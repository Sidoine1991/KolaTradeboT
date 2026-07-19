"""
XAUUSD WhatsApp Monitor v2 — Analyse croisée TradingAgents × GOM KOLA
======================================================================

Envoie toutes les 20 min une analyse complète :
- Prix live Deriv
- Verdict GOM KOLA (OB, CHoCH, Fibo, Spike, Supertrend, BB, VWAP)
- Biais session AI server
- Pending order actif
- Confluence / conflit détecté
- Alertes critiques sur changements d'état

Usage:
    python xauusd_whatsapp_monitor.py --phone "+2290196911346" --interval 1200
"""

import asyncio
import json
import sys
import io
import time
import logging
import argparse
from datetime import datetime
from typing import Optional, Dict, Any

import requests
import websockets
try:
    import ssl_patch  # noqa: F401 — SSL Windows fix
except ImportError:
    pass

# ─────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────
WHATSAPP_API_URL = "https://psychobot-1si7.onrender.com"
AI_SERVER_URL    = "http://127.0.0.1:8000"
DERIV_WS_URL     = "wss://ws.derivws.com/websockets/v3?app_id=1089"
SYMBOL           = "XAUUSD"

# Fix Windows console encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("xauusd_monitor.log", encoding="utf-8"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)

# État global
last_price:  Optional[float]       = None
last_bias:   Optional[Dict]        = None
last_gom:    Optional[Dict]        = None
last_order:  Optional[Dict]        = None
alerts_sent: set                   = set()


# ─────────────────────────────────────────────────────────────
# Récupération données
# ─────────────────────────────────────────────────────────────

async def get_live_price() -> Optional[float]:
    try:
        async with websockets.connect(DERIV_WS_URL, open_timeout=15) as ws:
            await ws.send(json.dumps({"ticks": "frxXAUUSD"}))
            for _ in range(20):
                try:
                    msg = json.loads(await asyncio.wait_for(ws.recv(), 10))
                    price = msg.get("tick", {}).get("quote")
                    if price:
                        return float(price)
                except asyncio.TimeoutError:
                    continue
        return None
    except Exception as e:
        logger.error(f"❌ Prix: {type(e).__name__} — {e}")
        return None


def get_session_bias() -> Optional[Dict]:
    try:
        r = requests.get(f"{AI_SERVER_URL}/session-bias", params={"symbol": SYMBOL}, timeout=15)
        if r.status_code == 200:
            return r.json().get("data")
        return None
    except Exception as e:
        logger.error(f"❌ Biais: {e}")
        return None


def get_gom_verdict() -> Optional[Dict]:
    try:
        r = requests.get(f"{AI_SERVER_URL}/gom-verdict", params={"symbol": SYMBOL}, timeout=15)
        if r.status_code == 200 and r.json().get("ok"):
            return r.json()
        return None
    except Exception as e:
        logger.error(f"❌ GOM verdict: {e}")
        return None


def get_pending_order() -> Optional[Dict]:
    try:
        r = requests.get(f"{AI_SERVER_URL}/pending-order", params={"symbol": SYMBOL}, timeout=15)
        if r.status_code == 200 and r.json().get("ok"):
            return r.json().get("order")
        return None
    except Exception as e:
        logger.error(f"❌ Pending order: {e}")
        return None


def get_ta_report_status() -> Optional[Dict]:
    try:
        r = requests.get(f"{AI_SERVER_URL}/tradingagents/report-status", params={"symbol": SYMBOL}, timeout=15)
        if r.status_code == 200:
            return r.json()
        return None
    except Exception as e:
        logger.error(f"❌ TA report status: {e}")
        return None


# ─────────────────────────────────────────────────────────────
# Envoi WhatsApp
# ─────────────────────────────────────────────────────────────

def send_whatsapp(phone: str, message: str) -> bool:
    alert_file = "whatsapp_alerts.log"
    ts = datetime.utcnow().strftime("%H:%M UTC")
    full_msg = f"📊 TradBOT [{ts}]\n\n{message}"
    try:
        with open(alert_file, "a", encoding="utf-8") as f:
            f.write(f"\n{'='*60}\n{datetime.utcnow().isoformat()}\n{full_msg}\n")
        r = requests.post(
            f"{WHATSAPP_API_URL}/send-message",
            json={"phone": phone, "message": full_msg},
            timeout=30,
        )
        if r.status_code == 200 and r.json().get("success"):
            logger.info(f"✅ WhatsApp envoyé")
            return True
        logger.error(f"❌ PsychoBot: {r.text}")
        return False
    except Exception as e:
        logger.error(f"❌ Envoi WhatsApp: {e}")
        return False


