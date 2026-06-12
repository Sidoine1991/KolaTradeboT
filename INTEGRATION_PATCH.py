#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Integration Patch — Comment intégrer les autonomous loops dans ai_server.py

À ajouter dans ai_server.py après les imports et avant les route definitions
"""

# ============================================================================
# STEP 1: Ajouter à la section imports (top of ai_server.py)
# ============================================================================

"""
from autonomous_loops import AutonomousLoopsManager, loops_manager
from autonomous_routes import create_autonomous_router
"""

# ============================================================================
# STEP 2: Ajouter après la création de l'app FastAPI
# ============================================================================

"""
# === AUTONOMOUS LOOPS MANAGEMENT ===
autonomous_router = create_autonomous_router(loops_manager)
app.include_router(autonomous_router)

logger.info("[INIT] Autonomous loops manager initialized")
logger.info("[INIT] Available endpoints:")
logger.info("  POST /autonomous/start-all")
logger.info("  POST /autonomous/stop-all")
logger.info("  POST /autonomous/start/{loop_name}")
logger.info("  POST /autonomous/stop/{loop_name}")
logger.info("  POST /autonomous/run/{loop_name}")
logger.info("  GET /autonomous/status")
logger.info("  GET /autonomous/loops-available")
"""

# ============================================================================
# STEP 3: Startup event (optional - auto-start all loops on server startup)
# ============================================================================

"""
@app.on_event("startup")
async def startup():
    logger.info("[STARTUP] AI Server initializing...")

    # Optionally auto-start all loops
    # Uncomment to enable auto-start
    # result = await loops_manager.start_all_loops()
    # logger.info(f"[STARTUP] Autonomous loops started: {result}")

    logger.info("[STARTUP] AI Server ready!")
"""

# ============================================================================
# FULL EXAMPLE: How to use
# ============================================================================

"""
# Start server
python ai_server.py

# In another terminal:

# 1. Start all loops at once
curl -X POST http://127.0.0.1:8000/autonomous/start-all

# 2. Check status
curl http://127.0.0.1:8000/autonomous/status

# 3. Run a single loop manually
curl -X POST http://127.0.0.1:8000/autonomous/run/gom_sync

# 4. Start individual loop
curl -X POST http://127.0.0.1:8000/autonomous/start/gom_poller

# 5. Stop all loops
curl -X POST http://127.0.0.1:8000/autonomous/stop-all

# 6. List available loops
curl http://127.0.0.1:8000/autonomous/loops-available
"""

# ============================================================================
# RESULT: No more separate terminals!
# ============================================================================

"""
Before (4 separate terminals):
  Terminal 1: python Python/gom_mt5_poller.py
  Terminal 2: python Python/gom_sync_with_report.py --report
  Terminal 3: python Python/pipeline_hourly_autonomous.py
  Terminal 4: python Python/order_recycler.py --loop

After (1 terminal + 1 curl command):
  Terminal 1: python ai_server.py
  Terminal 2: curl -X POST http://127.0.0.1:8000/autonomous/start-all

  Done! All 4 loops running in background.
"""
