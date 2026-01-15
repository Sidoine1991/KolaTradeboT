import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import os
import pickle
import logging # Ajout pour une meilleure gestion des logs
from typing import Optional

# Assurez-vous que backend.features est correctement accessible et contient la fonction compute_features
from backend.features import compute_features # L'import est déjà là, c'est bien.

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# --- INITIALISATION DU MODÈLE ML ---
ML_MODEL_PATH = os.path.join(os.path.dirname(__file__), 'spike_rf_model.pkl')
ml_model = None
ML_FEATURES = None # Sera défini dynamiquement lors du chargement ou de l'entraînement


def load_ml_model():
    """Charge le modèle ML depuis le chemin défini."""
    global ml_model, ML_FEATURES
    if os.path.exists(ML_MODEL_PATH):
        try:
            with open(ML_MODEL_PATH, 'rb') as f:
                model_data = pickle.load(f)
                ml_model = model_data.get('model')
                # Assurez-vous que les features du modèle sont stockées avec lui lors du save
                ML_FEATURES = model_data.get('features')
            if ml_model and ML_FEATURES:
                logging.info(f"[ML] Modèle chargé depuis {ML_MODEL_PATH}.")
            else:
                logging.warning(f"[ML] Modèle ou variables explicatives manquantes dans le fichier {ML_MODEL_PATH}.")
                ml_model = None # Réinitialise si le contenu est invalide
                ML_FEATURES = None
        except Exception as e:
            logging.error(f"[ML] Erreur lors du chargement du modèle depuis {ML_MODEL_PATH} : {e}")
            ml_model = None
            ML_FEATURES = None
    else:
        logging.warning(f"[ML] Modèle non trouvé à {ML_MODEL_PATH}. La prédiction ML sera désactivée.")

# Charger le modèle au démarrage de l'application
load_ml_model()


# --- PRÉDICTION ML EN TEMPS RÉEL (POUR CHAQUE NOUVEAU TICK) ---
def predict_spike_ml(df_ohlcv: pd.DataFrame) -> float | None:
    """
    Retourne la probabilité ML d'un spike imminent (dans les 2 ticks) pour le dernier tick du DataFrame.
    Prend un DataFrame OHLCV complet pour calculer les variables explicatives.
    """
    if ml_model is None or ML_FEATURES is None:
        logging.debug("[ML] Modèle ou variables ML non chargés. Impossible de prédire.")
        return None
    
    # Ultimate robust min_len calculation
    try:
        suffixes = []
        for f in ML_FEATURES:
            f_str = str(f)
            if not isinstance(f, str):
                logging.debug(f"[ML] Feature non-str détectée: {f} (type: {type(f)})")
            suf = f_str.split('_')[-1]
            if f_str.endswith(('14', '20', '30')):
                try:
                    suffixes.append(int(suf))
                except Exception as e:
                    logging.debug(f"[ML] Suffixe non convertible en int: {suf} pour feature {f_str} ({e})")
        logging.debug(f"[ML] Suffixes numériques extraits pour min_len: {suffixes} (types: {[type(x) for x in suffixes]})")
        # Ensure all elements are int, and max is called only on ints
        suffixes = [x for x in suffixes if isinstance(x, int)]
        min_len = max([20] + suffixes) if suffixes else 20
    except Exception as e:
        logging.error(f"[ML] Erreur lors du calcul de min_len pour les features: {e}")
        min_len = 20
    if len(df_ohlcv) < min_len:
        logging.debug(f"[ML] Pas assez de données ({len(df_ohlcv)} ticks) pour calculer les variables ML.")
        return None

    # Calcule toutes les variables nécessaires à partir du DataFrame OHLCV complet
    df_feat = compute_features(df_ohlcv)
    
    # Squeeze pour obtenir la dernière ligne comme une Series pour la prédiction
    last_row_features = df_feat.iloc[-1]

    # Vérifiez que toutes les variables d'entraînement sont présentes dans les variables calculées
    missing_features = [f for f in ML_FEATURES if f not in last_row_features.index]
    if missing_features:
        logging.error(f"[ML] Variables attendues manquantes pour la prédiction : {missing_features}")
        return {}

    # Préparer l'entrée pour le modèle : reshape en (1, n_features) et s'assurer de l'ordre
    X = last_row_features[ML_FEATURES].values.reshape(1, -1)
    
    try:
        proba = ml_model.predict_proba(X)[0][1]  # proba classe 1 (spike imminent)
        return float(proba)
    except Exception as e:
        logging.error(f"[ML] Erreur de prédiction : {e}. Entrée X : {X}, variables attendues : {ML_FEATURES}", exc_info=True)
        return {}

