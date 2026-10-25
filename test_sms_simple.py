#!/usr/bin/env python3
"""
Test simple de l'API Vonage SMS
"""
import os
import requests
from dotenv import load_dotenv

load_dotenv()

def test_vonage_sms():
    """Test direct de l'API Vonage SMS"""
    print("🧪 TEST VONAGE SMS")
    print("=" * 30)
    
    api_key = os.getenv("VONAGE_API_KEY")
    api_secret = os.getenv("VONAGE_API_SECRET")
    from_name = os.getenv("VONAGE_SMS_FROM", "TradBOT")
    to_num = os.getenv("VONAGE_SMS_TO", "22996911346")
    
    # Demander le numéro à l'utilisateur
    print(f"Numéro configuré: {to_num}")
    print("Si ce n'est pas votre numéro, modifiez VONAGE_SMS_TO dans .env")
    print("Format: 336XXXXXXXX (sans + ni 00)")
    
    print(f"API Key: {api_key[:8]}..." if api_key else "❌ Manquant")
    print(f"From: {from_name}")
    print(f"To: {to_num}")
    
    if not api_key or not api_secret:
        print("❌ Clés API manquantes")
        return
    
    # Test de l'API Vonage SMS
    url = "https://rest.nexmo.com/sms/json"
    
    payload = {
        "api_key": api_key,
        "api_secret": api_secret,
        "from": from_name,
        "to": to_num,
        "text": "🧪 Test TradBOT - Message SMS de test"
    }
    
    try:
        print("\n🔄 Envoi SMS en cours...")
        resp = requests.post(url, data=payload, timeout=15)
        
        print(f"Status: {resp.status_code}")
        print(f"Response: {resp.text}")
        
        if resp.status_code == 200:
            data = resp.json()
            if data.get('messages', [{}])[0].get('status') == '0':
                print("✅ SMS envoyé avec succès!")
                print(f"Message ID: {data.get('messages', [{}])[0].get('message-id')}")
            else:
                print("❌ Erreur d'envoi SMS")
                print(f"Erreur: {data.get('messages', [{}])[0].get('error-text')}")
        else:
            print("❌ Erreur HTTP")
            
    except Exception as e:
        print(f"❌ Erreur: {e}")

if __name__ == "__main__":
    test_vonage_sms()
