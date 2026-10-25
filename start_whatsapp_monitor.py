#!/usr/bin/env python3
"""
Script de lancement du surveillant WhatsApp des signaux
Usage: python start_whatsapp_monitor.py
"""

import sys
import os
import time
import signal
from datetime import datetime

# Ajouter le répertoire racine au PYTHONPATH
project_root = os.path.abspath(os.path.dirname(__file__))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

try:
    from backend.signal_whatsapp_monitor import SignalWhatsAppMonitor
    print("✅ Module SignalWhatsAppMonitor importé avec succès")
except ImportError as e:
    print(f"❌ Erreur d'import: {e}")
    sys.exit(1)

class WhatsAppMonitorManager:
    """Gestionnaire du surveillant WhatsApp"""
    
    def __init__(self):
        self.monitor = None
        self.running = False
    
    def start_monitor(self):
        """Démarrer le surveillant WhatsApp"""
        print("📱 Démarrage du surveillant WhatsApp des signaux")
        print("=" * 60)
        
        # Configuration du surveillant
        self.monitor = SignalWhatsAppMonitor(
            signal_api_url="http://localhost:8001",
            check_interval=10,  # Vérifier toutes les 10 secondes
            max_sl_pips=10.0,   # SL maximum 10 pips
            min_tp_pips=30.0,   # TP minimum 30 pips
            enabled=True
        )
        
        # Démarrer le surveillant
        if self.monitor.start():
            self.running = True
            print("✅ Surveillant WhatsApp démarré avec succès")
            print("📊 Configuration:")
            print(f"   - API Signaux: {self.monitor.signal_api_url}")
            print(f"   - Intervalle de vérification: {self.monitor.check_interval}s")
            print(f"   - SL maximum: {self.monitor.max_sl_pips} pips")
            print(f"   - TP minimum: {self.monitor.min_tp_pips} pips")
            print("\n🔄 Surveillance active...")
            print("📱 Les signaux respectant les critères seront envoyés par WhatsApp")
            print("🛑 Appuyez sur Ctrl+C pour arrêter")
            return True
        else:
            print("❌ Impossible de démarrer le surveillant")
            return False
    
    def stop_monitor(self):
        """Arrêter le surveillant WhatsApp"""
        if self.monitor:
            self.monitor.stop()
            self.running = False
            print("\n🛑 Surveillant WhatsApp arrêté")
    
    def show_status(self):
        """Afficher le statut du surveillant"""
        if self.monitor:
            status = self.monitor.get_status()
            print(f"\n📊 Statut du surveillant:")
            print(f"   - En cours d'exécution: {'✅' if status['running'] else '❌'}")
            print(f"   - Activé: {'✅' if status['enabled'] else '❌'}")
            print(f"   - WhatsApp disponible: {'✅' if status['whatsapp_available'] else '❌'}")
            print(f"   - Signaux traités: {status['processed_signals_count']}")
            print(f"   - SL max: {status['max_sl_pips']} pips")
            print(f"   - TP min: {status['min_tp_pips']} pips")
            if status['last_check_time']:
                print(f"   - Dernière vérification: {status['last_check_time']}")
    
    def run(self):
        """Boucle principale"""
        try:
            if not self.start_monitor():
                return
            
            # Boucle de surveillance
            while self.running:
                time.sleep(30)  # Afficher le statut toutes les 30 secondes
                self.show_status()
                
        except KeyboardInterrupt:
            print("\n🛑 Arrêt demandé par l'utilisateur")
            self.stop_monitor()
        except Exception as e:
            print(f"❌ Erreur: {e}")
            self.stop_monitor()

def signal_handler(signum, frame):
    """Gestionnaire de signaux pour arrêt propre"""
    print("\n🛑 Signal d'arrêt reçu")
    sys.exit(0)

def main():
    """Fonction principale"""
    print("📱 TradBOT - Surveillant WhatsApp des Signaux")
    print("=" * 60)
    print(f"⏰ Démarrage: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Configuration du gestionnaire de signaux
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Vérifier que l'API de signaux est disponible
    try:
        import requests
        response = requests.get("http://localhost:8001/health", timeout=5)
        if response.status_code == 200:
            print("✅ API de signaux disponible")
            data = response.json()
            print(f"📈 Signaux disponibles: {data.get('count', 0)}")
        else:
            print("⚠️ API de signaux non disponible - certains signaux pourraient être manqués")
    except Exception as e:
        print(f"⚠️ Impossible de vérifier l'API de signaux: {e}")
    
    # Vérifier WhatsApp
    try:
        from frontend.whatsapp_notify import send_whatsapp_message_unified
        print("✅ WhatsApp disponible")
    except Exception as e:
        print(f"⚠️ WhatsApp non disponible: {e}")
        print("💡 Assurez-vous que WhatsApp est configuré")
    
    # Créer et lancer le gestionnaire
    manager = WhatsAppMonitorManager()
    manager.run()

if __name__ == "__main__":
    main()
