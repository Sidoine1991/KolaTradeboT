//+------------------------------------------------------------------+
//|                                LIQUIDITY_SNIPER_EA_V1_7.mq5     |
//|                         Liquidity Sniper Expert Advisor          |
//|                Strategy: BSL/SSL Detection + Liquidity Sweep     |
//|                         + Order Block Entry                      |
//+------------------------------------------------------------------+
#property copyright "Liquidity Sniper EA v1.7"
#property version   "1.7"
#property description "Détecte les zones de liquidité (BSL/SSL), les sweeps et entre sur OB"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Objets de trading
CTrade         trade;
CPositionInfo  posInfo;

//=== INPUTS ===================================================================

input group "══════════ GESTION DU RISQUE ══════════"
input double   InpRiskPercent      = 1.0;    // Risque par trade (% du capital)
input double   InpRRRatio          = 2.0;    // Ratio Risque/Rendement
input int      InpMaxPositions     = 1;      // Nombre max de positions simultanées
input double   InpMaxLotSize       = 5.0;    // Lot maximum autorisé

input group "══════════ DÉTECTION DE LIQUIDITÉ ══════════"
input int      InpLiqLookback      = 50;     // Barres d'historique pour détecter BSL/SSL
input double   InpEqualPips        = 3.0;    // Tolérance equal highs/lows (pips)
input int      InpMinTouchCount    = 2;      // Touches minimales pour valider un niveau
input int      InpSweepConfirm     = 1;      // Barres de confirmation après sweep
input bool     InpRequireSweep     = true;   // Exiger un sweep avant entrée

input group "══════════ ORDER BLOCKS ══════════"
input bool     InpUseOB            = true;   // Utiliser les Order Blocks
input int      InpOBLookback       = 30;     // Barres pour détecter les OB
input double   InpOBMinSize        = 5.0;    // Taille minimale OB (pips)
input bool     InpUseFVG           = true;   // Utiliser les Fair Value Gaps

input group "══════════ STRUCTURE DU MARCHÉ ══════════"
input bool     InpUseBOS           = true;   // Filtrer par Break of Structure
input int      InpStructureLookback = 100;   // Barres pour détecter la structure
input ENUM_TIMEFRAMES InpHTF       = PERIOD_H4; // Timeframe HTF pour le biais

input group "══════════ FILTRE DE SESSION ══════════"
input bool     InpUseSession       = true;   // Activer le filtre de session
input int      InpSessionStart     = 7;      // Heure de début (UTC)
input int      InpSessionEnd       = 20;     // Heure de fin (UTC)
input bool     InpAvoidNews        = false;  // Éviter les news (manuel)

input group "══════════ PARAMÈTRES TRADE ══════════"
input bool     InpAllowBuy         = true;   // Autoriser les achats
input bool     InpAllowSell        = true;   // Autoriser les ventes
input int      InpMagicNumber      = 77001;  // Magic Number
input int      InpSlippage         = 10;     // Slippage max (points)
input bool     InpUseTrailingStop  = true;   // Activer le trailing stop
input double   InpTrailingPips     = 20.0;   // Trailing stop (pips)
input bool     InpBreakEven        = true;   // Activer le Break Even
input double   InpBEActivation     = 1.0;    // Activation BE (x RR)

//=== STRUCTURES ===============================================================

struct LiquidityLevel
{
   double   price;
   int      touches;
   bool     isBSL;       // true = Buy Side Liquidity (résistance), false = SSL (support)
   bool     swept;
   datetime time;
};

struct OrderBlock
{
   double   high;
   double   low;
   double   mid;
   bool     isBullish;
   bool     mitigated;
   datetime time;
};

struct FairValueGap
{
   double   high;
   double   low;
   bool     isBullish;
   bool     filled;
   datetime time;
};

//=== VARIABLES GLOBALES =======================================================

LiquidityLevel  g_Levels[];
OrderBlock      g_OBs[];
FairValueGap    g_FVGs[];

double   g_Point;
double   g_PipValue;
int      g_Digits;
bool     g_BullishBias = false;
bool     g_BearishBias = false;

datetime g_LastBarTime = 0;
string   g_Symbol;

//=== INITIALISATION ===========================================================

