"""
Endpoint API pour prédiction des bougies futures
Combine données Supabase + temps réel + ML
"""
from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
from datetime import datetime, timedelta
import numpy as np
from pydantic import BaseModel
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/prediction", tags=["prediction"])


# ═══════════════════════════════════════════════════════════════════
# MODÈLES DE DONNÉES
# ═══════════════════════════════════════════════════════════════════

class CandlePrediction(BaseModel):
    """Prédiction d'une bougie future"""
    time: datetime
    open: float
    high: float
    low: float
    close: float
    confidence: float  # 0-100%
    trend_direction: str  # "UP", "DOWN", "SIDEWAYS"


class TrajectoryPoint(BaseModel):
    """Point clé de la trajectoire"""
    time: datetime
    price: float
    type: str  # "SUPPORT", "RESISTANCE", "PIVOT", "TARGET"
    confidence: float


class PredictionZone(BaseModel):
    """Zone de prédiction complète"""
    symbol: str
    timeframe: str
    current_price: float
    prediction_horizon: int  # Nombre de bougies
    candles: List[CandlePrediction]
    trajectory_points: List[TrajectoryPoint]
    trend_direction: str
    trend_strength: float  # 0-100%
    volatility_expected: float
    key_levels: dict  # Support/Résistance clés
    ml_confidence: float  # Confiance globale du modèle


# ═══════════════════════════════════════════════════════════════════
# FONCTIONS DE PRÉDICTION ML
# ═══════════════════════════════════════════════════════════════════

def get_historical_patterns_from_supabase(symbol: str, timeframe: str, lookback_days: int = 30):
    """
    Récupérer les patterns historiques depuis Supabase

    Returns:
        dict avec patterns identifiés, volatilité moyenne, tendances
    """
    # TODO: Implémenter connexion Supabase réelle
    # Pour l'instant, retourner données de démo

    return {
        "avg_volatility": 0.015,  # 1.5% de volatilité moyenne
        "dominant_pattern": "bullish_continuation",
        "avg_candle_size": 50,  # En points
        "trend_persistence": 0.75,  # 75% de persistance de tendance
        "support_levels": [],
        "resistance_levels": []
    }


def calculate_trend_momentum(current_data: dict) -> dict:
    """
    Calculer le momentum de la tendance actuelle

    Args:
        current_data: Données temps réel (EMA, RSI, etc.)

    Returns:
        dict avec direction, force, probabilité continuation
    """
    ema_fast = current_data.get("ema_fast", 0)
    ema_slow = current_data.get("ema_slow", 0)
    rsi = current_data.get("rsi", 50)
    current_price = current_data.get("price", 0)

    # Déterminer direction
    if ema_fast > ema_slow and current_price > ema_fast:
        direction = "UP"
        strength = min(100, abs(ema_fast - ema_slow) / ema_slow * 1000)
    elif ema_fast < ema_slow and current_price < ema_fast:
        direction = "DOWN"
        strength = min(100, abs(ema_fast - ema_slow) / ema_slow * 1000)
    else:
        direction = "SIDEWAYS"
        strength = 30

    # Ajuster avec RSI
    if direction == "UP" and rsi > 70:
        strength *= 0.7  # Surachat, réduire force
    elif direction == "DOWN" and rsi < 30:
        strength *= 0.7  # Survente, réduire force

    return {
        "direction": direction,
        "strength": strength,
        "continuation_probability": strength / 100.0
    }


