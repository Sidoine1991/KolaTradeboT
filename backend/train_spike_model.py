import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier
import joblib
from backend.technical_analysis import add_technical_indicators, add_stair_pattern_features
from backend.spike_detector import label_future_spike
from sklearn.metrics import accuracy_score, f1_score, classification_report, confusion_matrix

# 1. Charger les données historiques OHLCV (adapte le chemin à tes données)
df = pd.read_csv('data/tes_donnees.csv')  # <-- À adapter
df.columns = [col.strip() for col in df.columns]  # Nettoyage des espaces

# Bloc de renommage pour garantir les colonnes standard
rename_map = {
    'HIGH': 'high',
    'LOW': 'low',
    'OPEN': 'open',
    'VOLUME': 'volume',
    'SYMBOL': 'symbol',
    'TIME': 'timestamp'
}
# Si ASK existe, utiliser la moyenne BID/ASK pour close
if 'BID' in df.columns and 'ASK' in df.columns:
    df['BID'] = pd.to_numeric(df['BID'], errors='coerce')
    df['ASK'] = pd.to_numeric(df['ASK'], errors='coerce')
    df['close'] = (df['BID'] + df['ASK']) / 2
elif 'BID' in df.columns:
    df['BID'] = pd.to_numeric(df['BID'], errors='coerce')
    df['close'] = df['BID']
df = df.rename(columns=rename_map)
for col in ['high', 'low', 'open', 'volume']:
    if col in df.columns:
        df[col] = pd.to_numeric(df[col], errors='coerce')
# Si 'open' n'existe pas, on la crée à partir de BID (ou close)
if 'open' not in df.columns:
    if 'BID' in df.columns:
        df['open'] = df['BID'].shift(1)
        df['open'] = df['open'].fillna(df['BID'])
    else:
        df['open'] = df['close']

# 2. Ajouter les features techniques et escalier
df = add_technical_indicators(df)
df = add_stair_pattern_features(df)

# 3. Labeliser les spikes futurs
df = label_future_spike(df, spike_threshold_percent=1.5, n_candles_ahead=3, instrument_type='BOOM')

# 4. Définir la liste des features à utiliser
FEATURES = [
    'ema_8', 'ema_21', 'ema_8_slope', 'normalized_atr', 'stair_strength',
    # Ajoute ici toutes les features techniques pertinentes
]

# 5. Préparer X et y
X = df[FEATURES].fillna(0)
y = df['is_spike'].fillna(0).astype(int)

# 6. Split, scaler, fit
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)
model = XGBClassifier(n_estimators=100, max_depth=3, random_state=42)
model.fit(X_scaled, y)

# 7. Sauvegarder les artefacts
joblib.dump(model, 'backend/spike_xgb_model.pkl')
joblib.dump(scaler, 'backend/spike_xgb_model_scaler.pkl')
joblib.dump(FEATURES, 'backend/spike_xgb_model_features.pkl')
print("Modèle, scaler et features sauvegardés dans backend/")

# Après l'entraînement et la prédiction sur X_test
# y_pred = model.predict(X_test)
# acc = accuracy_score(y_test, y_pred)
# f1 = f1_score(y_test, y_pred)
# report = classification_report(y_test, y_pred)
# cm = confusion_matrix(y_test, y_pred)

# print(f"Accuracy: {acc:.3f}")
# print(f"F1-score: {f1:.3f}")
# print("Classification report:\n", report)
# print("Confusion matrix:\n", cm)

# with open('backend/spike_training_report.txt', 'w', encoding='utf-8') as f:
#     f.write(f"Accuracy: {acc:.3f}\n")
#     f.write(f"F1-score: {f1:.3f}\n")
#     f.write("Classification report:\n" + report + "\n")
#     f.write("Confusion matrix:\n" + str(cm) + "\n") 