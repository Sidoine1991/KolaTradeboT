#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Spike Chain Live Pipeline — Trading automatique des chaînes de spikes
(Boom/Crash Deriv + PainX/GainX Weltrade + Volatility) via l'API ai_server.

Flux par symbole (boucle):
  1. Fetch candles H1/H4 + M5 (MT5 multi-broker via mt5_candles_fetcher)
  2. evaluate_chain_with_structure() -> renfort SMC (BOS/CHOCH + OB + bougies)
  3. Si signal `reinforced` (confiance >= 0.60) -> build_order()
  4. Route vers POST /api/core/place-order sur l'AI server
  5. Cooldown par symbole avant re-test

Ce pipeline réutilise 100% du existant :
  - list_all_spike_symbols()      (spike_chain_strategy)
  - fetch_mt5_candles()           (mt5_candles_fetcher, 3 brokers)
  - evaluate_chain_with_structure() (renfort BOS/CHOCH/OB/bougies)
  - POST /api/core/place-order    (core/register_routes.py)
"""

import sys
import json
import time
import logging
import asyncio
from pathlib import Path
from typing import Dict, Any, Optional, List

import requests

# ── Chemin projet ────────────────────────────────────────────────
_root = str(Path(__file__).resolve().parent)
if _root not in sys.path:
    sys.path.insert(0, _root)

from spike_chain_strategy import (
    SpikeChainStrategy,
    list_all_spike_symbols,
)

try:
    from mt5_candles_fetcher import fetch_mt5_candles, mt5_python_available
except Exception as _e:
    fetch_mt5_candles = None
    mt5_python_available = False
    logging.getLogger(__name__).warning(f"[PIPE] mt5_candles_fetcher: {_e}")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("logs/spike_chain_pipeline.log", encoding="utf-8", mode="a"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("spike_chain_pipeline")

AI_SERVER = "http://127.0.0.1:8000"
API_PLACE = f"{AI_SERVER}/api/core/place-order"

# Broker par défaut déduit du symbole (Deriv / Weltrade / StarTrader)
try:
    from symbol_mapper import is_weltrade_symbol, _broker_from_symbol
except Exception:
    def is_weltrade_symbol(s): return "PAINX" in s.upper() or "GAINX" in s.upper()
    def _broker_from_symbol(s): return "weltrade" if is_weltrade_symbol(s) else "deriv"


class SpikeChainPipeline:
    """Pipeline live de trading des chaînes de spikes."""

    def __init__(
        self,
        htf: str = "60",            # H1 pour la force d'impulsion + S/R 20 barres
        m5_bars: int = 50,
        htf_bars: int = 60,
        loop_seconds: int = 60,    # pause entre 2 passes complètes
        cooldown_symbol_sec: int = 900,  # 15 min par symbole après un ordre
        confidence_min: float = 0.60,
        sl_pips: float = 8.0,
        tp_extension_pips: float = 20.0,
        only_reinforced: bool = True,
    ):
        self.htf = htf
        self.m5_bars = m5_bars
        self.htf_bars = htf_bars
        self.loop_seconds = loop_seconds
        self.cooldown = cooldown_symbol_sec
        self.confidence_min = confidence_min
        self.sl_pips = sl_pips
        self.tp_extension_pips = tp_extension_pips
        self.only_reinforced = only_reinforced

        self.strat = SpikeChainStrategy(sr_lookback=20, m5_spike_body_pips=3.0)
        self.last_order_ts: Dict[str, float] = {}
        self.orders_placed = 0
        self.signals_seen = 0

    # ── Fetch des candles (3 brokers) ──────────────────────────
    def _fetch(self, symbol: str, tf: str, bars: int) -> Optional[Any]:
        if fetch_mt5_candles is None:
            return None
        broker = _broker_from_symbol(symbol)
        try:
            df = fetch_mt5_candles(symbol, tf, bars=bars, broker=broker)
            return df
        except Exception as e:
            log.debug(f"[PIPE] fetch {symbol} {tf} ({broker}) échec: {e}")
            return None

    # ── Évaluation d'un symbole ──────────────────────────────
    def evaluate_symbol(self, symbol: str) -> Optional[Dict[str, Any]]:
        df_htf = self._fetch(symbol, self.htf, self.htf_bars)
        df_m5 = self._fetch(symbol, "5", self.m5_bars)
        if df_htf is None or df_m5 is None or len(df_htf) < 21 or len(df_m5) < 12:
            return None

        ev = self.strat.evaluate_chain_with_structure(
            df_htf, df_m5, timeframe_htf=self.htf, df_struct=df_m5
        )
        return ev

    # ── Placement de l'ordre ────────────────────────────────
    def place_order(self, symbol: str, evaluation: Dict[str, Any]) -> bool:
        order = self.strat.build_order(
            evaluation, symbol,
            sl_pips=self.sl_pips,
            tp_extension_pips=self.tp_extension_pips,
        )
        if not order:
            return False

        # Conversion vers le format de l'API (/api/core/place-order)
        payload = {
            "symbol": order["symbol"],
            "direction": order["action"],          # BUY / SELL
            "volume": 0.01,
            "sl": order["sl"],
            "tp": order["tp"],
            "entry": order["entry"],
            "source": "spike_chain_pipeline",
            "confidence": evaluation.get("confidence"),
            "force": order.get("force"),
            "expected_spikes": order.get("expected_spikes"),
        }
        try:
            r = requests.post(API_PLACE, json=payload, timeout=5)
            if r.status_code == 200:
                log.info(
                    f"[OK] {symbol} {order['action']} @ {order['entry']:.5f} "
                    f"SL {order['sl']:.5f} TP {order['tp']:.5f} "
                    f"(conf {evaluation.get('confidence')})"
                )
                self.orders_placed += 1
                self.last_order_ts[symbol] = time.time()
                return True
            log.warning(f"[ERR] {symbol} HTTP {r.status_code}: {r.text[:120]}")
        except Exception as e:
            log.error(f"[ERR] placement {symbol}: {e}")
        return False

    # ── Une passe sur tous les symboles ──────────────────────
    def run_pass(self) -> Dict[str, Any]:
        symbols = list_all_spike_symbols(source="gom")
        now = time.time()
        evaluated = 0
        reinforced = 0

        for sym in symbols:
            # Cooldown par symbole
            last = self.last_order_ts.get(sym, 0.0)
            if now - last < self.cooldown:
                continue

            ev = self.evaluate_symbol(sym)
            if ev is None:
                continue
            evaluated += 1

            if not ev.get("signal"):
                continue
            self.signals_seen += 1

            ok = ev.get("reinforced", False) if self.only_reinforced else True
            if ok and ev.get("confidence", 0) >= self.confidence_min:
                reinforced += 1
                log.info(
                    f"[SIGNAL] {sym}: {ev['action']} conf={ev['confidence']} "
                    f"structure_ok={ev['structure_ok']} bos={ev['bos']['aligned']} "
                    f"ob_hit={ev['order_block']['zone_hit']}"
                )
                self.place_order(sym, ev)

        return {
            "evaluated": evaluated,
            "signals": self.signals_seen,
            "reinforced": reinforced,
            "orders_placed": self.orders_placed,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }

    # ── Boucle principale ────────────────────────────────────
    def run_forever(self) -> None:
        log.info("=" * 70)
        log.info("[START] Spike Chain Live Pipeline")
        log.info(f"  HTF={self.htf}  M5 bars={self.m5_bars}  loop={self.loop_seconds}s")
        log.info(f"  confidence_min={self.confidence_min}  cooldown={self.cooldown}s")
        log.info(f"  MT5 dispo: {mt5_python_available}")
        log.info("=" * 70)
        while True:
            try:
                res = self.run_pass()
                log.info(
                    f"[PASS] évalués={res['evaluated']} "
                    f"signaux={res['signals']} renforcés={res['reinforced']} "
                    f"ordres={res['orders_placed']}"
                )
            except Exception as e:
                log.error(f"[LOOP] erreur passe: {e}", exc_info=True)
            time.sleep(self.loop_seconds)


def _one_shot() -> Dict[str, Any]:
    """Une seule passe (utile pour test / cron)."""
    pipe = SpikeChainPipeline(loop_seconds=0, cooldown_symbol_sec=0)
    return pipe.run_pass()


if __name__ == "__main__":
    import argparse

    p = argparse.ArgumentParser(description="Spike Chain Live Pipeline")
    p.add_argument("--once", action="store_true", help="une seule passe")
    p.add_argument("--loop", type=int, default=60, help="pause entre passes (s)")
    p.add_argument("--htf", default="60", help="timeframe H1/H4 pour S/R + impulsion")
    p.add_argument("--conf", type=float, default=0.60, help="confiance min")
    p.add_argument("--no-reinforce", action="store_true",
                   help="placer même sans renfort SMC (signal seul)")
    # ai_server (importé en transit) consomme parfois sys.argv ;
    # on tolère un argv déjà vidé/occupé.
    try:
        args = p.parse_args()
    except SystemExit:
        args = p.parse_args([])

    if args.once:
        out = _one_shot()
        print(json.dumps(out, indent=2, default=str))
    else:
        pipe = SpikeChainPipeline(
            htf=args.htf,
            loop_seconds=args.loop,
            confidence_min=args.conf,
            only_reinforced=not args.no_reinforce,
        )
        pipe.run_forever()
