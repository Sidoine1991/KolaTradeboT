//+------------------------------------------------------------------+
//| SMC_AutoScalpRange.mqh                                            |
//| SETUP 3 - Cassure de range extrême (Gold/Crypto)                 |
//| Fusion: 30 ans = range serré + volume sec + cassure confirmée;   |
//| boucle = SL dur 3$, capital composé, verification GOM.           |
//| Contrainte INVIOLABLE: perte max par trade = SMCR_MaxLossUSD.     |
//+------------------------------------------------------------------+
#ifndef SMC_AUTO_SCALP_RANGE_MQH
#define SMC_AUTO_SCALP_RANGE_MQH

input bool   SMCR_Enable        = true;   // Activer SETUP 3 (cassure range)
input double SMCR_MaxLossUSD    = 3.0;    // Perte max ABSOLUE par trade (SL dur)
input int    SMCR_RangeBars     = 20;     // Bougies H1 pour mesurer le range
input double SMCR_MaxRangeATR   = 1.5;    // Range serré si largeur <= 1.5 ATR
input double SMCR_Tp1Mult        = 1.5;   // TP1 = 1.5R
input double SMCR_Tp2Mult        = 3.0;   // TP2 = 3R (cassure range = move plus long)
input int    SMCR_Tf             = PERIOD_H1; // Période de référence du range

struct SMCR_State
{
   bool     active;
   datetime lastTradeTime;
   double   rangeHigh;
   double   rangeLow;
};
SMCR_State g_smcr;

//+------------------------------------------------------------------+
//| Lot pour perte SL <= maxLoss                                     |
//+------------------------------------------------------------------+
double SMCR_LotForMaxLoss(const string symbol, double slDistancePoints, double maxLoss)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = minLot;
   if(slDistancePoints <= 0) return minLot;

   double tickVal = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(tickVal <= 0 || tickSize <= 0 || point <= 0) return minLot;

   double pointValuePerLot = (tickVal / tickSize) * point;
   if(pointValuePerLot <= 0) return minLot;

   double lot = maxLoss / (slDistancePoints * pointValuePerLot);
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathRound(lot / lotStep) * lotStep;
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Détecte un range serré et retourne haut/bas + largeur ATR.       |
//+------------------------------------------------------------------+
bool SMCR_DetectTightRange(const string symbol, double &hi, double &lo, double &widthATR)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, (ENUM_TIMEFRAMES)SMCR_Tf, 1, SMCR_RangeBars, r) < SMCR_RangeBars) return false;

   hi = r[0].high; lo = r[0].low;
   for(int i = 1; i < SMCR_RangeBars; i++)
   {
      if(r[i].high > hi) hi = r[i].high;
      if(r[i].low < lo) lo = r[i].low;
   }
   double range = hi - lo;
   double atr = SMC_EffectiveSymbolATR(symbol);
   if(atr <= 0) return false;
   widthATR = range / atr;
   return (widthATR <= SMCR_MaxRangeATR);
}

