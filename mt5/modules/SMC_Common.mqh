//+------------------------------------------------------------------+
//| SMC_Common.mqh — Helpers partagés SMC Universal                  |
//+------------------------------------------------------------------+
#ifndef __SMC_COMMON_MQH__
#define __SMC_COMMON_MQH__

//--- ATR cache
double GOM_GetATRValue(const string symbol=NULL,
                       const ENUM_TIMEFRAMES tf=PERIOD_CURRENT,
                       const int period=14)
{
   string sym = (symbol==NULL || symbol=="") ? _Symbol : symbol;
   ENUM_TIMEFRAMES useTf = (tf==PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : tf;
   int handle = iATR(sym, useTf, period);
   if(handle==INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf,true);
   double atr=0.0;
   if(CopyBuffer(handle,0,0,1,buf)>=1)
      atr=buf[0];
   IndicatorRelease(handle);
   return atr;
}

//--- Direction native synthétiques
int SMC_GetNativeDirection(const string symbol)
{
   string s=symbol;
   StringToUpper(s);
   if(StringFind(s,"GAINX")>=0 || StringFind(s,"BOOM")>=0) return 1;
   if(StringFind(s,"PAINX")>=0 || StringFind(s,"CRASH")>=0) return -1;
   if(StringFind(s,"VOLATILITY")>=0 || StringFind(s,"VIX")>=0)
      return AllowVolatilityBothDirections ? 0 : 0;
   return 0;
}

string SMC_NativeDirectionToString(const int d)
{
   if(d>0) return "BUY_ONLY";
   if(d<0) return "SELL_ONLY";
   return "BOTH";
}

//--- Verdict GOM (manuel / GlobalVariable / futur HTTP)
int GOM_GetVerdictNumber()
{
   // 1) GlobalVariable optionnelle
   if(StringLen(GOM_GlobalVariable)>0 && GlobalVariableCheck(GOM_GlobalVariable))
   {
      int v=(int)MathRound(GlobalVariableGet(GOM_GlobalVariable));
      if(v>=-3 && v<=3) return v;
   }
   // 2) Input manuel
   if(ManualGOMVerdict>=-3 && ManualGOMVerdict<=3)
      return ManualGOMVerdict;
   return 0;
}

bool GOM_IsGoodOrPerfect(const int vn)
{
   return (MathAbs(vn)>=MinGOMVerdictNumAbs);
}

string GOM_VerdictToString(const int vn)
{
   if(vn>=3)  return "PERFECT BUY";
   if(vn==2)  return "GOOD BUY";
   if(vn==1)  return "SIMPLE BUY";
   if(vn==0)  return "WAIT";
   if(vn==-1) return "SIMPLE SELL";
   if(vn==-2) return "GOOD SELL";
   if(vn<=-3) return "PERFECT SELL";
   return "WAIT";
}

string GOM_PhaseToString(const ENUM_GOM_PHASE ph)
{
   switch(ph)
   {
      case GOM_PHASE_IMPULSE:      return "IMPULSE";
      case GOM_PHASE_RETRACE:      return "RETRACE";
      case GOM_PHASE_WAIT_REBOUND: return "WAIT_REBOUND";
      default:                     return "NEUTRAL";
   }
}

//--- Position helpers
bool SMC_HasManagedPosition(const string symbol)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      return true;
   }
   return false;
}

int SMC_CountManagedPositions(const string symbol="")
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(symbol!="" && PositionGetString(POSITION_SYMBOL)!=symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      n++;
   }
   return n;
}

//--- Normalize stop vs stops level
double SMC_NormalizeStop(const string symbol, const double sl, const int dir)
{
   if(sl<=0.0) return 0.0;
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   int stops=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist=(stops+2)*point;
   double bid=SymbolInfoDouble(symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(symbol,SYMBOL_ASK);
   double out=NormalizeDouble(sl,digits);
   if(dir>0)
   {
      if(out>=bid-minDist) out=NormalizeDouble(bid-minDist,digits);
   }
   else
   {
      if(out<=ask+minDist) out=NormalizeDouble(ask+minDist,digits);
   }
   return out;
}

//--- SL initial: max(ATR*mult, ~$2 risque)
double SMC_CalculateInitialSL(const int dir,
                              const double entry,
                              const double atr,
                              const double lots)
{
   double slDist=atr*MathMax(SL_ATRMult,2.5);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double vol=(lots>0.0)?lots:InpLots;
   if(tv>0.0 && ts>0.0 && vol>0.0)
   {
      double ppd=(tv*vol)/ts;
      if(ppd>0.0)
         slDist=MathMax(slDist,2.0/ppd);
   }
   double sl=(dir>0)?(entry-slDist):(entry+slDist);
   return SMC_NormalizeStop(_Symbol,sl,dir);
}

//--- Chart object price (trendline / hline)
bool SMC_GetObjectPrice(const string namePart, const datetime t, double &outPrice)
{
   outPrice=0.0;
   int total=ObjectsTotal(0,0,-1);
   for(int i=total-1;i>=0;i--)
   {
      string name=ObjectName(0,i,0,-1);
      if(StringFind(name,namePart)<0) continue;
      int type=(int)ObjectGetInteger(0,name,OBJPROP_TYPE);
      if(type==OBJ_HLINE || type==OBJ_TREND || type==OBJ_ARROW || type==OBJ_TEXT)
      {
         double p0=ObjectGetDouble(0,name,OBJPROP_PRICE,0);
         double p1=ObjectGetDouble(0,name,OBJPROP_PRICE,1);
         if(type==OBJ_TREND && p0>0.0 && p1>0.0)
         {
            datetime t0=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,0);
            datetime t1=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,1);
            if(t1!=t0)
            {
               double slope=(p1-p0)/(double)(t1-t0);
               outPrice=p0+slope*(double)(t-t0);
            }
            else outPrice=(p0+p1)*0.5;
         }
         else if(p0>0.0) outPrice=p0;
         if(outPrice>0.0) return true;
      }
   }
   return false;
}

