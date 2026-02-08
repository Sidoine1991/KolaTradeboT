#!/usr/bin/env python3
"""
Script de test pour le client MT5 corrigé
"""

import requests
import json

def test_correct_format():
    """Tester le format corrigé avec le serveur local"""
    
    print("🧪 TEST CLIENT MT5 CORRIGÉ")
    print("=" * 50)
    
    # Test 1: Format complet
    print("\n1. Test format complet:")
    decision_data = {
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
        response = requests.post("http://localhost:8000/decision", json=decision_data, timeout=5)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ Succès: {data}")
        else:
            print(f"   ❌ Erreur: {response.text}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    # Test 2: Format Volatility
    print("\n2. Test format Volatility:")
    volatility_data = {
        "symbol": "Volatility 50 (1s) Index",
        "bid": 235466.89,
        "ask": 235500.47,
        "rsi": 50.0,
        "atr": 0.0,
        "ema_fast": 0.0,
        "ema_slow": 0.0,
        "is_spike_mode": False,
        "dir_rule": 0,
        "supertrend_trend": 0,
        "volatility_regime": 0,
        "volatility_ratio": 1.0
    }
    
    try:
        response = requests.post("http://localhost:8000/decision", json=volatility_data, timeout=5)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ Succès: {data}")
        else:
            print(f"   ❌ Erreur: {response.text}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    print("\n" + "=" * 50)
    print("🎯 TEST TERMINÉ")
    print("\nSi les tests réussissent, le client MT5 corrigé fonctionnera!")

if __name__ == "__main__":
    test_correct_format()
