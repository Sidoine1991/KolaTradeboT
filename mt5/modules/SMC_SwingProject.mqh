#ifndef SMC_SWING_PROJECT_MQH
#define SMC_SWING_PROJECT_MQH

// Fractales confirmées (bougies closes) → médiane d'amplitude / durée
// → zones SH/SL projetées sur les bougies futures (Chart Shift).
// Entrée précise = prix dans la zone du swing du côté GOM (pas au milieu de l'impulsion).

#define SMCSP_PFX        "SMCSP_"
#define SMCSP_MAX        24
#define SMCSP_LOOKBACK   180
#define SMCSP_WING       2

double   g_smcspLastSH = 0.0;
double   g_smcspLastSL = 0.0;
datetime g_smcspLastSHT = 0;
datetime g_smcspLastSLT = 0;
double   g_smcspProjSH = 0.0;
double   g_smcspProjSL = 0.0;
datetime g_smcspProjSHT = 0;
datetime g_smcspProjSLT = 0;
int      g_smcspLastKind = 0; // 1=SH, -1=SL

double SMCSP_Median(double &v[], const int n)
{
   if(n <= 0) return 0.0;
   double a[];
   ArrayResize(a, n);
   for(int i = 0; i < n; i++) a[i] = v[i];
   for(int i = 1; i < n; i++)
   {
      double key = a[i];
      int j = i - 1;
      while(j >= 0 && a[j] > key)
      {
         a[j + 1] = a[j];
         j--;
      }
      a[j + 1] = key;
   }
   if((n % 2) == 1) return a[n / 2];
   return 0.5 * (a[n / 2 - 1] + a[n / 2]);
}

bool SMCSP_IsHigh(const MqlRates &r[], const int i, const int n, const int wing)
{
   if(i < wing || i + wing >= n) return false;
   for(int k = 1; k <= wing; k++)
   {
      if(r[i].high <= r[i - k].high) return false;
      if(r[i].high <  r[i + k].high) return false;
   }
   return true;
}

bool SMCSP_IsLow(const MqlRates &r[], const int i, const int n, const int wing)
{
   if(i < wing || i + wing >= n) return false;
   for(int k = 1; k <= wing; k++)
   {
      if(r[i].low >= r[i - k].low) return false;
      if(r[i].low >  r[i + k].low) return false;
   }
   return true;
}

void SMCSP_Clear()
{
   ObjectsDeleteAll(0, SMCSP_PFX);
}

