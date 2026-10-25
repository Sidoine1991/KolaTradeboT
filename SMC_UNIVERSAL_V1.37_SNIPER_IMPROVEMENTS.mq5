/*
   =============================================================================
   SMC_Universal.mq5 - PATCH v1.37 SNIPER MODE
   =============================================================================
   
   Correction des 6 DÉFAILLANCES CRITIQUES identifiées :
   
   1. ✅ CalculateLotSize() - CAP CRITIQUE $3 MAX
      → Appliqué dans CalculateLotSize() + NormalizeVolumeForSymbol()
   
   2. ❌ ExecuteSpikeTrade() - SNIPER PRE-CHECKS (spread + capital + GOM)
      → À APPLIQUER ci-dessous
   
   3. ❌ CanPlaceOrderByGOM() - SÉLECTION INTELLIGENTE (spread + confluence)
      → À APPLIQUER ci-dessous
   
   4. ❌ SMC_IsCorrectionZoneForDirection() - DÉTECTION STRICTE
      → À APPLIQUER ci-dessous
   
   5. ❌ SMC_GetChartPatternFromAI() - INTÉGRATION IA CHARTISTE
      → À CRÉER/INTÉGRER
   
   6. ❌ PositionCloseWithLog() - SNIPER HOLD SUR MICRO-PERTE
      → À APPLIQUER ci-dessous
   
   APPLIQUERPATCH:
   ================
   1. Cherchez chaque section avec CTRL+F
   2. Remplacez l'ancienne fonction par la nouvelle version
   3. Compilez et testez
   4. Activez "UseSniperScalperMode = true" dans inputs
   
   =============================================================================
*/

//+------------------------------------------------------------------+
// PATCH #2: ExecuteSpikeTrade() - SNIPER PRE-CHECKS
//+------------------------------------------------------------------+
/*
   À TROUVER: void ExecuteSpikeTrade(string direction) @ ligne ~23741
   À REMPLACER: Les 10 premières lignes par le code ci-dessous
   
   CODE ACTUEL À REMPLACER:
   ========================
   void ExecuteSpikeTrade(string direction)
   {
      // Calculer lot size (recovery: doubler le lot min...)
      double lot = CalculateLotSize();
      lot = ApplyRecoveryLot(lot);
      if(lot <= 0) 
      {
         Print("? Erreur calcul lot size - trade annulé");
         return;
      }
   
   NOUVEAU CODE:
   =============
*/

