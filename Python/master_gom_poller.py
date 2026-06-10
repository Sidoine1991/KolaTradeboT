#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Master GOM Poller — Multi-symboles
====================================
Synchronise TOUS les symboles ouverts sur TradingView vers l'AI server
/gom-verdict, afin que le dashboard GOM de SMC_Universal soit à jour pour
chaque symbole simultanément.

Flux :
    Symbols list (dynamique)
        ↓  rotation chart TV (set-symbol)
    data_get_study_values (GOM KOLA SIDO Pine plots)
        ↓
    POST /gom-verdict  (ai_server local, par symbole)
        ↓
    SMC_Universal EA → SMCGP_PollGOM() → dashboard GOM (SMC_DASH_*)

Usage :
    python python/master_gom_poller.py                         # tous symboles, 12s/symbole
    python python/master_gom_poller.py --interval 8            # plus rapide
    python python/master_gom_poller.py --symbols XAUUSD,BTCUSD # sous-ensemble
    python python/master_gom_poller.py --once                  # un seul tour
    python python/master_gom_poller.py --no-launch-tv          # CDP déjà actif
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional

import requests

# ── Imports depuis le poller mono-symbole existant ────────────────────────
_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

import gom_verdict_poller as _gvp
from gom_verdict_poller import (
    AI_SERVER_URL,
    _read_via_mcp_reader_mjs,
    _read_via_mcp_bridge,
    _ensure_tv_ready,
    _ensure_tv_m1,
    _persist_gom_signal_file,
    push_gom_verdict,
    parse_gom_study,
    _run_tv_cli,
)

# ── Logging ───────────────────────────────────────────────────────────────
_LOG_DIR = _HERE.parent / "logs"
_LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [MasterPoller] %(message)s",
    handlers=[
        logging.StreamHandler(
            open(sys.stdout.fileno(), mode="w", encoding="utf-8", closefd=False)
        ),
        logging.FileHandler(str(_LOG_DIR / "master_gom_poller.log"), encoding="utf-8"),
    ],
)
log = logging.getLogger("master_poller")

# ── Mapping MT5 → ticker TradingView ─────────────────────────────────────
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
    "Gold Basket":      "OANDA:XAUUSD",
}

# Symboles 24h/7j (pas de fermeture weekend)
_ALWAYS_OPEN = {
    "BTCUSD", "ETHUSD",
    "Boom 1000 Index", "Boom 500 Index", "Boom 300 Index", "Boom 600 Index",
    "Crash 1000 Index", "Crash 500 Index", "Crash 300 Index", "Crash 600 Index",
}

# Liste complète par défaut (= symboles SMC_Universal + Boom/Crash)
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
        return False                    # samedi
    if wd == 4 and h >= 22:
        return False                    # vendredi soir
    if wd == 6 and h < 22:
        return False                    # dimanche avant ouverture
    return True


def _tv_ticker(symbol: str) -> str:
    return _MT5_TO_TV.get(symbol, symbol)


def _switch_and_wait(symbol: str, cdp_port: int, pause: float) -> bool:
    """Bascule le chart TV sur symbol et attend le rechargement du Pine."""
    tv_t = _tv_ticker(symbol)
    try:
        # Utiliser MCP au lieu de CLI
        import requests
        mcp_port = 8889  # Port MCP par défaut
        url = f"http://localhost:{mcp_port}/chart-set-symbol"
        requests.post(url, json={"symbol": tv_t}, timeout=5)
    except Exception as e:
        log.debug(f"set-symbol {tv_t} via MCP: {e}")
        # Fallback : ignorer silencieusement si MCP non dispo
    time.sleep(pause)
    return True


def _poll_one(symbol: str, cdp_port: int, pause: float) -> bool:
    """
    Cycle complet pour un symbole :
      1. Basculer chart TV (si possible)
      2. Lire GOM study values (mjs → bridge fallback)
      3. Pousser vers /gom-verdict
    """
    # Optionnel : basculer le chart. Peut ignorer silencieusement si MCP bridge non dispo.
    try:
        _switch_and_wait(symbol, cdp_port, pause)
    except Exception as e:
        log.debug(f"_switch_and_wait {symbol}: {e}")

    # Priorité 1 : gom_mcp_reader.mjs (appel MCP natif)
    mjs = _read_via_mcp_reader_mjs(cdp_port)
    if mjs:
        payload = parse_gom_study(mjs, symbol=symbol)
        if payload:
            _persist_gom_signal_file(payload)
            ok = push_gom_verdict(payload)
            if ok:
                log.info(
                    "✅ %-22s verdict=%-14s buy=%-4s sell=%-4s prix=%s",
                    symbol,
                    payload.get("verdict", "?"),
                    payload.get("score_buy", "?"),
                    payload.get("score_sell", "?"),
                    payload.get("price", "?"),
                )
            return ok

    # Fallback : bridge store
    bridge = _read_via_mcp_bridge()
    if bridge:
        payload = parse_gom_study(bridge, symbol=symbol)
        if payload:
            _persist_gom_signal_file(payload)
            ok = push_gom_verdict(payload)
            if ok:
                log.info("✅ %-22s (bridge) verdict=%s", symbol, payload.get("verdict"))
            return ok

    log.warning("⚠️  %-22s — aucune donnée GOM (indicator chargé sur TV ?)", symbol)
    return False


