import os
import sys
import pandas as pd
import numpy as np
import logging
import requests

# Configure logging to see what's happening
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("trigger_training")

# Set environment variables for ai_server
os.environ["DATABASE_URL"] = "postgresql://koladb_user:wYkUIyTb53vWEygkyia3YZiJNIdonmOt@dpg-d5nje68gjchc739d0dug-a.oregon-postgres.render.com/koladb_rurl"
# os.environ["MT5_AVAILABLE"] = "True" # We want it to try

# Configuration Render
RENDER_URL = "https://kolatradebot.onrender.com/ml/train"
PERIOD_BARS = 2000  # Nombre de barres à envoyer pour l'entraînement

# Add current directory to path
sys.path.append(os.getcwd())

try:
    import MetaTrader5 as mt5
    from ai_server import train_ml_models, ML_AVAILABLE
    import ai_server
    logger.info(f"ML_AVAILABLE: {ML_AVAILABLE}")
except Exception as e:
    logger.error(f"Error importing ai_server or MetaTrader5: {e}")
    sys.exit(1)

# Manually initialize MT5 if not done
if not mt5.initialize():
    logger.error("Failed to initialize MT5. Training requires historical data from MT5.")
    # sys.exit(1) # We can still try, maybe some data is cached? 
else:
    logger.info("MT5 initialized successfully.")
    ai_server.mt5_initialized = True # Force it for the module functions

symbols = [
    "Volatility 75 Index", 
    "Boom 300 Index", 
    "Crash 300 Index", 
    "Volatility 100 Index",
    "Step Index"
]

timeframes = ["M1", "M5"]

def sync_to_render(symbol: str, timeframe: str):
    """Synchronise l'entraînement avec le serveur Render"""
    try:
        logger.info(f"🔄 Synchronisation avec Render pour {symbol} ({timeframe})...")
        
        # Récupérer les données historiques depuis MT5
        tf = mt5.TIMEFRAME_M1 if timeframe == "M1" else mt5.TIMEFRAME_M5
        rates = mt5.copy_rates_from_pos(symbol, tf, 0, PERIOD_BARS)
        
        if rates is None or len(rates) < 100:
            logger.warning(f"⚠️ Pas assez de données pour {symbol} ({timeframe}) - Skip synchronisation")
            return False
            
        # Convertir en DataFrame puis en dict pour JSON
        df = pd.DataFrame(rates)
        data_to_send = df.to_dict(orient='records')
        
        payload = {
            "symbol": symbol,
            "timeframe": timeframe,
            "data": data_to_send
        }
        
        # Envoyer à Render avec timeout long (entraînement peut être lent)
        response = requests.post(RENDER_URL, json=payload, timeout=180)
        
        if response.status_code == 200:
            result = response.json()
            logger.info(f"✅ Synchronisation Render réussie pour {symbol} ({timeframe})")
            if 'metrics' in result:
                for model_name, metric in result['metrics'].items():
                    logger.info(f"   📊 {model_name}: Accuracy={metric.get('accuracy', 0):.4f}")
            return True
        else:
            logger.error(f"❌ Échec synchronisation Render: {response.status_code} - {response.text}")
            return False
            
    except requests.exceptions.Timeout:
        logger.error(f"⏱️ Timeout lors de la synchronisation Render pour {symbol} ({timeframe})")
        return False
    except Exception as e:
        logger.error(f"❌ Erreur synchronisation Render pour {symbol} ({timeframe}): {e}")
        return False

def trigger_training():
    """Entraîne les modèles localement ET synchronise avec Render"""
    for symbol in symbols:
        for tf in timeframes:
            logger.info(f"{'='*60}")
            logger.info(f"--- Entraînement pour {symbol} ({tf}) ---")
            logger.info(f"{'='*60}")
            
            # 1. Entraînement local
            try:
                logger.info(f"📦 Étape 1/2: Entraînement local...")
                result = train_ml_models(symbol, tf)
                if "error" in result:
                    logger.warning(f"⚠️ Erreur entraînement local: {result['error']}")
                else:
                    logger.info(f"✅ Entraînement local réussi pour {symbol} ({tf})!")
                    for model_name, metric in result.get('metrics', {}).items():
                        logger.info(f"   📊 {model_name}: Accuracy={metric.get('accuracy', 0):.4f}")
            except Exception as e:
                logger.error(f"❌ Erreur critique entraînement local {symbol} ({tf}): {e}")
                continue
            
            # 2. Synchronisation avec Render
            logger.info(f"🌐 Étape 2/2: Synchronisation avec Render...")
            sync_success = sync_to_render(symbol, tf)
            
            if sync_success:
                logger.info(f"✅ {symbol} ({tf}) - Entraînement local ET Render terminé avec succès!")
            else:
                logger.warning(f"⚠️ {symbol} ({tf}) - Entraînement local OK mais synchronisation Render échouée")
            
            logger.info("")  # Ligne vide pour séparer les symboles

if __name__ == "__main__":
    try:
        trigger_training()
        logger.info(f"{'='*60}")
        logger.info("✅ Processus d'entraînement terminé (local + Render)")
        logger.info(f"{'='*60}")
    finally:
        mt5.shutdown()
