#!/usr/bin/env python3
"""
Test simple de l'API de tendance
"""

import requests
import json
import time

def test_trend_api():
    """Test de l'API de tendance"""
    print("=== TEST API DE TENDANCE ===")
    print()
    
    # Attendre que l'API démarre
    print("Attente du demarrage de l'API...")
    time.sleep(2)
    
    try:
        # Test de l'endpoint health
        print("1. Test endpoint /health...")
        response = requests.get("http://localhost:8001/health", timeout=5)
        if response.status_code == 200:
            print("   [OK] API repond correctement")
            print(f"   Reponse: {response.json()}")
        else:
            print(f"   [ERROR] Code: {response.status_code}")
            
    except requests.exceptions.ConnectionError:
        print("   [ERROR] Impossible de se connecter a l'API")
        print("   Verifiez que l'API est demarree sur le port 8001")
        return False
    except Exception as e:
        print(f"   [ERROR] Erreur: {e}")
        return False
    
    try:
        # Test de l'endpoint trend
        print("\n2. Test endpoint /trend...")
        response = requests.get("http://localhost:8001/trend?symbol=Boom 1000 Index&timeframe=M1", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print("   [OK] Donnees de tendance recues")
            print(f"   Symbole: {data.get('symbol', 'N/A')}")
            print(f"   Direction: {data.get('trend_direction', 'N/A')}")
            print(f"   Force: {data.get('trend_strength', 'N/A')}")
            print(f"   Confiance: {data.get('confidence', 'N/A')}")
        else:
            print(f"   [ERROR] Code: {response.status_code}")
            
    except Exception as e:
        print(f"   [ERROR] Erreur: {e}")
        return False
    
    print("\n=== TEST TERMINE ===")
    print("L'API de tendance fonctionne correctement!")
    return True

if __name__ == "__main__":
    test_trend_api()