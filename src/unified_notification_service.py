"""
Service de notification unifié pour TradBOT
Support SMS et WhatsApp via Vonage + Firebase
Format optimisé basé sur Vonage
"""

import os
import requests
import json
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv()

logger = logging.getLogger(__name__)

class UnifiedNotificationService:
    """Service de notification unifié pour TradBOT"""
    
    def __init__(self):
        # Configuration Vonage
        self.vonage_api_key = os.getenv("VONAGE_API_KEY")
        self.vonage_api_secret = os.getenv("VONAGE_API_SECRET")
        self.vonage_sms_from = os.getenv("VONAGE_SMS_FROM", "TradBOT")
        self.vonage_whatsapp_from = os.getenv("VONAGE_WHATSAPP_FROM_SANDBOX", "14157386102")
        
        # Numéros de destination
        self.phone_number = os.getenv("VONAGE_SMS_TO", "22996911346")
        self.whatsapp_number = os.getenv("VONAGE_WHATSAPP_TO_SANDBOX", "22996911346")
        
        # Configuration Firebase (fallback)
        self.firebase_enabled = os.getenv("FIREBASE_ENABLED", "true").lower() == "true"
        
        # Services disponibles
        self.sms_enabled = bool(self.vonage_api_key and self.vonage_api_secret)
        self.whatsapp_enabled = bool(self.vonage_api_key and self.vonage_api_secret)
        
        logger.info(f"Service unifié initialisé - SMS: {self.sms_enabled}, WhatsApp: {self.whatsapp_enabled}")
    
    def send_trading_signal(self, signal_data: Dict[str, Any]) -> Dict[str, bool]:
        """Envoie un signal de trading via SMS et WhatsApp"""
        results = {"sms": False, "whatsapp": False, "firebase": False}
        
        # Formater le message selon le format Vonage optimisé
        message = self._format_trading_signal_message(signal_data)
        
        # Envoyer via SMS
        if self.sms_enabled:
            results["sms"] = self._send_sms(message)
        
        # Envoyer via WhatsApp
        if self.whatsapp_enabled:
            results["whatsapp"] = self._send_whatsapp(message)
        
        # Envoyer via Firebase (fallback)
        if self.firebase_enabled:
            results["firebase"] = self._send_firebase(message, "TradBOT Signal")
        
        return results
    
    def send_spike_alert(self, symbol: str, price: float, spike_percentage: float) -> Dict[str, bool]:
        """Envoie une alerte de spike"""
        results = {"sms": False, "whatsapp": False, "firebase": False}
        
        message = self._format_spike_alert_message(symbol, price, spike_percentage)
        
        if self.sms_enabled:
            results["sms"] = self._send_sms(message)
        
        if self.whatsapp_enabled:
            results["whatsapp"] = self._send_whatsapp(message)
        
        if self.firebase_enabled:
            results["firebase"] = self._send_firebase(message, "TradBOT Spike")
        
        return results
    
    def send_confirmed_signal(self, signal_data: Dict[str, Any]) -> Dict[str, bool]:
        """Envoie un signal confirmé de l'API de signaux"""
        results = {"sms": False, "whatsapp": False, "firebase": False}
        
        # Message spécial pour signaux confirmés
        message = self._format_confirmed_signal_message(signal_data)
        
        if self.sms_enabled:
            results["sms"] = self._send_sms(message)
        
        if self.whatsapp_enabled:
            results["whatsapp"] = self._send_whatsapp(message)
        
        if self.firebase_enabled:
            results["firebase"] = self._send_firebase(message, "TradBOT Signal Confirmé")
        
        return results
    
    def _format_trading_signal_message(self, signal_data: Dict[str, Any]) -> str:
        """Formate le message selon le format Vonage optimisé"""
        symbol = signal_data.get('symbol', 'N/A')
        action = signal_data.get('action', 'N/A')
        price = signal_data.get('price', 0)
        confidence = signal_data.get('confidence', 0)
        timeframe = signal_data.get('timeframe', 'M5')
        
        # Déterminer le type d'ordre et la direction
        if "Boom" in symbol and "Crash" not in symbol:
            direction = "BUY"
            order_type = "BUY LIMIT"
        elif "Crash" in symbol:
            direction = "SELL"
            order_type = "SELL LIMIT"
        elif action.upper() == "BUY":
            direction = "BUY"
            order_type = "BUY LIMIT"
        elif action.upper() == "SELL":
            direction = "SELL"
            order_type = "SELL LIMIT"
        else:
            direction = "NEUTRAL"
            order_type = "HOLD"
        
        # Calculer les niveaux de prix
        current_price = price
        if "JPY" in symbol or "Index" in symbol or "Boom" in symbol or "Crash" in symbol:
            pip_value = 0.01
        else:
            pip_value = 0.0001
        
        # TP = +15 pips, SL = -5 pips
        if direction == "BUY":
            entry_price = current_price
            tp_price = current_price + (15 * pip_value)
            sl_price = current_price - (5 * pip_value)
        elif direction == "SELL":
            entry_price = current_price
            tp_price = current_price - (15 * pip_value)
            sl_price = current_price + (5 * pip_value)
        else:
            entry_price = current_price
            tp_price = current_price
            sl_price = current_price
        
        # Format SMS optimisé (basé sur Vonage)
        message = f"""🎯 SPIKE {symbol}
⏰ {datetime.now().strftime('%H:%M')}
📊 {confidence:.0%} probabilité
🔄 {order_type}
💰 Entrée: {entry_price:.5f}
🎯 TP: {tp_price:.5f}
🛡️ SL: {sl_price:.5f}
📦 0.01 lots min"""
        
        return message
    
    def _format_confirmed_signal_message(self, signal_data: Dict[str, Any]) -> str:
        """Formate le message pour un signal confirmé de l'API"""
        symbol = signal_data.get('symbol', 'N/A')
        action = signal_data.get('action', 'N/A')
        price = signal_data.get('price', 0)
        confidence = signal_data.get('confidence', 0)
        source = signal_data.get('source', 'API')
        
        # Message spécial pour signaux confirmés
        message = f"""✅ SIGNAL CONFIRMÉ {symbol}
⏰ {datetime.now().strftime('%H:%M')}
📊 {confidence:.0%} probabilité
🔄 {action.upper()}
💰 Prix: {price:.5f}
🔗 Source: {source}
📦 0.01 lots min
⚠️ Signal confirmé par l'API"""
        
        return message
    
    def _format_spike_alert_message(self, symbol: str, price: float, spike_percentage: float) -> str:
        """Formate le message d'alerte de spike"""
        message = f"""🚨 SPIKE DÉTECTÉ {symbol}
⏰ {datetime.now().strftime('%H:%M')}
💰 Prix: {price:.5f}
📈 Variation: +{spike_percentage:.1f}%
⚠️ Attention: Mouvement important détecté"""
        
        return message
    
    def _send_sms(self, message: str) -> bool:
        """Envoie un SMS via Vonage"""
        try:
            url = "https://rest.nexmo.com/sms/json"
            payload = {
                "api_key": self.vonage_api_key,
                "api_secret": self.vonage_api_secret,
                "from": self.vonage_sms_from,
                "to": self.phone_number,
                "text": message
            }
            
            resp = requests.post(url, data=payload, timeout=15)
            
            if resp.status_code == 200:
                data = resp.json()
                if data.get('messages', [{}])[0].get('status') == '0':
                    logger.info(f"SMS envoyé avec succès à {self.phone_number}")
                    return True
                else:
                    logger.error(f"Erreur SMS: {data.get('messages', [{}])[0].get('error-text')}")
            else:
                logger.error(f"Erreur HTTP SMS: {resp.text}")
            
        except Exception as e:
            logger.error(f"Erreur lors de l'envoi SMS: {e}")
        
        return False
    
    def _send_whatsapp(self, message: str) -> bool:
        """Envoie un message WhatsApp via Vonage"""
        try:
            url = "https://api.nexmo.com/v1/messages"
            headers = {
                "Content-Type": "application/json",
                "Accept": "application/json"
            }
            
            payload = {
                "from": {"type": "whatsapp", "number": self.vonage_whatsapp_from},
                "to": {"type": "whatsapp", "number": self.whatsapp_number},
                "message": {
                    "content": {
                        "type": "text",
                        "text": message
                    }
                }
            }
            
            resp = requests.post(
                url,
                auth=(self.vonage_api_key, self.vonage_api_secret),
                json=payload,
                headers=headers,
                timeout=15
            )
            
            if resp.status_code == 202:
                logger.info(f"WhatsApp envoyé avec succès à {self.whatsapp_number}")
                return True
            else:
                logger.error(f"Erreur WhatsApp: {resp.text}")
        
        except Exception as e:
            logger.error(f"Erreur lors de l'envoi WhatsApp: {e}")
        
        return False
    
    def _send_firebase(self, message: str, title: str) -> bool:
        """Envoie via Firebase (fallback)"""
        try:
            # Utiliser le service SMS simplifié comme fallback
            from simple_sms_service import get_simple_sms_service
            sms_service = get_simple_sms_service()
            return sms_service.send_sms_notification(message, title)
        except Exception as e:
            logger.error(f"Erreur Firebase fallback: {e}")
            return False
    
    def test_all_services(self) -> Dict[str, bool]:
        """Test tous les services de notification"""
        results = {"sms": False, "whatsapp": False, "firebase": False}
        
        test_message = "🧪 Test TradBOT - Service unifié opérationnel!"
        
        if self.sms_enabled:
            results["sms"] = self._send_sms(test_message)
        
        if self.whatsapp_enabled:
            results["whatsapp"] = self._send_whatsapp(test_message)
        
        if self.firebase_enabled:
            results["firebase"] = self._send_firebase(test_message, "TradBOT Test")
        
        return results
    
    def get_status(self) -> Dict[str, Any]:
        """Retourne le statut des services"""
        return {
            "sms_enabled": self.sms_enabled,
            "whatsapp_enabled": self.whatsapp_enabled,
            "firebase_enabled": self.firebase_enabled,
            "phone_number": self.phone_number,
            "whatsapp_number": self.whatsapp_number,
            "vonage_configured": bool(self.vonage_api_key and self.vonage_api_secret)
        }

