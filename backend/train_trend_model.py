import sys
import os
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
import pickle

CSV_PATH = 'data/historique.csv'
MODEL_PATH = 'backend/trend_model.pkl'
RAPPORT_PATH = 'backend/rapport_trend_model.txt'
WINDOW = 5  # 5 bougies pour M1 = 5 minutes

# 1. Charger les données
if not os.path.exists(CSV_PATH):
    raise FileNotFoundError(f"Fichier historique introuvable : {CSV_PATH}")
df = pd.read_csv(CSV_PATH, parse_dates=['timestamp'])

# 2. Feature engineering pour la tendance
features = {}
# Pour chaque fenêtre glissante de 5 bougies
for i in range(len(df) - WINDOW + 1):
    window = df.iloc[i:i+WINDOW]
    closes = window['close'].values
    opens = window['open'].values
    highs = window['high'].values
    lows = window['low'].values
    # Slope de la régression linéaire
    x = np.arange(WINDOW)
    slope = np.polyfit(x, closes, 1)[0]
    # Pourcentage de bougies haussières
    pct_up = np.mean(closes > opens)
    pct_down = np.mean(closes < opens)
    # Nombre de plus hauts consécutifs (escalier ascendant)
    highs_diff = np.diff(highs)
    steps_up = np.sum(highs_diff > 0)
    # Nombre de plus bas consécutifs (escalier descendant)
    lows_diff = np.diff(lows)
    steps_down = np.sum(lows_diff < 0)
    # Moyenne mobile courte et longue
    ma_short = np.mean(closes[-3:])
    ma_long = np.mean(closes)
    # Amplitude
    amplitude = np.max(highs) - np.min(lows)
    # RSI-like (simplifié)
    gains = np.sum(np.diff(closes) > 0)
    losses = np.sum(np.diff(closes) < 0)
    rsi_simple = 100 * gains / (gains + losses) if (gains + losses) > 0 else 50
    # Ajout des features
    features[i] = {
        'slope': slope,
        'pct_up': pct_up,
        'pct_down': pct_down,
        'steps_up': steps_up,
        'steps_down': steps_down,
        'ma_short': ma_short,
        'ma_long': ma_long,
        'amplitude': amplitude,
        'rsi_simple': rsi_simple,
        'close_last': closes[-1],
        'close_first': closes[0],
    }

features_df = pd.DataFrame.from_dict(features, orient='index')
features_df.index = df.index[:len(features_df)]

# 3. Générer la cible : tendance sur la fenêtre
# Si le dernier close > premier close + seuil => haussier, < -seuil => baissier, sinon neutre
THRESH = 0.001  # 0.1% du prix pour éviter le bruit
trend = []
for i in range(len(df) - WINDOW + 1):
    closes = df['close'].iloc[i:i+WINDOW].values
    delta = (closes[-1] - closes[0]) / closes[0]
    if delta > THRESH:
        trend.append(1)
    elif delta < -THRESH:
        trend.append(-1)
    else:
        trend.append(0)
features_df['trend'] = trend

print("Aperçu features + cible :")
print(features_df.head(10))
print("Distribution cible :", features_df['trend'].value_counts().to_dict())

# 4. Nettoyer
X = features_df.drop(columns=['trend'])
y = features_df['trend']

# 5. Split train/test
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

# 6. Entraîner le modèle
clf = RandomForestClassifier(n_estimators=100, random_state=42, class_weight='balanced')
clf.fit(X_train, y_train)

# 7. Évaluer
y_pred = clf.predict(X_test)
rapport = classification_report(y_test, y_pred)
mat_conf = confusion_matrix(y_test, y_pred)
print("Rapport de classification :\n", rapport)
print("Matrice de confusion :\n", mat_conf)

# Importance des features
importances = clf.feature_importances_
importances_str = "\n".join([f"{feat}: {imp:.4f}" for feat, imp in zip(X.columns, importances)])
print("Importance des features :\n", importances_str)

# 8. Sauvegarder le modèle
with open(MODEL_PATH, 'wb') as f:
    pickle.dump(clf, f)
print(f"Modèle sauvegardé dans {MODEL_PATH}")

# 9. Sauvegarder le rapport
with open(RAPPORT_PATH, 'w') as f:
    f.write("Rapport de classification :\n" + rapport + "\n")
    f.write("Matrice de confusion :\n" + np.array2string(mat_conf) + "\n")
    f.write("Importance des features :\n" + importances_str + "\n")
print(f"Rapport sauvegardé dans {RAPPORT_PATH}") 