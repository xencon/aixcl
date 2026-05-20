#!/usr/bin/env python3
"""
agent.py — FTSO Monitor Agent: main orchestrator

Poll loop:
  1. scraper.scrape()           fetch live metrics from :9102/metrics
  2. classifier.classify()      Python threshold classification (no LLM)
  3. llm_writer.write_actions() LLM writes action strings + summary
  4. Print structured report to stdout

If llm_writer fails, a fallback "Investigate manually." action is used —
the poll loop continues regardless.

Human-in-the-loop (--interactive or INTERACTIVE=1):
  Pauses after printing any report that contains critical alerts,
  waiting for ENTER before continuing to the next poll.

Usage:
  python agent.py              continuous poll loop
  python agent.py --once       single poll then exit (testing)
  python agent.py --interactive pause on critical alerts

Design constraints:
  - No exec, no eval, no runtime file rewriting
  - Failures logged with full context; loop continues unless KeyboardInterrupt
  - No implicit global state
"""
from __future__ import annotations

import argparse
import logging
import os
import sys
import time
from datetime import datetime, timezone

import classifier
import llm_writer
import scraper

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger("ftso-monitor-agent")

POLL_INTERVAL: int = int(os.getenv("POLL_INTERVAL", "60"))
METRICS_URL: str = os.getenv("METRICS_URL", "http://localhost:9102/metrics")
INTERACTIVE: bool = os.getenv("INTERACTIVE", "0") == "1"


# ── Report formatting ──────────────────────────────────────────────────────────

_SEV_TAGS = {"critical": "[CRITICAL]", "warning": "[WARNING ]"}


def _format_report(
    snapshot: dict,
    alerts: list[dict],
    written: dict,
) -> str:
    ts = datetime.fromtimestamp(
        snapshot["timestamp"], tz=timezone.utc
    ).strftime("%Y-%m-%dT%H:%M:%SZ")

    overall = snapshot.get("overall", {})
    band_pct = overall.get("anchor_band_pct")
    feed_count = overall.get("provider_feed_count")
    src_errors = overall.get("source_errors", {})

    lines: list[str] = []
    lines.append("=" * 72)
    lines.append(f"  FTSO MONITOR AGENT  {ts}")
    lines.append("=" * 72)

    band_str = f"{band_pct:.2f}%" if band_pct is not None else "N/A"
    feed_str = str(feed_count) if feed_count is not None else "N/A"
    lines.append(f"  Anchor band : {band_str}   Feeds: {feed_str}")

    active_errors = {k: v for k, v in src_errors.items() if v > 0}
    if active_errors:
        lines.append(
            "  Src errors  : "
            + ", ".join(f"{k}={v}" for k, v in active_errors.items())
        )

    lines.append("")
    lines.append(f"  Summary: {written.get('summary', 'N/A')}")
    lines.append("")

    if not alerts:
        lines.append("  No active alerts.")
    else:
        lines.append(f"  Alerts ({len(alerts)}):")
        for a in alerts:
            tag = _SEV_TAGS.get(a["severity"], f"[{a['severity'].upper():8}]")
            action = written.get("actions", {}).get(a["id"], "Investigate manually.")
            lines.append(f"    {tag} {a['pair']} | {a['issue_type']}")
            lines.append(f"      {a['context']}")
            lines.append(f"      → {action}")
            lines.append("")

    lat = written.get("latency_s", 0.0)
    model = written.get("model", "N/A")
    if lat > 0:
        lines.append(f"  LLM: {model}  latency={lat}s")
    lines.append("=" * 72)
    return "\n".join(lines)


# ── Poll cycle ─────────────────────────────────────────────────────────────────

def _poll_once(interactive: bool) -> None:
    """Run one full poll cycle. Logs all errors; never raises."""
    try:
        snapshot = scraper.scrape(metrics_url=METRICS_URL)
    except Exception as exc:
        logger.error("Scraper raised unexpectedly: %s", exc, exc_info=True)
        return

    if not snapshot["scrape_ok"]:
        logger.warning("Scrape failed: %s", snapshot.get("error"))
        return

    alerts = classifier.classify(snapshot)

    try:
        written = llm_writer.write_actions(alerts)
    except RuntimeError as exc:
        logger.warning("LLM writer failed (%s) — using fallback actions.", exc)
        written = {
            "actions": {a["id"]: "Investigate manually." for a in alerts},
            "summary": "LLM unavailable — manual review required.",
            "latency_s": 0.0,
            "model": "fallback",
        }

    print(_format_report(snapshot, alerts, written), flush=True)

    if interactive and any(a["severity"] == "critical" for a in alerts):
        try:
            input("\n  [interactive] Press ENTER to continue (Ctrl-C to exit)...\n")
        except (EOFError, KeyboardInterrupt):
            logger.info("Interactive mode: exiting on interrupt.")
            sys.exit(0)


# ── Entry point ────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="FTSO Monitor Agent")
    parser.add_argument(
        "--once", action="store_true",
        help="Run a single poll and exit (for testing).",
    )
    parser.add_argument(
        "--interactive", action="store_true",
        help="Pause on critical alerts for operator confirmation.",
    )
    args = parser.parse_args()
    interactive = args.interactive or INTERACTIVE

    logger.info(
        "FTSO Monitor Agent starting  poll_interval=%ds  interactive=%s  metrics=%s",
        POLL_INTERVAL, interactive, METRICS_URL,
    )

    if args.once:
        _poll_once(interactive)
        return

    while True:
        _poll_once(interactive)
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
