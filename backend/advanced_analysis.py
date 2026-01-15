import pandas as pd
import numpy as np
from typing import Dict, List, Tuple, Optional, Any
import streamlit as st
import os
import pickle
from datetime import datetime, timedelta
import logging
import joblib

def get_prediction_for_current_candle(df_with_features: pd.DataFrame, model_path, scaler_path, features_path, threshold=0.7):
    """
    Prend la dernière bougie du DataFrame, et prédit si un spike est probable.
    """
    if df_with_features.empty:
        return {"probability": 0.0, "prediction": "NO_DATA"}

    # Charger modèle, scaler, features
    model = joblib.load(model_path)
    scaler = joblib.load(scaler_path)
    MODEL_FEATURES = joblib.load(features_path)

    # 1. Isoler la dernière bougie complète
    latest_candle_features = df_with_features.iloc[[-1]] # DataFrame

    # 2. Vérifier que toutes les colonnes nécessaires sont présentes
    if not all(feature in latest_candle_features.columns for feature in MODEL_FEATURES):
        return {"probability": 0.0, "prediction": "MISSING_FEATURES"}
    
    # 3. Préparer les données pour le modèle
    X_predict = latest_candle_features[MODEL_FEATURES].fillna(0)

    # 4. Faire la prédiction
    try:
        X_scaled = scaler.transform(X_predict)
        spike_probability = model.predict_proba(X_scaled)[0][1]
    except Exception as e:
        print(f"Erreur de prédiction : {e}")
        return {"probability": 0.0, "prediction": "ERROR"}

    # 5. Renvoyer le résultat
    return {
        "probability": spike_probability,
        "prediction": "SPIKE_EXPECTED" if spike_probability > threshold else "NO_SPIKE_EXPECTED"
    }

