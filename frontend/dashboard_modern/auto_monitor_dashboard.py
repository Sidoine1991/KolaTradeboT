#!/usr/bin/env python3
"""
Dashboard en temps réel pour le moniteur automatique de signaux
Interface moderne avec contrôle de configuration et monitoring live
"""
import streamlit as st
import requests
import json
import time
import pandas as pd
from datetime import datetime, timedelta
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots

# Configuration
API_BASE_URL = "http://localhost:8000"
REFRESH_INTERVAL = 5  # secondes

def get_api_data(endpoint):
    """Récupère les données depuis l'API"""
    try:
        response = requests.get(f"{API_BASE_URL}{endpoint}", timeout=10)
        if response.status_code == 200:
            return response.json()
        else:
            st.error(f"Erreur API {response.status_code}: {response.text}")
            return None
    except Exception as e:
        st.error(f"Erreur connexion API: {str(e)}")
        return None

def post_api_data(endpoint, data=None):
    """Envoie des données à l'API"""
    try:
        if data:
            response = requests.post(f"{API_BASE_URL}{endpoint}", json=data, timeout=10)
        else:
            response = requests.post(f"{API_BASE_URL}{endpoint}", timeout=10)
        
        if response.status_code == 200:
            return response.json()
        else:
            st.error(f"Erreur API {response.status_code}: {response.text}")
            return None
    except Exception as e:
        st.error(f"Erreur connexion API: {str(e)}")
        return None

def put_api_data(endpoint, data):
    """Met à jour des données via l'API"""
    try:
        response = requests.put(f"{API_BASE_URL}{endpoint}", json=data, timeout=10)
        if response.status_code == 200:
            return response.json()
        else:
            st.error(f"Erreur API {response.status_code}: {response.text}")
            return None
    except Exception as e:
        st.error(f"Erreur connexion API: {str(e)}")
        return None

def format_uptime(uptime_str):
    """Formate l'uptime pour l'affichage"""
    if uptime_str == "N/A":
        return "N/A"
    try:
        # Parse "X days, HH:MM:SS" format
        if "days" in uptime_str:
            days = int(uptime_str.split(" days")[0])
            time_part = uptime_str.split(", ")[1]
            hours, minutes, seconds = map(int, time_part.split(":"))
            return f"{days}j {hours}h {minutes}m"
        else:
            hours, minutes, seconds = map(int, uptime_str.split(":"))
            return f"{hours}h {minutes}m"
    except:
        return uptime_str

def create_confidence_chart(confidence_data):
    """Crée un graphique de distribution de confiance"""
    if not confidence_data:
        return None
    
    fig = go.Figure(data=[
        go.Bar(
            x=['Élevée (80-100%)', 'Moyenne (70-79%)', 'Faible (<70%)'],
            y=[
                confidence_data.get('high', 0),
                confidence_data.get('medium', 0),
                confidence_data.get('low', 0)
            ],
            marker_color=['#00ff00', '#ffff00', '#ff0000'],
            text=[
                confidence_data.get('high', 0),
                confidence_data.get('medium', 0),
                confidence_data.get('low', 0)
            ],
            textposition='auto',
        )
    ])
    
    fig.update_layout(
        title="Distribution de Confiance des Signaux",
        xaxis_title="Niveau de Confiance",
        yaxis_title="Nombre de Signaux",
        height=300,
        showlegend=False
    )
    
    return fig

def create_signals_timeline(symbols_scanned):
    """Crée un graphique de timeline des signaux"""
    if not symbols_scanned:
        return None
    
    # Préparer les données pour la timeline
    timeline_data = []
    for symbol, data in symbols_scanned.items():
        if 'last_success' in data:
            try:
                last_success = datetime.fromisoformat(data['last_success'].replace('Z', '+00:00'))
                timeline_data.append({
                    'symbol': symbol,
                    'last_success': last_success,
                    'success_count': data.get('success_count', 0)
                })
            except:
                continue
    
    if not timeline_data:
        return None
    
    # Trier par date
    timeline_data.sort(key=lambda x: x['last_success'], reverse=True)
    
    # Créer le graphique
    fig = go.Figure()
    
    for item in timeline_data[:20]:  # Top 20
        fig.add_trace(go.Scatter(
            x=[item['last_success']],
            y=[item['symbol']],
            mode='markers',
            marker=dict(
                size=min(item['success_count'] * 5 + 10, 30),
                color=item['success_count'],
                colorscale='Viridis',
                showscale=True,
                colorbar=dict(title="Succès")
            ),
            text=f"Succès: {item['success_count']}",
            hovertemplate='<b>%{y}</b><br>Dernier succès: %{x}<br>Succès: %{text}<extra></extra>'
        ))
    
    fig.update_layout(
        title="Timeline des Signaux par Symbole",
        xaxis_title="Date/Heure",
        yaxis_title="Symbole",
        height=400,
        showlegend=False
    )
    
    return fig

