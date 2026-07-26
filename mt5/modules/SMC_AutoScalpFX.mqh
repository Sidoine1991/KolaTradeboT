//+------------------------------------------------------------------+
//| SMC_AutoScalpFX.mqh                                               |
//| SETUP 2 - Chasse aux stops (Liquidity Sweep) Forex/Crypto/Gold   |
//| Fusion: 30 ans = balayage liquidité + trade dans le sens HTF;    |
//| boucle = SL dur 3$, capital composé, verification GOM.           |
//| Contrainte INVIOLABLE: perte max par trade = SMCFX_MaxLossUSD.    |
//+------------------------------------------------------------------+
#ifndef SMC_AUTO_SCALP_FX_MQH
#define SMC_AUTO_SCALP_FX_MQH

input bool   SMCFX_Enable       = true;   // Activer SETUP 2 (chasse stops)
input double SMCFX_MaxLossUSD   = 3.0;    // Perte max ABSOLUE par trade (SL dur)
input double SMCFX_Tp1Mult       = 1.0;   // TP1 = 1R
input double SMCFX_Tp2Mult       = 2.0;   // TP2 = 2R
input int    SMCFX_SweepLookback = 5;     // Bougies scannées pour le sweep
input bool   SMCFX_RequireHTFTrend = true;// Exiger tendance HTF dans le sens du trade

struct SMCFX_State
{
   bool     active;
   datetime lastTradeTime;
};
SMCFX_State g_smcfx;

//+------------------------------------------------------------------+
//| Calcule le lot pour perte SL <= maxLoss (réutilise la même loi)  |
//+------------------------------------------------------------------+
double SMCFX_LotForMaxLoss(const string symbol, double slDistancePoints, double maxLoss)
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
//| Tente un scalp SETUP 2 (chasse stops) sur un symbole.            |
//| BSL -> BUY si HTF haussier ; SSL -> SELL si HTF baissier.        |
//+------------------------------------------------------------------+
void SMCFX_TryScalpSweep(const string symbol)
{
   if(!SMCFX_Enable) return;
   if(g_smcfx.active) return;
   if(SMC_IsSpikeStyleSymbol(symbol)) return; // SETUP 2 = Forex/Crypto/Gold, pas synthétiques
   if(g_inRetrace) return; // bloqué par retracement

   string lsType = "";
   int barsAgo = 0;
   if(!SMC_DetectLiquiditySweepEx(symbol, LTF, lsType, barsAgo)) return;
   if(barsAgo > SMCFX_SweepLookback) return;

   bool bullHTF = IsBullishHTF();
   int dirSign = 0;
   if(lsType == "BSL" && (!SMCFX_RequireHTFTrend || bullHTF)) dirSign = 1;   // chasse stops acheteurs -> rebond haussier
   if(lsType == "SSL" && (!SMCFX_RequireHTFTrend || !bullHTF)) dirSign = -1; // chasse stops vendeurs -> repli baissier
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

   // Distance SL = petit multiple de point (scalp tight)
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double slDistancePoints = MathMax(10.0, SymbolInfoInteger(symbol, SYMBOL_DIGITS) * 0.5); // ~0.5 digit-unités de SL
   // Pour FX le SL doit être en points réels: utiliser ATR mini
   double atrPts = 0;
   if(atrHandle != INVALID_HANDLE)
   {
      double a[];
      ArraySetAsSeries(a, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, a) > 0) atrPts = a[0] / point;
   }
   if(atrPts <= 0) atrPts = slDistancePoints;
   slDistancePoints = MathMax(slDistancePoints, atrPts * 0.3); // SL = 30% ATR (très tight)

   double lot = SMCFX_LotForMaxLoss(symbol, slDistancePoints, SMCFX_MaxLossUSD);
   if(lot <= 0) lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   lot = MathMin(lot, balance / 10.0); // jamais plus de 10% du capital
   lot = MathMax(lot, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));
   if(PositionsTotal() >= 1) return;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double entry = (dirSign > 0) ? ask : bid;
   double sl = (dirSign > 0) ? entry - slDistancePoints * point
                              : entry + slDistancePoints * point;
   double tp1 = (dirSign > 0) ? entry + slDistancePoints * SMCFX_Tp1Mult * point
                               : entry - slDistancePoints * SMCFX_Tp1Mult * point;
   double tp2 = (dirSign > 0) ? entry + slDistancePoints * SMCFX_Tp2Mult * point
                               : entry - slDistancePoints * SMCFX_Tp2Mult * point;

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
   req.comment = "AUTOSCALP S2";

   if(!CanPlaceLimitOrder(symbol, req.type)) return;
   if(!ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, req.type)) return;

   if(OrderSend(req, res) && res.retcode == TRADE_RETCODE_DONE)
   {
      g_smcfx.active = true;
      g_smcfx.lastTradeTime = TimeCurrent();

       string dir = (dirSign > 0) ? "BUY" : "SELL";
       string gomLabel = "";
       if(MathAbs(vn) >= 3) gomLabel = (vn > 0) ? "PERFECT BUY" : "PERFECT SELL";
       else if(MathAbs(vn) >= 2) gomLabel = (vn > 0) ? "GOOD BUY" : "GOOD SELL";
       else gomLabel = "SIMPLE vn=" + IntegerToString(vn);
       string msg = "⚡ AUTOSCALP S2 [" + symbol + "]\n";
       msg += "ORDRE EXÉCUTÉ " + dir + "\n";
       msg += "GOM: " + gomLabel + " | Sweep: " + lsType + " | HTF: " + (bullHTF ? "BULL" : "BEAR") + "\n";
       msg += "Entry: " + DoubleToString(entry, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "\n";
       msg += "SL(3$): " + DoubleToString(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "\n";
       msg += "TP1(" + DoubleToString(SMCFX_Tp1Mult,1) + "R): " + DoubleToString(tp1, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) +
              " | TP2(" + DoubleToString(SMCFX_Tp2Mult,1) + "R): " + DoubleToString(tp2, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "\n";
       msg += "Lot: " + DoubleToString(lot,2) + " (minLot=" + DoubleToString(SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN),2) + ")";
       if(UseNotifications) SendNotification(msg);
       if(UseWhatsAppAlerts)
       {
          double conf = 1.0; int sc = 1;
          string extra = gomLabel + " Sweep=" + lsType;
          SendSR20WhatsAppSignal("CHAIN_SIGNAL", symbol, dir, entry, sl, tp2, entry, 0, "", slDistancePoints*point, conf, sc, extra);
       }
      Print("✅ AUTOSCALP S2 ", dir, " placé ", symbol, " | Sweep: ", lsType,
            " | Lot: ", DoubleToString(lot,2), " | SL pts: ", DoubleToString(slDistancePoints,1));
   }
   else
   {
      Print("❌ AUTOSCALP S2 échec ", symbol, " rc=", res.retcode, " ", res.comment);
   }
}

//+------------------------------------------------------------------+
//| Libère le verrou actif                                           |
//+------------------------------------------------------------------+
void SMCFX_OnTickGuard()
{
   if(g_smcfx.active)
   {
      bool stillOpen = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong tk = PositionGetTicket(i);
         if(tk > 0 && PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber
            && StringFind(PositionGetString(POSITION_COMMENT), "AUTOSCALP S2") >= 0)
         { stillOpen = true; break; }
      }
      if(!stillOpen) g_smcfx.active = false;
   }
}

#endif // SMC_AUTO_SCALP_FX_MQH