int OnInit()
{
   g_Symbol  = Symbol();
   g_Digits  = (int)SymbolInfoInteger(g_Symbol, SYMBOL_DIGITS);
   g_Point   = SymbolInfoDouble(g_Symbol, SYMBOL_POINT);
   g_PipValue = (g_Digits == 3 || g_Digits == 5) ? g_Point * 10 : g_Point;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   PrintFormat("🎯 LIQUIDITY SNIPER EA v1.7 | %s | Pip=%.5f", g_Symbol, g_PipValue);
   PrintFormat("   Risque: %.1f%% | RR: %.1f | Max Pos: %d", InpRiskPercent, InpRRRatio, InpMaxPositions);

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "LS_");
   PrintFormat("🔴 LIQUIDITY SNIPER EA arrêté. Raison: %d", reason);
}

//=== TICK PRINCIPAL ===========================================================

void OnTick()
{
   //--- Nouvelle bougie uniquement
   datetime currentBar = iTime(g_Symbol, PERIOD_CURRENT, 0);
   if(currentBar == g_LastBarTime)
   {
      //--- Gestion dynamique des positions ouvertes
      ManageOpenPositions();
      return;
   }
   g_LastBarTime = currentBar;

   //--- Filtre de session
   if(InpUseSession && !IsInSession()) return;

   //--- Mise à jour analyse
   AnalyzeHTFBias();
   DetectLiquidityLevels();
   if(InpUseOB)  DetectOrderBlocks();
   if(InpUseFVG) DetectFairValueGaps();

   //--- Recherche de setups
   if(CountOpenPositions() < InpMaxPositions)
   {
      CheckForBuySetup();
      CheckForSellSetup();
   }
}

//=== ANALYSE BIAIS HTF ========================================================

void AnalyzeHTFBias()
{
   int bars = InpStructureLookback;
   double highestHigh = 0, lowestLow = DBL_MAX;
   int highBar = -1, lowBar = -1;

   for(int i = 1; i <= bars; i++)
   {
      double h = iHigh(g_Symbol, InpHTF, i);
      double l = iLow(g_Symbol, InpHTF, i);
      if(h > highestHigh) { highestHigh = h; highBar = i; }
      if(l < lowestLow)   { lowestLow  = l; lowBar  = i; }
   }

   //--- Prix actuel vs structure HTF
   double currentClose = iClose(g_Symbol, InpHTF, 1);
   double midRange     = (highestHigh + lowestLow) / 2.0;

   //--- BOS haussier : cassure du dernier high HTF
   double prevHigh = iHigh(g_Symbol, InpHTF, highBar + 1);
   if(currentClose > highestHigh)       g_BullishBias = true;
   else if(currentClose < lowestLow)    g_BearishBias = true;
   else if(currentClose > midRange)     { g_BullishBias = true;  g_BearishBias = false; }
   else                                  { g_BearishBias = true;  g_BullishBias = false; }
}

//=== DÉTECTION DES ZONES DE LIQUIDITÉ =========================================

void DetectLiquidityLevels()
{
   ArrayResize(g_Levels, 0);
   int count = 0;
   double tolPips = InpEqualPips * g_PipValue;

   //--- Détecter equal highs (BSL) et equal lows (SSL)
   for(int i = 2; i <= InpLiqLookback - 2; i++)
   {
      double hi = iHigh(g_Symbol, PERIOD_CURRENT, i);
      double lo = iLow(g_Symbol,  PERIOD_CURRENT, i);

      //--- Vérifier si c'est un swing high (BSL candidate)
      if(hi > iHigh(g_Symbol, PERIOD_CURRENT, i-1) &&
         hi > iHigh(g_Symbol, PERIOD_CURRENT, i+1) &&
         hi > iHigh(g_Symbol, PERIOD_CURRENT, i-2) &&
         hi > iHigh(g_Symbol, PERIOD_CURRENT, i+2))
      {
         int touches = CountTouches(hi, true, tolPips, i);
         if(touches >= InpMinTouchCount)
         {
            LiquidityLevel lvl;
            lvl.price    = hi;
            lvl.touches  = touches;
            lvl.isBSL    = true;
            lvl.swept    = IsSwept(hi, true);
            lvl.time     = iTime(g_Symbol, PERIOD_CURRENT, i);
            ArrayResize(g_Levels, count + 1);
            g_Levels[count++] = lvl;
         }
      }

      //--- Vérifier si c'est un swing low (SSL candidate)
      if(lo < iLow(g_Symbol, PERIOD_CURRENT, i-1) &&
         lo < iLow(g_Symbol, PERIOD_CURRENT, i+1) &&
         lo < iLow(g_Symbol, PERIOD_CURRENT, i-2) &&
         lo < iLow(g_Symbol, PERIOD_CURRENT, i+2))
      {
         int touches = CountTouches(lo, false, tolPips, i);
         if(touches >= InpMinTouchCount)
         {
            LiquidityLevel lvl;
            lvl.price    = lo;
            lvl.touches  = touches;
            lvl.isBSL    = false;
            lvl.swept    = IsSwept(lo, false);
            lvl.time     = iTime(g_Symbol, PERIOD_CURRENT, i);
            ArrayResize(g_Levels, count + 1);
            g_Levels[count++] = lvl;
         }
      }
   }
}

