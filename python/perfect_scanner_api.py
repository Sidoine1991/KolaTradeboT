#!/usr/bin/env python3
"""
API for Perfect Opportunity Scanner — FastAPI endpoint
Integrates with main ai_server.py
"""

from fastapi import APIRouter, HTTPException
from datetime import datetime
import os

router = APIRouter(prefix="/api", tags=["scanner"])

# Global state (should be shared with scanner process)
perfect_opportunities = []
last_update = None


@router.get("/perfect-opportunities")
async def get_perfect_opportunities():
    """Get current perfect trading opportunities"""
    return {
        "opportunities": perfect_opportunities,
        "count": len(perfect_opportunities),
        "last_update": last_update,
        "timestamp": datetime.now().isoformat()
    }


@router.get("/perfect-opportunities/{symbol}")
async def get_opportunity_status(symbol: str):
    """Get status for a specific symbol"""
    for opp in perfect_opportunities:
        if opp["symbol"].upper() == symbol.upper():
            return opp

    raise HTTPException(status_code=404, detail=f"No perfect opportunity for {symbol}")


@router.post("/perfect-opportunities/update")
async def update_opportunities(data: dict):
    """Update opportunities list (called by scanner)"""
    global perfect_opportunities, last_update

    perfect_opportunities = data.get("opportunities", [])
    last_update = datetime.now().isoformat()

    return {
        "status": "updated",
        "count": len(perfect_opportunities),
        "timestamp": last_update
    }


if __name__ == "__main__":
    print("Perfect Scanner API ready to be mounted in FastAPI app")
