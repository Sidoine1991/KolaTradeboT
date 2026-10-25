#!/usr/bin/env python3
"""
Script de test de connexion à Supabase
"""

import asyncio
import asyncpg
import os

async def test_supabase_connection():
    """Test different connection formats"""
    
    password = "Socrate2025@1991"
    
    # Différents formats d'URL à tester
    urls_to_test = [
        f"postgresql://postgres.bpzqnooiisgadzicwupi:{password}@aws-0-eu-central-1.pooler.supabase.com:5432/postgres",
        f"postgresql://postgres:{password}@aws-0-eu-central-1.pooler.supabase.com:5432/postgres",
        f"postgresql://postgres:{password}@aws-0-eu-central-1.pooler.supabase.com:6543/postgres",
        f"postgresql://postgres.bpzqnooiisgadzicwupi:{password}@aws-0-eu-central-1.pooler.supabase.com:6543/postgres",
    ]
    
    for i, url in enumerate(urls_to_test, 1):
        print(f"\n🔍 Test {i}: {url}")
        try:
            conn = await asyncpg.connect(url)
            print(f"✅ Connexion réussie avec le format {i}!")
            
            # Test simple query
            result = await conn.fetchval("SELECT version()")
            print(f"📊 Version PostgreSQL: {result[:50]}...")
            
            await conn.close()
            return url
            
        except Exception as e:
            print(f"❌ Échec format {i}: {e}")
    
    print("\n❌ Tous les formats de connexion ont échoué")
    return None

if __name__ == "__main__":
    print("🧪 TEST DE CONNEXION SUPABASE")
    print("=" * 50)
    
    result = asyncio.run(test_supabase_connection())
    
    if result:
        print(f"\n✅ Format correct trouvé: {result}")
    else:
        print("\n❌ Aucun format de connexion n'a fonctionné")
        print("💡 Vérifiez:")
        print("   1. Le mot de passe Supabase")
        print("   2. L'URL du projet Supabase")
        print("   3. La connexion internet")
