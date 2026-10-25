#!/usr/bin/env python3
"""
API Boom Rising Channel Predictor - Intégration avec AngelOfSpike
API spécialisée pour le robot AngelOfSpike avec prédictions de canal haussier
"""

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, List, Optional
import uvicorn
import time
import json
import threading
from datetime import datetime, timedelta
import numpy as np

# Import du système Boom Rising Channel Predictor
from boom_rising_channel_predictor import (
    boom_predictor,
    get_boom_prediction,
    update_boom_data,
    get_boom_summary,
    create_boom_chart
)
from boom_config import get_config

# Configuration
API_PORT = 8002
CACHE_DURATION = 30  # secondes
PREDICTION_CACHE = {}
LAST_UPDATE_TIME = {}

app = FastAPI(
    title="Boom Rising Channel Predictor API",
    description="API spécialisée pour le robot AngelOfSpike - Prédictions de canal haussier sur Boom",
    version="1.0.0"
)

# CORS pour permettre les requêtes depuis MT5
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class BoomPredictionRequest(BaseModel):
    symbol: str = "Boom 1000 Index"
    timeframe: str = "M1"
    force_refresh: bool = False

class BoomPredictionResponse(BaseModel):
    symbol: str
    timestamp: float
    action: str
    direction: str
    confidence: float
    spike_probability: float
    time_to_spike: int
    ema_proximity: str
    channel_position: str
    current_price: float
    stop_loss: float
    take_profit: float
    lot_size: float
    reasoning: str
    channel_strength: float
    breakout_probability: float
    prediction_arrows: List[Dict]

class BoomStatusResponse(BaseModel):
    status: str
    active_predictions: int
    active_channels: int
    success_rate: float
    last_update: float
    system_health: str

def create_sample_data():
    """Crée des données d'exemple pour Boom"""
    test_data = []
    base_price = 10000.0
    
    # Simulation d'un canal haussier
    for i in range(100):
        trend_factor = i * 0.1
        noise = np.random.normal(0, 0.5)
        price = base_price + trend_factor + noise
        
        test_data.append({
            'timestamp': time.time() - (100-i) * 60,
            'open': price,
            'high': price + abs(np.random.normal(0, 0.3)),
            'low': price - abs(np.random.normal(0, 0.3)),
            'close': price,
            'volume': np.random.randint(1000, 5000)
        })
    
    return test_data

def update_boom_data_periodically():
    """Met à jour les données Boom périodiquement"""
    while True:
        try:
            # Créer des données simulées (à remplacer par vraies données MT5)
            sample_data = create_sample_data()
            update_boom_data(sample_data)
            
            # Mettre à jour le cache
            current_time = time.time()
            LAST_UPDATE_TIME['boom'] = current_time
            
            print(f"🔄 Données Boom mises à jour: {len(sample_data)} bougies")
            
        except Exception as e:
            print(f"❌ Erreur mise à jour données: {e}")
        
        time.sleep(60)  # Mise à jour toutes les minutes

@app.on_event("startup")
async def startup_event():
    """Événement de démarrage"""
    print("🚀 Démarrage de l'API Boom Rising Channel Predictor...")
    
    # Initialiser avec des données d'exemple
    sample_data = create_sample_data()
    update_boom_data(sample_data)
    
    # Démarrer le thread de mise à jour
    update_thread = threading.Thread(target=update_boom_data_periodically, daemon=True)
    update_thread.start()
    
    print("✅ API Boom Rising Channel Predictor démarrée")

@app.get("/")
async def root():
    """Endpoint racine"""
    return {
        "message": "Boom Rising Channel Predictor API - AngelOfSpike Integration",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "/predict": "Prédiction Boom avec canal haussier",
            "/status": "Statut du système",
            "/health": "Vérification santé",
            "/config": "Configuration du système",
            "/chart": "Génération de graphique",
            "/summary": "Résumé des prédictions"
        }
    }

