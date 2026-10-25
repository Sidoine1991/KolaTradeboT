#!/usr/bin/env python3
"""
Script de configuration Firebase pour TradBOT
Configure automatiquement les variables d'environnement Firebase
"""

import os
import json

def setup_firebase_env():
    """Configure les variables d'environnement Firebase"""
    
    # Configuration Firebase
    firebase_config = {
        'FIREBASE_PROJECT_ID': 'smstrade-5f6a5',
        'FIREBASE_PRIVATE_KEY': '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC4IvQJG3Jn5ul+\nZl9J4WS71O3DcGvzLoBBZRIIQSqCtVJSayYXa9PKrtmC8dGvBvqSON3W6khp0rkB\nzdgiKgE1m9wwYYfMUgYtIW5qFCxWzUWYwcQe+PMyAwajfEf4fxmg9NvaFs1jePL1\nzHFm60EOp/tTH8CjJdeVAd3GCu/uzWOvuWInhjfRBDwj4CD+ejFxYc38ag9ekw7I\nlkv3pWfcc/lLYMQiq6wbNTHeIGjzWEHUIjyrxiEHZCvdjETZEYlBxan+w67q+VmZ\nOqPaJjLs6umcgav0ipoglYR8RrHAaNakE1aMqs6vsqZ2QPNy2nTl3HKJMyaDkV4+\nADHEQfoVAgMBAAECggEAQrbDRQNxPWzfnyC3GHz1ssoQRPWX3vkzlb3pPR1jKg1I\n4LyahfTWvMIB45v6lRgJs+2vjly+1Lx4tEsgqiwe2Q35xnunqGL1gudwajWZ5O8l\nbpWRmYkoD7Ah+RyftMxT/EmK2CbXzlj1ahHi6l+E6Cr7d1/zOwkMZRvSfpza1mFt\naQJnInBB4auFQOYxrTyliB+V+3amyJL8JH6kLmZb5pBOS7U++ItlOec0Glw9VR3s\nDeVOhwx4IU5mowB30m+sYnQslx0sk/eMbxThj45R1TcCrtX4Bi6O32El9JQKlitm\nRGpRuWC+/PcdA7Br6Trwsm1bMihdAbx0fQxXdwhqFwKBgQDi0Mgbh5L7sevft1IW\noI9iPr3cfCnv/rqJCM9zLPhl9v/OEBGvYR7EXcWmYW+gWXRSKs7HEIGVJtekTup0\nhR+4n/sIopGqjcx8i11DdFPfdbKhe/ocGesYdW6mKvY7YY3TEcBSBhXD8FKDEAKq\neyKvL2PgqjOpOTej7vtgob9JfwKBgQDP1FdIcBOIWNjWbB5nOQkqwZ4Ej+HTTE/z\nmfq1hnCKtVFba1AWU7dEm64F9UyDm1k4Y757c50Xq/kPwTpwE9146a0ZdlqMPbEr\nRwvPife5AUXFOzC+8LlhozdqEdVMfNxFSrfor5b5Kof9+qftCbw50G6fYq6Sqd/f\nm2bbnD6+awKBgQCmZwg4ckmakNj9I5B8+0TWjjNa3FkkMt0Fhko0NKz0mbbopg9j\nfLxG0okcXOW5XYeidLeJggmftISGjkMiQzyXhf91QVffKfL4+IHu6BxUmBP6t2sy\nTK2XHyiTjndh71tOm/pd8wrq2piegRODoZ07q2f6PsRyBYFVqxIPvfsJ3wKBgAww\npD33dO3WaEGLbe0YB1WeraoO1mwSWc4sBeyHyioYoIEANl5Y4rL/fqGS1b4SapVI\nJHARQ/GTgLRP3SGdyKvC6QhJTN5U8ANd02+E5CbR0EnVQvKwI+96J1HtYdluqWzX\nCRp40h4jRH69KQRaQdQSSarHmv23QQ5Yixvuei+pAoGAczohKiym14mBY4BrJwhq\ntJzDF5vXZV3ZP8WhusN3R7AJ76RC9L+uBYgRoExAupz1RpJXSeufL33Dn1tmsq4h\nhJoHHCojYEmzSmWvUURf8QdSJbQmPiHTdtYu7cxh/DnpK5KtX+onrZNTolJkRa+t\nMpiy4LszXQ0up1R/xb9lSKU=\n-----END PRIVATE KEY-----\n',
        'FIREBASE_CLIENT_EMAIL': 'firebase-adminsdk-fbsvc@smstrade-5f6a5.iam.gserviceaccount.com',
        'FIREBASE_TOKEN_URI': 'https://oauth2.googleapis.com/token',
        'GOOGLE_API_KEY': 'AIzaSyClCAXRU8kk4l1TxtaMfDqbRUEixNQ68Ao'
    }
    
    # Vérifier si .env existe
    env_file = '.env'
    if os.path.exists(env_file):
        print("📁 Fichier .env trouvé, sauvegarde...")
        # Sauvegarder l'ancien fichier
        with open('.env.backup', 'w') as f:
            with open(env_file, 'r') as old_f:
                f.write(old_f.read())
        print("✅ Sauvegarde créée: .env.backup")
    
    # Lire le contenu existant du .env
    existing_content = ""
    if os.path.exists(env_file):
        with open(env_file, 'r') as f:
            existing_content = f.read()
    
    # Préparer le nouveau contenu
    new_content = existing_content
    
    # Ajouter ou mettre à jour les variables Firebase
    for key, value in firebase_config.items():
        if f"{key}=" in new_content:
            # Remplacer la variable existante
            import re
            pattern = f"{key}=.*"
            new_content = re.sub(pattern, f"{key}={value}", new_content)
            print(f"🔄 Variable mise à jour: {key}")
        else:
            # Ajouter la nouvelle variable
            if not new_content.endswith('\n') and new_content:
                new_content += '\n'
            new_content += f"{key}={value}\n"
            print(f"➕ Variable ajoutée: {key}")
    
    # Écrire le nouveau fichier .env
    with open(env_file, 'w') as f:
        f.write(new_content)
    
    print(f"\n✅ Configuration Firebase terminée!")
    print(f"📁 Fichier: {env_file}")
    print(f"🔥 Projet Firebase: {firebase_config['FIREBASE_PROJECT_ID']}")
    print(f"📧 Email: {firebase_config['FIREBASE_CLIENT_EMAIL']}")
    print(f"🔑 API Key: {firebase_config['GOOGLE_API_KEY'][:20]}...")
    
    print(f"\n📋 Variables configurées:")
    for key in firebase_config.keys():
        print(f"  ✅ {key}")
    
    print(f"\n⚠️  IMPORTANT: Configurez votre numéro de téléphone dans .env:")
    print(f"   PHONE_NUMBER=+1234567890")
    
    return True

if __name__ == "__main__":
    print("🔥 Configuration Firebase pour TradBOT")
    print("=" * 50)
    
    try:
        setup_firebase_env()
        print("\n🎉 Configuration terminée avec succès!")
        print("💡 Vous pouvez maintenant utiliser Firebase SMS avec 10,000 SMS gratuits/mois")
    except Exception as e:
        print(f"❌ Erreur lors de la configuration: {e}")
        print("💡 Vérifiez les permissions d'écriture dans le répertoire")
