//+------------------------------------------------------------------+
//| SMC_PerformancePause.mqh — pause après série de gains + giveback  |
//+------------------------------------------------------------------+
#ifndef SMC_PERFORMANCE_PAUSE_MQH
#define SMC_PERFORMANCE_PAUSE_MQH

extern double g_dailyStartEquity;
extern double g_dailyMaxEquity;
extern double g_dailyMinEquity;
// Ces variables sont declarees en input dans le .mq5 principal
// extern bool   UseAbsoluteDrawdownGuard;
// extern double AbsoluteDrawdownPct;

int g_consecutiveWins = 0;
double g_winStreakSessionUSD = 0.0;
datetime g_perfPauseUntil = 0;
bool g_profitGivebackLock = false;
string g_perfPauseLastWinSymbol = ""; // dernier symbole gagnant
void SMC_SetLastWinSymbol(const string s) { g_perfPauseLastWinSymbol = s; }
datetime g_givebackLockTime    = 0;   // Heure du déclenchement du lock giveback
bool     g_absoluteDrawdownLock    = false;
datetime g_absoluteDrawdownLockTime = 0;

// --- Perte consécutive tracking ---
string   g_lastLossSymbol            = "";
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
   GlobalVariableSet(SMC_PerfPauseGV("LossPauseGlobal"),   (double)g_lossPauseGlobalUntil);
   GlobalVariableSet(SMC_PerfPauseGV("LossPauseSymUntil"), (double)g_lossPauseSymbolUntil);
   GlobalVariableSet(SMC_PerfPauseGV("AbsDrawdownLock"),     g_absoluteDrawdownLock ? 1.0 : 0.0);
   GlobalVariableSet(SMC_PerfPauseGV("AbsDrawdownLockTime"), (double)g_absoluteDrawdownLockTime);
}

void SMC_ResetPerformancePauseDaily()
{
    g_profitGivebackLock = false;
    g_givebackLockTime = 0;
    g_absoluteDrawdownLock = false;
    g_absoluteDrawdownLockTime = 0;
    GlobalVariableSet(SMC_PerfPauseGV("GivebackLock"), 0.0);
    GlobalVariableSet(SMC_PerfPauseGV("GivebackLockTime"), 0.0);
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

    if(!UseWinStreakPause || profit <= 0)
        return;

    g_consecutiveWins++;
    g_winStreakSessionUSD += profit;
    SMC_SavePerformancePauseState();

    Print("[WIN-STREAK] Gain #", g_consecutiveWins, " | +", DoubleToString(profit, 2),
          "$ | serie +", DoubleToString(g_winStreakSessionUSD, 2), "$");

    if(g_consecutiveWins >= WinStreakThreshold)
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
   if(!UseProfitGivebackGuard || g_profitGivebackLock)
      return g_profitGivebackLock;

   if(g_dailyStartEquity <= 0.0)
      return false;

   double peakProfit = g_dailyMaxEquity - g_dailyStartEquity;
   double curProfit  = AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartEquity;

   // Petit capital : seuil relatif si le pic absolu est trop bas
   if(peakProfit < ProfitGivebackMinPeakUSD)
   {
      if(g_dailyStartEquity > 0 && peakProfit < g_dailyStartEquity * 0.03)
         return false; // Pic < 3% du capital — trop petit pour giveback
      // Sinon on continue même si pic < ProfitGivebackMinPeakUSD (petit capital)
   }
   if(peakProfit <= 0.0)
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

//+------------------------------------------------------------------+
//| Absolute Drawdown Guard — pause si équité < X% du capital départ  |
//+------------------------------------------------------------------+
bool SMC_CheckAbsoluteDrawdown()
{
   if(!UseAbsoluteDrawdownGuard || g_absoluteDrawdownLock)
      return g_absoluteDrawdownLock;
   if(g_dailyStartEquity <= 0.0)
      return false;
   double floorEquity = g_dailyStartEquity * (AbsoluteDrawdownPct / 100.0);
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity >= floorEquity)
      return false;
   g_absoluteDrawdownLock = true;
   g_absoluteDrawdownLockTime = TimeCurrent();
   SMC_SavePerformancePauseState();
   Print("[ABS-DD] 🔒 Équité ", DoubleToString(currentEquity, 2), "$ < ",
         DoubleToString(AbsoluteDrawdownPct, 0), "% départ (",
         DoubleToString(floorEquity, 2), "$) — PAUSE jusqu'à réinitialisation quotidienne");
   if(UseNotifications)
   {
      Alert("Drawdown absolu: pause quotidienne — equity " + DoubleToString(currentEquity, 2) + "$");
      SendNotification("Drawdown absolu: pause — equity " + DoubleToString(currentEquity, 2) + "$");
   }
   return true;
}

bool SMC_PerformancePauseAllowsEntry(const string symbol = "")
{
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
