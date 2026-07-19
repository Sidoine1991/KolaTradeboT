"""
Register Core Engine routes on an existing FastAPI app.
Usage in ai_server.py or any other FastAPI server:

    from core.register_routes import register_core_routes

    app = FastAPI(...)
    register_core_routes(app)  # Ajoute /api/core/*
"""

import logging
from fastapi import FastAPI, APIRouter, Query, Path
from typing import Optional, List

logger = logging.getLogger("tradbot.core_routes")

router = APIRouter(prefix="/api/core", tags=["core"])


def register_core_routes(app: FastAPI) -> None:
    """
    Ajoute les routes /api/core/* sur l'application FastAPI existante.
    """
    from core.bridge import CoreBridge, get_engine

    # Créer l'engine (sans auto-démarrage — laissé au contrôle du serveur)
    engine = get_engine(phone="", auto_start=False)
    bridge = CoreBridge(engine)

    @router.get("/status")
    async def core_status():
        return bridge.api_engine_status()

    @router.get("/signals")
    async def core_signals():
        return bridge.api_get_signals()

    @router.get("/risk")
    async def core_risk():
        return bridge.api_risk_status()

    @router.get("/scan-patterns")
    async def scan_patterns(
        symbol: str = Query(..., description="Trading symbol"),
        timeframe: str = Query("M15", description="Timeframe"),
    ):
        return bridge.api_scan_patterns(symbol, timeframe)

    @router.post("/place-order")
    async def place_order(
        symbol: str = Query(...),
        direction: str = Query(..., regex="^(BUY|SELL)$"),
        volume: float = Query(0.01, ge=0.001, le=100),
        sl: Optional[float] = Query(None),
        tp: Optional[float] = Query(None),
    ):
        return bridge.api_place_order({
            "symbol": symbol, "direction": direction,
            "volume": volume, "sl": sl, "tp": tp,
        })

    @router.post("/close-position")
    async def close_position(symbol: str = Query(...)):
        return bridge.api_close_position(symbol)

    @router.get("/trail-config")
    async def core_trail_config(
        activation: Optional[float] = Query(None, ge=1, description="Activation pips (global)"),
        distance: Optional[float] = Query(None, ge=0.5, description="Distance pips (global)"),
        step: Optional[float] = Query(None, ge=0.1, description="Step pips (global)"),
    ):
        if activation is not None:
            engine.config.trailing_activation_pips = activation
        if distance is not None:
            engine.config.trailing_distance_pips = distance
        if step is not None:
            engine.config.trailing_step_pips = step
        return bridge.api_trail_config()

    @router.put("/trail-config/{symbol}")
    async def core_set_trail_config(
        symbol: str = Path(...),
        activation: Optional[float] = Query(None, ge=1),
        distance: Optional[float] = Query(None, ge=0.5),
        step: Optional[float] = Query(None, ge=0.1),
    ):
        return bridge.api_set_trail_config(symbol, activation, distance, step)

    @router.delete("/trail-config/{symbol}")
    async def core_delete_trail_config(symbol: str = Path(...)):
        return bridge.api_delete_trail_config(symbol)

    @router.get("/trail-config/{symbol}")
    async def core_get_trail_config(symbol: str = Path(...)):
        return {
            "ok": True,
            "symbol": symbol,
            "config": engine.get_trail_config(symbol).to_dict(),
            "effective": engine.get_effective_trail_params(symbol),
        }

    # ── Endpoints dashboard ─────────────────────────────
    @router.get("/opportunities")
    async def core_opportunities():
        return bridge.api_opportunities()

    @router.get("/symbol/{symbol}")
    async def core_symbol_deep(symbol: str = Path(..., description="Trading symbol")):
        return bridge.api_symbol_deep(symbol)

    @router.get("/positions")
    async def core_positions():
        return bridge.api_positions()

    @router.get("/portfolio")
    async def core_portfolio():
        return bridge.api_portfolio()

    @router.get("/multi-scan/{symbol}")
    async def core_multi_scan(
        symbol: str = Path(...),
        timeframes: str = Query("M5,M15,H1", description="Comma-separated timeframes"),
    ):
        tf_list = [t.strip() for t in timeframes.split(",") if t.strip()]
        return bridge.api_multi_timeframe(symbol, tf_list)

    @router.get("/history")
    async def core_history(limit: int = Query(20, ge=1, le=100)):
        return bridge.api_order_history(limit)

    @router.post("/start")
    async def core_start():
        engine.start()
        return {"ok": True, "message": "Engine started"}

    @router.post("/stop")
    async def core_stop():
        engine.stop()
        return {"ok": True, "message": "Engine stopped"}

    @router.get("/combined-signal")
    async def combined_signal(symbol: str = Query(...)):
        return bridge.get_combined_signal(symbol)

    app.include_router(router)
    logger.info("✅ Core Engine routes registered at /api/core/*")

    # Si le serveur est l'AI server, on peut auto-start
    # Décommenter pour démarrage automatique:
    # engine.start()
