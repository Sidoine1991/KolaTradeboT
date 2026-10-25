//+------------------------------------------------------------------+
//| SMC_LiveGOMEntry.mqh — qualité d'entrée LIVE vs verdict GOM      |
//| FIX 2026-09-22 : GOM GOOD/PERFECT peut rester figé (poll/EMA)    |
//| alors que le M1 a déjà viré. Ce gate lit les bougies MT5 locales |
//| et bloque les MARKET en retard ou contre le flux.                |
//+------------------------------------------------------------------+
#ifndef SMC_LIVE_GOM_ENTRY_MQH
#define SMC_LIVE_GOM_ENTRY_MQH

#ifndef LIVE_GOM_CHASE_SNIPER
#define LIVE_GOM_CHASE_SNIPER 1.00
#endif
#ifndef LIVE_GOM_IMPULSE_BARS
#define LIVE_GOM_IMPULSE_BARS 3
#endif

struct LiveGOMLossSlot
{
   string   symbol;
   int      losses;
   datetime firstLoss;
   datetime pauseUntil;
};

LiveGOMLossSlot g_liveGomLoss[24];
int             g_liveGomLossCount = 0;

int SMC_LiveGomLossIndex(const string symbol)
{
   for(int i = 0; i < g_liveGomLossCount; i++)
      if(g_liveGomLoss[i].symbol == symbol)
         return i;
   if(g_liveGomLossCount >= 24)
      return 0;
   int n = g_liveGomLossCount++;
   g_liveGomLoss[n].symbol = symbol;
   g_liveGomLoss[n].losses = 0;
   g_liveGomLoss[n].firstLoss = 0;
   g_liveGomLoss[n].pauseUntil = 0;
   return n;
}

double SMC_LiveEntryATR(const string symbol)
{
   double atr = 0.0;
   int h = iATR(symbol, PERIOD_M1, 14);
   if(h != INVALID_HANDLE)
   {
      double b[];
      ArraySetAsSeries(b, true);
      if(CopyBuffer(h, 0, 0, 1, b) >= 1)
         atr = b[0];
      IndicatorRelease(h);
   }
   if(atr <= 0.0)
      atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 50.0;
   return atr;
}

void SMC_LiveGOMEntry_RegisterClose(const string symbol, const double profit)
{
   if(!UseLiveGOMEntryGate) return;
   int idx = SMC_LiveGomLossIndex(symbol);
   datetime now = TimeCurrent();
   if(profit >= 0.0)
   {
      g_liveGomLoss[idx].losses = 0;
      g_liveGomLoss[idx].firstLoss = 0;
      g_liveGomLoss[idx].pauseUntil = 0;
      return;
   }
   if(g_liveGomLoss[idx].firstLoss == 0 ||
      (now - g_liveGomLoss[idx].firstLoss) > LiveLossWindowMin * 60)
   {
      g_liveGomLoss[idx].losses = 1;
      g_liveGomLoss[idx].firstLoss = now;
   }
   else
      g_liveGomLoss[idx].losses++;

   if(g_liveGomLoss[idx].losses >= LiveLossPauseCount)
   {
      g_liveGomLoss[idx].pauseUntil = now + LiveLossPauseMin * 60;
      Print("🛑 LIVE-GOM — pause ", LiveLossPauseMin, " min sur ", symbol,
            " après ", g_liveGomLoss[idx].losses, " pertes rapides");
      g_liveGomLoss[idx].losses = 0;
      g_liveGomLoss[idx].firstLoss = 0;
   }
}

bool SMC_LiveClosedBarConfirms(const MqlRates &bar, const int dirSign, const double minBody = 0.38)
{
   double range = bar.high - bar.low;
   if(range <= 0.0) return false;
   double body = MathAbs(bar.close - bar.open);
   if(body < range * minBody) return false;
   if(dirSign > 0)
      return (bar.close > bar.open && bar.close >= bar.low + range * 0.55);
   return (bar.close < bar.open && bar.close <= bar.high - range * 0.55);
}

bool SMC_LiveIsVolFamily(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   return (StringFind(s, "VOL") >= 0 || StringFind(s, "SFX") >= 0);
}

