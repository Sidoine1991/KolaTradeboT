#!/usr/bin/env python3
"""
Test script for TradingView webhook integration
Sends test signals to verify end-to-end connectivity
"""

import requests
import json
import sys
from datetime import datetime
from typing import Dict, Any

# Configuration
DEFAULT_SERVER = "http://localhost:8000"
WEBHOOK_ENDPOINT = "/webhook/tradingview"
TEST_ENDPOINT = "/webhook/tradingview/test"


def send_signal(server_url: str, signal: Dict[str, Any]) -> Dict[str, Any]:
    """Send a trading signal to the webhook"""
    url = f"{server_url}{WEBHOOK_ENDPOINT}"
    headers = {"Content-Type": "application/json"}

    try:
        print(f"\n📤 Sending signal to {url}")
        print(f"   Payload: {json.dumps(signal, indent=2)}")

        response = requests.post(url, json=signal, headers=headers, timeout=10)
        response.raise_for_status()

        result = response.json()
        print(f"✅ Response: {response.status_code}")
        print(f"   Result: {json.dumps(result, indent=2)}")
        return result

    except requests.exceptions.ConnectionError:
        print(f"❌ Connection error: Cannot reach {server_url}")
        print(f"   Make sure AI server is running: python ai_server.py")
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        print(f"❌ HTTP error: {e.response.status_code}")
        print(f"   Response: {e.response.text}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


def test_connectivity(server_url: str) -> bool:
    """Test if server is reachable"""
    try:
        response = requests.get(f"{server_url}/health", timeout=5)
        if response.status_code == 200:
            print(f"✅ Server is alive: {server_url}")
            return True
    except Exception:
        pass

    print(f"❌ Server not responding: {server_url}")
    return False


def run_test_suite(server_url: str):
    """Run a complete test suite"""
    print("=" * 60)
    print("TradBOT TradingView Webhook Test Suite")
    print("=" * 60)

    # Test 1: Connectivity
    print("\n[Test 1/5] Server Connectivity")
    if not test_connectivity(server_url):
        print("Cannot proceed without server connectivity")
        sys.exit(1)

    # Test 2: Built-in test endpoint
    print("\n[Test 2/5] Built-in Test Endpoint")
    try:
        response = requests.get(f"{server_url}{TEST_ENDPOINT}", timeout=10)
        if response.status_code == 200:
            print("✅ Test endpoint works")
            result = response.json()
            print(f"   Sample signal processed: {result.get('decision', {}).get('status')}")
        else:
            print(f"❌ Test endpoint failed: {response.status_code}")
    except Exception as e:
        print(f"❌ Test endpoint error: {e}")

    # Test 3: Simple BUY signal
    print("\n[Test 3/5] Simple BUY Signal")
    buy_signal = {
        "symbol": "EURUSD",
        "timeframe": "M5",
        "action": "BUY",
        "confidence": 0.85,
    }
    result = send_signal(server_url, buy_signal)
    if result.get("status") == "SUCCESS":
        print(f"   ✓ Verdict: {result.get('decision', {}).get('status')}")

    # Test 4: Complete signal with SL/TP
    print("\n[Test 4/5] Complete Signal with Stop/Target")
    complete_signal = {
        "symbol": "GBPUSD",
        "timeframe": "M15",
        "action": "SELL",
        "confidence": 0.90,
        "price": 1.2645,
        "stop_loss": 1.2700,
        "take_profit": 1.2550,
        "reason": "FVG Breakout + OB Resistance"
    }
    result = send_signal(server_url, complete_signal)
    if result.get("status") == "SUCCESS":
        print(f"   ✓ Processing time: {result.get('processing_time_ms')}ms")

    # Test 5: CLOSE signal
    print("\n[Test 5/5] CLOSE Signal")
    close_signal = {
        "symbol": "EURUSD",
        "timeframe": "M5",
        "action": "CLOSE",
        "reason": "Target reached"
    }
    result = send_signal(server_url, close_signal)
    if result.get("status") == "SUCCESS":
        print(f"   ✓ Closed successfully")

    print("\n" + "=" * 60)
    print("✅ Test Suite Complete!")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Verify signals are logged in: curl http://localhost:8000/logs")
    print("2. Configure Pine Script with webhook URL")
    print("3. Set up alert in TradingView")
    print("4. Enable auto-trading in SMC_Universal.mq5")
    print("=" * 60)


def main():
    """Main entry point"""
    if len(sys.argv) > 1:
        server_url = sys.argv[1]
        if not server_url.startswith("http"):
            server_url = f"http://{server_url}"
    else:
        server_url = DEFAULT_SERVER

    # Interactive menu
    print("\nTradBOT Webhook Test Tool")
    print("1. Run full test suite")
    print("2. Send custom signal")
    print("3. Check server health")
    print("4. Exit")

    choice = input("\nSelect option (1-4): ").strip()

    if choice == "1":
        run_test_suite(server_url)
    elif choice == "2":
        print("\nEnter signal details:")
        symbol = input("Symbol (e.g., EURUSD): ").strip().upper()
        timeframe = input("Timeframe (M1/M5/M15/M30/H1/H4/D1): ").strip().upper()
        action = input("Action (BUY/SELL/CLOSE): ").strip().upper()
        confidence = float(input("Confidence (0-1, default 0.85): ").strip() or "0.85")

        signal = {
            "symbol": symbol,
            "timeframe": timeframe,
            "action": action,
            "confidence": confidence,
        }

        price = input("Price (optional): ").strip()
        if price:
            signal["price"] = float(price)

        sl = input("Stop Loss (optional): ").strip()
        if sl:
            signal["stop_loss"] = float(sl)

        tp = input("Take Profit (optional): ").strip()
        if tp:
            signal["take_profit"] = float(tp)

        reason = input("Reason (optional): ").strip()
        if reason:
            signal["reason"] = reason

        send_signal(server_url, signal)
    elif choice == "3":
        test_connectivity(server_url)
    else:
        print("Goodbye!")
        sys.exit(0)


if __name__ == "__main__":
    main()
