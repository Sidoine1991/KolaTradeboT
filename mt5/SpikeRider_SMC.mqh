//+------------------------------------------------------------------+
//| SpikeRider_SMC.mqh — Structure SMC pour capture spike Boom/Crash |
//| BOS, CHOCH, Fibonacci 50/61.8/78.6, zone OTE                     |
//+------------------------------------------------------------------+
#property strict

#ifndef SPIKE_RIDER_SMC_MQH
#define SPIKE_RIDER_SMC_MQH

struct SR_SMCSetup
{
   bool     valid;
   bool     bos;
   bool     choch;
   bool     inOTE;
   bool     inDiscount;
   bool     impulseUp;
   double   swingHigh;
   double   swingLow;
   double   oteLow;
   double   oteHigh;
   double   fib50;
   double   fib618;
   double   fib786;
   double   breakLevel;
   string   tag;
};

//+------------------------------------------------------------------+
bool SR_IsSwingHigh(const MqlRates &r[], const int i)
{
   return (r[i].high >= r[i-1].high && r[i].high >= r[i+1].high &&
           r[i].high >= r[i-2].high && r[i].high >= r[i+2].high);
}

bool SR_IsSwingLow(const MqlRates &r[], const int i)
{
   return (r[i].low <= r[i-1].low && r[i].low <= r[i+1].low &&
           r[i].low <= r[i-2].low && r[i].low <= r[i+2].low);
}

//+------------------------------------------------------------------+
bool SR_FindSwingPoints(const string sym, const ENUM_TIMEFRAMES tf, const int lookback,
                        double &swHi, double &swLo, int &idxHi, int &idxLo)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int need = lookback + 5;
   if(CopyRates(sym, tf, 1, need, r) < need) return false;

   swHi = -1e18;
   swLo =  1e18;
   idxHi = -1;
   idxLo = -1;
   for(int i = 2; i < lookback - 2; i++)
   {
      if(SR_IsSwingHigh(r, i) && r[i].high > swHi)
      {
         swHi  = r[i].high;
         idxHi = i;
      }
      if(SR_IsSwingLow(r, i) && r[i].low < swLo)
      {
         swLo  = r[i].low;
         idxLo = i;
      }
   }
   return (swHi > swLo && idxHi >= 0 && idxLo >= 0);
}

//+------------------------------------------------------------------+
void SR_CalcFiboOTE(const bool impulseUp, const double swHi, const double swLo,
                    double &oteLo, double &oteHi, double &f50, double &f618, double &f786)
{
   double range = swHi - swLo;
   f50 = f618 = f786 = oteLo = oteHi = 0.0;
   if(range <= 0.0) return;

   if(impulseUp)
   {
      f618  = swHi - range * 0.618;
      f786  = swHi - range * 0.786;
      oteLo = f786;
      oteHi = f618;
      f50   = swLo + range * 0.5;
   }
   else
   {
      f618  = swLo + range * 0.618;
      f786  = swLo + range * 0.786;
      oteLo = f618;
      oteHi = f786;
      f50   = swHi - range * 0.5;
   }
}

//+------------------------------------------------------------------+
bool SR_DetectBOS(const string sym, const ENUM_TIMEFRAMES tf, const bool wantBuy,
                  double &breakLevel, const double swHi, const double swLo)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(sym, tf, 1, 3, r) < 2) return false;

   const double pt    = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double minBr = pt * MathMax(3.0, (double)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL) + 1.0);

   if(wantBuy)
   {
      breakLevel = swHi;
      return (r[0].close > swHi + minBr);
   }
   breakLevel = swLo;
   return (r[0].close < swLo - minBr);
}

