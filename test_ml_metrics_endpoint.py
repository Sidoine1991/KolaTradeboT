#!/usr/bin/env python3
"""Test GET /ml/metrics directly. Run ai_server.py first (port 8000)."""
import urllib.request
import json
import sys

def main():
    base = "http://127.0.0.1:8000"
    url = f"{base}/ml/metrics?symbol=EURUSD&timeframe=M1"
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=10) as r:
            data = r.read().decode()
            obj = json.loads(data)
            print("GET /ml/metrics response (flat keys for MT5):")
            print(json.dumps(obj, indent=2))
            # Check expected flat keys
            for key in ("accuracy", "model_name", "total_samples", "status"):
                if key in obj:
                    print(f"  {key}: {obj[key]}")
                else:
                    print(f"  MISSING: {key}")
    except urllib.error.URLError as e:
        print(f"Error: {e}. Is ai_server.py running on port 8000?")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
