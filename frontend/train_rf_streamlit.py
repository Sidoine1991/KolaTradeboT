import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import streamlit as st
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
import joblib
import time
from backend.technical_analysis import add_stair_pattern_features
from backend.spike_detector import label_future_spike

st.set_page_config(page_title="Entraînement RF - Sidoine", page_icon="🧠", layout="wide")
st.title("Entraînement Random Forest (version Streamlit)")

DATA_PATH = 'data/february_merged.csv'
MODEL_PATH = 'backend/spike_rf_model.pkl'
SCALER_PATH = 'backend/spike_rf_model_scaler.pkl'
FEATURES_PATH = 'backend/spike_rf_model_features.pkl'
REPORT_PATH = 'backend/spike_rf_training_report.txt'

if not os.path.exists(DATA_PATH):
    st.error(f"Fichier de données introuvable: {DATA_PATH}")
    st.stop()

# Paramètres
n_estimators = st.slider("Nombre d'arbres (n_estimators)", 10, 300, 100, 10)
max_depth = st.slider("Profondeur max (max_depth)", 2, 20, 6, 1)
test_size = st.slider("Taille test (%)", 5, 50, 20, 5) / 100

if st.button("Lancer l'entraînement"):
    df = pd.read_csv(DATA_PATH)
    df.columns = [col.strip().lower() for col in df.columns]
    _, idx = np.unique(df.columns, return_index=True)
    df = df.iloc[:, idx]
    st.write("Colonnes du DataFrame après suppression des doublons:", df.columns.tolist())
    st.write("Premières lignes :", df.head())
    # Conversion explicite des colonnes critiques en float
    for col in ['open', 'close', 'high', 'low', 'bid', 'ask']:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')
    df = add_stair_pattern_features(df)
    st.write("Colonnes après add_stair_pattern_features:", df.columns.tolist())
    st.write("Shape du DataFrame avant nettoyage:", df.shape)
    colonnes_cles = [c for c in ['close', 'high', 'low', 'open'] if c in df.columns]
    if colonnes_cles:
        st.write("Exemple de valeurs:", df[colonnes_cles].head())
        st.write("Valeurs de close:", df['close'].head(10))
        st.write("Valeurs de high:", df['high'].head(10))
        st.write("Valeurs de low:", df['low'].head(10))
        st.write("Valeurs de open:", df['open'].head(10))
        # Diagnostic NaN
        for col in colonnes_cles:
            nan_count = df[col].isna().sum()
            if nan_count > 0:
                st.warning(f"{nan_count} valeurs manquantes dans la colonne {col}")
            if (df[col].dtype == float or df[col].dtype == int) and (df[col].abs() > 1e8).sum() > 0:
                st.warning(f"Valeurs aberrantes détectées dans {col}")
        # Nettoyage : suppression des lignes avec NaN dans les colonnes critiques
        df_clean = df.dropna(subset=colonnes_cles)
        st.write(f"Shape du DataFrame après nettoyage : {df_clean.shape}")
    else:
        st.warning("Colonnes critiques manquantes pour le label: close, high, low, open")
        df_clean = df
    st.write(f"Paramètre instrument_type utilisé: 'BOOM'")
    df_clean = label_future_spike(df_clean, spike_threshold_percent=1.5, n_candles_ahead=3, instrument_type='BOOM')
    st.write("Colonnes après label_future_spike:", df_clean.columns.tolist())
    st.write("Premières lignes après label:", df_clean.head())
    if 'is_spike' in df_clean.columns:
        st.write("Distribution des labels is_spike:", df_clean['is_spike'].value_counts())
    else:
        st.error("La colonne 'is_spike' n'a pas été générée. Vérifiez la fonction label_future_spike et les colonnes d'entrée.")
    FEATURES = ['ema_8', 'ema_21', 'ema_8_slope', 'normalized_atr', 'stair_strength']
    X = df_clean[FEATURES].fillna(0)
    y = df_clean['is_spike'].fillna(0).astype(int)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=test_size, random_state=42)
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    st.info("Entraînement en cours...")
    progress_bar = st.progress(0)
    model = RandomForestClassifier(n_estimators=1, max_depth=max_depth, random_state=42, class_weight='balanced', warm_start=True)
    for i in range(1, n_estimators + 1):
        model.set_params(n_estimators=i)
        model.fit(X_train_scaled, y_train)
        if i % max(1, n_estimators // 100) == 0 or i == n_estimators:
            progress_bar.progress(i / n_estimators)
    st.success("Entraînement terminé !")
    joblib.dump(model, MODEL_PATH)
    joblib.dump(scaler, SCALER_PATH)
    joblib.dump(FEATURES, FEATURES_PATH)

    y_pred = model.predict(X_test_scaled)
    acc = accuracy_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)
    report = classification_report(y_test, y_pred)
    if not isinstance(report, str):
        report = str(report)
    cm = confusion_matrix(y_test, y_pred)

    st.write(f"**Accuracy:** {acc:.3f}")
    st.write(f"**F1-score:** {f1:.3f}")
    st.text("Classification report:\n" + str(report))
    st.text("Confusion matrix:\n" + str(cm))

    with open(REPORT_PATH, 'w', encoding='utf-8') as f:
        f.write(f"Accuracy: {acc:.3f}\n")
        f.write(f"F1-score: {f1:.3f}\n")
        f.write("Classification report:\n" + report + "\n")
        f.write("Confusion matrix:\n" + str(cm) + "\n")
    with open(REPORT_PATH, 'r', encoding='utf-8') as f:
        st.download_button("Télécharger le rapport", f.read(), file_name="rf_training_report.txt") 