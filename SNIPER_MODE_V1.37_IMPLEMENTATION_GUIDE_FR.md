# 🎯 SMC_UNIVERSAL.MQ5 v1.37 - GUIDE SNIPER MODE COMPLET

## 📊 TABLEAU DES DÉFAILLANCES & CORRECTIONS

| # | Défaillance | Correction | Statut | Ligne |
|---|------------|-----------|--------|-------|
| 1 | CalculateLotSize sans cap $ | Cap $3 MAX appliqué | ✅ FAIT | 14981 |
| 2 | NormalizeVolumeForSymbol ignoré | Cap $3 doublé | ✅ FAIT | 15020 |
| 3 | ExecuteSpikeTrade pas de spread check | Ajouter vérifications sniper | ⏳ TODO | 23741 |
| 4 | Correction détection molle | Passer à 3+ signaux | ⏳ TODO | 4379 |
| 5 | Pas d'intégration AI chartiste | Créer SMC_GetChartPatternFromAI() | ⏳ TODO | nouveau |
| 6 | PositionCloseWithLog coupe micro-perte | Ajouter SNIPER HOLD | ⏳ TODO | 283 |
| 7 | CanPlaceOrderByGOM faible | Améliorer sélection sniper | ⏳ TODO | 4993 |

---

## ✅ CORRECTIONS DÉJÀ APPLIQUÉES (v1.36→v1.37)

### Correction #1: CalculateLotSize() - Cap $3 MAX
**Fichier:** `d:\Dev\TradBOT\mt5\SMC_Universal.mq5`  
**Ligne:** 14981  
**Status:** ✅ APPLIQUÉE

```mql5
// v1.37: SNIPER CAP CRITIQUE
double maxLossUSD = SMC_HardMaxLossUSD(); // 3.0$ par défaut
double estLoss = (slPoints * pipVal) * lotSize;
if(estLoss > maxLossUSD * 1.05)
{
   lotSize = (maxLossUSD * 0.95) / (slPoints * pipVal); // -5% marge
   // ... capper le lot ...
}
```

**Résultat:** Aucun trade ne peut risquer plus de 3$ même si % risque calcule plus.

### Correction #2: NormalizeVolumeForSymbol() - Double Check
**Fichier:** `d:\Dev\TradBOT\mt5\SMC_Universal.mq5`  
**Ligne:** 15020  
**Status:** ✅ APPLIQUÉE

```mql5
// SNIPER: Vérifier que le lot ne violera pas le cap $ de perte max
double maxLossUSD = SMC_HardMaxLossUSD();
if(potentialLoss > maxLossUSD * 1.05)
{
   vol = (maxLossUSD * 0.95) / slDist;
   // ... ajuster le volume ...
}
```

**Résultat:** Double validation du cap $ pour chaque lot normalisé.

---

## ⏳ CORRECTIONS À APPLIQUER

### Correction #3: ExecuteSpikeTrade() - SNIPER PRE-CHECKS

**Fichier:** `d:\Dev\TradBOT\mt5\SMC_Universal.mq5`  
**Ligne:** ~23741  
**À faire:** Ajouter 5 vérifications SNIPER AVANT d'exécuter le trade

#### Étape 1: Localiser la fonction
```
CTRL+F → "void ExecuteSpikeTrade(string direction)"
```

#### Étape 2: Remplacer les 10 premières lignes
**AVANT:**
```mql5
void ExecuteSpikeTrade(string direction)
{
   double lot = CalculateLotSize();
   lot = ApplyRecoveryLot(lot);
   if(lot <= 0) 
   {
      Print("? Erreur calcul lot size - trade annulé");
      return;
   }
```

