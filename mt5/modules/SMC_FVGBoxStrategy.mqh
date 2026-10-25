//+------------------------------------------------------------------+
//| SMC_FVGBoxStrategy.mqh — FVG ICT (boîtes colorées) + entrée EA   |
//| Graphique : rectangles remplis (bleu fort / cyan / vert / pêche) |
//| Stratégie : retest FVG non mitigé, ou IFVG après cassure,        |
//| filtrée par GOM GOOD/PERFECT + entry_allowed.                    |
//+------------------------------------------------------------------+
#ifndef SMC_FVG_BOX_STRATEGY_MQH
#define SMC_FVG_BOX_STRATEGY_MQH

#ifndef FVGBOX_MAX
#define FVGBOX_MAX 20
#endif

struct SMC_FVGBox
{
   double   top;
   double   bot;
   double   mid;
   datetime tOrigin;
   datetime tEdge;
   int      dir;       // +1 bull, -1 bear
   int      kind;      // 0 = FVG, 1 = IFVG (inversé après mitigation)
   bool     mitigated;
   color    clr;
   string   name;
};

SMC_FVGBox g_fvgBoxes[FVGBOX_MAX];
int        g_fvgBoxCount = 0;
datetime   g_fvgBoxLastDraw = 0;
datetime   g_fvgBoxLastEntry = 0;
int        g_fvgBoxAtrHandle = INVALID_HANDLE;

color FVGBox_Color(const int dir, const double gap, const double atr, const bool ifvg)
{
   if(ifvg)
      return (dir > 0) ? C'40,180,80' : C'200,90,70';
   if(dir < 0)
      return C'232,160,144';
   if(atr > 0.0 && gap >= atr * 1.20)
      return C'30,90,200';
   if(atr > 0.0 && gap >= atr * 0.55)
      return C'0,170,210';
   return C'46,176,80';
}

void FVGBox_ClearDraw()
{
   ObjectsDeleteAll(0, "SMC_FVGBOX_");
}

void FVGBox_Reset()
{
   g_fvgBoxCount = 0;
   for(int i = 0; i < FVGBOX_MAX; i++)
      ZeroMemory(g_fvgBoxes[i]);
}

bool FVGBox_Add(const double top, const double bot, const datetime t0,
                const datetime tEdge, const int dir, const bool mitigated,
                const bool ifvg, const double atr)
{
   if(g_fvgBoxCount >= FVGBOX_MAX) return false;
   if(top <= bot) return false;
   SMC_FVGBox b;
   ZeroMemory(b);
   b.top = top;
   b.bot = bot;
   b.mid = (top + bot) * 0.5;
   b.tOrigin = t0;
   b.tEdge = tEdge;
   b.dir = dir;
   b.kind = ifvg ? 1 : 0;
   b.mitigated = mitigated;
   b.clr = FVGBox_Color(dir, top - bot, atr, ifvg);
   b.name = "SMC_FVGBOX_" + (ifvg ? "IFVG_" : "FVG_") +
            (dir > 0 ? "B_" : "S_") + IntegerToString(g_fvgBoxCount);
   g_fvgBoxes[g_fvgBoxCount++] = b;
   return true;
}

