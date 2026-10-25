import json
import time
from datetime import datetime, timedelta, timezone

import requests


def build_synthetic_m1_history(
    symbol: str,
    days: int = 20,
    start_price: float = 100.0,
    step: float = 0.1,
) -> dict:
    """
    Construit un payload compatible MT5HistoryUploadRequest pour tester /mt5/history-upload.
    Génère des bougies M1 synthétiques sur N jours en UTC.
    """
    now = datetime.now(timezone.utc).replace(second=0, microsecond=0)
    start = now - timedelta(days=days)

    data = []
    price = start_price
    current = start
    total_minutes = days * 24 * 60

    for i in range(total_minutes):
        # timestamp Unix (secondes) comme MT5_HistoryUploader
        ts = int(current.timestamp())

        # petite dérive pseudo‑aléatoire déterministe autour de step
        direction = 1 if (i % 2 == 0) else -1
        move = direction * step
        open_price = price
        close_price = price + move
        high_price = max(open_price, close_price) + step * 0.5
        low_price = min(open_price, close_price) - step * 0.5

        bar = {
            "time": ts,
            "open": round(open_price, 5),
            "high": round(high_price, 5),
            "low": round(low_price, 5),
            "close": round(close_price, 5),
            # tick_volume est optionnel côté backend, mais on le fournit pour coller au bridge MT5
            "tick_volume": 1_000 + (i % 500),
        }
        data.append(bar)

        price = close_price
        current += timedelta(minutes=1)

    return {
        "symbol": symbol,
        "timeframe": "M1",
        "data": data,
    }


def main():
    # URL de ton serveur AI (identique à API_URL dans MT5_HistoryUploader.mq5)
    base_url = "https://kolatradebot.onrender.com"
    endpoint = f"{base_url}/mt5/history-upload"

    symbol = "EURUSD"  # adapte si besoin
    lookback_days = 20

    payload = build_synthetic_m1_history(symbol=symbol, days=lookback_days)

    print(f"POST {endpoint} for {symbol} M1 with {len(payload['data'])} bars...")
    t0 = time.time()
    resp = requests.post(endpoint, json=payload, timeout=60)
    dt = time.time() - t0

    print(f"Status: {resp.status_code} in {dt:.2f}s")
    try:
        print("Response JSON:", json.dumps(resp.json(), indent=2, ensure_ascii=False))
    except Exception:
        print("Raw response text:", resp.text[:500])

    print(
        "\nSi la requête est OK (200), le backend devrait calculer le profil horaire "
        "et lancer des upserts Supabase sur `symbol_hour_profile` et `symbol_hour_status`."
    )
    print(
        "Vérifie ensuite dans Supabase par une requête du type:\n"
        "  select * from symbol_hour_profile where symbol = '{sym}' order by hour_utc;".format(
            sym=symbol
        )
    )


if __name__ == "__main__":
    main()

