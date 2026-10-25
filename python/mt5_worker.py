#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mt5_worker.py — process dédié à UN SEUL terminal MT5, connexion permanente.

Contexte : jusqu'ici, mt5_candles_fetcher.py partageait un seul connecteur MT5
par process (ai_server.py, gom_mt5_poller.py) entre 4 terminaux (Deriv,
Weltrade, StarTrader, XMGlobal), avec shutdown()+initialize()+sleep(1.0) à
chaque changement de broker. Chaque process fait donc "l'aiguilleur" entre
plusieurs terminaux, ce qui coûte du temps et fragilise les données pendant
la bascule.

Ce worker élimine la bascule : un process = un broker = un terminal, connecté
en continu, jamais de shutdown() volontaire. mt5_candles_fetcher.py devient un
simple client HTTP qui route vers le worker du bon broker (voir ce fichier).

Usage :
    python mt5_worker.py --broker weltrade
    python mt5_worker.py --broker deriv --port 8011
    MT5_WORKER_BROKER=startrader python mt5_worker.py

Endpoints :
    GET /health                                    -> statut connexion (léger)
    GET /candles?symbol=X&timeframe=Y&bars=Z        -> bougies OHLC (JSON)
    GET /symbols?only_visible=&only_tradable=       -> symboles exposés par le terminal
    GET /dashboard                                  -> compte + positions + market watch
    GET /status                                     -> diagnostic complet
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError
from typing import Any, Optional

import pandas as pd

try:
    import MetaTrader5 as mt5
except ImportError:
    print(
        "MetaTrader5 non installé dans cet environnement — "
        "pip install MetaTrader5",
        file=sys.stderr,
    )
    sys.exit(1)

from fastapi import FastAPI, HTTPException, Query
import uvicorn

# --------------------------------------------------------------------------
# Config par broker (identique à l'ancien mt5_candles_fetcher.py)
# --------------------------------------------------------------------------

DEFAULT_TERMINAL_PATHS = {
    "deriv": r"D:\Program Files\MetaTrader 5\terminal64.exe",
    "weltrade": r"D:\Program Files\MetaTrader 5 - Copie\terminal64.exe",
    "startrader": r"D:\Program Files\MetaTrader 5 - Copie (2)\terminal64.exe",
    "xmglobal": r"D:\Program Files\MetaTrader 5 - XMGlobal\terminal64.exe",
}
ENV_PATH_VARS = {
    "deriv": "MT5_TERMINAL_PATH",
    "weltrade": "MT5_WELTRADE_TERMINAL_PATH",
    "startrader": "MT5_STARTRADER_TERMINAL_PATH",
    "xmglobal": "MT5_XMGLOBAL_TERMINAL_PATH",
}
DEFAULT_PORTS = {"weltrade": 8010, "deriv": 8011, "startrader": 8012, "xmglobal": 8013}
DEFAULT_INIT_TIMEOUTS = {"startrader": 3.0, "xmglobal": 3.0, "weltrade": 25.0, "deriv": 15.0}

HEALTH_LOOP_SEC = float(os.getenv("MT5_WORKER_HEALTH_INTERVAL_SEC", "15"))

CANON_TO_MT5_TF = {
    "1": "M1", "5": "M5", "15": "M15", "30": "M30",
    "60": "H1", "120": "H2", "240": "H4",
    "D": "D1", "W": "W1", "M": "MN1",
}


def _canon_tf(timeframe: str) -> str:
    t = str(timeframe or "").upper().strip()
    aliases = {
        "M1": "1", "M3": "3", "M5": "5", "M15": "15", "M30": "30",
        "H1": "60", "H2": "120", "H4": "240", "D1": "D", "W1": "W", "MN": "M",
    }
    return aliases.get(t, t)


logger = logging.getLogger("mt5_worker")


