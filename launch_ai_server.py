#!/usr/bin/env python3
"""AI Server launcher — production stable (pas de reload automatique)"""

import sys
import subprocess

# IMPORTANT: pas de --reload pour éviter les redémarrages sur écriture de fichiers
# (logs, data, .mq5, etc. déclencheraient des restarts intempestifs)
result = subprocess.run([
    sys.executable, "-m", "uvicorn",
    "ai_server:app",
    "--host", "127.0.0.1",
    "--port", "8000",
    "--log-level", "info",
    "--timeout-keep-alive", "30",
    "--timeout-graceful-shutdown", "10",
], cwd="D:/Dev/TradBOT")

sys.exit(result.returncode)