# ─────────────────────────────────────────────────────────────
# Analyse croisée → message WhatsApp
# ─────────────────────────────────────────────────────────────

def _fib_position(price: float, gom: Dict) -> str:
    """Retourne la zone Fibonacci où se trouve le prix."""
    levels = [
        (gom.get("fib_0"),   "0%   (Swing High)"),
        (gom.get("fib_236"), "23.6%"),
        (gom.get("fib_382"), "38.2%"),
        (gom.get("fib_500"), "50%  ⭐"),
        (gom.get("fib_618"), "61.8% OTE ⭐⭐"),
        (gom.get("fib_786"), "78.6%"),
        (gom.get("fib_100"), "100% (Swing Low)"),
    ]
    # Filtrer les None
    valid = [(v, l) for v, l in levels if v is not None]
    if not valid:
        return "inconnu"
    for i in range(len(valid) - 1):
        hi, hi_lbl = valid[i]
        lo, lo_lbl = valid[i + 1]
        if lo <= price <= hi:
            return f"entre Fib {hi_lbl} ({hi:.2f}) et {lo_lbl} ({lo:.2f})"
    if price > valid[0][0]:
        return f"au-dessus du Swing High ({valid[0][0]:.2f})"
    return f"sous le Swing Low ({valid[-1][0]:.2f})"


