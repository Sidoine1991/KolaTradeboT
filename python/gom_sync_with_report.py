#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Sync + WhatsApp Report — Boucle 10 minutes
Charge gom_signal.json, parse les verdicts, envoie rapport WhatsApp
"""

import json
import time
import os
import sys
import requests
import logging
from datetime import datetime, timezone, timedelta
from pathlib import Path

# Force UTF-8 on Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# Configuration
GOM_FILE = Path("D:/Dev/TradBOT/data/gom_signal.json")
AI_SERVER = "http://127.0.0.1:8000"
LOGS_DIR = Path("D:/Dev/TradBOT/logs")
LOOP_INTERVAL = 600  # 10 minutes en secondes

# Créer le dossier logs s'il n'existe pas
LOGS_DIR.mkdir(exist_ok=True)

# Configuration du logging — fichier fixe en mode append
log_file = LOGS_DIR / "gom_sync.log"
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - gom_sync - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8', mode='a')
    ]
)
logger = logging.getLogger(__name__)

# Ajouter stdout handler sans emojis pour Windows console
class NoEmojiHandler(logging.StreamHandler):
    def emit(self, record):
        msg = record.getMessage()
        msg = msg.replace('🔄', '[SYNC]').replace('✅', '[OK]').replace('❌', '[ERROR]')
        msg = msg.replace('⚠️', '[WARN]').replace('📊', '[REPORT]').replace('📋', '[LOG]')
        msg = msg.replace('📁', '[DIR]').replace('🌐', '[NET]').replace('📤', '[SEND]')
        msg = msg.replace('🚀', '[START]').replace('⏹️', '[STOP]').replace('⏰', '[WAIT]')
        ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f"{ts} - {record.levelname} - {msg}")

logger.addHandler(NoEmojiHandler())

# Mapping des emojis
EMOJI_MAP = {
    3: "🟢",    # PERFECT BUY
    2: "🟢",    # GOOD BUY
    1: "🟢",    # BUY
    -1: "🔴",   # SELL
    -2: "🔴",   # GOOD SELL
    -3: "🔴",   # PERFECT SELL
    0: "⚪"     # WAIT
}

# Mapping des actions
ACTION_MAP = {
    3: "PERFECT BUY",
    2: "GOOD BUY",
    1: "BUY",
    -1: "SELL",
    -2: "GOOD SELL",
    -3: "PERFECT SELL",
    0: "WAIT"
}


_VERDICT_MAX_AGE_HOURS = 1  # Rejeter les verdicts plus vieux que 1h

def _get_ml_score(symbol: str) -> dict | None:
    """
    Appelle GET /ml-metrics/{symbol} sur AI server (non-bloquant, timeout=3s).
    Retourne {action, confidence, accuracy_last20, model} ou None si indisponible.
    """
    try:
        r = requests.get(f"{AI_SERVER}/ml-metrics/{symbol}", timeout=3)
        if r.status_code != 200:
            return None
        data = r.json()
        if not data.get("ml_available"):
            return None
        return {
            "action":         data.get("action", "NEUTRAL"),
            "confidence":     float(data.get("confidence", 0)),
            "accuracy_last20": float(data.get("accuracy_last20", 0.5)),
            "model":          data.get("model"),
        }
    except Exception:
        return None


# Fenêtres de trading UTC par catégorie de symbole.
# Boom/Crash : délégué à l'AI server (bc_heure gate → HTTP 403 si hors fenêtre).
# Autres : gate locale dans _load_from_dashboard().
# Format : liste de (heure_début_incluse, heure_fin_exclusive) en UTC.
_SYMBOL_TRADING_WINDOWS: dict = {
    "XAUUSD": [(7, 17)],    # London open + NY overlap
    "BTCUSD": [(8, 22)],    # sessions EU + US (volume élevé)
    "ETHUSD": [(8, 22)],    # idem BTC
    "NAS100": [(13, 20)],   # NYSE/NASDAQ : 09:30–16:00 EDT = 13:30–20:00 UTC
    "US30":   [(13, 20)],   # même session
}


def _is_in_trading_window(symbol: str, utc_hour: int) -> bool:
    """Retourne True si le symbole est dans sa fenêtre de trading UTC."""
    s = symbol.upper().replace(" ", "")
    for key, windows in _SYMBOL_TRADING_WINDOWS.items():
        if key in s:
            return any(start <= utc_hour < end for start, end in windows)
    return True  # Boom/Crash gérés par AI server, autres sans restriction connue


def _verdict_age_hours(v: dict) -> float:
    """Retourne l'âge du verdict en heures. Retourne 999 si timestamp absent/invalide."""
    ts = v.get("timestamp") or v.get("updated_at")
    if not ts:
        return 999.0
    try:
        raw = str(ts).replace("Z", "+00:00")
        dt = datetime.fromisoformat(raw)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return (datetime.now(timezone.utc) - dt.astimezone(timezone.utc)).total_seconds() / 3600
    except Exception:
        return 999.0


