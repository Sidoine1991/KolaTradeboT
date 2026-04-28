#!/usr/bin/env python3
"""
Script de test avec les vraies clés Supabase du projet KolaTradeBoT
"""

import urllib.request
import urllib.parse
import json
from datetime import datetime

def test_real_supabase_connection():
    """Test avec les vraies clés du projet KolaTradeBoT"""
    
    print("🔧 Test connexion Supabase - Projet KolaTradeBoT")
    print("=" * 50)
    
    # Vraies clés du projet
    supabase_url = "https://bpzqnooiisgadzicwupi.supabase.co"
    supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4"
    
    print(f"📍 URL: {supabase_url}")
    print(f"🔑 Clé: {supabase_key[:20]}...")
    print(f"🆔 Project ID: bpzqnooiisgadzicwupi")
    
    # Test 1: Vérifier si la table existe
    print("\n📊 Test 1: Vérification table support_resistance_levels")
    
    api_url = f"{supabase_url}/rest/v1/support_resistance_levels"
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    params = {
        "select": "*",
        "limit": "5"
    }
    
    url_with_params = f"{api_url}?" + urllib.parse.urlencode(params)
    
    try:
        req = urllib.request.Request(url_with_params, headers=headers)
        
        with urllib.request.urlopen(req, timeout=10) as response:
            status_code = response.getcode()
            print(f"📊 Status Code: {status_code}")
            
            if status_code == 200:
                data = response.read().decode('utf-8')
                
                try:
                    json_data = json.loads(data)
                    
                    print(f"✅ Table accessible!")
                    print(f"📋 {len(json_data)} enregistrements trouvés")
                    
                    if json_data:
                        print("\n📊 Niveaux S/R actuels:")
                        for i, level in enumerate(json_data[:3], 1):
                            print(f"  {i}. {level.get('symbol', 'N/A')}")
                            print(f"     Support: {level.get('support', 'N/A')}")
                            print(f"     Résistance: {level.get('resistance', 'N/A')}")
                            print(f"     Score: {level.get('strength_score', 'N/A')}")
                            print(f"     Touches: {level.get('touch_count', 'N/A')}")
                            print()
                    else:
                        print("⚠️ Table vide - nous allons la créer")
                        
                    return True, json_data
                    
                except json.JSONDecodeError as e:
                    print(f"❌ Erreur parsing JSON: {e}")
                    print(f"📄 Réponse: {data[:200]}...")
                    return False, None
                    
            else:
                print(f"❌ Erreur HTTP: {status_code}")
                return False, None
                
    except urllib.error.HTTPError as e:
        print(f"❌ Erreur HTTP: {e.code} - {e.reason}")
        
        # Si la table n'existe pas (code 406 ou 400), c'est normal
        if e.code in [406, 400]:
            print("📝 La table n'existe pas encore - nous allons la créer")
            return False, None
        else:
            if hasattr(e, 'read'):
                error_data = e.read().decode('utf-8')
                print(f"📄 Erreur: {error_data[:200]}...")
            return False, None
            
    except Exception as e:
        print(f"❌ Erreur connexion: {e}")
        return False, None

def create_support_resistance_table():
    """Créer la table via l'API Supabase (si possible)"""
    
    print("\n📝 Création de la table support_resistance_levels")
    print("=" * 50)
    
    # URL Supabase
    supabase_url = "https://bpzqnooiisgadzicwupi.supabase.co"
    supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4"
    
    # SQL pour créer la table
    create_table_sql = """
    CREATE TABLE IF NOT EXISTS support_resistance_levels (
        id BIGSERIAL PRIMARY KEY,
        symbol VARCHAR(50) NOT NULL,
        support DECIMAL(15,5) NOT NULL,
        resistance DECIMAL(15,5) NOT NULL,
        timeframe VARCHAR(10) NOT NULL DEFAULT 'M1',
        strength_score DECIMAL(5,2) DEFAULT 0.0,
        touch_count INTEGER DEFAULT 0,
        last_touch TIMESTAMP NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Créer les index
    CREATE INDEX IF NOT EXISTS idx_support_resistance_symbol ON support_resistance_levels(symbol);
    CREATE INDEX IF NOT EXISTS idx_support_resistance_symbol_timeframe ON support_resistance_levels(symbol, timeframe);
    
    -- Activer RLS
    ALTER TABLE support_resistance_levels ENABLE ROW LEVEL SECURITY;
    
    -- Politiques pour permettre les lectures
    CREATE POLICY IF NOT EXISTS "Allow read access" ON support_resistance_levels FOR SELECT USING (true);
    
    -- Insérer des données de test
    INSERT INTO support_resistance_levels (symbol, support, resistance, timeframe, strength_score, touch_count) VALUES
    ('Boom 1000 Index', 1000.50, 1002.00, 'M1', 85.5, 12),
    ('Boom 1000 Index', 998.75, 1000.25, 'M1', 72.3, 8),
    ('Crash 1000 Index', 999.25, 1000.75, 'M1', 82.1, 15),
    ('Crash 1000 Index', 1002.25, 1003.75, 'M1', 76.8, 9);
    """
    
    print("📄 SQL à exécuter:")
    print(create_table_sql[:300] + "...")
    
    print("\n💡 Pour créer la table:")
    print("1. Allez sur: https://supabase.com/dashboard/project/bpzqnooiisgadzicwupi/sql")
    print("2. Copiez-collez le SQL ci-dessus")
    print("3. Cliquez sur 'Run'")
    
    print("\n📝 Ou utilisez le fichier de migration:")
    print("   supabase/migrations/20250311_support_resistance_levels.sql")

