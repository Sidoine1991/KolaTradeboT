# Guide d'utilisation - Trading Algo GUI (Interface Charles Robot)

## 📋 Vue d'ensemble

**Trading_Algo_GUI.mq5** est une interface graphique interactive pour MT5 qui vous permet d'exécuter manuellement les trades selon les signaux du robot Charles, avec calcul automatique du lot size en fonction de votre risque.

## 🎯 Fonctionnalités

### Interface graphique
- **Panneau interactif** affiché sur le graphique MT5
- **Boutons BUY/SELL/WAIT** pour sélectionner le signal
- **Champs d'édition** pour ajuster les paramètres
- **Calcul automatique** du lot size selon le risque %
- **Affichage en temps réel** des TP1, TP2, TP3, TP4 et SL
- **Statistiques** : Risk USD, Reward USD, Ratio Risk/Reward

### Calcul automatique
- **Lot size** calculé automatiquement selon votre risque %
- **TP/SL** calculés automatiquement selon les points configurés
- **Ratio R/R** affiché en temps réel
- **Validation** des paramètres avant exécution

## ⚙️ Installation

### Étape 1 : Copier le fichier
1. Copiez `Trading_Algo_GUI.mq5` dans le dossier `MQL5/Experts/` de votre installation MT5
2. Chemin typique : `C:\Program Files\MetaTrader 5\MQL5\Experts\`

### Étape 2 : Compiler
1. Ouvrez MetaEditor (F4 dans MT5)
2. Ouvrez le fichier `Trading_Algo_GUI.mq5`
3. Cliquez sur **Compiler** (F7)
4. Vérifiez qu'il n'y a pas d'erreurs

### Étape 3 : Attacher au graphique
1. Dans MT5, ouvrez le graphique du symbole souhaité (EURUSD, GBPUSD, etc.)
2. Dans le Navigateur (Ctrl+N), trouvez "Trading_Algo_GUI"
3. Faites un glisser-déposer sur le graphique
4. Activez "Autoriser le trading automatique" dans MT5

## 🎮 Utilisation

### Sélectionner le signal

1. **BUY** : Cliquez sur le bouton 📈 BUY ou appuyez sur **B**
   - Le signal passe à "📈 BUY" (vert)
   - Les TP sont calculés au-dessus du prix actuel
   - Le SL est calculé en dessous du prix actuel

2. **SELL** : Cliquez sur le bouton 📉 SELL ou appuyez sur **S**
   - Le signal passe à "📉 SELL" (rouge)
   - Les TP sont calculés en dessous du prix actuel
   - Le SL est calculé au-dessus du prix actuel

3. **WAIT** : Cliquez sur le bouton ⏳ WAIT ou appuyez sur **W**
   - Le signal passe à "⏳ WAIT" (gris)
   - Aucun trade ne peut être exécuté

### Ajuster le risque

1. Cliquez dans le champ **RISK %**
2. Entrez votre pourcentage de risque (ex: 0.5 pour 0.5%)
3. Le lot size est recalculé automatiquement
4. Les statistiques Risk USD et Reward USD sont mises à jour

**Exemple :**
- Balance : 1000 $
- Risk % : 0.5%
- Risk USD : 5 $
- Lot size calculé automatiquement

### Ajuster les TP/SL

1. Cliquez dans les champs **TP1, TP2, TP3, TP4** ou **SL**
2. Entrez les valeurs en points
3. Les prix correspondants sont affichés à côté
4. Le ratio R/R est recalculé automatiquement

**Points par défaut :**
- TP1 : 50 points
- TP2 : 100 points
- TP3 : 150 points
- TP4 : 200 points
- SL : 30 points

### Exécuter le trade

1. Sélectionnez BUY ou SELL
2. Vérifiez le lot size calculé
3. Vérifiez les TP/SL
4. Cliquez sur **🚀 EXECUTE TRADE** ou appuyez sur **ENTER**
5. Le trade est exécuté avec les paramètres configurés

## 📊 Affichage des informations

### Panneau principal

```
┌─────────────────────────────────────┐
│ 🤖 TRADING ALGO - CHARLES          │
│ SYMBOL: EURUSD                      │
│ SIGNAL: 📈 BUY                      │
│ [📈 BUY] [📉 SELL] [⏳ WAIT]       │
│ ─────────────────────────────────  │
│ RISK %: [0.50]                      │
│ LOT SIZE: 0.03                      │
│ ─────────────────────────────────  │
│ TP1: [50] 1.1650                   │
│ TP2: [100] 1.1700                   │
│ TP3: [150] 1.1750                   │
│ TP4: [200] 1.1800                   │
│ STOP-LOSS: [30] 1.1620              │
│ ─────────────────────────────────  │
│ Risk USD: 5.00                      │
│ Reward USD: 8.33                    │
│ R/R: 1.67                           │
│ [🚀 EXECUTE TRADE]                  │
└─────────────────────────────────────┘
```

### Statistiques

- **Risk USD** : Montant en dollars risqué sur le trade
- **Reward USD** : Gain potentiel en dollars (basé sur TP1)
- **R/R** : Ratio Risk/Reward (Reward / Risk)

## ⌨️ Raccourcis clavier

- **B** : Sélectionner BUY
- **S** : Sélectionner SELL
- **W** : Sélectionner WAIT
- **ENTER** : Exécuter le trade

## 🔧 Paramètres configurables

Dans les paramètres de l'Expert Advisor (F7) :

### Position du panneau
- **InpPanelX** : Position X (par défaut: 20)
- **InpPanelY** : Position Y (par défaut: 20)
- **InpPanelWidth** : Largeur du panneau (par défaut: 280)

### Couleurs
- **InpPanelBgColor** : Couleur de fond (par défaut: Navy)
- **InpPanelTextColor** : Couleur du texte (par défaut: White)
- **InpBuyColor** : Couleur BUY (par défaut: Lime)
- **InpSellColor** : Couleur SELL (par défaut: Red)

### Risque par défaut
- **InpDefaultRiskPercent** : Risque % par défaut (0.5)
- **InpDefaultTP1** : TP1 points par défaut (50)
- **InpDefaultTP2** : TP2 points par défaut (100)
- **InpDefaultTP3** : TP3 points par défaut (150)
- **InpDefaultTP4** : TP4 points par défaut (200)
- **InpDefaultSL** : SL points par défaut (30)

## 🎯 Workflow typique avec Charles Robot

### Scénario 1 : Signal BUY sur EURUSD

1. **Charles dit** : "EURUSD - BUY"
2. **Vous cliquez** sur 📈 BUY dans l'interface
3. **Vous vérifiez** : Lot size calculé (ex: 0.03)
4. **Vous ajustez** : Risk % si nécessaire (ex: 0.5)
5. **Vous vérifiez** : TP1, TP2, TP3, TP4 et SL
6. **Vous cliquez** sur 🚀 EXECUTE TRADE
7. **Trade exécuté** avec les paramètres optimisés

### Scénario 2 : Signal SELL on GBP/AUD

1. **Charles dit** : "GBPAUD - SELL"
2. **Vous cliquez** sur 📉 SELL dans l'interface
3. **Vous vérifiez** : Lot size calculé
4. **Vous ajustez** : TP/SL si nécessaire
5. **Vous cliquez** sur 🚀 EXECUTE TRADE
6. **Trade exécuté** automatiquement

### Scénario 3 : Wait sur BTC/USD

1. **Charles dit** : "BTCUSD - WAIT"
2. **Vous cliquez** sur ⏳ WAIT dans l'interface
3. **Aucun trade** n'est exécuté
4. **Vous attendez** le prochain signal

## ⚠️ Restrictions et validations

### Avant l'exécution
- ✅ Signal doit être BUY ou SELL (pas WAIT)
- ✅ Lot size doit être valide (> 0)
- ✅ Prix actuel doit être disponible
- ✅ SL doit être différent du prix d'entrée

### Après l'exécution
- ✅ Le signal est réinitialisé à WAIT
- ✅ Alert de confirmation affiché
- ✅ Log dans le journal MT5

## 🔍 Dépannage

### Le panneau ne s'affiche pas
- Vérifiez que l'EA est attaché au graphique
- Vérifiez que "Autoriser le trading automatique" est activé
- Vérifiez les coordonnées X/Y dans les paramètres

### Le lot size est 0.01 (minimum)
- Augmentez le risk %
- Vérifiez que la distance SL est suffisante
- Vérifiez la balance du compte

### Le trade ne s'exécute pas
- Vérifiez que le signal est BUY ou SELL
- Vérifiez que vous avez suffisamment de marge
- Vérifiez les logs dans l'onglet "Experts" de MT5

### Invalid TP message
- Vérifiez que TP1 est supérieur à l'entrée pour BUY
- Vérifiez que TP1 est inférieur à l'entrée pour SELL
- Vérifiez que les points sont positifs

## 📚 Comparaison avec votre capture d'écran

Votre capture TikTok montre :
- **Stop-loss** : 1.16487
- **TP1** : 1.17475
- **TP2** : 1.18072
- **TP3** : 1.18697
- **TP4** : 1.18039
- **Risk %** : 0.50
- **Risk USD** : 51.97
- **Reward USD** : 43.90
- **Reward/risk** : 13.04
- **Position size** : 0.03

Notre interface reproduit exactement cette logique :
- ✅ Input Risk %
- ✅ Calcul automatique Position size (lot)
- ✅ Affichage TP1, TP2, TP3, TP4
- ✅ Affichage Stop-loss
- ✅ Calcul Risk USD et Reward USD
- ✅ Affichage Reward/risk ratio

## 🎯 Avantages

1. **Pas d'analyse manuelle** : Charles fait l'analyse, vous exécutez
2. **Calcul automatique** : Lot size calculé selon votre risque
3. **Interface visuelle** : Tous les paramètres visibles en un coup d'œil
4. **Rapidité** : Exécution en quelques clics
5. **Flexibilité** : Ajustez les TP/SL selon vos préférences
6. **Sécurité** : Validations avant exécution

## 🚀 Prochaines améliorations possibles

- Intégration directe avec l'API Charles pour récupérer les signaux automatiquement
- Affichage des signaux Charles en temps réel
- Historique des trades exécutés
- Alertes sonores sur nouveaux signaux
- Multi-symboles dans le même panneau

---

**Note** : Cette interface est conçue pour reproduire exactement le workflow que vous décrivez avec le robot Charles. Vous n'avez plus besoin de "casser votre tête" avec l'analyse manuelle - Charles s'en charge, et vous n'avez qu'à cliquer sur BUY ou SELL selon ses signaux.