def batch_predict_spike_ml(df: pd.DataFrame) -> pd.Series:
    """
    Applique predict_spike_ml à chaque fenêtre du DataFrame et retourne une Series de probabilités.
    La prédiction est faite pour chaque ligne, en utilisant toutes les données jusqu'à cette ligne.
    """
    results = []
    for i in range(len(df)):
        sub_df = df.iloc[:i+1]
        proba = predict_spike_ml(sub_df)
        results.append(proba if proba is not None else float('nan'))
    return pd.Series(results, index=df.index)

# --- DÉTECTEURS DE SPIKES TRADITIONNELS (PEUVENT SERVIR DE CONFORMATEURS OU DE FALLBACK) ---
def detect_spikes(df: pd.DataFrame, threshold: float = 0.5, window: int = 5, method: str = 'percentage') -> pd.DataFrame:
    """
    Détecte les spikes (Boom/Crash) dans une série de prix.
    
    Args :
        df : DataFrame avec colonnes 'close', 'high', 'low', 'volume'. Assurez-vous d'avoir 'timestamp'.
        threshold : seuil de détection (en % pour method='percentage', en écart-type pour method='std')
        window : fenêtre de calcul pour les moyennes mobiles
        method : méthode de détection ('percentage', 'std', 'volume_spike')
    
    Returns :
        DataFrame avec les spikes détectés (peut être vide) avec 'timestamp', 'spike_type', 'intensity', 'confidence'.
    """
    process_df = df.copy() # On travaille sur une copie du DataFrame

    # Pré-calculer les stats communes qui pourraient être utiles pour la confiance
    # ou pour d'autres méthodes de détection.
    process_df['pct_change'] = process_df['close'].pct_change() * 100
    process_df['price_ma'] = process_df['close'].rolling(window=window).mean()
    process_df['price_std'] = process_df['close'].rolling(window=window).std()
    
    # Calculs pour le volume s'il existe
    if 'volume' in process_df.columns:
        process_df['volume_ma'] = process_df['volume'].rolling(window=window).mean()
        # Éviter la division par zéro si volume_ma est 0
        process_df['volume_ratio'] = process_df['volume'] / process_df['volume_ma'].replace(0, np.nan)
        
    spikes_df = pd.DataFrame() # Initialisez un DataFrame vide pour les résultats
    
    if method == 'percentage':
        spikes_df = detect_percentage_spikes(process_df, threshold, window)
    elif method == 'std':
        spikes_df = detect_std_spikes(process_df, threshold, window)
    elif method == 'volume_spike':
        spikes_df = detect_volume_spikes(process_df, threshold, window)
    else:
        logging.error(f"Méthode '{method}' non reconnue pour la détection de spikes.")
        return pd.DataFrame() # Retourne un DataFrame vide en cas de méthode non reconnue

    # La colonne 'timestamp' est cruciale pour le suivi et l'analyse ultérieure
    if not spikes_df.empty and 'timestamp' not in spikes_df.columns:
      spikes_df['timestamp'] = spikes_df.index # Assurez-vous que le timestamp est une colonne si l'index est la date

    return spikes_df


def detect_percentage_spikes(df: pd.DataFrame, threshold: float = 0.5, window: int = 5) -> pd.DataFrame:
    """Détection basée sur le pourcentage de variation."""
    df_prepared = df.copy()
    
    df_prepared['pct_ma'] = df_prepared['pct_change'].rolling(window=window).mean()
    df_prepared['pct_std'] = df_prepared['pct_change'].rolling(window=window).std()
    
    mask = (df_prepared['pct_change'].abs() > threshold) & \
           (df_prepared['pct_change'].abs() > df_prepared['pct_ma'].abs() + 0.5 * df_prepared['pct_std'])
    spikes = df_prepared[mask].copy()
    if isinstance(spikes, pd.Series):
        spikes = spikes.to_frame().T
    if not spikes.empty:
        spikes['spike_type'] = spikes['pct_change'].apply(lambda x: 'BOOM' if x > 0 else 'CRASH')
        spikes['intensity'] = spikes['pct_change'].abs()
        spikes['confidence'] = calculate_spike_confidence(spikes.index, df_prepared)
    return spikes


