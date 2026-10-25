#!/usr/bin/env python3
"""
Script pour surveiller la communication entre le robot MT5 et le serveur AI
Affiche les requêtes en temps réel
"""

import urllib.request
import urllib.parse
import json
import time
import threading
from datetime import datetime

class RequestMonitor:
    def __init__(self):
        self.running = True
        self.request_count = 0
        
    def monitor_server_logs(self):
        """Surveille les logs du serveur local"""
        print("🔍 SURVEILLANCE DE LA COMMUNICATION ROBOT MT5 ↔ SERVEUR AI")
        print("=" * 70)
        print(f"📅 Démarrage: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        print("📋 Instructions:")
        print("1. Assurez-vous que le serveur AI est démarré:")
        print("   python ai_server.py --port 8000")
        print()
        print("2. Attachez le robot GoldRush_basic.mq5 à un graphique MT5")
        print("3. Activez 'UseAI_Agent' dans les paramètres du robot")
        print()
        print("4. Surveillez les logs ci-dessous:")
        print("   - Vous devriez voir: '📥 POST /decision'")
        print("   - Puis les détails de la requête et la réponse")
        print()
        print("🔄 Surveillance en cours... (Ctrl+C pour arrêter)")
        print("-" * 70)
        
        # Simuler la surveillance en testant périodiquement
        test_data = {
            "symbol": "EURUSD",
            "bid": 1.08567,
            "ask": 1.08573,
            "rsi": 55.5,
            "atr": 0.00123,
            "ema_fast": 1.08560,
            "ema_slow": 1.08550,
            "is_spike_mode": False,
            "dir_rule": 0,
            "supertrend_trend": 0,
            "volatility_regime": 0,
            "volatility_ratio": 1.0
        }
        
        while self.running:
            try:
                # Tester si le serveur répond
                json_data = json.dumps(test_data).encode('utf-8')
                req = urllib.request.Request(
                    "http://localhost:8000/decision",
                    data=json_data,
                    headers={
                        'Content-Type': 'application/json',
                        'User-Agent': 'MT5-TradBOT/3.0-Test'
                    }
                )
                
                with urllib.request.urlopen(req, timeout=2) as response:
                    if response.getcode() == 200:
                        self.request_count += 1
                        timestamp = datetime.now().strftime('%H:%M:%S')
                        print(f"✅ [{timestamp}] Test #{self.request_count}: Serveur répond correctement")
                
                time.sleep(10)  # Test toutes les 10 secondes
                
            except KeyboardInterrupt:
                print("\n🛑 Arrêt de la surveillance")
                break
            except Exception as e:
                timestamp = datetime.now().strftime('%H:%M:%S')
                print(f"❌ [{timestamp}] Erreur: {e}")
                time.sleep(5)

def check_robot_configuration():
    """Vérifie la configuration du robot"""
    print("🔍 VÉRIFICATION DE LA CONFIGURATION DU ROBOT")
    print("-" * 50)
    
    # Vérifier le fichier MQ5
    try:
        with open("GoldRush_basic.mq5", "r", encoding="utf-8") as f:
            content = f.read()
            
        if "#property webrequest" in content:
            print("✅ Permission WebRequest trouvée dans le robot")
            
            # Extraire les URLs autorisées
            lines = content.split('\n')
            for line in lines:
                if "#property webrequest" in line:
                    urls = line.split('"')[1] if '"' in line else "Non trouvé"
                    print(f"📍 URLs autorisées: {urls}")
                    break
        else:
            print("❌ Permission WebRequest MANQUANTE dans le robot")
            print("💡 Ajoutez: #property webrequest \"https://kolatradebot.onrender.com,http://localhost:8000\"")
            
    except FileNotFoundError:
        print("❌ Fichier GoldRush_basic.mq5 non trouvé")
    except Exception as e:
        print(f"❌ Erreur lecture fichier: {e}")
    
    print()

def main():
    print("🧪 TEST DE COMMUNICATION ROBOT MT5 - SERVEUR AI")
    print("=" * 70)
    
    # Vérifier la configuration
    check_robot_configuration()
    
    # Démarrer la surveillance
    monitor = RequestMonitor()
    
    try:
        monitor.monitor_server_logs()
    except KeyboardInterrupt:
        print("\n👋 Au revoir!")

if __name__ == "__main__":
    main()
