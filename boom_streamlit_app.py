#!/usr/bin/env python3
"""
Interface Streamlit pour le Prédicteur Boom - Canal Haussier
Interface utilisateur pour visualiser les prédictions et contrôler le trading
"""

import streamlit as st
import pandas as pd
import numpy as np
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
import time
from datetime import datetime, timedelta
import json
import threading
from typing import Dict, List

# Import des modules locaux
from boom_rising_channel_predictor import (
    boom_predictor,
    get_boom_prediction,
    update_boom_data,
    create_boom_chart,
    get_boom_summary
)
from boom_trading_bot import (
    boom_trading_bot,
    start_boom_trading,
    stop_boom_trading,
    get_boom_trading_status,
    get_boom_positions,
    emergency_stop
)

# Configuration de la page
st.set_page_config(
    page_title="Boom Rising Channel Predictor",
    page_icon="🚀",
    layout="wide",
    initial_sidebar_state="expanded"
)

# CSS personnalisé
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        font-weight: bold;
        color: #1f77b4;
        text-align: center;
        margin-bottom: 2rem;
    }
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #1f77b4;
    }
    .prediction-card {
        background-color: #e8f4fd;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #ff6b6b;
    }
    .success-card {
        background-color: #e8f5e8;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #28a745;
    }
    .warning-card {
        background-color: #fff3cd;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #ffc107;
    }
</style>
""", unsafe_allow_html=True)

def main():
    """Fonction principale de l'interface"""
    
    # En-tête principal
    st.markdown('<h1 class="main-header">🚀 Boom Rising Channel Predictor</h1>', unsafe_allow_html=True)
    st.markdown("---")
    
    # Sidebar pour les contrôles
    with st.sidebar:
        st.header("🎛️ Contrôles")
        
        # Statut du trading
        trading_status = get_boom_trading_status()
        
        col1, col2 = st.columns(2)
        with col1:
            if st.button("▶️ Démarrer Trading", type="primary"):
                start_boom_trading()
                st.success("Trading démarré!")
                
        with col2:
            if st.button("⏹️ Arrêter Trading"):
                stop_boom_trading()
                st.warning("Trading arrêté!")
        
        # Bouton d'urgence
        if st.button("🚨 Arrêt d'Urgence", type="secondary"):
            emergency_stop()
            st.error("Arrêt d'urgence activé!")
        
        st.markdown("---")
        
        # Configuration
        st.header("⚙️ Configuration")
        
        # Paramètres de trading
        max_positions = st.slider("Max Positions", 1, 10, 3)
        position_size = st.slider("Taille Position", 0.01, 0.5, 0.1, 0.01)
        min_confidence = st.slider("Confiance Min", 0.5, 0.95, 0.75, 0.05)
        
        # Paramètres de prédiction
        ema_proximity_threshold = st.slider("Seuil Proximité EMA", 0.001, 0.01, 0.002, 0.001)
        spike_probability_threshold = st.slider("Seuil Probabilité Spike", 0.5, 0.95, 0.75, 0.05)
        
        st.markdown("---")
        
        # Informations du compte
        st.header("💰 Compte")
        st.metric("Solde", f"{trading_status['account_balance']:.2f} {trading_status['account_currency']}")
        st.metric("Positions Actives", trading_status['active_positions'])
        st.metric("Trades Aujourd'hui", trading_status['daily_trades'])
        st.metric("Perte Quotidienne", f"{trading_status['daily_loss']:.2f}")
    
    # Contenu principal
    tab1, tab2, tab3, tab4 = st.tabs(["📊 Prédictions", "📈 Graphique", "📋 Positions", "📊 Statistiques"])
    
    with tab1:
        display_predictions()
    
    with tab2:
        display_chart()
    
    with tab3:
        display_positions()
    
    with tab4:
        display_statistics()

