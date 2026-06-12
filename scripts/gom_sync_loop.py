"""
GOM Sync Loop — boucle autonome toutes les 10 minutes.
Lance: python scripts/gom_sync_loop.py
Arrêt: Ctrl+C
"""
import subprocess
import time
import os
import sys
from datetime import datetime

INTERVAL_SEC = 600  # 10 minutes
PROJECT_DIR  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT       = os.path.join(PROJECT_DIR, "Python", "gom_sync_with_report.py")
LOG_FILE     = os.path.join(PROJECT_DIR, "logs", "gom_sync.log")

os.makedirs(os.path.join(PROJECT_DIR, "logs"), exist_ok=True)

print(f"[GOM Loop] Démarré — interval={INTERVAL_SEC}s | log={LOG_FILE}")
print("[GOM Loop] Ctrl+C pour arrêter\n")

while True:
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[GOM Loop] {now} — Lancement sync...")

    with open(LOG_FILE, "a", encoding="utf-8") as f:
        result = subprocess.run(
            [sys.executable, SCRIPT, "--report"],
            cwd=PROJECT_DIR,
            stdout=f,
            stderr=f
        )

    status = "OK" if result.returncode == 0 else f"ERREUR (code {result.returncode})"
    print(f"[GOM Loop] {now} — {status} | prochain dans {INTERVAL_SEC//60} min")

    try:
        time.sleep(INTERVAL_SEC)
    except KeyboardInterrupt:
        print("\n[GOM Loop] Arrêt demandé.")
        break
