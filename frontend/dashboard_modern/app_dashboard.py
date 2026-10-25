"""
Dashboard moderne de prédiction des mouvements futurs des prix
- Sélection du symbole, timeframe, horizon
- Prédictions ML, graphiques, explications, export
- UI moderne et responsive
"""
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))
import streamlit as st
import pandas as pd
import requests
from datetime import datetime, timedelta
from backend.mt5_connector import get_ohlc, get_all_symbols, TIMEFRAME_MAPPING, get_symbols_by_category
from backend.spike_detector import predict_spike_ml, batch_predict_spike_ml
from backend.advanced_analysis import predict_trend_ml
from backend.adaptive_predict import predict_adaptive

st.set_page_config(page_title="Dashboard Prédiction Prix", page_icon="📈", layout="wide")
st.title("📈 Dashboard Prédiction des Mouvements Futurs")

# Configuration API
API_BASE_URL = "http://localhost:8000"

# Fonction pour récupérer l'état de validation de tendance
def get_trend_validation_status():
    try:
        response = requests.get(f"{API_BASE_URL}/trend_validation_status")
        if response.status_code == 200:
            return response.json().get("trend_validation_enabled", True)
        return True
    except:
        return True

# Fonction pour changer l'état de validation de tendance
def set_trend_validation(enabled):
    try:
        response = requests.post(f"{API_BASE_URL}/set_trend_validation", json={"enabled": enabled})
        return response.status_code == 200
    except:
        return False

# Sidebar - Sélection
st.sidebar.header("Paramètres de prédiction")

# Section Validation de Tendance
st.sidebar.subheader("🔧 Configuration Signaux")
current_validation_status = get_trend_validation_status()
validation_status_text = "✅ Activée" if current_validation_status else "❌ Désactivée"
st.sidebar.info(f"**Validation de tendance :** {validation_status_text}")

# Boutons pour changer l'état
col1, col2 = st.sidebar.columns(2)
with col1:
    if st.button("✅ Activer", key="enable_validation"):
        if set_trend_validation(True):
            st.success("Validation activée !")
            st.rerun()
        else:
            st.error("Erreur lors de l'activation")
with col2:
    if st.button("❌ Désactiver", key="disable_validation"):
        if set_trend_validation(False):
            st.success("Validation désactivée !")
            st.rerun()
        else:
            st.error("Erreur lors de la désactivation")

st.sidebar.markdown("---")

# Paramètres de prédiction existants
symbol_categories = ['TOUS', 'FOREX', 'SYNTHETIC', 'CRYPTO', 'INDICES', 'COMMODITIES', 'STOCKS', 'OTHER']
category = st.sidebar.selectbox("Catégorie de symbole", symbol_categories, index=0)
if category == 'TOUS':
    symbols = get_all_symbols()
else:
    symbols = get_symbols_by_category(category)
# Ajout d'un champ de recherche dynamique
symbol_search = st.sidebar.text_input("🔍 Rechercher un symbole", "", key="dashboard_sidebar_symbol_search")
if symbol_search:
    filtered_symbols = [s for s in symbols if symbol_search.upper() in s.upper()]
else:
    filtered_symbols = symbols
symbol = st.sidebar.selectbox("Symbole", filtered_symbols, index=0 if filtered_symbols else None)
timeframes = list(TIMEFRAME_MAPPING.keys())
timeframe = st.sidebar.selectbox("Timeframe", timeframes, index=0)
horizons = ["1h", "4h", "1j", "1s"]
horizon = st.sidebar.selectbox("Horizon de prédiction", horizons, index=0)
candle_count = st.sidebar.slider("Nombre de bougies", min_value=50, max_value=1000, value=200, step=10)

# Chargement des données
@st.cache_data(ttl=60)
def load_data(symbol, timeframe, count):
    return get_ohlc(symbol, timeframe, count)

df = load_data(symbol, timeframe, candle_count)

# Résumé en haut de page
st.subheader("Résumé des signaux et prédictions")
col1, col2, col3 = st.columns(3)
with col1:
    st.metric("Dernier prix", f"{df['close'].iloc[-1]:.4f}" if df is not None and not df.empty else "N/A")
with col2:
    proba_spike = predict_spike_ml(df) if df is not None and not df.empty else None
    # Correction: ensure proba_spike is a float before formatting
    if isinstance(proba_spike, float):
        proba_spike_display = f"{proba_spike:.1%}"
    else:
        proba_spike_display = "N/A"
    st.metric("Proba Spike ML (tick)", proba_spike_display)
with col3:
    trend_df = predict_trend_ml(df) if df is not None and not df.empty else None
    last_trend = trend_df['trend_pred'].dropna().iloc[-1] if trend_df is not None and not trend_df.empty else None
    st.metric("Tendance ML", "Hausse" if last_trend == 1 else "Baisse" if last_trend == -1 else "Neutre" if last_trend == 0 else "N/A")

