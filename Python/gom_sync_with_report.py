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


def load_gom_signals():
    """Charge les verdicts GOM — priorité serveur live, fallback fichier JSON."""
    # Priorité 1 : verdicts live depuis le serveur (candles MT5 fraîches)
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

        # Ligne directions par TF (varie selon que M1 vs H4 sont bullish/bearish)
        tf_row = _fmt_tf_row(v)
        if tf_row:
            lines.append(tf_row)

    lines.append("=" * 50)
    lines.append(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}")

    report = "\n".join(lines)
    logger.info(f"📋 Rapport construit ({len(active_verdicts)} signaux actifs)")
    return report


def send_whatsapp_report(report):
    """Envoie le rapport via WhatsApp (endpoint ai_server)"""
    if not report:
        return False

    try:
        url = f"{AI_SERVER}/notify-whatsapp"
        payload = {
            "event": "gom_report",
            "symbol": "GOM_VERDICTS",
            "message": report
        }

        response = requests.post(url, json=payload, timeout=5)

        if response.status_code == 200:
            logger.info(f"✅ Rapport WhatsApp envoyé (HTTP 200)")
            return True
        else:
            logger.warning(f"⚠️ WhatsApp HTTP {response.status_code}: {response.text}")
            return False

    except requests.exceptions.RequestException as e:
        logger.error(f"❌ Erreur WhatsApp: {e}")
        return False


def _enforce_synthetic_sl_tp(v: dict) -> dict:
    """
    Force SL/TP distances for synthetic indices (CRASH, BOOM, JUMP).
    Returns updated verdict dict.
    """
    symbol = v.get('symbol', '').upper()
    is_synthetic = any(x in symbol for x in ['CRASH', 'BOOM', 'JUMP'])

    if not is_synthetic:
        return v  # No modification needed

    entry = v.get('entry') or v.get('price')
    sl = v.get('sl')
    tp = v.get('tp')
    direction = 'BUY' if v.get('verdict_num', 0) > 0 else 'SELL'

    if not entry:
        return v  # Cannot validate without entry

    # SL/TP might be empty; if so, compute safe defaults
    if not sl or not tp:
        entry = float(entry)
        atr_raw = v.get('atr') or v.get('atr14') or 2.0
        atr_raw = float(atr_raw)
        min_dist = max(atr_raw * 4.0, 0.40)

        if direction == "BUY":
            v['sl'] = round(entry - min_dist, 5)
            v['tp'] = round(entry + min_dist, 5)
        else:
            v['sl'] = round(entry + min_dist, 5)
            v['tp'] = round(entry - min_dist, 5)

        logger.debug(f"  ℹ️  SYNTHÉTIQUE {symbol}: SL/TP générés (vides) → SL={v['sl']}, TP={v['tp']}")
        return v

    entry = float(entry)
    sl = float(sl)
    tp = float(tp)

    # ATR-based minimum (use 4x for synthetics)
    atr_raw = v.get('atr') or v.get('atr14') or 2.0
    atr_raw = float(atr_raw)

    # Calculate required minimums
    min_sl_dist = atr_raw * 4.0

    # Also enforce absolute minimum: 40 pips
    min_abs_pips = 0.40
    min_sl_dist = max(min_sl_dist, min_abs_pips)

    # Check and fix SL distance
    sl_dist = abs(entry - sl)
    if sl_dist < min_sl_dist:
        sl_new = entry - min_sl_dist if direction == "BUY" else entry + min_sl_dist
        logger.warning(f"  ⚠️  SYNTHÉTIQUE {symbol}: SL trop serré ({sl_dist:.2f} < {min_sl_dist:.2f}) → forcé à {sl_new:.2f}")
        v['sl'] = round(sl_new, 5)

    # Check and fix TP distance
    tp_dist = abs(entry - tp)
    if tp_dist < min_abs_pips:
        tp_new = entry + min_abs_pips if direction == "BUY" else entry - min_abs_pips
        logger.warning(f"  ⚠️  SYNTHÉTIQUE {symbol}: TP trop serré ({tp_dist:.2f} < {min_abs_pips:.2f}) → forcé à {tp_new:.2f}")
        v['tp'] = round(tp_new, 5)

    return v


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
                # Sync to ai_server (optionnel)
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
