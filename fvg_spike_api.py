#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
API FastAPI pour le système FVG Spike Detection
Endpoints pour alertes M5 et déclenchement d'ordres
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional, List, Literal
from datetime import datetime
import asyncio
import logging
import pandas as pd
import numpy as np

from fvg_spike_detector import (
    FVGSpikeDetector, 
    Alert, 
    SpikeSignal, 
    TimeFrame,
    FVGType
)

logger = logging.getLogger("fvg_spike_api")

# Modèles Pydantic pour l'API
class CandleData(BaseModel):
    open: float
    high: float
    low: float
    close: float
    volume: float = 0.0
    timestamp: Optional[datetime] = None

class MarketDataInput(BaseModel):
    symbol: str = Field(..., description="Symbole: 'Boom 500', 'GAINX', etc.")
    timeframe: Literal["M1", "M5"] = Field(..., description="Timeframe des bougies")
    candles: List[CandleData] = Field(..., min_length=3, description="Minimum 3 bougies")

class FVGAlertResponse(BaseModel):
    symbol: str
    alert_type: str
    fvg_type: str
    fvg_size: float
    confidence: float
    message: str
    timestamp: datetime
    triggered: bool

class TradeSignalResponse(BaseModel):
    symbol: str
    direction: Literal["BUY", "SELL"]
    entry_price: float
    stop_loss: float
    take_profit: float
    lot_size: float
    confidence: float
    timeframe_confluence: List[str]
    risk_amount_usd: float
    risk_reward_ratio: float
    timestamp: datetime
    status: str = "PENDING_EXECUTION"

class RiskCalculationRequest(BaseModel):
    symbol: str
    entry_price: float
    stop_loss: float
    take_profit: Optional[float] = None
    direction: Literal["BUY", "SELL", "AUTO"] = "AUTO"
    max_risk_usd: float = 2.50
    account_balance: Optional[float] = None

class RiskCalculationResponse(BaseModel):
    symbol: str
    lot_size: float
    max_risk_usd: float
    actual_risk_usd: float
    sl_distance_pips: float
    pip_value_usd: float
    leverage_used: float
    margin_required_usd: Optional[float] = None
    recommended: bool

