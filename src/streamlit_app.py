"""
Interface Streamlit pour TradBOT
Communique avec l'API Render déployée
"""

import streamlit as st
import requests
import json
from datetime import datetime
import pandas as pd

# Configuration
API_URL = "https://kolatradebot.onrender.com"

st.set_page_config(
    page_title="TradBOT Dashboard",
    page_icon="📈",
    layout="wide"
)

st.title("🤖 TradBOT - Dashboard de Trading")
st.markdown("---")

# Sidebar pour la configuration
with st.sidebar:
    st.header("⚙️ Configuration")
    api_url = st.text_input("URL de l'API", value=API_URL)
    
    st.markdown("---")
    st.markdown("### 📊 Statut")
    
    # Vérifier la santé de l'API
    try:
        health_response = requests.get(f"{api_url}/health", timeout=5)
        if health_response.status_code == 200:
            st.success("✅ API connectée")
            health_data = health_response.json()
            st.json(health_data)
        else:
            st.error(f"❌ API erreur: {health_response.status_code}")
    except Exception as e:
        st.error(f"❌ Impossible de se connecter à l'API: {str(e)}")
        st.info("💡 Vérifiez que l'API est déployée sur Render")

# Onglets principaux
tab1, tab2, tab3, tab4 = st.tabs(["📊 Dashboard", "🔍 Analyse", "📈 Tendances", "📡 API Status"])

with tab1:
    st.header("Dashboard Principal")
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Status API", "🟢 En ligne" if health_response.status_code == 200 else "🔴 Hors ligne")
    
    with col2:
        try:
            status_response = requests.get(f"{api_url}/status", timeout=5)
            if status_response.status_code == 200:
                status_data = status_response.json()
                st.metric("Version", status_data.get("version", "N/A"))
        except:
            st.metric("Version", "N/A")
    
    with col3:
        st.metric("Uptime", "100%")
    
    with col4:
        st.metric("Endpoints", "20+")

with tab2:
    st.header("🔍 Analyse de Marché")
    
    symbol = st.text_input("Symbole", value="EURUSD")
    timeframe = st.selectbox("Timeframe", ["M1", "M5", "M15", "H1", "H4", "D1"])
    
    if st.button("Analyser"):
        try:
            with st.spinner("Analyse en cours..."):
                # Appel à l'API d'analyse
                analysis_url = f"{api_url}/analysis?symbol={symbol}"
                response = requests.get(analysis_url, timeout=10)
                
                if response.status_code == 200:
                    data = response.json()
                    st.success("✅ Analyse réussie")
                    st.json(data)
                else:
                    st.error(f"Erreur: {response.status_code}")
        except Exception as e:
            st.error(f"Erreur lors de l'analyse: {str(e)}")

with tab3:
    st.header("📈 Analyse de Tendance")
    
    symbol_trend = st.text_input("Symbole pour tendance", value="EURUSD", key="trend_symbol")
    timeframe_trend = st.selectbox("Timeframe", ["M1", "M5", "M15", "H1", "H4", "D1"], key="trend_tf")
    
    if st.button("Obtenir la tendance"):
        try:
            with st.spinner("Calcul de la tendance..."):
                trend_url = f"{api_url}/trend?symbol={symbol_trend}&timeframe={timeframe_trend}"
                response = requests.get(trend_url, timeout=10)
                
                if response.status_code == 200:
                    trend_data = response.json()
                    st.success("✅ Tendance calculée")
                    
                    # Afficher les résultats
                    col1, col2 = st.columns(2)
                    with col1:
                        st.metric("Direction", trend_data.get("direction", "N/A"))
                        st.metric("Force", f"{trend_data.get('strength', 0)}%")
                    with col2:
                        st.metric("Confiance", f"{trend_data.get('confidence', 0)}%")
                        st.metric("Signal", trend_data.get("signal", "N/A"))
                    
                    st.json(trend_data)
                else:
                    st.error(f"Erreur: {response.status_code}")
        except Exception as e:
            st.error(f"Erreur: {str(e)}")

with tab4:
    st.header("📡 Statut de l'API")
    
    st.subheader("Endpoints disponibles")
    
    endpoints = [
        {"name": "Health Check", "url": "/health", "method": "GET"},
        {"name": "Status", "url": "/status", "method": "GET"},
        {"name": "Decision", "url": "/decision", "method": "POST"},
        {"name": "Trend", "url": "/trend", "method": "GET"},
        {"name": "Analysis", "url": "/analysis", "method": "GET"},
        {"name": "Documentation", "url": "/docs", "method": "GET"},
    ]
    
    for endpoint in endpoints:
        with st.expander(f"{endpoint['method']} {endpoint['name']}"):
            st.code(f"{api_url}{endpoint['url']}")
            if st.button(f"Tester {endpoint['name']}", key=endpoint['name']):
                try:
                    if endpoint['method'] == "GET":
                        response = requests.get(f"{api_url}{endpoint['url']}", timeout=5)
                    else:
                        st.info("Endpoint POST - Utilisez l'onglet Analyse")
                        continue
                    
                    if response.status_code == 200:
                        st.success("✅ Succès")
                        st.json(response.json())
                    else:
                        st.error(f"❌ Erreur {response.status_code}")
                except Exception as e:
                    st.error(f"Erreur: {str(e)}")
    
    st.markdown("---")
    st.markdown(f"### 📚 Documentation complète")
    st.markdown(f"[Documentation interactive]({api_url}/docs)")

# Footer
st.markdown("---")
st.markdown("**TradBOT** - Système de trading automatisé avec IA")
st.markdown(f"API déployée sur: `{api_url}`")