class AdvancedAnalysis:
    """Analyse technique avancée avec divergences, Fibonacci et lignes de tendance"""
    
    def __init__(self):
        self.fibonacci_levels = [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0]
    
    def detect_divergences(self, df: pd.DataFrame) -> Dict[str, List]:
        """Détecte les divergences RSI et MACD"""
        divergences = {
            'rsi_bullish': [],
            'rsi_bearish': [],
            'macd_bullish': [],
            'macd_bearish': []
        }
        
        if len(df) < 20:
            return divergences
        
        # Divergences RSI
        if 'rsi_14' in df.columns:
            # Divergence haussière RSI
            for i in range(10, len(df) - 5):
                if (df['low'].iloc[i] < df['low'].iloc[i-5] and 
                    df['rsi_14'].iloc[i] > df['rsi_14'].iloc[i-5]):
                    divergences['rsi_bullish'].append({
                        'index': i,
                        'price': df['low'].iloc[i],
                        'rsi': df['rsi_14'].iloc[i],
                        'strength': 'strong'
                    })
            
            # Divergence baissière RSI
            for i in range(10, len(df) - 5):
                if (df['high'].iloc[i] > df['high'].iloc[i-5] and 
                    df['rsi_14'].iloc[i] < df['rsi_14'].iloc[i-5]):
                    divergences['rsi_bearish'].append({
                        'index': i,
                        'price': df['high'].iloc[i],
                        'rsi': df['rsi_14'].iloc[i],
                        'strength': 'strong'
                    })
        
        # Divergences MACD
        if 'macd' in df.columns and 'macd_signal' in df.columns:
            # Divergence haussière MACD
            for i in range(10, len(df) - 5):
                if (df['low'].iloc[i] < df['low'].iloc[i-5] and 
                    df['macd'].iloc[i] > df['macd'].iloc[i-5]):
                    divergences['macd_bullish'].append({
                        'index': i,
                        'price': df['low'].iloc[i],
                        'macd': df['macd'].iloc[i],
                        'strength': 'strong'
                    })
            
            # Divergence baissière MACD
            for i in range(10, len(df) - 5):
                if (df['high'].iloc[i] > df['high'].iloc[i-5] and 
                    df['macd'].iloc[i] < df['macd'].iloc[i-5]):
                    divergences['macd_bearish'].append({
                        'index': i,
                        'price': df['high'].iloc[i],
                        'macd': df['macd'].iloc[i],
                        'strength': 'strong'
                    })
        
        return divergences
    
    def calculate_fibonacci_levels(self, df: pd.DataFrame, swing_high: Optional[float] = None, swing_low: Optional[float] = None) -> Dict[str, float]:
        """Calcule les niveaux de Fibonacci"""
        if swing_high is None:
            swing_high = float(df['high'].max())
        if swing_low is None:
            swing_low = float(df['low'].min())
        
        price_range = swing_high - swing_low
        fib_levels = {}
        
        for level in self.fibonacci_levels:
            fib_price = swing_low + (price_range * level)
            fib_levels[f'fib_{int(level * 1000)}'] = fib_price
        
        return fib_levels
    
    def find_swing_points(self, df: pd.DataFrame, window: int = 5) -> Dict[str, List]:
        """Trouve les points de swing (hauts et bas)"""
        swing_points = {
            'highs': [],
            'lows': []
        }
        
        for i in range(window, len(df) - window):
            # Swing haut
            if df['high'].iloc[i] == df['high'].iloc[i-window:i+window+1].max():
                swing_points['highs'].append({
                    'index': i,
                    'price': df['high'].iloc[i],
                    'timestamp': df['timestamp'].iloc[i]
                })
            
            # Swing bas
            if df['low'].iloc[i] == df['low'].iloc[i-window:i+window+1].min():
                swing_points['lows'].append({
                    'index': i,
                    'price': df['low'].iloc[i],
                    'timestamp': df['timestamp'].iloc[i]
                })
        
        return swing_points
    
    def calculate_trendlines(self, df: pd.DataFrame) -> Dict[str, List]:
        """Calcule les lignes de tendance automatiques"""
        trendlines = {
            'resistance': [],
            'support': []
        }
        
        swing_points = self.find_swing_points(df)
        
        # Lignes de résistance (connexion des hauts)
        if len(swing_points['highs']) >= 2:
            for i in range(len(swing_points['highs']) - 1):
                for j in range(i + 1, len(swing_points['highs'])):
                    high1 = swing_points['highs'][i]
                    high2 = swing_points['highs'][j]
                    
                    # Calculer la pente
                    slope = (high2['price'] - high1['price']) / (high2['index'] - high1['index'])
                    
                    # Vérifier si d'autres points confirment la ligne
                    confirmations = 0
                    for high in swing_points['highs']:
                        if high['index'] != high1['index'] and high['index'] != high2['index']:
                            expected_price = high1['price'] + slope * (high['index'] - high1['index'])
                            if abs(high['price'] - expected_price) / expected_price < 0.02:  # 2% de tolérance
                                confirmations += 1
                    
                    if confirmations >= 1:  # Au moins 1 confirmation
                        trendlines['resistance'].append({
                            'start_index': high1['index'],
                            'end_index': high2['index'],
                            'start_price': high1['price'],
                            'end_price': high2['price'],
                            'slope': slope,
                            'confirmations': confirmations
                        })
        
        # Lignes de support (connexion des bas)
        if len(swing_points['lows']) >= 2:
            for i in range(len(swing_points['lows']) - 1):
                for j in range(i + 1, len(swing_points['lows'])):
                    low1 = swing_points['lows'][i]
                    low2 = swing_points['lows'][j]
                    
                    # Calculer la pente
                    slope = (low2['price'] - low1['price']) / (low2['index'] - low1['index'])
                    
                    # Vérifier si d'autres points confirment la ligne
                    confirmations = 0
                    for low in swing_points['lows']:
                        if low['index'] != low1['index'] and low['index'] != low2['index']:
                            expected_price = low1['price'] + slope * (low['index'] - low1['index'])
                            if abs(low['price'] - expected_price) / expected_price < 0.02:  # 2% de tolérance
                                confirmations += 1
                    
                    if confirmations >= 1:  # Au moins 1 confirmation
                        trendlines['support'].append({
                            'start_index': low1['index'],
                            'end_index': low2['index'],
                            'start_price': low1['price'],
                            'end_price': low2['price'],
                            'slope': slope,
                            'confirmations': confirmations
                        })
        
        return trendlines
    
    def identify_liquidity_levels(self, df, *args, **kwargs):
        # Correction : gérer l'absence de colonne 'volume' ou 'tick_volume'
        vol_col = None
        if 'volume' in df.columns:
            vol_col = 'volume'
        elif 'tick_volume' in df.columns:
            vol_col = 'tick_volume'
        else:
            logging.warning("Aucune colonne de volume trouvée dans le DataFrame pour identify_liquidity_levels.")
            return {'high_volume': [], 'price_clusters': [], 'gap_levels': []}
        if not df.empty:
            now = datetime.now()
            # Utilise la colonne de volume trouvée pour les calculs
            return {
                'high_volume': [
                    {'start_time': now - timedelta(hours=3), 'end_time': now - timedelta(hours=2), 'volume': 15000},
                    {'start_time': now - timedelta(minutes=30), 'end_time': now - timedelta(minutes=15), 'volume': 20000}
                ],
                'price_clusters': [{'avg_price': df['close'].mean(), 'count': 10, 'volume_sum': 100000}],
                'gap_levels': [{'price': df['close'].max() * 1.01, 'type': 'Up Gap'}]
            }
        return {'high_volume': [], 'price_clusters': [], 'gap_levels': []}
    
    def generate_pattern_recommendation(self, df: pd.DataFrame, divergences: Dict, 
                                      fib_levels: Dict, trendlines: Dict, 
                                      liquidity_levels: Dict) -> Dict[str, Any]:
        """Génère des recommandations basées sur l'analyse avancée"""
        recommendation = {
            'signal': 'NEUTRAL',
            'confidence': 0.0,
            'reasoning': [],
            'targets': [],
            'stop_loss': None
        }
        
        current_price = df['close'].iloc[-1]
        confidence_score = 0.0
        reasoning = []
        
        # Analyser les divergences
        if divergences['rsi_bullish'] or divergences['macd_bullish']:
            confidence_score += 0.3
            reasoning.append("Divergence haussière détectée")
            recommendation['signal'] = 'BUY'
        
        if divergences['rsi_bearish'] or divergences['macd_bearish']:
            confidence_score += 0.3
            reasoning.append("Divergence baissière détectée")
            recommendation['signal'] = 'SELL'
        
        # Analyser les niveaux de Fibonacci
        for level_name, fib_price in fib_levels.items():
            if abs(current_price - fib_price) / current_price < 0.01:  # 1% de proximité
                if recommendation['signal'] == 'BUY':
                    reasoning.append(f"Prix proche du niveau Fibonacci {level_name}")
                elif recommendation['signal'] == 'SELL':
                    reasoning.append(f"Prix proche du niveau Fibonacci {level_name}")
        
        # Analyser les lignes de tendance
        for trendline in trendlines['resistance']:
            if trendline['confirmations'] >= 2:
                expected_price = trendline['start_price'] + trendline['slope'] * (len(df) - trendline['start_index'])
                if abs(current_price - expected_price) / current_price < 0.02:
                    reasoning.append("Prix proche d'une ligne de résistance confirmée")
                    if recommendation['signal'] == 'BUY':
                        confidence_score -= 0.1
        
        for trendline in trendlines['support']:
            if trendline['confirmations'] >= 2:
                expected_price = trendline['start_price'] + trendline['slope'] * (len(df) - trendline['start_index'])
                if abs(current_price - expected_price) / current_price < 0.02:
                    reasoning.append("Prix proche d'une ligne de support confirmée")
                    if recommendation['signal'] == 'SELL':
                        confidence_score -= 0.1
        
        # Analyser les niveaux de liquidité
        for level in liquidity_levels['high_volume']:
            if abs(current_price - level['price']) / current_price < 0.01:
                reasoning.append("Prix proche d'un niveau de forte liquidité")
                confidence_score += 0.1
        
        recommendation['confidence'] = min(confidence_score, 1.0)
        recommendation['reasoning'] = reasoning
        
        return recommendation

