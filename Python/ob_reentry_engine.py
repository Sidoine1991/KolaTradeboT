# -*- coding: utf-8 -*-
"""
ob_reentry_engine.py — Re-entry automatique sur Order Block ou EMA

Logique :
  1. Lit les OB actifs (bull/bear) + EMA20/50 depuis /gom-verdict (AI server)
  2. Détecte un "touch" : prix entre dans la zone OB ou approche EMA (≤ 0.3× ATR)
  3. Attend le pullback de confirmation (prix sort de la zone dans la direction)
  4. Place l'ordre via /pending-order avec source="ob_reentry"
     → TradeManager applique TOUS les guards normaux (pas pipeline)

Usage :
  python ob_reentry_engine.py             # loop continue (Ctrl+C pour stop)
  python ob_reentry_engine.py --once      # une seule passe
"""
from __future__ import annotations

import argparse
import logging
import math
import time
from dataclasses import dataclass, field
from typing import Dict, Optional

import requests

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
AI_SERVER   = "http://127.0.0.1:8000"
POLL_SEC    = 15          # interval entre deux polls
TOUCH_SLACK = 0.3         # distance OB/EMA en × ATR pour déclencher "touch"
CONFIRM_SEC = 30          # délai de confirmation pullback
COOLDOWN    = 300         # secondes de cooldown après un ordre placé par symbole
SYMBOLS     = ["XAUUSD"]  # symboles à surveiller (étendre selon besoin)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [OB-Reentry] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("ob_reentry")


# ---------------------------------------------------------------------------
# État par symbole
# ---------------------------------------------------------------------------
@dataclass
class SymState:
    symbol:       str
    in_touch:     bool  = False
    touch_time:   float = 0.0
    touch_type:   str   = ""   # "ob_bull" | "ob_bear" | "ema20" | "ema50"
    touch_price:  float = 0.0
    last_order:   float = 0.0  # timestamp dernier ordre


_states: Dict[str, SymState] = {}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _safe_float(v, default: float = 0.0) -> float:
    try:
        f = float(v)
        return f if math.isfinite(f) else default
    except (TypeError, ValueError):
        return default


def _get_gom_verdict(symbol: str) -> Optional[dict]:
    try:
        r = requests.get(f"{AI_SERVER}/gom-verdict/{symbol}", timeout=8)
        if r.status_code == 200:
            return r.json()
    except Exception as e:
        log.debug("Erreur /gom-verdict/%s: %s", symbol, e)
    return None


def _place_order(symbol: str, direction: str, entry: float, sl: float, tp: float, lot: float, reason: str):
    payload = {
        "symbol":     symbol,
        "direction":  direction,
        "entry":      entry,
        "stop_loss":  sl,
        "take_profit": tp,
        "lot":        lot,
        "source":     "ob_reentry",
        "reasoning":  reason,
    }
    try:
        r = requests.post(f"{AI_SERVER}/pending-order", json=payload, timeout=8)
        if r.status_code == 200:
            log.info("✅ Ordre ob_reentry placé: %s %s @ %.5f SL=%.5f TP=%.5f lot=%.2f",
                     symbol, direction, entry, sl, tp, lot)
            return True
        else:
            log.warning("Erreur placement ordre %s: %s %s", symbol, r.status_code, r.text[:200])
    except Exception as e:
        log.warning("Erreur /pending-order %s: %s", symbol, e)
    return False


def _compute_sl_tp(entry: float, direction: str, atr: float) -> tuple[float, float]:
    """SL serré (0.6× ATR) TP à 1.5× RR pour petit compte."""
    sl_dist = atr * 0.6
    tp_dist = sl_dist * 1.5
    if direction == "BUY":
        return round(entry - sl_dist, 5), round(entry + tp_dist, 5)
    return round(entry + sl_dist, 5), round(entry - tp_dist, 5)


def _get_lot(symbol: str) -> float:
    if any(symbol.startswith(p) for p in ("BOOM", "CRASH")):
        return 0.20
    return 0.01


