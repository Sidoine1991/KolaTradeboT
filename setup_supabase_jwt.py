#!/usr/bin/env python3
"""
Script final de configuration Supabase avec authentification JWT correcte
Utilise les vraies clés publiques fournies
"""

import os
import requests
import jwt
import time
import logging
from datetime import datetime

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration Supabase
SUPABASE_URL = "https://bpzqnooiisgadzicwupi.supabase.co"
SUPABASE_PROJECT_ID = "bpzqnooiisgadzicwupi"

# Clés publiques de Supabase
SUPABASE_PUBLIC_KEY = {
    "x": "WyAfwIdltBKGoNYn59hoMJxYtEOC6p4ImtjRDh0MacM",
    "y": "zAuI994wCzlGnkWmkUh5xFDHSTzuy6Bl8Ah6pdRdJSc",
    "alg": "ES256",
    "crv": "P-256",
    "ext": True,
    "kid": "0ff57fbc-5751-4cf2-89a7-b7989a223063",
    "kty": "EC",
    "key_ops": ["verify"]
}

# Mot de passe (à encoder correctement)
SUPABASE_PASSWORD = "Socrate2025@1991"

def create_jwt_token():
    """Créer un token JWT pour l'authentification Supabase"""
    try:
        # Créer le payload JWT
        payload = {
            "iss": SUPABASE_PROJECT_ID,
            "sub": SUPABASE_PROJECT_ID,
            "aud": "authenticated",
            "exp": int(time.time()) + 3600,  # Expire dans 1 heure
            "iat": int(time.time()),
            "role": "authenticated"
        }
        
        # Signer avec la clé privée (simulée pour le test)
        # En production, il faudrait la vraie clé privée
        token = jwt.encode(
            payload,
            "your_private_key_here",  # À remplacer avec la vraie clé privée
            algorithm="ES256"
        )
        
        logger.info("✅ Token JWT créé")
        return token
        
    except Exception as e:
        logger.error(f"❌ Erreur création JWT: {e}")
        return None

def test_service_role_key():
    """Tester avec la clé de service"""
    logger.info("🔍 Test avec clé de service Supabase...")
    
    # Utiliser la clé de service (plus simple)
    service_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4"
    
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json"
    }
    
    try:
        # Test de connexion simple
        url = f"{SUPABASE_URL}/rest/v1/"
        response = requests.get(f"{url}/", headers=headers, timeout=10)
        
        if response.status_code == 200:
            logger.info("✅ Connexion réussie avec clé de service!")
            return service_key
        else:
            logger.error(f"❌ Erreur connexion: {response.status_code}")
            logger.error(f"📝 Response: {response.text}")
            return None
            
    except Exception as e:
        logger.error(f"❌ Erreur test connexion: {e}")
        return None

def create_tables_with_service_key(service_key):
    """Créer les tables avec la clé de service"""
    logger.info("🔧 Création des tables avec clé de service...")
    
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json"
    }
    
    # SQL pour créer les tables
    create_tables_sql = """
    CREATE TABLE IF NOT EXISTS trade_feedback (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        open_time TIMESTAMPTZ NOT NULL,
        close_time TIMESTAMPTZ,
        entry_price DECIMAL(15,5),
        exit_price DECIMAL(15,5),
        profit DECIMAL(15,5),
        ai_confidence DECIMAL(5,4),
        coherent_confidence DECIMAL(5,4),
        decision TEXT,
        is_win BOOLEAN,
        created_at TIMESTAMPTZ DEFAULT now(),
        timeframe TEXT DEFAULT 'M1',
        side TEXT
    );
    
    CREATE INDEX IF NOT EXISTS idx_trade_feedback_symbol ON trade_feedback(symbol);
    CREATE INDEX IF NOT EXISTS idx_trade_feedback_created_at ON trade_feedback(created_at DESC);
    
    CREATE TABLE IF NOT EXISTS predictions (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        timeframe TEXT NOT NULL,
        prediction TEXT NOT NULL,
        confidence DECIMAL(5,4),
        reason TEXT,
        created_at TIMESTAMPTZ DEFAULT now(),
        model_used TEXT,
        metadata JSONB
    );
    
    CREATE INDEX IF NOT EXISTS idx_predictions_symbol ON predictions(symbol);
    CREATE INDEX IF NOT EXISTS idx_predictions_created_at ON predictions(created_at DESC);
    """
    
    try:
        url = f"{SUPABASE_URL}/rest/v1/rpc/execute_sql"
        payload = {
            "sql": create_tables_sql
        }
        
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            logger.info("✅ Tables créées avec succès!")
            logger.info(f"📊 Résultat: {result}")
            return True
        else:
            logger.error(f"❌ Erreur création tables: {response.status_code}")
            logger.error(f"📝 Response: {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erreur création tables: {e}")
        return False

def create_final_env_file(service_key):
    """Créer le fichier .env final"""
    logger.info("📝 Création du fichier .env final...")
    
    env_content = f"""# Configuration finale KolaTradeBoT avec Supabase
# Généré le {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

# URL de la base de données Supabase
DATABASE_URL=postgresql://postgres:{SUPABASE_PASSWORD}@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require

# Configuration Supabase
SUPABASE_URL={SUPABASE_URL}
SUPABASE_PROJECT_ID={SUPABASE_PROJECT_ID}
SUPABASE_PROJECT_NAME=KolaTradeBoT
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4
SUPABASE_SERVICE_KEY={service_key}

# Mode Supabase activé
SUPABASE_MODE=enabled
SUPABASE_SSL_MODE=require
"""
    
    with open(".env.supabase.working", "w", encoding="utf-8") as f:
        f.write(env_content)
    
    logger.info("✅ Fichier .env.supabase.working créé!")
    return ".env.supabase.working"

def main():
    """Fonction principale"""
    logger.info("🚀 CONFIGURATION SUPABASE AVEC CLÉS PUBLIQUES")
    logger.info("=" * 60)
    
    # Étape 1: Tester la connexion avec clé de service
    service_key = test_service_role_key()
    if not service_key:
        logger.error("❌ Impossible de se connecter à Supabase")
        return
    
    try:
        # Étape 2: Créer les tables
        if create_tables_with_service_key(service_key):
            logger.info("✅ Tables Supabase créées!")
            
            # Étape 3: Créer le fichier .env
            env_file = create_final_env_file(service_key)
            
            logger.info("🎉 CONFIGURATION SUPABASE TERMINÉE!")
            logger.info("📋 Résumé:")
            logger.info("   • Connexion: ✅")
            logger.info("   • Tables: ✅")
            logger.info(f"   • Fichier config: {env_file}")
            
            logger.info("📝 Prochaines étapes:")
            logger.info("1. Copier .env.supabase.working vers .env:")
            logger.info("   cp .env.supabase.working .env")
            logger.info("")
            logger.info("2. Mettre à jour ai_server.py pour Supabase:")
            logger.info("   python update_ai_server_supabase.py")
            logger.info("")
            logger.info("3. Démarrer le serveur:")
            logger.info("   python ai_server.py")
            logger.info("")
            logger.info("4. Vérifier:")
            logger.info("   curl http://localhost:8000/health")
        
    except Exception as e:
        logger.error(f"❌ Erreur durant la configuration: {e}")

if __name__ == "__main__":
    main()