def detect_std_spikes(df: pd.DataFrame, threshold: float = 2.0, window: int = 20) -> pd.DataFrame:
    """Détection basée sur l'écart-type (Z-score)."""
    df_prepared = df.copy()
    df_prepared['z_score'] = (df_prepared['close'] - df_prepared['price_ma']) / df_prepared['price_std'].replace(0, np.nan)
    mask = df_prepared['z_score'].abs() > threshold
    spikes = df_prepared[mask].copy()
    if isinstance(spikes, pd.Series):
        spikes = spikes.to_frame().T
    if not spikes.empty:
        spikes['spike_type'] = spikes['z_score'].apply(lambda x: 'BOOM' if x > 0 else 'CRASH')
        spikes['intensity'] = spikes['z_score'].abs()
        spikes['confidence'] = calculate_spike_confidence(spikes.index, df_prepared)
    return spikes


def detect_volume_spikes(df: pd.DataFrame, threshold: float = 2.0, window: int = 10) -> pd.DataFrame:
    """Détection basée sur les pics de volume et la variation de prix associée."""
    df_prepared = df.copy()
    if 'volume_ratio' not in df_prepared.columns:
        return pd.DataFrame()
    volume_spikes = df_prepared[df_prepared['volume_ratio'] > threshold].copy()
    if isinstance(volume_spikes, pd.Series):
        volume_spikes = volume_spikes.to_frame().T
    if volume_spikes.empty:
        return pd.DataFrame()
    price_change_mask = volume_spikes['pct_change'].abs() > 0.005
    spikes = volume_spikes[price_change_mask].copy()
    if isinstance(spikes, pd.Series):
        spikes = spikes.to_frame().T
    if not spikes.empty:
        spikes['spike_type'] = spikes['pct_change'].apply(lambda x: 'BOOM' if x > 0 else 'CRASH')
        spikes['intensity'] = spikes['pct_change'].abs()
        spikes['confidence'] = calculate_spike_confidence(spikes.index, df_prepared)
    return spikes


def calculate_spike_confidence(spike_indices: pd.Index, df_full: pd.DataFrame, avg_vol_window: int = 20) -> list[float]:
    """
    Calcule la confiance d'un spike basée sur plusieurs facteurs pour les indices donnés.
    Prend les indices des spikes et le DataFrame complet (avec toutes les statistiques pré-calculées).
    """
    confidences = []
    
    # Assurez-vous que les colonnes nécessaires pour calculate_spike_confidence existent
    required_cols = ['pct_change', 'volume', 'volume_ma', 'pct_std']
    for col in required_cols:
        if col not in df_full.columns:
            logging.debug(f"Colonne '{col}' manquante dans df_full pour calculate_spike_confidence.")
            # Calculez-la à la volée si absente, ou attribuez une valeur par défaut
            if col == 'pct_change': df_full['pct_change'] = df_full['close'].pct_change() * 100
            if col == 'volume_ma' and 'volume' in df_full.columns: df_full['volume_ma'] = df_full['volume'].rolling(window=avg_vol_window).mean()
            if col == 'pct_std' and 'pct_change' in df_full.columns: df_full['pct_std'] = df_full['pct_change'].rolling(window=avg_vol_window).std()

    for idx in spike_indices:
        confidence = 0
        
        # Récupérer la ligne complète pour l'index du spike
        spike_data = df_full.loc[idx]
        
        # Facteur 1: Intensité du spike (basée sur pct_change)
        # Normalisation de l'intensité sur une échelle de 0-100 (ex: 5% de change = 100% score d'intensité sur 40 points)
        # Adapter la base de normalisation (5.0 ici) à ce qui est un "gros" spike pour vos indices.
        intensity_score = min(spike_data.get('pct_change', 0) / 0.5, 1.0) * 40 # 0.5% change = 100% score intensité
        if intensity_score < 0: intensity_score = 0 # S'assurer que le score n'est pas négatif si pct_change est négatif pour une raison x
        confidence += intensity_score
        
        # Facteur 2: Volume relatif
        # Si le volume du spike est significativement plus élevé que la moyenne récente
        current_volume = spike_data.get('volume', 0)
        avg_volume = spike_data.get('volume_ma', np.nan)
        if not np.isnan(avg_volume) and avg_volume > 0:
            volume_ratio = current_volume / avg_volume
            volume_score = min(volume_ratio / 3.0, 1.0) * 30 # Volume 3x moyen = 100% score sur 30 points
            confidence += volume_score
        
        # Facteur 3: Contexte de marché (volatilité avant le spike)
        # Un marché plus calme juste avant le spike peut indiquer une accumulation.
        # pct_std (standard deviation of percentage change) représente la volatilité.
        # Plus pct_std est faible, plus le marché est calme.
        volatility = spike_data.get('pct_std', np.nan)
        if not np.isnan(volatility):
            # Assumer qu'une volatilité normale pour Boom/Crash est autour de X%.
            # Si la volatilité est faible (ex: < 0.1%), score plus élevé.
            # Adaptez cette logique et les seuils à l'historique de vos indices.
            max_calm_vol = 0.1 # Volatilité max considérée "calme" (à ajuster)
            volatility_score = max(0, (1 - min(volatility / max_calm_vol, 1.0))) * 30
            confidence += volatility_score
        
        confidences.append(min(confidence, 100)) # Clamper la confiance à 100
    
    return confidences

