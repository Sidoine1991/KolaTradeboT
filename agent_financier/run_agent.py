#!/usr/bin/env python3
"""
run_agent.py – Agent Financier SMC
Orchestre le workflow complet.
"""
import logging
from datetime import datetime
from pathlib import Path
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

from mcp_bridge import MCPBridge
from charts.chart_generator import ChartGenerator
from whatsapp.whatsapp_sender import WhatsAppSender
import yaml

LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / f"agent_{datetime.now():%Y%m%d}.log"),
        logging.StreamHandler(sys.stdout),
    ],
)
logger = logging.getLogger(__name__)


class AgentFinancierOrchestrator:
    """Orchestre le workflow : scan → analyse → génération → WhatsApp."""

    def __init__(self, config_path="config/config.yaml"):
        self.config_path = Path(__file__).parent / config_path
        self.config = self._load_config()
        self.mcp = MCPBridge()
        self.chart_gen = ChartGenerator()
        self.whatsapp = WhatsAppSender()
        self.logger = logger

    def _load_config(self):
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)
        except Exception as e:
            logger.error("Erreur config: %s", e)
            return {}

    def run(self):
        self.logger.info("=== AGENT FINANCIER SMC – LANCEMENT ===")
        # 1. Symboles
        symbols = self._get_symbols()
        self.logger.info("%s symboles à analyser", len(symbols))
        # 2. Analyse
        setups = self.mcp.batch_analyze(symbols)
        self.logger.info("%s setups valides trouvés", len(setups))
        if not setups:
            self.whatsapp.send_daily_report([], [])
            self.logger.info("Aucun setup détecté – rapport envoyé")
            return
        # 3. Charts
        chart_paths = self.chart_gen.generate_all_charts(setups)
        self.logger.info("%s charts générés", len(chart_paths))
        # 4. WhatsApp
        self.whatsapp.send_daily_report(setups, chart_paths)
        self.logger.info("Rapport WhatsApp envoyé")
        # 5. Terminé
        self.logger.info("=== AGENT FINANCIER SMC – TERMINÉ ===")

    def _get_symbols(self):
        symbols = []
        for category in self.config.get("symbols", {}).values():
            exchange = "OANDA" if category["pairs"][0] in ["EURUSD", "XAUUSD"] else "BINANCE"
            for pair in category["pairs"]:
                symbols.append({"symbol": pair, "exchange": exchange})
        return symbols


if __name__ == "__main__":
    orchestrator = AgentFinancierOrchestrator()
    orchestrator.run()