void SMCSP_Box(const string name, const datetime t1, const datetime t2,
               const double p1, const double p2, const color clr)
{
   ObjectDelete(0, name);
   if(t1 <= 0 || t2 <= 0 || p1 <= 0.0 || p2 <= 0.0) return;
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void SMCSP_Lbl(const string name, const datetime t, const double p,
               const string txt, const color clr)
{
   ObjectDelete(0, name);
   if(t <= 0 || p <= 0.0) return;
   ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void SMCSP_Rebuild(const string symbol)
{
   g_smcspLastSH = 0.0; g_smcspLastSL = 0.0;
   g_smcspProjSH = 0.0;  g_smcspProjSL = 0.0;
   g_smcspProjSHT = 0;   g_smcspProjSLT = 0;
   g_smcspLastKind = 0;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(symbol, PERIOD_CURRENT, 0, SMCSP_LOOKBACK, r);
   if(n < 30) return;

   datetime tH[], tL[];
   double   pH[], pL[];
   ArrayResize(tH, SMCSP_MAX); ArrayResize(pH, SMCSP_MAX);
   ArrayResize(tL, SMCSP_MAX); ArrayResize(pL, SMCSP_MAX);
   int nH = 0, nL = 0;

   // i=0 barre live — ignorée. i>=WING = confirmée à droite.
   for(int i = SMCSP_WING; i < n - SMCSP_WING && (nH < SMCSP_MAX || nL < SMCSP_MAX); i++)
   {
      if(nH < SMCSP_MAX && SMCSP_IsHigh(r, i, n, SMCSP_WING))
      {
         tH[nH] = r[i].time;
         pH[nH] = r[i].high;
         nH++;
      }
      if(nL < SMCSP_MAX && SMCSP_IsLow(r, i, n, SMCSP_WING))
      {
         tL[nL] = r[i].time;
         pL[nL] = r[i].low;
         nL++;
      }
   }
   if(nH < 2 || nL < 2) return;

   g_smcspLastSH = pH[0]; g_smcspLastSHT = tH[0];
   g_smcspLastSL = pL[0]; g_smcspLastSLT = tL[0];
   g_lastSwingHigh = g_smcspLastSH;
   g_lastSwingLow  = g_smcspLastSL;
   g_lastSwingHighTime = g_smcspLastSHT;
   g_lastSwingLowTime  = g_smcspLastSLT;
   g_smcspLastKind = (g_smcspLastSHT >= g_smcspLastSLT) ? 1 : -1;

   double upAmp[], dnAmp[], upBars[], dnBars[];
   int nu = 0, nd = 0;
   ArrayResize(upAmp, SMCSP_MAX); ArrayResize(dnAmp, SMCSP_MAX);
   ArrayResize(upBars, SMCSP_MAX); ArrayResize(dnBars, SMCSP_MAX);
   int ps0 = PeriodSeconds(PERIOD_CURRENT);
   if(ps0 <= 0) ps0 = 60;

   for(int i = 0; i < nH && nu < SMCSP_MAX; i++)
   {
      datetime bestT = 0;
      double   bestP = 0.0;
      for(int j = 0; j < nL; j++)
      {
         if(tL[j] < tH[i] && tL[j] >= bestT)
         {
            bestT = tL[j];
            bestP = pL[j];
         }
      }
      if(bestT > 0)
      {
         double amp = pH[i] - bestP;
         double bars = (double)(tH[i] - bestT) / (double)ps0;
         if(amp > 0.0 && bars >= 1.0 && bars < 80.0)
         {
            upAmp[nu] = amp;
            upBars[nu] = bars;
            nu++;
         }
      }
   }
   for(int i = 0; i < nL && nd < SMCSP_MAX; i++)
   {
      datetime bestT = 0;
      double   bestP = 0.0;
      for(int j = 0; j < nH; j++)
      {
         if(tH[j] < tL[i] && tH[j] >= bestT)
         {
            bestT = tH[j];
            bestP = pH[j];
         }
      }
      if(bestT > 0)
      {
         double amp = bestP - pL[i];
         double bars = (double)(tL[i] - bestT) / (double)ps0;
         if(amp > 0.0 && bars >= 1.0 && bars < 80.0)
         {
            dnAmp[nd] = amp;
            dnBars[nd] = bars;
            nd++;
         }
      }
   }

   double medUp = SMCSP_Median(upAmp, nu);
   double medDn = SMCSP_Median(dnAmp, nd);
   double medUpB = SMCSP_Median(upBars, nu);
   double medDnB = SMCSP_Median(dnBars, nd);
   if(medUp <= 0.0) medUp = MathAbs(g_smcspLastSH - g_smcspLastSL);
   if(medDn <= 0.0) medDn = medUp;
   if(medUpB < 3.0) medUpB = 8.0;
   if(medDnB < 3.0) medDnB = 8.0;

   int ps = PeriodSeconds(PERIOD_CURRENT);
   datetime t0 = r[0].time;
   if(t0 <= 0) t0 = TimeCurrent();

   if(g_smcspLastKind < 0)
   {
      g_smcspProjSH  = g_smcspLastSL + medUp;
      g_smcspProjSHT = g_smcspLastSLT + (datetime)(medUpB * ps);
      g_smcspProjSL  = g_smcspProjSH - medDn;
      g_smcspProjSLT = g_smcspProjSHT + (datetime)(medDnB * ps);
   }
   else
   {
      g_smcspProjSL  = g_smcspLastSH - medDn;
      g_smcspProjSLT = g_smcspLastSHT + (datetime)(medDnB * ps);
      g_smcspProjSH  = g_smcspProjSL + medUp;
      g_smcspProjSHT = g_smcspProjSLT + (datetime)(medUpB * ps);
   }
   if(g_smcspProjSHT < t0 + ps) g_smcspProjSHT = t0 + (datetime)(MathMax(3.0, medUpB) * ps);
   if(g_smcspProjSLT < t0 + ps) g_smcspProjSLT = t0 + (datetime)(MathMax(3.0, medDnB) * ps);

   if(!ShowSwingProjection) return;

   ChartSetInteger(0, CHART_SHIFT, true);
   if(ChartGetDouble(0, CHART_SHIFT_SIZE) < 12.0)
      ChartSetDouble(0, CHART_SHIFT_SIZE, 18.0);

   SMCSP_Clear();

   int dg = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double atr = 0.0;
   int hAtr = iATR(symbol, PERIOD_CURRENT, 14);
   if(hAtr != INVALID_HANDLE)
   {
      double b[];
      ArraySetAsSeries(b, true);
      if(CopyBuffer(hAtr, 0, 0, 1, b) >= 1) atr = b[0];
      IndicatorRelease(hAtr);
   }
   double band = (atr > 0.0) ? atr * 0.18 : (medUp * 0.08);
   if(band <= 0.0) band = MathMax(_Point * 20.0, MathAbs(g_smcspLastSH - g_smcspLastSL) * 0.04);

   int shown = 0;
   for(int i = 0; i < nH && shown < 6; i++)
   {
      string nm = SMCSP_PFX + "H" + IntegerToString(i);
      ObjectCreate(0, nm, OBJ_ARROW, 0, tH[i], pH[i]);
      ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, 226);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, clrTomato);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      shown++;
   }
   shown = 0;
   for(int i = 0; i < nL && shown < 6; i++)
   {
      string nm = SMCSP_PFX + "L" + IntegerToString(i);
      ObjectCreate(0, nm, OBJ_ARROW, 0, tL[i], pL[i]);
      ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, 225);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      shown++;
   }

   datetime tNow = t0;
   SMCSP_Box(SMCSP_PFX + "FSH", tNow, g_smcspProjSHT,
             g_smcspProjSH + band, g_smcspProjSH - band, clrTomato);
   SMCSP_Box(SMCSP_PFX + "FSL", tNow, g_smcspProjSLT,
             g_smcspProjSL + band, g_smcspProjSL - band, clrLime);

   ObjectDelete(0, SMCSP_PFX + "LSH");
   ObjectCreate(0, SMCSP_PFX + "LSH", OBJ_TREND, 0, g_smcspLastSHT, g_smcspLastSH, g_smcspProjSLT, g_smcspProjSL);
   ObjectSetInteger(0, SMCSP_PFX + "LSH", OBJPROP_COLOR, clrTomato);
   ObjectSetInteger(0, SMCSP_PFX + "LSH", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, SMCSP_PFX + "LSH", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, SMCSP_PFX + "LSH", OBJPROP_SELECTABLE, false);

   ObjectDelete(0, SMCSP_PFX + "LSL");
   ObjectCreate(0, SMCSP_PFX + "LSL", OBJ_TREND, 0, g_smcspLastSLT, g_smcspLastSL, g_smcspProjSHT, g_smcspProjSH);
   ObjectSetInteger(0, SMCSP_PFX + "LSL", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, SMCSP_PFX + "LSL", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, SMCSP_PFX + "LSL", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, SMCSP_PFX + "LSL", OBJPROP_SELECTABLE, false);

   int barsSH = (int)MathMax(1.0, (double)(g_smcspProjSHT - tNow) / (double)ps);
   int barsSL = (int)MathMax(1.0, (double)(g_smcspProjSLT - tNow) / (double)ps);
   SMCSP_Lbl(SMCSP_PFX + "TSH", g_smcspProjSHT, g_smcspProjSH + band,
             "SH proj +" + IntegerToString(barsSH) + "  " + DoubleToString(g_smcspProjSH, dg), clrTomato);
   SMCSP_Lbl(SMCSP_PFX + "TSL", g_smcspProjSLT, g_smcspProjSL - band,
             "SL proj +" + IntegerToString(barsSL) + "  " + DoubleToString(g_smcspProjSL, dg), clrLime);
}