# --- ANALYSE DE PATTERNS HISTORIQUES / PRÉDICTIF STATISTIQUE ---
# Ces fonctions sont utiles pour le contexte et l'analyse, moins pour le déclenchement ultra-rapide.
# Assurez-vous que df contient une colonne 'timestamp' pour ces analyses.

def analyze_spike_pattern(spikes_df: pd.DataFrame, df_full: Optional[pd.DataFrame] = None) -> dict:
    """
    Analyse les patterns de spikes (nécessite df avec 'timestamp' et 'spike_type').
    df_full est ignoré pour compatibilité, mais peut être utilisé pour des analyses avancées.
    """
    if len(spikes_df) < 2 or 'timestamp' not in spikes_df.columns or 'spike_type' not in spikes_df.columns:
        return {}
    
    analysis = {
        'total_spikes': len(spikes_df),
        'boom_count': len(spikes_df[spikes_df['spike_type'] == 'BOOM']),
        'crash_count': len(spikes_df[spikes_df['spike_type'] == 'CRASH']),
        'avg_intensity': spikes_df['intensity'].mean() if 'intensity' in spikes_df.columns else 0,
        'avg_confidence': spikes_df['confidence'].mean() if 'confidence' in spikes_df.columns else 0,
        'time_between_spikes_minutes': None,
        'pattern_detected': None
    }
    
    # Calcul du temps moyen entre spikes
    if len(spikes_df) > 1:
        spikes_df_sorted = spikes_df.sort_values(by='timestamp')
        time_diffs = (spikes_df_sorted['timestamp'].diff().dt.total_seconds() / 60).dropna()
        if not time_diffs.empty:
            analysis['time_between_spikes_minutes'] = time_diffs.mean()
    
    # Détection de patterns simples (ex: séquences)
    if len(spikes_df) >= 3:
        recent_spikes = spikes_df.tail(3)
        if all(recent_spikes['spike_type'] == 'BOOM'):
            analysis['pattern_detected'] = 'BOOM_SEQUENCE'
        elif all(recent_spikes['spike_type'] == 'CRASH'):
            analysis['pattern_detected'] = 'CRASH_SEQUENCE'
        elif recent_spikes['spike_type'].iloc[0] != recent_spikes['spike_type'].iloc[-1]:
            analysis['pattern_detected'] = 'ALTERNATING'
    
    return analysis


