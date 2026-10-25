import streamlit as st
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import time
from datetime import datetime, timedelta
import sys
import os
import logging

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Ajouter le chemin du backend
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

# Importer le BackendConnector
try:
    from frontend.backend_connector import BackendConnector
    BACKEND_AVAILABLE = True
except ImportError as e:
    logger.error(f"Erreur d'importation du BackendConnector: {e}")
    BACKEND_AVAILABLE = False

# Configuration de la page
st.set_page_config(
    page_title="TradBOT - Graphique Temps Réel",
    page_icon="📈",
    layout="wide",
    initial_sidebar_state="expanded",
    menu_items={
        'Get Help': None,
        'Report a bug': None,
        'About': "TradBOT - Graphique Temps Réel avec MT5"
    }
)

# CSS pour un meilleur style avec graphique large
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        font-weight: bold;
        text-align: center;
        margin-bottom: 1rem;
        background: linear-gradient(90deg, #00ff88, #00bcd4);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
    }
    .metric-card {
        background: rgba(255, 255, 255, 0.1);
        padding: 1rem;
        border-radius: 10px;
        border: 1px solid rgba(255, 255, 255, 0.2);
        margin: 0.5rem 0;
    }
    .status-connected {
        color: #00ff88;
        font-weight: bold;
    }
    .status-disconnected {
        color: #ff4444;
        font-weight: bold;
    }
    
    /* Configuration pour graphique large */
    .main .block-container {
        padding-top: 1rem;
        padding-bottom: 1rem;
        padding-left: 1rem;
        padding-right: 1rem;
        max-width: 100%;
    }
    
    /* Sidebar plus étroite */
    .css-1d391kg {
        width: 250px;
    }
    
    /* Zone principale plus large */
    .main .block-container > div {
        max-width: 100%;
    }
    
    /* Graphique optimisé */
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
    
    /* Réduire les marges */
    .stApp > div {
        padding-top: 0.5rem;
    }
    
    /* Métriques plus compactes */
    .metric-container {
        margin-bottom: 0.5rem;
    }
</style>
""", unsafe_allow_html=True)

# Initialiser l'état de la session
def initialize_session_state():
    # Données de marché
    if 'market_data' not in st.session_state:
        st.session_state.market_data = pd.DataFrame()
    if 'indicators' not in st.session_state:
        st.session_state.indicators = {}
    if 'last_update' not in st.session_state:
        st.session_state.last_update = None
    
    # Configuration
    if 'symbol' not in st.session_state:
        st.session_state.symbol = 'EURUSD'
    if 'timeframe' not in st.session_state:
        st.session_state.timeframe = '5m'
    
    # État de connexion
    if 'is_connected' not in st.session_state:
        st.session_state.is_connected = False
    if 'connection_attempts' not in st.session_state:
        st.session_state.connection_attempts = 0
    
    # Initialisation du connecteur backend
    if 'backend_connector' not in st.session_state and BACKEND_AVAILABLE:
        try:
            st.session_state.backend_connector = BackendConnector()
            # Tester la connexion initiale
            test_backend_connection()
        except Exception as e:
            logger.error(f"Erreur lors de l'initialisation du BackendConnector: {e}")
            st.session_state.is_connected = False

# Tester la connexion au backend
def test_backend_connection():
    """Teste la connexion au backend et met à jour l'état de la session"""
    if 'backend_connector' not in st.session_state:
        st.session_state.is_connected = False
        return False
    
    try:
        status = st.session_state.backend_connector.test_connections()
        st.session_state.is_connected = status.get('overall_status') == 'connected'
        return st.session_state.is_connected
    except Exception as e:
        logger.error(f"Erreur lors du test de connexion: {e}")
        st.session_state.is_connected = False
        return False