# Instance globale du service unifié
unified_service = UnifiedNotificationService()

def get_unified_service() -> UnifiedNotificationService:
    """Retourne l'instance du service unifié"""
    return unified_service

def send_trading_signal(symbol: str, action: str, price: float, confidence: float, 
                       timeframe: str = "M5", indicators: Dict = None) -> Dict[str, bool]:
    """Fonction utilitaire pour envoyer un signal de trading"""
    signal_data = {
        'symbol': symbol,
        'action': action,
        'price': price,
        'confidence': confidence,
        'timeframe': timeframe,
        'indicators': indicators or {},
        'timestamp': datetime.now().isoformat()
    }
    
    return unified_service.send_trading_signal(signal_data)

def send_confirmed_signal(symbol: str, action: str, price: float, confidence: float, 
                         source: str = "API") -> Dict[str, bool]:
    """Fonction utilitaire pour envoyer un signal confirmé"""
    signal_data = {
        'symbol': symbol,
        'action': action,
        'price': price,
        'confidence': confidence,
        'source': source,
        'timestamp': datetime.now().isoformat()
    }
    
    return unified_service.send_confirmed_signal(signal_data)

def send_spike_alert(symbol: str, price: float, spike_percentage: float) -> Dict[str, bool]:
    """Fonction utilitaire pour envoyer une alerte de spike"""
    return unified_service.send_spike_alert(symbol, price, spike_percentage)
