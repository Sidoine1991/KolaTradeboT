#!/usr/bin/env python3
"""Verify that GOM poller includes Weltrade symbols"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

print("\n" + "="*70)
print("GOM POLLER WELTRADE VERIFICATION")
print("="*70 + "\n")

# Check 1: master_gom_poller.py
print("[1] master_gom_poller.py symbols:")
with open(ROOT / "python" / "master_gom_poller.py", encoding="utf-8") as f:
    content = f.read()
    if "_DEFAULT_SYMBOLS" in content:
        # Extract the list
        start = content.find("_DEFAULT_SYMBOLS: List[str] = [")
        end = content.find("]", start) + 1
        symbols_section = content[start:end]
        print(symbols_section[:500])

    worldtrade_symbols = ["PAINX", "GAINX", "FXVOL"]
    found = all(sym in content for sym in worldtrade_symbols)
    print(f"\n  ✅ Weltrade symbols found: {found}")
    for sym in worldtrade_symbols:
        status = "✅" if sym in content else "❌"
        print(f"    {status} {sym}")

# Check 2: gom_mt5_poller.py
print("\n[2] gom_mt5_poller.py symbols:")
with open(ROOT / "python" / "gom_mt5_poller.py", encoding="utf-8") as f:
    content = f.read()
    worldtrade_symbols = ["PAINX", "GAINX", "FXVOL"]
    found = all(sym in content for sym in worldtrade_symbols)
    print(f"  ✅ Weltrade symbols found: {found}")
    for sym in worldtrade_symbols:
        status = "✅" if sym in content else "❌"
        print(f"    {status} {sym}")

# Check 3: gom_multiterminal_poller.py
print("\n[3] gom_multiterminal_poller.py (NEW):")
poller_path = ROOT / "python" / "gom_multiterminal_poller.py"
if poller_path.exists():
    print("  ✅ File exists")
    with open(poller_path, encoding="utf-8") as f:
        content = f.read()
        if "weltrade" in content.lower() and "PAINX" in content:
            print("  ✅ Weltrade support configured")
        else:
            print("  ❌ Weltrade support missing")
else:
    print("  ❌ File not found")

# Summary
print("\n" + "="*70)
print("VERIFICATION SUMMARY")
print("="*70)
print("""
To enable Weltrade symbol polling:

1. Use master_gom_poller.py:
   python python/master_gom_poller.py
   → Polls both Deriv and Weltrade symbols via TradingView CDP

2. Use gom_mt5_poller.py (needs both terminals open):
   python python/gom_mt5_poller.py
   → Polls only the default Deriv terminal

3. Use NEW multi-terminal poller (RECOMMENDED):
   python python/gom_multiterminal_poller.py
   → Polls BOTH Deriv and Weltrade terminals directly
   → Requires both MT5 terminals running

RECOMMENDATION:
  Use gom_multiterminal_poller.py for Weltrade support!
  It connects to both terminals and fetches Weltrade symbols.
""")

print("\n")
