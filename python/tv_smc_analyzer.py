#!/usr/bin/env python3
"""
tv_smc_analyzer.py — Analyse SMC multi-TF via TradingView MCP

Wrapper Python autour du script Node.js tv_smc_analyzer.mjs.
Mappe symbole MT5 → ticker TradingView, exécute l'analyse, retourne
structure SMC + confluence + setup d'entrée.

Usage:
    from tv_smc_analyzer import analyze_symbol
    result = analyze_symbol("Boom 500 Index")
    # ou direct:
    result = analyze_symbol("Crash 500 Index", full_output=False)
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Optional

MCP_NODE_ROOT = Path(r"D:\Dev\Depot Github\tradingview-mcp_kola")
ANALYZER_SCRIPT = MCP_NODE_ROOT / "scripts" / "tv_smc_analyzer.mjs"

# Mapping MT5 → TradingView CDP (identique à symbol_mapper.py)
_TV_CDP_TICKERS: Dict[str, str] = {
    "XAUUSD": "OANDA:XAUUSD",
    "XAGUSD": "OANDA:XAGUSD",
    "EURUSD": "OANDA:EURUSD",
    "GBPUSD": "OANDA:GBPUSD",
    "USDJPY": "OANDA:USDJPY",
    "USDCHF": "OANDA:USDCHF",
    "AUDUSD": "OANDA:AUDUSD",
    "NZDUSD": "OANDA:NZDUSD",
    "USDCAD": "OANDA:USDCAD",
    "BTCUSD": "BITSTAMP:BTCUSD",
    "ETHUSD": "BITSTAMP:ETHUSD",
    "Boom 300 Index": "DERIV:BOOM_300_INDEX",
    "Boom 500 Index": "DERIV:BOOM_500_INDEX",
    "Boom 600 Index": "DERIV:BOOM_600_INDEX",
    "Boom 900 Index": "DERIV:BOOM_900_INDEX",
    "Boom 1000 Index": "DERIV:BOOM_1000_INDEX",
    "Crash 300 Index": "DERIV:CRASH_300_INDEX",
    "Crash 500 Index": "DERIV:CRASH_500_INDEX",
    "Crash 600 Index": "DERIV:CRASH_600_INDEX",
    "Crash 900 Index": "DERIV:CRASH_900_INDEX",
    "Crash 1000 Index": "DERIV:CRASH_1000_INDEX",
    "Volatility 10 Index": "DERIV:VOLATILITY_10_INDEX",
    "Volatility 25 Index": "DERIV:VOLATILITY_25_INDEX",
    "Volatility 50 Index": "DERIV:VOLATILITY_50_INDEX",
    "Volatility 75 Index": "DERIV:VOLATILITY_75_INDEX",
    "Volatility 100 Index": "DERIV:VOLATILITY_100_INDEX",
    "VAEX": "VAEX",
    "US500": "SP:SPX",
    "US30": "DJ:DJI",
    "NAS100": "NASDAQ:NDX",
    "UK100": "FTSE:UKX",
    "JP225": "CME:NQ",
}

# Resolution des symboles MT5 non-canoniques
_MT5_ALIASES: Dict[str, str] = {
    "PAINX": "PainX",
    "PAINX300": "PainX 300",
    "PAINX600": "PainX 600",
    "GAINX": "GainX",
    "GAINX300": "GainX 300",
    "GAINX600": "GainX 600",
    "FXVOL": "FX Vol",
    "FXVOL20": "FX Vol 20",
    "FXVOL50": "FX Vol 50",
    "BOOM300": "Boom 300 Index",
    "BOOM500": "Boom 500 Index",
    "BOOM1000": "Boom 1000 Index",
    "CRASH300": "Crash 300 Index",
    "CRASH500": "Crash 500 Index",
    "CRASH1000": "Crash 1000 Index",
}


def _resolve_mt5_symbol(symbol: str) -> str:
    """Normalise un symbole MT5 vers sa forme canonique."""
    s = symbol.strip()
    canon = _MT5_ALIASES.get(s.upper())
    if canon:
        return canon
    # Essai de résolution simple (Boom500Index → Boom 500 Index)
    import re
    m = re.match(r"(Boom|Crash|PainX|GainX|FX\s*Vol)\s*(\d+)\s*Index?", s, re.IGNORECASE)
    if m:
        name = m.group(1).strip()
        num = m.group(2)
        if name.upper() in ("PAINX",):
            return f"PainX {num}"
        if name.upper() in ("GAINX",):
            return f"GainX {num}"
        if name.upper().startswith("FX") or name.upper().startswith("VOL"):
            return f"FX Vol {num}"
        return f"{name} {num} Index"
    return s


def mt5_to_tv_ticker(mt5_symbol: str) -> str:
    """Convertit un symbole MT5 → ticker TradingView CDP."""
    canon = _resolve_mt5_symbol(mt5_symbol)
    tv = _TV_CDP_TICKERS.get(canon)
    if tv:
        return tv
    # Fallback : essayer avec majuscules et underscores
    tv_upper = _TV_CDP_TICKERS.get(canon.upper())
    if tv_upper:
        return tv_upper
    return canon


def analyze_symbol(
    mt5_symbol: str,
    full_output: bool = False,
    timeout_sec: int = 240,
    cdp_port: int = 9222,
) -> Dict[str, Any]:
    """
    Analyse SMC multi-TF d'un symbole MT5 via TradingView.

    Args:
        mt5_symbol: Symbole MT5 (ex. "Boom 500 Index", "Crash 500 Index")
        full_output: Inclure les bougies brutes dans le résultat
        timeout_sec: Timeout total en secondes
        cdp_port: Port CDP de TradingView

    Returns:
        Dictionnaire structuré avec:
        - success: bool
        - symbol: symbole original
        - tv_ticker: ticker TradingView utilisé
        - timeframes: analyse SMC par TF
        - confluence: score + biais directionnel
        - entry_setup: suggestion d'entrée (ou None)
        - pine_levels: lignes/labels Pine Script
        - error: message d'erreur si échec
    """
    tv_ticker = mt5_to_tv_ticker(mt5_symbol)

    if not ANALYZER_SCRIPT.exists():
        return {
            "success": False,
            "symbol": mt5_symbol,
            "tv_ticker": tv_ticker,
            "error": f"Analyseur introuvable: {ANALYZER_SCRIPT}",
        }

    env = {**os.environ, "CDP_PORT": str(cdp_port)}
    cmd = ["node", str(ANALYZER_SCRIPT), tv_ticker]
    if full_output:
        cmd.append("--full")

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout_sec,
            cwd=str(MCP_NODE_ROOT),
            env=env,
        )
        stdout = proc.stdout.strip()
        if not stdout:
            return {
                "success": False,
                "symbol": mt5_symbol,
                "tv_ticker": tv_ticker,
                "error": f"Sortie vide. stderr: {proc.stderr[:500]}",
            }
        result = json.loads(stdout)
        result["symbol"] = mt5_symbol
        result["tv_ticker"] = tv_ticker
        return result

    except json.JSONDecodeError as e:
        return {
            "success": False,
            "symbol": mt5_symbol,
            "tv_ticker": tv_ticker,
            "error": f"JSON invalide: {e}",
            "raw_stdout": stdout if 'stdout' in dir() else "",
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "symbol": mt5_symbol,
            "tv_ticker": tv_ticker,
            "error": f"Timeout après {timeout_sec}s",
        }
    except Exception as e:
        return {
            "success": False,
            "symbol": mt5_symbol,
            "tv_ticker": tv_ticker,
            "error": str(e),
        }


# Test
if __name__ == "__main__":
    sym = sys.argv[1] if len(sys.argv) > 1 else "Crash 500 Index"
    full = "--full" in sys.argv
    result = analyze_symbol(sym, full_output=full)
    print(json.dumps(result, indent=2, default=str))
    if result.get("confluence"):
        c = result["confluence"]
        print(f"\nConfluence: {c['bias']} (score {c['score']}/7)")
    if result.get("entry_setup"):
        e = result["entry_setup"]
        print(f"Entry: {e['direction']} @ {e['entry']} | SL: {e['stop_loss']} | TP: {e['take_profit']} | R:R {e['rr']:.1f}")
