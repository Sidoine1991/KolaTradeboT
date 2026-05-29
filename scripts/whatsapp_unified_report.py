#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WhatsApp Unified Report Generator
Collecte données TradingView + AI server + envoie UN message WhatsApp unifié via PsychoBot
"""

import os
import sys
import json
import time
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Optional, Tuple, Any
from dataclasses import dataclass

import requests
from dotenv import load_dotenv

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - [WhatsApp Reporter] - %(levelname)s - %(message)s'
)
logger = logging.getLogger("whatsapp_reporter")

# Load env
_root_dir = Path(__file__).resolve().parent.parent
load_dotenv(_root_dir / ".env")

AI_SERVER_URL = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000")
PSYCHOBOT_URL = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com")
WHATSAPP_PHONE = os.getenv("WHATSAPP_PHONE", "+2290196911346")
ALERTS_LOG = _root_dir / "whatsapp_alerts.log"


@dataclass
class TradingViewData:
    """Données TradingView collectées"""
    symbol: str
    price: float
    time_utc: int  # unix timestamp
    open: float
    high: float
    low: float
    close: float
    volume: int


@dataclass
class SessionBiasData:
    """Biais de session de l'AI server"""
    direction: str  # BUY, SELL, NEUTRAL
    confidence: float  # 0.0-1.0
    age_hours: float
    valid: bool
    expires_in_hours: float
    timestamp: str


@dataclass
class PendingOrderData:
    """Ordre en attente de l'EA TradeManager"""
    ok: bool
    symbol: str
    action: str  # BUY, SELL, NONE
    entry_price: Optional[float]
    stop_loss: Optional[float]
    take_profit: Optional[float]
    confidence: float
    gom_verdict: str
    gom_score_buy: float
    gom_score_sell: float
    status: str
    mt5_ticket: Optional[int]


@dataclass
class TradingAgentsData:
    """Rapport TradingAgents"""
    ok: bool
    direction: str  # BUY, SELL, NONE
    confidence: float
    age_minutes: float
    expires_in_minutes: float


