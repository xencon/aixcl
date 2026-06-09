"""
proposer.py — FTSO Monitor Agent: proposal writer

At poll 5+ (persistent structural issue tier), analyses per-source
deviations to identify outlier exchanges and writes a proposal JSON to
PROPOSALS_DIR for operator review via ftso-approve.

Proposal types:
  remove_source     Single exchange is a statistical outlier vs peer median
  investigate       No single outlier — correlated drift or anchor issue
  investigate_pair  Pair has no data from provider (no_data alert)

Outlier detection uses median-of-sources (not anchor) to avoid flagging
all sources when the anchor reference itself drifts.

Watchlist updates are performed by ftso-approve at approval time, not
by the proposer — the proposer only writes proposal JSON.

Design constraints:
  - No exec, no eval, no runtime file rewriting
  - No silent failures — all errors raise with descriptive message
  - No module-level mutable state
  - Side effects (file write) only in named functions, never at import time
"""
from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timezone
from pathlib import Path
from statistics import median
from typing import Any

logger = logging.getLogger(__name__)

PROPOSALS_DIR: str = os.getenv("PROPOSALS_DIR", "/proposals")
BAND_THRESHOLD: float = float(os.getenv("BAND_THRESHOLD", "0.25"))
OUTLIER_MULTIPLE: float = float(os.getenv("OUTLIER_MULTIPLE", "2.0"))
MIN_SOURCES_FLOOR: int = int(os.getenv("MIN_SOURCES_FLOOR", "3"))
MAX_ANCHOR_ERRORS_BEFORE_FLAG: int = int(
    os.getenv("MAX_ANCHOR_ERRORS_BEFORE_FLAG", "0")
)


def identify_outlier(
    source_deviations: dict[str, float],
    band_threshold: float,
    outlier_multiple: float,
) -> tuple[str, float] | None:
    """
    Identify a single statistical outlier using median-of-sources.

    Flags an exchange if its deviation from the peer median exceeds
    outlier_multiple x band_threshold.  Returns (exchange, delta_from_median)
    if exactly one outlier is found; None if zero or multiple outliers exist
    (caller emits 'investigate' in those cases).

    Raises ValueError if fewer than two sources are provided.
    """
    if len(source_deviations) < 2:
        raise ValueError(
            f"Need at least 2 sources for outlier detection, "
            f"got {len(source_deviations)}: {list(source_deviations)}"
        )
    threshold = outlier_multiple * band_threshold
    med = median(source_deviations.values())
    outliers = [
        (src, dev)
        for src, dev in source_deviations.items()
        if abs(dev - med) > threshold
    ]
    if len(outliers) != 1:
        return None
    src, dev = outliers[0]
    return src, round(dev - med, 4)


def _proposal_id(pair: str, recommendation: str, source: str | None) -> str:
    """Generate a filesystem-safe, time-stamped proposal ID."""
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    pair_safe = pair.replace("/", "-")
    src_part = f"-{source}" if source else ""
    return f"{pair_safe}-{recommendation}{src_part}-{ts}"


def _pending_proposal_exists(pair: str, proposals_dir: str) -> bool:
    """Return True if a pending proposal already exists for this pair."""
    path = Path(proposals_dir)
    if not path.exists():
        return False
    for f in path.glob("*.json"):
        if f.name == "watchlist.json":
            continue
        try:
            data = json.loads(f.read_text())
        except (json.JSONDecodeError, OSError):
            continue
        if data.get("pair") == pair and data.get("status") == "pending":
            return True
    return False


def _write_proposal(proposal: dict[str, Any], proposals_dir: str) -> str:
    """
    Write proposal JSON to proposals_dir/<id>.json.
    Raises OSError if the directory cannot be created or file cannot be written.
    Returns the absolute file path written.
    """
    path = Path(proposals_dir)
    path.mkdir(parents=True, exist_ok=True)
    dest = path / f"{proposal['id']}.json"
    dest.write_text(json.dumps(proposal, indent=2))
    return str(dest)


def _get_source_deviations(pair: str, snapshot: dict[str, Any]) -> dict[str, float]:
    """
    Extract per-source deviations for a pair from the scraper snapshot.
    Searches out_of_band and approaching lists (scraper populates both).
    Returns empty dict if no per-source data is available for this pair.
    """
    for item in snapshot.get("out_of_band", []) + snapshot.get("approaching", []):
        if item.get("pair") == pair:
            return item.get("source_deviations", {})
    return {}


