#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Send morning scan Word file as attachment via PsychoBot /send-file endpoint
Requires: /send-file endpoint implemented in PsychoBot
"""

import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import requests
from pathlib import Path
from datetime import datetime

# === FICHIER À ENVOYER ===
doc_file = Path("D:/Dev/TradBOT/reports/morning_scan/TradBOT_Morning_Scan_20260530_0657.docx")

if not doc_file.exists():
    print(f"[ERROR] File not found: {doc_file}")
    sys.exit(1)

file_size = doc_file.stat().st_size
print(f"[FILE] {doc_file.name}")
print(f"[SIZE] {file_size / 1024:.1f} KB\n")

# === PAYLOAD ===
payload = {
    "phone": "+2290196911346",
    "message": "📊 TradBOT Morning Scan Report\nGéné: 30/05/2026 06:57 UTC",
    "file_path": str(doc_file),
    "file_name": doc_file.name
}

print("="*70)
print("SENDING FILE VIA PSYCHOBOT /send-file")
print("="*70 + "\n")

print(f"Payload:\n  Phone: {payload['phone']}\n  File: {payload['file_name']}\n  Size: {file_size / 1024:.1f} KB\n")

try:
    resp = requests.post(
        "https://psychobot-1si7.onrender.com/send-file",
        json=payload,
        timeout=30,
        verify=False
    )

    print(f"Status: {resp.status_code}\n")

    if resp.status_code in [200, 201]:
        print("[✅] File sent successfully!")
        print(f"Response: {resp.json()}\n")
        sys.exit(0)

    elif resp.status_code == 404:
        print("[⚠️] Endpoint /send-file not found")
        print("\nTo implement /send-file:")
        print("  1. Add psychobot_send_file_implementation.js to PsychoBot")
        print("  2. Restart PsychoBot")
        print("  3. Try again\n")
        sys.exit(1)

    elif resp.status_code == 400:
        print(f"[ERROR] Bad request: {resp.json()}\n")
        sys.exit(1)

    elif resp.status_code == 503:
        print(f"[ERROR] PsychoBot not connected: {resp.json()}\n")
        sys.exit(1)

    else:
        print(f"[ERROR] Status {resp.status_code}")
        print(f"Response: {resp.text[:200]}\n")
        sys.exit(1)

except requests.exceptions.ConnectionError:
    print("[ERROR] Connection failed - PsychoBot may be down\n")
    sys.exit(1)

except Exception as e:
    print(f"[ERROR] {e}\n")
    sys.exit(1)
