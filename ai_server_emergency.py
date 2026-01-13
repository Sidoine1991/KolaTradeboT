#!/usr/bin/env python3
"""
Serveur IA simplifié pour F_INX_Scalpe_double
Version d'urgence qui fonctionne sans dépendances lourdes
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
import random
import time
from datetime import datetime
import json
import urllib.parse

app = FastAPI(title="AI Server Simplifié", version="1.0")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class DecisionRequest(BaseModel):
    symbol: str
    timeframe: str = "M1"

class MarketStateRequest(BaseModel):
    symbol: str
    timeframe: str = "M1"

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

@app.post("/decision")
async def get_decision(request: DecisionRequest):
    """Génère une décision IA simplifiée mais réaliste"""
    try:
        symbol = request.symbol
        timeframe = request.timeframe
        
        # Nettoyer le nom du symbole
        clean_symbol = urllib.parse.unquote(symbol.replace(" ", "_"))
        
        # Simuler un prix actuel basé sur le type de symbole
        if "USD" in clean_symbol:
            current_price = 1.08 + random.uniform(-0.02, 0.02)
        elif "Oil" in clean_symbol or "XAU" in clean_symbol:
            current_price = 75 + random.uniform(-5, 5)
        elif "Boom" in clean_symbol or "Crash" in clean_symbol:
            current_price = 500 + random.uniform(-50, 50)
        else:
            current_price = 100 + random.uniform(-10, 10)
        
        # Génération de seed déterministe
        seed = hash(clean_symbol + str(int(current_price * 1000))) % (2**31)
        np.random.seed(seed)
        
        # Simuler l'analyse technique
        rsi = np.random.normal(50, 20)
        rsi = max(10, min(90, rsi))
        
        # Tendance multi-timeframe
        m1_trend = np.random.choice([-1, 0, 1], p=[0.3, 0.4, 0.3])
        m5_trend = np.random.choice([-1, 0, 1], p=[0.3, 0.4, 0.3])
        h1_trend = np.random.choice([-1, 0, 1], p=[0.3, 0.4, 0.3])
        
        # Décision basée sur l'alignement des tendances
        trend_score = m1_trend + m5_trend + h1_trend
        
        # Bonus pour RSI extrême
        if rsi < 30:
            trend_score += 1  # Survente = signal BUY
        elif rsi > 70:
            trend_score -= 1  # Surachat = signal SELL
        
        # Calcul de la confiance
        if abs(trend_score) >= 2:
            base_confidence = 0.75
        elif abs(trend_score) >= 1:
            base_confidence = 0.60
        else:
            base_confidence = 0.40
        
        # Ajustement selon le type de symbole
        if "Boom" in clean_symbol or "Crash" in clean_symbol:
            base_confidence += 0.1  # Plus volatil = plus de confiance
        
        # Ajouter un peu de bruit réaliste
        confidence = min(0.95, max(0.30, base_confidence + np.random.normal(0, 0.05)))
        
        # Déterminer l'action
        if trend_score > 0:
            action = "buy"
        elif trend_score < 0:
            action = "sell"
        else:
            action = "neutral"
        
        # Générer des prédictions de prix
        prediction_horizon = 500
        predictions = []
        
        # Prix de base
        base_price = current_price
        
        for i in range(prediction_horizon):
            # Simulation de mouvement brownien avec tendance
            trend_drift = (trend_score * 0.0001 * base_price)
            random_walk = np.random.normal(0, 0.001 * base_price)
            
            # Effet de retour à la moyenne
            mean_reversion = (base_price - current_price) * 0.001
            
            new_price = base_price + trend_drift + random_walk + mean_reversion
            predictions.append(float(new_price))
            base_price = new_price
        
        return {
            "action": action,
            "confidence": confidence,
            "predictions": predictions,
            "current_price": current_price,
            "rsi": rsi,
            "trend_m1": m1_trend,
            "trend_m5": m5_trend,
            "trend_h1": h1_trend,
            "trend_score": trend_score,
            "symbol": clean_symbol,
            "timeframe": timeframe,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur: {str(e)}")

@app.post("/market-state")
async def get_market_state(request: MarketStateRequest):
    """Retourne l'état du marché"""
    try:
        symbol = request.symbol
        clean_symbol = urllib.parse.unquote(symbol.replace(" ", "_"))
        
        # Simuler un état de marché
        trend = np.random.choice(["bullish", "bearish", "sideways"], p=[0.4, 0.3, 0.3])
        volatility = np.random.choice(["low", "medium", "high"], p=[0.3, 0.4, 0.3])
        
        # Confiance basée sur la tendance
        if trend == "sideways":
            confidence = np.random.uniform(0.3, 0.5)
        else:
            confidence = np.random.uniform(0.6, 0.85)
        
        return {
            "trend": trend,
            "volatility": volatility,
            "confidence": confidence,
            "symbol": clean_symbol,
            "timeframe": request.timeframe,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur: {str(e)}")

@app.get("/analysis/{symbol}")
async def get_analysis(symbol: str):
    """Analyse complète pour un symbole"""
    try:
        clean_symbol = urllib.parse.unquote(symbol.replace(" ", "_"))
        
        # Simuler une analyse complète
        return {
            "symbol": clean_symbol,
            "overall_trend": np.random.choice(["strong_bullish", "bullish", "sideways", "bearish", "strong_bearish"]),
            "support_levels": [100 + i*10 for i in range(3)],
            "resistance_levels": [120 + i*10 for i in range(3)],
            "key_levels": {
                "support": 105,
                "resistance": 125,
                "pivot": 115
            },
            "market_phase": np.random.choice(["accumulation", "markup", "distribution", "markdown"]),
            "confidence": np.random.uniform(0.6, 0.9),
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    print("🚀 Démarrage du serveur IA simplifié sur http://127.0.0.1:8000")
    print("✅ Serveur prêt - Version d'urgence sans dépendances lourdes")
    uvicorn.run(app, host="127.0.0.1", port=8000, log_level="info")
