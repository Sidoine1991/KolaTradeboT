#!/usr/bin/env python3
"""
Script de test pour vérifier le chargement des variables d'environnement
"""
import os
import sys

print("="*60)
print("TEST DU CHARGEMENT DES VARIABLES D'ENVIRONNEMENT")
print("="*60)

# Test 1: Vérifier si dotenv est installé
print("\n[1] Vérification de python-dotenv...")
try:
    from dotenv import load_dotenv
    print("   [OK] python-dotenv est installé")
except ImportError:
    print("   [ERREUR] python-dotenv n'est pas installé")
    print("   [INFO] Installez avec: pip install python-dotenv")
    sys.exit(1)

# Test 2: Charger le fichier .env
print("\n[2] Chargement du fichier .env...")
env_path = os.path.join(os.path.dirname(__file__), '.env')
if os.path.exists(env_path):
    print(f"   [OK] Fichier .env trouvé: {env_path}")
    load_dotenv(env_path)
    print("   [OK] Fichier .env chargé")
else:
    print(f"   [WARN] Fichier .env non trouvé: {env_path}")
    load_dotenv()  # Essaie de charger depuis le répertoire courant

# Test 3: Vérifier DATABASE_URL
print("\n[3] Vérification de DATABASE_URL...")
db_url = os.getenv("DATABASE_URL")
if db_url:
    print(f"   [OK] DATABASE_URL est défini")
    print(f"   [INFO] Valeur (premiers 50 caractères): {db_url[:50]}...")
    print(f"   [INFO] Longueur totale: {len(db_url)} caractères")
else:
    print("   [ERREUR] DATABASE_URL n'est pas défini")
    print("   [INFO] Vérifiez que le fichier .env contient DATABASE_URL=...")

# Test 4: Vérifier asyncpg
print("\n[4] Vérification de asyncpg...")
try:
    import asyncpg
    print(f"   [OK] asyncpg est installé (version: {asyncpg.__version__})")
except ImportError:
    print("   [ERREUR] asyncpg n'est pas installé")
    print("   [INFO] Installez avec: pip install asyncpg")

# Résumé
print("\n" + "="*60)
print("RÉSUMÉ")
print("="*60)
db_ok = bool(db_url)
asyncpg_ok = False
try:
    import asyncpg
    asyncpg_ok = True
except:
    pass

if db_ok and asyncpg_ok:
    print("[SUCCESS] Tout est configuré correctement!")
    print("   - DATABASE_URL: OK")
    print("   - asyncpg: OK")
    print("\n[INFO] Vous pouvez maintenant démarrer le serveur avec:")
    print("   python ai_server.py")
else:
    print("[WARN] Configuration incomplète:")
    if not db_ok:
        print("   - DATABASE_URL: MANQUANT")
    if not asyncpg_ok:
        print("   - asyncpg: NON INSTALLÉ")
print("="*60)
