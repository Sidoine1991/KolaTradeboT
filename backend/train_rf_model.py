import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
import joblib
from backend.technical_analysis import add_technical_indicators, add_stair_pattern_features
from backend.spike_detector import label_future_spike
from sklearn.metrics import accuracy_score, f1_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
from tqdm import tqdm
import time

# 1. Charger les données historiques OHLCV
DATA_PATH = 'data/february_merged.csv'  # Fichier fusionné pour l'entraînement
assert os.path.exists(DATA_PATH), f"Fichier de données introuvable: {DATA_PATH}"
df = pd.read_csv(DATA_PATH)
df.columns = [col.strip() for col in df.columns]

# Bloc de renommage pour garantir les colonnes standard
rename_map = {
    'HIGH': 'high',
    'LOW': 'low',
    'OPEN': 'open',
    'VOLUME': 'volume',
    'SYMBOL': 'symbol',
    'TIME': 'timestamp'
}
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
if 'open' not in df.columns:
    if 'BID' in df.columns:
        df['open'] = df['BID'].shift(1)
        df['open'] = df['open'].fillna(df['BID'])
    else:
        df['open'] = df['close']

# 2. Ajouter les features techniques et escalier
if hasattr(add_technical_indicators, '__call__'):
    df = add_technical_indicators(df)
df = add_stair_pattern_features(df)

# 3. Labeliser les spikes futurs
# (adapte les paramètres selon ton use-case)
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
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# 6b. Entraînement avec barre de progression
class TQDM_RF(RandomForestClassifier):
    def fit(self, X, y, sample_weight=None):
        from joblib import Parallel, delayed
        n_jobs = self.n_jobs if self.n_jobs is not None else 1
        self._validate_params()
        # tqdm sur les arbres
        with tqdm(total=self.n_estimators, desc="Entraînement RF (arbres)") as pbar:
            def _fit_estimator(est, X, y, sample_weight=None, idx=None):
                est.fit(X, y, sample_weight=sample_weight)
                pbar.update(1)
                return est
            self.estimators_ = Parallel(n_jobs=n_jobs)(
                delayed(_fit_estimator)(self._make_estimator(append=False, random_state=self.random_state), X, y, sample_weight, i)
                for i in range(self.n_estimators)
            )
        return self

start_time = time.time()
model = TQDM_RF(n_estimators=200, max_depth=6, random_state=42, class_weight='balanced', n_jobs=-1)
model.fit(X_train_scaled, y_train)
end_time = time.time()
print(f"Entraînement terminé en {end_time-start_time:.1f} secondes.")

# 7. Sauvegarder les artefacts
joblib.dump(model, 'backend/spike_rf_model.pkl')
joblib.dump(scaler, 'backend/spike_rf_model_scaler.pkl')
joblib.dump(FEATURES, 'backend/spike_rf_model_features.pkl')
print("Modèle RF, scaler et features sauvegardés dans backend/")

# 8. Évaluer et rapport
y_pred = model.predict(X_test_scaled)
acc = accuracy_score(y_test, y_pred)
f1 = f1_score(y_test, y_pred)
report = classification_report(y_test, y_pred)
cm = confusion_matrix(y_test, y_pred)

print(f"Accuracy: {acc:.3f}")
print(f"F1-score: {f1:.3f}")
print("Classification report:\n", report)
print("Confusion matrix:\n", cm)

with open('backend/spike_rf_training_report.txt', 'w', encoding='utf-8') as f:
    f.write(f"Accuracy: {acc:.3f}\n")
    f.write(f"F1-score: {f1:.3f}\n")
    f.write("Classification report:\n" + str(report) + "\n")
    f.write("Confusion matrix:\n" + str(cm) + "\n") 