//+------------------------------------------------------------------+
// CHOCH haussier : LH puis clôture au-dessus du LH | baissier : HL puis sous HL
bool SR_DetectCHOCH(const string sym, const ENUM_TIMEFRAMES tf, const bool wantBuy)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(sym, tf, 1, 55, r) < 55) return false;

   const double pt    = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double minBr = pt * MathMax(3.0, (double)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL) + 1.0);

   if(wantBuy)
   {
      double sh1 = -1e18, sh2 = -1e18;
      int found = 0;
      for(int i = 3; i < 48 && found < 2; i++)
      {
         if(!SR_IsSwingHigh(r, i)) continue;
         if(found == 0) { sh1 = r[i].high; found = 1; }
         else          { sh2 = r[i].high; found = 2; }
      }
      if(found < 2 || sh1 <= 0.0) return false;
      double lh = MathMin(sh1, sh2);
      return (r[0].close > lh + minBr);
   }

   double sl1 = 1e18, sl2 = 1e18;
   int foundL = 0;
   for(int i = 3; i < 48 && foundL < 2; i++)
   {
      if(!SR_IsSwingLow(r, i)) continue;
      if(foundL == 0) { sl1 = r[i].low; foundL = 1; }
      else            { sl2 = r[i].low; foundL = 2; }
   }
   if(foundL < 2 || sl1 >= 1e17) return false;
   double hl = MathMax(sl1, sl2);
   return (r[0].close < hl - minBr);
}

//+------------------------------------------------------------------+
bool SR_BuildSMCSetup(const string sym, const ENUM_TIMEFRAMES tf, const bool isBoom,
                      const double price, const int swingLb, SR_SMCSetup &out)
{
   out.valid = false;
   out.bos = out.choch = out.inOTE = out.inDiscount = false;
   out.tag = "—";
   out.breakLevel = 0.0;

   double sh, sl;
   int ih, il;
   if(!SR_FindSwingPoints(sym, tf, swingLb, sh, sl, ih, il))
      return false;

   out.swingHigh  = sh;
   out.swingLow   = sl;
   out.impulseUp  = (il < ih);
   SR_CalcFiboOTE(out.impulseUp, sh, sl, out.oteLow, out.oteHigh,
                  out.fib50, out.fib618, out.fib786);

   const bool wantBuy = isBoom;
   out.bos   = SR_DetectBOS(sym, tf, wantBuy, out.breakLevel, sh, sl);
   out.choch = SR_DetectCHOCH(sym, tf, wantBuy);

   if(wantBuy)
   {
      out.inOTE      = (price >= out.oteLow && price <= out.oteHigh);
      out.inDiscount = (price <= out.fib50);
   }
   else
   {
      out.inOTE      = (price >= out.oteLow && price <= out.oteHigh);
      out.inDiscount = (price >= out.fib50);
   }

   out.valid = true;
   out.tag   = StringFormat("BOS%s CHOCH%s OTE%s",
                            (out.bos ? "+" : "-"),
                            (out.choch ? "+" : "-"),
                            (out.inOTE ? "+" : "-"));
   return true;
}

//+------------------------------------------------------------------+
bool SR_SMCAllowsEntry(const SR_SMCSetup &smc, const bool isBoom,
                       const bool requireBOS, const bool requireCHOCH,
                       const bool requireOTE, const bool spikeConfirmed,
                       const double zScore, const double zMin,
                       string &reason)
{
   reason = "";
   if(!smc.valid) { reason = "structure SMC indisponible"; return false; }

   const bool wantBuy = isBoom;
   if(requireBOS && !smc.bos)
   {
      reason = "BOS absent";
      return false;
   }
   if(requireCHOCH && !smc.choch)
   {
      reason = "CHOCH absent";
      return false;
   }
   if(!requireBOS && !requireCHOCH && !smc.bos && !smc.choch)
   {
      reason = "ni BOS ni CHOCH";
      return false;
   }
   if(requireBOS && requireCHOCH && (!smc.bos || !smc.choch))
   {
      reason = "BOS+CHOCH requis";
      return false;
   }

   if(requireOTE && !smc.inOTE)
   {
      if(!spikeConfirmed || zScore < zMin + 0.75)
      {
         reason = "hors zone OTE 61.8–78.6";
         return false;
      }
   }

   if(wantBuy && !smc.impulseUp && !smc.bos)
   {
      reason = "impulsion non haussière";
      return false;
   }
   if(!wantBuy && smc.impulseUp && !smc.bos)
   {
      reason = "impulsion non baissière";
      return false;
   }

   reason = smc.tag;
   return true;
}

#endif // SPIKE_RIDER_SMC_MQH
