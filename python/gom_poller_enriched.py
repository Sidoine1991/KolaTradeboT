#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Poller Enriched — Combine Deriv WebSocket + yfinance + calculs locaux
Met à jour gom_signal.json avec prix réels du marché
"""
import json
import sys
import time
import logging
import asyncio
from pathlib import Path
from datetime import datetime, timezone

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

sys.path.insert(0, str(Path(__file__).parent))

from typing import Dict, Any
from market_data_client import YFinanceClient, MarketDataClient
from deriv_ws_client import DerivWSClient
from gom_pine_calculator import GOMLPineCalculator

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler("logs/gom_poller_enriched.log", encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger(__name__)

GOM_FILE = Path("data/gom_signal.json")
POLL_INTERVAL = 60  # 1 min

class EnrichedGOMPoller:
    """Poller GOM avec données marché réelles."""

    def __init__(self):
        self.gom_file = GOM_FILE
        self.calc = GOMLPineCalculator()
        self.deriv_client = None
        self.cycle = 0

    async def enrich_symbol(self, symbol: str, record: Dict) -> Dict:
        """Enrichit un symbole avec données marché + calculs."""
        try:
            # === BOOM/CRASH: Deriv WebSocket ===
            if "Boom" in symbol or "Crash" in symbol:
                if not self.deriv_client:
                    self.deriv_client = DerivWSClient()
                    await self.deriv_client.connect()

                snapshot = await self.deriv_client.get_full_snapshot(symbol)
                if snapshot and "error" not in snapshot:
                    record.update({
                        "entry": snapshot.get("close", record.get("entry", 0)),
                        "bb_mid": snapshot.get("bb_mid", record.get("bb_mid", 0)),
                        "bb_up": snapshot.get("bb_up", record.get("bb_up", 0)),
                        "bb_dn": snapshot.get("bb_dn", record.get("bb_dn", 0)),
                        "tf_m1_rsi": int(snapshot.get("rsi", 50)) if snapshot.get("rsi") else 50,
                    })
                    log.info(f"📡 {symbol}: Deriv WebSocket OK")

            # === AUTRE: yfinance ===
            elif any(s in symbol.upper() for s in ["XAU", "BTC", "ETH", "EUR", "GBP", "USD", "NZD", "AUD"]):
                snapshot = MarketDataClient.get_snapshot(symbol)
                if snapshot and "error" not in snapshot:
                    record.update({
                        "entry": snapshot.get("close", record.get("entry", 0)),
                        "bb_mid": snapshot.get("bb_mid", record.get("bb_mid", 0)),
                        "bb_up": snapshot.get("bb_up", record.get("bb_up", 0)),
                        "bb_dn": snapshot.get("bb_dn", record.get("bb_dn", 0)),
                        "tf_m1_rsi": int(snapshot.get("rsi", 50)) if snapshot.get("rsi") else 50,
                    })
                    log.info(f"📡 {symbol}: yfinance OK")

        except Exception as e:
            log.warning(f"⚠️  Erreur enrichissement {symbol}: {e}")

        # === Calculer verdicts localement ===
        record = self.calc.enrich_record(record)

        return record

    async def process_cycle(self):
        """Une itération du poller."""
        if not self.gom_file.exists():
            log.error(f"❌ {self.gom_file} non trouvé")
            return

        try:
            # Charger
            data = json.loads(self.gom_file.read_text(encoding="utf-8"))

            # Enrichir chaque symbole
            for symbol in data:
                data[symbol] = await self.enrich_symbol(symbol, data[symbol])

            # Sauvegarder
            self.gom_file.write_text(json.dumps(data, indent=2, ensure_ascii=False))

            # Log résumé
            buy_count = sum(1 for s in data if data[s].get("verdict_num", 0) > 0)
            sell_count = sum(1 for s in data if data[s].get("verdict_num", 0) < 0)
            wait_count = sum(1 for s in data if data[s].get("verdict_num", 0) == 0)

            log.info(f"✅ Cycle #{self.cycle} — BUY:{buy_count} SELL:{sell_count} WAIT:{wait_count}")

        except Exception as e:
            log.error(f"❌ Erreur cycle: {e}")

    async def run(self):
        """Boucle principale."""
        log.info("="*70)
        log.info("🚀 GOM Poller Enriched démarré (Deriv WS + yfinance)")
        log.info(f"   Intervalle: {POLL_INTERVAL}s")
        log.info("="*70)

        while True:
            self.cycle += 1
            try:
                await self.process_cycle()
                await asyncio.sleep(POLL_INTERVAL)

            except KeyboardInterrupt:
                log.info("\n⏹  Arrêt utilisateur")
                break
            except Exception as e:
                log.error(f"❌ Erreur boucle: {e}")
                await asyncio.sleep(POLL_INTERVAL)

        # Cleanup
        if self.deriv_client:
            await self.deriv_client.disconnect()


async def main():
    """Démarrer le poller."""
    poller = EnrichedGOMPoller()
    await poller.run()


if __name__ == "__main__":
    asyncio.run(main())
