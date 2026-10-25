"""
Service de notification SMS pour TradBOT
Intégration Firebase avec signaux de trading
"""

import os
import logging
from typing import Dict, Any, Optional
from datetime import datetime
import json

# Import du service Firebase
try:
    from firebase_service import get_firebase_service
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    logging.warning("Service Firebase non disponible")

from config.settings import ALERT_CONFIG

logger = logging.getLogger(__name__)

class SMSNotificationService:
    """Service de notification SMS pour les signaux de trading"""
    
    def __init__(self):
        self.firebase_service = None
        self.phone_number = ALERT_CONFIG.get('phone_number', '+22996911346')
        self.enabled = ALERT_CONFIG.get('firebase_enabled', False)
        
        if FIREBASE_AVAILABLE and self.enabled:
            self.firebase_service = get_firebase_service()
            if self.firebase_service and self.firebase_service.initialized:
                logger.info(f"Service SMS initialisé pour le numéro: {self.phone_number}")
            else:
                logger.warning("Service Firebase non initialisé")
        else:
            logger.warning("Service SMS non disponible (Firebase non configuré)")
    
    def send_trading_signal_sms(self, signal_data: Dict[str, Any]) -> bool:
        """Envoie une notification SMS pour un signal de trading"""
        if not self.firebase_service or not self.firebase_service.initialized:
            logger.error("Service Firebase non disponible")
            return False
        
        try:
            # Formater le message SMS
            message = self._format_trading_signal_message(signal_data)
            title = f"TradBOT Signal - {signal_data.get('symbol', 'N/A')}"
            
            # Envoyer via Firebase
            success = self.firebase_service.send_sms_notification(
                phone_number=self.phone_number,
                message=message,
                title=title
            )
            
            if success:
                logger.info(f"SMS de signal envoyé à {self.phone_number}")
                # Sauvegarder le signal dans Firestore
                self.firebase_service.save_trading_signal(signal_data)
            else:
                logger.error("Échec de l'envoi du SMS")
            
            return success
            
        except Exception as e:
            logger.error(f"Erreur lors de l'envoi du SMS de signal: {e}")
            return False
    
    def send_spike_alert_sms(self, symbol: str, price: float, spike_percentage: float) -> bool:
        """Envoie une alerte SMS pour un spike de prix"""
        if not self.firebase_service or not self.firebase_service.initialized:
            return False
        
        try:
            message = f"🚨 SPIKE DÉTECTÉ! {symbol} à {price:.2f} (+{spike_percentage:.1f}%)"
            title = f"TradBOT Spike - {symbol}"
            
            success = self.firebase_service.send_sms_notification(
                phone_number=self.phone_number,
                message=message,
                title=title
            )
            
            if success:
                logger.info(f"Alerte spike envoyée pour {symbol}")
            
            return success
            
        except Exception as e:
            logger.error(f"Erreur lors de l'envoi de l'alerte spike: {e}")
            return False
    
    def send_position_update_sms(self, position_data: Dict[str, Any]) -> bool:
        """Envoie une notification SMS pour une mise à jour de position"""
        if not self.firebase_service or not self.firebase_service.initialized:
            return False
        
        try:
            message = self._format_position_message(position_data)
            title = f"TradBOT Position - {position_data.get('symbol', 'N/A')}"
            
            success = self.firebase_service.send_sms_notification(
                phone_number=self.phone_number,
                message=message,
                title=title
            )
            
            return success
            
        except Exception as e:
            logger.error(f"Erreur lors de l'envoi de la notification de position: {e}")
            return False
    
    def send_daily_summary_sms(self, summary_data: Dict[str, Any]) -> bool:
        """Envoie un résumé quotidien par SMS"""
        if not self.firebase_service or not self.firebase_service.initialized:
            return False
        
        try:
            message = self._format_daily_summary_message(summary_data)
            title = "TradBOT Résumé Quotidien"
            
            success = self.firebase_service.send_sms_notification(
                phone_number=self.phone_number,
                message=message,
                title=title
            )
            
            return success
            
        except Exception as e:
            logger.error(f"Erreur lors de l'envoi du résumé quotidien: {e}")
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
    
    def _format_position_message(self, position_data: Dict[str, Any]) -> str:
        """Formate le message SMS pour une position"""
        symbol = position_data.get('symbol', 'N/A')
        action = position_data.get('action', 'N/A')
        price = position_data.get('price', 0)
        pnl = position_data.get('pnl', 0)
        status = position_data.get('status', 'N/A')
        
        emoji = "✅" if status == "CLOSED" else "⏳"
        
        message = f"{emoji} POSITION {status}\n"
        message += f"📊 {symbol} {action.upper()}\n"
        message += f"💰 Prix: {price:.4f}\n"
        message += f"💵 P&L: {pnl:.2f}\n"
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
    
    def test_sms_notification(self) -> bool:
        """Test l'envoi d'une notification SMS"""
        if not self.firebase_service or not self.firebase_service.initialized:
            logger.error("Service Firebase non disponible pour le test")
            return False
        
        try:
            test_message = "🔥 Test TradBOT - Configuration SMS réussie!"
            title = "TradBOT Test"
            
            success = self.firebase_service.send_sms_notification(
                phone_number=self.phone_number,
                message=test_message,
                title=title
            )
            
            if success:
                logger.info(f"Test SMS envoyé avec succès à {self.phone_number}")
            else:
                logger.error("Échec du test SMS")
            
            return success
            
        except Exception as e:
            logger.error(f"Erreur lors du test SMS: {e}")
            return False

# Instance globale du service SMS
sms_service = SMSNotificationService()

def get_sms_service() -> SMSNotificationService:
    """Retourne l'instance du service SMS"""
    return sms_service

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
    
    return sms_service.send_trading_signal_sms(signal_data)

def send_spike_alert(symbol: str, price: float, spike_percentage: float) -> bool:
    """Fonction utilitaire pour envoyer une alerte de spike"""
    return sms_service.send_spike_alert_sms(symbol, price, spike_percentage)
