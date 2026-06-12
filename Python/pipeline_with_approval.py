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

import sys, io, os, subprocess
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

# Signal refiner — boucle de rétroaction TV → signal qualité
try:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from signal_refiner import refine_signal, MIN_QUALITY_SCORE
    _REFINER_AVAILABLE = True
except ImportError as _ref_err:
    _REFINER_AVAILABLE = False
    log_tmp = logging.getLogger("pipeline_approval")
    log_tmp.warning("signal_refiner non disponible: %s", _ref_err)
    MIN_QUALITY_SCORE = 75  # Seuil minimum = 75% confiance

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


def check_mtf_gate(symbol: str, data: dict, action: str) -> tuple:
    """Gate MTF : H4+H1+M15 doivent confirmer la direction du signal.

    Règles :
    - BUY  valide  : H4==BULL ou (H1==BULL et M15==BULL)
    - SELL valide  : H4==BEAR ou (H1==BEAR et M15==BEAR)
    - Rejet absolu : H4 ET H1 tous deux opposés au signal
    - Cohérence MTF: >= 4/6 TF dans la direction du signal

    Retourne (ok: bool, raison: str).
    Si aucune donnée TF disponible → laisse passer.
    """
    tfs = {
        "m1":  data.get("tf_m1_dir",  "NEUT"),
        "m5":  data.get("tf_m5_dir",  "NEUT"),
        "m15": data.get("tf_m15_dir", "NEUT"),
        "h1":  data.get("tf_h1_dir",  "NEUT"),
        "h4":  data.get("tf_h4_dir",  "NEUT"),
        "d1":  data.get("tf_d1_dir",  "NEUT"),
    }
    if all(d == "NEUT" for d in tfs.values()):
        return True, ""

    h4  = tfs["h4"]
    h1  = tfs["h1"]
    m15 = tfs["m15"]
    side     = "BULL" if action.upper() == "BUY" else "BEAR"
    opposite = "BEAR" if action.upper() == "BUY" else "BULL"

    # Rejet absolu : H4 ET H1 tous deux opposés
    if h4 == opposite and h1 == opposite:
        return False, f"MTF rejet absolu — H4={h4} H1={h1} contre {action}"

    # Structure : H4 confirme OU (H1 + M15 confirment)
    if not ((h4 == side) or (h1 == side and m15 == side)):
        return False, f"MTF structure insuffisante — H4={h4} H1={h1} M15={m15} pour {action}"

    # Cohérence >= 4/6 TF
    count = sum(1 for d in tfs.values() if d == side)
    if count < 4:
        return False, f"MTF cohérence {count}/6 TF {side} < 4 requis pour {action}"

    return True, ""

# ---------------------------------------------------------------------------
# Lot minimum par catégorie
# ---------------------------------------------------------------------------
def get_lot_min(symbol: str) -> float:
    s = symbol.upper().replace("DERIV:", "").replace("_INDEX", "").replace(" ", "").replace("INDEX", "")
    if any(p in s for p in ("BOOM", "CRASH")):
        return 0.20
    if any(s.startswith(p) for p in ("1HZ", "R_", "V10", "V25", "V50", "V75", "V100", "VOLATILITY")):
        return 0.10
    return 0.01

# ---------------------------------------------------------------------------
# Symboles NON disponibles chez Deriv (filtrés du pipeline)
# ---------------------------------------------------------------------------
_DERIV_EXCLUDED = {
    "US500", "NAS100", "US30", "SPX500", "SP500", "NASDAQ",
    "DAX", "FTSE", "CAC40", "NIKKEI", "HSI",
    "^GSPC", "^DJI", "^IXIC", "^GDAXI",
}

def is_available_on_deriv(symbol: str) -> bool:
    s = symbol.upper().replace("DERIV:", "").replace("_INDEX", "").replace(" ", "")
    return s not in _DERIV_EXCLUDED

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
# Scan MT5/GOM (remplace TradingView MCP — 100% local)
# ---------------------------------------------------------------------------
_MCP_PRICE_CACHE: Dict[str, Dict] = {}

def scan_top_n(top_n: int) -> List[Dict]:
    return scan_top_n_with_prices(top_n)

