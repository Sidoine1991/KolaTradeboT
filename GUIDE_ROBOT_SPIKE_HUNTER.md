# Guide du Robot SpikeHunter EA

## 🤖 Robot de Trading Automatique pour Boom/Crash Index

### 📋 Description

Le **SpikeHunter EA** est un robot de trading MQL5 spécialement conçu pour capturer les spikes sur les indices Boom et Crash. Il utilise une stratégie de **trailing market position differential** pour détecter les inversions et placer des ordres avant les spikes.

## 🎯 Fonctionnalités Principales

### ✅ Détection Automatique de Spikes
- **Détection en temps réel** des mouvements de prix importants
- **Seuil configurable** pour la sensibilité de détection
- **Analyse multi-timeframe** pour une meilleure précision

### ✅ Trading Automatique
- **Ouverture automatique** d'ordres dans la direction du spike
- **Gestion des positions** avec Stop Loss et Take Profit
- **Trailing Stop** pour maximiser les profits
- **Limite du nombre de trades** simultanés

### ✅ Notifications en Temps Réel
- **Alertes MetaTrader** pour chaque action
- **Support Webhook** pour notifications externes
- **Intégration avec TradBOT** pour notifications SMS/WhatsApp

## 📁 Fichiers Inclus

```
mt5/
├── SpikeHunter_EA.mq5          # Expert Advisor principal
├── SpikeDetector.mq5           # Indicateur de détection de spikes
└── SpikeHunter_Template.tpl    # Template de graphique
```

## 🚀 Installation

### 1. Installation des Fichiers

1. **Copiez les fichiers** dans les dossiers appropriés de MetaTrader 5 :
   - `SpikeHunter_EA.mq5` → `MQL5/Experts/`
   - `SpikeDetector.mq5` → `MQL5/Indicators/`

2. **Compilez les fichiers** dans MetaEditor :
   - Ouvrez MetaEditor
   - Ouvrez `SpikeHunter_EA.mq5`
   - Cliquez sur "Compile" (F7)
   - Répétez pour `SpikeDetector.mq5`

### 2. Installation du Template

1. **Copiez le template** :
   - `SpikeHunter_Template.tpl` → `MQL5/Profiles/Templates/`

2. **Appliquez le template** :
   - Ouvrez MetaTrader 5
   - Allez sur "Fichier" → "Ouvrir le modèle"
   - Sélectionnez "SpikeHunter_Template.tpl"

## ⚙️ Configuration

### Paramètres Généraux

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `InpEnableTrading` | Activer le trading | `true` |
| `InpTimeframe` | Timeframe d'analyse | `PERIOD_M1` |
| `InpMagicNumber` | Magic Number | `123456` |

### Configuration Boom/Crash

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `InpTradeBoom` | Trader Boom Index | `true` |
| `InpTradeCrash` | Trader Crash Index | `true` |
| `InpMaxTrades` | Nombre max de trades | `3` |
| `InpLotSize` | Taille des lots | `0.01` |
| `InpStopLoss` | Stop Loss (points) | `50` |
| `InpTakeProfit` | Take Profit (points) | `150` |

### Détection de Spike

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `InpSpikeDetectionPeriod` | Période de détection | `20` |
| `InpSpikeThreshold` | Seuil de spike (%) | `0.5` |
| `InpReversalDetection` | Période d'inversion | `10` |
| `InpReversalThreshold` | Seuil d'inversion (%) | `0.3` |

### Trailing Stop

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `InpUseTrailing` | Utiliser trailing stop | `true` |
| `InpTrailingStart` | Distance de démarrage | `30` |
| `InpTrailingStep` | Pas du trailing | `10` |

## 🎮 Utilisation

### 1. Lancement du Robot

1. **Ouvrez un graphique** Boom 1000 Index ou Crash 500 Index
2. **Appliquez le template** SpikeHunter
3. **Glissez-déposez** l'EA sur le graphique
4. **Configurez les paramètres** selon vos besoins
5. **Activez le trading** en cochant "Autoriser le trading automatique"

### 2. Configuration des Paramètres

#### Pour Boom Index :
- `InpTradeBoom = true`
- `InpTradeCrash = false`
- Direction : **BUY** uniquement

#### Pour Crash Index :
- `InpTradeBoom = false`
- `InpTradeCrash = true`
- Direction : **SELL** uniquement

#### Pour les deux :
- `InpTradeBoom = true`
- `InpTradeCrash = true`
- Direction : **BUY** et **SELL**

### 3. Monitoring

Le robot affiche en temps réel :
- **Nombre de trades actifs**
- **Profit total**
- **Détection de spikes**
- **Signaux d'inversion**

## 📊 Stratégie de Trading

### 1. Détection de Spike

Le robot utilise plusieurs indicateurs pour détecter les spikes :

