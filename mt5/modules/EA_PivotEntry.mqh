//+------------------------------------------------------------------+
//| EA_PivotEntry.mqh — Entrées basées Pivot Low/High + Bollinger    |
//| Entry: Pivot Low (BUY) / Pivot High (SELL)                       |
//| TP: Bollinger Mid Upper Band (BUY) / Bollinger Mid Lower (SELL)  |
//+------------------------------------------------------------------+
#ifndef EA_PIVOT_ENTRY_MQH
#define EA_PIVOT_ENTRY_MQH

// ── État Pivot + Bollinger ─────────────────────────────────────────
double   g_pivotLow         = 0.0;
double   g_pivotHigh        = 0.0;
double   g_bollingerUp      = 0.0;
double   g_bollingerMid     = 0.0;
double   g_bollingerDown    = 0.0;

// ── Calcul Pivot Points (High/Low sur 20 bougies) ───────────────────
void EAPE_CalculatePivots(const int lookback = 20)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, lookback + 1, rates) < lookback)
   {
      Print("[EAPE] ❌ CopyRates failed");
      return;
   }

   double high = rates[lookback].high;
   double low  = rates[lookback].low;

   for(int i = lookback - 1; i >= 0; i--)
   {
      if(rates[i].high > high) high = rates[i].high;
      if(rates[i].low < low)   low  = rates[i].low;
   }

   g_pivotLow  = low;
   g_pivotHigh = high;
}

// ── Récupérer les Bollinger Bands du JSON GOM ──────────────────────
void EAPE_GetBollingerFromGOM()
{
   // Les valeurs viennent du module GOM (déjà calculées)
   // g_smcBbUp, g_smcBbMid, g_smcBbDn (depuis SMC_GOM_Pipeline.mqh)
   g_bollingerUp   = g_smcBbUp;
   g_bollingerMid  = g_smcBbMid;
   g_bollingerDown = g_smcBbDn;
}

// ── Setup BUY: Entry à Pivot Low, TP à Bollinger Mid Upper ──────────
struct BUYSetup
{
   double entry;
   double tp;
   double sl;
   bool   valid;
};

BUYSetup EAPE_GetBUYSetup()
{
   BUYSetup setup;
   setup.valid = false;

   EAPE_CalculatePivots(20);
   EAPE_GetBollingerFromGOM();

   // Entrée au Pivot Low
   setup.entry = g_pivotLow;

   // TP au Bollinger Mid Upper
   if(g_bollingerUp > setup.entry)
   {
      setup.tp = g_bollingerUp;
      setup.sl = g_pivotLow * 0.999;  // SL à -0.1% du pivot (protection min)
      setup.valid = true;

      Print("[EAPE-BUY] Setup valide:");
      Print("   Entry: ", DoubleToString(setup.entry, _Digits), " (Pivot Low)");
      Print("   TP: ", DoubleToString(setup.tp, _Digits), " (BB Upper)");
      Print("   SL: ", DoubleToString(setup.sl, _Digits));
   }
   else
   {
      Print("[EAPE-BUY] ❌ TP invalide: BB Upper (", DoubleToString(g_bollingerUp, _Digits),
            ") ≤ Entry (", DoubleToString(setup.entry, _Digits), ")");
   }

   return setup;
}

// ── Setup SELL: Entry à Pivot High, TP à Bollinger Mid Lower ────────
struct SELLSetup
{
   double entry;
   double tp;
   double sl;
   bool   valid;
};

SELLSetup EAPE_GetSELLSetup()
{
   SELLSetup setup;
   setup.valid = false;

   EAPE_CalculatePivots(20);
   EAPE_GetBollingerFromGOM();

   // Entrée au Pivot High
   setup.entry = g_pivotHigh;

   // TP au Bollinger Mid Lower
   if(g_bollingerDown < setup.entry)
   {
      setup.tp = g_bollingerDown;
      setup.sl = g_pivotHigh * 1.001;  // SL à +0.1% du pivot (protection min)
      setup.valid = true;

      Print("[EAPE-SELL] Setup valide:");
      Print("   Entry: ", DoubleToString(setup.entry, _Digits), " (Pivot High)");
      Print("   TP: ", DoubleToString(setup.tp, _Digits), " (BB Lower)");
      Print("   SL: ", DoubleToString(setup.sl, _Digits));
   }
   else
   {
      Print("[EAPE-SELL] ❌ TP invalide: BB Lower (", DoubleToString(g_bollingerDown, _Digits),
            ") ≥ Entry (", DoubleToString(setup.entry, _Digits), ")");
   }

   return setup;
}

// ── Vérifier si le prix touche l'entry (tolérance: ATR * 0.3) ────────
bool EAPE_IsPriceTouchingEntry(const double entry, const double tolerance = 0.0)
{
   double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid  = (bid + ask) / 2.0;

   double tol = tolerance;
   if(tol <= 0)
   {
      int hAtr = iATR(_Symbol, PERIOD_M5, 14);
      if(hAtr != INVALID_HANDLE)
      {
         double atrBuf[];
         ArraySetAsSeries(atrBuf, true);
         if(CopyBuffer(hAtr, 0, 1, 1, atrBuf) >= 1)
            tol = atrBuf[0] * 0.3;
         IndicatorRelease(hAtr);
      }
      else
         tol = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50;  // 50 pips fallback
   }

   bool touching = (MathAbs(mid - entry) <= tol);
   if(touching)
      Print("[EAPE] ✅ Prix touche entry: mid=", DoubleToString(mid, _Digits),
            " entry=", DoubleToString(entry, _Digits), " tol=", DoubleToString(tol, _Digits));

   return touching;
}

#endif