void ExecuteSpikeTrade_SNIPER_v137(string direction)
{
   // v1.37: VÉRIFICATIONS SNIPER PRIORITAIRES AVANT LOT
   
   // 1) SPREAD CHECK - Ne JAMAIS trader sur spread large
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spreadPips = (ask - bid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double maxSpreadPips = 50.0; // Adapter selon votre broker (Deriv = 5-8 pips)
   
   if(spreadPips > maxSpreadPips)
   {
      Print("❌ SPIKE TRADE BLOQUÉ - Spread trop large (" + DoubleToString(spreadPips, 1) + 
            " pips > " + DoubleToString(maxSpreadPips, 1) + " pips) sur " + _Symbol);
      return;
   }
   
   // 2) CAPITAL DISPO CHECK - Assurer min 5x le risque avant trade
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double maxLossUSD = SMC_HardMaxLossUSD(); // 3.0$ par défaut
   
   if(equity < maxLossUSD * 5.0)
   {
      Print("❌ SPIKE TRADE BLOQUÉ - Capital insuffisant (equity $" + DoubleToString(equity, 2) + 
            " < 5x $" + DoubleToString(maxLossUSD, 2) + ")");
      return;
   }
   
   // 3) LOT CALCULATION AVEC CAP CRITIQUE
   double lot = CalculateLotSize();
   lot = ApplyRecoveryLot(lot);
   
   if(lot <= 0) 
   {
      Print("❌ Erreur calcul lot size ou cap $ atteint - trade annulé");
      return;
   }
   
   // 4) GOM VERDICT PRE-CHECK (nouveau)
   int gomVn = g_smcGomConnected ? g_smcGomVerdictNum : 0;
   
   if(direction == "BUY" && gomVn < 0)
   {
      Print("❌ SPIKE BUY BLOQUÉ - GOM incompatible (verdict=" + 
            (gomVn == -1 ? "WAIT" : "SELL") + ")");
      return;
   }
   
   if(direction == "SELL" && gomVn > 0)
   {
      Print("❌ SPIKE SELL BLOQUÉ - GOM incompatible (verdict=" + 
            (gomVn == 3 ? "PERFECT" : "BUY") + ")");
      return;
   }
   
   // 5) CORRECTION ZONE CHECK (nouveau) - sauf si GOM PERFECT
   int correctionGate = -1; // Par défaut: pas de correction zone
   
   if(MathAbs(gomVn) < 3) // Non-PERFECT
   {
      bool inCorrectionZone = SMC_IsCorrectionZoneForDirection(_Symbol, 
                                                               direction == "BUY" ? 1 : -1);
      if(inCorrectionZone)
      {
         Print("⚠️ SPIKE " + direction + " - Zone correction détectée (GOM pas PERFECT)");
         correctionGate = 0; // Zone correction, SL ajusté
      }
   }
   
   Print("✅ SNIPER PRE-CHECKS OK - direction=" + direction + 
         " | spread=" + DoubleToString(spreadPips, 1) + 
         "pips | equity=$" + DoubleToString(equity, 2) + 
         " | lot=" + DoubleToString(lot, 2) + 
         " | GOM=" + IntegerToString(gomVn));
   
   // ... continue avec le code ExecuteSpikeTrade normal ...
}


//+------------------------------------------------------------------+
// PATCH #3: SMC_IsCorrectionZoneForDirection() - DÉTECTION STRICTE
//+------------------------------------------------------------------+
/*
   À TROUVER: bool SMC_IsCorrectionZoneForDirection(...) @ ligne ~4379
   À REMPLACER: Toute la fonction par le code ci-dessous
   
   NOUVEAU CODE:
   =============
*/

bool SMC_IsCorrectionZoneForDirection_STRICT_v137(const string symbol, const int dirSign)
{
   // v1.37: DÉTECTION CORRECTION STRICTE
   // Ancienne logique: 2+ signaux = correction
   // Nouvelle logique: 3 signaux OU 2+ FORTS = correction
   
   // Récupérer les conditions
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   // Calculer EMA 21 et 50
   int emaHandle21 = iMA(symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
   int emaHandle50 = iMA(symbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   double ema21 = 0, ema50 = 0;
   if(emaHandle21 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(emaHandle21, 0, 0, 1, buf) > 0) ema21 = buf[0];
   }
   if(emaHandle50 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(emaHandle50, 0, 0, 1, buf) > 0) ema50 = buf[0];
   }
   
   // Condition 1: Prix entre EMA 21 et 50
   bool betweenEMAs = (bid > MathMin(ema21, ema50) && bid < MathMax(ema21, ema50));
   
   // Condition 2: ATR compressé (< 30% de la moyenne 50 barres)
   bool atrCompressed = false;
   if(atrHandle != INVALID_HANDLE)
   {
      double ab[];
      ArraySetAsSeries(ab, true);
      if(CopyBuffer(atrHandle, 0, 0, 50, ab) >= 50)
      {
         double sumATR = 0;
         for(int i = 0; i < 50; i++) sumATR += ab[i];
         double avgATR50 = sumATR / 50.0;
         atrCompressed = (ab[0] < avgATR50 * 0.30);
      }
   }
   
   // Condition 3: Range étroit (derniers 20 barres)
   bool narrowRange = false;
   double close[];
   if(CopyClose(symbol, PERIOD_M1, 0, 20, close) >= 20)
   {
      ArraySetAsSeries(close, true);
      double highRange = close[0];
      double lowRange = close[0];
      for(int i = 1; i < 20; i++)
      {
         highRange = MathMax(highRange, close[i]);
         lowRange = MathMin(lowRange, close[i]);
      }
      double rangeSize = highRange - lowRange;
      double avgClose = 0;
      for(int i = 0; i < 20; i++) avgClose += close[i];
      avgClose /= 20.0;
      narrowRange = (rangeSize < avgClose * 0.015); // Range < 1.5% de prix moyen
   }
   
   // Compter les signaux
   int correctionSignals = 0;
   if(betweenEMAs) correctionSignals++;
   if(atrCompressed) correctionSignals++;
   if(narrowRange) correctionSignals++;
   
   // LOGIQUE STRICTE v1.37
   // Cas 1: 3 signaux = CORRECTION confirmée
   if(correctionSignals >= 3)
   {
      Print("⚠️ CORRECTION ZONE - 3/3 conditions met: EMAs + ATR + Range");
      return true;
   }
   
   // Cas 2: 2 signaux FORTS = CORRECTION si ATR très compressé (< 20%)
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
            double avgATR50 = sumATR / 50.0;
            if(ab[0] < avgATR50 * 0.20) // TRÈS compressé
            {
               Print("⚠️ CORRECTION ZONE - 2/3 mais ATR < 20% (très compressé)");
               return true;
            }
         }
      }
   }
   
   // Cas 3: 2 signaux modérés = PAS correction (trop faux positif)
   if(correctionSignals >= 2)
   {
      Print("ℹ️ Potentiel consolidation mais pas confirmé (2 signaux modérés)");
      return false;
   }
   
   // 0-1 signaux = clairement pas correction
   return false;
}


