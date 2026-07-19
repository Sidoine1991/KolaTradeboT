#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Symboles actifs pour le suivi — priorité au Top 3 du scan matinal.
Ne force plus XAUUSD en tête de liste.
"""

import json
import sys
import io
from datetime import datetime, timezone
from pathlib import Path

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

REPO_ROOT = Path(__file__).resolve().parent.parent
STATE_FILE = REPO_ROOT / "data" / "state" / "morning_top3.json"
ACTIVE_FILE = REPO_ROOT / "data" / "active_symbols.txt"


def load_morning_top3() -> list[str]:
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            syms = [x["symbol"] for x in data.get("top3", []) if x.get("symbol")]
            if syms:
                return syms
        except Exception:
            pass
    if ACTIVE_FILE.exists():
        lines = [
            ln.strip()
            for ln in ACTIVE_FILE.read_text(encoding="utf-8").splitlines()
            if ln.strip()
        ]
        if lines:
            return lines
    return []


def get_market_status() -> dict:
    now = datetime.now(timezone.utc)
    weekend = now.weekday() >= 5
    return {
        "is_weekend": weekend,
        "weekday": now.weekday(),
        "datetime": now,
        "markets": {
            "forex": not weekend,
            "crypto": True,
            "synthetics": True,
        },
    }


def get_symbols_to_monitor() -> tuple[list[str], dict]:
    status = get_market_status()
    top3 = load_morning_top3()
    if top3:
        return top3, status
    # Repli minimal sans privilégier l'or
    if status["is_weekend"]:
        fallback = ["BTCUSD", "ETHUSD", "Volatility 75 Index", "Boom 600 Index"]
    else:
        fallback = ["EURUSD", "GBPUSD", "BTCUSD", "Volatility 75 Index"]
    return fallback, status


def print_market_status() -> None:
    symbols, status = get_symbols_to_monitor()
    source = "scan matinal Top 3" if STATE_FILE.exists() else "repli"

    print("📊 SYMBOLES ACTIFS (suivi)")
    print("=" * 60)
    print(f"Heure: {status['datetime'].strftime('%Y-%m-%d %H:%M UTC')}")
    print(f"Source: {source}")
    print()
    for sym in symbols:
        print(f"  • {sym}")
    print("=" * 60)


if __name__ == "__main__":
    print_market_status()
    symbols, _ = get_symbols_to_monitor()
    ACTIVE_FILE.parent.mkdir(parents=True, exist_ok=True)
    ACTIVE_FILE.write_text("\n".join(symbols) + "\n", encoding="utf-8")
    print(f"\n✅ Écrit: {ACTIVE_FILE}")
