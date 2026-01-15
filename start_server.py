#!/usr/bin/env python3
"""
Script de démarrage pour Render
"""

import os
import uvicorn

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(
        "ai_server:app",
        host="0.0.0.0",
        port=port,
        log_level="info"
    )

