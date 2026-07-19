"""
Rapport WhatsApp toutes les 30 minutes
- Solde/Equity/Taux de marge
- Positions ouvertes (P/L, symbole, direction)
- P/L du jour
- Statut Giveback Guard
"""

import os
import sys
import io
import time
import logging
import requests
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Fix Windows console encoding
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

try:
    import MetaTrader5 as mt5
    MT5_OK = True
except ImportError:
    MT5_OK = False
    print("MetaTrader5 module not found - MT5 features disabled")

# ── Config ──────────────────────────────────────────────────────────────
load_dotenv(dotenv_path="D:/Dev/TradBOT/.env")

PSYCHOBOT_URL = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com")
PHONE = os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346")
AI_SERVER = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000")

# Accounts
WELTRADE_LOGIN = 5026526
WELTRADE_SERVER = "Deriv-MT5-Real"
DERIV_LOGIN = 5026526
DERIV_SERVER = "Deriv-MT5-Real"

# Giveback Guard dynamique
_giveback_daily_peak_pnl: float = 0.0
_giveback_daily_peak_date: str = ""
GIVEBACK_LOCK_PCT = 0.40  # 40% du pic → pause (même seuil que MT5)

INTERVAL = 1800  # 30 minutes

logging.basicConfig(level=logging.INFO, format="%(asctime)s [REPORT] %(message)s")
log = logging.getLogger("report_30min")


# ── WhatsApp ────────────────────────────────────────────────────────────
def send_whatsapp(text: str):
    try:
        r = requests.post(
            f"{PSYCHOBOT_URL}/send-message",
            json={"phone": PHONE, "message": text},
            timeout=15,
        )
        if r.status_code == 200:
            log.info("WhatsApp envoyé ✅")
        else:
            log.warning(f"WhatsApp HTTP {r.status_code}: {r.text[:200]}")
    except Exception as e:
        log.error(f"WhatsApp erreur: {e}")


# ── MT5 Account Info ────────────────────────────────────────────────────
def get_mt5_info(login: int, server: str) -> dict:
    info = {"balance": 0, "equity": 0, "margin": 0, "margin_level": 0,
            "positions": [], "daily_pnl": 0, "connected": False}
    if not MT5_OK:
        return info
    try:
        if not mt5.initialize():
            log.warning(f"MT5 init failed for {server}")
            return info

        authorized = mt5.login(login, server=server)
        if not authorized:
            log.warning(f"MT5 login failed {login}@{server}")
            mt5.shutdown()
            return info

        acc = mt5.account_info()
        if acc:
            info["balance"] = acc.balance
            info["equity"] = acc.equity
            info["margin"] = acc.margin
            info["margin_level"] = acc.margin_level if acc.margin else 0
            info["connected"] = True

        # Get open positions
        positions = mt5.positions_get()
        if positions:
            for pos in positions:
                pnl = pos.profit
                info["positions"].append({
                    "symbol": pos.symbol,
                    "type": "BUY" if pos.type == 0 else "SELL",
                    "volume": pos.volume,
                    "price_open": pos.price_open,
                    "price_current": pos.price_current,
                    "profit": pnl,
                    "sl": pos.sl,
                    "tp": pos.tp,
                    "time": pos.time,
                })
                info["daily_pnl"] += pnl

        # Get deals for today
        today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        deals = mt5.history_deals_get(today, datetime.now())
        if deals:
            for deal in deals:
                info["daily_pnl"] += deal.profit + deal.commission + deal.swap

        mt5.shutdown()
    except Exception as e:
        log.error(f"MT5 error {server}: {e}")
    return info


# ── Build Report ────────────────────────────────────────────────────────
def build_report() -> str:
    now = datetime.now()
    hour = now.strftime("%H:%M")

    weltrade = get_mt5_info(WELTRADE_LOGIN, WELTRADE_SERVER)
    deriv = get_mt5_info(DERIV_LOGIN, DERIV_SERVER)

    total_balance = weltrade["balance"] + deriv["balance"]
    total_equity = weltrade["equity"] + deriv["equity"]
    total_pnl = weltrade["daily_pnl"] + deriv["daily_pnl"]
    total_positions = len(weltrade["positions"]) + len(deriv["positions"])

    # ── Giveback Guard dynamique (pic du jour) ──
    global _giveback_daily_peak_pnl, _giveback_daily_peak_date
    today_str = datetime.now().strftime("%Y-%m-%d")
    if _giveback_daily_peak_date != today_str:
        _giveback_daily_peak_pnl = 0.0
        _giveback_daily_peak_date = today_str
    if total_pnl > _giveback_daily_peak_pnl:
        _giveback_daily_peak_pnl = total_pnl

    giveback_info = "🟢 INACTIF"
    if _giveback_daily_peak_pnl >= 5.0:  # Pic minimum $5
        giveback_pct = 1.0 - (total_pnl / _giveback_daily_peak_pnl) if _giveback_daily_peak_pnl > 0 else 0
        if giveback_pct >= GIVEBACK_LOCK_PCT:
            giveback_info = f"🔴 ACTIF — {giveback_pct*100:.0f}% du pic rendu (pic +${_giveback_daily_peak_pnl:.2f})"
        else:
            giveback_info = f"🟢 {giveback_pct*100:.0f}% rendu (pic +${_giveback_daily_peak_pnl:.2f})"
    elif _giveback_daily_peak_pnl > 0:
        giveback_info = f"🟢 Pic ${_giveback_daily_peak_pnl:.2f} < $5 seuil"

    msg = f"""📊 *RAPPORT 30min* — {hour}

💰 *SOLDE*
├ Weltrade: ${weltrade['balance']:.2f}
├ Deriv: ${deriv['balance']:.2f}
└ Total: ${total_balance:.2f}

📈 *EQUITY*
├ Weltrade: ${weltrade['equity']:.2f}
├ Deriv: ${deriv['equity']:.2f}
└ Total: ${total_equity:.2f}

💵 *P/L DU JOUR*
├ Weltrade: ${weltrade['daily_pnl']:.2f}
├ Deriv: ${deriv['daily_pnl']:.2f}
└ Total: ${total_pnl:+.2f}

🔓 *POSITIONS ({total_positions})*"""

    if weltrade["positions"]:
        msg += "\n▸ *Weltrade:*"
        for pos in weltrade["positions"]:
            emoji = "🟢" if pos["profit"] >= 0 else "🔴"
            msg += f"\n  {emoji} {pos['type']} {pos['symbol']} | {pos['volume']} lot | {pos['profit']:+.2f}$"

    if deriv["positions"]:
        msg += "\n▸ *Deriv:*"
        for pos in deriv["positions"]:
            emoji = "🟢" if pos["profit"] >= 0 else "🔴"
            msg += f"\n  {emoji} {pos['type']} {pos['symbol']} | {pos['volume']} lot | {pos['profit']:+.2f}$"

    if not weltrade["positions"] and not deriv["positions"]:
        msg += "\n  Aucune position ouverte"

    msg += f"""

🛡️ *GIVEBACK GUARD*
└ Statut: {giveback_info}

⏰ Prochain rapport: {(now + timedelta(minutes=30)).strftime('%H:%M')}"""

    return msg


# ── Main Loop ───────────────────────────────────────────────────────────
def main():
    log.info("Report 30min démarré")
    while True:
        try:
            report = build_report()
            send_whatsapp(report)
        except Exception as e:
            log.error(f"Erreur rapport: {e}")
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