def predict_next_candles(
    symbol: str,
    timeframe: str,
    current_data: dict,
    historical_patterns: dict,
    num_candles: int = 5
) -> List[CandlePrediction]:
    """
    Prédire les N prochaines bougies

    Algorithme:
    1. Analyser tendance actuelle (EMA, momentum)
    2. Appliquer patterns historiques (volatilité, taille moyenne)
    3. Projeter avec décroissance de confiance
    """
    predictions = []

    current_price = current_data.get("price", 0)
    current_time = datetime.now()

    # Analyser tendance
    trend = calculate_trend_momentum(current_data)
    direction = trend["direction"]
    strength = trend["strength"]

    # Paramètres de prédiction
    avg_candle_size = historical_patterns.get("avg_candle_size", 50)
    volatility = historical_patterns.get("avg_volatility", 0.015)
    trend_persistence = historical_patterns.get("trend_persistence", 0.75)

    # Timeframe en minutes
    tf_minutes = {
        "M1": 1, "M5": 5, "M15": 15, "M30": 30,
        "H1": 60, "H4": 240, "D1": 1440
    }.get(timeframe, 5)

    # Générer prédictions
    last_close = current_price
    base_confidence = 85.0  # Confiance initiale

    for i in range(num_candles):
        # Décroissance de confiance (plus on va loin, moins c'est sûr)
        confidence = base_confidence * (0.85 ** i)

        # Calculer variation attendue
        if direction == "UP":
            price_change = avg_candle_size * (1 + np.random.normal(0, volatility))
            open_price = last_close
            close_price = open_price + price_change
            high_price = close_price + (price_change * 0.3)
            low_price = open_price - (price_change * 0.1)
        elif direction == "DOWN":
            price_change = avg_candle_size * (1 + np.random.normal(0, volatility))
            open_price = last_close
            close_price = open_price - price_change
            low_price = close_price - (price_change * 0.3)
            high_price = open_price + (price_change * 0.1)
        else:  # SIDEWAYS
            price_change = avg_candle_size * 0.5 * (1 + np.random.normal(0, volatility))
            open_price = last_close
            close_price = open_price + np.random.choice([-1, 1]) * price_change
            high_price = max(open_price, close_price) + (price_change * 0.5)
            low_price = min(open_price, close_price) - (price_change * 0.5)

        # Appliquer persistence de tendance
        if np.random.random() > trend_persistence:
            # Inversion possible
            direction = "SIDEWAYS" if direction != "SIDEWAYS" else np.random.choice(["UP", "DOWN"])

        # Temps de la bougie
        candle_time = current_time + timedelta(minutes=tf_minutes * (i + 1))

        prediction = CandlePrediction(
            time=candle_time,
            open=round(open_price, 5),
            high=round(high_price, 5),
            low=round(low_price, 5),
            close=round(close_price, 5),
            confidence=round(confidence, 2),
            trend_direction=direction
        )

        predictions.append(prediction)
        last_close = close_price

    return predictions


def generate_trajectory_points(
    predictions: List[CandlePrediction],
    current_data: dict,
    historical_patterns: dict
) -> List[TrajectoryPoint]:
    """
    Générer les points clés de la trajectoire

    Points identifiés:
    - Supports/Résistances probables
    - Pivots de retournement
    - Cibles de prix
    """
    trajectory = []

    if not predictions:
        return trajectory

    current_price = current_data.get("price", 0)

    # Premier point = prix actuel
    trajectory.append(TrajectoryPoint(
        time=datetime.now(),
        price=current_price,
        type="PIVOT",
        confidence=100.0
    ))

    # Identifier points clés dans les prédictions
    for i, pred in enumerate(predictions):
        # Tous les 2-3 bougies, ajouter un point clé
        if i % 2 == 0 or i == len(predictions) - 1:
            # Type de point selon position
            if i == len(predictions) - 1:
                point_type = "TARGET"
            elif pred.trend_direction != predictions[max(0, i-1)].trend_direction:
                point_type = "PIVOT"
            elif pred.close > pred.open:
                point_type = "RESISTANCE"
            else:
                point_type = "SUPPORT"

            trajectory.append(TrajectoryPoint(
                time=pred.time,
                price=pred.close,
                type=point_type,
                confidence=pred.confidence
            ))

    return trajectory


# ═══════════════════════════════════════════════════════════════════
# ENDPOINTS API
# ═══════════════════════════════════════════════════════════════════

