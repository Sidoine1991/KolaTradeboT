//+------------------------------------------------------------------+
//| SMC_PivotLimitTracker.mqh — LIMIT sur lignes pivot verte/rouge  |
//| Fallback DOW : quand GOM PERFECT mais pas de spike DOW, placer  |
//| LIMIT sur les niveaux pivot (green/red lines). Suit le mouvement |
//| des lignes → annule + recrée si le prix change.                  |
//+------------------------------------------------------------------+
#ifndef SMC_PIVOT_LIMIT_TRACKER_MQH
#define SMC_PIVOT_LIMIT_TRACKER_MQH

#include <Trade/Trade.mqh>

//--- Inputs
input bool   UsePivotLimitTracker   = true;   // MARKET au touché Pivot vert/rouge (spike)
input double PivotLimitOffsetATR    = 0.05;  // Offset prix limit (x ATR)
input double PivotLimitSL_ATR       = 10.0;  // SL du LIMIT (x ATR M1 = ~10 bougies M1)
input double PivotLimitTP_ATR       = 2.0;   // TP du LIMIT (x ATR)
input int    PivotLimitMaxAge_sec   = 300;    // Max âge LIMIT avant suppression (sec)
input int    PivotLimitMagicOffset  = 100;    // Magic number offset pour identifier ces LIMITs

//--- État
static ulong  g_pivotBuyTicket   = 0;
static ulong  g_pivotSellTicket  = 0;
static double g_pivotBuyPrice    = 0;
static double g_pivotSellPrice   = 0;
static datetime g_pivotBuyTime   = 0;
static datetime g_pivotSellTime  = 0;
static CTrade  g_pivotTrade;

//+------------------------------------------------------------------+
//| Cherche un ordre LIMIT pivot existant par ticket                  |
//+------------------------------------------------------------------+
bool PivotLimit_IsOrderAlive(ulong ticket)
{
   if(ticket <= 0) return false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == ticket) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Trouve un ordre LIMIT pivot existant (par magic + comment)        |
//+------------------------------------------------------------------+
ulong PivotLimit_FindOrder(const string symbol, bool isBuy)
{
   long magic = InpMagicNumber + PivotLimitMagicOffset;
   string tag = isBuy ? "PIVOT_BUY" : "PIVOT_SELL";
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic) continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, tag) >= 0) return t;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Annule un ordre LIMIT pivot                                       |
//+------------------------------------------------------------------+
bool PivotLimit_CancelOrder(ulong ticket, string reason)
{
   if(ticket <= 0) return false;
   return LimitSafeOrderDelete(ticket, false, "PIVOT-LIMIT " + reason);
}

//+------------------------------------------------------------------+
//| Place un ordre LIMIT pivot                                        |
//+------------------------------------------------------------------+
bool PivotLimit_PlaceOrder(const string symbol, const string direction,
                           double limitPrice, double atrVal,
                           const string levelSource)
{
   if(limitPrice <= 0 || atrVal <= 0) return false;

   //--- Gates
   if(CountTerminalOrdersOurEA() >= MaxPositionsTerminal) return false;
   if(!IsSignalConfirmed()) return false;
   if(!GOM_CanOpenNewTrade(direction == "BUY" ? 1 : -1)) return false;
   if(!IsDirectionAllowedForBoomCrash(symbol, direction)) return false;

   //--- Calcul SL/TP
   int dg = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0) tickSize = _Point;
   limitPrice = NormalizeDouble(limitPrice, dg);

   double slDist = atrVal * PivotLimitSL_ATR;
   double tpDist = atrVal * PivotLimitTP_ATR;
   double sl = 0, tp = 0;
   if(direction == "BUY")
   {
      sl = NormalizeDouble(limitPrice - slDist, dg);
      tp = NormalizeDouble(limitPrice + tpDist, dg);
   }
   else
   {
      sl = NormalizeDouble(limitPrice + slDist, dg);
      tp = NormalizeDouble(limitPrice - tpDist, dg);
   }

   //--- Valider/ajuster le prix limit
   ENUM_ORDER_TYPE ot = (direction == "BUY") ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   if(!ValidateAndAdjustLimitPrice(limitPrice, sl, tp, ot))
      return false;

   //--- Construire la requête
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_PENDING;
   req.symbol    = symbol;
   req.volume    = CalculateLotSize();
   req.type      = ot;
   req.price     = limitPrice;
   req.sl        = sl;
   req.tp        = tp;
   req.magic     = InpMagicNumber + PivotLimitMagicOffset;
   req.comment   = "PIVOT_" + direction + " " + levelSource;
   req.type_time = ORDER_TIME_GTC;

   if(req.volume <= 0) return false;

   if(g_pivotTrade.OrderSend(req, res))
   {
      Print("🎯 PIVOT ", direction, " LIMIT @ ", req.price,
            " | SL=", req.sl, " | TP=", req.tp,
            " | source=", levelSource, " | ticket=", res.order);
      return true;
   }
   Print("❌ PIVOT LIMIT failed: ", res.retcode, " - ", res.comment);
   return false;
}

