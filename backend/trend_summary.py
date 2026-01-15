import pandas as pd
from backend.mt5_connector import get_ohlc
from backend.technical_analysis import add_technical_indicators
from concurrent.futures import ThreadPoolExecutor

def get_trend_and_force(symbol, tf):
    try:
        # Ajuster le nombre de bougies selon le timeframe pour éviter les données insuffisantes
        default_counts = {
            '1m': 600,
            '5m': 600,
            '15m': 600,
            '30m': 600,
            '1h': 600,
            '4h': 600,
            '6h': 600,
            '8h': 600,
            '1d': 600,
        }
        count = default_counts.get(tf, 600)
        df = get_ohlc(symbol, timeframe=tf, count=count)
        if df is None or df.empty or 'close' not in df.columns:
            print(f"[DEBUG] Pas de données pour {symbol} {tf}")
            return {'trend': 'neutral', 'force': 0, 'slope': 0.0, 'rsi': 50.0, 'macd': 0.0, 'adx': 20.0, 'price_vs_ma': 0.0, 'last_timestamp': '?'}
        # Si les données restent très courtes, tenter une deuxième récupération plus large
        if len(df) < 20:
            extra = max(50, 2 * len(df))
            try:
                df2 = get_ohlc(symbol, timeframe=tf, count=count + extra)
                if df2 is not None and not df2.empty:
                    df = df2
            except Exception:
                pass
        df = add_technical_indicators(df)
        last_timestamp = str(df['timestamp'].iloc[-1]) if 'timestamp' in df.columns else '?'
        
        # Vérifier et calculer SMA20 si nécessaire
        if 'sma_20' not in df.columns and len(df) >= 20:
            df['sma_20'] = df['close'].rolling(window=20).mean()
        
        # Slope MA20
        if 'sma_20' in df.columns and not df['sma_20'].isna().all():
            ma = df['sma_20'].dropna()
            if len(ma) < 6:
                print(f"[DEBUG] MA20 trop courte pour {symbol} {tf}")
                return {'trend': 'neutral', 'force': 0, 'slope': 0.0, 'rsi': 50.0, 'macd': 0.0, 'adx': 20.0, 'price_vs_ma': 0.0, 'last_timestamp': last_timestamp}
            slope = ma.iloc[-1] - ma.iloc[-6]
            slope_threshold = 0.001 * df['close'].iloc[-1]  # 0.1% du prix
            # RSI
            rsi = df['rsi_14'].iloc[-1] if 'rsi_14' in df.columns else 50
            # MACD
            macd = df['macd'].iloc[-1] if 'macd' in df.columns else 0
            # ADX
            adx = df['adx_14'].iloc[-1] if 'adx_14' in df.columns else 20
            # Position prix vs MA20
            price_vs_ma = df['close'].iloc[-1] - ma.iloc[-1]
            # Score consensus
            votes = 0
            if slope > slope_threshold:
                votes += 1
            elif slope < -slope_threshold:
                votes -= 1
            if rsi > 55:
                votes += 1
            elif rsi < 45:
                votes -= 1
            if macd > 0:
                votes += 1
            elif macd < 0:
                votes -= 1
            if price_vs_ma > 0:
                votes += 1
            elif price_vs_ma < 0:
                votes -= 1
            if adx > 25:
                votes += 1 if abs(slope) > slope_threshold else 0
            # Décision finale
            if votes >= 2:
                trend = 'bullish'
            elif votes <= -2:
                trend = 'bearish'
            else:
                trend = 'neutral'
            # Force pondérée
            force = (
                0.3 * min(abs(rsi - 50) * 2, 100) +
                0.3 * min(abs(slope) * 10000, 100) +
                0.2 * min(abs(macd) * 100, 100) +
                0.2 * min(adx, 100)
            )
            force = int(force)
            print(f"[DEBUG] {symbol} {tf} trend={trend} force={force} slope={slope:.5f} rsi={rsi:.2f} macd={macd:.5f} adx={adx:.2f} price_vs_ma={price_vs_ma:.5f} last_ts={last_timestamp}")
            return {
                'trend': trend,
                'force': force,
                'slope': round(slope, 5),
                'rsi': round(rsi, 2),
                'macd': round(macd, 5),
                'adx': round(adx, 2),
                'price_vs_ma': round(price_vs_ma, 5),
                'last_timestamp': last_timestamp
            }
        else:
            print(f"[DEBUG] Pas de MA20 pour {symbol} {tf} - données insuffisantes ou calcul échoué")
            # Essayer avec des indicateurs alternatifs
            if len(df) >= 10:
                # Calculer une MA simple alternative
                df['ma_simple'] = df['close'].rolling(window=min(10, len(df))).mean()
                if not df['ma_simple'].isna().all():
                    ma = df['ma_simple'].dropna()
                    if len(ma) >= 3:
                        slope = ma.iloc[-1] - ma.iloc[-3] if len(ma) >= 3 else 0
                        rsi = df['rsi_14'].iloc[-1] if 'rsi_14' in df.columns else 50
                        macd = df['macd'].iloc[-1] if 'macd' in df.columns else 0
                        
                        # Analyse simplifiée
                        votes = 0
                        if slope > 0:
                            votes += 1
                        elif slope < 0:
                            votes -= 1
                        if rsi > 55:
                            votes += 1
                        elif rsi < 45:
                            votes -= 1
                        if macd > 0:
                            votes += 1
                        elif macd < 0:
                            votes -= 1
                        
                        trend = 'bullish' if votes > 0 else 'bearish' if votes < 0 else 'neutral'
                        force = min(abs(votes) * 25, 100)  # Force simplifiée
                        
                        return {
                            'trend': trend,
                            'force': force,
                            'slope': round(slope, 5),
                            'rsi': round(rsi, 2),
                            'macd': round(macd, 5),
                            'adx': 20.0,
                            'price_vs_ma': 0.0,
                            'last_timestamp': last_timestamp
                        }
            
            # Données vraiment insuffisantes: renvoyer une ligne neutre explicite sans ? quand possible
            try:
                rsi_val = float(df['rsi_14'].iloc[-1]) if 'rsi_14' in df.columns else 50.0
                macd_val = float(df['macd'].iloc[-1]) if 'macd' in df.columns else 0.0
            except Exception:
                rsi_val = 50.0
                macd_val = 0.0
            return {
                'trend': 'neutral',
                'force': 0,
                'slope': 0.0,
                'rsi': round(rsi_val, 2),
                'macd': round(macd_val, 5),
                'adx': 20.0,
                'price_vs_ma': 0.0,
                'last_timestamp': last_timestamp
            }
    except Exception as e:
        print(f"[DEBUG] Erreur get_trend_and_force {symbol} {tf} : {e}")
        return {'trend': 'neutral', 'force': 0, 'slope': 0.0, 'rsi': 50.0, 'macd': 0.0, 'adx': 20.0, 'price_vs_ma': 0.0, 'last_timestamp': '?'}

