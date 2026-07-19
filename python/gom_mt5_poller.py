#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM MT5 Poller — calcul GOM 100% local depuis candles MT5 (sans TradingView)

Flux :
    MT5 Terminal
        → mt5_candles_fetcher.py   (bougies OHLC live, 7 TF)
        → gom_live_calculator.py   (indicateurs + scoring Pine)
        → POST /gom-verdict        (ai_server :8000)
        → SMC_Universal.mq5        (GET /gom-kola-dashboard)

Usage :
    python python/gom_mt5_poller.py              # boucle 30s, tous symboles
    python python/gom_mt5_poller.py --once        # un seul calcul
    python python/gom_mt5_poller.py --interval 60
    python python/gom_mt5_poller.py --symbols "XAUUSD,Boom 1000 Index"
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

try:
    from gom_symbols import all_gom_symbols
except ImportError:
    def all_gom_symbols(extra=None):
        return list(DEFAULT_SYMBOLS) + list(extra or [])

ROOT = Path(__file__).resolve().parent.parent
for p in (str(ROOT), str(ROOT / "python")):
    if p not in sys.path:
        sys.path.insert(0, p)

AI_SERVER_URL = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000").rstrip("/")
AI_SERVER_RENDER_URL = os.getenv(
    "AI_SERVER_RENDER_URL", "https://kolatradebot-7ofl.onrender.com"
).rstrip("/")
SERVER_WAIT_SEC = int(os.getenv("GOM_POLLER_WAIT_SERVER_SEC", "120"))
SERVER_CHECK_TIMEOUT = float(os.getenv("GOM_POLLER_HEALTH_TIMEOUT", "3"))

# --- Failover automatique local -> Render ---
# _active_server pointe vers l'endpoint actuellement utilisé. En cas d'échec
# répété sur l'endpoint actif, on bascule vers l'autre.
_active_server = AI_SERVER_URL
_fail_streak = 0
_FAIL_THRESHOLD = 3  # après N échecs consécutifs, bascule vers l'autre endpoint


def _other_server() -> str:
    return AI_SERVER_RENDER_URL if _active_server == AI_SERVER_URL else AI_SERVER_URL


def _mark_result(ok: bool) -> None:
    """Met à jour le compteur d'échecs et bascule si le seuil est atteint."""
    global _active_server, _fail_streak
    if ok:
        _fail_streak = 0
        return
    _fail_streak += 1
    if _fail_streak >= _FAIL_THRESHOLD:
        _active_server = _other_server()
        _fail_streak = 0
        log.warning(
            "🔄 GOM poller failover -> %s",
            "Render" if _active_server == AI_SERVER_RENDER_URL else "Local",
        )

DEFAULT_SYMBOLS: List[str] = [
    # Deriv Boom/Crash
    "Boom 50 Index", "Boom 150 Index", "Boom 200 Index", "Boom 300 Index",
    "Boom 500 Index", "Boom 600 Index", "Boom 900 Index", "Boom 1000 Index",
    "Crash 50 Index", "Crash 150 Index", "Crash 200 Index", "Crash 300 Index",
    "Crash 500 Index", "Crash 600 Index", "Crash 900 Index", "Crash 1000 Index",
    # Weltrade Boom/Crash
    "PainX 600", "PainX 1200", "GainX 400", "GainX 600", "GainX 800", "GainX 1200",
    # Volatility Deriv
    "Step Index",
    "Volatility 5 (1s) Index", "Volatility 10 (1s) Index", "Volatility 25 (1s) Index",
    "Volatility 30 (1s) Index", "Volatility 50 (1s) Index", "Volatility 75 (1s) Index",
    "Volatility 100 (1s) Index", "Volatility 150 (1s) Index", "Volatility 250 (1s) Index",
    "Volatility 10 Index", "Volatility 25 Index", "Volatility 50 Index",
    "Volatility 75 Index", "Volatility 100 Index", "Volatility 150 Index", "Volatility 250 Index",
    # Volatility Weltrade
    "FX Vol 20", "SFV Vol", "SFX Vol",
    # Forex
    "EURUSD", "GBPUSD", "USDJPY", "USDCAD", "AUDUSD", "USDCHF", "NZDUSD",
    "EURGBP", "EURJPY", "GBPJPY", "EURAUD", "GBPAUD", "AUDJPY",
    # Metals
    "XAUUSD", "XAUEUR", "XAGUSD",
    # Indices / Crypto
    "US30_x10", "BTCUSD", "ETHUSD",
]

