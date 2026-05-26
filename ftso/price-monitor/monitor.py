#!/usr/bin/env python3
"""
FTSO Price Monitor

Polls dd-ftso-v2-provider and compares prices against CoinGecko, Binance,
and the Flare FTSOv2 on-chain anchor (the actual scoring reference).
Exposes Prometheus metrics on METRICS_PORT for Grafana visualization.

Transparency additions:
- Calls /feed-details to expose per-source weights, raw prices, staleness
- Calls /last-round to expose the last voting round the provider committed to
- Stores source breakdown in ftso_sources (PostgreSQL)
- New Prometheus metrics: source_count, source_staleness, last_voting_round

Anchor fallback design:
  If FlareAnchorService fails to initialize at startup (RPC unreachable, bad
  registry, etc.), the monitor logs an ERROR and continues without anchor data.
  This is an explicitly designed fallback: CoinGecko/Binance monitoring remains
  fully operational, and the anchor metrics simply return no data. If anchor
  fetch fails during a poll cycle, the error is logged and counted in
  ftso_reference_fetch_errors_total{source="anchor"}.
"""

import asyncio
import json
import logging
import os
import time
from typing import Dict, List, Optional, Tuple

import aiohttp
from prometheus_client import Counter, Gauge, start_http_server

from flare_anchor import FlareAnchorService
from db import ensure_schema, store_snapshot, store_source_details, close as db_close

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("ftso-monitor")

# --- Configuration ---

PROVIDER_URL = os.getenv("PROVIDER_URL", "http://localhost:3101")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "30"))
METRICS_PORT = int(os.getenv("METRICS_PORT", "9102"))
PRIMARY_BAND_PCT = float(os.getenv("PRIMARY_BAND_PCT", "0.25"))

FLARE_RPC_URL = os.getenv(
    "FLARE_RPC_URL", "https://flare-api.flare.network/ext/C/rpc"
)
FLARE_CONTRACT_REGISTRY = os.getenv(
    "FLARE_CONTRACT_REGISTRY", "0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019"
)
ANCHOR_INIT_RETRIES = int(os.getenv("ANCHOR_INIT_RETRIES", "3"))
ANCHOR_INIT_RETRY_WAIT = int(os.getenv("ANCHOR_INIT_RETRY_WAIT", "20"))
COMMIT_LATENCY_MS = int(os.getenv("COMMIT_LATENCY_MS", "200"))

