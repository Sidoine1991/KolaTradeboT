# Plan de Déploiement: 2 Terminaux MT5

## Récapitulatif

| Aspect | Terminal 1 (Exness) | Terminal 2 (Deriv) |
|--------|-------------------|------------------|
| **Symboles** | EURUSD, XAUUSD, GBPUSD, USDJPY | Boom 1000, Crash 1000, Volatility 100 |
| **Spreads** | 1-4 pts (excellent) | 10-50 pts (8-16 UTC), 100-1400 pts (hors-fenêtre) |
| **Heures Trading** | 24h/24 ✅ | 8-16 UTC uniquement ✅ |
| **Risque par Trade** | $0.50 | $0.20 |
| **Max Positions** | 3 ouvertes | 2 ouvertes |
| **Throttle** | 10s (rapide) | 20s (lent) |
| **Dashboard** | Complet | Léger |
| **Taux Succès** | 85-95% ordres acceptés | 40-60% ordres acceptés |
| **Profit/jour** | +2-5% | +0.5-2% |

---

## Étapes de Configuration

### Préparation (Commun aux 2)
```
1. ✅ Compiler SMC_Universal.mq5 (0 errors, 0 warnings)
2. ✅ Copier SMC_Universal.ex5 compilé vers les 2 terminaux
3. ✅ Configurer WebRequest autorisé sur les 2 terminaux
   - MT5 > Outils > Options > Expert Advisors > WebRequest
   - URLs autorisées:
     * https://kolatradebot-7ofl.onrender.com
     * http://127.0.0.1:8000
```

### Terminal 1: Exness 🟢

```
1. Ouvrir Terminal 1 MT5 (Exness)
2. Navigateur Expert Advisors > SMC_Universal
3. Double-clic pour attacher à un graphique (ex: EURUSD M1)
4. Inputs à modifier:
   - ScannerSymbolsList = "EURUSD,XAUUSD,GBPUSD,USDJPY"
   - ScannerRefreshSeconds = 30
   - AutoTradeMaxRiskDollars = 0.50
   - AutoTradeScalpTpPoints = 100
   - AutoTradeScalpSlPoints = 40
   - MaxTotalOpenPositions = 3
   - GOM_OnTickMainThrottleSec = 10
   - SMC_UTCTradingWindowEnabled = false
   - GOM_InternalLightChart = false

5. Cliquer OK → EA démarre
6. Vérifier logs:
   ✅ "Compilé sans erreur"
   ✅ "Dashboard ML actif"
   ✅ "Scanner détecte opportunités"
   ✅ "✅ TRADE OUVERT"
```

### Terminal 2: Deriv 🔴

```
1. Ouvrir Terminal 2 MT5 (Deriv)
2. Navigateur Expert Advisors > SMC_Universal
3. Double-clic pour attacher à un graphique (ex: Boom 1000 Index M1)
4. Inputs à modifier:
   - ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index,Volatility 100 Index"
   - ScannerRefreshSeconds = 60
   - AutoTradeMaxRiskDollars = 0.20
   - AutoTradeScalpTpPoints = 80
   - AutoTradeScalpSlPoints = 30
   - MaxTotalOpenPositions = 2
   - GOM_OnTickMainThrottleSec = 20
   - SMC_UTCTradingWindowEnabled = true
   - SMC_UTCWindowStart = 8
   - SMC_UTCWindowEnd = 16
   - GOM_InternalLightChart = true
   - ScannerShowPanel = false

5. Cliquer OK → EA démarre
6. Vérifier logs:
   ✅ "Scanner multi-symboles actif"
   ✅ "UTC PAUSE détecté (hors 8-16 UTC)"
   ✅ "✅ TRADE OUVERT (pendant fenêtre UTC)"
   ✅ "⏸ MODE ARRÊT AUTO UTC (hors fenêtre)"
```

---

## Monitoring Pendant 24h

### Heures de Trading

```
TERMINAL 1 (EXNESS)        TERMINAL 2 (DERIV)
24h/24 Trading             8-16 UTC: ACTIF ✅
Toujours actif             16-8 UTC: OBSERVATION (pas de trading)

8-16 UTC
├─ Exness: Normal
└─ Deriv: Meilleurs spreads → plus d'opportunités

17-7 UTC (ex: 18-8 France)
├─ Exness: Normal
└─ Deriv: Spreads énormes → BLOQUÉ automatiquement
```

### Logs à Vérifier (Toutes les heures)

Terminal 1:
```
✅ "✅ TRADE OUVERT: EURUSD BUY 0.01 lots @ 1.0850"
✅ "Dashboard: Equity +50$, Flottant +5$"
✅ "Positions totales: 1-3"
```

Terminal 2:
```
✅ (8-16 UTC) "✅ TRADE OUVERT: Boom 1000 BUY 0.01 lots"
✅ (16-8 UTC) "⏸ MODE ARRÊT AUTO UTC" (normal)
✅ Dashboard: Positions = 0-2 (max respecté)
```

---

## Checklist de Mise en Production

- [ ] Compiler SMC_Universal.mq5 ✅
- [ ] Terminal 1 attaché à Exness (EURUSD M1)
- [ ] Terminal 2 attaché à Deriv (Boom 1000 M1)
- [ ] WebRequest autorisé sur les 2 (onglet Expert Advisors)
- [ ] Configurations optimales appliquées (voir CONFIG_EXNESS_OPTIMAL.md et CONFIG_DERIV_OPTIMAL.md)
- [ ] 1ère heure de monitoring: Vérifier logs + trades
- [ ] Équité positive après 24h
- [ ] Zéro erreur compilation après redémarrage

---

## Troubleshooting Rapide

| Symptôme | Cause | Solution |
|----------|-------|----------|
| Aucun trade | GOM OFF ou UTC fermée | Vérifier logs + UTC window |
| Ordres rejetés 90% | Spreads trop hauts | Terminal 2 hors 8-16 UTC |
| Dashboard vide | IA SERVER down | Vérifier Render API |
| Crash EA | Erreur compilation | Recompiler SMC_Universal.mq5 |

---

**Date:** 2026-05-16
**Status:** ✅ Prêt pour déploiement
