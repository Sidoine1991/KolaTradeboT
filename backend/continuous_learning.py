#!/usr/bin/env python3
"""
Système d'amélioration continue des modèles ML
Utilise les prédictions sauvegardées + résultats réels pour ré-entraîner périodiquement
"""

import os
import sys
import json
import logging
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
from backend.adaptive_predict import get_symbol_category, MODEL_CONFIGS, create_adaptive_features, MODEL_FEATURES

# Chemin du dossier MT5 Predictions
MT5_PREDICTIONS_DIR = Path(
    r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\Common\Files\Predictions"
)

# Mapping entre catégories trading et catégories adaptatives
TRADING_TO_ADAPTIVE_CATEGORY = {
    "BOOM_CRASH": "SYNTHETIC_SPECIAL",
    "VOLATILITY": "SYNTHETIC_GENERAL", 
    "FOREX": "FOREX",
    "COMMODITIES": "UNIVERSAL",  # Commodities n'a pas de catégorie spécifique
    "CRYPTO": "CRYPTO",
    "STOCKS": "STOCKS"
}

class ContinuousLearning:
    """
    Système d'apprentissage continu pour améliorer les modèles ML
    Utilise maintenant les vrais résultats de trades pour apprendre
    """
    
    def __init__(self, min_new_samples: int = 50, retrain_interval_days: int = 1, db_url: Optional[str] = None):
        """
        Args:
            min_new_samples: Nombre minimum de nouveaux trades avant ré-entraînement
            retrain_interval_days: Intervalle minimum entre ré-entraînements (jours)
            db_url: URL de la base de données PostgreSQL (optionnel)
        """
        self.min_new_samples = min_new_samples
        self.retrain_interval_days = retrain_interval_days
        self.last_retrain_file = Path("backend/last_retrain_times.json")
        self.last_retrain_times = self._load_last_retrain_times()
        self.db_url = db_url or os.getenv("DATABASE_URL")
    
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
    
    def load_trades_from_db(self, category: Optional[str] = None) -> Optional[pd.DataFrame]:
        """
        Charge les trades depuis la base de données PostgreSQL
        Utilise les vrais résultats (is_win) pour l'apprentissage
        """
        if not self.db_url:
            print("⚠️  DATABASE_URL non configuré - impossible de charger les trades")
            return None
        
        try:
            import asyncpg
            import asyncio
        except ImportError:
            print("⚠️  asyncpg non installé - installation requise pour charger les trades")
            return None
        
        async def _load_trades():
            try:
                conn = await asyncpg.connect(self.db_url)
                
                # Charger les trades récents avec leurs résultats
                query = """
                    SELECT 
                        symbol, open_time, close_time, entry_price, exit_price,
                        profit, ai_confidence, coherent_confidence, decision, is_win,
                        created_at
                    FROM trade_feedback
                    WHERE created_at >= NOW() - INTERVAL '30 days'
                    ORDER BY created_at DESC
                """
                
                rows = await conn.fetch(query)
                await conn.close()
                
                if not rows:
                    return None
                
                # Convertir en DataFrame
                trades_data = []
                for row in rows:
                    trades_data.append({
                        'symbol': row['symbol'],
                        'open_time': row['open_time'],
                        'close_time': row['close_time'],
                        'entry_price': row['entry_price'],
                        'exit_price': row['exit_price'],
                        'profit': row['profit'],
                        'ai_confidence': row['ai_confidence'],
                        'coherent_confidence': row['coherent_confidence'],
                        'decision': row['decision'],
                        'is_win': row['is_win'],
                        'created_at': row['created_at']
                    })
                
                df = pd.DataFrame(trades_data)
                
                # Filtrer par catégorie si spécifiée
                if category:
                    df['trading_category'] = df['symbol'].apply(self._map_symbol_to_trading_category)
                    df = df[df['trading_category'] == category]
                
                return df
            except Exception as e:
                print(f"❌ Erreur chargement trades depuis DB: {e}")
                return None
        
        # Exécuter la fonction async
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        
        return loop.run_until_complete(_load_trades())
    
    def _map_symbol_to_trading_category(self, symbol: str) -> str:
        """Map un symbole vers sa catégorie de trading"""
        symbol_upper = symbol.upper()
        if "BOOM" in symbol_upper or "CRASH" in symbol_upper:
            return "BOOM_CRASH"
        elif any(keyword in symbol_upper for keyword in ['VOLATILITY', 'STEP', 'JUMP', 'RANGE BREAK']):
            return "VOLATILITY"
        elif any(crypto in symbol_upper for crypto in ['BTC', 'ETH', 'ADA', 'DOT']):
            return "CRYPTO"
        elif any(pair in symbol_upper for pair in ['USD', 'EUR', 'GBP', 'JPY']):
            return "FOREX"
        else:
            return "COMMODITIES"
    
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
    
    def extract_features_from_trades(self, trades_df: pd.DataFrame) -> Optional[pd.DataFrame]:
        """
        Extrait les features depuis les trades
        Pour l'instant, essaie de récupérer depuis les prédictions sauvegardées
        TODO: Récupérer les données OHLC depuis MT5 pour recalculer les features
        """
        # Pour chaque trade, on essaie de trouver les features correspondantes
        # dans les fichiers de prédictions sauvegardées
        features_list = []
        
        for _, trade in trades_df.iterrows():
            symbol = trade['symbol']
            open_time = pd.to_datetime(trade['open_time'])
            
            # Chercher dans les fichiers de prédictions
            if MT5_PREDICTIONS_DIR.exists():
                for csv_file in MT5_PREDICTIONS_DIR.glob(f"*{symbol.replace(' ', '_')}*_predictions.csv"):
                    try:
                        pred_df = pd.read_csv(csv_file, sep=";", parse_dates=["time"])
                        # Trouver la prédiction la plus proche du moment d'ouverture
                        pred_df['time_diff'] = abs((pd.to_datetime(pred_df['time']) - open_time).dt.total_seconds())
                        closest = pred_df.nsmallest(1, 'time_diff')
                        
                        if len(closest) > 0 and closest['time_diff'].iloc[0] < 3600:  # Moins d'1h
                            try:
                                details = json.loads(closest['details_json'].iloc[0])
                                ml_decision = details.get("ml_decision", {})
                                if "input_row" in ml_decision:
                                    features_list.append(ml_decision["input_row"])
                                    break
                            except:
                                continue
                    except Exception as e:
                        continue
        
        if not features_list:
            print("⚠️  Impossible d'extraire les features depuis les prédictions")
            return None
        
        features_df = pd.DataFrame(features_list)
        return features_df
    
    def create_labels_from_trades(self, trades_df: pd.DataFrame) -> Optional[pd.Series]:
        """
        Crée les labels (targets) depuis les vrais résultats de trades
        Le modèle doit apprendre: si on prédit BUY et que le trade gagne → c'est bon
        Si on prédit BUY et que le trade perd → on aurait dû prédire SELL (0)
        
        Label = 1 si:
          - Decision était BUY ET is_win = True (la prédiction était correcte)
          - Decision était SELL ET is_win = False (on aurait dû prédire BUY)
        Label = 0 si:
          - Decision était SELL ET is_win = True (la prédiction était correcte)
          - Decision était BUY ET is_win = False (on aurait dû prédire SELL)
        """
        if trades_df is None or len(trades_df) == 0:
            return None
        
        # Normaliser les décisions
        trades_df = trades_df.copy()
        trades_df['decision_normalized'] = trades_df['decision'].str.upper().str.strip()
        
        # Filtrer seulement BUY et SELL
        trades = trades_df[trades_df['decision_normalized'].isin(['BUY', 'SELL'])].copy()
        
        if len(trades) == 0:
            return None
        
        # Créer les labels basés sur les résultats réels
        labels = []
        for _, trade in trades.iterrows():
            decision = trade['decision_normalized']
            is_win = trade['is_win']
            
            if decision == 'BUY':
                # Si BUY et gagnant → la prédiction était correcte → label = 1 (BUY était bon)
                # Si BUY et perdant → la prédiction était incorrecte → label = 0 (SELL aurait été meilleur)
                label = 1 if is_win else 0
            else:  # SELL
                # Si SELL et gagnant → la prédiction était correcte → label = 0 (SELL était bon)
                # Si SELL et perdant → la prédiction était incorrecte → label = 1 (BUY aurait été meilleur)
                label = 0 if is_win else 1
            
            labels.append(label)
        
        return pd.Series(labels, index=trades.index)
    
    def create_labels_from_predictions(self, predictions_df: pd.DataFrame) -> Optional[pd.Series]:
        """
        Crée les labels depuis les prédictions sauvegardées (fallback sans DB).
        Aligné avec extract_features_from_predictions : une label par ligne qui a input_row.
        Label = 1 (BUY) ou 0 (SELL) depuis ml_decision['prediction'] ou decision.
        """
        if predictions_df is None or len(predictions_df) == 0:
            return None
        labels_list = []
        for _, row in predictions_df.iterrows():
            try:
                details = json.loads(row["details_json"])
                ml_decision = details.get("ml_decision", {})
                if "input_row" not in ml_decision:
                    continue
                pred = ml_decision.get("prediction", None)
                if pred is not None:
                    labels_list.append(1 if int(pred) == 1 else 0)
                    continue
                decision = (ml_decision.get("decision") or details.get("decision") or "").upper().strip()
                if decision == "BUY":
                    labels_list.append(1)
                elif decision == "SELL":
                    labels_list.append(0)
                else:
                    labels_list.append(1)
            except Exception:
                continue
        if not labels_list:
            return None
        return pd.Series(labels_list)
    
    def retrain_model_for_category(self, category: str, use_historical_data: bool = True) -> Dict:
        """
        Ré-entraîne le modèle pour une catégorie donnée en utilisant les vrais résultats de trades
        
        Args:
            category: Catégorie trading à ré-entraîner (BOOM_CRASH, VOLATILITY, FOREX, etc.)
            use_historical_data: Si True, combine avec données historiques MT5 existantes
        """
        import logging
        log = logging.getLogger("tradbot_ai")
        
        log.info(f"\n{'='*60}")
        log.info(f"🔄 RÉ-ENTRAÎNEMENT - Catégorie: {category}")
        log.info(f"{'='*60}")
        
        # Convertir la catégorie trading vers la catégorie adaptative
        adaptive_category = TRADING_TO_ADAPTIVE_CATEGORY.get(category, "UNIVERSAL")
        log.info(f"📌 Catégorie adaptative: {adaptive_category}")
        
        # Vérifier si on doit ré-entraîner
        if not self._should_retrain(adaptive_category):
            last_time = self.last_retrain_times.get(adaptive_category, 'jamais')
            log.info(f"⏸️  Trop tôt pour ré-entraîner {adaptive_category}")
            log.info(f"   Dernier réentraînement: {last_time}")
            log.info(f"   Intervalle minimum: {self.retrain_interval_days} jours")
            return {"status": "skipped", "reason": "too_soon", "last_retrain": last_time}
        
        # Charger les trades depuis la base de données
        log.info(f"📊 Chargement des trades depuis la base de données...")
        trades_df = self.load_trades_from_db(category)
        if trades_df is None or len(trades_df) < self.min_new_samples:
            trades_count = len(trades_df) if trades_df is not None else 0
            log.warning(f"⏸️  Pas assez de trades dans la DB ({trades_count} < {self.min_new_samples})")
            log.info(f"   Minimum requis: {self.min_new_samples} trades")
            # Essayer de charger depuis les fichiers CSV en fallback
            predictions_df = self.load_predictions_for_category(category)
            if predictions_df is None or len(predictions_df) < self.min_new_samples:
                return {"status": "skipped", "reason": "insufficient_data", "trades_count": trades_count, "min_required": self.min_new_samples}
            log.info(f"   Utilisation des prédictions CSV en fallback ({len(predictions_df)} échantillons)")
            # Utiliser l'ancienne méthode en fallback
            features_df = self.extract_features_from_predictions(predictions_df)
            labels = self.create_labels_from_predictions(predictions_df)
        else:
            # Utiliser les vrais résultats de trades - c'est la meilleure méthode
            log.info(f"✅ Chargé {len(trades_df)} trades depuis la DB")
            # Statistiques sur les trades
            wins = trades_df['is_win'].sum() if 'is_win' in trades_df.columns else 0
            losses = (~trades_df['is_win']).sum() if 'is_win' in trades_df.columns else 0
            win_rate = (wins / len(trades_df) * 100) if len(trades_df) > 0 else 0
            log.info(f"   📈 Statistiques: {wins} wins / {losses} losses (Win Rate: {win_rate:.1f}%)")
            
            # Extraire les features depuis les trades
            # Pour chaque trade, on doit récupérer les données OHLC au moment de l'ouverture
            # Pour l'instant, on va essayer de récupérer les features depuis les prédictions sauvegardées
            # ou les recalculer si on a accès aux données MT5
            features_df = self.extract_features_from_trades(trades_df)
            labels = self.create_labels_from_trades(trades_df)
        
        if features_df is None or labels is None or len(features_df) != len(labels):
            print(f"❌ Erreur extraction features/labels")
            return {"status": "error", "reason": "feature_extraction_failed"}
        
        # Obtenir les features attendues pour cette catégorie
        expected_features = MODEL_FEATURES.get(adaptive_category, MODEL_FEATURES['UNIVERSAL'])
        
        # Vérifier que toutes les features attendues sont présentes
        missing_features = set(expected_features) - set(features_df.columns)
        if missing_features:
            print(f"⚠️  Features manquantes: {missing_features} - Remplissage avec 0")
            for feat in missing_features:
                features_df[feat] = 0
        
        # Sélectionner seulement les features attendues
        X = features_df[expected_features].fillna(0)
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
        log.info(f"📊 Entraînement du modèle XGBoost...")
        log.info(f"   - Échantillons d'entraînement: {len(X_train)}")
        log.info(f"   - Échantillons de test: {len(X_test)}")
        log.info(f"   - Features utilisées: {len(expected_features)}")
        
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
        
        log.info(f"✅ Nouveau modèle entraîné:")
        log.info(f"   - Accuracy: {accuracy:.3f} ({accuracy*100:.2f}%)")
        log.info(f"   - AUC-ROC: {auc:.3f}")
        
        # Comparer avec ancien modèle si disponible
        config = MODEL_CONFIGS.get(adaptive_category)
        if config and os.path.exists(config['model_path']):
            try:
                old_model = joblib.load(config['model_path'])
                old_scaler = joblib.load(config['scaler_path'])
                
                X_test_old_scaled = old_scaler.transform(X_test)
                old_pred = old_model.predict(X_test_old_scaled)
                old_accuracy = accuracy_score(y_test, old_pred)
                
                print(f"📊 Ancien modèle - Accuracy: {old_accuracy:.3f}")
                
                # Remplacer seulement si meilleur
                improvement = accuracy - old_accuracy
                log.info(f"📊 Comparaison avec l'ancien modèle:")
                log.info(f"   - Ancien modèle - Accuracy: {old_accuracy:.3f} ({old_accuracy*100:.2f}%)")
                log.info(f"   - Nouveau modèle - Accuracy: {accuracy:.3f} ({accuracy*100:.2f}%)")
                log.info(f"   - Amélioration: {improvement:+.3f} ({improvement*100:+.2f}%)")
                
                if improvement > 0.02:  # Au moins 2% d'amélioration
                    # Sauvegarder backup
                    backup_model = config['model_path'].replace('.pkl', '_backup.pkl')
                    backup_scaler = config['scaler_path'].replace('.pkl', '_backup.pkl')
                    os.rename(config['model_path'], backup_model)
                    os.rename(config['scaler_path'], backup_scaler)
                    
                    # Sauvegarder nouveau modèle
                    joblib.dump(model, config['model_path'])
                    joblib.dump(scaler, config['scaler_path'])
                    
                    log.info(f"✅ Modèle remplacé avec succès!")
                    log.info(f"   - Ancien modèle sauvegardé en backup")
                    log.info(f"   - Nouveau modèle actif: {config['model_path']}")
                    self._save_last_retrain_time(adaptive_category)
                    
                    return {
                        "status": "success",
                        "category": category,
                        "adaptive_category": adaptive_category,
                        "old_accuracy": old_accuracy,
                        "new_accuracy": accuracy,
                        "improvement": accuracy - old_accuracy,
                        "samples_used": len(X)
                    }
                else:
                    log.warning(f"⏸️  Modèle non remplacé - amélioration insuffisante")
                    log.warning(f"   Amélioration: {improvement:.3f} (minimum requis: 0.02)")
                    log.info(f"   L'ancien modèle reste actif")
                    return {
                        "status": "no_improvement",
                        "category": category,
                        "adaptive_category": adaptive_category,
                        "old_accuracy": old_accuracy,
                        "new_accuracy": accuracy,
                        "improvement": improvement
                    }
            except Exception as e:
                print(f"⚠️  Erreur comparaison ancien modèle: {e}")
                # Sauvegarder quand même le nouveau modèle
                joblib.dump(model, config['model_path'])
                joblib.dump(scaler, config['scaler_path'])
                self._save_last_retrain_time(adaptive_category)
                return {"status": "success", "category": category, "adaptive_category": adaptive_category, "accuracy": accuracy}
        else:
            # Pas d'ancien modèle, sauvegarder directement
            if config:
                joblib.dump(model, config['model_path'])
                joblib.dump(scaler, config['scaler_path'])
                self._save_last_retrain_time(adaptive_category)
                return {"status": "success", "category": category, "adaptive_category": adaptive_category, "accuracy": accuracy}
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

