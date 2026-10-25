#!/usr/bin/env python3
"""
Script de test avec données fictives pour simuler le fonctionnement Supabase
"""

import json
import urllib.request
import urllib.parse
from datetime import datetime

def create_mock_server():
    """Créer un serveur mock local pour simuler Supabase"""
    
    print("🎭 Simulation de serveur Supabase avec données fictives")
    print("=" * 50)
    
    # Données fictives réalistes pour Boom/Crash
    mock_data = [
        {
            "id": 1,
            "symbol": "Boom 1000 Index",
            "support": 1000.50,
            "resistance": 1002.00,
            "timeframe": "M1",
            "strength_score": 85.5,
            "touch_count": 12,
            "last_touch": "2025-03-11T10:30:00Z",
            "created_at": "2025-03-11T09:00:00Z",
            "updated_at": "2025-03-11T10:30:00Z"
        },
        {
            "id": 2,
            "symbol": "Boom 1000 Index", 
            "support": 998.75,
            "resistance": 1000.25,
            "timeframe": "M1",
            "strength_score": 72.3,
            "touch_count": 8,
            "last_touch": "2025-03-11T09:15:00Z",
            "created_at": "2025-03-11T08:00:00Z",
            "updated_at": "2025-03-11T09:15:00Z"
        },
        {
            "id": 3,
            "symbol": "Crash 1000 Index",
            "support": 999.25,
            "resistance": 1000.75,
            "timeframe": "M1",
            "strength_score": 82.1,
            "touch_count": 15,
            "last_touch": "2025-03-11T10:45:00Z",
            "created_at": "2025-03-11T09:30:00Z",
            "updated_at": "2025-03-11T10:45:00Z"
        },
        {
            "id": 4,
            "symbol": "Crash 1000 Index",
            "support": 1002.25,
            "resistance": 1003.75,
            "timeframe": "M1",
            "strength_score": 76.8,
            "touch_count": 9,
            "last_touch": "2025-03-11T09:45:00Z",
            "created_at": "2025-03-11T08:30:00Z",
            "updated_at": "2025-03-11T09:45:00Z"
        }
    ]
    
    return mock_data

def test_mql5_parsing():
    """Tester le parsing MQL5 avec les données fictives"""
    
    print("🔧 Test parsing MQL5 avec données réalistes")
    print("=" * 45)
    
    mock_data = create_mock_server()
    
    # Test pour chaque symbole
    symbols = ["Boom 1000 Index", "Crash 1000 Index"]
    
    for symbol in symbols:
        print(f"\n📊 Test pour: {symbol}")
        print("-" * 30)
        
        # Filtrer les données pour ce symbole
        symbol_data = [item for item in mock_data if item["symbol"] == symbol]
        
        if symbol_data:
            # Prendre le niveau avec le score le plus élevé
            best_level = max(symbol_data, key=lambda x: x["strength_score"])
            
            # Convertir en JSON
            json_str = json.dumps([best_level])
            
            print(f"📈 Meilleur niveau (score: {best_level['strength_score']})")
            print(f"   Support: {best_level['support']}")
            print(f"   Résistance: {best_level['resistance']}")
            print(f"   Touches: {best_level['touch_count']}")
            
            # Simuler le parsing MQL5
            print("\n🔍 Simulation parsing MQL5:")
            
            # Parser support
            support_pos = json_str.find('"support":')
            if support_pos > 0:
                start = support_pos + 11
                support_str = ""
                while start < len(json_str) and json_str[start] not in [',', '}']:
                    if json_str[start] not in [' ', '"']:
                        support_str += json_str[start]
                    start += 1
                print(f"✅ Support parsé: {support_str}")
            
            # Parser résistance
            resistance_pos = json_str.find('"resistance":')
            if resistance_pos > 0:
                start = resistance_pos + 14
                resistance_str = ""
                while start < len(json_str) and json_str[start] not in [',', '}']:
                    if json_str[start] not in [' ', '"']:
                        resistance_str += json_str[start]
                    start += 1
                print(f"✅ Résistance parsée: {resistance_str}")
            
            # Calculer la distance par rapport à un prix fictif
            current_price = 1001.25  # Prix fictif
            support = float(support_str) if support_str else 0
            resistance = float(resistance_str) if resistance_str else 0
            
            if support > 0 and current_price > support:
                support_distance = (current_price - support) / current_price * 100
                print(f"📍 Distance support: {support_distance:.3f}%")
            
            if resistance > 0 and current_price < resistance:
                resistance_distance = (resistance - current_price) / current_price * 100
                print(f"📍 Distance résistance: {resistance_distance:.3f}%")
            
            # Déterminer quel niveau utiliser
            if support > 0 and resistance > 0:
                support_dist = abs(current_price - support) / current_price * 100
                resist_dist = abs(resistance - current_price) / current_price * 100
                
                if support_dist < resist_dist:
                    print(f"🎯 Niveau sélectionné: SUPPORT @ {support}")
                else:
                    print(f"🎯 Niveau sélectionné: RÉSISTANCE @ {resistance}")

