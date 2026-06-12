#!/usr/bin/env python3
"""Test spike anticipation integration in ai_server endpoint"""

import requests
import json
import time
import subprocess
import sys
from pathlib import Path
import random

# Force UTF-8 output on Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Start ai_server in background
print("Starting ai_server...")
ai_process = subprocess.Popen(
    [sys.executable, "ai_server.py"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True
)

# Wait for server to start
time.sleep(3)

try:
    # Test 1: PERFECT signal with high RSI (should anticipate)
    print("\n" + "="*70)
    print("TEST 1: PERFECT signal with spike anticipation")
    print("="*70)
    
    sym1 = f"GOLD_PERFECT_{random.randint(1000,9999)}"
    
    payload = {
        "symbol": sym1,
        "action": "BUY",
        "entry_price": 4216.45,
        "stop_loss": 4200.00,
        "take_profit": 4240.00,
        "lot": 0.1,
        "execution_type": "limit",
        "confidence": 0.85,
        "source": "test",
        "reasoning": "Test spike anticipation",
        "gom_verdict": "PERFECT BUY",
        "gom_score_buy": 0.95,
        "gom_score_sell": 0.05,
        "rsi": 75.0,
        "volatility_regime": 1,
    }
    
    response = requests.post("http://127.0.0.1:8000/pending-order", json=payload, timeout=5)
    
    if response.status_code == 200:
        result = response.json()
        print(f"Status: {response.status_code}")
        print(f"Response keys: {list(result.keys())}")
        
        # Check if spike anticipation was applied
        if result.get("spike_anticipation_applied"):
            print(f"\n[OK] SPIKE ANTICIPATION APPLIED!")
            print(f"   Distance: {result.get('anticipation_distance_pips'):.1f} pips")
            print(f"   Original entry: {payload['entry_price']}")
            print(f"   Anticipated entry: {result.get('entry_price')}")
            print(f"   Original SL: {payload['stop_loss']}")
            print(f"   Anticipated SL: {result.get('stop_loss')}")
            print(f"   Original TP: {payload['take_profit']}")
            print(f"   Anticipated TP: {result.get('take_profit')}")
        else:
            print(f"\n[INFO] No spike anticipation applied")
            if "spike_anticipation_applied" in result:
                print(f"   spike_anticipation_applied = {result.get('spike_anticipation_applied')}")
    else:
        print(f"ERROR: HTTP {response.status_code}")
        print(response.text)
    
    # Test 2: GOOD signal (should not anticipate without high volatility)
    print("\n" + "="*70)
    print("TEST 2: GOOD signal without spike anticipation")
    print("="*70)
    
    sym2 = f"EUR_GOOD_{random.randint(1000,9999)}"
    
    payload2 = {
        "symbol": sym2,
        "action": "SELL",
        "entry_price": 1.0950,
        "stop_loss": 1.0970,
        "take_profit": 1.0920,
        "lot": 0.1,
        "execution_type": "limit",
        "confidence": 0.75,
        "source": "test",
        "reasoning": "Test GOOD signal",
        "gom_verdict": "GOOD SELL",
        "gom_score_buy": 0.30,
        "gom_score_sell": 0.70,
        "rsi": 50.0,
        "volatility_regime": 0,
    }
    
    response2 = requests.post("http://127.0.0.1:8000/pending-order", json=payload2, timeout=5)
    
    if response2.status_code == 200:
        result2 = response2.json()
        print(f"Status: {response2.status_code}")
        print(f"Response keys: {list(result2.keys())}")
        
        if result2.get("spike_anticipation_applied"):
            print(f"\n[WARN] Spike anticipation unexpectedly applied for GOOD signal")
            print(f"   Distance: {result2.get('anticipation_distance_pips'):.1f} pips")
        else:
            print(f"\n[OK] Correctly NO spike anticipation (low volatility, GOOD signal)")
            print(f"   spike_anticipation_applied = {result2.get('spike_anticipation_applied')}")
    else:
        print(f"ERROR: HTTP {response2.status_code}")
        print(response2.text)
    
    print("\n" + "="*70)
    print("TESTS COMPLETE")
    print("="*70)

finally:
    # Stop ai_server
    print("\nShutting down ai_server...")
    ai_process.terminate()
    try:
        ai_process.wait(timeout=5)
    except:
        ai_process.kill()
    print("Done!")

