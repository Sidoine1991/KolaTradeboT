#!/usr/bin/env python3
"""
GOM Sync + PsychoBot Report — Synchronise GOM et envoie rapport WhatsApp

Exécution: python gom_sync_with_report.py --report
"""
import json
import requests
import logging
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, Any, Optional, List
import subprocess
import sys

# Fix encoding
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

sys.path.insert(0, str(Path(__file__).parent))
from gom_pine_calculator import GOMLPineCalculator

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
log = logging.getLogger(__name__)

AI_SERVER_URL = "http://127.0.0.1:8000"
GOM_SIGNAL_FILE = Path("D:/Dev/TradBOT/data/gom_signal.json")
PSYCHOBOT_URL = "https://psychobot-1si7.onrender.com"  # À adapter si besoin

TRACKED_SYMBOLS = [
    "XAUUSD",
    "BTCUSD",
    "DERIV:BOOM_500_INDEX",
    "DERIV:CRASH_500_INDEX",
    "Boom 300 Index",
    "Boom 500 Index",
    "Boom 1000 Index",
    "Crash 300 Index",
    "Crash 500 Index",
    "Crash 1000 Index",
]

def load_local_gom_data() -> Dict[str, Dict[str, Any]]:
    """Charge les données GOM locales."""
    try:
        if not GOM_SIGNAL_FILE.exists():
            return {}
        data = json.loads(GOM_SIGNAL_FILE.read_text(encoding="utf-8"))
        return data
    except Exception as e:
        log.error(f"❌ Erreur lecture local: {e}")
        return {}

def send_gom_to_server(symbol: str, gom_data: Dict[str, Any]) -> bool:
    """Envoie verdict GOM à l'ai_server."""
    try:
        payload = {
            "symbol": symbol,
            "verdict": gom_data.get("verdict", "WAIT"),
            "verdict_num": gom_data.get("verdict_num", 0),
            # ✅ SCORES — CRITIQUES pour que ai_server ne recalcule pas
            "score_buy": gom_data.get("score_buy", 0.0),
            "score_sell": gom_data.get("score_sell", 0.0),
            "verdict_gap": gom_data.get("verdict_gap", 0.0),
            "bb_up": gom_data.get("bb_up", 0.0),
            "bb_mid": gom_data.get("bb_mid", 0.0),
            "bb_dn": gom_data.get("bb_dn", 0.0),
            "kola_buy": gom_data.get("kola_buy", 0.0),
            "kola_sell": gom_data.get("kola_sell", 0.0),
            # ✅ SETUP — noms corrects pour GomVerdictPayload
            "setup_entry": gom_data.get("entry", 0.0),
            "setup_sl": gom_data.get("sl", 0.0),
            "setup_tp1": gom_data.get("tp", 0.0),
            "timestamp": datetime.now(timezone.utc).isoformat() + "Z",
        }

        response = requests.post(
            f"{AI_SERVER_URL}/gom-verdict",
            json=payload,
            timeout=5
        )

        if response.status_code == 200:
            result = response.json()
            log.info(f"✅ {symbol:25s} | {result['verdict']:8s} | Entry: {gom_data.get('entry', 0):8.2f}")
            return True
        else:
            log.warning(f"⚠️  {symbol:25s} | HTTP {response.status_code}")
            return False
    except Exception as e:
        log.error(f"❌ {symbol:25s} | Error: {e}")
        return False

