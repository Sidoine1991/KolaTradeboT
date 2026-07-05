//+------------------------------------------------------------------+
//| SMC_PerformancePause.mqh — pause après série de gains + giveback  |
//+------------------------------------------------------------------+
#ifndef SMC_PERFORMANCE_PAUSE_MQH
#define SMC_PERFORMANCE_PAUSE_MQH

// Declare the new global variable for giveback pause hours
int    g_profitGivebackPauseHours = 0;  // Duration of giveback pause in hours

int g_consecutiveWins = 0;
double g_winStreakSessionUSD = 0.0;
datetime g_perfPauseUntil = 0;
bool g_profitGivebackLock = false;
string g_perfPauseLastWinSymbol = ""; // dernier symbole gagnant
void SMC_SetLastWinSymbol(const string s) { g_perfPauseLastWinSymbol = s; }
datetime g_givebackLockTime    = 0;   // Heure du déclenchement du lock giveback
double   g_givebackPeakAtLock  = 0.0; // Pic journalier ($) au moment du lock — évite re-lock immédiat
bool g_absoluteDrawdownLock    = false;
datetime g_absoluteDrawdownLockTime = 0;

// --- Configuration Proxies (Set from SMC_Universal) ---
bool   g_useNotifications         = true;
bool   g_useWinStreakPause       = true;
int    g_winStreakPauseHours     = 1;
int    g_winStreakThreshold      = 3;
bool   g_useAbsoluteDrawdownGuard = true;
double g_absoluteDrawdownPct     = 10.0;
bool   g_useLossStreakPause       = true;
bool   g_useProfitGivebackGuard  = true;
double g_profitGivebackPct       = 40.0;
double g_profitGivebackMinPeakUSD = 5.0;

// --- Perte consécutive tracking ---
#define RECENT_LOSS_WINDOW_SEC 900   // 15 min — fenêtre perte récente (post-loss cooldown)
// g_lastLossSymbol, g_lastLossTime declared in SMC_Universal.mq5 before #include
int      g_consecutiveLosses         = 0;
datetime g_lossPauseGlobalUntil      = 0;  // Pause globale après pertes sur symboles différents
int      g_lossPauseGlobalHours      = 1;  // Durée pause globale (défaut 1h)
string   g_lossPauseSymbol           = ""; // Symbole en pause spécifique
datetime g_lossPauseSymbolUntil      = 0;  // Fin pause symbole spécifique
int      g_lossPauseSymbolHours      = 2;  // Durée pause même symbole (défaut 2h)
int      g_lossStreakThreshold       = 3;  // Seuil pertes consécutives pour pause

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
   if(GlobalVariableCheck(SMC_PerfPauseGV("GivebackPeak")))
      g_givebackPeakAtLock = GlobalVariableGet(SMC_PerfPauseGV("GivebackPeak"));
   if(GlobalVariableCheck(SMC_PerfPauseGV("LossPauseGlobal")))
      g_lossPauseGlobalUntil = (datetime)GlobalVariableGet(SMC_PerfPauseGV("LossPauseGlobal"));
   if(GlobalVariableCheck(SMC_PerfPauseGV("LossPauseSymUntil")))
      g_lossPauseSymbolUntil = (datetime)GlobalVariableGet(SMC_PerfPauseGV("LossPauseSymUntil"));
   if(GlobalVariableCheck(SMC_PerfPauseGV("AbsDrawdownLock")))
      g_absoluteDrawdownLock = (GlobalVariableGet(SMC_PerfPauseGV("AbsDrawdownLock")) > 0.5);
   if(GlobalVariableCheck(SMC_PerfPauseGV("AbsDrawdownLockTime")))
      g_absoluteDrawdownLockTime = (datetime)GlobalVariableGet(SMC_PerfPauseGV("AbsDrawdownLockTime"));
}

