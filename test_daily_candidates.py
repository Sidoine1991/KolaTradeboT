#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test script for /symbols/daily-candidates endpoint"""

import sys
import io
import requests
import json

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def test_daily_candidates(ai_server_url="http://127.0.0.1:8000"):
    """Test the new /symbols/daily-candidates endpoint"""
    try:
        print("🔍 Testing /symbols/daily-candidates endpoint...")
        print(f"Server: {ai_server_url}\n")

        response = requests.get(
            f"{ai_server_url}/symbols/daily-candidates",
            timeout=60
        )

        if response.status_code == 200:
            data = response.json()
            candidates = data.get("candidates", [])
            scanned = data.get("scanned", 0)
            count = data.get("count", 0)

            print(f"✅ Endpoint responded successfully")
            print(f"   Scanned: {scanned} symbols")
            print(f"   Passed D1 filters: {count} candidates\n")

            if candidates:
                print("📊 Top 10 Candidates (sorted by category & ATR):")
                print("─" * 80)

                for i, candidate in enumerate(candidates[:10], 1):
                    sym = candidate.get("symbol", "N/A")
                    cat = candidate.get("category", "?").upper()
                    spread = candidate.get("spread", 0)
                    atr = candidate.get("atr_d1", 0)
                    trend = candidate.get("d1_trend_label", "?")

                    print(f"{i:2d}. {sym:15s} | {cat:10s} | Spread: {spread:6.1f} | ATR(D1): {atr:.6f} | D1: {trend}")

                print("─" * 80)

                # Group by category
                print("\n📈 Breakdown by Category:")
                by_cat = {}
                for c in candidates:
                    cat = c.get("category", "unknown")
                    by_cat[cat] = by_cat.get(cat, 0) + 1

                for cat, count in sorted(by_cat.items()):
                    print(f"   {cat.title():15s}: {count:3d} symbols")

                print("\n✅ Test PASSED")
                return True
            else:
                print("⚠️ No candidates passed filters (this could be normal if spreads are wide)")
                return True
        else:
            print(f"❌ Server returned {response.status_code}")
            print(f"Response: {response.text}")
            return False

    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to server. Is ai_server.py running?")
        print(f"   Try: python ai_server.py")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = test_daily_candidates()
    sys.exit(0 if success else 1)
