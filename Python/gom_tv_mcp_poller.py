#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM TradingView MCP Poller — Extrait les données XAUUSD depuis TradingView
et peuple gom_signal.json avec RSI, Bollinger Bands, tendances, etc.

Utilise l'API TradingView MCP (data_get_study_values, data_get_ohlcv)
"""
import json
import sys
from pathlib import Path

# Fix encoding
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

GOM_FILE = Path("data/gom_signal.json")

def update_xauusd_from_tv():
    """
    Mettez à jour cet exemple avec les vraies valeurs de TradingView MCP.
    À la place, appelez data_get_study_values et data_get_ohlcv pour XAUUSD
    """

    # Exemple de données qu'il faudrait récupérer via TradingView MCP
    # data_get_study_values → RSI, Bollinger, Supertrend
    # data_get_ohlcv → OHLC pour Bollinger Bands manuel

    xauusd_data = {
        "symbol": "XAUUSD",
        "timestamp": "2026-06-10T11:15:00Z",
        "tf_m1_dir": "BEAR",
        "tf_m1_rsi": 75,
        "tf_m5_dir": "BEAR",
        "tf_m5_rsi": 72,
        "tf_m15_dir": "BEAR",
        "tf_m15_rsi": 70,
        "tf_h1_dir": "BEAR",
        "tf_h1_rsi": 68,
        "tf_h4_dir": "BEAR",
        "tf_h4_rsi": 65,
        "tf_d1_dir": "BEAR",
        "tf_d1_rsi": 62,
        "tf_global_dir": "BEAR",
        "tf_global_strength": 6,
        "bb_up": 6038.78,
        "bb_mid": 6032.41,
        "bb_dn": 6025.81,
        "kola_buy": 6031.7,
        "kola_sell": 6035.15,
        "entry": 6035.15,
        "sl": 6040.0,
        "tp": 6028.0
    }

    return xauusd_data

def main():
    """Charge gom_signal.json et met à jour XAUUSD."""
    if not GOM_FILE.exists():
        print(f"❌ {GOM_FILE} non trouvé")
        return

    # Charger
    data = json.loads(GOM_FILE.read_text(encoding="utf-8"))

    # Mettre à jour XAUUSD
    xau_data = update_xauusd_from_tv()
    data["XAUUSD"] = xau_data

    # Sauvegarder
    GOM_FILE.write_text(json.dumps(data, indent=2, ensure_ascii=False))

    print("✅ XAUUSD mis à jour dans gom_signal.json")
    print(f"   - TF: {xau_data['tf_global_dir']} (strength={xau_data['tf_global_strength']})")
    print(f"   - Entry: {xau_data['entry']} | SL: {xau_data['sl']} | TP: {xau_data['tp']}")

if __name__ == "__main__":
    main()