POLL_INTERVAL = 30  # secondes

(ROOT / "logs").mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [GOM-MT5] %(message)s",
    handlers=[
        logging.StreamHandler(
            open(sys.stdout.fileno(), mode="w", encoding="utf-8", closefd=False)
        ),
        logging.FileHandler(str(ROOT / "logs" / "gom_mt5_poller.log"), encoding="utf-8"),
    ],
)
log = logging.getLogger(__name__)

_http = requests.Session()
_retry = Retry(total=1, connect=1, read=1, backoff_factor=0.2)
_http.mount("http://", HTTPAdapter(max_retries=_retry))
_http.mount("https://", HTTPAdapter(max_retries=_retry))

_server_down_logged = False


def _ai_server_ready() -> bool:
    try:
        r = _http.get(f"{_active_server}/health", timeout=SERVER_CHECK_TIMEOUT)
        ok = r.status_code == 200
        _mark_result(ok)
        return ok
    except Exception:
        _mark_result(False)
        return False


def wait_for_ai_server(max_wait_sec: int = SERVER_WAIT_SEC) -> bool:
    """Attend que ai_server réponde avant de poller."""
    t0 = time.time()
    while time.time() - t0 < max_wait_sec:
        if _ai_server_ready():
            log.info("✅ ai_server prêt — %s", _active_server)
            return True
        log.warning(
            "⏳ En attente ai_server (%s) — lancez: python ai_server.py",
            _active_server,
        )
        time.sleep(5)
    log.error(
        "❌ ai_server injoignable après %ds — arrêt. Démarrez: python ai_server.py",
        max_wait_sec,
    )
    return False


def _push_verdict(payload: Dict[str, Any]) -> bool:
    global _server_down_logged
    try:
        r = _http.post(f"{_active_server}/gom-verdict", json=payload, timeout=8)
        if r.ok and r.json().get("ok"):
            _server_down_logged = False
            _mark_result(True)
            log.info(
                "✅ %-20s → %-13s buy=%.1f sell=%.1f gap=%.1f coh=%.0f%% entry=%.2f sl=%.2f tp=%.2f atr=%.2f",
                payload["symbol"],
                payload["verdict"],
                payload.get("score_buy", 0),
                payload.get("score_sell", 0),
                payload.get("verdict_gap", 0),
                payload.get("coherence_pct", 0),
                payload.get("entry", 0),
                payload.get("sl", 0),
                payload.get("tp", 0),
                payload.get("atr", 0),
            )
            return True
        log.error("❌ /gom-verdict HTTP %s: %s", r.status_code, r.text[:200])
        _mark_result(False)
        return False
    except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as exc:
        _mark_result(False)
        if not _server_down_logged:
            log.error(
                "❌ ai_server injoignable (%s) — démarrez: python ai_server.py | %s",
                _active_server,
                exc,
            )
            _server_down_logged = True
        return False
    except requests.exceptions.RequestException as exc:
        _mark_result(False)
        if not _server_down_logged:
            log.error("❌ Erreur HTTP ai_server (%s): %s", _active_server, exc)
            _server_down_logged = True
        return False
    except Exception as exc:
        log.error("❌ push %s: %s", payload.get("symbol"), exc)
        return False


_WELTRADE_UTC_PREFIXES = ("PAINX", "GAINX", "FXVOL", "SFVVOL", "SFXVOL")


def _weltrade_gate_open(symbol: str) -> bool:
    """Retourne False si le symbole Weltrade est hors fenêtre 04h-23h UTC."""
    from datetime import datetime, timezone
    sym = symbol.upper().replace(" ", "")
    for prefix in _WELTRADE_UTC_PREFIXES:
        if sym.startswith(prefix):
            h = datetime.now(timezone.utc).hour
            in_window = 4 <= h < 23
            if not in_window:
                log.info("[GATE] %s: UTC %02dh hors 04h-23h — poll ignore", symbol, h)
            return in_window
    return True