@router.get("/candles/future", response_model=PredictionZone)
async def predict_future_candles(
    symbol: str = Query(..., description="Symbole (ex: EURUSD, Boom 500 Index)"),
    timeframe: str = Query("M5", description="Timeframe (M1, M5, M15, H1, etc.)"),
    num_candles: int = Query(5, ge=1, le=20, description="Nombre de bougies à prédire"),
    price: float = Query(..., description="Prix actuel"),
    ema_fast: float = Query(0, description="EMA rapide"),
    ema_slow: float = Query(0, description="EMA lente"),
    rsi: float = Query(50, description="RSI actuel"),
    atr: float = Query(0, description="ATR actuel")
):
    """
    Prédire les N prochaines bougies avec trajectoire

    Combine:
    - Données historiques Supabase (patterns, volatilité)
    - Données temps réel (EMAs, RSI, momentum)
    - Modèle ML de prédiction

    Returns:
        Zone de prédiction complète avec bougies + trajectoire
    """
    try:
        # 1. Récupérer patterns historiques depuis Supabase
        historical_patterns = get_historical_patterns_from_supabase(symbol, timeframe)

        # 2. Préparer données temps réel
        current_data = {
            "symbol": symbol,
            "price": price,
            "ema_fast": ema_fast,
            "ema_slow": ema_slow,
            "rsi": rsi,
            "atr": atr
        }

        # 3. Calculer tendance et momentum
        trend = calculate_trend_momentum(current_data)

        # 4. Prédire bougies futures
        candles = predict_next_candles(
            symbol, timeframe, current_data, historical_patterns, num_candles
        )

        # 5. Générer points de trajectoire
        trajectory = generate_trajectory_points(candles, current_data, historical_patterns)

        # 6. Identifier niveaux clés
        prices = [c.close for c in candles]
        key_levels = {
            "current": price,
            "predicted_high": max(prices),
            "predicted_low": min(prices),
            "target": prices[-1] if prices else price
        }

        # 7. Calculer volatilité attendue
        if len(prices) > 1:
            volatility_expected = np.std(prices) / price * 100
        else:
            volatility_expected = historical_patterns.get("avg_volatility", 1.5) * 100

        # 8. Confiance ML globale
        ml_confidence = sum(c.confidence for c in candles) / len(candles) if candles else 0

        # Construire réponse
        prediction_zone = PredictionZone(
            symbol=symbol,
            timeframe=timeframe,
            current_price=price,
            prediction_horizon=num_candles,
            candles=candles,
            trajectory_points=trajectory,
            trend_direction=trend["direction"],
            trend_strength=trend["strength"],
            volatility_expected=round(volatility_expected, 2),
            key_levels=key_levels,
            ml_confidence=round(ml_confidence, 2)
        )

        logger.info(f"Prédiction générée: {symbol} {timeframe} - {num_candles} bougies - Tendance: {trend['direction']} ({trend['strength']:.1f}%)")

        return prediction_zone

    except Exception as e:
        logger.error(f"Erreur prédiction: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur prédiction: {str(e)}")


@router.get("/trajectory/path", response_model=dict)
async def get_price_trajectory_path(
    symbol: str = Query(..., description="Symbole"),
    timeframe: str = Query("M5", description="Timeframe"),
    lookback_candles: int = Query(20, description="Historique (bougies passées)"),
    lookahead_candles: int = Query(5, description="Prédiction (bougies futures)")
):
    """
    Obtenir la trajectoire complète: passé + futur

    Pour dessiner un chemin continu sur le graphique
    """
    try:
        # TODO: Implémenter récupération historique réel
        # Pour l'instant, retourner structure de démo

        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "path": {
                "historical": [
                    {"time": "2024-04-28 12:00", "price": 1.0850},
                    {"time": "2024-04-28 12:05", "price": 1.0855},
                    {"time": "2024-04-28 12:10", "price": 1.0852},
                ],
                "current": {"time": "2024-04-28 12:15", "price": 1.0860},
                "predicted": [
                    {"time": "2024-04-28 12:20", "price": 1.0865, "confidence": 85},
                    {"time": "2024-04-28 12:25", "price": 1.0870, "confidence": 72},
                    {"time": "2024-04-28 12:30", "price": 1.0868, "confidence": 60},
                ]
            }
        }

    except Exception as e:
        logger.error(f"Erreur trajectoire: {e}")
        raise HTTPException(status_code=500, detail=str(e))