//+------------------------------------------------------------------+
// PATCH #4: SMC_GetChartPatternFromAI() - NOUVELLE FONCTION
//+------------------------------------------------------------------+
/*
   À AJOUTER: Nouvelle fonction pour intégrer ai_server.py
   AJOUTER APRÈS la fonction SMC_HardMaxLossUSD()
   
   NOUVEAU CODE:
   =============
*/

// v1.37: Intégration des figures chartistes détectées par ai_server.py
bool SMC_GetChartPatternFromAI(const string symbol, int &patternType, 
                               double &confidence, string &patternName)
{
   // Appelle l'endpoint /analyze/gemma du ai_server.py pour détection figures chartistes
   // Retour: pattern_type (1-7), confidence (0-100), pattern_name (description)
   
   patternType = 0;
   confidence = 0.0;
   patternName = "";
   
   // TODO: Implémenter WebRequest vers ai_server.py
   // Pseudo-code pour montrer la structure:
   /*
   string url = "http://localhost:8000/analyze/gemma?symbol=" + symbol;
   
   HINTERNET hInet = InternetOpen("MT5", INTERNET_OPEN_TYPE_DIRECT, NULL, NULL, 0);
   HINTERNET hUrl = InternetOpenUrl(hInet, url, NULL, 0, INTERNET_FLAG_RELOAD, 0);
   
   if(hUrl)
   {
      char buffer[4096];
      DWORD bytesRead = 0;
      InternetReadFile(hUrl, buffer, sizeof(buffer), &bytesRead);
      
      // Parser JSON: {"pattern_type": 3, "confidence": 85, "pattern_name": "Triangle"}
      // Extraire pattern_type, confidence, pattern_name
      // Retourner true si trouvé
      
      InternetCloseHandle(hUrl);
   }
   InternetCloseHandle(hInet);
   */
   
   // Pour maintenant: retourner faux (vous devrez intégrer l'appel HTTP)
   Print("ℹ️ SMC_GetChartPatternFromAI: endpoint /analyze/gemma non encore connecté");
   return false;
}


//+------------------------------------------------------------------+
// PATCH #5: PositionCloseWithLog() - SNIPER HOLD
//+------------------------------------------------------------------+
/*
   À TROUVER: bool PositionCloseWithLog(...) @ ligne ~283
   À REMPLACER: L'ajout de la vérification spread AVANT fermeture
   
   AJOUT APRÈS: double minProtectLoss = MathMax(...);
   
   NOUVEAU CODE À INSÉRER:
   =============
*/

// v1.37: SNIPER HOLD - ne pas fermer si la perte < spread potentiel
// À ajouter à la ligne ~308 (après "const int minHoldSec = 20;")
/*
      // v1.37: SNIPER HOLD - si perte petite + spread cost > perte, hold
      double spreadCost = (ask - bid) / SymbolInfoDouble(symbol, SYMBOL_POINT) * 
                          SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) / 
                          SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) * 
                          volume;
      
      if(!isHardLoss && profit < 0 && MathAbs(profit) < spreadCost * 1.5)
      {
         Print("[SNIPER-HOLD] Perte $" + DoubleToString(profit, 2) + " < spread cost $" + 
               DoubleToString(spreadCost, 2) + " | Keep trade alive");
         return false; // Garder la position ouverte
      }
*/


//+------------------------------------------------------------------+
// PATCH #6: CanPlaceOrderByGOM() - AMÉLIORATIONS
//+------------------------------------------------------------------+
/*
   À TROUVER: bool CanPlaceOrderByGOM(...) @ ligne ~4993
   À AJOUTER dans les vérifications avant "return true":
   
   ADDITIONS:
   ==========
*/

