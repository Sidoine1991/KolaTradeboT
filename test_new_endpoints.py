#!/usr/bin/env python3
"""
Tests rapides pour les 3 nouveaux endpoints ML
Fichier: test_new_endpoints.py
Usage: python test_new_endpoints.py
"""

import requests
import json
import time
from typing import Dict, Any

# Configuration
BASE_URL = "http://localhost:8000"
SYMBOLS = ["Boom 1000 Index", "Crash 1000 Index", "EURUSD"]
TIMEOUT = 5.0

# Couleurs console
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def print_header(title: str):
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'='*70}")
    print(f"  {title}")
    print(f"{'='*70}{Colors.ENDC}\n")

def print_success(msg: str):
    print(f"{Colors.OKGREEN}✅ {msg}{Colors.ENDC}")

def print_warning(msg: str):
    print(f"{Colors.WARNING}⚠️  {msg}{Colors.ENDC}")

def print_error(msg: str):
    print(f"{Colors.FAIL}❌ {msg}{Colors.ENDC}")

def print_info(msg: str):
    print(f"{Colors.OKCYAN}ℹ️  {msg}{Colors.ENDC}")

def test_endpoint_health():
    """Test que le serveur est accessible"""
    print_header("TEST 1: Server Health Check")

    try:
        resp = requests.get(f"{BASE_URL}/health", timeout=TIMEOUT)
        if resp.status_code == 200:
            print_success(f"Server is UP (HTTP {resp.status_code})")
            print_info(f"Response: {resp.json()}")
            return True
        else:
            print_error(f"Server returned HTTP {resp.status_code}")
            return False
    except Exception as e:
        print_error(f"Cannot reach server: {e}")
        print_warning("Make sure: python ai_server.py is running on localhost:8000")
        return False

def test_ml_decision():
    """Test GET /ml/decision"""
    print_header("TEST 2: GET /ml/decision")

    passed = 0
    for symbol in SYMBOLS:
        try:
            url = f"{BASE_URL}/ml/decision"
            params = {"symbol": symbol, "timeframe": "M1"}

            print_info(f"Testing: {symbol}")
            start = time.time()
            resp = requests.get(url, params=params, timeout=TIMEOUT)
            elapsed = time.time() - start

            if resp.status_code == 200:
                data = resp.json()
                action = data.get("action", "UNKNOWN")
                confidence = data.get("confidence", 0.0)

                print_success(
                    f"  HTTP {resp.status_code} | "
                    f"Action: {action} | "
                    f"Confidence: {confidence:.2f} | "
                    f"Time: {elapsed:.3f}s"
                )

                # Validate response structure
                required_fields = ["action", "confidence", "reason"]
                missing = [f for f in required_fields if f not in data]
                if missing:
                    print_warning(f"  Missing fields: {missing}")
                else:
                    print_success(f"  All required fields present")
                    passed += 1

                # Check performance
                if elapsed > 0.5:
                    print_warning(f"  Slow response: {elapsed:.3f}s (target: <500ms)")
                else:
                    print_success(f"  Response time OK: {elapsed:.3f}s")

            else:
                print_error(f"  HTTP {resp.status_code}: {resp.text}")

        except Exception as e:
            print_error(f"  Exception: {e}")

    print_info(f"\nPassed: {passed}/{len(SYMBOLS)} symbols")
    return passed == len(SYMBOLS)

def test_ml_trend_alignment():
    """Test GET /ml/trend_alignment"""
    print_header("TEST 3: GET /ml/trend_alignment")

    passed = 0
    for symbol in SYMBOLS:
        try:
            url = f"{BASE_URL}/ml/trend_alignment"
            params = {"symbol": symbol}

            print_info(f"Testing: {symbol}")
            start = time.time()
            resp = requests.get(url, params=params, timeout=TIMEOUT)
            elapsed = time.time() - start

            if resp.status_code == 200:
                data = resp.json()
                aligned = data.get("aligned", False)
                direction = data.get("direction", "UNKNOWN")
                confidence = data.get("confidence", 0.0)

                print_success(
                    f"  HTTP {resp.status_code} | "
                    f"Aligned: {aligned} | "
                    f"Direction: {direction} | "
                    f"Time: {elapsed:.3f}s"
                )

                # Validate response structure
                required_fields = ["aligned", "direction", "confidence"]
                missing = [f for f in required_fields if f not in data]
                if missing:
                    print_warning(f"  Missing fields: {missing}")
                else:
                    print_success(f"  All required fields present")
                    passed += 1

            else:
                print_error(f"  HTTP {resp.status_code}: {resp.text}")

        except Exception as e:
            print_error(f"  Exception: {e}")

    print_info(f"\nPassed: {passed}/{len(SYMBOLS)} symbols")
    return passed == len(SYMBOLS)

