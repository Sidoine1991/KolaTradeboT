// SMC_GivebackResetManuel.mq5
// Script pour rÃ©initialiser manuellement les conditions Giveback et reprendre le trading
#include "modules/SMC_PerformancePause.mqh"

void OnStart()
{
    Print("[GIVEBACK-GUARD] RÃ©initialisation manuelle dÃ©marrÃ©e - ChartID=", ChartID());

    string gvReset = "SMC_GivebackManualReset_" + IntegerToString((long)ChartID());
    GlobalVariableSet(gvReset, 1.0);

    g_profitGivebackLock = false;
    g_givebackLockTime = 0;
    g_givebackPeakAtLock = 0.0;
    g_consecutiveWins = 0;
    g_perfPauseUntil = 0;
    g_absoluteDrawdownLock = false;
    g_absoluteDrawdownLockTime = 0;

    double dailyStart = AccountInfoDouble(ACCOUNT_EQUITY);
    g_dailyStartEquity = dailyStart;
    g_dailyMaxEquity = dailyStart;

    Print("[GIVEBACK-GUARD] => Toutes les pauses performance dÃ©sactivÃ©es, trading repris normalement");
    Print("[GIVEBACK-GUARD] => EquitÃ© journaliÃ¨re rÃ©initialisÃ©e Ã  ", dailyStart);
    Alert("Giveback guard rÃ©initialisÃ©");
}