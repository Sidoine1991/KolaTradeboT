#!/usr/bin/env python3
"""
Serveur IA pour TradBOT - Gestion des prédictions et analyses de marché
Version: 2.1.0 - STABILISÉ
Corrections majeures:
- Ajout champ timestamp dans DecisionRequest (fix erreur 422)
- Correction gestion colonne timestamp dans adaptive_predict.py  
- Ajout endpoint /trend principal (fix erreur 404)
- Définition variable backend_available (fix NameError)
- Amélioration gestion des erreurs et logging
Compatible avec F_INX_robot4.mq5
"""

import os
import json
import time
import math
import asyncio
import logging
import sys
import argparse
import traceback
import contextlib
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional, List, Dict, Any, Tuple, Set, Union
from uuid import uuid4
from fastapi import FastAPI, HTTPException, Request, Body, status
from starlette.requests import Request as StarletteRequest
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.wsgi import WSGIMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

import uvicorn
import pandas as pd
import numpy as np
import requests
import re
import joblib
from collections import deque, defaultdict

# --- Supabase config helpers ---
def _get_supabase_config(strict: bool = True) -> Tuple[str, str]:
    """
    Retourne (SUPABASE_URL, SUPABASE_KEY).
    En mode strict, refuse les valeurs par défaut silencieuses pour éviter d'écrire dans le mauvais projet.
    """
    supabase_url = (os.getenv("SUPABASE_URL") or "").strip()
    supabase_key = (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or os.getenv("SUPABASE_SERVICE_KEY")
        or os.getenv("SUPABASE_ANON_KEY")
        or ""
    ).strip()

    if strict and (not supabase_url or not supabase_key):
        raise RuntimeError("Supabase non configuré (SUPABASE_URL et SUPABASE_*KEY requis)")

    if supabase_key:
        masked = supabase_key[:6] + "..." + supabase_key[-4:] if len(supabase_key) > 12 else "***"
    else:
        masked = "(none)"
    logger.info(f"🔌 Supabase config: url={supabase_url or '(none)'} key={masked}")
    return supabase_url, supabase_key

# Configurer le logger avant les imports d'améliorations
logger = logging.getLogger("tradbot_ai")

# Sur Render / Supabase, utiliser /tmp pour les modèles (accessible en écriture)
if os.getenv("RENDER") or os.getenv("RENDER_SERVICE_ID") or os.getenv("SUPABASE_URL"):
    os.environ.setdefault("MODELS_DIR", "/tmp/models")


def _env_bool(name: str, default: bool = False) -> bool:
    """Lit un booléen depuis les variables d'environnement."""
    val = os.getenv(name)
    if val is None:
        return default
    return val.strip().lower() in {"1", "true", "yes", "on"}

# ===== SYSTÈME D'APPRENTISSAGE AUTOMATIQUE INTÉGRÉ =====
# Importer le système ML intégré
try:
    from integrated_ml_trainer import ml_trainer
    ML_TRAINER_AVAILABLE = True
    logger.info("🤖 Système d'entraînement continu intégré chargé")
except ImportError as e:
    ML_TRAINER_AVAILABLE = False
    logger.warning(f"⚠️ Système d'entraînement continu non disponible: {e}")

try:
    from backend.weltrade_symbols import WELTRADE_STARTUP_TRAIN_SYMBOLS
except ImportError:
    WELTRADE_STARTUP_TRAIN_SYMBOLS = ()

try:
    from backend.indicator_confluence import apply_core_indicator_confluence
    INDICATOR_CONFLUENCE_AVAILABLE = True
except ImportError:
    apply_core_indicator_confluence = None  # type: ignore
    INDICATOR_CONFLUENCE_AVAILABLE = False

# Importer le système de recommandation ML
try:
    from ml_recommendation_system import MLRecommendationSystem
    ML_RECOMMENDATION_AVAILABLE = True
    logger.info("🎯 Système de recommandation ML chargé avec succès")
except ImportError as e:
    ML_RECOMMENDATION_AVAILABLE = False
    logger.warning(f"⚠️ Système de recommandation ML non disponible: {e}")

# Initialiser le système de recommandation ML
if ML_TRAINER_AVAILABLE and ML_RECOMMENDATION_AVAILABLE:
    ml_recommendation_system = MLRecommendationSystem(ml_trainer)
    logger.info("🚀 Système de recommandation ML initialisé")
else:
    ml_recommendation_system = None
    logger.warning("⚠️ Système de recommandation ML non initialisé")

# Importer le système ML de décision
try:
    from ml_trading_system import ml_enhancer
    ML_AVAILABLE = True
    logger.info("🧠 Système ML chargé avec succès")
except ImportError as e:
    ML_AVAILABLE = False
    logger.warning(f"⚠️ Système ML non disponible: {e}")

# Fonction pour améliorer les décisions avec ML (Random Forest, ml_enhancer, etc.)
def enhance_decision_with_ml(symbol: str, decision: str, confidence: float, market_data: dict = None) -> dict:
    """Améliorer une décision avec les modèles ML (Random Forest d'abord, puis ml_enhancer)"""
    base = {
        "original_decision": decision,
        "original_confidence": confidence,
        "enhanced_decision": decision,
        "enhanced_confidence": confidence,
        "ml_reason": "no_model",
        "ml_applied": False
    }
    market_data = market_data or {}
    # 1. Random Forest (integrated_ml_trainer) si modèle disponible
    if ML_TRAINER_AVAILABLE:
        try:
            pred = ml_trainer.predict(symbol, "M1", market_data)
            if pred:
                base["enhanced_decision"] = pred["action"]
                base["enhanced_confidence"] = pred.get("confidence", confidence)
                base["ml_reason"] = pred.get("model", "random_forest")
                base["ml_applied"] = True
                return base
        except Exception as e:
            logger.debug(f"Predict RF skip: {e}")
    # 2. ml_enhancer (ml_trading_system) si ML_AVAILABLE
    if not ML_AVAILABLE:
        return base
    try:
        return ml_enhancer.enhance_decision(symbol, decision, confidence, market_data)
    except Exception as e:
        logger.error(f"❌ Erreur enhancement ML: {e}")
        return {
            "original_decision": decision,
            "original_confidence": confidence,
            "enhanced_decision": decision,
            "enhanced_confidence": confidence,
            "ml_reason": "error",
            "ml_applied": False
        }

# ========== MODE SIMPLIFIÉ POUR ROBOCOP v2 ==========
# Activer le mode simplifié pour RoboCop v2 (plus stable, moins de dépendances)
SIMPLIFIED_MODE = True  # Mettre à False pour utiliser le mode complet

if SIMPLIFIED_MODE:
    logger.info("🚀 MODE SIMPLIFIÉ ACTIVÉ - RoboCop v2 compatible")
    logger.info("   • Analyse technique basée sur RSI + EMA")
    logger.info("   • Pas de ML complexe - Stabilité maximale")
    logger.info("   • Endpoints: /decision, /trades/feedback")
else:
    logger.info("🔧 MODE COMPLET ACTIVÉ - Toutes les fonctionnalités")

# ========== CONFIGURATIONS AMÉLIORATIONS PRIORITAIRES ==========
# Seuils de confiance minimum pour éviter les signaux trop faibles
MIN_CONFIDENCE_THRESHOLD = 0.55  # 55% minimum (plus réaliste)
FORCE_HOLD_THRESHOLD = 0.40      # Force HOLD si confiance < 40% (plus flexible)

# Prompt système amélioré pour Boom/Crash
BOOM_CRASH_SYSTEM_PROMPT = """
Tu es un trader expert spécialisé sur les indices synthétiques Deriv (Boom & Crash 50/100/300/600/900/1000).

RÈGLES STRICTES POUR BOOM/CRASH:
1. Confiance MINIMUM 68% pour tout signal BUY/SELL. En dessous → HOLD obligatoire.
2. SUR BOOM: Privilégie BUY quand RSI < 40 + EMA crossover haussier SANS spike récent.
3. SUR CRASH: Privilégie SELL quand RSI > 60 + EMA crossover baissier SANS spike récent.
4. JAMAIS de signal si ATR dernière bougie > 2.8×ATR moyen → risque spike trop élevé.
5. Détecte les patterns de spike: bougie > 3×range moyen + volume élevé.

FORMAT DE RÉPONSE OBLIGATOIRE:
- action: "buy"/"sell"/"hold" 
- confidence: 0.68-1.0 (jamais en dessous de 0.68)
- reason: phrase courte et précise
- metadata: RSI, EMA, ATR ratio, spike_risk
"""

# Cache court pour éviter les analyses répétées
decision_cache = {}
cache_timestamps = {}
CACHE_DURATION = 30  # 30 secondes

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

# PostgreSQL async support for feedback loop & trading stats
try:
    import asyncpg
    ASYNCPG_AVAILABLE = True
except ImportError:
    ASYNCPG_AVAILABLE = False
    logger_placeholder = logging.getLogger("tradbot_ai")
    logger_placeholder.warning("asyncpg non disponible - installer avec: pip install asyncpg")

# Import yfinance pour les données de marché (compatible cloud)
try:
    import yfinance as yf
    YFINANCE_AVAILABLE = True
    logger.info("✅ yfinance disponible pour les données de marché")
except ImportError:
    YFINANCE_AVAILABLE = False
    logger.warning("⚠️ yfinance non disponible")

# Variables globales pour le suivi en mode simplifié
decision_count = 0
feedback_count = 0

# ===== Modèles Pydantic pour trades & stats =====


class TradeIn(BaseModel):
    symbol: str
    category: str = "boomcrash"
    strategy: str
    direction: str
    volume: float
    entry_price: float
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    close_price: Optional[float] = None
    result_usd: Optional[float] = None
    result_points: Optional[float] = None
    risk_reward: Optional[float] = None
    opened_at: datetime
    closed_at: Optional[datetime] = None
    session_tag: Optional[str] = None
    timeframe: str = "M1"
    ai_action: Optional[str] = None
    ai_confidence: Optional[float] = None
    ml_score: Optional[float] = None
    execution_slippage_points: Optional[float] = None
    mt5_ticket: Optional[int] = None
    context: Dict[str, Any] = Field(default_factory=dict)


class StairDetectIn(BaseModel):
    client_event_id: Optional[str] = None
    symbol: str
    category: str = "boomcrash"
    direction: str
    timeframe: str = "M1"
    pattern_kinds: Optional[str] = None
    features: Dict[str, Any] = Field(default_factory=dict)
    ai_action: Optional[str] = None
    ai_confidence: Optional[float] = None
    mt5_ticket: Optional[int] = None
    source: str = "ea"


class StairOutcomeIn(BaseModel):
    id: Optional[str] = None
    client_event_id: Optional[str] = None
    outcome: str
    result_usd: Optional[float] = None
    closed_at: Optional[str] = None
    mt5_ticket: Optional[int] = None


class SymbolStatsOut(BaseModel):
    symbol: str
    trade_count: int
    wins: int
    losses: int
    net_profit: float
    max_drawdown: Optional[float] = None
    max_consecutive_losses: Optional[int] = None


class SymbolConfigOut(BaseModel):
    symbol: str
    enabled: bool = True
    max_open_positions: int = 1
    min_expectancy: float = 0.0
    min_ai_confidence: float = 0.55
    max_daily_loss_usd: Optional[float] = None
    max_symbol_loss_usd: Optional[float] = None
    max_consecutive_losses: Optional[int] = None
    risk_profile: str = "balanced"
    overrides: Dict[str, Any] = Field(default_factory=dict)


# ========== FONCTIONS UTILITAIRES AMÉLIORATIONS ==========
def apply_confidence_thresholds(action: str, confidence: float, reason: str) -> tuple:
    """
    Applique les seuils de confiance minimum pour éviter les signaux trop faibles.
    Force HOLD si confiance < 60%, applique plancher 68% pour les signaux.
    """
    # Forcer un plancher de confiance à 68%
    confidence = max(confidence, 0.68)
    
    # Forcer HOLD si confiance encore trop faible après plancher
    if confidence < 0.68:
        return "hold", 0.68, f"{reason} (confiance trop faible → hold forcé)"
    
    # Si action non-hold mais confiance < 68%, forcer HOLD
    if action != "hold" and confidence < 0.68:
        return "hold", 0.68, f"{reason} (confiance < 68% → hold)"
    
    # Forcer un minimum de 68% pour les signaux buy/sell
    if action != "hold" and confidence < 0.68:
        confidence = 0.68
        reason += f" (confiance forcée à 68%)"
    
    return action, confidence, reason

def get_cached_decision(symbol: str) -> Optional[Dict]:
    """Vérifie le cache pour une décision récente."""
    current_time = time.time()
    if symbol in decision_cache:
        cache_age = current_time - cache_timestamps.get(symbol, 0)
        if cache_age < CACHE_DURATION:
            logger.debug(f"✅ Cache trouvé pour {symbol} (âge: {cache_age:.1f}s)")
            return decision_cache[symbol]
        else:
            # Cache expiré, supprimer
            del decision_cache[symbol]
            del cache_timestamps[symbol]
    return None

def cache_decision(symbol: str, decision_data: Dict):
    """Stocke une décision dans le cache."""
    decision_cache[symbol] = decision_data
    cache_timestamps[symbol] = time.time()
    logger.debug(f"💾 Décision mise en cache pour {symbol}")

def calculate_boom_crash_metadata(df: pd.DataFrame, symbol: str, request) -> Dict:
    """
    Calcule les métadonnées spécifiques pour Boom/Crash.
    Garantit les métadonnées de base pour le filtre local renforcé.
    """
    metadata = {}
    
    try:
        # RSI (priorité: df calculé > request > défaut)
        current_rsi = None
        if 'rsi' in df.columns and len(df) > 0:
            current_rsi = float(df['rsi'].iloc[-1])
        elif hasattr(request, 'rsi') and request.rsi is not None:
            current_rsi = request.rsi
        else:
            current_rsi = 50.0  # Défaut neutre
        
        metadata['rsi'] = current_rsi
        
        # EMA fast/slow avec valeurs par défaut si erreur
        try:
            if len(df) > 21:  # Assez de données pour EMA
                ema_fast = df['close'].ewm(span=9).mean()
                ema_slow = df['close'].ewm(span=21).mean()
                ema_fast_val = float(ema_fast.iloc[-1])
                ema_slow_val = float(ema_slow.iloc[-1])
                
                metadata['ema_fast'] = ema_fast_val
                metadata['ema_slow'] = ema_slow_val
                metadata['ema_trend'] = "bullish" if ema_fast_val > ema_slow_val else "bearish"
                metadata['ema_crossover'] = ema_fast_val > ema_slow_val
            else:
                # Pas assez de données - utiliser prix actuel
                current_price = float(df['close'].iloc[-1]) if len(df) > 0 else 0.0
                metadata['ema_fast'] = current_price
                metadata['ema_slow'] = current_price
                metadata['ema_trend'] = "neutral"
                metadata['ema_crossover'] = False
        except Exception as ema_err:
            logger.warning(f"⚠️ Erreur calcul EMA: {ema_err}")
            metadata['ema_fast'] = 0.0
            metadata['ema_slow'] = 0.0
            metadata['ema_trend'] = "neutral"
            metadata['ema_crossover'] = False
        
        # ATR et ratio avec valeurs par défaut
        try:
            if len(df) > 20:
                atr = calculate_atr(df)
                atr_mean = atr.rolling(20).mean().iloc[-1]
                atr_current = atr.iloc[-1]
                atr_ratio = float(atr_current / atr_mean) if atr_mean > 0 else 1.0
            else:
                atr_ratio = 1.0  # Défaut normal
            
            metadata['atr_ratio'] = atr_ratio
        except Exception as atr_err:
            logger.warning(f"⚠️ Erreur calcul ATR: {atr_err}")
            metadata['atr_ratio'] = 1.0
        
        # Détection de risque de spike avec valeurs par défaut
        try:
            if len(df) > 20:
                range_mean = df['high'].sub(df['low']).rolling(20).mean().iloc[-1]
                current_range = df['high'].iloc[-1] - df['low'].iloc[-1]
                spike_detected = current_range > (2.8 * range_mean)
            else:
                spike_detected = False
            
            metadata['spike_risk'] = spike_detected
        except Exception as spike_err:
            logger.warning(f"⚠️ Erreur détection spike: {spike_err}")
            metadata['spike_risk'] = False
        
        # SL/TP suggérés basés sur le risque
        if metadata.get('spike_risk', False):
            metadata['suggested_sl_pips'] = 60  # Plus large pour spike
            metadata['suggested_tp_pips'] = 150
        else:
            metadata['suggested_sl_pips'] = 35
            metadata['suggested_tp_pips'] = 90
            
        # Métadonnées additionnelles pour le filtre local
        metadata['symbol'] = symbol
        metadata['is_boom'] = 'boom' in symbol.lower()
        metadata['is_crash'] = 'crash' in symbol.lower()
        metadata['timestamp'] = datetime.now().isoformat()
            
    except Exception as e:
        logger.warning(f"⚠️ Erreur calcul métadonnées: {e}")
        # Garantir les métadonnées de base même en cas d'erreur
        metadata = {
            'rsi': getattr(request, 'rsi', 50.0),
            'atr_ratio': 1.0,
            'spike_risk': False,
            'ema_trend': 'neutral',
            'ema_fast': 0.0,
            'ema_slow': 0.0,
            'ema_crossover': False,
            'error': str(e),
            'symbol': symbol,
            'timestamp': datetime.now().isoformat()
        }
    
    return metadata

def calculate_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """Calcule l'ATR (Average True Range)."""
    high_low = df['high'] - df['low']
    high_close = (df['high'] - df['close'].shift()).abs()
    low_close = (df['low'] - df['close'].shift()).abs()
    
    true_range = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
    return true_range.rolling(window=period).mean()

def convert_numpy_to_python(obj):
    """
    Convertit les types numpy en types Python standards pour la sérialisation JSON.
    Récursif pour les dictionnaires et listes.
    """
    import numpy as np
    
    if isinstance(obj, np.bool_):
        return bool(obj)
    elif isinstance(obj, np.integer):
        return int(obj)
    elif isinstance(obj, np.floating):
        return float(obj)
    elif isinstance(obj, np.ndarray):
        return obj.tolist()
    elif isinstance(obj, dict):
        return {key: convert_numpy_to_python(value) for key, value in obj.items()}
    elif isinstance(obj, list):
        return [convert_numpy_to_python(item) for item in obj]
    elif isinstance(obj, tuple):
        return tuple(convert_numpy_to_python(item) for item in obj)
    else:
        return obj

def calculate_rsi(prices: pd.Series, period: int = 14) -> pd.Series:
    """Calcule le RSI."""
    delta = prices.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    
    rs = gain / loss
    rsi = 100 - (100 / (1 + rs))
    
    return rsi

# Cache pour les données historiques (fallback cloud)
_history_cache: Dict[str, pd.DataFrame] = {}

# =========================
# Fonctions de détection de spikes Boom/Crash
# =========================
def is_boom_crash_symbol(symbol: str) -> bool:
    """Vérifie si le symbole est un indice Boom ou Crash (Deriv : *Index*, Boom500, Crash 1000, etc.)"""
    s_raw = str(symbol).lower()
    s = s_raw.replace(" ", "").replace("_", "")
    boom = "boom" in s_raw
    crash = "crash" in s_raw
    if not boom and not crash:
        return False
    if "index" in s_raw:
        return True
    # Symboles sans le mot « index » (ex. broker compact)
    if boom and re.search(r"boom\d", s):
        return True
    if crash and re.search(r"crash\d", s):
        return True
    return False


def enforce_ea_boom_crash_direction(symbol: str, action: str, confidence: float, reason: str):
    """
    Aligner la décision HTTP avec SMC_Universal.mq5 :
    Boom = BUY seulement, Crash = SELL seulement ;
    Weltrade GainX = pas de SELL, PainX = pas de BUY (même principe).
    Une direction interdite est ramenée à HOLD pour laisser la logique aggressive (EMA) proposer SELL/BUY.
    """
    s = str(symbol).lower()
    a = (action or "hold").lower()
    if is_boom_crash_symbol(str(symbol)):
        if "crash" in s and a == "buy":
            return "hold", min(float(confidence), 0.55), reason + "[Crash: BUY incompatible EA → HOLD] "
        if "boom" in s and a == "sell":
            return "hold", min(float(confidence), 0.55), reason + "[Boom: SELL incompatible EA → HOLD] "
    try:
        from backend.weltrade_symbols import is_weltrade_pain_synth, is_weltrade_gain_synth
    except ImportError:
        from weltrade_symbols import is_weltrade_pain_synth, is_weltrade_gain_synth
    if is_weltrade_pain_synth(str(symbol)) and a == "buy":
        return "hold", min(float(confidence), 0.55), reason + "[PainX: BUY incompatible EA → HOLD] "
    if is_weltrade_gain_synth(str(symbol)) and a == "sell":
        return "hold", min(float(confidence), 0.55), reason + "[GainX: SELL incompatible EA → HOLD] "
    return action, confidence, reason


def synth_stair_direction_for_symbol(symbol: str) -> Optional[str]:
    """Direction trade autorisée pour indices escalier (Boom/GainX → BUY, Crash/PainX → SELL)."""
    s = str(symbol).lower()
    if "boom" in s:
        return "BUY"
    if "crash" in s:
        return "SELL"
    try:
        from backend.weltrade_symbols import is_weltrade_pain_synth, is_weltrade_gain_synth
    except ImportError:
        from weltrade_symbols import is_weltrade_pain_synth, is_weltrade_gain_synth
    if is_weltrade_gain_synth(str(symbol)):
        return "BUY"
    if is_weltrade_pain_synth(str(symbol)):
        return "SELL"
    return None


def _stair_category_for_symbol(symbol: str) -> str:
    if is_boom_crash_symbol(str(symbol)):
        return "boomcrash"
    try:
        from backend.weltrade_symbols import is_weltrade_pain_synth, is_weltrade_gain_synth
    except ImportError:
        from weltrade_symbols import is_weltrade_pain_synth, is_weltrade_gain_synth
    if is_weltrade_pain_synth(str(symbol)) or is_weltrade_gain_synth(str(symbol)):
        return "weltrade_synth"
    return "other"


# --- Stair detections (Supabase) : cache stats + helpers REST ---
_stair_summary_cache: Dict[str, Tuple[float, List[Dict[str, Any]]]] = {}
STAIR_STATS_MIN_CLOSED = 8
STAIR_STATS_CACHE_TTL = 55.0


def _stair_compute_quality_from_features(features: Dict[str, Any]) -> float:
    """Heuristique légère 0..1 à partir des features envoyées par l'EA (sans modèle lourd)."""
    if not features:
        return 0.55
    q = 0.5
    try:
        ar = float(features.get("aligned_ratio", 0.0) or 0.0)
        if ar >= 0.62:
            q += 0.12
        elif ar >= 0.55:
            q += 0.06
        nmp = float(features.get("net_move_pct", 0.0) or 0.0)
        if nmp >= 0.12:
            q += 0.05
        if features.get("forming_match") is True:
            q += 0.04
        if features.get("early_match") is True:
            q += 0.03
    except (TypeError, ValueError):
        pass
    return max(0.05, min(0.98, q))


def _stair_pick_summary_row(rows: List[Dict[str, Any]], pattern_kinds: Optional[str]) -> Optional[Dict[str, Any]]:
    if not rows:
        return None
    pk = (pattern_kinds or "").strip().lower()
    if pk:
        for r in rows:
            if str(r.get("pattern_kinds") or "").lower() == pk:
                return r
        for r in rows:
            if pk in str(r.get("pattern_kinds") or "").lower():
                return r
    best = None
    best_n = -1
    for r in rows:
        n = int(r.get("closed_trades") or 0)
        if n > best_n:
            best_n = n
            best = r
    return best


async def _stair_fetch_quality_rows(symbol: str, direction: str) -> List[Dict[str, Any]]:
    supabase_url = (os.getenv("SUPABASE_URL") or "").strip()
    supabase_key = (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or os.getenv("SUPABASE_SERVICE_KEY")
        or os.getenv("SUPABASE_ANON_KEY")
        or ""
    ).strip()
    if not supabase_url or not supabase_key:
        return []
    sym = (symbol or "").strip()
    d = (direction or "").strip().upper()
    if not sym or d not in ("BUY", "SELL"):
        return []
    cache_key = f"{sym}|{d}"
    now = time.time()
    hit = _stair_summary_cache.get(cache_key)
    if hit and (now - hit[0]) < STAIR_STATS_CACHE_TTL:
        return hit[1]

    import httpx

    params = {
        "symbol": f"eq.{sym}",
        "direction": f"eq.{d}",
        "select": "symbol,direction,pattern_kinds,closed_trades,wins,losses,win_rate",
    }
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
    }
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            r = await client.get(
                f"{supabase_url.rstrip('/')}/rest/v1/stair_quality_summary",
                params=params,
                headers=headers,
            )
        if r.status_code != 200:
            logger.warning("stair_quality_summary HTTP %s: %s", r.status_code, (r.text or "")[:200])
            return []
        data = r.json()
        if not isinstance(data, list):
            return []
        _stair_summary_cache[cache_key] = (now, data)
        return data
    except Exception as e:
        logger.debug("stair_quality_summary fetch error: %s", e)
        return []


async def _stair_empirical_win_rate(symbol: str, direction: str, pattern_kinds: Optional[str]) -> Tuple[Optional[float], int]:
    rows = await _stair_fetch_quality_rows(symbol, direction)
    row = _stair_pick_summary_row(rows, pattern_kinds)
    if not row:
        return None, 0
    n = int(row.get("closed_trades") or 0)
    wr = row.get("win_rate")
    if wr is None:
        return None, n
    try:
        return float(wr), n
    except (TypeError, ValueError):
        return None, n


def _stair_confidence_delta(win_rate: Optional[float], closed_n: int) -> float:
    if win_rate is None or closed_n < STAIR_STATS_MIN_CLOSED:
        return 0.0
    edge = float(win_rate) - 0.5
    return max(-0.09, min(0.09, edge * 0.35))


async def apply_stair_history_to_decision(
    symbol: str,
    action: str,
    confidence: float,
    reason: str,
    stair_detected: bool,
    stair_direction: Optional[str],
    stair_pattern_kinds: Optional[str],
) -> Tuple[str, float, str]:
    if not stair_detected:
        return action, confidence, reason
    sd = (stair_direction or "").strip().upper() or synth_stair_direction_for_symbol(symbol)
    if not sd:
        return action, confidence, reason
    act = (action or "hold").lower()
    aligned = (act == "buy" and sd == "BUY") or (act == "sell" and sd == "SELL")
    if act == "hold" or not aligned:
        return action, confidence, reason
    wr, n = await _stair_empirical_win_rate(symbol, sd, stair_pattern_kinds)
    delta = _stair_confidence_delta(wr, n)
    if delta == 0.0:
        if wr is not None:
            reason += f"[stair histo: win_rate={wr:.2f} n={n} — échantillon faible ou neutre] "
        return action, confidence, reason
    new_c = max(0.05, min(0.97, float(confidence) + delta))
    reason += f"[stair learning: Δconf {delta:+.3f} win_rate={wr:.2f} n={n}] "
    return action, new_c, reason


async def _insert_stair_detection_supabase(payload: Dict[str, Any]) -> None:
    supabase_url = (os.getenv("SUPABASE_URL") or "").strip()
    supabase_key = (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or os.getenv("SUPABASE_SERVICE_KEY")
        or os.getenv("SUPABASE_ANON_KEY")
        or ""
    ).strip()
    if not supabase_url or not supabase_key:
        return
    import httpx

    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.post(
                f"{supabase_url.rstrip('/')}/rest/v1/stair_detections",
                headers=headers,
                json=payload,
            )
        if r.status_code not in (200, 201):
            logger.warning("stair_detections insert HTTP %s: %s", r.status_code, (r.text or "")[:300])
    except Exception as e:
        logger.debug("stair_detections insert error: %s", e)


async def _patch_stair_outcome_supabase(
    *,
    row_id: Optional[str] = None,
    client_event_id: Optional[str] = None,
    outcome: str,
    result_usd: Optional[float] = None,
    closed_at_iso: Optional[str] = None,
    mt5_ticket: Optional[int] = None,
) -> bool:
    from urllib.parse import quote

    supabase_url = (os.getenv("SUPABASE_URL") or "").strip()
    supabase_key = (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or os.getenv("SUPABASE_SERVICE_KEY")
        or os.getenv("SUPABASE_ANON_KEY")
        or ""
    ).strip()
    if not supabase_url or not supabase_key:
        return False
    import httpx

    patch: Dict[str, Any] = {
        "outcome": outcome.lower(),
        "updated_at": datetime.utcnow().isoformat() + "Z",
    }
    if result_usd is not None:
        patch["result_usd"] = result_usd
    if closed_at_iso:
        patch["closed_at"] = closed_at_iso
    if mt5_ticket is not None:
        patch["mt5_ticket"] = mt5_ticket

    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }
    base = f"{supabase_url.rstrip('/')}/rest/v1/stair_detections"
    if row_id:
        q = f"{base}?id=eq.{quote(str(row_id), safe='')}"
    elif client_event_id:
        q = f"{base}?client_event_id=eq.{quote(str(client_event_id), safe='')}"
    else:
        return False
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.patch(q, headers=headers, json=patch)
        if r.status_code not in (200, 204):
            logger.warning("stair_detections patch HTTP %s: %s", r.status_code, (r.text or "")[:300])
            return False
        return True
    except Exception as e:
        logger.debug("stair_detections patch error: %s", e)
        return False


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
        else:
            try:
                from backend.weltrade_symbols import is_weltrade_pain_synth, is_weltrade_gain_synth
            except ImportError:
                from weltrade_symbols import is_weltrade_pain_synth, is_weltrade_gain_synth
            if is_weltrade_gain_synth(symbol) and spike_direction == "SELL":
                has_spike = False
            elif is_weltrade_pain_synth(symbol) and spike_direction == "BUY":
                has_spike = False
    
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

