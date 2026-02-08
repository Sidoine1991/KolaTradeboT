#!/usr/bin/env python3
"""
Script de diagnostic pour vérifier la communication avec le serveur AI
Utilise uniquement les modules standard de Python
"""

import urllib.request
import urllib.parse
import json
import time
import socket
from datetime import datetime

def test_connection_with_urllib(url, data, timeout=10):
    """Test de connexion avec urllib (module standard)"""
    try:
        print(f"📍 Test de connexion à: {url}")
        
        # Préparer les données
        json_data = json.dumps(data).encode('utf-8')
        
        # Créer la requête
        req = urllib.request.Request(
            url,
            data=json_data,
            headers={
                'Content-Type': 'application/json',
                'User-Agent': 'MT5-TradBOT/3.0',
                'Accept': 'application/json'
            }
        )
        
        start_time = time.time()
        with urllib.request.urlopen(req, timeout=timeout) as response:
            response_time = time.time() - start_time
            response_data = response.read().decode('utf-8')
            
            print(f"✅ Statut: {response.getcode()}")
            print(f"⏱️ Temps de réponse: {response_time:.3f}s")
            print(f"📦 Réponse: {response_data}")
            
            return True, response.getcode(), response_data
            
    except urllib.error.URLError as e:
        print(f"❌ Erreur de connexion: {e.reason}")
        return False, None, str(e)
    except Exception as e:
        print(f"❌ Erreur inattendue: {e}")
        return False, None, str(e)

def check_port_open(host, port):
    """Vérifie si un port est ouvert"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except:
        return False

def main():
    print("🧪 DIAGNOSTIC DE CONNEXION AU SERVEUR AI")
    print("=" * 60)
    print(f"📅 Date/Heure: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
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
    
    print("📊 Données de test envoyées:")
    print(json.dumps(test_data, indent=2))
    print()
    
    # Vérification des ports
    print("🔍 VÉRIFICATION DES PORTS")
    print("-" * 30)
    
    if check_port_open('localhost', 8000):
        print("✅ Port 8000 (localhost): OUVERT - Serveur local probablement actif")
    else:
        print("❌ Port 8000 (localhost): FERMÉ - Serveur local probablement inactif")
    
    print()
    
    # Test du serveur local
    print("🌐 TEST DU SERVEUR LOCAL")
    print("-" * 30)
    local_url = "http://localhost:8000/decision"
    success, status, response = test_connection_with_urllib(local_url, test_data, timeout=5)
    
    if success and status == 200:
        print("🎉 Le serveur local fonctionne correctement!")
    else:
        print("💡 Pour démarrer le serveur local:")
        print("   1. Activez l'environnement virtuel: .\\activate_venv.bat")
        print("   2. Démarrez le serveur: python ai_server.py --port 8000")
    
    print()
    
    # Test du serveur distant
    print("🌐 TEST DU SERVEUR DISTANT (Render)")
    print("-" * 30)
    remote_url = "https://kolatradebot.onrender.com/decision"
    success, status, response = test_connection_with_urllib(remote_url, test_data, timeout=15)
    
    if success and status == 200:
        print("🎉 Le serveur distant fonctionne correctement!")
    else:
        print("💡 Vérifiez votre connexion Internet")
        print("💡 Le serveur Render peut être en cours de démarrage (peut prendre 1-2 minutes)")
    
    print()
    print("🔍 DIAGNOSTIC COMPLET")
    print("-" * 30)
    
    # Vérifier si les URLs du robot sont correctes
    print("📋 URLs configurées dans le robot MT5:")
    print("   - Serveur local: http://localhost:8000/decision")
    print("   - Serveur distant: https://kolatradebot.onrender.com/decision")
    print()
    
    # Vérifier le format des données
    print("📋 Format des données envoyées par le robot:")
    print("   - Content-Type: application/json")
    print("   - User-Agent: MT5-TradBOT/3.0")
    print("   - Méthode: POST")
    print()
    
    print("💡 ÉTAPES SUIVANTES")
    print("-" * 30)
    print("1. Démarrez le serveur AI local:")
    print("   .\\activate_venv.bat")
    print("   python ai_server.py --port 8000")
    print()
    print("2. Vérifiez les logs du serveur AI pour voir les requêtes:")
    print("   - Vous devriez voir: '📥 POST /decision'")
    print("   - Puis: '📤 POST /decision - 200 - Temps: X.XXXs'")
    print()
    print("3. Attachez le robot GoldRush_basic.mq5 à un graphique")
    print("4. Surveillez les logs du robot MT5 et du serveur AI")
    print()
    print("🚨 Si vous ne voyez aucune communication:")
    print("   - Vérifiez que 'UseAI_Agent' est activé dans le robot")
    print("   - Vérifiez que le robot a les permissions WebRequest")
    print("   - Vérifiez les logs d'erreurs MT5 dans l'onglet 'Experts'")

if __name__ == "__main__":
    main()
