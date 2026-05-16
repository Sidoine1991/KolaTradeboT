# 🤖 TRADING AUTOMATIQUE - SCANNER AVEC AUTO-TRADING

## 🎯 Vue d'ensemble

Le module de **trading automatique** s'intègre au scanner pour placer **automatiquement** des ordres sur les meilleures opportunités détectées. Parfait pour un **petit capital** (10$) avec gestion **scalping** et **trailing stop**.

## ✨ Fonctionnalités

### 🎯 Trading Intelligent
- ✅ Place des ordres **automatiquement** sur opportunités PERFECT et GOOD
- ✅ **Calcul du lot** adapté au risque (max 50 cents par trade pour capital 10$)
- ✅ **Scalping** avec TP/SL ajustables
- ✅ **Trailing stop** automatique pour maximiser les gains
- ✅ **1 position max** par symbole, **3 positions max** au total

### 📊 Gestion du Risque
- ✅ Risque **maximum par trade** configurable (défaut: 0.50$)
- ✅ Calcul **automatique du lot** basé sur la distance SL
- ✅ Respect des **limites broker** (min/max lot)
- ✅ **Throttle** entre trades (120 secondes minimum)
- ✅ Vérification des **marges** disponibles

### 📱 Notifications Push
- ✅ Notification à chaque **ouverture de position**
- ✅ **Rapport périodique** (toutes les 10 minutes)
- ✅ Statistiques: **Trades totaux, Win/Loss, Win Rate, P/L net**
- ✅ État des **positions ouvertes** avec P/L en temps réel

## ⚙️ Configuration

### Paramètres dans SMC_Universal

```mql5
[TRADING AUTOMATIQUE (SCANNER)]
EnableScannerAutoTrading = false      // true = Activer le trading auto
AutoTradeMaxRiskDollars = 0.50        // Risque max par trade ($)
AutoTradeScalpTpPoints = 50           // Take Profit (points)
AutoTradeScalpSlPoints = 30           // Stop Loss (points)
EnableAutoTrailingStop = true         // Activer trailing stop
AutoTrailingStopPoints = 20           // Distance trailing (points)
AutoTrailingStepPoints = 5            // Pas de déplacement (points)
AutoTradeNotifyIntervalMin = 10       // Intervalle notifications (minutes)
```

### Configuration Recommandée

#### Pour Capital 10$ (Micro-Compte)
```mql5
EnableScannerAutoTrading = true
AutoTradeMaxRiskDollars = 0.50        // 5% du capital
AutoTradeScalpTpPoints = 50           // TP: 50 points
AutoTradeScalpSlPoints = 30           // SL: 30 points
EnableAutoTrailingStop = true
AutoTrailingStopPoints = 20           // Trail: 20 points
AutoTrailingStepPoints = 5            // Step: 5 points
```

#### Pour Capital 50$ (Petit Compte)
```mql5
EnableScannerAutoTrading = true
AutoTradeMaxRiskDollars = 2.00        // 4% du capital
AutoTradeScalpTpPoints = 80
AutoTradeScalpSlPoints = 50
EnableAutoTrailingStop = true
AutoTrailingStopPoints = 30
AutoTrailingStepPoints = 10
```

#### Pour Capital 100$ (Compte Standard)
```mql5
EnableScannerAutoTrading = true
AutoTradeMaxRiskDollars = 5.00        // 5% du capital
AutoTradeScalpTpPoints = 100
AutoTradeScalpSlPoints = 60
EnableAutoTrailingStop = true
AutoTrailingStopPoints = 40
AutoTrailingStepPoints = 10
```

## 🚀 Utilisation

### 1. Activation

1. **Ouvrir** plusieurs graphiques (symboles à trader)
2. **Attacher** SMC_Universal sur chaque graphique
3. Sur **UN graphique**, activer:
   ```
   EnableOpportunityScanner = true
   EnableScannerAutoTrading = true
   ```
4. **Configurer** le risque et les paramètres de scalping
5. **OK** → Le robot commence à scanner et trader automatiquement

### 2. Vérification

Après activation, vous devriez voir dans l'onglet **Experts** (MT5):
```
✅ Scanner multi-symboles initialisé - Boom 1000 Index,Crash 1000 Index,...
✅ Trading automatique activé - Risque: $0.50 TP:50pts SL:30pts
```

### 3. Trading Automatique

