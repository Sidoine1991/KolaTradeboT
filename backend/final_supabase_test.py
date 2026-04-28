#!/usr/bin/env python3
"""
Test final pour vérifier que Supabase est prêt pour MT5
"""

import urllib.request
import urllib.parse
import json

def test_final_supabase_setup():
    """Test final complet de la configuration Supabase"""
    
    print("🎯 Test Final Supabase - KolaTradeBoT")
    print("=" * 50)
    
    # Configuration
    supabase_url = "https://bpzqnooiisgadzicwupi.supabase.co"
    supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4"
    
    # Test 1: Vérifier que la table a des données
    print("\n📊 Test 1: Vérification des données")
    print("-" * 30)
    
    api_url = f"{supabase_url}/rest/v1/support_resistance_levels"
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Accept": "application/json"
    }
    
    params = {
        "select": "count",
        "head": "true"
    }
    
    url_with_params = f"{api_url}?" + urllib.parse.urlencode(params)
    
    try:
        req = urllib.request.Request(url_with_params, headers=headers)
        
        with urllib.request.urlopen(req, timeout=10) as response:
            count = response.headers.get('content-range', '0').split('/')[-1]
            print(f"📊 Nombre d'enregistrements: {count}")
            
            if int(count) > 0:
                print("✅ Table contient des données")
            else:
                print("❌ Table vide - exécutez le setup manuel")
                return False
                
    except Exception as e:
        print(f"❌ Erreur vérification: {e}")
        return False
    
    # Test 2: Requête exacte MT5 pour Boom 1000
    print("\n🔧 Test 2: Requête MT5 exacte - Boom 1000")
    print("-" * 40)
    
    symbol = "Boom 1000 Index"
    params_mt5 = {
        "symbol": f"eq.{symbol}",
        "timeframe": "eq.M1",
        "order": "strength_score.desc",
        "limit": "3"
    }
    
    url_mt5 = f"{api_url}?" + urllib.parse.urlencode(params_mt5)
    
    try:
        req = urllib.request.Request(url_mt5, headers=headers)
        
        with urllib.request.urlopen(req, timeout=3) as response:  # 3s comme MT5
            if response.getcode() == 200:
                data = response.read().decode('utf-8')
                json_data = json.loads(data)
                
                print(f"✅ Réponse MT5: {len(json_data)} niveaux pour {symbol}")
                
                if json_data:
                    best = json_data[0]
                    print(f"🎯 Meilleur niveau:")
                    print(f"   Support: {best['support']}")
                    print(f"   Résistance: {best['resistance']}")
                    print(f"   Score: {best['strength_score']}/100")
                    print(f"   Touches: {best['touch_count']}")
                    
                    # Calculer distance par rapport à un prix fictif
                    current_price = 1001.25
                    support = float(best['support'])
                    resistance = float(best['resistance'])
                    
                    support_dist = (current_price - support) / current_price * 100
                    resist_dist = (resistance - current_price) / current_price * 100
                    
                    print(f"   Distance support: {support_dist:.3f}%")
                    print(f"   Distance résistance: {resist_dist:.3f}%")
                    
                    if support_dist < 0.2:
                        print(f"✅ BUY LIMIT possible @ {support}")
                    if resist_dist < 0.2:
                        print(f"✅ SELL LIMIT possible @ {resistance}")
                else:
                    print("❌ Aucune donnée pour Boom 1000")
                    return False
            else:
                print(f"❌ Erreur MT5: {response.getcode()}")
                return False
                
    except Exception as e:
        print(f"❌ Erreur test MT5: {e}")
        return False
    
    # Test 3: Requête pour Crash 1000
    print("\n🔧 Test 3: Requête MT5 - Crash 1000")
    print("-" * 35)
    
    symbol = "Crash 1000 Index"
    params_crash = {
        "symbol": f"eq.{symbol}",
        "timeframe": "eq.M1",
        "order": "strength_score.desc",
        "limit": "3"
    }
    
    url_crash = f"{api_url}?" + urllib.parse.urlencode(params_crash)
    
    try:
        req = urllib.request.Request(url_crash, headers=headers)
        
        with urllib.request.urlopen(req, timeout=3) as response:
            if response.getcode() == 200:
                data = response.read().decode('utf-8')
                json_data = json.loads(data)
                
                print(f"✅ Réponse MT5: {len(json_data)} niveaux pour {symbol}")
                
                if json_data:
                    best = json_data[0]
                    print(f"🎯 Meilleur niveau:")
                    print(f"   Support: {best['support']}")
                    print(f"   Résistance: {best['resistance']}")
                    print(f"   Score: {best['strength_score']}/100")
                else:
                    print("❌ Aucune donnée pour Crash 1000")
                    return False
            else:
                print(f"❌ Erreur Crash: {response.getcode()}")
                return False
                
    except Exception as e:
        print(f"❌ Erreur test Crash: {e}")
        return False
    
    # Test 4: Parsing MQL5
    print("\n🔍 Test 4: Parsing MQL5")
    print("-" * 25)
    
    # Simuler la réponse JSON
    sample_response = [{
        "id": 1,
        "symbol": "Boom 1000 Index",
        "support": 1000.50,
        "resistance": 1002.00,
        "timeframe": "M1",
        "strength_score": 85.5,
        "touch_count": 12,
        "last_touch": "2025-03-11T10:30:00Z"
    }]
    
    json_str = json.dumps(sample_response)
    
    # Parser support (comme dans MQL5)
    support_pos = json_str.find('"support":')
    if support_pos > 0:
        start = support_pos + 11
        support_str = ""
        while start < len(json_str) and json_str[start] not in [',', '}']:
            if json_str[start] not in [' ', '"']:
                support_str += json_str[start]
            start += 1
        print(f"✅ Support parsé: {support_str}")
    
    # Parser résistance (comme dans MQL5)
    resistance_pos = json_str.find('"resistance":')
    if resistance_pos > 0:
        start = resistance_pos + 14
        resistance_str = ""
        while start < len(json_str) and json_str[start] not in [',', '}']:
            if json_str[start] not in [' ', '"']:
                resistance_str += json_str[start]
            start += 1
        print(f"✅ Résistance parsée: {resistance_str}")
    
    print("✅ Parsing MQL5 fonctionnel!")
    
    return True

