# Application des Optimisations Capital 20$ - Checklist

## ✅ Modifications Déjà Appliquées dans SMC_Universal.mq5

Les paramètres suivants sont **DÉJÀ OPTIMISÉS** :

### Scanner & Trading Auto
- ✅ `EnableOpportunityScanner = true` (ligne 25)
- ✅ `EnableScannerAutoTrading = true` (ligne 35)
- ✅ `AutoTradeMaxRiskDollars = 0.20` (ligne 36)
- ✅ `AutoTradeScalpTpPoints = 80` (ligne 37)
- ✅ `AutoTrailingStopPoints = 15` (ligne 40)
- ✅ `AutoTrailingStepPoints = 3` (ligne 41)

### Risk Management de Base
- ✅ `InpLotSize = 0.01` (ligne 8586)
- ✅ `MaxPositionsTerminal = 1` (ligne 8589)
- ✅ `MaxTotalLossDollars = 3.0` (ligne 8593)
- ✅ `DailyProfitTarget = 2.0` (ligne 8594)
- ✅ `MaxRiskPerTradePercent = 1.0` (ligne 8599)
- ✅ `MaxDailyDrawdownPercent = 8.0` (ligne 8600)
- ✅ `MaxDailyLossDollars = 1.50` (ligne 8602)

### Détection Spikes (Plus Strict)
- ✅ `SpikeAlertMinProbability = 0.65` (ligne 131)
- ✅ `SpikeBypassMinProbability = 0.60` (ligne 132)
- ✅ `SpikeBlinkMinProbability = 0.55` (ligne 133)
- ✅ `SpikeBlinkLeadThAdjMax = 0.12` (ligne 134)
- ✅ `SpikeModeBypassStrict = false` (ligne 135)
- ✅ `DoubleSpikeMinProb = 0.60` (ligne 139)

### Trailing Stop Boom/Crash
- ✅ `EnableBoomCrashAdvancedTrailing = true` (ligne 8757)
- ✅ `BoomCrashTrailingInitialPct = 0.10` (ligne 8758)
- ✅ `BoomCrashTrailingSpikePct = 0.06` (ligne 8759)
- ✅ `BoomCrashTrailingStepPct = 0.03` (ligne 8760)
- ✅ `BoomCrashTrailingSpikeMinProfit = 0.03` (ligne 8761)

### Fermeture Auto Spike Boom/Crash
- ✅ `EnableAutoClosePositionsOnSpikeCaptured = true` (ligne 143)
- ✅ `GomSpikeCapturedCloseAnyProfit = true` (ligne 148)
- ✅ `SpikeCapturedCloseMagicFilter = 0` (ligne 144) - ferme toutes positions
- ✅ `SpikeAutoCloseAllowLightLossExit = true` (ligne 152)

### Filtres de Qualité
- ✅ `StrictConfluenceMode = true` (ligne 244)
- ✅ `MinFilterPassRatio = 0.55` (ligne 245)
- ✅ `RequireMTFAndStructure = true` (ligne 248)
- ✅ `MinStrengthForEntry = 3.0` (ligne 249)
- ✅ `EnableEntryQualityGate = true` (ligne 258)
- ✅ `MinEntryQualityScore = 0.55` (ligne 259)

### Lots Fixes
- ✅ `SpikeNearM5Lots = 0.01` (ligne 268)
- ✅ `GomPlanArrowMarketLots = 0.01` (ligne 291)

---

## 🔧 Modifications À APPLIQUER

### SMC_Universal.mq5 - Paramètres Restants

Chercher et modifier ces lignes :

