#!/usr/bin/env python3
"""
Script de diagnostic pour vérifier les données dans les tables Supabase
Vérifie spécifiquement les prix à 0 dans trades et trade_feedback
"""

import os
import sys
import requests
import json
from datetime import datetime
from dotenv import load_dotenv

# Charger les variables d'environnement
try:
    load_dotenv('.env.supabase', encoding='utf-8')
except UnicodeDecodeError:
    try:
        load_dotenv('.env.supabase', encoding='cp1252')
    except Exception as e:
        print(f"⚠️ Erreur lecture .env.supabase: {e}")
        # Utiliser les valeurs par défaut
        global SUPABASE_URL, SUPABASE_KEY
        SUPABASE_URL = 'https://bpzqnooiisgadzicwupi.supabase.co'
        SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4'

SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://bpzqnooiisgadzicwupi.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_ANON_KEY')

def check_table_data(table_name, limit=10):
    """Vérifie les données dans une table spécifique"""
    print(f"\n🔍 DIAGNOSTIC TABLE: {table_name}")
    print("=" * 60)
    
    try:
        # Récupérer les données
        url = f"{SUPABASE_URL}/rest/v1/{table_name}"
        headers = {
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}',
            'Content-Type': 'application/json'
        }
        
        # Compter le total d'enregistrements
        count_response = requests.get(
            f"{url}?select=id", 
            headers=headers,
            params={'limit': 1}
        )
        
        if count_response.status_code == 200:
            total_count = len(count_response.json()) if count_response.text else 0
            print(f"📊 Total enregistrements: {total_count}")
        else:
            print(f"❌ Erreur comptage: {count_response.status_code}")
            return
        
        # Récupérer les derniers enregistrements
        params = {
            'order': 'created_at.desc',
            'limit': limit
        }
        
        response = requests.get(url, headers=headers, params=params)
        
        if response.status_code == 200:
            data = response.json()
            if not data:
                print("⚠️ Aucune donnée trouvée")
                return
            
            print(f"📋 {len(data)} derniers enregistrements:")
            
            # Analyser chaque enregistrement
            zero_price_issues = []
            for i, record in enumerate(data):
                print(f"\n--- Enregistrement #{i+1} ---")
                
                # Vérifier les champs de prix
                price_fields = ['entry_price', 'exit_price', 'profit', 'lot_size', 'stop_loss', 'take_profit']
                zero_prices = []
                
                for field in price_fields:
                    if field in record:
                        value = record[field]
                        if value == 0 or value == 0.0:
                            zero_prices.append(field)
                        print(f"  {field}: {value}")
                
                # Autres champs importants
                other_fields = ['symbol', 'decision', 'is_win', 'created_at', 'status']
                for field in other_fields:
                    if field in record:
                        print(f"  {field}: {record[field]}")
                
                if zero_prices:
                    zero_price_issues.append({
                        'id': record.get('id'),
                        'zero_fields': zero_prices,
                        'record': record
                    })
            
            # Résumé des problèmes
            if zero_price_issues:
                print(f"\n❌ PROBLÈMES TROUVÉS: {len(zero_price_issues)} enregistrements avec des prix à 0")
                for issue in zero_price_issues:
                    print(f"  - ID {issue['id']}: Champs à 0 -> {issue['zero_fields']}")
            else:
                print(f"\n✅ Aucun problème de prix à 0 trouvé dans les {len(data)} derniers enregistrements")
                
        else:
            print(f"❌ Erreur récupération données: {response.status_code}")
            print(f"Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Erreur: {e}")

def check_trade_feedback_specific():
    """Vérification spécifique de la table trade_feedback"""
    print(f"\n🔍 DIAGNOSTIC SPÉCIFIQUE: trade_feedback")
    print("=" * 60)
    
    try:
        url = f"{SUPABASE_URL}/rest/v1/trade_feedback"
        headers = {
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}',
            'Content-Type': 'application/json'
        }
        
        # Requête pour trouver les prix à 0
        response = requests.get(
            url,
            headers=headers,
            params={
                'or': '(entry_price.eq.0,exit_price.eq.0,profit.eq.0)',
                'order': 'created_at.desc',
                'limit': 20
            }
        )
        
        if response.status_code == 200:
            data = response.json()
            if data:
                print(f"❌ TROUVÉ {len(data)} enregistrements avec des prix à 0:")
                for i, record in enumerate(data):
                    print(f"\n--- Problème #{i+1} ---")
                    print(f"  ID: {record.get('id')}")
                    print(f"  Symbol: {record.get('symbol')}")
                    print(f"  Entry Price: {record.get('entry_price')}")
                    print(f"  Exit Price: {record.get('exit_price')}")
                    print(f"  Profit: {record.get('profit')}")
                    print(f"  Decision: {record.get('decision')}")
                    print(f"  Is Win: {record.get('is_win')}")
                    print(f"  Created: {record.get('created_at')}")
            else:
                print("✅ Aucun enregistrement avec des prix à 0 trouvé")
        else:
            print(f"❌ Erreur recherche prix à 0: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Erreur: {e}")

def main():
    """Fonction principale"""
    print("🔍 DIAGNOSTIC DES DONNÉES SUPABASE")
    print("Vérification des prix à 0 dans trades et trade_feedback")
    print("=" * 80)
    print(f"URL: {SUPABASE_URL}")
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Vérifier les deux tables
    check_table_data('trades', limit=10)
    check_table_data('trade_feedback', limit=10)
    
    # Diagnostic spécifique
    check_trade_feedback_specific()
    
    print("\n" + "=" * 80)
    print("📋 RECOMMANDATIONS:")
    print("1. Si des prix à 0 sont trouvés, vérifier le code d'envoi des données")
    print("2. Assurer que les prix sont correctement extraits de MT5")
    print("3. Vérifier la conversion des types de données")
    print("4. Nettoyer les enregistrements invalides si nécessaire")

if __name__ == "__main__":
    main()
