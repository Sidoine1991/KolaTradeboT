#property copyright "TradBOT"
#property version   "1.00"
#property strict

// Inputs
input string   InpSymbol              = "";                 // Empty = current chart symbol
input ENUM_TIMEFRAMES InpTF           = PERIOD_M5;          // Working timeframe
input bool     InpModeScalping        = true;               // true=Scalping(M5), false=Swing(M10/M15)
input double   InpRiskPercent         = 1.0;                // Risk per trade (% of balance)
input int      InpCooldownMinutes     = 10;                 // Cooldown between signals
input double   InpRRMin               = 2.0;                // Minimal Risk/Reward
input int      InpMagic               = 20250911;           // Magic number

// Advanced filters
input int      InpMaxSpreadPoints     = 50;                 // Max spread in points
input bool     InpUseSRFilter         = true;               // Use S/R filter
input double   InpSRDistanceATR       = 0.6;                // S/R distance in ATR multiples

// Indicator parameters
input int      InpEMA200Period        = 200;
input int      InpRSIPeriod           = 14;
input int      InpStochK              = 14;
input int      InpStochD              = 3;
input int      InpMACDFast            = 12;
input int      InpMACDSlow            = 26;
input int      InpMACDSignal          = 9;
input int      InpBBPeriod            = 20;
input double   InpBBDeviation         = 2.0;
input int      InpATRPeriod           = 14;

// Additional indicators from Streamlit
input bool     InpUseSupertrend       = true;               // Use Supertrend filter
input int      InpST_ATR_Period       = 10;                 // Supertrend ATR period
input double   InpST_Multiplier       = 3.0;                // Supertrend multiplier
input bool     InpUseVWAP             = true;               // Use VWAP filter
input int      InpVWAPWindow          = 50;                 // VWAP rolling window (bars)
input bool     InpUseSAR              = true;               // Use Parabolic SAR filter
input double   InpSARStep             = 0.02;               // SAR step
input double   InpSARMax              = 0.2;                // SAR max
input bool     InpUseIchimoku         = false;              // Use Ichimoku filter
input int      InpIchimokuTenkan      = 9;
input int      InpIchimokuKijun       = 26;
input int      InpIchimokuSenkouB     = 52;
input bool     InpUsePivots           = false;              // Use Daily Pivots filter

datetime lastSignalTime = 0;

// Indicator handles (MQL5)
int hStoch = INVALID_HANDLE;
int hMACD  = INVALID_HANDLE;
int hBB    = INVALID_HANDLE;
int hATR   = INVALID_HANDLE;
int hMA200 = INVALID_HANDLE;
int hRSI   = INVALID_HANDLE;
int hFrac  = INVALID_HANDLE;
int hSAR   = INVALID_HANDLE;
int hIchimoku = INVALID_HANDLE;

string Sym() { return (InpSymbol=="" ? _Symbol : InpSymbol); }

double PipSize()
{
   if(StringFind(Sym(),"JPY")>=0) return 0.01;
   return 0.0001;
}

bool CooldownOk()
{
   if(lastSignalTime==0) return true;
   return (TimeCurrent() - lastSignalTime) >= (InpCooldownMinutes*60);
}

bool SpreadOk()
{
   MqlTick tick; SymbolInfoTick(Sym(),tick);
   double spread = (tick.ask - tick.bid) / _Point;
   return (spread <= InpMaxSpreadPoints);
}

bool NearSupportResistance(double price, double atr)
{
   if(!InpUseSRFilter) return true;
   
   int bars = 50; // Look back 50 bars for fractals
   double up[]; ArraySetAsSeries(up,true); CopyBuffer(hFrac,0,0,bars,up);
   double dn[]; ArraySetAsSeries(dn,true); CopyBuffer(hFrac,1,0,bars,dn);
   
   double maxDistance = InpSRDistanceATR * atr;
   
   for(int i=0; i<bars; i++)
   {
      if(up[i] != EMPTY_VALUE)
      {
         if(MathAbs(price - up[i]) <= maxDistance) return true;
      }
      if(dn[i] != EMPTY_VALUE)
      {
         if(MathAbs(price - dn[i]) <= maxDistance) return true;
      }
   }
   return false;
}

