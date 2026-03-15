# Tables Supabase - Guide d'utilisation

## 📊 Tables disponibles dans Supabase

### 1. **training_runs** - ✅ Maintenant utilisée
- **Purpose**: Enregistrer les sessions d'entraînement des modèles ML
- **Utilisation**: Logguée automatiquement par `integrated_ml_trainer.py`
- **Fréquence**: À chaque entraînement de modèle
- **Champs clés**:
  - `symbol`, `timeframe`, `status`, `samples_used`
  - `accuracy`, `f1_score`, `duration_sec`
  - `metadata` (model_type, features_used, category)

### 2. **feature_importance** - ✅ Maintenant utilisée
- **Purpose**: Tracker l'importance des features par modèle
- **Utilisation**: Logguée automatiquement après chaque entraînement
- **Fréquence**: À chaque entraînement avec feature importance
- **Champs clés**:
  - `symbol`, `timeframe`, `model_type`, `training_run_id`
  - `feature_name`, `importance`, `rank`

### 3. **symbol_calibration** - ✅ Maintenant utilisée
- **Purpose**: Calibration et performance par symbole
- **Utilisation**: Logguée automatiquement par `integrated_ml_trainer.py`
- **Fréquence**: À chaque entraînement de modèle
- **Champs clés**:
  - `symbol`, `timeframe`, `wins`, `total`
  - `drift_factor`, `last_updated`
  - `metadata` (model_type, accuracy, category)

### 4. **symbol_correction_patterns** - ✅ Maintenant utilisée
- **Purpose**: Patterns de correction par symbole
- **Utilisation**: Via `symbol_patterns_logger.py`
- **Fréquence**: Quand des patterns sont détectés
- **Champs clés**:
  - `symbol`, `pattern_type`, `avg_retracement_percentage`
  - `typical_duration_bars`, `success_rate`
  - `best_timeframes`, `occurrences_count`

### 5. **correction_summary_stats** - ✅ Maintenant utilisée
- **Purpose**: Statistiques résumées des corrections
- **Utilisation**: Via `symbol_patterns_logger.py`
- **Fréquence**: Périodique (hebdomadaire/mensuel)
- **Champs clés**:
  - `symbol`, `timeframe`, `period_start`, `period_end`
  - `total_corrections`, `successful_predictions`
  - `avg_retracement_pct`, `success_rate`
  - `dominant_pattern`, `metadata`

### 6. **support_resistance_levels** - ✅ Déjà utilisée
- **Purpose**: Niveaux de support/résistance
- **Utilisation**: Via `update_support_resistance.py`
- **Fréquence**: Régulière (chaque heure)
- **Champs clés**:
  - `symbol`, `support`, `resistance`
  - `timeframe`, `strength_score`, `touch_count`

## 🔧 Modifications apportées

### 1. **integrated_ml_trainer.py**
- ✅ Amélioré `_log_training_run()` pour logging systématique
- ✅ Ajouté `_log_feature_importance()` pour tracker les features
- ✅ Ajouté `_log_symbol_calibration()` pour la calibration
- ✅ Ajouté `_log_training_metrics()` pour orchestrer tous les logs
- ✅ Intégré le logging Supabase après chaque entraînement

### 2. **ai_server_supabase.py**
- ✅ Désactivé `SIMPLIFIED_MODE = False` pour activer toutes les fonctionnalités
- ✅ Ajouté import de `symbol_patterns_logger`
- ✅ Messages de log améliorés pour indiquer l'utilisation des tables

### 3. **symbol_patterns_logger.py** (Nouveau)
- ✅ Module complet pour logger les patterns de correction
- ✅ Fonctions pour `symbol_correction_patterns` et `correction_summary_stats`
- ✅ Intégration facile dans l'AI server

### 4. **test_supabase_tables.py** (Nouveau)
- ✅ Script de test complet pour toutes les tables
- ✅ Vérifie insertion, lecture et nettoyage
- ✅ Utile pour diagnostiquer les problèmes

## 🚀 Comment ça fonctionne maintenant

### Flow d'entraînement ML complet:
1. **Entraînement du modèle** → `integrated_ml_trainer.py`
2. **Logging automatique** dans toutes les tables:
   - `training_runs` (session d'entraînement)
   - `feature_importance` (importance des features)
   - `symbol_calibration` (calibration du symbole)
3. **Patterns de correction** → `symbol_patterns_logger.py`
4. **Support/Résistance** → `update_support_resistance.py` (déjà existant)

### Logs dans l'AI server:
```
✅ Training run logged: Boom 500 Index M1
✅ Feature importance logged: 12 features for Boom 500 Index
✅ Symbol calibration logged: Boom 500 Index
✅ All training metrics logged to Supabase: Boom 500 Index
✅ Correction pattern logged: Boom 500 Index - mean_reversion
✅ Correction summary logged: Boom 500 Index M1
```

## 📈 Avantages

1. **Traçabilité complète**: Tous les entraînements sont loggués
2. **Analyse des performances**: Feature importance et calibration par symbole
3. **Détection de patterns**: Patterns de correction automatiquement identifiés
4. **Historique**: Données conservées pour analyse future
5. **Monitoring**: Métriques détaillées pour optimiser les modèles

## 🔍 Vérification

Pour tester que tout fonctionne:

```bash
python test_supabase_tables.py
```

Ce script testera toutes les tables et affichera:
- ✅ Insertion réussie
- ✅ Lecture réussie  
- ✅ Nettoyage réussie

## 📝 Prochaines améliorations

1. **Dashboard web**: Interface pour visualiser les données
2. **Alertes**: Notifications quand la performance dégrade
3. **Auto-optimisation**: Ajustement automatique des paramètres
4. **Export**: Export des données pour analyse externe

## 🎯 Résultat

**Avant**: Seule `support_resistance_levels` était utilisée
**Après**: **Toutes les 6 tables sont maintenant utilisées** automatiquement par l'AI server!

L'AI server loggue maintenant systématiquement:
- Les entraînements de modèles
- L'importance des features
- La calibration des symboles
- Les patterns de correction
- Les statistiques résumées
- Les niveaux de support/résistance

Le système est maintenant **complètement intégré** avec Supabase! 🎉