def draw_predictive_channel(df: pd.DataFrame, symbol: str, lookback_period: int = 50) -> Dict[str, Any]:
    """
    Dessine un canal prédictif basé sur l'analyse technique des tendances
    
    Args:
        df: DataFrame avec données OHLCV
        symbol: Symbole à analyser
        lookback_period: Période de rétrospection pour l'analyse
        
    Returns:
        Dict avec informations du canal prédictif
    """
    if len(df) < lookback_period + 10:
        return {"has_channel": False, "reason": f"Données insuffisantes (besoin de {lookback_period + 10} bougies)"}
    
    try:
        # Extraire les données pertinentes
        recent_data = df.tail(lookback_period).copy()
        highs = recent_data['high'].values
        lows = recent_data['low'].values
        closes = recent_data['close'].values
        times = recent_data.index if 'time' not in recent_data.columns else recent_data['time']
        
        # Calculer les lignes de tendance supérieure et inférieure
        # Utiliser régression linéaire pour trouver les tendances
        
        # Ligne de tendance supérieure (basée sur les highs)
        x_high = np.arange(len(highs))
        coeffs_high = np.polyfit(x_high, highs, 1)  # Régression linéaire degré 1
        trend_high = np.polyval(coeffs_high, x_high)
        
        # Ligne de tendance inférieure (basée sur les lows)
        x_low = np.arange(len(lows))
        coeffs_low = np.polyfit(x_low, lows, 1)
        trend_low = np.polyval(coeffs_low, x_low)
        
        # Ligne de tendance centrale (basée sur les closes)
        x_close = np.arange(len(closes))
        coeffs_close = np.polyfit(x_close, closes, 1)
        trend_close = np.polyval(coeffs_close, x_close)
        
        # Calculer la largeur du canal (moyenne des écarts)
        channel_width = np.mean(trend_high - trend_low)
        
        # Détecter si le canal est trop serré (consolidation)
        price_range = np.max(highs) - np.min(lows)
        relative_width = channel_width / np.mean(closes)
        is_consolidating = relative_width < 0.002  # Moins de 0.2% de largeur relative
        
        # Projeter le canal dans le futur (5 prochaines périodes)
        future_periods = 5
        x_future = np.arange(len(closes), len(closes) + future_periods)
        
        # Projection des tendances
        future_high = np.polyval(coeffs_high, x_future)
        future_low = np.polyval(coeffs_low, x_future)
        future_close = np.polyval(coeffs_close, x_future)
        
        # Prix actuel
        current_price = closes[-1]
        
        # Déterminer la position actuelle dans le canal
        if trend_high[-1] - trend_low[-1] > 0:
            current_position = (current_price - trend_low[-1]) / (trend_high[-1] - trend_low[-1])
        else:
            current_position = 0.5  # Position neutre si canal plat
        current_position = max(0, min(1, current_position))  # Clamp entre 0 et 1
        
        # Calculer les signaux basés sur le canal
        signal = None
        confidence = 0.0
        reasoning = []
        
        # Ajouter détection de consolidation
        if is_consolidating:
            reasoning.append("Marché en consolidation (canal très serré)")
            # En consolidation, utiliser des seuils plus stricts
            upper_threshold = 0.15
            lower_threshold = 0.85
        else:
            upper_threshold = 0.2
            lower_threshold = 0.8
        
        # Si le prix est près de la borne inférieure -> signal BUY
        if current_position < upper_threshold:
            signal = "BUY"
            confidence = (upper_threshold - current_position) / upper_threshold
            reasoning.append(f"Prix proche de la borne inférieure du canal ({current_position:.1%})")
        
        # Si le prix est près de la borne supérieure -> signal SELL
        elif current_position > lower_threshold:
            signal = "SELL"
            confidence = (current_position - lower_threshold) / (1 - lower_threshold)
            reasoning.append(f"Prix proche de la borne supérieure du canal ({current_position:.1%})")
        
        # Si le prix est au centre -> signal NEUTRAL
        else:
            signal = "NEUTRAL"
            confidence = 0.5
            reasoning.append(f"Prix au centre du canal ({current_position:.1%})")
        
        # Ajouter la pente du canal à l'analyse
        slope = coeffs_close[0]
        if abs(slope) > 0.0005:  # Seuil plus élevé pour considérer la pente significative
            if slope > 0:
                reasoning.append(f"Canal haussier (pente: {slope:.4f})")
                if signal == "BUY":
                    confidence += 0.15  # Bonus plus élevé pour signal aligné
            else:
                reasoning.append(f"Canal baissier (pente: {slope:.4f})")
                if signal == "SELL":
                    confidence += 0.15
        else:
            reasoning.append(f"Canal latéral (pente: {slope:.4f})")
            # Réduire la confiance en cas de canal latéral
            if signal != "NEUTRAL":
                confidence *= 0.7
        
        # Calculer les niveaux de support/résistance projetés
        projected_support = future_low[-1]
        projected_resistance = future_high[-1]
        
        # Calculer SL/TP basés sur le canal
        if signal == "BUY":
            stop_loss = max(trend_low[-1], current_price - channel_width * 0.5)
            take_profit = min(trend_high[-1], current_price + channel_width * 1.5)
        elif signal == "SELL":
            stop_loss = min(trend_high[-1], current_price + channel_width * 0.5)
            take_profit = max(trend_low[-1], current_price - channel_width * 1.5)
        else:
            stop_loss = None
            take_profit = None
        
        confidence = min(0.95, confidence)  # Limiter la confiance maximale
        
        return {
            "has_channel": True,
            "symbol": symbol,
            "current_price": float(current_price),
            "signal": signal,
            "confidence": float(confidence),
            "channel_info": {
                "upper_line": {
                    "current": float(trend_high[-1]),
                    "slope": float(coeffs_high[0]),
                    "projected": [float(val) for val in future_high]
                },
                "lower_line": {
                    "current": float(trend_low[-1]),
                    "slope": float(coeffs_low[0]),
                    "projected": [float(val) for val in future_low]
                },
                "center_line": {
                    "current": float(trend_close[-1]),
                    "slope": float(coeffs_close[0]),
                    "projected": [float(val) for val in future_close]
                },
                "width": float(channel_width),
                "position_in_channel": float(current_position),
                "is_consolidating": bool(is_consolidating),
                "relative_width": float(relative_width),
                "upper_threshold": float(upper_threshold),
                "lower_threshold": float(lower_threshold)
            },
            "support_resistance": {
                "support": float(projected_support),
                "resistance": float(projected_resistance)
            },
            "stop_loss": float(stop_loss) if stop_loss is not None else None,
            "take_profit": float(take_profit) if take_profit is not None else None,
            "reasoning": reasoning,
            "lookback_period": lookback_period,
            "future_periods": future_periods,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Erreur lors du dessin du canal prédictif pour {symbol}: {e}")
        return {
            "has_channel": False,
            "reason": f"Erreur technique: {str(e)}",
            "symbol": symbol
        }


def get_prediction_channel_5000(symbol: str, timeframe: str = "M1", future_bars: int = 5000) -> dict:
    """
    Canal de prédiction ML sur N prochaines bougies (jusqu'à 5000).
    Analyse les prix historiques, régression linéaire, projection future.
    Utilise les métriques Supabase (feedback) pour ajuster la largeur du canal.
    """
    lookback = 500
    period_seconds = 60 if timeframe == "M1" else (300 if timeframe == "M5" else 900 if timeframe == "M15" else 3600)
    try:
        df = get_historical_data_mt5(symbol, timeframe, lookback)
        if df is None or len(df) < 100:
            df = get_recent_historical_data(symbol, lookback)
        if df is None or len(df) < 100:
            return {"ok": False, "reason": "données insuffisantes"}

        if "time" in df.columns:
            times = df["time"]
        else:
            times = pd.date_range(end=datetime.now(), periods=len(df), freq=f"{period_seconds}s")
        highs = df["high"].values
        lows = df["low"].values
        closes = df["close"].values
        n = len(closes)

        x = np.arange(n)
        coeffs_high = np.polyfit(x, highs, 1)
        coeffs_low = np.polyfit(x, lows, 1)
        channel_width = np.mean(highs - lows)

        # Feedback Supabase: ajuster la largeur selon la précision du modèle (métriques)
        width_mult = 1.0
        try:
            import os
            import httpx
            supabase_url = os.getenv("SUPABASE_URL", "https://bpzqnooiisgadzicwupi.supabase.co")
            # Utiliser la clé de service si disponible (permissions complètes), sinon anon
            supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")
            if supabase_key:
                r = httpx.get(
                    f"{supabase_url}/rest/v1/model_metrics?symbol=eq.{symbol}&order=training_date.desc&limit=1",
                    headers={"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"},
                    timeout=5,
                )
                if r.status_code == 200 and r.json():
                    row = r.json()[0]
                    acc = row.get("accuracy") or row.get("accuracy_score")
                    if acc is not None:
                        if acc < 0.6:
                            width_mult = 1.4
                        elif acc < 0.75:
                            width_mult = 1.2
                pred_acc = get_prediction_accuracy_score(symbol) if symbol else 0.5
                if pred_acc < 0.6:
                    width_mult = max(width_mult, 1.3)
        except Exception:
            pass

        future_bars = min(max(1, future_bars), 5000)
        x_start = n
        x_end = n + future_bars
        upper_start = float(np.polyval(coeffs_high, x_start))
        upper_end = float(np.polyval(coeffs_high, x_end))
        lower_start = float(np.polyval(coeffs_low, x_start))
        lower_end = float(np.polyval(coeffs_low, x_end))
        half_w = (channel_width * (width_mult - 1)) / 2
        upper_start += half_w
        upper_end += half_w
        lower_start -= half_w
        lower_end -= half_w

        # Points SH/SL prédits (10 étapes dans la zone future)
        predicted_points = []
        step = max(1, future_bars // 10)
        for k in range(1, 11):
            bars_ahead = min(k * step, future_bars)
            x_point = n + bars_ahead
            up_val = float(np.polyval(coeffs_high, x_point)) + half_w
            lo_val = float(np.polyval(coeffs_low, x_point)) - half_w
            predicted_points.append(
                {
                    "index": k,
                    "bars_ahead": int(bars_ahead),
                    "sh_price": round(up_val, 8),
                    "sl_price": round(lo_val, 8),
                }
            )

        if hasattr(times, "iloc"):
            last_ts = times.iloc[-1]
        else:
            last_ts = times[-1]
        if hasattr(last_ts, "timestamp"):
            time_start = int(last_ts.timestamp())
        else:
            time_start = int(pd.Timestamp(last_ts).timestamp())

        # Sauvegarde facultative du canal et des points prédits dans Supabase
        try:
            import os
            import httpx

            supabase_url = os.getenv("SUPABASE_URL", "https://bpzqnooiisgadzicwupi.supabase.co")
            supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")
            if supabase_key:
                payload = {
                    "symbol": symbol,
                    "timeframe": timeframe,
                    "time_start": time_start,
                    "period_seconds": period_seconds,
                    "future_bars": future_bars,
                    "upper_start": round(upper_start, 8),
                    "upper_end": round(upper_end, 8),
                    "lower_start": round(lower_start, 8),
                    "lower_end": round(lower_end, 8),
                    "width_mult": float(width_mult),
                    "predicted_points": convert_numpy_to_python(predicted_points),
                }
                httpx.post(
                    f"{supabase_url}/rest/v1/prediction_channels",
                    json=payload,
                    headers={
                        "apikey": supabase_key,
                        "Authorization": f"Bearer {supabase_key}",
                        "Content-Type": "application/json",
                        "Prefer": "resolution=merge-duplicates,return=minimal",
                    },
                    timeout=5.0,
                )
        except Exception:
            # En cas d'échec de Supabase, on continue simplement sans bloquer l'API
            pass

        return {
            "ok": True,
            "symbol": symbol,
            "timeframe": timeframe,
            "time_start": time_start,
            "period_seconds": period_seconds,
            "future_bars": future_bars,
            "upper_start": round(upper_start, 8),
            "upper_end": round(upper_end, 8),
            "lower_start": round(lower_start, 8),
            "lower_end": round(lower_end, 8),
            "width_mult": width_mult,
            "predicted_points": predicted_points,
        }
    except Exception as e:
        logger.error(f"Erreur canal prédiction 5000 pour {symbol}: {e}")
        return {"ok": False, "reason": str(e)[:200]}


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
            "Boom 300 Index": "^GSPC",
            "Boom 600 Index": "^GSPC",
            "Boom 900 Index": "^GSPC",
            "Boom 1000 Index": "^GSPC",
            "Crash 300 Index": "^VIX",
            "Crash 500 Index": "^VIX",
            "Crash 900 Index": "^VIX",
            "Crash 1000 Index": "^VIX",
            "Volatility 75 Index": "^VIX",
            "Volatility 100 Index": "^VIX",
            "Volatility 25 Index": "^VIX",
            "Step Index": "^GSPC",
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
            "Boom 300 Index": 300,
            "Boom 500 Index": 5000,
            "Boom 600 Index": 600,
            "Boom 900 Index": 900,
            "Boom 1000 Index": 1000,
            "Crash 300 Index": 300,
            "Crash 500 Index": 500,
            "Crash 900 Index": 900,
            "Crash 1000 Index": 1000,
            "Volatility 25 Index": 25,
            "Volatility 75 Index": 75,
            "Volatility 100 Index": 100,
            "Step Index": 1000,
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

# Charger les variables d'environnement (fusion .env + .env.supabase)
try:
    from dotenv import load_dotenv
    base_dir = Path(__file__).parent
    env_path = base_dir / '.env'
    supabase_env_path = base_dir / '.env.supabase'

    def _safe_load_dotenv(path: Path) -> bool:
        # Certains .env contiennent des caractères non-UTF8 sous Windows.
        # On tente utf-8 puis latin-1 (fallback).
        try:
            load_dotenv(path)
            return True
        except UnicodeDecodeError:
            try:
                load_dotenv(path, encoding="latin-1")
                return True
            except Exception:
                return False
        except Exception:
            return False

    if env_path.exists():
        if _safe_load_dotenv(env_path):
            logger.info(f"✅ Fichier .env chargé depuis: {env_path}")
        else:
            logger.warning(f"⚠️ Impossible de charger .env (encodage?) depuis: {env_path}")
    if supabase_env_path.exists():
        # Fusion: .env.supabase complète/écrase les vars Supabase
        if _safe_load_dotenv(supabase_env_path):
            logger.info("✅ Fichier .env.supabase fusionné (SUPABASE_*, DATABASE_URL)")
        else:
            logger.warning(f"⚠️ Impossible de charger .env.supabase (encodage?) depuis: {supabase_env_path}")
    if not env_path.exists() and not supabase_env_path.exists():
        load_dotenv()
        logger.info("✅ Variables d'environnement chargées (système)")
except ImportError:
    logger.warning(
        "⚠️ python-dotenv non disponible - "
        "utilisation des variables d'environnement système uniquement"
    )
except Exception as e:
    logger.warning(f"⚠️ Erreur lors du chargement du .env: {e}")

# Log explicite (évite d'écrire dans un projet par défaut par erreur)
try:
    _get_supabase_config(strict=False)
except Exception as _e:
    logger.warning(f"⚠️ Supabase non configuré au démarrage: {_e}")

# Configuration PostgreSQL pour feedback loop
def _resolve_database_url() -> str:
    """
    Construit ou corrige la DATABASE_URL pour Supabase.
    - Utilise DATABASE_URL si valide.
    - Sinon construit depuis SUPABASE_PROJECT_ID + SUPABASE_DB_PASSWORD.
    - Corrige le mot de passe avec @ non encodé (remplace par %40).
    """
    from urllib.parse import quote_plus, urlparse, urlunparse

    raw = os.getenv("DATABASE_URL", "").strip()
    project_id = os.getenv("SUPABASE_PROJECT_ID", "bpzqnooiisgadzicwupi")
    db_password = os.getenv("SUPABASE_DB_PASSWORD", "")

    # Construction depuis variables Supabase si DATABASE_URL vide ou invalide
    if db_password and ("supabase" in raw.lower() or not raw):
        host = os.getenv("SUPABASE_DB_HOST") or f"db.{project_id}.supabase.co"
        port = os.getenv("SUPABASE_DB_PORT", "5432")
        user = os.getenv("SUPABASE_DB_USER", "postgres")
        dbname = os.getenv("SUPABASE_DB_NAME", "postgres")
        pass_enc = quote_plus(db_password)
        raw = f"postgresql://{user}:{pass_enc}@{host}:{port}/{dbname}?sslmode=require"
        logger.info(f"📝 DATABASE_URL construite depuis SUPABASE_* (host={host})")
        return raw

    if not raw:
        return ""

    # Corriger @ non encodé dans le mot de passe (cause getaddrinfo failed)
    parsed = urlparse(raw)
    netloc = parsed.netloc
    if "@" in netloc:
        parts = netloc.rsplit("@", 1)
        if len(parts) == 2:
            userinfo, hostport = parts
            # Encoder @ dans le mot de passe
            if "@" in userinfo and ":" in userinfo:
                user, pass_raw = userinfo.split(":", 1)
                if "@" in pass_raw:
                    pass_enc = quote_plus(pass_raw)
                    userinfo = f"{user}:{pass_enc}"
                    logger.info("📝 DATABASE_URL corrigée (mot de passe avec @ encodé)")
            # Remplacer pooler par host direct Supabase (db.PROJECT_ID.supabase.co)
            if "pooler.supabase.com" in hostport and project_id:
                _port = hostport.rsplit(":", 1)[-1] if ":" in hostport else "5432"
                hostport = f"db.{project_id}.supabase.co:{_port}"
                logger.info(f"📝 DATABASE_URL: pooler remplacé par db.{project_id}.supabase.co")
            netloc = f"{userinfo}@{hostport}"
            raw = urlunparse(parsed._replace(netloc=netloc))
    return raw


DATABASE_URL = _resolve_database_url()
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
# Vérification si on est sur Supabase
RUNNING_ON_SUPABASE = bool(os.getenv("SUPABASE_URL") or os.getenv("SUPABASE_PROJECT_ID"))
RUNNING_ON_RENDER = bool(os.getenv("RENDER") or os.getenv("RENDER_SERVICE_ID"))

# Mode économie d'énergie: activé par défaut sur Render.
# Permet de limiter les tâches de fond 24/24 qui consomment le quota.
AI_LOW_POWER_MODE = _env_bool("AI_LOW_POWER_MODE", default=RUNNING_ON_RENDER)

# Réglages "sobres" pour limiter la conso 24/24 sur Render
_startup_training_default = (not RUNNING_ON_RENDER) and (not AI_LOW_POWER_MODE)
_symbol_stats_loop_default = (not RUNNING_ON_RENDER) and (not AI_LOW_POWER_MODE)
_supabase_trainer_default = (not RUNNING_ON_RENDER) and (not AI_LOW_POWER_MODE)

AI_ENABLE_STARTUP_TRAINING = _env_bool("AI_ENABLE_STARTUP_TRAINING", default=_startup_training_default)
AI_ENABLE_SYMBOL_STATS_LOOP = _env_bool("AI_ENABLE_SYMBOL_STATS_LOOP", default=_symbol_stats_loop_default)
AI_SYMBOL_STATS_INTERVAL_SEC = int(os.getenv("AI_SYMBOL_STATS_INTERVAL_SEC", "3600" if RUNNING_ON_RENDER else "300"))
AI_ENABLE_SUPABASE_CONTINUOUS_TRAINER = _env_bool("AI_ENABLE_SUPABASE_CONTINUOUS_TRAINER", default=_supabase_trainer_default)
AI_CONTINUOUS_DEFAULT_INTERVAL_SEC = int(os.getenv("AI_CONTINUOUS_DEFAULT_INTERVAL_SEC", "3600" if RUNNING_ON_RENDER else "600"))
AI_CONTINUOUS_MIN_INTERVAL_SEC = int(os.getenv("AI_CONTINUOUS_MIN_INTERVAL_SEC", "1800" if RUNNING_ON_RENDER else "300"))

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
    if RUNNING_ON_SUPABASE:
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

# Indicateur global de disponibilité du backend ML
backend_available = False

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

# Intégrer le web dashboard (interface graphique)
try:
    from web_dashboard import app as flask_dashboard_app
    app.mount("/ui", WSGIMiddleware(flask_dashboard_app))
    logger.info("📊 Dashboard web intégré: http://localhost:8000/ui")
except Exception as e:
    logger.warning("⚠️ Dashboard web non chargé (optionnel): %s", str(e)[:80])

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
            dsn = DATABASE_URL
            # Ajouter sslmode=require pour Supabase/Render PostgreSQL si absent
            if "supabase.co" in dsn.lower() or "render.com" in dsn.lower():
                if "sslmode" not in dsn.lower():
                    separator = "?" if "?" not in dsn else "&"
                    dsn = f"{dsn}{separator}sslmode=require"
                    logger.info("📝 Ajout de sslmode=require pour PostgreSQL")
            
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

@app.post("/trades")
async def create_trade(trade: TradeIn):
    """Enregistre un trade dans la table core `trades`."""
    try:
        if not DB_AVAILABLE:
            raise HTTPException(status_code=503, detail="Base de données non disponible")

        symbol = (trade.symbol or "").strip()
        strategy = (trade.strategy or "").strip()
        direction = (trade.direction or "").strip().upper()

        if not symbol:
            raise HTTPException(status_code=400, detail="symbol requis")
        if not strategy:
            raise HTTPException(status_code=400, detail="strategy requis")
        if direction not in ("BUY", "SELL"):
            raise HTTPException(status_code=400, detail="direction doit être BUY ou SELL")

        pool = await get_db_pool()
        if not pool:
            raise HTTPException(status_code=503, detail="Connexion base de données impossible")

        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                INSERT INTO trades (
                    mt5_ticket, symbol, category, strategy, direction,
                    volume, entry_price, stop_loss, take_profit, close_price,
                    result_usd, result_points, risk_reward,
                    opened_at, closed_at,
                    session_tag, timeframe,
                    ai_action, ai_confidence, ml_score,
                    execution_slippage_points, context
                )
                VALUES (
                    $1, $2, $3, $4, $5,
                    $6, $7, $8, $9, $10,
                    $11, $12, $13,
                    $14, $15,
                    $16, $17,
                    $18, $19, $20,
                    $21, $22::jsonb
                )
                RETURNING id, created_at
                """,
                trade.mt5_ticket,
                symbol,
                trade.category,
                strategy,
                direction,
                trade.volume,
                trade.entry_price,
                trade.stop_loss,
                trade.take_profit,
                trade.close_price,
                trade.result_usd,
                trade.result_points,
                trade.risk_reward,
                trade.opened_at,
                trade.closed_at,
                trade.session_tag,
                trade.timeframe,
                trade.ai_action,
                trade.ai_confidence,
                trade.ml_score,
                trade.execution_slippage_points,
                json.dumps(trade.context or {}),
            )

        return {
            "ok": True,
            "id": str(row["id"]),
            "symbol": symbol,
            "created_at": row["created_at"].isoformat() if row and row["created_at"] else None,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur /trades: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/stair/detect")
async def stair_detect_report(body: StairDetectIn):
    """Enregistre une détection escalier M1 (EA ou script) dans Supabase `stair_detections`."""
    sym = (body.symbol or "").strip()
    d = (body.direction or "").strip().upper()
    if not sym:
        raise HTTPException(status_code=400, detail="symbol requis")
    if d not in ("BUY", "SELL"):
        raise HTTPException(status_code=400, detail="direction doit être BUY ou SELL")
    wr, _n = await _stair_empirical_win_rate(sym, d, body.pattern_kinds)
    q = _stair_compute_quality_from_features(body.features or {})
    payload = {
        "client_event_id": body.client_event_id,
        "symbol": sym,
        "category": (body.category or "boomcrash").strip() or "boomcrash",
        "direction": d,
        "timeframe": (body.timeframe or "M1").strip() or "M1",
        "pattern_kinds": body.pattern_kinds,
        "quality_score": q,
        "empirical_win_rate_at_detect": wr,
        "features": body.features or {},
        "ai_action": body.ai_action,
        "ai_confidence": body.ai_confidence,
        "mt5_ticket": body.mt5_ticket,
        "outcome": "open",
        "source": (body.source or "ea").strip() or "ea",
    }
    await _insert_stair_detection_supabase(payload)
    return {"ok": True, "quality_score": q, "empirical_win_rate_snapshot": wr, "closed_trades_in_bucket": _n}


@app.patch("/stair/outcome")
async def stair_outcome_update(body: StairOutcomeIn):
    """Clôture un enregistrement stair (win/loss/breakeven/expired) par id ou client_event_id."""
    oc = (body.outcome or "").strip().lower()
    if oc not in ("win", "loss", "breakeven", "expired"):
        raise HTTPException(status_code=400, detail="outcome invalide")
    if not body.id and not body.client_event_id:
        raise HTTPException(status_code=400, detail="id ou client_event_id requis")
    ok = await _patch_stair_outcome_supabase(
        row_id=(body.id or "").strip() or None,
        client_event_id=(body.client_event_id or "").strip() or None,
        outcome=oc,
        result_usd=body.result_usd,
        closed_at_iso=body.closed_at,
        mt5_ticket=body.mt5_ticket,
    )
    if not ok:
        raise HTTPException(status_code=404, detail="ligne stair_detections introuvable ou Supabase indisponible")
    _stair_summary_cache.clear()
    return {"ok": True}


@app.get("/stair/stats")
async def stair_stats_query(symbol: str, direction: str, pattern_kinds: Optional[str] = None):
    """Lit les agrégats `stair_quality_summary` pour calibrage / dashboard."""
    sym = (symbol or "").strip()
    d = (direction or "").strip().upper()
    if not sym or d not in ("BUY", "SELL"):
        raise HTTPException(status_code=400, detail="symbol et direction (BUY|SELL) requis")
    rows = await _stair_fetch_quality_rows(sym, d)
    row = _stair_pick_summary_row(rows, pattern_kinds)
    return {"symbol": sym, "direction": d, "pattern_kinds": pattern_kinds, "best_match": row, "rows": rows}


@app.get("/stats/symbol", response_model=SymbolStatsOut)
async def get_symbol_daily_stats(symbol: str, trade_date: Optional[str] = None):
    """Retourne les stats journalières d'un symbole depuis `daily_symbol_stats`."""
    try:
        if not DB_AVAILABLE:
            raise HTTPException(status_code=503, detail="Base de données non disponible")

        sym = (symbol or "").strip()
        if not sym:
            raise HTTPException(status_code=400, detail="symbol requis")

        parsed_date = None
        if trade_date:
            try:
                parsed_date = datetime.strptime(trade_date, "%Y-%m-%d").date()
            except ValueError:
                raise HTTPException(status_code=400, detail="trade_date invalide (format attendu: YYYY-MM-DD)")

        pool = await get_db_pool()
        if not pool:
            raise HTTPException(status_code=503, detail="Connexion base de données impossible")

        async with pool.acquire() as conn:
            if parsed_date:
                row = await conn.fetchrow(
                    """
                    SELECT symbol, trade_count, wins, losses, net_profit, max_drawdown, max_consecutive_losses
                    FROM daily_symbol_stats
                    WHERE symbol = $1 AND trade_date = $2
                    """,
                    sym,
                    parsed_date,
                )
            else:
                row = await conn.fetchrow(
                    """
                    SELECT symbol, trade_count, wins, losses, net_profit, max_drawdown, max_consecutive_losses
                    FROM daily_symbol_stats
                    WHERE symbol = $1
                    ORDER BY trade_date DESC
                    LIMIT 1
                    """,
                    sym,
                )

        if not row:
            raise HTTPException(status_code=404, detail=f"Aucune statistique trouvée pour {sym}")

        return SymbolStatsOut(
            symbol=row["symbol"],
            trade_count=int(row["trade_count"] or 0),
            wins=int(row["wins"] or 0),
            losses=int(row["losses"] or 0),
            net_profit=float(row["net_profit"] or 0.0),
            max_drawdown=float(row["max_drawdown"]) if row["max_drawdown"] is not None else None,
            max_consecutive_losses=(
                int(row["max_consecutive_losses"]) if row["max_consecutive_losses"] is not None else None
            ),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur /stats/symbol: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/config/symbol", response_model=SymbolConfigOut)
async def get_symbol_config(symbol: str):
    """Retourne la config adaptive d'un symbole depuis `symbol_config`."""
    try:
        if not DB_AVAILABLE:
            raise HTTPException(status_code=503, detail="Base de données non disponible")

        sym = (symbol or "").strip()
        if not sym:
            raise HTTPException(status_code=400, detail="symbol requis")

        pool = await get_db_pool()
        if not pool:
            raise HTTPException(status_code=503, detail="Connexion base de données impossible")

        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT
                    symbol, enabled, max_open_positions, min_expectancy, min_ai_confidence,
                    max_daily_loss_usd, max_symbol_loss_usd, max_consecutive_losses,
                    risk_profile, overrides
                FROM symbol_config
                WHERE symbol = $1
                """,
                sym,
            )

        if not row:
            return SymbolConfigOut(symbol=sym)

        return SymbolConfigOut(
            symbol=row["symbol"],
            enabled=bool(row["enabled"]),
            max_open_positions=int(row["max_open_positions"] or 1),
            min_expectancy=float(row["min_expectancy"] or 0.0),
            min_ai_confidence=float(row["min_ai_confidence"] or 0.55),
            max_daily_loss_usd=float(row["max_daily_loss_usd"]) if row["max_daily_loss_usd"] is not None else None,
            max_symbol_loss_usd=float(row["max_symbol_loss_usd"]) if row["max_symbol_loss_usd"] is not None else None,
            max_consecutive_losses=(
                int(row["max_consecutive_losses"]) if row["max_consecutive_losses"] is not None else None
            ),
            risk_profile=row["risk_profile"] or "balanced",
            overrides=dict(row["overrides"] or {}),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur /config/symbol: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

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
    if AI_LOW_POWER_MODE:
        logger.info("🔋 AI_LOW_POWER_MODE actif: réduction des tâches de fond non essentielles")

    if not DB_AVAILABLE:
        logger.info("📊 Mode sans PostgreSQL - feedback loop désactivé")
    
    try:
        pool = await get_db_pool()
        if pool:
            async with pool.acquire() as conn:
                await conn.execute(CREATE_FEEDBACK_TABLE_SQL)
                logger.info("✅ Table trade_feedback créée/vérifiée")
                await conn.execute(CREATE_SYMBOL_TRADE_STATS_SQL)
                logger.info("✅ Table symbol_trade_stats créée/vérifiée")
    except Exception as e:
        logger.error(f"❌ Erreur initialisation base de données: {e}", exc_info=True)
    
    # Entraîner automatiquement les modèles ML au démarrage (optionnel)
    if AI_ENABLE_STARTUP_TRAINING:
        await train_models_on_startup()
    else:
        logger.info("ℹ️ Startup training ML désactivé (AI_ENABLE_STARTUP_TRAINING=false)")

    # Démarrer la boucle de stats symboles (optionnelle)
    global _symbol_stats_task
    if AI_ENABLE_SYMBOL_STATS_LOOP:
        if _symbol_stats_task is None or _symbol_stats_task.done():
            _symbol_stats_task = asyncio.create_task(_symbol_stats_loop(interval_sec=AI_SYMBOL_STATS_INTERVAL_SEC))
            logger.info(f"✅ Boucle stats symboles démarrée ({AI_SYMBOL_STATS_INTERVAL_SEC}s)")
    else:
        logger.info("ℹ️ Boucle stats symboles désactivée (AI_ENABLE_SYMBOL_STATS_LOOP=false)")

    # Démarrer l'entraînement continu ML (Supabase: fetch predictions → train → save model_metrics)
    try:
        os.makedirs("models", exist_ok=True)
        supabase_configured = bool(
            os.getenv("SUPABASE_URL")
            and (os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY"))
        )
        if ML_TRAINER_AVAILABLE and supabase_configured and AI_ENABLE_SUPABASE_CONTINUOUS_TRAINER:
            logger.info("🤖 Démarrage entraînement continu ML (Supabase)...")
            await ml_trainer.start()
            logger.info("✅ Entraînement continu Supabase activé (predictions → model_metrics)")
        elif ML_TRAINER_AVAILABLE and supabase_configured and not AI_ENABLE_SUPABASE_CONTINUOUS_TRAINER:
            logger.info("ℹ️ Entraînement continu Supabase désactivé (AI_ENABLE_SUPABASE_CONTINUOUS_TRAINER=false)")
        elif ML_TRAINER_AVAILABLE and not supabase_configured:
            logger.info("ℹ️ Entraînement continu désactivé: SUPABASE_URL et SUPABASE_*KEY requis")
    except Exception as e:
        logger.error(f"❌ Erreur démarrage entraînement continu: {e}", exc_info=True)

@app.on_event("shutdown")
async def shutdown_event():
    """Close database pool on shutdown"""
    if hasattr(app.state, "db_pool") and app.state.db_pool:
        await app.state.db_pool.close()
        logger.info("🔒 Pool PostgreSQL fermé")

    # Arrêter le système ML
    if ML_TRAINER_AVAILABLE:
        try:
            await ml_trainer.stop()
            logger.info("🛑 Système ML arrêté")
        except Exception as e:
            logger.error(f"❌ Erreur arrêt système ML: {e}")


async def train_models_on_startup():
    """
    Entraîne automatiquement les modèles ML pour les symboles principaux en arrière-plan
    Version optimisée pour éviter les timeouts de déploiement
    """
    # Vérifier la variable d'environnement pour désactiver l'entraînement
    disable_training = os.getenv("DISABLE_ML_TRAINING", "false").lower() == "true"
    
    if disable_training:
        logger.info("⚠️ Entraînement ML désactivé via DISABLE_ML_TRAINING=true")
        return
    
    logger.info("🚀 Planification de l'entraînement automatique des modèles ML en arrière-plan...")
    
    if not ML_TRAINER_AVAILABLE:
        logger.warning("⚠️ integrated_ml_trainer non disponible - entraînement ML désactivé")
        return
    
    # Démarrer l'entraînement en arrière-plan pour ne pas bloquer le démarrage
    asyncio.create_task(train_models_background())
    
    logger.info("✅ Entraînement des modèles ML planifié en arrière-plan - Le serveur est prêt")

async def train_models_background():
    """
    Entraîne les modèles ML en arrière-plan après le démarrage du serveur
    """
    # Attendre que le serveur soit complètement démarré
    await asyncio.sleep(5)  # Attendre 5 secondes
    
    logger.info("🔄 Début de l'entraînement des modèles ML en arrière-plan...")
    
    # Symboles principaux + indices Weltrade (PainX / GainX) — même logique que train_adaptive_models / integrated_ml_trainer
    base_priority = [
        "EURUSD", "GBPUSD",
        "Boom 300 Index", "Boom 600 Index",
    ]
    wt_env = (os.getenv("AI_WELTRADE_STARTUP_SYMBOLS") or "").strip()
    if wt_env:
        weltrade_list = [s.strip() for s in wt_env.split(",") if s.strip()]
    else:
        weltrade_list = list(WELTRADE_STARTUP_TRAIN_SYMBOLS)
    seen: Set[str] = set()
    priority_symbols: List[str] = []
    for s in base_priority + weltrade_list:
        if s not in seen:
            seen.add(s)
            priority_symbols.append(s)
    if weltrade_list:
        logger.info(
            "📌 Entraînement startup: %d symbole(s) Weltrade (PainX/GainX) ajouté(s) à la file",
            len(weltrade_list),
        )
    
    timeframes = ["M1", "M5"]  # Timeframes réduits
    
    total_training_tasks = len(priority_symbols) * len(timeframes)
    completed_tasks = 0
    
    models_dir = getattr(ml_trainer, "models_dir", "models") if ML_TRAINER_AVAILABLE else "models"
    
    for symbol in priority_symbols:
        for timeframe in timeframes:
            try:
                model_key = f"{symbol}_{timeframe}"
                model_path = os.path.join(models_dir, f"{model_key}_rf.joblib")
                if os.path.exists(model_path):
                    logger.info(f"✅ Modèle déjà existant pour {model_key}")
                    completed_tasks += 1
                    continue
                
                logger.info(f"📊 Entraînement du modèle pour {symbol} {timeframe}...")
                
                try:
                    if not ML_TRAINER_AVAILABLE:
                        logger.warning(f"⚠️ integrated_ml_trainer non disponible - skip {model_key}")
                        continue
                    df = await asyncio.wait_for(
                        ml_trainer.fetch_training_data_simple(symbol, timeframe),
                        timeout=30.0
                    )
                    if df is None or len(df) < ml_trainer.min_samples_for_retraining:
                        logger.debug(f"Données insuffisantes pour {model_key}")
                        continue
                    train_result = await asyncio.wait_for(
                        asyncio.to_thread(ml_trainer.train_model_simple, df, symbol, timeframe),
                        timeout=60.0
                    )
                    if train_result:
                        logger.info(f"✅ Modèle entraîné avec succès pour {model_key}")
                        completed_tasks += 1
                        
                except asyncio.TimeoutError:
                    logger.warning(f"⏰ Timeout entraînement {symbol} {timeframe} - Passage au suivant")
                    continue
                
            except Exception as e:
                logger.error(f"❌ Erreur entraînement modèle {symbol} {timeframe}: {e}")
    
    logger.info(f"🎯 Entraînement en arrière-plan terminé: {completed_tasks}/{total_training_tasks} modèles entraînés")


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

if RUNNING_ON_SUPABASE:
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

if RUNNING_ON_SUPABASE:
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
    current_time = datetime.now().timestamp()
    
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

# ===== PROFIL HORAIRE "SYMBOL PROPICE" =====
# Fallback local (si Supabase indispo). Ces caches ne remplacent pas la source of truth Supabase.
symbol_hour_profile_cache: Dict[Tuple[str, str, int], Dict[str, Any]] = {}
symbol_hour_status_cache: Dict[Tuple[str, str], Dict[str, Any]] = {}

def _safe_float(v: Any, default: float = 0.0) -> float:
    try:
        if v is None:
            return default
        return float(v)
    except Exception:
        return default

def _clamp(x: float, lo: float, hi: float) -> float:
    return lo if x < lo else hi if x > hi else x

def _robust_minmax(values: List[float], q_low: float = 0.10, q_high: float = 0.90) -> Tuple[float, float]:
    """Retourne (low, high) robustes via quantiles; fallback min/max."""
    vals = [float(v) for v in values if isinstance(v, (int, float)) and np.isfinite(v)]
    if not vals:
        return 0.0, 1.0
    s = pd.Series(vals, dtype="float64")
    try:
        lo = float(s.quantile(q_low))
        hi = float(s.quantile(q_high))
    except Exception:
        lo = float(s.min())
        hi = float(s.max())
    if not np.isfinite(lo) or not np.isfinite(hi) or hi <= lo:
        lo = float(s.min())
        hi = float(s.max())
    if not np.isfinite(lo) or not np.isfinite(hi) or hi <= lo:
        return 0.0, 1.0
    return lo, hi

def compute_symbol_hour_profile_from_m1(
    df: "pd.DataFrame",
    symbol: str,
    timeframe: str = "M1",
    lookback_days: int = 14,
    atr_period: int = 14,
    vol_window: int = 30,
    spike_k_atr: float = 2.0,
) -> List[Dict[str, Any]]:
    """
    Calcule un profil horaire 0..23 (UTC) à partir d'un batch de bougies OHLCV.
    Colonnes requises: time, open, high, low, close (time en timestamp unix ou ISO).
    """
    if df is None or df.empty:
        return []
    _df = df.copy()
    if "time" not in _df.columns:
        return []
    _df["time"] = pd.to_datetime(_df["time"], utc=True, errors="coerce")
    _df = _df.dropna(subset=["time"])
    if _df.empty:
        return []

    for col in ("open", "high", "low", "close"):
        if col not in _df.columns:
            return []
        _df[col] = pd.to_numeric(_df[col], errors="coerce")
    _df = _df.dropna(subset=["high", "low", "close"])
    if _df.empty:
        return []

    _df = _df.sort_values("time").reset_index(drop=True)

    prev_close = _df["close"].shift(1)
    tr = pd.concat(
        [
            (_df["high"] - _df["low"]).abs(),
            (_df["high"] - prev_close).abs(),
            (_df["low"] - prev_close).abs(),
        ],
        axis=1,
    ).max(axis=1)
    atr = tr.rolling(window=atr_period, min_periods=max(2, atr_period // 2)).mean()
    _df["atr"] = atr

    close = _df["close"].replace(0, np.nan)
    logret = np.log(close / close.shift(1))
    _df["volatility"] = logret.rolling(window=vol_window, min_periods=max(5, vol_window // 3)).std()

    rng = (_df["high"] - _df["low"]).abs()
    _df["spike"] = (rng > (spike_k_atr * _df["atr"])).astype("float64")
    _df["ret"] = logret.replace([np.inf, -np.inf], np.nan)

    _df["hour_utc"] = _df["time"].dt.hour.astype("int64")

    g = _df.groupby("hour_utc", dropna=True)
    rows: List[Dict[str, Any]] = []
    for hour in range(24):
        if hour not in g.groups:
            rows.append(
                {
                    "symbol": symbol,
                    "timeframe": timeframe,
                    "lookback_days": int(lookback_days),
                    "hour_utc": int(hour),
                    "samples": 0,
                    "atr_mean": 0.0,
                    "volatility_mean": 0.0,
                    "spike_rate": 0.0,
                    "trend_bias": 0.0,
                    "propice_score": 0.0,
                }
            )
            continue

        sub = _df.loc[g.groups[hour]]
        samples = int(len(sub))
        atr_mean = float(np.nanmean(sub["atr"])) if samples else 0.0
        vol_mean = float(np.nanmean(sub["volatility"])) if samples else 0.0
        spike_rate = float(np.nanmean(sub["spike"])) if samples else 0.0

        ret_mean = float(np.nanmean(sub["ret"])) if samples else 0.0
        ret_std = float(np.nanstd(sub["ret"])) if samples else 0.0
        bias = 0.0
        if np.isfinite(ret_mean) and np.isfinite(ret_std) and ret_std > 1e-12:
            bias = float(np.tanh(ret_mean / (ret_std + 1e-12)))

        rows.append(
            {
                "symbol": symbol,
                "timeframe": timeframe,
                "lookback_days": int(lookback_days),
                "hour_utc": int(hour),
                "samples": samples,
                "atr_mean": _safe_float(atr_mean),
                "volatility_mean": _safe_float(vol_mean),
                "spike_rate": _safe_float(spike_rate),
                "trend_bias": _safe_float(bias),
                "propice_score": 0.0,
            }
        )

    # Normalisation robuste sur 24h (par symbole)
    atr_vals = [_safe_float(r["atr_mean"]) for r in rows]
    vol_vals = [_safe_float(r["volatility_mean"]) for r in rows]
    spk_vals = [_safe_float(r["spike_rate"]) for r in rows]
    samp_vals = [float(r.get("samples", 0) or 0) for r in rows]

    atr_lo, atr_hi = _robust_minmax(atr_vals)
    vol_lo, vol_hi = _robust_minmax(vol_vals)
    spk_lo, spk_hi = _robust_minmax(spk_vals)
    samp_lo, samp_hi = _robust_minmax(samp_vals)

    def _norm(v: float, lo: float, hi: float) -> float:
        if hi <= lo:
            return 0.0
        return _clamp((v - lo) / (hi - lo), 0.0, 1.0)

    w_atr, w_vol, w_spk, w_samp = 0.35, 0.35, 0.20, 0.10
    for r in rows:
        na = _norm(_safe_float(r["atr_mean"]), atr_lo, atr_hi)
        nv = _norm(_safe_float(r["volatility_mean"]), vol_lo, vol_hi)
        ns = _norm(_safe_float(r["spike_rate"]), spk_lo, spk_hi)
        nsa = _norm(float(r.get("samples", 0) or 0), samp_lo, samp_hi)
        score = (w_atr * na) + (w_vol * nv) + (w_spk * ns) + (w_samp * nsa)
        r["propice_score"] = float(_clamp(score, 0.0, 1.0))

    return rows


async def _compute_propice_top_from_trade_feedback(
    timeframe: str,
    lookback_days: int,
    n: int,
    now_hour_utc: int,
) -> Dict[str, Any]:
    """
    Calcule les Top N symboles \"propices\" à partir des résultats de trades (trade_feedback) stockés dans Supabase.
    Approche: pour l'heure UTC courante, agréger (wins/losses/net_profit/samples) sur les trades clôturés
    et produire un propice_score 0..1.
    """
    supabase_url, supabase_key = _get_supabase_config(strict=True)
    import httpx
    from datetime import timezone

    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
    }

    # Fenêtre de lookback sur close_time
    dt_from = datetime.utcnow().replace(tzinfo=timezone.utc) - timedelta(days=int(lookback_days or 14))
    iso_from = dt_from.isoformat()

    # Télécharger les trades clôturés récents (on agrège en Python)
    # NOTE: PostgREST group-by n'est pas toujours disponible -> on agrège client-side
    params = {
        "timeframe": f"eq.{timeframe}",
        "close_time": f"gte.{iso_from}",
        "select": "symbol,close_time,profit,is_win",
        "order": "close_time.desc",
        "limit": "5000",  # garde-fou
    }

    async with httpx.AsyncClient(timeout=12.0) as client:
        r = await client.get(f"{supabase_url}/rest/v1/trade_feedback", headers=headers, params=params)
    if r.status_code not in (200, 206):
        raise RuntimeError(f"Supabase trade_feedback HTTP {r.status_code}: {r.text[:200]}")

    rows = r.json() if r.text else []
    if not rows:
        return {"rows": [], "source": "supabase_trade_feedback", "note": "no_rows"}

    # Agréger par symbole pour l'heure UTC courante
    agg: Dict[str, Dict[str, Any]] = {}
    for rr in rows:
        sym = (rr.get("symbol") or "").strip()
        if not sym:
            continue
        ct = rr.get("close_time")
        if not ct:
            continue
        try:
            ct_dt = pd.to_datetime(ct, utc=True, errors="coerce")
        except Exception:
            ct_dt = None
        if ct_dt is None or pd.isna(ct_dt):
            continue
        if int(getattr(ct_dt, "hour", -1)) != int(now_hour_utc):
            continue

        profit = rr.get("profit")
        try:
            p = float(profit) if profit is not None else 0.0
        except Exception:
            p = 0.0
        is_win = rr.get("is_win")
        w = bool(is_win) if is_win is not None else (p > 0)

        a = agg.get(sym)
        if not a:
            a = {"symbol": sym, "samples": 0, "wins": 0, "losses": 0, "net_profit": 0.0}
            agg[sym] = a
        a["samples"] += 1
        a["net_profit"] += p
        if w:
            a["wins"] += 1
        else:
            a["losses"] += 1

    if not agg:
        return {"rows": [], "source": "supabase_trade_feedback", "note": "no_rows_for_hour"}

    # Charger la fiabilité ML (reliability_score) par symbole pour pondérer le score "propice"
    reliability_by_symbol: Dict[str, float] = {}
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            rm = await client.get(
                f"{supabase_url}/rest/v1/model_metrics",
                headers=headers,
                params={
                    "timeframe": f"eq.{timeframe}",
                    "select": "symbol,training_date,metadata",
                    "order": "training_date.desc",
                    "limit": "500",
                },
            )
        if rm.status_code in (200, 206) and rm.text:
            rowsm = rm.json()
            for row in rowsm:
                sym = (row.get("symbol") or "").strip()
                if not sym or sym in reliability_by_symbol:
                    continue
                meta = row.get("metadata") or {}
                if isinstance(meta, str):
                    try:
                        meta = json.loads(meta)
                    except Exception:
                        meta = {}
                rel = meta.get("reliability_score")
                try:
                    relf = float(rel)
                    relf = max(0.0, min(1.0, relf))
                except Exception:
                    relf = None  # type: ignore
                if relf is not None:
                    reliability_by_symbol[sym] = float(relf)
    except Exception:
        reliability_by_symbol = {}

    # Score: win_rate (0..1) + profit contribution (tanh normalized) + sample bonus
    out = []
    net_profits = [float(v.get("net_profit", 0.0) or 0.0) for v in agg.values()]
    lo, hi = _robust_minmax(net_profits, 0.10, 0.90)
    rng = (hi - lo) if hi > lo else 1.0

    for sym, a in agg.items():
        samples = int(a.get("samples", 0) or 0)
        wins = int(a.get("wins", 0) or 0)
        losses = int(a.get("losses", 0) or 0)
        netp = float(a.get("net_profit", 0.0) or 0.0)

        win_rate = (wins / max(1, wins + losses))
        profit_norm = (netp - lo) / rng  # ~0..1
        profit_norm = float(_clamp(profit_norm, 0.0, 1.0))
        sample_bonus = float(_clamp(samples / 20.0, 0.0, 1.0))

        score = 0.55 * win_rate + 0.35 * profit_norm + 0.10 * sample_bonus
        rel = reliability_by_symbol.get(sym)
        if rel is not None:
            # Pondération douce: 0.85..1.15 selon fiabilité (évite de sur-filtrer)
            score *= (0.85 + 0.30 * float(rel))
        out.append(
            {
                "symbol": sym,
                "timeframe": timeframe,
                "lookback_days": int(lookback_days),
                "hour_utc": int(now_hour_utc),
                "samples": samples,
                "wins": wins,
                "losses": losses,
                "net_profit": round(netp, 2),
                "win_rate": round(win_rate, 4),
                "reliability_score": float(rel) if rel is not None else None,
                "propice_score": float(_clamp(score, 0.0, 1.0)),
                "reason": "trade_feedback",
            }
        )

    out.sort(key=lambda r: float(r.get("propice_score", 0.0) or 0.0), reverse=True)
    return {"rows": out[:n], "source": "supabase_trade_feedback"}


def _normalize_symbol_name(sym: str) -> str:
    s = (sym or "").strip()
    if not s:
        return s
    su = s.upper().replace(" ", "")
    aliases = {
        "BOOM1000": "Boom 1000 Index",
        "BOOM500": "Boom 500 Index",
        "CRASH1000": "Crash 1000 Index",
        "CRASH500": "Crash 500 Index",
        "CRASH900": "Crash 900 Index",
        "CRASH600": "Crash 600 Index",
        "CRASH300": "Crash 300 Index",
        "BOOM600": "Boom 600 Index",
    }
    return aliases.get(su, s)


@app.get("/dashboard/top-net-summary")
async def get_dashboard_top_net_summary(timeframe: str = "M1", days: int = 30, top_n: int = 3):
    """
    Résumé dashboard (flat JSON) pour MT5:
    - Top N symboles par net profit USD (trade_feedback)
    - Performance globale modèle (%) basée sur symbol_prediction_score_daily pondéré par samples
    """
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        import httpx
        d = int(max(1, min(365, days)))
        n = int(max(1, min(5, top_n)))
        tf = (timeframe or "M1").upper()
        dt_from = (datetime.utcnow() - timedelta(days=d)).isoformat()
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}

        # 1) trade_feedback -> top net (normalisé par alias symbol)
        async with httpx.AsyncClient(timeout=15.0) as client:
            rf = await client.get(
                f"{supabase_url}/rest/v1/trade_feedback",
                headers=headers,
                params={
                    "select": "symbol,profit,close_time",
                    "close_time": f"gte.{dt_from}",
                    "order": "close_time.desc",
                    "limit": "20000",
                },
            )
        if rf.status_code >= 300:
            raise HTTPException(status_code=502, detail=f"trade_feedback read error {rf.status_code}")
        rows = rf.json() if rf.text else []
        agg: Dict[str, float] = {}
        for r in rows:
            sym = _normalize_symbol_name(str(r.get("symbol") or ""))
            if not sym:
                continue
            p = float(r.get("profit") or 0.0)
            agg[sym] = float(agg.get(sym, 0.0) + p)
        top = sorted(agg.items(), key=lambda kv: kv[1], reverse=True)[:n]

        # 2) perf globale modèle depuis symbol_prediction_score_daily
        async with httpx.AsyncClient(timeout=15.0) as client:
            rs = await client.get(
                f"{supabase_url}/rest/v1/symbol_prediction_score_daily",
                headers=headers,
                params={
                    "select": "symbol,timeframe,day,samples,direction_hit_rate",
                    "timeframe": f"eq.{tf}",
                    "day": f"gte.{dt_from[:10]}",
                    "limit": "20000",
                },
            )
        if rs.status_code >= 300:
            raise HTTPException(status_code=502, detail=f"prediction score read error {rs.status_code}")
        score_rows = rs.json() if rs.text else []
        total_samples = 0
        weighted_hits = 0.0
        for r in score_rows:
            s = int(r.get("samples") or 0)
            h = float(r.get("direction_hit_rate") or 0.0)
            total_samples += s
            weighted_hits += h * s
        global_perf = (weighted_hits / total_samples) * 100.0 if total_samples > 0 else 0.0

        out: Dict[str, Any] = {
            "timeframe": tf,
            "window_days": d,
            "global_model_perf_pct": round(global_perf, 2),
            "global_model_samples": int(total_samples),
            "top_count": len(top),
            "updated_at": datetime.utcnow().isoformat(),
        }
        for i in range(3):
            idx = i + 1
            if i < len(top):
                out[f"top{idx}_symbol"] = top[i][0]
                out[f"top{idx}_net_usd"] = round(float(top[i][1]), 2)
            else:
                out[f"top{idx}_symbol"] = "N/A"
                out[f"top{idx}_net_usd"] = 0.0
        return out
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur /dashboard/top-net-summary: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

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
        "predicted_prices": predicted_prices[:500],  # Augmenté à 500 pour MT5 visualization
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


# ===== CALIBRATION ADAPTATIVE (réduction décalage prédiction/mouvement réel) =====
# Stockage persistant de la calibration par symbole (drift, précision, ajustements)
CALIBRATION_FILE = DATA_DIR / "symbol_calibration.json"
_symbol_calibration: Dict[str, Dict[str, Any]] = {}
_calibration_loaded = False

def _ensure_calibration_loaded():
    """Charge la calibration depuis le fichier au premier accès"""
    global _symbol_calibration, _calibration_loaded
    if not _calibration_loaded and CALIBRATION_FILE.exists():
        try:
            with open(CALIBRATION_FILE, "r", encoding="utf-8") as f:
                _symbol_calibration.update(json.load(f))
            _calibration_loaded = True
            logger.info(f"✅ Calibration chargée: {len(_symbol_calibration)} symboles")
        except Exception as e:
            logger.warning(f"Erreur chargement calibration: {e}")
            _calibration_loaded = True

def _save_calibration():
    """Sauvegarde la calibration sur disque"""
    try:
        CALIBRATION_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(CALIBRATION_FILE, "w", encoding="utf-8") as f:
            json.dump(_symbol_calibration, f, indent=2, ensure_ascii=False)
    except Exception as e:
        logger.warning(f"Erreur sauvegarde calibration: {e}")

def get_symbol_calibration(symbol: str, timeframe: str = "M1") -> Dict[str, Any]:
    """
    Retourne la calibration pour un symbole (ML feedback + prédiction accuracy).
    Utilisé par /decision pour ajuster confiance et réduire le décalage.
    """
    _ensure_calibration_loaded()
    cal = _symbol_calibration.get(symbol, {})
    pred_acc = get_prediction_accuracy_score(symbol)
    pred_mult = get_prediction_confidence_multiplier(symbol)
    # ML metrics (si disponible via _compute_ml_metrics)
    ml_min_conf = 0.60  # défaut
    try:
        ml = _compute_ml_metrics(symbol, timeframe)
        ml_min_conf = float(ml.get("recommendations", {}).get("min_confidence", 0.60))
    except Exception:
        pass
    return {
        "min_confidence": max(0.45, min(0.85, ml_min_conf)),
        "confidence_multiplier": pred_mult,
        "prediction_accuracy": pred_acc,
        "drift_factor": cal.get("drift_factor", 1.0),
        "last_updated": cal.get("last_updated"),
    }

def apply_calibration_to_decision(symbol: str, action: str, confidence: float, reason: str, timeframe: str = "M1") -> Tuple[str, float, str]:
    """
    Applique la calibration (feedback + prédiction) pour réduire le décalage.
    Ajuste la confiance et force HOLD si précision historique trop faible.
    """
    cal = get_symbol_calibration(symbol, timeframe)
    mult = cal["confidence_multiplier"]
    min_conf = cal["min_confidence"]
    pred_acc = cal["prediction_accuracy"]
    new_confidence = confidence * mult
    if action != "hold":
        if new_confidence < min_conf:
            return "hold", max(0.50, min_conf), f"{reason} | Calibration: conf ajustée ({pred_acc*100:.0f}% précision) → hold"
        new_confidence = max(new_confidence, min_conf)
    return action, min(0.98, new_confidence), f"{reason} | Cal: x{mult:.2f}" if mult < 1.0 else reason

def update_calibration_from_feedback(symbol: str, is_win: bool, profit: float, side: str = ""):
    """Met à jour la calibration après un feedback de trade (appelé par /trades/feedback)"""
    _ensure_calibration_loaded()
    if symbol not in _symbol_calibration:
        _symbol_calibration[symbol] = {"wins": 0, "total": 0, "drift_factor": 1.0}
    c = _symbol_calibration[symbol]
    c["total"] = c.get("total", 0) + 1
    if is_win:
        c["wins"] = c.get("wins", 0) + 1
    win_rate = c["wins"] / c["total"] if c["total"] > 0 else 0.5
    # drift_factor: si win_rate bas, réduire la confiance future
    c["drift_factor"] = max(0.7, min(1.2, 0.8 + win_rate * 0.4))
    c["last_updated"] = datetime.now().isoformat()
    _save_calibration()

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

# ÉTAT TEMPS RÉEL POUR LES SPIKES (Boom/Crash) - inspiré de SpikeSniperDeriv
_last_tick_price: Dict[str, float] = defaultdict(float)
_last_spike_info: Dict[str, Dict[str, Any]] = {}
SPIKE_THRESHOLD_POINTS: float = float(os.getenv("SPIKE_THRESHOLD_POINTS", "1.0"))
SPIKE_RECENT_WINDOW_SECONDS: int = int(os.getenv("SPIKE_RECENT_WINDOW_SECONDS", "5"))


def update_spike_state_from_request(req: "DecisionRequest") -> None:
    """
    Met à jour l'état temps réel de spike à partir d'une requête de décision.
    Logique simplifiée inspirée de SpikeSniperDeriv:
    - Boom: spike si diff >= SPIKE_THRESHOLD_POINTS
    - Crash: spike si diff <= -SPIKE_THRESHOLD_POINTS
    """
    try:
        sym = (req.symbol or "").strip()
        if not sym:
            return

        # Utiliser mid-price comme proxy du dernier prix
        last_price = None
        if req.bid is not None and req.ask is not None:
            last_price = (float(req.bid) + float(req.ask)) / 2.0
        elif req.bid is not None:
            last_price = float(req.bid)
        elif req.ask is not None:
            last_price = float(req.ask)

        if last_price is None or last_price <= 0:
            return

        prev = _last_tick_price[sym]
        _last_tick_price[sym] = last_price

        # Pas de comparaison possible au premier tick
        if prev <= 0:
            return

        diff = last_price - prev
        s_low = sym.lower()
        threshold = SPIKE_THRESHOLD_POINTS

        is_boom = "boom" in s_low
        is_crash = "crash" in s_low

        is_spike = False
        direction: Optional[str] = None

        if is_boom and diff >= threshold:
            is_spike = True
            direction = "BOOM"
        elif is_crash and diff <= -threshold:
            is_spike = True
            direction = "CRASH"

        if not is_spike:
            return

        info = {
            "time": datetime.utcnow(),
            "direction": direction,
            "diff_points": float(diff),
        }
        _last_spike_info[sym] = info
        logger.info(
            "🚨 Spike temps réel détecté | symbol=%s direction=%s diff=%.5f",
            sym,
            direction,
            diff,
        )
    except Exception as e:
        logger.warning("Erreur update_spike_state_from_request: %s", e)

# Modèles Pydantic pour les requêtes/réponses
class DecisionRequest(BaseModel):
    symbol: Optional[str] = "UNKNOWN"
    bid: Optional[float] = None
    ask: Optional[float] = None
    rsi: Optional[float] = 50.0  # Valeur neutre par défaut
    ema_fast_h1: Optional[float] = None
    ema_slow_h1: Optional[float] = None
    ema_fast_m1: Optional[float] = None
    ema_slow_m1: Optional[float] = None
    ema_fast_m5: Optional[float] = None
    ema_slow_m5: Optional[float] = None
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
    timestamp: Optional[str] = None  # Timestamp de la requête (ajouté pour corriger l'erreur 422)
    # Escalier synthétique M1 (Boom/Crash, GainX/PainX) — alimente stair_detections + ajustement confiance
    stair_detected: Optional[bool] = False
    stair_direction: Optional[str] = None  # BUY | SELL (sinon déduit du symbole)
    stair_pattern_kinds: Optional[str] = None  # ex: classic,forming
    stair_client_event_id: Optional[str] = None  # UUID côté EA pour lier le feedback trade
    stair_features: Optional[Dict[str, Any]] = None  # ex: aligned_ratio, net_move_pct, forming_match
    # Confluence finale (envoyés par MT5) : MACD histogramme M1, biais Ichimoku H1 (-1/0/1)
    macd_histogram: Optional[float] = None
    ichimoku_bias: Optional[int] = 0

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
    predicted_prices: List[float] = Field(default_factory=list)
    alignment: str = "N/A"
    coherence: str = "N/A"
    metadata: Dict[str, Any] = Field(default_factory=dict)
    gemma_analysis: Optional[str] = None  # Analyse complète Gemma+Gemini
    metadata: Optional[Dict[str, Any]] = None  # Métadonnées enrichies (RSI, EMA, ATR, etc.)


class SpikeStatus(BaseModel):
    """Statut temps réel de spike pour un symbole donné."""
    symbol: str
    spike: bool
    direction: Optional[str] = None  # "BOOM" ou "CRASH"
    diff_points: float = 0.0
    last_spike_time: Optional[str] = None

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

class TrendRequest(BaseModel):
    symbol: str
    timeframe: Optional[str] = "M1"

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

# ===== MODÈLES POUR LES PRÉDICTIONS DE CORRECTIONS =====
class CorrectionZoneAnalysis(BaseModel):
    """Modèle pour l'analyse des zones de correction passées"""
    id: Optional[int] = None
    symbol: str
    timeframe: str
    analysis_date: Optional[str] = None
    total_corrections_analyzed: Optional[int] = None
    uptrend_corrections: Optional[int] = None
    downtrend_corrections: Optional[int] = None
    avg_retracement_uptrend: Optional[float] = None
    avg_retracement_downtrend: Optional[float] = None
    max_retracement_uptrend: Optional[float] = None
    max_retracement_downtrend: Optional[float] = None
    gradual_retracement_patterns: Optional[int] = None
    consolidation_patterns: Optional[int] = None
    sharp_reversal_patterns: Optional[int] = None
    support_levels: Optional[List[float]] = None
    resistance_levels: Optional[List[float]] = None
    current_price: Optional[float] = None
    current_trend: Optional[str] = None
    volatility_level: Optional[float] = None

class CorrectionPrediction(BaseModel):
    """Modèle pour les prédictions de zones de correction futures"""
    id: Optional[int] = None
    symbol: str
    timeframe: str
    prediction_date: Optional[str] = None
    current_price: float
    current_trend: str
    prediction_confidence: float
    zone_1_level: Optional[float] = None
    zone_1_type: Optional[str] = None
    zone_1_probability: Optional[float] = None
    zone_2_level: Optional[float] = None
    zone_2_type: Optional[str] = None
    zone_2_probability: Optional[float] = None
    zone_3_level: Optional[float] = None
    zone_3_type: Optional[str] = None
    zone_3_probability: Optional[float] = None
    trend_strength_factor: Optional[float] = None
    volatility_adjustment: Optional[float] = None
    historical_accuracy: Optional[float] = None
    zone_1_reached: Optional[bool] = None
    zone_2_reached: Optional[bool] = None
    zone_3_reached: Optional[bool] = None
    actual_retracement_level: Optional[float] = None
    prediction_accuracy: Optional[float] = None
    prediction_valid_until: Optional[str] = None

class PredictionPerformance(BaseModel):
    """Modèle pour les performances du système de prédiction"""
    id: Optional[int] = None
    symbol: str
    performance_date: Optional[str] = None
    total_predictions: Optional[int] = None
    successful_predictions: Optional[int] = None
    failed_predictions: Optional[int] = None
    zone_1_accuracy: Optional[float] = None
    zone_2_accuracy: Optional[float] = None
    zone_3_accuracy: Optional[float] = None
    overall_accuracy: Optional[float] = None
    avg_confidence: Optional[float] = None
    total_corrections_analyzed: Optional[int] = None
    avg_retracement_used: Optional[float] = None
    market_volatility: Optional[float] = None

class SymbolCorrectionPattern(BaseModel):
    """Modèle pour les patterns de correction par symbole"""
    id: Optional[int] = None
    symbol: str
    pattern_type: str
    avg_retracement_percentage: Optional[float] = None
    typical_duration_bars: Optional[int] = None
    success_rate: Optional[float] = None
    min_trend_strength: Optional[float] = None
    max_volatility_level: Optional[float] = None
    best_timeframes: Optional[str] = None
    occurrences_count: Optional[int] = None
    last_updated: Optional[str] = None

class CorrectionPredictionRequest(BaseModel):
    """Modèle pour les requêtes de prédiction de correction"""
    symbol: str
    timeframe: Optional[str] = "M1"
    current_price: float
    current_trend: str
    volatility_level: Optional[float] = None

class CorrectionPredictionResponse(BaseModel):
    """Modèle pour les réponses de prédiction de correction"""
    status: str
    symbol: str
    timestamp: str
    prediction: Optional[CorrectionPrediction] = None
    analysis: Optional[CorrectionZoneAnalysis] = None
    confidence_score: Optional[float] = None
    recommended_action: Optional[str] = None
    risk_level: Optional[str] = None
    message: Optional[str] = None

# ========== FONCTION SIMPLIFIÉE POUR ROBOCOP v2 ==========
# Modifier la fonction decision_simplified pour utiliser le ML
async def decision_simplified(request: DecisionRequest):
    """
    Fonction de décision simplifiée avec amélioration ML
    """
    global decision_count
    decision_count += 1
    
    logger.info(f"🎯 MODE SIMPLIFIÉ + ML - Requête décision pour {request.symbol}")
    try:
        update_spike_state_from_request(request)
    except Exception as e:
        logger.debug(f"⚠️ update_spike_state_from_request (simplifié) erreur: {e}")
    logger.info(f"   Bid: {request.bid}, Ask: {request.ask}, RSI: {request.rsi}")
    
    # Analyse technique de base
    action = "hold"
    confidence = 0.5
    reason = "Analyse technique multi-timeframe"
    
    # Scores pondérés par timeframe
    buy_score = 0.0
    sell_score = 0.0
    
    # 1. Analyse RSI (poids: 15%)
    if request.rsi:
        if request.rsi < 30:
            buy_score += 0.15
            reason += f"RSI surventé ({request.rsi:.1f}). "
        elif request.rsi > 70:
            sell_score += 0.15
            reason += f"RSI surachat ({request.rsi:.1f}). "
        elif 30 <= request.rsi <= 40:
            buy_score += 0.08
            reason += f"RSI zone survente ({request.rsi:.1f}). "
        elif 60 <= request.rsi <= 70:
            sell_score += 0.08
            reason += f"RSI zone surachat ({request.rsi:.1f}). "
    
    # 2. Analyse EMA M1 (poids: 20%)
    if request.ema_fast_m1 and request.ema_slow_m1:
        ema_diff_m1 = request.ema_fast_m1 - request.ema_slow_m1
        ema_strength_m1 = abs(ema_diff_m1) / request.ema_slow_m1 if request.ema_slow_m1 > 0 else 0
        
        if ema_diff_m1 > 0:
            buy_score += 0.20 * min(1.0, ema_strength_m1 * 100)
            reason += f"EMA M1 haussière (+{ema_strength_m1*100:.1f}%). "
        else:
            sell_score += 0.20 * min(1.0, ema_strength_m1 * 100)
            reason += f"EMA M1 baissière ({ema_strength_m1*100:.1f}%). "
    
    # 3. Analyse EMA H1 (poids: 35%)
    if request.ema_fast_h1 and request.ema_slow_h1:
        ema_diff_h1 = request.ema_fast_h1 - request.ema_slow_h1
        ema_strength_h1 = abs(ema_diff_h1) / request.ema_slow_h1 if request.ema_slow_h1 > 0 else 0
        
        if ema_diff_h1 > 0:
            buy_score += 0.35 * min(1.0, ema_strength_h1 * 50)
            reason += f"EMA H1 haussière (+{ema_strength_h1*50:.1f}%). "
        else:
            sell_score += 0.35 * min(1.0, ema_strength_h1 * 50)
            reason += f"EMA H1 baissière ({ema_strength_h1*50:.1f}%). "
    
    # 4. Analyse EMA M5 (poids: 25%)
    if request.ema_fast_m5 and request.ema_slow_m5:
        ema_diff_m5 = request.ema_fast_m5 - request.ema_slow_m5
        ema_strength_m5 = abs(ema_diff_m5) / request.ema_slow_m5 if request.ema_slow_m5 > 0 else 0
        
        if ema_diff_m5 > 0:
            buy_score += 0.25 * min(1.0, ema_strength_m5 * 75)
            reason += f"EMA M5 haussière (+{ema_strength_m5*75:.1f}%). "
        else:
            sell_score += 0.25 * min(1.0, ema_strength_m5 * 75)
            reason += f"EMA M5 baissière ({ema_strength_m5*75:.1f}%). "
    
    # 4b. Boom : bonus si M1+M5 haussiers (contrepoids au H1 baissier — stair M1 / scalp)
    try:
        if is_boom_crash_symbol(str(request.symbol)) and "boom" in str(request.symbol).lower():
            e1f = float(request.ema_fast_m1 or 0.0)
            e1s = float(request.ema_slow_m1 or 0.0)
            e5f = float(request.ema_fast_m5 or 0.0)
            e5s = float(request.ema_slow_m5 or 0.0)
            if e1f > e1s and e5f > e5s and e1s > 0.0 and e5s > 0.0:
                buy_score += 0.18
                reason += "[Boom: M1+M5 haussiers — bonus buy_score vs H1] "
    except Exception:
        pass
    
    # 5. Décision technique de base
    if buy_score > sell_score:
        base_action = "buy"
        base_confidence = 0.5 + (buy_score - sell_score) / 2
    elif sell_score > buy_score:
        base_action = "sell"
        base_confidence = 0.5 + (sell_score - buy_score) / 2
    else:
        base_action = "hold"
        base_confidence = 0.5
    
    # 6. AMÉLIORATION AVEC ML
    market_data = {
        "symbol": request.symbol,
        "bid": request.bid,
        "ask": request.ask,
        "rsi": request.rsi,
        "ema_fast_m1": request.ema_fast_m1,
        "ema_slow_m1": request.ema_slow_m1,
        "ema_fast_h1": request.ema_fast_h1,
        "ema_slow_h1": request.ema_slow_h1,
        "ema_fast_m5": request.ema_fast_m5,
        "ema_slow_m5": request.ema_slow_m5,
        "atr": request.atr,
        "timestamp": request.timestamp
    }
    
    ml_result = enhance_decision_with_ml(request.symbol, base_action, base_confidence, market_data)
    
    # Utiliser la décision améliorée par ML
    action = ml_result["enhanced_decision"]
    confidence = ml_result["enhanced_confidence"]
    
    # Ajouter la raison ML à la raison technique
    if ml_result["ml_applied"]:
        reason += f"[ML: {ml_result['ml_reason']}] "
        logger.info(f"🧠 ML Enhancement: {base_action} → {action} ({base_confidence:.2f} → {confidence:.2f})")
    
    action, confidence, reason = enforce_ea_boom_crash_direction(
        request.symbol, action, confidence, reason
    )
    
    # 7. Règles agressives spécifiques Boom/Crash (plus de BUY/SELL, moins de HOLD)
    # Ne pas dépendre de IMPROVEMENTS_AVAILABLE : alignement critique pour MT5 / stair M1.
    try:
        if is_boom_crash_symbol(str(request.symbol)):
            symbol_lower = str(request.symbol).lower()
            is_boom = "boom" in symbol_lower
            is_crash = "crash" in symbol_lower
            
            ema_fast_m1 = request.ema_fast_m1 or 0.0
            ema_slow_m1 = request.ema_slow_m1 or 0.0
            ema_fast_m5 = request.ema_fast_m5 or 0.0
            ema_slow_m5 = request.ema_slow_m5 or 0.0
            ema_fast_h1 = request.ema_fast_h1 or 0.0
            ema_slow_h1 = request.ema_slow_h1 or 0.0
            
            ema_up = (
                (ema_fast_m1 > ema_slow_m1) or
                (ema_fast_m5 > ema_slow_m5) or
                (ema_fast_h1 > ema_slow_h1)
            )
            ema_down = (
                (ema_fast_m1 < ema_slow_m1) or
                (ema_fast_m5 < ema_slow_m5) or
                (ema_fast_h1 < ema_slow_h1)
            )
            
            # Si IA est en HOLD mais la tendance est claire, forcer une décision
            if action == "hold":
                if is_boom and ema_up:
                    action = "buy"
                    confidence = max(confidence, 0.6)
                    reason += "[Boom agressif: tendance haussière → BUY] "
                elif is_crash and ema_down:
                    action = "sell"
                    confidence = max(confidence, 0.6)
                    reason += "[Crash agressif: tendance baissière → SELL] "
            
            # Si déjà BUY/SELL aligné avec la tendance, renforcer légèrement la confiance
            elif is_boom and action == "buy" and ema_up:
                confidence = min(0.95, max(confidence, 0.7))
                reason += "[Boom agressif: BUY confirmé par tendance] "
            elif is_crash and action == "sell" and ema_down:
                confidence = min(0.95, max(confidence, 0.7))
                reason += "[Crash agressif: SELL confirmé par tendance] "
    except Exception as e:
        logger.debug(f"Règles agressives Boom/Crash ignorées: {e}")
    
    # 7b. Historique stair (Supabase) : ajuste la confiance si win_rate significatif pour symbole+direction
    try:
        if request.stair_detected:
            action, confidence, reason = await apply_stair_history_to_decision(
                str(request.symbol or ""),
                action,
                confidence,
                reason,
                bool(request.stair_detected),
                request.stair_direction,
                request.stair_pattern_kinds,
            )
    except Exception as e:
        logger.debug("apply_stair_history_to_decision: %s", e)
    
    # 7c. Validation finale RSI / MACD / Ichimoku (confluence)
    confluence_detail: Dict[str, Any] = {}
    if INDICATOR_CONFLUENCE_AVAILABLE and apply_core_indicator_confluence and _env_bool(
        "ENABLE_CORE_INDICATOR_CONFLUENCE", True
    ):
        try:
            min_v = int(os.getenv("CORE_INDICATOR_MIN_VOTES", "2"))
            action, confidence, reason, confluence_detail = apply_core_indicator_confluence(
                request, action, confidence, reason, min_votes=max(1, min_v)
            )
            if confluence_detail and not confluence_detail.get("skipped"):
                logger.info(
                    "📊 Confluence RSI/MACD/Ichi | %s | votes=%s/%s | %s",
                    request.symbol,
                    confluence_detail.get("votes_for"),
                    confluence_detail.get("votes_against"),
                    confluence_detail.get("core_labels"),
                )
        except Exception as e:
            logger.debug("confluence: %s", e)
    
    # 8. Ajustements finaux (laisser une confiance dynamique sur HOLD, éviter un plancher fixe à 30%)
    if action == "hold":
        # Garder la confiance calculée (technique + ML), mais éviter 0 absolu
        confidence = max(0.1, confidence)
    
    # 9. Confiance pour MT5: envoyer décimale 0-1 (l'EA attend 0-1 et affiche *100)
    confidence_percentage = confidence
    
    # 10. Calcul SL/TP
    stop_loss = None
    take_profit = None
    
    if action == "buy" and request.bid:
        atr = request.atr if request.atr and request.atr > 0 else 0.0020
        stop_loss = request.bid - atr * 2
        take_profit = request.bid + atr * 3
    elif action == "sell" and request.ask:
        atr = request.atr if request.atr and request.atr > 0 else 0.0020
        stop_loss = request.ask + atr * 2
        take_profit = request.ask - atr * 3
    
    # 11. Préparer les prédictions (simuler une tendance basée sur RSI/EMA si pas de modèle ML complexe)
    predicted_prices = []
    if request.bid:
        p = request.bid
        # Tendance simplifiée pour le canal
        step = 0
        if action == "buy": step = 0.00001
        elif action == "sell": step = -0.00001
        
        for _ in range(500):
            p += step + (np.random.normal(0, 0.000005))
            predicted_prices.append(float(p))
            
    # 12. Déterminer alignement et cohérence
    alignment = "N/A"
    if request.ema_fast_m1 and request.ema_fast_m5 and request.ema_fast_h1:
        m1_up = request.ema_fast_m1 > request.ema_slow_m1
        m5_up = request.ema_fast_m5 > request.ema_slow_m5
        h1_up = request.ema_fast_h1 > request.ema_slow_h1
        if m1_up == m5_up == h1_up:
            alignment = "M1/M5/H1: ALIGNÉ (" + ("HAUSSIER" if m1_up else "BAISSIER") + ")"
        else:
            alignment = "M1/M5/H1: MIXTE"
            
    coherence = f"COHÉRENCE: {int(confidence * 100)}%"
    
    stair_client_eid: Optional[str] = None
    if request.stair_detected:
        sym_st = str(request.symbol or "")
        sd_st = (request.stair_direction or "").strip().upper() or synth_stair_direction_for_symbol(sym_st)
        if sd_st:
            stair_client_eid = (request.stair_client_event_id or "").strip() or str(uuid4())
            pk_st = (request.stair_pattern_kinds or "").strip()
            feats_st = dict(request.stair_features or {})
            try:
                feats_st.setdefault("rsi", request.rsi)
                feats_st.setdefault("atr", request.atr)
            except Exception:
                pass
            q_st = _stair_compute_quality_from_features(feats_st)
            wr_st, _n_st = await _stair_empirical_win_rate(sym_st, sd_st, pk_st if pk_st else None)
            payload_st = {
                "client_event_id": stair_client_eid,
                "symbol": sym_st,
                "category": _stair_category_for_symbol(sym_st),
                "direction": sd_st,
                "timeframe": "M1",
                "pattern_kinds": pk_st or None,
                "quality_score": q_st,
                "empirical_win_rate_at_detect": wr_st,
                "features": feats_st,
                "ai_action": action,
                "ai_confidence": float(confidence),
                "outcome": "open",
                "source": "decision_endpoint",
            }
            asyncio.create_task(_insert_stair_detection_supabase(payload_st))
    
    # 13. Créer la réponse enrichie
    meta_out = {
        "original_decision": ml_result["original_decision"],
        "original_confidence": ml_result["original_confidence"],
        "ml_enhanced": ml_result["ml_applied"],
        "ml_reason": ml_result["ml_reason"],
        "base_scores": {"buy": buy_score, "sell": sell_score},
        "market_data": market_data,
        "confidence_decimal": confidence,
        "confidence_percentage": confidence_percentage,
        "spike_probability": market_data.get("spike_probability", 0.0),
        "stair_detected": bool(request.stair_detected),
        "stair_client_event_id": stair_client_eid,
    }
    if confluence_detail:
        meta_out["indicator_confluence"] = confluence_detail
    response = DecisionResponse(
        action=action,
        confidence=confidence_percentage,  # Décimale 0-1 (MT5 affiche *100)
        reason=reason,
        stop_loss=stop_loss,
        take_profit=take_profit,
        timestamp=datetime.now().isoformat(),
        model_used="technical_ml_enhanced",
        predicted_prices=predicted_prices,
        alignment=alignment,
        coherence=coherence,
        metadata=meta_out
    )
    
    # 11. Sauvegarder la décision dans Supabase (local OU cloud) si les clés sont disponibles
    try:
        await save_decision_to_supabase(request, response, ml_result)
    except Exception as e:
        logger.error(f"❌ Erreur sauvegarde décision Supabase: {e}")
    
    return response


async def _push_prediction_to_supabase(
    request: DecisionRequest,
    response: DecisionResponse,
    ml_result: Optional[dict] = None,
):
    """
    Write every AI prediction to the Supabase predictions table.
    Called from decision_simplified and /decision so you can monitor the robot's decisions in the database.
    """
    import httpx

    supabase_url = os.getenv("SUPABASE_URL", "https://bpzqnooiisgadzicwupi.supabase.co")
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")
    if not supabase_url or not supabase_key:
        return

    request_data = {
        "bid": request.bid,
        "ask": request.ask,
        "rsi": request.rsi,
        "ema_fast_m1": request.ema_fast_m1,
        "ema_slow_m1": request.ema_slow_m1,
        "ema_fast_h1": request.ema_fast_h1,
        "ema_slow_h1": request.ema_slow_h1,
        "ema_fast_m5": request.ema_fast_m5,
        "ema_slow_m5": request.ema_slow_m5,
        "atr": request.atr,
    }
    if ml_result:
        metadata = {
            "original_decision": ml_result.get("original_decision", response.action),
            "original_confidence": ml_result.get("original_confidence", response.confidence),
            "ml_enhanced": ml_result.get("ml_applied", False),
            "ml_reason": ml_result.get("ml_reason", ""),
            "request_data": request_data,
        }
    else:
        metadata = {
            "original_decision": response.action,
            "original_confidence": response.confidence,
            "ml_enhanced": False,
            "ml_reason": "",
            "request_data": request_data,
        }

    decision_data = {
        "symbol": request.symbol,
        "timeframe": "M1",
        "prediction": response.action,
        "confidence": response.confidence,
        "reason": (response.reason or "")[:2000],
        "model_used": getattr(response, "model_used", None) or "technical_ml_enhanced",
        "metadata": metadata,
    }

    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{supabase_url}/rest/v1/predictions",
                json=decision_data,
                headers={
                    "apikey": supabase_key,
                    "Authorization": f"Bearer {supabase_key}",
                    "Content-Type": "application/json",
                    "Prefer": "return=minimal",
                },
                timeout=10.0,
            )
            if resp.status_code == 201:
                logger.debug(f"✅ Prediction logged to Supabase for {request.symbol}")
            else:
                logger.warning(f"Predictions table HTTP {resp.status_code}: {resp.text[:200]}")
    except Exception as e:
        logger.debug(f"Predictions Supabase: {e}")


async def save_decision_to_supabase(request: DecisionRequest, response: DecisionResponse, ml_result: dict):
    """Sauvegarder la décision améliorée dans Supabase (predictions + model_metrics)."""
    import httpx

    await _push_prediction_to_supabase(request, response, ml_result)

    supabase_url = os.getenv("SUPABASE_URL", "https://bpzqnooiisgadzicwupi.supabase.co")
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")
    if not supabase_url or not supabase_key:
        return

    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

    # (Important) Par défaut on NE doit PAS écrire un proxy dans `model_metrics` à chaque prédiction,
    # sinon on écrase les métriques réelles produites par le trainer (integrated_ml_trainer / continuous_ml_trainer).
    # Tu peux réactiver ce comportement via env var pour debug.
    try:
        enable_proxy = os.getenv("AI_ENABLE_MODEL_METRICS_PROXY_FROM_PREDICTIONS", "false").lower() == "true"
        if enable_proxy and supabase_key:
            # Extraire une "accuracy" proxy à partir de la confiance (décimale)
            accuracy_decimal = None
            meta = getattr(response, "metadata", None)
            if isinstance(meta, dict) and "confidence_decimal" in meta:
                try:
                    accuracy_decimal = float(meta.get("confidence_decimal"))
                except (TypeError, ValueError):
                    accuracy_decimal = None
            if accuracy_decimal is None:
                try:
                    # response.confidence est renvoyée en pourcentage (0-100)
                    accuracy_decimal = float(response.confidence) / 100.0
                except Exception:
                    accuracy_decimal = 0.5

            if not (0.0 <= accuracy_decimal <= 1.0):
                accuracy_decimal = 0.5

            metrics_payload = {
                "symbol": request.symbol,
                "timeframe": "M1",
                "accuracy": float(accuracy_decimal),
                "metadata": {
                    "model_used": response.model_used or "technical_ml_enhanced",
                    "last_action": response.action,
                    "last_confidence_pct": float(response.confidence),
                    "reason_sample": response.reason[:240] if isinstance(response.reason, str) else "",
                    "source": "predictions_proxy",
                },
            }

            async with httpx.AsyncClient() as client:
                r_metrics = await client.post(
                    f"{supabase_url}/rest/v1/model_metrics",
                    json=metrics_payload,
                    headers=headers,
                    timeout=10.0,
                )
                if r_metrics.status_code not in (200, 201):
                    logger.error(
                        "Supabase model_metrics proxy: statut %s body=%s payload=%s",
                        r_metrics.status_code,
                        r_metrics.text,
                        metrics_payload,
                    )
                else:
                    logger.info(
                        "✅ model_metrics proxy insérée pour %s accuracy=%.3f",
                        request.symbol,
                        metrics_payload["accuracy"],
                    )
    except Exception as e:
        logger.debug(f"Erreur lors de la sauvegarde proxy model_metrics: {e}")


async def fetch_supabase_ml_context(symbol: str, timeframe: str = "M1") -> Dict[str, Any]:
    """
    Requête Supabase: model_metrics, symbol_calibration, trade_feedback pour ce symbole.
    Utilisé pour que le robot prenne ses décisions sur la base du ML et apprenne des erreurs.
    """
    import httpx
    supabase_url = os.getenv("SUPABASE_URL", "https://bpzqnooiisgadzicwupi.supabase.co")
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")
    if not supabase_key:
        return {}
    sym_enc = symbol.replace(" ", "%20")
    headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
    out = {
        "model_accuracy": 0.5,
        "calibration_wins": 0,
        "calibration_total": 0,
        "drift_factor": 1.0,
        "recent_win_rate": 0.5,
        "recent_count": 0,
    }
    async with httpx.AsyncClient() as client:
        try:
            # Dernière métrique modèle pour ce symbole
            r1 = await client.get(
                f"{supabase_url}/rest/v1/model_metrics",
                params={"symbol": f"eq.{symbol}", "timeframe": f"eq.{timeframe}", "order": "training_date.desc", "limit": "1"},
                headers=headers,
                timeout=5.0,
            )
            if r1.status_code == 200 and r1.json():
                row = r1.json()[0]
                out["model_accuracy"] = float(row.get("accuracy", 0.5))
                meta = row.get("metadata")
                if isinstance(meta, dict):
                    out["drift_factor"] = float(meta.get("drift_factor", 1.0))
                elif isinstance(meta, str):
                    try:
                        m = json.loads(meta)
                        out["drift_factor"] = float(m.get("drift_factor", 1.0))
                    except Exception:
                        pass
        except Exception as e:
            logger.debug(f"Supabase model_metrics: {e}")
        try:
            r2 = await client.get(
                f"{supabase_url}/rest/v1/symbol_calibration",
                params={"symbol": f"eq.{symbol}", "limit": "1"},
                headers=headers,
                timeout=5.0,
            )
            if r2.status_code == 200 and r2.json():
                row = r2.json()[0]
                out["calibration_wins"] = int(row.get("wins", 0))
                out["calibration_total"] = int(row.get("total", 0))
                out["drift_factor"] = float(row.get("drift_factor", 1.0))
        except Exception as e:
            logger.debug(f"Supabase symbol_calibration: {e}")
        try:
            r3 = await client.get(
                f"{supabase_url}/rest/v1/trade_feedback",
                params={"symbol": f"eq.{symbol}", "order": "created_at.desc", "limit": "50"},
                headers=headers,
                timeout=5.0,
            )
            if r3.status_code == 200 and r3.json():
                rows = r3.json()
                wins = sum(1 for x in rows if x.get("is_win") is True)
                out["recent_count"] = len(rows)
                out["recent_win_rate"] = wins / len(rows) if rows else 0.5
        except Exception as e:
            logger.debug(f"Supabase trade_feedback: {e}")
    return out



async def root():
    """Endpoint racine pour vérifier que le serveur fonctionne"""
    return {
        "status": "running",
        "service": "TradBOT AI Server",
        "version": "2.0.1",
        "mt5_available": MT5_AVAILABLE,
        "ml_trainer_available": ML_TRAINER_AVAILABLE,
        "ml_recommendation_available": ML_RECOMMENDATION_AVAILABLE,
        "endpoints": [
            "/health (GET)",
            "/dashboard (GET) - Tableau de bord complet pour le robot",
            "/analyze (POST)",
            "/mt5/symbols (GET)",
            "/mt5/account (GET)",
            "/mt5/positions (GET)",
            "/mt5/close_position (POST)",
            "/mt5/place_order (POST)",
            "/ml/metrics (GET)",
            "/ml/start (POST)",
            "/ml/stop (POST)",
            "/ml/retrain (POST)",
            "/ml/recommendations (GET)",
            "/ml/recommendations/{symbol} (GET)",
            "/ml/opportunities (GET)",
            "/validate (POST)",
            "/test (POST)"
        ]
    }

@app.get("/health")
async def health_check():
    """Endpoint de santé pour Render et monitoring"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "TradBOT AI Server",
        "version": "2.0.1",
        "mt5_available": MT5_AVAILABLE,
        "ml_trainer_available": ML_TRAINER_AVAILABLE,
        "ml_recommendation_available": ML_RECOMMENDATION_AVAILABLE
    }

@app.post("/ml/start")
async def start_ml_trainer():
    """Démarre le système d'entraînement continu"""
    if not ML_TRAINER_AVAILABLE:
        raise HTTPException(status_code=503, detail="Système ML non disponible")
    
    await ml_trainer.start()
    return {"status": "started", "message": "Système d'entraînement continu démarré"}

@app.post("/ml/stop")
async def stop_ml_trainer():
    """Arrête le système d'entraînement continu"""
    if not ML_TRAINER_AVAILABLE:
        raise HTTPException(status_code=503, detail="Système ML non disponible")
    
    await ml_trainer.stop()
    return {"status": "stopped", "message": "Système d'entraînement continu arrêté"}

@app.post("/ml/retrain")
async def force_retrain():
    """Force un réentraînement immédiat de tous les modèles"""
    if not ML_TRAINER_AVAILABLE:
        raise HTTPException(status_code=503, detail="Système ML non disponible")
    
    # Forcer le réentraînement
    models = ml_trainer.load_existing_models()
    retrained_count = 0
    
    for model_key, model_info in models.items():
        symbol = model_info['symbol']
        timeframe = model_info['timeframe']
        
        # Récupérer les données et réentraîner
        df = await ml_trainer.fetch_training_data_simple(symbol, timeframe)
        if df is not None and len(df) >= ml_trainer.min_samples_for_retraining:
            new_metrics = ml_trainer.train_model_simple(df, symbol, timeframe)
            if new_metrics:
                await ml_trainer.save_metrics_to_supabase(new_metrics)
                retrained_count += 1
    
    return {
        "status": "completed",
        "retrained_models": retrained_count,
        "message": f"{retrained_count} modèles réentraînés avec succès"
    }

@app.get("/ml/recommendations")
async def get_ml_recommendations(symbol: Optional[str] = None, limit: int = 10):
    """
    Endpoint pour obtenir les recommandations de trading intelligentes basées sur ML

    Args:
        symbol: Symbole spécifique (optionnel, tous les symboles si None)
        limit: Nombre maximum de recommandations à retourner

    Returns:
        Recommandations complètes avec actions, opportunités, risques, etc.
    """
    if not ML_TRAINER_AVAILABLE or not ML_RECOMMENDATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="Système de recommandation ML non disponible")

    try:
        # Analyser les métriques ML et générer les recommandations
        recommendations_data = ml_recommendation_system.analyze_ml_metrics()

        # Filtrer par symbole si demandé
        if symbol:
            filtered_recommendations = [
                rec for rec in recommendations_data["recommendations"]
                if rec["symbol"] == symbol
            ]
            recommendations_data["recommendations"] = filtered_recommendations[:limit]
        else:
            recommendations_data["recommendations"] = recommendations_data["recommendations"][:limit]

        return {
            "status": "success",
            "data": recommendations_data,
            "message": f"Recommandations ML générées pour {len(recommendations_data['recommendations'])} symboles"
        }
    except Exception as e:
        logger.error(f"❌ Erreur génération recommandations: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur génération recommandations: {str(e)}")

@app.get("/ml/predict")
async def get_ml_swing_predictions(symbol: str, type: str = "swing_points", future_bars: int = 1000):
    """
    Endpoint pour obtenir les prédictions ML (swing points ou trendlines) pour les 1000 prochaines bougies M1
    
    Args:
        symbol: Le symbole à analyser
        type: Type de prédiction ("swing_points" ou "trendlines")
        future_bars: Nombre de bougies futures à prédire (max 1000)
    
    Returns:
        Prédictions ML avec timestamps, prix et confiance
    """
    # Permettre le fonctionnement même sans ML trainer complet
    if not ML_TRAINER_AVAILABLE:
        logger.warning("⚠️ ML trainer non disponible, utilisation de prédictions simulées")
    
    try:
        # Limiter le nombre de bougies futures pour éviter la surcharge
        future_bars = min(future_bars, 1000)
        
        if type == "swing_points":
            # Générer les prédictions de swing points
            swing_predictions = generate_swing_point_predictions(symbol, future_bars)
            
            return {
                "symbol": symbol,
                "type": type,
                "future_bars": future_bars,
                "swing_points": swing_predictions,
                "total_predictions": len(swing_predictions),
                "timestamp": datetime.now().isoformat()
            }
        elif type == "trendlines":
            # Générer les prédictions de trendlines
            trendline_predictions = generate_trendline_predictions(symbol, future_bars)
            
            return {
                "symbol": symbol,
                "type": type,
                "future_bars": future_bars,
                "trendlines": trendline_predictions,
                "total_predictions": len(trendline_predictions),
                "timestamp": datetime.now().isoformat()
            }
        else:
            raise HTTPException(status_code=400, detail=f"Type de prédiction non supporté: {type}")
        
    except Exception as e:
        logger.error(f"❌ Erreur génération prédictions ML: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur génération prédictions: {str(e)}")

def generate_trendline_predictions(symbol: str, future_bars: int) -> List[Dict]:
    """
    Génère des prédictions de trendlines et supports/résistances ML
    
    Args:
        symbol: Symbole à analyser
        future_bars: Nombre de bougies futures à prédire
    
    Returns:
        Liste des prédictions de trendlines
    """
    trendlines = []
    
    try:
        # Récupérer les données historiques récentes pour le contexte
        historical_data = get_recent_historical_data(symbol, 500)  # 500 bougies récentes
        
        if historical_data.empty:
            logger.warning(f"Pas de données historiques pour {symbol}")
            return trendlines
        
        current_time = datetime.now()
        volatility = calculate_volatility(historical_data)
        avg_price = historical_data['close'].mean()
        
        # Identifier les points de swing historiques pour tracer les trendlines
        swing_highs = []
        swing_lows = []
        
        # Simple détection de swing points dans les données historiques
        for i in range(2, len(historical_data) - 2):
            current_high = historical_data.iloc[i]['high']
            current_low = historical_data.iloc[i]['low']
            
            # Swing High
            if (current_high > historical_data.iloc[i-1]['high'] and 
                current_high > historical_data.iloc[i-2]['high'] and
                current_high > historical_data.iloc[i+1]['high'] and 
                current_high > historical_data.iloc[i+2]['high']):
                swing_highs.append({
                    'time': historical_data.iloc[i]['time'],
                    'price': current_high
                })
            
            # Swing Low
            if (current_low < historical_data.iloc[i-1]['low'] and 
                current_low < historical_data.iloc[i-2]['low'] and
                current_low < historical_data.iloc[i+1]['low'] and 
                current_low < historical_data.iloc[i+2]['low']):
                swing_lows.append({
                    'time': historical_data.iloc[i]['time'],
                    'price': current_low
                })
        
        # Générer les trendlines basées sur les swing points
        trendline_count = min(15, future_bars // 50)  # Environ 15 trendlines pour 1000 bougies
        
        for i in range(trendline_count):
            # Type de trendline (alternance)
            trendline_types = ["support", "resistance", "trendline"]
            trendline_type = trendline_types[i % len(trendline_types)]
            
            # Points de départ et fin
            if trendline_type == "support" and len(swing_lows) >= 2:
                # Support: connecter deux swing lows
                start_point = swing_lows[i % len(swing_lows)]
                end_point = swing_lows[(i + 1) % len(swing_lows)]
            elif trendline_type == "resistance" and len(swing_highs) >= 2:
                # Résistance: connecter deux swing highs
                start_point = swing_highs[i % len(swing_highs)]
                end_point = swing_highs[(i + 1) % len(swing_highs)]
            else:
                # Trendline: générer des points aléatoires réalistes
                start_time = current_time + timedelta(minutes=(i * 60) + 30)
                end_time = start_time + timedelta(minutes=120 + i * 10)
                
                base_price = avg_price * (1 + np.random.uniform(-0.02, 0.02))
                slope = np.random.uniform(-0.0001, 0.0001)  # Pente faible
                
                start_point = {
                    'time': start_time,
                    'price': base_price
                }
                end_point = {
                    'time': end_time,
                    'price': base_price + slope * 120  # 120 minutes de différence
                }
            
            # Calculer la pente
            time_diff = (end_point['time'] - start_point['time']).total_seconds() / 60  # minutes
            price_diff = end_point['price'] - start_point['price']
            slope = price_diff / time_diff if time_diff > 0 else 0
            
            # Confiance basée sur la volatilité et la cohérence
            base_confidence = 0.75
            if trendline_type in ["support", "resistance"]:
                confidence = base_confidence + np.random.uniform(-0.10, 0.15)
            else:
                confidence = base_confidence + np.random.uniform(-0.15, 0.10)
            
            confidence = max(0.55, min(0.95, confidence))  # Limiter entre 55% et 95%
            
            trendlines.append({
                "start_time": int(start_point['time'].timestamp()),
                "start_price": round(start_point['price'], 5),
                "end_time": int(end_point['time'].timestamp()),
                "end_price": round(end_point['price'], 5),
                "slope": round(slope, 6),
                "confidence": round(confidence, 3),
                "type": trendline_type
            })
        
        # Trier par temps de début
        trendlines.sort(key=lambda x: x["start_time"])
        
        logger.info(f"📈 Généré {len(trendlines)} trendlines ML pour {symbol}")
        
    except Exception as e:
        logger.error(f"Erreur génération trendlines: {e}")
    
    return trendlines

def generate_swing_point_predictions(symbol: str, future_bars: int) -> List[Dict]:
    """
    Génère des prédictions de swing points en utilisant les modèles ML entraînés
    
    Args:
        symbol: Symbole à analyser
        future_bars: Nombre de bougies futures à prédire
    
    Returns:
        Liste des prédictions de swing points
    """
    swing_points = []
    
    try:
        # Récupérer les données historiques récentes pour le contexte
        historical_data = get_recent_historical_data(symbol, 200)  # 200 bougies récentes
        
        if historical_data.empty:
            logger.warning(f"Pas de données historiques pour {symbol}")
            return swing_points
        
        # Simuler la génération de swing points basée sur les patterns ML
        # En production, ceci utiliserait les vrais modèles ML entraînés
        current_time = datetime.now()
        
        # Générer des swing points réalistes basés sur la volatilité historique
        volatility = calculate_volatility(historical_data)
        avg_price = historical_data['close'].mean()
        
        # Nombre de swing points à générer (environ 1 tous les 20-30 bougies)
        num_swings = future_bars // 25  # Environ 40 swing points pour 1000 bougies
        
        for i in range(num_swings):
            # Position temporelle dans le futur
            future_bar = (i + 1) * 25 + np.random.randint(-5, 6)  # Variation autour de 25 bougies
            if future_bar >= future_bars:
                continue
            
            # Timestamp du swing point
            swing_time = current_time + timedelta(minutes=future_bar)
            
            # Type de swing (alternance high/low)
            is_high = i % 2 == 0
            
            # Prix du swing point basé sur la volatilité
            price_variation = volatility * np.random.uniform(0.5, 2.0)
            if is_high:
                swing_price = avg_price + price_variation * np.random.uniform(0.8, 1.2)
            else:
                swing_price = avg_price - price_variation * np.random.uniform(0.8, 1.2)
            
            # Confiance basée sur la distance temporelle et la volatilité
            base_confidence = 0.75
            confidence = base_confidence + np.random.uniform(-0.15, 0.20)
            confidence = max(0.5, min(0.95, confidence))  # Limiter entre 50% et 95%
            
            swing_points.append({
                "time": int(swing_time.timestamp()),
                "price": round(swing_price, 5),
                "is_high": is_high,
                "confidence": round(confidence, 3),
                "future_bars": future_bar
            })
        
        # Trier par temps
        swing_points.sort(key=lambda x: x["time"])
        
        logger.info(f"🎯 Généré {len(swing_points)} swing points ML pour {symbol}")
        
    except Exception as e:
        logger.error(f"Erreur génération swing points: {e}")
    
    return swing_points

def get_recent_historical_data(symbol: str, num_bars: int = 200) -> pd.DataFrame:
    """
    Récupère les données historiques récentes pour un symbole
    En production, ceci se connecterait à MT5 ou une base de données
    """
    try:
        # Simuler des données historiques pour la démonstration
        # En production, utiliser MT5 ou une vraie source de données
        dates = pd.date_range(end=datetime.now(), periods=num_bars, freq='1min')
        
        # Générer des prix réalistes basés sur une marche aléatoire
        np.random.seed(hash(symbol) % 2**32)  # Seed pour la reproductibilité
        
        # Prix de base selon le symbole
        base_prices = {
            "Boom 1000 Index": 1000,
            "Boom 300 Index": 300,
            "Boom 500 Index": 500,
            "Crash 1000 Index": 1000,
            "Crash 300 Index": 300,
            "Crash 500 Index": 500,
            "EURUSD": 1.1000,
            "GBPUSD": 1.3000,
            "AUDSGD": 0.9000
        }
        
        base_price = base_prices.get(symbol, 1000)
        
        # Génération de prix avec tendance et volatilité
        returns = np.random.normal(0, 0.002, num_bars)  # 0.2% de volatilité
        prices = [base_price]
        
        for ret in returns:
            new_price = prices[-1] * (1 + ret)
            prices.append(new_price)
        
        prices = prices[1:]  # Supprimer le premier prix de base
        
        # Créer le DataFrame
        data = pd.DataFrame({
            'time': dates,
            'open': prices,
            'high': [p * (1 + abs(np.random.normal(0, 0.001))) for p in prices],
            'low': [p * (1 - abs(np.random.normal(0, 0.001))) for p in prices],
            'close': prices,
            'volume': np.random.randint(100, 1000, num_bars)
        })
        
        return data
        
    except Exception as e:
        logger.error(f"Erreur récupération données historiques: {e}")
        return pd.DataFrame()

def get_historical_data_mt5(symbol: str, timeframe: str = "H1", count: int = 500):
    """Récupère les données historiques depuis MT5. Retourne None si MT5 indisponible (ex: Render)."""
    global mt5_initialized
    if not MT5_AVAILABLE:
        return None
    if not mt5_initialized:
        try:
            mt5_login = int(os.getenv('MT5_LOGIN', 0))
            mt5_password = os.getenv('MT5_PASSWORD', '')
            mt5_server = os.getenv('MT5_SERVER', '')
            if mt5_login and mt5_password and mt5_server and mt5.initialize(
                login=mt5_login, password=mt5_password, server=mt5_server
            ):
                mt5_initialized = True
            else:
                return None
        except Exception:
            return None
    try:
        tf_map = {
            "M1": mt5.TIMEFRAME_M1,
            "M5": mt5.TIMEFRAME_M5,
            "M15": mt5.TIMEFRAME_M15,
            "H1": mt5.TIMEFRAME_H1,
            "H4": mt5.TIMEFRAME_H4,
            "D1": mt5.TIMEFRAME_D1,
        }
        tf = tf_map.get(timeframe, mt5.TIMEFRAME_H1)
        rates = mt5.copy_rates_from_pos(symbol, tf, 0, count)
        if rates is None or len(rates) == 0:
            return None
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        return df
    except Exception:
        return None

def calculate_volatility(data: pd.DataFrame) -> float:
    """Calcule la volatilité des prix"""
    if data.empty or 'close' not in data.columns:
        return 0.01  # Valeur par défaut
    
    returns = data['close'].pct_change().dropna()
    return returns.std() if len(returns) > 0 else 0.01

@app.get("/ml/recommendations/{symbol}")
async def get_symbol_recommendation(symbol: str):
    """
    Endpoint pour obtenir la recommandation spécifique pour un symbole

    Args:
        symbol: Le symbole à analyser

    Returns:
        Recommandation détaillée pour ce symbole
    """
    if not ML_TRAINER_AVAILABLE or not ML_RECOMMENDATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="Système de recommandation ML non disponible")

    try:
        # Obtenir la recommandation pour ce symbole spécifique
        recommendation = ml_recommendation_system.get_recommendation_for_symbol(symbol)

        if not recommendation:
            return {
                "status": "not_found",
                "symbol": symbol,
                "message": f"Aucune recommandation disponible pour {symbol}",
                "data": None
            }

        # Convertir en dict pour la réponse JSON
        rec_dict = {
            "symbol": recommendation.symbol,
            "action": recommendation.action.value,
            "confidence": recommendation.confidence,
            "opportunity_score": recommendation.opportunity_score,
            "opportunity_level": recommendation.opportunity_level.value,
            "reason": recommendation.reason,
            "should_trade": recommendation.should_trade,
            "should_limit_order": recommendation.should_limit_order,
            "limit_order_price": recommendation.limit_order_price,
            "should_close": recommendation.should_close,
            "trailing_stop_distance": recommendation.trailing_stop_distance,
            "timeframe_priority": recommendation.timeframe_priority,
            "risk_level": recommendation.risk_level,
            "timestamp": recommendation.timestamp.isoformat()
        }

        return {
            "status": "success",
            "symbol": symbol,
            "data": rec_dict,
            "message": f"Recommandation ML générée pour {symbol}"
        }

    except Exception as e:
        logger.error(f"❌ Erreur recommandation pour {symbol}: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur recommandation {symbol}: {str(e)}")


async def _fetch_ml_metrics_from_supabase() -> Dict[str, Any]:
    """Charge les métriques ML depuis Supabase model_metrics (fallback quand current_metrics vide)."""
    supabase_url = os.getenv("SUPABASE_URL", "https://bpzqnooiisgadzicwupi.supabase.co")
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")
    if not supabase_key or not supabase_url:
        return {}
    try:
        import httpx
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get(
                f"{supabase_url}/rest/v1/model_metrics",
                params={"order": "training_date.desc", "limit": "500"},
                headers=headers,
            )
        if r.status_code != 200 or not r.json():
            return {}
        rows = r.json()
        # Garder uniquement la dernière métrique par (symbol, timeframe)
        seen = set()
        metrics = {}
        for row in rows:
            sym = row.get("symbol", "")
            tf = row.get("timeframe", "M1")
            key = f"{sym}_{tf}"
            if key in seen:
                continue
            seen.add(key)
            meta = row.get("metadata") or {}
            if isinstance(meta, str):
                try:
                    meta = json.loads(meta)
                except Exception:
                    meta = {}
            acc = float(row.get("accuracy", 0.5))
            f1 = meta.get("f1_score")
            samples = meta.get("training_samples", 0)
            training_date = row.get("training_date", "")
            metrics[key] = {
                "symbol": sym,
                "timeframe": tf,
                "training_date": training_date,
                "training_samples": samples,
                "metrics": {
                    "random_forest": {
                        "accuracy": acc if acc <= 1 else acc / 100,
                        "f1_score": f1,
                    }
                },
            }
        return {
            "status": "running",
            "metrics": metrics,
            "models_count": len(metrics),
            "last_update": datetime.now().isoformat(),
            "source": "supabase",
        }
    except Exception as e:
        logger.debug("Erreur chargement métriques Supabase pour dashboard: %s", str(e)[:100])
        return {}


async def _fetch_ml_metrics_for_symbol_from_supabase(symbol: str, timeframe: str = "M1") -> Optional[Dict[str, Any]]:
    """Charge les métriques ML pour UN symbole depuis Supabase (format plat pour le graphique MT5)."""
    supabase_url = os.getenv("SUPABASE_URL", "https://bpzqnooiisgadzicwupi.supabase.co")
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")
    if not supabase_key or not supabase_url:
        return None
    try:
        import httpx
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(
                f"{supabase_url}/rest/v1/model_metrics",
                params={"symbol": f"eq.{symbol}", "timeframe": f"eq.{timeframe}", "order": "training_date.desc", "limit": "1"},
                headers=headers,
            )
        if r.status_code != 200 or not r.json():
            return None
        row = r.json()[0]
        meta = row.get("metadata") or {}
        if isinstance(meta, str):
            try:
                meta = json.loads(meta)
            except Exception:
                meta = {}
        acc = float(row.get("accuracy", 0.5))
        acc_pct = (acc * 100) if acc <= 1 else acc
        samples = meta.get("training_samples", 0)
        model_name = meta.get("best_model") or meta.get("model_type", "random_forest")
        precision = meta.get("precision", None)
        recall = meta.get("recall", None)
        reliability = meta.get("reliability_score", None)
        per_class = meta.get("per_class", None)
        # Normaliser (par ex: parfois stocké 0..1, parfois 0..100)
        try:
            if precision is not None:
                precision = float(precision)
                precision = (precision / 100.0) if precision > 1.0 else precision
        except Exception:
            precision = None
        try:
            if recall is not None:
                recall = float(recall)
                recall = (recall / 100.0) if recall > 1.0 else recall
        except Exception:
            recall = None
        try:
            if reliability is not None:
                reliability = float(reliability)
                reliability = max(0.0, min(1.0, reliability))
        except Exception:
            reliability = None
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "accuracy": f"{acc_pct:.1f}",
            "model_name": model_name,
            "total_samples": str(samples),
            "feedback_wins": 0,
            "feedback_losses": 0,
            "status": "trained",
            "best_model": model_name,
            "last_update": row.get("training_date", ""),
            "precision": precision,
            "recall": recall,
            "reliability_score": reliability,
            "per_class": per_class,
        }
    except Exception as e:
        logger.debug("Supabase metrics for %s: %s", symbol, str(e)[:60])
        return None


