"""
Agent 7 — TradingAgents Deep Analyst

Identifies the most promising symbol from the timing agent's ranked entries,
runs a full TradingAgents pipeline on that symbol via tradbot_bridge.run_quick(),
then exposes the structured result so all other agents can consume it.

Peer consumers:
  - timing   : ta_confidence_boost (+5 to +15 pts) and ta_direction confirm
  - risk     : ta_win_rate_override (expert WR when pattern data is thin)
  - regime   : ta_bias per symbol (reinforces or weakens regime assessment)
  - news     : not consumed (news agent already fetches its own sources)

Output schema:
{
    "symbol":            str,          # symbol analysed
    "ticker":            str,          # TradingAgents ticker (GC=F, BOOM900…)
    "direction":         str,          # "BUY" | "SELL" | "HOLD"
    "raw_rating":        str,          # raw signal from TradingAgents
    "confidence":        float,        # 0.0 – 1.0 (derived from analyst consensus)
    "entry_price":       float | None,
    "stop_loss":         float | None,
    "take_profit":       float | None,
    "expert_analysis":   str,          # Claude scalping narrative
    "market_report":     str,          # TA market report snippet
    "trade_decision":    str,          # TA final decision snippet
    "indicators":        dict,         # RSI, ATR, MACD, BB, SMA from ai_server
    "ta_confidence_boost": float,      # pts to add in timing score (0, 5, 10, or 15)
    "ta_win_rate_override": float,     # WR % for risk agent (0 = no override)
    "ta_bias":           str,          # "BULLISH" | "BEARISH" | "NEUTRAL"
    "analysts_used":     list[str],
    "run_duration_s":    float,
    "error":             str,          # non-empty if run failed
}
"""

import os
import sys
import time
import logging
import subprocess
import json
from pathlib import Path
from typing import Any, Dict, List, Optional

from .agent_base import AgentBase

logger = logging.getLogger("agent.trading_agents")

# --- paths ------------------------------------------------------------------
_TRADBOT_ROOT = Path(__file__).resolve().parent.parent
_BRIDGE_SCRIPT = _TRADBOT_ROOT / "Python" / "tradbot_bridge.py"
_TA_VENV_PY    = Path(
    os.getenv(
        "TA_VENV_PYTHON",
        r"D:\Dev\Depot Github\TradingAgents-main\.venv\Scripts\python.exe",
    )
)

# Analysts to use (fast subset — market analyst runs in ~2 min)
_DEFAULT_ANALYSTS = os.getenv("TA7_ANALYSTS", "market,fundamentals")

# How many bars of peer-data to wait before first run
_WARMUP_CYCLES = 2

# Fallback symbol when GOM/timing has no entries yet
_FALLBACK_SYMBOL = os.getenv("TA7_FALLBACK_SYMBOL", "XAUUSD")


# Synthetic indices — TradingAgents has no fundamental/news data for these,
# and the Deriv API fetch times out inside the LLM pipeline.
_SYNTHETIC_PREFIXES = (
    "BOOM", "CRASH", "STEP INDEX", "JUMP", "RANGE BREAK",
    "VOLATILITY", "1HZ", "R_", "RDBULL", "RDBEAR",
)

def _is_synthetic(symbol: str) -> bool:
    up = symbol.upper()
    return any(up.startswith(p.upper()) or p.upper() in up for p in _SYNTHETIC_PREFIXES)


# ---------------------------------------------------------------------------
# Helper: pick the best symbol from timing agent output
# ---------------------------------------------------------------------------

def _pick_target(timing_out: Dict, correlation_out: Dict) -> Optional[str]:
    """
    Choose the highest-value *TA-compatible* symbol to deep-analyse.
    Skips synthetic indices (BOOM/CRASH/STEP/JUMP/VOL) which cause
    TradingAgents bridge timeouts due to missing fundamental/news data.

    Priority order:
      1. top_entry symbol if not synthetic
      2. first non-synthetic symbol in best_entries
      3. first non-synthetic symbol in correlation leaders
    Returns None when no compatible symbol is found.
    """
    top = timing_out.get("top_entry") or {}
    sym = top.get("symbol", "")
    if sym and not _is_synthetic(sym):
        return sym

    best = timing_out.get("best_entries", [])
    for entry in best:
        s = entry.get("symbol", "")
        if s and not _is_synthetic(s):
            return s

    leaders = correlation_out.get("leaders", [])
    for leader in leaders:
        s = leader.get("symbol", "")
        if s and not _is_synthetic(s):
            return s

    return None


def _normalize_direction(raw: str) -> str:
    raw = str(raw).strip().upper()
    if raw in ("BUY", "OVERWEIGHT"):
        return "BUY"
    if raw in ("SELL", "UNDERWEIGHT"):
        return "SELL"
    return "HOLD"


