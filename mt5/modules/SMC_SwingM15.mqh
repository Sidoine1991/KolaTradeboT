//+------------------------------------------------------------------+
//| SMC_SwingM15.mqh - Swing Trading Strategy M15 with Fixed $3 SL    |
//| Intégration dans l'architecture SMC_Universal                     |
//+------------------------------------------------------------------+
#ifndef SMC_SWING_M15_MQH
#define SMC_SWING_M15_MQH

#include "SMC_MarketRegime.mqh"
#include <Trade/Trade.mqh>

// ═══════════════════════════════════════════════════════════════════
// INPUTS (définis dans SMC_Universal.mq5 - préfixe SWING_)
// ═══════════════════════════════════════════════════════════════════
// NOTE: Ces inputs doivent être ajoutés dans SMC_Universal.mq5
/*
input group "=== SWING M15 STRATEGY ==="
input bool   SWING_Enable              = false;  // Activer stratégie Swing M15
input double SWING_FixedSL_Dollars    = 3.0;    // Stop Loss fixe en dollars
input double SWING_RR_Ratio            = 2.0;    // Risk/Reward ratio (TP = SL * RR)
input int    SWING_SwingStrength       = 3;      // Force des pivots swing
input int    SWING_MinSwings           = 2;      // Nombre min de swings pour confirmer tendance
input double SWING_MinTrendStrength    = 60.0;   // Force tendance min (0-100)
input double SWING_EntryPullbackPct    = 38.2;   // Retracement Fib pour entrée (38.2%)
input bool   SWING_UseTrailingStop     = true;   // Activer trailing stop
input double SWING_TrailActivationPct  = 50.0;   // Activation trailing à X% du TP
input double SWING_TrailStepPct        = 25.0;   // Pas trailing (en % du SL)
input int    SWING_MaxPositions        = 2;      // Max positions simultanées Swing
input int    SWING_CooldownBars       = 5;      // Cooldown en bougies M15 entre entrées
*/

// ═══════════════════════════════════════════════════════════════════
// STRUCTURES
// ═══════════════════════════════════════════════════════════════════
struct SwingSignal
{
   bool        valid;
   int         direction;           // +1 BUY, -1 SELL
   double      entryPrice;
   double      slPrice;
   double      tpPrice;
   double      lotSize;
   string      reason;
   double      confidence;
   datetime    signalTime;
};

struct SwingPosition
{
   ulong       ticket;
   string      symbol;
   int         direction;
   double      entryPrice;
   double      slPrice;
   double      tpPrice;
   double      initialSL;
   datetime    openTime;
   bool        trailingActive;
};

// ═══════════════════════════════════════════════════════════════════
// VARIABLES GLOBALES
// ═══════════════════════════════════════════════════════════════════
SwingPosition g_swingPositions[];
datetime      g_swingLastEntryBar = 0;
int            g_swingLastEntryDir = 0;

// ═══════════════════════════════════════════════════════════════════
// FONCTIONS
// ═══════════════════════════════════════════════════════════════════

//+------------------------------------------------------------------+
//| Calculer la taille de position pour un SL fixe en dollars         |
//+------------------------------------------------------------------+
double SWING_CalculateLotSizeForFixedSL(const string symbol, const double slDollars, const double slPips)
{
   if(slPips <= 0.0 || slDollars <= 0.0) return 0.0;
   
   double pipValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(pipValue <= 0.0 || tickSize <= 0.0) return 0.0;
   
   // SL en ticks
   double slTicks = slPips / tickSize;
   if(slTicks <= 0.0) return 0.0;
   
   // Lot size = SL_dollars / (SL_ticks * tick_value)
   double lotSize = slDollars / (slTicks * pipValue);
   
   // Normaliser au step du symbole
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = MathFloor(lotSize / stepLot) * stepLot;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Analyser la structure swing M15                                   |
//+------------------------------------------------------------------+
bool SWING_AnalyzeSwingStructure(const string symbol, int &direction, double &entryLevel, string &reason)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Récupérer 100 bougies M15
   if(CopyRates(symbol, PERIOD_M15, 0, 100, rates) < 50) return false;
   
   int strength = 3; // Force des pivots
   double lastHH = 0, lastHL = 0, lastLH = 0, lastLL = 0;
   
   // Utiliser la fonction existante de MarketRegime
   int bias = MR_StructureBias(rates, strength, lastHH, lastHL, lastLH, lastLL);
   
   if(bias == 0)
   {
      reason = "Structure indéterminée";
      return false;
   }
   
   direction = bias;
   
   // Calculer le niveau d'entrée sur retracement Fib
   double range = 0.0;
   if(bias > 0 && lastLL > 0.0 && lastHH > 0.0)
   {
      // Tendance haussière: entrée sur retracement de lastHH vers lastLL
      range = lastHH - lastLL;
      entryLevel = lastHH - (range * 0.382); // Retracement 38.2%
      reason = "Tendance haussière HH/HL - Entrée sur retracement 38.2%";
   }
   else if(bias < 0 && lastLH > 0.0 && lastLL > 0.0)
   {
      // Tendance baissière: entrée sur retracement de lastLL vers lastLH
      range = lastLH - lastLL;
      entryLevel = lastLL + (range * 0.382); // Retracement 38.2%
      reason = "Tendance baissière LH/LL - Entrée sur retracement 38.2%";
   }
   
   if(entryLevel <= 0.0)
   {
      reason = "Niveau d'entrée invalide";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculer SL/TP pour Swing M15                                     |
//+------------------------------------------------------------------+
bool SWING_CalculateLevels(const string symbol, const int direction, const double entryPrice,
                           const double slDollars, const double rrRatio,
                           double &slPrice, double &tpPrice, double &slPips)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(point <= 0.0) return false;
   
   // Calculer le SL en pips pour atteindre slDollars
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue <= 0.0 || tickSize <= 0.0) return false;
   
   // SL en ticks = slDollars / tick_value
   double slTicks = slDollars / tickValue;
   slPips = slTicks * tickSize;
   
   if(direction > 0)
   {
      slPrice = entryPrice - slPips;
      tpPrice = entryPrice + (slPips * rrRatio);
   }
   else
   {
      slPrice = entryPrice + slPips;
      tpPrice = entryPrice - (slPips * rrRatio);
   }
   
   slPrice = NormalizeDouble(slPrice, digits);
   tpPrice = NormalizeDouble(tpPrice, digits);
   
   return true;
}

