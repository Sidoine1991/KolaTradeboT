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

load_dotenv()

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
    page_title="TradBOT Temps Réel", 
    page_icon="⚡", 
    layout="wide", 
    initial_sidebar_state="expanded"
)

# Ajout du répertoire racine au PYTHONPATH
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

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
    # from backend.spike_predictor import AdvancedSpikePredictor  # Supprimé
    MT5_AVAILABLE = True
except ImportError as e:
    st.error(f"❌ Erreur d'import des modules backend: {e}")
    st.error("Assurez-vous que MetaTrader 5 est installé et configuré")
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
# spike_predictions supprimé - alertes spike désactivées
if 'ml_predictor' not in st.session_state:
    st.session_state.ml_predictor = AdvancedMLPredictor()
if 'setup_detector' not in st.session_state:
    st.session_state.setup_detector = SetupDetector()
# spike_predictor supprimé - alertes spike désactivées
if 'trading_signals' not in st.session_state:
    st.session_state.trading_signals = {}
if 'risk_manager' not in st.session_state:
    st.session_state.risk_manager = RiskManager(account_balance=1000.0)

# Essayer de charger les modèles ML pré-entraînés
if not st.session_state.ml_predictor.is_trained:
    try:
        if st.session_state.ml_predictor.load_models():
            st.session_state.ml_predictor.is_trained = True
    except:
        pass  # Pas de modèles pré-entraînés disponibles

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
    """Récupère le prix actuel en temps réel depuis MT5"""
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
        st.error(f"Erreur lors de la récupération du prix pour {symbol}: {e}")
    return None

def get_real_time_ohlc(symbol, timeframe='1m', count=100):
    """Récupère les données OHLC en temps réel depuis MT5"""
    if not MT5_AVAILABLE or not st.session_state.mt5_connected:
        return pd.DataFrame()
    
    try:
        df = get_ohlc(symbol, timeframe, count)
        if df is not None and not df.empty:
            # Ajouter les indicateurs techniques complets pour ML
            df = add_technical_indicators(df, ['RSI', 'MACD', 'BB'])
            # Ajouter toutes les features ML
            features_df = compute_features(df)
            # Fusionner les features avec les données OHLC
            for col in features_df.columns:
                if col not in df.columns:
                    df[col] = features_df[col]
            return df
    except Exception as e:
        st.error(f"Erreur lors de la récupération des données OHLC pour {symbol}: {e}")
    
    return pd.DataFrame()

def predict_spike_real_time(df):
    """Prédiction de spike en temps réel basée sur les vrais prix"""
    if df.empty or len(df) < 20:
        return None
    
    try:
        # Utiliser le modèle ML pour prédire les spikes
        ml_proba = predict_spike_ml(df)
        if ml_proba is not None:
            return ml_proba
        
        # Fallback: détection traditionnelle
        spikes = detect_spikes(df, threshold=0.5, method='percentage')
        if not spikes.empty:
            return 0.8  # Probabilité élevée si un spike est détecté
            
    except Exception as e:
        st.error(f"Erreur lors de la prédiction de spike: {e}")
    
    return None

def update_real_time_data():
    """Met à jour les données en temps réel"""
    if not st.session_state.current_symbol:
        return
    
    symbol = st.session_state.current_symbol
    timeframe = st.session_state.current_timeframe
    
    # Récupérer les données OHLC réelles
    df = get_real_time_ohlc(symbol, timeframe, 200)
    if not df.empty:
        st.session_state.real_time_data = df
        st.session_state.last_update = datetime.now()
        
        # Prédiction de spike supprimée - focus sur AutoMonitor et ML uniquement

# Interface principale
st.title("⚡ TradBOT - Prédictions Temps Réel")
st.markdown("### Prédictions basées sur les **vrais prix** du marché")