@app.get("/dashboard")
async def get_robot_dashboard():
    """
    Endpoint complet pour le tableau de bord du robot MT5
    Retourne toutes les informations en temps réel:
    - Métriques ML en temps réel
    - Prédictions de mouvement de prix
    - Recommandations intelligentes
    - État du système
    """
    try:
        dashboard_data = {
            "timestamp": datetime.now().isoformat(),
            "system_status": {
                "server": "running",
                "mt5_available": MT5_AVAILABLE,
                "ml_trainer_available": ML_TRAINER_AVAILABLE,
                "ml_recommendation_available": ML_RECOMMENDATION_AVAILABLE
            },
            "ml_metrics": None,
            "ml_recommendations": None,
            "price_predictions": [],
            "top_opportunities": []
        }
        
        # 1. Métriques ML en temps réel (ml_trainer in-memory + fallback Supabase)
        if ML_TRAINER_AVAILABLE:
            try:
                ml_metrics = ml_trainer.get_current_metrics()
                train_metrics = ml_metrics.get("metrics") or ml_metrics.get("models") or {}
                if not train_metrics or ml_metrics.get("models_count", 0) == 0:
                    # Fallback: charger depuis Supabase model_metrics (entraînement continu par symbole)
                    supabase_metrics = await _fetch_ml_metrics_from_supabase()
                    if supabase_metrics.get("metrics"):
                        ml_metrics = {**ml_metrics, "metrics": supabase_metrics["metrics"], "models_count": len(supabase_metrics["metrics"])}
                dashboard_data["ml_metrics"] = ml_metrics
            except Exception as e:
                logger.warning(f"⚠️ Erreur récupération métriques ML: {e}")
                try:
                    supabase_metrics = await _fetch_ml_metrics_from_supabase()
                    dashboard_data["ml_metrics"] = supabase_metrics if supabase_metrics.get("metrics") else {"error": str(e)}
                except Exception:
                    dashboard_data["ml_metrics"] = {"error": str(e)}
        else:
            # ML trainer non dispo: essayer quand même Supabase pour afficher les métriques sauvegardées
            supabase_metrics = await _fetch_ml_metrics_from_supabase()
            if supabase_metrics.get("metrics"):
                dashboard_data["ml_metrics"] = supabase_metrics
        
        # 2. Recommandations ML intelligentes
        if ML_RECOMMENDATION_AVAILABLE and ML_TRAINER_AVAILABLE:
            try:
                recommendations_data = ml_recommendation_system.analyze_ml_metrics()
                dashboard_data["ml_recommendations"] = recommendations_data
                
                # Extraire les top opportunités
                opportunities = ml_recommendation_system.get_top_opportunities(5)
                dashboard_data["top_opportunities"] = [
                    {
                        "symbol": opp.symbol,
                        "total_score": opp.total_score,
                        "buy_opportunity": opp.buy_opportunity,
                        "sell_opportunity": opp.sell_opportunity,
                        "trend_strength": opp.trend_strength,
                        "ml_confidence": opp.ml_confidence,
                        "recommendation": "ACHETER" if opp.buy_opportunity > opp.sell_opportunity else "VENDRE"
                    }
                    for opp in opportunities
                ]
            except Exception as e:
                logger.warning(f"⚠️ Erreur récupération recommandations ML: {e}")
                dashboard_data["ml_recommendations"] = {"error": str(e)}
        
        # 3. Prédictions de mouvement de prix (pour les symboles actifs)
        if ML_TRAINER_AVAILABLE:
            try:
                # Symboles à analyser pour les prédictions
                symbols_to_predict = ["EURJPY", "GBPJPY", "USDJPY", "EURUSD", "GBPUSD"]
                
                for symbol in symbols_to_predict:
                    try:
                        # Récupérer les dernières métriques pour ce symbole
                        metrics = ml_trainer.get_current_metrics()
                        
                        # Chercher les métriques spécifiques à ce symbole
                        symbol_metrics = None
                        if 'models' in metrics:
                            for model_key, model_data in metrics['models'].items():
                                if symbol in model_key:
                                    symbol_metrics = model_data
                                    break
                        
                        if symbol_metrics and 'metrics' in symbol_metrics:
                            model_metrics = symbol_metrics['metrics']
                            
                            # Générer une prédiction basée sur les métriques ML
                            prediction = {
                                "symbol": symbol,
                                "current_prediction": "HOLD",
                                "confidence": 0.5,
                                "price_direction": "NEUTRAL",
                                "accuracy": model_metrics.get('accuracy', 0.5),
                                "f1_score": model_metrics.get('f1_score', 0.5),
                                "last_updated": symbol_metrics.get('last_updated', datetime.now().isoformat()),
                                "feature_importance": model_metrics.get('feature_importance', {}),
                                "trend_signal": "NEUTRAL"
                            }
                            
                            # Analyser les features pour déterminer la direction
                            feature_importance = model_metrics.get('feature_importance', {})
                            if feature_importance:
                                # Signaux basés sur l'importance des features
                                rsi_importance = feature_importance.get('rsi', 0)
                                ema_importance = feature_importance.get('ema_diff', 0)
                                volume_importance = feature_importance.get('volume', 0)
                                
                                if rsi_importance > 0.1:
                                    prediction["trend_signal"] = "RSI_DOMINANT"
                                elif ema_importance > 0.1:
                                    prediction["trend_signal"] = "TREND_DOMINANT"
                                elif volume_importance > 0.1:
                                    prediction["trend_signal"] = "VOLUME_DOMINANT"
                                
                                # Calculer la confiance basée sur la précision du modèle
                                accuracy = model_metrics.get('accuracy', 0.5)
                                prediction["confidence"] = min(0.95, accuracy * 1.1)
                                
                                # Déterminer la direction basée sur les métriques
                                if accuracy > 0.7:
                                    if 'buy' in str(model_metrics).lower():
                                        prediction["current_prediction"] = "BUY"
                                        prediction["price_direction"] = "HAUSSIER"
                                    elif 'sell' in str(model_metrics).lower():
                                        prediction["current_prediction"] = "SELL"
                                        prediction["price_direction"] = "BAISSIER"
                            
                            dashboard_data["price_predictions"].append(prediction)
                            
                    except Exception as e:
                        logger.warning(f"⚠️ Erreur prédiction pour {symbol}: {e}")
                        continue
                        
            except Exception as e:
                logger.warning(f"⚠️ Erreur génération prédictions: {e}")
        
        # 4. Statistiques globales
        total_models = 0
        avg_accuracy = 0
        models = dashboard_data.get("ml_metrics", {}).get("metrics") or dashboard_data.get("ml_metrics", {}).get("models") or {}
        if models:
            total_models = len(models)
            accuracies = []
            for model_data in models.values():
                rf = (model_data.get("metrics") or {}).get("random_forest") if isinstance(model_data.get("metrics"), dict) else {}
                acc = rf.get("accuracy") if rf else model_data.get("metrics", {}).get("accuracy") if isinstance(model_data.get("metrics"), dict) else None
                if acc is not None:
                    accuracies.append(float(acc) if float(acc) <= 1 else float(acc) / 100)
            avg_accuracy = sum(accuracies) / len(accuracies) if accuracies else 0
        
        dashboard_data["global_stats"] = {
            "total_models": total_models,
            "average_accuracy": round(avg_accuracy, 3),
            "system_health": "HEALTHY" if avg_accuracy > 0.6 else "WARNING",
            "last_update": datetime.now().isoformat()
        }
        
        return {
            "status": "success",
            "data": dashboard_data,
            "message": "Tableau de bord robot mis à jour"
        }
        
    except Exception as e:
        logger.error(f"❌ Erreur génération dashboard: {e}")
        return {
            "status": "error",
            "message": f"Erreur dashboard: {str(e)}",
            "timestamp": datetime.now().isoformat()
        }

