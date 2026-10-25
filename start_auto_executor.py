#!/usr/bin/env python3
"""
Script de lancement de l'exécuteur automatique de signaux
Usage: python start_auto_executor.py
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
    from backend.auto_signal_executor import AutoSignalExecutor
    print("✅ Module AutoSignalExecutor importé avec succès")
except ImportError as e:
    print(f"❌ Erreur d'import: {e}")
    sys.exit(1)

class AutoExecutorManager:
    """Gestionnaire de l'exécuteur automatique"""
    
    def __init__(self):
        self.executor = None
        self.running = False
    
    def start_executor(self):
        """Démarrer l'exécuteur automatique"""
        print("🚀 Démarrage de l'exécuteur automatique de signaux")
        print("=" * 60)
        
        # Configuration de l'exécuteur
        self.executor = AutoSignalExecutor(
            signal_api_url="http://localhost:8001",
            check_interval=5,              # Vérifier toutes les 5 secondes
            max_risk_per_trade=0.20,       # 20% sur 10$ ≈ 2$ si pas d'info broker
            min_confidence=0.80,           # 80% de confiance minimum
            max_daily_trades=3,            # Max 3 trades par jour
            enabled=True,
            account_balance=10.0,          # Solde cible
            max_abs_risk_usd=2.0,          # Perte max absolue par trade
            cooldown_seconds=180,          # 3 minutes de cooldown
            spike_tp_rr=1.0                # TP à 1R (spike rapide)
        )
        
        # Démarrer l'exécuteur
        if self.executor.start():
            self.running = True
            print("✅ Exécuteur automatique démarré avec succès")
            print("📊 Configuration:")
            print(f"   - API Signaux: {self.executor.signal_api_url}")
            print(f"   - Intervalle de vérification: {self.executor.check_interval}s")
            print(f"   - Risque max par trade: {self.executor.max_risk_per_trade*100}%")
            print(f"   - Confiance minimum: {self.executor.min_confidence*100}%")
            print(f"   - Trades max par jour: {self.executor.max_daily_trades}")
            print("\n🔄 Surveillance active...")
            print("📱 Les signaux seront exécutés automatiquement sur MT5")
            print("🛑 Appuyez sur Ctrl+C pour arrêter")
            return True
        else:
            print("❌ Impossible de démarrer l'exécuteur")
            return False
    
    def stop_executor(self):
        """Arrêter l'exécuteur automatique"""
        if self.executor:
            self.executor.stop()
            self.running = False
            print("\n🛑 Exécuteur automatique arrêté")
    
    def show_status(self):
        """Afficher le statut de l'exécuteur"""
        if self.executor:
            status = self.executor.get_status()
            print(f"\n📊 Statut de l'exécuteur:")
            print(f"   - En cours d'exécution: {'✅' if status['running'] else '❌'}")
            print(f"   - Activé: {'✅' if status['enabled'] else '❌'}")
            print(f"   - MT5 connecté: {'✅' if status['mt5_connected'] else '❌'}")
            print(f"   - Trades aujourd'hui: {status['daily_trades']}/{status['max_daily_trades']}")
            print(f"   - Signaux exécutés: {status['executed_signals_count']}")
            print(f"   - Dernière réinitialisation: {status['last_reset_date']}")
    
    def run(self):
        """Boucle principale"""
        try:
            if not self.start_executor():
                return
            
            # Boucle de surveillance
            while self.running:
                time.sleep(30)  # Afficher le statut toutes les 30 secondes
                self.show_status()
                
        except KeyboardInterrupt:
            print("\n🛑 Arrêt demandé par l'utilisateur")
            self.stop_executor()
        except Exception as e:
            print(f"❌ Erreur: {e}")
            self.stop_executor()

def signal_handler(signum, frame):
    """Gestionnaire de signaux pour arrêt propre"""
    print("\n🛑 Signal d'arrêt reçu")
    sys.exit(0)

def main():
    """Fonction principale"""
    print("🤖 TradBOT - Exécuteur Automatique de Signaux")
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
        else:
            print("⚠️ API de signaux non disponible - certains signaux pourraient être manqués")
    except Exception as e:
        print(f"⚠️ Impossible de vérifier l'API de signaux: {e}")
    
    # Créer et lancer le gestionnaire
    manager = AutoExecutorManager()
    manager.run()

if __name__ == "__main__":
    main()