def _dedup_verdicts(verdicts: list) -> list:
    """Déduplique par symbole normalisé — garde le verdict avec le timestamp le plus récent.
    Filtre aussi les verdicts stales (> 1h).
    """
    now = datetime.now(timezone.utc)
    fresh = []
    stale_count = 0
    for v in verdicts:
        age = _verdict_age_hours(v)
        if age > _VERDICT_MAX_AGE_HOURS:
            stale_count += 1
            continue
        fresh.append(v)
    if stale_count:
        logger.warning(f"[STALE] {stale_count} verdict(s) ignorés (timestamp > {_VERDICT_MAX_AGE_HOURS}h)")

    seen: dict = {}
    for v in fresh:
        key = v.get("symbol", "").upper().replace(" ", "").replace("_", "").replace("INDEX", "")
        existing = seen.get(key)
        if existing is None:
            seen[key] = v
        else:
            ts_new = str(v.get("timestamp", ""))
            ts_old = str(existing.get("timestamp", ""))
            if ts_new > ts_old:
                seen[key] = v
    return list(seen.values())


_DASHBOARD_SYMBOLS = [
    "BOOM 300 INDEX", "BOOM 500 INDEX", "BOOM 900 INDEX", "BOOM 1000 INDEX",
    "CRASH 300 INDEX", "CRASH 500 INDEX", "CRASH 900 INDEX", "CRASH 1000 INDEX",
    "XAUUSD", "BTCUSD", "ETHUSD", "NAS100", "US30",
]

def _is_verdict_coherent_with_trend(vn: int, d: dict, sym: str) -> bool:
    """Vérifie que le verdict est cohérent avec la tendance globale MTF.

    Un verdict contre-tendance (ex: BUY sur Boom en BEAR global) n'est accepté
    que si spike_tradable=True (spike imminent confirmé par le detector).
    """
    tf_global = d.get("tf_global_dir", "NEUT")
    spike_tradable = d.get("spike_tradable") or False
    score_buy = float(d.get("score_buy", 0) or 0)
    score_sell = float(d.get("score_sell", 0) or 0)
    s = sym.upper()
    is_boom = "BOOM" in s
    is_crash = "CRASH" in s

    if is_boom or is_crash:
        # Détecter une inversion de score (serveur bugué ou spike guard actif)
        # Sur Boom: vn>0 mais score_sell > score_buy → inversion non confirmée
        if is_boom and vn > 0 and score_sell > score_buy and not spike_tradable:
            return False
        # Sur Crash: vn<0 mais score_buy > score_sell → inversion non confirmée
        if is_crash and vn < 0 and score_buy > score_sell and not spike_tradable:
            return False

    # Pour les autres actifs : vérifier cohérence tendance globale
    if not is_boom and not is_crash:
        if vn > 0 and tf_global == "BEAR":
            tf_strength = int(d.get("tf_global_strength", 0) or 0)
            if tf_strength >= 5:  # tendance forte — rejeter
                return False
        if vn < 0 and tf_global == "BULL":
            tf_strength = int(d.get("tf_global_strength", 0) or 0)
            if tf_strength >= 5:
                return False

    return True


