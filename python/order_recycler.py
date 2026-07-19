#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Order Recycler — Annule les ordres limit > 30min inactifs et les replace sur meilleure entrée
"""

import json
import requests
import logging
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, List, Any, Optional

# Force UTF-8 on Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler("logs/order_recycler.log", encoding='utf-8', mode='a'),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger(__name__)

AI_SERVER = "http://127.0.0.1:8000"
ORDER_TIMEOUT_MINUTES = 30

class OrderRecycler:
    """Monitor et recycle les ordres limit inactifs."""

    def __init__(self):
        self.recycled_count = 0
        self.replaced_count = 0

    def get_pending_orders(self) -> List[Dict[str, Any]]:
        """Récupère les ordres limit actifs depuis ai_server."""
        try:
            r = requests.get(f"{AI_SERVER}/pending-orders", timeout=5)
            if r.status_code == 200:
                data = r.json()
                orders = data.get("orders", [])
                log.info(f"[MONITOR] Chargé {len(orders)} ordres pending")
                return orders
            else:
                log.warning(f"[MONITOR] API /pending-orders retourne {r.status_code}")
                return []
        except Exception as e:
            log.error(f"[MONITOR] Erreur GET /pending-orders: {e}")
            return []

    def get_best_gom_verdict(self, exclude_symbol: str = "") -> Optional[Dict[str, Any]]:
        """Trouve le meilleur verdict GOM (highest coherence) sauf le symbol exclu."""
        try:
            r = requests.get(f"{AI_SERVER}/gom-verdicts", timeout=5)
            if r.status_code != 200:
                return None

            data = r.json()
            verdicts = data.get("verdicts", [])

            # Filter: vérifiés GOM, coherence >= 50%, pas le symbol exclu
            candidates = []
            for v in verdicts:
                sym = str(v.get("symbol", "")).upper()
                coh = float(v.get("coherence_pct", 0) or 0)
                verdict_num = int(v.get("verdict_num", 0) or 0)

                if sym == exclude_symbol.upper():
                    continue
                if verdict_num == 0:  # WAIT
                    continue
                if coh < 50.0:  # Trop faible
                    continue

                candidates.append({
                    "symbol": sym,
                    "verdict_num": verdict_num,
                    "coherence_pct": coh,
                    "entry": float(v.get("entry", 0.0) or 0.0),
                    "sl": float(v.get("sl", 0.0) or 0.0),
                    "tp": float(v.get("tp", 0.0) or 0.0),
                })

            if not candidates:
                log.warning("[RECYCLE] Aucun verdict GOM valide trouvé")
                return None

            # Trier par coherence (descending)
            candidates.sort(key=lambda x: x["coherence_pct"], reverse=True)
            best = candidates[0]

            log.info(f"[RECYCLE] Meilleur verdict trouvé: {best['symbol']} @ {best['coherence_pct']:.0f}% coh")
            return best

        except Exception as e:
            log.error(f"[RECYCLE] Erreur GET /gom-verdicts: {e}")
            return None

    def cancel_order(self, order_id: str, symbol: str, age_minutes: int) -> bool:
        """Annule un ordre limit via ai_server."""
        try:
            payload = {
                "order_id": order_id,
                "symbol": symbol,
                "reason": f"Ordre inactif {age_minutes}min (timeout 30min)"
            }
            r = requests.post(f"{AI_SERVER}/cancel-order", json=payload, timeout=5)

            if r.status_code == 200:
                log.info(f"[CANCEL] {symbol} ord#{order_id} annulé (age: {age_minutes}min)")
                self.recycled_count += 1
                return True
            else:
                log.warning(f"[CANCEL] Échec annulation {symbol} ord#{order_id}: HTTP {r.status_code}")
                return False

        except Exception as e:
            log.error(f"[CANCEL] Erreur annulation {symbol}: {e}")
            return False

    def place_new_order(self, symbol: str, direction: str, entry: float, sl: float, tp: float) -> bool:
        """Place un nouvel ordre limit sur symbol + direction."""
        try:
            action = "BUY" if direction > 0 else "SELL"
            payload = {
                "symbol": symbol,
                "action": action,
                "entry": entry,
                "sl": sl,
                "tp": tp,
                "order_type": "limit",
                "source": "order_recycler",
                "reason": "Recycled from expired order"
            }

            r = requests.post(f"{AI_SERVER}/place-order", json=payload, timeout=5)

            if r.status_code == 200:
                log.info(f"[PLACE] Nouvel ordre {action} {symbol} @ {entry} placé (recycled)")
                self.replaced_count += 1
                return True
            else:
                log.warning(f"[PLACE] Échec placement {symbol}: HTTP {r.status_code}")
                return False

        except Exception as e:
            log.error(f"[PLACE] Erreur placement {symbol}: {e}")
            return False

    def check_and_recycle_orders(self) -> Dict[str, Any]:
        """Main: check ordres > 30min, annuler et replacer."""
        log.info("=" * 70)
        log.info("[CYCLE] Vérification ordres limit timeout...")

        orders = self.get_pending_orders()
        if not orders:
            log.info("[CYCLE] Aucun ordre pending trouvé")
            return {"recycled": 0, "replaced": 0, "errors": []}

        errors = []
        now = datetime.now(timezone.utc)

        for order in orders:
            try:
                order_id = str(order.get("id") or order.get("order_id", "?"))
                symbol = str(order.get("symbol", "?"))
                created_at = order.get("created_at")

                if not created_at:
                    log.debug(f"[SKIP] {symbol} ord#{order_id}: pas de timestamp")
                    continue

                # Parser timestamp
                if isinstance(created_at, str):
                    created_dt = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                else:
                    created_dt = datetime.fromtimestamp(created_at, tz=timezone.utc)

                age = now - created_dt
                age_minutes = age.total_seconds() / 60.0

                log.debug(f"[CHECK] {symbol} ord#{order_id}: age={age_minutes:.1f}min")

                if age_minutes >= ORDER_TIMEOUT_MINUTES:
                    log.warning(f"[TIMEOUT] {symbol} ord#{order_id} timeout après {age_minutes:.0f}min")

                    # 1. Annuler l'ordre
                    if not self.cancel_order(order_id, symbol, int(age_minutes)):
                        errors.append(f"Annulation échouée {symbol} ord#{order_id}")
                        continue

                    # 2. Chercher meilleure entrée (autre symbol)
                    best = self.get_best_gom_verdict(exclude_symbol=symbol)
                    if not best:
                        log.warning(f"[RECYCLE] Pas de verdict meilleur trouvé pour remplacer {symbol}")
                        continue

                    # 3. Placer nouvel ordre sur meilleur symbol
                    if not self.place_new_order(
                        best["symbol"],
                        best["verdict_num"],
                        best["entry"],
                        best["sl"],
                        best["tp"]
                    ):
                        errors.append(f"Placement échoué sur {best['symbol']}")
                        continue

                    log.info(f"[RECYCLE] ✅ {symbol} ord#{order_id} → {best['symbol']} @ {best['entry']:.2f}")

            except Exception as e:
                log.error(f"[ERROR] Processing order: {e}")
                errors.append(str(e))

        result = {
            "recycled": self.recycled_count,
            "replaced": self.replaced_count,
            "errors": errors
        }

        log.info(f"[RESULT] Recyclés: {result['recycled']} | Remplacés: {result['replaced']} | Erreurs: {len(result['errors'])}")
        log.info("=" * 70)

        return result


def main():
    """Exécution unique: check et recycle."""
    import argparse

    parser = argparse.ArgumentParser(description="Order Recycler — recycle ordres timeout")
    parser.add_argument("--loop", action="store_true", help="Boucle continue (check toutes les 5min)")
    args = parser.parse_args()

    recycler = OrderRecycler()

    if args.loop:
        import time
        log.info("[START] Order Recycler BOUCLE CONTINUE (5min interval)")
        while True:
            recycler.check_and_recycle_orders()
            time.sleep(300)  # 5 minutes
    else:
        log.info("[START] Order Recycler EXÉCUTION UNIQUE")
        recycler.check_and_recycle_orders()


if __name__ == "__main__":
    main()