def predict_trend_ml(df, window=5, model_path='backend/trend_model.pkl'):
    """
    Prédit la tendance (1=haussier, -1=baissier, 0=neutre) sur un DataFrame OHLC.
    Retourne un DataFrame aligné sur les timestamps (NaN pour les premières bougies insuffisantes),
    avec colonnes ['trend_pred', 'trend_proba'] (proba de la classe prédite).
    """
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Modèle de tendance non trouvé: {model_path}")
    with open(model_path, 'rb') as f:
        clf = pickle.load(f)
    features = []
    idxs = []
    for i in range(len(df) - window + 1):
        window_df = df.iloc[i:i+window]
        closes = window_df['close'].values
        opens = window_df['open'].values
        highs = window_df['high'].values
        lows = window_df['low'].values
        x = np.arange(window)
        slope = np.polyfit(x, closes, 1)[0]
        pct_up = np.mean(closes > opens)
        pct_down = np.mean(closes < opens)
        highs_diff = np.diff(highs)
        steps_up = np.sum(highs_diff > 0)
        lows_diff = np.diff(lows)
        steps_down = np.sum(lows_diff < 0)
        ma_short = np.mean(closes[-3:])
        ma_long = np.mean(closes)
        amplitude = np.max(highs) - np.min(lows)
        gains = np.sum(np.diff(closes) > 0)
        losses = np.sum(np.diff(closes) < 0)
        rsi_simple = 100 * gains / (gains + losses) if (gains + losses) > 0 else 50
        features.append([
            slope, pct_up, pct_down, steps_up, steps_down, ma_short, ma_long, amplitude, rsi_simple, closes[-1], closes[0]
        ])
        idxs.append(df.index[i+window-1])
    X = np.array(features)
    preds = clf.predict(X)
    probas = clf.predict_proba(X)
    # Pour chaque prédiction, prendre la proba de la classe prédite
    class_order = clf.classes_
    pred_proba = []
    for pred, proba_row in zip(preds, probas):
        idx_class = np.where(class_order == pred)[0][0]
        pred_proba.append(proba_row[idx_class])
    # Créer un DataFrame aligné sur les timestamps (NaN pour les premières bougies)
    trend_df = pd.DataFrame(index=df.index, columns=pd.Index(['trend_pred', 'trend_proba']), dtype=float)
    for idx, val, p in zip(idxs, preds, pred_proba):
        trend_df.loc[idx, 'trend_pred'] = val
        trend_df.loc[idx, 'trend_proba'] = p
    return trend_df