# Récupérer les données du marché
def fetch_market_data(symbol, timeframe='5m'):
    """Récupère les données de marché et les indicateurs depuis le backend"""
    if not st.session_state.get('is_connected', False):
        return None, {}
    
    try:
        connector = st.session_state.backend_connector
        
        # Récupérer les données de prix
        price_data = connector.get_real_time_price(symbol)
        if not price_data or 'price' not in price_data:
            logger.warning("Aucune donnée de prix disponible")
            return None, {}
        
        # Récupérer l'analyse de tendance
        trend_data = connector.get_trend_summary(symbol, nocache=int(time.time()))
        
        # Mettre à jour les indicateurs
        indicators = {
            'price': price_data.get('price', 0),
            'bid': price_data.get('bid', 0),
            'ask': price_data.get('ask', 0),
            'volume': price_data.get('volume', 0),
            'trend': trend_data.get('trend', 'Neutre') if trend_data else 'Inconnu',
            'rsi': trend_data.get('rsi', 50) if trend_data else 50,
            'macd': trend_data.get('macd', {}).get('value', 0) if trend_data and 'macd' in trend_data else 0,
            'macd_signal': trend_data.get('macd', {}).get('signal', 0) if trend_data and 'macd' in trend_data else 0,
            'atr': trend_data.get('atr', 0) if trend_data else 0,
            'volatility': trend_data.get('volatility', 0) if trend_data else 0
        }
        
        # Créer un DataFrame avec les données de prix
        current_time = datetime.now()
        new_data = pd.DataFrame([{
            'timestamp': current_time,
            'open': price_data.get('price', 0),
            'high': price_data.get('high', price_data.get('price', 0)),
            'low': price_data.get('low', price_data.get('price', 0)),
            'close': price_data.get('price', 0),
            'volume': price_data.get('volume', 0)
        }])
        new_data.set_index('timestamp', inplace=True)
        
        return new_data, indicators
        
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des données: {e}")
        return None, {}

# Met à jour les données en temps réel
def update_real_time_data():
    if not st.session_state.get('is_connected', False):
        test_backend_connection()
        if not st.session_state.get('is_connected', False):
            return False
    
    try:
        # Récupérer les données du marché
        new_data, indicators = fetch_market_data(st.session_state.symbol, st.session_state.timeframe)
        
        if new_data is not None and not new_data.empty:
            # Mettre à jour les données de marché
            if st.session_state.market_data.empty:
                st.session_state.market_data = new_data
            else:
                # Mettre à jour uniquement si la dernière donnée est plus récente
                last_timestamp = st.session_state.market_data.index[-1] if not st.session_state.market_data.empty else None
                if last_timestamp is None or new_data.index[0] > last_timestamp:
                    st.session_state.market_data = pd.concat([st.session_state.market_data, new_data])
            
            # Mettre à jour les indicateurs
            st.session_state.indicators.update(indicators)
            st.session_state.last_update = datetime.now()
            return True
            
    except Exception as e:
        logger.error(f"Erreur lors de la mise à jour des données: {e}")
    
    return False

# Afficher les indicateurs techniques
def display_technical_indicators():
    """Affiche les indicateurs techniques dans des colonnes"""
    if not st.session_state.indicators:
        return
        
    indicators = st.session_state.indicators
    
    # Créer des colonnes pour l'affichage
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Prix Actuel", f"{indicators.get('price', 0):.5f}")
        st.metric("Tendance", indicators.get('trend', 'N/A'))
        
    with col2:
        st.metric("RSI", f"{indicators.get('rsi', 0):.2f}")
        st.metric("ATR", f"{indicators.get('atr', 0):.5f}")
        
    with col3:
        st.metric("MACD", f"{indicators.get('macd', 0):.5f}")
        st.metric("Signal", f"{indicators.get('macd_signal', 0):.5f}")
        
    with col4:
        st.metric("Volume", f"{indicators.get('volume', 0):,}")
        st.metric("Volatilité", f"{indicators.get('volatility', 0):.2%}")