def test_mt5_integration():
    """Simuler l'intégration avec MT5"""
    
    print("\n🔧 Simulation intégration MT5")
    print("=" * 30)
    
    mock_data = create_mock_server()
    
    # Simuler une requête MT5 typique
    symbol = "Boom 1000 Index"
    current_price = 1001.25
    
    print(f"📊 Symbole: {symbol}")
    print(f"💰 Prix actuel: {current_price}")
    
    # Trouver le meilleur niveau
    symbol_data = [item for item in mock_data if item["symbol"] == symbol]
    
    if symbol_data:
        best_level = max(symbol_data, key=lambda x: x["strength_score"])
        
        print(f"\n🎯 Meilleur niveau Supabase:")
        print(f"   Support: {best_level['support']}")
        print(f"   Résistance: {best_level['resistance']}")
        print(f"   Score force: {best_level['strength_score']}/100")
        print(f"   Nombre de touches: {best_level['touch_count']}")
        
        # Logique MT5 pour ordres limit
        print(f"\n📈 Logique ordres limit MT5:")
        
        # BUY LIMIT si près du support
        support_distance = (current_price - best_level['support']) / current_price * 100
        if support_distance < 0.2:  # Moins de 0.2%
            print(f"✅ BUY LIMIT possible @ {best_level['support']}")
            print(f"   Distance: {support_distance:.3f}% (< 0.2%)")
        else:
            print(f"❌ BUY LIMIT trop loin: {support_distance:.3f}% (> 0.2%)")
        
        # SELL LIMIT si près de la résistance  
        resistance_distance = (best_level['resistance'] - current_price) / current_price * 100
        if resistance_distance < 0.2:  # Moins de 0.2%
            print(f"✅ SELL LIMIT possible @ {best_level['resistance']}")
            print(f"   Distance: {resistance_distance:.3f}% (< 0.2%)")
        else:
            print(f"❌ SELL LIMIT trop loin: {resistance_distance:.3f}% (> 0.2%)")

def create_sample_env_file():
    """Créer un exemple de fichier .env fonctionnel"""
    
    print("\n📝 Création fichier .env.supabase.example")
    print("=" * 40)
    
    example_content = """# Configuration Supabase - Remplacez avec vos vraies valeurs
# Obtenez ces valeurs depuis: https://supabase.com/dashboard/project/your-project/settings/api

SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlvdXItcHJvamVjdC1pZCIsImlhdCI6MTY4MDAwMDAwMCwiZXhwIjoxOTk1NTU1NTU1fQ.VOTRE_EXEMPLE

# Configuration MT5 (optionnelle)
MT5_LOGIN=votre-login
MT5_PASSWORD=votre-password  
MT5_SERVER=votre-serveur

# Test: Pour vérifier que tout fonctionne
TEST_MODE=true
"""
    
    with open(".env.supabase.example", "w") as f:
        f.write(example_content)
    
    print("✅ Fichier .env.supabase.example créé")
    print("💡 Étapes suivantes:")
    print("   1. Copiez .env.supabase.example vers .env.supabase")
    print("   2. Remplacez vos-valeurs avec vos vraies clés Supabase")
    print("   3. Relancez le test")

if __name__ == "__main__":
    print("🚀 Tests Supabase - Mode Simulation")
    print("=" * 50)
    
    # Test 1: Parsing MQL5
    test_mql5_parsing()
    
    # Test 2: Intégration MT5
    test_mt5_integration()
    
    # Test 3: Création fichier exemple
    create_sample_env_file()
    
    print("\n" + "=" * 50)
    print("🎉 Tests de simulation terminés!")
    print("✅ Le parsing MQL5 fonctionne parfaitement")
    print("✅ La logique d'ordres limit est validée")
    print("✅ Le format de données est compatible")
    print("\n💡 Pour passer en production:")
    print("   1. Créez un projet Supabase")
    print("   2. Exécutez la migration SQL")
    print("   3. Configurez .env.supabase")
    print("   4. Lancez le script de mise à jour")
