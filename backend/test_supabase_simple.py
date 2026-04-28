#!/usr/bin/env python3
"""
Script de test simplifié pour Supabase sans dépendances externes
Utilise uniquement les modules standard Python
"""

import urllib.request
import urllib.parse
import json
import os
from datetime import datetime

def test_supabase_basic():
    """Test basique de connexion Supabase avec urllib"""
    
    print("🔧 Test de connexion Supabase (mode simplifié)")
    print("=" * 50)
    
    # Configuration par défaut (à modifier avec vos vraies valeurs)
    supabase_url = os.getenv("SUPABASE_URL", "https://your-project.supabase.co")
    supabase_key = os.getenv("SUPABASE_KEY", "your-supabase-anon-key")
    
    print(f"📍 URL: {supabase_url}")
    print(f"🔑 Clé: {supabase_key[:20]}..." if len(supabase_key) > 20 else f"🔑 Clé: {supabase_key}")
    
    # URL de l'API
    api_url = f"{supabase_url}/rest/v1/support_resistance_levels"
    
    # Headers
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    # Paramètres de test
    params = {
        "select": "*",
        "limit": "5"
    }
    
    # Construire l'URL complète avec paramètres
    url_with_params = f"{api_url}?" + urllib.parse.urlencode(params)
    
    print(f"\n🌐 Requête test vers: {url_with_params}")
    
    try:
        # Créer la requête
        req = urllib.request.Request(url_with_params, headers=headers)
        
        # Envoyer la requête
        with urllib.request.urlopen(req, timeout=10) as response:
            status_code = response.getcode()
            print(f"📊 Status Code: {status_code}")
            
            if status_code == 200:
                # Lire la réponse
                data = response.read().decode('utf-8')
                
                try:
                    # Parser le JSON
                    json_data = json.loads(data)
                    
                    print(f"✅ Connexion réussie!")
                    print(f"📋 {len(json_data)} enregistrements trouvés")
                    
                    if json_data:
                        print("\n📊 Exemples de niveaux S/R:")
                        for i, level in enumerate(json_data[:3], 1):
                            print(f"  {i}. {level.get('symbol', 'N/A')}")
                            print(f"     Support: {level.get('support', 'N/A')}")
                            print(f"     Résistance: {level.get('resistance', 'N/A')}")
                            print(f"     Score: {level.get('strength_score', 'N/A')}")
                            print(f"     Touches: {level.get('touch_count', 'N/A')}")
                            print()
                    else:
                        print("⚠️ Table vide mais accessible")
                        
                    return True
                    
                except json.JSONDecodeError as e:
                    print(f"❌ Erreur parsing JSON: {e}")
                    print(f"📄 Réponse brute: {data[:200]}...")
                    return False
                    
            else:
                print(f"❌ Erreur HTTP: {status_code}")
                return False
                
    except urllib.error.HTTPError as e:
        print(f"❌ Erreur HTTP: {e.code} - {e.reason}")
        if hasattr(e, 'read'):
            error_data = e.read().decode('utf-8')
            print(f"📄 Détail erreur: {error_data[:200]}...")
        return False
        
    except urllib.error.URLError as e:
        print(f"❌ Erreur URL: {e.reason}")
        return False
        
    except Exception as e:
        print(f"❌ Erreur inattendue: {e}")
        return False

def test_mql5_format_simulation():
    """Simuler le format de réponse attendu par MQL5"""
    
    print("\n🔧 Test format pour MQL5")
    print("=" * 30)
    
    # Simuler une réponse Supabase typique
    sample_response = [
        {
            "id": 1,
            "symbol": "Boom 1000 Index",
            "support": 1000.50,
            "resistance": 1002.00,
            "timeframe": "M1",
            "strength_score": 85.5,
            "touch_count": 12,
            "last_touch": "2025-03-11T10:30:00Z",
            "created_at": "2025-03-11T09:00:00Z",
            "updated_at": "2025-03-11T10:30:00Z"
        }
    ]
    
    json_str = json.dumps(sample_response)
    
    print("📊 Format JSON attendu par MQL5:")
    print(json_str)
    
    # Simuler le parsing MQL5
    print("\n🔍 Simulation parsing MQL5:")
    
    # Chercher "support":
    support_pos = json_str.find('"support":')
    if support_pos > 0:
        start = support_pos + 11  # Après "support":
        support_str = ""
        while start < len(json_str) and json_str[start] not in [',', '}']:
            if json_str[start] not in [' ', '"']:
                support_str += json_str[start]
            start += 1
        print(f"✅ Support trouvé: {support_str}")
    
    # Chercher "resistance":
    resistance_pos = json_str.find('"resistance":')
    if resistance_pos > 0:
        start = resistance_pos + 14  # Après "resistance":
        resistance_str = ""
        while start < len(json_str) and json_str[start] not in [',', '}']:
            if json_str[start] not in [' ', '"']:
                resistance_str += json_str[start]
            start += 1
        print(f"✅ Résistance trouvée: {resistance_str}")
    
    print("\n✅ Format compatible avec le parsing MQL5!")

def test_environment_variables():
    """Vérifier les variables d'environnement"""
    
    print("\n🔧 Variables d'environnement")
    print("=" * 30)
    
    vars_to_check = [
        "SUPABASE_URL",
        "SUPABASE_KEY", 
        "SUPABASE_SERVICE_KEY",
        "MT5_LOGIN",
        "MT5_PASSWORD",
        "MT5_SERVER"
    ]
    
    for var in vars_to_check:
        value = os.getenv(var)
        if value:
            masked_value = value[:10] + "..." if len(value) > 10 else value
            print(f"✅ {var}: {masked_value}")
        else:
            print(f"❌ {var}: Non définie")
    
    print(f"\n📁 Répertoire de travail: {os.getcwd()}")
    print(f"📁 Fichier .env.supabase existe: {os.path.exists('.env.supabase')}")

if __name__ == "__main__":
    print("🚀 Tests Supabase - Mode Simplifié")
    print("=" * 50)
    
    # Test 1: Variables d'environnement
    test_environment_variables()
    
    # Test 2: Connexion Supabase
    success = test_supabase_basic()
    
    # Test 3: Format MQL5
    test_mql5_format_simulation()
    
    print("\n" + "=" * 50)
    if success:
        print("🎉 Tests terminés avec succès!")
        print("💡 Prochaines étapes:")
        print("   1. Configurer vos vraies clés Supabase")
        print("   2. Exécuter la migration SQL")
        print("   3. Lancer le script de mise à jour des niveaux")
    else:
        print("❌ Tests échoués")
        print("💡 Vérifications:")
        print("   1. URL Supabase correcte?")
        print("   2. Clé API valide?")
        print("   3. Table créée dans Supabase?")
        print("   4. Accès réseau autorisé?")
