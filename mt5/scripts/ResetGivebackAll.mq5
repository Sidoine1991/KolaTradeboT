//+------------------------------------------------------------------+
//| Script: ResetGivebackAll                                          |
//| Réinitialise le giveback guard sur TOUS les graphiques du terminal|
//| Exécuter une fois par terminal (Weltrade, Deriv, etc.)            |
//+------------------------------------------------------------------+
#property script_show_inputs

void OnStart()
{
   int deleted = 0;
   int flagsSet = 0;
   string chartIds[];
   ArrayResize(chartIds, 0);

   int total = GlobalVariablesTotal();
   for(int i = 0; i < total; i++)
   {
      string name = GlobalVariableName(i);
      if(StringFind(name, "SMC_PERF_") != 0)
         continue;

      int p1 = StringLen("SMC_PERF_");
      int p2 = StringFind(name, "_", p1);
      if(p2 <= p1)
         continue;

      string idStr = StringSubstr(name, p1, p2 - p1);
      bool found = false;
      for(int j = 0; j < ArraySize(chartIds); j++)
      {
         if(chartIds[j] == idStr)
         {
            found = true;
            break;
         }
      }
      if(!found)
      {
         int n = ArraySize(chartIds);
         ArrayResize(chartIds, n + 1);
         chartIds[n] = idStr;
      }
   }

   total = GlobalVariablesTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string name = GlobalVariableName(i);
      bool isPerf  = (StringFind(name, "SMC_PERF_") == 0);
      bool isReset = (StringFind(name, "SMC_GivebackManualReset_") == 0);
      if(!isPerf && !isReset)
         continue;

      bool del = false;
      if(StringFind(name, "GivebackLock") >= 0)      del = true;
      if(StringFind(name, "GivebackPeak") >= 0)      del = true;
      if(StringFind(name, "AbsDrawdownLock") >= 0)   del = true;
      if(StringFind(name, "LossPauseGlobal") >= 0)   del = true;
      if(StringFind(name, "LossPauseSymUntil") >= 0)  del = true;
      if(isReset)                                    del = true;

      if(del && GlobalVariableDel(name))
         deleted++;
   }

   string curId = IntegerToString((long)ChartID());
   bool hasCur = false;
   for(int j = 0; j < ArraySize(chartIds); j++)
   {
      if(chartIds[j] == curId)
         hasCur = true;
      GlobalVariableSet("SMC_GivebackManualReset_" + chartIds[j], 1.0);
      flagsSet++;
   }
   if(!hasCur)
   {
      GlobalVariableSet("SMC_GivebackManualReset_" + curId, 1.0);
      flagsSet++;
   }

   Print("[RESET-GIVEBACK-ALL] Terminal reset | ", deleted,
         " GV supprimées | ", flagsSet, " flag(s) posé(s)");
   Alert("Giveback réinitialisé sur ce terminal — EA actif au prochain tick");
}
