import requests
import json
import time

def test_decision_fallback():
    url = "http://127.0.0.1:8000/decision"
    
    # Test case 1: Body Only
    print("Testing Case 1: JSON Body only...")
    payload = {
        "symbol": "BTCUSD",
        "bid": 50000.5,
        "ask": 50001.5,
        "rsi": 45.5,
        "ema_fast_m1": 49800.0,
        "ema_slow_m1": 49500.0,
        "dir_rule": 1
    }
    resp = requests.post(url, json=payload)
    print(f"Status: {resp.status_code}")
    print(f"Response: {resp.json().get('action')}")
    
    # Test case 2: Query Parameters Only (Simulating empty body)
    print("\nTesting Case 2: Query parameters only (Empty body)...")
    params = {
        "symbol": "ETHUSD",
        "bid": 3000.5,
        "ask": 3001.5,
        "rsi": 65.5,
        "ema_fast_m1": 2900.0,
        "ema_slow_m1": 2800.0,
        "dir_rule": -1
    }
    resp = requests.post(url, params=params, data="") # Empty body
    print(f"Status: {resp.status_code}")
    # Inspecting if it processed properly (action should not be wait if trend is strong)
    print(f"Response: {resp.json().get('action')}")

    # Test case 3: Both (Redundancy)
    print("\nTesting Case 3: Both JSON Body and Query Parameters (Redundancy)...")
    # Body has one value, query has another. Body should win.
    params = {"symbol": "GOLD", "bid": 1900.0}
    payload = {"symbol": "GOLD", "bid": 2000.0}
    resp = requests.post(url, params=params, json=payload)
    print(f"Status: {resp.status_code}")
    # We can't easily see the internal 'bid' without more logging, 
    # but the server logs should show 'Source for bid: JSON body'
    print("Check server logs for 'Source for bid: JSON body'")

if __name__ == "__main__":
    test_decision_fallback()
