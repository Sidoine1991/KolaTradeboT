import os
import requests
from dotenv import load_dotenv

load_dotenv()

TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID')
TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN')
TWILIO_WHATSAPP_FROM = os.getenv('TWILIO_WHATSAPP_FROM')  # format: 'whatsapp:+14155238886'
TWILIO_WHATSAPP_TO = os.getenv('TWILIO_WHATSAPP_TO')      # format: 'whatsapp:+33XXXXXXXXX'

def send_whatsapp_message(message, to=None, interactive=None):
    """
    Envoie un message WhatsApp via Twilio Programmable Messaging (2010-04-01 API).
    - message: texte simple (Body). Pour les templates/boutons, utiliser l'API Content (non gérée ici).
    """
    ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "")
    AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
    FROM = os.getenv("TWILIO_WHATSAPP_FROM", "")
    TO = to or os.getenv("TWILIO_WHATSAPP_TO", "")
    if not (ACCOUNT_SID and AUTH_TOKEN and FROM and TO):
        return {"status": "error", "detail": "Missing Twilio env vars (SID/TOKEN/FROM/TO)"}
    # Twilio classic endpoint for WhatsApp text
    url = f"https://api.twilio.com/2010-04-01/Accounts/{ACCOUNT_SID}/Messages.json"
    data = {
        "To": TO,
        "From": FROM,
        "Body": message or ""
    }
    try:
        resp = requests.post(url, data=data, auth=(ACCOUNT_SID, AUTH_TOKEN), timeout=15)
        # Normalize response
        try:
            j = resp.json()
        except Exception:
            j = {"raw": resp.text}
        if resp.status_code in (200, 201):
            sid = j.get("sid") if isinstance(j, dict) else None
            return {"status": "accepted", "provider": "twilio", "sid": sid, "raw": j}
        return {"status": "error", "provider": "twilio", "code": resp.status_code, "detail": j}
    except Exception as e:
        return {"status": "error", "provider": "twilio", "detail": str(e)}

# Exemple d'appel pour un menu principal interactif (3 boutons) :
# send_whatsapp_message(
#     message=None,
#     interactive={
#         "type": "button",
#         "body": {"text": "Que veux-tu faire ?"},
#         "action": {
#             "buttons": [
#                 {"type": "reply", "reply": {"id": "statut", "title": "Statut du bot"}},
#                 {"type": "reply", "reply": {"id": "symboles", "title": "Liste des symboles"}},
#                 {"type": "reply", "reply": {"id": "ordre", "title": "Passer un ordre"}}
#             ]
#         }
#     }
# ) 

def send_sms_vonage(message, to=None):
    """
    Envoie un SMS via Vonage (Nexmo) en utilisant l'API REST directement (fallback universel).
    - message : texte du SMS
    - to : numéro destinataire (par défaut, celui de la config)
    """
    VONAGE_API_KEY = os.getenv("VONAGE_API_KEY", "your_api_key")
    VONAGE_API_SECRET = os.getenv("VONAGE_API_SECRET", "your_api_secret")
    VONAGE_FROM = os.getenv("VONAGE_SMS_FROM", "TradBOT")
    TO = to or os.getenv("VONAGE_SMS_TO", "336XXXXXXXX")
    url = "https://rest.nexmo.com/sms/json"
    payload = {
        "api_key": VONAGE_API_KEY,
        "api_secret": VONAGE_API_SECRET,
        "from": VONAGE_FROM,
        "to": TO,
        "text": message,
    }
    try:
        resp = requests.post(url, data=payload, timeout=10)
        print("[SMS VONAGE] Response:", resp.status_code, resp.text)
        return resp.json()
    except Exception as e:
        print(f"[SMS ERROR] Vonage REST: {e}")
        return None

# Exemple d'appel :
# send_sms_vonage("Alerte : tendance consolidée bullish sur EURUSD !") 

def send_whatsapp_vonage_sandbox(message, to=None, interactive=None):
    """
    Envoie un message WhatsApp via Vonage Messages API.
    Utilise la structure simple qui fonctionne parfaitement.
    """
    VONAGE_API_KEY = os.getenv("VONAGE_API_KEY", "1a1de47f")
    VONAGE_API_SECRET = os.getenv("VONAGE_API_SECRET", "Vkb6ia33anmNAyOE")
    VONAGE_FROM = os.getenv("VONAGE_WHATSAPP_FROM_SANDBOX", "14157386102")
    TO = to or os.getenv("VONAGE_WHATSAPP_TO_SANDBOX", "22996911346")
    
    # API qui fonctionne parfaitement
    url = "https://messages-sandbox.nexmo.com/v1/messages"
    
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    # Structure simple qui fonctionne (testée et validée)
    payload = {
        "from": VONAGE_FROM,
        "to": TO,
        "message_type": "text",
        "text": message,
        "channel": "whatsapp"
    }
    
    try:
        resp = requests.post(
            url,
            auth=(VONAGE_API_KEY, VONAGE_API_SECRET),
            json=payload,
            headers=headers,
            timeout=10
        )
        print(f"[WHATSAPP VONAGE] Status: {resp.status_code}, Response: {resp.text}")
        
        if resp.status_code == 202:
            return {"status": "accepted", "message_uuid": resp.json().get("message_uuid")}
        else:
            return {"status": "error", "code": resp.status_code, "detail": resp.text}
            
    except Exception as e:
        print(f"[WHATSAPP ERROR] Vonage: {e}")
        return {"status": "error", "detail": str(e)} 

def send_whatsapp_message_unified(message, to=None, interactive=None):
    """
    Envoi unifié selon le type de message:
    - SIGNAL (🟢/🔴): Twilio en priorité, fallback Vonage si échec/quota.
    - Tendance consolidée: Vonage uniquement (Twilio bloqué).
    - Autres: Vonage d'abord, fallback Twilio.
    """
    try:
        is_signal = isinstance(message, str) and message.lstrip().startswith(("🟢 SIGNAL", "🔴 SIGNAL"))
        is_trend = isinstance(message, str) and message.strip().startswith("📊 Tendance consolidée")

        # 1) SIGNALS → Twilio d'abord, fallback Vonage
        if is_signal:
            t_res = send_whatsapp_message(message, to, interactive=interactive)
            if isinstance(t_res, dict) and t_res.get("status") == "accepted":
                return t_res
            # Fallback Vonage
            return send_whatsapp_vonage_sandbox(message, to, interactive=interactive)

        # 2) Tendance consolidée → Vonage uniquement
        if is_trend:
            return send_whatsapp_vonage_sandbox(message, to, interactive=interactive)

        # 3) Autres → Vonage d'abord, fallback Twilio
        v_result = send_whatsapp_vonage_sandbox(message, to, interactive=interactive)
        if isinstance(v_result, dict) and v_result.get("status") == "accepted":
            return v_result
        return send_whatsapp_message(message, to, interactive=interactive)
    except Exception as e:
        print(f"[UNIFIED ERROR] Vonage exception: {e}")
        # Fallback Twilio
        try:
            is_trend = isinstance(message, str) and message.strip().startswith("📊 Tendance consolidée")
            if is_trend:
                return {"status": "error", "detail": "Twilio blocked for this message format", "provider": "twilio"}
            return send_whatsapp_message(message, to, interactive=interactive)
        except Exception as e2:
            return {"status": "error", "detail": f"Twilio exception: {e2}"}