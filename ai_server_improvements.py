"""
Améliorations pour ai_server.py - Prédictions plus fiables et cohérentes
Ce module contient des fonctions améliorées pour remplacer celles de ai_server.py
"""

import pandas as pd
import numpy as np
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

# ============================================================================
# 1. CALCUL DE CONFiance AVANCÉ MULTI-INDICATEURS
# ============================================================================

def calculate_advanced_confidence(
    df: pd.DataFrame,
        symbol: str,
    timeframe: str = "M1",
    use_multi_timeframe: bool = True
) -> Dict[str, Any]:
    """
    Calcule un score de confiance avancé en combinant plusieurs indicateurs techniques.
    
    Args:
        df: DataFrame avec colonnes ['open', 'high', 'low', 'close', 'volume', 'time']
        symbol: Symbole analysé
        timeframe: Timeframe utilisé
        use_multi_timeframe: Si True, valide aussi sur les timeframes supérieurs
        
        Returns:
        Dict avec 'confidence', 'direction', 'indicators_scores', 'consensus'
    """
    if df is None or len(df) < 50:
        return {
            'confidence': 0.5,
            'direction': 'NEUTRAL',
            'indicators_scores': {},
            'consensus': 0.0,
            'reason': 'Données insuffisantes'
        }
    
    # Calculer tous les indicateurs
    indicators = {}
    
    # 1. RSI (14)
    delta = df['close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
    rs = gain / loss
    rsi = 100 - (100 / (1 + rs))
    current_rsi = rsi.iloc[-1]
    
    # Score RSI: 0-1 (1 = très confiant)
    if current_rsi > 70:
        indicators['rsi'] = {'score': 0.9, 'direction': 'BEARISH', 'value': current_rsi}
    elif current_rsi < 30:
        indicators['rsi'] = {'score': 0.9, 'direction': 'BULLISH', 'value': current_rsi}
    elif current_rsi > 50:
        indicators['rsi'] = {'score': 0.6, 'direction': 'BULLISH', 'value': current_rsi}
    else:
        indicators['rsi'] = {'score': 0.6, 'direction': 'BEARISH', 'value': current_rsi}
    
    # 2. MACD
    exp1 = df['close'].ewm(span=12, adjust=False).mean()
    exp2 = df['close'].ewm(span=26, adjust=False).mean()
    macd_line = exp1 - exp2
    signal_line = macd_line.ewm(span=9, adjust=False).mean()
    histogram = macd_line - signal_line
    
    current_macd = macd_line.iloc[-1]
    current_signal = signal_line.iloc[-1]
    current_hist = histogram.iloc[-1]
    
    if current_macd > current_signal and current_hist > 0:
        macd_score = min(0.95, 0.7 + abs(current_hist) / (df['close'].iloc[-1] * 0.01))
        indicators['macd'] = {'score': macd_score, 'direction': 'BULLISH', 'value': current_hist}
    elif current_macd < current_signal and current_hist < 0:
        macd_score = min(0.95, 0.7 + abs(current_hist) / (df['close'].iloc[-1] * 0.01))
        indicators['macd'] = {'score': macd_score, 'direction': 'BEARISH', 'value': current_hist}
    else:
        indicators['macd'] = {'score': 0.4, 'direction': 'NEUTRAL', 'value': current_hist}
    
    # 3. EMA Trend (9, 21, 50)
    ema9 = df['close'].ewm(span=9, adjust=False).mean()
    ema21 = df['close'].ewm(span=21, adjust=False).mean()
    ema50 = df['close'].ewm(span=50, adjust=False).mean() if len(df) >= 50 else None
    
    current_price = df['close'].iloc[-1]
    current_ema9 = ema9.iloc[-1]
    current_ema21 = ema21.iloc[-1]
    
    # Score EMA: alignement des EMA = confiance élevée
    ema_bullish = current_price > current_ema9 > current_ema21
    ema_bearish = current_price < current_ema9 < current_ema21
    
    if ema50 is not None:
        current_ema50 = ema50.iloc[-1]
        ema_bullish = ema_bullish and current_ema21 > current_ema50
        ema_bearish = ema_bearish and current_ema21 < current_ema50
    
    if ema_bullish:
        indicators['ema'] = {'score': 0.85, 'direction': 'BULLISH', 'value': current_price - current_ema21}
    elif ema_bearish:
        indicators['ema'] = {'score': 0.85, 'direction': 'BEARISH', 'value': current_price - current_ema21}
    else:
        indicators['ema'] = {'score': 0.5, 'direction': 'NEUTRAL', 'value': current_price - current_ema21}
    
    # 4. ATR (Volatilité)
    high_low = df['high'] - df['low']
    high_close = (df['high'] - df['close'].shift()).abs()
    low_close = (df['low'] - df['close'].shift()).abs()
    true_range = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
    atr = true_range.rolling(window=14).mean()
    current_atr = atr.iloc[-1]
    atr_percent = (current_atr / current_price) * 100
    
    # Volatilité modérée = bonne pour trading, trop élevée ou trop faible = moins confiant
    if 0.5 <= atr_percent <= 3.0:
        indicators['atr'] = {'score': 0.8, 'direction': 'NEUTRAL', 'value': atr_percent}
    elif atr_percent > 5.0:
        indicators['atr'] = {'score': 0.4, 'direction': 'NEUTRAL', 'value': atr_percent}  # Trop volatile
    else:
        indicators['atr'] = {'score': 0.5, 'direction': 'NEUTRAL', 'value': atr_percent}  # Trop calme
    
    # 5. Bollinger Bands
    sma20 = df['close'].rolling(window=20).mean()
    std20 = df['close'].rolling(window=20).std()
    bb_upper = sma20 + (std20 * 2)
    bb_lower = sma20 - (std20 * 2)
    
    current_bb_upper = bb_upper.iloc[-1]
    current_bb_lower = bb_lower.iloc[-1]
    bb_position = (current_price - current_bb_lower) / (current_bb_upper - current_bb_lower)
    
    if bb_position < 0.2:
        indicators['bb'] = {'score': 0.85, 'direction': 'BULLISH', 'value': bb_position}  # Près de la bande inférieure
    elif bb_position > 0.8:
        indicators['bb'] = {'score': 0.85, 'direction': 'BEARISH', 'value': bb_position}  # Près de la bande supérieure
    else:
        indicators['bb'] = {'score': 0.6, 'direction': 'NEUTRAL', 'value': bb_position}
    
    # 6. Volume (si disponible)
    if 'volume' in df.columns and df['volume'].sum() > 0:
        volume_sma = df['volume'].rolling(window=20).mean()
        current_volume = df['volume'].iloc[-1]
        avg_volume = volume_sma.iloc[-1]
        
        if current_volume > avg_volume * 1.5:
            # Volume élevé = confiance accrue pour la direction actuelle
            price_change = (df['close'].iloc[-1] - df['close'].iloc[-20]) / df['close'].iloc[-20]
            if price_change > 0:
                indicators['volume'] = {'score': 0.8, 'direction': 'BULLISH', 'value': current_volume / avg_volume}
            else:
                indicators['volume'] = {'score': 0.8, 'direction': 'BEARISH', 'value': current_volume / avg_volume}
        else:
            indicators['volume'] = {'score': 0.5, 'direction': 'NEUTRAL', 'value': current_volume / avg_volume}
    else:
        indicators['volume'] = {'score': 0.5, 'direction': 'NEUTRAL', 'value': 1.0}
    
    # Calculer le consensus et la direction
    bullish_count = sum(1 for ind in indicators.values() if ind['direction'] == 'BULLISH')
    bearish_count = sum(1 for ind in indicators.values() if ind['direction'] == 'BEARISH')
    total_count = len(indicators)
    
    consensus = max(bullish_count, bearish_count) / total_count if total_count > 0 else 0.5
    
    # Direction basée sur le consensus
    if bullish_count > bearish_count:
        direction = 'BULLISH'
    elif bearish_count > bullish_count:
        direction = 'BEARISH'
    else:
        direction = 'NEUTRAL'
    
    # Score de confiance composite (moyenne pondérée)
    weights = {
        'rsi': 0.15,
        'macd': 0.20,
        'ema': 0.25,
        'atr': 0.10,
        'bb': 0.15,
        'volume': 0.15
    }
    
    weighted_score = sum(
        indicators[ind]['score'] * weights.get(ind, 0.1)
        for ind in indicators.keys()
    )
    
    # Ajuster selon le consensus
    if consensus >= 0.7:
        confidence = min(0.95, weighted_score * 1.2)  # Bonus pour consensus fort
    elif consensus >= 0.5:
        confidence = weighted_score
    else:
        confidence = weighted_score * 0.7  # Pénalité pour faible consensus
    
    return {
        'confidence': round(confidence, 3),
        'direction': direction,
        'indicators_scores': {k: {'score': v['score'], 'direction': v['direction']} 
                              for k, v in indicators.items()},
        'consensus': round(consensus, 3),
        'reason': f'Consensus {direction} ({bullish_count}/{total_count} indicateurs)'
    }


# ============================================================================
# 2. PRÉDICTION DE PRIX AMÉLIORÉE AVEC SUPPORT/RÉSISTANCE
# ============================================================================

def detect_support_resistance_levels(
    df: pd.DataFrame,
    lookback: int = 100,
    min_touches: int = 2
) -> Dict[str, List[float]]:
    """
    Détecte les niveaux de support et résistance dans les données historiques.
    
    Args:
        df: DataFrame avec colonnes ['high', 'low', 'close']
        lookback: Nombre de bougies à analyser
        min_touches: Nombre minimum de touches pour valider un niveau
        
    Returns:
        Dict avec 'supports' et 'resistances' (listes de prix)
    """
    if len(df) < lookback:
        lookback = len(df)
    
    recent_df = df.tail(lookback).copy()
    
    # Trouver les pivots (local highs et lows)
    highs = []
    lows = []
    
    for i in range(2, len(recent_df) - 2):
        # Pivot haut: high[i] > high[i-1] et high[i] > high[i+1]
        if (recent_df['high'].iloc[i] > recent_df['high'].iloc[i-1] and
            recent_df['high'].iloc[i] > recent_df['high'].iloc[i+1]):
            highs.append(recent_df['high'].iloc[i])
        
        # Pivot bas: low[i] < low[i-1] et low[i] < low[i+1]
        if (recent_df['low'].iloc[i] < recent_df['low'].iloc[i-1] and
            recent_df['low'].iloc[i] < recent_df['low'].iloc[i+1]):
            lows.append(recent_df['low'].iloc[i])
    
    # Regrouper les niveaux proches (tolérance de 0.5%)
    tolerance = recent_df['close'].iloc[-1] * 0.005
    
    def cluster_levels(levels: List[float], tolerance: float) -> List[float]:
        if not levels:
            return []
        
        sorted_levels = sorted(levels)
        clusters = []
        current_cluster = [sorted_levels[0]]
        
        for level in sorted_levels[1:]:
            if abs(level - current_cluster[-1]) <= tolerance:
                current_cluster.append(level)
            else:
                if len(current_cluster) >= min_touches:
                    clusters.append(np.mean(current_cluster))
                current_cluster = [level]
        
        if len(current_cluster) >= min_touches:
            clusters.append(np.mean(current_cluster))
        
        return clusters
    
    supports = cluster_levels(lows, tolerance)
    resistances = cluster_levels(highs, tolerance)
    
    return {
        'supports': sorted(supports, reverse=True),  # Du plus haut au plus bas
        'resistances': sorted(resistances, reverse=True)  # Du plus haut au plus bas
    }


def predict_prices_advanced(
    df: pd.DataFrame,
    current_price: float,
    bars_to_predict: int,
    timeframe: str = "M1",
    symbol: str = "UNKNOWN"
) -> Dict[str, Any]:
    """
    Prédit les prix futurs avec un modèle amélioré prenant en compte:
    - Tendances multi-timeframe
    - Support/Résistance
    - Volatilité (ATR)
    - Patterns de prix
    
    Args:
        df: DataFrame historique avec colonnes ['open', 'high', 'low', 'close', 'volume']
        current_price: Prix actuel
        bars_to_predict: Nombre de bougies à prédire
        timeframe: Timeframe utilisé
        symbol: Symbole analysé
        
    Returns:
        Dict avec 'prediction' (liste de prix), 'confidence', 'support_levels', 'resistance_levels'
    """
    if df is None or len(df) < 50:
        # Fallback simple si données insuffisantes
        return {
            'prediction': [current_price] * bars_to_predict,
            'confidence': 0.5,
            'support_levels': [],
            'resistance_levels': [],
            'method': 'fallback'
        }
    
    # 1. Détecter les niveaux de support/résistance
    sr_levels = detect_support_resistance_levels(df, lookback=min(200, len(df)))
    
    # 2. Calculer la tendance et la volatilité
    recent_prices = df['close'].tail(50).values
    
    # Tendance linéaire
    x = np.arange(len(recent_prices))
    trend_slope = np.polyfit(x, recent_prices, 1)[0]
    
    # Volatilité (ATR)
    high_low = df['high'] - df['low']
    high_close = (df['high'] - df['close'].shift()).abs()
    low_close = (df['low'] - df['close'].shift()).abs()
    true_range = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
    atr = true_range.rolling(window=14).mean().iloc[-1]
    
    # 3. Calculer la confiance de la prédiction
    confidence_data = calculate_advanced_confidence(df, symbol, timeframe)
    prediction_confidence = confidence_data['confidence']
    direction = confidence_data['direction']
    
    # 4. Générer les prix prédits
    predicted_prices = []
    
    # Trouver les niveaux de support/résistance proches
    nearest_support = None
    nearest_resistance = None
    
    for support in sr_levels['supports']:
        if support < current_price and (nearest_support is None or support > nearest_support):
            nearest_support = support
    
    for resistance in sr_levels['resistances']:
        if resistance > current_price and (nearest_resistance is None or resistance < nearest_resistance):
            nearest_resistance = resistance
    
    # Ajuster la tendance selon la direction et les niveaux
    if direction == 'BULLISH':
        base_trend = abs(trend_slope) if trend_slope > 0 else atr * 0.1
        # Si proche d'un support, prévoir un rebond
        if nearest_support and (current_price - nearest_support) < atr * 2:
            base_trend *= 1.5  # Rebond attendu
    elif direction == 'BEARISH':
        base_trend = -abs(trend_slope) if trend_slope < 0 else -atr * 0.1
        # Si proche d'une résistance, prévoir un rejet
        if nearest_resistance and (nearest_resistance - current_price) < atr * 2:
            base_trend *= 1.5  # Rejet attendu
    else:
        base_trend = trend_slope * 0.5  # Tendance neutre réduite
    
    # Générer les prix avec décroissance de la tendance et bruit contrôlé
    for i in range(bars_to_predict):
        # Décroissance exponentielle de la tendance
        trend_decay = np.exp(-i / (bars_to_predict * 0.5))
        trend_component = base_trend * trend_decay
        
        # Bruit basé sur ATR (plus réaliste que bruit aléatoire pur)
        noise_factor = atr * 0.3 * (1 - trend_decay)  # Moins de bruit au début
        noise = np.random.normal(0, noise_factor)
        
        # Prix prédit
        predicted_price = current_price + (trend_component * i) + noise
        
        # Ajuster si on approche d'un niveau de support/résistance
        if nearest_support and predicted_price < nearest_support + atr:
            # Rebond possible au support
            predicted_price = nearest_support + atr * 0.5 + abs(noise) * 0.3
        
        if nearest_resistance and predicted_price > nearest_resistance - atr:
            # Rejet possible à la résistance
            predicted_price = nearest_resistance - atr * 0.5 - abs(noise) * 0.3
        
        predicted_prices.append(float(predicted_price))
    
    return {
        'prediction': predicted_prices,
        'confidence': prediction_confidence,
        'support_levels': sr_levels['supports'],
        'resistance_levels': sr_levels['resistances'],
        'direction': direction,
        'method': 'advanced',
        'atr': float(atr),
        'trend_slope': float(trend_slope)
    }


# ============================================================================
# 3. VALIDATION MULTI-TIMEFRAME
# ============================================================================

def validate_multi_timeframe(
    symbol: str,
    timeframes: List[str],
    mt5_module,
    mt5_initialized: bool
) -> Dict[str, Any]:
    """
    Valide la cohérence d'un signal sur plusieurs timeframes.
    
    Args:
        symbol: Symbole analysé
        timeframes: Liste des timeframes à analyser (ex: ['M1', 'M5', 'M15', 'H1'])
        mt5_module: Module MetaTrader5
        mt5_initialized: Si MT5 est initialisé
        
    Returns:
        Dict avec 'consensus', 'directions', 'confidences', 'is_valid'
    """
    if not mt5_initialized:
        return {
            'consensus': 0.5,
            'directions': {},
            'confidences': {},
            'is_valid': False,
            'reason': 'MT5 non initialisé'
        }
    
    tf_map = {
        'M1': mt5_module.TIMEFRAME_M1,
        'M5': mt5_module.TIMEFRAME_M5,
        'M15': mt5_module.TIMEFRAME_M15,
        'H1': mt5_module.TIMEFRAME_H1,
        'H4': mt5_module.TIMEFRAME_H4,
        'D1': mt5_module.TIMEFRAME_D1
    }
    
    directions = {}
    confidences = {}
    
    for tf in timeframes:
        try:
            mt5_tf = tf_map.get(tf, mt5_module.TIMEFRAME_M1)
            rates = mt5_module.copy_rates_from_pos(symbol, mt5_tf, 0, 100)
            
            if rates is None or len(rates) < 50:
                continue
            
            df = pd.DataFrame(rates)
            confidence_data = calculate_advanced_confidence(df, symbol, tf)
            
            directions[tf] = confidence_data['direction']
            confidences[tf] = confidence_data['confidence']
        except Exception as e:
            logger.warning(f"Erreur validation {tf} pour {symbol}: {e}")
            continue
    
    if not directions:
        return {
            'consensus': 0.0,
            'directions': {},
            'confidences': {},
            'is_valid': False,
            'reason': 'Aucune donnée disponible'
        }
    
    # Calculer le consensus
    bullish_count = sum(1 for d in directions.values() if d == 'BULLISH')
    bearish_count = sum(1 for d in directions.values() if d == 'BEARISH')
    total_count = len(directions)
    
    consensus = max(bullish_count, bearish_count) / total_count if total_count > 0 else 0.0
    
    # Validation: consensus >= 70% et confiance moyenne >= 0.65
    avg_confidence = np.mean(list(confidences.values())) if confidences else 0.0
    is_valid = consensus >= 0.7 and avg_confidence >= 0.65
    
    return {
        'consensus': round(consensus, 3),
        'directions': directions,
        'confidences': confidences,
        'is_valid': is_valid,
        'avg_confidence': round(avg_confidence, 3),
        'reason': f'Consensus {consensus:.1%}, Confiance moyenne {avg_confidence:.1%}'
    }


# ============================================================================
# 4. ADAPTATION AUX TYPES DE SYMBOLES
# ============================================================================

def is_boom_crash_symbol(symbol: str) -> bool:
    """Vérifie si le symbole est un Boom ou Crash"""
    return "Boom" in symbol or "Crash" in symbol


def is_volatility_symbol(symbol: str) -> bool:
    """Vérifie si le symbole est un Volatility"""
    return "Volatility" in symbol or "Vol" in symbol


def adapt_prediction_for_symbol(
    symbol: str,
    base_prediction: Dict[str, Any],
    df: pd.DataFrame
) -> Dict[str, Any]:
    """
    Adapte la prédiction selon le type de symbole.
    
    Args:
        symbol: Symbole analysé
        base_prediction: Prédiction de base
        df: DataFrame historique
        
    Returns:
        Prédiction adaptée
    """
    prediction = base_prediction.copy()
    
    if is_boom_crash_symbol(symbol):
        # Pour Boom/Crash: prédire des mouvements plus explosifs
        # Augmenter la volatilité attendue
        if 'prediction' in prediction:
            atr = prediction.get('atr', df['close'].iloc[-1] * 0.01)
            # Multiplier les mouvements par 1.5-2x pour Boom/Crash
            multiplier = 1.8
            
            adjusted_prices = []
            base_prices = prediction['prediction']
            current_price = base_prices[0] if base_prices else df['close'].iloc[-1]
            
            for i, price in enumerate(base_prices):
                # Amplifier les mouvements
                price_change = price - current_price
                adjusted_price = current_price + (price_change * multiplier)
                adjusted_prices.append(adjusted_price)
            
            prediction['prediction'] = adjusted_prices
            prediction['confidence'] = prediction.get('confidence', 0.7) * 0.9  # Légèrement réduire confiance
            prediction['symbol_type'] = 'boom_crash'
            prediction['volatility_multiplier'] = multiplier
    
    elif is_volatility_symbol(symbol):
        # Pour Volatility: analyser les cycles de volatilité
        # Détecter les périodes de consolidation vs expansion
        if len(df) >= 50:
            recent_atr = calculate_atr(df.tail(50), period=14)
            avg_atr = recent_atr.mean()
            current_atr = recent_atr.iloc[-1]
            
            # Si volatilité en expansion, prévoir continuation
            # Si volatilité en contraction, prévoir expansion future
            volatility_trend = (current_atr - avg_atr) / avg_atr
            
            if abs(volatility_trend) > 0.2:
                # Volatilité élevée: prévoir continuation avec légère réduction
                prediction['confidence'] = prediction.get('confidence', 0.7) * 0.95
            else:
                # Volatilité faible: prévoir expansion
                prediction['confidence'] = prediction.get('confidence', 0.7) * 0.85
            
            prediction['symbol_type'] = 'volatility'
            prediction['volatility_trend'] = float(volatility_trend)
    
    else:
        # Forex/autres: utiliser la prédiction de base
        prediction['symbol_type'] = 'forex'
    
    return prediction


def calculate_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """Calcule l'ATR (Average True Range)"""
    high_low = df['high'] - df['low']
    high_close = (df['high'] - df['close'].shift()).abs()
    low_close = (df['low'] - df['close'].shift()).abs()
    true_range = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
    return true_range.rolling(window=period).mean()


# ============================================================================
# 5. DÉTECTION DE MOMENTUM AVANCÉE
# ============================================================================

def calculate_momentum_score(
    df: pd.DataFrame,
    lookback: int = 20
) -> Dict[str, Any]:
    """
    Calcule un score de momentum avancé basé sur:
    - Vitesse de changement de prix
    - Accélération (changement de vitesse)
    - Force du mouvement (volume-weighted)
    
    Returns:
        Dict avec 'momentum_score' (0-1), 'direction', 'acceleration', 'strength'
    """
    if len(df) < lookback + 5:
        return {
            'momentum_score': 0.5,
            'direction': 'NEUTRAL',
            'acceleration': 0.0,
            'strength': 0.5,
            'velocity': 0.0
        }
    
    prices = df['close'].tail(lookback + 5).values
    
    # Vitesse: taux de changement de prix
    velocity_short = (prices[-1] - prices[-5]) / prices[-5] if len(prices) >= 5 else 0.0
    velocity_long = (prices[-1] - prices[-lookback]) / prices[-lookback] if len(prices) >= lookback else 0.0
    
    # Accélération: changement de vitesse
    velocity_prev_short = (prices[-5] - prices[-10]) / prices[-10] if len(prices) >= 10 else 0.0
    acceleration = velocity_short - velocity_prev_short
    
    # Force: combinaison de vitesse et volume (si disponible)
    volume_factor = 1.0
    if 'volume' in df.columns and df['volume'].sum() > 0:
        recent_volume = df['volume'].tail(lookback).mean()
        avg_volume = df['volume'].tail(lookback * 2).head(lookback).mean()
        if avg_volume > 0:
            volume_factor = min(2.0, recent_volume / avg_volume)
    
    # Score de momentum (0-1)
    # Combinaison de vitesse, accélération et force
    momentum_raw = abs(velocity_short) * volume_factor
    acceleration_boost = 1.0 + (acceleration * 10) if acceleration * velocity_short > 0 else 1.0
    
    momentum_score = min(1.0, momentum_raw * 100 * acceleration_boost)
    
    # Direction
    if velocity_short > 0.001 and acceleration > -0.0001:
        direction = 'BULLISH'
    elif velocity_short < -0.001 and acceleration < 0.0001:
        direction = 'BEARISH'
    else:
        direction = 'NEUTRAL'
        momentum_score *= 0.7  # Réduire le score si direction incertaine
    
    return {
        'momentum_score': round(momentum_score, 3),
        'direction': direction,
        'acceleration': round(acceleration, 6),
        'strength': round(volume_factor, 2),
        'velocity': round(velocity_short, 6)
    }


# ============================================================================
# 6. DÉTECTION DE DIVERGENCES RSI/PRICE
# ============================================================================

def detect_divergence(
    df: pd.DataFrame,
    period: int = 14,
    lookback: int = 30
) -> Dict[str, Any]:
    """
    Détecte les divergences entre le prix et le RSI.
    Les divergences peuvent indiquer des retournements potentiels.
    
    Returns:
        Dict avec 'divergence_type', 'strength', 'signal'
    """
    if len(df) < lookback + period:
        return {
            'divergence_type': 'NONE',
            'strength': 0.0,
            'signal': 'NEUTRAL'
        }
    
    # Calculer RSI
    delta = df['close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss
    rsi = 100 - (100 / (1 + rs))
    
    # Analyser les derniers lookback bougies
    recent_df = df.tail(lookback).copy()
    recent_rsi = rsi.tail(lookback).values
    recent_prices = recent_df['close'].values
    
    # Trouver les pics et creux dans le prix
    price_peaks = []
    price_troughs = []
    rsi_peaks = []
    rsi_troughs = []
    
    for i in range(2, len(recent_prices) - 2):
        # Pic de prix
        if (recent_prices[i] > recent_prices[i-1] and 
            recent_prices[i] > recent_prices[i+1] and
            recent_prices[i] > recent_prices[i-2] and
            recent_prices[i] > recent_prices[i+2]):
            price_peaks.append((i, recent_prices[i]))
            rsi_peaks.append((i, recent_rsi[i]))
        
        # Creux de prix
        if (recent_prices[i] < recent_prices[i-1] and 
            recent_prices[i] < recent_prices[i+1] and
            recent_prices[i] < recent_prices[i-2] and
            recent_prices[i] < recent_prices[i+2]):
            price_troughs.append((i, recent_prices[i]))
            rsi_troughs.append((i, recent_rsi[i]))
    
    # Détecter divergences baissières (bearish): prix fait des pics plus hauts, RSI fait des pics plus bas
    bearish_divergence = False
    if len(price_peaks) >= 2 and len(rsi_peaks) >= 2:
        last_price_peak = price_peaks[-1][1]
        prev_price_peak = price_peaks[-2][1]
        last_rsi_peak = rsi_peaks[-1][1]
        prev_rsi_peak = rsi_peaks[-2][1]
        
        if last_price_peak > prev_price_peak and last_rsi_peak < prev_rsi_peak:
            bearish_divergence = True
    
    # Détecter divergences haussières (bullish): prix fait des creux plus bas, RSI fait des creux plus hauts
    bullish_divergence = False
    if len(price_troughs) >= 2 and len(rsi_troughs) >= 2:
        last_price_trough = price_troughs[-1][1]
        prev_price_trough = price_troughs[-2][1]
        last_rsi_trough = rsi_troughs[-1][1]
        prev_rsi_trough = rsi_troughs[-2][1]
        
        if last_price_trough < prev_price_trough and last_rsi_trough > prev_rsi_trough:
            bullish_divergence = True
    
    # Calculer la force de la divergence
    strength = 0.0
    divergence_type = 'NONE'
    signal = 'NEUTRAL'
    
    if bearish_divergence:
        divergence_type = 'BEARISH'
        signal = 'SELL'
        # Force basée sur l'amplitude de la divergence
        price_diff = abs(price_peaks[-1][1] - price_peaks[-2][1]) / price_peaks[-2][1]
        rsi_diff = abs(rsi_peaks[-1][1] - rsi_peaks[-2][1])
        strength = min(1.0, (price_diff * 100 + rsi_diff) / 2)
    
    elif bullish_divergence:
        divergence_type = 'BULLISH'
        signal = 'BUY'
        # Force basée sur l'amplitude de la divergence
        price_diff = abs(price_troughs[-1][1] - price_troughs[-2][1]) / price_troughs[-2][1]
        rsi_diff = abs(rsi_troughs[-1][1] - rsi_troughs[-2][1])
        strength = min(1.0, (price_diff * 100 + rsi_diff) / 2)
    
    return {
        'divergence_type': divergence_type,
        'strength': round(strength, 3),
        'signal': signal
    }


# ============================================================================
# 7. DÉTECTION DE PATTERNS DE BOUGIES
# ============================================================================

def detect_candle_patterns(
    df: pd.DataFrame,
    lookback: int = 5
) -> Dict[str, Any]:
    """
    Détecte des patterns de bougies significatifs.
    
    Returns:
        Dict avec 'pattern_type', 'signal', 'reliability'
    """
    if len(df) < lookback + 2:
        return {
            'pattern_type': 'NONE',
            'signal': 'NEUTRAL',
            'reliability': 0.0
        }
    
    recent = df.tail(lookback + 2).copy()
    
    # Pattern: Engulfing Bullish
    # Bougie verte qui englobe complètement la bougie rouge précédente
    bullish_engulfing = False
    if len(recent) >= 2:
        prev_candle = recent.iloc[-2]
        curr_candle = recent.iloc[-1]
        
        if (prev_candle['close'] < prev_candle['open'] and  # Bougie rouge précédente
            curr_candle['close'] > curr_candle['open'] and  # Bougie verte actuelle
            curr_candle['open'] < prev_candle['close'] and  # Ouvre en dessous de la clôture précédente
            curr_candle['close'] > prev_candle['open']):     # Clôture au-dessus de l'ouverture précédente
            bullish_engulfing = True
    
    # Pattern: Engulfing Bearish
    # Bougie rouge qui englobe complètement la bougie verte précédente
    bearish_engulfing = False
    if len(recent) >= 2:
        prev_candle = recent.iloc[-2]
        curr_candle = recent.iloc[-1]
        
        if (prev_candle['close'] > prev_candle['open'] and  # Bougie verte précédente
            curr_candle['close'] < curr_candle['open'] and  # Bougie rouge actuelle
            curr_candle['open'] > prev_candle['close'] and  # Ouvre au-dessus de la clôture précédente
            curr_candle['close'] < prev_candle['open']):     # Clôture en dessous de l'ouverture précédente
            bearish_engulfing = True
    
    # Pattern: Hammer (marteau) - signal haussier
    hammer = False
    if len(recent) >= 1:
        candle = recent.iloc[-1]
        body = abs(candle['close'] - candle['open'])
        lower_shadow = min(candle['open'], candle['close']) - candle['low']
        upper_shadow = candle['high'] - max(candle['open'], candle['close'])
        
        # Mèche inférieure au moins 2x le corps, mèche supérieure petite
        if lower_shadow > body * 2 and upper_shadow < body * 0.5:
            hammer = True
    
    # Pattern: Shooting Star - signal baissier
    shooting_star = False
    if len(recent) >= 1:
        candle = recent.iloc[-1]
        body = abs(candle['close'] - candle['open'])
        lower_shadow = min(candle['open'], candle['close']) - candle['low']
        upper_shadow = candle['high'] - max(candle['open'], candle['close'])
        
        # Mèche supérieure au moins 2x le corps, mèche inférieure petite
        if upper_shadow > body * 2 and lower_shadow < body * 0.5:
            shooting_star = True
    
    # Déterminer le pattern et le signal
    pattern_type = 'NONE'
    signal = 'NEUTRAL'
    reliability = 0.0
    
    if bullish_engulfing:
        pattern_type = 'BULLISH_ENGULFING'
        signal = 'BUY'
        reliability = 0.75
    elif bearish_engulfing:
        pattern_type = 'BEARISH_ENGULFING'
        signal = 'SELL'
        reliability = 0.75
    elif hammer:
        pattern_type = 'HAMMER'
        signal = 'BUY'
        reliability = 0.65
    elif shooting_star:
        pattern_type = 'SHOOTING_STAR'
        signal = 'SELL'
        reliability = 0.65
    
    return {
        'pattern_type': pattern_type,
        'signal': signal,
        'reliability': reliability
    }


# ============================================================================
# 8. SYSTÈME DE SCORING MULTI-FACTEURS
# ============================================================================

def calculate_advanced_entry_score(
    df: pd.DataFrame,
    symbol: str,
    timeframe: str = "M1"
) -> Dict[str, Any]:
    """
    Calcule un score d'entrée multi-facteurs combinant:
    - Confiance des indicateurs
    - Momentum
    - Divergences
    - Patterns de bougies
    - Support/Résistance
    
    Returns:
        Dict avec 'entry_score' (0-1), 'direction', 'recommendation', 'factors'
    """
    if df is None or len(df) < 50:
        return {
            'entry_score': 0.0,
            'direction': 'NEUTRAL',
            'recommendation': 'HOLD',
            'factors': {},
            'reason': 'Données insuffisantes'
        }
    
    factors = {}
    
    # 1. Confiance des indicateurs (poids: 30%)
    confidence_data = calculate_advanced_confidence(df, symbol, timeframe)
    factors['confidence'] = confidence_data['confidence']
    base_direction = confidence_data['direction']
    
    # 2. Momentum (poids: 25%)
    momentum_data = calculate_momentum_score(df)
    factors['momentum'] = momentum_data['momentum_score']
    momentum_direction = momentum_data['direction']
    
    # 3. Divergences (poids: 20%)
    divergence_data = detect_divergence(df)
    factors['divergence'] = divergence_data['strength']
    divergence_signal = divergence_data['signal']
    
    # Bonus si divergence confirme la direction
    divergence_bonus = 0.0
    if divergence_signal == 'BUY' and base_direction == 'BULLISH':
        divergence_bonus = 0.15
    elif divergence_signal == 'SELL' and base_direction == 'BEARISH':
        divergence_bonus = 0.15
    
    # 4. Patterns de bougies (poids: 15%)
    pattern_data = detect_candle_patterns(df)
    factors['candle_pattern'] = pattern_data['reliability']
    pattern_signal = pattern_data['signal']
    
    # Bonus si pattern confirme la direction
    pattern_bonus = 0.0
    if pattern_signal == 'BUY' and base_direction == 'BULLISH':
        pattern_bonus = 0.10
    elif pattern_signal == 'SELL' and base_direction == 'BEARISH':
        pattern_bonus = 0.10
    
    # 5. Position relative au support/résistance (poids: 10%)
    sr_levels = detect_support_resistance_levels(df, lookback=min(100, len(df)))
    current_price = df['close'].iloc[-1]
    
    # Trouver le support/résistance le plus proche
    nearest_support = None
    nearest_resistance = None
    
    for support in sr_levels['supports']:
        if support < current_price and (nearest_support is None or support > nearest_support):
            nearest_support = support
    
    for resistance in sr_levels['resistances']:
        if resistance > current_price and (nearest_resistance is None or resistance < nearest_resistance):
            nearest_resistance = resistance
    
    # Score SR: proche d'un support = bon pour BUY, proche d'une résistance = bon pour SELL
    sr_score = 0.5
    if nearest_support and base_direction == 'BULLISH':
        distance_to_support = (current_price - nearest_support) / current_price
        if distance_to_support < 0.005:  # Moins de 0.5% du support
            sr_score = 0.9
        elif distance_to_support < 0.01:  # Moins de 1% du support
            sr_score = 0.7
    
    if nearest_resistance and base_direction == 'BEARISH':
        distance_to_resistance = (nearest_resistance - current_price) / current_price
        if distance_to_resistance < 0.005:  # Moins de 0.5% de la résistance
            sr_score = 0.9
        elif distance_to_resistance < 0.01:  # Moins de 1% de la résistance
            sr_score = 0.7
    
    factors['support_resistance'] = sr_score
    
    # Calcul du score d'entrée pondéré
    weights = {
        'confidence': 0.30,
        'momentum': 0.25,
        'divergence': 0.20,
        'candle_pattern': 0.15,
        'support_resistance': 0.10
    }
    
    base_score = sum(factors[k] * weights[k] for k in weights.keys())
    
    # Appliquer les bonus
    final_score = min(1.0, base_score + divergence_bonus + pattern_bonus)
    
    # Vérifier la cohérence des signaux
    signals = [base_direction, momentum_direction, divergence_signal, pattern_signal]
    bullish_signals = sum(1 for s in signals if s in ['BULLISH', 'BUY'])
    bearish_signals = sum(1 for s in signals if s in ['BEARISH', 'SELL'])
    
    # Pénalité si signaux contradictoires
    if bullish_signals > 0 and bearish_signals > 0:
        final_score *= 0.7  # Réduire le score en cas de contradiction
    
    # Déterminer la direction finale
    if bullish_signals > bearish_signals and final_score >= 0.65:
        direction = 'BULLISH'
        recommendation = 'BUY'
    elif bearish_signals > bullish_signals and final_score >= 0.65:
        direction = 'BEARISH'
        recommendation = 'SELL'
    else:
        direction = 'NEUTRAL'
        recommendation = 'HOLD'
        final_score *= 0.8  # Réduire le score si recommandation HOLD
    
    return {
        'entry_score': round(final_score, 3),
        'direction': direction,
        'recommendation': recommendation,
        'factors': {k: round(v, 3) for k, v in factors.items()},
        'consensus': round(max(bullish_signals, bearish_signals) / len([s for s in signals if s != 'NEUTRAL']), 2) if len([s for s in signals if s != 'NEUTRAL']) > 0 else 0.0,
        'reason': f'Score: {final_score:.1%}, Consensus: {bullish_signals}-{bearish_signals} signaux'
    }
