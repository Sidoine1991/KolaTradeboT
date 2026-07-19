#!/usr/bin/env python3
"""
Test en direct du serveur IA pour TradBOT
Vérifie que tous les endpoints répondent correctement
"""

import requests
import json
import time
import sys
from datetime import datetime

# Configuration
BASE_URL = "http://127.0.0.1:8000"
TIMEOUT = 10

def test_endpoint(endpoint, method="GET", data=None, description=""):
    """Test un endpoint spécifique"""
    url = f"{BASE_URL}{endpoint}"
    print(f"\n{'='*60}")
    print(f"Test: {description}")
    print(f"URL: {url}")
    print(f"Méthode: {method}")
    
    try:
        start_time = time.time()
        
        if method == "GET":
            response = requests.get(url, timeout=TIMEOUT)
        elif method == "POST":
            headers = {"Content-Type": "application/json"}
            response = requests.post(url, json=data, headers=headers, timeout=TIMEOUT)
        else:
            print(f"❌ Méthode non supportée: {method}")
            return False
            
        elapsed = (time.time() - start_time) * 1000
        
        print(f"Status: {response.status_code}")
        print(f"Temps: {elapsed:.1f}ms")
        
        if response.status_code == 200:
            try:
                result = response.json()
                print(f"✅ Réponse JSON valide")
                
                # Analyse spécifique selon l'endpoint
                if endpoint == "/decision":
                    if "action" in result and "confidence" in result:
                        print(f"   Action: {result.get('action')}")
                        print(f"   Confiance: {result.get('confidence')}")
                        print(f"   Raison: {result.get('reason', 'N/A')}")
                        return True
                    else:
                        print(f"❌ Format réponse invalide pour /decision")
                        return False
                        
                elif endpoint == "/health":
                    if "status" in result and result.get("status") == "ok":
                        print(f"   Status: {result.get('status')}")
                        print(f"   Version: {result.get('version', 'N/A')}")
                        return True
                    else:
                        print(f"❌ Status != 'ok'")
                        return False
                        
                elif endpoint == "/trend":
                    if "trend" in result:
                        print(f"   Trend: {result.get('trend')}")
                        print(f"   Strength: {result.get('strength', 'N/A')}")
                        return True
                    else:
                        print(f"❌ Champ 'trend' manquant")
                        return False
                        
                elif endpoint == "/gom":
                    if "verdict" in result:
                        print(f"   Verdict: {result.get('verdict')}")
                        print(f"   Verdict Num: {result.get('verdict_num', 'N/A')}")
                        print(f"   Cohérence: {result.get('coherence_pct', 'N/A')}%")
                        return True
                    else:
                        print(f"❌ Champ 'verdict' manquant")
                        return False
                        
                else:
                    # Pour les autres endpoints, vérifier juste que c'est du JSON valide
                    print(f"   Réponse: {json.dumps(result, indent=2)[:200]}...")
                    return True
                    
            except json.JSONDecodeError:
                print(f"❌ Réponse non-JSON: {response.text[:100]}")
                return False
        else:
            print(f"❌ Erreur HTTP {response.status_code}")
            print(f"   Réponse: {response.text[:200]}")
            return False
            
    except requests.exceptions.Timeout:
        print(f"❌ Timeout après {TIMEOUT}s")
        return False
    except requests.exceptions.ConnectionError:
        print(f"❌ Impossible de se connecter au serveur")
        print(f"   Vérifiez que le serveur est démarré: python ai_server.py")
        return False
    except Exception as e:
        print(f"❌ Erreur inattendue: {e}")
        return False

def test_decision_endpoint():
    """Test complet de l'endpoint /decision avec différentes configurations"""
    print("\n" + "="*60)
    print("TEST COMPLET ENDPOINT /decision")
    print("="*60)
    
    test_cases = [
        {
            "data": {
                "symbol": "XAUUSD",
                "timeframe": "M1",
                "bid": 1950.50,
                "ask": 1950.60,
                "spread": 0.10,
                "rsi": 45.5,
                "atr": 1.2,
                "ema_fast": 1949.8,
                "ema_slow": 1948.5,
                "timestamp": int(time.time())
            },
            "description": "Or (XAUUSD) - test basique"
        },
        {
            "data": {
                "symbol": "EURUSD",
                "timeframe": "M5",
                "bid": 1.0850,
                "ask": 1.0851,
                "spread": 0.0001,
                "rsi": 55.0,
                "atr": 0.0008,
                "ema_fast": 1.0848,
                "ema_slow": 1.0845,
                "timestamp": int(time.time())
            },
            "description": "Forex (EURUSD) - test M5"
        },
        {
            "data": {
                "symbol": "Boom 300 Index",
                "timeframe": "M1",
                "bid": 450.25,
                "ask": 450.35,
                "spread": 0.10,
                "rsi": 30.5,
                "atr": 2.5,
                "ema_fast": 449.8,
                "ema_slow": 448.5,
                "timestamp": int(time.time())
            },
            "description": "Boom Index - test synthétique"
        }
    ]
    
    successes = 0
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n--- Test {i}/{len(test_cases)}: {test_case['description']} ---")
        
        if test_endpoint("/decision", "POST", test_case["data"], test_case["description"]):
            successes += 1
        else:
            print(f"❌ Échec du test {i}")
            
    return successes == len(test_cases)

