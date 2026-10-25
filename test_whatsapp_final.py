#!/usr/bin/env python3
"""
Test WhatsApp avec le numéro qui fonctionne
"""
import os
import requests
from dotenv import load_dotenv

load_dotenv()

def test_whatsapp_final():
    """Test WhatsApp avec le bon numéro"""
    print("🧪 TEST WHATSAPP FINAL")
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
    
    # Test avec différentes structures d'API
    print("\n🔄 Test 1: Structure simple (ancienne API)")
    url1 = "https://messages-sandbox.nexmo.com/v1/messages"
    payload1 = {
        "from": from_num,
        "to": to_num,
        "message_type": "text",
        "text": "🧪 Test TradBOT WhatsApp - Structure simple",
        "channel": "whatsapp"
    }
    
    try:
        resp1 = requests.post(
            url1,
            auth=(api_key, api_secret),
            json=payload1,
            headers={"Content-Type": "application/json"},
            timeout=15
        )
        print(f"Status: {resp1.status_code}")
        print(f"Response: {resp1.text}")
        
        if resp1.status_code == 202:
            print("✅ WhatsApp envoyé avec succès!")
            return True
        else:
            print("❌ Erreur avec structure simple")
    except Exception as e:
        print(f"❌ Erreur: {e}")
    
    print("\n🔄 Test 2: Structure nouvelle API")
    url2 = "https://api.nexmo.com/v1/messages"
    payload2 = {
        "from": {"type": "whatsapp", "number": from_num},
        "to": {"type": "whatsapp", "number": to_num},
        "message": {
            "content": {
                "type": "text",
                "text": "🧪 Test TradBOT WhatsApp - Nouvelle API"
            }
        }
    }
    
    try:
        resp2 = requests.post(
            url2,
            auth=(api_key, api_secret),
            json=payload2,
            headers={"Content-Type": "application/json"},
            timeout=15
        )
        print(f"Status: {resp2.status_code}")
        print(f"Response: {resp2.text}")
        
        if resp2.status_code == 202:
            print("✅ WhatsApp envoyé avec succès!")
            return True
        else:
            print("❌ Erreur avec nouvelle API")
    except Exception as e:
        print(f"❌ Erreur: {e}")
    
    print("\n🔄 Test 3: API Messages API (dernière version)")
    url3 = "https://api.nexmo.com/v1/messages"
    payload3 = {
        "from": {"type": "whatsapp", "number": from_num},
        "to": {"type": "whatsapp", "number": to_num},
        "message": {
            "content": {
                "type": "text",
                "text": "🧪 Test TradBOT WhatsApp - Messages API"
            }
        }
    }
    
    try:
        resp3 = requests.post(
            url3,
            auth=(api_key, api_secret),
            json=payload3,
            headers={"Content-Type": "application/json", "Accept": "application/json"},
            timeout=15
        )
        print(f"Status: {resp3.status_code}")
        print(f"Response: {resp3.text}")
        
        if resp3.status_code == 202:
            print("✅ WhatsApp envoyé avec succès!")
            return True
        else:
            print("❌ Erreur avec Messages API")
    except Exception as e:
        print(f"❌ Erreur: {e}")
    
    return False

if __name__ == "__main__":
    test_whatsapp_final()