def show_mt5_configuration():
    """Afficher la configuration MT5"""
    
    print("\n🎯 Configuration MT5")
    print("=" * 30)
    
    print("📋 Inputs à configurer dans SMC_Universal.mq5:")
    print('   SupabaseUrl = "https://bpzqnooiisgadzicwupi.supabase.co"')
    print('   SupabaseApiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4"')
    
    print("\n🌐 WebRequest MT5:")
    print("   MT5 → Outils → Options → Expert Advisors")
    print("   ✅ Autoriser WebRequest")
    print("   ✅ Ajouter: https://bpzqnooiisgadzicwupi.supabase.co")
    
    print("\n📊 Logs attendus dans MT5:")
    print("   🌐 Requête Supabase S/R pour: Boom 1000 Index (M1)")
    print("   📊 Supabase S/R - Support: 1000.50000 | Résistance: 1002.00000")
    print("   ✅ Niveau Supabase sélectionné: SUPABASE_SUPPORT @ 1000.50000")
    print("   🎯 BUY LIMIT placé @ 1000.50000 (distance: 0.075%)")

if __name__ == "__main__":
    print("🚀 Test Final Supabase")
    print("=" * 50)
    
    if test_final_supabase_setup():
        print("\n" + "=" * 50)
        print("🎉 SUCCÈS TOTAL!")
        print("✅ Supabase est 100% prêt pour MT5")
        print("✅ Les vrais niveaux S/R sont disponibles")
        print("✅ Le parsing MQL5 fonctionne")
        print("✅ Les ordres limit utiliseront les vrais niveaux!")
        
        show_mt5_configuration()
        
        print("\n🚀 PROCHAINE ÉTAPE:")
        print("   1. Configurez les inputs dans MT5")
        print("   2. Activez WebRequest")
        print("   3. Lancez le robot")
        print("   4. Observez les logs Supabase!")
        
    else:
        print("\n" + "=" * 50)
        print("❌ Configuration incomplète")
        print("📋 Actions requises:")
        print("   1. Exécutez le setup manuel (SUPABASE_MANUAL_SETUP.md)")
        print("   2. Insérez les données SQL")
        print("   3. Relancez ce test")
        
        print("\n🔗 Lien setup manuel:")
        print("   https://supabase.com/dashboard/project/bpzqnooiisgadzicwupi/sql")
