#!/usr/bin/env python3
"""
Serveur GOM ultra-simple — lit gom_signal.json et retourne le verdict brut.
Port 9003 — aucun cache, aucune staleness check.
"""
import json
from pathlib import Path
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

app = FastAPI(title="GOM Clean Server", docs_url=None)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

ROOT = Path(__file__).resolve().parent.parent
GOM_FILE = ROOT / "data" / "gom_signal.json"

@app.get("/gom-verdict")
async def gom_verdict(symbol: str = Query(...)):
    """Retourne le verdict GOM brut sans aucun traitement."""
    try:
        if not GOM_FILE.is_file():
            return {"ok": False, "message": "gom_signal.json not found"}

        data = json.loads(GOM_FILE.read_text(encoding="utf-8"))

        if isinstance(data, dict) and symbol in data:
            result = data[symbol]
            result["ok"] = result.get("verdict_num", 0) != 0
            return result

        return {"ok": False, "message": f"Symbol {symbol} not found"}
    except Exception as e:
        return {"ok": False, "message": str(e)}

@app.get("/health")
async def health():
    return {"ok": True, "status": "running"}

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=9003, log_level="error")
