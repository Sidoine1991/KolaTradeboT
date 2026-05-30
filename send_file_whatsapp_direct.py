#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Send file directly via WhatsApp Cloud API
Requires: WhatsApp Business Account + Phone Number ID + Access Token
"""

import sys
import io
import json
import base64
import requests
from pathlib import Path
from datetime import datetime

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

print("="*70)
print("WHATSAPP FILE UPLOAD - SETUP REQUIRED")
print("="*70 + "\n")

print("⚠️ LIMITATION IDENTIFIÉE:")
print("-" * 70)
print("""
PsychoBot utilise Baileys (WhatsApp Web) qui ne supporte pas l'upload
de fichiers via API. Les fichiers doivent être envoyés via:

1. WhatsApp Business Cloud API (recommandé)
   - Nécessite: Phone Number ID + Access Token
   - Supporte: DOCX, PDF, XLSX, etc.

2. WhatsApp Web Client direct (via Baileys)
   - Limitation: Pas d'upload de fichier programmatique

3. Alternative: Copier-coller le fichier manuellement via WhatsApp Web
""")

print("\n🔧 SOLUTION:")
print("-" * 70)

scan_file = Path("D:/Dev/TradBOT/reports/morning_scan/TradBOT_Morning_Scan_20260530_0657.docx")

if scan_file.exists():
    print(f"""
Fichier disponible:
  📄 {scan_file.name}
  📊 Taille: {scan_file.stat().st_size / 1024:.1f} KB
  📍 Chemin: {scan_file}

OPTIONS:
-------

A) POUR ENVOYER AVEC L'API WHATSAPP CLOUD:
   1. Créer une app WhatsApp Business sur Meta Developers
   2. Obtenir: Phone Number ID + Access Token (24h)
   3. Implémenter l'endpoint /upload-media dans PsychoBot
   4. Utiliser: curl -X POST "https://graph.instagram.com/v18.0/PHONE_ID/media" \\
        -H "Authorization: Bearer TOKEN" \\
        -F "file=@rapport.docx" \\
        -F "type=document"

B) ALTERNATIVE IMMÉDIATE:
   1. Partager le lien local via partage de fichier Windows
   2. Ou copier-coller le contenu du rapport dans WhatsApp

C) MEILLEURE PRATIQUE:
   1. Héberger le fichier sur un serveur (ex: AWS S3, Render)
   2. Envoyer le lien de téléchargement via WhatsApp
   3. Exemple: "📄 Rapport disponible: https://storage.../report.docx"

""")

print("="*70)
print("POUR IMPLÉMENTER LA SOLUTION A:")
print("="*70 + "\n")

print("""
Ajouter à PsychoBot (index.js):

app.post('/upload-media', async (req, res) => {
    try {
        const { file_path, media_type } = req.body;
        const token = process.env.WHATSAPP_ACCESS_TOKEN;
        const phoneId = process.env.WHATSAPP_PHONE_ID;

        if (!file_path || !token || !phoneId) {
            return res.status(400).json({ error: 'Missing required params' });
        }

        const fs = require('fs');
        const fileBuffer = fs.readFileSync(file_path);
        const fileName = require('path').basename(file_path);

        const form = new FormData();
        form.append('file', new Blob([fileBuffer]), fileName);
        form.append('type', media_type || 'document');

        const resp = await fetch(
            `https://graph.instagram.com/v18.0/${phoneId}/media`,
            {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${token}` },
                body: form
            }
        );

        const data = await resp.json();
        res.json({ success: true, media_id: data.id });

    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

Puis envoyer via:

app.post('/send-file-via-whatsapp', async (req, res) => {
    const { phone, media_id } = req.body;
    const jid = phone.replace(/[^0-9]/g, '') + '@s.whatsapp.net';

    await sock.sendMessage(jid, {
        document: { id: media_id }
    });

    res.json({ success: true });
});
""")

print("="*70 + "\n")

print("[📝] STADE ACTUEL:")
print("  • PsychoBot: Fonctionnel pour messages texte")
print("  • WhatsApp Cloud API: Non intégrée")
print("  • Fichier local: Disponible et prêt\n")

print("[⏭️  PROCHAINES ÉTAPES:]")
print("  1. Intégrer WhatsApp Cloud API dans PsychoBot")
print("  2. Implémenter /upload-media endpoint")
print("  3. Ou envoyer fichier via lien de téléchargement\n")
