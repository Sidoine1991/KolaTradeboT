import streamlit as st
import pandas as pd
import numpy as np
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import plotly.express as px
from datetime import datetime, timedelta
import time
import os
import sys

# Ajouter le répertoire backend au path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))

try:
    from backend.mt5_connector import connect, get_ohlc, get_current_price, get_all_symbols, test_connection
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

# Configuration de la page
st.set_page_config(
    page_title="TradBOT Professional",
    page_icon="📈",
    layout="wide",
    initial_sidebar_state="expanded"
)

# CSS pour l'interface professionnelle
st.markdown("""
<style>
    /* Interface sombre professionnelle */
    .main .block-container {
        padding-top: 1rem;
        padding-bottom: 1rem;
        max-width: 100%;
    }
    
    /* Panneau de sentiment de marché */
    .market-sentiment {
        background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
        padding: 1rem;
        border-radius: 10px;
        margin-bottom: 1rem;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    
    .sentiment-bearish {
        background: linear-gradient(135deg, #dc2626 0%, #ef4444 100%);
        color: white;
        padding: 1rem;
        border-radius: 10px;
        margin-bottom: 1rem;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    
    .sentiment-bullish {
        background: linear-gradient(135deg, #059669 0%, #10b981 100%);
        color: white;
        padding: 1rem;
        border-radius: 10px;
        margin-bottom: 1rem;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    
    .sentiment-neutral {
        background: linear-gradient(135deg, #6b7280 0%, #9ca3af 100%);
        color: white;
        padding: 1rem;
        border-radius: 10px;
        margin-bottom: 1rem;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    
    /* Boutons de force de sentiment */
    .sentiment-strength {
        display: flex;
        gap: 0.5rem;
        margin-top: 0.5rem;
    }
    
    .strength-btn {
        padding: 0.25rem 0.75rem;
        border-radius: 5px;
        font-size: 0.8rem;
        font-weight: bold;
        border: none;
        cursor: pointer;
    }
    
    .strength-active {
        background: #dc2626;
        color: white;
    }
    
    .strength-inactive {
        background: #374151;
        color: #9ca3af;
    }
    
    /* Barre latérale des outils */
    .trading-tools {
        background: #1f2937;
        padding: 1rem;
        border-radius: 10px;
        margin-bottom: 1rem;
    }
    
    .tool-icon {
        width: 40px;
        height: 40px;
        background: #374151;
        border-radius: 8px;
        display: flex;
        align-items: center;
        justify-content: center;
        margin-bottom: 0.5rem;
        cursor: pointer;
        transition: background 0.3s;
    }
    
    .tool-icon:hover {
        background: #4b5563;
    }
    
    /* Niveaux de prix */
    .price-levels {
        background: #1f2937;
        padding: 1rem;
        border-radius: 10px;
        margin-bottom: 1rem;
    }
    
    .price-level {
        display: flex;
        align-items: center;
        margin-bottom: 0.5rem;
        padding: 0.5rem;
        border-radius: 5px;
        background: #374151;
    }
    
    .price-level-resistance {
        background: #dc2626;
        color: white;
    }
    
    .price-level-support {
        background: #059669;
        color: white;
    }
    
    .price-level-neutral {
        background: #6b7280;
        color: white;
    }
    
    /* Graphique principal */
    .main-chart {
        background: #111827;
        border-radius: 10px;
        padding: 1rem;
        margin-bottom: 1rem;
    }
    
    /* Métriques de trading */
    .trading-metrics {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 1rem;
        margin-bottom: 1rem;
    }
    
    .metric-card {
        background: #1f2937;
        padding: 1rem;
        border-radius: 10px;
        border-left: 4px solid #3b82f6;
    }
    
    .metric-value {
        font-size: 1.5rem;
        font-weight: bold;
        color: #3b82f6;
    }
    
    .metric-label {
        font-size: 0.9rem;
        color: #9ca3af;
        margin-top: 0.25rem;
    }
</style>
""", unsafe_allow_html=True)