def _buckets_by_broker(symbols: List[str]) -> Dict[str, List[str]]:
    """Associe chaque broker à sa liste de symboles — une bascule MT5 par bucket.

    Ordre stable : deriv → weltrade → startrader → xmglobal.
    Les symboles découverts (ex: XMGlobal) sont isolés dans leur propre
    bucket, ce qui évite la collision de noms avec StarTrader (EURUSD, XAUUSD…).
    """
    try:
        from mt5_candles_fetcher import _broker_for_symbol
    except ImportError:
        def _broker_for_symbol(s: str) -> str:
            u = (s or "").upper().replace(" ", "")
            if any(x in u for x in ("PAINX", "GAINX", "FXVOL", "SFVVOL", "SFXVOL")):
                return "weltrade"
            if any(x in u for x in (
                "EURUSD", "GBPUSD", "USDJPY", "XAUUSD", "XAUEUR", "XAGUSD",
                "BTCUSD", "ETHUSD", "EURNOK", "USDZAR",
            )):
                return "startrader"
            return "deriv"

    buckets: Dict[str, List[str]] = {}
    for s in symbols:
        b = _broker_for_symbol(s)
        buckets.setdefault(b, []).append(s)
    ordered: Dict[str, List[str]] = {}
    for k in ("deriv", "weltrade", "startrader", "xmglobal"):
        if buckets.get(k):
            ordered[k] = buckets[k]
    for k, v in buckets.items():  # brokers additionnels (ex: autres découverts)
        if k not in ordered:
            ordered[k] = v
    return ordered


def _sort_symbols_by_broker(symbols: List[str]) -> List[str]:
    """Compatibilité — liste à plat deriv → weltrade → startrader."""
    b = _buckets_by_broker(symbols)
    return [s for v in b.values() for s in v]


def poll_once(buckets: Dict[str, List[str]], calc) -> int:
    """Calcule GOM pour chaque symbole et pousse vers /gom-verdict.

    `buckets` mappe chaque broker à sa liste de symbols (codés ou découverts).
    Le terminal MT5 du broker est connecté une fois par bucket, ce qui évite
    les bascules de terminal à chaque symbole et permet de poller XMGlobal
    (découvert via l'API) en parallèle des brokers historiques.
    """
    if not _ai_server_ready():
        log.warning(
            "⏭️  Cycle ignoré — ai_server injoignable (%s). Lancez: python ai_server.py",
            _active_server,
        )
        return 0

    ok_count = 0
    server_lost = False
    for broker, symbols in buckets.items():
        if not symbols:
            continue

        # Connexion au terminal de ce broker (une seule fois par bucket)
        # Résilient : retry (max 2) pour pallier les déconnexions MT5 transitoires.
        try:
            from mt5_candles_fetcher import ensure_mt5_connected as _ensure_mt5
            connected = False
            for attempt in range(3):
                if _ensure_mt5(broker=broker):
                    connected = True
                    break
                if attempt < 2:
                    log.warning("⚠️  MT5 %s non connecté (essai %d/3) — nouvel essai...",
                                broker, attempt + 1)
                    time.sleep(2)
            if not connected:
                log.warning("⚠️  MT5 %s toujours non connecté — bucket ignoré (%d symboles). "
                            "Vérifiez que le terminal %s est ouvert.", broker, len(symbols), broker)
                continue
        except Exception as exc:
            log.warning("⚠️  MT5 %s injoignable — bucket ignoré: %s", broker, exc)
            continue

        for symbol in symbols:
            if server_lost:
                break
            try:
                resp = calc.build_api_response(symbol, broker=broker)
                if not resp.get("ok"):
                    log.warning("⚠️  %-20s SKIP — %s", symbol, resp.get("error", "no candles"))
                    continue

                entry = float(resp.get("price") or resp.get("close") or 0)
                atr = float(resp.get("atr14") or resp.get("atr") or 0)
                verdict_num = int(resp.get("verdict_num", 0))
                is_buy = verdict_num > 0

                if atr <= 0 and entry > 0:
                    atr = entry * 0.005
                sl_dist = max(atr * 1.5, entry * 0.002) if entry > 0 else 0
                tp_dist = sl_dist * 2.0

                sym_up = symbol.upper()
                if any(p in sym_up for p in ("BOOM", "CRASH")) and entry > 0:
                    sl_dist = max(sl_dist, 20.0)
                    tp_dist = sl_dist * 2.0

                if entry > 0 and sl_dist > 0 and verdict_num != 0:
                    sl = round(entry - sl_dist if is_buy else entry + sl_dist, 5)
                    tp = round(entry + tp_dist if is_buy else entry - tp_dist, 5)
                else:
                    sl = 0.0
                    tp = 0.0

                payload: Dict[str, Any] = {
                    **resp,
                    "symbol": symbol,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "source": "mt5_live",
                    "entry": entry,
                    "price": entry,
                    "sl": sl,
                    "tp": tp,
                    "atr": atr,
                    "atr14": atr,
                }
                if _push_verdict(payload):
                    ok_count += 1
                elif not _ai_server_ready():
                    server_lost = True
            except Exception as exc:
                log.error("Erreur %s: %s\n%s", symbol, exc, traceback.format_exc())
    return ok_count


