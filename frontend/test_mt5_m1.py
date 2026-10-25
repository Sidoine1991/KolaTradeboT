import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from backend.mt5_connector import get_ohlc

symbol = "Boom 1000 Index"  # ou le symbole à tester
timeframe = "1m"

df = get_ohlc(symbol, timeframe=timeframe, count=50)
if df is not None and not df.empty:
    print(f"✅ Données M1 récupérées pour {symbol} : {len(df)} bougies")
    print(df.tail())
else:
    print(f"❌ Impossible de récupérer les données M1 pour {symbol}")