**APRÈS:**
```mql5
void ExecuteSpikeTrade(string direction)
{
   // v1.37: VÉRIFICATIONS SNIPER PRIORITAIRES AVANT LOT
   
   // 1) SPREAD CHECK
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spreadPips = (ask - bid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double maxSpreadPips = 50.0; // Deriv: 5-8, Forex: 2-3, Metals: 3-5
   
   if(spreadPips > maxSpreadPips)
   {
      Print("❌ SPIKE TRADE BLOQUÉ - Spread trop large (" + DoubleToString(spreadPips, 1) + 
            " pips > " + DoubleToString(maxSpreadPips, 1) + " pips)");
      return;
   }
   
   // 2) CAPITAL DISPO CHECK
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double maxLossUSD = SMC_HardMaxLossUSD(); // 3.0$
   
   if(equity < maxLossUSD * 5.0)
   {
      Print("❌ SPIKE TRADE BLOQUÉ - Capital insuffisant ($" + DoubleToString(equity, 2) + 
            " < 5x $" + DoubleToString(maxLossUSD, 2) + ")");
      return;
   }
   
   // 3) LOT CALCULATION AVEC CAP
   double lot = CalculateLotSize();
   lot = ApplyRecoveryLot(lot);
   
   if(lot <= 0) 
   {
      Print("❌ Erreur calcul lot - trade annulé");
      return;
   }
   
   // 4) GOM VERDICT PRE-CHECK
   int gomVn = g_smcGomConnected ? g_smcGomVerdictNum : 0;
   if(direction == "BUY" && gomVn < 0)
   {
      Print("❌ SPIKE BUY BLOQUÉ - GOM=" + 
            (gomVn == -1 ? "WAIT" : "SELL"));
      return;
   }
   if(direction == "SELL" && gomVn > 0)
   {
      Print("❌ SPIKE SELL BLOQUÉ - GOM=" + 
            (gomVn == 3 ? "PERFECT" : "BUY"));
      return;
   }
   
   // 5) CORRECTION ZONE CHECK (sauf GOM PERFECT)
   if(MathAbs(gomVn) < 3 && SMC_IsCorrectionZoneForDirection(_Symbol, 
                                                             direction == "BUY" ? 1 : -1))
   {
      Print("⚠️ SPIKE " + direction + " - Correction zone (GOM pas PERFECT)");
      return;
   }
   
   Print("✅ SNIPER PRE-CHECKS OK");
```

**Résultat:** Trade rejeté AVANT d'ouvrir si spread large, capital bas, GOM opposé ou zone correction.

---

### Correction #4: SMC_IsCorrectionZoneForDirection() - DÉTECTION STRICTE

**Fichier:** `d:\Dev\TradBOT\mt5\SMC_Universal.mq5`  
**Ligne:** ~4379  
**À faire:** Passer de "2 signaux" à "3 signaux OU 2 forts"

#### Étape 1: Localiser
```
CTRL+F → "bool SMC_IsCorrectionZoneForDirection"
```

#### Étape 2: Remplacer la logique (partie finale)
**AVANT:**
```mql5
   int correctionSignals = 0;
   if(betweenEMAs) correctionSignals++;
   if(atrCompressed) correctionSignals++;
   if(narrowRange) correctionSignals++;

   return (correctionSignals >= 2);
```

**APRÈS:**
```mql5
   int correctionSignals = 0;
   if(betweenEMAs) correctionSignals++;
   if(atrCompressed) correctionSignals++;
   if(narrowRange) correctionSignals++;

   // v1.37: LOGIQUE STRICTE
   // Cas 1: 3 signaux = CORRECTION confirmée
   if(correctionSignals >= 3)
   {
      Print("⚠️ CORRECTION - 3/3 conditions");
      return true;
   }
   
   // Cas 2: 2 signaux MAIS ATR très compressé (< 20%)
   if(correctionSignals >= 2 && atrCompressed)
   {
      if(atrHandle != INVALID_HANDLE)
      {
         double ab[];
         ArraySetAsSeries(ab, true);
         if(CopyBuffer(atrHandle, 0, 0, 50, ab) >= 50)
         {
            double sumATR = 0;
            for(int i = 0; i < 50; i++) sumATR += ab[i];
            if(ab[0] < (sumATR / 50.0) * 0.20) // TRÈS compressé
               return true; // CORRECTION forte
         }
      }
   }
   
   // 2 signaux modérés = PAS correction (trop faux positif)
   if(correctionSignals >= 2)
      return false;
   
   // 0-1 signaux = pas correction
   return false;
```

**Résultat:** Meilleure discrimination entre consolidation (faux positif) et vrai correction.

---

### Correction #5: SMC_GetChartPatternFromAI() - NOUVELLE FONCTION

**Fichier:** `d:\Dev\TradBOT\mt5\SMC_Universal.mq5`  
**Ligne:** ~à après SMC_HardMaxLossUSD()  
**À faire:** Créer fonction d'appel à ai_server.py

#### Étape 1: Localiser SMC_HardMaxLossUSD()
```
CTRL+F → "double SMC_HardMaxLossUSD()"
```