# All 64 feeds from feeds.json (category 1)
FEEDS = [
    {"category": 1, "name": "FLR/USD"},
    {"category": 1, "name": "SGB/USD"},
    {"category": 1, "name": "BTC/USD"},
    {"category": 1, "name": "XRP/USD"},
    {"category": 1, "name": "LTC/USD"},
    {"category": 1, "name": "XLM/USD"},
    {"category": 1, "name": "DOGE/USD"},
    {"category": 1, "name": "ADA/USD"},
    {"category": 1, "name": "ALGO/USD"},
    {"category": 1, "name": "ETH/USD"},
    {"category": 1, "name": "FIL/USD"},
    {"category": 1, "name": "ARB/USD"},
    {"category": 1, "name": "AVAX/USD"},
    {"category": 1, "name": "BNB/USD"},
    {"category": 1, "name": "POL/USD"},
    {"category": 1, "name": "SOL/USD"},
    {"category": 1, "name": "USDC/USD"},
    {"category": 1, "name": "USDT/USD"},
    {"category": 1, "name": "XDC/USD"},
    {"category": 1, "name": "TRX/USD"},
    {"category": 1, "name": "LINK/USD"},
    {"category": 1, "name": "ATOM/USD"},
    {"category": 1, "name": "DOT/USD"},
    {"category": 1, "name": "TON/USD"},
    {"category": 1, "name": "ICP/USD"},
    {"category": 1, "name": "SHIB/USD"},
    {"category": 1, "name": "USDS/USD"},
    {"category": 1, "name": "BCH/USD"},
    {"category": 1, "name": "NEAR/USD"},
    {"category": 1, "name": "LEO/USD"},
    {"category": 1, "name": "UNI/USD"},
    {"category": 1, "name": "ETC/USD"},
    {"category": 1, "name": "WIF/USD"},
    {"category": 1, "name": "BONK/USD"},
    {"category": 1, "name": "JUP/USD"},
    {"category": 1, "name": "ETHFI/USD"},
    {"category": 1, "name": "ENA/USD"},
    {"category": 1, "name": "PYTH/USD"},
    {"category": 1, "name": "HNT/USD"},
    {"category": 1, "name": "SUI/USD"},
    {"category": 1, "name": "PEPE/USD"},
    {"category": 1, "name": "QNT/USD"},
    {"category": 1, "name": "AAVE/USD"},
    {"category": 1, "name": "S/USD"},
    {"category": 1, "name": "ONDO/USD"},
    {"category": 1, "name": "TAO/USD"},
    {"category": 1, "name": "FET/USD"},
    {"category": 1, "name": "RENDER/USD"},
    {"category": 1, "name": "NOT/USD"},
    {"category": 1, "name": "RUNE/USD"},
    {"category": 1, "name": "TRUMP/USD"},
    {"category": 1, "name": "USDX/USD"},
    {"category": 1, "name": "JOULE/USD"},
    {"category": 1, "name": "HBAR/USD"},
    {"category": 1, "name": "PENGU/USD"},
    {"category": 1, "name": "HYPE/USD"},
    {"category": 1, "name": "APT/USD"},
    {"category": 1, "name": "PAXG/USD"},
    {"category": 1, "name": "BERA/USD"},
    {"category": 1, "name": "OP/USD"},
    {"category": 1, "name": "PUMP/USD"},
    {"category": 1, "name": "XPL/USD"},
    {"category": 1, "name": "MON/USD"},
    {"category": 1, "name": "NIGHT/USD"},
]

# CoinGecko API IDs. None = not tracked on CoinGecko (niche/Flare-specific tokens).
COINGECKO_IDS: Dict[str, Optional[str]] = {
    "FLR":    "flare-networks",
    "SGB":    "songbird",
    "BTC":    "bitcoin",
    "XRP":    "ripple",
    "LTC":    "litecoin",
    "XLM":    "stellar",
    "DOGE":   "dogecoin",
    "ADA":    "cardano",
    "ALGO":   "algorand",
    "ETH":    "ethereum",
    "FIL":    "filecoin",
    "ARB":    "arbitrum",
    "AVAX":   "avalanche-2",
    "BNB":    "binancecoin",
    "POL":    "polygon-ecosystem-token",
    "SOL":    "solana",
    "USDC":   "usd-coin",
    "USDT":   "tether",
    "XDC":    "xdce-crowd-sale",
    "TRX":    "tron",
    "LINK":   "chainlink",
    "ATOM":   "cosmos",
    "DOT":    "polkadot",
    "TON":    "the-open-network",
    "ICP":    "internet-computer",
    "SHIB":   "shiba-inu",
    "USDS":   "usds",
    "BCH":    "bitcoin-cash",
    "NEAR":   "near",
    "LEO":    "leo-token",
    "UNI":    "uniswap",
    "ETC":    "ethereum-classic",
    "WIF":    "dogwifcoin",
    "BONK":   "bonk",
    "JUP":    "jupiter-exchange-solana",
    "ETHFI":  "ether-fi",
    "ENA":    "ethena",
    "PYTH":   "pyth-network",
    "HNT":    "helium",
    "SUI":    "sui",
    "PEPE":   "pepe",
    "QNT":    "quant-network",
    "AAVE":   "aave",
    "S":      "sonic-3",
    "ONDO":   "ondo-finance",
    "TAO":    "bittensor",
    "FET":    "fetch-ai",
    "RENDER": "render-token",
    "NOT":    "notcoin",
    "RUNE":   "thorchain",
    "TRUMP":  "official-trump",
    "USDX":   None,   # Flare ecosystem stablecoin
    "JOULE":  None,   # Flare ecosystem token
    "HBAR":   "hedera-hashgraph",
    "PENGU":  "pudgy-penguins",
    "HYPE":   "hyperliquid",
    "APT":    "aptos",
    "PAXG":   "pax-gold",
    "BERA":   "berachain-bera",
    "OP":     "optimism",
    "PUMP":   "pump-fun",
    "XPL":    None,   # Unclear CoinGecko listing
    "MON":    None,   # Monad not yet on CoinGecko
    "NIGHT":  None,   # Niche token
}

