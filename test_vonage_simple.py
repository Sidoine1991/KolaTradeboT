#!/usr/bin/env python3
"""
Test simple de l'API Vonage WhatsApp
"""
import os
import requests
from dotenv import load_dotenv

load_dotenv()

def test_vonage_whatsapp():
    """Test direct de l'API Vonage"""
    print("🧪 TEST VONAGE WHATSAPP")
    print("=" * 40)
    
    api_key = os.getenv("VONAGE_API_KEY")
    api_secret = os.getenv("VONAGE_API_SECRET")
    from_num = os.getenv("VONAGE_WHATSAPP_FROM_SANDBOX", "14157386102")
    to_num = os.getenv("VONAGE_WHATSAPP_TO_SANDBOX", "22996911346")
    
    print(f"API Key: {api_key[:8]}..." if api_key else "❌ Manquant")
    print(f"From: {from_num}")
    print(f"To: {to_num}")
    
    if not api_key or not api_secret:
        print("❌ Clés API manquantes")
        return
    
    # Test de l'API Vonage
    url = "https://api.nexmo.com/v1/messages"
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    payload = {
        "from": {"type": "whatsapp", "number": from_num},
        "to": {"type": "whatsapp", "number": to_num},
        "message": {
            "content": {
                "type": "text",
                "text": "🧪 Test TradBOT - Message de test Vonage"
            }
        }
    }
    
    try:
        print("\n🔄 Envoi en cours...")
        resp = requests.post(
            url,
            auth=(api_key, api_secret),
            json=payload,
            headers=headers,
            timeout=15
        )
        
        print(f"Status: {resp.status_code}")
        print(f"Response: {resp.text}")
        
        if resp.status_code == 202:
            print("✅ Message envoyé avec succès!")
            data = resp.json()
            print(f"Message UUID: {data.get('message_uuid')}")
        else:
            print("❌ Erreur d'envoi")
            
    except Exception as e:
        print(f"❌ Erreur: {e}")

if __name__ == "__main__":
    test_vonage_whatsapp()
