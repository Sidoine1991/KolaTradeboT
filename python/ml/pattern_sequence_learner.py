"""Markov / n-gram : motifs passés → motif suivant + biais directionnel.

Apprend en live à chaque nouvelle bougie M1 (token = figure chartiste ou
chandelier). Sert de confluence GOM : jamais un upgrade WAIT→GOOD à lui seul.
"""
from __future__ import annotations

import json
import threading
import time
from collections import Counter, defaultdict, deque
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parents[2]
MODEL_PATH = ROOT / "data" / "pattern_sequence_model.json"

MIN_OBS = 3
MAX_HISTORY = 48
SAVE_EVERY_OBS = 5
SAVE_EVERY_SEC = 20.0
BOOST_CAP = 0.35
CONF_MIN = 0.40

_lock = threading.Lock()
_state: Dict[str, Any] = {
    "updated_at": None,
    "obs": 0,
    "symbols": {},
}
_loaded = False
_last_save = 0.0
_obs_since_save = 0


def _empty_sym() -> Dict[str, Any]:
    return {
        "history": [],
        "last_bar": 0,
        "last_token": "",
        "last_close": 0.0,
        "trans": {},
        "outcomes": {},
        "n": 0,
    }


def _load() -> None:
    global _loaded, _state
    if _loaded:
        return
    _loaded = True
    if not MODEL_PATH.is_file():
        return
    try:
        data = json.loads(MODEL_PATH.read_text(encoding="utf-8"))
        if isinstance(data, dict) and "symbols" in data:
            _state = data
    except Exception:
        pass


def _save(force: bool = False) -> None:
    global _last_save, _obs_since_save
    now = time.time()
    if not force and _obs_since_save < SAVE_EVERY_OBS and (now - _last_save) < SAVE_EVERY_SEC:
        return
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    _state["updated_at"] = datetime.now(timezone.utc).isoformat()
    tmp = MODEL_PATH.with_suffix(".tmp")
    tmp.write_text(json.dumps(_state, ensure_ascii=False), encoding="utf-8")
    tmp.replace(MODEL_PATH)
    _last_save = now
    _obs_since_save = 0


def _sym_key(symbol: str) -> str:
    return str(symbol or "").strip().upper().replace(" ", "")


def current_token(
    bull_hits: str = "",
    bear_hits: str = "",
    extra_tags: Optional[List[str]] = None,
) -> str:
    """Un token stable par barre : BULL:ENGULFING, BEAR:THREE_CROWS, NEUT:NONE."""
    bull = [p.strip() for p in str(bull_hits or "").split(",") if p.strip()]
    bear = [p.strip() for p in str(bear_hits or "").split(",") if p.strip()]
    if bull and (not bear or len(bull) >= len(bear)):
        name = bull[0].split("@")[0]
        return f"BULL:{name}" if name else "BULL:PAT"
    if bear:
        name = bear[0].split("@")[0]
        return f"BEAR:{name}" if name else "BEAR:PAT"
    for tag in extra_tags or []:
        t = str(tag).upper().strip()
        if t in ("COMPRESSION", "EXPANSION", "HAMMER", "SHOOTING_STAR"):
            return f"NEUT:{t}"
    return "NEUT:NONE"


def _dir_from_return(ret: float) -> str:
    if ret > 1e-8:
        return "BUY"
    if ret < -1e-8:
        return "SELL"
    return "FLAT"


def observe(
    symbol: str,
    bar_time: int,
    close: float,
    bull_hits: str = "",
    bear_hits: str = "",
    extra_tags: Optional[List[str]] = None,
) -> str:
    """Enregistre la transition motif_t-1 → motif_t. Retourne le token courant."""
    global _obs_since_save
    token = current_token(bull_hits, bear_hits, extra_tags)
    key = _sym_key(symbol)
    if not key or bar_time <= 0 or close <= 0:
        return token

    with _lock:
        _load()
        sym = _state.setdefault("symbols", {}).setdefault(key, _empty_sym())
        if int(sym.get("last_bar", 0) or 0) == int(bar_time):
            return token

        prev = str(sym.get("last_token") or "")
        prev_close = float(sym.get("last_close") or 0.0)
        if prev and prev_close > 0:
            trans = sym.setdefault("trans", {})
            bucket = trans.setdefault(prev, {})
            bucket[token] = int(bucket.get(token, 0)) + 1
            ret = (float(close) / prev_close) - 1.0
            oc = sym.setdefault("outcomes", {})
            ob = oc.setdefault(prev, {"BUY": 0, "SELL": 0, "FLAT": 0})
            ob[_dir_from_return(ret)] = int(ob.get(_dir_from_return(ret), 0)) + 1
            sym["n"] = int(sym.get("n", 0)) + 1
            _state["obs"] = int(_state.get("obs", 0)) + 1
            _obs_since_save += 1

        hist = list(sym.get("history") or [])
        hist.append(token)
        sym["history"] = hist[-MAX_HISTORY:]
        sym["last_bar"] = int(bar_time)
        sym["last_token"] = token
        sym["last_close"] = float(close)
        _save(False)
    return token


