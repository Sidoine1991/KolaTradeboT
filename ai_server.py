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
import threading
import requests
import json
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, List, Dict, Any, Tuple, Callable
from fastapi import FastAPI, HTTPException, Request, Body, Response, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn
import pandas as pd
import numpy as np
from urllib.parse import urlparse, parse_qs

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

# Tentative d'importation de MetaTrader5 (optionnel)
try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
    logger.info("MetaTrader5 disponible")
except ImportError:
    MT5_AVAILABLE = False
    logger.info("MetaTrader5 n'est pas installé - le serveur fonctionnera en mode API uniquement (sans connexion MT5)")

# Tentative d'importation de Mistral AI (optionnel)
try:
    from mistralai import Mistral
    MISTRAL_AVAILABLE = True
    mistral_api_key = os.getenv("MISTRAL_API_KEY")
    if mistral_api_key:
        mistral_client = Mistral(api_key=mistral_api_key)
        logger.info("Mistral AI disponible")
    else:
        MISTRAL_AVAILABLE = False
        logger.info("Mistral AI: Non configuré (MISTRAL_API_KEY manquant)")
except ImportError:
    MISTRAL_AVAILABLE = False
    logger.info("Mistral AI: Non disponible (package non installé)")

# Tentative d'importation de Google Gemini AI (optionnel)
try:
    import google.generativeai as genai
    GEMINI_AVAILABLE = True
    gemini_api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if gemini_api_key:
        genai.configure(api_key=gemini_api_key)
        gemini_model = genai.GenerativeModel("gemini-1.5-flash")
        logger.info("Google Gemini AI disponible")
    else:
        GEMINI_AVAILABLE = False
        logger.info("Google Gemini AI: Non configuré (GEMINI_API_KEY ou GOOGLE_API_KEY manquant)")
except ImportError:
    GEMINI_AVAILABLE = False
    gemini_model = None
    logger.info("Google Gemini AI: Non disponible (package google-generativeai non installé)")
except Exception as e:
    GEMINI_AVAILABLE = False
    gemini_model = None
    logger.warning(f"Google Gemini AI: Erreur d'initialisation: {e}")

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

# Tentative d'importation des modules backend (optionnel)
import time
import threading
import schedule
from datetime import datetime, timedelta
from typing import List, Dict, Optional
import json
import random

try:
    sys.path.insert(0, str(Path(__file__).parent / "backend"))
    from advanced_ml_predictor import AdvancedMLPredictor
    from spike_predictor import AdvancedSpikePredictor
    from mt5_connector import get_historical_data, get_all_symbols, get_ohlc
    from trend_summary import get_multi_timeframe_trend
    BACKEND_AVAILABLE = True
    logger.info("Modules backend disponibles")
except ImportError as e:
    BACKEND_AVAILABLE = False
    logger.warning(f"Modules backend non disponibles: {e}")

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

# Variables globales
API_PORT = 8000
TREND_API_PORT = 8001
CACHE_DURATION = 30  # secondes
TREND_CACHE_DURATION = 30  # secondes

# Configuration des notifications de tendance
TREND_SUMMARY_INTERVAL = 300  # 5 minutes en secondes
TRACKED_SYMBOLS = ["Boom 300 Index", "Crash 300 Index"]  # Symboles à suivre
NOTIFICATION_WEBHOOK = os.getenv("DISCORD_WEBHOOK_URL")  # Optionnel: webhook Discord pour les notifications

# Thread pour l'API Trend
trend_api_thread = None
TREND_DATA_FILE = Path("trend_data.json")
DATA_DIR = Path("data")
MODELS_DIR = Path("models")
LOG_FILE = Path("ai_server.log")
DEFAULT_SYMBOL = "Volatility 75 Index"

# Création des répertoires si nécessaire
for directory in [DATA_DIR, MODELS_DIR]:
    directory.mkdir(exist_ok=True)

# Cache pour les prédictions
prediction_cache = {}
last_updated = {}

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
    rsi: float
    ema_fast_h1: float
    ema_slow_h1: float
    ema_fast_m1: float
    ema_slow_m1: float
    atr: float
    dir_rule: int
    is_spike_mode: bool
    vwap: Optional[float] = None  # VWAP (Volume Weighted Average Price)
    vwap_distance: Optional[float] = None  # Distance au VWAP en %
    above_vwap: Optional[bool] = None  # Prix au-dessus du VWAP
    supertrend_trend: Optional[int] = None  # 1 = UP, -1 = DOWN, 0 = indéterminé
    supertrend_line: Optional[float] = None  # Ligne SuperTrend
    volatility_regime: Optional[int] = None  # 1 = High Vol, 0 = Normal, -1 = Low Vol
    volatility_ratio: Optional[float] = None  # Ratio ATR court/long

class DecisionResponse(BaseModel):
    action: str  # "buy", "sell", "hold"
    confidence: float  # 0.0-1.0
    reason: str
    spike_prediction: bool = False
    spike_zone_price: Optional[float] = None
    spike_direction: Optional[bool] = None  # True=BUY, False=SELL
    early_spike_warning: bool = False
    early_spike_zone_price: Optional[float] = None
    early_spike_direction: Optional[bool] = None
    buy_zone_low: Optional[float] = None
    buy_zone_high: Optional[float] = None
    sell_zone_low: Optional[float] = None
    sell_zone_high: Optional[float] = None

class TrendlineData(BaseModel):
    start: Dict[str, Any]  # {"time": timestamp, "price": float}
    end: Dict[str, Any]    # {"time": timestamp, "price": float}

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
    # Essayer d'abord MT5 si disponible
    if mt5_initialized:
        df = get_historical_data_mt5(symbol, timeframe, count)
        if df is not None and not df.empty:
            return df
    
    # Fallback sur une autre source (par exemple, un fichier local ou une API)
    # Ici, vous pourriez ajouter la logique pour récupérer les données depuis une autre source
    # Par exemple, depuis un fichier CSV local ou une API tierce
    
    # Exemple de fallback avec un fichier CSV local (à adapter selon votre structure)
    try:
        data_file = Path(f"data/{symbol}_{timeframe}.csv")
        if data_file.exists():
            df = pd.read_csv(data_file)
            if 'time' in df.columns:
                df['time'] = pd.to_datetime(df['time'])
                return df.tail(count) if len(df) > count else df
    except Exception as e:
        logger.warning(f"Impossible de charger les données depuis le fichier local: {e}")
    
    # Si aucune source n'est disponible, retourner un DataFrame vide
    logger.warning(f"Aucune source de données disponible pour {symbol} {timeframe}")
    return pd.DataFrame()

def get_historical_data_mt5(symbol: str, timeframe: str = "H1", count: int = 500):
    """Récupère les données historiques depuis MT5"""
    if not mt5_initialized:
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
            return None
        
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        return df
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des données MT5: {e}")
        return None

def analyze_with_mistral(prompt: str) -> Optional[str]:
    """Analyse avec Mistral AI si disponible"""
    if not MISTRAL_AVAILABLE or not mistral_api_key:
        return None
    
    try:
        response = mistral_client.chat.complete(
            model="mistral-small-latest",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.2,
            max_tokens=512
        )
        return response.choices[0].message.content
    except Exception as e:
        logger.error(f"Erreur Mistral AI: {e}")
        return None

