from backend.mt5_connector import get_ohlc

symbol = 'EURUSD'  # Modifie ici si besoin

timeframes = ['1m', '5m', '15m', '30m', '1h', '4h', '1d', '1w', '1M']

print(f"Test récupération OHLC pour {symbol} sur tous les timeframes :")
for tf in timeframes:
    try:
        df = get_ohlc(symbol, timeframe=tf, count=10)
        if df is not None and not df.empty:
            last_ts = df['timestamp'].iloc[-1] if 'timestamp' in df.columns else '?'
            print(f"✅ {tf}: {len(df)} bougies, dernière bougie: {last_ts}")
        else:
            print(f"❌ {tf}: Aucune donnée récupérée")
    except Exception as e:
        print(f"❌ {tf}: Erreur {e}") 