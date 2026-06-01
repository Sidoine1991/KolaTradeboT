#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Envoie le dernier rapport Word du scan matinal + rappel des Top 3 (état JSON).
Le suivi 20 min utilise les mêmes symboles via morning_top3.json.
"""
import base64
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import requests

if sys.platform == "win32":
    os.environ["PYTHONIOENCODING"] = "utf-8"

REPO_ROOT = Path(__file__).resolve().parent
SCAN_DIR = REPO_ROOT / "reports" / "morning_scan"
STATE_FILE = REPO_ROOT / "data" / "state" / "morning_top3.json"
PSYCHOBOT = os.environ.get("TRADBOT_PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com/send-message")
PHONE = os.environ.get("TRADBOT_WHATSAPP_PHONE", "+2290196911346")


def load_top3_symbols() -> list[str]:
    if STATE_FILE.exists():
        data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        syms = [x["symbol"] for x in data.get("top3", []) if x.get("symbol")]
        if syms:
            return syms
    return []


def main() -> int:
    print("[SEND] Rapport scan matinal (Word)")
    print("=" * 70)

    if not SCAN_DIR.exists():
        print("[ERROR] Dossier reports/morning_scan introuvable")
        return 1

    reports = sorted(SCAN_DIR.glob("TradBOT_Morning_Scan_*.docx"), key=os.path.getmtime, reverse=True)
    if not reports:
        print("[ERROR] Aucun rapport .docx — lancer: python python/morning_scan.py")
        return 1

    latest = reports[0]
    print(f"[OK] {latest.name} ({latest.stat().st_size / 1024:.1f} KB)")

    top3 = load_top3_symbols()
    if top3:
        print(f"[OK] Top 3 (suivi 20 min): {top3}")
    else:
        print("[WARN] morning_top3.json absent — relancer le scan matinal")

    b64 = base64.b64encode(latest.read_bytes()).decode("utf-8")
    now = datetime.now(timezone.utc).strftime("%d/%m/%Y %H:%M UTC")
    sym_line = ", ".join(top3) if top3 else "voir rapport"

    payload = {
        "phone": PHONE,
        "message": f"📊 Scan matinal TradBOT\n{now}\nTop 3: {sym_line}\n\n{latest.name}",
        "file_data": b64,
        "file_name": latest.name,
        "file_type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    }

    try:
        resp = requests.post(PSYCHOBOT, json=payload, timeout=45, verify=False)
        if resp.status_code in (200, 201, 202):
            print("[SUCCESS] Rapport Word envoyé")
            return 0
        payload["file"] = b64
        payload["filename"] = latest.name
        payload["filetype"] = "document"
        resp2 = requests.post(PSYCHOBOT, json=payload, timeout=45, verify=False)
        if resp2.status_code in (200, 201, 202):
            print("[SUCCESS] Rapport envoyé (format alternatif)")
            return 0
        print(f"[ERROR] HTTP {resp.status_code} / {resp2.status_code}")
        return 1
    except Exception as exc:
        print(f"[ERROR] {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