def build_analysis_message(price: float, bias: Optional[Dict],
                            gom: Optional[Dict], order: Optional[Dict],
                            ta_report: Optional[Dict] = None) -> str:
    ts = datetime.utcnow().strftime("%d/%m %H:%M UTC")
    lines = []

    # ── HEADER ───────────────────────────────────────────────
    lines.append(f"*XAUUSD — Suivi 20min* | {ts}")
    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── PRIX & NIVEAUX CLÉS ──────────────────────────────────
    lines.append(f"💰 *Prix live :* ${price:.2f}")

    if gom:
        vwap   = gom.get("vwap")
        bb_up  = gom.get("bb_up")
        bb_mid = gom.get("bb_mid")
        bb_dn  = gom.get("bb_dn")
        st     = gom.get("st_line")
        st_dir = gom.get("st_dir", 0)

        if vwap:
            rel_vwap = "✅ AU-DESSUS" if price > vwap else "🔴 EN-DESSOUS"
            lines.append(f"📍 VWAP : ${vwap:.2f} → prix {rel_vwap}")
        if bb_mid and bb_up and bb_dn:
            if price > bb_up:
                bb_pos = "🔴 AU-DESSUS BB Sup → survente possible"
            elif price < bb_dn:
                bb_pos = "🟢 SOUS BB Inf → survendu"
            elif price > bb_mid:
                bb_pos = "📈 au-dessus BB Mid"
            else:
                bb_pos = "📉 sous BB Mid"
            lines.append(f"📊 BB : [{bb_dn:.2f} / {bb_mid:.2f} / {bb_up:.2f}] → {bb_pos}")
        if st:
            st_sym = "▲ Haussier" if st_dir == 1 else "▼ Baissier"
            rel_st = "✅ prix AU-DESSUS" if price > st else "🔴 prix EN-DESSOUS"
            lines.append(f"⚡ Supertrend : ${st:.2f} ({st_sym}) → {rel_st}")

        # Fibonacci
        fib_zone = _fib_position(price, gom)
        lines.append(f"📐 Fibo : {fib_zone}")

    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── VERDICT GOM KOLA ────────────────────────────────────
    if gom:
        verdict    = gom.get("verdict", "INCONNU")
        score_buy  = gom.get("score_buy", 0.0)
        score_sell = gom.get("score_sell", 0.0)
        spike_pct  = gom.get("spike_pct", 0)
        rsi        = gom.get("rsi")
        gom_ts     = gom.get("timestamp", "")[:16].replace("T", " ")
        tf_global_dir      = gom.get("tf_global_dir", "")
        tf_global_strength = int(gom.get("tf_global_strength") or 0)
        coherence  = gom.get("coherence_pct", 0)
        ecart      = abs(score_buy - score_sell)

        verdict_emoji = "🟢" if verdict in ("BUY","GOOD BUY","PERFECT BUY") else "🔴" if "SELL" in verdict else "🟡"
        lines.append(f"{verdict_emoji} *Verdict GOM KOLA : {verdict}*")
        lines.append(f"   Score BUY={score_buy:.1f}  SELL={score_sell:.1f}  Spike={spike_pct:.0f}%")
        if rsi:
            lines.append(f"   RSI={rsi:.0f} | ST={'↑' if gom.get('st_dir',0)==1 else '↓'} | écart={ecart:.2f} pts | coh={coherence:.0f}%")

        # TF Global — direction macro du marché
        if tf_global_dir:
            tg_emoji = "🟢" if tf_global_dir == "BULL" else "🔴" if tf_global_dir == "BEAR" else "🟡"
            lines.append(f"   {tg_emoji} TF Global : *{tf_global_dir}* (force {tf_global_strength}%)")
        if gom_ts:
            lines.append(f"   Mis à jour : {gom_ts}")
    else:
        lines.append("🟡 *Verdict GOM KOLA : non disponible*")
        lines.append("   (Lance Pine Script + crée alerte webhook)")

    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── BIAIS SESSION ───────────────────────────────────────
    if bias:
        direction  = bias.get("direction", "UNKNOWN")
        confidence = bias.get("confidence", 0) * 100
        valid      = bias.get("valid", False)
        expires    = bias.get("expires_in_hours", 0)
        bias_emoji = "🟢" if direction in ("BUY","STRONG_BUY") else "🔴" if direction in ("SELL","STRONG_SELL") else "🟡"
        valid_str  = f"✅ valide {expires:.1f}h" if valid else "❌ expiré"
        lines.append(f"{bias_emoji} *Biais session :* {direction} {confidence:.0f}% | {valid_str}")
    else:
        lines.append("🟡 *Biais session :* non disponible")

    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── ORDRE EN ATTENTE ────────────────────────────────────
    if order:
        action     = order.get("action", "?")
        entry      = order.get("entry_price")
        sl         = order.get("stop_loss")
        tp         = order.get("take_profit")
        conf       = (order.get("confidence") or 0) * 100
        exec_type  = order.get("execution_type", "limit").upper()
        gom_action = order.get("gom_action", "UNKNOWN")
        gom_warn   = order.get("gom_warning")
        order_emoji = "🟢" if action == "BUY" else "🔴"

        lines.append(f"{order_emoji} *Ordre EA :* {exec_type} {action}")
        if entry: lines.append(f"   Entrée : ${entry:.2f}")
        if sl:    lines.append(f"   SL : ${sl:.2f}")
        if tp:    lines.append(f"   TP : ${tp:.2f}")
        lines.append(f"   Confiance : {conf:.0f}% | GOM={gom_action}")

        if entry and sl and tp:
            rr = abs(tp - entry) / abs(sl - entry) if sl != entry else 0
            lines.append(f"   R:R = 1:{rr:.1f}")
        if entry:
            dist = price - entry
            dist_str = f"+{dist:.2f} ✅ en profit" if (action=="BUY" and dist>0) or (action=="SELL" and dist<0) else f"{dist:.2f} ⏳ pas encore"
            lines.append(f"   Distance entrée : {dist_str}")
        if gom_warn:
            lines.append(f"   ⚠️ {gom_warn[:80]}")
    else:
        lines.append("📭 *Aucun ordre EA actif*")

    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── RAPPORT TRADINGAGENTS ────────────────────────────────────
    if ta_report and ta_report.get("ok"):
        ta_dir   = ta_report.get("direction", "HOLD")
        ta_conf  = (ta_report.get("confidence") or 0) * 100
        ta_age   = ta_report.get("age_minutes", 0)
        ta_exp   = ta_report.get("expires_in_minutes", 0)
        ta_entry = ta_report.get("entry_price")
        ta_sl    = ta_report.get("stop_loss")
        ta_tp    = ta_report.get("take_profit")
        ta_snip  = ta_report.get("reasoning_snippet", "")
        ta_emoji = "🟢" if ta_dir == "BUY" else "🔴" if ta_dir == "SELL" else "🟡"
        lines.append(f"{ta_emoji} *Rapport TradingAgents :* {ta_dir} {ta_conf:.0f}%")
        lines.append(f"   Age : {ta_age:.0f}min | Expire dans : {ta_exp:.0f}min")
        if ta_entry: lines.append(f"   Entrée TA : ${ta_entry:.2f}")
        if ta_sl:    lines.append(f"   SL TA : ${ta_sl:.2f}")
        if ta_tp:    lines.append(f"   TP TA : ${ta_tp:.2f}")
        if ta_snip:  lines.append(f"   📝 {ta_snip[:120]}…")
    else:
        lines.append("🔘 *Rapport TradingAgents :* aucun rapport actif")
    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── ANALYSE CROISÉE ─────────────────────────────────────
    lines.append("🔬 *Analyse croisée*")

    confluence_signals = []
    conflict_signals   = []

    if gom and bias:
        gom_verdict  = gom.get("verdict", "WAIT")
        bias_dir     = bias.get("direction", "UNKNOWN")
        bias_valid   = bias.get("valid", False)

        # Confluence GOM × Biais
        gom_bull = gom_verdict == "BUY"
        gom_bear = gom_verdict == "SELL"
        bias_bull = bias_dir in ("BUY", "STRONG_BUY") and bias_valid
        bias_bear = bias_dir in ("SELL", "STRONG_SELL") and bias_valid

        if gom_bull and bias_bull:
            confluence_signals.append("✅ GOM BUY + Biais BUY → setup haussier confirmé")
        elif gom_bear and bias_bear:
            confluence_signals.append("✅ GOM SELL + Biais SELL → setup baissier confirmé")
        elif gom_bull and bias_bear:
            conflict_signals.append("⚠️ GOM BUY ≠ Biais SELL → correction probable, attendre")
        elif gom_bear and bias_bull:
            conflict_signals.append("⚠️ GOM SELL ≠ Biais BUY → correction probable, attendre")

    if gom:
        vwap   = gom.get("vwap")
        st_dir = gom.get("st_dir", 0)
        spike  = gom.get("spike_pct", 0)

        # Prix vs VWAP + Supertrend
        if vwap and st_dir != 0:
            vwap_bear = price < vwap
            st_bear   = st_dir == -1
            if vwap_bear and st_bear:
                confluence_signals.append("✅ Prix < VWAP + Supertrend baissier → momentum SELL")
            elif not vwap_bear and not st_bear:
                confluence_signals.append("✅ Prix > VWAP + Supertrend haussier → momentum BUY")
            else:
                conflict_signals.append("⚠️ VWAP et Supertrend divergent → consolidation")

        # Spike
        if spike >= 62:
            confluence_signals.append(f"⚡ Spike détecté {spike:.0f}% → entrée imminente possible")
        elif spike >= 52:
            confluence_signals.append(f"🔔 Spike précoce {spike:.0f}% → surveiller")

    if order and gom:
        order_dir    = order.get("action", "")
        gom_verdict  = gom.get("verdict", "WAIT")
        gom_action_f = order.get("gom_action", "UNKNOWN")
        if gom_action_f == "ALIGNED":
            confluence_signals.append(f"✅ Ordre {order_dir} aligné avec verdict GOM → confiance renforcée")
        elif gom_action_f == "CONFLICT":
            conflict_signals.append(f"⚠️ Ordre {order_dir} en conflit avec GOM → réduire lot ou patienter")

    # Verdict final
    if confluence_signals:
        for s in confluence_signals:
            lines.append(f"  {s}")
    if conflict_signals:
        for s in conflict_signals:
            lines.append(f"  {s}")
    if not confluence_signals and not conflict_signals:
        lines.append("  🟡 Données insuffisantes pour confluence")

    # ── BLOCAGE TRADEMANAGER (TF Global) ───────────────────
    # Détecte si TradeManager va bloquer l'ordre à cause du filtre TF Global
    tm_block_reason = None
    if gom and order:
        order_dir          = order.get("action", "")
        tf_global_dir      = gom.get("tf_global_dir", "")
        tf_global_strength = int(gom.get("tf_global_strength") or 0)
        verdict_cur        = gom.get("verdict", "WAIT")
        # TradeManager bloque SELL si TF Global=BULL (force > 55 par défaut)
        if order_dir == "SELL" and tf_global_dir == "BULL" and tf_global_strength >= 55:
            tm_block_reason = f"⛔ *Ordre SELL probable BLOQUÉ par TradeManager* — TF Global=BULL (force {tf_global_strength}%) contredit la direction. Attendre retournement Global BEAR."
        elif order_dir == "BUY" and tf_global_dir == "BEAR" and tf_global_strength >= 55:
            tm_block_reason = f"⛔ *Ordre BUY probable BLOQUÉ par TradeManager* — TF Global=BEAR (force {tf_global_strength}%) contredit la direction. Attendre retournement Global BULL."
        # Avertissement si force faible (entre 40-55%)
        elif order_dir == "SELL" and tf_global_dir == "BULL" and tf_global_strength >= 40:
            tm_block_reason = f"⚠️ *Ordre SELL à risque* — TF Global=BULL (force {tf_global_strength}%) : TradeManager peut bloquer si seuil > {tf_global_strength}%."
        elif order_dir == "BUY" and tf_global_dir == "BEAR" and tf_global_strength >= 40:
            tm_block_reason = f"⚠️ *Ordre BUY à risque* — TF Global=BEAR (force {tf_global_strength}%) : TradeManager peut bloquer si seuil > {tf_global_strength}%."

    if tm_block_reason:
        conflict_signals.append(tm_block_reason)

    # ── DÉCISION SCALPING ──────────────────────────────────
    lines.append("━━━━━━━━━━━━━━━━━━━━")
    lines.append("🎯 *Décision scalping*")

    n_confluence = len(confluence_signals)
    n_conflict   = len(conflict_signals)

    if n_conflict > 0 and n_confluence <= 1:
        decision_txt = "🟡 ATTENDRE — signaux contradictoires"
    elif n_confluence >= 3 and n_conflict == 0:
        if gom and "SELL" in gom.get("verdict", ""):
            decision_txt = "🔴 SELL — forte confluence baissière"
        elif gom and "BUY" in gom.get("verdict", ""):
            decision_txt = "🟢 BUY — forte confluence haussière"
        else:
            decision_txt = "🟡 WAIT — pas de direction claire"
    elif n_confluence >= 2:
        decision_txt = "📊 SURVEILLER — confluence modérée"
    else:
        decision_txt = "🟡 WAIT — pas assez de signaux"

    lines.append(f"  {decision_txt}")

    # Répéter le blocage TradeManager en bas pour qu'il soit bien visible
    if tm_block_reason:
        lines.append(f"  {tm_block_reason}")

    lines.append("━━━━━━━━━━━━━━━━━━━━")
    lines.append("_Prochain check dans 20 min_")

    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────
