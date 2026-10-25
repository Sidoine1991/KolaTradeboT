#!/usr/bin/env python3
"""
Test de l'API Trend TradBOT
Vérifie que l'API fonctionne correctement sur le port 8001
"""

import requests
import json
import time

def test_trend_api():
    """Test de l'API Trend"""
    base_url = "http://localhost:8001"
    
    print("🧪 Test de l'API Trend TradBOT")
    print("=" * 50)
    
    # Test 1: Endpoint principal
    try:
        response = requests.get(f"{base_url}/", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print("✅ Endpoint principal: OK")
            print(f"   Message: {data.get('message')}")
            print(f"   Status: {data.get('status')}")
        else:
            print(f"❌ Endpoint principal: Erreur {response.status_code}")
    except Exception as e:
        print(f"❌ Endpoint principal: {e}")
    
    # Test 2: Health check
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print("✅ Health check: OK")
            print(f"   Status: {data.get('status')}")
            print(f"   Timestamp: {data.get('timestamp')}")
        else:
            print(f"❌ Health check: Erreur {response.status_code}")
    except Exception as e:
        print(f"❌ Health check: {e}")
    
    # Test 3: Données de tendance
    try:
        response = requests.get(f"{base_url}/trend?symbol=EURUSD&timeframe=M1", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print("✅ Données de tendance: OK")
            print(f"   Symbole: {data.get('symbol')}")
            print(f"   Timeframe: {data.get('timeframe')}")
            print(f"   Direction: {data.get('trend_direction')}")
            print(f"   Force: {data.get('trend_strength')}")
            print(f"   Confiance: {data.get('confidence')}")
            print(f"   Signal: {data.get('trading_signal')}")
        else:
            print(f"❌ Données de tendance: Erreur {response.status_code}")
    except Exception as e:
        print(f"❌ Données de tendance: {e}")
    
    # Test 4: Status détaillé
    try:
        response = requests.get(f"{base_url}/status", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print("✅ Status détaillé: OK")
            print(f"   Status: {data.get('status')}")
            print(f"   Port: {data.get('port')}")
            print(f"   Uptime: {data.get('uptime')}")
            print(f"   Endpoints: {len(data.get('endpoints', {}))}")
        else:
            print(f"❌ Status détaillé: Erreur {response.status_code}")
    except Exception as e:
        print(f"❌ Status détaillé: {e}")
    
    print("\n" + "=" * 50)
    print("🎯 Test terminé")

if __name__ == "__main__":
    test_trend_api()
