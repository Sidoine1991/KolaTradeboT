#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génère le rapport Word via le scan matinal complet (délègue à morning_scan)."""
import sys
from pathlib import Path

if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

sys.path.insert(0, str(Path(__file__).resolve().parent))

from morning_scan import main

if __name__ == "__main__":
    sys.exit(main())
