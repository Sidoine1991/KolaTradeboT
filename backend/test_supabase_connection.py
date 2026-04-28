#!/usr/bin/env python3
"""
Script de test pour vérifier la connexion à Supabase et les niveaux S/R
"""

import os
import sys
import json
import requests
from datetime import datetime
from supabase import create_client, Client

def test_supabase_connection():
    """Tester la connexion à Supabase"""
    
    # Configuration
    supabase_url = os.getenv("SUPABASE_URL", "https://your-project.supabase.co")
    supabase_key = os.getenv("SUPABASE_KEY", "your-supabase-anon-key")
    
    print("🔧 Test de connexion Supabase")
    print(f"📍 URL: {supabase_url}")
    print(f"🔑 Clé: {supabase_key[:20]}..." if len(supabase_key) > 20 else f"🔑 Clé: {supabase_key}")
    
    try:
        # Connexion à Supabase
        supabase: Client = create_client(supabase_url, supabase_key)
        
        # Test 1: Vérifier si la table existe
        print("\n📊 Test 1: Vérification de la table support_resistance_levels")
        
        try:
            response = supabase.table("support_resistance_levels").select("*").limit(1).execute()
            
            if response.data:
                print("✅ Table accessible")
                print(f"📋 Exemple de données: {response.data[0]}")
            else:
                print("⚠️ Table vide mais accessible")
                
        except Exception as e:
            print(f"❌ Erreur accès table: {e}")
            return False
        
        # Test 2: Requête directe HTTP
        print("\n🌐 Test 2: Requête HTTP directe")
        
        api_url = f"{supabase_url}/rest/v1/support_resistance_levels"
        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json"
        }
        
        params = {
            "select": "*",
            "limit": 5
        }
        
        try:
            response = requests.get(api_url, headers=headers, params=params)
            
            if response.status_code == 200:
                data = response.json()
                print(f"✅ Requête HTTP réussie - {len(data)} enregistrements trouvés")
                
                if data:
                    print("📊 Premiers niveaux S/R:")
                    for i, level in enumerate(data[:3], 1):
                        print(f"  {i}. {level['symbol']} - S:{level['support']} R:{level['resistance']} Score:{level['strength_score']}")
            else:
                print(f"❌ Erreur HTTP: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Erreur requête HTTP: {e}")
            return False
        
        # Test 3: Requête pour un symbole spécifique
        print("\n🎯 Test 3: Requête pour Boom 1000 Index")
        
        try:
            response = supabase.table("support_resistance_levels")\
                .select("*")\
                .eq("symbol", "Boom 1000 Index")\
                .eq("timeframe", "M1")\
                .order("strength_score", desc=True)\
                .limit(3)\
                .execute()
            
            if response.data:
                print(f"✅ {len(response.data)} niveaux trouvés pour Boom 1000 Index")
                for level in response.data:
                    print(f"  📊 S:{level['support']} R:{level['resistance']} Score:{level['strength_score']} Touches:{level['touch_count']}")
            else:
                print("⚠️ Aucun niveau trouvé pour Boom 1000 Index")
                
        except Exception as e:
            print(f"❌ Erreur requête symbole: {e}")
            return False
        
        # Test 4: Insertion de test
        print("\n📝 Test 4: Insertion d'un niveau de test")
        
        test_level = {
            "symbol": "Test Symbol",
            "support": 1000.50,
            "resistance": 1002.00,
            "timeframe": "M1",
            "strength_score": 75.5,
            "touch_count": 5,
            "last_touch": datetime.now().isoformat()
        }
        
        try:
            response = supabase.table("support_resistance_levels").insert(test_level).execute()
            
            if response.data:
                print("✅ Insertion réussie")
                print(f"📋 ID inséré: {response.data[0]['id']}")
                
                # Nettoyage
                supabase.table("support_resistance_levels").delete().eq("id", response.data[0]['id']).execute()
                print("🧹 Test nettoyé")
            else:
                print("❌ Échec insertion")
                return False
                
        except Exception as e:
            print(f"❌ Erreur insertion: {e}")
            return False
        
        print("\n✅ Tous les tests passés avec succès!")
        return True
        
    except Exception as e:
        print(f"❌ Erreur connexion Supabase: {e}")
        return False

def test_mql5_format():
    """Tester le format de réponse pour MQL5"""
    
    print("\n🔧 Test format de réponse pour MQL5")
    
    supabase_url = os.getenv("SUPABASE_URL", "https://your-project.supabase.co")
    supabase_key = os.getenv("SUPABASE_KEY", "your-supabase-anon-key")
    
    try:
        api_url = f"{supabase_url}/rest/v1/support_resistance_levels"
        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json"
        }
        
        params = {
            "symbol": "eq.Boom 1000 Index",
            "timeframe": "eq.M1",
            "order": "strength_score.desc",
            "limit": 1
        }
        
        response = requests.get(api_url, headers=headers, params=params)
        
        if response.status_code == 200:
            data = response.json()
            
            if data:
                level = data[0]
                print("📊 Format attendu par MQL5:")
                print(f"  Support: {level['support']}")
                print(f"  Résistance: {level['resistance']}")
                print(f"  JSON complet: {json.dumps(level, indent=2)}")
                
                # Simulation du parsing MQL5
                json_str = json.dumps([level])
                print(f"\n🔍 Chaîne pour parsing MQL5:")
                print(json_str[:200] + "..." if len(json_str) > 200 else json_str)
                
            else:
                print("⚠️ Aucune donnée à tester")
        else:
            print(f"❌ Erreur: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Erreur test format: {e}")

if __name__ == "__main__":
    print("🚀 Démarrage des tests Supabase")
    print("=" * 50)
    
    success = test_supabase_connection()
    
    if success:
        test_mql5_format()
        print("\n🎉 Tests terminés avec succès!")
    else:
        print("\n❌ Tests échoués")
        sys.exit(1)
