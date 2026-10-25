import sys
import os
import pandas as pd
import numpy as np
import MetaTrader5 as mt5

# Ajouter le répertoire backend au path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

from features import compute_features

def test_features_generation():
    """Teste la génération des 32 features"""
    
    print("🧪 Test de génération des features")
    print("=" * 50)
    
    # Initialisation MT5
    if not mt5.initialize():
        print("❌ Échec de l'initialisation de MetaTrader 5")
        return False
    
    try:
        # Récupération des données
        symbol = "EURUSD"
        rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M5, 0, 100)
        
        if rates is None or len(rates) == 0:
            print("❌ Impossible de récupérer les données MT5")
            return False
        
        # Conversion en DataFrame
        df = pd.DataFrame(rates)
        df['timestamp'] = pd.to_datetime(df['time'], unit='s')
        df = df[['timestamp', 'open', 'high', 'low', 'close', 'tick_volume']]
        df.columns = ['timestamp', 'open', 'high', 'low', 'close', 'volume']
        
        print(f"✅ Données récupérées: {len(df)} barres pour {symbol}")
        
        # Calcul des features
        features = compute_features(df)
        
        print(f"\n📊 Résultats:")
        print(f"Nombre de features générées: {len(features.columns)}")
        print(f"Nombre attendu: 32")
        
        if len(features.columns) == 32:
            print("✅ SUCCÈS: Exactement 32 features générées!")
        else:
            print("❌ ÉCHEC: Nombre de features incorrect")
        
        print(f"\n📋 Liste des features:")
        for i, col in enumerate(features.columns, 1):
            print(f"{i:2d}. {col}")
        
        print(f"\n🔍 Dernières valeurs:")
        print(features.tail(1).T)
        
        # Test avec le scaler
        try:
            from sklearn.preprocessing import StandardScaler
            scaler = StandardScaler()
            scaled_features = scaler.fit_transform(features)
            print(f"\n✅ Test de scaling réussi: {scaled_features.shape}")
        except Exception as e:
            print(f"\n❌ Erreur lors du scaling: {e}")
        
        return len(features.columns) == 32
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return False
    finally:
        mt5.shutdown()

if __name__ == "__main__":
    success = test_features_generation()
    if success:
        print("\n🎉 Tous les tests sont passés!")
    else:
        print("\n💥 Certains tests ont échoué!") 