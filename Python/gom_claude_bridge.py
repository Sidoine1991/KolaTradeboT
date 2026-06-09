#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Claude Bridge — Remplace CLI tv cassé
==========================================
Bridge qui permet à master_gom_poller.py d'utiliser TradingView MCP via Claude.

Principe :
    Au lieu d'appeler CLI 'tv chart set-symbol', ce script écrit une requête
    dans un fichier que Claude surveille, exécute l'action MCP, et écrit le résultat.

Architecture :
    Python → writes request.json
         → Claude poll request.json
         → Claude execute MCP action
         → Claude writes response.json
         → Python reads response.json

Usage depuis master_gom_poller.py :
    from gom_claude_bridge import set_symbol_via_claude, get_study_values_via_claude

    set_symbol_via_claude("DERIV:BOOM_500_INDEX")
    time.sleep(3)
    data = get_study_values_via_claude()
"""
import json
import time
from pathlib import Path
from typing import Optional, Dict

_BRIDGE_DIR = Path(__file__).parent.parent / "data" / "claude_bridge"
_BRIDGE_DIR.mkdir(parents=True, exist_ok=True)

_REQUEST_FILE = _BRIDGE_DIR / "mcp_request.json"
_RESPONSE_FILE = _BRIDGE_DIR / "mcp_response.json"
_TIMEOUT = 15  # secondes max pour attendre réponse Claude


def _write_request(action: str, params: Dict) -> bool:
    """Écrit une requête MCP pour Claude."""
    request = {
        "action": action,
        "params": params,
        "timestamp": time.time(),
    }
    try:
        _REQUEST_FILE.write_text(json.dumps(request, indent=2), encoding="utf-8")
        return True
    except Exception as e:
        print(f"[Bridge] ❌ Erreur écriture requête: {e}")
        return False


def _wait_for_response(timeout: float = _TIMEOUT) -> Optional[Dict]:
    """Attend que Claude écrive une réponse."""
    start = time.time()

    # Effacer réponse précédente
    if _RESPONSE_FILE.exists():
        try:
            _RESPONSE_FILE.unlink()
        except Exception:
            pass

    # Attendre nouvelle réponse
    while time.time() - start < timeout:
        if _RESPONSE_FILE.exists():
            try:
                data = json.loads(_RESPONSE_FILE.read_text(encoding="utf-8"))
                # Vérifier timestamp (max 30s)
                age = time.time() - data.get("timestamp", 0)
                if age < 30:
                    return data
            except Exception as e:
                print(f"[Bridge] ⚠️  Erreur lecture réponse: {e}")

        time.sleep(0.5)

    print(f"[Bridge] ⏱  Timeout après {timeout}s — Claude n'a pas répondu")
    return None


def set_symbol_via_claude(ticker: str) -> bool:
    """Change symbole TradingView via Claude MCP."""
    print(f"[Bridge] 📤 Requête Claude: chart_set_symbol({ticker})")

    if not _write_request("chart_set_symbol", {"symbol": ticker}):
        return False

    response = _wait_for_response()
    if not response:
        return False

    if response.get("success"):
        print(f"[Bridge] ✅ Symbole changé: {ticker}")
        return True

    error = response.get("error", "Unknown error")
    print(f"[Bridge] ❌ Erreur: {error}")
    return False


def get_study_values_via_claude() -> Optional[Dict]:
    """Récupère study values via Claude MCP."""
    print(f"[Bridge] 📤 Requête Claude: data_get_study_values()")

    if not _write_request("data_get_study_values", {}):
        return None

    response = _wait_for_response()
    if not response:
        return None

    if response.get("success"):
        data = response.get("data", {})
        print(f"[Bridge] ✅ Study values reçus: {len(data.get('studies', []))} études")
        return data

    error = response.get("error", "Unknown error")
    print(f"[Bridge] ❌ Erreur: {error}")
    return None


def check_bridge_active() -> bool:
    """Vérifie si Claude surveille le bridge."""
    status_file = _BRIDGE_DIR / "bridge_active.json"

    if not status_file.exists():
        return False

    try:
        data = json.loads(status_file.read_text(encoding="utf-8"))
        age = time.time() - data.get("timestamp", 0)
        return age < 60  # Actif si heartbeat < 60s
    except Exception:
        return False


if __name__ == "__main__":
    import sys
    import io

    # Fix Windows encoding
    if sys.platform == "win32":
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

    print("=" * 60)
    print("GOM Claude Bridge — Test")
    print("=" * 60)

    if not check_bridge_active():
        print("")
        print("❌ Claude bridge pas actif")
        print("")
        print("Pour activer:")
        print("  1. Lance Claude Code dans D:/Dev/TradBOT")
        print("  2. Demande: 'Active le GOM bridge MCP'")
        print("  3. Claude va surveiller data/claude_bridge/mcp_request.json")
        print("  4. Re-lance ce script pour tester")
        print("")
    else:
        print("✅ Claude bridge actif")
        print("")
        print("Test 1: Change symbole BTCUSD")
        if set_symbol_via_claude("BITSTAMP:BTCUSD"):
            print("✅ Test 1 OK")

            print("")
            print("Test 2: Récupère study values (après 3s)")
            time.sleep(3)

            data = get_study_values_via_claude()
            if data:
                print("✅ Test 2 OK")
                studies = data.get("studies", [])
                if studies:
                    print(f"   Études trouvées: {[s.get('name') for s in studies]}")
            else:
                print("❌ Test 2 échec")
        else:
            print("❌ Test 1 échec")
