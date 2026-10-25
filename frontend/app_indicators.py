import streamlit as st
import pandas as pd
import numpy as np
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import MetaTrader5 as mt5
import time
from datetime import datetime, timedelta
import sys
import os

# Ajouter le répertoire backend au path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))

from features import compute_features
from backend.technical_analysis import add_rsi, add_macd, add_bollinger_bands, add_atr, INDICATOR_PARAMS
from backend.mt5_connector import get_all_symbols, get_symbols_by_category

# Configuration de la page
st.set_page_config(
    page_title="TradBOT - Indicateurs Techniques",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Titre principal
st.title("📊 Indicateurs Techniques en Temps Réel")
st.markdown("---")

# Initialisation de MT5
@st.cache_resource
def init_mt5():
    if not mt5.initialize():
        st.error("❌ Échec de l'initialisation de MetaTrader 5")
        return False
    return True

# Fonction pour récupérer les données MT5
def get_mt5_data(symbol, timeframe, num_bars=100):
    """Récupère les données depuis MT5"""
    try:
        # Conversion du timeframe
        tf_map = {
            "1 minute": mt5.TIMEFRAME_M1,
            "5 minutes": mt5.TIMEFRAME_M5,
            "15 minutes": mt5.TIMEFRAME_M15,
            "30 minutes": mt5.TIMEFRAME_M30,
            "1 heure": mt5.TIMEFRAME_H1,
            "4 heures": mt5.TIMEFRAME_H4,
            "1 jour": mt5.TIMEFRAME_D1
        }
        
        tf = tf_map.get(timeframe, mt5.TIMEFRAME_M5)
        
        # Récupération des données
        rates = mt5.copy_rates_from_pos(symbol, tf, 0, num_bars)
        if rates is None or len(rates) == 0:
            return None
            
        # Conversion en DataFrame
        df = pd.DataFrame(rates)
        df['timestamp'] = pd.to_datetime(df['time'], unit='s')
        df = df[['timestamp', 'open', 'high', 'low', 'close', 'tick_volume']]
        df.columns = ['timestamp', 'open', 'high', 'low', 'close', 'volume']
        
        return df
        
    except Exception as e:
        st.error(f"❌ Erreur lors de la récupération des données: {e}")
        return None

# Fonction pour créer le graphique principal
def create_main_chart(df, symbol):
    """Crée le graphique principal avec les indicateurs"""
    
    # Calcul des indicateurs
    df_ta = df.copy()
    
    # RSI
    df_ta = add_rsi(df_ta)
    
    # MACD
    df_ta = add_macd(df_ta, INDICATOR_PARAMS['macd'])
    
    # Bollinger Bands
    df_ta = add_bollinger_bands(df_ta, INDICATOR_PARAMS['bollinger'])
    
    # ATR
    df_ta = add_atr(df_ta, [14])
    
    # Moyennes mobiles
    df_ta['ma_5'] = df_ta['close'].rolling(window=5).mean()
    df_ta['ma_10'] = df_ta['close'].rolling(window=10).mean()
    df_ta['ma_20'] = df_ta['close'].rolling(window=20).mean()
    df_ta['ma_50'] = df_ta['close'].rolling(window=50).mean()
    
    # Création du graphique
    fig = make_subplots(
        rows=4, cols=1,
        shared_xaxes=True,
        vertical_spacing=0.05,
        subplot_titles=(f'Prix {symbol}', 'RSI', 'MACD', 'Volume'),
        row_heights=[0.5, 0.15, 0.15, 0.2]
    )
    
    # Ajout des bandes de support/résistance (zones)
    try:
        import requests
        url = f"http://localhost:8000/support_resistance_zones?symbol={symbol.replace(' ', '%20')}"
        zones = requests.get(url, timeout=3).json()
        x0 = df_ta['timestamp'].iloc[0]
        x1 = df_ta['timestamp'].iloc[-1]
        for zone in zones:
            color = "rgba(0,255,0,0.15)" if zone["type"] == "support" else "rgba(255,0,0,0.15)"
            fig.add_shape(
                type="rect",
                xref="x",
                yref="y",
                x0=x0,
                x1=x1,
                y0=zone["level"] - zone["margin"],
                y1=zone["level"] + zone["margin"],
                fillcolor=color,
                line_width=0,
                layer="below"
            )
            # Optionnel : ligne centrale
            fig.add_shape(
                type="line",
                xref="x",
                yref="y",
                x0=x0,
                x1=x1,
                y0=zone["level"],
                y1=zone["level"],
                line=dict(color="green" if zone["type"] == "support" else "red", width=1, dash="dot"),
                layer="above"
            )
    except Exception as e:
        pass  # Ne bloque pas l'affichage si l'API est indisponible
    
    # Graphique des prix (candlesticks)
    fig.add_trace(
        go.Candlestick(
            x=df_ta['timestamp'],
            open=df_ta['open'],
            high=df_ta['high'],
            low=df_ta['low'],
            close=df_ta['close'],
            name='Prix',
            increasing_line_color='#00ff00',
            decreasing_line_color='#ff0000'
        ),
        row=1, col=1
    )
    
    # Moyennes mobiles
    fig.add_trace(
        go.Scatter(x=df_ta['timestamp'], y=df_ta['ma_5'], name='MA 5', line=dict(color='blue', width=1)),
        row=1, col=1
    )
    fig.add_trace(
        go.Scatter(x=df_ta['timestamp'], y=df_ta['ma_10'], name='MA 10', line=dict(color='orange', width=1)),
        row=1, col=1
    )
    fig.add_trace(
        go.Scatter(x=df_ta['timestamp'], y=df_ta['ma_20'], name='MA 20', line=dict(color='red', width=1)),
        row=1, col=1
    )
    fig.add_trace(
        go.Scatter(x=df_ta['timestamp'], y=df_ta['ma_50'], name='MA 50', line=dict(color='purple', width=1)),
        row=1, col=1
    )
    
    # Bollinger Bands
    if 'bb_upper' in df_ta.columns:
        fig.add_trace(
            go.Scatter(x=df_ta['timestamp'], y=df_ta['bb_upper'], name='BB Upper', 
                      line=dict(color='gray', width=1, dash='dash')),
            row=1, col=1
        )
        fig.add_trace(
            go.Scatter(x=df_ta['timestamp'], y=df_ta['bb_lower'], name='BB Lower', 
                      line=dict(color='gray', width=1, dash='dash'), fill='tonexty'),
            row=1, col=1
        )
    
    # RSI
    if 'rsi_14' in df_ta.columns:
        fig.add_trace(
            go.Scatter(x=df_ta['timestamp'], y=df_ta['rsi_14'], name='RSI', line=dict(color='purple')),
            row=2, col=1
        )
        # Lignes de survente/surachat
        fig.add_hline(y=70, line_dash="dash", line_color="red", row=2, col=1)
        fig.add_hline(y=30, line_dash="dash", line_color="green", row=2, col=1)
        fig.add_hline(y=50, line_dash="dot", line_color="gray", row=2, col=1)
    
    # MACD
    if 'macd' in df_ta.columns:
        fig.add_trace(
            go.Scatter(x=df_ta['timestamp'], y=df_ta['macd'], name='MACD', line=dict(color='blue')),
            row=3, col=1
        )
        fig.add_trace(
            go.Scatter(x=df_ta['timestamp'], y=df_ta['macd_signal'], name='Signal', line=dict(color='red')),
            row=3, col=1
        )
        if 'macd_histogram' in df_ta.columns:
            colors = ['green' if val >= 0 else 'red' for val in df_ta['macd_histogram']]
            fig.add_trace(
                go.Bar(x=df_ta['timestamp'], y=df_ta['macd_histogram'], name='Histogram', 
                      marker_color=colors),
                row=3, col=1
            )
    
    # Volume
    colors = ['green' if close >= open else 'red' for close, open in zip(df_ta['close'], df_ta['open'])]
    fig.add_trace(
        go.Bar(x=df_ta['timestamp'], y=df_ta['volume'], name='Volume', marker_color=colors),
        row=4, col=1
    )
    
    # --- Détection et marquage des zones d'entrée optimales BUY/SELL ---
    profit_target = 0.20  # 20%
    max_loss = 0.05       # 5%
    lookahead = 30        # nombre de bougies à regarder après l'entrée
    buy_entries = []
    sell_entries = []
    close_prices = df_ta['close'].values
    timestamps = df_ta['timestamp'].values
    for i in range(len(close_prices) - lookahead):
        entry_price = close_prices[i]
        future_prices = np.array(close_prices[i+1:i+1+lookahead])
        # BUY
        max_up = (future_prices.max() - entry_price) / entry_price
        min_down = (future_prices.min() - entry_price) / entry_price
        if max_up >= profit_target and min_down > -max_loss:
            buy_entries.append((timestamps[i], entry_price))
        # SELL
        min_down = (future_prices.min() - entry_price) / entry_price
        max_up = (future_prices.max() - entry_price) / entry_price
        if min_down <= -profit_target and max_up < max_loss:
            sell_entries.append((timestamps[i], entry_price))
    # Marquer les entrées sur le graphique
    for ts, price in buy_entries:
        fig.add_trace(go.Scatter(
            x=[ts], y=[price],
            mode='markers+text',
            marker=dict(symbol='triangle-up', color='lime', size=14),
            text=["BUY"],
            textposition="top center",
            name="Entrée BUY"
        ))
    for ts, price in sell_entries:
        fig.add_trace(go.Scatter(
            x=[ts], y=[price],
            mode='markers+text',
            marker=dict(symbol='triangle-down', color='red', size=14),
            text=["SELL"],
            textposition="bottom center",
            name="Entrée SELL"
        ))
    
    # Mise à jour du layout
    fig.update_layout(
        title=f'Analyse Technique - {symbol}',
        xaxis_rangeslider_visible=False,
        height=800,
        showlegend=True
    )
    
    return fig

# Fonction pour afficher les statistiques
def display_statistics(df, features):
    """Affiche les statistiques des indicateurs"""
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Prix Actuel", f"{df['close'].iloc[-1]:.5f}")
        st.metric("Variation", f"{((df['close'].iloc[-1] / df['close'].iloc[-2] - 1) * 100):.2f}%")
    
    with col2:
        if 'rsi_14' in features.columns:
            rsi_val = features['rsi'].iloc[-1]
            st.metric("RSI", f"{rsi_val:.1f}")
            if rsi_val > 70:
                st.warning("Surachat")
            elif rsi_val < 30:
                st.success("Survente")
    
    with col3:
        if 'macd' in features.columns:
            macd_val = features['macd'].iloc[-1]
            signal_val = features['macd_signal'].iloc[-1]
            st.metric("MACD", f"{macd_val:.5f}")
            st.metric("Signal", f"{signal_val:.5f}")
    
    with col4:
        volatility = features['volatility'].iloc[-1]
        st.metric("Volatilité", f"{volatility:.5f}")
        if features['spike_detection'].iloc[-1] == 1:
            st.error("🚨 SPIKE DÉTECTÉ!")

# Interface principale
def main():
    # Sidebar pour les paramètres
    st.sidebar.header("⚙️ Paramètres")
    
    # Initialisation MT5
    if not init_mt5():
        st.error("❌ Impossible de se connecter à MetaTrader 5")
        return
    
    # Sidebar - Sélection
    st.sidebar.header("Paramètres de prédiction")
    symbol_categories = ['TOUS', 'FOREX', 'SYNTHETIC', 'CRYPTO', 'INDICES', 'COMMODITIES', 'STOCKS', 'OTHER']
    category = st.sidebar.selectbox("Catégorie de symbole", symbol_categories, index=0)
    if category == 'TOUS':
        symbols = get_all_symbols()
    else:
        symbols = get_symbols_by_category(category)
    symbol_search = st.sidebar.text_input("🔍 Rechercher un symbole", "", key="indicators_sidebar_symbol_search")
    if symbol_search:
        filtered_symbols = [s for s in symbols if symbol_search.upper() in s.upper()]
    else:
        filtered_symbols = symbols
    symbol = st.sidebar.selectbox("Symbole", filtered_symbols, index=0 if filtered_symbols else None)
    
    # Sélection du timeframe
    timeframes = ["1 minute", "5 minutes", "15 minutes", "30 minutes", "1 heure", "4 heures", "1 jour"]
    timeframe = st.sidebar.selectbox("Timeframe", timeframes, index=1)
    
    # Nombre de barres
    num_bars = st.sidebar.slider("Nombre de barres", 50, 500, 100)
    
    # Bouton de rafraîchissement
    if st.sidebar.button("🔄 Rafraîchir"):
        st.rerun()
    
    # Auto-refresh
    auto_refresh = st.sidebar.checkbox("Auto-refresh (5s)", value=True)
    
    # Récupération des données
    df = get_mt5_data(symbol, timeframe, num_bars=200)
    
    if df is None:
        st.error("❌ Impossible de récupérer les données")
        return
    
    # Calcul des features
    try:
        features = compute_features(df)
        st.success(f"✅ {len(features.columns)} features calculées")
    except Exception as e:
        st.error(f"❌ Erreur lors du calcul des features: {e}")
        return
    
    # Affichage des statistiques
    st.subheader("📈 Statistiques en Temps Réel")
    display_statistics(df, features)
    
    # Graphique principal
    st.subheader("📊 Graphique des Indicateurs")
    fig = create_main_chart(df, symbol)
    st.plotly_chart(fig, use_container_width=True)
    
    # Tableau des dernières valeurs
    st.subheader("📋 Dernières Valeurs")
    
    # Sélection des indicateurs à afficher
    indicator_cols = ['rsi', 'macd', 'macd_signal', 'bb_position', 'atr', 'volatility', 'spike_detection']
    available_cols = [col for col in indicator_cols if col in features.columns]
    
    if available_cols:
        display_df = features[available_cols].tail(10)
        display_df.index = df['timestamp'].tail(10)
        st.dataframe(display_df, use_container_width=True)
    
    # Auto-refresh
    if auto_refresh:
        time.sleep(5)
        st.rerun()

if __name__ == "__main__":
    main() 