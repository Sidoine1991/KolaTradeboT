# Modifications apportées à fx_robot2.mq5

## Objectif principal
Permettre au robot d'analyser plusieurs symboles sans avoir besoin d'être attaché à chaque graphique individuellement.

## Modifications apportées

### 1. Refactoring de la gestion du risque
- **Remplacement de `ManageTrailing` par `ManageLowVolatilityRisk`**
  - Implémente la gestion du risque avec un gain minimum de 1$ avant fermeture
  - Calcule dynamiquement SL et TP selon les ratios 20% perte / 80% profit
  - Gère le trailing stop adaptatif

- **Ajout de `CalculateLowVolatilitySLTP`**
  - Calcule SL/TP basés sur le risque du compte (20% de perte, 80% de profit)
  - Utilise le solde du compte et la taille de position pour déterminer les niveaux
  - Normalise les prix selon les digits du symbole

### 2. Analyse multi-symboles
- **Refactoring de `AnalyzeSymbol`**
  - Ne change plus de graphique dynamiquement
  - Utilise les fonctions qui acceptent un paramètre `symbol`
  - Analyse chaque symbole indépendamment

- **Ajout de fonctions spécifiques par symbole**
  - `IsPrioritySymbol(string symbol)` - Vérifie si un symbole est dans la liste de surveillance
  - `IsSpikeDetectedForSymbol(string symbol, ...)` - Détection de spikes pour un symbole spécifique
  - `ComputeVPINForSymbol(string symbol, ...)` - Calcul VPIN pour un symbole spécifique
  - `ComputeOBIForSymbol(string symbol, ...)` - Calcul OBI pour un symbole spécifique
  - `ComputeCVDForSymbol(string symbol, ...)` - Calcul CVD pour un symbole spécifique

### 3. Intégration dans les fonctions principales
- **Modification de `OnTimer`**
  - Ajout de l'appel à `ManageLowVolatilityRisk()` pour la gestion du risque
  - Maintient l'analyse multi-symboles via la boucle sur `g_symbolsToWatch`

- **Simplification de `OnTick`**
  - Concentré sur l'analyse multi-symboles
  - Appel à `ManageLowVolatilityRisk()` pour la gestion du risque
  - Mise à jour du panneau de performance

### 4. Nouveaux paramètres d'entrée
```mql5
input double InpMinProfitDollars = 1.0;        // Gain minimum avant fermeture
input double InpStopLossPercent = 20.0;        // Pourcentage de perte (20%)
input double InpTakeProfitPercent = 80.0;       // Pourcentage de profit (80%)
input bool   InpEnableAutoClose = true;          // Activer fermeture automatique
input double InpMaxRiskPercent = 2.0;           // Risque maximum par trade
input int    InpMaxConcurrentTrades = 1;        // Trades simultanés maximum
```

### 5. Nettoyage du code
- Suppression du code résiduel et dupliqué
- Simplification des fonctions principales
- Amélioration de la lisibilité et maintenabilité

## Fonctionnement

### Gestion du risque
1. **Gain minimum**: Le robot attend un gain minimum de 1$ avant de fermer une position
2. **SL/TP dynamiques**: Calculés selon 20% de risque et 80% de profit par rapport au solde du compte
3. **Trailing stop**: Ajuste automatiquement le SL lorsque le prix évolue favorablement

### Analyse multi-symboles
1. **Surveillance continue**: Le robot analyse tous les symboles dans `g_symbolsToWatch`
2. **Détection de spikes**: Chaque symbole est analysé pour détecter les spikes de prix
3. **Exécution automatique**: Place des ordres selon les signaux détectés

## Utilisation

1. **Configuration**: Définir les symboles à surveiller dans `g_symbolsToWatch`
2. **Paramètres**: Ajuster les paramètres de risque selon votre stratégie
3. **Installation**: Attacher l'EA à un seul graphique (n'importe lequel)
4. **Surveillance**: L'EA analysera automatiquement tous les symboles configurés

## Avantages

- **Multi-symboles**: Un seul EA pour plusieurs symboles
- **Gestion du risque améliorée**: SL/TP calculés dynamiquement
- **Gain minimum garanti**: Fermeture automatique après 1$ de profit
- **Trailing stop intelligent**: Protège les gains tout en laissant courir les profits

## Tests

Un script de test `test_multi_symbol.mq5` est disponible pour vérifier:
- L'accès aux données de plusieurs symboles
- La détection de spikes sur chaque symbole
- Le calcul des indicateurs (VPIN, OBI, CVD)

## Notes

- Le robot doit être attaché à au moins un graphique pour fonctionner
- Les symboles doivent être disponibles dans le Market Watch
- Les paramètres de risque peuvent être ajustés selon votre tolérance
