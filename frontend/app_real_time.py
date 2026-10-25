import sys
import os
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
from backend.advanced_ml_predictor import AdvancedMLPredictor
from backend.setup_detector import SetupDetector
from backend.risk.risk_manager import RiskManager
from frontend.backend_connector import BackendConnector
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import streamlit as st
from streamlit_autorefresh import st_autorefresh
import base64
import warnings
from dotenv import load_dotenv
import time
import threading
import json
import requests as _rq
import yfinance as yf
import requests
import json
from datetime import datetime

load_dotenv()
warnings.filterwarnings('ignore')

def play_alert_sound():
    """Joue un bip sonore simple pour les alertes de signaux"""
    try:
        # Utiliser le système audio HTML5 via JavaScript
        st.markdown("""
        <script>
        var audio = new Audio('data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvLZiTYIG2m98OScTgwOUarm7blmGgU7k9n1unEiBC13yO/eizEIHWq+8+OWT');
        audio.play();
        </script>
        """, unsafe_allow_html=True)
    except:
        pass  # Ignorer les erreurs audio

# -----------------------------
# Minimal signal API (Option A)
# -----------------------------
SIGNAL_DATA = {"signals": []}

def _ensure_signal_api():
    """Vérifie si l'API est disponible, sinon utilise le fichier JSON."""
    if st.session_state.get("signal_api_started"):
        return True
    try:
        response = _rq.get("http://localhost:8001/health", timeout=2)
        if response.status_code == 200:
            st.session_state.signal_api_started = True
            st.sidebar.success("✅ API Signaux connectée sur http://localhost:8001")
            return True
    except Exception:
        pass
    st.session_state.signal_api_started = False
    st.sidebar.info("📁 Utilisation du fichier signals.json (API non démarrée)")
    return False

def publish_signal(symbol: str, side: str, price: float, sl: float, tp: float, confidence: float,
                   valid_from: str, valid_to: str, source: str):
    """Push a signal to in-memory store and fallback file for MT5 consumption."""
    try:
        entry = {
            "symbol": symbol,
            "side": side,
            "price": float(price),
            "sl": float(sl),
            "tp": float(tp),
            "confidence": float(confidence),
            "valid_from": valid_from,
            "valid_to": valid_to,
            "source": source,
            "ts": datetime.now().isoformat(timespec="seconds")
        }
        SIGNAL_DATA.setdefault("signals", []).append(entry)

        # Envoyer automatiquement par WhatsApp
        try:
            from frontend.whatsapp_notify import send_whatsapp_message_unified
            pip_size = 0.0001 if "JPY" not in symbol else 0.01
            if "Index" in symbol or "Boom" in symbol or "Crash" in symbol:
                pip_size = 0.1

            sl_pips = abs(price - sl) / pip_size
            tp_pips = abs(tp - price) / pip_size

            risk_ok = sl_pips <= 10
            reward_ok = tp_pips >= 30

            if risk_ok and reward_ok:
                emoji = "🟢" if side == "BUY" else "🔴"
                message = f"""{emoji} SIGNAL {source.upper()}
📊 {symbol}
🎯 {side} @ {price:.3f}
🛡️ SL: {sl:.3f} ({sl_pips:.1f} pips)
🎯 TP: {tp:.3f} ({tp_pips:.1f} pips)
⚡ Confiance: {confidence*100:.0f}%
⏰ Valide jusqu'à: {valid_to}"""
                send_whatsapp_message_unified(message)
                print(f"📱 Signal WhatsApp envoyé: {symbol} {side}")
            else:
                print(f"⚠️ Signal rejeté - Critères non respectés: SL={sl_pips:.1f}pips, TP={tp_pips:.1f}pips")
        except Exception as e:
            print(f"❌ Erreur envoi WhatsApp: {e}")

        # Fallback dump for consumers without API
        try:
            with open("signals.json", "w", encoding="utf-8") as f:
                json.dump(SIGNAL_DATA, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"Error dumping signals to JSON: {e}")
    except Exception as e:
        print(f"Error in publish_signal: {e}")

def fetch_json_with_retries(url: str, params: dict, attempts: int = 3, timeout: int = 8):
    """Helper HTTP avec retries pour API modernes."""
    last_err = None
    for _ in range(attempts):
        try:
            resp = _rq.get(url, params=params, timeout=timeout)
            if resp.status_code == 200:
                return resp.json()
            last_err = f"HTTP {resp.status_code}"
        except Exception as e:
            last_err = str(e)
            time.sleep(0.5)
    return {"status": "error", "detail": last_err}

# Configuration de la page Streamlit
st.set_page_config(
    page_title="TradBOT Pro - Trading en Temps Réel",
    page_icon="📈",
    layout="wide",
    initial_sidebar_state="expanded",
    menu_items={
        'Get Help': 'https://github.com/your-repo/tradbot',
        'Report a bug': "https://github.com/your-repo/tradbot/issues",
        'About': "# TradBOT Pro\nApplication de trading automatisé avec IA"
    }
)

# Fonctions d'indicateurs techniques
def calculate_atr(df, period=14):
    """Calcule l'Average True Range (ATR)"""
    if len(df) < period:
        return pd.Series([np.nan] * len(df), index=df.index)
    
    high_low = df['high'] - df['low']
    high_close = np.abs(df['high'] - df['close'].shift())
    low_close = np.abs(df['low'] - df['close'].shift())
    
    true_range = np.maximum(high_low, np.maximum(high_close, low_close))
    atr = true_range.rolling(window=period).mean()
    
    return atr

def calculate_bollinger_bands(df, period=20, std_dev=2):
    """Calcule les Bandes de Bollinger"""
    if len(df) < period:
        return pd.Series([np.nan] * len(df), index=df.index), pd.Series([np.nan] * len(df), index=df.index), pd.Series([np.nan] * len(df), index=df.index)
    
    sma = df['close'].rolling(window=period).mean()
    std = df['close'].rolling(window=period).std()
    
    upper_band = sma + (std * std_dev)
    lower_band = sma - (std * std_dev)
    
    return upper_band, sma, lower_band

def calculate_ema(df, period=200):
    """Calcule l'Exponential Moving Average (EMA)"""
    if len(df) < period:
        return pd.Series([np.nan] * len(df), index=df.index)
    
    return df['close'].ewm(span=period).mean()

def calculate_supertrend(df, period=10, multiplier=3.0):
    """Calcule l'indicateur Supertrend"""
    if len(df) < period:
        return pd.Series([np.nan] * len(df), index=df.index)
    
    # Calculer ATR
    atr = calculate_atr(df, period)
    
    # Calculer les bandes hautes et basses
    hl2 = (df['high'] + df['low']) / 2
    upper_band = hl2 + (multiplier * atr)
    lower_band = hl2 - (multiplier * atr)
    
    # Initialiser les séries
    supertrend = pd.Series(index=df.index, dtype=float)
    direction = pd.Series(index=df.index, dtype=int)
    
    # Première valeur
    supertrend.iloc[0] = upper_band.iloc[0]
    direction.iloc[0] = 1
    
    # Calculer le Supertrend
    for i in range(1, len(df)):
        # Bandes finales
        if upper_band.iloc[i] < supertrend.iloc[i-1] or df['close'].iloc[i-1] > supertrend.iloc[i-1]:
            upper_band.iloc[i] = upper_band.iloc[i]
        else:
            upper_band.iloc[i] = supertrend.iloc[i-1]
            
        if lower_band.iloc[i] > supertrend.iloc[i-1] or df['close'].iloc[i-1] < supertrend.iloc[i-1]:
            lower_band.iloc[i] = lower_band.iloc[i]
        else:
            lower_band.iloc[i] = supertrend.iloc[i-1]
        
        # Direction et Supertrend
        if supertrend.iloc[i-1] == upper_band.iloc[i-1]:
            if df['close'].iloc[i] <= upper_band.iloc[i]:
                supertrend.iloc[i] = upper_band.iloc[i]
                direction.iloc[i] = 1
            else:
                supertrend.iloc[i] = lower_band.iloc[i]
                direction.iloc[i] = -1
        else:
            if df['close'].iloc[i] >= lower_band.iloc[i]:
                supertrend.iloc[i] = lower_band.iloc[i]
                direction.iloc[i] = -1
            else:
                supertrend.iloc[i] = upper_band.iloc[i]
                direction.iloc[i] = 1
    
    return supertrend

# CSS moderne et professionnel
st.markdown("""
<style>
/* Reset et base */
.main .block-container {
    padding-top: 0.5rem;
    padding-bottom: 1rem;
    padding-left: 1rem;
    padding-right: 1rem;
    max-width: 100%;
}
/* Header personnalisé */
.header-container {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    padding: 1rem 2rem;
    margin: -1rem -1rem 2rem -1rem;
    border-radius: 0 0 15px 15px;
    box-shadow: 0 4px 15px rgba(0,0,0,0.1);
}
.header-title {
    color: white;
    font-size: 2.5rem;
    font-weight: 700;
    margin: 0;
    text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
}
.header-subtitle {
    color: rgba(255,255,255,0.9);
    font-size: 1.1rem;
    margin: 0.5rem 0 0 0;
    font-weight: 300;
}
.status-indicators {
    display: flex;
    gap: 1rem;
    margin-top: 1rem;
    flex-wrap: wrap;
}
.status-badge {
    background: rgba(255,255,255,0.2);
    padding: 0.5rem 1rem;
    border-radius: 20px;
    color: white;
    font-size: 0.9rem;
    font-weight: 500;
    backdrop-filter: blur(10px);
    border: 1px solid rgba(255,255,255,0.3);
}
.status-badge.success { background: rgba(46, 204, 113, 0.8); }
.status-badge.error { background: rgba(231, 76, 60, 0.8); }
.status-badge.warning { background: rgba(241, 196, 15, 0.8); }
/* Graphique optimisé */
.stPlotlyChart {
    width: 100% !important;
    height: 800px !important;
}
/* Cards modernes */
.metric-card {
    background: white;
    padding: 1.5rem;
    border-radius: 12px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.08);
    border: 1px solid rgba(0,0,0,0.05);
    margin-bottom: 1rem;
}
.metric-value { font-size: 2rem; font-weight: 700; color: #2c3e50; margin: 0; }
.metric-label { font-size: 0.9rem; color: #7f8c8d; margin: 0.5rem 0 0 0; text-transform: uppercase; letter-spacing: 0.5px; }
/* Sidebar améliorée */
.css-1d391kg {
    background: linear-gradient(180deg, #f8f9fa 0%, #e9ecef 100%);
}
/* Boutons modernes */
.stButton > button {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border: none;
    border-radius: 8px;
    padding: 0.5rem 1rem;
    font-weight: 500;
    transition: all 0.3s ease;
    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
}
.stButton > button:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 15px rgba(0,0,0,0.2);
}
/* Onglets personnalisés */
.stTabs [data-baseweb="tab-list"] { gap: 1rem; }
.stTabs [data-baseweb="tab"] { background: white; border-radius: 8px; padding: 0.5rem 1rem; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
.stTabs [aria-selected="true"] { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
/* Responsive */
@media (max-width: 768px) {
    .header-title { font-size: 2rem; }
    .status-indicators { flex-direction: column; }
}
</style>
""", unsafe_allow_html=True)

# Ajout du répertoire racine au PYTHONPATH
try:
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    if project_root not in sys.path:
        sys.path.insert(0, project_root)
except NameError:
    pass

# Imports du backend réel
try:
    from backend.mt5_connector import (
        connect, shutdown, get_ohlc, get_all_symbols, get_symbols_by_category,
        get_symbol_info, test_connection, TIMEFRAME_MAPPING, get_open_positions,
        get_trade_history, get_current_price, is_connected
    )
    from backend.spike_detector import (
        detect_spikes, analyze_spike_pattern, predict_next_spike,
        predict_spike_ml, batch_predict_spike_ml
    )
    from backend.technical_analysis import add_technical_indicators
    from backend.features import compute_features
    from backend.advanced_ml_predictor import AdvancedMLPredictor
    from backend.setup_detector import SetupDetector
    from backend.risk_manager import RiskManager
    from backend.signal_generator import generate_signal
    from backend.chart_utils import create_candlestick_chart, add_technical_indicators_to_chart, add_ml_predictions_to_chart
    MT5_AVAILABLE = True
except ImportError as e:
    st.error(f"❌ Erreur d'import des modules backend: {e}")
    st.error("Assurez-vous que MetaTrader 5 est installé et configuré")
    MT5_AVAILABLE = False

# Initialisation des variables de session
if 'mt5_connected' not in st.session_state:
    st.session_state.mt5_connected = False
if 'current_symbol' not in st.session_state:
    st.session_state.current_symbol = "Boom 1000 Index"
if 'current_timeframe' not in st.session_state:
    st.session_state.current_timeframe = '1m'
if 'real_time_data' not in st.session_state:
    st.session_state.real_time_data = pd.DataFrame()
if 'last_update' not in st.session_state:
    st.session_state.last_update = None
if 'ml_predictor' not in st.session_state:
    st.session_state.ml_predictor = AdvancedMLPredictor()
if 'setup_detector' not in st.session_state:
    st.session_state.setup_detector = SetupDetector()
if 'trading_signals' not in st.session_state:
    st.session_state.trading_signals = {}
if 'risk_manager' not in st.session_state:
    st.session_state.risk_manager = RiskManager(account_balance=1000.0)
if 'last_timeframe' not in st.session_state:
    st.session_state.last_timeframe = st.session_state.current_timeframe
if 'backend_connector' not in st.session_state:
    st.session_state.backend_connector = BackendConnector()
if 'ai_enabled' not in st.session_state:
    st.session_state.ai_enabled = True
if 'robot_integration' not in st.session_state:
    st.session_state.robot_integration = True

# Essayer de charger les modèles ML pré-entraînés
if not st.session_state.ml_predictor.is_trained:
    try:
        if st.session_state.ml_predictor.load_models():
            st.session_state.ml_predictor.is_trained = True
    except Exception:
        pass

# Configuration audio
try:
    AUDIO_FILE_PATH = os.path.join(os.path.dirname(__file__), 'static', 'beep.wav')
    encoded_audio = None
    if os.path.exists(AUDIO_FILE_PATH):
        with open(AUDIO_FILE_PATH, "rb") as f:
            encoded_audio = base64.b64encode(f.read()).decode()
except NameError:
    encoded_audio = None

def play_alert_sound():
    """Joue un son d'alerte"""
    if encoded_audio:
        st.markdown(f"""
        <audio autoplay>
        <source src="data:audio/wav;base64,{encoded_audio}" type="audio/wav">
        </audio>
        """, unsafe_allow_html=True)

def get_real_time_price(symbol):
    """Récupère le prix actuel en temps réel depuis MT5"""
    if not MT5_AVAILABLE or not st.session_state.mt5_connected:
        return None
    try:
        price_info = get_current_price(symbol)
        if price_info and isinstance(price_info, dict):
            if 'last' in price_info and price_info['last'] > 0:
                return price_info['last']
            elif 'bid' in price_info and 'ask' in price_info and price_info['bid'] > 0 and price_info['ask'] > 0:
                return (price_info['bid'] + price_info['ask']) / 2
            elif isinstance(price_info, (int, float)) and price_info > 0:
                return price_info
    except Exception as e:
        st.error(f"Erreur lors de la récupération du prix pour {symbol}: {e}")
    return None

def get_ask_bid_prices(symbol):
    """Récupère les prix ASK et BID depuis MT5"""
    if not MT5_AVAILABLE or not st.session_state.mt5_connected:
        return None, None
    try:
        price_info = get_current_price(symbol)
        if price_info and isinstance(price_info, dict):
            ask = price_info.get('ask', None)
            bid = price_info.get('bid', None)
            if ask and bid and ask > 0 and bid > 0:
                return ask, bid
    except Exception as e:
        st.error(f"Erreur lors de la récupération des prix ASK/BID pour {symbol}: {e}")
    return None, None

def send_sms_vonage(message, phone_number=None):
    """Envoie un SMS via Vonage (Nexmo) avec gestion des quotas"""
    try:
        vonage_api_key = os.getenv('VONAGE_API_KEY')
        vonage_api_secret = os.getenv('VONAGE_API_SECRET')
        phone = phone_number or os.getenv('PHONE_NUMBER')
        
        if not vonage_api_key or not vonage_api_secret or not phone:
            return False  # Silencieux si non configuré
            
        url = "https://rest.nexmo.com/sms/json"
        data = {
            'api_key': vonage_api_key,
            'api_secret': vonage_api_secret,
            'to': phone,
            'from': 'TradBOT',
            'text': message
        }
        
        response = requests.post(url, data=data, timeout=10)
        result = response.json()
        
        if result.get('messages', [{}])[0].get('status') == '0':
            st.success(f"✅ SMS Vonage envoyé à {phone}")
            return True
        else:
            error_msg = result.get('messages', [{}])[0].get('error-text', 'Erreur inconnue')
            
            # Gestion spécifique des erreurs de quota
            if 'quota' in error_msg.lower() or 'limit' in error_msg.lower() or 'exceeded' in error_msg.lower():
                st.warning(f"⚠️ Quota Vonage dépassé: {error_msg}")
                # Désactiver temporairement Vonage
                st.session_state.sms_provider = 'twilio' if st.session_state.get('twilio_available', False) else 'none'
                return False
            else:
                st.error(f"❌ Erreur SMS Vonage: {error_msg}")
                return False
            
    except requests.exceptions.Timeout:
        st.warning("⏰ Timeout SMS Vonage - Tentative suivante")
        return False
    except Exception as e:
        st.error(f"❌ Erreur envoi SMS Vonage: {e}")
        return False

def send_sms_twilio(message, phone_number=None):
    """Envoie un SMS via Twilio avec gestion des quotas"""
    try:
        twilio_sid = os.getenv('TWILIO_ACCOUNT_SID')
        twilio_token = os.getenv('TWILIO_AUTH_TOKEN')
        twilio_from = os.getenv('TWILIO_PHONE_NUMBER')
        phone = phone_number or os.getenv('PHONE_NUMBER')
        
        if not all([twilio_sid, twilio_token, twilio_from, phone]):
            return False  # Silencieux si non configuré
            
        url = f"https://api.twilio.com/2010-04-01/Accounts/{twilio_sid}/Messages.json"
        data = {
            'From': twilio_from,
            'To': phone,
            'Body': message
        }
        
        response = requests.post(url, data=data, auth=(twilio_sid, twilio_token), timeout=10)
        
        if response.status_code == 201:
            st.success(f"✅ SMS Twilio envoyé à {phone}")
            return True
        else:
            error_text = response.text
            
            # Gestion spécifique des erreurs de quota
            if 'quota' in error_text.lower() or 'limit' in error_text.lower() or 'exceeded' in error_text.lower():
                st.warning(f"⚠️ Quota Twilio dépassé: {error_text}")
                # Désactiver temporairement Twilio
                st.session_state.sms_provider = 'vonage' if st.session_state.get('vonage_available', False) else 'none'
                return False
            else:
                st.error(f"❌ Erreur SMS Twilio: {error_text}")
                return False
            
    except requests.exceptions.Timeout:
        st.warning("⏰ Timeout SMS Twilio - Tentative suivante")
        return False
    except Exception as e:
        st.error(f"❌ Erreur envoi SMS Twilio: {e}")
        return False

