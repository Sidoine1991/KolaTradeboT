# Guide du Système de Performance MT5 - SpikeHunter EA

## 📊 Vue d'ensemble

Le système de performance intégré dans le SpikeHunter EA calcule automatiquement un score de performance synthétique basé sur vos paramètres de trading. Ce système vous permet de mesurer et suivre l'évolution de votre robot de trading en temps réel.

## 🎯 Formule du Score de Performance

Le score de performance est calculé selon la formule suivante :

```
Score = 100 × (0.4 × ROE + 0.3 × Win Rate + 0.3 × Profit Factor normalisé)
```

Où :
- **ROE (Return on Equity)** : Rendement sur capital = (Équité actuelle - Capital initial) / Capital initial
- **Win Rate** : Taux de réussite = Trades gagnants / Total des trades
- **Profit Factor normalisé** : Profit Factor / (1 + Profit Factor)

## ⚙️ Configuration

### Paramètres d'entrée

Dans les paramètres de l'EA, vous trouverez le groupe **"CALCUL DE PERFORMANCE"** :

- **`InpEnablePerformanceTracking`** : Activer/désactiver le suivi de performance
- **`InpInitialCapital`** : Capital initial pour le calcul du ROE (défaut: 1000.0)
- **`InpShowPerformancePanel`** : Afficher le panneau de performance sur le graphique
- **`InpPerformanceUpdateMinutes`** : Fréquence de mise à jour en minutes (défaut: 5)
- **`InpExportPerformanceData`** : Exporter les données en CSV
- **`InpPerformanceFilePath`** : Chemin du fichier d'export (défaut: "performance_data.csv")

## 📈 Fonctionnalités

### 1. Calcul Automatique
- Mise à jour automatique toutes les X minutes
- Calcul en temps réel des métriques de performance
- Historique des 365 derniers jours

### 2. Panneau de Performance
Le panneau affiche en temps réel :
- Score de performance actuel
- ROE moyen sur 7 jours
- Win Rate moyen sur 7 jours
- Profit total sur 7 jours
- Tendance (Amélioration/Dégradation/Stable)

### 3. Export des Données
Les données sont exportées en CSV avec les colonnes :
- Date
- Équité
- Trades gagnants
- Trades perdants
- Profit journalier
- Perte journalière
- Profit net
- ROE
- Win Rate
- Profit Factor
- Score de performance

### 4. Analyse de Tendance
Le système détermine automatiquement si votre robot :
- 🟢 **S'améliore** : Score récent > Score ancien + 2 points
- 🔴 **Se dégrade** : Score récent < Score ancien - 2 points
- 🟡 **Stable** : Variation entre -2 et +2 points

## 🚀 Utilisation

### 1. Activation
1. Ouvrez les paramètres de l'EA
2. Activez `InpEnablePerformanceTracking = true`
3. Définissez votre `InpInitialCapital`
4. Activez `InpShowPerformancePanel = true` pour voir le panneau

### 2. Surveillance
- Le panneau de performance s'affiche en haut à gauche du graphique
- Les données sont mises à jour automatiquement
- Consultez les logs pour les détails des calculs

### 3. Export des Données
- Les données sont automatiquement exportées si `InpExportPerformanceData = true`
- Le fichier CSV est créé dans le dossier `Files` de MT5
- Vous pouvez analyser les données avec Excel ou Python

## 📊 Interprétation des Scores

### Échelle de Performance
- **80-100** : 🟢 Excellent - Robot très performant
- **60-79** : 🟡 Bon - Robot performant avec quelques améliorations possibles
- **40-59** : 🟠 Correct - Robot acceptable mais nécessite des optimisations
- **0-39** : 🔴 Faible - Robot nécessite des corrections majeures

### Métriques Clés
- **ROE > 0.1 (10%)** : Bon rendement sur capital
- **Win Rate > 0.6 (60%)** : Bon taux de réussite
- **Profit Factor > 1.5** : Bon rapport gains/pertes

## 🔧 Personnalisation

### Modifier la Formule
Pour modifier les pondérations dans la formule, éditez la fonction `CalculatePerformanceScore()` :

```mql5
// Score pondéré : 40% ROE + 30% Win Rate + 30% Profit Factor normalisé
double score = 100.0 * (0.4 * roe + 0.3 * win_rate + 0.3 * pf_normalized);
```

### Ajuster la Fréquence
Modifiez `InpPerformanceUpdateMinutes` pour changer la fréquence de mise à jour :
- **1 minute** : Mise à jour très fréquente (plus de calculs)
- **5 minutes** : Équilibré (recommandé)
- **15 minutes** : Moins fréquent (moins de calculs)

## 📝 Exemple d'Utilisation

### Configuration Recommandée
```
InpEnablePerformanceTracking = true
InpInitialCapital = 1000.0
InpShowPerformancePanel = true
InpPerformanceUpdateMinutes = 5
InpExportPerformanceData = true
InpPerformanceFilePath = "spikehunter_performance.csv"
```

### Résultat Attendu
```
PERFORMANCE (7j): Score: 65.2 | ROE: 8.45% | Win Rate: 68.5% | Profit: $45.30 | 🟢 Amélioration
```

## 🐛 Dépannage

### Problèmes Courants

1. **Panneau non affiché**
   - Vérifiez que `InpShowPerformancePanel = true`
   - Redémarrez l'EA

2. **Données non exportées**
   - Vérifiez que `InpExportPerformanceData = true`
   - Vérifiez les permissions d'écriture dans le dossier Files

3. **Score toujours à 0**
   - Vérifiez que `InpInitialCapital` est correct
   - Vérifiez que l'EA a des trades à analyser

### Logs de Debug
Les logs affichent les détails des calculs :
```
📊 PERFORMANCE UPDATE - Score: 65.20 | ROE: 8.45% | Win Rate: 68.50% | Profit Factor: 2.15 | Trades: 5W/2L
```

## 📚 Intégration avec Python

Vous pouvez analyser les données exportées avec le script Python fourni :

```python
# Charger les données
import pandas as pd
df = pd.read_csv('performance_data.csv')

# Analyser la performance
print(f"Score moyen: {df['PerformanceScore'].mean():.2f}")
print(f"ROE moyen: {df['ROE'].mean()*100:.2f}%")
print(f"Win Rate moyen: {df['WinRate'].mean()*100:.1f}%")
```

## 🎯 Objectifs de Performance

### Objectifs Recommandés
- **Score de performance** : > 60
- **ROE mensuel** : > 5%
- **Win Rate** : > 60%
- **Profit Factor** : > 1.5
- **Tendance** : Stable ou Amélioration

### Optimisation Continue
1. Surveillez le score quotidiennement
2. Identifiez les périodes de dégradation
3. Ajustez les paramètres de trading si nécessaire
4. Analysez les patterns dans les données exportées

---

**Note** : Ce système de performance est conçu pour vous aider à optimiser votre robot de trading. Utilisez-le comme un outil d'aide à la décision, pas comme une garantie de performance future.
