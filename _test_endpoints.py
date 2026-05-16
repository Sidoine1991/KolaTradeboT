"""Test local /decision et /analyze/ollama — lancer avec le serveur déjà actif."""
import json
import sys
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:8000"


def post(path: str, body: dict, timeout: int = 120) -> None:
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    print(f"\n=== POST {path} ===")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read().decode()
            print("Status:", r.status)
            data = json.loads(raw)
            print(json.dumps(data, indent=2, ensure_ascii=False))
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.reason)
        err_body = e.read().decode(errors="replace")
        print(err_body[:4000])
    except Exception as e:
        print("Error:", type(e).__name__, e)


def main() -> None:
    decision_body = {
        "symbol": "Volatility 100 Index",
        "bid": 525.50,
        "ask": 525.58,
        "rsi": 48.2,
        "ema_fast_m1": 526.0,
        "ema_slow_m1": 524.5,
        "ema_fast_m5": 526.2,
        "ema_slow_m5": 523.8,
        "ema_fast_h1": 527.0,
        "ema_slow_h1": 522.0,
        "atr": 2.5,
        "timestamp": "2026-05-09T20:00:00",
    }
    post("/decision", decision_body)

    ollama_body = {
        "symbol": "Volatility 100 Index",
        "timeframe": "M5",
        "bid": 525.50,
        "ask": 525.58,
        "rsi": 48.2,
        "ema_fast_m1": 526.0,
        "ema_slow_m1": 524.5,
        "ema_fast_m5": 526.2,
        "ema_slow_m5": 523.8,
        "ema_fast_h1": 527.0,
        "ema_slow_h1": 522.0,
        "atr": 2.5,
        "m5_buy_entry": 524.0,
        "m5_sell_entry": 528.0,
        "timestamp": "2026-05-09T20:00:00",
    }
    post("/analyze/ollama", ollama_body)


if __name__ == "__main__":
    main()
    sys.exit(0)
