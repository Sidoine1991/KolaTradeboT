#!/usr/bin/env python3
"""
Serveur IA simplifié pour TradBOT - Version sans Gemma
"""

import os
import json
import time
import logging
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, Any
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('ai_server_simple.log', encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("tradbot_ai_simple")

# Configuration de l'application
app = FastAPI(
    title="TradBOT AI Server (Simple)",
    description="API simplifiée pour le robot de trading TradBOT",
    version="1.0.0"
)

# Configuration CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modèles Pydantic
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
    vwap: Optional[float] = None
    vwap_distance: Optional[float] = None
    above_vwap: Optional[bool] = None
    supertrend_trend: Optional[int] = None
    supertrend_line: Optional[float] = None
    volatility_regime: Optional[int] = None
    volatility_ratio: Optional[float] = None
    image_filename: Optional[str] = None

class DecisionResponse(BaseModel):
    action: str  # "buy", "sell", "hold"
    confidence: float  # 0.0-1.0
    reason: str
    spike_prediction: bool = False
    spike_zone_price: Optional[float] = None
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    spike_direction: Optional[bool] = None
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
    gemma_analysis: Optional[str] = None

class TrendAnalysisRequest(BaseModel):
    symbol: str
    timeframes: Optional[list] = ["M1", "M5", "M15", "H1", "H4"]

def analyze_market_simple(request: DecisionRequest) -> DecisionResponse:
    """Analyse simplifiée basée sur les indicateurs techniques"""
    
    # Logique simple basée sur RSI et EMA
    rsi = request.rsi
    ema_diff_m1 = request.ema_fast_m1 - request.ema_slow_m1
    ema_diff_h1 = request.ema_fast_h1 - request.ema_slow_h1
    
    # Décision basée sur RSI
    if rsi < 30:
        action = "buy"
        confidence = min(0.8, (30 - rsi) / 30)
        reason = f"RSI survendu à {rsi:.1f}"
    elif rsi > 70:
        action = "sell"
        confidence = min(0.8, (rsi - 70) / 30)
        reason = f"RSI suracheté à {rsi:.1f}"
    else:
        # Basé sur EMA si RSI neutre
        if ema_diff_m1 > 0 and ema_diff_h1 > 0:
            action = "buy"
            confidence = min(0.7, abs(ema_diff_m1) / request.ask * 10000)
            reason = f"EMA haussière (M1: {ema_diff_m1:.5f}, H1: {ema_diff_h1:.5f})"
        elif ema_diff_m1 < 0 and ema_diff_h1 < 0:
            action = "sell"
            confidence = min(0.7, abs(ema_diff_m1) / request.ask * 10000)
            reason = f"EMA baissière (M1: {ema_diff_m1:.5f}, H1: {ema_diff_h1:.5f})"
        else:
            action = "hold"
            confidence = 0.5
            reason = "Conditions neutres - RSI entre 30-70, EMA mixte"
    
    # Ajuster la confiance selon la volatilité
    if request.volatility_ratio and request.volatility_ratio > 1.0:
        confidence *= 0.8  # Réduire la confiance en haute volatilité
    
    # Calcul des zones de trading
    mid_price = (request.bid + request.ask) / 2
    atr_adjusted = request.atr * 2
    
    if action == "buy":
        buy_zone_low = mid_price - atr_adjusted
        buy_zone_high = mid_price
        sell_zone_low = mid_price + atr_adjusted
        sell_zone_high = mid_price + atr_adjusted * 2
    elif action == "sell":
        buy_zone_low = mid_price - atr_adjusted * 2
        buy_zone_high = mid_price - atr_adjusted
        sell_zone_low = mid_price
        sell_zone_high = mid_price + atr_adjusted
    else:
        buy_zone_low = buy_zone_high = sell_zone_low = sell_zone_high = None
    
    return DecisionResponse(
        action=action,
        confidence=min(0.95, max(0.1, confidence)),
        reason=reason,
        spike_prediction=request.is_spike_mode and confidence > 0.7,
        spike_zone_price=mid_price if request.is_spike_mode and confidence > 0.7 else None,
        spike_direction=action == "buy" if request.is_spike_mode else None,
        buy_zone_low=buy_zone_low,
        buy_zone_high=buy_zone_high,
        sell_zone_low=sell_zone_low,
        sell_zone_high=sell_zone_high,
        timestamp=datetime.now().isoformat(),
        model_used="Simple Technical Analysis",
        technical_analysis={
            "rsi": rsi,
            "ema_diff_m1": ema_diff_m1,
            "ema_diff_h1": ema_diff_h1,
            "atr": request.atr,
            "volatility_ratio": request.volatility_ratio
        }
    )

@app.post("/decision", response_model=DecisionResponse)
async def decision(request: DecisionRequest):
    """Endpoint principal de décision trading"""
    try:
        logger.info(f"Decision request pour {request.symbol}")
        result = analyze_market_simple(request)
        logger.info(f"Décision: {result.action} (confiance: {result.confidence:.2f})")
        return result
    except Exception as e:
        logger.error(f"Erreur dans decision: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/decisionGemma", response_model=DecisionResponse)
async def decision_gemma(request: DecisionRequest):
    """Endpoint compatible avec decisionGemma (utilise la même logique simple)"""
    return await decision(request)

@app.post("/trend")
async def get_trend_analysis(request: TrendAnalysisRequest):
    """Endpoint d'analyse de tendance"""
    try:
        # Logique simple de tendance basée sur l'heure
        hour = datetime.now().hour
        
        # Simulation d'analyse multi-timeframe
        m1_direction = "buy" if hour % 2 == 0 else "sell"
        m5_direction = "buy" if hour % 3 == 0 else "sell"
        h1_direction = "buy" if hour % 4 == 0 else "sell"
        
        # Calcul de confiance basé sur la cohérence
        directions = [m1_direction, m5_direction, h1_direction]
        buy_count = directions.count("buy")
        sell_count = directions.count("sell")
        
        if buy_count > sell_count:
            m1_confidence = 50 + (buy_count - sell_count) * 15
            m1_direction = "buy"
        elif sell_count > buy_count:
            m1_confidence = 50 + (sell_count - buy_count) * 15
            m1_direction = "sell"
        else:
            m1_confidence = 50
            m1_direction = "neutral"
        
        response = {
            "symbol": request.symbol,
            "timestamp": time.time(),
            "m1_direction": m1_direction,
            "m1_confidence": min(95, max(35, m1_confidence)),
            "is_valid": True
        }
        
        logger.info(f"Trend analysis pour {request.symbol}: {m1_direction} ({m1_confidence:.1f}%)")
        return response
        
    except Exception as e:
        logger.error(f"Erreur dans get_trend_analysis: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """Endpoint de santé"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

if __name__ == "__main__":
    logger.info("Démarrage du serveur IA simplifié...")
    uvicorn.run(app, host="127.0.0.1", port=8000, log_level="info")