def display_predictions():
    """Affiche les prédictions actuelles"""
    st.header("🎯 Prédictions Actuelles")
    
    # Obtenir la prédiction
    prediction = get_boom_prediction()
    
    if prediction.get('action') == 'HOLD':
        st.info("🔍 Aucune prédiction active - Surveillance en cours...")
    else:
        # Affichage de la prédiction principale
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.markdown('<div class="prediction-card">', unsafe_allow_html=True)
            st.metric("Action", prediction['action'])
            st.metric("Direction", prediction['direction'])
            st.markdown('</div>', unsafe_allow_html=True)
        
        with col2:
            st.markdown('<div class="metric-card">', unsafe_allow_html=True)
            st.metric("Confiance", f"{prediction['confidence']:.1%}")
            st.metric("Probabilité Spike", f"{prediction['spike_probability']:.1%}")
            st.markdown('</div>', unsafe_allow_html=True)
        
        with col3:
            st.markdown('<div class="metric-card">', unsafe_allow_html=True)
            st.metric("Temps Estimé", f"{prediction['time_to_spike']}s")
            st.metric("Prix Actuel", f"{prediction['current_price']:.2f}")
            st.markdown('</div>', unsafe_allow_html=True)
        
        # Détails de la prédiction
        st.markdown("### 📋 Détails de la Prédiction")
        
        details_col1, details_col2 = st.columns(2)
        
        with details_col1:
            st.write(f"**Proximité EMA:** {prediction['ema_proximity']}")
            st.write(f"**Position Canal:** {prediction['channel_position']}")
            st.write(f"**Stop Loss:** {prediction['stop_loss']:.2f}")
        
        with details_col2:
            st.write(f"**Take Profit:** {prediction['take_profit']:.2f}")
            st.write(f"**Taille Lot:** {prediction['lot_size']:.2f}")
            st.write(f"**Raison:** {prediction['reasoning']}")
        
        # Barre de progression pour le temps estimé
        time_progress = max(0, 1 - (prediction['time_to_spike'] / 300))
        st.progress(time_progress, text=f"Temps restant: {prediction['time_to_spike']}s")
    
    # Résumé des prédictions
    st.markdown("### 📊 Résumé des Prédictions")
    summary = get_boom_summary()
    
    if summary.get('status') == 'Prédiction active':
        latest = summary['latest_prediction']
        
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.metric("Direction", latest['direction'])
        with col2:
            st.metric("Confiance", latest['confidence'])
        with col3:
            st.metric("Probabilité", latest['spike_probability'])
        with col4:
            st.metric("Temps", latest['time_to_spike'])
    
    # Bouton de rafraîchissement
    if st.button("🔄 Rafraîchir Prédictions"):
        st.rerun()