def sync_all_symbols() -> Dict[str, Dict[str, Any]]:
    """Synchro tous les symboles — USE CACHED DATA (pas de recalcul)."""
    local_data = load_local_gom_data()
    results = {}

    for symbol in TRACKED_SYMBOLS:
        if symbol in local_data:
            record = local_data[symbol]
            # ✅ ENVOYER les données TELLES QUELLES (pas de recalcul = pas de conflit)
            send_gom_to_server(symbol, record)
            results[symbol] = record
        else:
            log.warning(f"⚠️  {symbol} — Aucune donnée locale")
            results[symbol] = {"verdict": "WAIT", "verdict_num": 0}

    # ✅ PERSISTER TOUT dans gom_signal.json avec setup_* aliases
    # Cela évite que gom_poller_enriched.py écrase nos verdicts avec ses propres calculs
    try:
        # Ajouter les aliases setup_* pour compatibilité ai_server GET
        for sym, rec in local_data.items():
            rec["setup_entry"] = rec.get("setup_entry") or rec.get("entry")
            rec["setup_sl"] = rec.get("setup_sl") or rec.get("sl")
            rec["setup_tp1"] = rec.get("setup_tp1") or rec.get("tp")

        GOM_SIGNAL_FILE.write_text(json.dumps(local_data, indent=2, ensure_ascii=False))
        log.debug("📝 gom_signal.json mis à jour après recalcul complet")
    except Exception as e:
        log.warning(f"⚠️  Erreur sauvegarde gom_signal.json: {e}")

    return results

def build_gom_report(sync_results: Dict[str, Dict[str, Any]]) -> str:
    """Construit le rapport GOM pour WhatsApp."""
    lines = [
        "📊 **GOM SYNC REPORT** — " + datetime.now().strftime("%H:%M:%S"),
        "",
    ]

    for symbol, data in sync_results.items():
        verdict = data.get("verdict", "WAIT")
        entry = data.get("entry", 0)
        sl = data.get("sl", 0)
        tp = data.get("tp", 0)

        if verdict == "BUY":
            emoji = "🟢"
        elif verdict == "SELL":
            emoji = "🔴"
        else:
            emoji = "⚪"

        lines.append(f"{emoji} **{symbol}** — {verdict}")
        if entry > 0:
            lines.append(f"   Entry: {entry:.2f} | SL: {sl:.2f} | TP: {tp:.2f}")
        lines.append("")

    return "\n".join(lines)

def send_report_to_psychobot(report_text: str) -> bool:
    """Envoie le rapport via ai_server (PsychoBot integration)."""
    try:
        # Utilise l'endpoint WhatsApp du pipeline via ai_server
        payload = {
            "message": report_text,
            "to_number": "2290196911346"  # Sidoine
        }

        response = requests.post(
            f"{AI_SERVER_URL}/whatsapp/send",
            json=payload,
            timeout=10
        )

        if response.status_code in [200, 201]:
            log.info("✅ Rapport envoyé via ai_server → WhatsApp")
            return True
        else:
            log.warning(f"⚠️  ai_server WhatsApp HTTP {response.status_code}")
            # Fallback: Juste log le rapport
            log.info("📋 Rapport (non envoyé):\n" + report_text)
            return False
    except Exception as e:
        log.warning(f"⚠️  Erreur WhatsApp: {e} — rapport loggé uniquement")
        log.info("📋 Rapport:\n" + report_text)
        return False

def main():
    """Main: Synchro + Rapport."""
    import argparse

    parser = argparse.ArgumentParser(description="GOM Sync + PsychoBot Report")
    parser.add_argument("--report", action="store_true", help="Envoyer rapport WhatsApp")
    parser.add_argument("--no-sync", action="store_true", help="Sauter la synchro")
    args = parser.parse_args()

    log.info("=" * 70)
    log.info("🚀 GOM Sync + Report")
    log.info("=" * 70)

    # Synchro
    if not args.no_sync:
        log.info("📤 Synchronisation des données GOM...")
        sync_results = sync_all_symbols()
    else:
        log.info("⏭  Synchro skipped")
        sync_results = {}

    # Rapport
    if args.report:
        log.info("📊 Construction du rapport...")
        report = build_gom_report(sync_results)
        log.info("\n" + report)

        log.info("📨 Envoi via PsychoBot...")
        send_report_to_psychobot(report)
    else:
        log.info("⏭  Rapport skipped")

    log.info("=" * 70)
    log.info("✅ Terminé")

if __name__ == "__main__":
    main()
