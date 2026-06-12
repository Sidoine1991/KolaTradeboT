#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM MT5 Poller — calcul GOM 100% local depuis candles MT5 (sans TradingView)

Flux :
    MT5 Terminal
        → mt5_candles_fetcher.py   (bougies OHLC live, 7 TF)
        → gom_live_calculator.py   (indicateurs + scoring Pine)
        → POST /gom-verdict        (ai_server :8000)
        → SMC_Universal.mq5        (GET /gom-kola-dashboard)

Usage :
    python python/gom_mt5_poller.py              # boucle 30s, tous symboles
    python python/gom_mt5_poller.py --once        # un seul calcul
    python python/gom_mt5_poller.py --interval 60
    python python/gom_mt5_poller.py --symbols "XAUUSD,Boom 1000 Index"
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

import requests

ROOT = Path(__file__).resolve().parent.parent
for p in (str(ROOT), str(ROOT / "python")):
    if p not in sys.path:
        sys.path.insert(0, p)

AI_SERVER_URL = "http://127.0.0.1:8000"

DEFAULT_SYMBOLS: List[str] = [
    "Boom 1000 Index",
    "Boom 500 Index",
    "Boom 300 Index",
    "Crash 1000 Index",
    "Crash 500 Index",
    "Crash 300 Index",
    "XAUUSD",
]

POLL_INTERVAL = 30  # secondes

(ROOT / "logs").mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [GOM-MT5] %(message)s",
    handlers=[
        logging.StreamHandler(
            open(sys.stdout.fileno(), mode="w", encoding="utf-8", closefd=False)
        ),
        logging.FileHandler(str(ROOT / "logs" / "gom_mt5_poller.log"), encoding="utf-8"),
    ],
)
log = logging.getLogger(__name__)


def _push_verdict(payload: Dict[str, Any]) -> bool:
    try:
        r = requests.post(f"{AI_SERVER_URL}/gom-verdict", json=payload, timeout=10)
        if r.ok and r.json().get("ok"):
            log.info(
                "✅ %-20s → %-13s buy=%.1f sell=%.1f gap=%.1f coh=%.0f%% entry=%.2f sl=%.2f tp=%.2f atr=%.2f",
                payload["symbol"],
                payload["verdict"],
                payload.get("score_buy", 0),
                payload.get("score_sell", 0),
                payload.get("verdict_gap", 0),
                payload.get("coherence_pct", 0),
                payload.get("entry", 0),
                payload.get("sl", 0),
                payload.get("tp", 0),
                payload.get("atr", 0),
            )
            return True
        log.error("❌ /gom-verdict HTTP %s: %s", r.status_code, r.text[:200])
        return False
    except Exception as exc:
        log.error("❌ push %s: %s", payload.get("symbol"), exc)
        return False


def poll_once(symbols: List[str], calc) -> int:
    """Calcule GOM pour chaque symbole et pousse vers /gom-verdict."""
    ok_count = 0
    for symbol in symbols:
        try:
            resp = calc.build_api_response(symbol)
            if not resp.get("ok"):
                log.warning("⚠️  %-20s SKIP — %s", symbol, resp.get("error", "no candles"))
                continue

            entry = float(resp.get("price") or resp.get("close") or 0)
            atr = float(resp.get("atr14") or resp.get("atr") or 0)
            verdict_num = int(resp.get("verdict_num", 0))
            is_buy = verdict_num > 0

            # SL/TP basés sur ATR — minimum 0.5% du prix si ATR absent
            if atr <= 0 and entry > 0:
                atr = entry * 0.005
            sl_dist = max(atr * 1.5, entry * 0.002) if entry > 0 else 0
            tp_dist = sl_dist * 2.0

            # Floor minimum pour indices synthétiques Boom/Crash
            sym_up = symbol.upper()
            if any(p in sym_up for p in ("BOOM", "CRASH")) and entry > 0:
                sl_dist = max(sl_dist, 20.0)
                tp_dist = sl_dist * 2.0

            if entry > 0 and sl_dist > 0 and verdict_num != 0:
                sl = round(entry - sl_dist if is_buy else entry + sl_dist, 5)
                tp = round(entry + tp_dist if is_buy else entry - tp_dist, 5)
            else:
                sl = 0.0
                tp = 0.0

            payload: Dict[str, Any] = {
                **resp,
                "symbol": symbol,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "source": "mt5_live",
                "entry": entry,
                "price": entry,
                "sl": sl,
                "tp": tp,
                "atr": atr,
                "atr14": atr,
            }
            if _push_verdict(payload):
                ok_count += 1
        except Exception as exc:
            log.error("Erreur %s: %s\n%s", symbol, exc, traceback.format_exc())
    return ok_count


def main() -> None:
    parser = argparse.ArgumentParser(description="GOM Poller 100% MT5 — sans TradingView")
    parser.add_argument("--interval", type=int, default=POLL_INTERVAL,
                        help=f"Intervalle entre polls en secondes (défaut={POLL_INTERVAL})")
    parser.add_argument("--once", action="store_true",
                        help="Un seul calcul puis quitter")
    parser.add_argument("--symbols", type=str, default=None,
                        help="Symboles séparés par virgule (défaut: liste prédéfinie)")
    args = parser.parse_args()

    symbols = (
        [s.strip() for s in args.symbols.split(",") if s.strip()]
        if args.symbols
        else DEFAULT_SYMBOLS
    )

    try:
        from gom_live_calculator import GOMSignalsLiveCalculator
        calc = GOMSignalsLiveCalculator()
    except ImportError as exc:
        log.error("gom_live_calculator introuvable: %s", exc)
        sys.exit(1)

    # Vérifier connexion MT5 au démarrage
    try:
        from mt5_candles_fetcher import ensure_mt5_connected, mt5_python_available
        if not mt5_python_available():
            log.error("❌ Package MetaTrader5 absent — pip install MetaTrader5")
            sys.exit(1)
        if ensure_mt5_connected():
            log.info("✅ MT5 connecté")
        else:
            log.warning("⚠️  MT5 non connecté au démarrage — vérifiez que le terminal Deriv est ouvert")
    except ImportError:
        log.warning("mt5_candles_fetcher non disponible — le calcul utilisera les candles uploadées")

    if args.once:
        n = poll_once(symbols, calc)
        log.info("Terminé — %d/%d succès", n, len(symbols))
        sys.exit(0 if n > 0 else 1)

    log.info("GOM MT5 Poller démarré — %d symboles — intervalle %ds", len(symbols), args.interval)
    log.info("Symboles: %s", ", ".join(symbols))
    log.info("Flux: MT5 Terminal → gom_live_calculator → /gom-verdict → SMC_Universal")
    log.info("(aucune connexion TradingView requise)")

    while True:
        try:
            t0 = time.time()
            n = poll_once(symbols, calc)
            elapsed = time.time() - t0
            log.info("→ %d/%d verdicts pushés (%.1fs)", n, len(symbols), elapsed)
        except KeyboardInterrupt:
            log.info("⏹️ Arrêt")
            break
        except Exception as exc:
            log.error("Erreur boucle: %s\n%s", exc, traceback.format_exc())
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