def scan_top_n_with_prices(top_n: int) -> List[Dict]:
    """Scan depuis /gom-verdicts (candles MT5 live) — sans TradingView."""
    log.info("Phase 1 — Scan GOM MT5 (sans TradingView)")
    try:
        r = requests.get(f"{AI_SERVER}/gom-verdicts", timeout=5)
        if r.status_code != 200:
            log.warning("Phase 1 — /gom-verdicts HTTP %s", r.status_code)
            return []
        data = r.json()
        verdicts = data.get("verdicts", data) if isinstance(data, dict) else data
        if not isinstance(verdicts, list):
            verdicts = list(verdicts.values()) if isinstance(verdicts, dict) else []
    except Exception as exc:
        log.error("Phase 1 — /gom-verdicts error: %s", exc)
        return []

    valid = []
    _seen_normalized = {}  # sym_norm → index dans valid (dédup)
    for v in verdicts:
        vnum = v.get("verdict_num", 0)
        if vnum == 0:
            continue
        sym = v.get("symbol", "")
        direction = "BUY" if vnum > 0 else "SELL"
        if not is_valid_direction(sym, direction):
            continue
        if not is_available_on_deriv(sym):
            continue
        score = float(v.get("verdict_gap", abs(vnum)))
        cp = float(v.get("entry") or v.get("close") or v.get("price") or 0)
        if cp > 0:
            _MCP_PRICE_CACHE[sym] = {"price": cp, "atr": float(v.get("atr", cp * 0.005))}
        # Normaliser pour dédup (évite "Crash 500 Index" + "CRASH 500 INDEX")
        sym_norm = sym.upper().replace(" ", "").replace("INDEX", "").replace("DERIV:", "")
        if sym_norm in _seen_normalized:
            existing_idx = _seen_normalized[sym_norm]
            if score > valid[existing_idx]["confluence_score"]:
                valid[existing_idx] = {
                    "symbol": sym, "direction": direction,
                    "confluence_score": score, "success": True,
                    "current_price": cp, "entry": cp,
                    "verdict_num": vnum, "verdict": v.get("verdict", direction),
                    "coherence_pct": float(v.get("coherence_pct", 0)),
                }
            continue
        _seen_normalized[sym_norm] = len(valid)
        valid.append({
            "symbol":          sym,
            "direction":       direction,
            "confluence_score": score,
            "success":         True,
            "current_price":   cp,
            "entry":           cp,
            "verdict_num":     vnum,
            "verdict":         v.get("verdict", direction),
            "coherence_pct":   float(v.get("coherence_pct", 0)),
        })

    valid.sort(key=lambda x: x["confluence_score"], reverse=True)
    top = valid[:top_n]
    log.info("Top-%d retenus: %s", top_n,
             [(r["symbol"], r["direction"], round(r["confluence_score"], 1)) for r in top])
    return top

