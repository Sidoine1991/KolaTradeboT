#!/usr/bin/env python3
"""
Script de diagnostic pour vérifier:
1. L'état des tables Supabase
2. Les données dans correction_summary vs autres tables
3. Générer un rapport de l'état actuel
"""

import os
import sys
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv()

def get_supabase_client() -> Client:
    """Créer et retourner le client Supabase"""
    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_ANON_KEY')
    
    if not url or not key:
        print("❌ ERREUR: Variables d'environnement Supabase manquantes")
        print("   Vérifiez SUPABASE_URL et SUPABASE_ANON_KEY dans .env")
        return None
    
    try:
        client = create_client(url, key)
        print("✅ Client Supabase créé avec succès")
        return client
    except Exception as e:
        print(f"❌ ERREUR de connexion Supabase: {e}")
        return None

def check_table_exists(client: Client, table_name: str) -> bool:
    """Vérifier si une table existe"""
    try:
        response = client.table(table_name).select("count", count="exact").execute()
        print(f"✅ Table '{table_name}' existe")
        return True
    except Exception as e:
        print(f"❌ Table '{table_name}' inaccessible: {e}")
        return False

def get_table_count(client: Client, table_name: str) -> int:
    """Compter les enregistrements dans une table"""
    try:
        response = client.table(table_name).select("id", count="exact").execute()
        return response.count if response else 0
    except Exception as e:
        print(f"❌ Erreur comptage {table_name}: {e}")
        return 0

def get_table_sample(client: Client, table_name: str, limit: int = 3):
    """Obtenir un échantillon de données d'une table"""
    try:
        response = client.table(table_name).select("*").limit(limit).execute()
        return response.data if response else []
    except Exception as e:
        print(f"❌ Erreur échantillon {table_name}: {e}")
        return []

def check_correction_summary(client: Client):
    """Vérifier spécifiquement la vue correction_summary"""
    print("\n" + "="*60)
    print("🔍 DIAGNOSTIC DE correction_summary")
    print("="*60)
    
    try:
        # Essayer de lire la vue
        response = client.rpc('get_correction_summary_data').execute()
        if response.data:
            print(f"✅ Vue correction_summary accessible: {len(response.data)} enregistrements")
            for record in response.data:
                print(f"   📊 {record}")
        else:
            print("⚠️ Vue correction_summary vide")
    except Exception as e:
        print(f"❌ Erreur accès vue correction_summary: {e}")
        
        # Essayer une requête directe sur la table sous-jacente
        try:
            response = client.table('correction_zones_analysis').select("symbol, COUNT(*) as count").execute()
            if response.data:
                print(f"✅ Table correction_zones_analysis accessible: {len(response.data)} enregistrements")
                for record in response.data:
                    print(f"   📊 {record}")
        except Exception as e2:
            print(f"❌ Erreur table correction_zones_analysis: {e2}")

def main():
    print("🚀 DÉMARRAGE DU DIAGNOSTIC SUPABASE")
    print(f"📅 Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    # Connexion Supabase
    client = get_supabase_client()
    if not client:
        sys.exit(1)
    
    # Tables à vérifier
    tables_to_check = [
        'correction_zones_analysis',
        'correction_predictions', 
        'prediction_performance',
        'symbol_correction_patterns',
        'ml_training_data',
        'model_metrics',
        'ai_predictions'
    ]
    
    print("\n📋 VÉRIFICATION DES TABLES")
    print("="*40)
    
    existing_tables = []
    for table in tables_to_check:
        if check_table_exists(client, table):
            existing_tables.append(table)
    
    print(f"\n📊 RÉSUMÉ: {len(existing_tables)}/{len(tables_to_check)} tables accessibles")
    
    # Compter les enregistrements
    print("\n📈 NOMBRE D'ENREGISTREMENTS PAR TABLE")
    print("="*45)
    
    for table in existing_tables:
        count = get_table_count(client, table)
        print(f"   {table}: {count} enregistrements")
    
    # Vérifier correction_summary spécifiquement
    check_correction_summary(client)
    
    # Échantillons de données
    print("\n🔍 ÉCHANTILLONS DE DONNÉES")
    print("="*40)
    
    for table in existing_tables[:3]:  # Limiter aux 3 premières tables
        sample = get_table_sample(client, table, 2)
        if sample:
            print(f"\n📋 {table} (échantillon):")
            for i, record in enumerate(sample, 1):
                print(f"   {i}. {record}")
    
    print("\n✅ DIAGNOSTIC TERMINÉ")
    print("\n💡 RECOMMANDATIONS:")
    print("   1. Si correction_summary est vide: insérer des données d'analyse")
    print("   2. Si les tables sont vides: exécuter le script de migration")
    print("   3. Vérifier les permissions RLS si accès refusé")

if __name__ == "__main__":
    main()
