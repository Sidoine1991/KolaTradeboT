import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import requests
import time
import schedule
import json
from datetime import datetime
from backend.whatsapp_utils import send_whatsapp_message

API_KEY = "CJFmHohSIYSrNGfTD8I7TDW_Zq2HMq9s"
# Exemples de symboles US (actions), Forex, Crypto
SYMBOLS = [
    ("AAPL", "stock"),
    ("MSFT", "stock"),
    ("TSLA", "stock"),
    ("EURUSD", "fx"),
    ("BTCUSD", "crypto"),
    ("ETHUSD", "crypto"),
]
THRESHOLDS = {
    "AAPL": 150.0,
    "MSFT": 300.0,
    "TSLA": 700.0,
    "EURUSD": 1.10,
    "BTCUSD": 30000.0,
    "ETHUSD": 2000.0,
}

def get_internal_trend(symbol):
    return "bullish" if symbol.endswith("USD") else "bearish"

def get_signal_confidence(symbol, price):
    return 0.85  # à remplacer par ta vraie logique

def get_order_type(symbol, price):
    trend = get_internal_trend(symbol)
    if trend == "bullish":
        return "Achat Marché", "🟢"
    elif trend == "bearish":
        return "Vente Marché", "🔴"
    else:
        return "Neutre", "🟡"

def get_tp_sl(price, trend):
    if trend == "bullish":
        tp = round(price * 1.01, 5)
        sl = round(price * 0.99, 5)
    elif trend == "bearish":
        tp = round(price * 0.99, 5)
        sl = round(price * 1.01, 5)
    else:
        tp = round(price * 1.005, 5)
        sl = round(price * 0.995, 5)
    return tp, sl

def get_justification(symbol, price):
    return "Alignement MTF + Confiance IA > 80%"

def calculate_lot(price, sl, tp):
    capital = 10.0
    max_risk = 4.0  # perte max
    max_gain = 30.0 # gain max
    risk_per_unit = abs(price - sl)
    if risk_per_unit == 0:
        return 0.01
    lot = max_risk / risk_per_unit
    gain_per_unit = abs(tp - price)
    if gain_per_unit > 0:
        lot_max_gain = max_gain / gain_per_unit
        lot = min(lot, lot_max_gain)
    lot = max(0.01, round(lot, 2))
    return lot

def fetch_last_price(symbol, asset_type):
    try:
        if asset_type == "crypto":
            binance_symbol = symbol.replace("USD", "USDT")
            try:
                url_binance = f"https://api.binance.com/api/v3/ticker/price?symbol={binance_symbol}"
                resp = requests.get(url_binance, timeout=5)
                data = resp.json()
                price = float(data['price'])
                print(f"[Binance] {symbol}: {price}")
                return price, "Binance"
            except Exception as e:
                print(f"Erreur Binance {symbol}: {e}")
            url = f"https://api.polygon.io/v1/last/crypto/{symbol[:-3]}/{symbol[-3:]}?apiKey={API_KEY}"
            resp = requests.get(url, timeout=10)
            data = resp.json()
            price = float(data['last']['price'])
            print(f"[Polygon.io] {symbol}: {price}")
            return price, "Polygon.io"
        elif asset_type == "stock":
            url = f"https://api.polygon.io/v2/last/trade/{symbol}?apiKey={API_KEY}"
            resp = requests.get(url, timeout=10)
            data = resp.json()
            price = float(data['results']['price'])
            return price, "Polygon.io"
        elif asset_type == "fx":
            url = f"https://api.polygon.io/v1/last/forex/{symbol[:3]}/{symbol[3:]}?apiKey={API_KEY}"
            resp = requests.get(url, timeout=10)
            data = resp.json()
            price = float(data['last']['price'])
            return price, "Polygon.io"
        else:
            return None, None
    except Exception as e:
        print(f"Erreur fetch_last_price {symbol}: {e}")
        return None, None

def is_signal_valid(symbol, price):
    threshold = THRESHOLDS.get(symbol, None)
    if threshold is None:
        return False
    trend = get_internal_trend(symbol)
    confidence = get_signal_confidence(symbol, price)
    return price > threshold and trend == "bullish" and confidence > 0.7

def is_market_open(symbol, asset_type):
    now = datetime.datetime.utcnow()
    weekday = now.weekday()  # 0 = lundi, 6 = dimanche
    if asset_type in ['stock', 'fx']:
        if weekday == 5 or weekday == 6:
            return False
        if weekday == 4 and now.hour >= 21:
            return False
        if weekday == 0 and now.hour < 21:
            return False
        return True
    return True

def fetch_and_notify_all():
    print("[Polygon.io] Vérification des signaux sur tous les symboles...")
    messages = []
    for symbol, asset_type in SYMBOLS:
        if not is_market_open(symbol, asset_type):
            print(f"Marché fermé pour {symbol}, pas de signal envoyé.")
            continue
        price, price_source = fetch_last_price(symbol, asset_type)
        if price is None:
            print(f"Aucun prix récupéré pour {symbol}.")
            continue
        print(f"Prix {symbol} {price_source} : {price}")
        if is_signal_valid(symbol, price):
            trend = get_internal_trend(symbol)
            confidence = get_signal_confidence(symbol, price)
            order_type, emoji = get_order_type(symbol, price)
            tp, sl = get_tp_sl(price, trend)
            lot = calculate_lot(price, sl, tp)
            duration = "15 min"
            justification = get_justification(symbol, price)
            now_utc = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S GMT')
            msg = (
                f"• {symbol} | {emoji} {order_type}\n"
                f"  Prix : {price} | Lot : {lot} | TP : {tp} | SL : {sl}\n"
                f"  Risque max : 4$ | Gain max : 30$\n"
                f"  Tendance : {trend.capitalize()} | Confiance : {confidence:.0%}\n"
                f"  Source : {price_source}\n"
                f"  Date/Heure : {now_utc}\n"
                f"  Durée : {duration}\n"
                f"  Justification : {justification}"
            )
            messages.append(msg)
        else:
            print(f"Signal non validé pour {symbol}.")
    if messages:
        full_msg = "📈 Signaux Polygon.io validés par TradBOT :\n\n" + "\n\n".join(messages) + "\n\n---\nEnvoyé par TradBOT 🚀"
        send_whatsapp_message(full_msg)
        print("Signaux groupés envoyés sur WhatsApp.")
        # Enregistrement dans le fichier pour l'onglet Streamlit
        try:
            with open("polygon_signals.json", "a", encoding="utf-8") as f:
                json.dump({
                    "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "message": full_msg
                }, f, ensure_ascii=False)
                f.write("\n")
        except Exception as e:
            print(f"Erreur écriture polygon_signals.json : {e}")
    else:
        print("Aucun signal validé à envoyer.")

# Scheduler : toutes les 5 minutes
schedule.every(5).minutes.do(fetch_and_notify_all)

if __name__ == "__main__":
    print("[Polygon.io] Démarrage du relais de signaux multi-symboles...")
    fetch_and_notify_all()  # Premier appel immédiat
    while True:
        schedule.run_pending()
        time.sleep(1) 