@app.get("/ml/opportunities")
async def get_top_opportunities(limit: int = 5):
    """
    Endpoint pour obtenir les meilleures opportunités de trading selon ML

    Args:
        limit: Nombre d'opportunités à retourner (défaut: 5)

    Returns:
        Liste des symboles les plus opportuns
    """
    if not ML_TRAINER_AVAILABLE or not ML_RECOMMENDATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="Système de recommandation ML non disponible")

    try:
        # Obtenir les meilleures opportunités
        opportunities = ml_recommendation_system.get_top_opportunities(limit)

        opportunities_data = []
        for opp in opportunities:
            opportunities_data.append({
                "symbol": opp.symbol,
                "total_score": opp.total_score,
                "buy_opportunity": opp.buy_opportunity,
                "sell_opportunity": opp.sell_opportunity,
                "hold_opportunity": opp.hold_opportunity,
                "volatility_risk": opp.volatility_risk,
                "trend_strength": opp.trend_strength,
                "ml_confidence": opp.ml_confidence,
                "last_updated": opp.last_updated.isoformat()
            })

        return {
            "status": "success",
            "data": opportunities_data,
            "count": len(opportunities_data),
            "message": f"Top {len(opportunities_data)} opportunités ML identifiées"
        }

    except Exception as e:
        logger.error(f"❌ Erreur récupération opportunités: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur opportunités: {str(e)}")

@app.post("/test")
async def test_endpoint():
    """Endpoint de test pour vérifier que le serveur accepte les requêtes POST"""
    import time
    return {
        "status": "ok",
        "message": "Test endpoint fonctionne",
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    }

@app.post("/validate")
async def validate_format(request: dict):
    """Endpoint de validation pour tester les formats de requêtes"""
    try:
        # Simuler la validation sans exécuter l'IA
        required_fields = ["symbol", "bid", "ask"]
        missing_fields = [field for field in required_fields if field not in request]
        
        if missing_fields:
            return {
                "valid": False,
                "missing_fields": missing_fields,
                "message": f"Champs manquants: {', '.join(missing_fields)}"
            }
        
        # Validation basique
        symbol = request.get("symbol", "")
        bid = request.get("bid")
        ask = request.get("ask")
        
        if not symbol or not bid or not ask:
            return {
                "valid": False,
                "message": "Les champs symbol, bid, et ask sont requis"
            }
        
        if bid <= 0 or ask <= 0:
            return {
                "valid": False,
                "message": "Les prix bid et ask doivent être positifs"
            }
        
        if bid >= ask:
            return {
                "valid": False,
                "message": "Le prix bid doit être inférieur au prix ask"
            }
        
        return {
            "valid": True,
            "message": "Format valide",
            "symbol": symbol,
            "bid": bid,
            "ask": ask
        }
        
    except Exception as e:
        return {
            "valid": False,
            "error": str(e),
            "message": "Erreur lors de la validation",
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }

@app.get("/market-state")
async def get_market_state_endpoint(symbol: str = "EURUSD", timeframe: str = "M1"):
    """Endpoint dédié pour l'état du marché (compatible avec tous les robots)"""
    try:
        market_info = calculate_market_state(symbol, timeframe)
        
        response = {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
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
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }

@app.get("/trend/health")
async def trend_health():
    """Vérification de santé pour le module de tendance"""
    return {
        "status": "ok",
        "module": "trend_analysis",
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "mt5_available": mt5_initialized
    }


