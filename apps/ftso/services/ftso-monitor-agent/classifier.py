"""
classifier.py — FTSO Monitor Agent: threshold classifier

Converts a raw scraper snapshot into a list of typed Alert dicts.
All arithmetic and threshold comparisons happen here — not in the LLM.

Alert schema:
  id            str   stable identifier  e.g. "RUNE/USD::out_of_band"
  pair          str
  issue_type    "out_of_band" | "approaching_boundary" | "no_data"
  severity      "critical" | "warning"
  deviation_pct float | None
  context       str   short human-readable description for LLM prompt

Design constraints:
  - Pure function: classify(snapshot, band_threshold, approach_threshold) -> list[dict]
  - No external calls, no I/O, no LLM
  - Returns empty list for malformed or failed-scrape input (no raise)
"""
from __future__ import annotations

from typing import Any


def classify(
    snapshot: dict[str, Any],
    band_threshold: float = 0.25,
    approach_threshold: float = 0.15,
) -> list[dict[str, Any]]:
    """
    Convert scraper snapshot to a list of Alert dicts.

    Thresholds are passed explicitly so context strings remain consistent
    with the values used during scraping (e.g. when BAND_THRESHOLD env
    override is active).  Returns empty list if scrape_ok is False or
    snapshot is malformed.
    """
    if not snapshot.get("scrape_ok"):
        return []

    alerts: list[dict[str, Any]] = []

    # ── Out of band ───────────────────────────────────────────────────────────
    for item in snapshot.get("out_of_band", []):
        pair = item["pair"]
        dev = item["deviation_pct"]
        abs_dev = abs(dev)
        direction = "above" if dev > 0 else "below"
        margin = round(abs_dev - band_threshold, 4)

        alerts.append({
            "id": f"{pair}::out_of_band",
            "pair": pair,
            "issue_type": "out_of_band",
            "severity": "critical",
            "deviation_pct": dev,
            "context": (
                f"{pair} is {abs_dev:.4f}% {direction} anchor — "
                f"outside the \u00b1{band_threshold}% primary band by {margin:.4f}%."
            ),
        })

    # ── Approaching boundary ──────────────────────────────────────────────────
    for item in snapshot.get("approaching", []):
        pair = item["pair"]
        dev = item["deviation_pct"]
        abs_dev = abs(dev)
        remaining = round(band_threshold - abs_dev, 4)
        direction = "above" if dev > 0 else "below"

        alerts.append({
            "id": f"{pair}::approaching_boundary",
            "pair": pair,
            "issue_type": "approaching_boundary",
            "severity": "warning",
            "deviation_pct": dev,
            "context": (
                f"{pair} is {abs_dev:.4f}% {direction} anchor — "
                f"{remaining:.4f}% from the \u00b1{band_threshold}% boundary."
            ),
        })

    # ── No data ───────────────────────────────────────────────────────────────
    for pair in snapshot.get("no_data", []):
        alerts.append({
            "id": f"{pair}::no_data",
            "pair": pair,
            "issue_type": "no_data",
            "severity": "warning",
            "deviation_pct": None,
            "context": (
                f"{pair} has no current price from the provider — "
                "all exchange sources may be unavailable or the asset was delisted."
            ),
        })

    return alerts