class Mt5Worker:
    """Connexion permanente à UN terminal MT5. Jamais de shutdown() volontaire."""

    def __init__(self, broker: str, path: str, init_timeout: float):
        self.broker = broker
        self.path = path
        self.init_timeout = init_timeout
        self.call_timeout = float(os.getenv("MT5_WORKER_CALL_TIMEOUT_SEC", "10"))
        self.lock = threading.RLock()
        self.executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix=f"mt5_{broker}")
        self.connected = False
        self.last_error: Optional[str] = None
        self.symbol_cache: dict[str, str] = {}

    # -- appels MT5 protégés par timeout (évite un thread bloqué à vie) --
    def _call(self, fn, *args, timeout: Optional[float] = None):
        fut = self.executor.submit(fn, *args)
        try:
            return fut.result(timeout=timeout or self.call_timeout)
        except FuturesTimeoutError:
            logger.warning("Appel MT5 timeout: %s", getattr(fn, "__name__", fn))
            return None
        except Exception as exc:
            logger.debug("Appel MT5 erreur %s: %s", getattr(fn, "__name__", fn), exc)
            return None

    def connect(self) -> bool:
        with self.lock:
            login = os.getenv("MT5_LOGIN", "").strip()
            password = os.getenv("MT5_PASSWORD", "").strip()
            server = os.getenv("MT5_SERVER", "").strip()
            init_kwargs = {"path": self.path} if self.path else {}

            ok = False
            if self.broker == "deriv" and login and password and server:
                try:
                    fut = self.executor.submit(
                        mt5.initialize, login=int(login), password=password,
                        server=server, **init_kwargs,
                    )
                    ok = fut.result(timeout=self.init_timeout) or False
                except FuturesTimeoutError:
                    logger.warning("initialize(login) timeout (%.1fs)", self.init_timeout)
                except Exception as exc:
                    logger.debug("init avec login échoué: %s", exc)

            if not ok:
                try:
                    fut = self.executor.submit(mt5.initialize, **init_kwargs)
                    ok = fut.result(timeout=self.init_timeout) or False
                except FuturesTimeoutError:
                    self.last_error = f"mt5.initialize timeout ({self.init_timeout}s)"
                    self.connected = False
                    return False
                except Exception as exc:
                    self.last_error = str(exc)
                    self.connected = False
                    return False

            if not ok:
                err = self._call(mt5.last_error)
                self.last_error = f"mt5.initialize failed: {err} path={self.path}"
                self.connected = False
                return False

            ti = self._call(mt5.terminal_info)
            ai = self._call(mt5.account_info)
            if ti is None:
                self.last_error = f"terminal_info() vide — MT5 {self.broker} ouvert ?"
                self.connected = False
                return False

            self.connected = True
            self.last_error = None
            self.symbol_cache.clear()
            logger.info(
                "Connecté [%s]: %s | compte=%s serveur=%s | path=%s",
                self.broker, ti.name, getattr(ai, "login", "?"),
                getattr(ai, "server", "?"), self.path,
            )
            return True

    def ensure_connected(self) -> bool:
        if self.connected:
            ti = self._call(mt5.terminal_info)
            if ti is not None:
                return True
            logger.warning("terminal_info() KO — reconnexion [%s]", self.broker)
            self.connected = False
        return self.connect()

    def resolve_symbol(self, symbol: str) -> Optional[str]:
        cached = self.symbol_cache.get(symbol.strip())
        if cached:
            return cached
        try:
            from symbol_mapper import resolve_mt5_symbol
            canon = resolve_mt5_symbol(symbol)
        except ImportError:
            canon = symbol.strip()

        candidates = [canon, symbol.strip()]
        seen: set[str] = set()
        for cand in candidates:
            if not cand or cand in seen:
                continue
            seen.add(cand)
            info = self._call(mt5.symbol_info, cand)
            if info is not None:
                if not info.visible:
                    self._call(mt5.symbol_select, cand, True)
                self.symbol_cache[symbol.strip()] = cand
                return cand

        compact = (candidates[-1] if candidates else symbol).upper().replace(" ", "")
        all_syms = self._call(mt5.symbols_get)
        if all_syms is None:
            logger.warning("symbols_get() timeout — symbole %s non résolu [%s]", symbol, self.broker)
            return None
        for s in all_syms:
            key = s.name.upper().replace(" ", "")
            if key == compact or (compact in key or key in compact):
                if len(key) >= 5 and len(compact) >= 5:
                    self._call(mt5.symbol_select, s.name, True)
                    self.symbol_cache[symbol.strip()] = s.name
                    return s.name
        return None

    def fetch_candles(self, symbol: str, timeframe: str, bars: int = 200) -> Optional[pd.DataFrame]:
        with self.lock:
            if not self.ensure_connected():
                return None
            sym = self.resolve_symbol(symbol)
            if not sym:
                logger.warning("Symbole introuvable: %s [%s]", symbol, self.broker)
                return None

            canon = _canon_tf(timeframe)
            tf_label = CANON_TO_MT5_TF.get(canon, "M15")
            tf_map = {
                "M1": mt5.TIMEFRAME_M1, "M5": mt5.TIMEFRAME_M5, "M15": mt5.TIMEFRAME_M15,
                "M30": mt5.TIMEFRAME_M30, "H1": mt5.TIMEFRAME_H1, "H2": mt5.TIMEFRAME_H2,
                "H4": mt5.TIMEFRAME_H4, "D1": mt5.TIMEFRAME_D1, "W1": mt5.TIMEFRAME_W1,
                "MN1": mt5.TIMEFRAME_MN1,
            }
            mt5_tf = tf_map.get(tf_label, mt5.TIMEFRAME_M15)

            rates = self._call(mt5.copy_rates_from_pos, sym, mt5_tf, 1, bars)
            if rates is None or len(rates) == 0:
                rates = self._call(mt5.copy_rates_from_pos, sym, mt5_tf, 0, bars)
            if rates is None or len(rates) == 0:
                logger.warning("copy_rates vide: %s %s [%s]", sym, tf_label, self.broker)
                return None

            df = pd.DataFrame(rates)
            df["time"] = pd.to_datetime(df["time"], unit="s")
            df.set_index("time", inplace=True)
            if "tick_volume" in df.columns and "volume" not in df.columns:
                df["volume"] = df["tick_volume"]
            return df[["open", "high", "low", "close", "volume"]].copy()

    def discover_symbols(self, only_visible: bool = True, only_tradable: bool = True) -> list[str]:
        with self.lock:
            if not self.ensure_connected():
                return []
            all_syms = self._call(mt5.symbols_get)
            if all_syms is None:
                return []
            found: list[str] = []
            for s in all_syms:
                if only_visible and not getattr(s, "visible", True):
                    continue
                if only_tradable and int(getattr(s, "trade_mode", 0)) == 0:
                    continue
                name = getattr(s, "name", "")
                if name:
                    found.append(str(name))
            found.sort(key=lambda x: x.upper())
            return found

    def dashboard_snapshot(self) -> dict:
        out: dict = {
            "connected": False, "account": {}, "positions": [], "symbols_watch": [],
            "terminal": None, "terminal_key": "", "error": None, "source": "python_bridge",
        }
        with self.lock:
            if not self.ensure_connected():
                out["error"] = self.last_error or "MT5 non connecté"
                return out
            ti = self._call(mt5.terminal_info)
            ai = self._call(mt5.account_info)
            if ai is None:
                out["error"] = "account_info() vide"
                return out
            out["connected"] = True
            out["account"] = {
                "login": ai.login, "server": ai.server, "name": ai.name, "company": ai.company,
                "balance": float(ai.balance), "equity": float(ai.equity), "margin": float(ai.margin),
                "margin_free": float(ai.margin_free), "profit": float(ai.profit),
                "currency": ai.currency, "leverage": int(ai.leverage),
            }
            out["terminal_key"] = f"python:{ai.login}@{ai.server}"
            if ti:
                out["terminal"] = {
                    "name": ti.name, "company": ti.company, "path": ti.path,
                    "connected": bool(ti.connected),
                }
            for p in (self._call(mt5.positions_get) or []):
                ptype = "BUY" if p.type == 0 else "SELL"
                profit = float(p.profit + p.swap + getattr(p, "commission", 0.0))
                out["positions"].append({
                    "ticket": int(p.ticket), "symbol": p.symbol, "type": ptype,
                    "volume": float(p.volume), "price_open": float(p.price_open),
                    "sl": float(p.sl), "tp": float(p.tp), "profit": profit,
                    "magic": int(p.magic), "comment": p.comment or "",
                })
            visible = [s.name for s in (self._call(mt5.symbols_get) or []) if s.visible]
            out["symbols_watch"] = visible[:80]
            return out

    def status_snapshot(self) -> dict:
        out = {
            "python_package": True,
            "connected": False,
            "broker": self.broker,
            "terminal_path": self.path,
            "terminal": None,
            "account": None,
            "last_error": self.last_error,
        }
        with self.lock:
            if not self.ensure_connected():
                out["hint"] = f"Ouvrez MetaTrader 5 ({self.broker}) et connectez-vous"
                return out
            ti = self._call(mt5.terminal_info)
            ai = self._call(mt5.account_info)
            out["connected"] = True
            if ti:
                out["terminal"] = {
                    "name": ti.name, "company": ti.company, "path": ti.path, "connected": ti.connected,
                }
            if ai:
                out["account"] = {
                    "login": ai.login, "server": ai.server, "balance": ai.balance, "trade_mode": ai.trade_mode,
                }
        return out


