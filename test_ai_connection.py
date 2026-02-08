#!/usr/bin/env python3
"""
Script de test pour vérifier la communication avec le serveur AI
Simule les requêtes envoyées par le robot MT5
"""

import requests
import json
import time
from datetime import datetime

def test_ai_server_connection():
    """Test la connexion au serveur AI local et distant"""
    
    # URLs des serveurs
    local_url = "http://localhost:8000/decision"
    remote_url = "https://kolatradebot.onrender.com/decision"
    
    # Données de test (simule ce que le robot MT5 envoie)
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
    
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "MT5-TradBOT/3.0",
        "Accept": "application/json",
        "Connection": "keep-alive"
    }
    
    print("🧪 TEST DE CONNEXION AU SERVEUR AI")
    print("=" * 50)
    print(f"📅 Date/Heure: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"📊 Données de test: {json.dumps(test_data, indent=2)}")
    print()
    
    # Test du serveur local
    print("🌐 TEST DU SERVEUR LOCAL")
    print("-" * 30)
    try:
        print(f"📍 URL: {local_url}")
        start_time = time.time()
        response = requests.post(local_url, json=test_data, headers=headers, timeout=5)
        response_time = time.time() - start_time
        
        print(f"✅ Statut: {response.status_code}")
        print(f"⏱️ Temps de réponse: {response_time:.3f}s")
        
        if response.status_code == 200:
            result = response.json()
            print(f"📦 Réponse: {json.dumps(result, indent=2)}")
        else:
            print(f"❌ Erreur: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("❌ Erreur de connexion - Serveur local inaccessible")
        print("💡 Assurez-vous que le serveur local est démarré:")
        print("   python ai_server.py --port 8000")
    except requests.exceptions.Timeout:
        print("❌ Timeout - Le serveur local ne répond pas")
    except Exception as e:
        print(f"❌ Erreur inattendue: {e}")
    
    print()
    
    # Test du serveur distant
    print("🌐 TEST DU SERVEUR DISTANT (Render)")
    print("-" * 30)
    try:
        print(f"📍 URL: {remote_url}")
        start_time = time.time()
        response = requests.post(remote_url, json=test_data, headers=headers, timeout=15)
        response_time = time.time() - start_time
        
        print(f"✅ Statut: {response.status_code}")
        print(f"⏱️ Temps de réponse: {response_time:.3f}s")
        
        if response.status_code == 200:
            result = response.json()
            print(f"📦 Réponse: {json.dumps(result, indent=2)}")
        else:
            print(f"❌ Erreur: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("❌ Erreur de connexion - Serveur distant inaccessible")
        print("💡 Vérifiez votre connexion Internet")
    except requests.exceptions.Timeout:
        print("❌ Timeout - Le serveur distant ne répond pas")
    except Exception as e:
        print(f"❌ Erreur inattendue: {e}")
    
    print()
    print("🔍 DIAGNOSTIC")
    print("-" * 30)
    
    # Vérifier si le port 8000 est utilisé
    import socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result_port = sock.connect_ex(('localhost', 8000))
    sock.close()
    
    if result_port == 0:
        print("✅ Port 8000: Ouvert (serveur local probablement actif)")
    else:
        print("❌ Port 8000: Fermé (serveur local probablement inactif)")
    
    print()
    print("💡 RECOMMANDATIONS")
    print("-" * 30)
    print("1. Si le serveur local ne fonctionne pas:")
    print("   - Activez l'environnement virtuel: .\\activate_venv.bat")
    print("   - Démarrez le serveur: python ai_server.py --port 8000")
    print()
    print("2. Si le serveur distant ne fonctionne pas:")
    print("   - Vérifiez votre connexion Internet")
    print("   - Le serveur Render peut être en cours de démarrage")
    print()
    print("3. Vérifiez les logs du serveur pour voir les requêtes entrantes")

if __name__ == "__main__":
    test_ai_server_connection()
