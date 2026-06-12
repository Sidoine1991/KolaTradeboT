#!/usr/bin/env python3
import sys
import requests
import time
import subprocess
import random

if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Start server and capture all output
print("Starting ai_server...")
ai_process = subprocess.Popen(
    [sys.executable, "ai_server.py"],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    bufsize=1
)

time.sleep(3)

try:
    sym = f"LOGTEST_{random.randint(1000,9999)}"
    print(f"\nSending request for {sym}...")
    
    payload = {
        "symbol": sym,
        "action": "BUY",
        "entry_price": 4216.45,
        "stop_loss": 4200.00,
        "take_profit": 4240.00,
        "lot": 0.1,
        "execution_type": "limit",
        "confidence": 0.85,
        "source": "test",
        "reasoning": "Test",
        "gom_verdict": "PERFECT BUY",
        "gom_score_buy": 0.95,
        "gom_score_sell": 0.05,
        "rsi": 75.0,
        "volatility_regime": 1,
    }
    
    response = requests.post("http://127.0.0.1:8000/pending-order", json=payload, timeout=5)
    print(f"Response: {response.json()}")
    
finally:
    print("\nShutting down...")
    ai_process.terminate()
    
    # Read remaining logs
    time.sleep(0.5)
    
    print("\n=== AI SERVER LOGS ===")
    for line in ai_process.stdout:
        if "PendingOrder" in line or "RESPONSE" in line or "RETURNING" in line:
            print(line.rstrip())
    
    ai_process.wait(timeout=5)

