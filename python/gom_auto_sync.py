#!/usr/bin/env python3
"""
GOM Auto Sync — Synchronise les données du Pine Script vers ai_server
Mode hybride : TradingView MCP si disponible, sinon fallback local JSON

Tâche automatisée à exécuter dans Claude Code avec accès optionnel MCP.
"""
import json
import requests
import logging
import time
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, Any, Optional, List
import sys

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
log = logging.getLogger(__name__)

AI_SERVER_URL = "http://127.0.0.1:8000"
GOM_SIGNAL_FILE = Path("D:/Dev/TradBOT/data/gom_signal.json")
POLL_INTERVAL_SECONDS = 300  # 5 minutes

# Symboles à suivre
TRACKED_SYMBOLS = [
    "XAUUSD",
    "BTCUSD",
    "DERIV:BOOM_500_INDEX",
    "DERIV:CRASH_500_INDEX",
]

# Tentative MCP disponible au démarrage
_MCP_AVAILABLE = False

def set_mcp_available(available: bool):
    """Signal si MCP TradingView est disponible."""
    global _MCP_AVAILABLE
    _MCP_AVAILABLE = available
    status = "✅ ACTIF" if available else "⏸  INACTIF (mode local)"
    log.info(f"MCP TradingView: {status}")

def load_local_gom_data() -> Dict[str, Dict[str, Any]]:
    """Charge les données locales depuis gom_signal.json."""
    try:
        if not GOM_SIGNAL_FILE.exists():
            log.warning(f"⚠️  {GOM_SIGNAL_FILE} not found")
            return {}

        data = json.loads(GOM_SIGNAL_FILE.read_text(encoding="utf-8"))
        log.info(f"✅ Données locales chargées: {len(data)} symboles")
        return data
    except Exception as e:
        log.error(f"❌ Erreur lecture local: {e}")
        return {}

def extract_gom_from_mcp(symbol: str) -> Optional[Dict[str, Any]]:
    """
    Extrait les données du Pine Script via Claude MCP TradingView.
    À appeler depuis Claude Code uniquement.
    """
    if not _MCP_AVAILABLE:
        return None

    try:
        # Ceci est appelé depuis Claude Code — MCP est disponible dans ce contexte
        # Pour l'instant, retourne None — Claude Code remplacera cet appel
        log.debug(f"🔍 MCP extract pour {symbol} (placeholder)")
        return None
    except Exception as e:
        log.warning(f"⚠️  MCP extract failed for {symbol}: {e}")
        return None

def send_gom_to_server(symbol: str, gom_data: Dict[str, Any]) -> bool:
    """Envoie les données GOM à l'ai_server /gom-verdict endpoint."""
    try:
        payload = {
            "symbol": symbol,
            "verdict": gom_data.get("verdict", "WAIT"),
            "verdict_num": gom_data.get("verdict_num", 0),
            "bb_up": gom_data.get("bb_up", 0.0),
            "bb_mid": gom_data.get("bb_mid", 0.0),
            "bb_dn": gom_data.get("bb_dn", 0.0),
            "kola_buy": gom_data.get("kola_buy", 0.0),
            "kola_sell": gom_data.get("kola_sell", 0.0),
            "entry_price": gom_data.get("entry", 0.0),
            "sl_price": gom_data.get("sl", 0.0),
            "tp_price": gom_data.get("tp", 0.0),
            "timestamp": datetime.now(timezone.utc).isoformat() + "Z",
        }

        response = requests.post(
            f"{AI_SERVER_URL}/gom-verdict",
            json=payload,
            timeout=5
        )

        if response.status_code == 200:
            result = response.json()
            log.info(f"✅ {symbol:25s} | Verdict: {result['verdict']:6s} | Entry: {gom_data.get('entry', 0):.2f}")
            return True
        else:
            log.warning(f"⚠️  {symbol:25s} | HTTP {response.status_code}")
            return False
    except Exception as e:
        log.error(f"❌ {symbol:25s} | Error: {e}")
        return False

def sync_cycle_hybrid() -> Dict[str, bool]:
    """
    Un cycle de sync complet — mode hybride.
    1. Essaie MCP TradingView si disponible
    2. Sinon, utilise les données locales gom_signal.json
    """
    results = {}

    for symbol in TRACKED_SYMBOLS:
        # Essai MCP d'abord
        mcp_data = extract_gom_from_mcp(symbol)

        if mcp_data:
            # MCP a réussi
            log.info(f"🌉 {symbol:25s} | Source: TradingView MCP")
            results[symbol] = send_gom_to_server(symbol, mcp_data)
        else:
            # Fallback local
            local_data = load_local_gom_data()
            if symbol in local_data:
                log.info(f"📄 {symbol:25s} | Source: Local JSON")
                results[symbol] = send_gom_to_server(symbol, local_data[symbol])
            else:
                log.warning(f"⚠️  {symbol:25s} | Aucune donnée (MCP + local)")
                results[symbol] = False

    return results

def main_sync_loop(interval_seconds: int = POLL_INTERVAL_SECONDS):
    """Boucle principale — tourne indéfiniment."""
    log.info("=" * 70)
    log.info("🚀 GOM Auto Sync — Démarré")
    log.info(f"   Interval: {interval_seconds}s")
    log.info(f"   Symboles: {', '.join(TRACKED_SYMBOLS)}")
    log.info("=" * 70)

    cycle = 0
    while True:
        cycle += 1
        try:
            log.info(f"\n┌─ Cycle #{cycle} {datetime.now().strftime('%H:%M:%S')} ─")

            results = sync_cycle_hybrid()

            ok_count = sum(1 for v in results.values() if v)
            log.info(f"└─ Résultat: {ok_count}/{len(TRACKED_SYMBOLS)} ✅")

            log.info(f"⏳ Prochain cycle dans {interval_seconds}s...")
            time.sleep(interval_seconds)

        except KeyboardInterrupt:
            log.info("\n⏹  Arrêt utilisateur")
            break
        except Exception as e:
            log.error(f"❌ Erreur cycle: {e}")
            time.sleep(interval_seconds)

def main():
    """Entrée principale."""
    import argparse

    parser = argparse.ArgumentParser(description="GOM Auto Sync — Synchronisation hybride")
    parser.add_argument("--interval", type=int, default=POLL_INTERVAL_SECONDS,
                       help=f"Interval entre cycles (default {POLL_INTERVAL_SECONDS}s)")
    parser.add_argument("--once", action="store_true", help="Un seul cycle puis exit")
    parser.add_argument("--mcp", action="store_true", help="Signale que MCP TradingView est disponible")
    args = parser.parse_args()

    set_mcp_available(args.mcp)

    if args.once:
        log.info("Mode ONE-SHOT")
        results = sync_cycle_hybrid()
        ok = sum(1 for v in results.values() if v)
        log.info(f"Résultat: {ok}/{len(TRACKED_SYMBOLS)} ✅")
        sys.exit(0 if ok > 0 else 1)
    else:
        main_sync_loop(args.interval)

if __name__ == "__main__":
    main()