void FVGBox_ScanTF(const string symbol, const ENUM_TIMEFRAMES tf, const int lookback, const double atr)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = lookback;
   if(n < 12) n = 12;
   if(CopyRates(symbol, tf, 0, n, r) < n) return;
   datetime nowT = TimeCurrent();
   datetime futureT = nowT + PeriodSeconds(tf);

   for(int i = 2; i < n - 2 && g_fvgBoxCount < FVGBOX_MAX; i++)
   {
      bool isBull = (r[i - 1].low > r[i + 1].high);
      bool isBear = (r[i - 1].high < r[i + 1].low);
      if(!isBull && !isBear) continue;

      double top = isBull ? r[i - 1].low : r[i + 1].low;
      double bot = isBull ? r[i + 1].high : r[i - 1].high;
      if(top <= bot) continue;
      double gap = top - bot;
      double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(pt <= 0.0) pt = 0.00001;
      if(gap < pt * 3.0) continue;
      if(atr > 0.0 && gap < atr * 0.12) continue;

      bool mitigated = false;
      bool closedThrough = false;
      datetime tMit = nowT;
      int dir = isBull ? 1 : -1;
      for(int j = i - 2; j >= 0; j--)
      {
         if(isBull && r[j].low <= bot)
         {
            mitigated = true;
            tMit = r[j].time;
            if(r[j].close < bot) closedThrough = true;
            break;
         }
         if(isBear && r[j].high >= top)
         {
            mitigated = true;
            tMit = r[j].time;
            if(r[j].close > top) closedThrough = true;
            break;
         }
      }

      datetime t0 = r[i + 1].time;
      datetime tEdge = mitigated ? tMit : futureT;
      FVGBox_Add(top, bot, t0, tEdge, dir, mitigated, false, atr);

      if(mitigated && closedThrough && g_fvgBoxCount < FVGBOX_MAX)
      {
         int idir = -dir;
         FVGBox_Add(top, bot, tMit, futureT, idir, false, true, atr);
      }
   }
}

void FVGBox_DrawOne(const SMC_FVGBox &b)
{
   if(!ObjectCreate(0, b.name, OBJ_RECTANGLE, 0, b.tOrigin, b.bot, b.tEdge, b.top))
      return;
   ObjectSetInteger(0, b.name, OBJPROP_COLOR, b.clr);
   ObjectSetInteger(0, b.name, OBJPROP_STYLE, b.mitigated ? STYLE_DOT : STYLE_SOLID);
   ObjectSetInteger(0, b.name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, b.name, OBJPROP_BACK, true);
   ObjectSetInteger(0, b.name, OBJPROP_FILL, !b.mitigated);
   ObjectSetInteger(0, b.name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, b.name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, b.name, OBJPROP_TOOLTIP,
                   (b.kind == 1 ? "IFVG " : "FVG ") + (b.dir > 0 ? "BUY" : "SELL"));

   string ce = b.name + "_CE";
   if(ObjectCreate(0, ce, OBJ_TREND, 0, b.tOrigin, b.mid, b.tEdge, b.mid))
   {
      ObjectSetInteger(0, ce, OBJPROP_COLOR, b.clr);
      ObjectSetInteger(0, ce, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, ce, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, ce, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, ce, OBJPROP_BACK, true);
      ObjectSetInteger(0, ce, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ce, OBJPROP_HIDDEN, true);
   }
}

void FVGBox_Rebuild(const string symbol)
{
   FVGBox_ClearDraw();
   FVGBox_Reset();

   double atr = 0.0;
   if(g_fvgBoxAtrHandle == INVALID_HANDLE)
      g_fvgBoxAtrHandle = iATR(symbol, PERIOD_M5, 14);
   double a[];
   ArraySetAsSeries(a, true);
   if(g_fvgBoxAtrHandle != INVALID_HANDLE && CopyBuffer(g_fvgBoxAtrHandle, 0, 0, 3, a) >= 1)
      atr = a[0];

   bool synth = (StringFind(symbol, "Pain") >= 0 || StringFind(symbol, "Gain") >= 0 ||
                 StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0 ||
                 StringFind(symbol, "Vol") >= 0);
   FVGBox_ScanTF(symbol, synth ? PERIOD_M1 : PERIOD_M15, synth ? 120 : 80, atr);
   if(synth)
      FVGBox_ScanTF(symbol, PERIOD_M5, 80, atr);

   for(int i = 0; i < g_fvgBoxCount; i++)
      FVGBox_DrawOne(g_fvgBoxes[i]);
   g_fvgBoxLastDraw = TimeCurrent();
}