def predict(symbol: str) -> Dict[str, Any]:
    """Probabilités du prochain token + direction historique après le token actuel."""
    key = _sym_key(symbol)
    empty = {
        "ok": False,
        "symbol": symbol,
        "token": "NEUT:NONE",
        "next_pattern": "",
        "next_dir": "NEUT",
        "confidence": 0.0,
        "n": 0,
        "alternatives": [],
        "boost_buy": 0.0,
        "boost_sell": 0.0,
    }
    with _lock:
        _load()
        sym = (_state.get("symbols") or {}).get(key)
        if not sym:
            return empty
        token = str(sym.get("last_token") or "NEUT:NONE")
        n = int(sym.get("n", 0) or 0)
        trans = (sym.get("trans") or {}).get(token) or {}
        outcomes = (sym.get("outcomes") or {}).get(token) or {}

    total_t = sum(int(v) for v in trans.values())
    alts: List[Tuple[str, float, int]] = []
    if total_t > 0:
        vocab = max(1, len(trans))
        for nxt, cnt in trans.items():
            p = (int(cnt) + 1.0) / (total_t + vocab)
            alts.append((str(nxt), float(p), int(cnt)))
        alts.sort(key=lambda x: x[1], reverse=True)

    next_pat = alts[0][0] if alts else ""
    next_p = alts[0][1] if alts else 0.0

    buy_n = int(outcomes.get("BUY", 0) or 0)
    sell_n = int(outcomes.get("SELL", 0) or 0)
    flat_n = int(outcomes.get("FLAT", 0) or 0)
    out_n = buy_n + sell_n + flat_n
    if out_n <= 0:
        next_dir = "NEUT"
        dir_p = 0.0
    elif buy_n == sell_n:
        next_dir = "NEUT"
        dir_p = 0.5
    elif buy_n > sell_n:
        next_dir = "BUY"
        dir_p = (buy_n + 1.0) / (out_n + 2.0)
    else:
        next_dir = "SELL"
        dir_p = (sell_n + 1.0) / (out_n + 2.0)

    # Confiance = min(proba transition, proba direction) × couverture
    cover = min(1.0, n / 40.0)
    conf = 0.0
    if n >= MIN_OBS and (total_t > 0 or out_n > 0):
        conf = round(min(0.95, 0.5 * next_p + 0.5 * dir_p) * (0.55 + 0.45 * cover), 3)

    boost_buy = 0.0
    boost_sell = 0.0
    if conf >= CONF_MIN and n >= MIN_OBS:
        mag = min(BOOST_CAP, (conf - 0.5) * 1.2)
        if next_dir == "BUY":
            boost_buy = round(mag, 3)
        elif next_dir == "SELL":
            boost_sell = round(mag, 3)

    return {
        "ok": n >= MIN_OBS,
        "symbol": symbol,
        "token": token,
        "next_pattern": next_pat,
        "next_dir": next_dir,
        "confidence": conf,
        "n": n,
        "alternatives": [
            {"pattern": a[0], "p": round(a[1], 3), "count": a[2]} for a in alts[:5]
        ],
        "boost_buy": boost_buy,
        "boost_sell": boost_sell,
        "outcome_buy": buy_n,
        "outcome_sell": sell_n,
    }


def apply_to_record(record: Dict[str, Any], pred: Dict[str, Any]) -> None:
    """Écrit les champs GOM + petit boost pattern_score (plafonné)."""
    record["pattern_seq_token"] = pred.get("token", "")
    record["pattern_seq_next"] = pred.get("next_pattern", "")
    record["pattern_seq_dir"] = pred.get("next_dir", "NEUT")
    record["pattern_seq_conf"] = float(pred.get("confidence", 0) or 0)
    record["pattern_seq_n"] = int(pred.get("n", 0) or 0)
    bb = float(pred.get("boost_buy", 0) or 0)
    bs = float(pred.get("boost_sell", 0) or 0)
    if bb > 0:
        record["pattern_score_buy"] = round(
            float(record.get("pattern_score_buy", 0) or 0) + bb, 2
        )
    if bs > 0:
        record["pattern_score_sell"] = round(
            float(record.get("pattern_score_sell", 0) or 0) + bs, 2
        )
