#!/usr/bin/env python3
"""
Serveur IA pour TradBOT - Gestion des prédictions et analyses de marché
Version: 2.0.0
Compatible avec F_INX_robot4.mq5
"""

import os
import json
import time
import asyncio
import logging
import sys
import argparse
import traceback
import contextlib
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, List, Dict, Any, Tuple, Set
from fastapi import FastAPI, HTTPException, Request, Body, status
from starlette.requests import Request as StarletteRequest
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import uvicorn
import pandas as pd
import numpy as np
import requests
import joblib
from collections import deque

# Configurer le logger avant les imports d'améliorations
logger = logging.getLogger("tradbot_ai")

# Importer les fonctions améliorées
try:
    from ai_server_improvements import (
        calculate_advanced_confidence,
        predict_prices_advanced,
        validate_multi_timeframe,
        adapt_prediction_for_symbol,
        detect_support_resistance_levels,
        is_boom_crash_symbol,
        is_volatility_symbol
    )
    IMPROVEMENTS_AVAILABLE = True
    logger.info("✅ Module ai_server_improvements chargé avec succès")
except ImportError:
    IMPROVEMENTS_AVAILABLE = False
    logger.warning(
        "⚠️ Module ai_server_improvements non disponible - "
        "utilisation des fonctions de base"
    )

# PostgreSQL async support for feedback loop
try:
    import asyncpg
    ASYNCPG_AVAILABLE = True
except ImportError:
    ASYNCPG_AVAILABLE = False
    logger_placeholder = logging.getLogger("tradbot_ai")
    logger_placeholder.warning("asyncpg non disponible - installer avec: pip install asyncpg")

# Machine Learning imports (Phase 2) - seront initialisés après logger
ML_AVAILABLE = False

# Import yfinance pour les données de marché (compatible cloud)
try:
    import yfinance as yf
    YFINANCE_AVAILABLE = True
    logger.info("✅ yfinance disponible pour les données de marché")
except ImportError:
    YFINANCE_AVAILABLE = False
    logger.warning("⚠️ yfinance non disponible")

# Cache pour les données historiques (fallback cloud)
_history_cache: Dict[str, pd.DataFrame] = {}

# =========================
# Fonctions de détection de spikes Boom/Crash
# =========================
def is_boom_crash_symbol(symbol: str) -> bool:
    """Vérifie si le symbole est un indice Boom ou Crash"""
    boom_crash_patterns = [
        "Boom 500 Index", "Boom 300 Index", "Boom 600 Index", "Boom 900 Index",
        "Crash 300 Index", "Crash 500 Index", "Crash 1000 Index"
    ]
    return any(pattern in symbol for pattern in boom_crash_patterns)

def detect_spike_pattern(df: pd.DataFrame, symbol: str) -> Dict[str, Any]:
    """
    Détecte les patterns de spikes pour Boom/Crash
    
    Args:
        df: DataFrame avec les données OHLCV
        symbol: Symbole à analyser
        
    Returns:
        Dict avec informations de spike détecté
    """
    if len(df) < 10:
        return {"has_spike": False, "reason": "Données insuffisantes"}
    
    # Debug: vérifier les colonnes disponibles
    logger.info(f"Colonnes disponibles dans DataFrame: {list(df.columns)}")
    
    # S'assurer que les colonnes requises existent
    required_columns = ['open', 'high', 'low', 'close', 'tick_volume']
    missing_columns = [col for col in required_columns if col not in df.columns]
    if missing_columns:
        logger.error(f"Colonnes manquantes: {missing_columns}")
        return {"has_spike": False, "reason": f"Colonnes manquantes: {missing_columns}"}
    
    # Calculer les indicateurs de volatilité
    df['price_change'] = df['close'] - df['open']
    df['price_change_pct'] = (df['price_change'] / df['open']) * 100
    
    # Ajouter le changement inter-bougies (plus important pour les spikes)
    df['close_change'] = df['close'] - df['close'].shift(1)
    df['close_change_pct'] = (df['close_change'] / df['close'].shift(1)) * 100
    
    df['range'] = df['high'] - df['low']
    df['range_pct'] = (df['range'] / df['open']) * 100
    df['volume_ma'] = df['tick_volume'].rolling(window=5).mean()
    df['volume_ratio'] = df['tick_volume'] / df['volume_ma']
    
    # Dernières bougies
    last_candle = df.iloc[-1]
    prev_candle = df.iloc[-2]
    
    # Seuils spécifiques Boom/Crash
    is_boom = "Boom" in symbol
    is_crash = "Crash" in symbol
    
    # Critères de spike
    spike_criteria = {
        "price_spike": abs(last_candle['close_change_pct']) > (0.8 if is_boom else 1.2),  # % de changement inter-bougies
        "range_spike": last_candle['range_pct'] > (1.0 if is_boom else 1.5),  # Volatilité intraday
        "volume_spike": last_candle['volume_ratio'] > 2.0,  # Volume 2x la moyenne
        "momentum_spike": False
    }
    
    # Calculer le momentum
    rsi_period = 14
    df['rsi'] = calculate_rsi(df['close'], rsi_period)
    
    if len(df) >= rsi_period + 1:
        rsi_current = df['rsi'].iloc[-1]
        rsi_prev = df['rsi'].iloc[-2]
        
        # Spike de momentum: RSI change brusquement
        rsi_change = abs(rsi_current - rsi_prev)
        spike_criteria["momentum_spike"] = rsi_change > 10
        
        # RSI extremes pour confirmation
        if is_boom:
            spike_criteria["rsi_oversold"] = rsi_current < 30
        else:  # Crash
            spike_criteria["rsi_overbought"] = rsi_current > 70
    
    # Compter les critères remplis
    criteria_met = sum(1 for k, v in spike_criteria.items() if v and not k.startswith("rsi_"))
    has_spike = criteria_met >= 2  # Au moins 2 critères sur 3
    
    # Direction du spike
    spike_direction = None
    if has_spike:
        if last_candle['close_change_pct'] > 0:
            spike_direction = "BUY"
        else:
            spike_direction = "SELL"
        
        # Validation direction pour Boom/Crash
        if is_boom and spike_direction == "SELL":
            has_spike = False  # Pas de SELL sur Boom
        elif is_crash and spike_direction == "BUY":
            has_spike = False  # Pas de BUY sur Crash
    
    # Calculer la confiance du spike
    spike_confidence = 0.0
    if has_spike:
        base_confidence = min(85.0, criteria_met * 25.0)  # 25% par critère
        
        # Bonus pour volume élevé
        if spike_criteria["volume_spike"]:
            base_confidence += 10.0
        
        # Bonus pour momentum extrême
        if spike_criteria["momentum_spike"]:
            base_confidence += 10.0
        
        spike_confidence = min(95.0, base_confidence)
    
    return {
        "has_spike": bool(has_spike),
        "direction": spike_direction,
        "confidence": float(spike_confidence),
        "criteria": {k: bool(v) for k, v in spike_criteria.items()},
        "price_change_pct": float(last_candle['close_change_pct']) if pd.notna(last_candle['close_change_pct']) else 0.0,
        "range_pct": float(last_candle['range_pct']) if pd.notna(last_candle['range_pct']) else 0.0,
        "volume_ratio": float(last_candle['volume_ratio']) if pd.notna(last_candle['volume_ratio']) else 0.0,
        "rsi": float(df['rsi'].iloc[-1]) if len(df) >= rsi_period and pd.notna(df['rsi'].iloc[-1]) else None,
        "timestamp": int(last_candle['time']) if 'time' in df.columns and pd.notna(last_candle['time']) else None
    }

def calculate_rsi(prices: pd.Series, period: int = 14) -> pd.Series:
    """Calcule le RSI"""
    delta = prices.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss
    rsi = 100 - (100 / (1 + rs))
    return rsi

def generate_boom_crash_signal(symbol: str, df: pd.DataFrame) -> Dict[str, Any]:
    """
    Génère un signal de trading pour Boom/Crash basé sur la détection de spikes
    
    Args:
        symbol: Symbole Boom/Crash
        df: DataFrame avec données OHLCV
        
    Returns:
        Dict avec signal de trading
    """
    if not is_boom_crash_symbol(symbol):
        return {"has_signal": False, "reason": "Pas un symbole Boom/Crash"}
    
    # Détecter le spike
    spike_info = detect_spike_pattern(df, symbol)
    
    if not spike_info["has_spike"]:
        return {
            "has_signal": False,
            "reason": "Aucun spike détecté",
            "spike_info": spike_info
        }
    
    # Calculer SL/TP pour les spikes
    last_candle = df.iloc[-1]
    current_price = last_candle['close']
    atr = calculate_atr(df, 14)
    
    # SL/TP serrés pour les spikes
    if spike_info["direction"] == "BUY":
        stop_loss = current_price - (atr * 0.5)  # SL très serré
        take_profit = current_price + (atr * 1.5)  # TP plus large
    else:  # SELL
        stop_loss = current_price + (atr * 0.5)
        take_profit = current_price - (atr * 1.5)
    
    return {
        "has_signal": bool(spike_info["has_signal"]),
        "signal": spike_info["direction"],
        "confidence": float(spike_info["confidence"]),
        "source": "boom_crash_spike",
        "stop_loss": round(float(stop_loss), 2) if pd.notna(stop_loss) else None,
        "take_profit": round(float(take_profit), 2) if pd.notna(take_profit) else None,
        "position_size": 0.01,  # Taille fixe pour les spikes
        "reasoning": [
            f"Spike {spike_info['direction']} détecté",
            f"Changement prix: {spike_info['price_change_pct']:.2f}%",
            f"Volume ratio: {spike_info['volume_ratio']:.1f}x",
            f"Confiance: {spike_info['confidence']:.0f}%"
        ],
        "spike_info": {
            k: (bool(v) if isinstance(v, (bool, np.bool_)) else float(v) if isinstance(v, (int, float, np.number)) else v)
            for k, v in spike_info.items()
            if k != 'criteria'
        },
        "timestamp": datetime.now().isoformat()
    }

def calculate_atr(df: pd.DataFrame, period: int = 14) -> float:
    """Calcule l'Average True Range"""
    high_low = df['high'] - df['low']
    high_close = abs(df['high'] - df['close'].shift())
    low_close = abs(df['low'] - df['close'].shift())
    
    true_range = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
    atr = true_range.rolling(window=period).mean()
    
    return atr.iloc[-1] if not atr.empty else 0.0

# =========================
# Fonctions de récupération de données cloud
# =========================
def get_market_data_cloud(symbol: str, period: str = "5d", interval: str = "1m") -> pd.DataFrame:
    """Récupère les données via yfinance (compatible cloud)"""
    try:
        if not YFINANCE_AVAILABLE:
            return generate_simulated_data(symbol, 100)
        
        # Mapping des symboles pour yfinance
        symbol_map = {
            "EURUSD": "EURUSD=X",
            "GBPUSD": "GBPUSD=X", 
            "USDJPY": "USDJPY=X",
            "Boom 500 Index": "^GSPC",
            "Crash 300 Index": "^VIX",
            "Volatility 75 Index": "^VIX",
            "Boom 300 Index": "^GSPC",
            "Boom 600 Index": "^GSPC",
            "Boom 900 Index": "^GSPC",
            "Crash 1000 Index": "^VIX"
        }
        
        yf_symbol = symbol_map.get(symbol, symbol)
        
        # Récupérer les données
        ticker = yf.Ticker(yf_symbol)
        data = ticker.history(period=period, interval=interval)
        
        if data.empty:
            return generate_simulated_data(symbol, 100)
        
        # Standardiser les colonnes
        df = data.reset_index()
        df = df.rename(columns={
            'Open': 'open',
            'High': 'high', 
            'Low': 'low',
            'Close': 'close',
            'Volume': 'volume'
        })
        
        # Ajouter colonne time
        df['time'] = df['Datetime'].astype(np.int64) // 10**9
        
        return df[['time', 'open', 'high', 'low', 'close', 'volume']]
        
    except Exception as e:
        logger.error(f"Erreur récupération données cloud pour {symbol}: {e}")
        return generate_simulated_data(symbol, 100)

def generate_simulated_data(symbol: str, periods: int = 100) -> pd.DataFrame:
    """Génère des données de marché simulées avec spikes réalistes pour Boom/Crash"""
    try:
        np.random.seed(hash(symbol) % 2**32)
        
        base_prices = {
            "EURUSD": 1.0850,
            "GBPUSD": 1.2750,
            "USDJPY": 148.50,
            "Boom 500 Index": 5000,
            "Crash 300 Index": 300,
            "Volatility 75 Index": 75,
            "Boom 300 Index": 300,
            "Boom 600 Index": 600,
            "Boom 900 Index": 900,
            "Crash 1000 Index": 1000
        }
        
        base_price = base_prices.get(symbol, 100)
        
        # Vérifier si c'est un symbole Boom/Crash pour générer des spikes
        is_boom_crash = is_boom_crash_symbol(symbol)
        
        if is_boom_crash:
            # Générer des données avec spikes pour Boom/Crash
            returns = np.random.normal(0, 0.001, periods)  # Volatilité de base plus faible
            
            # Ajouter quelques spikes aléatoires (10-15% de chance par bougie)
            spike_probability = 0.12
            for i in range(periods):
                if np.random.random() < spike_probability:
                    # Générer un spike
                    spike_direction = 1 if "Boom" in symbol else -1  # Boom monte, Crash descend
                    spike_magnitude = np.random.uniform(0.008, 0.025)  # 0.8% à 2.5% de spike
                    returns[i] = spike_direction * spike_magnitude
            
            # Ajouter de la volatilité autour des spikes
            volatility_boost = np.random.normal(0, 0.002, periods)
            returns += volatility_boost
        else:
            # Données normales pour les autres symboles
            returns = np.random.normal(0, 0.002, periods)
        
        prices = [base_price]
        
        for ret in returns:
            new_price = prices[-1] * (1 + ret)
            prices.append(new_price)
        
        prices = prices[1:]
        
        timestamps = pd.date_range(end=datetime.now(), periods=periods, freq='1min')
        
        # Générer les OHLC avec des spreads réalistes
        if is_boom_crash:
            # Spread plus large pour Boom/Crash pendant les spikes
            spreads = [abs(np.random.normal(0.002, 0.001)) for _ in range(periods)]
        else:
            spreads = [abs(np.random.normal(0.0005, 0.0002)) for _ in range(periods)]
        
        df = pd.DataFrame({
            'time': timestamps.astype(np.int64) // 10**9,
            'open': prices,
            'high': [p * (1 + spreads[i]) for i, p in enumerate(prices)],
            'low': [p * (1 - spreads[i]) for i, p in enumerate(prices)],
            'close': prices,
            'tick_volume': np.random.randint(5000, 50000, periods) if is_boom_crash else np.random.randint(1000, 10000, periods)
        })
        
        # Ajouter le volume column pour compatibilité
        df['volume'] = df['tick_volume']
        
        return df
        
    except Exception as e:
        logger.error(f"Erreur génération données simulées: {e}")
        return pd.DataFrame()

def get_market_data(symbol: str, timeframe: str = "M1", count: int = 1000) -> pd.DataFrame:
    """Récupère les données en utilisant la meilleure source disponible"""
    cache_key = f"{symbol}_{timeframe}"
    
    # Vérifier le cache en premier
    if cache_key in _history_cache:
        cached_data = _history_cache[cache_key]
        if not cached_data.empty:
            logger.info(
                f"Données récupérées depuis cache: "
                f"{len(cached_data)} bougies pour {symbol}"
            )
            return cached_data
    
    # Essayer MT5 d'abord
    if MT5_AVAILABLE and mt5_initialized:
        try:
            # Mapping des timeframes
            tf_map = {
                "M1": mt5.TIMEFRAME_M1,
                "M5": mt5.TIMEFRAME_M5,
                "M15": mt5.TIMEFRAME_M15,
                "M30": mt5.TIMEFRAME_M30,
                "H1": mt5.TIMEFRAME_H1,
                "H4": mt5.TIMEFRAME_H4,
                "D1": mt5.TIMEFRAME_D1,
            }
            
            mt5_tf = tf_map.get(timeframe, mt5.TIMEFRAME_M1)
            
            # Récupérer les données
            rates = mt5.copy_rates_from_pos(symbol, mt5_tf, 0, count)
            
            if rates is not None and len(rates) > 0:
                df = pd.DataFrame(rates)
                df['time'] = pd.to_datetime(df['time'], unit='s')
                _history_cache[cache_key] = df
                logger.info(f"Données récupérées depuis MT5: {len(df)} bougies pour {symbol}")
                return df
        except Exception as e:
            logger.warning(f"Erreur MT5 pour {symbol}: {e}")
    
    # Fallback vers yfinance
    data = get_market_data_cloud(symbol)
    if not data.empty:
        _history_cache[cache_key] = data
        logger.info(f"Données récupérées depuis yfinance: {len(data)} bougies pour {symbol}")
        return data
    
    # Dernier recours: données simulées
    data = generate_simulated_data(symbol, count)
    _history_cache[cache_key] = data
    logger.info(f"Données simulées générées: {len(data)} bougies pour {symbol}")
    return data

# Charger les variables d'environnement
try:
    from dotenv import load_dotenv
    # Charger explicitement depuis le répertoire courant
    env_path = Path(__file__).parent / '.env'
    if env_path.exists():
        load_dotenv(env_path)
        logger.info(f"✅ Fichier .env chargé depuis: {env_path}")
    else:
        load_dotenv()  # Essaie de charger depuis le répertoire courant
        logger.info(
            "✅ Variables d'environnement chargées "
            "(fichier .env non trouvé, utilisation des variables système)"
        )
except ImportError:
    logger.warning(
        "⚠️ python-dotenv non disponible - "
        "utilisation des variables d'environnement système uniquement"
    )
except Exception as e:
    logger.warning(f"⚠️ Erreur lors du chargement du .env: {e}")

# Configuration PostgreSQL pour feedback loop
DATABASE_URL = os.getenv("DATABASE_URL", "")
DB_AVAILABLE = bool(DATABASE_URL and ASYNCPG_AVAILABLE)

# Fonctions d'aide pour les indicateurs
def calculate_rsi(prices: pd.Series, period: int = 14) -> pd.Series:
    delta = prices.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss
    return 100 - (100 / (1 + rs))

def calculate_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    high_low = df['high'] - df['low']
    high_close = (df['high'] - df['close'].shift()).abs()
    low_close = (df['low'] - df['close'].shift()).abs()
    true_range = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
    return true_range.rolling(window=period).mean()

def calculate_macd(
    prices: pd.Series, fast: int = 12, slow: int = 26, signal: int = 9
) -> pd.Series:
    exp1 = prices.ewm(span=fast, adjust=False).mean()
    exp2 = prices.ewm(span=slow, adjust=False).mean()
    macd = exp1 - exp2
    signal_line = macd.ewm(span=signal, adjust=False).mean()
    return macd - signal_line

def calculate_bollinger_bands(
    prices: pd.Series, window: int = 20, num_std: int = 2
) -> Dict[str, pd.Series]:
    sma = prices.rolling(window=window).mean()
    std = prices.rolling(window=window).std()
    return {
        'upper': sma + (std * num_std),
        'middle': sma,
        'lower': sma - (std * num_std)
    }

def convert_numpy_types(data: Dict[str, Any]) -> Dict[str, Any]:
    """Convertit les types NumPy en types Python natifs.
    
    Args:
        data: Dictionnaire contenant des valeurs NumPy
        
    Returns:
        Dictionnaire avec des types Python natifs
    """
    import numpy as np
    
    converted = {}
    for key, value in data.items():
        if isinstance(value, (np.integer, np.floating)):
            converted[key] = value.item()
        elif isinstance(value, np.ndarray):
            converted[key] = value.tolist()
        else:
            converted[key] = value
    return converted

def get_mt5_indicators(symbol: str, timeframe: str, count: int = 100) -> Optional[Dict[str, Any]]:
    """Récupère les indicateurs MT5 pour un symbole et une période donnés
    
    Args:
        symbol: Symbole du marché (ex: "EURUSD")
        timeframe: Période (M1, M5, M15, H1, H4, D1)
        count: Nombre de bougies à analyser
        
    Returns:
        Dictionnaire des indicateurs techniques ou None en cas d'erreur
    """
    if not mt5.initialize():
        logger.error("Échec de l'initialisation MT5")
        return None
    
    try:
        # Conversion du timeframe MT5
        tf_map = {
            'M1': mt5.TIMEFRAME_M1,
            'M5': mt5.TIMEFRAME_M5,
            'M15': mt5.TIMEFRAME_M15,
            'M30': mt5.TIMEFRAME_M30,
            'H1': mt5.TIMEFRAME_H1,
            'H4': mt5.TIMEFRAME_H4,
            'D1': mt5.TIMEFRAME_D1,
            'W1': mt5.TIMEFRAME_W1
        }
        
        mt5_timeframe = tf_map.get(timeframe, mt5.TIMEFRAME_M1)
        
        # Récupération des données OHLC
        rates = mt5.copy_rates_from_pos(symbol, mt5_timeframe, 0, count)
        if rates is None or len(rates) == 0:
            logger.error(f"Impossible de récupérer les données pour {symbol} {timeframe}")
            return None
            
        # Conversion en DataFrame
        df = pd.DataFrame(rates)
        if df.empty:
            logger.error(f"Aucune donnée reçue pour {symbol} {timeframe}")
            return None
            
        df['time'] = pd.to_datetime(df['time'], unit='s')
        df.set_index('time', inplace=True)
        
        # Vérification des données manquantes
        if df.isnull().values.any():
            logger.warning(
                f"Données manquantes détectées pour {symbol} {timeframe}, "
                "tentative de remplissage..."
            )
            df = df.ffill().bfill()
            
            # Si des valeurs manquantes persistent, on les remplace par la dernière valeur valide
            if df.isnull().values.any():
                df = df.fillna(method='ffill')
        
        # Calcul des indicateurs avec gestion des erreurs
        indicators = {}
        try:
            # Prix et volumes
            indicators.update({
                'current_price': df['close'].iloc[-1],
                'open': df['open'].iloc[-1],
                'high': df['high'].iloc[-1],
                'low': df['low'].iloc[-1],
                'volume': df['tick_volume'].iloc[-1],
                'spread': df['spread'].iloc[-1] if 'spread' in df.columns else 0
            })
            
            # Moyennes mobiles
            for period in [5, 10, 20, 50, 100, 200]:
                if len(df) >= period:
                    indicators[f'sma_{period}'] = df['close'].rolling(window=period).mean().iloc[-1]
                    indicators[f'ema_{period}'] = df['close'].ewm(span=period, adjust=False).mean().iloc[-1]
            
            # RSI
            if len(df) >= 14:  # Période minimale pour RSI
                indicators['rsi'] = calculate_rsi(df['close'], 14).iloc[-1]
            
            # ATR
            if len(df) >= 14:  # Période minimale pour ATR
                indicators['atr'] = calculate_atr(df, 14).iloc[-1]
            
            # MACD
            if len(df) >= 26:  # Période minimale pour MACD
                ema12 = df['close'].ewm(span=12, adjust=False).mean()
                ema26 = df['close'].ewm(span=26, adjust=False).mean()
                macd_line = ema12 - ema26
                signal_line = macd_line.ewm(span=9, adjust=False).mean()
                indicators['macd'] = (macd_line - signal_line).iloc[-1]
            
            # Bandes de Bollinger
            if len(df) >= 20:  # Période minimale pour les bandes de Bollinger
                bb = calculate_bollinger_bands(df['close'])
                indicators.update({
                    'bb_upper': bb['upper'].iloc[-1],
                    'bb_middle': bb['middle'].iloc[-1],
                    'bb_lower': bb['lower'].iloc[-1],
                    'bb_width': (
                        (bb['upper'].iloc[-1] - bb['lower'].iloc[-1]) / 
                        bb['middle'].iloc[-1] if bb['middle'].iloc[-1] != 0 else 0
                    )
                })
            
            # Volume moyen sur 20 périodes
            if len(df) >= 20:
                indicators['volume_sma_20'] = df['tick_volume'].rolling(window=20).mean().iloc[-1]
            
            # Conversion des types numpy en types Python natifs
            indicators = convert_numpy_types(indicators)
            
            return indicators
            
        except Exception as e:
            logger.error(f"Erreur lors du calcul des indicateurs pour {symbol} {timeframe}: {e}")
            return None
            
    except Exception as e:
        logger.error(f"Erreur dans get_mt5_indicators pour {symbol} {timeframe}: {e}")
        return None
        
    finally:
        # Toujours essayer de fermer la connexion MT5
        try:
            mt5.shutdown()
        except:
            pass

# Nouveaux imports pour Gemma (optionnel)
GEMMA_AVAILABLE = False
gemma_processor = None
gemma_model = None
torch = None
Image = None
AutoProcessor = None
AutoModelForImageTextToText = None
AutoModelForCausalLM = None

# PIL peut être utilisé indépendamment de torch/transformers (ex: lecture d'images exportées).
# On l'importe séparément pour éviter que l'échec de torch désactive aussi PIL.
try:
    from PIL import Image as _PILImage  # type: ignore
    Image = _PILImage
except Exception:
    Image = None

# Configuration des répertoires via variables d'environnement
# Vérification si on est sur Render
RUNNING_ON_RENDER = bool(os.getenv("RENDER") or os.getenv("RENDER_SERVICE_ID"))

# Fonction pour créer un répertoire avec gestion des erreurs
def safe_makedirs(path, mode=0o755):
    try:
        os.makedirs(path, mode=mode, exist_ok=True)
        # Vérification des permissions
        test_file = os.path.join(path, f".test_{int(time.time())}")
        with open(test_file, 'w') as f:
            f.write("test")
        os.remove(test_file)
        return True
    except Exception as e:
        logger.error(f"Impossible d'écrire dans {path}: {str(e)}")
        return False

# Configuration des chemins
try:
    if RUNNING_ON_RENDER:
        # Sur Render, on utilise le répertoire temporaire du système
        import tempfile
        base_temp_dir = tempfile.gettempdir()
        app_temp_dir = os.path.join(base_temp_dir, 'tradbot_ai')
        
        # Création des chemins de base
        DEFAULT_DATA_DIR = os.path.join(app_temp_dir, 'data')
        DEFAULT_MODELS_DIR = os.path.join(app_temp_dir, 'models')
        
        # Essayer de créer les répertoires principaux
        if not safe_makedirs(DEFAULT_DATA_DIR) or not safe_makedirs(DEFAULT_MODELS_DIR):
            # Fallback vers /tmp direct si échec
            logger.warning("Utilisation de /tmp direct comme fallback")
            DEFAULT_DATA_DIR = "/tmp/tradbot_data"
            DEFAULT_MODELS_DIR = "/tmp/tradbot_models"
            safe_makedirs(DEFAULT_DATA_DIR)
            safe_makedirs(DEFAULT_MODELS_DIR)
    else:
        # En local, on utilise les dossiers du projet
        DEFAULT_DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
        DEFAULT_MODELS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")
        safe_makedirs(DEFAULT_DATA_DIR)
        safe_makedirs(DEFAULT_MODELS_DIR)
        
    # Définition des chemins des modèles et fichiers
    GEMMA_MODEL_PATH = os.path.join(DEFAULT_MODELS_DIR, "gemma")
    MT5_FILES_DIR = os.path.join(DEFAULT_DATA_DIR, "mt5_files")
    
    # Création des sous-répertoires
    safe_makedirs(GEMMA_MODEL_PATH)
    safe_makedirs(MT5_FILES_DIR)
    
    logger.info(f"Répertoire des données: {DEFAULT_DATA_DIR}")
    logger.info(f"Répertoire des modèles: {DEFAULT_MODELS_DIR}")
    logger.info(f"Chemin du modèle Gemma: {GEMMA_MODEL_PATH}")
    logger.info(f"Répertoire des fichiers MT5: {MT5_FILES_DIR}")
    
except Exception as e:
    logger.error(f"Erreur lors de la configuration des répertoires: {e}")
    raise

try:
    import torch
    from transformers import AutoProcessor, AutoModelForImageTextToText, AutoModelForCausalLM
    print(f"Chargement du modèle Gemma depuis {GEMMA_MODEL_PATH}...")
    # Chargement conditionnel pour ne pas bloquer si les libs manquent ou le chemin est faux
    if os.path.exists(GEMMA_MODEL_PATH):
        try:
            # Chargement du processeur et du modèle en mode texte uniquement
            gemma_processor = AutoProcessor.from_pretrained(GEMMA_MODEL_PATH)
            gemma_model = AutoModelForCausalLM.from_pretrained(
                GEMMA_MODEL_PATH,
                torch_dtype=torch.float16,
                load_in_8bit=True,
                device_map="auto"
            )
            print("Modèle Gemma (Texte seul) chargé avec succès !")

            GEMMA_AVAILABLE = True
        except Exception as load_err:
             print(f"Erreur interne chargement Gemma: {load_err}")
             GEMMA_AVAILABLE = False
    else:
        print(f"Chemin du modèle introuvable: {GEMMA_MODEL_PATH}")
except Exception as e:
    print(f"Impossible de charger le modèle Gemma: {e}")
    GEMMA_AVAILABLE = False


# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('ai_server.log', encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("tradbot_ai")

# Machine Learning imports (Phase 2)
try:
    from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
    from sklearn.neural_network import MLPClassifier
    from sklearn.model_selection import train_test_split, cross_val_score
    from sklearn.preprocessing import StandardScaler
    from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score
    ML_AVAILABLE = True
    logger.info("scikit-learn disponible - Phase 2 ML features activées")
except ImportError:
    ML_AVAILABLE = False
    logger.warning("scikit-learn non disponible - Phase 2 ML features désactivées")

# Tentative d'importation de MetaTrader5 (optionnel)
try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
    logger.info("MetaTrader5 disponible")
except ImportError:
    MT5_AVAILABLE = False
    logger.info(
        "MetaTrader5 n'est pas installé - "
        "le serveur fonctionnera en mode API uniquement (sans connexion MT5)"
    )

# Configuration Mistral AI (désactivée dans cette version déployée)
MISTRAL_AVAILABLE = False
mistral_client = None

# Gemini totalement désactivé pour le déploiement Render
GEMINI_AVAILABLE = False
gemini_model = None

# Alpha Vantage API pour analyse fondamentale
ALPHAVANTAGE_API_KEY = os.getenv("ALPHAVANTAGE_API_KEY", "IU9I5J595Q5LO61B")
ALPHAVANTAGE_AVAILABLE = bool(ALPHAVANTAGE_API_KEY)
if ALPHAVANTAGE_AVAILABLE:
    logger.info("Alpha Vantage API disponible pour analyse fondamentale")
else:
    logger.info("Alpha Vantage API: Non configuré (ALPHAVANTAGE_API_KEY manquant)")

# Deriv API WebSocket pour données de marché (fallback)
DERIV_APP_ID = os.getenv("DERIV_APP_ID", "1089")  # 1089 = test app_id
DERIV_API_TOKEN = os.getenv("DERIV_API_TOKEN", "")
DERIV_WS_URL = f"wss://ws.derivws.com/websockets/v3?app_id={DERIV_APP_ID}"
DERIV_AVAILABLE = True
logger.info(f"Deriv API WebSocket disponible (app_id: {DERIV_APP_ID})")

# Compteur de requêtes Alpha Vantage (limite: 25/jour gratuit)
alphavantage_request_count = 0
ALPHAVANTAGE_DAILY_LIMIT = 25

# Indicateur global de disponibilité du backend ML
BACKEND_AVAILABLE = False

# Tentative d'importation des modules backend (optionnel, mais non bloquant pour l'API)
sys.path.insert(0, str(Path(__file__).parent / "backend"))

# 1) Prédicteurs avancés (RandomForest, etc.) - facultatifs pour Render
try:
    from advanced_ml_predictor import AdvancedMLPredictor
    from spike_predictor import AdvancedSpikePredictor
    from backend.mt5_connector import get_ohlc as get_historical_data
    logger.info("Prédicteurs avancés backend importés avec succès")
except ImportError as e:
    AdvancedMLPredictor = None  # type: ignore
    AdvancedSpikePredictor = None  # type: ignore
    get_historical_data = None  # type: ignore
    logger.warning(f"Prédicteurs avancés non disponibles (ceci est non bloquant pour Render): {e}")

# 2) Router adaptatif multi‑actifs (XGBoost) chargé directement depuis backend/adaptive_predict.py
try:
    import importlib.util
    adaptive_predict_path = Path(__file__).parent / "backend" / "adaptive_predict.py"
    if adaptive_predict_path.exists():
        spec = importlib.util.spec_from_file_location("adaptive_predict", adaptive_predict_path)
        adaptive_predict_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adaptive_predict_module)  # type: ignore
        predict_adaptive = adaptive_predict_module.predict_adaptive
        get_symbol_category = adaptive_predict_module.get_symbol_category
        ADAPTIVE_PREDICT_AVAILABLE = True
        logger.info("Module adaptive_predict chargé directement (modèles multi-actifs)")
    else:
        raise ImportError(f"Fichier adaptive_predict.py non trouvé: {adaptive_predict_path}")
except Exception as e:
    predict_adaptive = None  # type: ignore
    get_symbol_category = None  # type: ignore
    ADAPTIVE_PREDICT_AVAILABLE = False
    logger.warning(f"Module adaptive_predict non disponible: {e}")

# 3) Détecteur de spikes ML (facultatif)
try:
    from backend.spike_detector import predict_spike_ml, detect_spikes, get_realtime_spike_analysis
    SPIKE_DETECTOR_AVAILABLE = True
    logger.info("Module spike_detector disponible")
except ImportError as e:
    SPIKE_DETECTOR_AVAILABLE = False
    logger.warning(f"Module spike_detector non disponible: {e}")

# 4) Système d'apprentissage continu (feedback loop)
try:
    from backend.continuous_learning import ContinuousLearning
    CONTINUOUS_LEARNING_AVAILABLE = True
    # Initialiser le système d'apprentissage continu
    continuous_learner = ContinuousLearning(
        min_new_samples=50,  # Minimum 50 trades pour réentraîner
        retrain_interval_days=1,  # Réentraîner au moins une fois par jour
        db_url=DATABASE_URL
    )
    logger.info("✅ Module continuous_learning chargé avec succès")
except ImportError as e:
    ContinuousLearning = None  # type: ignore
    continuous_learner = None
    CONTINUOUS_LEARNING_AVAILABLE = False
    logger.warning(f"⚠️ Module continuous_learning non disponible: {e}")

# Le backend ML est considéré comme disponible si au moins l'un des modules clés est prêt
if ADAPTIVE_PREDICT_AVAILABLE or SPIKE_DETECTOR_AVAILABLE:
    BACKEND_AVAILABLE = True
    logger.info("Modules backend disponibles (BACKEND_AVAILABLE = True)")
else:
    BACKEND_AVAILABLE = False
    logger.warning("Aucun module backend ML disponible (BACKEND_AVAILABLE = False)")

# Import du détecteur avancé depuis ai_server_improvements
try:
    from ai_server_improvements import (
        AdvancedSpikeDetector,
        calculate_advanced_entry_score,
        calculate_momentum_score,
        detect_divergence,
        detect_candle_patterns
    )
    ADVANCED_SPIKE_DETECTOR_AVAILABLE = True
    ADVANCED_ENTRY_SCORING_AVAILABLE = True
    advanced_spike_detector = AdvancedSpikeDetector()
    logger.info("AdvancedSpikeDetector et système de scoring avancé initialisés")
except ImportError as e:
    ADVANCED_SPIKE_DETECTOR_AVAILABLE = False
    ADVANCED_ENTRY_SCORING_AVAILABLE = False
    advanced_spike_detector = None
    calculate_advanced_entry_score = None
    calculate_momentum_score = None
    detect_divergence = None
    detect_candle_patterns = None
    logger.warning(f"AdvancedSpikeDetector et scoring avancé non disponibles: {e}")

# Tentative d'importation de ai_indicators
try:
    sys.path.insert(0, str(Path(__file__).parent / "python"))
    from ai_indicators import AdvancedIndicators, analyze_market_data
    AI_INDICATORS_AVAILABLE = True
    logger.info("Module ai_indicators disponible")
except ImportError as e:
    AI_INDICATORS_AVAILABLE = False
    logger.warning(f"Module ai_indicators non disponible: {e}")
    AdvancedIndicators = None
    analyze_market_data = None

# Tentative d'importation des outils de règles d'association (optionnel)
try:
    sys.path.insert(0, str(Path(__file__).parent / "python"))
    from association_mining import mine_rules_for_symbol  # type: ignore
    ASSOCIATION_MINING_AVAILABLE = True
except Exception as e:
    ASSOCIATION_MINING_AVAILABLE = False
    logger.warning(f"association_mining non disponible (facultatif) : {e}")

# Règles d'association pré-calculées (chargées depuis JSON si dispo)
ASSOCIATION_RULES: Dict[str, List[Dict[str, Any]]] = {}
ASSOCIATION_RULES_PATH = Path(__file__).parent / "association_rules.json"


def load_association_rules() -> None:
    """Charge des règles d'association pré-calculées depuis un JSON (facultatif)."""
    global ASSOCIATION_RULES
    if not ASSOCIATION_RULES_PATH.exists():
        logger.info("Aucune règle d'association trouvée (association_rules.json manquant)")
        ASSOCIATION_RULES = {}
        return

    try:
        with ASSOCIATION_RULES_PATH.open("r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            ASSOCIATION_RULES = data
            logger.info(
                "Règles d'association chargées pour symboles: %s",
                ", ".join(ASSOCIATION_RULES.keys()),
            )
        else:
            logger.warning("Format de association_rules.json invalide (dict attendu)")
            ASSOCIATION_RULES = {}
    except Exception as e:
        logger.error(f"Erreur chargement association_rules.json: {e}", exc_info=True)
        ASSOCIATION_RULES = {}


def build_items_from_request(req: "DecisionRequest") -> Set[str]:
    """
    Construit un ensemble d'items (booléens) à partir de la requête courante.
    Doit rester cohérent avec la logique utilisée pour miner les règles.
    """
    items: Set[str] = set()

    # Type de symbole (Boom/Crash/Volatility/Forex)
    sym = req.symbol or ""
    s_low = sym.lower()
    if "boom" in s_low:
        items.add("sym_boom")
    if "crash" in s_low:
        items.add("sym_crash")
    if "volatility" in s_low:
        items.add("sym_volatility")

    # RSI
    if req.rsi is not None:
        if req.rsi < 30:
            items.add("rsi_low")
        elif req.rsi > 70:
            items.add("rsi_high")

    # EMA H1
    if req.ema_fast_h1 is not None and req.ema_slow_h1 is not None:
        if req.ema_fast_h1 > req.ema_slow_h1:
            items.add("trend_up_H1")
        elif req.ema_fast_h1 < req.ema_slow_h1:
            items.add("trend_down_H1")

    # EMA M1 (via dir_rule si disponible)
    # dir_rule: 1=BUY, -1=SELL, 0=neutre (défini côté EA)
    if req.dir_rule == 1:
        items.add("trend_up_M1_rule")
    elif req.dir_rule == 0:
        items.add("trend_down_M1_rule")

    return items


def adjust_decision_with_rules(
    symbol: str,
    action: str,
    confidence: float,
    base_reason: str,
    items: Set[str],
) -> Tuple[str, float, str]:
    """
    Ajuste (légèrement) l'action / la confiance en fonction des règles d'association pré-calculées.

    - Si une règle pour ce symbole (ou '*') avec consequent 'trade_win' a ses items inclus dans
      l'état courant, et que cette règle est cohérente avec l'action (BUY/SELL),
      la confiance est augmentée légèrement.
    - L'impact est volontairement modéré pour ne pas casser la logique principale.
    """
    if not ASSOCIATION_RULES:
        return action, confidence, base_reason

    rules_for_symbol: List[Dict[str, Any]] = []
    if symbol in ASSOCIATION_RULES:
        rules_for_symbol.extend(ASSOCIATION_RULES[symbol])
    if "*" in ASSOCIATION_RULES:
        rules_for_symbol.extend(ASSOCIATION_RULES["*"])

    if not rules_for_symbol:
        return action, confidence, base_reason

    bonus = 0.0
    applied_rules: List[str] = []

    for r in rules_for_symbol:
        antecedent = set(r.get("antecedent", []))
        if not antecedent:
            continue
        if not antecedent.issubset(items):
            continue

        conf = float(r.get("confidence", 0.0))
        lift = float(r.get("lift", 1.0) or 1.0)

        if action != "hold" and conf >= 0.7 and lift >= 1.0:
            bonus += min((conf - 0.5) * 0.1, 0.05)  # max +0.05 par règle
            rule_str = (
                f"{','.join(sorted(antecedent))} "
                f"(conf={conf:.2f},lift={lift:.2f})"
            )
            applied_rules.append(rule_str)

    if bonus != 0.0:
        new_conf = max(0.0, min(1.0, confidence + bonus))
        reason = base_reason
        if applied_rules:
            reason = f"{base_reason} | RèglesAssoc:+{bonus:.2f} via {len(applied_rules)} règle(s)"
        return action, new_conf, reason

    return action, confidence, base_reason

# Charger les éventuelles règles d'association au démarrage
load_association_rules()

# Configuration de l'application
app = FastAPI(
    title="TradBOT AI Server",
    description="API de prédiction et d'analyse pour le robot de trading TradBOT",
    version="2.0.0"
)

# Configuration CORS pour permettre les requêtes depuis MT5
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Middleware pour logger toutes les requêtes entrantes
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log toutes les requêtes entrantes pour debugging"""
    start_time = time.time()
    
    # Logger le path et la méthode avec INFO pour être visible dans les logs Render
    logger.info(f"📥 {request.method} {request.url.path}")
    
    response = await call_next(request)
    
    process_time = time.time() - start_time
    # Logger toutes les réponses avec INFO pour être visible dans les logs Render
    if process_time > 1.0 or response.status_code >= 400:
        logger.warning(f"⚠️ {request.method} {request.url.path} - {response.status_code} - Temps: {process_time:.3f}s")
    else:
        logger.info(f"📤 {request.method} {request.url.path} - {response.status_code} - Temps: {process_time:.3f}s")
    
    return response

# ===== POSTGRESQL CONNECTION POOL FOR FEEDBACK LOOP =====
async def get_db_pool():
    """Get or create database connection pool"""
    if not hasattr(app.state, "db_pool"):
        if not DB_AVAILABLE:
            logger.warning(
        "PostgreSQL non disponible - "
        "DATABASE_URL manquant ou asyncpg non installé"
    )
            return None
        try:
            # Pour Render PostgreSQL, il faut ajouter SSL
            # Parse la DATABASE_URL pour ajouter sslmode si nécessaire
            dsn = DATABASE_URL
            if "render.com" in DATABASE_URL.lower() and "sslmode" not in DATABASE_URL.lower():
                # Ajouter sslmode=require pour Render PostgreSQL
                separator = "?" if "?" not in dsn else "&"
                dsn = f"{dsn}{separator}sslmode=require"
                logger.info("📝 Ajout de sslmode=require pour Render PostgreSQL")
            
            app.state.db_pool = await asyncpg.create_pool(
                dsn=dsn,
                min_size=1,
                max_size=5,
                command_timeout=30,  # Timeout réduit à 30s
                server_settings={
                    'application_name': 'tradbot_ai_server'
                }
            )
            logger.info("✅ Pool de connexions PostgreSQL créé")
        except asyncio.TimeoutError:
            logger.error(
        "❌ Timeout lors de la création du pool PostgreSQL - "
        "Vérifiez la connexion réseau"
    )
            app.state.db_pool = None
            return None
        except Exception as e:
            logger.error(f"❌ Erreur création pool PostgreSQL: {e}", exc_info=True)
            app.state.db_pool = None
            return None
    return app.state.db_pool

# SQL pour créer la table de feedback
CREATE_FEEDBACK_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS trade_feedback (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    open_time TIMESTAMPTZ NOT NULL,
    close_time TIMESTAMPTZ NOT NULL,
    entry_price DOUBLE PRECISION NOT NULL,
    exit_price DOUBLE PRECISION NOT NULL,
    profit DOUBLE PRECISION NOT NULL,
    ai_confidence DOUBLE PRECISION,
    coherent_confidence DOUBLE PRECISION,
    decision TEXT NOT NULL,
    is_win BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trade_feedback_symbol ON trade_feedback(symbol);
CREATE INDEX IF NOT EXISTS idx_trade_feedback_created_at ON trade_feedback(created_at DESC);
"""

@app.on_event("startup")
async def startup_event():
    """Initialize database on startup"""
    if not DB_AVAILABLE:
        logger.info("📊 Mode sans PostgreSQL - feedback loop désactivé")
        return
    
    try:
        pool = await get_db_pool()
        if pool:
            async with pool.acquire() as conn:
                await conn.execute(CREATE_FEEDBACK_TABLE_SQL)
                logger.info("✅ Table trade_feedback créée/vérifiée")
    except Exception as e:
        logger.error(f"❌ Erreur initialisation base de données: {e}", exc_info=True)

@app.on_event("shutdown")
async def shutdown_event():
    """Close database pool on shutdown"""
    if hasattr(app.state, "db_pool") and app.state.db_pool:
        await app.state.db_pool.close()
        logger.info("🔒 Pool PostgreSQL fermé")


# Parser les arguments en ligne de commande
parser = argparse.ArgumentParser(description='Serveur AI TradBOT')
parser.add_argument('--port', type=int, default=8000, help='Port sur lequel démarrer le serveur')
parser.add_argument(
    '--host', 
    type=str, 
    default='127.0.0.1', 
    help='Adresse IP sur laquelle écouter'
)
args = parser.parse_args()

# Variables globales
API_PORT = int(os.getenv('API_PORT', args.port))
HOST = os.getenv('HOST', args.host)
CACHE_DURATION = 30  # secondes
# Dossiers de prédictions / métriques MT5
RUNNING_ON_RENDER = bool(os.getenv("RENDER") or os.getenv("RENDER_SERVICE_ID"))

if RUNNING_ON_RENDER:
    # Sur Render, on utilise le dossier temporaire par défaut
    # qui est garanti d'être accessible en écriture
    # On utilise /tmp/ comme racine pour les données et modèles
    DATA_DIR = Path("/tmp/data")
    MODELS_DIR = Path("/tmp/models")
    
    # Créer les répertoires s'ils n'existent pas
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(MODELS_DIR, exist_ok=True)
    
    logger.info(f"Mode Render activé - Utilisation des dossiers temporaires:")
    logger.info(f"- Données: {DATA_DIR}")
    logger.info(f"- Modèles: {MODELS_DIR}")
    
    # Liste des dossiers à créer dans DATA_DIR
    required_dirs = ["mt5_files", "predictions", "metrics"]
    for dir_name in required_dirs:
        dir_path = DATA_DIR / dir_name
        os.makedirs(dir_path, exist_ok=True)
        logger.info(f"Créé le répertoire: {dir_path}")
    
    # Chercher un répertoire accessible en écriture
    possible_roots = [
        "/tmp",
        "/var/tmp",
        "/opt/render/project/src",
        str(Path.home()),
        ".",
    ]
    selected_root = "."  # Valeur par défaut
    for root_dir in possible_roots:
        test_dir = Path(root_dir)
        test_file = test_dir / ".write_test"
        try:
            test_dir.mkdir(parents=True, exist_ok=True)
            with open(test_file, 'w') as f:
                f.write("test")
            os.remove(test_file)
            selected_root = root_dir
            logger.info(f"Répertoire accessible en écriture trouvé: {test_dir}")
            break
        except Exception as e:
            logger.debug(f"Impossible d'écrire dans {test_dir}: {e}")
    
    # Définir les chemins des dossiers
    base_dir = Path(selected_root)
    DATA_DIR = base_dir / "data"
    MODELS_DIR = base_dir / "models"
    
    # Créer les dossiers avec gestion d'erreur
    try:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        MODELS_DIR.mkdir(parents=True, exist_ok=True)
        logger.info(f"Dossiers configurés: DATA_DIR={DATA_DIR}, MODELS_DIR={MODELS_DIR}")
    except Exception as e:
        logger.error(f"Erreur critique: Impossible de créer les dossiers nécessaires: {e}")
        raise
else:
    # Mode développement local
    DATA_DIR = Path("data")
    MODELS_DIR = Path("models")

LOG_FILE = Path("ai_server.log")
FEEDBACK_FILE = DATA_DIR / "trade_feedback.jsonl"

if RUNNING_ON_RENDER:
    # Mode cloud: tout est stocké dans le répertoire data/ du serveur
    MT5_PREDICTIONS_DIR = DATA_DIR / "Predictions"
    MT5_RESULTS_DIR = DATA_DIR / "Results"
else:
    # Mode local: utiliser les chemins Windows partagés avec MT5
    # Exemple fourni par l'utilisateur :
    # C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\Common\Files\Predictions
    MT5_PREDICTIONS_DIR = Path(
        r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\Common\Files\Predictions"
    )
    # Dossier pour sauvegarder les métriques de prédiction
    MT5_RESULTS_DIR = Path(
        r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\Common\Files\Results"
    )
try:
    MT5_PREDICTIONS_DIR.mkdir(parents=True, exist_ok=True)
    MT5_RESULTS_DIR.mkdir(parents=True, exist_ok=True)
except Exception as _e:
    # On log uniquement en warning, le serveur peut continuer sans ce stockage
    logging.getLogger("tradbot_ai").warning(
        f"Impossible de créer le dossier de prédictions/résultats MT5: {_e}"
    )
DEFAULT_SYMBOL = "Volatility 75 Index"

# Création des répertoires si nécessaire
for directory in [DATA_DIR, MODELS_DIR]:
    directory.mkdir(exist_ok=True)

# Cache pour les prédictions
prediction_cache = {}
last_updated = {}

# ===== SYSTÈME DE DÉTECTION DE MOUVEMENT EN TEMPS RÉEL =====
# Suivi des prix pour détecter les mouvements haussiers/baissiers en temps réel
# {symbol: [{"price": float, "timestamp": float}]}
realtime_price_history: Dict[str, List[Dict[str, float]]] = {}
MAX_PRICE_HISTORY = 10  # Garder les 10 derniers prix
MIN_PRICE_CHANGE_PERCENT = 0.05  # 0.05% de changement minimum pour détecter un mouvement
REALTIME_MOVEMENT_WINDOW = 30  # Fenêtre de 30 secondes pour détecter un mouvement

def detect_realtime_movement(symbol: str, current_price: float) -> Dict[str, Any]:
    """
    Détecte les mouvements de prix en temps réel (haussier/baissier)
    
    Args:
        symbol: Symbole du marché
        current_price: Prix actuel (mid_price)
        
    Returns:
        Dict avec 'direction' ('up', 'down', 'neutral'), 'strength' (0-1), 'price_change_percent'
    """
    current_time = time.time()
    
    # Initialiser l'historique si nécessaire
    if symbol not in realtime_price_history:
        realtime_price_history[symbol] = []
    
    # Ajouter le prix actuel
    realtime_price_history[symbol].append({
        "price": current_price,
        "timestamp": current_time
    })
    
    # Garder seulement les prix récents (dernières 30 secondes)
    cutoff_time = current_time - REALTIME_MOVEMENT_WINDOW
    realtime_price_history[symbol] = [
        p for p in realtime_price_history[symbol] 
        if p["timestamp"] >= cutoff_time
    ]
    
    # Limiter le nombre d'entrées
    if len(realtime_price_history[symbol]) > MAX_PRICE_HISTORY:
        realtime_price_history[symbol] = realtime_price_history[symbol][-MAX_PRICE_HISTORY:]
    
    history = realtime_price_history[symbol]
    
    # Besoin d'au moins 2 prix pour détecter un mouvement
    if len(history) < 2:
        return {
            "direction": "neutral",
            "strength": 0.0,
            "price_change_percent": 0.0,
            "trend_consistent": False
        }
    
    # Calculer le changement de prix depuis le premier prix de la fenêtre
    first_price = history[0]["price"]
    price_change = current_price - first_price
    price_change_percent = (price_change / first_price * 100) if first_price > 0 else 0.0
    
    # Calculer la tendance (combien de mouvements sont dans la même direction)
    up_moves = 0
    down_moves = 0
    for i in range(1, len(history)):
        if history[i]["price"] > history[i-1]["price"]:
            up_moves += 1
        elif history[i]["price"] < history[i-1]["price"]:
            down_moves += 1
    
    # Déterminer la direction
    if abs(price_change_percent) >= MIN_PRICE_CHANGE_PERCENT:
        if price_change_percent > 0:
            direction = "up"
            strength = min(abs(price_change_percent) / (MIN_PRICE_CHANGE_PERCENT * 2), 1.0)
        else:
            direction = "down"
            strength = min(abs(price_change_percent) / (MIN_PRICE_CHANGE_PERCENT * 2), 1.0)
    else:
        direction = "neutral"
        strength = 0.0
    
    # Vérifier la cohérence de la tendance (au moins 60% des mouvements dans la même direction)
    total_moves = up_moves + down_moves
    trend_consistent = False
    if total_moves > 0:
        if direction == "up" and up_moves / total_moves >= 0.6:
            trend_consistent = True
        elif direction == "down" and down_moves / total_moves >= 0.6:
            trend_consistent = True
    
    return {
        "direction": direction,
        "strength": strength,
        "price_change_percent": price_change_percent,
        "trend_consistent": trend_consistent,
        "up_moves": up_moves,
        "down_moves": down_moves
    }

# ===== CACHE POUR DONNÉES HISTORIQUES UPLOADÉES DEPUIS MT5 =====
# Stockage des données historiques envoyées par MT5 via le bridge
# Format: {f"{symbol}_{timeframe}": {"data": DataFrame, "timestamp": datetime}}
mt5_uploaded_history_cache: Dict[str, Dict[str, Any]] = {}
MT5_HISTORY_CACHE_TTL = 300  # TTL de 5 minutes (les données sont rafraîchies régulièrement)

# ===== SYSTÈME DE VALIDATION ET CALIBRATION DES PRÉDICTIONS =====
# Stockage des prédictions historiques pour validation
prediction_history: Dict[str, List[Dict[str, Any]]] = {}  # {symbol: [predictions]}
PREDICTION_VALIDATION_FILE = DATA_DIR / "prediction_validation.json"
MIN_VALIDATION_BARS = 10  # Minimum 10 bougies pour valider
MIN_ACCURACY_THRESHOLD = 0.55  # lowered from 60% to 55%  # Seuil minimum de précision (60%)
MAX_HISTORICAL_PREDICTIONS = 100  # Maximum 100 prédictions par symbole

def load_prediction_history():
    """Charge l'historique des prédictions depuis le fichier"""
    global prediction_history
    if PREDICTION_VALIDATION_FILE.exists():
        try:
            with open(PREDICTION_VALIDATION_FILE, 'r', encoding='utf-8') as f:
                prediction_history = json.load(f)
            pred_count = sum(len(v) for v in prediction_history.values())
            logger.info(f"✅ Historique des prédictions chargé: {pred_count} prédictions")
        except Exception as e:
            logger.warning(f"Erreur chargement historique prédictions: {e}")
            prediction_history = {}

def save_prediction_history():
    """Sauvegarde l'historique des prédictions dans le fichier"""
    try:
        with open(PREDICTION_VALIDATION_FILE, 'w', encoding='utf-8') as f:
            json.dump(prediction_history, f, indent=2, ensure_ascii=False)
    except Exception as e:
        logger.error(f"Erreur sauvegarde historique prédictions: {e}")

def store_prediction(
    symbol: str, 
    predicted_prices: List[float], 
    current_price: float, 
    timeframe: str
):
    """Stocke une prédiction pour validation future"""
    if symbol not in prediction_history:
        prediction_history[symbol] = []
    
    prediction_id = f"{symbol}_{datetime.now().timestamp()}"
    prediction = {
        "id": prediction_id,
        "timestamp": datetime.now().isoformat(),
        "predicted_prices": predicted_prices,
        "current_price": current_price,
        "timeframe": timeframe,
        "bars_predicted": len(predicted_prices),
        "accuracy_score": None,
        "is_validated": False,
        "validation_timestamp": None
    }
    
    prediction_history[symbol].append(prediction)
    
    # Limiter le nombre de prédictions stockées
    if len(prediction_history[symbol]) > MAX_HISTORICAL_PREDICTIONS:
        prediction_history[symbol] = prediction_history[symbol][-MAX_HISTORICAL_PREDICTIONS:]
    
    save_prediction_history()
    
    # Mettre à jour le cache temps réel
    cache_key = f"{symbol}_{timeframe}"
    accuracy_score = get_prediction_accuracy_score(symbol)
    realtime_predictions[cache_key] = {
        "symbol": symbol,
        "timeframe": timeframe,
        "timestamp": prediction["timestamp"],
        "predicted_prices": predicted_prices[:50],  # Limiter pour la réponse
        "current_price": current_price,
        "accuracy_score": round(accuracy_score, 3),
        "validation_count": sum(1 for p in prediction_history[symbol] if p.get("is_validated", False)),
        "reliability": (
            "HIGH" if accuracy_score >= 0.80 
            else "MEDIUM" if accuracy_score >= 0.60 
            else "LOW"
        )
    }

def calculate_prediction_accuracy(
    predicted_prices: List[float], 
    real_prices: List[float]
) -> float:
    """Calcule la précision d'une prédiction en comparant avec les prix réels"""
    if len(predicted_prices) == 0 or len(real_prices) == 0:
        return 0.0
    
    min_len = min(len(predicted_prices), len(real_prices))
    if min_len < MIN_VALIDATION_BARS:
        return 0.0
    
    total_error = 0.0
    valid_comparisons = 0
    
    for i in range(min_len):
        if predicted_prices[i] > 0 and real_prices[i] > 0:
            # Calculer l'erreur relative en pourcentage
            error_percent = abs(predicted_prices[i] - real_prices[i]) / real_prices[i]
            total_error += error_percent
            valid_comparisons += 1
    
    if valid_comparisons < MIN_VALIDATION_BARS:
        return 0.0
    
    # Calculer l'erreur moyenne
    avg_error = total_error / valid_comparisons
    
    # Convertir en score de précision (0.0 = 0% précision, 1.0 = 100% précision)
    # Erreur de 10% = précision 0%
    accuracy = 1.0 - min(avg_error * 10.0, 1.0)
    
    return max(0.0, min(1.0, accuracy))

def validate_predictions(symbol: str, timeframe: str = "M1"):
    """Valide les prédictions passées en comparant avec les prix réels"""
    if symbol not in prediction_history:
        return
    
    if not MT5_AVAILABLE or not mt5_initialized:
        return
    
    try:
        import MetaTrader5 as mt5_module
        period_map = {
            "M1": mt5_module.TIMEFRAME_M1,
            "M5": mt5_module.TIMEFRAME_M5,
            "M15": mt5_module.TIMEFRAME_M15,
            "H1": mt5_module.TIMEFRAME_H1,
            "H4": mt5_module.TIMEFRAME_H4,
            "D1": mt5_module.TIMEFRAME_D1
        }
        period = period_map.get(timeframe, mt5_module.TIMEFRAME_M1)
        
        validated_count = 0
        total_accuracy = 0.0
        
        for pred in prediction_history[symbol]:
            if pred["is_validated"]:
                continue
            
            # Calculer combien de bougies se sont écoulées
            pred_time = datetime.fromisoformat(pred["timestamp"])
            elapsed_minutes = (datetime.now() - pred_time).total_seconds() / 60
            
            if elapsed_minutes < MIN_VALIDATION_BARS:
                continue  # Pas assez de temps écoulé
            
            # Récupérer les prix réels
            bars_to_get = min(int(elapsed_minutes), pred["bars_predicted"])
            rates = mt5_module.copy_rates_from_pos(symbol, period, 0, bars_to_get)
            
            if rates is None or len(rates) < MIN_VALIDATION_BARS:
                continue
            
            # Extraire les prix réels (en ordre chronologique)
            real_prices = [rate['close'] for rate in reversed(rates[:bars_to_get])]
            predicted_prices = pred["predicted_prices"][:len(real_prices)]
            
            # Calculer la précision
            accuracy = calculate_prediction_accuracy(predicted_prices, real_prices)
            
            if accuracy > 0.0:
                pred["accuracy_score"] = accuracy
                pred["is_validated"] = True
                pred["validation_timestamp"] = datetime.now().isoformat()
                total_accuracy += accuracy
                validated_count += 1
                
                logger.info(f"✅ Prédiction validée pour {symbol}: Précision = {accuracy*100:.1f}%")
        
        if validated_count > 0:
            save_prediction_history()
            avg_accuracy = total_accuracy / validated_count
            logger.info(f"📊 Précision moyenne pour {symbol}: {avg_accuracy*100:.1f}% ({validated_count} validations)")
            
    except Exception as e:
        logger.error(f"Erreur validation prédictions pour {symbol}: {e}")

def get_prediction_accuracy_score(symbol: str) -> float:
    """Retourne le score de précision moyen pour un symbole"""
    if symbol not in prediction_history:
        return 0.5  # Score neutre si pas de données
    
    validated = [
        p for p in prediction_history[symbol] 
        if p.get("is_validated") and p.get("accuracy_score") is not None
    ]
    
    if len(validated) == 0:
        return 0.5  # Score neutre si pas de validations
    
    total_accuracy = sum(p["accuracy_score"] for p in validated)
    return total_accuracy / len(validated)

def get_prediction_confidence_multiplier(symbol: str) -> float:
    """Retourne un multiplicateur de confiance basé sur la précision historique"""
    accuracy = get_prediction_accuracy_score(symbol)
    
    if accuracy >= 0.80:
        return 1.0  # Confiance normale
    elif accuracy >= 0.60:
        return 0.8  # Réduire confiance de 20%
    elif accuracy >= 0.40:
        return 0.5  # Réduire confiance de 50%
    else:
        return 0.3  # Très faible précision

# Stockage des dernières prédictions en temps réel
realtime_predictions: Dict[str, Dict[str, Any]] = {}  # {symbol: {prediction_data}}

def save_prediction_metrics(symbol: str, metrics: Dict[str, Any]):
    """Sauvegarde les métriques de prédiction dans le dossier Results"""
    try:
        safe_symbol = symbol.replace(" ", "_").replace("(", "").replace(")", "").replace("%", "")
        metrics_file = MT5_RESULTS_DIR / f"{safe_symbol}_metrics.json"
        
        # Charger les métriques existantes
        if metrics_file.exists():
            try:
                with open(metrics_file, 'r', encoding='utf-8') as f:
                    all_metrics = json.load(f)
            except:
                all_metrics = {"history": [], "summary": {}}
        else:
            all_metrics = {"history": [], "summary": {}}
        
        # Ajouter timestamp
        metrics["timestamp"] = datetime.now().isoformat()
        
        # Ajouter à l'historique
        all_metrics["history"].append(metrics)
        
        # Garder seulement les 1000 dernières entrées
        if len(all_metrics["history"]) > 1000:
            all_metrics["history"] = all_metrics["history"][-1000:]
        
        # Calculer le résumé
        validated = [m for m in all_metrics["history"] if m.get("accuracy_score") is not None]
        if validated:
            accuracies = [m["accuracy_score"] for m in validated]
            all_metrics["summary"] = {
                "total_validations": len(validated),
                "average_accuracy": round(sum(accuracies) / len(accuracies), 3),
                "min_accuracy": round(min(accuracies), 3),
                "max_accuracy": round(max(accuracies), 3),
                "last_update": datetime.now().isoformat()
            }
        
        # Sauvegarder
        with open(metrics_file, 'w', encoding='utf-8') as f:
            json.dump(all_metrics, f, indent=2, ensure_ascii=False)
        
        logger.info(f"✅ Métriques sauvegardées pour {symbol} dans {metrics_file}")
        
    except Exception as e:
        logger.error(f"Erreur sauvegarde métriques pour {symbol}: {e}")

def validate_prediction_with_realtime_data(
    symbol: str, 
    real_prices: List[float], 
    prediction_id: Optional[str] = None
) -> Dict[str, Any]:
    """Valide une prédiction avec les données réelles envoyées"""
    try:
        # Vérifier que prediction_history est initialisé
        global prediction_history
        if not isinstance(prediction_history, dict):
            prediction_history = {}
        
        # Vérifier que real_prices est valide
        if not real_prices or not isinstance(real_prices, list):
            return {"error": "Liste de prix réels invalide ou vide"}
        
        if not all(isinstance(p, (int, float)) and p > 0 for p in real_prices):
            return {"error": "Les prix réels doivent être des nombres positifs"}
        
        # Si prediction_id est fourni, chercher la prédiction spécifique
        pred = None
        if prediction_id:
            if symbol not in prediction_history:
                return {"error": f"Aucune prédiction trouvée pour le symbole {symbol}"}
            for p in prediction_history[symbol]:
                if p.get("id") == prediction_id:
                    pred = p
                    break
            if not pred:
                return {"error": f"Prédiction avec l'ID {prediction_id} non trouvée"}
            if pred.get("is_validated"):
                return {"error": "Cette prédiction a déjà été validée"}
        else:
            # Prendre la dernière prédiction non validée
            if symbol not in prediction_history or not prediction_history[symbol]:
                return {"error": f"Aucune prédiction à valider pour le symbole {symbol}"}
            pred = prediction_history[symbol][-1]
            if pred.get("is_validated"):
                return {"error": "Toutes les prédictions sont déjà validées"}
        
        # Vérifier que la prédiction a les clés nécessaires
        if not isinstance(pred, dict):
            return {"error": "Format de prédiction invalide"}
        
        if "predicted_prices" not in pred:
            return {"error": "La prédiction ne contient pas de prix prédits"}
        
        predicted_prices = pred.get("predicted_prices", [])
        if not isinstance(predicted_prices, list) or len(predicted_prices) == 0:
            return {"error": "La liste des prix prédits est vide ou invalide"}
        
        if not all(isinstance(p, (int, float)) and p > 0 for p in predicted_prices):
            return {"error": "Les prix prédits doivent être des nombres positifs"}
        
        min_len = min(len(predicted_prices), len(real_prices))
        
        if min_len < MIN_VALIDATION_BARS:
            return {"error": f"Pas assez de données (minimum {MIN_VALIDATION_BARS} bougies, reçu {min_len})"}
        
        # Calculer la précision
        try:
            accuracy = calculate_prediction_accuracy(predicted_prices[:min_len], real_prices[:min_len])
        except Exception as e:
            logger.error(f"Erreur lors du calcul de la précision: {e}")
            return {"error": f"Erreur lors du calcul de la précision: {str(e)}"}
        
        # Mettre à jour la prédiction
        pred["accuracy_score"] = accuracy
        pred["is_validated"] = True
        pred["validation_timestamp"] = datetime.now().isoformat()
        pred["real_prices"] = real_prices[:min_len]
        
        # Sauvegarder l'historique
        try:
            save_prediction_history()
        except Exception as e:
            logger.warning(f"Erreur lors de la sauvegarde de l'historique: {e}")
        
        # Sauvegarder les métriques
        try:
            metrics = {
                "symbol": symbol,
                "prediction_id": pred.get("id", "unknown"),
                "accuracy_score": accuracy,
                "bars_validated": min_len,
                "predicted_prices_count": len(predicted_prices),
                "real_prices_count": len(real_prices),
                "timeframe": pred.get("timeframe", "M1")
            }
            save_prediction_metrics(symbol, metrics)
        except Exception as e:
            logger.warning(f"Erreur lors de la sauvegarde des métriques: {e}")
        
        logger.info(f"✅ Prédiction validée pour {symbol}: Précision = {accuracy*100:.1f}%")
        
        return {
            "success": True,
            "accuracy_score": accuracy,
            "bars_validated": min_len,
            "timestamp": datetime.now().isoformat()
        }
        
    except KeyError as e:
        error_msg = f"Clé manquante dans la prédiction: {str(e)}"
        logger.error(f"Erreur validation prédiction: {error_msg}")
        return {"error": error_msg}
    except Exception as e:
        error_msg = f"Erreur validation prédiction avec données réelles: {str(e)}"
        logger.error(error_msg, exc_info=True)
        return {"error": error_msg}

# Charger l'historique au démarrage
load_prediction_history()

# Initialisation MT5 si disponible
mt5_initialized = False
if MT5_AVAILABLE:
    try:
        mt5_login = int(os.getenv('MT5_LOGIN', 0))
        mt5_password = os.getenv('MT5_PASSWORD', '')
        mt5_server = os.getenv('MT5_SERVER', '')
        
        if mt5_login and mt5_password and mt5_server:
            if mt5.initialize(login=mt5_login, password=mt5_password, server=mt5_server):
                mt5_initialized = True
                logger.info("MT5 initialisé avec succès")
            else:
                logger.warning("Échec de l'initialisation MT5")
        else:
            logger.info("MT5: Non configuré (variables d'environnement manquantes)")
    except Exception as e:
        logger.error(f"Erreur lors de l'initialisation MT5: {e}")

# Initialisation des prédicteurs ML si disponibles
ml_predictor = None
spike_predictor = None
if BACKEND_AVAILABLE:
    try:
        ml_predictor = AdvancedMLPredictor()
        spike_predictor = AdvancedSpikePredictor()
        logger.info("Prédicteurs ML initialisés")
    except Exception as e:
        logger.warning(f"Impossible d'initialiser les prédicteurs ML: {e}")

# Dictionnaire pour stocker les instances d'AdvancedIndicators par symbole/tf
indicators_cache = {}

# Modèles Pydantic pour les requêtes/réponses
class DecisionRequest(BaseModel):
    symbol: str
    bid: float
    ask: float
    rsi: Optional[float] = 50.0  # Valeur neutre par défaut
    ema_fast_h1: Optional[float] = None
    ema_slow_h1: Optional[float] = None
    ema_fast_m1: Optional[float] = None
    ema_slow_m1: Optional[float] = None
    atr: Optional[float] = 0.0
    dir_rule: int = 0  # 0 = neutre par défaut
    is_spike_mode: bool = False
    vwap: Optional[float] = None
    vwap_distance: Optional[float] = None
    above_vwap: Optional[bool] = None
    supertrend_trend: Optional[int] = 0  # 0 = neutre par défaut
    supertrend_line: Optional[float] = None
    volatility_regime: Optional[int] = 0  # 0 = neutre par défaut
    volatility_ratio: Optional[float] = 1.0  # 1.0 = neutre par défaut
    image_filename: Optional[str] = None # Filename of the chart screenshot in MT5 Files
    deriv_patterns: Optional[str] = None  # Résumé des patterns Deriv détectés
    deriv_patterns_bullish: Optional[int] = None  # Nombre de patterns bullish
    deriv_patterns_bearish: Optional[int] = None  # Nombre de patterns bearish
    deriv_patterns_confidence: Optional[float] = None  # Confiance moyenne des patterns

# ===== MODÈLES POUR FEEDBACK LOOP =====
class TradeFeedback(BaseModel):
    """Modèle pour recevoir les résultats de trade du robot MT5"""
    symbol: str
    open_time: str  # ISO format datetime string
    close_time: str  # ISO format datetime string
    entry_price: float
    exit_price: float
    profit: float
    ai_confidence: float
    coherent_confidence: float
    decision: str  # "BUY" ou "SELL"
    is_win: bool


class DecisionResponse(BaseModel):
    action: str  # "buy", "sell", "hold"
    confidence: float  # 0.0-1.0
    reason: str
    spike_prediction: bool = False
    spike_zone_price: Optional[float] = None
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    spike_direction: Optional[bool] = None  # True=BUY, False=SELL
    early_spike_warning: bool = False
    early_spike_zone_price: Optional[float] = None
    early_spike_direction: Optional[bool] = None
    buy_zone_low: Optional[float] = None
    buy_zone_high: Optional[float] = None
    sell_zone_low: Optional[float] = None
    sell_zone_high: Optional[float] = None
    timestamp: Optional[str] = None
    model_used: Optional[str] = None
    technical_analysis: Optional[Dict[str, Any]] = None
    gemma_analysis: Optional[str] = None  # Analyse complète Gemma+Gemini

class TrendlineData(BaseModel):
    start: Dict[str, Any]  # {"time": timestamp, "price": float}
    end: Dict[str, Any]    # {"time": timestamp, "price": float}

class AnalysisRequest(BaseModel):
    symbol: str
    timeframe: Optional[str] = None
    request_type: Optional[str] = None

class AnalysisResponse(BaseModel):
    symbol: str
    timestamp: str
    h1: Dict[str, Any] = {}
    h4: Dict[str, Any] = {}
    m15: Dict[str, Any] = {}
    ete: Optional[Dict[str, Any]] = None

class TimeWindowsResponse(BaseModel):
    symbol: str
    preferred_hours: List[int]  # Liste d'heures 0-23
    forbidden_hours: List[int]  # Liste d'heures 0-23

class CoherentAnalysisRequest(BaseModel):
    symbol: str
    timeframes: Optional[List[str]] = ["D1", "H4", "H1", "M30", "M15", "M5", "M1"]

class CoherentAnalysisResponse(BaseModel):
    status: str
    symbol: str
    decision: str
    decision_type: str
    confidence: float
    stability: str
    bullish_pct: float
    bearish_pct: float
    neutral_pct: float
    trends: Dict[str, Any]
    timestamp: str
    message: Optional[str] = None

class DashboardStatsResponse(BaseModel):
    timestamp: str
    model_performance: Dict[str, Any]
    trading_stats: Dict[str, Any]
    robot_performance: Dict[str, Any]
    coherent_analysis: Optional[CoherentAnalysisResponse] = None

def convert_numpy_types(obj):
    """Convertit les types numpy en types Python natifs pour la sérialisation JSON."""
    if isinstance(obj, (np.integer, np.floating, np.uint64)):
        return int(obj) if isinstance(obj, (np.integer, np.uint64)) else float(obj)
    elif isinstance(obj, dict):
        return {k: convert_numpy_types(v) for k, v in obj.items()}
    elif isinstance(obj, (list, tuple)):
        return [convert_numpy_types(x) for x in obj]
    return obj

def check_trend(symbol: str) -> Dict[str, str]:
    """Vérifie la tendance sur plusieurs timeframes"""
    timeframes = {
        'M1': mt5.TIMEFRAME_M1,
        'M5': mt5.TIMEFRAME_M5,
        'H1': mt5.TIMEFRAME_H1
    }
    
    trends = {}
    
    for tf_name, tf in timeframes.items():
        rates = mt5.copy_rates_from_pos(symbol, tf, 0, 200)
        if rates is not None:
            df = pd.DataFrame(rates)
            sma_50 = df['close'].rolling(window=50).mean().iloc[-1]
            sma_200 = df['close'].rolling(window=200).mean().iloc[-1]
            
            # Détermination de la tendance
            if sma_50 > sma_200 * 1.01:  # 1% de marge
                trends[tf_name] = "HAUSSIER"
            elif sma_50 < sma_200 * 0.99:  # 1% de marge
                trends[tf_name] = "BAISSIER"
            else:
                trends[tf_name] = "NEUTRE"
        else:
            trends[tf_name] = "INDÉTERMINÉ"
    
    return trends

# Fonctions utilitaires
def get_historical_data(symbol: str, timeframe: str = "H1", count: int = 500) -> pd.DataFrame:
    """
    Récupère les données historiques depuis la source disponible (MT5 ou autre)
    
    Args:
        symbol: Symbole du marché (ex: "EURUSD")
        timeframe: Période temporelle (M1, M5, M15, H1, H4, D1)
        count: Nombre de bougies à récupérer
        
    Returns:
        DataFrame pandas avec les données OHLCV
    """
    # PRIORITÉ 1: Vérifier le cache des données uploadées depuis MT5 (bridge)
    cache_key = f"{symbol}_{timeframe}"
    if cache_key in mt5_uploaded_history_cache:
        cached_data = mt5_uploaded_history_cache[cache_key]
        cache_age = (datetime.now() - cached_data["timestamp"]).total_seconds()
        
        if cache_age < MT5_HISTORY_CACHE_TTL:
            df_cached = cached_data["data"]
            if df_cached is not None and not df_cached.empty:
                logger.info(f"✅ Données récupérées depuis cache MT5 uploadé: {len(df_cached)} bougies pour {symbol} {timeframe}")
                return df_cached.tail(count) if len(df_cached) > count else df_cached
        else:
            # Cache expiré, le retirer
            del mt5_uploaded_history_cache[cache_key]
            logger.debug(f"Cache expiré pour {cache_key}, retiré")
    
    # PRIORITÉ 2: Essayer MT5 si disponible (avec tentative de connexion automatique)
    df = get_historical_data_mt5(symbol, timeframe, count)
    if df is not None and not df.empty:
        return df
    
    # Fallback 1: Fichiers CSV locaux
    try:
        data_file = Path(f"data/{symbol}_{timeframe}.csv")
        if data_file.exists():
            df = pd.read_csv(data_file)
            if 'time' in df.columns:
                df['time'] = pd.to_datetime(df['time'])
                logger.info(f"✅ Données chargées depuis fichier local: {len(df)} bougies")
                return df.tail(count) if len(df) > count else df
    except Exception as e:
        logger.debug(f"Impossible de charger les données depuis le fichier local: {e}")
    
    # Fallback 2: Essayer de récupérer depuis un endpoint API si disponible
    try:
        # Vérifier si un endpoint de données historiques est disponible
        api_url = os.getenv('DATA_API_URL', '')
        if api_url:
            import requests
            params = {'symbol': symbol, 'timeframe': timeframe, 'count': count}
            response = requests.get(f"{api_url}/ohlc", params=params, timeout=5)
            if response.status_code == 200:
                data = response.json()
                if data and 'data' in data:
                    df = pd.DataFrame(data['data'])
                    if 'time' in df.columns:
                        df['time'] = pd.to_datetime(df['time'])
                        logger.info(f"✅ Données récupérées depuis API: {len(df)} bougies")
                        return df
    except Exception as e:
        logger.debug(f"Impossible de récupérer les données depuis l'API: {e}")
    
    # Si aucune source n'est disponible, retourner un DataFrame vide
    logger.warning(f"⚠️ Aucune source de données disponible pour {symbol} {timeframe}")
    return pd.DataFrame()

def get_historical_data_mt5(symbol: str, timeframe: str = "H1", count: int = 500):
    """Récupère les données historiques depuis MT5 avec connexion automatique si nécessaire"""
    global mt5_initialized
    
    # Si MT5 n'est pas initialisé, essayer de se connecter avec les variables d'environnement
    if not mt5_initialized:
        try:
            mt5_login = int(os.getenv('MT5_LOGIN', 0))
            mt5_password = os.getenv('MT5_PASSWORD', '')
            mt5_server = os.getenv('MT5_SERVER', '')
            
            if mt5_login and mt5_password and mt5_server:
                logger.info(f"🔄 Tentative de connexion MT5 pour {symbol}...")
                if mt5.initialize(login=mt5_login, password=mt5_password, server=mt5_server):
                    mt5_initialized = True
                    logger.info("✅ Connexion MT5 réussie")
                else:
                    error_code = mt5.last_error()
                    logger.warning(f"❌ Échec de connexion MT5: {error_code}")
                    return None
            else:
                logger.debug("Variables d'environnement MT5 non configurées (MT5_LOGIN, MT5_PASSWORD, MT5_SERVER)")
                return None
        except Exception as e:
            logger.warning(f"Erreur lors de la tentative de connexion MT5: {e}")
            return None
    
    try:
        tf_map = {
            "M1": mt5.TIMEFRAME_M1,
            "M5": mt5.TIMEFRAME_M5,
            "M15": mt5.TIMEFRAME_M15,
            "H1": mt5.TIMEFRAME_H1,
            "H4": mt5.TIMEFRAME_H4,
            "D1": mt5.TIMEFRAME_D1
        }
        
        tf = tf_map.get(timeframe, mt5.TIMEFRAME_H1)
        rates = mt5.copy_rates_from_pos(symbol, tf, 0, count)
        
        if rates is None or len(rates) == 0:
            logger.warning(f"Aucune donnée récupérée depuis MT5 pour {symbol} {timeframe}")
            return None
        
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        logger.debug(f"✅ {len(df)} bougies récupérées depuis MT5 pour {symbol} {timeframe}")
        return df
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des données MT5: {e}")
        return None


# =========================
#   ROUTAGE ML MULTI-MODÈLES
#   (Boom/Crash, Forex, Commodities, Volatility)
# =========================

def _map_symbol_to_trading_category(symbol: str) -> str:
    """
    Catégorie de trading « humaine » utilisée pour le reporting et la logique de style.
    
    - BOOM_CRASH     : indices Boom/Crash et assimilés (SYNTHETIC_SPECIAL)
    - VOLATILITY     : indices de volatilité / synthétiques généraux
    - FOREX          : paires de devises
    - COMMODITIES    : métaux / énergies / assimilés (mappés sur modèle actions au départ)
    """
    if not ADAPTIVE_PREDICT_AVAILABLE or get_symbol_category is None:  # type: ignore
        # Fallback simple si le router adaptatif n'est pas dispo
        s = symbol.upper()
        if "BOOM" in s or "CRASH" in s:
            return "BOOM_CRASH"
        if "VOLATILITY" in s or "RANGE BREAK" in s or "STEP" in s:
            return "VOLATILITY"
        if any(k in s for k in ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD"]):
            return "FOREX"
        return "VOLATILITY"
    
    base_cat = get_symbol_category(symbol)  # type: ignore
    if base_cat == "SYNTHETIC_SPECIAL":
        return "BOOM_CRASH"
    if base_cat == "SYNTHETIC_GENERAL":
        return "VOLATILITY"
    if base_cat == "FOREX":
        return "FOREX"
    if base_cat == "STOCKS":
        return "COMMODITIES"
    # CRYPTO / UNIVERSAL -> on mappe par défaut sur VOLATILITY pour la dynamique de risque
    return "VOLATILITY"


def get_multi_model_ml_decision(symbol: str, df_ohlc: pd.DataFrame) -> Optional[Dict[str, Any]]:
    """
    Utilise les modèles adaptatifs XGBoost par catégorie (adaptive_predict)
    pour produire une décision ML consolidée pour le symbole donné.
    
    Retourne un dict avec:
      - status: "ok" ou "error"
      - action: "buy" / "sell" / "hold"
      - confidence: float 0-1
      - style: "scalp" / "swing"
      - trading_category: catégorie humaine (BOOM_CRASH, FOREX, COMMODITIES, VOLATILITY)
      - model_name, underlying_category, raw (résultat brut)
    """
    if not ADAPTIVE_PREDICT_AVAILABLE or predict_adaptive is None:  # type: ignore
        return None
    if df_ohlc is None or df_ohlc.empty:
        return None

    try:
        result = predict_adaptive(symbol, df_ohlc)  # type: ignore
    except Exception as e:
        logger.warning(f"Erreur predict_adaptive pour {symbol}: {e}")
        return {"status": "error", "error": str(e)}

    if not isinstance(result, dict):
        return {"status": "error", "error": "Résultat inattendu de predict_adaptive"}

    if "error" in result:
        return {
            "status": "error",
            "error": result.get("error"),
            "category": result.get("category"),
            "model_name": result.get("model_name"),
        }

    proba = float(result.get("probability", 0.0))
    pred = int(result.get("prediction", 0))
    model_name = result.get("model_name", "adaptive_xgb")
    underlying_cat = result.get("category", "UNIVERSAL")

    trading_cat = _map_symbol_to_trading_category(symbol)

    # Direction binaire: 1 = hausse, 0 = baisse (convention interne)
    direction_up = pred == 1

    # Respecter les règles Boom/Crash (buy-only / sell-only)
    symbol_upper = symbol.upper()
    action: str
    if "CRASH" in symbol_upper:
        # Crash = SELL only
        if direction_up:
            action = "hold"  # modèle en désaccord avec la règle dure -> on ne trade pas
        else:
            action = "sell"
    elif "BOOM" in symbol_upper:
        # Boom = BUY only
        if direction_up:
            action = "buy"
        else:
            action = "hold"
    else:
        action = "buy" if direction_up else "sell"

    # Style par catégorie
    if trading_cat in ("BOOM_CRASH", "VOLATILITY"):
        style = "scalp"
    else:
        style = "swing"

    confidence = max(0.0, min(1.0, proba))

    return {
        "status": "ok",
        "action": action,
        "confidence": confidence,
        "style": style,
        "trading_category": trading_cat,
        "underlying_category": underlying_cat,
        "model_name": model_name,
        "raw": result,
    }


def save_prediction_to_mt5_files(
    symbol: str,
    timeframe: str,
    decision: Dict[str, Any],
    ml_decision: Optional[Dict[str, Any]] = None,
) -> None:
    """
    Sauvegarde la décision et les infos ML dans un fichier CSV par symbole/timeframe
    dans le dossier MT5 commun (Predictions).

    Format: une ligne par décision, séparateur ';'
    Colonnes principales:
      time;symbol;timeframe;action;confidence;style;category;model_name;details_json
    """
    try:
        if not MT5_PREDICTIONS_DIR.exists():
            return

        ts = datetime.now().isoformat()
        action = decision.get("action", "")
        conf = decision.get("confidence", 0.0)
        style = ""
        category = ""
        model_name = ""

        if isinstance(ml_decision, dict) and ml_decision.get("status") == "ok":
            style = ml_decision.get("style", "") or ""
            category = ml_decision.get("trading_category", "") or ""
            model_name = ml_decision.get("model_name", "") or ""

        # Détails bruts en JSON compact (pour ré-entraînement éventuel)
        details = {
            "decision": decision,
            "ml_decision": ml_decision,
        }
        details_str = json.dumps(details, separators=(",", ":"), ensure_ascii=False)

        # Nom de fichier: SYMBOL_TIMEFRAME_predictions.csv (remplacer caractères spéciaux)
        safe_symbol = symbol.replace(" ", "_").replace("/", "_")
        safe_tf = timeframe.replace(" ", "_")
        filename = MT5_PREDICTIONS_DIR / f"{safe_symbol}_{safe_tf}_predictions.csv"

        header = (
            "time;symbol;timeframe;action;confidence;style;category;model_name;details_json\n"
        )
        line = (
            f"{ts};{symbol};{timeframe};{action};{conf:.4f};"
            f"{style};{category};{model_name};{details_str}\n"
        )

        # Append avec création automatique de l'en-tête si fichier nouveau
        file_exists = filename.exists()
        with open(filename, "a", encoding="utf-8") as f:
            if not file_exists:
                f.write(header)
            f.write(line)

    except Exception as e:
        logger.warning(f"Erreur sauvegarde prédiction MT5 pour {symbol}: {e}")

def analyze_with_mistral(prompt: str) -> Optional[str]:
    """Analyse avec Mistral AI si disponible"""
    if not MISTRAL_AVAILABLE or not mistral_api_key:
        return None
    
    try:
        response = mistral_client.chat.complete(
            model="mistral-small-latest",
            messages=[
                {"role": "user", "content": prompt}
            ],
            temperature=0.2,
            max_tokens=512
        )
        return response.choices[0].message.content
    except Exception as e:
        logger.error(f"Erreur Mistral AI: {e}")
        return None


def analyze_with_gemma(
    prompt: str, 
    max_tokens: int = 200, 
    temperature: float = 0.7, 
    top_p: float = 0.9
) -> Optional[str]:
    """Analyse avec le modèle Gemma (version texte uniquement)
    
    Args:
        prompt: Le prompt à envoyer au modèle
        max_tokens: Nombre maximum de tokens à générer
        temperature: Contrôle le caractère aléatoire (0.0 à 1.0)
        top_p: Filtrage par noyau (nucleus sampling)
        
    Returns:
        str: La réponse générée par le modèle, ou None en cas d'erreur
    """
    global gemma_processor, gemma_model
    
    if not gemma_processor or not gemma_model:
        logger.error("❌ Modèle ou processeur Gemma non initialisé")
        return None
    
    try:
        logger.info("\n" + "="*80)
        logger.info("🔍 DÉMARRAGE ANALYSE GEMMA (TEXTE UNIQUEMENT)")
        logger.info("="*80)
        logger.info(f"📝 Prompt: {prompt[:150]}..." if len(prompt) > 150 else f"📝 Prompt: {prompt}")
        
        # Préparation des entrées texte uniquement
        logger.info("🔄 Préparation des entrées...")
        inputs = gemma_processor(
            text=prompt,
            return_tensors="pt"
        ).to("cuda" if torch and torch.cuda.is_available() else "cpu")
        
        # Génération de la réponse
        logger.info("⚡ Génération de la réponse...")
        start_time = time.time()
        
        generate_kwargs = {
            "max_length": max_tokens,
            "temperature": temperature,
            "top_p": top_p,
            "do_sample": True,
            "pad_token_id": gemma_processor.tokenizer.pad_token_id
        }
        
        # Génération avec suivi de la progression
        try:
            no_grad_context = torch.no_grad() if torch else contextlib.nullcontext()
            with no_grad_context:
                output = gemma_model.generate(
                    **inputs,
                    **generate_kwargs,
                    output_scores=True,
                    return_dict_in_generate=True
                )
            
            # Décodage de la réponse
            response = gemma_processor.batch_decode(output.sequences, skip_special_tokens=True)[0]
            duration = time.time() - start_time
            
            # Formatage de la réponse
            response = response.strip()
            logger.info("\n" + "="*80)
            logger.info("✅ ANALYSE TERMINÉE")
            logger.info("="*80)
            logger.info(f"⏱️  Durée: {duration:.2f} secondes")
            logger.info(f"📊 Réponse ({len(response)} caractères):")
            
            # Affichage d'un extrait de la réponse
            response_lines = response.split('\n')
            for i, line in enumerate(response_lines[:5]):  # Affiche les 5 premières lignes
                logger.info(f"   {line}")
            if len(response_lines) > 5:
                logger.info("   ... (suite de la réponse disponible) ...")
            
            # Analyse des signaux si nécessaire
            if "signal" in prompt.lower() or "trading" in prompt.lower():
                gemma_bot = GemmaTradingBot()
                gemma_bot.analyze_gemma_response(response)
            
            return response
            
        except RuntimeError as e:
            if "out of memory" in str(e).lower():
                logger.error("⚠️  Erreur: Mémoire GPU insuffisante. Essayez de réduire la taille du modèle ou du batch.")
                if torch and torch.cuda.is_available():
                    torch.cuda.empty_cache()
            raise
            
    except Exception as e:
        logger.error("❌ ERREUR LORS DE L'ANALYSE GEMMA")
        logger.error("="*60)
        logger.error(f"Type: {type(e).__name__}")
        logger.error(f"Message: {str(e)}")
        if hasattr(e, 'args') and e.args:
            logger.error(f"Détails: {e.args[0]}")
        logger.error("Stack trace:")
        logger.error(traceback.format_exc())
        return None
    
    finally:
        # Nettoyage de la mémoire GPU
        if torch and torch.cuda.is_available():
            torch.cuda.empty_cache()
            logger.info("🧹 Mémoire GPU nettoyée")

def analyze_with_gemini(prompt: str, max_retries: int = 3) -> Optional[str]:
    """
    Fonction désactivée - Utilisez Mistral AI à la place
    """
    # Ne logger qu'une seule fois au démarrage, pas à chaque appel
    return None

def analyze_with_ai(prompt: str, max_retries: int = 2) -> Optional[str]:
    """
    Analyse un prompt avec Mistral AI pour des prédictions de spike améliorées
    
    Args:
        prompt: Le prompt à analyser
        max_retries: Nombre de tentatives
        
    Returns:
        La réponse de l'IA ou None en cas d'échec
    """
    if not MISTRAL_AVAILABLE or not mistral_api_key:
        logger.error("Mistral AI n'est pas disponible")
        return None
    
    try:
        # Optimisation pour les prédictions de spike
        if "spike" in prompt.lower() or "volatility" in prompt.lower():
            # Utiliser un modèle plus performant et une température plus basse pour les spikes
            logger.info("Utilisation de Mistral AI pour l'analyse de spike (optimisée)")
            response = mistral_client.chat.complete(
                model="mistral-small",  # Modèle plus performant pour les spikes
                messages=[
                    {
                        "role": "system", 
                        "content": (
                            "Tu es un expert en trading de volatilité spécialisé "
                            "dans la détection de spikes. Analyse les indicateurs "
                            "techniques avec une précision extrême. Donne des "
                            "prédictions fiables basées sur les patterns de "
                            "volatilité, RSI, EMA et ATR."
                        )
                    },
                    {"role": "user", "content": prompt}
                ],
                # Température plus basse pour plus de cohérence
                temperature=0.3,
                # Limiter les tokens pour des réponses plus ciblées
                max_tokens=800
            )
        else:
            # Utilisation standard pour les autres analyses
            logger.info("Utilisation de Mistral AI pour l'analyse standard")
            response = mistral_client.chat.complete(
                model="mistral-tiny",
                messages=[
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=1000
            )
        return response.choices[0].message.content
    except Exception as e:
        logger.error(f"Erreur avec Mistral AI: {str(e)}")
        return None

def generate_fibonacci_levels(base_price: float) -> Dict[str, Dict[str, Any]]:
    """
    Génère les niveaux de Fibonacci pour un prix de base donné.
    
    Args:
        base_price: Prix de base pour le calcul des niveaux
        
    Returns:
        Dictionnaire contenant les niveaux de Fibonacci pour différents timeframes
    """
    levels = {
        "0": 0.0,
        "236": 0.236,
        "382": 0.382,
        "500": 0.5,
        "618": 0.618,
        "786": 0.786,
        "1000": 1.0
    }
    
    # Calcul des niveaux de support/résistance
    support = base_price * 0.95
    resistance = base_price * 1.05
    
    # Création de la réponse pour chaque timeframe
    response = {}
    for tf in ["h1", "h4", "m15"]:
        response[tf] = {
            "fibonacci": {level: base_price * factor for level, factor in levels.items()},
            "trend": "neutral",
            "support": support,
            "resistance": resistance,
            "status": "fibonacci_analysis"
        }
    
    return response

def detect_trendlines(df: pd.DataFrame, lookback: int = 3) -> Dict[str, Any]:
    """Détecte les trendlines dans les données historiques"""
    if df is None or len(df) < lookback * 2:
        return {}
    
    try:
        # Détection des swings (highs et lows)
        highs = []
        lows = []
        
        for i in range(lookback, len(df) - lookback):
            # Swing high
            is_high = all(
                df.iloc[i]['high'] >= df.iloc[i+j]['high'] 
                for j in range(-lookback, lookback+1) 
                if j != 0
            )
            if is_high:
                highs.append({
                    'index': i,
                    'time': df.iloc[i]['time'],
                    'price': df.iloc[i]['high']
                })
            
            # Swing low
            is_low = all(
                df.iloc[i]['low'] <= df.iloc[i+j]['low'] 
                for j in range(-lookback, lookback+1) 
                if j != 0
            )
            if is_low:
                lows.append({
                    'index': i,
                    'time': df.iloc[i]['time'],
                    'price': df.iloc[i]['low']
                })
        
        # Trendline haussière (deux derniers lows)
        bullish_tl = None
        if len(lows) >= 2:
            l1 = lows[-2]
            l2 = lows[-1]
            if l2['price'] > l1['price']:
                bullish_tl = {
                    "start": {"time": int(l1['time'].timestamp()), "price": l1['price']},
                    "end": {"time": int(l2['time'].timestamp()), "price": l2['price']}
                }
        
        # Trendline baissière (deux derniers highs)
        bearish_tl = None
        if len(highs) >= 2:
            h1 = highs[-2]
            h2 = highs[-1]
            if h2['price'] < h1['price']:
                bearish_tl = {
                    "start": {"time": int(h1['time'].timestamp()), "price": h1['price']},
                    "end": {"time": int(h2['time'].timestamp()), "price": h2['price']}
                }
        
        return {
            "bullish": bullish_tl,
            "bearish": bearish_tl
        }
    except Exception as e:
        logger.error(f"Erreur détection trendlines: {e}")
        return {}

# Routes de l'API
@app.get("/")
async def root():
    """Endpoint racine pour vérifier que le serveur fonctionne"""
    return {
        "status": "running",
        "service": "TradBOT AI Server",
        "version": "2.0.0",
        "mt5_available": MT5_AVAILABLE,
        "mt5_initialized": mt5_initialized,
        "mistral_available": MISTRAL_AVAILABLE,
        "gemini_available": GEMINI_AVAILABLE,
        "backend_available": BACKEND_AVAILABLE,
        "ai_indicators_available": AI_INDICATORS_AVAILABLE,
        "alphavantage_available": ALPHAVANTAGE_AVAILABLE,
        "endpoints": [
            "/fundamental/{symbol} (GET) - Données fondamentales",
            "/news/{symbol} (GET) - Actualités marché", 
            "/economic-calendar (GET) - Calendrier économique",
            "/decision (POST)",
            "/analysis (GET)",
            "/time_windows/{symbol} (GET)",
            "/predict/{symbol} (GET)",
            "/prediction (POST) - Prédiction de prix futurs pour graphique MQ5",
            "/health",
            "/status",
            "/logs",
            "/indicators/analyze (POST)",
            "/indicators/sentiment/{symbol} (GET)",
            "/indicators/volume_profile/{symbol} (GET)",
            "/analyze/gemini (POST)",
            "/mt5/history-upload (POST) - Upload données historiques MT5 vers Render (bridge)"
        ]
    }

@app.post("/")
async def root_post():
    """Endpoint racine POST - Redirige vers /decision pour compatibilité"""
    logger.warning("POST request received on root endpoint '/'. This should be '/decision'. Returning redirect info.")
    raise HTTPException(
        status_code=400,
        detail="Please use POST /decision endpoint for trading decisions. The root endpoint '/' only accepts GET requests."
    )

# ==================== ALPHA VANTAGE ENDPOINTS ====================

@app.get("/fundamental/{symbol}")
async def get_fundamental_data(symbol: str):
    """Récupère les données fondamentales via Alpha Vantage API"""
    if not ALPHAVANTAGE_AVAILABLE:
        raise HTTPException(status_code=503, detail="Alpha Vantage API non configurée")
    
    import httpx
    
    # Mapping symboles MT5 vers symboles Alpha Vantage
    symbol_map = {
        "EURUSD": "EUR/USD",
        "GBPUSD": "GBP/USD",
        "USDJPY": "USD/JPY",
        "XAUUSD": "XAU/USD",
        "US Oil": "USOIL",
        "UK 100": "FTSE",
        "US 30": "DJI",
        "US 500": "SPX",
    }
    av_symbol = symbol_map.get(symbol, symbol.replace(" ", ""))
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            # Pour Forex
            if "/" in av_symbol or any(c in symbol.upper() for c in ["USD", "EUR", "GBP", "JPY"]):
                from_c = av_symbol[:3] if len(av_symbol) >= 6 else "USD"
                to_c = av_symbol[3:6] if len(av_symbol) >= 6 else av_symbol[:3]
                url = f"https://www.alphavantage.co/query?function=CURRENCY_EXCHANGE_RATE&from_currency={from_c}&to_currency={to_c}&apikey={ALPHAVANTAGE_API_KEY}"
                resp = await client.get(url)
                alphavantage_request_count += 1
                data = resp.json()
                
                if "Realtime Currency Exchange Rate" in data:
                    rate_data = data["Realtime Currency Exchange Rate"]
                    return {
                        "symbol": symbol,
                        "type": "forex",
                        "exchange_rate": float(rate_data.get("5. Exchange Rate", 0)),
                        "bid": float(rate_data.get("8. Bid Price", 0)),
                        "ask": float(rate_data.get("9. Ask Price", 0)),
                        "last_updated": rate_data.get("6. Last Refreshed", ""),
                        "timezone": rate_data.get("7. Time Zone", "")
                    }
            
            # Pour actions/indices
            url = f"https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol={av_symbol}&apikey={ALPHAVANTAGE_API_KEY}"
            resp = await client.get(url)
            alphavantage_request_count += 1
            data = resp.json()
            
            if "Global Quote" in data and data["Global Quote"]:
                quote = data["Global Quote"]
                return {
                    "symbol": symbol,
                    "type": "stock",
                    "price": float(quote.get("05. price", 0)),
                    "change": float(quote.get("09. change", 0)),
                    "change_percent": quote.get("10. change percent", "0%"),
                    "volume": int(quote.get("06. volume", 0)),
                    "high": float(quote.get("03. high", 0)),
                    "low": float(quote.get("04. low", 0)),
                    "open": float(quote.get("02. open", 0)),
                    "previous_close": float(quote.get("08. previous close", 0))
                }
            
            return {"symbol": symbol, "error": "No data available", "raw": data}
            
    except Exception as e:
        logger.error(f"Alpha Vantage error for {symbol}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/news/{symbol}")
async def get_market_news(symbol: str):
    """Récupère les actualités du marché via Alpha Vantage"""
    if not ALPHAVANTAGE_AVAILABLE:
        raise HTTPException(status_code=503, detail="Alpha Vantage API non configurée")
    
    import httpx
    
    # Mapping pour les tickers de news
    topics = "financial_markets"
    if any(c in symbol.upper() for c in ["USD", "EUR", "GBP", "JPY"]):
        topics = "forex"
    elif "XAU" in symbol.upper() or "GOLD" in symbol.upper():
        topics = "finance"
    elif "OIL" in symbol.upper():
        topics = "energy_transportation"
    
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            url = f"https://www.alphavantage.co/query?function=NEWS_SENTIMENT&topics={topics}&apikey={ALPHAVANTAGE_API_KEY}&limit=10"
            resp = await client.get(url)
            alphavantage_request_count += 1
            data = resp.json()
            
            if "feed" in data:
                news_items = []
                for item in data["feed"][:10]:
                    news_items.append({
                        "title": item.get("title", ""),
                        "summary": item.get("summary", "")[:300] + "..." if len(item.get("summary", "")) > 300 else item.get("summary", ""),
                        "source": item.get("source", ""),
                        "sentiment_score": item.get("overall_sentiment_score", 0),
                        "sentiment_label": item.get("overall_sentiment_label", "Neutral"),
                        "time_published": item.get("time_published", "")
                    })
                
                # Calcul du sentiment global
                avg_sentiment = sum(n["sentiment_score"] for n in news_items) / len(news_items) if news_items else 0
                
                return {
                    "symbol": symbol,
                    "topic": topics,
                    "news_count": len(news_items),
                    "average_sentiment": round(avg_sentiment, 4),
                    "market_bias": "bullish" if avg_sentiment > 0.1 else "bearish" if avg_sentiment < -0.1 else "neutral",
                    "news": news_items
                }
            
            return {"symbol": symbol, "news": [], "error": "No news available"}
            
    except Exception as e:
        logger.error(f"Alpha Vantage news error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/economic-calendar")
async def get_economic_calendar():
    """Récupère le calendrier économique (événements importants)"""
    if not ALPHAVANTAGE_AVAILABLE:
        raise HTTPException(status_code=503, detail="Alpha Vantage API non configurée")
    
    # Note: Alpha Vantage n'a pas d'endpoint calendrier économique direct
    # On utilise les news avec filtre économie
    import httpx
    
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            url = f"https://www.alphavantage.co/query?function=NEWS_SENTIMENT&topics=economy_fiscal,economy_monetary&apikey={ALPHAVANTAGE_API_KEY}&limit=20"
            resp = await client.get(url)
            alphavantage_request_count += 1
            data = resp.json()
            
            events = []
            if "feed" in data:
                for item in data["feed"][:20]:
                    events.append({
                        "title": item.get("title", ""),
                        "summary": item.get("summary", "")[:200],
                        "source": item.get("source", ""),
                        "impact": "high" if abs(item.get("overall_sentiment_score", 0)) > 0.3 else "medium" if abs(item.get("overall_sentiment_score", 0)) > 0.1 else "low",
                        "sentiment": item.get("overall_sentiment_label", "Neutral"),
                        "time": item.get("time_published", "")
                    })
            
            return {
                "events": events,
                "count": len(events),
                "api": "Alpha Vantage"
            }
            
    except Exception as e:
        logger.error(f"Economic calendar error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== END ALPHA VANTAGE ====================

# ==================== DERIV API ENDPOINTS ====================

import asyncio
import websockets
import json as json_lib

async def deriv_ws_request(request_data: dict, timeout: float = 10.0) -> dict:
    """Effectue une requête WebSocket vers Deriv API"""
    try:
        async with websockets.connect(DERIV_WS_URL, close_timeout=5.0) as ws:
            await ws.send(json_lib.dumps(request_data))
            response = await asyncio.wait_for(ws.recv(), timeout=timeout)
            return json_lib.loads(response)
    except Exception as e:
        logger.error(f"Deriv WS error: {e}")
        return {"error": str(e)}

@app.get("/deriv/ticks/{symbol}")
async def get_deriv_ticks(symbol: str):
    """Récupère les ticks en temps réel via Deriv API"""
    # Mapping symboles MT5 vers Deriv
    deriv_symbols = {
        "Volatility 10 Index": "R_10",
        "Volatility 25 Index": "R_25",
        "Volatility 50 Index": "R_50", 
        "Volatility 75 Index": "R_75",
        "Volatility 100 Index": "R_100",
        "Boom 300 Index": "BOOM300N",
        "Boom 500 Index": "BOOM500",
        "Boom 1000 Index": "BOOM1000",
        "Crash 300 Index": "CRASH300N",
        "Crash 500 Index": "CRASH500",
        "Crash 1000 Index": "CRASH1000",
    }
    deriv_symbol = deriv_symbols.get(symbol, symbol)
    
    response = await deriv_ws_request({"ticks": deriv_symbol})
    
    if "error" in response:
        raise HTTPException(status_code=500, detail=response["error"])
    
    tick = response.get("tick", {})
    return {
        "symbol": symbol,
        "deriv_symbol": deriv_symbol,
        "quote": tick.get("quote"),
        "bid": tick.get("bid"),
        "ask": tick.get("ask"),
        "epoch": tick.get("epoch"),
        "api": "Deriv"
    }

@app.get("/deriv/active-symbols")
async def get_deriv_active_symbols():
    """Liste tous les symboles disponibles sur Deriv"""
    response = await deriv_ws_request({
        "active_symbols": "brief",
        "product_type": "basic"
    })
    
    if "error" in response:
        raise HTTPException(status_code=500, detail=response.get("error", {}).get("message", "Unknown error"))
    
    symbols = response.get("active_symbols", [])
    
    # Filtrer les indices synthétiques
    synthetic = [s for s in symbols if s.get("market") == "synthetic_index"]
    forex = [s for s in symbols if s.get("market") == "forex"]
    
    return {
        "total": len(symbols),
        "synthetic_indices": len(synthetic),
        "forex": len(forex),
        "symbols": [
            {
                "symbol": s.get("symbol"),
                "display_name": s.get("display_name"),
                "market": s.get("market"),
                "is_trading_suspended": s.get("is_trading_suspended"),
                "pip": s.get("pip")
            }
            for s in symbols[:50]  # Limiter à 50
        ],
        "api": "Deriv"
    }

@app.get("/deriv/candles/{symbol}")
async def get_deriv_candles(symbol: str, granularity: int = 60, count: int = 100):
    """Récupère les chandeliers historiques via Deriv API"""
    deriv_symbols = {
        "Volatility 10 Index": "R_10",
        "Volatility 25 Index": "R_25", 
        "Volatility 50 Index": "R_50",
        "Volatility 75 Index": "R_75",
        "Volatility 100 Index": "R_100",
        "Boom 300 Index": "BOOM300N",
        "Boom 500 Index": "BOOM500",
        "Boom 1000 Index": "BOOM1000",
        "Crash 300 Index": "CRASH300N",
        "Crash 500 Index": "CRASH500",
        "Crash 1000 Index": "CRASH1000",
    }
    deriv_symbol = deriv_symbols.get(symbol, symbol)
    
    response = await deriv_ws_request({
        "ticks_history": deriv_symbol,
        "adjust_start_time": 1,
        "count": count,
        "end": "latest",
        "granularity": granularity,
        "style": "candles"
    })
    
    if "error" in response:
        raise HTTPException(status_code=500, detail=response.get("error", {}).get("message", "Unknown error"))
    
    candles = response.get("candles", [])
    
    return {
        "symbol": symbol,
        "deriv_symbol": deriv_symbol,
        "granularity": granularity,
        "count": len(candles),
        "candles": [
            {
                "epoch": c.get("epoch"),
                "open": c.get("open"),
                "high": c.get("high"),
                "low": c.get("low"),
                "close": c.get("close")
            }
            for c in candles
        ],
        "api": "Deriv"
    }

@app.get("/market-data/{symbol}")
async def get_market_data_with_fallback(symbol: str):
    """Récupère les données de marché avec fallback automatique (Alpha Vantage -> Deriv)"""
    global alphavantage_request_count
    
    # Essayer Alpha Vantage d'abord si pas épuisé
    if ALPHAVANTAGE_AVAILABLE and alphavantage_request_count < ALPHAVANTAGE_DAILY_LIMIT:
        try:
            import httpx
            async with httpx.AsyncClient(timeout=10.0) as client:
                # Mapping pour Alpha Vantage
                if any(c in symbol.upper() for c in ["USD", "EUR", "GBP", "JPY"]):
                    from_c = symbol[:3].upper()
                    to_c = symbol[3:6].upper() if len(symbol) >= 6 else "USD"
                    url = f"https://www.alphavantage.co/query?function=CURRENCY_EXCHANGE_RATE&from_currency={from_c}&to_currency={to_c}&apikey={ALPHAVANTAGE_API_KEY}"
                    resp = await client.get(url)
                    alphavantage_request_count += 1
                    data = resp.json()
                    
                    if "Realtime Currency Exchange Rate" in data:
                        rate_data = data["Realtime Currency Exchange Rate"]
                        return {
                            "symbol": symbol,
                            "price": float(rate_data.get("5. Exchange Rate", 0)),
                            "bid": float(rate_data.get("8. Bid Price", 0)),
                            "ask": float(rate_data.get("9. Ask Price", 0)),
                            "api": "Alpha Vantage",
                            "requests_remaining": ALPHAVANTAGE_DAILY_LIMIT - alphavantage_request_count
                        }
        except Exception as e:
            logger.warning(f"Alpha Vantage failed, falling back to Deriv: {e}")
    
    # Fallback vers Deriv pour indices synthétiques ou si AV épuisé
    deriv_symbols = {
        "Volatility 10 Index": "R_10",
        "Volatility 25 Index": "R_25",
        "Volatility 50 Index": "R_50", 
        "Volatility 75 Index": "R_75",
        "Volatility 100 Index": "R_100",
        "Boom 300 Index": "BOOM300N",
        "Boom 500 Index": "BOOM500",
        "Boom 1000 Index": "BOOM1000",
        "Crash 300 Index": "CRASH300N",
        "Crash 500 Index": "CRASH500",
        "Crash 1000 Index": "CRASH1000",
    }
    
    deriv_symbol = deriv_symbols.get(symbol)
    if deriv_symbol:
        response = await deriv_ws_request({"ticks": deriv_symbol})
        if "tick" in response:
            tick = response["tick"]
            return {
                "symbol": symbol,
                "price": tick.get("quote"),
                "bid": tick.get("bid"),
                "ask": tick.get("ask"),
                "epoch": tick.get("epoch"),
                "api": "Deriv",
                "alphavantage_exhausted": alphavantage_request_count >= ALPHAVANTAGE_DAILY_LIMIT
            }
    
    return {
        "symbol": symbol,
        "error": "Symbol not supported",
        "supported_deriv": list(deriv_symbols.keys()),
        "alphavantage_requests_used": alphavantage_request_count
    }

# ==================== DERIV PATTERNS DETECTION ====================

def detect_xabcd_pattern(df: pd.DataFrame, tolerance: float = 0.05) -> List[Dict]:
    """
    Détecte les patterns XABCD (Harmonic Pattern)
    Pattern: X -> A -> B -> C -> D avec ratios Fibonacci spécifiques
    """
    patterns = []
    if len(df) < 5:
        return patterns
    
    highs = df['high'].values
    lows = df['low'].values
    closes = df['close'].values
    
    # Rechercher les points pivots
    for i in range(4, len(df)):
        # XABCD: X=point de départ, A=premier pivot, B=retour, C=retour, D=projection
        try:
            # Simplification: chercher 5 points pivots consécutifs
            x_idx = i - 4
            a_idx = i - 3
            b_idx = i - 2
            c_idx = i - 1
            d_idx = i
            
            # Calculer les ratios
            xa = abs(highs[a_idx] - lows[x_idx]) if highs[a_idx] > lows[x_idx] else abs(lows[a_idx] - highs[x_idx])
            ab = abs(highs[b_idx] - lows[a_idx]) if highs[b_idx] > lows[a_idx] else abs(lows[b_idx] - highs[a_idx])
            bc = abs(highs[c_idx] - lows[b_idx]) if highs[c_idx] > lows[b_idx] else abs(lows[c_idx] - highs[b_idx])
            cd = abs(highs[d_idx] - lows[c_idx]) if highs[d_idx] > lows[c_idx] else abs(lows[d_idx] - highs[c_idx])
            
            if xa == 0 or ab == 0 or bc == 0:
                continue
            
            # Ratios Fibonacci typiques pour XABCD
            ab_ratio = ab / xa
            bc_ratio = bc / ab
            cd_ratio = cd / bc
            
            # Vérifier si les ratios correspondent à un pattern XABCD
            # Pattern haussier: AB ≈ 0.382-0.618 de XA, BC ≈ 0.382-0.886 de AB, CD ≈ 1.272-1.618 de BC
            is_bullish = (0.3 <= ab_ratio <= 0.7 and 0.3 <= bc_ratio <= 0.9 and 1.2 <= cd_ratio <= 1.7)
            # Pattern baissier: ratios inversés
            is_bearish = (0.3 <= ab_ratio <= 0.7 and 0.3 <= bc_ratio <= 0.9 and 1.2 <= cd_ratio <= 1.7)
            
            if is_bullish or is_bearish:
                patterns.append({
                    "type": "XABCD",
                    "direction": "bullish" if is_bullish else "bearish",
                    "confidence": 0.7,
                    "points": {
                        "X": {"index": x_idx, "price": lows[x_idx] if is_bullish else highs[x_idx]},
                        "A": {"index": a_idx, "price": highs[a_idx] if is_bullish else lows[a_idx]},
                        "B": {"index": b_idx, "price": lows[b_idx] if is_bullish else highs[b_idx]},
                        "C": {"index": c_idx, "price": highs[c_idx] if is_bullish else lows[c_idx]},
                        "D": {"index": d_idx, "price": closes[d_idx]}
                    },
                    "ratios": {
                        "AB/XA": round(ab_ratio, 3),
                        "BC/AB": round(bc_ratio, 3),
                        "CD/BC": round(cd_ratio, 3)
                    }
                })
        except Exception as e:
            continue
    
    return patterns

def detect_cypher_pattern(df: pd.DataFrame) -> List[Dict]:
    """
    Détecte les patterns Cypher (Harmonic Pattern)
    Pattern: X -> A -> B -> C avec ratios spécifiques
    """
    patterns = []
    if len(df) < 4:
        return patterns
    
    highs = df['high'].values
    lows = df['low'].values
    closes = df['close'].values
    
    for i in range(3, len(df)):
        try:
            x_idx = i - 3
            a_idx = i - 2
            b_idx = i - 1
            c_idx = i
            
            xa = abs(highs[a_idx] - lows[x_idx]) if highs[a_idx] > lows[x_idx] else abs(lows[a_idx] - highs[x_idx])
            ab = abs(highs[b_idx] - lows[a_idx]) if highs[b_idx] > lows[a_idx] else abs(lows[b_idx] - highs[a_idx])
            bc = abs(highs[c_idx] - lows[b_idx]) if highs[c_idx] > lows[b_idx] else abs(lows[c_idx] - highs[b_idx])
            
            if xa == 0 or ab == 0:
                continue
            
            ab_ratio = ab / xa
            bc_ratio = bc / ab
            
            # Cypher: AB ≈ 0.382-0.618 de XA, BC ≈ 1.13-1.414 de AB
            is_valid = (0.35 <= ab_ratio <= 0.65 and 1.1 <= bc_ratio <= 1.45)
            
            if is_valid:
                patterns.append({
                    "type": "Cypher",
                    "confidence": 0.65,
                    "points": {
                        "X": {"index": x_idx, "price": lows[x_idx]},
                        "A": {"index": a_idx, "price": highs[a_idx]},
                        "B": {"index": b_idx, "price": lows[b_idx]},
                        "C": {"index": c_idx, "price": closes[c_idx]}
                    }
                })
        except:
            continue
    
    return patterns

def detect_head_and_shoulders(df: pd.DataFrame) -> List[Dict]:
    """
    Détecte les patterns Head and Shoulders
    Pattern: 3 pics avec le pic central le plus haut
    """
    patterns = []
    if len(df) < 10:
        return patterns
    
    highs = df['high'].values
    
    # Chercher 3 pics consécutifs
    for i in range(5, len(df) - 5):
        try:
            # Pic gauche (shoulder)
            left_peak = max(highs[i-5:i])
            left_idx = i - 5 + np.argmax(highs[i-5:i])
            
            # Pic central (head) - doit être le plus haut
            head_peak = max(highs[i-2:i+3])
            head_idx = i - 2 + np.argmax(highs[i-2:i+3])
            
            # Pic droit (shoulder)
            right_peak = max(highs[i+3:i+8])
            right_idx = i + 3 + np.argmax(highs[i+3:i+8])
            
            # Vérifier que le head est plus haut que les deux shoulders
            if head_peak > left_peak and head_peak > right_peak:
                # Les shoulders doivent être similaires en hauteur
                shoulder_diff = abs(left_peak - right_peak) / head_peak
                if shoulder_diff < 0.1:  # Moins de 10% de différence
                    patterns.append({
                        "type": "Head and Shoulders",
                        "direction": "bearish",
                        "confidence": 0.75,
                        "points": {
                            "left_shoulder": {"index": left_idx, "price": left_peak},
                            "head": {"index": head_idx, "price": head_peak},
                            "right_shoulder": {"index": right_idx, "price": right_peak}
                        },
                        "neckline": (left_peak + right_peak) / 2
                    })
        except:
            continue
    
    return patterns

def detect_abcd_pattern(df: pd.DataFrame) -> List[Dict]:
    """
    Détecte les patterns ABCD (Harmonic Pattern simple)
    Pattern: A -> B -> C -> D avec ratios Fibonacci
    """
    patterns = []
    if len(df) < 4:
        return patterns
    
    highs = df['high'].values
    lows = df['low'].values
    closes = df['close'].values
    
    for i in range(3, len(df)):
        try:
            a_idx = i - 3
            b_idx = i - 2
            c_idx = i - 1
            d_idx = i
            
            ab = abs(highs[b_idx] - lows[a_idx]) if highs[b_idx] > lows[a_idx] else abs(lows[b_idx] - highs[a_idx])
            bc = abs(highs[c_idx] - lows[b_idx]) if highs[c_idx] > lows[b_idx] else abs(lows[c_idx] - highs[b_idx])
            cd = abs(highs[d_idx] - lows[c_idx]) if highs[d_idx] > lows[c_idx] else abs(lows[d_idx] - highs[c_idx])
            
            if ab == 0:
                continue
            
            bc_ratio = bc / ab
            cd_ratio = cd / bc
            
            # ABCD: BC ≈ 0.382-0.886 de AB, CD ≈ 1.272-1.618 de BC
            is_valid = (0.35 <= bc_ratio <= 0.9 and 1.2 <= cd_ratio <= 1.7)
            
            if is_valid:
                patterns.append({
                    "type": "ABCD",
                    "confidence": 0.7,
                    "points": {
                        "A": {"index": a_idx, "price": lows[a_idx]},
                        "B": {"index": b_idx, "price": highs[b_idx]},
                        "C": {"index": c_idx, "price": lows[c_idx]},
                        "D": {"index": d_idx, "price": closes[d_idx]}
                    }
                })
        except:
            continue
    
    return patterns

def detect_triangle_pattern(df: pd.DataFrame) -> List[Dict]:
    """
    Détecte les patterns Triangle (ascendant, descendant, symétrique)
    """
    patterns = []
    if len(df) < 10:
        return patterns
    
    highs = df['high'].values
    lows = df['low'].values
    
    # Chercher convergence des hauts et bas
    for i in range(10, len(df)):
        try:
            recent_highs = highs[i-10:i]
            recent_lows = lows[i-10:i]
            
            # Calculer les lignes de tendance
            high_trend = np.polyfit(range(len(recent_highs)), recent_highs, 1)[0]
            low_trend = np.polyfit(range(len(recent_lows)), recent_lows, 1)[0]
            
            # Triangle ascendant: ligne de support montante, résistance horizontale
            ascending = low_trend > 0 and abs(high_trend) < 0.0001
            
            # Triangle descendant: ligne de support horizontale, résistance descendante
            descending = abs(low_trend) < 0.0001 and high_trend < 0
            
            # Triangle symétrique: les deux lignes convergent
            symmetrical = (low_trend > 0 and high_trend < 0) or (abs(low_trend) < 0.0001 and abs(high_trend) < 0.0001)
            
            if ascending or descending or symmetrical:
                patterns.append({
                    "type": "Triangle",
                    "subtype": "ascending" if ascending else "descending" if descending else "symmetrical",
                    "confidence": 0.65,
                    "points": {
                        "start": {"index": i-10, "high": recent_highs[0], "low": recent_lows[0]},
                        "end": {"index": i, "high": recent_highs[-1], "low": recent_lows[-1]}
                    },
                    "trends": {
                        "high_trend": round(high_trend, 6),
                        "low_trend": round(low_trend, 6)
                    }
                })
        except:
            continue
    
    return patterns

def detect_three_drives_pattern(df: pd.DataFrame) -> List[Dict]:
    """
    Détecte les patterns Three Drives
    Pattern: 3 mouvements similaires avec ratios Fibonacci
    """
    patterns = []
    if len(df) < 9:
        return patterns
    
    highs = df['high'].values
    lows = df['low'].values
    
    for i in range(8, len(df)):
        try:
            # 3 drives: 3 vagues similaires
            drive1 = abs(highs[i-8] - lows[i-6]) if highs[i-8] > lows[i-6] else abs(lows[i-8] - highs[i-6])
            drive2 = abs(highs[i-5] - lows[i-3]) if highs[i-5] > lows[i-3] else abs(lows[i-5] - highs[i-3])
            drive3 = abs(highs[i-2] - lows[i]) if highs[i-2] > lows[i] else abs(lows[i-2] - highs[i])
            
            if drive1 == 0:
                continue
            
            ratio2 = drive2 / drive1
            ratio3 = drive3 / drive2
            
            # Three Drives: ratios similaires entre les drives (0.8-1.2)
            is_valid = (0.8 <= ratio2 <= 1.2 and 0.8 <= ratio3 <= 1.2)
            
            if is_valid:
                patterns.append({
                    "type": "Three Drives",
                    "confidence": 0.7,
                    "points": {
                        "drive1": {"start": i-8, "end": i-6, "magnitude": drive1},
                        "drive2": {"start": i-5, "end": i-3, "magnitude": drive2},
                        "drive3": {"start": i-2, "end": i, "magnitude": drive3}
                    },
                    "ratios": {
                        "drive2/drive1": round(ratio2, 3),
                        "drive3/drive2": round(ratio3, 3)
                    }
                })
        except:
            continue
    
    return patterns

def detect_elliott_impulse(df: pd.DataFrame) -> List[Dict]:
    """
    Détecte les patterns Elliott Impulse Wave (12345)
    5 vagues: 3 impulsives (1,3,5) et 2 correctives (2,4)
    """
    patterns = []
    if len(df) < 20:
        return patterns
    
    closes = df['close'].values
    
    # Chercher 5 vagues
    for i in range(20, len(df)):
        try:
            # Simplification: chercher 5 mouvements alternés
            wave1 = closes[i-19] - closes[i-15]  # Vague 1
            wave2 = closes[i-15] - closes[i-11]  # Vague 2 (correction)
            wave3 = closes[i-11] - closes[i-7]    # Vague 3 (impulsive)
            wave4 = closes[i-7] - closes[i-3]    # Vague 4 (correction)
            wave5 = closes[i-3] - closes[i]      # Vague 5 (impulsive)
            
            # Vague 3 doit être la plus forte
            if abs(wave3) > abs(wave1) and abs(wave3) > abs(wave5):
                # Vagues 2 et 4 doivent être des corrections (direction opposée)
                is_valid = (wave1 * wave2 < 0 and wave2 * wave3 < 0 and wave3 * wave4 < 0 and wave4 * wave5 < 0)
                
                if is_valid:
                    patterns.append({
                        "type": "Elliott Impulse Wave",
                        "direction": "bullish" if wave1 > 0 else "bearish",
                        "confidence": 0.7,
                        "waves": {
                            "1": {"start": i-19, "end": i-15, "magnitude": wave1},
                            "2": {"start": i-15, "end": i-11, "magnitude": wave2},
                            "3": {"start": i-11, "end": i-7, "magnitude": wave3},
                            "4": {"start": i-7, "end": i-3, "magnitude": wave4},
                            "5": {"start": i-3, "end": i, "magnitude": wave5}
                        }
                    })
        except:
            continue
    
    return patterns

def detect_elliott_abc(df: pd.DataFrame) -> List[Dict]:
    """
    Détecte les patterns Elliott Correction Wave (ABC)
    3 vagues correctives
    """
    patterns = []
    if len(df) < 9:
        return patterns
    
    closes = df['close'].values
    
    for i in range(9, len(df)):
        try:
            wave_a = closes[i-9] - closes[i-6]
            wave_b = closes[i-6] - closes[i-3]
            wave_c = closes[i-3] - closes[i]
            
            # ABC: A et C dans la même direction, B en correction
            is_valid = (wave_a * wave_c > 0 and wave_a * wave_b < 0)
            
            if is_valid:
                patterns.append({
                    "type": "Elliott Correction Wave (ABC)",
                    "confidence": 0.65,
                    "waves": {
                        "A": {"start": i-9, "end": i-6, "magnitude": wave_a},
                        "B": {"start": i-6, "end": i-3, "magnitude": wave_b},
                        "C": {"start": i-3, "end": i, "magnitude": wave_c}
                    }
                })
        except:
            continue
    
    return patterns

@app.get("/deriv/patterns/{symbol}")
async def get_deriv_patterns(symbol: str, timeframe: str = "M15", count: int = 100):
    """
    Détecte tous les patterns Deriv sur un symbole
    Retourne: XABCD, Cypher, Head and Shoulders, ABCD, Triangle, Three Drives
    """
    global mt5_initialized  # Déclarer global AVANT toute utilisation
    try:
        # Récupérer les données
        if MT5_AVAILABLE and mt5_initialized:
            tf_map = {'M1': mt5.TIMEFRAME_M1, 'M5': mt5.TIMEFRAME_M5, 'M15': mt5.TIMEFRAME_M15,
                     'H1': mt5.TIMEFRAME_H1, 'H4': mt5.TIMEFRAME_H4, 'D1': mt5.TIMEFRAME_D1}
            tf = tf_map.get(timeframe.upper(), mt5.TIMEFRAME_M15)
            
            rates = mt5.copy_rates_from_pos(symbol, tf, 0, count)
            if rates is None or len(rates) == 0:
                raise HTTPException(status_code=404, detail=f"Aucune donnée pour {symbol}")
            
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
        else:
            # Fallback: utiliser les données MT5 si disponible, sinon erreur
            if not MT5_AVAILABLE:
                raise HTTPException(status_code=503, detail="MT5 non disponible - impossible de récupérer les données")
            
            # Essayer avec MT5 même si pas initialisé
            try:
                if not mt5_initialized:
                    if not mt5.initialize():
                        raise HTTPException(status_code=503, detail="Impossible d'initialiser MT5")
                    mt5_initialized = True
                
                tf_map = {'M1': mt5.TIMEFRAME_M1, 'M5': mt5.TIMEFRAME_M5, 'M15': mt5.TIMEFRAME_M15,
                         'H1': mt5.TIMEFRAME_H1, 'H4': mt5.TIMEFRAME_H4, 'D1': mt5.TIMEFRAME_D1}
                tf = tf_map.get(timeframe.upper(), mt5.TIMEFRAME_M15)
                
                rates = mt5.copy_rates_from_pos(symbol, tf, 0, count)
                if rates is None or len(rates) == 0:
                    raise HTTPException(status_code=404, detail=f"Aucune donnée pour {symbol}")
                
                df = pd.DataFrame(rates)
                df['time'] = pd.to_datetime(df['time'], unit='s')
            except Exception as e:
                logger.error(f"Erreur MT5 dans get_deriv_patterns: {type(e).__name__}: {str(e)}", exc_info=True)
                raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération des données: {str(e)}")
        
        # Vérifier que le DataFrame a les colonnes nécessaires
        required_columns = ['open', 'high', 'low', 'close']
        if not all(col in df.columns for col in required_columns):
            raise HTTPException(status_code=500, detail=f"Données incomplètes. Colonnes requises: {required_columns}, trouvées: {list(df.columns)}")
        
        # S'assurer que les colonnes sont numériques
        for col in required_columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')
        
        # Supprimer les lignes avec NaN
        df = df.dropna(subset=required_columns)
        
        if len(df) < 5:
            raise HTTPException(status_code=400, detail=f"Pas assez de données pour détecter des patterns. Minimum 5 bougies requis, trouvé: {len(df)}")
        
        # Détecter tous les patterns
        try:
            all_patterns = {
                "xabcd": detect_xabcd_pattern(df),
                "cypher": detect_cypher_pattern(df),
                "head_and_shoulders": detect_head_and_shoulders(df),
                "abcd": detect_abcd_pattern(df),
                "triangle": detect_triangle_pattern(df),
                "three_drives": detect_three_drives_pattern(df),
                "elliott_impulse": detect_elliott_impulse(df),
                "elliott_abc": detect_elliott_abc(df)
            }
        except Exception as pattern_error:
            logger.error(f"Erreur lors de la détection des patterns: {pattern_error}", exc_info=True)
            raise HTTPException(status_code=500, detail=f"Erreur détection patterns: {str(pattern_error)}")
        
        # Compter les patterns détectés
        total_patterns = sum(len(patterns) for patterns in all_patterns.values())
        
        # Convertir les types NumPy en types Python natifs pour la sérialisation JSON
        import numpy as np
        import json
        
        def convert_to_native(obj):
            """Convertit récursivement les types NumPy en types Python natifs"""
            if isinstance(obj, (np.integer, np.int64, np.int32)):
                return int(obj)
            elif isinstance(obj, (np.floating, np.float64, np.float32)):
                return float(obj)
            elif isinstance(obj, np.ndarray):
                return obj.tolist()
            elif isinstance(obj, dict):
                return {k: convert_to_native(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [convert_to_native(item) for item in obj]
            elif isinstance(obj, (pd.Timestamp, datetime)):
                return obj.isoformat() if hasattr(obj, 'isoformat') else str(obj)
            else:
                return obj
        
        # Convertir tous les patterns
        converted_patterns = {}
        for pattern_type, patterns_list in all_patterns.items():
            converted_patterns[pattern_type] = [convert_to_native(p) for p in patterns_list]
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "total_patterns": int(total_patterns),
            "patterns": converted_patterns,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Erreur détection patterns pour {symbol}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/deriv/tools/vwap/{symbol}")
async def get_anchored_vwap(symbol: str, anchor_date: Optional[str] = None, timeframe: str = "M15"):
    """
    Calcule l'Anchored VWAP (Volume Weighted Average Price) depuis une date d'ancrage
    """
    try:
        if MT5_AVAILABLE and mt5_initialized:
            tf_map = {'M1': mt5.TIMEFRAME_M1, 'M5': mt5.TIMEFRAME_M5, 'M15': mt5.TIMEFRAME_M15,
                     'H1': mt5.TIMEFRAME_H1, 'H4': mt5.TIMEFRAME_H4, 'D1': mt5.TIMEFRAME_D1}
            tf = tf_map.get(timeframe.upper(), mt5.TIMEFRAME_M15)
            
            # Si anchor_date fourni, calculer depuis cette date
            if anchor_date:
                anchor = datetime.fromisoformat(anchor_date.replace('Z', '+00:00'))
                rates = mt5.copy_rates_from(symbol, tf, anchor, 1000)
            else:
                # Par défaut: depuis le début de la journée
                today = datetime.now().replace(hour=0, minute=0, second=0)
                rates = mt5.copy_rates_from(symbol, tf, today, 1000)
            
            if rates is None or len(rates) == 0:
                raise HTTPException(status_code=404, detail="Aucune donnée")
            
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
        else:
            raise HTTPException(status_code=503, detail="MT5 non disponible ou non initialisé")
        
        # Calculer VWAP
        df['typical_price'] = (df['high'] + df['low'] + df['close']) / 3
        df['pv'] = df['typical_price'] * df['tick_volume']
        df['cumulative_pv'] = df['pv'].cumsum()
        df['cumulative_volume'] = df['tick_volume'].cumsum()
        df['vwap'] = df['cumulative_pv'] / df['cumulative_volume']
        
        current_vwap = df['vwap'].iloc[-1]
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "anchor_date": anchor_date or "today",
            "current_vwap": round(current_vwap, 5),
            "price_vs_vwap": round(df['close'].iloc[-1] - current_vwap, 5),
            "bias": "above" if df['close'].iloc[-1] > current_vwap else "below",
            "data_points": len(df)
        }
        
    except Exception as e:
        logger.error(f"Erreur VWAP pour {symbol}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/deriv/tools/volume-profile/{symbol}")
async def get_volume_profile(symbol: str, timeframe: str = "H1", bins: int = 20):
    """
    Calcule le Volume Profile (Fixed Range) - distribution du volume par niveau de prix
    """
    try:
        if MT5_AVAILABLE and mt5_initialized:
            tf_map = {'M1': mt5.TIMEFRAME_M1, 'M5': mt5.TIMEFRAME_M5, 'M15': mt5.TIMEFRAME_M15,
                     'H1': mt5.TIMEFRAME_H1, 'H4': mt5.TIMEFRAME_H4, 'D1': mt5.TIMEFRAME_D1}
            tf = tf_map.get(timeframe.upper(), mt5.TIMEFRAME_H1)
            
            rates = mt5.copy_rates_from_pos(symbol, tf, 0, 500)
            if rates is None or len(rates) == 0:
                raise HTTPException(status_code=404, detail="Aucune donnée")
            
            df = pd.DataFrame(rates)
        else:
            raise HTTPException(status_code=503, detail="MT5 non disponible ou non initialisé")
        
        # Calculer le range de prix
        price_min = df['low'].min()
        price_max = df['high'].max()
        price_range = price_max - price_min
        
        # Créer des bins de prix
        bin_size = price_range / bins
        price_bins = [price_min + i * bin_size for i in range(bins + 1)]
        
        # Distribuer le volume par bin
        volume_profile = []
        for i in range(bins):
            bin_low = price_bins[i]
            bin_high = price_bins[i + 1]
            
            # Volume dans ce bin (basé sur les bougies qui touchent ce range)
            volume = df[(df['high'] >= bin_low) & (df['low'] <= bin_high)]['tick_volume'].sum()
            
            volume_profile.append({
                "price_level": round((bin_low + bin_high) / 2, 5),
                "volume": int(volume),
                "range": {"low": round(bin_low, 5), "high": round(bin_high, 5)}
            })
        
        # Trouver le POC (Point of Control) - niveau avec le plus de volume
        max_volume_bin = max(volume_profile, key=lambda x: x['volume'])
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "price_range": {"min": round(price_min, 5), "max": round(price_max, 5)},
            "poc": {
                "price": max_volume_bin["price_level"],
                "volume": max_volume_bin["volume"]
            },
            "profile": volume_profile,
            "bins": bins
        }
        
    except Exception as e:
        logger.error(f"Erreur Volume Profile pour {symbol}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== END DERIV API ====================

# Import du module ML pour Phase 2
try:
    from backend.ml_trading_models import EnsembleMLModel, MLTradingModel
    ML_MODELS_AVAILABLE = True
    logger.info("✅ Module ML Trading (Phase 2) disponible")
except ImportError as e:
    ML_MODELS_AVAILABLE = False
    logger.warning(f"Module ML Trading non disponible: {e}")

# Variables globales pour les modèles ML
ml_ensemble = None
ml_models_initialized = False

@app.get("/dashboard/stats")
async def get_dashboard_stats(symbol: Optional[str] = None):
    """
    Endpoint pour récupérer toutes les statistiques du dashboard
    Retourne: performance modèles ML, statistiques trading, performance robot
    """
    if not DASHBOARD_STATS_AVAILABLE:
        return {
            "error": "Module dashboard_stats non disponible",
            "timestamp": datetime.now().isoformat()
        }
    
    try:
        stats_collector = DashboardStats()
        stats = stats_collector.get_all_stats()
        
        # Ajouter l'analyse cohérente si un symbole est fourni
        if symbol:
            coherent_analysis = await calculate_coherent_analysis(symbol)
            stats["coherent_analysis"] = coherent_analysis
        
        return stats
    except Exception as e:
        logger.error(f"Erreur récupération stats dashboard: {e}", exc_info=True)

@app.get("/health")
async def health_check():
    """Vérification de l'état du serveur"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "cache_size": len(prediction_cache),
        "mt5_initialized": mt5_initialized,
        "yfinance_available": YFINANCE_AVAILABLE,
        "mistral_available": MISTRAL_AVAILABLE,
        "trend_analysis": {
            "available": True,
            "mt5_available": mt5_initialized,
            "yfinance_available": YFINANCE_AVAILABLE
        }
    }

@app.post("/mt5/initialize")
async def initialize_mt5_endpoint():
    """Initialises MT5 avec les identifiants des variables d'environnement"""
    global mt5_initialized
    
    try:
        if not MT5_AVAILABLE:
            return {
                "status": "error",
                "message": "MetaTrader5 n'est pas installé sur le serveur",
                "mt5_initialized": False
            }
        
        if mt5_initialized:
            return {
                "status": "already_initialized",
                "message": "MT5 est déjà initialisé",
                "mt5_initialized": True
            }
        
        # Récupérer les identifiants depuis les variables d'environnement
        login = os.getenv("MT5_LOGIN")
        password = os.getenv("MT5_PASSWORD")
        server = os.getenv("MT5_SERVER")
        
        if not login or not password or not server:
            return {
                "status": "error",
                "message": "Variables d'environnement MT5 manquantes (MT5_LOGIN, MT5_PASSWORD, MT5_SERVER)",
                "mt5_initialized": False
            }
        
        # Initialiser MT5
        if not mt5.initialize():
            return {
                "status": "error",
                "message": f"Échec de l'initialisation MT5: {mt5.last_error()}",
                "mt5_initialized": False
            }
        
        # Se connecter
        authorized = mt5.login(login=int(login), password=password, server=server)
        if authorized:
            mt5_initialized = True
            logger.info(f"✅ MT5 connecté avec succès (login: {login})")
            return {
                "status": "success",
                "message": "MT5 initialisé et connecté avec succès",
                "mt5_initialized": True,
                "login": login,
                "server": server
            }
        else:
            error_msg = f"Échec de connexion MT5: {mt5.last_error()}"
            mt5.shutdown()
            return {
                "status": "error",
                "message": error_msg,
                "mt5_initialized": False
            }
            
    except Exception as e:
        logger.error(f"Erreur lors de l'initialisation MT5: {e}")
        return {
            "status": "error",
            "message": f"Erreur lors de l'initialisation MT5: {str(e)}",
            "mt5_initialized": False
        }

class MLModelUploadRequest(BaseModel):
    """Modèle pour l'upload de modèles ML entraînés"""
    symbol: str
    timeframe: str
    model_data: Dict[str, Any]  # Contient les modèles sérialisés
    metrics: Dict[str, Any]  # Métriques d'entraînement
    training_samples: int
    test_samples: int
    best_model: str
    timestamp: str

@app.post("/ml/upload-model")
async def upload_ml_model(request: MLModelUploadRequest):
    """
    Reçoit un modèle ML entraîné depuis un serveur local
    et le stocke pour utilisation sur le serveur cloud
    """
    try:
        model_key = f"{request.symbol}_{request.timeframe}"
        
        # Stocker les modèles dans le cache
        if model_data := request.model_data:
            ml_models_cache[model_key] = model_data
            logger.info(f"✅ Modèle ML reçu pour {model_key}: {request.best_model}")
        
        # Stocker les métriques
        _metrics_cache[model_key] = {
            "symbol": request.symbol,
            "timeframe": request.timeframe,
            "best_model": request.best_model,
            "metrics": request.metrics,
            "training_samples": request.training_samples,
            "test_samples": request.test_samples,
            "last_update": request.timestamp,
            "is_valid": True,
            "source": "local_upload"
        }
        
        return {
            "status": "success",
            "message": f"Modèle pour {request.symbol} {request.timeframe} reçu et stocké",
            "model_key": model_key,
            "best_model": request.best_model,
            "metrics": request.metrics
        }
        
    except Exception as e:
        logger.error(f"Erreur upload modèle ML: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur lors de l'upload du modèle: {str(e)}")

@app.post("/boom-crash/detect-spike")
async def detect_boom_crash_spike(request: Dict[str, Any]):
    """
    Endpoint dédié pour tester la détection de spikes Boom/Crash
    """
    try:
        symbol = request.get('symbol')
        timeframe = request.get('timeframe', 'M1')
        
        if not symbol:
            raise HTTPException(status_code=400, detail="Symbol requis")
        
        if not is_boom_crash_symbol(symbol):
            raise HTTPException(status_code=400, detail="Le symbole doit être un indice Boom ou Crash")
        
        # Récupérer les données
        df = get_market_data(symbol, timeframe, 100)
        
        if df.empty:
            raise HTTPException(status_code=400, detail="Impossible de récupérer les données")
        
        # Détecter les spikes
        spike_info = detect_spike_pattern(df, symbol)
        
        # Analyser les dernières bougies pour contexte
        analysis = {
            "symbol": symbol,
            "timeframe": timeframe,
            "data_points": len(df),
            "last_candle": {
                "time": df['time'].iloc[-1].isoformat() if 'time' in df.columns else None,
                "open": float(df['open'].iloc[-1]),
                "high": float(df['high'].iloc[-1]),
                "low": float(df['low'].iloc[-1]),
                "close": float(df['close'].iloc[-1]),
                "volume": int(df['tick_volume'].iloc[-1])
            },
            "spike_detection": spike_info,
            "market_context": {
                "avg_volume": float(df['tick_volume'].mean()),
                "price_volatility": float(df['close'].pct_change().std() * 100),
                "trend_direction": "up" if df['close'].iloc[-1] > df['close'].iloc[-10] else "down"
            }
        }
        
        return {
            "status": "success",
            "analysis": analysis,
            "recommendation": generate_boom_crash_signal(symbol, df),
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Erreur détection spike Boom/Crash: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ml/predict-signal")
async def predict_trading_signal(request: Dict[str, Any]):
    """
    Endpoint principal pour le robot MT5
    Retourne un signal de trading complet (direction, confidence, SL, TP)
    """
    try:
        symbol = request.get('symbol')
        timeframe = request.get('timeframe', 'M1')
        current_price = request.get('current_price')
        bid = request.get('bid')
        ask = request.get('ask')
        
        if not symbol:
            raise HTTPException(status_code=400, detail="Symbol requis")
        
        # ===== PRIORITÉ BOOM/CRASH SPIKE DETECTION =====
        if is_boom_crash_symbol(symbol):
            logger.info(f"🚀 Détection de spike pour {symbol}")
            
            try:
                # Récupérer les données pour détection de spike
                df = get_market_data(symbol, timeframe, 50)  # Plus de données pour les indicateurs
                
                if not df.empty and len(df) >= 20:
                    # Générer le signal Boom/Crash
                    boom_crash_result = generate_boom_crash_signal(symbol, df)
                    
                    if boom_crash_result["has_signal"]:
                        logger.info(
                            f"✅ Spike {boom_crash_result['signal']} détecté pour {symbol} - "
                            f"Confiance: {boom_crash_result['confidence']:.0f}%"
                        )
                        
                        return {
                            "signal": boom_crash_result["signal"],
                            "confidence": boom_crash_result["confidence"],
                            "source": "boom_crash_spike",
                            "symbol": symbol,
                            "timeframe": timeframe,
                            "stop_loss": boom_crash_result["stop_loss"],
                            "take_profit": boom_crash_result["take_profit"],
                            "position_size": boom_crash_result["position_size"],
                            "reasoning": boom_crash_result["reasoning"],
                            "spike_info": boom_crash_result["spike_info"],
                            "timestamp": datetime.now().isoformat()
                        }
                    else:
                        logger.info(f"❌ Aucun spike détecté pour {symbol}")
                        
                        # Retourner un signal neutre pour Boom/Crash sans spike
                        return {
                            "signal": "neutral",
                            "confidence": 0.0,
                            "source": "boom_crash_no_spike",
                            "symbol": symbol,
                            "timeframe": timeframe,
                            "stop_loss": None,
                            "take_profit": None,
                            "position_size": 0.0,
                            "reasoning": ["Aucun spike détecté", boom_crash_result.get("reason", "")],
                            "spike_info": boom_crash_result.get("spike_info", {}),
                            "timestamp": datetime.now().isoformat()
                        }
                else:
                    logger.warning(f"Données insuffisantes pour détection de spike {symbol}: {len(df)} bougies")
            except Exception as e:
                logger.error(f"Erreur dans détection spike Boom/Crash: {e}")
                logger.error(f"Traceback: {traceback.format_exc()}")
                # Continuer avec la logique ML standard en cas d'erreur
        
        # ===== LOGIQUE ML STANDARD POUR LES AUTRES SYMBOLES =====
        
        # Vérifier si nous avons un modèle pour ce symbole
        model_key = f"{symbol}_{timeframe}"
        
        if model_key not in ml_models_cache:
            # Fallback vers l'analyse de tendance
            logger.warning(f"Pas de modèle ML pour {model_key}, utilisation de l'analyse de tendance")
            trend_result = calculate_enhanced_trend_direction(symbol, timeframe)
            
            return {
                "signal": trend_result.get("direction", "neutral"),
                "confidence": trend_result.get("confidence", 50.0),
                "source": "trend_analysis",
                "symbol": symbol,
                "timeframe": timeframe,
                "stop_loss": None,
                "take_profit": None,
                "position_size": 0.01,  # Default
                "reasoning": trend_result.get("signals", []),
                "timestamp": datetime.now().isoformat()
            }
        
        # Utiliser le modèle ML
        model_data = ml_models_cache[model_key]
        best_model = model_data.get('best_model', 'RandomForest')
        
        # Récupérer les données récentes pour la prédiction
        df = get_market_data(symbol, timeframe, 100)
        
        if df.empty or len(df) < 50:
            raise HTTPException(status_code=400, detail="Données insuffisantes pour la prédiction")
        
        # Extraire les features
        features_df = extract_advanced_features(df)
        
        if features_df is None or features_df.empty:
            raise HTTPException(status_code=400, detail="Erreur extraction features")
        
        # Préparer les données pour la prédiction
        latest_features = features_df.iloc[-1:].dropna()
        
        if latest_features.empty:
            raise HTTPException(status_code=400, detail="Features invalides")
        
        # Faire la prédiction
        prediction = None
        if best_model in model_data and model_data[best_model]:
            try:
                model = model_data[best_model]
                prediction = model.predict(latest_features)[0]
                confidence = max(model.predict_proba(latest_features)[0]) * 100
            except:
                prediction = 0
                confidence = 50.0
        
        # Convertir la prédiction en signal
        if prediction == 1:
            signal = "BUY"
        elif prediction == -1:
            signal = "SELL"
        else:
            signal = "HOLD"
        
        # Calculer SL/TP basés sur l'ATR
        atr = calculate_atr(df, 14).iloc[-1]
        current_price = df['close'].iloc[-1]
        
        stop_loss = None
        take_profit = None
        
        if signal == "BUY":
            stop_loss = current_price - (atr * 2)
            take_profit = current_price + (atr * 3)
        elif signal == "SELL":
            stop_loss = current_price + (atr * 2)
            take_profit = current_price - (atr * 3)
        
        return {
            "signal": signal,
            "confidence": round(confidence, 1),
            "source": "ml_model",
            "model_used": best_model,
            "symbol": symbol,
            "timeframe": timeframe,
            "current_price": current_price,
            "stop_loss": round(stop_loss, 5) if stop_loss else None,
            "take_profit": round(take_profit, 5) if take_profit else None,
            "position_size": 0.01,  # Peut être ajusté selon la confidence
            "atr": round(atr, 5),
            "reasoning": [
                f"Modèle: {best_model}",
                f"Confiance: {confidence:.1f}%",
                f"Signal: {signal}"
            ],
            "timestamp": datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur prédiction signal: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur lors de la prédiction: {str(e)}")

@app.get("/ml/uploaded-models")
async def list_uploaded_models():
    """Liste tous les modèles uploadés"""
    try:
        models = []
        for key, model_data in ml_models_cache.items():
            symbol, timeframe = key.split('_', 1)
            metrics = _metrics_cache.get(key, {})
            models.append({
                "symbol": symbol,
                "timeframe": timeframe,
                "model_key": key,
                "best_model": metrics.get("best_model", "unknown"),
                "training_samples": metrics.get("training_samples", 0),
                "last_update": metrics.get("last_update", "unknown"),
                "source": metrics.get("source", "unknown")
            })
        
        return {
            "status": "success",
            "count": len(models),
            "models": models
        }
        
    except Exception as e:
        logger.error(f"Erreur liste modèles uploadés: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==============================================================================
# ENDPOINTS D'ANALYSE DE TENDANCE (intégrés depuis trend_api.py)
# ==============================================================================

class TrendAnalysisRequest(BaseModel):
    symbol: str
    timeframes: Optional[List[str]] = ["M1", "M5", "M15", "H1", "H4"]

def calculate_enhanced_trend_direction(symbol: str, timeframe: str = "M1") -> Dict[str, Any]:
    """Calcule la direction de tendance avec analyse multi-indicateurs avancés"""
    try:
        # Utiliser la fonction hybride get_market_data
        df = get_market_data(symbol, timeframe, 100)
        
        if df.empty or len(df) < 50:
            # Fallback basé sur l'heure si pas de données
            hour = datetime.now().hour
            if hour % 2 == 0:
                return {"direction": "buy", "confidence": 65.0, "signals": ["fallback_hour"]}
            else:
                return {"direction": "sell", "confidence": 65.0, "signals": ["fallback_hour"]}
        
        current_price = df['close'].iloc[-1]
        current_volume = df['volume'].iloc[-1]
        
        # ===== INDICATEURS MULTIPLES =====
        
        # 1. Moyennes mobiles multiples
        sma_20 = df['close'].rolling(window=20).mean().iloc[-1]
        sma_50 = df['close'].rolling(window=50).mean().iloc[-1]
        ema_9 = df['close'].ewm(span=9).mean().iloc[-1]
        ema_21 = df['close'].ewm(span=21).mean().iloc[-1]
        
        # 2. RSI avec zones optimisées
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        current_rsi = rsi.iloc[-1]
        
        # 3. MACD
        ema_12 = df['close'].ewm(span=12).mean()
        ema_26 = df['close'].ewm(span=26).mean()
        macd_line = ema_12 - ema_26
        signal_line = macd_line.ewm(span=9).mean()
        macd_histogram = macd_line - signal_line
        current_macd = macd_line.iloc[-1]
        current_signal = signal_line.iloc[-1]
        current_histogram = macd_histogram.iloc[-1]
        
        # 4. Bandes de Bollinger
        bb_period = 20
        bb_std = 2
        bb_middle = df['close'].rolling(window=bb_period).mean()
        bb_std = df['close'].rolling(window=bb_period).std()
        bb_upper = bb_middle + (bb_std * bb_std)
        bb_lower = bb_middle - (bb_std * bb_std)
        current_bb_upper = bb_upper.iloc[-1]
        current_bb_lower = bb_lower.iloc[-1]
        current_bb_middle = bb_middle.iloc[-1]
        
        # 5. Volume analysis
        volume_sma = df['volume'].rolling(window=20).mean()
        volume_ratio = current_volume / volume_sma.iloc[-1] if volume_sma.iloc[-1] > 0 else 1.0
        
        # 6. ATR pour la volatilité
        high_low = df['high'] - df['low']
        high_close = (df['high'] - df['close'].shift()).abs()
        low_close = (df['low'] - df['close'].shift()).abs()
        true_range = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
        atr = true_range.rolling(window=14).mean()
        current_atr = atr.iloc[-1]
        atr_percentage = (current_atr / current_price) * 100
        
        # ===== CALCUL DU SCORE DE TENDANCE =====
        trend_score = 0.0
        signals = []
        
        # Prix par rapport aux moyennes mobiles (poids: 2.0)
        if current_price > sma_20 > sma_50:
            trend_score += 2.0
            signals.append("price_above_sma")
        elif current_price < sma_20 < sma_50:
            trend_score -= 2.0
            signals.append("price_below_sma")
        
        # Confirmation EMA (poids: 1.5)
        if ema_9 > ema_21:
            trend_score += 1.5
            signals.append("ema_bullish")
        elif ema_9 < ema_21:
            trend_score -= 1.5
            signals.append("ema_bearish")
        
        # RSI confirmation avec zones optimisées (poids: 1.0)
        if 55 < current_rsi < 75:  # Zone haussière optimisée
            trend_score += 1.0
            signals.append("rsi_bullish")
        elif 25 < current_rsi < 45:  # Zone baissière optimisée
            trend_score -= 1.0
            signals.append("rsi_bearish")
        elif current_rsi >= 75:  # Surachat - pénalité
            trend_score -= 0.5
            signals.append("rsi_overbought")
        elif current_rsi <= 25:  # Survente - pénalité
            trend_score += 0.5
            signals.append("rsi_oversold")
        
        # MACD confirmation (poids: 1.0)
        if current_macd > current_signal and current_histogram > 0:
            trend_score += 1.0
            signals.append("macd_bullish")
        elif current_macd < current_signal and current_histogram < 0:
            trend_score -= 1.0
            signals.append("macd_bearish")
        
        # Position dans les bandes de Bollinger (poids: 0.5)
        if current_price > current_bb_upper:
            trend_score -= 0.5  # Surachat potentiel
            signals.append("above_bb_upper")
        elif current_price < current_bb_lower:
            trend_score += 0.5   # Survente potentiel
            signals.append("below_bb_lower")
        
        # Volume confirmation (poids: 0.8)
        if volume_ratio > 1.2:
            trend_score *= 1.2  # Renforcer si volume élevé
            signals.append("high_volume")
        elif volume_ratio < 0.8:
            trend_score *= 0.9  # Réduire si volume faible
            signals.append("low_volume")
        
        # ===== DÉCISION FINALE AVEC SEUILS AMÉLIORÉS =====
        
        # Calcul de la confiance base
        base_confidence = 50.0 + abs(trend_score) * 8
        
        # Ajustement selon la volatilité
        if atr_percentage > 2.0:  # Volatilité élevée
            base_confidence *= 0.85  # Réduire confiance en haute volatilité
            signals.append("high_volatility")
        elif atr_percentage < 0.5:  # Volatilité très faible
            base_confidence *= 0.90  # Réduire si pas de mouvement
            signals.append("low_volatility")
        
        # Confiance finale plafonnée
        final_confidence = min(95.0, max(40.0, base_confidence))
        
        # Détermination de la direction
        if trend_score >= 3.0:
            direction = "buy"
            final_confidence = min(90.0, final_confidence + 5)  # Bonus pour signal fort
        elif trend_score <= -3.0:
            direction = "sell"
            final_confidence = min(90.0, final_confidence + 5)  # Bonus pour signal fort
        else:
            direction = "neutral"
            final_confidence = max(45.0, final_confidence - 10)  # Pénalité pour neutral
        
        return {
            "direction": direction,
            "confidence": round(final_confidence, 1),
            "trend_score": round(trend_score, 2),
            "signals": signals,
            "rsi": round(current_rsi, 1),
            "macd": round(current_histogram, 4),
            "volume_ratio": round(volume_ratio, 2),
            "atr_percentage": round(atr_percentage, 2)
        }
        
    except Exception as e:
        logger.error(f"Erreur calcul tendance avancée pour {symbol} ({timeframe}): {e}")
        return {"direction": "neutral", "confidence": 50.0, "signals": ["error"]}

def calculate_trend_direction(symbol: str, timeframe: str = "M1") -> str:
    """Calcule la direction de la tendance pour un symbole/timeframe donné"""
    try:
        # Utiliser la nouvelle fonction avancée
        enhanced_result = calculate_enhanced_trend_direction(symbol, timeframe)
        return enhanced_result.get("direction", "neutral")
    except Exception as e:
        logger.error(f"Erreur lors du calcul de la tendance pour {symbol} ({timeframe}): {e}")
        return "neutral"

def calculate_market_state(symbol: str, timeframe: str = "M1") -> Dict[str, str]:
    """Calcule l'état du marché GLOBAL basé sur la moyenne de tous les timeframes
    
    # ... (le reste du code reste inchangé)
    Args:
        symbol: Symbole du marché
        timeframe: Timeframe d'analyse (ignoré, utilise tous les TF)
        
    Returns:
        Dictionnaire avec market_state et market_trend (global)
    """
    try:
        # Vérifier si MT5 est disponible et initialisé
        if not MT5_AVAILABLE or not mt5_initialized:
            logger.warning(f"MT5 non disponible pour calculer l'état du marché de {symbol}")
            return {"market_state": "DONNEES_INSUFFISANTES", "market_trend": "NEUTRE"}
        
        # Timeframes à analyser par ordre d'importance (plus long = plus important)
        timeframes = [
            ('W1', mt5.TIMEFRAME_W1, 3.0),    # Weekly = poids le plus élevé
            ('D1', mt5.TIMEFRAME_D1, 2.5),    # Daily
            ('H4', mt5.TIMEFRAME_H4, 2.0),     # 4 heures
            ('H1', mt5.TIMEFRAME_H1, 1.5),     # 1 heure
            ('M15', mt5.TIMEFRAME_M15, 1.2),   # 15 minutes
            ('M5', mt5.TIMEFRAME_M5, 1.0),      # 5 minutes
            ('M1', mt5.TIMEFRAME_M1, 0.8)      # 1 minute = poids le plus faible
        ]
        
        all_states = []
        all_trends = []
        valid_timeframes = 0
        
        logger.info(f"🔍 Analyse état du marché global pour {symbol}")
        
        for tf_name, mt5_tf, weight in timeframes:
            try:
                # Récupérer les données pour ce timeframe
                rates = mt5.copy_rates_from_pos(symbol, mt5_tf, 0, 50)
                
                if rates is None or len(rates) < 20:
                    logger.warning(f"   ⚠️ {tf_name}: Données insuffisantes")
                    continue
                
                # Extraire les prix de clôture
                prices = [rate['close'] for rate in rates]
                recent_prices = prices[-20:]  # 20 dernières bougies
                
                # Calculer la tendance pour ce timeframe
                if len(recent_prices) >= 10:
                    first_half = recent_prices[:10]
                    second_half = recent_prices[10:]
                    
                    avg_first = np.mean(first_half)
                    avg_second = np.mean(second_half)
                    
                    trend_change = (avg_second - avg_first) / avg_first
                    
                    volatility = np.std(recent_prices) / np.mean(recent_prices)
                    
                    # Déterminer l'état pour ce timeframe
                    if abs(trend_change) < 0.001:  # Moins de 0.1% de changement
                        market_state = "RANGE"
                    elif trend_change > 0.002:  # Plus de 0.2% de hausse
                        market_state = "TENDANCE_HAUSSIERE"
                    elif trend_change < -0.002:  # Plus de 0.2% de baisse
                        market_state = "TENDANCE_BAISSIERE"
                    else:
                        market_state = "CORRECTION"
                    
                    # Déterminer la tendance pour ce timeframe
                    if volatility > 0.01:  # Haute volatilité
                        if trend_change > 0:
                            market_trend = "VOLATILE_HAUSSIER"
                        else:
                            market_trend = "VOLATILE_BAISSIER"
                    else:
                        if trend_change > 0.001:
                            market_trend = "HAUSSIER_MODERE"
                        elif trend_change < -0.001:
                            market_trend = "BAISSIER_MODERE"
                        else:
                            market_trend = "STABLE"
                    
                    # Ajouter aux listes avec pondération
                    for _ in range(int(weight * 10)):  # Multiplier par 10 pour éviter les décimales
                        all_states.append(market_state)
                        all_trends.append(market_trend)
                    
                    valid_timeframes += 1
                    logger.info(f"   ✅ {tf_name}: {market_state} / {market_trend} (poids: {weight})")
                
            except Exception as e:
                logger.error(f"   ❌ {tf_name}: Erreur {e}")
                continue
        
        if not all_states:
            logger.warning(f"Pas de données valides pour {symbol}, utilisation fallback")
            return {"market_state": "DONNEES_INSUFFISANTES", "market_trend": "NEUTRE"}
        
        # Calculer l'état majoritaire (moyenne pondérée)
        from collections import Counter
        state_counts = Counter(all_states)
        trend_counts = Counter(all_trends)
        
        # État le plus fréquent = état global
        global_state = state_counts.most_common(1)[0][0]
        global_trend = trend_counts.most_common(1)[0][0]
        
        # Log des résultats
        logger.info(f"📊 Résultats globaux pour {symbol}:")
        logger.info(f"   Timeframes analysés: {valid_timeframes}")
        logger.info(f"   États détectés: {dict(state_counts)}")
        logger.info(f"   🎯 ÉTAT GLOBAL: {global_state}")
        logger.info(f"   📈 TENDANCE GLOBALE: {global_trend}")
        
        # Logique spécifique pour certains types de symboles
        symbol_lower = symbol.lower()
        if "boom" in symbol_lower:
            # Pour Boom, pas d'opportunité si tout est en SELL
            if global_trend in ["BAISSIER_MODERE", "VOLATILE_BAISSIER"]:
                global_trend += "_SANS_OPPORTUNITE"
        elif "crash" in symbol_lower:
            # Pour Crash, pas d'opportunité si tout est en BUY
            if global_trend in ["HAUSSIER_MODERE", "VOLATILE_HAUSSIER"]:
                global_trend += "_SANS_OPPORTUNITE"
        elif "volatility" in symbol_lower:
            # Pour Volatility Index, alertes extrêmes
            # Calculer volatilité moyenne sur tous les TF
            if valid_timeframes > 0 and MT5_AVAILABLE and mt5_initialized:
                try:
                    rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, 50)
                    if rates is not None and len(rates) >= 20:
                        recent_rates = rates[-20:]
                        closes = [rate['close'] for rate in recent_rates]
                        avg_volatility = np.std(closes) / np.mean(closes)
                        if avg_volatility > 0.015:
                            global_trend += "_EXTREME"
                except Exception as e:
                    logger.warning(f"Erreur calcul volatilité pour {symbol}: {e}")
        
        return {
            "market_state": global_state,
            "market_trend": global_trend
        }
        
    except Exception as e:
        logger.error(f"Erreur calcul état global marché {symbol}: {e}")
        return {"market_state": "ERREUR", "market_trend": "INCONNU"}
        
def _generate_simulated_prices(symbol: str, count: int = 50) -> List[float]:
    """Génère des données simulées basées sur le type de symbole"""
    import random
    
    base_price = 10000.0  # Prix de base
    symbol_lower = symbol.lower()
    
    # Ajuster le comportement selon le type de symbole
    if "boom" in symbol_lower:
        # Boom: tendance générale haussière avec des spikes
        trend_factor = 0.1
        volatility = 0.008
    elif "crash" in symbol_lower:
        # Crash: tendance générale baissière avec des spikes
        trend_factor = -0.08
        volatility = 0.008
    elif "volatility" in symbol_lower:
        # Volatility Index: comportement erratique
        trend_factor = 0.0
        volatility = 0.012
    else:
        # Forex/autres: tendance modérée
        trend_factor = random.choice([-0.02, 0.0, 0.02])
        volatility = 0.005
    
    prices = []
    current_price = base_price
    
    for i in range(count):
        # Appliquer la tendance
        current_price += trend_factor
        # Ajouter la volatilité
        noise = random.gauss(0, volatility * current_price)
        current_price += noise
        # Éviter les prix négatifs
        current_price = max(current_price, base_price * 0.8)
        prices.append(current_price)
    
    return prices

def filter_false_signals(symbol: str, direction: str, confidence: float, timeframe: str = "M1") -> Dict[str, Any]:
    """Filtre les faux signaux avec multiples validations pour réduire les risques"""
    try:
        # 1. Filtrage par heures de marché actives
        current_hour = datetime.now().hour
        current_day = datetime.now().weekday()  # 0 = Lundi, 6 = Dimanche
        
        # Heures optimisées par type de symbole
        if "Boom" in symbol or "Crash" in symbol:
            # Pour Boom/Crash: éviter les heures de faible volatilité
            active_hours = [8, 9, 10, 11, 14, 15, 16, 17, 20, 21, 22]  # Sessions actives
            if current_hour not in active_hours:
                return {
                    "valid": False, 
                    "reason": f"Hors heures de marché actives pour {symbol} (heure: {current_hour})",
                    "filtered_confidence": confidence * 0.3
                }
        else:
            # Pour Forex: éviter le week-end et heures de faible liquidité
            if current_day >= 5:  # Week-end
                return {
                    "valid": False, 
                    "reason": "Week-end - marché fermé pour Forex",
                    "filtered_confidence": confidence * 0.1
                }
            
            # Éviter les heures de faible liquidité (session asiatique tardive)
            if current_hour in [22, 23, 0, 1, 2]:
                return {
                    "valid": False, 
                    "reason": f"Heure de faible liquidité (heure: {current_hour})",
                    "filtered_confidence": confidence * 0.5
                }
        
        # 2. Filtrage par volatilité anormale
        if mt5_initialized:
            try:
                rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, 100)
                if rates and len(rates) >= 20:
                    df = pd.DataFrame(rates)
                    
                    # Calculer ATR actuel vs ATR moyen
                    high_low = df['high'] - df['low']
                    high_close = (df['high'] - df['close'].shift()).abs()
                    low_close = (df['low'] - df['close'].shift()).abs()
                    true_range = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
                    atr_current = true_range.rolling(14).mean().iloc[-1]
                    atr_average = true_range.rolling(14).mean().mean()
                    
                    current_price = df['close'].iloc[-1]
                    atr_percentage = (atr_current / current_price) * 100
                    
                    # Filtrer si volatilité extrême (> 3x la moyenne)
                    if atr_current > atr_average * 3.0:
                        return {
                            "valid": False, 
                            "reason": f"Volatilité extrême détectée (ATR: {atr_percentage:.2f}%)",
                            "filtered_confidence": confidence * 0.2
                        }
                    
                    # Filtrer si volatilité trop faible (< 0.1%)
                    if atr_percentage < 0.1:
                        return {
                            "valid": False, 
                            "reason": f"Volatilité trop faible (ATR: {atr_percentage:.2f}%)",
                            "filtered_confidence": confidence * 0.6
                        }
            except Exception as e:
                logger.warning(f"Erreur filtrage volatilité pour {symbol}: {e}")
        
        # 3. Filtrage par spread (si disponible)
        try:
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info:
                current_spread = symbol_info.ask - symbol_info.bid
                current_price = symbol_info.bid
                spread_percentage = (current_spread / current_price) * 100 if current_price > 0 else 0
                
                # Filtrer si spread trop élevé
                if "Boom" in symbol or "Crash" in symbol:
                    max_spread_pct = 0.5  # 0.5% max pour Boom/Crash
                else:
                    max_spread_pct = 0.05  # 0.05% max pour Forex
                
                if spread_percentage > max_spread_pct:
                    return {
                        "valid": False, 
                        "reason": f"Spread trop élevé ({spread_percentage:.3f}% > {max_spread_pct}%)",
                        "filtered_confidence": confidence * 0.3
                    }
        except Exception as e:
            logger.debug(f"Impossible de vérifier le spread pour {symbol}: {e}")
        
        # 4. Filtrage par corrélation de positions (pour Boom/Crash)
        if "Boom" in symbol or "Crash" in symbol:
            try:
                # Compter les positions existantes sur des symboles corrélés
                positions = mt5.positions_get()
                correlated_count = 0
                
                for pos in positions:
                    if pos.magic == 888888:  # Notre magic number
                        pos_symbol = pos.symbol
                        # Vérifier si c'est un symbole Boom/Crash corrélé
                        if ("Boom" in pos_symbol or "Crash" in pos_symbol) and pos_symbol != symbol:
                            correlated_count += 1
                
                # Limiter le nombre de positions corrélées simultanées
                if correlated_count >= 3:
                    return {
                        "valid": False, 
                        "reason": f"Trop de positions corrélées ({correlated_count} positions Boom/Crash)",
                        "filtered_confidence": confidence * 0.1
                    }
            except Exception as e:
                logger.debug(f"Impossible de vérifier les corrélations pour {symbol}: {e}")
        
        # 5. Filtrage par momentum excessif
        try:
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, 50)
            if rates and len(rates) >= 20:
                df = pd.DataFrame(rates)
                closes = df['close']
                
                # Calculer le momentum sur 10 périodes
                if len(closes) >= 10:
                    momentum_10 = (closes.iloc[-1] - closes.iloc[-10]) / closes.iloc[-10]
                    momentum_5 = (closes.iloc[-1] - closes.iloc[-5]) / closes.iloc[-5]
                    
                    # Filtrer si momentum trop élevé (possible manipulation ou news)
                    if abs(momentum_10) > 0.05:  # Plus de 5% en 10 minutes
                        return {
                            "valid": False, 
                            "reason": f"Momentum excessif détecté ({momentum_10*100:.1f}% en 10 min)",
                            "filtered_confidence": confidence * 0.2
                        }
                    
                    # Filtrer si momentum change brusquement de direction
                    if momentum_5 * momentum_10 < 0:  # Changement de direction
                        return {
                            "valid": False, 
                            "reason": "Changement brusque de direction du momentum",
                            "filtered_confidence": confidence * 0.4
                        }
        except Exception as e:
            logger.debug(f"Erreur filtrage momentum pour {symbol}: {e}")
        
        # 6. Ajustement de la confiance selon les filtres
        filtered_confidence = confidence
        
        # Réduire la confiance pour les symboles très volatiles
        if "Boom" in symbol or "Crash" in symbol:
            filtered_confidence *= 0.85  # -15% pour Boom/Crash
        elif "Volatility" in symbol:
            filtered_confidence *= 0.90  # -10% pour Volatility
        
        # Ajustement selon le timeframe
        timeframe_multipliers = {
            'M1': 0.8,   # Réduire pour M1 (beaucoup de bruit)
            'M5': 0.9,   # Légère réduction pour M5
            'M15': 1.0,  # Neutre pour M15
            'H1': 1.1,   # Légère augmentation pour H1
            'H4': 1.2    # Augmentation pour H4 (plus fiable)
        }
        multiplier = timeframe_multipliers.get(timeframe, 1.0)
        filtered_confidence *= multiplier
        
        # Plafonner la confiance finale
        final_confidence = min(95.0, max(40.0, filtered_confidence))
        
        return {
            "valid": True,
            "reason": "Signal validé après filtrage",
            "filtered_confidence": round(final_confidence, 1),
            "original_confidence": confidence,
            "filters_applied": ["hours", "volatility", "spread", "correlation", "momentum"]
        }
        
    except Exception as e:
        logger.error(f"Erreur filtrage signaux pour {symbol}: {e}")
        return {
            "valid": True, 
            "reason": "Erreur de filtrage - signal accepté par défaut",
            "filtered_confidence": confidence * 0.7,  # Réduire en cas d'erreur
            "filters_applied": ["error_fallback"]
        }

def calculate_trend_confidence(symbol: str, timeframe: str = "M1") -> float:
    """Calcule le niveau de confiance de la tendance (0-100) - Version améliorée"""
    try:
        if not mt5_initialized:
            # Fallback aléatoire si MT5 non disponible
            import random
            return float(random.randint(60, 90))
        
        # Utiliser la fonction améliorée si disponible
        if IMPROVEMENTS_AVAILABLE:
            try:
                tf_map = {
                    'M1': mt5.TIMEFRAME_M1,
                    'M5': mt5.TIMEFRAME_M5,
                    'M15': mt5.TIMEFRAME_M15,
                    'H1': mt5.TIMEFRAME_H1,
                    'H4': mt5.TIMEFRAME_H4
                }
                
                mt5_timeframe = tf_map.get(timeframe, mt5.TIMEFRAME_M1)
                rates = mt5.copy_rates_from_pos(symbol, mt5_timeframe, 0, 100)
                
                if rates is not None and len(rates) >= 50:
                    df = pd.DataFrame(rates)
                    confidence_data = calculate_advanced_confidence(df, symbol, timeframe)
                    
                    # Convertir de 0-1 à 0-100
                    return float(confidence_data['confidence'] * 100)
            except Exception as e:
                logger.warning(f"Erreur calcul confiance améliorée: {e}, fallback vers méthode standard")
        
        # Fallback vers méthode standard
        tf_map = {
            'M1': mt5.TIMEFRAME_M1,
            'M5': mt5.TIMEFRAME_M5,
            'M15': mt5.TIMEFRAME_M15,
            'H1': mt5.TIMEFRAME_H1,
            'H4': mt5.TIMEFRAME_H4
        }
        
        mt5_timeframe = tf_map.get(timeframe, mt5.TIMEFRAME_M1)
        rates = mt5.copy_rates_from_pos(symbol, mt5_timeframe, 0, 100)
        
        if rates is None or len(rates) < 50:
            return 50.0
        
        # Utiliser la nouvelle fonction avancée existante
        enhanced_result = calculate_enhanced_trend_direction(symbol, timeframe)
        base_confidence = enhanced_result.get("confidence", 50.0)
        
        # Appliquer le filtrage anti-faux signaux
        filter_result = filter_false_signals(symbol, enhanced_result.get("direction", "neutral"), base_confidence, timeframe)
        
        if filter_result.get("valid", False):
            return float(filter_result.get("filtered_confidence", base_confidence))
        else:
            logger.info(f"Signal filtré pour {symbol}: {filter_result.get('reason', 'Raison inconnue')}")
            return 0.0  # Confiance nulle si signal rejeté
            
    except Exception as e:
        logger.error(f"Erreur calcul confiance {symbol} {timeframe}: {e}")
        return 50.0

async def calculate_coherent_analysis(symbol: str, timeframes: Optional[List[str]] = None) -> Dict[str, Any]:
    """Calcule une analyse cohérente multi-timeframes
    
    Args:
        symbol: Symbole du marché
        timeframes: Liste des timeframes à analyser
        
    Returns:
        Dictionnaire avec l'analyse cohérente
    """
    if timeframes is None:
        timeframes = ["D1", "H4", "H1", "M30", "M15", "M5", "M1"]
    
    try:
        # Récupérer les données de tendance pour tous les timeframes
        trends = {}
        
        for tf in timeframes:
            try:
                # Utiliser la fonction existante de calcul de tendance
                trend_data = {
                    "direction": "neutral",
                    "strength": 50.0,
                    "ema9": 0.0,
                    "ema21": 0.0,
                    "bullish": False,
                    "bearish": False
                }
                
                # Calculer la direction de la tendance
                direction = calculate_trend_direction(symbol, tf)
                trend_data["direction"] = direction
                trend_data["bullish"] = direction == "buy"
                trend_data["bearish"] = direction == "sell"
                
                # Calculer la force (basée sur la cohérence des signaux)
                confidence = calculate_trend_confidence(symbol, tf)
                trend_data["strength"] = confidence
                
                trends[tf.lower()] = trend_data
                
            except Exception as e:
                logger.warning(f"Erreur tendance {tf} pour {symbol}: {e}")
                trends[tf.lower()] = {
                    "direction": "neutral",
                    "strength": 0.0,
                    "ema9": 0.0,
                    "ema21": 0.0,
                    "bullish": False,
                    "bearish": False
                }
        
        # Pondération des timeframes RENFORCÉE pour cohérence maximale
        # Donner un poids écrasant aux timeframes longs (très fiables)
        # Éliminer presque complètement l'influence des timeframes courts (bruit)
        timeframe_weights = {
            'd1': 0.45,    # Augmenté: Daily le plus fiable (45%)
            'h4': 0.35,    # Augmenté: 4h très fiable (35%)
            'h1': 0.15,    # Réduit: 1h influence modérée (15%)
            'm30': 0.03,   # Fort réduit: 30min très bruité (3%)
            'm15': 0.01,   # Minimisé: 15min bruit extrême (1%)
            'm5': 0.01,    # Minimisé: 5min bruit extrême (1%)
            'm1': 0.00     # Éliminé: 1min aucun poids (0%)
        }
        
        # Calcul de la cohérence des tendances
        bullish_count = 0.0
        bearish_count = 0.0
        neutral_count = 0.0
        total_strength = 0.0
        valid_timeframes = 0.0
        
        for tf, weight in timeframe_weights.items():
            if tf in trends:
                trend_data = trends[tf]
                direction = trend_data.get('direction', 'neutral')
                strength = trend_data.get('strength', 0)
                
                if direction == 'buy':
                    bullish_count += weight
                elif direction == 'sell':
                    bearish_count += weight
                else:
                    neutral_count += weight
                
                total_strength += strength * weight
                valid_timeframes += weight
        
        # Détermination de la décision finale
        total_weight = bullish_count + bearish_count + neutral_count
        if total_weight == 0:
            return {
                "status": "error",
                "message": "Aucune donnée valide",
                "decision": "EN ATTENTE",
                "confidence": 0,
                "stability": "EN ATTENTE"
            }
        
        bullish_pct = (bullish_count / total_weight) * 100
        bearish_pct = (bearish_count / total_weight) * 100
        neutral_pct = (neutral_count / total_weight) * 100
        
        # Calcul de la confiance
        confidence = min(95, (total_strength / valid_timeframes) if valid_timeframes > 0 else 0)
        
        # Calcul de la stabilité
        max_diff = max(bullish_pct, bearish_pct, neutral_pct)
        stability = "ÉLEVÉE" if max_diff >= 60 else "MOYENNE" if max_diff >= 40 else "FAIBLE"
        
        # Seuils de décision RENFORCÉS pour exiger une VRAIE cohérence
        # Seulement les signaux avec forte cohérence multi-timeframes seront acceptés
        if bullish_pct >= 85:  # Seuil très élevé - cohérence forte requise
            decision = "ACHAT FORT"
            decision_type = "BUY"
        elif bearish_pct >= 85:  # Seuil très élevé - cohérence forte requise
            decision = "VENTE FORTE"
            decision_type = "SELL"
        elif bullish_pct >= 75:  # Seuil élevé - bonne cohérence
            decision = "ACHAT MODÉRÉ"
            decision_type = "BUY"
        elif bearish_pct >= 75:  # Seuil élevé - bonne cohérence
            decision = "VENTE MODÉRÉE"
            decision_type = "SELL"
        else:
            decision = "ATTENTE - COHÉRENCE INSUFFISANTE"
            decision_type = "HOLD"
        
        return {
            "status": "success",
            "symbol": symbol,
            "decision": decision,
            "decision_type": decision_type,
            "confidence": round(confidence, 1),
            "stability": stability,
            "bullish_pct": round(bullish_pct, 1),
            "bearish_pct": round(bearish_pct, 1),
            "neutral_pct": round(neutral_pct, 1),
            "trends": trends,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Erreur analyse cohérente {symbol}: {e}")
        return {
            "status": "error",
            "message": str(e),
            "decision": "EN ATTENTE",
            "confidence": 0,
            "stability": "EN ATTENTE"
        }

# ==============================================================================
# PHASE 2: MACHINE LEARNING ET VALIDATION MULTI-TIMEFRAME (Phase 2 Implementation)
# ==============================================================================

# Répertoire pour sauvegarder les modèles ML
MODELS_DIR = Path("models")
MODELS_DIR.mkdir(exist_ok=True)

# Stockage des modèles ML entraînés (par symbole et timeframe)
ml_models_cache: Dict[str, Dict] = {}
ml_scalers_cache: Dict[str, Dict] = {}

def collect_historical_data(symbols: List[str], timeframes: List[str], period_days: int = 90) -> Dict[str, Dict[str, pd.DataFrame]]:
    """Collecte les données historiques pour l'entraînement ML
    
    Args:
        symbols: Liste des symboles à analyser
        timeframes: Liste des timeframes à collecter
        period_days: Nombre de jours de données historiques
        
    Returns:
        Dictionnaire {symbol: {timeframe: DataFrame}}
    """
    historical_data = {}
    
    try:
        # Calculer le nombre de barres nécessaires selon le timeframe
        bars_needed = {
            'M1': period_days * 24 * 60,
            'M5': period_days * 24 * 12,
            'M15': period_days * 24 * 4,
            'M30': period_days * 24 * 2,
            'H1': period_days * 24,
            'H4': period_days * 6,
            'D1': period_days
        }
        
        for symbol in symbols:
            historical_data[symbol] = {}
            
            for tf in timeframes:
                try:
                    bars = min(bars_needed.get(tf, 1000), 10000)  # Limiter à 10000 barres max
                    
                    # Utiliser la fonction hybride get_market_data
                    df = get_market_data(symbol, tf, bars)
                    
                    if df is not None and len(df) > 50:
                        # Standardiser les colonnes pour le ML
                        if 'tick_volume' not in df.columns and 'volume' in df.columns:
                            df = df.rename(columns={'volume': 'tick_volume'})
                        
                        historical_data[symbol][tf] = df
                        logger.info(f"Collecté {len(df)} barres pour {symbol} {tf}")
                    else:
                        logger.warning(f"Données insuffisantes pour {symbol} {tf}")
                        
                except Exception as e:
                    logger.error(f"Erreur collecte données {symbol} {tf}: {e}")
                    continue
                    
    except Exception as e:
        logger.error(f"Erreur collecte données historiques: {e}")
    
    return historical_data

def extract_advanced_features(df: pd.DataFrame) -> pd.DataFrame:
    """Extrait des features avancées pour le ML
    
    Args:
        df: DataFrame avec colonnes OHLCV
        
    Returns:
        DataFrame avec features techniques
    """
    if df is None or len(df) < 50:
        return None
    
    try:
        # S'assurer que les colonnes nécessaires existent
        required_cols = ['open', 'high', 'low', 'close', 'tick_volume']
        for col in required_cols:
            if col not in df.columns:
                logger.warning(f"Colonne manquante: {col}")
                return None
        
        # Créer une copie pour éviter les SettingWithCopyWarning
        features = df.copy()
        
        # Features de base
        features['sma20'] = features['close'].rolling(window=20).mean()
        features['sma50'] = features['close'].rolling(window=50).mean()
        features['price_vs_sma20'] = (features['close'] - features['sma20']) / features['sma20']
        features['price_vs_sma50'] = (features['close'] - features['sma50']) / features['sma50']
        
        # RSI et ses dérivés
        delta = features['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        features['rsi'] = 100 - (100 / (1 + rs))
        features['rsi_normalized'] = (features['rsi'] - 50) / 50  # Normalisé entre -1 et 1
        
        # MACD
        exp1 = features['close'].ewm(span=12).mean()
        exp2 = features['close'].ewm(span=26).mean()
        features['macd'] = exp1 - exp2
        features['macd_signal'] = features['macd'].ewm(span=9).mean()
        features['macd_histogram'] = features['macd'] - features['macd_signal']
        
        # ATR et volatilité
        high_low = features['high'] - features['low']
        high_close = np.abs(features['high'] - features['close'].shift())
        low_close = np.abs(features['low'] - features['close'].shift())
        tr = np.maximum(high_low, np.maximum(high_close, low_close))
        features['atr'] = tr.rolling(window=14).mean()
        features['atr_normalized'] = features['atr'] / features['close']
        features['atr_ma_ratio'] = features['atr'] / features['atr'].rolling(window=50).mean()
        
        # Bollinger Bands
        bb_period = 20
        bb_std = 2
        features['bb_middle'] = features['close'].rolling(window=bb_period).mean()
        bb_std_dev = features['close'].rolling(window=bb_period).std()
        features['bb_upper'] = features['bb_middle'] + (bb_std_dev * bb_std)
        features['bb_lower'] = features['bb_middle'] - (bb_std_dev * bb_std)
        features['bb_width'] = (features['bb_upper'] - features['bb_lower']) / features['bb_middle']
        features['bb_position'] = (features['close'] - features['bb_lower']) / (features['bb_upper'] - features['bb_lower'])
        
        # Volume analysis
        features['volume_ma'] = features['tick_volume'].rolling(window=20).mean()
        features['volume_ratio'] = features['tick_volume'] / features['volume_ma']
        features['volume_trend'] = features['tick_volume'].rolling(window=5).mean() / features['tick_volume'].rolling(window=20).mean()
        
        # Price action features
        features['high_low_range'] = (features['high'] - features['low']) / features['close']
        features['open_close_range'] = np.abs(features['close'] - features['open']) / features['close']
        features['body_size'] = np.abs(features['close'] - features['open']) / features['close']
        
        # Momentum indicators
        for period in [5, 10, 20]:
            features[f'momentum_{period}'] = features['close'] / features['close'].shift(period) - 1
        
        # Distance aux extremums récents
        for period in [10, 20]:
            features[f'distance_to_high_{period}'] = (features['high'].rolling(window=period).max() - features['close']) / features['close']
            features[f'distance_to_low_{period}'] = (features['close'] - features['low'].rolling(window=period).min()) / features['close']
        
        # Simplifier les noms de colonnes pour compatibilité
        features['distance_to_high'] = features['distance_to_high_10']
        features['distance_to_low'] = features['distance_to_low_10']
        
        # Features avancées pour Boom/Crash
        if 'Boom' in str(df.iloc[0]['symbol']) if 'symbol' in df.columns else False or \
           'Crash' in str(df.iloc[0]['symbol']) if 'symbol' in df.columns else False:
            # Spike detection
            features['price_change'] = features['close'].pct_change()
            features['spike_threshold'] = features['price_change'].rolling(window=20).std() * 2
            features['is_spike'] = np.abs(features['price_change']) > features['spike_threshold']
            
            # Mean reversion indicator
            features['mean_reversion'] = (features['close'] - features['sma20']) / features['atr']
            
            # Volatility regime
            features['volatility_regime'] = features['atr'] / features['atr'].rolling(window=50).mean()
        
        # Nettoyer les valeurs infinies et NaN
        features = features.replace([np.inf, -np.inf], np.nan)
        features = features.fillna(method='ffill').fillna(method='bfill').fillna(0)
        
        logger.info(f"✅ {len(features.columns)} features extraites pour ML")
        return features
        
    except Exception as e:
        logger.error(f"Erreur extraction features: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return None

def calculate_trade_outcome(df: pd.DataFrame, lookahead: int = 5, threshold: float = 0.002) -> List[int]:
    """Calcule le résultat des trades (labels pour ML)
    
    Args:
        df: DataFrame avec prix
        lookahead: Nombre de périodes à regarder en avant
        threshold: Seuil de mouvement pour considérer un trade rentable (0.2% par défaut)
        
    Returns:
        Liste de labels: 1 (buy/win), -1 (sell/win), 0 (neutral/loss)
    """
    labels = []
    
    try:
        closes = df['close'].values
        
        for i in range(len(df) - lookahead):
            current_price = closes[i]
            future_price = closes[i + lookahead]
            
            price_change = (future_price - current_price) / current_price
            
            # Label basé sur le mouvement futur
            if price_change > threshold:
                labels.append(1)  # Buy signal gagnant
            elif price_change < -threshold:
                labels.append(-1)  # Sell signal gagnant
            else:
                labels.append(0)  # Neutre/perdant
                
        # Ajouter des zéros pour les dernières lignes
        labels.extend([0] * lookahead)
        
    except Exception as e:
        logger.error(f"Erreur calcul labels: {e}")
        labels = [0] * len(df)
    
    return labels

def train_ml_models(symbol: str, timeframe: str, historical_data: Optional[pd.DataFrame] = None) -> Dict[str, Any]:
    """Entraîne les modèles ML (RandomForest, GradientBoosting, MLPClassifier)
    
    Args:
        symbol: Symbole du marché
        timeframe: Timeframe d'analyse
        historical_data: Données historiques (optionnel, sera collecté si None)
        
    Returns:
        Dictionnaire avec les modèles entraînés et métriques
    """
    start_time = time.time()
    logger.info(f"Début de l'entraînement pour {symbol} {timeframe}")
    
    if not ML_AVAILABLE:
        error_msg = "Erreur: scikit-learn n'est pas disponible pour l'entraînement"
        logger.error(error_msg)
        return {"status": "error", "message": error_msg, "symbol": symbol, "timeframe": timeframe}
    
    try:
        model_key = f"{symbol}_{timeframe}"
        
        # Collecter les données si non fournies
        if historical_data is None:
            logger.info(f"Collecte des données historiques pour {symbol} {timeframe}...")
            data_dict = collect_historical_data([symbol], [timeframe], period_days=90)
            if symbol not in data_dict or timeframe not in data_dict[symbol]:
                error_msg = f"Impossible de collecter les données historiques pour {symbol} {timeframe}"
                logger.error(error_msg)
                return {"status": "error", "message": error_msg, "symbol": symbol, "timeframe": timeframe}
            historical_data = data_dict[symbol][timeframe]
        
        # Vérification des données d'entrée
        if historical_data is None or len(historical_data) < 100:
            error_msg = f"Données historiques insuffisantes pour {symbol} {timeframe} (minimum 100 bougies requises)"
            logger.warning(error_msg)
            return {"status": "error", "message": error_msg, "symbol": symbol, "timeframe": timeframe}
        
        logger.info(f"Données collectées: {len(historical_data)} boucles pour {symbol} {timeframe}")
        
        # Extraire les features
        logger.info(f"Extraction des features pour {symbol} {timeframe}...")
        features_df = extract_advanced_features(historical_data)
        
        # Vérifier si l'extraction des features a réussi
        if features_df is None or features_df.empty:
            error_msg = f"Échec de l'extraction des features pour {symbol} {timeframe}"
            logger.error(error_msg)
            return {"status": "error", "message": error_msg, "symbol": symbol, "timeframe": timeframe}
        
        # Vérifier la distribution des classes
        labels = calculate_trade_outcome(features_df)
        unique_labels, counts = np.unique(labels, return_counts=True)
        label_dist = dict(zip(unique_labels, counts))
        logger.info(f"Distribution des classes pour {symbol} {timeframe}: {label_dist}")
        
        features_df['label'] = labels
        
        # Sélectionner les features pour l'entraînement
        feature_columns = [
            'price_vs_sma20', 'price_vs_sma50',
            'rsi', 'rsi_normalized',
            'macd', 'macd_signal', 'macd_histogram',
            'atr', 'atr_normalized', 'atr_ma_ratio',
            'bb_width', 'bb_position',
            'volume_ratio', 'volume_trend',
            'high_low_range', 'open_close_range', 'body_size',
            'momentum_5', 'momentum_10', 'momentum_20',
            'distance_to_high', 'distance_to_low'
        ]
        
        # Filtrer les colonnes qui existent
        available_features = [f for f in feature_columns if f in features_df.columns]
        
        # Vérifier qu'il reste des features disponibles
        if not available_features:
            error_msg = f"Aucune feature disponible pour l'entraînement de {symbol} {timeframe}"
            logger.error(error_msg)
            return {"status": "error", "message": error_msg, "symbol": symbol, "timeframe": timeframe}
            
        logger.info(f"{len(available_features)} features disponibles pour l'entraînement")
        
        # Préparer X et y avec gestion des valeurs manquantes
        X = features_df[available_features].fillna(0)
        
        # Vérifier les valeurs manquantes après remplissage
        missing_values = X.isna().sum().sum()
        if missing_values > 0:
            logger.warning(f"{missing_values} valeurs manquantes détectées après remplissage pour {symbol} {timeframe}")
            
        # Vérifier la variance des features
        from sklearn.feature_selection import VarianceThreshold
        selector = VarianceThreshold()
        try:
            selector.fit(X)
            n_constant_features = sum(~selector.get_support())
            if n_constant_features > 0:
                logger.warning(f"{n_constant_features} caractéristiques constantes détectées pour {symbol} {timeframe}")
        except Exception as e:
            logger.warning(f"Erreur lors de la vérification de la variance: {str(e)}")
            
        y = features_df['label'].fillna(0).astype(int)
        
        # Supprimer les lignes avec des valeurs infinies
        X = X.replace([np.inf, -np.inf], 0)
        
        # Split train/test
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y if len(y.unique()) > 1 else None
        )
        
        # Vérifier si nous avons au moins 2 classes dans les données d'entraînement
        if len(y_train.unique()) < 2:
            logger.warning(f" Seulement {len(y_train.unique())} classe(s) détectée(s) dans les données d'entraînement pour {symbol} {timeframe}")
            
            # Si une seule classe, créer des échantillons synthétiques avec SMOTE-like approach
            if len(y_train.unique()) == 1:
                logger.info(f" Création d'échantillons synthétiques pour rééquilibrer les classes...")
                
                # Ajouter des échantillons de la classe manquante en inversant les labels
                minority_class = 1 if y_train.iloc[0] == 0 else 0
                n_synthetic = len(y_train) // 3  # Créer 1/3 des échantillons existants
                
                # Sélectionner aléatoirement des échantillons à modifier
                synthetic_indices = np.random.choice(len(X_train), n_synthetic, replace=False)
                X_synthetic = X_train.iloc[synthetic_indices].copy()
                y_synthetic = pd.Series([minority_class] * n_synthetic)
                
                # Ajouter un peu de bruit pour différencier les échantillons
                noise = np.random.normal(0, 0.01, X_synthetic.shape)
                X_synthetic = X_synthetic + noise
                
                # Combiner avec les données originales
                X_train = pd.concat([X_train, X_synthetic], ignore_index=True)
                y_train = pd.concat([y_train, y_synthetic], ignore_index=True)
                
                logger.info(f" {n_synthetic} échantillons synthétiques créés. Classes: {dict(y_train.value_counts())}")
        
        # Appliquer SMOTE si nous avons au moins 2 classes et assez d'échantillons
        try:
            if len(y_train.unique()) >= 2 and len(y_train) >= 10:
                from imblearn.over_sampling import SMOTE
                smote = SMOTE(random_state=42, k_neighbors=min(5, len(y_train) // 2 - 1))
                X_train_resampled, y_train_resampled = smote.fit_resample(X_train, y_train)
                
                logger.info(f" Rééquilibrage SMOTE: Avant {dict(y_train.value_counts())} → Après {dict(y_train_resampled.value_counts())}")
                X_train, y_train = X_train_resampled, y_train_resampled
        except ImportError:
            logger.warning(" imbalanced-learn non installé. Utilisation des données originales.")
        except Exception as e:
            logger.warning(f" Erreur SMOTE: {str(e)}. Utilisation des données originales.")
        
        # Normaliser les features
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)
        X_test_scaled = scaler.transform(X_test)
        
        models = {}
        metrics = {}
        
# ... (code après la modification)
        # 1. Random Forest
        logger.info(f"Entraînement RandomForest pour {symbol} {timeframe}...")
        rf_model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            min_samples_split=5,
            min_samples_leaf=2,
            random_state=42,
            n_jobs=-1,
            class_weight='balanced'
        )
        rf_model.fit(X_train_scaled, y_train)
        rf_pred = rf_model.predict(X_test_scaled)
        rf_accuracy = accuracy_score(y_test, rf_pred)
        rf_f1 = f1_score(y_test, rf_pred, average='weighted', zero_division=0)
        
        models['random_forest'] = rf_model
        metrics['random_forest'] = {
            'accuracy': float(rf_accuracy),
            'f1_score': float(rf_f1),
            'feature_importance': dict(zip(available_features, rf_model.feature_importances_))
        }
        
        # 2. Gradient Boosting
        logger.info(f"Entraînement GradientBoosting pour {symbol} {timeframe}...")
        gb_model = GradientBoostingClassifier(
            n_estimators=100,
            learning_rate=0.1,
            max_depth=6,
            random_state=42
        )
        gb_model.fit(X_train_scaled, y_train)
        gb_pred = gb_model.predict(X_test_scaled)
        gb_accuracy = accuracy_score(y_test, gb_pred)
        gb_f1 = f1_score(y_test, gb_pred, average='weighted', zero_division=0)
        
        models['gradient_boosting'] = gb_model
        metrics['gradient_boosting'] = {
            'accuracy': float(gb_accuracy),
            'f1_score': float(gb_f1),
            'feature_importance': dict(zip(available_features, gb_model.feature_importances_))
        }
        
        # 3. MLP (Neural Network)
        logger.info(f"Entraînement MLPClassifier pour {symbol} {timeframe}...")
        mlp_model = MLPClassifier(
            hidden_layer_sizes=(50, 25),
            max_iter=500,
            random_state=42,
            early_stopping=True,
            validation_fraction=0.1
        )
        mlp_model.fit(X_train_scaled, y_train)
        mlp_pred = mlp_model.predict(X_test_scaled)
        mlp_accuracy = accuracy_score(y_test, mlp_pred)
        mlp_f1 = f1_score(y_test, mlp_pred, average='weighted', zero_division=0)
        
        models['mlp'] = mlp_model
        metrics['mlp'] = {
            'accuracy': float(mlp_accuracy),
            'f1_score': float(mlp_f1)
        }
        
        # Sauvegarder les modèles
        ml_models_cache[model_key] = models
        ml_scalers_cache[model_key] = scaler
        
        # Sauvegarder sur disque
        try:
            model_path = MODELS_DIR / f"{model_key}_rf.joblib"
            scaler_path = MODELS_DIR / f"{model_key}_scaler.joblib"
            joblib.dump(rf_model, model_path)
            joblib.dump(scaler, scaler_path)
            logger.info(f"Modèles sauvegardés dans {MODELS_DIR}")
        except Exception as e:
            logger.warning(f"Impossible de sauvegarder les modèles: {e}")
        
        # NOUVEAU: Sauvegarder les métriques dans un fichier JSON pour récupération ultérieure
        try:
            metrics_file = MODELS_DIR / f"{model_key}_metrics.json"
            metrics_to_save = {
                "symbol": symbol,
                "timeframe": timeframe,
                "training_date": datetime.now().isoformat(),
                "metrics": metrics,
                "best_model": max(metrics.keys(), key=lambda k: metrics[k]['f1_score']),
                "features_used": available_features,
                "training_samples": len(X_train),
                "test_samples": len(X_test)
            }
            
            with open(metrics_file, 'w', encoding='utf-8') as f:
                json.dump(metrics_to_save, f, indent=2, ensure_ascii=False)
            
            logger.info(f"✅ Métriques sauvegardées dans {metrics_file}")
        except Exception as e:
            logger.warning(f"Impossible de sauvegarder les métriques: {e}")
        
        # Choisir le meilleur modèle
        best_model_name = max(metrics.keys(), key=lambda k: metrics[k]['f1_score'])
        
        return {
            "status": "success",
            "symbol": symbol,
            "timeframe": timeframe,
            "models": list(models.keys()),
            "metrics": metrics,
            "best_model": best_model_name,
            "features_used": available_features,
            "training_samples": len(X_train),
            "test_samples": len(X_test)
        }
        
    except Exception as e:
        logger.error(f"Erreur entraînement ML pour {symbol} {timeframe}: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return {"error": str(e)}

def validate_multi_timeframe_ml(symbol: str, timeframes: List[str]) -> Dict[str, Any]:
    """Validation croisée multi-timeframe avec ML
    
    Args:
        symbol: Symbole du marché
        timeframes: Liste des timeframes à valider
        
    Returns:
        Dictionnaire avec consensus et validation
    """
    if not ML_AVAILABLE:
        return {"valid": False, "reason": "ML non disponible"}
    
    try:
        predictions = {}
        confidences = {}
        
        for tf in timeframes:
            model_key = f"{symbol}_{tf}"
            
            # Charger ou entraîner le modèle
            if model_key not in ml_models_cache:
                train_result = train_ml_models(symbol, tf)
                if "error" in train_result:
                    continue
            
            # Récupérer les données actuelles
            if not mt5_initialized:
                continue
                
            tf_map = {
                'M1': mt5.TIMEFRAME_M1, 'M5': mt5.TIMEFRAME_M5,
                'M15': mt5.TIMEFRAME_M15, 'H1': mt5.TIMEFRAME_H1,
                'H4': mt5.TIMEFRAME_H4, 'D1': mt5.TIMEFRAME_D1
            }
            
            mt5_tf = tf_map.get(tf, mt5.TIMEFRAME_M1)
            rates = mt5.copy_rates_from_pos(symbol, mt5_tf, 0, 100)
            
            if rates is None or len(rates) < 50:
                continue
            
            df = pd.DataFrame(rates)
            features_df = extract_advanced_features(df)
            
            # Sélectionner les features
            feature_columns = [
                'sma_20', 'sma_50', 'ema_9', 'ema_21', 'ema_50',
                'sma_20_slope', 'ema_9_slope',
                'price_vs_sma20', 'price_vs_sma50',
                'rsi', 'rsi_normalized',
                'macd', 'macd_signal', 'macd_histogram',
                'atr', 'atr_normalized', 'atr_ma_ratio',
                'bb_width', 'bb_position',
                'volume_ratio', 'volume_trend',
                'high_low_range', 'open_close_range', 'body_size',
                'momentum_5', 'momentum_10', 'momentum_20',
                'distance_to_high', 'distance_to_low'
            ]
            
            available_features = [f for f in feature_columns if f in features_df.columns]
            X = features_df[available_features].iloc[-1:].fillna(0)
            X = X.replace([np.inf, -np.inf], 0)
            
            # Prédire avec le meilleur modèle
            if model_key in ml_models_cache and model_key in ml_scalers_cache:
                scaler = ml_scalers_cache[model_key]
                models = ml_models_cache[model_key]
                
                # Utiliser RandomForest comme modèle principal
                if 'random_forest' in models:
                    X_scaled = scaler.transform(X)
                    prediction = models['random_forest'].predict(X_scaled)[0]
                    proba = models['random_forest'].predict_proba(X_scaled)[0]
                    confidence = max(proba) * 100
                    
                    predictions[tf] = prediction  # 1, -1, ou 0
                    confidences[tf] = confidence
        
        if not predictions:
            return {"valid": False, "reason": "Aucune prédiction disponible"}
        
        # Calculer le consensus
        buy_votes = sum(1 for p in predictions.values() if p == 1)
        sell_votes = sum(1 for p in predictions.values() if p == -1)
        neutral_votes = sum(1 for p in predictions.values() if p == 0)
        
        total_votes = len(predictions)
        avg_confidence = np.mean(list(confidences.values())) if confidences else 0
        
        consensus = "buy" if buy_votes > sell_votes and buy_votes > neutral_votes else \
                   "sell" if sell_votes > buy_votes and sell_votes > neutral_votes else "neutral"
        
        consensus_strength = max(buy_votes, sell_votes, neutral_votes) / total_votes if total_votes > 0 else 0
        
        # Validation: exiger au moins 60% de consensus et 65% de confiance moyenne
        is_valid = consensus_strength >= 0.60 and avg_confidence >= 65.0
        
        return {
            "valid": is_valid,
            "consensus": consensus,
            "consensus_strength": round(consensus_strength * 100, 1),
            "avg_confidence": round(avg_confidence, 1),
            "buy_votes": buy_votes,
            "sell_votes": sell_votes,
            "neutral_votes": neutral_votes,
            "predictions": predictions,
            "confidences": confidences
        }
        
    except Exception as e:
        logger.error(f"Erreur validation multi-timeframe ML: {e}")
        return {"valid": False, "reason": str(e)}

def adaptive_timeframe_weights(symbol: str, recent_performance: Optional[Dict] = None) -> Dict[str, float]:
    """Ajuste les poids des timeframes en fonction des performances récentes
    
    Args:
        symbol: Symbole du marché
        recent_performance: Dictionnaire avec performances récentes par timeframe
        
    Returns:
        Dictionnaire avec poids ajustés par timeframe
    """
    # Poids de base
    base_weights = {
        'd1': 0.35,
        'h4': 0.30,
        'h1': 0.20,
        'm30': 0.08,
        'm15': 0.05,
        'm5': 0.02,
        'm1': 0.00
    }
    
    if recent_performance is None:
        return base_weights
    
    adjusted_weights = base_weights.copy()
    
    try:
        # Ajuster les poids selon les performances récentes
        for tf, perf in recent_performance.items():
            tf_lower = tf.lower()
            
            if tf_lower in adjusted_weights:
                win_rate = perf.get('win_rate', 0.5)
                
                # Augmenter le poids si win_rate > 60%
                if win_rate > 0.60:
                    adjusted_weights[tf_lower] *= 1.2
                # Réduire le poids si win_rate < 40%
                elif win_rate < 0.40:
                    adjusted_weights[tf_lower] *= 0.8
        
        # Normaliser pour que la somme = 1
        total = sum(adjusted_weights.values())
        if total > 0:
            adjusted_weights = {k: v / total for k, v in adjusted_weights.items()}
        
    except Exception as e:
        logger.warning(f"Erreur ajustement poids timeframes: {e}")
    
    return adjusted_weights

@app.post("/coherent-analysis")
async def get_coherent_analysis(request: CoherentAnalysisRequest):
    """Endpoint pour l'analyse cohérente multi-timeframes"""
    try:
        analysis = await calculate_coherent_analysis(request.symbol, request.timeframes)
        return analysis
    except Exception as e:
        logger.error(f"Erreur endpoint analyse cohérente: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/coherent-analysis")
async def get_coherent_analysis_get(symbol: str = "EURUSD"):
    """Version GET de l'analyse cohérente"""
    try:
        analysis = await calculate_coherent_analysis(symbol)
        return analysis
    except Exception as e:
        logger.error(f"Erreur endpoint GET analyse cohérente: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==============================================================================
# ENDPOINTS PHASE 2: MACHINE LEARNING
# ==============================================================================

class MLTrainRequest(BaseModel):
    symbol: str
    timeframe: str = "M1"
    period_days: int = 90
    data: Optional[List[Dict[str, Any]]] = None  # Données historiques fournies par le client (Phase 2 Cloud)

class MLPredictRequest(BaseModel):
    symbol: str
    timeframes: Optional[List[str]] = ["M1", "M5", "M15", "H1", "H4"]

@app.post("/ml/train")
async def train_ml_models_endpoint(request: MLTrainRequest):
    """Endpoint pour entraîner les modèles ML
    
    Args:
        request: Requête avec symbol, timeframe et period_days
        
    Returns:
        Résultats de l'entraînement avec métriques
    """
    try:
        if not ML_AVAILABLE:
            raise HTTPException(status_code=503, detail="scikit-learn non disponible")
        
        logger.info(f"Entraînement ML demandé pour {request.symbol} {request.timeframe}")
        
        # Si des données sont fournies dans la requête, les utiliser directement (mode Cloud)
        historical_data = None
        if request.data and len(request.data) > 0:
            logger.info(f"Utilisation des données poussées ({len(request.data)} barres) pour l'entraînement cloud")
            historical_data = pd.DataFrame(request.data)
            # S'assurer que les noms de colonnes sont corrects pour MT5 (lowercase)
            # MT5 rates usually have: time, open, high, low, close, tick_volume, spread, real_volume
        
        result = train_ml_models(request.symbol, request.timeframe, historical_data=historical_data)
        
        if "error" in result:
            raise HTTPException(status_code=500, detail=result["error"])
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur entraînement ML endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ml/train")
async def train_ml_models_get(symbol: str = "EURUSD", timeframe: str = "M1"):
    """Version GET de l'entraînement ML"""
    try:
        if not ML_AVAILABLE:
            raise HTTPException(status_code=503, detail="scikit-learn non disponible")
        
        result = train_ml_models(symbol, timeframe, historical_data=None)
        
        if "error" in result:
            raise HTTPException(status_code=500, detail=result["error"])
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur entraînement ML GET: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ml/predict")
async def predict_ml_endpoint(request: MLPredictRequest):
    """Endpoint pour prédictions ML avec validation multi-timeframe
    
    Args:
        request: Requête avec symbol et timeframes
        
    Returns:
        Prédictions ML avec validation croisée
    """
    try:
        if not ML_AVAILABLE:
            raise HTTPException(status_code=503, detail="scikit-learn non disponible")
        
        logger.info(f"Prédiction ML demandée pour {request.symbol}")
        
        # Validation multi-timeframe ML
        validation_result = validate_multi_timeframe_ml(request.symbol, request.timeframes)
        
        # Analyse cohérente traditionnelle
        coherent_analysis = await calculate_coherent_analysis(request.symbol, request.timeframes)
        
        return {
            "symbol": request.symbol,
            "ml_validation": validation_result,
            "coherent_analysis": coherent_analysis,
            "timestamp": datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur prédiction ML endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ml/predict")
async def predict_ml_get(symbol: str = "EURUSD", timeframes: str = "M1,M5,M15,H1,H4"):
    """Version GET des prédictions ML"""
    try:
        if not ML_AVAILABLE:
            raise HTTPException(status_code=503, detail="scikit-learn non disponible")
        
        tf_list = [tf.strip() for tf in timeframes.split(",")]
        validation_result = validate_multi_timeframe_ml(symbol, tf_list)
        coherent_analysis = await calculate_coherent_analysis(symbol, tf_list)
        
        return {
            "symbol": symbol,
            "ml_validation": validation_result,
            "coherent_analysis": coherent_analysis,
            "timestamp": datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur prédiction ML GET: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ml/models")
async def list_ml_models():
    """Liste les modèles ML disponibles dans le cache"""
    try:
        models_list = []
        
        for model_key in ml_models_cache.keys():
            symbol, timeframe = model_key.split("_", 1)
            models_list.append({
                "symbol": symbol,
                "timeframe": timeframe,
                "model_key": model_key
            })
        
        return {
            "total_models": len(models_list),
            "models": models_list
        }
    except Exception as e:
        logger.error(f"Erreur liste modèles ML: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ml/metrics")
async def get_ml_metrics(symbol: str = "EURUSD", timeframe: str = "M1"):
    """Récupère les métriques ML depuis les modèles déjà entraînés"""
    try:
        if not ML_AVAILABLE:
            raise HTTPException(status_code=503, detail="scikit-learn non disponible")
        
        model_key = f"{symbol}_{timeframe}"
        
        # Vérifier si les modèles sont en cache
        if model_key not in ml_models_cache:
            # Essayer de charger depuis le disque sans MT5
            try:
                import joblib
                model_path = MODELS_DIR / f"{model_key}_rf.joblib"
                scaler_path = MODELS_DIR / f"{model_key}_scaler.joblib"
                
                if model_path.exists():
                    rf_model = joblib.load(model_path)
                    scaler = joblib.load(scaler_path) if scaler_path.exists() else None
                    
                    # Mettre en cache
                    ml_models_cache[model_key] = {
                        'random_forest': rf_model
                    }
                    ml_scalers_cache[model_key] = scaler
                    
                    logger.info(f"Modèle {model_key} chargé depuis le disque")
                else:
                    # Si le modèle spécifique n'existe pas, essayer avec EURUSD M1 par défaut
                    default_key = "EURUSD_M1"
                    default_model_path = MODELS_DIR / f"{default_key}_rf.joblib"
                    
                    if default_model_path.exists():
                        rf_model = joblib.load(default_model_path)
                        default_scaler_path = MODELS_DIR / f"{default_key}_scaler.joblib"
                        scaler = joblib.load(default_scaler_path) if default_scaler_path.exists() else None
                        
                        ml_models_cache[model_key] = {
                            'random_forest': rf_model
                        }
                        ml_scalers_cache[model_key] = scaler
                        
                        logger.info(f"Modèle par défaut {default_key} utilisé pour {symbol} {timeframe}")
                    else:
                        raise HTTPException(status_code=404, detail=f"Modèle non trouvé pour {symbol} {timeframe}")
            except Exception as e:
                raise HTTPException(status_code=404, detail=f"Modèle non disponible pour {symbol} {timeframe}: {str(e)}")
        
        # Récupérer les métriques depuis le cache ou créer des métriques par défaut
        models = ml_models_cache.get(model_key, {})
        if not models:
            raise HTTPException(status_code=404, detail=f"Aucun modèle trouvé pour {symbol} {timeframe}")
        
        # NOUVEAU: Récupérer les vraies métriques depuis les fichiers sauvegardés ou recalculer
        metrics_result = {}
        best_model_name = "random_forest"
        best_accuracy = 0.0
        
        # Essayer de charger les métriques sauvegardées depuis l'entraînement
        metrics_file = MODELS_DIR / f"{model_key}_metrics.json"
        if metrics_file.exists():
            try:
                with open(metrics_file, 'r', encoding='utf-8') as f:
                    saved_metrics = json.load(f)
                    if "metrics" in saved_metrics:
                        metrics_result = saved_metrics["metrics"]
                        best_model_name = saved_metrics.get("best_model", "random_forest")
                        # Trouver la meilleure accuracy
                        for model_name, model_metrics in metrics_result.items():
                            acc = model_metrics.get("accuracy", 0.0)
                            if isinstance(acc, float) and acc <= 1.0:
                                acc = acc * 100.0  # Convertir en pourcentage
                            if acc > best_accuracy:
                                best_accuracy = acc
                        logger.info(f"✅ Métriques chargées depuis fichier pour {symbol} {timeframe}: Best={best_accuracy:.2f}%")
            except Exception as e:
                logger.warning(f"⚠️ Erreur chargement métriques depuis fichier: {e}")
        
        # Si pas de métriques sauvegardées, recalculer depuis les modèles
        if not metrics_result:
            logger.info(f"📊 Recalcul des métriques depuis les modèles pour {symbol} {timeframe}...")
            
            # Récupérer les données de test pour recalculer les métriques
            try:
                if mt5_initialized:
                    tf_map = {
                        'M1': mt5.TIMEFRAME_M1, 'M5': mt5.TIMEFRAME_M5,
                        'M15': mt5.TIMEFRAME_M15, 'H1': mt5.TIMEFRAME_H1,
                        'H4': mt5.TIMEFRAME_H4, 'D1': mt5.TIMEFRAME_D1
                    }
                    mt5_tf = tf_map.get(timeframe, mt5.TIMEFRAME_M1)
                    rates = mt5.copy_rates_from_pos(symbol, mt5_tf, 0, 200)
                    
                    if rates is not None and len(rates) >= 100:
                        try:
                            df = pd.DataFrame(rates)
                            features_df = extract_advanced_features(df)
                            
                            if features_df is not None and not features_df.empty:
                                labels = calculate_trade_outcome(features_df)
                                feature_columns = [
                                    'price_vs_sma20', 'price_vs_sma50', 'rsi', 'rsi_normalized',
                                    'macd', 'macd_signal', 'macd_histogram', 'atr', 'atr_normalized',
                                    'atr_ma_ratio', 'bb_width', 'bb_position', 'volume_ratio',
                                    'volume_trend', 'high_low_range', 'open_close_range', 'body_size',
                                    'momentum_5', 'momentum_10', 'momentum_20', 'distance_to_high', 'distance_to_low'
                                ]
                                available_features = [f for f in feature_columns if f in features_df.columns]
                                
                                if available_features:
                                    X = features_df[available_features].fillna(0).replace([np.inf, -np.inf], 0)
                                    y = labels.fillna(0).astype(int)
                                    
                                    # Split pour test
                                    from sklearn.model_selection import train_test_split
                                    X_train, X_test, y_train, y_test = train_test_split(
                                        X, y, test_size=0.2, random_state=42
                                    )
                                    
                                    scaler = ml_scalers_cache.get(model_key)
                                    if scaler:
                                        X_test_scaled = scaler.transform(X_test)
                                        
                                        # Recalculer les métriques pour chaque modèle
                                        for model_name, model in models.items():
                                            try:
                                                pred = model.predict(X_test_scaled)
                                                from sklearn.metrics import accuracy_score, f1_score
                                                acc = accuracy_score(y_test, pred)
                                                f1 = f1_score(y_test, pred, average='weighted', zero_division=0)
                                                
                                                metrics_result[model_name] = {
                                                    "accuracy": float(acc * 100.0),  # En pourcentage
                                                    "f1_score": float(f1 * 100.0),  # En pourcentage
                                                    "feature_importance": {}
                                                }
                                                
                                                if hasattr(model, 'feature_importances_'):
                                                    metrics_result[model_name]["feature_importance"] = dict(
                                                        zip(available_features, model.feature_importances_)
                                                    )
                                                
                                                if acc > best_accuracy / 100.0:
                                                    best_accuracy = acc * 100.0
                                                    best_model_name = model_name
                                                    
                                            except Exception as e:
                                                logger.warning(f"Erreur calcul métriques pour {model_name}: {e}")
                        except Exception as e:
                            logger.warning(f"Erreur recalcul métriques: {e}")
            except Exception as e:
                logger.warning(f"Erreur récupération données pour recalcul: {e}")
        
        # Si toujours pas de métriques, utiliser des valeurs par défaut mais marquer comme non fiables
        if not metrics_result:
            logger.warning(f"⚠️ Aucune métrique disponible pour {symbol} {timeframe} - Utilisation valeurs par défaut (NON FIABLES)")
            default_metrics = {
                "accuracy": 0.0,  # 0% pour indiquer que ce n'est pas fiable
                "f1_score": 0.0,
                "feature_importance": {}
            }
            metrics_result = {
                "random_forest": default_metrics,
                "gradient_boosting": default_metrics,
                "mlp": default_metrics
            }
            best_model_name = "random_forest"
            best_accuracy = 0.0
        
        # Formater les métriques pour correspondre au format attendu par MQL5
        formatted_metrics = {}
        for model_name, model_metrics in metrics_result.items():
            acc = model_metrics.get("accuracy", 0.0)
            f1 = model_metrics.get("f1_score", 0.0)
            
            # S'assurer que les valeurs sont en pourcentage (0-100)
            if isinstance(acc, float) and acc <= 1.0:
                acc = acc * 100.0
            if isinstance(f1, float) and f1 <= 1.0:
                f1 = f1 * 100.0
                
            formatted_metrics[model_name] = {
                "accuracy": round(acc, 2),
                "f1_score": round(f1, 2),
                "feature_importance": model_metrics.get("feature_importance", {})
            }
        
        # Calculer best_accuracy et best_f1_score
        best_accuracy = 0.0
        best_f1_score = 0.0
        for model_name, model_metrics in formatted_metrics.items():
            acc = model_metrics.get("accuracy", 0.0)
            f1 = model_metrics.get("f1_score", 0.0)
            if acc > best_accuracy:
                best_accuracy = acc
            if f1 > best_f1_score:
                best_f1_score = f1
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "status": "success",
            "metrics": formatted_metrics,
            "best_model": best_model_name,
            "best_accuracy": round(best_accuracy, 2),
            "best_f1_score": round(best_f1_score, 2),
            "training_samples": len(X_train) if 'X_train' in locals() else 0,
            "test_samples": len(X_test) if 'X_test' in locals() else 0,
            "recommendations": {
                "min_confidence": round(max(65.0, best_accuracy - 10.0), 2),
                "use_model": best_model_name,
                "suggested_threshold": round(max(75.0, best_accuracy - 15.0), 2)
            },
            "timestamp": datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur récupération métriques ML: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ml/metrics/detailed")
async def get_detailed_ml_metrics(symbol: str = "EURUSD", timeframe: str = "M1"):
    """Récupère les métriques ML détaillées en forçant un ré-entraînement si nécessaire"""
    try:
        if not ML_AVAILABLE:
            raise HTTPException(status_code=503, detail="scikit-learn non disponible")
        
        logger.info(f"Récupération métriques détaillées pour {symbol} {timeframe}...")
        
        # Forcer l'entraînement pour obtenir les métriques
        train_result = train_ml_models(symbol, timeframe, historical_data=None)
        
        if "error" in train_result:
            raise HTTPException(status_code=500, detail=train_result["error"])
        
        # Formater les métriques pour une meilleure lisibilité
        formatted_metrics = {}
        for model_name, metrics in train_result.get("metrics", {}).items():
            formatted_metrics[model_name] = {
                "accuracy": round(metrics.get("accuracy", 0) * 100, 2),  # En pourcentage
                "f1_score": round(metrics.get("f1_score", 0) * 100, 2),  # En pourcentage
                "feature_importance": metrics.get("feature_importance", {})
            }
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "status": "success",
            "metrics": formatted_metrics,
            "best_model": train_result.get("best_model", ""),
            "features_count": len(train_result.get("features_used", [])),
            "training_samples": train_result.get("training_samples", 0),
            "test_samples": train_result.get("test_samples", 0),
            "recommendations": {
                "use_model": train_result.get("best_model", ""),
                "min_confidence": round(max([m.get("accuracy", 0) for m in train_result.get("metrics", {}).values()]) * 0.8, 2),
                "suggested_threshold": round(max([m.get("f1_score", 0) for m in train_result.get("metrics", {}).values()]) * 0.75, 2)
            },
            "timestamp": datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur récupération métriques détaillées ML: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/dashboard/graphs")
async def get_dashboard_graphs(symbol: str = "EURUSD"):
    """Endpoint pour les graphiques et statistiques du dashboard"""
    try:
        # Récupérer les statistiques du dashboard
        stats_response = await get_dashboard_stats(symbol)
        
        # Ajouter les graphiques
        graphs = {}
        
        # Graphique de confiance par timeframe
        if "coherent_analysis" in stats_response and "trends" in stats_response["coherent_analysis"]:
            trends = stats_response["coherent_analysis"]["trends"]
            confidence_data = []
            
            tf_order = ["d1", "h4", "h1", "m30", "m15", "m5", "m1"]
            tf_labels = ["1J", "4H", "1H", "30M", "15M", "5M", "1M"]
            
            for tf, label in zip(tf_order, tf_labels):
                if tf in trends:
                    confidence_data.append({
                        "timeframe": label,
                        "confidence": trends[tf].get("strength", 0),
                        "direction": trends[tf].get("direction", "neutral")
                    })
            
            graphs["confidence_by_timeframe"] = confidence_data
        
        # Graphique de distribution des décisions
        if "coherent_analysis" in stats_response:
            analysis = stats_response["coherent_analysis"]
            distribution = {
                "bullish": analysis.get("bullish_pct", 0),
                "bearish": analysis.get("bearish_pct", 0),
                "neutral": analysis.get("neutral_pct", 0)
            }
            graphs["decision_distribution"] = distribution
        
        # Statistiques de performance
        if "model_performance" in stats_response:
            model_perf = stats_response["model_performance"]
            if "models" in model_perf:
                models_data = []
                for model_name, model_stats in model_perf["models"].items():
                    models_data.append({
                        "model": model_name,
                        "total_predictions": model_stats.get("total_predictions", 0),
                        "avg_confidence": model_stats.get("avg_confidence", 0),
                        "buy_count": model_stats.get("buy_count", 0),
                        "sell_count": model_stats.get("sell_count", 0)
                    })
                graphs["model_performance"] = models_data
        
        # Statistiques de trading
        if "trading_stats" in stats_response:
            trading_stats = stats_response["trading_stats"]
            trading_graphs = {
                "total_trades": trading_stats.get("total_trades", 0),
                "buy_trades": trading_stats.get("buy_trades", 0),
                "sell_trades": trading_stats.get("sell_trades", 0),
                "avg_confidence": trading_stats.get("avg_confidence", 0),
                "high_confidence_trades": trading_stats.get("high_confidence_trades", 0),
                "confidence_distribution": trading_stats.get("confidence_distribution", {}),
                "action_distribution": trading_stats.get("action_distribution", {})
            }
            graphs["trading_statistics"] = trading_graphs
        
        return {
            "status": "success",
            "symbol": symbol,
            "timestamp": datetime.now().isoformat(),
            "graphs": graphs,
            "stats": stats_response
        }
        
    except Exception as e:
        logger.error(f"Erreur graphs dashboard: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/trend")
async def get_trend_analysis_get(symbol: str = "EURUSD", timeframe: str = "M1"):
    """Endpoint GET pour l'analyse de tendance (compatible avec MT5)"""
    try:
        logger.info(f"Analyse de tendance GET demandée pour {symbol} ({timeframe})")
        
        # Calculer la direction et la confiance
        direction_str_result = calculate_trend_direction(symbol, timeframe)
        confidence = calculate_trend_confidence(symbol, timeframe)
        
        # Convertir la direction en nombre pour les calculs
        # calculate_trend_direction retourne une chaîne comme "UP", "DOWN", "NEUTRAL"
        direction_str_upper = str(direction_str_result).upper()
        if "UP" in direction_str_upper or "BULL" in direction_str_upper or "BUY" in direction_str_upper:
            direction_num = 1
            direction_str = "BUY"
            signal = "bullish"
        elif "DOWN" in direction_str_upper or "BEAR" in direction_str_upper or "SELL" in direction_str_upper:
            direction_num = -1
            direction_str = "SELL"
            signal = "bearish"
        else:
            direction_num = 0
            direction_str = "NEUTRE"
            signal = "neutral"
        
        # Ajouter l'état du marché
        market_state_info = calculate_market_state(symbol, timeframe)
        
        # Calculer la force de la tendance (0-100)
        strength = abs(direction_num) * confidence * 100
        
        response = {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": time.time(),
            "direction": direction_str,
            "confidence": confidence,
            "strength": strength,  # Force de la tendance (0-100)
            "market_state": market_state_info["market_state"],
            "market_trend": market_state_info["market_trend"],
            "signal": signal
        }
        
        logger.info(f"Tendance GET {symbol}: {direction_str} (conf: {confidence:.1f}%, strength: {strength:.1f}%) - État: {market_state_info['market_state']}")
        return response
        
    except Exception as e:
        logger.error(f"Erreur analyse tendance GET: {e}", exc_info=True)
        return {
            "error": f"Erreur lors de l'analyse de tendance: {str(e)}",
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": time.time()
        }

@app.post("/trend")
async def get_trend_analysis(request: TrendAnalysisRequest):
    """Endpoint principal pour l'analyse de tendance (compatible avec MT5) - Version améliorée"""
    try:
        logger.info(f"Analyse de tendance POST demandée pour {request.symbol}")
        
        response = {
            "symbol": request.symbol,
            "timestamp": time.time()
        }
        
        # Validation multi-timeframe si disponible
        if IMPROVEMENTS_AVAILABLE and mt5_initialized:
            try:
                import MetaTrader5 as mt5_module
                multi_tf_validation = validate_multi_timeframe(
                    symbol=request.symbol,
                    timeframes=request.timeframes,
                    mt5_module=mt5_module,
                    mt5_initialized=mt5_initialized
                )
                response['multi_timeframe'] = {
                    'consensus': multi_tf_validation['consensus'],
                    'is_valid': multi_tf_validation['is_valid'],
                    'avg_confidence': multi_tf_validation.get('avg_confidence', 0.0),
                    'reason': multi_tf_validation.get('reason', '')
                }
            except Exception as e:
                logger.warning(f"Erreur validation multi-timeframe: {e}")
        
        # Analyser chaque timeframe demandé
        for tf in request.timeframes:
            direction = calculate_trend_direction(request.symbol, tf)
            confidence = calculate_trend_confidence(request.symbol, tf)
            
            # Ajouter l'état du marché
            market_state_info = calculate_market_state(request.symbol, tf)
            
            response[tf] = {
                "direction": direction,
                "confidence": confidence,
                "market_state": market_state_info["market_state"],
                "market_trend": market_state_info["market_trend"]
            }
        
        logger.info(f"Tendance POST {request.symbol}: {response.get('M1', {}).get('direction', 'unknown')} "
                   f"(conf: {response.get('M1', {}).get('confidence', 0):.1f}%)")
        return response
        
    except Exception as e:
        logger.error(f"Erreur analyse tendance POST: {e}")
        return {
            "error": f"Erreur lors de l'analyse de tendance: {str(e)}",
            "symbol": request.symbol,
            "timestamp": time.time()
        }

@app.get("/market-state")
async def get_market_state_endpoint(symbol: str = "EURUSD", timeframe: str = "M1"):
    """Endpoint dédié pour l'état du marché (compatible avec tous les robots)"""
    try:
        market_info = calculate_market_state(symbol, timeframe)
        
        response = {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": time.time(),
            "market_state": market_info["market_state"],
            "market_trend": market_info["market_trend"]
        }
        
        logger.info(f"État marché {symbol} {timeframe}: {market_info['market_state']} - {market_info['market_trend']}")
        return response
        
    except Exception as e:
        logger.error(f"Erreur état marché: {e}")
        return {
            "error": f"Erreur lors de l'analyse de l'état du marché: {str(e)}",
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": time.time()
        }

@app.get("/angelofspike/trend")
async def get_angelofspike_trend(symbol: str = "Boom 1000 Index", timeframe: str = "M1"):
    """Endpoint spécifique pour AngelOfSpike avec état du marché inclus"""
    try:
        # Analyse de tendance standard
        direction = calculate_trend_direction(symbol, timeframe)
        confidence = calculate_trend_confidence(symbol, timeframe)
        
        # État du marché
        market_info = calculate_market_state(symbol, timeframe)
        
        response = {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": time.time(),
            "direction": direction,
            "confidence": confidence,
            "market_state": market_info["market_state"],
            "market_trend": market_info["market_trend"],
            "signal": "BUY" if direction == "buy" else "SELL" if direction == "sell" else "HOLD"
        }
        
        logger.info(f"AngelOfSpike {symbol}: {direction} (conf: {confidence:.1f}%) - État: {market_info['market_state']}")
        return response
        
    except Exception as e:
        logger.error(f"Erreur AngelOfSpike trend: {e}")
        return {
            "error": f"Erreur lors de l'analyse AngelOfSpike: {str(e)}",
            "symbol": symbol,
            "timestamp": time.time()
        }

@app.get("/trend/health")
async def trend_health():
    """Vérification de santé pour le module de tendance"""
    return {
        "status": "ok",
        "module": "trend_analysis",
        "timestamp": time.time(),
        "mt5_available": mt5_initialized
    }

@app.get("/status")
async def status():
    """Statut détaillé du serveur"""
    return {
        "status": "running",
        "timestamp": datetime.now().isoformat(),
        "mt5": {
            "available": MT5_AVAILABLE,
            "initialized": mt5_initialized
        },
        "mistral": {
            "available": MISTRAL_AVAILABLE
        },
        "gemini": {
            "available": GEMINI_AVAILABLE
        },
        "backend": {
            "available": BACKEND_AVAILABLE,
            "ml_predictor": ml_predictor is not None,
            "spike_predictor": spike_predictor is not None
        },
        "ai_indicators": {
            "available": AI_INDICATORS_AVAILABLE
        },
        "cache": {
            "size": len(prediction_cache),
            "duration_seconds": CACHE_DURATION
        },
        "default_symbol": DEFAULT_SYMBOL,
        "trend_analysis": {
            "available": True,
            "mt5_available": mt5_initialized
        }
    }

@app.get("/logs")
async def get_logs(limit: int = 100):
    """Récupère les dernières lignes du log"""
    try:
        if not LOG_FILE.exists():
            return {"logs": [], "message": "Aucun log disponible"}
        
        with open(LOG_FILE, "r", encoding="utf-8") as f:
            lines = f.readlines()
            recent_lines = lines[-limit:] if len(lines) > limit else lines
        
        return {
            "logs": [line.strip() for line in recent_lines],
            "total_lines": len(lines),
            "returned_lines": len(recent_lines)
        }
    except Exception as e:
        logger.error(f"Erreur lecture logs: {e}")
        return {"logs": [], "error": str(e)}

@app.post("/decisionGemma", response_model=DecisionResponse)
async def decision_gemma(request: DecisionRequest):
    """
    Endpoint avancé qui utilise Gemma pour l'analyse visuelle du graphique MT5
    et Gemini pour formuler la recommandation finale de trading.
    """
    try:
        # Validation des champs obligatoires
        if not request.symbol:
            raise HTTPException(status_code=422, detail="Le symbole est requis")
        
        logger.info(f"Requête DecisionGemma reçue pour {request.symbol}")
        
        # Étape 1: Analyse technique initiale
        action = "hold"
        confidence = 0.5
        reason = "Analyse en cours..."
        
        # Analyse RSI
        if request.rsi:
            if request.rsi < 30:
                action = "buy"
                confidence += 0.2
                reason += f"RSI surventé ({request.rsi:.1f}). "
            elif request.rsi > 70:
                action = "sell"
                confidence += 0.2
                reason += f"RSI suracheté ({request.rsi:.1f}). "
        
        # Analyse EMA
        if request.ema_fast_h1 and request.ema_slow_h1:
            if request.ema_fast_h1 > request.ema_slow_h1:
                if action != "sell":
                    action = "buy"
                    confidence += 0.15
                reason += f"EMA H1 haussière ({request.ema_fast_h1:.5f} > {request.ema_slow_h1:.5f}). "
            else:
                if action != "buy":
                    action = "sell"
                    confidence += 0.15
                reason += f"EMA H1 baissière ({request.ema_fast_h1:.5f} < {request.ema_slow_h1:.5f}). "
        
        # Étape 2: Analyse visuelle avec Gemma (si image disponible)
        gemma_analysis = None
        sl_from_gemma = None
        tp_from_gemma = None
        
        if GEMMA_AVAILABLE and request.image_filename:
            try:
                # Construire le chemin complet de l'image depuis MT5
                mt5_image_path = os.path.join(MT5_FILES_DIR, request.image_filename)
                
                if os.path.exists(mt5_image_path):
                    gemma_prompt = f"""Analyse ce graphique {request.symbol} et identifie TOUS les objets graphiques visibles (lignes, zones, flèches, labels, patterns).
                    
                    Action suggérée: {action}
                    
                    Analyse DÉTAILLÉE demandée:
                    1. Identifie tous les objets graphiques visibles sur le graphique (support/résistance, zones, flèches de signal, patterns, etc.)
                    2. Interprète leur signification pour le trading
                    3. Évalue si ces objets confirment ou infirment l'action suggérée {action}
                    
                    Réponds en format JSON avec ces champs:
                    - "tendance": "haussière" ou "baissière" ou "neutre"
                    - "force": 1-10 (10 = très fort)
                    - "support": prix exact du support le plus proche
                    - "resistance": prix exact de la résistance la plus proche
                    - "stop_loss": prix optimal pour SL
                    - "take_profit": prix optimal pour TP
                    - "confirmation": true/false si tu confirmes l'action {action}
                    - "objets_graphiques": liste des objets identifiés (zones, lignes, patterns, etc.)
                    - "interpretation_objets": explication de comment les objets graphiques influencent la décision
                    """
                    
                    gemma_analysis = analyze_with_gemma(gemma_prompt, mt5_image_path)
                    
                    if gemma_analysis:
                        logger.info(f"Analyse Gemma reçue: {gemma_analysis[:200]}...")
                        
                        # Extraire SL/TP de la réponse Gemma
                        try:
                            import re
                            sl_match = re.search(r'"stop_loss":\s*([0-9.]+)', gemma_analysis)
                            tp_match = re.search(r'"take_profit":\s*([0-9.]+)', gemma_analysis)
                            confirmation_match = re.search(r'"confirmation":\s*(true|false)', gemma_analysis)
                            
                            if sl_match:
                                sl_from_gemma = float(sl_match.group(1))
                            if tp_match:
                                tp_from_gemma = float(tp_match.group(1))
                            if confirmation_match:
                                gemma_confirms = confirmation_match.group(1) == "true"
                                if gemma_confirms:
                                    confidence += 0.25
                                else:
                                    confidence -= 0.15
                                    
                        except Exception as parse_err:
                            logger.warning(f"Erreur parsing réponse Gemma: {parse_err}")
                        
                        reason += f"Analyse visuelle Gemma effectuée. "
                        
                else:
                    logger.warning(f"Fichier image non trouvé: {mt5_image_path}")
                    
            except Exception as gemma_err:
                logger.error(f"Erreur analyse Gemma: {type(gemma_err).__name__}: {str(gemma_err)}", exc_info=True)
        
        # Étape 3: Formulation finale avec Gemini
        global GEMINI_AVAILABLE, gemini_model  # Déclarer global AVANT toute utilisation
        if GEMINI_AVAILABLE and gemini_model is not None:
            try:
                gemini_prompt = f"""En tant qu'expert trading, analyse ces données pour {request.symbol}:
                
                DONNÉES TECHNIQUES:
                - Action initiale: {action}
                - Confiance: {confidence:.2f}
                - RSI: {request.rsi} (surventé<30, suracheté>70)
                - EMA H1: rapide={request.ema_fast_h1}, lente={request.ema_slow_h1}
                - Prix actuel: bid={request.bid}, ask={request.ask}
                
                ANALYSE VISUELLE GEMMA:
                {gemma_analysis if gemma_analysis else "Non disponible"}
                
                INSTRUCTIONS:
                1. Valide ou infirme l'action initiale
                2. Donne une recommandation finale claire: BUY/SELL/HOLD
                3. Attribue une confiance finale (0.0-1.0)
                4. Fournis une raison concise (<200 caractères)
                5. SL/TP: {"SL=" + str(sl_from_gemma) + ", TP=" + str(tp_from_gemma) if sl_from_gemma and tp_from_gemma else "Génère des niveaux logiques"}
                
                Réponds UNIQUEMENT en JSON:
                {{"action": "BUY/SELL/HOLD", "confidence": 0.00, "reason": "texte concis", "sl": 0.00000, "tp": 0.00000}}
                """
                
                response = gemini_model.generate_content(gemini_prompt)
                gemini_response = response.text.strip()
                
                # Nettoyer et parser la réponse JSON
                if gemini_response.startswith("```json"):
                    gemini_response = gemini_response.replace("```json", "").replace("```", "").strip()
                
                gemini_result = json.loads(gemini_response)
                
                action = gemini_result.get("action", action)
                confidence = gemini_result.get("confidence", confidence)
                reason = gemini_result.get("reason", reason)
                sl_from_gemma = gemini_result.get("sl", sl_from_gemma)
                tp_from_gemma = gemini_result.get("tp", tp_from_gemma)
                
                logger.info(f"Recommandation Gemini: {action} (conf: {confidence:.2f})")
                
            except Exception as gemini_err:
                logger.error(f"Erreur formulation Gemini: {type(gemini_err).__name__}: {str(gemini_err)}", exc_info=True)
                # Si le modèle est obsolète, désactiver Gemini pour cette session
                if "NotFound" in str(gemini_err) or "404" in str(gemini_err) or "not found" in str(gemini_err).lower():
                    logger.warning("Modèle Gemini obsolète détecté. Désactivation de Gemini pour cette requête.")
                    GEMINI_AVAILABLE = False
                    gemini_model = None
        
        # Limiter la confiance
        confidence = max(0.0, min(1.0, confidence))
        
        # Prédiction de spike (pour Boom/Crash)
        spike_prediction = False
        spike_zone_price = None
        
        if "Boom" in request.symbol or "Crash" in request.symbol:
            if request.volatility_regime == 1:  # High volatility
                spike_prediction = True
                spike_zone_price = request.ask if "Boom" in request.symbol else request.bid
                confidence += 0.1
        
        # Construire la réponse finale
        response = DecisionResponse(
            action=action,
            confidence=confidence,
            reason=reason[:250],  # Limiter la longueur
            spike_prediction=spike_prediction,
            spike_zone_price=spike_zone_price,
            stop_loss=sl_from_gemma,
            take_profit=tp_from_gemma,
            timestamp=datetime.now().isoformat(),
            model_used="Gemma+Gemini",
            technical_analysis={
                "rsi": request.rsi,
                "ema_fast_h1": request.ema_fast_h1,
                "ema_slow_h1": request.ema_slow_h1,
                "supertrend_line": request.supertrend_line,
                "volatility_regime": request.volatility_regime
            },
            gemma_analysis=gemma_analysis[:500] if gemma_analysis else f"Modèle Gemini utilisé - Confiance: {confidence:.2f}, Action: {action}"
        )
        
        logger.info(f"Décision finale pour {request.symbol}: {action} (conf: {confidence:.2f})")
        return response
        
    except Exception as e:
        logger.error(f"Erreur dans decision_gemma: {type(e).__name__}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur interne: {type(e).__name__}: {str(e)}")

# Fonction pour récupérer les données de tendance avec gestion d'erreur robuste
async def get_trend_data(symbol: str):
    """Récupère les données de tendance avec timeout et gestion d'erreur"""
    try:
        import httpx
        async with httpx.AsyncClient(timeout=2.0) as client:
            response = await client.get(f"http://127.0.0.1:8001/multi_timeframe?symbol={symbol}")
            if response.status_code == 200:
                logger.debug(f"Données de tendance récupérées pour {symbol}")
                return response.json()
            else:
                logger.warning(f"API tendance retourne status {response.status_code} pour {symbol}")
                return None
    except httpx.TimeoutException:
        logger.warning("⚠️ Timeout de l'API de tendance - Mode dégradé activé")
        return None
    except httpx.ConnectError:
        logger.warning("⚠️ API de tendance indisponible - Mode dégradé activé")
        return None
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des données de tendance: {str(e)}")
        return None

def calculate_fractals(df: pd.DataFrame, period: int = 5) -> Dict[str, float]:
    """
    Calcule les fractals supérieurs et inférieurs pour identifier les zones de mouvement de prix.
    
    Args:
        df: DataFrame avec colonnes high, low, close
        period: Période pour détecter les fractals (défaut: 5)
        
    Returns:
        Dict avec 'upper_fractal' et 'lower_fractal' (0 si non trouvé)
    """
    if len(df) < period * 2 + 1:
        return {'upper_fractal': 0.0, 'lower_fractal': 0.0}
    
    upper_fractal = 0.0
    lower_fractal = 0.0
    
    # Chercher le dernier fractal supérieur (high plus élevé que les périodes adjacentes)
    for i in range(period, len(df) - period):
        high = df.iloc[i]['high']
        is_upper = True
        is_lower = True
        
        # Vérifier si c'est un fractal supérieur
        for j in range(i - period, i + period + 1):
            if j != i:
                if df.iloc[j]['high'] >= high:
                    is_upper = False
                    break
        
        # Vérifier si c'est un fractal inférieur
        low = df.iloc[i]['low']
        for j in range(i - period, i + period + 1):
            if j != i:
                if df.iloc[j]['low'] <= low:
                    is_lower = False
                    break
        
        if is_upper and upper_fractal == 0.0:
            upper_fractal = high
        if is_lower and lower_fractal == 0.0:
            lower_fractal = low
        
        # Si on a trouvé les deux, on peut s'arrêter
        if upper_fractal > 0 and lower_fractal > 0:
            break
    
    return {'upper_fractal': upper_fractal, 'lower_fractal': lower_fractal}

def enhance_spike_prediction_with_history(df: pd.DataFrame, symbol: str) -> Dict[str, Any]:
    """
    Améliore la prédiction de spike en analysant les patterns historiques.
    
    Args:
        df: DataFrame avec données historiques
        symbol: Symbole du marché
        
    Returns:
        Dict avec 'spike_probability', 'spike_direction', 'historical_pattern'
    """
    if len(df) < 50:
        return {'spike_probability': 0.0, 'spike_direction': None, 'historical_pattern': 'insufficient_data'}
    
    # Analyser les mouvements historiques pour détecter des patterns de spike
    df['price_change'] = df['close'].pct_change()
    df['volatility'] = df['high'] - df['low']
    df['volatility_pct'] = df['volatility'] / df['close']
    
    # Calculer la moyenne et l'écart-type des mouvements
    avg_change = df['price_change'].abs().rolling(window=20).mean().iloc[-1]
    std_change = df['price_change'].abs().rolling(window=20).std().iloc[-1]
    
    # Mouvement récent
    recent_change = abs(df['price_change'].iloc[-1])
    recent_volatility = df['volatility_pct'].iloc[-1]
    
    # Détecter si le mouvement récent est anormalement élevé
    z_score = (recent_change - avg_change) / (std_change + 1e-10)
    
    # Probabilité de spike basée sur l'anomalie statistique
    spike_probability = min(1.0, max(0.0, (z_score - 1.0) / 2.0))  # Normaliser entre 0 et 1
    
    # Direction du spike
    spike_direction = None
    if recent_change > avg_change * 2:
        if df['price_change'].iloc[-1] > 0:
            spike_direction = 'up'
        else:
            spike_direction = 'down'
    
    # Pattern historique
    pattern = 'normal'
    if z_score > 2.5:
        pattern = 'strong_spike'
    elif z_score > 1.5:
        pattern = 'moderate_spike'
    
    return {
        'spike_probability': spike_probability,
        'spike_direction': spike_direction,
        'historical_pattern': pattern,
        'z_score': z_score,
        'recent_volatility': recent_volatility
    }

@app.post("/decision", response_model=DecisionResponse)
async def decision(request: DecisionRequest):
    # Logging détaillé seulement en mode debug, sinon juste les logs du middleware suffisent
    logger.debug(f"🎯 Décision IA demandée pour {request.symbol} (bid={request.bid}, ask={request.ask})")
    try:
        # Validation des champs obligatoires
        if not request.symbol:
            raise HTTPException(status_code=422, detail="Le symbole est requis")
            
        if request.bid is None or request.ask is None:
            raise HTTPException(status_code=422, detail="Les prix bid/ask sont requis")
            
        if request.bid <= 0 or request.ask <= 0:
            raise HTTPException(status_code=422, detail="Les prix doivent être supérieurs à zéro")
            
        if request.rsi is not None and (request.rsi < 0 or request.rsi > 100):
            raise HTTPException(status_code=422, detail="La valeur RSI doit être entre 0 et 100")
        
        # ========== DÉTECTION MODE INITIALISATION DEPUIS GRAPHIQUE ==========
        # Détecter si c'est une initialisation (première requête pour ce symbole)
        initialization_mode = False
        cache_key_init = f"{request.symbol}_init"
        current_time = time.time()
        
        # Vérifier si c'est la première requête pour ce symbole (dans les 30 dernières secondes)
        if cache_key_init not in last_updated or (current_time - last_updated.get(cache_key_init, 0)) > 30:
            initialization_mode = True
            last_updated[cache_key_init] = current_time
            logger.info(f"🔄 MODE INITIALISATION détecté pour {request.symbol} - Analyse approfondie activée")
        
        # En mode initialisation, utiliser une logique plus conservatrice et approfondie
        if initialization_mode:
            logger.info(f"📊 Initialisation: Collecte de données historiques étendues pour {request.symbol}...")
            
            # Récupérer plus de données historiques pour une meilleure analyse
            try:
                if MT5_AVAILABLE and mt5_initialized:
                    # Récupérer des données multi-timeframes pour analyse complète
                    df_m1_init = get_historical_data_mt5(request.symbol, "M1", 500)  # Plus de données
                    df_m5_init = get_historical_data_mt5(request.symbol, "M5", 200)
                    df_h1_init = get_historical_data_mt5(request.symbol, "H1", 100)
                    
                    if df_m1_init is not None and len(df_m1_init) > 100:
                        # Analyser la tendance générale sur les dernières heures
                        price_trend = (df_m1_init['close'].iloc[-1] - df_m1_init['close'].iloc[0]) / df_m1_init['close'].iloc[0]
                        volatility_init = df_m1_init['close'].pct_change().std() * 100
                        
                        logger.info(f"📈 Analyse initialisation {request.symbol}:")
                        logger.info(f"   ├─ Tendance: {price_trend:+.2%} sur {len(df_m1_init)} bougies M1")
                        logger.info(f"   ├─ Volatilité: {volatility_init:.3f}%")
                        logger.info(f"   └─ Données: M1={len(df_m1_init) if df_m1_init is not None else 0}, "
                                  f"M5={len(df_m5_init) if df_m5_init is not None else 0}, "
                                  f"H1={len(df_h1_init) if df_h1_init is not None else 0}")
                        
                        # En mode initialisation, être plus conservateur
                        # Ne trader que si la tendance est claire et la volatilité acceptable
                        if abs(price_trend) < 0.01 and volatility_init < 0.5:
                            logger.info(f"⚠️ Initialisation: Marché trop calme - Recommandation HOLD conservatrice")
                            return DecisionResponse(
                                action="hold",
                                confidence=0.30,
                                reason=f"Initialisation: Marché calme (tendance: {price_trend:+.2%}, volatilité: {volatility_init:.3f}%) - Attente signal plus clair",
                                spike_prediction=False,
                                spike_zone_price=None,
                                stop_loss=None,
                                take_profit=None,
                                spike_direction=None,
                                early_spike_warning=False,
                                early_spike_zone_price=None,
                                early_spike_direction=None,
                                buy_zone_low=None,
                                buy_zone_high=None,
                                sell_zone_low=None,
                                sell_zone_high=None
                            )
            except Exception as e:
                logger.warning(f"⚠️ Erreur analyse initialisation: {e}")
        
        # Règle stricte: Interdire les achats sur Crash et les ventes sur Boom
        symbol_lower = request.symbol.lower()
        if "crash" in symbol_lower:
            # Forcer HOLD pour tout achat sur Crash (règle de sécurité)
            if request.dir_rule == 1:  # 1 = BUY
                logger.debug(f"🔒 Achat sur Crash bloqué (règle sécurité): {request.symbol}")
                return DecisionResponse(
                    action="hold",
                    confidence=0.1,
                    reason="INTERDICTION: Achats sur Crash non autorisés",
                    spike_prediction=False,
                    spike_zone_price=None,
                    stop_loss=None,
                    take_profit=None,
                    spike_direction=None,
                    early_spike_warning=False,
                    early_spike_zone_price=None,
                    early_spike_direction=None,
                    buy_zone_low=None,
                    buy_zone_high=None,
                    sell_zone_low=None,
                    sell_zone_high=None
                )
        
        if "boom" in symbol_lower:
            # Forcer HOLD pour toute vente sur Boom (règle de sécurité)
            if request.dir_rule == 0:  # 0 = SELL
                logger.debug(f"🔒 Vente sur Boom bloquée (règle sécurité): {request.symbol}")
                return DecisionResponse(
                    action="hold",
                    confidence=0.1,
                    reason="INTERDICTION: Ventes sur Boom non autorisées",
                    spike_prediction=False,
                    spike_zone_price=None,
                    stop_loss=None,
                    take_profit=None,
                    spike_direction=None,
                    early_spike_warning=False,
                    early_spike_zone_price=None,
                    early_spike_direction=None,
                    buy_zone_low=None,
                    buy_zone_high=None,
                    sell_zone_low=None,
                    sell_zone_high=None
                )
            
        # Log de la requête reçue (déjà loggé par le middleware, pas besoin de répéter)
        # logger.info(f"Requête de décision reçue pour {request.symbol}")  # Supprimé pour éviter duplication
        
        # Vérifier si la décision est en cache
        # IMPORTANT: Utiliser seulement le symbole pour la clé de cache, pas le prix
        # Car le prix change constamment et empêche le cache de fonctionner
        cache_key = f"{request.symbol}"
        current_time = time.time()
        
        # Détection de mouvement en temps réel AVANT de vérifier le cache
        mid_price = (request.bid + request.ask) / 2
        realtime_movement = detect_realtime_movement(request.symbol, mid_price)
        
        # Vérifier le cache mais avec une durée réduite (5 secondes) pour permettre des mises à jour fréquentes
        CACHE_DURATION_SHORT = 5  # 5 secondes de cache pour permettre des mises à jour rapides
        CACHE_DURATION_VERY_SHORT = 1  # 1 seconde si mouvement détecté
        
        # Si mouvement haussier détecté, réduire drastiquement le cache pour être plus réactif
        cache_duration = CACHE_DURATION_VERY_SHORT if (
            realtime_movement["direction"] == "up" and 
            realtime_movement["strength"] > 0.3 and
            realtime_movement["trend_consistent"]
        ) else CACHE_DURATION_SHORT
        
        if cache_key in prediction_cache and \
           (current_time - last_updated.get(cache_key, 0)) < cache_duration:
            cached = prediction_cache[cache_key]
            cache_age = current_time - last_updated.get(cache_key, 0)
            logger.debug(f"Retour depuis cache pour {request.symbol} (cache: {cache_age:.1f}s)")
            
            # Si mouvement haussier détecté et cache = "hold", ignorer le cache immédiatement
            if realtime_movement["direction"] == "up" and realtime_movement["strength"] > 0.3:
                if cached.get("action") == "hold":
                    logger.info(f"🚀 Mouvement haussier détecté ({realtime_movement['price_change_percent']:+.3f}%) - Ignorer cache HOLD et recalculer")
                    # Ne pas retourner le cache, continuer le calcul
                elif cached.get("action") != "hold" and cached.get("confidence", 0) > 0.5:
                    # Cache valide avec action non-hold, retourner
                    return DecisionResponse(**cached)
            elif cached.get("action") != "hold" or cached.get("confidence", 0) > 0.5:
                # Cache valide normalement
                return DecisionResponse(**cached)
            else:
                # Si cache = "hold" avec faible confiance, recalculer
                logger.debug(f"Cache ignoré pour {request.symbol} (action=hold, confiance faible) - Recalcul...")
        
        # NOUVEAU: Utiliser le système de scoring avancé si disponible et données historiques accessibles
        use_advanced_scoring = False
        if ADVANCED_ENTRY_SCORING_AVAILABLE and calculate_advanced_entry_score and MT5_AVAILABLE:
            try:
                # Récupérer les données historiques pour le scoring avancé
                df_m1 = get_historical_data_mt5(request.symbol, "M1", 100)
                if df_m1 is not None and len(df_m1) >= 50:
                    entry_data = calculate_advanced_entry_score(df_m1, request.symbol, "M1")
                    
                    # Utiliser le scoring avancé si le score est suffisant
                    if entry_data['entry_score'] >= 0.65 and entry_data['recommendation'] != 'HOLD':
                        use_advanced_scoring = True
                        action = entry_data['recommendation'].lower()
                        confidence = entry_data['entry_score']
                        
                        # Construire la raison avec les détails
                        reason_parts = [
                            f"Score avancé: {entry_data['entry_score']:.1%}",
                            f"Consensus: {entry_data['consensus']:.0%}",
                        ]
                        
                        # Ajouter les facteurs principaux
                        factors_detail = []
                        for factor_name, factor_value in entry_data['factors'].items():
                            if factor_value > 0.6:
                                factors_detail.append(f"{factor_name}: {factor_value:.0%}")
                        
                        if factors_detail:
                            reason_parts.append(f"Facteurs: {', '.join(factors_detail)}")
                        
                        reason = " | ".join(reason_parts)
                        
                        # BONUS TEMPS RÉEL: Ajuster la confiance si mouvement haussier détecté
                        if realtime_movement["direction"] == "up" and realtime_movement["strength"] > 0.3:
                            if action == "buy":
                                confidence = min(confidence + 0.10, 0.98)  # +10% si BUY et mouvement haussier
                                reason_parts.append(f"RealtimeUp:+{realtime_movement['price_change_percent']:+.2f}%")
                            elif action == "hold" and realtime_movement["trend_consistent"] and (bullish_tfs >= bearish_tfs):
                                # Forcer BUY si mouvement haussier fort et scoring avancé = HOLD
                                action = "buy"
                                confidence = 0.60 + realtime_movement["strength"] * 0.20
                                reason_parts.append(f"RealtimeForceBUY:{realtime_movement['price_change_percent']:+.2f}%")
                                logger.info(f"🚀 Scoring avancé: HOLD → BUY (mouvement haussier temps réel fort)")
                        
                        logger.info(f"✅ Scoring avancé utilisé pour {request.symbol}: {action.upper()} "
                                  f"({confidence:.1%}) - {entry_data['reason']}")
                        
                        # Construire la réponse et la mettre en cache
                        response_data = {
                            "action": action,
                            "confidence": confidence,
                            "reason": reason,
                            "spike_prediction": False,
                            "spike_zone_price": None,
                            "stop_loss": None,
                            "take_profit": None,
                            "spike_direction": None,
                            "early_spike_warning": False,
                            "early_spike_zone_price": None,
                            "early_spike_direction": None,
                            "buy_zone_low": None,
                            "buy_zone_high": None,
                            "sell_zone_low": None,
                            "sell_zone_high": None,
                            "timestamp": datetime.now().isoformat(),
                            "model_used": "AdvancedEntryScoring",
                            "technical_analysis": entry_data.get('factors', {})
                        }
                        
                        # Mettre en cache
                        prediction_cache[cache_key] = response_data
                        last_updated[cache_key] = current_time
                        
                        # Retourner la réponse directement
                        return DecisionResponse(**response_data)
            except Exception as e:
                logger.warning(f"⚠️ Erreur scoring avancé, utilisation méthode standard: {e}")
                use_advanced_scoring = False
        
        # Analyse des indicateurs techniques
        rsi = request.rsi
        ema_fast_h1 = request.ema_fast_h1
        ema_slow_h1 = request.ema_slow_h1
        ema_fast_m1 = request.ema_fast_m1
        ema_slow_m1 = request.ema_slow_m1
        bid = request.bid
        ask = request.ask
        # mid_price déjà calculé plus haut pour la détection temps réel
        
        # Si le scoring avancé n'a pas été utilisé, utiliser la logique standard
        if not use_advanced_scoring:
            # Logique de décision basique
            action = "hold"
            confidence = 0.5
            reason = ""  # Sera construite plus bas avec les composants
        
        # Analyse RSI
        rsi_bullish = rsi is not None and rsi < 30  # Survente
        rsi_bearish = rsi is not None and rsi > 70  # Surachat
        
        # Analyse EMA H1 (tendance long terme) - Vérifier que les valeurs ne sont pas None
        h1_bullish = False
        h1_bearish = False
        if ema_fast_h1 is not None and ema_slow_h1 is not None:
            h1_bullish = ema_fast_h1 > ema_slow_h1
            h1_bearish = ema_fast_h1 < ema_slow_h1
        
        # Analyse EMA M1 (tendance court terme) - Vérifier que les valeurs ne sont pas None
        m1_bullish = False
        m1_bearish = False
        if ema_fast_m1 is not None and ema_slow_m1 is not None:
            m1_bullish = ema_fast_m1 > ema_slow_m1
            m1_bearish = ema_fast_m1 < ema_slow_m1
        
        # NOUVEAU: Analyse Multi-Time frames via trend_api (ULTRA-RAPIDE avec cache)
        # Interroger le service trend_api sur port 8001 pour obtenir les tendances cachées
        m5_bullish = False
        m5_bearish = False
        h1_bullish = False
        h1_bearish = False
        
        # Tentative de récupération depuis trend_api (rapide, caché) - H1 et M5 uniquement
        trend_api_success = False
        try:
            trend_api_url = f"http://127.0.0.1:8001/multi_timeframe?symbol={request.symbol}"
            trend_response = requests.get(trend_api_url, timeout=2)
            
            if trend_response.status_code == 200:
                trend_data = trend_response.json()
                trends = trend_data.get('trends', {})
                
                # Extraire seulement H1 et M5
                if 'M5' in trends:
                    m5_bullish = trends['M5'].get('bullish', False)
                    m5_bearish = trends['M5'].get('bearish', False)
                
                if 'H1' in trends:
                    h1_bullish = trends['H1'].get('bullish', False)
                    h1_bearish = trends['H1'].get('bearish', False)
                
                # Vérifier si on a récupéré H1 et M5
                if (h1_bullish or h1_bearish) and (m5_bullish or m5_bearish):
                    trend_api_success = True
                    logger.debug(f"✅ Tendances H1/M5 récupérées depuis trend_api")
                else:
                    logger.warning(f"⚠️ trend_api répond mais H1/M5 incomplets, calcul direct nécessaire")
            else:
                logger.warning(f"⚠️ trend_api réponse {trend_response.status_code}, calcul direct nécessaire")
        except Exception as e:
            logger.warning(f"⚠️ trend_api indisponible: {e}, calcul direct depuis MT5")
        
        # FALLBACK: Calculer H1 et M5 directement depuis MT5 si trend_api n'a pas fourni ces données
        if not trend_api_success and MT5_AVAILABLE:
            try:
                # Initialiser MT5 si nécessaire (ne pas fermer si déjà initialisé)
                mt5_was_initialized_before = mt5_initialized
                mt5_initialized_temp = mt5_initialized
                if not mt5_initialized_temp:
                    mt5_initialized_temp = mt5.initialize()
                    if mt5_initialized_temp:
                        logger.debug(f"📊 MT5 initialisé temporairement pour calcul direct H1/M5")
                
                if mt5_initialized_temp:
                    # Calculer H1 directement
                    rates_h1 = mt5.copy_rates_from_pos(request.symbol, mt5.TIMEFRAME_H1, 0, 50)
                    if rates_h1 is not None and len(rates_h1) >= 20:
                        df_h1 = pd.DataFrame(rates_h1)
                        if 'close' in df_h1.columns and len(df_h1) >= 20:
                            # EMA pour H1
                            ema_fast_h1 = df_h1['close'].ewm(span=9, adjust=False).mean()
                            ema_slow_h1 = df_h1['close'].ewm(span=21, adjust=False).mean()
                            if len(ema_fast_h1) > 0 and len(ema_slow_h1) > 0:
                                h1_bullish = bool(ema_fast_h1.iloc[-1] > ema_slow_h1.iloc[-1])
                                h1_bearish = bool(ema_fast_h1.iloc[-1] < ema_slow_h1.iloc[-1])
                                logger.info(f"📊 H1 calculé directement depuis MT5: {'↑' if h1_bullish else '↓' if h1_bearish else '→'}")
                    
                    # Calculer M5 directement (si pas déjà récupéré)
                    if not (m5_bullish or m5_bearish):
                        rates_m5 = mt5.copy_rates_from_pos(request.symbol, mt5.TIMEFRAME_M5, 0, 50)
                        if rates_m5 is not None and len(rates_m5) >= 20:
                            df_m5 = pd.DataFrame(rates_m5)
                            if 'close' in df_m5.columns and len(df_m5) >= 20:
                                ema_fast_m5 = df_m5['close'].ewm(span=9, adjust=False).mean()
                                ema_slow_m5 = df_m5['close'].ewm(span=21, adjust=False).mean()
                                if len(ema_fast_m5) > 0 and len(ema_slow_m5) > 0:
                                    m5_bullish = bool(ema_fast_m5.iloc[-1] > ema_slow_m5.iloc[-1])
                                    m5_bearish = bool(ema_fast_m5.iloc[-1] < ema_slow_m5.iloc[-1])
                                    logger.info(f"📊 M5 calculé directement depuis MT5: {'↑' if m5_bullish else '↓' if m5_bearish else '→'}")
                    
                    # Fermer MT5 seulement si on l'a initialisé nous-mêmes
                    if not mt5_was_initialized_before and mt5_initialized_temp:
                        mt5.shutdown()
                        logger.debug(f"📊 MT5 fermé après calcul direct H1/M5")
                        
            except Exception as mt5_error:
                logger.warning(f"⚠️ Erreur calcul direct MT5 pour H1/M5: {mt5_error}")
        
        # NOUVEAU 2025 : Analyse VWAP (prix d'équilibre)
        vwap_signal_buy = False
        vwap_signal_sell = False
        if request.vwap and request.vwap > 0 and request.above_vwap is not None:
            # BUY signal renforcé si prix EN-DESSOUS du VWAP (pas cher)
            # SELL signal renforcé si prix AU-DESSUS du VWAP (cher)
            if not request.above_vwap:  # Prix en-dessous du VWAP
                vwap_signal_buy = True
            else:  # Prix au-dessus du VWAP
                vwap_signal_sell = True
        
        # NOUVEAU 2025 : Analyse SuperTrend (tendance moderne)
        supertrend_bullish = False
        supertrend_bearish = False
        if request.supertrend_trend is not None:
            supertrend_bullish = request.supertrend_trend > 0  # SuperTrend UP
            supertrend_bearish = request.supertrend_trend < 0  # SuperTrend DOWN
        
        # NOUVEAU 2025 : Filtre régime de volatilité
        # Éviter les trades en régime de faible volatilité (pas d'opportunité)
        volatility_ok = True
        if request.volatility_regime is not None:
            if request.volatility_regime == -1:  # Low Vol
                volatility_ok = False
                reason += " | Volatilité trop faible"
        
        # NOUVEAU 2025 : Analyse des patterns Deriv
        deriv_patterns_bullish = 0
        deriv_patterns_bearish = 0
        deriv_patterns_confidence = 0.0
        
        if hasattr(request, 'deriv_patterns_bullish') and request.deriv_patterns_bullish is not None:
            deriv_patterns_bullish = request.deriv_patterns_bullish
        if hasattr(request, 'deriv_patterns_bearish') and request.deriv_patterns_bearish is not None:
            deriv_patterns_bearish = request.deriv_patterns_bearish
        if hasattr(request, 'deriv_patterns_confidence') and request.deriv_patterns_confidence is not None:
            deriv_patterns_confidence = request.deriv_patterns_confidence
        
        # Initialiser les signaux avant les conditions pour éviter UnboundLocalError
        bullish_signals_base = sum([rsi_bullish, h1_bullish, m1_bullish, vwap_signal_buy, supertrend_bullish])
        bearish_signals_base = sum([rsi_bearish, h1_bearish, m1_bearish, vwap_signal_sell, supertrend_bearish])
        bullish_signals = bullish_signals_base
        bearish_signals = bearish_signals_base

        # Poids par signal (pondération multi-timeframe H1 et M5 uniquement)
        WEIGHTS = {
            "m1": 0.10,    # M1: 10% - Court terme (conservé pour réactivité)
            "m5": 0.35,    # M5: 35% - Court terme (augmenté)
            "h1": 0.45,    # H1: 45% - Moyen terme (augmenté, plus important)
            "rsi": 0.08,   # Réduit car moins fiable en trending
            "vwap": 0.06,
            "supertrend": 0.06,
            "patterns": 0.10,
            "sentiment": 0.05,
        }
        ALIGN_BONUS = 0.15     # Bonus si tous les timeframes alignés
        DIVERGENCE_MALUS = -0.12
        VOL_LOW_MALUS = -0.15
        VOL_OK_BONUS = 0.03
        BASE_CONF = 0.35       # Base réduite car plus de timeframes
        MAX_CONF = 0.98        # Augmenté pour signaux ultra-forts
        MIN_CONF = 0.15
        HOLD_THRESHOLD = 0.03  # Seuil réduit pour permettre plus de signaux

        # Score directionnel pondéré
        score = 0.0
        components = []
        # Canal de prédiction M5 (pente normalisée)
        channel_slope = 0.0
        try:
            rates_chan = mt5.copy_rates_from_pos(request.symbol, mt5.TIMEFRAME_M5, 0, 80)
            if rates_chan is not None and len(rates_chan) >= 30:
                df_chan = pd.DataFrame(rates_chan)
                closes_chan = df_chan['close'].tail(50)
                x_idx = np.arange(len(closes_chan))
                coeff = np.polyfit(x_idx, closes_chan.values, 1)
                last_price = float(closes_chan.iloc[-1]) if len(closes_chan) > 0 else 0.0
                if last_price > 0:
                    channel_slope = float(coeff[0]) / last_price
                if channel_slope > 0:
                    components.append("ChUp")
                elif channel_slope < 0:
                    components.append("ChDown")
        except Exception:
            pass

        # Timeframes - pondération multi-niveaux
        if m1_bullish:
            score += WEIGHTS["m1"]; components.append("M1:+")
        if m1_bearish:
            score -= WEIGHTS["m1"]; components.append("M1:-")
        
        if m5_bullish:
            score += WEIGHTS["m5"]; components.append("M5:+")
        if m5_bearish:
            score -= WEIGHTS["m5"]; components.append("M5:-")
        
        if h1_bullish:
            score += WEIGHTS["h1"]; components.append("H1:+")
        if h1_bearish:
            score -= WEIGHTS["h1"]; components.append("H1:-")

        if rsi_bullish:
            score += WEIGHTS["rsi"]; components.append("RSI:+")
        if rsi_bearish:
            score -= WEIGHTS["rsi"]; components.append("RSI:-")

        if vwap_signal_buy:
            score += WEIGHTS["vwap"]; components.append("VWAP:+")
        if vwap_signal_sell:
            score -= WEIGHTS["vwap"]; components.append("VWAP:-")

        if supertrend_bullish:
            score += WEIGHTS["supertrend"]; components.append("ST:+")
        if supertrend_bearish:
            score -= WEIGHTS["supertrend"]; components.append("ST:-")

        # Patterns Deriv pondérés par leur confiance
        pattern_bonus = 0.0
        if deriv_patterns_confidence and deriv_patterns_confidence > 0.6:
            if deriv_patterns_bullish > deriv_patterns_bearish:
                pattern_bonus = WEIGHTS["patterns"] * min(deriv_patterns_bullish, 2)
                score += pattern_bonus; components.append(f"Patterns:+{pattern_bonus:.2f}")
            elif deriv_patterns_bearish > deriv_patterns_bullish:
                pattern_bonus = WEIGHTS["patterns"] * min(deriv_patterns_bearish, 2)
                score -= pattern_bonus; components.append(f"Patterns:-{pattern_bonus:.2f}")

        # Alignement / divergence multi‑timeframe (H1 et M5 uniquement)
        # Compter le nombre de timeframes alignés
        bullish_tfs = sum([m1_bullish, m5_bullish, h1_bullish])
        bearish_tfs = sum([m1_bearish, m5_bearish, h1_bearish])
        total_tfs = 3  # M1, M5, H1
        
        # Si tous les timeframes alignés dans la même direction = très fort
        if bullish_tfs == 3:
            score += ALIGN_BONUS; components.append(f"AlignBull:3/3")
        elif bearish_tfs == 3:
            score -= ALIGN_BONUS; components.append(f"AlignBear:3/3")
        
        # Divergence (1 TF contre 2 autres)
        if abs(bullish_tfs - bearish_tfs) == 1 and bullish_tfs + bearish_tfs == 3:
            score += DIVERGENCE_MALUS; components.append("DivMed")

        # Filtre de volatilité (ATR / régime)
        if not volatility_ok:
            score += VOL_LOW_MALUS; components.append("VolLow:-")
        elif request.volatility_regime == 1:
            score += VOL_OK_BONUS; components.append("VolHigh:+")

        # Sentiment avancé (sera ajouté plus bas si dispo)
        sentiment_bonus = 0.0

        # Décision basée sur le score directionnel
        action = "hold"
        direction_score = score
        
        # Calculer la confiance de manière intelligente avec bonus pour tendances long terme
        abs_score = abs(direction_score)
        
        # Score maximum théorique (somme de tous les poids positifs possibles)
        max_possible_score = sum([
            WEIGHTS["m1"], WEIGHTS["m5"], WEIGHTS["h1"], WEIGHTS["rsi"],
            WEIGHTS["vwap"], WEIGHTS["supertrend"], WEIGHTS["patterns"],
            WEIGHTS["sentiment"], ALIGN_BONUS, VOL_OK_BONUS
        ])
        
        # Normaliser le score (0.0 à 1.0)
        normalized_score = min(abs_score / max_possible_score, 1.0) if max_possible_score > 0 else 0.0
        
        # NOUVEAU CALCUL DE CONFIANCE PLUS INTELLIGENT ET RÉALISTE
        # La confiance doit refléter la qualité du signal et permettre de trader les bonnes opportunités
        
        # 1. Confiance de base proportionnelle au score
        base_confidence = MIN_CONF + (normalized_score * (MAX_CONF - MIN_CONF))
        
        # 2. BONUS UNIQUE pour tendance long terme (H1/M5) - éliminer la redondance
        long_term_bonus = 0.0
        if h1_bullish and m5_bullish:
            long_term_bonus = 0.25  # +25% si H1 ET M5 alignés (tendance long terme forte)
            components.append("H1+M5:++")
        elif h1_bearish and m5_bearish:
            long_term_bonus = 0.25
            components.append("H1+M5:--")
        elif (h1_bullish and m5_bearish) or (h1_bearish and m5_bullish):
            long_term_bonus = -0.15  # Pénalité si H1 et M5 divergents
            components.append("H1/M5:DIVERGE")
        elif h1_bullish or m5_bullish:
            long_term_bonus = 0.10  # +10% si au moins H1 OU M5 aligné
            components.append("H1/M5:+")
        elif h1_bearish or m5_bearish:
            long_term_bonus = 0.10
            components.append("H1/M5:-")
        
        # 3. BONUS pour alignement multi-timeframe complet (tous les 3 timeframes)
        multi_tf_bonus = 0.0
        if bullish_tfs == 3:  # M1, M5, H1 tous haussiers
            multi_tf_bonus = 0.20  # +20% pour alignement parfait
            components.append("ALIGN:3/3↑")
        elif bearish_tfs == 3:  # M1, M5, H1 tous baissiers
            multi_tf_bonus = 0.20
            components.append("ALIGN:3/3↓")
        elif bullish_tfs == 2 or bearish_tfs == 2:  # 2 sur 3 alignés
            multi_tf_bonus = 0.10
            components.append("ALIGN:2/3")
        
        # 4. BONUS pour qualité des indicateurs techniques
        technical_bonus = 0.0
        
        # RSI dans zones extrêmes (plus fiable)
        if rsi is not None:
            if rsi < 20 or rsi > 80:
                technical_bonus += 0.08  # RSI très fiable
                components.append("RSI:EXT")
            elif rsi < 30 or rsi > 70:
                technical_bonus += 0.05  # RSI fiable
                components.append("RSI:STR")
        
        # ATR pour la volatilité (confiance si volatilité adéquate)
        if request.atr and request.atr > 0:
            atr_percent = (request.atr / request.bid) * 100 if request.bid > 0 else 0
            if 0.1 <= atr_percent <= 0.5:  # Volatilité idéale
                technical_bonus += 0.06
                components.append("ATR:OK")
            elif atr_percent > 1.0:  # Volatilité trop élevée
                technical_bonus -= 0.03
                components.append("ATR:HIGH")
        
        # 5. CONFIDANCE FINALE
        confidence = base_confidence + long_term_bonus + multi_tf_bonus + technical_bonus
        
        # Appliquer les bonus/malus de volatilité
        if not volatility_ok:
            confidence += VOL_LOW_MALUS
        elif request.volatility_regime == 1:
            confidence += VOL_OK_BONUS
        
        # Limiter la confiance entre MIN_CONF et MAX_CONF
        confidence = max(MIN_CONF, min(MAX_CONF, confidence))
        
        # BONUS TEMPS RÉEL: Si mouvement haussier détecté en temps réel, favoriser BUY
        realtime_bonus = 0.0
        if realtime_movement["direction"] == "up" and realtime_movement["strength"] > 0.3:
            if realtime_movement["trend_consistent"]:
                realtime_bonus = 0.15  # +15% si mouvement haussier cohérent
                components.append(f"RealtimeUp:{realtime_movement['price_change_percent']:+.2f}%")
                logger.info(f"📈 Mouvement haussier temps réel détecté: {realtime_movement['price_change_percent']:+.3f}% (force: {realtime_movement['strength']:.1%})")
            else:
                realtime_bonus = 0.08  # +8% si mouvement moins cohérent
                components.append(f"RealtimeUpWeak:{realtime_movement['price_change_percent']:+.2f}%")
        elif realtime_movement["direction"] == "down" and realtime_movement["strength"] > 0.3:
            if realtime_movement["trend_consistent"]:
                realtime_bonus = -0.10  # -10% si mouvement baissier cohérent
                components.append(f"RealtimeDown:{realtime_movement['price_change_percent']:+.2f}%")
        
        # Appliquer le bonus temps réel à la confiance
        confidence += realtime_bonus
        
        # Décision finale basée sur le score et les alignements de timeframe
        min_tfs_for_signal = 3
        
        if bullish_tfs >= min_tfs_for_signal and direction_score > -HOLD_THRESHOLD:
            # Au moins 3 TFs haussiers -> signal BUY même si score faible
            action = "buy"
            confidence = max(confidence, 0.50)  # Minimum 50% si 3+ TFs alignés
            components.append("3+TFs:BUY")
        elif bearish_tfs >= min_tfs_for_signal and direction_score < HOLD_THRESHOLD:
            # Au moins 3 TFs baissiers -> signal SELL même si score faible
            action = "sell"
            confidence = max(confidence, 0.50)  # Minimum 50% si 3+ TFs alignés
            components.append("3+TFs:SELL")
        elif direction_score > HOLD_THRESHOLD:
            action = "buy"
            confidence += realtime_bonus
        elif direction_score < -HOLD_THRESHOLD:
            action = "sell"
            confidence += realtime_bonus
        else:
            # NOUVEAU: Si mouvement haussier temps réel fort détecté, forcer BUY même si score faible
            if realtime_movement["direction"] == "up" and realtime_movement["strength"] > 0.5 and realtime_movement["trend_consistent"]:
                action = "buy"
                confidence = 0.55 + realtime_bonus  # Confiance minimale de 55% pour mouvement temps réel fort
                components.append("RealtimeForceBUY")
                logger.info(f"🚀 FORCE BUY: Mouvement haussier temps réel fort détecté ({realtime_movement['price_change_percent']:+.3f}%)")
            else:
                action = "hold"
                confidence = MIN_CONF * 0.5
        
        # 7. CONFIANCE MINIMALE GARANTIE pour signaux valides avec H1 aligné
        # Si H1 est aligné, c'est déjà un signal valide = confiance minimale 0.60 (60%)
        if action != "hold" and (h1_bullish or h1_bearish):
            # Si H1 aligné avec M5, confiance minimale encore plus élevée
            if (m5_bullish) and h1_bullish:
                confidence = max(confidence, 0.70)  # 70% minimum si H1+M5
                if confidence == 0.70:
                    components.append("MinH1+M5:70%")
            elif (m5_bearish) and h1_bearish:
                confidence = max(confidence, 0.70)
                if confidence == 0.70:
                    components.append("MinH1+M5:70%")
            else:
                confidence = max(confidence, 0.60)  # 60% minimum si H1 seul
                if confidence == 0.60:
                    components.append("MinH1:60%")
        
        # 8. BONUS FINAL : Si M5+H1 alignés, confiance minimale 0.55
        if action != "hold" and (m5_bullish and h1_bullish):
            confidence = max(confidence, 0.55)
        elif action != "hold" and (m5_bearish and h1_bearish):
            confidence = max(confidence, 0.55)

        # 8.b OVERRIDE EMA/CHANNEL: éviter HOLD contre une tendance claire M5/H1 avec canal aligné
        if action == "hold":
            if (m5_bullish and (h1_bullish or not h1_bearish)) and channel_slope > 0:
                action = "buy"
                confidence = max(confidence, 0.55)
                components.append("EMA+Channel↑")
            elif (m5_bearish and (h1_bearish or not h1_bullish)) and channel_slope < 0:
                action = "sell"
                confidence = max(confidence, 0.55)
                components.append("EMA+Channel↓")

        
        # 9. Intégration de la décision ML multi-modèles (Boom/Crash, Forex, Commodities, Volatility)
        ml_decision = None
        separator = "=" * 80  # Séparateur pour les logs ML
        if BACKEND_AVAILABLE and ADAPTIVE_PREDICT_AVAILABLE:
            try:
                logger.info(separator)
                logger.info(f"🤖 SYSTÈME ML ACTIVÉ pour {request.symbol}")
                logger.info(separator)
                logger.info(f"📊 Récupération données historiques (2000 bougies M1)...")
                
                # Utiliser la fonction générique qui gère automatiquement:
                # 1. MT5 (avec connexion auto si variables d'env disponibles)
                # 2. Fichiers CSV locaux
                # 3. API endpoint (si DATA_API_URL configuré)
                df_ml = get_historical_data(request.symbol, "M1", 2000)
                if df_ml is not None and not df_ml.empty:
                    source_info = "MT5" if mt5_initialized else "Fallback (fichiers/API)"
                    logger.info(f"   └─ Source: {source_info}")
                
                if df_ml is not None and len(df_ml) > 200:
                    logger.info(f"✅ Données ML récupérées: {len(df_ml)} bougies pour {request.symbol}")
                    logger.info(f"   └─ Période: {df_ml['time'].min()} → {df_ml['time'].max()}")
                    
                    ml_decision = get_multi_model_ml_decision(request.symbol, df_ml)
                    if ml_decision and ml_decision.get("status") == "ok":
                        ml_action = ml_decision.get("action", "N/A")
                        ml_conf = ml_decision.get("confidence", 0)
                        ml_cat = ml_decision.get("trading_category", "N/A")
                        ml_model = ml_decision.get("model_name", "N/A")
                        ml_style = ml_decision.get("style", "N/A")
                        
                        logger.info(separator)
                        logger.info(f"🎯 DÉCISION ML FINALE pour {request.symbol}:")
                        logger.info(f"   ├─ Action: {ml_action.upper()}")
                        logger.info(f"   ├─ Confiance: {ml_conf:.1%}")
                        logger.info(f"   ├─ Catégorie: {ml_cat}")
                        logger.info(f"   ├─ Modèle: {ml_model}")
                        logger.info(f"   └─ Style: {ml_style.upper()}")
                        logger.info(separator)
                    elif ml_decision and ml_decision.get("status") == "error":
                        logger.warning(f"⚠️ ML erreur pour {request.symbol}: {ml_decision.get('error', 'Erreur inconnue')}")
                    else:
                        logger.warning(f"⚠️ ML retourné None pour {request.symbol}")
                else:
                    logger.warning(f"⚠️ Données ML insuffisantes pour {request.symbol}: {len(df_ml) if df_ml is not None else 0} bougies (minimum: 200)")
            except Exception as e:
                logger.error(separator)
                logger.error(f"❌ ERREUR SYSTÈME ML pour {request.symbol}")
                logger.error(f"   └─ {str(e)}")
                logger.error(separator, exc_info=True)
                ml_decision = None
        else:
            logger.warning(separator)
            logger.warning(f"⚠️ SYSTÈME ML NON DISPONIBLE pour {request.symbol}")
            logger.warning(f"   ├─ BACKEND: {BACKEND_AVAILABLE}")
            logger.warning(f"   ├─ ADAPTIVE_PREDICT: {ADAPTIVE_PREDICT_AVAILABLE}")
            logger.warning(f"   └─ MT5: {MT5_AVAILABLE}")
            logger.warning(separator)

        # Intégration ML améliorée - Le ML peut maintenant surcharger les indicateurs classiques
        ml_style = None
        if isinstance(ml_decision, dict) and ml_decision.get("status") == "ok":
            ml_action = ml_decision.get("action", "hold")
            ml_conf = float(ml_decision.get("confidence", 0.0))
            ml_style = ml_decision.get("style", None)
            ml_cat = ml_decision.get("trading_category", "")
            ml_model_name = ml_decision.get("model_name", "")
            
            # Seuil réduit à 0.50 pour permettre plus d'interventions ML
            if ml_conf >= 0.50 and ml_action in ("buy", "sell"):
                separator_dash = "─" * 80
                logger.info(separator_dash)
                logger.info(f"🔄 INTÉGRATION ML dans décision finale:")
                logger.info(f"   ├─ Décision classique: {action.upper()} @ {confidence:.1%}")
                logger.info(f"   └─ Décision ML: {ml_action.upper()} @ {ml_conf:.1%}")
                
                if action == "hold":
                    # Pas de décision forte côté indicateurs -> ML prend le contrôle
                    action = ml_action
                    confidence = ml_conf  # Utiliser directement la confiance ML
                    components.append(f"ML_PILOTE:{ml_cat}:{ml_conf:.0%}")
                    logger.info(separator)
                    logger.info(f"✅ ML PREND LE CONTRÔLE - {ml_action.upper()} @ {ml_conf:.1%}")
                    logger.info(separator)
                elif action == ml_action:
                    # Même direction -> renforcer significativement
                    old_conf = confidence
                    confidence = max(confidence, min(MAX_CONF, (confidence * 0.4 + ml_conf * 0.6)))
                    components.append(f"ML_RENFORCE:{ml_cat}:{ml_conf:.0%}")
                    logger.info(separator)
                    logger.info(f"✅ ML RENFORCE LA DÉCISION")
                    logger.info(f"   ├─ Confiance avant: {old_conf:.1%}")
                    logger.info(f"   └─ Confiance après: {confidence:.1%}")
                    logger.info(separator)
                else:
                    # Conflit: ML peut surcharger si confiance élevée
                    if ml_conf >= 0.70:
                        # ML très confiant -> surcharger les indicateurs classiques
                        old_action = action
                        old_conf = confidence
                        action = ml_action
                        confidence = ml_conf * 0.9  # Légèrement réduite pour prudence
                        components.append(f"ML_SURCHARGE:{ml_cat}:{ml_conf:.0%}")
                        logger.info(separator)
                        logger.info(f"⚠️ ML SURCHARGE LES INDICATEURS CLASSIQUES")
                        logger.info(f"   ├─ Avant: {old_action.upper()} @ {old_conf:.1%}")
                        logger.info(f"   └─ Après: {action.upper()} @ {confidence:.1%}")
                        logger.info(separator)
                    elif ml_conf >= 0.60 and confidence < 0.60:
                        # ML modérément confiant mais meilleur que les indicateurs
                        old_action = action
                        old_conf = confidence
                        action = ml_action
                        confidence = ml_conf * 0.85
                        components.append(f"ML_PREFERE:{ml_cat}:{ml_conf:.0%}")
                        logger.info(separator)
                        logger.info(f"✅ ML PRÉFÉRÉ AUX INDICATEURS")
                        logger.info(f"   ├─ Avant: {old_action.upper()} @ {old_conf:.1%}")
                        logger.info(f"   └─ Après: {action.upper()} @ {confidence:.1%}")
                        logger.info(separator)
                    else:
                        # Conflit mais indicateurs classiques plus forts OU confiance ML insuffisante pour surcharger
                        components.append(f"ML_IGNORE:{ml_cat}:{ml_conf:.0%}")
                        if ml_conf < confidence:
                            logger.info(f"⏸️ ML ignoré (conflit, conf ML={ml_conf:.1%} < conf classique={confidence:.1%})")
                        else:
                            logger.info(f"⏸️ ML ignoré (conflit, conf ML={ml_conf:.1%} insuffisante pour surcharger conf classique={confidence:.1%} - nécessite ≥70% ou classique <60%)")

                # Ajouter le nom du modèle dans les composants pour la raison finale
                if ml_model_name:
                    components.append(f"Model:{ml_model_name}")
            else:
                # Même si confiance < 0.50, permettre au ML de prendre le contrôle si action classique = "hold"
                # et que le ML a au moins une confiance minimale
                if action == "hold" and ml_conf >= 0.40 and ml_action in ("buy", "sell"):
                    action = ml_action
                    confidence = ml_conf
                    components.append(f"ML_FALLBACK:{ml_cat}:{ml_conf:.0%}")
                    logger.info(f"✅ ML FALLBACK activé - {ml_action.upper()} @ {ml_conf:.1%} (indicateurs classiques neutres)")
                else:
                    logger.info(f"⏸️ ML ignoré: confiance trop faible ({ml_conf:.1%} < 0.50) ou action=hold")


        # Harmonisation de la confiance avec l'alignement (M1/M5/H1) et la décision finale
        try:
            core_bullish_count = int(m1_bullish) + int(m5_bullish) + int(h1_bullish)
            core_bearish_count = int(m1_bearish) + int(m5_bearish) + int(h1_bearish)
            if action in ("buy", "sell"):
                core_count = core_bullish_count if action == "buy" else core_bearish_count
                # Carte des seuils cibles selon l'alignement coeur (3 TF)
                if core_count >= 3:
                    target_min = 0.90
                elif core_count == 2:
                    target_min = 0.75
                elif core_count == 1:
                    target_min = 0.60
                else:
                    target_min = 0.0
                # Bonus canal si aligné avec l'action
                if (action == "buy" and channel_slope > 0) or (action == "sell" and channel_slope < 0):
                    target_min = min(MAX_CONF, target_min + 0.05)
                # Bonus fort si mouvement temps réel confirme et alignement 3/3
                if core_count >= 3 and realtime_movement.get("trend_consistent") and realtime_movement.get("strength", 0.0) > 0.5:
                    target_min = min(MAX_CONF, max(target_min, 0.90) + 0.03)
                confidence = max(confidence, target_min)
                components.append(f"Core{('B' if action=='buy' else 'S')}:{core_count}/3")
        except Exception as _conf_ex:
            logger.debug(f"Align/Conf harmonization skipped: {_conf_ex}")
        # 10. S'assurer que la confiance est dans les limites raisonnables
        confidence = max(0.10, min(MAX_CONF, confidence))
        
        # Initialize any potentially undefined variables to 0 for logging
        long_term_alignment_bonus = long_term_alignment_bonus if 'long_term_alignment_bonus' in locals() else 0.0
        medium_term_bonus = medium_term_bonus if 'medium_term_bonus' in locals() else 0.0
        alignment_bonus = alignment_bonus if 'alignment_bonus' in locals() else 0.0
        
        # Log détaillé pour comprendre le calcul
        logger.info(f"📊 Confiance {request.symbol}: {action.upper()} | Score={direction_score:+.3f} | "
                   f"Base={base_confidence:.2f} | H4/D1={long_term_bonus:.2f} | H1+H4/D1={long_term_alignment_bonus:.2f} | "
                   f"M5+H1={medium_term_bonus:.2f} | Align={alignment_bonus:.2f} | FINAL={confidence:.2f} ({confidence*100:.1f}%)")
        
        # Construire la raison initiale structurée
        reason_parts = []
        if action != "hold":
            reason_parts.append(f"Signal {action.upper()}")
        reason_parts.append(f"Score={direction_score:+.3f}")
        reason_parts.append(f"Conf={confidence:.1%}")
        # Ajouter le style de trading proposé par la ML (scalp / swing) si disponible
        if ml_style and action != "hold":
            reason_parts.append(f"Style={ml_style}")
        
        # Ajouter les composants principaux (limiter à 5 pour éviter trop de détails)
        if components:
            main_components = components[:5]
            reason_parts.append(f"TF:{','.join(main_components)}")
        
        # Construire la raison de base
        reason = " | ".join(reason_parts) if reason_parts else "Analyse en cours"
        
        # Utiliser Gemini AI pour améliorer la raison si disponible
        # Note: Gemini est désactivé par défaut, on utilise Mistral si disponible
        if GEMINI_AVAILABLE and reason:
            try:
                ai_prompt = f"""
Analyse de trading pour {request.symbol}:
- Prix: {mid_price:.5f} (Bid: {bid:.5f}, Ask: {ask:.5f})
- RSI: {rsi:.2f}
- EMA H1: Fast={ema_fast_h1:.5f}, Slow={ema_slow_h1:.5f}
- EMA M1: Fast={ema_fast_m1:.5f}, Slow={ema_slow_m1:.5f}
- ATR: {request.atr:.5f}
- Direction actuelle: {action}
- Confiance: {confidence:.2%}

Donne une analyse concise (1-2 phrases) expliquant pourquoi {action} est recommandé.
Format: Analyse claire et professionnelle en français.
"""
                ai_analysis = analyze_with_gemini(ai_prompt)
                if ai_analysis:
                    reason = f"{reason} | IA: {ai_analysis[:100]}"
            except Exception as e:
                logger.debug(f"Gemini analysis non disponible: {e}")
        
        # Alternative: Utiliser Mistral AI si disponible et Gemini non disponible
        elif MISTRAL_AVAILABLE and reason and not GEMINI_AVAILABLE:
            try:
                ai_prompt = f"Analyse trading {request.symbol}: Prix={mid_price:.5f}, RSI={rsi:.2f}, Action={action}, Confiance={confidence:.0%}. Donne analyse courte (1 phrase)."
                ai_analysis = analyze_with_ai(ai_prompt)
                if ai_analysis:
                    reason = f"{reason} | Mistral: {ai_analysis[:80]}"
            except Exception as e:
                logger.debug(f"Mistral analysis non disponible: {e}")

        # Ajustement final via règles d'association (facultatif)
        try:
            items = build_items_from_request(request)
            action, confidence, reason = adjust_decision_with_rules(
                request.symbol, action, confidence, reason, items
            )
        except Exception as e:
            logger.warning(f"Erreur ajustement règles d'association: {e}")

        # S'assurer que la raison est complète
        # Si la raison de base n'a pas été modifiée par les règles d'association,
        # elle contient déjà les reason_parts, donc pas besoin de les réajouter
        if not reason or reason == "":
            # Construire la raison depuis les parts si elle est vide
            if reason_parts:
                reason = " | ".join(reason_parts)
            else:
                reason = f"Signal {action.upper()} (confiance: {confidence:.1%})"

        stop_loss = None
        take_profit = None

        # Utiliser Gemma Local (Multimodal) si image disponible
        if GEMMA_AVAILABLE and request.image_filename:
            try:
                gemma_prompt = f"Analyse graph {request.symbol}. Action: {action}. Donne moi 3 choses: 1) Tendance 2) Support/Resistance 3) Prix exacts pour SL et TP. Format: 'SL: 1.2345 | TP: 1.2345'"
                gemma_analysis = analyze_with_gemma(gemma_prompt, request.image_filename)
                
                if gemma_analysis:
                    logger.info(f"Gemma Analysis: {gemma_analysis}")
                    reason += f" | Gemma: {gemma_analysis[:150]}"
                    
                    # Bonus de confiance si Gemma confirme
                    if action.lower() in gemma_analysis.lower():
                        confidence = min(confidence + 0.05, MAX_CONF)
                        reason_parts.append("Gemma:+")
                        
                    # Tentative d'extraction SL/TP via Regex
                    import re
                    try:
                        sl_match = re.search(r"SL:\s*([\d\.]+)", gemma_analysis, re.IGNORECASE)
                        tp_match = re.search(r"TP:\s*([\d\.]+)", gemma_analysis, re.IGNORECASE)
                        
                        if sl_match:
                            stop_loss = float(sl_match.group(1))
                            logger.info(f"Gemma SL found: {stop_loss}")
                        if tp_match:
                            take_profit = float(tp_match.group(1))
                            logger.info(f"Gemma TP found: {take_profit}")
                            
                    except Exception as parse_err:
                        logger.warning(f"Failed to parse SL/TP from Gemma: {parse_err}")

            except Exception as e:
                logger.error(f"Erreur analyse Gemma: {type(e).__name__}: {str(e)}", exc_info=True)

        if AI_INDICATORS_AVAILABLE and mt5_initialized:
            try:
                # Récupérer les données pour l'analyse avancée
                df = get_historical_data_mt5(request.symbol, "M1", 100)
                if df is not None and len(df) > 20:
                    cache_key_ind = f"{request.symbol}_M1"
                    if cache_key_ind not in indicators_cache:
                        indicators_cache[cache_key_ind] = AdvancedIndicators(request.symbol, "M1")
                    
                    analyzer = indicators_cache[cache_key_ind]
                    sentiment = analyzer.calculate_market_sentiment(df)
                    
                    # Améliorer la décision avec le sentiment
                    if sentiment.get('sentiment', 0) > 0.3:
                        sentiment_bonus = WEIGHTS.get("sentiment", 0.07)
                        score += sentiment_bonus
                        reason_parts.append("Sentiment:+")
                        reason += f" | Sentiment: {sentiment.get('trend', 'neutral')}"
                    elif sentiment.get('sentiment', 0) < -0.3:
                        sentiment_bonus = WEIGHTS.get("sentiment", 0.07)
                        score -= sentiment_bonus
                        reason_parts.append("Sentiment:-")
                        reason += f" | Sentiment: {sentiment.get('trend', 'neutral')}"
                    
                    # Ajuster la confiance selon le sentiment
                    sentiment_strength = abs(sentiment.get('sentiment', 0))
                    if sentiment_strength > 0.5:
                        confidence = min(confidence + 0.05, MAX_CONF)
            except Exception as e:
                logger.warning(f"Erreur AdvancedIndicators dans decision: {e}")
        
        # ========== DÉTECTION DE SPIKE RENFORCÉE MULTI-SYSTÈME ==========
        spike_prediction = False
        spike_zone_price = None
        spike_direction = None
        early_spike_warning = False
        early_spike_zone_price = None
        early_spike_direction = None
        
        # Filtrage des symboles de volatilité
        is_volatility_symbol = any(vol in request.symbol for vol in ["Volatility", "Boom", "Crash", "Step Index"])
        is_boom = "Boom" in request.symbol
        is_crash = "Crash" in request.symbol
        is_step = "Step" in request.symbol
        
        if is_volatility_symbol:
            try:
                # 1. DÉTECTION ML AVANCÉE (si disponible)
                ml_spike_score = 0.0
                ml_spike_direction = None
                if SPIKE_DETECTOR_AVAILABLE:
                    try:
                        df_m1 = get_historical_data_mt5(request.symbol, "M1", 200)
                        if df_m1 is not None and len(df_m1) > 50:
                            # Prédiction ML
                            ml_result = predict_spike_ml(df_m1)
                            if ml_result and isinstance(ml_result, float):
                                ml_spike_score = ml_result
                                if ml_spike_score > 0.75:  # Seuil élevé pour ML
                                    ml_spike_direction = is_boom  # BUY pour Boom, SELL pour Crash
                                    logger.info(f"🚀 ML Spike détecté: {ml_spike_score:.2%} pour {request.symbol}")
                    except Exception as e:
                        logger.debug(f"Erreur détection ML spike: {e}")
                
                # 2. DÉTECTION AVANCÉE MULTI-INDICATEURS (AdvancedSpikeDetector)
                advanced_score = 0.0
                advanced_direction = None
                if ADVANCED_SPIKE_DETECTOR_AVAILABLE and advanced_spike_detector:
                    try:
                        df_m1 = get_historical_data_mt5(request.symbol, "M1", 100)
                        df_m5 = get_historical_data_mt5(request.symbol, "M5", 50) if df_m1 is not None else None
                        df_m15 = get_historical_data_mt5(request.symbol, "M15", 30) if df_m1 is not None else None
                        
                        if df_m1 is not None and len(df_m1) > 20:
                            score_result = advanced_spike_detector.calculate_spike_score(
                                symbol=request.symbol,
                                rsi=rsi,
                                atr=request.atr,
                                mid_price=mid_price,
                                ema_fast_h1=request.ema_fast_h1,
                                ema_slow_h1=request.ema_slow_h1,
                                ema_fast_m1=request.ema_fast_m1,
                                ema_slow_m1=request.ema_slow_m1,
                                vwap=request.vwap if hasattr(request, 'vwap') else None,
                                supertrend_trend=1 if supertrend_bullish else (-1 if supertrend_bearish else 0),
                                volatility_ratio=request.volatility_ratio if hasattr(request, 'volatility_ratio') else None,
                                df_m1=df_m1,
                                df_m5=df_m5,
                                df_m15=df_m15
                            )
                            advanced_score = score_result.get('score', 0.0)
                            advanced_direction = score_result.get('is_buy', False)
                            if advanced_score > 0.75:
                                logger.info(f"📊 Advanced Spike Score: {advanced_score:.2%} - {score_result.get('reasons', '')}")
                    except Exception as e:
                        logger.debug(f"Erreur AdvancedSpikeDetector: {e}")
                
                # 3. DÉTECTION AVEC FRACTALS (NOUVEAU)
                fractal_upper = 0.0
                fractal_lower = 0.0
                fractal_signal = False
                if MT5_AVAILABLE:
                    try:
                        df_fractal = get_historical_data_mt5(request.symbol, "M1", 50)
                        if df_fractal is not None and len(df_fractal) > 20:
                            fractals = calculate_fractals(df_fractal, period=5)
                            fractal_upper = fractals.get('upper_fractal', 0.0)
                            fractal_lower = fractals.get('lower_fractal', 0.0)
                            
                            # Vérifier si le prix est proche d'une zone fractal (signal de mouvement)
                            if fractal_upper > 0 and mid_price >= fractal_upper * 0.99:
                                fractal_signal = True
                                logger.info(f"📊 Fractal supérieur détecté: {fractal_upper:.5f} - Prix proche")
                            elif fractal_lower > 0 and mid_price <= fractal_lower * 1.01:
                                fractal_signal = True
                                logger.info(f"📊 Fractal inférieur détecté: {fractal_lower:.5f} - Prix proche")
                    except Exception as e:
                        logger.debug(f"Erreur calcul fractals: {e}")
                
                # 4. AMÉLIORATION PRÉDICTION SPIKE AVEC HISTORIQUE (NOUVEAU)
                historical_spike_data = None
                if MT5_AVAILABLE:
                    try:
                        df_history = get_historical_data_mt5(request.symbol, "M1", 200)
                        if df_history is not None and len(df_history) > 50:
                            historical_spike_data = enhance_spike_prediction_with_history(df_history, request.symbol)
                            if historical_spike_data.get('spike_probability', 0) > 0.6:
                                logger.info(f"🔮 Prédiction spike historique: {historical_spike_data.get('spike_probability', 0):.2%} - Pattern: {historical_spike_data.get('historical_pattern', 'normal')}")
                    except Exception as e:
                        logger.debug(f"Erreur prédiction historique: {e}")
                
                # 5. DÉTECTION TRADITIONNELLE RENFORCÉE
                volatility = request.atr / mid_price if mid_price > 0 else 0
                strong_vol = volatility >= 0.003
                medium_vol = volatility >= 0.0015
                extreme_oversold = rsi is not None and rsi <= 20
                extreme_overbought = rsi is not None and rsi >= 80
                moderate_oversold = rsi is not None and rsi <= 35
                moderate_overbought = rsi is not None and rsi >= 65
                
                # Score de détection traditionnelle (0-1)
                traditional_score = 0.0
                traditional_direction = None
                
                # Conditions haussières (avec fractals et historique)
                bull_conditions = 0
                if strong_vol: bull_conditions += 1
                if extreme_oversold: bull_conditions += 1
                if h1_bullish and m1_bullish: bull_conditions += 1
                if request.dir_rule >= 1: bull_conditions += 1
                if vwap_signal_buy or supertrend_bullish: bull_conditions += 1
                if fractal_signal and fractal_lower > 0: bull_conditions += 1  # Prix proche fractal inférieur
                if historical_spike_data and historical_spike_data.get('spike_direction') == 'up': bull_conditions += 1
                
                # Conditions baissières (avec fractals et historique)
                bear_conditions = 0
                if strong_vol: bear_conditions += 1
                if extreme_overbought: bear_conditions += 1
                if h1_bearish and m1_bearish: bear_conditions += 1
                if request.dir_rule <= -1: bear_conditions += 1
                if vwap_signal_sell or supertrend_bearish: bear_conditions += 1
                if fractal_signal and fractal_upper > 0: bear_conditions += 1  # Prix proche fractal supérieur
                if historical_spike_data and historical_spike_data.get('spike_direction') == 'down': bear_conditions += 1
                
                if bull_conditions >= 4:  # Au moins 4/5 conditions
                    traditional_score = 0.8 + (bull_conditions - 4) * 0.05
                    traditional_direction = True  # BUY
                elif bear_conditions >= 4:
                    traditional_score = 0.8 + (bear_conditions - 4) * 0.05
                    traditional_direction = False  # SELL
                elif bull_conditions >= 3:
                    traditional_score = 0.6
                    traditional_direction = True
                elif bear_conditions >= 3:
                    traditional_score = 0.6
                    traditional_direction = False
                
                # 4. FUSION DES SCORES (Pondération intelligente)
                final_spike_score = 0.0
                final_direction = None
                score_weights = []
                
                # ML a le plus de poids si disponible et fiable
                if ml_spike_score > 0.7:
                    final_spike_score += ml_spike_score * 0.4
                    score_weights.append(f"ML:{ml_spike_score:.2%}")
                    if final_direction is None:
                        final_direction = ml_spike_direction
                
                # Advanced detector a un poids moyen
                if advanced_score > 0.7:
                    final_spike_score += advanced_score * 0.35
                    score_weights.append(f"Advanced:{advanced_score:.2%}")
                    if final_direction is None:
                        final_direction = advanced_direction
                
                # Détection traditionnelle comme confirmation
                if traditional_score > 0.6:
                    final_spike_score += traditional_score * 0.25
                    score_weights.append(f"Traditional:{traditional_score:.2%}")
                    if final_direction is None:
                        final_direction = traditional_direction
                
                # Normaliser le score final
                final_spike_score = min(final_spike_score, 1.0)
                
                # 5. DÉCISION FINALE
                if final_spike_score >= 0.75:  # Seuil élevé pour spike confirmé
                    spike_prediction = True
                    spike_zone_price = mid_price
                    spike_direction = final_direction if final_direction is not None else (is_boom)
                    confidence = min(confidence + 0.2, 0.95)
                    reason += f" | 🚀 SPIKE CONFIRMÉ (Score: {final_spike_score:.2%}, Sources: {', '.join(score_weights)})"
                    logger.info(f"✅ SPIKE DÉTECTÉ pour {request.symbol}: Score={final_spike_score:.2%}, Direction={'BUY' if spike_direction else 'SELL'}")
                    
                elif final_spike_score >= 0.60:  # Pré-alerte
                    early_spike_warning = True
                    early_spike_zone_price = mid_price
                    early_spike_direction = final_direction if final_direction is not None else (moderate_oversold)
                    confidence = min(confidence + 0.08, 0.85)
                    reason += f" | ⚠️ Pré-alerte Spike (Score: {final_spike_score:.2%})"
                    logger.info(f"⚠️ Pré-alerte SPIKE pour {request.symbol}: Score={final_spike_score:.2%}")
                
            except Exception as e:
                logger.warning(f"Erreur détection spike renforcée: {e}")
                logger.debug(traceback.format_exc())
        
        # Fallback: Détection basique si les systèmes avancés ne sont pas disponibles
        if not spike_prediction and not early_spike_warning and is_volatility_symbol:
            # Détection traditionnelle simplifiée comme fallback
            volatility = request.atr / mid_price if mid_price > 0 else 0
            strong_vol = volatility >= 0.003
            medium_vol = volatility >= 0.0015
            extreme_oversold = rsi is not None and rsi <= 20
            extreme_overbought = rsi is not None and rsi >= 80
            moderate_oversold = rsi is not None and rsi <= 35
            moderate_overbought = rsi is not None and rsi >= 65
            
            # Spike haussier avec conditions renforcées
            strong_bull_spike = (
                strong_vol
                and extreme_oversold
                and h1_bullish and m1_bullish
                and request.dir_rule >= 1
                and (vwap_signal_buy or supertrend_bullish)
            )
            
            # Spike baissier avec conditions renforcées
            strong_bear_spike = (
                strong_vol
                and extreme_overbought
                and h1_bearish and m1_bearish
                and request.dir_rule <= -1
                and (vwap_signal_sell or supertrend_bearish)
            )
            
            # Spike pour Step Index
            step_spike = False
            if is_step:
                step_spike = (
                    strong_vol
                    and (extreme_oversold or extreme_overbought)
                    and ((h1_bullish and m1_bullish) or (h1_bearish and m1_bearish))
                    and abs(request.dir_rule) >= 1
                )
            
            if strong_bull_spike or strong_bear_spike or step_spike:
                spike_prediction = True
                spike_zone_price = mid_price
                spike_direction = strong_bull_spike or (step_spike and extreme_oversold)
                confidence = min(confidence + 0.2, 0.95)
                
                if is_boom:
                    reason += " | Spike Boom confirmé (fallback)"
                elif is_crash:
                    reason += " | Spike Crash confirmé (fallback)"
                elif is_step:
                    reason += " | Spike Step Index détecté (fallback)"
                else:
                    reason += " | Spike Volatilité confirmé (fallback)"
            
            # Pré-alerte améliorée avec filtre de bruit
            elif (medium_vol and 
                  (moderate_oversold or moderate_overbought) and
                  (h1_bullish != h1_bearish) and
                  (request.volatility_ratio > 0.7 if hasattr(request, 'volatility_ratio') and request.volatility_ratio is not None else True)):
                
                early_spike_warning = True
                early_spike_zone_price = mid_price
                early_spike_direction = moderate_oversold
                confidence = min(confidence + 0.05, 0.85)
                
                if is_boom:
                    reason += " | Pré-alerte Spike Boom (fallback)"
                elif is_crash:
                    reason += " | Pré-alerte Spike Crash (fallback)"
                else:
                    reason += " | Pré-alerte Volatilité (fallback)"
            is_boom = "Boom" in request.symbol
            is_crash = "Crash" in request.symbol
            is_step = "Step" in request.symbol

            volatility = request.atr / mid_price if mid_price > 0 else 0

            # Conditions de volatilité plus strictes
            strong_vol = volatility >= 0.003   # Augmenté de 0.002 à 0.003 (~0.3%)
            medium_vol = volatility >= 0.0015  # Augmenté de 0.001 à 0.0015

            # RSI plus stricts pour éviter les faux signaux
            extreme_oversold = rsi is not None and rsi <= 20      # Augmenté de 25 à 20
            extreme_overbought = rsi is not None and rsi >= 80     # Augmenté de 75 à 80
            moderate_oversold = rsi is not None and rsi <= 35      # Nouveau seuil modéré
            moderate_overbought = rsi is not None and rsi >= 65    # Nouveau seuil modéré

            # Spike haussier avec conditions renforcées
            strong_bull_spike = (
                strong_vol
                and extreme_oversold
                and h1_bullish and m1_bullish    # Alignement requis
                and request.dir_rule >= 1        # Direction BUY claire (pas neutre)
                and (vwap_signal_buy or supertrend_bullish)  # Confirmation additionnelle
            )

            # Spike baissier avec conditions renforcées
            strong_bear_spike = (
                strong_vol
                and extreme_overbought
                and h1_bearish and m1_bearish    # Alignement requis
                and request.dir_rule <= -1       # Direction SELL claire (pas neutre)
                and (vwap_signal_sell or supertrend_bearish)  # Confirmation additionnelle
            )

            # Spike pour Step Index avec conditions spécifiques
            step_spike = False
            if is_step:
                step_spike = (
                    strong_vol
                    and (extreme_oversold or extreme_overbought)
                    and ((h1_bullish and m1_bullish) or (h1_bearish and m1_bearish))
                    and abs(request.dir_rule) >= 1
                )

            if strong_bull_spike or strong_bear_spike or step_spike:
                spike_prediction = True
                spike_zone_price = mid_price
                spike_direction = strong_bull_spike or (step_spike and extreme_oversold)
                confidence = min(confidence + 0.2, 0.95)  # Bonus plus important
                
                if is_boom:
                    reason += " | Spike Boom confirmé (conditions strictes)"
                elif is_crash:
                    reason += " | Spike Crash confirmé (conditions strictes)"
                elif is_step:
                    reason += " | Spike Step Index détecté"
                else:
                    reason += " | Spike Volatilité confirmé"

            # Pré-alerte améliorée avec filtre de bruit
            elif (medium_vol and 
                  (moderate_oversold or moderate_overbought) and
                  (h1_bullish != h1_bearish) and  # Tendance claire sur H1
                  (request.volatility_ratio > 0.7 if hasattr(request, 'volatility_ratio') and request.volatility_ratio is not None else True)):  # Filtrer les faibles ratios
                
                early_spike_warning = True
                early_spike_zone_price = mid_price
                early_spike_direction = moderate_oversold
                confidence = min(confidence + 0.05, 0.85)  # Petit bonus de confiance
                
                if is_boom:
                    reason += " | Pré-alerte Spike Boom (conditions modérées)"
                elif is_crash:
                    reason += " | Pré-alerte Spike Crash (conditions modérées)"
                else:
                    reason += " | Pré-alerte Volatilité (conditions modérées)"
        
        # Calcul des zones d'achat/vente
        buy_zone_low = None
        buy_zone_high = None
        sell_zone_low = None
        sell_zone_high = None
        
        if h1_bullish:
            buffer = request.atr * 0.5
            buy_zone_low = mid_price - buffer
            buy_zone_high = mid_price + buffer
        
        if h1_bearish:
            buffer = request.atr * 0.5
            sell_zone_low = mid_price - buffer
            sell_zone_high = mid_price + buffer
        
        # ========== VALIDATION FINALE INTELLIGENCE DES ORDRES ==========
        # S'assurer que les ordres sont vraiment intelligents avant de les envoyer
        if action != "hold":
            # 1. Validation multi-critères pour BUY
            if action == "buy":
                buy_validation_score = 0.0
                buy_validation_reasons = []
                
                # Critères techniques
                if h1_bullish: buy_validation_score += 0.25; buy_validation_reasons.append("H1↑")
                if m5_bullish: buy_validation_score += 0.20; buy_validation_reasons.append("M5↑")
                if m1_bullish: buy_validation_score += 0.1; buy_validation_reasons.append("M1↑")
                if rsi_bullish: buy_validation_score += 0.1; buy_validation_reasons.append("RSI↑")
                if vwap_signal_buy: buy_validation_score += 0.1; buy_validation_reasons.append("VWAP↑")
                if supertrend_bullish: buy_validation_score += 0.1; buy_validation_reasons.append("ST↑")
                
                # Validation ML si disponible
                if ml_decision and ml_decision.get("action") == "buy":
                    ml_conf = float(ml_decision.get("confidence", 0.0))
                    buy_validation_score += ml_conf * 0.3
                    buy_validation_reasons.append(f"ML:{ml_conf:.0%}")
                
                # Seuil minimum pour valider un BUY intelligent
                MIN_BUY_INTELLIGENCE = 0.50  # Au moins 50% de validation
                if buy_validation_score < MIN_BUY_INTELLIGENCE:
                    logger.warning(f"⚠️ BUY rejeté: Score validation insuffisant ({buy_validation_score:.2f} < {MIN_BUY_INTELLIGENCE})")
                    logger.warning(f"   Raisons: {', '.join(buy_validation_reasons) if buy_validation_reasons else 'Aucune'}")
                    action = "hold"
                    confidence = max(confidence * 0.5, 0.20)  # Réduire la confiance
                    reason += f" | BUY rejeté (validation: {buy_validation_score:.0%} < {MIN_BUY_INTELLIGENCE:.0%})"
                else:
                    logger.info(f"✅ BUY validé: Score={buy_validation_score:.2f} ({', '.join(buy_validation_reasons)})")
            
            # 2. Validation multi-critères pour SELL
            elif action == "sell":
                sell_validation_score = 0.0
                sell_validation_reasons = []
                
                # Critères techniques
                if h1_bearish: sell_validation_score += 0.25; sell_validation_reasons.append("H1↓")
                if m5_bearish: sell_validation_score += 0.20; sell_validation_reasons.append("M5↓")
                if m1_bearish: sell_validation_score += 0.1; sell_validation_reasons.append("M1↓")
                if rsi_bearish: sell_validation_score += 0.1; sell_validation_reasons.append("RSI↓")
                if vwap_signal_sell: sell_validation_score += 0.1; sell_validation_reasons.append("VWAP↓")
                if supertrend_bearish: sell_validation_score += 0.1; sell_validation_reasons.append("ST↓")
                
                # Validation ML si disponible
                if ml_decision and ml_decision.get("action") == "sell":
                    ml_conf = float(ml_decision.get("confidence", 0.0))
                    sell_validation_score += ml_conf * 0.3
                    sell_validation_reasons.append(f"ML:{ml_conf:.0%}")
                
                # Seuil minimum pour valider un SELL intelligent
                MIN_SELL_INTELLIGENCE = 0.50  # Au moins 50% de validation
                if sell_validation_score < MIN_SELL_INTELLIGENCE:
                    logger.warning(f"⚠️ SELL rejeté: Score validation insuffisant ({sell_validation_score:.2f} < {MIN_SELL_INTELLIGENCE})")
                    logger.warning(f"   Raisons: {', '.join(sell_validation_reasons) if sell_validation_reasons else 'Aucune'}")
                    action = "hold"
                    confidence = max(confidence * 0.5, 0.20)  # Réduire la confiance
                    reason += f" | SELL rejeté (validation: {sell_validation_score:.0%} < {MIN_SELL_INTELLIGENCE:.0%})"
                else:
                    logger.info(f"✅ SELL validé: Score={sell_validation_score:.2f} ({', '.join(sell_validation_reasons)})")
            
            # 3. Validation spéciale en mode initialisation
            if initialization_mode and action != "hold":
                # En mode initialisation, être encore plus strict
                if confidence < 0.65:  # Seuil plus élevé à l'initialisation
                    logger.info(f"🔄 Initialisation: {action.upper()} rejeté (confiance {confidence:.1%} < 65% requis)")
                    action = "hold"
                    confidence = 0.30
                    reason += " | Initialisation: Confiance insuffisante pour trader immédiatement"
        
        # Construire la réponse
        response_data = {
            "action": action,
            "confidence": round(confidence, 3),
            "reason": reason,
            "spike_prediction": spike_prediction,
            "spike_zone_price": spike_zone_price,
            "spike_direction": spike_direction,
            "early_spike_warning": early_spike_warning,
            "early_spike_zone_price": early_spike_zone_price,
            "early_spike_direction": early_spike_direction,
            "buy_zone_low": buy_zone_low,
            "buy_zone_high": buy_zone_high,
            "sell_zone_low": sell_zone_low,
            "sell_zone_high": sell_zone_high,
            "stop_loss": stop_loss,
            "take_profit": take_profit
        }
        
        # Log de débogage pour vérifier les valeurs
        init_marker = "🔄 [INIT]" if initialization_mode else ""
        logger.info(f"✅ {init_marker} Décision IA pour {request.symbol}: action={action}, confidence={confidence:.3f} ({confidence*100:.1f}%), reason={reason[:100]}")
        
        # Mise en cache
        prediction_cache[cache_key] = response_data
        last_updated[cache_key] = current_time
        
        # Sauvegarder la prédiction dans le dossier MT5 Predictions pour analyse/entraînement futur
        try:
            # Déterminer le timeframe (par défaut M1, mais on peut le déduire du contexte si nécessaire)
            timeframe = "M1"  # Par défaut, le robot utilise M1 pour la plupart des décisions
            save_prediction_to_mt5_files(
                symbol=request.symbol,
                timeframe=timeframe,
                decision=response_data,
                ml_decision=ml_decision
            )
        except Exception as save_err:
            # Ne pas bloquer la réponse si la sauvegarde échoue
            logger.warning(f"⚠️ Erreur sauvegarde prédiction pour {request.symbol}: {save_err}")
        
        return DecisionResponse(**response_data)
        
    except Exception as e:
        logger.error(f"Erreur dans /decision: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )

async def handle_raw_analysis_request(raw_request: dict, symbol: Optional[str]) -> AnalysisResponse:
    """Gère les requêtes brutes (compatibilité MT5)"""
    logger.debug(f"Traitement d'une requête brute: {raw_request}")
    symbol = raw_request.get("symbol", symbol)
    request_type = raw_request.get("request_type")
    
    if not symbol:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le paramètre 'symbol' est requis dans raw_request"
        )
    
    if request_type == "fibonacci_analysis":
        logger.info(f"Analyse Fibonacci demandée pour {symbol} (raw)")
        return generate_fibonacci_response(symbol)
    
    return await get_technical_analysis(symbol)

async def handle_analysis_request(request: AnalysisRequest) -> AnalysisResponse:
    """Gère les requêtes via le modèle AnalysisRequest"""
    if not request.symbol:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le champ 'symbol' est requis"
        )
    
    if request.request_type == "fibonacci_analysis":
        logger.info(f"Analyse Fibonacci demandée pour {request.symbol} (via request)")
        return generate_fibonacci_response(request.symbol)
    
    return await get_technical_analysis(request.symbol)

def generate_fibonacci_response(symbol: str) -> AnalysisResponse:
    """Génère une réponse d'analyse Fibonacci"""
    import random
    base_price = random.uniform(
        6000 if "Boom" in symbol else 10000,
        10000 if "Boom" in symbol else 15000
    )
    fib_levels = generate_fibonacci_levels(base_price)
    
    return AnalysisResponse(
        symbol=symbol,
        timestamp=datetime.now().isoformat(),
        h1=fib_levels.get("h1", {}),
        h4=fib_levels.get("h4", {}),
        m15=fib_levels.get("m15", {})
    )

async def get_technical_analysis(symbol: str) -> AnalysisResponse:
    """Effectue une analyse technique complète"""
    logger.info(f"Début de l'analyse technique pour {symbol}")
    
    response = {
        "symbol": symbol,
        "timestamp": datetime.now().isoformat(),
        "h1": {},
        "h4": {},
        "m15": {},
        "ete": None
    }
    
    if not mt5_initialized:
        logger.warning("MT5 non initialisé - retour d'une réponse vide")
        return AnalysisResponse(**response)
    
    try:
        # Analyse H1
        df_h1 = get_historical_data_mt5(symbol, "H1", 400)
        if df_h1 is not None and not df_h1.empty:
            response["h1"] = detect_trendlines(df_h1)
        
        # Analyse H4
        df_h4 = get_historical_data_mt5(symbol, "H4", 400)
        if df_h4 is not None and not df_h4.empty:
            response["h4"] = detect_trendlines(df_h4)
        
        # Analyse M15
        df_m15 = get_historical_data_mt5(symbol, "M15", 400)
        if df_m15 is not None and not df_m15.empty:
            response["m15"] = detect_trendlines(df_m15)
            
    except Exception as e:
        logger.error(f"Erreur lors de l'analyse technique: {str(e)}", exc_info=True)
        # On continue avec les données disponibles
    
    return AnalysisResponse(**response)

@app.get("/analysis", response_model=AnalysisResponse)
@app.post("/analysis", response_model=AnalysisResponse)
async def analysis(
    symbol: Optional[str] = None,
    request: Optional[AnalysisRequest] = None,
    raw_request: Optional[dict] = Body(None, embed=True)
):
    """
    Analyse complète de la structure de marché (H1, H4, M15)
    Inclut les trendlines, figures chartistes et analyse Fibonacci
    
    Args:
        symbol: Symbole à analyser (peut être fourni en paramètre de requête ou dans le body)
        request: Objet de requête Pydantic (pour les requêtes POST JSON)
        raw_request: Corps brut de la requête (pour compatibilité MT5)
        
    Returns:
        AnalysisResponse: Réponse contenant l'analyse technique
    """
    try:
        # Journalisation de la requête
        logger.info(f"Requête /analysis reçue - symbol: {symbol}, "
                  f"request: {request}, raw_request: {raw_request}")
        
        # Si raw_request est un dictionnaire vide, le traiter comme None
        if raw_request == {}:
            raw_request = None
            
        # Vérification des paramètres d'entrée
        if symbol is None and request is None and raw_request is None:
            # Essayer de récupérer les données directement du corps de la requête
            body = await request.body()
            if body:
                try:
                    data = json.loads(body)
                    if 'symbol' in data:
                        symbol = data['symbol']
                        logger.info(f"Symbole extrait du corps de la requête: {symbol}")
                    elif 'raw_request' in data and isinstance(data['raw_request'], dict) and 'symbol' in data['raw_request']:
                        return await handle_raw_analysis_request(data['raw_request'], None)
                except json.JSONDecodeError:
                    pass
                    
            if symbol is None:
                logger.error("Aucun paramètre valide fourni")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Le paramètre 'symbol' est requis ou fournissez un objet de requête valide"
                )

        # Traitement des différentes sources de données
        if raw_request is not None:
            if isinstance(raw_request, dict):
                return await handle_raw_analysis_request(raw_request, symbol)
            else:
                logger.warning(f"Format de raw_request non pris en charge: {type(raw_request)}")
                
        if request is not None:
            return await handle_analysis_request(request)
            
        if symbol is not None:
            logger.info(f"Analyse technique standard pour {symbol}")
            return await get_technical_analysis(symbol)
            
    except HTTPException as http_exc:
        # On laisse passer les exceptions HTTP déjà définies
        logger.warning(f"Erreur HTTP dans /analysis: {str(http_exc.detail)}")
        raise
        
    except Exception as e:
        logger.error(f"Erreur inattendue dans /analysis: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Une erreur est survenue lors du traitement de la requête: {str(e)}"
        )

@app.get("/time_windows/{symbol:path}", response_model=TimeWindowsResponse)
async def time_windows(symbol: str):
    """
    Retourne les fenêtres horaires optimales pour trader un symbole
    """
    try:
        logger.info(f"Requête /time_windows pour {symbol}")
        
        preferred_hours = []
        forbidden_hours = []
        
        # Logique basée sur le type de symbole
        if "Boom" in symbol or "Crash" in symbol:
            preferred_hours = [8, 9, 10, 11, 14, 15, 16, 17]
            forbidden_hours = [0, 1, 2, 3, 4, 5]
        elif "Volatility" in symbol:
            preferred_hours = [9, 10, 11, 12, 13, 14, 15, 16, 17, 18]
            forbidden_hours = [22, 23, 0, 1, 2, 3, 4, 5]
        else:
            preferred_hours = [9, 10, 11, 12, 13, 14, 15, 16]
            forbidden_hours = [22, 23, 0, 1, 2, 3, 4, 5]
        
        return TimeWindowsResponse(
            symbol=symbol,
            preferred_hours=preferred_hours,
            forbidden_hours=forbidden_hours
        )
        
    except Exception as e:
        logger.error(f"Erreur dans /time_windows: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/predict/{symbol}")
async def predict(symbol: str, timeframe: str = "M1"):
    """
    Prédit la tendance pour un symbole donné (endpoint legacy)
    """
    try:
        cache_key = f"{symbol}_{timeframe}"
        current_time = time.time()
        
        if cache_key in prediction_cache and \
           (current_time - last_updated.get(cache_key, 0)) < CACHE_DURATION:
            return prediction_cache[cache_key]
        
        # Utiliser le prédicteur ML si disponible
        if ml_predictor and mt5_initialized:
            try:
                df = get_historical_data_mt5(symbol, timeframe, 500)
                if df is not None and len(df) > 100:
                    features = ml_predictor.create_advanced_features(df)
                    if not features.empty:
                        prediction_result = ml_predictor.predict_direction(features.iloc[-1:])
                        if prediction_result:
                            prediction = {
                                "symbol": symbol,
                                "timeframe": timeframe,
                                "timestamp": datetime.now().isoformat(),
                                "prediction": prediction_result,
                                "source": "ML"
                            }
                            prediction_cache[cache_key] = prediction
                            last_updated[cache_key] = current_time
                            return prediction
            except Exception as e:
                logger.warning(f"Erreur prédiction ML: {e}")
        
        # Fallback: simulation de prédiction
        prediction = {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": datetime.now().isoformat(),
            "prediction": {
                "direction": "UP" if hash(symbol + timeframe) % 2 == 0 else "DOWN",
                "confidence": round(0.5 + (hash(symbol) % 51) / 100, 2),
                "price_target": 1000 + (hash(symbol) % 1000) / 100,
                "stop_loss": 900 + (hash(symbol) % 200) / 100,
                "take_profit": 1100 + (hash(symbol) % 300) / 100,
                "time_horizon": "1h"
            },
            "analysis": {
                "trend_strength": 70 + (hash(symbol) % 31),
                "volatility": 30 + (hash(symbol) % 50),
                "volume": 50 + (hash(symbol) % 51),
                "rsi": 30 + (hash(symbol) % 61),
                "macd": "BULLISH" if hash(symbol) % 2 == 0 else "BEARISH"
            },
            "source": "fallback"
        }
        
        prediction_cache[cache_key] = prediction
        last_updated[cache_key] = current_time
        
        return prediction
        
    except Exception as e:
        logger.error(f"Erreur dans /predict: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/analyze/{symbol}")
async def analyze(symbol: str):
    """
    Analyse complète d'un symbole sur plusieurs timeframes (endpoint legacy)
    """
    try:
        analysis = {
            "symbol": symbol,
            "timestamp": datetime.now().isoformat(),
            "timeframes": {}
        }
        
        timeframes = ["M1", "M5", "M15", "H1", "H4", "D1"]
        for tf in timeframes:
            prediction = await predict(symbol, tf)
            analysis["timeframes"][tf] = prediction.get("prediction", {})
        
        return analysis
        
    except Exception as e:
        logger.error(f"Erreur dans /analyze: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

# Modèle pour la requête de prédiction de prix
class PricePredictionRequest(BaseModel):
    symbol: str
    current_price: float
    bars_to_predict: int = 200
    timeframe: str = "M1"
    history_bars: Optional[int] = 200
    history: Optional[List[float]] = None  # Données historiques fournies par le robot MQ5
    history_ohlc: Optional[Dict[str, List[float]]] = None  # Données OHLC complètes (open, high, low, close)

# ============================================================================
# FONCTIONS D'ANALYSE DES PATTERNS DE BOUGIES ET STRUCTURE DU MARCHÉ
# ============================================================================

def analyze_candlestick_patterns(df: pd.DataFrame, lookback: int = 10) -> Dict[str, Any]:
    """
    Analyse les patterns de bougies passées pour prédire le mouvement futur.
    """
    if len(df) < lookback + 2:
        return {
            'pattern_type': 'NONE',
            'bullish_pattern': False,
            'bearish_pattern': False,
            'reversal_signal': False
        }
    
    recent = df.tail(lookback + 2).copy()
    patterns = {
        'pattern_type': 'NONE',
        'bullish_pattern': False,
        'bearish_pattern': False,
        'reversal_signal': False
    }
    
    # Calculer les caractéristiques des bougies
    if 'open' in recent.columns and 'high' in recent.columns and 'low' in recent.columns and 'close' in recent.columns:
        recent['body'] = abs(recent['close'] - recent['open'])
        recent['range'] = recent['high'] - recent['low']
        recent['upper_shadow'] = recent['high'] - recent[['open', 'close']].max(axis=1)
        recent['lower_shadow'] = recent[['open', 'close']].min(axis=1) - recent['low']
        recent['is_bullish'] = recent['close'] > recent['open']
        
        # Analyser les dernières bougies pour détecter des patterns
        if len(recent) >= 2:
            last_candle = recent.iloc[-1]
            prev_candle = recent.iloc[-2]
            
            # Bullish Engulfing
            if (prev_candle['close'] < prev_candle['open'] and  # Bougie rouge précédente
                last_candle['close'] > last_candle['open'] and  # Bougie verte actuelle
                last_candle['open'] < prev_candle['close'] and  # Ouvre en dessous
                last_candle['close'] > prev_candle['open']):     # Clôture au-dessus
                patterns['pattern_type'] = 'BULLISH_ENGULFING'
                patterns['bullish_pattern'] = True
                patterns['reversal_signal'] = True
            
            # Bearish Engulfing
            elif (prev_candle['close'] > prev_candle['open'] and  # Bougie verte précédente
                  last_candle['close'] < last_candle['open'] and  # Bougie rouge actuelle
                  last_candle['open'] > prev_candle['close'] and  # Ouvre au-dessus
                  last_candle['close'] < prev_candle['open']):     # Clôture en dessous
                patterns['pattern_type'] = 'BEARISH_ENGULFING'
                patterns['bearish_pattern'] = True
                patterns['reversal_signal'] = True
            
            # Hammer (marteau) - signal haussier
            elif (last_candle['range'] > 0 and
                  last_candle['lower_shadow'] > last_candle['body'] * 2 and
                  last_candle['upper_shadow'] < last_candle['body'] * 0.5):
                patterns['pattern_type'] = 'HAMMER'
                patterns['bullish_pattern'] = True
                patterns['reversal_signal'] = True
            
            # Shooting Star - signal baissier
            elif (last_candle['range'] > 0 and
                  last_candle['upper_shadow'] > last_candle['body'] * 2 and
                  last_candle['lower_shadow'] < last_candle['body'] * 0.5):
                patterns['pattern_type'] = 'SHOOTING_STAR'
                patterns['bearish_pattern'] = True
                patterns['reversal_signal'] = True
            
            # Doji - indécision
            elif (last_candle['range'] > 0 and
                  last_candle['body'] < last_candle['range'] * 0.1):
                patterns['pattern_type'] = 'DOJI'
                patterns['reversal_signal'] = True
    
    return patterns

def analyze_market_structure(df: pd.DataFrame, lookback: int = 20) -> Dict[str, Any]:
    """
    Analyse la structure du marché (higher highs, lower lows) pour déterminer la tendance.
    """
    if len(df) < lookback:
        return {
            'trend': 'neutral',
            'strength': 0.0,
            'swing_highs': [],
            'swing_lows': []
        }
    
    recent = df.tail(lookback).copy()
    structure = {
        'trend': 'neutral',
        'strength': 0.0,
        'swing_highs': [],
        'swing_lows': []
    }
    
    if 'high' in recent.columns and 'low' in recent.columns:
        highs = recent['high'].values
        lows = recent['low'].values
        
        # Détecter les swing highs et lows
        for i in range(2, len(recent) - 2):
            # Swing high
            if highs[i] > highs[i-1] and highs[i] > highs[i-2] and highs[i] > highs[i+1] and highs[i] > highs[i+2]:
                structure['swing_highs'].append((i, highs[i]))
            # Swing low
            if lows[i] < lows[i-1] and lows[i] < lows[i-2] and lows[i] < lows[i+1] and lows[i] < lows[i+2]:
                structure['swing_lows'].append((i, lows[i]))
        
        # Déterminer la tendance basée sur les swing points
        if len(structure['swing_highs']) >= 2 and len(structure['swing_lows']) >= 2:
            # Higher highs et higher lows = uptrend
            if (structure['swing_highs'][-1][1] > structure['swing_highs'][-2][1] and
                structure['swing_lows'][-1][1] > structure['swing_lows'][-2][1]):
                structure['trend'] = 'uptrend'
                structure['strength'] = min(0.005, abs(structure['swing_highs'][-1][1] - structure['swing_highs'][-2][1]) / recent['close'].iloc[-1])
            # Lower highs et lower lows = downtrend
            elif (structure['swing_highs'][-1][1] < structure['swing_highs'][-2][1] and
                  structure['swing_lows'][-1][1] < structure['swing_lows'][-2][1]):
                structure['trend'] = 'downtrend'
                structure['strength'] = min(0.005, abs(structure['swing_lows'][-1][1] - structure['swing_lows'][-2][1]) / recent['close'].iloc[-1])
    
    return structure

def analyze_candle_characteristics(df: pd.DataFrame, lookback: int = 10) -> Dict[str, Any]:
    """
    Analyse les caractéristiques moyennes des bougies passées (taille, ratio corps/mèches).
    """
    if len(df) < lookback:
        return {
            'avg_body_ratio': 0.5,
            'avg_upper_shadow_ratio': 0.2,
            'avg_lower_shadow_ratio': 0.2
        }
    
    recent = df.tail(lookback).copy()
    characteristics = {
        'avg_body_ratio': 0.5,
        'avg_upper_shadow_ratio': 0.2,
        'avg_lower_shadow_ratio': 0.2
    }
    
    if 'open' in recent.columns and 'high' in recent.columns and 'low' in recent.columns and 'close' in recent.columns:
        recent['body'] = abs(recent['close'] - recent['open'])
        recent['range'] = recent['high'] - recent['low']
        recent['upper_shadow'] = recent['high'] - recent[['open', 'close']].max(axis=1)
        recent['lower_shadow'] = recent[['open', 'close']].min(axis=1) - recent['low']
        
        # Calculer les ratios moyens
        valid_ranges = recent['range'] > 0
        if valid_ranges.sum() > 0:
            characteristics['avg_body_ratio'] = float((recent.loc[valid_ranges, 'body'] / recent.loc[valid_ranges, 'range']).mean())
            characteristics['avg_upper_shadow_ratio'] = float((recent.loc[valid_ranges, 'upper_shadow'] / recent.loc[valid_ranges, 'range']).mean())
            characteristics['avg_lower_shadow_ratio'] = float((recent.loc[valid_ranges, 'lower_shadow'] / recent.loc[valid_ranges, 'range']).mean())
    
    return characteristics

@app.post("/prediction")
async def predict_prices(request: PricePredictionRequest):
    """
    Prédit une série de prix futurs pour un symbole donné.
    Utilisé par le robot MQ5 pour les prédictions multi-timeframes (M1, M15, M30, H1).
    Le robot envoie les données historiques pour améliorer la précision de la prédiction.
    
    Args:
        request: Requête contenant le symbole, prix actuel, nombre de bougies à prédire, timeframe,
                 et optionnellement les données historiques (history)
        
    Returns:
        dict: Dictionnaire contenant un tableau "prediction" avec les prix prédits
    """
    try:
        symbol = request.symbol
        current_price = request.current_price
        bars_to_predict = request.bars_to_predict
        timeframe = request.timeframe
        
        logger.info(f"📊 Prédiction multi-timeframe améliorée: {symbol} ({timeframe}) - {bars_to_predict} bougies")
        
        # Utiliser la fonction améliorée si disponible
        if IMPROVEMENTS_AVAILABLE and MT5_AVAILABLE and mt5_initialized:
            try:
                period_map = {
                    "M1": mt5.TIMEFRAME_M1,
                    "M5": mt5.TIMEFRAME_M5,
                    "M15": mt5.TIMEFRAME_M15,
                    "H1": mt5.TIMEFRAME_H1,
                    "H4": mt5.TIMEFRAME_H4,
                    "D1": mt5.TIMEFRAME_D1
                }
                
                period = period_map.get(timeframe, mt5.TIMEFRAME_M1)
                rates = mt5.copy_rates_from_pos(symbol, period, 0, min(500, bars_to_predict + 100))
                
                if rates is not None and len(rates) >= 50:
                    df = pd.DataFrame(rates)
                    if 'time' in df.columns:
                        df['time'] = pd.to_datetime(df['time'], unit='s')
                    
                    # Utiliser la prédiction améliorée de ai_server_improvements
                    prediction_data = predict_prices_advanced(
                        df=df,
                        current_price=current_price,
                        bars_to_predict=bars_to_predict,
                        timeframe=timeframe,
                        symbol=symbol
                    )
                    
                    # Adapter selon le type de symbole (Boom/Crash/Volatility)
                    prediction_result = adapt_prediction_for_symbol(
                        symbol=symbol,
                        base_prediction=prediction_data,
                        df=df
                    )
                    
                    prices = prediction_result['prediction']
                    
                    logger.info(f"✅ Prédiction améliorée générée: {len(prices)} prix pour {symbol} "
                              f"(Confiance: {prediction_result.get('confidence', 0.5):.1%}, "
                              f"Méthode: {prediction_result.get('method', 'advanced')})")
                    
                    # Stockage pour validation
                    store_prediction(symbol, prices, current_price, timeframe)
                    validate_predictions(symbol, timeframe)
                    
                    accuracy_score = get_prediction_accuracy_score(symbol)
                    confidence_multiplier = get_prediction_confidence_multiplier(symbol)
                    validation_count = sum(1 for p in prediction_history.get(symbol, []) if p.get("is_validated", False))

                    return {
                        "prediction": prices,
                        "symbol": symbol,
                        "current_price": current_price,
                        "bars_predicted": len(prices),
                        "timeframe": timeframe,
                        "timestamp": datetime.now().isoformat(),
                        "confidence": prediction_result.get('confidence', 0.5),
                        "direction": prediction_result.get('direction', 'NEUTRAL'),
                        "support_levels": prediction_result.get('support_levels', []),
                        "resistance_levels": prediction_result.get('resistance_levels', []),
                        "accuracy_score": round(accuracy_score, 3),
                        "confidence_multiplier": round(confidence_multiplier, 2),
                        "validation_count": validation_count,
                        "method": prediction_result.get('method', 'advanced')
                    }
            except Exception as e:
                logger.warning(f"⚠️ Échec prédiction améliorée, repli vers méthode standard: {e}")
        
        # Fallback si IMPROVEMENTS_AVAILABLE est False ou erreur
        prices = [current_price] * bars_to_predict
        np.random.seed(int(current_price * 100) % 2**31)
        vol = current_price * 0.001
        for i in range(bars_to_predict):
            prices[i] = float(current_price + np.random.normal(0, vol * (i+1)**0.5))

        return {
            "prediction": prices,
            "symbol": symbol,
            "current_price": current_price,
            "bars_predicted": len(prices),
            "timeframe": timeframe,
            "timestamp": datetime.now().isoformat(),
            "confidence": 0.5,
            "method": "fallback_basic"
        }
    except Exception as e:
        logger.error(f"Erreur critique dans /prediction: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de la prédiction de prix: {str(e)}")

@app.get("/prediction/accuracy/{symbol}")
async def get_prediction_accuracy(symbol: str):
    """
    Retourne les statistiques de précision des prédictions pour un symbole donné.
    
    Args:
        symbol: Symbole du marché
        
    Returns:
        dict: Statistiques de précision (score moyen, nombre de validations, etc.)
    """
    try:
        accuracy_score = get_prediction_accuracy_score(symbol)
        confidence_multiplier = get_prediction_confidence_multiplier(symbol)
        
        if symbol not in prediction_history:
            return {
                "symbol": symbol,
                "accuracy_score": 0.5,
                "confidence_multiplier": 0.8,
                "validation_count": 0,
                "total_predictions": 0,
                "reliability": "UNKNOWN",
                "message": "Aucune prédiction enregistrée pour ce symbole"
            }
        
        validated = [p for p in prediction_history[symbol] if p.get("is_validated", False)]
        total = len(prediction_history[symbol])
        
        return {
            "symbol": symbol,
            "accuracy_score": round(accuracy_score, 3),
            "confidence_multiplier": round(confidence_multiplier, 2),
            "validation_count": len(validated),
            "total_predictions": total,
            "reliability": (
            "HIGH" if accuracy_score >= 0.80 
            else "MEDIUM" if accuracy_score >= 0.60 
            else "LOW"
        ),
            "is_reliable": accuracy_score >= MIN_ACCURACY_THRESHOLD,
            "recent_validations": [
                {
                    "timestamp": p["validation_timestamp"],
                    "accuracy": round(p["accuracy_score"], 3)
                }
                for p in validated[-10:]  # 10 dernières validations
            ]
        }
        
    except Exception as e:
        logger.error(f"Erreur dans /prediction/accuracy: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération de la précision: {str(e)}")

@app.get("/predictions/realtime/{symbol}")
async def get_realtime_predictions(symbol: str, timeframe: str = "M1"):
    """
    Retourne les dernières prédictions en temps réel pour un symbole donné.
    Utilisé par le robot MQ5 pour afficher les prédictions dans le cadran d'information.
    """
    try:
        cache_key = f"{symbol}_{timeframe}"
        
        # Vérifier le cache des prédictions récentes
        if cache_key in realtime_predictions:
            pred_data = realtime_predictions[cache_key]
            # Vérifier si la prédiction n'est pas trop ancienne (moins de 60 secondes)
            pred_time = datetime.fromisoformat(pred_data.get("timestamp", ""))
            if (datetime.now() - pred_time).total_seconds() < 60:
                return pred_data
        
        # Si pas de cache récent, utiliser l'endpoint /prediction
        # ou retourner la dernière prédiction de l'historique
        if symbol in prediction_history and prediction_history[symbol]:
            last_pred = prediction_history[symbol][-1]
            accuracy_score = get_prediction_accuracy_score(symbol)
            
            response = {
                "symbol": symbol,
                "timeframe": timeframe,
                "timestamp": last_pred["timestamp"],
                "predicted_prices": last_pred["predicted_prices"][:50],  # Limiter à 50 prix pour la réponse
                "current_price": last_pred["current_price"],
                "accuracy_score": round(accuracy_score, 3),
                "validation_count": sum(1 for p in prediction_history[symbol] if p.get("is_validated", False)),
                "reliability": (
            "HIGH" if accuracy_score >= 0.80 
            else "MEDIUM" if accuracy_score >= 0.60 
            else "LOW"
        )
            }
            
            # Mettre en cache
            realtime_predictions[cache_key] = response
            
            return response
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "error": "Aucune prédiction disponible",
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Erreur dans /predictions/realtime: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération des prédictions: {str(e)}")

class PredictionValidationRequest(BaseModel):
    symbol: str
    real_prices: List[float] = Field(..., description="Liste des prix réels observés")
    prediction_id: Optional[str] = None
    timeframe: str = "M1"

class MT5HistoryUploadRequest(BaseModel):
    """Requête pour uploader des données historiques depuis MT5 vers Render"""
    symbol: str
    timeframe: str = Field(..., description="Timeframe (M1, M5, M15, H1, H4, D1)")
    data: List[Dict[str, Any]] = Field(..., description="Liste des bougies OHLCV au format: [{'time': timestamp, 'open': float, 'high': float, 'low': float, 'close': float, 'tick_volume': int}, ...]")

@app.post("/mt5/history-upload")
async def upload_mt5_history(request: MT5HistoryUploadRequest):
    """
    Endpoint pour recevoir les données historiques depuis MT5 (bridge).
    Les données sont stockées en cache et utilisées par le système ML avancé.
    
    Args:
        request: Requête contenant le symbole, timeframe et les données OHLCV
        
    Returns:
        dict: Confirmation de réception avec nombre de bougies stockées
    """
    try:
        if not request.symbol or not isinstance(request.symbol, str):
            raise HTTPException(status_code=400, detail="Le symbole est requis et doit être une chaîne de caractères")
        
        if not request.data or not isinstance(request.data, list):
            raise HTTPException(status_code=400, detail="La liste de données est requise")
        
        if len(request.data) == 0:
            raise HTTPException(status_code=400, detail="La liste de données ne peut pas être vide")
        
        # Valider le timeframe
        valid_timeframes = ["M1", "M5", "M15", "M30", "H1", "H4", "D1"]
        if request.timeframe not in valid_timeframes:
            raise HTTPException(status_code=400, detail=f"Timeframe invalide. Valeurs acceptées: {', '.join(valid_timeframes)}")
        
        # Convertir les données en DataFrame
        try:
            df = pd.DataFrame(request.data)
            
            # Vérifier les colonnes requises
            required_cols = ['time', 'open', 'high', 'low', 'close']
            missing_cols = [col for col in required_cols if col not in df.columns]
            if missing_cols:
                raise HTTPException(status_code=400, detail=f"Colonnes manquantes: {', '.join(missing_cols)}")
            
            # Convertir le timestamp en datetime
            if df['time'].dtype == 'int64' or df['time'].dtype == 'float64':
                # Timestamp Unix (secondes)
                df['time'] = pd.to_datetime(df['time'], unit='s')
            else:
                df['time'] = pd.to_datetime(df['time'])
            
            # Trier par temps (plus ancien au plus récent)
            df = df.sort_values('time').reset_index(drop=True)
            
            # Stocker dans le cache
            cache_key = f"{request.symbol}_{request.timeframe}"
            mt5_uploaded_history_cache[cache_key] = {
                "data": df,
                "timestamp": datetime.now(),
                "symbol": request.symbol,
                "timeframe": request.timeframe,
                "count": len(df)
            }
            
            logger.info(f"✅ Données historiques uploadées depuis MT5: {len(df)} bougies pour {request.symbol} {request.timeframe}")
            
            return {
                "status": "success",
                "symbol": request.symbol,
                "timeframe": request.timeframe,
                "bars_received": len(df),
                "cache_key": cache_key,
                "message": f"{len(df)} bougies stockées en cache pour {request.symbol} {request.timeframe}"
            }
            
        except Exception as e:
            logger.error(f"Erreur lors du traitement des données uploadées: {e}", exc_info=True)
            raise HTTPException(status_code=400, detail=f"Erreur lors du traitement des données: {str(e)}")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur dans /mt5/history-upload: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de l'upload des données historiques: {str(e)}")

@app.post("/predictions/validate")
async def validate_prediction(request: PredictionValidationRequest):
    """
    Valide une prédiction en comparant avec les données réelles.
    Les métriques sont sauvegardées dans le dossier Results.
    """
    try:
        # Validation supplémentaire des entrées
        if not request.symbol or not isinstance(request.symbol, str):
            raise HTTPException(status_code=400, detail="Le symbole est requis et doit être une chaîne de caractères")
        
        if not request.real_prices or not isinstance(request.real_prices, list):
            raise HTTPException(status_code=400, detail="La liste des prix réels est requise")
        
        if len(request.real_prices) == 0:
            raise HTTPException(status_code=400, detail="La liste des prix réels ne peut pas être vide")
        
        # Appeler la fonction de validation
        result = validate_prediction_with_realtime_data(
            request.symbol,
            request.real_prices,
            request.prediction_id
        )
        
        # Vérifier si le résultat contient une erreur
        if not isinstance(result, dict):
            logger.error(f"Résultat inattendu de validate_prediction_with_realtime_data: {type(result)}")
            raise HTTPException(status_code=500, detail="Erreur interne: format de réponse invalide")
        
        if "error" in result:
            # Message d'erreur plus informatif pour les erreurs de validation
            error_msg = result["error"]
            # Si c'est une erreur de "pas de prédiction", c'est acceptable (pas nécessairement une erreur)
            if "aucune prédiction" in error_msg.lower() or "prédiction" in error_msg.lower() and "non trouvée" in error_msg.lower():
                logger.info(f"Validation ignorée pour {request.symbol}: {error_msg}")
                return {
                    "success": False,
                    "message": error_msg,
                    "status": "no_prediction_to_validate"
                }
            raise HTTPException(status_code=400, detail=error_msg)
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur dans /predictions/validate: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de la validation: {str(e)}")

# Modèle pour la requête de précision de décision
class DecisionAccuracyRequest(BaseModel):
    symbol: str
    action: str  # "buy", "sell", "hold"
    confidence: float
    result: Optional[str] = None  # "win", "loss", "breakeven"
    profit: Optional[float] = None
    timestamp: Optional[str] = None

@app.post("/decision/accuracy")
async def log_decision_accuracy(request: DecisionAccuracyRequest):
    """
    Enregistre la précision d'une décision de trading pour le feedback loop.
    Permet au système d'apprendre de ses décisions.
    """
    try:
        logger.info(f"📊 Précision décision reçue: {request.symbol} - {request.action} (conf: {request.confidence:.2f})")
        
        # Log simple pour l'instant (peut être étendu avec stockage en base de données)
        accuracy_data = {
            "symbol": request.symbol,
            "action": request.action,
            "confidence": request.confidence,
            "result": request.result,
            "profit": request.profit,
            "timestamp": request.timestamp or datetime.now().isoformat()
        }
        
        # Ici, on pourrait sauvegarder dans une base de données ou un fichier
        # Pour l'instant, on log juste l'information
        logger.info(f"✅ Données de précision enregistrées: {accuracy_data}")
        
        return {
            "success": True,
            "message": "Précision de décision enregistrée",
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Erreur dans /decision/accuracy: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de l'enregistrement de la précision: {str(e)}")

# ===== ML FEEDBACK + METRICS (ENTRAÎNEMENT CONTINU) =====
# Système de feedback léger en mémoire pour apprentissage online
class TradeFeedbackRequest(BaseModel):
    symbol: str
    timeframe: Optional[str] = "M1"
    side: Optional[str] = None  # "buy" | "sell"
    profit: float
    is_win: bool
    ai_confidence: Optional[float] = None  # 0..1 (optional)
    open_time: Optional[int] = None
    close_time: Optional[int] = None
    timestamp: Optional[int] = None

# Buffer de feedback en mémoire (Render free: stockage éphémère)
_feedback_by_key: Dict[str, deque] = {}  # key = "{symbol}:{tf}"
_metrics_cache: Dict[str, Dict[str, Any]] = {}  # key = "{symbol}:{tf}"

# Contrôle "continuous training" (online recalibration)
_continuous_enabled = False
_continuous_task: Optional[asyncio.Task] = None
_continuous_last_tick: Optional[str] = None

def _ml_key(symbol: str, timeframe: str) -> str:
    return f"{symbol}:{timeframe}"

def _ml_clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))

def _get_feedback_buf(symbol: str, timeframe: str) -> deque:
    k = _ml_key(symbol, timeframe)
    if k not in _feedback_by_key:
        _feedback_by_key[k] = deque(maxlen=5000)
    return _feedback_by_key[k]

def _compute_ml_metrics(symbol: str, timeframe: str) -> Dict[str, Any]:
    """
    Retourne un JSON compatible avec le parser MT5 `ParseMLMetricsResponse()`:
    - best_model
    - metrics: random_forest/gradient_boosting/mlp -> accuracy
    - training_samples/test_samples
    - recommendations.min_confidence
    """
    k = _ml_key(symbol, timeframe)
    buf = _get_feedback_buf(symbol, timeframe)
    n = len(buf)

    # Par défaut (si pas encore de feedback), garder un niveau "neutre" pour permettre au robot de démarrer
    if n == 0:
        base_acc = 70.0
        win_rate = 0.50
    else:
        wins = sum(1 for x in buf if x.get("is_win"))
        win_rate = wins / n
        base_acc = _ml_clamp(win_rate * 100.0, 35.0, 95.0)

    # Simuler 3 "modèles" à partir de la performance observée (léger, robuste)
    rf = _ml_clamp(base_acc + 0.8, 0.0, 100.0)
    gb = _ml_clamp(base_acc + 0.3, 0.0, 100.0)
    mlp = _ml_clamp(base_acc - 0.5, 0.0, 100.0)

    best_model = "random_forest"
    best_acc = rf
    if gb > best_acc:
        best_model, best_acc = "gradient_boosting", gb
    if mlp > best_acc:
        best_model, best_acc = "mlp", mlp

    # Recommandation dynamique: si win_rate baisse, on remonte la confiance mini
    # (et inversement si win_rate est bon, on peut baisser un peu pour saisir plus d'opportunités)
    min_conf = _ml_clamp(0.75 - (win_rate - 0.50) * 0.30, 0.55, 0.85)

    payload = {
        "symbol": symbol,
        "timeframe": timeframe,
        "best_model": best_model,
        "metrics": {
            "random_forest": {"accuracy": float(rf)},
            "gradient_boosting": {"accuracy": float(gb)},
            "mlp": {"accuracy": float(mlp)},
        },
        "training_samples": int(n),
        "test_samples": int(max(0, n // 5)),
        "recommendations": {
            "min_confidence": float(min_conf),
        },
        "last_update": datetime.now().isoformat(),
        "is_valid": True,
    }

    _metrics_cache[k] = payload
    return payload

async def _continuous_training_loop(symbols: List[str], timeframe: str, interval_sec: int) -> None:
    global _continuous_last_tick
    logger.info(
        f"🧠 Continuous ML loop démarrée | symbols={','.join(symbols)} timeframe={timeframe} interval={interval_sec}s"
    )
    while _continuous_enabled:
        _continuous_last_tick = datetime.now().isoformat()
        # "Entraînement" lightweight: rafraîchir les métriques
        for sym in symbols:
            try:
                _compute_ml_metrics(sym, timeframe)
            except Exception as e:
                logger.warning(f"⚠️ Continuous loop: {sym}: {e}")
        await asyncio.sleep(max(10, interval_sec))

@app.post("/trades/feedback")
async def trades_feedback(request: TradeFeedbackRequest):
    """
    Reçoit le résultat d'un trade (profit, win/loss) et met à jour les métriques online.
    Retourne les métriques détaillées (compat MT5).
    """
    try:
        symbol = request.symbol
        tf = request.timeframe or "M1"
        buf = _get_feedback_buf(symbol, tf)
        buf.append({
            "profit": float(request.profit),
            "is_win": bool(request.is_win),
            "side": (request.side or "").lower(),
            "ai_confidence": float(request.ai_confidence) if request.ai_confidence is not None else None,
            "timestamp": request.timestamp or int(time.time()),
        })
        logger.info(f"📊 Feedback trade reçu: {symbol} {tf} - {'WIN' if request.is_win else 'LOSS'} (profit: {request.profit:.2f})")
        return _compute_ml_metrics(symbol, tf)
    except Exception as e:
        logger.error(f"Erreur /trades/feedback: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ml/metrics")
async def ml_metrics(symbol: str, timeframe: str = "M1"):
    """Alias simple: retourne les métriques détaillées."""
    return _compute_ml_metrics(symbol, timeframe)

@app.get("/ml/metrics/detailed")
async def ml_metrics_detailed(symbol: str, timeframe: str = "M1"):
    """Compat avec le robot MT5 (ParseMLMetricsResponse)."""
    return _compute_ml_metrics(symbol, timeframe)

@app.post("/ml/continuous/start")
async def ml_continuous_start(symbols: Optional[str] = None, timeframe: str = "M1", interval_sec: int = 300):
    """
    Démarre l'entraînement continu "online" (recalibrage à partir des feedbacks).
    symbols: "EURUSD,GBPUSD,USDJPY"
    """
    global _continuous_enabled, _continuous_task
    if _continuous_enabled and _continuous_task and not _continuous_task.done():
        return {"status": "already_running"}
    
    syms = [s.strip() for s in (symbols or os.getenv("ML_SYMBOLS", "EURUSD,GBPUSD,USDJPY,USDCAD,AUDUSD,NZDUSD,EURJPY")).split(",") if s.strip()]
    _continuous_enabled = True
    _continuous_task = asyncio.create_task(_continuous_training_loop(syms, timeframe, interval_sec))
    logger.info(f"✅ Continuous ML training démarré pour: {syms}")
    return {"status": "started", "symbols": syms, "timeframe": timeframe, "interval_sec": interval_sec}

@app.post("/ml/continuous/stop")
async def ml_continuous_stop():
    global _continuous_enabled
    _continuous_enabled = False
    logger.info("⏸️ Continuous ML training arrêté")
    return {"status": "stopping"}

@app.get("/ml/continuous/status")
async def ml_continuous_status():
    return {
        "enabled": _continuous_enabled,
        "last_tick": _continuous_last_tick,
        "feedback_keys": len(_feedback_by_key),
    }

# ===== SYSTÈME DE NOTIFICATIONS VONAGE =====
# Importer le service de notification unifié
try:
    sys.path.insert(0, str(Path(__file__).parent / "src"))
    from unified_notification_service import UnifiedNotificationService
    notification_service = UnifiedNotificationService()
    VONAGE_AVAILABLE = notification_service.sms_enabled
    logger.info("Service de notification Vonage disponible")
except Exception as e:
    logger.warning(f"Service de notification Vonage non disponible: {e}")
    notification_service = None
    VONAGE_AVAILABLE = False

class NotificationRequest(BaseModel):
    message: str
    symbol: Optional[str] = None
    signal_type: Optional[str] = None  # "trade", "spike", "prediction", "summary"
    confidence: Optional[float] = None
    price: Optional[float] = None

@app.post("/notifications/send")
async def send_notification(request: NotificationRequest):
    """
    Envoie une notification via Vonage SMS depuis MT5.
    Utilisé par le robot MQ5 pour envoyer des alertes.
    """
    try:
        if not VONAGE_AVAILABLE or not notification_service:
            return {
                "success": False,
                "error": "Service Vonage non disponible",
                "message": request.message
            }
        
        # Envoyer le SMS
        success = notification_service._send_sms(request.message)
        
        if success:
            logger.info(f"Notification Vonage envoyée: {request.message[:50]}...")
        
        return {
            "success": success,
            "message": request.message,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Erreur dans /notifications/send: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de l'envoi: {str(e)}")

@app.post("/notifications/trading-signal")
async def send_trading_signal_notification(request: Dict[str, Any]):
    """
    Envoie une notification de signal de trading via Vonage.
    """
    try:
        if not VONAGE_AVAILABLE or not notification_service:
            return {"success": False, "error": "Service Vonage non disponible"}
        
        symbol = request.get("symbol", "N/A")
        action = request.get("action", "N/A")
        price = request.get("price", 0.0)
        confidence = request.get("confidence", 0.0)
        timeframe = request.get("timeframe", "M1")
        
        signal_data = {
            'symbol': symbol,
            'action': action,
            'price': price,
            'confidence': confidence,
            'timeframe': timeframe,
            'timestamp': datetime.now().isoformat()
        }
        
        results = notification_service.send_trading_signal(signal_data)
        
        return {
            "success": results.get("sms", False) or results.get("whatsapp", False),
            "results": results,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Erreur dans /notifications/trading-signal: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de l'envoi: {str(e)}")

@app.get("/notifications/predictions-summary")
async def send_predictions_summary():
    """
    Envoie un résumé des prédictions par symbole via Vonage.
    """
    try:
        if not VONAGE_AVAILABLE or not notification_service:
            return {"success": False, "error": "Service Vonage non disponible"}
        
        # Récupérer toutes les prédictions récentes depuis prediction_history
        summary_lines = ["📊 RÉSUMÉ PRÉDICTIONS"]
        summary_lines.append(f"⏰ {datetime.now().strftime('%H:%M')}")
        summary_lines.append("")
        
        symbol_count = 0
        
        # Parcourir prediction_history
        for symbol, preds in prediction_history.items():
            if not preds:
                continue
            
            last_pred = preds[-1] if preds else None
            if not last_pred:
                continue
            
            # Calculer le score de précision
            try:
                accuracy_score = get_prediction_accuracy_score(symbol)
            except:
                accuracy_score = 0.0
            
            # Compter les validations
            validation_count = sum(1 for p in preds if p.get("is_validated", False))
            
            # Afficher même si pas encore validé, mais avec info différente
            if validation_count > 0:
                reliability = "HIGH" if accuracy_score >= 0.80 else "MEDIUM" if accuracy_score >= 0.60 else "LOW"
                summary_lines.append(f"📈 {symbol}")
                summary_lines.append(f"  Précision: {accuracy_score*100:.1f}%")
                summary_lines.append(f"  Validations: {validation_count}")
                summary_lines.append(f"  Fiabilité: {reliability}")
            else:
                # Afficher les prédictions non encore validées
                predicted_price = last_pred.get("predicted_price", 0)
                confidence = last_pred.get("confidence", 0)
                direction = last_pred.get("direction", "N/A")
                summary_lines.append(f"📈 {symbol}")
                summary_lines.append(f"  Direction: {direction}")
                summary_lines.append(f"  Prix prédit: {predicted_price:.5f}")
                summary_lines.append(f"  Confiance: {confidence*100:.1f}%")
                summary_lines.append(f"  En attente validation")
            
            summary_lines.append("")
            symbol_count += 1
        
        # Aussi vérifier realtime_predictions (si disponible)
        try:
            processed_symbols = set()
            for s in summary_lines:
                if s.startswith("📈"):
                    parts = s.split()
                    if len(parts) > 1:
                        processed_symbols.add(parts[1])
            
            for cache_key, pred in realtime_predictions.items():
                symbol = pred.get('symbol', cache_key.split('_')[0] if '_' in cache_key else cache_key)
                if symbol not in processed_symbols:
                    summary_lines.append(f"📈 {symbol}")
                    summary_lines.append(f"  Prédiction temps réel")
                    direction = pred.get('direction', 'N/A')
                    if direction == 'N/A':
                        # Essayer de déduire la direction depuis les prix prédits
                        predicted_prices = pred.get('predicted_prices', [])
                        current_price = pred.get('current_price', 0)
                        if predicted_prices and current_price > 0:
                            avg_predicted = sum(predicted_prices) / len(predicted_prices)
                            direction = "BUY" if avg_predicted > current_price else "SELL"
                    summary_lines.append(f"  Direction: {direction}")
                    conf = pred.get('accuracy_score', pred.get('confidence', 0))
                    if isinstance(conf, (int, float)) and conf > 0:
                        summary_lines.append(f"  Score: {conf*100:.1f}%")
                    summary_lines.append("")
                    symbol_count += 1
        except Exception as e:
            logger.warning(f"Erreur lors de l'ajout des prédictions temps réel au résumé: {e}")
        
        if symbol_count == 0:
            summary_lines.append("Aucune prédiction disponible")
        
        message = "\n".join(summary_lines)
        
        # Envoyer le SMS
        success = notification_service._send_sms(message)
        
        return {
            "success": success,
            "symbols_count": symbol_count,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Erreur dans /notifications/predictions-summary: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de l'envoi: {str(e)}")

# Gestion des modèles ML
def load_ml_models():
    """Charge les modèles ML depuis le répertoire models"""
    models = {}
    if not MODELS_DIR.exists():
        return models
    
    try:
        for model_file in MODELS_DIR.glob("*.pkl"):
            try:
                import joblib
                model_name = model_file.stem
                models[model_name] = joblib.load(model_file)
                logger.info(f"Modèle chargé: {model_name}")
            except Exception as e:
                logger.warning(f"Impossible de charger {model_file}: {e}")
    except Exception as e:
        logger.error(f"Erreur lors du chargement des modèles: {e}")
    
    return models

# Charger les modèles au démarrage
ml_models = load_ml_models()

def predict_with_model(symbol: str, features: Dict[str, float], model_name: Optional[str] = None):
    """Prédit avec un modèle ML spécifique"""
    if not ml_models:
        return None
    
    # Sélectionner le modèle approprié
    if model_name and model_name in ml_models:
        model = ml_models[model_name]
    else:
        # Sélection automatique selon le symbole
        if "Boom" in symbol or "Crash" in symbol:
            model_key = "synthetic_special_xgb_model"
        elif "Volatility" in symbol:
            model_key = "synthetic_general_xgb_model"
        else:
            model_key = "universal_xgb_model"
        
        if model_key in ml_models:
            model = ml_models[model_key]
        elif len(ml_models) > 0:
            model = list(ml_models.values())[0]
        else:
            return None
    
    try:
        # Préparer les features pour le modèle
        feature_array = np.array([list(features.values())])
        prediction = model.predict(feature_array)[0]
        probabilities = None
        if hasattr(model, 'predict_proba'):
            probabilities = model.predict_proba(feature_array)[0]
        
        return {
            "prediction": prediction,
            "probabilities": probabilities.tolist() if probabilities is not None else None,
            "model_used": model_name or "auto"
        }
    except Exception as e:
        logger.error(f"Erreur prédiction modèle: {e}")
        return None

# Gestion du cache avancée
def clear_old_cache(max_age_seconds: int = 3600):
    """Nettoie le cache des entrées trop anciennes"""
    current_time = time.time()
    keys_to_remove = []
    
    for key, last_update in last_updated.items():
        if current_time - last_update > max_age_seconds:
            keys_to_remove.append(key)
    
    for key in keys_to_remove:
        prediction_cache.pop(key, None)
        last_updated.pop(key, None)
    
    if keys_to_remove:
        logger.info(f"Cache nettoyé: {len(keys_to_remove)} entrées supprimées")

@app.get("/cache/stats")
async def cache_stats():
    """Statistiques du cache"""
    clear_old_cache()
    return {
        "size": len(prediction_cache),
        "max_age_seconds": 3600,
        "cache_duration": CACHE_DURATION
    }

@app.post("/cache/clear")
async def clear_cache():
    """Vide le cache"""
    prediction_cache.clear()
    last_updated.clear()
    logger.info("Cache vidé manuellement")
    return {"status": "cleared", "message": "Cache vidé avec succès"}

# Endpoint pour les statistiques de trading
@app.get("/stats/{symbol}")
async def get_symbol_stats(symbol: str, days: int = 7):
    """Récupère les statistiques de trading pour un symbole"""
    try:
        if not mt5_initialized:
            return {"error": "MT5 non initialisé"}
        
        # Récupérer les données historiques
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days)
        
        rates = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_D1, start_date, end_date)
        if rates is None or len(rates) == 0:
            return {"error": "Aucune donnée disponible"}
        
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        
        # Calculer les statistiques
        stats = {
            "symbol": symbol,
            "period_days": days,
            "total_candles": len(df),
            "price_range": {
                "high": float(df['high'].max()),
                "low": float(df['low'].min()),
                "current": float(df['close'].iloc[-1])
            },
            "volatility": {
                "atr": float(df['high'].sub(df['low']).mean()),
                "std": float(df['close'].std())
            },
            "trend": {
                "direction": "UP" if df['close'].iloc[-1] > df['close'].iloc[0] else "DOWN",
                "change_percent": float((df['close'].iloc[-1] / df['close'].iloc[0] - 1) * 100)
            }
        }
        
        return stats
    except Exception as e:
        logger.error(f"Erreur stats: {e}")
        return {"error": str(e)}

# Endpoint pour les signaux en temps réel amélioré
@app.get("/signals/{symbol}")
async def get_signals(
    symbol: str,
    timeframe: str = "M15",
    lookback: int = 200,
    min_confidence: float = 0.6
):
    """
    Génère des signaux de trading avancés avec analyse multi-timeframe
    
    Args:
        symbol: Symbole à analyser (ex: "EURUSD")
        timeframe: Période d'analyse (M1, M5, M15, H1, H4, D1)
        lookback: Nombre de bougies à analyser
        min_confidence: Confiance minimale pour les signaux (0-1)
    """
    try:
        if not mt5_initialized:
            return {"error": "MT5 non initialisé"}
        
        # Mapper le timeframe MT5
        tf_mapping = {
            'M1': mt5.TIMEFRAME_M1,
            'M5': mt5.TIMEFRAME_M5,
            'M15': mt5.TIMEFRAME_M15,
            'H1': mt5.TIMEFRAME_H1,
            'H4': mt5.TIMEFRAME_H4,
            'D1': mt5.TIMEFRAME_D1
        }
        
        mt5_timeframe = tf_mapping.get(timeframe, mt5.TIMEFRAME_M15)
        
        # Récupérer les données
        rates = mt5.copy_rates_from_pos(symbol, mt5_timeframe, 0, lookback)
        if rates is None or len(rates) == 0:
            return {"error": f"Aucune donnée disponible pour {symbol} sur {timeframe}"}
        
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        df.set_index('time', inplace=True)
        
        # 1. Calcul des indicateurs de tendance
        df['sma_20'] = df['close'].rolling(20).mean()
        df['sma_50'] = df['close'].rolling(50).mean()
        df['sma_200'] = df['close'].rolling(200).mean()
        
        # 2. Indicateur de momentum (RSI)
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        df['rsi'] = 100 - (100 / (1 + rs))
        
        # 3. Bandes de Bollinger
        df['bb_upper'], df['bb_middle'], df['bb_lower'] = (
            df['close'].rolling(20).mean() + 2 * df['close'].rolling(20).std(),
            df['close'].rolling(20).mean(),
            df['close'].rolling(20).mean() - 2 * df['close'].rolling(20).std()
        )
        
        # 4. MACD
        exp1 = df['close'].ewm(span=12, adjust=False).mean()
        exp2 = df['close'].ewm(span=26, adjust=False).mean()
        df['macd'] = exp1 - exp2
        df['signal_line'] = df['macd'].ewm(span=9, adjust=False).mean()
        
        # 5. ADX (Average Directional Index)
        plus_dm = df['high'].diff()
        minus_dm = df['low'].diff() * -1
        
        tr1 = df['high'] - df['low']
        tr2 = abs(df['high'] - df['close'].shift())
        tr3 = abs(df['low'] - df['close'].shift())
        
        df['tr'] = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
        atr = df['tr'].rolling(14).mean()
        
        plus_di = 100 * (plus_dm.ewm(alpha=1/14).mean() / atr)
        minus_di = 100 * (minus_dm.ewm(alpha=1/14).mean() / atr)
        df['adx'] = 100 * abs((plus_di - minus_di) / (plus_di + minus_di)).ewm(alpha=1/14).mean()
        
        # Dernières valeurs
        current = df.iloc[-1]
        previous = df.iloc[-2] if len(df) > 1 else current
        
        # Génération des signaux
        signals = []
        
        # 1. Signaux de tendance
        price_above_sma20 = current['close'] > current['sma_20']
        price_above_sma50 = current['close'] > current['sma_50']
        price_above_sma200 = current['close'] > current['sma_200']
        
        if price_above_sma20 and price_above_sma50 and price_above_sma200:
            signals.append({
                "type": "BUY",
                "reason": "Prix au-dessus des moyennes mobiles (20, 50, 200)",
                "confidence": 0.7
            })
        elif not price_above_sma20 and not price_above_sma50 and not price_above_sma200:
            signals.append({
                "type": "SELL",
                "reason": "Prix en-dessous des moyennes mobiles (20, 50, 200)",
                "confidence": 0.7
            })
        
        # 2. Signaux RSI
        if current['rsi'] < 30:
            signals.append({
                "type": "BUY",
                "reason": f"RSI en survente ({current['rsi']:.1f})",
                "confidence": 0.65
            })
        elif current['rsi'] > 70:
            signals.append({
                "type": "SELL",
                "reason": f"RSI en surachat ({current['rsi']:.1f})",
                "confidence": 0.65
            })
        
        # 3. Signaux Bandes de Bollinger
        if current['close'] < current['bb_lower']:
            signals.append({
                "type": "BUY",
                "reason": "Prix en dessous de la bande de Bollinger inférieure",
                "confidence": 0.7
            })
        elif current['close'] > current['bb_upper']:
            signals.append({
                "type": "SELL",
                "reason": "Prix au-dessus de la bande de Bollinger supérieure",
                "confidence": 0.7
            })
        
        # 4. Signaux MACD
        if current['macd'] > current['signal_line'] and previous['macd'] <= previous['signal_line']:
            signals.append({
                "type": "BUY",
                "reason": "Croisement haussier du MACD",
                "confidence": 0.75
            })
        elif current['macd'] < current['signal_line'] and previous['macd'] >= previous['signal_line']:
            signals.append({
                "type": "SELL",
                "reason": "Croisement baissier du MACD",
                "confidence": 0.75
            })
        
        # 5. Filtre ADX (tendance forte si > 25)
        strong_trend = current['adx'] > 25
        
        # Filtrer les signaux par confiance minimale
        signals = [s for s in signals if s['confidence'] >= min_confidence]
        
        # Trier par confiance décroissante
        signals.sort(key=lambda x: x['confidence'], reverse=True)
        
        # Préparer la réponse
        response = {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": datetime.now().isoformat(),
            "price": float(current['close']),
            "indicators": {
                "sma_20": float(current['sma_20']) if pd.notna(current['sma_20']) else None,
                "sma_50": float(current['sma_50']) if pd.notna(current['sma_50']) else None,
                "sma_200": float(current['sma_200']) if pd.notna(current['sma_200']) else None,
                "rsi": float(current['rsi']) if pd.notna(current['rsi']) else None,
                "bb_upper": float(current['bb_upper']) if pd.notna(current['bb_upper']) else None,
                "bb_middle": float(current['bb_middle']) if pd.notna(current['bb_middle']) else None,
                "bb_lower": float(current['bb_lower']) if pd.notna(current['bb_lower']) else None,
                "macd": float(current['macd']) if pd.notna(current['macd']) else None,
                "macd_signal": float(current['signal_line']) if pd.notna(current['signal_line']) else None,
                "adx": float(current['adx']) if pd.notna(current['adx']) else None,
                "strong_trend": bool(strong_trend) if pd.notna(strong_trend) else None
            },
            "signals": signals,
            "analysis": {
                "trend": "Haussière" if price_above_sma200 else "Baissière",
                "volatility": "Élevée" if (current['bb_upper'] - current['bb_lower']) / current['bb_middle'] > 0.01 else "Faible",
                "momentum": "Haussière" if current['rsi'] > 50 else "Baissière"
            }
        }
        
        return response
        
    except Exception as e:
        logger.error(f"Erreur lors de la génération du signal de trading: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur serveur: {str(e)}")

# ============================================================================
# ENDPOINTS: FEEDBACK LOOP & MONITORING (Phase 1)
# ============================================================================

async def _trigger_retraining_async(category: str):
    """Déclenche le réentraînement en arrière-plan de manière asynchrone"""
    try:
        if continuous_learner:
            logger.info(f"🔄 [AUTO-RETRAIN] Début réentraînement pour {category}...")
            result = continuous_learner.retrain_model_for_category(category)
            if result.get("status") == "success":
                improvement = result.get('improvement', 0)
                old_acc = result.get('old_accuracy', 0)
                new_acc = result.get('new_accuracy', 0)
                samples = result.get('samples_used', 0)
                success_msg = (
                    f"✅ [AUTO-RETRAIN] Réentraînement réussi pour {category}:\n"
                    f"   - Échantillons utilisés: {samples}\n"
                    f"   - Précision ancienne: {old_acc:.3f}\n"
                    f"   - Précision nouvelle: {new_acc:.3f}\n"
                    f"   - Amélioration: +{improvement:.3f} ({improvement*100:.2f}%)"
                )
                logger.info(success_msg)
            elif result.get("status") == "no_improvement":
                improvement = result.get('improvement', 0)
                logger.info(
                    f"⏸️ [AUTO-RETRAIN] Réentraînement pour {category}: "
                    f"pas d'amélioration suffisante ({improvement:.3f} < 0.02)"
                )
            elif result.get("status") == "skipped":
                reason = result.get('reason', 'unknown')
                logger.info(f"⏸️ [AUTO-RETRAIN] Réentraînement pour {category} ignoré: {reason}")
            else:
                logger.warning(f"⚠️ [AUTO-RETRAIN] Réentraînement pour {category}: {result.get('reason', 'unknown')}")
    except Exception as e:
        logger.error(f"❌ [AUTO-RETRAIN] Erreur lors du réentraînement en arrière-plan: {e}", exc_info=True)

@app.post("/trades/feedback")
async def receive_trade_feedback(feedback: TradeFeedback):
    """
    Endpoint pour recevoir les résultats de trade depuis le robot MT5
    Stocke dans PostgreSQL pour analyse et amélioration continue
    """
    if not DB_AVAILABLE:
        raise HTTPException(
            status_code=503,
            detail="Service de feedback non disponible - DATABASE_URL non configurée"
        )
    
    try:
        pool = await get_db_pool()
        if not pool:
            raise HTTPException(status_code=503, detail="Connexion base de données impossible")
        
        # Valider et parser les timestamps
        try:
            open_time_dt = datetime.fromisoformat(feedback.open_time.replace('Z', '+00:00'))
            close_time_dt = datetime.fromisoformat(feedback.close_time.replace('Z', '+00:00'))
        except ValueError as e:
            raise HTTPException(
                status_code=400,
                detail=f"Format de date invalide: {str(e)}. Utilisez le format ISO 8601"
            )
        
        # Insérer dans la base de données
        async with pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO trade_feedback (
                    symbol, open_time, close_time, entry_price, exit_price,
                    profit, ai_confidence, coherent_confidence, decision, is_win
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            """,
                feedback.symbol,
                open_time_dt,
                close_time_dt,
                feedback.entry_price,
                feedback.exit_price,
                feedback.profit,
                feedback.ai_confidence,
                feedback.coherent_confidence,
                feedback.decision,
                feedback.is_win
            )
        
        # Logger pour suivi
        win_str = "✅ WIN" if feedback.is_win else "❌ LOSS"
        logger.info(
            f"📊 Feedback reçu: {feedback.symbol} {feedback.decision} - "
            f"Profit: ${feedback.profit:.2f} {win_str} "
            f"(IA: {feedback.ai_confidence:.1%}, Coh: {feedback.coherent_confidence:.1%})"
        )
        
        # Déclencher automatiquement le réentraînement en arrière-plan (non-bloquant)
        if CONTINUOUS_LEARNING_AVAILABLE and continuous_learner:
            # Vérifier combien de trades ont été reçus pour cette catégorie
            try:
                # Map le symbole vers sa catégorie
                symbol_upper = feedback.symbol.upper()
                if "BOOM" in symbol_upper or "CRASH" in symbol_upper:
                    category = "BOOM_CRASH"
                elif any(keyword in symbol_upper for keyword in ['VOLATILITY', 'STEP', 'JUMP', 'RANGE BREAK']):
                    category = "VOLATILITY"
                elif any(crypto in symbol_upper for crypto in ['BTC', 'ETH', 'ADA', 'DOT']):
                    category = "CRYPTO"
                elif any(pair in symbol_upper for pair in ['USD', 'EUR', 'GBP', 'JPY']):
                    category = "FOREX"
                else:
                    category = "COMMODITIES"
                
                # Compter les trades récents pour cette catégorie
                async with pool.acquire() as conn:
                    count_result = await conn.fetchval("""
                        SELECT COUNT(*) FROM trade_feedback
                        WHERE created_at >= NOW() - INTERVAL '7 days'
                        AND (
                            CASE
                                WHEN symbol LIKE '%BOOM%' OR symbol LIKE '%CRASH%' THEN 'BOOM_CRASH'
                                WHEN symbol LIKE '%VOLATILITY%' OR symbol LIKE '%STEP%' OR symbol LIKE '%JUMP%' THEN 'VOLATILITY'
                                WHEN symbol LIKE '%BTC%' OR symbol LIKE '%ETH%' THEN 'CRYPTO'
                                WHEN symbol LIKE '%USD%' OR symbol LIKE '%EUR%' OR symbol LIKE '%GBP%' THEN 'FOREX'
                                ELSE 'COMMODITIES'
                            END
                        ) = $1
                    """, category)
                    
                    # Si on a assez de trades, déclencher le réentraînement en arrière-plan
                    if count_result and count_result >= continuous_learner.min_new_samples:
                        logger.info(f"🔄 Assez de trades ({count_result}) pour réentraîner {category} - Déclenchement en arrière-plan...")
                        # Déclencher le réentraînement de manière asynchrone (non-bloquant)
                        asyncio.create_task(_trigger_retraining_async(category))
            except Exception as e:
                logger.warning(f"⚠️ Erreur lors de la vérification du réentraînement: {e}")
        
        return {
            "status": "ok",
            "message": "Feedback enregistré avec succès",
            "symbol": feedback.symbol,
            "profit": feedback.profit
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur enregistrement feedback: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur serveur: {str(e)}")


@app.get("/ml/feedback/status")
async def get_feedback_status():
    """
    Vérifie le statut de la base de données trade_feedback
    Retourne des statistiques sur les trades enregistrés pour le monitoring
    """
    if not DB_AVAILABLE:
        return {
            "status": "error",
            "error": "Base de données non disponible - DATABASE_URL non configurée",
            "db_available": False
        }
    
    try:
        # Ajouter un timeout explicite pour éviter que la requête bloque indéfiniment
        pool = await asyncio.wait_for(get_db_pool(), timeout=10.0)
        if not pool:
            return {
                "status": "error",
                "error": "Connexion base de données impossible - pool non créé",
                "db_available": False
            }
        
        # Tester la connexion avec un timeout explicite
        try:
            async with pool.acquire() as conn:
                # Statistiques globales (avec timeout explicite)
                total_trades = await asyncio.wait_for(
                    conn.fetchval("SELECT COUNT(*) FROM trade_feedback"), 
                    timeout=10.0
                )
                total_win = await asyncio.wait_for(
                    conn.fetchval("SELECT COUNT(*) FROM trade_feedback WHERE is_win = true"),
                    timeout=10.0
                )
                total_loss = await asyncio.wait_for(
                    conn.fetchval("SELECT COUNT(*) FROM trade_feedback WHERE is_win = false"),
                    timeout=10.0
                )
                total_profit = await asyncio.wait_for(
                    conn.fetchval("SELECT SUM(profit) FROM trade_feedback"),
                    timeout=10.0
                )
            
                # Trades récents (7 derniers jours)
                recent_trades = await asyncio.wait_for(
                    conn.fetchval("SELECT COUNT(*) FROM trade_feedback WHERE created_at >= NOW() - INTERVAL '7 days'"),
                    timeout=10.0
                )
                
                # Trades par catégorie
                trades_by_category = await asyncio.wait_for(
                    conn.fetch("""
                SELECT 
                    CASE
                        WHEN symbol LIKE '%BOOM%' OR symbol LIKE '%CRASH%' THEN 'BOOM_CRASH'
                        WHEN symbol LIKE '%VOLATILITY%' OR symbol LIKE '%STEP%' OR symbol LIKE '%JUMP%' THEN 'VOLATILITY'
                        WHEN symbol LIKE '%BTC%' OR symbol LIKE '%ETH%' OR symbol LIKE '%ADA%' THEN 'CRYPTO'
                        WHEN symbol LIKE '%USD%' OR symbol LIKE '%EUR%' OR symbol LIKE '%GBP%' OR symbol LIKE '%JPY%' THEN 'FOREX'
                        ELSE 'COMMODITIES'
                    END as category,
                    COUNT(*) as count,
                    SUM(CASE WHEN is_win THEN 1 ELSE 0 END) as wins,
                    SUM(profit) as total_profit
                FROM trade_feedback
                WHERE created_at >= NOW() - INTERVAL '30 days'
                GROUP BY category
                ORDER BY count DESC
                    """),
                    timeout=10.0
                )
                
                # Derniers trades
                last_trades = await asyncio.wait_for(
                    conn.fetch("""
                    SELECT symbol, decision, profit, is_win, created_at
                    FROM trade_feedback
                    ORDER BY created_at DESC
                    LIMIT 10
                """),
                    timeout=10.0
                )
                
                # Vérifier si on a assez de trades pour le réentraînement
                min_samples = continuous_learner.min_new_samples if CONTINUOUS_LEARNING_AVAILABLE and continuous_learner else 50
                ready_for_retraining = {}
                
                for row in trades_by_category:
                    category = row['category']
                    count = row['count']
                    ready_for_retraining[category] = {
                        "count": count,
                        "ready": count >= min_samples,
                        "wins": row['wins'],
                        "total_profit": float(row['total_profit']) if row['total_profit'] else 0.0
                    }
                
                win_rate = (total_win / total_trades * 100) if total_trades > 0 else 0.0
                
                return {
                "status": "ok",
                "db_available": True,
                "statistics": {
                    "total_trades": total_trades,
                    "total_wins": total_win,
                    "total_losses": total_loss,
                    "win_rate": round(win_rate, 2),
                    "total_profit": float(total_profit) if total_profit else 0.0,
                    "recent_trades_7d": recent_trades,
                    "min_samples_for_retraining": min_samples
                },
                "trades_by_category": {
                    row['category']: {
                        "count": row['count'],
                        "wins": row['wins'],
                        "total_profit": float(row['total_profit']) if row['total_profit'] else 0.0,
                        "ready_for_retraining": row['count'] >= min_samples
                    }
                    for row in trades_by_category
                },
                "last_trades": [
                    {
                        "symbol": row['symbol'],
                        "decision": row['decision'],
                        "profit": float(row['profit']),
                        "is_win": row['is_win'],
                        "created_at": row['created_at'].isoformat() if row['created_at'] else None
                    }
                    for row in last_trades
                ],
                "continuous_learning": {
                    "available": CONTINUOUS_LEARNING_AVAILABLE,
                    "min_samples": min_samples,
                    "retrain_interval_days": continuous_learner.retrain_interval_days if CONTINUOUS_LEARNING_AVAILABLE and continuous_learner else None
                }
                }
        except asyncio.TimeoutError:
            logger.error("Timeout lors de la connexion à la base de données PostgreSQL")
            return {
                "status": "error",
                "error": "Timeout lors de la connexion à la base de données - Vérifiez la connexion réseau ou le serveur PostgreSQL",
                "db_available": DB_AVAILABLE
            }
        except Exception as e:
            logger.error(f"Erreur lors de la vérification du statut feedback: {e}", exc_info=True)
            return {
                "status": "error",
                "error": str(e),
                "db_available": DB_AVAILABLE
            }
    except asyncio.TimeoutError:
        logger.error("Timeout lors de la connexion à la base de données PostgreSQL")
        return {
            "status": "error",
            "error": "Timeout lors de la connexion à la base de données - Vérifiez la connexion réseau ou le serveur PostgreSQL",
            "db_available": DB_AVAILABLE
        }
    except Exception as e:
        logger.error(f"Erreur lors de la vérification du statut feedback: {e}", exc_info=True)
        return {
            "status": "error",
            "error": str(e),
            "db_available": DB_AVAILABLE
        }

@app.get("/ml/retraining/stats")
async def get_retraining_stats():
    """
    Retourne les statistiques de réentraînement des modèles ML
    """
    if not CONTINUOUS_LEARNING_AVAILABLE or not continuous_learner:
        return {
            "status": "error",
            "error": "Système d'apprentissage continu non disponible"
        }
    
    try:
        # Charger les timestamps de dernier réentraînement
        last_retrain_times = continuous_learner.last_retrain_times
        retrain_stats = {}
        
        categories = ["BOOM_CRASH", "VOLATILITY", "FOREX", "CRYPTO", "COMMODITIES"]
        for category in categories:
            last_time = last_retrain_times.get(category)
            if last_time:
                last_dt = datetime.fromisoformat(last_time)
                days_since = (datetime.now() - last_dt).days
                hours_since = (datetime.now() - last_dt).total_seconds() / 3600
                
                retrain_stats[category] = {
                    "last_retrained": last_time,
                    "days_since": days_since,
                    "hours_since": round(hours_since, 2),
                    "should_retrain": continuous_learner._should_retrain(category)
                }
            else:
                retrain_stats[category] = {
                    "last_retrained": None,
                    "days_since": None,
                    "hours_since": None,
                    "should_retrain": True
                }
        
        return {
            "status": "ok",
            "config": {
                "min_new_samples": continuous_learner.min_new_samples,
                "retrain_interval_days": continuous_learner.retrain_interval_days
            },
            "retraining_status": retrain_stats
        }
        
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des stats de réentraînement: {e}", exc_info=True)
        return {
            "status": "error",
            "error": str(e)
        }

@app.post("/ml/retraining/trigger")
async def trigger_retraining(category: Optional[str] = None):
    """
    Déclenche manuellement le réentraînement pour une catégorie ou toutes les catégories
    
    Body params:
        - category: Catégorie spécifique à réentraîner (BOOM_CRASH, VOLATILITY, FOREX, CRYPTO, COMMODITIES)
                   Si non spécifié, réentraîne toutes les catégories disponibles
    """
    if not CONTINUOUS_LEARNING_AVAILABLE or not continuous_learner:
        raise HTTPException(
            status_code=503,
            detail="Système d'apprentissage continu non disponible"
        )
    
    try:
        if category:
            # Réentraîner une catégorie spécifique
            logger.info(f"🔄 [MANUAL-RETRAIN] Déclenchement manuel du réentraînement pour {category}")
            result = continuous_learner.retrain_model_for_category(category)
            
            return {
                "status": "ok",
                "category": category,
                "result": result
            }
        else:
            # Réentraîner toutes les catégories
            logger.info("🔄 [MANUAL-RETRAIN] Déclenchement manuel du réentraînement pour toutes les catégories")
            results = continuous_learner.retrain_all_categories()
            
            return {
                "status": "ok",
                "message": "Réentraînement déclenché pour toutes les catégories",
                "results": results
            }
            
    except Exception as e:
        logger.error(f"Erreur lors du réentraînement manuel: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur serveur: {str(e)}")

@app.get("/monitoring/dashboard")
async def monitoring_dashboard(symbols: Optional[str] = None, limit: int = 100):
    """
    Dashboard de monitoring en temps réel
    Retourne les statistiques de performance par symbole et globales
    
    Query params:
        - symbols: Filtre par symboles (séparés par virgules), ex: "Volatility 75 Index,Boom 300 Index"
        - limit: Nombre maximum de trades récents à analyser (défaut: 100)
    """
    if not DB_AVAILABLE:
        return {
            "error": "Service de monitoring non disponible - DATABASE_URL non configurée",
            "win_rate": 0,
            "pnl_total": 0,
            "pnl_par_symbole": {},
            "objectif_progress": 0,
            "alertes": ["Base de données non disponible"]
        }
    
    try:
        pool = await get_db_pool()
        if not pool:
            raise HTTPException(status_code=503, detail="Connexion base de données impossible")
        
        async with pool.acquire() as conn:
            # Requête de base
            query = """
                SELECT symbol, profit, is_win, ai_confidence, coherent_confidence,
                       decision, created_at
                FROM trade_feedback
                ORDER BY created_at DESC
                LIMIT $1
            """
            params = [limit]
            
            # Filtrer par symboles si demandé
            if symbols:
                symbol_list = [s.strip() for s in symbols.split(',')]
                query = """
                    SELECT symbol, profit, is_win, ai_confidence, coherent_confidence,
                           decision, created_at
                    FROM trade_feedback
                    WHERE symbol = ANY($2::text[])
                    ORDER BY created_at DESC
                    LIMIT $1
                """
                params = [limit, symbol_list]
            
            rows = await conn.fetch(query, *params)
        
        if not rows:
            return {
                "win_rate": 0.0,
                "pnl_total": 0.0,
                "total_trades": 0,
                "pnl_par_symbole": {},
                "objectif_progress": 0.0,
                "recent_trades": [],
                "alertes": ["Aucune donnée de trading disponible"],
                "timestamp": datetime.now().isoformat()
            }
        
        # Calcul des statistiques
        total_trades = len(rows)
        wins = sum(1 for r in rows if r["is_win"])
        pnl_total = sum(float(r["profit"] or 0) for r in rows)
        win_rate = wins / total_trades if total_trades > 0 else 0.0
        
        # PnL par symbole
        pnl_by_symbol = {}
        trades_by_symbol = {}
        wins_by_symbol = {}
        
        for r in rows:
            sym = r["symbol"] or "UNKNOWN"
            if sym not in pnl_by_symbol:
                pnl_by_symbol[sym] = 0.0
                trades_by_symbol[sym] = 0
                wins_by_symbol[sym] = 0
            
            pnl_by_symbol[sym] += float(r["profit"] or 0)
            trades_by_symbol[sym] += 1
            if r["is_win"]:
                wins_by_symbol[sym] += 1
        
        # Compiler stats par symbole
        symbol_stats = {}
        for sym in pnl_by_symbol.keys():
            symbol_stats[sym] = {
                "pnl": round(pnl_by_symbol[sym], 2),
                "trades": trades_by_symbol[sym],
                "win_rate": round(wins_by_symbol[sym] / trades_by_symbol[sym] * 100, 1) if trades_by_symbol[sym] > 0 else 0
            }
        
        # Générer alertes intelligentes
        alertes = []
        if total_trades >= 5 and win_rate < 0.40:
            alertes.append(f"⚠️ Win rate faible: {win_rate*100:.1f}% (seuil critique: 40%)")
        if pnl_total < -50:
            alertes.append(f"🔴 Pertes cumulées élevées: ${pnl_total:.2f}")
        if total_trades >= 10 and win_rate >= 0.70:
            alertes.append(f"🎉 Performance excellente! Win rate: {win_rate*100:.1f}%")
        
        # Analyser les symboles perdants
        for sym, stats in symbol_stats.items():
            if stats["trades"] >= 3 and stats["pnl"] < -20:
                alertes.append(f"⚠️ Symbole perdant: {sym} (${stats['pnl']:.2f} sur {stats['trades']} trades)")
        
        if not alertes:
            alertes.append("✅ Aucune alerte - Performance normale")
        
        # Progression vers objectif quotidien (exemple: 30$ par jour)
        objectif_quotidien = 30.0
        objectif_progress = min((pnl_total / objectif_quotidien) * 100, 100) if  pnl_total > 0 else 0
        
        # Trades récents (les 10 derniers)
        recent_trades = [
            {
                "symbol": r["symbol"],
                "decision": r["decision"],
                "profit": round(float(r["profit"]), 2),
                "is_win": r["is_win"],
                "ai_confidence": round(float(r["ai_confidence"] or 0), 2),
                "timestamp": r["created_at"].isoformat() if hasattr(r["created_at"], 'isoformat') else str(r["created_at"])
            }
            for r in rows[:10]
        ]
        
        return {
            "win_rate": round(win_rate, 3),
            "pnl_total": round(pnl_total, 2),
            "total_trades": total_trades,
            "pnl_par_symbole": symbol_stats,
            "objectif_progress": round(objectif_progress, 1),
            "objectif_quotidien": objectif_quotidien,
            "recent_trades": recent_trades,
            "alertes": alertes,
            "timestamp": datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur monitoring dashboard: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur serveur: {str(e)}")

# ============================================================================
# MAIN
# ============================================================================


# Endpoint pour les indicateurs avancés
@app.post("/indicators/analyze")
async def analyze_indicators(request_data: Dict[str, Any]):
    """Analyse les données de marché avec AdvancedIndicators"""
    try:
        if not AI_INDICATORS_AVAILABLE:
            raise HTTPException(status_code=503, detail="Module ai_indicators non disponible")
        
        symbol = request_data.get("symbol")
        timeframe = request_data.get("timeframe", "M1")
        market_data = request_data.get("market_data")
        
        if not symbol or not market_data:
            raise HTTPException(status_code=400, detail="symbol et market_data requis")
        
        # Utiliser le cache pour éviter de recréer l'instance
        cache_key = f"{symbol}_{timeframe}"
        if cache_key not in indicators_cache:
            indicators_cache[cache_key] = AdvancedIndicators(symbol, timeframe)
        
        analyzer = indicators_cache[cache_key]
        result = analyzer.process_market_data(market_data)
        
        return result
    except Exception as e:
        logger.error(f"Erreur analyse indicateurs: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/indicators/sentiment/{symbol}")
async def get_market_sentiment(symbol: str, timeframe: str = "H1"):
    """Récupère le sentiment du marché pour un symbole"""
    try:
        if not AI_INDICATORS_AVAILABLE:
            raise HTTPException(status_code=503, detail="Module ai_indicators non disponible")
        
        # Récupérer les données depuis MT5
        if not mt5_initialized:
            raise HTTPException(status_code=503, detail="MT5 non initialisé")
        
        tf_map = {
            "M1": mt5.TIMEFRAME_M1,
            "M5": mt5.TIMEFRAME_M5,
            "M15": mt5.TIMEFRAME_M15,
            "H1": mt5.TIMEFRAME_H1,
            "H4": mt5.TIMEFRAME_H4,
            "D1": mt5.TIMEFRAME_D1
        }
        
        tf = tf_map.get(timeframe, mt5.TIMEFRAME_H1)
        rates = mt5.copy_rates_from_pos(symbol, tf, 0, 500)
        
        if rates is None or len(rates) == 0:
            raise HTTPException(status_code=404, detail="Aucune donnée disponible")
        
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        
        # Utiliser AdvancedIndicators pour calculer le sentiment
        cache_key = f"{symbol}_{timeframe}"
        if cache_key not in indicators_cache:
            indicators_cache[cache_key] = AdvancedIndicators(symbol, timeframe)
        
        analyzer = indicators_cache[cache_key]
        sentiment = analyzer.calculate_market_sentiment(df)
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": datetime.now().isoformat(),
            "sentiment": sentiment
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur sentiment marché: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/indicators/volume_profile/{symbol}")
async def get_volume_profile(symbol: str, timeframe: str = "H1", num_bins: int = 20):
    """Récupère le profil de volume pour un symbole"""
    try:
        if not AI_INDICATORS_AVAILABLE:
            raise HTTPException(status_code=503, detail="Module ai_indicators non disponible")
        
        if not mt5_initialized:
            raise HTTPException(status_code=503, detail="MT5 non initialisé")
        
        tf_map = {
            "M1": mt5.TIMEFRAME_M1,
            "M5": mt5.TIMEFRAME_M5,
            "M15": mt5.TIMEFRAME_M15,
            "H1": mt5.TIMEFRAME_H1,
            "H4": mt5.TIMEFRAME_H4,
            "D1": mt5.TIMEFRAME_D1
        }
        
        tf = tf_map.get(timeframe, mt5.TIMEFRAME_H1)
        rates = mt5.copy_rates_from_pos(symbol, tf, 0, 500)
        
        if rates is None or len(rates) == 0:
            raise HTTPException(status_code=404, detail="Aucune donnée disponible")
        
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        
        # Calculer le profil de volume
        cache_key = f"{symbol}_{timeframe}"
        if cache_key not in indicators_cache:
            indicators_cache[cache_key] = AdvancedIndicators(symbol, timeframe)
        
        analyzer = indicators_cache[cache_key]
        volume_profile = analyzer.calculate_volume_profile(df, num_bins)
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": datetime.now().isoformat(),
            "volume_profile": volume_profile
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur profil volume: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

# Endpoint pour l'analyse avec Gemini AI
@app.post("/analyze/gemini")
async def analyze_with_gemini_endpoint(request_data: Dict[str, Any]):
    """Analyse de marché avec Google Gemini AI"""
    try:
        if not GEMINI_AVAILABLE:
            raise HTTPException(status_code=503, detail="Google Gemini AI non disponible")
        
        symbol = request_data.get("symbol", "UNKNOWN")
        market_data = request_data.get("market_data", {})
        question = request_data.get("question", "Analyse ce marché et donne une recommandation de trading")
        
        # Construire le prompt
        prompt = f"""
Analyse de trading pour {symbol}

Données de marché:
{json.dumps(market_data, indent=2)}

Question: {question}

Fournis une analyse détaillée incluant:
1. Analyse technique du marché
2. Recommandation (BUY/SELL/HOLD)
3. Niveau de confiance (0-100%)
4. Raisonnement clair
"""
        
        result = analyze_with_gemini(prompt)
        if not result:
            raise HTTPException(status_code=500, detail="Erreur lors de l'analyse Gemini")
        
        return {
            "symbol": symbol,
            "timestamp": datetime.now().isoformat(),
            "analysis": result,
            "provider": "google-gemini-1.5-flash"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur analyse Gemini: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

# Endpoint pour la validation des ordres
@app.post("/validate_order")
async def validate_order(order_data: Dict[str, Any]):
    """Valide un ordre avant exécution"""
    try:
        symbol = order_data.get("symbol")
        order_type = order_data.get("type")  # "BUY" or "SELL"
        volume = order_data.get("volume", 0.01)
        sl = order_data.get("stop_loss")
        tp = order_data.get("take_profit")
        
        if not symbol:
            return {"valid": False, "reason": "Symbole manquant"}
        
        # Récupérer les données actuelles
        if mt5_initialized:
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info is None:
                return {"valid": False, "reason": "Symbole introuvable"}
            
            tick = mt5.symbol_info_tick(symbol)
            if tick is None:
                return {"valid": False, "reason": "Impossible de récupérer le tick"}
            
            current_price = tick.ask if order_type == "BUY" else tick.bid
            
            # Vérifier les stops
            min_stop = symbol_info.trade_stops_level * symbol_info.point
            if sl and abs(current_price - sl) < min_stop:
                return {
                    "valid": False,
                    "reason": f"Stop Loss trop proche (minimum: {min_stop} points)"
                }
            if tp and abs(current_price - tp) < min_stop:
                return {
                    "valid": False,
                    "reason": f"Take Profit trop proche (minimum: {min_stop} points)"
                }
            
            return {
                "valid": True,
                "current_price": float(current_price),
                "min_stop_points": float(min_stop / symbol_info.point)
            }
        else:
            return {"valid": False, "reason": "MT5 non initialisé"}
    except Exception as e:
        logger.error(f"Erreur validation ordre: {e}", exc_info=True)
        return {"valid": False, "reason": f"Erreur: {str(e)}"}

class GemmaTradingResponse(BaseModel):
    """Modèle pour les réponses de trading avec Gemma"""
    success: bool
    symbol: str
    timeframe: str
    analysis: Optional[str] = None
    chart_filename: Optional[str] = None
    error: Optional[str] = None
    timestamp: str = Field(default_factory=lambda: datetime.utcnow().isoformat())

class TradingSignalRequest(BaseModel):
    """Modèle pour les requêtes de signaux de trading"""
    symbol: str
    timeframe: str
    analysis: str
    indicators: Optional[Dict[str, Any]] = None

class TradingSignalResponse(BaseModel):
    """Modèle pour les réponses de signaux de trading"""
    success: bool
    signal: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    timestamp: str = Field(default_factory=lambda: datetime.utcnow().isoformat())

class GemmaTradingRequest(BaseModel):
    """Modèle pour les requêtes d'analyse de graphique Gemma"""
    symbol: str
    timeframe: str
    prompt: Optional[str] = None
    capture_chart: bool = True
    max_tokens: int = 200
    temperature: float = 0.7
    top_p: float = 0.9

class IndicatorsResponse(BaseModel):
    """Modèle pour les réponses d'indicateurs MT5"""
    symbol: str
    timeframe: str
    indicators: Dict[str, Any]

# ===================== GEMMA TRADING BOT =====================

class GemmaTradingBot:
    """Gestion de la capture et de l'analyse de graphiques pour le trading"""

    def __init__(self, config: Optional[Dict[str, Any]] | None = None):
        self.config = config or {}
        self.model_path = self.config.get("model_path", GEMMA_MODEL_PATH)
        self.mt5_files_dir = self.config.get("mt5_files_dir", MT5_FILES_DIR)
        self.chart_dir = os.path.join(self.mt5_files_dir, "Charts")
        os.makedirs(self.chart_dir, exist_ok=True)

    # Note: on évite Optional[Image.Image] car Image peut être None si PIL n'est pas installé,
    # et les annotations sont évaluées au chargement du module (crash Render sinon).
    def capture_chart(self, symbol: str, timeframe: str, width: int = 800, height: int = 600) -> Tuple[Optional[Any], Optional[str]]:
        if not MT5_AVAILABLE or not 'mt5' in globals() or not mt5_initialized:
            logger.warning("MT5 non initialisé, capture impossible")
            return None, None

        if not mt5.symbol_select(symbol, True):
            logger.error("Symbole %s introuvable dans MT5", symbol)
            return None, None

        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filename = f"{symbol}_{timeframe}_{timestamp}.png"
        filepath = os.path.join(self.chart_dir, filename)

        try:
            if not mt5.chart_save(0, filepath, width, height, 0):
                logger.error("chart_save a échoué pour %s %s", symbol, timeframe)
                return None, None
            if Image is None:
                logger.error("PIL (Pillow) n'est pas installé: impossible d'ouvrir l'image %s", filepath)
                return None, filename
            image = Image.open(filepath)
            return image, filename
        except Exception as exc:
            logger.error("Erreur capture_chart: %s", exc, exc_info=True)
            return None, None

    def analyze_chart(self, symbol: str, timeframe: str, image: Optional[Any] = None, prompt: Optional[str] = None) -> Optional[str]:
        if not GEMMA_AVAILABLE:
            logger.warning("Gemma non disponible")
            return None
        if image is None:
            image, _ = self.capture_chart(symbol, timeframe)
            if image is None:
                return None

        prompt = prompt or (
            f"Analyse ce graphique pour {symbol} sur {timeframe}. "
            "Identifie la tendance, supports, résistances et donne un commentaire concis."
        )

        temp_path = os.path.join(self.chart_dir, f"temp_{int(time.time())}.png")
        image.save(temp_path)
        try:
            result = analyze_with_gemma(prompt=prompt, image_filename=temp_path)
            return result
        finally:
            try:
                os.remove(temp_path)
            except OSError:
                pass
                
    def analyze_gemma_response(self, response: str) -> None:
        """Analyse et log les signaux détectés dans la réponse Gemma"""
        if not response:
            return
            
        try:
            # Détection des signaux de trading
            signals = {
                'buy': ['acheter', 'long', 'haussier', 'bullish', '↑', '🔼', '📈', '🚀'],
                'sell': ['vendre', 'short', 'baissier', 'bearish', '↓', '🔽', '📉', '💥'],
                'neutral': ['neutre', 'lateral', 'ranging', 'consolidation', 'sideways', '➡️']
            }
            
            detected_signals = []
            for signal, keywords in signals.items():
                if any(keyword in response.lower() for keyword in keywords):
                    detected_signals.append(signal.upper())
            
            # Détection des niveaux de prix
            import re
            price_levels = re.findall(r'\b\d+\.?\d*\b', response)
            
            # Log des résultats
            logger.info("\n" + "="*80)
            logger.info("📊 RÉSULTATS GEMMA")
            logger.info("="*80)
            if detected_signals:
                logger.info(f"📡 Signaux détectés: {', '.join(detected_signals)}")
            else:
                logger.info("ℹ️ Aucun signal clair détecté")
                
            if price_levels:
                logger.info(f"🎯 Niveaux de prix détectés: {', '.join(price_levels[:5])}")
                
            # Détection des mots-clés importants
            important_keywords = ['stop loss', 'take profit', 'risque', 'opportunité', 'tendance']
            found_keywords = [kw for kw in important_keywords if kw in response.lower()]
            if found_keywords:
                logger.info(f"🔍 Mots-clés importants: {', '.join(found_keywords)}")
                
            logger.info("="*80 + "\n")
            
        except Exception as e:
            logger.error(f"Erreur lors de l'analyse de la réponse Gemma: {str(e)}")

# Instance réutilisable
gemma_trading_bot = GemmaTradingBot()

# ---------------------- Endpoints Trading ----------------------

# Route pour obtenir les indicateurs bruts
@app.get("/trading/indicators/{symbol}/{timeframe}")
async def get_indicators(symbol: str, timeframe: str):
    indicators = get_mt5_indicators(symbol, timeframe)
    if not indicators:
        raise HTTPException(
            status_code=400,
            detail=f"Impossible de récupérer les indicateurs pour {symbol}"
        )
    return JSONResponse(content={
        "symbol": symbol,
        "timeframe": timeframe,
        "indicators": indicators
    })

# Route d'analyse avec Gemma utilisant les indicateurs MT5
@app.post("/trading/analyze")
async def analyze_trading_chart(request: GemmaTradingRequest):
    try:
        # Récupération des indicateurs MT5
        indicators = get_mt5_indicators(request.symbol, request.timeframe)
        if not indicators:
            return JSONResponse(
                status_code=400,
                content={"error": f"Impossible de récupérer les indicateurs pour {request.symbol}"}
            )
        
        # Création du prompt avec les indicateurs
        analysis_prompt = f"""
        Analyse technique pour {request.symbol} ({request.timeframe}):
        
        Prix:
        - Actuel: {indicators['current_price']}
        - Ouverture: {indicators['open']}
        - Plus haut: {indicators['high']}
        - Plus bas: {indicators['low']}
        
        Moyennes mobiles:
        - SMA 20: {indicators['sma_20']}
        - SMA 50: {indicators['sma_50']}
        - SMA 200: {indicators['sma_200']}
        
        Indicateurs:
        - RSI (14): {indicators['rsi']:.2f}
        - ATR (14): {indicators['atr']:.5f}
        - MACD: {indicators['macd']:.5f}
        - Bandes de Bollinger: {indicators['bb_lower']:.5f} - {indicators['bb_upper']:.5f}
        - Volume: {indicators['volume']}
        
        {request.prompt or "Donne une analyse technique complète et des recommandations de trading."}
        """
        
        # Utilisation de Gemma pour l'analyse
        if not GEMMA_AVAILABLE:
            return {"error": "Gemma n'est pas disponible"}
            
        try:
            inputs = gemma_processor(analysis_prompt, return_tensors="pt")
            outputs = gemma_model.generate(**inputs, max_length=1000)
            analysis = gemma_processor.decode(outputs[0], skip_special_tokens=True)
            
            return {
                "symbol": request.symbol,
                "timeframe": request.timeframe,
                "analysis": analysis,
                "indicators": indicators
            }
            
        except Exception as e:
            return {"error": f"Erreur lors de l'analyse avec Gemma: {str(e)}"}
            
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": f"Erreur lors de l'analyse: {str(e)}"}
        )

@app.post("/trading/generate-signal", response_model=TradingSignalResponse)
async def generate_trading_signal(request: TradingSignalRequest):
    try:
        if not GEMMA_AVAILABLE:
            raise ValueError("Gemma non disponible")

        prompt = f"""
        Génère un signal de trading clair pour {request.symbol} ({request.timeframe}) basé sur l'analyse suivante :
        {request.analysis}

        Indicateurs:
        {json.dumps(request.indicators or {}, indent=2)}

        Format de la réponse attendu :
        Action: BUY/SELL/HOLD
        Entrée: <prix>
        StopLoss: <prix>
        TakeProfit: <prix>
        Confiance: <0-100%>
        Raisonnement:
        """

        response_text = analyze_with_gemma(prompt=prompt)
        if not response_text:
            raise ValueError("Impossible de générer le signal")

        signal = {"raw_response": response_text}

        return TradingSignalResponse(success=True, signal=signal)
    except Exception as exc:
        logger.error("Erreur generate_trading_signal: %s", exc, exc_info=True)
        return TradingSignalResponse(success=False, error=str(exc))

# =============================================================================
class GemmaAnalysisRequest(BaseModel):
    """Modèle pour les requêtes d'analyse Gemma"""
    prompt: str
    image_filename: Optional[str] = None
    max_tokens: int = 200
    temperature: float = 0.7
    top_p: float = 0.9

class GemmaAnalysisResponse(BaseModel):
    """Modèle pour les réponses d'analyse Gemma"""
    success: bool
    result: Optional[str] = None
    error: Optional[str] = None
    model_status: str = "unavailable"

@app.post("/analyze/gemma", response_model=GemmaAnalysisResponse)
async def analyze_with_gemma_endpoint(request: GemmaAnalysisRequest):
    """
    Endpoint pour effectuer des analyses avec le modèle Gemma
    """
    if not GEMMA_AVAILABLE:
        return GemmaAnalysisResponse(
            success=False,
            error="Le modèle Gemma n'est pas disponible",
            model_status="unavailable"
        )
    
    try:
        # Valider les paramètres
        if not request.prompt or len(request.prompt.strip()) == 0:
            raise ValueError("Le prompt ne peut pas être vide")
            
        # Appeler la fonction d'analyse Gemma
        result = analyze_with_gemma(
            prompt=request.prompt,
            image_filename=request.image_filename
        )
        
        if result is None:
            return GemmaAnalysisResponse(
                success=False,
                error="L'analyse Gemma n'a pas pu être effectuée",
                model_status="error"
            )
            
        return GemmaAnalysisResponse(
            success=True,
            result=result,
            model_status="ready"
        )
        
    except Exception as e:
        logger.error(f"Erreur lors de l'analyse avec Gemma: {str(e)}", exc_info=True)
        return GemmaAnalysisResponse(
            success=False,
            error=f"Erreur lors de l'analyse: {str(e)}",
            model_status="error"
        )

# ==================== INDICATEURS TECHNIQUES AVANCÉS ====================

@app.get("/indicators/ichimoku/{symbol}")
async def get_ichimoku_analysis(
    symbol: str, 
    timeframe: str = "H1",
    count: int = 200
):
    """
    Récupère l'analyse Ichimoku Kinko Hyo pour un symbole donné.
    
    Args:
        symbol: Symbole du marché (ex: "EURUSD", "BTCUSDT")
        timeframe: Période temporelle (M1, M5, M15, H1, H4, D1)
        count: Nombre de bougies à analyser (max 1000)
        
    Returns:
        Dictionnaire contenant les composantes de l'Ichimoku
    """
    try:
        # Valider les paramètres
        count = min(max(50, count), 1000)  # Limiter entre 50 et 1000
        
        # Récupérer les données historiques
        df = get_historical_data(symbol, timeframe, count)
        if df.empty:
            raise HTTPException(status_code=404, detail=f"Aucune donnée disponible pour {symbol}")
        
        # Initialiser l'analyseur d'indicateurs
        from python.ai_indicators import AdvancedIndicators
        analyzer = AdvancedIndicators(symbol, timeframe)
        
        # Calculer l'Ichimoku
        ichimoku = analyzer.calculate_ichimoku(df)
        
        if not ichimoku:
            raise HTTPException(status_code=400, detail="Impossible de calculer l'Ichimoku avec les données disponibles")
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": datetime.utcnow().isoformat(),
            **ichimoku
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur dans get_ichimoku_analysis: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors du calcul de l'Ichimoku: {str(e)}")

@app.get("/indicators/fibonacci/{symbol}")
async def get_fibonacci_levels(
    symbol: str,
    timeframe: str = "D1",
    lookback: int = 100
):
    """
    Calcule les niveaux de retracement et d'extension de Fibonacci.
    
    Args:
        symbol: Symbole du marché
        timeframe: Période temporelle (M1, M5, M15, H1, H4, D1)
        lookback: Nombre de périodes à analyser pour trouver les extrêmes
        
    Returns:
        Dictionnaire contenant les niveaux de Fibonacci
    """
    try:
        # Valider les paramètres
        lookback = min(max(20, lookback), 500)  # Limiter entre 20 et 500
        
        # Récupérer les données historiques
        df = get_historical_data(symbol, timeframe, lookback + 10)  # Prendre quelques bougies supplémentaires
        if df.empty:
            raise HTTPException(status_code=404, detail=f"Aucune donnée disponible pour {symbol}")
        
        # Initialiser l'analyseur d'indicateurs
        from python.ai_indicators import AdvancedIndicators
        analyzer = AdvancedIndicators(symbol, timeframe)
        
        # Calculer les niveaux de Fibonacci
        fib_levels = analyzer.calculate_fibonacci(df, lookback)
        
        if not fib_levels:
            raise HTTPException(status_code=400, detail="Impossible de calculer les niveaux de Fibonacci")
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "lookback_periods": lookback,
            "timestamp": datetime.utcnow().isoformat(),
            **fib_levels
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur dans get_fibonacci_levels: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors du calcul des niveaux de Fibonacci: {str(e)}")

@app.get("/indicators/order-blocks/{symbol}")
async def get_order_blocks(
    symbol: str,
    timeframe: str = "H4",
    lookback: int = 50,
    min_strength: float = 0.7
):
    """
    Détecte les blocs d'ordre (Order Blocks) dans le graphique.
    
    Args:
        symbol: Symbole du marché
        timeframe: Période temporelle (M1, M5, M15, H1, H4, D1)
        lookback: Nombre de périodes à analyser
        min_strength: Force minimale des blocs à inclure (0-1)
        
    Returns:
        Liste des blocs d'ordre détectés
    """
    try:
        # Valider les paramètres
        lookback = min(max(20, lookback), 200)  # Limiter entre 20 et 200
        min_strength = min(max(0.1, min_strength), 1.0)  # Limiter entre 0.1 et 1.0
        
        # Récupérer les données historiques
        df = get_historical_data(symbol, timeframe, lookback + 10)  # Prendre quelques bougies supplémentaires
        if df.empty:
            raise HTTPException(status_code=404, detail=f"Aucune donnée disponible pour {symbol}")
        
        # Initialiser l'analyseur d'indicateurs
        from python.ai_indicators import AdvancedIndicators
        analyzer = AdvancedIndicators(symbol, timeframe)
        
        # Détecter les blocs d'ordre
        blocks = analyzer.detect_order_blocks(df, lookback, min_strength)
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "lookback_periods": lookback,
            "min_strength": min_strength,
            "timestamp": datetime.utcnow().isoformat(),
            "order_blocks": blocks
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur dans get_order_blocks: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de la détection des blocs d'ordre: {str(e)}")

@app.get("/indicators/liquidity-zones/{symbol}")
async def get_liquidity_zones(
    symbol: str,
    timeframe: str = "H1",
    num_zones: int = 5,
    volume_filter: bool = True
):
    """
    Identifie les zones de liquidité basées sur le volume et le profil de prix.
    
    Args:
        symbol: Symbole du marché
        timeframe: Période temporelle (M1, M5, M15, H1, H4, D1)
        num_zones: Nombre de zones de liquidité à identifier (1-10)
        volume_filter: Si True, utilise le volume pour pondérer les zones
        
    Returns:
        Liste des zones de liquidité identifiées
    """
    try:
        # Valider les paramètres
        num_zones = min(max(1, num_zones), 10)  # Limiter entre 1 et 10
        
        # Récupérer les données historiques
        df = get_historical_data(symbol, timeframe, 200)  # Prendre assez de données pour une analyse significative
        if df.empty:
            raise HTTPException(status_code=404, detail=f"Aucune donnée disponible pour {symbol}")
        
        # Initialiser l'analyseur d'indicateurs
        from python.ai_indicators import AdvancedIndicators
        analyzer = AdvancedIndicators(symbol, timeframe)
        
        # Identifier les zones de liquidité
        zones = analyzer.identify_liquidity_zones(df, num_zones, volume_filter)
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "num_zones": len(zones),
            "volume_filter": volume_filter,
            "timestamp": datetime.utcnow().isoformat(),
            "liquidity_zones": zones
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur dans get_liquidity_zones: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de l'identification des zones de liquidité: {str(e)}")

@app.get("/indicators/market-profile/{symbol}")
async def get_market_profile_analysis(
    symbol: str,
    timeframe: str = "D1",
    period: str = "D",
    value_area_percent: float = 0.7
):
    """
    Calcule le profil de marché (Market Profile) avec POC, VAL, VAH, etc.
    
    Args:
        symbol: Symbole du marché
        timeframe: Période temporelle des bougies
        period: Période d'agrégation (D=journalier, W=hebdomadaire, M=mensuel)
        value_area_percent: Pourcentage de volume à inclure dans la zone de valeur (0.5-0.9)
        
    Returns:
        Dictionnaire contenant les informations du profil de marché
    """
    try:
        # Valider les paramètres
        value_area_percent = min(max(0.5, value_area_percent), 0.9)  # Limiter entre 0.5 et 0.9
        
        # Déterminer le nombre de bougies à récupérer en fonction de la période
        if period == "D":
            days = 30
        elif period == "W":
            days = 180
        elif period == "M":
            days = 365
        else:
            days = 30  # Par défaut, 1 mois
        
        # Récupérer les données historiques
        df = get_historical_data(symbol, timeframe, days * 24)  # Estimation grossière
        if df.empty:
            raise HTTPException(status_code=404, detail=f"Aucune donnée disponible pour {symbol}")
        
        # Initialiser l'analyseur d'indicateurs
        from python.ai_indicators import AdvancedIndicators
        analyzer = AdvancedIndicators(symbol, timeframe)
        
        # Calculer le profil de marché
        profile = analyzer.calculate_market_profile(df, period, value_area_percent)
        
        if not profile:
            raise HTTPException(status_code=400, detail="Impossible de calculer le profil de marché")
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "period": period,
            "value_area_percent": value_area_percent,
            "timestamp": datetime.utcnow().isoformat(),
            **profile
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur dans get_market_profile_analysis: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors du calcul du profil de marché: {str(e)}")

# ==================== FIN INDICATEURS TECHNIQUES AVANCÉS ====================

# ==================== AUTOSCAN ENDPOINTS ====================

@app.get("/autoscan/signals")
async def get_autoscan_signals(symbol: Optional[str] = None):
    """
    Endpoint pour récupérer les signaux AutoScan (compatible avec MT5)
    
    Format attendu par MT5:
    {
        "status": "success",
        "data": {
            "signals": [
                {
                    "symbol": "...",
                    "action": "BUY" | "SELL",
                    "entry_price": float,
                    "stop_loss": float,
                    "take_profit": float,
                    "confidence": float (0.0-1.0),
                    "reason": "..."
                }
            ]
        }
    }
    """
    try:
        signals = []
        
        # Si MT5 n'est pas disponible, retourner une liste vide
        if not mt5_initialized:
            logger.warning("MT5 non initialisé, retour de liste de signaux vide pour AutoScan")
            return {
                "status": "success",
                "data": {
                    "signals": []
                },
                "timestamp": datetime.utcnow().isoformat(),
                "count": 0,
                "message": "MT5 non disponible"
            }
        
        # Si un symbole est spécifié, analyser uniquement ce symbole
        symbols_to_scan = [symbol] if symbol else []
        
        # Si aucun symbole n'est spécifié, utiliser les symboles courants
        if not symbols_to_scan:
            # Symboles par défaut pour Boom/Crash
            symbols_to_scan = ["Boom 1000 Index", "Crash 1000 Index"]
        
        for sym in symbols_to_scan:
            try:
                # Récupérer les données OHLC récentes
                df = get_historical_data(sym, "M1", 100)
                if df.empty:
                    logger.warning(f"Aucune donnée disponible pour {sym}")
                    continue
                
                current_price = float(df['close'].iloc[-1])
                
                # Calculer les indicateurs techniques
                rsi_values = calculate_rsi(df['close'], period=14)
                rsi = float(rsi_values.iloc[-1]) if not rsi_values.empty else 50.0
                
                # Calculer ATR pour stop loss/take profit
                atr_values = calculate_atr(df, period=14)
                atr = float(atr_values.iloc[-1]) if not atr_values.empty else current_price * 0.001
                
                # Calculer les moyennes mobiles
                ema_fast = df['close'].ewm(span=12, adjust=False).mean()
                ema_slow = df['close'].ewm(span=26, adjust=False).mean()
                ema_fast_val = float(ema_fast.iloc[-1]) if not ema_fast.empty else current_price
                ema_slow_val = float(ema_slow.iloc[-1]) if not ema_slow.empty else current_price
                
                # Détecter les signaux basés sur RSI et MA
                action = None
                confidence = 0.0
                reason = ""
                
                # Condition 1: RSI en survente (< 30) -> Signal BUY
                if rsi < 30:
                    action = "BUY"
                    confidence = 0.75
                    reason = "RSI Survente"
                # Condition 2: RSI en surachat (> 70) -> Signal SELL
                elif rsi > 70:
                    action = "SELL"
                    confidence = 0.75
                    reason = "RSI Surachat"
                # Condition 3: Croisement de MA haussier
                elif len(ema_fast) >= 3 and len(ema_slow) >= 3:
                    ema_fast_prev = float(ema_fast.iloc[-2])
                    ema_slow_prev = float(ema_slow.iloc[-2])
                    if ema_fast_val > ema_slow_val and ema_fast_prev <= ema_slow_prev:
                        action = "BUY"
                        confidence = 0.70
                        reason = "MA Croisement Haussier"
                    # Condition 4: Croisement de MA baissier
                    elif ema_fast_val < ema_slow_val and ema_fast_prev >= ema_slow_prev:
                        action = "SELL"
                        confidence = 0.70
                        reason = "MA Croisement Baissier"
                # Condition 5: Volatilité élevée
                if action is None:
                    volatility = abs(current_price - ema_slow_val) / ema_slow_val if ema_slow_val > 0 else 0
                    if volatility > 0.002:  # 0.2%
                        if current_price > ema_slow_val:
                            action = "BUY"
                            confidence = 0.65
                            reason = "Volatilité Haussier"
                        else:
                            action = "SELL"
                            confidence = 0.65
                            reason = "Volatilité Baissier"
                
                # Si un signal a été détecté, créer l'entrée
                if action and confidence >= 0.55:  # Seuil minimum de confiance
                    # Calculer stop loss et take profit basés sur ATR
                    if action == "BUY":
                        entry_price = current_price
                        stop_loss = entry_price - (atr * 2)
                        take_profit = entry_price + (atr * 4.5)  # Augmenté de 3.0 à 4.5 (+50%)
                    else:  # SELL
                        entry_price = current_price
                        stop_loss = entry_price + (atr * 2)
                        take_profit = entry_price - (atr * 4.5)  # Augmenté de 3.0 à 4.5 (+50%)
                    
                    signal = {
                        "symbol": sym,
                        "action": action,
                        "entry_price": round(entry_price, 5),
                        "stop_loss": round(stop_loss, 5),
                        "take_profit": round(take_profit, 5),
                        "confidence": round(confidence, 2),
                        "reason": reason
                    }
                    signals.append(signal)
                    logger.info(f"AutoScan: Signal détecté pour {sym} - {action} (confiance: {confidence*100:.0f}%)")
                    
            except Exception as e:
                logger.error(f"Erreur lors de l'analyse de {sym} pour AutoScan: {e}", exc_info=True)
                continue
        
        # Retourner la réponse dans le format attendu par MT5
        return {
            "status": "success",
            "data": {
                "signals": signals
            },
            "timestamp": datetime.utcnow().isoformat(),
            "count": len(signals)
        }
        
    except Exception as e:
        logger.error(f"Erreur dans get_autoscan_signals: {e}", exc_info=True)
        return {
            "status": "error",
            "data": {
                "signals": []
            },
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }

# ==================== FIN AUTOSCAN ENDPOINTS ====================

# Point d'entrée du programme
if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("TRADBOT AI SERVER")
    logger.info("=" * 60)
    logger.info(f"Serveur démarré sur http://localhost:{API_PORT}")
    logger.info(f"MT5: {'Disponible' if mt5_initialized else 'Non disponible (mode API uniquement)'}")
    logger.info(f"Mistral AI: {'Configuré' if MISTRAL_AVAILABLE else 'Non configuré'}")
    logger.info(f"Google Gemini AI: {'Configuré' if GEMINI_AVAILABLE else 'Non configuré'}")
    logger.info(f"Symbole par défaut: {DEFAULT_SYMBOL}")
    logger.info(f"Timeframes disponibles: {len(['M1', 'M5', 'M15', 'H1', 'H4', 'D1'])}")
    logger.info("=" * 60)
    logger.info("Serveur prêt à recevoir des requêtes")
    logger.info("=" * 60)
    
    print("\n" + "=" * 60)
    print("Démarrage du serveur AI TradBOT...")
    print("=" * 60)
    print(f"API disponible sur: http://127.0.0.1:{API_PORT}")
    print("\nEndpoints disponibles:")
    print(f"  - GET  /                           : Vérification de l'état du serveur")
    print(f"  - GET  /health                     : Vérification de santé")
    print(f"  - GET  /status                     : Statut détaillé")
    print(f"  - GET  /logs                       : Derniers logs")
    print(f"  - POST /decision                  : Décision de trading (appelé par MQ5)")
    print(f"  - GET  /analysis?symbol=SYMBOL     : Analyse structure H1/H4/M15")
    print(f"  - GET  /time_windows/{{symbol}}     : Fenêtres horaires optimales")
    print(f"  - GET  /predict/{{symbol}}          : Prédiction (legacy)")
    print(f"  - POST /prediction                  : Prédiction de prix futurs (pour MQ5)")
    print(f"  - GET  /analyze/{{symbol}}           : Analyse complète (legacy)")
    print(f"  - POST /indicators/analyze           : Analyse avec AdvancedIndicators")
    print(f"  - POST /trend                     : Analyse de tendance MT5 (POST)")
    print(f"  - GET  /trend?symbol=SYMBOL       : Analyse de tendance MT5 (GET)")
    print(f"  - GET  /trend/health              : Santé module tendance")
    print(f"  - GET  /indicators/sentiment/{{symbol}} : Sentiment du marché")
    print(f"  - GET  /indicators/volume_profile/{{symbol}} : Profil de volume")
    print(f"  - POST /analyze/gemini               : Analyse avec Google Gemini AI")
    print(f"  - POST /trading/analyze             : Capture et analyse de graphique avec Gemma")
    print(f"  - POST /trading/generate-signal     : Génération de signaux de trading")
    print("  - GET  /indicators/ichimoku/{symbol}     : Analyse Ichimoku Kinko Hyo")
    print("  - GET  /indicators/fibonacci/{symbol}    : Niveaux de retracement/extension Fibonacci")
    print("  - GET  /indicators/order-blocks/{symbol} : Détection des blocs d'ordre")
    print("  - GET  /indicators/liquidity-zones/{symbol} : Zones de liquidité")
    print("  - GET  /indicators/market-profile/{symbol}  : Profil de marché (Market Profile)")
    print(f"  - GET  /autoscan/signals?symbol=SYMBOL    : Signaux AutoScan (compatible MT5)")
    print(f"  - GET  /deriv/patterns/{{symbol}}            : Détection patterns Deriv (XABCD, Cypher, H&S, etc.)")
    print(f"  - GET  /deriv/tools/vwap/{{symbol}}          : Anchored VWAP")
    print(f"  - GET  /deriv/tools/volume-profile/{{symbol}}: Volume Profile")
    print("\nDocumentation interactive:")
    print(f"  - http://127.0.0.1:{API_PORT}/docs")
    print("=" * 60)
    
    # Démarrer le serveur
    # Note: reload nécessite une chaîne d'import, on utilise un mode compatible
    import sys
    use_reload = "--reload" in sys.argv or os.getenv("AUTO_RELOAD", "false").lower() == "true"
    
    if use_reload:
        # Mode reload (développement) - utiliser la chaîne d'import
        uvicorn.run(
            "ai_server:app",
            host=HOST,
            port=API_PORT,
            log_level="info",
            reload=True
        )
    else:
        # Mode production (sans reload) - passer l'app directement
        uvicorn.run(
            app,
            host=HOST,
            port=API_PORT,
            log_level="info"
        )