#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UNIFIED TOP 3 DAEMON
Exécute le rapport unifié toutes les 20 minutes
UN SEUL message consolidé envoyé via WhatsApp
"""

import time
import sys
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

if sys.platform == 'win32':
    os.environ['PYTHONIOENCODING'] = 'utf-8'

REPORT_INTERVAL = 20 * 60  # 20 minutes
CHECK_INTERVAL = 5  # Check toutes les 5 sec
REPORT_SCRIPT = Path(__file__).parent / "unified_top3_master_report.py"

def format_time_until(seconds):
    """Formate le temps restant"""
    mins = seconds // 60
    secs = seconds % 60
    return f"{mins}m{secs:02d}s"

def main():
    """Boucle principale"""
    print("=" * 70)
    print("[DAEMON] Unified TOP 3 Report Daemon")
    print(f"[CONFIG] Report interval: {REPORT_INTERVAL // 60} minutes")
    print(f"[SCRIPT] {REPORT_SCRIPT}")
    print("=" * 70)

    last_report_time = time.time() - REPORT_INTERVAL  # Force initial report
    iteration = 0

    try:
        while True:
            current_time = time.time()
            time_since_report = current_time - last_report_time
            time_until_report = REPORT_INTERVAL - time_since_report

            # Afficher le compte a rebours tous les 60 sec
            if int(time_since_report) % 60 == 0 or time_until_report <= 5:
                status_msg = f"[WAIT] Next report in {format_time_until(int(time_until_report))}"
                if time_until_report <= 5:
                    status_msg = f"[FIRE] Report firing in {format_time_until(int(time_until_report))}..."
                print(f"[{datetime.now(timezone.utc).strftime('%H:%M:%S')}] {status_msg}")

            # Déclencher rapport si intervalle écoulé
            if time_since_report >= REPORT_INTERVAL:
                iteration += 1
                print(f"\n{'=' * 70}")
                print(f"[REPORT #{iteration}] {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}")
                print(f"{'=' * 70}")

                try:
                    result = subprocess.run(
                        [sys.executable, str(REPORT_SCRIPT)],
                        capture_output=True,
                        text=True,
                        timeout=30
                    )

                    if result.returncode == 0:
                        print("[SUCCESS] Report generated and sent")
                        # Afficher les lignes importantes
                        for line in result.stdout.split('\n'):
                            if '[SUCCESS]' in line or '[ERROR]' in line or '[COMPLETE]' in line:
                                print(line)
                    else:
                        print(f"[ERROR] Script failed: {result.stderr[:200]}")

                except subprocess.TimeoutExpired:
                    print("[ERROR] Script timeout (>30s)")
                except Exception as e:
                    print(f"[ERROR] {e}")

                last_report_time = current_time
                print(f"\n[NEXT] Report in {REPORT_INTERVAL // 60} minutes\n")

            # Vérifier l'arrêt toutes les N secondes
            time.sleep(CHECK_INTERVAL)

    except KeyboardInterrupt:
        print("\n" + "=" * 70)
        print("[STOP] Daemon stopped (Ctrl+C)")
        print("=" * 70)
        sys.exit(0)
    except Exception as e:
        print(f"[FATAL] {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
