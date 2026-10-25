# 🚀 Pipeline ML Automatisé - Trading Bot

## 📋 Vue d'ensemble

Ce système automatisé effectue une **analyse complète** de chaque devise de trading en suivant ces étapes :

1. **📥 Téléchargement** des 3000 dernières bougies
2. **🔍 Analyse exploratoire des données (EDA)** complète
3. **🔧 Préparation des features** techniques avancées
4. **🏗️ Construction du pipeline** de modélisation
5. **🎯 Entraînement des modèles** avec validation croisée
6. **📊 Évaluation des performances** et sélection du meilleur modèle
7. **⚙️ Calcul des paramètres optimaux** SL/TP pour le trading

## 🎯 Objectif Final

**Prédire avec précision les signaux Strong Buy/Sell** et fournir automatiquement :
- **Stop Loss (SL)** optimal
- **Take Profit (TP)** optimal  
- **Durée du signal** recommandée
- **Seuil de confiance** requis

## 🏗️ Architecture du Système

```
📁 backend/
├── automated_ml_pipeline.py    # Pipeline principal
├── mt5_connector.py           # Connexion MT5
└── technical_analysis.py      # Analyse technique

📁 config/
├── ml_pipeline_config.py      # Configuration complète
└── settings.py               # Paramètres généraux

📁 data/                      # Dossier de sortie
├── EURUSD/                   # Un dossier par devise
│   ├── random_forest_model.pkl
│   ├── transformations.pkl
│   ├── model_performances.json
│   └── metadata.json
└── global_pipeline_summary.json

📁 scripts/
├── launch_ml_pipeline.py     # Interface utilisateur
├── test_automated_pipeline.py # Tests
└── start_ml_pipeline.bat     # Lancement rapide
```

## 🚀 Utilisation Rapide

### 1. Lancement via l'interface
```bash
python launch_ml_pipeline.py
```

### 2. Test rapide sur 3 symboles
```bash
python test_automated_pipeline.py
```

### 3. Lancement direct
```bash
python -c "
from backend.automated_ml_pipeline import AutomatedMLPipeline
pipeline = AutomatedMLPipeline()
results = pipeline.run_complete_pipeline('EURUSD')
print(f'Succès: {results.get(\"status\")}')
"
```

## 📊 Fonctionnalités Principales

### 🔍 Analyse Exploratoire (EDA)
- **Statistiques descriptives** complètes
- **Détection des valeurs manquantes** et outliers
- **Analyse des corrélations** entre variables
- **Recommandations automatiques** pour la qualité des données

### 🔧 Engineering des Features
- **Indicateurs techniques** : SMA, EMA, MACD, RSI, Bollinger Bands
- **Features de prix** : retours, ratios, ombres des bougies
- **Features de volume** : VWAP, ratio volume, OBV
- **Features de volatilité** : ATR, True Range, volatilité roulante
- **Features de momentum** : ROC, CCI, accélération

### 🎯 Création de la Target
- **Strong Buy** : >2% sur 5 périodes ET >5% sur 20 périodes
- **Strong Sell** : <-2% sur 5 périodes ET <-5% sur 20 périodes
- **Neutral** : mouvements modérés

### 🏗️ Modèles d'Entraînement
- **Random Forest** : Ensemble d'arbres avec bagging
- **Gradient Boosting** : Boosting séquentiel
- **XGBoost** : Gradient boosting optimisé
- **Logistic Regression** : Régression logistique régularisée
- **SVM** : Machine à vecteurs de support

### ⚙️ Optimisation Automatique
- **Recherche d'hyperparamètres** par Grid Search
- **Validation croisée** 5-fold
- **Sélection du meilleur modèle** basée sur CV score
- **Feature importance** et analyse des performances

## 📈 Paramètres de Trading Calculés

### Strong Buy
- **Stop Loss** : -2.0% (ajusté selon la précision du modèle)
- **Take Profit** : +5.0% (ajusté selon le recall)
- **Durée** : 24h (ajustée selon la confiance)
- **Seuil de confiance** : 0.7 (ajusté selon les performances)

### Strong Sell
- **Stop Loss** : +2.0% (ajusté selon la précision du modèle)
- **Take Profit** : -5.0% (ajusté selon le recall)
- **Durée** : 24h (ajustée selon la confiance)
- **Seuil de confiance** : 0.7 (ajusté selon les performances)

## 🔧 Configuration Avancée

### Modèles
```python
from config.ml_pipeline_config import MODELS_CONFIG

# Ajouter un nouveau modèle
MODELS_CONFIG['neural_network'] = {
    'name': 'Neural Network',
    'params_grid': {
        'hidden_layers': [(50,), (100,), (50, 25)],
        'learning_rate': [0.001, 0.01, 0.1]
    }
}
```