def predict_next_spike(spikes_df: pd.DataFrame, df_full: pd.DataFrame, lookback_hours: int = 24) -> dict:
    """
    Prédit la probabilité du prochain spike avec analyse du contexte historique.
    Nécessite spikes_df avec 'timestamp', 'spike_type', 'confidence'.
    Nécessite df_full avec 'timestamp', 'close'.
    """
    if len(spikes_df) < 2 or 'timestamp' not in spikes_df.columns:
        return {'probability': 0, 'expected_time': None, 'type': 'UNKNOWN', 'confidence': 0, 'context': {}}

    recent_spikes = spikes_df[spikes_df['timestamp'] > datetime.now() - timedelta(hours=lookback_hours)].copy()
    if len(recent_spikes) == 0:
        return {'probability': 0, 'expected_time': None, 'type': 'UNKNOWN', 'confidence': 0, 'context': {}}

    # Calculer la probabilité basée sur la fréquence
    time_window_minutes = lookback_hours * 60
    # Ajoutez 1 pour éviter la division par zéro si time_window_minutes est petit
    spike_frequency_per_min = len(recent_spikes) / (time_window_minutes if time_window_minutes > 0 else 1) 
    probability = min(spike_frequency_per_min * 60 / 2, 0.8) # Probabilité par heure divisée par 2, max 80%

    # Prédire le type basé sur l'historique récent
    boom_ratio = len(recent_spikes[recent_spikes['spike_type'] == 'BOOM']) / len(recent_spikes)
    predicted_type = 'BOOM' if boom_ratio > 0.6 else 'CRASH' if boom_ratio < 0.4 else 'UNKNOWN'

    # Temps attendu basé sur la fréquence moyenne
    expected_minutes = 1 / (spike_frequency_per_min if spike_frequency_per_min > 0 else 0.001) # Avoid div by zero
    expected_time = datetime.now() + timedelta(minutes=expected_minutes)
    # Correction : s'assurer que le temps attendu est toujours dans le futur (au moins +1 min)
    min_expected_time = datetime.now() + timedelta(minutes=1)
    if expected_time < min_expected_time:
        expected_time = min_expected_time

    # Analyse du contexte historique
    context = {}
    ts_series = recent_spikes['timestamp']
    if not isinstance(ts_series, pd.Series):
        ts_series = pd.Series(ts_series)
    last_spike_time = ts_series.iloc[-1]
    time_since_last_spike = (datetime.now() - last_spike_time).total_seconds() / 60
    context['minutes_since_last_spike'] = time_since_last_spike

    # Volatilité récente
    if len(df_full) >= 20: # Assurez-vous que df_full a assez de data
        recent_volatility = df_full['close'].iloc[-20:].std()
    else:
        recent_volatility = df_full['close'].std() if not df_full.empty else 0
    context['recent_volatility'] = recent_volatility

    # Score de contexte favorable: ex. faible volatilité avant un spike, ou longue période sans spike
    favorable = False
    if recent_volatility < (df_full['close'].std() if not df_full.empty else 0) * 0.7 and time_since_last_spike > expected_minutes * 0.8:
        favorable = True
    context['favorable_context'] = favorable

    return {
        'probability': probability,
        'expected_time': expected_time,
        'type': predicted_type,
        'confidence': recent_spikes['confidence'].mean() if 'confidence' in recent_spikes.columns else 0,
        'context': context
    }

# --- ENTRAÎNEMENT ET RAFFINEMENT DU MODÈLE ML ---

