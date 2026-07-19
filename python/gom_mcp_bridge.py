#!/usr/bin/env python3
"""
GOM MCP Bridge — Extrait données du Pine Script via Claude MCP TradingView
et les envoie à ai_server /gom-verdict endpoint.

Exécuté dans Claude Code avec MCP TradingView actif.
"""
import json
import requests
import logging
from datetime import datetime
from typing import Dict, Any, Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger(__name__)

AI_SERVER_URL = "http://127.0.0.1:8000"
DEFAULT_SYMBOLS = ["XAUUSD", "BTCUSD", "DERIV:BOOM_500_INDEX", "DERIV:CRASH_500_INDEX"]

def extract_gom_verdict_from_labels(labels: list) -> Optional[str]:
    """Extrait le verdict BUY/SELL/WAIT des labels Pine Script."""
    for label in labels:
        text = label.get("text", "").upper()
        if "BUY" in text and "SELL" not in text:
            return "BUY"
        if "SELL" in text and "BUY" not in text:
            return "SELL"
        if "WAIT" in text:
            return "WAIT"
    return None

def parse_pine_data(labels: list, lines: list, tables: list) -> Dict[str, Any]:
    """Parse les données extraites du Pine Script."""
    result = {
        "verdict": "WAIT",
        "verdict_num": 0,
        "bb_up": 0.0,
        "bb_mid": 0.0,
        "bb_dn": 0.0,
        "kola_buy": 0.0,
        "kola_sell": 0.0,
        "entry": 0.0,
        "sl": 0.0,
        "tp": 0.0,
    }

    # Extraire du verdict des labels
    verdict = extract_gom_verdict_from_labels(labels)
    if verdict:
        result["verdict"] = verdict
        result["verdict_num"] = 1 if verdict == "BUY" else (-1 if verdict == "SELL" else 0)

    # Extraire les niveaux KOLA, Entry, SL, TP des labels
    for label in labels:
        text = label.get("text", "")
        price = label.get("price", 0.0)

        if "BUY" in text and "KOLA" not in text:
            result["kola_buy"] = price
        elif "SELL" in text and "KOLA" not in text:
            result["kola_sell"] = price
        elif "ENTRY" in text.upper() or "E:" in text:
            result["entry"] = price
        elif "SL" in text.upper():
            result["sl"] = price
        elif "TP" in text.upper():
            result["tp"] = price
        elif "0%" in text:
            result["bb_dn"] = price
        elif "100%" in text:
            result["bb_up"] = price
        elif "50%" in text or "MID" in text.upper():
            result["bb_mid"] = price

    # Si pas de BB, utiliser les lignes horizontales
    if result["bb_up"] == 0 and lines:
        sorted_lines = sorted(lines, reverse=True)
        if len(sorted_lines) >= 3:
            result["bb_up"] = sorted_lines[0]
            result["bb_dn"] = sorted_lines[-1]
            result["bb_mid"] = (sorted_lines[0] + sorted_lines[-1]) / 2

    return result

def send_gom_to_server(symbol: str, gom_data: Dict[str, Any]) -> bool:
    """Envoie les données GOM à l'ai_server /gom-verdict endpoint."""
    try:
        payload = {
            "symbol": symbol,
            "verdict": gom_data["verdict"],
            "verdict_num": gom_data["verdict_num"],
            "bb_up": gom_data["bb_up"],
            "bb_mid": gom_data["bb_mid"],
            "bb_dn": gom_data["bb_dn"],
            "kola_buy": gom_data["kola_buy"],
            "kola_sell": gom_data["kola_sell"],
            "entry_price": gom_data["entry"],
            "sl_price": gom_data["sl"],
            "tp_price": gom_data["tp"],
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }

        response = requests.post(
            f"{AI_SERVER_URL}/gom-verdict",
            json=payload,
            timeout=5
        )

        if response.status_code == 200:
            result = response.json()
            log.info(f"✅ {symbol:20s} → Verdict: {result['verdict']:6s} | Entry: {gom_data['entry']:.2f}")
            return True
        else:
            log.error(f"❌ {symbol:20s} → HTTP {response.status_code}: {response.text}")
            return False
    except Exception as e:
        log.error(f"❌ {symbol:20s} → Error: {e}")
        return False

def main():
    """
    À exécuter dans Claude Code avec:
    1. MCP TradingView actif
    2. chart_set_symbol() pour chaque symbole
    3. data_get_pine_lines/labels/tables() pour extraire les données
    4. Puis appeler send_gom_to_server() avec les données parsées

    Ceci est le template. La boucle réelle s'exécute dans Claude.
    """
    log.info("=" * 60)
    log.info("🌉 GOM MCP Bridge — Prêt à recevoir les données")
    log.info("   Cet endpoint attend les données extraites du Pine Script")
    log.info("=" * 60)

    # Exemple de test
    test_data = {
        "symbol": "XAUUSD",
        "verdict": "BUY",
        "verdict_num": 1,
        "bb_up": 6038.78,
        "bb_mid": 6032.41,
        "bb_dn": 6025.81,
        "kola_buy": 6031.7,
        "kola_sell": 6035.15,
        "entry": 6031.7,
        "sl": 6025.81,
        "tp": 6038.78,
    }

    send_gom_to_server("XAUUSD", test_data)

if __name__ == "__main__":
    main()
