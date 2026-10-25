//+------------------------------------------------------------------+
//| SMC_DowTouchEntry.mqh - Entry on DOW Trendline Touch              |
//| FIX 2026-09-20 (Sidoine) : Stratégie d'entrée précise sur touch    |
//| de trendline DOW pour synthétiques (PainX, GainX, Boom, Crash)     |
//| Basée sur l'observation historique : la majorité des spikes sur     |
//| PainX 999 respectent le touch de la trendline DOW en M1           |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
// Variables globales pour le suivi de l'état
static bool   g_dteInitialized = false;
static double g_dteTrendlinePrice = 0.0;
static int    g_dteDirection = 0;  // +1 BUY, -1 SELL
static datetime g_dteArmedSince = 0;
static ulong  g_dtePendingTicket = 0;

// Les paramètres sont définis dans SMC_Universal.mq5 comme inputs
 // Use the existing definitions directly

//+------------------------------------------------------------------+
//| Initialisation du module                                          |
//+------------------------------------------------------------------+
void SMC_DTE_Init()
{
   g_dteInitialized = true;
   g_dteTrendlinePrice = 0.0;
   g_dteDirection = 0;
   g_dteArmedSince = 0;
   g_dtePendingTicket = 0;
   Print("📐 DOW TOUCH ENTRY - Initialisé");
}

//+------------------------------------------------------------------+
//| Cleanup du module                                                 |
//+------------------------------------------------------------------+
void SMC_DTE_Deinit()
{
   if(g_dtePendingTicket > 0)
   {
      if(OrderSelect(g_dtePendingTicket))
         trade.OrderDelete(g_dtePendingTicket);
   }
   g_dteInitialized = false;
   Print("📐 DOW TOUCH ENTRY - Nettoyé");
}

//+------------------------------------------------------------------+
//| Récupérer le prix de la trendline DOW depuis les données          |
//| (calculé localement via fractals et swings)                       |
//+------------------------------------------------------------------+
double SMC_DTE_GetDowTrendlinePrice(const string symbol)
{
   // FIX 2026-09-22: priorité à la DOW officielle de l'EA (projected / EP)
   if(g_dowState.active)
   {
      if(g_dowState.projectedPrice > 0.0)
         return g_dowState.projectedPrice;
      if(g_dowState.currentEpPrice > 0.0)
         return g_dowState.currentEpPrice;
   }

   // Fallback: fractals / swings locaux
   // 1. Récupérer les derniers fractals significatifs
   MqlRates rates[];
   int barsToCheck = 100;  // Analyser les 100 dernières bougies M1
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(symbol, PERIOD_M1, 0, barsToCheck, rates) < barsToCheck)
      return 0.0;
   
   // 2. Détecter les points hauts et bas (swings)
   double highs[];
   double lows[];
   datetime highTimes[];
   datetime lowTimes[];
   
   ArrayResize(highs, 0);
   ArrayResize(lows, 0);
   ArrayResize(highTimes, 0);
   ArrayResize(lowTimes, 0);
   
   // Détection simple : un swing haut si la bougie est plus haute que les N voisines
   int swingPeriod = 5;  // Période de détection des swings
   
   for(int i = swingPeriod; i < barsToCheck - swingPeriod; i++)
   {
      bool isSwingHigh = true;
      bool isSwingLow = true;
      
      for(int j = 1; j <= swingPeriod; j++)
      {
         if(rates[i].high <= rates[i+j].high || rates[i].high <= rates[i-j].high)
            isSwingHigh = false;
         if(rates[i].low >= rates[i+j].low || rates[i].low >= rates[i-j].low)
            isSwingLow = false;
      }
      
      if(isSwingHigh)
      {
         int size = ArraySize(highs);
         ArrayResize(highs, size + 1);
         ArrayResize(highTimes, size + 1);
         highs[size] = rates[i].high;
         highTimes[size] = rates[i].time;
      }
      
      if(isSwingLow)
      {
         int size = ArraySize(lows);
         ArrayResize(lows, size + 1);
         ArrayResize(lowTimes, size + 1);
         lows[size] = rates[i].low;
         lowTimes[size] = rates[i].time;
      }
   }
   
   // 3. Déterminer la direction Dow (haussière ou baissière)
    bool dowBullish = !g_dowState.isBearish;
    bool dowBearish = g_dowState.isBearish;
   
   if(!dowBullish && !dowBearish)
      return 0.0;  // Direction Dow indéterminée
   
   // 4. Calculer la trendline basée sur la direction Dow
   double trendlinePrice = 0.0;
   
   if(dowBullish && ArraySize(lows) >= 2)
   {
      // Trendline haussière : connecter les derniers 2 points bas
      int n = ArraySize(lows);
      double x1 = (double)lowTimes[n-2];
      double y1 = lows[n-2];
      double x2 = (double)lowTimes[n-1];
      double y2 = lows[n-1];
      double xCurrent = (double)rates[0].time;
      
      // Équation de la droite : y = mx + b
      double m = (y2 - y1) / (x2 - x1);
      double b = y1 - m * x1;
      trendlinePrice = m * xCurrent + b;
   }
   else if(dowBearish && ArraySize(highs) >= 2)
   {
      // Trendline baissière : connecter les derniers 2 points hauts
      int n = ArraySize(highs);
      double x1 = (double)highTimes[n-2];
      double y1 = highs[n-2];
      double x2 = (double)highTimes[n-1];
      double y2 = highs[n-1];
      double xCurrent = (double)rates[0].time;
      
      // Équation de la droite : y = mx + b
      double m = (y2 - y1) / (x2 - x1);
      double b = y1 - m * x1;
      trendlinePrice = m * xCurrent + b;
   }
   
   // 5. Valider la trendline (doit être proche du prix actuel)
   if(trendlinePrice > 0.0)
   {
      double currentPrice = rates[0].close;
      double atr = 0.0;
      
      // Calculer ATR pour validation
      if(atrM1 != INVALID_HANDLE)
         atr = SCH1_GetATRAt(atrM1, 0);
      
      if(atr > 0.0)
      {
         double distance = MathAbs(currentPrice - trendlinePrice);
         double maxDistance = atr * 2.0;  // Tolérance : 2x ATR
         
         if(distance > maxDistance)
            return 0.0;  // Trendline trop loin, non valide
      }
   }
   
   return trendlinePrice;
}