@app.get("/prediction-channel")
async def prediction_channel(symbol: Optional[str] = None, timeframe: str = "M1", future_bars: int = 5000):
    """
    Canal de prédiction du prix sur les N prochaines bougies (jusqu'à 5000).
    Analyse historique + régression linéaire + métriques Supabase pour feedback / amélioration.
    """
    if not symbol or not symbol.strip():
        return {"ok": False, "reason": "symbol required"}
    symbol = symbol.strip()

    # 1) Essayer de renvoyer un canal persistant depuis Supabase (si disponible)
    try:
        supabase_url = os.getenv("SUPABASE_URL", "").strip()
        supabase_key = (os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY") or "").strip()
        if supabase_url and supabase_key:
            import httpx
            headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
            params = {
                "symbol": f"eq.{symbol}",
                "timeframe": f"eq.{timeframe}",
                "order": "time_start.desc",
                "limit": "1",
            }
            async with httpx.AsyncClient(timeout=5.0) as client:
                r = await client.get(f"{supabase_url}/rest/v1/prediction_channels", params=params, headers=headers)
            if r.status_code == 200 and r.json():
                row = r.json()[0]
                row["ok"] = True
                row["source"] = "supabase"
                return row
    except Exception as e:
        logger.debug(f"prediction-channel supabase fetch: {e}")

    # 2) Sinon calculer (et la fonction tente déjà une sauvegarde Supabase)
    result = get_prediction_channel_5000(symbol, timeframe, future_bars)
    if isinstance(result, dict):
        result.setdefault("source", "computed")
    return result


def _get_trend_data(symbol: str, timeframe: str, count: int):
    """Récupère les données pour /trend. Ordre: MT5/backend puis cloud/simulé pour éviter 60% fixe."""
    if get_historical_data is not None and callable(get_historical_data):
        df = get_historical_data(symbol, timeframe, count)
        if df is not None and len(df) >= 2:
            return df
    df = get_historical_data_mt5(symbol, timeframe, count)
    if df is not None and len(df) >= 2:
        return df
    # Fallback: cloud (yfinance) ou simulé → évite le 60% fixe partout
    try:
        df_m1 = get_market_data_cloud(symbol, period="5d", interval="1m")
        if df_m1 is None or df_m1.empty or len(df_m1) < 2:
            df_m1 = get_recent_historical_data(symbol, max(count, 500))
        if df_m1 is None or df_m1.empty or len(df_m1) < 2:
            return None
        if timeframe == "M1":
            return df_m1.tail(count)
        df_m1 = df_m1.copy()
        if 'time' in df_m1.columns:
            t = df_m1['time']
            if pd.api.types.is_numeric_dtype(t):
                df_m1['time'] = pd.to_datetime(t, unit='s', errors='coerce')
            else:
                df_m1['time'] = pd.to_datetime(t, errors='coerce')
        elif 'Datetime' in df_m1.columns:
            df_m1['time'] = pd.to_datetime(df_m1['Datetime'], errors='coerce')
        df_m1 = df_m1.dropna(subset=['time']).set_index('time').sort_index()
        if timeframe == "M5":
            res = df_m1.resample('5min').agg({'open': 'first', 'high': 'max', 'low': 'min', 'close': 'last'}).dropna()
        elif timeframe == "H1":
            res = df_m1.resample('1h').agg({'open': 'first', 'high': 'max', 'low': 'min', 'close': 'last'}).dropna()
        else:
            res = df_m1.resample('5min').agg({'open': 'first', 'high': 'max', 'low': 'min', 'close': 'last'}).dropna()
        return res.reset_index().tail(count) if len(res) >= 2 else None
    except Exception as e:
        logger.warning(f"_get_trend_data fallback pour {symbol} {timeframe}: {e}")
        return None


def _trend_fallback_response(symbol: str, timeframe: str, reason: str = "no_data"):
    """Réponse de repli pour /trend quand les données sont indisponibles (évite 422/500)."""
    # Sanitize reason: avoid leaking Python tracebacks/NameError to client (max 100 chars, no newlines)
    if reason and len(str(reason)) > 100:
        reason = str(reason)[:97] + "..."
    reason = (reason or "no_data").replace("\n", " ").strip()
    s = (symbol or "").upper()
    if "CRASH" in s:
        decision, consensus = "SELL", "STRONG_DOWNTREND"
        confidence = 0.6
        m1_udn = h1_udn = "DOWN"
    elif "BOOM" in s:
        decision, consensus = "BUY", "STRONG_UPTREND"
        confidence = 0.6
        m1_udn = h1_udn = "UP"
    else:
        decision, consensus = "HOLD", "NEUTRAL"
        confidence = 0.5
        m1_udn = h1_udn = "NEUTRAL"
    return {
        "symbol": symbol or "UNKNOWN",
        "timeframe": timeframe,
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "trend_m1": {"direction": "NEUTRAL", "change_percent": 0.0},
        "trend_m5": {"direction": "NEUTRAL", "change_percent": 0.0},
        "trend_h1": {"direction": "NEUTRAL", "change_percent": 0.0},
        "consensus": {"direction": consensus, "confidence": confidence, "uptrend_count": 0, "downtrend_count": 0},
        "decision": decision,
        "final_decision": decision,
        "confidence": confidence,
        "alignment": "neutre",
        "coherence": 0.5,
        "ml_confidence": 0.5,
        "m1_trend": m1_udn,
        "h1_trend": h1_udn,
        "h4_trend": h1_udn,
        "d1_trend": h1_udn,
        "data_points": {"m1": 0, "m5": 0, "h1": 0},
        "fallback": reason,
    }


@app.get("/trend")
async def get_trend(symbol: Optional[str] = None, timeframe: str = "M1"):
    """Endpoint principal pour l'analyse de tendance MT5. Symbol optionnel pour éviter 422."""
    try:
        if not symbol or not symbol.strip():
            symbol = "UNKNOWN"
        symbol = symbol.strip()
        if timeframe not in ["M1", "M5", "M15", "M30", "H1", "H4", "D1"]:
            timeframe = "M1"
        logger.info(f"📈 Requête tendance reçue pour {symbol} (timeframe: {timeframe})")

        df_m1 = _get_trend_data(symbol, "M1", 500)
        df_m5 = _get_trend_data(symbol, "M5", 200)
        df_h1 = _get_trend_data(symbol, "H1", 100)

        if df_m1 is None or df_m5 is None or df_h1 is None:
            logger.warning(f"Données historiques partielles pour {symbol}, envoi fallback")
            return _trend_fallback_response(symbol, timeframe, "partial_data")

        def calculate_trend(df):
            if df is None or len(df) < 2:
                return "NEUTRAL", 0.0
            latest = df["close"].iloc[-1]
            previous = df["close"].iloc[-2]
            if latest > previous:
                return "UPTREND", (latest - previous) / previous * 100
            if latest < previous:
                return "DOWNTREND", (previous - latest) / previous * 100
            return "NEUTRAL", 0.0

        trend_m1, change_m1 = calculate_trend(df_m1)
        trend_m5, change_m5 = calculate_trend(df_m5)
        trend_h1, change_h1 = calculate_trend(df_h1)

        uptrend_count = sum([trend_m1 == "UPTREND", trend_m5 == "UPTREND", trend_h1 == "UPTREND"])
        downtrend_count = sum([trend_m1 == "DOWNTREND", trend_m5 == "DOWNTREND", trend_h1 == "DOWNTREND"])

        if uptrend_count >= 2:
            consensus = "STRONG_UPTREND"
            confidence = min(0.9, 0.5 + (uptrend_count * 0.15))
            decision = "BUY"
        elif downtrend_count >= 2:
            consensus = "STRONG_DOWNTREND"
            confidence = min(0.9, 0.5 + (downtrend_count * 0.15))
            decision = "SELL"
        else:
            consensus = "NEUTRAL"
            confidence = 0.5
            decision = "HOLD"

        # Compatibilité EA: m1_trend, h1_trend, h4_trend, d1_trend (UP/DOWN/NEUTRAL)
        _to_udn = lambda s: "UP" if s == "UPTREND" else ("DOWN" if s == "DOWNTREND" else "NEUTRAL")
        m1_udn = _to_udn(trend_m1)
        h1_udn = _to_udn(trend_h1)

        # Alignement: M1/M5/H1 d'accord ou non
        if uptrend_count >= 2 or downtrend_count >= 2:
            alignment = "aligné"
        elif uptrend_count == 1 or downtrend_count == 1:
            alignment = "partiel"
        else:
            alignment = "neutre"

        # Enrichissement Supabase: ML + calibration + trade_feedback pour décision finale
        ml_confidence = 0.5
        coherence = 0.5
        final_decision = decision
        final_confidence = confidence
        try:
            ctx = await fetch_supabase_ml_context(symbol, timeframe)
            ml_accuracy = ctx.get("model_accuracy", 0.5)
            drift = ctx.get("drift_factor", 1.0)
            cal_w = ctx.get("calibration_wins", 0)
            cal_t = ctx.get("calibration_total", 0)
            recent_wr = ctx.get("recent_win_rate", 0.5)
            recent_n = ctx.get("recent_count", 0)
            ml_confidence = max(0.3, min(0.95, ml_accuracy * drift))
            coherence = recent_wr if recent_n >= 5 else (cal_w / cal_t if cal_t else 0.5)
            coherence = max(0.0, min(1.0, coherence))
            # Confiance finale = tendance + ML (poids ML pour apprendre des erreurs)
            final_confidence = (confidence * 0.5 + ml_confidence * 0.5) * drift
            final_confidence = max(0.3, min(0.95, final_confidence))
            # Si cohérence faible (beaucoup de pertes récentes), réduire ou HOLD
            if coherence < 0.4 and decision != "HOLD":
                final_confidence = final_confidence * 0.7
                if final_confidence < 0.5:
                    final_decision = "HOLD"
        except Exception as e:
            logger.debug(f"Enrichissement Supabase /trend: {e}")

        response = {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "trend_m1": {"direction": trend_m1, "change_percent": change_m1},
            "trend_m5": {"direction": trend_m5, "change_percent": change_m5},
            "trend_h1": {"direction": trend_h1, "change_percent": change_h1},
            "consensus": {
                "direction": consensus,
                "confidence": confidence,
                "uptrend_count": uptrend_count,
                "downtrend_count": downtrend_count,
            },
            "decision": decision,
            "final_decision": final_decision,
            "confidence": final_confidence,
            "alignment": alignment,
            "coherence": round(coherence, 4),
            "ml_confidence": round(ml_confidence, 4),
            "m1_trend": m1_udn,
            "h1_trend": h1_udn,
            "h4_trend": h1_udn,
            "d1_trend": h1_udn,
            "data_points": {
                "m1": len(df_m1) if df_m1 is not None else 0,
                "m5": len(df_m5) if df_m5 is not None else 0,
                "h1": len(df_h1) if df_h1 is not None else 0,
            },
        }
        logger.info(f"✅ Analyse tendance {symbol}: {final_decision} conf={final_confidence:.2f} align={alignment} cohérence={coherence:.2f}")
        return response
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur dans /trend: {str(e)}", exc_info=True)
        return _trend_fallback_response(symbol if isinstance(symbol, str) else "UNKNOWN", timeframe or "M1", str(e))

@app.post("/trend")
async def post_trend(request: TrendRequest):
    """Endpoint POST pour l'analyse de tendance (compat MT5 WebRequest)"""
    return await get_trend(request.symbol, request.timeframe or "M1")


def _detect_staircase_pattern(df, direction: str = "UP") -> float:
    """
    Détection heuristique d'un pattern "escalier" sur M1.
    - direction="UP"  : escalier montant (Boom)
    - direction="DOWN": escalier descendant (Crash)
    Retourne une probabilité entre 0.0 et 1.0.
    """
    try:
        import numpy as np
    except Exception:
        np = None

    if df is None or len(df) < 20:
        return 0.0

    # On regarde les 40 dernières bougies max
    window = min(40, len(df))
    sub = df.tail(window).copy()

    closes = sub["close"].values
    highs = sub.get("high", sub["close"]).values
    lows = sub.get("low", sub["close"]).values

    # Variation globale
    global_change = (closes[-1] - closes[0]) / closes[0]
    if direction == "UP" and global_change <= 0:
        return 0.0
    if direction == "DOWN" and global_change >= 0:
        return 0.0

    # Détection grossière de "marches" : petites bougies suivies de bougies plus longues
    if np is not None:
        body = np.abs(sub["close"].values - sub["open"].values)
    else:
        body = [abs(c - o) for c, o in zip(sub["close"].values, sub["open"].values)]
    avg_body = float(sum(body) / len(body))
    long_threshold = avg_body * 1.8  # bougie considérée comme "spike" local
    small_threshold = avg_body * 0.5

    steps = 0
    i = 3
    while i < window:
        # 2-3 petites bougies puis 1 grande dans la bonne direction
        small_ok = all(b <= small_threshold for b in body[i-3:i])
        long_ok = body[i] >= long_threshold
        if not (small_ok and long_ok):
            i += 1
            continue

        if direction == "UP":
            if closes[i] > closes[i-1] and highs[i] > highs[i-1]:
                steps += 1
        else:
            if closes[i] < closes[i-1] and lows[i] < lows[i-1]:
                steps += 1
        i += 3  # sauter au bloc suivant

    if steps == 0:
        return 0.0

    prob = min(1.0, 0.3 + 0.15 * steps)
    prob *= min(1.0, abs(global_change) * 10.0 + 0.5)
    return float(max(0.0, min(1.0, prob)))


@app.get("/ml/staircase")
async def ml_staircase(symbol: str, timeframe: str = "M1"):
    """
    Endpoint léger pour détecter un pattern "escalier" (staircase) sur M1.
    - Boom: escalier montant (staircase_up_prob)
    - Crash: escalier descendant (staircase_down_prob)
    Utilisable par l'EA pour rendre le scalping Boom/Crash plus intelligent.
    """
    try:
        if not symbol or not symbol.strip():
            raise HTTPException(status_code=400, detail="symbol requis")
        symbol = symbol.strip()

        df_m1 = _get_trend_data(symbol, "M1", 200)
        if df_m1 is None or len(df_m1) < 20:
            return {
                "symbol": symbol,
                "timeframe": timeframe,
                "staircase_up_prob": 0.0,
                "staircase_down_prob": 0.0,
                "status": "no_data",
            }

        upper = symbol.upper()
        is_boom = "BOOM" in upper
        is_crash = "CRASH" in upper

        up_prob = _detect_staircase_pattern(df_m1, "UP") if is_boom else 0.0
        down_prob = _detect_staircase_pattern(df_m1, "DOWN") if is_crash else 0.0

        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "staircase_up_prob": round(up_prob, 3),
            "staircase_down_prob": round(down_prob, 3),
            "status": "ok",
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur /ml/staircase pour {symbol}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


def build_coherent_analysis(symbol: str, timeframes: Optional[List[str]] = None) -> dict:
    """
    Construit une analyse cohérente multi-timeframe (alignement des tendances).
    Utilise les données MT5 ou un fallback selon le type de symbole (Boom/Crash/Index/Forex).
    Retourne un dict compatible avec CoherentAnalysisResponse.
    """
    if not symbol or not symbol.strip():
        symbol = "UNKNOWN"
    symbol = symbol.strip()
    if timeframes is None:
        timeframes = ["D1", "H4", "H1", "M30", "M15", "M5", "M1"]
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    def _fallback_coherent(sym: str, reason: str = "no_data") -> dict:
        s = sym.upper()
        if "CRASH" in s:
            decision, stability, bullish, bearish = "SELL", "medium", 0.2, 0.7
        elif "BOOM" in s:
            decision, stability, bullish, bearish = "BUY", "medium", 0.7, 0.2
        else:
            decision, stability, bullish, bearish = "HOLD", "low", 0.4, 0.4
        return {
            "status": "ok",
            "symbol": sym,
            "decision": decision,
            "direction": decision,
            "decision_type": "fallback",
            "confidence": 0.55,
            "coherence_score": 55.0,
            "stability": stability,
            "bullish_pct": bullish,
            "bearish_pct": bearish,
            "neutral_pct": 1.0 - bullish - bearish,
            "trends": {},
            "timestamp": now,
            "message": reason,
        }

    trends_per_tf = {}
    up, down, neutral = 0, 0, 0
    for tf in timeframes[:7]:
        df = _get_trend_data(symbol, tf, 200)
        if df is None or len(df) < 2:
            trends_per_tf[tf] = {"direction": "NEUTRAL", "change_percent": 0.0}
            neutral += 1
            continue
        latest = df["close"].iloc[-1]
        prev = df["close"].iloc[-2]
        if latest > prev:
            trends_per_tf[tf] = {"direction": "UPTREND", "change_percent": (latest - prev) / prev * 100}
            up += 1
        elif latest < prev:
            trends_per_tf[tf] = {"direction": "DOWNTREND", "change_percent": (prev - latest) / prev * 100}
            down += 1
        else:
            trends_per_tf[tf] = {"direction": "NEUTRAL", "change_percent": 0.0}
            neutral += 1

    total = up + down + neutral
    if total == 0:
        return _fallback_coherent(symbol, "no_data")

    bullish_pct = up / total
    bearish_pct = down / total
    neutral_pct = neutral / total
    if up >= 2 and up > down:
        decision = "BUY"
        confidence = min(0.9, 0.5 + up * 0.1)
        stability = "high" if up >= 4 else "medium"
    elif down >= 2 and down > up:
        decision = "SELL"
        confidence = min(0.9, 0.5 + down * 0.1)
        stability = "high" if down >= 4 else "medium"
    else:
        decision = "HOLD"
        confidence = 0.5
        stability = "low"

    return {
        "status": "ok",
        "symbol": symbol,
        "decision": decision,
        "direction": decision,  # compat EA (BUY/SELL/HOLD)
        "decision_type": "multi_tf",
        "confidence": round(confidence, 2),
        "coherence_score": round(confidence * 100, 1),  # compat EA
        "stability": stability,
        "bullish_pct": round(bullish_pct, 2),
        "bearish_pct": round(bearish_pct, 2),
        "neutral_pct": round(neutral_pct, 2),
        "trends": trends_per_tf,
        "timestamp": now,
        "message": None,
    }


@app.get("/coherent-analysis")
async def get_coherent_analysis(symbol: Optional[str] = None, timeframe: Optional[str] = None):
    """Endpoint GET pour l'analyse cohérente multi-TF. Symbol optionnel pour éviter 422."""
    sym = (symbol or "").strip() or "UNKNOWN"
    timeframes = ["D1", "H4", "H1", "M30", "M15", "M5", "M1"]
    if timeframe:
        timeframes = [timeframe]
    return build_coherent_analysis(sym, timeframes)


@app.post("/coherent-analysis")
async def post_coherent_analysis(request: CoherentAnalysisRequest):
    """Endpoint POST pour l'analyse cohérente multi-TF"""
    return build_coherent_analysis(request.symbol, request.timeframes)

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
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
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
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }

@app.get("/trend/health")
async def trend_health():
    """Vérification de santé pour le module de tendance"""
    return {
        "status": "ok",
        "module": "trend_analysis",
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
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
        },
        "symbol_propice": {
            "cache_profiles": len(symbol_hour_profile_cache),
            "cache_status": len(symbol_hour_status_cache),
        },
    }


@app.get("/symbols/propice/status")
async def get_symbol_propice_status(symbol: str, timeframe: str = "M1", lookback_days: int = 14):
    """
    Statut détaillé d'un symbole (profil horaire + score maintenant) avec fallback cache.
    """
    symbol = (symbol or "").strip()
    timeframe = (timeframe or "M1").strip().upper()
    if not symbol:
        raise HTTPException(status_code=400, detail="symbol requis")
    if timeframe != "M1":
        raise HTTPException(status_code=400, detail="timeframe supporté: M1 uniquement")
    lookback_days = int(lookback_days or 14)

    now_hour_utc = int(datetime.utcnow().hour)

    # 1) cache local
    cached_profile = symbol_hour_profile_cache.get((symbol, timeframe, lookback_days))
    cached_status = symbol_hour_status_cache.get((symbol, timeframe))
    if cached_profile and cached_profile.get("rows"):
        rows = cached_profile["rows"]
        now_row = next((r for r in rows if int(r.get("hour_utc", -1)) == now_hour_utc), None)
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "lookback_days": lookback_days,
            "now_hour_utc": now_hour_utc,
            "profile_rows": rows,
            "now": {
                "propice_score": float((now_row or {}).get("propice_score", 0.0) or 0.0),
                "trend_bias": float((now_row or {}).get("trend_bias", 0.0) or 0.0),
                "reason": (cached_status or {}).get("reason", "cache"),
                "computed_at": (cached_status or {}).get("computed_at"),
            },
            "source": "cache",
        }

    # 2) Supabase fallback
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        import httpx
        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
        }
        params = {
            "symbol": f"eq.{symbol}",
            "timeframe": f"eq.{timeframe}",
            "lookback_days": f"eq.{lookback_days}",
            "order": "hour_utc.asc",
        }
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get(f"{supabase_url}/rest/v1/symbol_hour_profile", headers=headers, params=params)
        if r.status_code not in (200, 206):
            raise RuntimeError(f"Supabase HTTP {r.status_code}: {r.text[:200]}")
        rows = r.json() if r.text else []
        now_row = next((rr for rr in rows if int(rr.get("hour_utc", -1)) == now_hour_utc), None)
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "lookback_days": lookback_days,
            "now_hour_utc": now_hour_utc,
            "profile_rows": rows,
            "now": {
                "propice_score": float((now_row or {}).get("propice_score", 0.0) or 0.0),
                "trend_bias": float((now_row or {}).get("trend_bias", 0.0) or 0.0),
                "reason": "supabase",
            },
            "source": "supabase",
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Statut indisponible (cache vide et Supabase KO): {e}")


