#!/usr/bin/env python3
"""
Script de test et diagnostic WhatsApp pour TradBOT
"""
import os
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv()

def test_whatsapp_config():
    """Teste la configuration WhatsApp"""
    print("🔍 DIAGNOSTIC WHATSAPP")
    print("=" * 50)
    
    # Vérifier les variables d'environnement
    twilio_sid = os.getenv('TWILIO_ACCOUNT_SID')
    twilio_token = os.getenv('TWILIO_AUTH_TOKEN')
    twilio_from = os.getenv('TWILIO_WHATSAPP_FROM')
    twilio_to = os.getenv('TWILIO_WHATSAPP_TO')
    
    print(f"TWILIO_ACCOUNT_SID: {'✅ Configuré' if twilio_sid and twilio_sid != 'your_twilio_account_sid' else '❌ Manquant ou par défaut'}")
    print(f"TWILIO_AUTH_TOKEN: {'✅ Configuré' if twilio_token and twilio_token != 'your_twilio_auth_token' else '❌ Manquant ou par défaut'}")
    print(f"TWILIO_WHATSAPP_FROM: {twilio_from}")
    print(f"TWILIO_WHATSAPP_TO: {twilio_to}")
    
    # Test de connexion Twilio
    if twilio_sid and twilio_token and twilio_sid != 'your_twilio_account_sid':
        try:
            import requests
            url = f"https://api.twilio.com/v1/Accounts/{twilio_sid}.json"
            resp = requests.get(url, auth=(twilio_sid, twilio_token), timeout=10)
            
            if resp.status_code == 200:
                account_info = resp.json()
                print(f"✅ Compte Twilio valide: {account_info.get('friendly_name', 'N/A')}")
                print(f"   Status: {account_info.get('status', 'N/A')}")
            else:
                print(f"❌ Erreur Twilio: {resp.status_code} - {resp.text}")
        except Exception as e:
            print(f"❌ Erreur de connexion Twilio: {e}")
    else:
        print("⚠️ Configuration Twilio incomplète")
    
    print("\n" + "=" * 50)
    
    # Test Vonage
    vonage_key = os.getenv('VONAGE_API_KEY')
    vonage_secret = os.getenv('VONAGE_API_SECRET')
    vonage_from = os.getenv('VONAGE_WHATSAPP_FROM_SANDBOX')
    vonage_to = os.getenv('VONAGE_WHATSAPP_TO_SANDBOX')
    
    print("🔍 DIAGNOSTIC VONAGE (SMS/WhatsApp)")
    print("=" * 50)
    print(f"VONAGE_API_KEY: {'✅ Configuré' if vonage_key and vonage_key != 'your_vonage_api_key' else '❌ Manquant ou par défaut'}")
    print(f"VONAGE_API_SECRET: {'✅ Configuré' if vonage_secret and vonage_secret != 'your_vonage_api_secret' else '❌ Manquant ou par défaut'}")
    print(f"VONAGE_WHATSAPP_FROM_SANDBOX: {vonage_from}")
    print(f"VONAGE_WHATSAPP_TO_SANDBOX: {vonage_to}")
    
    print("\n" + "=" * 50)
    print("📋 RECOMMANDATIONS:")
    print("1. Vérifiez que vos clés API sont correctes dans .env")
    print("2. Pour Twilio: Utilisez le numéro sandbox +14155238886")
    print("3. Pour Vonage: Utilisez le sandbox WhatsApp")
    print("4. Testez d'abord avec un numéro de test")

if __name__ == "__main__":
    test_whatsapp_config()
