from dotenv import load_dotenv

load_dotenv()

# Unifie l'envoi via Vonage puis fallback Twilio, pour garder le même format de message
def send_whatsapp_message(message: str, to_number: str = None):
    try:
        from frontend.whatsapp_notify import send_whatsapp_message_unified
        result = send_whatsapp_message_unified(message, to=to_number)
        # Retourner True/False pour compatibilité existante
        if result is True:
            return True
        if isinstance(result, dict) and result.get('status') not in ['error', 'failed']:
            return True
        print(f"Erreur WhatsApp (unified): {result}")
        return False
    except Exception as e:
        print(f"Erreur WhatsApp (unified exception): {e}")
        return False