@app.get("/predict", response_model=BoomPredictionResponse)
async def get_boom_prediction_api(
    symbol: str = Query("Boom 1000 Index", description="Symbole à analyser"),
    timeframe: str = Query("M1", description="Timeframe d'analyse"),
    force_refresh: bool = Query(False, description="Forcer le rafraîchissement")
):
    """
    Endpoint principal pour obtenir une prédiction Boom
    Utilisé par le robot AngelOfSpike
    """
    try:
        # Vérifier le cache
        cache_key = f"{symbol}_{timeframe}"
        current_time = time.time()
        
        if not force_refresh and cache_key in PREDICTION_CACHE:
            last_update = LAST_UPDATE_TIME.get(cache_key, 0)
            if current_time - last_update < CACHE_DURATION:
                cached_prediction = PREDICTION_CACHE[cache_key]
                print(f"📊 Prédiction Boom depuis le cache: {cached_prediction['action']}")
                return BoomPredictionResponse(**cached_prediction)
        
        # Obtenir une nouvelle prédiction
        prediction = get_boom_prediction()
        
        if not prediction:
            raise HTTPException(status_code=500, detail="Impossible de générer une prédiction")
        
        # Enrichir la réponse avec des données supplémentaires
        enhanced_prediction = {
            "symbol": symbol,
            "timestamp": current_time,
            "action": prediction.get('action', 'HOLD'),
            "direction": prediction.get('direction', 'NEUTRAL'),
            "confidence": prediction.get('confidence', 0.0),
            "spike_probability": prediction.get('spike_probability', 0.0),
            "time_to_spike": prediction.get('time_to_spike', 0),
            "ema_proximity": prediction.get('ema_proximity', 'N/A'),
            "channel_position": prediction.get('channel_position', 'N/A'),
            "current_price": prediction.get('current_price', 0.0),
            "stop_loss": prediction.get('stop_loss', 0.0),
            "take_profit": prediction.get('take_profit', 0.0),
            "lot_size": prediction.get('lot_size', 0.1),
            "reasoning": prediction.get('reasoning', 'Analyse standard'),
            "channel_strength": boom_predictor.rising_channels[-1].strength if boom_predictor.rising_channels else 0.0,
            "breakout_probability": boom_predictor.rising_channels[-1].breakout_probability if boom_predictor.rising_channels else 0.0,
            "prediction_arrows": [
                {
                    "timestamp": arrow.timestamp,
                    "price": arrow.price,
                    "direction": arrow.direction.value,
                    "confidence": arrow.confidence,
                    "ema_proximity": arrow.ema_proximity,
                    "channel_position": arrow.channel_position
                }
                for arrow in boom_predictor.prediction_arrows[-5:]  # 5 dernières flèches
            ]
        }
        
        # Mettre en cache
        PREDICTION_CACHE[cache_key] = enhanced_prediction
        LAST_UPDATE_TIME[cache_key] = current_time
        
        print(f"🎯 Nouvelle prédiction Boom générée: {enhanced_prediction['action']} - Confiance: {enhanced_prediction['confidence']:.1%}")
        
        return BoomPredictionResponse(**enhanced_prediction)
        
    except Exception as e:
        print(f"❌ Erreur prédiction Boom: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur génération prédiction: {str(e)}")

@app.get("/status", response_model=BoomStatusResponse)
async def get_boom_status():
    """Statut du système Boom Rising Channel Predictor"""
    try:
        summary = get_boom_summary()
        
        status = {
            "status": "running",
            "active_predictions": len(boom_predictor.prediction_arrows),
            "active_channels": len(boom_predictor.rising_channels),
            "success_rate": boom_predictor.success_rate,
            "last_update": LAST_UPDATE_TIME.get('boom', 0),
            "system_health": "healthy" if boom_predictor.prediction_arrows else "initializing"
        }
        
        return BoomStatusResponse(**status)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur statut: {str(e)}")

@app.get("/health")
async def health_check():
    """Vérification de santé de l'API"""
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "api_name": "Boom Rising Channel Predictor",
        "version": "1.0.0",
        "uptime": "running",
        "last_data_update": LAST_UPDATE_TIME.get('boom', 0),
        "active_predictions": len(boom_predictor.prediction_arrows),
        "active_channels": len(boom_predictor.rising_channels)
    }