# Tabs principales
tabs = st.tabs(["Graphique & Prédiction", "Explication", "Export", "Tendance consolidée (D1, H4, H1, M30, M15, M5, M1)"])

# Tab 1: Graphique & Prédiction
with tabs[0]:
    st.subheader("Graphique interactif et prédiction future")
    if df is not None and not df.empty:
        import plotly.graph_objects as go
        fig = go.Figure()
        fig.add_trace(go.Candlestick(x=df['timestamp'], open=df['open'], high=df['high'], low=df['low'], close=df['close'], name='Prix'))
        # Ajout prédiction adaptative
        result = predict_adaptive(symbol, df)
        if 'probability' in result:
            fig.add_trace(go.Scatter(x=[df['timestamp'].iloc[-1]], y=[df['close'].iloc[-1]], mode='markers+text', marker=dict(size=14, color='red'), text=[f"{result['probability']*100:.1f}%"], name='Proba ML'))
        st.plotly_chart(fig, use_container_width=True)
        # Affichage horizon
        st.info(f"Horizon de prédiction sélectionné : {horizon}")
        # Probabilité future (placeholder)
        st.metric(f"Probabilité de hausse dans {horizon}", f"{result['probability']*100:.1f}%" if 'probability' in result else "N/A")
        # --- SPIKE ALERT ---
        proba_spike = predict_spike_ml(df)
        spike_threshold = 0.8
        if isinstance(proba_spike, float) and proba_spike >= spike_threshold:
            buy_price = df['close'].iloc[-1]
            tp = buy_price * 1.02  # +2%
            sl = buy_price * 0.99  # -1%
            st.error(f"🚨 SPIKE DÉTECTÉ !\n\n**Prix d'achat :** {buy_price:.4f}\n**TP :** {tp:.4f}\n**SL :** {sl:.4f}")
    else:
        st.warning("Aucune donnée disponible pour ce symbole/timeframe.")

# Tab 2: Explication
with tabs[1]:
    st.subheader("Explication de la prédiction")
    if df is not None and not df.empty:
        result = predict_adaptive(symbol, df)
        if 'error' in result:
            st.warning(result['error'])
        else:
            st.write(f"**Catégorie détectée :** {result['category']}")
            st.write(f"**Modèle utilisé :** {result['model_name']}")
            st.write("**Features utilisées (dernière ligne) :**")
            st.json(result['input_row'])
            # Feature importances
            try:
                import joblib
                from backend.adaptive_predict import MODEL_CONFIGS
                model_path = MODEL_CONFIGS[result['category']]['model_path']
                model = joblib.load(model_path)
                if hasattr(model, 'feature_importances_'):
                    import plotly.express as px
                    importances = model.feature_importances_
                    features = result['features_used']
                    fig = px.bar(x=features, y=importances, labels={'x': 'Feature', 'y': 'Importance'}, title='Importance des features (modèle)')
                    st.plotly_chart(fig, use_container_width=True)
            except Exception as e:
                st.info(f"Impossible d'afficher l'importance des features: {e}")
            # Explication textuelle (placeholder)
            st.info("Explication automatique : Cette prédiction est basée sur les indicateurs techniques, la volatilité récente et le modèle ML spécialisé pour cette catégorie d'actif.")
    else:
        st.warning("Aucune donnée pour explication.")

# Tab 3: Export
with tabs[2]:
    st.subheader("Exporter les résultats")
    if df is not None and not df.empty:
        result = predict_adaptive(symbol, df)
        # Correction: ensure data is always a string, not None
        json_data = str(pd.Series(result).to_json()) if result is not None else "{}"
        if result is not None and 'input_row' in result and isinstance(result['input_row'], dict):
            features_csv = str(pd.DataFrame([result['input_row']]).to_csv(index=False))
        else:
            features_csv = ""
        ohlc_csv = str(df.to_csv(index=False)) if df is not None and not df.empty else ""
        st.download_button("Exporter prédiction (JSON)", data=json_data, file_name=f"{symbol}_prediction.json")
        st.download_button("Exporter features (CSV)", data=features_csv, file_name=f"{symbol}_features.csv")
        st.download_button("Exporter historique OHLC (CSV)", data=ohlc_csv, file_name=f"{symbol}_{timeframe}_ohlc.csv")
    else:
        st.info("Aucune donnée à exporter.")

