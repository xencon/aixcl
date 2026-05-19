#!/usr/bin/env python3
"""
FTSO Price Monitor

Polls dd-ftso-v2-provider and compares prices against CoinGecko and Binance.
Exposes Prometheus metrics on METRICS_PORT for Grafana visualization.
"""

import asyncio
import logging
import os
import time
from typing import Dict, Optional

import aiohttp
from prometheus_client import Counter, Gauge, start_http_server

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("ftso-monitor")

PROVIDER_URL = os.getenv("PROVIDER_URL", "http://localhost:3101")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "30"))
METRICS_PORT = int(os.getenv("METRICS_PORT", "9102"))
PRIMARY_BAND_PCT = float(os.getenv("PRIMARY_BAND_PCT", "0.25"))

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

COINGECKO_IDS: Dict[str, Optional[str]] = {
    "FLR": "flare-networks", "SGB": "songbird", "BTC": "bitcoin",
    "XRP": "ripple", "LTC": "litecoin", "XLM": "stellar",
    "DOGE": "dogecoin", "ADA": "cardano", "ALGO": "algorand",
    "ETH": "ethereum", "FIL": "filecoin", "ARB": "arbitrum",
    "AVAX": "avalanche-2", "BNB": "binancecoin", "POL": "polygon-ecosystem-token",
    "SOL": "solana", "USDC": "usd-coin", "USDT": "tether",
    "XDC": "xdce-crowd-sale", "TRX": "tron", "LINK": "chainlink",
    "ATOM": "cosmos", "DOT": "polkadot", "TON": "the-open-network",
    "ICP": "internet-computer", "SHIB": "shiba-inu", "USDS": "usds",
    "BCH": "bitcoin-cash", "NEAR": "near", "LEO": "leo-token",
    "UNI": "uniswap", "ETC": "ethereum-classic", "WIF": "dogwifcoin",
    "BONK": "bonk", "JUP": "jupiter-exchange-solana", "ETHFI": "ether-fi",
    "ENA": "ethena", "PYTH": "pyth-network", "HNT": "helium",
    "SUI": "sui", "PEPE": "pepe", "QNT": "quant-network",
    "AAVE": "aave", "S": "sonic-3", "ONDO": "ondo-finance",
    "TAO": "bittensor", "FET": "fetch-ai", "RENDER": "render-token",
    "NOT": "notcoin", "RUNE": "thorchain", "TRUMP": "official-trump",
    "USDX": None, "JOULE": None,
    "HBAR": "hedera-hashgraph", "PENGU": "pudgy-penguins",
    "HYPE": "hyperliquid", "APT": "aptos", "PAXG": "pax-gold",
    "BERA": "berachain-bera", "OP": "optimism", "PUMP": "pump-fun",
    "XPL": None, "MON": None, "NIGHT": None,
}

BINANCE_SYMBOLS: Dict[str, Optional[str]] = {
    "FLR": "FLRUSDT", "SGB": None, "BTC": "BTCUSDT",
    "XRP": "XRPUSDT", "LTC": "LTCUSDT", "XLM": "XLMUSDT",
    "DOGE": "DOGEUSDT", "ADA": "ADAUSDT", "ALGO": "ALGOUSDT",
    "ETH": "ETHUSDT", "FIL": "FILUSDT", "ARB": "ARBUSDT",
    "AVAX": "AVAXUSDT", "BNB": "BNBUSDT", "POL": "POLUSDT",
    "SOL": "SOLUSDT", "USDC": "USDCUSDT", "USDT": None,
    "XDC": None, "TRX": "TRXUSDT", "LINK": "LINKUSDT",
    "ATOM": "ATOMUSDT", "DOT": "DOTUSDT", "TON": "TONUSDT",
    "ICP": "ICPUSDT", "SHIB": "SHIBUSDT", "USDS": "USDSUSDT",
    "BCH": "BCHUSDT", "NEAR": "NEARUSDT", "LEO": None,
    "UNI": "UNIUSDT", "ETC": "ETCUSDT", "WIF": "WIFUSDT",
    "BONK": "BONKUSDT", "JUP": "JUPUSDT", "ETHFI": None   # Binance ETHFI thin liquidity, systematic lag,
    "ENA": "ENAUSDT", "PYTH": "PYTHUSDT", "HNT": None   # Binance lists legacy migrated token, deviation -83%,
    "SUI": "SUIUSDT", "PEPE": "PEPEUSDT", "QNT": "QNTUSDT",
    "AAVE": "AAVEUSDT", "S": "SUSDT", "ONDO": "ONDOUSDT",
    "TAO": "TAOUSDT", "FET": "FETUSDT", "RENDER": "RENDERUSDT",
    "NOT": "NOTUSDT", "RUNE": "RUNEUSDT", "TRUMP": "TRUMPUSDT",
    "USDX": None, "JOULE": None, "HBAR": "HBARUSDT",
    "PENGU": "PENGUUSDT", "HYPE": None, "APT": "APTUSDT",
    "PAXG": "PAXGUSDT", "BERA": "BERAUSDT", "OP": "OPUSDT",
    "PUMP": "PUMPUSDT", "XPL": "XPLUSDT", "MON": "MONUSDT",
    "NIGHT": None,
}

