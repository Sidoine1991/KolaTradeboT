"""
Version simplifiée du Pipeline ML Automatisé.
Système automatisé pour l'analyse exploratoire des données (EDA),
construction de pipeline et entraînement de modèles pour chaque devise.
Objectif : Prédire Strong Buy/Sell avec paramètres SL/TP optimaux.
"""

import os
import sys
import json
import logging
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import warnings
warnings.filterwarnings('ignore')

# ML imports
from sklearn.model_selection import train_test_split, cross_val_score, GridSearchCV
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from sklearn.pipeline import Pipeline
import joblib

# Technical analysis
import ta
from ta.trend import SMAIndicator, EMAIndicator, MACD
from ta.momentum import RSIIndicator, StochasticOscillator
from ta.volatility import BollingerBands, AverageTrueRange
from ta.volume import VolumeWeightedAveragePrice

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class AutomatedMLPipeline:
    """
    Pipeline automatisé pour l'analyse ML de chaque devise.
    """
    
    def __init__(self, data_dir: str = "D:/Dev/TradBOT/data"):
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(exist_ok=True)
        
        # Récupération dynamique des symboles disponibles
        self.symbols = self._get_all_available_symbols()
        
        # Configuration des modèles
        self.models_config = {
            'random_forest': {
                'model': RandomForestClassifier(random_state=42),
                'params': {
                    'n_estimators': [100, 200, 300],
                    'max_depth': [10, 20, None],
                    'min_samples_split': [2, 5, 10]
                }
            },
            'gradient_boosting': {
                'model': GradientBoostingClassifier(random_state=42),
                'params': {
                    'n_estimators': [100, 200],
                    'learning_rate': [0.01, 0.1, 0.2],
                    'max_depth': [3, 5, 7]
                }
            },
            'logistic_regression': {
                'model': LogisticRegression(random_state=42, max_iter=1000),
                'params': {
                    'C': [0.1, 1, 10],
                    'penalty': ['l1', 'l2']
                }
            }
        }
        
        # Métriques de performance
        self.performance_metrics = {}
    
    def download_data_for_symbol(self, symbol: str, timeframe: str = "1h", count: int = 3000) -> pd.DataFrame:
        """
        Télécharge les données pour un symbole donné.
        Version simplifiée avec données simulées.
        """
        try:
            logger.info(f"📥 Téléchargement des données pour {symbol}")
            
            # Simulation de données OHLCV
            dates = pd.date_range(end=datetime.now(), periods=count, freq='1H')
            np.random.seed(42)  # Pour la reproductibilité
            
            # Prix de base selon le symbole
            base_price = 1.0 if 'USD' in symbol else 100.0
            
            # Génération de données simulées
            returns = np.random.normal(0, 0.001, count)  # 0.1% de volatilité par heure
            prices = base_price * np.exp(np.cumsum(returns))
            
            df = pd.DataFrame({
                'timestamp': dates,
                'open': prices * (1 + np.random.normal(0, 0.0005, count)),
                'high': prices * (1 + abs(np.random.normal(0, 0.001, count))),
                'low': prices * (1 - abs(np.random.normal(0, 0.001, count))),
                'close': prices,
                'volume': np.random.randint(1000, 10000, count)
            })
            
            # Assurer que high >= max(open, close) et low <= min(open, close)
            df['high'] = df[['open', 'close', 'high']].max(axis=1)
            df['low'] = df[['open', 'close', 'low']].min(axis=1)
            
            logger.info(f"✅ {len(df)} bougies téléchargées pour {symbol}")
            return df
            
        except Exception as e:
            logger.error(f"❌ Erreur lors du téléchargement des données pour {symbol}: {e}")
            raise
    
    def perform_eda(self, df: pd.DataFrame, symbol: str) -> Dict:
        """
        Effectue l'analyse exploratoire des données (EDA).
        """
        try:
            logger.info(f"🔍 EDA pour {symbol}")
            
            eda_results = {
                'symbol': symbol,
                'data_shape': df.shape,
                'data_types': df.dtypes.to_dict(),
                'missing_values': df.isnull().sum().to_dict(),
                'descriptive_stats': df.describe().to_dict(),
                'recommendations': []
            }
            
            # Vérification des valeurs manquantes
            missing_pct = df.isnull().sum().sum() / (df.shape[0] * df.shape[1]) * 100
            if missing_pct > 5:
                eda_results['recommendations'].append(f"⚠️ {missing_pct:.1f}% de valeurs manquantes détectées")
            
            # Vérification des doublons
            duplicates = df.duplicated().sum()
            if duplicates > 0:
                eda_results['recommendations'].append(f"⚠️ {duplicates} lignes dupliquées détectées")
            
            # Vérification de la cohérence des prix
            price_issues = ((df['high'] < df['low']) | (df['high'] < df['open']) | 
                           (df['high'] < df['close']) | (df['low'] > df['open']) | 
                           (df['low'] > df['close'])).sum()
            if price_issues > 0:
                eda_results['recommendations'].append(f"⚠️ {price_issues} incohérences de prix détectées")
            
            # Recommandations automatiques
            if not eda_results['recommendations']:
                eda_results['recommendations'].append("✅ Données de bonne qualité")
            
            eda_results['recommendations'].append("✅ Prêt pour l'ingénierie des features")
            
            logger.info(f"✅ EDA terminé pour {symbol}")
            return eda_results
            
        except Exception as e:
            logger.error(f"❌ Erreur lors de l'EDA pour {symbol}: {e}")
            raise
    
    def prepare_features(self, df: pd.DataFrame, symbol: str) -> Tuple[pd.DataFrame, pd.Series]:
        """
        Prépare les features pour l'entraînement du modèle.
        """
        try:
            logger.info(f"🔧 Préparation des features pour {symbol}")
            
            # Copie des données
            features_df = df.copy()
            
            # Features de prix
            features_df['returns_1'] = features_df['close'].pct_change(1)
            features_df['returns_5'] = features_df['close'].pct_change(5)
            features_df['returns_20'] = features_df['close'].pct_change(20)
            
            # Features de volatilité
            features_df['volatility_5'] = features_df['returns_1'].rolling(5).std()
            features_df['volatility_20'] = features_df['returns_1'].rolling(20).std()
            
            # Features de volume
            features_df['volume_sma_20'] = features_df['volume'].rolling(20).mean()
            features_df['volume_ratio'] = features_df['volume'] / features_df['volume_sma_20']
            
            # Indicateurs techniques simples
            features_df['sma_20'] = features_df['close'].rolling(20).mean()
            features_df['sma_50'] = features_df['close'].rolling(50).mean()
            features_df['price_vs_sma20'] = (features_df['close'] - features_df['sma_20']) / features_df['sma_20']
            features_df['price_vs_sma50'] = (features_df['close'] - features_df['sma_50']) / features_df['sma_50']
            
            # Features de momentum
            features_df['momentum_5'] = features_df['close'] / features_df['close'].shift(5) - 1
            features_df['momentum_20'] = features_df['close'] / features_df['close'].shift(20) - 1
            
            # Features de tendance
            features_df['trend_5'] = np.where(features_df['sma_20'] > features_df['sma_20'].shift(5), 1, -1)
            features_df['trend_20'] = np.where(features_df['sma_50'] > features_df['sma_50'].shift(20), 1, -1)
            
            # Suppression des lignes avec NaN
            features_df = features_df.dropna()
            
            # Création de la target
            target = self._create_target(features_df)
            
            # Sélection des features numériques
            feature_columns = features_df.select_dtypes(include=[np.number]).columns.tolist()
            feature_columns = [col for col in feature_columns if col not in ['timestamp', 'open', 'high', 'low', 'close', 'volume']]
            
            features = features_df[feature_columns]
            
            logger.info(f"✅ {len(feature_columns)} features préparées pour {symbol}")
            return features, target
            
        except Exception as e:
            logger.error(f"❌ Erreur lors de la préparation des features pour {symbol}: {e}")
            raise
    
    def _create_target(self, df: pd.DataFrame) -> pd.Series:
        """
        Crée la variable cible pour la classification.
        """
        try:
            # Classification en 3 classes : Strong Buy, Strong Sell, Neutral
            target = pd.Series(index=df.index, data='Neutral')
            
            # Strong Buy : >2% sur 5 périodes ET >5% sur 20 périodes
            strong_buy_mask = (df['returns_5'] > 0.02) & (df['returns_20'] > 0.05)
            target[strong_buy_mask] = 'Strong Buy'
            
            # Strong Sell : <-2% sur 5 périodes ET <-5% sur 20 périodes
            strong_sell_mask = (df['returns_5'] < -0.02) & (df['returns_20'] < -0.05)
            target[strong_sell_mask] = 'Strong Sell'
            
            # Distribution des classes
            class_dist = target.value_counts()
            logger.info(f"📊 Distribution des classes : {class_dist.to_dict()}")
            
            return target
            
        except Exception as e:
            logger.error(f"❌ Erreur lors de la création de la target : {e}")
            raise
    
    def build_and_train_models(self, features: pd.DataFrame, target: pd.Series, symbol: str) -> Dict:
        """
        Construit et entraîne les modèles ML.
        """
        try:
            logger.info(f"🏗️ Construction et entraînement des modèles pour {symbol}")
            
            # Encodage de la target
            le = LabelEncoder()
            target_encoded = le.fit_transform(target)
            
            # Split des données
            X_train, X_test, y_train, y_test = train_test_split(
                features, target_encoded, test_size=0.2, random_state=42, stratify=target_encoded
            )
            
            # Standardisation des features
            scaler = StandardScaler()
            X_train_scaled = scaler.fit_transform(X_train)
            X_test_scaled = scaler.transform(X_test)
            
            # Entraînement des modèles
            models_results = {}
            best_model_name = None
            best_score = 0
            
            for model_name, model_config in self.models_config.items():
                try:
                    logger.info(f"🎯 Entraînement de {model_name}")
                    
                    # Grid Search pour l'optimisation des hyperparamètres
                    grid_search = GridSearchCV(
                        model_config['model'],
                        model_config['params'],
                        cv=5,
                        scoring='accuracy',
                        n_jobs=-1
                    )
                    
                    grid_search.fit(X_train_scaled, y_train)
                    
                    # Évaluation sur le test set
                    y_pred = grid_search.predict(X_test_scaled)
                    accuracy = accuracy_score(y_test, y_pred)
                    
                    # Validation croisée
                    cv_scores = cross_val_score(grid_search.best_estimator_, X_train_scaled, y_train, cv=5)
                    
                    models_results[model_name] = {
                        'model': grid_search.best_estimator_,
                        'best_params': grid_search.best_params_,
                        'best_score': grid_search.best_score_,
                        'test_accuracy': accuracy,
                        'cv_mean': cv_scores.mean(),
                        'cv_std': cv_scores.std(),
                        'classification_report': classification_report(y_test, y_pred, output_dict=True),
                        'confusion_matrix': confusion_matrix(y_test, y_pred).tolist()
                    }
                    
                    # Mise à jour du meilleur modèle
                    if accuracy > best_score:
                        best_score = accuracy
                        best_model_name = model_name
                    
                    logger.info(f"✅ {model_name} - Précision: {accuracy:.3f}")
                    
                except Exception as e:
                    logger.error(f"❌ Erreur lors de l'entraînement de {model_name}: {e}")
                    continue
            
            # Sauvegarde des modèles et transformations
            symbol_dir = self.data_dir / symbol.replace('/', '_')
            symbol_dir.mkdir(exist_ok=True)
            
            # Sauvegarde du meilleur modèle
            if best_model_name:
                best_model = models_results[best_model_name]['model']
                model_path = symbol_dir / f"{best_model_name}_model.pkl"
                joblib.dump(best_model, model_path)
                
                # Sauvegarde du scaler
                scaler_path = symbol_dir / f"{best_model_name}_scaler.pkl"
                joblib.dump(scaler, scaler_path)
                
                # Sauvegarde des métadonnées
                metadata = {
                    'symbol': symbol,
                    'training_date': datetime.now().isoformat(),
                    'best_model': best_model_name,
                    'best_accuracy': best_score,
                    'models_trained': list(models_results.keys()),
                    'feature_names': features.columns.tolist(),
                    'class_distribution': target.value_counts().to_dict()
                }
                
                metadata_path = symbol_dir / "metadata.json"
                with open(metadata_path, 'w') as f:
                    json.dump(metadata, f, indent=2)
                
                logger.info(f"💾 Modèle sauvegardé : {model_path}")
            
            return {
                'best_model_info': {
                    'best_model_name': best_model_name,
                    'best_performance': {
                        'accuracy': best_score,
                        'cv_mean': models_results[best_model_name]['cv_mean'],
                        'cv_std': models_results[best_model_name]['cv_std']
                    }
                },
                'all_models': models_results,
                'data_info': {
                    'train_size': len(X_train),
                    'test_size': len(X_test),
                    'feature_count': len(features.columns),
                    'class_distribution': target.value_counts().to_dict()
                }
            }
            
        except Exception as e:
            logger.error(f"❌ Erreur lors de l'entraînement des modèles pour {symbol}: {e}")
            raise
    
    def get_prediction_parameters(self, symbol: str) -> Dict:
        """
        Récupère les paramètres de prédiction pour un symbole.
        """
        try:
            symbol_dir = self.data_dir / symbol.replace('/', '_')
            metadata_path = symbol_dir / "metadata.json"
            
            if not metadata_path.exists():
                return {'error': f'Aucun modèle entraîné trouvé pour {symbol}'}
            
            # Chargement des métadonnées
            with open(metadata_path, 'r') as f:
                metadata = json.load(f)
            
            # Chargement du modèle et du scaler
            best_model_name = metadata['best_model']
            model_path = symbol_dir / f"{best_model_name}_model.pkl"
            scaler_path = symbol_dir / f"{best_model_name}_scaler.pkl"
            
            if not model_path.exists() or not scaler_path.exists():
                return {'error': f'Fichiers de modèle manquants pour {symbol}'}
            
            model = joblib.load(model_path)
            scaler = joblib.load(scaler_path)
            
            # Calcul des paramètres de trading optimaux
            accuracy = metadata['best_accuracy']
            parameters = self._calculate_optimal_parameters(accuracy, symbol)
            
            return {
                'symbol': symbol,
                'model_loaded': True,
                'model_name': best_model_name,
                'accuracy': accuracy,
                'transformations': {
                    'scaler': scaler,
                    'feature_names': metadata['feature_names']
                },
                'parameters': parameters
            }
            
        except Exception as e:
            return {'error': f'Erreur lors du chargement des paramètres : {e}'}
    
    def _calculate_optimal_parameters(self, accuracy: float, symbol: str) -> Dict:
        """
        Calcule les paramètres optimaux de trading basés sur la performance du modèle.
        """
        # Paramètres de base
        base_params = {
            'Strong Buy': {
                'stop_loss_pct': -2.0,
                'take_profit_pct': 5.0,
                'signal_duration_hours': 24,
                'confidence_threshold': 0.7
            },
            'Strong Sell': {
                'stop_loss_pct': 2.0,
                'take_profit_pct': -5.0,
                'signal_duration_hours': 24,
                'confidence_threshold': 0.7
            }
        }
        
        # Ajustement basé sur la précision du modèle
        if accuracy > 0.8:
            # Modèle très performant : paramètres plus agressifs
            for signal_type in base_params:
                base_params[signal_type]['stop_loss_pct'] *= 0.8
                base_params[signal_type]['take_profit_pct'] *= 1.2
                base_params[signal_type]['confidence_threshold'] = 0.8
        elif accuracy < 0.6:
            # Modèle peu performant : paramètres plus conservateurs
            for signal_type in base_params:
                base_params[signal_type]['stop_loss_pct'] *= 1.2
                base_params[signal_type]['take_profit_pct'] *= 0.8
                base_params[signal_type]['confidence_threshold'] = 0.6
        
        return base_params
    
    def run_complete_pipeline(self, symbol: str) -> Dict:
        """
        Exécute le pipeline complet pour un symbole.
        """
        try:
            logger.info(f"🚀 Lancement du pipeline complet pour {symbol}")
            
            # 1. Téléchargement des données
            df = self.download_data_for_symbol(symbol)
            
            # 2. EDA
            eda_results = self.perform_eda(df, symbol)
            
            # 3. Préparation des features
            features, target = self.prepare_features(df, symbol)
            
            # 4. Entraînement des modèles
            training_results = self.build_and_train_models(features, target, symbol)
            
            logger.info(f"✅ Pipeline terminé avec succès pour {symbol}")
            
            return {
                'status': 'success',
                'symbol': symbol,
                'eda_results': eda_results,
                'training_results': training_results
            }
            
        except Exception as e:
            logger.error(f"❌ Échec du pipeline pour {symbol}: {e}")
            return {
                'status': 'error',
                'symbol': symbol,
                'error': str(e)
            }
    
    def run_pipeline_for_all_symbols(self, symbols: Optional[List[str]] = None) -> Dict:
        """
        Exécute le pipeline pour plusieurs symboles.
        """
        if symbols is None:
            symbols = self.symbols
        
        logger.info(f"🌍 Lancement du pipeline pour {len(symbols)} symboles")
        
        results = {}
        successful = 0
        failed = 0
        
        for symbol in symbols:
            try:
                result = self.run_complete_pipeline(symbol)
                results[symbol] = result
                
                if result['status'] == 'success':
                    successful += 1
                else:
                    failed += 1
                    
            except Exception as e:
                logger.error(f"❌ Erreur pour {symbol}: {e}")
                results[symbol] = {
                    'status': 'error',
                    'error': str(e)
                }
                failed += 1
        
        # Sauvegarde du résumé global
        summary = {
            'total_symbols': len(symbols),
            'successful': successful,
            'failed': failed,
            'success_rate': (successful / len(symbols)) * 100 if symbols else 0,
            'results': results,
            'timestamp': datetime.now().isoformat()
        }
        
        summary_path = self.data_dir / "global_pipeline_summary.json"
        with open(summary_path, 'w') as f:
            json.dump(summary, f, indent=2)
        
        logger.info(f"🎉 Pipeline terminé : {successful}/{len(symbols)} succès")
        return summary

    def _get_all_available_symbols(self) -> List[str]:
        """
        Récupère tous les symboles disponibles, organisés par catégorie.
        Inclut Forex, Indices, Crypto, Métaux, Commodités, etc.
        """
        try:
            # Tentative de récupération depuis MT5
            try:
                import MetaTrader5 as mt5
                if mt5.initialize():
                    symbols = mt5.symbols_get()
                    mt5.shutdown()
                    if symbols:
                        # Filtrer et organiser les symboles
                        all_symbols = []
                        for symbol in symbols:
                            symbol_name = symbol.name
                            # Exclure les symboles avec des caractères spéciaux ou trop longs
                            if (len(symbol_name) <= 20 and 
                                not any(char in symbol_name for char in ['#', '&', '(', ')', ' ']) and
                                symbol_name.isalnum() or '_' in symbol_name):
                                all_symbols.append(symbol_name)
                        
                        if all_symbols:
                            logger.info(f"✅ {len(all_symbols)} symboles récupérés depuis MT5")
                            return sorted(all_symbols)
            except Exception as e:
                logger.warning(f"⚠️ Impossible de récupérer les symboles MT5 : {e}")
            
            # Fallback : liste étendue de symboles populaires par catégorie
            fallback_symbols = []
            
            # Forex (Devises)
            forex_symbols = [
                'EURUSD', 'GBPUSD', 'USDJPY', 'USDCHF', 'AUDUSD', 'NZDUSD', 'USDCAD',
                'EURGBP', 'EURJPY', 'GBPJPY', 'AUDJPY', 'CADJPY', 'NZDJPY',
                'EURAUD', 'GBPAUD', 'AUDCAD', 'AUDNZD', 'CADCHF', 'NZDCHF'
            ]
            fallback_symbols.extend(forex_symbols)
            
            # Indices (Bourses)
            index_symbols = [
                'US30', 'NAS100', 'SPX500', 'NDX100', 'DJI', 'SPY', 'QQQ',
                'GER30', 'FRA40', 'ITA40', 'ESP35', 'NLD25', 'SWE30',
                'JPN225', 'AUS200', 'CAN60', 'BRA50', 'MEX35', 'IND50'
            ]
            fallback_symbols.extend(index_symbols)
            
            # Crypto (Cryptomonnaies)
            crypto_symbols = [
                'BTCUSD', 'ETHUSD', 'LTCUSD', 'XRPUSD', 'ADAUSD', 'DOTUSD',
                'LINKUSD', 'BCHUSD', 'XLMUSD', 'EOSUSD', 'TRXUSD', 'VETUSD',
                'MATICUSD', 'SOLUSD', 'AVAXUSD', 'ATOMUSD', 'NEARUSD', 'FTMUSD'
            ]
            fallback_symbols.extend(crypto_symbols)
            
            # Métaux précieux
            metal_symbols = [
                'XAUUSD', 'XAGUSD', 'XPTUSD', 'XPDUSD', 'XAUAUD', 'XAGEUR',
                'XAUGBP', 'XAUJPY', 'XAGGBP', 'XAGJPY'
            ]
            fallback_symbols.extend(metal_symbols)
            
            # Commodités (Énergie, Agriculture)
            commodity_symbols = [
                'WTIUSD', 'BRENTUSD', 'NATGASUSD', 'HEATOILUSD',
                'CORNUSD', 'WHEATUSD', 'SOYBEANUSD', 'SUGARUSD',
                'COFFEEUSD', 'COCOAUSD', 'COTTONUSD', 'LUMBERUSD'
            ]
            fallback_symbols.extend(commodity_symbols)
            
            # Actions populaires (si disponibles)
            stock_symbols = [
                'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'TSLA', 'META', 'NVDA',
                'NFLX', 'ADBE', 'CRM', 'PYPL', 'INTC', 'AMD', 'ORCL'
            ]
            fallback_symbols.extend(stock_symbols)
            
            # Indices synthétiques (Boom/Crash)
            synthetic_symbols = [
                'Boom 1000 Index', 'Boom 900 Index', 'Boom 800 Index',
                'Crash 1000 Index', 'Crash 900 Index', 'Crash 800 Index',
                'Boom 500 Index', 'Crash 500 Index'
            ]
            fallback_symbols.extend(synthetic_symbols)
            
            logger.info(f"✅ {len(fallback_symbols)} symboles de fallback chargés")
            return sorted(fallback_symbols)
            
        except Exception as e:
            logger.error(f"❌ Erreur lors de la récupération des symboles : {e}")
            # Dernier fallback : symboles de base
            basic_symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'XAUUSD', 'BTCUSD', 'US30', 'NAS100']
            logger.warning(f"⚠️ Utilisation des symboles de base : {len(basic_symbols)}")
            return basic_symbols
