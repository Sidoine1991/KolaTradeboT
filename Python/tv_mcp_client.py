# -*- coding: utf-8 -*-
"""Client Python pour analyses TradingView via tradingview-mcp_kola (Node + CDP)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Optional

_TRADBOT_ROOT = Path(__file__).resolve().parent.parent
_TV_MCP_ROOT = Path(
    os.getenv("TV_MCP_ROOT", r"D:\Dev\Depot Github\tradingview-mcp_kola")
)
_CLI = _TRADBOT_ROOT / "scripts" / "tv_analyze_cli.mjs"
_TIMEOUT = int(os.getenv("TV_ANALYZE_TIMEOUT_SEC", "120"))

# Symbole MT5 / bridge -> symbole graphique TradingView
_MT5_TO_TV: Dict[str, str] = {
    "XAUUSD": "XAUUSD",
    "GOLD": "XAUUSD",
    "OR": "XAUUSD",
    "BTCUSD": "BTCUSD",
    "BITCOIN": "BTCUSD",
    "BOOM 300 INDEX": "BOOM300",
    "BOOM 500 INDEX": "BOOM500",
    "BOOM 600 INDEX": "BOOM600",
    "BOOM 900 INDEX": "BOOM900",
    "BOOM 1000 INDEX": "BOOM1000",
    "CRASH 300 INDEX": "CRASH300",
    "CRASH 500 INDEX": "CRASH500",
    "CRASH 600 INDEX": "CRASH600",
    "CRASH 900 INDEX": "CRASH900",
    "CRASH 1000 INDEX": "CRASH1000",
}


def mt5_to_tv_symbol(symbol: str) -> str:
    s = symbol.strip().upper()
    for k, v in _MT5_TO_TV.items():
        if k in s or s == k.replace(" ", ""):
            return v
    return s.split()[0] if s else "XAUUSD"


def fetch_tradingview_analysis(
    symbol: str,
    mode: str = "both",
) -> Dict[str, Any]:
    """
    Lance l'analyse SMC/spike via Node (TradingView Desktop + CDP).
    Retourne dict avec smc, spike, success, error.
    """
    if not _CLI.exists():
        return {
            "success": False,
            "error": f"CLI introuvable: {_CLI}",
            "symbol": symbol,
        }

    tv_sym = mt5_to_tv_symbol(symbol)
    env = os.environ.copy()
    env["TV_MCP_ROOT"] = str(_TV_MCP_ROOT)

    try:
        proc = subprocess.run(
            ["node", str(_CLI), tv_sym, mode],
            capture_output=True,
            text=True,
            timeout=_TIMEOUT,
            cwd=str(_TV_MCP_ROOT),
            env=env,
        )
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "error": f"Timeout {_TIMEOUT}s — TradingView/CDP non joignable?",
            "symbol": tv_sym,
        }
    except FileNotFoundError:
        return {"success": False, "error": "Node.js introuvable", "symbol": tv_sym}

    raw = (proc.stdout or "").strip()
    if not raw:
        return {
            "success": False,
            "error": (proc.stderr or "sortie vide").strip()[:500],
            "symbol": tv_sym,
            "returncode": proc.returncode,
        }

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        return {
            "success": False,
            "error": f"JSON invalide: {e}",
            "symbol": tv_sym,
            "raw_tail": raw[-400:],
        }

    data["mt5_symbol"] = symbol
    data["tv_symbol"] = tv_sym
    return data


def summarize_tv_analysis(tv: Dict[str, Any]) -> Dict[str, Any]:
    """Résumé exploitable pour fusion / WhatsApp / Word."""
    smc = tv.get("smc") or {}
    spike = tv.get("spike") or {}
    bias = smc.get("bias") or {}
    setup = smc.get("entry_setup") or {}

    direction = (bias.get("direction") or "NEUTRAL").upper()
    if direction == "NEUTRAL" and setup.get("valid"):
        direction = (setup.get("direction") or "NEUTRAL").upper()

    spike_sig = spike.get("signal") or "NONE"
    if spike.get("spike_detected") and "BUY" in spike_sig:
        spike_dir = "BUY"
    elif spike.get("spike_detected") and "SELL" in spike_sig:
        spike_dir = "SELL"
    else:
        spike_dir = "NEUTRAL"

    return {
        "success": bool(tv.get("success")),
        "symbol": tv.get("tv_symbol") or tv.get("symbol"),
        "direction": direction,
        "bias_score": bias.get("score"),
        "bias_reasons": bias.get("reasons") or [],
        "confluence_score": setup.get("confluence_score"),
        "entry_valid": setup.get("valid", False),
        "entry_price": setup.get("entry_price"),
        "stop_loss": setup.get("stop_loss"),
        "take_profit": setup.get("take_profit"),
        "current_price": smc.get("current_price"),
        "structure_m15": (smc.get("structure_m15") or {}).get("trend"),
        "structure_h1": (smc.get("structure_h1") or {}).get("trend"),
        "spike_detected": spike.get("spike_detected", False),
        "spike_z": spike.get("z_score"),
        "spike_direction": spike_dir,
        "error": tv.get("error"),
    }