bool PositionsExist(int direction)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      string s; PositionGetString(POSITION_SYMBOL,s);
      if(s!=Sym()) continue;
      long type; PositionGetInteger(POSITION_TYPE,type);
      if((direction>0 && type==POSITION_TYPE_BUY) || (direction<0 && type==POSITION_TYPE_SELL)) return true;
   }
   return false;
}

double ValuePerPoint()
{
   double tick_value, tick_size; 
   SymbolInfoDouble(Sym(),SYMBOL_TRADE_TICK_VALUE,tick_value);
   SymbolInfoDouble(Sym(),SYMBOL_TRADE_TICK_SIZE,tick_size);
   if(tick_size<=0.0) tick_size=_Point;
   return tick_value*(_Point/tick_size);
}

double CalcVolumeByRisk(double stop_distance_points)
{
   if(stop_distance_points<=0) return 0.01;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_money = balance * InpRiskPercent/100.0;
   double vpp = ValuePerPoint();
   if(vpp<=0) return 0.01;
   double lots = risk_money / (stop_distance_points * vpp);
   double minLot, maxLot, step;
   SymbolInfoDouble(Sym(),SYMBOL_VOLUME_MIN,minLot);
   SymbolInfoDouble(Sym(),SYMBOL_VOLUME_MAX,maxLot);
   SymbolInfoDouble(Sym(),SYMBOL_VOLUME_STEP,step);
   if(step<=0) step=0.01;
   lots = MathMax(minLot, MathMin(maxLot, MathFloor(lots/step)*step));
   return lots;
}

double GetLast(int handle,int buffer)
{
   double v[]; ArraySetAsSeries(v,true);
   if(handle==INVALID_HANDLE) return 0.0;
   if(CopyBuffer(handle,buffer,0,1,v)<=0) return 0.0;
   return v[0];
}

int OnInit()
{
   if(!SymbolSelect(Sym(),true)) return(INIT_FAILED);
   ChartSetInteger(0,CHART_SHOW_TRADE_LEVELS,true);

   // Create indicator handles
   hStoch = iStochastic(Sym(),InpTF,InpStochK,InpStochD,3,MODE_SMA,STO_LOWHIGH);
   hMACD  = iMACD(Sym(),InpTF,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE);
   hBB    = iBands(Sym(),InpTF,InpBBPeriod,InpBBDeviation,0,PRICE_CLOSE);
   hATR   = iATR(Sym(),InpTF,InpATRPeriod);
   hMA200 = iMA(Sym(),InpTF,InpEMA200Period,0,MODE_EMA,PRICE_CLOSE);
   hRSI   = iRSI(Sym(),InpTF,InpRSIPeriod,PRICE_CLOSE);
   hFrac  = iFractals(Sym(),InpTF);
   if(InpUseSAR)      hSAR = iSAR(Sym(),InpTF,InpSARStep,InpSARMax);
   if(InpUseIchimoku) hIchimoku = iIchimoku(Sym(),InpTF,InpIchimokuTenkan,InpIchimokuKijun,InpIchimokuSenkouB);
   if(hStoch==INVALID_HANDLE || hMACD==INVALID_HANDLE || hBB==INVALID_HANDLE || hATR==INVALID_HANDLE || hMA200==INVALID_HANDLE || hRSI==INVALID_HANDLE || hFrac==INVALID_HANDLE)
      return(INIT_FAILED);
   return(INIT_SUCCEEDED);
}

void DrawPreSignalArrow(const string sym, ENUM_TIMEFRAMES tf, int direction, double atr)
{
   // direction: 1 = buy (blue), -1 = sell (red)
   if(direction==0) return;
   datetime t[]; ArraySetAsSeries(t,true);
   double low[]; ArraySetAsSeries(low,true);
   double high[]; ArraySetAsSeries(high,true);
   if(CopyTime(sym,tf,0,1,t)<=0) return;
   if(CopyLow(sym,tf,0,1,low)<=0) return;
   if(CopyHigh(sym,tf,0,1,high)<=0) return;
   double y = (direction>0 ? (low[0]-0.2*atr) : (high[0]+0.2*atr));
   string name = (direction>0?"SniperPreBUY_":"SniperPreSELL_")+IntegerToString((long)t[0]);
   if(ObjectFind(0,name)>=0) ObjectDelete(0,name);
   ObjectCreate(0,name,OBJ_ARROW,0,t[0],y);
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,241);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_COLOR, direction>0 ? clrDodgerBlue : clrRed);
   ChartRedraw(0);
}

