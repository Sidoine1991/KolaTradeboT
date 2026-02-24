//+------------------------------------------------------------------+
//|                                    BoomCrash_Spike_Predictor.mq5 |
//|            Spike catcher prédictif simple pour Boom / Crash      |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

//------------------- INPUTS ----------------------------------------
input ulong InpMagicNumber      = 20251115;
input ENUM_TIMEFRAMES InpTF    = PERIOD_M1;
input double InpRiskPercent    = 1.0;   // % risque par trade
input double InpFixedLot       = 0.0;   // 0 = auto, sinon lot fixe
input int    InpATR_Period     = 14;
input double InpSL_ATR_Mult    = 1.5;   // SL = 1.5 * ATR
input double InpTP_ATR_Mult    = 3.0;   // TP = 3.0 * ATR
input double InpSpikeZScore    = 1.5;   // Seuil Z-Score spike
input double InpMinSpikeMult   = 2.0;   // close‑move >= 2x moyenne
input bool   InpOnlyOnePosSym  = true;  // 1 trade max par symbole
input bool   InpDebug          = true;

//------------------- HANDLES / STATE -------------------------------
int   g_atrHandle = INVALID_HANDLE;
datetime g_lastBarTime = 0;

//------------------- HELPERS ---------------------------------------
bool IsSymbolBoom(string s)
{
   return (StringFind(s,"Boom",0) >= 0 || StringFind(s,"BOOM",0) >= 0);
}

bool IsSymbolCrash(string s)
{
   return (StringFind(s,"Crash",0) >= 0 || StringFind(s,"CRASH",0) >= 0);
}

bool IsBoomCrashSymbol(string s)
{
   return (IsSymbolBoom(s) || IsSymbolCrash(s));
}

double GetCurrentATR()
{
   if(g_atrHandle == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf,true);
   if(CopyBuffer(g_atrHandle,0,0,1,buf) <= 0) return 0.0;
   return buf[0];
}

double CalcAutoLot(double atr)
{
   double minLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   if(InpFixedLot > 0.0)
   {
      double l = MathFloor(InpFixedLot/lotStep + 0.5)*lotStep;
      return MathMax(minLot,MathMin(maxLot,l));
   }

   if(atr <= 0.0) return minLot;

   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk$ = bal * InpRiskPercent/100.0;
   double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double tickV = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickS = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickV <= 0 || tickS <= 0) return minLot;

   double slPoints = (InpSL_ATR_Mult * atr)/point;
   if(slPoints <= 0) return minLot;

   double valPerPointPerLot = (tickV/tickS)*point;
   double lot = risk$/(slPoints*valPerPointPerLot);
   lot = MathFloor(lot/lotStep)*lotStep;

   return MathMax(minLot,MathMin(maxLot,lot));
}

bool HasOpenPositionForSymbol()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
   }
   return false;
}

//------------------- SPIKE DETECTION -------------------------------
bool DetectSpike(double &strength,int &direction)
{
   strength = 0.0;
   direction = 0;

   MqlRates rates[];
   int lookback = 20;
   if(CopyRates(_Symbol,InpTF,0,lookback,rates) < lookback) return false;
   ArraySetAsSeries(rates,true);

   // mouvements de clôture
   double moves[];
   ArrayResize(moves,lookback-1);
   double sum=0.0;
   for(int i=0;i<lookback-1;i++)
   {
      moves[i] = MathAbs(rates[i].close - rates[i+1].close);
      sum += moves[i];
   }
   double mean = sum/(lookback-1);
   if(mean<=0) return false;

   double var=0.0;
   for(int i=0;i<lookback-1;i++)
      var += MathPow(moves[i]-mean,2);
   double sd = MathSqrt(var/(lookback-1));
   if(sd<=0) sd = mean;

   double curMove = MathAbs(rates[0].close - rates[0].open);
   double z = (curMove-mean)/sd;

   bool isSpike = (z >= InpSpikeZScore) || (curMove >= mean*InpMinSpikeMult);
   if(!isSpike) return false;

   strength = z*20.0;
   direction = (rates[0].close > rates[0].open) ? 1 : -1;

   if(InpDebug)
      Print("Spike détecté: z=",DoubleToString(z,2),
            " move=",DoubleToString(curMove,_Digits),
            " mean=",DoubleToString(mean,_Digits),
            " dir=",direction>0?"UP":"DOWN");

   return true;
}

