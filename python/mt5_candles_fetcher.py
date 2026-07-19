#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Bougies OHLC depuis MT5 — multi-terminal (Deriv + Weltrade + StarTrader)."""

from __future__ import annotations

import logging
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError
from pathlib import Path
from typing import Optional

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

logger = logging.getLogger(__name__)

_mt5_ready = False
_last_init_error: Optional[str] = None
_current_broker: Optional[str] = None
_mt5_lock = __import__("threading").Lock()
_symbol_cache: dict[str, str] = {}  # canonical → mt5 name cache
_MT5_CALL_TIMEOUT = 10.0  # secondes max pour tout appel MT5 bloquant
_MT5_EXECUTOR = ThreadPoolExecutor(max_workers=1, thread_name_prefix="mt5_call")

DEFAULT_DERIV_TERMINAL = r"D:\Program Files\MetaTrader 5\terminal64.exe"
DEFAULT_WELTRADE_TERMINAL = r"D:\Program Files\MetaTrader 5 - Copie\terminal64.exe"
DEFAULT_STARTRADER_TERMINAL = r"D:\Program Files\MetaTrader 5 - Copie (2)\terminal64.exe"
DEFAULT_XMGLOBAL_TERMINAL = r"D:\Program Files\MetaTrader 5 - XMGlobal\terminal64.exe"

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


def _broker_for_symbol(symbol: str) -> str:
    try:
        from symbol_mapper import is_weltrade_symbol, is_startrader_symbol
        if is_weltrade_symbol(symbol):
            return "weltrade"
        if is_startrader_symbol(symbol):
            return "startrader"
        return "deriv"
    except ImportError:
        s = (symbol or "").upper().replace(" ", "")
        if "PAINX" in s or "GAINX" in s or "FXVOL" in s or "SFVVOL" in s:
            return "weltrade"
        if any(x in s for x in (
            "EURUSD", "GBPUSD", "USDJPY", "USDCAD", "AUDUSD", "USDCHF", "NZDUSD",
            "EURGBP", "EURJPY", "GBPJPY", "EURAUD", "GBPAUD", "AUDJPY",
            "EURNOK", "USDZAR", "XAUUSD", "XAUEUR", "XAGUSD", "BTCUSD", "ETHUSD",
        )):
            return "startrader"
        return "deriv"


def _terminal_path_for_broker(broker: str) -> str:
    if broker == "weltrade":
        return (
            os.getenv("MT5_WELTRADE_TERMINAL_PATH", DEFAULT_WELTRADE_TERMINAL).strip()
            or DEFAULT_WELTRADE_TERMINAL
        )
    if broker == "startrader":
        return (
            os.getenv("MT5_STARTRADER_TERMINAL_PATH", DEFAULT_STARTRADER_TERMINAL).strip()
            or DEFAULT_STARTRADER_TERMINAL
        )
    if broker == "xmglobal":
        return (
            os.getenv("MT5_XMGLOBAL_TERMINAL_PATH", DEFAULT_XMGLOBAL_TERMINAL).strip()
            or DEFAULT_XMGLOBAL_TERMINAL
        )
    return (
        os.getenv("MT5_TERMINAL_PATH", DEFAULT_DERIV_TERMINAL).strip()
        or DEFAULT_DERIV_TERMINAL
    )


def _shutdown_mt5() -> None:
    global _mt5_ready, _current_broker
    if not mt5_python_available():
        return
    import MetaTrader5 as mt5
    try:
        _mt5_call_with_timeout(mt5.shutdown)
    except Exception:
        pass
    _mt5_ready = False
    _current_broker = None
    _symbol_cache.clear()  # les noms de symboles varient entre terminaux


