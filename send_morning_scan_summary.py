#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Send morning scan summary via PsychoBot with file location
"""

import sys
import io
import json
import requests
from pathlib import Path
from datetime import datetime
from docx import Document

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Lire le fichier Word pour extraire le contenu
scan_file = Path("D:/Dev/TradBOT/reports/morning_scan/TradBOT_Morning_Scan_20260530_0657.docx")

print(f"[📄] Reading scan report: {scan_file.name}\n")

try:
    doc = Document(scan_file)

    # Extraire le contenu
    content = []
    for para in doc.paragraphs:
        text = para.text.strip()
        if text and len(text) > 0:
            content.append(text)

    # Créer le message récapitulatif
    summary = "\n".join(content[:30])  # Premiers 30 paragraphes

except Exception as e:
    summary = "Unable to read Word file"
    print(f"[⚠️] Error reading file: {e}\n")

# Message WhatsApp
msg = f"""📊 TradBOT Morning Scan Report
Generated: 30/05/2026 06:57 UTC

📋 SCAN SUMMARY:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{summary}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📥 FICHIER COMPLET:
Chemin local: D:\\Dev\\TradBOT\\reports\\morning_scan\\TradBOT_Morning_Scan_20260530_0657.docx
Taille: 35.0 KB
Format: Word (.docx)

⚙️ NOTE:
L'endpoint PsychoBot nécessite une amélioration pour supporter l'upload de fichiers.
Le rapport complet est disponible localement."""

print(msg)
print("\n" + "="*70)
print("SENDING VIA PSYCHOBOT")
print("="*70 + "\n")

# Envoyer via PsychoBot
session = requests.Session()
session.verify = False

payload = {
    "phone": "+2290196911346",
    "message": msg
}

try:
    resp = session.post(
        "https://psychobot-1si7.onrender.com/send-message",
        json=payload,
        timeout=15
    )

    if resp.status_code in [200, 201]:
        print("[✅] Morning scan summary sent successfully via PsychoBot")
        print(f"Status: {resp.status_code}")
        resp_data = resp.json()
        print(f"Response: {json.dumps(resp_data, indent=2)}\n")

        print("="*70)
        print("NEXT STEPS TO SEND FILE:")
        print("="*70)
        print("\n1. Add /send-file endpoint to PsychoBot that supports:")
        print("   - Multipart form-data upload")
        print("   - File types: DOCX, PDF, XLSX")
        print("   - WhatsApp Media API integration")
        print("\n2. Then use: curl -F file=@report.docx ...")
        print("\n3. OR use WhatsApp Cloud API /media endpoint directly\n")

        sys.exit(0)
    else:
        print(f"[❌] PsychoBot error: {resp.status_code}")
        raise Exception(f"Status {resp.status_code}")

except Exception as e:
    print(f"[❌] Failed: {str(e)[:100]}")
    sys.exit(1)
