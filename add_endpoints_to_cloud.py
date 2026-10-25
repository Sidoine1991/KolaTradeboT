#!/usr/bin/env python3
"""
Ajouter manuellement les endpoints /test et /validate à ai_server_cloud.py
"""

# Définition des endpoints à ajouter
test_endpoint = '''
@app.post("/test")
async def test_endpoint():
    """Endpoint de test pour vérifier que le serveur accepte les requêtes POST"""
    return {
        "message": "Test endpoint fonctionne",
        "status": "ok",
        "timestamp": datetime.now().isoformat()
    }

@app.post("/validate")
async def validate_format(request: dict):
    """Endpoint de validation pour tester les formats de requêtes"""
    required_fields = ["symbol", "bid", "ask"]
    missing_fields = [field for field in required_fields if field not in request]
    
    if missing_fields:
        return {
            "valid": False,
            "missing_fields": missing_fields,
            "error": f"Champs manquants: {', '.join(missing_fields)}"
        }
    
    # Validation basique des valeurs
    if request["bid"] <= 0 or request["ask"] <= 0:
        return {
            "valid": False,
            "error": "Les prix bid/ask doivent être positifs"
        }
    
    if request["bid"] >= request["ask"]:
        return {
            "valid": False,
            "error": "Le bid doit être inférieur à l'ask"
        }
    
    return {
        "valid": True,
        "message": "Format de requête valide",
        "symbol": request["symbol"],
        "bid": request["bid"],
        "ask": request["ask"]
    }
'''

def add_endpoints():
    """Ajouter les endpoints au fichier cloud"""
    
    print("AJOUT ENDPOINTS /test et /validate")
    print("=" * 40)
    
    # Lire le fichier cloud
    with open('ai_server_cloud.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Trouver où insérer (après @app.get("/health"))
    insert_pos = content.find('@app.get("/health")')
    if insert_pos == -1:
        print("Erreur: impossible de trouver où insérer")
        return
    
    # Trouver la fin de cet endpoint
    end_pos = content.find('\n\n@app', insert_pos)
    if end_pos == -1:
        end_pos = content.find('\n@app', insert_pos)
    if end_pos == -1:
        end_pos = len(content)
    
    insert_pos = end_pos
    
    # Insérer les nouveaux endpoints
    new_content = content[:insert_pos] + test_endpoint + "\n\n" + content[insert_pos:]
    
    # Mettre à jour la version
    new_content = new_content.replace('version="2.0.0-cloud"', 'version="2.0.2-cloud"')
    
    # Mettre à jour la liste des endpoints
    endpoints_list = '''"endpoints": [
            "/fundamental/{symbol} (GET) - Données fondamentales",
            "/news/{symbol} (GET) - Actualités marché", 
            "/economic-calendar (GET) - Calendrier économique",
            "/decision (POST)",
            "/test (POST) - Test de connexion",
            "/validate (POST) - Validation de format",
            "/analysis (GET)",
            "/time_windows/{symbol} (GET)",
            "/predict/{symbol} (GET)",
            "/prediction (POST) - Prédiction de prix futurs pour graphique MQ5",
            "/health",
            "/status",
            "/logs",
            "/indicators/analyze (POST)",
            "/indicators/sentiment/{symbol} (GET)",
            "/indicators/volume_profile/{symbol} (GET)",
            "/analyze/gemini (POST)",
            "/mt5/history-upload (POST) - Upload données historiques MT5 vers Render (bridge)"
        ]'''
    
    # Remplacer la liste des endpoints
    import re
    new_content = re.sub(
        r'"endpoints": \[.*?\]',
        endpoints_list,
        new_content,
        flags=re.DOTALL
    )
    
    # Sauvegarder
    with open('ai_server_cloud.py', 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print("Endpoints /test et /validate ajoutes avec succes!")
    print("Version mise a jour: 2.0.2-cloud")
    print("\nProchaines etapes:")
    print("1. git add ai_server_cloud.py")
    print("2. git commit -m 'Cloud v2.0.2 - Ajout endpoints /test et /validate'")
    print("3. git push")
    print("4. Redeployer sur Render")

if __name__ == "__main__":
    add_endpoints()