void SMCSP_OnTick()
{
   static datetime s_bar = 0;
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t == s_bar) return;
   s_bar = t;
   SMCSP_Rebuild(_Symbol);
}

bool SMCSP_PrecisionOK(const string symbol, const int dirSign)
{
   if(!UseSwingPrecisionGate) return true;
   if(dirSign == 0) return false;
   if(g_dowPriceLeadInFlight || g_secondSpikeInFlight) return true;
   if(MathAbs(g_smcGomVerdictNum) >= 3) return true;
   if(SMC_IsSpikeStyleSymbol(symbol) || SMC_IsWeltradeBoomCrash(symbol))
      return true;

   if(g_smcspLastSH <= 0.0 || g_smcspLastSL <= 0.0)
      SMCSP_Rebuild(symbol);
   if(g_smcspLastSH <= 0.0 || g_smcspLastSL <= 0.0)
      return true;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0) return false;
   double px = (dirSign > 0) ? bid : ask;

   double atr = 0.0;
   int h = iATR(symbol, PERIOD_CURRENT, 14);
   if(h != INVALID_HANDLE)
   {
      double b[];
      ArraySetAsSeries(b, true);
      if(CopyBuffer(h, 0, 0, 1, b) >= 1) atr = b[0];
      IndicatorRelease(h);
   }
   double tol = (atr > 0.0) ? atr * SwingPrecisionATR : MathAbs(g_smcspLastSH - g_smcspLastSL) * 0.12;
   if(tol <= 0.0) return true;

   if(dirSign > 0)
   {
      bool nearLast = MathAbs(px - g_smcspLastSL) <= tol;
      bool nearProj = (g_smcspProjSL > 0.0 && MathAbs(px - g_smcspProjSL) <= tol);
      if(nearLast || nearProj) return true;
      Print("[SWING] BUY hors SL (last=", DoubleToString(g_smcspLastSL, _Digits),
            " proj=", DoubleToString(g_smcspProjSL, _Digits), ")");
      return false;
   }
   bool nearLastH = MathAbs(px - g_smcspLastSH) <= tol;
   bool nearProjH = (g_smcspProjSH > 0.0 && MathAbs(px - g_smcspProjSH) <= tol);
   if(nearLastH || nearProjH) return true;
   Print("[SWING] SELL hors SH (last=", DoubleToString(g_smcspLastSH, _Digits),
         " proj=", DoubleToString(g_smcspProjSH, _Digits), ")");
   return false;
}

#endif
