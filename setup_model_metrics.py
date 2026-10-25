#!/usr/bin/env python3
"""
Script pour créer les tables de métriques dans Supabase
"""

import os
import asyncio
import httpx
from datetime import datetime
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv('.env.supabase')

async def create_model_metrics_table():
    """Crée la table model_metrics dans Supabase"""
    
    supabase_url = os.getenv("SUPABASE_URL", "https://bpzqnooiisgadzicwupi.supabase.co")
    supabase_key = os.getenv("SUPABASE_ANON_KEY")
    
    print(f"URL: {supabase_url}")
    print(f"Key: {supabase_key[:20]}..." if supabase_key else "None")
    
    if not supabase_key:
        print("❌ SUPABASE_ANON_KEY non trouvé")
        return
    
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }
    
    # Lire le SQL
    with open('create_model_metrics_table.sql', 'r') as f:
        sql_content = f.read()
    
    # Exécuter via l'endpoint SQL direct
    headers_sql = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/sql"
    }
    
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(
                f"{supabase_url}/rest/v1/rpc/sql",
                data=sql_content,
                headers=headers_sql,
                timeout=30.0
            )
            
            if resp.status_code == 200:
                print("✅ Tables model_metrics créées avec succès")
            else:
                print(f"❌ Erreur création tables (RPC): {resp.status_code} - {resp.text}")
                
                # Alternative: créer manuellement via l'API REST
                print("🔄 Tentative création manuelle...")
                
                # Créer la table model_metrics
                table_sql = """
                CREATE TABLE IF NOT EXISTS model_metrics (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    symbol VARCHAR(50) NOT NULL,
                    timeframe VARCHAR(10) NOT NULL,
                    model_type VARCHAR(50) NOT NULL DEFAULT 'random_forest',
                    accuracy DECIMAL(10,6) NOT NULL,
                    f1_score DECIMAL(10,6) NOT NULL,
                    training_samples INTEGER NOT NULL,
                    training_date TIMESTAMP WITH TIME ZONE NOT NULL,
                    feature_importance JSONB,
                    metadata JSONB,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                );
                """
                
                print("📝 Veuillez exécuter manuellement dans Supabase Dashboard:")
                print(table_sql)
                
        except Exception as e:
            print(f"❌ Erreur connexion Supabase: {e}")

if __name__ == "__main__":
    asyncio.run(create_model_metrics_table())
