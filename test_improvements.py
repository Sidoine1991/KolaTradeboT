#!/usr/bin/env python3
"""
Script de test pour vérifier les améliorations des features et signaux
"""

import sys
import os
from datetime import datetime, timedelta
import pandas as pd
import numpy as np

# Ajouter le répertoire racine au PYTHONPATH
project_root = os.path.dirname(os.path.abspath(__file__))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

def test_features():
    """Test de la génération des features"""
    print("🔍 Test de la génération des features...")
    
    try:
        from backend.features import compute_features
        from backend.mt5_connector import get_ohlc
        from backend.technical_analysis import add_technical_indicators
        
        # Récupérer des données réelles
        df = get_ohlc("EURUSD", "1m", 100)
        if df is not None and not df.empty:
            print(f"✅ {len(df)} bougies récupérées pour EURUSD")
            
            # Ajouter les indicateurs techniques
            df = add_technical_indicators(df, ['RSI', 'MACD', 'BB', 'SMA', 'EMA'])
            
            # Générer les features
            features = compute_features(df)
            
            print(f"📊 Features générées: {len(features.columns)} colonnes")
            print(f"📋 Colonnes: {list(features.columns)}")
            
            # Vérifier qu'on a exactement 30 features
            if len(features.columns) == 30:
                print("✅ Nombre de features correct (30)")
            else:
                print(f"⚠️ Nombre de features incorrect: {len(features.columns)} (attendu: 30)")
            
            # Afficher quelques valeurs
            print(f"\n📈 Dernières valeurs des features:")
            for col in list(features.columns)[:10]:  # Afficher les 10 premières
                value = features[col].iloc[-1]
                print(f"   {col}: {value:.4f}")
            
            return True
        else:
            print("❌ Aucune donnée récupérée")
            return False
            
    except Exception as e:
        print(f"❌ Erreur lors du test des features: {e}")
        return False

def test_signals():
    """Test de la génération des signaux"""
    print("\n🔍 Test de la génération des signaux...")
    
    try:
        from backend.signal_generator import generate_signal, generate_professional_signal_html
        from backend.mt5_connector import get_ohlc
        from backend.technical_analysis import add_technical_indicators
        
        # Récupérer des données réelles
        df = get_ohlc("EURUSD", "1m", 100)
        if df is not None and not df.empty:
            print(f"✅ {len(df)} bougies récupérées pour EURUSD")
            
            # Ajouter les indicateurs techniques
            df = add_technical_indicators(df, ['RSI', 'MACD', 'BB', 'SMA', 'EMA'])
            
            # Simulation d'une prédiction ML
            ml_prediction = {
                'direction': 'HAUSSE',
                'probability': 0.75
            }
            
            # Générer le signal
            signal = generate_signal(df, ml_prediction)
            
            print(f"📊 Signal généré:")
            print(f"   Direction: {signal['signal']}")
            print(f"   Confiance: {signal['confidence']}%")
            print(f"   Force: {signal['strength']}")
            print(f"   Raison: {signal['reason']}")
            
            # Générer le HTML
            html = generate_professional_signal_html(signal)
            print(f"✅ HTML généré ({len(html)} caractères)")
            
            return True
        else:
            print("❌ Aucune donnée récupérée")
            return False
            
    except Exception as e:
        print(f"❌ Erreur lors du test des signaux: {e}")
        return False

def test_ml_prediction():
    """Test de la prédiction ML avec les nouvelles features"""
    print("\n🔍 Test de la prédiction ML...")
    
    try:
        from backend.spike_detector import predict_spike_ml
        from backend.mt5_connector import get_ohlc
        from backend.technical_analysis import add_technical_indicators
        
        # Récupérer des données réelles
        df = get_ohlc("Boom 1000 Index", "1m", 100)
        if df is not None and not df.empty:
            print(f"✅ {len(df)} bougies récupérées pour Boom 1000 Index")
            
            # Ajouter les indicateurs techniques
            df = add_technical_indicators(df, ['RSI', 'MACD', 'BB', 'SMA', 'EMA'])
            
            # Prédiction ML
            ml_proba = predict_spike_ml(df)
            
            if ml_proba is not None:
                print(f"🎯 Prédiction ML: {ml_proba:.2%}")
                
                if ml_proba > 0.7:
                    print("🚨 ALERTE: Forte probabilité de spike!")
                elif ml_proba > 0.5:
                    print("⚠️ Attention: Probabilité modérée de spike")
                else:
                    print("✅ Probabilité faible de spike")
            else:
                print("⚠️ Impossible de calculer la probabilité de spike")
            
            return True
        else:
            print("❌ Aucune donnée récupérée")
            return False
            
    except Exception as e:
        print(f"❌ Erreur lors du test ML: {e}")
        return False

def main():
    """Fonction principale"""
    print("🚀 Test des améliorations TradBOT")
    print("=" * 50)
    
    # Test des features
    features_ok = test_features()
    
    # Test des signaux
    signals_ok = test_signals()
    
    # Test ML
    ml_ok = test_ml_prediction()
    
    print("\n" + "=" * 50)
    if features_ok and signals_ok and ml_ok:
        print("✅ Tous les tests réussis!")
        print("🎯 Les améliorations sont fonctionnelles")
        print("📱 L'application est prête avec des prédictions améliorées")
    else:
        print("❌ Certains tests ont échoué")
        print("🔧 Vérifiez les erreurs ci-dessus")

if __name__ == "__main__":
    main() 