"""
gold_scalper.py — Scalping automatique XAUUSD via Deriv WebSocket
- Prix en temps réel toutes les 3 minutes
- Prédiction direction (momentum + EMA + RSI)
- Envoi ordre LIMIT au serveur IA → SMC_Universal exécute
- TradeManager gère le trailing stop
"""
import asyncio
import json
import time
import logging
import statistics
import os
from datetime import datetime
from collections import deque

import httpx
import websockets

# ── Configuration ────────────────────────────────────────────────────
AI_SERVER      = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000")
DERIV_APP_ID   = os.getenv("DERIV_APP_ID", "1089")
DERIV_WS       = f"wss://ws.derivws.com/websockets/v3?app_id={DERIV_APP_ID}"
SYMBOL_DERIV   = "frxXAUUSD"
SYMBOL_MT5     = "XAUUSD"

CHECK_INTERVAL = 180       # secondes entre chaque analyse (3 min)
TICK_WINDOW    = 60        # nombre de ticks à conserver pour analyse
SL_PIPS        = 8.0       # SL serré scalping (8 USD = ~8 pips sur XAUUSD)
TP_PIPS        = 16.0      # TP = RR 1:2
LOT            = 0.01
MIN_CONFIDENCE = 0.70      # seuil minimum relevé (était 0.55)
COOLDOWN_SEC   = 900       # 15 min entre deux ordres (était 5 min)
ATR_RANGE_MAX  = 3.0       # si ATR M1 < X USD → range, skip le trade
ATR_WINDOW     = 20        # nombre de ticks pour calculer l'ATR

# ── Logging ─────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [Scalper] %(message)s",
    datefmt="%H:%M:%S"
)
log = logging.getLogger("gold_scalper")

# ── State ────────────────────────────────────────────────────────────
ticks       = deque(maxlen=TICK_WINDOW)
last_order  = 0.0
order_count = 0

# ── Analyse technique légère ─────────────────────────────────────────
def ema(prices: list, period: int) -> float:
    if len(prices) < period:
        return prices[-1] if prices else 0
    k = 2 / (period + 1)
    result = prices[0]
    for p in prices[1:]:
        result = p * k + result * (1 - k)
    return result

def rsi(prices: list, period: int = 14) -> float:
    if len(prices) < period + 1:
        return 50.0
    gains, losses = [], []
    for i in range(1, period + 1):
        diff = prices[-i] - prices[-i-1]
        if diff > 0:
            gains.append(diff)
        else:
            losses.append(abs(diff))
    avg_gain = statistics.mean(gains) if gains else 0.001
    avg_loss = statistics.mean(losses) if losses else 0.001
    rs = avg_gain / avg_loss
    return 100 - (100 / (1 + rs))

def calc_atr(prices: list, window: int = ATR_WINDOW) -> float:
    """ATR simplifié sur les derniers ticks — mesure la volatilité."""
    if len(prices) < window + 1:
        return 999.0
    ranges = [abs(prices[i] - prices[i-1]) for i in range(-window, 0)]
    return sum(ranges) / len(ranges) * 100  # en USD approximatif

def predict_direction(prices: list) -> tuple[str, float]:
    """
    Retourne (direction, confidence) basé sur :
    - Détection range (ATR faible → NEUTRAL)
    - Momentum 5 ticks vs 15 ticks
    - EMA9 vs EMA21
    - RSI
    """
    if len(prices) < 25:
        return "NEUTRAL", 0.0

    # Détection range — si marché trop calme, pas de scalp
    atr_now = calc_atr(prices)
    if atr_now < ATR_RANGE_MAX:
        return "NEUTRAL", 0.0  # range → skip

    ema9  = ema(prices, 9)
    ema21 = ema(prices, 21)
    rsi14 = rsi(prices, 14)

    # Momentum : pente des 5 derniers ticks
    recent  = prices[-5:]
    older   = prices[-15:-10]
    mom_recent = (recent[-1] - recent[0]) / max(recent[0], 0.01) * 100
    mom_older  = (older[-1]  - older[0])  / max(older[0],  0.01) * 100

    signals = []

    # EMA signal
    if ema9 > ema21:
        signals.append(("BUY", 0.3))
    elif ema9 < ema21:
        signals.append(("SELL", 0.3))

    # RSI signal
    if rsi14 < 40:
        signals.append(("BUY", 0.25))
    elif rsi14 > 60:
        signals.append(("SELL", 0.25))
    elif rsi14 < 45:
        signals.append(("BUY", 0.1))
    elif rsi14 > 55:
        signals.append(("SELL", 0.1))

    # Momentum signal
    if mom_recent > 0.01:
        signals.append(("BUY", 0.25))
    elif mom_recent < -0.01:
        signals.append(("SELL", 0.25))

    # Momentum acceleration
    if mom_recent > mom_older and mom_recent > 0:
        signals.append(("BUY", 0.2))
    elif mom_recent < mom_older and mom_recent < 0:
        signals.append(("SELL", 0.2))

    if not signals:
        return "NEUTRAL", 0.0

    buy_score  = sum(w for d, w in signals if d == "BUY")
    sell_score = sum(w for d, w in signals if d == "SELL")
    total      = buy_score + sell_score

    if buy_score > sell_score:
        conf = buy_score / total if total > 0 else 0
        return "BUY", round(conf, 2)
    elif sell_score > buy_score:
        conf = sell_score / total if total > 0 else 0
        return "SELL", round(conf, 2)
    return "NEUTRAL", 0.0

