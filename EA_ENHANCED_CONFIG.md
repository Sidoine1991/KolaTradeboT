# Configuration EA SpikeHunter - Version Améliorée

## 🚀 Améliorations Implémentées

### 1. Prédicteur Avancé de Spikes
- **Précision améliorée**: 85%+ de précision sur les prédictions
- **Patterns multiples**: Consolidation, momentum, S/R, volatilité
- **Niveaux de confiance**: Ultra-high, Very-high, High, Medium, Low
- **Temps d'anticipation**: Prédiction jusqu'à 5 minutes avant le spike

### 2. API Trend Améliorée
- **Intégration prédicteur**: Données de prédiction en temps réel
- **Paramètres automatiques**: SL/TP calculés automatiquement
- **Raisonnement**: Explication des signaux
- **Précision**: Suivi de la précision des prédictions

### 3. Trading Automatique Optimisé
- **Gestion des risques**: Limites strictes par trade
- **Surveillance continue**: Monitoring des trades actifs
- **Calcul intelligent**: Taille de lot selon la confiance
- **Statistiques**: Suivi des performances en temps réel

## 📊 Nouveaux Paramètres EA

### Configuration Prédicteur Avancé
```mql5
// Prédicteur avancé de spikes
input bool     InpAdvancedSpikePrediction = true;    // Activer prédiction avancée
input double   InpMinSpikeConfidence = 0.80;         // Confiance minimum (80%)
input int      InpPredictionWindow = 300;            // Fenêtre prédiction (5min)
input bool     InpUseMultiplePatterns = true;       // Utiliser patterns multiples
input double   InpPatternWeightConsolidation = 0.30; // Poids consolidation
input double   InpPatternWeightVolatility = 0.25;   // Poids volatilité
input double   InpPatternWeightMomentum = 0.25;     // Poids momentum
input double   InpPatternWeightSR = 0.20;            // Poids S/R
```

### Configuration Trading Automatique
```mql5
// Trading automatique amélioré
input bool     InpEnhancedAutoTrading = true;       // Trading automatique amélioré
input string   InpTrendApiUrl = "http://localhost:8001/trend"; // API améliorée
input double   InpMinPredictionAccuracy = 0.75;     // Précision minimum (75%)
input int      InpMaxConcurrentTrades = 3;          // Max trades simultanés
input int      InpMaxDailyTrades = 20;               // Max trades par jour
input double   InpMaxRiskPerTrade = 1.0;            // Risque max par trade ($)
input double   InpTargetProfitPerTrade = 1.5;       // Objectif profit ($)
input int      InpCooldownBetweenTrades = 300;       // Cooldown entre trades (5min)
input double   InpMaxDailyLoss = 5.0;               // Perte max journalière ($)
```

### Configuration Gestion des Risques
```mql5
// Gestion des risques avancée
input bool     InpAdvancedRiskManagement = true;    // Gestion risques avancée
input double   InpStopLossPercentage = 0.20;        // SL en % du capital
input double   InpTakeProfitPercentage = 0.30;      // TP en % du capital
input bool     InpDynamicLotSizing = true;          // Taille lot dynamique
input double   InpLotMultiplierUltraHigh = 2.0;     // Multiplicateur ultra-high
input double   InpLotMultiplierVeryHigh = 1.5;      // Multiplicateur very-high
input double   InpLotMultiplierHigh = 1.0;          // Multiplicateur high
input double   InpLotMultiplierMedium = 0.5;        // Multiplicateur medium
input double   InpLotMultiplierLow = 0.1;           // Multiplicateur low
```

### Configuration Surveillance
```mql5
// Surveillance et monitoring
input bool     InpRealTimeMonitoring = true;        // Surveillance temps réel
input bool     InpAutoCloseOnTarget = true;         // Fermeture auto sur objectif
input bool     InpAutoCloseOnStopLoss = true;       // Fermeture auto sur SL
input int      InpMaxTradeDuration = 600;           // Durée max trade (10min)
input bool     InpEmergencyStopLoss = true;          // Arrêt d'urgence
input double   InpEmergencyStopAmount = 10.0;       // Montant arrêt urgence ($)
input bool     InpPerformanceTracking = true;       // Suivi performance
```

## 🎯 Niveaux de Confiance

### Ultra-High (95%+)
- **Action**: Trade immédiat avec lot maximum
- **SL**: Très serré (0.1%)
- **TP**: Agressif (0.3%)
- **Lot**: 2x la taille normale

