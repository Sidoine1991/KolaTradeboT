"""
TradBOT Agent Server — port 8001.
Sert les agents API ET le dashboard via HTTP (resout le blocage file://).

    python agents/server.py          -> http://127.0.0.1:8001/dashboard
    python agents/server.py --port 8002
"""

import argparse
import logging
import sys
import os
from pathlib import Path

# Make imports work from repo root
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
)
logger = logging.getLogger("agent_server")

# Resolve dashboard path relative to this file
DASHBOARD_DIR = (Path(__file__).resolve().parent.parent / "dashboard").resolve()

app = FastAPI(
    title="TradBOT Agent Intelligence Server",
    description="6 autonomous intelligence agents for adaptive trading",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register agent routes
from agents.api_routes import agent_router
app.include_router(agent_router)

# Serve dashboard HTML + static assets
if DASHBOARD_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(DASHBOARD_DIR)), name="static")
else:
    logger.warning("Dashboard dir not found: %s", DASHBOARD_DIR)


@app.get("/", include_in_schema=False)
@app.get("/dashboard", include_in_schema=False)
async def serve_dashboard():
    """Dashboard principal — ouvrir http://127.0.0.1:8001/dashboard"""
    f = DASHBOARD_DIR / "agent_intelligence.html"
    if f.exists():
        return FileResponse(str(f), media_type="text/html")
    return HTMLResponse(
        f"<h2>Fichier introuvable: {f}</h2>"
        f"<p>DASHBOARD_DIR={DASHBOARD_DIR}</p>",
        status_code=404,
    )


@app.get("/health")
async def health():
    return {"status": "ok", "service": "agent_server", "dashboard_dir": str(DASHBOARD_DIR)}


_port = 8001


@app.on_event("startup")
async def startup():
    from agents.orchestrator import get_orchestrator
    get_orchestrator().start_all()
    logger.info("All 6 intelligence agents started")
    logger.info("Dashboard: http://127.0.0.1:%s/dashboard", _port)


@app.on_event("shutdown")
async def shutdown():
    from agents.orchestrator import get_orchestrator
    get_orchestrator().stop_all()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8001)
    parser.add_argument("--host", default="127.0.0.1")
    args = parser.parse_args()
    _port = args.port
    print()
    print("  TradBOT Intelligence Agents")
    print(f"  Dashboard -> http://127.0.0.1:{args.port}/dashboard")
    print(f"  API       -> http://127.0.0.1:{args.port}/agents/status")
    print()
    uvicorn.run("agents.server:app", host=args.host, port=args.port, reload=False)
