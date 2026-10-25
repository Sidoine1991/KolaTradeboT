//+------------------------------------------------------------------+
//|                                            EA_TradBOT_Pro_OTE.mq5|
//|   EA combinant OTE + confluences (EMA200, Supertrend proxy, RSI) |
//|   et option d'alignement avec l'API de tendance (via iCustom).    |
//+------------------------------------------------------------------+
#property strict

input string  InpSymbol           = "";           // Vide = symbole du graphique
input ENUM_TIMEFRAMES InpTF       = PERIOD_CURRENT;
input double  InpMinLot           = 1.0;          // Lot minimum
input double  InpRiskPct          = 1.0;          // Risque % par trade (optionnel)
input int     InpOTEPivotWindow   = 5;            // Fenêtre pivots
// Stops/targets agnostiques au symbole
input bool    InpStopsInPoints    = true;         // true = utiliser des points (agnostique), false = pips
input int     InpSLPoints         = 500;          // SL en points (si InpStopsInPoints)
input int     InpTPPoints         = 1500;         // TP en points (si InpStopsInPoints)
input int     InpSLPips           = 20;           // SL en pips (si !InpStopsInPoints)
input int     InpTPPips           = 60;           // TP en pips (si !InpStopsInPoints)
input int     InpMagic            = 27191;        // Magic
input int     InpSlippage         = 10;           // Slippage
input bool    InpOnePosPerSide    = true;         // Empêcher multi-positions par côté
// Confluences
input bool    InpUseEMA200Filter  = true;
input bool    InpUseRSIFilter     = true;
input int     InpRSIPeriod        = 14;
input bool    InpUseSupertrend    = true;         // Supertrend proxy via ATR band crossing
// Filtres modernes
input bool    InpUseADXFilter     = true;
input int     InpADXPeriod        = 14;
input int     InpADXMin           = 18;           // ADX minimum
input bool    InpUseATRVolFilter  = true;         // Filtre volatilité minimale ATR
input int     InpATRPeriodFilter  = 14;
input double  InpATRMinMultPoint  = 50;           // ATR minimal en points (ex: 50 points)

int OnInit(){ return(INIT_SUCCEEDED);} void OnDeinit(const int reason){}

bool GetConfluences(string sym, ENUM_TIMEFRAMES tf, double &ema200, double &rsi, double &st_dir)
{
   ema200 = 0; rsi = 50; st_dir = 0;
   int bars = 300;
   double ema[]; ArraySetAsSeries(ema,true);
   int hMA = iMA(sym, tf, 200, 0, MODE_EMA, PRICE_CLOSE); if(hMA==INVALID_HANDLE) return false;
   if(CopyBuffer(hMA,0,0,bars,ema)<=0) return false; ema200 = ema[0];
   if(InpUseRSIFilter)
   {
      double rbuf[]; ArraySetAsSeries(rbuf,true);
      int hRSI = iRSI(sym, tf, InpRSIPeriod, PRICE_CLOSE); if(hRSI==INVALID_HANDLE) return false;
      if(CopyBuffer(hRSI,0,0,bars,rbuf)<=0) return false; rsi = rbuf[0];
   }
   if(InpUseSupertrend)
   {
      // Proxy: direction = close par rapport à mid +/- ATR
      MqlRates rates[]; ArraySetAsSeries(rates,true); if(CopyRates(sym,tf,0,300,rates)<=50) return false;
      int hATR = iATR(sym, tf, 14); double atr[]; ArraySetAsSeries(atr,true); if(CopyBuffer(hATR,0,0,300,atr)<=0) return false;
      double mid=(rates[0].high+rates[0].low)*0.5; double bandUp=mid+3.0*atr[0]; double bandDn=mid-3.0*atr[0];
      st_dir = (rates[0].close>bandUp?1:(rates[0].close<bandDn?-1:0));
   }
   if(InpUseADXFilter)
   {
      double adxbuf[]; ArraySetAsSeries(adxbuf,true);
      int hADX = iADX(sym, tf, InpADXPeriod); if(hADX==INVALID_HANDLE) return false;
      if(CopyBuffer(hADX,0,0,300,adxbuf)<=0) return false; // buffer 0 = ADX main
      if((int)adxbuf[0] < InpADXMin) return false; // rejette si tendance trop faible
   }
   if(InpUseATRVolFilter)
   {
      double atrf[]; ArraySetAsSeries(atrf,true);
      int hATRF = iATR(sym, tf, InpATRPeriodFilter); if(hATRF==INVALID_HANDLE) return false;
      if(CopyBuffer(hATRF,0,0,300,atrf)<=0) return false;
      if(atrf[0] < InpATRMinMultPoint*SymbolInfoDouble(sym,SYMBOL_POINT)) return false;
   }
   return true;
}

