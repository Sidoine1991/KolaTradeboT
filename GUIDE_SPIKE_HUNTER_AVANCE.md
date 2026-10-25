# 🚀 SPIKE HUNTER EA - Guide d'Utilisation Avancé

## 📋 Vue d'ensemble

Le **SpikeHunter EA** est un robot de trading automatique spécialement conçu pour capturer les spikes (pics de prix) sur les indices Boom et Crash. Il intègre une gestion avancée des lots avec compensation des pertes et un panneau de performance en temps réel.

## 🎯 Fonctionnalités Principales

### ✅ Trading Automatique
- **Détection automatique des spikes** sur Boom/Crash
- **Ouverture automatique des positions** BUY/SELL
- **Gestion automatique des lots** avec stratégie Martingale
- **Compensation des pertes** par ajustement des lots

### 📊 Panneau de Performance
- **Affichage en temps réel** sur le graphique MT5
- **Statistiques complètes** : trades, profits, taux de réussite
- **Gestion des risques** : pertes consécutives, marge
- **Alertes visuelles** et sonores

### 🔊 Alertes Sonores
- **Spike détecté** : `alert.wav`
- **Trade ouvert** : `trade_open.wav`
- **Trade fermé** : `trade_close.wav`
- **Profit** : `profit.wav`
- **Perte** : `loss.wav`

## ⚙️ Configuration des Paramètres

### 🔧 Configuration Générale
```
InpEnableTrading = true          // Activer le trading
InpTimeframe = PERIOD_M1         // Timeframe d'analyse
InpMagicNumber = 123456          // Magic Number unique
```

### 📈 Configuration Boom/Crash
```
InpTradeBoom = true              // Trader Boom Index
InpTradeCrash = true             // Trader Crash Index
InpMaxTrades = 5                 // Nombre max de trades simultanés
InpBaseLotSize = 0.01            // Taille de base des lots
InpMaxLotSize = 1.0              // Taille maximum des lots
InpStopLoss = 30                 // Stop Loss en points
InpTakeProfit = 50               // Take Profit en points
```

### 🎯 Détection de Spike
```
InpSpikeDetectionPeriod = 10     // Période de détection
InpSpikeThreshold = 0.3          // Seuil de spike (%)
InpReversalDetection = 5         // Période d'inversion
InpReversalThreshold = 0.2       // Seuil d'inversion (%)
```

### 💰 Gestion des Lots (Martingale)
```
InpUseMartingale = true          // Utiliser la stratégie Martingale
InpMartingaleMultiplier = 1.5    // Multiplicateur Martingale
InpRecoveryFactor = 0.8          // Facteur de récupération
InpMaxConsecutiveLosses = 3      // Max pertes consécutives
```

### 🎵 Interface Graphique
```
InpShowDashboard = true          // Afficher le panneau de performance
InpPlaySounds = true             // Activer les alertes sonores
InpSoundFile = "alert.wav"       // Fichier son par défaut
```

## 📱 Panneau de Performance

Le panneau affiche en temps réel :

### 🟢 Statut du Trading
- **Statut** : ACTIF/INACTIF
- **Symbol** : Symbole tradé
- **Timeframe** : Période d'analyse

### 📊 Trades Actifs
- **Nombre de trades** : X/5
- **Profit actuel** : $X.XX
- **Lot actuel** : X.XX

### 📈 Performance
- **Total Trades** : Nombre total
- **Trades gagnants** : Nombre de gains
- **Trades perdants** : Nombre de pertes
- **Taux de réussite** : X.X%
- **Profit total** : $X.XX
- **Profit max** : $X.XX
- **Perte max** : $X.XX

### ⚠️ Gestion des Risques
- **Pertes consécutives** : X
- **Martingale** : OUI/NON
- **Multiplicateur** : X.X

### 💳 Compte
- **Balance** : $X.XX
- **Equity** : $X.XX
- **Marge libre** : $X.XX

### 🔔 Dernière Alerte
- **Type** : Spike/Trade/Profit/Perte
- **Détails** : Informations spécifiques

## 🎵 Fichiers Sonores

Placez les fichiers sonores dans le dossier `Sounds` de MetaTrader 5 :

```
MetaTrader 5/Sounds/
├── alert.wav          // Alerte générale
├── trade_open.wav     // Trade ouvert
├── trade_close.wav    // Trade fermé
├── profit.wav         // Profit réalisé
└── loss.wav           // Perte réalisée
```

## 🚀 Installation et Utilisation

### 1. Installation
1. **Copiez** `SpikeHunter_EA.mq5` dans `MetaTrader 5/MQL5/Experts/`
2. **Compilez** le fichier dans MetaEditor (F7)
3. **Redémarrez** MetaTrader 5

### 2. Configuration
1. **Ouvrez** un graphique Boom ou Crash
2. **Attachez** l'EA SpikeHunter
3. **Configurez** les paramètres selon vos besoins
4. **Activez** le trading automatique

### 3. Surveillance
1. **Vérifiez** le panneau de performance
2. **Écoutez** les alertes sonores
3. **Surveillez** les logs dans l'onglet "Experts"

## ⚠️ Gestion des Risques

### 🛡️ Sécurités Intégrées
- **Limite de trades** : Maximum 5 trades simultanés
- **Limite de pertes** : Arrêt après 3 pertes consécutives
- **Vérification de marge** : 90% de marge libre maximum
- **Taille de lot** : Limite à 1.0 lot maximum

### 📊 Stratégie Martingale
- **Multiplicateur** : 1.5x par perte consécutive
- **Récupération** : Ajustement selon le ratio perte/profit
- **Reset** : Retour à la taille de base après profit

## 🔧 Dépannage

### ❌ Problèmes Courants

#### EA disparaît du graphique
- **Cause** : Erreur de compilation
- **Solution** : Vérifiez les logs dans MetaEditor

#### Pas de trades ouverts
- **Cause** : Trading désactivé ou marge insuffisante
- **Solution** : Vérifiez `InpEnableTrading` et la marge

#### Pas d'alertes sonores
- **Cause** : Fichiers sonores manquants
- **Solution** : Placez les fichiers .wav dans le dossier Sounds

#### Panneau non affiché
- **Cause** : `InpShowDashboard = false`
- **Solution** : Activez l'affichage du panneau

### 📝 Logs et Monitoring
- **Onglet Experts** : Logs détaillés
- **Panneau de performance** : Statistiques temps réel
- **Alertes sonores** : Notifications audio

## 📞 Support

Pour toute question ou problème :
1. **Vérifiez** les logs dans l'onglet "Experts"
2. **Consultez** ce guide
3. **Testez** d'abord sur un compte démo

## 🎯 Conseils d'Optimisation

### 📈 Pour de Meilleurs Résultats
1. **Testez** sur compte démo d'abord
2. **Ajustez** les seuils selon la volatilité
3. **Surveillez** les pertes consécutives
4. **Utilisez** des lots appropriés à votre capital
5. **Activez** les alertes sonores pour surveillance

### ⚡ Optimisations Avancées
- **Timeframe** : M1 pour réactivité maximale
- **Seuils** : Ajustez selon la volatilité du marché
- **Martingale** : Utilisez avec prudence
- **Stop Loss** : Protégez votre capital

---

**⚠️ AVERTISSEMENT** : Le trading automatique comporte des risques. Testez toujours sur un compte démo avant d'utiliser sur un compte réel. Les performances passées ne garantissent pas les résultats futurs.
