// ... [contenu existant jusqu'à la fonction UpdateWinCounter] ...

//+------------------------------------------------------------------+
//| Met à jour le compteur de gains et gère le cooldown             |
//+------------------------------------------------------------------+
void UpdateWinCounter(double profit)
{
   if(profit > 0)
   {
      g_consecutiveWins++;
      g_lastWinTime = TimeCurrent();
      Print("🎯 Gain enregistré. Série de gains: ", g_consecutiveWins);
      
      // Vérifier si on est sur le Boom 300 Index
      bool isBoom300 = (StringFind(_Symbol, "Boom 300") >= 0);
      
      // Démarrer le cooldown après 2 gains consécutifs
      if(g_consecutiveWins >= g_requiredWinsForCooldown)
      {
         g_winCooldownUntil = TimeCurrent() + (g_winCooldownMinutes * 60);
         Print("⏸️ Cooldown de ", g_winCooldownMinutes, 
               " minutes après ", g_consecutiveWins, " gains consécutifs.");
               
         // Si c'est le Boom 300 Index et qu'on a 2 gains consécutifs, on active une pause de 5 minutes
         if(isBoom300 && g_consecutiveWins == 2)
         {
            g_winStreakPauseUntil = TimeCurrent() + (5 * 60); // 5 minutes de pause
            Print("⏸️ Pause de 5 minutes activée après 2 gains consécutifs sur Boom 300 Index");
         }
      }
   }
   else if(profit < 0)
   {
      // Réinitialiser le compteur en cas de perte
      if(g_consecutiveWins > 0)
      {
         Print("🔄 Réinitialisation du compteur de gains après une perte");
         g_consecutiveWins = 0;
         
         // Si c'est le Boom 300 Index, on réinitialise aussi la pause
         if(g_winStreakPauseUntil > 0 && StringFind(_Symbol, "Boom 300") >= 0)
         {
            g_winStreakPauseUntil = 0;
            Print("🔄 Réinitialisation de la pause après gains consécutifs (suite à une perte)");
         }
      }
   }
}

// ... [contenu existant jusqu'à la fonction IsTradingAllowed] ...

//+------------------------------------------------------------------+
//| Vérifie les conditions de trading                               |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   // Vérifier les objectifs quotidiens
   if(IsDailyTargetReached())
      return false;
      
   // Vérifier les pertes consécutives sur ce symbole
   if(!CanTradeSymbolAfterLoss(_Symbol))
      return false;

   // Vérifier la limite de perte quotidienne
   if(IsDailyLossLimitReached())
   {
      if(GetTickCount() % 60000 < 1000) // Afficher une fois par minute max
         Print("❌ Limite de perte quotidienne atteinte: ", g_dailyLoss, " ", AccountInfoString(ACCOUNT_CURRENCY));
      return false;
   }
   
   // Vérifier le nombre de pertes consécutives
   if(g_consecutiveLosses >= MaxConsecLosses && MaxConsecLosses > 0)
   {
      if(GetTickCount() % 60000 < 1000) // Afficher une fois par minute max
         Print("⚠️ Arrêt après ", g_consecutiveLosses, " pertes consécutives");
      return false;
   }
   
   // Vérifier les pertes consécutives (fonction existante)
   if(!CanTradeAfterLosses())
      return false;
      
   // Vérifier la pause après 2 gains consécutifs sur le Boom 300 Index
   if(StringFind(_Symbol, "Boom 300") >= 0 && TimeCurrent() < g_winStreakPauseUntil)
   {
      int remaining = (int)(g_winStreakPauseUntil - TimeCurrent()) / 60;
      if(GetTickCount() % 60000 < 1000) // Afficher une fois par minute max
         Print("⏸️ Pause active après 2 gains consécutifs sur Boom 300 Index. Reprise dans ", remaining, " minutes");
      return false;
   }
      
   return true;
}

// ... [reste du contenu existant] ...