def get_multi_timeframe_trend(symbol):
    """
    Retourne la tendance consolidée sur plusieurs timeframes pour un symbole donné.
    Timeframes : 1d, 8h, 6h, 4h, 1h, 30m, 15m, 5m, 1m
    """
    timeframes = ['1d', '8h', '6h', '4h', '1h', '30m', '15m', '5m', '1m']
    trends = {}
    def tf_job(tf):
        return tf, get_trend_and_force(symbol, tf)
    with ThreadPoolExecutor(max_workers=len(timeframes)) as executor:
        results = list(executor.map(tf_job, timeframes))
    for tf, tf_data in results:
        trends[tf] = tf_data

    # Pondérations par timeframe (plus lourd pour D1/H4/H1)
    weights = {
        '1d': 0.22,
        '8h': 0.16,
        '6h': 0.14,
        '4h': 0.14,
        '1h': 0.14,
        '30m': 0.10,
        '15m': 0.06,
        '5m': 0.03,
        '1m': 0.01,
    }

    weighted_score = 0.0
    total_weight_used = 0.0
    contributions = {}

    for tf, data in trends.items():
        trend = data.get('trend', 'neutral')
        force = data.get('force', 0) or 0
        weight = weights.get(tf, 0)
        direction = 1 if trend == 'bullish' else -1 if trend == 'bearish' else 0
        contribution = direction * (force / 100.0) * weight
        weighted_score += contribution
        total_weight_used += weight if direction != 0 else 0
        contributions[tf] = round(contribution, 4)

    # Seuils de décision: neutre si l'amplitude est faible
    if weighted_score > 0.10:
        consolidated = 'bullish'
    elif weighted_score < -0.10:
        consolidated = 'bearish'
    else:
        consolidated = 'neutral'

    # Confiance globale basée sur l'amplitude et la couverture pondérée
    coverage = min(max(total_weight_used, 0.0), 1.0)
    consolidated_confidence = int(min(abs(weighted_score) * (100 / 0.25) * (0.6 + 0.4 * coverage), 100))

    m1_trend = trends.get('1m', {}).get('trend', 'neutral')
    m1_force = trends.get('1m', {}).get('force', 0) or 0
    scalping_possible = 'OUI' if m1_trend == consolidated and m1_force >= 60 else 'NON'

    return {
        'trends': trends,
        'consolidated': consolidated,
        'consolidated_confidence': consolidated_confidence,
        'weighted_score': round(weighted_score, 4),
        'contributions': contributions,
        'scalping_possible': scalping_possible
    }