def propose(
    alert: dict[str, Any],
    snapshot: dict[str, Any],
    proposals_dir: str,
) -> dict[str, Any] | None:
    """
    Generate a proposal for a persistent alert (consecutive_polls >= 5).

    Returns the proposal dict if a new proposal was written.
    Returns None if consecutive_polls < 5 or a pending proposal already
    exists for this pair.

    Raises RuntimeError if the proposals directory cannot be written or
    outlier detection raises unexpectedly.
    Raises ValueError if alert is not a dict or is missing 'pair'.
    """
    if not isinstance(alert, dict):
        raise ValueError(f"alert must be a dict, got {type(alert)!r}")
    if alert.get("consecutive_polls", 0) < 5:
        return None
    pair = alert.get("pair")
    if not pair:
        raise ValueError(f"alert missing 'pair' field: {alert!r}")
    if _pending_proposal_exists(pair, proposals_dir):
        logger.debug(
            "Proposer: pending proposal already exists for %s \u2014 skipping", pair
        )
        return None

    issue_type = alert.get("issue_type", "")
    consecutive_polls = alert["consecutive_polls"]
    source_deviations = _get_source_deviations(pair, snapshot)
    anchor_errors = (
        snapshot.get("overall", {}).get("source_errors", {}).get("anchor", 0)
    )

    if issue_type == "no_data":
        recommendation, target_source, outlier_delta = "investigate_pair", None, None
        reason = (
            f"{pair} has had no provider price data for {consecutive_polls} "
            "consecutive polls \u2014 all sources may be unavailable or the "
            "asset was delisted."
        )

    elif not source_deviations or len(source_deviations) < 2:
        recommendation, target_source, outlier_delta = "investigate", None, None
        reason = (
            f"{pair} has been {issue_type.replace('_', ' ')} for "
            f"{consecutive_polls} consecutive polls but insufficient per-source "
            "data is available for outlier analysis."
        )

    else:
        source_count = len(source_deviations)
        try:
            outlier_result = identify_outlier(
                source_deviations, BAND_THRESHOLD, OUTLIER_MULTIPLE
            )
        except ValueError as exc:
            raise RuntimeError(
                f"Outlier detection failed for {pair}: {exc}"
            ) from exc

        if outlier_result is None:
            recommendation, target_source, outlier_delta = "investigate", None, None
            reason = (
                f"{pair} has been {issue_type.replace('_', ' ')} for "
                f"{consecutive_polls} consecutive polls with no single outlier "
                "\u2014 correlated drift or anchor issue suspected."
            )
        elif (source_count - 1) < MIN_SOURCES_FLOOR:
            recommendation = "investigate"
            target_source, outlier_delta = outlier_result
            reason = (
                f"{pair}: {target_source} is an outlier "
                f"({outlier_delta:+.4f}% from peer median) but removal would "
                f"leave only {source_count - 1} source(s) \u2014 below the "
                f"{MIN_SOURCES_FLOOR}-source minimum.  Manual review required."
            )
        else:
            recommendation = "remove_source"
            target_source, outlier_delta = outlier_result
            reason = (
                f"{target_source} is {outlier_delta:+.4f}% from peer median "
                f"for {consecutive_polls} consecutive polls \u2014 persistent outlier."
            )

    proposal: dict[str, Any] = {
        "id": _proposal_id(pair, recommendation, target_source),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "pair": pair,
        "issue_type": issue_type,
        "severity": alert.get("severity", "unknown"),
        "consecutive_polls": consecutive_polls,
        "deviation_pct": alert.get("deviation_pct"),
        "recommendation": recommendation,
        "target_source": target_source,
        "outlier_delta_from_median": outlier_delta,
        "reason": reason,
        "source_deviations": source_deviations,
        "anchor_errors_at_creation": anchor_errors,
        "low_confidence": anchor_errors > MAX_ANCHOR_ERRORS_BEFORE_FLAG,
        "status": "pending",
    }

    try:
        file_path = _write_proposal(proposal, proposals_dir)
    except OSError as exc:
        raise RuntimeError(
            f"Failed to write proposal for {pair} to {proposals_dir}: {exc}"
        ) from exc

    logger.info(
        "Proposer: wrote %s proposal for %s (poll %d) \u2014 %s",
        recommendation, pair, consecutive_polls, file_path,
    )
    return proposal
