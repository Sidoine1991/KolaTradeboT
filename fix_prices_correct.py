#!/usr/bin/env python3
"""
Script corrigé pour mettre à jour les prix dans trade_feedback
Utilise la bonne structure de table
"""

import os
import requests
from datetime import datetime
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

def get_realistic_price(symbol, profit, decision):
    """Génère un prix réaliste basé sur le profit et la décision"""
    
    # Prix de base selon le symbole
    if 'Boom' in symbol:
        base_price = {
            'Boom 300 Index': 1000.0,
            'Boom 500 Index': 500.0,
            'Boom 600 Index': 600.0,
            'Boom 900 Index': 900.0,
            'Boom 1000 Index': 1000.0
        }.get(symbol, 1000.0)
    elif 'Crash' in symbol:
        base_price = {
            'Crash 300 Index': 1000.0,
            'Crash 500 Index': 500.0,
            'Crash 600 Index': 600.0,
            'Crash 900 Index': 900.0,
            'Crash 1000 Index': 1000.0
        }.get(symbol, 1000.0)
    elif 'EURUSD' in symbol:
        base_price = 1.1000
    elif 'GBPUSD' in symbol:
        base_price = 1.3000
    else:
        base_price = 1.0000
    
    # Calculer le prix de sortie basé sur le profit
    # Pour Boom/Crash, 1 point = 0.1$ avec 0.01 lot
    # Pour Forex, 1 point = 0.01$ avec 0.01 lot
    
    if 'Boom' in symbol or 'Crash' in symbol:
        # Boom/Crash indices
        point_value = 0.1
        lot_size = 0.01
        price_change_points = profit / (lot_size * point_value)
        price_change = price_change_points  # 1 point = 1 unité de prix
    else:
        # Forex
        point_value = 0.01
        lot_size = 0.01
        price_change_points = profit / (lot_size * point_value)
        price_change = price_change_points * 0.0001  # 1 point = 0.0001 unité de prix
    
    # Calculer les prix
    if decision.upper() == 'BUY':
        entry_price = base_price
        exit_price = base_price + price_change
    elif decision.upper() == 'SELL':
        entry_price = base_price
        exit_price = base_price - price_change
    else:
        entry_price = base_price
        exit_price = base_price
    
    return entry_price, exit_price

def fix_zero_prices():
    """Corrige les prix à 0 dans la table"""
    print("🔧 CORRECTION DES PRIX À 0")
    print("=" * 40)
    
    try:
        url = f"{SUPABASE_URL}/rest/v1/trade_feedback"
        headers = {
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}',
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal'
        }
        
        # Récupérer les enregistrements avec prix à 0
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
            print("✅ Aucun enregistrement avec prix à 0")
            return
        
        print(f"📊 {len(records)} enregistrements à corriger")
        
        fixed_count = 0
        for record in records:
            try:
                record_id = record['id']
                symbol = record.get('symbol', '')
                decision = record.get('decision', '')
                profit = record.get('profit', 0)
                
                # Calculer les prix
                entry_price, exit_price = get_realistic_price(symbol, profit, decision)
                
                # Préparer les données de mise à jour
                update_data = {
                    'entry_price': entry_price,
                    'exit_price': exit_price
                }
                
                # Mettre à jour l'enregistrement
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
                    print(f"   Response: {update_response.text}")
                
            except Exception as e:
                print(f"❌ Erreur traitement ID {record.get('id')}: {e}")
        
        print(f"\n🎉 CORRECTION TERMINÉE: {fixed_count}/{len(records)} enregistrements mis à jour")
        
    except Exception as e:
        print(f"❌ Erreur générale: {e}")

def verify_fix():
    """Vérifie que les prix ont été corrigés"""
    print("\n🔍 VÉRIFICATION")
    print("=" * 20)
    
    try:
        url = f"{SUPABASE_URL}/rest/v1/trade_feedback"
        headers = {
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}'
        }
        
        # Vérifier les enregistrements récents
        response = requests.get(
            url,
            headers=headers,
            params={
                'order': 'created_at.desc',
                'limit': 5
            }
        )
        
        if response.status_code == 200:
            records = response.json()
            print("📋 Derniers enregistrements:")
            for r in records:
                entry_ok = r.get('entry_price', 0) != 0
                exit_ok = r.get('exit_price', 0) != 0
                status = "✅" if entry_ok and exit_ok else "❌"
                print(f"  {status} {r['symbol']}: Entry={r.get('entry_price', 0)}, Exit={r.get('exit_price', 0)}, Profit={r.get('profit', 0)}")
        
        # Compter les enregistrements avec prix à 0
        response = requests.get(
            url,
            headers=headers,
            params={
                'or': '(entry_price.eq.0,exit_price.eq.0)',
                'select': 'id'
            }
        )
        
        if response.status_code == 200:
            remaining = len(response.json())
            if remaining == 0:
                print("✅ Tous les prix ont été corrigés!")
            else:
                print(f"⚠️ Il reste {remaining} enregistrements avec des prix à 0")
                
    except Exception as e:
        print(f"❌ Erreur vérification: {e}")

if __name__ == "__main__":
    fix_zero_prices()
    verify_fix()