def main():
    st.set_page_config(
        page_title="Auto Monitor Dashboard",
        page_icon="🤖",
        layout="wide",
        initial_sidebar_state="expanded"
    )
    
    # CSS personnalisé
    st.markdown("""
    <style>
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #1f77b4;
    }
    .status-running {
        color: #00ff00;
        font-weight: bold;
    }
    .status-stopped {
        color: #ff0000;
        font-weight: bold;
    }
    </style>
    """, unsafe_allow_html=True)
    
    # Titre principal
    st.title("🤖 Dashboard Auto Monitor - TradBOT")
    st.markdown("---")
    
    # Sidebar pour les contrôles
    with st.sidebar:
        st.header("🎛️ Contrôles")
        
        # Boutons de contrôle
        col1, col2 = st.columns(2)
        
        with col1:
            if st.button("▶️ Démarrer", type="primary"):
                result = post_api_data("/auto_monitor/start")
                if result:
                    st.success("Moniteur démarré!")
                    time.sleep(1)
        
        with col2:
            if st.button("⏹️ Arrêter"):
                result = post_api_data("/auto_monitor/stop")
                if result:
                    st.success("Moniteur arrêté!")
                    time.sleep(1)
        
        st.markdown("---")
        
        # Scan manuel
        if st.button("🔍 Scan Manuel"):
            result = post_api_data("/auto_monitor/scan_now")
            if result:
                st.success("Scan manuel déclenché!")
                time.sleep(1)
        
        # Reset stats
        if st.button("🔄 Reset Stats"):
            result = post_api_data("/auto_monitor/reset_stats")
            if result:
                st.success("Statistiques réinitialisées!")
                time.sleep(1)
        
        st.markdown("---")
        
        # Configuration
        st.header("⚙️ Configuration")
        
        # Récupérer la config actuelle
        config_data = get_api_data("/auto_monitor/config")
        if config_data and config_data.get('status') == 'success':
            config = config_data.get('config', {})
            
            # Paramètres configurables
            new_config = {}
            
            scan_interval = st.slider(
                "Intervalle de scan (minutes)",
                min_value=1,
                max_value=60,
                value=config.get('scan_interval', 5)
            )
            new_config['scan_interval'] = scan_interval
            
            max_signals = st.slider(
                "Max signaux/heure",
                min_value=1,
                max_value=50,
                value=config.get('max_signals_per_hour', 10)
            )
            new_config['max_signals_per_hour'] = max_signals
            
            min_confidence = st.slider(
                "Confiance minimale (%)",
                min_value=50,
                max_value=95,
                value=config.get('min_confidence', 75)
            )
            new_config['min_confidence'] = min_confidence
            
            min_trend_confidence = st.slider(
                "Confiance tendance min (%)",
                min_value=50,
                max_value=95,
                value=config.get('min_trend_confidence', 70)
            )
            new_config['min_trend_confidence'] = min_trend_confidence
            
            timeout_seconds = st.slider(
                "Timeout (secondes)",
                min_value=10,
                max_value=60,
                value=config.get('timeout_seconds', 30)
            )
            new_config['timeout_seconds'] = timeout_seconds
            
            max_symbols = st.slider(
                "Max symboles/scan",
                min_value=10,
                max_value=100,
                value=config.get('max_symbols_per_scan', 25)
            )
            new_config['max_symbols_per_scan'] = max_symbols
            
            # Options booléennes
            enable_whatsapp = st.checkbox(
                "Activer WhatsApp",
                value=config.get('enable_whatsapp', True)
            )
            new_config['enable_whatsapp'] = enable_whatsapp
            
            enable_logging = st.checkbox(
                "Logging détaillé",
                value=config.get('enable_logging', True)
            )
            new_config['enable_logging'] = enable_logging
            
            retry_failed = st.checkbox(
                "Réessayer symboles échoués",
                value=config.get('retry_failed_symbols', True)
            )
            new_config['retry_failed_symbols'] = retry_failed
            
            # Appliquer la configuration
            if st.button("💾 Appliquer Config", type="secondary"):
                result = put_api_data("/auto_monitor/config", new_config)
                if result:
                    st.success("Configuration mise à jour!")
                    time.sleep(1)
    
    # Contenu principal
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.header("📊 Statut en Temps Réel")
        
        # Récupérer le statut
        status_data = get_api_data("/auto_monitor/status")
        
        if status_data:
            # Métriques principales
            col1_1, col1_2, col1_3, col1_4 = st.columns(4)
            
            with col1_1:
                st.metric(
                    "Statut",
                    "🟢 ACTIF" if status_data.get('running') else "🔴 ARRÊTÉ",
                    delta=None
                )
            
            with col1_2:
                st.metric(
                    "Uptime",
                    format_uptime(status_data.get('uptime', 'N/A')),
                    delta=None
                )
            
            with col1_3:
                st.metric(
                    "Scans Totaux",
                    status_data.get('stats', {}).get('total_scans', 0),
                    delta=None
                )
            
            with col1_4:
                st.metric(
                    "Signaux/Heure",
                    f"{status_data.get('signal_count_this_hour', 0)}/{status_data.get('max_signals_per_hour', 10)}",
                    delta=None
                )
            
            # Métriques détaillées
            col2_1, col2_2, col2_3, col2_4 = st.columns(4)
            
            stats = status_data.get('stats', {})
            
            with col2_1:
                st.metric(
                    "Signaux Générés",
                    stats.get('signals_generated', 0),
                    delta=None
                )
            
            with col2_2:
                st.metric(
                    "Signaux Envoyés",
                    stats.get('signals_sent', 0),
                    delta=None
                )
            
            with col2_3:
                st.metric(
                    "Signaux Rejetés",
                    stats.get('signals_rejected', 0),
                    delta=None
                )
            
            with col2_4:
                st.metric(
                    "Erreurs",
                    stats.get('errors', 0),
                    delta=None
                )
            
            # Dernier signal
            last_signal = stats.get('last_signal_time')
            if last_signal:
                st.info(f"🎯 Dernier signal: {last_signal}")
            else:
                st.warning("⚠️ Aucun signal envoyé")
            
            # Graphiques
            st.markdown("---")
            st.header("📈 Graphiques")
            
            # Distribution de confiance
            confidence_data = stats.get('confidence_distribution', {})
            if confidence_data:
                fig_confidence = create_confidence_chart(confidence_data)
                if fig_confidence:
                    st.plotly_chart(fig_confidence, use_container_width=True)
            
            # Timeline des signaux
            symbols_scanned = stats.get('symbols_scanned', {})
            if symbols_scanned:
                fig_timeline = create_signals_timeline(symbols_scanned)
                if fig_timeline:
                    st.plotly_chart(fig_timeline, use_container_width=True)
    
    with col2:
        st.header("📋 Détails")
        
        if status_data:
            # Configuration actuelle
            st.subheader("⚙️ Configuration Actuelle")
            config = status_data.get('config', {})
            
            config_df = pd.DataFrame([
                ["Intervalle scan", f"{config.get('scan_interval', 5)} min"],
                ["Max signaux/heure", config.get('max_signals_per_hour', 10)],
                ["Confiance min", f"{config.get('min_confidence', 75)}%"],
                ["Confiance tendance", f"{config.get('min_trend_confidence', 70)}%"],
                ["Timeout", f"{config.get('timeout_seconds', 30)}s"],
                ["Max symboles", config.get('max_symbols_per_scan', 25)],
                ["WhatsApp", "✅" if config.get('enable_whatsapp', True) else "❌"],
                ["Logging", "✅" if config.get('enable_logging', True) else "❌"],
                ["Retry échecs", "✅" if config.get('retry_failed_symbols', True) else "❌"],
            ], columns=["Paramètre", "Valeur"])
            
            st.dataframe(config_df, hide_index=True, use_container_width=True)
            
            # Symboles prioritaires
            st.subheader("🎯 Symboles Prioritaires")
            priority_count = status_data.get('priority_symbols_count', 0)
            st.metric("Nombre", priority_count)
            
            # Symboles échoués
            st.subheader("❌ Symboles Échoués")
            failed_count = status_data.get('failed_symbols_count', 0)
            st.metric("Nombre", failed_count)
            
            if failed_count > 0:
                st.warning(f"{failed_count} symboles en échec")
    
    # Auto-refresh
    if st.button("🔄 Actualiser"):
        st.rerun()
    
    # Auto-refresh automatique
    time.sleep(REFRESH_INTERVAL)
    st.rerun()

if __name__ == "__main__":
    main() 