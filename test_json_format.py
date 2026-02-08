#!/usr/bin/env python3
"""Test script to validate the JSON format being sent by MT5"""

import json
import requests
from pydantic import BaseModel, ValidationError

# Copy the exact DecisionRequest model from ai_server.py
class DecisionRequest(BaseModel):
    symbol: str
    bid: float
    ask: float
    rsi: float = 50.0
    ema_fast_h1: float = None
    ema_slow_h1: float = None
    ema_fast_m1: float = None
    ema_slow_m1: float = None
    atr: float = 0.0
    dir_rule: int = 0
    is_spike_mode: bool = False
    vwap: float = None
    vwap_distance: float = None
    above_vwap: bool = None
    supertrend_trend: int = 0
    supertrend_line: float = None
    volatility_regime: int = 0
    volatility_ratio: float = 1.0
    image_filename: str = None
    deriv_patterns: str = None
    deriv_patterns_bullish: int = None
    deriv_patterns_bearish: int = None
    deriv_patterns_confidence: float = None

# Test JSON examples from the logs
test_cases = [
    # From XAGUSD log
    '{"symbol":"XAGUSD","bid":76.35900,"ask":76.38900,"rsi":53.83,"atr":1.83729,"is_spike_mode":false,"dir_rule":0,"supertrend_trend":0,"volatility_regime":0,"volatility_ratio":1.0}',
    
    # From Boom 900 Index log  
    '{"symbol":"Boom 900 Index","bid":9117.56300,"ask":9118.06400,"rsi":43.06,"atr":29.83300,"is_spike_mode":false,"dir_rule":0,"supertrend_trend":0,"volatility_regime":0,"volatility_ratio":1.0}',
    
    # From XAUUSD log
    '{"symbol":"XAUUSD","bid":4946.08000,"ask":4946.24000,"rsi":61.45,"atr":41.75857,"is_spike_mode":false,"dir_rule":0,"supertrend_trend":0,"volatility_regime":0,"volatility_ratio":1.0}'
]

print("Testing JSON validation...")
for i, json_str in enumerate(test_cases):
    print(f"\n--- Test Case {i+1} ---")
    print(f"JSON: {json_str}")
    
    try:
        # Test JSON parsing
        data = json.loads(json_str)
        print("✅ JSON parsing: OK")
        
        # Test Pydantic validation
        request = DecisionRequest(**data)
        print("✅ Pydantic validation: OK")
        print(f"   Symbol: {request.symbol}")
        print(f"   Bid/Ask: {request.bid}/{request.ask}")
        print(f"   RSI: {request.rsi}")
        
    except json.JSONDecodeError as e:
        print(f"❌ JSON parsing failed: {e}")
    except ValidationError as e:
        print(f"❌ Pydantic validation failed: {e}")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")

print("\n" + "="*50)
print("Testing endpoint connectivity...")
for i, json_str in enumerate(test_cases):
    print(f"\n--- Endpoint Test {i+1} ---")
    
    try:
        response = requests.post(
            "http://localhost:8000/decision",
            data=json_str,
            headers={"Content-Type": "application/json"},
            timeout=5
        )
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            print("✅ Endpoint response: OK")
            print(f"Response: {response.json()}")
        else:
            print(f"❌ Endpoint error: {response.text}")
    except requests.exceptions.ConnectionError:
        print("❌ Connection refused - local server not running")
    except Exception as e:
        print(f"❌ Request error: {e}")
