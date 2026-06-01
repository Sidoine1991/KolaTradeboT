#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TradingView MCP Bridge — Accès aux données TradingView via MCP depuis Python
Ce script permet à l'AI server d'appeler les MCP tools directement
"""

import requests
import json
import time
from typing import Dict, Any, Optional

class TradingViewMCPBridge:
    """Bridge entre AI server et TradingView MCP tools"""

    def __init__(self, tradingview_url: str = "http://localhost:9222"):
        self.tv_url = tradingview_url
        self.last_quote = {}
        self.last_study_values = {}
        self.last_update = 0
        self.cache_ttl = 10  # cache 10 secondes

    def get_quote(self, symbol: str = "OANDA:XAUUSD") -> Dict[str, Any]:
        """Récupère le prix actuel via TradingView"""
        try:
            # Via CDP direct à TradingView (si disponible)
            # Pour l'instant, retour stub
            return {
                "symbol": symbol,
                "last": 4554.59,
                "high": 4560.00,
                "low": 4550.00,
                "open": 4552.00,
                "close": 4554.59,
                "volume": 1250000
            }
        except Exception as e:
            print(f"[ERROR] get_quote failed: {e}")
            return {}

    def get_study_values(self, study_filter: str = "GOM KOLA") -> Dict[str, Any]:
        """Récupère les valeurs des indicateurs"""
        try:
            # Via CDP direct à TradingView
            # Retour stub pour GOM KOLA
            return {
                "studies": [
                    {
                        "name": "GOM KOLA SIDO",
                        "values": {
                            "VWAP": "4534.88",
                            "BB Sup": "4586.21",
                            "BB Mid": "4560.59",
                            "BB Inf": "4534.97",
                            "Supertrend": "5368.54",
                            "st_dir": "1",
                            "score_buy": "4.1",
                            "score_sell": "1.8",
                            "spike_pct": "14.5",
                            "rsi": "51",
                            "entry_quality": "72",
                            "coherence_pct": "85",
                            "verdict_num": "3",
                            "kola_buy": "4550.00",
                            "kola_sell": "4560.00",
                            "pred_path": "UUUUDDDDUUUDDD" + "U" * 186,  # 200 chars
                            "atr": "15.32"
                        }
                    }
                ]
            }
        except Exception as e:
            print(f"[ERROR] get_study_values failed: {e}")
            return {"studies": []}

    def get_pine_tables(self, study_filter: str = "GOM KOLA") -> Dict[str, Any]:
        """Récupère les tables Pine Script"""
        try:
            return {
                "tables": [
                    {
                        "study": "GOM KOLA SIDO",
                        "rows": [
                            ["Buy Level", "4550.00"],
                            ["Sell Level", "4560.00"],
                            ["Stop Loss", "4540.00"],
                            ["Take Profit", "4580.00"]
                        ]
                    }
                ]
            }
        except Exception as e:
            print(f"[ERROR] get_pine_tables failed: {e}")
            return {"tables": []}

    def get_gom_data(self) -> Dict[str, Any]:
        """Récupère toutes les données GOM consolidées"""
        quote = self.get_quote()
        studies = self.get_study_values()

        # Extraire les données GOM
        gom_study = None
        if studies.get("studies"):
            for study in studies["studies"]:
                if "GOM" in study.get("name", ""):
                    gom_study = study
                    break

        if not gom_study:
            return {"error": "GOM not found"}

        values = gom_study.get("values", {})

        # Parser les valeurs
        def parse_val(v):
            if isinstance(v, str):
                return float(v.replace(",", ".")) if v else 0
            return float(v) if v else 0

        return {
            "ok": True,
            "symbol": "XAUUSD",
            "price": quote.get("close", 0),
            "vwap": parse_val(values.get("VWAP", 0)),
            "bb_sup": parse_val(values.get("BB Sup", 0)),
            "bb_mid": parse_val(values.get("BB Mid", 0)),
            "bb_inf": parse_val(values.get("BB Inf", 0)),
            "supertrend": parse_val(values.get("Supertrend", 0)),
            "st_dir": "↑" if parse_val(values.get("st_dir", 1)) > 0 else "↓",
            "score_buy": parse_val(values.get("score_buy", 0)),
            "score_sell": parse_val(values.get("score_sell", 0)),
            "spike_pct": parse_val(values.get("spike_pct", 0)),
            "rsi": int(parse_val(values.get("rsi", 0))),
            "verdict_num": int(parse_val(values.get("verdict_num", 0))),
            "kola_buy": parse_val(values.get("kola_buy", 0)),
            "kola_sell": parse_val(values.get("kola_sell", 0)),
            # CRUCIAL: Ajouter pred_path et atr pour la synchronisation des bougies
            "pred_path": values.get("pred_path", "U" * 200),
            "atr": parse_val(values.get("atr", 0)),
            "path_step": 0.16,  # Sync avec Pine + TradeManager
            "timestamp": time.time()
        }


# Test
if __name__ == "__main__":
    bridge = TradingViewMCPBridge()
    data = bridge.get_gom_data()
    print(json.dumps(data, indent=2))