# Initialisation FastAPI
app = FastAPI(
    title="FVG Spike Detector API",
    description="API pour la détection de spikes FVG multi-timeframe Boom/Crash",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Instance globale du détecteur
detector = FVGSpikeDetector(max_risk_usd=2.50)

# Stockage des alertes et signaux récents (en production: utiliser Redis/DB)
_recent_alerts: List[dict] = []
_recent_signals: List[dict] = []

# Callbacks pour notifications
async def _alert_notification(alert: Alert):
    """Callback pour alerte M5 - envoi notification WhatsApp/Telegram"""
    logger.info(f"[NOTIF] Alerte M5 envoyée: {alert.symbol}")
    # Ici: intégrer avec WhatsApp Sender ou Telegram Bot
    _recent_alerts.append({
        "type": "ALERT", 
        "symbol": alert.symbol,
        "message": alert.message,
        "timestamp": alert.timestamp.isoformat()
    })

async def _signal_notification(signal: SpikeSignal):
    """Callback pour signal de trade - déclenchement ordre broker"""
    logger.info(f"[EXEC] Ordre prêt: {signal.symbol} {signal.direction}")
    # Ici: connexion avec l'EA MT5 ou l'API broker
    _recent_signals.append({
        "type": "SIGNAL",
        "symbol": signal.symbol,
        "direction": signal.direction,
        "entry": signal.entry_price,
        "sl": signal.stop_loss,
        "tp": signal.take_profit,
        "lot": signal.lot_size,
        "timestamp": signal.timestamp.isoformat()
    })

# Enregistrement des callbacks
detector.register_alert_callback(_alert_notification)
detector.register_signal_callback(_signal_notification)


def _candles_to_dataframe(candles: List[CandleData]) -> pd.DataFrame:
    """Convertit les bougies Pydantic en DataFrame pandas"""
    data = {
        'open': [c.open for c in candles],
        'high': [c.high for c in candles],
        'low': [c.low for c in candles],
        'close': [c.close for c in candles],
        'volume': [c.volume for c in candles],
    }
    df = pd.DataFrame(data)
    if candles[0].timestamp:
        df.index = [c.timestamp for c in candles]
    return df


@app.post("/fvg/detect", response_model=Optional[FVGAlertResponse])
async def detect_fvg_alert(data: MarketDataInput):
    """
    Détecte un FVG et génère une alerte si applicable.
    Utilisé pour le timeframe M5 principalement.
    """
    if len(data.candles) < 3:
        raise HTTPException(400, "Minimum 3 bougies requises pour détecter un FVG")
    
    df = _candles_to_dataframe(data.candles)
    tf = TimeFrame[data.timeframe]
    
    from fvg_spike_detector import FVGCalculator
    calc = FVGCalculator()
    fvgs = calc.detect_fvg(df, tf)
    
    supply_fvgs = [f for f in fvgs if f.is_supply]
    if not supply_fvgs:
        return None
    
    best = max(supply_fvgs, key=lambda x: x.confidence)
    
    return FVGAlertResponse(
        symbol=data.symbol,
        alert_type="FVG_SUPPLY",
        fvg_type="SUPPLY",
        fvg_size=best.size,
        confidence=best.confidence,
        message=f"FVG Supply détecté sur {data.symbol} ({data.timeframe})",
        timestamp=datetime.now(),
        triggered=True
    )


@app.post("/fvg/analyze", response_model=dict)
async def analyze_confluence(m5_data: MarketDataInput, m1_data: MarketDataInput):
    """
    Analyse la confluence M5 + M1 et retourne le statut complet.
    Si confluence positive, retourne le signal de trade.
    """
    # Alerte M5
    alert = None
    if m5_data.candles and len(m5_data.candles) >= 3:
        df_m5 = _candles_to_dataframe(m5_data.candles)
        alert = await detector.process_m5_candle(m5_data.symbol, df_m5)
    
    # Signal M1
    signal = None
    if m1_data.candles and len(m1_data.candles) >= 3:
        df_m1 = _candles_to_dataframe(m1_data.candles)
        signal = await detector.process_m1_candle(m1_data.symbol, df_m1, alert)
    
    return {
        "m5_alert": {
            "detected": alert is not None,
            "confidence": alert.fvg.confidence if alert else 0.0,
            "message": alert.message if alert else "Aucun FVG M5"
        },
        "m1_signal": {
            "detected": signal is not None,
            "direction": signal.direction if signal else None,
            "confidence": signal.confidence if signal else 0.0,
        },
        "trade_recommandation": {
            "action": "EXECUTE" if signal else "WAIT",
            "details": TradeSignalResponse(
                symbol=signal.symbol,
                direction=signal.direction,
                entry_price=signal.entry_price,
                stop_loss=signal.stop_loss,
                take_profit=signal.take_profit,
                lot_size=signal.lot_size,
                confidence=signal.confidence,
                timeframe_confluence=["M5", "M1"],
                risk_amount_usd=2.50,
                risk_reward_ratio=abs(signal.take_profit - signal.entry_price) / abs(signal.entry_price - signal.stop_loss),
                timestamp=signal.timestamp
            ).dict() if signal else None
        }
    }


@app.post("/trade/calculate-risk", response_model=RiskCalculationResponse)
async def calculate_risk(req: RiskCalculationRequest):
    """
    Calcule le lot optimal pour respecter le risque maximum de $2.50
    Adapté pour Boom/Crash et autres synthétiques.
    """
    from fvg_spike_detector import RiskManager
    
    sl_distance = abs(req.entry_price - req.stop_loss)
    if sl_distance == 0:
        raise HTTPException(400, "Stop Loss doit être différent du prix d'entrée")
    
    # Valeur pip pour Boom/Cash sur Deriv/Weltrade
    # Approximation: 1 lot = $1 par pip de mouvement pour Boom 500
    pip_value = 0.01  # Pour Boom 500 (volatilité en 0.01)
    if "1000" in req.symbol:
        pip_value = 0.02  # Boom 1000 peut avoir une valeur pip différente
    
    # Calcul du nombre de pips pour le SL
    sl_pips = sl_distance / pip_value
    
    # Calcul du lot
    risk_manager = RiskManager(max_risk_usd=req.max_risk_usd)
    lot_size = risk_manager.calculate_lot_size(req.entry_price, req.stop_loss, req.symbol)
    
    # Risque réel basé sur le lot calculé
    actual_risk = sl_pips * lot_size * pip_value
    
    # Leverage typique pour ces instruments
    leverage = 100.0
    margin = None
    if req.account_balance:
        margin = (lot_size * req.entry_price) / leverage
    
    return RiskCalculationResponse(
        symbol=req.symbol,
        lot_size=lot_size,
        max_risk_usd=req.max_risk_usd,
        actual_risk_usd=round(actual_risk, 2),
        sl_distance_pips=round(sl_pips, 2),
        pip_value_usd=pip_value,
        leverage_used=leverage,
        margin_required_usd=round(margin, 2) if margin else None,
        recommended=actual_risk <= req.max_risk_usd
    )


@app.get("/status/{symbol}")
async def get_status(symbol: str):
    """Retourne le statut du détecteur pour un symbole"""
    return detector.get_status(symbol)


@app.get("/alerts/recent")
async def get_recent_alerts(limit: int = Query(10, ge=1, le=100)):
    """Retourne les alertes récentes"""
    return _recent_alerts[-limit:]


@app.get("/signals/recent")
async def get_recent_signals(limit: int = Query(10, ge=1, le=100)):
    """Retourne les signaux de trade récents"""
    return _recent_signals[-limit:]


@app.get("/health")
async def health_check():
    """Endpoint de santé"""
    return {
        "status": "healthy",
        "service": "FVG Spike Detector",
        "version": "1.0.0",
        "max_risk_usd": 2.50,
        "symbols_monitored": len(detector._last_alert)
    }


# Lancer le serveur
if __name__ == "__main__":
    import uvicorn
    logger.info("🚀 Lancement du serveur FVG Spike Detector API")
    uvicorn.run(app, host="0.0.0.0", port=8001)
