#!/usr/bin/env python3
"""
Script pour insérer des données de test dans les tables Supabase vides
"""

import os
import json
import urllib.request
import urllib.parse
from datetime import datetime, timedelta

def load_env():
    """Charger les variables d'environnement depuis .env"""
    env_vars = {}
    try:
        with open('.env', 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()
        return env_vars
    except FileNotFoundError:
        print("❌ Fichier .env non trouvé")
        return {}

def insert_correction_predictions():
    """Insérer des données de test dans correction_predictions"""
    print("📊 INSERTION DANS correction_predictions")
    
    env = load_env()
    url = env.get('SUPABASE_URL')
    key = env.get('SUPABASE_ANON_KEY')
    
    # Données de test
    test_data = [
        {
            'symbol': 'Boom 500 Index',
            'timeframe': 'M1',
            'current_price': 1850.50,
            'current_trend': 'UP',
            'prediction_confidence': 75.5,
            'zone_1_level': 1845.25,
            'zone_1_type': 'SUPPORT',
            'zone_1_probability': 80.0,
            'zone_2_level': 1840.00,
            'zone_2_type': 'SUPPORT',
            'zone_2_probability': 65.0,
            'zone_3_level': 1835.75,
            'zone_3_type': 'SUPPORT',
            'zone_3_probability': 45.0,
            'trend_strength_factor': 1.2,
            'volatility_adjustment': 0.95,
            'historical_accuracy': 72.5,
            'prediction_valid_until': (datetime.now() + timedelta(hours=24)).isoformat()
        },
        {
            'symbol': 'Crash 500 Index',
            'timeframe': 'M1',
            'current_price': 1840.25,
            'current_trend': 'DOWN',
            'prediction_confidence': 82.3,
            'zone_1_level': 1845.50,
            'zone_1_type': 'RESISTANCE',
            'zone_1_probability': 85.0,
            'zone_2_level': 1850.75,
            'zone_2_type': 'RESISTANCE',
            'zone_2_probability': 70.0,
            'zone_3_level': 1855.00,
            'zone_3_type': 'RESISTANCE',
            'zone_3_probability': 50.0,
            'trend_strength_factor': 1.1,
            'volatility_adjustment': 1.05,
            'historical_accuracy': 78.2,
            'prediction_valid_until': (datetime.now() + timedelta(hours=24)).isoformat()
        }
    ]
    
    try:
        for data in test_data:
            insert_url = f"{url}/rest/v1/correction_predictions"
            req = urllib.request.Request(insert_url)
            req.add_header('apikey', key)
            req.add_header('Authorization', f'Bearer {key}')
            req.add_header('Content-Type', 'application/json')
            req.add_header('Prefer', 'return=minimal')
            
            json_data = json.dumps(data).encode('utf-8')
            
            with urllib.request.urlopen(req, json_data) as response:
                print(f"   ✅ Données insérées pour {data['symbol']}")
                
    except Exception as e:
        print(f"❌ Erreur insertion correction_predictions: {e}")

def insert_prediction_performance():
    """Insérer des données de test dans prediction_performance"""
    print("📈 INSERTION DANS prediction_performance")
    
    env = load_env()
    url = env.get('SUPABASE_URL')
    key = env.get('SUPABASE_ANON_KEY')
    
    # Données de test
    test_data = [
        {
            'symbol': 'Boom 500 Index',
            'performance_date': datetime.now().date().isoformat(),
            'total_predictions': 15,
            'successful_predictions': 11,
            'failed_predictions': 4,
            'zone_1_accuracy': 85.5,
            'zone_2_accuracy': 72.3,
            'zone_3_accuracy': 45.8,
            'overall_accuracy': 73.3,
            'avg_confidence': 76.8,
            'total_corrections_analyzed': 45,
            'avg_retracement_used': 2.3,
            'market_volatility': 0.023
        },
        {
            'symbol': 'Crash 500 Index',
            'performance_date': datetime.now().date().isoformat(),
            'total_predictions': 12,
            'successful_predictions': 9,
            'failed_predictions': 3,
            'zone_1_accuracy': 88.2,
            'zone_2_accuracy': 75.6,
            'zone_3_accuracy': 52.1,
            'overall_accuracy': 75.0,
            'avg_confidence': 79.5,
            'total_corrections_analyzed': 38,
            'avg_retracement_used': 2.4,
            'market_volatility': 0.025
        }
    ]
    
    try:
        for data in test_data:
            insert_url = f"{url}/rest/v1/prediction_performance"
            req = urllib.request.Request(insert_url)
            req.add_header('apikey', key)
            req.add_header('Authorization', f'Bearer {key}')
            req.add_header('Content-Type', 'application/json')
            req.add_header('Prefer', 'return=minimal')
            
            json_data = json.dumps(data).encode('utf-8')
            
            with urllib.request.urlopen(req, json_data) as response:
                print(f"   ✅ Données insérées pour {data['symbol']}")
                
    except Exception as e:
        print(f"❌ Erreur insertion prediction_performance: {e}")

def insert_symbol_patterns():
    """Insérer des données de test dans symbol_correction_patterns"""
    print("🎯 INSERTION DANS symbol_correction_patterns")
    
    env = load_env()
    url = env.get('SUPABASE_URL')
    key = env.get('SUPABASE_ANON_KEY')
    
    # Données de test
    test_data = [
        {
            'symbol': 'Boom 500 Index',
            'pattern_type': 'GRADUAL',
            'avg_retracement_percentage': 2.3,
            'typical_duration_bars': 8,
            'success_rate': 75.5,
            'min_trend_strength': 1.2,
            'max_volatility_level': 0.03,
            'best_timeframes': 'M1,M5,H1',
            'occurrences_count': 15
        },
        {
            'symbol': 'Boom 500 Index',
            'pattern_type': 'CONSOLIDATION',
            'avg_retracement_percentage': 1.8,
            'typical_duration_bars': 12,
            'success_rate': 68.2,
            'min_trend_strength': 1.0,
            'max_volatility_level': 0.025,
            'best_timeframes': 'M5,H1',
            'occurrences_count': 20
        },
        {
            'symbol': 'Crash 500 Index',
            'pattern_type': 'SHARP_REVERSAL',
            'avg_retracement_percentage': 3.1,
            'typical_duration_bars': 5,
            'success_rate': 82.3,
            'min_trend_strength': 1.5,
            'max_volatility_level': 0.035,
            'best_timeframes': 'M1,M5',
            'occurrences_count': 8
        }
    ]
    
    try:
        for data in test_data:
            insert_url = f"{url}/rest/v1/symbol_correction_patterns"
            req = urllib.request.Request(insert_url)
            req.add_header('apikey', key)
            req.add_header('Authorization', f'Bearer {key}')
            req.add_header('Content-Type', 'application/json')
            req.add_header('Prefer', 'return=minimal')
            
            json_data = json.dumps(data).encode('utf-8')
            
            with urllib.request.urlopen(req, json_data) as response:
                print(f"   ✅ Données insérées pour {data['symbol']} - {data['pattern_type']}")
                
    except Exception as e:
        print(f"❌ Erreur insertion symbol_correction_patterns: {e}")

def verify_insertion():
    """Vérifier que les données ont été insérées"""
    print("\n🔍 VÉRIFICATION DE L'INSERTION")
    
    env = load_env()
    url = env.get('SUPABASE_URL')
    key = env.get('SUPABASE_ANON_KEY')
    
    tables = ['correction_predictions', 'prediction_performance', 'symbol_correction_patterns']
    
    for table in tables:
        try:
            count_url = f"{url}/rest/v1/{table}?select=id&limit=0"
            req = urllib.request.Request(count_url)
            req.add_header('apikey', key)
            req.add_header('Authorization', f'Bearer {key}')
            req.add_header('Prefer', 'count=exact')
            
            with urllib.request.urlopen(req) as response:
                count = response.headers.get('content-range', '0-0/0').split('/')[-1]
                print(f"   📊 {table}: {count} enregistrements")
                
        except Exception as e:
            print(f"   ❌ Erreur vérification {table}: {e}")

def main():
    print("🚀 INSERTION DE DONNÉES DE TEST SUPABASE")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    insert_correction_predictions()
    insert_prediction_performance()
    insert_symbol_patterns()
    verify_insertion()
    
    print("\n✅ INSERTION TERMINÉE")
    print("\n💡 PROCHAINES ÉTAPES:")
    print("   1. Vérifiez les données dans le Dashboard Supabase")
    print("   2. Testez le robot MT5 avec les nouvelles données")
    print("   3. Exécutez le script de test graphique sur MT5")

if __name__ == "__main__":
    main()