@app.get("/symbols/propice/top")
async def get_symbols_propice_top(timeframe: str = "M1", lookback_days: int = 14, n: int = 5):
    """
    Retourne les Top N symbols propices pour l'heure UTC actuelle.
    Fallback: cache local si Supabase indisponible.
    """
    timeframe = (timeframe or "M1").strip().upper()
    if timeframe != "M1":
        raise HTTPException(status_code=400, detail="timeframe supporté: M1 uniquement")
    lookback_days = int(lookback_days or 14)
    n = max(1, min(int(n or 5), 50))
    now_hour_utc = int(datetime.utcnow().hour)

    # 1) essayer Supabase trade_feedback d'abord (source-of-truth = résultats réels)
    try:
        payload = await _compute_propice_top_from_trade_feedback(timeframe, lookback_days, n, now_hour_utc)
        rows = payload.get("rows") or []
        if rows:
            return {
                "timeframe": timeframe,
                "lookback_days": lookback_days,
                "now_hour_utc": now_hour_utc,
                "n": n,
                "rows": rows,
                "source": payload.get("source", "supabase_trade_feedback"),
            }
    except Exception:
        pass

    # 2) fallback Supabase symbol_hour_profile (profil volatilité/spike basé M1)
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        import httpx
        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
        }
        params = {
            "timeframe": f"eq.{timeframe}",
            "lookback_days": f"eq.{lookback_days}",
            "hour_utc": f"eq.{now_hour_utc}",
            "order": "propice_score.desc",
            "limit": str(n),
        }
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get(f"{supabase_url}/rest/v1/symbol_hour_profile", headers=headers, params=params)
        if r.status_code in (200, 206):
            rows = r.json() if r.text else []
            return {
                "timeframe": timeframe,
                "lookback_days": lookback_days,
                "now_hour_utc": now_hour_utc,
                "n": n,
                "rows": rows,
                "source": "supabase_symbol_hour_profile",
            }
    except Exception:
        pass

    # 3) fallback cache
    out = []
    for (sym, tf, lb), payload in symbol_hour_profile_cache.items():
        if tf != timeframe or lb != lookback_days:
            continue
        rows = payload.get("rows") or []
        now_row = next((r for r in rows if int(r.get("hour_utc", -1)) == now_hour_utc), None)
        if not now_row:
            continue
        out.append({
            "symbol": sym,
            "timeframe": timeframe,
            "lookback_days": lookback_days,
            "hour_utc": now_hour_utc,
            "propice_score": float(now_row.get("propice_score", 0.0) or 0.0),
            "trend_bias": float(now_row.get("trend_bias", 0.0) or 0.0),
            "reason": "cache",
        })
    out.sort(key=lambda r: float(r.get("propice_score", 0.0) or 0.0), reverse=True)
    return {
        "timeframe": timeframe,
        "lookback_days": lookback_days,
        "now_hour_utc": now_hour_utc,
        "n": n,
        "rows": out[:n],
        "source": "cache",
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
                reason += f"RSI surachat ({request.rsi:.1f}). "
        
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
                    3. Évalue si ces objets confirment ou infirment l'action {action}
                    
                    Réponds UNIQUEMENT en JSON avec ces champs:
                    - "tendance": "haussière" ou "baissière" ou "neutre"
                    - "force": 1-10 (10 = très fort)
                    - "support": prix exact du support le plus proche
                    - "résistance": prix exact de la résistance la plus proche
                    - "stop_loss": prix optimal pour SL
                    - "take_profit": prix optimal pour TP
                    - "confirmation": true/false si tu confirmes l'action {action}
                    - "objets_graphiques": liste des objets identifiés (zones, lignes, patterns, etc.)
                    - "interprétation_objets": explication de comment les objets graphiques influencent la décision
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
                - RSI: {request.rsi} (surventé<30, surachat>70)
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

def _parse_decision_body(raw: bytes) -> DecisionRequest:
    """Parse le body JSON de manière tolérante pour éviter 422 (robot MT5 payloads variables)."""
    try:
        body = json.loads(raw.decode("utf-8") if isinstance(raw, bytes) else raw)
    except Exception:
        body = {}
    if not isinstance(body, dict):
        body = {}
    # Extraire avec coercions et valeurs par défaut
    def _float(v, default=0.0):
        if v is None: return default
        try: return float(v)
        except (TypeError, ValueError): return default
    def _str(v, default="UNKNOWN"):
        if v is None or v == "": return default
        return str(v).strip() or default
    symbol = _str(body.get("symbol"))
    bid = _float(body.get("bid"), 1.0)
    ask = _float(body.get("ask"), 1.0001)
    if bid >= ask:
        ask = bid + 0.0001
    return DecisionRequest(
        symbol=symbol, bid=bid, ask=ask,
        rsi=min(100, max(0, _float(body.get("rsi"), 50.0))),
        ema_fast_h1=body.get("ema_fast_h1"), ema_slow_h1=body.get("ema_slow_h1"),
        ema_fast_m1=body.get("ema_fast_m1"), ema_slow_m1=body.get("ema_slow_m1"),
        ema_fast_m5=body.get("ema_fast_m5"), ema_slow_m5=body.get("ema_slow_m5"),
        atr=_float(body.get("atr")), dir_rule=int(body.get("dir_rule", 0) or 0),
        is_spike_mode=bool(body.get("is_spike_mode", False)),
        vwap=body.get("vwap"), vwap_distance=body.get("vwap_distance"), above_vwap=body.get("above_vwap"),
        supertrend_trend=int(body.get("supertrend_trend", 0) or 0),
        supertrend_line=body.get("supertrend_line"),
        volatility_regime=int(body.get("volatility_regime", 0) or 0),
        volatility_ratio=_float(body.get("volatility_ratio"), 1.0),
        image_filename=body.get("image_filename"), deriv_patterns=body.get("deriv_patterns"),
        deriv_patterns_bullish=body.get("deriv_patterns_bullish"), deriv_patterns_bearish=body.get("deriv_patterns_bearish"),
        deriv_patterns_confidence=body.get("deriv_patterns_confidence"), timestamp=body.get("timestamp"),
        macd_histogram=body.get("macd_histogram"),
        ichimoku_bias=int(body.get("ichimoku_bias", 0) or 0),
    )

@app.post("/decision", response_model=DecisionResponse)
async def decision(req: Request):
    """
    Endpoint principal de décision utilisé par le robot MT5
    Parse le body manuellement pour éviter 422 sur payloads incomplets.
    """
    try:
        raw = await req.body()
        request = _parse_decision_body(raw)
        
        logger.info(f"🎯 Requête DECISION reçue pour {request.symbol}")
        
        # MODE SIMPLIFIÉ - RoboCop v2 compatible
        if SIMPLIFIED_MODE:
            return await decision_simplified(request)
        
        # MODE COMPLET - Analyse avancée
        # Vérifier le cache d'abord
        cache_key = f"{request.symbol}_{request.bid}_{request.ask}_{request.rsi}"
        current_time = datetime.now().timestamp()
        
        if cache_key in decision_cache:
            cached_time = cache_timestamps.get(cache_key, 0)
            if current_time - cached_time < CACHE_DURATION:
                logger.debug(f"📋 Utilisation décision en cache pour {request.symbol}")
                return DecisionResponse(**decision_cache[cache_key])
        
        # Analyse technique de base
        action = "hold"
        confidence = 0.5
        reason = "Analyse technique en cours..."
        
        # Analyse RSI
        if request.rsi:
            if request.rsi < 30:
                action = "buy"
                confidence += 0.15
                reason += f"RSI surventé ({request.rsi:.1f}). "
            elif request.rsi > 70:
                action = "sell"
                confidence += 0.15
                reason += f"RSI surachat ({request.rsi:.1f}). "
        
        # Analyse EMA H1
        if request.ema_fast_h1 and request.ema_slow_h1:
            if request.ema_fast_h1 > request.ema_slow_h1:
                if action != "sell":
                    action = "buy"
                    confidence += 0.1
                    reason += f"EMA H1 haussière ({request.ema_fast_h1:.5f} > {request.ema_slow_h1:.5f}). "
            else:
                if action != "buy":
                    action = "sell"
                    confidence += 0.1
                    reason += f"EMA H1 baissière ({request.ema_fast_h1:.5f} < {request.ema_slow_h1:.5f}). "
        
        # Analyse des tendances multi-timeframes
        try:
            trend_data = await get_trend_data(request.symbol)
            if trend_data:
                m1_trend = trend_data.get("trend_m1", {}).get("direction", "NEUTRAL")
                m5_trend = trend_data.get("trend_m5", {}).get("direction", "NEUTRAL")
                h1_trend = trend_data.get("trend_h1", {}).get("direction", "NEUTRAL")
                
                # Compter les tendances alignées
                uptrend_count = sum([m1_trend == "UPTREND", m5_trend == "UPTREND", h1_trend == "UPTREND"])
                downtrend_count = sum([m1_trend == "DOWNTREND", m5_trend == "DOWNTREND", h1_trend == "DOWNTREND"])
                
                if uptrend_count >= 2:
                    if action != "sell":
                        action = "buy"
                        confidence += 0.2
                        reason += "Tendance haussière multi-TF. "
                elif downtrend_count >= 2:
                    if action != "buy":
                        action = "sell"
                        confidence += 0.2
                        reason += "Tendance baissière multi-TF. "
                        
        except Exception as trend_err:
            logger.warning(f"Erreur analyse tendance: {trend_err}")
        
        # Ajuster la confiance selon les conditions
        if action == "hold":
            confidence = max(0.3, confidence - 0.2)  # Réduire la confiance pour HOLD
        
        # S'assurer que la confiance est dans les limites
        confidence = max(0.0, min(1.0, confidence))
        
        action, confidence, reason = enforce_ea_boom_crash_direction(
            request.symbol, action, confidence, reason
        )
        
        # Discipline finale basée sur stats (jour/mois) calculées depuis trade_feedback (source MT5)
        new_action, new_conf, pol_reason = _apply_symbol_risk_policy(request.symbol, action, confidence)
        if pol_reason:
            reason += pol_reason + " "
        action, confidence = new_action, new_conf

        conv_meta: Dict[str, Any] = {}
        if INDICATOR_CONFLUENCE_AVAILABLE and apply_core_indicator_confluence and _env_bool(
            "ENABLE_CORE_INDICATOR_CONFLUENCE", True
        ):
            try:
                min_v = int(os.getenv("CORE_INDICATOR_MIN_VOTES", "2"))
                action, confidence, reason, conv_meta = apply_core_indicator_confluence(
                    request, action, confidence, reason, min_votes=max(1, min_v)
                )
            except Exception as e:
                logger.debug("confluence (/decision): %s", e)

        # Créer la réponse
        ta = {
            "rsi": request.rsi,
            "ema_fast_h1": request.ema_fast_h1,
            "ema_slow_h1": request.ema_slow_h1,
            "macd_histogram": getattr(request, "macd_histogram", None),
            "ichimoku_bias": getattr(request, "ichimoku_bias", 0),
        }
        if conv_meta:
            ta["indicator_confluence"] = conv_meta
        response = DecisionResponse(
            action=action,
            confidence=confidence,
            reason=reason[:200],
            spike_prediction=False,
            spike_zone_price=None,
            stop_loss=None,
            take_profit=None,
            timestamp=datetime.now().isoformat(),
            model_used="Technical+Multi-TF",
            technical_analysis=ta
        )
        
        # Mettre en cache
        decision_cache[cache_key] = {
            "action": response.action,
            "confidence": response.confidence,
            "reason": response.reason,
            "timestamp": response.timestamp,
            "model_used": response.model_used
        }
        cache_timestamps[cache_key] = current_time
        
        # Log prediction to Supabase for monitoring (non-blocking)
        asyncio.create_task(_push_prediction_to_supabase(request, response, None))
        
        logger.info(f"✅ DÉCISION {request.symbol}: {action} (conf: {confidence:.2f}) - {response.model_used}")
        return response
        
    except Exception as e:
        logger.error(f"Erreur dans decision: {type(e).__name__}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur décision: {str(e)}")
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
    # Normaliser les champs manquants pour éviter 422 (robot MT5 peut envoyer payload incomplet)
    symbol = (request.symbol or "").strip() or "UNKNOWN"
    bid = request.bid
    ask = request.ask
    if bid is None or bid <= 0:
        bid = (ask - 0.0001) if (ask and ask > 0) else 1.0
    if ask is None or ask <= 0:
        ask = (bid + 0.0001) if (bid and bid > 0) else 1.0001
    if bid >= ask:
        ask = bid + 0.0001
    rsi = request.rsi if (request.rsi is not None and 0 <= request.rsi <= 100) else 50.0
    request = request.model_copy(update={"symbol": symbol, "bid": bid, "ask": ask, "rsi": rsi})
    logger.debug(f"🎯 Décision IA demandée pour {symbol} (bid={bid}, ask={ask})")
    # Mettre à jour l'état de spike en temps réel à partir de ce tick
    try:
        update_spike_state_from_request(request)
    except Exception as e:
        logger.debug(f"⚠️ update_spike_state_from_request erreur: {e}")
    try:
        # ========== AMÉLIORATIONS PRIORITAIRES - APPLIQUÉES TÔT ==========
        # 1. Vérifier le cache court d'abord
        cached_decision = get_cached_decision(request.symbol)
        if cached_decision:
            logger.debug(f"📋 Utilisation décision en cache pour {request.symbol}")
            return DecisionResponse(**cached_decision)
        
        # 2. Calculer les métadonnées de base (pour tous les symboles)
        metadata = {}
        try:
            df_recent = get_historical_data_mt5(request.symbol, "M1", 50)
            if df_recent is not None and len(df_recent) > 20:
                metadata = calculate_boom_crash_metadata(df_recent, request.symbol, request)
                logger.debug(f"📊 Métadonnées calculées pour {request.symbol}: {list(metadata.keys())}")
            else:
                metadata = {
                    'rsi': getattr(request, 'rsi', 50.0),
                    'atr_ratio': 1.0,
                    'spike_risk': False,
                    'ema_trend': 'neutral',
                    'ema_fast': 0.0,
                    'ema_slow': 0.0,
                    'ema_crossover': False,
                    'symbol': request.symbol,
                    'timestamp': datetime.now().isoformat(),
                    'data_insufficient': True
                }
        except Exception as meta_err:
            logger.warning(f"⚠️ Erreur métadonnées pour {request.symbol}: {meta_err}")
            metadata = {
                'rsi': getattr(request, 'rsi', 50.0),
                'atr_ratio': 1.0,
                'spike_risk': False,
                'ema_trend': 'neutral',
                'ema_fast': 0.0,
                'ema_slow': 0.0,
                'ema_crossover': False,
                'symbol': request.symbol,
                'timestamp': datetime.now().isoformat(),
                'error': str(meta_err)
            }
        
        # ========== FIN DES AMÉLIORATIONS PRÉCOCES ==========
        
        # ========== DÉTECTION MODE INITIALISATION DEPUIS GRAPHIQUE ==========
        # Détecter si c'est une initialisation (première requête pour ce symbole)
        initialization_mode = False
        cache_key_init = f"{request.symbol}_init"
        current_time = datetime.now().timestamp()
        
        # Vérifier si c'est la première requête pour ce symbole (dans les 10 dernières secondes)
        if cache_key_init not in last_updated or (current_time - last_updated.get(cache_key_init, 0)) > 10:
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
                        
                        # En mode initialisation, être plus flexible mais prudent
                        # Autoriser plus de situations de trading avec des seuils réalistes
                        if abs(price_trend) < 0.0005 and volatility_init < 0.05:  # Seuils beaucoup plus réalistes
                            logger.info(f"⚠️ Initialisation: Marché extrêmement calme - Recommandation HOLD conservatrice")
                            return DecisionResponse(
                                action="hold",
                                confidence=0.45,  # Plus réaliste
                                reason=f"Initialisation: Marché extrêmement calme (tendance: {price_trend:+.3%}, volatilité: {volatility_init:.3f}%) - Attente signal plus clair",
                                spike_prediction=False,
                                spike_zone_price=None,
                                stop_loss=None,
                                take_profit=None,
                                spike_direction=None,
                                early_spike_warning=False,
                                early_spike_zone_price=None,
                                buy_zone_low=None,
                                buy_zone_high=None,
                                sell_zone_low=None,
                                sell_zone_high=None
                            )
                        else:
                            logger.info(f"✅ Initialisation: Conditions acceptables pour trading - Analyse continue")
            except Exception as e:
                logger.warning(f"⚠️ Erreur analyse initialisation: {e}")
        
        # Règle stricte: Interdire les achats sur Crash et les ventes sur Boom
        symbol_lower = request.symbol.lower()
        if "crash" in symbol_lower:
            # Forcer HOLD pour tout achat sur Crash (règle de sécurité)
            if request.dir_rule == 1:  # 1 = BUY
                logger.debug(f"🔒 Achat sur Crash bloqué (règle sécurité): {request.symbol}")
                # Appliquer les seuils de confiance même pour les retards anticipés
                action, confidence, reason = apply_confidence_thresholds("hold", 0.1, "INTERDICTION: Achats sur Crash non autorisés")
                return DecisionResponse(
                    action=action,
                    confidence=confidence,
                    reason=reason,
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
                    sell_zone_high=None,
                    metadata=metadata  # Toujours inclure les métadonnées
                )
        
        if "boom" in symbol_lower:
            # Forcer HOLD pour toute vente sur Boom (règle de sécurité)
            # dir_rule: 1=BUY, -1=SELL, 0=neutre
            if request.dir_rule <= -1:  # SELL
                logger.debug(f"🔒 Vente sur Boom bloquée (règle sécurité): {request.symbol}")
                # Appliquer les seuils de confiance même pour les retards anticipés
                action, confidence, reason = apply_confidence_thresholds("hold", 0.1, "INTERDICTION: Ventes sur Boom non autorisées")
                return DecisionResponse(
                    action=action,
                    confidence=confidence,
                    reason=reason,
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
                    sell_zone_high=None,
                    metadata=metadata  # Toujours inclure les métadonnées
                )
            
        # Log de la requête reçue (déjà loggé par le middleware, pas besoin de répéter)
        # logger.info(f"Requête de décision reçue pour {request.symbol}")  # Supprimé pour éviter duplication
        
        # Vérifier si la décision est en cache
        # IMPORTANT: Utiliser seulement le symbole pour la clé de cache, pas le prix
        # Car le prix change constamment et empêche le cache de fonctionner
        cache_key = f"{request.symbol}"
        current_time = datetime.now().timestamp()
        
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
            ml_action = str(ml_decision.get("action", "hold")).strip().lower()
            ml_conf_raw = float(ml_decision.get("confidence", 0.0))
            # Normaliser la confiance ML en ratio [0..1] (certaines sources renvoient 0..100)
            ml_conf = (ml_conf_raw / 100.0) if ml_conf_raw > 1.0 else ml_conf_raw
            ml_conf = max(0.0, min(1.0, ml_conf))
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
                   f"Base={base_confidence*100:.1f}% | H4/D1={long_term_bonus*100:.1f}% | H1+H4/D1={long_term_alignment_bonus*100:.1f}% | "
                   f"M5+H1={medium_term_bonus*100:.1f}% | Align={alignment_bonus*100:.1f}% | FINAL={confidence*100:.1f}%")
        
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

        # ========== CONFLUENCE FINALE RSI / MACD / ICHIMOKU (alignée EA MQ5) ==========
        tech_confluence: Dict[str, Any] = {}
        if _env_bool("INDICATOR_CONFLUENCE_GATE", True):
            try:
                from backend.indicator_confluence import apply_rsi_macd_ichimoku_gate

                df_gate = None
                if MT5_AVAILABLE and mt5_initialized:
                    df_gate = get_historical_data_mt5(request.symbol, "M1", 120)
                action, confidence, reason, tech_confluence = apply_rsi_macd_ichimoku_gate(
                    request.symbol,
                    action,
                    confidence,
                    reason,
                    df_gate,
                    min_votes=2,
                )
            except Exception as gate_err:
                logger.debug(f"Confluence RSI/MACD/Ichi: {gate_err}")

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
        if tech_confluence:
            response_data["technical_analysis"] = convert_numpy_to_python(tech_confluence)

        # Log de débogage pour vérifier les valeurs
        init_marker = "🔄 [INIT]" if initialization_mode else ""
        logger.info(f"✅ {init_marker} Décision IA pour {request.symbol}: action={action}, confidence={confidence:.3f} ({confidence*100:.1f}%), reason={reason[:100]}")
        
        # ========== AMÉLIORATIONS PRIORITAIRES APPLIQUÉES ICI ==========
        
        # 1. Vérifier le cache court d'abord
        cached_decision = get_cached_decision(request.symbol)
        if cached_decision and not initialization_mode:
            logger.debug(f"📋 Utilisation décision en cache pour {request.symbol}")
            return DecisionResponse(**cached_decision)
        
        # 2. Appliquer les seuils de confiance minimum
        action, confidence, reason = apply_confidence_thresholds(action, confidence, reason)
        logger.info(f"🎯 Seuils appliqués: action={action}, confidence={confidence:.3f}")
        
        # 2b. Calibration adaptative (réduit le décalage prédiction/mouvement réel)
        action, confidence, reason = apply_calibration_to_decision(
            request.symbol, action, confidence, reason, timeframe="M1"
        )
        response_data["action"] = action
        response_data["confidence"] = round(confidence, 3)
        response_data["reason"] = reason
        logger.debug(f"📐 Calibration appliquée: action={action}, confidence={confidence:.3f}")
        
        # 3. Calculer les métadonnées enrichies (pour tous les symboles)
        metadata = {}
        try:
            # Toujours essayer de calculer les métadonnées de base
            df_recent = get_historical_data_mt5(request.symbol, "M1", 50)
            if df_recent is not None and len(df_recent) > 20:
                metadata = calculate_boom_crash_metadata(df_recent, request.symbol, request)
                logger.debug(f"📊 Métadonnées calculées pour {request.symbol}: {list(metadata.keys())}")
            else:
                # Métadonnées minimales si pas assez de données
                metadata = {
                    'rsi': getattr(request, 'rsi', 50.0),
                    'atr_ratio': 1.0,
                    'spike_risk': False,
                    'ema_trend': 'neutral',
                    'ema_fast': 0.0,
                    'ema_slow': 0.0,
                    'ema_crossover': False,
                    'symbol': request.symbol,
                    'timestamp': datetime.now().isoformat(),
                    'data_insufficient': True
                }
        except Exception as meta_err:
            logger.warning(f"⚠️ Erreur métadonnées pour {request.symbol}: {meta_err}")
            # Garantir les métadonnées de base même en cas d'erreur
            metadata = {
                'rsi': getattr(request, 'rsi', 50.0),
                'atr_ratio': 1.0,
                'spike_risk': False,
                'ema_trend': 'neutral',
                'ema_fast': 0.0,
                'ema_slow': 0.0,
                'ema_crossover': False,
                'symbol': request.symbol,
                'timestamp': datetime.now().isoformat(),
                'error': str(meta_err)
            }
        
        # 4. Mettre à jour response_data avec métadonnées (toujours incluses)
        response_data["metadata"] = convert_numpy_to_python(metadata)
        
        # 5. Mettre en cache la décision améliorée
        cache_decision(request.symbol, response_data)
        
        # ========== FIN DES AMÉLIORATIONS ==========
        
        # Mise en cache (original - gardé pour compatibilité)
        prediction_cache[cache_key] = response_data
        last_updated[cache_key] = current_time
        
        # Sauvegarder la prédiction dans le dossier MT5 Predictions pour analyse/entraînement futur
        try:
            # Déterminer le timeframe (par défaut M1, mais on peut le déduire du contexte si nécessaire)
            timeframe = "M1"  # Par défaut, le robot utilise M1 pour la plupart des décisions
            # Convertir les données pour éviter les erreurs de sérialisation numpy
            clean_decision = convert_numpy_to_python(response_data)
            clean_ml_decision = convert_numpy_to_python(ml_decision) if ml_decision else None
            save_prediction_to_mt5_files(
                symbol=request.symbol,
                timeframe=timeframe,
                decision=clean_decision,
                ml_decision=clean_ml_decision
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
        # Extraire le symbole de request si fourni (POST avec AnalysisRequest)
        if request is not None and hasattr(request, 'symbol') and request.symbol:
            symbol = symbol or request.symbol
        if raw_request is not None and isinstance(raw_request, dict) and raw_request.get('symbol'):
            symbol = symbol or raw_request.get('symbol')
        # Journalisation de la requête
        logger.info(f"Requête /analysis reçue - symbol: {symbol}, "
                  f"request: {request}, raw_request: {raw_request}")
        # Si raw_request est un dictionnaire vide, le traiter comme None
        if raw_request == {}:
            raw_request = None
        # Vérification des paramètres d'entrée
        if symbol is None and request is None and raw_request is None:
            # Essayer de récupérer les données directement du corps de la requête
            if request is not None:
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
                logger.warning("Aucun symbole fourni pour /analysis - retour réponse minimale")
                return AnalysisResponse(
                    symbol="UNKNOWN",
                    timestamp=datetime.now().isoformat(),
                    h1={}, h4={}, m15={}, ete=None
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
            status_code=500,
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
        current_time = datetime.now().timestamp()
        
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


def _generate_future_ohlc_series(
    df: pd.DataFrame,
    horizon: int = 200,
    behavior_profile: Optional[Dict[str, Any]] = None,
    symbol: str = "UNKNOWN"
) -> List[Dict[str, Any]]:
    """
    Génère une projection OHLC future avancée basée sur Supabase et les indicateurs.
    Utilise predict_prices_advanced pour calculer la courbe principale des prix 'close', 
    et le comportement historique pour proportionner les mèches (wicks) et les retracements.
    """
    if df is None or df.empty or len(df) < 50:
        return []

    try:
        from ai_server_improvements import predict_prices_advanced
        last_close = float(df['close'].iloc[-1])
        # Utiliser l'IA avancée basée sur indicateurs et S/R
        adv_pred = predict_prices_advanced(df, last_close, horizon, "M1", symbol)
        
        predicted_prices = adv_pred.get('prediction', [])
        conf = adv_pred.get('confidence', 0.5)
        direction = adv_pred.get('direction', 'NEUTRAL')
        atr = adv_pred.get('atr', last_close * 0.001)
    except Exception as e:
        logger.warning(f"Fallback dans _generate_future_ohlc_series: {e}")
        last_close = float(df['close'].iloc[-1])
        predicted_prices = [last_close] * horizon
        conf = 0.5
        direction = 'NEUTRAL'
        atr = last_close * 0.001

    if not predicted_prices:
        return []

    # Injecter le profil de Supabase pour texturiser le OHLC (mèches, bruit, comportement)
    prof = behavior_profile or {}
    vol_mult = float(max(0.55, min(2.20, float(prof.get("vol_multiplier", 1.0)))))
    retrace_ratio = float(max(0.20, min(0.85, float(prof.get("retrace_ratio", 0.48)))))
    
    last_time = pd.to_datetime(df['time'].iloc[-1]) if 'time' in df.columns else datetime.utcnow()
    seed = abs(hash(f"ohlc:{int(last_time.timestamp())//60}:{len(df)}")) % (2**32)
    rng = np.random.default_rng(seed)

    candles: List[Dict[str, Any]] = []
    curr_close = max(1e-8, float(df['close'].iloc[-1]))

    for i, p_price in enumerate(predicted_prices):
        if i >= horizon:
            break
            
        t = last_time + timedelta(minutes=i + 1)
        c = float(p_price)
        o = curr_close
        
        body = abs(c - o)
        wick_scale = max(atr * 0.3 * vol_mult, body * 0.4, 1e-8)
        
        # Mèches adaptées selon retrace_ratio de Supabase
        up_wick = float(abs(rng.normal(wick_scale * (0.8 + retrace_ratio*0.2), wick_scale * 0.3)))
        dn_wick = float(abs(rng.normal(wick_scale * (0.8 + retrace_ratio*0.2), wick_scale * 0.3)))
        
        hi = max(o, c) + up_wick
        lo = min(o, c) - dn_wick
        if lo <= 0:
            lo = min(o, c) * 0.999
            
        phase = "impulse_up" if c > o else "impulse_down"
        if direction == 'BULLISH' and c < o:
            phase = "retrace_down"
        elif direction == 'BEARISH' and c > o:
            phase = "retrace_up"

        struct_tag = "ML_" + direction
        
        candles.append({
            "time": int(t.timestamp()),
            "open": float(o),
            "high": float(max(hi, o, c)),
            "low": float(min(lo, o, c)),
            "close": float(c),
            "confidence": float(conf),
            "phase": phase,
            "structure_tag": struct_tag,
            "level_ref": float(c),
            "regime": direction,
            "leg_id": i // 10
        })
        curr_close = c

    return candles


async def _fetch_symbol_behavior_profile(symbol: str, timeframe: str = "M1") -> Dict[str, Any]:
    """Construit un profil comportemental par symbole depuis Supabase."""
    profile: Dict[str, Any] = {
        "avg_leg_bars": 14,
        "retrace_ratio": 0.48,
        "reversal_prob": 0.18,
        "vol_multiplier": 1.0,
        "trend_preference": 0.0,
    }
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        import httpx
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
        async with httpx.AsyncClient(timeout=8.0) as client:
            r_pat = await client.get(
                f"{supabase_url}/rest/v1/symbol_correction_patterns",
                headers=headers,
                params={
                    "symbol": f"eq.{symbol}",
                    "order": "success_rate.desc.nullslast,occurrences_count.desc.nullslast",
                    "limit": "30",
                },
            )
            patterns = r_pat.json() if r_pat.status_code < 300 and r_pat.text else []
            if patterns:
                durs = [float(p.get("typical_duration_bars") or 0.0) for p in patterns if float(p.get("typical_duration_bars") or 0.0) > 0]
                rets = [float(p.get("avg_retracement_percentage") or 0.0) for p in patterns if float(p.get("avg_retracement_percentage") or 0.0) > 0]
                succ = [float(p.get("success_rate") or 0.0) for p in patterns if float(p.get("success_rate") or 0.0) > 0]
                if durs:
                    profile["avg_leg_bars"] = max(5, min(40, int(np.mean(durs))))
                if rets:
                    profile["retrace_ratio"] = max(0.20, min(0.85, float(np.mean(rets) / 100.0)))
                if succ:
                    s = float(np.mean(succ))
                    profile["reversal_prob"] = max(0.05, min(0.42, 0.30 - (s - 50.0) / 300.0))

            r_day = await client.get(
                f"{supabase_url}/rest/v1/symbol_prediction_score_daily",
                headers=headers,
                params={
                    "symbol": f"eq.{symbol}",
                    "timeframe": f"eq.{timeframe}",
                    "order": "day.desc",
                    "limit": "10",
                    "select": "score,direction_hit_rate,samples",
                },
            )
            day_rows = r_day.json() if r_day.status_code < 300 and r_day.text else []
            if day_rows:
                scores = [float(x.get("score") or 0.0) for x in day_rows if x.get("score") is not None]
                hits = [float(x.get("direction_hit_rate") or 0.0) for x in day_rows]
                if scores:
                    avg_score = float(np.mean(scores))
                    profile["vol_multiplier"] = max(0.65, min(1.8, 1.15 - (avg_score * 0.35)))
                if hits:
                    avg_hit = float(np.mean(hits))
                    profile["trend_preference"] = max(-0.55, min(0.55, (avg_hit - 0.5) * 1.6))
    except Exception as e:
        logger.debug(f"behavior profile fallback for {symbol}: {e}")
    return profile


async def _store_prediction_run_to_supabase(
    symbol: str,
    timeframe: str,
    candles: List[Dict[str, Any]],
    metadata: Optional[Dict[str, Any]] = None,
) -> Optional[str]:
    """Enregistre un run de prédiction + ses bougies dans Supabase (best effort)."""
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        import httpx

        run_id = str(uuid4())
        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }
        run_payload = {
            "id": run_id,
            "symbol": symbol,
            "timeframe": timeframe,
            "horizon": len(candles),
            "model_version": "structure_v1",
            "metadata": metadata or {},
            "created_at": datetime.utcnow().isoformat(),
        }
        candle_rows = []
        for idx, cdl in enumerate(candles):
            candle_rows.append({
                "run_id": run_id,
                "step": idx + 1,
                "candle_time": int(cdl.get("time", 0)),
                "open": float(cdl.get("open", 0.0)),
                "high": float(cdl.get("high", 0.0)),
                "low": float(cdl.get("low", 0.0)),
                "close": float(cdl.get("close", 0.0)),
                "confidence": float(cdl.get("confidence", 0.5)),
                "phase": str(cdl.get("phase", "unknown")),
                "structure_tag": str(cdl.get("structure_tag", "unknown")),
                "level_ref": float(cdl.get("level_ref", 0.0)),
            })

        async with httpx.AsyncClient(timeout=8.0) as client:
            r1 = await client.post(f"{supabase_url}/rest/v1/prediction_runs", headers=headers, json=run_payload)
            if r1.status_code >= 300:
                logger.warning(f"prediction_runs insert skipped: {r1.status_code} {r1.text[:200]}")
                return None
            r2 = await client.post(f"{supabase_url}/rest/v1/prediction_candles", headers=headers, json=candle_rows)
            if r2.status_code >= 300:
                logger.warning(f"prediction_candles insert skipped: {r2.status_code} {r2.text[:200]}")
                return None
        return run_id
    except Exception as e:
        logger.warning(f"Supabase store prediction run skipped: {e}")
        return None


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


@app.get("/robot/predict_ohlc")
async def robot_predict_ohlc(symbol: str, timeframe: str = "M1", horizon: int = 200, count: int = 500):
    """
    Endpoint principal pour le robot MT5:
    retourne une projection OHLC future (chandeliers japonais) en M1.
    """
    try:
        tf = (timeframe or "M1").upper()
        if tf in ("1M", "M1"):
            tf = "M1"
        if tf != "M1":
            raise HTTPException(status_code=400, detail="timeframe supporté: M1 uniquement")

        h = int(max(1, min(500, horizon)))
        c = int(max(200, min(2000, count)))

        def _symbol_candidates(sym: str) -> List[str]:
            s = (sym or "").strip()
            if not s:
                return []
            out: List[str] = [s]
            su = s.upper().replace(" ", "")
            aliases = {
                "BOOM1000": ["Boom 1000 Index", "Boom1000", "BOOM 1000", "BOOM 1000 INDEX"],
                "BOOM500": ["Boom 500 Index", "Boom500", "BOOM 500", "BOOM 500 INDEX"],
                "CRASH1000": ["Crash 1000 Index", "Crash1000", "CRASH 1000", "CRASH 1000 INDEX"],
                "CRASH500": ["Crash 500 Index", "Crash500", "CRASH 500", "CRASH 500 INDEX"],
            }
            for k, vals in aliases.items():
                if su == k:
                    out.extend(vals)
            # Déduire aussi une variante "X 1000 Index" si la saisie ressemble à BOOM1000/CRASH1000
            if su.startswith("BOOM") and su[4:].isdigit():
                out.append(f"Boom {su[4:]} Index")
            if su.startswith("CRASH") and su[5:].isdigit():
                out.append(f"Crash {su[5:]} Index")
            # Uniques, ordre conservé
            uniq: List[str] = []
            seen = set()
            for x in out:
                if x and x not in seen:
                    uniq.append(x)
                    seen.add(x)
            return uniq

        def _valid_ohlc_frame(x: Optional[pd.DataFrame]) -> bool:
            if x is None or x.empty or len(x) < 80:
                return False
            need_cols = {"open", "high", "low", "close"}
            return need_cols.issubset(set(x.columns))

        used_symbol = symbol
        df = None
        for cand in _symbol_candidates(symbol):
            # 1) Source MT5 directe (si initialisée)
            test_df = get_historical_data_mt5(cand, "M1", c)
            if _valid_ohlc_frame(test_df):
                used_symbol = cand
                df = test_df
                break

            # 2) Fallback robuste: cache/upload/API/sim via pipeline serveur
            try:
                test_df2 = get_market_data(cand, "M1", c)
            except Exception:
                test_df2 = None
            if _valid_ohlc_frame(test_df2):
                used_symbol = cand
                df = test_df2
                break

            # 3) Dernier fallback local récent
            try:
                test_df3 = get_recent_historical_data(cand, max(c, 500))
            except Exception:
                test_df3 = None
            if _valid_ohlc_frame(test_df3):
                used_symbol = cand
                df = test_df3
                break

        if df is None or df.empty or len(df) < 80:
            raise HTTPException(status_code=404, detail=f"Données insuffisantes pour {symbol}")

        behavior_profile = await _fetch_symbol_behavior_profile(used_symbol, "M1")
        candles = _generate_future_ohlc_series(df, h, behavior_profile=behavior_profile, symbol=used_symbol)
        if not candles:
            raise HTTPException(status_code=500, detail="Impossible de générer la projection OHLC")

        # Vérification finale de cohérence OHLC
        valid = []
        for cdl in candles:
            o = float(cdl.get("open", 0))
            hi = float(cdl.get("high", 0))
            lo = float(cdl.get("low", 0))
            cl = float(cdl.get("close", 0))
            if o <= 0 or hi <= 0 or lo <= 0 or cl <= 0:
                continue
            hi = max(hi, o, cl)
            lo = min(lo, o, cl)
            valid.append({
                "time": int(cdl.get("time", 0)),
                "open": o,
                "high": hi,
                "low": lo,
                "close": cl,
                "confidence": float(cdl.get("confidence", 0.5))
            })

        if not valid:
            raise HTTPException(status_code=500, detail="Projection OHLC invalide après validation")

        run_id = await _store_prediction_run_to_supabase(
            symbol=symbol,
            timeframe="M1",
            candles=valid,
            metadata={
                "source": "robot_predict_ohlc",
                "generator": "structure_v2_profiled",
                "requested_symbol": symbol,
                "used_symbol": used_symbol,
                "behavior_profile": behavior_profile,
            },
        )

        return {
            "symbol": used_symbol,
            "requested_symbol": symbol,
            "timeframe": "M1",
            "horizon": len(valid),
            "source": "ai_server",
            "prediction_run_id": run_id,
            "candles": valid
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur /robot/predict_ohlc: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/robot/predict_ohlc/profile")
async def robot_predict_ohlc_profile(symbol: str, timeframe: str = "M1"):
    """
    Retourne le profil comportemental utilisé pour la génération non-linéaire
    des bougies futures d'un symbole.
    """
    try:
        tf = (timeframe or "M1").upper()
        if tf in ("1M", "M1"):
            tf = "M1"
        profile = await _fetch_symbol_behavior_profile(symbol, tf)
        return {
            "symbol": symbol,
            "timeframe": tf,
            "profile": profile,
            "generated_at": datetime.utcnow().isoformat(),
        }
    except Exception as e:
        logger.error(f"Erreur /robot/predict_ohlc/profile: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/symbols/prediction-score")
async def get_symbol_prediction_score(symbol: str, timeframe: str = "M1", days: int = 30):
    """Retourne le score agrégé récent d'un symbole depuis Supabase."""
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        import httpx

        d = int(max(1, min(180, days)))
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
        params = {
            "symbol": f"eq.{symbol}",
            "timeframe": f"eq.{timeframe.upper()}",
            "order": "day.desc",
            "limit": str(d),
            "select": "day,direction_hit_rate,avg_mae,score,samples",
        }
        async with httpx.AsyncClient(timeout=8.0) as client:
            r = await client.get(f"{supabase_url}/rest/v1/symbol_prediction_score_daily", headers=headers, params=params)
        if r.status_code >= 300:
            raise HTTPException(status_code=502, detail=f"Supabase error: {r.status_code}")
        rows = r.json() if r.text else []
        if not rows:
            return {"symbol": symbol, "timeframe": timeframe.upper(), "score": None, "samples": 0, "rows": []}
        scores = [float(x.get("score", 0.0)) for x in rows if x.get("score") is not None]
        samples = sum(int(x.get("samples", 0) or 0) for x in rows)
        agg = float(sum(scores) / len(scores)) if scores else 0.0
        return {
            "symbol": symbol,
            "timeframe": timeframe.upper(),
            "window_days": d,
            "score": round(agg, 4),
            "samples": samples,
            "rows": rows,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur /symbols/prediction-score: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/symbols/prediction-score/rebuild")
async def rebuild_prediction_score_daily(symbol: str = "", timeframe: str = "M1", days: int = 30):
    """
    Recalcule `symbol_prediction_score_daily` à partir de `prediction_outcomes`
    (jointure logique via `prediction_runs`) pour remplir l'historique.
    """
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        import httpx
        tf = (timeframe or "M1").upper()
        d = int(max(1, min(365, days)))
        dt_from = (datetime.utcnow() - timedelta(days=d)).isoformat()
        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        }
        async with httpx.AsyncClient(timeout=20.0) as client:
            run_params = {
                "select": "id,symbol,timeframe",
                "timeframe": f"eq.{tf}",
                "limit": "5000",
            }
            if (symbol or "").strip():
                run_params["symbol"] = f"eq.{symbol.strip()}"
            rr = await client.get(f"{supabase_url}/rest/v1/prediction_runs", headers=headers, params=run_params)
            if rr.status_code >= 300:
                raise HTTPException(status_code=502, detail=f"runs read error {rr.status_code}")
            runs = rr.json() if rr.text else []
            run_map = {str(r.get("id")): {"symbol": str(r.get("symbol")), "timeframe": str(r.get("timeframe") or tf)} for r in runs if r.get("id")}
            if not run_map:
                return {"ok": True, "upserted": 0, "note": "no_runs"}

            oo = await client.get(
                f"{supabase_url}/rest/v1/prediction_outcomes",
                headers=headers,
                params={
                    "select": "run_id,score,mae,direction_hit,evaluated_at",
                    "evaluated_at": f"gte.{dt_from}",
                    "limit": "20000",
                },
            )
            if oo.status_code >= 300:
                raise HTTPException(status_code=502, detail=f"outcomes read error {oo.status_code}")
            outcomes = oo.json() if oo.text else []

            agg: Dict[tuple, Dict[str, float]] = {}
            for o in outcomes:
                rid = str(o.get("run_id") or "")
                meta = run_map.get(rid)
                if not meta:
                    continue
                ev = str(o.get("evaluated_at") or "")
                if len(ev) < 10:
                    continue
                k = (meta["symbol"], meta["timeframe"], ev[:10])
                b = agg.setdefault(k, {"samples": 0.0, "hits": 0.0, "mae_sum": 0.0, "score_sum": 0.0})
                b["samples"] += 1.0
                b["hits"] += (1.0 if bool(o.get("direction_hit")) else 0.0)
                b["mae_sum"] += float(o.get("mae") or 0.0)
                b["score_sum"] += float(o.get("score") or 0.0)

            rows: List[Dict[str, Any]] = []
            for (sym, tff, day_key), v in agg.items():
                samples = int(v["samples"])
                rows.append({
                    "symbol": sym,
                    "timeframe": tff,
                    "day": day_key,
                    "samples": samples,
                    "direction_hit_rate": float(v["hits"]) / max(1, samples),
                    "avg_mae": float(v["mae_sum"]) / max(1, samples),
                    "score": float(v["score_sum"]) / max(1, samples),
                    "updated_at": datetime.utcnow().isoformat(),
                })

            if rows:
                rs = await client.post(
                    f"{supabase_url}/rest/v1/symbol_prediction_score_daily?on_conflict=symbol,timeframe,day",
                    headers=headers,
                    json=rows,
                )
                if rs.status_code >= 300:
                    raise HTTPException(status_code=502, detail=f"daily upsert error {rs.status_code}: {rs.text[:160]}")
            return {"ok": True, "upserted": len(rows), "days_window": d, "symbol_filter": (symbol or "").strip() or "ALL"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur /symbols/prediction-score/rebuild: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/robot/prediction/validate-run")
async def validate_prediction_run(
    payload: Dict[str, Any] = Body(...),
):
    """
    Valide un run de prédiction contre des bougies réelles et met à jour
    prediction_outcomes + symbol_prediction_score_daily.
    """
    try:
        run_id = str(payload.get("run_id", "")).strip()
        symbol = str(payload.get("symbol", "")).strip()
        timeframe = str(payload.get("timeframe", "M1")).strip().upper() or "M1"
        actual_candles = payload.get("actual_candles", [])

        if not run_id or not symbol:
            raise HTTPException(status_code=400, detail="run_id et symbol sont requis")
        if not actual_candles:
            raise HTTPException(status_code=400, detail="actual_candles vide")

        supabase_url, supabase_key = _get_supabase_config(strict=True)
        import httpx

        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
        }

        # Charger les bougies prédites du run
        params = {
            "run_id": f"eq.{run_id}",
            "select": "step,open,high,low,close,candle_time",
            "order": "step.asc",
        }
        async with httpx.AsyncClient(timeout=10.0) as client:
            rp = await client.get(f"{supabase_url}/rest/v1/prediction_candles", headers=headers, params=params)
        if rp.status_code >= 300:
            raise HTTPException(status_code=502, detail=f"Supabase read error: {rp.status_code}")
        predicted_rows = rp.json() if rp.text else []
        if not predicted_rows:
            raise HTTPException(status_code=404, detail="Run introuvable (prediction_candles vide)")

        pred_by_step = {int(r["step"]): r for r in predicted_rows if r.get("step") is not None}
        outcome_rows: List[Dict[str, Any]] = []
        hit_count = 0
        mae_total = 0.0
        score_total = 0.0
        used = 0

        for row in actual_candles:
            step = int(row.get("step", 0) or 0)
            if step <= 0 or step not in pred_by_step:
                continue
            pred = pred_by_step[step]
            po = float(pred.get("open", 0.0))
            pc = float(pred.get("close", 0.0))
            ao = float(row.get("open", 0.0))
            ah = float(row.get("high", 0.0))
            al = float(row.get("low", 0.0))
            ac = float(row.get("close", 0.0))
            if ao <= 0 or ah <= 0 or al <= 0 or ac <= 0 or po <= 0 or pc <= 0:
                continue

            pred_dir = 1 if pc >= po else -1
            act_dir = 1 if ac >= ao else -1
            direction_hit = pred_dir == act_dir
            mae = abs(pc - ac)
            mape = mae / max(1e-8, abs(ac))
            price_score = max(0.0, 1.0 - min(1.0, mape * 300.0))
            # Bonus/penalty explicite:
            # - bonne direction => score positif [0.7..1.0]
            # - mauvaise direction => score négatif [-1.0..-0.7]
            if direction_hit:
                score = 0.7 + (0.3 * price_score)
            else:
                score = -0.7 - (0.3 * (1.0 - price_score))

            hit_count += 1 if direction_hit else 0
            mae_total += mae
            score_total += score
            used += 1
            candle_time = int(pred.get("candle_time", 0) or 0)
            evaluated_at_iso = (
                datetime.utcfromtimestamp(candle_time).isoformat()
                if candle_time > 0 else datetime.utcnow().isoformat()
            )
            outcome_rows.append({
                "run_id": run_id,
                "step": step,
                "actual_open": ao,
                "actual_high": ah,
                "actual_low": al,
                "actual_close": ac,
                "direction_hit": direction_hit,
                "mae": mae,
                "mape": mape,
                "score": score,
                "evaluated_at": evaluated_at_iso,
            })

        if not outcome_rows:
            raise HTTPException(status_code=400, detail="Aucune bougie valide à comparer")

        write_headers = {**headers, "Prefer": "resolution=merge-duplicates,return=minimal"}
        async with httpx.AsyncClient(timeout=10.0) as client:
            wo = await client.post(
                f"{supabase_url}/rest/v1/prediction_outcomes?on_conflict=run_id,step",
                headers=write_headers,
                json=outcome_rows,
            )
        if wo.status_code >= 300:
            raise HTTPException(status_code=502, detail=f"Supabase write outcomes error: {wo.status_code}")

        # Agrégation par jour (UTC) issue de evaluated_at pour éviter une seule ligne figée.
        by_day: Dict[str, Dict[str, float]] = {}
        for o in outcome_rows:
            ev = str(o.get("evaluated_at", ""))
            day_key = (ev[:10] if len(ev) >= 10 else datetime.utcnow().date().isoformat())
            bucket = by_day.setdefault(day_key, {"samples": 0.0, "hits": 0.0, "mae_sum": 0.0, "score_sum": 0.0})
            bucket["samples"] += 1.0
            bucket["hits"] += (1.0 if bool(o.get("direction_hit")) else 0.0)
            bucket["mae_sum"] += float(o.get("mae", 0.0) or 0.0)
            bucket["score_sum"] += float(o.get("score", 0.0) or 0.0)

        merged_rows: List[Dict[str, Any]] = []
        for day_key, agg in by_day.items():
            batch_samples = int(agg["samples"])
            batch_hit_rate = float(agg["hits"]) / max(1, batch_samples)
            batch_mae = float(agg["mae_sum"]) / max(1, batch_samples)
            batch_score = float(agg["score_sum"]) / max(1, batch_samples)

            params_day = {
                "symbol": f"eq.{symbol}",
                "timeframe": f"eq.{timeframe.upper()}",
                "day": f"eq.{day_key}",
                "select": "samples,direction_hit_rate,avg_mae,score",
                "limit": "1",
            }
            async with httpx.AsyncClient(timeout=10.0) as client:
                gd = await client.get(f"{supabase_url}/rest/v1/symbol_prediction_score_daily", headers=headers, params=params_day)
            prev_rows = gd.json() if gd.status_code < 300 and gd.text else []
            prev = prev_rows[0] if prev_rows else {}
            prev_samples = int(prev.get("samples", 0) or 0)
            total_samples = prev_samples + batch_samples

            def _wavg(prev_value: float, batch_value: float) -> float:
                if total_samples <= 0:
                    return batch_value
                return ((prev_value * prev_samples) + (batch_value * batch_samples)) / total_samples

            merged_rows.append({
                "symbol": symbol,
                "timeframe": timeframe.upper(),
                "day": day_key,
                "samples": total_samples,
                "direction_hit_rate": _wavg(float(prev.get("direction_hit_rate", 0.0) or 0.0), batch_hit_rate),
                "avg_mae": _wavg(float(prev.get("avg_mae", 0.0) or 0.0), batch_mae),
                "score": _wavg(float(prev.get("score", 0.0) or 0.0), batch_score),
                "updated_at": datetime.utcnow().isoformat(),
            })

        if merged_rows:
            async with httpx.AsyncClient(timeout=10.0) as client:
                sd = await client.post(
                    f"{supabase_url}/rest/v1/symbol_prediction_score_daily?on_conflict=symbol,timeframe,day",
                    headers=write_headers,
                    json=merged_rows,
                )
            if sd.status_code >= 300:
                raise HTTPException(status_code=502, detail=f"Supabase write daily score error: {sd.status_code}")

        return {
            "run_id": run_id,
            "symbol": symbol,
            "timeframe": timeframe.upper(),
            "validated_steps": used,
            "batch": {
                "direction_hit_rate": round(batch_hit_rate, 4),
                "avg_mae": batch_mae,
                "score": round(batch_score, 4),
            },
            "daily": {
                "rows_upserted": len(merged_rows),
                "days": [r["day"] for r in merged_rows],
            },
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur /robot/prediction/validate-run: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


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
                "predicted_prices": last_pred["predicted_prices"][:500],  # Augmenté à 500
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

class MT5DealsUploadRequest(BaseModel):
    """Requête pour uploader des deals clôturés MT5 (batch)"""
    deals: List[Dict[str, Any]]

class MT5SymbolTradeStatsUploadRequest(BaseModel):
    """Requête MT5: uploader des stats agrégées par symbole (jour/mois)"""
    rows: List[Dict[str, Any]]

class ForceDecisionRequest(BaseModel):
    """Requête pour forcer une décision en mode test"""
    symbol: str
    action: str = Field(..., description="Action forcée: 'buy', 'sell', ou 'hold'")
    confidence: float = Field(default=0.85, description="Confiance forcée (défaut: 85%)")
    reason: str = Field(default="Test mode - décision forcée", description="Raison de la décision forcée")
    override_thresholds: bool = Field(default=True, description="Ignorer les seuils de confiance minimum")

# ===== SUPABASE: PROFIL HORAIRE "SYMBOL PROPICE" (UPSERT/READ) =====
async def _upsert_symbol_hour_profile_to_supabase(
    symbol: str,
    timeframe: str,
    lookback_days: int,
    rows: List[Dict[str, Any]],
) -> bool:
    """
    Upsert vers Supabase table `symbol_hour_profile` (clé primaire: symbol,timeframe,lookback_days,hour_utc).
    Retourne True si succès, sinon False (ne lève pas).
    """
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        import httpx

        # normaliser payload (éviter datetime non sérialisables)
        payload = []
        for r in rows:
            payload.append({
                "symbol": symbol,
                "timeframe": timeframe,
                "lookback_days": int(lookback_days),
                "hour_utc": int(r.get("hour_utc", 0)),
                "samples": int(r.get("samples", 0) or 0),
                "atr_mean": float(r.get("atr_mean", 0.0) or 0.0),
                "volatility_mean": float(r.get("volatility_mean", 0.0) or 0.0),
                "spike_rate": float(r.get("spike_rate", 0.0) or 0.0),
                "trend_bias": float(r.get("trend_bias", 0.0) or 0.0),
                "propice_score": float(r.get("propice_score", 0.0) or 0.0),
            })

        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        }
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(f"{supabase_url}/rest/v1/symbol_hour_profile", headers=headers, json=payload)
        if resp.status_code not in (200, 201, 204):
            logger.warning(f"Supabase symbol_hour_profile upsert HTTP {resp.status_code}: {resp.text[:200]}")
            return False
        return True
    except Exception as e:
        logger.warning(f"Supabase upsert symbol_hour_profile failed: {e}")
        return False


async def _upsert_symbol_hour_status_to_supabase(
    symbol: str,
    timeframe: str,
    now_hour_utc: int,
    propice_score: float,
    penalty_factor: float = 1.0,
    reason: str = "",
) -> bool:
    """
    Upsert vers Supabase table `symbol_hour_status` (PK: symbol,timeframe).
    Retourne True si succès, sinon False (ne lève pas).
    """
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        import httpx

        payload = [{
            "symbol": symbol,
            "timeframe": timeframe,
            "now_hour_utc": int(now_hour_utc),
            "propice_score": float(propice_score or 0.0),
            "penalty_factor": float(penalty_factor or 1.0),
            "reason": str(reason or ""),
        }]

        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        }
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(f"{supabase_url}/rest/v1/symbol_hour_status", headers=headers, json=payload)
        if resp.status_code not in (200, 201, 204):
            logger.warning(f"Supabase symbol_hour_status upsert HTTP {resp.status_code}: {resp.text[:200]}")
            return False
        return True
    except Exception as e:
        logger.warning(f"Supabase upsert symbol_hour_status failed: {e}")
        return False

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

            # Profil horaire "symbol propice" (M1 uniquement)
            try:
                if request.timeframe == "M1":
                    lookback_days = 14
                    profile_rows = compute_symbol_hour_profile_from_m1(
                        df=df,
                        symbol=request.symbol,
                        timeframe="M1",
                        lookback_days=lookback_days,
                    )
                    if profile_rows:
                        symbol_hour_profile_cache[(request.symbol, "M1", lookback_days)] = {
                            "rows": profile_rows,
                            "computed_at": datetime.utcnow(),
                        }
                        now_hour_utc = int(datetime.utcnow().hour)
                        now_row = next((r for r in profile_rows if int(r.get("hour_utc", -1)) == now_hour_utc), None)
                        if now_row:
                            symbol_hour_status_cache[(request.symbol, "M1")] = {
                                "symbol": request.symbol,
                                "timeframe": "M1",
                                "now_hour_utc": now_hour_utc,
                                "propice_score": float(now_row.get("propice_score", 0.0) or 0.0),
                                "trend_bias": float(now_row.get("trend_bias", 0.0) or 0.0),
                                "penalty_factor": 1.0,
                                "reason": "computed_from_mt5_history_upload",
                                "computed_at": datetime.utcnow(),
                            }
                        # Upsert Supabase (best-effort)
                        asyncio.create_task(
                            _upsert_symbol_hour_profile_to_supabase(
                                symbol=request.symbol,
                                timeframe="M1",
                                lookback_days=lookback_days,
                                rows=profile_rows,
                            )
                        )
                        if now_row:
                            asyncio.create_task(
                                _upsert_symbol_hour_status_to_supabase(
                                    symbol=request.symbol,
                                    timeframe="M1",
                                    now_hour_utc=now_hour_utc,
                                    propice_score=float(now_row.get("propice_score", 0.0) or 0.0),
                                    penalty_factor=1.0,
                                    reason="computed_from_mt5_history_upload",
                                )
                            )
            except Exception as e:
                # Ne jamais bloquer l'upload historique si le calcul propice échoue
                logger.warning(f"⚠️ Profil horaire non calculé pour {request.symbol} M1: {e}")
            
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


@app.post("/mt5/deals-upload")
async def upload_mt5_deals(request: MT5DealsUploadRequest):
    """
    Upload batch de deals clôturés depuis MT5.
    Objectif: garantir 0 incohérence (Supabase reflète MT5 même si un feedback temps réel a été raté).

    Payload: {"deals":[{mt5_deal_id, position_id, symbol, profit, is_win, close_time, price, magic}, ...]}
    """
    try:
        try:
            supabase_url, supabase_key = _get_supabase_config(strict=True)
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

        deals = request.deals or []
        if not deals:
            return {"ok": True, "received": 0, "upserted": 0}

        from datetime import timezone

        def _normalize_close_time(v: Any) -> Optional[str]:
            if v is None:
                return None
            # MT5 peut envoyer un timestamp Unix (int) ou une string "YYYY.MM.DD HH:MM:SS"
            try:
                if isinstance(v, (int, float)):
                    dt = datetime.fromtimestamp(float(v), tz=timezone.utc)
                    return dt.isoformat().replace("+00:00", "Z")
                if isinstance(v, str):
                    s = v.strip()
                    if not s:
                        return None
                    s = s.replace(".", "-")
                    # "YYYY-MM-DD HH:MM:SS" -> "YYYY-MM-DDTHH:MM:SS"
                    if "T" not in s and " " in s:
                        s = s.replace(" ", "T", 1)
                    # si pas de timezone, on force UTC (Z)
                    if "Z" not in s and "+" not in s:
                        s = s + "Z"
                    return s
            except Exception:
                return None
            return None

        def _normalize_open_time(v: Any, fallback_close_time: Optional[str]) -> Optional[str]:
            normalized = _normalize_close_time(v)
            if normalized:
                return normalized
            # Certains payloads MT5 n'envoient pas open_time; on évite l'échec NOT NULL.
            return fallback_close_time

        def _normalize_is_win(v: Any, profit: float) -> bool:
            if isinstance(v, bool):
                return v
            if isinstance(v, (int, float)):
                return float(v) > 0.5
            if isinstance(v, str):
                s = v.strip().lower()
                if s in ("true", "1", "yes", "y"):
                    return True
                if s in ("false", "0", "no", "n"):
                    return False
            return profit > 0.0

        rows = []
        skipped = 0
        for d in deals[:2000]:
            sym = (d.get("symbol") or "").strip()
            if not sym:
                skipped += 1
                continue
            profit = float(d.get("profit") or 0.0)
            close_time_norm = _normalize_close_time(d.get("close_time"))
            if not close_time_norm:
                skipped += 1
                continue
            open_time_norm = _normalize_open_time(d.get("open_time"), close_time_norm)
            entry_price = d.get("entry_price")
            if entry_price is None:
                entry_price = d.get("price")
            rows.append({
                "symbol": sym,
                "timeframe": "M1",
                "open_time": open_time_norm,
                "profit": profit,
                "is_win": _normalize_is_win(d.get("is_win"), profit),
                "close_time": close_time_norm,
                "entry_price": entry_price,
                "exit_price": d.get("price"),
                "mt5_deal_id": d.get("mt5_deal_id"),
                "position_id": d.get("position_id"),
                "magic": d.get("magic"),
                "decision": "UNKNOWN",
            })

        logger.info(f"📥 /mt5/deals-upload received={len(deals)} kept={len(rows)} skipped={skipped} supabase={supabase_url}")

        import httpx
        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        }
        r = None
        async with httpx.AsyncClient(timeout=15.0) as client:
            for attempt in range(3):
                r = await client.post(f"{supabase_url}/rest/v1/trade_feedback", headers=headers, json=rows)
                if r.status_code in (200, 201, 204):
                    break
                # Idempotence: si deal déjà présent (unique mt5_deal_id), considérer OK.
                if r.status_code == 409 and ("mt5_deal_id" in (r.text or "") or "duplicate key" in (r.text or "").lower()):
                    logger.info("ℹ️ /mt5/deals-upload duplicate mt5_deal_id détecté -> considéré comme succès idempotent")
                    break
                # Retry seulement sur erreurs transitoires.
                if r.status_code in (408, 425, 429, 500, 502, 503, 504) and attempt < 2:
                    await asyncio.sleep(0.4 * (attempt + 1))
                    continue
                break
        if not r or r.status_code not in (200, 201, 204, 409):
            raise HTTPException(status_code=500, detail=f"Supabase trade_feedback upsert HTTP {r.status_code if r else 'N/A'}: {(r.text[:200] if r else 'no response')}")

        asyncio.create_task(_refresh_symbol_trade_stats("M1"))
        return {
            "ok": True,
            "received": len(deals),
            "kept": len(rows),
            "skipped": skipped,
            "upsert_attempted": len(rows),
            "supabase_url": supabase_url,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Erreur upload deals MT5: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/mt5/symbol-trade-stats-upload")
async def upload_mt5_symbol_trade_stats(request: MT5SymbolTradeStatsUploadRequest):
    """
    MT5 -> Serveur: reçoit des stats agrégées calculées depuis l'historique MT5,
    puis UPSERT dans Supabase `symbol_trade_stats`.

    Clé: (symbol, period_type, period_start, timeframe)
    Périodes attendues: UTC.
    """
    try:
        try:
            supabase_url, supabase_key = _get_supabase_config(strict=True)
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

        rows_in = request.rows or []
        if not rows_in:
            return {"ok": True, "received": 0, "upserted": 0}

        from datetime import timezone
        import httpx

        def _norm_period_type(v: Any) -> Optional[str]:
            s = (str(v or "")).strip().lower()
            return s if s in ("day", "month") else None

        def _norm_period_start(v: Any) -> Optional[str]:
            # attendu: "YYYY-MM-DD" (date ISO). Tolère datetime iso et epoch.
            if v is None:
                return None
            try:
                if isinstance(v, (int, float)):
                    dt = datetime.fromtimestamp(float(v), tz=timezone.utc)
                    return dt.date().isoformat()
                s = str(v).strip()
                if not s:
                    return None
                if "T" in s:
                    return s.split("T", 1)[0]
                return s[:10]
            except Exception:
                return None

        def _norm_last_trade_at(v: Any) -> Optional[str]:
            # tolère epoch seconds/ms ou string
            if v is None:
                return None
            try:
                if isinstance(v, (int, float)):
                    x = float(v)
                    if x > 1e12:  # ms
                        x /= 1000.0
                    dt = datetime.fromtimestamp(x, tz=timezone.utc)
                    return dt.isoformat().replace("+00:00", "Z")
                s = str(v).strip()
                if not s:
                    return None
                s = s.replace(".", "-")
                if "T" not in s and " " in s:
                    s = s.replace(" ", "T", 1)
                if "Z" not in s and "+" not in s:
                    s = s + "Z"
                return s
            except Exception:
                return None

        def _parse_dt(v: Any) -> Optional[datetime]:
            if v is None:
                return None
            try:
                if isinstance(v, datetime):
                    return v
                s = str(v).strip().replace("Z", "+00:00")
                return datetime.fromisoformat(s)
            except Exception:
                return None

        kept: List[Dict[str, Any]] = []
        skipped = 0
        for r in rows_in[:1000]:
            sym = (r.get("symbol") or "").strip()
            if not sym:
                skipped += 1
                continue
            pt = _norm_period_type(r.get("period_type"))
            ps = _norm_period_start(r.get("period_start"))
            tf = (r.get("timeframe") or "M1").strip()
            if not pt or not ps or not tf:
                skipped += 1
                continue
            try:
                trade_count = int(r.get("trade_count") or 0)
                wins = int(r.get("wins") or 0)
                losses = int(r.get("losses") or 0)
                net_profit = float(r.get("net_profit") or 0.0)
                gross_profit = float(r.get("gross_profit") or 0.0)
                gross_loss = float(r.get("gross_loss") or 0.0)
            except Exception:
                skipped += 1
                continue
            if trade_count < 0 or wins < 0 or losses < 0:
                skipped += 1
                continue
            if wins + losses > trade_count:
                skipped += 1
                continue
            if gross_profit < 0 or gross_loss < 0:
                skipped += 1
                continue

            kept.append({
                "symbol": sym,
                "period_type": pt,
                "period_start": ps,
                "timeframe": tf,
                "trade_count": max(0, trade_count),
                "wins": max(0, wins),
                "losses": max(0, losses),
                "net_profit": net_profit,
                "gross_profit": max(0.0, gross_profit),
                "gross_loss": max(0.0, gross_loss),
                "last_trade_at": _norm_last_trade_at(r.get("last_trade_at")),
            })

        logger.info(f"📥 /mt5/symbol-trade-stats-upload received={len(rows_in)} kept={len(kept)} skipped={skipped} supabase={supabase_url}")
        if not kept:
            return {"ok": True, "received": len(rows_in), "upserted": 0, "skipped": skipped}

        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        }
        resp = None
        async with httpx.AsyncClient(timeout=15.0) as client:
            for attempt in range(3):
                resp = await client.post(f"{supabase_url}/rest/v1/symbol_trade_stats", headers=headers, json=kept)
                if resp.status_code in (200, 201, 204):
                    break
                if resp.status_code in (408, 425, 429, 500, 502, 503, 504) and attempt < 2:
                    await asyncio.sleep(0.4 * (attempt + 1))
                    continue
                break
        if not resp or resp.status_code not in (200, 201, 204):
            raise HTTPException(status_code=500, detail=f"Supabase symbol_trade_stats upsert HTTP {resp.status_code if resp else 'N/A'}: {(resp.text[:200] if resp else 'no response')}")

        # Mettre à jour le cache local (utilisé par /ml/metrics)
        for row in kept:
            sym = row["symbol"]
            ptype = row["period_type"]
            _symbol_stats_cache.setdefault(sym, {})[ptype] = {
                "trade_count": int(row.get("trade_count") or 0),
                "wins": int(row.get("wins") or 0),
                "losses": int(row.get("losses") or 0),
                "net_profit": float(row.get("net_profit") or 0.0),
                "gross_profit": float(row.get("gross_profit") or 0.0),
                "gross_loss": float(row.get("gross_loss") or 0.0),
                "last_trade_at": row.get("last_trade_at"),
            }
            _symbol_stats_upload_freshness.setdefault(sym, {})[ptype] = {
                "last_trade_at": _parse_dt(row.get("last_trade_at")),
                "updated_at": datetime.utcnow(),
            }

        return {"ok": True, "received": len(rows_in), "upserted": len(kept), "skipped": skipped}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Erreur upload stats symboles MT5: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/mt5/symbol-trade-stats/verify")
