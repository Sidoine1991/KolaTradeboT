#!/usr/bin/env python3
"""
Test du nouveau format SMS optimisé
"""
import os
import requests
from dotenv import load_dotenv
from datetime import datetime

load_dotenv()

def test_sms_format():
    """Test du nouveau format SMS optimisé"""
    print("🧪 TEST FORMAT SMS OPTIMISÉ")
    print("=" * 40)
    
    # Configuration
    api_key = os.getenv("VONAGE_API_KEY")
    api_secret = os.getenv("VONAGE_API_SECRET")
    from_name = os.getenv("VONAGE_SMS_FROM", "TradBOT")
    to_num = os.getenv("VONAGE_SMS_TO", "22996911346")
    
    print(f"From: {from_name}")
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
        elif "Crash" in case["symbol"]:
            direction = "SELL"
            order_type = "SELL LIMIT"
        else:
            direction = "NEUTRAL"
            order_type = "HOLD"
        
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
        
        # Format SMS optimisé (plus court, emojis clairs)
        sms_text = f"""🎯 SPIKE {case['symbol']}
⏰ {datetime.now().strftime('%H:%M')}
📊 {case['probability']:.0%} probabilité
🔄 {order_type}
💰 Entrée: {entry_price:.5f}
🎯 TP: {tp_price:.5f}
🛡️ SL: {sl_price:.5f}
📦 0.01 lots min"""
        
        print("Message SMS généré:")
        print(sms_text)
        print("-" * 40)
        
        # Envoyer seulement si probabilité > 70%
        if case["probability"] > 0.70:
            print("✅ Probabilité > 70% - Envoi du SMS")
            
            # Test SMS
            try:
                url = "https://rest.nexmo.com/sms/json"
                payload = {
                    "api_key": api_key,
                    "api_secret": api_secret,
                    "from": from_name,
                    "to": to_num,
                    "text": sms_text
                }
                
                resp = requests.post(url, data=payload, timeout=15)
                
                print(f"SMS Status: {resp.status_code}")
                if resp.status_code == 200:
                    data = resp.json()
                    if data.get('messages', [{}])[0].get('status') == '0':
                        print("✅ SMS envoyé avec succès!")
                        print(f"Message ID: {data.get('messages', [{}])[0].get('message-id')}")
                    else:
                        print("❌ Erreur d'envoi SMS")
                        print(f"Erreur: {data.get('messages', [{}])[0].get('error-text')}")
                else:
                    print(f"❌ Erreur HTTP: {resp.text}")
                    
            except Exception as e:
                print(f"❌ Erreur: {e}")
        else:
            print("❌ Probabilité < 70% - SMS ignoré")

if __name__ == "__main__":
    test_sms_format()