//+------------------------------------------------------------------+
//| Détecter si le prix touche la trendline DOW                       |
//+------------------------------------------------------------------+
bool SMC_DTE_IsPriceNearTrendline(const string symbol, double trendlinePrice, double tolerance)
{
   if(trendlinePrice <= 0.0) return false;
   
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(point <= 0.0) return false;
   
   double tolerancePrice = tolerance * point;
   
   // Vérifier si bid ou ask est dans la tolérance
   bool bidNear = (MathAbs(bid - trendlinePrice) <= tolerancePrice);
   bool askNear = (MathAbs(ask - trendlinePrice) <= tolerancePrice);
   
   return bidNear || askNear;
}

//+------------------------------------------------------------------+
//| Calculer le prix d'entrée pour l'ordre LIMIT                      |
//+------------------------------------------------------------------+
double SMC_DTE_CalculateEntryPrice(const string symbol, double trendlinePrice, int direction, double distance)
{
   if(trendlinePrice <= 0.0) return 0.0;
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0) return 0.0;
   
   double distancePrice = distance * point;
   
   // Pour BUY : placer LIMIT en-dessous de la trendline
   // Pour SELL : placer LIMIT au-dessus de la trendline
   if(direction > 0)  // BUY
      return trendlinePrice - distancePrice;
   else if(direction < 0)  // SELL
      return trendlinePrice + distancePrice;
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Vérifier les conditions pour armer l'entrée DOW touch             |
//+------------------------------------------------------------------+
bool SMC_DTE_CanArmEntry(const string symbol, int direction)
{
   // 1. Module activé
   if(!UseDowTouchEntry) return false;
   
   // 2. Synthétiques PainX/GainX/Boom/Crash uniquement
   if(!SMC_IsSpikeStyleSymbol(symbol)) return false;

   // 3. DOW active et non cassée (sinon pas de touch fiable)
   if(!g_dowState.active || g_dowState.broken) return false;
   
   // 4. Verdict GOM GOOD/PERFECT aligné avec la direction
   if(!g_smcGomConnected) return false;
   if(MathAbs(g_smcGomVerdictNum) < 2) return false;  // GOOD/PERFECT requis
   if(direction > 0 && g_smcGomVerdictNum < 2) return false;
   if(direction < 0 && g_smcGomVerdictNum > -2) return false;
   
   // 5. Alignement M1 + M5 strict (même sens que l'entrée)
   string m1Dir = (StringLen(g_smcTfM1DirLive) > 0) ? g_smcTfM1DirLive : g_smcTfM1Dir;
   string m5Dir = g_smcTfM5Dir;
   StringToUpper(m1Dir);
   StringToUpper(m5Dir);
   
   bool m1Ok = (direction > 0 && (StringFind(m1Dir, "BULL") >= 0 || m1Dir == "BUY" || m1Dir == "UP")) ||
               (direction < 0 && (StringFind(m1Dir, "BEAR") >= 0 || m1Dir == "SELL" || m1Dir == "DOWN"));
   bool m5Ok = (direction > 0 && (StringFind(m5Dir, "BULL") >= 0 || m5Dir == "BUY" || m5Dir == "UP")) ||
               (direction < 0 && (StringFind(m5Dir, "BEAR") >= 0 || m5Dir == "SELL" || m5Dir == "DOWN"));
   
   if(!m1Ok || !m5Ok)
   {
      static datetime s_m1m5Log = 0;
      if(TimeCurrent() - s_m1m5Log >= 30)
      {
         s_m1m5Log = TimeCurrent();
         Print("[DOW-TOUCH] skip arm — M1/M5 non alignés | M1=", m1Dir, " M5=", m5Dir,
               " dir=", (direction > 0 ? "BUY" : "SELL"));
      }
      return false;
   }
   
   // 6. Alignement DOW
   bool dowBearish = g_dowState.isBearish;
   bool dowBullish = !g_dowState.isBearish;
   
   if(direction > 0 && dowBearish) return false;  // BUY contre Dow BEAR
   if(direction < 0 && dowBullish) return false;  // SELL contre Dow BULL
   
   // 7. Pas de position déjà ouverte (ce symbole)
   if(CountPositionsForSymbol(symbol) > 0) return false;
   
   // 7. Vérifier si aucun ordre LIMIT n'est déjà en attente
   if(g_dtePendingTicket > 0)
   {
      if(OrderSelect(g_dtePendingTicket))
      {
         if(OrderGetInteger(ORDER_STATE) == ORDER_STATE_PLACED)
            return false;  // Ordre déjà en attente
      }
      else
      {
         g_dtePendingTicket = 0;  // Ordre n'existe plus, reset
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Placer un ordre LIMIT près de la trendline DOW                    |
//+------------------------------------------------------------------+
bool SMC_DTE_PlaceLimitOrder(const string symbol, int direction, double entryPrice, double sl, double tp, double lot)
{
   if(entryPrice <= 0.0) return false;

   ENUM_ORDER_TYPE ot = (direction > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   // Gate unique: anti-hedge, DOW HARD, GOM LIVE, famille Boom/Crash
   if(!SMC_FinalOpenGate(symbol, ot))
   {
      Print("🔒 DOW TOUCH LIMIT bloqué par FinalOpenGate : ", symbol,
            " ", (direction > 0 ? "BUY" : "SELL"));
      return false;
   }
   
   MqlTradeRequest req = {};
   MqlTradeResult res = {};
   
   req.action = TRADE_ACTION_PENDING;
   req.symbol = symbol;
   req.volume = lot;
   req.deviation = 10;
   req.magic = InpMagicNumber;
   req.comment = "DOW TOUCH ENTRY";
   
   if(direction > 0)  // BUY
   {
      req.type = ORDER_TYPE_BUY_LIMIT;
      req.price = entryPrice;
      req.sl = sl;
      req.tp = tp;
   }
   else if(direction < 0)  // SELL
   {
      req.type = ORDER_TYPE_SELL_LIMIT;
      req.price = entryPrice;
      req.sl = sl;
      req.tp = tp;
   }
   
   if(SafeOrderSend(req, res, "DOW TOUCH LIMIT"))
   {
      g_dtePendingTicket = res.order;
      g_dteArmedSince = TimeCurrent();
      Print("✅ DOW TOUCH LIMIT placé : ", symbol, " ", 
            (direction > 0 ? "BUY" : "SELL"),
            " @ ", DoubleToString(entryPrice, _Digits),
            " | Ticket: ", res.order);
      return true;
   }
   else
   {
      Print("❌ Échec placement DOW TOUCH LIMIT : ", symbol, " | code: ", res.retcode);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Mise à jour principale - appelée depuis OnTick                     |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| DTE REVIVAL (v1.52) — rejaillissement DOW depuis la correction   |
//| Observation trader (2026-10-12): en GOOD/PERFECT COHERENT, apres |
//| correction, le prix vient toucher la DOW line et rejaillit.      |
//| Entree MARKET au contact si: verdict>=2 + coherence>=seuil +     |
//| bougie M1 fermee dans le sens du verdict qui a explore la bande  |
//| TL. EXEMPT des gates M1/M5 (le rebond EST la confirmation). SL   |
//| STRUCTUREL sous/sur la ligne. OFF par defaut + cap journalier.   |
//+------------------------------------------------------------------+
void SMC_DTE_RevivalTick(const string symbol)
{
   if(!DTE_RevivalEnable) return;              // kill-switch (tuer le pattern si non payant)
   if(!g_dteInitialized || !UseDowTouchEntry) return;
   if(!SMC_IsSpikeStyleSymbol(symbol)) return;
   if(!g_dowState.active || g_dowState.broken) return;
   if(CountPositionsForSymbol(symbol) > 0) return;
   if(g_dtePendingTicket > 0) return;

   int direction = 0;
   if(!g_dowState.isBearish && g_smcGomVerdictNum > 0) direction = 1;
   else if(g_dowState.isBearish && g_smcGomVerdictNum < 0) direction = -1;
   if(direction == 0) return;
   if(MathAbs(g_smcGomVerdictNum) < 2) return;                    // GOOD/PERFECT requis
   if(g_smcGomCoherence < (double)DTE_RevivalCoherence) return;   // lecon #643725888: conviction SANS coherence = piege

   double tl = SMC_DTE_GetDowTrendlinePrice(symbol);
   if(tl <= 0.0) return;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double band  = (double)DTE_RevivalTlBandPts * point;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0) return;
   double px = (direction > 0) ? ask : bid;
   if(MathAbs(px - tl) > band) return;                            // pas au contact de la ligne

   // Rebond CONFIRME: bougie M1 close dans le sens du verdict + elle a
   // explore la bande TL (le touch provient de CETTE bougie)
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 3, r) < 3) return;
   bool closedInDir = (direction > 0) ? (r[1].close > r[1].open) : (r[1].close < r[1].open);
   bool probedTL    = (direction > 0) ? (r[1].low  <= tl + band) : (r[1].high >= tl - band);
   if(!closedInDir || !probedTL) return;

   // Cap journalier
   static int      s_revCount = 0;
   static datetime s_revDay   = 0;
   MqlDateTime dtn; TimeToStruct(TimeCurrent(), dtn);
   datetime dayStamp = (datetime)(dtn.year * 1000000 + dtn.mon * 10000 + dtn.day * 100);
   if(s_revDay != dayStamp) { s_revDay = dayStamp; s_revCount = 0; }
   if(s_revCount >= DTE_RevivalMaxPerDay) return;

   // SL STRUCTUREL sous/sur la DOW line (et jamais plus loin que 1.5 ATR du prix)
   double atr = 0.0;
   if(atrM1 != INVALID_HANDLE) atr = SCH1_GetATRAt(atrM1, 0);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double sl, tp;
   if(direction > 0)
   {
      sl = NormalizeDouble(MathMin(tl - band, px - atr * 1.5), digits);
      tp = NormalizeDouble(px + MathMax(atr * 3.0, px - sl), digits);
   }
   else
   {
      sl = NormalizeDouble(MathMax(tl + band, px + atr * 1.5), digits);
      tp = NormalizeDouble(px - MathMax(atr * 3.0, sl - px), digits);
   }
   double lot = CalculateLotSize();
   if(lot <= 0.0) return;

   MqlTradeResult mres;
   if(SMC_MarketDealSend(symbol, direction, lot, sl, tp, "DTE-REVIVAL", mres))
   {
      s_revCount++;
      Print("🎯 DTE-REVIVAL ", symbol, " ", (direction > 0 ? "BUY" : "SELL"),
            " au contact DOW TL=", DoubleToString(tl, digits),
            " | vn=", g_smcGomVerdictNum,
            " coh=", DoubleToString(g_smcGomCoherence, 0), "%",
            " | rebond M1 confirmé (", TimeToString(r[1].time, TIME_MINUTES), ")",
            " | ", s_revCount, "/", DTE_RevivalMaxPerDay, " aujourd'hui");
   }
}

void SMC_DTE_Update(const string symbol)
{
   if(!g_dteInitialized) return;
   if(!UseDowTouchEntry) return;
   
   // Nettoyer les ordres expirés
   if(g_dtePendingTicket > 0)
   {
      if(OrderSelect(g_dtePendingTicket))
      {
         int state = (int)OrderGetInteger(ORDER_STATE);
         if(state != ORDER_STATE_PLACED)
         {
            g_dtePendingTicket = 0;
            g_dteArmedSince = 0;
         }
         else
         {
            // Vérifier timeout
            int elapsed = (int)(TimeCurrent() - g_dteArmedSince);
            if(elapsed >= DowTouchTimeoutSec)
            {
               trade.OrderDelete(g_dtePendingTicket);
               g_dtePendingTicket = 0;
               g_dteArmedSince = 0;
               Print("⏰ DOW TOUCH LIMIT expiré (timeout) : ", symbol);
            }
         }
      }
      else
      {
         g_dtePendingTicket = 0;
         g_dteArmedSince = 0;
      }
   }
   
   // Récupérer le prix de la trendline
   double trendlinePrice = SMC_DTE_GetDowTrendlinePrice(symbol);
   if(trendlinePrice <= 0.0) return;  // Trendline non disponible

   // v1.27: 1er rebond MARKET même si GOM=WAIT (direction = DOW native)
   if(g_dowState.active && !g_dowState.broken)
   {
      double atrB = g_dowState.currentATR;
      if(atrB <= 0.0 && atrM1 != INVALID_HANDLE)
         atrB = SCH1_GetATRAt(atrM1, 0);
      if(atrB > 0.0)
         Dow_TryFirstBounceMarket(g_dowState.isBearish, atrB);
      if(CountPositionsForSymbol(symbol) > 0) return;
   }

   // v1.52: mode REVIVAL — rejaillissement depuis la correction au contact DOW
   SMC_DTE_RevivalTick(symbol);

   // LIMIT seulement si GOM GOOD/PERFECT aligné (pas de LIMIT sous WAIT)
   int direction = 0;
    if(!g_dowState.isBearish && g_smcGomVerdictNum > 0)
       direction = 1;
    else if(g_dowState.isBearish && g_smcGomVerdictNum < 0)
       direction = -1;
   
   if(direction == 0) return;
   
   // Vérifier si on peut armer une nouvelle entrée
   if(SMC_DTE_CanArmEntry(symbol, direction))
   {
      // Calculer le prix d'entrée
      double entryPrice = SMC_DTE_CalculateEntryPrice(
         symbol, 
         trendlinePrice, 
         direction, 
         DowTouchDistancePoints
      );
      
      if(entryPrice <= 0.0) return;
      
      // Calculer SL/TP (utiliser la logique existante de l'EA)
      double atr = 0.0;
      if(atrM1 != INVALID_HANDLE)
         atr = SCH1_GetATRAt(atrM1, 0);
      
      double sl = 0.0, tp = 0.0;
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      
      if(atr > 0.0)
      {
         if(direction > 0)  // BUY
         {
            sl = NormalizeDouble(entryPrice - atr * 1.5, digits);
            tp = NormalizeDouble(entryPrice + atr * 3.0, digits);
         }
         else  // SELL
         {
            sl = NormalizeDouble(entryPrice + atr * 1.5, digits);
            tp = NormalizeDouble(entryPrice - atr * 3.0, digits);
         }
      }
      
      // Calculer le lot
      double lot = CalculateLotSize();
      if(lot <= 0.0) return;
      
      // Placer l'ordre LIMIT
      SMC_DTE_PlaceLimitOrder(symbol, direction, entryPrice, sl, tp, lot);
   }
}

//+------------------------------------------------------------------+
//| Système de backtest - simuler les entrées sur touch DOW           |
//| (à implémenter avec des données historiques)                      |
//+------------------------------------------------------------------+
struct DTE_BacktestResult
{
   int totalTrades;
   int winningTrades;
   int losingTrades;
   double totalProfit;
   double maxDrawdown;
   double winRate;
   double avgProfitPerTrade;
};

DTE_BacktestResult SMC_DTE_Backtest(const string symbol, datetime startDate, datetime endDate)
{
   DTE_BacktestResult result;
   ZeroMemory(result);
   
   // FIX 2026-09-20: Le backtest nécessite l'accès aux données historiques
   // de la trendline DOW et des prix. Cette fonction sera implémentée
   // dans une version future avec :
   // 1. Chargement des données historiques M1
   // 2. Reconstruction de la trendline DOW pour chaque période
   // 3. Simulation des entrées sur touch
   // 4. Calcul des statistiques de performance
   
   Print("⚠️ DOW TOUCH BACKTEST - Non implémenté (nécessite données historiques trendline)");
   
   return result;
}
