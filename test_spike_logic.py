#!/usr/bin/env python3
"""
Test simple de la détection de spikes Boom/Crash sans serveur
"""

import sys
import os
import pandas as pd
import numpy as np
from datetime import datetime

# Ajouter le répertoire courant au path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def test_spike_detection_logic():
    """Test la logique de détection de spikes directement"""
    
    print("🚀 Test de la logique de détection de spikes Boom/Crash")
    print("=" * 60)
    
    # Importer les fonctions depuis ai_server
    try:
        from ai_server import (
            is_boom_crash_symbol,
            detect_spike_pattern,
            generate_boom_crash_signal,
            generate_simulated_data,
            calculate_rsi,
            calculate_atr
        )
        print("✅ Import réussi des fonctions de détection")
    except ImportError as e:
        print(f"❌ Erreur import: {e}")
        return
    
    # Test 1: Vérification des symboles Boom/Crash
    print("\n📊 Test 1: Identification des symboles Boom/Crash")
    test_symbols = [
        "Boom 500 Index",
        "Crash 300 Index", 
        "EURUSD",
        "Boom 300 Index",
        "Crash 1000 Index",
        "GBPUSD"
    ]
    
    for symbol in test_symbols:
        is_bc = is_boom_crash_symbol(symbol)
        status = "✅" if is_bc else "❌"
        print(f"  {status} {symbol}: {'Boom/Crash' if is_bc else 'Normal'}")
    
    # Test 2: Génération de données simulées avec spikes
    print("\n📈 Test 2: Génération de données simulées")
    
    for symbol in ["Boom 500 Index", "Crash 300 Index", "EURUSD"]:
        print(f"\n  📊 Génération pour {symbol}:")
        df = generate_simulated_data(symbol, 50)
        
        if not df.empty:
            print(f"    ✅ {len(df)} bougies générées")
            print(f"    📊 Prix moyen: {df['close'].mean():.2f}")
            print(f"    📊 Volatilité: {df['close'].pct_change().std()*100:.2f}%")
            print(f"    📊 Volume moyen: {df['tick_volume'].mean():.0f}")
        else:
            print(f"    ❌ Erreur génération")
    
    # Test 3: Détection de spikes
    print("\n🔥 Test 3: Détection de spikes")
    
    for symbol in ["Boom 500 Index", "Crash 300 Index"]:
        print(f"\n  📊 Analyse {symbol}:")
        
        # Générer des données
        df = generate_simulated_data(symbol, 30)
        
        if not df.empty:
            # Détecter les spikes
            spike_info = detect_spike_pattern(df, symbol)
            
            print(f"    🔥 Spike détecté: {spike_info.get('has_spike')}")
            print(f"    📊 Direction: {spike_info.get('direction')}")
            print(f"    💪 Confiance: {spike_info.get('confidence', 0):.1f}%")
            print(f"    📈 Changement prix: {spike_info.get('price_change_pct', 0):.2f}%")
            print(f"    📊 Range: {spike_info.get('range_pct', 0):.2f}%")
            print(f"    📊 Volume ratio: {spike_info.get('volume_ratio', 0):.1f}x")
            
            # Critères
            criteria = spike_info.get('criteria', {})
            print(f"    🎯 Critères:")
            print(f"      - Price spike: {criteria.get('price_spike', False)}")
            print(f"      - Range spike: {criteria.get('range_spike', False)}")
            print(f"      - Volume spike: {criteria.get('volume_spike', False)}")
            print(f"      - Momentum spike: {criteria.get('momentum_spike', False)}")
            
            # Test génération de signal
            signal = generate_boom_crash_signal(symbol, df)
            print(f"    🎯 Signal généré: {signal.get('has_signal')}")
            if signal.get('has_signal'):
                print(f"      - Direction: {signal.get('signal')}")
                print(f"      - Confiance: {signal.get('confidence', 0):.1f}%")
                print(f"      - SL: {signal.get('stop_loss')}")
                print(f"      - TP: {signal.get('take_profit')}")
        else:
            print(f"    ❌ Données vides")
    
    # Test 4: Test avec un spike artificiel
    print("\n🎯 Test 4: Spike artificiel")
    
    # Créer un DataFrame avec un spike évident
    np.random.seed(42)
    base_price = 5000
    normal_prices = np.random.normal(0, 0.001, 20).cumsum() + base_price
    
    # Ajouter un spike à la fin
    spike_prices = list(normal_prices)
    spike_prices.append(spike_prices[-1] * 1.025)  # Spike de 2.5% (plus prononcé)
    
    timestamps = pd.date_range(end=datetime.now(), periods=len(spike_prices), freq='1min')
    
    spike_df = pd.DataFrame({
        'time': timestamps.astype(np.int64) // 10**9,
        'open': spike_prices,
        'high': [p * 1.005 for p in spike_prices],  # Range plus large
        'low': [p * 0.995 for p in spike_prices],
        'close': spike_prices,
        'tick_volume': [50000 if i == len(spike_prices)-1 else np.random.randint(10000, 30000) for i in range(len(spike_prices))]  # Volume élevé sur spike
    })
    
    print("  📊 DataFrame avec spike créé:")
    print(f"    - Prix avant spike: {spike_prices[-2]:.2f}")
    print(f"    - Prix spike: {spike_prices[-1]:.2f}")
    print(f"    - Changement: {((spike_prices[-1]/spike_prices[-2])-1)*100:.2f}%")
    
    # Tester la détection
    spike_info = detect_spike_pattern(spike_df, "Boom 500 Index")
    
    print(f"  🔥 Spike détecté: {spike_info.get('has_spike')}")
    print(f"  💪 Confiance: {spike_info.get('confidence', 0):.1f}%")
    
    # Debug: voir les valeurs calculées
    criteria = spike_info.get('criteria', {})
    print(f"  🐛 Debug valeurs:")
    print(f"    - Price change pct: {spike_info.get('price_change_pct', 0):.3f}% (seuil: 0.8%)")
    print(f"    - Range pct: {spike_info.get('range_pct', 0):.3f}% (seuil: 1.0%)")
    print(f"    - Volume ratio: {spike_info.get('volume_ratio', 0):.1f}x (seuil: 2.0x)")
    print(f"    - RSI: {spike_info.get('rsi', 'N/A')}")
    print(f"    - Critères remplis: {sum(1 for k, v in criteria.items() if v and not k.startswith('rsi_'))}/3")
    
    print("\n" + "=" * 60)
    print("✅ Tests terminés!")

if __name__ == "__main__":
    test_spike_detection_logic()
