#!/usr/bin/env python3
"""
Indicateurs techniques avancés pour traders professionnels
Inclut les indicateurs cachés mais efficaces utilisés par les pros
"""

import pandas as pd
import numpy as np
from typing import Dict, List, Tuple, Optional

def calculate_vwap(df: pd.DataFrame, volume_col: str = 'tick_volume') -> pd.Series:
    """
    Volume Weighted Average Price (VWAP)
    Indicateur institutionnel pour détecter la pression acheteur/vendeur
    """
    if volume_col not in df.columns:
        # Fallback si pas de volume
        df = df.copy()
        df[volume_col] = 1000
    
    typical_price = (df['high'] + df['low'] + df['close']) / 3
    vwap = (typical_price * df[volume_col]).cumsum() / df[volume_col].cumsum()
    return vwap

def calculate_keltner_channels(df: pd.DataFrame, period: int = 20, multiplier: float = 2.0) -> Tuple[pd.Series, pd.Series, pd.Series]:
    """
    Keltner Channels - Alternative aux Bollinger Bands, moins de bruit
    Basé sur ATR au lieu de l'écart-type
    """
    ema = df['close'].ewm(span=period).mean()
    atr = calculate_atr(df, period)
    
    upper = ema + (multiplier * atr)
    lower = ema - (multiplier * atr)
    
    return upper, ema, lower

def calculate_vortex_indicator(df: pd.DataFrame, period: int = 14) -> Tuple[pd.Series, pd.Series]:
    """
    Vortex Indicator - Détecte début/fin de tendance via croisements
    Retourne VI+ et VI-
    """
    high_low = df['high'] - df['low']
    high_prev_close = np.abs(df['high'] - df['close'].shift())
    low_prev_close = np.abs(df['low'] - df['close'].shift())
    
    true_range = np.maximum(high_low, np.maximum(high_prev_close, low_prev_close))
    
    vm_plus = np.abs(df['high'] - df['low'].shift())
    vm_minus = np.abs(df['low'] - df['high'].shift())
    
    vi_plus = vm_plus.rolling(window=period).sum() / true_range.rolling(window=period).sum()
    vi_minus = vm_minus.rolling(window=period).sum() / true_range.rolling(window=period).sum()
    
    return vi_plus, vi_minus

def calculate_aroon_indicator(df: pd.DataFrame, period: int = 14) -> Tuple[pd.Series, pd.Series, pd.Series]:
    """
    Aroon Indicator - Détecte la force du trend
    Retourne Aroon Up, Aroon Down, et Aroon Oscillator
    """
    high_period = df['high'].rolling(window=period).apply(lambda x: x.argmax())
    low_period = df['low'].rolling(window=period).apply(lambda x: x.argmin())
    
    aroon_up = ((period - high_period) / period) * 100
    aroon_down = ((period - low_period) / period) * 100
    aroon_oscillator = aroon_up - aroon_down
    
    return aroon_up, aroon_down, aroon_oscillator

