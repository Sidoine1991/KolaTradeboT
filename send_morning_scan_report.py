#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Send morning scan report Word file via PsychoBot
"""

import sys
import io
import json
import requests
import base64
from pathlib import Path
from datetime import datetime

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Chemin du rapport
scan_file = Path("D:/Dev/TradBOT/reports/morning_scan/TradBOT_Morning_Scan_20260530_0657.docx")

if not scan_file.exists():
    print(f"[❌] File not found: {scan_file}")
    sys.exit(1)

print(f"[📄] Loading scan report: {scan_file.name}")
print(f"[📊] File size: {scan_file.stat().st_size / 1024:.1f} KB\n")

# Lire le fichier
with open(scan_file, "rb") as f:
    file_data = f.read()

# Encoder en base64
file_base64 = base64.b64encode(file_data).decode('utf-8')

print(f"[✅] File encoded to base64 ({len(file_base64) / 1024:.1f} KB)\n")

# Préparer le message
now = datetime.utcnow().strftime("%d/%m/%Y %H:%M UTC")

message_text = f"""📊 TradBOT Morning Scan Report

Generated: {now}
File: {scan_file.name}

Attached: Complete morning scan analysis with top 3 symbols"""

print(f"[📤] Preparing to send via PsychoBot...\n")
print(f"Message:\n{message_text}\n")

# Envoyer via PsychoBot
session = requests.Session()
session.verify = False

payload = {
    "phone": "+2290196911346",
    "message": message_text,
    "file_data": file_base64,
    "file_name": scan_file.name,
    "file_type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
}

try:
    print("="*70)
    print("SENDING VIA PSYCHOBOT")
    print("="*70 + "\n")

    resp = session.post(
        "https://psychobot-1si7.onrender.com/send-message",
        json=payload,
        timeout=30
    )

    if resp.status_code in [200, 201]:
        print("[✅] Morning scan report sent successfully via PsychoBot")
        print(f"Status: {resp.status_code}")
        resp_data = resp.json()
        print(f"Response: {json.dumps(resp_data, indent=2)}\n")
        sys.exit(0)
    else:
        print(f"[❌] PsychoBot error: {resp.status_code}")
        print(f"Response: {resp.text[:300]}\n")
        raise Exception(f"Status {resp.status_code}")

except Exception as e:
    print(f"[❌] PsychoBot failed: {str(e)[:100]}")
    print("[📝] Logging to fallback file...\n")

    try:
        with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
            now_iso = datetime.now().isoformat()
            f.write(f"\n{'='*70}\n[{now_iso}] Morning Scan Report (File Send Fallback)\n{'='*70}\n")
            f.write(f"File: {scan_file.name}\n")
            f.write(f"Size: {scan_file.stat().st_size / 1024:.1f} KB\n")
            f.write(f"Message: {message_text}\n")
        print("[✅] File reference logged to whatsapp_alerts.log\n")
        sys.exit(0)
    except Exception as log_err:
        print(f"[❌] Logging failed: {log_err}\n")
        sys.exit(1)
