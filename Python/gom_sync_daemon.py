#!/usr/bin/env python3
"""
GOM Sync Daemon — Boucle automatique toutes les 10 minutes
Exécution: python Python/gom_sync_daemon.py
"""
import sys
import time
import subprocess
from pathlib import Path
from datetime import datetime

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

INTERVAL = 60  # 1 minute en secondes (au lieu de 10 min)
SCRIPT = "Python/gom_sync_with_report.py"

def run_sync():
    """Exécute une synchro unique."""
    try:
        result = subprocess.run(
            [sys.executable, SCRIPT, "--report"],
            cwd="D:/Dev/TradBOT",
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode == 0:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] ✅ GOM Sync OK")
            return True
        else:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ GOM Sync ERROR:\n{result.stderr}")
            return False
    except subprocess.TimeoutExpired:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ⏱  GOM Sync TIMEOUT (> 30s)")
        return False
    except Exception as e:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ ERROR: {e}")
        return False

def main():
    """Boucle daemon."""
    print("="*70)
    print(f"🚀 GOM SYNC DAEMON — Synchro toutes les {INTERVAL//60} minutes")
    print("="*70)

    # Première synchro immédiate
    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] ⏳ Synchro initiale...")
    run_sync()

    # Boucle infinie
    while True:
        print(f"\n⏳ Prochain sync dans {INTERVAL//60} min...", end="", flush=True)
        try:
            time.sleep(INTERVAL)
        except KeyboardInterrupt:
            print("\n\n⏹  Arrêt utilisateur")
            break

        print(f" [{datetime.now().strftime('%H:%M:%S')}]")
        run_sync()

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\n❌ Daemon ERROR: {e}")
        sys.exit(1)
