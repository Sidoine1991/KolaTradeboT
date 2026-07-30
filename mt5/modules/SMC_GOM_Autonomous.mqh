//+------------------------------------------------------------------+
//| SMC_GOM_Autonomous.mqh — Entrées GOM PERFECT/GOOD (LIMIT + MARKET)|
//| Restaure la stratégie autonome désactivée par le stub SMC_Stubs   |
//+------------------------------------------------------------------+
#ifndef SMC_GOM_AUTONOMOUS_MQH
#define SMC_GOM_AUTONOMOUS_MQH

datetime g_lastGomVerdictExitTime = 0;
string   g_lastSpikeCapturedSymbol = "";
datetime g_lastSpikeCapturedTime   = 0;

void CancelAllGOMPendingOrders(const string symbol)
{
   CancelGOMPendingByTag(symbol, "GOM_LIMIT");
   CancelGOMPendingByTag(symbol, "GOM_GOOD");
   CancelGOMPendingByTag(symbol, "GOM_PERFECT");
   CancelGOMPendingByTag(symbol, "GOM_ALIGN_LIM");
}

void ManageGOMAutonomousStrategy()
{
   if(!GOMPerfectAutoEntry) return;

   if(!SMC_GOMAutonomousAllowed(_Symbol))
      return;

   if(!g_smcGomConnected)
   {
      static datetime s_lastConnLog = 0;
      if(TimeCurrent() - s_lastConnLog >= 30)
      {
         s_lastConnLog = TimeCurrent();
         Print("[GOM-AUTO] En attente connexion ai_server — vn=", g_smcGomVerdictNum, " ", g_smcGomVerdict);
      }
      return;
   }

if(g_smcLastGOMPoll > 0 && (int)(TimeCurrent() - g_smcLastGOMPoll) > 15)
    {
       static datetime s_lastStaleLog = 0;
       if(TimeCurrent() - s_lastStaleLog >= 30)
       {
          s_lastStaleLog = TimeCurrent();
          Print("[GOM-AUTO] STALE verdict (", (int)(TimeCurrent() - g_smcLastGOMPoll),
                "s sans poll) — entrées bloquées | ", _Symbol);
       }
       return;
   }

   static datetime s_lastTry = 0;
   static int s_lastVn = 999;
   int cooldown = 1; // 1s minimum for fast PERFECT reaction

   // WAIT : rien + annuler les ordres GOM en attente
   if(g_smcGomVerdictNum == 0)
   {
      if(s_lastVn != 0)
         CancelAllGOMPendingOrders(_Symbol);
      s_lastVn = 0;
      return;
   }

   if(s_lastVn != 999)
   {
      int prevSign = (s_lastVn > 0) ? 1 : ((s_lastVn < 0) ? -1 : 0);
      int curSign  = (g_smcGomVerdictNum > 0) ? 1 : ((g_smcGomVerdictNum < 0) ? -1 : 0);
      if(prevSign != 0 && curSign != 0 && prevSign != curSign)
         CancelGOMPendingByTag(_Symbol, "GOM_LIMIT");
   }
   s_lastVn = g_smcGomVerdictNum;

   int alignDir = (g_smcGomVerdictNum > 0) ? 1 : -1;
   if(GOMAlignLimitAuto && GOM_EntryAlignmentOK(alignDir))
      return;

   int reentryCd = SMC_GOMReentryCooldownSec();
   if(g_lastGomVerdictExitTime > 0 && TimeCurrent() - g_lastGomVerdictExitTime < reentryCd)
      return;

   if(TimeCurrent() - s_lastTry < cooldown)
      return;

   if(CountPositionsForSymbol(_Symbol) > 0)
      return;
   if(CountOpenLimitOrdersTerminal() >= MaxLimitOrdersTerminal)
      return;

   if(SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH
      && g_lastSpikeCapturedSymbol == _Symbol && g_lastSpikeCapturedTime > 0)
   {
      int elapsedSpike = (int)(TimeCurrent() - g_lastSpikeCapturedTime);
      if(elapsedSpike < 60) return;
      int smallBars = SMC_CountSmallM1BarsAfterTime(_Symbol, g_lastSpikeCapturedTime);
      if(smallBars < PostSpikeMinSmallCandles) return;
   }

   int perfectDir = SMCGP_GOMPerfectDirection();
   int goodDir    = SMCGP_GOMGoodDirection();

   bool isPerfect = (perfectDir != 0);
   if(!isPerfect && !GOM_EntryCoherenceOK())
      return;

   double atrVal = GOM_GetATRValue();
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return;

   // Blink obligatoire pour PERFECT (synchronisé avec affichage graphique)
   if(perfectDir != 0)
   {
      if(!IsSignalConfirmed() || GetConfirmedSignalDir() != perfectDir)
         return;
   }

   // --- PERFECT : LIMIT sur S/R proche, MARKET si prix déjà sur niveau ---
   if(perfectDir != 0)
   {
      CancelGOMPendingByTag(_Symbol, "GOM_LIMIT");
      string direction = (perfectDir == 1) ? "BUY" : "SELL";
      if(!IsDirectionAllowedForBoomCrash(_Symbol, direction))
         return;

      if(!SMCGP_GOMAllowsDirectionEx(perfectDir, false))
         return;

      s_lastTry = TimeCurrent();

      string levelSource = "";
      double refPrice = (perfectDir == 1) ? ask : bid;
      double entryLvl = (perfectDir == 1)
         ? GetClosestBuyLevel(refPrice, atrVal, PreciseLimitMaxDistATR, levelSource)
         : GetClosestSellLevel(refPrice, atrVal, PreciseLimitMaxDistATR, levelSource);

      double nearTol = MathMax(atrVal * 0.35, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
      bool atLevel = (entryLvl > 0 && MathAbs(refPrice - entryLvl) <= nearTol);

      if(atLevel && PlaceGOMMarketOrder(direction, "GOM_PERFECT", levelSource))
      {
         Print("[GOM-PERFECT] MARKET ", direction, " @ ", levelSource);
         return;
      }
      if(entryLvl > 0 && PlaceGOMLimitAtLevel(direction, "GOM_PERFECT", entryLvl, levelSource))
      {
         Print("[GOM-PERFECT] LIMIT ", direction, " @ ", levelSource, " | vn=", g_smcGomVerdictNum);
         return;
      }
      if(GOMAlignMarketFallback && PlaceGOMMarketOrder(direction, "GOM_PERFECT", "fallback_mkt"))
      {
         Print("[GOM-PERFECT] MARKET fallback ", direction, " | vn=", g_smcGomVerdictNum);
         return;
      }
      Print("[GOM-PERFECT] Échec placement — vn=", g_smcGomVerdictNum, " niveau=", entryLvl);
      return;
   }

   // --- GOOD : entrée marché sur pullback support/résistance ---
   if(goodDir != 0)
   {
      CancelGOMPendingByTag(_Symbol, "GOM_LIMIT");
      string direction = (goodDir == 1) ? "BUY" : "SELL";
      if(!IsDirectionAllowedForBoomCrash(_Symbol, direction)) return;

if(!SMCGP_GOMAllowsDirectionEx(goodDir, false)) return;

      if(SMC_IsSyntheticAutonomousSym(_Symbol) && GOM_EntryAlignmentOK(goodDir))
      {
         if(GOMAlignLimitAuto) return;
         s_lastTry = TimeCurrent();
         string levelSource = "";
         double refPrice = (goodDir == 1) ? ask : bid;
         double entryLvl = (goodDir == 1)
            ? GetClosestBuyLevel(refPrice, atrVal, PreciseLimitMaxDistATR, levelSource)
            : GetClosestSellLevel(refPrice, atrVal, PreciseLimitMaxDistATR, levelSource);
         double nearTol = MathMax(atrVal * 0.35, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
         if(entryLvl > 0 && MathAbs(refPrice - entryLvl) <= nearTol)
         {
            if(PlaceGOMMarketOrder(direction, "GOM_GOOD", levelSource))
               Print("[GOM-GOOD] MARKET triple-align ", direction, " @ ", levelSource);
         }
         else if(entryLvl > 0 && PlaceGOMLimitAtLevel(direction, "GOM_GOOD", entryLvl, levelSource))
            Print("[GOM-GOOD] LIMIT triple-align ", direction, " @ ", levelSource);
         return;
      }

double refPrice = (goodDir == 1) ? ask : bid;
      string levelSource = "";
      double entryLvl = (goodDir == 1)
         ? GetClosestBuyLevel(refPrice, atrVal, PreciseLimitMaxDistATR, levelSource)
         : GetClosestSellLevel(refPrice, atrVal, PreciseLimitMaxDistATR, levelSource);
      if(entryLvl <= 0) return;

      bool isSynthetic = (SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH);
      double tolMult   = isSynthetic ? 2.0 : 0.5;
      double zoneTol   = MathMax(atrVal * tolMult, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
      bool atLevel = (MathAbs(refPrice - entryLvl) <= zoneTol);

      s_lastTry = TimeCurrent();
      if(atLevel && PlaceGOMMarketOrder(direction, "GOM_GOOD", levelSource))
      {
         Print("[GOM-GOOD] MARKET pullback ", direction, " @ ", levelSource);
         return;
      }
      if(PlaceGOMLimitAtLevel(direction, "GOM_GOOD", entryLvl, levelSource))
         Print("[GOM-GOOD] LIMIT pullback ", direction, " @ ", levelSource);
   }
}

bool TryExecuteGOMPerfectEntry()
{
   ManageGOMAutonomousStrategy();
   return false;
}

#endif