# ── Vérifier biais serveur ────────────────────────────────────────────
async def get_server_bias() -> tuple[str, float]:
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(f"{AI_SERVER}/session-bias?symbol={SYMBOL_MT5}")
            if r.status_code == 200:
                data = r.json().get("data", {})
                if data.get("valid"):
                    return data.get("direction", "NEUTRAL"), data.get("confidence", 0.0)
    except Exception:
        pass
    return "NEUTRAL", 0.0

# ── Envoyer ordre au serveur ──────────────────────────────────────────
async def send_order(direction: str, price: float, confidence: float):
    global last_order, order_count

    sl = price + SL_PIPS if direction == "SELL" else price - SL_PIPS
    tp = price - TP_PIPS if direction == "SELL" else price + TP_PIPS

    payload = {
        "symbol":         SYMBOL_MT5,
        "recommendation": direction,
        "action":         direction,
        "entry_price":    round(price, 2),
        "stop_loss":      round(sl, 2),
        "take_profit":    round(tp, 2),
        "lot":            LOT,
        "execution_type": "limit",
        "confidence":     confidence,
        "reasoning":      f"Scalper auto | RSI+EMA+Momentum | conf={confidence:.0%}"
    }

    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.post(
                f"{AI_SERVER}/tradingagents/manual-report",
                json=payload
            )
            if r.status_code == 200:
                last_order  = time.time()
                order_count += 1
                log.info(f"✅ Ordre #{order_count} {direction} LIMIT @ {price:.2f} | SL={sl:.2f} TP={tp:.2f} | conf={confidence:.0%}")
                return True
            else:
                log.warning(f"Ordre refusé: {r.status_code} {r.text}")
    except Exception as e:
        log.error(f"Erreur envoi ordre: {e}")
    return False

# ── Boucle principale ─────────────────────────────────────────────────
async def scalping_loop():
    log.info(f"Scalper démarré — analyse toutes les {CHECK_INTERVAL}s | SL={SL_PIPS}$ TP={TP_PIPS}$")

    while True:
        try:
            # Collecter les ticks pendant CHECK_INTERVAL secondes
            async with websockets.connect(DERIV_WS, open_timeout=10) as ws:
                await ws.send(json.dumps({"ticks": SYMBOL_DERIV, "subscribe": 1}))
                log.info("Connecté Deriv WebSocket — collecte ticks...")

                start = time.time()
                last_analysis = time.time()

                while True:
                    try:
                        msg = json.loads(await asyncio.wait_for(ws.recv(), timeout=30))
                    except asyncio.TimeoutError:
                        log.warning("Timeout tick — reconnexion")
                        break

                    if msg.get("msg_type") == "tick":
                        tick_data = msg.get("tick", {})
                        price = tick_data.get("quote") or tick_data.get("bid")
                        if price:
                            ticks.append(float(price))

                    # Analyse toutes les CHECK_INTERVAL secondes
                    now = time.time()
                    if now - last_analysis >= CHECK_INTERVAL:
                        last_analysis = now
                        prices = list(ticks)
                        current_price = prices[-1] if prices else 0

                        if len(prices) < 20:
                            log.info(f"Pas assez de données ({len(prices)} ticks)")
                            continue

                        # Prédiction locale
                        direction, confidence = predict_direction(prices)

                        # Biais serveur
                        server_dir, server_conf = await get_server_bias()

                        log.info(
                            f"Prix={current_price:.2f} | "
                            f"Local={direction}({confidence:.0%}) | "
                            f"Server={server_dir}({server_conf:.0%})"
                        )

                        # Alignement local + serveur
                        if direction == "NEUTRAL":
                            log.info("Signal NEUTRAL — pas d'ordre")
                            continue

                        # Boost confiance si serveur aligne
                        final_conf = confidence
                        if server_dir == "NEUTRAL":
                            # Biais expiré ou indéterminé → skip (évite les erreurs envoi)
                            log.info("Biais serveur NEUTRAL — skip (biais expiré ou indisponible)")
                            continue
                        elif server_dir == direction and server_conf > 0:
                            final_conf = min(0.95, confidence + server_conf * 0.3)
                            log.info(f"Biais serveur aligne → confiance boostée {confidence:.0%} → {final_conf:.0%}")
                        elif server_dir != direction and server_conf > 0.6:
                            log.info(f"Biais serveur OPPOSE ({server_dir}) — ordre bloqué")
                            continue

                        if final_conf < MIN_CONFIDENCE:
                            log.info(f"Confiance {final_conf:.0%} < {MIN_CONFIDENCE:.0%} — skip")
                            continue

                        # Cooldown
                        if time.time() - last_order < COOLDOWN_SEC:
                            remaining = int(COOLDOWN_SEC - (time.time() - last_order))
                            log.info(f"Cooldown {remaining}s")
                            continue

                        # Envoyer l'ordre
                        await send_order(direction, current_price, final_conf)

        except Exception as e:
            log.error(f"Erreur connexion: {e} — retry dans 10s")
            await asyncio.sleep(10)

if __name__ == "__main__":
    asyncio.run(scalping_loop())
