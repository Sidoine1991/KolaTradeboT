#!/usr/bin/env python3
"""
Script pour mettre à jour ai_server.py pour utiliser Supabase
Remplace les références Render par Supabase et ajoute le support de l'API REST
"""

import os
import re
from datetime import datetime

def update_ai_server_for_supabase():
    """Mettre à jour ai_server.py pour utiliser Supabase"""
    
    try:
        # Lire le fichier actuel
        with open("ai_server.py", "r", encoding="utf-8") as f:
            content = f.read()
        
        logger.info("📝 Mise à jour de ai_server.py pour Supabase...")
        
        # Remplacements à effectuer
        replacements = [
            # Remplacer les variables d'environnement Render par Supabase
            ('RUNNING_ON_RENDER = bool(os.getenv("RENDER") or os.getenv("RENDER_SERVICE_ID"))',
             'RUNNING_ON_SUPABASE = bool(os.getenv("SUPABASE_URL") or os.getenv("SUPABASE_PROJECT_ID"))'),
            
            # Remplacer les logs et messages
            ('Mode Render activé', 'Mode Supabase activé'),
            ('pour Render PostgreSQL', 'pour Supabase PostgreSQL'),
            ('📝 Ajout de sslmode=require pour Render PostgreSQL', 
             '📝 Ajout de sslmode=require pour Supabase PostgreSQL'),
        ]
        
        # Appliquer les remplacements
        updated_content = content
        for old, new in replacements:
            updated_content = updated_content.replace(old, new)
        
        # Sauvegarder la version mise à jour
        with open("ai_server_supabase.py", "w", encoding="utf-8") as f:
            f.write(updated_content)
        
        logger.info("✅ ai_server.py mis à jour pour Supabase!")
        logger.info("📝 Fichier créé: ai_server_supabase.py")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Erreur mise à jour ai_server.py: {e}")
        return False

def create_env_file():
    """Créer le fichier .env pour Supabase"""
    
    env_content = f"""# Configuration KolaTradeBoT avec Supabase
# Généré le {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

# Priorité à Supabase
SUPABASE_URL=https://bpzqnooiisgadzicwupi.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4
SUPABASE_PROJECT_ID=bpzqnooiisgadzicwupi
SUPABASE_PROJECT_NAME=KolaTradeBoT
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4

# Mode Supabase activé
SUPABASE_MODE=enabled
SUPABASE_USE_API=true

# URL de la base de données Supabase
DATABASE_URL=postgresql://postgres:Socrate2025@1991@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require
"""
    
    with open(".env.supabase", "w", encoding="utf-8") as f:
        f.write(env_content)
    
    logger.info("✅ Fichier .env.supabase créé!")
    return ".env.supabase"

def main():
    """Fonction principale"""
    logger.info("🚀 MISE À JOUR AI SERVER POUR SUPABASE")
    logger.info("=" * 60)
    
    # Étape 1: Mettre à jour ai_server.py
    if update_ai_server_for_supabase():
        logger.info("✅ ai_server.py mis à jour avec succès!")
        
        # Étape 2: Créer le fichier .env
        env_file = create_env_file()
        
        logger.info("🎉 MISE À JOUR TERMINÉE!")
        logger.info("📋 Résumé:")
        logger.info("   • Serveur mis à jour: ai_server_supabase.py")
        logger.info(f"   • Fichier config: {env_file}")
        
        logger.info("📝 Prochaines étapes:")
        logger.info("1. Copier .env.supabase vers .env:")
        logger.info("   cp .env.supabase .env")
        logger.info("")
        logger.info("2. Démarrer le serveur avec Supabase:")
        logger.info("   python ai_server_supabase.py")
        logger.info("")
        logger.info("3. Vérifier le démarrage:")
        logger.info("   curl http://localhost:8000/health")
        
    else:
        logger.error("❌ Échec mise à jour ai_server.py")

if __name__ == "__main__":
    import logging
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    logger = logging.getLogger(__name__)
    
    main()