def fine_tune_spike_model(df_recent: pd.DataFrame, spike_pct_threshold: float = 0.015) -> dict:
    """
    Raffine le modèle de spike sur les données récentes (df_recent).
    spike_pct_threshold: Seuil en pourcentage pour définir un "spike" pour l'entraînement (ex: 1.5%).
    Ceci est la définition du label 'spike_avenir'.
    """
    global ml_model, ML_FEATURES
    
    # Vérifiez les dépendances ici (import imb_learn, sklearn) pour éviter les erreurs si elles manquent
    try:
        from sklearn.ensemble import RandomForestClassifier
        from imblearn.over_sampling import RandomOverSampler
    except ImportError as e:
        return {"success": False, "error": f"Dépendance manquante pour le raffinage du modèle: {e}. Installez scikit-learn et imbalanced-learn."}

    # S'assurer que le DataFrame est correctement formaté pour l'entraînement
    if not all(col in df_recent.columns for col in ['timestamp', 'open', 'high', 'low', 'close', 'volume']):
        return {"success": False, "error": "DataFrame d'entrée incomplet pour le raffinage. Colonnes requises: timestamp, open, high, low, close, volume."}

    try:
        # 1. Calculer les features pour toutes les données récentes
        features_df = compute_features(df_recent.copy()) # Assurez-vous que compute_features gère bien les NaN/inf
        
        # 2. Générer la cible 'spike_avenir'
        # Un spike est défini ici comme un changement de prix abs > spike_pct_threshold
        # Le label est décalé pour prédire un spike FUTUR (ex: dans les 2 ticks)
        df_recent_copy = df_recent.copy()
        df_recent_copy['true_spike'] = (df_recent_copy['close'].pct_change().abs() > spike_pct_threshold).astype(int)
        df_recent_copy['spike_avenir'] = df_recent_copy['true_spike'].shift(-2).fillna(0).astype(int)

        # Joindre les features avec la cible
        # Utilisez l'index 'timestamp' pour joindre si compute_features renvoie 'timestamp' comme index
        # Sinon, assurez-vous que les DataFrames sont alignés
        df_ml = features_df.join(df_recent_copy[['spike_avenir']], how='inner')
        # Supprimer les NaNs créés par les calculs de features et le shift pour la cible
        df_ml = df_ml.dropna()

        # Extraire X (features) et y (cible)
        X = df_ml.drop('spike_avenir', axis=1)
        y = df_ml['spike_avenir']
        
        # Vérification des dimensions et des classes
        if X.empty or y.empty:
            return {"success": False, "error": "Aucune donnée nettoyée pour l'entraînement après le calcul des features et le drop de NaN."}

        unique_classes = np.unique(y)
        if len(unique_classes) < 2:
            return {"success": False, "error": f"La cible n'a qu'une seule classe (valeurs: {unique_classes.tolist()}) sur {len(y)} exemples. Ajoutez plus de données ou élargissez la fenêtre de détection pour l'entraînement."}
        
        # S'assurer que ML_FEATURES conserve l'ordre des colonnes
        ML_FEATURES = X.columns.tolist()

        # 3. Oversampling pour gérer le déséquilibre des classes (les spikes sont rares)
        logging.info(f"[ML] Balance des classes avant oversampling: {y.value_counts()}")
        ros = RandomOverSampler(random_state=42)
        X_res, y_res = ros.fit_resample(X, y)[:2]
        logging.info(f"[ML] Balance des classes après oversampling: {y_res.value_counts()}")

        # 4. Entraîner le modèle RandomForest
        # Ajouter class_weight='balanced' pour bien gérer les classes déséquilibrées même sans oversampling extrême
        clf = RandomForestClassifier(n_estimators=100, random_state=42, class_weight='balanced', n_jobs=-1) # n_jobs=-1 utilise tous les coeurs disponibles
        clf.fit(X_res, y_res)
        
        # 5. Sauvegarder le modèle et les features avec lui pour la cohérence
        with open(ML_MODEL_PATH, 'wb') as f:
            pickle.dump({'model': clf, 'features': ML_FEATURES}, f)
        
        ml_model = clf # Mettre à jour le modèle global
        logging.info(f"[ML] Modèle affiné et sauvegardé avec {len(X_res)} exemples.")
        return {"success": True, "message": f"Modèle affiné avec succès sur {len(X_res)} exemples."}

    except Exception as e:
        logging.error(f"[ML] Erreur lors du raffinage du modèle: {e}", exc_info=True)
        return {"success": False, "error": str(e)}

def fine_tune_spike_model_from_csv(csv_path: str) -> dict:
    """
    Raffine le modèle à partir d'un fichier CSV.
    Le CSV doit contenir 'timestamp', 'open', 'high', 'low', 'close', 'volume'.
    """
    try:
        logging.info(f"[ML] Chargement des données CSV depuis {csv_path} pour le raffinage.")
        df = pd.read_csv(csv_path, parse_dates=['timestamp'])
        df = df.sort_values('timestamp') # Assurez-vous que les données sont triées chronologiquement
        logging.info(f"[ML] {len(df)} lignes chargées depuis le CSV.")
        return fine_tune_spike_model(df)
    except FileNotFoundError:
        logging.error(f"[ML] Fichier CSV non trouvé: {csv_path}")
        return {"success": False, "error": f"Fichier CSV non trouvé: {csv_path}"}
    except Exception as e:
        logging.error(f"[ML] Erreur lors du chargement ou du raffinage depuis CSV: {e}", exc_info=True)
        return {"success": False, "error": str(e)}

