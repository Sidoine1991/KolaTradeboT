import requests
import json
import time

url = "http://localhost:8000/robot/predict_ohlc?symbol=Step%20Index&timeframe=M1&horizon=10"
try:
    r = requests.get(url, timeout=10)
    print(f"Status: {r.status_code}")
    data = r.json()
    print(f"Keys: {list(data.keys())}")
    if "candles" in data:
        print(f"Count: {len(data['candles'])}")
        for i, c in enumerate(data['candles'][:2]):
            print(f"Candle {i}: {c}")
except Exception as e:
    print(f"Error: {e}")
