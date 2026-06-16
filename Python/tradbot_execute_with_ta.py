#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TradBOT Execute with TradingAgents Local Analysis
=====================================================
Workflow:
1. Load GOM verdicts from gom_signal.json
2. For each active verdict: run TradingAgents locally (direct import)
3. Refine signal with TV MCP data
4. Send WhatsApp: [SYMBOL] [ACTION] Entry=X SL=Y TP=Z | Confirmer? OUI/NON
5. Wait for WhatsApp response or auto-approve if --auto
6. Place valid orders via /pending-order
7. Log everything with timestamps + symbol

Usage:
    python tradbot_execute_with_ta.py --auto              # Auto-approve all
    python tradbot_execute_with_ta.py --wait-approval 120 # Wait 2min for reply
    python tradbot_execute_with_ta.py --test              # Test mode (no orders)
"""

import sys
import io
import os
import json
import logging
import time
import requests
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Dict, Optional

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

# Paths
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
LOG_DIR = ROOT / "logs"
GOM_FILE = ROOT / "data" / "gom_signal.json"
WHITELIST_FILE = ROOT / "data" / "pipeline_whitelist.json"
LOG_DIR.mkdir(parents=True, exist_ok=True)

# Logging
log_file = LOG_DIR / f"tradbot_execute_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(log_file, encoding="utf-8"),
    ],
)
log = logging.getLogger(__name__)

# Config
AI_SERVER = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000")
PSYCHOBOT = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com")
PHONE = os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346")

# Action mappings
ACTION_MAP = {
    3: "PERFECT BUY",
    2: "GOOD BUY",
    1: "BUY",
    -1: "SELL",
    -2: "GOOD SELL",
    -3: "PERFECT SELL",
    0: "WAIT",
}

EMOJI_MAP = {3: "🟢", 2: "🟢", 1: "🟢", -1: "🔴", -2: "🔴", -3: "🔴", 0: "⚪"}


def _check_mtf_gate(symbol: str, verdict: Dict, action: str) -> tuple:
    """Gate MTF : H4+H1+M15 doivent confirmer la direction du signal.
    Retourne (ok: bool, raison: str).
    Si toutes les directions TF sont NEUT (pas de données) → laisse passer.
    """
    tfs = {
        "m1":  str(verdict.get("tf_m1_dir",  "NEUT") or "NEUT"),
        "m5":  str(verdict.get("tf_m5_dir",  "NEUT") or "NEUT"),
        "m15": str(verdict.get("tf_m15_dir", "NEUT") or "NEUT"),
        "h1":  str(verdict.get("tf_h1_dir",  "NEUT") or "NEUT"),
        "h4":  str(verdict.get("tf_h4_dir",  "NEUT") or "NEUT"),
        "d1":  str(verdict.get("tf_d1_dir",  "NEUT") or "NEUT"),
    }
    if all(d == "NEUT" for d in tfs.values()):
        return True, ""

    h4  = tfs["h4"]
    h1  = tfs["h1"]
    m15 = tfs["m15"]
    side     = "BULL" if action == "BUY" else "BEAR"
    opposite = "BEAR" if action == "BUY" else "BULL"

    if h4 == opposite and h1 == opposite:
        return False, f"MTF rejet absolu — H4={h4} H1={h1} tous deux contre {action}"

    structure_ok = (h4 == side) or (h1 == side and m15 == side)
    if not structure_ok:
        return False, f"MTF structure insuffisante — H4={h4} H1={h1} M15={m15} pour {action}"

    count_side = sum(1 for d in tfs.values() if d == side)
    if count_side < 4:
        return False, f"MTF cohérence {count_side}/6 TF {side} < 4 requis pour {action}"

    return True, ""


def load_gom_verdicts() -> List[Dict]:
    """Charge les verdicts GOM depuis /gom-verdicts (MT5 live), fallback fichier."""
    # Priorité : serveur live (candles MT5 fraîches)
    try:
        r = requests.get(f"{AI_SERVER}/gom-verdicts", timeout=5)
        if r.status_code == 200:
            data = r.json()
            verdicts = data.get("verdicts", data) if isinstance(data, dict) else data
            if isinstance(verdicts, list) and verdicts:
                active = [v for v in verdicts if v.get("verdict_num", 0) != 0]
                log.info(f"[GOM] {len(verdicts)} verdicts LIVE, {len(active)} actifs")
                return active
    except Exception:
        pass

    # Fallback fichier JSON
    try:
        with open(GOM_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        verdicts = []
        if isinstance(data, dict):
            verdicts = data.get("verdicts") or [v for v in data.values() if isinstance(v, dict)]
        elif isinstance(data, list):
            verdicts = data
        active = [v for v in verdicts if v.get("verdict_num", 0) != 0]
        log.warning(f"[GOM] Fallback fichier — {len(active)} verdicts (peut être stale)")
        return active
    except Exception as e:
        log.error(f"[GOM] Failed to load: {e}")
        return []


# Fenêtres de trading UTC — hors fenêtre = verdict ignoré même si GOM actif.
# Boom/Crash : pas de restriction locale (bc_heure gate gérée par ai_server /pending-order).
_TRADING_WINDOWS: dict = {
    "XAUUSD": [(7, 17)],
    "BTCUSD": [(8, 22)],
    "ETHUSD": [(8, 22)],
    "NAS100": [(13, 20)],
    "US30":   [(13, 20)],
}


def _in_trading_window(symbol: str) -> bool:
    """Retourne True si le symbole est dans sa fenêtre de trading UTC (heure courante)."""
    utc_hour = datetime.now(timezone.utc).hour
    s = symbol.upper().replace(" ", "")
    for key, windows in _TRADING_WINDOWS.items():
        if key in s:
            in_window = any(start <= utc_hour < end for start, end in windows)
            if not in_window:
                log.warning(
                    f"[GATE-SESSION] {symbol}: heure UTC {utc_hour:02d}h "
                    f"hors fenêtre propice {windows} — rejeté"
                )
            return in_window
    return True  # Boom/Crash et symboles inconnus → gate déléguée à ai_server


def validate_direction(symbol: str, direction: str) -> bool:
    """Validate Boom/Crash direction constraints"""
    s = symbol.upper()
    d = direction.upper()

    if "BOOM" in s and d == "SELL":
        log.warning(f"[VALIDATE] {symbol}: SELL forbidden on Boom")
        return False
    if "CRASH" in s and d == "BUY":
        log.warning(f"[VALIDATE] {symbol}: BUY forbidden on Crash")
        return False
    return True


def check_whitelist(symbol: str) -> bool:
    """
    Vérifie que le symbole N'EST PAS déjà dans la pipeline_whitelist.
    Si pipeline_with_approval a déjà placé sur ce symbole → skip pour éviter doublon.
    """
    try:
        if not WHITELIST_FILE.exists():
            return True  # Pas de whitelist → pas de restriction
        with open(WHITELIST_FILE, "r", encoding="utf-8") as f:
            wl = json.load(f)
        symbols = wl.get("symbols", [])
        if not symbols:
            return True  # Whitelist vide → pas de restriction
        sym_norm = symbol.upper().replace(" ", "").replace("_INDEX", "").replace("DERIV:", "")
        for entry in symbols:
            s = entry if isinstance(entry, str) else entry.get("symbol", "")
            s_norm = str(s).upper().replace(" ", "").replace("_INDEX", "").replace("DERIV:", "")
            if sym_norm == s_norm:
                log.info(f"[WHITELIST] {symbol} déjà géré par pipeline_with_approval — skip doublon")
                return False
        return True  # Symbole absent de la whitelist → on peut traiter
    except Exception as e:
        log.warning(f"[WHITELIST] Erreur lecture whitelist: {e} — autorisation par défaut")
        return True


def get_lot_min(symbol: str) -> float:
    """Get minimum lot size for symbol category"""
    s = symbol.upper().replace("DERIV:", "").replace("_INDEX", "").replace(" ", "")

    if any(p in s for p in ("BOOM", "CRASH")):
        return 0.20
    if any(s.startswith(p) for p in ("1HZ", "R_", "V10", "V25", "V50", "V75", "V100")):
        return 0.10
    return 0.01


def analyze_with_trading_agents(symbol: str, date_str: str) -> Optional[Dict]:
    """
    Get TradingAgents analysis via AI server endpoint.
    Falls back gracefully if unavailable.
    """
    try:
        log.info(f"[TA] Fetching analysis for {symbol}...")

        url = f"{AI_SERVER}/ta-analysis"
        response = requests.get(
            url,
            params={"symbol": symbol, "date_str": date_str},
            timeout=15
        )

        if response.status_code == 200:
            data = response.json()
            if data.get("success"):
                log.info(f"[TA] {symbol} opinion: {data.get('opinion')}")
                return data
            else:
                log.debug(f"[TA] Not available: {data.get('error')}")
                return None
        else:
            log.debug(f"[TA] HTTP {response.status_code}")
            return None

    except requests.exceptions.Timeout:
        log.debug(f"[TA] {symbol} timeout")
        return None
    except Exception as e:
        log.debug(f"[TA] {symbol} error: {e}")
        return None


def fetch_tv_indicators(symbol: str) -> Optional[Dict]:
    """Fetch indicateurs depuis GOM MT5 (remplace TradingView MCP)."""
    try:
        log.info(f"[GOM] Fetching indicators for {symbol}...")
        url = f"{AI_SERVER}/gom-kola-dashboard"
        response = requests.get(url, params={"symbol": symbol}, timeout=10)
        if response.status_code == 200:
            data = response.json()
            if data.get("ok"):
                rsi = data.get("rsi14") or data.get("rsi") or 50
                bias = data.get("tf_global_dir", "NEUT")
                log.info(f"[GOM] RSI={rsi}, Bias={bias}")
                return {"rsi": rsi, "bias": bias, "source": "gom_mt5", **data}
        log.debug(f"[GOM] HTTP {response.status_code}, continuing without indicators")
        return None
    except Exception as e:
        log.debug(f"[GOM] Error: {e}, continuing...")
        return None


def build_order_message(verdict: Dict, ta_result: Optional[Dict], tv_data: Optional[Dict]) -> str:
    """Build order confirmation message for WhatsApp"""
    symbol = verdict.get("symbol", "UNKNOWN")
    verdict_num = verdict.get("verdict_num", 0)
    entry = verdict.get("entry", 0)
    sl = verdict.get("sl", 0)
    tp = verdict.get("tp", 0)
    lot = verdict.get("lot", 0.01)

    action = ACTION_MAP.get(verdict_num, "WAIT")
    emoji = EMOJI_MAP.get(verdict_num, "⚪")

    msg = f"{emoji} **{symbol}** — {action}\n"
    msg += f"Entry: {entry:.2f} | SL: {sl:.2f} | TP: {tp:.2f}\n"
    msg += f"Lot: {lot:.2f}\n"

    if ta_result:
        msg += f"TA: {ta_result.get('opinion', 'N/A')}\n"

    if tv_data:
        msg += f"TV RSI: {tv_data.get('rsi', 'N/A')} | Bias: {tv_data.get('bias', 'N/A')}\n"

    msg += "\n✅ Confirmer? OUI/NON"

    return msg


def send_approval_request(symbol: str, message: str, timeout_sec: int = 120) -> bool:
    """
    Send WhatsApp approval message and wait for YES/NO response via AI server.
    Returns True if approved, False if rejected or timeout.
    """
    try:
        log.info(f"[APPROVE] Sending {symbol} to WhatsApp for approval...")

        # Send via AI server /notify-whatsapp then wait for /approval response
        notify_url = f"{AI_SERVER}/notify-whatsapp"
        notify_payload = {
            "event": "order_approval",
            "symbol": symbol,
            "message": message,
        }

        response = requests.post(notify_url, json=notify_payload, timeout=5)
        if response.status_code != 200:
            log.warning(f"[APPROVE] Notify failed: HTTP {response.status_code}")
            return False

        log.info(f"[APPROVE] Message sent, waiting {timeout_sec}s for response...")

        # Poll /approval/{symbol} endpoint for response
        start_time = time.time()
        poll_interval = 5  # Check every 5 seconds

        while time.time() - start_time < timeout_sec:
            check_url = f"{AI_SERVER}/approval/{symbol}"
            try:
                check_response = requests.get(check_url, timeout=3)
                if check_response.status_code == 200:
                    data = check_response.json()
                    status_val = data.get("status", "").lower()

                    if status_val in {"approved", "yes", "oui", "ok"}:
                        log.info(f"[APPROVE] {symbol} APPROVED")
                        return True
                    elif status_val in {"rejected", "no", "non", "skip"}:
                        log.info(f"[APPROVE] {symbol} REJECTED")
                        return False
                    # else: still pending, continue polling

            except requests.exceptions.RequestException:
                pass  # Endpoint not ready, continue

            time.sleep(poll_interval)

        log.warning(f"[APPROVE] {symbol} TIMEOUT waiting for response")
        return False

    except Exception as e:
        log.error(f"[APPROVE] {symbol} error: {e}")
        return False


def place_order(verdict: Dict) -> bool:
    """
    Place order via /pending-order endpoint.
    Returns True if placed successfully.
    """
    try:
        symbol = verdict.get("symbol", "UNKNOWN")
        verdict_num = verdict.get("verdict_num", 0)
        entry = verdict.get("entry", 0)
        sl = verdict.get("sl", 0)
        tp = verdict.get("tp", 0)
        lot = verdict.get("lot", 0.01)

        action = "BUY" if verdict_num > 0 else "SELL"

        # GATE 1 — IA STATUS : coherence_pct doit être >= 70%
        _ia = float(verdict.get("coherence_pct") or 0)
        if 0 < _ia < 70.0:
            log.warning(f"[ORDER] 🚫 {symbol}: IA status {_ia:.0f}% < 70% requis — ordre bloqué")
            return False

        # GATE 2 — MTF : H4+H1+M15 doivent confirmer la direction
        _mtf_ok, _mtf_reason = _check_mtf_gate(symbol, verdict, action)
        if not _mtf_ok:
            log.warning(f"[ORDER] 🚫 {symbol}: Gate MTF — {_mtf_reason}")
            return False

        # Fallback ATR si SL absent — 2× ATR (SL large, évite fermetures prématurées)
        if not sl or sl <= 0:
            atr = float(verdict.get("atr") or verdict.get("atr14") or 0)
            if atr > 0 and entry > 0:
                sl = round(entry - atr * 2.0, 5) if action == "BUY" else round(entry + atr * 2.0, 5)
                log.info(f"[ORDER] {symbol} SL calculé ATR fallback (2×{atr:.2f}) → SL={sl:.2f}")
            else:
                log.error(f"[ORDER] {symbol} SL=0 et ATR indisponible — ordre refusé")
                return False
        if not tp or tp <= 0:
            log.error(f"[ORDER] {symbol} TP=0 — ordre refusé (objectif indéfini)")
            return False

        log.info(f"[ORDER] Placing {action} order for {symbol} (IA={_ia:.0f}%)...")

        url = f"{AI_SERVER}/pending-order"
        payload = {
            "symbol": symbol,
            "action": action,
            "entry_price": entry,
            "stop_loss": sl,
            "take_profit": tp,
            "lot": lot,
            "source": "pipeline_ta",
        }

        response = requests.post(url, json=payload, timeout=5)

        if response.status_code in (200, 201):
            log.info(f"[ORDER] {symbol} order placed successfully (HTTP {response.status_code})")
            return True
        else:
            log.error(f"[ORDER] {symbol} failed (HTTP {response.status_code}): {response.text}")
            return False

    except Exception as e:
        log.error(f"[ORDER] {symbol} exception: {e}")
        return False


def main(auto_approve: bool = False, approval_timeout: int = 120, test_mode: bool = False):
    """Main workflow"""
    log.info("=" * 70)
    log.info(f"TradBOT Execute with TradingAgents | auto_approve={auto_approve} | test={test_mode}")
    log.info("=" * 70)

    verdicts = load_gom_verdicts()
    if not verdicts:
        log.warning("[MAIN] No active verdicts found")
        return

    stats = {"total": len(verdicts), "placed": 0, "rejected": 0, "failed": 0}

    for i, verdict in enumerate(verdicts, 1):
        symbol = verdict.get("symbol", "UNKNOWN")
        verdict_num = verdict.get("verdict_num", 0)

        log.info(f"\n[MAIN] [{i}/{len(verdicts)}] Processing {symbol}...")

        # 1. Validate direction
        action = "BUY" if verdict_num > 0 else "SELL"
        if not validate_direction(symbol, action):
            log.warning(f"[MAIN] {symbol} direction validation failed")
            stats["rejected"] += 1
            continue

        # 1b. Gate horaire UTC — ne pas trader hors fenêtre propice
        if not _in_trading_window(symbol):
            stats["rejected"] += 1
            continue

        # 1c. Vérifier whitelist pipeline (si active)
        if not check_whitelist(symbol):
            stats["rejected"] += 1
            continue

        # 2. Ensure minimum lot size
        verdict["lot"] = max(verdict.get("lot", 0.01), get_lot_min(symbol))

        # 3. Run TradingAgents analysis
        ta_result = analyze_with_trading_agents(symbol, datetime.now().strftime("%Y-%m-%d"))

        # 4. Fetch TV indicators for refinement
        tv_data = fetch_tv_indicators(symbol)

        # 5. Build approval message
        msg = build_order_message(verdict, ta_result, tv_data)

        # 6. Get approval (auto or WhatsApp)
        approved = auto_approve or send_approval_request(symbol, msg, timeout_sec=approval_timeout)

        if not approved:
            log.info(f"[MAIN] {symbol} approval denied/timeout, skipping")
            stats["rejected"] += 1
            continue

        # 7. Vérifier fraîcheur GOM + enrichir le verdict avec les champs TF frais
        if not test_mode:
            try:
                fresh = requests.get(f"{AI_SERVER}/gom-verdicts", timeout=5)
                if fresh.status_code == 200:
                    fresh_list = fresh.json()
                    verdicts_list = fresh_list.get("verdicts", fresh_list) if isinstance(fresh_list, dict) else fresh_list
                    fresh_data = next((v for v in verdicts_list if v.get("symbol") == symbol), None)
                    if fresh_data:
                        fresh_num = fresh_data.get("verdict_num", 0)
                        if fresh_num == 0:
                            log.warning(f"[MAIN] {symbol} verdict devenu WAIT avant ordre — annulé")
                            stats["rejected"] += 1
                            continue
                        if fresh_num != verdict_num:
                            log.warning(f"[MAIN] {symbol} verdict changé ({verdict_num}→{fresh_num}) avant ordre — annulé")
                            stats["rejected"] += 1
                            continue
                        # Enrichir le verdict avec les champs frais (TF dirs, coherence_pct, etc.)
                        verdict.update(fresh_data)
            except Exception as e:
                log.warning(f"[MAIN] {symbol} vérif fraîcheur GOM échouée ({e}) — on continue")

        # 8. Place order (or test mode)
        if test_mode:
            log.info(f"[TEST] Would place {action} order for {symbol}")
            stats["placed"] += 1
        else:
            if place_order(verdict):
                stats["placed"] += 1
            else:
                stats["failed"] += 1

    # Summary
    log.info("\n" + "=" * 70)
    log.info(f"EXECUTION SUMMARY")
    log.info(f"  Total verdicts: {stats['total']}")
    log.info(f"  Orders placed: {stats['placed']}")
    log.info(f"  Rejected: {stats['rejected']}")
    log.info(f"  Failed: {stats['failed']}")
    log.info("=" * 70)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--auto", action="store_true", help="Auto-approve all orders")
    parser.add_argument("--wait-approval", type=int, default=120, help="Wait N seconds for WhatsApp approval")
    parser.add_argument("--test", action="store_true", help="Test mode (no orders placed)")

    args = parser.parse_args()

    main(auto_approve=args.auto, approval_timeout=args.wait_approval, test_mode=args.test)