//+------------------------------------------------------------------+
//| Met à jour les tickets trackés (vérifie vivacité)                |
//+------------------------------------------------------------------+
void PivotLimit_UpdateTickets()
{
   if(g_pivotBuyTicket > 0 && !PivotLimit_IsOrderAlive(g_pivotBuyTicket))
   {
      g_pivotBuyTicket = 0;
      g_pivotBuyPrice = 0;
      g_pivotBuyTime = 0;
   }
   if(g_pivotSellTicket > 0 && !PivotLimit_IsOrderAlive(g_pivotSellTicket))
   {
      g_pivotSellTicket = 0;
      g_pivotSellPrice = 0;
      g_pivotSellTime = 0;
   }
}

//+------------------------------------------------------------------+
//| Vérifie si le prix de la ligne a changé → annule + recrée        |
//+------------------------------------------------------------------+
void PivotLimit_CheckLineMovement_Buy(const string symbol, double newPrice, double atrVal)
{
   if(g_pivotBuyTicket == 0) return;
   string direction = "BUY";
   if(TimeCurrent() - g_pivotBuyTime > PivotLimitMaxAge_sec)
   {
      PivotLimit_CancelOrder(g_pivotBuyTicket, "âge dépassé (BUY)");
      g_pivotBuyTicket = 0; g_pivotBuyPrice = 0; g_pivotBuyTime = 0;
      return;
   }
   double diff = MathAbs(newPrice - g_pivotBuyPrice);
   if(diff <= SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE)) return;
   PivotLimit_CancelOrder(g_pivotBuyTicket, "prix ligne changé (BUY)");
   g_pivotBuyTicket = 0; g_pivotBuyPrice = 0; g_pivotBuyTime = 0;
   if(PivotLimit_PlaceOrder(symbol, direction, newPrice, atrVal, "LineMove"))
   {
      g_pivotBuyTicket = PivotLimit_FindOrder(symbol, true);
      g_pivotBuyPrice = newPrice;
      g_pivotBuyTime = TimeCurrent();
   }
}