# Initialisation des variables de session
if 'mt5_connected' not in st.session_state:
    st.session_state.mt5_connected = False
if 'real_time_data' not in st.session_state:
    st.session_state.real_time_data = pd.DataFrame()
if 'current_symbol' not in st.session_state:
    st.session_state.current_symbol = "Boom 1000 Index"
if 'current_timeframe' not in st.session_state:
    st.session_state.current_timeframe = "1m"
if 'ml_predictor' not in st.session_state:
    st.session_state.ml_predictor = AdvancedMLPredictor()
if 'setup_detector' not in st.session_state:
    st.session_state.setup_detector = SetupDetector()
if 'risk_manager' not in st.session_state:
    st.session_state.risk_manager = RiskManager()
if 'trading_signals' not in st.session_state:
    st.session_state.trading_signals = {}

def get_market_sentiment(data):
    """Détermine le sentiment de marché basé sur les données"""
    if data.empty:
        return "NEUTRAL", 0.5, "Consolidating"
    
    # Analyser la tendance récente
    recent_data = data.tail(20)
    price_change = (recent_data['close'].iloc[-1] - recent_data['close'].iloc[0]) / recent_data['close'].iloc[0]
    
    # Analyser la volatilité
    volatility = recent_data['close'].pct_change().std()
    
    # Déterminer le sentiment
    if price_change > 0.02:  # +2%
        sentiment = "BULLISH"
        strength = min(0.9, 0.5 + abs(price_change) * 10)
        trend = "Rising"
    elif price_change < -0.02:  # -2%
        sentiment = "BEARISH"
        strength = min(0.9, 0.5 + abs(price_change) * 10)
        trend = "Falling"
    else:
        sentiment = "NEUTRAL"
        strength = 0.5
        if volatility > 0.01:
            trend = "Consolidating"
        else:
            trend = "Sideways"
    
    return sentiment, strength, trend

def get_sentiment_strength_levels(strength):
    """Retourne les niveaux de force du sentiment"""
    if strength >= 0.8:
        return ["Very Strong", "Strong", "Neutral", "Weak", "Very Weak"]
    elif strength >= 0.6:
        return ["Strong", "Very Strong", "Neutral", "Weak", "Very Weak"]
    elif strength >= 0.4:
        return ["Neutral", "Strong", "Very Strong", "Weak", "Very Weak"]
    elif strength >= 0.2:
        return ["Weak", "Neutral", "Strong", "Very Strong", "Very Weak"]
    else:
        return ["Very Weak", "Weak", "Neutral", "Strong", "Very Strong"]

def create_trading_tools_sidebar():
    """Crée la barre latérale des outils de trading"""
    st.markdown("### 🛠️ Outils de Trading")
    
    # Outils de dessin
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("**Dessin**")
        if st.button("✏️", help="Crayon"):
            st.session_state.selected_tool = "pen"
        if st.button("📏", help="Règle"):
            st.session_state.selected_tool = "ruler"
        if st.button("📐", help="Ligne"):
            st.session_state.selected_tool = "line"
        if st.button("📦", help="Rectangle"):
            st.session_state.selected_tool = "rectangle"
        if st.button("📝", help="Texte"):
            st.session_state.selected_tool = "text"
    
    with col2:
        st.markdown("**Analyse**")
        if st.button("🔍", help="Zoom"):
            st.session_state.selected_tool = "zoom"
        if st.button("↩️", help="Annuler"):
            st.session_state.selected_tool = "undo"
        if st.button("⚙️", help="Paramètres"):
            st.session_state.selected_tool = "settings"
        if st.button("📊", help="Indicateurs"):
            st.session_state.selected_tool = "indicators"
        if st.button("🤖", help="EA"):
            st.session_state.selected_tool = "ea"