worker: Optional[Mt5Worker] = None
app = FastAPI(title="mt5_worker")


@app.get("/health")
def health():
    ok = worker.ensure_connected()
    return {"ok": ok, "broker": worker.broker, "connected": ok, "last_error": worker.last_error}


@app.get("/candles")
def candles(symbol: str, timeframe: str = "15", bars: int = 200):
    df = worker.fetch_candles(symbol, timeframe, bars)
    if df is None:
        raise HTTPException(status_code=503, detail=worker.last_error or f"candles indisponibles pour {symbol}")
    records = [
        {
            "time": idx.isoformat(),
            "open": float(row.open), "high": float(row.high),
            "low": float(row.low), "close": float(row.close),
            "volume": float(row.volume),
        }
        for idx, row in df.iterrows()
    ]
    return {"symbol": symbol, "timeframe": timeframe, "broker": worker.broker, "candles": records}


@app.get("/symbols")
def symbols(only_visible: bool = True, only_tradable: bool = True):
    return {"broker": worker.broker, "symbols": worker.discover_symbols(only_visible, only_tradable)}


@app.get("/dashboard")
def dashboard():
    return worker.dashboard_snapshot()


@app.get("/status")
def status():
    return worker.status_snapshot()


def _health_loop():
    while True:
        try:
            worker.ensure_connected()
        except Exception:
            logger.exception("Erreur boucle santé [%s]", worker.broker)
        time.sleep(HEALTH_LOOP_SEC)