# Binance USDT spot symbols. None = not listed on Binance spot.
BINANCE_SYMBOLS: Dict[str, Optional[str]] = {
    "FLR":    "FLRUSDT",
    "SGB":    None,
    "BTC":    "BTCUSDT",
    "XRP":    "XRPUSDT",
    "LTC":    "LTCUSDT",
    "XLM":    "XLMUSDT",
    "DOGE":   "DOGEUSDT",
    "ADA":    "ADAUSDT",
    "ALGO":   "ALGOUSDT",
    "ETH":    "ETHUSDT",
    "FIL":    "FILUSDT",
    "ARB":    "ARBUSDT",
    "AVAX":   "AVAXUSDT",
    "BNB":    "BNBUSDT",
    "POL":    "POLUSDT",
    "SOL":    "SOLUSDT",
    "USDC":   "USDCUSDT",
    "USDT":   None,   # No USDT/USDT pair
    "XDC":    None,   # Not on Binance spot
    "TRX":    "TRXUSDT",
    "LINK":   "LINKUSDT",
    "ATOM":   "ATOMUSDT",
    "DOT":    "DOTUSDT",
    "TON":    "TONUSDT",
    "ICP":    "ICPUSDT",
    "SHIB":   "SHIBUSDT",
    "USDS":   "USDSUSDT",
    "BCH":    "BCHUSDT",
    "NEAR":   "NEARUSDT",
    "LEO":    None,
    "UNI":    "UNIUSDT",
    "ETC":    "ETCUSDT",
    "WIF":    "WIFUSDT",
    "BONK":   "BONKUSDT",
    "JUP":    "JUPUSDT",
    "ETHFI":  None,   # Binance ETHFI liquidity too thin, systematic lag vs CoinGecko
    "ENA":    "ENAUSDT",
    "PYTH":   "PYTHUSDT",
    "HNT":    None,   # Binance lists legacy/migrated token, price is -83% vs spot
    "SUI":    "SUIUSDT",
    "PEPE":   "PEPEUSDT",
    "QNT":    "QNTUSDT",
    "AAVE":   "AAVEUSDT",
    "S":      "SUSDT",
    "ONDO":   "ONDOUSDT",
    "TAO":    "TAOUSDT",
    "FET":    "FETUSDT",
    "RENDER": "RENDERUSDT",
    "NOT":    "NOTUSDT",
    "RUNE":   "RUNEUSDT",
    "TRUMP":  "TRUMPUSDT",
    "USDX":   None,
    "JOULE":  None,
    "HBAR":   "HBARUSDT",
    "PENGU":  "PENGUUSDT",
    "HYPE":   None,   # Hyperliquid native — not on Binance spot
    "APT":    "APTUSDT",
    "PAXG":   "PAXGUSDT",
    "BERA":   "BERAUSDT",
    "OP":     "OPUSDT",
    "PUMP":   "PUMPUSDT",
    "XPL":    "XPLUSDT",
    "MON":    "MONUSDT",
    "NIGHT":  None,
}

# --- Prometheus metrics ---

