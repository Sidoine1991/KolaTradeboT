
import pandas as pd
import numpy as np
import sys
import os
from pathlib import Path

# Add python directory to path
sys.path.insert(0, str(Path(__file__).parent / "python"))
from ai_indicators import AdvancedIndicators

def test_rsi_accuracy():
    # Sample data
    data = [100, 101, 102, 101, 100, 99, 98, 99, 101, 103, 105, 104, 103, 102, 101, 100, 102, 104, 106, 105]
    df = pd.DataFrame(data, columns=['close'])
    df['high'] = df['close'] + 0.5
    df['low'] = df['close'] - 0.5
    df['open'] = df['close']
    df['volume'] = 1000
    df['time'] = pd.to_datetime(range(len(df)), unit='m')
    
    analyzer = AdvancedIndicators("TEST", "M1")
    sentiment = analyzer.calculate_market_sentiment(df)
    
    rsi = sentiment.get('rsi')
    print(f"Calculated RSI: {rsi}")
    
    # Standard RSI for this data (period 14)
    # prices are: 100, 101, 102, 101, 100, 99, 98, 99, 101, 103, 105, 104, 103, 102, 101, 100, 102, 104, 106, 105
    # Last 5 values from test_rsi_discrepancy.py (Wilder's):
    # 15    45.422893
    # 16    54.147051
    # 17    60.881206
    # 18    66.223366
    # 19    61.687276
    
    expected_rsi = 61.687276
    diff = abs(rsi - expected_rsi)
    
    if diff < 0.001:
        print("✅ RSI Calculation Verified (Wilder's Smoothing)")
    else:
        print(f"❌ RSI Discrepancy: Expected ~{expected_rsi}, Got {rsi}")

if __name__ == "__main__":
    test_rsi_accuracy()