def main():
    global worker, logger

    parser = argparse.ArgumentParser(description="Worker MT5 dédié à un seul broker/terminal")
    parser.add_argument("--broker", default=os.getenv("MT5_WORKER_BROKER", ""),
                        choices=sorted(DEFAULT_PORTS.keys()))
    parser.add_argument("--port", type=int, default=None)
    parser.add_argument("--path", default=None, help="Chemin terminal64.exe (sinon variable d'env / défaut)")
    parser.add_argument("--host", default=os.getenv("MT5_WORKER_HOST", "127.0.0.1"))
    args = parser.parse_args()

    broker = (args.broker or "").strip().lower()
    if broker not in DEFAULT_PORTS:
        parser.error(f"--broker requis, un de: {', '.join(sorted(DEFAULT_PORTS.keys()))}")

    path = args.path or os.getenv(ENV_PATH_VARS[broker], DEFAULT_TERMINAL_PATHS[broker])
    port = args.port or int(os.getenv(f"MT5_WORKER_PORT_{broker.upper()}", DEFAULT_PORTS[broker]))
    init_timeout = float(os.getenv("MT5_WORKER_INIT_TIMEOUT_SEC", str(DEFAULT_INIT_TIMEOUTS.get(broker, 15.0))))

    logging.basicConfig(
        level=logging.INFO,
        format=f"%(asctime)s [MT5-{broker.upper()}] %(message)s",
    )
    logger = logging.getLogger("mt5_worker")

    worker = Mt5Worker(broker, path, init_timeout)

    if not worker.connect():
        logger.warning(
            "Connexion initiale échouée (%s) — nouvelles tentatives toutes les %ss en tâche de fond",
            worker.last_error, HEALTH_LOOP_SEC,
        )

    threading.Thread(target=_health_loop, daemon=True).start()

    logger.info("Worker MT5 [%s] démarré sur %s:%s (terminal: %s)", broker, args.host, port, path)
    uvicorn.run(app, host=args.host, port=port, log_level="warning")


if __name__ == "__main__":
    main()
