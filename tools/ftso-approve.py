#!/usr/bin/env python3
"""
ftso-approve — FTSO feed change proposal executor

Reads proposals from PROPOSALS_DIR (written by the monitor agent's proposer)
and allows the operator to approve or reject them.

Approval executes: feeds.json edit -> FEEDS_CHANGES.md update ->
git commit -> provider rebuild -> watchlist update -> mark approved.

Sub-commands:
  list                  Show pending proposals
  show <id>             Full detail + live stale check
  approve <id>          Apply the proposal (--force skips stale check)
  reject  <id>          Discard without action
  watch-check           Show watchlisted exchanges with current pair state

Design constraints:
  - No exec, no eval
  - All subprocess calls use list form — shell=True never used
  - No silent failures — all errors raise or print+exit(1)
  - No module-level mutable state
  - Explicit, traceable initialization
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

logger = logging.getLogger("ftso-approve")

_DD = "/home/sbadakhc/src/github.com/Digital-Dynamics/dd-ftso-v2-provider"
_SVC = "/home/sbadakhc/src/github.com/sbadakhc/aixcl/services"

PROPOSALS_DIR: str = os.getenv("PROPOSALS_DIR", "/home/sbadakhc/ftso-proposals")
FEEDS_JSON: str = os.getenv("FEEDS_JSON", f"{_DD}/src/config/feeds.json")
FEEDS_CHANGES_MD: str = os.getenv("FEEDS_CHANGES_MD", f"{_DD}/FEEDS_CHANGES.md")
PROVIDER_DIR: str = os.getenv("PROVIDER_DIR", _DD)
COMPOSE_DIR: str = os.getenv("COMPOSE_DIR", _SVC)
METRICS_URL: str = os.getenv("METRICS_URL", "http://localhost:9102/metrics")


# ── Proposal I/O ──────────────────────────────────────────────────────────────

def _load_proposals(
    proposals_dir: str, status_filter: str | None = None
) -> list[dict[str, Any]]:
    """
    Load all proposal JSON files from proposals_dir.
    Skips watchlist.json and files that fail to parse (logged as warning).
    Raises OSError if proposals_dir is not accessible.
    """
    path = Path(proposals_dir)
    if not path.exists():
        return []
    proposals = []
    for f in sorted(path.glob("*.json")):
        if f.name == "watchlist.json":
            continue
        try:
            data = json.loads(f.read_text())
        except (json.JSONDecodeError, OSError) as exc:
            logger.warning("Could not read proposal %s: %s", f.name, exc)
            continue
        if status_filter is None or data.get("status") == status_filter:
            proposals.append(data)
    return proposals


def _load_proposal(proposal_id: str, proposals_dir: str) -> dict[str, Any]:
    """
    Load a specific proposal by ID.
    Raises FileNotFoundError if not found.
    Raises ValueError if the file cannot be parsed.
    """
    path = Path(proposals_dir) / f"{proposal_id}.json"
    if not path.exists():
        raise FileNotFoundError(
            f"Proposal not found: {proposal_id}\nLooked in: {proposals_dir}"
        )
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"Proposal file is corrupt: {path}: {exc}") from exc


def _save_proposal(proposal: dict[str, Any], proposals_dir: str) -> None:
    """Write a proposal back to disk after a status update. Raises OSError on failure."""
    path = Path(proposals_dir) / f"{proposal['id']}.json"
    path.write_text(json.dumps(proposal, indent=2))


# ── Stale check ───────────────────────────────────────────────────────────────

def _is_pair_out_of_band(pair: str, metrics_url: str) -> bool | None:
    """
    Check whether a pair is currently out of band in provider metrics.
    Returns True if out of band, False if resolved, None if unreachable.
    Matches ftso_within_primary_band{...pair="X"...source="anchor"...} 0
    regardless of label ordering.
    """
    try:
        resp = requests.get(metrics_url, timeout=5)
        resp.raise_for_status()
    except Exception as exc:
        logger.warning("Stale check: metrics fetch failed: %s", exc)
        return None
    for line in resp.text.splitlines():
        if not line.startswith("ftso_within_primary_band{"):
            continue
        if f'pair="{pair}"' not in line or 'source="anchor"' not in line:
            continue
        parts = line.split("}")
        if len(parts) < 2:
            continue
        try:
            if float(parts[1].strip().split()[0]) == 0.0:
                return True
        except (ValueError, IndexError):
            continue
    return False


# ── Feeds.json ────────────────────────────────────────────────────────────────

def _load_feeds(feeds_path: str) -> list[dict[str, Any]]:
    """
    Load feeds.json as a list.
    Raises FileNotFoundError if path does not exist.
    Raises ValueError if JSON is malformed.
    """
    path = Path(feeds_path)
    if not path.exists():
        raise FileNotFoundError(f"feeds.json not found: {feeds_path}")
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"feeds.json is malformed: {feeds_path}: {exc}") from exc


def _remove_source(
    feeds: list[dict[str, Any]], pair: str, source: str
) -> tuple[list[dict[str, Any]], str]:
    """
    Remove a source from a pair entry in feeds.
    Returns (modified_feeds, removed_symbol).
    Raises ValueError if pair or source is not found.
    Does not write to disk — caller persists the result.
    """
    entry = next((e for e in feeds if e["feed"]["name"] == pair), None)
    if entry is None:
        raise ValueError(f"Pair {pair!r} not found in feeds.json")
    src_entry = next(
        (s for s in entry["sources"] if s["exchange"] == source), None
    )
    if src_entry is None:
        raise ValueError(
            f"Source {source!r} not found for pair {pair!r} in feeds.json"
        )
    removed_symbol: str = src_entry["symbol"]
    entry["sources"] = [s for s in entry["sources"] if s["exchange"] != source]
    return feeds, removed_symbol


def _write_feeds(feeds: list[dict[str, Any]], feeds_path: str) -> None:
    """Write feeds list back to feeds.json with trailing newline. Raises OSError on failure."""
    Path(feeds_path).write_text(json.dumps(feeds, indent=2) + "\n")


# ── FEEDS_CHANGES.md ──────────────────────────────────────────────────────────

def _append_feeds_changes(
    changes_path: str, pair: str, change: str, reason: str
) -> None:
    """
    Append a row to the change log table in FEEDS_CHANGES.md.
    Raises FileNotFoundError if the file does not exist.
    Raises RuntimeError if the change log table cannot be located.
    """
    path = Path(changes_path)
    if not path.exists():
        raise FileNotFoundError(f"FEEDS_CHANGES.md not found: {changes_path}")
    content = path.read_text()
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    new_row = f"| {pair} | {change} | {reason[:80]} | {date_str} | ftso-approve |"
    lines = content.splitlines()
    last_table_line = max(
        (i for i, ln in enumerate(lines) if ln.startswith("| ") and "/" in ln),
        default=None,
    )
    if last_table_line is None:
        raise RuntimeError(
            "Could not locate the change log table in FEEDS_CHANGES.md"
        )
    lines.insert(last_table_line + 1, new_row)
    path.write_text("\n".join(lines) + "\n")


# ── Watchlist ─────────────────────────────────────────────────────────────────

def _load_watchlist(proposals_dir: str) -> list[dict[str, Any]]:
    """Load watchlist.json; returns empty list if file does not exist."""
    path = Path(proposals_dir) / "watchlist.json"
    if not path.exists():
        return []
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"watchlist.json is corrupt in {proposals_dir}: {exc}"
        ) from exc


def _save_watchlist(watchlist: list[dict[str, Any]], proposals_dir: str) -> None:
    """Write watchlist.json. Raises OSError on failure."""
    (Path(proposals_dir) / "watchlist.json").write_text(
        json.dumps(watchlist, indent=2) + "\n"
    )


def _add_to_watchlist(
    proposals_dir: str, pair: str, source: str, symbol: str, reason: str
) -> None:
    """
    Add a removed exchange to the watchlist or increment its removal_count.
    At removal_count >= 3 the status is set to 'manual_only'.
    Raises ValueError if watchlist is corrupt; OSError on write failure.
    """
    watchlist = _load_watchlist(proposals_dir)
    now = datetime.now(timezone.utc).isoformat()
    existing = next(
        (e for e in watchlist if e["pair"] == pair and e["source"] == source), None
    )
    if existing:
        existing["removal_count"] = existing.get("removal_count", 1) + 1
        existing["last_removed_at"] = now
        existing["status"] = (
            "manual_only" if existing["removal_count"] >= 3 else "watching"
        )
    else:
        watchlist.append({
            "pair": pair,
            "source": source,
            "symbol": symbol,
            "first_removed_at": now,
            "last_removed_at": now,
            "removal_reason": reason,
            "removal_count": 1,
            "status": "watching",
        })
    _save_watchlist(watchlist, proposals_dir)


# ── Git / Docker ──────────────────────────────────────────────────────────────

def _run(cmd: list[str], cwd: str, description: str) -> str:
    """
    Run a subprocess command with list form (shell=True never used).
    Returns stdout on success.
    Raises RuntimeError with stderr on non-zero exit.
    """
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"{description} failed (exit {result.returncode}):\n{result.stderr}"
        )
    return result.stdout


def _git_commit(provider_dir: str, files: list[str], message: str) -> None:
    """Stage files and commit. Raises RuntimeError if either step fails."""
    _run(["git", "add"] + files, cwd=provider_dir, description="git add")
    _run(["git", "commit", "-m", message], cwd=provider_dir, description="git commit")


def _rebuild_provider(compose_dir: str) -> None:
    """Build and restart ftso-v2-provider. Raises RuntimeError on failure."""
    _run(
        ["docker", "compose", "-f", "docker-compose.yml", "build", "ftso-v2-provider"],
        cwd=compose_dir, description="docker compose build",
    )
    _run(
        ["docker", "compose", "-f", "docker-compose.yml", "up", "-d", "ftso-v2-provider"],
        cwd=compose_dir, description="docker compose up",
    )


# ── Sub-commands ──────────────────────────────────────────────────────────────

def cmd_list(proposals_dir: str) -> None:
    """Print a table of pending proposals."""
    proposals = _load_proposals(proposals_dir, status_filter="pending")
    if not proposals:
        print("No pending proposals.")
        return
    print(f"\n{'ID':<58} {'PAIR':<12} {'TYPE':<18} {'SEV':<10} POLLS")
    print("-" * 108)
    for p in proposals:
        flag = " [low-confidence]" if p.get("low_confidence") else ""
        print(
            f"{p['id']:<58} {p['pair']:<12} {p['recommendation']:<18} "
            f"{p['severity']:<10} {p['consecutive_polls']}{flag}"
        )
    print()


def cmd_show(proposal_id: str, proposals_dir: str, metrics_url: str) -> None:
    """Print full proposal detail with live stale check."""
    p = _load_proposal(proposal_id, proposals_dir)
    print(f"\n{'=' * 72}")
    print(f"  Proposal : {p['id']}")
    print(f"{'=' * 72}")
    print(f"  Created    : {p['created_at']}")
    print(f"  Status     : {p['status']}")
    print(f"  Pair       : {p['pair']}")
    print(f"  Issue type : {p['issue_type']}")
    print(f"  Severity   : {p['severity']}")
    print(f"  Polls      : {p['consecutive_polls']}")
    if p.get("deviation_pct") is not None:
        print(f"  Deviation  : {p['deviation_pct']:+.4f}% vs anchor")
    if p.get("low_confidence"):
        print(
            f"  \u26a0  LOW CONFIDENCE \u2014 anchor had "
            f"{p['anchor_errors_at_creation']} error(s) at creation"
        )
    print(f"\n  Recommendation : {p['recommendation']}")
    if p.get("target_source"):
        print(f"  Target source  : {p['target_source']}")
    if p.get("outlier_delta_from_median") is not None:
        print(f"  Outlier delta  : {p['outlier_delta_from_median']:+.4f}% from peer median")
    print(f"\n  Reason: {p['reason']}")
    if p.get("source_deviations"):
        print("\n  Source deviations at proposal time:")
        for src, dev in sorted(p["source_deviations"].items(), key=lambda x: x[1]):
            marker = "  \u2190 outlier" if src == p.get("target_source") else ""
            print(f"    {src:<16} {dev:+.4f}%{marker}")
    print(f"\n  Current state ({metrics_url}):")
    state = _is_pair_out_of_band(p["pair"], metrics_url)
    if state is None:
        print("    \u26a0  Metrics unreachable \u2014 cannot verify current state")
    elif state:
        print(f"    \u2717  {p['pair']} is still out of band")
    else:
        print(
            f"    \u2713  {p['pair']} is currently in band \u2014 "
            "situation may have resolved (use --force to approve anyway)"
        )
    print(f"{'=' * 72}\n")


def cmd_approve(
    proposal_id: str,
    proposals_dir: str,
    feeds_json: str,
    feeds_changes_md: str,
    provider_dir: str,
    compose_dir: str,
    metrics_url: str,
    force: bool,
) -> None:
    """
    Apply a proposal: edit feeds.json -> FEEDS_CHANGES.md -> git commit ->
    rebuild provider -> watchlist update -> mark approved.

    Supports: remove_source (actionable), investigate / investigate_pair
    (advisory acknowledgement only).
    Raises ValueError for unrecognised recommendation types.
    Raises RuntimeError if any step fails.
    """
    proposal = _load_proposal(proposal_id, proposals_dir)
    if proposal["status"] != "pending":
        print(
            f"Proposal {proposal_id} is already {proposal['status']} "
            "\u2014 nothing to do."
        )
        return

    if not force and proposal["recommendation"] == "remove_source":
        state = _is_pair_out_of_band(proposal["pair"], metrics_url)
        if state is False:
            print(
                f"\u26a0  {proposal['pair']} is currently in band \u2014 "
                "situation appears resolved.\nUse --force to apply anyway."
            )
            sys.exit(1)
        if state is None:
            print(
                "\u26a0  Cannot verify current state (metrics unreachable).\n"
                "Use --force to skip stale check."
            )
            sys.exit(1)

    rec = proposal["recommendation"]

    if rec == "remove_source":
        pair = proposal["pair"]
        source = proposal["target_source"]
        if not source:
            raise ValueError(
                f"Proposal {proposal_id} has recommendation=remove_source "
                "but no target_source \u2014 cannot apply"
            )
        print(f"Removing {source} from {pair} in feeds.json ...")
        feeds = _load_feeds(feeds_json)
        feeds, removed_symbol = _remove_source(feeds, pair, source)
        remaining = next(
            (e for e in feeds if e["feed"]["name"] == pair), {}
        ).get("sources", [])
        print(f"  Remaining: {[s['exchange'] for s in remaining]}")
        _write_feeds(feeds, feeds_json)
        print("  feeds.json updated.")

        _append_feeds_changes(
            feeds_changes_md, pair,
            f"Removed {source} ({removed_symbol})",
            proposal["reason"],
        )
        print("  FEEDS_CHANGES.md updated.")

        commit_msg = (
            f"Remove {source} from {pair} \u2014 persistent outlier (ftso-approve)\n\n"
            f"Proposal: {proposal_id}\n"
            f"Reason: {proposal['reason']}\n\n"
            "Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
        )
        print(f"Committing to {provider_dir} ...")
        _git_commit(
            provider_dir,
            files=["src/config/feeds.json", "FEEDS_CHANGES.md"],
            message=commit_msg,
        )
        print("  Committed.")

        print("Rebuilding ftso-v2-provider ...")
        _rebuild_provider(compose_dir)
        print("  Provider rebuilt and restarted.")

        print("Updating watchlist ...")
        _add_to_watchlist(
            proposals_dir,
            pair=pair, source=source, symbol=removed_symbol,
            reason=proposal["reason"],
        )
        print(f"  {source} added to watchlist.")

    elif rec in ("investigate", "investigate_pair"):
        print(
            f"Acknowledging advisory proposal {proposal_id}.\n"
            "No feed change applied \u2014 investigate-only proposal."
        )
    else:
        raise ValueError(
            f"Unsupported recommendation: {rec!r}\n"
            "Only remove_source and investigate* proposals can be approved."
        )

    proposal["status"] = "approved"
    proposal["approved_at"] = datetime.now(timezone.utc).isoformat()
    _save_proposal(proposal, proposals_dir)
    print(f"\n\u2713 Proposal {proposal_id} approved.")


def cmd_reject(proposal_id: str, proposals_dir: str) -> None:
    """Discard a proposal without applying any change."""
    proposal = _load_proposal(proposal_id, proposals_dir)
    if proposal["status"] != "pending":
        print(
            f"Proposal {proposal_id} is already {proposal['status']} "
            "\u2014 nothing to do."
        )
        return
    proposal["status"] = "rejected"
    proposal["rejected_at"] = datetime.now(timezone.utc).isoformat()
    _save_proposal(proposal, proposals_dir)
    print(f"Proposal {proposal_id} rejected.")


def cmd_watch_check(proposals_dir: str, metrics_url: str) -> None:
    """
    Print the watchlist with current pair state from live metrics.
    Flags exchanges where the pair is now clean as potentially re-addable.
    Re-addition is manual: edit feeds.json, update FEEDS_CHANGES.md, rebuild.
    """
    watchlist = _load_watchlist(proposals_dir)
    if not watchlist:
        print("Watchlist is empty.")
        return
    print(
        f"\n{'PAIR':<12} {'SOURCE':<14} {'STATUS':<14} "
        f"{'REMOVALS':<10} {'LAST REMOVED':<22} PAIR STATE"
    )
    print("-" * 95)
    for e in watchlist:
        state = _is_pair_out_of_band(e["pair"], metrics_url)
        if state is None:
            pair_state = "metrics N/A"
        elif state:
            pair_state = "still out-of-band"
        else:
            pair_state = "\u2713 in band"
            if e["status"] == "watching":
                pair_state += " \u2014 consider re-add"
        if e["status"] == "manual_only":
            pair_state += "  [MANUAL ONLY \u2014 3+ removals]"
        print(
            f"{e['pair']:<12} {e['source']:<14} {e['status']:<14} "
            f"{e.get('removal_count', 1):<10} "
            f"{e.get('last_removed_at', '')[:19]:<22} {pair_state}"
        )
    print(
        "\nTo re-add: edit feeds.json, append to FEEDS_CHANGES.md, "
        "then rebuild the provider.\n"
    )


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    logging.basicConfig(
        level=os.getenv("LOG_LEVEL", "WARNING"),
        format="%(levelname)s %(message)s",
        stream=sys.stderr,
    )
    parser = argparse.ArgumentParser(
        prog="ftso-approve",
        description="FTSO feed change proposal executor",
    )
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list", help="Show pending proposals")
    p_show = sub.add_parser("show", help="Full proposal detail + stale check")
    p_show.add_argument("id", help="Proposal ID")
    p_approve = sub.add_parser("approve", help="Apply a proposal")
    p_approve.add_argument("id", help="Proposal ID")
    p_approve.add_argument(
        "--force", action="store_true",
        help="Skip stale check and apply even if pair is currently in band",
    )
    p_reject = sub.add_parser("reject", help="Discard a proposal without action")
    p_reject.add_argument("id", help="Proposal ID")
    sub.add_parser("watch-check", help="Show watchlisted exchanges with current state")

    args = parser.parse_args()
    try:
        if args.command == "list":
            cmd_list(PROPOSALS_DIR)
        elif args.command == "show":
            cmd_show(args.id, PROPOSALS_DIR, METRICS_URL)
        elif args.command == "approve":
            cmd_approve(
                proposal_id=args.id,
                proposals_dir=PROPOSALS_DIR,
                feeds_json=FEEDS_JSON,
                feeds_changes_md=FEEDS_CHANGES_MD,
                provider_dir=PROVIDER_DIR,
                compose_dir=COMPOSE_DIR,
                metrics_url=METRICS_URL,
                force=args.force,
            )
        elif args.command == "reject":
            cmd_reject(args.id, PROPOSALS_DIR)
        elif args.command == "watch-check":
            cmd_watch_check(PROPOSALS_DIR, METRICS_URL)
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
    except (ValueError, RuntimeError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(0)


if __name__ == "__main__":
    main()
