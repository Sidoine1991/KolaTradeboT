#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module de notifications WhatsApp pour les alertes FVG Spike
Envoi de messages formatés lors des alertes M5 et signaux M1
"""

import os
import logging
import asyncio
from datetime import datetime
from typing import Optional
import aiohttp
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv()

logger = logging.getLogger("fvg_spike_whatsapp")

class WhatsAppNotifier:
    """Gestionnaire de notifications WhatsApp pour trading"""
    
    def __init__(self):
        # Configuration depuis les variables d'environnement
        self.phone_number = os.getenv("WHATSAPP_PHONE_NUMBER", "")
        self.api_key = os.getenv("WHATSAPP_API_KEY", "")
        self.api_url = os.getenv("WHATSAPP_API_URL", "https://api.callmebot.com/whatsapp.php")
        self.enabled = bool(self.phone_number and self.api_key)
        
        if not self.enabled:
            logger.warning("WhatsApp notifier non configuré - set WHATSAPP_PHONE_NUMBER et WHATSAPP_API_KEY")
    
    async def send_message(self, message: str, priority: str = "normal") -> bool:
        """
        Envoie un message WhatsApp via l'API CallMeBot
        
        Args:
            message: Texte du message à envoyer
            priority: "normal", "high", "critical"
            
        Returns:
            True si envoyé avec succès
        """
        if not self.enabled:
            logger.debug("WhatsApp désactivé - message non envoyé")
            return False
        
        try:
            # Format du message avec emojis selon la priorité
            emoji_map = {
                "normal": "⚪",
                "high": "🟡",
                "critical": "🔴"
            }
            emoji = emoji_map.get(priority, "⚪")
            
            formatted_message = f"{emoji} *FVG SPIKE DETECTOR*\n\n{message}\n\n"
            formatted_message += f"_{datetime.now().strftime('%H:%M:%S')}_"
            
            # Appel API CallMeBot (gratuit via connexion WiFi - voir callmebot.com)
            params = {
                "phone": self.phone_number,
                "text": formatted_message,
                "apikey": self.api_key
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.get(self.api_url, params=params, timeout=aiohttp.ClientTimeout(total=10)) as response:
                    if response.status == 200:
                        logger.info(f"✅ Notification WhatsApp envoyée (prio={priority})")
                        return True
                    else:
                        logger.error(f"❌ Erreur WhatsApp API: {response.status}")
                        return False
                        
        except asyncio.TimeoutError:
            logger.error("⏱️ Timeout envoi WhatsApp")
            return False
        except Exception as e:
            logger.error(f"❌ Erreur envoi WhatsApp: {e}")
            return False
    
    async def send_m5_alert(self, symbol: str, fvg_size: float, confidence: float):
        """Envoie une alerte pour FVG Supply détecté en M5"""
        message = (
            f"🚨 *ALERTE M5 - FVG SUPPLY*\n\n"
            f"📊 *Symbole:* {symbol}\n"
            f"📏 *Taille FVG:* {fvg_size:.2f}\n"
            f"🎯 *Confiance:* {confidence:.0%}\n\n"
            f"⏳ En attente de confirmation M1...\n"
            f"💡 Le système surveille maintenant le timeframe M1 "
            f"pour un second FVG Supply confirmant le spike."
        )
        return await self.send_message(message, priority="high")
    
    async def send_m1_signal(self, symbol: str, direction: str, 
                            entry: float, sl: float, tp: float, 
                            lot: float, confidence: float,
                            risk_usd: float = 2.50):
        """Envoie un signal de trade déclenché par confluence M5+M1"""
        rr = abs(tp - entry) / abs(entry - sl) if entry != sl else 0
        
        message = (
            f"🚀 *SIGNAL TRADE - CONFLUENCE M5+M1*\n\n"
            f"📊 *Symbole:* {symbol}\n"
            f"📉 *Direction:* {direction}\n"
            f"💰 *Entry:* {entry:.5f}\n"
            f"🛑 *SL:* {sl:.5f}\n"
            f"🎯 *TP:* {tp:.5f}\n"
            f"📐 *Lot:* {lot}\n"
            f"🎯 *Confiance:* {confidence:.0%}\n"
            f"⚖️ *Risk/Reward:* 1:{rr:.1f}\n"
            f"💵 *Risque Max:* ${risk_usd}\n\n"
            f"✅ *Action recommandée:* Ouvrir position {direction}"
        )
        return await self.send_message(message, priority="critical")
    
    async def send_position_update(self, symbol: str, pnl: float, 
                                   status: str, lots: float):
        """Envoi un update sur le statut d'une position"""
        emoji = "🟢" if pnl > 0 else "🔴"
        message = (
            f"{emoji} *UPDATE POSITION*\n\n"
            f"📊 *Symbole:* {symbol}\n"
            f"💰 *P&L:* ${pnl:.2f}\n"
            f"📐 *Lots:* {lots}\n"
            f"📋 *Statut:* {status}\n"
        )
        return await self.send_message(message, priority="normal")


# Instanciation globale pour utilisation dans le détecteur
whatsapp_notifier = WhatsAppNotifier()


async def send_whatsapp_alert(alert_type: str, **kwargs):
    """
    Fonction utilitaire pour envoyer des notifications
    
    Usage:
        await send_whatsapp_alert("m5", symbol="Boom 500", fvg_size=1.5, confidence=0.85)
        await send_whatsapp_alert(" positions", symbol="Boom 500", pnl=-1.25, status="OPEN")
    """
    notifier = whatsapp_notifier
    
    if alert_type == "m5":
        return await notifier.send_m5_alert(
            kwargs.get("symbol"), 
            kwargs.get("fvg_size", 0), 
            kwargs.get("confidence", 0)
        )
    elif alert_type == "m1":
        return await notifier.send_m1_signal(
            kwargs.get("symbol"),
            kwargs.get("direction", "SELL"),
            kwargs.get("entry", 0),
            kwargs.get("sl", 0),
            kwargs.get("tp", 0),
            kwargs.get("lot", 0.01),
            kwargs.get("confidence", 0)
        )
    elif alert_type == "position":
        return await notifier.send_position_update(
            kwargs.get("symbol"),
            kwargs.get("pnl", 0),
            kwargs.get("status", "OPEN"),
            kwargs.get("lots", 0.01)
        )
    else:
        message = kwargs.get("message", "Notification FVG Spike")
        priority = kwargs.get("priority", "normal")
        return await notifier.send_message(message, priority)


# Exemple d'utilisation
if __name__ == "__main__":
    async def test():
        # Test alerte M5
        await send_whatsapp_alert("m5", symbol="Boom 500", fvg_size=2.5, confidence=0.82)
        
        # Test signal M1
        await send_whatsapp_alert(
            "m1", 
            symbol="Boom 500", 
            direction="SELL",
            entry=100.50,
            sl=100.80,
            tp=99.90,
            lot=0.50,
            confidence=0.91
        )
    
    asyncio.run(test())
