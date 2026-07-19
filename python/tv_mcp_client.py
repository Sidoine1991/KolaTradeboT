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
    "GOLD BASKET": "XAUBASKET",
    "XAUBASKET": "XAUBASKET",
    "GOLDBASKET": "XAUBASKET",
    "BTCUSD": "BTCUSD",
    "BITCOIN": "BTCUSD",
    "EURUSD": "EURUSD",
    # Oil (le symbole exact dépend de ton broker/TV ; on garde une clé simple)
    "USOIL": "USOIL",
    "WTI": "USOIL",
    "XTIUSD": "USOIL",
    # Volatility indices (Deriv) — fallback générique "VOLATILITY"
    "VOLATILITY": "VOLATILITY",
    "VIX": "VIX",
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
    ai_server_url: str = "http://127.0.0.1:8000",
) -> Dict[str, Any]:
    """
    Récupère l'analyse TV complète pour le refiner.

    Stratégie (par ordre de priorité) :
      1. /bridge/mcp-study-values  → valeurs live des indicateurs GOM KOLA SIDO
                                     (RSI, BB, VWAP, score_buy/sell, spike_pct, OB, FVG…)
      2. /bridge/mcp-watchlist-scan → bias directionnel, structure, pine levels
      3. CLI Node tv_analyze_cli.mjs (si dispo) → SMC avancé H4/H1/M15/M1
    Tout est fusionné dans le format attendu par signal_refiner.py.
    """
    tv_sym = mt5_to_tv_symbol(symbol)

    # ── Source 1 : mcp-study-values (GOM KOLA SIDO + indicateurs live) ───────
    study_data: Dict = {}
    try:
        import requests as _req
        r1 = _req.post(f"{ai_server_url}/bridge/mcp-study-values",
                       json={"symbol": tv_sym}, timeout=10)
        if r1.status_code == 200 and r1.json().get("success"):
            # Prendre le premier study (GOM KOLA SIDO)
            studies = r1.json().get("studies", [])
            if studies:
                study_data = studies[0].get("values", {})
    except Exception:
        pass

    # ── Source 2 : mcp-watchlist-scan (bias, structure, pine levels) ──────────
    scan_data: Dict = {}
    try:
        import requests as _req
        r2 = _req.post(f"{ai_server_url}/bridge/mcp-watchlist-scan",
                       json={"symbols": [tv_sym]}, timeout=20)
        if r2.status_code == 200:
            results = r2.json().get("all_results", [])
            scan_data = results[0] if results else {}
    except Exception:
        pass

    # ── Source 3 : CLI Node (optionnel, SMC avancé multi-TF) ─────────────────
    cli_data: Dict = {}
    if _CLI.exists():
        env = os.environ.copy()
        env["TV_MCP_ROOT"] = str(_TV_MCP_ROOT)
        try:
            proc = subprocess.run(
                ["node", str(_CLI), tv_sym, mode],
                capture_output=True, text=True,
                timeout=min(_TIMEOUT, 30),
                cwd=str(_TV_MCP_ROOT), env=env,
            )
            raw = (proc.stdout or "").strip()
            if raw:
                cli_data = json.loads(raw)
        except Exception:
            pass

    # ── Fusion des 3 sources en format refiner ─────────────────────────────────
    has_data = bool(study_data or scan_data or cli_data)
    if not has_data:
        return {"success": False, "error": "Toutes les sources TV indisponibles", "symbol": tv_sym}

    # RSI : GOM KOLA SIDO (source la plus fiable)
    rsi_val = study_data.get("rsi")
    rsi_zone = ("overbought" if rsi_val and rsi_val > 70
                 else "oversold" if rsi_val and rsi_val < 30
                 else "bullish_zone" if rsi_val and rsi_val > 55
                 else "bearish_zone" if rsi_val and rsi_val < 45
                 else "neutral") if rsi_val else "neutral"

    # EMA stack : depuis CLI Node si dispo, sinon None (kola_buy/sell ne sont PAS des EMAs)
    bb_mid = study_data.get("bb_mid")
    vwap   = study_data.get("vwap")
    ema_stack = (cli_data.get("smc") or {}).get("ema_stack") or None

    # Biais directionnel : GOM score prime, puis scan, puis cli
    gom_verdict_num = study_data.get("verdict_num", 0)
    score_buy  = float(study_data.get("score_buy") or 0)
    score_sell = float(study_data.get("score_sell") or 0)
    entry_quality = float(study_data.get("entry_quality") or 0)
    coherence = float(study_data.get("coherence_pct") or 0)

    if gom_verdict_num > 0:
        bias_dir = "BUY"
    elif gom_verdict_num < 0:
        bias_dir = "SELL"
    else:
        bias_dir = (scan_data.get("bias") or {}).get("direction") or \
                   (cli_data.get("smc") or {}).get("bias", {}).get("direction") or "NEUTRAL"

    bias_score = round(max(score_buy, score_sell), 2) if (score_buy or score_sell) else \
                 float((scan_data.get("bias") or {}).get("score") or 0)

    bias_reasons = []
    if gom_verdict_num != 0:
        bias_reasons.append(f"GOM verdict {'haussier' if gom_verdict_num > 0 else 'baissier'} ({gom_verdict_num:+d})")
    if score_buy > 0:
        bias_reasons.append(f"Score BUY={score_buy:.1f}")
    if score_sell > 0:
        bias_reasons.append(f"Score SELL={score_sell:.1f}")
    if entry_quality > 0:
        bias_reasons.append(f"Qualité entrée={entry_quality:.0f}%")
    if coherence > 0:
        bias_reasons.append(f"Cohérence={coherence:.0f}%")
    if not bias_reasons:
        bias_reasons = (scan_data.get("bias") or {}).get("reasons") or []

    # Structure (depuis scan ou cli)
    struct_m15 = scan_data.get("structure_m15") or (cli_data.get("smc") or {}).get("structure_m15") or {}
    struct_h1  = scan_data.get("structure_h1")  or (cli_data.get("smc") or {}).get("structure_h1")  or {}

    # Order Blocks (depuis cli si dispo, sinon vide)
    obs = (cli_data.get("smc") or {}).get("order_blocks") or scan_data.get("order_blocks") or []

    # FVG (depuis cli si dispo)
    fvgs = (cli_data.get("smc") or {}).get("fvg") or scan_data.get("fvg") or []

    # Candle pattern (depuis cli ou scan)
    candle = (cli_data.get("smc") or {}).get("candle_pattern") or scan_data.get("candle_pattern") or ""

    # Pine levels (depuis cli si dispo)
    pine = (cli_data.get("smc") or {}).get("pine_levels") or []

    # Spike (depuis GOM spike_pct ou cli)
    spike_pct = float(study_data.get("spike_pct") or 0)
    spike_raw = cli_data.get("spike") or {}
    spike_detected = spike_pct > 50 or spike_raw.get("spike_detected", False)
    spike_z = spike_raw.get("z_score") or (round(spike_pct / 30, 2) if spike_pct > 0 else 0)

    # Prix actuel
    current_price = (
        scan_data.get("current_price") or
        float(study_data.get("bb_mid") or 0) or
        float(study_data.get("vwap") or 0)
    )

    # Construction du format final (compatible signal_refiner)
    smc_block = {
        "bias": {
            "direction": bias_dir,
            "score": bias_score,
            "reasons": bias_reasons,
        },
        "structure_m15": struct_m15 if isinstance(struct_m15, dict) else {"trend": str(struct_m15)},
        "structure_h1":  struct_h1  if isinstance(struct_h1, dict)  else {"trend": str(struct_h1)},
        "rsi": {"value": rsi_val, "zone": rsi_zone} if rsi_val else None,
        "ema_stack": ema_stack,
        "order_blocks": obs,
        "fvg": fvgs,
        "candle_pattern": candle,
        "pine_levels": pine,
        "current_price": current_price,
        # Données GOM brutes (pour scorecard rapport)
        "gom_score_buy":   score_buy,
        "gom_score_sell":  score_sell,
        "gom_verdict_num": gom_verdict_num,
        "entry_quality":   entry_quality,
        "coherence_pct":   coherence,
        "bb_upper": study_data.get("bb_up"),
        "bb_lower": study_data.get("bb_dn"),
        "vwap":     vwap,
        "st_dir":   study_data.get("st_dir"),
        "st_line":  study_data.get("st_line"),
    }

    return {
        "success": True,
        "symbol": tv_sym,
        "mt5_symbol": symbol,
        "smc": smc_block,
        "spike": {
            "spike_detected": spike_detected,
            "z_score": spike_z,
            "spike_pct": spike_pct,
            "signal": spike_raw.get("signal", "NONE"),
        },
        "sources_used": [s for s, d in [
            ("study_values", study_data),
            ("watchlist_scan", scan_data),
            ("cli_node", cli_data),
        ] if d],
    }


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
