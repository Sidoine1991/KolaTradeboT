//+------------------------------------------------------------------+
//| Script: ResetGiveback                                             |
//| Réinitialise le giveback guard sur le terminal actif             |
//| Pose un flag que l'EA traite au prochain tick pour reset le pic  |
//+------------------------------------------------------------------+
#property script_show_inputs

input ulong InpMagic = 20260524; // Magic number (pour info, pas utilisé dans les GV)

void OnStart()
{
   string prefix = "SMC_PERF_" + IntegerToString((long)ChartID()) + "_";
   string gvReset = "SMC_GivebackManualReset_" + IntegerToString((long)ChartID());
   int count = 0;

   // 1. Flag de reset manuel — l'EA le traitera au prochain tick
   GlobalVariableSet(gvReset, 1.0);
   Print("[RESET-GIVEBACK] Flag posé pour ChartID=", ChartID());

   // 2. Supprimer les锁 giveback (nettoyage immédiat)
   if(GlobalVariableCheck(prefix + "GivebackLock"))
   {
      GlobalVariableDel(prefix + "GivebackLock");
      count++;
   }
   if(GlobalVariableCheck(prefix + "GivebackLockTime"))
   {
      GlobalVariableDel(prefix + "GivebackLockTime");
      count++;
   }
   if(GlobalVariableCheck(prefix + "GivebackPeak"))
   {
      GlobalVariableDel(prefix + "GivebackPeak");
      count++;
   }

   // 3. Supprimer abs drawdown
   if(GlobalVariableCheck(prefix + "AbsDrawdownLock"))
   {
      GlobalVariableDel(prefix + "AbsDrawdownLock");
      count++;
   }
   if(GlobalVariableCheck(prefix + "AbsDrawdownLockTime"))
   {
      GlobalVariableDel(prefix + "AbsDrawdownLockTime");
      count++;
   }

   // 4. Supprimer loss pause
   if(GlobalVariableCheck(prefix + "LossPauseGlobal"))
   {
      GlobalVariableDel(prefix + "LossPauseGlobal");
      count++;
   }
   if(GlobalVariableCheck(prefix + "LossPauseSymUntil"))
   {
      GlobalVariableDel(prefix + "LossPauseSymUntil");
      count++;
   }

   Print("[RESET-GIVEBACK] ", count, " GV supprimées + flag reset posé");
   Print("[RESET-GIVEBACK] L'EA resettera g_dailyMaxEquity au prochain tick");
   Alert("Giveback guard réinitialisé — trading autorisé au prochain tick");
}
