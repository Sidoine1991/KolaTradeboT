# Backtest Checklist — 2026-06-01

## Changements à tester

### 1. ✅ Dual Trade Counters (Dashboard)
- [ ] Dashboard affiche **Symbol: X/7** (trades par symbol)
- [ ] Dashboard affiche **Global: Y/7** (tous symbols)
- [ ] Compteurs se mettent à jour correctement pendant le backtest

### 2. ✅ Global Limit Stop (Position 7)
- [ ] Robot s'arrête complètement quand **Global atteint 7**
- [ ] Message log: "ROBOT EN PAUSE — Limite GLOBAL 7 positions atteinte"
- [ ] Robot reprend le lendemain à 00h00 (ou nouveau jour)
- [ ] Pas de 8e trade même si per-symbol < 7

### 3. ✅ Dynamic SL — Breakeven Protection
- [ ] À 50% du chemin vers TP, SL remonte automatiquement au breakeven
- [ ] Exemple BUY: Entrée 2500, TP 2510 → À 2505 (50%), SL → 2500
- [ ] Message log: "Breakeven Protection — Ticket XXXXX | SL déplacé au breakeven"
- [ ] Trade ne perd JAMAIS plus après 50% du TP atteint

### 4. Signal Quality (Existing)
- [ ] Seuil qualité: 60% (vérifier dans Inputs)
- [ ] Seuls signaux >= 60% génèrent des trades
- [ ] Signaux faibles sont filtrés

---

## Paramètres Backtest

| Paramètre | Valeur |
|-----------|--------|
| Symbol | Boom 1000 |
| Timeframe | M1 |
| Expert Advisor | deriveapro.mq5 |
| Period | Last 7 days (2026-05-25 to 2026-06-01) |
| InpMinSignalQuality | 60.0 |
| MAX_DAILY_POSITIONS | 7 |
| InpTimeStopMinutes | 25 |
| InpTP_ATR | 2.5 |

---

## Métriques Attendues

### Réduction de Fréquence
- **Avant**: ~8-12 trades/jour
- **Attendu après**: ~3-6 trades/jour (limite 7 + filtre qualité)

### Win Rate
- **Attendu**: +15-25% vs avant (meilleure qualité)
- **Breakeven trades**: Devrait augmenter (protection SL au 50%)

### Drawdown
- **Attendu**: -20-30% vs avant (moins d'entrées impulsives)
- **Pertes max**: Limitées car SL remonte au breakeven

### Profit par Trade
- **Attendu**: Stable ou légèrement augmenté
- Fréquence réduite = capital mieux alloué

---

## Points de Vérification Critiques

### ⚡ STOP si:
1. ❌ Compilation avec erreurs (déjà vérifiée ✅ 0 errors)
2. ❌ Robot n'ouvre pas de trades du tout
3. ❌ Dashboard ne montre pas les deux compteurs
4. ❌ Global limit ne fonctionne pas (8e trade ouvre quand global=7)
5. ❌ SL ne change pas après 50% du TP

### ✅ GO si:
1. ✅ Compilation: 0 errors, 0 warnings
2. ✅ Backtest s'exécute sans crash
3. ✅ Profits positifs
4. ✅ Tous les 3 points ci-dessus validés

---

## Log Clés à Chercher

```
[DerivEAPro] ✅ Breakeven Protection — Ticket 123456 | SL déplacé au breakeven 2500.00000
[DerivEAPro] ⏸️ ROBOT EN PAUSE — Limite GLOBAL 7 positions atteinte (7 trades tous symbols)
[DerivEAPro] Nouveau jour — Compteurs réinitialisés, 7 positions max permises
```

---

## Notes

- Backtest lancé: 2026-06-01 (samedi)
- Durée estimée: 5-15 min pour 7 jours de données M1
- Profit cible: Pas de perte > -$20/day avec breakeven protection
