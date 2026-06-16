//+------------------------------------------------------------------+
//| SMC_PerformancePause.mqh — pause après série de gains + giveback  |
//+------------------------------------------------------------------+
#ifndef SMC_PERFORMANCE_PAUSE_MQH
#define SMC_PERFORMANCE_PAUSE_MQH

extern double g_dailyStartEquity;
extern double g_dailyMaxEquity;

int      g_consecutiveWins     = 0;
double   g_winStreakSessionUSD = 0.0;
datetime g_perfPauseUntil      = 0;
bool     g_profitGivebackLock  = false;
datetime g_givebackLockTime    = 0;   // Heure du déclenchement du lock giveback

string SMC_PerfPauseGV(const string suffix)
{
   return "SMC_PERF_" + IntegerToString((long)ChartID()) + "_" + suffix;
}

void SMC_LoadPerformancePauseState()
{
   if(GlobalVariableCheck(SMC_PerfPauseGV("PauseUntil")))
      g_perfPauseUntil = (datetime)GlobalVariableGet(SMC_PerfPauseGV("PauseUntil"));
   if(GlobalVariableCheck(SMC_PerfPauseGV("ConsecWins")))
      g_consecutiveWins = (int)GlobalVariableGet(SMC_PerfPauseGV("ConsecWins"));
   if(GlobalVariableCheck(SMC_PerfPauseGV("GivebackLock")))
      g_profitGivebackLock = (GlobalVariableGet(SMC_PerfPauseGV("GivebackLock")) > 0.5);
   if(GlobalVariableCheck(SMC_PerfPauseGV("GivebackLockTime")))
      g_givebackLockTime = (datetime)GlobalVariableGet(SMC_PerfPauseGV("GivebackLockTime"));
}

void SMC_SavePerformancePauseState()
{
   GlobalVariableSet(SMC_PerfPauseGV("PauseUntil"),       (double)g_perfPauseUntil);
   GlobalVariableSet(SMC_PerfPauseGV("ConsecWins"),        (double)g_consecutiveWins);
   GlobalVariableSet(SMC_PerfPauseGV("GivebackLock"),      g_profitGivebackLock ? 1.0 : 0.0);
   GlobalVariableSet(SMC_PerfPauseGV("GivebackLockTime"),  (double)g_givebackLockTime);
}

void SMC_ResetPerformancePauseDaily()
{
   g_profitGivebackLock = false;
   g_givebackLockTime   = 0;
   GlobalVariableSet(SMC_PerfPauseGV("GivebackLock"),     0.0);
   GlobalVariableSet(SMC_PerfPauseGV("GivebackLockTime"), 0.0);
}

bool SMC_WinStreakPauseActive()
{
   if(!UseWinStreakPause || g_perfPauseUntil <= 0)
      return false;

   if(TimeCurrent() >= g_perfPauseUntil)
   {
      g_perfPauseUntil = 0;
      SMC_SavePerformancePauseState();
      Print("[WIN-STREAK] Pause terminée — trading autorisé");
      return false;
   }
   return true;
}

void SMC_TriggerWinStreakPause()
{
   int pauseSec = MathMax(1, WinStreakPauseHours) * 3600;
   g_perfPauseUntil = TimeCurrent() + pauseSec;
   g_consecutiveWins = 0;
   g_winStreakSessionUSD = 0.0;
   SMC_SavePerformancePauseState();

   datetime resumeAt = g_perfPauseUntil;
   Print("[WIN-STREAK] 🏆 ", WinStreakThreshold,
         " gains consécutifs — PAUSE ", WinStreakPauseHours, "h jusqu'à ",
         TimeToString(resumeAt, TIME_DATE|TIME_MINUTES));

   if(UseNotifications)
   {
      Alert("Pause performance: ", WinStreakThreshold, " gains → stop ", WinStreakPauseHours, "h");
      SendNotification("Pause performance: serie de gains → stop " + IntegerToString(WinStreakPauseHours) + "h");
   }
}

void SMC_RecordTradeClosePerformance(const double profit)
{
   if(profit < 0)
   {
      g_consecutiveWins = 0;
      g_winStreakSessionUSD = 0.0;
      SMC_SavePerformancePauseState();
      return;
   }

   if(!UseWinStreakPause || profit <= 0)
      return;

   g_consecutiveWins++;
   g_winStreakSessionUSD += profit;
   SMC_SavePerformancePauseState();

   Print("[WIN-STREAK] Gain #", g_consecutiveWins, "/", WinStreakThreshold,
         " (+", DoubleToString(profit, 2), "$ | serie +", DoubleToString(g_winStreakSessionUSD, 2), "$)");

   if(g_consecutiveWins >= WinStreakThreshold)
      SMC_TriggerWinStreakPause();
}

bool SMC_CheckProfitGivebackLock()
{
   if(!UseProfitGivebackGuard || g_profitGivebackLock)
      return g_profitGivebackLock;

   if(g_dailyStartEquity <= 0.0)
      return false;

   double peakProfit = g_dailyMaxEquity - g_dailyStartEquity;
   double curProfit  = AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartEquity;

   if(peakProfit < ProfitGivebackMinPeakUSD || peakProfit <= 0.0)
      return false;

   double floorProfit = peakProfit * (1.0 - ProfitGivebackPct / 100.0);
   if(curProfit >= floorProfit)
      return false;

   g_profitGivebackLock = true;
   g_givebackLockTime   = TimeCurrent();
   SMC_SavePerformancePauseState();
   Print("[GIVEBACK-GUARD] 🔒 Pic jour +", DoubleToString(peakProfit, 2),
         "$ → actuel +", DoubleToString(curProfit, 2),
         "$ (seuil ", DoubleToString(floorProfit, 2), "$) — pause 2h, reprise à ",
         TimeToString(g_givebackLockTime + 7200, TIME_MINUTES));
   if(UseNotifications)
   {
      Alert("Giveback guard: pause 2h — profits proteges");
      SendNotification("Giveback guard: pause 2h — reprise " + TimeToString(g_givebackLockTime + 7200, TIME_MINUTES));
   }
   return true;
}

bool SMC_PerformancePauseAllowsEntry()
{
   if(SMC_CheckProfitGivebackLock())
   {
      // Reset automatique après 2 heures
      if(g_givebackLockTime > 0 && (TimeCurrent() - g_givebackLockTime) >= 7200)
      {
         g_profitGivebackLock = false;
         g_givebackLockTime   = 0;
         SMC_SavePerformancePauseState();
         Print("[GIVEBACK-GUARD] ✅ Pause 2h terminée — trading autorisé");
         return true;
      }
      static datetime s_gbLog = 0;
      if(TimeCurrent() - s_gbLog >= 120)
      {
         s_gbLog = TimeCurrent();
         int remaining = (int)(7200 - (TimeCurrent() - g_givebackLockTime));
         Print("[GIVEBACK-GUARD] BLOQUÉ — ", remaining/60, "min ", remaining%60, "s restantes avant reprise");
      }
      return false;
   }

   if(SMC_WinStreakPauseActive())
   {
      static datetime s_wsLog = 0;
      if(TimeCurrent() - s_wsLog >= 120)
      {
         s_wsLog = TimeCurrent();
         int rem = (int)(g_perfPauseUntil - TimeCurrent());
         Print("[WIN-STREAK] BLOQUE — pause performance ",
               rem / 3600, "h ", (rem % 3600) / 60, "m restantes");
      }
      return false;
   }

   return true;
}

#endif
