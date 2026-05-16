#!/usr/bin/env python3
"""
TradBOT AI Server - AWS RDS Version
Prédictions et analyses de marché - Sans Supabase
Version: 2.1.0 AWS-RDS - CLEAN_AWS_ONLY_NO_ENV_VALIDATION

Features:
- Connexion AWS RDS PostgreSQL
- FastAPI server sur port 8000
- Prédictions de signaux de trading
- Analyse de marché
- Pas de dépendances Supabase
- NO environment variable validation needed
- NO Supabase, NO Gemini API key required
"""

import os
import json
import time
import logging
import sys
import argparse
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Dict, Any, List
from dotenv import load_dotenv

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import uvicorn
import psycopg2
from psycopg2.extras import RealDictCursor

# ===== CONFIGURATION =====
load_dotenv()

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ===== DATABASE CONNECTION =====
class DatabaseConnection:
    """Manage PostgreSQL connection on AWS RDS"""

    def __init__(self):
        self.conn = None
        self.host = os.getenv('RDS_HOST', 'localhost')
        self.port = os.getenv('RDS_PORT', '5432')
        self.database = os.getenv('RDS_DATABASE', 'tradbot')
        self.user = os.getenv('RDS_USER', 'postgres')
        self.password = os.getenv('RDS_PASSWORD', '')

    def connect(self) -> bool:
        """Connect to AWS RDS PostgreSQL"""
        try:
            self.conn = psycopg2.connect(
                host=self.host,
                port=self.port,
                database=self.database,
                user=self.user,
                password=self.password
            )
            logger.info(f"✅ Connected to AWS RDS: {self.host}:{self.port}/{self.database}")
            return True
        except Exception as e:
            logger.warning(f"⚠️  AWS RDS connection failed: {e}")
            logger.info("🔄 Continuing with in-memory mode")
            return False

    def execute_query(self, query: str, params: tuple = None) -> List[Dict]:
        """Execute SELECT query"""
        if not self.conn:
            return []

        try:
            with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(query, params or ())
                return cur.fetchall()
        except Exception as e:
            logger.error(f"Query error: {e}")
            return []

    def execute_insert(self, query: str, params: tuple = None) -> bool:
        """Execute INSERT/UPDATE/DELETE query"""
        if not self.conn:
            return False

        try:
            with self.conn.cursor() as cur:
                cur.execute(query, params or ())
                self.conn.commit()
                return True
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Insert error: {e}")
            return False

    def close(self):
        """Close connection"""
        if self.conn:
            self.conn.close()

# ===== MODELS =====
class TradeSignal(BaseModel):
    """Trading signal model"""
    symbol: str = Field(..., description="Trading symbol")
    price: float = Field(..., description="Current price")
    confluence: int = Field(..., ge=1, le=5, description="Confluence level (1-5)")
    timeframe: str = Field(default="M15", description="Timeframe")

class TradeDecision(BaseModel):
    """Trade decision response"""
    action: str = Field(..., description="BUY, SELL, or HOLD")
    confidence: float = Field(..., ge=0, le=1, description="Confidence score")
    quality_score: int = Field(..., ge=0, le=100, description="Quality 0-100")
    reason: str = Field(..., description="Decision reason")
    timestamp: str = Field(default_factory=datetime.now)

# ===== FASTAPI APP =====
app = FastAPI(
    title="TradBOT AI Server",
    description="AI Server for trading signals - AWS RDS Version",
    version="2.1.0-AWS-RDS"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection (global)
db = DatabaseConnection()

# ===== ENDPOINTS =====

@app.on_event("startup")
async def startup():
    """Initialize on startup"""
    logger.info("[STARTUP] TradBOT AI Server starting...")
    db.connect()
    logger.info("[STARTUP] Ready to receive requests")

@app.on_event("shutdown")
async def shutdown():
    """Cleanup on shutdown"""
    logger.info("[SHUTDOWN] Closing database connection...")
    db.close()

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": "2.1.0-AWS-RDS",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "database": "connected" if db.conn else "disconnected"
    }

@app.post("/signal", response_model=TradeDecision)
async def process_signal(signal: TradeSignal):
    """Process trading signal and return decision"""
    try:
        logger.info(f"Processing signal: {signal.symbol} @ {signal.price} (confluence: {signal.confluence}/5)")

        # Calculate quality score
        quality = calculate_quality_score(signal.confluence)

        # Determine action
        if signal.confluence >= 3 and quality >= 50:
            action = "BUY"
            confidence = min(0.95, signal.confluence * 0.15 + 0.1)
        else:
            action = "HOLD"
            confidence = 0.3

        decision = TradeDecision(
            action=action,
            confidence=confidence,
            quality_score=quality,
            reason=f"Confluence: {signal.confluence}/5 | Quality: {quality}/100 | Timeframe: {signal.timeframe}"
        )

        logger.info(f"Decision: {action} (confidence: {confidence:.2f}, quality: {quality})")

        # Store in database if connected
        if db.conn:
            store_decision(signal, decision)

        return decision

    except Exception as e:
        logger.error(f"Error processing signal: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/analyze")
