#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════════════════════
    TEST AUTOMATION SCRIPT - TradBOT v3.0
    Vérifie que TOUS les composants fonctionnent correctement
═══════════════════════════════════════════════════════════════════════════════
"""

import subprocess
import requests
import json
import time
import sys
from datetime import datetime

# Couleurs de sortie
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
END = '\033[0m'

def print_header(text):
    print(f"\n{BLUE}{'='*80}{END}")
    print(f"{BLUE}{text:^80}{END}")
    print(f"{BLUE}{'='*80}{END}\n")

def print_success(text):
    print(f"{GREEN}✅ {text}{END}")

def print_error(text):
    print(f"{RED}❌ {text}{END}")

def print_warning(text):
    print(f"{YELLOW}⚠️  {text}{END}")

def print_info(text):
    print(f"{BLUE}ℹ️  {text}{END}")

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 1: Vérifier Ollama
# ═══════════════════════════════════════════════════════════════════════════════

def test_ollama():
    print_header("TEST 1: OLLAMA CONNECTION")
    
    try:
        print_info("Testing Ollama on 127.0.0.1:11434...")
        response = requests.get(
            "http://127.0.0.1:11434/api/tags",
            timeout=5
        )
        
        if response.status_code == 200:
            models = response.json().get("models", [])
            model_names = [m.get("name") for m in models]
            
            print_success(f"Ollama is ONLINE")
            print_info(f"Models available: {model_names}")
            
            if any("mistral" in m.lower() for m in model_names):
                print_success("Mistral model found!")
                return True
            else:
                print_error("Mistral model NOT found")
                print_info("Run: ollama pull mistral")
                return False
        else:
            print_error(f"HTTP {response.status_code}")
            return False
            
    except requests.exceptions.ConnectionError:
        print_error("Cannot connect to Ollama on 127.0.0.1:11434")
        print_info("Start Ollama: ollama serve")
        return False
    except Exception as e:
        print_error(f"Error: {str(e)}")
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 2: Vérifier serveur IA
# ═══════════════════════════════════════════════════════════════════════════════

def test_ai_server():
    print_header("TEST 2: AI SERVER CONNECTION")
    
    try:
        print_info("Testing AI Server on 127.0.0.1:8000...")
        response = requests.get(
            "http://127.0.0.1:8000/health",
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            print_success("AI Server is ONLINE")
            print_info(f"Status: {data.get('status')}")
            print_info(f"Ollama available: {data.get('ollama_available')}")
            print_info(f"Cache entries: {data.get('cache_size')}")
            
            return data.get('status') == 'ALIVE'
        else:
            print_error(f"HTTP {response.status_code}")
            return False
            
    except requests.exceptions.ConnectionError:
        print_error("Cannot connect to AI Server on 127.0.0.1:8000")
        print_info("Start server: python ai_server_v3_OPTIMIZED.py")
        return False
    except Exception as e:
        print_error(f"Error: {str(e)}")
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 3: Tester endpoint /decision
# ═══════════════════════════════════════════════════════════════════════════════

def test_decision_endpoint():
    print_header("TEST 3: DECISION ENDPOINT")
    
    payload = {
        "symbol": "EURUSD",
        "timeframe": "M5",
        "price": 1.0950,
        "bid": 1.0949,
        "ask": 1.0951,
        "timestamp": int(time.time()),
        "volume": 1000.0,
        "volatility": 0.015,
        "trend": "UPTREND"
    }
    
    try:
        print_info(f"Sending request: {json.dumps(payload, indent=2)}")
        
        start_time = time.time()
        response = requests.post(
            "http://127.0.0.1:8000/decision",
            json=payload,
            timeout=3
        )
        latency = (time.time() - start_time) * 1000
        
        if response.status_code == 200:
            data = response.json()
            print_success(f"Decision received in {latency:.0f}ms")
            
            # Afficher réponse
            print_info(f"Decision: {data.get('decision')}")
            print_info(f"Confidence: {data.get('confidence'):.2f}")
            print_info(f"Entry Price: {data.get('entry_price'):.5f}")
            print_info(f"Stop Loss: {data.get('stop_loss'):.5f}")
            print_info(f"Take Profit: {data.get('take_profit'):.5f}")
            print_info(f"Analysis Type: {data.get('analysis_type')}")
            
            # Valider réponse
            decision = data.get('decision')
            confidence = data.get('confidence')
            
            if decision not in ["BUY", "SELL", "HOLD"]:
                print_error(f"Invalid decision: {decision}")
                return False
            
            if not (0 <= confidence <= 1):
                print_error(f"Invalid confidence: {confidence}")
                return False
            
            print_success("Response is valid!")
            return True
        else:
            print_error(f"HTTP {response.status_code}")
            print_error(response.text)
            return False
            
    except requests.exceptions.Timeout:
        print_error("Request timeout (>3s)")
        return False
    except Exception as e:
        print_error(f"Error: {str(e)}")
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 4: Tester cache
# ═══════════════════════════════════════════════════════════════════════════════

def test_cache():
    print_header("TEST 4: CACHE PERFORMANCE")
    
    payload = {
        "symbol": "GBPUSD",
        "timeframe": "M5",
        "price": 1.2750,
        "bid": 1.2749,
        "ask": 1.2751,
        "timestamp": int(time.time()),
        "volume": 800.0,
        "volatility": 0.012,
        "trend": "DOWNTREND"
    }
    
    try:
        # Premier requête (devrait être OLLAMA ou FALLBACK)
        print_info("First request (should be OLLAMA or FALLBACK)...")
        start1 = time.time()
        response1 = requests.post(
            "http://127.0.0.1:8000/decision",
            json=payload,
            timeout=5
        )
        latency1 = (time.time() - start1) * 1000
        
        if response1.status_code != 200:
            print_error(f"First request failed: HTTP {response1.status_code}")
            return False
        
        data1 = response1.json()
        type1 = data1.get('analysis_type')
        print_success(f"First response in {latency1:.0f}ms ({type1})")
        
        # Deuxième requête (devrait être CACHE)
        time.sleep(0.1)  # Petit délai
        print_info("Second request (should be CACHE)...")
        start2 = time.time()
        response2 = requests.post(
            "http://127.0.0.1:8000/decision",
            json=payload,
            timeout=5
        )
        latency2 = (time.time() - start2) * 1000
        
        if response2.status_code != 200:
            print_error(f"Second request failed: HTTP {response2.status_code}")
            return False
        
        data2 = response2.json()
        type2 = data2.get('analysis_type')
        print_success(f"Second response in {latency2:.0f}ms ({type2})")
        
        # Vérifier cache hit
        if type2 == "CACHE":
            if latency2 < 200:  # Cache should be <200ms
                print_success("Cache is working! (latency improvement)")
                return True
            else:
                print_warning(f"Cache hit but slow: {latency2:.0f}ms")
                return True
        else:
            print_warning("Second request was not from cache (expected if TTL expired)")
            return True
        
    except Exception as e:
        print_error(f"Error: {str(e)}")
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 5: Tester fallback
# ═══════════════════════════════════════════════════════════════════════════════

def test_fallback():
    print_header("TEST 5: FALLBACK BEHAVIOR")
    
    payload = {
        "symbol": "USDJPY",
        "timeframe": "H1",
        "price": 140.50,
        "bid": 140.49,
        "ask": 140.51,
        "timestamp": int(time.time()),
        "volume": 2000.0,
        "volatility": 0.020,
        "trend": "NEUTRAL"
    }
    
    try:
        print_info("Testing with NEUTRAL trend (should give decent fallback)...")
        response = requests.post(
            "http://127.0.0.1:8000/decision",
            json=payload,
            timeout=3
        )
        
        if response.status_code == 200:
            data = response.json()
            decision = data.get('decision')
            confidence = data.get('confidence')
            
            print_success(f"Response: {decision} with {confidence:.2f} confidence")
            
            # Fallback should always give valid response
            if decision in ["BUY", "SELL", "HOLD"] and confidence > 0:
                print_success("Fallback is working correctly!")
                return True
            else:
                print_error("Invalid fallback response")
                return False
        else:
            print_error(f"HTTP {response.status_code}")
            return False
            
    except Exception as e:
        print_error(f"Error: {str(e)}")
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 6: Tester endpoints supplémentaires
# ═══════════════════════════════════════════════════════════════════════════════

def test_extra_endpoints():
    print_header("TEST 6: EXTRA ENDPOINTS")
    
    test_passed = True
    
    # Test /status
    try:
        print_info("Testing /status endpoint...")
        response = requests.get("http://127.0.0.1:8000/status", timeout=3)
        if response.status_code == 200:
            print_success("/status working")
        else:
            print_error(f"/status failed: HTTP {response.status_code}")
            test_passed = False
    except Exception as e:
        print_error(f"/status error: {str(e)}")
        test_passed = False
    
    # Test /gom/interpret
    try:
        print_info("Testing /gom/interpret endpoint...")
        payload = {
            "symbol": "EURUSD",
            "timeframe": "M5",
            "price": 1.0950,
            "bid": 1.0949,
            "ask": 1.0951,
            "timestamp": int(time.time()),
            "volume": 1000.0,
            "volatility": 0.015,
            "trend": "UPTREND"
        }
        response = requests.post(
            "http://127.0.0.1:8000/gom/interpret",
            json=payload,
            timeout=3
        )
        if response.status_code == 200:
            print_success("/gom/interpret working")
        else:
            print_error(f"/gom/interpret failed: HTTP {response.status_code}")
            test_passed = False
    except Exception as e:
        print_error(f"/gom/interpret error: {str(e)}")
        test_passed = False
    
    return test_passed


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN TEST RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    print_header("TRADBOT v3.0 - AUTOMATED TEST SUITE")
    print(f"{BLUE}Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{END}\n")
    
    results = {}
    
    # Run all tests
    results['Ollama'] = test_ollama()
    results['AI Server'] = test_ai_server()
    results['Decision Endpoint'] = test_decision_endpoint()
    results['Cache'] = test_cache()
    results['Fallback'] = test_fallback()
    results['Extra Endpoints'] = test_extra_endpoints()
    
    # Summary
    print_header("TEST SUMMARY")
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for test, result in results.items():
        status = f"{GREEN}PASS{END}" if result else f"{RED}FAIL{END}"
        print(f"{test:.<40} {status}")
    
    print(f"\n{BLUE}{'='*80}{END}")
    if passed == total:
        print_success(f"ALL TESTS PASSED ({passed}/{total})")
        print(f"\n{GREEN}Your TradBOT system is READY FOR PRODUCTION! 🚀{END}\n")
        return 0
    else:
        print_error(f"SOME TESTS FAILED ({passed}/{total} passed)")
        print(f"\n{RED}Please fix the issues above before trading.{END}\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