def _load_from_dashboard() -> list:
    """Charge verdicts directement depuis /gom-kola-dashboard (calcul live MT5 temps réel)."""
    verdicts = []
    for sym in _DASHBOARD_SYMBOLS:
        try:
            r = requests.get(
                f"{AI_SERVER}/gom-kola-dashboard",
                params={"symbol": sym, "chart_tf": "M1"},
                timeout=5,
            )
            if r.status_code != 200:
                continue
            d = r.json()
            if not d.get("ok"):
                continue
            vn = d.get("verdict_num", 0)
            verdict = d.get("verdict", "WAIT")
            if vn == 0 or verdict == "WAIT":
                continue
            # Gate session horaire UTC — hors fenêtre propice = ordre ignoré
            utc_hour = datetime.now(timezone.utc).hour
            if not _is_in_trading_window(sym, utc_hour):
                logger.warning(f"[GATE-SESSION] {sym}: heure UTC {utc_hour:02d}h hors fenêtre propice — rejeté")
                continue

            # Rejeter les verdicts contre-tendance sans spike confirmé
            if not _is_verdict_coherent_with_trend(vn, d, sym):
                logger.warning(f"[TREND-FILTER] {sym}: {verdict} (vn={vn}) rejeté — contre-tendance sans spike confirmé")
                continue

            # Gate RSI extreme : BUY sur RSI>78 ou SELL sur RSI<22 = entrée retardée
            rsi_val = float(d.get("rsi") or d.get("rsi14") or 50)
            if vn > 0 and rsi_val > 78:
                logger.warning(f"[GATE-RSI] {sym}: RSI {rsi_val:.0f} overbought (>78) — BUY rejeté")
                continue
            if vn < 0 and rsi_val < 22:
                logger.warning(f"[GATE-RSI] {sym}: RSI {rsi_val:.0f} oversold (<22) — SELL rejeté")
                continue

            # Gate M15 opposé : M15 contre la direction = setup non confirmé
            m15 = d.get("tf_m15_dir", "NEUT")
            if vn > 0 and m15 == "BEAR":
                logger.warning(f"[GATE-M15] {sym}: M15=BEAR opposé à BUY — rejeté")
                continue
            if vn < 0 and m15 == "BULL":
                logger.warning(f"[GATE-M15] {sym}: M15=BULL opposé à SELL — rejeté")
                continue

            verdicts.append({
                "symbol": sym,
                "verdict_num": vn,
                "verdict": verdict,
                "coherence_pct": d.get("coherence_pct", 0),
                "filter_ratio": d.get("filter_ratio", 0),
                "entry": d.get("entry", d.get("price", 0)),
                "sl": d.get("sl", 0),
                "tp": d.get("tp", 0),
                "kola_buy": d.get("kola_buy", 0),
                "kola_sell": d.get("kola_sell", 0),
                "bb_up": d.get("bb_up", 0),
                "bb_dn": d.get("bb_dn", 0),
                "score_buy": d.get("score_buy", 0),
                "score_sell": d.get("score_sell", 0),
                "tf_global_dir": d.get("tf_global_dir", "NEUT"),
                "tf_global_strength": d.get("tf_global_strength", 0),
                "tf_m1_dir": d.get("tf_m1_dir", "NEUT"),
                "tf_m5_dir": d.get("tf_m5_dir", "NEUT"),
                "tf_m15_dir": d.get("tf_m15_dir", "NEUT"),
                "tf_h1_dir": d.get("tf_h1_dir", "NEUT"),
                "tf_h4_dir": d.get("tf_h4_dir", "NEUT"),
                "tf_d1_dir": d.get("tf_d1_dir", "NEUT"),
                "rsi": d.get("rsi", 50),
                "atr": d.get("atr", 0),
                "source": "mt5_live_dashboard",
                "timestamp": d.get("timestamp", ""),
            })
        except Exception:
            continue
    return verdicts


def load_gom_signals():
    """Charge les verdicts GOM — priorité dashboard MT5 live, puis store, puis fichier."""
    # Priorité 1 : /gom-kola-dashboard — calcul temps réel depuis candles MT5 fraîches
    try:
        dashboard_verdicts = _load_from_dashboard()
        if dashboard_verdicts:
            logger.info(f"[OK] Charge {len(dashboard_verdicts)} verdicts GOM depuis dashboard MT5 LIVE")
            return dashboard_verdicts
    except Exception:
        pass

    # Priorité 2 : /gom-verdicts store mémoire
    try:
        resp = requests.get(f"{AI_SERVER}/gom-verdicts", timeout=5)
        if resp.status_code == 200:
            data = resp.json()
            verdicts = data.get("verdicts", data) if isinstance(data, dict) else data
            if isinstance(verdicts, list) and verdicts:
                verdicts = _dedup_verdicts(verdicts)
                logger.info(f"[OK] Charge {len(verdicts)} verdicts GOM depuis serveur LIVE (/gom-verdicts)")
                return verdicts
    except Exception:
        pass

    # Fallback : fichier JSON local
    try:
        with open(GOM_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)

        verdicts = []
        if isinstance(data, dict):
            verdicts = data.get('verdicts') or [v for v in data.values() if isinstance(v, dict)]
        elif isinstance(data, list):
            verdicts = data

        logger.warning(f"[WARN] Serveur indisponible — charge {len(verdicts)} verdicts depuis {GOM_FILE} (peut être stale)")
        return verdicts
    except Exception as e:
        logger.error(f"[ERROR] Erreur chargement GOM: {e}")
        return []