void PivotLimit_CheckLineMovement_Sell(const string symbol, double newPrice, double atrVal)
{
   if(g_pivotSellTicket == 0) return;
   string direction = "SELL";
   if(TimeCurrent() - g_pivotSellTime > PivotLimitMaxAge_sec)
   {
      PivotLimit_CancelOrder(g_pivotSellTicket, "âge dépassé (SELL)");
      g_pivotSellTicket = 0; g_pivotSellPrice = 0; g_pivotSellTime = 0;
      return;
   }
   double diff = MathAbs(newPrice - g_pivotSellPrice);
   if(diff <= SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE)) return;
   PivotLimit_CancelOrder(g_pivotSellTicket, "prix ligne changé (SELL)");
   g_pivotSellTicket = 0; g_pivotSellPrice = 0; g_pivotSellTime = 0;
   if(PivotLimit_PlaceOrder(symbol, direction, newPrice, atrVal, "LineMove"))
   {
      g_pivotSellTicket = PivotLimit_FindOrder(symbol, false);
      g_pivotSellPrice = newPrice;
      g_pivotSellTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Entrée MARKET au touché Pivot Low (vert) / Pivot High (rouge)    |
//| Conditions: GOM GOOD/PERFECT + décision BUY/SELL clignotante     |
//| + direction spike autorisée (Boom/Gainx BUY, Crash/Painx SELL)   |
//+------------------------------------------------------------------+
bool PivotLimit_ExecuteMarketAtLevel(const string symbol, const string direction,
                                     double levelPrice, double atrVal,
                                     const string levelSource)
{
   if(levelPrice <= 0 || atrVal <= 0) return false;
   int dirSign = (direction == "BUY") ? 1 : -1;

   if(!IsSignalConfirmed()) return false;
   if(GetConfirmedSignalDir() != dirSign) return false;
   if(!IsDirectionAllowedForBoomCrash(symbol, direction)) return false;
   if(!CanPlaceMarketOrder(symbol, dirSign)) return false;
   if(CountPositionsForSymbol(symbol) > 0) return false;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return false;

   double nearTol = atrVal * 0.40;
   double refPx = (dirSign > 0) ? ask : bid;
   if(MathAbs(refPx - levelPrice) > nearTol)
      return false; // attendre le touché de la ligne

   if(!TryAcquireOpenLock()) return false;

   int dg = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return false; }

   double slDist = atrVal * PivotLimitSL_ATR;
   // Cap SL ATR pour MARKET scalp (10 ATR trop large en market)
   if(slDist > atrVal * 3.0) slDist = atrVal * 2.5;
   double tpDist = atrVal * MathMax(1.5, PivotLimitTP_ATR);
   double sl = 0, tp = 0;
   bool ok = false;

   if(dirSign > 0)
   {
      sl = NormalizeDouble(ask - slDist, dg);
      tp = NormalizeDouble(ask + tpDist, dg);
      ok = trade.Buy(lot, symbol, ask, sl, tp, "PIVOT GREEN MARKET");
   }
   else
   {
      sl = NormalizeDouble(bid + slDist, dg);
      tp = NormalizeDouble(bid - tpDist, dg);
      ok = trade.Sell(lot, symbol, bid, sl, tp, "PIVOT RED MARKET");
   }

   if(ok)
   {
      RegisterOrderPlaced();
      ulong ticket = trade.ResultOrder();
      if(ticket > 0) SMC_ApplyPostEntrySLBuffer(symbol, ticket, 1.0);
      Print("🚀 PIVOT ", direction, " MARKET @ ", levelSource,
            " | lvl=", DoubleToString(levelPrice, dg),
            " entry=", DoubleToString(refPx, dg),
            " | vn=", g_smcGomVerdictNum, " blink=", g_signalActiveAction);
   }
   ReleaseOpenLock();
   return ok;
}

//+------------------------------------------------------------------+
//| Compte TOUTES les positions + pending orders du terminal         |
//| MaxPositionsTerminal = 2 au total, tous magics, tous symboles    |
//+------------------------------------------------------------------+
int CountTerminalOrdersOurEA()
{
   int count = 0;
   count += PositionsTotal();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT ||
         t == ORDER_TYPE_BUY_STOP  || t == ORDER_TYPE_SELL_STOP)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| MARKET au touché ligne verte (Pivot Low) / rouge (Pivot High)    |
