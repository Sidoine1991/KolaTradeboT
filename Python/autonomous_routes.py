#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Autonomous Routes — FastAPI endpoints pour contrôler les boucles autonomes
À importer dans ai_server.py comme blueprints
"""

from fastapi import APIRouter, HTTPException
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)

def create_autonomous_router(loops_manager) -> APIRouter:
    """Create FastAPI router for autonomous loops management."""
    router = APIRouter(prefix="/autonomous", tags=["autonomous"])

    @router.post("/start/{loop_name}")
    async def start_loop(loop_name: str) -> Dict[str, Any]:
        """Start a specific autonomous loop."""
        result = await loops_manager.start_loop(loop_name)
        if "error" in result:
            raise HTTPException(status_code=404, detail=result["error"])
        return result

    @router.post("/stop/{loop_name}")
    async def stop_loop(loop_name: str) -> Dict[str, Any]:
        """Stop a specific autonomous loop."""
        result = await loops_manager.stop_loop(loop_name)
        if "error" in result:
            raise HTTPException(status_code=404, detail=result["error"])
        return result

    @router.post("/run/{loop_name}")
    async def run_loop_once(loop_name: str) -> Dict[str, Any]:
        """Execute one iteration of a loop manually."""
        result = await loops_manager.run_loop_iteration(loop_name)
        if "error" in result:
            raise HTTPException(status_code=500, detail=result["error"])
        return result

    @router.post("/start-all")
    async def start_all() -> Dict[str, Any]:
        """Start all autonomous loops."""
        return await loops_manager.start_all_loops()

    @router.post("/stop-all")
    async def stop_all() -> Dict[str, Any]:
        """Stop all autonomous loops."""
        return await loops_manager.stop_all_loops()

    @router.get("/status")
    async def get_status() -> Dict[str, Any]:
        """Get status of all autonomous loops."""
        return loops_manager.get_status()

    @router.get("/loops-available")
    async def list_available() -> Dict[str, Any]:
        """List all available loops and their configurations."""
        loops_info = {}
        for name, config in loops_manager.loops.items():
            loops_info[name] = {
                "script": config["script"],
                "interval_seconds": config["interval"],
                "description": f"{name} loop (runs every {config['interval']}s)"
            }
        return {
            "available_loops": loops_info,
            "total": len(loops_manager.loops)
        }

    return router
