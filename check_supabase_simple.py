#!/usr/bin/env python3
"""
Script simple pour vérifier l'état des tables Supabase
sans dépendances externes complexes
"""

import os
import json
import urllib.request
import urllib.parse
from datetime import datetime

def load_env():
    """Charger les variables d'environnement depuis .env"""
    env_vars = {}
    try:
        with open('.env', 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()
        return env_vars
    except FileNotFoundError:
        print("❌ Fichier .env non trouvé")
        return {}

def test_supabase_connection():
    """Tester la connexion Supabase avec requête REST simple"""
    print("🚀 TEST DE CONNEXION SUPABASE")
    print("="*50)
    
    env = load_env()
    url = env.get('SUPABASE_URL')
    key = env.get('SUPABASE_ANON_KEY')
    
    if not url or not key:
        print("❌ Variables SUPABASE_URL ou SUPABASE_ANON_KEY manquantes")
        return False
    
    print(f"✅ URL Supabase: {url}")
    print(f"✅ Clé API trouvée: {key[:20]}...")
    
    # Tester l'accès à la table correction_zones_analysis
    try:
        table_url = f"{url}/rest/v1/correction_zones_analysis?select=count&limit=1"
        req = urllib.request.Request(table_url)
        req.add_header('apikey', key)
        req.add_header('Authorization', f'Bearer {key}')
        
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            print(f"✅ Table correction_zones_analysis accessible")
            return True
            
    except Exception as e:
        print(f"❌ Erreur d'accès à correction_zones_analysis: {e}")
        return False

def check_table_data():
    """Vérifier les données dans les tables principales"""
    print("\n📊 VÉRIFICATION DES DONNÉES")
    print("="*40)
    
    env = load_env()
    url = env.get('SUPABASE_URL')
    key = env.get('SUPABASE_ANON_KEY')
    
    tables = [
        'correction_zones_analysis',
        'correction_predictions',
        'prediction_performance',
        'symbol_correction_patterns'
    ]
    
    for table in tables:
        try:
            # Compter les enregistrements
            count_url = f"{url}/rest/v1/{table}?select=id&limit=0"
            req = urllib.request.Request(count_url)
            req.add_header('apikey', key)
            req.add_header('Authorization', f'Bearer {key}')
            req.add_header('Prefer', 'count=exact')
            
            with urllib.request.urlopen(req) as response:
                count = response.headers.get('content-range', '0-0/0').split('/')[-1]
                print(f"📋 {table}: {count} enregistrements")
                
                # Obtenir un échantillon si des données existent
                if int(count) > 0:
                    sample_url = f"{url}/rest/v1/{table}?select=*&limit=2"
                    req_sample = urllib.request.Request(sample_url)
                    req_sample.add_header('apikey', key)
                    req_sample.add_header('Authorization', f'Bearer {key}')
                    
                    with urllib.request.urlopen(req_sample) as sample_response:
                        sample_data = json.loads(sample_response.read().decode())
                        print(f"   📄 Échantillon: {sample_data}")
                        
        except Exception as e:
            print(f"❌ Erreur table {table}: {e}")

def check_correction_summary():
    """Vérifier spécifiquement la vue correction_summary"""
    print("\n🔍 VÉRIFICATION DE correction_summary")
    print("="*45)
    
    env = load_env()
    url = env.get('SUPABASE_URL')
    key = env.get('SUPABASE_ANON_KEY')
    
    try:
        # Essayer d'accéder à la vue
        view_url = f"{url}/rest/v1/correction_summary?select=*&limit=5"
        req = urllib.request.Request(view_url)
        req.add_header('apikey', key)
        req.add_header('Authorization', f'Bearer {key}')
        
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            print(f"✅ Vue correction_summary accessible: {len(data)} enregistrements")
            for record in data:
                print(f"   📊 {record}")
                
    except Exception as e:
        print(f"❌ Erreur accès vue correction_summary: {e}")
        
        # Essayer la table sous-jacente
        try:
            table_url = f"{url}/rest/v1/correction_zones_analysis?select=symbol,COUNT(*)&limit=5"
            req = urllib.request.Request(table_url)
            req.add_header('apikey', key)
            req.add_header('Authorization', f'Bearer {key}')
            
            with urllib.request.urlopen(req) as response:
                data = json.loads(response.read().decode())
                print(f"✅ Table correction_zones_analysis (alternative): {len(data)} enregistrements")
                for record in data:
                    print(f"   📊 {record}")
                    
        except Exception as e2:
            print(f"❌ Erreur table correction_zones_analysis: {e2}")

def main():
    print(f"📅 Diagnostic Supabase - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    if test_supabase_connection():
        check_table_data()
        check_correction_summary()
        
        print("\n💡 RECOMMANDATIONS:")
        print("   1. Si les tables sont vides: exécuter supabase_correction_tables.sql")
        print("   2. Si correction_summary est vide: insérer des données d'analyse")
        print("   3. Vérifier les permissions RLS dans Supabase Dashboard")
    else:
        print("\n❌ Impossible de se connecter à Supabase")
        print("   Vérifiez les identifiants dans le fichier .env")

if __name__ == "__main__":
    main()
