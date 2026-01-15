import random
import time
import schedule
from backend.mt5_connector import get_all_symbols
from backend.trend_summary import get_multi_timeframe_trend
from backend.whatsapp_utils import send_whatsapp_message

def send_trend_batch():
    symbols = get_all_symbols()
    if len(symbols) < 10:
        selected = symbols
    else:
        selected = random.sample(symbols, 10)
    for symbol in selected:
        trend_data = get_multi_timeframe_trend(symbol)
        tf_order = ["1d", "8h", "6h", "4h", "1h", "30m", "15m", "5m", "1m"]
        tf_labels = ["D1", "H8", "H6", "H4", "H1", "M30", "M15", "M5", "M1"]
        lines = [f"📊 Tendance consolidée pour {symbol}"]
        for tf, label in zip(tf_order, tf_labels):
            tf_info = trend_data["trends"].get(tf, {})
            trend = tf_info.get("trend", "?")
            force = tf_info.get("force", "?")
            try:
                force_pct = f"{int(force)}%" if force != "?" else "?"
            except:
                force_pct = "?"
            lines.append(f"{label} : {trend} ({force_pct})")
        lines.append(f"Synthèse : {trend_data.get('consolidated', '?')} | Scalping possible : {trend_data.get('scalping_possible', '?')}")
        msg = "\n".join(lines)
        send_whatsapp_message(msg)
        time.sleep(2)  # Pour éviter le flood Twilio

def main():
    print("[BatchTrend] Démarrage de l'envoi automatique des tendances consolidées...")
    send_trend_batch()  # Premier envoi immédiat
    schedule.every(10).minutes.do(send_trend_batch)
    while True:
        schedule.run_pending()
        time.sleep(1)

if __name__ == "__main__":
    main() 