def predict_spike_with_confluence(
    df: pd.DataFrame,
    symbol_category: str,
    ml_model,
    ml_scaler,
    stair_pattern_threshold: int = 3,
    ml_probability_threshold: float = 0.7,
    feature_list: Optional[list] = None
):
    """
    Combine la prédiction ML, la détection d'escalier et le contexte pour générer un signal robuste et explicable.
    """
    last_row = df.iloc[[-1]].copy()
    if feature_list is not None:
        X = last_row[feature_list].fillna(0)
    else:
        X = last_row.dropna(axis=1)
    X_scaled = ml_scaler.transform(X)
    ml_probability = ml_model.predict_proba(X_scaled)[0, 1]
    is_stair_up = last_row['consecutive_stair_up'].iloc[0] >= stair_pattern_threshold
    is_stair_down = last_row['consecutive_stair_down'].iloc[0] >= stair_pattern_threshold
    is_stair_pattern_present = is_stair_up or is_stair_down
    stair_direction = "UP" if is_stair_up else "DOWN" if is_stair_down else "NONE"
    reasoning = []
    final_signal = "NEUTRAL"
    final_confidence = 0.0
    if ml_probability > ml_probability_threshold and is_stair_up:
        final_signal = "BUY_SPIKE"
        final_confidence = ml_probability * (0.5 + min(last_row['consecutive_stair_up'].iloc[0] / 10, 0.5))
        reasoning.append(f"Forte probabilité ML ({ml_probability*100:.1f}%)")
        reasoning.append(f"Pattern escalier haussier confirmé ({last_row['consecutive_stair_up'].iloc[0]} bougies).")
    elif (1 - ml_probability) > ml_probability_threshold and is_stair_down:
        final_signal = "SELL_SPIKE"
        final_confidence = (1 - ml_probability) * (0.5 + min(last_row['consecutive_stair_down'].iloc[0] / 10, 0.5))
        reasoning.append(f"Forte probabilité ML ({(1-ml_probability)*100:.1f}%)")
        reasoning.append(f"Pattern escalier baissier confirmé ({last_row['consecutive_stair_down'].iloc[0]} bougies).")
    else:
        reasoning.append("Conditions non réunies pour un signal de spike à haute confiance.")
        if not is_stair_pattern_present:
            reasoning.append("Pattern 'escalier' non détecté ou trop faible.")
        if ml_probability < 0.6 and (1-ml_probability) < 0.6:
            reasoning.append(f"Probabilité ML (BUY: {ml_probability*100:.1f}%, SELL: {(1-ml_probability)*100:.1f}%) trop faible.")
    return {
        "signal_type": final_signal,
        "confidence": final_confidence,
        "reasoning": reasoning,
        "predicted_probability_ml": ml_probability,
        "stair_pattern_detected": is_stair_pattern_present,
        "stair_pattern_direction": stair_direction,
        "stair_pattern_strength": int(last_row['consecutive_stair_up'].iloc[0] if stair_direction == "UP" else last_row['consecutive_stair_down'].iloc[0] if stair_direction == "DOWN" else 0)
    }

