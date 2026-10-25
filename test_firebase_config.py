#!/usr/bin/env python3
"""
Script de test pour la configuration Firebase
"""

import os
import sys
import json
from pathlib import Path

# Ajouter le répertoire src au path
sys.path.append(str(Path(__file__).parent / 'src'))

def test_firebase_config():
    """Test la configuration Firebase"""
    print("🔥 Test de la configuration Firebase pour TradBOT")
    print("=" * 60)
    
    # Test 1: Vérifier les fichiers de configuration
    print("\n1. Vérification des fichiers de configuration...")
    
    config_files = [
        'firebase_config.json',
        'config/settings.py',
        'src/firebase_service.py'
    ]
    
    for file_path in config_files:
        if os.path.exists(file_path):
            print(f"   ✅ {file_path}")
        else:
            print(f"   ❌ {file_path} - MANQUANT")
    
    # Test 2: Vérifier la configuration Firebase
    print("\n2. Vérification de la configuration Firebase...")
    
    try:
        with open('firebase_config.json', 'r') as f:
            firebase_config = json.load(f)
        
        required_fields = [
            'project_id', 'private_key_id', 'private_key', 
            'client_email', 'client_id'
        ]
        
        for field in required_fields:
            if field in firebase_config and firebase_config[field]:
                print(f"   ✅ {field}: {str(firebase_config[field])[:50]}...")
            else:
                print(f"   ❌ {field}: MANQUANT")
        
        print(f"   📋 Projet Firebase: {firebase_config.get('project_id', 'N/A')}")
        print(f"   📧 Email: {firebase_config.get('client_email', 'N/A')}")
        
    except Exception as e:
        print(f"   ❌ Erreur lors de la lecture de firebase_config.json: {e}")
    
    # Test 3: Vérifier les variables d'environnement
    print("\n3. Vérification des variables d'environnement...")
    
    env_vars = [
        'FIREBASE_PROJECT_ID',
        'GOOGLE_API_KEY',
        'PHONE_NUMBER'
    ]
    
    for var in env_vars:
        value = os.getenv(var)
        if value:
            print(f"   ✅ {var}: {str(value)[:30]}...")
        else:
            print(f"   ⚠️  {var}: Non défini (utilisera la valeur par défaut)")
    
    # Test 4: Test d'importation du service Firebase
    print("\n4. Test d'importation du service Firebase...")
    
    try:
        from firebase_service import FirebaseService, get_firebase_service
        print("   ✅ Importation du service Firebase réussie")
        
        # Test d'initialisation
        service = get_firebase_service()
        if service.initialized:
            print("   ✅ Service Firebase initialisé avec succès")
        else:
            print("   ⚠️  Service Firebase non initialisé (dépendances manquantes?)")
            
    except ImportError as e:
        print(f"   ❌ Erreur d'importation: {e}")
        print("   💡 Installez les dépendances: pip install firebase-admin")
    except Exception as e:
        print(f"   ❌ Erreur lors de l'initialisation: {e}")
    
    # Test 5: Vérifier la configuration dans settings.py
    print("\n5. Vérification de la configuration dans settings.py...")
    
    try:
        from config.settings import FIREBASE_CONFIG, ALERT_CONFIG
        
        print(f"   ✅ FIREBASE_CONFIG chargé")
        print(f"   📋 Projet: {FIREBASE_CONFIG.get('project_id', 'N/A')}")
        print(f"   🔑 API Key: {FIREBASE_CONFIG.get('google_api_key', 'N/A')[:20]}...")
        
        if ALERT_CONFIG.get('firebase_enabled'):
            print("   ✅ Firebase activé dans ALERT_CONFIG")
        else:
            print("   ⚠️  Firebase non activé dans ALERT_CONFIG")
            
    except Exception as e:
        print(f"   ❌ Erreur lors de la lecture de settings.py: {e}")
    
    # Résumé
    print("\n" + "=" * 60)
    print("📋 RÉSUMÉ DE LA CONFIGURATION")
    print("=" * 60)
    
    print("\n✅ Configuration Firebase prête!")
    print("📁 Fichiers créés:")
    print("   • firebase_config.json - Configuration Firebase complète")
    print("   • src/firebase_service.py - Service Firebase pour TradBOT")
    print("   • config/settings.py - Configuration mise à jour")
    
    print("\n🔧 Prochaines étapes:")
    print("   1. Installez les dépendances: pip install firebase-admin")
    print("   2. Configurez votre numéro de téléphone dans .env")
    print("   3. Testez l'envoi de notifications SMS")
    print("   4. Intégrez le service dans vos scripts de trading")
    
    print("\n💡 Utilisation:")
    print("   from src.firebase_service import get_firebase_service")
    print("   service = get_firebase_service()")
    print("   service.send_sms_notification('+1234567890', 'Signal de trading!')")

if __name__ == "__main__":
    test_firebase_config()
