import streamlit as st
import pandas as pd
from datetime import datetime, timedelta

# Import backend prediction functions
from backend.mt5_connector import get_ohlc, get_all_symbols, TIMEFRAME_MAPPING
from backend.spike_detector import predict_spike_ml, batch_predict_spike_ml, predict_spike_realtime_ml, get_realtime_spike_analysis
from backend.advanced_analysis import predict_trend_ml
from backend.adaptive_predict import predict_adaptive

st.set_page_config(page_title="Prédictions ML - TradBOT", page_icon="🔮", layout="wide")
st.title("🔮 Prédictions Multi-Models (ML)")

# Sidebar: Symbol and timeframe selection
st.sidebar.header("Sélection des paramètres")
symbols = get_all_symbols()
symbol = st.sidebar.selectbox("Symbole", symbols, index=0)
timeframes = list(TIMEFRAME_MAPPING.keys())
timeframe = st.sidebar.selectbox("Timeframe", timeframes, index=0)
candle_count = st.sidebar.slider("Nombre de bougies", min_value=50, max_value=1000, value=200, step=10)

# Fetch OHLCV data
df = None
try:
    df = get_ohlc(symbol, timeframe, candle_count)
    if df is not None and not df.empty:
        st.success(f"Données chargées pour {symbol} ({timeframe}), {len(df)} lignes.")
    else:
        st.warning("Aucune donnée OHLCV trouvée.")
except Exception as e:
    st.error(f"Erreur lors du chargement des données: {e}")

if df is not None and not df.empty:
    tabs = st.tabs(["Spike ML (dernier tick)", "Spike ML (batch)", "Spike ML temps réel", "Tendance ML", "Modèle Adaptatif"])
    # --- Spike ML (dernier tick) ---
    with tabs[0]:
        st.subheader("Prédiction Spike ML (dernier tick)")
        proba = predict_spike_ml(df)
        if proba is not None:
            st.metric("Probabilité de spike imminent (ML)", f"{proba:.1%}")
        else:
            st.info("Modèle non disponible ou données insuffisantes.")
    # --- Spike ML (batch) ---
    with tabs[1]:
        st.subheader("Prédiction Spike ML (batch)")
        batch = batch_predict_spike_ml(df)
        if batch is not None and not batch.isnull().all():
            st.line_chart(batch, use_container_width=True)
            st.write("Dernières valeurs:", batch.tail(5))
        else:
            st.info("Modèle non disponible ou données insuffisantes.")
    # --- Spike ML temps réel ---
    with tabs[2]:
        st.subheader("Prédiction Spike ML en temps réel (avec prix actuel)")
        if len(df) > 0:
            current_price = df['close'].iloc[-1]
            pred = predict_spike_realtime_ml(symbol, current_price, df)
            if pred:
                st.json(pred)
            else:
                st.info("Modèle non disponible ou données insuffisantes.")
            st.caption("Utilise le dernier prix de la série comme prix actuel.")
        else:
            st.warning("Données insuffisantes.")
    # --- Tendance ML ---
    with tabs[3]:
        st.subheader("Prédiction de tendance ML")
        try:
            trend_df = predict_trend_ml(df)
            if trend_df is not None and not trend_df.empty:
                st.line_chart(trend_df['trend_pred'], use_container_width=True)
                st.write("Dernières valeurs:", trend_df.tail(5))
            else:
                st.info("Modèle non disponible ou données insuffisantes.")
        except Exception as e:
            st.error(f"Erreur lors de la prédiction de tendance: {e}")
    # --- Modèle Adaptatif ---
    with tabs[4]:
        st.subheader("Prédiction par Modèle Adaptatif (Catégorie)")
        result = predict_adaptive(symbol, df)
        if 'error' in result:
            st.warning(result['error'])
            st.info(f"Catégorie détectée: {result.get('category', '?')}, Modèle: {result.get('model_name', '?')}")
        else:
            st.success(f"Catégorie: {result['category']} | Modèle: {result['model_name']}")
            st.metric("Prédiction (direction)", "Hausse" if result['prediction'] else "Baisse")
            st.metric("Probabilité (classe 1)", f"{result['probability']:.1%}")
            st.write("**Features utilisées (dernière ligne):**")
            st.json(result['input_row'])
            # Export options
            st.download_button("Exporter résultats (JSON)", data=pd.Series(result).to_json(), file_name=f"{symbol}_adaptive_pred.json")
            st.download_button("Exporter features (CSV)", data=pd.DataFrame([result['input_row']]).to_csv(index=False), file_name=f"{symbol}_features.csv")
            # Feature importances (if available)
            try:
                import joblib
                config = result['category']
                from backend.adaptive_predict import MODEL_CONFIGS
                model_path = MODEL_CONFIGS[config]['model_path']
                model = joblib.load(model_path)
                if hasattr(model, 'feature_importances_'):
                    import plotly.express as px
                    importances = model.feature_importances_
                    features = result['features_used']
                    fig = px.bar(x=features, y=importances, labels={'x': 'Feature', 'y': 'Importance'}, title='Importance des features (modèle)')
                    st.plotly_chart(fig, use_container_width=True)
            except Exception as e:
                st.info(f"Impossible d'afficher l'importance des features: {e}")
else:
    st.info("Veuillez sélectionner un symbole et un timeframe pour afficher les prédictions.") 