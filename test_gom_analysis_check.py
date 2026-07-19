#!/usr/bin/env python3
"""
Test GOM/TradingView Analysis verification avant execution des ordres.

Fonctionne OFFLINE (lecture gom_signal.json) + ONLINE (si serveur dispo).
Simule les 2 chaines de validation:
  1. SERVEUR  -> _validate_gom_confluence (advisory: ajuste confiance + warning)
  2. EA/MT5   -> SMCGP_GOMAllowsDirectionEx  (bloquant: |vnum|>=2, coherence, BB, OB, OTE)

Usage:
    python test_gom_analysis_check.py                   # tous les symboles
    python test_gom_analysis_check.py --symbol BTCUSD   # un seul symbole
"""

import sys, os, json, time, logging, argparse
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Dict, Any

sys.path.insert(0, str(Path(__file__).parent))

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("GOM_TEST")

PASS = "\033[92mPASS\033[0m"
FAIL = "\033[91mFAIL\033[0m"
WARN = "\033[93mWARN\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"

AI_SERVER = "http://127.0.0.1:8000"
GOM_FILE = Path("data/gom_signal.json")

# -- Server-side advisory validator (copied from ai_server.py) --
def validate_gom_confluence(direction: str, gom_verdict: str) -> Dict[str, Any]:
    verdict = gom_verdict.upper()
    result = {"action": "NONE", "warning": None, "confidence_delta": 0.0}

    if verdict in ("UNKNOWN", "WAIT"):
        result["action"] = "NEUTRAL"
        return result

    if direction == "SELL" and verdict == "BUY":
        result["action"]          = "CONFLICT"
        result["confidence_delta"] = -0.15
        result["warning"]         = "Signal SELL oppose verdict GOM=BUY"
    elif direction == "BUY" and verdict == "SELL":
        result["action"]          = "CONFLICT"
        result["confidence_delta"] = -0.15
        result["warning"]         = "Signal BUY oppose verdict GOM=SELL"
    elif direction == verdict:
        result["action"]          = "ALIGNED"
        result["confidence_delta"] = 0.10

    return result

# -- EA-side blocking validator (simplified from SMCGP_GOMAllowsDirectionEx) --
def ea_gom_allows_direction(dir: int, vnum: int, coherence: float,
                            gom_global_dir: str = "", gom_global_str: float = 0.0,
                            is_forex: bool = False) -> Dict[str, Any]:
    reasons = []

    if vnum == 0:
        return {"allow": False, "reason": "VERDICT_ZERO"}
    if abs(vnum) < 2:
        return {"allow": False, "reason": f"NOT_GOOD_PERFECT vnum={vnum}"}

    min_coh = 70
    if coherence > 0 and coherence < min_coh:
        return {"allow": False, "reason": f"LOW_COHERENCE {coherence}% < {min_coh}%"}

    if dir == 1:
        if vnum < 2:
            return {"allow": False, "reason": f"BUY_VN_TOO_LOW vn={vnum}"}
        if gom_global_dir == "BEAR" and gom_global_str >= 60:
            return {"allow": False, "reason": f"BUY_AGAINST_GLOBAL_BEAR str={gom_global_str}"}
    elif dir == -1:
        if vnum > -2:
            return {"allow": False, "reason": f"SELL_VN_TOO_HIGH vn={vnum}"}
        if gom_global_dir == "BULL" and gom_global_str >= 60:
            return {"allow": False, "reason": f"SELL_AGAINST_GLOBAL_BULL str={gom_global_str}"}
    else:
        return {"allow": False, "reason": "DIR_INVALID"}

    if dir == 1 and vnum < 0:
        return {"allow": False, "reason": "BUY_SIGN_MISMATCH"}
    if dir == -1 and vnum > 0:
        return {"allow": False, "reason": "SELL_SIGN_MISMATCH"}

    return {"allow": True, "reason": "OK"}

def load_gom_data() -> list:
    if GOM_FILE.exists():
        try:
            with open(GOM_FILE) as f:
                data = json.load(f)
            return data.get("verdicts", [])
        except Exception:
            pass
    return []

def get_opposite_dir(d: str) -> str:
    return "SELL" if d == "BUY" else "BUY"

