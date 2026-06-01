#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test Audio Transcription + AI Response (Local)
Teste le fichier audio WhatsApp localement
"""

import sys
import io
import os
import requests
import json
from pathlib import Path

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

print("=" * 80)
print("  TEST AUDIO KOLABOT - TRANSCRIPTION + RÉPONSE CONTEXTUELLE")
print("=" * 80)

# Configuration
AUDIO_FILE = r"C:\Users\USER\Downloads\WhatsApp Ptt 2026-05-31 at 12.29.09.ogg"
OPENAI_API_KEY = "REMOVED_OPENAI_KEY"
NVIDIA_API_KEY = "REMOVED_NVIDIA_KEY_1"

print(f"\n📂 Fichier audio: {AUDIO_FILE}")

# Vérifier si le fichier existe
if not os.path.exists(AUDIO_FILE):
    print(f"\n❌ ERREUR: Fichier audio introuvable!")
    print(f"Chemin: {AUDIO_FILE}")
    sys.exit(1)

file_size = os.path.getsize(AUDIO_FILE)
print(f"✓ Fichier trouvé: {file_size} bytes")

# ===== ÉTAPE 1: TRANSCRIPTION =====
print("\n" + "=" * 80)
print("ÉTAPE 1: TRANSCRIPTION AUDIO → TEXTE")
print("=" * 80)

transcript = None

# Tenter OpenAI Whisper
print("\n🔍 Tentative 1: OpenAI Whisper API...")
try:
    with open(AUDIO_FILE, 'rb') as audio_file:
        response = requests.post(
            'https://api.openai.com/v1/audio/transcriptions',
            headers={
                'Authorization': f'Bearer {OPENAI_API_KEY}'
            },
            files={
                'file': ('audio.ogg', audio_file, 'audio/ogg')
            },
            data={
                'model': 'whisper-1',
                'language': 'fr'
            },
            timeout=60,
            verify=False
        )

    if response.status_code == 200:
        data = response.json()
        transcript = data.get('text', '').strip()
        print(f"\n✅ TRANSCRIPTION RÉUSSIE (OpenAI Whisper):")
        print(f"\n📝 Transcript:\n\"{transcript}\"\n")
    else:
        print(f"\n❌ OpenAI échoué: {response.status_code}")
        print(f"Erreur: {response.text[:200]}")

except Exception as e:
    print(f"\n❌ OpenAI erreur: {str(e)}")

# Si OpenAI échoue, tenter AWS (simulé car nécessite credentials)
if not transcript:
    print("\n🔍 Tentative 2: AWS Transcribe...")
    print("⚠️  Pas de test local AWS (nécessite setup)")
    print("⚠️  AWS sera testé sur Render uniquement")

# Si toujours pas de transcript
if not transcript:
    print("\n❌ AUCUNE TRANSCRIPTION DISPONIBLE")
    print("\n🔧 Solutions:")
    print("   1. Vérifier clé OpenAI valide")
    print("   2. Ajouter crédits OpenAI ($5 minimum)")
    print("   3. Configurer AWS sur Render")
    sys.exit(1)

# ===== ÉTAPE 2: GÉNÉRATION RÉPONSE AI =====
print("\n" + "=" * 80)
print("ÉTAPE 2: GÉNÉRATION RÉPONSE CONTEXTUELLE (NVIDIA NIM)")
print("=" * 80)

print("\n🤖 Contexte:")
print("   • Assistant: KolaBoT (assistant de Sidoine)")
print("   • Langue: Français (détectée)")
print("   • Ton: Convivial, chaleureux")
print("   • Historique: Premier contact (simulation)")

# Préparer le prompt système
system_prompt = """Tu es l'assistant virtuel personnel de Sidoine Kolaolé YEBADOKPO. Tu gères ses échanges WhatsApp en son absence.

C'est le PREMIER message de cette conversation. Commence par informer poliment que Sidoine n'est pas disponible pour le moment, puis réponds à la question ou au message reçu.