bool SMC_ObjectBroken(const string namePart, const double mid, const double atr)
{
   double lvl=0.0;
   if(!SMC_GetObjectPrice(namePart,TimeCurrent(),lvl) || lvl<=0.0) return false;
   // Cassure simple: prix au-delà du niveau de > 0.5 ATR
   int vn=GOM_GetVerdictNumber();
   if(vn<0 && mid>lvl+atr*0.5) return true; // SELL bias, cassure haussière
   if(vn>0 && mid<lvl-atr*0.5) return true; // BUY bias, cassure baissière
   return false;
}

bool SMC_PriceTouchesLevel(const double price,
                           const double level,
                           const double atr,
                           const double tolATR)
{
   if(level<=0.0 || atr<=0.0) return false;
   return (MathAbs(price-level)<=atr*tolATR);
}

//--- Spike detection M1 (corps fort + direction)
bool SMC_ReactionSpikeNow(const int dirSign, const double atr)
{
   if(atr<=0.0 || dirSign==0) return false;
   MqlRates r[];
   ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,PERIOD_M1,0,4,r)<3) return false;
   for(int i=0;i<=1;i++)
   {
      double range=r[i].high-r[i].low;
      double body=MathAbs(r[i].close-r[i].open);
      bool dirOk=(dirSign>0 && r[i].close>r[i].open) || (dirSign<0 && r[i].close<r[i].open);
      if(dirOk && (body>=atr*0.70 || range>=atr*0.90))
         return true;
   }
   return false;
}

//--- Réaction M5 (rejet sur GOM_TF_TL_M5)
bool SMC_M5ReactionDetected()
{
   double atr=GOM_GetATRValue(_Symbol,PERIOD_M5,ATR_Period);
   if(atr<=0.0) atr=GOM_GetATRValue();
   double level=0.0;
   if(!SMC_GetObjectPrice(GOM_M5_Object,TimeCurrent(),level))
      return false;
   MqlRates r[];
   ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,PERIOD_M5,0,3,r)<2) return false;
   int vn=GOM_GetVerdictNumber();
   int dir=(vn>0)?1:((vn<0)?-1:SMC_GetNativeDirection(_Symbol));
   double tol=atr*GOM_ReactTolATR;
   if(dir>0)
   {
      bool touch=r[1].low<=level+tol;
      bool reject=r[1].close>level && r[1].close>r[1].open;
      return touch && reject;
   }
   if(dir<0)
   {
      bool touch=r[1].high>=level-tol;
      bool reject=r[1].close<level && r[1].close<r[1].open;
      return touch && reject;
   }
   return false;
}

//--- Safe trade wrappers
bool SafeTradeBuy(const double lots, const double sl, const double tp, const string comment)
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double nsl=SMC_NormalizeStop(_Symbol,sl,1);
   double ntp=(tp>0.0)?NormalizeDouble(tp,_Digits):0.0;
   bool ok=trade.Buy(lots,_Symbol,ask,nsl,ntp,comment);
   if(!ok)
      Print("[TRADE] Buy fail ",trade.ResultRetcode()," ",trade.ResultRetcodeDescription());
   return ok;
}

bool SafeTradeSell(const double lots, const double sl, const double tp, const string comment)
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double nsl=SMC_NormalizeStop(_Symbol,sl,-1);
   double ntp=(tp>0.0)?NormalizeDouble(tp,_Digits):0.0;
   bool ok=trade.Sell(lots,_Symbol,bid,nsl,ntp,comment);
   if(!ok)
      Print("[TRADE] Sell fail ",trade.ResultRetcode()," ",trade.ResultRetcodeDescription());
   return ok;
}

bool SafeTradeBuyLimit(const double lots, const double price,
                       const double sl, const double tp,
                       const datetime expiry, const string comment)
{
   double nsl=SMC_NormalizeStop(_Symbol,sl,1);
   double ntp=(tp>0.0)?NormalizeDouble(tp,_Digits):0.0;
   double px=NormalizeDouble(price,_Digits);
   bool ok=trade.BuyLimit(lots,px,_Symbol,nsl,ntp,ORDER_TIME_SPECIFIED,expiry,comment);
   if(!ok)
      Print("[TRADE] BuyLimit fail ",trade.ResultRetcode()," ",trade.ResultRetcodeDescription());
   return ok;
}

bool SafeTradeSellLimit(const double lots, const double price,
                        const double sl, const double tp,
                        const datetime expiry, const string comment)
{
   double nsl=SMC_NormalizeStop(_Symbol,sl,-1);
   double ntp=(tp>0.0)?NormalizeDouble(tp,_Digits):0.0;
   double px=NormalizeDouble(price,_Digits);
   bool ok=trade.SellLimit(lots,px,_Symbol,nsl,ntp,ORDER_TIME_SPECIFIED,expiry,comment);
   if(!ok)
      Print("[TRADE] SellLimit fail ",trade.ResultRetcode()," ",trade.ResultRetcodeDescription());
   return ok;
}

#endif // __SMC_COMMON_MQH__