void OnTick()
{
   string s = Sym();
   ENUM_TIMEFRAMES tf = InpTF;

   int shift=0;
   double ema200 = GetLast(hMA200,0);
   double rsi    = GetLast(hRSI,0);
   double k      = GetLast(hStoch,0);
   double d      = GetLast(hStoch,1);
   double macd   = GetLast(hMACD,0);
   double macds  = GetLast(hMACD,1);
   double bbU    = GetLast(hBB,0);
   double bbL    = GetLast(hBB,2);
   double atr    = GetLast(hATR,0);
   double close  = iClose(s,tf,shift);

   // Additional indicators (computed on the fly)
   double sar=0.0; bool sar_ok=true;
   if(InpUseSAR && hSAR!=INVALID_HANDLE) {
      sar = GetLast(hSAR,0);
   }

   // Simple VWAP approximation over a rolling window
   double vwap=0.0; bool vwap_ok=true;
   if(InpUseVWAP) {
      int win = MathMax(10, InpVWAPWindow);
      double c[]; ArraySetAsSeries(c,true); CopyClose(s,tf,0,win,c);
      long v[]; ArraySetAsSeries(v,true); bool volok = CopyTickVolume(s,tf,0,win,v)>0;
      if(ArraySize(c)>0 && volok) {
         double num=0.0, den=0.0;
         for(int i=0;i<ArraySize(c);i++){ num += c[i]*(double)v[i]; den += (double)v[i]; }
         if(den>0) vwap = num/den; else vwap_ok=false;
      } else vwap_ok=false;
   }

   // Ichimoku basic trend filter (price vs Kijun-Sen)
   double kijun=0.0; bool ichi_ok=true;
   if(InpUseIchimoku && hIchimoku!=INVALID_HANDLE){
      kijun = GetLast(hIchimoku,1);
   }

   if(ema200==0 || close==0 || atr==0) return;

   double rr_min   = InpModeScalping ? MathMax(InpRRMin,2.0) : MathMax(InpRRMin,2.5);
   int cooldownMin = (InpModeScalping ? MathMax(InpCooldownMinutes,10) : MathMax(InpCooldownMinutes,20));

   bool aboveEMA = (close>ema200);
   bool rsi_ok_b = (rsi<35);
   bool stoch_b  = (k<d && k<30);
   bool macd_b   = (macd>macds);
   bool bb_touch_b = (close<=bbL);
   bool buy_ok = aboveEMA && rsi_ok_b && stoch_b && macd_b && (bb_touch_b || rsi<30);
   if(InpUseSAR && sar_ok)           buy_ok = buy_ok && (close>sar);
   if(InpUseVWAP && vwap_ok)         buy_ok = buy_ok && (close>=vwap);
   if(InpUseIchimoku && kijun>0.0)   buy_ok = buy_ok && (close>=kijun);

   bool belowEMA = (close<ema200);
   bool rsi_ok_s = (rsi>65);
   bool stoch_s  = (k>d && k>70);
   bool macd_s   = (macd<macds);
   bool bb_touch_s = (close>=bbU);
   bool sell_ok = belowEMA && rsi_ok_s && stoch_s && macd_s && (bb_touch_s || rsi>70);
   if(InpUseSAR && sar_ok)           sell_ok = sell_ok && (close<sar);
   if(InpUseVWAP && vwap_ok)         sell_ok = sell_ok && (close<=vwap);
   if(InpUseIchimoku && kijun>0.0)   sell_ok = sell_ok && (close<=kijun);

   if(!CooldownOk()) return;
   if(!SpreadOk()) return;

   MqlTick tick; SymbolInfoTick(s,tick);
   double ask=tick.ask, bid=tick.bid;
   if(ask<=0 || bid<=0) return;

   double sl=0, tp=0, entry=0; int direction=0;
   if(buy_ok && !PositionsExist(1) && NearSupportResistance(ask, atr))
   {
      entry = ask; sl = entry - 1.5*atr; tp = entry + rr_min*1.5*atr; direction = 1;
   }
   else if(sell_ok && !PositionsExist(-1) && NearSupportResistance(bid, atr))
   {
      entry = bid; sl = entry + 1.5*atr; tp = entry - rr_min*1.5*atr; direction = -1;
   }
   if(direction==0) return;

   // Pre-signal arrow on current bar (anticipation one bar ahead)
   DrawPreSignalArrow(s,tf,direction,atr);

   // Dessiner/mettre à jour les S/R (fractales)
   DrawFractalSR(s,tf);

   double risk_points = MathAbs(entry - sl)/_Point;
   double vol = CalcVolumeByRisk(risk_points);
   if(vol<=0) return;

   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action   = TRADE_ACTION_DEAL;
   req.symbol   = s;
   req.magic    = InpMagic;
   req.volume   = vol;
   req.deviation= 20;
   req.sl       = sl;
   req.tp       = tp;
   if(direction>0){ req.type=ORDER_TYPE_BUY; req.price=entry; }
   else           { req.type=ORDER_TYPE_SELL; req.price=entry; }

   if(OrderSend(req,res))
   {
      if(res.retcode==10009 || res.retcode==10008)
         lastSignalTime = TimeCurrent();
   }
}

