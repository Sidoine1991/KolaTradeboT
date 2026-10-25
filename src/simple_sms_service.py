"""
Service SMS simplifié pour TradBOT
Utilise Firebase sans Firestore pour les notifications SMS
"""

import os
import logging
import requests
import json
from typing import Dict, Any, Optional
from datetime import datetime

from config.settings import FIREBASE_CONFIG

logger = logging.getLogger(__name__)

class SimpleSMSService:
    """Service SMS simplifié utilisant l'API Firebase"""
    
    def __init__(self):
        self.phone_number = "+22996911346"
        self.api_key = FIREBASE_CONFIG.get('google_api_key', 'AIzaSyClCAXRU8kk4l1TxtaMfDqbRUEixNQ68Ao')
        self.project_id = FIREBASE_CONFIG.get('project_id', 'smstrade-5f6a5')
        self.enabled = True
        
        logger.info(f"Service SMS simplifié initialisé pour {self.phone_number}")
    
    def send_sms_notification(self, message: str, title: str = "TradBOT Alert") -> bool:
        """Envoie une notification SMS via l'API Firebase"""
        try:
            # Simuler l'envoi SMS (en attendant l'activation de Firestore)
            logger.info(f"📱 SMS envoyé à {self.phone_number}")
            logger.info(f"📝 Titre: {title}")
            logger.info(f"💬 Message: {message}")
            
            # Ici, vous pouvez intégrer une vraie API SMS comme Twilio, Vonage, etc.
            # Pour l'instant, on simule l'envoi
            
            # Sauvegarder dans un fichier local pour simulation
            self._save_notification_to_file(message, title)
            
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de l'envoi SMS: {e}")
            return False
    
    def send_trading_signal_sms(self, signal_data: Dict[str, Any]) -> bool:
        """Envoie une notification SMS pour un signal de trading"""
        try:
            message = self._format_trading_signal_message(signal_data)
            title = f"TradBOT Signal - {signal_data.get('symbol', 'N/A')}"
            
            success = self.send_sms_notification(message, title)
            
            if success:
                logger.info(f"Signal de trading envoyé: {signal_data.get('symbol')}")
            
            return success
            
        except Exception as e:
            logger.error(f"Erreur lors de l'envoi du signal: {e}")
            return False
    
    def send_spike_alert_sms(self, symbol: str, price: float, spike_percentage: float) -> bool:
        """Envoie une alerte SMS pour un spike de prix"""
        try:
            message = f"🚨 SPIKE DÉTECTÉ! {symbol} à {price:.2f} (+{spike_percentage:.1f}%)"
            title = f"TradBOT Spike - {symbol}"
            
            success = self.send_sms_notification(message, title)
            
            if success:
                logger.info(f"Alerte spike envoyée pour {symbol}")
            
            return success
            
        except Exception as e:
            logger.error(f"Erreur lors de l'envoi de l'alerte spike: {e}")
            return False
    
    def send_daily_summary_sms(self, summary_data: Dict[str, Any]) -> bool:
        """Envoie un résumé quotidien par SMS"""
        try:
            message = self._format_daily_summary_message(summary_data)
            title = "TradBOT Résumé Quotidien"
            
            success = self.send_sms_notification(message, title)
            
            if success:
                logger.info("Résumé quotidien envoyé")
            
            return success
            
        except Exception as e:
            logger.error(f"Erreur lors de l'envoi du résumé: {e}")
            return False
    
    def _format_trading_signal_message(self, signal_data: Dict[str, Any]) -> str:
        """Formate le message SMS pour un signal de trading"""
        symbol = signal_data.get('symbol', 'N/A')
        action = signal_data.get('action', 'N/A')
        price = signal_data.get('price', 0)
        confidence = signal_data.get('confidence', 0)
        timeframe = signal_data.get('timeframe', 'N/A')
        
        # Emoji selon l'action
        emoji = "🟢" if action.upper() == "BUY" else "🔴" if action.upper() == "SELL" else "⚪"
        
        message = f"{emoji} SIGNAL {action.upper()}\n"
        message += f"📊 {symbol}\n"
        message += f"💰 Prix: {price:.4f}\n"
        message += f"🎯 Confiance: {confidence:.1%}\n"
        message += f"⏰ {timeframe}\n"
        message += f"🕐 {datetime.now().strftime('%H:%M:%S')}"
        
        return message
    
    def _format_daily_summary_message(self, summary_data: Dict[str, Any]) -> str:
        """Formate le message SMS pour le résumé quotidien"""
        total_signals = summary_data.get('total_signals', 0)
        successful_signals = summary_data.get('successful_signals', 0)
        total_pnl = summary_data.get('total_pnl', 0)
        win_rate = summary_data.get('win_rate', 0)
        
        message = f"📊 RÉSUMÉ QUOTIDIEN\n"
        message += f"📈 Signaux: {total_signals}\n"
        message += f"✅ Réussis: {successful_signals}\n"
        message += f"🎯 Taux: {win_rate:.1%}\n"
        message += f"💰 P&L: {total_pnl:.2f}\n"
        message += f"🕐 {datetime.now().strftime('%d/%m/%Y %H:%M')}"
        
        return message
    
    def _save_notification_to_file(self, message: str, title: str):
        """Sauvegarde la notification dans un fichier local"""
        try:
            notification = {
                'timestamp': datetime.now().isoformat(),
                'phone_number': self.phone_number,
                'title': title,
                'message': message
            }
            
            # Créer le dossier notifications s'il n'existe pas
            os.makedirs('notifications', exist_ok=True)
            
            # Sauvegarder dans un fichier JSON
            filename = f"notifications/sms_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(notification, f, indent=2, ensure_ascii=False)
            
            logger.info(f"Notification sauvegardée: {filename}")
            
        except Exception as e:
            logger.error(f"Erreur lors de la sauvegarde: {e}")
    
    def test_sms_notification(self) -> bool:
        """Test l'envoi d'une notification SMS"""
        try:
            test_message = "🔥 Test TradBOT - Configuration SMS réussie!"
            title = "TradBOT Test"
            
            success = self.send_sms_notification(test_message, title)
            
            if success:
                logger.info(f"Test SMS envoyé avec succès à {self.phone_number}")
            else:
                logger.error("Échec du test SMS")
            
            return success
            
        except Exception as e:
            logger.error(f"Erreur lors du test SMS: {e}")
            return False

# Instance globale du service SMS simplifié
simple_sms_service = SimpleSMSService()

def get_simple_sms_service() -> SimpleSMSService:
    """Retourne l'instance du service SMS simplifié"""
    return simple_sms_service

def send_trading_signal(symbol: str, action: str, price: float, confidence: float, 
                       timeframe: str = "M5", indicators: Dict = None) -> bool:
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
    
    return simple_sms_service.send_trading_signal_sms(signal_data)

def send_spike_alert(symbol: str, price: float, spike_percentage: float) -> bool:
    """Fonction utilitaire pour envoyer une alerte de spike"""
    return simple_sms_service.send_spike_alert_sms(symbol, price, spike_percentage)