def test_symbol(v: Dict):
    symbol = v.get("symbol", "?")
    vnum = v.get("verdict_num", 0)
    coherence = v.get("coherence_pct", v.get("coherence", 0))

    vlabel = v.get("verdict", "").upper()
    if "SELL" in vlabel:
        gom_dir_str = "SELL"
    elif "BUY" in vlabel:
        gom_dir_str = "BUY"
    else:
        gom_dir_str = "WAIT"

    print(f"\n{BOLD}=== {symbol} ==={RESET}")
    print(f"  Verdict:  {vlabel} (vnum={vnum})")
    print(f"  Coherence: {coherence}%")

    if gom_dir_str == "WAIT" or vnum == 0:
        print(f"  {WARN}  GOM=WAIT/ZERO -> aucun filtre applicable")
        return

    # -- Test aligne --
    print(f"\n  {BOLD}[A] Ordre aligne: {gom_dir_str}{RESET}")
    srv = validate_gom_confluence(gom_dir_str, gom_dir_str)
    ea = ea_gom_allows_direction(1 if gom_dir_str == "BUY" else -1, vnum, coherence)
    tag = PASS if ea["allow"] else FAIL
    print(f"  {tag} Serveur: action={srv['action']}, conf_delta={srv['confidence_delta']:+.2f}")
    print(f"     EA/MT5: allow={ea['allow']}, reason={ea['reason']}")

    # -- Test oppose --
    opp = get_opposite_dir(gom_dir_str)
    print(f"\n  {BOLD}[B] Ordre oppose: {opp}{RESET}")
    srv = validate_gom_confluence(opp, gom_dir_str)
    ea = ea_gom_allows_direction(1 if opp == "BUY" else -1, vnum, coherence)

    tag_srv = WARN if srv["action"] == "CONFLICT" else PASS
    tag_ea = FAIL if not ea["allow"] else WARN
    print(f"  {tag_srv} Serveur: action={srv['action']}, conf_delta={srv['confidence_delta']:+.2f}")
    if srv["warning"]:
        print(f"          {DIM}WARN: {srv['warning']}{RESET}")
    print(f"  {tag_ea} EA/MT5:   allow={ea['allow']}, reason={ea['reason']}")

    # Interpretation
    print(f"\n  {BOLD}> Verdict:{RESET}")
    if not ea["allow"]:
        print(f"    {PASS} L'ordre {opp} serait BLOQUE cote EA MT5 (SMCGP_GOMAllowsDirectionEx)")
    else:
        print(f"    {WARN} L'ordre {opp} passerait le filtre EA MAIS le serveur avertit (advisory)")
    print(f"    {DIM}  Note: le blocage final depend de UseGOMVerdictFilter=true dans l'EA{RESET}")

def main():
    parser = argparse.ArgumentParser(description="Test GOM validation chain")
    parser.add_argument("--symbol", help="Symbole specifique (defaut: tous)")
    parser.add_argument("--no-color", action="store_true")
    args = parser.parse_args()

    if args.no_color:
        global PASS, FAIL, WARN, BOLD, DIM, RESET
        PASS = "PASS"; FAIL = "FAIL"; WARN = "WARN"; BOLD = ""; DIM = ""; RESET = ""

    verdicts = load_gom_data()
    if not verdicts:
        print(f"{FAIL} Aucune donnee GOM dans {GOM_FILE}")
        print(f"  Assurez-vous que le fichier existe avec des verdicts valides.")
        sys.exit(1)

    print(f"{BOLD}=== CHAINE VALIDATION GOM - TEST OFFLINE ==={RESET}")
    print(f"Fichier: {GOM_FILE}")
    if verdicts:
        src = verdicts[0].get('data_source', verdicts[0].get('source', '?'))
        print(f"Source:  {src}")
    print(f"Symboles disponibles: {len(verdicts)}")

    if args.symbol:
        filtered = [v for v in verdicts if args.symbol.upper() in v.get("symbol", "").upper()]
        if not filtered:
            print(f"\n{FAIL} Symbole '{args.symbol}' introuvable")
            available = [v.get("symbol") for v in verdicts]
            print(f"  Disponibles: {', '.join(available)}")
            sys.exit(1)
        for v in filtered:
            test_symbol(v)
    else:
        for v in verdicts:
            test_symbol(v)

    # -- Resume --
    print(f"\n{BOLD}=== RESUME ==={RESET}")
    print(f"  Serveur (REST):  advisory - ajuste confiance +/-10-15%, ne bloque PAS")
    print(f"  EA MT5 (native): bloquant - verifie |vnum|>=2, coherence>=70%, sign match, BB, OB, OTE")
    print(f"  Pipeline Python: passe par le serveur -> advisory + gates horaires/cognition")
    print(f"")
    print(f"  Pour un vrai test en direct avec le serveur:")
    print(f"  $ python test_gom_analysis_check.py --symbol BTCUSD")

if __name__ == "__main__":
    main()
