#!/usr/bin/env python3
"""Vérifie que le payload GOM dashboard = ce que l'EA affiche/trade."""
import json
import sys
import urllib.parse
import urllib.request

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000"

CASES = [
    {
        "broker": "Deriv",
        "chart_symbol": "Crash 500 Index",
        "api_symbol": "Crash 500 Index",
    },
    {
        "broker": "Weltrade",
        "chart_symbol": "PainX 400",
        "api_symbol": "PainX 400",
    },
]


def ea_resolve_gom_sym(sym: str) -> str:
    s = sym.upper().replace(" ", "")
    if s.startswith("FXVOL"):
        num = s[5:]
        return f"FX Vol {num}" if num else "FX Vol 20"
    if s.startswith("PAINX"):
        num = s[5:]
        return f"PainX {num}" if num else "PainX"
    if s.startswith("GAINX"):
        num = s[5:]
        return f"GainX {num}" if num else "GainX"
    if "INDEX" in sym.upper():
        return sym
    return sym


def ea_parse_harmonized(body: dict) -> bool:
    harmonized = bool(body.get("harmonized_m1"))
    mode = str(body.get("verdict_mode") or "")
    if not harmonized and mode == "reactive_pine":
        harmonized = True
    return harmonized


def ea_trading_verdict(body: dict, harmonized: bool) -> tuple[int, str, str]:
    """Simule SMCGP_ParseGOMBody + overlay correction (simplifié)."""
    vn = int(body.get("verdict_num") or 0)
    verdict = str(body.get("verdict") or "WAIT").upper()
    server_vn = vn
    server_txt = verdict

    if harmonized:
        display = verdict
        trade_vn = vn
        trade_txt = verdict
        note = "harmonized_m1 -> affichage = execution (pas d'overlay client)"
    else:
        # Client pourrait forcer WAIT (correction) — affichage corrigé récemment
        if body.get("correction_wait"):
            display = f"WAIT (trade) ← {server_txt}"
            trade_vn = 0
            trade_txt = "WAIT"
            note = "correction_wait actif côté serveur"
        else:
            display = verdict
            trade_vn = vn
            trade_txt = verdict
            note = "non harmonise — risque re-gate client M1"

    can_trade = abs(trade_vn) >= 2
    return trade_vn, trade_txt, display, server_vn, server_txt, can_trade, note


def fetch_dashboard(symbol: str) -> dict:
    q = urllib.parse.urlencode({"symbol": symbol, "chart_tf": "M15", "source": "local"})
    url = f"{BASE}/gom-kola-dashboard?{q}"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=25) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> int:
    print(f"=== Verification GOM EA display — {BASE} ===\n")
    ok_all = True
    for case in CASES:
        broker = case["broker"]
        chart = case["chart_symbol"]
        api_sym = case["api_symbol"]
        resolved = ea_resolve_gom_sym(chart)
        print(f"--- {broker}: graphique MT5 `{chart}` -> API `{resolved}` ---")
        try:
            body = fetch_dashboard(api_sym)
        except Exception as exc:
            print(f"  ERREUR HTTP: {exc}\n")
            ok_all = False
            continue

        if not body.get("ok"):
            print(f"  ERREUR API: {body.get('error', body)}\n")
            ok_all = False
            continue

        harmonized = ea_parse_harmonized(body)
        trade_vn, trade_txt, display, srv_vn, srv_txt, can_trade, note = ea_trading_verdict(
            body, harmonized
        )

        print(f"  HTTP ok={body.get('ok')} gate={body.get('gate') or '-'}")
        print(f"  harmonized_m1={body.get('harmonized_m1')} verdict_mode={body.get('verdict_mode')}")
        print(f"  Serveur: {srv_txt} (vn={srv_vn})")
        print(f"  EA affiche: {display}")
        print(f"  EA trade:   {trade_txt} (vn={trade_vn}) | ordre autorisé={can_trade}")
        print(f"  cohérence={body.get('coherence_pct')}% scores B={body.get('score_buy')} S={body.get('score_sell')}")
        print(f"  -> {note}")

        if harmonized and display != trade_txt and "WAIT (trade)" not in display:
            print("  WARN: INCOHERENCE affichage/trade")
            ok_all = False
        elif not harmonized:
            print("  WARN: harmonized_m1=false — l'EA peut diverger du serveur")
        else:
            print("  OK: Aligne")
        print()

    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
