#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Suivi 20 min — rapport unifié sur le TOP 3 du scan matinal uniquement.
Lit data/state/morning_top3.json (pas de liste XAUUSD figée).
"""

from __future__ import annotations

import json
import os
import sys
import warnings
from datetime import datetime, timezone
from pathlib import Path

import requests

warnings.filterwarnings("ignore")

if sys.platform == "win32":
    os.environ["PYTHONIOENCODING"] = "utf-8"

REPO_ROOT = Path(__file__).resolve().parent.parent
STATE_FILE = REPO_ROOT / "data" / "state" / "morning_top3.json"
sys.path.insert(0, str(REPO_ROOT / "python"))
from top3_symbols import load_top3_meta, load_top3_symbols  # noqa: E402

AI_SERVER = os.environ.get("TRADBOT_AI_SERVER", "http://127.0.0.1:8000").rstrip("/")
PSYCHOBOT = os.environ.get("TRADBOT_PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com/send-message")
PHONE = os.environ.get("TRADBOT_WHATSAPP_PHONE", "+2290196911346")
FALLBACK_LOG = REPO_ROOT / "whatsapp_alerts.log"


class UnifiedTop3Report:
    def __init__(self):
        self.top3_meta = load_top3_meta()
        self.symbols = load_top3_symbols()
        self.data: dict = {}

    def fetch_symbol_data(self, symbol: str) -> dict:
        out = {
            "symbol": symbol,
            "gom": {},
            "bias": {},
            "order": {},
            "price": 0.0,
            "confluence": 0.0,
        }
        try:
            gom_r = requests.get(
                f"{AI_SERVER}/gom-verdict",
                params={"symbol": symbol},
                timeout=12,
            )
            if gom_r.status_code == 200:
                gom = gom_r.json()
                if gom.get("ok") is not False:
                    out["gom"] = gom
                    out["price"] = float(gom.get("price") or 0)
                    out["confluence"] = max(
                        float(gom.get("score_buy") or 0),
                        float(gom.get("score_sell") or 0),
                    )

            bias_r = requests.get(
                f"{AI_SERVER}/session-bias",
                params={"symbol": symbol},
                timeout=10,
            )
            if bias_r.status_code == 200:
                bias = bias_r.json()
                if bias.get("success") and "data" in bias:
                    out["bias"] = bias["data"]
                else:
                    out["bias"] = bias

            order_r = requests.get(
                f"{AI_SERVER}/pending-order",
                params={"symbol": symbol},
                timeout=10,
            )
            if order_r.status_code == 200:
                out["order"] = order_r.json()
        except Exception as exc:
            print(f"    Warning {symbol}: {exc}")

        return out

    def fetch_all_data(self) -> bool:
        if not self.symbols:
            return False
        print(f"[COLLECT] Top 3 scan matinal: {self.symbols}")
        for sym in self.symbols:
            print(f"  … {sym}")
            self.data[sym] = self.fetch_symbol_data(sym)
        return True

    def build_message(self) -> str:
        now = datetime.now(timezone.utc)
        time_str = now.strftime("%H:%M")
        date_str = now.strftime("%d/%m")

        ranked = sorted(
            self.data.items(),
            key=lambda x: x[1].get("confluence", 0),
            reverse=True,
        )

        scan_time = ""
        if STATE_FILE.exists():
            try:
                st = json.loads(STATE_FILE.read_text(encoding="utf-8"))
                scan_time = st.get("generated_at", "")[:16].replace("T", " ")
            except Exception:
                pass

        msg = f"""📊 *TradBOT — Suivi 20 min* [{time_str} UTC]

*Top 3 du scan matinal* | {date_str} {time_str} UTC
_Scan: {scan_time or 'voir morning_top3.json'}_
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"""
        medals = ["🥇", "🥈", "🥉"]
        for idx, (symbol, data) in enumerate(ranked[:3]):
            medal = medals[idx] if idx < 3 else f"#{idx+1}"
            gom = data.get("gom") or {}
            bias = data.get("bias") or {}
            order = data.get("order") or {}
            price = float(gom.get("price") or data.get("price") or 0)
            verdict = gom.get("verdict", "WAIT")
            vnum = int(gom.get("verdict_num") or 0)
            ve = "🟢" if vnum > 0 else "🔴" if vnum < 0 else "⚪"

            meta = next((m for m in self.top3_meta if m.get("symbol") == symbol), {})
            cat = meta.get("category", "")

            msg += f"""{medal} *{symbol}* {f'({cat})' if cat else ''}
   💰 Prix: {price:.5g}
   {ve} GOM: {verdict} | BUY={float(gom.get('score_buy') or 0):.1f} SELL={float(gom.get('score_sell') or 0):.1f}
   Biais: {bias.get('direction', 'N/A')}
"""
            if order.get("ok") and order.get("order"):
                od = order["order"]
                msg += f"   📦 EA: {od.get('action', 'N/A')} @ {od.get('entry_price', 'N/A')}\n"
            msg += "\n"

        msg += """━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏱ Prochain suivi dans 20 min
_Symboles = Top 3 opportunités du jour uniquement_
"""
        return msg

    def send_whatsapp(self, message: str) -> bool:
        try:
            resp = requests.post(
                PSYCHOBOT,
                json={"phone": PHONE, "message": message},
                timeout=15,
                verify=False,
            )
            ok = resp.status_code in (200, 201, 202)
            print(f"[SEND] {'OK' if ok else 'FAIL'} HTTP {resp.status_code}")
            return ok
        except Exception as exc:
            print(f"[ERROR] {exc}")
            return False

    def save_fallback(self, message: str) -> None:
        ts = datetime.now(timezone.utc).isoformat()
        with FALLBACK_LOG.open("a", encoding="utf-8") as f:
            f.write(f"\n{'=' * 80}\n[{ts}] TOP3 UNIFIED\n{'=' * 80}\n{message}\n")
        print(f"[FALLBACK] {FALLBACK_LOG}")

    def save_locally(self, message: str) -> None:
        path = REPO_ROOT / "unified_top3_report_latest.txt"
        path.write_text(message, encoding="utf-8")
        print(f"[SAVED] {path}")

    def run(self) -> str | None:
        print("=" * 70)
        print("[START] Suivi 20 min — Top 3 scan matinal (pas XAUUSD seul)")
        if not self.symbols:
            print("[SKIP] Aucun symbole — lancer python/morning_scan.py")
            return None
        if not self.top3_meta:
            print(f"[WARN] morning_top3.json absent — repli: {self.symbols}")
        if not self.fetch_all_data():
            return None
        message = self.build_message()
        self.save_locally(message)
        if not self.send_whatsapp(message):
            self.save_fallback(message)
        print("[COMPLETE]")
        return message


if __name__ == "__main__":
    UnifiedTop3Report().run()
