"""
scraper.py — FTSO Monitor Agent: metrics scraper

Fetches a health snapshot from the FTSO price monitor metrics endpoint
(:9102/metrics, Prometheus text format). No Prometheus API, no async.

Metric names as defined in ftso/price-monitor/monitor.py:
  ftso_provider_price{pair}                  current provider price
  ftso_price_deviation_pct{pair,source}      % deviation from reference
  ftso_within_primary_band{pair,source}      1=in-band, 0=out-of-band
  ftso_pairs_within_primary_band_pct{source} overall % in primary band
  ftso_provider_prices_total                 count of provider prices
  ftso_reference_fetch_errors_total{source}  fetch error counts

Design constraints:
  - Failures raise explicitly — caller decides how to handle
  - No side effects at import time
  - No global mutable state
"""
from __future__ import annotations

import logging
import os
import re
import time
from typing import Any

import requests

logger = logging.getLogger(__name__)

# ── Band thresholds (must match monitor.py PRIMARY_BAND_PCT) ──────────────────
BAND_THRESHOLD: float = float(os.getenv("BAND_THRESHOLD", "0.25"))
APPROACH_FRACTION: float = float(os.getenv("APPROACH_FRACTION", "0.60"))
APPROACH_THRESHOLD: float = BAND_THRESHOLD * APPROACH_FRACTION  # default 0.15%

ANCHOR_SOURCE: str = "anchor"
FETCH_TIMEOUT: int = int(os.getenv("FETCH_TIMEOUT", "5"))

# ── Full feed list — must stay in sync with FEEDS in monitor.py ──────────────
# Update both files when the upstream feed list changes.
EXPECTED_PAIRS: tuple[str, ...] = (
    "FLR/USD",    "SGB/USD",    "BTC/USD",    "XRP/USD",    "LTC/USD",
    "XLM/USD",    "DOGE/USD",   "ADA/USD",    "ALGO/USD",   "ETH/USD",
    "FIL/USD",    "ARB/USD",    "AVAX/USD",   "BNB/USD",    "POL/USD",
    "SOL/USD",    "USDC/USD",   "USDT/USD",   "XDC/USD",    "TRX/USD",
    "LINK/USD",   "ATOM/USD",   "DOT/USD",    "TON/USD",    "ICP/USD",
    "SHIB/USD",   "USDS/USD",   "BCH/USD",    "NEAR/USD",   "LEO/USD",
    "UNI/USD",    "ETC/USD",    "WIF/USD",    "BONK/USD",   "JUP/USD",
    "ETHFI/USD",  "ENA/USD",    "PYTH/USD",   "HNT/USD",    "SUI/USD",
    "PEPE/USD",   "QNT/USD",    "AAVE/USD",   "S/USD",      "ONDO/USD",
    "TAO/USD",    "FET/USD",    "RENDER/USD", "NOT/USD",    "RUNE/USD",
    "TRUMP/USD",  "USDX/USD",   "JOULE/USD",  "HBAR/USD",   "PENGU/USD",
    "HYPE/USD",   "APT/USD",    "PAXG/USD",   "BERA/USD",   "OP/USD",
    "PUMP/USD",   "XPL/USD",    "MON/USD",    "NIGHT/USD",
)


# ── HTTP / parse helpers ───────────────────────────────────────────────────────

def _fetch(url: str, timeout: int = FETCH_TIMEOUT) -> str:
    """GET the URL; raises on network error or non-2xx status."""
    resp = requests.get(url, timeout=timeout)
    resp.raise_for_status()
    return resp.text


def _parse_prometheus(text: str) -> dict[str, list[dict[str, Any]]]:
    """
    Parse Prometheus text exposition format.
    Returns {metric_name: [{labels: {k: v}, value: float}, ...]}
    Comments and blank lines are skipped; unparseable values are skipped.
    """
    result: dict[str, list[dict[str, Any]]] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r'^([a-zA-Z_:][a-zA-Z0-9_:]*)(\{[^}]*\})?\s+([^\s]+)', line)
        if not m:
            continue
        name, labels_str, value_str = m.group(1), m.group(2) or "", m.group(3)
        try:
            value = float(value_str)
        except ValueError:
            continue
        labels: dict[str, str] = {}
        for lm in re.finditer(r'(\w+)="([^"]*)"', labels_str):
            labels[lm.group(1)] = lm.group(2)
        result.setdefault(name, []).append({"labels": labels, "value": value})
    return result