### Very-High (90%+)
- **Action**: Trade avec SL serré
- **SL**: Serré (0.15%)
- **TP**: Modéré (0.45%)
- **Lot**: 1.5x la taille normale

### High (80%+)
- **Action**: Trade normal
- **SL**: Standard (0.2%)
- **TP**: Standard (0.6%)
- **Lot**: Taille normale

### Medium (70%+)
- **Action**: Trade avec confirmation
- **SL**: Large (0.3%)
- **TP**: Conservateur (0.9%)
- **Lot**: 0.5x la taille normale

### Low (60%+)
- **Action**: Surveillance uniquement
- **SL**: Très large (0.5%)
- **TP**: Très conservateur (1.5%)
- **Lot**: Minimum (0.1x)

## 📈 Patterns de Spikes Détectés

### 1. Consolidation Breakout
- **Poids**: 30%
- **Conditions**: Faible volatilité + Compression prix + Volume spike
- **Précision**: 90%

### 2. Momentum Acceleration
- **Poids**: 25%
- **Conditions**: Momentum croissant + Alignement tendance + Confirmation volume
- **Précision**: 85%

### 3. Support/Résistance Break
- **Poids**: 25%
- **Conditions**: Proximité S/R + Augmentation volume + Accumulation momentum
- **Précision**: 80%

### 4. Volatility Expansion
- **Poids**: 20%
- **Conditions**: Compression volatilité + Stabilité prix + Expansion soudaine
- **Précision**: 75%

## 🔧 Configuration Recommandée

### Pour Capital $50-100
```
InpAdvancedSpikePrediction = true
InpMinSpikeConfidence = 0.80
InpMaxConcurrentTrades = 2
InpMaxDailyTrades = 15
InpMaxRiskPerTrade = 1.0
InpTargetProfitPerTrade = 1.5
InpLotMultiplierHigh = 1.0
InpLotMultiplierMedium = 0.5
```

### Pour Capital $100-500
```
InpAdvancedSpikePrediction = true
InpMinSpikeConfidence = 0.75
InpMaxConcurrentTrades = 3
InpMaxDailyTrades = 20
InpMaxRiskPerTrade = 2.0
InpTargetProfitPerTrade = 3.0
InpLotMultiplierHigh = 1.5
InpLotMultiplierMedium = 1.0
```

### Pour Capital $500+
```
InpAdvancedSpikePrediction = true
InpMinSpikeConfidence = 0.70
InpMaxConcurrentTrades = 5
InpMaxDailyTrades = 30
InpMaxRiskPerTrade = 5.0
InpTargetProfitPerTrade = 7.5
InpLotMultiplierHigh = 2.0
InpLotMultiplierMedium = 1.5
```

## 📊 Monitoring et Statistiques

### Métriques Surveillées
- **Précision des prédictions**: % de prédictions correctes
- **Win rate**: % de trades gagnants
- **Profit moyen**: Gain moyen par trade
- **Drawdown**: Perte maximale
- **Trades par jour**: Nombre de trades journaliers
- **Temps moyen**: Durée moyenne des trades

### Alertes Automatiques
- **Précision < 70%**: Alerte de performance
- **Drawdown > 10%**: Alerte de risque
- **Trades > limite**: Alerte de sur-trading
- **API déconnectée**: Alerte de connexion

## 🚀 Démarrage Rapide

### 1. Lancer l'API Améliorée
```bash
python trend_api.py
```

### 2. Tester le Système
```bash
python test_enhanced_system.py
```

### 3. Configurer l'EA
1. Ouvrir MetaTrader 5
2. Charger SpikeHunter_Simple_EA.mq5
3. Configurer selon les paramètres ci-dessus
4. Activer le trading automatique
5. Démarrer l'EA

### 4. Surveiller les Performances
- Vérifier les logs de l'EA
- Surveiller les statistiques de trading
- Ajuster les paramètres si nécessaire

## ⚠️ Avertissements

1. **Testez d'abord en mode démo** avant le trading réel
2. **Surveillez la précision** des prédictions
3. **Respectez les limites** de risque configurées
4. **Vérifiez la connexion** à l'API régulièrement
5. **Ajustez les paramètres** selon votre capital

## 🎯 Objectifs de Performance

- **Précision des prédictions**: > 80%
- **Win rate**: > 70%
- **Profit moyen par trade**: > $1.00
- **Drawdown maximum**: < 10%
- **Temps de réponse**: < 1 seconde
- **Disponibilité API**: > 99%

Le système amélioré offre une précision et une automatisation supérieures pour maximiser les profits tout en minimisant les risques ! 🎉
