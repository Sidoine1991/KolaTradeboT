#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pipeline TradBOT — Auto-placement Good/Perfect + Rapports Word

Workflow:
    1. Scan GOM MT5 — filtre uniquement Good/Perfect (verdict_num ±2)
    2. Pour les Good/Perfect:
       - Analyse TradingAgents
       - Rapport Word généré + envoyé
    3. Top-3 valides → Place ordres auto (marché/stop/limit)
    4. Résumé WhatsApp final

Usage:
    python pipeline_auto_goodperfect.py
    python pipeline_auto_goodperfect.py --top-n 5 --dry-run  # test sans ordres
"""

import sys
import io
import os
import subprocess
import json
import logging
import time
import requests
from datetime import datetime, date
from pathlib import Path
from typing import List, Dict, Optional, Tuple

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent
_LOG_DIR = _ROOT / "logs"
_LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(_LOG_DIR / "pipeline_auto_goodperfect.log", encoding="utf-8"),
    ],
)
log = logging.getLogger("pipeline_auto_goodperfect")

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
AI_SERVER = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000")
PSYCHOBOT = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com")
PHONE = os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def send_whatsapp(msg: str) -> bool:
    """Envoie message WhatsApp."""
    for attempt in range(3):
        try:
            r = requests.post(
                f"{PSYCHOBOT}/send-message",
                json={"phone": PHONE, "message": msg},
                timeout=15,
                verify=False,
            )
            if r.status_code == 200:
                return True
        except Exception as e:
            log.warning(f"WhatsApp tentative {attempt + 1}/3: {e}")
        time.sleep(2)
    return False

def _tv_to_mt5(symbol: str) -> str:
    """Convertit DERIV:BOOM_500_INDEX → Boom 500 Index."""
    mapping = {
        "DERIV:BOOM_1000_INDEX": "Boom 1000 Index",
        "DERIV:BOOM_500_INDEX": "Boom 500 Index",
        "DERIV:BOOM_300_INDEX": "Boom 300 Index",
        "DERIV:CRASH_1000_INDEX": "Crash 1000 Index",
        "DERIV:CRASH_500_INDEX": "Crash 500 Index",
        "DERIV:CRASH_300_INDEX": "Crash 300 Index",
    }
    return mapping.get(symbol, symbol)

def is_valid_direction(symbol: str, direction: str) -> bool:
    """Valide Boom/Crash rules."""
    s = symbol.upper()
    d = direction.upper()
    if "BOOM" in s and d == "SELL":
        log.warning(f"🚫 {symbol}: SELL interdit sur Boom")
        return False
    if "CRASH" in s and d == "BUY":
        log.warning(f"🚫 {symbol}: BUY interdit sur Crash")
        return False
    return True

def get_lot_min(symbol: str) -> float:
    """Retourne lot minimum par catégorie."""
    s = symbol.upper().replace("DERIV:", "").replace("_INDEX", "").replace(" ", "").replace("INDEX", "")
    if any(p in s for p in ("BOOM", "CRASH")):
        return 0.20
    if any(s.startswith(p) for p in ("1HZ", "R_", "V10", "V25", "V50", "V75", "V100", "VOLATILITY")):
        return 0.10
    return 0.01

def check_mtf_gate(symbol: str, data: dict, action: str) -> tuple:
    """Gate MTF : H4+H1+M15 doivent confirmer la direction."""
    tfs = {
        "m1": data.get("tf_m1_dir", "NEUT"),
        "m5": data.get("tf_m5_dir", "NEUT"),
        "m15": data.get("tf_m15_dir", "NEUT"),
        "h1": data.get("tf_h1_dir", "NEUT"),
        "h4": data.get("tf_h4_dir", "NEUT"),
        "d1": data.get("tf_d1_dir", "NEUT"),
    }
    if all(d == "NEUT" for d in tfs.values()):
        return True, ""

    h4 = tfs["h4"]
    h1 = tfs["h1"]
    m15 = tfs["m15"]
    side = "BULL" if action.upper() == "BUY" else "BEAR"
    opposite = "BEAR" if action.upper() == "BUY" else "BULL"

    if h4 == opposite and h1 == opposite:
        return False, f"MTF rejet absolu — H4={h4} H1={h1} contre {action}"

    if not ((h4 == side) or (h1 == side and m15 == side)):
        return False, f"MTF structure insuffisante — H4={h4} H1={h1} M15={m15}"

    count = sum(1 for d in tfs.values() if d == side)
    if count < 4:
        return False, f"MTF cohérence {count}/6 < 4 requis pour {action}"

    return True, ""

# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------

class PipelineAutoGoodPerfect:
    """Pipeline auto-placement Good/Perfect."""

    def __init__(self, dry_run: bool = False):
        self.dry_run = dry_run
        self.good_perfect_signals = []
        self.orders_placed = []
        self.orders_failed = []
        self.reports_sent = []

    def scan_goodperfect_only(self, top_n: int) -> List[Dict]:
        """Scanne et filtre uniquement Good/Perfect."""
        log.info("📊 Phase 1 — Scan Good/Perfect uniquement")
        try:
            r = requests.get(f"{AI_SERVER}/gom-verdicts", timeout=5)
            if r.status_code != 200:
                log.error(f"❌ /gom-verdicts HTTP {r.status_code}")
                return []

            data = r.json()
            verdicts = data.get("verdicts", data) if isinstance(data, dict) else data
            if not isinstance(verdicts, list):
                verdicts = list(verdicts.values()) if isinstance(verdicts, dict) else []
        except Exception as e:
            log.error(f"❌ Erreur scan: {e}")
            return []

        good_perfect = []
        _seen_normalized = {}

        for v in verdicts:
            verdict_num = v.get("verdict_num", 0)
            verdict = v.get("verdict", "WAIT")

            # Filtrer uniquement Good (±2) et Perfect (±3)
            if abs(verdict_num) < 2:
                continue

            sym = v.get("symbol", "")
            direction = "BUY" if verdict_num > 0 else "SELL"

            if not is_valid_direction(sym, direction):
                continue

            score = float(v.get("verdict_gap", abs(verdict_num)))
            cp = float(v.get("entry") or v.get("close") or v.get("price") or 0)
            coh = float(v.get("coherence_pct", 0))

            # Normaliser pour dédup
            sym_norm = sym.upper().replace(" ", "").replace("INDEX", "").replace("DERIV:", "")
            if sym_norm in _seen_normalized:
                idx = _seen_normalized[sym_norm]
                if score > good_perfect[idx]["score"]:
                    good_perfect[idx] = {
                        "symbol": sym,
                        "verdict": verdict,
                        "verdict_num": verdict_num,
                        "direction": direction,
                        "score": score,
                        "coherence_pct": coh,
                        "entry": cp,
                        "atr": float(v.get("atr", 0)),
                        "rsi14": float(v.get("rsi14", v.get("rsi", 50))),
                        "bb_up": float(v.get("bb_up", 0)),
                        "bb_dn": float(v.get("bb_dn", 0)),
                        "tf_m1_dir": str(v.get("tf_m1_dir", "NEUT")),
                        "tf_m5_dir": str(v.get("tf_m5_dir", "NEUT")),
                        "tf_m15_dir": str(v.get("tf_m15_dir", "NEUT")),
                        "tf_h1_dir": str(v.get("tf_h1_dir", "NEUT")),
                        "tf_h4_dir": str(v.get("tf_h4_dir", "NEUT")),
                        "tf_d1_dir": str(v.get("tf_d1_dir", "NEUT")),
                    }
                continue

            _seen_normalized[sym_norm] = len(good_perfect)
            good_perfect.append({
                "symbol": sym,
                "verdict": verdict,
                "verdict_num": verdict_num,
                "direction": direction,
                "score": score,
                "coherence_pct": coh,
                "entry": cp,
                "atr": float(v.get("atr", 0)),
                "rsi14": float(v.get("rsi14", v.get("rsi", 50))),
                "bb_up": float(v.get("bb_up", 0)),
                "bb_dn": float(v.get("bb_dn", 0)),
                "tf_m1_dir": str(v.get("tf_m1_dir", "NEUT")),
                "tf_m5_dir": str(v.get("tf_m5_dir", "NEUT")),
                "tf_m15_dir": str(v.get("tf_m15_dir", "NEUT")),
                "tf_h1_dir": str(v.get("tf_h1_dir", "NEUT")),
                "tf_h4_dir": str(v.get("tf_h4_dir", "NEUT")),
                "tf_d1_dir": str(v.get("tf_d1_dir", "NEUT")),
            })
            log.info(f"  ✅ {sym:25s} | {verdict:20s} | Score: {score:.1f} Coh: {coh:.0f}%")

        # Trier et limiter
        good_perfect.sort(key=lambda x: x["score"], reverse=True)
        top = good_perfect[:top_n]
        log.info(f"🎯 Total Good/Perfect: {len(good_perfect)} → Top-{len(top)} sélectionnés")
        return top

    def analyze_signal(self, gom_signal: Dict) -> Optional[Dict]:
        """Analyse un signal Good/Perfect."""
        sym = gom_signal["symbol"]
        direction = gom_signal["direction"]

        log.info(f"🤖 Analyse: {sym} {direction}")

        entry = float(gom_signal.get("entry", 0))
        atr = float(gom_signal.get("atr", 0))
        bb_up = float(gom_signal.get("bb_up", 0))
        bb_dn = float(gom_signal.get("bb_dn", 0))

        if entry <= 0:
            log.warning(f"  ⚠️ Entry manquante — skip")
            return None

        # Calculer SL/TP
        if direction == "BUY":
            sl = bb_dn if bb_dn > 0 else entry * 0.995
            tp = bb_up if bb_up > 0 else entry * 1.01
        else:
            sl = bb_up if bb_up > 0 else entry * 1.005
            tp = bb_dn if bb_dn > 0 else entry * 0.99

        # ATR floor
        if atr and atr > 0:
            min_sl_dist = atr * 2.0
            sl_dist = abs(entry - sl)
            if sl_dist < min_sl_dist:
                sl = round(entry - min_sl_dist if direction == "BUY" else entry + min_sl_dist, 5)
                log.info(f"  ℹ️ SL ATR floor appliqué → SL={sl:.5f}")

        # Execution type
        cp = entry
        exec_type = "market"
        if entry and cp > 0:
            is_buy = direction == "BUY"
            if is_buy and entry < cp * 0.999:
                exec_type = "limit"
            elif is_buy and entry > cp * 1.001:
                exec_type = "stop"
            elif not is_buy and entry > cp * 1.001:
                exec_type = "limit"
            elif not is_buy and entry < cp * 0.999:
                exec_type = "stop"

        lot = get_lot_min(sym)

        return {
            "symbol": sym,
            "clean_sym": _tv_to_mt5(sym),
            "direction": direction,
            "entry": round(entry, 5),
            "sl": round(sl, 5),
            "tp": round(tp, 5),
            "atr": round(atr, 5),
            "lot": lot,
            "execution_type": exec_type,
            "coherence_pct": gom_signal.get("coherence_pct", 0),
            "verdict": gom_signal.get("verdict", direction),
            "tf_m1_dir": gom_signal.get("tf_m1_dir", "NEUT"),
            "tf_m5_dir": gom_signal.get("tf_m5_dir", "NEUT"),
            "tf_m15_dir": gom_signal.get("tf_m15_dir", "NEUT"),
            "tf_h1_dir": gom_signal.get("tf_h1_dir", "NEUT"),
            "tf_h4_dir": gom_signal.get("tf_h4_dir", "NEUT"),
            "tf_d1_dir": gom_signal.get("tf_d1_dir", "NEUT"),
        }

    def send_report_word(self, analysis: Dict) -> Optional[str]:
        """Envoie rapport Word via PsychoBot."""
        sym = analysis["symbol"]
        log.info(f"📄 Envoi rapport Word: {sym}")

        try:
            sys.path.insert(0, str(_HERE))
            from send_tradingagents_report import send_whatsapp_file

            # Créer rapport simple
            report_name = f"Signal_{sym}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
            report_path = _LOG_DIR / report_name

            report_content = f"""📊 SIGNAL ANALYSIS — {sym}

Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} UTC
Direction: {analysis['direction']}
Verdict: {analysis['verdict']}

