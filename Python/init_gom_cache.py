#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Initialise gom_signal.json avec structure par symbole.
Crée des entrées placeholder pour Boom/Crash jusqu'à ce que gom_mcp_poller.py les remplisse.
"""
import sys, io
if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

import json
from pathlib import Path
from datetime import datetime

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"
_DATA_DIR.mkdir(parents=True, exist_ok=True)

# Symboles à supporter
SYMBOLS = [
    "XAUUSD", "EURUSD", "GBPUSD", "USDJPY", "USDCHF",
    "BTCUSD", "ETHUSD",
    "Boom 1000 Index", "Boom 500 Index", "Boom 300 Index", "Boom 600 Index",
    "Crash 1000 Index", "Crash 500 Index", "Crash 300 Index", "Crash 600 Index",
]

def init_gom_cache():
    """Crée gom_signal.json avec structure par symbole."""
    out_file = _DATA_DIR / "gom_signal.json"

    # Template pour chaque symbole
    template = {
        "symbol": None,
        "timestamp": datetime.utcnow().isoformat() + "+00:00",
        "verdict": "WAIT",
        "verdict_num": 0,
        "buy_score": 0.0,
        "sell_score": 0.0,
        "spike_pct": 0.0,
        "quality": 0.0,
        "coherence": 0.0,
        "kola_state": "---",
        "rsi": 50,
        "st_direction": "NEUTRAL",
        "verdict_gap": 0.0,
        "tf_global_dir": "NEUTRAL",
        "tf_bull_count": 0,
        "tf_bear_count": 0,
        "pred_bull": 0,
        "pred_bear": 0,
        "pred_neut": 100,
        "pred_net": 0,
        "setup_type": "NONE",
        "setup_confirm": "",
        "setup_entry": 0.0,
        "setup_sl": 0.0,
        "setup_tp1": 0.0,
        "setup_tp2": 0.0,
        "setup_rr": 0.0,
        "setup_dir": 0,
        "spike_tradable": False,
        "imminence_pct": None,
        "spike_level": None,
    }

    # Créer un dict par symbole
    gom_cache = {}
    for symbol in SYMBOLS:
        entry = template.copy()
        entry["symbol"] = symbol
        gom_cache[symbol] = entry

    # Écrire le fichier
    try:
        out_file.write_text(json.dumps(gom_cache, indent=2), encoding="utf-8")
        print(f"✅ {out_file} initialisé avec {len(gom_cache)} symboles")
        print(f"   Symboles: {', '.join(SYMBOLS[:3])}... (total: {len(SYMBOLS)})")
    except Exception as e:
        print(f"❌ Erreur: {e}")

if __name__ == "__main__":
    init_gom_cache()
