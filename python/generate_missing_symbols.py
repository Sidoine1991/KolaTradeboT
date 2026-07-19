#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génère les verdicts GOM pour les symboles manquants en MT5."""
import json
import sys
from pathlib import Path
from datetime import datetime, timezone

# Fix encoding for Windows
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

GOM_FILE = Path("D:/Dev/TradBOT/data/gom_signal.json")

# Symboles MT5 typiques à tracker
ALL_SYMBOLS = [
    "XAUUSD", "BTCUSD", "ETHUSD", "EURUSD", "GBPUSD", "USDJPY",
    "AUDUSD", "NZDUSD", "USDCAD", "USDCHF",
    "NAS100", "US30", "EURUSD",
    "DERIV:BOOM_500_INDEX", "DERIV:BOOM_1000_INDEX", "DERIV:BOOM_300_INDEX",
    "DERIV:CRASH_500_INDEX", "DERIV:CRASH_1000_INDEX", "DERIV:CRASH_300_INDEX",
    "Boom 500 Index", "Boom 1000 Index", "Boom 300 Index",
    "Crash 500 Index", "Crash 1000 Index", "Crash 300 Index"
]

def generate_default_verdict(symbol):
    """Génère un verdict par défaut."""
    return {
        "symbol": symbol,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "verdict": "WAIT",
        "verdict_num": 0,
        "bb_mid": 0.0,
        "kola_buy": 0.0,
        "kola_sell": 0.0,
        "entry": 0.0,
        "sl": 0.0,
        "tp": 0.0,
        "tf_m1_dir": "NEUT",
        "tf_m1_rsi": 50,
        "tf_m5_dir": "NEUT",
        "tf_m5_rsi": 50,
        "tf_m15_dir": "NEUT",
        "tf_m15_rsi": 50,
        "tf_h1_dir": "NEUT",
        "tf_h1_rsi": 50,
        "tf_h4_dir": "NEUT",
        "tf_h4_rsi": 50,
        "tf_d1_dir": "NEUT",
        "tf_d1_rsi": 50,
        "tf_global_dir": "NEUT",
        "tf_global_strength": 0
    }

# Charger existants
if GOM_FILE.exists():
    data = json.loads(GOM_FILE.read_text(encoding="utf-8"))
else:
    data = {}

# Ajouter manquants
added = []
for sym in ALL_SYMBOLS:
    if sym not in data:
        data[sym] = generate_default_verdict(sym)
        added.append(sym)

# Sauvegarder
GOM_FILE.write_text(json.dumps(data, indent=2, ensure_ascii=False))

print(f"✅ Ajoutés {len(added)} symboles:")
for s in added:
    print(f"  • {s}")
print(f"\n📊 Total: {len(data)} symboles")
