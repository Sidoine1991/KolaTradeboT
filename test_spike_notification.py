#!/usr/bin/env python3
"""
Test du nouveau format de notification Spike
"""
import os
import requests
from dotenv import load_dotenv
from datetime import datetime

load_dotenv()

def test_spike_notification():
    """Test du nouveau format de notification Spike"""
    print("🧪 TEST NOTIFICATION SPIKE")
    print("=" * 40)
    
    # Configuration
    api_key = os.getenv("VONAGE_API_KEY")
    api_secret = os.getenv("VONAGE_API_SECRET")
    from_num = os.getenv("VONAGE_WHATSAPP_FROM_SANDBOX", "14157386102")
    to_num = os.getenv("VONAGE_WHATSAPP_TO_SANDBOX", "22996911346")
    
    print(f"From: {from_num}")
    print(f"To: {to_num}")
    
    # Test avec différents symboles
    test_cases = [
        {
            "symbol": "Boom 1000 Index",
            "probability": 0.85,
            "current_price": 18137.31400
        },
        {
            "symbol": "Crash 500 Index", 
            "probability": 0.78,
            "current_price": 3298.22529
        },
        {
            "symbol": "EURUSD",
            "probability": 0.72,
            "current_price": 1.08500
        }
    ]
    
    for i, case in enumerate(test_cases, 1):
        print(f"\n🔄 Test {i}: {case['symbol']}")
        
        # Déterminer le type d'ordre et la direction
        if "Boom" in case["symbol"] and "Crash" not in case["symbol"]:
            direction = "BUY"
            order_type = "BUY LIMIT"
            spike_emoji = "🚀"
        elif "Crash" in case["symbol"]:
            direction = "SELL"
            order_type = "SELL LIMIT"
            spike_emoji = "💥"
        else:
            direction = "NEUTRAL"
            order_type = "HOLD"
            spike_emoji = "⚡"
        
        # Calculer les niveaux de prix
        current_price = case["current_price"]
        if "JPY" in case["symbol"] or "Index" in case["symbol"] or "Boom" in case["symbol"] or "Crash" in case["symbol"]:
            pip_value = 0.01
        else:
            pip_value = 0.0001
        
        # TP = +15 pips, SL = -5 pips
        if direction == "BUY":
            entry_price = current_price
            tp_price = current_price + (15 * pip_value)
            sl_price = current_price - (5 * pip_value)
        elif direction == "SELL":
            entry_price = current_price
            tp_price = current_price - (15 * pip_value)
            sl_price = current_price + (5 * pip_value)
        else:
            entry_price = current_price
            tp_price = current_price
            sl_price = current_price
        
        # Message professionnel pour les spikes
        spike_text = f"""🎯 SIGNAL TRADING SPIKE
📈 Devise: {case['symbol']}
⏰ Heure: {datetime.now().strftime('%H:%M:%S')}
📊 Probabilité: {case['probability']:.1%}
🔄 Ordre: {order_type}
💰 Prix d'entrée: {entry_price:.5f}
🎯 Take Profit: {tp_price:.5f}
🛡️ Stop Loss: {sl_price:.5f}
📦 Lots min: 0.01
💪 Confiance: {int(case['probability'] * 100)}%"""
        
        print("Message généré:")
        print(spike_text)
        print("-" * 40)
        
        # Envoyer seulement si probabilité > 70%
        if case["probability"] > 0.70:
            print("✅ Probabilité > 70% - Envoi du signal")
            
            # Test WhatsApp
            try:
                url = "https://messages-sandbox.nexmo.com/v1/messages"
                payload = {
                    "from": from_num,
                    "to": to_num,
                    "message_type": "text",
                    "text": spike_text,
                    "channel": "whatsapp"
                }
                
                resp = requests.post(
                    url,
                    auth=(api_key, api_secret),
                    json=payload,
                    headers={"Content-Type": "application/json"},
                    timeout=15
                )
                
                print(f"WhatsApp Status: {resp.status_code}")
                if resp.status_code == 202:
                    print("✅ WhatsApp envoyé avec succès!")
                else:
                    print(f"❌ Erreur WhatsApp: {resp.text}")
                    
            except Exception as e:
                print(f"❌ Erreur: {e}")
        else:
            print("❌ Probabilité < 70% - Signal ignoré")

if __name__ == "__main__":
    test_spike_notification()