Le robot va:
1. **Scanner** les opportunités toutes les 2 secondes
2. **Filtrer** uniquement PERFECT et GOOD (+ spike ≥50% pour GOOD)
3. **Calculer** le lot size optimal (risque max respecté)
4. **Placer** l'ordre automatiquement (BUY ou SELL)
5. **Gérer** le trailing stop en temps réel
6. **Notifier** chaque action

### 4. Notifications Push

#### À l'ouverture d'une position
```
✅ TRADE OUVERT: Boom 1000 Index BUY 0.02 lots @ 2845.32
(SL:2815.32 TP:2895.32)
```

#### Rapport périodique (toutes les 10 min)
```
📊 SCANNER AUTO-TRADING
━━━━━━━━━━━━━━━━━━━━
⏰ 2026-05-14 15:30

📈 Trades: 5 (W:3 L:2)
✅ Win Rate: 60.0%
💰 Profit Net: $2.45

📊 Positions Ouvertes: 2
  Boom 1000 Index BUY: $1.20
  Crash 1000 Index SELL: $0.85

💵 P/L Total: $2.05

━━━━━━━━━━━━━━━━━━━━
```

## 📊 Logique de Trading

### Sélection des Opportunités

Le robot trade **automatiquement** si:
1. ✅ Qualité = **PERFECT** (toujours)
2. ✅ Qualité = **GOOD** + Spike ≥ 50% (haute probabilité)
3. ❌ Qualité = **FAIR** (ignoré, trop risqué)

### Calcul du Lot Size

```
Formula:
Lot = (Risque $ Max / Distance SL en points) / Tick Value

Exemple (Capital 10$, Risque 0.50$):
- Prix entrée: 2845.32
- SL: 2815.32
- Distance: 30 points
- Risque par point: 0.50 / 30 = 0.0166$
- Lot calculé: 0.02 lots (normalisé)
```

Le lot est toujours:
- ≥ **Lot minimum** broker (ex: 0.01)
- ≤ **Lot maximum** configuré (0.10)
- **Arrondi** au step broker (ex: 0.01)

### Gestion du Trailing Stop

#### Comment ça marche?

```
Position BUY @ 2845.32, SL initial: 2815.32

Prix monte à 2865.32:
→ Nouveau SL = 2865.32 - 20pts = 2845.32 (BE)

Prix monte à 2885.32:
→ Nouveau SL = 2885.32 - 20pts = 2865.32 (+20pts profit sécurisé)

Prix monte à 2905.32:
→ Nouveau SL = 2905.32 - 20pts = 2885.32 (+40pts profit sécurisé)
```

Le SL ne **descend jamais**, seulement **monte** pour sécuriser les profits.

### Limites de Sécurité

#### 1. Max Positions
- **1 position max** par symbole (évite surexposition)
- **3 positions max** au total (diversification)

#### 2. Throttle Temps
- **120 secondes minimum** entre 2 trades sur le même symbole
- Évite le **overtrading**

#### 3. Opportunité Unique
- Chaque opportunité n'est tradée qu'**une seule fois**
- Évite les **doublons** (même symbole, direction, prix)

## 💡 Stratégie de Scalping

### Objectif
**Petits gains fréquents** avec gestion stricte du risque.

### Paramètres Optimaux

| Capital | Risque/Trade | TP | SL | Trail | Objectif/Jour |
|---------|--------------|----|----|-------|---------------|
| 10$ | 0.50$ (5%) | 50pts | 30pts | 20pts | +1-2$ |
| 50$ | 2.00$ (4%) | 80pts | 50pts | 30pts | +5-10$ |
| 100$ | 5.00$ (5%) | 100pts | 60pts | 40pts | +10-20$ |

### Ratio Risk/Reward
```
TP: 50 points
SL: 30 points
R/R = 1.67:1

Avec Win Rate 55%:
- 100 trades
- 55 gagnants: 55 × 50pts = +2750pts
- 45 perdants: 45 × 30pts = -1350pts
- Net: +1400pts = +14 lots profit
```

## 📈 Statistiques

### Métriques Suivies
- **Total Trades**: Nombre de trades ouverts
- **Winning Trades**: Nombre de trades gagnants
- **Losing Trades**: Nombre de trades perdants
- **Win Rate**: % de trades gagnants
- **Total Profit**: Somme des gains ($)
- **Total Loss**: Somme des pertes ($)
- **Net Profit**: Profit total - Perte totale ($)

### Analyse Performance

