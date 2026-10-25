#!/usr/bin/env python3
"""
Entraînement continu des modèles ML pour TradBOT
S'exécute quotidiennement ou quand le quota de données est atteint
"""

import os
import sys
import json
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from pathlib import Path
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, accuracy_score, confusion_matrix, roc_auc_score
import joblib
import warnings
import requests
warnings.filterwarnings('ignore')

# Configuration
DATA_DIR = Path("D:/Dev/TradBOT/ml_data")
MODELS_DIR = Path("D:/Dev/TradBOT/ml_models")
QUOTA_MIN_TRADES = 500  # Nombre minimum de nouveaux trades pour entraîner
MAX_MODELS_KEEP = 10    # Nombre de modèles historiques à conserver

# Configuration WhatsApp pour notifications
_WHATSAPP_URL = os.getenv("WHATSAPP_URL", "https://psychobot-1si7.onrender.com")
_PHONE = os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346")

# Assurer l'existence des répertoires
DATA_DIR.mkdir(exist_ok=True)
MODELS_DIR.mkdir(exist_ok=True)

# Fonctions utilitaires
def load_data():
    """Charger les données d'entraînement"""
    features_path = DATA_DIR / "features.csv"
    labels_path = DATA_DIR / "labels.csv"

    if not features_path.exists() or not labels_path.exists():
        print("[WARNING] No training data found")
        return pd.DataFrame(), pd.DataFrame()

    features = pd.read_csv(features_path)
    labels = pd.read_csv(labels_path)

    # Nettoyer les données
    features = features.dropna()
    labels = labels.dropna()

    # Ensure timestamp column exists (for compatibility with older data)
    if 'timestamp' not in features.columns:
        features['timestamp'] = 0.0

    # Convertir les labels en numérique pour classification (3 classes)
    if 'result' in labels.columns:
        labels['result_num'] = labels['result'].map({'LOSS': 0, 'WIN': 1, 'BREAK_EVEN': 2})

    return features, labels