def run_tour(symbols: List[str], cdp_port: int, pause: float) -> Dict[str, bool]:
    """Un tour complet sur tous les symboles ouverts."""
    open_syms   = [s for s in symbols if _is_market_open(s)]
    closed_syms = [s for s in symbols if not _is_market_open(s)]

    if closed_syms:
        log.info("⏸  Weekend — marchés fermés ignorés : %s", ", ".join(closed_syms))

    log.info("─── Tour : %d symboles ouverts ───", len(open_syms))
    results: Dict[str, bool] = {}
    for sym in open_syms:
        # Re-vérifier CDP avant chaque symbole (TV peut se déconnecter)
        port = _gvp.detect_cdp_port() or cdp_port
        try:
            results[sym] = _poll_one(sym, port, pause)
        except Exception as e:
            log.error("❌ %s : %s", sym, e)
            results[sym] = False

    # Revenir sur XAUUSD après le tour
    try:
        import requests
        mcp_port = 8889
        requests.post(f"http://localhost:{mcp_port}/chart-set-symbol",
                      json={"symbol": _tv_ticker("XAUUSD")}, timeout=5)
        _ensure_tv_m1(cdp_port)
    except Exception:
        pass

    n_ok = sum(1 for v in results.values() if v)
    log.info("─── Tour terminé : %d/%d OK ───", n_ok, len(open_syms))
    return results


def build_symbol_list(args_symbols: str, include_pipeline: bool) -> List[str]:
    """Construit la liste finale en dédupliquant, XAUUSD en tête."""
    base = (
        [s.strip() for s in args_symbols.split(",") if s.strip()]
        if args_symbols.strip()
        else list(_DEFAULT_SYMBOLS)
    )

    if include_pipeline:
        wl = _HERE.parent / "data" / "pipeline_whitelist.json"
        if wl.exists():
            try:
                data = json.loads(wl.read_text(encoding="utf-8"))
                for entry in data.get("symbols", []):
                    sym = entry.get("symbol", "")
                    if sym and sym not in base:
                        base.append(sym)
                        log.info("➕ Pipeline whitelist : %s ajouté", sym)
            except Exception as e:
                log.warning("Whitelist pipeline non lisible : %s", e)

    seen, out = set(), []
    for s in ["XAUUSD"] + base:
        if s not in seen:
            seen.add(s)
            out.append(s)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Master GOM Poller — synchronise tous les symboles TV → /gom-verdict"
    )
    parser.add_argument("--symbols", type=str, default="",
        help="CSV symboles MT5 (ex: XAUUSD,BTCUSD). Vide = liste complète par défaut.")
    parser.add_argument("--interval", type=int, default=12,
        help="Pause entre deux symboles (secondes, défaut=12)")
    parser.add_argument("--cycle-pause", type=int, default=0,
        help="Pause entre deux tours complets en secondes (défaut=0 = continu)")
    parser.add_argument("--once", action="store_true",
        help="Effectuer un seul tour et quitter")
    parser.add_argument("--no-launch-tv", action="store_true",
        help="Ne jamais lancer TradingView automatiquement")
    parser.add_argument("--pipeline-symbols", action="store_true",
        help="Ajouter les symboles du pipeline matinal (pipeline_whitelist.json)")
    args = parser.parse_args()

    _gvp._no_auto_launch_tv = bool(args.no_launch_tv)

    symbols = build_symbol_list(args.symbols, args.pipeline_symbols)

    log.info("=" * 60)
    log.info("🚀 Master GOM Poller démarré")
    log.info("   Symboles (%d) : %s", len(symbols), ", ".join(symbols))
    log.info("   Pause/symbole : %ds  |  Cycle-pause : %ds", args.interval, args.cycle_pause)
    log.info("   Flux : TradingView CDP -> /gom-verdict -> SMC_Universal")
    log.info("=" * 60)

    cdp_port = _ensure_tv_ready()
    if not cdp_port:
        log.error("❌ TradingView CDP introuvable — lance TV en mode debug d'abord")
        sys.exit(1)
    log.info("✅ CDP sur port %d", cdp_port)

    if args.once:
        run_tour(symbols, cdp_port, args.interval)
        sys.exit(0)

    tour = 0
    while True:
        tour += 1
        log.info("══ Tour #%d ══", tour)
        try:
            cdp_port = _gvp.detect_cdp_port() or cdp_port
            run_tour(symbols, cdp_port, args.interval)
        except KeyboardInterrupt:
            log.info("⏹️  Arrêt")
            break
        except Exception as e:
            log.error("Erreur tour #%d : %s", tour, e)

        if args.cycle_pause > 0:
            log.info("⏳ Pause %ds avant tour #%d…", args.cycle_pause, tour + 1)
            time.sleep(args.cycle_pause)


if __name__ == "__main__":
    main()
