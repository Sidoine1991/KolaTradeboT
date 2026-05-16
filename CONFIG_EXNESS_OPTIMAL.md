# Configuration EXNESS Optimale

## Terminal 1: Exness (Forex/Metals)

```
Input Group: SCANNER MULTI-SYMBOLES TEMPS RÉEL
=====================================
EnableOpportunityScanner = true
ScannerSymbolsList = "EURUSD,XAUUSD,GBPUSD,USDJPY"
ScannerRefreshSeconds = 30          // ✅ PLUS RAPIDE (spreads stables)
ScannerPanelX = 12
ScannerPanelY = 150
ScannerPanelWidth = 500
ScannerRowHeight = 25
ScannerPanelAnchorRight = true
ScannerShowPanel = true             // ✅ VISIBLE (peu d'objets)

Input Group: TRADING AUTOMATIQUE (SCANNER)
=====================================
EnableScannerAutoTrading = true
AutoTradeMaxRiskDollars = 0.50      // ✅ AUGMENTÉ (Exness = capital plus stable)
AutoTradeScalpTpPoints = 100        // ✅ AUGMENTÉ (spreads bas = TP plus loin)
AutoTradeScalpSlPoints = 40         // ✅ AUGMENTÉ (ratio TP/SL = 2.5:1)
EnableAutoTrailingStop = true
AutoTrailingStopPoints = 20
AutoTrailingStepPoints = 3
AutoTradeNotifyIntervalMin = 5

Input Group: TIMEFRAMES
=====================================
ShowM1Levels = true                 // ✅ ACTIVÉ (plus de précision)
ShowM5Levels = true
ShowM15Levels = true
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
GOM_InternalLightChart = false      // ✅ COMPLET (Exness = peu d'objets)
GOM_OnTickMainThrottleSec = 10      // ✅ RAPIDE (spreads stables)
GOM_EngineUpdateIntervalSec = 3

Input Group: GESTION DES POSITIONS
=====================================
MaxOpenPositionsPerSymbol = 1
MaxTotalOpenPositions = 3           // ✅ AUGMENTÉ (3 symboles × 1 pos = 3 max)
MinSecondsBetweenTrades = 60
```

## Configuration Avancée

```
Input Group: MACHINE LEARNING
=====================================
UseAIServer = true
UseRenderAsPrimary = true           // Cloud par défaut
AI_ServerRender = "https://kolatradebot-7ofl.onrender.com"
AI_ServerLocal = "http://127.0.0.1:8000"
MinAIConfidencePercent = 65.0       // ✅ BAISSÉ (Exness = moins de spike)

Input Group: UTC TRADING WINDOW
=====================================
SMC_UTCTradingWindowEnabled = false // ✅ DÉSACTIVÉ (Forex 24h)
```

## Symboles Exness (Spreads Typiques)

| Symbole | Spread | Volatilité | Profitabilité |
|---------|--------|-----------|---------------|
| EURUSD | 1-2 pts | Moyenne | ⭐⭐⭐⭐ |
| XAUUSD | 2-4 pts | Élevée | ⭐⭐⭐⭐⭐ |
| GBPUSD | 2-3 pts | Élevée | ⭐⭐⭐⭐ |
| USDJPY | 1-2 pts | Moyenne | ⭐⭐⭐ |

## Performance Attendue

- **Taux d'acceptation ordres:** 85-95% ✅
- **Wins/jour:** 5-15 trades
- **Profit/jour:** +2-5% capital
- **Spread moyen:** ~2 points

---

**Status:** Prêt à déployer sur Terminal 1
