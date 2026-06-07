#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pipeline Autonome avec Validation WhatsApp

Workflow:
  1. Scan TradingView → Top-N symboles
  2. Pour chaque symbole → TradingAgents analyse complète
  3. WhatsApp: affiche signal + Entry/SL/TP/Lot → attend OUI/NON
  4. Si OUI → place l'ordre dans /pending-order (TradeManager l'exécute)
  5. Si NON ou timeout → skip, symbole suivant
  6. Rapport Word final envoyé

Usage:
  python pipeline_with_approval.py
  python pipeline_with_approval.py --top-n 3
  python pipeline_with_approval.py --timeout 300   # 5 min pour répondre
  python pipeline_with_approval.py --auto           # valider tout auto (sans attente)
"""

import sys, io, os
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

import ssl
ssl._create_default_https_context = ssl._create_unverified_context

import argparse
import json
import logging
import time
import requests
from datetime import datetime, date
from pathlib import Path
from typing import List, Dict, Optional

_HERE  = Path(__file__).resolve().parent
_ROOT  = _HERE.parent
_LOG_DIR = _ROOT / "logs"
_LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(_LOG_DIR / "pipeline_approval.log", encoding="utf-8"),
    ],
)
log = logging.getLogger("pipeline_approval")

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
AI_SERVER   = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000")
PSYCHOBOT   = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com")
PHONE       = os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346")
APPROVAL_TIMEOUT_SEC = 300  # 5 min pour répondre OUI/NON

# Réponses OUI acceptées
_YES = {"oui", "yes", "o", "y", "1", "ok", "valider", "valide", "go", "✅", "👍"}
_NO  = {"non", "no", "n", "0", "skip", "annuler", "annule", "❌", "👎"}

# ---------------------------------------------------------------------------
# Validation Boom/Crash
# ---------------------------------------------------------------------------
def is_valid_direction(symbol: str, direction: str) -> bool:
    s = symbol.upper()
    d = direction.upper()
    if "BOOM" in s and d == "SELL":
        log.warning("🚫 %s: SELL interdit sur Boom", symbol)
        return False
    if "CRASH" in s and d == "BUY":
        log.warning("🚫 %s: BUY interdit sur Crash", symbol)
        return False
    return True

# ---------------------------------------------------------------------------
# Lot minimum par catégorie
# ---------------------------------------------------------------------------
def get_lot_min(symbol: str) -> float:
    s = symbol.upper()
    if any(s.startswith(p) for p in ("BOOM", "CRASH")):
        return 0.20
    if any(s.startswith(p) for p in ("1HZ", "R_", "V10", "V25", "V50", "V75", "V100")):
        return 0.10
    return 0.01

# ---------------------------------------------------------------------------
# WhatsApp helpers
# ---------------------------------------------------------------------------
def send_whatsapp(msg: str) -> bool:
    for attempt in range(3):
        try:
            r = requests.post(
                f"{PSYCHOBOT}/send-message",
                json={"phone": PHONE, "message": msg},
                timeout=15, verify=False,
            )
            if r.status_code == 200:
                return True
        except Exception as e:
            log.warning("WhatsApp tentative %d/%d: %s", attempt + 1, 3, e)
        time.sleep(2)
    return False

def wait_for_approval(symbol: str, timeout: int) -> Optional[str]:
    """
    Poll GET /approval/{symbol} sur l'AI server jusqu'à timeout.
    L'utilisateur répond via PsychoBot ou directement via POST /approval.
    Retourne "yes", "no", ou None si timeout.
    """
    mt5_sym = _tv_to_mt5(symbol)
    deadline = time.time() + timeout
    # Nettoyer toute approbation précédente
    for sym_try in [mt5_sym, symbol]:
        try:
            requests.delete(f"{AI_SERVER}/approval/{sym_try}", timeout=3)
        except Exception:
            pass
    while time.time() < deadline:
        for sym_try in [mt5_sym, symbol]:
            try:
                r = requests.get(f"{AI_SERVER}/approval/{sym_try}", timeout=3)
                if r.status_code == 200:
                    data = r.json()
                    if data.get("answer") in ("yes", "no"):
                        # Nettoyer après lecture
                        requests.delete(f"{AI_SERVER}/approval/{sym_try}", timeout=3)
                        return data["answer"]
            except Exception:
                pass
        time.sleep(5)
    return None

def _tv_to_mt5(symbol: str) -> str:
    """Convertit DERIV:BOOM_500_INDEX → Boom 500 Index."""
    mapping = {
        "DERIV:BOOM_1000_INDEX": "Boom 1000 Index",
        "DERIV:BOOM_500_INDEX":  "Boom 500 Index",
        "DERIV:BOOM_300_INDEX":  "Boom 300 Index",
        "DERIV:CRASH_1000_INDEX":"Crash 1000 Index",
        "DERIV:CRASH_500_INDEX": "Crash 500 Index",
        "DERIV:CRASH_300_INDEX": "Crash 300 Index",
    }
    return mapping.get(symbol, symbol)

# ---------------------------------------------------------------------------
# Scan TradingView (réutilise morning_scan_report)
# ---------------------------------------------------------------------------
def scan_top_n(top_n: int) -> List[Dict]:
    from morning_scan_report import MorningScanReportGenerator
    gen = MorningScanReportGenerator()
    symbols = gen.get_open_market_symbols()
    log.info("Phase 1 — Scan TradingView: %d symboles", len(symbols))
    raw = gen.run_mcp_watchlist_scan(symbols)
    norm = [gen.normalize_result(r) for r in raw]
    valid = [
        r for r in norm
        if r.get("success")
        and r.get("direction") in ("BUY", "SELL")
        and r.get("confluence_score", 0) >= 5.0
        and is_valid_direction(r.get("symbol", ""), r.get("direction", ""))
    ]
    valid.sort(key=lambda x: x.get("confluence_score", 0), reverse=True)
    top = valid[:top_n]
    log.info("Top-%d retenus: %s", top_n, [r["symbol"] for r in top])
    return top

# Cache des prix MCP du scan — alimenté par scan_top_n pour fallback
_MCP_PRICE_CACHE: Dict[str, Dict] = {}

def scan_top_n_with_prices(top_n: int) -> List[Dict]:
    """Scan TradingView et conserve aussi les prix/ATR MCP pour fallback."""
    from morning_scan_report import MorningScanReportGenerator
    gen = MorningScanReportGenerator()
    symbols = gen.get_open_market_symbols()
    log.info("Phase 1 — Scan TradingView: %d symboles", len(symbols))
    raw = gen.run_mcp_watchlist_scan(symbols)

    # Stocker prix/ATR MCP dans le cache
    for r in raw:
        sym = r.get("symbol", "")
        cp  = r.get("current_price") or r.get("entry_setup", {}).get("entry_price")
        atr = r.get("entry_setup", {}).get("atr")
        if sym and (cp or atr):
            _MCP_PRICE_CACHE[sym] = {"price": cp, "atr": atr}

    norm = [gen.normalize_result(r) for r in raw]
    valid = [
        r for r in norm
        if r.get("success")
        and r.get("direction") in ("BUY", "SELL")
        and is_valid_direction(r.get("symbol", ""), r.get("direction", ""))
    ]
    # Seuil adaptatif : préférer >= 5.0, sinon prendre les meilleurs disponibles
    high = [r for r in valid if r.get("confluence_score", 0) >= 5.0]
    chosen = high if high else valid
    chosen.sort(key=lambda x: x.get("confluence_score", 0), reverse=True)
    top = chosen[:top_n]
    if not high and top:
        log.info("Phase 1 — Seuil abaissé (aucun score >= 5.0), meilleurs: %s",
                 [(r["symbol"], round(r.get("confluence_score",0),1)) for r in top])
    log.info("Top-%d retenus: %s", top_n,
             [(r["symbol"], r["direction"], round(r.get("confluence_score",0),1)) for r in top])
    return top

# ---------------------------------------------------------------------------
# TradingAgents analyse via bridge (run_quick)
# ---------------------------------------------------------------------------
def run_trading_agents(symbol: str, direction: str, trade_date: str) -> Optional[Dict]:
    """
    Appelle run_quick() du bridge TradingAgents.
    Retourne dict avec entry, sl, tp, lot, rapport_path ou None si échec.
    """
    try:
        # Ajouter le venv TradingAgents au path
        ta_repo = os.getenv("AI_TRADINGAGENTS_REPO_PATH",
                            r"D:\Dev\Depot Github\TradingAgents-main")
        venv_py = Path(ta_repo) / ".venv" / "Scripts" / "python.exe"
        if str(_HERE) not in sys.path:
            sys.path.insert(0, str(_HERE))
        if ta_repo not in sys.path:
            sys.path.insert(0, ta_repo)

        # Charger .env
        env_file = _ROOT / ".env"
        if env_file.exists():
            for line in env_file.read_text(encoding="utf-8").splitlines():
                if "=" in line and not line.startswith("#"):
                    k, _, v = line.partition("=")
                    os.environ.setdefault(k.strip(), v.strip())

        from tradbot_bridge import (
            run_quick, _normalize_rating, _extract_order_params,
            compute_signals, compute_entry_levels, compute_lot_sizes,
            save_report_word, _mt5_to_yfinance, push_pending_order,
        )

        # Nettoyer préfixe TV avant conversion (DERIV:BOOM_1000_INDEX → Boom 1000 Index)
        clean_sym = _tv_to_mt5(symbol)  # ex: "Boom 1000 Index"

        # Tout passer via Deriv — supporte frxBTCUSD, frxETHUSD, frxXAUUSD, BOOM*, CRASH*, EURUSD...
        from tradingagents.dataflows.deriv_market import resolve_deriv_symbol  # type: ignore
        try:
            ticker_id = resolve_deriv_symbol(clean_sym.upper().replace(" ", ""))
        except Exception:
            ticker_id = _mt5_to_yfinance(clean_sym)
        vendor = "deriv"
        log.info("  [TA] Symbole %s -> ticker=%s vendor=deriv", clean_sym, ticker_id)

        log.info("  [TA] Analyse %s → %s (%s) vendor=%s", symbol, clean_sym, ticker_id, vendor)
        result = run_quick(clean_sym, trade_date,
                           analysts=["market", "social"],
                           data_ticker=ticker_id,
                           vendor=vendor)

        rec       = _normalize_rating(result["signal_rating"])
        final_st  = result["final_state"]
        indicators= result.get("indicators") or {}
        params    = _extract_order_params(final_st)

        # Calculer niveaux Entry/SL/TP
        cp  = float(indicators.get("current_price") or 0)
        atr = float(indicators.get("atr") or 0)

        # Source 1 : Deriv WebSocket API (données réelles — utilisé pour TOUS les symboles)
        if cp <= 0 or atr <= 0:
            try:
                from tradbot_bridge import compute_indicators_from_deriv
                deriv_ind = compute_indicators_from_deriv(ticker_id)
                if deriv_ind:
                    if cp <= 0:
                        cp  = float(deriv_ind.get("current_price") or 0)
                    if atr <= 0:
                        atr = float(deriv_ind.get("atr") or 0)
                    if cp > 0:
                        log.info("  [Deriv ✅] %s: prix=%.5f ATR=%.5f", symbol, cp, atr)
            except Exception as e:
                log.warning("  [Deriv] %s: %s", symbol, e)

        # Source 2 : AI server /trading/indicators (pour Forex/Crypto)
        if cp <= 0 or atr <= 0:
            lvl = compute_entry_levels(clean_sym, rec)
            if cp <= 0:
                cp  = float(lvl.get("current_price") or 0)
            if atr <= 0:
                atr = float(lvl.get("atr") or 0)

        # Source 3 : AI server /gom-verdict
        if cp <= 0 or atr <= 0:
            try:
                rg = requests.get(f"{AI_SERVER}/gom-verdict",
                                  params={"symbol": clean_sym}, timeout=4)
                if rg.status_code == 200:
                    gd = rg.json()
                    if cp <= 0:
                        cp  = float(gd.get("close") or gd.get("current_price") or 0)
                    if atr <= 0:
                        atr = float(gd.get("atr") or 0)
            except Exception:
                pass

        # Source 4 : cache prix MCP du scan phase 1
        if cp <= 0:
            cached = _MCP_PRICE_CACHE.get(symbol, {})
            if cached.get("price"):
                cp  = float(cached["price"])
                log.info("  [MCP cache] %s: prix=%.5f", symbol, cp)
            if atr <= 0 and cached.get("atr"):
                atr = float(cached["atr"])

        # Calculer signaux avec le meilleur prix disponible
        signals = []
        if cp > 0 and atr > 0:
            signals = compute_signals(clean_sym, rec, cp, atr)
        elif cp > 0:
            # ATR estimé à 0.5% du prix si indisponible
            atr_est = round(cp * 0.005, 5)
            log.warning("  [TA] %s: ATR indisponible — estimé %.5f (0.5%% × %.2f)", symbol, atr_est, cp)
            signals = compute_signals(clean_sym, rec, cp, atr_est)
        else:
            log.warning("  [TA] %s: Aucune source de prix disponible — niveaux N/A", symbol)

        sig0 = signals[0] if signals else {}
        entry = sig0.get("entry_price") or params.get("entry_price")
        sl    = sig0.get("stop_loss")   or params.get("stop_loss")
        tp    = sig0.get("take_profit") or params.get("take_profit")
        lot   = get_lot_min(symbol)

        # Sauvegarder rapport Word
        confirmed = {
            "recommendation": rec,
            "confidence":     0.75,
            "entry_price":    entry,
            "stop_loss":      sl,
            "take_profit":    tp,
            "execution_type": sig0.get("exec_type", "market"),
            "lot":            lot,
        }
        # Utiliser clean_sym (ex: "Boom 300 Index") — jamais le ticker TV avec ":"
        report_path = save_report_word(
            clean_sym, trade_date, result["signal_rating"],
            final_st, params, confirmed=confirmed,
            indicators=indicators if indicators else None,
        )

        return {
            "symbol":      symbol,
            "direction":   rec,
            "entry":       entry,
            "sl":          sl,
            "tp":          tp,
            "lot":         lot,
            "current":     cp,
            "atr":         atr,
            "score":       float(result.get("score", 0) or 0),
            "report_path": report_path,
            "confirmed":   confirmed,
            "final_state": final_st,
            "reasoning":   (str(final_st.get("final_trade_decision") or "") + "\n" +
                            str(final_st.get("trader_investment_plan") or ""))[:500],
        }

    except Exception as e:
        log.error("  [TA] Erreur %s: %s", symbol, e, exc_info=True)
        return None

# ---------------------------------------------------------------------------
# Message WhatsApp de validation
# ---------------------------------------------------------------------------
def build_approval_message(idx: int, total: int, ta: Dict) -> str:
    sym  = ta["symbol"]
    dire = ta["direction"]
    e    = ta.get("entry")
    sl   = ta.get("sl")
    tp   = ta.get("tp")
    lot  = ta.get("lot")
    cur  = ta.get("current")
    atr  = ta.get("atr")

    arrow = "🟢" if dire == "BUY" else "🔴"
    rr_str = ""
    if e and sl and tp:
        try:
            risk   = abs(float(e) - float(sl))
            reward = abs(float(tp) - float(e))
            rr = round(reward / risk, 2) if risk > 0 else 0
            rr_str = f"R/R: 1:{rr}\n"
        except Exception:
            pass

    def _fmt(v): return f"{v:.5f}" if v and isinstance(v, float) else (str(v) if v else "N/A")

    return (
        f"*🤖 TradBOT — Signal #{idx}/{total}*\n"
        f"━━━━━━━━━━━━━━━━━━\n"
        f"{arrow} *{sym}* — {dire}\n\n"
        f"💰 Prix actuel : {_fmt(cur)}\n"
        f"📍 Entry       : {_fmt(e)}\n"
        f"🛑 Stop Loss   : {_fmt(sl)}\n"
        f"🎯 Take Profit : {_fmt(tp)}\n"
        f"📦 Lot         : {lot}\n"
        f"📊 ATR         : {_fmt(atr)}\n"
        f"{rr_str}"
        f"━━━━━━━━━━━━━━━━━━\n"
        f"*Répondre OUI pour placer l'ordre*\n"
        f"*Répondre NON pour ignorer*\n"
        f"⏳ _{APPROVAL_TIMEOUT_SEC // 60} minutes pour répondre_"
    )

# ---------------------------------------------------------------------------
# Envoyer l'ordre validé à TradeManager
# ---------------------------------------------------------------------------
def place_order(ta: Dict) -> bool:
    payload = {
        "symbol":         ta["symbol"],
        "action":         ta["direction"].lower(),
        "recommendation": ta["direction"],
        "entry_price":    ta.get("entry"),
        "stop_loss":      ta.get("sl"),
        "take_profit":    ta.get("tp"),
        "lot":            ta.get("lot"),
        "execution_type": ta["confirmed"].get("execution_type", "market"),
        "confidence":     0.80,
        "source":         "pipeline_approval",
        "reasoning":      ta.get("reasoning", ""),
        "status":         "ready",
    }
    try:
        r = requests.post(f"{AI_SERVER}/pending-order", json=payload, timeout=10)
        r.raise_for_status()
        log.info("  ✅ Ordre placé: %s %s @ %s SL=%s TP=%s lot=%s",
                 ta["direction"], ta["symbol"],
                 ta.get("entry"), ta.get("sl"), ta.get("tp"), ta.get("lot"))
        return True
    except Exception as e:
        log.error("  ❌ Ordre échoué %s: %s", ta["symbol"], e)
        return False

# ---------------------------------------------------------------------------
# Envoyer rapport Word par WhatsApp
# ---------------------------------------------------------------------------
def send_report_whatsapp(ta: Dict) -> None:
    rp = ta.get("report_path")
    if not rp or not Path(rp).exists():
        return
    try:
        sys.path.insert(0, str(_HERE))
        from send_tradingagents_report import send_whatsapp_file
        caption = (f"📊 *Rapport TradingAgents — {ta['symbol']}*\n"
                   f"Direction: *{ta['direction']}*")
        send_whatsapp_file(str(rp), caption)
        log.info("  📄 Rapport Word envoyé: %s", Path(rp).name)
    except Exception as e:
        log.warning("  Rapport Word non envoyé: %s", e)

# ---------------------------------------------------------------------------
# Pipeline principal
# ---------------------------------------------------------------------------
def run(top_n: int = 5, timeout: int = APPROVAL_TIMEOUT_SEC, auto: bool = False) -> None:
    t0 = time.time()
    trade_date = str(date.today())
    run_at = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")

    log.info("=" * 60)
    log.info("Pipeline Approval — %s  Top-%d  Auto=%s", run_at, top_n, auto)
    log.info("=" * 60)

    # Phase 1 — Scan TV (avec cache prix MCP pour fallback)
    scans = scan_top_n_with_prices(top_n)
    if not scans:
        log.warning("Aucun setup valide trouvé — pipeline terminé")
        send_whatsapp(f"*TradBOT*\nAucun setup valide ce cycle ({run_at})")
        return

    # Notifier le début
    symbols_list = "\n".join([f"  {i+1}. {s['symbol']} {s['direction']} ({s['confluence_score']:.1f}/10)"
                               for i, s in enumerate(scans)])
    send_whatsapp(
        f"*🤖 TradBOT — Pipeline démarré*\n"
        f"_{run_at}_\n\n"
        f"Analyse en cours pour {len(scans)} symbole(s):\n{symbols_list}\n\n"
        f"_Vous serez alerté pour chaque signal..._"
    )

    orders_placed  = []
    orders_skipped = []
    orders_failed  = []

    for idx, scan in enumerate(scans, 1):
        sym = scan["symbol"]
        dir_tv = scan["direction"]

        log.info("--- [%d/%d] %s %s ---", idx, len(scans), sym, dir_tv)

        # Phase 2 — TradingAgents
        log.info("  Analyse TradingAgents...")
        ta = run_trading_agents(sym, dir_tv, trade_date)

        if ta is None:
            log.warning("  TradingAgents échoué pour %s — skip", sym)
            orders_failed.append(sym)
            send_whatsapp(f"⚠️ *{sym}*: Analyse TradingAgents échouée — ignoré")
            continue

        # Vérifier direction retournée par TA
        ta_dir = ta.get("direction", dir_tv)
        if not is_valid_direction(sym, ta_dir):
            orders_skipped.append(sym)
            send_whatsapp(f"🚫 *{sym}*: Direction {ta_dir} invalide — rejeté automatiquement")
            continue

        # Envoyer rapport Word
        send_report_whatsapp(ta)

        if auto:
            # Mode auto — pas de confirmation
            log.info("  Mode AUTO — placement direct de l'ordre")
            if place_order(ta):
                orders_placed.append(sym)
                send_whatsapp(
                    f"✅ *Ordre placé automatiquement*\n"
                    f"{ta_dir} *{sym}*\n"
                    f"Entry: {ta.get('entry')} | SL: {ta.get('sl')} | TP: {ta.get('tp')} | Lot: {ta.get('lot')}"
                )
            else:
                orders_failed.append(sym)
            continue

        # Phase 3 — Alerte WhatsApp + attente validation
        approval_msg = build_approval_message(idx, len(scans), ta)
        log.info("  Envoi alerte WhatsApp validation...")
        send_whatsapp(approval_msg)

        log.info("  Attente réponse OUI/NON (%ds timeout)...", timeout)
        send_whatsapp(
            f"💡 *Pour valider:*\n"
            f"Répondez à ce bot: *OUI {sym}* ou *NON {sym}*\n"
            f"_ou via API: POST {AI_SERVER}/approval {{symbol:{sym},answer:yes}}_"
        )
        reply = wait_for_approval(sym, timeout)

        if reply is None:
            log.warning("  ⏰ Timeout — aucune réponse pour %s — skip", sym)
            orders_skipped.append(sym)
            send_whatsapp(f"⏰ *{sym}*: Pas de réponse ({timeout//60}min) — ordre ignoré")
            continue

        if reply == "yes":
            log.info("  ✅ Validé par utilisateur — placement ordre %s", sym)
            if place_order(ta):
                orders_placed.append(sym)
                send_whatsapp(
                    f"✅ *Ordre placé!*\n"
                    f"{ta_dir} *{sym}*\n"
                    f"Entry: {ta.get('entry')} | SL: {ta.get('sl')} | TP: {ta.get('tp')} | Lot: {ta.get('lot')}"
                )
            else:
                orders_failed.append(sym)
                send_whatsapp(f"❌ *{sym}*: Échec placement ordre — vérifier TradeManager")
        else:  # "no"
            log.info("  ❌ Refusé par utilisateur — %s ignoré", sym)
            orders_skipped.append(sym)
            send_whatsapp(f"⏭ *{sym}*: Signal ignoré sur votre demande")

    # Résumé final
    elapsed = round(time.time() - t0, 0)
    summary = (
        f"*🏁 TradBOT — Pipeline Terminé*\n"
        f"_{run_at}_\n\n"
        f"✅ Ordres placés    : {len(orders_placed)}\n"
        f"⏭ Ignorés          : {len(orders_skipped)}\n"
        f"❌ Erreurs          : {len(orders_failed)}\n\n"
    )
    if orders_placed:
        summary += f"*Placés:* {', '.join(orders_placed)}\n"
    if orders_skipped:
        summary += f"*Ignorés:* {', '.join(orders_skipped)}\n"
    if orders_failed:
        summary += f"*Erreurs:* {', '.join(orders_failed)}\n"
    summary += f"\n_Durée: {int(elapsed)}s_"

    send_whatsapp(summary)
    log.info(summary.replace("*", "").replace("_", ""))


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Pipeline autonome avec validation WhatsApp")
    parser.add_argument("--top-n",   type=int,   default=5,   help="Nombre de symboles à analyser")
    parser.add_argument("--timeout", type=int,   default=300, help="Secondes pour répondre OUI/NON (défaut 300=5min)")
    parser.add_argument("--auto",    action="store_true",     help="Valider tout automatiquement sans confirmation")
    args = parser.parse_args()
    run(top_n=args.top_n, timeout=args.timeout, auto=args.auto)

if __name__ == "__main__":
    main()