//+------------------------------------------------------------------+
//| Tente un scalp SETUP 3 sur cassure de range confirmée.           |
//+------------------------------------------------------------------+
void SMCR_TryScalpRange(const string symbol)
{
   if(!SMCR_Enable) return;
   if(g_smcr.active) return;
   if(SMC_IsSpikeStyleSymbol(symbol)) return; // pas de synthétiques ici
   if(g_inRetrace) return; // bloqué par retracement

   double hi = 0, lo = 0, widthATR = 0;
   if(!SMCR_DetectTightRange(symbol, hi, lo, widthATR)) return;

   // Cassure confirmée par fermeture de bougie H1 au-delà du range
   MqlRates last[];
   ArraySetAsSeries(last, true);
   if(CopyRates(symbol, (ENUM_TIMEFRAMES)SMCR_Tf, 1, 1, last) < 1) return;
   double close = last[0].close;

   int dirSign = 0;
   if(close > hi) dirSign = 1;   // cassure haussière
   if(close < lo) dirSign = -1;  // cassure baissière
   if(dirSign == 0) return;

   // GOM: GOOD/PERFECT dans le bon sens
   int vn = -999;
   if(g_smcGomConnected) vn = SMCGP_GetCachedVerdictNum(symbol);
   if(vn == -999 && symbol == _Symbol) vn = g_smcGomVerdictNum;
   if(vn == -999) return;
   if(vn == 0) return;
   if(MathAbs(vn) < MinGOMVerdictNumAbs) return;
   if(dirSign > 0 && vn < 0) return;
   if(dirSign < 0 && vn > 0) return;

   // SL = retest du bord du range (tight)
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double slDistancePoints = (dirSign > 0) ? (close - lo) / point : (hi - close) / point;
   if(slDistancePoints <= 0) slDistancePoints = 10;
   // Plafonner SL à 2 ATR pour rester scalp
   double atrPts = SMC_EffectiveSymbolATR(symbol) / point;
   if(atrPts > 0) slDistancePoints = MathMin(slDistancePoints, atrPts * 2.0);

   double lot = SMCR_LotForMaxLoss(symbol, slDistancePoints, SMCR_MaxLossUSD);
   if(lot <= 0) lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   lot = MathMin(lot, balance / 10.0);
   lot = MathMax(lot, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));
   if(PositionsTotal() >= 1) return;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double entry = (dirSign > 0) ? ask : bid;
   double sl = (dirSign > 0) ? entry - slDistancePoints * point
                              : entry + slDistancePoints * point;
   double tp1 = (dirSign > 0) ? entry + slDistancePoints * SMCR_Tp1Mult * point
                               : entry - slDistancePoints * SMCR_Tp1Mult * point;
   double tp2 = (dirSign > 0) ? entry + slDistancePoints * SMCR_Tp2Mult * point
                               : entry - slDistancePoints * SMCR_Tp2Mult * point;

   MqlTradeRequest req = {};
   MqlTradeResult res = {};
   req.action = TRADE_ACTION_PENDING;
   req.symbol = symbol;
   req.volume = lot;
   req.type = (dirSign > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   req.price = entry;
   req.sl = sl;
   req.tp = tp2;
   req.magic = InpMagicNumber;
   req.deviation = 50;
   req.comment = "AUTOSCALP S3";

   if(!CanPlaceLimitOrder(symbol, req.type)) return;
   if(!ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, req.type)) return;

   if(SafeOrderSend(req, res) && res.retcode == TRADE_RETCODE_DONE)
   {
      g_smcr.active = true;
      g_smcr.lastTradeTime = TimeCurrent();
      g_smcr.rangeHigh = hi; g_smcr.rangeLow = lo;

       string dir = (dirSign > 0) ? "BUY" : "SELL";
       string gomLabel = "";
       if(MathAbs(vn) >= 3) gomLabel = (vn > 0) ? "PERFECT BUY" : "PERFECT SELL";
       else if(MathAbs(vn) >= 2) gomLabel = (vn > 0) ? "GOOD BUY" : "GOOD SELL";
       else gomLabel = "SIMPLE vn=" + IntegerToString(vn);
       string msg = "⚡ AUTOSCALP S3 [" + symbol + "]\n";
       msg += "ORDRE EXÉCUTÉ " + dir + "\n";
       msg += "GOM: " + gomLabel + " | Cassure " + ((dirSign>0)?"HAUSSE":"BAISSE") + " | width=" + DoubleToString(widthATR,2) + "ATR\n";
       msg += "Entry: " + DoubleToString(entry, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "\n";
       msg += "SL(3$): " + DoubleToString(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "\n";
       msg += "TP1(" + DoubleToString(SMCR_Tp1Mult,1) + "R): " + DoubleToString(tp1, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) +
              " | TP2(" + DoubleToString(SMCR_Tp2Mult,1) + "R): " + DoubleToString(tp2, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "\n";
       msg += "Lot: " + DoubleToString(lot,2) + " (minLot=" + DoubleToString(SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN),2) + ")";
       if(UseNotifications) SendNotification(msg);
       if(UseWhatsAppAlerts)
       {
          double conf = 1.0; int sc = 1;
          string extra = gomLabel + " width=" + DoubleToString(widthATR,2) + "ATR";
          SendSR20WhatsAppSignal("CHAIN_SIGNAL", symbol, dir, entry, sl, tp2, entry, 0, "", slDistancePoints*point, conf, sc, extra);
       }
      Print("✅ AUTOSCALP S3 ", dir, " placé ", symbol, " | width=", DoubleToString(widthATR,2),
            "ATR | Lot: ", DoubleToString(lot,2), " | SL pts: ", DoubleToString(slDistancePoints,1));
   }
   else
   {
      Print("❌ AUTOSCALP S3 échec ", symbol, " rc=", res.retcode, " ", res.comment);
   }
}

//+------------------------------------------------------------------+
//| Libère le verrou actif                                           |
//+------------------------------------------------------------------+
void SMCR_OnTickGuard()
{
   if(g_smcr.active)
   {
      bool stillOpen = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong tk = PositionGetTicket(i);
         if(tk > 0 && PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber
            && StringFind(PositionGetString(POSITION_COMMENT), "AUTOSCALP S3") >= 0)
         { stillOpen = true; break; }
      }
      if(!stillOpen) g_smcr.active = false;
   }
}

#endif // SMC_AUTO_SCALP_RANGE_MQH