def _index_by_pair(
    entries: list[dict[str, Any]], source_filter: str | None = None
) -> dict[str, float]:
    """Build {pair: value} optionally filtered by source label."""
    out: dict[str, float] = {}
    for e in entries:
        if source_filter and e["labels"].get("source") != source_filter:
            continue
        pair = e["labels"].get("pair")
        if pair:
            out[pair] = e["value"]
    return out


# ── Main scrape ────────────────────────────────────────────────────────────────

def scrape(metrics_url: str | None = None) -> dict[str, Any]:
    """
    Fetch a complete health snapshot of the FTSO provider.

    Returns:
      {
        timestamp    : float
        overall      : {anchor_band_pct, provider_feed_count, source_errors}
        out_of_band  : [{pair, deviation_pct}]
        approaching  : [{pair, deviation_pct}]
        no_data      : [pair_str, ...]
        scrape_ok    : bool
        error        : str | None
      }

    On network / HTTP failure: scrape_ok=False, error set, raises nothing.
    """
    url = metrics_url or os.getenv("METRICS_URL", "http://localhost:9102/metrics")

    snapshot: dict[str, Any] = {
        "timestamp": time.time(),
        "overall": {
            "anchor_band_pct": None,
            "provider_feed_count": None,
            "source_errors": {},
        },
        "out_of_band": [],
        "approaching": [],
        "no_data": [],
        "scrape_ok": False,
        "error": None,
    }

    try:
        raw = _fetch(url)
    except Exception as exc:
        snapshot["error"] = f"metrics fetch failed: {exc}"
        logger.error("Metrics fetch failed: %s", exc)
        return snapshot

    metrics = _parse_prometheus(raw)

    # ── Overall band score ────────────────────────────────────────────────────
    for e in metrics.get("ftso_pairs_within_primary_band_pct", []):
        if e["labels"].get("source") == ANCHOR_SOURCE:
            snapshot["overall"]["anchor_band_pct"] = round(e["value"], 2)

    # ── Provider feed count ───────────────────────────────────────────────────
    for e in metrics.get("ftso_provider_prices_total", []):
        snapshot["overall"]["provider_feed_count"] = int(e["value"])

    # ── Source errors ─────────────────────────────────────────────────────────
    for e in metrics.get("ftso_reference_fetch_errors_total", []):
        src = e["labels"].get("source", "unknown")
        snapshot["overall"]["source_errors"][src] = int(e["value"])

    # ── Per-pair deviation vs anchor ──────────────────────────────────────────
    deviation = _index_by_pair(
        metrics.get("ftso_price_deviation_pct", []), source_filter=ANCHOR_SOURCE
    )
    in_band = _index_by_pair(
        metrics.get("ftso_within_primary_band", []), source_filter=ANCHOR_SOURCE
    )

    # Per-source deviation index for outlier analysis (excludes anchor source)
    src_devs_by_pair: dict[str, dict[str, float]] = {}
    for e in metrics.get("ftso_price_deviation_pct", []):
        src = e["labels"].get("source", "")
        p = e["labels"].get("pair", "")
        if src and src != ANCHOR_SOURCE and p:
            src_devs_by_pair.setdefault(p, {})[src] = round(e["value"], 4)

    for pair, dev in deviation.items():
        abs_dev = abs(dev)
        src_devs = src_devs_by_pair.get(pair, {})
        if in_band.get(pair, 1.0) == 0.0:
            snapshot["out_of_band"].append(
                {"pair": pair, "deviation_pct": round(dev, 4), "source_deviations": src_devs}
            )
        elif abs_dev > APPROACH_THRESHOLD:
            snapshot["approaching"].append(
                {"pair": pair, "deviation_pct": round(dev, 4), "source_deviations": src_devs}
            )

    # ── No-data: expected pairs absent from provider price gauge ─────────────
    active_pairs: set[str] = {
        e["labels"]["pair"]
        for e in metrics.get("ftso_provider_price", [])
        if "pair" in e["labels"]
    }
    for pair in EXPECTED_PAIRS:
        if pair not in active_pairs:
            snapshot["no_data"].append(pair)

    snapshot["scrape_ok"] = True
    return snapshot