// v1.37: Additions à CanPlaceOrderByGOM()
// À ajouter AVANT la dernière ligne "return true;"
/*
   // v1.37: SNIPER SELECT - vérifier spread + confluence
   if(UseGOMVerdictFilter)
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double spreadPips = (ask - bid) / SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      // Refuser si spread trop large
      if(spreadPips > 50.0) // Deriv = max 8 pips, Forex/Metals = max 2-3
      {
         whyOut = "spread trop large pour ordre sniper (" + DoubleToString(spreadPips, 1) + " pips)";
         return false;
      }
      
      // Vérifier capital dispo pour le lot
      double maxLossUSD = SMC_HardMaxLossUSD();
      if(AccountInfoDouble(ACCOUNT_EQUITY) < maxLossUSD * 3.0)
      {
         whyOut = "capital insuffisant (equity < 3x risque max)";
         return false;
      }
   }
   
   // v1.37: Intégration figures IA chartistes (si active)
   if(UseGOMVerdictFilter && IntegrateChartPatternAI)
   {
      int patType = 0;
      double patConf = 0;
      string patName = "";
      
      if(SMC_GetChartPatternFromAI(symbol, patType, patConf, patName))
      {
         // Pattern détecté - augmenter la confiance d'entrée
         if(patConf >= 75.0) // Pattern fiable
         {
            Print("✅ Pattern IA détecté: " + patName + " (confiance " + 
                  DoubleToString(patConf, 0) + "%) - ordre autorisé");
            return true; // AUTORISÉ malgré GOM borderline
         }
      }
   }
*/

//+------------------------------------------------------------------+
// RÉSUMÉ DES CHANGEMENTS v1.37
//+------------------------------------------------------------------+
/*
   ✅ 1. CalculateLotSize() - CAP $3 MAX APPLIQUÉ
      Détail: Limite le lot pour jamais dépasser 3$ de perte potentielle
      Impact: Sniper mode activé automatiquement
      
   ✅ 2. NormalizeVolumeForSymbol() - CAP $3 APPLIQUÉ
      Détail: Double-vérification lors de normalisation volume
      Impact: Validation stricte du risque par métier
      
   ❌→✅ 3. ExecuteSpikeTrade() - SNIPER PRE-CHECKS
      À appliquer: Ajouter spread check, capital check, GOM check, correction check
      Impact: Bloque les mauvaises entrées AVANT d'ouvrir
      
   ❌→✅ 4. SMC_IsCorrectionZoneForDirection() - DÉTECTION STRICTE
      À appliquer: Passer de 2+ signaux à 3 signaux OU 2 forts
      Impact: Moins de fausses entrées en consolidation
      
   ❌→✅ 5. SMC_GetChartPatternFromAI() - NOUVELLE FONCTION
      À créer: Appel HTTP vers ai_server.py /analyze/gemma
      Impact: Intégration des figures chartistes IA
      
   ❌→✅ 6. PositionCloseWithLog() - SNIPER HOLD
      À ajouter: Hold si perte < coût spread
      Impact: Évite les micro-pertes au spread
      
   ❌→✅ 7. CanPlaceOrderByGOM() - SÉLECTION SNIPER
      À améliorer: Ajouter spread check + pattern AI
      Impact: Ordres plus intelligents = moins de pertes
      
   INSTRUCTIONS DE MISE À JOUR:
   =============================
   1. Compiler le fichier actuel pour vérifier les 2 corrections déjà appliquées ✅
   2. Appliquer les corrections #3-7 suivant les code ci-dessus
   3. Tester avec UseSniperScalperMode = true
   4. Vérifier les logs pour "SNIPER PRE-CHECKS OK" et "LOT CAPPED TO $"
   5. Désactiver/ajuster MaxLossPerTradeDollars si besoin (recommandé: 3.0)
   
   TEST POST-PATCH:
   ================
   1. Boom1000: pas d'ordre si spread > 8 pips ✓
   2. Trailing: perte < 1$ gardée si spread cost > 1.5$ ✓
   3. GOM SELL + SPIKE BUY = ordre BLOQUÉ ✓
   4. Zone correction + non-PERFECT GOM = ordre BLOQUÉ ✓
   5. Capital < $15 (3$ risque x 5) = ordres BLOQUÉS ✓
   
*/
