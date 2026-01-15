import pandas as pd
import joblib
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import TimeSeriesSplit
import xgboost as xgb
from backend.technical_analysis import add_stair_pattern_features
from backend.spike_detector import label_future_spike

# --- PARAMÈTRES À ADAPTER ---
DATA_PATH = 'data/historical_data.csv'  # À adapter
MODEL_PATH = 'backend/boom1000_xgb_model.pkl'
SCALER_PATH = 'backend/boom1000_xgb_model_scaler.pkl'
FEATURES_PATH = 'backend/boom1000_xgb_model_features.pkl'
SPIKE_THRESHOLD_PERCENT = 0.5
N_CANDLES_AHEAD = 5
INSTRUMENT_TYPE = 'BOOM'
N_SPLITS = 5

# --- PIPELINE ---
print('Chargement des données...')
df = pd.read_csv(DATA_PATH)

print('Calcul des features techniques...')
df = add_stair_pattern_features(df)

print('Labeling des spikes...')
df = label_future_spike(df, SPIKE_THRESHOLD_PERCENT, N_CANDLES_AHEAD, INSTRUMENT_TYPE)

print('Nettoyage des NaN...')
df = df.dropna()

# Sélection des features (exclure OHLC, timestamp, is_spike)
exclude_cols = ['timestamp', 'open', 'high', 'low', 'close', 'volume', 'is_spike']
feature_cols = [col for col in df.columns if col not in exclude_cols]
X = df[feature_cols]
y = df['is_spike']

print('Split temporel...')
tscv = TimeSeriesSplit(n_splits=N_SPLITS)
for train_idx, test_idx in tscv.split(X):
    X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
    y_train, y_test = y.iloc[train_idx], y.iloc[test_idx]

print('Entraînement du scaler...')
scaler = StandardScaler().fit(X_train)
X_train_scaled = scaler.transform(X_train)
X_test_scaled = scaler.transform(X_test)

print('Gestion du déséquilibre...')
scale_pos_weight = (y_train == 0).sum() / max((y_train == 1).sum(), 1)

print('Entraînement du modèle XGBoost...')
model = xgb.XGBClassifier(
    objective='binary:logistic',
    eval_metric='logloss',
    scale_pos_weight=scale_pos_weight,
    use_label_encoder=False
)
model.fit(X_train_scaled, y_train)

print('Évaluation...')
y_pred = model.predict(X_test_scaled)
from sklearn.metrics import classification_report
print(classification_report(y_test, y_pred))

print('Sauvegarde du modèle, scaler et features...')
joblib.dump(model, MODEL_PATH)
joblib.dump(scaler, SCALER_PATH)
joblib.dump(feature_cols, FEATURES_PATH)
print('Terminé.') 