bool DetectOTE(string sym, ENUM_TIMEFRAMES tf, int w, double &fib0, double &fib1, bool &up)
{
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(sym, tf, 0, 500, r)<=100) return false;
   int start=w, end=ArraySize(r)-1-w; if(end<start) return false;
   int lastH=-1,lastL=-1;
   for(int i=end;i>=start;i--){ bool isH=true; for(int k=1;k<=w;k++){ if(r[i].high<=r[i-k].high || r[i].high<=r[i+k].high){ isH=false; break; } } if(isH){ lastH=i; break; } }
   for(int i=end;i>=start;i--){ bool isL=true; for(int k=1;k<=w;k++){ if(r[i].low >=r[i-k].low  || r[i].low >=r[i+k].low ){ isL=false; break; } } if(isL){ lastL=i; break; } }
   if(lastH<0 || lastL<0) return false;
   double swingH=r[lastH].high, swingL=r[lastL].low; double rng=swingH-swingL; if(rng<=0) return false;
   up = (lastH>lastL); fib0 = up ? swingL : swingH; fib1 = up ? swingH : swingL; return true;
}

void OnTick()
{
   string sym = (InpSymbol=="" ? _Symbol : InpSymbol);
   ENUM_TIMEFRAMES tf = (InpTF==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTF);

   double ema200, rsi, st_dir; if(!GetConfluences(sym, tf, ema200, rsi, st_dir)) return;

   double bid=SymbolInfoDouble(sym, SYMBOL_BID), ask=SymbolInfoDouble(sym, SYMBOL_ASK), px=(bid+ask)*0.5; if(px<=0) return;
   bool up; double fib0, fib1; if(!DetectOTE(sym, tf, MathMax(3, MathMin(11, InpOTEPivotWindow)), fib0, fib1, up)) return; double rng=fib1-fib0; if(rng<0) rng=-rng;

   // Position relative OTE
   bool buy_ok=false, sell_ok=false;
   if(up){ double pos=(px-fib0)/rng; buy_ok=(pos>=0.0 && pos<=0.5); sell_ok=(pos>=0.78 && pos<=1.0); }
   else  { double posD=(fib1-px)/rng; sell_ok=(posD>=0.0 && posD<=0.5); buy_ok=(posD>=0.78 && posD<=1.0); }

   // Filtres confluences
   if(InpUseEMA200Filter){ if(buy_ok && px<ema200) buy_ok=false; if(sell_ok && px>ema200) sell_ok=false; }
   if(InpUseRSIFilter){ if(buy_ok && rsi<40) buy_ok=false; if(sell_ok && rsi>60) sell_ok=false; }
   if(InpUseSupertrend){ if(buy_ok && st_dir<0) buy_ok=false; if(sell_ok && st_dir>0) sell_ok=false; }

   // Gestion positions existantes
   int buys=0,sells=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(PositionSelectByTicket(t)&&PositionGetString(POSITION_SYMBOL)==sym){ long ty=PositionGetInteger(POSITION_TYPE); if(ty==POSITION_TYPE_BUY) buys++; else if(ty==POSITION_TYPE_SELL) sells++; }}
   if(InpOnePosPerSide && ((buy_ok && buys>0) || (sell_ok && sells>0))) return;

   // Volume
   double lot = MathMax(InpMinLot, 1.0);
   double pt=SymbolInfoDouble(sym,SYMBOL_POINT);
   double sl_points, tp_points;
   if(InpStopsInPoints)
   {
      sl_points = (double)InpSLPoints;
      tp_points = (double)InpTPPoints;
   }
   else
   {
      // Conversion pips->points agnostique: estime 1 pip = 10^(-2) unités de prix si digits>=2, sinon = point
      int digits=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
      double pip_guess = (digits>=2 ? 0.01 : pt);
      sl_points = (InpSLPips * (pip_guess/pt));
      tp_points = (InpTPPips * (pip_guess/pt));
   }

   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action=TRADE_ACTION_DEAL; req.symbol=sym; req.type_filling=ORDER_FILLING_IOC; req.deviation=InpSlippage; req.magic=InpMagic; req.volume=lot;

   if(buy_ok)
   { req.type=ORDER_TYPE_BUY; req.price=SymbolInfoDouble(sym,SYMBOL_ASK); req.sl=req.price - sl_points*pt; req.tp=req.price + tp_points*pt; OrderSend(req,res); }
   else if(sell_ok)
   { req.type=ORDER_TYPE_SELL; req.price=SymbolInfoDouble(sym,SYMBOL_BID); req.sl=req.price + sl_points*pt; req.tp=req.price - tp_points*pt; OrderSend(req,res); }
}