def _valid_direction(symbol: str, verdict_num: int) -> bool:
    """Vérifie cohérence Boom=BUY only / Crash=SELL only."""
    s = symbol.upper()
    if "BOOM" in s and verdict_num < 0:
        return False
    if "CRASH" in s and verdict_num > 0:
        return False
    return True


_TF_DIR_ICON = {"BULL": "🟢", "BEAR": "🔴", "NEUT": "⚪"}

def _fmt_tf_row(v: dict) -> str:
    """Ligne MTF : M1 M5 M15 H1 H4 D1 avec icônes couleur."""
    tfs = [
        ("M1",  v.get("tf_m1_dir",  "NEUT")),
        ("M5",  v.get("tf_m5_dir",  "NEUT")),
        ("M15", v.get("tf_m15_dir", "NEUT")),
        ("H1",  v.get("tf_h1_dir",  "NEUT")),
        ("H4",  v.get("tf_h4_dir",  "NEUT")),
        ("D1",  v.get("tf_d1_dir",  "NEUT")),
    ]
    # Afficher seulement si au moins un TF a une direction connue
    if all(d == "NEUT" for _, d in tfs):
        return ""
    parts = [f"{_TF_DIR_ICON.get(d, '⚪')}{tf}" for tf, d in tfs]
    return "  " + " ".join(parts)


def build_report(verdicts):
    """Construit un rapport formaté avec les verdicts actifs et les directions par TF."""
    raw_active = [v for v in verdicts if v.get('verdict_num', 0) != 0]
    active_verdicts = [v for v in raw_active if _valid_direction(v.get('symbol', ''), v.get('verdict_num', 0))]
    if len(active_verdicts) < len(raw_active):
        logger.warning(f"[FILTER] {len(raw_active)-len(active_verdicts)} verdict(s) filtrés (direction Boom/Crash invalide)")

    if not active_verdicts:
        logger.warning("⚠️ Aucun verdict actif")
        return None

    lines = []
    lines.append("🎯 **GOM VERDICTS REPORT** 📊")
    lines.append("=" * 50)

    for v in active_verdicts:
        symbol = v.get('symbol', 'N/A')
        verdict_num = v.get('verdict_num', 0)
        entry = v.get('entry', 0)
        sl = v.get('sl', 0)
        tp = v.get('tp', 0)
        coherence = v.get('coherence_pct', 0)

        emoji = EMOJI_MAP.get(verdict_num, "⚪")
        action = ACTION_MAP.get(verdict_num, "WAIT")
        in_ote = v.get('in_ote', False)
        ote_top = v.get('ote_top', 0)
        ote_bot = v.get('ote_bot', 0)

        parts = [f"{emoji} {symbol} — {action}", f"Entry: {entry:.2f}"]
        if sl and sl > 0:
            parts.append(f"SL: {sl:.2f}")
        if tp and tp > 0:
            parts.append(f"TP: {tp:.2f}")
        parts.append(f"Coh: {coherence:.0f}%")
        if ote_top > 0 and ote_bot > 0:
            parts.append(f"OTE[{ote_bot:.2f}-{ote_top:.2f}]{'✅' if in_ote else ''}")

        lines.append(" | ".join(parts))

        # Ligne directions par TF
        tf_row = _fmt_tf_row(v)
        if tf_row:
            lines.append(tf_row)

        # Score ML (non-bloquant — absent si ML indisponible)
        ml = _get_ml_score(symbol)
        if ml and ml["confidence"] > 0:
            ml_icon = "🟢" if ml["action"] == "BUY" else "🔴" if ml["action"] == "SELL" else "⚪"
            lines.append(
                f"  🤖 ML: {ml_icon}{ml['action']} {ml['confidence']*100:.0f}%"
                f" | acc={ml['accuracy_last20']*100:.0f}%"
            )

    lines.append("=" * 50)
    lines.append(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}")

    report = "\n".join(lines)
    logger.info(f"📋 Rapport construit ({len(active_verdicts)} signaux actifs)")
    return report


PSYCHOBOT_URL = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com")
WHATSAPP_PHONE = os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346")


