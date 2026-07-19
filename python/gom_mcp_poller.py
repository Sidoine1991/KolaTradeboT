#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM MCP Poller — Version MCP native
====================================
Remplace master_gom_poller.py qui utilisait l'ancien CLI 'tv' cassé.
Utilise directement TradingView MCP pour changer symboles et lire données.

Flux :
    Symbols list → chart_set_symbol (MCP) → data_get_study_values (MCP)
        ↓
    POST /gom-verdict (ai_server)
        ↓
    SMC_Universal EA → SMCGP_PollGOM() → dashboard GOM

Usage :
    python python/gom_mcp_poller.py --symbol "Boom 500 Index"
    python Python/gom_mcp_poller.py --symbols "XAUUSD,BTCUSD,Boom 500 Index"
    python Python/gom_mcp_poller.py --once  # un seul tour sur tous les symboles
"""
import argparse
import json
import logging
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional

import requests

# ── Paths ─────────────────────────────────────────────────────────────────
_HERE = Path(__file__).resolve().parent
_LOG_DIR = _HERE.parent / "logs"
_LOG_DIR.mkdir(parents=True, exist_ok=True)
_DATA_DIR = _HERE.parent / "data"
_DATA_DIR.mkdir(parents=True, exist_ok=True)

# ── Logging ───────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [GOM-MCP] %(message)s",
    handlers=[
        logging.StreamHandler(
            open(sys.stdout.fileno(), mode="w", encoding="utf-8", closefd=False)
        ),
        logging.FileHandler(str(_LOG_DIR / "gom_mcp_poller.log"), encoding="utf-8"),
    ],
)
log = logging.getLogger("gom_mcp")

# ── Configuration ─────────────────────────────────────────────────────────
AI_SERVER_URL = "http://127.0.0.1:8000"

# Mapping MT5 → TradingView ticker
_MT5_TO_TV: Dict[str, str] = {
    "XAUUSD":           "OANDA:XAUUSD",
    "XAGUSD":           "OANDA:XAGUSD",
    "EURUSD":           "OANDA:EURUSD",
    "GBPUSD":           "OANDA:GBPUSD",
    "USDJPY":           "OANDA:USDJPY",
    "USDCHF":           "OANDA:USDCHF",
    "AUDUSD":           "OANDA:AUDUSD",
    "NZDUSD":           "OANDA:NZDUSD",
    "USDCAD":           "OANDA:USDCAD",
    "US30":             "FOREXCOM:DJI",
    "US500":            "FOREXCOM:SPXUSD",
    "NAS100":           "NASDAQ:NDX",
    "BTCUSD":           "BITSTAMP:BTCUSD",
    "ETHUSD":           "BITSTAMP:ETHUSD",
    "Boom 1000 Index":  "DERIV:BOOM_1000_INDEX",
    "Boom 500 Index":   "DERIV:BOOM_500_INDEX",
    "Boom 300 Index":   "DERIV:BOOM_300_INDEX",
    "Boom 600 Index":   "DERIV:BOOM_600_INDEX",
    "Crash 1000 Index": "DERIV:CRASH_1000_INDEX",
    "Crash 500 Index":  "DERIV:CRASH_500_INDEX",
    "Crash 300 Index":  "DERIV:CRASH_300_INDEX",
    "Crash 600 Index":  "DERIV:CRASH_600_INDEX",
}

# Symboles 24h/7j
_ALWAYS_OPEN = {
    "BTCUSD", "ETHUSD",
    "Boom 1000 Index", "Boom 500 Index", "Boom 300 Index", "Boom 600 Index",
    "Crash 1000 Index", "Crash 500 Index", "Crash 300 Index", "Crash 600 Index",
}

# Liste par défaut
_DEFAULT_SYMBOLS: List[str] = [
    "XAUUSD",
    "EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "NZDUSD", "USDCAD",
    "XAGUSD", "US30", "US500", "NAS100",
    "BTCUSD", "ETHUSD",
    "Boom 1000 Index", "Boom 500 Index", "Crash 1000 Index", "Crash 500 Index",
]


def _is_market_open(symbol: str) -> bool:
    """Filtre weekend pour forex/métaux. Synthétiques toujours ouverts."""
    if symbol in _ALWAYS_OPEN:
        return True
    import datetime as _dt
    now = _dt.datetime.utcnow()
    wd, h = now.weekday(), now.hour
    if wd == 5:
        return False  # samedi
    if wd == 4 and h >= 22:
        return False  # vendredi soir
    if wd == 6 and h < 22:
        return False  # dimanche avant ouverture
    return True


def _tv_ticker(symbol: str) -> str:
    """Convertit symbole MT5 en ticker TradingView."""
    return _MT5_TO_TV.get(symbol, symbol)


def _parse_fr_float(s) -> Optional[float]:
    """Convertit tout format numerique (FR/EN, espaces, virgules) en float."""
    if s is None:
        return None
    try:
        import re as _re
        text = str(s).replace('−', '-').replace('–', '-').replace('—', '-')
        cleaned = _re.sub(r'[^\d,.\-]', '', text)
        if '.' in cleaned and ',' in cleaned:
            cleaned = cleaned.replace(',', '')
        else:
            cleaned = cleaned.replace(',', '.')
        return float(cleaned) if cleaned and cleaned != '-' else None
    except (ValueError, TypeError):
        return None


def parse_gom_study(data: Dict, symbol: str = "Unknown") -> Optional[Dict]:
    """Parse les valeurs GOM depuis data_get_study_values."""
    if not data or not isinstance(data, dict):
        return None

    # TradingView MCP retourne format: {plot_name: {value: "...", title: "..."}}
    plots = data.get("plots", {}) or data

    # Helper pour extraire valeur
    def get_val(key: str) -> Optional[float]:
        if key in plots:
            if isinstance(plots[key], dict):
                return _parse_fr_float(plots[key].get("value"))
            return _parse_fr_float(plots[key])
        return None

    # GOM KOLA SIDO plots principaux
    verdict_num = get_val("verdict_num") or 0
    verdict_map = {1: "BUY", -1: "SELL", 2: "BUY", -2: "SELL"}
    verdict = verdict_map.get(int(verdict_num), "WAIT")

    payload = {
        "symbol": symbol,
        "verdict": verdict,
        "quality": get_val("entry_quality") or 0,
        "delta": get_val("ghost_delta") or 0,
        "cvd": get_val("ghost_cvd") or 0,
        "buypct": get_val("ghost_buypct") or 50,
        "sellpct": get_val("ghost_sellpct") or 50,
        "compass": int(get_val("ghost_compass") or 0),
        "imbalance": get_val("imbalance") or 0,
        "volume_profile": get_val("volume_profile") or 0,
        "liquidity_score": get_val("liquidity_score") or 0,
        "smart_money_idx": get_val("smart_money_idx") or 0,
        "setup_entry": get_val("setup_entry") or 0,
        "setup_sl": get_val("setup_sl") or 0,
        "setup_tp1": get_val("setup_tp1") or 0,
        "setup_tp2": get_val("setup_tp2") or 0,
        "setup_rr": get_val("setup_rr") or 0,
        "setup_dir": verdict if (get_val("setup_entry") or 0) > 0 else "",
        "score_buy": get_val("score_buy") or 0,
        "score_sell": get_val("score_sell") or 0,
        "price": get_val("close") or 0,
    }

    return payload


def push_gom_verdict(payload: Dict) -> bool:
    """POST vers /gom-verdict."""
    try:
        resp = requests.post(f"{AI_SERVER_URL}/gom-verdict", json=payload, timeout=5)
        if resp.status_code == 200:
            return True
        log.warning(f"AI server /gom-verdict returned {resp.status_code}")
        return False
    except Exception as e:
        log.error(f"Erreur push /gom-verdict: {e}")
        return False


def persist_gom_signal(payload: Dict):
    """
    Écrit gom_signal.json pour EA MT5.
    Format: {"XAUUSD": {...}, "Boom 500 Index": {...}, ...}
    Accumule les données par symbole pour support multi-symbole.
    """
    out = _DATA_DIR / "gom_signal.json"
    try:
        # Charger les données existantes si présentes
        existing = {}
        if out.is_file():
            try:
                existing = json.loads(out.read_text(encoding="utf-8"))
                if not isinstance(existing, dict):
                    existing = {}
            except Exception:
                existing = {}

        # Extraire le symbole du payload
        symbol = payload.get("symbol", "UNKNOWN")

        # ✅ FUSIONNER INTELLIGENT: ne pas écraser les verdicts déjà calculés (vn >= 2)
        # Raison: gom_sync_with_report.py calcule verdicts précis; ne pas perdre le travail
        if symbol in existing:
            prev = existing[symbol]
            prev_vn = prev.get("verdict_num", 0)
            new_vn = payload.get("verdict_num", 0)

            # Si le verdict précédent est "bon" (vn >= 2) et le nouveau est "nul" (vn == 0/1),
            # garder l'ancien (il a probablement été calculé par gom_pine_calculator)
            if prev_vn >= 2 and new_vn <= 1:
                # Fusionner seulement les données techniques (prix, BB, RSI)
                # Garder verdict, score, verdict_num de l'ancien
                payload_copy = payload.copy()
                for key in ["bb_up", "bb_mid", "bb_dn", "tf_m1_rsi", "entry", "close", "timestamp"]:
                    if key in payload_copy:
                        prev[key] = payload_copy[key]
                existing[symbol] = prev
                log.info(f"✅ {symbol}: Fusion SMART (gardé vn={prev_vn}, mis à jour prix/RSI)")
            else:
                # Sinon, remplacer complètement
                existing[symbol] = payload
                log.info(f"✅ {symbol}: Remplacement complet")
        else:
            existing[symbol] = payload

        # Écrire le dict accumulé
        out.write_text(json.dumps(existing, indent=2), encoding="utf-8")
        log.info(f"✅ GOM signal persisted: {symbol} (total symbols: {len(existing)})")
    except Exception as e:
        log.error(f"Erreur écriture {out}: {e}")


def poll_one_symbol(symbol: str, mcp_available: bool = True) -> bool:
    """
    Poll un symbole :
    1. Change symbole sur TradingView (via Claude MCP si disponible)
    2. Lit study values
    3. Push vers AI server
    4. Persist dans data/gom_signal.json
    """
    tv_ticker = _tv_ticker(symbol)

    if not mcp_available:
        log.warning(f"⚠️  {symbol:22s} — MCP indisponible, skip")
        return False

    log.info(f"🔄 {symbol:22s} → {tv_ticker}")

    # NOTE: Ici on devrait appeler Claude MCP pour :
    # 1. chart_set_symbol(tv_ticker)
    # 2. data_get_study_values(study_filter="GOM KOLA SIDO")
    #
    # Mais comme ce script tourne en standalone sans Claude,
    # on doit utiliser un bridge ou demander à Claude de le faire.
    #
    # Pour l'instant, on log un placeholder.

    log.warning(f"⚠️  {symbol:22s} — Ce script nécessite Claude MCP actif (lance via Claude)")
    return False


def run_tour(symbols: List[str]) -> Dict[str, bool]:
    """Un tour complet sur tous les symboles ouverts."""
    open_syms = [s for s in symbols if _is_market_open(s)]
    closed_syms = [s for s in symbols if not _is_market_open(s)]

    if closed_syms:
        log.info(f"⏸  Weekend — marchés fermés : {', '.join(closed_syms)}")

    log.info(f"─── Tour : {len(open_syms)} symboles ouverts ───")

    results: Dict[str, bool] = {}
    for sym in open_syms:
        try:
            results[sym] = poll_one_symbol(sym)
        except Exception as e:
            log.error(f"❌ {sym}: {e}")
            results[sym] = False

    n_ok = sum(1 for v in results.values() if v)
    log.info(f"─── Tour terminé : {n_ok}/{len(open_syms)} OK ───")
    return results


def main():
    parser = argparse.ArgumentParser(description="GOM MCP Poller — TradingView MCP native")
    parser.add_argument("--symbol", type=str, help="Symbole unique")
    parser.add_argument("--symbols", type=str, help="Symboles CSV (ex: XAUUSD,BTCUSD)")
    parser.add_argument("--once", action="store_true", help="Un seul tour puis exit")
    args = parser.parse_args()

    # Build symbol list
    if args.symbol:
        symbols = [args.symbol]
    elif args.symbols:
        symbols = [s.strip() for s in args.symbols.split(",") if s.strip()]
    else:
        symbols = list(_DEFAULT_SYMBOLS)

    log.info("=" * 60)
    log.info("🚀 GOM MCP Poller démarré")
    log.info(f"   Symboles ({len(symbols)}) : {', '.join(symbols)}")
    log.info("   Mode : MCP TradingView natif via Claude")
    log.info("=" * 60)

    log.error("❌ Ce script nécessite Claude Code avec TradingView MCP actif.")
    log.error("   Lance ce poller depuis Claude avec :")
    log.error("   > Lance python Python/gom_mcp_poller.py --symbol 'Boom 500 Index'")
    log.error("")
    log.error("   Ou utilise l'ancien master_gom_poller.py (CLI cassé mais fallback bridge possible)")
    sys.exit(1)


if __name__ == "__main__":
    main()
