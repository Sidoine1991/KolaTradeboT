import sys
import os
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
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

load_dotenv()

# -----------------------------
# Minimal signal API (Option A)
# -----------------------------
SIGNAL_DATA = {"signals": []}

def _ensure_signal_api():
    """VÃ©rifie si l'API est disponible, sinon utilise le fichier JSON."""
    # VÃ©rifier si l'API est dÃ©jÃ  dÃ©marrÃ©e
    if st.session_state.get("signal_api_started"):
        return True
    
    # Essayer de se connecter Ã  l'API
    try:
        import requests
        response = requests.get("http://localhost:8001/health", timeout=2)
        if response.status_code == 200:
            st.session_state.signal_api_started = True
            st.sidebar.success("âœ… API Signaux connectÃ©e sur http://localhost:8001")
            return True
    except:
        pass
    
    # Fallback: utiliser le fichier JSON
    st.session_state.signal_api_started = False
    st.sidebar.info("ðŸ“ Utilisation du fichier signals.json (API non dÃ©marrÃ©e)")
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
            
            # Calculer les pips
            pip_size = 0.0001 if "JPY" not in symbol else 0.01
            if "Index" in symbol or "Boom" in symbol or "Crash" in symbol:
                pip_size = 0.1  # Pour les indices
            
            sl_pips = abs(price - sl) / pip_size
            tp_pips = abs(tp - price) / pip_size
            
            # VÃ©rifier les critÃ¨res de risque
            risk_ok = sl_pips <= 10  # SL max 10 pips
            reward_ok = tp_pips >= 30  # TP min 30 pips
            
            if risk_ok and reward_ok:
                # Formater le message WhatsApp
                emoji = "ðŸŸ¢" if side == "BUY" else "ðŸ”´"
                message = f"""{emoji} SIGNAL {source.upper()}
    except Exception as e:
        pass
ðŸ“Š {symbol}
ðŸŽ¯ {side} @ {price:.3f}
ðŸ›¡ï¸ SL: {sl:.3f} ({sl_pips:.1f} pips)
ðŸŽ¯ TP: {tp:.3f} ({tp_pips:.1f} pips)
âš¡ Confiance: {confidence*100:.0f}%
â° Valide jusqu'Ã : {valid_to}"""
                
                send_whatsapp_message_unified(message)
                print(f"ðŸ“± Signal WhatsApp envoyÃ©: {symbol} {side}")
            else:
                print(f"âš ï¸ Signal rejetÃ© - CritÃ¨res non respectÃ©s: SL={sl_pips:.1f}pips, TP={tp_pips:.1f}pips")
                
        except Exception as e:
            print(f"âŒ Erreur envoi WhatsApp: {e}")
        
        # Fallback dump for consumers without API
        try:
            with open("signals.json", "w", encoding="utf-8") as f:
                json.dump(SIGNAL_DATA, f, ensure_ascii=False, indent=2)
        except Exception:
            pass
    except Exception:
        pass

# Helper HTTP avec retries pour API modernes
def fetch_json_with_retries(url: str, params: dict, attempts: int = 3, timeout: int = 8):
    import requests as _rq
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

# Configuration de la page
st.set_page_config(
    page_title="TradBOT Temps RÃ©el", 
    page_icon="âš¡", 
    layout="wide", 
    initial_sidebar_state="expanded"
)

# CSS pour largeur augmentÃ©e du graphique
st.markdown("""
<style>
    .main .block-container {
        padding-top: 2rem;
        padding-bottom: 2rem;
        padding-left: 1rem;
        padding-right: 1rem;
        max-width: 100%;
    }
    
        .stPlotlyChart {
            width: 100% !important;
            max-width: 100% !important;
            min-width: 100% !important;
            margin: 0.5rem 0 !important;
            border-radius: 8px !important;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1) !important;
            overflow: visible !important;
            transform: scale(0.79) !important;  /* RÃ©duire le zoom Ã  79% */
        }
    
    .plotly-graph-div {
        width: 100% !important;
        max-width: 100% !important;
        min-width: 100% !important;
        height: auto !important;
        min-height: 600px !important;  /* Hauteur minimale augmentÃ©e */
        overflow: visible !important;
        transform: scale(0.79) !important;  /* RÃ©duire le zoom Ã  79% */
    }
    
    /* Forcer la largeur du conteneur principal */
    .main .block-container {
        max-width: 100% !important;
        padding-left: 0.5rem !important;
        padding-right: 0.5rem !important;
    }
    
    /* Assurer que le graphique utilise toute la largeur */
    .element-container {
        width: 100% !important;
    }
    
    /* Assurer que le conteneur principal utilise toute la largeur */
    .main {
        max-width: 100% !important;
    }
</style>
""", unsafe_allow_html=True)

# Ajout du rÃ©pertoire racine au PYTHONPATH
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

# Imports du backend rÃ©el
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
    # from backend.spike_predictor import AdvancedSpikePredictor  # SupprimÃ©
    MT5_AVAILABLE = True
except ImportError as e:
    st.error(f"âŒ Erreur d'import des modules backend: {e}")
    st.error("Assurez-vous que MetaTrader 5 est installÃ© et configurÃ©")
    MT5_AVAILABLE = False

# Initialisation des variables de session
if 'mt5_connected' not in st.session_state:
    st.session_state.mt5_connected = False
if 'current_symbol' not in st.session_state:
    st.session_state.current_symbol = None
if 'current_timeframe' not in st.session_state:
    st.session_state.current_timeframe = '1m'
if 'real_time_data' not in st.session_state:
    st.session_state.real_time_data = pd.DataFrame()
if 'last_update' not in st.session_state:
    st.session_state.last_update = None
if 'price_alerts' not in st.session_state:
    st.session_state.price_alerts = []
# spike_predictions supprimÃ© - alertes spike dÃ©sactivÃ©es
if 'ml_predictor' not in st.session_state:
    st.session_state.ml_predictor = AdvancedMLPredictor()
if 'setup_detector' not in st.session_state:
    st.session_state.setup_detector = SetupDetector()
# spike_predictor supprimÃ© - alertes spike dÃ©sactivÃ©es
if 'trading_signals' not in st.session_state:
    st.session_state.trading_signals = {}
if 'risk_manager' not in st.session_state:
    st.session_state.risk_manager = RiskManager(account_balance=1000.0)

# Essayer de charger les modÃ¨les ML prÃ©-entraÃ®nÃ©s
if not st.session_state.ml_predictor.is_trained:
    try:
        if st.session_state.ml_predictor.load_models():
            st.session_state.ml_predictor.is_trained = True
    except:
        pass  # Pas de modÃ¨les prÃ©-entraÃ®nÃ©s disponibles

# Configuration audio
AUDIO_FILE_PATH = os.path.join(os.path.dirname(__file__), 'static', 'beep.wav')
encoded_audio = None
if os.path.exists(AUDIO_FILE_PATH):
    with open(AUDIO_FILE_PATH, "rb") as f:
        encoded_audio = base64.b64encode(f.read()).decode()

def play_alert_sound():
    """Joue un son d'alerte"""
    if encoded_audio:
        st.markdown(f"""
            <audio autoplay>
                <source src="data:audio/wav;base64,{encoded_audio}" type="audio/wav">
            </audio>
        """, unsafe_allow_html=True)

def get_real_time_price(symbol):
    """RÃ©cupÃ¨re le prix actuel en temps rÃ©el depuis MT5"""
    if not MT5_AVAILABLE or not st.session_state.mt5_connected:
        return None
    
    try:
        price_info = get_current_price(symbol)
        if price_info and isinstance(price_info, dict):
            # Utiliser le prix 'last' ou la moyenne bid/ask
            if 'last' in price_info and price_info['last'] > 0:
                return price_info['last']
            elif 'bid' in price_info and 'ask' in price_info and price_info['bid'] > 0 and price_info['ask'] > 0:
                return (price_info['bid'] + price_info['ask']) / 2
        elif isinstance(price_info, (int, float)) and price_info > 0:
            return price_info
    except Exception as e:
        st.error(f"Erreur lors de la rÃ©cupÃ©ration du prix pour {symbol}: {e}")
    return None

def get_real_time_ohlc(symbol, timeframe='1m', count=100):
    """RÃ©cupÃ¨re les donnÃ©es OHLC en temps rÃ©el depuis MT5 (sans cache)"""
    if not MT5_AVAILABLE or not st.session_state.mt5_connected:
        return pd.DataFrame()
    
    try:
        # RÃ©cupÃ©rer directement depuis MT5 sans cache
        df = get_ohlc(symbol, timeframe, count)
        if df is not None and not df.empty:
            # S'assurer qu'il y a une colonne timestamp
            if 'timestamp' not in df.columns and 'time' in df.columns:
                df['timestamp'] = df['time']
            elif 'timestamp' not in df.columns:
                df['timestamp'] = df.index
            
            # Ajouter seulement les indicateurs de base (pas de ML pour Ã©viter les calculs lourds)
            df = add_technical_indicators(df, ['RSI', 'MACD', 'BB'])
            
            print(f"ðŸ“Š DonnÃ©es OHLC rÃ©cupÃ©rÃ©es: {len(df)} bougies pour {symbol}")
            print(f"ðŸ“… DerniÃ¨re bougie: {df['timestamp'].iloc[-1]} - Prix: {df['close'].iloc[-1]:.5f}")
            
            return df
    except Exception as e:
        st.error(f"Erreur lors de la rÃ©cupÃ©ration des donnÃ©es OHLC pour {symbol}: {e}")
    
    return pd.DataFrame()

def predict_spike_real_time(df):
    """PrÃ©diction de spike en temps rÃ©el basÃ©e sur les vrais prix"""
    if df.empty or len(df) < 20:
        return None
    
    try:
        # Utiliser le modÃ¨le ML pour prÃ©dire les spikes
        ml_proba = predict_spike_ml(df)
        if ml_proba is not None:
            return ml_proba
        
        # Fallback: dÃ©tection traditionnelle
        spikes = detect_spikes(df, threshold=0.5, method='percentage')
        if not spikes.empty:
            return 0.8  # ProbabilitÃ© Ã©levÃ©e si un spike est dÃ©tectÃ©
            
    except Exception as e:
        st.error(f"Erreur lors de la prÃ©diction de spike: {e}")
    
    return None


# =========================
# StratÃ©gie OTE (Fibonacci)
# =========================
def _detect_last_impulse(df: pd.DataFrame, pivot_window: int = 5):
    """DÃ©tecte la derniÃ¨re impulsion (direction, high, low) via pivots simples.
    Retourne (direction, swing_high, swing_low) oÃ¹ direction âˆˆ {"up","down"} ou (None, None, None) si indisponible.
    """
    if df is None or df.empty or not set(['high','low','close']).issubset(df.columns):
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
        # Impulsion haussiÃ¨re: de low -> high
        return "up", swing_high, swing_low
    elif last_low_idx > last_high_idx and swing_high > swing_low:
        # Impulsion baissiÃ¨re: de high -> low
        return "down", swing_high, swing_low
    else:
        # Fallback: comparer close rÃ©cent
        recent = tail['close'].tail(20)
        direction = "up" if recent.iloc[-1] >= recent.iloc[0] else "down"
        return direction, max(tail['high'][-50:]), min(tail['low'][-50:])


def _compute_fib_levels(swing_high: float, swing_low: float) -> dict:
    """Calcule niveaux Fibo clÃ©s: 0, 0.5, 0.78, 0.88, 1 selon l'impulsion low->high.
    Retourne dict avec les prix des niveaux selon orientation low->high.
    """
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
    """Applique la rÃ¨gle:
    - Si impulsion up (low->high):
      - Achat autorisÃ© zone [0, 0.5]
      - Entre 0.5 et 1, Ã©viter achats; zone [0.78, 1] privilÃ©giÃ©e pour ventes (OTE sell)
    - Si impulsion down (high->low): miroir
    Retourne dict: {'bias': 'buy'|'sell', 'zone': 'buy_ok'|'risky'|'ote_sell'|'ote_buy', 'message': str}
    """
    try:
        if not fib_levels or current_price is None or current_price <= 0:
            return {'bias': None, 'zone': None, 'message': 'DonnÃ©es insuffisantes'}

        l0 = fib_levels.get('0')
        l05 = fib_levels.get('0.5')
        l078 = fib_levels.get('0.78')
        l1 = fib_levels.get('1')
        if None in (l0, l05, l078, l1):
            return {'bias': None, 'zone': None, 'message': 'Niveaux Fibo incomplets'}

        # Normaliser position entre 0 et 1 par rapport Ã  low->high
        rng = (l1 - l0) if (l1 - l0) != 0 else 1e-9
        pos = (current_price - l0) / rng

        if direction == 'up':
            if 0 <= pos <= 0.5:
                return {'bias': 'buy', 'zone': 'buy_ok', 'message': 'Zone dâ€™achat (0 Ã  0.5)'}
            elif 0.5 < pos < 0.78:
                return {'bias': 'sell', 'zone': 'risky', 'message': 'Zone risquÃ©e pour achats (0.5 Ã  0.78)'}
            elif 0.78 <= pos <= 1.0:
                return {'bias': 'sell', 'zone': 'ote_sell', 'message': 'Zone OTE de vente (0.78 Ã  1)'}
            else:
                return {'bias': None, 'zone': None, 'message': 'Hors plage'}
        elif direction == 'down':
            # Miroir: inverser low/high pour mesurer depuis high->low
            # Recalcule pos miroir
            pos_down = (l1 - current_price) / rng  # 0 en haut (high), 1 en bas (low)
            if 0 <= pos_down <= 0.5:
                return {'bias': 'sell', 'zone': 'sell_ok', 'message': 'Zone de vente (0 Ã  0.5 depuis le haut)'}
            elif 0.5 < pos_down < 0.78:
                return {'bias': 'buy', 'zone': 'risky', 'message': 'Zone risquÃ©e pour ventes (0.5 Ã  0.78)'}
            elif 0.78 <= pos_down <= 1.0:
                return {'bias': 'buy', 'zone': 'ote_buy', 'message': 'Zone OTE dâ€™achat (0.78 Ã  1 depuis le haut)'}
            else:
                return {'bias': None, 'zone': None, 'message': 'Hors plage'}
        else:
            return {'bias': None, 'zone': None, 'message': 'Direction inconnue'}
    except Exception as e:
        return {'bias': None, 'zone': None, 'message': f'Erreur Ã©valuation OTE: {e}'}

def update_real_time_data():
    """Met Ã  jour les donnÃ©es en temps rÃ©el avec les derniÃ¨res donnÃ©es MT5"""
    if not st.session_state.current_symbol:
        return
    
    symbol = st.session_state.current_symbol
    timeframe = st.session_state.current_timeframe
    
    try:
        # RÃ©cupÃ©rer les donnÃ©es OHLC rÃ©elles depuis MT5 (sans cache)
        df = get_ohlc(symbol, timeframe, 300)
        if df is not None and not df.empty:
            # S'assurer qu'il y a une colonne timestamp
            if 'timestamp' not in df.columns and 'time' in df.columns:
                df['timestamp'] = df['time']
            elif 'timestamp' not in df.columns:
                df['timestamp'] = df.index
            
            # Ajouter les indicateurs techniques de base (sans ML pour Ã©viter les calculs lourds)
            df = add_technical_indicators(df, ['RSI', 'MACD', 'BB'])
            
            # Mettre Ã  jour les donnÃ©es en session
            st.session_state.real_time_data = df
            st.session_state.last_update = datetime.now()
            
            # Debug: afficher les derniÃ¨res donnÃ©es
            print(f"ðŸ”„ DonnÃ©es mises Ã  jour: {len(df)} bougies pour {symbol}")
            print(f"ðŸ“… DerniÃ¨re bougie: {df['timestamp'].iloc[-1]} - Prix: {df['close'].iloc[-1]:.5f}")
            
            return True
        else:
            st.warning(f"âš ï¸ Aucune donnÃ©e rÃ©cupÃ©rÃ©e pour {symbol}")
            return False
    except Exception as e:
        st.error(f"âŒ Erreur lors de la mise Ã  jour des donnÃ©es: {e}")
        return False

# CSS pour un meilleur affichage du graphique
st.markdown("""
<style>
    /* Configuration pour graphique large */
    .main .block-container {
        padding-top: 1rem;
        padding-bottom: 1rem;
        padding-left: 1rem;
        padding-right: 1rem;
        max-width: 100%;
    }
    
    /* Graphique optimisÃ© */
    .stPlotlyChart {
        width: 100% !important;
        height: 800px !important;
        margin: 0 auto !important;
        display: block !important;
    }
    
    /* Conteneur du graphique */
    .element-container {
        display: flex !important;
        justify-content: center !important;
        width: 100% !important;
    }
    
    /* Forcer la largeur du graphique */
    .stPlotlyChart > div {
        width: 100% !important;
        max-width: none !important;
    }
    
    /* RÃ©duire les marges */
    .stApp > div {
        padding-top: 0.5rem;
    }
</style>
""", unsafe_allow_html=True)

# Interface principale
st.title("âš¡ TradBOT - PrÃ©dictions Temps RÃ©el")

# Ã‰tat de la connexion
if st.session_state.mt5_connected:
    st.success("ðŸŸ¢ MT5 ConnectÃ©")
else:
    st.error("ðŸ”´ MT5 Non connectÃ© - Connectez-vous d'abord Ã  MT5")
# DÃ©marrer automatiquement l'API Signaux (si disponible)
try:
    _ensure_signal_api()
except Exception:
    pass
st.markdown("### PrÃ©dictions basÃ©es sur les **vrais prix** du marchÃ©")

