import os
import sys
import requests
import pandas as pd
import MetaTrader5 as mt
import logging

# Configuration
RENDER_URL = "https://kolatradebot.onrender.com/ml/train"
SYMBOLS = ["Volatility 75 Index", "Boom 300 Index", "Crash 300 Index"]
TIMEFRAMES = ["M1", "M5"]
PERIOD_BARS = 2000 # Nombre de barres à envoyer pour l'entraînement

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("cloud_sync")

def sync_to_cloud():
    if not mt.initialize():
        logger.error("MT5 initialization failed")
        return

    for symbol in SYMBOLS:
        for tf_str in TIMEFRAMES:
            logger.info(f"Syncing {symbol} ({tf_str}) to cloud...")
            
            tf = mt.TIMEFRAME_M1 if tf_str == "M1" else mt.TIMEFRAME_M5
            rates = mt.copy_rates_from_pos(symbol, tf, 0, PERIOD_BARS)
            
            if rates is None or len(rates) < 100:
                logger.warning(f"Not enough data for {symbol} ({tf_str})")
                continue
                
            # Convert to list of dicts for JSON serialization
            df = pd.DataFrame(rates)
            # Ensure types are JSON serializable
            data_to_send = df.to_dict(orient='records')
            
            payload = {
                "symbol": symbol,
                "timeframe": tf_str,
                "data": data_to_send
            }
            
            try:
                # Use a long timeout as training can be slow
                response = requests.post(RENDER_URL, json=payload, timeout=120)
                if response.status_code == 200:
                    logger.info(f"Successfully triggered cloud training for {symbol} {tf_str}")
                    result = response.json()
                    logger.info(f"Metrics (Cloud): {result.get('metrics', {})}")
                else:
                    logger.error(f"Cloud training failed: {response.text}")
            except Exception as e:
                logger.error(f"Request error: {e}")

    mt.shutdown()

if __name__ == "__main__":
    sync_to_cloud()