g_provider_price = Gauge(
    "ftso_provider_price",
    "Current price from the FTSO provider",
    ["pair"],
)
g_reference_price = Gauge(
    "ftso_reference_price",
    "Reference price from an external source",
    ["pair", "source"],
)
g_deviation_pct = Gauge(
    "ftso_price_deviation_pct",
    "Price deviation from reference in percent ((provider-ref)/ref*100)",
    ["pair", "source"],
)
g_in_band = Gauge(
    "ftso_within_primary_band",
    f"1 if deviation is within ±{PRIMARY_BAND_PCT}% of reference, else 0",
    ["pair", "source"],
)
g_band_pct = Gauge(
    "ftso_pairs_within_primary_band_pct",
    "Percentage of pairs with reference data that are within the primary band",
    ["source"],
)
g_provider_count = Gauge("ftso_provider_prices_total", "Number of pairs returned by provider")
g_reference_count = Gauge(
    "ftso_reference_prices_total",
    "Number of pairs with reference data",
    ["source"],
)
g_last_voting_round = Gauge(
    "ftso_provider_last_voting_round",
    "Last voting round ID the provider committed to",
)
g_voting_round_ts = Gauge(
    "ftso_provider_voting_round_timestamp",
    "Unix timestamp of the last known voting round",
)
g_source_count = Gauge(
    "ftso_provider_source_count",
    "Number of active sources used for a given feed",
    ["pair"],
)
g_source_staleness = Gauge(
    "ftso_provider_source_staleness_ms",
    "Staleness of each individual source in ms",
    ["pair", "exchange"],
)
g_source_weight = Gauge(
    "ftso_provider_source_weight",
    "Normalized weight of each individual source",
    ["pair", "exchange"],
)
g_source_raw_price = Gauge(
    "ftso_provider_source_raw_price",
    "Raw price from each individual source before median aggregation",
    ["pair", "exchange"],
)
c_poll = Counter("ftso_poll_total", "Poll cycle count", ["status"])
c_ref_errors = Counter(
    "ftso_reference_fetch_errors_total",
    "Reference source fetch failures",
    ["source"],
)
c_commit_latency = Counter(
    "ftso_commit_latency_total",
    "Simulated commit latency in milliseconds",
)


# --- Data fetchers ---

async def fetch_provider(session: aiohttp.ClientSession) -> Dict[str, float]:
    try:
        async with session.post(
            f"{PROVIDER_URL}/feed-values/",
            json={"feeds": FEEDS},
            timeout=aiohttp.ClientTimeout(total=10),
        ) as resp:
            resp.raise_for_status()
            data = await resp.json()
            prices: dict[str, float] = {}
            missing: list[str] = []
            for item in data["data"]:
                if "value" in item:
                    prices[item["feed"]["name"]] = item["value"]
                else:
                    missing.append(item["feed"]["name"])
            if missing:
                logger.warning(
                    "Provider warmup: %d feed(s) missing value -- skipped: %s",
                    len(missing),
                    missing[:5],
                )
            return prices
    except Exception as exc:
        logger.error("Provider fetch failed: %s", exc)
        return {}


async def fetch_provider_details(session: aiohttp.ClientSession) -> Tuple[Dict[str, List[Dict]], int, str]:
    """
    Call /feed-details for transparency.
    Returns (details_by_pair, last_voting_round, round_timestamp).
    """
    details_by_pair: Dict[str, List[Dict]] = {}
    last_round = 0
    round_ts = ""
    try:
        # Fetch feed details in batches of 20 to keep payload reasonable
        batch_size = 20
        for i in range(0, len(FEEDS), batch_size):
            batch = FEEDS[i:i + batch_size]
            async with session.post(
                f"{PROVIDER_URL}/feed-details",
                json={"feeds": batch},
                timeout=aiohttp.ClientTimeout(total=15),
            ) as resp:
                resp.raise_for_status()
                body = await resp.json()
                for item in body.get("data", []):
                    pair = item["feed"]["name"]
                    details_by_pair[pair] = item.get("sources", [])
    except Exception as exc:
        logger.error("Provider details fetch failed: %s", exc)

    try:
        async with session.get(
            f"{PROVIDER_URL}/last-round",
            timeout=aiohttp.ClientTimeout(total=5),
        ) as resp:
            resp.raise_for_status()
            body = await resp.json()
            rid = body.get("lastVotingRoundId")
            last_round = int(rid) if rid is not None else 0
            round_ts = body.get("timestamp", "")
    except Exception as exc:
        logger.error("Provider last-round fetch failed: %s", exc)

    return details_by_pair, last_round, round_ts


