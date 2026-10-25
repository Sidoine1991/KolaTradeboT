import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import streamlit as st
import pandas as pd
import numpy as np
import joblib
from datetime import datetime
from backend.mt5_connector import get_ohlc, get_all_symbols, TIMEFRAME_MAPPING
from backend.technical_analysis import add_stair_pattern_features

st.set_page_config(page_title="Sidoine_app - RF Signals", page_icon="🤖", layout="wide")
st.title("Sidoine_app : Signaux Buy/Sell par Random Forest")

# Sidebar - Sélection symbole et timeframe
symbols = get_all_symbols()
symbol = st.sidebar.selectbox("Symbole", symbols)
timeframes = list(TIMEFRAME_MAPPING.keys())
timeframe = st.sidebar.selectbox("Timeframe", timeframes, index=0)
candle_count = st.sidebar.slider("Nombre de bougies", min_value=100, max_value=1000, value=300, step=10)

# Chargement modèle RF
model_path = os.path.join("backend", "spike_rf_model.pkl")
scaler_path = os.path.join("backend", "spike_rf_model_scaler.pkl")
features_path = os.path.join("backend", "spike_rf_model_features.pkl")

try:
    model = joblib.load(model_path)
    scaler = joblib.load(scaler_path)
    feature_list = joblib.load(features_path)
    st.success(f"Modèle Random Forest chargé : {model_path}")
except Exception as e:
    st.error(f"Erreur chargement modèle RF : {e}")
    st.stop()

# Récupération des données
with st.spinner("Récupération des données..."):
    df = get_ohlc(symbol, timeframe, candle_count)
    if df is None or df.empty:
        st.error("Impossible de récupérer les données pour ce symbole/timeframe.")
        st.stop()
    df = add_stair_pattern_features(df)

# Préparation des features
X = df.copy()
missing_features = [f for f in feature_list if f not in X.columns]
if missing_features:
    st.warning(f"Features manquantes dans les données: {missing_features}")
    for f in missing_features:
        X[f] = 0.0
X = X[feature_list].fillna(0)
X_scaled = scaler.transform(X)

# Prédiction
probas = model.predict_proba(X_scaled)
preds = model.predict(X_scaled)
confidences = np.max(probas, axis=1)
labels = np.array(["SELL" if p==0 else "BUY" for p in preds])

# Seulement signaux avec confiance >= 0.8
signal_idx = np.where(confidences >= 0.8)[0]
if len(signal_idx) == 0:
    st.info("Aucun signal avec confiance >= 80% sur la période.")
else:
    st.subheader("Signaux détectés (confiance ≥ 80%)")
    signals = df.iloc[signal_idx].copy()
    signals["Signal"] = labels[signal_idx]
    signals["Confiance"] = confidences[signal_idx]
    # TP/SL simples : TP = close + 2*ATR (BUY), close - 2*ATR (SELL), SL = close - ATR (BUY), close + ATR (SELL)
    if "atr" in signals.columns:
        signals["TP"] = np.where(signals["Signal"]=="BUY", signals["close"]+2*signals["atr"], signals["close"]-2*signals["atr"])
        signals["SL"] = np.where(signals["Signal"]=="BUY", signals["close"]-signals["atr"], signals["close"]+signals["atr"])
    else:
        signals["TP"] = np.nan
        signals["SL"] = np.nan
    st.dataframe(signals[["time", "close", "Signal", "Confiance", "TP", "SL"]], use_container_width=True)
    # Export
    st.download_button("Exporter signaux CSV", signals.to_csv(index=False).encode(), file_name=f"signals_{symbol}_{timeframe}.csv", mime="text/csv")
    st.download_button("Exporter signaux JSON", signals.to_json(orient="records").encode(), file_name=f"signals_{symbol}_{timeframe}.json", mime="application/json")

st.caption("Sidoine_app - Algo RF indépendant. Pour toute question, contactez l'équipe.") 