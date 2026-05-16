# ⚡ TRADING AUTOMATIQUE - DÉMARRAGE RAPIDE

## 🎯 En 5 Minutes

### Étape 1: Compiler (1 minute)

1. **Ouvrir MetaEditor** (F4 dans MT5)
2. **Compiler** SMC_Universal.mq5 (F7)
3. Vérifier: `0 errors` ✅

**Nouveaux fichiers ajoutés:**
- ✅ SMC_AutoTrader.mqh (18 KB) - Module trading auto
- ✅ SMC_OpportunityScanner.mqh (29 KB) - Scanner mis à jour

### Étape 2: Configuration (2 minutes)

1. **Ouvrir** 2 graphiques:
   - Boom 1000 Index
   - Crash 1000 Index

2. **Attacher** SMC_Universal sur les 2 graphiques

3. Sur le graphique **Crash 1000**, configurer:

```mql5
[SCANNER MULTI-SYMBOLES TEMPS RÉEL]
EnableOpportunityScanner = true
ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index"

[TRADING AUTOMATIQUE (SCANNER)]
EnableScannerAutoTrading = true
AutoTradeMaxRiskDollars = 0.50     // Pour capital 10$
AutoTradeScalpTpPoints = 50
AutoTradeScalpSlPoints = 30
EnableAutoTrailingStop = true
```

4. **Cliquer OK**

### Étape 3: Vérifier (2 minutes)

Dans l'onglet **Experts** (bas de MT5), vous devriez voir:
```
✅ Scanner multi-symboles initialisé - Boom 1000 Index,Crash 1000 Index
✅ Trading automatique activé - Risque: $0.50 TP:50pts SL:30pts
```

## ✅ C'est Tout!

Le robot va maintenant:
1. **Scanner** les 2 symboles toutes les 2 secondes
2. **Placer automatiquement** des trades sur PERFECT et GOOD
3. **Gérer** le trailing stop
4. **Notifier** les résultats toutes les 10 minutes

## 📱 Notifications

### À l'ouverture
```
✅ TRADE OUVERT: Boom 1000 Index BUY 0.02 lots @ 2845.32
(SL:2815.32 TP:2895.32)
```

### Rapport (toutes les 10 min)
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
```

## ⚙️ Configurations Rapides

### Capital 10$ (Débutant)
```mql5
AutoTradeMaxRiskDollars = 0.50
AutoTradeScalpTpPoints = 50
AutoTradeScalpSlPoints = 30
```

### Capital 50$ (Intermédiaire)
```mql5
AutoTradeMaxRiskDollars = 2.00
AutoTradeScalpTpPoints = 80
AutoTradeScalpSlPoints = 50
```

### Capital 100$ (Avancé)
```mql5
AutoTradeMaxRiskDollars = 5.00
AutoTradeScalpTpPoints = 100
AutoTradeScalpSlPoints = 60
```

## 🛡️ Sécurité

✅ **Risque contrôlé** - Maximum 0.50$ par trade (pour 10$)
✅ **1 position max** par symbole
✅ **3 positions max** au total
✅ **Trailing stop** automatique
✅ **Throttle** - 2 minutes minimum entre trades

## 🎯 Que Trader?

Le robot trade **automatiquement** si:
- ✅ Opportunité = **PERFECT** (toujours)
- ✅ Opportunité = **GOOD** + Spike ≥ 50%
- ❌ Opportunité = **FAIR** (ignoré)

## 📊 Résultats Attendus

### Capital 10$ - Objectif: +1-2$ /jour
```
Win Rate: 55%+
Trades/jour: 5-10
Profit moyen: +0.30$ /trade gagnant
```

### Capital 50$ - Objectif: +5-10$ /jour
```
Win Rate: 55%+
Trades/jour: 8-15
Profit moyen: +1.50$ /trade gagnant
```

## 🔧 Dépannage Rapide

### Pas de trade automatique
→ Vérifier `EnableScannerAutoTrading = true`

### Lot trop petit
→ Augmenter `AutoTradeMaxRiskDollars`

### Pas de notification
→ Activer dans MT5: Outils → Options → Notifications

## 📖 Documentation Complète

Pour en savoir plus:
→ **TRADING_AUTOMATIQUE_README.md** (guide complet)

---

**Prêt?** Activez le trading auto et laissez le robot travailler! 🤖📈💰