def test_ml_coherent_analysis():
    """Test GET /ml/coherent_analysis"""
    print_header("TEST 4: GET /ml/coherent_analysis")

    passed = 0
    for symbol in SYMBOLS:
        try:
            url = f"{BASE_URL}/ml/coherent_analysis"
            params = {"symbol": symbol}

            print_info(f"Testing: {symbol}")
            start = time.time()
            resp = requests.get(url, params=params, timeout=TIMEOUT)
            elapsed = time.time() - start

            if resp.status_code == 200:
                data = resp.json()
                coherence = data.get("coherence_score", 0.0)
                consensus = data.get("consensus", "UNKNOWN")
                volatility = data.get("volatility_regime", "UNKNOWN")

                print_success(
                    f"  HTTP {resp.status_code} | "
                    f"Coherence: {coherence:.2f} | "
                    f"Consensus: {consensus} | "
                    f"Time: {elapsed:.3f}s"
                )

                # Validate response structure
                required_fields = ["coherence_score", "consensus"]
                missing = [f for f in required_fields if f not in data]
                if missing:
                    print_warning(f"  Missing fields: {missing}")
                else:
                    print_success(f"  All required fields present")
                    passed += 1

            else:
                print_error(f"  HTTP {resp.status_code}: {resp.text}")

        except Exception as e:
            print_error(f"  Exception: {e}")

    print_info(f"\nPassed: {passed}/{len(SYMBOLS)} symbols")
    return passed == len(SYMBOLS)

def test_performance():
    """Test performance: response time must be < 500ms"""
    print_header("TEST 5: Performance Benchmark")

    endpoints = [
        ("/ml/decision", {"symbol": "Boom 1000 Index", "timeframe": "M1"}),
        ("/ml/trend_alignment", {"symbol": "Boom 1000 Index"}),
        ("/ml/coherent_analysis", {"symbol": "Boom 1000 Index"}),
    ]

    results = {}
    for endpoint, params in endpoints:
        times = []
        for i in range(3):
            try:
                start = time.time()
                resp = requests.get(f"{BASE_URL}{endpoint}", params=params, timeout=TIMEOUT)
                elapsed = time.time() - start
                times.append(elapsed)

            except Exception as e:
                print_error(f"  {endpoint}: {e}")
                return False

        avg_time = sum(times) / len(times)
        results[endpoint] = {
            "avg": avg_time,
            "times": times,
            "ok": avg_time < 0.5
        }

        status = "✅" if avg_time < 0.5 else "⚠️ "
        print_info(f"{status} {endpoint}: avg={avg_time:.3f}s, "
                   f"samples={times[0]:.3f}s, {times[1]:.3f}s, {times[2]:.3f}s")

    all_ok = all(r["ok"] for r in results.values())
    return all_ok

def main():
    """Run all tests"""
    print(f"\n{Colors.BOLD}TradBOT ML Endpoints Test Suite{Colors.ENDC}")
    print(f"Testing new endpoints: /ml/decision, /ml/trend_alignment, /ml/coherent_analysis")
    print(f"Target: Response time < 500ms\n")

    results = []

    # Test 1: Health check
    results.append(("Health Check", test_endpoint_health()))
    if not results[-1][1]:
        print_error("Server not accessible. Stopping tests.")
        return

    # Test 2: /ml/decision
    results.append(("/ml/decision", test_ml_decision()))

    # Test 3: /ml/trend_alignment
    results.append(("/ml/trend_alignment", test_ml_trend_alignment()))

    # Test 4: /ml/coherent_analysis
    results.append(("/ml/coherent_analysis", test_ml_coherent_analysis()))

    # Test 5: Performance
    results.append(("Performance", test_performance()))

    # Summary
    print_header("TEST SUMMARY")

    for test_name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status} | {test_name}")

    total_passed = sum(1 for _, p in results if p)
    total_tests = len(results)

    print(f"\n{Colors.BOLD}Total: {total_passed}/{total_tests} tests passed{Colors.ENDC}")

    if total_passed == total_tests:
        print_success("All tests passed! 🎉")
    else:
        print_error("Some tests failed. Check logs above.")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print_warning("\n\nTests interrupted by user")
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        import traceback
        traceback.print_exc()