- **Changement de prix** par rapport à la moyenne mobile
- **Volatilité** calculée sur la période
- **Momentum** pour confirmer la direction
- **Pattern recognition** pour les formations de spikes

### 2. Ouverture des Positions

- **Boom Index** : Achat lors de spike haussier
- **Crash Index** : Vente lors de spike baissier
- **Timing** : Ouverture immédiate avant le spike
- **Gestion** : Stop Loss et Take Profit automatiques

### 3. Gestion des Positions

- **Trailing Stop** : Suit le prix favorable
- **Fermeture automatique** : À la fin du spike
- **Limite de trades** : Évite le sur-trading
- **Gestion du risque** : Stop Loss obligatoire

## 🔧 Personnalisation

### Modification des Seuils

```mql5
// Augmenter la sensibilité
InpSpikeThreshold = 0.3;  // Plus sensible
InpReversalThreshold = 0.2;

// Réduire la sensibilité
InpSpikeThreshold = 0.8;  // Moins sensible
InpReversalThreshold = 0.5;
```

### Ajustement des Lots

```mql5
// Trading conservateur
InpLotSize = 0.01;
InpMaxTrades = 1;

// Trading agressif
InpLotSize = 0.05;
InpMaxTrades = 5;
```

### Configuration des Stops

```mql5
// Stops serrés
InpStopLoss = 30;
InpTakeProfit = 90;

// Stops larges
InpStopLoss = 100;
InpTakeProfit = 300;
```

## 📱 Notifications

### 1. Notifications MetaTrader

- **Alertes sonores** pour chaque action
- **Messages** dans le journal
- **Notifications push** sur mobile

### 2. Intégration TradBOT

Le robot peut envoyer des notifications via le service unifié :

```mql5
// Dans le code de l'EA
if(InpSendNotifications) {
    SendNotification("Spike détecté sur " + _Symbol);
}
```

### 3. Webhook Support

```mql5
// Configuration webhook
InpWebhookURL = "https://votre-webhook.com/notify";
```

## 🚨 Gestion des Risques

### 1. Paramètres de Sécurité

- **Stop Loss obligatoire** sur chaque trade
- **Limite du nombre de trades** simultanés
- **Vérification des marges** avant ouverture
- **Gestion des erreurs** robuste

### 2. Monitoring

- **Surveillance continue** des positions
- **Alertes** en cas de problème
- **Logs détaillés** pour l'analyse
- **Statistiques** de performance

### 3. Recommandations

- **Testez d'abord** sur un compte démo
- **Commencez petit** avec des lots réduits
- **Surveillez** les performances
- **Ajustez** les paramètres selon les résultats

## 📈 Optimisation

### 1. Backtesting

1. **Ouvrez Strategy Tester**
2. **Sélectionnez** SpikeHunter_EA
3. **Configurez** la période de test
4. **Lancez** le test
5. **Analysez** les résultats

### 2. Optimisation des Paramètres

1. **Utilisez** l'optimisation génétique
2. **Testez** différentes combinaisons
3. **Validez** sur données hors échantillon
4. **Implémentez** les meilleurs paramètres

### 3. Monitoring en Temps Réel

- **Surveillez** les performances
- **Ajustez** les paramètres si nécessaire
- **Documentez** les changements
- **Analysez** les patterns de marché

## 🐛 Dépannage

### Problèmes Courants

1. **Robot ne trade pas** :
   - Vérifiez `InpEnableTrading = true`
   - Vérifiez les autorisations de trading
   - Vérifiez la connexion au serveur

2. **Pas de détection de spikes** :
   - Ajustez `InpSpikeThreshold`
   - Vérifiez la période de détection
   - Vérifiez les données de prix

3. **Trades non fermés** :
   - Vérifiez les niveaux de Stop Loss
   - Vérifiez la logique de trailing stop
   - Vérifiez les erreurs dans le journal

### Logs et Debugging

- **Journal MetaTrader** : `Ctrl+Shift+J`
- **Logs de l'EA** : Dans l'onglet "Experts"
- **Debug** : Activez les messages de debug

## 📞 Support

### Ressources

- **Documentation MQL5** : https://www.mql5.com/en/docs
- **Forum MetaTrader** : https://www.mql5.com/en/forum
- **TradBOT Support** : Via le service de notifications

### Contact

Pour toute question ou problème :
- **Email** : support@tradbot.com
- **Discord** : TradBOT Community
- **GitHub** : https://github.com/tradbot/spikehunter

## 🎉 Conclusion

Le **SpikeHunter EA** est un robot de trading puissant et flexible pour capturer les spikes sur les indices Boom et Crash. Avec sa détection avancée et sa gestion automatique des positions, il offre une solution complète pour le trading automatique.

**Bonne chance avec votre trading !** 🚀

---

*Développé par l'équipe TradBOT - 2025*