def label_future_spike(df: pd.DataFrame, spike_threshold_percent: float, n_candles_ahead: int, instrument_type: str = "BOOM") -> pd.DataFrame:
    """
    Ajoute une colonne 'is_spike' au DataFrame, indiquant si un spike (hausse pour BOOM, baisse pour CRASH) survient dans les n prochaines bougies.
    """
    df_labeled = df.copy()
    df_labeled['is_spike'] = 0
    for i in range(len(df_labeled) - 1 - n_candles_ahead, -1, -1):
        current_close = df_labeled.loc[df_labeled.index[i], 'close']
        future_high = df_labeled.loc[df_labeled.index[i+1 : i+1+n_candles_ahead], 'high'].max()
        future_low = df_labeled.loc[df_labeled.index[i+1 : i+1+n_candles_ahead], 'low'].min()
        if instrument_type.upper() == "BOOM":
            if future_high and current_close > 0 and (future_high - current_close) / current_close * 100 >= spike_threshold_percent:
                df_labeled.loc[df_labeled.index[i], 'is_spike'] = 1
        elif instrument_type.upper() == "CRASH":
            if future_low and current_close > 0 and (current_close - future_low) / current_close * 100 >= spike_threshold_percent:
                df_labeled.loc[df_labeled.index[i], 'is_spike'] = 1
    return df_labeled.dropna()

# --- DÉTECTION DE SPIKE EN TEMPS RÉEL AVEC PRIX ACTUELS MT5 ---
def detect_spike_realtime(symbol: str, current_price: float, historical_df: pd.DataFrame, 
                         threshold: float = 0.5, window: int = 5) -> dict:
    """
    Détecte les spikes en temps réel en utilisant le prix actuel de MT5.
    
    Args:
        symbol: Symbole du trading
        current_price: Prix actuel récupéré de MT5
        historical_df: DataFrame historique pour calculer les moyennes et statistiques
        threshold: Seuil de détection en pourcentage
        window: Fenêtre de calcul pour les moyennes mobiles
    
    Returns:
        dict: Informations sur le spike détecté ou None
    """
    if historical_df.empty or len(historical_df) < window:
        return None
    
    try:
        # Calculer les statistiques basées sur les données historiques
        recent_prices = historical_df['close'].tail(window)
        price_ma = recent_prices.mean()
        price_std = recent_prices.std()
        
        # Calculer la variation en pourcentage avec le prix actuel
        price_change_pct = ((current_price - price_ma) / price_ma) * 100
        
        # Détecter si c'est un spike
        is_spike = abs(price_change_pct) > threshold
        
        if is_spike:
            # Calculer la confiance basée sur l'écart par rapport à la moyenne
            z_score = abs(price_change_pct) / (price_std / price_ma * 100) if price_std > 0 else 0
            
            spike_info = {
                'symbol': symbol,
                'current_price': current_price,
                'price_change_pct': price_change_pct,
                'spike_type': 'BOOM' if price_change_pct > 0 else 'CRASH',
                'intensity': abs(price_change_pct),
                'confidence': min(z_score / 3.0, 1.0),  # Normaliser la confiance
                'timestamp': datetime.now(),
                'price_ma': price_ma,
                'price_std': price_std,
                'threshold': threshold
            }
            
            logging.info(f"[REALTIME] Spike détecté pour {symbol}: {spike_info['spike_type']} "
                        f"({price_change_pct:.2f}%) - Confiance: {spike_info['confidence']:.2f}")
            
            return spike_info
        else:
            return None
            
    except Exception as e:
        logging.error(f"[REALTIME] Erreur lors de la détection de spike en temps réel: {e}")
        return None

