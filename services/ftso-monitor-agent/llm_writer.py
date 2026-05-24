"""
llm_writer.py — FTSO Monitor Agent: LLM action writer

Calls the local Phi-3 model via Ollama to generate:
  - A concise action string per alert (what the operator should do)
  - A one-sentence overall summary

The LLM is NOT responsible for classification, arithmetic, or severity.
It only writes the human-readable action strings and summary.

Calibration decisions (from testing phi3:latest):
  - format: "json"  forces valid JSON output
  - temperature: 0.1  reduces hallucination
  - Few-shot example in system prompt guards against enum drift
  - Belt-and-braces: strip markdown fences before json.loads()
  - All failures raise RuntimeError — caller provides fallback

Design constraints:
  - No exec, no eval
  - No silent failure — raises with descriptive message
"""
from __future__ import annotations

import json
import logging
import os
import re
import time
from typing import Any

import requests

logger = logging.getLogger(__name__)

OLLAMA_URL: str = os.getenv("OLLAMA_URL", "http://localhost:11434")
OLLAMA_MODEL: str = os.getenv("OLLAMA_MODEL", "gemma4:latest")
OLLAMA_TIMEOUT: int = int(os.getenv("OLLAMA_TIMEOUT", "60"))

_SYSTEM_PROMPT = """\
You are a Flare Network FTSOv2 oracle provider operations assistant.
You receive a JSON list of alerts from an automated monitor.
Each alert has: id, pair, issue_type, severity, and context.

Your task is to output a JSON object with exactly two keys:
  "actions": an object mapping each alert id to a short action string (max 20 words).
  "summary": a single sentence (max 30 words) describing the overall situation.

Rules:
- Action strings must begin with a verb (e.g. "Check", "Remove", "Investigate", "Monitor").
- Do not include raw numbers or percentages — the context string already has them.
- Do not include markdown formatting or code fences.
- Output valid JSON only — no extra text before or after.

Example input:
[
  {"id": "RUNE/USD::out_of_band", "pair": "RUNE/USD", "issue_type": "out_of_band",
   "severity": "critical", "context": "RUNE/USD is 0.261% below anchor — outside the primary band by 0.011%."}
]

Example output:
{
  "actions": {
    "RUNE/USD::out_of_band": "Check RUNE/USD exchange sources and remove any delisted feed."
  },
  "summary": "One pair is outside the primary band and requires immediate source review."
}
"""


def _strip_fences(text: str) -> str:
    """Remove markdown code fences if the model added them despite instructions."""
    return re.sub(r"^```(?:json)?\s*|\s*```$", "", text.strip(), flags=re.MULTILINE)


def _call_ollama(prompt: str) -> tuple[str, float]:
    """POST to Ollama generate. Returns (raw_response, wall_seconds)."""
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "system": _SYSTEM_PROMPT,
        "format": "json",
        "stream": False,
        "options": {
            "temperature": 0.1,
            "num_predict": 512,
        },
    }
    t0 = time.monotonic()
    resp = requests.post(
        f"{OLLAMA_URL}/api/generate",
        json=payload,
        timeout=OLLAMA_TIMEOUT,
    )
    resp.raise_for_status()
    latency = round(time.monotonic() - t0, 2)
    data = resp.json()
    if "response" not in data:
        raise RuntimeError(f"Ollama response missing 'response' key: {data!r}")
    return data["response"], latency


def write_actions(alerts: list[dict[str, Any]]) -> dict[str, Any]:
    """
    Generate action strings and summary for the given alerts.

    Returns:
      {
        "actions": {alert_id: action_str, ...},
        "summary": str,
        "latency_s": float,
        "model": str,
      }

    Raises RuntimeError if Ollama is unreachable or returns unparseable output.
    Returns empty-action result immediately if alerts list is empty.
    """
    if not alerts:
        return {
            "actions": {},
            "summary": "No active alerts — provider is operating normally.",
            "latency_s": 0.0,
            "model": OLLAMA_MODEL,
        }

    # Send only the fields the LLM needs; omit deviation_pct (it's in context)
    llm_alerts = [
        {
            "id": a["id"],
            "pair": a["pair"],
            "issue_type": a["issue_type"],
            "severity": a["severity"],
            "context": a["context"],
        }
        for a in alerts
    ]

    try:
        raw, latency = _call_ollama(json.dumps(llm_alerts, indent=2))
    except requests.exceptions.RequestException as exc:
        raise RuntimeError(f"Ollama request failed: {exc}") from exc

    cleaned = _strip_fences(raw)
    try:
        parsed = json.loads(cleaned)
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"Ollama returned non-JSON (latency={latency}s): {cleaned!r}"
        ) from exc

    if not isinstance(parsed.get("actions"), dict):
        raise RuntimeError(f"Ollama response missing 'actions' dict: {parsed!r}")
    if not isinstance(parsed.get("summary"), str):
        raise RuntimeError(f"Ollama response missing 'summary' string: {parsed!r}")

    return {
        "actions": parsed["actions"],
        "summary": parsed["summary"],
        "latency_s": latency,
        "model": OLLAMA_MODEL,
    }
