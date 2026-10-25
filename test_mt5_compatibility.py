#!/usr/bin/env python3
"""
Test MT5 compatibility with AI Server
Simulates the exact payload format that MT5 sends
"""

import requests
import json

def test_mt5_payload():
    """Test with the exact payload format from MT5"""
    url = "http://127.0.0.1:8001/decision"
    
    # Simulate MT5 payload format (based on the logs)
    payload = {
        "symbol": "Crash 600 Index",
        "bid": 19719.42300,
        "ask": 19720.67600,
        "rsi": 82.00,
        "ema_fast_h1": 19532.82740,
        "ema_slow_h1": 19555.59367,
        "ema_fast_m1": 19696.21374,
        "ema_slow_m1": 19661.98272,
        "atr": 1.80536,
        "dir_rule": 1,
        "is_spike_mode": False,
        "vwap": None,
        "vwap_distance": None,
        "above_vwap": None,
        "supertrend_trend": None,
        "supertrend_line": None,
        "volatility_regime": None,
        "volatility_ratio": None
    }
    
    try:
        print(f"Testing MT5 compatibility with {url}")
        print(f"Payload: {json.dumps(payload, indent=2)}")
        
        response = requests.post(url, json=payload, timeout=5)
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        
        # Check if confidence is above the new threshold (0.7)
        response_data = response.json()
        confidence = response_data.get("confidence", 0.0)
        action = response_data.get("action", "hold")
        
        print(f"\nAnalysis:")
        print(f"- Action: {action}")
        print(f"- Confidence: {confidence}")
        print(f"- Above threshold (0.7): {confidence >= 0.7}")
        print(f"- Reason: {response_data.get('reason', 'N/A')}")
        
        return response.status_code == 200
        
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_boom_payload():
    """Test with Boom symbol (should not be blocked anymore)"""
    url = "http://127.0.0.1:8001/decision"
    
    payload = {
        "symbol": "Boom 900 Index",
        "bid": 19210.43900,
        "ask": 19211.43000,
        "rsi": 42.47,
        "ema_fast_h1": 19105.57382,
        "ema_slow_h1": 19005.85245,
        "ema_fast_m1": 19222.56677,
        "ema_slow_m1": 19230.12661,
        "atr": 3.15086,
        "dir_rule": -1,  # Sell signal
        "is_spike_mode": False
    }
    
    try:
        print(f"\n\nTesting Boom symbol with sell signal...")
        response = requests.post(url, json=payload, timeout=5)
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        
        return response.status_code == 200
        
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("MT5 COMPATIBILITY TEST")
    print("=" * 60)
    
    test_mt5_payload()
    test_boom_payload()
    
    print("\n" + "=" * 60)
    print("Test completed")
    print("=" * 60)
