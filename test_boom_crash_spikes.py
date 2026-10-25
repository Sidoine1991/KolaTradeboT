#!/usr/bin/env python3
"""
Script de test pour la détection de spikes Boom/Crash
"""

import requests
import json
import time
from datetime import datetime

def test_boom_crash_spike_detection():
    """Test la détection de spikes pour Boom/Crash"""
    
    # Configuration du serveur
    base_url = "http://localhost:8000"
    
    # Symboles à tester
    test_symbols = [
        "Boom 500 Index",
        "Crash 300 Index", 
        "Boom 300 Index",
        "Crash 1000 Index"
    ]
    
    print("🚀 Test de détection de spikes Boom/Crash")
    print("=" * 50)
    
    for symbol in test_symbols:
        print(f"\n📊 Test du symbole: {symbol}")
        print("-" * 30)
        
        # Test 1: Détection de spike
        try:
            response = requests.post(
                f"{base_url}/boom-crash/detect-spike",
                json={
                    "symbol": symbol,
                    "timeframe": "M1"
                },
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                analysis = data.get("analysis", {})
                spike_info = analysis.get("spike_detection", {})
                recommendation = data.get("recommendation", {})
                
                print(f"✅ Status: {data.get('status')}")
                print(f"📈 Points de données: {analysis.get('data_points')}")
                print(f"🕐 Dernière bougie: {analysis.get('last_candle', {}).get('close')}")
                print(f"🔥 Spike détecté: {spike_info.get('has_spike')}")
                
                if spike_info.get('has_spike'):
                    print(f"📊 Direction: {spike_info.get('direction')}")
                    print(f"💪 Confiance: {spike_info.get('confidence', 0):.1f}%")
                    print(f"📈 Changement prix: {spike_info.get('price_change_pct', 0):.2f}%")
                    print(f"📊 Volume ratio: {spike_info.get('volume_ratio', 0):.1f}x")
                    
                    if recommendation.get('has_signal'):
                        print(f"🎯 Signal: {recommendation.get('signal')}")
                        print(f"🛡️ SL: {recommendation.get('stop_loss')}")
                        print(f"🎪 TP: {recommendation.get('take_profit')}")
                else:
                    print(f"❌ Raison: {spike_info.get('reason', 'Inconnue')}")
                    
            else:
                print(f"❌ Erreur HTTP: {response.status_code}")
                print(f"📝 Message: {response.text}")
                
        except requests.exceptions.RequestException as e:
            print(f"❌ Erreur de connexion: {e}")
        
        # Test 2: Endpoint principal de prédiction
        try:
            print(f"\n🎯 Test endpoint principal pour {symbol}")
            response = requests.post(
                f"{base_url}/ml/predict-signal",
                json={
                    "symbol": symbol,
                    "timeframe": "M1",
                    "current_price": 5000 if "Boom" in symbol else 300
                },
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                print(f"✅ Signal: {data.get('signal')}")
                print(f"💪 Confiance: {data.get('confidence', 0):.1f}%")
                print(f"📡 Source: {data.get('source')}")
                
                if data.get('spike_info'):
                    spike = data.get('spike_info', {})
                    print(f"🔥 Spike info: {spike.get('has_spike')}")
                    
            else:
                print(f"❌ Erreur endpoint principal: {response.status_code}")
                
        except requests.exceptions.RequestException as e:
            print(f"❌ Erreur connexion endpoint principal: {e}")
        
        time.sleep(1)  # Pause entre les tests
    
    print("\n" + "=" * 50)
    print("✅ Tests terminés!")

def test_multiple_timeframes():
    """Test la détection sur différents timeframes"""
    
    base_url = "http://localhost:8000"
    symbol = "Boom 500 Index"
    timeframes = ["M1", "M5", "M15"]
    
    print(f"\n⏰ Test multi-timeframes pour {symbol}")
    print("=" * 40)
    
    for tf in timeframes:
        print(f"\n📊 Timeframe: {tf}")
        
        try:
            response = requests.post(
                f"{base_url}/boom-crash/detect-spike",
                json={
                    "symbol": symbol,
                    "timeframe": tf
                },
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                spike_info = data.get("analysis", {}).get("spike_detection", {})
                
                print(f"🔥 Spike: {spike_info.get('has_spike')}")
                print(f"📊 Changement: {spike_info.get('price_change_pct', 0):.2f}%")
                print(f"💪 Confiance: {spike_info.get('confidence', 0):.1f}%")
                
            else:
                print(f"❌ Erreur: {response.status_code}")
                
        except Exception as e:
            print(f"❌ Exception: {e}")

if __name__ == "__main__":
    print("🤖 Démarrage des tests de détection de spikes Boom/Crash")
    print(f"⏰ Heure: {datetime.now().strftime('%H:%M:%S')}")
    
    # Test principal
    test_boom_crash_spike_detection()
    
    # Test multi-timeframes
    test_multiple_timeframes()
    
    print(f"\n✅ Tous les tests terminés à {datetime.now().strftime('%H:%M:%S')}")
