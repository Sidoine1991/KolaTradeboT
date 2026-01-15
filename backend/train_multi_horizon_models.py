import pandas as pd
import numpy as np
import xgboost as xgb
import joblib

# === PARAMÈTRES ===
DATA_PATH = 'data/ohlc_sample.csv'  # À adapter à ta source réelle
HORIZONS = {
    '4h': 4,      # 4 heures
    '1d': 24,     # 1 jour
    '1w': 24*7    # 1 semaine
}

# === CHARGEMENT DES DONNÉES ===
df = pd.read_csv(DATA_PATH, parse_dates=['timestamp'])

# === FONCTION DE FEATURE ENGINEERING SIMPLE ===
def make_features(df):
    feats = pd.DataFrame(index=df.index)
    feats['return_1'] = df['close'].pct_change(1)
    feats['return_3'] = df['close'].pct_change(3)
    feats['ma_5'] = df['close'].rolling(5).mean()
    feats['ma_10'] = df['close'].rolling(10).mean()
    feats['vol_5'] = df['close'].rolling(5).std()
    feats['vol_10'] = df['close'].rolling(10).std()
    feats = feats.dropna()
    return feats

# === ENTRAÎNEMENT PAR HORIZON ===
for label, horizon in HORIZONS.items():
    print(f'--- Entraînement pour horizon {label} ---')
    # Target : hausse à horizon
    df[f'target_{label}'] = (df['close'].shift(-horizon) > df['close']).astype(int)
    feats = make_features(df)
    # Alignement X/y
    y = df.loc[feats.index, f'target_{label}']
    X = feats.values
    # Split simple (train/test)
    split = int(0.8 * len(X))
    X_train, X_test = X[:split], X[split:]
    y_train, y_test = y[:split], y[split:]
    # Modèle XGBoost
    model = xgb.XGBClassifier(n_estimators=100, max_depth=3, random_state=42)
    model.fit(X_train, y_train)
    acc = model.score(X_test, y_test)
    print(f'Précision test {label} : {acc:.2%}')
    # Sauvegarde
    joblib.dump(model, f'backend/xgb_model_{label}.pkl')
    print(f'Modèle sauvegardé : backend/xgb_model_{label}.pkl') 