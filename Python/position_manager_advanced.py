#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Position Manager Advanced — Trailing Stop + Breakeven SL + Real-time PnL
Gère automatiquement les positions ouvertes en temps réel
"""

import json
import time
import os
import sys
import requests
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Force UTF-8 on Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# Configuration
AI_SERVER = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000")
LOGS_DIR = Path("D:/Dev/TradBOT/logs")
LOGS_DIR.mkdir(parents=True, exist_ok=True)

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOGS_DIR / "position_manager.log", encoding='utf-8', mode='a'),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger(__name__)

# ============================================================================
# POSITION TRACKING
# ============================================================================

class PositionManager:
    """Gère les positions ouvertes avec trailing stop et breakeven SL"""

    def __init__(self):
        self.positions: Dict[str, Dict] = {}
        self.closed_positions: List[Dict] = []

    def add_position(self, symbol: str, action: str, entry: float, sl: float, tp: float, lot: float):
        """Ajoute une position à tracker"""
        pos_id = f"{symbol}_{len(self.positions)}"
        self.positions[pos_id] = {
            "id": pos_id,
            "symbol": symbol,
            "action": action.upper(),  # BUY or SELL
            "entry": float(entry),
            "initial_sl": float(sl),
            "current_sl": float(sl),
            "tp": float(tp),
            "lot": float(lot),
            "opened_at": datetime.now(timezone.utc).isoformat(),
            "highest_price": float(entry),  # Pour BUY
            "lowest_price": float(entry),   # Pour SELL
            "trailing_enabled": False,
            "breakeven_triggered": False,
            "status": "OPEN"
        }
        log.info(f"✅ Position ajoutée: {pos_id} | {symbol} {action} @ {entry}")
        return pos_id

    def update_prices(self, symbol: str, bid: float, ask: float) -> Dict[str, any]:
        """Met à jour les prix et gère trailing stop + breakeven"""
        updates = {}
        mid_price = (bid + ask) / 2

        for pos_id, pos in self.positions.items():
            if pos["status"] != "OPEN" or pos["symbol"] != symbol:
                continue

            action = pos["action"]
            entry = pos["entry"]
            current_sl = pos["current_sl"]
            tp = pos["tp"]
            profit_usd = self._calculate_pnl(pos, mid_price)
            profit_pct = (profit_usd / entry * 100) if entry > 0 else 0

            updates[pos_id] = {
                "symbol": symbol,
                "current_price": mid_price,
                "pnl_usd": profit_usd,
                "pnl_pct": profit_pct,
                "sl_old": current_sl,
                "sl_new": current_sl
            }

            # ──────────────────────────────────────────────────
            # 1. BREAKEVEN SL — Monter SL au prix d'entrée si profit > $2
            # ──────────────────────────────────────────────────
            if profit_usd >= 2.0 and not pos["breakeven_triggered"]:
                # Sécuriser le profit de $2 en montant SL à l'entry
                new_sl = entry
                pos["current_sl"] = new_sl
                pos["breakeven_triggered"] = True
                updates[pos_id]["sl_new"] = new_sl
                updates[pos_id]["action"] = "BREAKEVEN_SL"
                log.info(f"🔒 BREAKEVEN SL {pos_id}: Profit ${profit_usd:.2f} → SL @ Entry {entry:.5f}")

            # ──────────────────────────────────────────────────
            # 2. TRAILING STOP — Suit le profit, sécurise les gains
            # ──────────────────────────────────────────────────
            if profit_usd >= 2.0 and pos["breakeven_triggered"]:
                pos["trailing_enabled"] = True

                if action == "BUY":
                    # Pour BUY: SL monte mais ne descend jamais
                    if mid_price > pos["highest_price"]:
                        pos["highest_price"] = mid_price

                    # Trailing distance = 0.5% du prix courant (configurable)
                    trailing_distance = mid_price * 0.005  # 0.5%
                    new_trailing_sl = mid_price - trailing_distance

                    # SL monte seulement, ne descend jamais
                    if new_trailing_sl > current_sl:
                        pos["current_sl"] = new_trailing_sl
                        updates[pos_id]["sl_new"] = new_trailing_sl
                        updates[pos_id]["action"] = "TRAILING_STOP"
                        log.info(f"📈 TRAILING STOP {pos_id} (BUY): Current ${mid_price:.5f} → SL ${new_trailing_sl:.5f} (+${profit_usd:.2f})")

                elif action == "SELL":
                    # Pour SELL: SL descend mais ne monte jamais
                    if mid_price < pos["lowest_price"]:
                        pos["lowest_price"] = mid_price

                    trailing_distance = mid_price * 0.005  # 0.5%
                    new_trailing_sl = mid_price + trailing_distance

                    if new_trailing_sl < current_sl:
                        pos["current_sl"] = new_trailing_sl
                        updates[pos_id]["sl_new"] = new_trailing_sl
                        updates[pos_id]["action"] = "TRAILING_STOP"
                        log.info(f"📉 TRAILING STOP {pos_id} (SELL): Current ${mid_price:.5f} → SL ${new_trailing_sl:.5f} (+${profit_usd:.2f})")

            # ──────────────────────────────────────────────────
            # 3. VÉRIFIER TP HIT
            # ──────────────────────────────────────────────────
            if action == "BUY" and mid_price >= tp:
                pos["status"] = "CLOSED"
                self.closed_positions.append(pos)
                log.info(f"✅ TP HIT {pos_id}: {symbol} @ ${mid_price:.5f} | Profit: ${profit_usd:.2f}")
                updates[pos_id]["action"] = "TP_HIT"

            elif action == "SELL" and mid_price <= tp:
                pos["status"] = "CLOSED"
                self.closed_positions.append(pos)
                log.info(f"✅ TP HIT {pos_id}: {symbol} @ ${mid_price:.5f} | Profit: ${profit_usd:.2f}")
                updates[pos_id]["action"] = "TP_HIT"

            # ──────────────────────────────────────────────────
            # 4. VÉRIFIER SL HIT
            # ──────────────────────────────────────────────────
            if action == "BUY" and mid_price <= current_sl:
                pos["status"] = "CLOSED"
                self.closed_positions.append(pos)
                log.error(f"❌ SL HIT {pos_id}: {symbol} @ ${mid_price:.5f} | Loss: ${profit_usd:.2f}")
                updates[pos_id]["action"] = "SL_HIT"

            elif action == "SELL" and mid_price >= current_sl:
                pos["status"] = "CLOSED"
                self.closed_positions.append(pos)
                log.error(f"❌ SL HIT {pos_id}: {symbol} @ ${mid_price:.5f} | Loss: ${profit_usd:.2f}")
                updates[pos_id]["action"] = "SL_HIT"

        return updates

    def _calculate_pnl(self, pos: Dict, current_price: float) -> float:
        """Calcule le PnL en dollars"""
        entry = pos["entry"]
        lot = pos["lot"]
        action = pos["action"]

        if action == "BUY":
            pnl = (current_price - entry) * lot * 100  # lot = 0.01 = 1 mini lot
        else:  # SELL
            pnl = (entry - current_price) * lot * 100

        return pnl

    def get_positions_summary(self) -> str:
        """Retourne un résumé formaté des positions"""
        if not self.positions:
            return "Aucune position ouverte"

        lines = ["📊 POSITION SUMMARY", "=" * 80]

        total_pnl = 0
        for pos_id, pos in self.positions.items():
            if pos["status"] != "OPEN":
                continue

            symbol = pos["symbol"]
            action = pos["action"]
            entry = pos["entry"]
            sl = pos["current_sl"]
            tp = pos["tp"]
            breakeven = "🔒" if pos["breakeven_triggered"] else ""
            trailing = "📈" if pos["trailing_enabled"] else ""

            lines.append(f"{breakeven}{trailing} {pos_id}")
            lines.append(f"  Symbol: {symbol} {action} @ {entry:.5f}")
            lines.append(f"  SL: {sl:.5f} | TP: {tp:.5f}")
            lines.append(f"  Lot: {pos['lot']}")
            lines.append("")

        lines.append("=" * 80)
        return "\n".join(lines)

    def get_statistics(self) -> Dict:
        """Retourne les statistiques des positions fermées"""
        if not self.closed_positions:
            return {
                "closed_count": 0,
                "won_count": 0,
                "loss_count": 0,
                "total_profit": 0,
                "win_rate": 0
            }

        won = len([p for p in self.closed_positions if self._calculate_pnl(p, p["tp"]) > 0])
        loss = len(self.closed_positions) - won
        total_profit = sum(self._calculate_pnl(p, p["tp"]) for p in self.closed_positions)

        return {
            "closed_count": len(self.closed_positions),
            "won_count": won,
            "loss_count": loss,
            "total_profit": total_profit,
            "win_rate": round(won / len(self.closed_positions) * 100, 1) if self.closed_positions else 0
        }


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

def demo():
    """Démo du position manager"""
    log.info("=" * 80)
    log.info("🚀 POSITION MANAGER ADVANCED — DEMO")
    log.info("=" * 80)

    pm = PositionManager()

    # Ajouter quelques positions
    pm.add_position("XAUUSD", "BUY", 2200.50, 2190.00, 2210.00, 0.01)
    pm.add_position("EURUSD", "SELL", 1.0850, 1.0880, 1.0820, 0.01)

    # Simuler des mises à jour de prix
    log.info("\n📊 Simulation de mises à jour de prix:")
    prices = [
        ("XAUUSD", 2200.50, 2200.60),  # Entry
        ("XAUUSD", 2201.50, 2201.60),  # +1$ profit
        ("XAUUSD", 2202.50, 2202.60),  # +2$ profit → Breakeven SL
        ("XAUUSD", 2203.50, 2203.60),  # +3$ profit → Trailing Stop
        ("XAUUSD", 2204.50, 2204.60),  # +4$ profit → Trailing Stop monte
        ("XAUUSD", 2203.00, 2203.10),  # Retraitement → SL ne descend pas
        ("EURUSD", 1.0850, 1.0860),    # Entry
    ]

    for symbol, bid, ask in prices:
        time.sleep(0.5)
        updates = pm.update_prices(symbol, bid, ask)
        log.info(f"📍 {symbol} @ {(bid + ask) / 2:.5f}")

    # Résumé
    log.info("\n" + pm.get_positions_summary())
    stats = pm.get_statistics()
    log.info(f"📈 Stats: {stats}")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--demo":
        demo()
    else:
        log.info("Usage: python position_manager_advanced.py --demo")
