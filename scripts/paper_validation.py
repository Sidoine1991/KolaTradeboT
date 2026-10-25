#!/usr/bin/env python3
"""
Script de validation Paper Trading pour TradBOT
Lance le moteur en mode simulation et surveille les métriques clés.
"""
import sys
import time
import json
import logging
from pathlib import Path
from datetime import datetime, timezone

# Ajouter le chemin du projet
sys.path.insert(0, str(Path(__file__).parent.parent))

from core.engine import TradingEngine, EngineConfig

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%H:%M:%S"
)
log = logging.getLogger("paper_validation")

# ─── Configuration Paper Trading ───
PAPER_CONFIG = EngineConfig(
    scan_interval=15.0,
    gom_min_coherence=70.0,
    require_pattern_alignment=True,
    min_signal_strength=0.5,
    enable_auto_close=True,
    enable_auto_trade=True,  # En paper, on simule seulement
    max_spread_multiplier=3.0,
    default_lot=0.01,
    trailing_activation_pips=5.0,
    trailing_distance_pips=3.0,
    trailing_step_pips=1.0,
    dow_blocking_enabled=True,
    dow_blocking_threshold_pips=80.0,
    dow_blocking_threshold_coherence=70.0,
    dow_blocking_strict_entry=True,
)

# Seuils de validation
VALIDATION_THRESHOLDS = {
    "max_daily_loss_usd": 20.0,
    "max_trade_loss_usd": 3.0,
    "min_winrate_pct": 48.0,
    "min_profit_factor": 1.3,
    "max_drawdown_pct": 15.0,
    "max_trades_per_day": 12,
}

class PaperValidator:
    def __init__(self):
        self.engine = TradingEngine(phone="+2290196911346", config=PAPER_CONFIG)
        self.start_time = time.time()
        self.daily_pnl = 0.0
        self.trades = []
        self.losses_today = 0
        self.consecutive_losses = 0

    def run_cycle(self):
        """Exécute un cycle et analyse les résultats"""
        report = self.engine.run_once()

        # Analyser les ordres
        for order in report.get("orders", []):
            if order.get("success", True):
                self.trades.append({
                    "time": time.time(),
                    "symbol": order["symbol"],
                    "direction": order["direction"],
                    "lot": order["lot"],
                    "entry": order["price"],
                    "sl": order["sl"],
                    "tp": order["tp"],
                    "ticket": order["ticket"],
                })
                log.info(f"📝 PAPER ORDER: {order['direction']} {order['symbol']} "
                         f"@{order['price']:.5f} SL={order['sl']:.5f} TP={order['tp']:.5f} "
                         f"Lot={order['lot']:.2f} Ticket={order['ticket']}")

        # Analyser les fermetures
        for close in report.get("closes", []):
            profit = close.get("profit", 0.0)
            self.daily_pnl += profit
            self.trades[-1]["exit_profit"] = profit if self.trades else 0
            self.trades[-1]["exit_time"] = time.time()

            if profit < 0:
                self.losses_today += 1
                self.consecutive_losses += 1
            else:
                self.consecutive_losses = 0

            log.info(f"🔒 PAPER CLOSE: {close['symbol']} P&L={profit:.2f}$ "
                     f"Daily P&L={self.daily_pnl:.2f}$ Consecutive losses={self.consecutive_losses}")

        return report

    def check_thresholds(self) -> dict:
        """Vérifie si les seuils de validation sont respectés"""
        results = {}

        # Perte journalière
        results["daily_loss_ok"] = abs(min(0, self.daily_pnl)) <= VALIDATION_THRESHOLDS["max_daily_loss_usd"]

        # Trades par jour
        today_trades = len([t for t in self.trades if time.time() - t["time"] < 86400])
        results["trades_per_day_ok"] = today_trades <= VALIDATION_THRESHOLDS["max_trades_per_day"]

        # Pertes consécutives
        results["consecutive_losses_ok"] = self.consecutive_losses < 3

        # Winrate (si assez de trades)
        closed_trades = [t for t in self.trades if "exit_profit" in t]
        if len(closed_trades) >= 10:
            wins = sum(1 for t in closed_trades if t["exit_profit"] > 0)
            winrate = (wins / len(closed_trades)) * 100
            results["winrate"] = winrate
            results["winrate_ok"] = winrate >= VALIDATION_THRESHOLDS["min_winrate_pct"]

            # Profit factor
            gross_profit = sum(t["exit_profit"] for t in closed_trades if t["exit_profit"] > 0)
            gross_loss = abs(sum(t["exit_profit"] for t in closed_trades if t["exit_profit"] < 0))
            if gross_loss > 0:
                pf = gross_profit / gross_loss
                results["profit_factor"] = pf
                results["profit_factor_ok"] = pf >= VALIDATION_THRESHOLDS["min_profit_factor"]

        return results

    def print_status(self):
        """Affiche le statut actuel"""
        status = self.engine.get_status()
        thresholds = self.check_thresholds()

        print("\n" + "="*60)
        print(f"📊 PAPER VALIDATION STATUS — {datetime.now().strftime('%H:%M:%S')}")
        print("="*60)
        print(f"⏱️  Uptime: {(time.time() - self.start_time)/60:.1f} min")
        print(f"🔄 Cycles: {status['cycle']}")
        print(f"📈 Daily P&L: ${self.daily_pnl:.2f}")
        print(f"📝 Total trades: {len(self.trades)}")
        print(f"❌ Losses today: {self.losses_today}")
        print(f"🔁 Consecutive losses: {self.consecutive_losses}")
        print(f"🎯 Active signals: {len(status['active_signals'])}")
        print(f"📍 Active positions: {len(status['active_positions'])}")

        print("\n📋 SEUILS DE VALIDATION:")
        for key, value in thresholds.items():
            if isinstance(value, bool):
                icon = "✅" if value else "❌"
                label = key.replace("_ok", "").replace("_", " ").title()
                print(f"   {icon} {label}: {'PASS' if value else 'FAIL'}")
            elif isinstance(value, float):
                label = key.replace("_", " ").title()
                print(f"   📊 {label}: {value:.2f}")

        # Dow blocking status
        dow = status["config"].get("dow_blocking", {})
        print(f"\n🛡️  DOW BLOCKING: enabled={dow.get('enabled')}, "
              f"threshold_pips={dow.get('threshold_pips')}, "
              f"threshold_coherence={dow.get('threshold_coherence')}")

        print("="*60 + "\n")

        return all(v for k, v in thresholds.items() if isinstance(v, bool) and k.endswith("_ok"))

