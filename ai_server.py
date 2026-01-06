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
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, List, Dict, Any, Tuple
from fastapi import FastAPI, HTTPException, Request, Body, status
from starlette.requests import Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import uvicorn
import pandas as pd
import numpy as np
import requests

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

def calculate_macd(prices: pd.Series, fast: int = 12, slow: int = 26, signal: int = 9) -> pd.Series:
    exp1 = prices.ewm(span=fast, adjust=False).mean()
    exp2 = prices.ewm(span=slow, adjust=False).mean()
    macd = exp1 - exp2
    signal_line = macd.ewm(span=signal, adjust=False).mean()
    return macd - signal_line

def calculate_bollinger_bands(prices: pd.Series, window: int = 20, num_std: int = 2) -> Dict[str, pd.Series]:
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
            'H1': mt5.TIMEFRAME_H1,
            'H4': mt5.TIMEFRAME_H4,
            'D1': mt5.TIMEFRAME_D1
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
            logger.warning(f"Données manquantes détectées pour {symbol} {timeframe}, tentative de remplissage...")
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
                macd_line = df['close'].ewm(span=12, adjust=False).mean() - df['close'].ewm(span=26, adjust=False).mean()
                signal_line = macd_line.ewm(span=9, adjust=False).mean()
                indicators['macd'] = (macd_line - signal_line).iloc[-1]
            
            # Bandes de Bollinger
            if len(df) >= 20:  # Période minimale pour les bandes de Bollinger
                bb = calculate_bollinger_bands(df['close'])
                indicators.update({
                    'bb_upper': bb['upper'].iloc[-1],
                    'bb_middle': bb['middle'].iloc[-1],
                    'bb_lower': bb['lower'].iloc[-1],
                    'bb_width': (bb['upper'].iloc[-1] - bb['lower'].iloc[-1]) / bb['middle'].iloc[-1] if bb['middle'].iloc[-1] != 0 else 0
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

# Nouveaux imports pour Gemma
import torch
from PIL import Image
from transformers import AutoProcessor, AutoModelForImageTextToText, AutoModelForCausalLM

# Configuration du modèle Gemma Local
GEMMA_MODEL_PATH = r"D:\Dev\model_gemma"
MT5_FILES_DIR = r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\Common\Files" # Default, user may need to change
GEMMA_AVAILABLE = False
gemma_processor = None
gemma_model = None

try:
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

# Tentative d'importation de MetaTrader5 (optionnel)
try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
    logger.info("MetaTrader5 disponible")
except ImportError:
    MT5_AVAILABLE = False
    logger.info("MetaTrader5 n'est pas installé - le serveur fonctionnera en mode API uniquement (sans connexion MT5)")

# Configuration Mistral AI
MISTRAL_AVAILABLE = True
try:
    from mistralai.client import MistralClient
    from mistralai.models.chat_completion import ChatMessage
    
    mistral_api_key = os.getenv("MISTRAL_API_KEY", "demo_key")  # Clé par défaut pour le développement
    if not mistral_api_key:
        logger.warning("Aucune clé API Mistral trouvée. Utilisation du mode démo limité.")
        MISTRAL_AVAILABLE = False
    else:
        mistral_client = MistralClient(api_key=mistral_api_key)
        logger.info("Mistral AI configuré avec succès")
        
except ImportError:
    MISTRAL_AVAILABLE = False
    logger.error("ERREUR: Le package mistralai n'est pas installé. Installez-le avec: pip install mistralai")

# Désactivation complète de Gemini
GEMINI_AVAILABLE = False
gemini_model = None
try:
    import google.generativeai as genai
    from google.api_core.exceptions import NotFound
    
    # Désactiver le chargement automatique des modèles
    genai.configure(transport='rest')
    
    # Récupérer la clé API
    gemini_api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    
    if not gemini_api_key:
        logger.warning("Aucune clé API Gemini trouvée. Définissez GEMINI_API_KEY ou GOOGLE_API_KEY")
    else:
        genai.configure(api_key=gemini_api_key)
        
        # Vérifier les modèles disponibles
        try:
            models = genai.list_models()
            available_models = [m.name for m in models]
            logger.info(f"Tous les modèles disponibles: {', '.join(available_models)}")
            
            # Essayer d'utiliser les modèles par ordre de préférence (gemini-pro est obsolète)
            for model_name in ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-1.0-pro']:
                # Vérifier que le modèle est vraiment disponible (enlever le préfixe models/ si présent)
                model_check = model_name.replace('models/', '')
                if any(model_check in m or m.endswith(model_check) for m in available_models):
                    try:
                        gemini_model = genai.GenerativeModel(model_name)
                        GEMINI_AVAILABLE = True
                        logger.info(f"Modèle {model_name} chargé avec succès")
                        break
                    except Exception as e:
                        logger.warning(f"Impossible de charger le modèle {model_name}: {str(e)}")
                        continue
            
            if not GEMINI_AVAILABLE:
                logger.warning("Aucun modèle Gemini compatible trouvé")
                
        except Exception as e:
            logger.error(f"Erreur lors de la vérification des modèles: {str(e)}")
    
except ImportError:
    logger.warning("Le package google-generativeai n'est pas installé. Installez-le avec: pip install google-generativeai")
except Exception as e:
    logger.error(f"Erreur d'initialisation Gemini: {str(e)}", exc_info=True)

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
try:
    sys.path.insert(0, str(Path(__file__).parent / "backend"))
    from advanced_ml_predictor import AdvancedMLPredictor
    from spike_predictor import AdvancedSpikePredictor
    from backend.mt5_connector import get_ohlc as get_historical_data
    # Import du détecteur de spikes amélioré
    try:
        from backend.spike_detector import predict_spike_ml, detect_spikes, get_realtime_spike_analysis
        SPIKE_DETECTOR_AVAILABLE = True
        logger.info("Module spike_detector disponible")
    except ImportError:
        SPIKE_DETECTOR_AVAILABLE = False
        logger.warning("Module spike_detector non disponible")
    BACKEND_AVAILABLE = True
    logger.info("Modules backend disponibles")
except ImportError as e:
    BACKEND_AVAILABLE = False
    SPIKE_DETECTOR_AVAILABLE = False
    logger.warning(f"Modules backend non disponibles: {e}")

# Import du détecteur avancé depuis ai_server_improvements
try:
    from ai_server_improvements import AdvancedSpikeDetector
    ADVANCED_SPIKE_DETECTOR_AVAILABLE = True
    advanced_spike_detector = AdvancedSpikeDetector()
    logger.info("AdvancedSpikeDetector initialisé")
except ImportError as e:
    ADVANCED_SPIKE_DETECTOR_AVAILABLE = False
    advanced_spike_detector = None
    logger.warning(f"AdvancedSpikeDetector non disponible: {e}")

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

# Middleware pour logger toutes les requêtes entrantes
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log toutes les requêtes entrantes pour debugging"""
    start_time = time.time()
    
    # Logger seulement le path et la méthode (pas le body pour éviter spam)
    logger.debug(f"📥 {request.method} {request.url.path}")
    
    response = await call_next(request)
    
    process_time = time.time() - start_time
    # Logger seulement si le temps de traitement est anormalement long (>1s) ou erreur
    if process_time > 1.0 or response.status_code >= 400:
        logger.warning(f"⚠️ {request.method} {request.url.path} - {response.status_code} - Temps: {process_time:.3f}s")
    else:
        logger.debug(f"📤 {request.method} {request.url.path} - {response.status_code} - {process_time:.3f}s")
    
    return response

# Parser les arguments en ligne de commande
parser = argparse.ArgumentParser(description='Serveur AI TradBOT')
parser.add_argument('--port', type=int, default=8000, help='Port sur lequel démarrer le serveur')
parser.add_argument('--host', type=str, default='127.0.0.1', help='Adresse IP sur laquelle écouter')
args = parser.parse_args()

# Variables globales
API_PORT = int(os.getenv('API_PORT', args.port))
HOST = os.getenv('HOST', args.host)
CACHE_DURATION = 30  # secondes
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
    image_filename: Optional[str] = None # Filename of the chart screenshot in MT5 Files
    deriv_patterns: Optional[str] = None  # Résumé des patterns Deriv détectés
    deriv_patterns_bullish: Optional[int] = None  # Nombre de patterns bullish
    deriv_patterns_bearish: Optional[int] = None  # Nombre de patterns bearish
    deriv_patterns_confidence: Optional[float] = None  # Confiance moyenne des patterns

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


def analyze_with_gemma(prompt: str, max_tokens: int = 200, temperature: float = 0.7, 
                      top_p: float = 0.9) -> Optional[str]:
    """
    Analyse avec le modèle Gemma (version texte uniquement)
    
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
        ).to("cuda" if torch.cuda.is_available() else "cpu")
        
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
            with torch.no_grad():
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
                torch.cuda.empty_cache()
            raise
            
    except Exception as e:
        logger.error(f"\n❌ ERREUR LORS DE L'ANALYSE GEMMA")
        logger.error("="*60)
        logger.error(f"Type: {type(e).__name__}")
        logger.error(f"Message: {str(e)}")
        if hasattr(e, 'args') and e.args:
            logger.error(f"Détails: {e.args[0]}")
        logger.error("\nStack trace:")
        logger.error(traceback.format_exc())
        return None
    
    finally:
        # Nettoyage de la mémoire GPU
        if torch.cuda.is_available():
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
                    {"role": "system", "content": "Tu es un expert en trading de volatilité spécialisé dans la détection de spikes. Analyse les indicateurs techniques avec une précision extrême. Donne des prédictions fiables basées sur les patterns de volatilité, RSI, EMA et ATR."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,  # Température plus basse pour plus de cohérence
                max_tokens=800   # Limiter les tokens pour des réponses plus ciblées
            )
        else:
            # Utilisation standard pour les autres analyses
            logger.info("Utilisation de Mistral AI pour l'analyse standard")
            response = mistral_client.chat.complete(
                model="mistral-tiny",
                messages=[{"role": "user", "content": prompt}],
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
            "/analyze/gemini (POST)"
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

# ==================== END DERIV PATTERNS ====================

# ==================== END DERIV API ====================

@app.get("/health")
async def health_check():
    """Vérification de l'état du serveur"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "cache_size": len(prediction_cache),
        "mt5_initialized": mt5_initialized,
        "mistral_available": MISTRAL_AVAILABLE,
        "trend_analysis": {
            "available": True,
            "mt5_available": mt5_initialized
        }
    }

# ==============================================================================
# ENDPOINTS D'ANALYSE DE TENDANCE (intégrés depuis trend_api.py)
# ==============================================================================

class TrendAnalysisRequest(BaseModel):
    symbol: str
    timeframes: Optional[List[str]] = ["M1", "M5", "M15", "H1", "H4"]

def calculate_trend_direction(symbol: str, timeframe: str = "M1") -> str:
    """Calcule la direction de la tendance pour un symbole/timeframe donné"""
    try:
        if not mt5_initialized:
            # Fallback basé sur l'heure si MT5 non disponible
            hour = datetime.now().hour
            if hour % 2 == 0:
                return "buy"
            else:
                return "sell"
        
        # Récupérer les données MT5
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
            return "neutral"
        
        df = pd.DataFrame(rates)
        
        # Calcul des moyennes mobiles
        sma_20 = df['close'].rolling(window=20).mean().iloc[-1]
        sma_50 = df['close'].rolling(window=50).mean().iloc[-1]
        current_price = df['close'].iloc[-1]
        
        # Détermination de la tendance
        if current_price > sma_20 > sma_50:
            return "buy"
        elif current_price < sma_20 < sma_50:
            return "sell"
        else:
            return "neutral"
            
    except Exception as e:
        logger.error(f"Erreur calcul tendance {symbol} {timeframe}: {e}")
        return "neutral"

def calculate_trend_confidence(symbol: str, timeframe: str = "M1") -> float:
    """Calcule le niveau de confiance de la tendance (0-100)"""
    try:
        if not mt5_initialized:
            # Fallback aléatoire si MT5 non disponible
            import random
            return random.randint(60, 90)
        
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
        
        df = pd.DataFrame(rates)
        
        # Calcul du RSI pour la confiance
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        current_rsi = rsi.iloc[-1]
        
        # Confiance basée sur la cohérence RSI-prix
        sma_20 = df['close'].rolling(window=20).mean().iloc[-1]
        current_price = df['close'].iloc[-1]
        
        if current_price > sma_20 and current_rsi > 50:
            return min(90, 60 + (current_rsi - 50))
        elif current_price < sma_20 and current_rsi < 50:
            return min(90, 60 + (50 - current_rsi))
        else:
            return max(40, 70 - abs(current_rsi - 50))
            
    except Exception as e:
        logger.error(f"Erreur calcul confiance {symbol} {timeframe}: {e}")
        return 50.0

@app.post("/trend")
async def get_trend_analysis(request: TrendAnalysisRequest):
    """Endpoint principal pour l'analyse de tendance (compatible avec MT5)"""
    try:
        logger.info(f"Analyse de tendance demandée pour {request.symbol}")
        
        response = {
            "symbol": request.symbol,
            "timestamp": time.time()
        }
        
        # Analyser chaque timeframe demandé
        for tf in request.timeframes:
            direction = calculate_trend_direction(request.symbol, tf)
            confidence = calculate_trend_confidence(request.symbol, tf)
            
            response[tf] = {
                "direction": direction,
                "confidence": confidence
            }
        
        logger.info(f"Tendance {request.symbol}: {response.get('M1', {}).get('direction', 'unknown')} (conf: {response.get('M1', {}).get('confidence', 0):.1f}%)")
        return response
        
    except Exception as e:
        logger.error(f"Erreur analyse tendance: {e}")
        return {
            "error": f"Erreur lors de l'analyse de tendance: {str(e)}",
            "symbol": request.symbol,
            "timestamp": time.time()
        }

@app.get("/trend")
async def get_trend_get(symbol: str = "EURUSD", timeframes: str = "M1,M5,M15,H1,H4"):
    """Version GET de l'analyse de tendance"""
    tf_list = [tf.strip() for tf in timeframes.split(",")]
    request = TrendAnalysisRequest(symbol=symbol, timeframes=tf_list)
    return await get_trend_analysis(request)

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

        # Poids par signal (pondération explicite)
        WEIGHTS = {
            "h1": 0.25,
            "m1": 0.18,
            "rsi": 0.12,
            "vwap": 0.08,
            "supertrend": 0.08,
            "patterns": 0.12,
            "sentiment": 0.07,
        }
        ALIGN_BONUS = 0.10     # Alignement multi‑TF
        DIVERGENCE_MALUS = -0.10
        VOL_LOW_MALUS = -0.15
        VOL_OK_BONUS = 0.03
        BASE_CONF = 0.40
        MAX_CONF = 0.95
        MIN_CONF = 0.20
        HOLD_THRESHOLD = 0.05  # Score trop faible => hold

        # Score directionnel pondéré
        score = 0.0
        components = []

        if h1_bullish:
            score += WEIGHTS["h1"]; components.append("H1:+")
        if h1_bearish:
            score -= WEIGHTS["h1"]; components.append("H1:-")

        if m1_bullish:
            score += WEIGHTS["m1"]; components.append("M1:+")
        if m1_bearish:
            score -= WEIGHTS["m1"]; components.append("M1:-")

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

        # Alignement / divergence multi‑timeframe
        if (h1_bullish and m1_bullish) or (h1_bearish and m1_bearish):
            score += ALIGN_BONUS; components.append("Align:+")
        if (h1_bullish and m1_bearish) or (h1_bearish and m1_bullish):
            score += DIVERGENCE_MALUS; components.append("Div:-")

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
        if direction_score > HOLD_THRESHOLD:
            action = "buy"
        elif direction_score < -HOLD_THRESHOLD:
            action = "sell"

        confidence = BASE_CONF + abs(direction_score)
        confidence = max(MIN_CONF, min(MAX_CONF, confidence))

        # Raison initiale structurée
        reason_parts = [f"Score={direction_score:+.2f}", f"Comp={','.join(components)}"]
        
        # Recalibrer direction/action après ajustements (score peut évoluer)
        direction_score = score
        if direction_score > HOLD_THRESHOLD:
            action = "buy"
        elif direction_score < -HOLD_THRESHOLD:
            action = "sell"
        else:
            action = "hold"

        confidence = BASE_CONF + abs(direction_score)
        confidence = max(MIN_CONF, min(MAX_CONF, confidence))

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

        # Si pas de raison construite, utiliser les composants de score
        if reason_parts:
            reason_from_parts = " | ".join(reason_parts)
            if reason:
                reason = f"{reason_from_parts} | {reason}"
            else:
                reason = reason_from_parts

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
                
                # 3. DÉTECTION TRADITIONNELLE RENFORCÉE
                volatility = request.atr / mid_price if mid_price > 0 else 0
                strong_vol = volatility >= 0.003
                medium_vol = volatility >= 0.0015
                extreme_oversold = rsi <= 20
                extreme_overbought = rsi >= 80
                moderate_oversold = rsi <= 35
                moderate_overbought = rsi >= 65
                
                # Score de détection traditionnelle (0-1)
                traditional_score = 0.0
                traditional_direction = None
                
                # Conditions haussières
                bull_conditions = 0
                if strong_vol: bull_conditions += 1
                if extreme_oversold: bull_conditions += 1
                if h1_bullish and m1_bullish: bull_conditions += 1
                if request.dir_rule >= 1: bull_conditions += 1
                if vwap_signal_buy or supertrend_bullish: bull_conditions += 1
                
                # Conditions baissières
                bear_conditions = 0
                if strong_vol: bear_conditions += 1
                if extreme_overbought: bear_conditions += 1
                if h1_bearish and m1_bearish: bear_conditions += 1
                if request.dir_rule <= -1: bear_conditions += 1
                if vwap_signal_sell or supertrend_bearish: bear_conditions += 1
                
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
            extreme_oversold = rsi <= 20
            extreme_overbought = rsi >= 80
            moderate_oversold = rsi <= 35
            moderate_overbought = rsi >= 65
            
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
            extreme_oversold = rsi <= 20      # Augmenté de 25 à 20
            extreme_overbought = rsi >= 80     # Augmenté de 75 à 80
            moderate_oversold = rsi <= 35      # Nouveau seuil modéré
            moderate_overbought = rsi >= 65    # Nouveau seuil modéré

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
        
        # Mise en cache
        prediction_cache[cache_key] = response_data
        last_updated[cache_key] = current_time
        
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
        logger.error(f"Erreur lors de la génération des signaux pour {symbol}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de l'analyse: {str(e)}")

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

    def capture_chart(self, symbol: str, timeframe: str, width: int = 800, height: int = 600) -> Tuple[Optional[Image.Image], Optional[str]]:
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
            image = Image.open(filepath)
            return image, filename
        except Exception as exc:
            logger.error("Erreur capture_chart: %s", exc, exc_info=True)
            return None, None

    def analyze_chart(self, symbol: str, timeframe: str, image: Optional[Image.Image] = None, prompt: Optional[str] = None) -> Optional[str]:
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
                if action and confidence >= 0.60:  # Seuil minimum de confiance
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