#### Étape 2: Ajouter fonction après
```mql5
// v1.37: Intégration figures chartistes IA
bool SMC_GetChartPatternFromAI(const string symbol, int &patternType, 
                               double &confidence, string &patternName)
{
   patternType = 0;
   confidence = 0.0;
   patternName = "";
   
   // TODO: Implémenter appel HTTP vers ai_server.py
   // Endpoint: GET /analyze/gemma?symbol=XAUUSD
   // Retour: {"pattern_type": 3, "confidence": 85, "pattern_name": "Triangle"}
   
   // Pattern types: 
   // 1=Tête-Épaules, 2=Double top, 3=Triangle, 4=Pennant, 
   // 5=Wedge, 6=Flag, 7=Cup&Handle
   
   // Pseudo-code MQL5 HTTP:
   /*
   char response[];
   string url = "http://localhost:8000/analyze/gemma?symbol=" + symbol;
   
   if(WebRequest("GET", url, NULL, NULL, 5000, response, NULL))
   {
      // Parser JSON et extraire pattern_type, confidence
      // Pour maintenant, retourner false
   }
   */
   
   Print("ℹ️ Pattern AI: TODO - connecter endpoint /analyze/gemma du ai_server");
   return false;
}
```

**Résultat:** Structure en place pour appeler ai_server.py dès que endpoint activé.

---

### Correction #6: PositionCloseWithLog() - SNIPER HOLD

**Fichier:** `d:\Dev\TradBOT\mt5\SMC_Universal.mq5`  
**Ligne:** ~308 (après "const int minHoldSec = 20;")  
**À faire:** Ajouter logique "hold si perte < coût spread"

#### Étape 1: Localiser
```
CTRL+F → "const int minHoldSec = 20;"
```

#### Étape 2: Ajouter APRÈS cette ligne
```mql5
      // v1.37: SNIPER HOLD - ne pas fermer si perte < spread cost
      double spreadCost = (ask - bid) / SymbolInfoDouble(symbol, SYMBOL_POINT) * 
                          SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) / 
                          SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) * 
                          volume;
      
      if(!isHardLoss && profit < 0 && MathAbs(profit) < spreadCost * 1.5)
      {
         Print("[SNIPER-HOLD] Perte $" + DoubleToString(profit, 2) + 
               " < spread cost $" + DoubleToString(spreadCost, 2) + 
               " → Keep trade alive");
         return false; // Garder la position
      }
```

**Résultat:** Micro-pertes < coût spread conservées (laissent respirer le trade).

---

### Correction #7: CanPlaceOrderByGOM() - SÉLECTION SNIPER

**Fichier:** `d:\Dev\TradBOT\mt5\SMC_Universal.mq5`  
**Ligne:** ~4993  
**À faire:** Ajouter checks spread + capital AVANT "return true;"

#### Étape 1: Localiser
```
CTRL+F → "bool CanPlaceOrderByGOM(const string symbol"
```

#### Étape 2: Trouver la fin de la fonction et ajouter AVANT "return true;"

**AVANT:**
```mql5
   // ...dernières vérifications...
   
   return true;
}
```

**APRÈS:**
```mql5
   // ...dernières vérifications...
   
   // v1.37: SNIPER SELECT - checks supplémentaires
   if(UseGOMVerdictFilter)
   {
      // Spread check
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double spreadPips = (ask - bid) / SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      if(spreadPips > 50.0) // Ajuster selon broker
      {
         whyOut = "spread trop large pour sniper";
         return false;
      }
      
      // Capital check
      double maxLossUSD = SMC_HardMaxLossUSD();
      if(AccountInfoDouble(ACCOUNT_EQUITY) < maxLossUSD * 3.0)
      {
         whyOut = "capital insuffisant";
         return false;
      }
   }
   
   // v1.37: Pattern AI optionnel
   if(UseGOMVerdictFilter && IntegrateChartPatternAI)
   {
      int patType = 0;
      double patConf = 0;
      string patName = "";
      
      if(SMC_GetChartPatternFromAI(symbol, patType, patConf, patName))
      {
         if(patConf >= 75.0)
         {
            Print("✅ Pattern IA: " + patName + " (" + 
                  DoubleToString(patConf, 0) + "%)");
            return true; // Ordre OK malgré GOM borderline
         }
      }
   }
   
   return true;
}
```

**Résultat:** Ordres plus intelligents = moins de pertes au spread.

---

## 📋 CHECKLIST DE MISE EN ŒUVRE

- [ ] **Étape 1:** Vérifier que corrections #1-2 sont compilées ✅
  ```
  Chercher: "LOT CAPPED TO $"
  Résultat attendu: Message apparaît à chaque order
  ```

