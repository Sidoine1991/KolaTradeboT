#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OBSOLÈTE — ne plus utiliser pour XAUUSD seul.

Redirige vers le suivi 20 min Top 3 (scan matinal Deriv/Weltrade).
"""
import subprocess
import sys
from pathlib import Path

if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

ROOT = Path(__file__).resolve().parent
TARGET = ROOT / "scripts" / "unified_top3_master_report.py"

print("⚠️  xauusd_20min_monitor.py est déprécié.")
print("    Suivi = Top 3 du scan matinal (pas l'or seul).")
print(f"    → {TARGET}\n")

if not TARGET.exists():
    print(f"❌ Script introuvable: {TARGET}")
    sys.exit(1)

sys.exit(subprocess.call([sys.executable, str(TARGET)], cwd=str(ROOT)))