def _estimate_confidence(final_state: Dict) -> float:
    """
    Derive a 0-1 confidence score from TradingAgents internal fields.
    Falls back to 0.60 when the fields are absent.
    """
    decision = str(final_state.get("final_trade_decision") or "")
    plan     = str(final_state.get("trader_investment_plan") or "")
    text     = decision + " " + plan

    keywords_high   = ["strongly", "confident", "clear", "high conviction", "très confiant",
                       "fort signal", "conviction elevee"]
    keywords_medium = ["moderate", "reasonable", "acceptable", "modéré", "signal moyen"]
    keywords_low    = ["uncertain", "risky", "weak", "incertain", "faible", "risqué"]

    text_lower = text.lower()
    high   = sum(1 for k in keywords_high   if k in text_lower)
    medium = sum(1 for k in keywords_medium if k in text_lower)
    low    = sum(1 for k in keywords_low    if k in text_lower)

    if high >= 2:
        return 0.85
    if high >= 1 and low == 0:
        return 0.75
    if medium >= 1 and low == 0:
        return 0.65
    if low >= 1:
        return 0.50
    return 0.60


def _extract_bias(direction: str, confidence: float) -> str:
    if direction == "BUY"  and confidence >= 0.65:
        return "BULLISH"
    if direction == "SELL" and confidence >= 0.65:
        return "BEARISH"
    return "NEUTRAL"


def _confidence_to_pts(confidence: float, direction_matches: bool) -> float:
    """Convert TA confidence to timing bonus points."""
    if not direction_matches:
        return 0.0
    if confidence >= 0.80:
        return 15.0
    if confidence >= 0.70:
        return 10.0
    if confidence >= 0.60:
        return 5.0
    return 0.0


# ---------------------------------------------------------------------------
# Subprocess runner — calls tradbot_bridge via its own venv
# ---------------------------------------------------------------------------

def _run_bridge_subprocess(symbol: str, analysts: str) -> Dict[str, Any]:
    """
    Run tradbot_bridge.py in the TradingAgents venv and capture the JSON output.

    The bridge is called with --output-json so it prints a single JSON line
    to stdout before the Word report / WhatsApp steps.
    We patch it with --no-pending --no-whatsapp --auto so it never blocks.
    """
    if not _TA_VENV_PY.exists():
        return {"error": f"TradingAgents venv not found: {_TA_VENV_PY}"}
    if not _BRIDGE_SCRIPT.exists():
        return {"error": f"Bridge script not found: {_BRIDGE_SCRIPT}"}

    env = os.environ.copy()
    env["PYTHONHTTPSVERIFY"] = "0"
    env["REQUESTS_CA_BUNDLE"] = ""
    env["SSL_CERT_FILE"] = ""
    env["CURL_CA_BUNDLE"] = ""

    cmd = [
        str(_TA_VENV_PY),
        str(_BRIDGE_SCRIPT),
        "--symbol", symbol,
        "--analysts", analysts,
        "--no-pending",
        "--no-whatsapp",
        "--no-tv",
        "--auto",
        "--output-json",   # new flag we add to bridge (see patch below)
    ]

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,   # 2 min max (market+fundamentals analysts)
            env=env,
            cwd=str(_TRADBOT_ROOT),
        )
    except subprocess.TimeoutExpired as exc:
        # Capture whatever partial output was produced before timeout
        partial = (exc.stdout or "")[-300:] if exc.stdout else ""
        logger.warning("TradingAgents bridge timeout (120s) for %s. Last output: %s", symbol, partial)
        return {"error": "TradingAgents timeout (120s)", "stdout_tail": partial}
    except Exception as exc:
        return {"error": f"subprocess error: {exc}"}

    # Parse the JSON result line — bridge emits it last on stdout
    stdout = proc.stdout or ""
    for line in reversed(stdout.splitlines()):
        line = line.strip()
        if line.startswith("{") and line.endswith("}"):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                pass

    # Fallback: bridge did not emit JSON (old version without --output-json)
    # Try to extract key fields from text output
    return _parse_text_output(stdout, proc.returncode)


def _parse_text_output(stdout: str, returncode: int) -> Dict[str, Any]:
    """Minimal parser for bridge text output when JSON is unavailable."""
    import re
    result: Dict[str, Any] = {}

    m = re.search(r"Decision\s*:\s*(BUY|SELL|HOLD)", stdout, re.IGNORECASE)
    if m:
        result["direction"] = m.group(1).upper()

    m = re.search(r"Rating brut\s*:\s*(\S+)", stdout, re.IGNORECASE)
    if m:
        result["raw_rating"] = m.group(1)

    for label, key in [("Entry Price", "entry_price"),
                       ("Stop Loss",   "stop_loss"),
                       ("Take Profit", "take_profit")]:
        m = re.search(rf"{label}\s*[:\s]+([0-9]+(?:\.[0-9]+)?)", stdout, re.IGNORECASE)
        if m:
            try:
                result[key] = float(m.group(1))
            except ValueError:
                pass

    if returncode != 0 and not result:
        return {"error": f"Bridge exited {returncode}", "stdout_tail": stdout[-500:]}
    return result


# ---------------------------------------------------------------------------
# Main agent class
# ---------------------------------------------------------------------------