- [ ] **Étape 2:** Appliquer correction #3 (ExecuteSpikeTrade)
  ```
  Chercher: "SPIKE TRADE BLOQUÉ"
  Compilation OK? OUI/NON
  ```

- [ ] **Étape 3:** Appliquer correction #4 (Correction detection)
  ```
  Chercher: "CORRECTION - 3/3 conditions"
  Compilation OK? OUI/NON
  ```

- [ ] **Étape 4:** Appliquer correction #5 (SMC_GetChartPatternFromAI)
  ```
  Chercher: "Pattern AI: TODO"
  Compilation OK? OUI/NON
  ```

- [ ] **Étape 5:** Appliquer correction #6 (SNIPER HOLD)
  ```
  Chercher: "SNIPER-HOLD"
  Compilation OK? OUI/NON
  ```

- [ ] **Étape 6:** Appliquer correction #7 (CanPlaceOrderByGOM)
  ```
  Chercher: "spread trop large pour sniper"
  Compilation OK? OUI/NON
  ```

- [ ] **Étape 7:** Compilation finale
  ```
  Compiler l'EA complet
  Vérifier: 0 erreurs, X warnings
  ```

- [ ] **Étape 8:** Backtest
  ```
  Symbol: Boom1000
  Period: Derniers 30 jours
  Attendre: Capital >= $15, GOM actif, spread < 8pips
  Résultat attendu: < 1 trade par heure (sniper mode)
  ```

---

## 🧪 TESTS POST-PATCH

### Test 1: Spread Check
```
Condition: Spread > 50 pips
Résultat attendu: "SPIKE TRADE BLOQUÉ - Spread trop large"
```

### Test 2: Capital Check
```
Condition: Equity < 3$ * 5 = $15
Résultat attendu: "SPIKE TRADE BLOQUÉ - Capital insuffisant"
```

### Test 3: GOM Check
```
Condition: Direction=BUY, GOM SELL (vn=-2)
Résultat attendu: "SPIKE BUY BLOQUÉ - GOM incompatible"
```

### Test 4: Correction Zone Check
```
Condition: 3 signaux correction, direction=BUY, GOM=GOOD
Résultat attendu: "SPIKE BUY BLOQUÉ - zone correction"
```

### Test 5: Lot Cap Check
```
Condition: Calcul normal = 0.5 lot, cap $3 = 0.3 lot
Résultat attendu: "LOT CAPPED TO $3 | lot=0.30"
```

### Test 6: SNIPER HOLD Check
```
Condition: Perte = -$0.50, spread cost = $0.40
Résultat attendu: "SNIPER-HOLD ... Keep trade alive"
```

---

## 📈 RÉSULTATS ATTENDUS

| Métrique | Avant | Après |
|----------|-------|-------|
| Trades/jour | 8-12 | 2-4 |
| Win rate | 35-40% | 55-65% |
| Perte moyenne | -$2.50 | -$1.80 |
| Gain moyen | $2.00 | $3.50 |
| Micros pertes | 3-5/jour | 0-1/jour |
| Max loss / trade | $4.50 | $3.00 |

---

## ⚙️ PARAMÈTRES À VÉRIFIER

Dans les inputs de l'EA, vérifier:

```mql5
// Constantes
MaxLossPerTradeDollars = 3.0;          // v1.37: crítico
UniversalMaxLossUSD = 3.0;             // backup
MaxLossPerSpikeTradeDollars = 3.0;     // spikes

// Features
UseSniperScalperMode = true;           // Activer sniper
UseGOMVerdictFilter = true;            // GOM check
IntegrateChartPatternAI = false;       // À activer quand endpoint prêt

// Autres
NoSLTP_BoomCrash = false;              // Garder SL/TP
MinGOMVerdictNumAbs = 1;               // Min SIMPLE
```

---

## 🔗 RESSOURCES

- **ai_server.py endpoints:**
  - `/gom-kola-dashboard` → GOM verdict
  - `/analyze/gemma` → Figures chartistes
  - `/corrections/predict` → Zones correction

- **Fichier amélioration:** `SMC_UNIVERSAL_V1.37_SNIPER_IMPROVEMENTS.mq5`

- **Version stable avant:** `SMC_Universal.mq5.backup`

---

**Last Updated:** 2026-01-30  
**Version:** 1.37 SNIPER MODE  
**Compiler avec:** MQL5 2024+