//+------------------------------------------------------------------+
//| Générer un signal Swing M15                                       |
//+------------------------------------------------------------------+
SwingSignal SWING_GenerateSignal(const string symbol)
{
   SwingSignal signal;
   ZeroMemory(signal);
   
   signal.valid = false;
   signal.signalTime = TimeCurrent();
   
   // Analyser la structure
   int direction = 0;
   double entryLevel = 0.0;
   string reason = "";
   
   if(!SWING_AnalyzeSwingStructure(symbol, direction, entryLevel, reason))
   {
      signal.reason = reason;
      return signal;
   }
   
   // Vérifier le cooldown
   MqlRates m15Rates[];
   ArraySetAsSeries(m15Rates, true);
   if(CopyRates(symbol, PERIOD_M15, 0, 10, m15Rates) >= 5)
   {
      datetime currentBar = m15Rates[0].time;
      if(g_swingLastEntryBar == currentBar && g_swingLastEntryDir == direction)
      {
         signal.reason = "Cooldown actif - déjà entré sur cette bougie";
         return signal;
      }
   }
   
   // Vérifier que le prix est proche du niveau d'entrée
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double currentPrice = (bid + ask) * 0.5;
   
   double atr = MR_GetATR(symbol, PERIOD_M15, 14);
   if(atr <= 0.0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 100.0;
   
   // Tolérance: 0.5 ATR autour du niveau d'entrée
   if(MathAbs(currentPrice - entryLevel) > atr * 0.5)
   {
      signal.reason = "Prix trop éloigné du niveau d'entrée";
      return signal;
   }
   
   // Calculer SL/TP
   double slPrice = 0.0, tpPrice = 0.0, slPips = 0.0;
   double slDollars = 3.0; // SL fixe de 3$
   double rrRatio = 2.0;  // RR 2:1 par défaut
   
   if(!SWING_CalculateLevels(symbol, direction, entryLevel, slDollars, rrRatio, slPrice, tpPrice, slPips))
   {
      signal.reason = "Erreur calcul SL/TP";
      return signal;
   }
   
   // Calculer taille de position
   double lotSize = SWING_CalculateLotSizeForFixedSL(symbol, slDollars, slPips);
   if(lotSize <= 0.0)
   {
      signal.reason = "Taille de position invalide";
      return signal;
   }
   
   // Remplir le signal
   signal.valid = true;
   signal.direction = direction;
   signal.entryPrice = entryLevel;
   signal.slPrice = slPrice;
   signal.tpPrice = tpPrice;
   signal.lotSize = lotSize;
   signal.reason = reason;
   signal.confidence = 75.0; // Confiance de base
   
   // Ajuster la confiance selon la force de tendance
   MarketAnalysis ma = MR_AnalyzeMarket(symbol, PERIOD_M15, 40, 3);
   if(ma.trend_strength >= 70.0) signal.confidence = 85.0;
   else if(ma.trend_strength >= 60.0) signal.confidence = 75.0;
   else signal.confidence = 65.0;
   
   return signal;
}

//+------------------------------------------------------------------+
//| Exécuter un ordre Swing M15                                        |
//+------------------------------------------------------------------+
bool SWING_ExecuteSwingTrade(const string symbol, const SwingSignal &signal)
{
   if(!signal.valid) return false;
   
   CTrade trade;
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(50);
   
   ENUM_ORDER_TYPE orderType = (signal.direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   bool result = trade.PositionOpen(symbol, orderType, signal.lotSize, 
                                      signal.entryPrice, signal.slPrice, signal.tpPrice,
                                      "SWING_M15");
   
   if(result)
   {
      // Enregistrer la position
      int sz = ArraySize(g_swingPositions);
      ArrayResize(g_swingPositions, sz + 1);
      
      g_swingPositions[sz].ticket = trade.ResultOrder();
      g_swingPositions[sz].symbol = symbol;
      g_swingPositions[sz].direction = signal.direction;
      g_swingPositions[sz].entryPrice = signal.entryPrice;
      g_swingPositions[sz].slPrice = signal.slPrice;
      g_swingPositions[sz].tpPrice = signal.tpPrice;
      g_swingPositions[sz].initialSL = signal.slPrice;
      g_swingPositions[sz].openTime = TimeCurrent();
      g_swingPositions[sz].trailingActive = false;
      
      // Mettre à jour le cooldown
      MqlRates m15Rates[];
      ArraySetAsSeries(m15Rates, true);
      if(CopyRates(symbol, PERIOD_M15, 0, 1, m15Rates) >= 1)
      {
         g_swingLastEntryBar = m15Rates[0].time;
         g_swingLastEntryDir = signal.direction;
      }
      
      Print("✅ SWING M15: Ordre exécuté ", symbol, " ", 
            (signal.direction > 0 ? "BUY" : "SELL"),
            " Entry=", signal.entryPrice,
            " SL=", signal.slPrice,
            " TP=", signal.tpPrice,
            " Lot=", signal.lotSize,
            " Confiance=", signal.confidence, "%");
   }
   else
   {
      Print("❌ SWING M15: Échec ordre ", symbol, " - ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Gérer le trailing stop pour positions Swing                        |
//+------------------------------------------------------------------+
void SWING_ManageTrailingStop()
{
   for(int i = ArraySize(g_swingPositions) - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_swingPositions[i].ticket))
      {
         // Position fermée, retirer du tableau
         ArrayRemove(g_swingPositions, i, 1);
         continue;
      }
      
      SwingPosition &pos = g_swingPositions[i];
      
      double currentPrice = SymbolInfoDouble(pos.symbol, (pos.direction > 0) ? SYMBOL_BID : SYMBOL_ASK);
      double slDistance = MathAbs(pos.slPrice - pos.entryPrice);
      double tpDistance = MathAbs(pos.tpPrice - pos.entryPrice);
      
      // Activation trailing à 50% du TP
      double activationLevel = pos.entryPrice + (pos.direction > 0 ? tpDistance * 0.5 : -tpDistance * 0.5);
      
      if(!pos.trailingActive)
      {
         if((pos.direction > 0 && currentPrice >= activationLevel) ||
            (pos.direction < 0 && currentPrice <= activationLevel))
         {
            pos.trailingActive = true;
            Print("🔄 SWING M15: Trailing activé pour ", pos.symbol, " ticket=", pos.ticket);
         }
      }
      
      if(pos.trailingActive)
      {
         double trailStep = slDistance * 0.25; // 25% du SL initial
         double newSL = 0.0;
         
         if(pos.direction > 0)
         {
            newSL = currentPrice - trailStep;
            if(newSL <= pos.slPrice) continue; // SL ne doit pas descendre
         }
         else
         {
            newSL = currentPrice + trailStep;
            if(newSL >= pos.slPrice) continue; // SL ne doit pas monter
         }
         
         // Mettre à jour le SL
         CTrade trade;
         trade.SetExpertMagicNumber(InpMagicNumber);
         
         if(trade.PositionModify(pos.ticket, newSL, pos.tpPrice))
         {
            pos.slPrice = newSL;
            Print("🔄 SWING M15: SL trailing mis à jour ", pos.symbol, " nouveau SL=", newSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Fonction principale à appeler depuis OnTick                       |
//+------------------------------------------------------------------+
void SWING_OnTick(const string symbol)
{
   // Les inputs sont définis dans SMC_Universal.mq5 et sont globalement visibles
   if(!SWING_Enable) return;
   
   // Vérifier le nombre max de positions
   int swingCount = 0;
   for(int i = 0; i < ArraySize(g_swingPositions); i++)
   {
      if(PositionSelectByTicket(g_swingPositions[i].ticket)) swingCount++;
   }
   
   if(swingCount >= SWING_MaxPositions) return;
   
   // Générer et exécuter le signal
   SwingSignal signal = SWING_GenerateSignal(symbol);
   if(signal.valid && signal.confidence >= 70.0)
   {
      SWING_ExecuteSwingTrade(symbol, signal);
   }
   
   // Gérer le trailing stop
   if(SWING_UseTrailingStop)
      SWING_ManageTrailingStop();
}

#endif // SMC_SWING_M15_MQH