@app.get("/config")
async def get_boom_config():
    """Configuration du système Boom"""
    try:
        config = {
            "boom": get_config('boom'),
            "ema": get_config('ema'),
            "channel": get_config('channel'),
            "prediction": get_config('prediction'),
            "trading": get_config('trading')
        }
        
        return {
            "status": "ok",
            "config": config,
            "timestamp": time.time()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur configuration: {str(e)}")

@app.get("/chart")
async def generate_boom_chart():
    """Génère un graphique Boom avec prédictions"""
    try:
        chart_path = f"boom_chart_{int(time.time())}.png"
        result = create_boom_chart(chart_path)
        
        return {
            "status": "ok",
            "chart_path": chart_path,
            "message": result,
            "timestamp": time.time()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur génération graphique: {str(e)}")

@app.get("/summary")
async def get_boom_summary_api():
    """Résumé des prédictions Boom"""
    try:
        summary = get_boom_summary()
        
        return {
            "status": "ok",
            "summary": summary,
            "timestamp": time.time(),
            "cache_size": len(PREDICTION_CACHE),
            "last_updates": LAST_UPDATE_TIME
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur résumé: {str(e)}")

@app.post("/update_data")
async def update_boom_data_manual():
    """Met à jour manuellement les données Boom"""
    try:
        sample_data = create_sample_data()
        update_boom_data(sample_data)
        
        LAST_UPDATE_TIME['boom'] = time.time()
        
        return {
            "status": "ok",
            "message": f"Données mises à jour: {len(sample_data)} bougies",
            "timestamp": time.time()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur mise à jour: {str(e)}")

@app.get("/angelofspike/format")
async def get_angelofspike_format():
    """Format de réponse compatible avec AngelOfSpike"""
    try:
        prediction = get_boom_prediction()
        
        if not prediction:
            return {
                "direction": "NEUTRAL",
                "strength": 0,
                "confidence": 0,
                "signal": "no_signal",
                "trend": "neutral"
            }
        
        # Format compatible avec AngelOfSpike
        angelofspike_response = {
            "direction": prediction.get('direction', 'NEUTRAL'),
            "strength": int(prediction.get('confidence', 0) * 100),
            "confidence": int(prediction.get('spike_probability', 0) * 100),
            "signal": f"boom_{prediction.get('action', 'HOLD').lower()}",
            "trend": prediction.get('direction', 'neutral').lower(),
            "ema_proximity": prediction.get('ema_proximity', 'N/A'),
            "channel_position": prediction.get('channel_position', 'N/A'),
            "spike_probability": prediction.get('spike_probability', 0),
            "time_to_spike": prediction.get('time_to_spike', 0),
            "current_price": prediction.get('current_price', 0),
            "stop_loss": prediction.get('stop_loss', 0),
            "take_profit": prediction.get('take_profit', 0)
        }
        
        return angelofspike_response
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur format AngelOfSpike: {str(e)}")

@app.get("/angelofspike/trend")
async def get_angelofspike_trend(
    symbol: str = Query("Boom 1000 Index"),
    timeframe: str = Query("M1")
):
    """
    Endpoint spécialement formaté pour AngelOfSpike
    Compatible avec l'API /trend existante
    """
    try:
        prediction = get_boom_prediction()
        
        if not prediction:
            return {
                "symbol": symbol,
                "timeframe": timeframe,
                "timestamp": time.time(),
                "direction": "NEUTRAL",
                "strength": 0,
                "confidence": 0,
                "signal": "no_signal",
                "trend": "neutral"
            }
        
        # Format compatible avec l'API trend existante
        trend_response = {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": time.time(),
            "direction": prediction.get('direction', 'NEUTRAL'),
            "strength": int(prediction.get('confidence', 0) * 100),
            "confidence": int(prediction.get('spike_probability', 0) * 100),
            "signal": f"boom_{prediction.get('action', 'HOLD').lower()}",
            "trend": prediction.get('direction', 'neutral').lower(),
            "spike_probability": prediction.get('spike_probability', 0),
            "time_to_spike": prediction.get('time_to_spike', 0),
            "ema_proximity": prediction.get('ema_proximity', 'N/A'),
            "channel_position": prediction.get('channel_position', 'N/A'),
            "current_price": prediction.get('current_price', 0),
            "stop_loss": prediction.get('stop_loss', 0),
            "take_profit": prediction.get('take_profit', 0),
            "lot_size": prediction.get('lot_size', 0.1),
            "reasoning": prediction.get('reasoning', 'Analyse canal haussier Boom'),
            "channel_strength": boom_predictor.rising_channels[-1].strength if boom_predictor.rising_channels else 0.0,
            "breakout_probability": boom_predictor.rising_channels[-1].breakout_probability if boom_predictor.rising_channels else 0.0
        }
        
        print(f"🎯 Réponse AngelOfSpike: {trend_response['direction']} - Force: {trend_response['strength']} - Confiance: {trend_response['confidence']}")
        
        return trend_response
        
    except Exception as e:
        print(f"❌ Erreur AngelOfSpike trend: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur génération trend: {str(e)}")

@app.get("/stats")
async def get_api_stats():
    """Statistiques de l'API"""
    return {
        "api_name": "Boom Rising Channel Predictor API",
        "version": "1.0.0",
        "port": API_PORT,
        "endpoints": [
            "/predict - Prédiction Boom principale",
            "/angelofspike/trend - Format AngelOfSpike",
            "/status - Statut du système",
            "/health - Vérification santé",
            "/config - Configuration",
            "/chart - Génération graphique",
            "/summary - Résumé prédictions"
        ],
        "features": [
            "Détection canal haussier",
            "Prédiction spikes Boom",
            "Analyse proximité EMA",
            "Flèches dynamiques",
            "Intégration AngelOfSpike",
            "Cache intelligent",
            "Mise à jour temps réel"
        ],
        "status": "operational",
        "timestamp": time.time()
    }

if __name__ == "__main__":
    print("🚀 Démarrage de l'API Boom Rising Channel Predictor...")
    print(f"🌐 URL: http://localhost:{API_PORT}")
    print(f"📊 Endpoint principal: /predict")
    print(f"🤖 Endpoint AngelOfSpike: /angelofspike/trend")
    print(f"📚 Documentation: http://localhost:{API_PORT}/docs")
    print("=" * 60)
    
    uvicorn.run(
        "boom_api:app",
        host="0.0.0.0",
        port=API_PORT,
        reload=True,
        log_level="info"
    )