def save_data(features, labels):
    """Sauvegarder les données d'entraînement"""
    features.to_csv(DATA_DIR / "features.csv", index=False)
    labels.to_csv(DATA_DIR / "labels.csv", index=False)

    # Mettre à jour le metadata
    metadata = {
        "last_update": datetime.now().isoformat(),
        "total_trades": len(features),
        "features_count": len(features.columns) if not features.empty else 0
    }
    with open(DATA_DIR / "metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)

def create_feature_vector(trade):
    """Créer un vecteur de caractéristiques à partir d'un trade"""
    try:
        # Convertir les valeurs de manière robuste
        open_price = float(trade.get('open_price', 0))
        close_price = float(trade.get('close_price', 0))
        volume = float(trade.get('volume', 0))

        # Calculer les caractéristiques
        profit_pips = (close_price - open_price) / float(trade.get('point', 0.0001))
        duration_minutes = float(trade.get('duration_minutes', 0))
        gom_verdict = int(trade.get('gom_verdict_num', 0))
        ia_confidence = float(trade.get('ia_confidence', 0))
        technical_score = float(trade.get('score', 0))
        market_volatility = float(trade.get('volatility_index', 0))
        # Timestamp feature (seconds since epoch)
        timestamp = 0.0
        try:
            # Try to get close_time from trade
            close_time_str = trade.get('close_time', '')
            if close_time_str:
                from datetime import datetime
                dt = datetime.fromisoformat(close_time_str.replace('Z', '+00:00'))
                timestamp = dt.timestamp()
        except Exception:
            pass

        # Catégorie du symbole
        symbol = trade.get('symbol', '')
        if any(k in symbol.upper() for k in ['BOOM', 'CRASH', 'PAINX', 'GAINX']):
            category = 'volatility'
        elif any(k in symbol.upper() for k in ['EUR', 'GBP', 'JPY', 'USD']):
            category = 'forex'
        elif any(k in symbol.upper() for k in ['GOLD', 'SILVER', 'XAU', 'XAG']):
            category = 'commodities'
        else:
            category = 'other'

        # Encodeur one-hot pour la catégorie
        cat_features = {
            f'cat_{cat}': 1 if cat == category else 0
            for cat in ['forex', 'volatility', 'commodities', 'other']
        }

        # Convert day_of_week string to integer (0=Monday, 6=Sunday)
        day_of_week_str = trade.get('day_of_week', 'Monday')
        day_of_week_map = {
            'Monday': 0, 'Tuesday': 1, 'Wednesday': 2, 'Thursday': 3,
            'Friday': 4, 'Saturday': 5, 'Sunday': 6
        }
        day_of_week = day_of_week_map.get(day_of_week_str, 0)

        features = {
            'symbol': symbol,
            'direction': 1 if trade.get('direction') == 'BUY' else -1,
            'volume': volume,
            'open_price': open_price,
            'close_price': close_price,
            'profit_pips': profit_pips,
            'duration_minutes': duration_minutes,
            'gom_verdict': gom_verdict,
            'ia_confidence': ia_confidence,
            'technical_score': technical_score,
            'market_volatility': market_volatility,
            'hour_utc': int(trade.get('hour_utc', 0)) % 24,
            'day_of_week': day_of_week,
            'timestamp': timestamp,
            **cat_features
        }

        return features
    except Exception as e:
        print("[WARNING] Error creating features: {}".format(e))
        return None

def add_trade_to_ml(trade, result):
    """Ajouter un trade à la base d'apprentissage ML"""
    try:
        # Créer les features
        features = create_feature_vector(trade)
        if features is None:
            return False

        # Déterminer le résultat (mapping pour classification 3 classes)
        if result == 'WIN':
            label = 1
        elif result == 'LOSS':
            label = 0
        else:  # BREAK_EVEN
            label = 2

        # Charger les données existantes
        existing_features, existing_labels = load_data()

        # Ajouter le nouveau point
        new_feature_df = pd.DataFrame([features])
        new_label_df = pd.DataFrame([{'result': result, 'result_num': label}])

        combined_features = pd.concat([existing_features, new_feature_df], ignore_index=True)
        combined_labels = pd.concat([existing_labels, new_label_df], ignore_index=True)

        # Sauvegarder
        save_data(combined_features, combined_labels)
        print("[OK] Trade added to ML base: {} ({})".format(trade.get('symbol', 'UNKNOWN'), result))
        return True
    except Exception as e:
        print("[ERROR] Error adding trade to ML: {}".format(e))
        return False

def train_model(features, labels):
    """Entraîner un nouveau modèle Random Forest"""
    try:
        # Préparer les données
        X = features.drop(['symbol'], axis=1)
        y = labels['result_num']

        # Split train/test
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )

        # Essayer plusieurs modèles
        models = {
            'RandomForest': RandomForestClassifier(
                n_estimators=200, max_depth=15, random_state=42, n_jobs=-1
            ),
            'GradientBoosting': GradientBoostingClassifier(
                n_estimators=100, learning_rate=0.1, max_depth=10, random_state=42
            ),
            'LogisticRegression': LogisticRegression(
                max_iter=1000, random_state=42, n_jobs=-1
            )
        }

        best_model = None
        best_score = -1
        best_name = ''

        for name, model in models.items():
            model.fit(X_train, y_train)
            score = accuracy_score(y_test, model.predict(X_test))
            print(f"[INFO] {name}: {score:.2%} precision")
            if score > best_score:
                best_score = score
                best_model = model
                best_name = name

        # Évaluer sur l'ensemble complet
        full_score = accuracy_score(y, best_model.predict(X))
        print(f"[INFO] Final score on all data: {full_score:.2%}")

        # Sauvegarder le modèle
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        model_name = f"ml_model_{timestamp}_{best_name}"
        model_path = MODELS_DIR / f"{model_name}.pkl"
        joblib.dump(best_model, model_path)

        # Sauvegarder les métadonnées
        metadata = {
            "model_name": model_name,
            "trained_at": timestamp,
            "features": list(X.columns),
            "accuracy_full": float(full_score),
            "accuracy_test": float(best_score),
            "sample_size": len(X),
            "model_type": best_name
        }
        with open(MODELS_DIR / f"{model_name}.json", "w") as f:
            json.dump(metadata, f, indent=2)

        # Envoyer une notification WhatsApp avec les performances du modèle
        try:
            send_model_performance_notification(model_name, metadata)
        except Exception as e:
            print(f"[WARNING] Échec de l'envoi de la notification WhatsApp: {e}")

        # Nettoyer les anciens modèles (garder les MAX_MODELS_KEEP meilleurs)
        cleanup_old_models()

        print(f"[OK] New model saved: {model_name}")
        return model_path, metadata
    except Exception as e:
        print("[ERROR] Training error: {}".format(e))
        return None, None

def cleanup_old_models():
    """Supprimer les anciens modèles pour libérer de l'espace"""
    try:
        all_models = list(MODELS_DIR.glob("*.pkl"))
        if len(all_models) > MAX_MODELS_KEEP:
            # Trier par date (les plus récents en premier)
            all_models.sort(key=lambda p: p.stat().st_mtime, reverse=True)
            to_delete = all_models[MAX_MODELS_KEEP:]
            for model_path in to_delete:
                model_path.unlink()
                print(f"🗑️ Supprimé ancien modèle: {model_path.name}")
    except Exception as e:
        print(f"⚠️ Erreur nettoyage modèles: {e}")

