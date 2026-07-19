#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Symboles Top 3 — lu depuis le scan matinal (jamais XAUUSD forcé)."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
STATE_FILE = REPO_ROOT / "data" / "state" / "morning_top3.json"
ACTIVE_FILE = REPO_ROOT / "data" / "active_symbols.txt"


def load_top3_meta() -> list[dict[str, Any]]:
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            top3 = data.get("top3") or []
            if top3:
                return top3
        except Exception:
            pass
    return []


def load_top3_symbols() -> list[str]:
    syms = [x["symbol"] for x in load_top3_meta() if x.get("symbol")]
    if syms:
        return syms[:3]

    if ACTIVE_FILE.exists():
        lines = [
            ln.strip()
            for ln in ACTIVE_FILE.read_text(encoding="utf-8").splitlines()
            if ln.strip()
        ]
        if lines:
            return lines[:3]

    return fallback_symbols()


def fallback_symbols() -> list[str]:
    """Repli sans privilégier l'or — Deriv / Weltrade."""
    weekend = datetime.now(timezone.utc).weekday() >= 5
    if weekend:
        return [
            "Volatility 75 Index",
            "Boom 600 Index",
            "Crash 600 Index",
        ]
    return [
        "Volatility 75 Index",
        "Boom 600 Index",
        "EURUSD",
    ]