def ensure_mt5_connected(symbol: Optional[str] = None, broker: Optional[str] = None) -> bool:
    """Connecte le terminal MT5 adapté au symbole (Deriv, Weltrade, StarTrader, XMGlobal).

    Si `broker` est fourni, il prime sur l'inférence par symbole — utile pour
    la découverte de symbols (on se connecte à un terminal sans symbole précis).
    """
    global _mt5_ready, _last_init_error, _current_broker

    if not mt5_python_available():
        _last_init_error = "MetaTrader5 non installé (pip install MetaTrader5)"
        return False

    if not broker:
        broker = _broker_for_symbol(symbol or "")
    path = _terminal_path_for_broker(broker)

    import MetaTrader5 as mt5

    if _mt5_ready and _current_broker == broker:
        if _mt5_call_with_timeout(mt5.terminal_info) is not None:
            return True
        _mt5_ready = False

    if _mt5_ready and _current_broker != broker:
        logger.info("MT5 switch terminal: %s -> %s", _current_broker, broker)
        _shutdown_mt5()
        time.sleep(1.0)  # laisse le terminal précédent se libérer

    init_kwargs = {"path": path} if path else {}
    init_timeout = float(
        os.getenv(
            "MT5_INIT_TIMEOUT_SEC",
            "3" if broker in ("startrader", "xmglobal") else "25" if broker in ("weltrade") else "15",
        )
    )

    login = os.getenv("MT5_LOGIN", "").strip()
    password = os.getenv("MT5_PASSWORD", "").strip()
    server = os.getenv("MT5_SERVER", "").strip()

    ok = False
    if broker == "deriv" and login and password and server:
        try:
            _login = int(login)
            future = _MT5_EXECUTOR.submit(
                mt5.initialize, login=_login, password=password, server=server, **init_kwargs
            )
            ok = future.result(timeout=init_timeout) or False
        except FuturesTimeoutError:
            logger.warning("MT5 initialize(login) timeout — broker=%s", broker)
        except Exception as exc:
            logger.debug("MT5 init with login failed: %s", exc)

    if not ok:
        try:
            future = _MT5_EXECUTOR.submit(mt5.initialize, **init_kwargs)
            ok = future.result(timeout=init_timeout) or False
        except FuturesTimeoutError:
            _last_init_error = f"mt5.initialize timeout ({init_timeout}s) broker={broker}"
            logger.warning(_last_init_error)
            return False
        except Exception as exc:
            _last_init_error = str(exc)
            return False

    if not ok:
        err = _mt5_call_with_timeout(mt5.last_error)
        _last_init_error = f"mt5.initialize failed ({broker}): {err} path={path}"
        return False

    ti = _mt5_call_with_timeout(mt5.terminal_info)
    ai = _mt5_call_with_timeout(mt5.account_info)
    if ti is None:
        _last_init_error = f"terminal_info() vide — MT5 {broker} ouvert ?"
        return False

    _mt5_ready = True
    _current_broker = broker
    _last_init_error = None
    logger.info(
        "MT5 connecté [%s]: %s | compte=%s serveur=%s | path=%s",
        broker,
        ti.name,
        getattr(ai, "login", "?"),
        getattr(ai, "server", "?"),
        path,
    )
    return True


def ensure_mt5_connected_legacy() -> bool:
    """Compatibilité — connecte Deriv par défaut."""
    return ensure_mt5_connected(None)


def discover_symbols_via_api(
    broker: str = "xmglobal",
    only_visible: bool = True,
    only_tradable: bool = True,
) -> list[str]:
    """Découvre les symbols du terminal MT5 du broker via l'API (mt5.symbols_get()).

    Contrairement à la liste codée en dur (gom_symbols.py), ceci interroge
    réellement le terminal du broker et renvoie les symbols qu'il expose — utile
    pour un nouveau broker (ex: XMGlobal) sans avoir à lister ses symbols à la main.

    - only_visible   : ne garde que les symbols visibles dans la liste du terminal
    - only_tradable : exclut les symbols en mode TRADE_MODE_DISABLED
    """
    if not mt5_python_available():
        logger.error("MetaTrader5 non installé — impossible de découvrir les symbols")
        return []
    if not ensure_mt5_connected(broker=broker):
        logger.error("MT5 %s non connecté — découverte de symbols impossible", broker)
        return []

    import MetaTrader5 as mt5

    all_syms = _mt5_call_with_timeout(mt5.symbols_get)
    if all_syms is None:
        logger.warning("symbols_get() timeout — broker=%s", broker)
        return []

    found: list[str] = []
    for s in all_syms:
        # s est un namedtuple SymbolInfo : s.name, s.visible, s.trade_mode
        if only_visible and not getattr(s, "visible", True):
            continue
        if only_tradable and int(getattr(s, "trade_mode", 0)) == 0:  # TRADE_MODE_DISABLED
            continue
        name = getattr(s, "name", "")
        if name:
            found.append(str(name))

    found.sort(key=lambda x: x.upper())
    logger.info("Découverte %s via API : %d symbols", broker, len(found))
    return found


