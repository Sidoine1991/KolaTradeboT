# Configuration DERIV Optimale

## Terminal 2: Deriv (Indices Synthétiques)

```
Input Group: SCANNER MULTI-SYMBOLES TEMPS RÉEL
=====================================
EnableOpportunityScanner = true
ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index,Volatility 100 Index"
ScannerRefreshSeconds = 60          // ⚠️ PLUS LENT (spreads variables)
ScannerPanelX = 12
ScannerPanelY = 150
ScannerPanelWidth = 500
ScannerRowHeight = 25
ScannerPanelAnchorRight = true
ScannerShowPanel = false            // ⚠️ MASQUÉ (trop d'objets graphiques)

Input Group: TRADING AUTOMATIQUE (SCANNER)
=====================================
EnableScannerAutoTrading = true
AutoTradeMaxRiskDollars = 0.20      // ✅ ULTRA-CONSERVATEUR (spreads énormes)
AutoTradeScalpTpPoints = 80         // ✅ RÉDUIT (spreads = déjà 80-300 pts)
AutoTradeScalpSlPoints = 30         // ✅ RÉDUIT (ratio TP/SL = 2.67:1)
EnableAutoTrailingStop = true
AutoTrailingStopPoints = 15         // ✅ SERRÉ (spike rapides)
AutoTrailingStepPoints = 3
AutoTradeNotifyIntervalMin = 5

Input Group: TIMEFRAMES
=====================================
ShowM1Levels = true                 // ✅ M1 = timeframe principal
ShowM5Levels = true                 // ✅ Confirmation
ShowM15Levels = false               // ⚠️ DÉSACTIVÉ (Deriv = rapide, M1/M5 suffisent)
ShowM30Levels = false
ShowH1Levels = false
ShowH4Levels = false
ShowD1Levels = false
ShowW1Levels = false

Input Group: DASHBOARD ML AWS RDS
=====================================
UseEnhancedDashboard = true
DashboardMLPosX = 10
DashboardMLPosY = 30
DashboardMLCellWidth = 124
DashboardMLCellHeight = 46
DashboardMLFontSize = 7
DrawingsMaxAgeMinutes = 120

Input Group: MOTEUR GOM INTERNE
=====================================
UseInternalGOMEngine = true
GOM_InternalLightChart = true       // ✅ LÉGER (moins d'objets = CPU bas)
GOM_OnTickMainThrottleSec = 20      // ✅ RALENTI (spreads = moins de calculs)
GOM_EngineUpdateIntervalSec = 5     // ✅ MIS À JOUR plus souvent (spike rapid)

Input Group: GESTION DES POSITIONS
=====================================
MaxOpenPositionsPerSymbol = 1
MaxTotalOpenPositions = 2           // ✅ STRICT (2 max — anti-risque)
MinSecondsBetweenTrades = 120       // ✅ 2 min (évite sur-trading)
```

## Configuration Avancée

```
Input Group: MACHINE LEARNING
=====================================
UseAIServer = true
UseRenderAsPrimary = true
AI_ServerRender = "https://kolatradebot-7ofl.onrender.com"
AI_ServerLocal = "http://127.0.0.1:8000"
MinAIConfidencePercent = 70.0       // ✅ ÉLEVÉ (spike = haute confiance)

Input Group: UTC TRADING WINDOW
=====================================
SMC_UTCTradingWindowEnabled = true  // ✅ ACTIVÉ
SMC_UTCWindowStart = 8              // 8h-16h UTC = meilleurs spreads (UK)
SMC_UTCWindowEnd = 16
SMC_UTCWindowAllowWeekends = false

Input Group: BOOM/CRASH SPECIFIC
=====================================
UseSpikeAutoClose = true            // ✅ Fermer rapide après spike
ProfilScalpBoomCrash = true
BoomCrashSpikeTP = 0.05             // ✅ PETIT TP (0.05$ = ferme vite)
MaxLossDollars = 15.0               // ✅ STOP si -15$ cumul
```

## Symboles Deriv (Spreads Typiques)

| Symbole | Spread | Heures (UTC) | Profitabilité |
|---------|--------|--------------|---------------|
| Boom 1000 | 10-50 pts | 8-16 | ⭐⭐⭐⭐⭐ |
| Boom 1000 | 100-300 pts | 17-7 | ⚠️ Risqué |
| Crash 1000 | 10-50 pts | 8-16 | ⭐⭐⭐⭐⭐ |
| Crash 1000 | 100-300 pts | 17-7 | ⚠️ Risqué |
| Volatility 100 | 20-80 pts | 8-16 | ⭐⭐⭐ |
| Step Index | 30-100 pts | Tous | ⭐⭐ |

## Stratégie Heure par Heure

```
8h-16h UTC (Meilleur spreads)       → TRADING ACTIF ✅
17h-7h UTC (Spreads énormes)        → OBSERVATION (pas de trades)
```

## Performance Attendue

- **Taux d'acceptation ordres:** 40-60% ⚠️ (spreads = rejet fréquent)
- **Wins/jour:** 2-5 trades (fenêtre horaire réduite)
- **Profit/jour:** +0.5-2% capital (spike rapides mais petits)
- **Spread moyen:** ~30 points (8-16 UTC), 200+ hors-fenêtre

## ⚠️ ATTENTION: SPREADS ÉNORMES

**Hors fenêtre UTC (17h-7h):**
- Spreads = **100-1400 points** (!!)
- Ordres bloqués automatiquement
- Zéro trading recommandé

**Le fix appliqué aujourd'hui:** GOM_InternalEngine_Update() s'exécute TOUJOURS → blocage automatique hors fenêtre UTC ✅

---

**Status:** Prêt à déployer sur Terminal 2
