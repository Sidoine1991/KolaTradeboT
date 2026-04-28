#!/usr/bin/env python3
"""
Script pour vérifier la structure de la table trade_feedback
"""

import os
import requests
from dotenv import load_dotenv

try:
    load_dotenv('.env.supabase', encoding='utf-8')
except UnicodeDecodeError:
    try:
        load_dotenv('.env.supabase', encoding='cp1252')
    except Exception:
        pass

SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://bpzqnooiisgadzicwupi.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_ANON_KEY')

def check_table_structure():
    """Vérifie la structure de la table trade_feedback"""
    print("🔍 VÉRIFICATION STRUCTURE TABLE trade_feedback")
    print("=" * 50)
    
    try:
        # Récupérer un enregistrement pour voir la structure
        url = f"{SUPABASE_URL}/rest/v1/trade_feedback"
        headers = {
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}'
        }
        
        response = requests.get(url, headers=headers, params={'limit': 1})
        
        if response.status_code == 200:
            data = response.json()
            if data:
                record = data[0]
                print("📋 Structure de l'enregistrement:")
                for key, value in record.items():
                    print(f"  {key}: {value} ({type(value).__name__})")
            else:
                print("⚠️ Aucun enregistrement trouvé")
        else:
            print(f"❌ Erreur: {response.status_code}")
            print(f"Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Erreur: {e}")

if __name__ == "__main__":
    check_table_structure()
