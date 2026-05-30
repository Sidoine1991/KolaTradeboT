#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Send morning scan report Word file as attachment via PsychoBot /send-file endpoint
"""

import sys
import io
import json
import requests
from pathlib import Path
from datetime import datetime

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Fichier à envoyer
scan_file = Path("D:/Dev/TradBOT/reports/morning_scan/TradBOT_Morning_Scan_20260530_0657.docx")

if not scan_file.exists():
    print(f"[❌] File not found: {scan_file}")
    sys.exit(1)

file_size = scan_file.stat().st_size
print(f"[📄] Sending file: {scan_file.name}")
print(f"[📊] File size: {file_size / 1024:.1f} KB\n")

# Préparer la requête
session = requests.Session()
session.verify = False

payload = {
    "phone": "+2290196911346",
    "message": "📊 TradBOT Morning Scan Report - 30/05/2026 06:57 UTC",
    "file_path": str(scan_file),
    "file_name": scan_file.name
}

print("="*70)
print("SENDING FILE VIA PSYCHOBOT /send-file ENDPOINT")
print("="*70 + "\n")

print(f"Payload: {json.dumps(payload, indent=2)}\n")

try:
    print("[📤] Sending request...\n")

    resp = session.post(
        "https://psychobot-1si7.onrender.com/send-file",
        json=payload,
        timeout=30
    )

    print(f"Status: {resp.status_code}\n")

    if resp.status_code in [200, 201]:
        resp_data = resp.json()
        print("[✅] File sent successfully!")
        print(f"Response: {json.dumps(resp_data, indent=2)}\n")
        sys.exit(0)
    elif resp.status_code == 404:
        print("[⚠️] Endpoint /send-file not found on PsychoBot")
        print("[💡] Need to implement the endpoint first\n")
        print("To implement /send-file endpoint in PsychoBot:")
        print("1. Add psychobot_send_file_patch.js to PsychoBot index.js")
        print("2. Restart PsychoBot")
        print("3. Try again\n")
        sys.exit(1)
    else:
        print(f"[❌] Error: {resp.status_code}")
        print(f"Response: {resp.text[:300]}\n")
        sys.exit(1)

except requests.exceptions.ConnectionError:
    print("[❌] Connection error - PsychoBot may be down")
    print("[💡] Check: https://psychobot-1si7.onrender.com/ping\n")
    sys.exit(1)

except Exception as e:
    print(f"[❌] Error: {str(e)}\n")
    sys.exit(1)