# Sidebar pour la configuration
with st.sidebar:
    st.header("⚙️ Configuration MT5")
    
    # Test de connexion MT5
    if st.button("🔗 Tester Connexion MT5"):
        with st.spinner("Test de connexion..."):
            if MT5_AVAILABLE and test_connection():
                st.session_state.mt5_connected = True
                st.success("✅ Connexion MT5 réussie!")
            else:
                st.error("❌ Échec de la connexion MT5")
                st.info("Vérifiez vos identifiants dans le fichier .env")
    
    # Connexion manuelle
    if st.button("🔌 Connecter MT5"):
        with st.spinner("Connexion en cours..."):
            if MT5_AVAILABLE:
                try:
                    connect()
                    st.session_state.mt5_connected = True
                    st.success("✅ Connecté à MT5!")
                except Exception as e:
                    st.error(f"❌ Erreur de connexion: {e}")
    
    # Statut de connexion
    if st.session_state.mt5_connected:
        st.success("🟢 MT5 Connecté")
    else:
        st.error("🔴 MT5 Non connecté")
    
    st.markdown("---")
    st.header("📊 Analyse Technique")
    
    # Contrôles pour les trendlines et Fibonacci
    show_trendlines = st.checkbox("📈 Trendlines", value=True, help="Afficher les lignes de support et résistance")
    show_fibonacci = st.checkbox("🌀 Fibonacci", value=True, help="Afficher les retracements de Fibonacci")
    show_current_price = st.checkbox("💰 Prix actuel", value=True, help="Afficher la ligne du prix actuel")
    show_sr_zones = st.checkbox("🧱 Zones S/R réelles", value=True, help="Dessiner les vrais supports/résistances détectés sur les prix MT5")
    
    # Stocker dans session_state pour utilisation dans le graphique
    st.session_state.show_trendlines = show_trendlines
    st.session_state.show_fibonacci = show_fibonacci
    st.session_state.show_current_price = show_current_price
    st.session_state.show_sr_zones = show_sr_zones
    
    # Configuration du rafraîchissement
    st.header("🔄 Rafraîchissement")
    auto_refresh = st.checkbox("Rafraîchissement automatique", value=True)
    refresh_interval = st.slider("Intervalle (secondes)", 5, 30, 10)
    
    if auto_refresh:
        st_autorefresh(interval=refresh_interval * 1000, key="realtime_refresh")
    
    # Sélection du symbole
    st.header("📈 Sélection du symbole")
    
    if st.session_state.mt5_connected and MT5_AVAILABLE:
        try:
            # Récupérer TOUS les symboles exacts depuis MT5
            with st.spinner("🔄 Chargement de tous les symboles MT5..."):
                all_symbols = get_all_symbols()
            
            if all_symbols:
                st.success(f"✅ {len(all_symbols)} symboles chargés depuis MT5")
                
                # Zone de recherche et de filtrage
                st.caption("🔍 Recherche dans tous les symboles MT5 (Market Watch)")
                search = st.text_input("Rechercher un symbole", value=st.session_state.current_symbol or "", key="main_symbol_search").upper()
                
                # Filtrer par recherche
                filtered = [s for s in all_symbols if search in s.upper()] if search else all_symbols
                
                # Option de catégories (Synthétiques / Forex / Indices ...)
                with st.expander("🎯 Filtrer par catégories", expanded=False):
                    from backend.mt5_connector import get_symbols_by_category
                    colA, colB, colC, colD = st.columns(4)
                    with colA:
                        show_syn = st.checkbox("Synthétiques", value=True, key="cat_syn")
                    with colB:
                        show_fx = st.checkbox("Forex", value=True, key="cat_fx")
                    with colC:
                        show_crypto = st.checkbox("Crypto", value=True, key="cat_crypto")
                    with colD:
                        show_others = st.checkbox("Autres", value=True, key="cat_others")
                    
                    # Appliquer les filtres de catégories
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
                
                # Affichage des résultats
                if filtered:
                    # Sélecteur complet avec pagination
                    page_size = 100  # Plus de symboles par page
                    total = len(filtered)
                    total_pages = max(1, (total - 1) // page_size + 1)
                    
                    col1, col2, col3 = st.columns([1, 2, 1])
                    with col1:
                        page = st.number_input("Page", min_value=1, max_value=total_pages, value=1, step=1)
                    with col2:
                        st.caption(f"📄 Page {page}/{total_pages} - Affichage {min(page_size, total)} symboles")
                    with col3:
                        st.caption(f"📊 Total: {total} symboles")
                    
                    start = (page - 1) * page_size
                    end = start + page_size
                    page_symbols = filtered[start:end]
                    
                    # Sélecteur de symbole
                    selected_symbol = st.selectbox(
                        "Choisir un symbole MT5", 
                        page_symbols,
                        index=page_symbols.index(st.session_state.current_symbol) if st.session_state.current_symbol in page_symbols else 0,
                        help="Sélectionnez le symbole exact depuis votre Market Watch MT5"
                    )
                else:
                    st.warning("Aucun symbole trouvé avec ces critères de recherche")
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
    
    # Sélection du timeframe
    timeframe_options = ["1m", "5m", "15m", "30m", "1h", "4h", "6h", "8h", "1d"]
    selected_timeframe = st.selectbox(
        "Timeframe",
        timeframe_options,
        index=timeframe_options.index(st.session_state.current_timeframe) if st.session_state.current_timeframe in timeframe_options else 0
    )
    st.session_state.current_timeframe = selected_timeframe

    # Watchlist AutoMonitor
    st.header("🧭 AutoMonitor Watchlist")
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

    # Organiser les symboles par catégorie pour faciliter la sélection
    if available_for_watchlist:
        # Grouper les symboles par catégorie
        forex_symbols = [s for s in available_for_watchlist if any(curr in s for curr in ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD']) and len(s) == 6]
        synthetic_symbols = [s for s in available_for_watchlist if any(keyword in s.upper() for keyword in ['BOOM', 'CRASH', 'STEP', 'JUMP', 'RANGE', 'VOLATILITY', 'DRIFT', 'DEX', 'MULTI', 'DAILY', 'HYBRID', 'SKEWED', 'SYNTHETIC', 'INDEX', 'INDICES'])]
        crypto_symbols = [s for s in available_for_watchlist if any(curr in s for curr in ['BTC', 'ETH', 'LTC', 'XRP', 'ADA', 'DOT', 'BCH', 'BAT', 'APE', 'ALG', 'XTZ'])]
        indices_symbols = [s for s in available_for_watchlist if any(keyword in s.upper() for keyword in ['SPX', 'NAS', 'DOW', 'FTSE', 'DAX', 'NIKKEI', 'WALL_STREET', 'US_500', 'US_TECH'])]
        other_symbols = [s for s in available_for_watchlist if s not in forex_symbols + synthetic_symbols + crypto_symbols + indices_symbols]
        
        # Créer des options groupées
        options_with_categories = []
        if forex_symbols:
            options_with_categories.extend([f"💱 {s}" for s in forex_symbols[:20]])  # Limiter à 20 par catégorie
        if synthetic_symbols:
            options_with_categories.extend([f"🎯 {s}" for s in synthetic_symbols[:20]])
        if crypto_symbols:
            options_with_categories.extend([f"🪙 {s}" for s in crypto_symbols[:20]])
        if indices_symbols:
            options_with_categories.extend([f"📈 {s}" for s in indices_symbols[:20]])
        if other_symbols:
            options_with_categories.extend([f"📊 {s}" for s in other_symbols[:20]])
        
        # Ajouter une option de recherche
        search_term = st.text_input("🔍 Rechercher un symbole", placeholder="Tapez pour filtrer...", key="watchlist_symbol_search")
        if search_term:
            filtered_options = [opt for opt in options_with_categories if search_term.upper() in opt.upper()]
        else:
            filtered_options = options_with_categories
        
        # Préparer les valeurs par défaut avec icônes
        default_with_icons = []
        for symbol in st.session_state.watchlist:
            # Chercher le symbole dans les options filtrées
            for option in filtered_options:
                if option.endswith(f" {symbol}"):
                    default_with_icons.append(option)
                    break
        
        # Sélection multiple avec options groupées
        selected_with_icons = st.multiselect(
            "Sélectionnez des symboles à surveiller (plusieurs choix possibles)",
            options=filtered_options,
            default=default_with_icons,
            help="💡 Vous pouvez sélectionner plusieurs symboles à la fois. Utilisez la recherche pour filtrer rapidement.",
            key="watchlist_multiselect"
        )
        
        # Nettoyer les sélections (enlever les icônes)
        st.session_state.watchlist = [opt.split(' ', 1)[1] for opt in selected_with_icons]
        
        # Boutons de sélection rapide
        st.subheader("⚡ Sélection rapide")
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            if st.button("💱 Forex Majors", help="Sélectionner 5 paires de devises au hasard", key="btn_forex_majors"):
                import random
                available_forex = [s for s in forex_symbols if s in available_for_watchlist]
                if available_forex:
                    # Sélectionner 5 symboles au hasard
                    selected_forex = random.sample(available_forex, min(5, len(available_forex)))
                    st.session_state.watchlist = list(set(st.session_state.watchlist + selected_forex))
                    st.rerun()
        
        with col2:
            if st.button("🎯 Synthétiques", help="Sélectionner 5 indices synthétiques au hasard", key="btn_synthetics"):
                import random
                available_synthetics = [s for s in synthetic_symbols if s in available_for_watchlist]
                if available_synthetics:
                    # Sélectionner 5 symboles au hasard
                    selected_synthetics = random.sample(available_synthetics, min(5, len(available_synthetics)))
                    st.session_state.watchlist = list(set(st.session_state.watchlist + selected_synthetics))
                    st.rerun()
        
        with col3:
            if st.button("🪙 Crypto Top", help="Sélectionner 3 cryptomonnaies au hasard", key="btn_crypto_top"):
                import random
                available_crypto = [s for s in crypto_symbols if s in available_for_watchlist]
                if available_crypto:
                    # Sélectionner 3 symboles au hasard
                    selected_crypto = random.sample(available_crypto, min(3, len(available_crypto)))
                    st.session_state.watchlist = list(set(st.session_state.watchlist + selected_crypto))
                    st.rerun()
        
        with col4:
            if st.button("🧹 Tout effacer", help="Désélectionner tous les symboles", key="btn_clear_all"):
                st.session_state.watchlist = []
                st.rerun()
        
        # Afficher le nombre de symboles sélectionnés
        if st.session_state.watchlist:
            st.success(f"✅ {len(st.session_state.watchlist)} symbole(s) sélectionné(s): {', '.join(st.session_state.watchlist[:5])}{'...' if len(st.session_state.watchlist) > 5 else ''}")
        else:
            st.info("ℹ️ Aucun symbole sélectionné. Choisissez des symboles à surveiller ci-dessus.")
    else:
        st.warning("⚠️ Aucun symbole disponible. Vérifiez la connexion MT5.")
        st.session_state.watchlist = []

    colW1, colW2, colW3 = st.columns([1,1,1])
    with colW1:
        automonitor_auto = st.checkbox("Auto-scan", value=False, key="automonitor_auto")
        # Reprogrammer sans toucher à l'état du widget
        if st.button("⟳ Reprogrammer", key="automonitor_reprogram"):
            st.session_state.automonitor_next_ts = datetime.now()
    with colW2:
        automonitor_interval = st.number_input("Intervalle (s)", min_value=10, max_value=300, value=60, step=10, key="automonitor_interval")
    with colW3:
        probability_threshold = st.slider("Seuil probabilité (%)", min_value=30, max_value=90, value=60, step=5, key="probability_threshold", help="Probabilité minimum pour générer un signal")

    # Modes de stratégie: Scalping M5 / Swing M10 (approx M15)
    st.subheader("🎛️ Mode de stratégie")
    mode_options = ["Scalping (M5)", "Swing court (M10≈M15)"]
    selected_mode = st.selectbox("Sélectionnez un mode", options=mode_options, index=0, key="strategy_mode")
    # Capital et risque
    st.caption("Capital de départ")
    capital_usd = st.number_input("Capital ($)", min_value=1.0, max_value=1000.0, value=5.0, step=1.0, key="capital_usd")
    risk_pct = st.slider("Risque par trade (%)", min_value=0.5, max_value=2.0, value=1.0, step=0.5, key="risk_pct")

    # Appliquer présélections selon le mode
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
        do_manual_scan = st.button("🔎 Scanner maintenant", key="automonitor_scan_btn")
        if do_manual_scan:
            st.session_state["automonitor_manual_once"] = True
    
    with col_scan2:
        test_signal_logic = st.button("🧪 Tester logique signaux", key="test_signal_btn")
        if test_signal_logic:
            st.session_state["test_signal_logic"] = True

    # Initialiser le prochain scan si absent (indépendant du rafraîchissement global)
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
        status_chip = "🟢 ON" if st.session_state.get("automonitor_auto") else "⚪ OFF"
        st.caption(f"🧭 AutoMonitor: {status_chip} · {st.session_state.automonitor_status} · ⏱ {secs_left}s")
    else:
        status_chip = "🟢 ON" if st.session_state.get("automonitor_auto") else "⚪ OFF"
        st.caption(f"🧭 AutoMonitor: {status_chip} · {st.session_state.automonitor_status}")

    # Notifications
    st.header("📣 Notifications")
    notify_whatsapp = st.checkbox("WhatsApp", value=True, key="notify_whatsapp")
    notify_sms = st.checkbox("SMS", value=True, key="notify_sms")
    notif_interval = st.number_input("Intervalle min entre alertes (s)", min_value=30, max_value=3600, value=180, step=30, key="notify_interval")
    if 'last_notifications' not in st.session_state:
        st.session_state.last_notifications = {}
    # spike_predictions supprimé - alertes spike désactivées
    
    # Résumé des notifications configurées
    st.markdown("#### 📋 Types de notifications")
    st.markdown("""
    - **🧭 Signaux AutoMonitor** : Confluence > 70% (cooldown 3min)
    - **📱 Envoi** : SMS + WhatsApp automatique
    - **📊 Format** : Devise, Heure, Type d'ordre, Lots, Prix d'entrée, TP/SL
    """)
    
    # Bouton de test des notifications
    if st.button("🧪 Tester Notifications", type="secondary"):
        try:
            from frontend.whatsapp_notify import send_whatsapp_message_unified, send_sms_vonage
            test_message = f"[TradBOT Test] Signal BUY EURUSD (M5) · Confluence 85% · {datetime.now().strftime('%H:%M:%S')}"
            
            if notify_whatsapp:
                st.info("🔄 Envoi WhatsApp en cours...")


                try:
                    result_wa = send_whatsapp_message_unified(test_message)
                    st.write("📋 Réponse WhatsApp:", result_wa)
                    # Considérer succès si dict sans status=error, ou True
                    if result_wa is True:
                        st.success("✅ Test WhatsApp envoyé !")
                    elif isinstance(result_wa, dict) and result_wa.get('status') not in ['error', 'failed']:
                        st.success("✅ Test WhatsApp envoyé !")
                    else:
                        st.error(f"❌ Erreur WhatsApp: {result_wa}")
                except Exception as e:
                    st.error(f"❌ Erreur WhatsApp: {e}")
            else:
                st.warning("⚠️ WhatsApp désactivé - activez d'abord la case WhatsApp")
            
            if notify_sms:
                st.info("🔄 Envoi SMS en cours...")
                result_sms = send_sms_vonage(test_message)
                st.write("📋 Réponse SMS:", result_sms)
                
                if result_sms and result_sms.get('messages', [{}])[0].get('status') == '0':
                    st.success("✅ Test SMS envoyé !")
                else:
                    st.error(f"❌ Erreur SMS: {result_sms}")
            else:
                st.warning("⚠️ SMS désactivé - activez d'abord la case SMS")
                
        except Exception as e:
            st.error(f"❌ Erreur test notifications: {e}")
            import traceback
            st.code(traceback.format_exc())

# Zone principale
if st.session_state.current_symbol:
    symbol = st.session_state.current_symbol
    
    # Mise à jour des données en temps réel
    update_real_time_data()
    
    # Affichage du prix actuel
    col1, col2, col3 = st.columns(3)
    
    with col1:
        current_price = get_real_time_price(symbol)
        if current_price and isinstance(current_price, (int, float)) and current_price > 0:
            # Ajuster le nombre de décimales selon le type de symbole
            if 'JPY' in symbol or 'Index' in symbol:
                price_format = f"{current_price:.2f}"
            else:
                price_format = f"{current_price:.5f}"
            st.metric(
                label="💰 Prix Actuel",
                value=price_format,
                delta=None
            )
        else:
            st.metric("💰 Prix Actuel", "N/A")
    
    with col2:
        if not st.session_state.real_time_data.empty:
            price_change = st.session_state.real_time_data['close'].pct_change().iloc[-1] * 100
            st.metric(
                label="📊 Variation",
                value=f"{price_change:.2f}%",
                delta=f"{price_change:.2f}%"
            )
        else:
            st.metric("📊 Variation", "N/A")
    
    with col3:
        if st.session_state.last_update:
            time_diff = datetime.now() - st.session_state.last_update
            st.metric(
                label="🕒 Dernière MAJ",
                value=f"{time_diff.seconds}s"
            )
        else:
            st.metric("🕒 Dernière MAJ", "N/A")
    
    # Graphique en temps réel
    if not st.session_state.real_time_data.empty:
        st.subheader(f"📈 Graphique {symbol} - {st.session_state.current_timeframe}")
        
        # Créer le graphique avec timeframe dans le titre
        chart_title = f"{symbol} - {st.session_state.current_timeframe} - Temps Réel"
        fig = create_candlestick_chart(st.session_state.real_time_data, chart_title)
        try:
            fig.update_layout(title=chart_title)
        except Exception:
            pass
        
        # Ajouter les indicateurs techniques et canaux de trading (sans Bollinger Bands)
        fig = add_technical_indicators_to_chart(fig, st.session_state.real_time_data, ['sma', 'ema', 'channels'])

        # Dessiner les vraies zones de support/résistance issues du détecteur
        try:
            if st.session_state.get('show_sr_zones', False) and len(st.session_state.real_time_data) >= 50:
                # Utiliser une fenêtre limitée pour éviter des ranges x invalides
                _df_sr = st.session_state.real_time_data.tail(400)
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
                # Zones de résistance
                for z in (sr.get('resistance_zones') or [])[:3]:
                    lower = float(z.get('lower', 0))
                    upper = float(z.get('upper', 0))
                    if lower > 0 and upper > 0 and upper >= lower:
                        fig.add_shape(type="rect", xref="x", yref="y",
                                      x0=x0_sr, x1=x1_sr,
                                      y0=float(lower), y1=float(upper),
                                      line=dict(color="rgba(231, 76, 60, 0.0)", width=0),
                                      fillcolor="rgba(231, 76, 60, 0.08)", layer="below")
        except Exception:
            pass

        # Ajouter lignes de tendance avancées + retracements de Fibonacci
        try:
            df_plot = st.session_state.real_time_data
            if len(df_plot) >= 50 and all(c in df_plot.columns for c in ['high','low','close']):
                tail_n = 200 if len(df_plot) >= 200 else len(df_plot)
                df_tail = df_plot.tail(tail_n)
                
                # X-axis handling (index or time column)
                x_series = df_tail.index
                if 'time' in df_tail.columns:
                    x_series = df_tail['time']

                # Détecter plusieurs points pivots pour des trendlines plus robustes
                highs = df_tail['high'].rolling(window=5, center=True).max() == df_tail['high']
                lows = df_tail['low'].rolling(window=5, center=True).min() == df_tail['low']
                
                pivot_highs = df_tail[highs].sort_values('high', ascending=False).head(3)
                pivot_lows = df_tail[lows].sort_values('low', ascending=True).head(3)
                
                # Trendline de résistance (connecter les 2 plus hauts points)
                if len(pivot_highs) >= 2 and st.session_state.get('show_trendlines', True):
                    high1_idx = pivot_highs.index[0]
                    high2_idx = pivot_highs.index[1]
                    x1, y1 = x_series.loc[high1_idx], float(pivot_highs.loc[high1_idx, 'high'])
                    x2, y2 = x_series.loc[high2_idx], float(pivot_highs.loc[high2_idx, 'high'])
                    
                    # Étendre la trendline de résistance
                    x_extend = x_series.iloc[-1] + (x_series.iloc[-1] - x_series.iloc[0]) * 0.1
                    slope = (y2 - y1) / (x2 - x1) if x2 != x1 else 0
                    y_extend = y2 + slope * (x_extend - x2)
                    
                    try:
                        fig.add_trace(
                            go.Scatter(x=[x1, x_extend], y=[y1, y_extend], mode="lines",
                                       line=dict(color="#e74c3c", width=2, dash="dash"),
                                       name="Résistance", showlegend=True),
                            row=1, col=1
                        )
                    except Exception:
                        fig.add_trace(
                            go.Scatter(x=[x1, x_extend], y=[y1, y_extend], mode="lines",
                                       line=dict(color="#e74c3c", width=2, dash="dash"),
                                       name="Résistance", showlegend=True)
                        )

                # Trendline de support (connecter les 2 plus bas points)
                if len(pivot_lows) >= 2 and st.session_state.get('show_trendlines', True):
                    low1_idx = pivot_lows.index[0]
                    low2_idx = pivot_lows.index[1]
                    x1, y1 = x_series.loc[low1_idx], float(pivot_lows.loc[low1_idx, 'low'])
                    x2, y2 = x_series.loc[low2_idx], float(pivot_lows.loc[low2_idx, 'low'])
                    
                    # Étendre la trendline de support
                    x_extend = x_series.iloc[-1] + (x_series.iloc[-1] - x_series.iloc[0]) * 0.1
                    slope = (y2 - y1) / (x2 - x1) if x2 != x1 else 0
                    y_extend = y2 + slope * (x_extend - x2)
                    
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
                
                # Déterminer la direction du swing principal
                is_uptrend = swing_low_idx < swing_high_idx
                
                # Niveaux de Fibonacci complets
                fib_ratios = [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0]
                fib_colors = ["#e74c3c", "#f39c12", "#f1c40f", "#2ecc71", "#3498db", "#9b59b6", "#e74c3c"]
                
                # Afficher les niveaux de Fibonacci seulement si activé
                if st.session_state.get('show_fibonacci', True):
                    for i, (ratio, color) in enumerate(zip(fib_ratios, fib_colors)):
                        if is_uptrend:
                            level = swing_high - (swing_high - swing_low) * ratio
                        else:
                            level = swing_low + (swing_high - swing_low) * ratio
                        
                        # Style différent pour les niveaux clés
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
                if st.session_state.get('show_current_price', True):
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
        
        # Ajouter les prédictions ML et setups si disponibles
        if len(st.session_state.real_time_data) >= 50:
            try:
                # Détecter les setups
                setups = st.session_state.setup_detector.detect_all_setups(st.session_state.real_time_data)
                
                # Générer les signaux ML
                try:
                    ml_signals = st.session_state.ml_predictor.get_trading_signals(st.session_state.real_time_data)
                except ValueError:
                    # Utiliser des signaux basiques si les modèles ne sont pas entraînés
                    ml_signals = {
                        'direction': 'HOLD',
                        'direction_strength': 0.5,
                        'spike': 'LOW_SPIKE_RISK',
                        'spike_strength': 0.3
                    }
                
                # Prédictions de spikes supprimées
                
                # Ajouter les prédictions au graphique
                fig = add_ml_predictions_to_chart(fig, st.session_state.real_time_data, ml_signals, setups)
                
            except Exception as e:
                st.warning(f"⚠️ Impossible d'ajouter les prédictions au graphique: {e}")
        
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
        
        # Ajout des flèches de prédiction de spikes (overlay avant rendu)
        try:
            if st.session_state.get('show_spike_predictions', True) and len(st.session_state.real_time_data) >= 50:
                df_sp = st.session_state.real_time_data.copy()
                # Heuristique professionnelle: composite (ret/ATR, dev/σ, vol/σ), fenêtres adaptatives, min pips
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
                # Pré-signal: placer la flèche sur la bougie suivante (T-1) quand possible
                last_idx = len(df_sp) - 1
                for i in idx_candidates[-60:]:
                    j = i + 1 if (i + 1) <= last_idx else i
                    direction_up = mom[i] > 0
                    y = df_sp['high'].iloc[j] if direction_up else df_sp['low'].iloc[j]
                    # Bleu pour BUY, Rouge pour SELL
                    arrow_color = "#3498db" if direction_up else "#e74c3c"
                    arrow_y = float(y) * (1.004 if direction_up else 0.996)
                    label = "T-1" if j == i + 1 else ""
                    try:
                        fig.add_annotation(
                            x=x_series.iloc[j], y=arrow_y,
                            ax=0, ay=(-20 if direction_up else 20),
                            xref='x', yref='y',
                            showarrow=True, arrowhead=3, arrowsize=1, arrowwidth=2, arrowcolor=arrow_color,
                            opacity=0.9,
                            text=label,
                        )
                    except Exception:
                        pass
                    # Point jaune de confirmation (momentum + écart vs MA forts)
                    try:
                        sret_i = float(s_ret[i]) if 's_ret' in locals() else 0.0
                        sdev_i = float(s_dev[i]) if 's_dev' in locals() else 0.0
                        if sret_i > 1.0 and sdev_i > 1.0:
                            fig.add_scatter(x=[x_series.iloc[j]], y=[float(df_sp['close'].iloc[j])],
                                            mode='markers', marker=dict(color='yellow', size=8, line=dict(color='black', width=0.5)),
                                            name='Confirm', showlegend=False)
                    except Exception:
                        pass
        except Exception as _e_sp:
            st.caption(f"(Spike overlay non disponible: {_e_sp})")

        # 🎯 Sniper Boom/Crash (pro)
        with st.expander("🎯 Sniper Boom/Crash (pro)", expanded=False):
            if 'sniper_enabled' not in st.session_state:
                st.session_state['sniper_enabled'] = True
            st.checkbox("Activer la stratégie Sniper avancée", value=st.session_state['sniper_enabled'], key="sniper_enabled")
            st.caption("Règles: MTF (M5 contexte, M1 entrée) · EMA200 filtre · RSI/Stoch · MACD croisement · Bollinger touch · ATR SL/TP")

        # Overlays Sniper Strategy (Boom/Crash)
        try:
            if st.session_state.get('sniper_enabled', True) and len(st.session_state.real_time_data) >= 60:
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

                # Génération des signaux Sniper sur la dernière fenêtre
                marks = []
                N = len(df_sn)
                rng = range(max(20, N-300), N)
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
                    buy_ok = above_ema and (rsi < 35) and stoch_rebound_buy and macd_buy and ctx_ok_buy and (bb_touch_buy or rsi < 30)
                    sell_ok = below_ema and (rsi > 65) and stoch_rebound_sell and macd_sell and ctx_ok_sell and (bb_touch_sell or rsi > 70)
                    if buy_ok:
                        marks.append((i, True, c, atr))
                    elif sell_ok:
                        marks.append((i, False, c, atr))

                # Ajouter des marqueurs + table SL/TP via ATR
                x_series = df_sn.index if 'time' not in df_sn.columns else df_sn['time']
                for i, is_buy, price, atr in marks[-40:]:
                    arrow_color = "#3498db" if is_buy else "#e74c3c"
                    y = df_sn['low'].iloc[i] * 0.996 if is_buy else df_sn['high'].iloc[i] * 1.004
                    try:
                        fig.add_annotation(x=x_series.iloc[i], y=y, ax=0, ay=(-30 if is_buy else 30),
                                           xref='x', yref='y', showarrow=True, arrowhead=2,
                                           arrowsize=1, arrowwidth=2, arrowcolor=arrow_color, opacity=0.95, text="")
                    except Exception:
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
                                "Entrée": round(float(price), 5),
                                "SL": round(float(sl), 5),
                                "TP": round(float(tp), 5),
                                "ATR": round(float(atr), 5)
                            })
                        st.caption("Derniers signaux Sniper (ATR SL/TP)")
                        st.dataframe(_pd.DataFrame(rows), use_container_width=True, hide_index=True)
                    except Exception:
                        pass
        except Exception as _e_sn:
            st.caption(f"(Sniper overlay non disponible: {_e_sn})")

        # Afficher le graphique UNE SEULE FOIS (avec ou sans flèches)
        st.plotly_chart(fig, use_container_width=True, key="price_chart")
        
        # Watchlist AutoMonitor - Scan & Opportunities table
        try:
            import requests as _rq
            if st.session_state.watchlist:
                # Auto trigger based on interval
                trigger_scan = False
                # Planification indépendante
                now = datetime.now()
                next_ts = st.session_state.get('automonitor_next_ts')
                if st.session_state.get('automonitor_auto'):
                    if next_ts is None or now >= next_ts:
                        trigger_scan = True
                # Scan manuel
                if st.button("🔎 Scanner la Watchlist", key="automonitor_scan_btn_main"):
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
                            # ALGORITHME BASÉ UNIQUEMENT SUR LA PROBABILITÉ
                            # Calcul d'un score de probabilité unique (0-100%)
                            
                            # 1. PROBABILITÉ DE BASE (Force de tendance)
                            base_probability = force  # 0-100
                            
                            # 2. BONUS PROBABILITÉ - Alignement des indicateurs
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
                                elif trend_dir == "bearish" and rsi_f > 70:  # Suralimenté
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
                            
                            # 3. CALCUL DE LA PROBABILITÉ FINALE
                            final_probability = min(100, base_probability + probability_bonus)
                            
                            # 4. DÉCISION BASÉE UNIQUEMENT SUR LA PROBABILITÉ
                            confluence = int(final_probability)
                            confidence = confluence  # Même valeur pour simplicité
                            
                            # Calculer les niveaux de prix pour TP/SL
                            try:
                                # Récupérer le prix actuel depuis l'API
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
                    else:
                                            current_price = 0
                                except Exception:
                                    pass
                                
                                # Si pas de prix, essayer de récupérer depuis les données de tendance
                                if current_price == 0:
                                    try:
                                        # Récupérer le prix depuis les données de tendance
                                        trend_data = trend.get("trends", {}).get(tf_for_scan, {})
                                        if trend_data and "price" in trend_data:
                                            current_price = float(trend_data["price"])
                                        elif trend_data and "close" in trend_data:
                                            current_price = float(trend_data["close"])
                                    except Exception:
                                        pass
                                
                                # Si toujours pas de prix, utiliser une estimation basée sur le symbole
                                if current_price == 0:
                                    if "Index" in sym_scan or "Boom" in sym_scan or "Crash" in sym_scan:
                                        current_price = 1000.0  # Prix par défaut pour les indices
                                    elif "JPY" in sym_scan:
                                        current_price = 100.0  # Prix par défaut pour JPY
                                    else:
                                        current_price = 1.0  # Prix par défaut pour les autres
                                
                                # Essayer de récupérer l'ATR depuis les données de tendance
                                atr_val = 0
                                try:
                                    trend_data = trend.get("trends", {}).get(tf_for_scan, {})
                                    if trend_data and "atr" in trend_data:
                                        atr_val = float(trend_data["atr"])
                                except Exception:
                                    pass
                                
                                # Si pas d'ATR, estimation basée sur le type de symbole
                                if atr_val == 0:
                                    if "Index" in sym_scan or "Boom" in sym_scan or "Crash" in sym_scan:
                                        atr_val = current_price * 0.01  # 1% du prix pour les indices
                                    elif "JPY" in sym_scan:
                                        atr_val = current_price * 0.001  # 0.1% pour JPY
                                    else:
                                        atr_val = current_price * 0.0001  # 0.01% pour les autres
                                
                                # Calculer TP et SL basés sur ATR
                                if current_price > 0 and atr_val > 0:
                                    if trend_dir == "bullish":
                                        entry_price = current_price
                                        tp_price = current_price + (atr_val * 2)  # TP à 2 ATR
                                        sl_price = current_price - (atr_val * 1)  # SL à 1 ATR
                                    elif trend_dir == "bearish":
                                        entry_price = current_price
                                        tp_price = current_price - (atr_val * 2)  # TP à 2 ATR
                                        sl_price = current_price + (atr_val * 1)  # SL à 1 ATR
                                    else:
                                        entry_price = current_price
                                        tp_price = current_price
                                        sl_price = current_price
                                else:
                                    # Debug: afficher pourquoi les prix sont à 0
                                    print(f"DEBUG {sym_scan}: current_price={current_price}, atr_val={atr_val}")
                                    entry_price = current_price
                                    tp_price = current_price
                                    sl_price = current_price
                            except Exception as e:
                                print(f"Erreur calcul prix pour {sym_scan}: {e}")
                                entry_price = 0
                                tp_price = 0
                                sl_price = 0

                            # LOGIQUE SIMPLE BASÉE UNIQUEMENT SUR LA PROBABILITÉ
                            signal = "HOLD"
                            
                            # Seuil de probabilité depuis l'interface utilisateur
                            probability_threshold = st.session_state.get('probability_threshold_effective', st.session_state.get('probability_threshold', 60))
                            
                            # Décision simple : si probabilité >= seuil ET direction claire
                            if trend_dir == "bullish" and confluence >= probability_threshold:
                                signal = "BUY"
                            elif trend_dir == "bearish" and confluence >= probability_threshold:
                                signal = "SELL"
                            
                            # Debug: Afficher les détails pour chaque symbole
                            print(f"🔍 DEBUG {sym_scan}: trend_dir={trend_dir}, probability={confluence}%, signal={signal}")
                            print(f"   Components: {components}")
                            print(f"   RSI: {rsi_f}, ST: {st_dir}, BOS: {bos_dir}")
                            
                            # Mise à jour du résultat
                            opp.update({
                                "signal": signal, 
                                "confidence": confidence, 
                                "confluence": confluence, 
                                "reason": f"Probabilité {confluence}% ({'+'.join(components)})",
                                "entry_price": entry_price,
                                "tp_price": tp_price,
                                "sl_price": sl_price
                            })
                        except Exception as e:
                            opp.update({"signal": "HOLD", "confidence": 0, "confluence": 0, "reason": f"Erreur: {e}", "entry_price": 0.0, "tp_price": 0.0, "sl_price": 0.0})
                        results.append(opp)
                        # Avancement
                        progress.progress(min(100, int(i/total_sym*100)), text=f"{i}/{total_sym} · {sym_scan}")
                    progress.empty()
                    if results:
                        import pandas as _pd
                        df_res = _pd.DataFrame(results)
                        df_res.sort_values(["signal", "confluence"], ascending=[True, False], inplace=True)
                        st.subheader("🧭 Opportunités Watchlist")
                        
                        # Debug: Afficher les statistiques de probabilité
                        probability_stats = df_res['confluence'].describe()
                        current_threshold = st.session_state.get('probability_threshold', 60)
                        st.caption(f"📊 Statistiques de probabilité: Min={probability_stats['min']:.1f}%, Max={probability_stats['max']:.1f}%, Moyenne={probability_stats['mean']:.1f}% (Seuil: {current_threshold}%)")
                        
                        # Debug: Afficher la répartition des signaux
                        signal_counts = df_res['signal'].value_counts()
                        st.caption(f"📈 Répartition: {dict(signal_counts)}")
                        
                        # Affichage spécial pour le test de logique
                        if st.session_state.get('test_signal_logic'):
                            st.success("🧪 Test de logique des signaux terminé !")
                            st.info("💡 Consultez la console pour voir les détails de chaque symbole scanné")
                            st.session_state['test_signal_logic'] = False
                        
                        # Afficher les signaux BUY/SELL avec format amélioré
                        buy_signals = df_res[df_res['signal'].isin(['BUY', 'SELL'])]
                        hold_signals = df_res[df_res['signal'] == 'HOLD']
                        
                        # Résumé des signaux
                        st.metric("📊 Résumé du scan", f"{len(buy_signals)} signaux actifs sur {len(df_res)} symboles scannés")
                        
                        if not buy_signals.empty:
                            st.success(f"🎯 {len(buy_signals)} signal(s) de trading détecté(s) !")
                            
                            # Envoyer les notifications WhatsApp pour les signaux
                            try:
                                from frontend.whatsapp_notify import send_whatsapp_message_unified, send_sms_vonage
                                
                                for _, signal in buy_signals.iterrows():
                                    # Vérifier le cooldown (3 minutes = 180 secondes)
                                    signal_key = f"automonitor_{signal['symbol']}_{datetime.now().strftime('%H:%M')}"
                                    last_signal_ts = st.session_state.last_notifications.get(signal_key, 0)
                                    now_ts = datetime.now().timestamp()
                                    
                                    # Respecter cooldown selon mode (10m scalp, 20m swing)
                                    cooldown_sec = int(st.session_state.get('cooldown_sec', 600))
                                    if now_ts - last_signal_ts >= cooldown_sec:
                                        # Calculer l'heure d'expiration (4 heures après l'émission)
                                        signal_time = datetime.now()
                                        expiration_time = signal_time + timedelta(hours=4)
                                        
                                        # Rafraîchir le prix en temps réel juste avant envoi
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

                                        # Vérifier Risk/Reward minimal selon mode
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
                                            print(f"⛔ RR insuffisant ({rr:.2f} < {rr_min:.2f}) pour {signal['symbol']}")
                                            continue
                                        
                                        # Format du message WhatsApp
                                        signal_emoji = "🟢" if signal['signal'] == 'BUY' else "🔴"
                                        whatsapp_text = f"""{signal_emoji} SIGNAL {signal['signal']} {signal['symbol']}
📊 Timeframe: {tf_for_scan}
🎯 Confluence: {signal['confluence']}%
💪 Confiance: {signal['confidence']}%
💰 Prix d'entrée: {entry_for_msg:.5f}
🎯 Take Profit: {tp_for_msg:.5f}
🛡️ Stop Loss: {sl_for_msg:.5f}
📝 Raison: {signal['reason']}
⏰ Émis: {signal_time.strftime('%H:%M:%S')}
⏳ Expire: {expiration_time.strftime('%H:%M:%S')}"""
                                        
                                        # Envoi WhatsApp
                                        if st.session_state.get('notify_whatsapp', True):
                                            try:
                                                result_wa = send_whatsapp_message_unified(whatsapp_text)
                                                # Considérer succès si True ou dict sans error
                                                is_success = False
                                                if result_wa is True:
                                                    is_success = True
                                                elif isinstance(result_wa, dict) and result_wa.get('status') not in ['error','failed']:
                                                    is_success = True
                                                if is_success:
                                                    st.success(f"📱 WhatsApp envoyé: {signal['symbol']}")
                                                    print(f"✅ WhatsApp envoyé pour {signal['symbol']}: {whatsapp_text}")
                                                else:
                                                    print(f"❌ Échec WhatsApp pour {signal['symbol']}: {result_wa}")
                                            except Exception as e:
                                                st.error(f"❌ Erreur WhatsApp {signal['symbol']}: {e}")
                                                print(f"❌ Exception WhatsApp {signal['symbol']}: {e}")
                                        
                                        # Envoi SMS
                                        if st.session_state.get('notify_sms'):
                                            try:
                                                sms_text = f"""{signal_emoji} {signal['signal']} {signal['symbol']}
⏰ {datetime.now().strftime('%H:%M')}
🎯 {signal['confluence']}% confluence
💰 Entrée: {signal.get('entry_price', 0):.5f}
🎯 TP: {signal.get('tp_price', 0):.5f}
🛡️ SL: {signal.get('sl_price', 0):.5f}"""
                                                
                                                result_sms = send_sms_vonage(sms_text)
                                                if result_sms and result_sms.get('messages', [{}])[0].get('status') == '0':
                                                    st.success(f"📱 SMS envoyé: {signal['symbol']}")
                                            except Exception as e:
                                                st.error(f"❌ Erreur SMS {signal['symbol']}: {e}")
                                        
                                        # Mettre à jour le timestamp
                                        st.session_state.last_notifications[signal_key] = now_ts
                            except Exception as e:
                                st.error(f"❌ Erreur notifications: {e}")
                            
                            # Afficher les signaux dans des colonnes
                            cols = st.columns(min(2, len(buy_signals)))
                            for idx, (_, signal) in enumerate(buy_signals.iterrows()):
                                with cols[idx % 2]:
                                    signal_emoji = "🟢" if signal['signal'] == 'BUY' else "🔴"
                                    signal_time = datetime.now()
                                    expiration_time = signal_time + timedelta(hours=4)
                                    
                                    st.markdown(f"""
                                    <div style="border: 2px solid {'#00ff00' if signal['signal'] == 'BUY' else '#ff0000'}; padding: 10px; border-radius: 8px; margin: 5px 0;">
                                        <h4>{signal_emoji} {signal['signal']} {signal['symbol']}</h4>
                                        <p><strong>📊 Timeframe:</strong> {tf_for_scan}</p>
                                        <p><strong>🎯 Probabilité:</strong> {signal['confluence']}%</p>
                                        <p><strong>💪 Confiance:</strong> {signal['confidence']}%</p>
                                        <p><strong>💰 Entrée:</strong> {signal.get('entry_price', 0):.5f}</p>
                                        <p><strong>🎯 TP:</strong> {signal.get('tp_price', 0):.5f}</p>
                                        <p><strong>🛡️ SL:</strong> {signal.get('sl_price', 0):.5f}</p>
                                        <p><strong>📝 Raison:</strong> {signal['reason']}</p>
                                        <p><strong>⏰ Émis:</strong> {signal_time.strftime('%H:%M:%S')}</p>
                                        <p><strong>⏳ Expire:</strong> {expiration_time.strftime('%H:%M:%S')}</p>
                                    </div>
                                    """, unsafe_allow_html=True)
                        else:
                            st.info("ℹ️ Aucun signal de trading détecté. Tous les symboles sont en HOLD.")
                        
                        # Afficher le tableau complet avec filtres
                        st.subheader("📋 Tableau détaillé")
                        
                        # Filtres pour le tableau
                        col_filter1, col_filter2 = st.columns(2)
                        with col_filter1:
                            signal_filter = st.selectbox("Filtrer par signal", ["Tous", "BUY", "SELL", "HOLD"], key="signal_filter")
                        with col_filter2:
                            min_confluence = st.slider("Probabilité minimum", 0, 100, 0, key="min_confluence")
                        
                        # Appliquer les filtres
                        filtered_df = df_res.copy()
                        if signal_filter != "Tous":
                            filtered_df = filtered_df[filtered_df['signal'] == signal_filter]
                        filtered_df = filtered_df[filtered_df['confluence'] >= min_confluence]
                        
                        # Afficher le tableau filtré
                        if not filtered_df.empty:
                            # S'assurer que toutes les colonnes nécessaires existent
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
                                    "confluence": st.column_config.NumberColumn("Probabilité %", format="%.0f"),
                                    "confidence": st.column_config.NumberColumn("Confiance %", format="%.0f"),
                                    "entry_price": st.column_config.NumberColumn("Prix Entrée", format="%.5f"),
                                    "tp_price": st.column_config.NumberColumn("Take Profit", format="%.5f"),
                                    "sl_price": st.column_config.NumberColumn("Stop Loss", format="%.5f"),
                                    "reason": "Raison"
                                }
                        )
            else:
                st.info("Aucun résultat ne correspond aux filtres sélectionnés.")
        
        except Exception as e:
            st.error(f"Erreur dans l'AutoMonitor : {e}")

