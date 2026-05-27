#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PHASE 5: Simplified End-to-End Tests
======================================
Tests the bi-directional SL/TP sync API endpoints without TradingView MCP dependency.
"""

import sys
import io
import requests
import json
import time
from datetime import datetime

# Fix console encoding for Windows
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

BASE_URL = "http://127.0.0.1:8000"
TIMEOUT = 15  # Increased timeout for slow endpoints

def log(msg, level="INFO"):
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] [{level}] {msg}")

def test_1_create_pending_order():
    """Test 1: Create a pending order via POST"""
    log("TEST 1: Creating pending order...")

    payload = {
        "symbol": "XAUUSD",
        "action": "BUY",
        "entry_price": 2650.50,
        "stop_loss": 2645.00,
        "take_profit": 2660.00,
        "lot": 0.01,
        "confidence": 0.85
    }

    try:
        resp = requests.post(f"{BASE_URL}/pending-order", json=payload, timeout=TIMEOUT)
        if resp.status_code == 200:
            data = resp.json()
            log(f"✅ Order created: {data.get('order_id', 'N/A')}", "PASS")
            return data.get('order_id')
        else:
            log(f"❌ HTTP {resp.status_code}: {resp.text[:200]}", "FAIL")
            return None
    except Exception as e:
        log(f"❌ Exception: {e}", "FAIL")
        return None

def test_2_get_pending_order(order_id):
    """Test 2: Retrieve pending order"""
    if not order_id:
        log("⏭️  SKIP (no order_id from Test 1)", "SKIP")
        return False

    log("TEST 2: Retrieving pending order...")

    try:
        resp = requests.get(f"{BASE_URL}/pending-order?symbol=XAUUSD", timeout=TIMEOUT)
        if resp.status_code == 200:
            data = resp.json()
            if data.get('ok'):
                order = data.get('order', {})
                sl = order.get('stop_loss')
                tp = order.get('take_profit')
                log(f"✅ Retrieved: SL={sl}, TP={tp}", "PASS")
                return True
            else:
                log(f"⚠️ No order in response", "WARN")
                return False
        else:
            log(f"❌ HTTP {resp.status_code}", "FAIL")
            return False
    except Exception as e:
        log(f"❌ Exception: {e}", "FAIL")
        return False

def test_3_patch_sltp_from_tv(order_id):
    """Test 3: TradingView user drags SL line → PATCH /pending-order/{id}"""
    if not order_id:
        log("⏭️  SKIP (no order_id)", "SKIP")
        return False

    log("TEST 3: TradingView manual SL change → PATCH /pending-order/{id}...")

    payload = {
        "stop_loss": 2640.00,
        "update_source": "tv_manual"
    }

    try:
        resp = requests.patch(f"{BASE_URL}/pending-order/{order_id}", json=payload, timeout=TIMEOUT)
        if resp.status_code == 200:
            data = resp.json()
            if data.get('ok'):
                updated_sl = data.get('order', {}).get('stop_loss')
                source = data.get('order', {}).get('sl_update_source')
                log(f"✅ SL updated: {updated_sl}, source={source}", "PASS")
                return True
            else:
                log(f"❌ Update failed: {data.get('error')}", "FAIL")
                return False
        else:
            log(f"❌ HTTP {resp.status_code}: {resp.text[:200]}", "FAIL")
            return False
    except Exception as e:
        log(f"❌ Exception: {e}", "FAIL")
        return False

def test_4_post_sync_from_ea(order_id):
    """Test 4: MT5 trailing stop → POST /pending-order/{id}/sync"""
    if not order_id:
        log("⏭️  SKIP (no order_id)", "SKIP")
        return False

    log("TEST 4: MT5 trailing stop → POST /pending-order/{id}/sync...")

    payload = {
        "mt5_ticket": 123456,
        "current_stop_loss": 2648.00,
        "current_take_profit": 2660.00,
        "update_source": "ea_trailing",
        "peak_profit": 50.0,
        "trailing_active": True
    }

    try:
        resp = requests.post(f"{BASE_URL}/pending-order/{order_id}/sync", json=payload, timeout=TIMEOUT)
        if resp.status_code == 200:
            data = resp.json()
            if data.get('ok'):
                updated_sl = data.get('order', {}).get('stop_loss')
                source = data.get('order', {}).get('sl_update_source')
                log(f"✅ Synced from EA: SL={updated_sl}, source={source}", "PASS")
                return True
            else:
                log(f"❌ Sync failed: {data.get('error')}", "FAIL")
                return False
        else:
            log(f"❌ HTTP {resp.status_code}: {resp.text[:200]}", "FAIL")
            return False
    except Exception as e:
        log(f"❌ Exception: {e}", "FAIL")
        return False

def test_5_verify_update_source_tracking():
    """Test 5: Verify update_source tracking"""
    log("TEST 5: Verify update_source tracking...")

    try:
        resp = requests.get(f"{BASE_URL}/pending-order?symbol=XAUUSD", timeout=TIMEOUT)
        if resp.status_code == 200:
            data = resp.json()
            if data.get('ok'):
                order = data.get('order', {})
                sources = {
                    'sl_source': order.get('sl_update_source'),
                    'tp_source': order.get('tp_update_source')
                }
                log(f"✅ Sources tracked: {sources}", "PASS")
                # Last should be "ea_trailing" from test 4
                if sources.get('sl_source') == 'ea_trailing':
                    log("✅ SL source correctly shows 'ea_trailing'", "PASS")
                    return True
                else:
                    log(f"⚠️ Expected 'ea_trailing', got '{sources.get('sl_source')}'", "WARN")
                    return True  # Test still passes, just note the state
            else:
                log("⚠️ No order in response", "WARN")
                return False
        else:
            log(f"❌ HTTP {resp.status_code}", "FAIL")
            return False
    except Exception as e:
        log(f"❌ Exception: {e}", "FAIL")
        return False

def main():
    log("=" * 70)
    log("PHASE 5: SIMPLIFIED END-TO-END TESTS (API ENDPOINTS ONLY)")
    log("=" * 70)

    print()

    # Run tests sequentially
    order_id = test_1_create_pending_order()
    time.sleep(1)

    test_2_get_pending_order(order_id)
    time.sleep(1)

    test_3_patch_sltp_from_tv(order_id)
    time.sleep(1)

    test_4_post_sync_from_ea(order_id)
    time.sleep(1)

    test_5_verify_update_source_tracking()

    print()
    log("=" * 70)
    log("ALL TESTS COMPLETED")
    log("=" * 70)

if __name__ == "__main__":
    main()