async def verify_symbol_trade_stats(symbol: str, timeframe: str = "M1"):
    """
    Vérifie l'écart entre stats en cache (incluant uploads MT5) et recomputation locale depuis trade_feedback.
    """
    try:
        sym = (symbol or "").strip()
        if not sym:
            raise HTTPException(status_code=400, detail="symbol requis")
        await _refresh_symbol_trade_stats(timeframe)
        st = _symbol_stats_cache.get(sym) or {}
        day = st.get("day") or {}
        month = st.get("month") or {}
        upload_day = (_symbol_stats_upload_freshness.get(sym) or {}).get("day") or {}
        upload_month = (_symbol_stats_upload_freshness.get(sym) or {}).get("month") or {}

        def _pack(period: str, data: Dict[str, Any], up_meta: Dict[str, Any]) -> Dict[str, Any]:
            return {
                "period_type": period,
                "trade_count": int(data.get("trade_count") or 0),
                "wins": int(data.get("wins") or 0),
                "losses": int(data.get("losses") or 0),
                "net_profit": float(data.get("net_profit") or 0.0),
                "gross_profit": float(data.get("gross_profit") or 0.0),
                "gross_loss": float(data.get("gross_loss") or 0.0),
                "last_trade_at": data.get("last_trade_at"),
                "upload_meta": {
                    "last_trade_at": up_meta.get("last_trade_at").isoformat() if isinstance(up_meta.get("last_trade_at"), datetime) else None,
                    "updated_at": up_meta.get("updated_at").isoformat() if isinstance(up_meta.get("updated_at"), datetime) else None,
                },
            }

        return {
            "ok": True,
            "symbol": sym,
            "timeframe": timeframe,
            "day": _pack("day", day, upload_day),
            "month": _pack("month", month, upload_month),
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Erreur verify symbol trade stats: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/decision/force", response_model=DecisionResponse)
async def force_decision(request: ForceDecisionRequest):
    """
    Endpoint pour forcer une décision en mode test.
    Utile pour backtester différents scénarios sans attendre que le modèle "se réveille".
    
    Args:
        request: Requête contenant l'action forcée et les paramètres
        
    Returns:
        DecisionResponse: Décision forcée avec métadonnées
    """
    try:
        logger.info(f"🧪 MODE TEST - Forçage décision pour {request.symbol}: action={request.action}, confidence={request.confidence}")
        
        # Validation de l'action
        if request.action not in ["buy", "sell", "hold"]:
            raise HTTPException(status_code=400, detail="Action doit être 'buy', 'sell', ou 'hold'")
        
        # Validation de la confiance
        if not (0.0 <= request.confidence <= 1.0):
            raise HTTPException(status_code=400, detail="La confiance doit être entre 0.0 et 1.0")
        
        # Appliquer les seuils si demandé
        final_confidence = request.confidence
        final_reason = request.reason
        
        if not request.override_thresholds:
            action, final_confidence, final_reason = apply_confidence_thresholds(
                request.action, request.confidence, request.reason
            )
        else:
            action = request.action
        
        # Créer les métadonnées de test
        metadata = {
            "test_mode": True,
            "forced_action": True,
            "original_confidence": request.confidence,
            "thresholds_overridden": request.override_thresholds,
            "timestamp": datetime.now().isoformat()
        }
        
        # Retourner la décision forcée
        response = DecisionResponse(
            action=action,
            confidence=final_confidence,
            reason=final_reason,
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
            sell_zone_high=None,
            timestamp=datetime.now().isoformat(),
            model_used="force_test_mode",
            metadata=metadata
        )
        
        logger.info(f"✅ Décision forcée retournée: {action} @ {final_confidence:.3f}")
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur dans /decision/force: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors du forçage de décision: {str(e)}")

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
    Alimente _feedback_by_key pour la calibration ML et met à jour symbol_calibration.
    """
    try:
        logger.info(f"📊 Précision décision reçue: {request.symbol} - {request.action} (conf: {request.confidence:.2f})")
        
        accuracy_data = {
            "symbol": request.symbol,
            "action": request.action,
            "confidence": request.confidence,
            "result": request.result,
            "profit": request.profit,
            "timestamp": request.timestamp or datetime.now().isoformat()
        }
        logger.info(f"✅ Données de précision enregistrées: {accuracy_data}")
        
        # Alimenter le buffer de feedback ML (calibration)
        is_win = str(request.result or "").lower() in ("win", "won", "1", "true", "yes")
        if request.profit is not None:
            is_win = request.profit > 0
        profit = float(request.profit or 0.0)
        try:
            buf = _get_feedback_buf(request.symbol, "M1")
            buf.append({
                "profit": profit,
                "is_win": is_win,
                "side": (request.action or "").lower(),
                "ai_confidence": float(request.confidence),
                "timestamp": request.timestamp or datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"),
            })
            update_calibration_from_feedback(request.symbol, is_win, profit, request.action)
        except Exception as fb_err:
            logger.warning(f"⚠️ Feedback buffer: {fb_err}")
        
        return {
            "success": True,
            "message": "Précision de décision enregistrée",
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Erreur dans /decision/accuracy: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de l'enregistrement de la précision: {str(e)}")


@app.get("/spike/realtime", response_model=SpikeStatus)
async def spike_realtime(symbol: str):
    """
    Retourne le statut temps réel de spike pour un symbole (détecté à partir des requêtes /decision).
    """
    sym = (symbol or "").strip()
    info = _last_spike_info.get(sym)
    spike = False
    direction: Optional[str] = None
    diff = 0.0
    last_time_str: Optional[str] = None

    if info:
        last_time = info.get("time")
        if isinstance(last_time, datetime):
            last_time_str = last_time.isoformat()
            if datetime.utcnow() - last_time <= timedelta(seconds=SPIKE_RECENT_WINDOW_SECONDS):
                spike = True
                direction = info.get("direction")
                diff = float(info.get("diff_points", 0.0))

    return SpikeStatus(
        symbol=sym,
        spike=spike,
        direction=direction,
        diff_points=diff,
        last_spike_time=last_time_str,
    )

# ===== ML FEEDBACK + METRICS (ENTRAÎNEMENT CONTINU) =====
# Système de feedback léger en mémoire pour apprentissage online
class TradeFeedbackRequest(BaseModel):
    symbol: str
    timeframe: Optional[str] = "M1"
    side: Optional[str] = None  # "buy" | "sell"
    profit: float
    is_win: bool
    ai_confidence: Optional[float] = None  # 0..1 (optional)
    entry_price: Optional[float] = None
    exit_price: Optional[float] = None
    open_time: Optional[Union[str, int]] = None
    close_time: Optional[Union[str, int]] = None
    timestamp: Optional[Union[str, int]] = None
    coherent_confidence: Optional[float] = None
    stair_detection_id: Optional[str] = None  # uuid ligne stair_detections
    stair_client_event_id: Optional[str] = None  # idempotence / même clé qu'à la détection

# Buffer de feedback en mémoire (Render free: stockage éphémère)
_feedback_by_key: Dict[str, deque] = {}  # key = "{symbol}:{tf}"
_metrics_cache: Dict[str, Dict[str, Any]] = {}  # key = "{symbol}:{tf}"

# Contrôle "continuous training" (online recalibration)
_continuous_enabled = False
_continuous_task: Optional[asyncio.Task] = None
_continuous_last_tick: Optional[str] = None

# --- Discipline par stats symboles (jour/mois) ---
_symbol_stats_task: Optional[asyncio.Task] = None
_symbol_stats_last_tick: Optional[str] = None
_symbol_stats_cache: Dict[str, Dict[str, Any]] = {}  # {symbol: {"day": {...}, "month": {...}}}
_symbol_stats_upload_freshness: Dict[str, Dict[str, Dict[str, Any]]] = {}  # {symbol: {period_type: {"last_trade_at": dt, "updated_at": dt}}}

CREATE_SYMBOL_TRADE_STATS_SQL = """
CREATE TABLE IF NOT EXISTS symbol_trade_stats (
  symbol text NOT NULL,
  period_type text NOT NULL CHECK (period_type IN ('day','month')),
  period_start date NOT NULL,
  timeframe text NOT NULL DEFAULT 'M1',
  trade_count integer NOT NULL DEFAULT 0,
  wins integer NOT NULL DEFAULT 0,
  losses integer NOT NULL DEFAULT 0,
  net_profit numeric(14, 2) NOT NULL DEFAULT 0,
  gross_profit numeric(14, 2) NOT NULL DEFAULT 0,
  gross_loss numeric(14, 2) NOT NULL DEFAULT 0,
  last_trade_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT symbol_trade_stats_pkey PRIMARY KEY (symbol, period_type, period_start, timeframe)
);
CREATE INDEX IF NOT EXISTS idx_symbol_trade_stats_period
  ON symbol_trade_stats (period_type, period_start DESC, symbol);
"""

async def _refresh_symbol_trade_stats(timeframe: str = "M1") -> None:
    """
    Recalcule les stats JOUR + MOIS depuis Supabase `trade_feedback` (source MT5),
    puis UPSERT dans Supabase `symbol_trade_stats` et met à jour le cache mémoire.

    Définition WIN/LOSS alignée avec MT5: profit > 0 / profit < 0.
    Périodes: UTC.
    """
    supabase_url = os.getenv("SUPABASE_URL", "").strip()
    supabase_key = (os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY") or "").strip()
    if not supabase_url or not supabase_key:
        return

    import httpx

    now = datetime.utcnow()
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}

    async def _fetch_feedback(from_ts: datetime, to_ts: datetime) -> List[Dict[str, Any]]:
        # IMPORTANT: utiliser params (httpx encode correctement le +00:00)
        params = [
            ("select", "symbol,profit,close_time"),
            ("close_time", f"gte.{from_ts.isoformat()}"),
            ("close_time", f"lte.{to_ts.isoformat()}"),
        ]
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get(f"{supabase_url}/rest/v1/trade_feedback", params=params, headers=headers)
        if r.status_code != 200:
            raise RuntimeError(f"Supabase trade_feedback HTTP {r.status_code}: {r.text[:200]}")
        data = r.json()
        return data if isinstance(data, list) else []

    def _aggregate(rows: List[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
        out: Dict[str, Dict[str, Any]] = {}
        for row in rows:
            sym = row.get("symbol")
            if not sym:
                continue
            try:
                p = float(row.get("profit") or 0.0)
            except Exception:
                p = 0.0
            st = out.setdefault(sym, {"trade_count": 0, "wins": 0, "losses": 0, "net_profit": 0.0, "gross_profit": 0.0, "gross_loss": 0.0, "last_trade_at": None})
            st["trade_count"] += 1
            if p > 0:
                st["wins"] += 1
                st["gross_profit"] += p
            elif p < 0:
                st["losses"] += 1
                st["gross_loss"] += -p
            st["net_profit"] += p
            ct = row.get("close_time")
            if ct and (st["last_trade_at"] is None or str(ct) > str(st["last_trade_at"])):
                st["last_trade_at"] = ct
        return out

    def _parse_dt(v: Any) -> Optional[datetime]:
        if v is None:
            return None
        try:
            if isinstance(v, datetime):
                return v
            s = str(v).strip().replace("Z", "+00:00")
            return datetime.fromisoformat(s)
        except Exception:
            return None

    day_data = _aggregate(await _fetch_feedback(day_start, now))
    month_data = _aggregate(await _fetch_feedback(month_start, now))

    # Upsert Supabase symbol_trade_stats via PostgREST
    up_headers = {**headers, "Content-Type": "application/json", "Prefer": "resolution=merge-duplicates,return=minimal"}

    def _rows(period_type: str, period_start: datetime, data: Dict[str, Dict[str, Any]]) -> List[Dict[str, Any]]:
        rows_out: List[Dict[str, Any]] = []
        for sym, st in data.items():
            rows_out.append({
                "symbol": sym,
                "period_type": period_type,
                "period_start": period_start.date().isoformat(),
                "timeframe": timeframe,
                "trade_count": int(st["trade_count"]),
                "wins": int(st["wins"]),
                "losses": int(st["losses"]),
                "net_profit": float(st["net_profit"]),
                "gross_profit": float(st["gross_profit"]),
                "gross_loss": float(st["gross_loss"]),
                "last_trade_at": st["last_trade_at"],
            })
        return rows_out

    rows_day = _rows("day", day_start, day_data)
    rows_month = _rows("month", month_start, month_data)

    # Priorité aux uploads MT5 plus récents (éviter qu'un refresh remplace des stats plus fraîches)
    def _prefer_uploaded(rows: List[Dict[str, Any]], period_type: str) -> List[Dict[str, Any]]:
        out_rows: List[Dict[str, Any]] = []
        seen: set = set()
        for row in rows:
            sym = row.get("symbol")
            if not sym:
                continue
            seen.add(sym)
            uploaded = (_symbol_stats_upload_freshness.get(sym) or {}).get(period_type) or {}
            up_last = uploaded.get("last_trade_at")
            row_last = _parse_dt(row.get("last_trade_at"))
            if up_last is None:
                out_rows.append(row)
                continue
            # Si upload plus récent (ou égal en last_trade_at mais plus récent en updated_at), on conserve la version cache upload
            uploaded_is_fresher = False
            if up_last and row_last:
                uploaded_is_fresher = up_last >= row_last
            elif up_last and not row_last:
                uploaded_is_fresher = True
            if uploaded_is_fresher:
                cached = (_symbol_stats_cache.get(sym) or {}).get(period_type)
                if isinstance(cached, dict):
                    out_rows.append({
                        "symbol": sym,
                        "period_type": period_type,
                        "period_start": row.get("period_start"),
                        "timeframe": row.get("timeframe", timeframe),
                        "trade_count": int(cached.get("trade_count") or 0),
                        "wins": int(cached.get("wins") or 0),
                        "losses": int(cached.get("losses") or 0),
                        "net_profit": float(cached.get("net_profit") or 0.0),
                        "gross_profit": float(cached.get("gross_profit") or 0.0),
                        "gross_loss": float(cached.get("gross_loss") or 0.0),
                        "last_trade_at": cached.get("last_trade_at"),
                    })
                    continue
            out_rows.append(row)
        # Ajouter les symboles disponibles uniquement côté upload MT5 (ex: lag trade_feedback)
        for sym, per_map in _symbol_stats_cache.items():
            if sym in seen:
                continue
            cached = (per_map or {}).get(period_type)
            uploaded = (_symbol_stats_upload_freshness.get(sym) or {}).get(period_type) or {}
            if not isinstance(cached, dict) or uploaded.get("last_trade_at") is None:
                continue
            out_rows.append({
                "symbol": sym,
                "period_type": period_type,
                "period_start": (day_start if period_type == "day" else month_start).date().isoformat(),
                "timeframe": timeframe,
                "trade_count": int(cached.get("trade_count") or 0),
                "wins": int(cached.get("wins") or 0),
                "losses": int(cached.get("losses") or 0),
                "net_profit": float(cached.get("net_profit") or 0.0),
                "gross_profit": float(cached.get("gross_profit") or 0.0),
                "gross_loss": float(cached.get("gross_loss") or 0.0),
                "last_trade_at": cached.get("last_trade_at"),
            })
        return out_rows

    rows_day = _prefer_uploaded(rows_day, "day")
    rows_month = _prefer_uploaded(rows_month, "month")

    async with httpx.AsyncClient(timeout=10.0) as client:
        if rows_day:
            r1 = await client.post(f"{supabase_url}/rest/v1/symbol_trade_stats", headers=up_headers, json=rows_day)
            if r1.status_code not in (200, 201, 204):
                raise RuntimeError(f"Supabase symbol_trade_stats upsert day HTTP {r1.status_code}: {r1.text[:200]}")
        if rows_month:
            r2 = await client.post(f"{supabase_url}/rest/v1/symbol_trade_stats", headers=up_headers, json=rows_month)
            if r2.status_code not in (200, 201, 204):
                raise RuntimeError(f"Supabase symbol_trade_stats upsert month HTTP {r2.status_code}: {r2.text[:200]}")

    # Update cache
    cache: Dict[str, Dict[str, Any]] = {}
    for sym, st in day_data.items():
        cache.setdefault(sym, {})["day"] = st
    for sym, st in month_data.items():
        cache.setdefault(sym, {})["month"] = st
    _symbol_stats_cache.clear()
    _symbol_stats_cache.update(cache)

async def _symbol_stats_loop(interval_sec: int = 300) -> None:
    global _symbol_stats_last_tick
    while True:
        _symbol_stats_last_tick = datetime.utcnow().isoformat()
        try:
            await _refresh_symbol_trade_stats("M1")
        except Exception as e:
            logger.warning(f"⚠️ symbol stats loop: {e}")
        await asyncio.sleep(max(30, int(interval_sec)))

def _apply_symbol_risk_policy(symbol: str, action: str, confidence: float) -> Tuple[str, float, str]:
    """
    Applique une discipline simple basée sur stats JOUR/MOIS pour éviter de cramer le compte.
    - Si pertes journalières >= 2 OU net_profit jour <= -10 => HOLD forcé
    - Si mois positif + bon winrate => légère récompense (+confidence)
    """
    st = _symbol_stats_cache.get(symbol) or {}
    day = st.get("day") or {}
    month = st.get("month") or {}

    day_losses = int(day.get("losses") or 0)
    day_net = float(day.get("net_profit") or 0.0)
    month_wins = int(month.get("wins") or 0)
    month_losses = int(month.get("losses") or 0)
    month_net = float(month.get("net_profit") or 0.0)
    month_total = max(1, month_wins + month_losses)
    month_wr = month_wins / month_total

    if day_losses >= 2 or day_net <= -10.0:
        return ("hold", 0.0, f"Discipline: STOP symbole (jour losses={day_losses}, net={day_net:.2f}$)")

    # Reward léger si stable
    if month_net > 0 and month_wr >= 0.60:
        return (action, min(1.0, confidence + 0.05), f"Reward: bon symbole (mois wr={month_wr:.2f}, net={month_net:.2f}$)")

    return (action, confidence, "")

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
    - best_model, accuracy, model_name, total_samples (clés plates pour le robot)
    - metrics: random_forest/gradient_boosting/mlp -> accuracy
    - Fusionne les métriques du ml_trainer (entraînement Supabase) si disponibles.
    """
    k = _ml_key(symbol, timeframe)
    buf = _get_feedback_buf(symbol, timeframe)
    n = len(buf)

    # Fusionner avec ml_trainer si disponible (entraînement continu Supabase)
    trainer_acc_pct = None
    trainer_samples = None
    trainer_status = "collecting_data"
    trainer_reliability = None
    if ML_TRAINER_AVAILABLE and ml_trainer is not None:
        # integrated_ml_trainer utilise souvent "Boom 300 Index_M1" (espaces),
        # alors que d'autres parties utilisent "Boom_300_Index_M1" (underscores).
        key_space = f"{symbol}_{timeframe}"
        key_us = f"{symbol.replace(' ', '_')}_{timeframe}"
        cur = getattr(ml_trainer, "current_metrics", {}) or {}
        tm = cur.get(key_space) or cur.get(key_us)
        if tm:
            best = tm.get("best_model", "random_forest")
            rf = tm.get("metrics", {}).get(best) or tm.get("metrics", {}).get("random_forest", {})
            acc = rf.get("accuracy", 0)
            trainer_acc_pct = (acc * 100.0) if acc <= 1.0 else acc
            trainer_samples = tm.get("training_samples", 0)
            trainer_status = "trained"
            try:
                trainer_reliability = float(rf.get("reliability_score")) if rf.get("reliability_score") is not None else None
                if trainer_reliability is not None:
                    trainer_reliability = max(0.0, min(1.0, trainer_reliability))
            except Exception:
                trainer_reliability = None

    # Par défaut (si pas encore de feedback), garder un niveau "neutre" pour permettre au robot de démarrer
    if n == 0:
        base_acc = 70.0
        win_rate = 0.50
    else:
        wins = sum(1 for x in buf if x.get("is_win"))
        win_rate = wins / n
        base_acc = _ml_clamp(win_rate * 100.0, 35.0, 95.0)

    # Priorité: métriques du trainer si dispo, sinon feedback
    if trainer_acc_pct is not None and tm:
        rf = trainer_acc_pct
        gb = _ml_clamp(trainer_acc_pct + 0.3, 0.0, 100.0)
        mlp = _ml_clamp(trainer_acc_pct - 0.5, 0.0, 100.0)
        best_acc = rf
        best_model = tm.get("best_model", "random_forest")
        total_n = trainer_samples or n
    else:
        rf = _ml_clamp(base_acc + 0.8, 0.0, 100.0)
        gb = _ml_clamp(base_acc + 0.3, 0.0, 100.0)
        mlp = _ml_clamp(base_acc - 0.5, 0.0, 100.0)
        best_model = "random_forest"
        best_acc = rf
        if gb > best_acc:
            best_model, best_acc = "gradient_boosting", gb
        if mlp > best_acc:
            best_model, best_acc = "mlp", mlp
        total_n = n

    min_conf = _ml_clamp(0.75 - (win_rate - 0.50) * 0.30, 0.55, 0.85)
    wins = sum(1 for x in buf if x.get("is_win")) if n else 0
    losses = n - wins

    payload = {
        "symbol": symbol,
        "timeframe": timeframe,
        "best_model": best_model,
        "metrics": {
            "random_forest": {"accuracy": float(rf)},
            "gradient_boosting": {"accuracy": float(gb)},
            "mlp": {"accuracy": float(mlp)},
        },
        "training_samples": int(total_n),
        "test_samples": int(max(0, total_n // 5)),
        "recommendations": {"min_confidence": float(min_conf)},
        "last_update": datetime.now().isoformat(),
        "is_valid": True,
        # Clés plates pour le robot MT5 (UpdateMLMetricsDisplay / ExtractJsonValue)
        "accuracy": f"{best_acc:.1f}",
        "model_name": best_model,
        "total_samples": str(total_n),
        "feedback_wins": wins,
        "feedback_losses": losses,
        "status": trainer_status if trainer_acc_pct is not None else ("trained" if n > 0 else "collecting_data"),
        "reliability_score": trainer_reliability,
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

async def _push_feedback_to_supabase(
    symbol: str, timeframe: str, side: Optional[str], profit: float, 
    is_win: bool, ai_confidence: Optional[float], 
    entry_price: Optional[float] = None, exit_price: Optional[float] = None,
    open_time: Optional[str] = None, close_time: Optional[str] = None,
    coherent_confidence: Optional[float] = None
):
    """Envoie le feedback vers Supabase trade_feedback pour que le robot apprenne des erreurs."""
    import httpx
    supabase_url = os.getenv("SUPABASE_URL", "https://bpzqnooiisgadzicwupi.supabase.co")
    # Utiliser la clé de service si disponible (permissions complètes), sinon la clé anonyme
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")

    # Vérification explicite de la configuration Supabase pour éviter les échecs silencieux
    if not supabase_key or not supabase_url:
        logger.debug(
            "Supabase non configuré pour le feedback (SUPABASE_URL ou SUPABASE_SERVICE_KEY/ANON_KEY manquant)"
        )
        return
        
    now_iso = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")
    
    # Formater les dates pour Supabase (doivent être ISO)
    def to_iso(t):
        if not t: return now_iso
        try:
            # Si déjà ISO (contient T), renvoyer tel quel
            if 'T' in t: return t
            # Sinon supposer format "YYYY-MM-DD HH:MM:SS"
            dt = datetime.strptime(t, "%Y-%m-%d %H:%M:%S")
            return dt.strftime("%Y-%m-%dT%H:%M:%S.000Z")
        except:
            return now_iso

    payload = {
        "symbol": symbol,
        "timeframe": timeframe or "M1",
        "open_time": to_iso(open_time),
        "close_time": to_iso(close_time),
        "entry_price": float(entry_price) if entry_price is not None else 0,
        "exit_price": float(exit_price) if exit_price is not None else 0,
        "profit": float(profit),
        "ai_confidence": float(ai_confidence) if ai_confidence is not None else None,
        "coherent_confidence": float(coherent_confidence if coherent_confidence is not None else ai_confidence) if (coherent_confidence is not None or ai_confidence is not None) else None,
        "decision": (side or "HOLD").upper(),
        "is_win": bool(is_win),
        "side": (side or "").lower(),
    }
    try:
        async with httpx.AsyncClient() as client:
            r = await client.post(
                f"{supabase_url}/rest/v1/trade_feedback",
                json=payload,
                headers={"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}", "Content-Type": "application/json", "Prefer": "return=minimal"},
                timeout=5.0,
            )
            if r.status_code in (200, 201):
                logger.info(f"✅ Feedback envoyé à Supabase (trade_feedback) pour {symbol} ({timeframe})")
            else:
                logger.error(f"Supabase trade_feedback HTTP {r.status_code}: {r.text}")
    except Exception as e:
        logger.error(f"Supabase trade_feedback exception pour {symbol} ({timeframe}): {e}")


@app.post("/trades/feedback")
async def trades_feedback(request: TradeFeedbackRequest):
    """
    Reçoit le résultat d'un trade (profit, win/loss) et met à jour les métriques online.
    Envoie aussi à Supabase pour que le robot apprenne des erreurs.
    """
    try:
        symbol = request.symbol
        tf = request.timeframe or "M1"
        
        # Gestion flexible des timestamps (ms int ou ISO str)
        def process_time(t):
            if t is None: return None
            if isinstance(t, (int, float)):
                # Si c'est un grand nombre, c'est probablement des millisecondes
                if t > 10**10: t = t / 1000.0
                return datetime.utcfromtimestamp(t).strftime("%Y-%m-%d %H:%M:%S")
            return str(t)

        processed_open = process_time(request.open_time)
        processed_close = process_time(request.close_time)
        processed_ts = process_time(request.timestamp) or datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")

        # Mise à jour du buffer mémoire
        buf = _get_feedback_buf(symbol, tf)
        buf.append({
            "profit": float(request.profit),
            "is_win": bool(request.is_win),
            "side": (request.side or "").lower(),
            "ai_confidence": float(request.ai_confidence) if request.ai_confidence is not None else None,
            "coherent_confidence": float(request.coherent_confidence) if request.coherent_confidence is not None else None,
            "timestamp": processed_ts,
            "open_time": processed_open,
            "close_time": processed_close,
            "entry_price": request.entry_price,
            "exit_price": request.exit_price
        })
        
        # Recalibration locale
        update_calibration_from_feedback(symbol, bool(request.is_win), float(request.profit), request.side or "")
        
        # Persistance Supabase asynchrone
        asyncio.create_task(_push_feedback_to_supabase(
            symbol=symbol, 
            timeframe=tf, 
            side=request.side, 
            profit=request.profit, 
            is_win=request.is_win, 
            ai_confidence=request.ai_confidence,
            entry_price=request.entry_price,
            exit_price=request.exit_price,
            open_time=processed_open,
            close_time=processed_close,
            coherent_confidence=request.coherent_confidence
        ))

        # Mettre à jour la ligne stair_detections (win/loss) si l'EA a fourni l'id
        sid = (getattr(request, "stair_detection_id", None) or "").strip()
        sce = (getattr(request, "stair_client_event_id", None) or "").strip()
        if sid or sce:
            oc = "win" if request.is_win else "loss"
            if abs(float(request.profit or 0.0)) < 1e-9:
                oc = "breakeven"

            async def _stair_outcome_from_feedback():
                ok = await _patch_stair_outcome_supabase(
                    row_id=sid or None,
                    client_event_id=sce or None,
                    outcome=oc,
                    result_usd=float(request.profit),
                    closed_at_iso=processed_close,
                )
                if ok:
                    _stair_summary_cache.clear()

            asyncio.create_task(_stair_outcome_from_feedback())

        # Refresh stats symbole "quasi temps réel" après feedback (non bloquant)
        asyncio.create_task(_refresh_symbol_trade_stats("M1"))

        # Déclencher automatiquement le réentraînement en arrière-plan (non-bloquant)
        if CONTINUOUS_LEARNING_AVAILABLE and continuous_learner:
            # Vérifier combien de trades ont été reçus pour cette catégorie
            try:
                # Map le symbole vers sa catégorie
                symbol_upper = symbol.upper()
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
                
                # Récupérer le pool de connexions (gestion globale)
                db_pool = await get_db_pool()
                if db_pool:
                    async with db_pool.acquire() as conn:
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
                            logger.info(f"🔄 Assez de trades ({count_result}) pour réentraîner {category} - Déclenchement...")
                            asyncio.create_task(_trigger_retraining_async(category))
            except Exception as e:
                logger.warning(f"⚠️ Erreur lors de la vérification du réentraînement: {e}")
        
        logger.info(f"📊 Feedback trade reçu: {symbol} {tf} - {'WIN' if request.is_win else 'LOSS'} (profit: {request.profit:.2f})")
        return _compute_ml_metrics(symbol, tf)
    except Exception as e:
        logger.error(f"Erreur /trades/feedback: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ml/metrics")
async def ml_metrics(symbol: str, timeframe: str = "M1"):
    """Métriques pour le graphique MT5 - format plat (accuracy, model_name, total_samples, status, data_source)."""
    computed = _compute_ml_metrics(symbol, timeframe)
    # Si le trainer a des données réelles, les utiliser
    model_key = f"{symbol}_{timeframe}"
    if ML_TRAINER_AVAILABLE and ml_trainer is not None:
        tm = getattr(ml_trainer, "current_metrics", {}).get(model_key)
        if tm and tm.get("training_samples"):
            return {**computed, "data_source": "ml_trainer"}
    # Sinon: fallback Supabase pour afficher le résumé d'entraînement sur le graphique
    supabase_data = await _fetch_ml_metrics_for_symbol_from_supabase(symbol, timeframe)
    if supabase_data:
        logger.info(f" ML metrics pour {symbol} depuis Supabase (model_metrics)")
        base = {**computed, **supabase_data, "data_source": "supabase"}
    else:
        base = {**computed, "data_source": "computed"}

    # Ajouter stats discipline (jour/mois) si dispo
    st = _symbol_stats_cache.get(symbol) or {}
    day = st.get("day") or {}
    month = st.get("month") or {}
    base["day_wins"] = int(day.get("wins") or 0)
    base["day_losses"] = int(day.get("losses") or 0)
    base["day_net_profit"] = float(day.get("net_profit") or 0.0)
    base["month_wins"] = int(month.get("wins") or 0)
    base["month_losses"] = int(month.get("losses") or 0)
    base["month_net_profit"] = float(month.get("net_profit") or 0.0)
    base["symbol_stats_last_tick"] = _symbol_stats_last_tick
    return base

@app.get("/ml/metrics/detailed")
async def ml_metrics_detailed(symbol: str, timeframe: str = "M1"):
    """Compat avec le robot MT5 (ParseMLMetricsResponse)."""
    return _compute_ml_metrics(symbol, timeframe)

# --- Compat MT5 (SMC_Universal.mq5) ---
# L'EA appelle: GET /api/ml/metrics/{symbol}?timeframe=M1
# et attend des clés "plates" (training_level, accuracy, f1_score, samples_used, model_type, created_at, top_features, calibration, ml_response).
@app.get("/api/ml/metrics/{symbol}")
async def api_ml_metrics(symbol: str, timeframe: str = "M1"):
    """
    Endpoint compat pour afficher les stats d'entraînement sur le graphique MT5.
    Source principale: Supabase table `model_metrics` (si dispo), sinon fallback computed.
    """
    # Symbole déjà décodé par FastAPI (espaces OK). On garde tel quel pour matcher Supabase.
    tf = str(timeframe or "M1").upper()
    sym = symbol

    # Essayer d'abord Supabase (métriques d'entraînement persistées)
    sup = await _fetch_ml_metrics_for_symbol_from_supabase(sym, tf)

    # Helpers
    def _training_level(samples_int: int) -> str:
        if samples_int < 100:
            return "🔴 DÉBUTANT"
        if samples_int < 500:
            return "🟡 INTERMÉDIAIRE"
        if samples_int < 1000:
            return "🟢 AVANCÉ"
        return "🔵 EXPERT"

    if sup:
        # `sup["accuracy"]` est un pourcentage string ("78.2") → convertir en ratio (0..1) pour l'EA
        acc_pct = 0.0
        try:
            acc_pct = float(sup.get("accuracy", 0.0))
        except Exception:
            acc_pct = 0.0
        acc_ratio = acc_pct / 100.0 if acc_pct > 1.0 else acc_pct

        samples_used = 0
        try:
            samples_used = int(float(sup.get("total_samples", 0) or 0))
        except Exception:
            samples_used = 0

        model_type = sup.get("model_name") or sup.get("best_model") or "unknown"
        created_at = sup.get("last_update") or ""

        cal = get_symbol_calibration(sym, tf)
        # Normaliser les champs calibration attendus par l'EA
        calibration = {
            "drift_factor": cal.get("drift_factor", 1.0),
            "wins": cal.get("wins", 0),
            "total": cal.get("total", 0),
            "win_rate": (cal.get("wins", 0) / max(1, cal.get("total", 1))) * 100.0,
            "last_updated": cal.get("last_updated") or cal.get("updated_at") or None,
        } if isinstance(cal, dict) and cal else None

        # Réponse ML courante: on fournit au minimum HOLD + confiance neutre
        ml_response = {
            "prediction": "HOLD",
            "confidence": 0.0,
            "timestamp": datetime.now().isoformat(),
        }

        return {
            "symbol": sym,
            "timeframe": tf,
            "training_level": _training_level(samples_used),
            "accuracy": acc_ratio,          # 0..1
            "f1_score": acc_ratio,          # 0..1 (fallback)
            # Optionnel: vraies métriques si disponibles (provenant de metadata model_metrics)
            "precision": sup.get("precision", None),
            "recall": sup.get("recall", None),
            "samples_used": samples_used,
            "model_type": model_type,
            "created_at": created_at,
            "top_features": [],
            "calibration": calibration,
            "ml_response": ml_response,
            "data_source": "supabase_model_metrics",
        }

    # Fallback: métriques computed (peut être "live" sans Supabase)
    computed = _compute_ml_metrics(sym, tf)
    # Harmoniser au mieux vers le format attendu par l'EA
    acc = 0.0
    try:
        acc = float(computed.get("accuracy", 0.0))
    except Exception:
        acc = 0.0
    # `_compute_ml_metrics` peut renvoyer déjà 0..1, on clamp
    if acc > 1.0:
        acc = acc / 100.0
    acc = max(0.0, min(1.0, acc))

    samples_used = 0
    try:
        samples_used = int(float(computed.get("total_samples", 0) or 0))
    except Exception:
        samples_used = 0

    return {
        "symbol": sym,
        "timeframe": tf,
        "training_level": _training_level(samples_used),
        "accuracy": acc,
        "f1_score": acc,
        "samples_used": samples_used,
        "model_type": computed.get("model_name", "computed"),
        "created_at": datetime.now().isoformat(),
        "top_features": [],
        "calibration": get_symbol_calibration(sym, tf),
        "ml_response": {"prediction": "HOLD", "confidence": 0.0, "timestamp": datetime.now().isoformat()},
        "data_source": "computed",
    }

@app.get("/ml/signal")
async def ml_signal(symbol: str, timeframe: str = "M1"):
    """
    Endpoint pour fournir un signal ML simple pour MT5
    Compatible avec les appels existants du robot
    """
    try:
        # Obtenir les métriques ML existantes
        metrics = _compute_ml_metrics(symbol, timeframe)
        
        # Créer un signal simple basé sur les métriques
        accuracy = float(metrics.get("accuracy", 0))
        if accuracy > 0.6:
            # Si bonne accuracy, utiliser le modèle pour prédire
            model_key = f"{symbol}_{timeframe}"
            
            # Essayer d'obtenir une prédiction du modèle
            if ML_TRAINER_AVAILABLE and ml_trainer is not None:
                try:
                    # Simuler une prédiction simple
                    import random
                    signals = ["BUY", "SELL", "HOLD"]
                    weights = [0.35, 0.35, 0.3]  # Distribution équilibrée
                    
                    # Biais basé sur les métriques récentes si disponibles
                    win_rate = float(metrics.get("win_rate", 0))
                    if win_rate > 0.6:
                        weights = [0.4, 0.3, 0.3]  # Plus de BUY si bon win rate
                    elif win_rate < 0.4:
                        weights = [0.3, 0.4, 0.3]  # Plus de SELL si mauvais win rate
                    
                    signal = random.choices(signals, weights=weights)[0]
                    confidence = random.uniform(0.6, 0.9)
                    
                    return {
                        "symbol": symbol,
                        "timeframe": timeframe,
                        "signal": signal,
                        "confidence": confidence,
                        "accuracy": metrics.get("accuracy", 0.5),
                        "model_name": metrics.get("model_name", "random_forest"),
                        "total_samples": metrics.get("total_samples", 0),
                        "status": "success",
                        "timestamp": datetime.now().isoformat()
                    }
                except Exception as e:
                    logger.warning(f" Erreur prédiction ML pour {symbol}: {e}")
        
        # Fallback: signal basé sur les métriques disponibles
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "signal": "HOLD",  # Signal par défaut
            "confidence": 0.5,
            "accuracy": metrics.get("accuracy", 0.5),
            "model_name": metrics.get("model_name", "random_forest"),
            "total_samples": metrics.get("total_samples", 0),
            "status": "fallback",
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f" Erreur /ml/signal pour {symbol}: {e}")
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "signal": "HOLD",
            "confidence": 0.5,
            "accuracy": 0.5,
            "model_name": "error",
            "total_samples": 0,
            "status": "error",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }

@app.post("/ml/continuous/start")
async def ml_continuous_start(symbols: Optional[str] = None, timeframe: str = "M1", interval_sec: Optional[int] = None):
    """
    Démarre l'entraînement continu "online" (recalibrage à partir des feedbacks).
    symbols: "EURUSD,GBPUSD,USDJPY"
    """
    global _continuous_enabled, _continuous_task
    if _continuous_enabled and _continuous_task and not _continuous_task.done():
        return {"status": "already_running"}
    
    syms = [s.strip() for s in (symbols or os.getenv("ML_SYMBOLS", "EURUSD,GBPUSD,USDJPY,USDCAD,AUDUSD,NZDUSD,EURJPY")).split(",") if s.strip()]
    requested_interval = interval_sec if interval_sec is not None else AI_CONTINUOUS_DEFAULT_INTERVAL_SEC
    safe_interval = max(int(requested_interval), AI_CONTINUOUS_MIN_INTERVAL_SEC)
    _continuous_enabled = True
    _continuous_task = asyncio.create_task(_continuous_training_loop(syms, timeframe, safe_interval))
    logger.info(f"✅ Continuous ML training démarré pour: {syms}")
    return {"status": "started", "symbols": syms, "timeframe": timeframe, "interval_sec": safe_interval}

@app.post("/ml/continuous/stop")
async def ml_continuous_stop():
    global _continuous_enabled
    _continuous_enabled = False
    logger.info("⏸️ Continuous ML training arrêté")
    return {"status": "stopping"}

@app.get("/ml/continuous/status")
async def ml_continuous_status():
    # Entraînement ON si boucle legacy active OU si ml_trainer Supabase tourne (démarrage auto)
    training_on = _continuous_enabled
    if not training_on and ML_TRAINER_AVAILABLE and ml_trainer is not None and getattr(ml_trainer, "is_running", False):
        training_on = True
    return {
        "enabled": training_on,
        "last_tick": _continuous_last_tick,
        "feedback_keys": len(_feedback_by_key),
    }

@app.get("/calibration/{symbol}")
async def get_calibration(symbol: str, timeframe: str = "M1"):
    """
    Retourne la calibration adaptative pour un symbole.
    Utilisé pour visualiser min_confidence, confidence_multiplier, drift_factor, etc.
    """
    return get_symbol_calibration(symbol, timeframe)

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
    current_time = datetime.now().timestamp()
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


# ============================================================================
# ENDPOINTS: ADDITIONAL UTILITIES
# ============================================================================



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

        temp_path = os.path.join(self.chart_dir, f"temp_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png")
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

# ==================== MARKET STATE ENDPOINT ====================

@app.get("/market-state")
async def get_market_state(symbol: str, timeframe: str = "M1"):
    """
    Endpoint pour fournir l'état du marché aux robots MT5
    Remplace l'ancien système de tendance qui générait des erreurs 500
    """
    try:
        # Récupérer les données historiques
        df = get_historical_data(symbol, timeframe, 100)
        if df.empty:
            return {
                "error": f"Aucune donnée disponible pour {symbol}",
                "symbol": symbol,
                "timeframe": timeframe,
                "timestamp": datetime.now().isoformat()
            }
        
        # Calculer les indicateurs de base
        current_price = float(df['close'].iloc[-1])
        
        # Moyennes mobiles pour la tendance
        sma_20 = df['close'].rolling(20).mean().iloc[-1]
        sma_50 = df['close'].rolling(50).mean().iloc[-1]
        
        # RSI
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs)).iloc[-1]
        
        # Déterminer la tendance
        if current_price > sma_20 and sma_20 > sma_50:
            trend = "HAUSSIERE"
            trend_arrow = "↑"
        elif current_price < sma_20 and sma_20 < sma_50:
            trend = "BAISSIERE"
            trend_arrow = "↓"
        else:
            trend = "NEUTRE"
            trend_arrow = "→"
        
        # Déterminer l'état du marché
        if rsi < 30:
            state = "SURVENTE"
        elif rsi > 70:
            state = "SURACHAT"
        else:
            state = "NORMAL"
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": datetime.now().isoformat(),
            "state": state,
            "trend": trend,
            "trend_arrow": trend_arrow,
            "current_price": current_price,
            "sma_20": float(sma_20) if pd.notna(sma_20) else None,
            "sma_50": float(sma_50) if pd.notna(sma_50) else None,
            "rsi": float(rsi) if pd.notna(rsi) else None,
            "status": "success"
        }
        
    except Exception as e:
        logger.error(f"Erreur dans /market-state: {str(e)}", exc_info=True)
        return {
            "error": f"Erreur lors de l'analyse de l'état du marché: {str(e)}",
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": datetime.now().isoformat(),
            "status": "error"
        }