# ---------------------------------------------------------------------------
# Logique touch + pullback
# ---------------------------------------------------------------------------
def _check_symbol(sym: str):
    state = _states.setdefault(sym, SymState(symbol=sym))
    now   = time.time()

    # cooldown après dernier ordre
    if now - state.last_order < COOLDOWN:
        return

    data = _get_gom_verdict(sym)
    if not data:
        return

    price = _safe_float(data.get("current_price") or data.get("price"))
    atr   = _safe_float(data.get("atr"))
    if price <= 0 or atr <= 0:
        return

    slack = atr * TOUCH_SLACK

    # --- Niveaux OB depuis /gom-verdict ---
    ob_bull_top = _safe_float(data.get("ob_bull_top"))
    ob_bull_bot = _safe_float(data.get("ob_bull_bot"))
    ob_bear_top = _safe_float(data.get("ob_bear_top"))
    ob_bear_bot = _safe_float(data.get("ob_bear_bot"))

    # --- EMA depuis /gom-verdict (champs bb_up/dn utilisés comme proxy si EMA absent) ---
    ema20 = _safe_float(data.get("ema20") or data.get("bb_mid"))
    ema50 = _safe_float(data.get("ema50"))

    # ----- Détection touch ------------------------------------------------
    touch_type = ""
    touch_dir  = ""

    # Bullish OB : prix touche la zone → potentiel BUY
    if ob_bull_top > 0 and ob_bull_bot > 0:
        if ob_bull_bot - slack <= price <= ob_bull_top + slack:
            touch_type = "ob_bull"
            touch_dir  = "BUY"

    # Bearish OB : prix touche la zone → potentiel SELL
    if not touch_type and ob_bear_top > 0 and ob_bear_bot > 0:
        if ob_bear_bot - slack <= price <= ob_bear_top + slack:
            touch_type = "ob_bear"
            touch_dir  = "SELL"

    # EMA20 touch
    if not touch_type and ema20 > 0:
        if abs(price - ema20) <= slack:
            # direction selon position prix vs EMA50
            touch_type = "ema20"
            touch_dir  = "BUY" if price >= ema20 else "SELL"

    # EMA50 touch (seulement si pas de signal EMA20)
    if not touch_type and ema50 > 0:
        if abs(price - ema50) <= slack:
            touch_type = "ema50"
            touch_dir  = "BUY" if price >= ema50 else "SELL"

    # ----- Gestion état touch --------------------------------------------
    if touch_type and not state.in_touch:
        state.in_touch    = True
        state.touch_time  = now
        state.touch_type  = touch_type
        state.touch_price = price
        log.info("👆 Touch %s sur %s @ %.5f (type=%s dir=%s)",
                 sym, touch_type, price, touch_type, touch_dir)
        return

    if state.in_touch:
        elapsed = now - state.touch_time
        if elapsed < CONFIRM_SEC:
            return  # attendre la confirmation

        # Confirmation pullback : prix a bougé dans la direction après le touch
        moved = price - state.touch_price
        direction = "BUY" if state.touch_type in ("ob_bull", "ema20", "ema50") and moved > atr * 0.1 else (
                    "SELL" if state.touch_type in ("ob_bear",) and moved < -atr * 0.1 else "")

        # Pour EMA : direction selon mouvement effectif
        if state.touch_type in ("ema20", "ema50"):
            if moved > atr * 0.1:
                direction = "BUY"
            elif moved < -atr * 0.1:
                direction = "SELL"

        state.in_touch = False  # reset dans tous les cas

        if not direction:
            log.info("❌ Pullback non confirmé %s (déplacement=%.5f < seuil)", sym, moved)
            return

        # Placer l'ordre
        sl, tp = _compute_sl_tp(price, direction, atr)
        lot    = _get_lot(sym)
        reason = f"OB/EMA re-entry: {state.touch_type} touch @ {state.touch_price:.5f}, pullback confirmé {elapsed:.0f}s"

        success = _place_order(sym, direction, price, sl, tp, lot, reason)
        if success:
            state.last_order = now


# ---------------------------------------------------------------------------
# Boucle principale
# ---------------------------------------------------------------------------
def run_once():
    for sym in SYMBOLS:
        try:
            _check_symbol(sym)
        except Exception as e:
            log.warning("Erreur check %s: %s", sym, e)


def run_loop():
    log.info("OB/EMA Re-entry engine démarré — symboles: %s", SYMBOLS)
    while True:
        run_once()
        time.sleep(POLL_SEC)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true", help="Une seule passe")
    args = parser.parse_args()

    if args.once:
        run_once()
    else:
        run_loop()