def _mt5_call_with_timeout(fn, *args, timeout: float = _MT5_CALL_TIMEOUT):
    """Exécute fn(*args) dans un thread avec timeout pour éviter le blocage sur MT5."""
    future = _MT5_EXECUTOR.submit(fn, *args)
    try:
        return future.result(timeout=timeout)
    except FuturesTimeoutError:
        logger.warning("MT5 call timeout (%.1fs): %s", timeout, getattr(fn, "__name__", fn))
        return None
    except Exception as exc:
        logger.debug("MT5 call error %s: %s", getattr(fn, "__name__", fn), exc)
        return None


def _resolve_broker_symbol(symbol: str, broker: Optional[str] = None) -> Optional[str]:
    # Cache lookup (évite symbols_get() répétés)
    if broker:
        try:
            ensure_mt5_connected(broker=broker)
        except Exception:
            pass
    cached = _symbol_cache.get(symbol.strip())
    if cached:
        return cached

    try:
        from symbol_mapper import resolve_mt5_symbol
        canon = resolve_mt5_symbol(symbol)
    except ImportError:
        canon = symbol.strip()

    import MetaTrader5 as mt5

    candidates = [canon, symbol.strip()]
    seen: set[str] = set()
    for cand in candidates:
        if not cand or cand in seen:
            continue
        seen.add(cand)
        info = _mt5_call_with_timeout(mt5.symbol_info, cand)
        if info is not None:
            if not info.visible:
                _mt5_call_with_timeout(mt5.symbol_select, cand, True)
            _symbol_cache[symbol.strip()] = cand
            return cand

    # Fallback fuzzy sur symbols_get() — avec timeout pour ne pas bloquer
    compact = (candidates[-1] if candidates else symbol).upper().replace(" ", "")
    all_syms = _mt5_call_with_timeout(mt5.symbols_get)
    if all_syms is None:
        logger.warning("symbols_get() timeout — symbole %s non résolu", symbol)
        return None
    for s in all_syms:
        key = s.name.upper().replace(" ", "")
        if key == compact or (compact in key or key in compact):
            if len(key) >= 5 and len(compact) >= 5:
                _mt5_call_with_timeout(mt5.symbol_select, s.name, True)
                _symbol_cache[symbol.strip()] = s.name
                return s.name
    return None


def _canon_tf(timeframe: str) -> str:
    t = str(timeframe or "").upper().strip()
    aliases = {
        "M1": "1", "M3": "3", "M5": "5", "M15": "15", "M30": "30",
        "H1": "60", "H2": "120", "H4": "240", "D1": "D", "W1": "W", "MN": "M",
    }
    return aliases.get(t, t)


