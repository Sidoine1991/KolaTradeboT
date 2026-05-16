#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Menu texte : symboles Deriv + MT5 exposés par ai_server.

Prérequis : serveur lancé (venv\\Scripts\\python.exe ai_server.py)

  venv\\Scripts\\python.exe symbol_catalog_menu.py
  venv\\Scripts\\python.exe symbol_catalog_menu.py http://127.0.0.1:8000

Après choix, affiche le symbole pour copier-coller vers test_tradingagents_api.py
ou le CLI TradingAgents (ticker yfinance — voir hint dans la réponse API).
"""
from __future__ import annotations

import json
import sys
import urllib.request
from typing import Any, Dict, List


def _get_json(url: str) -> Dict[str, Any]:
    req = urllib.request.Request(url, method="GET")
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read().decode("utf-8", errors="replace"))


def _pick_from_list(title: str, items: List[str], page_size: int = 40) -> str | None:
    if not items:
        print(f"\n({title}: liste vide)")
        return None
    flat = sorted(set(items))
    total = len(flat)
    offset = 0
    while True:
        chunk = flat[offset : offset + page_size]
        print(f"\n=== {title} ({total} total, lignes {offset + 1}-{offset + len(chunk)}) ===")
        for i, s in enumerate(chunk, start=1):
            print(f"  {i:3d}. {s}")
        print("  [n] page suivante  [p] page précédente  [q] quitter sans choix")
        raw = input("Numéro du symbole (ou commande): ").strip().lower()
        if raw in ("q", ""):
            return None
        if raw == "n":
            offset = min(offset + page_size, max(0, total - 1))
            continue
        if raw == "p":
            offset = max(0, offset - page_size)
            continue
        try:
            idx = int(raw)
        except ValueError:
            print("Entrée invalide.")
            continue
        if 1 <= idx <= len(chunk):
            return chunk[idx - 1]
        print("Hors plage pour cette page — utilise n/p ou un numéro affiché.")


def main() -> int:
    base = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000").rstrip("/")
    url = f"{base}/catalog/trading-symbols"
    print(f"GET {url}")
    try:
        data = _get_json(url)
    except Exception as e:
        print("Erreur:", e)
        return 1

    hint = data.get("tradingagents_yfinance_hint", "")
    if hint:
        print("\n--- Aide TradingAgents / yfinance ---\n", hint)

    mt5 = data.get("mt5") or {}
    deriv = data.get("deriv") or {}

    if mt5.get("hint"):
        print("\nMT5:", mt5.get("hint"))
    if mt5.get("error"):
        print("MT5 erreur:", mt5.get("error"))
    if deriv.get("error"):
        print("Deriv erreur:", deriv.get("error"))

    print("\nSource ?")
    print("  1 = Deriv (codes broker)")
    print("  2 = MT5 (si connecté)")
    choice = input("Choix [1/2]: ").strip()

    picked: str | None = None
    if choice == "2":
        picked = _pick_from_list("MT5", list(mt5.get("symbols") or []))
    else:
        picked = _pick_from_list("Deriv", list(deriv.get("symbols") or []))

    if picked:
        print(f"\n>>> Symbole choisi : {picked}")
        print(f"    Exemple test API : venv\\Scripts\\python.exe test_tradingagents_api.py {base} {picked}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
