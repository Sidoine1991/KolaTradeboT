import os
import logging
from datetime import datetime

import pandas as pd

try:
    import MetaTrader5 as mt5
except ImportError:
    mt5 = None

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("collect_spike_data")

DATA_DIR = os.path.join(os.path.dirname(__file__), "data_spike")
SYMBOLS = [
    "Boom 300 Index",
    "Boom 500 Index",
    "Boom 1000 Index",
    "Crash 300 Index",
    "Crash 500 Index",
    "Crash 1000 Index",
]
BARS = 3000
TIMEFRAME = "M1"  # pour lisibilité dans les fichiers


def _check_mt5() -> bool:
    if mt5 is None:
        logger.error("MetaTrader5 n'est pas installé (pip install MetaTrader5)")
        return False
    try:
        return mt5.initialize()
    except Exception as e:
        logger.error("Impossible d'initialiser MT5: %s", e)
        return False


def collect_for_symbol(symbol: str) -> None:
    rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, BARS)
    if rates is None or len(rates) == 0:
        logger.warning("Aucune donnée pour %s", symbol)
        return

    df = pd.DataFrame(rates)
    df["time"] = pd.to_datetime(df["time"], unit="s")

    fname = f"{symbol.replace(' ', '_').replace('/', '')}_{TIMEFRAME}_{BARS}.csv"
    path = os.path.join(DATA_DIR, fname)
    df.to_csv(path, index=False)
    logger.info("%s: %d bougies sauvegardées -> %s", symbol, len(df), path)


def main() -> None:
    os.makedirs(DATA_DIR, exist_ok=True)

    if not _check_mt5():
        return

    try:
        for sym in SYMBOLS:
            try:
                collect_for_symbol(sym)
            except Exception as e:
                logger.error("Erreur sur %s: %s", sym, e)
    finally:
        try:
            mt5.shutdown()
        except Exception:
            pass


if __name__ == "__main__":
    main()