class UnifiedReportGenerator:
    """Générateur de rapport WhatsApp unifié"""

    def __init__(self, symbol: str = "OANDA:XAUUSD"):
        self.symbol = symbol
        self.tv_data: Optional[TradingViewData] = None
        self.bias_data: Optional[SessionBiasData] = None
        self.order_data: Optional[PendingOrderData] = None
        self.ta_data: Optional[TradingAgentsData] = None

    def fetch_tradingview_data(self) -> bool:
        """Récupère les données TradingView via MCP"""
        try:
            import subprocess
            # Appel au MCP TradingView pour récupérer quote
            result = subprocess.run(
                ["mcp", "tradingview-kola", "quote_get", f"symbol={self.symbol}"],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode == 0:
                data = json.loads(result.stdout)
                if data.get("success"):
                    self.tv_data = TradingViewData(
                        symbol=data["symbol"],
                        price=data["last"],
                        time_utc=data["time"],
                        open=data["open"],
                        high=data["high"],
                        low=data["low"],
                        close=data["close"],
                        volume=data["volume"]
                    )
                    logger.info(f"✅ TradingView: {self.symbol} @ ${self.tv_data.price:.2f}")
                    return True
        except Exception as e:
            logger.warning(f"TradingView fetch failed: {e}")

        return False

    def fetch_ai_server_data(self) -> bool:
        """Récupère les données de l'AI server"""
        all_ok = True

        # 1. Session Bias
        try:
            resp = requests.get(
                f"{AI_SERVER_URL}/session-bias",
                params={"symbol": self.symbol},
                timeout=5
            )
            if resp.status_code == 200:
                data = resp.json()
                if data.get("success"):
                    d = data["data"]
                    self.bias_data = SessionBiasData(
                        direction=d.get("direction", "NEUTRAL"),
                        confidence=float(d.get("confidence", 0)),
                        age_hours=float(d.get("age_hours", 0)),
                        valid=d.get("valid", False),
                        expires_in_hours=float(d.get("expires_in_hours", 0)),
                        timestamp=d.get("timestamp", "")
                    )
                    logger.info(f"✅ Session Bias: {self.bias_data.direction} {self.bias_data.confidence*100:.0f}%")
        except Exception as e:
            logger.warning(f"Session bias fetch failed: {e}")
            all_ok = False

        # 2. Pending Order
        try:
            resp = requests.get(
                f"{AI_SERVER_URL}/pending-order",
                params={"symbol": self.symbol},
                timeout=5
            )
            if resp.status_code == 200:
                data = resp.json()
                if data.get("ok"):
                    o = data["order"]
                    self.order_data = PendingOrderData(
                        ok=data["ok"],
                        symbol=o.get("symbol", ""),
                        action=o.get("action", "NONE"),
                        entry_price=o.get("entry_price"),
                        stop_loss=o.get("stop_loss"),
                        take_profit=o.get("take_profit"),
                        confidence=float(o.get("confidence", 0)),
                        gom_verdict=o.get("gom_verdict", "NONE"),
                        gom_score_buy=float(o.get("gom_score_buy", 0)),
                        gom_score_sell=float(o.get("gom_score_sell", 0)),
                        status=o.get("status", ""),
                        mt5_ticket=o.get("mt5_ticket")
                    )
                    logger.info(f"✅ Pending Order: {self.order_data.action} @ ${self.order_data.entry_price}")
                else:
                    logger.info("📭 No pending order")
        except Exception as e:
            logger.warning(f"Pending order fetch failed: {e}")
            all_ok = False

        # 3. TradingAgents Report
        try:
            resp = requests.get(
                f"{AI_SERVER_URL}/tradingagents/report-status",
                params={"symbol": self.symbol},
                timeout=5
            )
            if resp.status_code == 200:
                data = resp.json()
                self.ta_data = TradingAgentsData(
                    ok=data.get("ok", False),
                    direction=data.get("direction", "NONE"),
                    confidence=float(data.get("confidence", 0)),
                    age_minutes=float(data.get("age_minutes", 0)),
                    expires_in_minutes=float(data.get("expires_in_minutes", 0))
                )
                if self.ta_data.ok:
                    logger.info(f"✅ TradingAgents: {self.ta_data.direction} {self.ta_data.confidence*100:.0f}%")
                else:
                    logger.info("⚠️ TradingAgents: pas de rapport actif")
        except Exception as e:
            logger.warning(f"TradingAgents fetch failed: {e}")
            all_ok = False

        return all_ok

    def build_message(self) -> str:
        """Construit le message WhatsApp unifié"""
        now_utc = datetime.now(timezone.utc)
        time_str = now_utc.strftime("%H:%M")
        date_str = now_utc.strftime("%d/%m")

        # En-tête
        msg = f"📊 *TradBOT [{time_str} UTC]*\n\n"
        msg += f"*{self.symbol.split(':')[1]} — Suivi 20min* | {date_str} {time_str} UTC\n"
        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Prix live et indicateurs TradingView
        if self.tv_data:
            msg += f"💰 *Prix live :* ${self.tv_data.price:.2f}\n"
            msg += f"   Open: ${self.tv_data.open:.2f} | High: ${self.tv_data.high:.2f} | Low: ${self.tv_data.low:.2f}\n"
        else:
            msg += "💰 *Prix live :* ⚠️ TradingView indisponible\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Verdict GOM (Pending Order)
        if self.order_data and self.order_data.ok:
            verdict_emoji = "🟢" if self.order_data.action == "BUY" else "🔴"
            msg += f"{verdict_emoji} *Verdict GOM KOLA : {self.order_data.action}*\n"
            msg += f"   Score BUY={self.order_data.gom_score_buy:.1f}  SELL={self.order_data.gom_score_sell:.1f}\n"
            msg += f"   Verdict: {self.order_data.gom_verdict}\n"
            if self.order_data.entry_price:
                msg += f"   Entry: ${self.order_data.entry_price:.2f} | SL: ${self.order_data.stop_loss:.2f} | TP: ${self.order_data.take_profit:.2f}\n"
            msg += f"   Ticket MT5: {self.order_data.mt5_ticket or 'N/A'}\n"
        else:
            msg += "⚠️ *Verdict GOM KOLA : ATTENTE*\n"
            msg += "   Aucun ordre en attente\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Biais de session
        if self.bias_data:
            bias_emoji = "🟢" if self.bias_data.direction == "BUY" else "🔴" if self.bias_data.direction == "SELL" else "⚪"
            valid_emoji = "✅" if self.bias_data.valid else "❌"
            msg += f"{bias_emoji} *Biais session :* {self.bias_data.direction} {self.bias_data.confidence*100:.0f}% | {valid_emoji} valide {self.bias_data.expires_in_hours:.1f}h\n"
        else:
            msg += "⚠️ *Biais session :* AI server hors ligne\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Rapport TradingAgents
        if self.ta_data and self.ta_data.ok:
            ta_emoji = "🟢" if self.ta_data.direction == "BUY" else "🔴" if self.ta_data.direction == "SELL" else "⚪"
            msg += f"{ta_emoji} *Rapport TradingAgents :* {self.ta_data.direction} {self.ta_data.confidence*100:.0f}%\n"
            msg += f"   Age: {self.ta_data.age_minutes:.0f}min | Expire: {self.ta_data.expires_in_minutes:.0f}min\n"
        else:
            msg += "📭 *Rapport TradingAgents :* Aucun rapport actif\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Analyse croisée
        confluence_count = 0
        if self.order_data and self.order_data.ok and self.order_data.action == "BUY":
            confluence_count += 1
        if self.bias_data and self.bias_data.direction == "BUY":
            confluence_count += 1
        if self.ta_data and self.ta_data.ok and self.ta_data.direction == "BUY":
            confluence_count += 1

        msg += "🔬 *Analyse croisée*\n"
        if confluence_count >= 2:
            msg += f"   ✅ Confluence {confluence_count}/3 pour BUY\n"
            msg += "   🎯 *Décision : BUY*\n"
        elif confluence_count == 1:
            msg += f"   ⚠️ Confluence faible {confluence_count}/3\n"
            msg += "   🎯 *Décision : ATTENDRE*\n"
        else:
            msg += "   ❌ Pas de confluence\n"
            msg += "   🎯 *Décision : WAIT*\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"
        msg += "_Prochain check dans 20 min_\n"

        return msg

    def send_whatsapp(self, message: str) -> bool:
        """Envoie le message via PsychoBot"""
        try:
            payload = {
                "phone": WHATSAPP_PHONE,
                "message": message
            }

            resp = requests.post(
                f"{PSYCHOBOT_URL}/send-message",
                json=payload,
                timeout=10,
                verify=False
            )

            if resp.status_code in [200, 201, 202]:
                logger.info("✅ Message WhatsApp envoyé via PsychoBot")
                return True
            else:
                logger.error(f"❌ PsychoBot error {resp.status_code}: {resp.text}")
                return False

        except Exception as e:
            logger.error(f"❌ Exception WhatsApp: {e}")
            return False

    def fallback_to_log(self, message: str):
        """Fallback: enregistre le message dans un log file"""
        try:
            with open(ALERTS_LOG, "a", encoding="utf-8") as f:
                f.write(f"\n[{datetime.now(timezone.utc).isoformat()}]\n{message}\n")
            logger.info(f"✅ Message enregistré dans {ALERTS_LOG}")
        except Exception as e:
            logger.error(f"Fallback log failed: {e}")

    def run(self):
        """Workflow complet: fetch → build → send"""
        logger.info(f"🔄 Démarrage rapport unifié pour {self.symbol}")

        # 1. Fetch TradingView
        tv_ok = self.fetch_tradingview_data()

        # 2. Fetch AI server
        ai_ok = self.fetch_ai_server_data()

        # 3. Build message
        message = self.build_message()

        # 4. Send WhatsApp
        whatsapp_ok = self.send_whatsapp(message)

        if not whatsapp_ok:
            logger.warning("Fallback: enregistrement dans log")
            self.fallback_to_log(message)

        logger.info("✅ Rapport complet généré et envoyé")
        return message


def main():
    """Point d'entrée"""
    generator = UnifiedReportGenerator(symbol="OANDA:XAUUSD")
    message = generator.run()

    # Écrire dans un fichier pour éviter les problèmes d'encodage
    output_file = _root_dir / "last_whatsapp_report.txt"
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(message)
    logger.info(f"Message écrit dans {output_file}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.info("Arrêt")
        sys.exit(0)
