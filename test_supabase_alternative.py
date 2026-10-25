#!/usr/bin/env python3
"""
Script de test de connexion à Supabase avec formats alternatifs
"""

import asyncio
import asyncpg
import socket
import os

async def test_dns_resolution():
    """Test DNS resolution for Supabase hosts"""
    hosts_to_test = [
        "aws-0-eu-central-1.pooler.supabase.com",
        "pooler.supabase.com",
        "supabase.com"
    ]
    
    print("🔍 Test de résolution DNS:")
    for host in hosts_to_test:
        try:
            ip = socket.gethostbyname(host)
            print(f"✅ {host} → {ip}")
        except Exception as e:
            print(f"❌ {host} → {e}")

async def test_supabase_alternative():
    """Test alternative connection methods"""
    
    password = "Socrate2025@1991"
    
    # Essayer avec SSL mode require
    urls_to_test = [
        f"postgresql://postgres:{password}@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require",
        f"postgresql://postgres:{password}@db.bpzqnooiisgadzicwupi.supabase.co:5432/postgres?sslmode=require",
        f"postgresql://postgres:{password}@aws-0-eu-central-1.pooler.supabase.com/postgres?sslmode=require",
    ]
    
    for i, url in enumerate(urls_to_test, 1):
        print(f"\n🔍 Test alternatif {i}: {url[:60]}...")
        try:
            conn = await asyncpg.connect(url)
            print(f"✅ Connexion réussie avec le format alternatif {i}!")
            
            # Test simple query
            result = await conn.fetchval("SELECT version()")
            print(f"📊 Version PostgreSQL: {result[:50]}...")
            
            await conn.close()
            return url
            
        except Exception as e:
            print(f"❌ Échec alternatif {i}: {e}")
    
    return None

async def test_with_psycopg2():
    """Test with psycopg2 as fallback"""
    try:
        import psycopg2
        print("\n🔄 Test avec psycopg2...")
        
        password = "Socrate2025@1991"
        conn_string = f"postgresql://postgres:{password}@aws-0-eu-central-1.pooler.supabase.com:5432/postgres"
        
        conn = psycopg2.connect(conn_string)
        print("✅ Connexion réussie avec psycopg2!")
        
        cursor = conn.cursor()
        cursor.execute("SELECT version()")
        result = cursor.fetchone()[0]
        print(f"📊 Version PostgreSQL: {result[:50]}...")
        
        conn.close()
        return True
        
    except ImportError:
        print("❌ psycopg2 non installé")
        return False
    except Exception as e:
        print(f"❌ Échec psycopg2: {e}")
        return False

if __name__ == "__main__":
    print("🧪 TEST DE CONNEXION SUPABASE - ALTERNATIVES")
    print("=" * 60)
    
    # Test DNS resolution
    asyncio.run(test_dns_resolution())
    
    # Test alternative connections
    result = asyncio.run(test_supabase_alternative())
    
    if not result:
        # Try psycopg2
        result = test_with_psycopg2()
    
    if result:
        print(f"\n✅ Connexion réussie!")
    else:
        print("\n❌ Toutes les tentatives de connexion ont échoué")
        print("💡 Solutions possibles:")
        print("   1. Vérifier le mot de passe dans le dashboard Supabase")
        print("   2. Vérifier que la base de données est active")
        print("   3. Essayer de se connecter via un client SQL externe")
        print("   4. Vérifier les paramètres réseau/firewall")