int CountTouches(double level, bool isHigh, double tol, int startBar)
{
   int touches = 0;
   for(int i = startBar; i <= InpLiqLookback; i++)
   {
      double price = isHigh ? iHigh(g_Symbol, PERIOD_CURRENT, i)
                            : iLow(g_Symbol, PERIOD_CURRENT, i);
      if(MathAbs(price - level) <= tol) touches++;
   }
   return touches;
}

bool IsSwept(double level, bool isBSL)
{
   double currentHigh = iHigh(g_Symbol, PERIOD_CURRENT, 1);
   double currentLow  = iLow(g_Symbol,  PERIOD_CURRENT, 1);
   double currentClose = iClose(g_Symbol, PERIOD_CURRENT, 1);

   if(isBSL)
      return (currentHigh > level && currentClose < level);
   else
      return (currentLow < level && currentClose > level);
}

//=== DÉTECTION DES ORDER BLOCKS ===============================================

void DetectOrderBlocks()
{
   ArrayResize(g_OBs, 0);
   int count = 0;

   for(int i = 3; i <= InpOBLookback; i++)
   {
      double open_i  = iOpen(g_Symbol,  PERIOD_CURRENT, i);
      double close_i = iClose(g_Symbol, PERIOD_CURRENT, i);
      double high_i  = iHigh(g_Symbol,  PERIOD_CURRENT, i);
      double low_i   = iLow(g_Symbol,   PERIOD_CURRENT, i);
      double size    = MathAbs(close_i - open_i) / g_PipValue;

      if(size < InpOBMinSize) continue;

      bool isBullishCandle = close_i > open_i;
      bool isBearishCandle = close_i < open_i;

      //--- Bullish OB : bougie baissière suivie d'un BOS haussier
      if(isBearishCandle)
      {
         double nextHigh = iHigh(g_Symbol, PERIOD_CURRENT, i - 1);
         double nextClose = iClose(g_Symbol, PERIOD_CURRENT, i - 1);
         if(nextClose > high_i)
         {
            OrderBlock ob;
            ob.high      = high_i;
            ob.low       = low_i;
            ob.mid       = (high_i + low_i) / 2.0;
            ob.isBullish = true;
            ob.mitigated = IsMitigated(ob.high, ob.low, true, i);
            ob.time      = iTime(g_Symbol, PERIOD_CURRENT, i);
            ArrayResize(g_OBs, count + 1);
            g_OBs[count++] = ob;
         }
      }

      //--- Bearish OB : bougie haussière suivie d'un BOS baissier
      if(isBullishCandle)
      {
         double nextLow   = iLow(g_Symbol,  PERIOD_CURRENT, i - 1);
         double nextClose = iClose(g_Symbol, PERIOD_CURRENT, i - 1);
         if(nextClose < low_i)
         {
            OrderBlock ob;
            ob.high      = high_i;
            ob.low       = low_i;
            ob.mid       = (high_i + low_i) / 2.0;
            ob.isBullish = false;
            ob.mitigated = IsMitigated(ob.high, ob.low, false, i);
            ob.time      = iTime(g_Symbol, PERIOD_CURRENT, i);
            ArrayResize(g_OBs, count + 1);
            g_OBs[count++] = ob;
         }
      }
   }
}