def test_advanced_endpoints():
    """Test des endpoints avancés"""
    print("\n" + "="*60)
    print("TEST ENDPOINTS AVANCÉS")
    print("="*60)
    
    endpoints = [
        ("/health", "GET", None, "Health check"),
        ("/trend", "GET", None, "Trend analysis"),
        ("/gom", "GET", None, "GOM verdict"),
        ("/daily-readiness", "GET", None, "Daily readiness"),
        ("/agents/gate", "POST", {
            "symbol": "XAUUSD",
            "timeframe": "M1",
            "bid": 1950.50,
            "ask": 1950.60,
            "rsi": 45.5,
            "atr": 1.2
        }, "Agent gate"),
        ("/spike-probability", "POST", {
            "symbol": "Boom 300 Index",
            "timeframe": "M1",
            "bid": 450.25,
            "ask": 450.35,
            "rsi": 30.5,
            "atr": 2.5
        }, "Spike probability")
    ]
    
    success_count = 0
    for endpoint, method, data, description in endpoints:
        if test_endpoint(endpoint, method, data, description):
            success_count += 1
            
    return success_count >= len(endpoints) * 0.8  # 80% de succès minimum

def test_ml_metrics():
    """Test des métriques ML"""
    print("\n" + "="*60)
    print("TEST MÉTRIQUES ML")
    print("="*60)
    
    # Test avec un symbole spécifique
    data = {
        "symbol": "XAUUSD",
        "timeframe": "M1"
    }
    
    return test_endpoint("/ml-metrics", "POST", data, "ML Metrics")

def test_performance():
    """Test de performance avec requêtes multiples"""
    print("\n" + "="*60)
    print("TEST DE PERFORMANCE")
    print("="*60)
    
    test_data = {
        "symbol": "EURUSD",
        "timeframe": "M1",
        "bid": 1.0850,
        "ask": 1.0851,
        "spread": 0.0001,
        "rsi": 55.0,
        "atr": 0.0008,
        "ema_fast": 1.0848,
        "ema_slow": 1.0845,
        "timestamp": int(time.time())
    }
    
    times = []
    successes = 0
    
    for i in range(3):  # 3 requêtes pour tester la performance
        print(f"\nRequête de performance {i+1}/3...")
        start_time = time.time()
        
        try:
            response = requests.post(
                f"{BASE_URL}/decision",
                json=test_data,
                headers={"Content-Type": "application/json"},
                timeout=TIMEOUT
            )
            
            elapsed = (time.time() - start_time) * 1000
            times.append(elapsed)
            
            if response.status_code == 200:
                successes += 1
                print(f"   ✓ {elapsed:.1f}ms")
            else:
                print(f"   ✗ {elapsed:.1f}ms - HTTP {response.status_code}")
                
        except Exception as e:
            elapsed = (time.time() - start_time) * 1000
            times.append(elapsed)
            print(f"   ✗ {elapsed:.1f}ms - Erreur: {e}")
    
    if times:
        avg_time = sum(times) / len(times)
        max_time = max(times)
        min_time = min(times)
        
        print(f"\n📊 Résultats performance:")
        print(f"   Moyenne: {avg_time:.1f}ms")
        print(f"   Min: {min_time:.1f}ms")
        print(f"   Max: {max_time:.1f}ms")
        print(f"   Succès: {successes}/3")
        
        # Critère: moyenne < 500ms et tous succès
        return avg_time < 500 and successes == 3
    else:
        print("❌ Aucune mesure de temps disponible")
        return False

def main():
    """Fonction principale de test"""
    print("="*60)
    print("TEST COMPLET SERVEUR IA TRADBOT")
    print("="*60)
    print(f"URL de base: {BASE_URL}")
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    # Vérifier d'abord que le serveur est accessible
    print("\n🔍 Vérification de la connexion au serveur...")
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        if response.status_code == 200:
            print("✅ Serveur accessible")
        else:
            print(f"❌ Serveur accessible mais /health retourne {response.status_code}")
            print(f"   Vérifiez que le serveur IA est bien démarré avec: python ai_server.py")
            return 1
    except requests.exceptions.ConnectionError:
        print("❌ Impossible de se connecter au serveur")
        print("   Démarrer le serveur avec: python ai_server.py")
        return 1
    
    # Exécuter les tests
    tests = [
        ("Health check", lambda: test_endpoint("/health", "GET", None, "Health check")),
        ("Trend analysis", lambda: test_endpoint("/trend", "GET", None, "Trend analysis")),
        ("GOM verdict", lambda: test_endpoint("/gom", "GET", None, "GOM verdict")),
        ("Decision endpoint", test_decision_endpoint),
        ("Advanced endpoints", test_advanced_endpoints),
        ("ML metrics", test_ml_metrics),
        ("Performance", test_performance)
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\n🧪 Exécution: {test_name}")
        try:
            success = test_func()
            results.append((test_name, success))
            print(f"   {'✅ PASS' if success else '❌ FAIL'}")
        except Exception as e:
            print(f"   ❌ ERREUR: {e}")
            results.append((test_name, False))
    
    # Résumé
    print("\n" + "="*60)
    print("RÉSUMUM DES TESTS")
    print("="*60)
    
    passed = sum(1 for _, success in results if success)
    total = len(results)
    
    for test_name, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} {test_name}")
    
    print(f"\n📊 Score: {passed}/{total} tests passés ({passed/total*100:.1f}%)")
    
    if passed == total:
        print("\n🎉 TOUS LES TESTS ONT RÉUSSI !")
        print("Le serveur IA est opérationnel et prêt pour le trading.")
        return 0
    elif passed >= total * 0.7:  # 70% de succès minimum
        print(f"\n⚠️  {total - passed} tests ont échoué, mais le serveur est fonctionnel.")
        print("Certaines fonctionnalités avancées peuvent ne pas être disponibles.")
        return 0
    else:
        print(f"\n❌ {total - passed} tests ont échoué.")
        print("Le serveur IA nécessite des ajustements.")
        return 1

if __name__ == "__main__":
    sys.exit(main())