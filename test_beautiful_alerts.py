#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test beautiful formatted pullback alerts via WhatsApp
Uses the corrected format and existing PsychoBot endpoint
"""

import sys
import io
import requests
import time
from datetime import datetime
from pathlib import Path

# Import formatter BEFORE UTF-8 wrapper to avoid conflicts
sys.path.insert(0, str(Path(__file__).parent / "Python"))
from pullback_alert_formatter import PullbackAlertFormatter

# Configuration
PSYCHOBOT_URL = "https://psychobot-1si7.onrender.com/send-message"
OWNER_PHONE = "+2290196911346"

def send_formatted_alert(message: str) -> bool:
    """Send formatted message via WhatsApp"""
    payload = {
        "phone": OWNER_PHONE,
        "message": message,
        "source": "tradbot-pullback-beautiful"
    }

    try:
        print(f"\n[SEND] Envoi via {PSYCHOBOT_URL}")
        response = requests.post(PSYCHOBOT_URL, json=payload, timeout=10)

        if response.status_code == 200:
            print(f"[OK] Status 200 — Message envoyé!")
            return True
        else:
            print(f"[ERROR] Status {response.status_code}: {response.text[:100]}")
            return False

    except Exception as e:
        print(f"[ERROR] Exception: {e}")
        return False


def main():
    print("\n" + "="*80)
    print("TEST: BEAUTIFUL FORMATTED PULLBACK ALERTS VIA WHATSAPP")
    print("="*80)

    formatter = PullbackAlertFormatter()

    # Phase 1: Pullback Started
    print("\n[PHASE 1] PULLBACK STARTED...")
    msg1 = formatter.format_pullback_started(
        symbol="Boom 150 Index",
        direction="BUY",
        breakout_price=1456.23,
        pullback_min=0.5,
        pullback_max=1.5
    )
    print(msg1)
    result1 = send_formatted_alert(msg1)
    time.sleep(2)

    # Phase 2: Pullback Detected
    print("\n[PHASE 2] PULLBACK DETECTED...")
    msg2 = formatter.format_pullback_detected(
        symbol="Boom 150 Index",
        direction="BUY",
        pullback_pct=0.92,
        pullback_price=1452.11,
        breakout_price=1456.23
    )
    print(msg2)
    result2 = send_formatted_alert(msg2)
    time.sleep(2)

    # Phase 3: Resumption Confirmed
    print("\n[PHASE 3] RESUMPTION CONFIRMED...")
    msg3 = formatter.format_resumption_confirmed(
        symbol="Boom 150 Index",
        direction="BUY",
        entry_price=1453.45,
        sl=1451.95,
        tp=1455.20,
        lot=0.01,
        signals_detail="EMA Cross + Volume Spike (2/3)"
    )
    print(msg3)
    result3 = send_formatted_alert(msg3)
    time.sleep(2)

    # Phase 4: Trade Opened
    print("\n[PHASE 4] TRADE OPENED...")
    msg4 = formatter.format_trade_opened(
        symbol="Boom 150 Index",
        direction="BUY",
        entry_price=1453.45,
        sl=1451.95,
        tp=1455.20,
        lot=0.01,
        ticket=12345,
        risk_usd=0.48,
        reward_usd=0.53
    )
    print(msg4)
    result4 = send_formatted_alert(msg4)

    # Summary
    print("\n" + "="*80)
    print("TEST SUMMARY")
    print("="*80)

    results = [result1, result2, result3, result4]
    phases = ["PULLBACK STARTED", "PULLBACK DETECTED", "RESUMPTION CONFIRMED", "TRADE OPENED"]

    success_count = sum(results)
    total_count = len(results)

    print(f"\n✅ {success_count}/{total_count} alerts sent successfully!\n")

    for phase, result in zip(phases, results):
        status = "[OK]" if result else "[FAIL]"
        print(f"{status} {phase}")

    print("\nCheck your WhatsApp for beautiful formatted messages!")
    print("="*80)


if __name__ == "__main__":
    main()