bool IsMitigated(double high, double low, bool isBullish, int fromBar)
{
   for(int i = fromBar - 1; i >= 1; i--)
   {
      double lo = iLow(g_Symbol,  PERIOD_CURRENT, i);
      double hi = iHigh(g_Symbol, PERIOD_CURRENT, i);
      if(isBullish && lo <= low) return true;
      if(!isBullish && hi >= high) return true;
   }
   return false;
}

//=== DÉTECTION DES FAIR VALUE GAPS ============================================

void DetectFairValueGaps()
{
   ArrayResize(g_FVGs, 0);
   int count = 0;

   for(int i = 2; i <= InpOBLookback; i++)
   {
      double high_prev = iHigh(g_Symbol, PERIOD_CURRENT, i + 1);
      double low_prev  = iLow(g_Symbol,  PERIOD_CURRENT, i + 1);
      double high_next = iHigh(g_Symbol, PERIOD_CURRENT, i - 1);
      double low_next  = iLow(g_Symbol,  PERIOD_CURRENT, i - 1);

      //--- Bullish FVG : low de la bougie suivante > high de la bougie précédente
      if(low_next > high_prev)
      {
         FairValueGap fvg;
         fvg.high      = low_next;
         fvg.low       = high_prev;
         fvg.isBullish = true;
         fvg.filled    = IsFVGFilled(fvg.high, fvg.low, true, i);
         fvg.time      = iTime(g_Symbol, PERIOD_CURRENT, i);
         ArrayResize(g_FVGs, count + 1);
         g_FVGs[count++] = fvg;
      }

      //--- Bearish FVG : high de la bougie suivante < low de la bougie précédente
      if(high_next < low_prev)
      {
         FairValueGap fvg;
         fvg.high      = low_prev;
         fvg.low       = high_next;
         fvg.isBullish = false;
         fvg.filled    = IsFVGFilled(fvg.high, fvg.low, false, i);
         fvg.time      = iTime(g_Symbol, PERIOD_CURRENT, i);
         ArrayResize(g_FVGs, count + 1);
         g_FVGs[count++] = fvg;
      }
   }
}

bool IsFVGFilled(double high, double low, bool isBullish, int fromBar)
{
   for(int i = fromBar - 1; i >= 1; i--)
   {
      double lo = iLow(g_Symbol,  PERIOD_CURRENT, i);
      double hi = iHigh(g_Symbol, PERIOD_CURRENT, i);
      if(isBullish && lo <= low)  return true;
      if(!isBullish && hi >= high) return true;
   }
   return false;
}

//=== SETUP ACHAT ==============================================================

void CheckForBuySetup()
{
   if(!InpAllowBuy) return;
   if(InpUseBOS && !g_BullishBias) return;

   double ask = SymbolInfoDouble(g_Symbol, SYMBOL_ASK);

   //--- Chercher un sweep SSL récent (liquidité basse prise)
   bool sslSwept = false;
   double sweptLevel = 0;

   for(int i = 0; i < ArraySize(g_Levels); i++)
   {
      if(!g_Levels[i].isBSL && g_Levels[i].swept)
      {
         sslSwept   = true;
         sweptLevel = g_Levels[i].price;
         break;
      }
   }

   if(InpRequireSweep && !sslSwept) return;

   //--- Chercher un Bullish OB non mitiqué en dessous du prix actuel
   if(InpUseOB)
   {
      for(int i = 0; i < ArraySize(g_OBs); i++)
      {
         if(g_OBs[i].isBullish && !g_OBs[i].mitigated)
         {
            //--- Prix dans la zone de l'OB
            if(ask >= g_OBs[i].low && ask <= g_OBs[i].high)
            {
               double sl = g_OBs[i].low - (2 * g_PipValue);
               double tp = ask + (ask - sl) * InpRRRatio;
               double lots = CalculateLotSize(sl, ask);
               if(lots > 0)
               {
                  PrintFormat("🟢 BUY Setup | Ask=%.5f | OB[%.5f-%.5f] | SSL swept=%.5f | SL=%.5f | TP=%.5f",
                              ask, g_OBs[i].low, g_OBs[i].high, sweptLevel, sl, tp);
                  OpenTrade(ORDER_TYPE_BUY, lots, sl, tp);
                  return;
               }
            }
         }
      }
   }

   //--- Si pas d'OB, utiliser FVG bullish
   if(InpUseFVG)
   {
      for(int i = 0; i < ArraySize(g_FVGs); i++)
      {
         if(g_FVGs[i].isBullish && !g_FVGs[i].filled)
         {
            if(ask >= g_FVGs[i].low && ask <= g_FVGs[i].high)
            {
               double sl = g_FVGs[i].low - (2 * g_PipValue);
               double tp = ask + (ask - sl) * InpRRRatio;
               double lots = CalculateLotSize(sl, ask);
               if(lots > 0)
               {
                  PrintFormat("🟢 BUY Setup (FVG) | Ask=%.5f | FVG[%.5f-%.5f] | SL=%.5f | TP=%.5f",
                              ask, g_FVGs[i].low, g_FVGs[i].high, sl, tp);
                  OpenTrade(ORDER_TYPE_BUY, lots, sl, tp);
                  return;
               }
            }
         }
      }
   }
}