def display_chart():
    """Affiche le graphique avec les prédictions"""
    st.header("📈 Graphique Boom - Canal Haussier")
    
    # Simulation de données pour le graphique
    if st.button("🔄 Générer Nouveau Graphique"):
        # Créer des données simulées
        create_sample_data()
        
        # Générer le graphique
        chart_path = "boom_chart.png"
        result = create_boom_chart(chart_path)
        
        if "sauvegardé" in result:
            st.image(chart_path, caption="Graphique Boom avec Prédictions")
        else:
            st.info("Graphique généré avec succès!")
    
    # Graphique interactif avec Plotly
    st.markdown("### 📊 Graphique Interactif")
    
    # Données simulées pour l'exemple
    dates = pd.date_range(start=datetime.now() - timedelta(hours=1), end=datetime.now(), freq='1min')
    base_price = 10000
    
    # Simulation d'un canal haussier
    trend = np.linspace(0, 50, len(dates))
    noise = np.random.normal(0, 2, len(dates))
    prices = base_price + trend + noise
    
    # EMAs simulées
    ema10 = pd.Series(prices).ewm(span=10).mean()
    ema30 = pd.Series(prices).ewm(span=30).mean()
    ema50 = pd.Series(prices).ewm(span=50).mean()
    
    # Créer le graphique
    fig = make_subplots(
        rows=2, cols=1,
        shared_xaxes=True,
        vertical_spacing=0.1,
        subplot_titles=('Prix Boom avec Canal Haussier', 'Volume'),
        row_heights=[0.7, 0.3]
    )
    
    # Prix et EMAs
    fig.add_trace(
        go.Scatter(x=dates, y=prices, name='Prix Boom', line=dict(color='blue', width=2)),
        row=1, col=1
    )
    
    fig.add_trace(
        go.Scatter(x=dates, y=ema10, name='EMA 10', line=dict(color='red', width=1)),
        row=1, col=1
    )
    
    fig.add_trace(
        go.Scatter(x=dates, y=ema30, name='EMA 30', line=dict(color='orange', width=1)),
        row=1, col=1
    )
    
    fig.add_trace(
        go.Scatter(x=dates, y=ema50, name='EMA 50', line=dict(color='green', width=1)),
        row=1, col=1
    )
    
    # Canal haussier simulé
    upper_channel = prices + 10
    lower_channel = prices - 10
    
    fig.add_trace(
        go.Scatter(x=dates, y=upper_channel, name='Canal Supérieur', 
                  line=dict(color='green', width=1, dash='dash'), fill=None),
        row=1, col=1
    )
    
    fig.add_trace(
        go.Scatter(x=dates, y=lower_channel, name='Canal Inférieur', 
                  line=dict(color='green', width=1, dash='dash'), 
                  fill='tonexty', fillcolor='rgba(0,255,0,0.1)'),
        row=1, col=1
    )
    
    # Flèches de prédiction simulées
    prediction_points = []
    for i in range(0, len(dates), 20):
        if i < len(dates) - 5:
            prediction_points.append({
                'x': dates[i],
                'y': prices[i],
                'direction': 'BOOM' if prices[i] < ema30.iloc[i] else 'CRASH',
                'confidence': np.random.uniform(0.7, 0.95)
            })
    
    for point in prediction_points:
        color = 'green' if point['direction'] == 'BOOM' else 'red'
        marker = 'triangle-up' if point['direction'] == 'BOOM' else 'triangle-down'
        
        fig.add_trace(
            go.Scatter(x=[point['x']], y=[point['y']], 
                      mode='markers', marker=dict(symbol=marker, size=15, color=color),
                      name=f"Prédiction {point['direction']}", showlegend=False),
            row=1, col=1
        )
    
    # Volume simulé
    volume = np.random.randint(1000, 5000, len(dates))
    fig.add_trace(
        go.Bar(x=dates, y=volume, name='Volume', marker_color='lightblue'),
        row=2, col=1
    )
    
    # Configuration du graphique
    fig.update_layout(
        title="Boom Rising Channel Predictor - Analyse en Temps Réel",
        xaxis_title="Temps",
        yaxis_title="Prix",
        height=800,
        showlegend=True
    )
    
    fig.update_xaxes(title_text="Temps", row=2, col=1)
    fig.update_yaxes(title_text="Volume", row=2, col=1)
    
    st.plotly_chart(fig, use_container_width=True)
    
    # Légende des indicateurs
    st.markdown("### 📋 Légende des Indicateurs")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.markdown("**Lignes de Prix:**")
        st.markdown("🔵 Prix Boom")
        st.markdown("🔴 EMA 10")
        st.markdown("🟠 EMA 30")
        st.markdown("🟢 EMA 50")
    
    with col2:
        st.markdown("**Canal Haussier:**")
        st.markdown("🟢 Ligne Supérieure")
        st.markdown("🟢 Ligne Inférieure")
        st.markdown("🟢 Zone de Canal")
    
    with col3:
        st.markdown("**Prédictions:**")
        st.markdown("🔼 Flèche Verte = BOOM")
        st.markdown("🔽 Flèche Rouge = CRASH")
        st.markdown("📊 Taille = Confiance")

