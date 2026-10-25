#!/usr/bin/env python3
"""
Script de diagnostic pour le serveur AI local (sans requests)
Utilise urllib pour tester le serveur
"""

import urllib.request
import urllib.error
import json
import time

def test_local_ai_server():
    """Tester le serveur AI local avec différents formats de requêtes"""
    
    print("🔍 DIAGNOSTIC SERVEUR AI LOCAL")
    print("=" * 50)
    
    base_url = "http://localhost:8000/decision"
    
    def post_json(data, description):
        """Fonction helper pour POST JSON"""
        print(f"\n{description}:")
        try:
            json_data = json.dumps(data).encode('utf-8')
            
            req = urllib.request.Request(
                base_url,
                data=json_data,
                headers={
                    'Content-Type': 'application/json',
                    'Content-Length': len(json_data)
                }
            )
            
            with urllib.request.urlopen(req, timeout=5) as response:
                result = response.read().decode('utf-8')
                print(f"   ✅ Status: {response.status}")
                print(f"   Response: {result[:200]}")
                return True
                
        except urllib.error.HTTPError as e:
            print(f"   ❌ HTTP Error {e.code}: {e.reason}")
            try:
                error_data = e.read().decode('utf-8')
                print(f"   Details: {error_data}")
            except:
                pass
            return False
        except Exception as e:
            print(f"   ❌ Exception: {e}")
            return False
    
    # Tests
    post_json({}, "1. Test requête vide")
    post_json({"symbol": "EURUSD"}, "2. Test avec symbol seulement")
    post_json({"symbol": "EURUSD", "bid": 1.1234}, "3. Test avec symbol et bid")
    
    # Test 4: Requête complète
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
    post_json(complete_data, "4. Test requête complète")
    
    # Test 5: Format MT5
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
    post_json(mt5_data, "5. Test format MT5")
    
    # Test 6: Vérifier GET endpoint
    print("\n6. Test GET endpoint:")
    try:
        with urllib.request.urlopen("http://localhost:8000/", timeout=5) as response:
            result = response.read().decode('utf-8')
            print(f"   ✅ Status: {response.status}")
            print(f"   Response: {result[:200]}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    print("\n" + "=" * 50)
    print("🎯 DIAGNOSTIC TERMINÉ")

if __name__ == "__main__":
    test_local_ai_server()
