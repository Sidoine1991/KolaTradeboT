#!/usr/bin/env python3
import sys
import io
import requests
import json

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

print("Envoi message test à PsychoBot...\n")

url = "https://psychobot-1si7.onrender.com/send-message"
payload = {
    "phone": "+237696814391",
    "message": """🎉 KolaBoT - Tests Réussis !

✅ Session WhatsApp connectée
✅ Messages texte fonctionnent
✅ NVIDIA génère réponses contextuelles
✅ Historique conservé ("Kolaole", restaurant)

🔧 Fix Google TTS Appliqué:
Commit e0099d9 - Limite 200 caractères

⏳ Attendre redéploiement (~3 min)

🎯 APRÈS "Live":
Envoyer nouveau message VOCAL
→ Audio devrait marcher maintenant !

📊 Reste à faire (optionnel):
1. Mettre à jour NVIDIA_NIM_API_KEY
   REMOVED_NVIDIA_KEY_2

2. Ajouter crédits OpenAI ($5)
   platform.openai.com/billing

🚀 KolaBoT quasi opérationnel !"""
}

try:
    response = requests.post(url, json=payload, timeout=30, verify=False)

    if response.status_code in [200, 201]:
        print("✅ Message envoyé avec succès !")
        data = response.json()
        print(f"Réponse: {json.dumps(data, indent=2)}")
    else:
        print(f"❌ Erreur HTTP {response.status_code}")
        print(f"Réponse: {response.text[:200]}")

except Exception as e:
    print(f"❌ Erreur: {str(e)}")
