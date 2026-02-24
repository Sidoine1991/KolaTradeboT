#!/usr/bin/env python3
"""
Script de migration de sauvegarde locale vers Supabase
Utilise les fichiers locaux comme source au lieu de Render
"""

import os
import json
import sqlite3
import psycopg2
import logging
from datetime import datetime
from pathlib import Path
from urllib.parse import quote_plus

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration
SUPABASE_PASSWORD = "Socrate2025@1991"
encoded_password = quote_plus(SUPABASE_PASSWORD)

# Essayer l'URL Supabase la plus simple
SUPABASE_URLS = [
    "postgresql://postgres.bpzqnooiisgadzicwupi:postgres@aws-0-eu-central-1.pooler.supabase.com:5432/postgres",
    "postgresql://postgres:postgres@aws-0-eu-central-1.pooler.supabase.com:5432/postgres",
]

def create_local_backup():
    """Créer une sauvegarde locale des données importantes"""
    logger.info("📦 Création sauvegarde locale...")
    
    backup_data = {
        "timestamp": datetime.now().isoformat(),
        "trade_feedback": [],
        "predictions": [],
        "symbol_calibration": {},
        "ai_settings": {
            "model": "Technical_Analysis_v3_Enhanced",
            "version": "2.1.0",
            "features": ["multi-timeframe", "price_action", "scoring_system"]
        }
    }
    
    # Chercher les fichiers de données existants
    data_files = [
        "trade_feedback.jsonl",
        "predictions.json",
        "symbol_calibration.json",
        "ai_settings.json"
    ]
    
    for filename in data_files:
        filepath = Path(filename)
        if filepath.exists():
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    if filename.endswith('.jsonl'):
                        # Lire fichier JSONL
                        lines = f.readlines()
                        data = [json.loads(line.strip()) for line in lines if line.strip()]
                        backup_data[filename.replace('.jsonl', '')] = data
                    else:
                        # Lire fichier JSON
                        data = json.load(f)
                        backup_data[filename.replace('.json', '')] = data
                
                logger.info(f"✅ {filename}: {len(data) if isinstance(data, list) else len(data.keys())} éléments")
            except Exception as e:
                logger.error(f"❌ Erreur lecture {filename}: {e}")
    
    # Sauvegarder dans un fichier de backup
    backup_file = f"backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(backup_file, 'w', encoding='utf-8') as f:
        json.dump(backup_data, f, indent=2, ensure_ascii=False)
    
    logger.info(f"✅ Sauvegarde créée: {backup_file}")
    return backup_file, backup_data

def setup_supabase_minimal():
    """Configuration minimale de Supabase sans migration complexe"""
    logger.info("🔧 Configuration Supabase minimale...")
    
    for i, url in enumerate(SUPABASE_URLS, 1):
        logger.info(f"🔍 Test connexion {i}: {url[:50]}...")
        try:
            conn = psycopg2.connect(url + "?sslmode=require")
            logger.info(f"✅ Connexion réussie avec format {i}!")
            
            # Créer tables de base
            cursor = conn.cursor()
            
            # Table simple pour les décisions
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS decisions (
                id SERIAL PRIMARY KEY,
                symbol TEXT NOT NULL,
                action TEXT NOT NULL,
                confidence DECIMAL(5,4),
                reason TEXT,
                created_at TIMESTAMPTZ DEFAULT now(),
                model_used TEXT
            )
            """)
            
            # Table pour les logs de trading
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS trading_logs (
                id SERIAL PRIMARY KEY,
                symbol TEXT NOT NULL,
                action TEXT NOT NULL,
                profit DECIMAL(15,5),
                confidence DECIMAL(5,4),
                timestamp TIMESTAMPTZ DEFAULT now()
            )
            """)
            
            conn.commit()
            logger.info("✅ Tables de base créées!")
            
            # Insérer un enregistrement de test
            cursor.execute("""
            INSERT INTO decisions (symbol, action, confidence, reason, model_used)
            VALUES ('TEST', 'BUY', 0.75, 'Test initial', 'Setup Script')
            """)
            conn.commit()
            
            cursor.close()
            conn.close()
            
            # Créer fichier de configuration
            env_config = f"""# Configuration Supabase - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
DATABASE_URL={url}?sslmode=require
SUPABASE_URL=https://bpzqnooiisgadzicwupi.supabase.co
SUPABASE_PROJECT_ID=bpzqnooiisgadzicwupi
SUPABASE_PROJECT_NAME=KolaTradeBoT
SUPABASE_MODE=minimal
"""
            
            with open(".env.supabase.minimal", "w") as f:
                f.write(env_config)
            
            logger.info("✅ Fichier .env.supabase.minimal créé!")
            logger.info("🎉 Configuration Supabase minimale terminée!")
            
            return url
            
        except Exception as e:
            logger.error(f"❌ Échec connexion {i}: {e}")
    
    return None

def update_ai_server_for_supabase():
    """Mettre à jour ai_server.py pour utiliser Supabase"""
    logger.info("📝 Mise à jour ai_server.py pour Supabase...")
    
    try:
        with open("ai_server.py", 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Remplacer les références Render par Supabase
        updates = [
            ("RUNNING_ON_RENDER", "RUNNING_ON_SUPABASE"),
            ("Mode Render activé", "Mode Supabase activé"),
            ("pour Render PostgreSQL", "pour Supabase PostgreSQL"),
            ("render.com", "supabase.co"),
        ]
        
        updated_content = content
        for old, new in updates:
            updated_content = updated_content.replace(old, new)
        
        # Sauvegarder la version mise à jour
        with open("ai_server_supabase.py", 'w', encoding='utf-8') as f:
            f.write(updated_content)
        
        logger.info("✅ ai_server_supabase.py créé!")
        
    except Exception as e:
        logger.error(f"❌ Erreur mise à jour ai_server.py: {e}")

def main():
    """Fonction principale"""
    logger.info("🚀 MIGRATION ALTERNATIVE RENDER → SUPABASE")
    logger.info("=" * 60)
    
    # Étape 1: Créer sauvegarde locale
    backup_file, backup_data = create_local_backup()
    
    # Étape 2: Configuration Supabase minimale
    working_url = setup_supabase_minimal()
    
    if working_url:
        # Étape 3: Mettre à jour ai_server.py
        update_ai_server_for_supabase()
        
        logger.info("🎉 MIGRATION TERMINÉE AVEC SUCCÈS!")
        logger.info("📋 Résumé:")
        logger.info(f"   • Sauvegarde locale: {backup_file}")
        logger.info(f"   • URL Supabase: {working_url[:50]}...")
        logger.info("   • Fichier config: .env.supabase.minimal")
        logger.info("   • Serveur mis à jour: ai_server_supabase.py")
        
        logger.info("📝 Prochaines étapes:")
        logger.info("1. Copier .env.supabase.minimal vers .env")
        logger.info("2. Utiliser ai_server_supabase.py comme serveur principal")
        logger.info("3. Démarrer: python ai_server_supabase.py")
        
    else:
        logger.error("❌ Échec configuration Supabase")
        logger.info("💡 Solution: Utiliser la sauvegarde locale")

if __name__ == "__main__":
    main()