def main():
    print("🚀 DÉMARRAGE PAPER VALIDATION TradBOT")
    print("="*60)
    print("Configuration:")
    print(f"  - Scan interval: {PAPER_CONFIG.scan_interval}s")
    print(f"  - GOM min coherence: {PAPER_CONFIG.gom_min_coherence}%")
    print(f"  - Dow blocking: {PAPER_CONFIG.dow_blocking_enabled} "
          f"(pips={PAPER_CONFIG.dow_blocking_threshold_pips}, "
          f"coherence={PAPER_CONFIG.dow_blocking_threshold_coherence}%)")
    print(f"  - Auto trade: {PAPER_CONFIG.enable_auto_trade}")
    print(f"  - Auto close: {PAPER_CONFIG.enable_auto_close}")
    print("="*60)
    print("⚠️  MODE PAPER — Aucune vraie ordre n'est envoyée au broker")
    print("   Surveillez les logs pour valider la logique d'entrée")
    print("="*60 + "\n")

    validator = PaperValidator()
    validator.engine.start()

    try:
        cycle = 0
        while True:
            cycle += 1
            validator.run_cycle()

            # Afficher statut tous les 10 cycles (~2.5 min)
            if cycle % 10 == 0:
                all_ok = validator.print_status()
                if not all_ok:
                    log.warning("⚠️  SEUILS NON RESPECTÉS — Vérification requise")

            # Arrêt d'urgence si perte journalière critique
            if validator.daily_pnl <= -VALIDATION_THRESHOLDS["max_daily_loss_usd"]:
                log.error(f"🛑 ARRÊT D'URGENCE: Perte journalière ${validator.daily_pnl:.2f} "
                          f"≥ ${VALIDATION_THRESHOLDS['max_daily_loss_usd']}")
                break

            time.sleep(PAPER_CONFIG.scan_interval)

    except KeyboardInterrupt:
        print("\n🛑 Arrêt demandé par l'utilisateur")
    finally:
        validator.engine.stop()
        validator.print_status()
        print("📝 Validation terminée")

if __name__ == "__main__":
    main()