//=== SETUP VENTE ==============================================================

void CheckForSellSetup()
{
   if(!InpAllowSell) return;
   if(InpUseBOS && !g_BearishBias) return;

   double bid = SymbolInfoDouble(g_Symbol, SYMBOL_BID);

   //--- Chercher un sweep BSL récent (liquidité haute prise)
   bool bslSwept = false;
   double sweptLevel = 0;

   for(int i = 0; i < ArraySize(g_Levels); i++)
   {
      if(g_Levels[i].isBSL && g_Levels[i].swept)
      {
         bslSwept   = true;
         sweptLevel = g_Levels[i].price;
         break;
      }
   }

   if(InpRequireSweep && !bslSwept) return;

   //--- Chercher un Bearish OB non mitiqué au-dessus du prix
   if(InpUseOB)
   {
      for(int i = 0; i < ArraySize(g_OBs); i++)
      {
         if(!g_OBs[i].isBullish && !g_OBs[i].mitigated)
         {
            if(bid >= g_OBs[i].low && bid <= g_OBs[i].high)
            {
               double sl = g_OBs[i].high + (2 * g_PipValue);
               double tp = bid - (sl - bid) * InpRRRatio;
               double lots = CalculateLotSize(bid, sl);
               if(lots > 0)
               {
                  PrintFormat("🔴 SELL Setup | Bid=%.5f | OB[%.5f-%.5f] | BSL swept=%.5f | SL=%.5f | TP=%.5f",
                              bid, g_OBs[i].low, g_OBs[i].high, sweptLevel, sl, tp);
                  OpenTrade(ORDER_TYPE_SELL, lots, sl, tp);
                  return;
               }
            }
         }
      }
   }

   //--- Si pas d'OB, utiliser FVG bearish
   if(InpUseFVG)
   {
      for(int i = 0; i < ArraySize(g_FVGs); i++)
      {
         if(!g_FVGs[i].isBullish && !g_FVGs[i].filled)
         {
            if(bid >= g_FVGs[i].low && bid <= g_FVGs[i].high)
            {
               double sl = g_FVGs[i].high + (2 * g_PipValue);
               double tp = bid - (sl - bid) * InpRRRatio;
               double lots = CalculateLotSize(bid, sl);
               if(lots > 0)
               {
                  PrintFormat("🔴 SELL Setup (FVG) | Bid=%.5f | FVG[%.5f-%.5f] | SL=%.5f | TP=%.5f",
                              bid, g_FVGs[i].low, g_FVGs[i].high, sl, tp);
                  OpenTrade(ORDER_TYPE_SELL, lots, sl, tp);
                  return;
               }
            }
         }
      }
   }
}

//=== GESTION DES POSITIONS ====================================================