bool SMC_LiveIs1200(const string symbol)
{
   return (StringFind(symbol, "1200") >= 0);
}

bool SMC_LiveIsSniper(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   if(StringFind(s, "999") >= 0) return true;
   return ((StringFind(s, "PAINX") >= 0 || StringFind(s, "GAINX") >= 0) &&
           StringFind(s, "400") >= 0);
}

double SMC_LiveChaseFor(const string symbol)
{
   if(SMC_LiveIsSniper(symbol))
      return LIVE_GOM_CHASE_SNIPER;
   return LiveChaseATR;
}

int SMC_LiveImpulseBars(const MqlRates &m1[], const int dirSign, const int n)
{
   int bars = 0;
   int lim = MathMin(n, ArraySize(m1));
   for(int i = 1; i < lim; i++)
   {
      bool withDir = (dirSign > 0 && m1[i].close > m1[i].open) ||
                     (dirSign < 0 && m1[i].close < m1[i].open);
      if(!withDir) break;
      bars++;
   }
   return bars;
}

bool SMC_LiveNearPullback(const string symbol, const int dirSign, const double atr)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || atr <= 0.0) return false;
   double px = (bid + ask) * 0.5;
   double maxDist = atr * LivePullbackMaxATR;

   double lvl = 0.0;
   if(SMC_FindReactionObjectLevel(symbol, "GOM_TF_TL_M1", lvl) && lvl > 0.0 && MathAbs(px - lvl) <= maxDist)
      return true;
   if(SMC_FindReactionObjectLevel(symbol, "GOM_TF_TL_M5", lvl) && lvl > 0.0 && MathAbs(px - lvl) <= maxDist)
      return true;
   double dow = 0.0;
   bool bear = false;
   if(SMC_FindDOWProjectedLevel(dow, bear) && dow > 0.0 && MathAbs(px - dow) <= maxDist)
      return true;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 12, r) < 10) return false;
   if(dirSign > 0)
   {
      double swing = r[2].low;
      for(int i = 3; i < 10; i++)
         if(r[i].low < swing) swing = r[i].low;
      return (MathAbs(px - swing) <= maxDist);
   }
   double swingH = r[2].high;
   for(int i = 3; i < 10; i++)
      if(r[i].high > swingH) swingH = r[i].high;
   return (MathAbs(px - swingH) <= maxDist);
}