async def fetch_coingecko(session: aiohttp.ClientSession) -> Dict[str, float]:
    ids = [cg_id for cg_id in COINGECKO_IDS.values() if cg_id]
    reverse = {v: k for k, v in COINGECKO_IDS.items() if v}
    try:
        async with session.get(
            "https://api.coingecko.com/api/v3/simple/price",
            params={"ids": ",".join(ids), "vs_currencies": "usd"},
            headers={"Accept": "application/json", "User-Agent": "ftso-price-monitor/1.0"},
            timeout=aiohttp.ClientTimeout(total=20),
        ) as resp:
            resp.raise_for_status()
            data = await resp.json()
            return {
                reverse[cg_id]: info["usd"]
                for cg_id, info in data.items()
                if cg_id in reverse and "usd" in info
            }
    except Exception as exc:
        logger.error("CoinGecko fetch failed: %s", exc)
        c_ref_errors.labels(source="coingecko").inc()
        return {}


async def fetch_binance(session: aiohttp.ClientSession) -> Dict[str, float]:
    try:
        async with session.get(
            "https://api.binance.com/api/v3/ticker/price",
            timeout=aiohttp.ClientTimeout(total=10),
        ) as resp:
            resp.raise_for_status()
            data = await resp.json()
            all_prices = {item["symbol"]: float(item["price"]) for item in data}
            return {
                token: all_prices[sym]
                for token, sym in BINANCE_SYMBOLS.items()
                if sym and sym in all_prices
            }
    except Exception as exc:
        logger.error("Binance fetch failed: %s", exc)
        c_ref_errors.labels(source="binance").inc()
        return {}


async def fetch_anchor(
    anchor_service: FlareAnchorService,
    loop: asyncio.AbstractEventLoop,
) -> Dict[str, float]:
    """
    Fetch anchor prices from Flare FTSOv2 on-chain contract.

    Runs the synchronous web3 call in a thread executor to avoid blocking
    the async event loop. Errors are logged and counted; returns {} on failure.
    """
    try:
        return await loop.run_in_executor(None, anchor_service.fetch_prices)
    except Exception as exc:
        logger.error("Anchor fetch failed: %s", exc)
        c_ref_errors.labels(source="anchor").inc()
        return {}


# --- Metrics update ---

