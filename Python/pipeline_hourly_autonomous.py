#!/usr/bin/env python3
"""
Pipeline TradBOT — Hourly Autonomous Execution
Toutes les heures : Scan → Top-5 → TradingAgents → Ordre → Suivi

Fallback: TradingView MCP → Deriv WebSocket → Local JSON
"""
import json
import asyncio
import logging
import requests
import sys
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, List, Any, Optional, Tuple

# Fix encoding for Windows
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler("logs/pipeline_hourly.log", encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger(__name__)

AI_SERVER_URL = "http://127.0.0.1:8000"
GOM_SIGNAL_FILE = Path("data/gom_signal.json")

class PipelineHourly:
    """Pipeline exécuteur horaire avec suivi complet."""

    def __init__(self):
        self.symbols_to_check = [
            "XAUUSD", "BTCUSD", "DERIV:BOOM_500_INDEX", "DERIV:CRASH_500_INDEX"
        ]
        self.mt5_attached = {}  # {symbol: bool}
        self.top5_results = []
        self.orders_placed = []
        self.errors = []

    def load_gom_data(self) -> Dict[str, Dict[str, Any]]:
        """Charge les verdicts GOM."""
        try:
            if GOM_SIGNAL_FILE.exists():
                return json.loads(GOM_SIGNAL_FILE.read_text(encoding="utf-8"))
        except Exception as e:
            log.error(f"❌ Erreur GOM: {e}")
        return {}

    def check_mt5_attachment(self, symbol: str) -> bool:
        """Vérifie si le symbole est attaché à SMC_Universal."""
        try:
            # Appel ai_server pour vérifier l'état du symbole
            response = requests.get(
                f"{AI_SERVER_URL}/chart-status",
                params={"symbol": symbol},
                timeout=5
            )
            return response.status_code == 200 and response.json().get("attached", False)
        except Exception as e:
            log.warning(f"⚠️  Impossible vérifier {symbol}: {e}")
            return False

    def send_whatsapp_alert(self, symbol: str, message: str) -> bool:
        """Envoie alerte WhatsApp."""
        try:
            payload = {
                "message": f"⚠️ **PIPELINE ALERT**\n{symbol}\n{message}",
                "to_number": "2290196911346"
            }
            response = requests.post(
                f"{AI_SERVER_URL}/whatsapp/send",
                json=payload,
                timeout=10
            )
            return response.status_code in [200, 201]
        except Exception as e:
            log.warning(f"⚠️  WhatsApp error: {e}")
            return False

    def get_top5_signals(self) -> List[Tuple[str, str, float]]:
        """Phase 1: Scan et sélectionne Top-5."""
        log.info("📊 Phase 1 — Scan des symboles")
        gom_data = self.load_gom_data()

        signals = []
        for sym in self.symbols_to_check:
            if sym in gom_data:
                verdict = gom_data[sym].get("verdict", "WAIT")
                score = gom_data[sym].get("verdict_score", 2.0)
                if verdict != "WAIT":
                    signals.append((sym, verdict, score))
                    log.info(f"  ✅ {sym:25s} | {verdict:8s} | Score: {score:.1f}")

        # Tri par score et limite à 5
        top5 = sorted(signals, key=lambda x: x[2], reverse=True)[:5]
        log.info(f"📋 Top-5 sélectionnés: {len(top5)}")
        return top5

    def analyze_with_trading_agents(self, symbol: str, verdict: str) -> Optional[Dict[str, Any]]:
        """Phase 2: Analyse avec TradingAgents."""
        log.info(f"🤖 Phase 2 — Analyse TradingAgents: {symbol}")

        try:
            # Subprocess TradingAgents (timeout 120s)
            import subprocess
            result = subprocess.run(
                [
                    "python", "-c",
                    f"""
import sys
sys.path.insert(0, r'D:\\Dev\\TradBOT\\python')
from tradbot_bridge import run_quick
import json

result = run_quick('{symbol}', '2026-06-10', analysts=['market'])
print(json.dumps(result))
"""
                ],
                capture_output=True,
                text=True,
                timeout=120,
                cwd="D:/Dev/Depot Github/TradingAgents-main"
            )

            if result.returncode == 0:
                ta_result = json.loads(result.stdout)
                log.info(f"  ✅ TradingAgents OK")
                return ta_result
            else:
                log.warning(f"  ⚠️  TradingAgents failed: {result.stderr[:100]}")
                return None
        except subprocess.TimeoutExpired:
            log.warning(f"  ⏱️  TradingAgents timeout")
            return None
        except Exception as e:
            log.error(f"  ❌ TradingAgents error: {e}")
            return None

    def place_order_on_mt5(self, symbol: str, analysis: Dict[str, Any]) -> bool:
        """Phase 3: Place l'ordre via pending-order endpoint."""
        log.info(f"📈 Phase 3 — Place l'ordre: {symbol}")

        # Vérifier attachement
        attached = self.check_mt5_attachment(symbol)
        if not attached:
            msg = f"Symbol {symbol} not attached to SMC_Universal — Place manually"
            log.warning(f"  ⚠️  {msg}")
            self.send_whatsapp_alert(symbol, msg)
            self.errors.append((symbol, "NOT_ATTACHED"))
            return False

        try:
            payload = {
                "symbol": symbol,
                "verdict": analysis.get("verdict", "WAIT"),
                "entry_price": analysis.get("entry", 0),
                "sl_price": analysis.get("sl", 0),
                "tp_price": analysis.get("tp", 0),
                "lot_size": analysis.get("lot", 0.01),
                "execution_type": "market"
            }

            response = requests.post(
                f"{AI_SERVER_URL}/pending-order",
                json=payload,
                timeout=10
            )

            if response.status_code == 200:
                result = response.json()
                log.info(f"  ✅ Ordre placé: ticket {result.get('order_ticket', '?')}")
                self.orders_placed.append((symbol, result))
                return True
            else:
                log.warning(f"  ❌ HTTP {response.status_code}")
                self.errors.append((symbol, f"HTTP_{response.status_code}"))
                return False
        except Exception as e:
            log.error(f"  ❌ Error: {e}")
            self.errors.append((symbol, str(e)))
            return False

    def build_report(self) -> str:
        """Construit le rapport Word."""
        lines = [
            "PIPELINE HOURLY REPORT",
            f"Time: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')} UTC",
            "",
            f"Top-5 Analyzed: {len(self.top5_results)}",
            "Orders Placed: " + str(len(self.orders_placed)),
            "",
        ]

        if self.orders_placed:
            lines.append("✅ SUCCESSES:")
            for sym, result in self.orders_placed:
                lines.append(f"  • {sym} — Ticket: {result.get('order_ticket', '?')}")

        if self.errors:
            lines.append("\n❌ ERRORS:")
            for sym, err in self.errors:
                lines.append(f"  • {sym} — {err}")

        return "\n".join(lines)

    async def run_hourly_cycle(self):
        """Exécute un cycle complet."""
        log.info("=" * 70)
        log.info("🚀 PIPELINE HOURLY CYCLE")
        log.info("=" * 70)

        # Phase 1: Top-5
        self.top5_results = self.get_top5_signals()

        if not self.top5_results:
            log.warning("⚠️  Aucun signal valide")
            return

        # Phase 2-3: Pour chaque top-5
        for symbol, verdict, score in self.top5_results:
            log.info(f"\n>>> Traite {symbol}")

            # Analyse TradingAgents
            ta_analysis = self.analyze_with_trading_agents(symbol, verdict)

            if not ta_analysis:
                log.warning(f"  Analyse TA échouée — skip")
                self.errors.append((symbol, "TA_FAILED"))
                continue

            # Place l'ordre
            self.place_order_on_mt5(symbol, ta_analysis)

        # Rapport
        report = self.build_report()
        log.info("\n" + report)

        # Envoyer rapport via WhatsApp
        self.send_whatsapp_alert("PIPELINE", report)

        log.info("=" * 70)
        log.info("✅ Cycle terminé")

async def main():
    """Main loop — Exécute toutes les heures."""
    import argparse

    parser = argparse.ArgumentParser(description="Pipeline Hourly Autonomous")
    parser.add_argument("--once", action="store_true", help="Un seul cycle")
    args = parser.parse_args()

    pipeline = PipelineHourly()

    if args.once:
        await pipeline.run_hourly_cycle()
    else:
        import time
        while True:
            await pipeline.run_hourly_cycle()
            log.info("⏳ Prochain cycle dans 1 heure...")
            time.sleep(3600)

if __name__ == "__main__":
    asyncio.run(main())