async def analyze_market(data: Dict[str, Any]):
    """Analyze market conditions"""
    try:
        symbol = data.get("symbol", "UNKNOWN")
        timeframe = data.get("timeframe", "M15")

        logger.info(f"Analyzing {symbol} on {timeframe}")

        analysis = {
            "symbol": symbol,
            "timeframe": timeframe,
            "structure": "UPTREND",
            "bos_detected": True,
            "liquidity_level": "HIGH",
            "recommendation": "WAIT_FOR_PULLBACK",
            "next_support": 1.2050,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        return analysis

    except Exception as e:
        logger.error(f"Error analyzing market: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/signals/recent")
async def get_recent_signals(limit: int = 10):
    """Get recent trading signals from database"""
    try:
        if not db.conn:
            return {"signals": [], "message": "Database not connected"}

        query = "SELECT * FROM trading_signals ORDER BY created_at DESC LIMIT %s"
        signals = db.execute_query(query, (limit,))

        return {
            "signals": signals,
            "count": len(signals),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

    except Exception as e:
        logger.error(f"Error fetching signals: {e}")
        return {"signals": [], "error": str(e)}

@app.get("/ping")
async def ping():
    """Simple ping endpoint"""
    return {
        "status": "online",
        "message": "AI Server Running",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

# ===== HELPER FUNCTIONS =====

def calculate_quality_score(confluence: int) -> int:
    """Calculate signal quality based on confluence"""
    if confluence < 3:
        return 30
    elif confluence == 3:
        return 60
    elif confluence == 4:
        return 80
    else:
        return 100

def store_decision(signal: TradeSignal, decision: TradeDecision):
    """Store trading decision in database"""
    try:
        query = """
        INSERT INTO trading_signals
        (symbol, price, confluence, action, confidence, quality_score, reason, created_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, NOW())
        """
        params = (
            signal.symbol,
            signal.price,
            signal.confluence,
            decision.action,
            decision.confidence,
            decision.quality_score,
            decision.reason
        )

        if db.execute_insert(query, params):
            logger.debug(f"Decision stored: {signal.symbol} {decision.action}")

    except Exception as e:
        logger.warning(f"Could not store decision: {e}")

# ===== MAIN =====

@app.post("/decision")
async def decision(signal: TradeSignal):
    """
    Endpoint /decision - Decisiones de trading para SMC_Universal.mq5
    Analiza señal y retorna acción de trading
    """
    try:
        # Calcular score de calidad
        quality_score = calculate_quality_score(signal.confluence)

        # Determinar acción basada en confluence y precio
        if signal.confluence >= 4 and signal.price > 0:
            action = "BUY" if signal.direction > 0 else "SELL"
            confidence = min(0.5 + (signal.confluence / 10.0), 0.95)
        else:
            action = "HOLD"
            confidence = 0.5

        decision = TradeDecision(
            action=action,
            confidence=confidence,
            reason=f"Confluence: {signal.confluence}/5 | Quality: {quality_score}%",
            quality_score=quality_score,
            entry_price=signal.price,
            stop_loss=signal.price * 0.98 if signal.direction > 0 else signal.price * 1.02,
            take_profit=signal.price * 1.02 if signal.direction > 0 else signal.price * 0.98
        )

        # Guardar decisión en BD
        store_decision(signal, decision)

        logger.info(f"✅ Decision: {signal.symbol} → {action} (confidence: {confidence:.2f})")

        return decision.dict()

    except Exception as e:
        logger.error(f"Error in /decision endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


def main():
    """Start the AI Server"""
    print("🚀 Starting TradBOT AI Server - CLEAN AWS RDS VERSION (no env validation)")
    parser = argparse.ArgumentParser(description='TradBOT AI Server - AWS RDS Version')
    parser.add_argument('--host', default='127.0.0.1', help='Host address')
    parser.add_argument('--port', type=int, default=8000, help='Port number')
    parser.add_argument('--reload', action='store_true', help='Auto-reload on code changes')
    parser.add_argument('--workers', type=int, default=4, help='Number of workers')

    args = parser.parse_args()

    print(f"""
    ╔════════════════════════════════════════╗
    ║  TradBOT AI Server - AWS RDS Version   ║
    ║  Version: 2.1.0                        ║
    ╠════════════════════════════════════════╣
    ║  Starting on {args.host}:{args.port:<24} ║
    ║  Workers: {args.workers:<32} ║
    ╚════════════════════════════════════════╝
    """)

    uvicorn.run(
        "ai_server_aws_rds:app",
        host=args.host,
        port=args.port,
        reload=args.reload,
        workers=args.workers,
        log_level="info"
    )

if __name__ == '__main__':
    main()
