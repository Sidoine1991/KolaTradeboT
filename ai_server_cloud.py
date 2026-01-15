"""
AI Server Cloud Version - Compatible avec déploiement cloud (sans MT5)
Version optimisée pour Render/Heroku avec fallback yfinance pour les données de marché
"""

import os
import json
import time
import asyncio
import logging
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from pathlib import Path

# FastAPI imports
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# Configuration
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Variables globales
prediction_cache = {}
CACHE_DURATION = 300  # 5 minutes

# Initialisation FastAPI
app = FastAPI(
    title="TradBOT AI Server - Cloud Version",
    description="API de trading IA optimisée pour déploiement cloud",
    version="2.0.0-cloud"
)

# Configuration CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modèles de données
class PredictionRequest(BaseModel):
    symbol: str
    timeframe: Optional[str] = "M1"
    lookback: Optional[int] = 100

class TrendAnalysisRequest(BaseModel):
    symbol: str
    timeframes: Optional[List[str]] = ["M1", "M5", "M15", "H1", "H4"]

class CoherentAnalysisRequest(BaseModel):
    symbol: str
    timeframes: Optional[List[str]] = None

# Import yfinance pour les données de marché (compatible cloud)
try:
    import yfinance as yf
    YFINANCE_AVAILABLE = True
    logger.info("✅ yfinance disponible pour les données de marché")
except ImportError:
    YFINANCE_AVAILABLE = False
    logger.warning("⚠️ yfinance non disponible")

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

def get_market_data_cloud(symbol: str, period: str = "5d", interval: str = "1m") -> pd.DataFrame:
    """Récupère les données de marché via yfinance (compatible cloud)"""
    try:
        if not YFINANCE_AVAILABLE:
            # Générer des données simulées si yfinance non disponible
            logger.warning("yfinance non disponible, génération de données simulées")
            return generate_simulated_data(symbol, 100)
        
        # Mapping des symboles pour yfinance
        symbol_map = {
            "EURUSD": "EURUSD=X",
            "GBPUSD": "GBPUSD=X", 
            "USDJPY": "USDJPY=X",
            "Boom 500 Index": "^GSPC",  # S&P 500 comme proxy
            "Crash 300 Index": "^VIX",   # VIX comme proxy
            "Volatility 75 Index": "^VIX"
        }
        
        yf_symbol = symbol_map.get(symbol, symbol)
        
        # Récupérer les données
        ticker = yf.Ticker(yf_symbol)
        data = ticker.history(period=period, interval=interval)
        
        if data.empty:
            logger.warning(f"Pas de données pour {symbol}, génération simulée")
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
    """Génère des données de marché simulées réalistes"""
    try:
        np.random.seed(hash(symbol) % 2**32)  # Seed basé sur le symbole
        
        # Prix de base selon le symbole
        base_prices = {
            "EURUSD": 1.0850,
            "GBPUSD": 1.2750,
            "USDJPY": 148.50,
            "Boom 500 Index": 5000,
            "Crash 300 Index": 300,
            "Volatility 75 Index": 75
        }
        
        base_price = base_prices.get(symbol, 100)
        
        # Génération des prix avec marche aléatoire
        returns = np.random.normal(0, 0.002, periods)  # 0.2% volatilité
        prices = [base_price]
        
        for ret in returns:
            new_price = prices[-1] * (1 + ret)
            prices.append(new_price)
        
        prices = prices[1:]  # Supprimer le prix de base
        
        # Créer le DataFrame
        timestamps = pd.date_range(end=datetime.now(), periods=periods, freq='1min')
        
        df = pd.DataFrame({
            'time': timestamps.astype(np.int64) // 10**9,
            'open': prices,
            'high': [p * (1 + abs(np.random.normal(0, 0.001))) for p in prices],
            'low': [p * (1 - abs(np.random.normal(0, 0.001))) for p in prices],
            'close': prices,
            'volume': np.random.randint(1000, 10000, periods)
        })
        
        return df
        
    except Exception as e:
        logger.error(f"Erreur génération données simulées: {e}")
        # Retourner un DataFrame vide en cas d'erreur
        return pd.DataFrame()

def calculate_rsi(prices: pd.Series, period: int = 14) -> pd.Series:
    """Calcule le RSI"""
    delta = prices.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss
    return 100 - (100 / (1 + rs))

def calculate_macd(prices: pd.Series, fast: int = 12, slow: int = 26, signal: int = 9) -> Dict[str, pd.Series]:
    """Calcule le MACD"""
    ema_fast = prices.ewm(span=fast).mean()
    ema_slow = prices.ewm(span=slow).mean()
    macd_line = ema_fast - ema_slow
    signal_line = macd_line.ewm(span=signal).mean()
    histogram = macd_line - signal_line
    
    return {
        'macd': macd_line,
        'signal': signal_line,
        'histogram': histogram
    }