bool SMC_LiveGOMEntryOK(const string symbol, const int dirSign, const bool isPending, string &reasonOut)
{
   reasonOut = "";
   if(!UseLiveGOMEntryGate) return true;
   if(dirSign == 0)
   {
      reasonOut = "dir=0";
      return false;
   }
   if(IsCrashLikeSymbol(symbol) && dirSign > 0)
   {
      reasonOut = "PainX/Crash — BUY interdit (natif SELL)";
      return false;
   }
   if(IsBoomLikeSymbol(symbol) && dirSign < 0)
   {
      reasonOut = "GainX/Boom — SELL interdit (natif BUY)";
      return false;
   }

   int idx = SMC_LiveGomLossIndex(symbol);
   if(g_liveGomLoss[idx].pauseUntil > 0 && TimeCurrent() < g_liveGomLoss[idx].pauseUntil)
   {
      reasonOut = StringFormat("pause pertes jusqu'a %s", TimeToString(g_liveGomLoss[idx].pauseUntil, TIME_MINUTES));
      return false;
   }

   double atr = SMC_LiveEntryATR(symbol);
   MqlRates m1[];
   ArraySetAsSeries(m1, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 6, m1) < 5)
   {
      reasonOut = "M1 rates insuffisants";
      return false;
   }

   double d1 = m1[1].close - m1[2].close;
   double d3 = m1[1].close - m1[4].close;
   double forming = m1[0].close - m1[0].open;
   double against = atr * LiveAgainstATR;

   bool flowAgainst = (dirSign > 0 && d1 < -against && d3 < -against) ||
                      (dirSign < 0 && d1 >  against && d3 >  against);
   bool formingAgainst = (dirSign > 0 && forming < -atr * LiveAgainstATR * 1.6) ||
                         (dirSign < 0 && forming >  atr * LiveAgainstATR * 1.6);

   if(flowAgainst)
   {
      reasonOut = StringFormat("M1 1b+3b contre GOM (d1=%.5f d3=%.5f atr=%.5f) — verdict probablement figé",
                               d1, d3, atr);
      return false;
   }
   if(IsCrashLikeSymbol(symbol) && dirSign < 0)
   {
      int greens = 0;
      for(int gi = 1; gi <= 3; gi++)
         if(m1[gi].close > m1[gi].open) greens++;
      if(greens >= 2 || d3 > 0.0)
      {
         reasonOut = "PainX SELL interdit — M1 haussier (3 Soldiers / rally)";
         return false;
      }
   }
   if(IsBoomLikeSymbol(symbol) && dirSign > 0)
   {
      int reds = 0;
      for(int ri = 1; ri <= 3; ri++)
         if(m1[ri].close < m1[ri].open) reds++;
      if(reds >= 2 && d3 < 0.0)
      {
         reasonOut = "GainX BUY interdit — M1 dump en cours";
         return false;
      }
   }
   if(!isPending && formingAgainst)
   {
      reasonOut = "bougie M1 en cours déjà contre le verdict";
      return false;
   }

   if(g_smcLastGOMPoll > 0 && (TimeCurrent() - g_smcLastGOMPoll) > LiveGOMMaxAgeSec)
   {
      bool oneBarAgainst = (dirSign > 0 && d1 < 0) || (dirSign < 0 && d1 > 0);
      if(oneBarAgainst)
      {
         reasonOut = StringFormat("GOM stale %ds + M1 déjà contraire",
                                  (int)(TimeCurrent() - g_smcLastGOMPoll));
         return false;
      }
   }

   if(isPending)
      return true;

   if(!g_smcGomConnected || g_smcGomVerdictNum == 0 || g_smcGomVerdictNum == -999)
   {
      reasonOut = "GOM WAIT";
      return false;
   }

   if(g_dowPriceLeadInFlight && !SMC_LiveIsVolFamily(symbol))
      return true;

   double bodyMin = SMC_LiveIsVolFamily(symbol) ? 0.22 : 0.38;
   bool needM5 = LiveRequireM5Closed;
   if(SMC_LiveIs1200(symbol) && SMC_LiveClosedBarConfirms(m1[1], dirSign, bodyMin))
      needM5 = false;
   if(SMC_LiveIsVolFamily(symbol))
      needM5 = true;

   if(needM5)
   {
      MqlRates m5[];
      ArraySetAsSeries(m5, true);
      if(CopyRates(symbol, PERIOD_M5, 0, 3, m5) < 2)
      {
         reasonOut = "M5 rates insuffisants";
         return false;
      }
      if(!SMC_LiveClosedBarConfirms(m5[1], dirSign, MathMin(bodyMin, 0.28)))
      {
         reasonOut = "M5 clôturée non confirmée dans le sens GOM";
         return false;
      }
   }

   if(!SMC_LiveClosedBarConfirms(m1[1], dirSign, bodyMin))
   {
      reasonOut = "M1 clôturée trop faible / doji — pas de confirmation";
      return false;
   }

   double impulse = MathAbs(d3);
   double chase = SMC_LiveChaseFor(symbol);
   int impulseBars = SMC_LiveImpulseBars(m1, dirSign, 6);
   bool lateChase = (impulse >= atr * chase && impulseBars > LIVE_GOM_IMPULSE_BARS);
   if(lateChase && !SMC_LiveNearPullback(symbol, dirSign, atr))
   {
      reasonOut = StringFormat("MARKET en retard (impulse %.2fxATR, %d bars hors pullback)",
                               (atr > 0.0 ? impulse / atr : 0.0), impulseBars);
      return false;
   }

   return true;
}

double SMC_DowLiveLevel()
{
   double lvl = 0.0;
   bool bear = false;
   if(SMC_FindDOWProjectedLevel(lvl, bear) && lvl > 0.0)
      return lvl;
   return 0.0;
}

