#!/usr/bin/env python3
import sys
import io
import requests

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

api_key = "YOUR_OPENAI_API_KEY"

print("=" * 70)
print("  TEST CLÉ OPENAI")
print("=" * 70)
print(f"\nClé: {api_key[:20]}...{api_key[-10:]}")
print(f"Longueur: {len(api_key)} caractères\n")

print("🔍 Test 1: Appel API OpenAI...")

try:
    response = requests.get(
        'https://api.openai.com/v1/models',
        headers={'Authorization': f'Bearer {api_key}'},
        timeout=10
    )

    print(f"Status Code: {response.status_code}")

    if response.status_code == 200:
        print("\n✅ CLÉ VALIDE!")
        data = response.json()
        models = len(data.get('data', []))
        print(f"✓ {models} modèles disponibles")

        # Chercher Whisper
        whisper = [m for m in data.get('data', []) if 'whisper' in m.get('id', '').lower()]
        if whisper:
            print(f"✅ Whisper disponible: {whisper[0]['id']}")
        else:
            print("⚠️  Whisper non trouvé")

    elif response.status_code == 401:
        print("\n❌ CLÉ INVALIDE ou EXPIRÉE")
        print(f"Erreur: {response.text}")
        print("\n🔧 Solution:")
        print("   1. Allez sur: https://platform.openai.com/api-keys")
        print("   2. Cliquez sur votre ancienne clé")
        print("   3. Si elle est expirée, créez-en une nouvelle")
        print("   4. Remplacez sur Render")

    elif response.status_code == 429:
        print("\n⚠️  QUOTA DÉPASSÉ")
        print("Clé valide mais trop de requêtes")

    else:
        print(f"\n❌ ERREUR {response.status_code}")
        print(response.text[:300])

except requests.exceptions.ConnectionError:
    print("❌ Erreur de connexion (proxy/firewall?)")
except requests.exceptions.Timeout:
    print("❌ Timeout - API ne répond pas")
except Exception as e:
    print(f"❌ Erreur: {e}")

print("\n" + "=" * 70)
print("🔍 Test 2: Vérifier les crédits")
print("=" * 70)
print("\nAllez sur: https://platform.openai.com/account/billing/overview")
print("Vérifiez que vous avez des crédits disponibles ($5 minimum)\n")

print("=" * 70)
