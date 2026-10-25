#!/usr/bin/env python3
"""
Test WhatsApp avec configuration propre
"""
import os
import requests

# Configuration directe (sans .env)
VONAGE_API_KEY = "1a1de47f"
VONAGE_API_SECRET = "Vkb6ia33anmNAyOE"
VONAGE_FROM = "14157386102"
VONAGE_TO = "22996911346"

def test_whatsapp_clean():
    """Test WhatsApp avec configuration propre"""
    print("🧪 TEST WHATSAPP PROPRE")
    print("=" * 40)
    print(f"From: {VONAGE_FROM}")
    print(f"To: {VONAGE_TO}")
    
    # Test 1: Structure simple (ancienne API)
    print("\n🔄 Test 1: Structure simple")
    url1 = "https://messages-sandbox.nexmo.com/v1/messages"
    payload1 = {
        "from": VONAGE_FROM,
        "to": VONAGE_TO,
        "message_type": "text",
        "text": "🧪 Test TradBOT WhatsApp - Structure simple",
        "channel": "whatsapp"
    }
    
    try:
        resp1 = requests.post(
            url1,
            auth=(VONAGE_API_KEY, VONAGE_API_SECRET),
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
    
    # Test 2: Nouvelle API
    print("\n🔄 Test 2: Nouvelle API")
    url2 = "https://api.nexmo.com/v1/messages"
    payload2 = {
        "from": {"type": "whatsapp", "number": VONAGE_FROM},
        "to": {"type": "whatsapp", "number": VONAGE_TO},
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
            auth=(VONAGE_API_KEY, VONAGE_API_SECRET),
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
    
    return False

if __name__ == "__main__":
    test_whatsapp_clean()