# Sidebar pour la configuration
with st.sidebar:
    st.header("âš™ï¸ Configuration MT5")
    
    # Test de connexion MT5
    if st.button("ðŸ”— Tester Connexion MT5"):
        with st.spinner("Test de connexion..."):
            if MT5_AVAILABLE and test_connection():
                st.session_state.mt5_connected = True
                st.success("âœ… Connexion MT5 rÃ©ussie!")
            else:
                st.error("âŒ Ã‰chec de la connexion MT5")
                st.info("VÃ©rifiez vos identifiants dans le fichier .env")
    
    # Connexion manuelle
    if st.button("ðŸ”Œ Connecter MT5"):
        with st.spinner("Connexion en cours..."):
            if MT5_AVAILABLE:
                try:
                    connect()
                    st.session_state.mt5_connected = True
                    st.success("âœ… ConnectÃ© Ã  MT5!")
                except Exception as e:
                    st.error(f"âŒ Erreur de connexion: {e}")
    
    # Statut de connexion
    if st.session_state.mt5_connected:
        st.success("ðŸŸ¢ MT5 ConnectÃ©")
    else:
        st.error("ðŸ”´ MT5 Non connectÃ©")
    
    st.markdown("---")
    st.header("ðŸ“Š Analyse Technique")
    
    # ContrÃ´les pour les trendlines et Fibonacci
    show_trendlines = st.checkbox("ðŸ“ˆ Trendlines", value=True, help="Afficher les lignes de support et rÃ©sistance")
    show_fibonacci = st.checkbox("ðŸŒ€ Fibonacci", value=True, help="Afficher les retracements de Fibonacci")
    show_current_price = st.checkbox("ðŸ’° Prix actuel", value=True, help="Afficher la ligne du prix actuel")
    show_sr_zones = st.checkbox("ðŸ§± Zones S/R rÃ©elles", value=True, help="Dessiner les vrais supports/rÃ©sistances dÃ©tectÃ©s sur les prix MT5")
    
    # Stocker dans session_state pour utilisation dans le graphique
    st.session_state.show_trendlines = show_trendlines
    st.session_state.show_fibonacci = show_fibonacci
    st.session_state.show_current_price = show_current_price
    st.session_state.show_sr_zones = show_sr_zones
    
    # Configuration du rafraÃ®chissement
    st.header("ðŸ”„ RafraÃ®chissement")
    auto_refresh = st.checkbox("RafraÃ®chissement automatique", value=True)
    refresh_interval = st.slider("Intervalle (secondes)", 5, 30, 10)
    
    if auto_refresh:
        st_autorefresh(interval=refresh_interval * 1000, key="realtime_refresh")

    # API Signaux (Option A)
    st.header("ðŸ›°ï¸ API Signaux (MT5)")
    col1, col2, col3 = st.columns(3)
    with col1:
        if st.button("VÃ©rifier API", key="btn_check_signal_api"):
            _ensure_signal_api()
    with col2:
        if st.button("Tester API", key="btn_test_api"):
            try:
                import requests
                test_urls = ["http://localhost:8001/", "http://localhost:8001/health", "http://localhost:8001/signals", "http://localhost:8001/test"]
                for url in test_urls:
                    try:
                        response = requests.get(url, timeout=3)
                        st.write(f"âœ… {url}: {response.status_code} - {response.json()}")
                    except Exception as e:
                        st.write(f"âŒ {url}: {e}")
            except Exception as e:
                st.error(f"Erreur test API: {e}")
    with col3:
        if st.button("ðŸš€ DÃ©marrer API", key="btn_start_api"):
            st.info("ðŸ’¡ Pour dÃ©marrer l'API, exÃ©cutez dans un terminal :")
            st.code("python start_signal_api.py", language="bash")
            st.info("ðŸ“ Les signaux sont sauvegardÃ©s dans signals.json")
    
    if st.session_state.get("signal_api_started"):
        st.success("API active: http://localhost:8001/signals")
    else:
        st.info("API non active. Utilisez le bouton ci-dessus. Fallback: signals.json mis Ã  jour")
    
    # SÃ©lection du symbole
    st.header("ðŸ“ˆ SÃ©lection du symbole")
    
    if st.session_state.mt5_connected and MT5_AVAILABLE:
        try:
            # RÃ©cupÃ©rer TOUS les symboles exacts depuis MT5
            with st.spinner("ðŸ”„ Chargement de tous les symboles MT5..."):
                all_symbols = get_all_symbols()
            
            if all_symbols:
                st.success(f"âœ… {len(all_symbols)} symboles chargÃ©s depuis MT5")
                
                # Zone de recherche et de filtrage
                st.caption("ðŸ” Recherche dans tous les symboles MT5 (Market Watch)")
                search = st.text_input("Rechercher un symbole", value=st.session_state.current_symbol or "", key="main_symbol_search").upper()
                
                # Filtrer par recherche
                filtered = [s for s in all_symbols if search in s.upper()] if search else all_symbols
                
                # Option de catÃ©gories (SynthÃ©tiques / Forex / Indices ...)
                with st.expander("ðŸŽ¯ Filtrer par catÃ©gories", expanded=False):
                    from backend.mt5_connector import get_symbols_by_category
                    colA, colB, colC, colD = st.columns(4)
                    with colA:
                        show_syn = st.checkbox("SynthÃ©tiques", value=True, key="cat_syn")
                    with colB:
                        show_fx = st.checkbox("Forex", value=True, key="cat_fx")
                    with colC:
                        show_crypto = st.checkbox("Crypto", value=True, key="cat_crypto")
                    with colD:
                        show_others = st.checkbox("Autres", value=True, key="cat_others")
                    
                    # Appliquer les filtres de catÃ©gories
                    if not (show_syn and show_fx and show_crypto and show_others):
                        category_symbols = []
                        if show_syn:
                            category_symbols.extend(get_symbols_by_category('SYNTHETIC'))
                        if show_fx:
                            category_symbols.extend(get_symbols_by_category('FOREX'))
                        if show_crypto:
                            category_symbols.extend(get_symbols_by_category('CRYPTO'))
                        if show_others:
                            category_symbols.extend(get_symbols_by_category('COMMODITIES'))
                            category_symbols.extend(get_symbols_by_category('INDICES'))
                        
                        if category_symbols:
                            filtered = [s for s in filtered if s in category_symbols]
                
                # Affichage des rÃ©sultats
                if filtered:
                    # SÃ©lecteur complet avec pagination
                    page_size = 100  # Plus de symboles par page
                    total = len(filtered)
                    total_pages = max(1, (total - 1) // page_size + 1)
                    
                    col1, col2, col3 = st.columns([1, 2, 1])
                    with col1:
                        page = st.number_input("Page", min_value=1, max_value=total_pages, value=1, step=1)
                    with col2:
                        st.caption(f"ðŸ“„ Page {page}/{total_pages} - Affichage {min(page_size, total)} symboles")
                    with col3:
                        st.caption(f"ðŸ“Š Total: {total} symboles")
                    
                    start = (page - 1) * page_size
                    end = start + page_size
                    page_symbols = filtered[start:end]
                    
                    # SÃ©lecteur de symbole
                    selected_symbol = st.selectbox(
                        "Choisir un symbole MT5", 
                        page_symbols,
                        index=page_symbols.index(st.session_state.current_symbol) if st.session_state.current_symbol in page_symbols else 0,
                        help="SÃ©lectionnez le symbole exact depuis votre Market Watch MT5"
                    )
                else:
                    st.warning("Aucun symbole trouvÃ© avec ces critÃ¨res de recherche")
                    selected_symbol = None
                
                if selected_symbol != st.session_state.current_symbol:
                    st.session_state.current_symbol = selected_symbol
                    st.session_state.real_time_data = pd.DataFrame()
                    
            else:
                st.warning("Aucun symbole disponible")
                selected_symbol = st.text_input("Entrez un symbole manuellement", "EURUSD", key="real_time_symbol_manual_1")
                st.session_state.current_symbol = selected_symbol
                
        except Exception as e:
            st.error(f"Erreur lors du chargement des symboles: {e}")
            selected_symbol = st.text_input("Entrez un symbole manuellement", "EURUSD", key="real_time_symbol_manual_2")
            st.session_state.current_symbol = selected_symbol
    else:
        selected_symbol = st.text_input("Entrez un symbole", "EURUSD", key="real_time_symbol_manual_3")
        st.session_state.current_symbol = selected_symbol
    
    # SÃ©lection du timeframe
    timeframe_options = ["1m", "5m", "15m", "30m", "1h", "4h", "6h", "8h", "1d"]
    selected_timeframe = st.selectbox(
        "Timeframe",
        timeframe_options,
        index=timeframe_options.index(st.session_state.current_timeframe) if st.session_state.current_timeframe in timeframe_options else 0
    )
    st.session_state.current_timeframe = selected_timeframe

    # Watchlist AutoMonitor
    st.header("ðŸ§­ AutoMonitor Watchlist")
    if 'watchlist' not in st.session_state:
        st.session_state.watchlist = []
    if 'automonitor_last' not in st.session_state:
        st.session_state.automonitor_last = None

    # Source des symboles pour multiselect
    available_for_watchlist = []
    try:
        available_for_watchlist = get_all_symbols() if (st.session_state.mt5_connected and MT5_AVAILABLE) else []
    except Exception:
        available_for_watchlist = []

    # Organiser les symboles par catÃ©gorie pour faciliter la sÃ©lection
    if available_for_watchlist:
        # Grouper les symboles par catÃ©gorie
        forex_symbols = [s for s in available_for_watchlist if any(curr in s for curr in ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD']) and len(s) == 6]
        synthetic_symbols = [s for s in available_for_watchlist if any(keyword in s.upper() for keyword in ['BOOM', 'CRASH', 'STEP', 'JUMP', 'RANGE', 'VOLATILITY', 'DRIFT', 'DEX', 'MULTI', 'DAILY', 'HYBRID', 'SKEWED', 'SYNTHETIC', 'INDEX', 'INDICES'])]
        crypto_symbols = [s for s in available_for_watchlist if any(curr in s for curr in ['BTC', 'ETH', 'LTC', 'XRP', 'ADA', 'DOT', 'BCH', 'BAT', 'APE', 'ALG', 'XTZ'])]
        indices_symbols = [s for s in available_for_watchlist if any(keyword in s.upper() for keyword in ['SPX', 'NAS', 'DOW', 'FTSE', 'DAX', 'NIKKEI', 'WALL_STREET', 'US_500', 'US_TECH'])]
        other_symbols = [s for s in available_for_watchlist if s not in forex_symbols + synthetic_symbols + crypto_symbols + indices_symbols]
        
        # CrÃ©er des options groupÃ©es
        options_with_categories = []
        if forex_symbols:
            options_with_categories.extend([f"ðŸ’± {s}" for s in forex_symbols[:20]])  # Limiter Ã  20 par catÃ©gorie
        if synthetic_symbols:
            options_with_categories.extend([f"ðŸŽ¯ {s}" for s in synthetic_symbols[:20]])
        if crypto_symbols:
            options_with_categories.extend([f"ðŸª™ {s}" for s in crypto_symbols[:20]])
        if indices_symbols:
            options_with_categories.extend([f"ðŸ“ˆ {s}" for s in indices_symbols[:20]])
        if other_symbols:
            options_with_categories.extend([f"ðŸ“Š {s}" for s in other_symbols[:20]])
        
        # Ajouter une option de recherche
        search_term = st.text_input("ðŸ” Rechercher un symbole", placeholder="Tapez pour filtrer...", key="watchlist_symbol_search")
        if search_term:
            filtered_options = [opt for opt in options_with_categories if search_term.upper() in opt.upper()]
        else:
            filtered_options = options_with_categories
        
        # PrÃ©parer les valeurs par dÃ©faut avec icÃ´nes
        default_with_icons = []
        for symbol in st.session_state.watchlist:
            # Chercher le symbole dans les options filtrÃ©es
            for option in filtered_options:
                if option.endswith(f" {symbol}"):
                    default_with_icons.append(option)
                    break
        
        # SÃ©lection multiple avec options groupÃ©es
        selected_with_icons = st.multiselect(
            "SÃ©lectionnez des symboles Ã  surveiller (plusieurs choix possibles)",
            options=filtered_options,
            default=default_with_icons,
            help="ðŸ’¡ Vous pouvez sÃ©lectionner plusieurs symboles Ã  la fois. Utilisez la recherche pour filtrer rapidement.",
            key="watchlist_multiselect"
        )
        
        # Nettoyer les sÃ©lections (enlever les icÃ´nes)
        st.session_state.watchlist = [opt.split(' ', 1)[1] for opt in selected_with_icons]
        
        # Boutons de sÃ©lection rapide
        st.subheader("âš¡ SÃ©lection rapide")
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            if st.button("ðŸ’± Forex Majors", help="SÃ©lectionner 5 paires de devises au hasard", key="btn_forex_majors"):
                import random
                available_forex = [s for s in forex_symbols if s in available_for_watchlist]
                if available_forex:
                    # SÃ©lectionner 5 symboles au hasard
                    selected_forex = random.sample(available_forex, min(5, len(available_forex)))
                    st.session_state.watchlist = list(set(st.session_state.watchlist + selected_forex))
                    st.rerun()
        
        with col2:
            if st.button("ðŸŽ¯ SynthÃ©tiques", help="SÃ©lectionner 5 indices synthÃ©tiques au hasard", key="btn_synthetics"):
                import random
                available_synthetics = [s for s in synthetic_symbols if s in available_for_watchlist]
                if available_synthetics:
                    # SÃ©lectionner 5 symboles au hasard
                    selected_synthetics = random.sample(available_synthetics, min(5, len(available_synthetics)))
                    st.session_state.watchlist = list(set(st.session_state.watchlist + selected_synthetics))
                    st.rerun()
        
        with col3:
            if st.button("ðŸª™ Crypto Top", help="SÃ©lectionner 3 cryptomonnaies au hasard", key="btn_crypto_top"):
                import random
                available_crypto = [s for s in crypto_symbols if s in available_for_watchlist]
                if available_crypto:
                    # SÃ©lectionner 3 symboles au hasard
                    selected_crypto = random.sample(available_crypto, min(3, len(available_crypto)))
                    st.session_state.watchlist = list(set(st.session_state.watchlist + selected_crypto))
                    st.rerun()
        
        with col4:
            if st.button("ðŸ§¹ Tout effacer", help="DÃ©sÃ©lectionner tous les symboles", key="btn_clear_all"):
                st.session_state.watchlist = []
                st.rerun()
        
        # Afficher le nombre de symboles sÃ©lectionnÃ©s
        if st.session_state.watchlist:
            st.success(f"âœ… {len(st.session_state.watchlist)} symbole(s) sÃ©lectionnÃ©(s): {', '.join(st.session_state.watchlist[:5])}{'...' if len(st.session_state.watchlist) > 5 else ''}")
        else:
            st.info("â„¹ï¸ Aucun symbole sÃ©lectionnÃ©. Choisissez des symboles Ã  surveiller ci-dessus.")
    else:
        st.warning("âš ï¸ Aucun symbole disponible. VÃ©rifiez la connexion MT5.")
        st.session_state.watchlist = []

    colW1, colW2, colW3 = st.columns([1,1,1])
    with colW1:
        automonitor_auto = st.checkbox("Auto-scan", value=False, key="automonitor_auto")
        # Reprogrammer sans toucher Ã  l'Ã©tat du widget
        if st.button("âŸ³ Reprogrammer", key="automonitor_reprogram"):
            st.session_state.automonitor_next_ts = datetime.now()
    with colW2:
        automonitor_interval = st.number_input("Intervalle (s)", min_value=10, max_value=300, value=60, step=10, key="automonitor_interval")
    with colW3:
        probability_threshold = st.slider("Seuil probabilitÃ© (%)", min_value=30, max_value=90, value=60, step=5, key="probability_threshold", help="ProbabilitÃ© minimum pour gÃ©nÃ©rer un signal")

    # Modes de stratÃ©gie: Scalping M5 / Swing M10 (approx M15)
    st.subheader("ðŸŽ›ï¸ Mode de stratÃ©gie")
    mode_options = ["Scalping (M5)", "Swing court (M10â‰ˆM15)"]
    selected_mode = st.selectbox("SÃ©lectionnez un mode", options=mode_options, index=0, key="strategy_mode")
    # Capital et risque
    st.caption("Capital de dÃ©part")
    capital_usd = st.number_input("Capital ($)", min_value=1.0, max_value=1000.0, value=5.0, step=1.0, key="capital_usd")
    risk_pct = st.slider("Risque par trade (%)", min_value=0.5, max_value=2.0, value=1.0, step=0.5, key="risk_pct")

    # Appliquer prÃ©sÃ©lections selon le mode
    if selected_mode == "Scalping (M5)":
        st.session_state['rr_min'] = 2.0
        st.session_state['cooldown_sec'] = 600  # 10 minutes
        # seuil effectif sans modifier le widget existant
        _ui_thr = st.session_state.get('probability_threshold', 60)
        st.session_state['probability_threshold_effective'] = int(max(_ui_thr, 92))
    else:
        st.session_state['rr_min'] = 2.5
        st.session_state['cooldown_sec'] = 1200  # 20 minutes
        _ui_thr = st.session_state.get('probability_threshold', 60)
        st.session_state['probability_threshold_effective'] = int(max(_ui_thr, 90))

    col_scan1, col_scan2 = st.columns(2)
    with col_scan1:
        do_manual_scan = st.button("ðŸ”Ž Scanner maintenant", key="automonitor_scan_btn")
        if do_manual_scan:
            st.session_state["automonitor_manual_once"] = True
    
    with col_scan2:
        test_signal_logic = st.button("ðŸ§ª Tester logique signaux", key="test_signal_btn")
        if test_signal_logic:
            st.session_state["test_signal_logic"] = True

    # Initialiser le prochain scan si absent (indÃ©pendant du rafraÃ®chissement global)
    if "automonitor_next_ts" not in st.session_state:
        st.session_state.automonitor_next_ts = None
    if "automonitor_status" not in st.session_state:
        st.session_state.automonitor_status = "Idle"

    # Afficher le statut du monitor
    now = datetime.now()
    next_ts = st.session_state.automonitor_next_ts
    # Affichage statut style "chip"
    if st.session_state.get("automonitor_auto") and isinstance(next_ts, datetime):
        secs_left = max(0, int((next_ts - now).total_seconds()))
        status_chip = "ðŸŸ¢ ON" if st.session_state.get("automonitor_auto") else "âšª OFF"
        st.caption(f"ðŸ§­ AutoMonitor: {status_chip} Â· {st.session_state.automonitor_status} Â· â± {secs_left}s")
    else:
        status_chip = "ðŸŸ¢ ON" if st.session_state.get("automonitor_auto") else "âšª OFF"
        st.caption(f"ðŸ§­ AutoMonitor: {status_chip} Â· {st.session_state.automonitor_status}")

    # Notifications
    st.header("ðŸ“£ Notifications")
    notify_whatsapp = st.checkbox("WhatsApp", value=True, key="notify_whatsapp")
    notify_sms = st.checkbox("SMS", value=True, key="notify_sms")
    notif_interval = st.number_input("Intervalle min entre alertes (s)", min_value=30, max_value=3600, value=180, step=30, key="notify_interval")
    if 'last_notifications' not in st.session_state:
        st.session_state.last_notifications = {}
    # spike_predictions supprimÃ© - alertes spike dÃ©sactivÃ©es
    
    # RÃ©sumÃ© des notifications configurÃ©es
    st.markdown("#### ðŸ“‹ Types de notifications")
    st.markdown("""
    - **ðŸ§­ Signaux AutoMonitor** : Confluence > 70% (cooldown 3min)
    - **ðŸ“± Envoi** : SMS + WhatsApp automatique
    - **ðŸ“Š Format** : Devise, Heure, Type d'ordre, Lots, Prix d'entrÃ©e, TP/SL
    """)
    
    # Bouton de test des notifications
    if st.button("ðŸ§ª Tester Notifications", type="secondary"):
        try:
            from frontend.whatsapp_notify import send_whatsapp_message_unified, send_sms_vonage
            test_message = f"[TradBOT Test] Signal BUY EURUSD (M5) Â· Confluence 85% Â· {datetime.now().strftime('%H:%M:%S')}"
            
            if notify_whatsapp:
                st.info("ðŸ”„ Envoi WhatsApp en cours...")


                try:
                    result_wa = send_whatsapp_message_unified(test_message)
                    st.write("ðŸ“‹ RÃ©ponse WhatsApp:", result_wa)
                    # ConsidÃ©rer succÃ¨s si dict sans status=error, ou True
                    if result_wa is True:
                        st.success("âœ… Test WhatsApp envoyÃ© !")
                    elif isinstance(result_wa, dict) and result_wa.get('status') not in ['error', 'failed']:
                        st.success("âœ… Test WhatsApp envoyÃ© !")
                    else:
                        st.error(f"âŒ Erreur WhatsApp: {result_wa}")
                except Exception as e:
                    st.error(f"âŒ Erreur WhatsApp: {e}")
            else:
                st.warning("âš ï¸ WhatsApp dÃ©sactivÃ© - activez d'abord la case WhatsApp")
            
            if notify_sms:
                st.info("ðŸ”„ Envoi SMS en cours...")
                result_sms = send_sms_vonage(test_message)
                st.write("ðŸ“‹ RÃ©ponse SMS:", result_sms)
                
                if result_sms and result_sms.get('messages', [{}])[0].get('status') == '0':
                    st.success("âœ… Test SMS envoyÃ© !")
                else:
                    st.error(f"âŒ Erreur SMS: {result_sms}")
            else:
                st.warning("âš ï¸ SMS dÃ©sactivÃ© - activez d'abord la case SMS")
                
        except Exception as e:
            st.error(f"âŒ Erreur test notifications: {e}")
            import traceback
            st.code(traceback.format_exc())

# Zone principale
if st.session_state.current_symbol:
    symbol = st.session_state.current_symbol
    
    # Mise Ã  jour des donnÃ©es en temps rÃ©el
    update_real_time_data()
    
    # Affichage du prix actuel
    col1, col2, col3 = st.columns(3)
    
    with col1:
        current_price = get_real_time_price(symbol)
        if current_price and isinstance(current_price, (int, float)) and current_price > 0:
            # Ajuster le nombre de dÃ©cimales selon le type de symbole
            if 'JPY' in symbol or 'Index' in symbol:
                price_format = f"{current_price:.2f}"
            else:
                price_format = f"{current_price:.5f}"
            st.metric(
                label="ðŸ’° Prix Actuel",
                value=price_format,
                delta=None
            )
        else:
            st.metric("ðŸ’° Prix Actuel", "N/A")
    
    with col2:
        if not st.session_state.real_time_data.empty:
            price_change = st.session_state.real_time_data['close'].pct_change().iloc[-1] * 100
            st.metric(
                label="ðŸ“Š Variation",
                value=f"{price_change:.2f}%",
                delta=f"{price_change:.2f}%"
            )
        else:
            st.metric("ðŸ“Š Variation", "N/A")
    
    with col3:
        if st.session_state.last_update:
            time_diff = datetime.now() - st.session_state.last_update
            st.metric(
                label="ðŸ•’ DerniÃ¨re MAJ",
                value=f"{time_diff.seconds}s"
            )
        else:
            st.metric("ðŸ•’ DerniÃ¨re MAJ", "N/A")
    
    # ContrÃ´les de mise Ã  jour des donnÃ©es
    col1, col2, col3 = st.columns([2, 1, 1])
    
    with col1:
        st.subheader("ðŸ“Š DonnÃ©es Temps RÃ©el")
    
    with col2:
        if st.button("ðŸ”„ Actualiser", key="refresh_data_btn"):
            if st.session_state.mt5_connected and st.session_state.current_symbol:
                update_success = update_real_time_data()
                if update_success:
                    st.success("âœ… DonnÃ©es mises Ã  jour")
                    st.rerun()
                else:
                    st.error("âŒ Erreur de mise Ã  jour")
            else:
                st.warning("âš ï¸ Connectez-vous Ã  MT5 d'abord")
    
    with col3:
        if st.button("ðŸ” Debug", key="debug_data_btn"):
            if not st.session_state.real_time_data.empty:
                st.write("**Debug des donnÃ©es:**")
                st.write(f"- Nombre de bougies: {len(st.session_state.real_time_data)}")
                st.write(f"- DerniÃ¨re bougie: {st.session_state.real_time_data['timestamp'].iloc[-1]}")
                st.write(f"- Dernier prix: {st.session_state.real_time_data['close'].iloc[-1]:.5f}")
                st.write(f"- Colonnes: {list(st.session_state.real_time_data.columns)}")
    
    # Mise Ã  jour forcÃ©e des donnÃ©es en temps rÃ©el
    if st.session_state.mt5_connected and st.session_state.current_symbol:
        # Forcer la mise Ã  jour des donnÃ©es Ã  chaque refresh
        update_success = update_real_time_data()
        if not update_success:
            st.error("âŒ Impossible de rÃ©cupÃ©rer les donnÃ©es en temps rÃ©el")
            st.stop()
    
    # ==============================
    # HEADER - Informations principales
    # ==============================
    if not st.session_state.real_time_data.empty:
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.metric("ðŸ’± Symbole", symbol, delta=None)
        
        with col2:
            st.metric("â±ï¸ Timeframe", st.session_state.current_timeframe, delta=None)
        
        with col3:
            if st.session_state.last_update:
                st.metric("ðŸ”„ DerniÃ¨re MAJ", st.session_state.last_update.strftime('%H:%M:%S'), delta=None)
            else:
                st.metric("ðŸ”„ DerniÃ¨re MAJ", "N/A", delta=None)
        
        with col4:
            last_price = st.session_state.real_time_data['close'].iloc[-1] if not st.session_state.real_time_data.empty else 0
            st.metric("ðŸ’° Prix Actuel", f"{last_price:.5f}", delta=None)
        
        st.markdown("---")
    
    # ==============================
    # GRAPHIQUE PRINCIPAL
    # ==============================
    if not st.session_state.real_time_data.empty:
        # VÃ©rification et correction des donnÃ©es
        required_cols = ['open', 'high', 'low', 'close']
        missing_cols = [col for col in required_cols if col not in st.session_state.real_time_data.columns]
        if missing_cols:
            st.error(f"âŒ Colonnes OHLC manquantes: {missing_cols}")
            st.write("ðŸ” AperÃ§u des donnÃ©es:", st.session_state.real_time_data.head())
            st.write("ðŸ“Š Colonnes disponibles:", list(st.session_state.real_time_data.columns))
            st.stop()
        
        # S'assurer qu'il y a une colonne timestamp
        if 'timestamp' not in st.session_state.real_time_data.columns:
            if 'time' in st.session_state.real_time_data.columns:
                st.session_state.real_time_data['timestamp'] = st.session_state.real_time_data['time']
            else:
                st.session_state.real_time_data['timestamp'] = st.session_state.real_time_data.index
                st.info("â„¹ï¸ Utilisation de l'index comme timestamp")
        
        # CrÃ©er le graphique optimisÃ© avec timeframe dans le titre
        chart_title = f"{symbol} - {st.session_state.current_timeframe} - Temps RÃ©el"
        fig = create_candlestick_chart(st.session_state.real_time_data, chart_title)
        
        # Debug: vÃ©rifier si le graphique est crÃ©Ã©
        if fig is None:
            st.error("âŒ Erreur: Le graphique n'a pas pu Ãªtre crÃ©Ã©")
            st.write("ðŸ” VÃ©rifiez les donnÃ©es:", st.session_state.real_time_data.head())
            st.stop()
        
        # Optimiser le layout pour s'adapter Ã  la fenÃªtre avec zoom rÃ©duit Ã  79%
        fig.update_layout(
            height=800,  # Hauteur ajustÃ©e pour le zoom 79%
            margin=dict(l=80, r=20, t=60, b=50),  # Marges augmentÃ©es pour dÃ©caler vers la droite
            autosize=True,  # Activer l'auto-resize pour s'adapter Ã  la fenÃªtre
            title=dict(
                text=chart_title,
                font=dict(size=22, color='white'),
                x=0.5,
                pad=dict(t=25, b=15)
            ),
            template="plotly_dark",  # ThÃ¨me sombre pour un meilleur contraste
            xaxis_rangeslider_visible=False,  # Masquer le range slider pour plus d'espace
            showlegend=True,
            legend=dict(
                orientation="h",
                yanchor="bottom",
                y=1.02,
                xanchor="right",
                x=1,
                font=dict(size=10)
            ),
            # Configuration des axes pour Ã©viter la dÃ©formation
            xaxis=dict(
                type='date',
                showgrid=True,
                gridcolor='rgba(128,128,128,0.3)',
                showline=True,
                linecolor='rgba(128,128,128,0.5)',
                mirror=True,
                title=dict(text="Temps", font=dict(size=14, color='white')),
                tickfont=dict(size=10, color='white')
            ),
            yaxis=dict(
                showgrid=True,
                gridcolor='rgba(128,128,128,0.3)',
                showline=True,
                linecolor='rgba(128,128,128,0.5)',
                mirror=True,
                title=dict(text="Prix", font=dict(size=14, color='white')),
                tickfont=dict(size=10, color='white'),
                fixedrange=False  # Permettre le zoom
            )
        )
        
        # Ajouter les indicateurs techniques et canaux de trading (sans Bollinger Bands)
        fig = add_technical_indicators_to_chart(fig, st.session_state.real_time_data, ['sma', 'ema', 'channels'])

        # ==============================
        # Overlay StratÃ©gie OTE/Fibonacci
        # ==============================
        try:
            with st.expander("ðŸŽ¯ StratÃ©gie OTE (Fibonacci)", expanded=False):
                enable_ote = st.checkbox("Activer lâ€™overlay OTE", value=True, key="ote_enable")
                show_boxes = st.checkbox("Afficher zones (0-0.5, 0.78-1)", value=True, key="ote_boxes")
                pivot_w = st.slider("FenÃªtre pivots", 3, 11, 5, 1, key="ote_pivot_win")

                if enable_ote:
                    direction, swing_high, swing_low = _detect_last_impulse(st.session_state.real_time_data, pivot_window=pivot_w)
                    fibs = _compute_fib_levels(swing_high, swing_low)

                    # DÃ©terminer prix courant
                    px = get_real_time_price(symbol) or (st.session_state.real_time_data['close'].iloc[-1] if not st.session_state.real_time_data.empty else None)
                    ote_eval = evaluate_ote_strategy(px, direction, fibs)

                    # Dessiner zones OTE sur le chart
                    if fibs and show_boxes:
                        x_sr = st.session_state.real_time_data.index if 'time' not in st.session_state.real_time_data.columns else st.session_state.real_time_data['time']
                        x0b, x1b = x_sr.iloc[0], x_sr.iloc[-1]
                        # Zone 0-0.5 (achat pour impulsion up)
                        if all(k in fibs for k in ['0','0.5']):
                            y0, y1 = float(fibs['0']), float(fibs['0.5'])
                            if y1 >= y0:
                                fig.add_shape(type="rect", xref="x", yref="y",
                                              x0=x0b, x1=x1b,
                                              y0=y0, y1=y1,
                                              line=dict(color="rgba(46, 204, 113, 0.0)", width=0),
                                              fillcolor="rgba(46, 204, 113, 0.08)", layer="below")
                        # Zone 0.78-1 (vente pour impulsion up)
                        if all(k in fibs for k in ['0.78','1']):
                            y0, y1 = float(fibs['0.78']), float(fibs['1'])
                            if y1 >= y0:
                                fig.add_shape(type="rect", xref="x", yref="y",
                                              x0=x0b, x1=x1b,
                                              y0=y0, y1=y1,
                                              line=dict(color="rgba(231, 76, 60, 0.0)", width=0),
                                              fillcolor="rgba(231, 76, 60, 0.08)", layer="below")

                    # RÃ©sumÃ© dÃ©cisionnel
                    st.markdown("#### ðŸ§­ OTE - DÃ©cision")
                    st.write(f"Direction impulsion: {direction}")
                    if fibs:
                        st.write(f"Niveaux: 0={fibs.get('0'):.5f} Â· 0.5={fibs.get('0.5'):.5f} Â· 0.78={fibs.get('0.78'):.5f} Â· 1={fibs.get('1'):.5f}")
                    st.write(f"Prix courant: {px if isinstance(px, (int,float)) else 'N/A'}")
                    st.success(ote_eval['message']) if ote_eval.get('bias') in ('buy','sell') else st.info(ote_eval['message'])
        except Exception:
            pass

        # ==============================
        # Zones de Support/RÃ©sistance
        # ==============================
        with st.expander("ðŸŽ¯ Zones de Support/RÃ©sistance", expanded=False):
            show_sr = st.checkbox("Afficher les zones S/R", value=False, key="show_sr_zones")
            if show_sr and len(st.session_state.real_time_data) >= 50:
                try:
                    # Utiliser une fenÃªtre limitÃ©e pour Ã©viter des ranges x invalides
                    _df_sr = st.session_state.real_time_data.tail(300)
                    x_series_sr = _df_sr.index if 'time' not in _df_sr.columns else _df_sr['time']
                    x0_sr = x_series_sr.iloc[0]
                    x1_sr = x_series_sr.iloc[-1]
                    sr = st.session_state.setup_detector.detect_support_resistance_zones(_df_sr)
                    # Zones de support
                    for z in (sr.get('support_zones') or [])[:3]:
                        lower = float(z.get('lower', 0))
                        upper = float(z.get('upper', 0))
                        if lower > 0 and upper > 0 and upper >= lower:
                            fig.add_shape(type="rect", xref="x", yref="y",
                                          x0=x0_sr, x1=x1_sr,
                                          y0=float(lower), y1=float(upper),
                                          line=dict(color="rgba(52, 152, 219, 0.0)", width=0),
                                          fillcolor="rgba(52, 152, 219, 0.08)", layer="below")
                    # Zones de rÃ©sistance
                    for z in (sr.get('resistance_zones') or [])[:3]:
                        lower = float(z.get('lower', 0))
                        upper = float(z.get('upper', 0))
                        if lower > 0 and upper > 0 and upper >= lower:
                            fig.add_shape(type="rect", xref="x", yref="y",
                                          x0=x0_sr, x1=x1_sr,
                                          y0=float(lower), y1=float(upper),
                                          line=dict(color="rgba(231, 76, 60, 0.0)", width=0),
                                          fillcolor="rgba(231, 76, 60, 0.08)", layer="below")
                except Exception as e:
                    st.error(f"Erreur dans les zones S/R: {e}")

        # ==============================
        # Lignes de Tendance et Fibonacci
        # ==============================
        with st.expander("ðŸ“ˆ Lignes de Tendance et Fibonacci", expanded=False):
            show_trendlines = st.checkbox("Afficher les lignes de tendance", value=True, key="show_trendlines")
            show_fibonacci = st.checkbox("Afficher les niveaux Fibonacci", value=True, key="show_fibonacci")
            show_current_price = st.checkbox("Afficher le prix actuel", value=True, key="show_current_price")
            
            if show_trendlines or show_fibonacci or show_current_price:
                try:
                    # DÃ©tecter les pivots hauts et bas pour les trendlines
                    df_tail = st.session_state.real_time_data.tail(100)  # Utiliser les 100 derniÃ¨res bougies
                    
                    # DÃ©tection des pivots hauts et bas
                    pivot_highs = df_tail[df_tail['high'] == df_tail['high'].rolling(window=5, center=True).max()].dropna()
                    pivot_lows = df_tail[df_tail['low'] == df_tail['low'].rolling(window=5, center=True).min()].dropna()
                    
                    # X-axis handling (index or time column)
                    if 'time' in df_tail.columns:
                        x_series = df_tail['time']
                    elif 'timestamp' in df_tail.columns:
                        x_series = df_tail['timestamp']
                    else:
                        # Convertir l'index en timestamps si c'est un RangeIndex
                        x_series = pd.to_datetime(df_tail.index)
                
                    # Trendline de rÃ©sistance (connecter les 2 plus hauts points)
                    if len(pivot_highs) >= 2 and show_trendlines:
                        high1_idx = pivot_highs.index[0]
                        high2_idx = pivot_highs.index[1]
                
                        # Utiliser iloc pour accÃ©der aux valeurs par position
                        x1, y1 = x_series.iloc[df_tail.index.get_loc(high1_idx)], float(pivot_highs.loc[high1_idx, 'high'])
                        x2, y2 = x_series.iloc[df_tail.index.get_loc(high2_idx)], float(pivot_highs.loc[high2_idx, 'high'])
                            
                        # Ã‰tendre la trendline de rÃ©sistance
                        # Convertir d'abord en timestamps numÃ©riques pour Ã©viter les erreurs Timedelta
                        x1_num = pd.Timestamp(x1).timestamp() if isinstance(x1, (str, pd.Timestamp)) else float(x1)
                        x2_num = pd.Timestamp(x2).timestamp() if isinstance(x2, (str, pd.Timestamp)) else float(x2)
                        x_last_num = pd.Timestamp(x_series.iloc[-1]).timestamp() if isinstance(x_series.iloc[-1], (str, pd.Timestamp)) else float(x_series.iloc[-1])
                        x_first_num = pd.Timestamp(x_series.iloc[0]).timestamp() if isinstance(x_series.iloc[0], (str, pd.Timestamp)) else float(x_series.iloc[0])
                        
                        # Calculer l'extension en utilisant les timestamps numÃ©riques
                        x_extend_num = x_last_num + (x_last_num - x_first_num) * 0.1
                        slope = (y2 - y1) / (x2_num - x1_num) if x2_num != x1_num else 0
                        y_extend = y2 + slope * (x_extend_num - x2_num)
                        
                        # Convertir x_extend_num en timestamp pour l'affichage
                        x_extend = pd.Timestamp.fromtimestamp(x_extend_num)
                        
                        try:
                            fig.add_trace(
                                go.Scatter(x=[x1, x_extend], y=[y1, y_extend], mode="lines",
                                           line=dict(color="#e74c3c", width=2, dash="dash"),
                                           name="RÃ©sistance", showlegend=True),
                                row=1, col=1
                            )
                        except Exception:
                            fig.add_trace(
                                go.Scatter(x=[x1, x_extend], y=[y1, y_extend], mode="lines",
                                           line=dict(color="#e74c3c", width=2, dash="dash"),
                                           name="RÃ©sistance", showlegend=True)
                            )

                    # Trendline de support (connecter les 2 plus bas points)
                    if len(pivot_lows) >= 2 and show_trendlines:
                        low1_idx = pivot_lows.index[0]
                        low2_idx = pivot_lows.index[1]
                
                        # Utiliser iloc pour accÃ©der aux valeurs par position
                        x1, y1 = x_series.iloc[df_tail.index.get_loc(low1_idx)], float(pivot_lows.loc[low1_idx, 'low'])
                        x2, y2 = x_series.iloc[df_tail.index.get_loc(low2_idx)], float(pivot_lows.loc[low2_idx, 'low'])
                    
                        # Ã‰tendre la trendline de support
                        # Convertir d'abord en timestamps numÃ©riques pour Ã©viter les erreurs Timedelta
                        x1_num = pd.Timestamp(x1).timestamp() if isinstance(x1, (str, pd.Timestamp)) else float(x1)
                        x2_num = pd.Timestamp(x2).timestamp() if isinstance(x2, (str, pd.Timestamp)) else float(x2)
                        x_last_num = pd.Timestamp(x_series.iloc[-1]).timestamp() if isinstance(x_series.iloc[-1], (str, pd.Timestamp)) else float(x_series.iloc[-1])
                        x_first_num = pd.Timestamp(x_series.iloc[0]).timestamp() if isinstance(x_series.iloc[0], (str, pd.Timestamp)) else float(x_series.iloc[0])
                
                        # Calculer l'extension en utilisant les timestamps numÃ©riques
                        x_extend_num = x_last_num + (x_last_num - x_first_num) * 0.1
                        slope = (y2 - y1) / (x2_num - x1_num) if x2_num != x1_num else 0
                        y_extend = y2 + slope * (x_extend_num - x2_num)
                
                        # Convertir x_extend_num en timestamp pour l'affichage
                        x_extend = pd.Timestamp.fromtimestamp(x_extend_num)
                
                        try:
                            fig.add_trace(
                                go.Scatter(x=[x1, x_extend], y=[y1, y_extend], mode="lines",
                                   line=dict(color="#2ecc71", width=2, dash="dash"),
                                   name="Support", showlegend=True),
                                row=1, col=1
                            )
                        except Exception:
                            fig.add_trace(
                                go.Scatter(x=[x1, x_extend], y=[y1, y_extend], mode="lines",
                                   line=dict(color="#2ecc71", width=2, dash="dash"),
                                   name="Support", showlegend=True)
                            )

                    # Retracements de Fibonacci sur le swing principal
                    swing_low = df_tail['low'].min()
                    swing_high = df_tail['high'].max()
                    swing_low_idx = df_tail['low'].idxmin()
                    swing_high_idx = df_tail['high'].idxmax()
                
                    # DÃ©terminer la direction du swing principal
                    is_uptrend = swing_low_idx < swing_high_idx
                
                    # Niveaux de Fibonacci complets
                    fib_ratios = [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0]
                    fib_colors = ["#e74c3c", "#f39c12", "#f1c40f", "#2ecc71", "#3498db", "#9b59b6", "#e74c3c"]
                
                    # Afficher les niveaux de Fibonacci seulement si activÃ©
                    if show_fibonacci:
                        for i, (ratio, color) in enumerate(zip(fib_ratios, fib_colors)):
                            if is_uptrend:
                                level = swing_high - (swing_high - swing_low) * ratio
                            else:
                                level = swing_low + (swing_high - swing_low) * ratio
                        
                            # Style diffÃ©rent pour les niveaux clÃ©s
                            line_style = "solid" if ratio in [0, 0.5, 1.0] else "dot"
                            line_width = 3 if ratio in [0, 0.5, 1.0] else 2
                        
                            try:
                                fig.add_hline(y=level, line_color=color, line_dash=line_style,
                                          opacity=0.8, line_width=line_width,
                                          annotation_text=f"Fib {int(ratio*100)}%" if ratio > 0 else "0%",
                                          annotation_position="right",
                                          annotation_font_size=10,
                                          row=1, col=1)
                            except Exception:
                                fig.add_hline(y=level, line_color=color, line_dash=line_style,
                                          opacity=0.8, line_width=line_width,
                                          annotation_text=f"Fib {int(ratio*100)}%" if ratio > 0 else "0%",
                                          annotation_position="right",
                                          annotation_font_size=10)
                
                    # Ajouter une zone de prix actuelle
                    if show_current_price:
                        current_price = df_tail['close'].iloc[-1]
                            try:
                            fig.add_hline(y=current_price, line_color="#ffffff", line_dash="solid",
                                          opacity=1.0, line_width=2,
                                          annotation_text=f"Prix: {current_price:.5f}",
                                          annotation_position="left",
                                          annotation_font_size=12,
                                          row=1, col=1)
                            except Exception:
                            fig.add_hline(y=current_price, line_color="#ffffff", line_dash="solid",
                                          opacity=1.0, line_width=2,
                                          annotation_text=f"Prix: {current_price:.5f}",
                                          annotation_position="left",
                                          annotation_font_size=12)
                                  
                except Exception as e:
            print(f"Erreur dans l'ajout des trendlines/Fibonacci: {e}")
            pass
        
        # Ajouter les prÃ©dictions ML et setups basÃ©s sur les donnÃ©es en temps rÃ©el - DÃ‰SACTIVÃ‰
        if False and len(st.session_state.real_time_data) >= 50:
            try:
                # Utiliser les donnÃ©es en temps rÃ©el pour les prÃ©dictions
                current_data = st.session_state.real_time_data.copy()
                print(f"ðŸ¤– Calcul des prÃ©dictions ML avec {len(current_data)} bougies en temps rÃ©el")
                print(f"ðŸ“… DerniÃ¨re bougie: {current_data['timestamp'].iloc[-1]} - Prix: {current_data['close'].iloc[-1]:.5f}")
                    
                # DÃ©tecter les setups avec les donnÃ©es actuelles
                setups = st.session_state.setup_detector.detect_all_setups(current_data)
                
                # GÃ©nÃ©rer les signaux ML avec les donnÃ©es en temps rÃ©el
                try:
                    # Calculer la probabilitÃ© de spike en temps rÃ©el
                    spike_proba = predict_spike_ml(current_data)
                    if spike_proba is not None:
                        print(f"ðŸŽ¯ ProbabilitÃ© de spike ML: {spike_proba:.3f}")
                    
                    ml_signals = st.session_state.ml_predictor.get_trading_signals(current_data)
                    
                    # Ajouter la probabilitÃ© de spike en temps rÃ©el
                    if spike_proba is not None:
                        ml_signals['spike_probability'] = spike_proba
                        ml_signals['spike'] = 'HIGH_SPIKE_RISK' if spike_proba > 0.7 else 'LOW_SPIKE_RISK'
                        ml_signals['spike_strength'] = spike_proba
                    
                    # Afficher les signaux en temps rÃ©el
                    print(f"ðŸ“Š Signaux ML temps rÃ©el: {ml_signals}")
                    
                except ValueError as e:
                    print(f"âš ï¸ Erreur ML: {e}")
                    # Utiliser des signaux basiques si les modÃ¨les ne sont pas entraÃ®nÃ©s
                    ml_signals = {
                        'direction': 'HOLD',
                        'direction_strength': 0.5,
                        'spike': 'LOW_SPIKE_RISK',
                        'spike_strength': 0.3
                    }
                
                # Ajouter les prÃ©dictions au graphique avec les donnÃ©es en temps rÃ©el
                fig = add_ml_predictions_to_chart(fig, current_data, ml_signals, setups)
                
            except Exception as e:
                st.warning(f"âš ï¸ Impossible d'ajouter les prÃ©dictions au graphique: {e}")
        
        # Stabiliser l'UI lors des refresh (sans forcer de range)
        try:
            fig.update_layout(uirevision="streaming")
        except Exception:
            pass

        # Lignes Bid/Ask si disponibles
        try:
            info = get_symbol_info(symbol)
            bid = None
            ask = None
            if isinstance(info, dict):
                bid = info.get('bid') or info.get('Bid')
                ask = info.get('ask') or info.get('Ask')
            else:
                # Certains wrappers MT5 exposent en attributs
                bid = getattr(info, 'bid', None)
                ask = getattr(info, 'ask', None)
            if isinstance(bid, (int, float)) and isinstance(ask, (int, float)):
                fig.add_hline(y=bid, line_color="#ff4d4f", line_width=1, opacity=0.7,
                              annotation_text="Bid", annotation_position="top left",
                              annotation_font_color="#ff4d4f")
                fig.add_hline(y=ask, line_color="#52c41a", line_width=1, opacity=0.7,
                              annotation_text="Ask", annotation_position="bottom left",
                              annotation_font_color="#52c41a")
        except Exception:
            pass
        
        # Ajout des flÃ¨ches de prÃ©diction de spikes (overlay avant rendu) - DÃ‰SACTIVÃ‰
        try:
            if False and st.session_state.get('show_spike_predictions', True) and len(st.session_state.real_time_data) >= 50:
                # if st.session_state.get('show_spike_predictions', True) and len(st.session_state.real_time_data) >= 50:
                df_sp = st.session_state.real_time_data.copy()
                # Heuristique professionnelle: composite (ret/ATR, dev/Ïƒ, vol/Ïƒ), fenÃªtres adaptatives, min pips
                import numpy as _np
                import pandas as _pd
                closes = df_sp['close'].values
                returns = _np.diff(closes, prepend=closes[0])
                ret_abs = _np.abs(returns)
                ultra = bool(st.session_state.get('spike_ultra_sensitive', False))
                win_vol = 6 if ultra else 10
                win_ma = 10 if ultra else 20
                vol = _pd.Series(closes).pct_change().rolling(win_vol).std().fillna(0).values
                ma = _pd.Series(closes).rolling(win_ma).mean().fillna(method='bfill').values
                dev = closes - ma
                # ATR proxy (ou colonne atr si dispo)
                if 'atr' in df_sp.columns:
                    atr = df_sp['atr'].fillna(method='bfill').fillna(method='ffill').values
                else:
                    highs = df_sp['high'].values
                    lows = df_sp['low'].values
                    prev_close = _np.concatenate(([closes[0]], closes[:-1]))
                    tr = _np.maximum(highs - lows, _np.maximum(_np.abs(highs - prev_close), _np.abs(lows - prev_close)))
                    atr = _pd.Series(tr).rolling(14 if not ultra else 7).mean().fillna(method='bfill').values
                eps = 1e-9
                s_ret = ret_abs / (_np.maximum(atr, eps))
                s_dev = _np.abs(dev) / ((_np.std(dev[-max(50, win_ma*3):]) + eps))
                s_vol = vol / ((_np.std(vol[-max(50, win_vol*3):]) + eps))
                score = 0.5 * s_ret + 0.3 * s_dev + 0.2 * s_vol
                # Direction via momentum court
                mom = _pd.Series(closes).diff(3 if not ultra else 2).fillna(0).values
                # Normalisation robuste
                s_tail = score[-300:]
                s_min = float(_np.percentile(s_tail, 5)) if len(s_tail) > 10 else float(score.min())
                s_max = float(_np.percentile(s_tail, 95)) if len(s_tail) > 10 else float(score.max())
                if s_max <= s_min:
                    s_max = s_min + 1e-6
                proba = _np.clip((score - s_min) / (s_max - s_min), 0, 1)
                thr_base = (st.session_state.get('spike_threshold_slider', 85) or 85) / 100.0
                thr = max(0.5, thr_base - (0.15 if ultra else 0.0))
                # Pip heuristique symbole
                sym = st.session_state.current_symbol or ""
                pip = 0.01 if any(x in sym for x in ['JPY', 'Index', 'Boom', 'Crash']) else 0.0001
                min_pips = int(st.session_state.get('spike_min_pips', 2) or 0)
                # Filtrage candidats
                idx_candidates = []
                for i in range(len(closes)):
                    if proba[i] >= thr:
                        move_pips = abs(returns[i]) / max(pip, 1e-9)
                        if move_pips >= min_pips:
                            idx_candidates.append(i)
                # Annotations
                x_series = df_sp.index if 'time' not in df_sp.columns else df_sp['time']
                # SÃ©ries pour mode strict (EMA/Keltner/Donchian)
                try:
                    ema_fast_seq = _np.array(df_sp['close'].ewm(span=8, adjust=False).mean())
                    ema_slow_seq = _np.array(df_sp['close'].ewm(span=21, adjust=False).mean())
                    ema20_k = _np.array(df_sp['close'].ewm(span=20, adjust=False).mean())
                    prev_close_all = _np.concatenate(([df_sp['close'].iloc[0]], df_sp['close'].values[:-1]))
                    tr_all = _np.maximum(df_sp['high'].values - df_sp['low'].values, _np.maximum(_np.abs(df_sp['high'].values - prev_close_all), _np.abs(df_sp['low'].values - prev_close_all)))
                    atr20_all = _np.convolve(tr_all, _np.ones(20)/20.0, mode='same')
                    donch_hi = _np.maximum.accumulate(df_sp['high'].values)
                    donch_lo = _np.minimum.accumulate(df_sp['low'].values)
                    # FenÃªtres roulantes approximÃ©es (simple et suffisant pour filtre strict)
                    win = 20
                    for k in range(win, len(donch_hi)):
                        donch_hi[k] = _np.max(df_sp['high'].values[k-win+1:k+1])
                        donch_lo[k] = _np.min(df_sp['low'].values[k-win+1:k+1])
                    donch_mid = (donch_hi + donch_lo) / 2.0
                except Exception:
                    ema_fast_seq = _np.array(df_sp['close'])
                    ema_slow_seq = _np.array(df_sp['close'])
                    ema20_k = _np.array(df_sp['close'])
                    atr20_all = _np.ones(len(df_sp))
                    donch_mid = _np.array(df_sp['close'])

                # ContrÃ´les UI
                strict_mode = st.checkbox("Mode strict des flÃ¨ches (EMA/Keltner/Donchian)", value=True, key="arrow_strict_mode")
                force_thr = st.slider("Seuil de force (0-1)", 0.0, 1.0, 0.6, 0.05, key="arrow_force_thr")
                # PrÃ©-signal: placer la flÃ¨che sur la bougie suivante (T-1) quand possible
                last_idx = len(df_sp) - 1
                for i in idx_candidates[-60:]:
                    j = i + 1 if (i + 1) <= last_idx else i
                    # Direction
                    ema_slope = float(ema_fast_seq[j] - ema_fast_seq[max(0, j-1)])
                    direction_up = (mom[i] > 0) and (ema_slope >= 0)

                    # Filtre strict: alignement avec EMA/Keltner/Donchian
                    strict_ok = True
                    if strict_mode:
                        c = float(df_sp['close'].iloc[j])
                        k_mid = float(ema20_k[j])
                        d_mid = float(donch_mid[j])
                        if direction_up:
                            strict_ok = (c >= float(ema_slow_seq[j])) and (ema_fast_seq[j] >= ema_slow_seq[j]) and (c >= k_mid) and (c >= d_mid)
                        else:
                            strict_ok = (c <= float(ema_slow_seq[j])) and (ema_fast_seq[j] <= ema_slow_seq[j]) and (c <= k_mid) and (c <= d_mid)
                    if not strict_ok:
                        continue

                    # Force du signal (0-1)
                    try:
                        mom_win = mom[max(0, i-30):i+1]
                        sd_m = float(_np.std(mom_win)) + 1e-9
                        norm_m = min(1.0, abs(float(mom[i]))/(2.0*sd_m))
                    except Exception:
                        norm_m = 0.5
                    atr_j = float(max(atr20_all[j], 1e-9))
                    norm_slope = min(1.0, abs(ema_slope)/(atr_j*0.5))
                    force_sig = max(0.0, min(1.0, 0.5*norm_m + 0.5*norm_slope))
                    if force_sig < force_thr:
                        continue
                    y = df_sp['high'].iloc[j] if direction_up else df_sp['low'].iloc[j]
                    # Bleu pour BUY, Rouge pour SELL
                    arrow_color = "#3498db" if direction_up else "#e74c3c"
                    arrow_y = float(y)  # Exactement sur le prix - pas de dÃ©calage
                    # FenÃªtre de validitÃ© (prÃ©vision): dÃ©but Ã  la prochaine bougie, fin aprÃ¨s X minutes
                    try:
                        tf_map = {"1m":60, "5m":300, "15m":900, "30m":1800, "1h":3600, "4h":14400, "6h":21600, "8h":28800, "1d":86400}
                        tf_sec = tf_map.get(st.session_state.current_timeframe, 300)
                        validity_min = 10
                        start_dt = datetime.now() + timedelta(seconds=tf_sec)
                        end_dt = start_dt + timedelta(minutes=validity_min)
                        label = f"{'BUY' if direction_up else 'SELL'} ({start_dt.strftime('%H:%M')}â†’{end_dt.strftime('%H:%M')})"
                    except Exception:
                        label = "BUY" if direction_up else "SELL"
                    try:
                        # Utiliser l'index directement pour x
                        x_value = x_series.iloc[j] if hasattr(x_series, 'iloc') else x_series[j]
                        fig.add_annotation(
                            x=x_value, y=arrow_y,
                            ax=0, ay=0,  # Pas de dÃ©calage - superposition directe
                            xref='x', yref='y',
                            showarrow=True, arrowhead=3, arrowsize=1, arrowwidth=2, arrowcolor=arrow_color,
                            opacity=0.9,
                            text=f"{label} Â· force {force_sig:.2f}",
                        )
                        print(f"ðŸŽ¯ Prediction arrow added: {label} at {x_value}, force {force_sig:.2f}")
                        # Colorer la fenÃªtre de validitÃ© sur le fond
                        try:
                            fig.add_vrect(
                                x0=start_dt, x1=end_dt,
                                fillcolor=("rgba(46, 204, 113, 0.15)" if direction_up else "rgba(231, 76, 60, 0.15)"),
                                opacity=0.15,
                                line_width=0,
                                layer="below"
                            )
                        except Exception:
                            pass
                    except Exception:
                        pass
                    # Point jaune de confirmation (momentum + Ã©cart vs MA forts)
                    try:
                        sret_i = float(s_ret[i]) if 's_ret' in locals() else 0.0
                        sdev_i = float(s_dev[i]) if 's_dev' in locals() else 0.0
                        if sret_i > 1.0 and sdev_i > 1.0:
                            x_value = x_series.iloc[j] if hasattr(x_series, 'iloc') else x_series[j]
                            fig.add_scatter(x=[x_value], y=[float(df_sp['close'].iloc[j])],
                                            mode='markers', marker=dict(color='yellow', size=8, line=dict(color='black', width=0.5)),
                                            name='Confirm', showlegend=False)
                    except Exception:
                        pass
        except Exception as _e_sp:
            st.caption(f"(Spike overlay non disponible: {_e_sp})")

        # ==============================
        # Micro-Scalp (signaux proches du prix)
        # ==============================
        try:
            with st.expander("âš¡ Micro-Scalp (signaux proches du prix)", expanded=False):
                dfm = st.session_state.real_time_data.tail(300).copy()
                if len(dfm) >= 50 and all(c in dfm.columns for c in ['high','low','close']):
                    win_atr = st.slider("FenÃªtre ATR (micro)", 5, 21, 10, 1, key="micro_atr_win")
                    mult_sl = st.slider("xATR SL", 0.5, 3.0, 1.0, 0.1, key="micro_sl_mult")
                    mult_tp = st.slider("xATR TP", 0.5, 5.0, 2.0, 0.1, key="micro_tp_mult")
                    min_rr  = st.slider("RR min (TP â‰¥ 50% SL)", 0.5, 3.0, 1.0, 0.1, key="micro_rr")

                    tr = np.maximum(dfm['high']-dfm['low'], np.maximum(abs(dfm['high']-dfm['close'].shift(1)), abs(dfm['low']-dfm['close'].shift(1))))
                    atr = tr.rolling(win_atr, min_periods=win_atr).mean()
                    dfm['atr_m'] = atr

                    ema_fast = dfm['close'].ewm(span=8).mean()
                    ema_slow = dfm['close'].ewm(span=21).mean()
                    vwap = (dfm['close']*np.arange(1, len(dfm)+1)).cumsum()/np.arange(1, len(dfm)+1)
                    dfm['ema_fast'] = ema_fast
                    dfm['ema_slow'] = ema_slow
                    dfm['vwap'] = vwap

                    signals = []
                    px = float(dfm['close'].iloc[-1])
                    atr_now = float(dfm['atr_m'].iloc[-1] or 0)
                    if atr_now > 0:
                        near_buy_ref = abs(px - float(dfm['ema_slow'].iloc[-1])) <= 0.2*atr_now or abs(px - float(dfm['vwap'].iloc[-1])) <= 0.2*atr_now
                        trend_up = float(dfm['ema_fast'].iloc[-1]) >= float(dfm['ema_slow'].iloc[-1])
                        if trend_up and near_buy_ref:
                            sl = px - mult_sl*atr_now
                            tp = px + mult_tp*atr_now
                            if (tp - px) / max(px - sl, 1e-9) >= max(0.5, min_rr):
                                signals.append({"side":"BUY", "entry":px, "sl":sl, "tp":tp, "atr":atr_now})

                        near_sell_ref = abs(px - float(dfm['ema_slow'].iloc[-1])) <= 0.2*atr_now or abs(px - float(dfm['vwap'].iloc[-1])) <= 0.2*atr_now
                        trend_dn = float(dfm['ema_fast'].iloc[-1]) <= float(dfm['ema_slow'].iloc[-1])
                        if trend_dn and near_sell_ref:
                            sl = px + mult_sl*atr_now
                            tp = px - mult_tp*atr_now
                            if (px - tp) / max(sl - px, 1e-9) >= max(0.5, min_rr):
                                signals.append({"side":"SELL", "entry":px, "sl":sl, "tp":tp, "atr":atr_now})

                    if signals:
                        st.success(f"{len(signals)} signal(s) micro trouvÃ©s")
                        for s in signals[:3]:
                            st.write(f"{s['side']} @ {s['entry']:.5f} | SL {s['sl']:.5f} | TP {s['tp']:.5f} | ATR {s['atr']:.5f}")
                            # Publier vers API Signaux (MT5)
                            try:
                                valid_from = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                                # ValiditÃ© courte: 10 minutes
                                valid_to = (datetime.now() + timedelta(minutes=10)).strftime('%Y-%m-%d %H:%M:%S')
                                publish_signal(symbol, s['side'], s['entry'], s['sl'], s['tp'], 0.7, valid_from, valid_to, source="micro_scalp")
                            except Exception:
                                pass
                            # Envoi WhatsApp/SMS (Twilio/Vonage) â€“ optionnel
                            try:
                                if st.session_state.get('notify_whatsapp', True) or st.session_state.get('notify_sms', False):
                                    txt = f"{symbol} | {s['side']} micro | entrÃ©e {s['entry']:.5f} | SL {s['sl']:.5f} | TP {s['tp']:.5f}"
                                    if st.session_state.get('notify_whatsapp', True):
                                        from frontend.whatsapp_notify import send_whatsapp_message_unified
                                        _ = send_whatsapp_message_unified(f"ðŸŸ¢ SIGNAL MICRO\n{txt}") if s['side']=='BUY' else send_whatsapp_message_unified(f"ðŸ”´ SIGNAL MICRO\n{txt}")
                                    if st.session_state.get('notify_sms', False):
                                        from frontend.whatsapp_notify import send_sms_vonage
                                        _ = send_sms_vonage(txt)
                            except Exception:
                                pass
                    else:
                        st.info("Pas de signal micro valide maintenant")
        except Exception:
            pass

        # ðŸŽ¯ Sniper Boom/Crash (pro)
        with st.expander("ðŸŽ¯ Sniper Boom/Crash (pro)", expanded=False):
            if 'sniper_enabled' not in st.session_state:
                st.session_state['sniper_enabled'] = True
            st.checkbox("Activer la stratÃ©gie Sniper avancÃ©e", value=st.session_state['sniper_enabled'], key="sniper_enabled")
            st.caption("RÃ¨gles: MTF (M5 contexte, M1 entrÃ©e) Â· EMA200 filtre Â· RSI/Stoch Â· MACD croisement Â· Bollinger touch Â· ATR SL/TP")

        # VÃ©rification silencieuse du graphique
        traces_before_arrows = len(fig.data) if hasattr(fig, 'data') else 0

        # Overlays Sniper Strategy (Boom/Crash) - DÃ‰SACTIVÃ‰
        try:
            if False and st.session_state.get('sniper_enabled', True) and len(st.session_state.real_time_data) >= 60:
                # if st.session_state.get('sniper_enabled', True) and len(st.session_state.real_time_data) >= 60:
                import numpy as _np
                import pandas as _pd
                df_sn = st.session_state.real_time_data.copy()
                # Compute EMA200 if missing
                if 'ema_200' not in df_sn.columns:
                    df_sn['ema_200'] = _pd.Series(df_sn['close']).ewm(span=200, adjust=False).mean()
                # Compute Stochastic if missing
                if 'stoch_k' not in df_sn.columns or 'stoch_d' not in df_sn.columns:
                    high14 = df_sn['high'].rolling(14, min_periods=14).max()
                    low14 = df_sn['low'].rolling(14, min_periods=14).min()
                    stoch_k = (df_sn['close'] - low14) / (high14 - low14 + 1e-9) * 100.0
                    stoch_d = stoch_k.rolling(3, min_periods=3).mean()
                    df_sn['stoch_k'] = stoch_k.fillna(method='bfill')
                    df_sn['stoch_d'] = stoch_d.fillna(method='bfill')
                # Bollinger bands (20,2) if missing
                if not all(col in df_sn.columns for col in ['bb_upper','bb_middle','bb_lower']):
                    ma20 = df_sn['close'].rolling(20, min_periods=20).mean()
                    sd20 = df_sn['close'].rolling(20, min_periods=20).std()
                    df_sn['bb_middle'] = ma20
                    df_sn['bb_upper'] = ma20 + 2*sd20
                    df_sn['bb_lower'] = ma20 - 2*sd20
                # MACD if missing
                if 'macd' not in df_sn.columns or 'macd_signal' not in df_sn.columns:
                    ema12 = df_sn['close'].ewm(span=12, adjust=False).mean()
                    ema26 = df_sn['close'].ewm(span=26, adjust=False).mean()
                    macd = ema12 - ema26
                    macd_signal = macd.ewm(span=9, adjust=False).mean()
                    df_sn['macd'] = macd
                    df_sn['macd_signal'] = macd_signal
                # RSI if missing
                if 'rsi_14' not in df_sn.columns:
                    diff = df_sn['close'].diff()
                    up = diff.clip(lower=0).rolling(14).mean()
                    down = (-diff.clip(upper=0)).rolling(14).mean()
                    rs = up / (down + 1e-9)
                    df_sn['rsi_14'] = 100 - (100 / (1 + rs))
                # ATR for SL/TP
                highs = df_sn['high'].values; lows = df_sn['low'].values; closes = df_sn['close'].values
                prev_close = _np.concatenate(([closes[0]], closes[:-1]))
                tr = _np.maximum(highs - lows, _np.maximum(_np.abs(highs - prev_close), _np.abs(lows - prev_close)))
                df_sn['atr14'] = _pd.Series(tr).rolling(14).mean().fillna(method='bfill')

                # Context M5 via API trend_summary (si dispo)
                context_bull = None
                try:
                    import requests as _rq
                    base = "http://localhost:8000"
                    sym = st.session_state.current_symbol
                    rctx = _rq.get(f"{base}/trend_summary", params={"symbol": sym, "nocache": 1}, timeout=6)
                    if rctx.status_code == 200:
                        ctx = rctx.json()
                        t5 = (ctx.get('trends',{}).get('5m',{}) or {})
                        context_bull = (str(t5.get('trend','')).lower() == 'bullish')
                except Exception:
                    context_bull = None

                # GÃ©nÃ©ration des signaux Sniper sur la derniÃ¨re fenÃªtre
                marks = []
                N = len(df_sn)
                rng = range(max(20, N-300), N)
                print(f"ðŸ” Debug Sniper: Analysing {len(rng)} bars, N={N}")
                for i in rng:
                    c = df_sn['close'].iloc[i]
                    ema200 = df_sn['ema_200'].iloc[i]
                    rsi = df_sn['rsi_14'].iloc[i]
                    k = df_sn['stoch_k'].iloc[i]
                    d = df_sn['stoch_d'].iloc[i]
                    macd = df_sn['macd'].iloc[i]
                    macds = df_sn['macd_signal'].iloc[i]
                    bb_up = df_sn['bb_upper'].iloc[i]
                    bb_lo = df_sn['bb_lower'].iloc[i]
                    atr = float(df_sn['atr14'].iloc[i] or 0.0)
                    above_ema = c > ema200
                    below_ema = c < ema200
                    macd_buy = macd > macds
                    macd_sell = macd < macds
                    stoch_rebound_buy = (k < 20 and d < 20) or (k > d and k < 30)
                    stoch_rebound_sell = (k > 80 and d > 80) or (k < d and k > 70)
                    bb_touch_buy = c <= bb_lo
                    bb_touch_sell = c >= bb_up
                    ctx_ok_buy = (context_bull is None) or context_bull
                    ctx_ok_sell = (context_bull is None) or (context_bull is False)
                    
                    # Analyse de tendance globale pour cohÃ©rence des signaux
                    # Calculer la tendance sur les 20 derniÃ¨res bougies
                    trend_period = min(20, i)
                    if trend_period >= 5:
                        recent_closes = [df_sn['close'].iloc[j] for j in range(max(0, i-trend_period), i+1)]
                        trend_slope = (recent_closes[-1] - recent_closes[0]) / len(recent_closes) if len(recent_closes) > 1 else 0
                        trend_bullish = trend_slope > 0
                        trend_bearish = trend_slope < 0
                    else:
                        trend_bullish = above_ema
                        trend_bearish = below_ema
                    
                    # Conditions strictes pour Ã©viter les signaux contradictoires
                    # DÃ©terminer la direction dominante sur une pÃ©riode plus longue
                    long_trend_period = min(50, i)
                    if long_trend_period >= 10:
                        long_recent_closes = [df_sn['close'].iloc[j] for j in range(max(0, i-long_trend_period), i+1)]
                        long_trend_slope = (long_recent_closes[-1] - long_recent_closes[0]) / len(long_recent_closes) if len(long_recent_closes) > 1 else 0
                        dominant_bullish = long_trend_slope > 0
                        dominant_bearish = long_trend_slope < 0
                    else:
                        dominant_bullish = above_ema
                        dominant_bearish = below_ema
                    
                    # Signaux exclusifs : soit BUY soit SELL, jamais les deux
                    if dominant_bullish:
                        # Mode haussier : seulement des signaux BUY
                        buy_ok = above_ema and (rsi < 40) and stoch_rebound_buy and macd_buy and (bb_touch_buy or rsi < 35)
                        sell_ok = False  # Pas de SELL en mode haussier
                    elif dominant_bearish:
                        # Mode baissier : seulement des signaux SELL
                        sell_ok = below_ema and (rsi > 60) and stoch_rebound_sell and macd_sell and (bb_touch_sell or rsi > 65)
                        buy_ok = False   # Pas de BUY en mode baissier
                    else:
                        # Mode neutre : pas de signaux
                        buy_ok = False
                        sell_ok = False
                    
                    # Debug des conditions
                    if i % 30 == 0:  # Log tous les 30 barres pour Ã©viter le spam
                        print(f"ðŸ” Bar {i}: RSI={rsi:.1f}, K={k:.1f}, D={d:.1f}, MACD={macd:.4f}, EMA200={ema200:.5f}, Close={c:.5f}")
                        print(f"   Dominant Trend: {'Bullish' if dominant_bullish else 'Bearish' if dominant_bearish else 'Neutral'}, Long Slope: {long_trend_slope:.5f}")
                        print(f"   Mode: {'BUY Only' if dominant_bullish else 'SELL Only' if dominant_bearish else 'No Signals'}")
                        print(f"   Above EMA: {above_ema}, RSI<40: {rsi < 40}, Stoch: {stoch_rebound_buy}, MACD: {macd_buy}, BB: {bb_touch_buy}")
                    if buy_ok:
                        marks.append((i, True, c, atr))
                        print(f"âœ… BUY signal at bar {i}, price {c:.5f}")
                    elif sell_ok:
                        marks.append((i, False, c, atr))
                        print(f"âŒ SELL signal at bar {i}, price {c:.5f}")

                # Ajouter des marqueurs + table SL/TP via ATR
                if 'time' in df_sn.columns:
                    x_series = df_sn['time']
                else:
                    # Convertir l'index en timestamps si nÃ©cessaire
                    x_series = pd.to_datetime(df_sn.index)
                
                print(f"ðŸŽ¯ Debug: {len(marks)} signals found, displaying last 40")
                print(f"ðŸ” Debug: x_series type: {type(x_series)}, length: {len(x_series)}")
                
                # VÃ©rifier la cohÃ©rence des signaux
                buy_signals = [m for m in marks if m[1]]  # m[1] = is_buy
                sell_signals = [m for m in marks if not m[1]]
                print(f"ðŸ“Š Signaux BUY: {len(buy_signals)}, Signaux SELL: {len(sell_signals)}")
                
                if len(buy_signals) > 0 and len(sell_signals) > 0:
                    print("âš ï¸ ATTENTION: Signaux contradictoires dÃ©tectÃ©s !")
                    print("ðŸ”§ Filtrage des signaux pour Ã©viter les contradictions...")
                    # Garder seulement les signaux de la direction dominante
                    if len(buy_signals) >= len(sell_signals):
                        marks = buy_signals  # Garder seulement les BUY
                        print("âœ… GardÃ© seulement les signaux BUY")
                    else:
                        marks = sell_signals  # Garder seulement les SELL
                        print("âœ… GardÃ© seulement les signaux SELL")
                
                if True:  # RÃ‰ACTIVÃ‰ - FlÃ¨ches de prÃ©diction
                    for i, is_buy, price, atr in marks[-40:]:
                        arrow_color = "#00ff88" if is_buy else "#ff4444"  # Couleurs cohÃ©rentes avec les chandeliers
                        # Positionner les flÃ¨ches directement sur les chandeliers
                        if is_buy:
                            y = df_sn['low'].iloc[i] - (atr * 0.1)  # LÃ©gÃ¨rement en dessous du low
                            ay_offset = -40  # FlÃ¨che vers le haut
                        else:
                            y = df_sn['high'].iloc[i] + (atr * 0.1)  # LÃ©gÃ¨rement au-dessus du high
                            ay_offset = 40   # FlÃ¨che vers le bas
                        
                        try:
                            # Utiliser l'index directement pour x
                            x_value = x_series.iloc[i] if hasattr(x_series, 'iloc') else x_series[i]
                            fig.add_annotation(
                                x=x_value, y=y, ax=0, ay=ay_offset,
                                xref='x', yref='y', 
                                showarrow=True, arrowhead=2,
                                arrowsize=1.5, arrowwidth=3, 
                                arrowcolor=arrow_color, 
                                opacity=0.9, 
                                text=f"{'BUY' if is_buy else 'SELL'}",
                                font=dict(color=arrow_color, size=10),
                                bgcolor='rgba(0,0,0,0.7)',
                                bordercolor=arrow_color,
                                borderwidth=1
                            )
                            print(f"ðŸ“Š Arrow added: {'BUY' if is_buy else 'SELL'} at {x_value}, price {y:.5f}")
                        except Exception as e:
                            print(f"âŒ Error adding arrow: {e}")
                            print(f"ðŸ” Debug: i={i}, x_series[i]={x_series[i] if i < len(x_series) else 'out of range'}")
                            pass
                        # Point jaune de confirmation RSI/Stoch + MACD
                        try:
                            rsi = float(df_sn['rsi_14'].iloc[i])
                            k = float(df_sn.get('stoch_k', df_sn['rsi_14']).iloc[i])
                            d = float(df_sn.get('stoch_d', df_sn['rsi_14']).iloc[i])
                            macd_ok = bool((df_sn['macd'].iloc[i] > df_sn['macd_signal'].iloc[i]) if is_buy else (df_sn['macd'].iloc[i] < df_sn['macd_signal'].iloc[i]))
                            stoch_ok = (k < d and k < 30) if is_buy else (k > d and k > 70)
                            rsi_ok = (rsi < 35) if is_buy else (rsi > 65)
                            if macd_ok and stoch_ok and rsi_ok:
                                fig.add_scatter(x=[x_series.iloc[i]], y=[float(df_sn['close'].iloc[i])],
                                                mode='markers', marker=dict(color='yellow', size=8, line=dict(color='black', width=0.5)),
                                                name='Confirm', showlegend=False)
                        except Exception:
                            pass
                # Si aucun signal trouvÃ©, essayer des conditions plus simples
                if not marks:
                    print("ðŸ” Aucun signal strict trouvÃ©, essayant des conditions plus simples...")
                    for i in rng[-50:]:  # DerniÃ¨res 50 barres seulement
                        c = df_sn['close'].iloc[i]
                        rsi = df_sn['rsi_14'].iloc[i]
                        ema200 = df_sn['ema_200'].iloc[i]
                        atr = float(df_sn['atr14'].iloc[i] or 0.0)
                        
                        # Conditions trÃ¨s simples
                        simple_buy = (c > ema200) and (rsi < 45) and (rsi > 20)
                        simple_sell = (c < ema200) and (rsi > 55) and (rsi < 80)
                        
                        if simple_buy:
                            marks.append((i, True, c, atr))
                            print(f"âœ… Simple BUY signal at bar {i}, price {c:.5f}, RSI {rsi:.1f}")
                        elif simple_sell:
                            marks.append((i, False, c, atr))
                            print(f"âŒ Simple SELL signal at bar {i}, price {c:.5f}, RSI {rsi:.1f}")
                
                if marks:
                    try:
                        import pandas as _pd
                        rows = []
                        sym = st.session_state.current_symbol or "?"
                        for i, is_buy, price, atr in marks[-6:]:
                            if is_buy:
                                sl = price - 1.5*atr
                                tp = price + 3.0*atr
                            else:
                                sl = price + 1.5*atr
                                tp = price - 3.0*atr
                            rows.append({
                                "Type": "BUY" if is_buy else "SELL",
                                "EntrÃ©e": round(float(price), 5),
                                "SL": round(float(sl), 5),
                                "TP": round(float(tp), 5),
                                "ATR": round(float(atr), 5)
                            })
                        st.caption("Derniers signaux Sniper (ATR SL/TP)")
                        st.dataframe(_pd.DataFrame(rows), use_container_width=True, hide_index=True)
                        # Publier aussi vers API Signaux avec critÃ¨res de risque stricts
                        try:
                            for i, is_buy, price, atr in marks[-6:]:
                                # Calculer la taille d'un pip pour le symbole
                                pip_size = 0.0001 if "JPY" not in sym else 0.01
                                if "Index" in sym or "Boom" in sym or "Crash" in sym:
                                    pip_size = 0.1  # Pour les indices
                                
                                # CritÃ¨res stricts: SL max 10 pips, TP min 30 pips
                                max_sl_pips = 10.0
                                min_tp_pips = 30.0
                                
                                # Calculer SL et TP selon les critÃ¨res
                                sl_distance = max_sl_pips * pip_size
                                tp_distance = min_tp_pips * pip_size
                                
                                if is_buy:
                                    sl = price - sl_distance
                                    tp = price + tp_distance
                                else:
                                    sl = price + sl_distance
                                    tp = price - tp_distance
                                
                                valid_from = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                                valid_to = (datetime.now() + timedelta(minutes=20)).strftime('%Y-%m-%d %H:%M:%S')
                                publish_signal(sym, 'BUY' if is_buy else 'SELL', float(price), float(sl), float(tp), 0.8, valid_from, valid_to, source='sniper')
                        except Exception as e:
                            st.write(f"âš ï¸ Erreur traitement signaux: {e}")
                    except Exception as e:
                        st.write(f"âš ï¸ Erreur affichage signaux: {e}")
                else:
                    st.write("âš ï¸ Aucun signal trouvÃ© mÃªme avec les conditions simplifiÃ©es")
        except Exception as _e_sn:
            st.caption(f"(Sniper overlay non disponible: {_e_sn})")
        
        # VÃ©rification silencieuse aprÃ¨s ajout des flÃ¨ches
        traces_after_arrows = len(fig.data) if hasattr(fig, 'data') else 0
        
        if traces_after_arrows == 0:
            st.error("âŒ Erreur: Le graphique a Ã©tÃ© corrompu")
            # RecrÃ©er le graphique de base avec optimisations
            fig = create_candlestick_chart(st.session_state.real_time_data, chart_title)
            if fig is not None:
                fig.update_layout(
                    title=chart_title, 
                    height=900,  # Hauteur rÃ©duite Ã  100% de zoom
                    width=1600,  # Largeur Ã©quilibrÃ©e
                    margin=dict(l=70, r=15, t=50, b=40),  # Marges Ã©quilibrÃ©es
                    autosize=False  # DÃ©sactiver l'auto-resize
                )

        # Stabiliser l'UI lors des refresh (sans forcer de range)
        try:
            fig.update_layout(uirevision="streaming")
        except Exception:
            pass

        # Afficher le graphique optimisÃ© (avec ou sans flÃ¨ches)
        # Utiliser une colonne pour maximiser l'espace du graphique avec dÃ©calage vers la droite
        col1, col2, col3 = st.columns([0.02, 0.96, 0.02])
        with col2:
            st.plotly_chart(
                fig, 
                use_container_width=True,  # Utiliser toute la largeur disponible
                height=800,  # Hauteur ajustÃ©e pour le zoom 79%
                key="price_chart",
                config={
                    'displayModeBar': True,
                    'displaylogo': False,
                    'modeBarButtonsToRemove': ['pan2d', 'lasso2d', 'select2d'],
                    'responsive': True,  # Activer la responsivitÃ©
                    'toImageButtonOptions': {
                        'format': 'png',
                        'filename': f'{symbol}_{st.session_state.current_timeframe}',
                        'height': 900,
                        'width': 1600,
                        'scale': 2
                    }
                }
            )
        
        # ==============================
        # ANALYSE MULTI-TIMEFRAME
        # ==============================
        st.markdown("---")
        st.markdown("### ðŸ“ˆ Analyse Multi-Timeframe")
        
        with st.expander("ðŸ“Š Tableau de Tendance Multi-Timeframe", expanded=True):
            try:
                import requests
                trend_api_url = f"http://localhost:8000/trend_summary?symbol={symbol}&nocache=1"
                trend_response = requests.get(trend_api_url, timeout=15)
                
                if trend_response.status_code == 200:
                    trend_data = trend_response.json()
                    
                    # CrÃ©er le tableau de tendance
                    tf_order = ["1d", "8h", "6h", "4h", "1h", "30m", "15m", "5m", "1m"]
                    tf_labels = ["D1", "H8", "H6", "H4", "H1", "M30", "M15", "M5", "M1"]
                    
                    # PrÃ©parer les donnÃ©es pour le tableau
                    trend_table_data = []
                    for tf in tf_order:
                        tf_info = trend_data.get("trends", {}).get(tf, {})
                        trend = (tf_info.get("trend") or "neutral").lower()
                        force = tf_info.get("force")
                        slope = tf_info.get("slope")
                        rsi = tf_info.get("rsi")
                        macd = tf_info.get("macd")
                        
                        # Formatage des valeurs
                        try:
                            force_val = int(force) if isinstance(force, (int, float)) else 0
                        except Exception:
                            force_val = 0
                        force_str = f"{force_val}%"
                        slope_val = float(slope) if isinstance(slope, (int, float)) else 0.0
                        slope_str = f"{slope_val:.4f}"
                        rsi_val = float(rsi) if isinstance(rsi, (int, float)) else 50.0
                        rsi_str = f"{rsi_val:.1f}"
                        macd_val = float(macd) if isinstance(macd, (int, float)) else 0.0
                        macd_str = f"{macd_val:.4f}"
                        
                        # Couleur selon la tendance
                        if trend == "bullish":
                            trend_display = "ðŸŸ¢ Haussier"
                        elif trend == "bearish":
                            trend_display = "ðŸ”´ Baissier"
                        else:
                            trend_display = "âšª Neutre"
                        
                        trend_table_data.append({
                            "Timeframe": tf_labels[tf_order.index(tf)],
                            "Tendance": trend_display,
                            "Force": force_str,
                            "Slope": slope_str,
                            "RSI": rsi_str,
                            "MACD": macd_str
                        })
                    
                    # Afficher le tableau
                    if trend_table_data:
                        df_trend = pd.DataFrame(trend_table_data)
                        st.dataframe(
                            df_trend,
                            use_container_width=True,
                            hide_index=True
                        )
                    else:
                        st.warning("Aucune donnÃ©e de tendance disponible")
                        
                else:
                    st.error(f"âŒ Erreur API: {trend_response.status_code}")
                    
            except requests.exceptions.RequestException as e:
                st.error(f"âŒ Impossible de se connecter Ã  l'API de tendance: {str(e)}")
                st.info("ðŸ’¡ Assurez-vous que l'API de tendance est dÃ©marrÃ©e sur le port 8000")
            except Exception as e:
                st.error(f"âŒ Erreur lors de l'analyse de tendance: {str(e)}")
        
        # ==============================
        # INDICATEURS TECHNIQUES MODERNES
        # ==============================
        st.markdown("---")
        st.markdown("### ðŸ§  Indicateurs Techniques Modernes (2025)")
        
        with st.expander("ðŸ“Š Indicateurs AvancÃ©s", expanded=False):
            try:
                base = "http://localhost:8000"
                params = {"symbol": symbol, "timeframe": st.session_state.current_timeframe, "count": 200}
                
                # VÃ©rifier si l'API est disponible
                try:
                    test_response = _rq.get(f"{base}/health", timeout=5)
                    api_available = test_response.status_code == 200
                except Exception:
                    api_available = False
                
                if not api_available:
                    st.info("ðŸ”§ **API des indicateurs modernes non disponible**")
                    st.markdown("""
                    **Pour activer les indicateurs 2025 :**
                    1. Lancez l'API backend : `python start_signal_api.py`
                    2. VÃ©rifiez que le port 8000 est libre
                    3. Rechargez cette page
                    
                    **Indicateurs disponibles :**
                    - ðŸ“Š Structure de marchÃ© (BOS/CHOCH)
                    - ðŸ’° Smart Money (Order Blocks, FVG)
                    - ðŸ“ˆ VWAP et Supertrend
                    - ðŸŽ¯ Pivots et Squeeze
                    """)
                else:
                    # RÃ©cupÃ©rer les indicateurs modernes avec gestion d'erreur
                    def get_indicator_data(endpoint):
                        try:
                            response = _rq.get(f"{base}{endpoint}", params=params, timeout=10)
                            return response.json() if response.status_code == 200 else {}
                        except Exception:
                            return {}
                
                    ms = get_indicator_data("/indicators/market_structure")
                    sm = get_indicator_data("/indicators/smart_money")
                    vw = get_indicator_data("/indicators/vwap")
                    sq = get_indicator_data("/indicators/squeeze")
                    stn = get_indicator_data("/indicators/supertrend")
                    pv = get_indicator_data("/indicators/pivots")

                    # Option debug: afficher les JSON bruts si nÃ©cessaire
                    show_raw = st.checkbox("ðŸ‘€ Voir les donnÃ©es brutes (debug)", value=False, key="indicators_show_raw")

                    # RÃ©sumÃ© compact en un seul tableau en haut (toujours visible)
                    try:
                        import pandas as _pd
                        regime = (ms.get("regime") if isinstance(ms, dict) else None) or "?"
                        last_bos = (ms.get("bos") or [])[-1] if isinstance(ms, dict) and ms.get("bos") else None
                        bos_dir = (last_bos.get("direction") if last_bos else None) or "?"
                        
                        # CrÃ©er un tableau de rÃ©sumÃ© des indicateurs
                        indicators_summary = []
                        
                        # Market Structure
                        if ms:
                            indicators_summary.append({
                                "Indicateur": "ðŸ“Š Structure de MarchÃ©",
                                "Valeur": regime,
                                "DÃ©tail": f"BOS: {bos_dir}" if bos_dir != "?" else "N/A"
                            })
                        
                        # Smart Money
                        if sm:
                            ob_count = len(sm.get("order_blocks", []))
                            fvg_count = len(sm.get("fair_value_gaps", []))
                            indicators_summary.append({
                                "Indicateur": "ðŸ’° Smart Money",
                                "Valeur": f"{ob_count} OB, {fvg_count} FVG",
                                "DÃ©tail": "Order Blocks & Fair Value Gaps"
                            })
                        
                        # VWAP
                        if vw:
                            vwap_price = vw.get("vwap", "N/A")
                            indicators_summary.append({
                                "Indicateur": "ðŸ“ˆ VWAP",
                                "Valeur": f"{vwap_price:.5f}" if isinstance(vwap_price, (int, float)) else str(vwap_price),
                                "DÃ©tail": "Volume Weighted Average Price"
                            })
                        
                        # Supertrend
                        if stn:
                            st_direction = stn.get("direction", "N/A")
                            st_value = stn.get("value", "N/A")
                            indicators_summary.append({
                                "Indicateur": "ðŸ“ˆ Supertrend",
                                "Valeur": st_direction,
                                "DÃ©tail": f"Value: {st_value:.5f}" if isinstance(st_value, (int, float)) else str(st_value)
                            })
                        
                        # Afficher le tableau de rÃ©sumÃ©
                        if indicators_summary:
                            df_indicators = _pd.DataFrame(indicators_summary)
                            st.dataframe(df_indicators, use_container_width=True, hide_index=True)
                        else:
                            st.warning("Aucun indicateur moderne disponible")
                            
                    except Exception as e:
                        st.error(f"Erreur lors de l'affichage des indicateurs: {e}")
                        
            except Exception as e:
                st.error(f"Erreur dans les indicateurs modernes: {e}")
        
        # ==============================
        # SECTIONS DÃ‰CALÃ‰ES EN BAS
        # ==============================
        
        # CrÃ©er un conteneur pour toutes les sections secondaires
        with st.container():
            st.markdown("---")  # SÃ©parateur visuel
            st.markdown("### ðŸ“Š Outils et Analyses SupplÃ©mentaires")
        
        # ==============================
        # ExÃ©cuteur Automatique de Signaux
        # ==============================
        try:
            with st.expander("ðŸ¤– ExÃ©cuteur Automatique de Signaux", expanded=False):
                st.markdown("#### ðŸŽ¯ Configuration de l'ExÃ©cution Automatique")
                
                col1, col2 = st.columns(2)
                
                with col1:
                    auto_executor_enabled = st.checkbox(
                        "Activer l'exÃ©cution automatique", 
                        value=st.session_state.get('auto_executor_enabled', False),
                        key='auto_executor_enabled',
                        help="ExÃ©cute automatiquement les signaux sur MetaTrader 5"
                    )
                    
                    if auto_executor_enabled:
                        st.success("âœ… ExÃ©cution automatique activÃ©e")
                        
                        # Configuration du risque
                        max_risk = st.slider(
                            "Risque maximum par trade (%)", 
                            min_value=0.5, max_value=5.0, value=2.0, step=0.1,
                            key='auto_executor_risk',
                            help="Pourcentage du capital risquÃ© par trade"
                        )
                        
                        min_confidence = st.slider(
                            "Confiance minimum requise (%)", 
                            min_value=50, max_value=95, value=75, step=5,
                            key='auto_executor_confidence',
                            help="Niveau de confiance minimum pour exÃ©cuter un signal"
                        )
                        
                        max_daily_trades = st.slider(
                            "Nombre maximum de trades par jour", 
                            min_value=1, max_value=20, value=8, step=1,
                            key='auto_executor_max_trades',
                            help="Limite quotidienne de trades automatiques"
                        )
                        
                        # Bouton pour dÃ©marrer/arrÃªter l'exÃ©cuteur
                        if st.button("ðŸš€ DÃ©marrer l'ExÃ©cuteur Automatique", type="primary"):
                            try:
                                # Importer et dÃ©marrer l'exÃ©cuteur
                                from backend.auto_signal_executor import AutoSignalExecutor
                                
                                executor = AutoSignalExecutor(
                                    signal_api_url="http://localhost:8001",
                                    check_interval=5,
                                    max_risk_per_trade=max_risk/100,
                                    min_confidence=min_confidence/100,
                                    max_daily_trades=max_daily_trades,
                                    enabled=True
                                )
                                
                                if executor.start():
                                    st.success("âœ… ExÃ©cuteur automatique dÃ©marrÃ© avec succÃ¨s!")
                                    st.info("ðŸ“± Les signaux seront maintenant exÃ©cutÃ©s automatiquement sur MT5")
                                    
                                    # Sauvegarder la configuration
                                    st.session_state.auto_executor_config = {
                                        'enabled': True,
                                        'max_risk': max_risk,
                                        'min_confidence': min_confidence,
                                        'max_daily_trades': max_daily_trades
                                    }
                                else:
                                    st.error("âŒ Impossible de dÃ©marrer l'exÃ©cuteur automatique")
                                    st.error("VÃ©rifiez que MetaTrader 5 est connectÃ© et configurÃ©")
                                    
                            except Exception as e:
                                st.error(f"âŒ Erreur lors du dÃ©marrage: {e}")
                        
                        if st.button("ðŸ›‘ ArrÃªter l'ExÃ©cuteur Automatique"):
                            try:
                                # ArrÃªter l'exÃ©cuteur (nÃ©cessite une implÃ©mentation de gestion d'Ã©tat)
                                st.warning("âš ï¸ FonctionnalitÃ© d'arrÃªt Ã  implÃ©menter")
                                st.info("ðŸ’¡ Pour arrÃªter l'exÃ©cuteur, fermez le processus ou redÃ©marrez l'application")
                            except Exception as e:
                                st.error(f"âŒ Erreur lors de l'arrÃªt: {e}")
                    
                    else:
                        st.warning("âš ï¸ ExÃ©cution automatique dÃ©sactivÃ©e")
                        st.info("ðŸ’¡ Activez l'option pour permettre l'exÃ©cution automatique des signaux")
                
                with col2:
                    st.markdown("#### ðŸ“Š Statut de l'ExÃ©cuteur")
                    
                    # Afficher le statut de l'API de signaux
                    try:
                        import requests
                        response = requests.get("http://localhost:8001/health", timeout=3)
                        if response.status_code == 200:
                            st.success("âœ… API de signaux disponible")
                            data = response.json()
                            st.info(f"ðŸ“ˆ Signaux disponibles: {data.get('count', 0)}")
                        else:
                            st.error("âŒ API de signaux indisponible")
                    except Exception:
                        st.error("âŒ Impossible de contacter l'API de signaux")
                    
                    # Afficher le statut MT5
                    if MT5_AVAILABLE and is_connected():
                        st.success("âœ… MetaTrader 5 connectÃ©")
                    else:
                        st.error("âŒ MetaTrader 5 non connectÃ©")
                    
                    # Informations sur l'exÃ©cution automatique
                    st.markdown("#### â„¹ï¸ Informations")
                    st.info("""
                    **Comment Ã§a fonctionne:**
                    1. L'exÃ©cuteur surveille l'API de signaux
                    2. Valide chaque signal (confiance, timing, etc.)
                    3. Calcule la taille de position selon le risque
                    4. ExÃ©cute l'ordre sur MetaTrader 5
                    5. GÃ¨re les stop loss et take profit
                    """)
                    
                    st.warning("""
                    **âš ï¸ Important:**
                    - Assurez-vous que MT5 est connectÃ©
                    - VÃ©rifiez votre capital disponible
                    - L'exÃ©cution automatique comporte des risques
                    - Surveillez rÃ©guliÃ¨rement les positions ouvertes
                    """)
        
        except Exception as e_auto:
            st.caption(f"(ExÃ©cuteur automatique non disponible: {e_auto})")
        
        # Watchlist AutoMonitor - Scan & Opportunities table
        try:
            import requests as _rq
            if st.session_state.watchlist:
                # Auto trigger based on interval
                trigger_scan = False
                # Planification indÃ©pendante
                now = datetime.now()
                next_ts = st.session_state.get('automonitor_next_ts')
                if st.session_state.get('automonitor_auto'):
                    if next_ts is None or now >= next_ts:
                        trigger_scan = True
                # Scan manuel
                if st.button("ðŸ”Ž Scanner la Watchlist", key="automonitor_scan_btn_main"):
                    trigger_scan = True
                    st.session_state['automonitor_manual_once'] = False
                if trigger_scan or st.session_state.get('automonitor_manual_once') or st.session_state.get('test_signal_logic'):
                    st.session_state.automonitor_status = 'Scanning'
                    results = []
                    tf_for_scan = st.session_state.current_timeframe
                    base = "http://localhost:8000"
                    # Barre de progression
                    total_sym = len(st.session_state.watchlist)
                    progress = st.progress(0, text="Scan en cours...")
                    for i, sym_scan in enumerate(st.session_state.watchlist, start=1):
                        opp = {"symbol": sym_scan, "signal": "HOLD", "confidence": 0, "confluence": 0, "reason": "", "entry_price": 0.0, "tp_price": 0.0, "sl_price": 0.0}
                        try:
                            # Trend summary
                            r = _rq.get(f"{base}/trend_summary", params={"symbol": sym_scan, "nocache": 1}, timeout=10)
                            trend = r.json() if r.status_code == 200 else {}
                            tf_data = (trend.get("trends", {}).get(tf_for_scan) or {}) if isinstance(trend, dict) else {}
                            force = int(tf_data.get("force") or 0)
                            trend_dir = (tf_data.get("trend") or "neutral").lower()
                            # Supertrend confirmation
                            stn_req = _rq.get(f"{base}/indicators/supertrend", params={"symbol": sym_scan, "timeframe": tf_for_scan, "count": 200}, timeout=10)
                            stn = stn_req.json() if stn_req.status_code == 200 else {}
                            st_dir = None
                            try:
                                st_dir = (stn.get("trend") or [])[-1]
                            except Exception:
                                st_dir = None
                            # Market Structure (BOS direction)
                            ms_req = _rq.get(f"{base}/indicators/market_structure", params={"symbol": sym_scan, "timeframe": tf_for_scan, "count": 200}, timeout=10)
                            ms = ms_req.json() if ms_req.status_code == 200 else {}
                            bos_dir = None
                            try:
                                last_bos = (ms.get("bos") or [])[-1]
                                bos_dir = (last_bos.get("direction") or "").lower()
                            except Exception:
                                bos_dir = None
                            # ALGORITHME BASÃ‰ UNIQUEMENT SUR LA PROBABILITÃ‰
                            # Calcul d'un score de probabilitÃ© unique (0-100%)
                            
                            # 1. PROBABILITÃ‰ DE BASE (Force de tendance)
                            base_probability = force  # 0-100
                            
                            # 2. BONUS PROBABILITÃ‰ - Alignement des indicateurs
                            probability_bonus = 0
                            components = []
                            
                            # Supertrend alignment
                            aligned_supertrend = (trend_dir == "bullish" and st_dir == 1) or (trend_dir == "bearish" and st_dir == -1)
                            if aligned_supertrend:
                                probability_bonus += 15
                                components.append("ST")
                            
                            # BOS alignment
                            aligned_bos = (trend_dir == "bullish" and bos_dir == "up") or (trend_dir == "bearish" and bos_dir == "down")
                            if aligned_bos:
                                probability_bonus += 10
                                components.append("BOS")
                            
                            # RSI momentum
                            rsi_val = tf_data.get("rsi")
                            try:
                                rsi_f = float(rsi_val) if rsi_val is not None else None
                            except Exception:
                                rsi_f = None
                            
                            if rsi_f is not None:
                                if trend_dir == "bullish" and 30 <= rsi_f <= 70:
                                    probability_bonus += 10
                                    components.append("RSI+")
                                elif trend_dir == "bearish" and 30 <= rsi_f <= 70:
                                    probability_bonus += 10
                                    components.append("RSI+")
                                elif trend_dir == "bullish" and rsi_f < 30:  # Survente
                                    probability_bonus += 20
                                    components.append("RSI_OS")
                                elif trend_dir == "bearish" and rsi_f > 70:  # SuralimentÃ©
                                    probability_bonus += 20
                                    components.append("RSI_OB")
                            
                            # Multi-timeframe alignment
                            try:
                                h1_dir = (trend.get("trends",{}).get("1h",{}).get("trend") or "").lower()
                                h4_dir = (trend.get("trends",{}).get("4h",{}).get("trend") or "").lower()
                                
                                mtf_alignment = 0
                                if h1_dir and h1_dir == trend_dir:
                                    mtf_alignment += 1
                                if h4_dir and h4_dir == trend_dir:
                                    mtf_alignment += 1
                                
                                probability_bonus += mtf_alignment * 5
                                if mtf_alignment > 0:
                                    components.append(f"MTF{mtf_alignment}")
                            except Exception:
                                pass
                            
                            # 3. CALCUL DE LA PROBABILITÃ‰ FINALE
                            final_probability = min(100, base_probability + probability_bonus)
                            
                            # 4. DÃ‰CISION BASÃ‰E UNIQUEMENT SUR LA PROBABILITÃ‰
                            confluence = int(final_probability)
                            confidence = confluence  # MÃªme valeur pour simplicitÃ©
                            
                            # Calculer les niveaux de prix pour TP/SL
                            try:
                                # RÃ©cupÃ©rer le prix actuel depuis l'API
                                current_price = 0
                                atr_val = 0
                                
                                try:
                                    price_req = _rq.get(f"{base}/real_time_price", params={"symbol": sym_scan}, timeout=5)
                                    if price_req.status_code == 200:
                                        price_data = price_req.json()
                                        # S'assurer que current_price est un nombre
                                        price_value = price_data.get("price", 0)
                                        if isinstance(price_value, (int, float)):
                                            current_price = float(price_value)
                                        else:
                                            current_price = 0
                                except Exception:
                                    pass
                                
                                # Si pas de prix, essayer de rÃ©cupÃ©rer depuis les donnÃ©es de tendance
                                if current_price == 0:
                                    try:
                                        # RÃ©cupÃ©rer le prix depuis les donnÃ©es de tendance
                                        trend_data = trend.get("trends", {}).get(tf_for_scan, {})
                                        if trend_data and "price" in trend_data:
                                            current_price = float(trend_data["price"])
                                        elif trend_data and "close" in trend_data:
                                            current_price = float(trend_data["close"])
                                    except Exception:
                                        pass
                                
                                # Si toujours pas de prix, utiliser une estimation basÃ©e sur le symbole
                                if current_price == 0:
                                    if "Index" in sym_scan or "Boom" in sym_scan or "Crash" in sym_scan:
                                        current_price = 1000.0  # Prix par dÃ©faut pour les indices
                                    elif "JPY" in sym_scan:
                                        current_price = 100.0  # Prix par dÃ©faut pour JPY
                                    else:
                                        current_price = 1.0  # Prix par dÃ©faut pour les autres
                                
                                # Essayer de rÃ©cupÃ©rer l'ATR depuis les donnÃ©es de tendance
                                atr_val = 0
                                try:
                                    trend_data = trend.get("trends", {}).get(tf_for_scan, {})
                                    if trend_data and "atr" in trend_data:
                                        atr_val = float(trend_data["atr"])
                                except Exception:
                                    pass
                                
                                # Si pas d'ATR, estimation basÃ©e sur le type de symbole
                                if atr_val == 0:
                                    if "Index" in sym_scan or "Boom" in sym_scan or "Crash" in sym_scan:
                                        atr_val = current_price * 0.01  # 1% du prix pour les indices
                                    elif "JPY" in sym_scan:
                                        atr_val = current_price * 0.001  # 0.1% pour JPY
                                    else:
                                        atr_val = current_price * 0.0001  # 0.01% pour les autres
                                
                                # Calculer TP et SL basÃ©s sur ATR
                                if current_price > 0 and atr_val > 0:
                                    if trend_dir == "bullish":
                                        entry_price = current_price
                                        tp_price = current_price + (atr_val * 2)  # TP Ã  2 ATR
                                        sl_price = current_price - (atr_val * 1)  # SL Ã  1 ATR
                                    elif trend_dir == "bearish":
                                        entry_price = current_price
                                        tp_price = current_price - (atr_val * 2)  # TP Ã  2 ATR
                                        sl_price = current_price + (atr_val * 1)  # SL Ã  1 ATR
                                    else:
                                        entry_price = current_price
                                        tp_price = current_price
                                        sl_price = current_price
                                else:
                                    # Debug: afficher pourquoi les prix sont Ã  0
                                    print(f"DEBUG {sym_scan}: current_price={current_price}, atr_val={atr_val}")
                                    entry_price = current_price
                                    tp_price = current_price
                                    sl_price = current_price
                            except Exception as e:
                                print(f"Erreur calcul prix pour {sym_scan}: {e}")
                                entry_price = 0
                                tp_price = 0
                                sl_price = 0

                            # LOGIQUE SIMPLE BASÃ‰E UNIQUEMENT SUR LA PROBABILITÃ‰
                            signal = "HOLD"
                            
                            # Seuil de probabilitÃ© depuis l'interface utilisateur
                            probability_threshold = st.session_state.get('probability_threshold_effective', st.session_state.get('probability_threshold', 60))
                            
                            # DÃ©cision simple : si probabilitÃ© >= seuil ET direction claire
                            if trend_dir == "bullish" and confluence >= probability_threshold:
                                signal = "BUY"
                            elif trend_dir == "bearish" and confluence >= probability_threshold:
                                signal = "SELL"
                            
                            # Debug: Afficher les dÃ©tails pour chaque symbole
                            print(f"ðŸ” DEBUG {sym_scan}: trend_dir={trend_dir}, probability={confluence}%, signal={signal}")
                            print(f"   Components: {components}")
                            print(f"   RSI: {rsi_f}, ST: {st_dir}, BOS: {bos_dir}")
                            
                            # Mise Ã  jour du rÃ©sultat
                            opp.update({
                                "signal": signal, 
                                "confidence": confidence, 
                                "confluence": confluence, 
                                "reason": f"ProbabilitÃ© {confluence}% ({'+'.join(components)})",
                                "entry_price": entry_price,
                                "tp_price": tp_price,
                                "sl_price": sl_price
                            })
                        except Exception as e:
                            opp.update({"signal": "HOLD", "confidence": 0, "confluence": 0, "reason": f"Erreur: {e}", "entry_price": 0.0, "tp_price": 0.0, "sl_price": 0.0})
                        results.append(opp)
                        # Avancement
                        progress.progress(min(100, int(i/total_sym*100)), text=f"{i}/{total_sym} Â· {sym_scan}")
                    progress.empty()
                    if results:
                        import pandas as _pd
                        df_res = _pd.DataFrame(results)
                        df_res.sort_values(["signal", "confluence"], ascending=[True, False], inplace=True)
                        st.subheader("ðŸ§­ OpportunitÃ©s Watchlist")
                        
                        # Debug: Afficher les statistiques de probabilitÃ©
                        probability_stats = df_res['confluence'].describe()
                        current_threshold = st.session_state.get('probability_threshold', 60)
                        st.caption(f"ðŸ“Š Statistiques de probabilitÃ©: Min={probability_stats['min']:.1f}%, Max={probability_stats['max']:.1f}%, Moyenne={probability_stats['mean']:.1f}% (Seuil: {current_threshold}%)")
                        
                        # Debug: Afficher la rÃ©partition des signaux
                        signal_counts = df_res['signal'].value_counts()
                        st.caption(f"ðŸ“ˆ RÃ©partition: {dict(signal_counts)}")
                        
                        # Affichage spÃ©cial pour le test de logique
                        if st.session_state.get('test_signal_logic'):
                            st.success("ðŸ§ª Test de logique des signaux terminÃ© !")
                            st.info("ðŸ’¡ Consultez la console pour voir les dÃ©tails de chaque symbole scannÃ©")
                            st.session_state['test_signal_logic'] = False
                        
                        # Afficher les signaux BUY/SELL avec format amÃ©liorÃ©
                        buy_signals = df_res[df_res['signal'].isin(['BUY', 'SELL'])]
                        hold_signals = df_res[df_res['signal'] == 'HOLD']
                        
                        # RÃ©sumÃ© des signaux
                        st.metric("ðŸ“Š RÃ©sumÃ© du scan", f"{len(buy_signals)} signaux actifs sur {len(df_res)} symboles scannÃ©s")
                        
                        if not buy_signals.empty:
                            st.success(f"ðŸŽ¯ {len(buy_signals)} signal(s) de trading dÃ©tectÃ©(s) !")
                            
                            # Envoyer les notifications WhatsApp pour les signaux
                            try:
                                from frontend.whatsapp_notify import send_whatsapp_message_unified, send_sms_vonage
                                
                                for _, signal in buy_signals.iterrows():
                                    # VÃ©rifier le cooldown (3 minutes = 180 secondes)
                                    signal_key = f"automonitor_{signal['symbol']}_{datetime.now().strftime('%H:%M')}"
                                    last_signal_ts = st.session_state.last_notifications.get(signal_key, 0)
                                    now_ts = datetime.now().timestamp()
                                    
                                    # Respecter cooldown selon mode (10m scalp, 20m swing)
                                    cooldown_sec = int(st.session_state.get('cooldown_sec', 600))
                                    if now_ts - last_signal_ts >= cooldown_sec:
                                        # Calculer l'heure d'expiration (4 heures aprÃ¨s l'Ã©mission)
                                        signal_time = datetime.now()
                                        expiration_time = signal_time + timedelta(hours=4)
                                        
                                        # RafraÃ®chir le prix en temps rÃ©el juste avant envoi
                                        refreshed_entry = None
                                        try:
                                            price_req2 = _rq.get(f"{base}/real_time_price", params={"symbol": signal['symbol']}, timeout=5)
                                            if price_req2.status_code == 200:
                                                price_data2 = price_req2.json()
                                                pv2 = price_data2.get('price')
                                                if isinstance(pv2, (int, float)) and pv2 > 0:
                                                    refreshed_entry = float(pv2)
                                        except Exception:
                                            refreshed_entry = None
                                        if refreshed_entry is None:
                                            try:
                                                info2 = get_symbol_info(signal['symbol'])
                                                bid2 = info2.get('bid') if isinstance(info2, dict) else getattr(info2, 'bid', None)
                                                ask2 = info2.get('ask') if isinstance(info2, dict) else getattr(info2, 'ask', None)
                                                if isinstance(bid2, (int,float)) and isinstance(ask2, (int,float)) and bid2>0 and ask2>0:
                                                    refreshed_entry = (bid2 + ask2) / 2.0
                                            except Exception:
                                                refreshed_entry = None
                                        entry_for_msg = float(signal.get('entry_price') or 0.0)
                                        tp_for_msg = float(signal.get('tp_price') or entry_for_msg)
                                        sl_for_msg = float(signal.get('sl_price') or entry_for_msg)
                                        if isinstance(refreshed_entry, float) and refreshed_entry > 0:
                                            try:
                                                dtp = tp_for_msg - entry_for_msg
                                                dsl = sl_for_msg - entry_for_msg
                                                entry_for_msg = refreshed_entry
                                                tp_for_msg = refreshed_entry + dtp
                                                sl_for_msg = refreshed_entry + dsl
                                            except Exception:
                                                pass

                                        # VÃ©rifier Risk/Reward minimal selon mode
                                        rr_min = float(st.session_state.get('rr_min', 2.0))
                                        rr = 0.0
                                        try:
                                            risk = abs(entry_for_msg - sl_for_msg)
                                            reward = abs(tp_for_msg - entry_for_msg)
                                            rr = (reward / risk) if risk > 0 else 0.0
                                        except Exception:
                                            rr = 0.0
                                        if rr < rr_min:
                                            # Ne pas envoyer si RR insuffisant
                                            print(f"â›” RR insuffisant ({rr:.2f} < {rr_min:.2f}) pour {signal['symbol']}")
                                            continue
                                        
                                        # Format du message WhatsApp
                                        signal_emoji = "ðŸŸ¢" if signal['signal'] == 'BUY' else "ðŸ”´"
                                        whatsapp_text = f"""{signal_emoji} SIGNAL {signal['signal']} {signal['symbol']}
ðŸ“Š Timeframe: {tf_for_scan}
ðŸŽ¯ Confluence: {signal['confluence']}%
ðŸ’ª Confiance: {signal['confidence']}%
ðŸ’° Prix d'entrÃ©e: {entry_for_msg:.5f}
ðŸŽ¯ Take Profit: {tp_for_msg:.5f}
ðŸ›¡ï¸ Stop Loss: {sl_for_msg:.5f}
ðŸ“ Raison: {signal['reason']}
â° Ã‰mis: {signal_time.strftime('%H:%M:%S')}
â³ Expire: {expiration_time.strftime('%H:%M:%S')}"""
                                        
                                        # Envoi WhatsApp
                                        if st.session_state.get('notify_whatsapp', True):
                                            try:
                                                result_wa = send_whatsapp_message_unified(whatsapp_text)
                                                # ConsidÃ©rer succÃ¨s si True ou dict sans error
                                                is_success = False
                                                if result_wa is True:
                                                    is_success = True
                                                elif isinstance(result_wa, dict) and result_wa.get('status') not in ['error','failed']:
                                                    is_success = True
                                                if is_success:
                                                    st.success(f"ðŸ“± WhatsApp envoyÃ©: {signal['symbol']}")
                                                    print(f"âœ… WhatsApp envoyÃ© pour {signal['symbol']}: {whatsapp_text}")
                                                else:
                                                    print(f"âŒ Ã‰chec WhatsApp pour {signal['symbol']}: {result_wa}")
                                            except Exception as e:
                                                st.error(f"âŒ Erreur WhatsApp {signal['symbol']}: {e}")
                                                print(f"âŒ Exception WhatsApp {signal['symbol']}: {e}")
                                        
                                        # Envoi SMS
                                        if st.session_state.get('notify_sms'):
                                            try:
                                                sms_text = f"""{signal_emoji} {signal['signal']} {signal['symbol']}
                                            except Exception as e:
                                                pass
â° {datetime.now().strftime('%H:%M')}
ðŸŽ¯ {signal['confluence']}% confluence
ðŸ’° EntrÃ©e: {signal.get('entry_price', 0):.5f}
ðŸŽ¯ TP: {signal.get('tp_price', 0):.5f}
ðŸ›¡ï¸ SL: {signal.get('sl_price', 0):.5f}"""
                                                
                                                result_sms = send_sms_vonage(sms_text)
                                                if result_sms and result_sms.get('messages', [{}])[0].get('status') == '0':
                                                    st.success(f"ðŸ“± SMS envoyÃ©: {signal['symbol']}")
                                            except Exception as e:
                                                st.error(f"âŒ Erreur SMS {signal['symbol']}: {e}")
                                        
                                        # Mettre Ã  jour le timestamp
                                        st.session_state.last_notifications[signal_key] = now_ts
                            except Exception as e:
                                st.error(f"âŒ Erreur notifications: {e}")
                            
                            # Afficher les signaux dans des colonnes
                            cols = st.columns(min(2, len(buy_signals)))
                            for idx, (_, signal) in enumerate(buy_signals.iterrows()):
                                with cols[idx % 2]:
                                    signal_emoji = "ðŸŸ¢" if signal['signal'] == 'BUY' else "ðŸ”´"
                                    signal_time = datetime.now()
                                    expiration_time = signal_time + timedelta(hours=4)
                                    
                                    st.markdown(f"""
                                    <div style="border: 2px solid {'#00ff00' if signal['signal'] == 'BUY' else '#ff0000'}; padding: 10px; border-radius: 8px; margin: 5px 0;">
                                        <h4>{signal_emoji} {signal['signal']} {signal['symbol']}</h4>
                                        <p><strong>ðŸ“Š Timeframe:</strong> {tf_for_scan}</p>
                                        <p><strong>ðŸŽ¯ ProbabilitÃ©:</strong> {signal['confluence']}%</p>
                                        <p><strong>ðŸ’ª Confiance:</strong> {signal['confidence']}%</p>
                                        <p><strong>ðŸ’° EntrÃ©e:</strong> {signal.get('entry_price', 0):.5f}</p>
                                        <p><strong>ðŸŽ¯ TP:</strong> {signal.get('tp_price', 0):.5f}</p>
                                        <p><strong>ðŸ›¡ï¸ SL:</strong> {signal.get('sl_price', 0):.5f}</p>
                                        <p><strong>ðŸ“ Raison:</strong> {signal['reason']}</p>
                                        <p><strong>â° Ã‰mis:</strong> {signal_time.strftime('%H:%M:%S')}</p>
                                        <p><strong>â³ Expire:</strong> {expiration_time.strftime('%H:%M:%S')}</p>
                                    </div>
                                    """, unsafe_allow_html=True)
                        else:
                            st.info("â„¹ï¸ Aucun signal de trading dÃ©tectÃ©. Tous les symboles sont en HOLD.")
                        
                        # Afficher le tableau complet avec filtres
                        st.subheader("ðŸ“‹ Tableau dÃ©taillÃ©")
                        
                        # Filtres pour le tableau
                        col_filter1, col_filter2 = st.columns(2)
                        with col_filter1:
                            signal_filter = st.selectbox("Filtrer par signal", ["Tous", "BUY", "SELL", "HOLD"], key="signal_filter")
                        with col_filter2:
                            min_confluence = st.slider("ProbabilitÃ© minimum", 0, 100, 0, key="min_confluence")
                        
                        # Appliquer les filtres
                        filtered_df = df_res.copy()
                        if signal_filter != "Tous":
                            filtered_df = filtered_df[filtered_df['signal'] == signal_filter]
                        filtered_df = filtered_df[filtered_df['confluence'] >= min_confluence]
                        
                        # Afficher le tableau filtrÃ©
                        if not filtered_df.empty:
                            # S'assurer que toutes les colonnes nÃ©cessaires existent
                            required_columns = ['symbol', 'signal', 'confluence', 'confidence', 'entry_price', 'tp_price', 'sl_price', 'reason']
                            for col in required_columns:
                                if col not in filtered_df.columns:
                                    filtered_df[col] = 0.0 if 'price' in col else ('N/A' if col == 'reason' else 0)
                            
                            st.dataframe(
                                filtered_df[required_columns], 
                                hide_index=True, 
                                use_container_width=True,
                                column_config={
                                    "symbol": "Symbole",
                                    "signal": "Signal",
                                    "confluence": st.column_config.NumberColumn("ProbabilitÃ© %", format="%.0f"),
                                    "confidence": st.column_config.NumberColumn("Confiance %", format="%.0f"),
                                    "entry_price": st.column_config.NumberColumn("Prix EntrÃ©e", format="%.5f"),
                                    "tp_price": st.column_config.NumberColumn("Take Profit", format="%.5f"),
                                    "sl_price": st.column_config.NumberColumn("Stop Loss", format="%.5f"),
                                    "reason": "Raison"
                                }
                        )
            else:
                st.info("Aucun rÃ©sultat ne correspond aux filtres sÃ©lectionnÃ©s.")
        except Exception as e:
            st.error(f"Erreur dans l'AutoMonitor : {e}")

# Section supprimÃ©e - Alertes Spike dÃ©sactivÃ©es
        
        # Section spÃ©ciale pour les indices synthÃ©tiques
        if symbol and ('Boom' in symbol or 'Crash' in symbol or 'Volatility' in symbol):
            st.subheader("ðŸŽ¯ Analyse Indices SynthÃ©tiques")
            
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.info("**ðŸ”¥ BOOM/CRASH**")
                st.write("â€¢ VolatilitÃ© extrÃªme")
                st.write("â€¢ Mouvements rapides")
                st.write("â€¢ Risque Ã©levÃ©")
            
            with col2:
                st.warning("**âš ï¸ RÃˆGLES STRICTES**")
                st.write("â€¢ SL: 5-10 points max")
                st.write("â€¢ TP: 15-25 points")
                st.write("â€¢ Max 3 trades/jour")
            
            with col3:
                st.success("**ðŸ“Š SIGNALS**")
                if not st.session_state.real_time_data.empty:
                    # Calculer les signaux spÃ©cifiques
                    if 'rsi' in st.session_state.real_time_data.columns:
                        rsi_val = st.session_state.real_time_data['rsi'].iloc[-1]
                        if rsi_val < 30:
                            st.error("ðŸŸ¢ SIGNAL ACHAT (RSI < 30)")
                        elif rsi_val > 70:
                            st.error("ðŸ”´ SIGNAL VENTE (RSI > 70)")
                        else:
                            st.info("âšª ATTENDRE")
                    else:
                        st.info("Calcul en cours...")
        
        # Analyse technique en temps rÃ©el
        st.subheader("ðŸ” Analyse Technique")
        
        # Debug: afficher les colonnes disponibles
        if not st.session_state.real_time_data.empty:
            available_cols = [col for col in st.session_state.real_time_data.columns if any(indicator in col.lower() for indicator in ['rsi', 'macd', 'bb'])]
            if available_cols:
                st.info(f"ðŸ“Š Colonnes techniques disponibles: {', '.join(available_cols)}")
        
        col1, col2 = st.columns(2)
        
        with col1:
            # Essayer diffÃ©rentes colonnes RSI possibles
            rsi_value = None
            for rsi_col in ['RSI', 'rsi', 'rsi_14']:
                if rsi_col in st.session_state.real_time_data.columns and len(st.session_state.real_time_data) >= 14:
                    rsi_value = st.session_state.real_time_data[rsi_col].iloc[-1]
                    break
            
            if rsi_value is not None and not pd.isna(rsi_value):
                st.metric("RSI", f"{rsi_value:.2f}")
                
                if rsi_value > 70:
                    st.warning("ðŸ“ˆ SuralimentÃ© (RSI > 70)")
                elif rsi_value < 30:
                    st.info("ðŸ“‰ Survente (RSI < 30)")
                else:
                    st.success("âœ… RSI normal")
            else:
                st.metric("RSI", "N/A")
        
        with col2:
            # Essayer diffÃ©rentes colonnes MACD possibles
            macd_value = None
            macd_signal_value = None
            
            # Chercher les colonnes MACD
            for macd_col in ['MACD', 'macd']:
                if macd_col in st.session_state.real_time_data.columns:
                    macd_value = st.session_state.real_time_data[macd_col].iloc[-1]
                    break
            
            # Chercher les colonnes MACD Signal
            for signal_col in ['MACD_Signal', 'macd_signal']:
                if signal_col in st.session_state.real_time_data.columns:
                    macd_signal_value = st.session_state.real_time_data[signal_col].iloc[-1]
                    break
            
            if (macd_value is not None and not pd.isna(macd_value) and 
                macd_signal_value is not None and not pd.isna(macd_signal_value)):
                st.metric("MACD", f"{macd_value:.5f}")
                st.metric("Signal", f"{macd_signal_value:.5f}")
                
                if macd_value > macd_signal_value:
                    st.success("ðŸ“ˆ Signal haussier")
                else:
                    st.error("ðŸ“‰ Signal baissier")
            else:
                st.metric("MACD", "N/A")
                st.metric("Signal", "N/A")
        
        # PrÃ©dictions de spikes (flÃ¨ches) â€“ configurable
        with st.expander("ðŸš€ PrÃ©dictions de Spikes (arrows)", expanded=False):
            if 'show_spike_predictions' not in st.session_state:
                st.session_state['show_spike_predictions'] = True
            _show_spikes = st.checkbox(
                "Afficher les prÃ©dictions de spikes (flÃ¨ches)", value=st.session_state['show_spike_predictions'], key="show_spike_predictions"
            )
            _ = st.slider(
                "Seuil de confiance spike (%)", min_value=60, max_value=99, value=st.session_state.get('spike_threshold', 85), step=1, key="spike_threshold_slider"
            )
            # Ultra-sensible + filtre min pips
            if 'spike_ultra_sensitive' not in st.session_state:
                st.session_state['spike_ultra_sensitive'] = False
            if 'spike_min_pips' not in st.session_state:
                st.session_state['spike_min_pips'] = 2
            st.checkbox("Mode ultra-sensible (dÃ©tection micro-spikes)", value=st.session_state['spike_ultra_sensitive'], key="spike_ultra_sensitive")
            st.slider("Taille minimale (pips)", min_value=0, max_value=20, value=int(st.session_state['spike_min_pips']), step=1, key="spike_min_pips")
        
        # Boutons de contrÃ´le
        col1, col2 = st.columns(2)
        
        with col1:
            if st.button("ðŸ”„ Mettre Ã  jour maintenant"):
                update_real_time_data()
                st.rerun()
        
        with col2:
            if st.button("ðŸ¤– EntraÃ®ner ML") and len(st.session_state.real_time_data) >= 100:
                with st.spinner("ðŸ¤– EntraÃ®nement des modÃ¨les ML..."):
                    try:
                        st.session_state.ml_predictor.train_models(st.session_state.real_time_data)
                        st.success("âœ… ModÃ¨les ML entraÃ®nÃ©s avec succÃ¨s!")
                        st.rerun()
                    except Exception as e:
                        st.error(f"âŒ Erreur lors de l'entraÃ®nement: {e}")
            elif len(st.session_state.real_time_data) < 100:
                st.button("ðŸ¤– EntraÃ®ner ML", disabled=True, help=f"Besoin de 100 bougies (actuellement: {len(st.session_state.real_time_data)})")
        
        # Ã‰tat des modÃ¨les ML
        if len(st.session_state.real_time_data) >= 50:
            st.subheader("ðŸ¤– Ã‰tat des ModÃ¨les ML")
            
            col1, col2, col3 = st.columns(3)
            
            with col1:
                if st.session_state.ml_predictor.is_trained:
                    st.success("âœ… ModÃ¨les ML entraÃ®nÃ©s")
                else:
                    st.warning("âš ï¸ ModÃ¨les ML non entraÃ®nÃ©s")
            
            with col2:
                st.info(f"ðŸ“Š DonnÃ©es disponibles: {len(st.session_state.real_time_data)} bougies")
            
            with col3:
                if len(st.session_state.real_time_data) >= 100:
                    st.success("âœ… Suffisamment de donnÃ©es pour l'entraÃ®nement")
                else:
                    st.warning(f"âš ï¸ Besoin de {100 - len(st.session_state.real_time_data)} bougies supplÃ©mentaires")
        
        # Signaux ML avancÃ©s et setups de trading
        if len(st.session_state.real_time_data) >= 50:
            st.subheader("ðŸ¤– Signaux ML AvancÃ©s & Setups de Trading")
            
            try:
                # DÃ©tecter les setups d'abord
                setups = st.session_state.setup_detector.detect_all_setups(st.session_state.real_time_data)
                
                # GÃ©nÃ©rer les signaux ML (avec gestion d'erreur si pas entraÃ®nÃ©)
                try:
                    ml_signals = st.session_state.ml_predictor.get_trading_signals(st.session_state.real_time_data)
                except ValueError as e:
                    if "doivent Ãªtre entraÃ®nÃ©s" in str(e):
                        # Essayer d'entraÃ®ner les modÃ¨les si on a assez de donnÃ©es
                        if len(st.session_state.real_time_data) >= 100:
                            with st.spinner("ðŸ¤– EntraÃ®nement des modÃ¨les ML en cours..."):
                                try:
                                    st.session_state.ml_predictor.train_models(st.session_state.real_time_data)
                                    ml_signals = st.session_state.ml_predictor.get_trading_signals(st.session_state.real_time_data)
                                    st.success("âœ… ModÃ¨les ML entraÃ®nÃ©s avec succÃ¨s!")
                                except Exception as train_error:
                                    st.warning(f"âš ï¸ Erreur lors de l'entraÃ®nement: {train_error}")
                                    # Utiliser des signaux basiques en cas d'erreur
                                    ml_signals = {
                                        'overall_signal': 'HOLD',
                                        'spike': 'LOW_SPIKE_RISK',
                                        'spike_strength': 0.3,
                                        'breakout': 'NO_BREAKOUT',
                                        'breakout_strength': 0.4,
                                        'amplitude': 'LOW_VOLATILITY',
                                        'amplitude_strength': 0.3
                                    }
                        else:
                            # Pas assez de donnÃ©es pour l'entraÃ®nement, utiliser des signaux basiques
                            ml_signals = {
                                'overall_signal': 'HOLD',
                                'spike': 'LOW_SPIKE_RISK',
                                'spike_strength': 0.3,
                                'breakout': 'NO_BREAKOUT',
                                'breakout_strength': 0.4,
                                'amplitude': 'LOW_VOLATILITY',
                                'amplitude_strength': 0.3
                            }
                            st.info(f"ðŸ¤– Collecte de donnÃ©es en cours... ({len(st.session_state.real_time_data)}/100 bougies pour l'entraÃ®nement ML)")
                    else:
                        raise e
                
                # Afficher les signaux principaux
                col1, col2, col3, col4 = st.columns(4)
                
                with col1:
                    signal = ml_signals.get('overall_signal', 'HOLD')
                    if signal == 'STRONG_BUY':
                        st.success("ðŸŸ¢ **STRONG BUY**")
                    elif signal == 'BUY':
                        st.success("ðŸŸ¢ **BUY**")
                    elif signal == 'SELL':
                        st.error("ðŸ”´ **SELL**")
                    elif signal == 'STRONG_SELL':
                        st.error("ðŸ”´ **STRONG SELL**")
                    elif signal == 'SPIKE_WARNING':
                        st.warning("âš ï¸ **SPIKE WARNING**")
                    else:
                        st.info("âšª **HOLD**")
                
                with col2:
                    spike_risk = ml_signals.get('spike', 'LOW_SPIKE_RISK')
                    spike_strength = ml_signals.get('spike_strength', 0.5)
                    if spike_risk == 'HIGH_SPIKE_RISK':
                        st.error(f"ðŸš¨ **HIGH SPIKE RISK** ({spike_strength:.1%})")
                    elif spike_risk == 'MEDIUM_SPIKE_RISK':
                        st.warning(f"âš ï¸ **MEDIUM SPIKE RISK** ({spike_strength:.1%})")
                    else:
                        st.success(f"âœ… **LOW SPIKE RISK** ({spike_strength:.1%})")
                
                with col3:
                    breakout = ml_signals.get('breakout', 'NO_BREAKOUT')
                    breakout_strength = ml_signals.get('breakout_strength', 0.5)
                    if breakout == 'BREAKOUT_LIKELY':
                        st.warning(f"ðŸ“ˆ **BREAKOUT LIKELY** ({breakout_strength:.1%})")
                    else:
                        st.info(f"ðŸ“Š **NO BREAKOUT** ({breakout_strength:.1%})")
                
                with col4:
                    amplitude = ml_signals.get('amplitude', 'LOW_VOLATILITY')
                    amplitude_strength = ml_signals.get('amplitude_strength', 0.5)
                    if amplitude == 'HIGH_VOLATILITY':
                        st.warning(f"ðŸ“Š **HIGH VOLATILITY** ({amplitude_strength:.1%})")
                    else:
                        st.info(f"ðŸ“‰ **LOW VOLATILITY** ({amplitude_strength:.1%})")
                
                # Afficher les dÃ©tails des setups
                with st.expander("ðŸ“Š DÃ©tails des Setups de Trading"):
                    col1, col2 = st.columns(2)
                    
                    with col1:
                        st.write("**ðŸŽ¯ Signaux Techniques:**")
                        
                        # Moving Average
                        ma_setup = setups.get('moving_average', {})
                        if ma_setup.get('current_trend') == 1:
                            st.success(f"ðŸ“ˆ MA Crossover: BULLISH (Force: {ma_setup.get('strength', 0):.3f})")
                        elif ma_setup.get('current_trend') == -1:
                            st.error(f"ðŸ“‰ MA Crossover: BEARISH (Force: {ma_setup.get('strength', 0):.3f})")
                        else:
                            st.info("ðŸ“Š MA Crossover: NEUTRAL")
                        
                        # RSI
                        rsi_setup = setups.get('rsi', {})
                        rsi_value = rsi_setup.get('current_rsi', 50)
                        if rsi_value < 30:
                            st.success(f"ðŸ“ˆ RSI: OVERSOLD ({rsi_value:.1f})")
                        elif rsi_value > 70:
                            st.error(f"ðŸ“‰ RSI: OVERBOUGHT ({rsi_value:.1f})")
                        else:
                            st.info(f"ðŸ“Š RSI: NEUTRAL ({rsi_value:.1f})")
                        
                        # MACD
                        macd_setup = setups.get('macd', {})
                        macd_signal = macd_setup.get('signal', 'HOLD')
                        if macd_signal == 'BUY':
                            st.success("ðŸ“ˆ MACD: BULLISH")
                        elif macd_signal == 'SELL':
                            st.error("ðŸ“‰ MACD: BEARISH")
                        else:
                            st.info("ðŸ“Š MACD: NEUTRAL")
                    
                    with col2:
                        st.write("**ðŸŽ¯ Signaux de Breakout:**")
                        
                        # Bollinger Bands
                        bb_setup = setups.get('bollinger_bands', {})
                        bb_position = bb_setup.get('current_bb_position', 0.5)
                        if bb_position < 0.2:
                            st.success(f"ðŸ“ˆ BB: OVERSOLD ({bb_position:.2f})")
                        elif bb_position > 0.8:
                            st.error(f"ðŸ“‰ BB: OVERBOUGHT ({bb_position:.2f})")
                        else:
                            st.info(f"ðŸ“Š BB: NEUTRAL ({bb_position:.2f})")
                        
                        # Donchian Channels
                        donchian_setup = setups.get('donchian_channels', {})
                        donchian_position = donchian_setup.get('current_position', 0.5)
                        if donchian_position > 0.8:
                            st.warning(f"ðŸ“ˆ Donchian: NEAR BREAKOUT ({donchian_position:.2f})")
                        elif donchian_position < 0.2:
                            st.warning(f"ðŸ“‰ Donchian: NEAR BREAKDOWN ({donchian_position:.2f})")
                        else:
                            st.info(f"ðŸ“Š Donchian: NEUTRAL ({donchian_position:.2f})")
                        
                        # Stochastic
                        stoch_setup = setups.get('stochastic', {})
                        stoch_k = stoch_setup.get('current_k', 50)
                        if stoch_k < 20:
                            st.success(f"ðŸ“ˆ Stochastic: OVERSOLD ({stoch_k:.1f})")
                        elif stoch_k > 80:
                            st.error(f"ðŸ“‰ Stochastic: OVERBOUGHT ({stoch_k:.1f})")
                        else:
                            st.info(f"ðŸ“Š Stochastic: NEUTRAL ({stoch_k:.1f})")
                        
                # Boom/Crash Momentum (nouveau)
                momentum_setup = setups.get('boom_crash_momentum', {})
                momentum_signal = momentum_setup.get('signal', 'HOLD')
                momentum_strength = momentum_setup.get('strength', 0.5)
                is_spike = momentum_setup.get('is_spike', False)
                spike_direction = momentum_setup.get('spike_direction', 'NONE')

                if momentum_signal == 'BUY':
                    if is_spike:
                        st.success(f"ðŸš€ SPIKE UP DETECTED! ({spike_direction}) - Force: {momentum_strength:.2f}")
                    else:
                        st.success(f"ðŸ“ˆ Momentum: BULLISH - Force: {momentum_strength:.2f}")
                elif momentum_signal == 'SELL':
                    if is_spike:
                        st.error(f"ðŸ’¥ SPIKE DOWN DETECTED! ({spike_direction}) - Force: {momentum_strength:.2f}")
                    else:
                        st.error(f"ðŸ“‰ Momentum: BEARISH - Force: {momentum_strength:.2f}")
                else:
                    st.info(f"ðŸ“Š Momentum: NEUTRAL - Force: {momentum_strength:.2f}")
                
                # PrÃ©diction avancÃ©e des spikes supprimÃ©e
                
                # Recommandations de trading
                recommendations = st.session_state.setup_detector.get_trading_recommendations(st.session_state.real_time_data)
                
                with st.expander("ðŸ’¡ Recommandations de Trading"):
                    st.write(f"**Action recommandÃ©e:** {recommendations['action']}")
                    st.write(f"**Confiance:** {recommendations['confidence']:.1%}")
                    st.write(f"**Score composite:** {recommendations['score']}")
                    
                    if recommendations['entry_strategy'] != 'N/A':
                        st.write(f"**StratÃ©gie d'entrÃ©e:** {recommendations['entry_strategy']}")
                        st.write(f"**Stop Loss:** {recommendations['stop_loss']}")
                        st.write(f"**Take Profit:** {recommendations['take_profit']}")
                    
                    st.write("**Signaux dÃ©tectÃ©s:**")
                    for signal in recommendations['signals']:
                        st.write(f"â€¢ {signal}")
                
            except Exception as e:
                st.error(f"Erreur lors de la gÃ©nÃ©ration des signaux ML: {e}")
        else:
            st.info("Collecte de donnÃ©es en cours... (minimum 50 bougies requis pour l'analyse ML)")
        
        # Section spÃ©ciale pour les indices synthÃ©tiques Boom/Crash
        if symbol and any(indice in symbol for indice in ['Boom', 'Crash', 'Volatility']):
            st.subheader("ðŸŽ¯ StratÃ©gies SpÃ©cialisÃ©es - Indices SynthÃ©tiques")
            
            try:
                # Analyser les donnÃ©es pour les indices synthÃ©tiques
                if len(st.session_state.real_time_data) >= 20:
                    # DÃ©tecter les setups si pas dÃ©jÃ  fait
                    if 'setups' not in locals():
                        setups = st.session_state.setup_detector.detect_all_setups(st.session_state.real_time_data)
                    # Calculer les mÃ©triques spÃ©cifiques aux indices synthÃ©tiques
                    current_price = st.session_state.real_time_data['close'].iloc[-1]
                    volatility = st.session_state.real_time_data['close'].pct_change().std() * 100
                    
                    # DÃ©tecter les patterns de spike
                    price_changes = st.session_state.real_time_data['close'].pct_change().abs()
                    recent_volatility = price_changes.tail(10).mean() * 100
                    
                    col1, col2, col3 = st.columns(3)
                    
                    with col1:
                        st.metric("ðŸ“Š VolatilitÃ© Actuelle", f"{recent_volatility:.2f}%")
                        if recent_volatility > 2:
                            st.warning("âš ï¸ VolatilitÃ© Ã©levÃ©e - Risque de spike")
                        elif recent_volatility < 0.5:
                            st.info("ðŸ“‰ VolatilitÃ© faible - Range trading possible")
                        else:
                            st.success("âœ… VolatilitÃ© normale")
                    
                    with col2:
                        # DÃ©tecter les patterns de Boom/Crash
                        if 'Boom' in symbol:
                            st.write("ðŸš€ **BOOM INDEX**")
                            # StratÃ©gie pour Boom
                            if recent_volatility > 1.5:
                                st.success("ðŸ“ˆ Signal BOOM - PrÃªt pour une explosion")
                                st.write("**StratÃ©gie:** Attendre un pullback vers support")
                            else:
                                st.info("â³ Attendre l'accumulation")
                        elif 'Crash' in symbol:
                            st.write("ðŸ’¥ **CRASH INDEX**")
                            # StratÃ©gie pour Crash
                            if recent_volatility > 1.5:
                                st.error("ðŸ“‰ Signal CRASH - PrÃªt pour une chute")
                                st.write("**StratÃ©gie:** Attendre un pullback vers rÃ©sistance")
                            else:
                                st.info("â³ Attendre la distribution")
                        else:
                            st.write("ðŸ“Š **VOLATILITY INDEX**")
                            # StratÃ©gie pour Volatility
                            if recent_volatility > 2:
                                st.warning("ðŸ“Š VolatilitÃ© extrÃªme - Trading dangereux")
                            else:
                                st.success("âœ… VolatilitÃ© contrÃ´lÃ©e - Trading possible")
                    
                    with col3:
                        # Recommandations de gestion de risque
                        risk_summary = st.session_state.risk_manager.get_risk_summary()
                        
                        st.write("ðŸ›¡ï¸ **Gestion de Risque**")
                        if risk_summary['can_trade']:
                            st.success("âœ… Trading autorisÃ©")
                        else:
                            st.error("âŒ Trading suspendu")
                        
                        st.write(f"**Pertes consÃ©cutives:** {risk_summary['consecutive_losses']}")
                        st.write(f"**Risque quotidien:** {risk_summary['daily_risk_used']:.1f}%")
                    
                    # StratÃ©gies spÃ©cifiques selon le type d'indice
                    with st.expander("ðŸŽ¯ StratÃ©gies DÃ©taillÃ©es"):
                        if 'Boom' in symbol:
                            st.write("**ðŸš€ StratÃ©gie BOOM Index:**")
                            st.write("1. **EntrÃ©e:** RSI < 30 + prix sur support")
                            st.write("2. **Stop Loss:** 5 points maximum")
                            st.write("3. **Take Profit:** 15 points (ratio 1:3)")
                            st.write("4. **Timing:** Ã‰viter les heures de faible volatilitÃ©")
                            
                        elif 'Crash' in symbol:
                            st.write("**ðŸ’¥ StratÃ©gie CRASH Index:**")
                            st.write("1. **EntrÃ©e:** RSI > 70 + prix sur rÃ©sistance")
                            st.write("2. **Stop Loss:** 5 points maximum")
                            st.write("3. **Take Profit:** 15 points (ratio 1:3)")
                            st.write("4. **Timing:** Ã‰viter les heures de faible volatilitÃ©")
                            
                        else:
                            st.write("**ðŸ“Š StratÃ©gie VOLATILITY Index:**")
                            st.write("1. **EntrÃ©e:** Breakout des bandes de Bollinger")
                            st.write("2. **Stop Loss:** 2x ATR")
                            st.write("3. **Take Profit:** 3x ATR (ratio 1:1.5)")
                            st.write("4. **Timing:** Trading 24/7 possible")
                    
                    # Alertes de trading
                    with st.expander("ðŸš¨ Alertes de Trading"):
                        # VÃ©rifier les conditions d'alerte
                        alerts = []
                        
                        # Alerte RSI
                        rsi_setup = setups.get('rsi', {})
                        rsi_value = rsi_setup.get('current_rsi', 50)
                        if rsi_value < 30:
                            alerts.append("ðŸŸ¢ RSI OVERSOLD - Signal d'achat")
                        elif rsi_value > 70:
                            alerts.append("ðŸ”´ RSI OVERBOUGHT - Signal de vente")
                        
                        # Alerte volatilitÃ©
                        if recent_volatility > 3:
                            alerts.append("âš ï¸ VOLATILITÃ‰ EXTRÃŠME - Risque Ã©levÃ©")
                        elif recent_volatility < 0.3:
                            alerts.append("ðŸ“‰ VOLATILITÃ‰ FAIBLE - Range trading")
                        
                        # Alerte breakout
                        bb_setup = setups.get('bollinger_bands', {})
                        bb_position = bb_setup.get('current_bb_position', 0.5)
                        if bb_position < 0.1:
                            alerts.append("ðŸ“ˆ PRÃˆS DU SUPPORT - Signal d'achat")
                        elif bb_position > 0.9:
                            alerts.append("ðŸ“‰ PRÃˆS DE LA RÃ‰SISTANCE - Signal de vente")
                        
                        if alerts:
                            for alert in alerts:
                                st.warning(alert)
                        else:
                            st.info("Aucune alerte active")
                    
                    # Calculer les niveaux de support/rÃ©sistance
                    if len(st.session_state.real_time_data) >= 50:
                        support_resistance = st.session_state.setup_detector.detect_support_resistance_zones(st.session_state.real_time_data)
                        
                        # Ajouter le tableau de tendance multi-timeframe
                        with st.expander("ðŸ“ˆ Analyse de Tendance Multi-Timeframe"):
                            try:
                                import requests
                                trend_api_url = f"http://localhost:8000/trend_summary?symbol={selected_symbol}&nocache=1"
                                trend_response = requests.get(trend_api_url, timeout=15)
                                
                                if trend_response.status_code == 200:
                                    trend_data = trend_response.json()
                                    
                                    # CrÃ©er le tableau de tendance
                                    tf_order = ["1d", "8h", "6h", "4h", "1h", "30m", "15m", "5m", "1m"]
                                    tf_labels = ["D1", "H8", "H6", "H4", "H1", "M30", "M15", "M5", "M1"]
                                    
                                    # PrÃ©parer les donnÃ©es pour le tableau
                                    trend_table_data = []
                                    for tf in tf_order:
                                        tf_info = trend_data.get("trends", {}).get(tf, {})
                                        trend = (tf_info.get("trend") or "neutral").lower()
                                        force = tf_info.get("force")
                                        slope = tf_info.get("slope")
                                        rsi = tf_info.get("rsi")
                                        macd = tf_info.get("macd")
                                        
                                        # Formatage des valeurs
                                        # La force renvoyÃ©e par l'API est sur 0-100 â†’ afficher en % entier
                                        # Normalisation valeurs par dÃ©faut
                                        try:
                                            force_val = int(force) if isinstance(force, (int, float)) else 0
                                        except Exception:
                                            force_val = 0
                                        force_str = f"{force_val}%"
                                        slope_val = float(slope) if isinstance(slope, (int, float)) else 0.0
                                        slope_str = f"{slope_val:.4f}"
                                        rsi_val = float(rsi) if isinstance(rsi, (int, float)) else 50.0
                                        rsi_str = f"{rsi_val:.1f}"
                                        macd_val = float(macd) if isinstance(macd, (int, float)) else 0.0
                                        macd_str = f"{macd_val:.4f}"
                                        
                                        # Couleur selon la tendance
                                        if trend == "bullish":
                                            trend_emoji = "ðŸŸ¢"
                                            trend_color = "green"
                                        elif trend == "bearish":
                                            trend_emoji = "ðŸ”´"
                                            trend_color = "red"
                                        elif trend == "neutral":
                                            trend_emoji = "âšª"
                                            trend_color = "gray"
                                        else:
                                            trend_emoji = "â“"
                                            trend_color = "lightgray"
                                        
                                        trend_table_data.append({
                                            "Timeframe": tf_labels[tf_order.index(tf)],
                                            "Tendance": f"{trend_emoji} {trend.upper()}",
                                            "Force": force_str,
                                            "Slope MA20": slope_str,
                                            "RSI": rsi_str,
                                            "MACD": macd_str
                                        })
                                    
                                    # Afficher le tableau
                                    import pandas as pd
                                    trend_df = pd.DataFrame(trend_table_data)
                                    st.dataframe(
                                        trend_df,
                                        use_container_width=True,
                                        hide_index=True
                                    )
                                    
                                    # (DemandÃ©) Ne pas afficher la synthÃ¨se globale; focus sur l'analyse par timeframe uniquement
                                
                                else:
                                    st.error(f"âŒ Erreur API: {trend_response.status_code}")
                                    
                            except requests.exceptions.RequestException as e:
                                st.error(f"âŒ Impossible de se connecter Ã  l'API de tendance: {str(e)}")
                                st.info("ðŸ’¡ Assurez-vous que l'API de tendance est dÃ©marrÃ©e sur le port 8000")
                            except Exception as e:
                                st.error(f"âŒ Erreur lors de l'analyse de tendance: {str(e)}")

                        # Chat IA dÃ©sactivÃ© pour Ã©viter les problÃ¨mes de mÃ©moire
                        with st.expander("ðŸ¤– Chat Trading IA (DÃ©sactivÃ©)", expanded=False):
                            st.info("ðŸš« Le chat IA est temporairement dÃ©sactivÃ© pour Ã©viter les problÃ¨mes de mÃ©moire.")
                            st.caption("Cette fonctionnalitÃ© sera rÃ©activÃ©e dans une version future optimisÃ©e.")
                            
                            # Interface de chat simplifiÃ©e sans Gemma
                            st.subheader("ðŸ’¬ Chat Trading (Mode Simple)")
                            st.text_area("Votre question:", key="chat_input", height=100, placeholder="Posez votre question sur le trading...")
                            
                            if st.button("Envoyer", key="chat_send_btn"):
                                st.info("ðŸ’¡ FonctionnalitÃ© en dÃ©veloppement. Utilisez les autres outils d'analyse disponibles.")
                            
                            # Informations de trading disponibles
                            if not st.session_state.real_time_data.empty:
                                current_price = st.session_state.real_time_data['close'].iloc[-1]
                                st.metric("Prix actuel", f"{current_price:.5f}")
                                
                                # Afficher les indicateurs disponibles
                                if 'rsi' in st.session_state.real_time_data.columns:
                                    rsi_value = st.session_state.real_time_data['rsi'].iloc[-1]
                                    st.metric("RSI", f"{rsi_value:.2f}")
                                
                                if 'macd' in st.session_state.real_time_data.columns:
                                    macd_value = st.session_state.real_time_data['macd'].iloc[-1]
                                    st.metric("MACD", f"{macd_value:.5f}")
                                else:
                                    st.warning("Aucune donnÃ©e de trading disponible")
                            
                            with col2:
                                st.write("**Zones de RÃ©sistance:**")
                                resistance_zones = support_resistance.get('resistance_zones', [])
                                if resistance_zones:
                                    for i, zone in enumerate(resistance_zones[:3]):  # Afficher les 3 plus fortes
                                        zone_range = zone['upper'] - zone['lower']
                                        zone_pips = zone_range / (st.session_state.real_time_data['close'].iloc[-1] * 0.0001)
                                        confidence = zone.get('confidence', 0.0)
                                        is_high_confidence = zone.get('is_high_confidence', False)
                                        
                                        # Style selon la confiance
                                        if is_high_confidence:
                                            st.markdown(f"**ðŸŽ¯ Zone {i+1} - CONFIRMÃ‰E {confidence:.0%}**")
                                            st.markdown(f"ðŸ’° **Niveau:** {zone['level']:.5f}")
                                            st.markdown(f"ðŸ“ **Range:** {zone['lower']:.5f} - {zone['upper']:.5f}")
                                            st.markdown(f"ðŸ“ **Largeur:** {zone_pips:.1f} pips")
                                            st.markdown(f"ðŸ’ª **Force:** {zone['strength']:.2f}")
                                            st.markdown(f"ðŸ”¢ **Touches:** {zone['touches']}")
                                            st.success("ðŸ”¥ ZONE HAUTE CONFIANCE - PRIORITÃ‰ MAXIMALE!")
                                        else:
                                            st.write(f"**Zone {i+1}:**")
                                            st.write(f"ðŸ’° Niveau: {zone['level']:.5f}")
                                            st.write(f"ðŸ“ Range: {zone['lower']:.5f} - {zone['upper']:.5f}")
                                            st.write(f"ðŸ“ Largeur: {zone_pips:.1f} pips")
                                            st.write(f"ðŸ’ª Force: {zone['strength']:.2f}")
                                            st.write(f"ðŸ”¢ Touches: {zone['touches']}")
                                            st.write(f"ðŸ“Š Confiance: {confidence:.0%}")
                                        
                                        if zone_pips <= 4:
                                            st.success("âœ… Zone prÃ©cise (â‰¤ 4 pips)")
                                        elif zone_pips <= 8:
                                            st.warning("âš ï¸ Zone acceptable (â‰¤ 8 pips)")
                                        else:
                                            st.error("âŒ Zone trop large (> 8 pips)")
                                        st.write("---")
                                else:
                                    st.write("Aucune zone de rÃ©sistance confirmÃ©e dÃ©tectÃ©e")
                
            except Exception as e:
                st.error(f"Erreur dans l'analyse des indices synthÃ©tiques: {e}")
    
            # Section supprimÃ©e - les indicateurs modernes sont maintenant dans la section dÃ©diÃ©e plus haut
