# 🚀 SPIKE HUNTER EA - Mode Agressif

## 📋 Vue d'ensemble

Le **SpikeHunter EA** en mode agressif est configuré pour prendre des positions automatiquement dès qu'il détecte des opportunités, sans limitation stricte. Il est optimisé pour réagir rapidement aux signaux de votre application locale.

## 🎯 Configuration Agressive

### ⚡ Paramètres Optimisés pour la Réactivité

```
=== CONFIGURATION BOOM/CRASH ===
InpMaxTrades = 50                 // 50 trades simultanés maximum
InpBaseLotSize = 0.01             // Taille de base des lots
InpMaxLotSize = 2.0               // Taille maximum des lots (augmenté)
InpStopLoss = 20                  // Stop Loss réduit (20 points)
InpTakeProfit = 40                // Take Profit réduit (40 points)

=== DÉTECTION DE SPIKE ===
InpSpikeDetectionPeriod = 5       // Période réduite (5)
InpSpikeThreshold = 0.1           // Seuil très sensible (0.1%)
InpReversalDetection = 3          // Détection rapide (3)
InpReversalThreshold = 0.1        // Seuil très sensible (0.1%)

=== GESTION DES LOTS ===
InpUseMartingale = true           // Martingale activé
InpMartingaleMultiplier = 1.3     // Multiplicateur modéré (1.3)
InpRecoveryFactor = 0.9           // Facteur de récupération élevé (0.9)
InpMaxConsecutiveLosses = 10      // 10 pertes consécutives max

=== TRAILING STOP ===
InpTrailingStart = 10             // Démarrage rapide (10 points)
InpTrailingStep = 3               // Pas réduit (3 points)

=== CONNEXION APPLICATION ===
InpAppURL = "http://localhost:8503" // URL de votre app
InpCheckInterval = 1              // Vérification chaque seconde
InpUseAppSignals = true           // Utiliser les signaux de l'app
```

## 🔥 Fonctionnalités Agressives

### 1. **Détection Ultra-Sensible**
- **Seuil de spike** : 0.1% (très sensible)
- **Vérification** : Toutes les secondes
- **Réaction** : Immédiate (2 secondes max entre trades)

### 2. **Trading Multi-Positions**
- **Maximum** : 50 trades simultanés
- **Ouverture** : Multiple trades par signal
- **Martingale** : +2 trades par perte consécutive

### 3. **Gestion des Lots Dynamique**
- **Taille de base** : 0.01 lot
- **Maximum** : 2.0 lots
- **Compensation** : Automatique des pertes
- **Récupération** : 90% du ratio perte/profit

### 4. **Connexion Application Locale**
- **URL** : http://localhost:8503
- **Vérification** : Chaque seconde
- **Signaux** : Intégration automatique
- **Réaction** : Immédiate aux signaux

## 📊 Stratégie de Trading

### 🎯 **Logique d'Ouverture**
1. **Détection de spike** ≥ 0.1%
2. **Signal de l'application** locale
3. **Ouverture immédiate** de position
4. **Multi-positions** si pertes consécutives

### 💰 **Gestion des Lots**
- **1ère perte** : 0.01 lot
- **2ème perte** : 0.013 lot (1.3x)
- **3ème perte** : 0.017 lot (1.3²x)
- **4ème perte** : 0.022 lot (1.3³x)
- **Et ainsi de suite...**

### 🛡️ **Protection**
- **Stop Loss** : 20 points
- **Take Profit** : 40 points
- **Trailing Stop** : Démarre à 10 points
- **Marge** : 95% maximum utilisée

## 🚀 Installation et Utilisation

### 1. **Installation**
```bash
# Copiez le fichier dans MetaTrader 5
MetaTrader 5/MQL5/Experts/SpikeHunter_EA.mq5

# Compilez dans MetaEditor (F7)
# Redémarrez MetaTrader 5
```

### 2. **Configuration**
1. **Ouvrez** un graphique Boom ou Crash
2. **Attachez** l'EA SpikeHunter
3. **Configurez** les paramètres agressifs
4. **Activez** le trading automatique
5. **Vérifiez** que votre app locale fonctionne

### 3. **Surveillance**
- **Panneau de performance** : Temps réel
- **Alertes sonores** : Chaque action
- **Logs** : Onglet "Experts"
- **Statistiques** : Affichage continu

## ⚠️ Gestion des Risques

### 🛡️ **Sécurités Intégrées**
- **Limite de trades** : 50 maximum
- **Limite de pertes** : 10 consécutives max
- **Vérification de marge** : 95% max
- **Taille de lot** : 2.0 lots maximum

### 📊 **Monitoring**
- **Trades actifs** : Affichage en temps réel
- **Profit/Perte** : Calcul automatique
- **Taux de réussite** : Mise à jour continue
- **Alertes** : Sonores et visuelles

## 🔧 Dépannage

### ❌ **Problèmes Courants**

#### Robot ne prend pas de positions
- **Vérifiez** : `InpEnableTrading = true`
- **Vérifiez** : Marge disponible
- **Vérifiez** : Seuils de détection
- **Vérifiez** : Connexion à l'app locale

#### Trop de positions ouvertes
- **Réduisez** : `InpMaxTrades`
- **Ajustez** : `InpMaxConsecutiveLosses`
- **Vérifiez** : Gestion de la marge

#### Pas de signaux de l'app
- **Vérifiez** : URL de l'application
- **Vérifiez** : Port 8503 ouvert
- **Vérifiez** : `InpUseAppSignals = true`

## 📈 Optimisations

### 🎯 **Pour Plus de Réactivité**
1. **Réduisez** `InpSpikeThreshold` à 0.05%
2. **Réduisez** `InpCheckInterval` à 0.5 secondes
3. **Augmentez** `InpMaxTrades` à 100
4. **Réduisez** `InpStopLoss` à 15 points

### 💰 **Pour Plus de Profit**
1. **Augmentez** `InpTakeProfit` à 60 points
2. **Réduisez** `InpMartingaleMultiplier` à 1.2
3. **Augmentez** `InpRecoveryFactor` à 0.95
4. **Optimisez** les seuils selon la volatilité

## 🎵 Fichiers Sonores

Placez ces fichiers dans `MetaTrader 5/Sounds/` :
```
alert.wav          // Alerte générale
trade_open.wav     // Trade ouvert
trade_close.wav    // Trade fermé
profit.wav         // Profit réalisé
loss.wav           // Perte réalisée
```

## 📞 Support

### 🔍 **Vérifications**
1. **Logs** : Onglet "Experts" dans MT5
2. **Panneau** : Affichage des statistiques
3. **Application** : Vérifiez localhost:8503
4. **Marge** : Vérifiez la disponibilité

### ⚡ **Performance**
- **Réactivité** : < 1 seconde
- **Détection** : 0.1% de changement
- **Ouverture** : Immédiate
- **Gestion** : Automatique

---

**⚠️ AVERTISSEMENT** : Le mode agressif comporte des risques élevés. Testez toujours sur un compte démo avant d'utiliser sur un compte réel. Surveillez attentivement les pertes consécutives et la marge disponible.

**🎯 OBJECTIF** : Le robot est conçu pour être libre de prendre des positions dès qu'il détecte des opportunités, sans limitation artificielle du nombre de trades par jour.
