#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Session Readiness — Daily Trade Readiness + Circuit-Breaker anti-surtrading
Phases 1 & 2 : analytics journal SQLite + protection pertes consecutives
"""

import os
import sqlite3
import logging
import json
from datetime import datetime, timedelta, timezone
from dataclasses import dataclass, field, asdict
from typing import Optional
from pathlib import Path

logger = logging.getLogger("session_readiness")

# ── Chemin DB ────────────────────────────────────────────────────────────────
_HERE = Path(__file__).parent.parent
DB_PATH = os.getenv("TRADES_DB_PATH", str(_HERE / "data" / "trades.db"))

# ── Circuit-breaker state file ────────────────────────────────────────────────
CB_STATE_FILE = str(_HERE / "data" / "circuit_breaker_state.json")

# ── Thresholds (overridable via env) ─────────────────────────────────────────
CB_CONSECUTIVE_SYMBOL  = int(os.getenv("CB_CONSECUTIVE_SYMBOL",  "3"))   # N pertes d'affilée sur même symbole → cooldown symbole
CB_CONSECUTIVE_GLOBAL  = int(os.getenv("CB_CONSECUTIVE_GLOBAL",  "4"))   # N pertes d'affilée tous symboles → halt global
CB_SESSION_LOSS_USD    = float(os.getenv("CB_SESSION_LOSS_USD",   "0"))   # 0 = désactivé (utiliser % equity)
CB_SESSION_LOSS_PCT    = float(os.getenv("CB_SESSION_LOSS_PCT",   "0"))   # 0 = désactivé par défaut (activer via env: CB_SESSION_LOSS_PCT=5.0)
CB_SYMBOL_COOLDOWN_H   = int(os.getenv("CB_SYMBOL_COOLDOWN_H",   "1"))   # Heures de cooldown symbole
CB_GLOBAL_HALT_H       = int(os.getenv("CB_GLOBAL_HALT_H",       "2"))   # Heures de halt global

# ── Score daily readiness ─────────────────────────────────────────────────────
DR_LOOKBACK_DAYS       = int(os.getenv("DR_LOOKBACK_DAYS",        "30"))
DR_MIN_TRADES_PER_HOUR = int(os.getenv("DR_MIN_TRADES_PER_HOUR",  "3"))
DR_GO_THRESHOLD        = int(os.getenv("DR_GO_THRESHOLD",          "45"))


# ─────────────────────────────────────────────────────────────────────────────
# Helpers DB
# ─────────────────────────────────────────────────────────────────────────────

def _get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, timeout=10)
    conn.row_factory = sqlite3.Row
    return conn


def _db_exists() -> bool:
    return os.path.exists(DB_PATH)


# ─────────────────────────────────────────────────────────────────────────────
# Phase 1 — Analytics journal
# ─────────────────────────────────────────────────────────────────────────────

def get_hourly_stats(symbol: str, lookback_days: int = DR_LOOKBACK_DAYS) -> list[dict]:
    """Win rate et profit par heure UTC pour un symbole."""
    if not _db_exists():
        return []
    try:
        conn = _get_conn()
        rows = conn.execute("""
            SELECT
                hour_utc,
                COUNT(*) AS trades,
                SUM(CASE WHEN result='WIN' THEN 1 ELSE 0 END) AS wins,
                SUM(CASE WHEN result='LOSS' THEN 1 ELSE 0 END) AS losses,
                ROUND(AVG(CASE WHEN result='WIN' THEN 1.0 ELSE 0.0 END) * 100, 1) AS win_rate_pct,
                ROUND(SUM(net_profit), 2) AS total_profit,
                ROUND(AVG(net_profit), 2) AS avg_profit
            FROM trades
            WHERE symbol = ?
              AND result IN ('WIN','LOSS')
              AND trade_date >= date('now', ? || ' days')
            GROUP BY hour_utc
            ORDER BY hour_utc
        """, (symbol, f"-{lookback_days}")).fetchall()
        conn.close()

        # Remplir les heures manquantes avec 0 trades
        by_hour = {r["hour_utc"]: dict(r) for r in rows}
        result = []
        for h in range(24):
            if h in by_hour:
                result.append(by_hour[h])
            else:
                result.append({
                    "hour_utc": h, "trades": 0, "wins": 0, "losses": 0,
                    "win_rate_pct": 0.0, "total_profit": 0.0, "avg_profit": 0.0
                })
        return result
    except Exception as e:
        logger.warning(f"[session_readiness] get_hourly_stats error: {e}")
        return []


def get_dow_stats(symbol: str, lookback_days: int = DR_LOOKBACK_DAYS) -> list[dict]:
    """Win rate par jour de la semaine."""
    if not _db_exists():
        return []
    try:
        conn = _get_conn()
        rows = conn.execute("""
            SELECT
                day_of_week,
                COUNT(*) AS trades,
                SUM(CASE WHEN result='WIN' THEN 1 ELSE 0 END) AS wins,
                ROUND(AVG(CASE WHEN result='WIN' THEN 1.0 ELSE 0.0 END) * 100, 1) AS win_rate_pct,
                ROUND(SUM(net_profit), 2) AS total_profit
            FROM trades
            WHERE symbol = ?
              AND result IN ('WIN','LOSS')
              AND trade_date >= date('now', ? || ' days')
            GROUP BY day_of_week
        """, (symbol, f"-{lookback_days}")).fetchall()
        conn.close()
        return [dict(r) for r in rows]
    except Exception as e:
        logger.warning(f"[session_readiness] get_dow_stats error: {e}")
        return []


def get_symbols_summary(lookback_days: int = DR_LOOKBACK_DAYS) -> list[dict]:
    """Résumé performance par symbole (tous ceux avec >= 5 trades)."""
    if not _db_exists():
        return []
    try:
        conn = _get_conn()
        rows = conn.execute("""
            SELECT
                symbol,
                category,
                COUNT(*) AS trades,
                ROUND(AVG(CASE WHEN result='WIN' THEN 1.0 ELSE 0.0 END) * 100, 1) AS win_rate_pct,
                ROUND(SUM(net_profit), 2) AS net_profit,
                ROUND(AVG(net_profit), 2) AS avg_profit_per_trade,
                MAX(trade_date) AS last_trade_date
            FROM trades
            WHERE result IN ('WIN','LOSS')
              AND trade_date >= date('now', ? || ' days')
            GROUP BY symbol
            HAVING COUNT(*) >= 5
            ORDER BY win_rate_pct DESC
        """, (f"-{lookback_days}",)).fetchall()
        conn.close()
        return [dict(r) for r in rows]
    except Exception as e:
        logger.warning(f"[session_readiness] get_symbols_summary error: {e}")
        return []


def get_best_hours(symbol: str, min_trades: int = DR_MIN_TRADES_PER_HOUR, min_wr: float = 55.0,
                   lookback_days: int = DR_LOOKBACK_DAYS) -> list[int]:
    """Heures UTC où le symbole gagne >= min_wr% avec >= min_trades trades."""
    stats = get_hourly_stats(symbol, lookback_days)
    return [s["hour_utc"] for s in stats if s["trades"] >= min_trades and s["win_rate_pct"] >= min_wr]


def get_avoid_hours(symbol: str, min_trades: int = DR_MIN_TRADES_PER_HOUR, max_wr: float = 40.0,
                    lookback_days: int = DR_LOOKBACK_DAYS) -> list[int]:
    """Heures UTC où le symbole perd (win rate <= max_wr% avec >= min_trades trades)."""
    stats = get_hourly_stats(symbol, lookback_days)
    return [s["hour_utc"] for s in stats if s["trades"] >= min_trades and s["win_rate_pct"] <= max_wr]


def get_recent_trades(symbol: str, n: int = 5) -> list[dict]:
    """Les N derniers trades clôturés sur ce symbole."""
    if not _db_exists():
        return []
    try:
        conn = _get_conn()
        rows = conn.execute("""
            SELECT symbol, result, net_profit, close_time
            FROM trades
            WHERE symbol = ? AND result IN ('WIN','LOSS')
            ORDER BY close_time DESC
            LIMIT ?
        """, (symbol, n)).fetchall()
        conn.close()
        return [dict(r) for r in rows]
    except Exception as e:
        logger.warning(f"[session_readiness] get_recent_trades error: {e}")
        return []


def get_recent_trades_all(n: int = 10) -> list[dict]:
    """Les N derniers trades clôturés tous symboles confondus."""
    if not _db_exists():
        return []
    try:
        conn = _get_conn()
        rows = conn.execute("""
            SELECT symbol, result, net_profit, close_time
            FROM trades
            WHERE result IN ('WIN','LOSS')
            ORDER BY close_time DESC
            LIMIT ?
        """, (n,)).fetchall()
        conn.close()
        return [dict(r) for r in rows]
    except Exception as e:
        logger.warning(f"[session_readiness] get_recent_trades_all error: {e}")
        return []


def get_session_pnl() -> float:
    """PnL de la session courante (depuis 00h00 UTC)."""
    if not _db_exists():
        return 0.0
    try:
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        conn = _get_conn()
        row = conn.execute("""
            SELECT COALESCE(SUM(net_profit), 0.0) AS session_pnl
            FROM trades
            WHERE trade_date = ? AND result IN ('WIN','LOSS')
        """, (today,)).fetchone()
        conn.close()
        return float(row["session_pnl"]) if row else 0.0
    except Exception as e:
        logger.warning(f"[session_readiness] get_session_pnl error: {e}")
        return 0.0


# ─────────────────────────────────────────────────────────────────────────────
# Phase 2 — Circuit-breaker
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class CircuitBreakerState:
    active: bool = False
    reason: str = ""
    triggered_at: Optional[str] = None        # ISO UTC
    resume_at: Optional[str] = None            # ISO UTC
    session_losses_usd: float = 0.0
    consecutive_losses_global: int = 0
    symbol_cooldowns: dict = field(default_factory=dict)  # {symbol: iso_resume_utc}
    last_updated: Optional[str] = None

    def to_dict(self) -> dict:
        return asdict(self)


_cb_state = CircuitBreakerState()


def _load_cb_state():
    global _cb_state
    if os.path.exists(CB_STATE_FILE):
        try:
            with open(CB_STATE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            _cb_state = CircuitBreakerState(**data)
        except Exception as e:
            logger.warning(f"[CB] Cannot load state: {e}")


def _save_cb_state():
    try:
        _cb_state.last_updated = datetime.now(timezone.utc).isoformat()
        os.makedirs(os.path.dirname(CB_STATE_FILE), exist_ok=True)
        with open(CB_STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(_cb_state.to_dict(), f, indent=2)
    except Exception as e:
        logger.warning(f"[CB] Cannot save state: {e}")


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _parse_iso(s: Optional[str]) -> Optional[datetime]:
    if not s:
        return None
    try:
        return datetime.fromisoformat(s)
    except Exception:
        return None


def check_circuit_breaker(symbol: str = "") -> dict:
    """
    Vérifie l'état du circuit-breaker pour un symbole (ou global si symbol="").
    Retourne: { active: bool, reason: str, resume_at: str|None, symbol_cooling: bool }
    """
    _load_cb_state()
    now = _now_utc()

    # Auto-expiry global halt
    if _cb_state.active:
        resume = _parse_iso(_cb_state.resume_at)
        if resume and now >= resume:
            _cb_state.active = False
            _cb_state.reason = ""
            _cb_state.resume_at = None
            _save_cb_state()
            logger.info("[CB] Halt global expiré — reprise automatique")

    # Symbol-level cooldown
    symbol_cooling = False
    symbol_resume_at = None
    if symbol and symbol in _cb_state.symbol_cooldowns:
        sym_resume = _parse_iso(_cb_state.symbol_cooldowns[symbol])
        if sym_resume:
            if now >= sym_resume:
                del _cb_state.symbol_cooldowns[symbol]
                _save_cb_state()
                logger.info(f"[CB] Cooldown {symbol} expiré")
            else:
                symbol_cooling = True
                symbol_resume_at = _cb_state.symbol_cooldowns[symbol]

    return {
        "active": _cb_state.active,
        "reason": _cb_state.reason,
        "resume_at": _cb_state.resume_at,
        "session_losses_usd": _cb_state.session_losses_usd,
        "consecutive_losses_global": _cb_state.consecutive_losses_global,
        "symbol_cooling": symbol_cooling,
        "symbol_resume_at": symbol_resume_at,
        "symbol_cooldowns": dict(_cb_state.symbol_cooldowns),
    }


def record_trade_result(symbol: str, net_profit: float, is_win: bool,
                        account_equity: float = 0.0) -> dict:
    """
    Appelé après chaque clôture de trade.
    Met à jour le circuit-breaker et retourne l'état résultant.
    """
    _load_cb_state()
    now = _now_utc()

    if is_win:
        # Une victoire remet les compteurs à zéro (global seulement)
        _cb_state.consecutive_losses_global = 0
        # On ne libère pas le symbol cooldown ici (on attend l'expiry auto)
        _save_cb_state()
        return check_circuit_breaker(symbol)

    # Perte
    _cb_state.session_losses_usd += abs(net_profit)
    _cb_state.consecutive_losses_global += 1

    # Compteur pertes consécutives par symbole
    sym_key = f"_consec_{symbol}"
    current_sym_consec = _cb_state.symbol_cooldowns.get(sym_key, 0)
    if isinstance(current_sym_consec, int):
        current_sym_consec += 1
        _cb_state.symbol_cooldowns[sym_key] = current_sym_consec
    else:
        # C'est une date ISO → symbole déjà en cooldown
        current_sym_consec = 1
        _cb_state.symbol_cooldowns[sym_key] = 1

    triggered_reason = ""

    # Règle 1 : N pertes consécutives sur le même symbole → cooldown symbole
    if current_sym_consec >= CB_CONSECUTIVE_SYMBOL:
        resume = now + timedelta(hours=CB_SYMBOL_COOLDOWN_H)
        _cb_state.symbol_cooldowns[symbol] = resume.isoformat()
        del _cb_state.symbol_cooldowns[sym_key]  # reset compteur
        triggered_reason = f"symbol_consec_{CB_CONSECUTIVE_SYMBOL}_losses"
        logger.warning(
            f"[CB] SYMBOL COOLDOWN {symbol}: {CB_CONSECUTIVE_SYMBOL} pertes consécutives"
            f" → cooldown {CB_SYMBOL_COOLDOWN_H}h jusqu'à {resume.strftime('%H:%M UTC')}"
        )
        _send_wa_alert(
            f"⛔ CIRCUIT-BREAKER — {symbol}\n"
            f"{CB_CONSECUTIVE_SYMBOL} pertes consécutives sur {symbol}\n"
            f"Cooldown: {CB_SYMBOL_COOLDOWN_H}h | Reprise: {resume.strftime('%H:%M UTC')}"
        )

    # Règle 2 : N pertes consécutives globales → halt global
    if _cb_state.consecutive_losses_global >= CB_CONSECUTIVE_GLOBAL and not _cb_state.active:
        resume = now + timedelta(hours=CB_GLOBAL_HALT_H)
        _cb_state.active = True
        _cb_state.reason = f"global_consec_{CB_CONSECUTIVE_GLOBAL}_losses"
        _cb_state.triggered_at = now.isoformat()
        _cb_state.resume_at = resume.isoformat()
        logger.warning(
            f"[CB] HALT GLOBAL: {CB_CONSECUTIVE_GLOBAL} pertes consécutives"
            f" → halt {CB_GLOBAL_HALT_H}h jusqu'à {resume.strftime('%H:%M UTC')}"
        )
        _send_wa_alert(
            f"🚨 CIRCUIT-BREAKER GLOBAL\n"
            f"{CB_CONSECUTIVE_GLOBAL} pertes consécutives tous symboles\n"
            f"Halt: {CB_GLOBAL_HALT_H}h | Reprise: {resume.strftime('%H:%M UTC')}\n"
            f"Pertes session: ${_cb_state.session_losses_usd:.2f}"
        )

    # Règle 3 : Perte session > seuil USD ou % equity
    session_limit_hit = False
    if CB_SESSION_LOSS_USD > 0 and _cb_state.session_losses_usd >= CB_SESSION_LOSS_USD:
        session_limit_hit = True
    if account_equity > 0 and CB_SESSION_LOSS_PCT > 0:
        pct_lost = (_cb_state.session_losses_usd / account_equity) * 100
        if pct_lost >= CB_SESSION_LOSS_PCT:
            session_limit_hit = True

    if session_limit_hit and not _cb_state.active:
        resume = now + timedelta(hours=CB_GLOBAL_HALT_H)
        _cb_state.active = True
        _cb_state.reason = f"session_loss_limit_${_cb_state.session_losses_usd:.0f}"
        _cb_state.triggered_at = now.isoformat()
        _cb_state.resume_at = resume.isoformat()
        logger.warning(f"[CB] HALT SESSION LOSS: ${_cb_state.session_losses_usd:.2f}")
        _send_wa_alert(
            f"🚨 CIRCUIT-BREAKER SESSION\n"
            f"Perte session: ${_cb_state.session_losses_usd:.2f}\n"
            f"Halt: {CB_GLOBAL_HALT_H}h | Reprise: {resume.strftime('%H:%M UTC')}"
        )

    _save_cb_state()
    return check_circuit_breaker(symbol)


def reset_circuit_breaker(symbol: str = "") -> dict:
    """Reset manuel (via dashboard ou WhatsApp commande)."""
    _load_cb_state()
    if symbol:
        sym_key = f"_consec_{symbol}"
        _cb_state.symbol_cooldowns.pop(symbol, None)
        _cb_state.symbol_cooldowns.pop(sym_key, None)
        logger.info(f"[CB] Reset manuel symbole {symbol}")
    else:
        _cb_state.active = False
        _cb_state.reason = ""
        _cb_state.resume_at = None
        _cb_state.triggered_at = None
        _cb_state.session_losses_usd = 0.0
        _cb_state.consecutive_losses_global = 0
        _cb_state.symbol_cooldowns = {}
        logger.info("[CB] Reset manuel global")
    _save_cb_state()
    return check_circuit_breaker(symbol)


def reset_session_counters():
    """Appelé à chaque début de session (00h00 UTC) pour remettre les compteurs."""
    _load_cb_state()
    _cb_state.session_losses_usd = 0.0
    _cb_state.consecutive_losses_global = 0
    # Garder les cooldowns symbole actifs (ils expirent par TTL)
    # Supprimer les compteurs internes (clés _consec_*)
    keys_to_del = [k for k in _cb_state.symbol_cooldowns if k.startswith("_consec_")]
    for k in keys_to_del:
        del _cb_state.symbol_cooldowns[k]
    # Ne pas réactiver halt global s'il est encore dans la fenêtre
    _save_cb_state()
    logger.info("[CB] Compteurs session remis à zéro (nouvelle session)")


# ─────────────────────────────────────────────────────────────────────────────
# Phase 2 — Daily Readiness score
# ─────────────────────────────────────────────────────────────────────────────

def compute_daily_readiness(symbol: str, current_hour_utc: Optional[int] = None,
                             gom_global_str: int = 0,
                             atr_ratio: float = 1.0,
                             account_equity: float = 0.0) -> dict:
    """
    Score 0-100 indiquant si le symbole est propice à trader maintenant.
    Retourne: { go: bool, score: int, best_hours: list, avoid_hours: list, factors: dict }
    """
    if current_hour_utc is None:
        current_hour_utc = datetime.now(timezone.utc).hour

    factors = {}
    score = 0

    # Facteur 1 — Jour de la semaine (25 pts)
    dow_name = datetime.now(timezone.utc).strftime("%A")  # Monday, Tuesday...
    dow_stats = get_dow_stats(symbol)
    dow_wr = 50.0  # défaut neutre
    dow_trades = 0
    for d in dow_stats:
        if d.get("day_of_week", "").lower() == dow_name.lower():
            dow_wr = d["win_rate_pct"]
            dow_trades = d["trades"]
            break
    if dow_trades >= 5:
        if dow_wr >= 60:   pts = 25
        elif dow_wr >= 50: pts = 15
        elif dow_wr >= 40: pts = 8
        else:               pts = 0
    else:
        pts = 12  # données insuffisantes → neutre
    score += pts
    factors["day_of_week"] = {"value": dow_name, "wr": dow_wr, "trades": dow_trades, "pts": pts}

    # Facteur 2 — Heure courante parmi les meilleures (20 pts)
    best_hours = get_best_hours(symbol)
    avoid_hours = get_avoid_hours(symbol)
    hourly_stats = get_hourly_stats(symbol)
    cur_h_data = next((s for s in hourly_stats if s["hour_utc"] == current_hour_utc), None)
    cur_h_wr = cur_h_data["win_rate_pct"] if cur_h_data else 50.0
    cur_h_trades = cur_h_data["trades"] if cur_h_data else 0

    if current_hour_utc in best_hours:
        h_pts = 20
        h_cat = "best"
    elif current_hour_utc in avoid_hours:
        h_pts = 0
        h_cat = "avoid"
    else:
        h_pts = 10
        h_cat = "neutral"
    score += h_pts
    factors["current_hour"] = {"hour": current_hour_utc, "category": h_cat,
                                "wr": cur_h_wr, "trades": cur_h_trades, "pts": h_pts}

    # Facteur 3 — Performance récente sur ce symbole (20 pts)
    recent = get_recent_trades(symbol, 3)
    wins_recent = sum(1 for t in recent if t["result"] == "WIN")
    if len(recent) >= 3:
        if wins_recent == 3:   r_pts = 20
        elif wins_recent == 2: r_pts = 14
        elif wins_recent == 1: r_pts = 7
        else:                   r_pts = 0
    else:
        r_pts = 10  # pas assez de données → neutre
    score += r_pts
    recent_results = [t["result"] for t in recent]
    factors["recent_performance"] = {"last_n": recent_results, "wins": wins_recent, "pts": r_pts}

    # Facteur 4 — Volatilité relative ATR (15 pts)
    if atr_ratio >= 1.3:   v_pts = 15
    elif atr_ratio >= 1.0: v_pts = 10
    elif atr_ratio >= 0.7: v_pts = 4
    else:                   v_pts = 0
    score += v_pts
    factors["volatility"] = {"atr_ratio": round(atr_ratio, 3), "pts": v_pts}

    # Facteur 5 — Force tendance GOM globale (10 pts)
    if gom_global_str >= 60:   g_pts = 10
    elif gom_global_str >= 35: g_pts = 5
    else:                       g_pts = 0
    score += g_pts
    factors["trend_strength"] = {"gom_global_str": gom_global_str, "pts": g_pts}

    # Facteur 6 — Circuit-breaker / cooldown (10 pts)
    cb = check_circuit_breaker(symbol)
    if cb["active"] or cb["symbol_cooling"]:
        cb_pts = 0
    else:
        # Nombre de pertes consécutives récentes sur ce symbole (depuis journal)
        recent_all = get_recent_trades(symbol, 5)
        consec = 0
        for t in recent_all:
            if t["result"] == "LOSS":
                consec += 1
            else:
                break
        if consec == 0:    cb_pts = 10
        elif consec == 1:  cb_pts = 5
        else:               cb_pts = 0
    score += cb_pts
    factors["loss_cooldown"] = {
        "symbol_cooling": cb["symbol_cooling"],
        "global_halt": cb["active"],
        "pts": cb_pts
    }

    score = min(100, max(0, score))
    go = (score >= DR_GO_THRESHOLD) and (not cb["active"]) and (not cb["symbol_cooling"])

    return {
        "go": go,
        "score": score,
        "threshold": DR_GO_THRESHOLD,
        "best_hours": best_hours,
        "avoid_hours": avoid_hours,
        "circuit_breaker": cb,
        "factors": factors,
        "computed_at": datetime.now(timezone.utc).isoformat(),
    }


def compute_daily_readiness_all(current_hour_utc: Optional[int] = None,
                                 gom_global_str: int = 0,
                                 atr_ratio: float = 1.0) -> dict:
    """Readiness pour tous les symboles avec assez de données."""
    summary = get_symbols_summary()
    result = {}
    for sym_info in summary:
        sym = sym_info["symbol"]
        result[sym] = compute_daily_readiness(sym, current_hour_utc, gom_global_str, atr_ratio)
    return result


# ─────────────────────────────────────────────────────────────────────────────
# WhatsApp alert helper (appelle /notify-whatsapp ou PsychoBot directement)
# ─────────────────────────────────────────────────────────────────────────────

def _send_wa_alert(message: str):
    """Envoie une alerte WhatsApp via PsychoBot."""
    try:
        import requests as req_lib
        psychobot_url = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com")
        phone = os.getenv("WHATSAPP_PHONE") or os.getenv("WHATSAPP_PHONE_NUMBER", "")
        if not phone:
            logger.warning("[CB-WA] WHATSAPP_PHONE non configuré — alerte non envoyée")
            return
        resp = req_lib.post(
            f"{psychobot_url}/send-message",
            json={"phone": phone, "message": message},
            timeout=15,
        )
        logger.info(f"[CB-WA] Alerte envoyée: {resp.status_code}")
    except Exception as e:
        logger.warning(f"[CB-WA] Erreur envoi alerte: {e}")


# Charger l'état au démarrage du module
_load_cb_state()
