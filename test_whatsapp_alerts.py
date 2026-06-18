#!/usr/bin/env python3
"""
Test script for WhatsApp alerts via PsychoBot
Tests all 4 alert phases: Pullback Start, Pullback Detected, Resumption, Trade Opened
"""

import requests
import json
import sys
import time
from datetime import datetime
from typing import Dict, Optional
import io

# UTF-8 wrapper for Windows console
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Configuration
PSYCHOBOT_RENDER = "https://psychobot-1si7.onrender.com"
PSYCHOBOT_LOCAL = "http://localhost:3000"
OWNER_PHONE = "+2290196911346"
ALERT_TIMEOUT = 5000  # ms

class WhatsAppAlertTester:
    def __init__(self, phone: str):
        self.phone = phone
        self.session = requests.Session()
        self.session.headers.update({'Content-Type': 'application/json'})
        self.endpoints = [
            f"{PSYCHOBOT_RENDER}/send-message",  # Primary: Render cloud
            f"{PSYCHOBOT_LOCAL}/send-message"     # Fallback: local
        ]

    def send_alert(self, message: str, retry_count: int = 3) -> Dict:
        """Send WhatsApp alert with retry logic"""
        payload = {
            "phone": self.phone,
            "message": message,
            "source": "tradbot-pullback-scanner"
        }

        for endpoint_idx, endpoint in enumerate(self.endpoints):
            print(f"\n[TEST] Trying endpoint {endpoint_idx + 1}/{len(self.endpoints)}: {endpoint}")

            for attempt in range(1, retry_count + 1):
                try:
                    print(f"  Attempt {attempt}/{retry_count}")
                    print(f"  Phone: {self.phone}")
                    print(f"  Message: {message[:70]}...")

                    response = self.session.post(
                        endpoint,
                        json=payload,
                        timeout=ALERT_TIMEOUT / 1000
                    )

                    print(f"  Status: {response.status_code}")
                    print(f"  Response: {response.text[:150]}")

                    if response.status_code in [200, 201]:
                        print(f"[OK] Alert sent successfully via {endpoint}!")
                        return {"success": True, "status": response.status_code, "endpoint": endpoint, "response": response.text}
                    else:
                        print(f"  [WARN] Status {response.status_code} — trying next endpoint or retry...")

                except requests.exceptions.Timeout:
                    print(f"  [RETRY] Timeout — backoff {attempt}s...")
                    time.sleep(attempt)
                except requests.exceptions.ConnectionError:
                    print(f"  [RETRY] Connection failed — trying next endpoint...")
                    break  # Try next endpoint
                except Exception as e:
                    print(f"  [ERROR] Failed: {str(e)}")
                    break  # Try next endpoint

        print(f"[FAILED] All endpoints/attempts exhausted!")
        return {"success": False, "endpoints": len(self.endpoints)}

def run_test_sequence():
    """Run complete test sequence for all 4 alert phases"""
    tester = WhatsAppAlertTester(OWNER_PHONE)

    print("=" * 80)
    print("WHATSAPP ALERT TEST SEQUENCE - Pullback Entry System")
    print("=" * 80)

    # Phase 1: Pullback Started
    print("\n[PHASE 1] Testing PULLBACK STARTED alert...")
    msg1 = """[PULLBACK] Boom 150 Index
Direction: BUY
Breakout: 1456.23
Waiting for pullback (0.5-1.5%)...
Time: 2026-06-17 14:20:05 UTC"""

    result1 = tester.send_alert(msg1)
    time.sleep(2)

    # Phase 2: Pullback Detected
    print("\n[PHASE 2] Testing PULLBACK DETECTED alert...")
    msg2 = """[PULLBACK DETECTED] Boom 150 Index
Pullback: 0.92%
Low: 1452.11
Waiting for resumption signal...
Time: 2026-06-17 14:23:12 UTC"""

    result2 = tester.send_alert(msg2)
    time.sleep(2)

    # Phase 3: Resumption Confirmed
    print("\n[PHASE 3] Testing RESUMPTION CONFIRMED alert...")
    msg3 = """[SIGNAL GO] Boom 150 Index
BUY @ 1453.45
SL: 1451.95 | TP: 1455.20
Lot: 0.01
Signals: EMA Cross + Volume Spike (2/3)
Time: 2026-06-17 14:25:33 UTC"""

    result3 = tester.send_alert(msg3)
    time.sleep(2)

    # Phase 4: Trade Opened
    print("\n[PHASE 4] Testing TRADE OPENED alert...")
    msg4 = """[TRADE OPENED] Boom 150 Index
BUY @ 1453.45 | SL: 1451.95 | TP: 1455.20
Lot: 0.01 | Ticket: #12345
Risk: $0.48 | Reward: $0.53
Time: 2026-06-17 14:25:35 UTC"""

    result4 = tester.send_alert(msg4)

    # Summary
    print("\n" + "=" * 80)
    print("TEST SUMMARY")
    print("=" * 80)

    results = [result1, result2, result3, result4]
    phases = ["PULLBACK STARTED", "PULLBACK DETECTED", "RESUMPTION CONFIRMED", "TRADE OPENED"]

    success_count = sum(1 for r in results if r.get("success", False))
    total_count = len(results)

    print(f"\nPhases tested: {total_count}")
    print(f"Successful: {success_count}/{total_count}")

    for phase, result in zip(phases, results):
        status = "[OK]" if result.get("success") else "[FAIL]"
        print(f"{status} {phase}")

    if success_count == total_count:
        print("\n[SUCCESS] All alerts sent successfully! Check WhatsApp.")
    else:
        print(f"\n[PARTIAL] {success_count}/{total_count} alerts sent. Check logs above.")

    print("\n" + "=" * 80)

if __name__ == "__main__":
    print(f"\nStarting WhatsApp Alert Test at {datetime.now().isoformat()}")
    print(f"PsychoBot Endpoints:")
    print(f"  1. {PSYCHOBOT_RENDER}/send-message (primary)")
    print(f"  2. {PSYCHOBOT_LOCAL}/send-message (fallback)")
    print(f"Owner Phone: {OWNER_PHONE}")
    print(f"Timeout: {ALERT_TIMEOUT}ms")

    run_test_sequence()

    print(f"\nTest completed at {datetime.now().isoformat()}")
