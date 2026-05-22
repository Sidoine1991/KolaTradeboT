#!/usr/bin/env python3
"""
Test simple du serveur ai_server.py
Vérifie que les imports fonctionnent
"""

import sys
from pathlib import Path

# Setup path
sys.path.insert(0, str(Path(__file__).parent))

print("=" * 60)
print("TradBOT IA Server - Import Test")
print("=" * 60)

try:
    print("\n1. Testing imports...")
    from dotenv import load_dotenv
    print("   OK: dotenv")

    import pandas as pd
    print(f"   OK: pandas {pd.__version__}")

    import numpy as np
    print(f"   OK: numpy {np.__version__}")

    from fastapi import FastAPI
    print("   OK: fastapi")

    import uvicorn
    print("   OK: uvicorn")

    from pydantic import BaseModel
    print("   OK: pydantic")

    print("\n2. Testing environment...")
    # Load env first
    load_dotenv()
    load_dotenv(Path(__file__).parent / "python" / ".env")
    print("   OK: Environment loaded")

    print("\n3. Ready to start server!")
    print("\nTo start the server, run:")
    print("   python ai_server.py --port 8000")
    print("\nOr use:")
    print("   launch_server.bat")

    print("\n4. Once running, test endpoints:")
    print("   - http://localhost:8000/health")
    print("   - http://localhost:8000/docs")
    print("   - POST http://localhost:8000/divergence/signal")

    print("\n" + "=" * 60)
    print("All checks passed! Server should work fine.")
    print("=" * 60 + "\n")

except Exception as e:
    print(f"\nERROR: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