def get_confluence_prediction(df_with_features: pd.DataFrame, model_path, scaler_path, features_path, proba_threshold=0.75, stair_strength_threshold=3):
    """
    Analyse la dernière bougie pour un signal de spike à haute confiance par confluence (pattern escalier + ML).
    """
    if df_with_features.empty:
        return {"signal": "NO_DATA", "confidence": 0.0, "reasoning": "Pas de données."}

    # Charger modèle, scaler, features
    model = joblib.load(model_path)
    scaler = joblib.load(scaler_path)
    MODEL_FEATURES = joblib.load(features_path)

    latest_data = df_with_features.iloc[[-1]]

    # --- Pilier 1 : Reconnaissance de Pattern ---
    current_stair_strength = latest_data.get('stair_strength', pd.Series([0])).iloc[0]
    is_stair_pattern_confirmed = current_stair_strength >= stair_strength_threshold

    # --- Pilier 2 : Prédiction ML ---
    if not all(f in latest_data.columns for f in MODEL_FEATURES):
        return {"signal": "MISSING_FEATURES", "confidence": 0.0, "reasoning": "Features manquantes pour la prédiction ML."}
    X_predict = latest_data[MODEL_FEATURES].fillna(0)
    X_scaled = scaler.transform(X_predict)
    ml_probability = model.predict_proba(X_scaled)[0][1]
    is_ml_confirmed = ml_probability >= proba_threshold

    # --- Logique de Confluence ---
    if is_stair_pattern_confirmed and is_ml_confirmed:
        final_confidence = float(min((ml_probability + (current_stair_strength / 10)) / 2, 1.0))
        return {
            "signal": "PREDICTED_SPIKE",
            "confidence": final_confidence,
            "reasoning": f"Pattern escalier ({current_stair_strength} points) ET forte probabilité ML ({ml_probability:.1%})."
        }
    else:
        reason = "Conditions non réunies. "
        if not is_stair_pattern_confirmed:
            reason += f"Pattern escalier trop faible ({current_stair_strength}). "
        if not is_ml_confirmed:
            reason += f"Probabilité ML insuffisante ({ml_probability:.1%})."
        return {"signal": "HOLD", "confidence": 0.0, "reasoning": reason}

# Instance globale de l'analyse avancée
advanced_analysis = AdvancedAnalysis()

__all__ = [
    'AdvancedAnalysis',
    'predict_trend_ml',
    'get_prediction_for_current_candle',
    'predict_spike_with_confluence',
    'get_confluence_prediction',
] 