def create_price_levels_panel(data):
    """Crée le panneau des niveaux de prix"""
    if data.empty:
        return
    
    st.markdown("### 💰 Niveaux de Prix")
    
    # Niveaux de support/résistance
    current_price = data['close'].iloc[-1]
    
    # Calculer les niveaux
    high_20 = data['high'].tail(20).max()
    low_20 = data['low'].tail(20).min()
    
    # Niveau de résistance
    resistance = high_20
    resistance_diff = abs(resistance - current_price) / current_price
    
    # Niveau de support
    support = low_20
    support_diff = abs(support - current_price) / current_price
    
    # Afficher les niveaux
    if resistance_diff < 0.01:  # Moins de 1%
        st.markdown(f'<div class="price-level price-level-resistance">Résistance: {resistance:.5f}</div>', unsafe_allow_html=True)
    else:
        st.markdown(f'<div class="price-level price-level-neutral">Résistance: {resistance:.5f}</div>', unsafe_allow_html=True)
    
    st.markdown(f'<div class="price-level price-level-neutral">Prix: {current_price:.5f}</div>', unsafe_allow_html=True)
    
    if support_diff < 0.01:  # Moins de 1%
        st.markdown(f'<div class="price-level price-level-support">Support: {support:.5f}</div>', unsafe_allow_html=True)
    else:
        st.markdown(f'<div class="price-level price-level-neutral">Support: {support:.5f}</div>', unsafe_allow_html=True)

def create_market_sentiment_panel(data):
    """Crée le panneau de sentiment de marché"""
    sentiment, strength, trend = get_market_sentiment(data)
    
    # Couleur du panneau selon le sentiment
    if sentiment == "BEARISH":
        panel_class = "sentiment-bearish"
        sentiment_text = "Bearish"
    elif sentiment == "BULLISH":
        panel_class = "sentiment-bullish"
        sentiment_text = "Bullish"
    else:
        panel_class = "sentiment-neutral"
        sentiment_text = "Neutral"
    
    # Créer le HTML du panneau
    strength_levels = get_sentiment_strength_levels(strength)
    
    html = f"""
    <div class="{panel_class}">
        <h2 style="margin: 0; font-size: 2rem; font-weight: bold;">{sentiment_text}</h2>
        <div style="margin: 0.5rem 0;">
            <span style="background: rgba(255,255,255,0.2); padding: 0.25rem 0.5rem; border-radius: 5px; margin-right: 0.5rem;">{trend}</span>
            <span style="background: rgba(255,255,255,0.2); padding: 0.25rem 0.5rem; border-radius: 5px;">Force: {strength:.2f}</span>
        </div>
        <div class="sentiment-strength">
    """
    
    for level in strength_levels:
        if level == strength_levels[0]:  # Premier niveau (actif)
            html += f'<span class="strength-btn strength-active">{level}</span>'
        else:
            html += f'<span class="strength-btn strength-inactive">{level}</span>'
    
    html += """
        </div>
    </div>
    """
    
    st.markdown(html, unsafe_allow_html=True)

def create_trading_metrics(data):
    """Crée les métriques de trading"""
    if data.empty:
        return
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        current_price = data['close'].iloc[-1]
        st.metric("Prix Actuel", f"{current_price:.5f}")
    
    with col2:
        price_change = data['close'].pct_change().iloc[-1] * 100
        st.metric("Variation", f"{price_change:+.2f}%")
    
    with col3:
        volatility = data['close'].pct_change().std() * 100
        st.metric("Volatilité", f"{volatility:.2f}%")
    
    with col4:
        volume = data['volume'].iloc[-1] if 'volume' in data.columns else 0
        st.metric("Volume", f"{volume:,.0f}")

