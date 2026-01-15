import os
from dotenv import load_dotenv

load_dotenv()
 
MT5_LOGIN = int(os.getenv('MT5_LOGIN', 0))
MT5_PASSWORD = os.getenv('MT5_PASSWORD', '')
MT5_SERVER = os.getenv('MT5_SERVER', '')
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY', '') 