def main() -> None:
    parser = argparse.ArgumentParser(description="GOM Poller 100% MT5 — sans TradingView")
    parser.add_argument("--interval", type=int, default=POLL_INTERVAL,
                        help=f"Intervalle entre polls en secondes (défaut={POLL_INTERVAL})")
    parser.add_argument("--once", action="store_true",
                        help="Un seul calcul puis quitter")
    parser.add_argument("--symbols", type=str, default=None,
                        help="Symboles séparés par virgule (défaut: liste prédéfinie)")
    parser.add_argument("--no-wait-server", action="store_true",
                        help="Ne pas attendre ai_server au démarrage")
    parser.add_argument("--discover", action="store_true",
                        help="Découvre les symboles via l'API MT5 (symbols_get) pour les brokers de --discover-brokers")
    parser.add_argument("--discover-brokers", type=str, default="xmglobal",
                        help="Brokers à découvrir via l'API, séparés par virgule (défaut: xmglobal)")
    args = parser.parse_args()

    symbols = (
        [s.strip() for s in args.symbols.split(",") if s.strip()]
        if args.symbols
        else all_gom_symbols()
    )

    # Buckets broker -> symbols. La découverte isole chaque broker dans son
    # propre terminal, ce qui évite la collision de noms (XMGlobal vs StarTrader).
    buckets = _buckets_by_broker(symbols)
    if args.discover:
        for b in [x.strip() for x in args.discover_brokers.split(",") if x.strip()]:
            try:
                from mt5_candles_fetcher import discover_symbols_via_api
                disc = discover_symbols_via_api(b)
                if disc:
                    buckets.setdefault(b, [])
                    seen = {s.upper() for s in buckets[b]}
                    for s in disc:
                        if s.upper() not in seen:
                            buckets[b].append(s)
                            seen.add(s.upper())
                    log.info("🔎 %s découvert via API : %d symboles", b, len(disc))
            except Exception as exc:
                log.warning("Découverte %s échouée: %s", b, exc)
    symbols_flat = [s for v in buckets.values() for s in v]

    try:
        from gom_live_calculator import GOMSignalsLiveCalculator
        calc = GOMSignalsLiveCalculator()
    except ImportError as exc:
        log.error("gom_live_calculator introuvable: %s", exc)
        sys.exit(1)

    # Vérifier connexion MT5 au démarrage
    try:
        from mt5_candles_fetcher import ensure_mt5_connected, mt5_python_available
        if not mt5_python_available():
            log.error("❌ Package MetaTrader5 absent — pip install MetaTrader5")
            sys.exit(1)
        if ensure_mt5_connected():
            log.info("✅ MT5 connecté")
        else:
            log.warning("⚠️  MT5 non connecté au démarrage — vérifiez que le terminal Deriv est ouvert")
    except ImportError:
        log.warning("mt5_candles_fetcher non disponible — le calcul utilisera les candles uploadées")

    if not args.no_wait_server and not wait_for_ai_server():
        sys.exit(1)

    if args.once:
        n = poll_once(buckets, calc)
        log.info("Terminé — %d/%d succès", n, len(symbols_flat))
        sys.exit(0 if n > 0 else 1)

    log.info("GOM MT5 Poller démarré — %d symboles — intervalle %ds", len(symbols_flat), args.interval)
    log.info("ai_server: %s (fallback Render: %s)", AI_SERVER_URL, AI_SERVER_RENDER_URL)
    log.info("Symboles: %s", ", ".join(symbols_flat))
    log.info("Flux: MT5 Terminal → gom_live_calculator → /gom-verdict → SMC_Universal")
    log.info("(aucune connexion TradingView requise)")

    while True:
        try:
            t0 = time.time()
            n = poll_once(buckets, calc)
            elapsed = time.time() - t0
            log.info("→ %d/%d verdicts pushés (%.1fs)", n, len(symbols), elapsed)
        except KeyboardInterrupt:
            log.info("⏹️ Arrêt")
            break
        except Exception as exc:
            log.error("Erreur boucle: %s\n%s", exc, traceback.format_exc())
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