# Alertes critiques sur changements d'état
# ─────────────────────────────────────────────────────────────

def check_critical_alerts(phone: str, price: float, bias: Optional[Dict],
                           gom: Optional[Dict], order: Optional[Dict]) -> None:
    global last_price, last_bias, last_gom, alerts_sent

    critical = []

    # Changement verdict GOM
    if gom and last_gom:
        prev_v = last_gom.get("verdict", "")
        curr_v = gom.get("verdict", "")
        if prev_v != curr_v and curr_v != "WAIT":
            key = f"gom_change_{prev_v}_{curr_v}"
            if key not in alerts_sent:
                critical.append(f"🔄 Verdict GOM change : {prev_v} → *{curr_v}*")
                alerts_sent.add(key)

    # Ordre : TP ou SL atteint
    if order and last_price:
        entry  = order.get("entry_price")
        sl     = order.get("stop_loss")
        tp     = order.get("take_profit")
        action = order.get("action", "")

        if sl and action == "SELL" and last_price > sl and price <= sl:
            key = f"sl_hit_{sl}"
            if key not in alerts_sent:
                critical.append(f"🛑 SL touché @ ${sl:.2f} ! Position fermée / stoppée")
                alerts_sent.add(key)
        if tp and action == "SELL" and last_price > tp and price <= tp:
            key = f"tp_hit_{tp}"
            if key not in alerts_sent:
                critical.append(f"🎯 TP ATTEINT @ ${tp:.2f} ! Sécuriser le profit")
                alerts_sent.add(key)
        if sl and action == "BUY" and last_price < sl and price >= sl:
            key = f"sl_hit_{sl}"
            if key not in alerts_sent:
                critical.append(f"🛑 SL touché @ ${sl:.2f} ! Position fermée / stoppée")
                alerts_sent.add(key)
        if tp and action == "BUY" and last_price < tp and price >= tp:
            key = f"tp_hit_{tp}"
            if key not in alerts_sent:
                critical.append(f"🎯 TP ATTEINT @ ${tp:.2f} ! Sécuriser le profit")
                alerts_sent.add(key)

    # Biais expiré
    if bias and last_bias:
        was_valid = last_bias.get("valid", False)
        now_valid = bias.get("valid", False)
        if was_valid and not now_valid:
            key = "bias_expired"
            if key not in alerts_sent:
                critical.append("⏰ Biais de session expiré — réévaluer le setup")
                alerts_sent.add(key)

    for msg in critical:
        ts = datetime.utcnow().strftime("%H:%M UTC")
        send_whatsapp(phone, f"🚨 *ALERTE [{ts}]*\n\n{msg}")