void SMC_SavePerformancePauseState()
{
   GlobalVariableSet(SMC_PerfPauseGV("PauseUntil"),       (double)g_perfPauseUntil);
   GlobalVariableSet(SMC_PerfPauseGV("ConsecWins"),        (double)g_consecutiveWins);
   GlobalVariableSet(SMC_PerfPauseGV("GivebackLock"),      g_profitGivebackLock ? 1.0 : 0.0);
   GlobalVariableSet(SMC_PerfPauseGV("GivebackLockTime"),  (double)g_givebackLockTime);
   GlobalVariableSet(SMC_PerfPauseGV("GivebackPeak"),        g_givebackPeakAtLock);
   GlobalVariableSet(SMC_PerfPauseGV("LossPauseGlobal"),   (double)g_lossPauseGlobalUntil);
   GlobalVariableSet(SMC_PerfPauseGV("LossPauseSymUntil"), (double)g_lossPauseSymbolUntil);
   GlobalVariableSet(SMC_PerfPauseGV("AbsDrawdownLock"),     g_absoluteDrawdownLock ? 1.0 : 0.0);
   GlobalVariableSet(SMC_PerfPauseGV("AbsDrawdownLockTime"), (double)g_absoluteDrawdownLockTime);
}

void SMC_ResetPerformancePauseDaily()
{
    g_profitGivebackLock = false;
    g_givebackLockTime = 0;
    g_givebackPeakAtLock = 0.0;
    g_absoluteDrawdownLock = false;
    g_absoluteDrawdownLockTime = 0;
    GlobalVariableSet(SMC_PerfPauseGV("GivebackLock"), 0.0);
    GlobalVariableSet(SMC_PerfPauseGV("GivebackLockTime"), 0.0);
    GlobalVariableSet(SMC_PerfPauseGV("GivebackPeak"), 0.0);
    GlobalVariableSet(SMC_PerfPauseGV("AbsDrawdownLock"), 0.0);
    GlobalVariableSet(SMC_PerfPauseGV("AbsDrawdownLockTime"), 0.0);
}

void SMC_ResetPerformancePauseFull()
{
    g_consecutiveWins = 0;
    g_winStreakSessionUSD = 0.0;
    g_perfPauseUntil = 0;
    g_profitGivebackLock = false;
    g_givebackLockTime = 0;
    g_givebackPeakAtLock = 0.0;
    g_absoluteDrawdownLock = false;
    g_absoluteDrawdownLockTime = 0;
    if(GlobalVariableCheck(SMC_PerfPauseGV("PauseUntil")))
        GlobalVariableDel(SMC_PerfPauseGV("PauseUntil"));
    if(GlobalVariableCheck(SMC_PerfPauseGV("ConsecWins")))
        GlobalVariableDel(SMC_PerfPauseGV("ConsecWins"));
    if(GlobalVariableCheck(SMC_PerfPauseGV("GivebackLock")))
        GlobalVariableDel(SMC_PerfPauseGV("GivebackLock"));
    if(GlobalVariableCheck(SMC_PerfPauseGV("GivebackLockTime")))
        GlobalVariableDel(SMC_PerfPauseGV("GivebackLockTime"));
    if(GlobalVariableCheck(SMC_PerfPauseGV("GivebackPeak")))
        GlobalVariableDel(SMC_PerfPauseGV("GivebackPeak"));
}

int SMC_GivebackPauseSeconds()
{
   return MathMax(1, g_profitGivebackPauseHours) * 3600;
}

// Fin de pause giveback : autoriser le trading et repartir sur un nouveau pic
void SMC_UnlockProfitGivebackAfterPause()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_profitGivebackLock = false;
   g_givebackLockTime   = 0;
   g_givebackPeakAtLock = 0.0;
   g_dailyMaxEquity     = eq;
   if(g_dailyMinEquity <= 0.0 || eq < g_dailyMinEquity)
      g_dailyMinEquity = eq;
   SMC_SavePerformancePauseState();
   Print("[GIVEBACK-GUARD] ✅ Pause ", g_profitGivebackPauseHours,
         "h terminée — trading autorisé | nouveau pic journalier=",
         DoubleToString(eq, 2), "$ (cycle giveback remis à zéro)");
}