━━━━━━━━━━━━━━━━━━
ENTRY LEVELS
━━━━━━━━━━━━━━━━━━
Entry Price: {analysis['entry']:.5f}
Stop Loss:   {analysis['sl']:.5f}
Take Profit: {analysis['tp']:.5f}
Lot:         {analysis['lot']}

Risk/Reward: 1:{round(abs(analysis['tp'] - analysis['entry']) / abs(analysis['entry'] - analysis['sl']), 2) if abs(analysis['entry'] - analysis['sl']) > 0 else 0}

━━━━━━━━━━━━━━━━━━
INDICATORS
━━━━━━━━━━━━━━━━━━
ATR (14):       {analysis['atr']:.5f}
IA Status:      {analysis['coherence_pct']:.0f}%

Timeframe Analysis:
  M1:  {analysis['tf_m1_dir']}
  M5:  {analysis['tf_m5_dir']}
  M15: {analysis['tf_m15_dir']}
  H1:  {analysis['tf_h1_dir']}
  H4:  {analysis['tf_h4_dir']}
  D1:  {analysis['tf_d1_dir']}

Execution Type: {analysis['execution_type']}

Generated by TradBOT Auto-Pipeline
"""
            report_path.write_text(report_content, encoding="utf-8")

            caption = f"📊 *{sym}* — {analysis['direction']}\nEntry: {analysis['entry']:.5f}"
            try:
                send_whatsapp_file(str(report_path), caption)
                log.info(f"  ✅ Rapport envoyé: {report_name}")
                self.reports_sent.append(sym)
                return str(report_path)
            except Exception as e:
                log.warning(f"  ⚠️ Rapport non envoyé: {e}")
                return None
        except Exception as e:
            log.warning(f"  ⚠️ Erreur rapport: {e}")
            return None

    def place_order(self, analysis: Dict) -> bool:
        """Place l'ordre via /pending-order."""
        sym = analysis["symbol"]
        mt5_sym = analysis["clean_sym"]

        log.info(f"📈 Place ordre: {sym}")

        # Gate IA Status
        ia = float(analysis.get("coherence_pct", 0))
        if 0 < ia < 70:
            log.warning(f"  🚫 IA status {ia:.0f}% < 70% — ordre bloqué")
            self.orders_failed.append((sym, f"IA_STATUS_{ia:.0f}%"))
            return False

        # Gate MTF
        mtf_ok, mtf_reason = check_mtf_gate(sym, analysis, analysis["direction"])
        if not mtf_ok:
            log.warning(f"  🚫 MTF gate: {mtf_reason}")
            self.orders_failed.append((sym, f"MTF_GATE: {mtf_reason[:60]}"))
            return False

        # DRY RUN
        if self.dry_run:
            log.info(f"  [DRY RUN] Ordre non placé")
            self.orders_placed.append(sym)
            return True

        payload = {
            "symbol": mt5_sym,
            "action": analysis["direction"].lower(),
            "recommendation": analysis["direction"],
            "entry_price": analysis["entry"],
            "stop_loss": analysis["sl"],
            "take_profit": analysis["tp"],
            "lot": analysis["lot"],
            "execution_type": analysis["execution_type"],
            "confidence": analysis["coherence_pct"] / 100.0 if analysis["coherence_pct"] > 1 else 0.80,
            "source": "pipeline_auto_goodperfect",
            "status": "ready",
        }

        try:
            r = requests.post(f"{AI_SERVER}/pending-order", json=payload, timeout=10)

            if r.status_code == 409:
                log.info(f"  [409] Ordre existant — reset + retry")
                try:
                    from urllib.parse import quote
                    reset_sym = quote(mt5_sym, safe="")
                    requests.post(f"{AI_SERVER}/pending-order/{reset_sym}/reset", timeout=5)
                except Exception:
                    pass
                r = requests.post(f"{AI_SERVER}/pending-order", json=payload, timeout=10)

            r.raise_for_status()
            log.info(f"  ✅ Ordre placé: {analysis['direction']} {sym} @ {analysis['entry']}")
            self.orders_placed.append(sym)
            return True
        except Exception as e:
            log.error(f"  ❌ Erreur: {e}")
            self.orders_failed.append((sym, str(e)[:50]))
            return False

    async def run(self, top_n: int = 5):
        """Exécute le pipeline."""
        t0 = time.time()
        run_at = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")

        log.info("=" * 70)
        log.info(f"🚀 PIPELINE AUTO GOOD/PERFECT")
        log.info(f"━ Dry Run: {self.dry_run} | Top-N: {top_n}")
        log.info("=" * 70)

        # Phase 1: Scan Good/Perfect
        good_perfect = self.scan_goodperfect_only(top_n * 2)  # Scanne plus large
        if not good_perfect:
            log.warning("⚠️ Aucun signal Good/Perfect")
            send_whatsapp("*TradBOT*\nAucun signal Good/Perfect ce cycle")
            return

        # Notifier début
        symbols_list = "\n".join([f"  {i+1}. {s['symbol']} {s['direction']} ({s['verdict']})"
                                  for i, s in enumerate(good_perfect[:top_n])])
        send_whatsapp(
            f"*🤖 TradBOT — Pipeline Auto Good/Perfect*\n"
            f"_{run_at}_\n\n"
            f"Traite {len(good_perfect[:top_n])} signal(s):\n{symbols_list}"
        )

        # Phase 2-3: Analyser et placer ordres (top-3)
        for idx, gom_signal in enumerate(good_perfect[:top_n], 1):
            sym = gom_signal["symbol"]
            log.info(f"\n>>> [{idx}/{len(good_perfect[:top_n])}] {sym}")

            # Analyser
            analysis = self.analyze_signal(gom_signal)
            if not analysis:
                self.orders_failed.append((sym, "ANALYSIS_FAILED"))
                continue

            # Envoi rapport Word
            self.send_report_word(analysis)

            # Placer ordre
            self.place_order(analysis)

        # Résumé
        elapsed = round(time.time() - t0, 0)
        summary = (
            f"*🏁 TradBOT — Pipeline Terminé*\n"
            f"_{run_at}_\n\n"
            f"✅ Ordres placés    : {len(self.orders_placed)}\n"
            f"📄 Rapports envoyés : {len(self.reports_sent)}\n"
            f"❌ Erreurs          : {len(self.orders_failed)}\n\n"
        )
        if self.orders_placed:
            summary += f"*Placés:* {', '.join(self.orders_placed)}\n"
        if self.reports_sent:
            summary += f"*Rapports:* {', '.join(self.reports_sent)}\n"
        if self.orders_failed:
            summary += f"*Erreurs:* {', '.join([f'{s[0]} ({s[1]})' for s in self.orders_failed])}\n"
        summary += f"\n_Durée: {int(elapsed)}s_"

        send_whatsapp(summary)
        log.info(summary.replace("*", "").replace("_", ""))
        log.info("=" * 70)

async def main():
    import argparse

    parser = argparse.ArgumentParser(description="Pipeline Auto Good/Perfect + Rapports Word")
    parser.add_argument("--top-n", type=int, default=3, help="Nombre de signaux à traiter")
    parser.add_argument("--dry-run", action="store_true", help="Test sans placer ordres")
    args = parser.parse_args()

    pipeline = PipelineAutoGoodPerfect(dry_run=args.dry_run)
    await pipeline.run(top_n=args.top_n)

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