g_provider_price = Gauge("ftso_provider_price", "Current price from the FTSO provider", ["pair"])
g_reference_price = Gauge("ftso_reference_price", "Reference price from an external source", ["pair", "source"])
g_deviation_pct = Gauge("ftso_price_deviation_pct", "Price deviation from reference in percent", ["pair", "source"])
g_in_band = Gauge("ftso_within_primary_band", "1 if within primary band else 0", ["pair", "source"])
g_band_pct = Gauge("ftso_pairs_within_primary_band_pct", "Percentage of pairs within primary band", ["source"])
g_provider_count = Gauge("ftso_provider_prices_total", "Number of pairs returned by provider")
g_reference_count = Gauge("ftso_reference_prices_total", "Number of pairs with reference data", ["source"])
c_poll = Counter("ftso_poll_total", "Poll cycle count", ["status"])
c_ref_errors = Counter("ftso_reference_fetch_errors_total", "Reference source fetch failures", ["source"])


async def fetch_provider(session: aiohttp.ClientSession) -> Dict[str, float]:
    try:
        async with session.post(
            f"{PROVIDER_URL}/feed-values/",
            json={"feeds": FEEDS},
            timeout=aiohttp.ClientTimeout(total=10),
        ) as resp:
            resp.raise_for_status()
            data = await resp.json()
            return {item["feed"]["name"]: item["value"] for item in data["data"]}
    except Exception as exc:
        logger.error("Provider fetch failed: %s", exc)
        return {}


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


def update_metrics(
    provider: Dict[str, float],
    coingecko: Dict[str, float],
    binance: Dict[str, float],
) -> None:
    sources = {"coingecko": coingecko, "binance": binance}
    in_band: Dict[str, Dict[str, int]] = {s: {"in": 0, "total": 0} for s in sources}
    g_provider_count.set(len(provider))
    for feed in FEEDS:
        pair = feed["name"]
        token = pair.split("/")[0]
        if pair not in provider:
            continue
        our_price = provider[pair]
        g_provider_price.labels(pair=pair).set(our_price)
        for src, prices in sources.items():
            if token not in prices:
                continue
            ref = prices[token]
            if ref <= 0:
                continue
            g_reference_price.labels(pair=pair, source=src).set(ref)
            dev = ((our_price - ref) / ref) * 100
            g_deviation_pct.labels(pair=pair, source=src).set(dev)
            band = 1 if abs(dev) <= PRIMARY_BAND_PCT else 0
            g_in_band.labels(pair=pair, source=src).set(band)
            in_band[src]["total"] += 1
            in_band[src]["in"] += band
    for src, counts in in_band.items():
        g_reference_count.labels(source=src).set(counts["total"])
        if counts["total"] > 0:
            g_band_pct.labels(source=src).set(counts["in"] / counts["total"] * 100)


async def poll_loop() -> None:
    connector = aiohttp.TCPConnector(limit=10, ttl_dns_cache=300)
    async with aiohttp.ClientSession(connector=connector) as session:
        while True:
            t0 = time.monotonic()
            try:
                provider, coingecko, binance = await asyncio.gather(
                    fetch_provider(session),
                    fetch_coingecko(session),
                    fetch_binance(session),
                )
                update_metrics(provider, coingecko, binance)
                c_poll.labels(status="success").inc()
                logger.info("Poll ok — provider=%d CoinGecko=%d Binance=%d",
                            len(provider), len(coingecko), len(binance))
            except Exception as exc:
                logger.error("Poll cycle error: %s", exc)
                c_poll.labels(status="error").inc()
            elapsed = time.monotonic() - t0
            await asyncio.sleep(max(0.0, POLL_INTERVAL - elapsed))


def main() -> None:
    start_http_server(METRICS_PORT)
    logger.info("Metrics on :%d | provider=%s | interval=%ds | band=+/-%.2f%%",
                METRICS_PORT, PROVIDER_URL, POLL_INTERVAL, PRIMARY_BAND_PCT)
    asyncio.run(poll_loop())


if __name__ == "__main__":
    main()