# Section supprimée - Alertes Spike désactivées
        
        # Section spéciale pour les indices synthétiques
        if symbol and ('Boom' in symbol or 'Crash' in symbol or 'Volatility' in symbol):
            st.subheader("🎯 Analyse Indices Synthétiques")
            
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.info("**🔥 BOOM/CRASH**")
                st.write("• Volatilité extrême")
                st.write("• Mouvements rapides")
                st.write("• Risque élevé")
            
            with col2:
                st.warning("**⚠️ RÈGLES STRICTES**")
                st.write("• SL: 5-10 points max")
                st.write("• TP: 15-25 points")
                st.write("• Max 3 trades/jour")
            
            with col3:
                st.success("**📊 SIGNALS**")
                if not st.session_state.real_time_data.empty:
                    # Calculer les signaux spécifiques
                    if 'rsi' in st.session_state.real_time_data.columns:
                        rsi_val = st.session_state.real_time_data['rsi'].iloc[-1]
                        if rsi_val < 30:
                            st.error("🟢 SIGNAL ACHAT (RSI < 30)")
                        elif rsi_val > 70:
                            st.error("🔴 SIGNAL VENTE (RSI > 70)")
                        else:
                            st.info("⚪ ATTENDRE")
                    else:
                        st.info("Calcul en cours...")
        
        # Analyse technique en temps réel
        st.subheader("🔍 Analyse Technique")
        
        # Debug: afficher les colonnes disponibles
        if not st.session_state.real_time_data.empty:
            available_cols = [col for col in st.session_state.real_time_data.columns if any(indicator in col.lower() for indicator in ['rsi', 'macd', 'bb'])]
            if available_cols:
                st.info(f"📊 Colonnes techniques disponibles: {', '.join(available_cols)}")
        
        col1, col2 = st.columns(2)
        
        with col1:
            # Essayer différentes colonnes RSI possibles
            rsi_value = None
            for rsi_col in ['RSI', 'rsi', 'rsi_14']:
                if rsi_col in st.session_state.real_time_data.columns and len(st.session_state.real_time_data) >= 14:
                    rsi_value = st.session_state.real_time_data[rsi_col].iloc[-1]
                    break
            
            if rsi_value is not None and not pd.isna(rsi_value):
                st.metric("RSI", f"{rsi_value:.2f}")
                
                if rsi_value > 70:
                    st.warning("📈 Suralimenté (RSI > 70)")
                elif rsi_value < 30:
                    st.info("📉 Survente (RSI < 30)")
                else:
                    st.success("✅ RSI normal")
            else:
                st.metric("RSI", "N/A")
        
        with col2:
            # Essayer différentes colonnes MACD possibles
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
                    st.success("📈 Signal haussier")
                else:
                    st.error("📉 Signal baissier")
            else:
                st.metric("MACD", "N/A")
                st.metric("Signal", "N/A")
        
        # Prédictions de spikes (flèches) – configurable
        with st.expander("🚀 Prédictions de Spikes (arrows)", expanded=False):
            if 'show_spike_predictions' not in st.session_state:
                st.session_state['show_spike_predictions'] = True
            _show_spikes = st.checkbox(
                "Afficher les prédictions de spikes (flèches)", value=st.session_state['show_spike_predictions'], key="show_spike_predictions"
            )
            _ = st.slider(
                "Seuil de confiance spike (%)", min_value=60, max_value=99, value=st.session_state.get('spike_threshold', 85), step=1, key="spike_threshold_slider"
            )
            # Ultra-sensible + filtre min pips
            if 'spike_ultra_sensitive' not in st.session_state:
                st.session_state['spike_ultra_sensitive'] = False
            if 'spike_min_pips' not in st.session_state:
                st.session_state['spike_min_pips'] = 2
            st.checkbox("Mode ultra-sensible (détection micro-spikes)", value=st.session_state['spike_ultra_sensitive'], key="spike_ultra_sensitive")
            st.slider("Taille minimale (pips)", min_value=0, max_value=20, value=int(st.session_state['spike_min_pips']), step=1, key="spike_min_pips")
        
        # Boutons de contrôle
        col1, col2 = st.columns(2)
        
        with col1:
            if st.button("🔄 Mettre à jour maintenant"):
                update_real_time_data()
                st.rerun()
        
        with col2:
            if st.button("🤖 Entraîner ML") and len(st.session_state.real_time_data) >= 100:
                with st.spinner("🤖 Entraînement des modèles ML..."):
                    try:
                        st.session_state.ml_predictor.train_models(st.session_state.real_time_data)
                        st.success("✅ Modèles ML entraînés avec succès!")
                        st.rerun()
                    except Exception as e:
                        st.error(f"❌ Erreur lors de l'entraînement: {e}")
            elif len(st.session_state.real_time_data) < 100:
                st.button("🤖 Entraîner ML", disabled=True, help=f"Besoin de 100 bougies (actuellement: {len(st.session_state.real_time_data)})")
        
        # État des modèles ML
        if len(st.session_state.real_time_data) >= 50:
            st.subheader("🤖 État des Modèles ML")
            
            col1, col2, col3 = st.columns(3)
            
            with col1:
                if st.session_state.ml_predictor.is_trained:
                    st.success("✅ Modèles ML entraînés")
                else:
                    st.warning("⚠️ Modèles ML non entraînés")
            
            with col2:
                st.info(f"📊 Données disponibles: {len(st.session_state.real_time_data)} bougies")
            
            with col3:
                if len(st.session_state.real_time_data) >= 100:
                    st.success("✅ Suffisamment de données pour l'entraînement")
                else:
                    st.warning(f"⚠️ Besoin de {100 - len(st.session_state.real_time_data)} bougies supplémentaires")
        
        # Signaux ML avancés et setups de trading
        if len(st.session_state.real_time_data) >= 50:
            st.subheader("🤖 Signaux ML Avancés & Setups de Trading")
            
            try:
                # Détecter les setups d'abord
                setups = st.session_state.setup_detector.detect_all_setups(st.session_state.real_time_data)
                
                # Générer les signaux ML (avec gestion d'erreur si pas entraîné)
                try:
                    ml_signals = st.session_state.ml_predictor.get_trading_signals(st.session_state.real_time_data)
                except ValueError as e:
                    if "doivent être entraînés" in str(e):
                        # Essayer d'entraîner les modèles si on a assez de données
                        if len(st.session_state.real_time_data) >= 100:
                            with st.spinner("🤖 Entraînement des modèles ML en cours..."):
                                try:
                                    st.session_state.ml_predictor.train_models(st.session_state.real_time_data)
                                    ml_signals = st.session_state.ml_predictor.get_trading_signals(st.session_state.real_time_data)
                                    st.success("✅ Modèles ML entraînés avec succès!")
                                except Exception as train_error:
                                    st.warning(f"⚠️ Erreur lors de l'entraînement: {train_error}")
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
                            # Pas assez de données pour l'entraînement, utiliser des signaux basiques
                            ml_signals = {
                                'overall_signal': 'HOLD',
                                'spike': 'LOW_SPIKE_RISK',
                                'spike_strength': 0.3,
                                'breakout': 'NO_BREAKOUT',
                                'breakout_strength': 0.4,
                                'amplitude': 'LOW_VOLATILITY',
                                'amplitude_strength': 0.3
                            }
                            st.info(f"🤖 Collecte de données en cours... ({len(st.session_state.real_time_data)}/100 bougies pour l'entraînement ML)")
                    else:
                        raise e
                
                # Afficher les signaux principaux
                col1, col2, col3, col4 = st.columns(4)
                
                with col1:
                    signal = ml_signals.get('overall_signal', 'HOLD')
                    if signal == 'STRONG_BUY':
                        st.success("🟢 **STRONG BUY**")
                    elif signal == 'BUY':
                        st.success("🟢 **BUY**")
                    elif signal == 'SELL':
                        st.error("🔴 **SELL**")
                    elif signal == 'STRONG_SELL':
                        st.error("🔴 **STRONG SELL**")
                    elif signal == 'SPIKE_WARNING':
                        st.warning("⚠️ **SPIKE WARNING**")
                    else:
                        st.info("⚪ **HOLD**")
                
                with col2:
                    spike_risk = ml_signals.get('spike', 'LOW_SPIKE_RISK')
                    spike_strength = ml_signals.get('spike_strength', 0.5)
                    if spike_risk == 'HIGH_SPIKE_RISK':
                        st.error(f"🚨 **HIGH SPIKE RISK** ({spike_strength:.1%})")
                    elif spike_risk == 'MEDIUM_SPIKE_RISK':
                        st.warning(f"⚠️ **MEDIUM SPIKE RISK** ({spike_strength:.1%})")
                    else:
                        st.success(f"✅ **LOW SPIKE RISK** ({spike_strength:.1%})")
                
                with col3:
                    breakout = ml_signals.get('breakout', 'NO_BREAKOUT')
                    breakout_strength = ml_signals.get('breakout_strength', 0.5)
                    if breakout == 'BREAKOUT_LIKELY':
                        st.warning(f"📈 **BREAKOUT LIKELY** ({breakout_strength:.1%})")
                    else:
                        st.info(f"📊 **NO BREAKOUT** ({breakout_strength:.1%})")
                
                with col4:
                    amplitude = ml_signals.get('amplitude', 'LOW_VOLATILITY')
                    amplitude_strength = ml_signals.get('amplitude_strength', 0.5)
                    if amplitude == 'HIGH_VOLATILITY':
                        st.warning(f"📊 **HIGH VOLATILITY** ({amplitude_strength:.1%})")
                    else:
                        st.info(f"📉 **LOW VOLATILITY** ({amplitude_strength:.1%})")
                
                # Afficher les détails des setups
                with st.expander("📊 Détails des Setups de Trading"):
                    col1, col2 = st.columns(2)
                    
                    with col1:
                        st.write("**🎯 Signaux Techniques:**")
                        
                        # Moving Average
                        ma_setup = setups.get('moving_average', {})
                        if ma_setup.get('current_trend') == 1:
                            st.success(f"📈 MA Crossover: BULLISH (Force: {ma_setup.get('strength', 0):.3f})")
                        elif ma_setup.get('current_trend') == -1:
                            st.error(f"📉 MA Crossover: BEARISH (Force: {ma_setup.get('strength', 0):.3f})")
                        else:
                            st.info("📊 MA Crossover: NEUTRAL")
                        
                        # RSI
                        rsi_setup = setups.get('rsi', {})
                        rsi_value = rsi_setup.get('current_rsi', 50)
                        if rsi_value < 30:
                            st.success(f"📈 RSI: OVERSOLD ({rsi_value:.1f})")
                        elif rsi_value > 70:
                            st.error(f"📉 RSI: OVERBOUGHT ({rsi_value:.1f})")
                        else:
                            st.info(f"📊 RSI: NEUTRAL ({rsi_value:.1f})")
                        
                        # MACD
                        macd_setup = setups.get('macd', {})
                        macd_signal = macd_setup.get('signal', 'HOLD')
                        if macd_signal == 'BUY':
                            st.success("📈 MACD: BULLISH")
                        elif macd_signal == 'SELL':
                            st.error("📉 MACD: BEARISH")
                        else:
                            st.info("📊 MACD: NEUTRAL")
                    
                    with col2:
                        st.write("**🎯 Signaux de Breakout:**")
                        
                        # Bollinger Bands
                        bb_setup = setups.get('bollinger_bands', {})
                        bb_position = bb_setup.get('current_bb_position', 0.5)
                        if bb_position < 0.2:
                            st.success(f"📈 BB: OVERSOLD ({bb_position:.2f})")
                        elif bb_position > 0.8:
                            st.error(f"📉 BB: OVERBOUGHT ({bb_position:.2f})")
                        else:
                            st.info(f"📊 BB: NEUTRAL ({bb_position:.2f})")
                        
                        # Donchian Channels
                        donchian_setup = setups.get('donchian_channels', {})
                        donchian_position = donchian_setup.get('current_position', 0.5)
                        if donchian_position > 0.8:
                            st.warning(f"📈 Donchian: NEAR BREAKOUT ({donchian_position:.2f})")
                        elif donchian_position < 0.2:
                            st.warning(f"📉 Donchian: NEAR BREAKDOWN ({donchian_position:.2f})")
                        else:
                            st.info(f"📊 Donchian: NEUTRAL ({donchian_position:.2f})")
                        
                        # Stochastic
                        stoch_setup = setups.get('stochastic', {})
                        stoch_k = stoch_setup.get('current_k', 50)
                        if stoch_k < 20:
                            st.success(f"📈 Stochastic: OVERSOLD ({stoch_k:.1f})")
                        elif stoch_k > 80:
                            st.error(f"📉 Stochastic: OVERBOUGHT ({stoch_k:.1f})")
                        else:
                            st.info(f"📊 Stochastic: NEUTRAL ({stoch_k:.1f})")
                        
                # Boom/Crash Momentum (nouveau)
                momentum_setup = setups.get('boom_crash_momentum', {})
                momentum_signal = momentum_setup.get('signal', 'HOLD')
                momentum_strength = momentum_setup.get('strength', 0.5)
                is_spike = momentum_setup.get('is_spike', False)
                spike_direction = momentum_setup.get('spike_direction', 'NONE')

                if momentum_signal == 'BUY':
                    if is_spike:
                        st.success(f"🚀 SPIKE UP DETECTED! ({spike_direction}) - Force: {momentum_strength:.2f}")
                    else:
                        st.success(f"📈 Momentum: BULLISH - Force: {momentum_strength:.2f}")
                elif momentum_signal == 'SELL':
                    if is_spike:
                        st.error(f"💥 SPIKE DOWN DETECTED! ({spike_direction}) - Force: {momentum_strength:.2f}")
                    else:
                        st.error(f"📉 Momentum: BEARISH - Force: {momentum_strength:.2f}")
                else:
                    st.info(f"📊 Momentum: NEUTRAL - Force: {momentum_strength:.2f}")
                
                # Prédiction avancée des spikes supprimée
                
                # Recommandations de trading
                recommendations = st.session_state.setup_detector.get_trading_recommendations(st.session_state.real_time_data)
                
                with st.expander("💡 Recommandations de Trading"):
                    st.write(f"**Action recommandée:** {recommendations['action']}")
                    st.write(f"**Confiance:** {recommendations['confidence']:.1%}")
                    st.write(f"**Score composite:** {recommendations['score']}")
                    
                    if recommendations['entry_strategy'] != 'N/A':
                        st.write(f"**Stratégie d'entrée:** {recommendations['entry_strategy']}")
                        st.write(f"**Stop Loss:** {recommendations['stop_loss']}")
                        st.write(f"**Take Profit:** {recommendations['take_profit']}")
                    
                    st.write("**Signaux détectés:**")
                    for signal in recommendations['signals']:
                        st.write(f"• {signal}")
                
            except Exception as e:
                st.error(f"Erreur lors de la génération des signaux ML: {e}")
        else:
            st.info("Collecte de données en cours... (minimum 50 bougies requis pour l'analyse ML)")
        
        # Section spéciale pour les indices synthétiques Boom/Crash
        if symbol and any(indice in symbol for indice in ['Boom', 'Crash', 'Volatility']):
            st.subheader("🎯 Stratégies Spécialisées - Indices Synthétiques")
            
            try:
                # Analyser les données pour les indices synthétiques
                if len(st.session_state.real_time_data) >= 20:
                    # Détecter les setups si pas déjà fait
                    if 'setups' not in locals():
                        setups = st.session_state.setup_detector.detect_all_setups(st.session_state.real_time_data)
                    # Calculer les métriques spécifiques aux indices synthétiques
                    current_price = st.session_state.real_time_data['close'].iloc[-1]
                    volatility = st.session_state.real_time_data['close'].pct_change().std() * 100
                    
                    # Détecter les patterns de spike
                    price_changes = st.session_state.real_time_data['close'].pct_change().abs()
                    recent_volatility = price_changes.tail(10).mean() * 100
                    
                    col1, col2, col3 = st.columns(3)
                    
                    with col1:
                        st.metric("📊 Volatilité Actuelle", f"{recent_volatility:.2f}%")
                        if recent_volatility > 2:
                            st.warning("⚠️ Volatilité élevée - Risque de spike")
                        elif recent_volatility < 0.5:
                            st.info("📉 Volatilité faible - Range trading possible")
                        else:
                            st.success("✅ Volatilité normale")
                    
                    with col2:
                        # Détecter les patterns de Boom/Crash
                        if 'Boom' in symbol:
                            st.write("🚀 **BOOM INDEX**")
                            # Stratégie pour Boom
                            if recent_volatility > 1.5:
                                st.success("📈 Signal BOOM - Prêt pour une explosion")
                                st.write("**Stratégie:** Attendre un pullback vers support")
                            else:
                                st.info("⏳ Attendre l'accumulation")
                        elif 'Crash' in symbol:
                            st.write("💥 **CRASH INDEX**")
                            # Stratégie pour Crash
                            if recent_volatility > 1.5:
                                st.error("📉 Signal CRASH - Prêt pour une chute")
                                st.write("**Stratégie:** Attendre un pullback vers résistance")
                            else:
                                st.info("⏳ Attendre la distribution")
                        else:
                            st.write("📊 **VOLATILITY INDEX**")
                            # Stratégie pour Volatility
                            if recent_volatility > 2:
                                st.warning("📊 Volatilité extrême - Trading dangereux")
                            else:
                                st.success("✅ Volatilité contrôlée - Trading possible")
                    
                    with col3:
                        # Recommandations de gestion de risque
                        risk_summary = st.session_state.risk_manager.get_risk_summary()
                        
                        st.write("🛡️ **Gestion de Risque**")
                        if risk_summary['can_trade']:
                            st.success("✅ Trading autorisé")
                        else:
                            st.error("❌ Trading suspendu")
                        
                        st.write(f"**Pertes consécutives:** {risk_summary['consecutive_losses']}")
                        st.write(f"**Risque quotidien:** {risk_summary['daily_risk_used']:.1f}%")
                    
                    # Stratégies spécifiques selon le type d'indice
                    with st.expander("🎯 Stratégies Détaillées"):
                        if 'Boom' in symbol:
                            st.write("**🚀 Stratégie BOOM Index:**")
                            st.write("1. **Entrée:** RSI < 30 + prix sur support")
                            st.write("2. **Stop Loss:** 5 points maximum")
                            st.write("3. **Take Profit:** 15 points (ratio 1:3)")
                            st.write("4. **Timing:** Éviter les heures de faible volatilité")
                            
                        elif 'Crash' in symbol:
                            st.write("**💥 Stratégie CRASH Index:**")
                            st.write("1. **Entrée:** RSI > 70 + prix sur résistance")
                            st.write("2. **Stop Loss:** 5 points maximum")
                            st.write("3. **Take Profit:** 15 points (ratio 1:3)")
                            st.write("4. **Timing:** Éviter les heures de faible volatilité")
                            
                        else:
                            st.write("**📊 Stratégie VOLATILITY Index:**")
                            st.write("1. **Entrée:** Breakout des bandes de Bollinger")
                            st.write("2. **Stop Loss:** 2x ATR")
                            st.write("3. **Take Profit:** 3x ATR (ratio 1:1.5)")
                            st.write("4. **Timing:** Trading 24/7 possible")
                    
                    # Alertes de trading
                    with st.expander("🚨 Alertes de Trading"):
                        # Vérifier les conditions d'alerte
                        alerts = []
                        
                        # Alerte RSI
                        rsi_setup = setups.get('rsi', {})
                        rsi_value = rsi_setup.get('current_rsi', 50)
                        if rsi_value < 30:
                            alerts.append("🟢 RSI OVERSOLD - Signal d'achat")
                        elif rsi_value > 70:
                            alerts.append("🔴 RSI OVERBOUGHT - Signal de vente")
                        
                        # Alerte volatilité
                        if recent_volatility > 3:
                            alerts.append("⚠️ VOLATILITÉ EXTRÊME - Risque élevé")
                        elif recent_volatility < 0.3:
                            alerts.append("📉 VOLATILITÉ FAIBLE - Range trading")
                        
                        # Alerte breakout
                        bb_setup = setups.get('bollinger_bands', {})
                        bb_position = bb_setup.get('current_bb_position', 0.5)
                        if bb_position < 0.1:
                            alerts.append("📈 PRÈS DU SUPPORT - Signal d'achat")
                        elif bb_position > 0.9:
                            alerts.append("📉 PRÈS DE LA RÉSISTANCE - Signal de vente")
                        
                        if alerts:
                            for alert in alerts:
                                st.warning(alert)
                        else:
                            st.info("Aucune alerte active")
                    
                    # Calculer les niveaux de support/résistance
                    if len(st.session_state.real_time_data) >= 50:
                        support_resistance = st.session_state.setup_detector.detect_support_resistance_zones(st.session_state.real_time_data)
                        
                        # Ajouter le tableau de tendance multi-timeframe
                        with st.expander("📈 Analyse de Tendance Multi-Timeframe"):
                            try:
                                import requests
                                trend_api_url = f"http://localhost:8000/trend_summary?symbol={selected_symbol}&nocache=1"
                                trend_response = requests.get(trend_api_url, timeout=15)
                                
                                if trend_response.status_code == 200:
                                    trend_data = trend_response.json()
                                    
                                    # Créer le tableau de tendance
                                    tf_order = ["1d", "8h", "6h", "4h", "1h", "30m", "15m", "5m", "1m"]
                                    tf_labels = ["D1", "H8", "H6", "H4", "H1", "M30", "M15", "M5", "M1"]
                                    
                                    # Préparer les données pour le tableau
                                    trend_table_data = []
                                    for tf in tf_order:
                                        tf_info = trend_data.get("trends", {}).get(tf, {})
                                        trend = (tf_info.get("trend") or "neutral").lower()
                                        force = tf_info.get("force")
                                        slope = tf_info.get("slope")
                                        rsi = tf_info.get("rsi")
                                        macd = tf_info.get("macd")
                                        
                                        # Formatage des valeurs
                                        # La force renvoyée par l'API est sur 0-100 → afficher en % entier
                                        # Normalisation valeurs par défaut
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
                                            trend_emoji = "🟢"
                                            trend_color = "green"
                                        elif trend == "bearish":
                                            trend_emoji = "🔴"
                                            trend_color = "red"
                                        elif trend == "neutral":
                                            trend_emoji = "⚪"
                                            trend_color = "gray"
                                        else:
                                            trend_emoji = "❓"
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
                                    
                                    # (Demandé) Ne pas afficher la synthèse globale; focus sur l'analyse par timeframe uniquement
                                
                                else:
                                    st.error(f"❌ Erreur API: {trend_response.status_code}")
                                    
                            except requests.exceptions.RequestException as e:
                                st.error(f"❌ Impossible de se connecter à l'API de tendance: {str(e)}")
                                st.info("💡 Assurez-vous que l'API de tendance est démarrée sur le port 8000")
                            except Exception as e:
                                st.error(f"❌ Erreur lors de l'analyse de tendance: {str(e)}")

                        # Ajouter la fenêtre de chat Gemma
                        with st.expander("🤖 Chat Trading IA - Gemma"):
                            from backend.gemma_trading_chat import gemma_chat
                            
                            # Chargement à la demande pour éviter de bloquer l'UI
                            if 'gemma_initialized' not in st.session_state:
                                st.info("L'IA Gemma est optionnelle et lourde à charger. Chargez-la seulement si nécessaire.")
                                col_g1, col_g2 = st.columns([1,1])
                                with col_g1:
                                    want_load = st.checkbox("Activer Gemma (expérimental)", key="gemma_enable")
                                with col_g2:
                                    if want_load and st.button("Charger le modèle", key="gemma_load_btn"):
                                        with st.spinner("🔄 Chargement du modèle Gemma (peut prendre 1-2 minutes)..."):
                                            pass
                                    if gemma_chat.load_model():
                                        st.session_state.gemma_initialized = True
                                        st.success("✅ Modèle Gemma chargé avec succès!")
                                    else:
                                                st.warning("⚠️ Passage en mode simulation (MOCK). L'IA répondra sans charger le modèle.")
                                                st.session_state.gemma_initialized = True
                            
                            # Mettre à jour le contexte de trading
                            trading_data = {
                                "current_price": st.session_state.real_time_data['close'].iloc[-1] if not st.session_state.real_time_data.empty else 0,
                                "indicators": {
                                    "rsi": st.session_state.real_time_data['rsi_14'].iloc[-1] if 'rsi_14' in st.session_state.real_time_data.columns else 50,
                                    "macd": st.session_state.real_time_data['macd'].iloc[-1] if 'macd' in st.session_state.real_time_data.columns else 0,
                                    "bb_position": st.session_state.real_time_data['bb_position'].iloc[-1] if 'bb_position' in st.session_state.real_time_data.columns else 0.5
                                },
                                "ml_signals": st.session_state.ml_signals if hasattr(st.session_state, 'ml_signals') else {},
                                "trend_analysis": {},  # Sera rempli par l'API
                                "support_resistance": support_resistance,
                                "setup_detection": st.session_state.setup_detector.detect_all_setups(st.session_state.real_time_data) if hasattr(st.session_state, 'setup_detector') else {},
                                "volatility": {
                                    "atr": st.session_state.real_time_data['atr'].iloc[-1] if 'atr' in st.session_state.real_time_data.columns else 0
                                }
                            }
                            
                            gemma_chat.update_trading_context(selected_symbol, "1m", trading_data)
                            
                            # Bandeau statut modèle + actions
                            status = gemma_chat.get_status()
                            status_icon = "🟢" if status.get("ready") else "⚪"
                            if status.get("mode") == "mock":
                                status_icon = "🟡"
                            st.markdown(f"**Statut modèle:** {status_icon} {status.get('mode','unloaded')} ({status.get('device')})")
                            if status.get('last_error'):
                                st.caption(f"Dernière erreur: {status['last_error']}")
                            col_act1, col_act2, col_act3 = st.columns([1,1,1])
                            with col_act1:
                                if st.button("🧹 Effacer l'historique", key="gemma_clear_history"):
                                    gemma_chat.clear_history()
                                    st.success("Historique effacé")
                            with col_act2:
                                if st.button("🔄 Recharger le modèle", key="gemma_reload_model"):
                                    with st.spinner("Chargement du modèle..."):
                                        gemma_chat.load_model()
                            with col_act3:
                                if st.button("⚡ Forcer Gemini", key="gemma_force_gemini"):
                                    with st.spinner("Bascule vers Gemini..."):
                                        gemma_chat.use_gemini()
                                        st.success("Provider: Gemini (Flash)")
                            
                            # Interface de chat
                            st.subheader("💬 Chat avec l'IA Trading")

                            # Upload d'image pour analyse du graphique (Gemini Vision via API)
                            st.caption("Optionnel: uploadez une capture de votre graphique pour extraction (symbol, TF, S/R, patterns)")
                            chart_file = st.file_uploader("Capture d'écran du graphique (PNG/JPG)", type=["png","jpg","jpeg"], key="chart_upload")
                            if chart_file is not None and st.button("🔎 Analyser l'image", key="analyze_chart_btn"):
                                import base64
                                try:
                                    img_bytes = chart_file.read()
                                    b64 = base64.b64encode(img_bytes).decode()
                                    mime = chart_file.type or "image/png"
                                    payload = {"image_base64": b64, "mime_type": mime, "filename": chart_file.name}
                                    resp = requests.post("http://localhost:8000/analyze_chart", json=payload, timeout=30)
                                    if resp.status_code == 200:
                                        vision = resp.json()
                                        st.success("Image analysée")
                                        # Afficher un résumé lisible des résultats Vision
                                        st.markdown("#### 🖼️ Résultats de l'analyse d'image")
                                        vis_symbol = vision.get("symbol")
                                        vis_tf = vision.get("timeframe")
                                        vis_patterns = vision.get("patterns") or []
                                        vis_support = vision.get("support_zones") or []
                                        vis_resist = vision.get("resistance_zones") or []
                                        cols = st.columns(4)
                                        cols[0].metric("Symbole", vis_symbol if vis_symbol else "?")
                                        cols[1].metric("Timeframe", vis_tf if vis_tf else "?")
                                        cols[2].metric("Supports", len(vis_support))
                                        cols[3].metric("Résistances", len(vis_resist))
                                        if vis_patterns:
                                            st.caption("Patterns détectés: " + ", ".join([str(p) for p in vis_patterns][:6]))
                                        # Afficher le brut en debug si rien d'extrait
                                        if (not vis_symbol and not vis_tf and not vis_support and not vis_resist) and vision.get("raw"):
                                            with st.expander("Voir la sortie brute (debug)"):
                                                st.code(vision.get("raw"))
                                        # Tables simples des niveaux si fournis
                                        try:
                                            import pandas as pd
                                            if isinstance(vis_support, list) and vis_support:
                                                df_sup = pd.DataFrame({"Support": vis_support})
                                                st.dataframe(df_sup, hide_index=True, use_container_width=True)
                                            if isinstance(vis_resist, list) and vis_resist:
                                                df_res = pd.DataFrame({"Résistance": vis_resist})
                                                st.dataframe(df_res, hide_index=True, use_container_width=True)
                                        except Exception:
                                            pass
                                        # Fusionner dans le contexte
                                        trading_data["vision"] = vision
                                        # Mettre à jour supports/résistances si fournis
                                        if isinstance(vision, dict):
                                            sr = trading_data.get("support_resistance", {})
                                            if "support_zones" in vision:
                                                sr["support_zones"] = vision.get("support_zones") or sr.get("support_zones", [])
                                            if "resistance_zones" in vision:
                                                sr["resistance_zones"] = vision.get("resistance_zones") or sr.get("resistance_zones", [])
                                            trading_data["support_resistance"] = sr
                                        gemma_chat.update_trading_context(selected_symbol, "1m", trading_data)
                                    else:
                                        st.error(f"Erreur /analyze_chart: {resp.status_code}")
                                except Exception as e:
                                    st.error(f"Erreur analyse image: {e}")
                            
                            # Zone de saisie
                            user_input = st.text_input(
                                "Posez votre question à l'IA:",
                                placeholder="Ex: Analyse la situation et propose un signal de trading",
                                key="gemma_user_input"
                            )
                            send_clicked = st.button("✉️ Envoyer", key="gemma_send")
                            
                            col1, col2 = st.columns([1, 1])
                            
                            with col1:
                                if st.button("🚀 Analyser & Proposer Signal", key="gemma_analyze") or send_clicked:
                                    if user_input:
                                        with st.spinner("🤖 L'IA analyse la situation..."):
                                            # enrichir le contexte avec l'analyse de tendance API
                                            try:
                                                trend_api_url = f"http://localhost:8000/trend_summary?symbol={selected_symbol}&nocache=1"
                                                _resp = requests.get(trend_api_url, timeout=10)
                                                if _resp.status_code == 200:
                                                    trend_payload = _resp.json()
                                                    trading_data["trend_analysis"] = trend_payload
                                                    gemma_chat.update_trading_context(selected_symbol, st.session_state.current_timeframe if 'current_timeframe' in st.session_state else "1m", trading_data)
                                            except Exception:
                                                pass
                                            response = gemma_chat.generate_trading_analysis(user_input)
                                            signal_info = gemma_chat.extract_trading_signal(response)
                                            gemma_chat.add_to_chat_history(user_input, response, signal_info)
                                            
                                            # Afficher la réponse
                                            st.markdown("### 🤖 Réponse de l'IA:")
                                            st.markdown(response)
                                            
                                            # Afficher la Signal Card compacte (toujours)
                                            st.markdown("### 📊 Signal de Trading")
                                            badge = "🟢" if signal_info["signal"].upper() == "BUY" else ("🔴" if signal_info["signal"].upper() == "SELL" else "⚪")
                                            st.markdown(f"**{badge} {signal_info['signal']}** · {signal_info['type']} · confiance {signal_info['confidence']:.0f}%")

                                            # Contraintes P/L: TP ≥ +10 pips, SL ≤ -2 pips
                                            entry = float(signal_info.get('price') or 0)
                                            tp_val = float(signal_info.get('tp') or entry)
                                            sl_val = float(signal_info.get('sl') or entry)
                                            # Taille de pip heuristique
                                            if any(x in selected_symbol for x in ['JPY', 'Index', 'Boom', 'Crash']):
                                                pip = 0.01
                                                    else:
                                                pip = 0.0001
                                            side = str(signal_info.get('signal', '')).upper()
                                            if side in ['BUY','SELL'] and entry > 0:
                                                if side == 'BUY':
                                                    tp_target = entry + 10 * pip
                                                    sl_target = entry - 2 * pip
                                                else:
                                                    tp_target = entry - 10 * pip
                                                    sl_target = entry + 2 * pip
                                                # Appliquer les contraintes
                                                tp_val = tp_target
                                                sl_val = sl_target
                                                tp_pips = abs((tp_val - entry) / pip)
                                                sl_pips = abs((sl_val - entry) / pip)
                                            else:
                                                tp_pips = abs((tp_val - entry) / pip) if entry > 0 else 0
                                                sl_pips = abs((sl_val - entry) / pip) if entry > 0 else 0

                                            col_p1, col_p2, col_p3 = st.columns(3)
                                            col_p1.metric("Entrée", f"{entry:.5f}")
                                            col_p2.metric("TP", f"{tp_val:.5f} (+{tp_pips:.0f} pips)")
                                            col_p3.metric("SL", f"{sl_val:.5f} (-{sl_pips:.0f} pips)")
                                            st.caption("Lots: 0.01 · Règle: TP ≥ 10 pips, SL ≤ 2 pips")
                                            
                                            # Les notifications IA sont désactivées - focus sur les spikes uniquement
                                            st.info("ℹ️ Notifications IA désactivées - Seuls les signaux Spike sont envoyés")
                            
                            with col2:
                                if st.button("📊 Analyse Automatique", key="gemma_auto"):
                                    with st.spinner("🤖 Analyse automatique en cours..."):
                                        response = gemma_chat.generate_trading_analysis("Analyse automatique de la situation de trading actuelle")
                                        signal_info = gemma_chat.extract_trading_signal(response)
                                        gemma_chat.add_to_chat_history("Analyse automatique", response, signal_info)
                                        
                                        st.markdown("### 🤖 Analyse Automatique:")
                                        st.markdown(response)
                            
                            # Historique du chat
                            if gemma_chat.chat_history:
                                st.subheader("📜 Historique du Chat")
                                for i, chat in enumerate(reversed(gemma_chat.chat_history[-5:])):  # Afficher les 5 derniers
                                    with st.expander(f"💬 Chat {len(gemma_chat.chat_history) - i} - {chat['timestamp'][:19]}"):
                                        st.write("**👤 Utilisateur:**", chat['user'])
                                        st.write("**🤖 IA:**", chat['bot'])
                                        if chat['signal']['signal'] != "HOLD":
                                            st.write("**📊 Signal:**", f"{chat['signal']['signal']} - {chat['signal']['type']}")

                        with st.expander("📊 Zones de Support/Résistance Confirmées"):
                            # Afficher la confiance
                            confidence = support_resistance.get('confidence', 'low')
                            if confidence == 'high':
                                st.success("✅ Zones confirmées avec haute confiance")
                            else:
                                st.warning("⚠️ Zones en cours de validation")
                            
                            col1, col2 = st.columns(2)
                            
                            with col1:
                                st.write("**Zones de Support:**")
                                support_zones = support_resistance.get('support_zones', [])
                                if support_zones:
                                    for i, zone in enumerate(support_zones[:3]):  # Afficher les 3 plus fortes
                                        zone_range = zone['upper'] - zone['lower']
                                        zone_pips = zone_range / (st.session_state.real_time_data['close'].iloc[-1] * 0.0001)
                                        confidence = zone.get('confidence', 0.0)
                                        is_high_confidence = zone.get('is_high_confidence', False)
                                        
                                        # Style selon la confiance
                                        if is_high_confidence:
                                            st.markdown(f"**🎯 Zone {i+1} - CONFIRMÉE {confidence:.0%}**")
                                            st.markdown(f"💰 **Niveau:** {zone['level']:.5f}")
                                            st.markdown(f"📏 **Range:** {zone['lower']:.5f} - {zone['upper']:.5f}")
                                            st.markdown(f"📐 **Largeur:** {zone_pips:.1f} pips")
                                            st.markdown(f"💪 **Force:** {zone['strength']:.2f}")
                                            st.markdown(f"🔢 **Touches:** {zone['touches']}")
                                            st.success("🔥 ZONE HAUTE CONFIANCE - PRIORITÉ MAXIMALE!")
                                        else:
                                            st.write(f"**Zone {i+1}:**")
                                            st.write(f"💰 Niveau: {zone['level']:.5f}")
                                            st.write(f"📏 Range: {zone['lower']:.5f} - {zone['upper']:.5f}")
                                            st.write(f"📐 Largeur: {zone_pips:.1f} pips")
                                            st.write(f"💪 Force: {zone['strength']:.2f}")
                                            st.write(f"🔢 Touches: {zone['touches']}")
                                            st.write(f"📊 Confiance: {confidence:.0%}")
                                        
                                        if zone_pips <= 4:
                                            st.success("✅ Zone précise (≤ 4 pips)")
                                        elif zone_pips <= 8:
                                            st.warning("⚠️ Zone acceptable (≤ 8 pips)")
                                        else:
                                            st.error("❌ Zone trop large (> 8 pips)")
                                        st.write("---")
                                else:
                                    st.write("Aucune zone de support confirmée détectée")
                            
                            with col2:
                                st.write("**Zones de Résistance:**")
                                resistance_zones = support_resistance.get('resistance_zones', [])
                                if resistance_zones:
                                    for i, zone in enumerate(resistance_zones[:3]):  # Afficher les 3 plus fortes
                                        zone_range = zone['upper'] - zone['lower']
                                        zone_pips = zone_range / (st.session_state.real_time_data['close'].iloc[-1] * 0.0001)
                                        confidence = zone.get('confidence', 0.0)
                                        is_high_confidence = zone.get('is_high_confidence', False)
                                        
                                        # Style selon la confiance
                                        if is_high_confidence:
                                            st.markdown(f"**🎯 Zone {i+1} - CONFIRMÉE {confidence:.0%}**")
                                            st.markdown(f"💰 **Niveau:** {zone['level']:.5f}")
                                            st.markdown(f"📏 **Range:** {zone['lower']:.5f} - {zone['upper']:.5f}")
                                            st.markdown(f"📐 **Largeur:** {zone_pips:.1f} pips")
                                            st.markdown(f"💪 **Force:** {zone['strength']:.2f}")
                                            st.markdown(f"🔢 **Touches:** {zone['touches']}")
                                            st.success("🔥 ZONE HAUTE CONFIANCE - PRIORITÉ MAXIMALE!")
                                        else:
                                            st.write(f"**Zone {i+1}:**")
                                            st.write(f"💰 Niveau: {zone['level']:.5f}")
                                            st.write(f"📏 Range: {zone['lower']:.5f} - {zone['upper']:.5f}")
                                            st.write(f"📐 Largeur: {zone_pips:.1f} pips")
                                            st.write(f"💪 Force: {zone['strength']:.2f}")
                                            st.write(f"🔢 Touches: {zone['touches']}")
                                            st.write(f"📊 Confiance: {confidence:.0%}")
                                        
                                        if zone_pips <= 4:
                                            st.success("✅ Zone précise (≤ 4 pips)")
                                        elif zone_pips <= 8:
                                            st.warning("⚠️ Zone acceptable (≤ 8 pips)")
                                        else:
                                            st.error("❌ Zone trop large (> 8 pips)")
                                        st.write("---")
                                else:
                                    st.write("Aucune zone de résistance confirmée détectée")
                
            except Exception as e:
                st.error(f"Erreur dans l'analyse des indices synthétiques: {e}")
    
            # Indicateurs modernes (2025)
            with st.expander("🧠 Indicateurs modernes (2025)", expanded=True):
                try:
                    base = "http://localhost:8000"
                    params = {"symbol": symbol, "timeframe": st.session_state.current_timeframe, "count": 200}
                    # Récupérer les indicateurs modernes avec gestion d'erreur
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

                    # Option debug: afficher les JSON bruts si nécessaire
                    show_raw = st.checkbox("👀 Voir les données brutes (debug)", value=False, key="indicators_show_raw")

                    # Résumé compact en un seul tableau en haut (toujours visible)
                    try:
                        import pandas as _pd
                        regime = (ms.get("regime") if isinstance(ms, dict) else None) or "?"
                        last_bos = (ms.get("bos") or [])[-1] if isinstance(ms, dict) and ms.get("bos") else None
                        bos_dir = (last_bos.get("direction") if last_bos else None) or "?"
                        bos_price = (last_bos.get("price") if last_bos else None)
                        ob_count = len(sm.get("order_blocks", [])) if isinstance(sm, dict) else 0
                        fvg_count = len(sm.get("fvg", [])) if isinstance(sm, dict) else 0
                        liq_count = len(sm.get("liquidity_pools", [])) if isinstance(sm, dict) else 0
                        squeeze_on = sq.get("squeeze_on") if isinstance(sq, dict) else None
                        bb_bw = sq.get("bb_bw") if isinstance(sq, dict) else None
                        bb_str = f"{bb_bw:.2%}" if isinstance(bb_bw, (int, float)) else str(bb_bw)
                        last_vwap = None
                        if isinstance(vw, dict) and vw.get("vwap"):
                            try:
                                last_vwap = vw["vwap"][-1]["value"]
                            except Exception:
                                last_vwap = None
                        trend_last = None
                        if isinstance(stn, dict) and stn.get("trend"):
                            try:
                                trend_last = stn["trend"][-1]
                            except Exception:
                                trend_last = None
                        pp = pv.get("pp") if isinstance(pv, dict) else None
                        df_summary = _pd.DataFrame([
                            {
                                "Régime": regime,
                                "BOS": bos_dir,
                                "Prix BOS": bos_price,
                                "OB": ob_count,
                                "FVG": fvg_count,
                                "Liq": liq_count,
                                "Squeeze": "ON" if squeeze_on else "OFF",
                                "BB%": bb_str,
                                "VWAP": last_vwap,
                                "Supertrend": ("UP" if trend_last == 1 else ("DOWN" if trend_last == -1 else "NEUTRE")),
                                "PP": pp,
                            }
                        ])
                        st.dataframe(df_summary, hide_index=True, use_container_width=True, height=80)
                    except Exception:
                        pass

                    # Fallback: afficher le JSON brut quand tables vides ou sur demande
                    if show_raw:
                        st.markdown("---")
                        st.caption("JSON brut des endpoints d'indicateurs")
                        st.json({
                            "market_structure": ms,
                            "smart_money": sm,
                            "vwap": vw,
                            "squeeze": sq,
                            "supertrend": stn,
                            "pivots": pv,
                        })

                    colA, colB = st.columns(2)

                    with colA:
                        st.markdown("**Structure de marché (BOS/CHOCH)**")
                        if isinstance(ms, dict) and ms.get("status") == "error":
                            st.warning(f"Market structure indisponible: {ms.get('detail')}")
                        else:
                            import pandas as _pd
                            regime = ms.get("regime", "unknown")
                            regime_emoji = {"trending": "📈", "mean_revert": "🔁"}.get(regime, "⚪")
                            last_bos = (ms.get("bos") or [])[-1:] or []
                            bos_dir = last_bos[0]["direction"].lower() if last_bos else "?"
                            bos_emoji = "⬆️" if bos_dir == "up" else ("⬇️" if bos_dir == "down" else "⚪")
                            bos_price = last_bos[0]["price"] if last_bos else None
                            df_ms = _pd.DataFrame([
                                {"Régime": f"{regime_emoji} {regime}", "Dernier BOS": f"{bos_emoji}", "Prix": bos_price}
                            ])
                            st.dataframe(df_ms, hide_index=True, use_container_width=True)

                        st.markdown("**Smart Money (OB/FVG)**")
                        if isinstance(sm, dict) and sm.get("status") == "error":
                            st.warning(f"Smart Money indisponible: {sm.get('detail')}")
                        else:
                            import pandas as _pd
                            ob = (sm.get("order_blocks") or [])[-3:]
                            fvg = (sm.get("fvg") or [])[-3:]
                            liq = (sm.get("liquidity_pools") or [])[-4:]
                            if ob:
                                for row in ob:
                                    row["Type"] = ("🟩" if row.get("type") == "bullish" else "🟥") + f" {row.get('type')}"
                                df_ob = _pd.DataFrame([{ "Type": r["Type"], "Bas": r.get("low"), "Haut": r.get("high") } for r in ob])
                                st.caption("Order Blocks")
                                st.dataframe(df_ob, hide_index=True, use_container_width=True)
                            if fvg:
                                for row in fvg:
                                    row["Type"] = ("🟩" if row.get("type") == "bullish" else "🟥") + f" {row.get('type')}"
                                df_fvg = _pd.DataFrame([{ "Type": r["Type"], "De": r.get("from"), "À": r.get("to") } for r in fvg])
                                st.caption("Fair Value Gaps")
                                st.dataframe(df_fvg, hide_index=True, use_container_width=True)
                            if liq:
                                for row in liq:
                                    row["Niveau"] = row.get("level")
                                    row["Type"] = ("💧 HAUTS ÉGAUX" if row.get("type") == "equal_highs" else "💧 BAS ÉGAUX")
                                df_liq = _pd.DataFrame([{ "Type": r["Type"], "Niveau": r["Niveau"] } for r in liq])
                                st.caption("Pools de liquidité")
                                st.dataframe(df_liq, hide_index=True, use_container_width=True)

                        st.markdown("**Squeeze / Volatilité**")
                        if isinstance(sq, dict) and sq.get("status") == "error":
                            st.warning(f"Squeeze indisponible: {sq.get('detail')}")
                        else:
                            on = bool(sq.get("squeeze_on"))
                            bb_bw = sq.get("bb_bw")
                            bb_str = f"{bb_bw:.2%}" if isinstance(bb_bw, (int,float)) else str(bb_bw)
                            st.metric("Squeeze", "🟢 ON" if on else "⚪ OFF")
                            st.metric("Bollinger Bandwidth", bb_str)
                    with colB:
                        st.markdown("**VWAP**")
                        if isinstance(vw, dict) and vw.get("status") == "error":
                            st.warning(f"VWAP indisponible: {vw.get('detail')}")
                        else:
                            try:
                                last_vwap = vw.get("vwap", [])[-1]["value"] if vw.get("vwap") else None
                            except Exception:
                                last_vwap = None
                            bands = ", ".join([str(b.get("k")) for b in (vw.get("bands") or [])])
                            import pandas as _pd
                            df_vwap = _pd.DataFrame([{ "VWAP": last_vwap, "Bands": bands }])
                            st.dataframe(df_vwap, hide_index=True, use_container_width=True)
                        st.markdown("**Supertrend**")
                        if isinstance(stn, dict) and stn.get("status") == "error":
                            st.warning(f"Supertrend indisponible: {stn.get('detail')}")
                        else:
                            trend_last = None
                            try:
                                trend_last = (stn.get("trend") or [])[-1]
                            except Exception:
                                trend_last = None
                            st.metric("Direction", "🟢 HAUSSE" if trend_last == 1 else ("🔴 BAISSE" if trend_last == -1 else "⚪ NEUTRE"))
                        st.markdown("**Pivots**")
                        if isinstance(pv, dict) and pv.get("status") == "error":
                            st.warning(f"Pivots indisponibles: {pv.get('detail')}")
                        else:
                            import pandas as _pd
                            df_piv = _pd.DataFrame([{ "PP": pv.get("pp"), "R": pv.get("r"), "S": pv.get("s") }])
                            st.dataframe(df_piv, hide_index=True, use_container_width=True)
                except Exception as e2:
                    st.error("Indicateurs modernes indisponibles. L'API redémarre peut-être.")
                else:
                    st.warning("⏳ Chargement des données en cours...")
    else:
        st.warning("⏳ Chargement des données en cours...")
        if st.session_state.mt5_connected:
            st.info("Vérifiez que le symbole existe dans MT5 et que la connexion est stable")
        else:
            st.error("Connectez-vous d'abord à MT5")

else:
    st.info("👈 Sélectionnez un symbole dans la sidebar pour commencer")

# Pied de page
st.markdown("---")
st.markdown(
    "**⚠️ Important:** Cette application utilise les **vrais prix** de MetaTrader 5. "
    "Assurez-vous que MT5 est connecté et que vos identifiants sont corrects dans le fichier `.env`"
) 