def update_metrics(
    provider: Dict[str, float],
    coingecko: Dict[str, float],
    binance: Dict[str, float],
    anchor: Dict[str, float],
) -> Tuple[Dict[str, Dict[str, float]], Dict[str, Dict[str, bool]]]:
    """Update Prometheus metrics and return raw deviation data for downstream storage."""
    sources = {"coingecko": coingecko, "binance": binance, "anchor": anchor}
    in_band: Dict[str, Dict[str, int]] = {s: {"in": 0, "total": 0} for s in sources}

    deviations: Dict[str, Dict[str, float]] = {}
    band_map: Dict[str, Dict[str, bool]] = {}

    g_provider_count.set(len(provider))

    for feed in FEEDS:
        pair = feed["name"]
        token = pair.split("/")[0]

        if pair not in provider:
            continue

        our_price = provider[pair]
        g_provider_price.labels(pair=pair).set(our_price)

        for src, prices in sources.items():
            if token not in prices or prices[token] is None:
                continue
            ref = prices[token]
            if ref <= 0:
                continue

            g_reference_price.labels(pair=pair, source=src).set(ref)

            dev = ((our_price - ref) / ref) * 100
            g_deviation_pct.labels(pair=pair, source=src).set(dev)

            band = abs(dev) <= PRIMARY_BAND_PCT
            g_in_band.labels(pair=pair, source=src).set(1 if band else 0)

            deviations.setdefault(pair, {})[src] = dev
            band_map.setdefault(pair, {})[src] = band

            in_band[src]["total"] += 1
            in_band[src]["in"] += (1 if band else 0)

    for src, counts in in_band.items():
        g_reference_count.labels(source=src).set(counts["total"])
        if counts["total"] > 0:
            g_band_pct.labels(source=src).set(counts["in"] / counts["total"] * 100)

    return deviations, band_map


def update_transparency_metrics(
    details: Dict[str, List[Dict]],
    last_round: int,
    round_ts: str,
) -> None:
    """Update Prometheus metrics for source transparency."""
    if last_round > 0:
        g_last_voting_round.set(last_round)
    if round_ts:
        try:
            from datetime import datetime, timezone
            ts = datetime.fromisoformat(round_ts.replace("Z", "+00:00"))
            g_voting_round_ts.set(ts.timestamp())
        except Exception:
            pass

    for pair, sources in details.items():
        g_source_count.labels(pair=pair).set(len(sources))
        for src in sources:
            ex = src.get("exchange", "unknown")
            g_source_staleness.labels(pair=pair, exchange=ex).set(src.get("stalenessMs", 0) or 0)
            g_source_weight.labels(pair=pair, exchange=ex).set(src.get("weight", 0) or 0)
            g_source_raw_price.labels(pair=pair, exchange=ex).set(src.get("rawPrice", 0) or 0)


# --- Main loop ---

async def poll_loop(anchor_service: Optional[FlareAnchorService]) -> None:
    loop = asyncio.get_event_loop()
    connector = aiohttp.TCPConnector(limit=10, ttl_dns_cache=300)
    async with aiohttp.ClientSession(connector=connector) as session:
        # Ensure PostgreSQL schema on the same event loop that will use it
        try:
            pg_ready = await ensure_schema()
        except Exception as exc:
            logger.warning("PostgreSQL schema init skipped: %s", exc)
            pg_ready = False
        try:
            while True:
                # Lazy anchor re-init: retry once per cycle if startup init failed
                if anchor_service is None:
                    try:
                        _feed_names = [f["name"] for f in FEEDS]
                        anchor_service = await loop.run_in_executor(
                            None,
                            lambda: FlareAnchorService(
                                rpc_url=FLARE_RPC_URL,
                                registry_address=FLARE_CONTRACT_REGISTRY,
                                feed_names=_feed_names,
                            ),
                        )
                        logger.info(
                            "Flare anchor service initialized (lazy retry, %d feeds)",
                            len(_feed_names),
                        )
                    except Exception as exc:
                        logger.debug("Anchor lazy init retry failed: %s", exc)

                t0 = time.monotonic()
                try:
                    # Build coroutines -- anchor fetch only if service is available
                    coros = [
                        fetch_provider(session),
                        fetch_provider_details(session),
                        fetch_coingecko(session),
                        fetch_binance(session),
                    ]
                    if anchor_service is not None:
                        coros.append(fetch_anchor(anchor_service, loop))

                    results = await asyncio.gather(*coros)
                    provider, (details, last_round, round_ts), coingecko, binance = (
                        results[0],
                        results[1],
                        results[2],
                        results[3],
                    )
                    anchor = results[4] if anchor_service is not None else {}

                    # --- Simulate commit/reveal latency ---
                    if COMMIT_LATENCY_MS > 0:
                        logger.debug(
                            "Simulating commit latency %d ms before metrics update",
                            COMMIT_LATENCY_MS,
                        )
                        await asyncio.sleep(COMMIT_LATENCY_MS / 1000.0)
                        c_commit_latency.inc(COMMIT_LATENCY_MS)

                    deviations, band_map = update_metrics(provider, coingecko, binance, anchor)
                    update_transparency_metrics(details, last_round, round_ts)

                    if pg_ready:
                        await store_snapshot(
                            provider,
                            {
                                "coingecko": coingecko,
                                "binance": binance,
                                "anchor": anchor,
                            },
                            deviations,
                            band_map,
                        )
                        await store_source_details(details, last_round)

                    # Log a concise transparency line for every pair (first 3)
                    for pair in list(details)[:3]:
                        srcs = details.get(pair, [])
                        src_list = ", ".join(
                            f"{s['exchange']}={s['rawPrice']:.4f}(w{s['weight']:.2f})"
                            for s in srcs[:3]
                        )
                        logger.info(
                            "Transparency %s | round=%s | sources=%d | top: %s",
                            pair,
                            last_round,
                            len(srcs),
                            src_list,
                        )

                    c_poll.labels(status="success").inc()
                    logger.info(
                        "Poll ok -- provider=%d CoinGecko=%d Binance=%d Anchor=%d round=%s",
                        len(provider), len(coingecko), len(binance), len(anchor), last_round,
                    )
                except Exception as exc:
                    logger.error("Poll cycle error: %s", exc)
                    c_poll.labels(status="error").inc()

                elapsed = time.monotonic() - t0
                await asyncio.sleep(max(0.0, POLL_INTERVAL - elapsed))
        finally:
            await db_close()