bool SMC_WinStreakPauseActive()
{
   if(!g_useWinStreakPause || g_perfPauseUntil <= 0)
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
   int pauseSec = MathMax(1, g_winStreakPauseHours) * 3600;
   g_perfPauseUntil = TimeCurrent() + pauseSec;
   g_consecutiveWins = 0;
   g_winStreakSessionUSD = 0.0;
   SMC_SavePerformancePauseState();

   datetime resumeAt = g_perfPauseUntil;
   Print("[WIN-STREAK] 🏆 ", g_winStreakThreshold,
         " gains consécutifs — PAUSE ", g_winStreakPauseHours, "h jusqu'à ",
         TimeToString(resumeAt, TIME_DATE|TIME_MINUTES));

   if(g_useNotifications)
   {
      Alert("Pause performance: ", g_winStreakThreshold, " gains → stop ", g_winStreakPauseHours, "h");
      SendNotification("Pause performance: serie de gains → stop " + IntegerToString(g_winStreakPauseHours) + "h");
   }
}

void SMC_RecordTradeClosePerformance(const double profit, const string symbol)
{
    if(profit < 0)
    {
        // ── Perte : reset streak gains ──
        g_consecutiveWins = 0;
        g_winStreakSessionUSD = 0.0;

        // ── Loss streak tracking ──
        if(symbol != "" && StringLen(symbol) > 0)
        {
            g_consecutiveLosses++;
            bool sameSymbol = (g_lastLossSymbol == symbol);
            if(sameSymbol)
            {
                // Même symbole → pause spécifique
                g_lossPauseSymbol = symbol;
                g_lossPauseSymbolUntil = TimeCurrent() + g_lossPauseSymbolHours * 3600;
                Print("[LOSS-STREAK] 2 pertes consécutives sur ", symbol,
                      " → pause ", g_lossPauseSymbolHours, "h (jusqu'à ",
                      TimeToString(g_lossPauseSymbolUntil, TIME_MINUTES), ")");
            }
            else if(g_consecutiveLosses >= g_lossStreakThreshold)
            {
                // Symboles différents → pause globale
                g_lossPauseGlobalUntil = TimeCurrent() + g_lossPauseGlobalHours * 3600;
                Print("[LOSS-STREAK] ", g_consecutiveLosses, " pertes consécutives (",
                      g_lastLossSymbol, " puis ", symbol,
                      ") → pause GLOBALE ", g_lossPauseGlobalHours, "h (jusqu'à ",
                      TimeToString(g_lossPauseGlobalUntil, TIME_MINUTES), ")");
            }
            g_lastLossSymbol = symbol;
        }

        SMC_SavePerformancePauseState();
        return;
    }

    // ── Gain ──
    if(profit > 0)
    {
        // Reset pertes consécutives sur gain
        g_consecutiveLosses = 0;
        g_lastLossSymbol = "";
        // Ne pas reset les pauses déjà actives (elles restent jusqu'à expiration)
    }

    if(!g_useWinStreakPause || profit <= 0)
        return;

    g_consecutiveWins++;
    g_winStreakSessionUSD += profit;
    SMC_SavePerformancePauseState();

    Print("[WIN-STREAK] Gain #", g_consecutiveWins, " | +", DoubleToString(profit, 2),
          "$ | serie +", DoubleToString(g_winStreakSessionUSD, 2), "$");

    if(g_consecutiveWins >= g_winStreakThreshold)
        SMC_TriggerWinStreakPause();
}

