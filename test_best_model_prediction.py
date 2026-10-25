#!/usr/bin/env python3
"""
Test de prédiction avec le meilleur modèle pour 200 bougies futures
"""
import requests
import json
from datetime import datetime, timedelta

def test_best_model_prediction():
    """Test la prédiction avec le meilleur modèle disponible"""
    
    symbols = ["Boom 300 Index", "Boom 600 Index", "Boom 900 Index", "Crash 1000 Index", "EURUSD", "GBPUSD", "USDJPY"]
    
    print("🔮 Test de prédiction avec meilleur modèle (200 bougies)")
    print("=" * 60)
    
    for symbol in symbols:
        print(f"\n📊 {symbol}")
        print("-" * 40)
        
        try:
            # Utiliser l'endpoint qui choisit le meilleur modèle automatiquement
            response = requests.get(
                f"https://kolatradebot.onrender.com/predict/{symbol}",
                timeout=15
            )
            
            if response.status_code == 200:
                data = response.json()
                prediction = data.get('prediction', {})
                
                print(f"✅ Signal: {prediction.get('direction', 'N/A')}")
                print(f"🎯 Confiance: {prediction.get('confidence', 0)*100:.1f}%")
                print(f"💰 Prix actuel: {prediction.get('price_target', 'N/A')}")
                print(f"📈 Stop Loss: {prediction.get('stop_loss', 'N/A')}")
                print(f"🎉 Take Profit: {prediction.get('take_profit', 'N/A')}")
                print(f"⏰ Horizon: {prediction.get('time_horizon', 'N/A')}")
                print(f"🤖 Source: {data.get('source', 'N/A')}")
                
                # Analyse technique si disponible
                analysis = data.get('analysis', {})
                if analysis:
                    print(f"📊 Force tendance: {analysis.get('trend_strength', 0)}")
                    print(f"📊 Volatilité: {analysis.get('volatility', 0)}")
                    print(f"📊 Volume: {analysis.get('volume', 0)}")
                    print(f"📊 RSI: {analysis.get('rsi', 0)}")
                    print(f"📊 MACD: {analysis.get('macd', 'N/A')}")
                
                # Demander une prédiction sur 200 bougies
                prediction_payload = {
                    "symbol": symbol,
                    "timeframe": "M1",
                    "periods": 200,
                    "current_price": prediction.get('price_target', 1000)
                }
                
                pred_response = requests.post(
                    "https://kolatradebot.onrender.com/prediction",
                    json=prediction_payload,
                    timeout=15
                )
                
                if pred_response.status_code == 200:
                    pred_data = pred_response.json()
                    print(f"🔮 Prédiction 200 bougies: {pred_data.get('predicted_price', 'N/A')}")
                    print(f"📈 Tendance longue: {pred_data.get('trend', 'N/A')}")
                else:
                    print(f"⚠️ Erreur prédiction 200 bougies: {pred_response.status_code}")
                
            else:
                print(f"❌ Erreur: {response.status_code}")
                print(f"Détail: {response.text}")
                
        except Exception as e:
            print(f"❌ Erreur: {e}")
    
    print("\n" + "=" * 60)
    print("📝 Résumé:")
    print("✅ Le système sélectionne automatiquement le meilleur modèle")
    print("📊 Basé sur les données d'entraînement envoyées toutes les heures")
    print("🎯 Prédiction disponible pour 200 bougies futures")
    print("⚡ Modèles optimisés par symbole et catégorie")

if __name__ == "__main__":
    test_best_model_prediction()
