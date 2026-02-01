#!/usr/bin/env python3
import requests
import json

# Test simple de l'endpoint
response = requests.post(
    "http://localhost:8000/ml/predict-signal",
    json={
        "symbol": "Boom 500 Index",
        "timeframe": "M1",
        "current_price": 5000
    },
    timeout=10
)

print(f"Status: {response.status_code}")
print(f"Response: {response.text}")

if response.status_code == 200:
    data = response.json()
    print(f"Signal: {data.get('signal')}")
    print(f"Confiance: {data.get('confidence')}")
    print(f"Source: {data.get('source')}")
else:
    print(f"Error: {response.status_code}")
