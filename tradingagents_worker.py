#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TradingAgents Worker - Processus séparé pour isoler le LLM.
Communique avec ai_server.py via HTTP interne (localhost:15000 par défaut).
"""

import os
import sys
import json
import time
import asyncio
import logging
import subprocess
from pathlib import Path
from typing import Optional, Dict, Any
from datetime import datetime, timezone

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("ta_worker")

# === CFG ===
PORT = int(os.getenv("TA_WORKER_PORT", "15000"))
HOST = os.getenv("TA_WORKER_HOST", "127.0.0.1")
CACHE_MAX_AGE = int(os.getenv("TA_WORKER_CACHE_MAX_AGE", "300"))  # 5 minutes
MAX_SIMULTANEOUS = int(os.getenv("TA_WORKER_MAX_SIMULTANEOUS", "2"))

# Global state
_results_cache: Dict[str, Dict[str, Any]] = {}
_lock = asyncio.Lock()
_semaphore = asyncio.Semaphore(MAX_SIMULTANEOUS)


def _get_tradingagents_path() -> str:
    """Récupère le chemin vers le dépôt TradingAgents."""
    from pathlib import Path
    repo_path = os.getenv("AI_TRADINGAGENTS_REPO_PATH") or r"D:\Dev\Depot Github\TradingAgents-main"
    return str(Path(repo_path).resolve())


def _import_tradingagents_local():
    """Importe TradingAgents depuis le dépôt local."""
    repo_path = _get_tradingagents_path()
    if repo_path not in sys.path:
        sys.path.insert(0, repo_path)
    
    from tradingagents.graph.trading_graph import TradingAgentsGraph
    from tradingagents.default_config import DEFAULT_CONFIG
    return TradingAgentsGraph, DEFAULT_CONFIG


def _mt5_to_yfinance_ticker(symbol: str) -> str:
    """Convertit symbole MT5 vers ticker yfinance."""
    s = str(symbol).strip().upper().replace(" ", "")
    mapping = {
        "XAUUSD": "GC=F", "XAGUSD": "SI=F", "US30": "^DJI", "US100": "^NDX",
        "EU": "EURUSD=X", "EURUSD": "EURUSD=X", "USDJPY": "USDJPY=X",
        "GBPUSD": "GBPUSD=X", "USDCHF": "USDCHF=X", "AUDUSD": "AUDUSD=X",
        "USDCAD": "USDCAD=X", "NZDUSD": "NZDUSD=X",
    }
    return mapping.get(s, s)


def _extract_recommendation(decision) -> Dict[str, Any]:
    """Extrait une recommandation normalisée depuis l'objet decision."""
    try:
        rec = str(getattr(decision, 'recommendation', 'HOLD')).upper().strip()
    except Exception:
        rec = "HOLD"
    
    try:
        conf = float(getattr(decision, 'confidence', 0.0))
    except Exception:
        conf = 0.0
    
    return {
        "recommendation": rec,
        "confidence": min(1.0, max(0.0, conf)),
        "status": "ok",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


# === Core: cache + runner sécurisé ===

async def _run_ta_analysis(symbol: str) -> Dict[str, Any]:
    """Exécute TradingAgents et retourne le résultat."""
    try:
        TradingAgentsGraph, ta_default_config = _import_tradingagents_local()
        data_ticker = _mt5_to_yfinance_ticker(symbol)
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        
        def _sync_run():
            cfg = ta_default_config.copy()
            # Override LLM provider depuis env si besoin
            ta_graph = TradingAgentsGraph(debug=False, config=cfg)
            _, decision = ta_graph.propagate(data_ticker, today)
            return _extract_recommendation(decision)
        
        logger.info("[TA-Worker] Starting analysis for %s", symbol)
        result = await asyncio.to_thread(_sync_run)
        result["data_ticker"] = data_ticker
        result["symbol"] = symbol
        return result
        
    except Exception as exc:
        logger.error("[TA-Worker] Error for %s: %s", symbol, exc, exc_info=True)
        return {
            "symbol": symbol,
            "recommendation": "HOLD",
            "confidence": 0.0,
            "status": "error",
            "error": str(exc),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }


async def get_cached_or_run(symbol: str) -> Dict[str, Any]:
    """Retourne le cache si valide, sinon exécute et met en cache."""
    sym = str(symbol).strip().upper()
    now = time.time()
    
    async with _lock:
        cached = _results_cache.get(sym)
        if cached and (now - cached.get("_cached_at", 0)) < CACHE_MAX_AGE:
            logger.info("[TA-Worker] Cache hit for %s (age=%.0fs)", sym, now - cached["_cached_at"])
            return {**cached, "status": "cached"}
    
    # Limiter le nombre d'analyses simultanées
    async with _semaphore:
        result = await _run_ta_analysis(sym)
        result["_cached_at"] = time.time()
        
        async with _lock:
            _results_cache[sym] = result
            
        return result


# === HTTP Server (FastAPI minimal) ===

from fastapi import FastAPI, HTTPException
import uvicorn

app = FastAPI(title="TradingAgents Worker", version="1.0.0")


@app.get("/health")
async def health():
    """Vérifie que le worker est vivant."""
    return {
        "status": "ok",
        "uptime": time.time() ,
        "cache_size": len(_results_cache),
    }


@app.post("/run")
async def run_analysis(payload: Dict[str, Any]) -> Dict[str, Any]:
    """
    Lance une analyse TradingAgents pour un symbole.
    JSON: {"symbol": "XAUUSD"}
    Retourne le résultat (cache ou nouveau).
    """
    symbol = str(payload.get("symbol", "")).strip().upper()
    if not symbol:
        raise HTTPException(status_code=400, detail="symbol requis")
    
    logger.info("[TA-Worker] /run reçu pour %s", symbol)
    return await get_cached_or_run(symbol)


@app.get("/status/{symbol}")
async def get_status(symbol: str):
    """Retourne le statut d'un symbole (dernier résultat en cache)."""
    sym = str(symbol).strip().upper()
    cached = _results_cache.get(sym)
    if not cached:
        return {"status": "not_found", "symbol": sym}
    
    age = time.time() - cached.get("_cached_at", 0)
    return {
        "status": "ok",
        "symbol": sym,
        "cached_age_seconds": round(age, 1),
        "recommendation": cached.get("recommendation"),
        "confidence": cached.get("confidence"),
    }


@app.post("/shutdown")
async def shutdown():
    """Arrête proprement le worker."""
    logger.info("[TA-Worker] Shutdown reçu")
    os._exit(0)


def main():
    logger.info("[TA-Worker] Démarrage sur http://%s:%d", HOST, PORT)
    logger.info("[TA-Worker] Cache TTL: %ds | Max simultané: %d", CACHE_MAX_AGE, MAX_SIMULTANEOUS)
    uvicorn.run(app, host=HOST, port=PORT, log_level="warning", access_log=False)


if __name__ == "__main__":
    main()