//------------------- EXECUTION -------------------------------------
bool ExecuteSpikeTrade(int spikeDir)
{
   if(!IsBoomCrashSymbol(_Symbol)) return false;

   bool isBoom  = IsSymbolBoom(_Symbol);
   bool isCrash = IsSymbolCrash(_Symbol);

   // Règle stricte: BUY seulement sur Boom, SELL seulement sur Crash
   if(isBoom && spikeDir < 0) return false;
   if(isCrash && spikeDir > 0) return false;

   ENUM_ORDER_TYPE type = (spikeDir>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL);

   double atr = GetCurrentATR();
   if(atr<=0.0) return false;

   double lot = CalcAutoLot(atr);
   if(lot<=0.0) return false;

   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   double price = (type==ORDER_TYPE_BUY ? ask : bid);
   double sl,tp;

   if(type==ORDER_TYPE_BUY)
   {
      sl = price - atr*InpSL_ATR_Mult;
      tp = price + atr*InpTP_ATR_Mult;
   }
   else
   {
      sl = price + atr*InpSL_ATR_Mult;
      tp = price - atr*InpTP_ATR_Mult;
   }

   sl = NormalizeDouble(sl,digits);
   tp = NormalizeDouble(tp,digits);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(5);

   bool ok = false;
   if(type==ORDER_TYPE_BUY)
      ok = trade.Buy(lot,_Symbol,0,sl,tp,"BoomCrash spike BUY");
   else
      ok = trade.Sell(lot,_Symbol,0,sl,tp,"BoomCrash spike SELL");

   if(ok)
   {
      if(InpDebug)
         Print("✅ Spike trade ",EnumToString(type)," lot=",DoubleToString(lot,2),
               " SL=",DoubleToString(sl,digits)," TP=",DoubleToString(tp,digits));
   }
   else
   {
      Print("❌ Echec spike trade: ",trade.ResultRetcode()," - ",trade.ResultRetcodeDescription());
   }
   return ok;
}

//------------------- MT5 LIFECYCLE ---------------------------------
int OnInit()
{
   if(!IsBoomCrashSymbol(_Symbol))
   {
      Print("⚠️ BoomCrash_Spike_Predictor est conçu uniquement pour Boom/Crash. Symbole actuel: ",_Symbol);
   }

   g_atrHandle = iATR(_Symbol,InpTF,InpATR_Period);
   if(g_atrHandle==INVALID_HANDLE)
   {
      Print("❌ Erreur création ATR handle");
      return INIT_FAILED;
   }

   EventSetTimer(1); // boucle chaque seconde
   Print("✅ BoomCrash_Spike_Predictor initialisé sur ",_Symbol," TF=",EnumToString(InpTF));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atrHandle!=INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   EventKillTimer();
   Print("BoomCrash_Spike_Predictor arrêté sur ",_Symbol);
}

void OnTimer()
{
   if(!IsBoomCrashSymbol(_Symbol)) return;

   // 1 trade max par symbole
   if(InpOnlyOnePosSym && HasOpenPositionForSymbol()) return;

   // Ne recalculer qu'une fois par nouvelle bougie M1
   datetime t = iTime(_Symbol,InpTF,0);
   if(t==g_lastBarTime) return;
   g_lastBarTime = t;

   double spikeStrength;
   int spikeDir;
   if(!DetectSpike(spikeStrength,spikeDir)) return;

   // Filtre de force minimale
   if(spikeStrength < 20.0) return;

   ExecuteSpikeTrade(spikeDir);
}

// Pour compatibilité, ne rien faire sur OnTick (tout est dans OnTimer)
void OnTick() { }