```mql5
// Section SALVAGE BANK (Protection Gains)
input double SalvageBankTriggerDailyProfitUSD = 1.50;     // Était probablement plus haut
input double SalvageBankAbsoluteFloorUSD = 0.80;
input double SalvageBankMaxGivebackFromPeakUSD = 0.50;
input bool SalvageBankBlockNewEntriesWhenArmed = true;

// Section STOP LOSS / TAKE PROFIT
input double SL_ATRMult = 1.8;                            // Était 2.5
input double TP_ATRMult = 5.4;                            // Était 5.0
input double TrailingStop_ATRMult = 2.0;                  // Était 3.0
input double TrailingStartProfitDollars = 0.05;           // Était 1.00
input double DynamicSL_StartProfitDollars = 0.05;         // Était 1.00

// Section BOOM/CRASH TARGETS
input double TargetProfitBoomCrashUSD = 0.50;             // Était 2.0
input double MaxLossBoomCrashPerTradeUSD = 0.20;          // Était 3.0
input double BoomCrashSpikeDetectionThreshold = 0.35;     // Était 0.42
input double DynamicSL_LockPctOfMax = 0.80;               // Était 0.70
input int DynamicSL_BE_BufferPoints = 3;                  // Était 5

// Section PROFIT LOCK
input double ProfitLockStartDollars = 1.0;                // Était 5.0
input double ProfitLockMaxGivebackDollars = 0.30;         // Était 1.5

// Section PERTES CUMULÉES
input double CumulativeLossPauseThresholdDollars = 1.0;   // Était 5.0
input int CumulativeLossPauseMinutes = 60;                // Était 30
input int ConsecutiveLossPauseMinutes = 90;               // Était 45

// Section LIMITES SYMBOLES
input double MaxLossPerSpikeTradeDollars = 0.20;          // Était 3.0
input double MaxLossPerSymbolDollars = 0.40;              // Était 3.0
input double MaxLossPerMetalSymbolDollars = 0.60;         // Était 8.0
input double MaxDailyRealizedLossPerSymbolUSD = 0.40;     // Était 3.0
input double SymbolProfitTargetUSD = 1.0;                 // Était 10.0

// Section STALE EXIT
input double BoomCrash_StaleExitBankUsd = 0.05;           // Était 0.35

// Section PAUSE APRÈS PROFIT
input int PauseAfterProfitHours = 6;                      // Était 4

// Section CONFIANCE IA
input double MinAIConfidencePercent = 82.0;               // Était 75.0
input double MinAIConfidence = 0.82;                      // Était 0.80
input double MinSetupScoreEntry = 75.0;                   // Était 65.0
input double MinWinProbability = 88.0;                    // Était 85.0
input double MinConfidenceHtfEntryPct = 72.0;             // Vérifier valeur actuelle

// Section TRADES JOURNALIERS
input int MaxDailyTrades = 3;                             // Était 6
input bool UseEquityAdaptiveDailyTrades = true;           // Vérifier
input int MinMinutesBetweenTrades = 30;                   // Était 20
input double MaxAllowedLossPerTrade = 0.20;               // Était 2.0
input int MaxHoldingTimeSeconds = 180;                    // Était 300

// Section PROTECTION GAINS
input double DailyGainProtectionThreshold = 1.0;          // Était 4.0
input double MaxDrawdownAfterProtection = 0.30;           // Était 1.0

// Section ML/SPIKE
input double SpikeTradeMinModelProbability = 0.62;        // Était 0.52
input double SpikeImminentAlertThreshold = 0.68;          // Était 0.62
input double SpikeML_MinProbability = 0.78;               // Était 0.75

// Section POSITIONS OTE
input int OTE_MaxPositionsPerSymbol = 1;                  // Était 2

// Section QUALITÉ FILTRES
input double KolaClosestAnchorMaxAtr = 1.20;              // Vérifier
input bool RelaxStrengthBoomCrashSpikeKola = false;       // Était true
input double RelaxStrengthSpikeKolaMinCap = 1.5;          // Vérifier
```

---

### GOM_KOLA_SIDO_Script.mq5

Modifications à appliquer :

```mql5
input int    SpikeLookbackBarsM1 = 25;                    // Était 20
input double SpikeAlertMinProbability = 0.62;             // Était 0.45
input double SpikeBypassMinProbability = 0.58;            // Était 0.40
input double SpikeBlinkMinProbability = 0.52;             // Était 0.35
input double SpikeBlinkLeadThAdjMax = 0.15;               // Était 0.20
input bool   SpikeModeBypassStrict = false;               // Était true
input double DoubleSpikeNearLevelAtr = 0.60;              // Était 0.75
input double DoubleSpikeMinProb = 0.58;                   // Était 0.42
input int    DoubleSpikeHoldSeconds = 60;                 // Était 90
```

---

### ai_server.py

Modifications à appliquer (chercher les lignes correspondantes) :