def calculate_bollinger_bands(prices: pd.Series, period: int = 20, std_dev: int = 2) -> Dict[str, pd.Series]:
    """Calcule les bandes de Bollinger"""
    sma = prices.rolling(window=period).mean()
    std = prices.rolling(window=period).std()
    
    return {
        'upper': sma + (std * std_dev),
        'middle': sma,
        'lower': sma - (std * std_dev)
    }

def calculate_enhanced_trend_direction_cloud(symbol: str, timeframe: str = "M1") -> Dict[str, Any]:
    """Version cloud du calcul de tendance avancée"""
    try:
        # Récupérer les données
        df = get_market_data_cloud(symbol)
        
        if df.empty or len(df) < 50:
            return {
                "direction": "neutral", 
                "confidence": 50.0, 
                "signals": ["insufficient_data"],
                "error": "Données insuffisantes"
            }
        
        current_price = df['close'].iloc[-1]
        
        # Calcul des indicateurs
        sma_20 = df['close'].rolling(window=20).mean().iloc[-1]
        sma_50 = df['close'].rolling(window=50).mean().iloc[-1]
        ema_9 = df['close'].ewm(span=9).mean().iloc[-1]
        ema_21 = df['close'].ewm(span=21).mean().iloc[-1]
        
        rsi = calculate_rsi(df['close'])
        current_rsi = rsi.iloc[-1]
        
        macd_data = calculate_macd(df['close'])
        current_macd = macd_data['macd'].iloc[-1]
        current_signal = macd_data['signal'].iloc[-1]
        
        bb_data = calculate_bollinger_bands(df['close'])
        current_bb_upper = bb_data['upper'].iloc[-1]
        current_bb_lower = bb_data['lower'].iloc[-1]
        
        # Calcul du score de tendance
        trend_score = 0.0
        signals = []
        
        # Prix vs moyennes mobiles
        if current_price > sma_20 > sma_50:
            trend_score += 2.0
            signals.append("price_above_sma")
        elif current_price < sma_20 < sma_50:
            trend_score -= 2.0
            signals.append("price_below_sma")
        
        # EMA confirmation
        if ema_9 > ema_21:
            trend_score += 1.5
            signals.append("ema_bullish")
        elif ema_9 < ema_21:
            trend_score -= 1.5
            signals.append("ema_bearish")
        
        # RSI
        if 55 < current_rsi < 75:
            trend_score += 1.0
            signals.append("rsi_bullish")
        elif 25 < current_rsi < 45:
            trend_score -= 1.0
            signals.append("rsi_bearish")
        
        # MACD
        if current_macd > current_signal:
            trend_score += 1.0
            signals.append("macd_bullish")
        elif current_macd < current_signal:
            trend_score -= 1.0
            signals.append("macd_bearish")
        
        # Bollinger
        if current_price > current_bb_upper:
            trend_score -= 0.5
            signals.append("above_bb_upper")
        elif current_price < current_bb_lower:
            trend_score += 0.5
            signals.append("below_bb_lower")
        
        # Calcul de la confiance
        base_confidence = 50.0 + abs(trend_score) * 8
        final_confidence = min(95.0, max(40.0, base_confidence))
        
        # Direction finale
        if trend_score >= 3.0:
            direction = "buy"
        elif trend_score <= -3.0:
            direction = "sell"
        else:
            direction = "neutral"
        
        return {
            "direction": direction,
            "confidence": round(final_confidence, 1),
            "trend_score": round(trend_score, 2),
            "signals": signals,
            "rsi": round(current_rsi, 1),
            "macd": round(current_macd, 5),
            "price": round(current_price, 5),
            "sma_20": round(sma_20, 5),
            "sma_50": round(sma_50, 5),
            "data_source": "cloud_yfinance" if YFINANCE_AVAILABLE else "simulated"
        }
        
    except Exception as e:
        logger.error(f"Erreur tendance cloud pour {symbol}: {e}")
        return {
            "direction": "neutral",
            "confidence": 50.0,
            "signals": ["error"],
            "error": str(e)
        }

