#!/usr/bin/env python3
"""
Script pour tester que les prix sont correctement envoyés
"""

import os
import requests
import json
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

def test_recent_feedback():
    """Teste les derniers feedbacks pour vérifier les prix"""
    print("🧪 TEST DES PRIX DANS TRADE_FEEDBACK")
    print("=" * 50)
    
    try:
        url = f"{SUPABASE_URL}/rest/v1/trade_feedback"
        headers = {
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}'
        }
        
        # Récupérer les 5 derniers enregistrements
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
            print(f"📊 {len(records)} derniers enregistrements:")
            
            all_prices_ok = True
            for i, record in enumerate(records):
                entry_price = record.get('entry_price', 0)
                exit_price = record.get('exit_price', 0)
                profit = record.get('profit', 0)
                symbol = record.get('symbol', 'N/A')
                created = record.get('created_at', 'N/A')
                
                # Vérifier si les prix sont valides
                entry_ok = entry_price != 0 and entry_price is not None
                exit_ok = exit_price != 0 and exit_price is not None
                
                status = "✅" if entry_ok and exit_ok else "❌"
                print(f"\n{status} Enregistrement #{i+1}:")
                print(f"  Symbol: {symbol}")
                print(f"  Entry Price: {entry_price}")
                print(f"  Exit Price: {exit_price}")
                print(f"  Profit: {profit}")
                print(f"  Created: {created}")
                
                if not entry_ok or not exit_ok:
                    all_prices_ok = False
            
            print(f"\n🎯 RÉSULTAT: {'✅ Tous les prix sont corrects' if all_prices_ok else '❌ Certains prix sont encore à 0'}")
            
        else:
            print(f"❌ Erreur: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Erreur: {e}")

def simulate_feedback():
    """Simule l'envoi d'un feedback avec des prix"""
    print("\n🔄 SIMULATION D'ENVOI DE FEEDBACK")
    print("=" * 40)
    
    try:
        url = f"{SUPABASE_URL}/rest/v1/trade_feedback"
        headers = {
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}',
            'Content-Type': 'application/json'
        }
        
        # Données de test
        test_data = {
            "symbol": "Boom 500 Index",
            "timeframe": "M1",
            "profit": -1.25,
            "is_win": False,
            "ai_confidence": 0.75,
            "side": "SELL",
            "open_time": datetime.now().isoformat(),
            "close_time": datetime.now().isoformat(),
            "entry_price": 500.1234,
            "exit_price": 501.3734
        }
        
        response = requests.post(url, headers=headers, json=test_data)
        
        if response.status_code in (200, 201):
            print("✅ Feedback de test envoyé avec succès")
            print(f"  Entry: {test_data['entry_price']}")
            print(f"  Exit: {test_data['exit_price']}")
            print(f"  Profit: {test_data['profit']}")
        else:
            print(f"❌ Erreur envoi: {response.status_code}")
            print(f"Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Erreur simulation: {e}")

if __name__ == "__main__":
    test_recent_feedback()
    simulate_feedback()
    
    print("\n" + "=" * 60)
    print("📋 INSTRUCTIONS:")
    print("1. Compilez SMC_Universal.mq5 avec les corrections")
    print("2. Lancez le robot sur MT5")
    print("3. Faites quelques trades pour tester")
    print("4. Vérifiez les logs MT5 pour les messages '📤 ENVOI FEEDBACK IA'")
    print("5. Relancez ce script pour vérifier les nouveaux enregistrements")
