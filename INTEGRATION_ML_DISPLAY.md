# Intégration ML Display - Guide Complet

## 🎯 **Objectif**

Afficher sur le graphique MT5 les **vraies métriques ML** depuis Supabase :
- Niveau d'entraînement des données
- Accuracy et F1 Score réels
- Top 5 des features les plus importantes
- Calibration et drift factor
- Réponse ML en temps réel

## 📁 **Fichiers créés**

### 1. **backend/api/ml_metrics.py**
- **Endpoint API** : `/api/ml/metrics/{symbol}`
- **Récupère depuis Supabase** :
  - Dernier training run (accuracy, F1, samples, model)
  - Top 5 features importance
  - Calibration (drift factor, win rate)
  - Dernière réponse ML

### 2. **ML_Display_Enhanced.mq5**
- **Panneau ML complet** sur le graphique MT5
- **Mise à jour automatique** toutes les 60 secondes
- **Affichage détaillé** avec couleurs et icônes

## 🔧 **Intégration dans l'API existante**

### Modifier `backend/api/main.py` :

```python
# Importer le module ML Metrics
try:
    from backend.api.ml_metrics import router as ml_metrics_router
    ML_METRICS_AVAILABLE = True
except ImportError:
    ML_METRICS_AVAILABLE = False
    print("⚠️ Module ML Metrics non disponible")

# Inclure le router
if ML_METRICS_AVAILABLE:
    app.include_router(ml_metrics_router, prefix="/api/ml", tags=["ML Metrics"])
    print("✅ Router ML Metrics inclus")
```

## 📊 **Fonctionnalités du panneau ML**

### 🎯 **Niveau d'entraînement**
- 🔴 DÉBUTANT (< 100 samples)
- 🟡 INTERMÉDIAIRE (100-500 samples)
- 🟢 AVANCÉ (500-1000 samples)
- 🔵 EXPERT (> 1000 samples)

### 📈 **Métriques de performance**
- **Accuracy** : Précision du modèle (en %)
- **F1 Score** : Score F1 (en %)
- **Samples** : Nombre d'échantillons utilisés
- **Model Type** : Type de modèle (Random Forest, XGBoost...)

### 🔥 **Top 5 Features**
- **Feature Name** : Nom de la feature
- **Importance** : Pourcentage d'importance
- **Classement** : Ordre par importance

### ⚖️ **Calibration**
- **Drift Factor** : Facteur de dérive (0.000 - 1.000)
- **Win Rate** : Taux de réussite (en %)
- **Trades** : Nombre de trades wins/total

### 🧠 **Réponse ML en temps réel**
- **Signal** : BUY/SELL/HOLD
- **Confidence** : Confiance (en %)
- **Timestamp** : Heure de la dernière prédiction

## 🎨 **Configuration du panneau**

### Inputs MT5 :
- `ShowMLMetricsPanel` : Activer/désactiver le panneau
- `ShowMLTrainingLevel` : Afficher le niveau d'entraînement
- `ShowMLAccuracy` : Afficher accuracy et F1
- `ShowMLFeatures` : Afficher les features importantes
- `ShowMLCalibration` : Afficher la calibration
- `ShowMLResponse` : Afficher la réponse ML
- `MLPanelBackColor` : Couleur de fond
- `MLPanelTextColor` : Couleur du texte
- `MLPanelFontSize` : Taille de police
- `MLPanelWidth/Height` : Dimensions du panneau

### Codes couleur automatiques :
- **Accuracy** : Vert (≥80%), Jaune (60-80%), Rouge (<60%)
- **Drift Factor** : Vert (<0.1), Jaune (0.1-0.3), Rouge (>0.3)
- **Prediction** : Vert (BUY), Rouge (SELL), Jaune (HOLD)

## 🚀 **Installation et utilisation**

### 1. **Intégrer l'API**
```bash
# Ajouter le router ML Metrics dans main.py
# Redémarrer le serveur API
python backend/api/main.py
```

### 2. **Compiler l'indicateur MT5**
```bash
# Copier ML_Display_Enhanced.mq5 dans le dossier Indicators MT5
# Compiler depuis MetaEditor
# Ajouter au graphique
```