def predict_spike_realtime_ml(symbol: str, current_price: float, historical_df: pd.DataFrame) -> dict:
    """
    Prédit les spikes en temps réel en utilisant le modèle ML et le prix actuel de MT5.
    
    Args:
        symbol: Symbole du trading
        current_price: Prix actuel récupéré de MT5
        historical_df: DataFrame historique pour calculer les features
    
    Returns:
        dict: Prédiction ML avec probabilité de spike
    """
    if ml_model is None or ML_FEATURES is None:
        return None
    
    try:
        # Créer un DataFrame temporaire avec le prix actuel
        temp_df = historical_df.copy()
        
        # Ajouter le prix actuel comme nouvelle ligne
        current_row = temp_df.iloc[-1].copy()
        current_row['close'] = current_price
        current_row['high'] = max(current_price, temp_df['high'].iloc[-1])
        current_row['low'] = min(current_price, temp_df['low'].iloc[-1])
        current_row['timestamp'] = datetime.now()
        
        # Ajouter la nouvelle ligne au DataFrame
        temp_df = pd.concat([temp_df, pd.DataFrame([current_row])], ignore_index=True)
        
        # Calculer les features avec le prix actuel
        features = compute_features(temp_df)
        
        if len(features) == 0:
            return None
        
        # Prendre la dernière ligne (avec le prix actuel)
        last_features = features.iloc[-1]
        
        # Vérifier que toutes les features nécessaires sont présentes
        missing_features = [f for f in ML_FEATURES if f not in last_features.index]
        if missing_features:
            logging.error(f"[REALTIME ML] Features manquantes: {missing_features}")
            return None
        
        # Préparer les données pour la prédiction
        X = last_features[ML_FEATURES].values.reshape(1, -1)
        
        # Faire la prédiction
        proba = ml_model.predict_proba(X)[0][1]  # Probabilité de spike
        
        prediction_info = {
            'symbol': symbol,
            'current_price': current_price,
            'spike_probability': float(proba),
            'prediction': 'SPIKE_LIKELY' if proba > 0.7 else 'SPIKE_POSSIBLE' if proba > 0.5 else 'NO_SPIKE',
            'confidence': proba,
            'timestamp': datetime.now()
        }
        
        logging.info(f"[REALTIME ML] Prédiction pour {symbol}: {prediction_info['prediction']} "
                    f"(prob: {proba:.3f})")
        
        return prediction_info
        
    except Exception as e:
        logging.error(f"[REALTIME ML] Erreur lors de la prédiction ML en temps réel: {e}")
        return None

def get_realtime_spike_analysis(symbol: str, historical_df: pd.DataFrame, 
                               threshold: float = 0.5, window: int = 5) -> dict:
    """
    Analyse complète des spikes en temps réel en utilisant les prix actuels de MT5.
    
    Args:
        symbol: Symbole du trading
        historical_df: DataFrame historique
        threshold: Seuil de détection
        window: Fenêtre de calcul
    
    Returns:
        dict: Analyse complète des spikes en temps réel
    """
    try:
        from backend.mt5_connector import get_symbol_info
        
        # Récupérer le prix actuel de MT5
        symbol_info = get_symbol_info(symbol)
        if not symbol_info or 'bid' not in symbol_info or 'ask' not in symbol_info:
            return None
        
        current_price = (symbol_info['bid'] + symbol_info['ask']) / 2
        spread = symbol_info['ask'] - symbol_info['bid']
        
        # Détection traditionnelle
        spike_detection = detect_spike_realtime(symbol, current_price, historical_df, threshold, window)
        
        # Prédiction ML
        ml_prediction = predict_spike_realtime_ml(symbol, current_price, historical_df)
        
        # Analyse complète
        analysis = {
            'symbol': symbol,
            'current_price': current_price,
            'spread': spread,
            'timestamp': datetime.now(),
            'spike_detection': spike_detection,
            'ml_prediction': ml_prediction,
            'market_status': 'ACTIVE' if spread > 0 else 'INACTIVE'
        }
        
        # Déterminer l'alerte globale
        if spike_detection and spike_detection['confidence'] > 0.7:
            analysis['alert_level'] = 'HIGH'
            analysis['alert_message'] = f"🚨 SPIKE {spike_detection['spike_type']} DÉTECTÉ!"
        elif ml_prediction and ml_prediction['spike_probability'] > 0.7:
            analysis['alert_level'] = 'MEDIUM'
            analysis['alert_message'] = f"⚠️ SPIKE PROBABLE (ML: {ml_prediction['spike_probability']:.1%})"
        else:
            analysis['alert_level'] = 'LOW'
            analysis['alert_message'] = "✅ Pas de spike détecté"
        
        return analysis
        
    except Exception as e:
        logging.error(f"[REALTIME] Erreur lors de l'analyse en temps réel: {e}")
        return None

# --- FIN DU FICHIER ---