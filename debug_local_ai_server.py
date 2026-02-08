#!/usr/bin/env python3
"""
Script de diagnostic pour le serveur AI local
Teste différents formats de requêtes pour identifier le problème
"""

import requests
import json
import time

def test_local_ai_server():
    """Tester le serveur AI local avec différents formats de requêtes"""
    
    print("🔍 DIAGNOSTIC SERVEUR AI LOCAL")
    print("=" * 50)
    
    base_url = "http://localhost:8000/decision"
    
    # Test 1: Requête vide
    print("\n1. Test requête vide:")
    try:
        response = requests.post(base_url, json={}, timeout=5)
        print(f"   Status: {response.status_code}")
        if response.status_code != 200:
            print(f"   Erreur: {response.text}")
    except Exception as e:
        print(f"   Exception: {e}")
    
    # Test 2: Requête avec symbol seulement
    print("\n2. Test avec symbol seulement:")
    try:
        response = requests.post(base_url, json={"symbol": "EURUSD"}, timeout=5)
        print(f"   Status: {response.status_code}")
        if response.status_code != 200:
            print(f"   Erreur: {response.text}")
    except Exception as e:
        print(f"   Exception: {e}")
    
    # Test 3: Requête avec symbol et bid
    print("\n3. Test avec symbol et bid:")
    try:
        response = requests.post(base_url, json={"symbol": "EURUSD", "bid": 1.1234}, timeout=5)
        print(f"   Status: {response.status_code}")
        if response.status_code != 200:
            print(f"   Erreur: {response.text}")
    except Exception as e:
        print(f"   Exception: {e}")
    
    # Test 4: Requête complète (format attendu)
    print("\n4. Test requête complète:")
    complete_data = {
        "symbol": "EURUSD",
        "bid": 1.1234,
        "ask": 1.1235,
        "rsi": 50.0,
        "atr": 0.001,
        "ema_fast": 1.1230,
        "ema_slow": 1.1240,
        "is_spike_mode": False,
        "dir_rule": 0,
        "supertrend_trend": 0,
        "volatility_regime": 0,
        "volatility_ratio": 1.0
    }
    try:
        response = requests.post(base_url, json=complete_data, timeout=5)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"   ✅ Succès: {result}")
        else:
            print(f"   Erreur: {response.text}")
    except Exception as e:
        print(f"   Exception: {e}")
    
    # Test 5: Requête format MT5 (simulé)
    print("\n5. Test format MT5:")
    mt5_data = {
        "symbol": "Volatility 50 (1s) Index",
        "bid": 235466.89,
        "ask": 235500.47,
        "rsi": 50.00,
        "atr": 0.00,
        "ema_fast": 0.00,
        "ema_slow": 0.00,
        "is_spike_mode": False,
        "dir_rule": 0,
        "supertrend_trend": 0,
        "volatility_regime": 0,
        "volatility_ratio": 1.0
    }
    try:
        response = requests.post(base_url, json=mt5_data, timeout=5)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"   ✅ Succès: {result}")
        else:
            print(f"   Erreur: {response.text}")
    except Exception as e:
        print(f"   Exception: {e}")
    
    # Test 6: Vérifier si le serveur est accessible
    print("\n6. Test GET endpoint:")
    try:
        response = requests.get("http://localhost:8000/", timeout=5)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.text[:200]}")
    except Exception as e:
        print(f"   Exception: {e}")
    
    print("\n" + "=" * 50)
    print("🎯 DIAGNOSTIC TERMINÉ")
    print("\nRecommandations:")
    print("- Si le test 4 fonctionne, le format des données est correct")
    print("- Si seul le test 5 échoue, problème avec les symboles Volatility")
    print("- Si tous échouent, le serveur a un problème de configuration")

if __name__ == "__main__":
    test_local_ai_server()