async def calculate_coherent_analysis_cloud(symbol: str, timeframes: Optional[List[str]] = None) -> Dict[str, Any]:
    """Version cloud de l'analyse cohérente"""
    if timeframes is None:
        timeframes = ["M1", "M5", "M15", "H1"]
    
    try:
        trends = {}
        
        for tf in timeframes:
            trend_data = calculate_enhanced_trend_direction_cloud(symbol, tf)
            trends[tf.lower()] = {
                "direction": trend_data.get("direction", "neutral"),
                "strength": trend_data.get("confidence", 50),
                "bullish": trend_data.get("direction") == "buy",
                "bearish": trend_data.get("direction") == "sell"
            }
        
        # Pondération des timeframes
        timeframe_weights = {
            'm1': 0.10,
            'm5': 0.15,
            'm15': 0.25,
            'h1': 0.50
        }
        
        # Calcul de la cohérence
        bullish_count = 0.0
        bearish_count = 0.0
        neutral_count = 0.0
        
        for tf, weight in timeframe_weights.items():
            if tf in trends:
                direction = trends[tf]["direction"]
                if direction == "buy":
                    bullish_count += weight
                elif direction == "sell":
                    bearish_count += weight
                else:
                    neutral_count += weight
        
        total_weight = bullish_count + bearish_count + neutral_count
        if total_weight == 0:
            return {
                "status": "error",
                "message": "Aucune donnée valide",
                "decision": "EN ATTENTE",
                "confidence": 0
            }
        
        bullish_pct = (bullish_count / total_weight) * 100
        bearish_pct = (bearish_count / total_weight) * 100
        
        # Décision finale
        if bullish_pct >= 70:
            decision = "ACHAT FORT"
        elif bearish_pct >= 70:
            decision = "VENTE FORTE"
        elif bullish_pct >= 55:
            decision = "ACHAT MODÉRÉ"
        elif bearish_pct >= 55:
            decision = "VENTE MODÉRÉE"
        else:
            decision = "ATTENTE"
        
        confidence = max(bullish_pct, bearish_pct)
        
        return {
            "status": "success",
            "symbol": symbol,
            "decision": decision,
            "confidence": round(confidence, 1),
            "bullish_pct": round(bullish_pct, 1),
            "bearish_pct": round(bearish_pct, 1),
            "trends": trends,
            "timestamp": datetime.now().isoformat(),
            "data_source": "cloud_version"
        }
        
    except Exception as e:
        logger.error(f"Erreur analyse cohérente cloud {symbol}: {e}")
        return {
            "status": "error",
            "message": str(e),
            "decision": "EN ATTENTE",
            "confidence": 0
        }

# Endpoints API
@app.get("/")
async def root():
    """Page d'accueil de l'API"""
    return {
        "message": "TradBOT AI Server - Cloud Version",
        "version": "2.0.0-cloud",
        "status": "running",
        "features": {
            "yfinance_data": YFINANCE_AVAILABLE,
            "ml_models": ML_MODELS_AVAILABLE,
            "cloud_compatible": True
        },
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health_check():
    """Vérification de l'état du serveur"""
    return {
        "status": "healthy",
        "version": "cloud",
        "timestamp": datetime.now().isoformat(),
        "yfinance_available": YFINANCE_AVAILABLE,
        "ml_models_available": ML_MODELS_AVAILABLE,
        "cache_size": len(prediction_cache)
    }

@app.post("/predict")
async def predict_prices_cloud(request: PredictionRequest):
    """Endpoint de prédiction compatible cloud"""
    try:
        # Récupérer les données
        df = get_market_data_cloud(request.symbol)
        
        if df.empty:
            raise HTTPException(status_code=404, detail="Données non disponibles")
        
        # Analyse de tendance
        trend_analysis = calculate_enhanced_trend_direction_cloud(request.symbol, request.timeframe)
        
        # Analyse cohérente
        coherent_analysis = await calculate_coherent_analysis_cloud(request.symbol)
        
        # Prédiction basée sur l'analyse
        prediction = {
            "symbol": request.symbol,
            "timeframe": request.timeframe,
            "prediction": trend_analysis["direction"],
            "confidence": trend_analysis["confidence"],
            "signals": trend_analysis["signals"],
            "coherent_analysis": coherent_analysis,
            "current_price": trend_analysis.get("price", 0),
            "rsi": trend_analysis.get("rsi", 50),
            "data_source": trend_analysis.get("data_source", "unknown"),
            "timestamp": datetime.now().isoformat()
        }
        
        return prediction
        
    except Exception as e:
        logger.error(f"Erreur prédiction cloud: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/coherent-analysis")
async def get_coherent_analysis_cloud(request: CoherentAnalysisRequest):
    """Endpoint d'analyse cohérente compatible cloud"""
    try:
        analysis = await calculate_coherent_analysis_cloud(request.symbol, request.timeframes)
        return analysis
    except Exception as e:
        logger.error(f"Erreur analyse cohérente cloud: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/trend")
async def get_trend_analysis_cloud(symbol: str = "EURUSD", timeframe: str = "M1"):
    """Endpoint d'analyse de tendance compatible cloud"""
    try:
        trend_analysis = calculate_enhanced_trend_direction_cloud(symbol, timeframe)
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": datetime.now().isoformat(),
            **trend_analysis
        }
    except Exception as e:
        logger.error(f"Erreur tendance cloud: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Point d'entrée
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(
        "ai_server_cloud:app",
        host="0.0.0.0",
        port=port,
        reload=True
    )
