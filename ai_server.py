"""
╔══════════════════════════════════════════════════════════════════════════════╗
║          AI_SERVER.PY — Moteur de Décision Trading 360°                     ║
║          Scalping M5/M15 + Swing H1 | Forex & Indices Volatilité            ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""

import asyncio
import websockets
import json
import logging
import uuid
import time
from datetime import datetime, timezone
from dataclasses import dataclass, field, asdict
from typing import Optional
from pathlib import Path
import os
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse

# ─── Configuration ────────────────────────────────────────────────────────────

WS_HOST = "0.0.0.0"
WS_PORT = int(os.environ.get("PORT", 8000))

# --- FastAPI App for Render Health Checks ---
app = FastAPI(title="AI Trading Server")

@app.get("/")
async def root():
    return {"status": "online", "message": "AI Trading Server is running"}

@app.get("/health")
async def health():
    return {"status": "ok"}

LOG_DIR = Path("logs")
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / f"ai_server_{datetime.now().strftime('%Y%m%d')}.log"),
        logging.StreamHandler()
    ]
)
log = logging.getLogger("AI_SERVER")

# ─── Paramètres de risk management ────────────────────────────────────────────

RISK_PARAMS = {
    "scalping_risk_pct"    : 1.0,
    "swing_risk_pct"       : 1.5,
    "max_total_risk_pct"   : 4.0,
    "max_scalp_trades"     : 5,
    "max_swing_trades"     : 3,
    "cooldown_after_sl_min": 15,
    "max_dd_pct_daily"     : 5.0,
    "account_balance"      : 10000.0,   # Modifier selon votre compte
}

SCORE_THRESHOLDS = {
    "scalping": 70,
    "swing"   : 75,
}

# Spread max selon type de symbol
SPREAD_LIMITS = {
    "FOREX_MAJOR"  : 2.0,
    "FOREX_CROSS"  : 3.0,
    "FOREX_EXOTIC" : 5.0,
    "VOLATILITY"   : 0.5,
    "INDEX"        : 1.0,
}


# ─── Dataclasses ──────────────────────────────────────────────────────────────

@dataclass
class TradeSignal:
    signal_id       : str
    timestamp_utc   : str
    symbol          : str
    mode            : str          # SCALPING | SWING
    action          : str          # BUY | SELL | HOLD
    entry_price     : float
    stop_loss       : float
    take_profit_1   : float
    take_profit_2   : float
    take_profit_3   : float
    lot_size        : float
    risk_percent    : float
    risk_reward     : float
    confluence_score: int
    confidence      : str          # HIGH | MEDIUM | LOW
    justification   : list
    invalidation    : str
    expires_in_min  : int

@dataclass
class RejectedSignal:
    signal_id    : str
    timestamp_utc: str
    symbol       : str
    mode         : str
    reason       : str
    score        : int
    details      : list


# ─── Gestionnaire d'état global ───────────────────────────────────────────────

class TradingState:
    def __init__(self):
        self.open_trades      : dict = {}    # symbol -> trade info
        self.daily_pnl        : float = 0.0
        self.daily_sl_count   : int = 0
        self.cooldown_symbols : dict = {}    # symbol -> timestamp fin cooldown
        self.total_risk_pct   : float = 0.0
        self.trade_log        : list = []

    def is_in_cooldown(self, symbol: str) -> bool:
        if symbol in self.cooldown_symbols:
            return time.time() < self.cooldown_symbols[symbol]
        return False

    def add_cooldown(self, symbol: str):
        cd_sec = RISK_PARAMS["cooldown_after_sl_min"] * 60
        self.cooldown_symbols[symbol] = time.time() + cd_sec
        log.info(f"Cooldown activé sur {symbol} pour {RISK_PARAMS['cooldown_after_sl_min']} min")

    def can_open_trade(self, mode: str) -> bool:
        scalp_count = sum(1 for t in self.open_trades.values() if t.get("mode") == "SCALPING")
        swing_count = sum(1 for t in self.open_trades.values() if t.get("mode") == "SWING")

        if mode == "SCALPING" and scalp_count >= RISK_PARAMS["max_scalp_trades"]:
            return False
        if mode == "SWING" and swing_count >= RISK_PARAMS["max_swing_trades"]:
            return False
        if self.total_risk_pct >= RISK_PARAMS["max_total_risk_pct"]:
            return False
        if abs(self.daily_pnl) / RISK_PARAMS["account_balance"] * 100 >= RISK_PARAMS["max_dd_pct_daily"]:
            return False
        return True


state = TradingState()


# ─── Fonctions utilitaires ────────────────────────────────────────────────────

def detect_symbol_type(symbol: str) -> str:
    symbol = symbol.upper()
    volatility_keywords = ["V10", "V25", "V50", "V75", "V100", "BOOM", "CRASH", "STEP", "RANGE"]
    if any(k in symbol for k in volatility_keywords):
        return "VOLATILITY"
    major_pairs = ["EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD", "NZDUSD"]
    if symbol in major_pairs:
        return "FOREX_MAJOR"
    if len(symbol) == 6 and symbol.isalpha():
        return "FOREX_CROSS"
    if any(k in symbol for k in ["SPX", "NAS", "DAX", "DOW", "CAC", "FTSE"]):
        return "INDEX"
    return "FOREX_EXOTIC"


def calculate_lot_size(risk_pct: float, sl_pips: float, symbol_type: str) -> float:
    balance   = RISK_PARAMS["account_balance"]
    risk_usd  = balance * (risk_pct / 100)
    pip_value = 10.0   # valeur pip pour 1 lot standard (approximation)
    if symbol_type == "VOLATILITY":
        pip_value = 0.10
    elif symbol_type == "INDEX":
        pip_value = 1.0
    if sl_pips <= 0:
        return 0.01
    lot = risk_usd / (sl_pips * pip_value)
    lot = round(max(0.01, min(lot, 10.0)), 2)
    return lot


def get_confidence(score: int) -> str:
    if score >= 85:
        return "HIGH"
    elif score >= 75:
        return "MEDIUM"
    return "LOW"


def log_signal(signal: dict, rejected: bool = False):
    fname = f"signals_{datetime.now().strftime('%Y%m%d')}.json"
    fpath = LOG_DIR / fname
    entry = {"type": "REJECTED" if rejected else "ACCEPTED", **signal}
    with open(fpath, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


# ─── Moteur d'analyse SCALPING ────────────────────────────────────────────────

def analyze_scalping(data: dict) -> tuple[str, list, list]:
    """
    Évalue les conditions de scalping sur M5/M15.
    Retourne : (action, justifications, raisons_refus)
    """
    tf_m5  = data.get("timeframes", {}).get("M5", {})
    tf_m15 = data.get("timeframes", {}).get("M15", {})
    tf_h1  = data.get("timeframes", {}).get("H1", {})
    meta   = data.get("meta", {})
    score  = meta.get("confluence_score", 0)

    buy_conditions  = []
    sell_conditions = []
    rejections      = []

    # ── Biais H1 ──────────────────────────────────────────────────────────────
    h1_bias = tf_h1.get("ema_alignment", "")
    if h1_bias == "BULLISH_STACK":
        buy_conditions.append(f"Biais H1 BULLISH (EMA stack haussier)")
    elif h1_bias == "BEARISH_STACK":
        sell_conditions.append(f"Biais H1 BEARISH (EMA stack baissier)")
    else:
        rejections.append(f"Biais H1 ambigu ({h1_bias}) — pas de direction claire")

    # ── Alignement EMA M15 ────────────────────────────────────────────────────
    m15_align = tf_m15.get("ema_alignment", "")
    if m15_align == "BULLISH_STACK":
        buy_conditions.append("EMA 8>21>50 sur M15 (stack haussier confirmé)")
    elif m15_align == "BEARISH_STACK":
        sell_conditions.append("EMA 8<21<50 sur M15 (stack baissier confirmé)")
    else:
        rejections.append(f"Alignement EMA M15 non idéal ({m15_align})")

    # ── Prix vs EMA21 M5 ──────────────────────────────────────────────────────
    price_vs_ema21 = tf_m5.get("price_vs_ema21", "")
    if price_vs_ema21 == "ABOVE":
        buy_conditions.append("Prix au-dessus EMA21 M5 (momentum local haussier)")
    elif price_vs_ema21 == "BELOW":
        sell_conditions.append("Prix sous EMA21 M5 (momentum local baissier)")

    # ── RSI M5 ────────────────────────────────────────────────────────────────
    rsi_m5 = tf_m5.get("rsi_14", 50)
    if 40 <= rsi_m5 <= 65:
        buy_conditions.append(f"RSI M5 = {rsi_m5:.1f} (zone favorable BUY)")
    elif 35 <= rsi_m5 <= 60:
        sell_conditions.append(f"RSI M5 = {rsi_m5:.1f} (zone favorable SELL)")
    elif rsi_m5 > 70:
        rejections.append(f"RSI M5 suracheté ({rsi_m5:.1f}) — risque retournement")
    elif rsi_m5 < 30:
        rejections.append(f"RSI M5 survendu ({rsi_m5:.1f}) — risque retournement")

    # ── MACD M5 ───────────────────────────────────────────────────────────────
    macd_hist = tf_m5.get("macd_hist", 0)
    macd_cross = tf_m5.get("macd_cross", "")
    if macd_hist > 0 or "BULLISH" in macd_cross:
        buy_conditions.append(f"MACD M5 haussier (hist={macd_hist:.5f}, cross={macd_cross})")
    elif macd_hist < 0 or "BEARISH" in macd_cross:
        sell_conditions.append(f"MACD M5 baissier (hist={macd_hist:.5f})")

    # ── Bougie de trigger M5 ──────────────────────────────────────────────────
    candle = tf_m5.get("candle_type", "")
    candle_confirm = tf_m5.get("candle_confirmation", False)
    bullish_candles = ["PIN_BAR_BULLISH", "ENGULFING_BULLISH", "HAMMER", "MORNING_STAR"]
    bearish_candles = ["PIN_BAR_BEARISH", "ENGULFING_BEARISH", "SHOOTING_STAR", "EVENING_STAR"]
    if candle in bullish_candles and candle_confirm:
        buy_conditions.append(f"Bougie trigger BUY : {candle} confirmée")
    elif candle in bearish_candles and candle_confirm:
        sell_conditions.append(f"Bougie trigger SELL : {candle} confirmée")
    else:
        rejections.append(f"Pas de bougie trigger confirmée (type={candle})")

    # ── Proximité S/R ─────────────────────────────────────────────────────────
    atr_m15 = tf_m15.get("atr_14_pips", 10)
    dist_sup = tf_m5.get("dist_to_support_pips", 999)
    dist_res = tf_m5.get("dist_to_resist_pips", 999)
    if dist_sup <= atr_m15:
        buy_conditions.append(f"Prix proche support ({dist_sup:.1f} pips ≤ 1×ATR)")
    if dist_res <= atr_m15:
        sell_conditions.append(f"Prix proche résistance ({dist_res:.1f} pips ≤ 1×ATR)")

    # ── Score global ──────────────────────────────────────────────────────────
    if score < SCORE_THRESHOLDS["scalping"]:
        rejections.append(f"Score confluence insuffisant ({score} < {SCORE_THRESHOLDS['scalping']})")

    # ── Session ───────────────────────────────────────────────────────────────
    session = data.get("session", "")
    good_sessions = ["LONDON", "NEW_YORK", "LONDON_NY_OVERLAP"]
    if not any(s in session for s in good_sessions):
        rejections.append(f"Session non premium ({session})")
    else:
        buy_conditions.append(f"Session active : {session}")
        sell_conditions.append(f"Session active : {session}")

    # ── News risk ─────────────────────────────────────────────────────────────
    news = data.get("news_risk", "NONE")
    if news == "HIGH":
        rejections.append("News HIGH imminente — trading suspendu")

    # ── Décision finale ───────────────────────────────────────────────────────
    if rejections:
        return "HOLD", [], rejections

    buy_score  = len(buy_conditions)
    sell_score = len(sell_conditions)

    if buy_score >= 5 and buy_score > sell_score:
        return "BUY", buy_conditions, []
    elif sell_score >= 5 and sell_score > buy_score:
        return "SELL", sell_conditions, []
    else:
        return "HOLD", [], [f"Conditions insuffisantes (BUY={buy_score}, SELL={sell_score})"]


# ─── Moteur d'analyse SWING ───────────────────────────────────────────────────

def analyze_swing(data: dict) -> tuple[str, list, list]:
    """
    Évalue les conditions de swing trading sur H1.
    Retourne : (action, justifications, raisons_refus)
    """
    tf_h1  = data.get("timeframes", {}).get("H1", {})
    tf_h4  = data.get("timeframes", {}).get("H4", {})
    tf_d1  = data.get("timeframes", {}).get("D1", {})
    meta   = data.get("meta", {})
    score  = meta.get("confluence_score", 0)

    buy_conditions  = []
    sell_conditions = []
    rejections      = []

    # ── Tendance D1 ───────────────────────────────────────────────────────────
    d1_align = tf_d1.get("ema_alignment", "")
    if d1_align == "BULLISH_STACK":
        buy_conditions.append("Tendance D1 BULLISH (EMA50 D1 montante)")
    elif d1_align == "BEARISH_STACK":
        sell_conditions.append("Tendance D1 BEARISH (EMA50 D1 descendante)")
    else:
        rejections.append(f"Tendance D1 non définie ({d1_align})")

    # ── Structure H4 ──────────────────────────────────────────────────────────
    h4_phase = tf_h4.get("market_phase", data.get("market_phase", ""))
    structure = meta.get("market_structure", "")
    if "HH_HL" in structure or h4_phase == "TRENDING_UP":
        buy_conditions.append(f"Structure H4 haussière (HH+HL confirmés)")
    elif "LL_LH" in structure or h4_phase == "TRENDING_DOWN":
        sell_conditions.append(f"Structure H4 baissière (LL+LH confirmés)")
    else:
        rejections.append(f"Structure H4 ambiguë ({structure})")

    # ── Retracement Fibonacci H1 ──────────────────────────────────────────────
    close_h1  = tf_h1.get("close", 0)
    fib_382   = tf_h1.get("fib_382", 0)
    fib_618   = tf_h1.get("fib_618", 0)
    if fib_382 and fib_618:
        fib_low  = min(fib_382, fib_618)
        fib_high = max(fib_382, fib_618)
        if fib_low <= close_h1 <= fib_high:
            buy_conditions.append(f"Prix en zone Fib 38.2-61.8% (retracement ideal)")
            sell_conditions.append(f"Prix en zone Fib 38.2-61.8% (retracement ideal)")
        else:
            rejections.append(f"Prix hors zone Fib (close={close_h1}, zone={fib_low:.5f}-{fib_high:.5f})")

    # ── RSI H1 ────────────────────────────────────────────────────────────────
    rsi_h1 = tf_h1.get("rsi_14", 50)
    if 40 <= rsi_h1 <= 60:
        buy_conditions.append(f"RSI H1 = {rsi_h1:.1f} (zone neutre-haussière)")
        sell_conditions.append(f"RSI H1 = {rsi_h1:.1f} (zone neutre-baissière)")
    else:
        rejections.append(f"RSI H1 hors zone optimale ({rsi_h1:.1f})")

    # ── MACD H1 ───────────────────────────────────────────────────────────────
    macd_cross_h1 = tf_h1.get("macd_cross", "")
    rsi_div = tf_h1.get("rsi_divergence", None)
    if "BULLISH" in macd_cross_h1 or rsi_div == "BULLISH":
        buy_conditions.append(f"MACD H1 haussier ou divergence RSI bullish")
    elif "BEARISH" in macd_cross_h1 or rsi_div == "BEARISH":
        sell_conditions.append(f"MACD H1 baissier ou divergence RSI bearish")

    # ── ADX H1 ────────────────────────────────────────────────────────────────
    adx_h1 = tf_h1.get("adx_14", 0)
    if adx_h1 >= 20:
        buy_conditions.append(f"ADX H1 = {adx_h1:.1f} (tendance présente)")
        sell_conditions.append(f"ADX H1 = {adx_h1:.1f} (tendance présente)")
    else:
        rejections.append(f"ADX H1 trop faible ({adx_h1:.1f} < 20) — marché en range")

    # ── Bougie de confirmation H1 ─────────────────────────────────────────────
    candle_h1     = tf_h1.get("candle_type", "")
    candle_ok_h1  = tf_h1.get("candle_confirmation", False)
    bullish_c = ["PIN_BAR_BULLISH", "ENGULFING_BULLISH", "HAMMER", "MORNING_STAR"]
    bearish_c = ["PIN_BAR_BEARISH", "ENGULFING_BEARISH", "SHOOTING_STAR", "EVENING_STAR"]
    if candle_h1 in bullish_c and candle_ok_h1:
        buy_conditions.append(f"Bougie confirmation H1 : {candle_h1}")
    elif candle_h1 in bearish_c and candle_ok_h1:
        sell_conditions.append(f"Bougie confirmation H1 : {candle_h1}")
    else:
        rejections.append(f"Pas de bougie de confirmation H1 ({candle_h1})")

    # ── Score ─────────────────────────────────────────────────────────────────
    if score < SCORE_THRESHOLDS["swing"]:
        rejections.append(f"Score insuffisant pour swing ({score} < {SCORE_THRESHOLDS['swing']})")

    # ── News ──────────────────────────────────────────────────────────────────
    if data.get("news_risk") == "HIGH":
        rejections.append("News HIGH — trading swing suspendu")

    # ── Décision ──────────────────────────────────────────────────────────────
    if rejections:
        return "HOLD", [], rejections

    buy_score  = len(buy_conditions)
    sell_score = len(sell_conditions)

    if buy_score >= 5 and buy_score > sell_score:
        return "BUY", buy_conditions, []
    elif sell_score >= 5 and sell_score > buy_score:
        return "SELL", sell_conditions, []
    else:
        return "HOLD", [], [f"Conditions swing insuffisantes (BUY={buy_score}, SELL={sell_score})"]


# ─── Construction du signal complet ──────────────────────────────────────────

def build_signal(data: dict, action: str, mode: str, justifications: list) -> TradeSignal:
    symbol      = data.get("symbol", "UNKNOWN")
    symbol_type = detect_symbol_type(symbol)
    score       = data.get("meta", {}).get("confluence_score", 70)

    tf_key      = "M5" if mode == "SCALPING" else "H1"
    tf_ref      = data.get("timeframes", {}).get(tf_key, {})
    tf_m15      = data.get("timeframes", {}).get("M15", {})

    entry = tf_ref.get("close", 0)
    atr   = tf_ref.get("atr_14_pips", 10)

    # ── SL / TP ───────────────────────────────────────────────────────────────
    sl_multiplier = 1.0 if mode == "SCALPING" else 1.5
    sl_pips       = atr * sl_multiplier

    sl_min = {"FOREX_MAJOR": 8, "FOREX_CROSS": 15, "FOREX_EXOTIC": 20,
              "VOLATILITY": 10, "INDEX": 15}.get(symbol_type, 10)
    sl_pips = max(sl_pips, sl_min)

    # Point value (approximation 4 décimales forex)
    pip_val = 0.0001 if symbol_type not in ["VOLATILITY", "INDEX"] else 0.01

    if action == "BUY":
        sl  = entry - sl_pips * pip_val
        tp1 = entry + sl_pips * 1.5 * pip_val
        tp2 = tf_ref.get("nearest_resist", entry + sl_pips * 2.0 * pip_val)
        tp3 = entry + sl_pips * 3.0 * pip_val
        invalidation = f"Clôture {tf_key} sous {sl:.5f} annule le setup"
    else:
        sl  = entry + sl_pips * pip_val
        tp1 = entry - sl_pips * 1.5 * pip_val
        tp2 = tf_ref.get("nearest_support", entry - sl_pips * 2.0 * pip_val)
        tp3 = entry - sl_pips * 3.0 * pip_val
        invalidation = f"Clôture {tf_key} au-dessus {sl:.5f} annule le setup"

    rr = abs(tp1 - entry) / abs(sl - entry) if abs(sl - entry) > 0 else 0

    # ── Lot size ──────────────────────────────────────────────────────────────
    risk_pct = RISK_PARAMS["scalping_risk_pct"] if mode == "SCALPING" else RISK_PARAMS["swing_risk_pct"]
    lot      = calculate_lot_size(risk_pct, sl_pips, symbol_type)

    expires = 15 if mode == "SCALPING" else 240

    return TradeSignal(
        signal_id        = str(uuid.uuid4()),
        timestamp_utc    = datetime.now(timezone.utc).isoformat(),
        symbol           = symbol,
        mode             = mode,
        action           = action,
        entry_price      = round(entry, 5),
        stop_loss        = round(sl, 5),
        take_profit_1    = round(tp1, 5),
        take_profit_2    = round(tp2, 5) if tp2 else round(tp1 * 1.5, 5),
        take_profit_3    = round(tp3, 5),
        lot_size         = lot,
        risk_percent     = risk_pct,
        risk_reward      = round(rr, 2),
        confluence_score = score,
        confidence       = get_confidence(score),
        justification    = justifications,
        invalidation     = invalidation,
        expires_in_min   = expires,
    )


# ─── Traitement principal d'un message entrant ────────────────────────────────

async def process_analysis(data: dict) -> dict:
    symbol = data.get("symbol", "UNKNOWN")
    score  = data.get("meta", {}).get("confluence_score", 0)

    log.info(f"Analyse reçue → {symbol} | score={score} | phase={data.get('market_phase')}")

    # Vérifications préalables globales
    if state.is_in_cooldown(symbol):
        reason = f"{symbol} en cooldown post-SL"
        log.warning(reason)
        rej = RejectedSignal(str(uuid.uuid4()), datetime.now(timezone.utc).isoformat(),
                             symbol, "ALL", reason, score, [])
        log_signal(asdict(rej), rejected=True)
        return {"status": "REJECTED", "reason": reason}

    # Vérifier filtres meta
    meta = data.get("meta", {})
    if not meta.get("spread_filter_ok", True):
        reason = "Spread trop élevé — filtre activé"
        log.warning(f"{symbol}: {reason}")
        return {"status": "REJECTED", "reason": reason}

    results = []

    # ── Analyse SCALPING ──────────────────────────────────────────────────────
    if state.can_open_trade("SCALPING"):
        s_action, s_just, s_rej = analyze_scalping(data)
        if s_action != "HOLD":
            signal = build_signal(data, s_action, "SCALPING", s_just)
            result = asdict(signal)
            result["status"] = "SIGNAL"
            log_signal(result)
            log.info(f"✅ SCALPING {s_action} généré pour {symbol} (R:R={signal.risk_reward})")
            results.append(result)
        else:
            log.info(f"SCALPING HOLD {symbol}: {'; '.join(s_rej[:2])}")

    # ── Analyse SWING ─────────────────────────────────────────────────────────
    if state.can_open_trade("SWING"):
        sw_action, sw_just, sw_rej = analyze_swing(data)
        if sw_action != "HOLD":
            signal = build_signal(data, sw_action, "SWING", sw_just)
            result = asdict(signal)
            result["status"] = "SIGNAL"
            log_signal(result)
            log.info(f"✅ SWING {sw_action} généré pour {symbol} (R:R={signal.risk_reward})")
            results.append(result)
        else:
            log.info(f"SWING HOLD {symbol}: {'; '.join(sw_rej[:2])}")

    if results:
        return {"status": "SIGNALS", "count": len(results), "signals": results}
    return {"status": "HOLD", "symbol": symbol, "score": score}


# ─── Serveur WebSocket ────────────────────────────────────────────────────────

async def handler(websocket):
    client_addr = websocket.remote_address
    log.info(f"Connexion entrante : {client_addr}")

    async for message in websocket:
        try:
            data   = json.loads(message)
            result = await process_analysis(data)
            await websocket.send(json.dumps(result, ensure_ascii=False))

        except json.JSONDecodeError as e:
            err = {"status": "ERROR", "message": f"JSON invalide: {e}"}
            await websocket.send(json.dumps(err))
            log.error(f"JSON invalide reçu de {client_addr}: {e}")

        except Exception as e:
            err = {"status": "ERROR", "message": str(e)}
            await websocket.send(json.dumps(err))
            log.exception(f"Erreur traitement pour {client_addr}")

    log.info(f"Déconnexion : {client_addr}")

@app.websocket("/")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    client_addr = websocket.client
    log.info(f"WebSocket connectée : {client_addr}")
    try:
        while True:
            message = await websocket.receive_text()
            try:
                data = json.loads(message)
                result = await process_analysis(data)
                await websocket.send_text(json.dumps(result, ensure_ascii=False))
            except json.JSONDecodeError as e:
                err = {"status": "ERROR", "message": f"JSON invalide: {e}"}
                await websocket.send_text(json.dumps(err))
                log.error(f"JSON invalide reçu de {client_addr}: {e}")
            except Exception as e:
                err = {"status": "ERROR", "message": str(e)}
                await websocket.send_text(json.dumps(err))
                log.exception(f"Erreur traitement pour {client_addr}")
    except WebSocketDisconnect:
        log.info(f"WebSocket déconnectée : {client_addr}")

async def main():
    log.info(f"╔══ AI Trading Server démarré ══╗")
    log.info(f"║  Host    : {WS_HOST}:{WS_PORT}")
    log.info(f"║  Balance : {RISK_PARAMS['account_balance']} USD")
    log.info(f"║  Risk/T  : {RISK_PARAMS['scalping_risk_pct']}% scalp / {RISK_PARAMS['swing_risk_pct']}% swing")
    log.info(f"╚═══════════════════════════════╝")
    
    # En local, on peut encore utiliser websockets.serve si lancé via python ai_server.py
    # Mais sur Render, c'est uvicorn qui gère tout via 'app'
    async with websockets.serve(handler, WS_HOST, WS_PORT):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
