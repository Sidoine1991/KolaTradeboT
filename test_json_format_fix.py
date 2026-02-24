#!/usr/bin/env python3
"""
Test script to verify the JSON format fixes for AI server decision endpoint
"""

import requests
import json
from datetime import datetime

# Test data that matches the fixed format
test_data = {
    "symbol": "Boom 500 Index",
    "bid": 5297.889,
    "ask": 5298.282,
    "rsi": 44.74,
    "atr": 28.1215,
    "ema_fast_h1": 5297.5,
    "ema_slow_h1": 5298.0,
    "ema_fast_m1": 5297.6,
    "ema_slow_m1": 5297.9,
    "is_spike_mode": False,
    "dir_rule": 0,
    "supertrend_trend": 0,
    "volatility_regime": 0,
    "volatility_ratio": 1.0,
    "timestamp": datetime.now().isoformat()
}

def test_local_server():
    """Test the local AI server"""
    try:
        print("🧪 Testing local AI server...")
        response = requests.post(
            "http://localhost:8000/decision",
            json=test_data,
            timeout=5
        )
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Local server success!")
            print(f"Action: {result.get('action', 'unknown')}")
            print(f"Confidence: {result.get('confidence', 0):.2f}")
            return True
        else:
            print(f"❌ Local server error: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print("⚠️ Local server not running - this is expected")
        return False
    except Exception as e:
        print(f"❌ Error testing local server: {e}")
        return False

def test_render_server():
    """Test the Render AI server"""
    try:
        print("\n🧪 Testing Render AI server...")
        response = requests.post(
            "https://kolatradebot.onrender.com/decision",
            json=test_data,
            timeout=10
        )
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Render server success!")
            print(f"Action: {result.get('action', 'unknown')}")
            print(f"Confidence: {result.get('confidence', 0):.2f}")
            return True
        else:
            print(f"❌ Render server error: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error testing Render server: {e}")
        return False

def main():
    print("=" * 60)
    print("🔧 JSON FORMAT FIX VERIFICATION")
    print("=" * 60)
    
    print("\n📋 Test Data:")
    print(json.dumps(test_data, indent=2))
    
    local_success = test_local_server()
    render_success = test_render_server()
    
    print("\n" + "=" * 60)
    print("📊 SUMMARY")
    print("=" * 60)
    print(f"Local Server: {'✅ PASS' if local_success else '❌ FAIL / N/A'}")
    print(f"Render Server: {'✅ PASS' if render_success else '❌ FAIL'}")
    
    if render_success:
        print("\n🎉 JSON format fix verified successfully!")
        print("The MT5 expert advisors should now work correctly.")
    else:
        print("\n⚠️ Issues still exist. Check the error messages above.")

if __name__ == "__main__":
    main()