def analyze_with_gemini(prompt: str) -> Optional[str]:
    """Analyse avec Google Gemini AI si disponible"""
    if not GEMINI_AVAILABLE or not gemini_model:
        return None
    
    try:
        response = gemini_model.generate_content(prompt)
        if hasattr(response, 'text'):
            return response.text
        elif hasattr(response, 'candidates') and response.candidates:
            return response.candidates[0].text
        return None
    except Exception as e:
        logger.error(f"Erreur Gemini AI: {e}")
        return None

def analyze_with_ai(prompt: str) -> Optional[str]:
    """Analyse avec IA (Gemini en priorité, puis Mistral en fallback)"""
    # Essayer Gemini d'abord
    result = analyze_with_gemini(prompt)
    if result:
        return result
    
    # Fallback sur Mistral
    result = analyze_with_mistral(prompt)
    if result:
        return result
    
    return None

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
            if all(df.iloc[i]['high'] >= df.iloc[i+j]['high'] for j in range(-lookback, lookback+1) if j != 0):
                highs.append({
                    'index': i,
                    'time': df.iloc[i]['time'],
                    'price': df.iloc[i]['high']
                })
            
            # Swing low
            if all(df.iloc[i]['low'] <= df.iloc[i+j]['low'] for j in range(-lookback, lookback+1) if j != 0):
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
            "/health",
            "/status",
            "/logs",
            "/indicators/analyze (POST)",
            "/indicators/sentiment/{symbol} (GET)",
            "/indicators/volume_profile/{symbol} (GET)",
            "/analyze/gemini (POST)",
            "/autoscan/start (POST) - Démarrer le scan automatique",
            "/autoscan/stop (POST) - Arrêter le scan automatique",
            "/autoscan/status (GET) - Statut du scan",
            "/autoscan/results (GET) - Résultats du scan",
            "/autoscan/signals (GET) - Signaux détectés",
            "/autoscan/scan (POST) - Lancer un scan manuel",
            "/autoscan/config (POST) - Configuration du scan"
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
            if "/" in av_symbol or any(c in symbol.upper() for c in ["USD", "EUR", "GBP", "JPY", "CHF", "AUD", "NZD", "CAD"]):
                from_currency = av_symbol[:3] if len(av_symbol) >= 6 else "USD"
                to_currency = av_symbol[3:6] if len(av_symbol) >= 6 else av_symbol[:3]
                url = f"https://www.alphavantage.co/query?function=CURRENCY_EXCHANGE_RATE&from_currency={from_currency}&to_currency={to_currency}&apikey={ALPHAVANTAGE_API_KEY}"
                resp = await client.get(url)
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
        "Step Index": "stpRNG",
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
        "Step Index": "stpRNG",
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

# ==================== END DERIV API ====================

# ==================== AUTOSCAN ENDPOINTS ====================

@app.post("/autoscan/start")
async def start_autoscan(interval_minutes: int = 5):
    """Démarre le scan automatique des symboles."""
    try:
        success = autoscan_manager.start()
        if success:
            return {
                "status": "success",
                "message": f"Scan automatique démarré avec un intervalle de {interval_minutes} minutes",
                "scan_interval": interval_minutes
            }
        else:
            return {
                "status": "error",
                "message": "Le scan est déjà en cours d'exécution"
            }
    except Exception as e:
        logger.error(f"Erreur lors du démarrage de l'autoscan: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur lors du démarrage de l'autoscan: {str(e)}")

@app.post("/autoscan/stop")
async def stop_autoscan():
    """Arrête le scan automatique des symboles."""
    try:
        autoscan_manager.stop()
        return {
            "status": "success",
            "message": "Scan automatique arrêté"
        }
    except Exception as e:
        logger.error(f"Erreur lors de l'arrêt de l'autoscan: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur lors de l'arrêt de l'autoscan: {str(e)}")

@app.get("/autoscan/status")
async def get_autoscan_status():
    """Retourne le statut actuel du scan automatique."""
    try:
        status = autoscan_manager.get_status()
        return {
            "status": "success",
            "data": status
        }
    except Exception as e:
        logger.error(f"Erreur lors de la récupération du statut de l'autoscan: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération du statut: {str(e)}")

@app.get("/autoscan/results")
async def get_autoscan_results():
    """Retourne les derniers résultats du scan."""
    try:
        results = autoscan_manager.get_latest_results()
        return {
            "status": "success",
            "data": results
        }
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des résultats de l'autoscan: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération des résultats: {str(e)}")

@app.post("/autoscan/scan")
async def manual_scan():
    """Effectue un scan manuel immédiat."""
    try:
        def run_scan():
            autoscan_manager._perform_scan()
        
        thread = threading.Thread(target=run_scan, daemon=True)
        thread.start()
        
        return {
            "status": "success",
            "message": "Scan manuel démarré en arrière-plan"
        }
    except Exception as e:
        logger.error(f"Erreur lors du lancement du scan manuel: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur lors du lancement du scan manuel: {str(e)}")

@app.get("/autoscan/signals")
async def get_autoscan_signals():
    """Retourne uniquement les signaux détectés lors du dernier scan."""
    try:
        results = autoscan_manager.get_latest_results()
        signals = results.get('signals', [])
        
        return {
            "status": "success",
            "data": {
                "signals": signals,
                "count": len(signals),
                "timestamp": results.get('timestamp')
            }
        }
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des signaux: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération des signaux: {str(e)}")

