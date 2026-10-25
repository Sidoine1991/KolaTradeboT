import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import requests
import time
import schedule
from backend.whatsapp_utils import send_whatsapp_message
import json
from datetime import datetime

API_KEY = "4EM6K09BZU52S9JD"
SYMBOLS = [
    ("EUR", "USD"),
    ("GBP", "USD"),
    ("USD", "JPY"),
    ("BTC", "USD"),
    ("ETH", "USD"),
    ("XAU", "USD"),
    ("AUD", "USD"),
    ("USD", "CAD"),
    ("USD", "CHF"),
    ("NZD", "USD"),
]
THRESHOLDS = {
    "EURUSD": 1.10,
    "GBPUSD": 1.25,
    "USDJPY": 150.0,
    "BTCUSD": 30000.0,
    "ETHUSD": 2000.0,
    "XAUUSD": 1900.0,
    "AUDUSD": 0.65,
    "USDCAD": 1.30,
    "USDCHF": 0.90,
    "NZDUSD": 0.60,
}

# Mock tendance interne et confiance (à remplacer par ta vraie logique)
def get_internal_trend(symbol):
    # Ex : retourne "bullish", "bearish" ou "neutral"
    return "bullish" if symbol.endswith("USD") else "bearish"

def get_signal_confidence(symbol, price):
    # Ex : retourne un float entre 0 et 1
    return 0.82  # à remplacer par ta vraie logique

def get_order_type(symbol, price):
    # Exemple : retourne "Achat Marché" ou "Vente Marché" selon la tendance
    trend = get_internal_trend(symbol)
    if trend == "bullish":
        return "Achat Marché", "🟢"
    elif trend == "bearish":
        return "Vente Marché", "🔴"
    else:
        return "Neutre", "🟡"

def get_tp_sl(price, trend):
    # Exemple : TP/SL à +/-1% du prix
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
    # À remplacer par ta vraie logique d'explication
    return "Alignement MTF + Confiance IA > 80%"

def calculate_lot(price, sl, tp, trend):
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

def fetch_last_price(from_currency, to_currency):
    try:
        # Forex et Crypto : déjà OK
        if (from_currency, to_currency) in [("BTC", "USD"), ("ETH", "USD")]:
            url = f"https://www.alphavantage.co/query?function=CURRENCY_EXCHANGE_RATE&from_currency={from_currency}&to_currency={to_currency}&apikey={API_KEY}"
            response = requests.get(url, timeout=10)
            data = response.json()
            last_price = float(data["Realtime Currency Exchange Rate"]["5. Exchange Rate"])
            return last_price, "Alpha Vantage"
        elif len(from_currency) == 3 and len(to_currency) == 3:
            url = f"https://www.alphavantage.co/query?function=CURRENCY_EXCHANGE_RATE&from_currency={from_currency}&to_currency={to_currency}&apikey={API_KEY}"
            response = requests.get(url, timeout=10)
            data = response.json()
            last_price = float(data["Realtime Currency Exchange Rate"]["5. Exchange Rate"])
            return last_price, "Alpha Vantage"
        else:
            symbol = from_currency
            url = f"https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol={symbol}&apikey={API_KEY}"
            response = requests.get(url, timeout=10)
            data = response.json()
            last_price = float(data["Global Quote"]["05. price"])
            return last_price, "Alpha Vantage"
    except Exception as e:
        print(f"Erreur récupération Alpha Vantage {from_currency}{to_currency} : {e}")
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
    print("[AlphaVantage] Vérification des signaux sur tous les symboles...")
    messages = []
    for from_currency, to_currency in SYMBOLS:
        symbol = f"{from_currency}{to_currency}"
        # Déterminer le type d'actif
        asset_type = 'fx' if len(from_currency) == 3 and len(to_currency) == 3 else 'stock'
        if not is_market_open(symbol, asset_type):
            print(f"Marché fermé pour {symbol}, pas de signal envoyé.")
            continue
        price, price_source = fetch_last_price(from_currency, to_currency)
        if price is None:
            print(f"Aucun prix récupéré pour {symbol}.")
            continue
        print(f"Prix {symbol} {price_source} : {price}")
        if is_signal_valid(symbol, price):
            trend = get_internal_trend(symbol)
            confidence = get_signal_confidence(symbol, price)
            order_type, emoji = get_order_type(symbol, price)
            tp, sl = get_tp_sl(price, trend)
            lot = calculate_lot(price, sl, tp, trend)
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
        full_msg = "📈 Signaux Alpha Vantage validés par TradBOT :\n\n" + "\n\n".join(messages) + "\n\n---\nEnvoyé par TradBOT 🚀"
        send_whatsapp_message(full_msg)
        print("Signaux groupés envoyés sur WhatsApp.")
        # Enregistrement dans le fichier pour l'onglet Streamlit
        try:
            with open("alpha_vantage_signals.json", "a", encoding="utf-8") as f:
                json.dump({
                    "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "message": full_msg
                }, f, ensure_ascii=False)
                f.write("\n")
        except Exception as e:
            print(f"Erreur écriture alpha_vantage_signals.json : {e}")
    else:
        print("Aucun signal validé à envoyer.")

# Scheduler : toutes les 5 minutes
schedule.every(5).minutes.do(fetch_and_notify_all)

if __name__ == "__main__":
    print("[AlphaVantage] Démarrage du relais de signaux multi-symboles...")
    fetch_and_notify_all()  # Premier appel immédiat
    while True:
        schedule.run_pending()
        time.sleep(1) 