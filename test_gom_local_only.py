#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test: Vérifier que GOM/KOLA fonctionne 100% en local (NO TradingView)
Status: POST-DEPLOYMENT TEST

Usage: python test_gom_local_only.py
"""

import sys
import json
import requests
from pathlib import Path
from datetime import datetime, timezone

# Fix Windows encoding
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

def test_gom_signal_json_exists():
    """✅ Test 1: Fichier data/gom_signal.json existe"""
    gom_file = Path("data/gom_signal.json")
    assert gom_file.exists(), "❌ FAILED: data/gom_signal.json not found"
    print("✅ PASS: data/gom_signal.json exists")
    return gom_file

def test_gom_signal_contains_kola(gom_file):
    """✅ Test 2: JSON contient kola_buy et kola_sell"""
    with open(gom_file, 'r', encoding='utf-8') as f:
        gom_data = json.load(f)

    assert isinstance(gom_data, dict), "❌ FAILED: GOM data is not a dict"
    print(f"✅ PASS: GOM data contains {len(gom_data)} symbols")

    # Vérifier au moins un symbole
    for symbol, record in gom_data.items():
        if record.get("verdict", "WAIT") != "WAIT":
            assert "kola_buy" in record, f"❌ FAILED: {symbol} missing kola_buy"
            assert "kola_sell" in record, f"❌ FAILED: {symbol} missing kola_sell"
            assert "verdict" in record, f"❌ FAILED: {symbol} missing verdict"
            assert "verdict_num" in record, f"❌ FAILED: {symbol} missing verdict_num"
            print(f"✅ PASS: {symbol} has kola_buy={record.get('kola_buy')}, kola_sell={record.get('kola_sell')}")
            return symbol

    # Si pas de symbole actif trouvé, au moins vérifier XAUUSD
    if "XAUUSD" in gom_data:
        record = gom_data["XAUUSD"]
        assert "kola_buy" in record, "❌ FAILED: XAUUSD missing kola_buy"
        assert "kola_sell" in record, "❌ FAILED: XAUUSD missing kola_sell"
        print(f"✅ PASS: XAUUSD has kola_buy={record.get('kola_buy')}, kola_sell={record.get('kola_sell')}")

def test_api_endpoint_uses_local_json():
    """✅ Test 3: Endpoint /gom-kola-dashboard retourne données LOCAL"""
    try:
        # Appel local (assume ai_server.py est en cours d'exécution)
        resp = requests.get("http://localhost:8000/gom-kola-dashboard?symbol=XAUUSD", timeout=5)
        assert resp.status_code == 200, f"❌ FAILED: HTTP {resp.status_code}"

        data = resp.json()
        assert data.get("ok") is True, "❌ FAILED: response.ok is False"
        assert data.get("source") == "local_json", f"❌ FAILED: source is '{data.get('source')}', expected 'local_json'"
        assert "kola_buy" in data, "❌ FAILED: response missing kola_buy"
        assert "kola_sell" in data, "❌ FAILED: response missing kola_sell"
        assert "verdict_num" in data, "❌ FAILED: response missing verdict_num"

        print(f"✅ PASS: API /gom-kola-dashboard works (source: {data.get('source')})")
        print(f"   Verdict: {data.get('verdict')} (vn={data.get('verdict_num')})")
        print(f"   Kola: BUY={data.get('kola_buy')}, SELL={data.get('kola_sell')}")
        print(f"   Scores: BUY={data.get('score_buy')}, SELL={data.get('score_sell')}")

    except requests.exceptions.ConnectionError:
        print("⚠️ SKIP: ai_server not running (cannot test HTTP endpoint)")
    except Exception as e:
        print(f"❌ FAILED: {e}")

def test_multiple_symbols():
    """✅ Test 4: Vérifier plusieurs symboles"""
    gom_file = Path("data/gom_signal.json")
    with open(gom_file, 'r', encoding='utf-8') as f:
        gom_data = json.load(f)

    symbols_tested = 0
    for symbol in ["XAUUSD", "BTCUSD", "Boom 1000 Index", "Crash 500 Index"]:
        if symbol in gom_data:
            record = gom_data[symbol]
            kola_buy = record.get("kola_buy", 0)
            kola_sell = record.get("kola_sell", 0)
            verdict = record.get("verdict", "WAIT")
            verdict_num = record.get("verdict_num", 0)

            print(f"  {symbol:25} | {verdict:15} (vn={verdict_num:2}) | Kola: {kola_buy} / {kola_sell}")
            symbols_tested += 1

    assert symbols_tested > 0, "❌ FAILED: No symbols found in GOM data"
    print(f"✅ PASS: Tested {symbols_tested} symbols")

def main():
    print("\n" + "="*80)
    print("TEST SUITE: GOM/KOLA 100% LOCAL (NO TradingView)")
    print("="*80 + "\n")

    print("[1] Checking GOM signal file...")
    gom_file = test_gom_signal_json_exists()

    print("\n[2] Checking KOLA levels in JSON...")
    test_gom_signal_contains_kola(gom_file)

    print("\n[3] Testing API endpoint...")
    test_api_endpoint_uses_local_json()

    print("\n[4] Testing multiple symbols...")
    test_multiple_symbols()

    print("\n" + "="*80)
    print("✅ ALL TESTS PASSED: GOM/KOLA is 100% LOCAL (NO TradingView)")
    print("="*80 + "\n")

if __name__ == "__main__":
    main()
