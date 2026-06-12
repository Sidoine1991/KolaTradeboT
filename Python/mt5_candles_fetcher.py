#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Bougies OHLC depuis le terminal MT5 local (Deriv) — sans TradingView."""

from __future__ import annotations

import logging
import os
import sys
import time
from pathlib import Path
from typing import Optional

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

logger = logging.getLogger(__name__)

_mt5_ready = False
_last_init_error: Optional[str] = None
_mt5_lock = __import__("threading").Lock()

CANON_TO_MT5_TF = {
    "1": ("M1", None),
    "5": ("M5", None),
    "15": ("M15", None),
    "30": ("M30", None),
    "60": ("H1", None),
    "120": ("H2", None),
    "240": ("H4", None),
    "D": ("D1", None),
    "W": ("W1", None),
    "M": ("MN1", None),
}


def mt5_python_available() -> bool:
    try:
        import MetaTrader5  # noqa: F401
        return True
    except ImportError:
        return False


def ensure_mt5_connected() -> bool:
    """Attache le package Python au terminal MT5 déjà ouvert (Deriv)."""
    global _mt5_ready, _last_init_error
    if not mt5_python_available():
        _last_init_error = "MetaTrader5 non installé (pip install MetaTrader5)"
        return False

    import MetaTrader5 as mt5

    if _mt5_ready:
        if mt5.terminal_info() is not None:
            return True
        _mt5_ready = False

    login = os.getenv("MT5_LOGIN", "").strip()
    password = os.getenv("MT5_PASSWORD", "").strip()
    server = os.getenv("MT5_SERVER", "").strip()
    path = os.getenv("MT5_TERMINAL_PATH", "").strip()

    init_kwargs = {}
    if path:
        init_kwargs["path"] = path

    ok = False
    if login and password and server:
        try:
            ok = mt5.initialize(login=int(login), password=password, server=server, **init_kwargs)
        except Exception as exc:
            logger.debug("MT5 init with login failed: %s", exc)

    if not ok:
        try:
            ok = mt5.initialize(**init_kwargs)
        except Exception as exc:
            _last_init_error = str(exc)
            return False

    if not ok:
        err = mt5.last_error()
        _last_init_error = f"mt5.initialize failed: {err}"
        return False

    ti = mt5.terminal_info()
    ai = mt5.account_info()
    if ti is None:
        _last_init_error = "terminal_info() vide — MT5 ouvert ?"
        return False

    _mt5_ready = True
    _last_init_error = None
    logger.info(
        "MT5 connecté: %s | compte=%s serveur=%s",
        ti.name,
        getattr(ai, "login", "?"),
        getattr(ai, "server", "?"),
    )
    return True


def _resolve_broker_symbol(symbol: str) -> Optional[str]:
    from symbol_mapper import resolve_mt5_symbol

    import MetaTrader5 as mt5

    candidates = []
    canon = resolve_mt5_symbol(symbol)
    candidates.append(canon)
    candidates.append(symbol.strip())
    if canon != symbol.strip():
        candidates.append(symbol.strip())

    seen = set()
    for cand in candidates:
        if not cand or cand in seen:
            continue
        seen.add(cand)
        info = mt5.symbol_info(cand)
        if info is not None:
            if not info.visible:
                mt5.symbol_select(cand, True)
            return cand

    compact = (candidates[-1] if candidates else symbol).upper().replace(" ", "")
    for s in mt5.symbols_get() or []:
        key = s.name.upper().replace(" ", "")
        if key == compact:
            mt5.symbol_select(s.name, True)
            return s.name
    return None


def _canon_tf(timeframe: str) -> str:
    t = str(timeframe or "").upper().strip()
    aliases = {
        "M1": "1", "M3": "3", "M5": "5", "M15": "15", "M30": "30",
        "H1": "60", "H2": "120", "H4": "240", "D1": "D", "W1": "W", "MN": "M",
    }
    return aliases.get(t, t)


def fetch_mt5_candles(symbol: str, timeframe: str, bars: int = 200) -> Optional[pd.DataFrame]:
    """Lit les bougies fermées depuis MT5 (shift=1)."""
    with _mt5_lock:
        if not ensure_mt5_connected():
            return None

        import MetaTrader5 as mt5

        sym = _resolve_broker_symbol(symbol)
        if not sym:
            logger.warning("Symbole MT5 introuvable: %s", symbol)
            return None

        canon = _canon_tf(timeframe)
        tf_label = CANON_TO_MT5_TF.get(canon, ("M15", None))[0]
        tf_map = {
            "M1": mt5.TIMEFRAME_M1,
            "M5": mt5.TIMEFRAME_M5,
            "M15": mt5.TIMEFRAME_M15,
            "M30": mt5.TIMEFRAME_M30,
            "H1": mt5.TIMEFRAME_H1,
            "H2": mt5.TIMEFRAME_H2,
            "H4": mt5.TIMEFRAME_H4,
            "D1": mt5.TIMEFRAME_D1,
            "W1": mt5.TIMEFRAME_W1,
            "MN1": mt5.TIMEFRAME_MN1,
        }
        mt5_tf = tf_map.get(tf_label, mt5.TIMEFRAME_M15)

        rates = mt5.copy_rates_from_pos(sym, mt5_tf, 1, bars)
        if rates is None or len(rates) == 0:
            rates = mt5.copy_rates_from_pos(sym, mt5_tf, 0, bars)
        if rates is None or len(rates) == 0:
            logger.warning("copy_rates vide: %s %s", sym, tf_label)
            return None

        df = pd.DataFrame(rates)
        df["time"] = pd.to_datetime(df["time"], unit="s")
        df.set_index("time", inplace=True)
        if "tick_volume" in df.columns and "volume" not in df.columns:
            df["volume"] = df["tick_volume"]
        return df[["open", "high", "low", "close", "volume"]].copy()


def mt5_status_snapshot() -> dict:
    """Diagnostic connexion MT5 pour /gom/mt5-status."""
    out = {
        "python_package": mt5_python_available(),
        "connected": False,
        "terminal": None,
        "account": None,
        "last_error": _last_init_error,
    }
    if not out["python_package"]:
        out["hint"] = "pip install MetaTrader5"
        return out
    if not ensure_mt5_connected():
        out["hint"] = "Ouvrez MetaTrader 5 (Deriv) et connectez-vous au compte"
        return out
    import MetaTrader5 as mt5

    ti = mt5.terminal_info()
    ai = mt5.account_info()
    out["connected"] = True
    if ti:
        out["terminal"] = {
            "name": ti.name,
            "company": ti.company,
            "path": ti.path,
            "connected": ti.connected,
        }
    if ai:
        out["account"] = {
            "login": ai.login,
            "server": ai.server,
            "balance": ai.balance,
            "trade_mode": ai.trade_mode,
        }
    return out
