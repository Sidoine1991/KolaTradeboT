#!/usr/bin/env python3

import urllib.request
import urllib.parse
import json

# Test data from logs
data = {
    "symbol": "Boom 1000 Index",
    "bid": 14721.7185,
    "ask": 14723.2984,
    "rsi": 50.00,
    "atr": 0.0000,
    "ema_fast_h1": 0.0000,
    "ema_slow_h1": 0.0000,
    "ema_fast_m1": 0.0000,
    "ema_slow_m1": 0.0000,
    "is_spike_mode": False,
    "dir_rule": 0,
    "supertrend_trend": 0,
    "volatility_regime": 0,
    "volatility_ratio": 1.0,
    "timestamp": "2026.02.14 12:47:44"
}

def test_local_server():
    try:
        url = "http://localhost:8000/decision"
        json_data = json.dumps(data).encode('utf-8')
        
        req = urllib.request.Request(
            url,
            data=json_data,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=5) as response:
            result = response.read().decode('utf-8')
            print(f"✅ Local server response: {result}")
            return True
            
    except Exception as e:
        print(f"❌ Local server error: {e}")
        return False

def test_remote_server():
    try:
        url = "https://kolatradebot.onrender.com/decision"
        json_data = json.dumps(data).encode('utf-8')
        
        req = urllib.request.Request(
            url,
            data=json_data,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=10) as response:
            result = response.read().decode('utf-8')
            print(f"✅ Remote server response: {result}")
            return True
            
    except Exception as e:
        print(f"❌ Remote server error: {e}")
        return False

if __name__ == "__main__":
    print("🔍 Testing AI server connections...")
    print("\n1. Testing local server:")
    test_local_server()
    
    print("\n2. Testing remote server:")
    test_remote_server()