void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      if(posInfo.Symbol() != g_Symbol)      continue;

      double openPrice = posInfo.PriceOpen();
      double sl        = posInfo.StopLoss();
      double tp        = posInfo.TakeProfit();
      double currentBid = SymbolInfoDouble(g_Symbol, SYMBOL_BID);
      double currentAsk = SymbolInfoDouble(g_Symbol, SYMBOL_ASK);
      ulong  ticket    = posInfo.Ticket();

      //--- Break Even
      if(InpBreakEven)
      {
         double riskPips = MathAbs(openPrice - sl) / g_PipValue;
         double profitPips = 0;

         if(posInfo.PositionType() == POSITION_TYPE_BUY)
            profitPips = (currentBid - openPrice) / g_PipValue;
         else
            profitPips = (openPrice - currentAsk) / g_PipValue;

         if(profitPips >= riskPips * InpBEActivation)
         {
            double beSL = (posInfo.PositionType() == POSITION_TYPE_BUY)
                          ? openPrice + g_PipValue
                          : openPrice - g_PipValue;

            if(posInfo.PositionType() == POSITION_TYPE_BUY && (sl < beSL))
               trade.PositionModify(ticket, beSL, tp);
            else if(posInfo.PositionType() == POSITION_TYPE_SELL && (sl > beSL || sl == 0))
               trade.PositionModify(ticket, beSL, tp);
         }
      }

      //--- Trailing Stop
      if(InpUseTrailingStop)
      {
         double trailDist = InpTrailingPips * g_PipValue;

         if(posInfo.PositionType() == POSITION_TYPE_BUY)
         {
            double newSL = currentBid - trailDist;
            if(newSL > sl && newSL > openPrice)
               trade.PositionModify(ticket, NormalizeDouble(newSL, g_Digits), tp);
         }
         else
         {
            double newSL = currentAsk + trailDist;
            if((newSL < sl || sl == 0) && newSL < openPrice)
               trade.PositionModify(ticket, NormalizeDouble(newSL, g_Digits), tp);
         }
      }
   }
}

//=== UTILITAIRES ==============================================================

double CalculateLotSize(double entryPrice, double slPrice)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount     = accountBalance * InpRiskPercent / 100.0;
   double slPips         = MathAbs(entryPrice - slPrice) / g_PipValue;

   if(slPips < 1.0) return 0;

   double tickValue = SymbolInfoDouble(g_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(g_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pipValue  = (g_PipValue / tickSize) * tickValue;

   double lots = riskAmount / (slPips * pipValue);

   double minLot  = SymbolInfoDouble(g_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = MathMin(SymbolInfoDouble(g_Symbol, SYMBOL_VOLUME_MAX), InpMaxLotSize);
   double lotStep = SymbolInfoDouble(g_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   return lots;
}

void OpenTrade(ENUM_ORDER_TYPE type, double lots, double sl, double tp)
{
   sl = NormalizeDouble(sl, g_Digits);
   tp = NormalizeDouble(tp, g_Digits);

   if(type == ORDER_TYPE_BUY)
   {
      double price = SymbolInfoDouble(g_Symbol, SYMBOL_ASK);
      trade.Buy(lots, g_Symbol, price, sl, tp, "LS_BUY");
   }
   else
   {
      double price = SymbolInfoDouble(g_Symbol, SYMBOL_BID);
      trade.Sell(lots, g_Symbol, price, sl, tp, "LS_SELL");
   }

   if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
      PrintFormat("✅ Trade ouvert | Type=%s | Lots=%.2f | SL=%.5f | TP=%.5f",
                  type == ORDER_TYPE_BUY ? "BUY" : "SELL", lots, sl, tp);
   else
      PrintFormat("❌ Erreur trade: %d - %s", trade.ResultRetcode(), trade.ResultComment());
}

int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == g_Symbol)
         count++;
   }
   return count;
}

bool IsInSession()
{
   MqlDateTime dt;
   TimeGMT(dt);
   int hour = dt.hour;
   if(InpSessionStart <= InpSessionEnd)
      return (hour >= InpSessionStart && hour < InpSessionEnd);
   else
      return (hour >= InpSessionStart || hour < InpSessionEnd);
}

//=== AFFICHAGE GRAPHIQUE ======================================================

void DrawLiquidityLevels()
{
   ObjectsDeleteAll(0, "LS_LVL_");
   for(int i = 0; i < ArraySize(g_Levels); i++)
   {
      string name = "LS_LVL_" + IntegerToString(i);
      color  clr  = g_Levels[i].isBSL ? clrDodgerBlue : clrOrangeRed;
      ENUM_LINE_STYLE style = g_Levels[i].swept ? STYLE_DOT : STYLE_DASH;
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, g_Levels[i].price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   }
}

//+------------------------------------------------------------------+
