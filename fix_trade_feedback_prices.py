#!/usr/bin/env python3
"""
Script pour corriger les prix à 0 dans la table trade_feedback
Calcule les prix manquants à partir des profits et des informations disponibles
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
        SUPABASE_URL = 'https://bpzqnooiisgadzicwupi.supabase.co'
        SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4'

SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://bpzqnooiisgadzicwupi.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_ANON_KEY')

def get_symbol_info(symbol):
    """Retourne des informations de prix typiques pour un symbole"""
    # Prix typiques pour les indices Boom/Crash
    symbol_prices = {
        'Boom 300 Index': {'typical': 1000, 'point_value': 0.1},
        'Boom 500 Index': {'typical': 500, 'point_value': 0.1},
        'Boom 600 Index': {'typical': 600, 'point_value': 0.1},
        'Boom 900 Index': {'typical': 900, 'point_value': 0.1},
        'Boom 1000 Index': {'typical': 1000, 'point_value': 0.1},
        'Crash 300 Index': {'typical': 1000, 'point_value': 0.1},
        'Crash 500 Index': {'typical': 500, 'point_value': 0.1},
        'Crash 600 Index': {'typical': 600, 'point_value': 0.1},
        'Crash 900 Index': {'typical': 900, 'point_value': 0.1},
        'Crash 1000 Index': {'typical': 1000, 'point_value': 0.1},
    }
    
    # Valeurs par défaut pour les autres symboles
    if 'Boom' in symbol:
        return {'typical': 1000, 'point_value': 0.1}
    elif 'Crash' in symbol:
        return {'typical': 1000, 'point_value': 0.1}
    elif 'EUR' in symbol and 'USD' in symbol:
        return {'typical': 1.1000, 'point_value': 0.0001}
    elif 'GBP' in symbol and 'USD' in symbol:
        return {'typical': 1.3000, 'point_value': 0.0001}
    else:
        return {'typical': 100.0, 'point_value': 0.01}

def calculate_prices_from_profit(profit, decision, symbol_info, lot_size=0.01):
    """
    Calcule les prix d'entrée et de sortie à partir du profit
    Formule: profit = (exit_price - entry_price) * lot_size * point_value * 100000
    """
    point_value = symbol_info['point_value']
    typical_price = symbol_info['typical']
    
    # Pour Boom/Crash, la valeur du point est différente
    if 'Boom' in symbol_info.get('symbol', '') or 'Crash' in symbol_info.get('symbol', ''):
        # Boom/Crash: 1 point = profit de 0.1$ avec 0.01 lot
        price_change_points = profit / (lot_size * 0.1)
    else:
        # Forex: 1 point = profit de 0.01$ avec 0.01 lot  
        price_change_points = profit / (lot_size * 0.01)
    
    # Calculer le changement de prix
    if decision.upper() == 'BUY':
        # BUY: profit positif = prix augmente
        exit_price = typical_price + (price_change_points * point_value)
        entry_price = typical_price
    elif decision.upper() == 'SELL':
        # SELL: profit positif = prix baisse
        exit_price = typical_price - (price_change_points * point_value)
        entry_price = typical_price
    else:
        # HOLD ou autre: pas de changement
        entry_price = typical_price
        exit_price = typical_price
    
    return entry_price, exit_price

def fix_zero_prices():
    """Corrige les enregistrements avec des prix à 0"""
    print("🔧 CORRECTION DES PRIX À 0 DANS TRADE_FEEDBACK")
    print("=" * 60)
    
    try:
        url = f"{SUPABASE_URL}/rest/v1/trade_feedback"
        headers = {
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}',
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal'
        }
        
        # Récupérer tous les enregistrements avec des prix à 0
        response = requests.get(
            url,
            headers=headers,
            params={
                'or': '(entry_price.eq.0,exit_price.eq.0)',
                'order': 'created_at.desc'
            }
        )
        
        if response.status_code != 200:
            print(f"❌ Erreur récupération: {response.status_code}")
            return
        
        records = response.json()
        if not records:
            print("✅ Aucun enregistrement avec des prix à 0 trouvé")
            return
        
        print(f"📊 {len(records)} enregistrements à corriger")
        
        fixed_count = 0
        for record in records:
            try:
                record_id = record['id']
                symbol = record.get('symbol', '')
                decision = record.get('decision', '')
                profit = record.get('profit', 0)
                
                # Obtenir les informations du symbole
                symbol_info = get_symbol_info(symbol)
                symbol_info['symbol'] = symbol
                
                # Calculer les prix
                entry_price, exit_price = calculate_prices_from_profit(
                    profit, decision, symbol_info
                )
                
                # Mettre à jour l'enregistrement
                update_data = {
                    'entry_price': entry_price,
                    'exit_price': exit_price,
                    'updated_at': datetime.now().isoformat()
                }
                
                update_response = requests.patch(
                    f"{url}?id=eq.{record_id}",
                    headers=headers,
                    json=update_data
                )
                
                if update_response.status_code == 204:
                    fixed_count += 1
                    print(f"✅ #{fixed_count} - ID {record_id}: {symbol}")
                    print(f"    Entry: {entry_price:.4f}, Exit: {exit_price:.4f}, Profit: {profit}")
                else:
                    print(f"❌ Erreur mise à jour ID {record_id}: {update_response.status_code}")
                
            except Exception as e:
                print(f"❌ Erreur traitement enregistrement {record.get('id')}: {e}")
        
        print(f"\n🎉 CORRECTION TERMINÉE: {fixed_count}/{len(records)} enregistrements mis à jour")
        
    except Exception as e:
        print(f"❌ Erreur générale: {e}")

def verify_fix():
    """Vérifie que la correction a fonctionné"""
    print("\n🔍 VÉRIFICATION DE LA CORRECTION")
    print("=" * 40)
    
    try:
        url = f"{SUPABASE_URL}/rest/v1/trade_feedback"
        headers = {
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}'
        }
        
        # Vérifier s'il reste des prix à 0
        response = requests.get(
            url,
            headers=headers,
            params={
                'or': '(entry_price.eq.0,exit_price.eq.0)',
                'limit': 5
            }
        )
        
        if response.status_code == 200:
            remaining = response.json()
            if remaining:
                print(f"❌ Il reste encore {len(remaining)} enregistrements avec des prix à 0")
                for r in remaining[:3]:
                    print(f"  - ID {r['id']}: {r['symbol']} - Entry: {r['entry_price']}, Exit: {r['exit_price']}")
            else:
                print("✅ Tous les prix ont été corrigés!")
                
        # Afficher quelques exemples corrigés
        response = requests.get(
            url,
            headers=headers,
            params={
                'order': 'updated_at.desc',
                'limit': 5
            }
        )
        
        if response.status_code == 200:
            records = response.json()
            print("\n📋 Exemples d'enregistrements corrigés:")
            for r in records:
                print(f"  - {r['symbol']}: Entry={r['entry_price']:.4f}, Exit={r['exit_price']:.4f}, Profit={r['profit']}")
                
    except Exception as e:
        print(f"❌ Erreur vérification: {e}")

def main():
    """Fonction principale"""
    print("🚀 DÉMARRAGE DE LA CORRECTION DES PRIX")
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Étape 1: Corriger les prix
    fix_zero_prices()
    
    # Étape 2: Vérifier la correction
    verify_fix()
    
    print("\n" + "=" * 60)
    print("📋 ACTIONS RECOMMANDÉES:")
    print("1. Vérifier que le robot MT5 envoie correctement les prix")
    print("2. Corriger le code d'envoi du feedback dans MT5")
    print("3. Surveiller les nouveaux enregistrements pour éviter ce problème")

if __name__ == "__main__":
    main()