# ─────────────────────────────────────────────────────────────
# Boucle principale
# ─────────────────────────────────────────────────────────────

async def monitor_loop(phone: str, interval: int = 1200) -> None:
    global last_price, last_bias, last_gom, last_order

    logger.info(f"🚀 Monitor XAUUSD → {phone} | intervalle {interval}s")
    send_whatsapp(
        phone,
        f"🚀 *TradBOT Monitor démarré*\n"
        f"Analyse croisée TradingAgents × GOM KOLA\n"
        f"Symbole : {SYMBOL} | Check toutes les {interval // 60}min",
    )

    iteration = 0
    while True:
        try:
            iteration += 1
            logger.info(f"--- Check #{iteration} @ {datetime.utcnow().strftime('%H:%M:%S')} UTC ---")

            # Collecte parallèle
            price     = await get_live_price()
            bias      = get_session_bias()
            gom       = get_gom_verdict()
            order     = get_pending_order()
            ta_report = get_ta_report_status()

            if not price:
                logger.warning("⚠️ Prix non disponible, skip")
                await asyncio.sleep(interval)
                continue

            logger.info(
                f"Prix=${price:.2f} | "
                f"Biais={bias.get('direction') if bias else 'N/A'} | "
                f"GOM={gom.get('verdict') if gom else 'N/A'} | "
                f"Ordre={'oui' if order else 'non'} | "
                f"TA={'actif' if (ta_report and ta_report.get('ok')) else 'aucun'}"
            )

            # Alertes critiques (changements d'état)
            check_critical_alerts(phone, price, bias, gom, order)

            # Message de statut complet (intervalle = paramètre --interval, défaut 20min)
            msg = build_analysis_message(price, bias, gom, order, ta_report)
            send_whatsapp(phone, msg)

            # Mémoriser état
            last_price = price
            last_bias  = bias
            last_gom   = gom
            last_order = order

            await asyncio.sleep(interval)

        except KeyboardInterrupt:
            logger.info("⏹️ Arrêt")
            send_whatsapp(phone, "⏹️ Monitor XAUUSD arrêté.")
            break
        except Exception as e:
            logger.error(f"❌ Erreur boucle: {e}")
            await asyncio.sleep(60)


def main() -> None:
    parser = argparse.ArgumentParser(description="Monitor XAUUSD — analyse croisée WhatsApp")
    parser.add_argument("--phone",    type=str, required=True, help="Numéro WhatsApp (+2290196911346)")
    parser.add_argument("--interval", type=int, default=1200,  help="Intervalle secondes (défaut=1200 = 20min)")
    args = parser.parse_args()

    if not args.phone.startswith("+"):
        logger.error("❌ Le numéro doit commencer par +")
        sys.exit(1)

    try:
        asyncio.run(monitor_loop(args.phone, args.interval))
    except KeyboardInterrupt:
        logger.info("👋 Arrêt propre")


if __name__ == "__main__":
    main()