def fetch_mt5_candles(symbol: str, timeframe: str, bars: int = 200, broker: Optional[str] = None) -> Optional[pd.DataFrame]:
    """Lit les bougies fermées depuis MT5 (shift=1).

    `broker` verrouille le terminal utilisé (au lieu de l'inférence par nom) —
    indispensable pour poller un broker découvert (XMGlobal) dont les noms
    de symbols chevauchent un autre broker (EURUSD, XAUUSD…).
    """
    with _mt5_lock:
        if not ensure_mt5_connected(symbol, broker=broker):
            return None

        import MetaTrader5 as mt5

        sym = _resolve_broker_symbol(symbol, broker=broker)
        if not sym:
            logger.warning(
                "Symbole MT5 introuvable: %s (broker=%s, terminal=%s)",
                symbol,
                _current_broker,
                _terminal_path_for_broker(_current_broker or "deriv"),
            )
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

        rates = _mt5_call_with_timeout(mt5.copy_rates_from_pos, sym, mt5_tf, 1, bars)
        if rates is None or len(rates) == 0:
            rates = _mt5_call_with_timeout(mt5.copy_rates_from_pos, sym, mt5_tf, 0, bars)
        if rates is None or len(rates) == 0:
            logger.warning("copy_rates vide: %s %s", sym, tf_label)
            return None

        df = pd.DataFrame(rates)
        df["time"] = pd.to_datetime(df["time"], unit="s")
        df.set_index("time", inplace=True)
        if "tick_volume" in df.columns and "volume" not in df.columns:
            df["volume"] = df["tick_volume"]
        return df[["open", "high", "low", "close", "volume"]].copy()


def fetch_mt5_live_dashboard(symbol: Optional[str] = None) -> dict:
    """Compte + positions + Market Watch via API Python MT5 (fallback dashboard)."""
    out: dict = {
        "connected": False,
        "account": {},
        "positions": [],
        "symbols_watch": [],
        "terminal": None,
        "terminal_key": "",
        "error": _last_init_error,
        "source": "python_bridge",
    }
    if not mt5_python_available():
        out["error"] = "MetaTrader5 non installé (pip install MetaTrader5)"
        return out
    if not ensure_mt5_connected(symbol):
        out["error"] = _last_init_error or "MT5 non connecté"
        return out

    import MetaTrader5 as mt5

    ti = _mt5_call_with_timeout(mt5.terminal_info)
    ai = _mt5_call_with_timeout(mt5.account_info)
    if ai is None:
        out["error"] = "account_info() vide"
        return out

    out["connected"] = True
    out["error"] = None
    out["account"] = {
        "login": ai.login,
        "server": ai.server,
        "name": ai.name,
        "company": ai.company,
        "balance": float(ai.balance),
        "equity": float(ai.equity),
        "margin": float(ai.margin),
        "margin_free": float(ai.margin_free),
        "profit": float(ai.profit),
        "currency": ai.currency,
        "leverage": int(ai.leverage),
    }
    out["terminal_key"] = f"python:{ai.login}@{ai.server}"
    if ti:
        out["terminal"] = {
            "name": ti.name,
            "company": ti.company,
            "path": ti.path,
            "connected": bool(ti.connected),
        }

    for p in (_mt5_call_with_timeout(mt5.positions_get) or []):
        ptype = "BUY" if p.type == 0 else "SELL"
        profit = float(p.profit + p.swap + getattr(p, "commission", 0.0))
        out["positions"].append({
            "ticket": int(p.ticket),
            "symbol": p.symbol,
            "type": ptype,
            "volume": float(p.volume),
            "price_open": float(p.price_open),
            "sl": float(p.sl),
            "tp": float(p.tp),
            "profit": profit,
            "magic": int(p.magic),
            "comment": p.comment or "",
        })

    visible = [s.name for s in (_mt5_call_with_timeout(mt5.symbols_get) or []) if s.visible]
    out["symbols_watch"] = visible[:80]
    return out


def mt5_status_snapshot(symbol: Optional[str] = None) -> dict:
    """Diagnostic connexion MT5 pour /gom/mt5-status."""
    broker = _broker_for_symbol(symbol or "")
    out = {
        "python_package": mt5_python_available(),
        "connected": False,
        "broker": broker,
        "terminal_path": _terminal_path_for_broker(broker),
        "terminal": None,
        "account": None,
        "last_error": _last_init_error,
    }
    if not out["python_package"]:
        out["hint"] = "pip install MetaTrader5"
        return out
    if not ensure_mt5_connected(symbol):
        out["hint"] = f"Ouvrez MetaTrader 5 ({broker}) et connectez-vous"
        return out
    import MetaTrader5 as mt5

    ti = _mt5_call_with_timeout(mt5.terminal_info)
    ai = _mt5_call_with_timeout(mt5.account_info)
    out["connected"] = True
    out["current_broker"] = _current_broker
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
