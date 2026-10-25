#!/usr/bin/env python3
"""
Script de test simple pour vérifier que le serveur AI répond correctement
"""
import requests
import json
import sys

def test_server():
    base_url = "http://127.0.0.1:8000"
    
    print("=" * 60)
    print("TEST DU SERVEUR AI TRADBOT")
    print("=" * 60)
    
    # Test 1: Health check
    print("\n1. Test de santé du serveur (/health)...")
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        if response.status_code == 200:
            print("   ✅ Serveur accessible!")
            print(f"   Réponse: {response.json()}")
        else:
            print(f"   ⚠️ Code HTTP: {response.status_code}")
    except requests.exceptions.ConnectionError:
        print("   ❌ ERREUR: Le serveur n'est pas accessible!")
        print("   SOLUTION: Démarrez le serveur avec: python launch_server.py")
        return False
    except Exception as e:
        print(f"   ❌ Erreur: {e}")
        return False
    
    # Test 2: Endpoint /decision
    print("\n2. Test de l'endpoint /decision...")
    try:
        test_payload = {
            "symbol": "EURUSD",
            "rsi": 50.0,
            "atr": 0.001,
            "ema_fast_h1": 1.1000,
            "ema_slow_h1": 1.1000,
            "ema_fast_m1": 1.1000,
            "ema_slow_m1": 1.1000,
            "ask": 1.1000,
            "bid": 1.0999,
            "dir_rule": 0,
            "is_spike_mode": False
        }
        
        response = requests.post(
            f"{base_url}/decision",
            json=test_payload,
            timeout=10,
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            result = response.json()
            print("   ✅ Endpoint /decision fonctionne!")
            print(f"   Action: {result.get('action', 'N/A')}")
            print(f"   Confiance: {result.get('confidence', 'N/A')}")
            print(f"   Raison: {result.get('reason', 'N/A')[:100]}...")
            return True
        else:
            print(f"   ⚠️ Code HTTP: {response.status_code}")
            print(f"   Réponse: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"   ❌ Erreur: {e}")
        return False

if __name__ == "__main__":
    success = test_server()
    print("\n" + "=" * 60)
    if success:
        print("✅ TOUS LES TESTS ONT RÉUSSI")
        print("Le serveur est prêt à recevoir des requêtes de MT5")
    else:
        print("❌ CERTAINS TESTS ONT ÉCHOUÉ")
        print("Vérifiez que le serveur est démarré avec: python launch_server.py")
    print("=" * 60)
    sys.exit(0 if success else 1)

