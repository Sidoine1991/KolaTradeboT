#!/usr/bin/env python3

import urllib.request
import urllib.parse
import json

def test_trend_endpoint():
    """Test the /trend endpoint that's causing 422 errors"""
    try:
        # Test GET request first
        url = "https://kolatradebot.onrender.com/trend"
        req = urllib.request.Request(url)
        
        with urllib.request.urlopen(req, timeout=10) as response:
            result = response.read().decode('utf-8')
            print(f"✅ Trend GET response: {result}")
            
    except Exception as e:
        print(f"❌ Trend GET error: {e}")
        
        # Try POST with symbol data
        try:
            data = {"symbol": "Boom 1000 Index"}
            json_data = json.dumps(data).encode('utf-8')
            
            req = urllib.request.Request(
                url,
                data=json_data,
                headers={'Content-Type': 'application/json'}
            )
            
            with urllib.request.urlopen(req, timeout=10) as response:
                result = response.read().decode('utf-8')
                print(f"✅ Trend POST response: {result}")
                
        except Exception as e2:
            print(f"❌ Trend POST error: {e2}")

def test_coherent_endpoint():
    """Test the /coherent-analysis endpoint that's causing 422 errors"""
    try:
        # Test GET request first
        url = "https://kolatradebot.onrender.com/coherent-analysis"
        req = urllib.request.Request(url)
        
        with urllib.request.urlopen(req, timeout=10) as response:
            result = response.read().decode('utf-8')
            print(f"✅ Coherent GET response: {result}")
            
    except Exception as e:
        print(f"❌ Coherent GET error: {e}")
        
        # Try POST with symbol data
        try:
            data = {"symbol": "Boom 1000 Index"}
            json_data = json.dumps(data).encode('utf-8')
            
            req = urllib.request.Request(
                url,
                data=json_data,
                headers={'Content-Type': 'application/json'}
            )
            
            with urllib.request.urlopen(req, timeout=10) as response:
                result = response.read().decode('utf-8')
                print(f"✅ Coherent POST response: {result}")
                
        except Exception as e2:
            print(f"❌ Coherent POST error: {e2}")

def test_trend_with_params():
    """Test trend endpoint with query parameters like MT5 does"""
    try:
        symbol = "Boom 1000 Index"
        safe_symbol = symbol.replace(" ", "%20")
        url = f"https://kolatradebot.onrender.com/trend?symbol={safe_symbol}&timeframe=M1"
        
        req = urllib.request.Request(url)
        
        with urllib.request.urlopen(req, timeout=10) as response:
            result = response.read().decode('utf-8')
            print(f"✅ Trend with params response: {result}")
            
    except Exception as e:
        print(f"❌ Trend with params error: {e}")

if __name__ == "__main__":
    print("🔍 Testing problematic endpoints...")
    
    print("\n1. Testing /trend endpoint:")
    test_trend_endpoint()
    
    print("\n2. Testing /coherent-analysis endpoint:")
    test_coherent_endpoint()
    
    print("\n3. Testing /trend with query parameters:")
    test_trend_with_params()
