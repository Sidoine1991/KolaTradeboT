# Guide de Monitoring et Vérification du Système d'Apprentissage ML

Ce guide explique comment utiliser les nouveaux outils de monitoring et de vérification pour s'assurer que le système d'apprentissage automatique fonctionne correctement.

## 📊 Endpoints de Monitoring

### 1. Vérifier le Statut de la Base de Données `trade_feedback`

**Endpoint:** `GET /ml/feedback/status`

Vérifie que la base de données est correctement remplie par MT5 et affiche les statistiques.

**Exemple de réponse:**
```json
{
  "status": "ok",
  "db_available": true,
  "statistics": {
    "total_trades": 150,
    "total_wins": 90,
    "total_losses": 60,
    "win_rate": 60.0,
    "total_profit": 250.50,
    "recent_trades_7d": 45,
    "min_samples_for_retraining": 50
  },
  "trades_by_category": {
    "BOOM_CRASH": {
      "count": 75,
      "wins": 45,
      "total_profit": 120.30,
      "ready_for_retraining": true
    },
    "VOLATILITY": {
      "count": 50,
      "wins": 30,
      "total_profit": 80.20,
      "ready_for_retraining": true
    }
  },
  "last_trades": [...],
  "continuous_learning": {
    "available": true,
    "min_samples": 50,
    "retrain_interval_days": 1
  }
}
```

**Comment vérifier:**
```bash
# Via curl
curl http://localhost:8000/ml/feedback/status

# Via navigateur
http://localhost:8000/ml/feedback/status
```

### 2. Voir les Statistiques de Réentraînement

**Endpoint:** `GET /ml/retraining/stats`

Affiche quand chaque modèle a été réentraîné pour la dernière fois.

**Exemple de réponse:**
```json
{
  "status": "ok",
  "config": {
    "min_new_samples": 50,
    "retrain_interval_days": 1
  },
  "retraining_status": {
    "BOOM_CRASH": {
      "last_retrained": "2024-01-15T10:30:00",
      "days_since": 1,
      "hours_since": 24.5,
      "should_retrain": false
    },
    "VOLATILITY": {
      "last_retrained": "2024-01-14T08:15:00",
      "days_since": 2,
      "hours_since": 48.5,
      "should_retrain": true
    }
  }
}
```

### 3. Forcer le Réentraînement Manuel

**Endpoint:** `POST /ml/retraining/trigger`

Permet de déclencher manuellement le réentraînement d'une catégorie ou toutes les catégories.

**Exemple avec catégorie spécifique:**
```bash
curl -X POST "http://localhost:8000/ml/retraining/trigger?category=BOOM_CRASH"
```

**Exemple pour toutes les catégories:**
```bash
curl -X POST "http://localhost:8000/ml/retraining/trigger"
```

**Réponse:**
```json
{
  "status": "ok",
  "category": "BOOM_CRASH",
  "result": {
    "status": "success",
    "old_accuracy": 0.65,
    "new_accuracy": 0.68,
    "improvement": 0.03,
    "samples_used": 75
  }
}
```

## 📈 Logs Améliorés

Le système enregistre maintenant des logs détaillés pour le réentraînement. Surveillez les logs pour voir:

1. **Quand le réentraînement se déclenche automatiquement:**
   ```
   🔄 [AUTO-RETRAIN] Début réentraînement pour BOOM_CRASH...
   ```

2. **Les statistiques des trades utilisés:**
   ```
   ✅ Chargé 75 trades depuis la DB
      📈 Statistiques: 45 wins / 30 losses (Win Rate: 60.0%)
   ```

3. **Les résultats du réentraînement:**
   ```
   ✅ [AUTO-RETRAIN] Réentraînement réussi pour BOOM_CRASH:
      - Échantillons utilisés: 75
      - Précision ancienne: 0.650
      - Précision nouvelle: 0.680
      - Amélioration: +0.030 (3.00%)
   ```

**Comment surveiller les logs:**
```bash
# Si vous utilisez uvicorn
tail -f logs/ai_server.log | grep -E "\[AUTO-RETRAIN\]|RÉ-ENTRAÎNEMENT"

# Ou directement dans la console si le serveur tourne en mode console
```

## ✅ Checklist de Vérification

### 1. Vérifier que la Base de Données est Remplie

1. Appeler `GET /ml/feedback/status`
2. Vérifier que `db_available` est `true`
3. Vérifier que `total_trades > 0`
4. Vérifier que des trades récents apparaissent dans `last_trades`

**Si aucun trade n'apparaît:**
- Vérifier que MT5 envoie bien les feedbacks via `POST /trades/feedback`
- Vérifier la connexion à la base de données PostgreSQL
- Vérifier que le robot MT5 est configuré pour envoyer les résultats

### 2. Surveiller les Logs

1. Vérifier que les logs montrent les feedbacks reçus:
   ```
   📊 Feedback reçu: Volatility 75 Index BUY - Profit: $5.20 ✅ WIN
   ```

2. Vérifier que le réentraînement automatique se déclenche quand il y a assez de trades:
   ```
   🔄 Assez de trades (75) pour réentraîner BOOM_CRASH - Déclenchement en arrière-plan...
   ```

3. Vérifier les résultats du réentraînement dans les logs

### 3. Laisser Tourner le Système

1. **Minimum recommandé:** Laissez le système tourner pendant au moins 7 jours
2. **Objectif:** Accumuler au moins 50 trades par catégorie
3. **Surveillance:** Vérifiez régulièrement `/ml/feedback/status` pour voir la progression

### 4. Vérifier les Améliorations de Précision

1. Appeler régulièrement `GET /ml/retraining/stats` pour voir quand les modèles sont réentraînés
2. Surveiller les logs pour voir les améliorations de précision
3. Vérifier que les modèles sont remplacés uniquement s'ils s'améliorent d'au moins 2%

**Exemple de vérification quotidienne:**
```bash
# Vérifier le statut quotidiennement
curl http://localhost:8000/ml/feedback/status | jq '.statistics'

# Vérifier quand le dernier réentraînement a eu lieu
curl http://localhost:8000/ml/retraining/stats | jq '.retraining_status'
```

## 🔧 Dépannage

### Problème: La base de données est vide

**Solutions:**
1. Vérifier que MT5 envoie les feedbacks correctement
2. Vérifier la configuration `DATABASE_URL`
3. Vérifier que la table `trade_feedback` existe dans PostgreSQL

### Problème: Le réentraînement ne se déclenche jamais

**Solutions:**
1. Vérifier qu'il y a assez de trades (minimum 50)
2. Vérifier que le réentraînement n'a pas eu lieu trop récemment (intervalle de 1 jour)
3. Forcer manuellement avec `POST /ml/retraining/trigger`

### Problème: Les modèles ne s'améliorent pas

**Solutions:**
1. Vérifier que le système utilise bien les vrais résultats (is_win) dans les labels
2. Vérifier que les features sont correctement extraites
3. Augmenter le nombre minimum de trades pour le réentraînement
4. Vérifier que les données sont de bonne qualité

## 📝 Résumé

Le système est maintenant configuré pour:
- ✅ Apprendre automatiquement des résultats réels des trades
- ✅ Se réentraîner automatiquement quand il y a assez de données
- ✅ Logger toutes les opérations pour le monitoring
- ✅ Fournir des endpoints pour vérifier le statut et forcer le réentraînement

**Prochaines étapes:**
1. Vérifier que la base de données est remplie
2. Surveiller les logs pour voir le réentraînement automatique
3. Laisser tourner pendant plusieurs jours
4. Vérifier les améliorations de précision
