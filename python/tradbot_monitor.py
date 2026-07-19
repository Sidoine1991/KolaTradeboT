# -*- coding: utf-8 -*-
"""
TradBOT Monitor — GOM Poller + WhatsApp dans un seul terminal
=============================================================

Deux taches asyncio en parallele :
  - Tache 1 (GOM Poller)       : lit TradingView toutes les 60s → /gom-verdict
  - Tache 2 (WhatsApp Monitor) : analyse croisee + WhatsApp toutes les 10min

Usage :
    python Python/tradbot_monitor.py --phone +2290196911346
    python Python/tradbot_monitor.py --phone +2290196911346 --poll 30 --whatsapp 300
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

import requests
import websockets

# ─────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────
AI_SERVER_URL = "http://127.0.0.1:8000"
WHATSAPP_URL  = "https://psychobot-1si7.onrender.com"
DERIV_WS_URL  = "wss://ws.derivws.com/websockets/v3?app_id=1089"
SYMBOL        = "XAUUSD"
TV_CLI        = Path(r"D:\Dev\Depot Github\tradingview-mcp_kola\src\cli\index.js")
TV_ROOT       = Path(r"D:\Dev\Depot Github\tradingview-mcp_kola")

DEFAULT_POLL_SEC      = 60    # lecture TradingView
DEFAULT_WHATSAPP_SEC  = 600   # envoi WhatsApp

# ─────────────────────────────────────────────────────────────
# Logging unique dans ce terminal
# ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(message)s",
    handlers=[
        logging.StreamHandler(
            open(sys.stdout.fileno(), mode="w", encoding="utf-8", closefd=False)
        ),
        logging.FileHandler("tradbot_monitor.log", encoding="utf-8"),
    ],
)
log = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────
# Etat partage entre les deux taches
# ─────────────────────────────────────────────────────────────
state: Dict[str, Any] = {
    "last_gom":    None,
    "last_bias":   None,
    "last_order":  None,
    "last_price":  None,
    "alerts_sent": set(),
}


# ═══════════════════════════════════════════════════════════════
# UTILITAIRES
# ═══════════════════════════════════════════════════════════════

def _parse_num(s) -> Optional[float]:
    if s is None:
        return None
    try:
        cleaned = re.sub(r"[^\d,.\-]", "", str(s))
        if "." in cleaned and "," in cleaned:
            cleaned = cleaned.replace(",", "")
        else:
            cleaned = cleaned.replace(",", ".")
        return float(cleaned) if cleaned else None
    except (ValueError, TypeError):
        return None


def _tv_cli(cmd: list) -> Optional[Dict]:
    try:
        p = subprocess.run(
            ["node", str(TV_CLI)] + cmd,
            capture_output=True, text=True, timeout=30,
            cwd=str(TV_ROOT),
        )
        return json.loads(p.stdout.strip()) if p.stdout.strip() else None
    except Exception as e:
        log.warning(f"[TV-CLI] {cmd} → {e}")
        return None


def _ai_get(path: str, params: dict = {}) -> Optional[Dict]:
    try:
        r = requests.get(f"{AI_SERVER_URL}{path}", params=params, timeout=5)
        return r.json() if r.ok else None
    except Exception:
        return None


def _send_whatsapp(phone: str, msg: str) -> bool:
    ts  = datetime.utcnow().strftime("%H:%M UTC")
    txt = f"TradBOT [{ts}]\n\n{msg}"
    try:
        with open("tradbot_monitor.log", "a", encoding="utf-8") as f:
            f.write(f"\n--- WA {datetime.utcnow().isoformat()} ---\n{txt}\n")
        r = requests.post(
            f"{WHATSAPP_URL}/send-message",
            json={"phone": phone, "message": txt},
            timeout=30,
        )
        ok = r.status_code == 200 and r.json().get("success")
        log.info(f"[WA] {'OK' if ok else 'ERREUR'} → {phone}")
        return ok
    except Exception as e:
        log.error(f"[WA] {e}")
        return False


# ═══════════════════════════════════════════════════════════════
# TACHE 1 — GOM POLLER
# ═══════════════════════════════════════════════════════════════

def _compute_gom_verdict(vals: Dict, price: float) -> Dict:
    vwap   = _parse_num(vals.get("VWAP"))
    bb_mid = _parse_num(vals.get("BB Mid"))
    bb_up  = _parse_num(vals.get("BB Sup"))
    bb_dn  = _parse_num(vals.get("BB Inf"))
    st     = _parse_num(vals.get("Supertrend"))

    buy = sell = 0.0
    if st:
        if price > st: buy  += 1.5
        else:          sell += 1.5
    if vwap:
        if price > vwap: buy  += 1.0
        else:            sell += 1.0
    if bb_mid:
        if price > bb_mid: buy  += 0.5
        else:              sell += 0.5

    gap     = abs(buy - sell)
    verdict = "BUY" if buy > sell and gap >= 1.2 else "SELL" if sell > buy and gap >= 1.2 else "WAIT"
    st_dir  = (1 if price > st else -1) if st else 0

    return {
        "symbol":     SYMBOL,
        "verdict":    verdict,
        "score_buy":  round(buy,  1),
        "score_sell": round(sell, 1),
        "spike_pct":  0,
        "vwap":       vwap,
        "bb_up":      bb_up,
        "bb_mid":     bb_mid,
        "bb_dn":      bb_dn,
        "st_line":    st,
        "st_dir":     st_dir,
        "fib_0":      _parse_num(vals.get("Fib 0%")),
        "fib_236":    _parse_num(vals.get("Fib 23.6%")),
        "fib_382":    _parse_num(vals.get("Fib 38.2%")),
        "fib_500":    _parse_num(vals.get("Fib 50%")),
        "fib_618":    _parse_num(vals.get("Fib 61.8%")),
        "fib_786":    _parse_num(vals.get("Fib 78.6%")),
        "fib_100":    _parse_num(vals.get("Fib 100%")),
        "price":      price,
    }


def poll_gom_once() -> bool:
    studies = _tv_cli(["values"])
    quote   = _tv_cli(["quote"])
    if not studies:
        log.warning("[GOM] TV non lisible — chart ouvert avec GOM·KOLA visible ?")
        return False

    study_list = studies.get("studies", [])
    gom_study  = next((s for s in study_list if "gom" in s.get("name","").lower() or "kola" in s.get("name","").lower()), None)
    if not gom_study:
        log.warning("[GOM] Indicateur GOM·KOLA non trouvé sur le chart")
        return False

    price = _parse_num(str((quote or {}).get("last", 0))) or 0.0
    payload = _compute_gom_verdict(gom_study["values"], price)

    try:
        r = requests.post(f"{AI_SERVER_URL}/gom-verdict", json=payload, timeout=5)
        if r.ok and r.json().get("ok"):
            log.info(
                f"[GOM] verdict={payload['verdict']}  "
                f"buy={payload['score_buy']}  sell={payload['score_sell']}  "
                f"prix={price:.2f}  "
                f"ST={'haussier' if payload['st_dir']==1 else 'baissier'}  "
                f"VWAP={payload['vwap']}"
            )
            state["last_gom"] = payload
            return True
    except Exception as e:
        log.error(f"[GOM] push: {e}")
    return False


async def task_gom_poller(interval: int) -> None:
    log.info(f"[GOM] Poller demarré — lecture TV toutes les {interval}s")
    while True:
        try:
            await asyncio.get_event_loop().run_in_executor(None, poll_gom_once)
        except Exception as e:
            log.error(f"[GOM] {e}")
        await asyncio.sleep(interval)


# ═══════════════════════════════════════════════════════════════
# TACHE 2 — WHATSAPP MONITOR
# ═══════════════════════════════════════════════════════════════

async def _live_price() -> Optional[float]:
    try:
        async with websockets.connect(DERIV_WS_URL, open_timeout=15) as ws:
            await ws.send(json.dumps({"ticks": "frxXAUUSD"}))
            for _ in range(20):
                try:
                    msg = json.loads(await asyncio.wait_for(ws.recv(), 10))
                    p   = msg.get("tick", {}).get("quote")
                    if p:
                        return float(p)
                except asyncio.TimeoutError:
                    continue
    except Exception as e:
        log.warning(f"[WS] prix: {e}")
    # Fallback : prix depuis GOM
    if state["last_gom"] and state["last_gom"].get("price"):
        return state["last_gom"]["price"]
    return None


def _fib_zone(price: float, gom: Dict) -> str:
    lvls = [
        (gom.get("fib_0"),   "0% Swing High"),
        (gom.get("fib_236"), "23.6%"),
        (gom.get("fib_382"), "38.2%"),
        (gom.get("fib_500"), "50%"),
        (gom.get("fib_618"), "61.8% OTE"),
        (gom.get("fib_786"), "78.6%"),
        (gom.get("fib_100"), "100% Swing Low"),
    ]
    valid = [(v, l) for v, l in lvls if v is not None]
    if not valid:
        return "N/A"
    for i in range(len(valid) - 1):
        hi, hl = valid[i]
        lo, ll = valid[i + 1]
        if lo <= price <= hi:
            return f"Fib {hl} ({hi:.2f}) — {ll} ({lo:.2f})"
    return f"sous Swing Low ({valid[-1][0]:.2f})" if price < valid[-1][0] else f"au-dessus Swing High ({valid[0][0]:.2f})"


def build_message(price: float) -> str:
    gom   = state["last_gom"]
    bias  = state["last_bias"]
    order = state["last_order"]
    lines = []

    lines.append(f"XAUUSD — {datetime.utcnow().strftime('%d/%m %H:%M UTC')}")
    lines.append("━━━━━━━━━━━━━━━━━━━━")
    lines.append(f"Prix live : ${price:.2f}")

    # ── Indicateurs techniques ───────────────────────────────
    if gom:
        if gom.get("vwap"):
            rel = "AU-DESSUS" if price > gom["vwap"] else "EN-DESSOUS"
            lines.append(f"VWAP : ${gom['vwap']:.2f} → {rel}")
        if gom.get("bb_mid"):
            if price > gom.get("bb_up", 0):     bb = "AU-DESSUS BB Sup"
            elif price < gom.get("bb_dn", 9e9): bb = "SOUS BB Inf"
            elif price > gom["bb_mid"]:          bb = "entre BB Mid et Sup"
            else:                                bb = "entre BB Inf et Mid"
            lines.append(f"BB [{gom.get('bb_dn',0):.2f}/{gom['bb_mid']:.2f}/{gom.get('bb_up',0):.2f}] → {bb}")
        if gom.get("st_line"):
            st_txt = "haussier" if gom["st_dir"] == 1 else "baissier"
            rel    = "AU-DESSUS" if price > gom["st_line"] else "EN-DESSOUS"
            lines.append(f"Supertrend : ${gom['st_line']:.2f} ({st_txt}) → {rel}")
        lines.append(f"Fibo : {_fib_zone(price, gom)}")

    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── ORDRE EN ATTENTE — vérifié EN PREMIER ────────────────
    if order:
        act  = order.get("action", "?")
        e    = order.get("entry_price")
        sl   = order.get("stop_loss")
        tp   = order.get("take_profit")
        conf = (order.get("confidence") or 0) * 100
        ga   = order.get("gom_action", "?")
        etype= order.get("execution_type", "limit").upper()

        lines.append(f"Ordre EA actif : {etype} {act}  conf={conf:.0f}%  GOM={ga}")
        if e:
            lines.append(f"  Entree ${e:.2f}  SL ${sl:.2f}  TP ${tp:.2f}")
        if e and sl and tp:
            rr   = abs(tp - e) / abs(sl - e) if sl != e else 0
            dist = price - e
            en_profit = (act == "BUY" and dist > 0) or (act == "SELL" and dist < 0)
            statut = "en profit" if en_profit else "pas encore declenche" if (
                (act=="SELL" and price > e) or (act=="BUY" and price < e)
            ) else "en attente"
            lines.append(f"  R:R 1:{rr:.1f}  |  ecart entree ${dist:+.2f}  ({statut})")
        if order.get("gom_warning"):
            lines.append(f"  ATTENTION : {order['gom_warning'][:90]}")

        # Statut GOM par rapport à l'ordre
        if gom:
            gv = gom["verdict"]
            if gv == act:
                lines.append(f"  GOM confirme la direction {act} — setup valide")
            elif gv == "WAIT":
                lines.append(f"  GOM neutre — surveiller")
            else:
                lines.append(f"  CONFLIT : GOM={gv} mais ordre={act} — possible correction, reduire lot")

        # Statut biais par rapport à l'ordre (contexte seulement)
        if bias:
            bd  = bias.get("direction", "?")
            bv  = bias.get("valid", False)
            bpc = bias.get("confidence", 0) * 100
            if not bv:
                lines.append(f"  Biais session expire ({bd}) — surveiller retournement")
            elif bd in ("BUY","STRONG_BUY") and act == "SELL":
                lines.append(f"  Biais session BUY {bpc:.0f}% — ordre SELL contre-tendance HTF")
            elif bd in ("SELL","STRONG_SELL") and act == "BUY":
                lines.append(f"  Biais session SELL {bpc:.0f}% — ordre BUY contre-tendance HTF")
            else:
                lines.append(f"  Biais session {bd} {bpc:.0f}% — aligne avec l'ordre")
        else:
            lines.append(f"  Biais session : non disponible (AI server ?)")

    else:
        # ── PAS D'ORDRE — on donne le statut complet ─────────
        lines.append("Ordre EA : aucun ordre actif")

        if gom:
            v  = gom["verdict"]
            lines.append(f"Verdict GOM : {v}  (BUY={gom['score_buy']} / SELL={gom['score_sell']})")
        else:
            lines.append("Verdict GOM : indisponible — Pine Script actif ?")

        if bias:
            bd, bpc, bv = bias.get("direction","?"), bias.get("confidence",0)*100, bias.get("valid",False)
            exp = bias.get("expires_in_hours", 0)
            if bv:
                lines.append(f"Biais session : {bd} {bpc:.0f}%  valide encore {exp:.1f}h")
            else:
                lines.append(f"Biais session : {bd} — EXPIRE, en attendre un nouveau")
        else:
            lines.append("Biais session : indisponible — AI server actif ?")

    # ── ANALYSE CROISEE ──────────────────────────────────────
    lines.append("━━━━━━━━━━━━━━━━━━━━")
    lines.append("Analyse croisee")

    confluence, conflict = [], []

    if gom and bias:
        gv = gom["verdict"]
        bd = bias.get("direction", "")
        bv = bias.get("valid", False)
        gb = gv == "BUY";  gs = gv == "SELL"
        bb = bd in ("BUY","STRONG_BUY") and bv
        bs = bd in ("SELL","STRONG_SELL") and bv
        if   gb and bb: confluence.append("GOM BUY + Biais BUY → haussier confirme")
        elif gs and bs: confluence.append("GOM SELL + Biais SELL → baissier confirme")
        elif gb and bs: conflict.append("GOM BUY != Biais SELL → correction probable")
        elif gs and bb: conflict.append("GOM SELL != Biais BUY → correction probable")

    if gom:
        vwap = gom.get("vwap"); st_d = gom.get("st_dir", 0)
        if vwap and st_d:
            if   price < vwap and st_d == -1: confluence.append("Prix < VWAP + ST baissier → momentum SELL")
            elif price > vwap and st_d == 1:  confluence.append("Prix > VWAP + ST haussier → momentum BUY")
            else:                             conflict.append("VWAP et Supertrend divergent → consolidation")
        if gom.get("spike_pct", 0) >= 62:
            confluence.append(f"Spike {gom['spike_pct']:.0f}% → entree imminente")

    if order and gom:
        ga = order.get("gom_action", "")
        if   ga == "ALIGNED":  confluence.append(f"Ordre {order.get('action')} aligne avec GOM")
        elif ga == "CONFLICT": conflict.append(f"Ordre {order.get('action')} en conflit GOM → lot reduit conseille")

    for s in confluence: lines.append(f"  OK {s}")
    for s in conflict:   lines.append(f"  ATTENTION {s}")
    if not confluence and not conflict:
        lines.append("  Pas assez de donnees pour confluence")

    # ── DECISION FINALE ──────────────────────────────────────
    lines.append("━━━━━━━━━━━━━━━━━━━━")
    n_c, n_x = len(confluence), len(conflict)

    if order:
        # Un ordre existe : la décision porte sur sa validité
        act = order.get("action","?")
        ga  = order.get("gom_action","")
        if n_x >= 2:
            dec = f"PRUDENCE — {n_x} conflits sur l'ordre {act}, envisager annulation"
        elif ga == "CONFLICT":
            dec = f"SURVEILLER — ordre {act} en conflit GOM, attendre confirmation"
        elif n_c >= 2:
            dec = f"TENIR l'ordre {act} — confluence confirmee"
        else:
            dec = f"ORDRE {act} ACTIF — confluence moderee, suivre le plan"
    else:
        # Pas d'ordre : conseil d'entrée
        if n_x > 0 and n_c <= 1:
            dec = "ATTENDRE — signaux contradictoires, pas d'entree"
        elif n_c >= 3 and n_x == 0:
            gv  = gom["verdict"] if gom else "?"
            dec = f"SETUP {gv} — forte confluence, envisager entree"
        elif n_c >= 2:
            dec = "SURVEILLER — confluence moderee, attendre confirmation"
        else:
            dec = "WAIT — signaux insuffisants"

    lines.append(f"Decision : {dec}")
    lines.append("Prochain check dans 10 min")
    return "\n".join(lines)


def check_alerts(phone: str, price: float) -> None:
    gom   = state["last_gom"]
    order = state["last_order"]
    last  = state["last_price"]
    sent  = state["alerts_sent"]

    # Changement verdict GOM
    prev_gom = getattr(check_alerts, "_prev_gom", None)
    if gom and prev_gom and prev_gom != gom["verdict"] and gom["verdict"] != "WAIT":
        key = f"gom_{prev_gom}_{gom['verdict']}"
        if key not in sent:
            _send_whatsapp(phone, f"ALERTE : Verdict GOM change {prev_gom} → {gom['verdict']}")
            sent.add(key)
    check_alerts._prev_gom = gom["verdict"] if gom else None

    # TP / SL atteints
    if order and last:
        act = order.get("action",""); sl = order.get("stop_loss"); tp = order.get("take_profit")
        if sl and act=="SELL" and last > sl and price <= sl:
            k = f"sl_{sl}"
            if k not in sent: _send_whatsapp(phone, f"SL touche @ ${sl:.2f} !"); sent.add(k)
        if tp and act=="SELL" and last > tp and price <= tp:
            k = f"tp_{tp}"
            if k not in sent: _send_whatsapp(phone, f"TP ATTEINT @ ${tp:.2f} ! Securiser"); sent.add(k)
        if sl and act=="BUY" and last < sl and price >= sl:
            k = f"sl_{sl}"
            if k not in sent: _send_whatsapp(phone, f"SL touche @ ${sl:.2f} !"); sent.add(k)
        if tp and act=="BUY" and last < tp and price >= tp:
            k = f"tp_{tp}"
            if k not in sent: _send_whatsapp(phone, f"TP ATTEINT @ ${tp:.2f} ! Securiser"); sent.add(k)


async def task_whatsapp_monitor(phone: str, interval: int) -> None:
    log.info(f"[WA] Monitor demarre — envoi toutes les {interval}s → {phone}")
    _send_whatsapp(phone,
        f"TradBOT Monitor demarre\n"
        f"Analyse croisee GOM KOLA x TradingAgents\n"
        f"Check toutes les {interval//60}min"
    )
    while True:
        try:
            price = await _live_price()
            if not price:
                log.warning("[WA] Prix indisponible, skip")
                await asyncio.sleep(interval)
                continue

            # Rafraichit biais et ordre depuis AI server
            bias_r  = _ai_get("/session-bias",  {"symbol": SYMBOL})
            order_r = _ai_get("/pending-order", {"symbol": SYMBOL})
            gom_r   = _ai_get("/gom-verdict",   {"symbol": SYMBOL})

            state["last_bias"]  = bias_r.get("data") if bias_r else None
            state["last_order"] = order_r.get("order") if order_r and order_r.get("ok") else None
            if gom_r and gom_r.get("ok"):
                state["last_gom"] = gom_r

            check_alerts(phone, price)
            msg = build_message(price)
            _send_whatsapp(phone, msg)
            state["last_price"] = price

        except Exception as e:
            log.error(f"[WA] {e}")
        await asyncio.sleep(interval)


# ═══════════════════════════════════════════════════════════════
# POINT D'ENTREE — les deux taches dans ce terminal
# ═══════════════════════════════════════════════════════════════

async def main_async(phone: str, poll: int, whatsapp: int) -> None:
    log.info("=" * 55)
    log.info("  TradBOT Monitor — GOM Poller + WhatsApp")
    log.info(f"  GOM polling   : toutes les {poll}s")
    log.info(f"  WhatsApp      : toutes les {whatsapp}s ({whatsapp//60}min)")
    log.info(f"  Phone         : {phone}")
    log.info("=" * 55)

    await asyncio.gather(
        task_gom_poller(poll),
        task_whatsapp_monitor(phone, whatsapp),
    )


def main() -> None:
    p = argparse.ArgumentParser(description="TradBOT Monitor unifie")
    p.add_argument("--phone",    required=True, help="Numero WhatsApp (+2290196911346)")
    p.add_argument("--poll",     type=int, default=DEFAULT_POLL_SEC,     help="Intervalle GOM polling (s)")
    p.add_argument("--whatsapp", type=int, default=DEFAULT_WHATSAPP_SEC, help="Intervalle WhatsApp (s)")
    args = p.parse_args()

    if not args.phone.startswith("+"):
        print("Erreur : le numero doit commencer par +")
        sys.exit(1)

    try:
        asyncio.run(main_async(args.phone, args.poll, args.whatsapp))
    except KeyboardInterrupt:
        log.info("Arret propre.")


if __name__ == "__main__":
    main()