### 3. **Configurer l'URL**
```mq5
// Dans ML_Display_Enhanced.mq5, modifier si nécessaire :
string g_mlMetricsURL = "http://localhost:8000/api/ml/metrics/";
```

## 📡 **Endpoints API disponibles**

### GET `/api/ml/metrics/{symbol}`
```json
{
  "symbol": "Boom 500 Index",
  "timeframe": "M1",
  "last_training": {
    "status": "completed",
    "accuracy": 0.85,
    "f1_score": 0.82,
    "samples_used": 1250,
    "duration_sec": 120,
    "model_type": "random_forest",
    "created_at": "2026-03-15T15:30:00Z",
    "training_level": "🔵 EXPERT"
  },
  "top_features": [
    {"name": "rsi", "importance": 0.25, "rank": 1},
    {"name": "atr", "importance": 0.18, "rank": 2},
    {"name": "ema_diff_m1", "importance": 0.15, "rank": 3},
    {"name": "volume_ratio", "importance": 0.12, "rank": 4},
    {"name": "price_change_pct", "importance": 0.08, "rank": 5}
  ],
  "calibration": {
    "drift_factor": 0.125,
    "wins": 85,
    "total": 100,
    "win_rate": 85.0,
    "last_updated": "2026-03-15T15:30:00Z"
  },
  "ml_response": {
    "confidence": 0.78,
    "prediction": "BUY",
    "timestamp": "2026-03-15T16:25:00Z"
  }
}
```

### GET `/api/ml/training-status/{symbol}`
```json
{
  "status": "ok",
  "symbol": "Boom 500 Index",
  "training_level": "🔵 EXPERT",
  "accuracy": 0.85,
  "model_type": "random_forest",
  "last_updated": "2026-03-15T15:30:00Z"
}
```

## 🔄 **Mise à jour automatique**

### Fréquences :
- **API MT5** : Toutes les 60 secondes
- **Cache API** : Éviter les appels excessifs
- **Panneau graphique** : Redessiné à chaque tick

### Gestion d'erreurs :
- **Timeout API** : 10 secondes
- **Erreur HTTP** : Log et affichage "EN ATTENTE"
- **JSON invalide** : Parsing sécurisé avec fallback

## 🎯 **Résultat visuel**

Le panneau ML affiche en temps réel :

```
╔════════════════════════════════════════════════════════════╗
║ 🤖 MÉTRIQUES ML - Boom 500 Index                        ║
╠════════════════════════════════════════════════════════════╣
║ 🎯 NIVEAU: 🔵 EXPERT                                    ║
║ 📊 Précision: 85.0% | F1: 82.0%                    ║
║ 📚 Samples: 1250 | Modèle: random_forest                 ║
║                                                         ║
║ 🔥 TOP FEATURES:                                         ║
║    rsi: 25.0%                                          ║
║    atr: 18.0%                                          ║
║    ema_diff_m1: 15.0%                                  ║
║    volume_ratio: 12.0%                                  ║
║    price_change_pct: 8.0%                               ║
║                                                         ║
║ ⚖️ CALIBRATION:                                         ║
║    Drift: 0.125 | Win Rate: 85.0%                     ║
║    Trades: 85/100                                        ║
║                                                         ║
║ 🧠 RÉPONSE ML:                                          ║
║    Signal: BUY | Conf: 78.0%                           ║
║    Dernière: 16:25:00                                   ║
╚════════════════════════════════════════════════════════════╝
```

## 🎉 **Avantages**

1. **Visibilité totale** : Toutes les métriques ML en un coup d'œil
2. **Temps réel** : Mises à jour automatiques depuis Supabase
3. **Personnalisable** : Configuration complète des couleurs et affichage
4. **Performance optimisée** : Cache et fréquences contrôlées
5. **Robuste** : Gestion d'erreurs et fallbacks
6. **Intégration facile** : Simple à ajouter à l'API existante

Le système affiche maintenant les **vraies métriques ML** sur le graphique MT5 avec une interface complète et professionnelle ! 🚀
