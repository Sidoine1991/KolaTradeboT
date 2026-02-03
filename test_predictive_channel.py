#!/usr/bin/env python3
"""
Script de test pour la fonction de canal prédictif
"""

import pandas as pd
import numpy as np
import requests
import json
from datetime import datetime, timedelta

def generate_test_data(symbol: str, n_candles: int = 100) -> pd.DataFrame:
    """Génère des données de test pour le canal prédictif"""
    
    # Créer des données avec une tendance claire
    np.random.seed(42)
    
    # Prix de base selon le symbole
    base_prices = {
        "EURUSD": 1.0500,
        "GBPUSD": 1.2500,
        "USDJPY": 150.00,
        "XAUUSD": 2000.0,
        "Boom 500 Index": 500
    }
    
    base_price = base_prices.get(symbol, 100.0)
    
    # Générer une tendance avec canal
    trend = np.linspace(0, 0.02, n_candles)  # Tendance haussière de 2%
    noise = np.random.normal(0, 0.005, n_candles)  # Bruit aléatoire
    channel_width = 0.01  # Largeur du canal de 1%
    
    # Générer les prix
    closes = base_price * (1 + trend + noise)
    
    # Créer les OHLC
    highs = closes + np.random.uniform(0, channel_width * base_price, n_candles)
    lows = closes - np.random.uniform(0, channel_width * base_price, n_candles)
    opens = np.roll(closes, 1)
    opens[0] = closes[0]
    
    # Volume
    volumes = np.random.randint(1000, 5000, n_candles)
    
    # Timestamps
    timestamps = pd.date_range(start=datetime.now() - timedelta(minutes=n_candles), 
                              periods=n_candles, freq='1min')
    
    df = pd.DataFrame({
        'time': timestamps.astype(np.int64) // 10**9,  # Convertir en timestamp Unix
        'open': opens,
        'high': highs,
        'low': lows,
        'close': closes,
        'tick_volume': volumes
    })
    
    return df

def test_predictive_channel_function():
    """Test la fonction draw_predictive_channel directement"""
    print("🧪 Test de la fonction draw_predictive_channel...")
    
    # Importer la fonction
    import sys
    sys.path.append('.')
    from ai_server import draw_predictive_channel
    
    # Tester avec différents symboles
    symbols = ["EURUSD", "GBPUSD", "XAUUSD", "Boom 500 Index"]
    
    for symbol in symbols:
        print(f"\n📊 Test du canal prédictif pour {symbol}...")
        
        # Générer des données de test
        df = generate_test_data(symbol, 100)
        
        # Appeler la fonction
        result = draw_predictive_channel(df, symbol, lookback_period=50)
        
        # Afficher les résultats
        if result["has_channel"]:
            print(f"✅ Canal détecté pour {symbol}")
            print(f"   Signal: {result['signal']}")
            print(f"   Confiance: {result['confidence']:.1f}%")
            print(f"   Prix actuel: {result['current_price']:.5f}")
            print(f"   Position dans canal: {result['channel_info']['position_in_channel']:.1%}")
            print(f"   Largeur du canal: {result['channel_info']['width']:.5f}")
            print(f"   Support projeté: {result['support_resistance']['support']:.5f}")
            print(f"   Résistance projetée: {result['support_resistance']['resistance']:.5f}")
            
            if result['stop_loss'] and result['take_profit']:
                print(f"   SL: {result['stop_loss']:.5f}")
                print(f"   TP: {result['take_profit']:.5f}")
            
            print(f"   Raisonnement: {' | '.join(result['reasoning'])}")
        else:
            print(f"❌ Canal non détecté: {result['reason']}")

def test_predictive_channel_endpoint():
    """Test les endpoints FastAPI"""
    print("\n🌐 Test des endpoints FastAPI...")
    
    base_url = "http://localhost:8000"
    
    # Test GET endpoint
    try:
        response = requests.get(f"{base_url}/channel/predictive?symbol=EURUSD&lookback_period=50", timeout=10)
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Endpoint GET fonctionne")
            print(f"   Signal: {result.get('signal', 'N/A')}")
            print(f"   Confiance: {result.get('confidence', 0):.1f}%")
        else:
            print(f"❌ Erreur GET: {response.status_code}")
            print(f"   Message: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("⚠️ Serveur non démarré. Test GET ignoré.")
    except Exception as e:
        print(f"❌ Erreur GET: {e}")
    
    # Test POST endpoint
    try:
        payload = {
            "symbol": "EURUSD",
            "lookback_period": 50
        }
        
        response = requests.post(f"{base_url}/channel/predictive", 
                                json=payload, timeout=10)
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Endpoint POST fonctionne")
            print(f"   Signal: {result.get('signal', 'N/A')}")
            print(f"   Confiance: {result.get('confidence', 0):.1f}%")
        else:
            print(f"❌ Erreur POST: {response.status_code}")
            print(f"   Message: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("⚠️ Serveur non démarré. Test POST ignoré.")
    except Exception as e:
        print(f"❌ Erreur POST: {e}")

def test_edge_cases():
    """Test des cas limites"""
    print("\n🔍 Test des cas limites...")
    
    import sys
    sys.path.append('.')
    from ai_server import draw_predictive_channel
    
    # Test avec données insuffisantes
    print("📊 Test données insuffisantes...")
    df_small = generate_test_data("EURUSD", 30)  # Moins de 50 bougies
    result = draw_predictive_channel(df_small, "EURUSD", lookback_period=50)
    
    if not result["has_channel"]:
        print(f"✅ Correctement détecté: {result['reason']}")
    else:
        print("❌ Erreur: aurait dû détecter des données insuffisantes")
    
    # Test avec données vides
    print("📊 Test DataFrame vide...")
    df_empty = pd.DataFrame()
    result = draw_predictive_channel(df_empty, "EURUSD")
    
    if not result["has_channel"]:
        print(f"✅ Correctement détecté: {result['reason']}")
    else:
        print("❌ Erreur: aurait dû détecter un DataFrame vide")

if __name__ == "__main__":
    print("🚀 Démarrage des tests du canal prédictif...")
    
    # Test 1: Fonction directe
    test_predictive_channel_function()
    
    # Test 2: Endpoints API
    test_predictive_channel_endpoint()
    
    # Test 3: Cas limites
    test_edge_cases()
    
    print("\n🎯 Tests terminés!")
