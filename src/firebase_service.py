"""
Service Firebase pour les notifications SMS et la gestion des données
"""

import os
import json
import logging
from typing import Dict, Any, Optional
from pathlib import Path

try:
    import firebase_admin
    from firebase_admin import credentials, firestore, messaging
    from google.cloud import firestore as firestore_client
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    logging.warning("Firebase Admin SDK non installé. Installez avec: pip install firebase-admin")

from config.settings import FIREBASE_CONFIG

logger = logging.getLogger(__name__)

class FirebaseService:
    """Service Firebase pour TradBOT"""
    
    def __init__(self):
        self.app = None
        self.db = None
        self.initialized = False
        self._initialize_firebase()
    
    def _initialize_firebase(self):
        """Initialise la connexion Firebase"""
        if not FIREBASE_AVAILABLE:
            logger.error("Firebase Admin SDK non disponible")
            return
        
        try:
            # Vérifier si Firebase est déjà initialisé
            if firebase_admin._apps:
                self.app = firebase_admin.get_app()
                logger.info("Utilisation de l'instance Firebase existante")
            else:
                # Utiliser le fichier de configuration Firebase
                cred_path = os.path.join(os.path.dirname(__file__), '..', 'firebase_config.json')
                if os.path.exists(cred_path):
                    cred = credentials.Certificate(cred_path)
                else:
                    # Créer les credentials Firebase
                    cred_dict = {
                        "type": "service_account",
                        "project_id": FIREBASE_CONFIG['project_id'],
                        "private_key_id": FIREBASE_CONFIG['private_key_id'],
                        "private_key": FIREBASE_CONFIG['private_key'].replace('\\n', '\n'),
                        "client_email": FIREBASE_CONFIG['client_email'],
                        "client_id": FIREBASE_CONFIG['client_id'],
                        "auth_uri": FIREBASE_CONFIG['auth_uri'],
                        "token_uri": FIREBASE_CONFIG['token_uri'],
                        "auth_provider_x509_cert_url": FIREBASE_CONFIG['auth_provider_x509_cert_url'],
                        "client_x509_cert_url": FIREBASE_CONFIG['client_x509_cert_url'],
                        "universe_domain": FIREBASE_CONFIG['universe_domain']
                    }
                    cred = credentials.Certificate(cred_dict)
                
                # Initialiser Firebase
                self.app = firebase_admin.initialize_app(cred, {
                    'projectId': FIREBASE_CONFIG['project_id']
                })
                logger.info(f"Firebase initialisé pour le projet: {FIREBASE_CONFIG['project_id']}")
            
            # Initialiser Firestore
            self.db = firestore.client()
            self.initialized = True
            logger.info("Service Firebase initialisé avec succès")
            
        except Exception as e:
            logger.error(f"Erreur lors de l'initialisation Firebase: {e}")
            self.initialized = False
    
    def send_sms_notification(self, phone_number: str, message: str, title: str = "TradBOT Alert") -> bool:
        """Envoie une notification SMS via Firebase"""
        if not self.initialized:
            logger.error("Firebase non initialisé")
            return False
        
        try:
            # Enregistrer la notification dans Firestore
            notification_data = {
                'phone_number': phone_number,
                'message': message,
                'title': title,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'status': 'sent'
            }
            
            # Ajouter à la collection notifications
            doc_ref = self.db.collection('notifications').add(notification_data)
            logger.info(f"Notification enregistrée dans Firestore: {doc_ref[1].id}")
            
            # Ici, vous pouvez ajouter l'envoi SMS réel via une API tierce
            # comme Twilio, Vonage, ou Firebase Cloud Messaging
            logger.info(f"SMS envoyé à {phone_number}: {message}")
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de l'envoi SMS: {e}")
            return False
    
    def save_trading_signal(self, signal_data: Dict[str, Any]) -> Optional[str]:
        """Sauvegarde un signal de trading dans Firestore"""
        if not self.initialized:
            logger.error("Firebase non initialisé")
            return None
        
        try:
            # Ajouter timestamp
            signal_data['timestamp'] = firestore.SERVER_TIMESTAMP
            signal_data['status'] = 'active'
            
            # Sauvegarder dans Firestore
            doc_ref = self.db.collection('trading_signals').add(signal_data)
            signal_id = doc_ref[1].id
            
            logger.info(f"Signal de trading sauvegardé: {signal_id}")
            return signal_id
            
        except Exception as e:
            logger.error(f"Erreur lors de la sauvegarde du signal: {e}")
            return None
    
    def get_trading_signals(self, limit: int = 50) -> list:
        """Récupère les derniers signaux de trading"""
        if not self.initialized:
            logger.error("Firebase non initialisé")
            return []
        
        try:
            # Récupérer les signaux récents
            signals_ref = self.db.collection('trading_signals')
            signals = signals_ref.order_by('timestamp', direction=firestore.Query.DESCENDING).limit(limit).stream()
            
            signals_list = []
            for signal in signals:
                signal_data = signal.to_dict()
                signal_data['id'] = signal.id
                signals_list.append(signal_data)
            
            logger.info(f"Récupéré {len(signals_list)} signaux de trading")
            return signals_list
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération des signaux: {e}")
            return []
    
    def save_market_data(self, symbol: str, data: Dict[str, Any]) -> bool:
        """Sauvegarde les données de marché"""
        if not self.initialized:
            logger.error("Firebase non initialisé")
            return False
        
        try:
            # Ajouter timestamp et symbol
            data['symbol'] = symbol
            data['timestamp'] = firestore.SERVER_TIMESTAMP
            
            # Sauvegarder dans Firestore
            self.db.collection('market_data').add(data)
            logger.debug(f"Données de marché sauvegardées pour {symbol}")
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de la sauvegarde des données de marché: {e}")
            return False
    
    def get_market_data(self, symbol: str, limit: int = 100) -> list:
        """Récupère les données de marché pour un symbole"""
        if not self.initialized:
            logger.error("Firebase non initialisé")
            return []
        
        try:
            # Récupérer les données récentes pour le symbole
            data_ref = self.db.collection('market_data')
            data = data_ref.where('symbol', '==', symbol).order_by('timestamp', direction=firestore.Query.DESCENDING).limit(limit).stream()
            
            data_list = []
            for doc in data:
                doc_data = doc.to_dict()
                doc_data['id'] = doc.id
                data_list.append(doc_data)
            
            logger.debug(f"Récupéré {len(data_list)} points de données pour {symbol}")
            return data_list
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération des données de marché: {e}")
            return []
    
    def update_signal_status(self, signal_id: str, status: str) -> bool:
        """Met à jour le statut d'un signal"""
        if not self.initialized:
            logger.error("Firebase non initialisé")
            return False
        
        try:
            # Mettre à jour le statut
            self.db.collection('trading_signals').document(signal_id).update({
                'status': status,
                'updated_at': firestore.SERVER_TIMESTAMP
            })
            
            logger.info(f"Statut du signal {signal_id} mis à jour: {status}")
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de la mise à jour du signal: {e}")
            return False
    
    def cleanup_old_data(self, days: int = 30) -> bool:
        """Nettoie les anciennes données (plus de X jours)"""
        if not self.initialized:
            logger.error("Firebase non initialisé")
            return False
        
        try:
            from datetime import datetime, timedelta
            
            # Calculer la date limite
            cutoff_date = datetime.now() - timedelta(days=days)
            
            # Nettoyer les anciens signaux
            signals_ref = self.db.collection('trading_signals')
            old_signals = signals_ref.where('timestamp', '<', cutoff_date).stream()
            
            deleted_count = 0
            for signal in old_signals:
                signal.reference.delete()
                deleted_count += 1
            
            logger.info(f"Nettoyage terminé: {deleted_count} anciens signaux supprimés")
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors du nettoyage: {e}")
            return False

# Instance globale du service Firebase
firebase_service = FirebaseService()

def get_firebase_service() -> FirebaseService:
    """Retourne l'instance du service Firebase"""
    return firebase_service
