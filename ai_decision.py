#!/usr/bin/env python3
"""
Serveur principal de décision (FastAPI) pour TradBOT.
Fournit les endpoints :
- POST /trades/feedback : stockage des résultats de trade pour le feedback loop.
- GET  /monitoring/dashboard : agrégation temps réel (win rate, PnL, alertes).
- POST /decision : décision enrichie avec métadonnées (poids, reasoning).

Persistance minimale : fichier JSONL sous data/trade_feedback.jsonl pour éviter
de dépendre d'une base immédiate. Remplacer par PostgreSQL/SQLite en prod.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

logger = logging.getLogger("ai_decision")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

DATA_DIR = Path("data")
DATA_DIR.mkdir(parents=True, exist_ok=True)
FEEDBACK_FILE = DATA_DIR / "trade_feedback.jsonl"

app = FastAPI(title="TradBOT Decision Server", version="1.0.0")


# ----------------------------- Modèles Pydantic -----------------------------
class TradeFeedback(BaseModel):
    symbol: str
    open_time: datetime
    close_time: datetime
    entry_price: float
    exit_price: float
    profit: float
    ai_confidence: float = Field(..., ge=0, le=1)
    coherent_confidence: float = Field(..., ge=0, le=1)
    decision: str
    is_win: bool


class DecisionRequest(BaseModel):
    symbol: str
    timeframe: str = "M5"
    ml_confidence: float = Field(..., ge=0, le=1)
    coherent_confidence: float = Field(..., ge=0, le=1)
    technical_confidence: float = Field(..., ge=0, le=1)
    context_confidence: float = Field(..., ge=0, le=1)
    ml_action: str
    coherent_action: str
    technical_action: str
    context_action: str


class DecisionResponse(BaseModel):
    action: str
    confidence: float
    ml_weight: float
    technical_weight: float
    coherent_weight: float
    context_weight: float
    reasoning: str
    strategy_mode: str


# ----------------------------- Helpers stockage -----------------------------
def _append_feedback(payload: TradeFeedback) -> None:
    """Append feedback to JSONL store."""
    with FEEDBACK_FILE.open("a", encoding="utf-8") as f:
        f.write(payload.json() + "\n")


def _load_feedback() -> List[Dict[str, Any]]:
    if not FEEDBACK_FILE.exists():
        return []
    rows = []
    with FEEDBACK_FILE.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                logger.warning("Ligne JSONL invalide ignorée")
    return rows


# ----------------------------- Logic dashboard -----------------------------
def compute_realtime_stats() -> Dict[str, Any]:
    data = _load_feedback()
    if not data:
        return {
            "win_rate": 0.0,
            "pnl_total": 0.0,
            "pnl_par_symbole": {},
            "objectif_progress": 0.0,
            "alertes": ["Aucune donnée de feedback disponible"],
        }

    total_trades = len(data)
    wins = sum(1 for d in data if d.get("is_win"))
    pnl_total = sum(float(d.get("profit", 0.0)) for d in data)

    # PnL par symbole
    pnl_par_symbole: Dict[str, float] = {}
    for d in data:
        sym = d.get("symbol", "UNKNOWN")
        pnl_par_symbole[sym] = pnl_par_symbole.get(sym, 0.0) + float(d.get("profit", 0.0))

    win_rate = wins / total_trades if total_trades else 0.0

    alertes = []
    if total_trades >= 5 and win_rate < 0.4:
        alertes.append("Win rate faible")
    if pnl_total < -50:  # seuil arbitraire pour alerte
        alertes.append("Pertes cumulées élevées")

    return {
        "win_rate": round(win_rate, 3),
        "pnl_total": round(pnl_total, 2),
        "pnl_par_symbole": {k: round(v, 2) for k, v in pnl_par_symbole.items()},
        "objectif_progress": 0.0,  # TODO: relier à l'objectif quotidien
        "alertes": alertes or ["OK"],
    }


# ----------------------------- Logic décision -----------------------------
def _vote_weighted(req: DecisionRequest) -> DecisionResponse:
    weights = {
        "ml": 0.40,
        "technical": 0.30,
        "coherent": 0.20,
        "context": 0.10,
    }

    buy_score = 0.0
    sell_score = 0.0

    if req.ml_action.upper() == "BUY":
        buy_score += req.ml_confidence * weights["ml"]
    if req.ml_action.upper() == "SELL":
        sell_score += req.ml_confidence * weights["ml"]

    if req.technical_action.upper() == "BUY":
        buy_score += req.technical_confidence * weights["technical"]
    if req.technical_action.upper() == "SELL":
        sell_score += req.technical_confidence * weights["technical"]

    if req.coherent_action.upper() == "BUY":
        buy_score += req.coherent_confidence * weights["coherent"]
    if req.coherent_action.upper() == "SELL":
        sell_score += req.coherent_confidence * weights["coherent"]

    if req.context_action.upper() == "BUY":
        buy_score += req.context_confidence * weights["context"]
    if req.context_action.upper() == "SELL":
        sell_score += req.context_confidence * weights["context"]

    # Décision finale
    if buy_score > sell_score and buy_score > 0.65:
        action = "BUY"
        confidence = buy_score
    elif sell_score > buy_score and sell_score > 0.65:
        action = "SELL"
        confidence = sell_score
    else:
        action = "HOLD"
        confidence = max(buy_score, sell_score)

    reasoning = (
        f"ML:{req.ml_confidence*weights['ml']:.2f} "
        f"Tech:{req.technical_confidence*weights['technical']:.2f} "
        f"Coh:{req.coherent_confidence*weights['coherent']:.2f} "
        f"Ctx:{req.context_confidence*weights['context']:.2f}"
    )

    return DecisionResponse(
        action=action,
        confidence=round(confidence, 3),
        ml_weight=round(req.ml_confidence * weights["ml"], 3),
        technical_weight=round(req.technical_confidence * weights["technical"], 3),
        coherent_weight=round(req.coherent_confidence * weights["coherent"], 3),
        context_weight=round(req.context_confidence * weights["context"], 3),
        reasoning=reasoning,
        strategy_mode="ADAPTIVE",
    )


# ----------------------------- Endpoints -----------------------------
@app.post("/trades/feedback")
async def receive_feedback(payload: TradeFeedback):
    try:
        _append_feedback(payload)
        # Ici on pourrait déclencher un job d'entraînement async/celery
        return {"status": "ok"}
    except Exception as exc:  # pragma: no cover - log en cas d'erreur d'I/O
        logger.exception("Erreur lors de l'enregistrement du feedback")
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/monitoring/dashboard")
async def monitoring_dashboard():
    return compute_realtime_stats()


@app.post("/decision", response_model=DecisionResponse)
async def make_decision(req: DecisionRequest):
    try:
        return _vote_weighted(req)
    except Exception as exc:  # pragma: no cover
        logger.exception("Erreur lors du calcul de décision")
        raise HTTPException(status_code=500, detail=str(exc))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)

