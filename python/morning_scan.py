#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Point d'entrée legacy — délègue à python/morning_scan.py"""
import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_ROOT / "python"))

from morning_scan import main  # noqa: E402

if __name__ == "__main__":
    sys.exit(main())