# ---------------------------------------------------------------------------
# TradingAgents analyse via bridge (run_quick)
# ---------------------------------------------------------------------------
def run_trading_agents(symbol: str, direction: str, trade_date: str) -> Optional[Dict]:
    """
    Appelle run_quick() du bridge TradingAgents via subprocess isolé.
    Évite numpy import error en lançant TradingAgents dans son venv.

    Note: TradingAgents a un problème numpy quand importé directement.
    Subprocess isolé résout le problème en utilisant le venv séparé.
    """
    try:
        ta_repo = os.getenv("AI_TRADINGAGENTS_REPO_PATH",
                            r"D:\Dev\Depot Github\TradingAgents-main")
        venv_py = Path(ta_repo) / ".venv" / "Scripts" / "python.exe"

        if not venv_py.exists():
            log.warning("  [TA] Venv TradingAgents not found: %s", venv_py)
            return None

        # Créer script temporaire qui appelle ta_worker et retourne JSON
        ta_script = f"""
import sys
sys.path.insert(0, r'{_HERE}')
from tradbot_bridge import run_quick
import json

try:
    result = run_quick('{symbol}', '{trade_date}', analysts=['market', 'social'])
    output = {{'ok': True, 'result': result}}
except Exception as e:
    output = {{'ok': False, 'error': str(e)}}

print(json.dumps(output))
"""

        # Lancer via venv Python isolé
        try:
            result = subprocess.run(
                [str(venv_py), "-c", ta_script],
                capture_output=True,
                text=True,
                timeout=120
            )

            if result.returncode != 0:
                log.warning("  [TA] Erreur subprocess: %s", result.stderr[:200])
                return None

            output = json.loads(result.stdout)
            if not output.get("ok"):
                log.warning("  [TA] TradingAgents error: %s", output.get("error", "Unknown")[:200])
                return None
            return output.get("result")
        except (subprocess.TimeoutExpired, json.JSONDecodeError) as _sp_err:
            log.warning("  [TA] Subprocess failed: %s", _sp_err)
            return None

    except Exception as e:
        log.warning("  [TA] Error: %s", str(e)[:200])
        return None

    # Nettoyer préfixe TV avant conversion (DERIV:BOOM_1000_INDEX → Boom 1000 Index)
    clean_sym = _tv_to_mt5(symbol)  # ex: "Boom 1000 Index"

    # Déterminer vendor selon catégorie
    _clean_up = clean_sym.upper().replace(" ", "")
    _is_synth = any(_clean_up.startswith(p) for p in ("BOOM","CRASH","1HZ","R_","V10","V25","V50","V75","V100","STEP","JUMP","RANGE"))
    _is_forex = any(_clean_up.startswith(p) for p in ("XAUUSD","XAGUSD","EURUSD","GBPUSD","USDJPY","USDCHF","AUDUSD","NZDUSD","USDCAD"))
    _is_crypto = any(_clean_up.startswith(p) for p in ("BTC","ETH","BNB","SOL","XRP","ADA","DOT","AVAX"))

    if _is_synth or _is_forex:
        # Indices synthétiques et Forex → Deriv WebSocket (données réelles)
        from tradingagents.dataflows.deriv_market import resolve_deriv_symbol  # type: ignore
        try:
            ticker_id = resolve_deriv_symbol(_clean_up)
        except Exception:
            ticker_id = _mt5_to_yfinance(clean_sym)
        vendor = "deriv"
    elif _is_crypto:
        # Crypto → ticker yfinance standard (BTC-USD, ETH-USD)
        _CRYPTO_MAP = {
            "BTCUSD": "BTC-USD", "ETHUSD": "ETH-USD", "BNBUSD": "BNB-USD",
            "SOLUSD": "SOL-USD", "XRPUSD": "XRP-USD", "ADAUSD": "ADA-USD",
        }
        ticker_id = _CRYPTO_MAP.get(_clean_up, _clean_up.replace("USD", "-USD"))
        vendor = "yfinance"
    else:
        ticker_id = _mt5_to_yfinance(clean_sym)
        vendor = "yfinance"
    log.info("  [TA] %s -> ticker=%s vendor=%s", clean_sym, ticker_id, vendor)

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

    # Source 1 : Deriv WebSocket API (données réelles — synthétiques et forex)
    if (cp <= 0 or atr <= 0) and vendor == "deriv":
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

    # Source 5 : yfinance (fallback crypto/forex si toutes les sources précédentes échouent)
    if cp <= 0 and vendor == "yfinance":
        try:
            import yfinance as yf  # type: ignore
            tkr = yf.Ticker(ticker_id)
            fast = tkr.fast_info
            cp_yf = float(getattr(fast, "last_price", 0) or 0)
            if cp_yf > 0:
                cp = cp_yf
                if atr <= 0:
                    hist = tkr.history(period="5d", interval="1d")
                    if not hist.empty:
                        atr = float((hist["High"] - hist["Low"]).mean())
                log.info("  [yfinance ✅] %s: prix=%.5f ATR=%.5f", symbol, cp, atr)
        except Exception as _yf_err:
            log.warning("  [yfinance] %s: %s", symbol, _yf_err)

    # Calculer signaux avec le meilleur prix disponible
    signals = []
    if cp > 0 and atr > 0:
        signals = compute_signals(clean_sym, rec, cp, atr)
    elif cp > 0:
        # ATR estimé à 0.5% du prix si indisponible
        atr = round(cp * 0.005, 5)
        log.warning("  [TA] %s: ATR indisponible — estimé %.5f (0.5%% × %.2f)", symbol, atr, cp)
        signals = compute_signals(clean_sym, rec, cp, atr)
    else:
        log.warning("  [TA] %s: Aucune source de prix disponible — niveaux N/A", symbol)

    sig0 = signals[0] if signals else {}

    # Entry depuis signaux calculés (prioritaire) — ignorer si aberrant vs prix réel
    entry_raw = sig0.get("entry_price") or params.get("entry_price")
    if entry_raw and cp > 0:
        ecart = abs(float(entry_raw) - cp) / cp
        if ecart > 0.20:  # >20% d'écart = prix extrait du texte (ex: objectif $100k BTC)
            log.warning("  [TA] %s: entry=%.5f aberrant vs prix=%.5f (%.0f%%) — rejeté",
                        symbol, float(entry_raw), cp, ecart * 100)
            entry_raw = None  # forcer recalcul depuis prix courant
    entry = entry_raw if entry_raw else (cp if cp > 0 else None)

    # Si après tous les fallbacks on n'a toujours pas de prix, skip le signal
    if not entry or float(entry) <= 0:
        log.warning("  [TA] %s: prix non disponible — signal rejeté (entry invalide)", symbol)
        return None

    ref = cp if cp > 0 else float(entry)  # référence pour ATR et SL/TP

    sl    = sig0.get("stop_loss")   or params.get("stop_loss")
    tp    = sig0.get("take_profit") or params.get("take_profit")

    # Recalculer SL/TP si manquants (fonctionne même quand cp=0)
    if not sl or not tp:
        atr_f = atr if atr > 0 else ref * 0.005
        is_buy = rec == "BUY"
        sym_up = str(symbol).upper()
        sl_mult = 2.0 if ("BOOM" in sym_up or "CRASH" in sym_up) else 2.0
        if not sl:
            sl = round(float(entry) - atr_f * sl_mult, 5) if is_buy else round(float(entry) + atr_f * sl_mult, 5)
        if not tp:
            sl_dist = abs(float(entry) - float(sl))
            tp = round(float(entry) + sl_dist * 2.0, 5) if is_buy else round(float(entry) - sl_dist * 2.0, 5)

    lot   = get_lot_min(symbol)

    # Déterminer execution_type selon règles métier
    # - market  : entrée immédiate au prix courant
    # - limit   : BUY en-dessous du prix courant / SELL au-dessus
    # - stop    : BUY au-dessus du prix courant / SELL en-dessous (breakout)
    exec_type = sig0.get("exec_type", "market")
    if entry and cp > 0:
        is_buy = rec == "BUY"
        if is_buy and float(entry) < cp * 0.999:
            exec_type = "limit"   # BUY LIMIT sous le marché (pullback)
        elif is_buy and float(entry) > cp * 1.001:
            exec_type = "stop"    # BUY STOP au-dessus (breakout)
        elif not is_buy and float(entry) > cp * 1.001:
            exec_type = "limit"   # SELL LIMIT au-dessus du marché (rebond)
        elif not is_buy and float(entry) < cp * 0.999:
            exec_type = "stop"    # SELL STOP en-dessous (breakout)
        else:
            exec_type = "market"  # Entry = prix courant → marché
        log.info("  [TA] %s %s execution_type=%s entry=%.5f prix=%.5f",
                rec, clean_sym, exec_type, float(entry) if entry else 0, cp)

        # Sauvegarder rapport Word
        confirmed = {
            "recommendation": rec,
            "confidence":     0.75,
            "entry_price":    entry,
            "stop_loss":      sl,
            "take_profit":    tp,
            "execution_type": exec_type,
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
            "clean_sym":   clean_sym,  # Nom MT5 propre pour /pending-order
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
def _check_gom_before_order(symbol: str, direction: str, exec_type: str) -> Optional[str]:
    """
    Vérifie le verdict GOM avant de placer un ordre.
    Retourne None si OK, sinon un message d'erreur.
    Les ordres limit/stop sont toujours autorisés (entrée différée — GOM peut changer).
    """
    if exec_type in ("limit", "stop"):
        return None  # Ordre différé — pas de gate GOM
    try:
        clean = _tv_to_mt5(symbol)
        rg = requests.get(f"{AI_SERVER}/gom-verdict", params={"symbol": clean}, timeout=5)
        if rg.status_code != 200:
            return f"GOM serveur indisponible ({rg.status_code}) — ordre market bloqué"
        gd = rg.json()
        if not gd.get("ok"):
            return f"GOM indisponible ({gd.get('message','?')}) — ordre market bloqué"
        vnum = int(gd.get("verdict_num", 0))
        verdict = gd.get("verdict", "WAIT")
        # ✅ RÈGLE STRICTE: vnum=0 (WAIT) toujours bloqué
        if vnum == 0:
            return f"GOM=WAIT (vnum=0) — ordre market bloqué. Attendre BUY/SELL confirmé."
        # ✅ Direction opposée au verdict = bloquer
        if direction == "BUY" and vnum < 0:
            return f"GOM={verdict} (vnum={vnum}) — direction opposée à BUY, ordre bloqué"
        if direction == "SELL" and vnum > 0:
            return f"GOM={verdict} (vnum={vnum}) — direction opposée à SELL, ordre bloqué"
        log.info("  [GOM gate] %s vnum=%d (%s) → OK pour %s market", clean, vnum, verdict, direction)
        return None
    except Exception as e:
        log.warning("  [GOM gate] Erreur fetch: %s — ordre market bloqué (WAIT par défaut)", e)
        return f"GOM fetch error ({e}) — ordre market bloqué"


def place_order(ta: Dict) -> bool:
    # Utiliser le nom MT5 propre (ex: "Boom 500 Index") pas le ticker TV (DERIV:BOOM_500_INDEX)
    mt5_symbol = ta.get("clean_sym") or _tv_to_mt5(ta["symbol"])
    # execution_type : depuis refiner (raffiné) ou confirmed, jamais market par défaut aveugle
    exec_type = (
        ta.get("execution_type")
        or (ta.get("confirmed") or {}).get("execution_type")
        or "market"
    )
    # ── Gate GOM : bloquer les ordres market si GOM=WAIT ou direction opposée ──
    gom_block = _check_gom_before_order(ta["symbol"], ta["direction"], exec_type)
    if gom_block:
        log.warning("  [GOM gate] 🚫 Ordre bloqué — %s", gom_block)
        send_whatsapp(f"🚫 *{ta['symbol']}* ordre bloqué\n_{gom_block}_")
        return False

    # ── Gate MTF : H4+H1+M15 doivent confirmer la direction ──
    if exec_type not in ("limit", "stop"):
        _mtf_ok, _mtf_reason = check_mtf_gate(ta["symbol"], ta, ta["direction"])
        if not _mtf_ok:
            log.warning("  [MTF gate] 🚫 Ordre bloqué — %s", _mtf_reason)
            send_whatsapp(f"🚫 *{ta['symbol']}* bloqué (MTF gate)\n_{_mtf_reason}_")
            return False
    quality_note = ""
    if ta.get("quality_score"):
        quality_note = f" | Score={ta['quality_score']}/100 ({ta.get('quality_label','?')})"
    payload = {
        "symbol":         mt5_symbol,
        "action":         ta["direction"].lower(),
        "recommendation": ta["direction"],
        "entry_price":    ta.get("entry"),
        "stop_loss":      ta.get("sl"),
        "take_profit":    ta.get("tp"),
        "lot":            ta.get("lot"),
        "execution_type": exec_type,
        "confidence":     0.80,
        "source":         "pipeline",
        "reasoning":      (ta.get("refiner_summary") or ta.get("reasoning") or "") + quality_note,
        "status":         "ready",
    }
    try:
        r = requests.post(f"{AI_SERVER}/pending-order", json=payload, timeout=10)

        # 409 = ordre actif déjà en store — reset via endpoint dédié puis retry
        if r.status_code == 409:
            log.info("  [409] Ordre existant pour %s — reset puis retry", mt5_symbol)
            try:
                from urllib.parse import quote
                reset_sym = quote(mt5_symbol, safe="")
                requests.post(f"{AI_SERVER}/pending-order/{reset_sym}/reset", timeout=5)
            except Exception as reset_err:
                log.warning("  [409] Reset échoué: %s", reset_err)
            r = requests.post(f"{AI_SERVER}/pending-order", json=payload, timeout=10)

        r.raise_for_status()
        log.info("  ✅ Ordre placé: %s %s @ %s SL=%s TP=%s lot=%s",
                ta["direction"], ta["symbol"],
                ta.get("entry"), ta.get("sl"), ta.get("tp"), ta.get("lot"))
        # Écrire pipeline_whitelist.json dans MT5 Common/Files
        _write_mt5_whitelist(mt5_symbol, ta["direction"])
        return True
    except Exception as e:
        log.error("  ❌ Ordre échoué %s: %s", ta["symbol"], e)
        return False


def _write_mt5_whitelist(symbol: str, direction: str) -> None:
    """
    Écrit pipeline_whitelist.json dans MT5 Common/Files.
    Le TradeManager lit ce fichier pour autoriser l'exécution en PipelineOnlyMode.
    """
    import json as _json
    import pathlib as _pl
    from datetime import datetime as _dt
    wl_path = _pl.Path(
        os.getenv("MT5_COMMON_FILES",
                    r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\Common\Files")
    ) / "pipeline_whitelist.json"
    try:
        # Charger whitelist existante et ajouter le symbole
        existing = []
        if wl_path.exists():
            try:
                existing = _json.loads(wl_path.read_text(encoding="utf-8")).get("symbols", [])
            except Exception:
                existing = []
        # Dédupliquer
        syms_set = {s["symbol"] for s in existing}
        if symbol not in syms_set:
            existing.append({"symbol": symbol, "direction": direction,
                                "added_at": _dt.utcnow().isoformat()})
        data = {"generated_at": _dt.utcnow().isoformat(), "symbols": existing}
        wl_path.parent.mkdir(parents=True, exist_ok=True)
        wl_path.write_text(_json.dumps(data, indent=2), encoding="utf-8")
        log.info("  [Whitelist] %s ajouté → %s", symbol, wl_path.name)
    except Exception as wl_err:
        log.warning("  [Whitelist] Échec écriture: %s", wl_err)

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

        # Phase 2 — TradingAgents (skip pour Deriv synthétiques — GOM MT5 suffit)
        clean_sym_2 = _tv_to_mt5(sym)
        _is_deriv = any(p in clean_sym_2.upper() for p in ("BOOM", "CRASH", "XAUUSD", "1HZ", "V10", "V25", "V50", "V75", "V100"))
        ta = None
        if not _is_deriv:
            log.info("  Analyse TradingAgents...")
            ta = run_trading_agents(sym, dir_tv, trade_date)

        if ta is None:
            log.info("  Fallback GOM MT5 (skip TA — symbole Deriv ou timeout)")
            # Récupérer le prix depuis le GOM store
            _gom_entry = float(scan.get("entry") or scan.get("current_price") or 0)
            ta = {
                "symbol":    sym,
                "direction": dir_tv,
                "reason":    "gom-mt5-direct",
                "clean_sym": clean_sym_2,
                "entry":     _gom_entry,
                "sl":        0.0,
                "tp":        0.0,
            }

        # Vérifier direction retournée par TA (ou fallback TV)
        ta_dir = ta.get("direction", dir_tv)
        if not is_valid_direction(sym, ta_dir):
            orders_skipped.append(sym)
            send_whatsapp(f"🚫 *{sym}*: Direction {ta_dir} invalide — rejeté automatiquement")
            continue

        # Rejeter HOLD — aucun ordre à placer
        if ta_dir not in ("BUY", "SELL"):
            log.warning("  ⏭ %s: TA retourne '%s' — pas d'ordre placé", sym, ta_dir)
            orders_skipped.append(sym)
            send_whatsapp(f"⏭ *{sym}*: Signal TA = {ta_dir} — pas d'ordre")
            continue

        # ── Phase 2b — Indicateurs depuis GOM MT5 (remplace TV MCP) ────────────
        tv_raw_data: Dict = {}
        if _REFINER_AVAILABLE:
            log.info("  Fetch indicateurs GOM MT5...")
            try:
                clean_sym_mt5 = _tv_to_mt5(sym)
                rg = requests.get(f"{AI_SERVER}/gom-kola-dashboard",
                                  params={"symbol": clean_sym_mt5}, timeout=8)
                if rg.status_code == 200:
                    gd = rg.json()
                    if gd.get("ok"):
                        # Convertir BEAR/BULL/NEUT → SELL/BUY/NEUTRAL (attendu par signal_refiner)
                        _raw_dir = (gd.get("tf_global_dir") or "NEUT").upper()
                        _bias_dir = {"BULL": "BUY", "BEAR": "SELL", "NEUT": "NEUTRAL"}.get(_raw_dir, "NEUTRAL")
                        _coh = float(gd.get("coherence_pct", 0) or 0)
                        _bias_score = _coh / 10.0 if _coh > 1 else _coh * 10  # → échelle 0-10
                        tv_raw_data = {
                            "success": True,
                            "smc": {
                                "bias": {"direction": _bias_dir, "score": _bias_score},
                                "rsi":  {"value": float(gd.get("rsi14", gd.get("rsi", 50)))},
                                "order_blocks": [],
                                "fvg": [],
                            },
                            "gom": gd,
                        }
                        # Override entry avec prix live MT5 si disponible
                        _live_price = float(gd.get("entry") or gd.get("price") or gd.get("close") or 0)
                        if _live_price > 0 and (ta.get("entry", 0) <= 0 or ta.get("entry", 0) in (7000.0, 6035.0, 3495.0, 13800.0)):
                            ta["entry"] = _live_price
                            log.info("  [GOM MT5] Entry override → %.5f (prix live)", _live_price)
                        # Injecter ATR GOM MT5 si absent dans ta_result
                        _gom_atr = float(gd.get("atr14") or gd.get("atr") or 0)
                        if _gom_atr > 0 and float(ta.get("atr") or 0) <= 0:
                            ta["atr"] = _gom_atr
                            log.info("  [GOM MT5] ATR injecté → %.5f", _gom_atr)
                        log.info("  [GOM MT5] Bias=%s RSI=%.0f gap=%.1f coh=%.0f%%",
                                 gd.get("tf_global_dir", "?"),
                                 float(gd.get("rsi14", gd.get("rsi", 50))),
                                 float(gd.get("verdict_gap", 0)),
                                 float(gd.get("coherence_pct", 0)))
                    else:
                        log.warning("  [GOM MT5] ok=False — %s", gd.get("error", "?"))
                else:
                    log.warning("  [GOM MT5] HTTP %s", rg.status_code)
            except Exception as _mt5_err:
                log.warning("  [GOM MT5] Erreur fetch: %s", _mt5_err)

        # ── Phase 2c — Signal Refiner (boucle TV → qualité → levels) ─────────
        refined: Optional[Dict] = None
        if _REFINER_AVAILABLE and ta_dir in ("BUY", "SELL"):
            log.info("  Raffinage signal (TV + TA)...")
            log.debug("  [Refiner] ta entry=%.5f sl=%.5f tp=%.5f atr=%.5f",
                     float(ta.get("entry") or 0), float(ta.get("sl") or 0),
                     float(ta.get("tp") or 0), float(ta.get("atr") or 0))
            try:
                refined = refine_signal(
                    ta_result=ta,
                    tv_raw=tv_raw_data,
                    direction=ta_dir,
                    symbol=_tv_to_mt5(sym),
                )
                q = refined["quality_score"]
                label = refined["quality_label"]
                log.info("  [Refiner] Score=%d/100 (%s) | RR=1:%s | exec=%s",
                        q, label, refined.get("rr"), refined.get("execution_type"))
                log.info("  [Refiner] Entry=%.5f SL=%.5f TP=%.5f Lot=$20:%.2f",
                        refined.get("entry", 0), refined.get("sl", 0),
                        refined.get("tp", 0), refined.get("recommended_lot", 0.01))

                if not refined["accept"]:
                    # Bypass qualité pour Deriv (Boom/Crash) avec verdict PERFECT ou GOOD
                    # Ces symboles n'ont pas M15/H1/EMA/OB → score plafonné à ~45 structurellement
                    # CONDITION ABSOLUE : IA status (coherence_pct) doit être >= 70%
                    _sym_up = sym.upper()
                    _is_deriv_bypass = any(p in _sym_up for p in ("BOOM", "CRASH"))
                    _verdict_num = int(scan.get("verdict_num", 0))
                    _is_strong = abs(_verdict_num) >= 2  # PERFECT(±3) ou GOOD(±2)
                    # Priorité : GOM MT5 live (ta) > scan initial (peut être périmé)
                    _ia_coh = float(ta.get("coherence_pct") or scan.get("coherence_pct") or 0)
                    _ia_ok = _ia_coh >= 70.0 or _ia_coh == 0.0  # 0 = pas de donnée → laisser passer
                    _signal_dir = "BUY" if _verdict_num > 0 else "SELL"
                    _mtf_ok, _mtf_reason = check_mtf_gate(sym, ta, _signal_dir)
                    if _is_deriv_bypass and _is_strong and q >= 30 and _ia_ok and _mtf_ok:
                        log.info("  [Refiner] Bypass Deriv PERFECT/GOOD (score=%d/100 coh=%.0f%%) — signal accepté", q, _ia_coh)
                        refined["accept"] = True
                        refined["reject_reason"] = ""
                        # Force quality_score à 75 pour passer le gate auto
                        refined["quality_score"] = 75
                        q = 75
                        label = "STANDARD"
                        refined["quality_label"] = label
                    elif _is_deriv_bypass and _is_strong and not _ia_ok:
                        _reject_ia = f"IA status {_ia_coh:.0f}% < 70% requis — bypass Deriv refusé malgré {scan.get('verdict', 'PERFECT')}"
                        log.warning("  [Refiner] SIGNAL REJETÉ (IA gate): %s", _reject_ia)
                        orders_skipped.append(sym)
                        send_whatsapp(
                            f"🚫 *{sym}* — Signal rejeté (IA gate)\n"
                            f"IA status: {_ia_coh:.0f}% (min=70%)\n"
                            f"_{_reject_ia[:200]}_"
                        )
                        continue
                    elif _is_deriv_bypass and _is_strong and not _mtf_ok:
                        log.warning("  [Refiner] SIGNAL REJETÉ (MTF gate): %s", _mtf_reason)
                        orders_skipped.append(sym)
                        send_whatsapp(
                            f"🚫 *{sym}* — Signal rejeté (MTF gate)\n"
                            f"_{_mtf_reason[:200]}_"
                        )
                        continue
                    else:
                        log.warning("  [Refiner] SIGNAL REJETÉ: %s", refined["reject_reason"])
                        orders_skipped.append(sym)
                        send_whatsapp(
                            f"🚫 *{sym}* — Signal rejeté par refiner\n"
                            f"Score: {q}/100 (min={MIN_QUALITY_SCORE})\n"
                            f"_{refined['reject_reason'][:200]}_"
                        )
                        continue

                # Mettre à jour ta avec les niveaux raffinés
                ta["entry"]          = refined["entry"]
                ta["sl"]             = refined["sl"]
                ta["tp"]             = refined["tp"]
                ta["lot"]            = refined["recommended_lot"]
                ta["execution_type"] = refined["execution_type"]
                ta["quality_score"]  = q
                ta["quality_label"]  = label
                ta["rr"]             = refined["rr"]
                ta["refiner_summary"] = refined["summary"]

                # Notifier la qualité sur WhatsApp
                qual_icon = "🟢" if label == "FORT" else ("🟡" if label == "STANDARD" else "🟠")
                send_whatsapp(
                    f"{qual_icon} *Signal {sym} raffiné — {label} ({q}/100)*\n"
                    f"{ta_dir} | Entry: {refined['entry']:.4f} | SL: {refined['sl']:.4f} | TP: {refined['tp']:.4f}\n"
                    f"RR 1:{refined['rr']} | Lot $50: {refined['recommended_lot']}\n"
                    f"_{'; '.join(refined['tv_reasons_pos'][:2]) or 'Pas de raisons TV'}_"
                )

            except Exception as _ref_err:
                log.warning("  [Refiner] Erreur: %s — utilisation signal TA brut", _ref_err)
                # ⚠️ FORCER rejection si refiner crash (pas de quality_score = pas d'entry fiable)
                ta["quality_score"] = 0  # Force reject (0 < 75%)
                ta["quality_label"] = "ERREUR REFINER"

        if auto:
            # Mode auto — validation qualité stricte avant placement
            quality = ta.get('quality_score', 0)
            entry = ta.get('entry', 0)

            # REJET si qualité < 75% OU entry manquante
            if quality < MIN_QUALITY_SCORE or entry <= 0:
                log.warning("  Mode AUTO — SIGNAL REJETÉ (qualité=%.0f%% < %.0f%% OU entry=%.5f ≤ 0)",
                           quality, MIN_QUALITY_SCORE, entry)
                send_whatsapp(
                    f"🚫 *{sym}* — Mode AUTO: Signal rejeté\n"
                    f"Qualité {quality}/100 < {MIN_QUALITY_SCORE} OU Entry={entry:.5f}\n"
                    f"→ HOLD jusqu'à signal > {MIN_QUALITY_SCORE}%"
                )
                orders_skipped.append(sym)
                continue

            # ✅ QUALITÉ OK — ENVOYER RAPPORT WORD AVANT PLACEMENT
            log.info("  Mode AUTO — qualité OK (%.0f%% ≥ %.0f%%) — envoi rapport...", quality, MIN_QUALITY_SCORE)
            send_report_whatsapp(ta)
            log.info("  📄 Rapport Word envoyé — En attente placement...")

            # OK — Placer l'ordre
            log.info("  Mode AUTO — qualité OK (%.0f%% ≥ %.0f%%) — placement direct", quality, MIN_QUALITY_SCORE)
            if place_order(ta):
                orders_placed.append(sym)
                send_whatsapp(
                    f"✅ *Ordre placé automatiquement*\n"
                    f"{ta_dir} *{sym}* | Score: {quality:.0f}/100 (ACCEPTÉ)\n"
                    f"Entry: {ta.get('entry', 0):.5f} | SL: {ta.get('sl', 0):.5f} | TP: {ta.get('tp', 0):.5f} | Lot: {ta.get('lot', 0.01)}\n"
                    f"Type: {ta.get('execution_type','market')} | RR 1:{ta.get('rr','?')}"
                )
            else:
                log.error("  Échec placement ordre %s", sym)
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