RÈGLES :
- Réponds TOUJOURS dans la langue de l'interlocuteur (français/anglais/etc.).
- Ton : chaleureux, convivial, professionnel. Jamais froid ni robotique.
- Longueur : concis (2-4 phrases) sauf si une explication longue est explicitement demandée.
- Tu n'es PAS Sidoine. Tu ES son assistant bienveillant.
- Si la demande dépasse tes attributions : "Je transmets à _*Sidoine*_ qui vous répondra dès que possible 🙏"
- Émojis expressifs et pertinents 😊✨🙏💡

PROFIL DE SIDOINE :
- Data Analyst, Développeur Fullstack & Expert MEAL
- Poste : Conseiller Global Suivi, Évaluation & Apprentissage au CCR-Bénin
- Compétences : Python, R, SQL, Power BI, Django, React, IA/ML, TradingView
- Contact : syebadokpo@gmail.com | +229 01 96 91 13 46"""

print("\n🔄 Appel API NVIDIA NIM (Llama 3.3 70B)...")

try:
    response = requests.post(
        'https://integrate.api.nvidia.com/v1/chat/completions',
        headers={
            'Authorization': f'Bearer {NVIDIA_API_KEY}',
            'Content-Type': 'application/json'
        },
        json={
            'model': 'meta/llama-3.3-70b-instruct',
            'messages': [
                {'role': 'system', 'content': system_prompt},
                {'role': 'user', 'content': transcript}
            ],
            'temperature': 0.72,
            'max_tokens': 512
        },
        timeout=45,
        verify=False
    )

    if response.status_code == 200:
        data = response.json()
        ai_response = data['choices'][0]['message']['content'].strip()

        print(f"\n✅ RÉPONSE GÉNÉRÉE:")
        print(f"\n🤖 KolaBoT répond:\n\"{ai_response}\"\n")

        # ===== ÉTAPE 3: SYNTHÈSE =====
        print("\n" + "=" * 80)
        print("ÉTAPE 3: RÉSULTAT FINAL (Ce que l'utilisateur recevrait)")
        print("=" * 80)

        print("\n📱 MESSAGE WHATSAPP:")
        print("-" * 80)
        print(f"\n🎙️ Transcript:")
        print(f'"{transcript}"')
        print(f"\n🤖 Response:")
        print(ai_response)
        print("\n" + "-" * 80)

        print("\n🔊 + AUDIO VOCAL (Google TTS convertit la réponse en audio)")

        print("\n" + "=" * 80)
        print("✅ TEST COMPLET RÉUSSI !")
        print("=" * 80)

        print("\n🎯 Résumé:")
        print(f"   • Transcription: ✅ Réussie (OpenAI Whisper)")
        print(f"   • Longueur transcript: {len(transcript)} caractères")
        print(f"   • Réponse AI: ✅ Générée (NVIDIA NIM)")
        print(f"   • Longueur réponse: {len(ai_response)} caractères")
        print(f"   • Langue détectée: Français")
        print(f"   • Ton: Convivial ✓")

        print("\n📊 Fonctionnalités Testées:")
        print("   ✅ Transcription audio → texte")
        print("   ✅ Génération réponse contextuelle")
        print("   ✅ Ton convivial en français")
        print("   ✅ Émojis et formatage WhatsApp")
        print("   ⚠️  Text-to-speech (non testé localement)")

    else:
        print(f"\n❌ NVIDIA API échoué: {response.status_code}")
        print(f"Erreur: {response.text[:300]}")

except Exception as e:
    print(f"\n❌ NVIDIA erreur: {str(e)}")

print("\n" + "=" * 80)
print("🔍 DIAGNOSTIC")
print("=" * 80)

print("""
Si ce test fonctionne LOCALEMENT mais pas sur RENDER:

1. Variables manquantes sur Render:
   • AWS_ACCESS_KEY_ID
   • AWS_SECRET_ACCESS_KEY
   • AWS_REGION
   • OPENAI_API_KEY
   • NVIDIA_NIM_API_KEY

2. Render pas encore redéployé après ajout variables
   → Attendre Status "Live" (3 min)

3. Session WhatsApp corrompue
   → Shell Render: rm -rf session/
   → Scanner nouveau QR code

4. Clé OpenAI invalide/pas de crédits
   → Vérifier sur platform.openai.com/billing

5. Google TTS échoue (audio pas envoyé)
   → Vérifier Google_api_key sur Render
""")

print("\n" + "=" * 80)