//| Uniquement si GOM GOOD/PERFECT + décision finale clignotante     |
//+------------------------------------------------------------------+
void PivotLimitTracker_OnTick()
{
   if(!UsePivotLimitTracker) return;

   string symUpper = _Symbol;
   StringToUpper(symUpper);
   bool isSpikeSymbol = (StringFind(symUpper, "BOOM") >= 0 || StringFind(symUpper, "CRASH") >= 0 ||
                          StringFind(symUpper, "PAINX") >= 0 || StringFind(symUpper, "GAINX") >= 0);
   if(!isSpikeSymbol) return;

   PivotLimit_UpdateTickets();

   // Si DOW a déjà une position / LIMIT actif → ne pas doubler
   if(CountPositionsForSymbol(_Symbol) > 0) return;
   if(Dow_CountLimitOrders(_Symbol) > 0) return;
   if(CountTerminalOrdersOurEA() >= MaxPositionsTerminal) return;

   // GOM GOOD/PERFECT + blink BUY/SELL
   if(!IsSignalConfirmed()) return;
   int vn = g_smcGomVerdictNum;
   if(MathAbs(vn) < 2) return;

   int blinkDir = GetConfirmedSignalDir();
   if(blinkDir == 0) return;
   // Alignement verdict ↔ blink
   if((vn > 0 && blinkDir != 1) || (vn < 0 && blinkDir != -1)) return;

   string direction = (blinkDir > 0) ? "BUY" : "SELL";
   if(!IsDirectionAllowedForBoomCrash(_Symbol, direction)) return;

   double atrArr[];
   ArraySetAsSeries(atrArr, true);
   int atrH = iATR(_Symbol, PERIOD_M1, 14);
   if(atrH == INVALID_HANDLE || CopyBuffer(atrH, 0, 0, 1, atrArr) < 1) return;
   double atrVal = atrArr[0];
   if(atrVal <= 0) return;

   // Lignes pures: verte = Pivot Low / BuyLevel, rouge = Pivot High / SellLevel
   double buyLevel = 0, sellLevel = 0;
   if(ObjectFind(0, "SMC_Limit_BuyLevel") >= 0)
      buyLevel = ObjectGetDouble(0, "SMC_Limit_BuyLevel", OBJPROP_PRICE);
   if(ObjectFind(0, "SMC_Limit_SellLevel") >= 0)
      sellLevel = ObjectGetDouble(0, "SMC_Limit_SellLevel", OBJPROP_PRICE);
   // Fallback swing pivot (lignes pointillées)
   if(buyLevel <= 0 && ObjectFind(0, "SMC_Limit_SwingLow") >= 0)
      buyLevel = ObjectGetDouble(0, "SMC_Limit_SwingLow", OBJPROP_PRICE);
   if(sellLevel <= 0 && ObjectFind(0, "SMC_Limit_SwingHigh") >= 0)
      sellLevel = ObjectGetDouble(0, "SMC_Limit_SwingHigh", OBJPROP_PRICE);
   if(buyLevel <= 0 && g_lastSwingLow > 0)   buyLevel = g_lastSwingLow;
   if(sellLevel <= 0 && g_lastSwingHigh > 0) sellLevel = g_lastSwingHigh;

   static datetime s_lastPivotMarket = 0;
   if(TimeCurrent() - s_lastPivotMarket < 30) return;

   if(blinkDir > 0 && buyLevel > 0)
   {
      if(PivotLimit_ExecuteMarketAtLevel(_Symbol, "BUY", buyLevel, atrVal, "PivotLow/Green"))
         s_lastPivotMarket = TimeCurrent();
   }
   else if(blinkDir < 0 && sellLevel > 0)
   {
      if(PivotLimit_ExecuteMarketAtLevel(_Symbol, "SELL", sellLevel, atrVal, "PivotHigh/Red"))
         s_lastPivotMarket = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Nettoyage à la déconnexion                                       |
//+------------------------------------------------------------------+
void PivotLimitTracker_Cleanup()
{
   PivotLimit_CancelOrder(g_pivotBuyTicket, "cleanup");
   PivotLimit_CancelOrder(g_pivotSellTicket, "cleanup");
   g_pivotBuyTicket = 0;
   g_pivotSellTicket = 0;
   g_pivotBuyPrice = 0;
   g_pivotSellPrice = 0;
   g_pivotBuyTime = 0;
   g_pivotSellTime = 0;
}

//+------------------------------------------------------------------+
//| Status line pour le dashboard                                     |
//+------------------------------------------------------------------+
string PivotLimitTracker_StatusLine()
{
   if(!UsePivotLimitTracker) return "";
   string s = "";
   if(g_pivotBuyTicket > 0)
      s += "🟢PIVOT-LIM(BUY @" + DoubleToString(g_pivotBuyPrice, _Digits) + ") ";
   if(g_pivotSellTicket > 0)
      s += "🔴PIVOT-LIM(SELL @" + DoubleToString(g_pivotSellPrice, _Digits) + ") ";
   return s;
}

#endif // SMC_PIVOT_LIMIT_TRACKER_MQH