# Afficher le graphique des prix
def display_price_chart():
    """Affiche le graphique des prix avec les indicateurs"""
    if st.session_state.market_data.empty:
        st.warning("Aucune donnée à afficher")
        return
        
    df = st.session_state.market_data
    
    # Créer le graphique avec deux sous-graphiques
    fig = make_subplots(
        rows=2, 
        cols=1, 
        shared_xaxes=True,
        vertical_spacing=0.03,
        row_heights=[0.7, 0.3],
        subplot_titles=('Prix', 'Volume')
    )
    
    # Ajouter les chandeliers
    fig.add_trace(
        go.Candlestick(
            x=df.index,
            open=df['open'],
            high=df['high'],
            low=df['low'],
            close=df['close'],
            name='Prix',
            increasing_line_color='#2ecc71',
            decreasing_line_color='#e74c3c'
        ),
        row=1, col=1
    )
    
    # Ajouter le volume
    fig.add_trace(
        go.Bar(
            x=df.index,
            y=df['volume'],
            name='Volume',
            marker_color='#3498db',
            opacity=0.7
        ),
        row=2, col=1
    )
    
    # Mise en forme du graphique
    fig.update_layout(
        height=800,
        showlegend=True,
        hovermode='x unified',
        template='plotly_dark',
        margin=dict(l=20, r=20, t=40, b=20),
        xaxis_rangeslider_visible=False,
        xaxis2_rangeslider_visible=False
    )
    
    # Afficher le graphique
    st.plotly_chart(fig, use_container_width=True)

def main():
    # Initialisation de l'état de la session
    initialize_session_state()
    
    # Barre latérale
    with st.sidebar:
        st.title("⚙️ Configuration")
        
        # Test de connexion
        if st.button("🔌 Tester la connexion"):
            if test_backend_connection():
                st.success("✅ Connecté au serveur backend")
    # Graphique principal
    if st.session_state.mt5_connected and st.session_state.current_symbol:
        # Mettre à jour les données si nécessaire
        if st.session_state.auto_refresh or st.session_state.real_time_data.empty:
            update_real_time_data()
        
        # Afficher le graphique
        if not st.session_state.real_time_data.empty:
            # Vérifier les colonnes requises
            required_cols = ['open', 'high', 'low', 'close']
            missing_cols = [col for col in required_cols if col not in st.session_state.real_time_data.columns]
            
            if missing_cols:
                st.error(f"❌ Colonnes OHLC manquantes: {missing_cols}")
                st.write("🔍 Aperçu des données:", st.session_state.real_time_data.head())
                st.write("📊 Colonnes disponibles:", list(st.session_state.real_time_data.columns))
            else:
                # Créer le graphique
                chart_title = f"{st.session_state.current_symbol} - {st.session_state.current_timeframe} - Temps Réel"
                fig = create_candlestick_chart(st.session_state.real_time_data, chart_title)
                
                if fig is not None:
                    # Ajouter les indicateurs techniques
                    fig = add_technical_indicators_to_chart(fig, st.session_state.real_time_data, ['sma', 'ema', 'channels'])
                    
                    # Afficher le graphique avec configuration optimisée
                    st.plotly_chart(
                        fig, 
                        use_container_width=True,  # Utiliser toute la largeur disponible
                        height=800,
                        config={
                            'displayModeBar': True,
                            'displaylogo': False,
                            'modeBarButtonsToRemove': ['pan2d', 'lasso2d', 'select2d'],
                            'responsive': True,
                            'toImageButtonOptions': {
                                'format': 'png',
                                'filename': f'{st.session_state.current_symbol}_{st.session_state.current_timeframe}',
                                'height': 800,
                                'width': 1400,
                                'scale': 2
                            }
                        }
                    )
                    
                    # Informations sur les données - plus compactes
                    with st.expander("📊 Détails des données OHLC", expanded=False):
                        col1, col2, col3, col4 = st.columns(4)
                        with col1:
                            st.metric("Ouverture", f"{st.session_state.real_time_data['open'].iloc[-1]:.5f}")
                        with col2:
                            st.metric("Plus haut", f"{st.session_state.real_time_data['high'].iloc[-1]:.5f}")
                        with col3:
                            st.metric("Plus bas", f"{st.session_state.real_time_data['low'].iloc[-1]:.5f}")
                        with col4:
                            st.metric("Clôture", f"{st.session_state.real_time_data['close'].iloc[-1]:.5f}")
                else:
                    st.error("❌ Erreur lors de la création du graphique")
        else:
            st.warning("⚠️ Aucune donnée disponible. Vérifiez la connexion MT5 et le symbole.")
    else:
        st.info("👈 Veuillez vous connecter à MT5 et sélectionner un symbole dans la sidebar")
    
    # Auto-refresh si activé
    if st.session_state.auto_refresh and st.session_state.mt5_connected:
        time.sleep(5)  # Attendre 5 secondes
        st.rerun()

if __name__ == "__main__":
    main()
