#!/usr/bin/env python3
"""
Test de l'API Trend Optimisée
Vérifie que les optimisations réduisent l'impact sur MetaTrader 5
"""

import requests
import json
import time
from datetime import datetime

def test_optimized_api():
    """Test de l'API optimisée"""
    print("🧪 Test de l'API Trend Optimisée")
    print("=" * 50)
    
    base_url = "http://localhost:8001"
    
    # Test 1: Health check optimisé
    try:
        start_time = time.time()
        response = requests.get(f"{base_url}/health", timeout=3)
        response_time = time.time() - start_time
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Health check optimisé: OK")
            print(f"   Status: {data.get('status')}")
            print(f"   Optimized: {data.get('optimized', False)}")
            print(f"   Temps de réponse: {response_time:.3f}s")
        else:
            print(f"❌ Health check: {response.status_code}")
    except Exception as e:
        print(f"❌ Health check: {e}")
    
    # Test 2: Endpoint trend optimisé
    try:
        start_time = time.time()
        response = requests.get(f"{base_url}/trend?symbol=EURUSD&timeframe=M1", timeout=3)
        response_time = time.time() - start_time
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Trend endpoint optimisé: OK")
            print(f"   Symbole: {data.get('symbol')}")
            print(f"   Direction: {data.get('trend_direction')}")
            print(f"   Confiance: {data.get('confidence')}")
            print(f"   Signal: {data.get('trading_signal')}")
            print(f"   Temps de réponse: {response_time:.3f}s")
        else:
            print(f"❌ Trend endpoint: {response.status_code}")
    except Exception as e:
        print(f"❌ Trend endpoint: {e}")
    
    # Test 3: Endpoint performance
    try:
        start_time = time.time()
        response = requests.get(f"{base_url}/performance", timeout=3)
        response_time = time.time() - start_time
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Performance endpoint: OK")
            print(f"   Temps de réponse: {response_time:.3f}s")
            
            if 'performance_stats' in data:
                stats = data['performance_stats']
                print(f"   Cache hits: {stats.get('cache_hits', 0)}")
                print(f"   Cache misses: {stats.get('cache_misses', 0)}")
                print(f"   Appels API réduits: {stats.get('api_calls_reduced', 0)}")
                print(f"   Opérations batch: {stats.get('batch_operations', 0)}")
        else:
            print(f"❌ Performance endpoint: {response.status_code}")
    except Exception as e:
        print(f"❌ Performance endpoint: {e}")
    
    # Test 4: Test de performance avec plusieurs appels
    print(f"\n📊 Test de Performance avec Appels Multiples")
    print("=" * 50)
    
    symbols = ['EURUSD', 'Boom 1000 Index', 'Crash 1000 Index']
    total_time = 0
    successful_calls = 0
    
    for i, symbol in enumerate(symbols):
        try:
            start_time = time.time()
            response = requests.get(f"{base_url}/trend?symbol={symbol}&timeframe=M1", timeout=3)
            call_time = time.time() - start_time
            total_time += call_time
            
            if response.status_code == 200:
                successful_calls += 1
                data = response.json()
                print(f"   {symbol}: {call_time:.3f}s - {data.get('trading_signal', 'N/A')}")
            else:
                print(f"   {symbol}: {call_time:.3f}s - ERREUR {response.status_code}")
                
        except Exception as e:
            print(f"   {symbol}: ERREUR - {e}")
    
    # Calculer les statistiques
    if successful_calls > 0:
        avg_response_time = total_time / successful_calls
        print(f"\n📈 Statistiques de Performance:")
        print(f"   Appels réussis: {successful_calls}/{len(symbols)}")
        print(f"   Temps total: {total_time:.3f}s")
        print(f"   Temps moyen: {avg_response_time:.3f}s")
        
        # Évaluer les performances
        if avg_response_time < 0.5:
            print("   ✅ Performance: EXCELLENTE (< 0.5s)")
        elif avg_response_time < 1.0:
            print("   ✅ Performance: BONNE (< 1.0s)")
        elif avg_response_time < 2.0:
            print("   ⚠️ Performance: ACCEPTABLE (< 2.0s)")
        else:
            print("   ❌ Performance: LENTE (> 2.0s)")
    
    # Test 5: Test de cache
    print(f"\n📦 Test de Cache")
    print("=" * 50)
    
    # Premier appel (cache miss)
    start_time = time.time()
    response1 = requests.get(f"{base_url}/trend?symbol=EURUSD&timeframe=M1", timeout=3)
    time1 = time.time() - start_time
    
    # Deuxième appel immédiat (cache hit)
    start_time = time.time()
    response2 = requests.get(f"{base_url}/trend?symbol=EURUSD&timeframe=M1", timeout=3)
    time2 = time.time() - start_time
    
    if response1.status_code == 200 and response2.status_code == 200:
        print(f"   Premier appel: {time1:.3f}s")
        print(f"   Deuxième appel: {time2:.3f}s")
        
        if time2 < time1:
            improvement = ((time1 - time2) / time1) * 100
            print(f"   ✅ Amélioration cache: {improvement:.1f}%")
        else:
            print(f"   ⚠️ Pas d'amélioration cache détectée")
    
    print(f"\n🎯 Test terminé à {datetime.now().strftime('%H:%M:%S')}")

if __name__ == "__main__":
    test_optimized_api()
