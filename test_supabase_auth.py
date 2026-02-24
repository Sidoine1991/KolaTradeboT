#!/usr/bin/env python3
"""
Script de test final pour connexion Supabase avec différents formats d'authentification
"""

import psycopg2
import logging

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Différents formats d'authentification à tester
auth_formats = [
    # Format 1: postgres (sans préfixe projet)
    {
        "user": "postgres",
        "password": "Socrate2025@1991",
        "host": "aws-0-eu-central-1.pooler.supabase.com",
        "port": "5432",
        "database": "postgres"
    },
    # Format 2: postgres.bpzqnooiisgadzicwupi (avec préfixe)
    {
        "user": "postgres.bpzqnooiisgadzicwupi",
        "password": "Socrate2025@1991",
        "host": "aws-0-eu-central-1.pooler.supabase.com",
        "port": "5432",
        "database": "postgres"
    },
    # Format 3: authentification par token
    {
        "user": "postgres",
        "password": "Socrate2025@1991",
        "host": "db.bpzqnooiisgadzicwupi.supabase.co",
        "port": "5432",
        "database": "postgres"
    }
]

def test_auth_format(auth_config, format_num):
    """Tester un format d'authentification"""
    logger.info(f"🔍 Test format {format_num}: {auth_config['user']}@{auth_config['host']}")
    
    try:
        conn = psycopg2.connect(
            host=auth_config["host"],
            port=auth_config["port"],
            database=auth_config["database"],
            user=auth_config["user"],
            password=auth_config["password"],
            sslmode="require"
        )
        
        logger.info(f"✅ Connexion réussie avec format {format_num}!")
        
        # Test simple query
        cursor = conn.cursor()
        cursor.execute("SELECT version()")
        version = cursor.fetchone()[0]
        logger.info(f"📊 PostgreSQL: {version[:50]}...")
        
        # Créer une table de test
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS test_connection (
            id SERIAL PRIMARY KEY,
            created_at TIMESTAMPTZ DEFAULT now()
        )
        """)
        conn.commit()
        
        cursor.execute("SELECT COUNT(*) FROM test_connection")
        count = cursor.fetchone()[0]
        logger.info(f"📋 Table test_connection: {count} enregistrements")
        
        cursor.close()
        conn.close()
        return True, auth_config
        
    except Exception as e:
        logger.error(f"❌ Échec format {format_num}: {e}")
        return False, None

def main():
    """Fonction principale"""
    logger.info("🚀 TEST FINAL CONNEXION SUPABASE")
    logger.info("=" * 50)
    
    for i, auth_config in enumerate(auth_formats, 1):
        success, working_config = test_auth_format(auth_config, i)
        if success:
            logger.info("🎉 CONNEXION RÉUSSIE!")
            logger.info(f"📝 Configuration fonctionnelle:")
            logger.info(f"   User: {working_config['user']}")
            logger.info(f"   Host: {working_config['host']}")
            logger.info(f"   Port: {working_config['port']}")
            logger.info(f"   Database: {working_config['database']}")
            
            # Créer le fichier .env final
            env_content = f"""# Configuration Supabase fonctionnelle
DATABASE_URL=postgresql://{working_config['user']}:{working_config['password']}@{working_config['host']}:{working_config['port']}/{working_config['database']}?sslmode=require
SUPABASE_URL=https://bpzqnooiisgadzicwupi.supabase.co
SUPABASE_PROJECT_ID=bpzqnooiisgadzicwupi
SUPABASE_PROJECT_NAME=KolaTradeBoT
"""
            
            with open(".env.supabase.working", "w") as f:
                f.write(env_content)
            
            logger.info("✅ Fichier .env.supabase.working créé!")
            logger.info("📋 Prochaines étapes:")
            logger.info("1. Copier .env.supabase.working vers .env")
            logger.info("2. Relancer la migration")
            logger.info("3. Démarrer le serveur")
            return
    
    logger.error("❌ Tous les formats d'authentification ont échoué")
    logger.info("💡 Vérifiez dans le dashboard Supabase:")
    logger.info("1. Paramètres de connexion de la base de données")
    logger.info("2. Utilisateurs autorisés")
    logger.info("3. Mot de passe correct")

if __name__ == "__main__":
    main()