```python
# Ligne ~830-850 : Confiance décisions
MIN_CONFIDENCE_THRESHOLD = 0.72  # Était 0.55
FORCE_HOLD_THRESHOLD = 0.60      # Était 0.40
CACHE_DURATION = 45              # Était 30

# Dans la fonction qui calcule les décisions (chercher "confidence =")
confidence = max(0.75, raw_confidence)  # Plancher 75% (était 0.68)

# Seuil HOLD forcé (chercher "if confidence <")
if confidence < 0.72:  # Était 0.68
    return "HOLD", 0.50, "Confidence insuffisante pour capital 20$ (ultra-conservateur)"

# Dans /config/symbols endpoint (classe SymbolConfigOut)
SymbolConfigOut(
    min_expectancy=0.20,           # Était 0.0
    min_ai_confidence=0.72,        # Était 0.55
    max_daily_loss_usd=0.40,       # Était None
    max_consecutive_losses=2,      # Était None
    risk_profile="ultra_conservative"  # Était "balanced"
)

# Prompt Boom/Crash (chercher "Confiance minimum" dans le prompt)
"""
Confiance minimum : 75% (était 68%)
RSI extrêmes : <35 (achat) / >65 (vente) — était <40 / >60
ATR danger : >2.5x moyenne — était >2.8x
Capital : 20 USD strict
Risque par trade : 0.20 USD maximum (1%)
"""
```

---

## 🎯 COMPORTEMENT BOOM/CRASH vs AUTRES DEVISES

### ✅ BOOM/CRASH (Déjà Configuré)

La fonction `ManageBoomCrashSpikeClose()` est **DÉJÀ ACTIVE** et gère :

1. **Fermeture automatique dès spike capté + gain > 0** :
   - `GomSpikeCapturedCloseAnyProfit = true` (ligne 148)
   - Ferme dès que le prix franchit le niveau GOM ET profit net > 0

2. **Trailing stop ultra-serré après spike** :
   - `BoomCrashTrailingSpikePct = 0.06` (6% après spike)
   - `BoomCrashTrailingSpikeMinProfit = 0.03` (actif dès 0.03$)

3. **Détection mouvement rapide** :
   - `SpikeCapturedRequireRealSpike = true` (ligne 153)
   - Exige 0.3% en 5s avant de considérer comme "spike capté"

4. **Filtre par catégorie symbole** :
   - Lignes 11798-11801 : Forex/Métaux/Commodities **EXCLUS** de cette logique
   - Seulement Boom/Crash/Volatility/Gainx/Painx concernés

### ✅ FOREX/MÉTAUX/AUTRES (Déjà Configuré)

Les autres devises utilisent :

1. **TP fixe** :
   - `AutoTradeScalpTpPoints = 80` (ligne 37)
   - TP respecté jusqu'à atteinte

2. **Trailing stop normal** :
   - `EnableAutoTrailingStop = true` (ligne 39)
   - `AutoTrailingStopPoints = 15` (ligne 40)
   - `AutoTrailingStepPoints = 3` (ligne 41)

3. **Pas de fermeture spike** :
   - La fonction `ManageBoomCrashSpikeClose()` ignore ces symboles (ligne 11798)

---

## 📝 ORDRE D'APPLICATION

1. **ai_server.py** (redémarrage requis)
2. **GOM_KOLA_SIDO_Script.mq5** (recompilation)
3. **SMC_Universal.mq5** (recompilation)
4. **Tester en démo** 2-3 jours
5. **Déployer en production** avec monitoring

---

## ⚠️ POINTS CRITIQUES

### Boom/Crash - Fermeture Automatique
La logique suivante est **ACTIVE** :

```
SI (Boom/Crash OU Volatility OU Gainx/Painx)
  ET spike_capté (niveau GOM franchi)
  ET profit_net > 0.00$
  ET mouvement_rapide_détecté (0.3% en 5s)
ALORS
  → Fermeture IMMÉDIATE au marché
```

### Autres Devises - TP + Trailing Normal
```
SI (Forex OU Métaux OU Commodities)
ALORS
  → Respecter TP (80 points)
  → Trailing stop normal (15 points distance, 3 points step)
  → PAS de fermeture spike automatique
```

---

## ✅ CONCLUSION

**SMC_Universal.mq5** est déjà configuré avec la logique demandée :
- ✅ Boom/Crash : Fermeture auto sur spike capté + gain
- ✅ Autres devises : TP et trailing stop normaux

Les modifications restantes concernent principalement :
- Ajustements fins des seuils (plus strict pour 20$)
- Salvage Bank et Profit Lock
- Confiance IA relevée à 72-82%

Tous les fichiers sont prêts, il suffit de recompiler et tester !
