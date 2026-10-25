#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check historical data availability for specific symbols
"""

import sys
import subprocess
from datetime import datetime, timedelta

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
print("CHECKING HISTORICAL DATA AVAILABILITY")
print("=" * 60)

symbols = ["PainX 999", "GainX 999", "PainX 800", "GainX 800"]

for symbol in symbols:
    print(f"\n{symbol}:")
    
    # Try different timeframes
    timeframes = [
        ("M1", mt5.TIMEFRAME_M1),
        ("M5", mt5.TIMEFRAME_M5),
        ("H1", mt5.TIMEFRAME_H1),
    ]
    
    for tf_name, tf in timeframes:
        # Try last 30 days
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)
        
        rates = mt5.copy_rates_range(symbol, tf, start_date, end_date)
        
        if rates is not None and len(rates) > 0:
            print(f"  {tf_name}: {len(rates)} candles available (last 30 days)")
        else:
            print(f"  {tf_name}: No data")
    
    # Try to get the earliest available data
    try:
        rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, 1)
        if rates is not None and len(rates) > 0:
            print(f"  Latest candle: {datetime.fromtimestamp(rates[0]['time'])}")
    except:
        pass

print("\n" + "=" * 60)
print("NOTE: If no data is available, you may need to:")
print("1. Open MT5 terminal")
print("2. Go to History Center (F2)")
print("3. Download historical data for these symbols")
print("4. Or enable 'Download missing data' in MT5 settings")
print("=" * 60)

mt5.shutdown()
