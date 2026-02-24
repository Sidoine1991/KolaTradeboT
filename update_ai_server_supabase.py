#!/usr/bin/env python3
"""
Script pour mettre à jour ai_server.py afin d'utiliser Supabase au lieu de Render
"""

import re
import os
from pathlib import Path

def update_ai_server_for_supabase():
    """Met à jour le fichier ai_server.py pour Supabase"""
    
    file_path = Path("ai_server.py")
    if not file_path.exists():
        print("❌ Fichier ai_server.py non trouvé")
        return
    
    # Lire le fichier actuel
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Modifications à apporter
    updates = [
        # Remplacer la détection Render par Supabase
        (r'RUNNING_ON_RENDER = bool\(os\.getenv\("RENDER"\) or os\.getenv\("RENDER_SERVICE_ID"\)\)',
         'RUNNING_ON_SUPABASE = bool(os.getenv("SUPABASE_URL") or os.getenv("SUPABASE_PROJECT_ID"))'),
        
        # Mettre à jour les références à RUNNING_ON_RENDER
        (r'RUNNING_ON_RENDER', 'RUNNING_ON_SUPABASE'),
        
        # Mettre à jour les logs pour indiquer Supabase au lieu de Render
        (r'Mode Render activé', 'Mode Supabase activé'),
        (r'pour Render PostgreSQL', 'pour Supabase PostgreSQL'),
        (r'sur Render', 'sur Supabase'),
        
        # Mettre à jour la configuration SSL pour Supabase
        (r'if "render\.com" in DATABASE_URL\.lower\(\) and "sslmode" not in DATABASE_URL\.lower\(\):',
         'if ("supabase.co" in DATABASE_URL.lower() or "pooler.supabase.com" in DATABASE_URL.lower()) and "sslmode" not in DATABASE_URL.lower():'),
        
        # Mettre à jour le message SSL
        (r'📝 Ajout de sslmode=require pour Render PostgreSQL',
         '📝 Ajout de sslmode=require pour Supabase PostgreSQL'),
    ]
    
    # Appliquer les modifications
    updated_content = content
    for pattern, replacement in updates:
        updated_content = re.sub(pattern, replacement, updated_content)
    
    # Écrire le fichier mis à jour
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(updated_content)
    
    print("✅ ai_server.py mis à jour pour Supabase")
    print("📝 Modifications apportées:")
    print("   • RUNNING_ON_RENDER → RUNNING_ON_SUPABASE")
    print("   • Détection automatique de l'environnement Supabase")
    print("   • Configuration SSL adaptée pour Supabase")
    print("   • Logs mis à jour")

def create_backup():
    """Créer une sauvegarde du fichier original"""
    file_path = Path("ai_server.py")
    backup_path = Path("ai_server_render_backup.py")
    
    if file_path.exists():
        with open(file_path, 'r', encoding='utf-8') as src:
            content = src.read()
        with open(backup_path, 'w', encoding='utf-8') as dst:
            dst.write(content)
        print(f"✅ Sauvegarde créée: {backup_path}")

def main():
    """Fonction principale"""
    print("🔧 MISE À JOUR AI_SERVER POUR SUPABASE")
    print("=" * 50)
    
    # Créer une sauvegarde
    create_backup()
    
    # Mettre à jour le fichier
    update_ai_server_for_supabase()
    
    print("\n📋 Étapes suivantes:")
    print("1. Configurez votre mot de passe Supabase:")
    print("   export SUPABASE_PASSWORD='votre_mot_de_passe'")
    print("\n2. Copiez .env.supabase vers .env:")
    print("   cp .env.supabase .env")
    print("\n3. Modifiez .env pour ajouter votre vrai mot de passe")
    print("\n4. Lancez la migration des données:")
    print("   python migrate_to_supabase.py")
    print("\n5. Redémarrez le serveur:")
    print("   python ai_server.py")

if __name__ == "__main__":
    main()
