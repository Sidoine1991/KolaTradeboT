#!/usr/bin/env python3
"""
Système d'amélioration continue des modèles ML
Utilise les prédictions sauvegardées + résultats réels pour ré-entraîner périodiquement
"""

import os
import sys
import json
import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import joblib
import warnings
warnings.filterwarnings('ignore')

# Ajouter le chemin du projet
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

try:
    from sklearn.model_selection import train_test_split
    from sklearn.preprocessing import StandardScaler
    from sklearn.metrics import accuracy_score, classification_report, roc_auc_score
    import xgboost as xgb
except ImportError as e:
    print(f"❌ Erreur import sklearn/xgboost: {e}")
    sys.exit(1)

from backend.features import compute_features, EXPECTED_FEATURES
from backend.adaptive_predict import get_symbol_category, MODEL_CONFIGS, create_adaptive_features

# Chemin du dossier MT5 Predictions
MT5_PREDICTIONS_DIR = Path(
    r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\Common\Files\Predictions"
)

class ContinuousLearning:
    """
    Système d'apprentissage continu pour améliorer les modèles ML
    """
    
    def __init__(self, min_new_samples: int = 100, retrain_interval_days: int = 7):
        """
        Args:
            min_new_samples: Nombre minimum de nouvelles prédictions avant ré-entraînement
            retrain_interval_days: Intervalle minimum entre ré-entraînements (jours)
        """
        self.min_new_samples = min_new_samples
        self.retrain_interval_days = retrain_interval_days
        self.last_retrain_file = Path("backend/last_retrain_times.json")
        self.last_retrain_times = self._load_last_retrain_times()
    
    def _load_last_retrain_times(self) -> Dict[str, str]:
        """Charge les timestamps de dernier ré-entraînement par catégorie"""
        if self.last_retrain_file.exists():
            try:
                with open(self.last_retrain_file, 'r') as f:
                    return json.load(f)
            except:
                return {}
        return {}
    
    def _save_last_retrain_time(self, category: str):
        """Sauvegarde le timestamp de dernier ré-entraînement"""
        self.last_retrain_times[category] = datetime.now().isoformat()
        with open(self.last_retrain_file, 'w') as f:
            json.dump(self.last_retrain_times, f, indent=2)
    
    def _should_retrain(self, category: str) -> bool:
        """Vérifie si on doit ré-entraîner pour cette catégorie"""
        if category not in self.last_retrain_times:
            return True
        
        last_time = datetime.fromisoformat(self.last_retrain_times[category])
        days_since = (datetime.now() - last_time).days
        return days_since >= self.retrain_interval_days
    
    def load_predictions_for_category(self, category: str) -> Optional[pd.DataFrame]:
        """
        Charge toutes les prédictions pour une catégorie donnée
        """
        if not MT5_PREDICTIONS_DIR.exists():
            print(f"❌ Dossier Predictions non trouvé: {MT5_PREDICTIONS_DIR}")
            return None
        
        all_predictions = []
        
        # Parcourir tous les fichiers CSV
        for csv_file in MT5_PREDICTIONS_DIR.glob("*_predictions.csv"):
            try:
                df = pd.read_csv(csv_file, sep=";", parse_dates=["time"])
                
                # Filtrer par catégorie
                if "category" in df.columns:
                    df_cat = df[df["category"] == category]
                    if len(df_cat) > 0:
                        all_predictions.append(df_cat)
            except Exception as e:
                print(f"⚠️ Erreur lecture {csv_file.name}: {e}")
                continue
        
        if not all_predictions:
            return None
        
        combined = pd.concat(all_predictions, ignore_index=True)
        print(f"✅ Chargé {len(combined)} prédictions pour catégorie {category}")
        return combined
    
    def extract_features_from_predictions(self, predictions_df: pd.DataFrame) -> Optional[pd.DataFrame]:
        """
        Extrait les features depuis les prédictions sauvegardées
        Note: Pour l'instant, on utilise les features stockées dans details_json
        À améliorer: récupérer les données OHLC réelles depuis MT5 pour recalculer les features
        """
        features_list = []
        
        for _, row in predictions_df.iterrows():
            try:
                details = json.loads(row["details_json"])
                ml_decision = details.get("ml_decision", {})
                
                # Si on a les features dans ml_decision, les utiliser
                if "input_row" in ml_decision:
                    features_list.append(ml_decision["input_row"])
            except Exception as e:
                continue
        
        if not features_list:
            return None
        
        features_df = pd.DataFrame(features_list)
        return features_df
    
    def create_labels_from_predictions(self, predictions_df: pd.DataFrame) -> Optional[pd.Series]:
        """
        Crée les labels (targets) depuis les prédictions
        Pour l'instant: action "buy" = 1, "sell" = 0, "hold" = exclu
        TODO: Améliorer avec les résultats réels des trades (PnL réel)
        """
        # Filtrer seulement les décisions de trading (exclure HOLD)
        trades = predictions_df[predictions_df["action"].isin(["buy", "sell"])].copy()
        
        if len(trades) == 0:
            return None
        
        # Label: 1 pour BUY, 0 pour SELL
        labels = (trades["action"] == "buy").astype(int)
        
        return labels
    
    def retrain_model_for_category(self, category: str, use_historical_data: bool = True) -> Dict:
        """
        Ré-entraîne le modèle pour une catégorie donnée
        
        Args:
            category: Catégorie à ré-entraîner (BOOM_CRASH, VOLATILITY, FOREX, etc.)
            use_historical_data: Si True, combine avec données historiques MT5 existantes
        """
        print(f"\n🔄 Ré-entraînement modèle pour catégorie: {category}")
        
        # Vérifier si on doit ré-entraîner
        if not self._should_retrain(category):
            print(f"⏸️  Trop tôt pour ré-entraîner {category} (dernier: {self.last_retrain_times.get(category, 'jamais')})")
            return {"status": "skipped", "reason": "too_soon"}
        
        # Charger les prédictions récentes
        predictions_df = self.load_predictions_for_category(category)
        if predictions_df is None or len(predictions_df) < self.min_new_samples:
            print(f"⏸️  Pas assez de nouvelles données ({len(predictions_df) if predictions_df is not None else 0} < {self.min_new_samples})")
            return {"status": "skipped", "reason": "insufficient_data"}
        
        # Extraire features et labels
        features_df = self.extract_features_from_predictions(predictions_df)
        labels = self.create_labels_from_predictions(predictions_df)
        
        if features_df is None or labels is None or len(features_df) != len(labels):
            print(f"❌ Erreur extraction features/labels")
            return {"status": "error", "reason": "feature_extraction_failed"}
        
        # Vérifier que toutes les features attendues sont présentes
        missing_features = set(EXPECTED_FEATURES) - set(features_df.columns)
        if missing_features:
            print(f"⚠️  Features manquantes: {missing_features} - Remplissage avec 0")
            for feat in missing_features:
                features_df[feat] = 0
        
        # Sélectionner seulement les features attendues
        X = features_df[EXPECTED_FEATURES].fillna(0)
        y = labels.values
        
        if len(X) < 50:  # Minimum absolu pour entraînement
            print(f"❌ Pas assez d'échantillons après filtrage ({len(X)} < 50)")
            return {"status": "error", "reason": "insufficient_samples"}
        
        # Diviser train/test
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y if len(np.unique(y)) > 1 else None
        )
        
        # Normaliser
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)
        X_test_scaled = scaler.transform(X_test)
        
        # Entraîner nouveau modèle XGBoost
        print(f"📊 Entraînement sur {len(X_train)} échantillons...")
        model = xgb.XGBClassifier(
            n_estimators=200,
            max_depth=6,
            learning_rate=0.1,
            subsample=0.8,
            colsample_bytree=0.8,
            random_state=42,
            eval_metric='logloss'
        )
        
        model.fit(
            X_train_scaled, y_train,
            eval_set=[(X_test_scaled, y_test)],
            early_stopping_rounds=20,
            verbose=False
        )
        
        # Évaluer
        y_pred = model.predict(X_test_scaled)
        y_pred_proba = model.predict_proba(X_test_scaled)[:, 1]
        
        accuracy = accuracy_score(y_test, y_pred)
        auc = roc_auc_score(y_test, y_pred_proba) if len(np.unique(y_test)) > 1 else 0.0
        
        print(f"✅ Nouveau modèle - Accuracy: {accuracy:.3f}, AUC: {auc:.3f}")
        
        # Comparer avec ancien modèle si disponible
        config = MODEL_CONFIGS.get(category)
        if config and os.path.exists(config['model_path']):
            try:
                old_model = joblib.load(config['model_path'])
                old_scaler = joblib.load(config['scaler_path'])
                
                X_test_old_scaled = old_scaler.transform(X_test)
                old_pred = old_model.predict(X_test_old_scaled)
                old_accuracy = accuracy_score(y_test, old_pred)
                
                print(f"📊 Ancien modèle - Accuracy: {old_accuracy:.3f}")
                
                # Remplacer seulement si meilleur
                if accuracy > old_accuracy + 0.02:  # Au moins 2% d'amélioration
                    # Sauvegarder backup
                    backup_model = config['model_path'].replace('.pkl', '_backup.pkl')
                    backup_scaler = config['scaler_path'].replace('.pkl', '_backup.pkl')
                    os.rename(config['model_path'], backup_model)
                    os.rename(config['scaler_path'], backup_scaler)
                    
                    # Sauvegarder nouveau modèle
                    joblib.dump(model, config['model_path'])
                    joblib.dump(scaler, config['scaler_path'])
                    
                    print(f"✅ Modèle remplacé (amélioration: +{accuracy - old_accuracy:.3f})")
                    self._save_last_retrain_time(category)
                    
                    return {
                        "status": "success",
                        "category": category,
                        "old_accuracy": old_accuracy,
                        "new_accuracy": accuracy,
                        "improvement": accuracy - old_accuracy,
                        "samples_used": len(X)
                    }
                else:
                    print(f"⏸️  Modèle non remplacé (amélioration insuffisante: {accuracy - old_accuracy:.3f})")
                    return {
                        "status": "no_improvement",
                        "category": category,
                        "old_accuracy": old_accuracy,
                        "new_accuracy": accuracy,
                        "improvement": accuracy - old_accuracy
                    }
            except Exception as e:
                print(f"⚠️  Erreur comparaison ancien modèle: {e}")
                # Sauvegarder quand même le nouveau modèle
                joblib.dump(model, config['model_path'])
                joblib.dump(scaler, config['scaler_path'])
                self._save_last_retrain_time(category)
                return {"status": "success", "category": category, "accuracy": accuracy}
        else:
            # Pas d'ancien modèle, sauvegarder directement
            if config:
                joblib.dump(model, config['model_path'])
                joblib.dump(scaler, config['scaler_path'])
                self._save_last_retrain_time(category)
                return {"status": "success", "category": category, "accuracy": accuracy}
            else:
                return {"status": "error", "reason": "no_config"}
    
    def retrain_all_categories(self) -> Dict[str, Dict]:
        """Ré-entraîne tous les modèles qui ont assez de nouvelles données"""
        results = {}
        
        categories = ["BOOM_CRASH", "VOLATILITY", "FOREX", "COMMODITIES"]
        
        for category in categories:
            try:
                result = self.retrain_model_for_category(category)
                results[category] = result
            except Exception as e:
                print(f"❌ Erreur ré-entraînement {category}: {e}")
                results[category] = {"status": "error", "error": str(e)}
        
        return results


def main():
    """Point d'entrée pour ré-entraînement manuel"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Ré-entraînement continu des modèles ML")
    parser.add_argument("--category", help="Catégorie spécifique à ré-entraîner")
    parser.add_argument("--all", action="store_true", help="Ré-entraîner toutes les catégories")
    parser.add_argument("--min-samples", type=int, default=100, help="Minimum d'échantillons requis")
    
    args = parser.parse_args()
    
    learner = ContinuousLearning(min_new_samples=args.min_samples)
    
    if args.all:
        results = learner.retrain_all_categories()
        print("\n📊 Résumé ré-entraînement:")
        for cat, result in results.items():
            print(f"   {cat}: {result.get('status', 'unknown')}")
    elif args.category:
        result = learner.retrain_model_for_category(args.category)
        print(f"\n📊 Résultat: {result}")
    else:
        parser.print_help()


if __name__ == "__main__":
    main()

