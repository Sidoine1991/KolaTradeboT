#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test orchestration : POST /tradingagents/manual-report puis POST /decision (même symbole).

Usage (serveur déjà lancé) :
  venv\\Scripts\\python.exe test_orchestration_manual_report.py
  venv\\Scripts\\python.exe test_orchestration_manual_report.py http://127.0.0.1:8000
"""
from __future__ import annotations

import json
import sys
import urllib.request


def _safe_print(s: str) -> None:
    """Évite le mélange buffer/texte sous Windows (ordre des lignes incohérent)."""
    print(s, flush=True)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass

    base = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000").rstrip("/")

    def get(path: str) -> dict:
        req = urllib.request.Request(base + path, method="GET")
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode("utf-8", errors="replace"))

    def post(path: str, payload: dict, timeout: int = 120) -> dict:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            base + path,
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8", errors="replace"))

    _safe_print("=== 1) GET /health ===")
    try:
        h = get("/health")
        _safe_print(json.dumps(h, indent=2, ensure_ascii=False)[:1200])
    except Exception as e:
        _safe_print("ÉCHEC: " + repr(e))
        return 1

    _safe_print("\n=== 2) GET /tradingagents/realtime/status ===")
    try:
        st = get("/tradingagents/realtime/status")
        _safe_print(json.dumps(st, indent=2, ensure_ascii=False))
    except Exception as e:
        _safe_print("ÉCHEC: " + repr(e))
        return 1

    symbol = "Boom 600 Index"
    _safe_print(f"\n=== 3) POST /tradingagents/manual-report ({symbol}) ===")
    try:
        mr = post(
            "/tradingagents/manual-report",
            {
                "symbol": symbol,
                "recommendation": "BUY",
                "confidence": 0.88,
                "reasoning": "Test orchestration script (pas le vrai CLI).",
            },
            timeout=30,
        )
        _safe_print(json.dumps(mr, indent=2, ensure_ascii=False))
    except Exception as e:
        _safe_print("ÉCHEC: " + repr(e))
        return 1

    st2 = get("/tradingagents/realtime/status")
    _safe_print("\n=== 4) Status après manual-report (manual_reports_cached) ===")
    _safe_print("manual_reports_cached: " + str(st2.get("manual_reports_cached")))

    dec_body = {
        "symbol": symbol,
        "bid": 6035.877,
        "ask": 6036.396,
        "rsi": 45.0,
        "ema_fast_m1": 6038.0,
        "ema_slow_m1": 6030.0,
        "ema_fast_m5": 6035.0,
        "ema_slow_m5": 6032.0,
        "ema_fast_h1": 6020.0,
        "ema_slow_h1": 6040.0,
        "atr": 3.5,
    }

    _safe_print(
        f"\n=== 5) POST /decision ({symbol}) — vérifier reason contient [CLI TradingAgents ==="
    )
    try:
        d = post("/decision", dec_body, timeout=120)
    except Exception as e:
        _safe_print("ÉCHEC: " + repr(e))
        return 1

    reason = str(d.get("reason") or "")
    action = str(d.get("action") or "")
    conf = d.get("confidence")
    ok_cli = "[CLI TradingAgents" in reason
    _safe_print("action: " + action + " | confidence: " + str(conf))
    _safe_print("reason (500 premiers car.):\n" + reason[:500])
    _safe_print("\n--- Bilan orchestration ---")
    _safe_print("manual-report OK: " + str(mr.get("ok") is True))
    _safe_print("/decision OK: " + str(action in ("buy", "sell", "hold")))
    _safe_print(
        "Fusion CLI visible dans reason: "
        + ("OUI" if ok_cli else "NON (vérifier symbole exact ou TTL)")
    )

    return 0 if (mr.get("ok") and ok_cli) else 2


if __name__ == "__main__":
    raise SystemExit(main())