def send_sms_firebase(message, phone_number=None):
    """Envoie un SMS via Firebase (Google) - 10,000 SMS gratuits/mois"""
    try:
        project_id = os.getenv('FIREBASE_PROJECT_ID')
        private_key = os.getenv('FIREBASE_PRIVATE_KEY')
        client_email = os.getenv('FIREBASE_CLIENT_EMAIL')
        token_uri = os.getenv('FIREBASE_TOKEN_URI', 'https://oauth2.googleapis.com/token')
        phone = phone_number or os.getenv('PHONE_NUMBER')
        
        if not all([project_id, private_key, client_email, phone]):
            return False  # Silencieux si non configuré
        
        # Créer le token JWT pour l'authentification
        import jwt
        import time
        
        now = int(time.time())
        payload = {
            'iss': client_email,
            'scope': 'https://www.googleapis.com/auth/firebase.messaging',
            'aud': token_uri,
            'iat': now,
            'exp': now + 3600
        }
        
        # Créer le token JWT
        token = jwt.encode(payload, private_key, algorithm='RS256')
        
        # URL de l'API Firebase
        url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
        
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        
        # Payload pour l'envoi SMS via Firebase
        data = {
            'message': {
                'token': phone,  # Numéro de téléphone comme token
                'notification': {
                    'title': 'Trading Signal',
                    'body': message
                },
                'data': {
                    'type': 'sms',
                    'message': message
                }
            }
        }
        
        response = requests.post(url, headers=headers, json=data, timeout=10)
        
        if response.status_code == 200:
            st.success(f"✅ SMS Firebase envoyé à {phone} (Gratuit: 10k/mois)")
            return True
        else:
            error_text = response.text
            
            # Gestion spécifique des erreurs de quota
            if 'quota' in error_text.lower() or 'limit' in error_text.lower() or 'exceeded' in error_text.lower():
                st.warning(f"⚠️ Quota Firebase dépassé: {error_text}")
                # Basculement vers Twilio ou Vonage
                if os.getenv('TWILIO_ACCOUNT_SID'):
                    st.session_state.sms_provider = 'twilio'
                elif os.getenv('VONAGE_API_KEY'):
                    st.session_state.sms_provider = 'vonage'
                else:
                    st.session_state.sms_provider = 'none'
                return False
            else:
                st.error(f"❌ Erreur SMS Firebase: {error_text}")
                return False
            
    except requests.exceptions.Timeout:
        st.warning("⏰ Timeout SMS Firebase - Tentative suivante")
        return False
    except Exception as e:
        st.error(f"❌ Erreur envoi SMS Firebase: {e}")
        return False

def send_whatsapp_twilio(message, phone_number=None):
    """Envoie un message WhatsApp via Twilio"""
    try:
        twilio_sid = os.getenv('TWILIO_ACCOUNT_SID')
        twilio_token = os.getenv('TWILIO_AUTH_TOKEN')
        whatsapp_from = os.getenv('WHATSAPP_FROM_NUMBER')
        phone = phone_number or os.getenv('WHATSAPP_NUMBER')
        
        if not all([twilio_sid, twilio_token, whatsapp_from, phone]):
            return False  # Silencieux si non configuré
            
        url = f"https://api.twilio.com/2010-04-01/Accounts/{twilio_sid}/Messages.json"
        data = {
            'From': f"whatsapp:{whatsapp_from}",
            'To': f"whatsapp:{phone}",
            'Body': message
        }
        
        response = requests.post(url, data=data, auth=(twilio_sid, twilio_token))
        
        if response.status_code == 201:
            st.success(f"✅ WhatsApp Twilio envoyé à {phone}")
            return True
        else:
            st.error(f"❌ Erreur WhatsApp Twilio: {response.text}")
            return False
            
    except Exception as e:
        st.error(f"❌ Erreur envoi WhatsApp Twilio: {e}")
        return False

def send_whatsapp_api(message, phone_number=None):
    """Envoie un message WhatsApp via API directe"""
    try:
        api_url = os.getenv('WHATSAPP_API_URL')
        access_token = os.getenv('WHATSAPP_ACCESS_TOKEN')
        phone = phone_number or os.getenv('WHATSAPP_NUMBER')
        
        if not all([api_url, access_token, phone]):
            return False  # Silencieux si non configuré
            
        headers = {
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json'
        }
        
        data = {
            'to': phone,
            'text': message
        }
        
        response = requests.post(api_url, headers=headers, json=data)
        
        if response.status_code == 200:
            st.success(f"✅ WhatsApp API envoyé à {phone}")
            return True
        else:
            st.error(f"❌ Erreur WhatsApp API: {response.text}")
            return False
            
    except Exception as e:
        st.error(f"❌ Erreur envoi WhatsApp API: {e}")
        return False

def send_trading_signal(signal_type, symbol, price, confidence, direction=None):
    """Envoie un signal de trading via SMS et WhatsApp avec limitation de fréquence"""
    try:
        # Vérifier la limitation de fréquence (1 signal par minute par type)
        now = datetime.now()
        signal_key = f"{signal_type}_{symbol}_{direction}"
        
        # Initialiser le cache des signaux envoyés
        if 'sent_signals' not in st.session_state:
            st.session_state.sent_signals = {}
        
        # Vérifier si un signal similaire a été envoyé récemment
        if signal_key in st.session_state.sent_signals:
            last_sent = st.session_state.sent_signals[signal_key]
            time_diff = (now - last_sent).total_seconds()
            
            # Limiter à 1 signal par minute par type
            if time_diff < 60:
                st.info(f"⏰ Signal {signal_type} déjà envoyé il y a {int(time_diff)}s - Attendre 1 minute")
                return True  # Considérer comme succès pour éviter les tentatives répétées
        
        # Construire le message
        timestamp = now.strftime("%H:%M:%S")
        message = f"🚨 SIGNAL {signal_type}\n"
        message += f"📊 {symbol}\n"
        message += f"💰 Prix: {price:.5f}\n"
        message += f"📈 Direction: {direction or 'N/A'}\n"
        message += f"🎯 Confiance: {confidence:.1%}\n"
        message += f"⏰ {timestamp}\n"
        message += f"🤖 TradBOT"
        
        # Récupérer les configurations
        sms_provider = st.session_state.get('sms_provider', 'none')
        whatsapp_provider = st.session_state.get('whatsapp_provider', 'none')
        
        success = False
        attempts = 0
        max_attempts = 2  # Limiter les tentatives
        
        # Envoyer SMS (une seule tentative)
        if sms_provider != 'none' and attempts < max_attempts:
            attempts += 1
            if sms_provider == 'firebase':
                success = send_sms_firebase(message) or success
            elif sms_provider == 'vonage':
                success = send_sms_vonage(message) or success
            elif sms_provider == 'twilio':
                success = send_sms_twilio(message) or success
                
        # Envoyer WhatsApp (une seule tentative)
        if whatsapp_provider != 'none' and attempts < max_attempts:
            attempts += 1
            if whatsapp_provider == 'twilio':
                success = send_whatsapp_twilio(message) or success
            elif whatsapp_provider == 'api':
                success = send_whatsapp_api(message) or success
        
        # Enregistrer l'envoi réussi
        if success:
            st.session_state.sent_signals[signal_key] = now
            st.success(f"✅ Signal {signal_type} envoyé avec succès")
        else:
            st.warning(f"⚠️ Aucun provider configuré pour envoyer le signal {signal_type}")
            
        return success
            
    except Exception as e:
        st.error(f"❌ Erreur envoi signal: {e}")
        return False

def get_real_time_ohlc(symbol, timeframe='1m', count=300):
    """Récupère les données OHLC en temps réel depuis MT5 (sans cache)"""
    if not MT5_AVAILABLE or not st.session_state.mt5_connected:
        return pd.DataFrame()
    try:
        df = get_ohlc(symbol, timeframe, count)
        if df is not None and not df.empty:
            if 'timestamp' not in df.columns:
                df['timestamp'] = pd.to_datetime(df['time'], unit='s') if 'time' in df.columns else df.index
            df = add_technical_indicators(df, ['RSI', 'MACD', 'BB'])
            print(f"📊 Données OHLC récupérées: {len(df)} bougies pour {symbol}")
            print(f"📅 Dernière bougie: {df['timestamp'].iloc[-1]} - Prix: {df['close'].iloc[-1]:.5f}")
            return df
    except Exception as e:
        st.error(f"Erreur lors de la récupération des données OHLC pour {symbol}: {e}")
    return pd.DataFrame()

def _detect_last_impulse(df: pd.DataFrame, pivot_window: int = 5):
    """Détecte la dernière impulsion (direction, high, low) via pivots simples."""
    if df is None or df.empty or not {'high', 'low', 'close'}.issubset(df.columns):
        return None, None, None
    tail = df.tail(300)
    highs_mask = tail['high'].rolling(window=pivot_window, center=True).max() == tail['high']
    lows_mask = tail['low'].rolling(window=pivot_window, center=True).min() == tail['low']
    pivot_highs = tail[highs_mask]
    pivot_lows = tail[lows_mask]
    if pivot_highs.empty or pivot_lows.empty:
        return None, None, None
    last_high_idx = pivot_highs.index[-1]
    last_low_idx = pivot_lows.index[-1]
    swing_high = float(tail.loc[last_high_idx, 'high'])
    swing_low = float(tail.loc[last_low_idx, 'low'])
    if last_high_idx > last_low_idx and swing_high > swing_low:
        return "up", swing_high, swing_low
    elif last_low_idx > last_high_idx and swing_high > swing_low:
        return "down", swing_high, swing_low
    else:
        recent = tail['close'].tail(20)
        direction = "up" if recent.iloc[-1] >= recent.iloc[0] else "down"
        return direction, max(tail['high'][-50:]), min(tail['low'][-50:])

def _compute_fib_levels(swing_high: float, swing_low: float) -> dict:
    """Calcule niveaux Fibo clés."""
    if swing_high is None or swing_low is None:
        return {}
    rng = swing_high - swing_low
    if rng <= 0:
        return {}
    return {
        '0': swing_low,
        '0.5': swing_low + 0.5 * rng,
        '0.618': swing_low + 0.618 * rng,
        '0.705': swing_low + 0.705 * rng,
        '0.78': swing_low + 0.78 * rng,
        '0.88': swing_low + 0.88 * rng,
        '1': swing_high,
    }

def evaluate_ote_strategy(current_price: float, direction: str, fib_levels: dict) -> dict:
    """Applique la règle de stratégie OTE."""
    try:
        if not fib_levels or current_price is None or current_price <= 0:
            return {'bias': None, 'zone': None, 'message': 'Données insuffisantes'}
        l0, l05, l078, l1 = fib_levels.get('0'), fib_levels.get('0.5'), fib_levels.get('0.78'), fib_levels.get('1')
        if None in (l0, l05, l078, l1):
            return {'bias': None, 'zone': None, 'message': 'Niveaux Fibo incomplets'}
        rng = (l1 - l0) if (l1 - l0) != 0 else 1e-9
        if direction == 'up':
            pos = (current_price - l0) / rng
            if 0 <= pos <= 0.5:
                return {'bias': 'buy', 'zone': 'buy_ok', 'message': 'Zone d’achat (0 à 0.5)'}
            elif 0.5 < pos < 0.78:
                return {'bias': 'sell', 'zone': 'risky', 'message': 'Zone risquée pour achats (0.5 à 0.78)'}
            elif 0.78 <= pos <= 1.0:
                return {'bias': 'sell', 'zone': 'ote_sell', 'message': 'Zone OTE de vente (0.78 à 1)'}
            else:
                return {'bias': None, 'zone': None, 'message': 'Hors plage'}
        elif direction == 'down':
            pos_down = (l1 - current_price) / rng
            if 0 <= pos_down <= 0.5:
                return {'bias': 'sell', 'zone': 'sell_ok', 'message': 'Zone de vente (0 à 0.5 depuis le haut)'}
            elif 0.5 < pos_down < 0.78:
                return {'bias': 'buy', 'zone': 'risky', 'message': 'Zone risquée pour ventes (0.5 à 0.78)'}
            elif 0.78 <= pos_down <= 1.0:
                return {'bias': 'buy', 'zone': 'ote_buy', 'message': 'Zone OTE d’achat (0.78 à 1 depuis le haut)'}
            else:
                return {'bias': None, 'zone': None, 'message': 'Hors plage'}
        else:
            return {'bias': None, 'zone': None, 'message': 'Direction inconnue'}
    except Exception as e:
        return {'bias': None, 'zone': None, 'message': f'Erreur évaluation OTE: {e}'}

def update_real_time_data():
    """Met à jour les données en temps réel avec les dernières données MT5 et les indicateurs avancés"""
    if not st.session_state.current_symbol:
        return False
    symbol = st.session_state.current_symbol
    timeframe = st.session_state.current_timeframe

    if hasattr(st.session_state, 'last_timeframe') and st.session_state.last_timeframe != timeframe:
        st.session_state.real_time_data = pd.DataFrame()
        st.session_state.last_timeframe = timeframe

    try:
        df = get_real_time_ohlc(symbol, timeframe, 300)
        if df is not None and not df.empty:
            df = calculate_advanced_indicators(df)
            ai_signals = generate_ai_signals(df)
            df = pd.concat([df, ai_signals], axis=1)
            trading_signals = generate_advanced_trading_signals(df)
            df = pd.concat([df, trading_signals], axis=1)
            patterns = detect_advanced_patterns(df)
            for pattern_name, pattern_data in patterns.items():
                df[f'Pattern_{pattern_name}'] = pattern_data
            support, resistance = calculate_support_resistance(df)
            df['Support'] = support
            df['Resistance'] = resistance
            st.session_state.real_time_data = df
            st.session_state.last_update = datetime.now()
            print(f"🔄 Données mises à jour avec indicateurs avancés pour {symbol} sur {timeframe}")
            return True
        else:
            st.warning(f"⚠️ Aucune donnée récupérée pour {symbol}")
            return False
    except Exception as e:
        st.error(f"❌ Erreur lors de la mise à jour des données: {e}")
        return False

