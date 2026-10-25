#!/usr/bin/env python3
"""
Diagnostic des erreurs API Render pour BoomCrash Bot
Erreurs observées:
- 422 sur /decision : format de données incorrect
- 404 sur /predict et /trend : endpoints non trouvés
"""

import requests
import json
from datetime import datetime

def test_endpoints():
    base_url = "https://kolatradebot.onrender.com"
    
    print("🔍 DIAGNOSTIC DES ENDPOINTS RENDER")
    print("=" * 50)
    print(f"Heure: {datetime.now().strftime('%H:%M:%S')}")
    print(f"Base URL: {base_url}")
    print()
    
    # Test 1: Endpoint /decision
    print("1. TEST /decision")
    decision_url = f"{base_url}/decision"
    decision_data = {
        "symbol": "Boom 600 Index",
        "bid": 1234.5,
        "ask": 1235.0,
        "rsi": 45.2,
        "ema_fast_h1": 1233.0,
        "ema_slow_h1": 1232.0,
        "ema_fast_m1": 1234.0,
        "ema_slow_m1": 1233.5,
        "atr": 2.5,
        "dir_rule": 1,
        "is_spike_mode": True
    }
    
    try:
        response = requests.post(decision_url, json=decision_data, timeout=10)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            print(f"   ✅ Succès: {response.json()}")
        else:
            print(f"   ❌ Erreur: {response.status_code}")
            print(f"   Response: {response.text[:200]}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    print()
    
    # Test 2: Endpoint /predict
    print("2. TEST /predict")
    predict_url = f"{base_url}/predict"
    predict_data = {
        "symbol": "Boom 600 Index",
        "bars": 100
    }
    
    try:
        response = requests.post(predict_url, json=predict_data, timeout=10)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            print(f"   ✅ Succès: {len(response.json())} prédictions reçues")
        else:
            print(f"   ❌ Erreur: {response.status_code}")
            print(f"   Response: {response.text[:200]}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    print()
    
    # Test 3: Endpoint /trend
    print("3. TEST /trend")
    trend_url = f"{base_url}/trend"
    trend_data = {
        "symbol": "Boom 600 Index"
    }
    
    try:
        response = requests.post(trend_url, json=trend_data, timeout=10)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            print(f"   ✅ Succès: {response.json()}")
        else:
            print(f"   ❌ Erreur: {response.status_code}")
            print(f"   Response: {response.text[:200]}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    print()
    
    # Test 4: Vérifier les endpoints disponibles
    print("4. TEST ENDPOINTS DISPONIBLES")
    try:
        response = requests.get(base_url, timeout=10)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            print(f"   ✅ Serveur accessible")
            print(f"   Response: {response.text[:200]}")
        else:
            print(f"   ❌ Serveur inaccessible: {response.status_code}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    print()
    print("🔧 RECOMMANDATIONS:")
    print("1. Si /predict et /trend retournent 404:")
    print("   - Vérifier que les endpoints existent sur le serveur")
    print("   - Peut-être utiliser /trend-analysis au lieu de /trend")
    print()
    print("2. Si /decision retourne 422:")
    print("   - Vérifier le format des données envoyées")
    print("   - Certains champs peuvent être manquants ou incorrects")
    print()
    print("3. Solutions possibles:")
    print("   - Désactiver les endpoints qui ne fonctionnent pas")
    print("   - Utiliser seulement /decision qui fonctionne")
    print("   - Corriger les URLs des endpoints")

if __name__ == "__main__":
    test_endpoints()
