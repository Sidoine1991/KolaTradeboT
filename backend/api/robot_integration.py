"""
API d'intégration pour le robot F_INX_robot4.mq5
Endpoints spécialisés pour la communication avec le robot de trading
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends
from pydantic import BaseModel
from typing import Dict, List, Optional, Any
import json
import time
import logging
from datetime import datetime, timedelta
import sys
import os
import numpy as np
import pandas as pd
from typing import Tuple, Dict, List

# Ajout du chemin racine
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

# Imports des modules existants
from backend.mt5_connector import get_ohlc, get_current_price, get_all_symbols, get_symbol_info, get_spread
from backend.technical_analysis import add_technical_indicators, calculate_rsi, calculate_atr, calculate_macd, calculate_ema, calculate_bollinger_bands
from backend.spike_detector import detect_spikes, predict_spike_ml
from backend.advanced_ml_predictor import AdvancedMLPredictor
from backend.multi_timeframe_signal_generator import MultiTimeframeSignalGenerator
from backend.indicators_modern import (
    compute_market_structure,
    compute_smart_money,
    compute_supertrend,
    compute_vwap,
    compute_squeeze
)

logger = logging.getLogger("robot_integration")

router = APIRouter(prefix="/robot", tags=["robot"])

# Cache pour stocker le symbole sélectionné et son analyse
selected_symbol_cache = {
    'symbol': None,
    'analysis': None,
    'timestamp': 0,
    'expires_in': 300,  # 5 minutes de cache
    'last_trade_result': None,  # Dernier résultat de trade (gagnant/perdant)
    'consecutive_losses': 0,   # Nombre de pertes consécutives
    'last_scan_time': 0,       # Dernier scan complet
    'symbol_scores': {},       # Scores des symboles analysés
    'symbol_metrics': {}       # Métriques détaillées par symbole
}

# Variables globales pour le cache
prediction_cache = {}
last_signal_time = {}
signal_cooldown = 60  # 1 minute entre les signaux

# Modèles de données
class RobotDecisionRequest(BaseModel):
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
    vwap: Optional[float] = None
    vwap_distance: Optional[float] = None
    above_vwap: Optional[bool] = None
    supertrend_trend: Optional[int] = None
    supertrend_line: Optional[float] = None
    volatility_regime: Optional[int] = None
    volatility_ratio: Optional[float] = None

class RobotDecisionResponse(BaseModel):
    action: str  # "buy", "sell", "hold"
    confidence: float  # 0.0-1.0
    reason: str
    spike_prediction: bool = False
    spike_zone_price: Optional[float] = None
    spike_direction: Optional[bool] = None
    early_spike_warning: bool = False
    early_spike_zone_price: Optional[float] = None
    early_spike_direction: Optional[bool] = None
    buy_zone_low: Optional[float] = None
    buy_zone_high: Optional[float] = None
    sell_zone_low: Optional[float] = None
    sell_zone_high: Optional[float] = None
    technical_indicators: Optional[Dict[str, Any]] = None
    market_structure: Optional[Dict[str, Any]] = None
    smart_money: Optional[Dict[str, Any]] = None

class RobotParameterUpdate(BaseModel):
    """Modèle pour la mise à jour des paramètres du robot"""
    parameter_name: str
    parameter_value: Any
    parameter_type: str = "auto"  # auto, int, float, bool, str
    restart_required: bool = False

class IndicatorRequest(BaseModel):
    symbol: str
    timeframe: str = "1m"
    count: int = 200

class IndicatorResponse(BaseModel):
    symbol: str
    timeframe: str
    indicators: Dict[str, Any]
    timestamp: str

# Modèles de données supplémentaires
class SymbolAnalysis(BaseModel):
    symbol: str
    score: float
    action: str
    confidence: float
    reason: str
    indicators: Dict[str, Any]
    timeframe_analysis: Dict[str, Dict[str, Any]]
    last_updated: str = datetime.now().isoformat()

class SymbolScanResponse(BaseModel):
    selected_symbol: Optional[str]
    selected_symbol_score: Optional[float]
    analysis: Optional[Dict[str, Any]]
    all_symbols: List[Dict[str, Any]]
    timestamp: str = datetime.now().isoformat()

# Dictionnaire global pour stocker les paramètres du robot
ROBOT_PARAMETERS = {
    "symbol": "Boom 1000 Index",
    "timeframe": "M1",
    "risk_per_trade": 1.0,
    "max_spread": 2.5,
    "trading_hours": {
        "start": "08:00",
        "end": "20:00"
    },
    "indicators": {
        "rsi_period": 14,
        "ema_fast": 9,
        "ema_slow": 21,
        "atr_period": 14
    },
    "trading": {
        "max_open_positions": 1,
        "trailing_stop": True,
        "break_even": True,
        "use_martingale": False
    },
    "notifications": {
        "enable_email": True,
        "enable_whatsapp": True,
        "enable_sms": False
    },
    "last_updated": datetime.now().isoformat()
}

@router.get("/config", response_model=Dict[str, Any])
async def get_robot_config():
    """
    Récupère la configuration actuelle du robot
    """
    try:
        return ROBOT_PARAMETERS
    except Exception as e:
        logger.error(f"Erreur lors de la récupération de la configuration: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/config/update")
async def update_robot_parameter(update: RobotParameterUpdate):
    """
    Met à jour un paramètre du robot en temps réel
    
    Args:
        update (RobotParameterUpdate): Les détails de la mise à jour du paramètre
        
    Returns:
        dict: Statut de la mise à jour
    """
    global ROBOT_PARAMETERS
    
    try:
        param_path = update.parameter_name.split('.')
        current = ROBOT_PARAMETERS
        
        # Parcourir le chemin du paramètre (support pour les paramètres imbriqués)
        for i, key in enumerate(param_path[:-1]):
            if key not in current:
                raise HTTPException(status_code=400, detail=f"Chemin de paramètre invalide: {'.'.join(param_path[:i+1])}")
            current = current[key]
        
        param_name = param_path[-1]
        if param_name not in current:
            raise HTTPException(status_code=400, detail=f"Paramètre inconnu: {update.parameter_name}")
        
        # Convertir la valeur selon le type spécifié
        value = update.parameter_value
        if update.parameter_type != "auto":
            try:
                if update.parameter_type == "int":
                    value = int(value)
                elif update.parameter_type == "float":
                    value = float(value)
                elif update.parameter_type == "bool":
                    if isinstance(value, str):
                        value = value.lower() in ('true', '1', 't', 'y', 'yes')
                    else:
                        value = bool(value)
                # Pour les chaînes, on laisse la valeur telle quelle
            except (ValueError, TypeError) as e:
                raise HTTPException(
                    status_code=400,
                    detail=f"Impossible de convertir la valeur '{value}' en type {update.parameter_type}"
                )
        
        # Mettre à jour la valeur
        old_value = current[param_name]
        current[param_name] = value
        
        # Mettre à jour le timestamp
        ROBOT_PARAMETERS['last_updated'] = datetime.now().isoformat()
        
        logger.info(f"Paramètre mis à jour: {update.parameter_name} = {value} (ancienne valeur: {old_value})")
        
        return {
            "status": "success",
            "message": f"Paramètre {update.parameter_name} mis à jour",
            "parameter": update.parameter_name,
            "old_value": old_value,
            "new_value": value,
            "restart_required": update.restart_required,
            "timestamp": ROBOT_PARAMETERS['last_updated']
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de la mise à jour du paramètre: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur serveur: {str(e)}")

# Initialisation des prédicteurs
try:
    ml_predictor = AdvancedMLPredictor()
    signal_generator = MultiTimeframeSignalGenerator()
    logger.info("Prédicteurs ML et générateur de signaux initialisés")
except Exception as e:
    logger.error(f"Erreur initialisation prédicteurs: {e}")
    ml_predictor = None
    signal_generator = None

@router.post("/decision", response_model=RobotDecisionResponse)
async def robot_decision(request: RobotDecisionRequest):
    """
    Endpoint principal pour les décisions du robot F_INX_robot4.mq5
    Combine IA, indicateurs techniques et analyse multi-timeframe
    """
    try:
        logger.info(f"Decision request for {request.symbol}: bid={request.bid}, ask={request.ask}")
        
        # Vérifier le cooldown pour éviter les signaux trop fréquents
        current_time = time.time()
        last_time = last_signal_time.get(request.symbol, 0)
        if current_time - last_time < signal_cooldown:
            logger.info(f"Signal en cooldown pour {request.symbol}")
            return RobotDecisionResponse(
                action="hold",
                confidence=0.1,
                reason="Signal en cooldown"
            )
        
        # Récupérer les données OHLC pour l'analyse
        df = get_ohlc(request.symbol, timeframe="1m", count=200)
        if df is None or df.empty:
            raise HTTPException(status_code=404, detail=f"Pas de données pour {request.symbol}")
        
        # Ajouter les indicateurs techniques
        df = add_technical_indicators(df)
        
        # Analyse des indicateurs avancés
        market_structure = compute_market_structure(df)
        smart_money = compute_smart_money(df)
        supertrend = compute_supertrend(df)
        vwap = compute_vwap(df)
        squeeze = compute_squeeze(df)
        
        # Détection de spikes
        spike_detected = False
        spike_prediction = False
        spike_direction = None
        spike_zone_price = None
        
        if request.is_spike_mode:
            try:
                # Détection de spikes avec le module existant
                spike_results = detect_spikes(df)
                spike_detected = spike_results.get('spike_detected', False)
                
                # Prédiction ML de spikes
                if ml_predictor:
                    spike_pred = predict_spike_ml(df, ml_predictor)
                    spike_prediction = spike_pred.get('prediction', False)
                    spike_direction = spike_pred.get('direction')
                    spike_zone_price = spike_pred.get('target_price')
                    
            except Exception as e:
                logger.warning(f"Erreur détection spikes: {e}")
        
        # Génération de signal multi-timeframe
        signal_action = "hold"
        signal_confidence = 0.5
        signal_reason = "Analyse technique"
        
        if signal_generator:
            try:
                mtf_signal = signal_generator.generate_mtf_signal(request.symbol)
                if mtf_signal:
                    signal_action = mtf_signal.get('direction', 'hold').lower()
                    signal_confidence = mtf_signal.get('confidence', 0.5) / 100
                    signal_reason = mtf_signal.get('reason', 'Signal MTF')
            except Exception as e:
                logger.warning(f"Erreur génération signal MTF: {e}")
        
        # Analyse technique locale
        current_price = (request.bid + request.ask) / 2
        
        # RSI
        rsi_signal = "neutral"
        if 'rsi_14' in df.columns:
            rsi_value = df['rsi_14'].iloc[-1]
            if rsi_value < 30:
                rsi_signal = "oversold"
            elif rsi_value > 70:
                rsi_signal = "overbought"
        
        # EMA
        ema_signal = "neutral"
        if 'ema_20' in df.columns and 'ema_50' in df.columns:
            ema_20 = df['ema_20'].iloc[-1]
            ema_50 = df['ema_50'].iloc[-1]
            if ema_20 > ema_50 and current_price > ema_20:
                ema_signal = "bullish"
            elif ema_20 < ema_50 and current_price < ema_20:
                ema_signal = "bearish"
        
        # Combinaison des signaux
        final_action = "hold"
        final_confidence = signal_confidence
        final_reason = signal_reason
        
        # Priorité aux signaux de spikes si mode spike
        if request.is_spike_mode and (spike_detected or spike_prediction):
            if spike_direction:  # True = BUY, False = SELL
                final_action = "buy" if spike_direction else "sell"
            else:
                final_action = "buy" if rsi_signal == "oversold" else "sell"
            final_confidence = max(final_confidence, 0.8)
            final_reason = "Signal de spike détecté"
        else:
            # Logique de trading normal
            if signal_action != "hold":
                final_action = signal_action
                final_confidence = signal_confidence
                final_reason = signal_reason
            elif ema_signal != "neutral":
                final_action = "buy" if ema_signal == "bullish" else "sell"
                final_confidence = 0.6
                final_reason = f"Signal EMA {ema_signal}"
        
        # Calcul des zones d'achat/vente
        atr_value = request.atr
        buy_zone_low = current_price - (atr_value * 1.5)
        buy_zone_high = current_price - (atr_value * 0.5)
        sell_zone_low = current_price + (atr_value * 0.5)
        sell_zone_high = current_price + (atr_value * 1.5)
        
        # Mettre à jour le cooldown
        last_signal_time[request.symbol] = current_time
        
        # Construire la réponse
        response = RobotDecisionResponse(
            action=final_action,
            confidence=final_confidence,
            reason=final_reason,
            spike_prediction=spike_prediction,
            spike_zone_price=spike_zone_price,
            spike_direction=spike_direction,
            buy_zone_low=buy_zone_low,
            buy_zone_high=buy_zone_high,
            sell_zone_low=sell_zone_low,
            sell_zone_high=sell_zone_high,
            technical_indicators={
                "rsi": rsi_signal,
                "ema": ema_signal,
                "supertrend": supertrend,
                "vwap": vwap,
                "squeeze": squeeze
            },
            market_structure=market_structure,
            smart_money=smart_money
        )
        
        logger.info(f"Decision for {request.symbol}: {final_action} (conf: {final_confidence:.2f})")
        return response
        
    except Exception as e:
        logger.error(f"Erreur dans robot_decision: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/indicators/{symbol}", response_model=IndicatorResponse)
async def get_robot_indicators(symbol: str, timeframe: str = "1m", count: int = 200):
    """
    Retourne les indicateurs techniques pour le robot
    """
    try:
        df = get_ohlc(symbol, timeframe=timeframe, count=count)
        if df is None or df.empty:
            raise HTTPException(status_code=404, detail=f"Pas de données pour {symbol}")
        
        # Ajouter les indicateurs techniques
        df = add_technical_indicators(df)
        
        # Indicateurs avancés
        market_structure = compute_market_structure(df)
        smart_money = compute_smart_money(df)
        supertrend = compute_supertrend(df)
        vwap = compute_vwap(df)
        squeeze = compute_squeeze(df)
        
        # Extraire les dernières valeurs
        latest = df.iloc[-1]
        
        indicators = {
            "basic": {
                "rsi": latest.get('rsi_14', 50),
                "macd": latest.get('macd', 0),
                "macd_signal": latest.get('macd_signal', 0),
                "macd_histogram": latest.get('macd_histogram', 0),
                "bb_upper": latest.get('bb_upper', 0),
                "bb_middle": latest.get('bb_middle', 0),
                "bb_lower": latest.get('bb_lower', 0),
                "atr": latest.get('atr_14', 0),
                "volume": latest.get('volume', 0)
            },
            "ema": {
                "ema_20": latest.get('ema_20', 0),
                "ema_50": latest.get('ema_50', 0),
                "ema_200": latest.get('ema_200', 0)
            },
            "advanced": {
                "market_structure": market_structure,
                "smart_money": smart_money,
                "supertrend": supertrend,
                "vwap": vwap,
                "squeeze": squeeze
            }
        }
        
        return IndicatorResponse(
            symbol=symbol,
            timeframe=timeframe,
            indicators=indicators,
            timestamp=datetime.now().isoformat()
        )
        
    except Exception as e:
        logger.error(f"Erreur dans get_robot_indicators: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/spike-analysis/{symbol}")
async def get_spike_analysis(symbol: str, timeframe: str = "1m", count: int = 200):
    """
    Analyse spécialisée pour la détection de spikes
    """
    try:
        df = get_ohlc(symbol, timeframe=timeframe, count=count)
        if df is None or df.empty:
            raise HTTPException(status_code=404, detail=f"Pas de données pour {symbol}")
        
        # Détection de spikes
        spike_results = detect_spikes(df)
        
        # Prédiction ML si disponible
        ml_prediction = None
        if ml_predictor:
            ml_prediction = predict_spike_ml(df, ml_predictor)
        
        # Analyse de volatilité
        volatility_analysis = {
            "current_volatility": df['close'].pct_change().std(),
            "avg_volatility": df['close'].pct_change().rolling(20).std().mean(),
            "volatility_regime": "high" if df['close'].pct_change().std() > df['close'].pct_change().rolling(20).std().mean() * 1.5 else "normal"
        }
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "spike_detection": spike_results,
            "ml_prediction": ml_prediction,
            "volatility_analysis": volatility_analysis,
            "recommendation": {
                "action": "monitor" if spike_results.get('spike_detected', False) else "wait",
                "confidence": spike_results.get('confidence', 0),
                "reason": spike_results.get('reason', 'No spike detected')
            },
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Erreur dans get_spike_analysis: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/health")
async def robot_health():
    """
    Vérification de l'état des services pour le robot
    """
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "services": {
            "ml_predictor": ml_predictor is not None,
            "signal_generator": signal_generator is not None,
            "mt5_connector": True,  # À vérifier avec une vraie connexion
            "spike_detector": True,
            "indicators": True
        },
        "cache_stats": {
            "prediction_cache_size": len(prediction_cache),
            "signal_cooldown": signal_cooldown,
            "last_signals": last_signal_time
        }
    }

@router.post("/signal/validate")
async def validate_signal(symbol: str, action: str, confidence: float, reason: str):
    """
    Validation et enregistrement d'un signal généré par le robot
    """
    try:
        # Enregistrer le signal pour suivi
        signal_data = {
            "symbol": symbol,
            "action": action,
            "confidence": confidence,
            "reason": reason,
            "timestamp": datetime.now().isoformat(),
            "validated": True
        }
        
        # Ici on pourrait envoyer à une base de données ou à un système de notification
        logger.info(f"Signal validé: {signal_data}")
        
        return {
            "status": "validated",
            "signal": signal_data,
            "message": "Signal enregistré avec succès"
        }
        
    except Exception as e:
        logger.error(f"Erreur validation signal: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/config")
async def get_robot_config():
    """
    Configuration actuelle du robot
    """
    return {
        "version": "1.0.0",
        "status": "running",
        "symbols": get_all_symbols(),
        "settings": {
            "signal_cooldown": signal_cooldown,
            "cache_enabled": True,
            "max_positions": 1,
            "max_risk_per_trade": 0.02,
            "max_daily_drawdown": 0.05,
            "symbol_selection_interval": 300,  # 5 minutes
            "min_volume": 1000,  # Volume minimum pour considérer un symbole
            "max_spread_pips": 3.0,  # Spread maximum en pips
            "max_signals_per_minute": 1,
            "min_confidence_threshold": 0.6,
            "spike_mode_enabled": True,
            "timeframes": ["H1", "M5"],
            "min_rsi": 30,
            "max_rsi": 70,
            "min_atr_percent": 0.2,
            "max_atr_percent": 2.0,
            "min_confidence_score": 0.7,
            "max_consecutive_losses": 3,
            "risk_reward_ratio": 1.5
        }
    }

def calculate_symbol_score(symbol: str, config: dict) -> Tuple[float, Dict[str, Any]]:
    """
    Calcule un score pour un symbole basé sur plusieurs facteurs
    Retourne le score et les métriques détaillées
    """
    try:
        metrics = {
            'symbol': symbol,
            'score': 0.0,
            'timeframes': {},
            'indicators': {},
            'volume': 0,
            'spread': 0,
            'volatility': 0,
            'trend_strength': 0,
            'rsi': 50,
            'atr': 0,
            'recommendation': 'hold',
            'confidence': 0.0,
            'reasons': []
        }

        # Récupérer les données du symbole
        symbol_info = get_symbol_info(symbol)
        if not symbol_info:
            return 0.0, metrics

        # Vérifier le spread
        spread = get_spread(symbol)
        max_spread = config.get('max_spread_pips', 3.0)
        if spread > max_spread:
            metrics['reasons'].append(f"Spread trop élevé: {spread:.1f} pips > {max_spread} pips")
            return 0.0, metrics
        
        metrics['spread'] = spread
        
        # Vérifier le volume
        volume = symbol_info.volume
        min_volume = config.get('min_volume', 1000)
        if volume < min_volume:
            metrics['reasons'].append(f"Volume insuffisant: {volume} < {min_volume}")
            return 0.0, metrics
            
        metrics['volume'] = volume
        
        # Analyser chaque timeframe
        timeframes = config.get('timeframes', ['H1', 'M5'])
        timeframe_scores = []
        
        for tf in timeframes:
            try:
                # Récupérer les données OHLC
                df = get_ohlc(symbol, timeframe=tf, count=200)
                if df is None or df.empty:
                    continue
                
                # Calculer les indicateurs
                df = add_technical_indicators(df)
                
                # Récupérer les dernières valeurs
                latest = df.iloc[-1]
                
                # Calculer le score pour ce timeframe
                tf_score = 0.0
                tf_reasons = []
                
                # RSI
                rsi = latest.get('rsi_14', 50)
                min_rsi = config.get('min_rsi', 30)
                max_rsi = config.get('max_rsi', 70)
                
                # ATR
                atr = latest.get('atr_14', 0)
                atr_percent = (atr / latest['close']) * 100 if latest['close'] > 0 else 0
                min_atr = config.get('min_atr_percent', 0.2)
                max_atr = config.get('max_atr_percent', 2.0)
                
                # Vérifier les conditions de trading
                if rsi < min_rsi and latest['close'] < latest['ema_20']:
                    tf_score += 0.3
                    tf_reasons.append(f"RSI {rsi:.1f} < {min_rsi} (survente)")
                elif rsi > max_rsi and latest['close'] > latest['ema_20']:
                    tf_score += 0.3
                    tf_reasons.append(f"RSI {rsi:.1f} > {max_rsi} (surachat)")
                
                # Vérifier la tendance
                ema_signal = 'neutral'
                if latest['ema_20'] > latest['ema_50'] and latest['close'] > latest['ema_20']:
                    ema_signal = 'bullish'
                    tf_score += 0.2
                elif latest['ema_20'] < latest['ema_50'] and latest['close'] < latest['ema_20']:
                    ema_signal = 'bearish'
                    tf_score += 0.2
                
                # Vérifier la volatilité
                if min_atr <= atr_percent <= max_atr:
                    tf_score += 0.2
                    tf_reasons.append(f"ATR {atr_percent:.2f}% dans la plage optimale")
                
                # Enregistrer les métriques du timeframe
                metrics['timeframes'][tf] = {
                    'rsi': rsi,
                    'atr': atr,
                    'atr_percent': atr_percent,
                    'ema_signal': ema_signal,
                    'score': tf_score,
                    'reasons': tf_reasons
                }
                
                timeframe_scores.append(tf_score)
                
            except Exception as e:
                logger.error(f"Erreur analyse timeframe {tf} pour {symbol}: {e}")
                continue
        
        # Calculer le score global
        if timeframe_scores:
            metrics['score'] = sum(timeframe_scores) / len(timeframe_scores)
        
        # Vérifier la cohérence entre les timeframes
        if 'H1' in metrics['timeframes'] and 'M5' in metrics['timeframes']:
            h1_signal = metrics['timeframes']['H1']['ema_signal']
            m5_signal = metrics['timeframes']['M5']['ema_signal']
            
            if h1_signal == m5_signal and h1_signal != 'neutral':
                metrics['score'] += 0.2
                metrics['reasons'].append(f"Tendance confirmée H1 et M5: {h1_signal}")
                metrics['recommendation'] = 'buy' if h1_signal == 'bullish' else 'sell'
                metrics['confidence'] = min(0.9, metrics['score'] * 1.2)
            else:
                metrics['reasons'].append("Pas d'alignement clair entre H1 et M5")
                metrics['recommendation'] = 'hold'
                metrics['confidence'] = max(0.1, metrics['score'] * 0.7)
        
        return metrics['score'], metrics
        
    except Exception as e:
        logger.error(f"Erreur calcul score pour {symbol}: {e}")
        return 0.0, {'symbol': symbol, 'error': str(e), 'score': 0.0}

@router.get("/scan_symbols", response_model=SymbolScanResponse)
async def scan_all_symbols(force_rescan: bool = False):
    """
    Scanne tous les symboles disponibles et retourne le plus prometteur
    """
    try:
        config = get_robot_config()
        current_time = time.time()
        
        # Vérifier si on peut utiliser le cache
        if not force_rescan and \
           selected_symbol_cache['symbol'] and \
           (current_time - selected_symbol_cache['timestamp']) < selected_symbol_cache['expires_in']:
            return SymbolScanResponse(
                selected_symbol=selected_symbol_cache['symbol'],
                selected_symbol_score=selected_symbol_cache.get('score', 0),
                analysis=selected_symbol_cache['analysis'],
                all_symbols=[]
            )
        
        # Récupérer tous les symboles
        symbols = get_all_symbols()
        if not symbols:
            raise HTTPException(status_code=404, detail="Aucun symbole disponible")
        
        # Analyser chaque symbole
        symbol_scores = {}
        all_metrics = {}
        
        for symbol in symbols:
            score, metrics = calculate_symbol_score(symbol, config['settings'])
            symbol_scores[symbol] = score
            all_metrics[symbol] = metrics
        
        # Trier les symboles par score décroissant
        sorted_symbols = sorted(symbol_scores.items(), key=lambda x: x[1], reverse=True)
        
        # Sélectionner le meilleur symbole avec un score minimum
        min_confidence = config['settings'].get('min_confidence_score', 0.7)
        selected_symbol = None
        
        for symbol, score in sorted_symbols:
            if score >= min_confidence:
                selected_symbol = symbol
                break
        
        # Mettre à jour le cache
        selected_symbol_cache['symbol'] = selected_symbol
        selected_symbol_cache['score'] = symbol_scores.get(selected_symbol, 0) if selected_symbol else 0
        selected_symbol_cache['analysis'] = all_metrics.get(selected_symbol) if selected_symbol else None
        selected_symbol_cache['symbol_scores'] = symbol_scores
        selected_symbol_cache['symbol_metrics'] = all_metrics
        selected_symbol_cache['timestamp'] = current_time
        selected_symbol_cache['last_scan_time'] = current_time
        
        # Préparer la réponse
        response_data = {
            'selected_symbol': selected_symbol,
            'selected_symbol_score': selected_symbol_cache['score'],
            'analysis': selected_symbol_cache['analysis'],
            'all_symbols': [{
                'symbol': s,
                'score': score,
                'recommendation': all_metrics.get(s, {}).get('recommendation', 'hold'),
                'confidence': all_metrics.get(s, {}).get('confidence', 0)
            } for s, score in symbol_scores.items() if score > 0],
            'timestamp': datetime.now().isoformat()
        }
        
        return response_data
        
    except Exception as e:
        logger.error(f"Erreur scan_symbols: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/best_symbol")
async def get_best_symbol():
    """
    Retourne le meilleur symbole actuel basé sur la dernière analyse
    """
    try:
        if not selected_symbol_cache['symbol']:
            # Forcer un nouveau scan si aucun symbole n'est en cache
            return await scan_all_symbols(force_rescan=True)
            
        return {
            'symbol': selected_symbol_cache['symbol'],
            'score': selected_symbol_cache.get('score', 0),
            'analysis': selected_symbol_cache['analysis'],
            'last_scan': datetime.fromtimestamp(selected_symbol_cache['timestamp']).isoformat(),
            'next_scan_in': max(0, selected_symbol_cache['timestamp'] + selected_symbol_cache['expires_in'] - time.time())
        }
    except Exception as e:
        logger.error(f"Erreur get_best_symbol: {e}")
        raise HTTPException(status_code=500, detail=str(e))