@app.post("/autoscan/config")
async def update_autoscan_config(config: Dict[str, Any]):
    """Met à jour la configuration de l'autoscan."""
    try:
        if 'scan_interval_minutes' in config:
            new_interval = config['scan_interval_minutes']
            if isinstance(new_interval, int) and new_interval >= 1:
                autoscan_manager.scan_interval = new_interval
                logger.info(f"Intervalle de scan mis à jour: {new_interval} minutes")
            else:
                raise HTTPException(status_code=400, detail="L'intervalle de scan doit être un entier >= 1")
        
        return {
            "status": "success",
            "message": "Configuration de l'autoscan mise à jour",
            "current_config": {
                "scan_interval_minutes": autoscan_manager.scan_interval
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de la mise à jour de la configuration de l'autoscan: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur lors de la mise à jour de la configuration: {str(e)}")

# ==================== END AUTOSCAN ENDPOINTS ====================

@app.get("/health")
async def health_check():
    """Vérification de l'état du serveur"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "cache_size": len(prediction_cache),
        "mt5_initialized": mt5_initialized,
        "mistral_available": MISTRAL_AVAILABLE,
        "gemini_available": GEMINI_AVAILABLE,
        "deriv_available": DERIV_AVAILABLE,
        "alphavantage_requests_remaining": ALPHAVANTAGE_DAILY_LIMIT - alphavantage_request_count
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
        "default_symbol": DEFAULT_SYMBOL
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

@app.post("/decision", response_model=DecisionResponse)
async def decision(request: DecisionRequest):
    """
    Endpoint principal pour les décisions de trading
    Appelé par le robot MQ5 avec les données de marché en temps réel
    """
    try:
        logger.info(f"Requête reçue: /decision - Données: {request.model_dump_json()}")
        
        # Vérifier si la décision est en cache
        cache_key = f"{request.symbol}_{request.bid:.2f}_{request.ask:.2f}"
        current_time = time.time()
        
        if cache_key in prediction_cache and \
           (current_time - last_updated.get(cache_key, 0)) < CACHE_DURATION:
            cached = prediction_cache[cache_key]
            logger.debug(f"Retour depuis cache pour {request.symbol}")
            return DecisionResponse(**cached)
        
        # Analyse des indicateurs techniques
        rsi = request.rsi
        ema_fast_h1 = request.ema_fast_h1
        ema_slow_h1 = request.ema_slow_h1
        ema_fast_m1 = request.ema_fast_m1
        ema_slow_m1 = request.ema_slow_m1
        bid = request.bid
        ask = request.ask
        mid_price = (bid + ask) / 2
        
        # Logique de décision basique
        action = "hold"
        confidence = 0.5
        reason = "Analyse en cours"
        
        # Analyse RSI
        rsi_bullish = rsi < 30  # Survente
        rsi_bearish = rsi > 70  # Surachat
        
        # Analyse EMA H1 (tendance long terme)
        h1_bullish = ema_fast_h1 > ema_slow_h1
        h1_bearish = ema_fast_h1 < ema_slow_h1
        
        # Analyse EMA M1 (tendance court terme)
        m1_bullish = ema_fast_m1 > ema_slow_m1
        m1_bearish = ema_fast_m1 < ema_slow_m1
        
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
        
        # Décision combinée (incluant VWAP et SuperTrend)
        bullish_signals = sum([rsi_bullish, h1_bullish, m1_bullish, vwap_signal_buy, supertrend_bullish])
        bearish_signals = sum([rsi_bearish, h1_bearish, m1_bearish, vwap_signal_sell, supertrend_bearish])
        
        # Appliquer le filtre de volatilité
        if not volatility_ok:
            action = "hold"
            confidence = 0.2
            reason = "Régime de faible volatilité détecté - Attente"
        elif bullish_signals >= 2:
            action = "buy"
            confidence = min(0.5 + (bullish_signals * 0.12), 0.95)
            vwap_note = f", VWAP={'✓' if vwap_signal_buy else '✗'}"
            st_note = f", SuperTrend={'✓' if supertrend_bullish else '✗'}"
            reason = f"Signaux haussiers: RSI={rsi_bullish}, H1={h1_bullish}, M1={m1_bullish}{vwap_note}{st_note}"
        elif bearish_signals >= 2:
            action = "sell"
            confidence = min(0.5 + (bearish_signals * 0.12), 0.95)
            vwap_note = f", VWAP={'✓' if vwap_signal_sell else '✗'}"
            st_note = f", SuperTrend={'✓' if supertrend_bearish else '✗'}"
            reason = f"Signaux baissiers: RSI={rsi_bearish}, H1={h1_bearish}, M1={m1_bearish}{vwap_note}{st_note}"
        else:
            action = "hold"
            confidence = 0.3
            reason = "Signaux mixtes, attente de confirmation"
        
        # Utiliser Gemini AI pour améliorer la raison si disponible
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
        
        # Utiliser AdvancedIndicators pour améliorer l'analyse si disponible
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
                        bullish_signals += 1
                        reason += f" | Sentiment: {sentiment.get('trend', 'neutral')}"
                    elif sentiment.get('sentiment', 0) < -0.3:
                        bearish_signals += 1
                        reason += f" | Sentiment: {sentiment.get('trend', 'neutral')}"
                    
                    # Ajuster la confiance selon le sentiment
                    sentiment_strength = abs(sentiment.get('sentiment', 0))
                    if sentiment_strength > 0.5:
                        confidence = min(confidence + 0.1, 0.95)
            except Exception as e:
                logger.warning(f"Erreur AdvancedIndicators dans decision: {e}")
        
        # Utiliser le prédicteur de spike si disponible
        spike_prediction = False
        spike_zone_price = None
        spike_direction = None
        early_spike_warning = False
        early_spike_zone_price = None
        early_spike_direction = None
        
        if spike_predictor and ("Boom" in request.symbol or "Crash" in request.symbol):
            try:
                # Récupérer les données historiques pour le prédicteur
                df = get_historical_data_mt5(request.symbol, "M1", 100)
                if df is not None and len(df) > 0:
                    confluence = spike_predictor.calculate_ema_confluence(df)
                    if confluence.get('confluence_strength', 0) > 0.7:
                        spike_prediction = True
                        spike_zone_price = mid_price
                        spike_direction = confluence.get('trend_direction') == 'BULLISH'
                        reason += " | Spike détecté par ML"
            except Exception as e:
                logger.warning(f"Erreur prédicteur spike: {e}")
        
        # Détection de spike basique si ML non disponible (Boom / Crash uniquement)
        if not spike_prediction and ("Boom" in request.symbol or "Crash" in request.symbol):
            is_boom = "Boom" in request.symbol
            is_crash = "Crash" in request.symbol

            volatility = request.atr / mid_price if mid_price > 0 else 0

            # Conditions de base communes
            strong_vol = volatility >= 0.002   # ~0.2% de range minimum
            medium_vol = volatility >= 0.001   # ~0.1% pour pré-alerte

            # Spike haussier (Boom / Crash avec retournement haussier)
            strong_bull_spike = (
                strong_vol
                and rsi <= 25                    # RSI très bas (survente marquée)
                and h1_bullish and m1_bullish    # Alignement H1 + M1
                and request.dir_rule >= 0        # Règle de direction compatible BUY / neutre
            )

            # Spike baissier (Crash / Boom avec retournement baissier)
            strong_bear_spike = (
                strong_vol
                and rsi >= 75                    # RSI très haut (surachat marqué)
                and h1_bearish and m1_bearish    # Alignement H1 + M1
                and request.dir_rule <= 0        # Règle de direction compatible SELL / neutre
            )

            if strong_bull_spike or strong_bear_spike:
                spike_prediction = True
                spike_zone_price = mid_price
                # true = BUY, false = SELL
                spike_direction = strong_bull_spike
                reason += " | Spike détecté (conditions strictes)"

            # Pré-alerte plus souple (affichage flèche + countdown, sans exécution auto)
            elif medium_vol and (rsi <= 30 or rsi >= 70):
                early_spike_warning = True
                early_spike_zone_price = mid_price
                early_spike_direction = rsi <= 30
                reason += " | Pré-alerte spike (conditions modérées)"
        
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
            "sell_zone_high": sell_zone_high
        }
        
        # Mise en cache
        prediction_cache[cache_key] = response_data
        last_updated[cache_key] = current_time
        
        return DecisionResponse(**response_data)
        
    except Exception as e:
        logger.error(f"Erreur dans /decision: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/analysis", response_model=AnalysisResponse)
async def analysis(symbol: str):
    """
    Analyse complète de la structure de marché (H1, H4, M15)
    Inclut les trendlines et figures chartistes (ETE, etc.)
    """
    try:
        logger.info(f"Requête /analysis pour {symbol}")
        
        response = {
            "symbol": symbol,
            "timestamp": datetime.now().isoformat(),
            "h1": {},
            "h4": {},
            "m15": {},
            "ete": None
        }
        
        # Récupérer les données historiques depuis MT5 si disponible
        if mt5_initialized:
            # Analyse H1
            df_h1 = get_historical_data_mt5(symbol, "H1", 400)
            if df_h1 is not None:
                response["h1"] = detect_trendlines(df_h1)
            
            # Analyse H4
            df_h4 = get_historical_data_mt5(symbol, "H4", 400)
            if df_h4 is not None:
                response["h4"] = detect_trendlines(df_h4)
            
            # Analyse M15
            df_m15 = get_historical_data_mt5(symbol, "M15", 400)
            if df_m15 is not None:
                response["m15"] = detect_trendlines(df_m15)
        
        return AnalysisResponse(**response)
        
    except Exception as e:
        logger.error(f"Erreur dans /analysis: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

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

# Endpoint pour les signaux en temps réel
@app.get("/signals/{symbol}")
async def get_signals(symbol: str):
    """Génère des signaux de trading en temps réel"""
    try:
        if not mt5_initialized:
            return {"error": "MT5 non initialisé"}
        
        # Récupérer les dernières données
        rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, 100)
        if rates is None or len(rates) == 0:
            return {"error": "Aucune donnée disponible"}
        
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        
        # Calculer les indicateurs
        df['sma_20'] = df['close'].rolling(20).mean()
        df['sma_50'] = df['close'].rolling(50).mean()
        
        # Calculer RSI
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        df['rsi'] = 100 - (100 / (1 + rs))
        
        current_price = df['close'].iloc[-1]
        current_rsi = df['rsi'].iloc[-1]
        sma_20 = df['sma_20'].iloc[-1]
        sma_50 = df['sma_50'].iloc[-1]
        
        # Générer les signaux
        signals = []
        
        # Signal SMA crossover
        if len(df) > 1:
            prev_sma20 = df['sma_20'].iloc[-2]
            prev_sma50 = df['sma_50'].iloc[-2]
            
            if pd.notna(sma_20) and pd.notna(sma_50):
                if sma_20 > sma_50 and prev_sma20 <= prev_sma50:
                    signals.append({
                        "type": "BUY",
                        "reason": "SMA 20 croise au-dessus de SMA 50",
                        "confidence": 0.7
                    })
                elif sma_20 < sma_50 and prev_sma20 >= prev_sma50:
                    signals.append({
                        "type": "SELL",
                        "reason": "SMA 20 croise en-dessous de SMA 50",
                        "confidence": 0.7
                    })
        
        # Signal RSI
        if pd.notna(current_rsi):
            if current_rsi < 30:
                signals.append({
                    "type": "BUY",
                    "reason": "RSI en survente",
                    "confidence": 0.6
                })
            elif current_rsi > 70:
                signals.append({
                    "type": "SELL",
                    "reason": "RSI en surachat",
                    "confidence": 0.6
                })
        
        return {
            "symbol": symbol,
            "timestamp": datetime.now().isoformat(),
            "current_price": float(current_price),
            "indicators": {
                "rsi": float(current_rsi) if pd.notna(current_rsi) else None,
                "sma_20": float(sma_20) if pd.notna(sma_20) else None,
                "sma_50": float(sma_50) if pd.notna(sma_50) else None
            },
            "signals": signals
        }
    except Exception as e:
        logger.error(f"Erreur signaux: {e}")
        return {"error": str(e)}

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
            return {"valid": True, "warning": "MT5 non disponible, validation limitée"}
    except Exception as e:
        logger.error(f"Erreur validation ordre: {e}")
        return {"valid": False, "reason": str(e)}

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

class AutoScanManager:
    """Gestionnaire de scan automatique des symboles pour détecter les opportunités de trading."""
    
    def __init__(self, scan_interval_minutes: int = 10):
        """Initialise le gestionnaire de scan."""
        self.scan_interval = scan_interval_minutes
        self.running = False
        self.thread = None
        self.last_scan_time = None
        self.scan_results = {}
        self.scan_lock = threading.Lock()
        self.logger = logging.getLogger("autoscan")
        
    def start(self):
        """Démarre le scan automatique en arrière-plan."""
        if self.running:
            self.logger.warning("Le scan est déjà en cours d'exécution")
            return False
            
        self.running = True
        self.thread = threading.Thread(target=self._run_scan_loop, daemon=True)
        self.thread.start()
        self.logger.info(f"Scan automatique démarré avec un intervalle de {self.scan_interval} minutes")
        return True
        
    def stop(self):
        """Arrête le scan automatique."""
        self.running = False
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=5)
        self.logger.info("Scan automatique arrêté")
        
    def _run_scan_loop(self):
        """Boucle principale du scan automatique."""
        while self.running:
            try:
                self._perform_scan()
                time.sleep(self.scan_interval * 60)
            except Exception as e:
                self.logger.error(f"Erreur dans la boucle de scan: {e}")
                time.sleep(30)
                
    def _perform_scan(self):
        """Effectue un scan complet de tous les symboles."""
        if not BACKEND_AVAILABLE:
            self.logger.warning("Modules backend non disponibles - scan impossible")
            return
            
        start_time = time.time()
        self.logger.info("Début du scan automatique des symboles")
        
        try:
            # Récupérer tous les symboles disponibles
            symbols = self._get_symbols_to_scan()
            signals_found = []
            
            for symbol in symbols:
                if not self.running:
                    break
                    
                try:
                    signal = self._scan_symbol(symbol)
                    if signal:
                        signals_found.append(signal)
                        self.logger.info(f"Signal détecté pour {symbol}: {signal['action']}")
                except Exception as e:
                    self.logger.error(f"Erreur lors du scan de {symbol}: {e}")
                    
            # Stocker les résultats
            with self.scan_lock:
                self.scan_results = {
                    'timestamp': datetime.now().isoformat(),
                    'signals': signals_found,
                    'symbols_scanned': len(symbols),
                    'scan_duration': time.time() - start_time
                }
                
            self.logger.info(f"Scan terminé: {len(signals_found)} signaux trouvés sur {len(symbols)} symboles")
            
        except Exception as e:
            self.logger.error(f"Erreur lors du scan: {e}")
            
    def _get_symbols_to_scan(self) -> List[str]:
        """Récupère la liste des symboles attachés au robot (symboles actifs)."""
        if BACKEND_AVAILABLE and MT5_AVAILABLE:
            try:
                import MetaTrader5 as mt5
                if mt5.terminal_info():
                    # Récupérer les symboles actuellement ouverts dans les graphiques
                    charts = mt5.chart_get_all()
                    symbols_from_charts = set()
                    
                    for chart in charts:
                        symbol = chart.symbol
                        if symbol and symbol not in symbols_from_charts:
                            symbols_from_charts.add(symbol)
                    
                    if symbols_from_charts:
                        self.logger.info(f"Symboles détectés depuis les graphiques: {list(symbols_from_charts)}")
                        return list(symbols_from_charts)
                    
                    # Alternative: récupérer les symboles avec des positions ouvertes
                    positions = mt5.positions_get()
                    symbols_from_positions = set()
                    
                    if positions:
                        for position in positions:
                            if position.symbol not in symbols_from_positions:
                                symbols_from_positions.add(position.symbol)
                    
                    if symbols_from_positions:
                        self.logger.info(f"Symboles détectés depuis les positions: {list(symbols_from_positions)}")
                        return list(symbols_from_positions)
                    
                    # Alternative: récupérer les symboles favoris/symboles récemment utilisés
                    from mt5_connector import get_all_symbols
                    all_symbols = get_all_symbols()
                    
                    # Filtrer pour les symboles commonly traded
                    priority_symbols = []
                    other_symbols = []
                    
                    for symbol in all_symbols:
                        if any(symbol.startswith(prefix) for prefix in [
                            'EUR', 'GBP', 'USD', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD'  # Forex majeurs
                        ]):
                            if len(symbol) == 6:  # Format standard forex
                                priority_symbols.append(symbol)
                        elif any(keyword in symbol for keyword in ['Volatility', 'Boom', 'Crash', 'Step']):
                            priority_symbols.append(symbol)  # Indices synthétiques
                    
                    # Limiter à 10 symboles prioritaires pour éviter la surcharge
                    return priority_symbols[:10]
                    
            except Exception as e:
                self.logger.error(f"Erreur lors de la récupération des symboles MT5: {e}")
                
        # Retourner une liste par défaut si MT5 n'est pas disponible
        default_symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'Volatility 75 Index']
        self.logger.info(f"Utilisation des symboles par défaut: {default_symbols}")
        return default_symbols
        
    def _scan_symbol(self, symbol: str) -> Optional[Dict]:
        """Scanne un symbole individuel pour détecter des signaux avec scores d'opportunité."""
        try:
            # Récupérer les données de tendance sur plusieurs timeframes
            timeframes = ['M1', 'M5', 'M15', 'M30', 'H1', 'H4']
            trend_data = {}
            
            # Importer les fonctions de calcul de tendance directement
            import random
            
            for tf in timeframes:
                try:
                    # Simuler les données de tendance (sera remplacé par trend_api.py plus tard)
                    trend_data[tf] = {
                        'symbol': symbol,
                        'timeframe': tf,
                        'timestamp': time.time(),
                        'trend_direction': self._calculate_trend_direction(symbol, tf),
                        'trend_strength': self._calculate_trend_strength(symbol, tf),
                        'confidence': self._calculate_confidence(symbol, tf),
                        'support_levels': self._get_support_levels(symbol, tf),
                        'resistance_levels': self._get_resistance_levels(symbol, tf),
                        'volatility': self._calculate_volatility(symbol, tf),
                        'spike_probability': self._calculate_spike_probability(symbol, tf),
                        'trading_signal': self._generate_trading_signal(symbol, tf),
                        'risk_level': self._assess_symbol_risk_level(symbol, tf)
                    }
                except Exception as e:
                    self.logger.error(f"Erreur lors de l'analyse {tf} pour {symbol}: {e}")
                    trend_data[tf] = None
            
            # Calculer le score d'opportunité
            opportunity_score = self._calculate_opportunity_score(symbol, trend_data)
            
            # Récupérer le prix actuel sur M1
            if BACKEND_AVAILABLE:
                from mt5_connector import get_ohlc
                df = get_ohlc(symbol, 'M1', 2)
                if df is not None and not df.empty:
                    current_price = float(df['close'].iloc[-1])
                    
                    # Calculer TP/SL basé sur le score d'opportunité
                    atr = self._get_atr(symbol, 'M1', 14)
                    if atr and atr > 0:
                        # Ajuster TP/SL selon le score d'opportunité
                        multiplier = 1.0 + (opportunity_score['overall_score'] / 100)
                        sl_distance = atr * (1.5 / multiplier)  # SL plus serré si score élevé
                        tp_distance = atr * (3.0 * multiplier)  # TP plus large si score élevé
                        
                        sl = current_price - sl_distance if opportunity_score['direction'] == 'BUY' else current_price + sl_distance
                        tp = current_price + tp_distance if opportunity_score['direction'] == 'BUY' else current_price - tp_distance
                        
                        return {
                            'symbol': symbol,
                            'action': opportunity_score['direction'],
                            'entry_price': current_price,
                            'stop_loss': sl,
                            'take_profit': tp,
                            'confidence': opportunity_score['overall_score'] / 100,
                            'reason': f"Score d'opportunité: {opportunity_score['overall_score']:.1f}% - {opportunity_score['reason']}",
                            'timestamp': datetime.now().isoformat(),
                            'opportunity_score': opportunity_score,
                            'trend_data': trend_data,
                            'lot_size_recommendation': self._calculate_lot_size(opportunity_score['overall_score']),
                            'risk_level': opportunity_score['risk_level']
                        }
            
            return None
            
        except Exception as e:
            self.logger.error(f"Erreur lors du scan de {symbol}: {e}")
            return None
    
    # Méthodes de calcul de tendance (remplacées par trend_api.py plus tard)
    def _calculate_trend_direction(self, symbol: str, timeframe: str) -> str:
        """Calcule la direction de la tendance pour un timeframe."""
        import random
        directions = ['bullish', 'bearish', 'neutral']
        # Simulation basée sur l'heure et le symbole pour cohérence
        seed = hash(symbol + timeframe + str(int(time.time() / 300)))  # Change toutes les 5 minutes
        random.seed(seed % 1000)
        return random.choice(directions)
    
    def _calculate_trend_strength(self, symbol: str, timeframe: str) -> int:
        """Calcule la force de la tendance (0-100)."""
        import random
        seed = hash(symbol + timeframe + 'strength' + str(int(time.time() / 300)))
        random.seed(seed % 1000)
        return random.randint(40, 95)
    
    def _calculate_confidence(self, symbol: str, timeframe: str) -> int:
        """Calcule le niveau de confiance (0-100)."""
        import random
        seed = hash(symbol + timeframe + 'confidence' + str(int(time.time() / 300)))
        random.seed(seed % 1000)
        return random.randint(50, 90)
    
    def _get_support_levels(self, symbol: str, timeframe: str) -> List[float]:
        """Retourne les niveaux de support."""
        # Simulation - sera remplacé par trend_api.py
        return [1.0800, 1.0750, 1.0700]
    
    def _get_resistance_levels(self, symbol: str, timeframe: str) -> List[float]:
        """Retourne les niveaux de résistance."""
        # Simulation - sera remplacé par trend_api.py
        return [1.0900, 1.0950, 1.1000, 1.1050, 1.1100]
    
    def _calculate_volatility(self, symbol: str, timeframe: str) -> float:
        """Calcule la volatilité actuelle."""
        import random
        return round(random.uniform(0.5, 3.0), 2)
    
    def _calculate_spike_probability(self, symbol: str, timeframe: str) -> float:
        """Calcule la probabilité de spike."""
        import random
        return round(random.uniform(0.2, 0.8), 2)
    
    def _generate_trading_signal(self, symbol: str, timeframe: str) -> str:
        """Génère un signal de trading."""
        signals = ["BUY", "SELL", "HOLD"]
        import random
        return random.choice(signals)
    
    def _assess_symbol_risk_level(self, symbol: str, timeframe: str) -> str:
        """Évalue le niveau de risque."""
        risk_levels = ["LOW", "MEDIUM", "HIGH"]
        import random
        return random.choice(risk_levels)
            
    def _get_atr(self, symbol: str, timeframe: str, period: int) -> Optional[float]:
        """Calcule l'ATR pour un symbole."""
        try:
            if BACKEND_AVAILABLE:
                from mt5_connector import get_ohlc
                df = get_ohlc(symbol, timeframe, period + 1)
                if df is not None and not df.empty:
                    high = df['high'].values
                    low = df['low'].values
                    close = df['close'].values
                    
                    tr1 = high[1:] - low[1:]
                    tr2 = abs(high[1:] - close[:-1])
                    tr3 = abs(low[1:] - close[:-1])
                    
                    tr = np.maximum.reduce([tr1, tr2, tr3])
                    atr = np.mean(tr)
                    
                    return float(atr)
        except Exception as e:
            self.logger.error(f"Erreur lors du calcul de l'ATR pour {symbol}: {e}")
            
        return None
        
    def _calculate_opportunity_score(self, symbol: str, trend_data: Dict) -> Dict:
        """Calcule le score d'opportunité basé sur l'analyse multi-timeframe."""
        try:
            scores = {
                'BUY_LONG': 0,    # Achat long terme (H4/H1)
                'BUY_SHORT': 0,   # Achat court terme (M15/M5/M1)
                'SELL_LONG': 0,   # Vente long terme (H4/H1)
                'SELL_SHORT': 0   # Vente court terme (M15/M5/M1)
            }
            
            # Pondération par timeframe
            weights = {
                'H4': 0.3,
                'H1': 0.25,
                'M30': 0.2,
                'M15': 0.15,
                'M5': 0.07,
                'M1': 0.03
            }
            
            # Analyser chaque timeframe
            for tf, data in trend_data.items():
                if data and tf in weights:
                    weight = weights[tf]
                    trend_dir = data.get('trend_direction', 'neutral')
                    strength = data.get('trend_strength', 50) / 100
                    confidence = data.get('confidence', 50) / 100
                    volatility = data.get('volatility', 1.0)
                    
                    # Ajuster selon la volatilité
                    volatility_factor = min(2.0, 1.0 / volatility) if volatility > 0 else 1.0
                    
                    score = strength * confidence * weight * volatility_factor
                    
                    if trend_dir == 'bullish':
                        if tf in ['H4', 'H1']:
                            scores['BUY_LONG'] += score
                        else:
                            scores['BUY_SHORT'] += score
                    elif trend_dir == 'bearish':
                        if tf in ['H4', 'H1']:
                            scores['SELL_LONG'] += score
                        else:
                            scores['SELL_SHORT'] += score
            
            # Déterminer la meilleure direction
            best_direction = max(scores, key=scores.get)
            best_score = scores[best_direction]
            
            # Calculer le score global (0-100)
            overall_score = min(100, best_score * 100)
            
            # Évaluer le niveau de risque
            risk_level = self._assess_risk_level(trend_data, overall_score)
            
            # Générer la raison
            reason = self._generate_opportunity_reason(best_direction, scores, trend_data)
            
            return {
                'direction': 'BUY' if 'BUY' in best_direction else 'SELL',
                'term': 'LONG' if 'LONG' in best_direction else 'SHORT',
                'overall_score': overall_score,
                'detailed_scores': scores,
                'risk_level': risk_level,
                'reason': reason
            }
            
        except Exception as e:
            self.logger.error(f"Erreur calcul score d'opportunité: {e}")
            return {
                'direction': 'HOLD',
                'term': 'SHORT',
                'overall_score': 0,
                'detailed_scores': {},
                'risk_level': 'HIGH',
                'reason': 'Erreur calcul'
            }
    
    def _assess_risk_level(self, trend_data: Dict, score: float) -> str:
        """Évalue le niveau de risque basé sur les tendances et le score."""
        try:
            # Compter les tendances alignées
            bullish_count = 0
            bearish_count = 0
            total_count = 0
            
            for tf, data in trend_data.items():
                if data:
                    total_count += 1
                    trend_dir = data.get('trend_direction', 'neutral')
                    if trend_dir == 'bullish':
                        bullish_count += 1
                    elif trend_dir == 'bearish':
                        bearish_count += 1
            
            # Calculer le consensus
            if total_count == 0:
                return 'HIGH'
            
            consensus = max(bullish_count, bearish_count) / total_count
            
            # Évaluer le risque
            if score >= 75 and consensus >= 0.7:
                return 'LOW'
            elif score >= 50 and consensus >= 0.5:
                return 'MEDIUM'
            else:
                return 'HIGH'
                
        except Exception as e:
            self.logger.error(f"Erreur évaluation risque: {e}")
            return 'HIGH'
    
    def _generate_opportunity_reason(self, best_direction: str, scores: Dict, trend_data: Dict) -> str:
        """Génère une raison textuelle pour l'opportunité."""
        try:
            direction = 'Achat' if 'BUY' in best_direction else 'Vente'
            term = 'long terme' if 'LONG' in best_direction else 'court terme'
            
            # Identifier les timeframes les plus forts
            strong_timeframes = []
            for tf, data in trend_data.items():
                if data and data.get('trend_direction') in ['bullish' if 'BUY' in best_direction else 'bearish']:
                    strength = data.get('trend_strength', 0)
                    if strength >= 70:
                        strong_timeframes.append(tf)
            
            reason = f"{direction} {term}"
            if strong_timeframes:
                reason += f" - Tendance forte sur {', '.join(strong_timeframes[:3])}"
            
            return reason
            
        except Exception as e:
            self.logger.error(f"Erreur génération raison: {e}")
            return f"{direction} {term}"
    
    def _calculate_lot_size(self, opportunity_score: float) -> float:
        """Calcule la taille de position recommandée basée sur le score d'opportunité."""
        try:
            # Base lot size selon le score
            if opportunity_score >= 80:
                base_lot = 0.1  # Score très élevé
            elif opportunity_score >= 60:
                base_lot = 0.05  # Score élevé
            elif opportunity_score >= 40:
                base_lot = 0.02  # Score moyen
            else:
                base_lot = 0.01  # Score faible
            
            return round(base_lot, 2)
            
        except Exception as e:
            self.logger.error(f"Erreur calcul lot size: {e}")
            return 0.01
        
    def get_latest_results(self) -> Dict:
        """Retourne les derniers résultats du scan."""
        with self.scan_lock:
            return self.scan_results.copy()
            
    def get_status(self) -> Dict:
        """Retourne le statut actuel du scan."""
        return {
            'running': self.running,
            'scan_interval_minutes': self.scan_interval,
            'last_scan_time': self.last_scan_time,
            'latest_results': self.get_latest_results()
        }

# Instance globale du gestionnaire de scan
autoscan_manager = AutoScanManager()

# ==================== TREND SUMMARIES ====================

async def send_notification(message: str, webhook_url: str = None):
    """
    Envoie une notification via le webhook Discord si configuré
    """
    if not webhook_url and NOTIFICATION_WEBHOOK:
        webhook_url = NOTIFICATION_WEBHOOK
        
    if not webhook_url:
        logger.warning("Aucun webhook configuré pour les notifications")
        return
        
    try:
        payload = {"content": message}
        response = requests.post(
            webhook_url,
            data=json.dumps(payload),
            headers={"Content-Type": "application/json"}
        )
        response.raise_for_status()
        logger.info("Notification envoyée avec succès")
    except Exception as e:
        logger.error(f"Erreur lors de l'envoi de la notification: {str(e)}")

def generate_trend_summary(symbol: str) -> str:
    """
    Génère une synthèse de tendance pour un symbole donné.
    """
    try:
        # Récupérer les données d'analyse
        analysis = get_ichimoku_analysis(symbol)
        fib = get_fibonacci_levels(symbol)
        
        # Extraire les informations clés
        current_price = (analysis['current_price']['bid'] + analysis['current_price']['ask']) / 2
        trend = analysis['trend']
        kumo_cloud = analysis['kumo_cloud']
        
        # Construire le résumé
        summary = f"📊 *Synthèse des tendances - {symbol}*\n"
        summary += f"🕒 {datetime.now().strftime('%d/%m/%Y %H:%M')}\n\n"
        
        # Tendance actuelle
        summary += f"📈 *Tendance*: {'Haussière' if trend['direction'] == 'bullish' else 'Baissière' if trend['direction'] == 'bearish' else 'Neutre'}\n"
        summary += f"💪 Force: {trend['strength']:.1f}/100 | Confiance: {trend['confidence']:.1f}%\n"
        
        # Niveaux clés
        summary += f"\n🔑 *Niveaux Clés*\n"
        summary += f"• Prix actuel: {current_price:.5f}\n"
        summary += f"• Support: {fib['support_levels'][0]:.5f}\n"
        summary += f"• Résistance: {fib['resistance_levels'][0]:.5f}\n"
        
        # Nuage Ichimoku
        summary += f"\n☁️ *Nuage Ichimoku*\n"
        summary += f"• Position: {'Au-dessus' if kumo_cloud['price_above_cloud'] else 'En-dessous'} du nuage\n"
        summary += f"• Épaisseur: {kumo_cloud['cloud_thickness']:.5f} pips\n"
        
        # Recommandation
        summary += f"\n💡 *Recommandation*\n"
        if trend['direction'] == 'bullish' and trend['strength'] > 60:
            summary += "🟢 Opportunité d'achat\n"
        elif trend['direction'] == 'bearish' and trend['strength'] > 60:
            summary += "🔴 Opportunité de vente\n"
        else:
            summary += "⚪ Attendre un meilleur setup\n"
            
        return summary
        
    except Exception as e:
        logger.error(f"Erreur génération synthèse: {str(e)}")
        return f"❌ Erreur lors de la génération de la synthèse pour {symbol}"

async def periodic_trend_summary():
    """Tâche périodique pour générer et envoyer des synthèses de tendance"""
    while True:
        try:
            for symbol in TRACKED_SYMBOLS:
                try:
                    summary = generate_trend_summary(symbol)
                    await send_notification(f"```{summary}```")
                    logger.info(f"Synthèse de tendance envoyée pour {symbol}")
                except Exception as e:
                    logger.error(f"Erreur génération synthèse pour {symbol}: {str(e)}")
                
                # Petit délai entre chaque symbole
                await asyncio.sleep(1)
                
        except Exception as e:
            logger.error(f"Erreur dans la tâche périodique: {str(e)}")
            
        # Attendre l'intervalle défini
        await asyncio.sleep(TREND_SUMMARY_INTERVAL)

# Démarrer la tâche périodique au démarrage du serveur
@app.on_event("startup")
async def startup_event():
    asyncio.create_task(periodic_trend_summary())

# ==================== TREND API HANDLER ====================

class TrendHandler(BaseHTTPRequestHandler):
    """Gestionnaire des requêtes pour l'API Trend"""
    
    def _set_headers(self, status_code=200):
        """Définit les en-têtes de la réponse HTTP"""
        self.send_response(status_code)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type')
        self.end_headers()
    
    def do_OPTIONS(self):
        """Gère les requêtes OPTIONS pour CORS"""
        self._set_headers(200)
    
    def do_GET(self):
        """Gère les requêtes GET pour l'API Trend"""
        try:
            parsed_url = urlparse(self.path)
            path = parsed_url.path
            query_params = parse_qs(parsed_url.query)
            
            # Route racine
            if path == "/":
                response = {
                    "status": "ok",
                    "service": "TradBOT Trend API",
                    "version": "1.0.0",
                    "endpoints": [
                        "/trend?symbol=SYMBOL",
                        "/health",
                        "/status"
                    ]
                }
                self._send_json(200, response)
            
            # Endpoint de santé
            elif path == "/health":
                self._send_json(200, {"status": "ok", "timestamp": datetime.now().isoformat()})
            
            # Endpoint de statut
            elif path == "/status":
                self._send_json(200, {
                    "status": "running",
                    "port": TREND_API_PORT,
                    "last_updated": datetime.now().isoformat(),
                    "uptime_seconds": (datetime.now() - START_TIME).total_seconds()
                })
            
            # Endpoint d'analyse de tendance
            elif path == "/trend":
                symbol = query_params.get("symbol", [DEFAULT_SYMBOL])[0]
                self._handle_trend_request(symbol)
            
            # Endpoint non trouvé
            else:
                self._send_json(404, {"error": "Endpoint non trouvé"})
                
        except Exception as e:
            logger.error(f"Erreur dans l'API Trend: {str(e)}", exc_info=True)
            self._send_json(500, {"error": str(e)})
    
    def _handle_trend_request(self, symbol: str):
        """Gère une requête d'analyse de tendance"""
        try:
            # Récupérer les données historiques
            df = get_historical_data(symbol, "H1", 100)
            if df is None or df.empty:
                self._send_json(404, {"error": f"Aucune donnée disponible pour {symbol}"})
                return
            
            # Calculer les indicateurs de tendance
            trend_data = self._calculate_trend_indicators(df)
            
            # Préparer la réponse
            response = {
                "symbol": symbol,
                "timestamp": datetime.now().isoformat(),
                "trend": {
                    "direction": trend_data["direction"],
                    "strength": trend_data["strength"],
                    "confidence": trend_data["confidence"]
                },
                "levels": {
                    "support": trend_data["support_levels"],
                    "resistance": trend_data["resistance_levels"]
                },
                "indicators": {
                    "rsi": trend_data["rsi"],
                    "atr": trend_data["atr"],
                    "adx": trend_data["adx"]
                }
            }
            
            self._send_json(200, response)
            
        except Exception as e:
            logger.error(f"Erreur lors du traitement de la requête de tendance: {str(e)}", exc_info=True)
            self._send_json(500, {"error": f"Erreur lors de l'analyse de tendance: {str(e)}"})
    
    def _calculate_trend_indicators(self, df: pd.DataFrame) -> Dict:
        """Calcule les indicateurs de tendance à partir des données historiques"""
        # Calcul du RSI
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs)).iloc[-1]
        
        # Calcul de l'ATR (Average True Range)
        high_low = df['high'] - df['low']
        high_close = (df['high'] - df['close'].shift()).abs()
        low_close = (df['low'] - df['close'].shift()).abs()
        true_range = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
        atr = true_range.rolling(window=14).mean().iloc[-1]
        
        # Calcul de l'ADX (Average Directional Index)
        plus_dm = df['high'].diff()
        minus_dm = df['low'].diff()
        
        plus_dm[plus_dm < 0] = 0
        minus_dm[minus_dm > 0] = 0
        minus_dm = abs(minus_dm)
        
        tr1 = df['high'] - df['low']
        tr2 = abs(df['high'] - df['close'].shift())
        tr3 = abs(df['low'] - df['close'].shift())
        
        tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
        atr = tr.rolling(window=14).mean()
        
        plus_di = 100 * (plus_dm.rolling(window=14).mean() / atr)
        minus_di = 100 * (minus_dm.rolling(window=14).mean() / atr)
        dx = 100 * (abs(plus_di - minus_di) / (plus_di + minus_di))
        adx = dx.rolling(window=14).mean().iloc[-1]
        
        # Déterminer la direction de la tendance
        if plus_di.iloc[-1] > minus_di.iloc[-1] and adx > 25:
            direction = "bullish"
            strength = min(100, int(adx * 2))  # Normaliser entre 0-100
        elif minus_di.iloc[-1] > plus_di.iloc[-1] and adx > 25:
            direction = "bearish"
            strength = min(100, int(adx * 2))  # Normaliser entre 0-100
        else:
            direction = "neutral"
            strength = 0
        
        # Niveaux de support et résistance (simplifiés)
        support_levels = sorted(list(set(df['low'].rolling(window=20).min().dropna().tail(5).values)))[:3]
        resistance_levels = sorted(list(set(df['high'].rolling(window=20).max().dropna().tail(5).values)), reverse=True)[:3]
        
        return {
            "direction": direction,
            "strength": strength,
            "confidence": min(100, int(adx * 1.5)),  # Confiance basée sur ADX
            "rsi": round(float(rsi), 2),
            "atr": round(float(atr.iloc[-1]), 5),
            "adx": round(float(adx), 2),
            "support_levels": [round(float(x), 5) for x in support_levels],
            "resistance_levels": [round(float(x), 5) for x in resistance_levels]
        }
    
    def _send_json(self, status_code: int, data: Dict):
        """Envoie une réponse JSON avec le code de statut spécifié"""
        self._set_headers(status_code)
        self.wfile.write(json.dumps(data, default=str).encode('utf-8'))