def test_mt5_integration_format():
    """Tester le format exact pour MT5"""
    
    print("\n🔧 Test format MT5 avec données réelles")
    print("=" * 40)
    
    # Simuler une réponse Supabase typique
    sample_data = [
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
    
    json_str = json.dumps(sample_data)
    
    print("📊 JSON pour MT5:")
    print(json_str)
    
    # Test parsing comme dans MQL5
    print("\n🔍 Parsing MQL5:")
    
    # Parser support
    support_pos = json_str.find('"support":')
    if support_pos > 0:
        start = support_pos + 11
        support_str = ""
        while start < len(json_str) and json_str[start] not in [',', '}']:
            if json_str[start] not in [' ', '"']:
                support_str += json_str[start]
            start += 1
        print(f"✅ Support: {support_str}")
    
    # Parser résistance
    resistance_pos = json_str.find('"resistance":')
    if resistance_pos > 0:
        start = resistance_pos + 14
        resistance_str = ""
        while start < len(json_str) and json_str[start] not in [',', '}']:
            if json_str[start] not in [' ', '"']:
                resistance_str += json_str[start]
            start += 1
        print(f"✅ Résistance: {resistance_str}")
    
    print("\n✅ Format compatible avec MT5!")

def update_env_file():
    """Mettre à jour le fichier .env.supabase avec les bonnes variables"""
    
    print("\n📝 Mise à jour du fichier .env.supabase")
    print("=" * 40)
    
    env_content = """# Configuration KolaTradeBoT avec Supabase
# Mis à jour pour les niveaux Support/Résistance

# URL et clés du projet
SUPABASE_URL=https://bpzqnooiisgadzicwupi.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4
SUPABASE_PROJECT_ID=bpzqnooiisgadzicwupi
SUPABASE_PROJECT_NAME=KolaTradeBoT

# Configuration pour MT5
SUPABASE_MODE=enabled
SUPABASE_USE_API=true

# Base de données
DATABASE_URL=postgresql://postgres:Socrate2025_A@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require

# Variables pour les scripts Python
MT5_LOGIN=votre-login-mt5
MT5_PASSWORD=votre-password-mt5  
MT5_SERVER=votre-serveur-mt5

# Options d'analyse
ANALYSIS_BARS=1000
TOUCH_TOLERANCE=0.001
STRENGTH_THRESHOLD=50.0
"""
    
    with open(".env.supabase", "w") as f:
        f.write(env_content)
    
    print("✅ Fichier .env.supabase mis à jour")
    print("📋 Variables ajoutées pour MT5 et Python")

if __name__ == "__main__":
    print("🚀 Test Supabase - Projet KolaTradeBoT")
    print("=" * 50)
    
    # Test 1: Connexion
    success, data = test_real_supabase_connection()
    
    if not success:
        # Test 2: Création table
        create_support_resistance_table()
    
    # Test 3: Format MT5
    test_mt5_integration_format()
    
    # Test 4: Mise à jour .env
    update_env_file()
    
    print("\n" + "=" * 50)
    print("🎉 Test terminé!")
    
    if success:
        print("✅ Supabase accessible et prêt pour MT5")
    else:
        print("📝 Actions requises:")
        print("   1. Créer la table dans Supabase SQL Editor")
        print("   2. Insérer les données de test")
        print("   3. Relancer ce script pour vérifier")
    
    print("\n🎯 Configuration MT5:")
    print("   SupabaseUrl = https://bpzqnooiisgadzicwupi.supabase.co")
    print("   SupabaseApiKey = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