def send_whatsapp_report(report):
    """Envoie le rapport via WhatsApp — AI server en priorité, fallback PsychoBot Render."""
    if not report:
        return False

    # Tentative 1 : AI server local
    try:
        url = f"{AI_SERVER}/notify-whatsapp"
        payload = {"event": "gom_report", "symbol": "GOM_VERDICTS", "message": report}
        response = requests.post(url, json=payload, timeout=5)
        if response.status_code == 200:
            logger.info("✅ Rapport WhatsApp envoyé via AI server")
            return True
        logger.warning(f"⚠️ AI server WhatsApp HTTP {response.status_code}")
    except requests.exceptions.RequestException:
        logger.info("[WA] AI server indisponible — fallback PsychoBot Render")

    # Tentative 2 : PsychoBot Render direct
    try:
        response = requests.post(
            f"{PSYCHOBOT_URL}/send-message",
            json={"phone": WHATSAPP_PHONE, "message": report},
            timeout=30,
            verify=False,
        )
        if response.status_code == 200:
            logger.info("✅ Rapport WhatsApp envoyé via PsychoBot Render")
            return True
        logger.warning(f"⚠️ PsychoBot HTTP {response.status_code}: {response.text[:100]}")
    except requests.exceptions.RequestException as e:
        logger.error(f"❌ Erreur WhatsApp (PsychoBot): {e}")

    return False


def _compute_sl_tp_from_levels(v: dict) -> dict:
    """
    Calcule SL/TP depuis les niveaux réels GOM (kola_buy/kola_sell, bb_up/bb_dn, ATR).
    Logique SMC : entry depuis kola niveau, SL = ATR×mult de l'autre côté, TP = niveau opposé.
    """
    symbol = v.get('symbol', '').upper()
    is_synthetic = any(x in symbol for x in ['CRASH', 'BOOM', 'JUMP'])
    direction = 'BUY' if v.get('verdict_num', 0) > 0 else 'SELL'

    entry = float(v.get('entry') or v.get('price') or 0)
    if entry <= 0:
        return v

    atr_raw = float(v.get('atr') or v.get('atr14') or 0)
    kola_buy  = float(v.get('kola_buy')  or 0)
    kola_sell = float(v.get('kola_sell') or 0)
    bb_up = float(v.get('bb_up') or 0)
    bb_dn = float(v.get('bb_dn') or 0)

    # Multiplicateur ATR selon type d'instrument
    atr_sl_mult = 1.5 if is_synthetic else 2.0
    atr_tp_mult = 2.0 if is_synthetic else 1.5
    min_sl_dist = atr_raw * atr_sl_mult if atr_raw > 0 else entry * 0.003

    if direction == "BUY":
        # Entry = kola_buy (niveau support) ou price courant
        if kola_buy > 0 and kola_buy < entry:
            entry = kola_buy
            v['entry'] = round(entry, 5)
        # SL = sous kola_buy d'un ATR, ou sous bb_dn
        if bb_dn > 0 and abs(entry - bb_dn) >= min_sl_dist:
            sl = bb_dn - atr_raw * 0.5 if atr_raw > 0 else bb_dn * 0.998
        else:
            sl = entry - min_sl_dist
        # TP = kola_sell (résistance) ou bb_up
        if kola_sell > entry:
            tp = kola_sell
        elif bb_up > entry:
            tp = bb_up
        else:
            tp = entry + abs(entry - sl) * atr_tp_mult
    else:
        # Entry = kola_sell (niveau résistance) ou price courant
        if kola_sell > 0 and kola_sell > entry:
            entry = kola_sell
            v['entry'] = round(entry, 5)
        # SL = au-dessus kola_sell d'un ATR, ou au-dessus bb_up
        if bb_up > 0 and abs(bb_up - entry) >= min_sl_dist:
            sl = bb_up + atr_raw * 0.5 if atr_raw > 0 else bb_up * 1.002
        else:
            sl = entry + min_sl_dist
        # TP = kola_buy (support) ou bb_dn
        if kola_buy > 0 and kola_buy < entry:
            tp = kola_buy
        elif bb_dn > 0 and bb_dn < entry:
            tp = bb_dn
        else:
            tp = entry - abs(sl - entry) * atr_tp_mult

    # Vérification finale : RR minimum 1.0
    sl_dist = abs(entry - sl)
    tp_dist = abs(entry - tp)
    if sl_dist > 0 and tp_dist < sl_dist:
        tp = entry + sl_dist * atr_tp_mult if direction == "BUY" else entry - sl_dist * atr_tp_mult

    v['sl'] = round(sl, 5)
    v['tp'] = round(tp, 5)
    return v


def _enforce_synthetic_sl_tp(v: dict) -> dict:
    """Délègue à _compute_sl_tp_from_levels si SL/TP manquants ou nuls."""
    sl = float(v.get('sl') or 0)
    tp = float(v.get('tp') or 0)
    if sl == 0 or tp == 0:
        return _compute_sl_tp_from_levels(v)
    return v