# Tab 4: Tendance consolidée (Heatmap)
with tabs[3]:
    st.subheader("Heatmap Tendance Multi-Timeframe")
    import plotly.graph_objects as go
    trend_api_url = f"{API_BASE_URL}/trend_summary?symbol={symbol}"
    try:
        trend_response = requests.get(trend_api_url)
        if trend_response.status_code == 200:
            trend_data = trend_response.json()
            tf_order = ["1d", "4h", "1h", "30m", "15m", "5m", "1m"]
            tf_labels = ["D1", "H4", "H1", "M30", "M15", "M5", "M1"]
            trends = []
            forces = []
            annotations = []
            colors = []
            for tf in tf_order:
                tf_info = trend_data["trends"].get(tf, {})
                trend = tf_info.get("trend", "?")
                force = tf_info.get("force", "?")
                trends.append(trend)
                # Format force as percentage if possible
                try:
                    force_pct = f"{int(force)}%" if force != "?" else "?"
                except:
                    force_pct = "?"
                # Annotation: trend + force
                annotations.append(f"{trend}\n{force_pct}")
                # Color
                if trend == "bullish":
                    colors.append("#4CAF50")  # green
                elif trend == "bearish":
                    colors.append("#F44336")  # red
                elif trend == "neutral":
                    colors.append("#BDBDBD")  # gray
                else:
                    colors.append("#EEEEEE")  # light gray for unknown
            # Create heatmap (single row)
            fig = go.Figure(data=go.Heatmap(
                z=[[1]*len(tf_labels)],
                x=tf_labels,
                y=[symbol],
                text=[annotations],
                texttemplate="%{text}",
                colorscale=[[0, c] for c in colors],
                showscale=False,
                hoverinfo="text"
            ))
            # Manually set cell colors
            for i, color in enumerate(colors):
                fig.add_shape(type="rect",
                              x0=i-0.5, x1=i+0.5, y0=-0.5, y1=0.5,
                              fillcolor=color, line=dict(width=0))
            fig.update_traces(
                text=annotations,
                texttemplate="%{text}",
                hovertemplate="%{text}<extra></extra>"
            )
            fig.update_layout(
                xaxis=dict(title="Timeframe", tickmode="array", tickvals=tf_labels),
                yaxis=dict(title="Symbole", tickvals=[symbol]),
                margin=dict(l=40, r=40, t=40, b=40),
                height=120
            )
            st.plotly_chart(fig, use_container_width=True)
            consolidated = trend_data.get('consolidated', '?')
            confidence = trend_data.get('consolidated_confidence')
            score = trend_data.get('weighted_score')
            conf_str = f"{int(confidence)}%" if isinstance(confidence, (int, float)) else str(confidence)
            # Badge couleur
            if isinstance(consolidated, str):
                t = consolidated.lower()
                if t == 'bullish':
                    badge = '🟢'
                elif t == 'bearish':
                    badge = '🔴'
                elif t == 'neutral':
                    badge = '⚪'
                else:
                    badge = '❓'
            else:
                badge = '❓'
            st.caption(f"{badge} Tendance consolidée : {consolidated} | Confiance : {conf_str} | Score : {score} | Scalping : {trend_data.get('scalping_possible', '?')}")
        else:
            st.warning(f"Erreur API trend_summary: {trend_response.text}")
    except Exception as e:
        st.warning(f"Erreur lors de la récupération de la tendance: {e}")

# Section Signaux Multi-Timeframe
st.markdown("---")
st.subheader("🚨 Signaux Multi-Timeframe")
st.info("Génère des signaux en tenant compte de la tendance globale sur tous les timeframes (D1, H4, H1, M30, M15, M5)")

col1, col2 = st.columns(2)
with col1:
    if st.button("📊 Générer Signal MTF", key="generate_mtf_signal"):
        try:
            response = requests.get(f"{API_BASE_URL}/send_mtf_signal?symbol={symbol}")
            if response.status_code == 200:
                result = response.json()
                if result.get('status') == 'sent':
                    st.success("✅ Signal multi-timeframe généré et envoyé par WhatsApp !")
                    st.json(result.get('signal', {}))
                else:
                    st.warning(f"⚠️ {result.get('detail', 'Aucun signal valide')}")
            else:
                st.error(f"❌ Erreur API: {response.text}")
        except Exception as e:
            st.error(f"❌ Erreur: {e}")

with col2:
    if st.button("📱 Tester WhatsApp", key="test_whatsapp"):
        try:
            response = requests.get(f"{API_BASE_URL}/test_whatsapp")
            if response.status_code == 200:
                st.success("✅ Test WhatsApp réussi !")
            else:
                st.error(f"❌ Erreur test WhatsApp: {response.text}")
        except Exception as e:
            st.error(f"❌ Erreur: {e}")

# Footer
st.markdown("---")
st.caption("TradBOT - Dashboard moderne de prédiction des prix. API REST à venir.") 