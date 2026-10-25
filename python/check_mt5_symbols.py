#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check available symbols in MT5 terminal
"""

import sys
import subprocess

# Fix encoding for Windows console
if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

try:
    import MetaTrader5 as mt5
except ImportError:
    print("Installing MetaTrader5 package...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "MetaTrader5"])
    import MetaTrader5 as mt5

# Initialize MT5
if not mt5.initialize():
    print(f"ERROR: Failed to initialize MT5: {mt5.last_error()}")
    sys.exit(1)

print("=" * 60)
print("MT5 TERMINAL - AVAILABLE SYMBOLS")
print("=" * 60)

# Get all symbols
symbols = mt5.symbols_get()
print(f"\nTotal symbols available: {len(symbols)}")

# Filter for synthetics (Boom, Crash, Volatility, Jump, PainX, GainX)
synthetic_keywords = ["Boom", "Crash", "Volatility", "Jump", "Pain", "Gain"]
synthetic_symbols = []

for symbol in symbols:
    name = symbol.name
    for keyword in synthetic_keywords:
        if keyword in name:
            synthetic_symbols.append(name)
            break

print(f"\nSynthetic symbols found: {len(synthetic_symbols)}")
print("\n" + "=" * 60)
for sym in sorted(synthetic_symbols):
    print(sym)
print("=" * 60)

# Also show some forex symbols for comparison
forex_symbols = []
for symbol in symbols:
    name = symbol.name
    if "USD" in name and len(name) == 6:
        forex_symbols.append(name)

print(f"\nForex symbols (USD pairs): {len(forex_symbols[:20])}")
print("\n" + "=" * 60)
for sym in sorted(forex_symbols)[:20]:
    print(sym)
print("=" * 60)

mt5.shutdown()