# État persistant entre cycles (en mémoire — reset au redémarrage du script)
_prev_verdicts: dict = {}   # symbol → verdict_num du cycle précédent
_wait_notified: set = set() # symboles pour lesquels la notif WAIT a déjà été envoyée


def _get_open_positions() -> list:
    """Récupère les ordres ouverts depuis /pending-orders (statut ready/executed)."""
    try:
        r = requests.get(f"{AI_SERVER}/pending-orders", timeout=5)
        if r.status_code == 200:
            data = r.json()
            return data.get("orders", [])
    except Exception:
        pass
    return []


def _close_position_for_symbol(symbol: str, reason: str) -> bool:
    """
    Enregistre une close request INCONDITIONNELLE via /gom-verdict/close-request.
    Dès que GOM=WAIT, la position est fermée sans condition de perte.
    """
    try:
        payload = {
            "symbol": symbol,
            "reason": reason,
            "force": True,       # fermeture inconditionnelle
            "min_loss_usd": 0,   # pas de seuil
        }
        r = requests.post(f"{AI_SERVER}/gom-verdict/close-request", json=payload, timeout=5)
        if r.status_code == 200:
            logger.info(f"🔒 CloseRequest FORCE enregistrée pour {symbol} — raison: {reason}")
            return True
        logger.warning(f"⚠️ CloseRequest {symbol} HTTP {r.status_code}: {r.text[:100]}")
    except Exception as e:
        logger.error(f"❌ Erreur close request {symbol}: {e}")
    return False


def _place_market_order(symbol: str, direction: str, v: dict) -> bool:
    """
    Place un ordre au marché immédiat via /pending-order (upgrade GOOD→PERFECT).
    """
    try:
        entry = float(v.get("entry") or v.get("price") or 0)
        sl    = float(v.get("sl") or 0)
        tp    = float(v.get("tp") or 0)
        if entry <= 0:
            logger.warning(f"⚠️ Market order {symbol}: entry=0, skip")
            return False
        payload = {
            "symbol": symbol,
            "recommendation": direction,
            "action": direction,
            "entry_price": entry,
            "stop_loss": sl,
            "take_profit": tp,
            "lot": 0.01,
            "execution_type": "market",
            "confidence": 0.95,
            "gom_verdict": v.get("verdict", "PERFECT"),
            "source": "pipeline",
        }
        r = requests.post(f"{AI_SERVER}/pending-order", json=payload, timeout=5)
        if r.status_code in (200, 201):
            logger.info(f"🚀 MARKET ORDER placé: {direction} {symbol} @ {entry:.2f} SL={sl:.2f} TP={tp:.2f}")
            return True
        logger.warning(f"⚠️ Market order {symbol} HTTP {r.status_code}: {r.text[:100]}")
    except Exception as e:
        logger.error(f"❌ Erreur market order {symbol}: {e}")
    return False


MIN_COHERENCE_TO_PLACE = 85  # Gate GOM : cohérence minimum pour placer un ordre


def _check_trading_pause() -> tuple[bool, int]:
    """
    Consulte /trading-pause sur l'AI server.
    Retourne (is_paused, remaining_sec).
    """
    try:
        r = requests.get(f"{AI_SERVER}/trading-pause", timeout=5)
        if r.status_code == 200:
            data = r.json()
            return data.get("active", False), data.get("remaining_sec", 0)
    except Exception:
        pass
    return False, 0


