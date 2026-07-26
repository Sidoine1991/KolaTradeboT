"""
Fetch M1 history from MT5 for all Weltrade synthetics.
Output: CSV files per symbol in Modele_spike/data/
"""
import os
import time
import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime

SYMBOLS = [
    "PainX 400", "GainX 400", "PainX 600", "GainX 600",
    "PainX 800", "GainX 800", "PainX 999", "GainX 999",
    "PainX 1200", "GainX 1200",
    "FX Vol 20", "FX Vol 40", "FX Vol 60", "FX Vol 80", "FX Vol 99",
    "SFX Vol 20", "SFX Vol 40", "SFX Vol 60", "SFX Vol 80", "SFX Vol 99",
]

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "data")
os.makedirs(OUTPUT_DIR, exist_ok=True)

if not mt5.initialize():
    raise RuntimeError("MT5 initialize failed")

print(f"Connected: {mt5.terminal_info().name}")
print(f"Max bars: {mt5.terminal_info().maxbars}")

for name in SYMBOLS:
    safe_name = name.replace(" ", "_")
    out_path = os.path.join(OUTPUT_DIR, f"{safe_name}_M1.csv")
    if os.path.exists(out_path):
        size_kb = os.path.getsize(out_path) / 1024
        print(f"  {name}: cached ({size_kb:.0f} KB)")
        continue

    mt5.symbol_select(name, True)
    time.sleep(0.2)

    rates = mt5.copy_rates_from_pos(name, mt5.TIMEFRAME_M1, 0, 80000)
    if rates is None or len(rates) == 0:
        print(f"  {name}: NO DATA (err={mt5.last_error()})")
        continue

    df = pd.DataFrame(rates)
    df["time"] = pd.to_datetime(df["time"], unit="s")
    df = df[["time", "open", "high", "low", "close", "tick_volume", "spread", "real_volume"]]
    df.to_csv(out_path, index=False)

    t_start = df["time"].iloc[0]
    t_end = df["time"].iloc[-1]
    print(f"  {name}: {len(df)} bars, {t_start.date()} -> {t_end.date()}")
    time.sleep(1)

mt5.shutdown()
print(f"\nDone. All data in {OUTPUT_DIR}")