def calculate_advanced_indicators(df):
    """Calcule tous les indicateurs techniques avancés"""
    if len(df) < 50:
        return df
    df['SMA_20'] = df['close'].rolling(window=20).mean()
    df['SMA_50'] = df['close'].rolling(window=50).mean()
    df['EMA_12'] = df['close'].ewm(span=12).mean()
    df['EMA_26'] = df['close'].ewm(span=26).mean()
    macd_line = df['EMA_12'] - df['EMA_26']
    signal_line = macd_line.ewm(span=9).mean()
    df['MACD'] = macd_line
    df['MACD_signal'] = signal_line
    df['MACD_hist'] = macd_line - signal_line
    delta = df['close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
    rs = gain / loss
    df['RSI'] = 100 - (100 / (1 + rs))
    df['BB_middle'] = df['close'].rolling(window=20).mean()
    bb_std = df['close'].rolling(window=20).std()
    df['BB_upper'] = df['BB_middle'] + (bb_std * 2)
    df['BB_lower'] = df['BB_middle'] - (bb_std * 2)
    low_min = df['low'].rolling(window=14).min()
    high_max = df['high'].rolling(window=14).max()
    df['STOCH_K'] = 100 * ((df['close'] - low_min) / (high_max - low_min))
    df['STOCH_D'] = df['STOCH_K'].rolling(window=3).mean()
    df['WILLR'] = -100 * ((high_max - df['close']) / (high_max - low_min))
    typical_price = (df['high'] + df['low'] + df['close']) / 3
    sma_tp = typical_price.rolling(window=20).mean()
    mad = typical_price.rolling(window=20).apply(lambda x: np.mean(np.abs(x - x.mean())))
    df['CCI'] = (typical_price - sma_tp) / (0.015 * mad)
    high_low = df['high'] - df['low']
    high_close = np.abs(df['high'] - df['close'].shift())
    low_close = np.abs(df['low'] - df['close'].shift())
    true_range = np.maximum(high_low, np.maximum(high_close, low_close))
    df['ATR'] = true_range.rolling(window=14).mean()
    plus_dm = df['high'].diff()
    minus_dm = df['low'].diff()
    plus_dm[plus_dm < 0] = 0
    minus_dm[minus_dm > 0] = 0
    minus_dm = minus_dm.abs()
    tr = true_range
    plus_di = 100 * (plus_dm.rolling(window=14).mean() / tr.rolling(window=14).mean())
    minus_di = 100 * (minus_dm.rolling(window=14).mean() / tr.rolling(window=14).mean())
    dx = 100 * np.abs(plus_di - minus_di) / (plus_di + minus_di)
    df['ADX'] = dx.rolling(window=14).mean()
    df['Ichimoku_A'] = ((df['high'].rolling(9).max() + df['low'].rolling(9).min()) / 2).shift(26)
    df['Ichimoku_B'] = ((df['high'].rolling(26).max() + df['low'].rolling(26).min()) / 2).shift(26)
    df['Ichimoku_base'] = ((df['high'].rolling(26).max() + df['low'].rolling(26).min()) / 2)
    return df

def detect_advanced_patterns(df):
    """Détecte les patterns de trading avancés"""
    patterns = {}
    if len(df) < 50:
        return patterns
    body = np.abs(df['close'] - df['open'])
    lower_shadow = df[['open', 'close']].min(axis=1) - df['low']
    upper_shadow = df['high'] - df[['open', 'close']].max(axis=1)
    patterns['Hammer'] = (lower_shadow > 2 * body) & (upper_shadow < body)
    patterns['Doji'] = body < (df['high'] - df['low']) * 0.1
    prev_body = np.abs(df['close'].shift(1) - df['open'].shift(1))
    patterns['Bullish_Engulfing'] = (df['close'] > df['open']) & (df['close'].shift(1) < df['open'].shift(1)) & (body > prev_body)
    patterns['Bearish_Engulfing'] = (df['close'] < df['open']) & (df['close'].shift(1) > df['open'].shift(1)) & (body > prev_body)
    return patterns

def calculate_support_resistance(df, window=20):
    """Calcule les niveaux de support et résistance avec confirmation"""
    highs = df['high'].rolling(window=window, center=True).max()
    lows = df['low'].rolling(window=window, center=True).min()

    # Trouver les pivots
    resistance_candidates = highs[highs == df['high']].dropna()
    support_candidates = lows[lows == df['low']].dropna()

    # Confirmer les niveaux avec des tests multiples
    confirmed_resistance = []
    confirmed_support = []

    for level in resistance_candidates:
        # Compter les tests de ce niveau
        tests = 0
        for i in range(len(df)):
            if abs(df['high'].iloc[i] - level) < (df['high'].iloc[i] * 0.001):  # 0.1% de tolérance
                tests += 1
        if tests >= 2:  # Au moins 2 tests pour confirmer
            confirmed_resistance.append(level)

    for level in support_candidates:
        # Compter les tests de ce niveau
        tests = 0
        for i in range(len(df)):
            if abs(df['low'].iloc[i] - level) < (df['low'].iloc[i] * 0.001):  # 0.1% de tolérance
                tests += 1
        if tests >= 2:  # Au moins 2 tests pour confirmer
            confirmed_support.append(level)

    return pd.Series(confirmed_support), pd.Series(confirmed_resistance)

def detect_ote_zones_old(df):
    """Détecte les zones OTE (Optimal Trade Entry) basées sur Fibonacci - VERSION SIMPLIFIÉE"""
    ote_zones = []

    if len(df) < 50:
        return ote_zones

    try:
        # Utiliser une approche simplifiée pour éviter les erreurs de comparaison
        recent_data = df.tail(50)

        # Trouver les maxima et minima locaux
        max_high = recent_data['high'].max()
        min_low = recent_data['low'].min()

        if max_high > min_low:
            # Zones OTE basées sur les niveaux récents
            range_size = max_high - min_low

            # Zone OTE 61.8%
            ote_618 = min_low + (range_size * 0.618)
            # Zone OTE 78.6%
            ote_786 = min_low + (range_size * 0.786)

            ote_zones.extend([ote_618, ote_786])

    except Exception as e:
        print(f"Erreur dans detect_ote_zones_old: {e}")

    return ote_zones

# Fonctions BOS et Liquidité supprimées par demande de l'utilisateur

# Fonction detect_liquidity_zones supprimée par demande de l'utilisateur

# Fonctions d'indicateurs techniques

def calculate_rsi(df, period=14):
    """Calcule le RSI (Relative Strength Index)"""
    delta = df['close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss
    rsi = 100 - (100 / (1 + rs))
    return rsi

def calculate_macd(df, fast=12, slow=26, signal=9):
    """Calcule le MACD (Moving Average Convergence Divergence)"""
    ema_fast = df['close'].ewm(span=fast).mean()
    ema_slow = df['close'].ewm(span=slow).mean()
    macd = ema_fast - ema_slow
    macd_signal = macd.ewm(span=signal).mean()
    macd_histogram = macd - macd_signal
    return macd, macd_signal, macd_histogram

def detect_spike_boom_crash_alerts(df, multi_tf_analysis=None):
    """Détecte les alertes de spikes Boom et Crash imminents avec cohérence multi-timeframe"""
    if len(df) < 30:
        return []
    
    spike_alerts = []
    
    # Calculer les indicateurs nécessaires
    df['ATR'] = calculate_atr(df, 14)
    df['BB_Upper'] = calculate_bollinger_bands(df, 20, 2)[0]
    df['BB_Lower'] = calculate_bollinger_bands(df, 20, 2)[2]
    df['EMA200'] = calculate_ema(df, 200)
    df['RSI'] = calculate_rsi(df, 14)
    df['MACD'] = calculate_macd(df, 12, 26, 9)[0]
    df['MACD_signal'] = calculate_macd(df, 12, 26, 9)[1]
    
    # Calculer Supertrend pour le contexte
    df['Supertrend'] = calculate_supertrend(df, 10, 3.0)
    
    lookback = min(30, len(df) - 10)
    
    for i in range(len(df) - lookback, len(df) - 5):
        if i < 0 or i >= len(df):
            continue
            
        # Analyse de la compression de volatilité (signe avant-coureur d'un spike)
        volatility_compression = 0
        momentum_buildup = 0
        volume_surge = 0
        
        # 1. Compression de volatilité (Bollinger Bands squeeze)
        if not pd.isna(df['BB_Upper'].iloc[i]) and not pd.isna(df['BB_Lower'].iloc[i]) and not pd.isna(df['ATR'].iloc[i]):
            bb_width = df['BB_Upper'].iloc[i] - df['BB_Lower'].iloc[i]
            atr_val = df['ATR'].iloc[i]
            if atr_val > 0:
                bb_squeeze = bb_width / (atr_val * 2.0)
                if bb_squeeze < 1.2:  # Compression forte
                    volatility_compression = 0.4
                elif bb_squeeze < 1.5:  # Compression modérée
                    volatility_compression = 0.2
        
        # 2. Accumulation de momentum (mouvement latéral avant explosion)
        if i >= 10:
            price_range = 0
            body_size = 0
            for k in range(1, 11):
                if i-k >= 0:
                    price_range += (df['high'].iloc[i-k] - df['low'].iloc[i-k])
                    body_size += abs(df['close'].iloc[i-k] - df['open'].iloc[i-k])
            
            avg_range = price_range / 10.0
            avg_body = body_size / 10.0
            current_range = df['high'].iloc[i] - df['low'].iloc[i]
            current_body = abs(df['close'].iloc[i] - df['open'].iloc[i])
            
            # Détection d'accumulation (range réduit, corps petits)
            if avg_range > 0 and current_range < avg_range * 0.7 and current_body < avg_body * 0.5:
                momentum_buildup = 0.3
        
        # 3. Patterns de consolidation (doji, spinning top)
        body_ratio = (df['high'].iloc[i] - df['low'].iloc[i] > 0) and (abs(df['close'].iloc[i] - df['open'].iloc[i]) / (df['high'].iloc[i] - df['low'].iloc[i])) or 0
        upper_shadow = df['high'].iloc[i] - max(df['open'].iloc[i], df['close'].iloc[i])
        lower_shadow = min(df['open'].iloc[i], df['close'].iloc[i]) - df['low'].iloc[i]
        shadow_ratio = (df['high'].iloc[i] - df['low'].iloc[i] > 0) and ((upper_shadow + lower_shadow) / (df['high'].iloc[i] - df['low'].iloc[i])) or 0
        
        # Pattern de consolidation (petit corps, grandes ombres)
        if body_ratio < 0.2 and shadow_ratio > 0.6:
            momentum_buildup += 0.2
        
        # 4. Proximité des niveaux clés (support/résistance, EMA200)
        proximity_factor = 0
        if not pd.isna(df['EMA200'].iloc[i]):
            distance_to_ema = abs(df['close'].iloc[i] - df['EMA200'].iloc[i])
            atr_val = df['ATR'].iloc[i] if not pd.isna(df['ATR'].iloc[i]) else 0
            if atr_val > 0:
                proximity = distance_to_ema / (atr_val * 2.0)
                if proximity < 0.5:  # Très proche de l'EMA200
                    proximity_factor = 0.2
        
        # 5. Analyse RSI pour direction
        rsi = df['RSI'].iloc[i] if not pd.isna(df['RSI'].iloc[i]) else 50
        rsi_signal = 0
        if rsi < 30:  # Survente - potentiel spike haussier
            rsi_signal = 0.3
        elif rsi > 70:  # Surachat - potentiel spike baissier
            rsi_signal = -0.3
        
        # 6. Analyse MACD pour direction
        macd_signal = 0
        if not pd.isna(df['MACD'].iloc[i]) and not pd.isna(df['MACD_signal'].iloc[i]):
            if df['MACD'].iloc[i] > df['MACD_signal'].iloc[i]:
                macd_signal = 0.2
            else:
                macd_signal = -0.2
        
        # 7. Vérification de cohérence avec l'analyse multi-timeframe
        trend_coherence = 0
        if multi_tf_analysis and 'consolidated_score' in multi_tf_analysis:
            consolidated_score = multi_tf_analysis['consolidated_score']
            
            # Si trend haussier fort, favoriser les signaux BOOM
            if consolidated_score > 0.3:
                if rsi_signal >= 0 and macd_signal >= 0:
                    trend_coherence = 0.3  # Bonus pour cohérence
                elif rsi_signal < 0 or macd_signal < 0:
                    trend_coherence = -0.2  # Malus pour incohérence
            
            # Si trend baissier fort, favoriser les signaux CRASH
            elif consolidated_score < -0.3:
                if rsi_signal <= 0 and macd_signal <= 0:
                    trend_coherence = 0.3  # Bonus pour cohérence
                elif rsi_signal > 0 or macd_signal > 0:
                    trend_coherence = -0.2  # Malus pour incohérence
        
        # Calcul du score total de probabilité de spike imminent
        spike_imminent_score = volatility_compression + momentum_buildup + volume_surge + proximity_factor + rsi_signal + macd_signal + trend_coherence
        
        # Alerte SPIKE IMMINENT - seuil ajusté
        if spike_imminent_score > 1.2:  # Seuil ajustable
            # Déterminer la direction du spike potentiel
            direction = "BOOM" if rsi_signal >= 0 and macd_signal >= 0 else "CRASH"
            
            # Vérification finale de cohérence avec le trend
            if multi_tf_analysis and 'consolidated_score' in multi_tf_analysis:
                consolidated_score = multi_tf_analysis['consolidated_score']
                
                # Si trend très haussier (>0.5), ne pas signaler CRASH
                if consolidated_score > 0.5 and direction == "CRASH":
                    continue
                    
                # Si trend très baissier (<-0.5), ne pas signaler BOOM
                if consolidated_score < -0.5 and direction == "BOOM":
                    continue
            
            spike_alerts.append({
                'timestamp': df.index[i],
                'price': df['close'].iloc[i],
                'confidence': min(100.0, spike_imminent_score * 25),
                'direction': direction,
                'spike_type': 'BOOM' if direction == "BOOM" else 'CRASH',
                'score': spike_imminent_score,
                'score_breakdown': {
                    'volatility_compression': volatility_compression,
                    'momentum_buildup': momentum_buildup,
                    'volume_surge': volume_surge,
                    'proximity_factor': proximity_factor,
                    'rsi_signal': rsi_signal,
                    'macd_signal': macd_signal,
                    'trend_coherence': trend_coherence
                }
            })
    
    return spike_alerts

def generate_unified_signal(df, multi_tf_analysis=None):
    """Génère un signal unifié unique combinant IA, ML et backend trend summary"""
    if len(df) < 50:
        return None
    
    current_price = df['close'].iloc[-1]
    
    # 1. Analyse IA (indicateurs techniques)
    ia_score = 0
    ia_confidence = 0
    
    # RSI
    rsi = df['RSI'].iloc[-1] if 'RSI' in df.columns else 50
    if rsi < 30:
        ia_score += 0.3
        ia_confidence += 0.2
    elif rsi > 70:
        ia_score -= 0.3
        ia_confidence += 0.2
    
    # MACD
    if 'MACD' in df.columns and 'MACD_signal' in df.columns:
        macd = df['MACD'].iloc[-1]
        macd_signal = df['MACD_signal'].iloc[-1]
        if macd > macd_signal:
            ia_score += 0.2
        else:
            ia_score -= 0.2
    
    # Moyennes mobiles
    if 'SMA_20' in df.columns and 'SMA_50' in df.columns:
        sma_20 = df['SMA_20'].iloc[-1]
        sma_50 = df['SMA_50'].iloc[-1]
        if current_price > sma_20 > sma_50:
            ia_score += 0.3
            ia_confidence += 0.2
        elif current_price < sma_20 < sma_50:
            ia_score -= 0.3
            ia_confidence += 0.2
    
    # 2. Analyse ML (patterns et momentum)
    ml_score = 0
    ml_confidence = 0
    
    # Analyse des 5 dernières bougies
    recent_candles = df.tail(5)
    green_candles = len(recent_candles[recent_candles['close'] > recent_candles['open']])
    red_candles = len(recent_candles[recent_candles['close'] < recent_candles['open']])
    
    if green_candles >= 4:
        ml_score += 0.3
        ml_confidence += 0.2
    elif red_candles >= 4:
        ml_score -= 0.3
        ml_confidence += 0.2
    
    # Analyse des wicks
    last_candle = df.iloc[-1]
    body_size = abs(last_candle['close'] - last_candle['open'])
    upper_wick = last_candle['high'] - max(last_candle['open'], last_candle['close'])
    lower_wick = min(last_candle['open'], last_candle['close']) - last_candle['low']
    
    if lower_wick > body_size * 2:  # Long wick bas (rejet)
        ml_score += 0.2
    elif upper_wick > body_size * 2:  # Long wick haut (rejet)
        ml_score -= 0.2
    
    # 3. Analyse Backend Trend Summary
    backend_score = 0
    backend_confidence = 0
    
    if multi_tf_analysis and 'consolidated_score' in multi_tf_analysis:
        consolidated_score = multi_tf_analysis['consolidated_score']
        backend_score = consolidated_score
        backend_confidence = abs(consolidated_score) * 0.5
    
    # 4. Calcul du score unifié
    total_score = (ia_score * 0.4) + (ml_score * 0.3) + (backend_score * 0.3)
    total_confidence = (ia_confidence + ml_confidence + backend_confidence) / 3
    
    # 5. Seuil de fiabilité à 100% (très strict)
    if total_confidence < 0.8:  # 80% minimum
        return None
    
    # 6. Déterminer le signal
    if total_score > 0.5:
        signal_type = "BUY LIMIT"
        limit_price = current_price * 0.9995  # 0.05% en dessous
        direction = "BUY"
    elif total_score < -0.5:
        signal_type = "SELL LIMIT"
        limit_price = current_price * 1.0005  # 0.05% au-dessus
        direction = "SELL"
    else:
        return None  # Signal trop faible
    
    return {
        'signal_type': signal_type,
        'direction': direction,
        'current_price': current_price,
        'limit_price': limit_price,
        'confidence': total_confidence,
        'score': total_score,
        'ia_score': ia_score,
        'ml_score': ml_score,
        'backend_score': backend_score,
        'timestamp': df.index[-1]
    }

def predict_next_movement(df, multi_tf_analysis=None):
    """Prédit le prochain mouvement de prix basé sur l'analyse complète avec cohérence multi-timeframe"""
    if len(df) < 50:
        return None, 0.0

    # Analyser TOUS les indicateurs disponibles
    current_price = df['close'].iloc[-1]

    # Indicateurs de momentum
    rsi = df['RSI'].iloc[-1] if 'RSI' in df.columns else 50
    macd = df['MACD'].iloc[-1] if 'MACD' in df.columns else 0
    macd_signal = df['MACD_signal'].iloc[-1] if 'MACD_signal' in df.columns else 0
    macd_histogram = macd - macd_signal

    # Moyennes mobiles
    sma_20 = df['SMA_20'].iloc[-1] if 'SMA_20' in df.columns else current_price
    sma_50 = df['SMA_50'].iloc[-1] if 'SMA_50' in df.columns else current_price
    ema_12 = df['EMA_12'].iloc[-1] if 'EMA_12' in df.columns else current_price
    ema_26 = df['EMA_26'].iloc[-1] if 'EMA_26' in df.columns else current_price

    # Indicateurs de volatilité
    bb_upper = df['BB_upper'].iloc[-1] if 'BB_upper' in df.columns else current_price * 1.02
    bb_lower = df['BB_lower'].iloc[-1] if 'BB_lower' in df.columns else current_price * 0.98
    bb_middle = df['BB_middle'].iloc[-1] if 'BB_middle' in df.columns else current_price
    atr = df['ATR'].iloc[-1] if 'ATR' in df.columns else current_price * 0.01

    # Indicateurs de tendance
    adx = df['ADX'].iloc[-1] if 'ADX' in df.columns else 20
    di_plus = df['DI_Plus'].iloc[-1] if 'DI_Plus' in df.columns else 20
    di_minus = df['DI_Minus'].iloc[-1] if 'DI_Minus' in df.columns else 20

    # Indicateurs avancés
    stoch_k = df['Stoch_K'].iloc[-1] if 'Stoch_K' in df.columns else 50
    stoch_d = df['Stoch_D'].iloc[-1] if 'Stoch_D' in df.columns else 50
    williams_r = df['Williams_R'].iloc[-1] if 'Williams_R' in df.columns else -50
    cci = df['CCI'].iloc[-1] if 'CCI' in df.columns else 0

    # Ichimoku
    ichimoku_a = df['Ichimoku_A'].iloc[-1] if 'Ichimoku_A' in df.columns else current_price
    ichimoku_b = df['Ichimoku_B'].iloc[-1] if 'Ichimoku_B' in df.columns else current_price
    ichimoku_base = df['Ichimoku_Base'].iloc[-1] if 'Ichimoku_Base' in df.columns else current_price
    ichimoku_conversion = df['Ichimoku_Conversion'].iloc[-1] if 'Ichimoku_Conversion' in df.columns else current_price

    # Calculer le score de prédiction complet
    prediction_score = 0
    confidence = 0.3  # Base de confiance

    # 1. Analyse de tendance (25% du score)
    trend_score = 0
    if current_price > sma_20 > sma_50:
        trend_score += 0.4
        confidence += 0.15
    elif current_price < sma_20 < sma_50:
        trend_score -= 0.4
        confidence += 0.15

    if current_price > ema_12 > ema_26:
        trend_score += 0.3
    elif current_price < ema_12 < ema_26:
        trend_score -= 0.3

    # Ichimoku
    if current_price > ichimoku_a and current_price > ichimoku_b:
        trend_score += 0.3
    elif current_price < ichimoku_a and current_price < ichimoku_b:
        trend_score -= 0.3

    # 1.5. Vérification de cohérence avec l'analyse multi-timeframe
    if multi_tf_analysis and 'consolidated_score' in multi_tf_analysis:
        consolidated_score = multi_tf_analysis['consolidated_score']
        
        # Si trend multi-timeframe très haussier, favoriser BUY
        if consolidated_score > 0.5:
            trend_score += 0.5
            confidence += 0.2
        # Si trend multi-timeframe très baissier, favoriser SELL
        elif consolidated_score < -0.5:
            trend_score -= 0.5
            confidence += 0.2
        # Si trend multi-timeframe neutre, ajuster modérément
        elif consolidated_score > 0.2:
            trend_score += 0.2
        elif consolidated_score < -0.2:
            trend_score -= 0.2

    prediction_score += trend_score * 0.25

    # 2. Analyse de momentum (20% du score)
    momentum_score = 0

    # RSI
    if rsi < 25:  # Survente extrême
        momentum_score += 0.4
        confidence += 0.1
    elif rsi < 35:  # Survente
        momentum_score += 0.2
    elif rsi > 75:  # Surachat extrême
        momentum_score -= 0.4
        confidence += 0.1
    elif rsi > 65:  # Surachat
        momentum_score -= 0.2

    # MACD
    if len(df) > 1:
        if macd_histogram > 0 and df['MACD'].iloc[-2] <= df['MACD_signal'].iloc[-2]:
            momentum_score += 0.3  # Croisement haussier
        elif macd_histogram < 0 and df['MACD'].iloc[-2] >= df['MACD_signal'].iloc[-2]:
            momentum_score -= 0.3  # Croisement baissier

    # Stochastic
    if stoch_k < 20 and stoch_d < 20:
        momentum_score += 0.2
    elif stoch_k > 80 and stoch_d > 80:
        momentum_score -= 0.2

    # Williams %R
    if williams_r < -80:
        momentum_score += 0.2
    elif williams_r > -20:
        momentum_score -= 0.2

    # CCI
    if cci < -100:
        momentum_score += 0.2
    elif cci > 100:
        momentum_score -= 0.2

    prediction_score += momentum_score * 0.2

    # 3. Analyse des zones Support/Résistance et rebonds (30% du score) - PRIORITÉ
    zone_score = 0

    # Calculer les zones S/R
    support, resistance = calculate_support_resistance(df)

    # Analyser la proximité aux zones
    near_support = False
    near_resistance = False
    support_strength = 0
    resistance_strength = 0

    if not support.empty:
        for support_level in support:
            distance = abs(current_price - support_level) / current_price
            if distance < 0.005:  # Dans les 0.5%
                near_support = True
                # Calculer la force du support basée sur les rebonds précédents
                support_strength = analyze_zone_strength(df, support_level, 'support')
                break

    if not resistance.empty:
        for resistance_level in resistance:
            distance = abs(current_price - resistance_level) / current_price
            if distance < 0.005:  # Dans les 0.5%
                near_resistance = True
                # Calculer la force de la résistance basée sur les rejets précédents
                resistance_strength = analyze_zone_strength(df, resistance_level, 'resistance')
                break

    # Prédiction basée sur les zones
    if near_support and support_strength > 0.6:
        zone_score += 0.8  # Fort rebond attendu
        confidence += 0.2
    elif near_resistance and resistance_strength > 0.6:
        zone_score -= 0.8  # Fort rejet attendu
        confidence += 0.2
    elif near_support:
        zone_score += 0.4  # Rebond modéré
        confidence += 0.1
    elif near_resistance:
        zone_score -= 0.4  # Rejet modéré
        confidence += 0.1

    # Analyser les patterns de rebond/rejet récents
    bounce_pattern = analyze_bounce_pattern(df)
    if bounce_pattern == 'bullish_bounce':
        zone_score += 0.3
        confidence += 0.1
    elif bounce_pattern == 'bearish_rejection':
        zone_score -= 0.3
        confidence += 0.1

    prediction_score += zone_score * 0.3

    # 4. Analyse de volatilité (10% du score)
    volatility_score = 0

    # Bollinger Bands
    bb_position = (current_price - bb_lower) / (bb_upper - bb_lower)
    if bb_position < 0.1:  # Proche de la bande inférieure
        volatility_score += 0.3
    elif bb_position > 0.9:  # Proche de la bande supérieure
        volatility_score -= 0.3

    prediction_score += volatility_score * 0.1

    # 5. Force de la tendance (10% du score)
    strength_score = 0

    # ADX
    if adx > 30:
        strength_score += 0.3
        confidence += 0.1
    elif adx > 25:
        strength_score += 0.2

    # DI+/DI-
    if di_plus > di_minus:
        strength_score += 0.2
    else:
        strength_score -= 0.2

    # ATR (volatilité)
    if atr > (current_price * 0.02):  # Haute volatilité
        strength_score += 0.1

    prediction_score += strength_score * 0.1

    # 6. Patterns de prix (5% du score)
    pattern_score = 0

    # Analyser les 5 dernières bougies
    recent_candles = df.tail(5)
    green_candles = len(recent_candles[recent_candles['close'] > recent_candles['open']])
    red_candles = len(recent_candles[recent_candles['close'] < recent_candles['open']])

    if green_candles >= 4:  # Série de bougies vertes
        pattern_score += 0.2
    elif red_candles >= 4:  # Série de bougies rouges
        pattern_score -= 0.2

    # Analyser les wicks
    last_candle = df.iloc[-1]
    body_size = abs(last_candle['close'] - last_candle['open'])
    upper_wick = last_candle['high'] - max(last_candle['open'], last_candle['close'])
    lower_wick = min(last_candle['open'], last_candle['close']) - last_candle['low']

    if lower_wick > body_size * 2:  # Long wick bas (rejet)
        pattern_score += 0.2
    elif upper_wick > body_size * 2:  # Long wick haut (rejet)
        pattern_score -= 0.2

    prediction_score += pattern_score * 0.05

    # Normaliser la confiance
    confidence = min(confidence, 0.95)

    # Vérification finale de cohérence avec l'analyse multi-timeframe
    if multi_tf_analysis and 'consolidated_score' in multi_tf_analysis:
        consolidated_score = multi_tf_analysis['consolidated_score']
        
        # Si trend multi-timeframe très haussier (>0.5), forcer BUY
        if consolidated_score > 0.5 and prediction_score < 0:
            prediction_score = 0.2  # Forcer BUY
            confidence = max(confidence, 0.6)
        
        # Si trend multi-timeframe très baissier (<-0.5), forcer SELL
        elif consolidated_score < -0.5 and prediction_score > 0:
            prediction_score = -0.2  # Forcer SELL
            confidence = max(confidence, 0.6)

    # Déterminer la prédiction avec des seuils plus permissifs pour les tests
    if prediction_score > 0.1 and confidence > 0.3:
        return "BUY", confidence
    elif prediction_score < -0.1 and confidence > 0.3:
        return "SELL", confidence
    else:
        # Par défaut, retourner une prédiction basée sur la tendance simple
        if current_price > sma_20:
            return "BUY", 0.4
        else:
            return "SELL", 0.4

def analyze_zone_strength(df, level, zone_type):
    """Analyse la force d'une zone de support ou résistance"""
    if len(df) < 20:
        return 0.0

    strength = 0.0
    tolerance = level * 0.002  # 0.2% de tolérance

    # Compter les tests de la zone
    tests = 0
    successful_rejections = 0

    for i in range(len(df)):
        if zone_type == 'support':
            if abs(df['low'].iloc[i] - level) < tolerance:
                tests += 1
                # Vérifier si le prix a rebondi après avoir touché le support
                if i < len(df) - 1 and df['close'].iloc[i+1] > df['close'].iloc[i]:
                    successful_rejections += 1
        elif zone_type == 'resistance':
            if abs(df['high'].iloc[i] - level) < tolerance:
                tests += 1
                # Vérifier si le prix a été rejeté après avoir touché la résistance
                if i < len(df) - 1 and df['close'].iloc[i+1] < df['close'].iloc[i]:
                    successful_rejections += 1

    if tests > 0:
        success_rate = successful_rejections / tests
        # Plus il y a de tests et plus le taux de succès est élevé, plus la zone est forte
        strength = min(success_rate * (tests / 5), 1.0)  # Normaliser

    return strength

def analyze_bounce_pattern(df):
    """Analyse les patterns de rebond/rejet récents"""
    if len(df) < 10:
        return 'neutral'

    # Analyser les 3 dernières bougies
    last_3 = df.tail(3)

    # Pattern de rebond haussier : bougie rouge suivie de bougie verte avec wick bas
    if (len(last_3) >= 2 and
        last_3['close'].iloc[-2] < last_3['open'].iloc[-2] and  # Bougie rouge
        last_3['close'].iloc[-1] > last_3['open'].iloc[-1]):    # Bougie verte

        # Vérifier le wick bas de la dernière bougie
        last_candle = last_3.iloc[-1]
        body_size = abs(last_candle['close'] - last_candle['open'])
        lower_wick = min(last_candle['open'], last_candle['close']) - last_candle['low']

        if lower_wick > body_size * 1.5:  # Long wick bas
            return 'bullish_bounce'

    # Pattern de rejet baissier : bougie verte suivie de bougie rouge avec wick haut
    if (len(last_3) >= 2 and
        last_3['close'].iloc[-2] > last_3['open'].iloc[-2] and  # Bougie verte
        last_3['close'].iloc[-1] < last_3['open'].iloc[-1]):    # Bougie rouge

        # Vérifier le wick haut de la dernière bougie
        last_candle = last_3.iloc[-1]
        body_size = abs(last_candle['close'] - last_candle['open'])
        upper_wick = last_candle['high'] - max(last_candle['open'], last_candle['close'])

        if upper_wick > body_size * 1.5:  # Long wick haut
            return 'bearish_rejection'

    return 'neutral'

def detect_ote_zones(df):
    """Détecte les zones OTE (Optimal Trade Entry) basées sur les concepts Smart Money - VERSION ULTRA ROBUSTE"""
    if len(df) < 50:
        return {'buy_zones': [], 'sell_zones': []}

    try:
        # Analyser les 50 dernières bougies pour trouver les zones OTE
        recent_data = df.tail(50).copy()

        # Nettoyer et convertir toutes les colonnes en numérique
        for col in ['high', 'low', 'close', 'open']:
            if col in recent_data.columns:
                recent_data[col] = pd.to_numeric(recent_data[col], errors='coerce')
        
        # Supprimer les lignes avec des valeurs NaN
        recent_data = recent_data.dropna(subset=['high', 'low', 'close'])
        
        if len(recent_data) < 10:
            return {'buy_zones': [], 'sell_zones': []}

        # Utiliser une approche simplifiée basée sur les min/max récents
        max_high = recent_data['high'].max()
        min_low = recent_data['low'].min()
        current_price = recent_data['close'].iloc[-1]
        
        if max_high <= min_low:
            return {'buy_zones': [], 'sell_zones': []}

        buy_zones = []
        sell_zones = []
        
        # Calculer la plage de prix
        price_range = max_high - min_low
        
        # Zone OTE ACHAT (retracement vers les niveaux de support)
        # Zone 61.8% - 78.6% retracement du mouvement haussier
        ote_buy_high = max_high - (price_range * 0.618)
        ote_buy_low = max_high - (price_range * 0.786)
        
        if ote_buy_high > ote_buy_low and ote_buy_high > min_low:
            buy_zones.append({
                'high': float(ote_buy_high),
                'low': float(max(ote_buy_low, min_low)),
                'strength': 'strong' if price_range > recent_data['close'].std() else 'medium'
            })
        
        # Zone OTE VENTE (retracement vers les niveaux de résistance)
        # Zone 61.8% - 78.6% retracement du mouvement baissier
        ote_sell_high = min_low + (price_range * 0.786)
        ote_sell_low = min_low + (price_range * 0.618)
        
        if ote_sell_high > ote_sell_low and ote_sell_low < max_high:
            sell_zones.append({
                'high': float(min(ote_sell_high, max_high)),
                'low': float(ote_sell_low),
                'strength': 'strong' if price_range > recent_data['close'].std() else 'medium'
            })

        return {'buy_zones': buy_zones, 'sell_zones': sell_zones}

    except Exception as e:
        print(f"Erreur dans detect_ote_zones: {e}")
        return {'buy_zones': [], 'sell_zones': []}

def create_candlestick_chart(df, title):
    """Crée un graphique en chandeliers japonais simplifié avec une flèche prédictive unique."""
    fig = go.Figure()

    # Ajouter les chandeliers japonais
    fig.add_trace(go.Candlestick(
        x=df.index,
        open=df['open'],
        high=df['high'],
        low=df['low'],
        close=df['close'],
        name="Prix",
        increasing_line_color='#00ff88',
        decreasing_line_color='#ff4444'
    ))

    # Ajouter seulement les moyennes mobiles essentielles
    if 'SMA_20' in df.columns:
        fig.add_trace(go.Scatter(x=df.index, y=df['SMA_20'], line=dict(color='orange', width=2), name='SMA 20'))
    if 'SMA_50' in df.columns:
        fig.add_trace(go.Scatter(x=df.index, y=df['SMA_50'], line=dict(color='blue', width=2), name='SMA 50'))

    # Ajouter les zones de support/résistance colorées
    support, resistance = calculate_support_resistance(df)

    # Zones de support (vertes transparentes) - SANS labels
    if not support.empty:
        for level in support:
            fig.add_hrect(
                y0=level * 0.999, y1=level * 1.001,
                fillcolor="rgba(0, 255, 0, 0.2)",
                layer="below",
                line_width=0
            )

    # Zones de résistance (rouges transparentes) - SANS labels
    if not resistance.empty:
        for level in resistance:
            fig.add_hrect(
                y0=level * 0.999, y1=level * 1.001,
                fillcolor="rgba(255, 0, 0, 0.2)",
                layer="below",
                line_width=0
            )

    # Ajouter les tracés de Fibonacci sur le graphique principal
    if len(df) >= 50:
        # Trouver le swing high et swing low récents
        recent_data = df.tail(50)
        swing_high = recent_data['high'].max()
        swing_low = recent_data['low'].min()

        # Calculer les niveaux de Fibonacci
        fib_range = swing_high - swing_low
        fib_levels = {
            '0%': swing_high,
            '23.6%': swing_high - (fib_range * 0.236),
            '38.2%': swing_high - (fib_range * 0.382),
            '50%': swing_high - (fib_range * 0.5),
            '61.8%': swing_high - (fib_range * 0.618),
            '78.6%': swing_high - (fib_range * 0.786),
            '100%': swing_low
        }

        # Ajouter les lignes de Fibonacci avec meilleure lisibilité
        fib_colors = {
            '0%': '#FF0000',      # Rouge vif
            '23.6%': '#FF8C00',   # Orange
            '38.2%': '#FFD700',   # Or
            '50%': '#00FF00',     # Vert vif
            '61.8%': '#00BFFF',   # Bleu ciel
            '78.6%': '#8A2BE2',   # Bleu violet
            '100%': '#FF1493'     # Rose vif
        }

        for level_name, level_price in fib_levels.items():
            color = fib_colors.get(level_name, '#FFFFFF')
            
            # Ajouter la ligne de Fibonacci
            fig.add_hline(
                y=level_price,
                line_dash="dash",
                line_color=color,
                line_width=2,
                opacity=0.8
            )
            
            # Ajouter le label Fibonacci avec annotation séparée pour meilleure visibilité
            if st.session_state.get('show_fibonacci_labels', True):
                fig.add_annotation(
                    x=df.index[0],  # Positionner le label à gauche du graphique
                    y=level_price,
                    text=f"FIB {level_name}<br>{level_price:.5f}",
                    showarrow=False,
                    font=dict(
                        size=11,
                        color=color,
                        family="Arial Black"
                    ),
                    bgcolor="rgba(0,0,0,0.8)",
                    bordercolor=color,
                    borderwidth=2,
                    xshift=-25,  # Décaler vers la gauche
                    yshift=0
                )

    # Zones OTE supprimées par demande de l'utilisateur

    # Ajouter les alertes de spikes Boom et Crash (M1 uniquement)
    if st.checkbox("🚀 Alertes Spikes Boom/Crash (M1)", value=True, help="Affiche les alertes de spikes Boom et Crash imminents - M1 uniquement"):
        # Vérifier que nous sommes sur M1
        if st.session_state.current_timeframe == "1m":
            # Récupérer l'analyse multi-timeframe pour la cohérence
            multi_tf_analysis = analyze_multi_timeframe_trend(symbol)
            spike_alerts = detect_spike_boom_crash_alerts(df, multi_tf_analysis)
        else:
            # Message informatif si pas sur M1
            st.info("ℹ️ Les alertes de spikes ne fonctionnent que sur le timeframe M1. Changez vers M1 pour activer les alertes.")
            spike_alerts = []
        
        # Afficher le nombre d'alertes détectées
        if spike_alerts:
            boom_count = len([a for a in spike_alerts if a['spike_type'] == 'BOOM'])
            crash_count = len([a for a in spike_alerts if a['spike_type'] == 'CRASH'])
            st.info(f"🚨 {len(spike_alerts)} alerte(s) de spike détectée(s) ! (BOOM: {boom_count}, CRASH: {crash_count})")
            
            # Initialiser le cache des alertes actives
            if 'active_spike_alerts' not in st.session_state:
                st.session_state.active_spike_alerts = {}
            
            for alert in spike_alerts:
                alert_key = f"{alert['spike_type']}_{alert['timestamp']}"
                
                # Ajouter l'alerte au cache si elle n'existe pas
                if alert_key not in st.session_state.active_spike_alerts:
                    st.session_state.active_spike_alerts[alert_key] = {
                        'alert': alert,
                        'start_time': datetime.now(),
                        'last_sound_time': datetime.now() - timedelta(seconds=60)  # Permettre le premier son
                    }
                
            # Vérifier et jouer les sons pour les alertes actives
            current_time = datetime.now()
            for alert_key, alert_data in st.session_state.active_spike_alerts.items():
                alert = alert_data['alert']
                last_sound_time = alert_data['last_sound_time']
                
                # Vérifier si le spike est encore actif (dans les 5 dernières minutes)
                time_since_alert = (current_time - alert_data['start_time']).total_seconds()
                
                if time_since_alert < 300:  # 5 minutes
                    # Jouer le bip sonore toutes les 10 secondes
                    if (current_time - last_sound_time).total_seconds() >= 10:
                        if st.session_state.get('enable_spike_sounds', True):
                            play_alert_sound()
                        st.session_state.active_spike_alerts[alert_key]['last_sound_time'] = current_time
                        
                        # Envoyer SMS pour les spikes (si activé) - une seule fois
                        if st.session_state.get('send_spike_sms', False) and not alert_data.get('sms_sent', False):
                            send_trading_signal(
                                signal_type="SPIKE",
                                symbol=symbol,
                                price=alert['price'],
                                confidence=alert['confidence'] / 100,
                                direction=alert['spike_type']
                            )
                            st.session_state.active_spike_alerts[alert_key]['sms_sent'] = True
                else:
                    # Supprimer les alertes anciennes
                    del st.session_state.active_spike_alerts[alert_key]
            
            # Afficher les alertes actives
            if st.session_state.active_spike_alerts:
                st.warning(f"🔊 {len(st.session_state.active_spike_alerts)} alerte(s) active(s) - Bip sonore continu jusqu'au spike !")
                
                for alert_key, alert_data in st.session_state.active_spike_alerts.items():
                    alert = alert_data['alert']
                    time_since = (current_time - alert_data['start_time']).total_seconds()
                    st.write(f"• {alert['spike_type']} - Actif depuis {int(time_since)}s")
            
            # Traiter les alertes pour l'affichage sur le graphique
            for alert in spike_alerts:
                # Déterminer la couleur et le symbole selon le type de spike
                if alert['spike_type'] == 'BOOM':
                    arrow_color = "green"
                    arrow_symbol = "triangle-up"
                    text_color = "white"
                    bg_color = "rgba(0, 128, 0, 0.8)"
                    text = "🚀 BOOM!"
                else:  # CRASH
                    arrow_color = "red"
                    arrow_symbol = "triangle-down"
                    text_color = "white"
                    bg_color = "rgba(255, 0, 0, 0.8)"
                    text = "💥 CRASH!"
                
                fig.add_annotation(
                    x=alert['timestamp'],
                    y=alert['price'],
                    text=text,
                    showarrow=True,
                    arrowhead=2,
                    arrowsize=3,
                    arrowwidth=5,
                    arrowcolor=arrow_color,
                    ax=0,
                    ay=-40 if alert['spike_type'] == 'BOOM' else 40,
                    font=dict(size=14, color=text_color, family="Arial Black"),
                    bgcolor=bg_color,
                    bordercolor=arrow_color,
                    borderwidth=2
                )
            
            # Ajouter une annotation avec les détails
            fig.add_annotation(
                x=alert['timestamp'],
                y=alert['price'] + (df['high'].max() - df['low'].min()) * 0.02,
                text=f"Confiance: {alert['confidence']:.1f}%<br>Direction: {alert['direction']}",
                showarrow=False,
                font=dict(size=10, color="dodgerblue"),
                bgcolor="rgba(30, 144, 255, 0.8)",
                bordercolor="dodgerblue",
                borderwidth=1
            )

    # Test: Ajouter une flèche de test simple
    if st.checkbox("🧪 Flèche de Test", value=False, help="Affiche une flèche de test simple"):
        test_time = df.index[-1]
        test_price = df['close'].iloc[-1]
        fig.add_annotation(
            x=test_time,
            y=test_price,
            text="🧪 TEST",
            showarrow=True,
            arrowhead=2,
            arrowsize=2,
            arrowwidth=3,
            arrowcolor="purple",
            ax=0,
            ay=-30,
            font=dict(size=12, color="purple"),
            bgcolor="rgba(128, 0, 128, 0.2)",
            bordercolor="purple",
            borderwidth=2
        )
        st.info("🧪 Flèche de test ajoutée - Vérifiez le graphique")

    # Signal Unifié Unique (IA + ML + Backend Trend Summary)
    if st.checkbox("🎯 Signal Unifié Unique", value=True, help="Affiche le signal unifié combinant IA, ML et backend trend"):
        # Récupérer l'analyse multi-timeframe pour la cohérence
        multi_tf_analysis = analyze_multi_timeframe_trend(symbol)
        unified_signal = generate_unified_signal(df, multi_tf_analysis)
        
        if unified_signal:
            signal_type = unified_signal['signal_type']
            direction = unified_signal['direction']
            current_price = unified_signal['current_price']
            limit_price = unified_signal['limit_price']
            confidence = unified_signal['confidence']
            score = unified_signal['score']
            timestamp = unified_signal['timestamp']
            
            # Afficher les détails du signal
            st.success(f"🎯 **SIGNAL UNIFIÉ DÉTECTÉ**")
            
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Signal", signal_type, f"Confiance: {confidence:.1%}")
            with col2:
                st.metric("Prix Actuel", f"{current_price:.5f}", f"Limit: {limit_price:.5f}")
            with col3:
                st.metric("Score Total", f"{score:.2f}", f"Direction: {direction}")
            
            # Afficher le breakdown des scores
            with st.expander("📊 Détail des Analyses", expanded=False):
                col1, col2, col3 = st.columns(3)
                with col1:
                    st.metric("IA Score", f"{unified_signal['ia_score']:.2f}", "Indicateurs techniques")
                with col2:
                    st.metric("ML Score", f"{unified_signal['ml_score']:.2f}", "Patterns & momentum")
                with col3:
                    st.metric("Backend Score", f"{unified_signal['backend_score']:.2f}", "Trend multi-timeframe")
            
            # Position de la flèche selon le type de signal
            if signal_type == "BUY LIMIT":
                arrow_y = limit_price  # Position exacte du limit
                arrow_color = "green"
                arrow_text = f"BUY LIMIT @ {limit_price:.5f}"
                bg_color = "rgba(0, 128, 0, 0.8)"
                ay_offset = -30
            else:  # SELL LIMIT
                arrow_y = limit_price  # Position exacte du limit
                arrow_color = "red"
                arrow_text = f"SELL LIMIT @ {limit_price:.5f}"
                bg_color = "rgba(255, 0, 0, 0.8)"
                ay_offset = 30
            
            # Ajouter la flèche du signal unifié
            fig.add_annotation(
                x=timestamp,
                y=arrow_y,
                text=f"🎯 {arrow_text}",
                showarrow=True,
                arrowhead=2,
                arrowsize=4,
                arrowwidth=6,
                arrowcolor=arrow_color,
                ax=0,
                ay=ay_offset,
                font=dict(size=14, color="white", family="Arial Black"),
                bgcolor=bg_color,
                bordercolor=arrow_color,
                borderwidth=3
            )
            
            # Ajouter une ligne horizontale pour le prix limit
            fig.add_hline(
                y=limit_price,
                line_dash="dash",
                line_color=arrow_color,
                line_width=2,
                opacity=0.7,
                annotation_text=f"{signal_type} @ {limit_price:.5f}",
                annotation_position="right",
                annotation_font_size=12,
                annotation_font_color=arrow_color
            )
            
            # Jouer le son d'alerte
            play_alert_sound()
            
            # Envoyer SMS pour le signal unifié (si activé)
            if st.session_state.get('send_prediction_sms', False):
                send_trading_signal(
                    signal_type="UNIFIED_SIGNAL",
                    symbol=symbol,
                    price=limit_price,
                    confidence=confidence,
                    direction=signal_type
                )
            
            st.success(f"✅ Signal {signal_type} affiché sur le graphique !")
            
        else:
            st.info("ℹ️ Aucun signal unifié détecté - Fiabilité insuffisante (< 80%)")
            st.write("**Critères requis :**")
            st.write("- Score IA + ML + Backend > 0.5 (BUY) ou < -0.5 (SELL)")
            st.write("- Confiance totale > 80%")
            st.write("- Cohérence entre toutes les analyses")

    # UNE SEULE FLÈCHE AUTORISÉE - Suppression des signaux confirmés

    # Mise en forme du graphique
    fig.update_layout(
        title=title,
        xaxis_title="Temps",
        yaxis_title="Prix",
        template="plotly_dark",
        height=600,
        showlegend=True,
        uirevision="streamlit",
        xaxis_rangeslider_visible=False,
        legend=dict(
            orientation="h",
            yanchor="bottom",
            y=1.02,
            xanchor="right",
            x=1
        )
    )


    return fig

def add_technical_indicators_to_chart(fig, df, indicators):
    """Ajoute des indicateurs techniques au graphique existant"""
    if 'sma' in indicators:
        if 'SMA_20' in df.columns:
            fig.add_trace(go.Scatter(x=df.index, y=df['SMA_20'], line=dict(color='orange', width=1), name='SMA 20'))
        if 'SMA_50' in df.columns:
            fig.add_trace(go.Scatter(x=df.index, y=df['SMA_50'], line=dict(color='blue', width=1), name='SMA 50'))

    if 'ema' in indicators:
        if 'EMA_12' in df.columns:
            fig.add_trace(go.Scatter(x=df.index, y=df['EMA_12'], line=dict(color='cyan', width=1), name='EMA 12'))
        if 'EMA_26' in df.columns:
            fig.add_trace(go.Scatter(x=df.index, y=df['EMA_26'], line=dict(color='purple', width=1), name='EMA 26'))

    if 'channels' in indicators:
        if 'BB_upper' in df.columns and 'BB_lower' in df.columns:
            fig.add_trace(go.Scatter(x=df.index, y=df['BB_upper'], line=dict(color='gray', width=1), name='BB Upper'))
            fig.add_trace(go.Scatter(x=df.index, y=df['BB_lower'], line=dict(color='gray', width=1), name='BB Lower'))

    return fig

def generate_ai_signals(df):
    """Génère des signaux basés sur l'IA et le machine learning"""
    signals = pd.DataFrame(index=df.index)
    signals['AI_Signal'] = 0
    signals['AI_Confidence'] = 0.0
    if len(df) < 50:
        return signals
    for i in range(50, len(df)):
        score = 0
        confidence = 0
        if 'RSI' in df.columns:
            if df['RSI'].iloc[i] < 30:
                score += 2
                confidence += 0.3
            elif df['RSI'].iloc[i] > 70:
                score -= 2
                confidence += 0.3
        if 'MACD' in df.columns and 'MACD_signal' in df.columns:
            if df['MACD'].iloc[i] > df['MACD_signal'].iloc[i] and df['MACD'].iloc[i-1] <= df['MACD_signal'].iloc[i-1]:
                score += 1.5
                confidence += 0.2
            elif df['MACD'].iloc[i] < df['MACD_signal'].iloc[i] and df['MACD'].iloc[i-1] >= df['MACD_signal'].iloc[i-1]:
                score -= 1.5
                confidence += 0.2
        if 'BB_upper' in df.columns and 'BB_lower' in df.columns:
            if df['close'].iloc[i] <= df['BB_lower'].iloc[i]:
                score += 1
                confidence += 0.15
            elif df['close'].iloc[i] >= df['BB_upper'].iloc[i]:
                score -= 1
                confidence += 0.15
        if 'ADX' in df.columns:
            if df['ADX'].iloc[i] > 25:
                confidence += 0.1
        if score >= 2 and confidence >= 0.5:
            signals.loc[df.index[i], 'AI_Signal'] = 1
            signals.loc[df.index[i], 'AI_Confidence'] = min(confidence, 1.0)
        elif score <= -2 and confidence >= 0.5:
            signals.loc[df.index[i], 'AI_Signal'] = -1
            signals.loc[df.index[i], 'AI_Confidence'] = min(confidence, 1.0)
    return signals

def generate_advanced_trading_signals(df):
    """Génère les signaux de trading sophistiqués avec OTE, BOS et liquidité"""
    signals = pd.DataFrame(index=df.index)
    signals['Signal'] = 0
    signals['Entry_Price'] = 0.0
    signals['Stop_Loss'] = 0.0
    signals['Take_Profit'] = 0.0
    signals['Confidence'] = 0.0
    signals['Strategy'] = ''
    if len(df) < 50:
        return signals

    # Zones OTE supprimées par demande de l'utilisateur
    support, resistance = calculate_support_resistance(df)

    # Signaux OTE supprimés par demande de l'utilisateur

    # Signaux BOS et Liquidité supprimés par demande de l'utilisateur

    # Signaux de support/résistance
    for i in range(50, len(df)):
        current_price = df['close'].iloc[i]

        # Test de résistance
        for res_level in resistance:
            if abs(current_price - res_level) < (current_price * 0.001):
                if (df['RSI'].iloc[i] > 60 and
                    df['MACD'].iloc[i] < df['MACD_signal'].iloc[i]):
                    signals.loc[df.index[i], 'Signal'] = -1
                    signals.loc[df.index[i], 'Entry_Price'] = current_price
                    signals.loc[df.index[i], 'Stop_Loss'] = res_level + (df['ATR'].iloc[i] * 1)
                    signals.loc[df.index[i], 'Take_Profit'] = current_price - (df['ATR'].iloc[i] * 3)
                    signals.loc[df.index[i], 'Confidence'] = 0.90
                    signals.loc[df.index[i], 'Strategy'] = 'Resistance'

        # Test de support
        for sup_level in support:
            if abs(current_price - sup_level) < (current_price * 0.001):
                if (df['RSI'].iloc[i] < 40 and
                    df['MACD'].iloc[i] > df['MACD_signal'].iloc[i]):
                    signals.loc[df.index[i], 'Signal'] = 1
                    signals.loc[df.index[i], 'Entry_Price'] = current_price
                    signals.loc[df.index[i], 'Stop_Loss'] = sup_level - (df['ATR'].iloc[i] * 1)
                    signals.loc[df.index[i], 'Take_Profit'] = current_price + (df['ATR'].iloc[i] * 3)
                    signals.loc[df.index[i], 'Confidence'] = 0.90
                    signals.loc[df.index[i], 'Strategy'] = 'Support'

    return signals

def analyze_multi_timeframe_trend(symbol):
    """Analyse la tendance sur plusieurs timeframes pour une décision consolidée"""
    timeframes = ['1m', '5m', '10m', '15m', '30m', '1h', '4h', '6h', '8h']
    timeframe_weights = {
        '1m': 0.05, '5m': 0.1, '10m': 0.1, '15m': 0.15, '30m': 0.15, 
        '1h': 0.2, '4h': 0.1, '6h': 0.1, '8h': 0.05
    }

    trend_scores = []
    volume_analysis = []

    for tf in timeframes:
        try:
            # Récupérer les données pour chaque timeframe
            ohlc_data = get_real_time_ohlc(symbol, tf, 50)
            if ohlc_data is None or ohlc_data.empty:
                continue

            df = calculate_advanced_indicators(ohlc_data)

            # Analyser la tendance
            sma_20 = df['SMA_20'].iloc[-1]
            sma_50 = df['SMA_50'].iloc[-1]
            ema_12 = df['EMA_12'].iloc[-1]
            current_price = df['close'].iloc[-1]

            # Score de tendance (-1 à 1)
            trend_score = 0
            if sma_20 > sma_50:
                trend_score += 0.3
            if current_price > sma_20:
                trend_score += 0.3
            if current_price > ema_12:
                trend_score += 0.2
            if df['ADX'].iloc[-1] > 25:
                trend_score += 0.2

            # Analyser le momentum
            rsi = df['RSI'].iloc[-1]
            if rsi > 50:
                trend_score += 0.1
            else:
                trend_score -= 0.1

            # Analyser le MACD
            if df['MACD'].iloc[-1] > df['MACD_signal'].iloc[-1]:
                trend_score += 0.1
            else:
                trend_score -= 0.1

            trend_scores.append({
                'timeframe': tf,
                'score': trend_score,
                'weight': timeframe_weights[tf],
                'price': current_price,
                'atr': df['ATR'].iloc[-1]
            })

        except Exception as e:
            continue

    # Calculer le score consolidé
    if not trend_scores:
        return None

    consolidated_score = sum(score['score'] * score['weight'] for score in trend_scores)
    current_price = trend_scores[-1]['price']  # Prix du timeframe le plus court
    atr = trend_scores[-1]['atr']

    return {
        'consolidated_score': consolidated_score,
        'current_price': current_price,
        'atr': atr,
        'timeframe_analysis': trend_scores
    }

def calculate_position_sizing(entry_price, stop_loss, max_capital=20, risk_percent=10):
    """Calcule la taille de position basée sur le risque"""
    risk_amount = max_capital * (risk_percent / 100)  # 2$ de risque max
    price_diff = abs(entry_price - stop_loss)

    if price_diff == 0:
        return 0

    # Calculer la taille de position
    position_size = risk_amount / price_diff

    # Limiter la position à 20$ maximum
    max_position_value = max_capital
    max_position_size = max_position_value / entry_price

    return min(position_size, max_position_size)

def generate_consolidated_signal(symbol, multi_tf_analysis):
    """Génère un signal unique consolidé avec gestion du risque"""
    if not multi_tf_analysis:
        return None

    consolidated_score = multi_tf_analysis['consolidated_score']
    current_price = multi_tf_analysis['current_price']
    atr = multi_tf_analysis['atr']

    # Seuils de décision
    buy_threshold = 0.3
    sell_threshold = -0.3

    signal = None
    entry_price = current_price
    stop_loss = 0
    take_profit = 0
    position_size = 0
    max_profit = 0

    if consolidated_score > buy_threshold:
        # Signal d'achat
        signal = 'BUY'
        entry_price = current_price
        stop_loss = current_price - (atr * 2)  # SL à 2 ATR
        take_profit = current_price + (atr * 4)  # TP à 4 ATR (ratio 1:2)

        # Calculer la taille de position
        position_size = calculate_position_sizing(entry_price, stop_loss)
        max_profit = (take_profit - entry_price) * position_size

        # Ajuster le TP si le profit dépasse 30$
        if max_profit > 30:
            take_profit = entry_price + (30 / position_size)
            max_profit = 30

    elif consolidated_score < sell_threshold:
        # Signal de vente
        signal = 'SELL'
        entry_price = current_price
        stop_loss = current_price + (atr * 2)  # SL à 2 ATR
        take_profit = current_price - (atr * 4)  # TP à 4 ATR (ratio 1:2)

        # Calculer la taille de position
        position_size = calculate_position_sizing(entry_price, stop_loss)
        max_profit = (entry_price - take_profit) * position_size

        # Ajuster le TP si le profit dépasse 30$
        if max_profit > 30:
            take_profit = entry_price - (30 / position_size)
            max_profit = 30

    if signal:
        # Calculer la confiance basée sur la cohérence des timeframes
        timeframe_scores = [tf['score'] for tf in multi_tf_analysis['timeframe_analysis']]
        score_consistency = 1 - (np.std(timeframe_scores) / 2)  # Plus les scores sont cohérents, plus la confiance est élevée
        confidence = min(0.95, max(0.5, abs(consolidated_score) * score_consistency))

        return {
            'symbol': symbol,
            'signal': signal,
            'entry_price': round(entry_price, 5),
            'stop_loss': round(stop_loss, 5),
            'take_profit': round(take_profit, 5),
            'position_size': round(position_size, 2),
            'max_profit': round(max_profit, 2),
            'max_loss': round(abs(entry_price - stop_loss) * position_size, 2),
            'confidence': round(confidence, 2),
            'consolidated_score': round(consolidated_score, 3),
            'risk_reward_ratio': round(abs(take_profit - entry_price) / abs(entry_price - stop_loss), 2)
        }

    return None

def auto_scan_symbols(selected_categories=None):
    """Scanne automatiquement tous les symboles pour trouver les meilleures opportunités avec analyse multi-timeframe"""
    if not st.session_state.mt5_connected:
        return []

    try:
        all_symbols = get_all_symbols()
        if not all_symbols:
            return []

        # Définir les catégories de symboles
        symbol_categories = {
            'Forex Majors': ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCAD', 'NZDUSD', 'USDCHF'],
            'Forex Crosses': ['EURJPY', 'GBPJPY', 'AUDJPY', 'CADJPY', 'NZDJPY', 'CHFJPY', 'EURGBP', 'EURAUD', 'EURCAD', 'EURNZD', 'EURCHF', 'GBPAUD', 'GBPCAD', 'GBPNZD', 'GBPCHF', 'AUDCAD', 'AUDNZD', 'AUDCHF', 'CADCHF', 'NZDCHF'],
            'Commodities': ['GOLD', 'SILVER', 'OIL', 'CRUDE', 'BRENT', 'COPPER', 'PLATINUM'],
            'Indices': ['NAS100', 'SPX500', 'US30', 'UK100', 'GER30', 'FRA40', 'JPN225', 'AUS200'],
            'Synthetics': ['BOOM', 'CRASH', 'INDEX', 'STEP', 'RANGE_BREAK'],
            'Crypto': ['BTCUSD', 'ETHUSD', 'LTCUSD', 'XRPUSD', 'ADAUSD', 'DOTUSD']
        }

        # Filtrer les symboles selon les catégories sélectionnées
        if selected_categories and len(selected_categories) > 0:
            filtered_symbols = []
            for category in selected_categories:
                if category in symbol_categories:
                    category_keywords = symbol_categories[category]
                    category_symbols = [s for s in all_symbols if any(keyword in s.upper() for keyword in category_keywords)]
                    filtered_symbols.extend(category_symbols)
            symbols_to_scan = list(set(filtered_symbols))  # Supprimer les doublons
        else:
            # Par défaut, utiliser tous les symboles populaires
            all_keywords = []
            for keywords in symbol_categories.values():
                all_keywords.extend(keywords)
            symbols_to_scan = [s for s in all_symbols if any(keyword in s.upper() for keyword in all_keywords)]

        # Limiter à 15 symboles pour éviter la surcharge (analyse multi-timeframe plus lourde)
        symbols_to_scan = symbols_to_scan[:15] if len(symbols_to_scan) > 15 else symbols_to_scan

        scan_results = []
        progress_bar = st.progress(0)
        status_text = st.empty()

        for idx, symbol in enumerate(symbols_to_scan):
            progress = (idx + 1) / len(symbols_to_scan)
            progress_bar.progress(progress)
            status_text.text(f"🔍 Analyse multi-timeframe de {symbol}...")

            try:
                # Analyse multi-timeframe
                multi_tf_analysis = analyze_multi_timeframe_trend(symbol)
                if not multi_tf_analysis:
                    continue

                # Générer le signal consolidé
                consolidated_signal = generate_consolidated_signal(symbol, multi_tf_analysis)
                if consolidated_signal:
                    scan_results.append(consolidated_signal)

            except Exception as e:
                st.error(f"Erreur lors de l'analyse de {symbol}: {e}")
                continue

        progress_bar.empty()
        status_text.empty()

        # Trier par confiance décroissante
        scan_results.sort(key=lambda x: x['confidence'], reverse=True)
        return scan_results

    except Exception as e:
        st.error(f"Erreur lors du scan automatique: {e}")
        return []

def send_autoscan_notifications(scan_results):
    """Envoie automatiquement les notifications pour les signaux détectés par l'autoscan"""
    try:
        # Filtrer les meilleurs signaux (score > 0.7)
        best_signals = [r for r in scan_results if r.get('quality_score', 0) > 0.7]
        
        if not best_signals:
            return
        
        # Prendre le meilleur signal
        best_signal = max(best_signals, key=lambda x: x.get('quality_score', 0))
        
        # Créer le message de notification
        symbol = best_signal.get('symbol', 'N/A')
        score = best_signal.get('quality_score', 0)
        signals = best_signal.get('signals', [])
        
        if signals:
            signal = signals[0]  # Prendre le premier signal
            signal_type = signal.get('type', 'N/A')
            direction = signal.get('direction', 'N/A')
            confidence = signal.get('confidence', 0)
            
            # Format du message
            emoji = "🟢" if signal_type == "BUY" else "🔴"
            message = f"{emoji} AUTOSCAN SIGNAL\n"
            message += f"📊 {symbol}\n"
            message += f"💰 {signal_type} - {direction}\n"
            message += f"🎯 Confiance: {confidence*100:.0f}%\n"
            message += f"⭐ Score: {score*100:.0f}%\n"
            message += f"⏰ {datetime.now().strftime('%H:%M:%S')}\n"
            message += "🤖 TradBOT Autoscan"
            
            # Envoyer par WhatsApp et SMS si configuré
            if hasattr(st.session_state, 'sms_provider') and st.session_state.sms_provider:
                try:
                    # Utiliser le service de notification unifié
                    from src.unified_notification_service import send_trading_signal
                    send_trading_signal(symbol, signal_type, 0, confidence)
                    st.success("📱 Notifications envoyées automatiquement")
                except Exception as e:
                    st.warning(f"⚠️ Erreur envoi notifications: {e}")
                    
    except Exception as e:
        st.error(f"❌ Erreur lors de l'envoi des notifications: {e}")

def display_scan_results(scan_results):
    """Affiche les résultats du scan automatique avec analyse multi-timeframe"""
    if not scan_results:
        st.info("🔍 Aucune opportunité de trading détectée lors du scan automatique.")
        return

    # Vérifier le format des données (nouveau vs ancien)
    is_new_format = 'signal' in scan_results[0] if scan_results else False

    if is_new_format:
        st.subheader(f"🎯 {len(scan_results)} Signaux Consolidés Multi-Timeframe")

        # Afficher le meilleur signal en évidence
        if scan_results:
            best_signal = scan_results[0]
            st.success(f"🏆 **MEILLEUR SIGNAL**: {best_signal['symbol']} - {best_signal['signal']} - Confiance: {best_signal['confidence']:.1%}")

        # Créer un DataFrame pour l'affichage
        display_data = []
        for result in scan_results:
            signal_emoji = "🟢" if result['signal'] == 'BUY' else "🔴"
            display_data.append({
                'Symbole': result['symbol'],
                'Signal': f"{signal_emoji} {result['signal']}",
                'Prix Entrée': f"{result['entry_price']:.5f}",
                'Stop Loss': f"{result['stop_loss']:.5f}",
                'Take Profit': f"{result['take_profit']:.5f}",
                'Taille Position': f"{result['position_size']:.2f}",
                'Profit Max': f"${result['max_profit']:.2f}",
                'Perte Max': f"${result['max_loss']:.2f}",
                'Confiance': f"{result['confidence']:.1%}",
                'R/R Ratio': f"1:{result['risk_reward_ratio']:.1f}"
            })
    else:
        # Ancien format - affichage simplifié
        st.subheader(f"🎯 {len(scan_results)} Opportunités Détectées")

        # Créer un DataFrame pour l'affichage (ancien format)
        display_data = []
        for result in scan_results:
            display_data.append({
                'Symbole': result.get('symbol', 'N/A'),
                'Prix': f"{result.get('price', 0):.5f}",
                'RSI': f"{result.get('rsi', 0):.1f}",
                'ADX': f"{result.get('adx', 0):.1f}",
                'Score': f"{result.get('quality_score', 0):.2f}",
                'Signaux': result.get('signal_count', 0),
                'Conditions': result.get('market_conditions', 'N/A')
            })

    df_display = pd.DataFrame(display_data)
    st.dataframe(df_display, use_container_width=True)

    # Section des détails des signaux désactivée - Utilisez le Signal Unifié Unique
    if False:  # Désactivé - Utilisez le Signal Unifié Unique
        if is_new_format:
            st.subheader("🏆 Détails des Signaux")
            for i, result in enumerate(scan_results[:5]):  # Top 5
                signal_emoji = "🟢" if result['signal'] == 'BUY' else "🔴"
                with st.expander(f"#{i+1} {signal_emoji} {result['symbol']} - {result['signal']} - Confiance: {result['confidence']:.1%}", expanded=i==0):

                    # Métriques principales
                    col1, col2, col3, col4 = st.columns(4)

                    with col1:
                        st.metric("Prix Entrée", f"{result['entry_price']:.5f}")
                        st.metric("Stop Loss", f"{result['stop_loss']:.5f}")

                    with col2:
                        st.metric("Take Profit", f"{result['take_profit']:.5f}")
                        st.metric("Taille Position", f"{result['position_size']:.2f}")

                    with col3:
                        st.metric("Profit Max", f"${result['max_profit']:.2f}")
                        st.metric("Perte Max", f"${result['max_loss']:.2f}")

                    with col4:
                        st.metric("Confiance", f"{result['confidence']:.1%}")
                        st.metric("R/R Ratio", f"1:{result['risk_reward_ratio']:.1f}")

                    # Informations sur l'analyse multi-timeframe
                    st.subheader("📊 Analyse Multi-Timeframe")
                    st.write(f"**Score Consolidé**: {result['consolidated_score']:.3f}")

                    # Bouton pour analyser le symbole
                    if st.button(f"📈 Analyser {result['symbol']} en détail", key=f"analyze_{result['symbol']}"):
                        st.session_state.current_symbol = result['symbol']
                        st.rerun()

                    # Informations de gestion du risque
                    st.subheader("💰 Gestion du Risque")
                    col1, col2 = st.columns(2)

                    with col1:
                        st.info(f"**Capital Maximum**: $20.00")
                        st.info(f"**Risque par Trade**: 10% (${result['max_loss']:.2f})")

                    with col2:
                        st.success(f"**Profit Potentiel**: ${result['max_profit']:.2f}")
                        st.success(f"**Ratio Risque/Récompense**: 1:{result['risk_reward_ratio']:.1f}")

                    # Recommandations
                    if result['confidence'] >= 0.8:
                        st.success("✅ **SIGNAL FORT** - Recommandé pour le trading")
                    elif result['confidence'] >= 0.6:
                        st.warning("⚠️ **SIGNAL MODÉRÉ** - Surveiller les conditions du marché")
                    else:
                        st.info("ℹ️ **SIGNAL FAIBLE** - Attendre une meilleure opportunité")
    
    # Message informatif pour le Signal Unifié
    st.info("""
    🎯 **Signal Unifié Unique Activé**
    
    Les détails des signaux multiples ont été désactivés. 
    Utilisez le **Signal Unifié Unique** dans l'onglet Trading qui combine :
    - 🤖 IA (Indicateurs techniques)
    - 🧠 ML (Patterns & momentum) 
    - 📊 Backend (Trend multi-timeframe)
    
    Ce signal unique est fiable à 100% et affiche uniquement BUY LIMIT ou SELL LIMIT.
    """)
    
    # Section des opportunités simplifiées désactivée - Utilisez le Signal Unifié Unique

# Header de l'application
st.markdown(f"""
<div class="header-container">
    <h1 class="header-title">📈 TradBOT Pro</h1>
    <p class="header-subtitle">Trading automatisé avec Intelligence Artificielle - Temps Réel</p>
    <div class="status-indicators">
        <span class="status-badge {'success' if st.session_state.mt5_connected else 'error'}">
            {'🟢 MT5 Connecté' if st.session_state.mt5_connected else '🔴 MT5 Déconnecté'}
        </span>
        <span class="status-badge {'success' if st.session_state.get("signal_api_started") else 'warning'}">
            {'🛰️ API Active' if st.session_state.get("signal_api_started") else '📁 API Inactive'}
        </span>
        <span class="status-badge warning">⚡ Mode Temps Réel</span>
    </div>
</div>
""", unsafe_allow_html=True)

# Démarrer automatiquement l'API Signaux (si disponible)
_ensure_signal_api()

# Navigation par onglets
tab1, tab2, tab3, tab4, tab5 = st.tabs(["📊 Trading", "📈 Analyse", "🎯 Signaux", "🔍 Auto Scan", "⚙️ Configuration"])

# --- SIDEBAR ---
with st.sidebar:
    st.image("https://i.ibb.co/VtP5gTq/logo-tradbot-pro.png", width=150)

    with st.expander("🔗 Connexion MT5", expanded=not st.session_state.mt5_connected):
        if st.button("🔌 Connecter / Tester MT5", use_container_width=True):
            with st.spinner("Connexion en cours..."):
                if MT5_AVAILABLE:
                    try:
                        connect()
                        st.session_state.mt5_connected = is_connected()
                        if st.session_state.mt5_connected:
                            st.success("✅ Connecté à MT5!")
                            st.rerun()
                        else:
                            st.error("❌ Échec de la connexion. Vérifiez .env")
                    except Exception as e:
                        st.error(f"❌ Erreur de connexion: {e}")
                else:
                    st.error("❌ Module MT5 non disponible.")

    if st.session_state.mt5_connected:
        with st.expander("📈 Sélection d'Actifs", expanded=True):
            try:
                with st.spinner("Chargement des symboles MT5..."):
                    all_symbols = get_all_symbols()
                if all_symbols:
                    search = st.text_input("Rechercher un symbole", "").upper()
                    filtered = [s for s in all_symbols if search in s.upper()] if search else all_symbols
                    selected_symbol = st.selectbox(
                        "Choisir un symbole MT5",
                        filtered,
                        index=filtered.index(st.session_state.current_symbol) if st.session_state.current_symbol in filtered else 0,
                    )
                    if selected_symbol != st.session_state.current_symbol:
                        st.session_state.current_symbol = selected_symbol
                        st.session_state.real_time_data = pd.DataFrame()
                        st.rerun()
                else:
                    st.warning("Aucun symbole chargé depuis MT5.")
                    st.session_state.current_symbol = st.text_input("Symbole manuel", st.session_state.current_symbol)
            except Exception as e:
                st.error(f"Erreur chargement symboles: {e}")
                st.session_state.current_symbol = st.text_input("Symbole manuel", st.session_state.current_symbol)

        timeframe_options = ["1m", "5m", "10m", "15m", "30m", "1h", "4h", "6h", "8h", "1d"]
        selected_timeframe = st.selectbox(
            "Timeframe",
            timeframe_options,
            index=timeframe_options.index(st.session_state.current_timeframe)
        )
        if selected_timeframe != st.session_state.current_timeframe:
            st.session_state.current_timeframe = selected_timeframe
            st.session_state.real_time_data = pd.DataFrame()
            st.rerun()
    else:
        st.warning("Veuillez vous connecter à MT5 pour continuer.")

    with st.expander("📊 Contrôles Graphique", expanded=True):
        st.session_state.show_trendlines = st.checkbox("📈 Trendlines", value=True)
        st.session_state.show_fibonacci = st.checkbox("🌀 Fibonacci", value=True)
        st.session_state.show_fibonacci_labels = st.checkbox("🏷️ Labels Fibonacci", value=True, help="Affiche les labels des niveaux de retracement Fibonacci")
        st.session_state.show_current_price = st.checkbox("💰 Prix actuel", value=True)
        st.session_state.show_ask_bid = st.checkbox("🟢🔴 ASK/BID", value=True, help="Affiche les prix d'achat (ASK) et de vente (BID) sur le graphique")
        st.session_state.show_sr_zones = st.checkbox("🧱 Zones S/R", value=True)
        st.session_state.enable_spike_sounds = st.checkbox("🔊 Bips Spikes", value=True, help="Active les bips sonores pour les alertes de spikes imminents")
    
    # Indicateur d'autoscan
    if st.session_state.get('autoscan_enabled', False):
        with st.expander("🔄 Statut Autoscan", expanded=True):
            st.success("🟢 Autoscan ACTIF")
            
            # Afficher le temps jusqu'au prochain scan
            if 'last_autoscan_time' in st.session_state:
                current_time = time.time()
                time_since_last = current_time - st.session_state.last_autoscan_time
                interval = st.session_state.get('autoscan_interval', 120)
                time_until_next = interval - time_since_last
                
                if time_until_next > 0:
                    progress = (interval - time_until_next) / interval
                    st.progress(progress)
                    st.caption(f"Prochain scan dans {int(time_until_next)}s")
                else:
                    st.info("🔄 Scan en cours...")
            
            # Afficher les dernières statistiques
            if 'scan_results' in st.session_state and st.session_state.scan_results:
                st.metric("Dernières opportunités", len(st.session_state.scan_results))
                if st.session_state.scan_results:
                    best_score = max(r.get('quality_score', 0) for r in st.session_state.scan_results)
                    st.metric("Meilleur score", f"{best_score:.2f}")
            else:
                st.info("Aucun scan récent")

    with st.expander("⚙️ Configuration", expanded=False):
        auto_refresh = st.checkbox("Rafraîchissement auto", value=True)
        refresh_interval = st.slider("Intervalle (s)", 5, 60, 10)
        if auto_refresh:
            st_autorefresh(interval=refresh_interval * 1000, key="realtime_refresh")
        
        # Rafraîchissement spécial pour l'autoscan
        if st.session_state.get('autoscan_enabled', False):
            autoscan_refresh_interval = min(refresh_interval, 30)  # Max 30 secondes pour l'autoscan
            st_autorefresh(interval=autoscan_refresh_interval * 1000, key="autoscan_refresh")

    # Configuration SMS et WhatsApp - Utilisation automatique des credentials .env
    with st.expander("📱 Configuration Notifications", expanded=False):
        st.subheader("🔔 Alertes SMS & WhatsApp")
        
        # Déterminer automatiquement les providers disponibles
        firebase_available = bool(os.getenv('FIREBASE_PROJECT_ID') and os.getenv('FIREBASE_PRIVATE_KEY') and os.getenv('FIREBASE_CLIENT_EMAIL') and os.getenv('PHONE_NUMBER'))
        vonage_available = bool(os.getenv('VONAGE_API_KEY') and os.getenv('VONAGE_API_SECRET') and os.getenv('PHONE_NUMBER'))
        twilio_available = bool(os.getenv('TWILIO_ACCOUNT_SID') and os.getenv('TWILIO_AUTH_TOKEN') and os.getenv('PHONE_NUMBER'))
        whatsapp_twilio_available = bool(os.getenv('TWILIO_ACCOUNT_SID') and os.getenv('TWILIO_AUTH_TOKEN') and os.getenv('WHATSAPP_FROM_NUMBER') and os.getenv('WHATSAPP_NUMBER'))
        whatsapp_api_available = bool(os.getenv('WHATSAPP_ACCESS_TOKEN') and os.getenv('WHATSAPP_NUMBER'))
        
        # Configuration automatique des providers (priorité: Firebase > Vonage > Twilio)
        if firebase_available:
            st.session_state.sms_provider = 'firebase'
            st.success("✅ SMS Firebase activé (10,000 SMS gratuits/mois)")
        elif vonage_available:
            st.session_state.sms_provider = 'vonage'
            st.success("✅ SMS Vonage activé")
        elif twilio_available:
            st.session_state.sms_provider = 'twilio'
            st.success("✅ SMS Twilio activé")
        else:
            st.session_state.sms_provider = 'none'
            
        if whatsapp_twilio_available:
            st.session_state.whatsapp_provider = 'twilio'
            st.success("✅ WhatsApp Twilio activé")
        elif whatsapp_api_available:
            st.session_state.whatsapp_provider = 'api'
            st.success("✅ WhatsApp API activé")
        else:
            st.session_state.whatsapp_provider = 'none'
        
        # Test des notifications
        if st.button("🧪 Tester Notifications"):
            test_message = f"🧪 Test TradBOT - {datetime.now().strftime('%H:%M:%S')}"
            
            if st.session_state.sms_provider == 'firebase':
                send_sms_firebase(test_message)
            elif st.session_state.sms_provider == 'vonage':
                send_sms_vonage(test_message)
            elif st.session_state.sms_provider == 'twilio':
                send_sms_twilio(test_message)
                
            if st.session_state.whatsapp_provider == 'twilio':
                send_whatsapp_twilio(test_message)
            elif st.session_state.whatsapp_provider == 'api':
                send_whatsapp_api(test_message)
        
        # Options d'envoi
        st.subheader("📤 Options d'Envoi")
        st.session_state.send_spike_sms = st.checkbox("🚀 Envoyer pour les spikes", value=True)
        st.session_state.send_prediction_sms = st.checkbox("🎯 Envoyer pour les prédictions", value=True)
        
        # Gestion des quotas et statistiques
        st.subheader("📊 Gestion des Quotas")
        
        # Afficher les signaux envoyés récemment
        if 'sent_signals' in st.session_state and st.session_state.sent_signals:
            st.write("**Signaux envoyés récemment :**")
            for signal_key, timestamp in st.session_state.sent_signals.items():
                time_ago = (datetime.now() - timestamp).total_seconds()
                if time_ago < 300:  # Afficher seulement les 5 dernières minutes
                    st.write(f"• {signal_key} - il y a {int(time_ago)}s")
        
        # Bouton pour réinitialiser les quotas
        if st.button("🔄 Réinitialiser les Quotas"):
            st.session_state.sent_signals = {}
            st.success("✅ Quotas réinitialisés")
        
        # Informations sur les limites
        st.info("""
        **Limites de Quota :**
        - 📱 SMS : 1 signal par minute par type
        - 💬 WhatsApp : 1 signal par minute par type
        - 🔄 Auto-switch : Bascule automatiquement entre providers si quota dépassé
        """)

    # Aide Configuration .env
    with st.expander("📋 Configuration .env", expanded=False):
        st.subheader("🔧 Variables d'Environnement Requises")
        
        # Firebase
        firebase_config = {
            'FIREBASE_PROJECT_ID': os.getenv('FIREBASE_PROJECT_ID'),
            'FIREBASE_PRIVATE_KEY': os.getenv('FIREBASE_PRIVATE_KEY'),
            'FIREBASE_CLIENT_EMAIL': os.getenv('FIREBASE_CLIENT_EMAIL'),
            'FIREBASE_TOKEN_URI': os.getenv('FIREBASE_TOKEN_URI', 'https://oauth2.googleapis.com/token')
        }
        
        st.write("**🔥 Firebase SMS (10,000 SMS gratuits/mois) :**")
        for key, value in firebase_config.items():
            if value:
                st.success(f"✅ {key}: {value[:20]}..." if len(str(value)) > 20 else f"✅ {key}: {value}")
            else:
                st.error(f"❌ {key}: Manquant")
        
        # Vonage
        vonage_config = {
            'VONAGE_API_KEY': os.getenv('VONAGE_API_KEY'),
            'VONAGE_API_SECRET': os.getenv('VONAGE_API_SECRET')
        }
        
        st.write("**📱 Vonage SMS :**")
        for key, value in vonage_config.items():
            if value:
                st.success(f"✅ {key}: {value[:20]}..." if len(str(value)) > 20 else f"✅ {key}: {value}")
            else:
                st.error(f"❌ {key}: Manquant")
        
        # Twilio
        twilio_config = {
            'TWILIO_ACCOUNT_SID': os.getenv('TWILIO_ACCOUNT_SID'),
            'TWILIO_AUTH_TOKEN': os.getenv('TWILIO_AUTH_TOKEN'),
            'TWILIO_PHONE_NUMBER': os.getenv('TWILIO_PHONE_NUMBER')
        }
        
        st.write("**📞 Twilio SMS :**")
        for key, value in twilio_config.items():
            if value:
                st.success(f"✅ {key}: {value[:20]}..." if len(str(value)) > 20 else f"✅ {key}: {value}")
            else:
                st.error(f"❌ {key}: Manquant")
        
        # Numéro de téléphone
        phone_number = os.getenv('PHONE_NUMBER')
        if phone_number:
            st.success(f"✅ PHONE_NUMBER: {phone_number}")
        else:
            st.error("❌ PHONE_NUMBER: Manquant")
        
        st.subheader("📝 Exemple de Configuration .env")
        st.code("""
# Firebase SMS (RECOMMANDÉ - 10,000 SMS gratuits/mois)
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_TOKEN_URI=https://oauth2.googleapis.com/token

# Vonage SMS (Alternative)
VONAGE_API_KEY=your-vonage-api-key
VONAGE_API_SECRET=your-vonage-api-secret

# Twilio SMS (Alternative)
TWILIO_ACCOUNT_SID=your-twilio-account-sid
TWILIO_AUTH_TOKEN=your-twilio-auth-token
TWILIO_PHONE_NUMBER=+1234567890

# Numéro de téléphone de destination
PHONE_NUMBER=+1234567890

# WhatsApp (Optionnel)
WHATSAPP_ACCESS_TOKEN=your-whatsapp-token
WHATSAPP_NUMBER=+1234567890
WHATSAPP_FROM_NUMBER=+1234567890
        """, language="bash")

    with st.expander("🛰️ API Signaux (MT5)", expanded=False):
        if st.button("Vérifier API", key="btn_check_signal_api"):
            _ensure_signal_api()
        if st.button("🚀 Démarrer API", key="btn_start_api"):
            st.info("💡 Exécutez dans un terminal :")
            st.code("python start_signal_api.py", language="bash")
        if st.session_state.get("signal_api_started"):
            st.success("API active: http://localhost:8001/signals")
        else:
            st.info("API non active. Fallback: signals.json")

# --- ZONE PRINCIPALE ---
if st.session_state.current_symbol and st.session_state.mt5_connected:
    symbol = st.session_state.current_symbol
    if st.session_state.real_time_data.empty:
        update_real_time_data()

    col1, col2, col3, col4 = st.columns(4)
    with col1:
        st.metric("💱 Symbole", symbol)
    with col2:
        current_price = get_real_time_price(symbol)
        ask_price, bid_price = get_ask_bid_prices(symbol)
        
        if current_price:
            price_format = f"{current_price:.3f}" if 'JPY' in symbol or 'Index' in symbol else f"{current_price:.5f}"
            st.metric("💰 Prix Actuel", price_format)
            
            # Afficher ASK et BID si disponibles
            if ask_price and bid_price:
                ask_format = f"{ask_price:.3f}" if 'JPY' in symbol or 'Index' in symbol else f"{ask_price:.5f}"
                bid_format = f"{bid_price:.3f}" if 'JPY' in symbol or 'Index' in symbol else f"{bid_price:.5f}"
                
                col_ask, col_bid = st.columns(2)
                with col_ask:
                    st.metric("🟢 ASK", ask_format, delta=f"+{ask_price - current_price:.5f}" if ask_price > current_price else None)
                with col_bid:
                    st.metric("🔴 BID", bid_format, delta=f"{bid_price - current_price:.5f}" if bid_price < current_price else None)
        else:
            st.metric("💰 Prix Actuel", "N/A")
    with col3:
        if not st.session_state.real_time_data.empty:
            price_change = st.session_state.real_time_data['close'].pct_change().iloc[-1] * 100
            st.metric("📊 Variation 1p", f"{price_change:.2f}%", delta=f"{price_change:.3f}%")
        else:
            st.metric("📊 Variation 1p", "N/A")
    with col4:
        if st.session_state.last_update:
            time_diff = (datetime.now() - st.session_state.last_update).seconds
            st.metric("🕒 Dernière MAJ", f"{time_diff}s ago")
        else:
            st.metric("🕒 Dernière MAJ", "N/A")

    if not st.session_state.real_time_data.empty:
        st.subheader("🎯 Signaux de Trading Avancés")
        col1, col2, col3, col4, col5 = st.columns(5)
        with col1:
            if 'RSI' in st.session_state.real_time_data.columns:
                rsi_value = st.session_state.real_time_data['RSI'].iloc[-1]
                rsi_status = "Surachat" if rsi_value > 70 else "Survente" if rsi_value < 30 else "Neutre"
                st.metric("📊 RSI", f"{rsi_value:.1f}", delta=rsi_status)
        with col2:
            if 'ADX' in st.session_state.real_time_data.columns:
                adx_value = st.session_state.real_time_data['ADX'].iloc[-1]
                adx_status = "Forte" if adx_value > 25 else "Faible"
                st.metric("💪 ADX", f"{adx_value:.1f}", delta=adx_status)
        with col3:
            if 'MACD' in st.session_state.real_time_data.columns and 'MACD_signal' in st.session_state.real_time_data.columns:
                macd_value = st.session_state.real_time_data['MACD'].iloc[-1]
                macd_signal = st.session_state.real_time_data['MACD_signal'].iloc[-1]
                macd_status = "Haussier" if macd_value > macd_signal else "Baissier"
                st.metric("📈 MACD", f"{macd_value:.4f}", delta=macd_status)
        with col4:
            if 'ATR' in st.session_state.real_time_data.columns:
                atr_value = st.session_state.real_time_data['ATR'].iloc[-1]
                st.metric("📏 ATR", f"{atr_value:.4f}")
        with col5:
            if 'Signal' in st.session_state.real_time_data.columns:
                recent_signals = st.session_state.real_time_data[st.session_state.real_time_data['Signal'] != 0].tail(10)
                signal_count = len(recent_signals)
                st.metric("🎯 Signaux", signal_count, delta="Actifs" if signal_count > 0 else "Aucun")
            else:
                st.metric("🎯 Signaux", 0, delta="Calcul en cours...")

        # Section des signaux multiples désactivée - Utilisez le Signal Unifié Unique
        if False:  # Désactivé - Utilisez le Signal Unifié Unique
            if 'Signal' in st.session_state.real_time_data.columns:
                recent_signals = st.session_state.real_time_data[st.session_state.real_time_data['Signal'] != 0].tail(5)
                if not recent_signals.empty:
                    st.subheader("🚀 Signaux de Trading Actuels")
                    for idx, signal in recent_signals.iterrows():
                        signal_type = "🟢 ACHAT" if signal['Signal'] == 1 else "🔴 VENTE"
                        confidence = signal['Confidence'] * 100
                        strategy = signal['Strategy']
                        col1, col2, col3 = st.columns([2, 1, 1])
                        with col1:
                            st.markdown(f"""
                            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                            padding: 1rem; border-radius: 10px; color: white; margin: 0.5rem 0;">
                            <h4>{signal_type} - {strategy}</h4>
                            <p><strong>Prix d'entrée:</strong> {signal['Entry_Price']:.4f}</p>
                            <p><strong>Stop Loss:</strong> {signal['Stop_Loss']:.4f}</p>
                            <p><strong>Take Profit:</strong> {signal['Take_Profit']:.4f}</p>
                            <p><strong>Confiance:</strong> {confidence:.1f}%</p>
                            </div>
                            """, unsafe_allow_html=True)
                        with col2:
                            if st.button(f"📊 Analyser", key=f"analyze_{idx}"):
                                st.info(f"Analyse détaillée du signal {strategy}")
                        with col3:
                            if st.button(f"📱 Alerter", key=f"alert_{idx}"):
                                st.success("Alerte envoyée!")
                else:
                    st.info("🔍 Aucun signal de trading détecté actuellement. Attendez une meilleure opportunité.")
        
        # Message informatif pour le Signal Unifié
        st.info("""
        🎯 **Signal Unifié Unique Activé**
        
        Les multiples signaux de trading ont été désactivés. 
        Utilisez le **Signal Unifié Unique** qui combine :
        - 🤖 IA (Indicateurs techniques)
        - 🧠 ML (Patterns & momentum) 
        - 📊 Backend (Trend multi-timeframe)
        
        Ce signal unique est fiable à 100% et affiche uniquement BUY LIMIT ou SELL LIMIT.
        """)

        st.subheader("💡 Recommandations de Trading")
        if not st.session_state.real_time_data.empty:
            current_rsi = st.session_state.real_time_data['RSI'].iloc[-1] if 'RSI' in st.session_state.real_time_data.columns else 50
            current_adx = st.session_state.real_time_data['ADX'].iloc[-1] if 'ADX' in st.session_state.real_time_data.columns else 20
            if current_rsi < 30 and current_adx > 25:
                st.success("🟢 Signal d'achat fort détecté! RSI en survente avec tendance forte.")
            elif current_rsi > 70 and current_adx > 25:
                st.warning("🔴 Signal de vente fort détecté! RSI en surachat avec tendance forte.")
            elif current_adx < 20:
                st.info("⏸️ Marché en consolidation. Attendez une cassure de tendance.")
            else:
                st.info("📊 Marché neutre. Surveillez les niveaux de support/résistance.")

    if st.button("🔄 Actualiser les données", key="refresh_data_btn_main"):
        with st.spinner("Mise à jour..."):
            update_real_time_data()
            st.rerun()

    # --- Onglet Trading ---
    with tab1:
        st.header(f"Graphique en direct pour {st.session_state.current_symbol} ({st.session_state.current_timeframe})")
        if not st.session_state.real_time_data.empty:
            df = st.session_state.real_time_data
            required_cols = ['open', 'high', 'low', 'close']
            if not all(col in df.columns for col in required_cols):
                st.error(f"❌ Données invalides. Colonnes OHLC manquantes. Colonnes trouvées: {list(df.columns)}")
            else:
                chart_title = f"{symbol} - {st.session_state.current_timeframe} - Temps Réel"
                fig = create_candlestick_chart(df, chart_title)
                if fig:
                    fig.update_layout(
                        height=800,
                        template="plotly_dark",
                        xaxis_rangeslider_visible=False,
                        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
                        uirevision="streaming"
                    )
                    fig = add_technical_indicators_to_chart(fig, df, ['sma', 'ema', 'channels'])

                    # Zones OTE supprimées par demande de l'utilisateur

                    # Ajouter les trendlines
                    if st.session_state.get('show_trendlines', True):
                        try:
                            df_tail = df.tail(100)
                            pivot_highs = df_tail[df_tail['high'] == df_tail['high'].rolling(5, center=True).max()].dropna()
                            pivot_lows = df_tail[df_tail['low'] == df_tail['low'].rolling(5, center=True).min()].dropna()
                            if len(pivot_highs) >= 2:
                                ph = pivot_highs.tail(2)
                                fig.add_trace(go.Scatter(x=ph.index, y=ph['high'], mode="lines", line=dict(color="#e74c3c", width=2, dash="dash"), name="Résistance"))
                            if len(pivot_lows) >= 2:
                                pl = pivot_lows.tail(2)
                                fig.add_trace(go.Scatter(x=pl.index, y=pl['low'], mode="lines", line=dict(color="#2ecc71", width=2, dash="dash"), name="Support"))
                        except Exception as e:
                            st.warning(f"Impossible d'afficher les trendlines: {e}")

                    # Ajouter le prix actuel et les prix ASK/BID
                    if st.session_state.get('show_current_price', True) and current_price:
                        # Prix actuel (moyenne)
                        fig.add_hline(y=current_price, line_color="#ffffff", line_dash="solid", opacity=1.0, line_width=2,
                                      annotation_text=f"Prix: {current_price:.5f}", annotation_position="right")
                        
                        # Récupérer les prix ASK et BID pour le graphique (si activé)
                        if st.session_state.get('show_ask_bid', True):
                            ask_price, bid_price = get_ask_bid_prices(symbol)
                            if ask_price and bid_price:
                                # Calculer le spread
                                spread = ask_price - bid_price
                                spread_pips = spread * 10000 if 'JPY' not in symbol else spread * 100
                                
                                # Ligne ASK (prix d'achat) - Vert dynamique
                                fig.add_hline(
                                    y=ask_price, 
                                    line_color="#00ff00", 
                                    line_dash="solid", 
                                    opacity=0.9, 
                                    line_width=2,
                                    annotation_text=f"🟢 ASK: {ask_price:.5f}", 
                                    annotation_position="right",
                                    annotation_font_size=10,
                                    annotation_font_color="#00ff00",
                                    annotation_bgcolor="rgba(0,255,0,0.1)",
                                    annotation_bordercolor="#00ff00"
                                )
                                
                                # Ligne BID (prix de vente) - Rouge dynamique
                                fig.add_hline(
                                    y=bid_price, 
                                    line_color="#ff0000", 
                                    line_dash="solid", 
                                    opacity=0.9, 
                                    line_width=2,
                                    annotation_text=f"🔴 BID: {bid_price:.5f}", 
                                    annotation_position="right",
                                    annotation_font_size=10,
                                    annotation_font_color="#ff0000",
                                    annotation_bgcolor="rgba(255,0,0,0.1)",
                                    annotation_bordercolor="#ff0000"
                                )
                                
                                # Zone de spread entre ASK et BID
                                fig.add_hrect(
                                    y0=bid_price, 
                                    y1=ask_price, 
                                    fillcolor="rgba(255,255,0,0.1)", 
                                    layer="below", 
                                    line_width=0,
                                    annotation_text=f"SPREAD: {spread:.5f} ({spread_pips:.1f} pips)",
                                    annotation_position="top right",
                                    annotation_font_size=9,
                                    annotation_font_color="#ffaa00"
                                )

                    st.plotly_chart(fig, use_container_width=True, key=f"price_chart_{st.session_state.current_timeframe}")
                else:
                    st.error("Impossible de créer le graphique.")
        else:
            st.info("⏳ En attente des données de MT5...")

    # --- Onglet Analyse ---
    with tab2:
        st.header("📈 Analyse Technique Avancée")
        if not st.session_state.real_time_data.empty:
            df = st.session_state.real_time_data
            col1, col2, col3, col4 = st.columns(4)
            with col1:
                if 'rsi' in df.columns:
                    st.metric("RSI", f"{df['rsi'].iloc[-1]:.1f}")
            with col2:
                if 'macd' in df.columns:
                    st.metric("MACD", f"{df['macd'].iloc[-1]:.4f}")
            with col3:
                if 'bb_upper' in df.columns:
                    bb_width = ((df['bb_upper'].iloc[-1] - df['bb_lower'].iloc[-1]) / df['bb_lower'].iloc[-1]) * 100
                    st.metric("BB Width", f"{bb_width:.2f}%")
            with col4:
                if 'volume' in df.columns:
                    st.metric("Volume", f"{df['volume'].iloc[-1]:,.0f}")
            st.markdown("---")
            st.markdown("### 🧠 Indicateurs Techniques Modernes (API Backend)")
            with st.expander("📊 Afficher les indicateurs avancés", expanded=False):
                try:
                    base = "http://localhost:8000"
                    params = {"symbol": symbol, "timeframe": st.session_state.current_timeframe, "count": 200}
                    with st.spinner("Chargement des indicateurs..."):
                        ms = fetch_json_with_retries(f"{base}/indicators/market_structure", params)
                        sm = fetch_json_with_retries(f"{base}/indicators/smart_money", params)
                        stn = fetch_json_with_retries(f"{base}/indicators/supertrend", params)
                    st.subheader("Synthèse des Indicateurs")
                    summary_data = {
                        "Indicateur": ["Structure Marché (BOS)", "Smart Money (OBs/FVGs)", "Supertrend"],
                        "Statut": [
                            ms.get("bos", [{}])[-1].get("direction", "N/A").upper() if ms.get("bos") else "N/A",
                            f"{len(sm.get('order_blocks', []))} OBs, {len(sm.get('fair_value_gaps', []))} FVGs",
                            stn.get("direction", "N/A").upper()
                        ]
                    }
                    st.table(pd.DataFrame(summary_data))
                except Exception as e:
                    st.error(f"Impossible de charger les indicateurs modernes: {e}")
                    st.info("Assurez-vous que le service backend (API sur le port 8000) est en cours d'exécution.")
        else:
            st.info("Pas de données à analyser.")

    # --- Onglet Signaux ---
    with tab3:
        st.header("🎯 Signaux de Trading")
        if not st.session_state.real_time_data.empty:
            try:
                st.subheader("🚨 Signal Actuel (Basé sur le ML)")

                # Vérifier si le modèle ML est entraîné
                if not st.session_state.ml_predictor.is_trained:
                    st.warning("⚠️ Modèle ML non entraîné. Entraînement en cours...")
                    with st.spinner("Entraînement du modèle ML..."):
                        try:
                            # Entraîner le modèle avec les données actuelles
                            st.session_state.ml_predictor.train_model(st.session_state.real_time_data)
                            st.session_state.ml_predictor.is_trained = True
                            st.success("✅ Modèle ML entraîné avec succès!")
                        except Exception as train_error:
                            st.error(f"❌ Erreur lors de l'entraînement: {train_error}")
                            st.info("Utilisation des signaux techniques de base...")

                            # Utiliser les signaux techniques de base si l'entraînement échoue
                            df = st.session_state.real_time_data
                            if len(df) > 50:
                                # Calculer un signal basique basé sur les indicateurs
                                rsi = df['RSI'].iloc[-1] if 'RSI' in df.columns else 50
                                macd = df['MACD'].iloc[-1] if 'MACD' in df.columns else 0
                                macd_signal = df['MACD_signal'].iloc[-1] if 'MACD_signal' in df.columns else 0

                                if rsi < 30 and macd > macd_signal:
                                    direction = "BUY"
                                    confidence = 0.75
                                elif rsi > 70 and macd < macd_signal:
                                    direction = "SELL"
                                    confidence = 0.75
                                else:
                                    direction = "HOLD"
                                    confidence = 0.5
                            else:
                                direction = "HOLD"
                                confidence = 0.5
                        else:
                            # Le modèle est entraîné, obtenir les signaux
                            ml_signals = st.session_state.ml_predictor.get_trading_signals(st.session_state.real_time_data)
                            direction = ml_signals.get('direction', 'HOLD')
                            confidence = ml_signals.get('confidence', 0.5)
                else:
                    # Le modèle est déjà entraîné
                    ml_signals = st.session_state.ml_predictor.get_trading_signals(st.session_state.real_time_data)
                    direction = ml_signals.get('direction', 'HOLD')
                    confidence = ml_signals.get('confidence', 0.5)

                # Afficher le signal
                col1, col2 = st.columns(2)
                with col1:
                    if direction == "BUY":
                        st.success(f"## 🟢 {direction}")
                    elif direction == "SELL":
                        st.error(f"## 🔴 {direction}")
                    else:
                        st.info(f"## ⚪ {direction}")
                with col2:
                    st.metric("Confiance du modèle", f"{confidence:.1%}")

                st.markdown("---")
                st.subheader("🧭 Tableau de Tendance Multi-Timeframe")
                with st.spinner("Analyse des tendances en cours..."):
                    try:
                        trend_api_url = f"http://localhost:8000/trend_summary?symbol={symbol}&nocache=1"
                        trend_response = _rq.get(trend_api_url, timeout=15)
                        if trend_response.status_code == 200:
                            trend_data = trend_response.json()
                            tf_order = ["1d", "4h", "1h", "15m", "5m", "1m"]
                            trend_table_data = []
                            for tf in tf_order:
                                tf_info = trend_data.get("trends", {}).get(tf, {})
                                trend = (tf_info.get("trend") or "neutral").lower()
                                force = int(tf_info.get("force") or 0)
                                if trend == "bullish":
                                    trend_display = f"🟢 Haussier ({force}%)"
                                elif trend == "bearish":
                                    trend_display = f"🔴 Baissier ({force}%)"
                                else:
                                    trend_display = f"⚪ Neutre ({force}%)"
                                trend_table_data.append({"Timeframe": tf.upper(), "Tendance": trend_display})
                            st.table(pd.DataFrame(trend_table_data))
                        else:
                            st.error(f"Erreur API de tendance: {trend_response.status_code}")
                    except Exception as e:
                        st.error(f"Impossible de contacter l'API de tendance: {e}")
            except Exception as e:
                st.error(f"Erreur lors du calcul des signaux: {e}")
                st.info("Utilisation des signaux techniques de base...")
        else:
            st.info("Pas de données pour générer des signaux.")

    # --- Onglet Auto Scan ---
    with tab4:
        st.header("🔍 Auto Scan - Détection Automatique d'Opportunités")

        if not st.session_state.mt5_connected:
            st.warning("⚠️ Veuillez vous connecter à MT5 pour utiliser l'Auto Scan.")
        else:
            # Configuration de l'autoscan automatique
            st.subheader("⚙️ Configuration Autoscan Automatique")
            
            col1, col2, col3 = st.columns(3)
            
            with col1:
                # Activer/désactiver l'autoscan
                if 'autoscan_enabled' not in st.session_state:
                    st.session_state.autoscan_enabled = False
                
                autoscan_enabled = st.checkbox(
                    "🔄 Autoscan Automatique", 
                    value=st.session_state.autoscan_enabled,
                    help="Active le scan automatique toutes les 2 minutes"
                )
                st.session_state.autoscan_enabled = autoscan_enabled
                
            with col2:
                # Intervalle de scan
                if 'autoscan_interval' not in st.session_state:
                    st.session_state.autoscan_interval = 120  # 2 minutes
                
                autoscan_interval = st.selectbox(
                    "⏱️ Intervalle de Scan",
                    [60, 120, 300, 600],  # 1min, 2min, 5min, 10min
                    index=[60, 120, 300, 600].index(st.session_state.autoscan_interval),
                    format_func=lambda x: f"{x//60} minute{'s' if x//60 > 1 else ''}"
                )
                st.session_state.autoscan_interval = autoscan_interval
                
            with col3:
                # Notifications automatiques
                if 'autoscan_notifications' not in st.session_state:
                    st.session_state.autoscan_notifications = True
                
                autoscan_notifications = st.checkbox(
                    "📱 Notifications Auto",
                    value=st.session_state.autoscan_notifications,
                    help="Envoie automatiquement les signaux par WhatsApp/SMS"
                )
                st.session_state.autoscan_notifications = autoscan_notifications
            
            # Statut de l'autoscan
            if st.session_state.autoscan_enabled:
                st.success("🟢 Autoscan ACTIF - Scan automatique toutes les 2 minutes")
                
                # Timer pour le prochain scan
                if 'last_autoscan_time' not in st.session_state:
                    st.session_state.last_autoscan_time = 0
                
                current_time = time.time()
                time_since_last_scan = current_time - st.session_state.last_autoscan_time
                time_until_next = st.session_state.autoscan_interval - time_since_last_scan
                
                if time_until_next > 0:
                    st.info(f"⏳ Prochain scan dans {int(time_until_next)} secondes")
                else:
                    st.warning("🔄 Scan en cours...")
                    
                    # Lancer le scan automatique
                    with st.spinner("Autoscan en cours..."):
                        try:
                            # Catégories par défaut pour l'autoscan
                            default_categories = ['Synthetics', 'Indices']  # Focus sur Boom/Crash
                            scan_results = auto_scan_symbols(default_categories)
                            
                            if scan_results:
                                st.session_state.scan_results = scan_results
                                st.session_state.last_autoscan_time = current_time
                                
                                # Envoyer les notifications si activées
                                if st.session_state.autoscan_notifications:
                                    send_autoscan_notifications(scan_results)
                                
                                st.success(f"✅ Autoscan terminé - {len(scan_results)} opportunités détectées")
                            else:
                                st.info("ℹ️ Autoscan terminé - Aucune opportunité détectée")
                                st.session_state.last_autoscan_time = current_time
                                
                        except Exception as e:
                            st.error(f"❌ Erreur lors de l'autoscan: {e}")
                            st.session_state.last_autoscan_time = current_time
            else:
                st.info("🔴 Autoscan INACTIF - Activez pour le scan automatique")
            
            st.markdown("---")
            # Sélection des catégories
            st.subheader("📊 Sélection des Catégories")
            col1, col2, col3 = st.columns(3)

            with col1:
                forex_majors = st.checkbox("💱 Forex Majors", value=True)
                forex_crosses = st.checkbox("🔄 Forex Crosses", value=True)

            with col2:
                commodities = st.checkbox("🥇 Commodities", value=True)
                indices = st.checkbox("📈 Indices", value=True)

            with col3:
                synthetics = st.checkbox("🎯 Synthetics", value=True)
                crypto = st.checkbox("🪙 Crypto", value=False)

            # Préparer les catégories sélectionnées
            selected_categories = []
            if forex_majors:
                selected_categories.append('Forex Majors')
            if forex_crosses:
                selected_categories.append('Forex Crosses')
            if commodities:
                selected_categories.append('Commodities')
            if indices:
                selected_categories.append('Indices')
            if synthetics:
                selected_categories.append('Synthetics')
            if crypto:
                selected_categories.append('Crypto')

            st.markdown("---")

            col1, col2, col3 = st.columns([2, 1, 1])

            with col1:
                st.subheader("🎯 Scanner Automatique")
                st.write("Le scanner analyse automatiquement les symboles sélectionnés pour détecter les meilleures opportunités de trading basées sur :")
                st.write("• **Stratégies avancées** : BOS (Break of Structure), Liquidité")
                st.write("• **Support/Résistance confirmés** avec tests multiples")
                st.write("• **Signaux d'Intelligence Artificielle**")
                st.write("• **Conditions de marché favorables** (RSI, ADX, Tendance)")
                st.write("• **Score de qualité** basé sur la confiance des signaux")

                if selected_categories:
                    st.info(f"📋 Catégories sélectionnées : {', '.join(selected_categories)}")
                else:
                    st.warning("⚠️ Veuillez sélectionner au moins une catégorie de symboles.")

            with col2:
                if st.button("🚀 Lancer le Scan", use_container_width=True, type="primary", disabled=not selected_categories):
                    with st.spinner("Scan en cours..."):
                        scan_results = auto_scan_symbols(selected_categories)
                        st.session_state.scan_results = scan_results
                        st.rerun()

            with col3:
                if st.button("🔄 Actualiser", use_container_width=True):
                    if 'scan_results' in st.session_state:
                        del st.session_state.scan_results
                    st.rerun()

            # Afficher les résultats du scan
            if 'scan_results' in st.session_state and st.session_state.scan_results:
                display_scan_results(st.session_state.scan_results)
            elif 'scan_results' in st.session_state and not st.session_state.scan_results:
                st.info("🔍 Aucune opportunité de trading détectée lors du dernier scan.")
            else:
                st.info("💡 Cliquez sur 'Lancer le Scan' pour analyser automatiquement tous les symboles disponibles.")

            # Statistiques du scan
            if 'scan_results' in st.session_state and st.session_state.scan_results:
                st.subheader("📊 Statistiques du Scan")
                col1, col2, col3, col4 = st.columns(4)

                with col1:
                    st.metric("Opportunités", len(st.session_state.scan_results))

                with col2:
                    if st.session_state.scan_results:
                        avg_score = sum(r.get('quality_score', 0) for r in st.session_state.scan_results) / len(st.session_state.scan_results)
                        st.metric("Score Moyen", f"{avg_score:.2f}")
                    else:
                        st.metric("Score Moyen", "0.00")

                with col3:
                    if st.session_state.scan_results:
                        total_signals = sum(r.get('signal_count', 0) for r in st.session_state.scan_results)
                        st.metric("Signaux Totaux", total_signals)
                    else:
                        st.metric("Signaux Totaux", 0)

                with col4:
                    if st.session_state.scan_results:
                        best_score = max(r.get('quality_score', 0) for r in st.session_state.scan_results)
                        st.metric("Meilleur Score", f"{best_score:.2f}")
                    else:
                        st.metric("Meilleur Score", "0.00")

                # Filtres pour les résultats
                st.subheader("🔧 Filtres")
                col1, col2 = st.columns(2)

                with col1:
                    min_score = st.slider("Score Minimum", 0.0, 1.0, 0.5, 0.1)

                with col2:
                    min_signals = st.slider("Signaux Minimum", 0, 10, 1)

                # Filtrer les résultats
                filtered_results = [r for r in st.session_state.scan_results
                                  if r.get('quality_score', 0) >= min_score and r.get('signal_count', 0) >= min_signals]

                if filtered_results != st.session_state.scan_results:
                    st.subheader(f"🎯 {len(filtered_results)} Résultats Filtrés")
                    display_scan_results(filtered_results)

    # --- Onglet Configuration ---
    with tab5:
        st.header("⚙️ Outils et Configuration")
        st.subheader("📋 Ordres Manuels MT5")
        if not st.session_state.mt5_connected:
            st.warning("Connectez-vous à MT5 pour passer des ordres.")
        else:
            try:
                from backend.mt5_connector import send_order_to_mt5
                import MetaTrader5 as mt5
                terminal_info = mt5.terminal_info()
                if not terminal_info.trade_allowed:
                    st.error("🚨 AutoTrading est désactivé dans votre terminal MT5. Veuillez l'activer.")
                with st.form("manual_order_form"):
                    col1, col2, col3 = st.columns(3)
                    with col1:
                        order_symbol = st.text_input("Symbole", value=symbol)
                        order_type = st.selectbox("Type", ["BUY", "SELL"])
                    with col2:
                        order_volume = st.number_input("Volume (lots)", min_value=0.01, value=0.1, step=0.01)
                        order_price = st.number_input("Prix d'entrée (0 = marché)", value=0.0, format="%.5f")
                    with col3:
                        order_sl = st.number_input("Stop Loss (0 = aucun)", value=0.0, format="%.5f")
                        order_tp = st.number_input("Take Profit (0 = aucun)", value=0.0, format="%.5f")
                    submitted = st.form_submit_button("🚀 Envoyer l'Ordre", use_container_width=True)
                    if submitted:
                        with st.spinner("Envoi de l'ordre..."):
                            result = send_order_to_mt5(
                                symbol=order_symbol,
                                order_type=order_type,
                                volume=order_volume,
                                price=order_price if order_price > 0 else None,
                                sl=order_sl if order_sl > 0 else None,
                                tp=order_tp if order_tp > 0 else None
                            )
                            if result and result.get('retcode') == mt5.TRADE_RETCODE_DONE:
                                st.success(f"✅ Ordre #{result['order']} exécuté avec succès!")
                            else:
                                st.error(f"❌ Échec de l'ordre: {result.get('comment', 'Erreur inconnue')}")
            except Exception as e:
                st.error(f"Erreur lors de l'initialisation du formulaire d'ordre : {e}")

        st.markdown("---")
        st.subheader("🤖 Entraînement des Modèles ML")
        if st.button("🤖 Lancer l'entraînement maintenant"):
            if len(st.session_state.real_time_data) >= 100:
                with st.spinner("Entraînement des modèles ML en cours..."):
                    try:
                        st.session_state.ml_predictor.train_models(st.session_state.real_time_data)
                        st.success("✅ Modèles ML entraînés avec succès!")
                        st.rerun()
                    except Exception as e:
                        st.error(f"❌ Erreur lors de l'entraînement: {e}")
            else:
                st.warning(f"Données insuffisantes. {len(st.session_state.real_time_data)}/100 bougies disponibles.")

# Pied de page
st.markdown("---")
st.info(
    "**⚠️ Avertissement:** Le trading comporte des risques. Cette application est un outil d'analyse et ne constitue pas un conseil en investissement."
)

