#!/usr/bin/env python3
"""
Script pour synchroniser les mises à jour de ai_server.py vers ai_server_cloud.py
"""

import re

def sync_cloud_updates():
    """Synchroniser les mises à jour critiques dans la version cloud"""
    
    print("SYNCHRONISATION VERSION CLOUD")
    print("=" * 50)
    
    # Lire les deux fichiers
    with open('ai_server.py', 'r', encoding='utf-8') as f:
        local_content = f.read()
    
    with open('ai_server_cloud.py', 'r', encoding='utf-8') as f:
        cloud_content = f.read()
    
    # Extraire les endpoints /test et /validate du fichier local
    test_endpoint_pattern = r'(@app\.post\("/test".*?)(?=@app\.|\Z)'
    validate_endpoint_pattern = r'(@app\.post\("/validate".*?)(?=@app\.|\Z)'
    
    test_endpoint = re.search(test_endpoint_pattern, local_content, re.DOTALL)
    validate_endpoint = re.search(validate_endpoint_pattern, local_content, re.DOTALL)
    
    if test_endpoint:
        print("Endpoint /test trouvé dans la version locale")
    else:
        print("Endpoint /test non trouvé dans la version locale")
    
    if validate_endpoint:
        print("Endpoint /validate trouvé dans la version locale")
    else:
        print("Endpoint /validate non trouvé dans la version locale")
    
    # Mettre à jour la version cloud
    updated_cloud = cloud_content
    
    # Ajouter les endpoints manquants avant le dernier @app
    if test_endpoint and validate_endpoint:
        # Trouver où insérer (avant le dernier @app)
        last_app_pos = updated_cloud.rfind('@app.')
        if last_app_pos > 0:
            insertion_point = updated_cloud.rfind('\n', 0, last_app_pos) + 1
            
            # Insérer les nouveaux endpoints
            new_endpoints = "\n" + "="*50 + "\n"
            new_endpoints += "# ENDPOINTS DE TEST ET VALIDATION\n"
            new_endpoints += "="*50 + "\n\n"
            new_endpoints += test_endpoint.group(1) + "\n\n"
            new_endpoints += validate_endpoint.group(1) + "\n"
            
            updated_cloud = updated_cloud[:insertion_point] + new_endpoints + updated_cloud[insertion_point:]
            
            print("Endpoints /test et /validate ajoutés à la version cloud")
    
    # Mettre à jour la version
    updated_cloud = re.sub(
        r'version="[^"]*"',
        'version="2.0.2-cloud"',
        updated_cloud
    )
    
    # Mettre à jour la liste des endpoints dans root
    updated_cloud = re.sub(
        r'"endpoints": \[.*?\]',
        '"endpoints": ['
        '"/fundamental/{symbol} (GET) - Données fondamentales", '
        '"/news/{symbol} (GET) - Actualités marché", '
        '"/economic-calendar (GET) - Calendrier économique", '
        '"/decision (POST)", '
        '"/test (POST) - Test de connexion", '
        '"/validate (POST) - Validation de format", '
        '"/analysis (GET)", '
        '"/time_windows/{symbol} (GET)", '
        '"/predict/{symbol} (GET)", '
        '"/prediction (POST) - Prédiction de prix futurs pour graphique MQ5", '
        '"/health", '
        '"/status", '
        '"/logs", '
        '"/indicators/analyze (POST)", '
        '"/indicators/sentiment/{symbol} (GET)", '
        '"/indicators/volume_profile/{symbol} (GET)", '
        '"/analyze/gemini (POST)", '
        '"/mt5/history-upload (POST) - Upload données historiques MT5 vers Render (bridge)"'
        ']',
        updated_cloud,
        flags=re.DOTALL
    )
    
    # Sauvegarder la version mise à jour
    with open('ai_server_cloud.py', 'w', encoding='utf-8') as f:
        f.write(updated_cloud)
    
    print("Version cloud mise à jour avec succes !")
    print("\nModifications apportees :")
    print("   - Ajout endpoints /test et /validate")
    print("   - Mise a jour version 2.0.2-cloud")
    print("   - Mise a jour liste des endpoints")
    
    print("\nProchaine etape :")
    print("   1. Commit les changements : git add ai_server_cloud.py")
    print("   2. Push vers GitHub")
    print("   3. Redeployez sur Render")

if __name__ == "__main__":
    sync_cloud_updates()