//+------------------------------------------------------------------+
//| Vérifie si les pertes consécutives bloquent ce symbole           |
//+------------------------------------------------------------------+
bool SMC_LossStreakAllowsEntry(const string symbol)
{
    // Pause globale active ?
    if(g_lossPauseGlobalUntil > 0)
    {
        if(TimeCurrent() >= g_lossPauseGlobalUntil)
        {
            g_lossPauseGlobalUntil = 0;
            SMC_SavePerformancePauseState();
            return true;
        }
        static datetime s_lsLog = 0;
        if(TimeCurrent() - s_lsLog >= 120)
        {
            s_lsLog = TimeCurrent();
            int rem = (int)(g_lossPauseGlobalUntil - TimeCurrent());
            Print("[LOSS-STREAK] BLOQUE GLOBAL — ", rem/60, "min ", rem%60, "s restants");
        }
        return false;
    }

    // Pause symbole spécifique active ?
    if(g_lossPauseSymbolUntil > 0 && g_lossPauseSymbol == symbol)
    {
        if(TimeCurrent() >= g_lossPauseSymbolUntil)
        {
            g_lossPauseSymbol = "";
            g_lossPauseSymbolUntil = 0;
            SMC_SavePerformancePauseState();
            return true;
        }
        static datetime s_lsSymLog = 0;
        if(TimeCurrent() - s_lsSymLog >= 120)
        {
            s_lsSymLog = TimeCurrent();
            int rem = (int)(g_lossPauseSymbolUntil - TimeCurrent());
            Print("[LOSS-STREAK] BLOQUE ", symbol, " — ", rem/60, "min ", rem%60, "s restants");
        }
        return false;
    }

    return true;
}

bool SMC_CheckProfitGivebackLock()
{
   if(!g_useProfitGivebackGuard)
      return false;

   // Déjà en pause giveback — ne pas re-évaluer le seuil (évite re-lock instantané)
   if(g_profitGivebackLock)
      return true;

   if(g_dailyStartEquity <= 0.0)
      return false;

   double peakProfit = g_dailyMaxEquity - g_dailyStartEquity;
   double curProfit  = AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartEquity;

   if(peakProfit < g_profitGivebackMinPeakUSD)
      return false;
   if(peakProfit <= 0.0)
      return false;

   double floorProfit = peakProfit * (1.0 - g_profitGivebackPct / 100.0);
   if(curProfit >= floorProfit)
      return false;

   g_profitGivebackLock   = true;
   g_givebackLockTime     = TimeCurrent();
   g_givebackPeakAtLock   = peakProfit;
   SMC_SavePerformancePauseState();
int pauseSec = SMC_GivebackPauseSeconds();
    Print("[GIVEBACK-GUARD] 🔒 Pic jour +", DoubleToString(peakProfit, 2),
          "$ → actuel +", DoubleToString(curProfit, 2),
          "$ (seuil ", DoubleToString(floorProfit, 2), "$) — pause ",
          g_profitGivebackPauseHours, "h, reprise à ",
          TimeToString(g_givebackLockTime + pauseSec, TIME_MINUTES));
    if(g_useNotifications)
    {
       Alert("Giveback guard: pause " + IntegerToString(g_profitGivebackPauseHours) + "h — profits proteges");
       SendNotification("Giveback guard: pause " + IntegerToString(g_profitGivebackPauseHours) +
                        "h — reprise " + TimeToString(g_givebackLockTime + pauseSec, TIME_MINUTES));
    }
    return true;
}

//+------------------------------------------------------------------+
//| Absolute Drawdown Guard — pause si équité < X% du capital départ  |
//+------------------------------------------------------------------+
bool SMC_CheckAbsoluteDrawdown()
{
   if(!g_useAbsoluteDrawdownGuard || g_absoluteDrawdownLock)
      return g_absoluteDrawdownLock;
   if(g_dailyStartEquity <= 0.0)
      return false;
   double floorEquity = g_dailyStartEquity * (g_absoluteDrawdownPct / 100.0);
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity >= floorEquity)
      return false;
   g_absoluteDrawdownLock = true;
   g_absoluteDrawdownLockTime = TimeCurrent();
   SMC_SavePerformancePauseState();
   Print("[ABS-DD] 🔒 Équité ", DoubleToString(currentEquity, 2), "$ < ",
         DoubleToString(g_absoluteDrawdownPct, 0), "% départ (",
         DoubleToString(floorEquity, 2), "$) — PAUSE jusqu'à réinitialisation quotidienne");
   if(g_useNotifications)
   {
      Alert("Drawdown absolu: pause quotidienne — equity " + DoubleToString(currentEquity, 2) + "$");
      SendNotification("Drawdown absolu: pause — equity " + DoubleToString(currentEquity, 2) + "$");
   }
   return true;
}