def main():
    st.title("📈 TradBOT Professional")
    
    # Panneau de sentiment de marché
    if not st.session_state.real_time_data.empty:
        create_market_sentiment_panel(st.session_state.real_time_data)
    
    # Layout principal
    col1, col2, col3 = st.columns([1, 4, 1])
    
    with col1:
        # Barre latérale gauche - Outils de trading
        create_trading_tools_sidebar()
        
        # Connexion MT5
        st.markdown("### 🔌 Connexion")
        if st.button("Connecter MT5"):
            if MT5_AVAILABLE:
                try:
                    connect()
                    st.session_state.mt5_connected = True
                    st.success("✅ Connecté!")
                except Exception as e:
                    st.error(f"❌ Erreur: {e}")
        
        if st.session_state.mt5_connected:
            st.success("🟢 MT5 Connecté")
        else:
            st.error("🔴 MT5 Non connecté")
    
    with col2:
        # Graphique principal
        if not st.session_state.real_time_data.empty:
            st.markdown("### 📊 Graphique Principal")
            
            # Créer le graphique
            fig = create_candlestick_chart(st.session_state.real_time_data, f"{st.session_state.current_symbol} - Professional")
            
            # Ajouter les indicateurs techniques et canaux de trading
            fig = add_technical_indicators_to_chart(fig, st.session_state.real_time_data, ['sma', 'ema', 'bollinger', 'channels'])
            
            # Ajouter les prédictions ML
            if len(st.session_state.real_time_data) >= 50:
                try:
                    setups = st.session_state.setup_detector.detect_all_setups(st.session_state.real_time_data)
                    ml_signals = st.session_state.ml_predictor.get_trading_signals(st.session_state.real_time_data)
                    fig = add_ml_predictions_to_chart(fig, st.session_state.real_time_data, ml_signals, setups)
                except:
                    pass
            
            # Style du graphique
            fig.update_layout(
                template="plotly_dark",
                height=600,
                showlegend=True,
                xaxis_rangeslider_visible=False
            )
            
            st.plotly_chart(fig, use_container_width=True)
            
            # Métriques de trading
            create_trading_metrics(st.session_state.real_time_data)
        else:
            st.info("Sélectionnez un symbole pour afficher le graphique")
    
    with col3:
        # Barre latérale droite - Niveaux de prix
        if not st.session_state.real_time_data.empty:
            create_price_levels_panel(st.session_state.real_time_data)
        
        # Sélection du symbole
        st.markdown("### 📈 Symboles")
        if st.session_state.mt5_connected and MT5_AVAILABLE:
            try:
                all_symbols = get_all_symbols()
                if all_symbols:
                    # Symboles populaires
                    popular_symbols = [
                        "Boom 1000 Index", "Crash 1000 Index", "Volatility 75 Index",
                        "EURUSD", "GBPUSD", "USDJPY", "AUDUSD",
                        "BTCUSD", "ETHUSD", "GOLD", "SILVER"
                    ]
                    
                    available_symbols = [s for s in all_symbols if s in popular_symbols]
                    if not available_symbols:
                        available_symbols = all_symbols[:20]
                    
                    selected_symbol = st.selectbox(
                        "Choisir un symbole",
                        available_symbols,
                        index=0 if "Boom 1000 Index" not in available_symbols else available_symbols.index("Boom 1000 Index")
                    )
                    
                    if selected_symbol != st.session_state.current_symbol:
                        st.session_state.current_symbol = selected_symbol
                        
                        # Récupérer les données
                        with st.spinner("Récupération des données..."):
                            try:
                                ohlc_data = get_ohlc(selected_symbol, st.session_state.current_timeframe, 200)
                                if not ohlc_data.empty:
                                    # Ajouter les features
                                    features = compute_features(ohlc_data)
                                    st.session_state.real_time_data = pd.concat([ohlc_data, features], axis=1)
                                    st.success(f"✅ Données récupérées pour {selected_symbol}")
                                else:
                                    st.error("❌ Aucune donnée récupérée")
                            except Exception as e:
                                st.error(f"❌ Erreur: {e}")
            except Exception as e:
                st.error(f"❌ Erreur de connexion: {e}")
        
        # Rafraîchissement automatique
        if st.checkbox("Rafraîchissement automatique"):
            time.sleep(5)
            st.rerun()

if __name__ == "__main__":
    main()