def main() -> None:
    # Initialize error counters so metric series exist from startup,
    # even before any errors occur. All three sources must be present.
    c_ref_errors.labels(source="coingecko")
    c_ref_errors.labels(source="binance")
    c_ref_errors.labels(source="anchor")

    # Construct FlareAnchorService explicitly.
    # Explicitly designed fallback: if the Flare RPC is unreachable at startup,
    # the monitor continues without anchor data. CoinGecko/Binance monitoring is
    # unaffected. The ERROR log and missing anchor metrics make the degraded state
    # visible -- this is not silent failure.
    anchor_service: Optional[FlareAnchorService] = None
    feed_names = [f["name"] for f in FEEDS]
    for _attempt in range(1, ANCHOR_INIT_RETRIES + 1):
        try:
            anchor_service = FlareAnchorService(
                rpc_url=FLARE_RPC_URL,
                registry_address=FLARE_CONTRACT_REGISTRY,
                feed_names=feed_names,
            )
            logger.info("Flare anchor service initialized (%d feeds)", len(feed_names))
            break
        except Exception as exc:
            if _attempt < ANCHOR_INIT_RETRIES:
                logger.warning(
                    "Flare anchor init attempt %d/%d failed: %s -- retrying in %ds",
                    _attempt, ANCHOR_INIT_RETRIES, exc, ANCHOR_INIT_RETRY_WAIT,
                )
                time.sleep(ANCHOR_INIT_RETRY_WAIT)
            else:
                logger.error(
                    "Flare anchor service failed to initialize -- anchor metrics will be absent: %s",
                    exc,
                )

    start_http_server(METRICS_PORT)
    logger.info(
        "Metrics on :%d | provider=%s | interval=%ds | band=±%.2f%% | anchor=%s | commit_latency_ms=%d",
        METRICS_PORT,
        PROVIDER_URL,
        POLL_INTERVAL,
        PRIMARY_BAND_PCT,
        "enabled" if anchor_service is not None else "DISABLED (init failed)",
        COMMIT_LATENCY_MS,
    )
    asyncio.run(poll_loop(anchor_service))


if __name__ == "__main__":
    main()