def load_latest_model():
    """Charger le modèle le plus récent"""
    try:
        all_models = list(MODELS_DIR.glob("*.pkl"))
        if not all_models:
            return None, None
        # Le plus récent en premier
        latest = max(all_models, key=lambda p: p.stat().st_mtime)
        model = joblib.load(latest)
        # Charger les métadonnées
        meta_path = latest.with_suffix('.json')
        if meta_path.exists():
            with open(meta_path) as f:
                metadata = json.load(f)
        else:
            metadata = {"model_name": latest.name, "trained_at": "inconnu"}
        return model, metadata
    except Exception as e:
        print(f"[ERROR] Erreur chargement modèle: {e}")
        return None, None


def send_model_performance_notification(model_name, metadata):
    """Send WhatsApp notification with model performance metrics"""
    try:
        msg = (
            f"*Nouveau modèle ML entraîné* [{datetime.now().strftime('%H:%M UTC')}]\n"
            f"Modèle: {model_name}\n"
            f"Précision test: {metadata['accuracy_test']:.2%}\n"
            f"Précision totale: {metadata['accuracy_full']:.2%}\n"
            f"Échantillons: {metadata['sample_size']}\n"
            f"Features: {len(metadata['features'])}"
        )
        r = requests.post(
            f"{_WHATSAPP_URL}/send-message",
            json={"phone": _PHONE, "message": msg},
            timeout=10,
            verify=False,
        )
        if r.status_code == 200 and r.json().get("success"):
            print("WhatsApp notification sent")
        else:
            print(f"[WARNING] WhatsApp response: {r.status_code} {r.text[:200]}")
    except Exception as e:
        print(f"[ERROR] Failed to send WhatsApp notification: {e}")

def main():
    """Fonction principale"""
    print("Starting ML continuous training")

    # Charger les données récentes (derniers jours)
    features, labels = load_data()
    if features.empty or labels.empty:
        print("[WARNING] Not enough data for training")
        return

    # Vérifier le quota
    recent_days = 7
    cutoff = datetime.now() - timedelta(days=recent_days)
    recent_mask = pd.to_datetime(features['timestamp']).dt.date >= cutoff.date()
    recent_features = features[recent_mask]
    recent_labels = labels[recent_mask]

    print("{} new trades in the last {} days".format(len(recent_features), recent_days))

    if len(recent_features) >= QUOTA_MIN_TRADES:
        print("Quota reached ({} >= {}), training on recent data...".format(len(recent_features), QUOTA_MIN_TRADES))
        model_path, metadata = train_model(recent_features, recent_labels)
    else:
        print("Not enough new trades ({} < {}), training on all available data ({} total)".format(len(recent_features), QUOTA_MIN_TRADES, len(features)))
        model_path, metadata = train_model(features, labels)

    if model_path:
        print("Training successful! New model: {}".format(metadata['model_name']))
    else:
        print("Training failed")

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Entraînement continu des modèles ML pour TradBOT')
    parser.add_argument('--add-trade', type=int, help='Numéro du ticket de trade à ajouter à la base ML')
    parser.add_argument('--result', choices=['WIN', 'LOSS', 'BREAK_EVEN'], help='Résultat du trade (WIN/LOSS/BREAK_EVEN)')
    args = parser.parse_args()

    if args.add_trade is not None and args.result is not None:
        # Ajouter un trade spécifique à la base ML
        print(f"[INFO] Ajout du trade {args.add_trade} avec résultat {args.result} à la base ML")
        # Charger le trade depuis la base de données
        db_path = Path("D:/Dev/TradBOT/data/trades.db")
        if not db_path.exists():
            print("❌ Base de données trades.db non trouvée")
            sys.exit(1)
        import sqlite3
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM trades WHERE deal_ticket = ?", (args.add_trade,))
        columns = [description[0] for description in cursor.description]
        row = cursor.fetchone()
        conn.close()
        if row:
            trade = dict(zip(columns, row))
            # Ajouter à la base ML
            success = add_trade_to_ml(trade, args.result)
            if success:
                print(f"[OK] Trade {args.add_trade} ajouté à la base ML")
            else:
                print(f"[ERROR] Échec de l'ajout du trade {args.add_trade} à la base ML")
        else:
            print(f"[ERROR] Trade {args.add_trade} non trouvé dans la base de données")
    else:
        # Entraînement normal
        main()
