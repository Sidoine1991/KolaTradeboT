#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Subprocess worker: appelle run_quick() de tradbot_bridge et écrit le résultat JSON sur stdout.
Usage: python ta_worker.py SYMBOL DATE_ISO [VENDOR]
"""
import sys
import os
import json
import time
import io
import contextlib
from pathlib import Path

# Redirige stdout de tradbot_bridge vers stderr pour garder stdout propre
_orig_stdout = sys.stdout

def _redirect_prints():
    sys.stdout = sys.stderr

def _restore_stdout():
    sys.stdout = _orig_stdout

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent
sys.path.insert(0, str(_HERE))

# Charger .env pour avoir NVIDIA_NIM_API_KEY et autres variables
_env_file = _ROOT / ".env"
if _env_file.exists():
    for _line in _env_file.read_text(encoding="utf-8").splitlines():
        if "=" in _line and not _line.startswith("#"):
            _k, _, _v = _line.partition("=")
            os.environ.setdefault(_k.strip(), _v.strip())

def _normalize_rating(rating: str) -> str:
    r = (rating or "").upper().strip()
    if r in ("BUY", "OVERWEIGHT", "STRONG BUY", "STRONGBUY"):
        return "BUY"
    if r in ("SELL", "UNDERWEIGHT", "STRONG SELL", "STRONGSELL"):
        return "SELL"
    return "HOLD"


def _extract_scalping_levels(expert_analysis: str) -> dict:
    """Extrait entry/SL/TP du texte d'analyse Claude scalping."""
    import re
    result = {"entry_price": None, "stop_loss": None, "take_profit": None}
    patterns = {
        "entry_price": r"(?:entry|entr[ée]e?)[^\d]*([0-9]+(?:[.,][0-9]+)?)",
        "stop_loss":   r"(?:sl|stop[- ]?loss|stop)[^\d]*([0-9]+(?:[.,][0-9]+)?)",
        "take_profit": r"(?:tp|take[- ]?profit|cible)[^\d]*([0-9]+(?:[.,][0-9]+)?)",
    }
    for key, pat in patterns.items():
        m = re.search(pat, expert_analysis, re.IGNORECASE)
        if m:
            try:
                result[key] = float(m.group(1).replace(",", "."))
            except ValueError:
                pass
    return result


def main():
    if len(sys.argv) < 3:
        out = {"success": False, "error": "Usage: ta_worker.py SYMBOL DATE [VENDOR]"}
        _orig_stdout.write(json.dumps(out))
        sys.exit(1)

    symbol   = sys.argv[1]
    date_str = sys.argv[2]
    vendor   = sys.argv[3] if len(sys.argv) > 3 else None

    start = time.time()

    _redirect_prints()
    try:
        from tradbot_bridge import run_quick  # noqa: PLC0415
        try:
            result = run_quick(symbol, date_str, vendor=vendor)
        except SystemExit as se:
            raise RuntimeError(f"run_quick sys.exit: {se}") from se

        signal_rating    = result.get("signal_rating", "HOLD")
        normalized       = _normalize_rating(signal_rating)
        expert_analysis  = result.get("expert_analysis", "")
        final_state      = result.get("final_state") or {}
        indicators       = result.get("indicators") or {}

        # Extraire niveaux scalping depuis expert_analysis
        scalping = _extract_scalping_levels(expert_analysis)

        # Essayer aussi d'extraire depuis compute_signals via indicators
        entry  = scalping.get("entry_price") or indicators.get("current_price")
        sl     = scalping.get("stop_loss")
        tp     = scalping.get("take_profit")

        # Calcul SL/TP ATR si manquants
        atr = indicators.get("atr")
        if entry and atr and not sl:
            atr_f = float(atr)
            sl = round(float(entry) - atr_f * 1.5, 5) if normalized == "BUY" else round(float(entry) + atr_f * 1.5, 5)
        if entry and sl and not tp:
            sl_dist = abs(float(entry) - float(sl))
            tp = round(float(entry) + sl_dist * 2.0, 5) if normalized == "BUY" else round(float(entry) - sl_dist * 2.0, 5)

        output = {
            "success":             True,
            "symbol":              symbol,
            "signal_rating":       signal_rating,
            "normalized_rating":   normalized,
            "expert_analysis":     expert_analysis[:2000],
            "final_trade_decision": str(final_state.get("final_trade_decision", ""))[:500],
            "confidence":          0.80 if normalized in ("BUY", "SELL") else 0.40,
            "entry_price":         entry,
            "stop_loss":           sl,
            "take_profit":         tp,
            "current_price":       indicators.get("current_price"),
            "atr":                 atr,
            "elapsed_sec":         round(time.time() - start, 1),
        }
    except Exception as e:
        import traceback
        output = {
            "success":           False,
            "symbol":            symbol,
            "signal_rating":     "ERROR",
            "normalized_rating": "HOLD",
            "expert_analysis":   "",
            "final_trade_decision": "",
            "confidence":        0.0,
            "entry_price":       None,
            "stop_loss":         None,
            "take_profit":       None,
            "current_price":     None,
            "atr":               None,
            "error":             str(e),
            "traceback":         traceback.format_exc()[-800:],
            "elapsed_sec":       round(time.time() - start, 1),
        }
    finally:
        _restore_stdout()

    _orig_stdout.write(json.dumps(output))
    sys.exit(0 if output["success"] else 1)


if __name__ == "__main__":
    main()
