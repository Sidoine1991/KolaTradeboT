# 📊 Backtest Manual Setup — deriveapro.mq5

## Étape 1 : Ouvrir Strategy Tester

1. **Ouvrir MT5** (déjà en cours)
2. **Strategy Tester** : Appuyez sur **F4** ou allez à **View → Strategy Tester**
3. Vérifiez que le panneau apparaît en bas

---

## Étape 2 : Configuration de Base

### 2.1 Expert Advisor
- **Dropdown EA** : Sélectionnez **deriveapro**
- Si absent : recompiler via MetaEditor (F7)

### 2.2 Symbol
- **Dropdown** : Choisissez **Boom 1000** (ou Boom 500)
- Alternatives : Crash 1000, XAUUSD, etc.

### 2.3 Timeframe
- **Dropdown** : **M1** (1 minute)
- Ne pas changer (EA optimisé pour M1)

### 2.4 Model
- **Dropdown** : **Every tick** (précision maximale)

### 2.5 Period
- **From** : Il y a 7-14 jours
- **To** : Aujourd'hui (2026-06-01)
- **Bouton Calendar** pour sélectionner facilement

---

## Étape 3 : Inputs (Paramètres EA)

### 3.1 Qualité Signal
```
InpMinSignalQuality = 60.0  (gamme 0-100)
InpTimeStopMinutes = 25     (fermer après 25 min sans TP)
```

### 3.2 Gestion Position
```
MAX_DAILY_POSITIONS = 7     (limite GLOBALE par jour)
```

### 3.3 Stop Loss / Take Profit
```
InpTP_ATR = 2.5             (TP = entrée + 2.5 × ATR)
SL = ~4 pips (calculé automatiquement)
```

### 3.4 Spike Detection
```
EnableBoomCrashSpikePipeline = true
UseBoomCrashSpikeAtrStops = true
```

**→ Cliquez sur l'onglet "Inputs" pour voir/modifier tous les paramètres**

---

## Étape 4 : Options Backtest

### 4.1 Onglet "Settings"
- ✅ Cochez **Use date** (utiliser la période spécifiée)
- ✅ Cochez **Visual backtest** (voir trades sur chart)
- ⚠️ Ne modifiez PAS : Initial deposit, Leverage, etc.

### 4.2 Onglet "Optimization"
- ✅ Assurez-vous que **Optimization = OFF** (pas d'optimisation)
- Si coché → décochez-le

---

## Étape 5 : Lancer le Backtest

### ✅ Bouton START (couleur verte)
1. Assurez-vous que tous les champs sont remplis
2. Cliquez **START** en bas du Strategy Tester
3. La barre de progression s'affiche (bleu)
4. Attendez que les résultats s'affichent (5-15 min)

---

## Étape 6 : Analyser les Résultats

### 📊 Onglet "Results"
Vous devriez voir :
- **Total Trades** : ~15-30 (avec limite 7/jour)
- **Profitable Trades** : ~60-75%
- **Profit** : Positif (objectif $50-200)
- **Drawdown Max** : < 10-15% (protection SL en breakeven)

### 📈 Onglet "Trades"
Chaque ligne = 1 trade :
- **Entry Time** : Quand la position a ouvert
- **Entry Price** : Prix d'entrée
- **Exit Price** : Prix de fermeture
- **Profit** : P&L en $
- **Status** : "Closed" = normal ; "Stopped out" = SL atteint ; "TP" = TP atteint

**Vérifiez** :
- Beaucoup de trades fermés au **breakeven** après 50% du TP
- Peu de trades perdants (filtre qualité 60% = meilleure sélection)
- Aucun trade après que le 7e position du jour a fermé (limite global = pause)

### 📊 Onglet "Graph"
- Ligne **Balance** : Évolution du solde
- Ligne **Equity** : Solde actuel (balance - losses ouverts)
- Montée régulière = bon signe
- Pics aigus = drawdown (OK si < 15%)

---

## 🔍 Points Clés à Vérifier

### ✅ Dashboard Pendant le Backtest

1. **Compteurs Trade**
   ```
   Symbol: 3/7 | Global: 7/7
   ```
   - À gauche : trades sur le symbol courant
   - À droite : total tous symbols

2. **Statut EA**
   ```
   🟢 ACTIF  ← vert si actif
   🔴 LIMITE ATTEINTE — Pause jusqu'à minuit  ← rouge si limit
   ```

3. **Signal Affiché**
   ```
   Signal: S5-Pattern123 (BUY) | Qualité: 78%
   ```

### 🎯 Breakeven SL Verification

- Cherchez dans le **Journal** les lignes contenant :
  ```
  [DerivEAPro] ✅ Breakeven Protection — Ticket 123456 | SL déplacé au breakeven 2500.00000
  ```
- Cela confirme que le SL remonte au prix d'entrée à 50% du TP

### ⏸️ Global Limit Verification

- Cherchez dans le **Journal** :
  ```
  [DerivEAPro] ⏸️ ROBOT EN PAUSE — Limite GLOBAL 7 positions atteinte (7 trades tous symbols)
  ```
- Vérifiez qu'AUCUN trade n'ouvre après ce message jusqu'au lendemain

---

## 🐛 Troubleshooting

### ❌ "deriveapro not found"
**Solution** :
1. Ouvrez MetaEditor (Alt+F11)
2. Ouvrez `D:\Dev\TradBOT\deriveapro.mq5`
3. Recompilez (Ctrl+F9)
4. Fermez MetaEditor
5. Relancez Strategy Tester

### ❌ "Boom 1000 symbol not available"
**Solution** :
1. Vérifiez que vous êtes connecté à Deriv (MarketWatch affiche les symboles)
2. Ou changez le symbol à **Boom 500** ou **Crash 1000**

### ❌ "No trades opened"
**Possible causes** :
- Période trop courte (changez à 14-30 jours)
- Signal Quality trop élevée (réduisez à 50-60%)
- Market pas en condition de spike (normal)
- **Vérifiez** : Ouvrez le Journal (F3) pour voir les détails

### ❌ SL ne change pas / Breakeven Protection ne fonctionne pas
**Solution** :
1. Vérifiez que le trade atteint bien 50% du TP
2. Ouvrez le Journal → cherchez "Breakeven Protection"
3. Si absent : peut-être que les trades ferment trop vite au TP

---

## 📋 Checklist Avant de Cliquer START

- [ ] EA = **deriveapro**
- [ ] Symbol = **Boom 1000**
- [ ] Timeframe = **M1**
- [ ] Period = **7-14 derniers jours**
- [ ] Inputs affichés correctement
- [ ] Optimization = **OFF**
- [ ] Initial Deposit = **10,000** (ou votre montant)
- [ ] Leverage = **1:100** (standard Deriv)

**Si tout est ✅ : Cliquez START !**

---

## 📊 Résultats Attendus (2026-06-01)

| Métrique | Expectative |
|----------|------------|
| **Total Trades** | 15-30 |
| **Profitable Trades %** | 65-75% |
| **Total Profit** | +$50 to +$200 |
| **Max Drawdown** | 5-12% |
| **Trades per Day** | 3-7 (limited) |
| **Breakeven Trades** | 20-30% du total |

✅ Si résultats positifs → Prêt pour live testing
❌ Si résultats négatifs → Investiguer via Journal