void OnDeinit(const int reason)
{
   if(hStoch!=INVALID_HANDLE) IndicatorRelease(hStoch);
   if(hMACD!=INVALID_HANDLE)  IndicatorRelease(hMACD);
   if(hBB!=INVALID_HANDLE)    IndicatorRelease(hBB);
   if(hATR!=INVALID_HANDLE)   IndicatorRelease(hATR);
   if(hMA200!=INVALID_HANDLE) IndicatorRelease(hMA200);
   if(hRSI!=INVALID_HANDLE)   IndicatorRelease(hRSI);
   if(hFrac!=INVALID_HANDLE)  IndicatorRelease(hFrac);
   if(hSAR!=INVALID_HANDLE)   IndicatorRelease(hSAR);
   if(hIchimoku!=INVALID_HANDLE) IndicatorRelease(hIchimoku);
}

void ClearObjectsByPrefix(const string prefix)
{
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--)
   {
      string name = ObjectName(0,i,-1,-1);
      if(StringFind(name,prefix)==0) ObjectDelete(0,name);
   }
}

void DrawFractalSR(const string sym, ENUM_TIMEFRAMES tf)
{
   // Dessine des segments S/R à partir des fractales récentes (style TradingView)
   int bars = 300;
   datetime t[]; ArraySetAsSeries(t,true); CopyTime(sym,tf,0,bars,t);
   double up[]; ArraySetAsSeries(up,true); CopyBuffer(hFrac,0,0,bars,up); // upper
   double dn[]; ArraySetAsSeries(dn,true); CopyBuffer(hFrac,1,0,bars,dn); // lower
   if(ArraySize(t)==0) return;

   ClearObjectsByPrefix("SR_");
   int drawnU=0, drawnD=0;
   int maxSeg=8; // limiter pour la lisibilité
   int segLen=25; // longueur en barres
   color colU = clrMagenta; // résistance
   color colD = clrDodgerBlue; // support

   for(int i=1; i<bars-1 && (drawnU<maxSeg || drawnD<maxSeg); i++)
   {
      if(drawnU<maxSeg && up[i]!=EMPTY_VALUE)
      {
         int j = MathMax(0, i - segLen);
         string name = StringFormat("SR_U_%d",(int)t[i]);
         ObjectCreate(0,name,OBJ_TREND,0,t[i],up[i],t[j],up[i]);
         ObjectSetInteger(0,name,OBJPROP_COLOR,colU);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,3);
         drawnU++;
      }
      if(drawnD<maxSeg && dn[i]!=EMPTY_VALUE)
      {
         int j = MathMax(0, i - segLen);
         string name = StringFormat("SR_D_%d",(int)t[i]);
         ObjectCreate(0,name,OBJ_TREND,0,t[i],dn[i],t[j],dn[i]);
         ObjectSetInteger(0,name,OBJPROP_COLOR,colD);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,3);
         drawnD++;
      }
   }
}