bool FVGBox_PriceInBox(const SMC_FVGBox &b, const double px)
{
   return (px >= b.bot && px <= b.top);
}

bool FVGBox_TryEntry(const string symbol)
{
   if(!UseFVGBoxStrategy) return false;
   SMCGP_RestoreCachedIfDisconnected();
   if(!SMCGP_GomLinkOK()) return false;
   if(!SMCGP_IsGoodPerfect(g_smcGomVerdictNum)) return false;
   if(!g_smcGomEntryAllowed) return false;
   if(CountPositionsForSymbol(symbol) > 0) return false;
   if(IsTerminalFull()) return false;
   if(TimeCurrent() - g_fvgBoxLastEntry < 30) return false;

   int want = (g_smcGomVerdictNum > 0) ? 1 : -1;
   if(!SMC_EntryVerdictOK(symbol, want)) return false;
   if(IsBoomLikeSymbol(symbol) && want < 0) return false;
   if(IsCrashLikeSymbol(symbol) && want > 0) return false;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double px = (want > 0) ? ask : bid;
   if(px <= 0.0) return false;

   int best = -1;
   double bestGap = 1e100;
   for(int i = 0; i < g_fvgBoxCount; i++)
   {
      if(g_fvgBoxes[i].mitigated) continue;
      if(g_fvgBoxes[i].dir != want) continue;
      if(!FVGBox_PriceInBox(g_fvgBoxes[i], px)) continue;
      double g = g_fvgBoxes[i].top - g_fvgBoxes[i].bot;
      if(g < bestGap)
      {
         bestGap = g;
         best = i;
      }
   }
   if(best < 0) return false;

   if(!CanPlaceMarketOrder(symbol, want)) return false;
   string dir = (want > 0) ? "BUY" : "SELL";
   if(!CanTradeOnSymbol(symbol, dir)) return false;
   if(!SMC_FinalOpenGate(symbol, want > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL)) return false;

   double lot = CalculateLotSize();
   if(lot <= 0.0) return false;
   int dg = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   double sl = (want > 0)
               ? NormalizeDouble(g_fvgBoxes[best].bot, dg)
               : NormalizeDouble(g_fvgBoxes[best].top, dg);
   double risk = MathAbs(px - sl);
   if(risk <= 0.0) return false;
   double tp = (want > 0)
               ? NormalizeDouble(px + risk * 2.0, dg)
               : NormalizeDouble(px - risk * 2.0, dg);

   if(!TryAcquireOpenLock()) return false;
   bool ok = false;
   string cmt = (g_fvgBoxes[best].kind == 1) ? "FVG_IFVG " : "FVG_BOX ";
   cmt += dir;
   if(want > 0)
      ok = SafeTradeBuy(lot, symbol, ask, sl, tp, cmt);
   else
      ok = SafeTradeSell(lot, symbol, bid, sl, tp, cmt);
   if(ok) SMC_GateRegisterOpened(symbol, want > 0);
   ReleaseOpenLock();

   if(ok)
   {
      g_fvgBoxLastEntry = TimeCurrent();
      RegisterOrderPlaced();
      Print("🟩 FVG BOX ", cmt, " | zone ", DoubleToString(g_fvgBoxes[best].bot, dg),
            "-", DoubleToString(g_fvgBoxes[best].top, dg),
            " | vn=", g_smcGomVerdictNum, " | ", symbol);
   }
   return ok;
}

void SMC_FVGBox_OnTick(const string symbol)
{
   if(!UseFVGBoxStrategy) return;
   if(TimeCurrent() - g_fvgBoxLastDraw >= 2)
      FVGBox_Rebuild(symbol);
   FVGBox_TryEntry(symbol);
}

void SMC_FVGBox_Deinit()
{
   FVGBox_ClearDraw();
   FVGBox_Reset();
   if(g_fvgBoxAtrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_fvgBoxAtrHandle);
      g_fvgBoxAtrHandle = INVALID_HANDLE;
   }
}

#endif