bool SMC_DowAlreadyChased(const string symbol, const int dirSign, const double atr)
{
   double lvl = SMC_DowLiveLevel();
   if(lvl <= 0.0 || atr <= 0.0) return true;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(bid <= 0.0) return true;
   if(MathAbs(bid - lvl) > atr * 0.85)
      return true;

   MqlRates m1[];
   ArraySetAsSeries(m1, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 5, m1) < 4)
      return false;
   int bigDir = 0;
   for(int i = 1; i <= 3; i++)
   {
      double rng = m1[i].high - m1[i].low;
      bool withDir = (dirSign < 0 && m1[i].close < m1[i].open) ||
                     (dirSign > 0 && m1[i].close > m1[i].open);
      if(withDir && rng >= atr * 1.00)
         bigDir++;
   }
   return (bigDir >= 2 && MathAbs(bid - lvl) > atr * 0.40);
}

bool SMC_DowFirstBounceOK(const string symbol, const int dirSign, string &reasonOut)
{
   reasonOut = "";
   if(!SMC_IsSpikeStyleSymbol(symbol))
   {
      reasonOut = "pas un spike synthétique";
      return false;
   }
   double lvl = 0.0;
   bool dowBear = false;
   if(!SMC_FindDOWProjectedLevel(lvl, dowBear) || lvl <= 0.0)
   {
      reasonOut = "DOW inactive";
      return false;
   }
   if(dirSign > 0 && dowBear)
   {
      reasonOut = "DOW BEAR vs BUY";
      return false;
   }
   if(dirSign < 0 && !dowBear)
   {
      reasonOut = "DOW BULL vs SELL";
      return false;
   }
   if(IsCrashLikeSymbol(symbol) && dirSign > 0)
   {
      reasonOut = "PainX/Crash — BUY interdit";
      return false;
   }
   if(IsBoomLikeSymbol(symbol) && dirSign < 0)
   {
      reasonOut = "GainX/Boom — SELL interdit";
      return false;
   }

   double atr = SMC_LiveEntryATR(symbol);
   if(atr <= 0.0)
   {
      reasonOut = "ATR indisponible";
      return false;
   }
   if(SMC_DowAlreadyChased(symbol, dirSign, atr))
   {
      reasonOut = "trop tard — cascade déjà partie loin du DOW";
      return false;
   }

   MqlRates m1[];
   ArraySetAsSeries(m1, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 6, m1) < 4)
   {
      reasonOut = "M1 insuffisant";
      return false;
   }

   double touchTol = atr * 0.40;
   bool touched = false;
   int touchI = -1;
   for(int i = 0; i <= 3; i++)
   {
      bool t = (dirSign < 0) ? (m1[i].high + touchTol >= lvl)
                             : (m1[i].low  - touchTol <= lvl);
      if(t)
      {
         touched = true;
         touchI = i;
         break;
      }
   }
   if(!touched)
   {
      reasonOut = "pas de touch DOW sur 4 M1";
      return false;
   }

   int rejectBars = 0;
   for(int i = 0; i <= MathMin(touchI + 2, 3); i++)
   {
      double rng = m1[i].high - m1[i].low;
      bool dirClose = (dirSign < 0 && m1[i].close < m1[i].open) ||
                      (dirSign > 0 && m1[i].close > m1[i].open);
      bool awayFromLine = (dirSign < 0 && m1[i].close < lvl) ||
                          (dirSign > 0 && m1[i].close > lvl);
      bool wick = false;
      if(rng > 0.0)
      {
         if(dirSign < 0 && m1[i].high + touchTol >= lvl &&
            (m1[i].high - m1[i].close) / rng >= 0.40)
            wick = true;
         if(dirSign > 0 && m1[i].low - touchTol <= lvl &&
            (m1[i].close - m1[i].low) / rng >= 0.40)
            wick = true;
      }
      if((dirClose && awayFromLine) || wick)
         rejectBars++;
   }
   if(rejectBars < 1)
   {
      reasonOut = "touch DOW sans rejet M1";
      return false;
   }

   reasonOut = StringFormat("touch+rejet DOW (bars=%d i=%d)", rejectBars, touchI);
   return true;
}

#endif // SMC_LIVE_GOM_ENTRY_MQH