def place_active_orders(verdicts: list) -> list:
    """
    Place immédiatement un ordre marché pour chaque verdict actif :
    - Pause globale inactive (< 3 gains consécutifs sans perte)
    - Cohérence >= MIN_COHERENCE_TO_PLACE (70%)
    - Pas déjà en position ouverte sur ce symbole
    - Direction Boom/Crash respectée
    Retourne la liste des ordres placés.
    """
    # Gate pause win-streak : 3 gains consécutifs → pause 1h
    is_paused, remaining_sec = _check_trading_pause()
    if is_paused:
        remaining_min = remaining_sec // 60
        logger.warning(f"[GATE-PAUSE] 🏆 Pause win-streak active — trading suspendu encore {remaining_min}min")
        return []

    open_positions = _get_open_positions()
    open_syms = {o.get("symbol", "").upper() for o in open_positions}
    placed = []

    for v in verdicts:
        vn = int(v.get("verdict_num", 0))
        if vn == 0:
            continue

        symbol = v.get("symbol", "")
        coherence = float(v.get("coherence_pct", 0) or 0)
        direction = "BUY" if vn > 0 else "SELL"

        # Gate cohérence
        if coherence < MIN_COHERENCE_TO_PLACE:
            logger.warning(f"[GATE-COH] {symbol}: cohérence {coherence:.0f}% < {MIN_COHERENCE_TO_PLACE}% — ordre ignoré")
            continue

        # Direction Boom/Crash
        if not _valid_direction(symbol, vn):
            logger.warning(f"[GATE-DIR] {symbol}: direction {direction} interdite — ordre ignoré")
            continue

        # Gate post-spike : attendre 2 bougies M1 de confirmation
        bars_since_spike = int(v.get("bars_since_spike") or 99)
        if 0 < bars_since_spike < 2:
            logger.warning(f"[GATE-SPIKE] {symbol}: spike trop récent ({bars_since_spike} bougie M1) — attente 2 bougies min")
            continue

        # Pas déjà en position
        sym_norm = symbol.upper().replace(" ", "")
        if any(sym_norm in o.upper().replace(" ", "") for o in open_syms):
            logger.info(f"[GATE-POS] {symbol}: position déjà ouverte — ordre ignoré")
            continue

        # ML advisory — warning si ML s'oppose au verdict GOM (jamais bloquant)
        ml = _get_ml_score(symbol)
        if ml and ml["confidence"] >= 0.65:
            if (direction == "BUY" and ml["action"] == "SELL") or \
               (direction == "SELL" and ml["action"] == "BUY"):
                logger.warning(
                    f"[ML-WARN] {symbol}: ML={ml['action']} {ml['confidence']*100:.0f}%"
                    f" s'oppose à GOM={direction} — ordre maintenu (advisory only)"
                )

        v_enriched = _compute_sl_tp_from_levels(dict(v))
        ok = _place_market_order(symbol, direction, v_enriched)
        if ok:
            placed.append({"symbol": symbol, "direction": direction, "verdict": v_enriched})

    return placed


def process_verdict_changes(current_verdicts: list):
    """
    Compare les verdicts actuels avec le cycle précédent et agit :
    1. WAIT après position ouverte + perte ≥ $1 → fermeture + notif
    2. Upgrade GOOD→PERFECT → ordre au marché immédiat
    """
    current_map = {v["symbol"]: v for v in current_verdicts}
    open_positions = _get_open_positions()
    open_syms = {o["symbol"] for o in open_positions}

    for symbol, v in current_map.items():
        vn_now  = int(v.get("verdict_num", 0))
        vn_prev = _prev_verdicts.get(symbol, vn_now)  # première fois = pas de changement

        # ── 1. Passage à WAIT avec position ouverte → fermeture IMMÉDIATE ──
        if vn_now == 0 and vn_prev != 0 and symbol in open_syms:
            closed = _close_position_for_symbol(
                symbol,
                f"GOM_WAIT (était {ACTION_MAP.get(vn_prev,'?')}) — fermeture immédiate"
            )
            msg = (
                f"🔴 *GOM WAIT — FERMETURE IMMÉDIATE* — {symbol}\n"
                f"Verdict {ACTION_MAP.get(vn_prev,'?')} → WAIT\n"
                f"{'✅ Ordre de fermeture envoyé' if closed else '⚠️ Échec envoi fermeture'}"
            )
            send_whatsapp_report(msg)
            logger.info(f"[WAIT-CLOSE] {symbol}: fermeture immédiate demandée (vn_prev={vn_prev})")
            _wait_notified.add(symbol)

        # Réinitialiser si le verdict revient actif
        if vn_now != 0 and symbol in _wait_notified:
            _wait_notified.discard(symbol)
            logger.info(f"[WAIT-NOTIF] {symbol}: verdict revenu à {ACTION_MAP.get(vn_now,'?')}, surveillance annulée")

        # ── 2. Upgrade GOOD→PERFECT ────────────────────────────────────────
        was_good    = abs(vn_prev) == 2
        is_perfect  = abs(vn_now) == 3
        same_side   = (vn_prev > 0) == (vn_now > 0)  # même direction

        if was_good and is_perfect and same_side and vn_prev != 0:
            direction = "BUY" if vn_now > 0 else "SELL"
            logger.info(f"[UPGRADE] {symbol}: {ACTION_MAP.get(vn_prev,'?')} → {ACTION_MAP.get(vn_now,'?')} — ordre marché {direction}")
            v_enriched = _compute_sl_tp_from_levels(dict(v))
            placed = _place_market_order(symbol, direction, v_enriched)
            msg = (
                f"🚀 *UPGRADE GOOD→PERFECT* — {symbol}\n"
                f"{ACTION_MAP.get(vn_prev,'?')} → {ACTION_MAP.get(vn_now,'?')}\n"
                f"{'✅ Ordre marché placé' if placed else '⚠️ Échec placement'}: {direction} "
                f"@ {v_enriched.get('entry',0):.2f} SL={v_enriched.get('sl',0):.2f} TP={v_enriched.get('tp',0):.2f}"
            )
            send_whatsapp_report(msg)

    # Mettre à jour l'état précédent pour le prochain cycle
    for symbol, v in current_map.items():
        _prev_verdicts[symbol] = int(v.get("verdict_num", 0))


