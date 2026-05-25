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
  - No implicit global state — consecutive_counts lifetime is owned by main()
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import signal
import sys
import time
from datetime import datetime, timezone

import requests

import classifier
import llm_writer
import proposer
import scraper

logger = logging.getLogger("ftso-monitor-agent")

POLL_INTERVAL: int = int(os.getenv("POLL_INTERVAL", "60"))
METRICS_URL: str = os.getenv("METRICS_URL", "http://localhost:9102/metrics")
INTERACTIVE: bool = os.getenv("INTERACTIVE", "0") == "1"
ALERTMANAGER_URL: str = os.getenv("ALERTMANAGER_URL", "http://localhost:9093")
LOKI_URL: str = os.getenv("LOKI_URL", "http://localhost:3100")
PROPOSALS_DIR: str | None = os.getenv("PROPOSALS_DIR")  # None = proposer disabled

_SEV_TAGS: dict[str, str] = {"critical": "[CRITICAL]", "warning": "[WARNING ]"}


# ── Report formatting ──────────────────────────────────────────────────────────

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
            lines.append(f"      \u2192 {action}")
            lines.append("")

    lat = written.get("latency_s", 0.0)
    model = written.get("model", "N/A")
    if lat > 0:
        lines.append(f"  LLM: {model}  latency={lat}s")
    lines.append("=" * 72)
    return "\n".join(lines)


# ── Persistence tracking ───────────────────────────────────────────────────────

def _update_alert_counts(alerts: list[dict], counts: dict[str, int]) -> None:
    """
    Update consecutive poll counts for each active alert.
    Mutates alerts in place — adds 'consecutive_polls' and enriches 'context'.
    Clears counts for pairs that are no longer alerting (resolved).
    State is passed in explicitly — lifetime owned by the caller (main loop).

    Tier thresholds:
      poll 1        monitor — likely self-resolving
      polls 2-4     recurring — investigate sources
      polls 5+      persistent structural issue — act now
    """
    active_ids = {a["id"] for a in alerts}

    for a in alerts:
        counts[a["id"]] = counts.get(a["id"], 0) + 1
        count = counts[a["id"]]
        a["consecutive_polls"] = count

        if count == 1:
            tier = "poll 1 \u2014 monitor, likely self-resolving"
        elif count < 5:
            tier = f"poll {count} \u2014 recurring, investigate sources"
        else:
            tier = f"poll {count} \u2014 persistent structural issue, act now"

        a["context"] = a["context"] + f" [{tier}]"

    # Clear resolved pairs
    for key in list(counts.keys()):
        if key not in active_ids:
            del counts[key]


# ── Alertmanager integration ───────────────────────────────────────────────────

def _post_to_alertmanager(alerts: list[dict]) -> None:
    """
    POST critical alerts to Alertmanager /api/v2/alerts.
    Only critical severity is forwarded — warnings are informational.
    Failures are logged and swallowed — monitoring must never break monitoring.
    """
    critical = [a for a in alerts if a["severity"] == "critical"]
    if not critical:
        return

    now = datetime.now(timezone.utc).isoformat()
    payload = [
        {
            "labels": {
                "alertname": "FTSOPriceBandViolation",
                "pair": a["pair"],
                "issue_type": a["issue_type"],
                "severity": a["severity"],
                "job": "ftso-monitor-agent",
            },
            "annotations": {
                "summary": f"{a['pair']} \u2014 {a['issue_type'].replace('_', ' ')}",
                "description": a["context"],
            },
            "startsAt": now,
        }
        for a in critical
    ]
    try:
        resp = requests.post(
            f"{ALERTMANAGER_URL}/api/v2/alerts",
            json=payload,
            timeout=5,
        )
        resp.raise_for_status()
        logger.info("Alertmanager: posted %d critical alert(s).", len(payload))
    except Exception as exc:
        logger.warning("Alertmanager POST failed (alerts NOT delivered): %s", exc)


# ── Loki direct push ───────────────────────────────────────────────────────────

