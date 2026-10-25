
import pandas as pd
import numpy as np

def current_rsi(prices, period=14):
    delta = prices.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss
    rsi = 100 - (100 / (1 + rs))
    return rsi

def standard_rsi(prices, period=14):
    delta = prices.diff()
    gain = (delta.where(delta > 0, 0))
    loss = (-delta.where(delta < 0, 0))
    
    # Wilder's Smoothing is equivalent to EMA with alpha = 1/period
    avg_gain = gain.ewm(alpha=1/period, min_periods=period, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1/period, min_periods=period, adjust=False).mean()
    
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    return rsi

# Sample data
data = [100, 101, 102, 101, 100, 99, 98, 99, 101, 103, 105, 104, 103, 102, 101, 100, 102, 104, 106, 105]
prices = pd.Series(data)

c_rsi = current_rsi(prices)
s_rsi = standard_rsi(prices)

print("Current RSI (last 5):")
print(c_rsi.tail())
print("\nStandard RSI (last 5):")
print(s_rsi.tail())
