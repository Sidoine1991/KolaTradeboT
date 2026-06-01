#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Reset KolaBoT WhatsApp Session (Sans Shell Render)
Utilise l'endpoint /new-qr pour forcer une reconnexion
"""

import sys
import io
import requests
import time

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

print("=" * 80)
print("  RESET SESSION KOLABOT (Sans Shell Render)")
print("=" * 80)

BOT_URL = "https://psychobot-1si7.onrender.com"

print(f"\n📡 URL Bot: {BOT_URL}")
print("\n🔄 Étape 1: Appel endpoint /new-qr...")

try:
    response = requests.get(
        f"{BOT_URL}/new-qr",
        timeout=30,
        verify=False
    )

    if response.status_code == 200:
        data = response.json()
        print("\n✅ Session supprimée avec succès !")
        print(f"\nRéponse: {data}")

        print("\n" + "=" * 80)
        print("📱 ÉTAPE 2: SCANNER LE NOUVEAU QR CODE")
        print("=" * 80)

        print("\n🔍 Ouvrir dans le navigateur:")
        print(f"   {BOT_URL}/qr")

        print("\n📋 Instructions:")
        print("   1. Ouvrir le lien ci-dessus dans le navigateur")
        print("   2. Attendre 10-20 secondes que le QR code apparaisse")
        print("   3. WhatsApp (+237696814391) → Menu ⋮ → Appareils connectés")
        print("   4. Scanner le QR code affiché sur la page")

        print("\n⏳ Attendre ~30 secondes après scan...")
        print("   Le bot va se connecter automatiquement")

        print("\n" + "=" * 80)
        print("✅ RESET INITIÉ AVEC SUCCÈS")
        print("=" * 80)

        print("\n🎯 Prochaines actions:")
        print("   1. Scanner le QR code maintenant")
        print("   2. Attendre connexion (logs Render montreront '✓ Connection successful')")
        print("   3. Envoyer message texte simple pour tester")
        print("   4. Envoyer message vocal pour tester transcription")

        print("\n📊 Résolution des problèmes:")
        print("   ✅ Session WhatsApp corrompue → RÉSOLU")
        print("   ⏳ AWS Transcribe chunk size → Fix en cours de déploiement")
        print("   ⏳ NVIDIA API key → À mettre à jour sur Render")
        print("   ⏳ OpenAI crédits → À ajouter ($5 minimum)")

    else:
        print(f"\n❌ Erreur HTTP {response.status_code}")
        print(f"Réponse: {response.text[:300]}")

        print("\n🔧 Solution alternative:")
        print("   1. Render Dashboard → Manual Deploy → Deploy latest commit")
        print("   2. Cela forcera un redémarrage complet")
        print("   3. Les logs afficheront un nouveau QR code")

except requests.exceptions.Timeout:
    print("\n❌ Timeout - Le bot ne répond pas")
    print("\n🔧 Vérifier:")
    print("   1. Render Dashboard → Status = 'Live' ?")
    print("   2. Si 'Sleeping', attendre réveil (~30 sec)")
    print("   3. Logs montrent des erreurs ?")

except Exception as e:
    print(f"\n❌ Erreur: {str(e)}")

print("\n" + "=" * 80)
print("📄 Documentation Complète:")
print("   D:/Dev/TradBOT/psychobot_reconnect_instructions.md")
print("=" * 80)