def display_positions():
    """Affiche les positions actives"""
    st.header("📋 Positions Actives")
    
    positions = get_boom_positions()
    
    if not positions:
        st.info("📭 Aucune position active")
    else:
        # Créer un DataFrame pour l'affichage
        df = pd.DataFrame(positions)
        
        # Afficher le tableau
        st.dataframe(df, use_container_width=True)
        
        # Métriques des positions
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.metric("Total Positions", len(positions))
        
        with col2:
            buy_positions = len([p for p in positions if p['type'] == 'BUY'])
            st.metric("Positions BUY", buy_positions)
        
        with col3:
            sell_positions = len([p for p in positions if p['type'] == 'SELL'])
            st.metric("Positions SELL", sell_positions)
        
        with col4:
            avg_confidence = np.mean([p['confidence'] for p in positions])
            st.metric("Confiance Moyenne", f"{avg_confidence:.1%}")
        
        # Graphique des positions
        st.markdown("### 📊 Répartition des Positions")
        
        # Graphique en barres par type
        type_counts = df['type'].value_counts()
        fig_type = px.bar(x=type_counts.index, y=type_counts.values, 
                         title="Positions par Type")
        st.plotly_chart(fig_type, use_container_width=True)
        
        # Graphique de confiance
        fig_conf = px.histogram(df, x='confidence', nbins=10, 
                              title="Distribution de la Confiance")
        st.plotly_chart(fig_conf, use_container_width=True)

def display_statistics():
    """Affiche les statistiques de trading"""
    st.header("📊 Statistiques de Trading")
    
    # Charger l'historique des trades
    try:
        with open('boom_trade_history.json', 'r') as f:
            trades = [json.loads(line) for line in f.readlines()]
        
        if trades:
            df_trades = pd.DataFrame(trades)
            
            # Métriques principales
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                total_trades = len(df_trades)
                st.metric("Total Trades", total_trades)
            
            with col2:
                profitable_trades = len(df_trades[df_trades['profit'] > 0])
                win_rate = profitable_trades / total_trades if total_trades > 0 else 0
                st.metric("Taux de Réussite", f"{win_rate:.1%}")
            
            with col3:
                total_profit = df_trades['profit'].sum()
                st.metric("Profit Total", f"{total_profit:.2f}")
            
            with col4:
                avg_profit = df_trades['profit'].mean()
                st.metric("Profit Moyen", f"{avg_profit:.2f}")
            
            # Graphiques
            st.markdown("### 📈 Évolution des Profits")
            
            # Graphique des profits cumulés
            df_trades['cumulative_profit'] = df_trades['profit'].cumsum()
            fig_profit = px.line(df_trades, x='timestamp', y='cumulative_profit',
                                title="Profit Cumulé")
            st.plotly_chart(fig_profit, use_container_width=True)
            
            # Graphique de répartition des profits
            fig_dist = px.histogram(df_trades, x='profit', nbins=20,
                                  title="Distribution des Profits")
            st.plotly_chart(fig_dist, use_container_width=True)
            
            # Analyse par EMA
            st.markdown("### 🎯 Performance par Proximité EMA")
            
            ema_performance = df_trades.groupby('ema_proximity').agg({
                'profit': ['count', 'sum', 'mean'],
                'prediction_confidence': 'mean'
            }).round(2)
            
            st.dataframe(ema_performance, use_container_width=True)
            
            # Graphique de performance par EMA
            ema_profit = df_trades.groupby('ema_proximity')['profit'].mean()
            fig_ema = px.bar(x=ema_profit.index, y=ema_profit.values,
                           title="Profit Moyen par EMA")
            st.plotly_chart(fig_ema, use_container_width=True)
        
        else:
            st.info("📭 Aucun historique de trades disponible")
    
    except FileNotFoundError:
        st.info("📭 Fichier d'historique non trouvé")
    except Exception as e:
        st.error(f"❌ Erreur lors du chargement des statistiques: {e}")

def create_sample_data():
    """Crée des données d'exemple pour le graphique"""
    # Simulation de données de prix
    test_data = []
    base_price = 10000.0
    
    for i in range(100):
        # Simulation d'un canal haussier
        trend_factor = i * 0.1  # Tendance haussière
        noise = np.random.normal(0, 0.5)
        price = base_price + trend_factor + noise
        
        test_data.append({
            'timestamp': time.time() - (100-i) * 60,  # 1 minute par bougie
            'open': price,
            'high': price + abs(np.random.normal(0, 0.3)),
            'low': price - abs(np.random.normal(0, 0.3)),
            'close': price,
            'volume': np.random.randint(1000, 5000)
        })
    
    # Mettre à jour le prédicteur avec les données simulées
    update_boom_data(test_data)

if __name__ == "__main__":
    main()
