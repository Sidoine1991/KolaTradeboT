#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test rapide de l'intégration TradingAgents via ai_server (TradBOT).

Prérequis venv (une fois) :
  pip install yfinance
  pip install -e "D:\\Dev\\Depot Github\\TradingAgents-main"
  Si erreur langgraph.stream : réinstaller langgraph (voir README ou discussion).

Variables LLM (exemple Google, comme le CLI TradingAgents) :
  set TRADINGAGENTS_LLM_PROVIDER=google
  set GOOGLE_API_KEY=...
  set AI_TRADINGAGENTS_USE_FLASH_FOR_ALL=1

Repli si quota Gemini (429) :
  set OPENAI_API_KEY=... & set AI_TRADINGAGENTS_FALLBACK_OPENAI=true
  set NVIDIA_NIM_API_KEY=... & set AI_TRADINGAGENTS_FALLBACK_NVIDIA_NIM=true
  (nécessite un tradingagents récent avec provider nvidia_nim — voir dépôt TradingAgents-main)

Catalogue symboles (menu local) :
  venv\\Scripts\\python.exe symbol_catalog_menu.py http://127.0.0.1:8000
  ou GET http://127.0.0.1:8000/catalog/trading-symbols et GET /deriv/active-symbols

Usage (serveur déjà lancé: venv\\Scripts\\python.exe ai_server.py) :
  venv\\Scripts\\python.exe test_tradingagents_api.py --quick
  venv\\Scripts\\python.exe test_tradingagents_api.py http://127.0.0.1:8000 SPY

Le POST /tradingagents/realtime/run-once peut prendre plusieurs minutes (yfinance + LLM).

Flux manuel (sans boucle serveur) :
  1) Lancer le CLI TradingAgents : python -m cli.main (dépôt TradingAgents-main)
  2) Pousser le rapport vers TradBOT : POST http://127.0.0.1:8000/tradingagents/manual-report
     JSON minimal : {"symbol":"XAUUSD","recommendation":"BUY","confidence":0.72,"reasoning":"..."}
     JSON avec ordre en attente (fusionné dans /decision si action technique alignée) :
       {"symbol":"XAUUSD","recommendation":"BUY","confidence":0.72,
        "execution_type":"limit","entry_price":2650.10,"stop_loss":2645.0,"take_profit":2660.0}
  3) L'EA SMC appelle POST /decision comme d'habitude — le serveur fusionne le rapport (pondération AI_TRADINGAGENTS_CLI_WEIGHT)
     et peut renvoyer entry_price + execution_type pour exécution limite/stop côté SMC_Universal_Enhanced.mq5.

La boucle auto serveur est désactivée par défaut ; pour la réactiver : AI_ENABLE_TRADINGAGENTS_AUTO_LOOP=true
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from urllib.parse import quote


def main() -> int:
    args = [a for a in sys.argv[1:] if a != ""]
    quick = "--quick" in args
    args = [a for a in args if a != "--quick"]
    base = (args[0] if len(args) > 0 else "http://127.0.0.1:8000").rstrip("/")
    symbol = args[1] if len(args) > 1 else "SPY"

    print(f"Base URL: {base}")
    print(f"Symbole test: {symbol}")

    # 1) Health
    try:
        req = urllib.request.Request(base + "/health", method="GET")
        with urllib.request.urlopen(req, timeout=15) as r:
            body = r.read().decode("utf-8", errors="replace")
        print("\n--- GET /health OK ---")
        print(body[:500])
    except Exception as e:
        print("\n--- GET /health ÉCHEC ---", e)
        return 1

    # 2) Statut cache TradingAgents (pas d'exécution LLM)
    try:
        req = urllib.request.Request(base + "/tradingagents/realtime/status", method="GET")
        with urllib.request.urlopen(req, timeout=15) as r:
            body = r.read().decode("utf-8", errors="replace")
        print("\n--- GET /tradingagents/realtime/status ---")
        print(json.dumps(json.loads(body), indent=2, ensure_ascii=False)[:3000])
    except Exception as e:
        print("\n--- GET status (optionnel) ---", e)

    if quick:
        print("\n(--quick : pas de run-once LLM — configure les clés puis relance sans --quick)")
        return 0

    # 3) Une analyse complète (long)
    q = quote(symbol, safe="")
    url = f"{base}/tradingagents/realtime/run-once?symbol={q}"
    print(f"\n--- POST {url} ---")
    print("(Patience : 2–15+ min selon profondeur / quotas LLM…)\n")
    try:
        req = urllib.request.Request(url, method="POST", data=b"", headers={})
        with urllib.request.urlopen(req, timeout=900) as r:
            raw = r.read().decode("utf-8", errors="replace")
        data = json.loads(raw)
        print("--- Résultat run-once ---")
        print(json.dumps(data, indent=2, ensure_ascii=False)[:8000])
        rec = data.get("recommendation", "?")
        conf = data.get("confidence", 0)
        dticker = data.get("data_ticker", "")
        st = data.get("status", "")
        lr = data.get("llm_route", "")
        print(f"\n>>> status={st} llm_route={lr} recommendation={rec} confidence={conf} data_ticker={dticker}")
        if st in ("quota_exceeded", "error"):
            print("\n(!) Analyse non complète : quota Gemini ou autre erreur (voir reasoning).")
            return 2
        return 0
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        print(f"HTTP {e.code}: {err[:2500]}")
        return 1
    except Exception as e:
        print(type(e).__name__, e)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
