import os
from dotenv import load_dotenv
import requests

load_dotenv()
sid = os.getenv("TWILIO_ACCOUNT_SID")
token = os.getenv("TWILIO_AUTH_TOKEN")
from_whatsapp = os.getenv("TWILIO_WHATSAPP_FROM")
to_whatsapp = os.getenv("TWILIO_WHATSAPP_TO")

url = f"https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json"
data = {
    'To': to_whatsapp,
    'From': from_whatsapp,
    'Body': "Test WhatsApp TradBOT"
}
response = requests.post(url, data=data, auth=(sid, token))
print(response.status_code, response.text)