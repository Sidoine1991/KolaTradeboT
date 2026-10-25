import os
import requests
from dotenv import load_dotenv

load_dotenv()

TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID')  # Peut être un @username ou un ID numérique


def send_telegram_message(message: str):
    """
    Envoie un message Telegram à l'utilisateur via le bot configuré.
    """
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        return False
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    data = {
        'chat_id': TELEGRAM_CHAT_ID,
        'text': message,
        'parse_mode': 'HTML'
    }
    try:
        response = requests.post(url, data=data, timeout=10)
        return response.status_code == 200
    except Exception:
        return False 