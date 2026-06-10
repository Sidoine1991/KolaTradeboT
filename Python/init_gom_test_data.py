#!/usr/bin/env python3
"""
Initialise gom_signal.json avec données de TEST pour tous les symboles.
Permet à MT5 de tester la synchronisation GOM sans dépendre du poller TradingView.
"""
import json
from pathlib import Path
from datetime import datetime

_ROOT = Path(__file__).resolve().parent.parent
_DATA_DIR = _ROOT / "data"
_DATA_DIR.mkdir(parents=True, exist_ok=True)

# Données de test pour chaque symbole
TEST_DATA = {
    "XAUUSD": {
        "symbol": "XAUUSD",
        "timestamp": datetime.utcnow().isoformat() + "+00:00",
        "verdict": "GOOD BUY",
        "verdict_num": 2,
        "bb_up": 4200.0,
        "bb_mid": 4195.0,
        "bb_dn": 4190.0,
        "kola_buy": 4185.0,
        "kola_sell": 4205.0,
    },
    "Boom 500 Index": {
        "symbol": "Boom 500 Index",
        "timestamp": datetime.utcnow().isoformat() + "+00:00",
        "verdict": "HOLD",
        "verdict_num": 1,
        "bb_up": 5320.0,
        "bb_mid": 5310.0,
        "bb_dn": 5300.0,
        "kola_buy": 5295.0,
        "kola_sell": 5325.0,
    },
    "Boom 1000 Index": {
        "symbol": "Boom 1000 Index",
        "timestamp": datetime.utcnow().isoformat() + "+00:00",
        "verdict": "GOOD SELL",
        "verdict_num": -2,
        "bb_up": 13900.0,
        "bb_mid": 13850.0,
        "bb_dn": 13800.0,
        "kola_buy": 13780.0,
        "kola_sell": 13920.0,
    },
    "Crash 500 Index": {
        "symbol": "Crash 500 Index",
        "timestamp": datetime.utcnow().isoformat() + "+00:00",
        "verdict": "BUY",
        "verdict_num": 1,
        "bb_up": 450.0,
        "bb_mid": 445.0,
        "bb_dn": 440.0,
        "kola_buy": 435.0,
        "kola_sell": 455.0,
    },
    "Crash 1000 Index": {
        "symbol": "Crash 1000 Index",
        "timestamp": datetime.utcnow().isoformat() + "+00:00",
        "verdict": "WAIT",
        "verdict_num": 0,
        "bb_up": 950.0,
        "bb_mid": 945.0,
        "bb_dn": 940.0,
        "kola_buy": 935.0,
        "kola_sell": 955.0,
    },
    "BTCUSD": {
        "symbol": "BTCUSD",
        "timestamp": datetime.utcnow().isoformat() + "+00:00",
        "verdict": "GOOD BUY",
        "verdict_num": 2,
        "bb_up": 42500.0,
        "bb_mid": 42000.0,
        "bb_dn": 41500.0,
        "kola_buy": 41000.0,
        "kola_sell": 43000.0,
    },
    "ETHUSD": {
        "symbol": "ETHUSD",
        "timestamp": datetime.utcnow().isoformat() + "+00:00",
        "verdict": "HOLD",
        "verdict_num": 1,
        "bb_up": 2400.0,
        "bb_mid": 2350.0,
        "bb_dn": 2300.0,
        "kola_buy": 2280.0,
        "kola_sell": 2420.0,
    },
}

def init_test_data():
    out_file = _DATA_DIR / "gom_signal.json"
    try:
        out_file.write_text(json.dumps(TEST_DATA, indent=2), encoding="utf-8")
        print(f"✅ {out_file} initialisé avec données TEST")
        print(f"   Symboles: {', '.join(TEST_DATA.keys())}")
        print("")
        print("📌 IMPORTANT: Ces données sont de TEST uniquement!")
        print("   Pour avoir les vrais données, lancez: python master_gom_poller.py")
    except Exception as e:
        print(f"❌ Erreur: {e}")

if __name__ == "__main__":
    init_test_data()
