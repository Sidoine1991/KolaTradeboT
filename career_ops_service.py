"""
Career-Ops Standalone Service for Render
FastAPI application for job prospection + RDS backend
Runs independently on port 8001
"""

import sys
from pathlib import Path
import logging

_root = Path(__file__).resolve().parent
sys.path.insert(0, str(_root))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os

# Import Career-Ops API router
from career_ops_api_rds import router as careerops_router

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("career_ops_service")

# Create FastAPI app
app = FastAPI(
    title="Career-Ops Service",
    description="Autonomous job prospection + RDS backend",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins (can restrict to specific domains)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Career-Ops router
app.include_router(careerops_router, prefix="/api")

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint for Render"""
    return {
        "status": "healthy",
        "service": "Career-Ops",
        "version": "1.0.0"
    }

# Root endpoint
@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Career-Ops",
        "description": "Autonomous job prospection system",
        "endpoints": {
            "health": "/health",
            "api": "/api/career-ops/*"
        }
    }

# Startup event
@app.on_event("startup")
async def startup_event():
    logger.info("Career-Ops Service starting...")
    logger.info("Environment: " + os.getenv("ENVIRONMENT", "development"))
    logger.info("Service ready on port 8001")

# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Career-Ops Service shutting down...")

if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8001))
    host = os.getenv("HOST", "0.0.0.0")

    logger.info(f"Starting Career-Ops Service on {host}:{port}")

    uvicorn.run(
        "career_ops_service:app",
        host=host,
        port=port,
        reload=os.getenv("ENVIRONMENT") == "development"
    )
