#!/usr/bin/env python3
"""
Module de surveillance des signaux API et envoi automatique par WhatsApp
"""

import json
import time
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Set
import logging
import os
import sys

# Ajouter le répertoire racine au PYTHONPATH
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

try:
    from frontend.whatsapp_notify import send_whatsapp_message_unified
    WHATSAPP_AVAILABLE = True
except ImportError as e:
    print(f"⚠️ WhatsApp non disponible: {e}")
    WHATSAPP_AVAILABLE = False

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SignalWhatsAppMonitor:
    """Surveillant des signaux API avec envoi automatique WhatsApp"""
    
    def __init__(self, 
                 signal_api_url: str = "http://localhost:8001",
                 check_interval: int = 10,
                 max_sl_pips: float = 10.0,  # SL maximum 10 pips
                 min_tp_pips: float = 30.0,  # TP minimum 30 pips
                 enabled: bool = True):
        
        self.signal_api_url = signal_api_url
        self.check_interval = check_interval
        self.max_sl_pips = max_sl_pips
        self.min_tp_pips = min_tp_pips
        self.enabled = enabled
        
        # État du surveillant
        self.running = False
        self.processed_signals = set()  # IDs des signaux déjà traités
        self.last_check_time = None
        
        logger.info(f"📱 SignalWhatsAppMonitor initialisé - API: {signal_api_url}")
        logger.info(f"📊 Configuration: SL max={max_sl_pips}pips, TP min={min_tp_pips}pips")
    
    def start(self):
        """Démarrer le surveillant"""
        if not WHATSAPP_AVAILABLE:
            logger.error("❌ WhatsApp non disponible - impossible de démarrer le surveillant")
            return False
        
        if not self.enabled:
            logger.warning("⚠️ Surveillant désactivé")
            return False
        
        self.running = True
        logger.info("🚀 Surveillant WhatsApp démarré")
        return True
    
    def stop(self):
        """Arrêter le surveillant"""
        self.running = False
        logger.info("🛑 Surveillant WhatsApp arrêté")
    
    def _get_signal_id(self, signal: Dict) -> str:
        """Générer un ID unique pour le signal"""
        return f"{signal['symbol']}_{signal['side']}_{signal['ts']}_{signal['price']}"
    
    def _calculate_pip_size(self, symbol: str) -> float:
        """Calculer la taille d'un pip pour le symbole"""
        if "JPY" in symbol:
            return 0.01
        elif "Index" in symbol or "Boom" in symbol or "Crash" in symbol:
            return 0.1  # Pour les indices
        else:
            return 0.0001  # Pour les paires de devises
    
    def _validate_signal_risk(self, signal: Dict) -> tuple[bool, float, float]:
        """Valider les critères de risque d'un signal"""
        try:
            symbol = signal['symbol']
            price = float(signal['price'])
            sl = float(signal['sl'])
            tp = float(signal['tp'])
            
            # Calculer la taille d'un pip
            pip_size = self._calculate_pip_size(symbol)
            
            # Calculer les pips
            sl_pips = abs(price - sl) / pip_size
            tp_pips = abs(tp - price) / pip_size
            
            # Vérifier les critères
            risk_ok = sl_pips <= self.max_sl_pips
            reward_ok = tp_pips >= self.min_tp_pips
            
            return risk_ok and reward_ok, sl_pips, tp_pips
            
        except Exception as e:
            logger.error(f"❌ Erreur validation risque: {e}")
            return False, 0, 0
    
    def _format_whatsapp_message(self, signal: Dict, sl_pips: float, tp_pips: float) -> str:
        """Formater le message WhatsApp"""
        try:
            symbol = signal['symbol']
            side = signal['side']
            price = float(signal['price'])
            sl = float(signal['sl'])
            tp = float(signal['tp'])
            confidence = float(signal['confidence'])
            source = signal['source']
            valid_to = signal['valid_to']
            
            # Emoji selon la direction
            emoji = "🟢" if side == "BUY" else "🔴"
            
            # Formater le message
            message = f"""{emoji} SIGNAL {source.upper()}
📊 {symbol}
🎯 {side} @ {price:.3f}
🛡️ SL: {sl:.3f} ({sl_pips:.1f} pips)
🎯 TP: {tp:.3f} ({tp_pips:.1f} pips)
⚡ Confiance: {confidence*100:.0f}%
⏰ Valide jusqu'à: {valid_to}
📈 Ratio R/R: 1:{tp_pips/sl_pips:.1f}"""
            
            return message
            
        except Exception as e:
            logger.error(f"❌ Erreur formatage message: {e}")
            return f"Signal {signal.get('symbol', 'N/A')} {signal.get('side', 'N/A')}"
    
    def _process_signal(self, signal: Dict) -> bool:
        """Traiter un signal et l'envoyer par WhatsApp"""
        try:
            # Vérifier si déjà traité
            signal_id = self._get_signal_id(signal)
            if signal_id in self.processed_signals:
                return False
            
            # Valider les critères de risque
            is_valid, sl_pips, tp_pips = self._validate_signal_risk(signal)
            
            if not is_valid:
                logger.debug(f"⚠️ Signal rejeté - Critères non respectés: SL={sl_pips:.1f}pips, TP={tp_pips:.1f}pips")
                return False
            
            # Formater et envoyer le message
            message = self._format_whatsapp_message(signal, sl_pips, tp_pips)
            
            # Envoyer par WhatsApp
            success = send_whatsapp_message_unified(message)
            
            if success:
                self.processed_signals.add(signal_id)
                logger.info(f"📱 Signal WhatsApp envoyé: {signal['symbol']} {signal['side']}")
                return True
            else:
                logger.error(f"❌ Échec envoi WhatsApp: {signal['symbol']}")
                return False
                
        except Exception as e:
            logger.error(f"❌ Erreur traitement signal: {e}")
            return False
    
    def _fetch_signals(self) -> List[Dict]:
        """Récupérer les signaux depuis l'API"""
        try:
            response = requests.get(f"{self.signal_api_url}/signals", timeout=5)
            if response.status_code == 200:
                data = response.json()
                return data.get('signals', [])
            else:
                logger.warning(f"⚠️ API signaux indisponible: {response.status_code}")
                return []
        except Exception as e:
            logger.error(f"❌ Erreur récupération signaux: {e}")
            return []
    
    def check_and_send_signals(self):
        """Vérifier et envoyer les nouveaux signaux"""
        try:
            # Récupérer les signaux
            signals = self._fetch_signals()
            
            if not signals:
                return
            
            # Traiter chaque signal
            sent_count = 0
            for signal in signals:
                if self._process_signal(signal):
                    sent_count += 1
            
            if sent_count > 0:
                logger.info(f"📱 {sent_count} signal(s) WhatsApp envoyé(s)")
            
            self.last_check_time = datetime.now()
            
        except Exception as e:
            logger.error(f"❌ Erreur vérification signaux: {e}")
    
    def run_continuous(self):
        """Boucle continue de surveillance"""
        logger.info("👁️ Surveillance continue des signaux démarrée")
        
        while self.running:
            try:
                self.check_and_send_signals()
                time.sleep(self.check_interval)
            except KeyboardInterrupt:
                logger.info("🛑 Arrêt demandé par l'utilisateur")
                break
            except Exception as e:
                logger.error(f"❌ Erreur dans la surveillance: {e}")
                time.sleep(10)  # Attendre avant de réessayer
    
    def get_status(self) -> Dict:
        """Obtenir le statut du surveillant"""
        return {
            'running': self.running,
            'enabled': self.enabled,
            'processed_signals_count': len(self.processed_signals),
            'last_check_time': self.last_check_time.isoformat() if self.last_check_time else None,
            'whatsapp_available': WHATSAPP_AVAILABLE,
            'max_sl_pips': self.max_sl_pips,
            'min_tp_pips': self.min_tp_pips
        }


def main():
    """Fonction principale pour tester le surveillant"""
    print("📱 Test du surveillant WhatsApp des signaux")
    print("=" * 50)
    
    # Créer le surveillant
    monitor = SignalWhatsAppMonitor(
        signal_api_url="http://localhost:8001",
        check_interval=15,  # Vérifier toutes les 15 secondes
        max_sl_pips=10.0,   # SL max 10 pips
        min_tp_pips=30.0,   # TP min 30 pips
        enabled=True
    )
    
    try:
        # Démarrer le surveillant
        if monitor.start():
            print("✅ Surveillant démarré avec succès")
            print("📊 Statut:", monitor.get_status())
            
            # Vérifier une fois
            print("\n🔍 Vérification des signaux...")
            monitor.check_and_send_signals()
            
            print("\n✅ Test terminé")
        else:
            print("❌ Impossible de démarrer le surveillant")
    
    except Exception as e:
        print(f"❌ Erreur: {e}")
        monitor.stop()


if __name__ == "__main__":
    main()