def sync_verdicts_to_ai_server(verdicts):
    """Envoie chaque verdict via POST /gom-verdict à ai_server (optionnel)"""
    try:
        url = f"{AI_SERVER}/gom-verdict"

        for v in verdicts:
            verdict_num = v.get('verdict_num', 0)
            if verdict_num == 0:
                continue  # Skip WAIT signals

            try:
                # ENFORCE SL/TP SAFEGUARDS FOR SYNTHETICS BEFORE SENDING
                v = _enforce_synthetic_sl_tp(v)

                # S'assurer que price est présent (le serveur mappe price → entry)
                payload = dict(v)
                if not payload.get('price') and payload.get('entry'):
                    payload['price'] = payload['entry']
                response = requests.post(url, json=payload, timeout=5)
                if response.status_code == 200:
                    symbol = v.get('symbol', 'N/A')
                    action = ACTION_MAP.get(verdict_num, "WAIT")
                    logger.info(f"📤 {symbol} → {action} (HTTP 200)")
                else:
                    logger.debug(f"⚠️ POST /gom-verdict HTTP {response.status_code}")
            except Exception as e:
                logger.debug(f"Erreur sync verdict: {e}")

    except Exception as e:
        logger.error(f"❌ Erreur sync verdicts: {e}")


def main_loop():
    """Boucle principale — exécute toutes les 10 minutes"""
    logger.info("🚀 GOM Sync + WhatsApp Report démarré (10 min loop)")
    logger.info(f"📁 GOM File: {GOM_FILE}")
    logger.info(f"🌐 AI Server: {AI_SERVER}")
    logger.info(f"📋 Logs: {LOGS_DIR}")
    logger.info("=" * 60)

    iteration = 0

    try:
        while True:
            iteration += 1
            logger.info(f"\n[Itération {iteration}] 🔄 Synchronisation GOM...")

            # Charger les verdicts GOM
            verdicts = load_gom_signals()

            if verdicts:
                # Détection changements verdict (WAIT→close, GOOD→PERFECT→market)
                process_verdict_changes(verdicts)

                # Placer immédiatement les ordres pour tous les signaux actifs éligibles
                placed = place_active_orders(verdicts)
                if placed:
                    logger.info(f"🚀 {len(placed)} ordre(s) placé(s): {[p['symbol']+' '+p['direction'] for p in placed]}")

                # Sync to ai_server
                sync_verdicts_to_ai_server(verdicts)

                # Construire et envoyer rapport
                report = build_report(verdicts)
                if report:
                    send_whatsapp_report(report)

            logger.info(f"⏰ Prochain sync dans 10 min ({LOOP_INTERVAL}s)...")
            time.sleep(LOOP_INTERVAL)

    except KeyboardInterrupt:
        logger.info("\n⏹️ Arrêt demandé (Ctrl+C)")
    except Exception as e:
        logger.error(f"❌ Erreur boucle: {e}")


def run_once():
    """Exécute une seule synchronisation (--report)"""
    logger.info("🔄 Exécution unique GOM sync...")

    verdicts = load_gom_signals()

    if verdicts:
        # Détection changements verdict (WAIT→close, GOOD→PERFECT→market)
        process_verdict_changes(verdicts)

        # Placer immédiatement les ordres pour tous les signaux actifs éligibles
        placed = place_active_orders(verdicts)
        if placed:
            logger.info(f"🚀 {len(placed)} ordre(s) placé(s): {[p['symbol']+' '+p['direction'] for p in placed]}")

        sync_verdicts_to_ai_server(verdicts)
        report = build_report(verdicts)
        if report:
            logger.info("\n📋 RAPPORT:")
            logger.info(report)
            send_whatsapp_report(report)

    logger.info("✅ Exécution unique terminée")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--report":
        # Mode unique
        run_once()
    else:
        # Mode boucle 10 minutes
        main_loop()
