#!/usr/bin/env python3
"""
Test script for AI Server
"""

import requests
import json

def test_ai_server():
    """Test the AI server endpoint"""
    url = "http://127.0.0.1:8001/decision"
    
    # Test payload
    payload = {
        "symbol": "Boom 900 Index",
        "bid": 9965.5,
        "ask": 9966.5,
        "rsi": 45.0,
        "ema_fast_h1": 9950.0,
        "ema_slow_h1": 9940.0,
        "ema_fast_m1": 9965.0,
        "ema_slow_m1": 9960.0,
        "atr": 2.5,
        "dir_rule": 1,
        "is_spike_mode": False
    }
    
    try:
        print(f"Testing AI server at {url}")
        print(f"Payload: {json.dumps(payload, indent=2)}")
        
        response = requests.post(url, json=payload, timeout=5)
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        
        return response.status_code == 200
        
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    test_ai_server()
