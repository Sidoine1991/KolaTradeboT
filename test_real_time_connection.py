#!/usr/bin/env python3
"""
Script de test pour vérifier la connexion MT5 et les données en temps réel
"""

import sys
import os
from datetime import datetime, timedelta
import pandas as pd

# Ajouter le répertoire racine au PYTHONPATH
project_root = os.path.dirname(os.path.abspath(__file__))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

def test_mt5_connection():
    """Test de la connexion MT5 avec affichage des erreurs détaillées"""
    print("🔍 Test de connexion MT5...")
    
    try:
        from backend.mt5_connector import connect, test_connection, get_all_symbols, get_current_price, get_ohlc
        from backend.spike_detector import predict_spike_ml
        from backend.technical_analysis import add_technical_indicators
        import MetaTrader5 as mt5
        from dotenv import load_dotenv
        load_dotenv()
        
        # Test de connexion détaillé
        login = os.getenv('MT5_LOGIN')
        password = os.getenv('MT5_PASSWORD')
        server = os.getenv('MT5_SERVER')
        print(f"Tentative de connexion avec :\n  LOGIN={login}\n  SERVER={server}")
        
        if not login or not password or not server:
            print("❌ Erreur : MT5_LOGIN, MT5_PASSWORD ou MT5_SERVER manquant dans le fichier .env")
            return False
        try:
            login_int = int(login)
        except Exception:
            print(f"❌ Erreur : MT5_LOGIN doit être un nombre (actuellement: {login})")
            return False
        
        if not mt5.initialize(server=server, login=login_int, password=password):
            error = mt5.last_error()
            print(f"❌ Échec de l'initialisation MT5 : {error}")
            return False
        if not mt5.login(login=login_int, password=password, server=server):
            error = mt5.last_error()
            print(f"❌ Échec du login MT5 : {error}")
            return False
        print("✅ Connexion MT5 réussie!")
        
        # Récupérer les symboles
        symbols = get_all_symbols()
        print(f"📊 {len(symbols)} symboles disponibles")
        
        # Tester quelques symboles populaires
        test_symbols = ["EURUSD", "Volatility 75 Index", "Boom 1000 Index"]
        
        for symbol in test_symbols:
            if symbol in symbols:
                print(f"\n🔍 Test du symbole: {symbol}")
                
                # Prix actuel
                current_price = get_current_price(symbol)
                if current_price:
                    print(f"💰 Prix actuel: {current_price}")
                else:
                    print(f"❌ Impossible de récupérer le prix pour {symbol}")
                
                # Données OHLC
                df = get_ohlc(symbol, '1m', 10)
                if df is not None and not df.empty:
                    print(f"📈 Données OHLC: {len(df)} bougies récupérées")
                    print(f"   Dernière bougie: {df['close'].iloc[-1]:.5f}")
                    
                    # Ajouter les indicateurs techniques
                    df_with_indicators = add_technical_indicators(df, ['RSI', 'MACD'])
                    print(f"📊 Indicateurs techniques ajoutés")
                    
                    # Test de prédiction de spike
                    spike_proba = predict_spike_ml(df_with_indicators)
                    if spike_proba is not None:
                        print(f"🎯 Probabilité de spike: {spike_proba:.2%}")
                    else:
                        print(f"⚠️ Impossible de prédire les spikes pour {symbol}")
                else:
                    print(f"❌ Aucune donnée OHLC pour {symbol}")
            else:
                print(f"⚠️ Symbole {symbol} non trouvé")
        
        mt5.shutdown()
        return True
    except ImportError as e:
        print(f"❌ Erreur d'import: {e}")
        print("Assurez-vous que MetaTrader 5 est installé et configuré")
        return False
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return False

def test_real_time_data():
    """Test des données en temps réel"""
    print("\n🔄 Test des données en temps réel...")
    
    try:
        from backend.mt5_connector import get_ohlc, get_current_price
        from backend.spike_detector import predict_spike_ml
        from backend.technical_analysis import add_technical_indicators
        
        # Test avec EURUSD
        symbol = "EURUSD"
        
        print(f"📊 Test en temps réel pour {symbol}")
        
        # Récupérer les données récentes
        df = get_ohlc(symbol, '1m', 100)
        if df is not None and not df.empty:
            print(f"✅ {len(df)} bougies récupérées")
            
            # Ajouter les indicateurs
            df = add_technical_indicators(df, ['RSI', 'MACD', 'BB'])
            
            # Prédiction de spike
            spike_proba = predict_spike_ml(df)
            if spike_proba is not None:
                print(f"🎯 Probabilité de spike: {spike_proba:.2%}")
                
                if spike_proba > 0.7:
                    print("🚨 ALERTE: Forte probabilité de spike!")
                elif spike_proba > 0.5:
                    print("⚠️ Attention: Probabilité modérée de spike")
                else:
                    print("✅ Probabilité faible de spike")
            else:
                print("⚠️ Impossible de calculer la probabilité de spike")
            
            # Afficher les dernières valeurs
            print(f"\n📈 Dernières valeurs:")
            print(f"   Prix: {df['close'].iloc[-1]:.5f}")
            
            # Vérifier et afficher RSI
            if 'rsi_14' in df.columns:
                print(f"   RSI: {df['rsi_14'].iloc[-1]:.2f}")
            else:
                print(f"   RSI: Non disponible")
            
            # Vérifier et afficher MACD
            if 'macd' in df.columns:
                print(f"   MACD: {df['macd'].iloc[-1]:.5f}")
            else:
                print(f"   MACD: Non disponible")
            
            print(f"   Volume: {df['volume'].iloc[-1]}")
            
        else:
            print(f"❌ Aucune donnée pour {symbol}")
            
    except Exception as e:
        print(f"❌ Erreur lors du test temps réel: {e}")

def main():
    """Fonction principale"""
    print("🚀 Test de TradBOT - Connexion Temps Réel")
    print("=" * 50)
    
    # Test de connexion
    if test_mt5_connection():
        # Test des données en temps réel
        test_real_time_data()
        
        print("\n" + "=" * 50)
        print("✅ Tests terminés avec succès!")
        print("🎯 L'application est prête pour les prédictions en temps réel")
    else:
        print("\n" + "=" * 50)
        print("❌ Tests échoués")
        print("🔧 Vérifiez votre configuration MT5")

if __name__ == "__main__":
    main() 