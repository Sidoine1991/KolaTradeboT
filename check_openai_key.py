#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check if OpenAI API Key is valid
"""

import sys
import io
import os
import requests

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

print("=" * 70)
print("  OPENAI API KEY VALIDATION")
print("=" * 70)

# Demander la clé
print("\nCopiez la clé OPENAI_API_KEY depuis Render Dashboard")
print("(Environment variables → OPENAI_API_KEY → copier la valeur)\n")

api_key = input("Collez la clé ici : ").strip()

if not api_key:
    print("\n❌ Aucune clé fournie")
    sys.exit(1)

print(f"\n✓ Clé reçue (longueur: {len(api_key)} caractères)")
print(f"✓ Commence par: {api_key[:10]}...")

# Test 1: Format de la clé
print("\n" + "=" * 70)
print("TEST 1: Format de la clé")
print("=" * 70)

if api_key.startswith('sk-'):
    print("✅ Format valide (commence par 'sk-')")
else:
    print("❌ Format invalide (devrait commencer par 'sk-')")
    print("   La clé n'est probablement pas correcte")

# Test 2: Appel API pour vérifier validité
print("\n" + "=" * 70)
print("TEST 2: Validité de la clé (appel API)")
print("=" * 70)

print("\n🔍 Test de connexion à l'API OpenAI...")

try:
    response = requests.get(
        'https://api.openai.com/v1/models',
        headers={
            'Authorization': f'Bearer {api_key}'
        },
        timeout=10
    )

    if response.status_code == 200:
        print("✅ CLÉ VALIDE - L'API répond correctement")

        data = response.json()
        models = data.get('data', [])
        print(f"✓ {len(models)} modèles disponibles")

        # Vérifier si Whisper est disponible
        whisper_available = any('whisper' in m.get('id', '').lower() for m in models)
        if whisper_available:
            print("✅ Modèle Whisper disponible")
        else:
            print("⚠️  Modèle Whisper non trouvé dans la liste")

    elif response.status_code == 401:
        print("❌ CLÉ INVALIDE - Erreur d'authentification")
        print("   La clé est incorrecte ou a expiré")
        print("\n   Solution:")
        print("   1. Allez sur: https://platform.openai.com/api-keys")
        print("   2. Créez une NOUVELLE clé")
        print("   3. Remplacez l'ancienne sur Render")

    elif response.status_code == 429:
        print("⚠️  QUOTA DÉPASSÉ - Trop de requêtes")
        print("   La clé est valide mais le quota est atteint")
        print("\n   Solution:")
        print("   Attendez quelques minutes et réessayez")

    else:
        print(f"❌ ERREUR - Status code: {response.status_code}")
        print(f"   Réponse: {response.text[:200]}")

except requests.exceptions.Timeout:
    print("❌ TIMEOUT - L'API ne répond pas")
    print("   Problème de connexion réseau")

except Exception as e:
    print(f"❌ ERREUR: {str(e)}")

# Test 3: Vérifier les crédits (si clé valide)
print("\n" + "=" * 70)
print("TEST 3: Vérification des crédits")
print("=" * 70)

print("\n📊 Pour vérifier vos crédits OpenAI:")
print("   1. Allez sur: https://platform.openai.com/account/billing/overview")
print("   2. Vérifiez que vous avez des crédits disponibles")
print("   3. Si balance = $0, ajoutez des crédits ($5 minimum recommandé)")

# Résumé
print("\n" + "=" * 70)
print("RÉSUMÉ")
print("=" * 70)

print("""
Si la clé est INVALIDE:
   → Créez une nouvelle clé sur platform.openai.com
   → Remplacez sur Render Dashboard
   → Attendez redéploiement (3 min)

Si la clé est VALIDE mais quota atteint:
   → Ajoutez des crédits sur platform.openai.com/billing
   → Minimum $5 recommandé

Si la clé est VALIDE avec crédits:
   → Le problème est ailleurs (vérifier logs Render)
""")

print("=" * 70)