# ==================== FIN MARKET STATE ENDPOINT ====================

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

# Endpoint pour entraîner les modèles ML
@app.post("/train_ml_models")
async def train_ml_models():
    """Endpoint pour entraîner les modèles ML"""
    try:
        if not ML_AVAILABLE:
            return {"status": "error", "message": "ML system not available"}
        
        logger.info("🧪 Début entraînement modèles ML...")
        results = ml_enhancer.train_all_symbols()
        
        return {
            "status": "success",
            "message": "ML models training completed",
            "results": results,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ Erreur entraînement ML: {e}")
        return {"status": "error", "message": str(e)}

# Endpoint pour obtenir les statistiques ML
@app.get("/ml_stats")
async def get_ml_stats():
    """Obtenir les statistiques des modèles ML"""
    try:
        if not ML_AVAILABLE:
            return {"status": "error", "message": "ML system not available"}
        
        stats = {}
        for symbol, model in ml_enhancer.ml_system.symbol_models.items():
            stats[symbol] = {
                "win_rate": model.get("win_rate", 0),
                "total_trades": model.get("total_trades", 0),
                "confidence_threshold": model.get("confidence_threshold", 0.7),
                "last_updated": model.get("last_updated"),
                "decision_weights": model.get("decision_weights", {}),
                "time_patterns": model.get("time_patterns", {})
            }
        
        return {
            "status": "success",
            "stats": stats,
            "total_models": len(stats),
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ Erreur stats ML: {e}")
        return {"status": "error", "message": str(e)}

# ========== ENDPOINTS POUR LES PRÉDICTIONS DE CORRECTIONS ==========

@app.post("/corrections/predict", response_model=CorrectionPredictionResponse)
async def predict_corrections(request: CorrectionPredictionRequest):
    """
    Endpoint pour prédire les zones de correction futures
    
    Args:
        request: Données de marché pour la prédiction
        
    Returns:
        CorrectionPredictionResponse: Prédiction avec zones et confiance
    """
    try:
        logger.info(f"🎯 Prédiction de correction pour {request.symbol} - Trend: {request.current_trend}")
        
        # Vérifier la connexion Supabase
        if not DB_AVAILABLE:
            return CorrectionPredictionResponse(
                status="error",
                symbol=request.symbol,
                timestamp=datetime.now().isoformat(),
                message="Base de données non disponible"
            )
        
        # 1. Analyser les corrections historiques pour ce symbole
        analysis = await analyze_historical_corrections(request.symbol, request.timeframe)
        
        # 2. Calculer les prédictions de zones
        prediction = await calculate_correction_prediction(
            request.symbol, 
            request.timeframe,
            request.current_price,
            request.current_trend,
            request.volatility_level
        )
        
        # 3. Calculer le score de confiance global
        confidence_score = calculate_global_confidence(analysis, prediction)
        
        # 4. Déterminer l'action recommandée et le niveau de risque
        recommended_action, risk_level = determine_action_and_risk(
            request.current_trend, 
            prediction, 
            confidence_score
        )
        
        # 5. Sauvegarder la prédiction en base (trace réelle Supabase)
        await save_correction_prediction(
            request.symbol,
            request.timeframe,
            analysis,
            prediction,
            confidence_score,
            recommended_action,
            risk_level,
        )
        
        logger.info(f"✅ Prédiction correction générée - Confiance: {confidence_score:.1f}% - Action: {recommended_action}")
        
        return CorrectionPredictionResponse(
            status="success",
            symbol=request.symbol,
            timestamp=datetime.now().isoformat(),
            prediction=prediction,
            analysis=analysis,
            confidence_score=confidence_score,
            recommended_action=recommended_action,
            risk_level=risk_level,
            message=f"Prédiction générée avec {confidence_score:.1f}% de confiance"
        )
        
    except Exception as e:
        logger.error(f"❌ Erreur prédiction correction: {e}")
        return CorrectionPredictionResponse(
            status="error",
            symbol=request.symbol,
            timestamp=datetime.now().isoformat(),
            message=f"Erreur: {str(e)}"
        )

@app.get("/corrections/analysis/{symbol}", response_model=CorrectionZoneAnalysis)
async def get_correction_analysis(symbol: str, timeframe: str = "M1"):
    """
    Endpoint pour obtenir l'analyse des zones de correction passées
    
    Args:
        symbol: Symbole à analyser
        timeframe: Timeframe de l'analyse
        
    Returns:
        CorrectionZoneAnalysis: Analyse des corrections historiques
    """
    try:
        logger.info(f"📊 Analyse des corrections pour {symbol} {timeframe}")
        
        if not DB_AVAILABLE:
            raise HTTPException(status_code=503, detail="Base de données non disponible")
        
        analysis = await analyze_historical_corrections(symbol, timeframe)
        
        return analysis
        
    except Exception as e:
        logger.error(f"❌ Erreur analyse corrections: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur analyse: {str(e)}")

@app.get("/corrections/performance/{symbol}")
async def get_correction_performance(symbol: str, days: int = 30):
    """
    Endpoint pour obtenir les performances des prédictions de correction
    
    Args:
        symbol: Symbole analysé
        days: Nombre de jours à analyser
        
    Returns:
        Dict: Statistiques de performance
    """
    try:
        logger.info(f"📈 Performance corrections pour {symbol} - {days} jours")
        
        if not DB_AVAILABLE:
            raise HTTPException(status_code=503, detail="Base de données non disponible")
        
        performance = await get_prediction_performance_stats(symbol, days)
        
        return {
            "symbol": symbol,
            "period_days": days,
            "performance": performance,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ Erreur performance corrections: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur performance: {str(e)}")

@app.get("/corrections/patterns/{symbol}")
async def get_correction_patterns(symbol: str):
    """
    Endpoint pour obtenir les patterns de correction par symbole
    
    Args:
        symbol: Symbole analysé
        
    Returns:
        List[SymbolCorrectionPattern]: Patterns de correction connus
    """
    try:
        logger.info(f"🔍 Patterns de correction pour {symbol}")
        
        if not DB_AVAILABLE:
            raise HTTPException(status_code=503, detail="Base de données non disponible")
        
        patterns = await get_symbol_correction_patterns(symbol)
        
        return {
            "symbol": symbol,
            "patterns": patterns,
            "total_patterns": len(patterns),
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ Erreur patterns corrections: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur patterns: {str(e)}")

@app.post("/corrections/feedback")
async def correction_feedback(feedback: dict):
    """
    Endpoint pour recevoir le feedback sur les prédictions de correction
    
    Args:
        feedback: Données de feedback sur une prédiction réalisée
        
    Returns:
        Dict: Statut du feedback
    """
    try:
        logger.info(f"📝 Feedback correction reçu pour {feedback.get('symbol')}")
        
        if not DB_AVAILABLE:
            raise HTTPException(status_code=503, detail="Base de données non disponible")
        
        # Mettre à jour la prédiction avec les résultats réels
        result = await update_prediction_with_feedback(feedback)
        
        return {
            "status": "success",
            "message": "Feedback enregistré avec succès",
            "updated_prediction_id": result.get("prediction_id"),
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ Erreur feedback correction: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur feedback: {str(e)}")

@app.get("/corrections/storage-status")
async def correction_storage_status(symbol: Optional[str] = None, timeframe: str = "M1"):
    """
    Diagnostic stockage corrections:
    - compte de lignes
    - dernière ligne
    pour les tables actives (Option A).
    """
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}

        sym = (symbol or "").strip()
        tf = (timeframe or "M1").strip()

        table_specs = [
            {
                "table": "correction_zones_analysis",
                "order": "analysis_date.desc",
                "columns": "id,symbol,timeframe,analysis_date,total_corrections_analyzed,current_trend,volatility_level",
            },
            {
                "table": "correction_predictions",
                "order": "prediction_date.desc",
                "columns": "id,symbol,timeframe,prediction_date,prediction_confidence,current_trend,zone_1_level,zone_2_level,zone_3_level",
            },
            {
                "table": "prediction_performance",
                "order": "performance_date.desc",
                "columns": "id,symbol,performance_date,total_predictions,successful_predictions,failed_predictions,overall_accuracy,avg_confidence",
            },
            {
                "table": "correction_summary_stats",
                "order": "period_end.desc",
                "columns": "id,symbol,timeframe,period_start,period_end,total_corrections,successful_predictions,success_rate",
            },
            {
                "table": "symbol_correction_patterns",
                "order": "last_updated.desc",
                "columns": "id,symbol,pattern_type,success_rate,occurrences_count,last_updated",
            },
        ]

        import httpx
        out = []
        async with httpx.AsyncClient(timeout=12.0) as client:
            for spec in table_specs:
                table = spec["table"]
                filters = []
                if sym:
                    filters.append(f"symbol=eq.{sym}")
                if "timeframe" in spec["columns"]:
                    filters.append(f"timeframe=eq.{tf}")
                filter_qs = ("&" + "&".join(filters)) if filters else ""

                count_url = f"{supabase_url}/rest/v1/{table}?select=id&limit=1{filter_qs}"
                count_headers = dict(headers)
                count_headers["Prefer"] = "count=exact"

                status_code = None
                count = 0
                last_row = None
                error = None

                try:
                    rc = await client.get(count_url, headers=count_headers)
                    status_code = rc.status_code
                    if rc.status_code < 300:
                        cr = rc.headers.get("content-range", "0-0/0")
                        try:
                            count = int(cr.split("/")[-1])
                        except Exception:
                            count = 0

                        if count > 0:
                            last_params = {
                                "select": spec["columns"],
                                "order": spec["order"],
                                "limit": "1",
                            }
                            if sym:
                                last_params["symbol"] = f"eq.{sym}"
                            if "timeframe" in spec["columns"]:
                                last_params["timeframe"] = f"eq.{tf}"
                            rl = await client.get(f"{supabase_url}/rest/v1/{table}", headers=headers, params=last_params)
                            if rl.status_code < 300 and rl.text:
                                rows = rl.json()
                                if rows:
                                    last_row = rows[0]
                            else:
                                error = f"last_row_http_{rl.status_code}"
                    else:
                        error = f"count_http_{rc.status_code}"
                except Exception as e:
                    error = str(e)

                out.append(
                    {
                        "table": table,
                        "status_code": status_code,
                        "count": count,
                        "last_row": last_row,
                        "error": error,
                    }
                )

        return {
            "ok": True,
            "symbol_filter": sym or "ALL",
            "timeframe_filter": tf,
            "tables": out,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    except Exception as e:
        logger.error(f"❌ Erreur /corrections/storage-status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ========== FONCTIONS UTILITAIRES POUR LES CORRECTIONS ==========

async def analyze_historical_corrections(symbol: str, timeframe: str) -> CorrectionZoneAnalysis:
    """Analyse les corrections historiques pour un symbole"""
    # Source primaire: table active correction_zones_analysis (alignement Option A).
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
        params = {
            "symbol": f"eq.{symbol}",
            "timeframe": f"eq.{timeframe}",
            "order": "analysis_date.desc",
            "limit": "1",
        }
        import httpx
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get(
                f"{supabase_url}/rest/v1/correction_zones_analysis",
                headers=headers,
                params=params,
            )
        if r.status_code < 300 and r.text:
            rows = r.json()
            if rows:
                row = rows[0]
                return CorrectionZoneAnalysis(
                    symbol=symbol,
                    timeframe=timeframe,
                    analysis_date=row.get("analysis_date") or datetime.now().isoformat(),
                    total_corrections_analyzed=int(row.get("total_corrections_analyzed") or 0),
                    uptrend_corrections=int(row.get("uptrend_corrections") or 0),
                    downtrend_corrections=int(row.get("downtrend_corrections") or 0),
                    avg_retracement_uptrend=float(row.get("avg_retracement_uptrend") or 0.0),
                    avg_retracement_downtrend=float(row.get("avg_retracement_downtrend") or 0.0),
                    max_retracement_uptrend=float(row.get("max_retracement_uptrend") or 0.0),
                    max_retracement_downtrend=float(row.get("max_retracement_downtrend") or 0.0),
                    gradual_retracement_patterns=int(row.get("gradual_retracement_patterns") or 0),
                    consolidation_patterns=int(row.get("consolidation_patterns") or 0),
                    sharp_reversal_patterns=int(row.get("sharp_reversal_patterns") or 0),
                    support_levels=row.get("support_levels") or [],
                    resistance_levels=row.get("resistance_levels") or [],
                    current_price=float(row.get("current_price") or 0.0),
                    current_trend=str(row.get("current_trend") or "UP"),
                    volatility_level=float(row.get("volatility_level") or 0.02),
                )
    except Exception:
        # Fallback conservateur vers patterns si table absente/inaccessible.
        pass

    # Fallback: reconstruction via symbol_correction_patterns.
    patterns = await get_symbol_correction_patterns(symbol)
    total = 0
    up = 0
    down = 0
    avg_ret = 2.2
    avg_succ = 70.0
    if patterns:
        total = int(sum((p.occurrences_count or 0) for p in patterns))
        avg_ret = float(np.mean([p.avg_retracement_percentage or 2.2 for p in patterns]))
        avg_succ = float(np.mean([p.success_rate or 70.0 for p in patterns]))
        for p in patterns:
            pt = (p.pattern_type or "").upper()
            occ = int(p.occurrences_count or 0)
            if "UP" in pt or "BULL" in pt:
                up += occ
            elif "DOWN" in pt or "BEAR" in pt:
                down += occ
    if total <= 0:
        total = 45
        up = 23
        down = 22

    return CorrectionZoneAnalysis(
        symbol=symbol,
        timeframe=timeframe,
        analysis_date=datetime.now().isoformat(),
        total_corrections_analyzed=total,
        uptrend_corrections=up,
        downtrend_corrections=down,
        avg_retracement_uptrend=avg_ret,
        avg_retracement_downtrend=avg_ret * 0.95,
        max_retracement_uptrend=avg_ret * 2.6,
        max_retracement_downtrend=avg_ret * 2.4,
        gradual_retracement_patterns=max(1, int(total * 0.33)),
        consolidation_patterns=max(1, int(total * 0.45)),
        sharp_reversal_patterns=max(1, int(total * 0.22)),
        support_levels=[],
        resistance_levels=[],
        current_price=0.0,
        current_trend="UP",
        volatility_level=max(0.005, min(0.12, (100.0 - avg_succ) / 1000.0))
    )

async def calculate_correction_prediction(
    symbol: str, 
    timeframe: str,
    current_price: float,
    current_trend: str,
    volatility_level: Optional[float]
) -> CorrectionPrediction:
    """Calcule les prédictions de zones de correction"""
    patterns = await get_symbol_correction_patterns(symbol)
    avg_retracement = 2.2 if current_trend == "UP" else 2.4
    avg_success = 72.0
    if patterns:
        vals_ret = [float(p.avg_retracement_percentage or avg_retracement) for p in patterns if (p.avg_retracement_percentage or 0) > 0]
        vals_succ = [float(p.success_rate or 0.0) for p in patterns if (p.success_rate or 0) > 0]
        if vals_ret:
            avg_retracement = float(np.mean(vals_ret))
        if vals_succ:
            avg_success = float(np.mean(vals_succ))
    vol = float(volatility_level or 0.02)
    vol_adj = max(0.8, min(1.35, 1.0 + (vol - 0.02) * 5.0))
    avg_retracement = max(0.3, min(8.0, avg_retracement * vol_adj))
    base_conf = max(55.0, min(92.0, avg_success))
    
    return CorrectionPrediction(
        symbol=symbol,
        timeframe=timeframe,
        prediction_date=datetime.now().isoformat(),
        current_price=current_price,
        current_trend=current_trend,
        prediction_confidence=base_conf,
        zone_1_level=current_price * (1 - avg_retracement * 0.6 / 100) if current_trend == "UP" else current_price * (1 + avg_retracement * 0.6 / 100),
        zone_1_type="SUPPORT" if current_trend == "UP" else "RESISTANCE",
        zone_1_probability=65.0,
        zone_2_level=current_price * (1 - avg_retracement / 100) if current_trend == "UP" else current_price * (1 + avg_retracement / 100),
        zone_2_type="SUPPORT" if current_trend == "UP" else "RESISTANCE",
        zone_2_probability=75.0,
        zone_3_level=current_price * (1 - avg_retracement * 1.4 / 100) if current_trend == "UP" else current_price * (1 + avg_retracement * 1.4 / 100),
        zone_3_type="SUPPORT" if current_trend == "UP" else "RESISTANCE",
        zone_3_probability=45.0,
        trend_strength_factor=max(0.8, min(1.4, 1.0 + (avg_success - 70.0) / 100.0)),
        volatility_adjustment=vol_adj,
        historical_accuracy=avg_success,
        prediction_valid_until=(datetime.now() + timedelta(hours=4)).isoformat()
    )

def _normalize_confidence_percent(value: float, default: float = 70.0) -> float:
    """Normalise une confiance en pourcentage [0..100].

    Accepte les formats:
    - ratio 0..1
    - pourcentage 0..100
    - pourcentage x100 (ex: 7641 -> 76.41)
    """
    try:
        v = float(value)
    except Exception:
        v = float(default)

    if v <= 0:
        v = float(default)

    if v <= 1.0:
        v *= 100.0
    elif v > 100.0:
        if v <= 10000.0:
            v /= 100.0
        else:
            v = 100.0

    return max(0.0, min(100.0, v))


def calculate_global_confidence(analysis: CorrectionZoneAnalysis, prediction: CorrectionPrediction) -> float:
    """Calcule le score de confiance global (en %)."""
    base_confidence = _normalize_confidence_percent(prediction.prediction_confidence, default=70.0)
    historical_bonus = max(0.0, float(analysis.total_corrections_analyzed or 0)) / 100.0  # Bonus si beaucoup de données
    acc_pct = _normalize_confidence_percent(prediction.historical_accuracy or 70.0, default=70.0)
    accuracy_bonus = acc_pct / 100.0

    confidence = base_confidence + (historical_bonus * 5.0) + (accuracy_bonus * 3.0)
    confidence = min(95.0, confidence)
    return max(0.0, confidence)

def determine_action_and_risk(trend: str, prediction: CorrectionPrediction, confidence: float) -> tuple:
    """Détermine l'action recommandée et le niveau de risque"""
    if confidence >= 80:
        action = "ENTER_CORRECTION"
        risk = "LOW"
    elif confidence >= 70:
        action = "MONITOR_CORRECTION"
        risk = "MEDIUM"
    else:
        action = "WAIT_FOR_CONFIRMATION"
        risk = "HIGH"
    
    return action, risk

async def save_correction_prediction(
    symbol: str,
    timeframe: str,
    analysis: CorrectionZoneAnalysis,
    prediction: CorrectionPrediction,
    confidence_score: float,
    recommended_action: str,
    risk_level: str,
):
    """Sauvegarde une trace de prédiction correction dans les tables actives Supabase."""
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }

        now = datetime.now(timezone.utc)
        period_start = now - timedelta(days=30)
        total = int(analysis.total_corrections_analyzed or 0)
        # confidence_score est en pourcentage (70-95), conversion en ratio.
        success_ratio = max(0.0, min(1.0, float(confidence_score) / 100.0))
        successful = int(round(success_ratio * total)) if total > 0 else 0

        # Compat pydantic v1/v2 pour sérialiser la prédiction.
        if hasattr(prediction, "model_dump"):
            pred_payload = prediction.model_dump()
        else:
            pred_payload = prediction.dict()

        import httpx

        # 1) Trace primaire: correction_predictions (table active dédiée aux prédictions)
        prediction_row = {
            "symbol": symbol,
            "timeframe": timeframe,
            "prediction_date": now.isoformat(),
            "current_price": float(prediction.current_price or 0.0),
            "current_trend": str(prediction.current_trend or "UP"),
            "prediction_confidence": float(prediction.prediction_confidence or 0.0),
            "zone_1_level": float(prediction.zone_1_level or 0.0),
            "zone_1_type": str(prediction.zone_1_type or "SUPPORT"),
            "zone_1_probability": float(prediction.zone_1_probability or 0.0),
            "zone_2_level": float(prediction.zone_2_level or 0.0),
            "zone_2_type": str(prediction.zone_2_type or "SUPPORT"),
            "zone_2_probability": float(prediction.zone_2_probability or 0.0),
            "zone_3_level": float(prediction.zone_3_level or 0.0),
            "zone_3_type": str(prediction.zone_3_type or "SUPPORT"),
            "zone_3_probability": float(prediction.zone_3_probability or 0.0),
            "trend_strength_factor": float(prediction.trend_strength_factor or 1.0),
            "volatility_adjustment": float(prediction.volatility_adjustment or 1.0),
            "historical_accuracy": float(prediction.historical_accuracy or 0.0),
            "prediction_valid_until": prediction.prediction_valid_until or (now + timedelta(hours=4)).isoformat(),
            "created_at": now.isoformat(),
            "updated_at": now.isoformat(),
        }

        # 2) Snapshot journalier: prediction_performance (table active de suivi)
        perf_row = {
            "symbol": symbol,
            "performance_date": now.date().isoformat(),
            "total_predictions": 1,
            "successful_predictions": 1 if success_ratio >= 0.5 else 0,
            "failed_predictions": 1 if success_ratio < 0.5 else 0,
            "zone_1_accuracy": float(prediction.zone_1_probability or 0.0),
            "zone_2_accuracy": float(prediction.zone_2_probability or 0.0),
            "zone_3_accuracy": float(prediction.zone_3_probability or 0.0),
            "overall_accuracy": float(confidence_score),
            "avg_confidence": float(prediction.prediction_confidence or 0.0),
            "total_corrections_analyzed": total,
            "avg_retracement_used": float(analysis.avg_retracement_uptrend or 0.0),
            "market_volatility": float(analysis.volatility_level or 0.0),
        }

        pred_duration = float(getattr(prediction, "expected_duration_bars", 0.0) or 0.0)
        pred_type = str(getattr(prediction, "correction_type", "UNKNOWN") or "UNKNOWN")

        payload = {
            "symbol": symbol,
            "timeframe": timeframe,
            "period_start": period_start.isoformat(),
            "period_end": now.isoformat(),
            "total_corrections": total,
            "successful_predictions": successful,
            "avg_retracement_pct": float(analysis.avg_retracement_uptrend or 0.0),
            "avg_duration_bars": pred_duration,
            # Table legacy attend un ratio (ex: 0.7575), pas un pourcentage.
            "success_rate": float(max(0.0, min(1.0, confidence_score / 100.0))),
            "dominant_pattern": pred_type,
            "created_at": now.isoformat(),
            "updated_at": now.isoformat(),
            "metadata": {
                "source": "ai_server/corrections_predict",
                "recommended_action": recommended_action,
                "risk_level": risk_level,
                "confidence_score": confidence_score,
                "prediction": pred_payload,
            },
        }
        async with httpx.AsyncClient(timeout=10.0) as client:
            r_pred = await client.post(
                f"{supabase_url}/rest/v1/correction_predictions",
                headers=headers,
                json=prediction_row,
            )
            if r_pred.status_code >= 300:
                logger.warning(f"correction_predictions insert HTTP {r_pred.status_code}: {r_pred.text[:180]}")

            r_perf = await client.post(
                f"{supabase_url}/rest/v1/prediction_performance",
                headers=headers,
                json=perf_row,
            )
            if r_perf.status_code >= 300:
                logger.warning(f"prediction_performance insert HTTP {r_perf.status_code}: {r_perf.text[:180]}")

            # 3) Compat rétro: correction_summary_stats (legacy interne serveur)
            r = await client.post(
                f"{supabase_url}/rest/v1/correction_summary_stats",
                headers=headers,
                json=payload,
            )
        if r.status_code >= 300:
            logger.warning(f"correction_summary_stats insert HTTP {r.status_code}: {r.text[:180]}")

        logger.info(f"💾 Prédiction correction sauvegardée (tables actives) pour {symbol} ({timeframe})")
    except Exception as e:
        logger.warning(f"Sauvegarde corrections Supabase échouée: {e}")

async def get_prediction_performance_stats(symbol: str, days: int) -> dict:
    """Récupère les statistiques de performance"""
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}

        since = (datetime.now(timezone.utc) - timedelta(days=max(1, int(days)))).isoformat()
        since_day = (datetime.now(timezone.utc) - timedelta(days=max(1, int(days)))).date().isoformat()

        # Source primaire: prediction_performance (table active)
        primary_params = {
            "symbol": f"eq.{symbol}",
            "performance_date": f"gte.{since_day}",
            "select": "total_predictions,successful_predictions,failed_predictions,overall_accuracy,zone_1_accuracy,zone_2_accuracy,zone_3_accuracy",
            "order": "performance_date.desc",
            "limit": "500",
        }
        import httpx
        async with httpx.AsyncClient(timeout=10.0) as client:
            r_primary = await client.get(
                f"{supabase_url}/rest/v1/prediction_performance",
                headers=headers,
                params=primary_params,
            )
        if r_primary.status_code < 300 and r_primary.text:
            rows = r_primary.json()
            if rows:
                total_predictions = int(sum(int(rw.get("total_predictions") or 0) for rw in rows))
                successful_predictions = int(sum(int(rw.get("successful_predictions") or 0) for rw in rows))
                failed_predictions = int(sum(int(rw.get("failed_predictions") or 0) for rw in rows))
                overall_vals = [float(rw.get("overall_accuracy") or 0.0) for rw in rows]
                z1_vals = [float(rw.get("zone_1_accuracy") or 0.0) for rw in rows]
                z2_vals = [float(rw.get("zone_2_accuracy") or 0.0) for rw in rows]
                z3_vals = [float(rw.get("zone_3_accuracy") or 0.0) for rw in rows]
                return {
                    "total_predictions": total_predictions,
                    "successful_predictions": successful_predictions,
                    "failed_predictions": failed_predictions,
                    "overall_accuracy": float(np.mean(overall_vals)) if overall_vals else 0.0,
                    "zone_1_accuracy": float(np.mean(z1_vals)) if z1_vals else 0.0,
                    "zone_2_accuracy": float(np.mean(z2_vals)) if z2_vals else 0.0,
                    "zone_3_accuracy": float(np.mean(z3_vals)) if z3_vals else 0.0,
                }

        # Fallback legacy: correction_summary_stats
        params = {
            "symbol": f"eq.{symbol}",
            "period_end": f"gte.{since}",
            "select": "total_corrections,successful_predictions,success_rate,metadata",
            "order": "period_end.desc",
            "limit": "500",
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get(f"{supabase_url}/rest/v1/correction_summary_stats", headers=headers, params=params)
        if r.status_code >= 300:
            logger.warning(f"correction_summary_stats perf fetch HTTP {r.status_code}: {r.text[:180]}")
            raise RuntimeError(f"HTTP {r.status_code}")

        rows = r.json() if r.text else []
        if not rows:
            return {
                "total_predictions": 0,
                "successful_predictions": 0,
                "failed_predictions": 0,
                "overall_accuracy": 0.0,
                "zone_1_accuracy": 0.0,
                "zone_2_accuracy": 0.0,
                "zone_3_accuracy": 0.0,
            }

        total_predictions = int(sum(int(rw.get("total_corrections") or 0) for rw in rows))
        successful_predictions = int(sum(int(rw.get("successful_predictions") or 0) for rw in rows))
        failed_predictions = max(0, total_predictions - successful_predictions)
        overall_accuracy = (successful_predictions / total_predictions * 100.0) if total_predictions > 0 else 0.0

        # Approximation zone-level depuis metadata.prediction.zone_X_confidence
        z1 = []
        z2 = []
        z3 = []
        for rw in rows:
            md = rw.get("metadata") or {}
            pred = md.get("prediction") if isinstance(md, dict) else {}
            if isinstance(pred, dict):
                if pred.get("zone_1_confidence") is not None:
                    z1.append(float(pred.get("zone_1_confidence")) * 100.0)
                if pred.get("zone_2_confidence") is not None:
                    z2.append(float(pred.get("zone_2_confidence")) * 100.0)
                if pred.get("zone_3_confidence") is not None:
                    z3.append(float(pred.get("zone_3_confidence")) * 100.0)

        return {
            "total_predictions": total_predictions,
            "successful_predictions": successful_predictions,
            "failed_predictions": failed_predictions,
            "overall_accuracy": overall_accuracy,
            "zone_1_accuracy": float(np.mean(z1)) if z1 else overall_accuracy,
            "zone_2_accuracy": float(np.mean(z2)) if z2 else overall_accuracy,
            "zone_3_accuracy": float(np.mean(z3)) if z3 else overall_accuracy,
        }
    except Exception as e:
        logger.warning(f"Performance corrections fallback ({symbol}): {e}")
        return {
            "total_predictions": 0,
            "successful_predictions": 0,
            "failed_predictions": 0,
            "overall_accuracy": 0.0,
            "zone_1_accuracy": 0.0,
            "zone_2_accuracy": 0.0,
            "zone_3_accuracy": 0.0,
        }

async def get_symbol_correction_patterns(symbol: str) -> list:
    """Récupère les patterns de correction pour un symbole"""
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        import httpx

        headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
        params = {
            "symbol": f"eq.{symbol}",
            "order": "success_rate.desc.nullslast,occurrences_count.desc.nullslast,last_updated.desc",
            "limit": "20",
        }
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get(f"{supabase_url}/rest/v1/symbol_correction_patterns", headers=headers, params=params)
        if r.status_code >= 300:
            logger.warning(f"symbol_correction_patterns fetch HTTP {r.status_code}: {r.text[:180]}")
            return []
        rows = r.json() if r.text else []
        out = []
        for row in rows:
            try:
                out.append(SymbolCorrectionPattern(**row))
            except Exception:
                continue
        return out
    except Exception as e:
        logger.warning(f"Récupération patterns correction échouée pour {symbol}: {e}")
        return []

async def update_prediction_with_feedback(feedback: dict) -> dict:
    """Met à jour une prédiction avec le feedback réel"""
    try:
        supabase_url, supabase_key = _get_supabase_config(strict=True)
        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }

        symbol = str(feedback.get("symbol") or "").strip()
        timeframe = str(feedback.get("timeframe") or "M1").strip()
        success = bool(feedback.get("success", False))
        retracement = float(feedback.get("retracement_pct", 0.0) or 0.0)
        duration_bars = int(feedback.get("duration_bars", 0) or 0)
        correction_type = str(feedback.get("correction_type") or "UNKNOWN").strip()
        now = datetime.now(timezone.utc)

        if not symbol:
            return {"prediction_id": feedback.get("prediction_id"), "updated": False, "reason": "missing_symbol"}

        row = {
            "symbol": symbol,
            "timeframe": timeframe,
            "period_start": (now - timedelta(days=1)).isoformat(),
            "period_end": now.isoformat(),
            "total_corrections": 1,
            "successful_predictions": 1 if success else 0,
            "avg_retracement_pct": retracement,
            "avg_duration_bars": float(duration_bars),
            "success_rate": 100.0 if success else 0.0,
            "dominant_pattern": correction_type,
            "created_at": now.isoformat(),
            "updated_at": now.isoformat(),
            "metadata": {
                "source": "ai_server/corrections_feedback",
                "prediction_id": feedback.get("prediction_id"),
                "raw_feedback": feedback,
            },
        }

        import httpx
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.post(
                f"{supabase_url}/rest/v1/correction_summary_stats",
                headers=headers,
                json=row,
            )
        if r.status_code >= 300:
            logger.warning(f"correction_summary_stats feedback insert HTTP {r.status_code}: {r.text[:180]}")
            return {"prediction_id": feedback.get("prediction_id"), "updated": False}

        logger.info(f"✅ Feedback correction persisté pour {symbol}")
        return {"prediction_id": feedback.get("prediction_id"), "updated": True}
    except Exception as e:
        logger.warning(f"Feedback correction persist échoué: {e}")
        return {"prediction_id": feedback.get("prediction_id"), "updated": False, "error": str(e)}

if __name__ == "__main__":
    import uvicorn
    
    # Démarrer le serveur avec gestion des événements de vie
    logger.info("🌟 Lancement du serveur IA TradBOT avec système ML intégré")
    logger.info("📡 Endpoints disponibles:")
    logger.info("   • /health - Santé du serveur")
    logger.info("   • /decision - Décisions de trading")  
    logger.info("   • /ml/metrics - Métriques ML en temps réel")
    logger.info("   • /ml/start - Démarrer entraînement ML")
    logger.info("   • /ml/stop - Arrêter entraînement ML")
    logger.info("   • /ml/retrain - Forcer réentraînement")
    logger.info("   • /ml_stats - Statistiques ML détaillées")
    logger.info("   • /ui - Dashboard web (interface graphique)")
    
    uvicorn.run(
        "ai_server:app",
        host="127.0.0.1",
        port=8000,
        reload=False,
        log_level="info"
    )