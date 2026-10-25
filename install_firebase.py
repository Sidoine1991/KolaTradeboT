#!/usr/bin/env python3
"""
Script d'installation et de configuration Firebase pour TradBOT
"""

import os
import sys
import subprocess
import json
from pathlib import Path

def install_firebase_dependencies():
    """Installe les dépendances Firebase"""
    print("📦 Installation des dépendances Firebase...")
    
    dependencies = [
        'firebase-admin>=6.2.0',
        'google-cloud-firestore>=2.11.0'
    ]
    
    for dep in dependencies:
        try:
            print(f"   Installation de {dep}...")
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', dep])
            print(f"   ✅ {dep} installé")
        except subprocess.CalledProcessError as e:
            print(f"   ❌ Erreur lors de l'installation de {dep}: {e}")
            return False
    
    return True

def create_env_file():
    """Crée le fichier .env avec la configuration Firebase"""
    print("\n📝 Création du fichier .env...")
    
    env_content = """# Configuration Firebase pour TradBOT
FIREBASE_PROJECT_ID=smstrade-5f6a5
FIREBASE_PRIVATE_KEY_ID=7da798f4748423a37852118ac2812d045244ef22
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC4IvQJG3Jn5ul+\nZl9J4WS71O3DcGvzLoBBZRIIQSqCtVJSayYXa9PKrtmC8dGvBvqSON3W6khp0rkB\nzdgiKgE1m9wwYYfMUgYtIW5qFCxWzUWYwcQe+PMyAwajfEf4fxmg9NvaFs1jePL1\nzHFm60EOp/tTH8CjJdeVAd3GCu/uzWOvuWInhjfRBDwj4CD+ejFxYc38ag9ekw7I\nlkv3pWfcc/lLYMQiq6wbNTHeIGjzWEHUIjyrxiEHZCvdjETZEYlBxan+w67q+VmZ\nOqPaJjLs6umcgav0ipoglYR8RrHAaNakE1aMqs6vsqZ2QPNy2nTl3HKJMyaDkV4+\nADHEQfoVAgMBAAECggEAQrbDRQNxPWzfnyC3GHz1ssoQRPWX3vkzlb3pPR1jKg1I\n4LyahfTWvMIB45v6lRgJs+2vjly+1Lx4tEsgqiwe2Q35xnunqGL1gudwajWZ5O8l\nbpWRmYkoD7Ah+RyftMxT/EmK2CbXzlj1ahHi6l+E6Cr7d1/zOwkMZRvSfpza1mFt\naQJnInBB4auFQOYxrTyliB+V+3amyJL8JH6kLmZb5pBOS7U++ItlOec0Glw9VR3s\nDeVOhwx4IU5mowB30m+sYnQslx0sk/eMbxThj45R1TcCrtX4Bi6O32El9JQKlitm\nRGpRuWC+/PcdA7Br6Trwsm1bMihdAbx0fQxXdwhqFwKBgQDi0Mgbh5L7sevft1IW\noI9iPr3cfCnv/rqJCM9zLPhl9v/OEBGvYR7EXcWmYW+gWXRSKs7HEIGVJtekTup0\nhR+4n/sIopGqjcx8i11DdFPfdbKhe/ocGesYdW6mKvY7YY3TEcBSBhXD8FKDEAKq\neyKvL2PgqjOpOTej7vtgob9JfwKBgQDP1FdIcBOIWNjWbB5nOQkqwZ4Ej+HTTE/z\nmfq1hnCKtVFba1AWU7dEm64F9UyDm1k4Y757c50Xq/kPwTpwE9146a0ZdlqMPbEr\nRwvPife5AUXFOzC+8LlhozdqEdVMfNxFSrfor5b5Kof9+qftCbw50G6fYq6Sqd/f\nm2bbnD6+awKBgQCmZwg4ckmakNj9I5B8+0TWjjNa3FkkMt0Fhko0NKz0mbbopg9j\nfLxG0okcXOW5XYeidLeJggmftISGjkMiQzyXhf91QVffKfL4+IHu6BxUmBP6t2sy\nTK2XHyiTjndh71tOm/pd8wrq2piegRODoZ07q2f6PsRyBYFVqxIPvfsJ3wKBgAww\npD33dO3WaEGLbe0YB1WeraoO1mwSWc4sBeyHyioYoIEANl5Y4rL/fqGS1b4SapVI\nJHARQ/GTgLRP3SGdyKvC6QhJTN5U8ANd02+E5CbR0EnVQvKwI+96J1HtYdluqWzX\nCRp40h4jRH69KQRaQdQSSarHmv23QQ5Yixvuei+pAoGAczohKiym14mBY4BrJwhq\ntJzDF5vXZV3ZP8WhusN3R7AJ76RC9L+uBYgRoExAupz1RpJXSeufL33Dn1tmsq4h\nhJoHHCojYEmzSmWvUURf8QdSJbQmPiHTdtYu7cxh/DnpK5KtX+onrZNTolJkRa+t\nMpiy4LszXQ0up1R/xb9lSKU=\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@smstrade-5f6a5.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=110284900614212803727
FIREBASE_AUTH_URI=https://accounts.google.com/o/oauth2/auth
FIREBASE_TOKEN_URI=https://oauth2.googleapis.com/token
FIREBASE_AUTH_PROVIDER_X509_CERT_URL=https://www.googleapis.com/oauth2/v1/certs
FIREBASE_CLIENT_X509_CERT_URL=https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40smstrade-5f6a5.iam.gserviceaccount.com
FIREBASE_UNIVERSE_DOMAIN=googleapis.com

# Clé API Google
GOOGLE_API_KEY=AIzaSyClCAXRU8kk4l1TxtaMfDqbRUEixNQ68Ao

# Configuration MT5 (à remplir selon vos paramètres)
MT5_LOGIN=
MT5_PASSWORD=
MT5_SERVER=

# Configuration des notifications
PHONE_NUMBER=+1234567890
EMAIL_SENDER=
EMAIL_PASSWORD=
EMAIL_RECEIVER=
TELEGRAM_TOKEN=
TELEGRAM_CHAT_ID=

# Configuration de l'application
DEBUG=True
LOG_LEVEL=INFO
"""
    
    try:
        with open('.env', 'w') as f:
            f.write(env_content)
        print("   ✅ Fichier .env créé")
        return True
    except Exception as e:
        print(f"   ❌ Erreur lors de la création du .env: {e}")
        return False

