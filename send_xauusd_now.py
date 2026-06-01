#!/usr/bin/env python3
"""OBSOLÈTE — redirige vers le suivi Top 3 (scan matinal, pas XAUUSD seul)."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TARGET = ROOT / "scripts" / "unified_top3_master_report.py"

print("send_xauusd_now.py est deprecie → Top 3 scan matinal")
sys.exit(subprocess.call([sys.executable, str(TARGET)], cwd=str(ROOT)))