#### Bon Performance
```
Win Rate: ≥ 55%
Net Profit: Positif
Ratio W/L: ≥ 1.2
```

#### Performance à Améliorer
```
Win Rate: < 50%
Net Profit: Négatif ou stagnant
Ratio W/L: < 1.0
```

**Action:** Ajuster les paramètres ou désactiver temporairement.

## 🛡️ Sécurité

### Protections Intégrées

1. **Calcul Lot Sécurisé**
   - Jamais plus que le risque configuré
   - Respect des limites broker

2. **Vérification Marge**
   - Vérifie la marge disponible avant trade
   - Bloque si marge insuffisante

3. **Throttle Trading**
   - Minimum 2 minutes entre trades
   - Évite l'overtrading

4. **Filtrage Qualité**
   - Seulement PERFECT et GOOD (spike ≥50%)
   - Pas de trade sur FAIR

5. **Trailing Stop**
   - Sécurise les profits automatiquement
   - Ne descend jamais, seulement monte

## 🔧 Dépannage

### Aucun trade automatique
✓ Vérifier `EnableScannerAutoTrading = true`
✓ Vérifier que les symboles sont scannés
✓ Vérifier les opportunités (doivent être PERFECT/GOOD)
✓ Vérifier la marge disponible
✓ Consulter l'onglet **Experts** pour les messages

### Lot size trop petit
→ Le risque configuré est trop faible
→ Augmenter `AutoTradeMaxRiskDollars` (ex: 0.50 → 1.00)

### Trop de trades simultanés
→ Limites configurées (1/symbole, 3 total)
→ Normal, c'est la sécurité

### Pas de notification
✓ Activer les notifications dans MT5 (Outils → Options → Notifications)
✓ Vérifier `EnableAutoTrailingStop = true` dans les inputs
✓ Attendre 10 minutes pour le rapport périodique

### Trailing stop ne bouge pas
→ Le prix doit monter d'au moins `AutoTrailingStepPoints` (5pts par défaut)
→ Normal, évite les modifications trop fréquentes

## 📊 Exemple Complet

### Configuration
```mql5
EnableOpportunityScanner = true
ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index"
EnableScannerAutoTrading = true
AutoTradeMaxRiskDollars = 0.50
AutoTradeScalpTpPoints = 50
AutoTradeScalpSlPoints = 30
EnableAutoTrailingStop = true
```

### Scénario

**15:00** - Scanner détecte opportunité PERFECT BUY sur Boom 1000 @ 2845.32
```
✅ TRADE OUVERT: Boom 1000 Index BUY 0.02 lots @ 2845.32
(SL:2815.32 TP:2895.32)
```

**15:05** - Prix monte à 2865.32
```
📊 Trailing Stop: Boom 1000 Index nouveau SL: 2845.32 (BE)
```

**15:08** - Prix monte à 2885.32
```
📊 Trailing Stop: Boom 1000 Index nouveau SL: 2865.32 (+20pts)
```

**15:10** - Rapport périodique
```
📊 SCANNER AUTO-TRADING
━━━━━━━━━━━━━━━━━━━━
Trades: 1 (W:0 L:0)
Positions Ouvertes: 1
  Boom 1000 Index BUY: $0.80
```

**15:15** - Prix atteint TP @ 2895.32
```
✅ Position fermée: +$1.00 (50 points × 0.02 lots)
```

## 🎓 Conseils

### Pour Débutants
1. Commencer avec **EnableScannerAutoTrading = false**
2. Observer le scanner pendant **1-2 jours**
3. Activer avec **capital minimum** (10$)
4. Risque **conservateur** (0.50$ max)

### Pour Intermédiaires
1. Capital 50-100$
2. Risque 2-5$ par trade
3. Diversifier sur 5-8 symboles
4. Analyser les stats quotidiennes

### Pour Avancés
1. Optimiser les paramètres TP/SL selon symboles
2. Ajuster le trailing selon volatilité
3. Combiner avec analyse manuelle
4. Tester en démo avant le réel

## ⚠️ Avertissements

- ⚠️ Le trading comporte des **risques de perte**
- ⚠️ Ne tradez que l'argent que vous pouvez **perdre**
- ⚠️ Testez d'abord en **compte démo**
- ⚠️ Surveillez régulièrement les **positions**
- ⚠️ Ajustez les paramètres selon **vos résultats**

---

**Développé par TradBOT SMC** - Trading Automatique Intelligent
**Version:** 1.0
**Date:** 2026-05-14