### Features Techniques
```python
from config.ml_pipeline_config import TECHNICAL_FEATURES_CONFIG

# Ajouter de nouveaux indicateurs
TECHNICAL_FEATURES_CONFIG['custom_indicators'] = {
    'ichimoku': True,
    'pivot_points': True,
    'fibonacci_retracements': True
}
```

### Paramètres de Trading
```python
from config.ml_pipeline_config import TRADING_PARAMS_CONFIG

# Ajuster les seuils
TRADING_PARAMS_CONFIG['default_parameters']['Strong Buy']['stop_loss_pct'] = -1.5
TRADING_PARAMS_CONFIG['default_parameters']['Strong Buy']['take_profit_pct'] = 6.0
```

## 📊 Exemple de Sortie

### Résultats d'Entraînement
```json
{
  "symbol": "EURUSD",
  "status": "success",
  "training_results": {
    "best_model_info": {
      "best_model_name": "random_forest",
      "best_performance": {
        "accuracy": 0.847,
        "cv_mean": 0.834,
        "cv_std": 0.023
      }
    },
    "data_info": {
      "train_size": 2400,
      "test_size": 600,
      "feature_count": 45,
      "class_distribution": {
        "Strong Buy": 0.25,
        "Strong Sell": 0.23,
        "Neutral": 0.52
      }
    }
  }
}
```

### Paramètres de Trading
```json
{
  "symbol": "EURUSD",
  "model_loaded": true,
  "model_name": "random_forest",
  "accuracy": 0.847,
  "parameters": {
    "Strong Buy": {
      "stop_loss_pct": -1.6,
      "take_profit_pct": 5.5,
      "signal_duration_hours": 29,
      "confidence_threshold": 0.8
    },
    "Strong Sell": {
      "stop_loss_pct": 1.6,
      "take_profit_pct": -5.5,
      "signal_duration_hours": 29,
      "confidence_threshold": 0.8
    }
  }
}
```

## 🚨 Gestion des Erreurs

### Erreurs Communes
1. **Connexion MT5** : Vérifier que MT5 est ouvert et connecté
2. **Dépendances manquantes** : `pip install scikit-learn pandas numpy ta`
3. **Mémoire insuffisante** : Réduire le nombre de features ou symboles
4. **Données insuffisantes** : Vérifier la disponibilité des données MT5

### Logs et Debugging
```python
import logging
logging.basicConfig(level=logging.DEBUG)

# Voir les logs détaillés
pipeline = AutomatedMLPipeline()
pipeline.run_complete_pipeline('EURUSD')
```

## 📈 Performance et Optimisation

### Temps d'Exécution
- **1 symbole** : ~5-10 minutes
- **10 symboles** : ~1-2 heures
- **Tous les symboles** : ~4-8 heures

### Optimisations
- **Parallélisation** : Utilisation de tous les cœurs CPU
- **Mise en cache** : Sauvegarde des modèles et transformations
- **Feature selection** : Sélection automatique des meilleures features
- **Validation croisée** : Évaluation robuste des performances

## 🔮 Extensions Futures

### Modèles Avancés
- **Deep Learning** : LSTM, GRU pour séries temporelles
- **Ensemble Methods** : Stacking, Voting
- **AutoML** : H2O, AutoKeras

### Features Avancées
- **Sentiment Analysis** : News, tweets, forums
- **Market Microstructure** : Order flow, bid-ask spread
- **Alternative Data** : Satellite, cartes de crédit

### Trading Avancé
- **Portfolio Optimization** : Gestion multi-devises
- **Risk Management** : VaR, Expected Shortfall
- **Execution Algorithms** : TWAP, VWAP, POV

## 📞 Support et Contact

### Documentation
- **Code** : Commentaires détaillés dans chaque fonction
- **Configuration** : Fichiers de config modulaires
- **Tests** : Scripts de test complets

### Développement
- **Modularité** : Architecture extensible
- **Tests** : Couverture complète des fonctionnalités
- **Logs** : Traçabilité complète des opérations

---

## 🎯 Prochaines Étapes

1. **Lancer un test rapide** sur 3 symboles
2. **Analyser un symbole spécifique** (EURUSD recommandé)
3. **Examiner les résultats** dans le dossier `data/`
4. **Ajuster la configuration** selon vos besoins
5. **Lancer l'analyse complète** sur tous les symboles

**🚀 Prêt à révolutionner votre trading avec l'IA !**