# Variable globale pour suivre le temps de démarrage
START_TIME = datetime.now()

# Fonction pour démarrer l'API Trend
def start_trend_api():
    """Démarre l'API Trend dans un thread séparé"""
    class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
        """Serveur HTTP avec support multithread"""
        daemon_threads = True
    
    def run_trend_api():
        """Fonction exécutée dans le thread pour démarrer l'API Trend"""
        server = ThreadedHTTPServer(('0.0.0.0', TREND_API_PORT), TrendHandler)
        logger.info(f"Trend API démarrée sur le port {TREND_API_PORT}")
        server.serve_forever()
    
    global trend_api_thread
    if trend_api_thread is None or not trend_api_thread.is_alive():
        trend_api_thread = threading.Thread(target=run_trend_api, daemon=True)
        trend_api_thread.start()
        logger.info("Thread Trend API démarré")
    else:
        logger.info("Thread Trend API déjà en cours d'exécution")

# Point d'entrée du programme
if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("TRADBOT AI SERVER")
    logger.info("=" * 60)
    logger.info(f"Serveur démarré sur http://localhost:{API_PORT}")
    logger.info(f"API Trend: http://localhost:{TREND_API_PORT}")
    logger.info(f"MT5: {'Disponible' if mt5_initialized else 'Non disponible (mode API uniquement)'}")
    logger.info(f"Mistral AI: {'Configuré' if MISTRAL_AVAILABLE else 'Non configuré'}")
    logger.info(f"Google Gemini AI: {'Configuré' if GEMINI_AVAILABLE else 'Non configuré'}")
    logger.info(f"Symbole par défaut: {DEFAULT_SYMBOL}")
    logger.info(f"Backend: {'Disponible' if BACKEND_AVAILABLE else 'Non disponible'}")
    logger.info(f"AI Indicators: {'Disponible' if AI_INDICATORS_AVAILABLE else 'Non disponible'}")
    
    # Démarrer l'API Trend dans un thread séparé
    try:
        start_trend_api()
        logger.info("API Trend démarrée avec succès")
    except Exception as e:
        logger.error(f"Erreur lors du démarrage de l'API Trend: {str(e)}")
    logger.info(f"AutoScan: Intégré et prêt à démarrer")
    
    # Démarrer l'autoscan si le backend est disponible
    if BACKEND_AVAILABLE:
        try:
            autoscan_manager.start()
            logger.info("AutoScan démarré automatiquement")
        except Exception as e:
            logger.warning(f"Impossible de démarrer l'AutoScan automatiquement: {e}")
    else:
        logger.info("AutoScan non démarré - Backend non disponible")
    
    logger.info("=" * 60)
    
    def start_trend_api():
        """Démarre l'API Trend dans un thread séparé"""
        class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
            """Serveur HTTP avec support multithread"""
            daemon_threads = True
        
        def run_trend_api():
            """Fonction exécutée dans le thread pour démarrer l'API Trend"""
            server = ThreadedHTTPServer(('0.0.0.0', TREND_API_PORT), TrendHandler)
            logger.info(f"Trend API démarrée sur le port {TREND_API_PORT}")
            server.serve_forever()
        
        global trend_api_thread
        if trend_api_thread is None or not trend_api_thread.is_alive():
            trend_api_thread = threading.Thread(target=run_trend_api, daemon=True)
            trend_api_thread.start()
            logger.info("Thread Trend API démarré")
        else:
            logger.info("Thread Trend API déjà en cours d'exécution")

    start_trend_api()
    
    try:
        uvicorn.run(app, host="0.0.0.0", port=API_PORT, log_level="info")
    except KeyboardInterrupt:
        logger.info("Arrêt du serveur demandé...")
        autoscan_manager.stop()
        logger.info("AutoScan arrêté")
    except Exception as e:
        logger.error(f"Erreur lors du démarrage du serveur: {e}")
        autoscan_manager.stop()
        raise
    
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
    print(f"  - GET  /analyze/{{symbol}}           : Analyse complète (legacy)")
    print(f"  - POST /indicators/analyze           : Analyse avec AdvancedIndicators")
    print(f"  - GET  /indicators/sentiment/{{symbol}} : Sentiment du marché")
    print(f"  - GET  /indicators/volume_profile/{{symbol}} : Profil de volume")
    print(f"  - POST /analyze/gemini               : Analyse avec Google Gemini AI")
    print("  - GET  /indicators/ichimoku/{symbol}     : Analyse Ichimoku Kinko Hyo")
    print("  - GET  /indicators/fibonacci/{symbol}    : Niveaux de retracement/extension Fibonacci")
    print("  - GET  /indicators/order-blocks/{symbol} : Détection des blocs d'ordre")
    print("  - GET  /indicators/liquidity-zones/{symbol} : Zones de liquidité")
    print("  - GET  /indicators/market-profile/{symbol}  : Profil de marché (Market Profile)")
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
            host="0.0.0.0",
            port=API_PORT,
            log_level="info",
            reload=True
        )
    else:
        # Mode production (sans reload) - passer l'app directement
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=API_PORT,
            log_level="info"
        )
