import os
import sys
import pandas as pd
import numpy as np
import logging

# Configure logging to see what's happening
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("trigger_training")

# Set environment variables for ai_server
os.environ["DATABASE_URL"] = "postgresql://koladb_user:wYkUIyTb53vWEygkyia3YZiJNIdonmOt@dpg-d5nje68gjchc739d0dug-a.oregon-postgres.render.com/koladb_rurl"
# os.environ["MT5_AVAILABLE"] = "True" # We want it to try

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

def trigger_training():
    for symbol in symbols:
        for tf in timeframes:
            logger.info(f"--- Training for {symbol} ({tf}) ---")
            try:
                result = train_ml_models(symbol, tf)
                if "error" in result:
                    logger.warning(f"Result: {result['error']}")
                else:
                    logger.info(f"Success for {symbol} ({tf})!")
                    for model_name, metric in result.get('metrics', {}).items():
                        logger.info(f"  - {model_name}: Accuracy={metric.get('accuracy', 0):.4f}")
            except Exception as e:
                logger.error(f"Critical error training {symbol} ({tf}): {e}")

if __name__ == "__main__":
    try:
        trigger_training()
    finally:
        mt5.shutdown()
