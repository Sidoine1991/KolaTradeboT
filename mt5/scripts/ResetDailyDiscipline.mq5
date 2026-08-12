// Script: ResetDailyDiscipline
// Lance ce script sur un graphique pour remettre le compteur journalier à zéro
// (utile si MaxDailyTrades est atteint et qu'on veut continuer à trader)
#property script_show_inputs

input int MagicNumber = 202502; // Magic Number de l'EA

void OnStart()
{
   string prefix = "SMC_Disc_" + IntegerToString(MagicNumber) + "_";

   GlobalVariableSet(prefix + "Trades",    0);
   GlobalVariableSet(prefix + "TargetHit", 0);
   // Remettre la date à aujourd'hui pour qu'au prochain tick l'EA recharge les bonnes valeurs
   MqlDateTime dt;
   TimeLocal(dt);
   int today = dt.year * 10000 + dt.mon * 100 + dt.day;
   GlobalVariableSet(prefix + "Date", today);

   Print("[RESET-DISCIPLINE] Compteur remis à 0 pour Magic=", MagicNumber,
         " — GV: ", prefix, "Trades=0, TargetHit=0, Date=", today);
   Alert("Discipline journalière réinitialisée (Magic=", MagicNumber, ")");
}