def _push_to_loki(snapshot: dict, alerts: list[dict], written: dict) -> None:
    """
    Push one structured JSON log entry per poll to Loki /loki/api/v1/push.
    Every poll is recorded regardless of alert status — this is the audit trail.
    Failures are logged and swallowed.
    """
    ts_ns = str(int(snapshot["timestamp"] * 1_000_000_000))
    overall = snapshot.get("overall", {})

    entry = json.dumps({
        "anchor_band_pct": overall.get("anchor_band_pct"),
        "provider_feed_count": overall.get("provider_feed_count"),
        "alert_count": len(alerts),
        "critical_count": sum(1 for a in alerts if a["severity"] == "critical"),
        "warning_count": sum(1 for a in alerts if a["severity"] == "warning"),
        "alerts": [
            {
                "pair": a["pair"],
                "issue_type": a["issue_type"],
                "severity": a["severity"],
                "consecutive_polls": a.get("consecutive_polls", 1),
            }
            for a in alerts
        ],
        "summary": written.get("summary", ""),
        "llm_latency_s": written.get("latency_s", 0.0),
    })

    critical = sum(1 for a in alerts if a["severity"] == "critical")
    warnings = sum(1 for a in alerts if a["severity"] == "warning")
    level = "error" if critical > 0 else "warn" if warnings > 0 else "info"

    payload = {
        "streams": [{
            "stream": {"job": "ftso-monitor-agent", "level": level},
            "values": [[ts_ns, entry]],
        }]
    }
    try:
        resp = requests.post(
            f"{LOKI_URL}/loki/api/v1/push",
            json=payload,
            timeout=5,
        )
        resp.raise_for_status()
    except Exception as exc:
        logger.warning("Loki push failed (poll NOT recorded): %s", exc)


# ── Poll cycle ─────────────────────────────────────────────────────────────────

def _poll_once(interactive: bool, counts: dict[str, int]) -> None:
    """Run one full poll cycle. Logs all errors; never raises."""
    try:
        snapshot = scraper.scrape(metrics_url=METRICS_URL)
    except Exception as exc:
        logger.error("Scraper raised unexpectedly: %s", exc, exc_info=True)
        return

    if not snapshot["scrape_ok"]:
        logger.warning("Scrape failed: %s", snapshot.get("error"))
        return

    alerts = classifier.classify(
        snapshot,
        band_threshold=scraper.BAND_THRESHOLD,
        approach_threshold=scraper.APPROACH_THRESHOLD,
    )
    _update_alert_counts(alerts, counts)

    if PROPOSALS_DIR:
        for a in alerts:
            if a.get("consecutive_polls", 0) >= 5:
                try:
                    prop = proposer.propose(a, snapshot, PROPOSALS_DIR)
                    if prop:
                        logger.info(
                            "Proposer: %s for %s (poll %d) — %s",
                            prop["recommendation"], prop["pair"],
                            prop["consecutive_polls"], prop["id"],
                        )
                except (RuntimeError, ValueError) as exc:
                    logger.warning(
                        "Proposer failed for %s: %s", a.get("pair"), exc
                    )

    try:
        written = llm_writer.write_actions(alerts)
    except RuntimeError as exc:
        logger.warning("LLM writer failed (%s) \u2014 using fallback actions.", exc)
        written = {
            "actions": {a["id"]: "Investigate manually." for a in alerts},
            "summary": "LLM unavailable \u2014 manual review required.",
            "latency_s": 0.0,
            "model": "fallback",
        }

    print(_format_report(snapshot, alerts, written), flush=True)

    _post_to_alertmanager(alerts)
    _push_to_loki(snapshot, alerts, written)

    if interactive and any(a["severity"] == "critical" for a in alerts):
        try:
            input("\n  [interactive] Press ENTER to continue (Ctrl-C to exit)...\n")
        except (EOFError, KeyboardInterrupt):
            logger.info("Interactive mode: exiting on interrupt.")
            sys.exit(0)


# ── Entry point ────────────────────────────────────────────────────────────────

def main() -> None:
    logging.basicConfig(
        level=os.getenv("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
        stream=sys.stdout,
    )

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

    # Consecutive-alert persistence — lifetime is this process, not the module.
    # Resets on container restart (expected — each run is a fresh baseline).
    counts: dict[str, int] = {}

    if args.once:
        _poll_once(interactive, counts)
        return

    def _on_sigterm(signum, frame):
        logger.info("Received SIGTERM - shutting down.")
        sys.exit(0)

    signal.signal(signal.SIGTERM, _on_sigterm)

    while True:
        _poll_once(interactive, counts)
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