def calculate_williams_r(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """
    Williams %R - Oscillateur entre -100 et 0
    Idéal pour les marchés latéraux
    """
    highest_high = df['high'].rolling(window=period).max()
    lowest_low = df['low'].rolling(window=period).min()
    
    williams_r = ((highest_high - df['close']) / (highest_high - lowest_low)) * -100
    return williams_r

def calculate_cmo(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """
    Chande Momentum Oscillator (CMO)
    Mesure momentum sans centrage sur zéro, idéal en tendance
    """
    change = df['close'].diff()
    gain = change.where(change > 0, 0)
    loss = -change.where(change < 0, 0)
    
    sum_gain = gain.rolling(window=period).sum()
    sum_loss = loss.rolling(window=period).sum()
    
    cmo = ((sum_gain - sum_loss) / (sum_gain + sum_loss)) * 100
    return cmo

def calculate_force_index(df: pd.DataFrame, period: int = 13, volume_col: str = 'tick_volume') -> pd.Series:
    """
    Force Index - Quantifie la pression acheteuse/vendeuse
    Inventé par Alexander Elder
    """
    if volume_col not in df.columns:
        df = df.copy()
        df[volume_col] = 1000
    
    force = df['close'].diff() * df[volume_col]
    force_index = force.ewm(span=period).mean()
    return force_index

def calculate_chaikin_oscillator(df: pd.DataFrame, fast_period: int = 3, slow_period: int = 10, volume_col: str = 'tick_volume') -> pd.Series:
    """
    Chaikin Oscillator - Combine volume et momentum
    Détecte accumulation/distribution
    """
    if volume_col not in df.columns:
        df = df.copy()
        df[volume_col] = 1000
    
    # Money Flow Multiplier
    mfm = ((df['close'] - df['low']) - (df['high'] - df['close'])) / (df['high'] - df['low'])
    mfm = mfm.replace([np.inf, -np.inf], 0)
    
    # Money Flow Volume
    mfv = mfm * df[volume_col]
    
    # Accumulation/Distribution Line
    adl = mfv.cumsum()
    
    # Chaikin Oscillator
    chaikin = adl.ewm(span=fast_period).mean() - adl.ewm(span=slow_period).mean()
    return chaikin

def calculate_donchian_channels(df: pd.DataFrame, period: int = 20) -> Tuple[pd.Series, pd.Series, pd.Series]:
    """
    Donchian Channels - Définit les extrêmes sur n-périodes
    Excellent filtre de breakout
    """
    upper = df['high'].rolling(window=period).max()
    lower = df['low'].rolling(window=period).min()
    middle = (upper + lower) / 2
    
    return upper, middle, lower

def calculate_starc_bands(df: pd.DataFrame, period: int = 6, multiplier: float = 1.5) -> Tuple[pd.Series, pd.Series]:
    """
    STARC Bands - Alternative aux Bollinger, plus orientée timing
    """
    sma = df['close'].rolling(window=period).mean()
    atr = calculate_atr(df, period)
    
    upper = sma + (multiplier * atr)
    lower = sma - (multiplier * atr)
    
    return upper, lower

def calculate_coppock_curve(df: pd.DataFrame, roc1_period: int = 14, roc2_period: int = 11, wma_period: int = 10) -> pd.Series:
    """
    Coppock Curve - Courbe lissée pour investisseurs long-terme
    Générateur de buy-signals après les creux
    """
    roc1 = df['close'].pct_change(roc1_period) * 100
    roc2 = df['close'].pct_change(roc2_period) * 100
    
    roc_sum = roc1 + roc2
    
    # WMA (Weighted Moving Average)
    weights = np.arange(1, wma_period + 1)
    coppock = roc_sum.rolling(window=wma_period).apply(
        lambda x: np.dot(x, weights) / weights.sum(), raw=True
    )
    
    return coppock

def calculate_gator_oscillator(df: pd.DataFrame) -> Tuple[pd.Series, pd.Series]:
    """
    Gator Oscillator - Extrait de l'Alligator de Bill Williams
    Révèle phases de marché (trend vs range)
    """
    # Alligator lines
    jaw = df['close'].rolling(window=13).mean().shift(8)
    teeth = df['close'].rolling(window=8).mean().shift(5)
    lips = df['close'].rolling(window=5).mean().shift(3)
    
    # Gator Jaw (green)
    gator_jaw = np.abs(jaw - teeth)
    
    # Gator Teeth (red)
    gator_teeth = -np.abs(teeth - lips)
    
    return gator_jaw, gator_teeth

def detect_hikkake_pattern(df: pd.DataFrame, inside_periods: int = 3) -> pd.Series:
    """
    Hikkake Pattern - Patron japonais signalant faux breakouts
    Confirme les retournements ou continuations
    """
    hikkake = pd.Series(0, index=df.index)
    
    for i in range(inside_periods + 1, len(df)):
        # Inside bar pattern
        inside_high = df['high'].iloc[i-inside_periods:i].max()
        inside_low = df['low'].iloc[i-inside_periods:i].min()
        
        # Check if current bar breaks out
        if df['high'].iloc[i] > inside_high:
            # Bullish breakout
            hikkake.iloc[i] = 1
        elif df['low'].iloc[i] < inside_low:
            # Bearish breakout
            hikkake.iloc[i] = -1
    
    return hikkake

def calculate_heikin_ashi(df: pd.DataFrame) -> pd.DataFrame:
    ha_df = df.copy()
    if ha_df.empty:
        return ha_df
    # Calcul initial ha_close et ha_open
    ha_df['ha_close'] = (ha_df['open'] + ha_df['high'] + ha_df['low'] + ha_df['close']) / 4
    ha_df['ha_open'] = ha_df['open']
    for i in range(1, len(ha_df)):
        ha_df.at[ha_df.index[i], 'ha_open'] = (ha_df.at[ha_df.index[i-1], 'ha_open'] + ha_df.at[ha_df.index[i-1], 'ha_close']) / 2
    # Maintenant on peut calculer ha_high et ha_low
    ha_df['ha_high'] = ha_df[['high', 'ha_open', 'ha_close']].max(axis=1)
    ha_df['ha_low'] = ha_df[['low', 'ha_open', 'ha_close']].min(axis=1)
    return ha_df[['ha_open', 'ha_high', 'ha_low', 'ha_close']]

def calculate_adx(df: pd.DataFrame, period: int = 14) -> Tuple[pd.Series, pd.Series, pd.Series]:
    """
    Average Directional Index (ADX) - Confirme force de la tendance
    Seuil > 25 recommandé pour tendance significative
    """
    high_low = df['high'] - df['low']
    high_prev_close = np.abs(df['high'] - df['close'].shift())
    low_prev_close = np.abs(df['low'] - df['close'].shift())
    
    true_range = np.maximum(high_low, np.maximum(high_prev_close, low_prev_close))
    
    # Directional Movement
    up_move = df['high'] - df['high'].shift()
    down_move = df['low'].shift() - df['low']
    
    plus_dm = np.where((up_move > down_move) & (up_move > 0), up_move, 0)
    minus_dm = np.where((down_move > up_move) & (down_move > 0), down_move, 0)
    
    # Smoothed values
    tr_smooth = true_range.rolling(window=period).mean()
    plus_di = (pd.Series(plus_dm).rolling(window=period).mean() / tr_smooth) * 100
    minus_di = (pd.Series(minus_dm).rolling(window=period).mean() / tr_smooth) * 100
    
    # ADX
    dx = np.abs(plus_di - minus_di) / (plus_di + minus_di) * 100
    adx = dx.rolling(window=period).mean()
    
    return plus_di, minus_di, adx

def calculate_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """
    Average True Range (ATR) - Mesure de volatilité
    """
    high_low = df['high'] - df['low']
    high_prev_close = np.abs(df['high'] - df['close'].shift())
    low_prev_close = np.abs(df['low'] - df['close'].shift())
    
    true_range = np.maximum(high_low, np.maximum(high_prev_close, low_prev_close))
    atr = true_range.rolling(window=period).mean()
    
    return atr

def add_advanced_technical_indicators(df: pd.DataFrame, indicators: List[str] = None) -> pd.DataFrame:
    """
    Ajoute tous les indicateurs techniques avancés au DataFrame
    """
    df_enhanced = df.copy()
    
    if indicators is None:
        indicators = [
            'vwap', 'keltner', 'vortex', 'aroon', 'williams_r', 'cmo',
            'force_index', 'chaikin', 'donchian', 'starc', 'coppock',
            'gator', 'hikkake', 'heikin_ashi', 'adx', 'atr'
        ]
    
    # VWAP
    if 'vwap' in indicators:
        df_enhanced['vwap'] = calculate_vwap(df_enhanced)
    
    # Keltner Channels
    if 'keltner' in indicators:
        keltner_upper, keltner_middle, keltner_lower = calculate_keltner_channels(df_enhanced)
        df_enhanced['keltner_upper'] = keltner_upper
        df_enhanced['keltner_middle'] = keltner_middle
        df_enhanced['keltner_lower'] = keltner_lower
    
    # Vortex Indicator
    if 'vortex' in indicators:
        vi_plus, vi_minus = calculate_vortex_indicator(df_enhanced)
        df_enhanced['vortex_plus'] = vi_plus
        df_enhanced['vortex_minus'] = vi_minus
        df_enhanced['vortex_signal'] = np.where(vi_plus > vi_minus, 1, -1)
    
    # Aroon Indicator
    if 'aroon' in indicators:
        aroon_up, aroon_down, aroon_osc = calculate_aroon_indicator(df_enhanced)
        df_enhanced['aroon_up'] = aroon_up
        df_enhanced['aroon_down'] = aroon_down
        df_enhanced['aroon_oscillator'] = aroon_osc
    
    # Williams %R
    if 'williams_r' in indicators:
        df_enhanced['williams_r'] = calculate_williams_r(df_enhanced)
    
    # CMO
    if 'cmo' in indicators:
        df_enhanced['cmo'] = calculate_cmo(df_enhanced)
    
    # Force Index
    if 'force_index' in indicators:
        df_enhanced['force_index'] = calculate_force_index(df_enhanced)
    
    # Chaikin Oscillator
    if 'chaikin' in indicators:
        df_enhanced['chaikin_oscillator'] = calculate_chaikin_oscillator(df_enhanced)
    
    # Donchian Channels
    if 'donchian' in indicators:
        donchian_upper, donchian_middle, donchian_lower = calculate_donchian_channels(df_enhanced)
        df_enhanced['donchian_upper'] = donchian_upper
        df_enhanced['donchian_middle'] = donchian_middle
        df_enhanced['donchian_lower'] = donchian_lower
    
    # STARC Bands
    if 'starc' in indicators:
        starc_upper, starc_lower = calculate_starc_bands(df_enhanced)
        df_enhanced['starc_upper'] = starc_upper
        df_enhanced['starc_lower'] = starc_lower
    
    # Coppock Curve
    if 'coppock' in indicators:
        df_enhanced['coppock_curve'] = calculate_coppock_curve(df_enhanced)
    
    # Gator Oscillator
    if 'gator' in indicators:
        gator_jaw, gator_teeth = calculate_gator_oscillator(df_enhanced)
        df_enhanced['gator_jaw'] = gator_jaw
        df_enhanced['gator_teeth'] = gator_teeth
    
    # Hikkake Pattern
    if 'hikkake' in indicators:
        df_enhanced['hikkake_pattern'] = detect_hikkake_pattern(df_enhanced)
    
    # Heikin-Ashi
    if 'heikin_ashi' in indicators:
        ha_df = calculate_heikin_ashi(df_enhanced)
        df_enhanced['ha_open'] = ha_df['ha_open']
        df_enhanced['ha_high'] = ha_df['ha_high']
        df_enhanced['ha_low'] = ha_df['ha_low']
        df_enhanced['ha_close'] = ha_df['ha_close']
    
    # ADX
    if 'adx' in indicators:
        plus_di, minus_di, adx = calculate_adx(df_enhanced)
        df_enhanced['adx_plus_di'] = plus_di
        df_enhanced['adx_minus_di'] = minus_di
        df_enhanced['adx'] = adx
        df_enhanced['adx_trend_strength'] = np.where(adx > 25, 'Strong', 'Weak')
    
    # ATR
    if 'atr' in indicators:
        df_enhanced['atr'] = calculate_atr(df_enhanced)
    
    return df_enhanced

def generate_professional_signals(df: pd.DataFrame) -> Dict[str, str]:
    """
    Génère des signaux de trading basés sur la confluence d'indicateurs professionnels
    Stratégie: Keltner + Vortex + Hikkake + VWAP + ADX
    """
    signals = {}
    
    if len(df) < 50:
        return {'signal': 'INSUFFICIENT_DATA', 'confidence': 0.0}
    
    # Récupérer les dernières valeurs
    current = df.iloc[-1]
    prev = df.iloc[-2] if len(df) > 1 else current
    
    # 1. Keltner Channels
    if 'keltner_upper' in df.columns and 'keltner_lower' in df.columns:
        keltner_position = (current['close'] - current['keltner_lower']) / (current['keltner_upper'] - current['keltner_lower'])
        signals['keltner'] = 'BUY' if keltner_position < 0.2 else 'SELL' if keltner_position > 0.8 else 'NEUTRAL'
    
    # 2. Vortex Indicator
    if 'vortex_plus' in df.columns and 'vortex_minus' in df.columns:
        vortex_signal = 'BUY' if current['vortex_plus'] > current['vortex_minus'] else 'SELL'
        signals['vortex'] = vortex_signal
    
    # 3. VWAP
    if 'vwap' in df.columns:
        vwap_signal = 'BUY' if current['close'] > current['vwap'] else 'SELL'
        signals['vwap'] = vwap_signal
    
    # 4. ADX Trend Strength
    if 'adx' in df.columns:
        trend_strength = 'Strong' if current['adx'] > 25 else 'Weak'
        signals['adx'] = trend_strength
    
    # 5. Hikkake Pattern
    if 'hikkake_pattern' in df.columns:
        hikkake_signal = 'BUY' if current['hikkake_pattern'] == 1 else 'SELL' if current['hikkake_pattern'] == -1 else 'NEUTRAL'
        signals['hikkake'] = hikkake_signal
    
    # 6. Williams %R
    if 'williams_r' in df.columns:
        if current['williams_r'] < -80:
            signals['williams_r'] = 'BUY'  # Survente
        elif current['williams_r'] > -20:
            signals['williams_r'] = 'SELL'  # Surachat
        else:
            signals['williams_r'] = 'NEUTRAL'
    
    # 7. CMO
    if 'cmo' in df.columns:
        if current['cmo'] > 50:
            signals['cmo'] = 'BUY'  # Momentum haussier
        elif current['cmo'] < -50:
            signals['cmo'] = 'SELL'  # Momentum baissier
        else:
            signals['cmo'] = 'NEUTRAL'
    
    # Calculer le signal final basé sur la confluence
    buy_signals = sum(1 for signal in signals.values() if signal == 'BUY')
    sell_signals = sum(1 for signal in signals.values() if signal == 'SELL')
    strong_trend = signals.get('adx', 'Weak') == 'Strong'
    
    total_signals = len(signals)
    confidence = max(buy_signals, sell_signals) / total_signals if total_signals > 0 else 0
    
    if buy_signals > sell_signals and strong_trend:
        final_signal = 'BUY'
    elif sell_signals > buy_signals and strong_trend:
        final_signal = 'SELL'
    else:
        final_signal = 'NEUTRAL'
        confidence *= 0.5  # Réduire la confiance si pas de tendance forte
    
    return {
        'signal': final_signal,
        'confidence': confidence,
        'signals_detail': signals,
        'buy_count': buy_signals,
        'sell_count': sell_signals,
        'trend_strength': strong_trend
    } 