def test_firebase_installation():
    """Test l'installation Firebase"""
    print("\n🧪 Test de l'installation Firebase...")
    
    try:
        # Test d'importation
        import firebase_admin
        from firebase_admin import credentials, firestore
        print("   ✅ Importations Firebase réussies")
        
        # Test de configuration
        with open('firebase_config.json', 'r') as f:
            config = json.load(f)
        
        if config.get('project_id') == 'smstrade-5f6a5':
            print("   ✅ Configuration Firebase valide")
        else:
            print("   ❌ Configuration Firebase invalide")
            return False
        
        print("   ✅ Installation Firebase testée avec succès")
        return True
        
    except ImportError as e:
        print(f"   ❌ Erreur d'importation: {e}")
        return False
    except Exception as e:
        print(f"   ❌ Erreur lors du test: {e}")
        return False

def main():
    """Fonction principale d'installation"""
    print("🔥 Installation Firebase pour TradBOT")
    print("=" * 50)
    
    # Étape 1: Installation des dépendances
    if not install_firebase_dependencies():
        print("❌ Échec de l'installation des dépendances")
        return False
    
    # Étape 2: Création du fichier .env
    if not create_env_file():
        print("❌ Échec de la création du fichier .env")
        return False
    
    # Étape 3: Test de l'installation
    if not test_firebase_installation():
        print("❌ Échec du test d'installation")
        return False
    
    # Résumé
    print("\n" + "=" * 50)
    print("🎉 INSTALLATION TERMINÉE AVEC SUCCÈS!")
    print("=" * 50)
    
    print("\n📁 Fichiers créés:")
    print("   • .env - Variables d'environnement")
    print("   • firebase_config.json - Configuration Firebase")
    print("   • src/firebase_service.py - Service Firebase")
    
    print("\n🔧 Prochaines étapes:")
    print("   1. Configurez votre numéro de téléphone dans .env")
    print("   2. Lancez: python test_firebase_config.py")
    print("   3. Testez: python demo_firebase_sms.py")
    print("   4. Intégrez dans vos scripts de trading")
    
    print("\n💡 Utilisation:")
    print("   from src.firebase_service import get_firebase_service")
    print("   service = get_firebase_service()")
    print("   service.send_sms_notification('+1234567890', 'Signal!')")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