bool SMC_PerformancePauseAllowsEntry(const string symbol = "")
{
   // ── 0. RESET MANUEL : script ResetGiveback a posé le flag ──────────────
   string gvReset = "SMC_GivebackManualReset_" + IntegerToString((long)ChartID());
   if(GlobalVariableCheck(gvReset) && GlobalVariableGet(gvReset) > 0.5)
   {
      GlobalVariableDel(gvReset);
      g_profitGivebackLock = false;
      g_givebackLockTime   = 0;
      g_givebackPeakAtLock = 0.0;
      g_dailyMaxEquity     = AccountInfoDouble(ACCOUNT_EQUITY);
      SMC_SavePerformancePauseState();
      Print("[GIVEBACK-GUARD] ✅ Reset manuel — pic journalier repart à ",
            DoubleToString(g_dailyMaxEquity, 2), "$");
      return true;
   }

   // ── 1. Absolute Drawdown (perte en capital) ────────────────────────────
   if(SMC_CheckAbsoluteDrawdown())
   {
      static datetime s_ddLog = 0;
      if(TimeCurrent() - s_ddLog >= 120)
      {
         s_ddLog = TimeCurrent();
         Print("[ABS-DD] BLOQUÉ — drawdown absolu actif jusqu'au prochain reset journalier");
      }
      return false;
   }

   // ── 2. Profit Giveback Guard ───────────────────────────────────────────
   if(g_profitGivebackLock)
   {
      int pauseSec = SMC_GivebackPauseSeconds();
      if(g_givebackLockTime > 0 && (TimeCurrent() - g_givebackLockTime) >= pauseSec)
      {
         SMC_UnlockProfitGivebackAfterPause();
         return true;
      }
      static datetime s_gbLog = 0;
      if(TimeCurrent() - s_gbLog >= 120)
      {
         s_gbLog = TimeCurrent();
         int remaining = (int)(pauseSec - (TimeCurrent() - g_givebackLockTime));
         if(remaining < 0) remaining = 0;
         Print("[GIVEBACK-GUARD] BLOQUÉ — ", remaining/60, "min ", remaining%60,
               "s restantes avant reprise");
      }
      return false;
   }

   if(SMC_CheckProfitGivebackLock())
      return false;

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

   // Pause globale pour pertes consécutives (symboles différents)
   if(g_lossPauseGlobalUntil > 0)
   {
      if(TimeCurrent() >= g_lossPauseGlobalUntil)
      {
         g_lossPauseGlobalUntil = 0;
         SMC_SavePerformancePauseState();
         Print("[LOSS-STREAK] ✅ Pause globale terminée");
         return true;
      }
      static datetime s_lsLog = 0;
      if(TimeCurrent() - s_lsLog >= 120)
      {
         s_lsLog = TimeCurrent();
         int rem = (int)(g_lossPauseGlobalUntil - TimeCurrent());
         Print("[LOSS-STREAK] BLOQUE GLOBAL — ", rem/60, "min ", rem%60, "s restants");
      }
      return false;
   }

   // Pause symbole spécifique (2 pertes même symbole)
   if(symbol != "" && g_lossPauseSymbolUntil > 0 && g_lossPauseSymbol == symbol)
   {
      if(TimeCurrent() >= g_lossPauseSymbolUntil)
      {
         g_lossPauseSymbol = "";
         g_lossPauseSymbolUntil = 0;
         SMC_SavePerformancePauseState();
         Print("[LOSS-STREAK] ✅ Pause ", symbol, " terminée");
         return true;
      }
      static datetime s_lsSymLog = 0;
      if(TimeCurrent() - s_lsSymLog >= 120)
      {
         s_lsSymLog = TimeCurrent();
         int rem = (int)(g_lossPauseSymbolUntil - TimeCurrent());
         Print("[LOSS-STREAK] BLOQUE ", symbol, " — ", rem/60, "min ", rem%60, "s restants");
      }
      return false;
   }

   return true;
}

#endif
