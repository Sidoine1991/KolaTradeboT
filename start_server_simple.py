#!/usr/bin/env python3
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    import uvicorn
    from ai_server import app
    print("🚀 Démarrage du serveur IA sur le port 8001...")
    uvicorn.run(app, host="127.0.0.1", port=8001, log_level="info")
except Exception as e:
    print(f"❌ Erreur: {e}")
    import traceback
    traceback.print_exc()