class TradingAgentsDeepAnalyst(AgentBase):
    """
    Agent 7 — deep-analyses the top symbol via the TradingAgents pipeline
    and broadcasts the result to peer agents via the standard output dict.
    """

    agent_id   = "trading_agents"
    agent_name = "TradingAgents Deep Analyst"
    description = (
        "Picks the most promising symbol from Agent 4 (timing), runs a full "
        "TradingAgents multi-analyst pipeline, and injects the enriched signal "
        "into all peer agents (confidence boost, WR override, directional bias)."
    )
    version = "1.0.0"
    # Run every 30 min — TradingAgents takes 2-4 min, so 30 min is a good cadence
    interval_seconds = int(os.getenv("TA7_INTERVAL_S", "1800"))

    def __init__(self):
        super().__init__()
        self._analysts = _DEFAULT_ANALYSTS
        self._warmup_done = False
        self._cycles_since_start = 0

    # ------------------------------------------------------------------
    # Core analysis
    # ------------------------------------------------------------------

    def analyze(self) -> Dict[str, Any]:
        self._cycles_since_start += 1

        # Wait for peer agents to have real data
        if self._cycles_since_start <= _WARMUP_CYCLES:
            logger.info(
                "TradingAgents agent warming up (%d/%d)", self._cycles_since_start, _WARMUP_CYCLES
            )
            return self._empty_result("warming_up")

        timing_out      = self.get_peer("timing")
        correlation_out = self.get_peer("correlation")

        symbol = _pick_target(timing_out, correlation_out)
        if not symbol:
            symbol = _FALLBACK_SYMBOL
            logger.info("TradingAgents: no peer target — using fallback symbol %s", symbol)

        logger.info("TradingAgents: running deep analysis on %s", symbol)
        t0 = time.time()

        raw = _run_bridge_subprocess(symbol, self._analysts)
        duration = round(time.time() - t0, 1)

        if raw.get("error"):
            logger.warning("TradingAgents bridge error for %s: %s", symbol, raw["error"])
            return self._empty_result(raw["error"], symbol=symbol, duration=duration)

        # --- Extract structured fields from bridge output ---
        final_state    = raw.get("final_state", {})
        indicators     = raw.get("indicators") or {}
        raw_rating     = str(raw.get("signal_rating") or raw.get("raw_rating") or "HOLD")
        direction      = _normalize_direction(raw.get("direction") or raw_rating)
        confidence     = raw.get("confidence") or _estimate_confidence(final_state)
        expert_text    = raw.get("expert_analysis", "")
        market_report  = str(final_state.get("market_report") or "")[:600]
        trade_decision = str(final_state.get("final_trade_decision") or "")[:600]

        # Entry levels — prefer bridge-computed, fallback to TA-proposed
        entry_price = (raw.get("entry_price")
                       or _safe_float(final_state.get("entry_price")))
        stop_loss   = (raw.get("stop_loss")
                       or _safe_float(final_state.get("stop_loss")))
        take_profit = (raw.get("take_profit")
                       or _safe_float(final_state.get("take_profit")))

        # Check direction match against timing agent
        top_entry = timing_out.get("top_entry") or {}
        timing_direction = _normalize_direction(top_entry.get("verdict", ""))
        direction_matches = (direction == timing_direction and direction in ("BUY", "SELL"))

        ta_confidence_boost = _confidence_to_pts(confidence, direction_matches)
        ta_win_rate_override = round(confidence * 100, 1) if direction in ("BUY", "SELL") else 0.0
        ta_bias = _extract_bias(direction, confidence)

        logger.info(
            "TradingAgents: %s → %s (conf=%.0f%% boost=+%.0fpts bias=%s) in %.1fs",
            symbol, direction, confidence * 100, ta_confidence_boost, ta_bias, duration,
        )

        return {
            "symbol":               symbol,
            "ticker":               raw.get("data_ticker", symbol),
            "direction":            direction,
            "raw_rating":           raw_rating,
            "confidence":           round(confidence, 2),
            "entry_price":          entry_price,
            "stop_loss":            stop_loss,
            "take_profit":          take_profit,
            "expert_analysis":      expert_text,
            "market_report":        market_report,
            "trade_decision":       trade_decision,
            "indicators":           indicators,
            "ta_confidence_boost":  ta_confidence_boost,
            "ta_win_rate_override": ta_win_rate_override,
            "ta_bias":              ta_bias,
            "analysts_used":        self._analysts.split(","),
            "run_duration_s":       duration,
            "error":                "",
        }

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _empty_result(reason: str = "", symbol: str = "", duration: float = 0.0) -> Dict:
        return {
            "symbol":               symbol,
            "ticker":               "",
            "direction":            "HOLD",
            "raw_rating":           "HOLD",
            "confidence":           0.0,
            "entry_price":          None,
            "stop_loss":            None,
            "take_profit":          None,
            "expert_analysis":      "",
            "market_report":        "",
            "trade_decision":       "",
            "indicators":           {},
            "ta_confidence_boost":  0.0,
            "ta_win_rate_override": 0.0,
            "ta_bias":              "NEUTRAL",
            "analysts_used":        [],
            "run_duration_s":       duration,
            "error":                reason,
        }


def _safe_float(val: Any) -> Optional[float]:
    try:
        return float(val) if val is not None else None
    except (TypeError, ValueError):
        return None
