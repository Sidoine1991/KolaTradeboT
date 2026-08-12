//+------------------------------------------------------------------+
//| SMC_PostSpikeRecovery.mqh - Post-Spike Recovery Strategy             |
//| Stratégie basée sur la recherche: reprise après spike = haut taux    |
//| Attendre 3-5 bougies après spike, vérifier reprise du creep         |
//+------------------------------------------------------------------+
#ifndef SMC_POST_SPIKE_RECOVERY_MQH
#define SMC_POST_SPIKE_RECOVERY_MQH

struct SMC_PostSpikeRecovery
{
   datetime lastSpikeTime;
   double   spikeHigh;
   double   spikeLow;
   int      spikeDirection;  // +1 up, -1 down
   int      barsSinceSpike;
   bool     recoveryConfirmed;
   double   recoveryStrength;  // 0-100
};

SMC_PostSpikeRecovery g_postSpikeRecovery;

//+------------------------------------------------------------------+
//| Initialiser l'état post-spike                                       |
//+------------------------------------------------------------------+
void SMC_PSR_Init()
{
   ZeroMemory(g_postSpikeRecovery);
}

//+------------------------------------------------------------------+
//| Enregistrer un spike détecté                                       |
//+------------------------------------------------------------------+
void SMC_PSR_RegisterSpike(const double price, const int direction)
{
   g_postSpikeRecovery.lastSpikeTime = TimeCurrent();
   g_postSpikeRecovery.spikeDirection = direction;
   g_postSpikeRecovery.barsSinceSpike = 0;
   g_postSpikeRecovery.recoveryConfirmed = false;
   g_postSpikeRecovery.recoveryStrength = 0.0;
   
   if(direction > 0)
   {
      g_postSpikeRecovery.spikeHigh = price;
      g_postSpikeRecovery.spikeLow = price;  // sera mis à jour
   }
   else
   {
      g_postSpikeRecovery.spikeLow = price;
      g_postSpikeRecovery.spikeHigh = price;  // sera mis à jour
   }
   
   Print("[PSR] Spike enregistré: ", direction > 0 ? "UP" : "DOWN", " @ ", DoubleToString(price, 2));
}

//+------------------------------------------------------------------+
//| Mettre à jour le compteur de bougies après spike                     |
//+------------------------------------------------------------------+
void SMC_PSR_UpdateBars()
{
   if(g_postSpikeRecovery.lastSpikeTime > 0)
   {
      g_postSpikeRecovery.barsSinceSpike++;
   }
}

//+------------------------------------------------------------------+
//| Vérifier si l'entrée post-spike est autorisée                       |
//+------------------------------------------------------------------+
bool SMC_PSR_AllowsEntry(const string symbol, const int dirSign)
{
   // Pas de spike récent = pas de restriction
   if(g_postSpikeRecovery.lastSpikeTime == 0) return true;
   
   // Attendre minimum 3 bougies après spike
   if(g_postSpikeRecovery.barsSinceSpike < 3)
   {
      static datetime s_log = 0;
      if(TimeCurrent() - s_log >= 30)
      {
         s_log = TimeCurrent();
         Print("[PSR] Attente bougies après spike: ", g_postSpikeRecovery.barsSinceSpike, "/3");
      }
      return false;
   }
   
   // Si déjà confirmé, autoriser
   if(g_postSpikeRecovery.recoveryConfirmed)
   {
      return true;
   }
   
   // Vérifier que le creep reprend
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 5, r) < 5) return false;
   
   // Calculer la taille moyenne des bougies
   double avgBody = 0;
   for(int i = 0; i < 3; i++)
      avgBody += MathAbs(r[i].close - r[i].open);
   avgBody /= 3;
   
   // Direction du creep: Crash=BUY, Boom=SELL
   bool creepDir = IsCrashLikeSymbol(symbol);
   
   // Vérifier que les bougies vont dans le sens du creep
   int alignedBars = 0;
   double totalMove = 0;
   for(int i = 0; i < 3; i++)
   {
      double move = r[i].close - r[i].open;
      totalMove += move;
      if(creepDir && move > 0) alignedBars++;
      else if(!creepDir && move < 0) alignedBars++;
   }
   
   // Calculer la force de la reprise (0-100)
   double moveStrength = MathAbs(totalMove) / (avgBody * 3 + 0.001) * 100;
   g_postSpikeRecovery.recoveryStrength = MathMin(100, moveStrength);
   
   // Condition: au moins 2 bougies alignées + force minimale
   if(alignedBars >= 2 && g_postSpikeRecovery.recoveryStrength > 30)
   {
      g_postSpikeRecovery.recoveryConfirmed = true;
      Print("[PSR] Reprise confirmée: ", alignedBars, "/3 alignées | force=", 
            DoubleToString(g_postSpikeRecovery.recoveryStrength, 1));
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Obtenir la force de la reprise actuelle                            |
//+------------------------------------------------------------------+
double SMC_PSR_GetRecoveryStrength()
{
   return g_postSpikeRecovery.recoveryStrength;
}

//+------------------------------------------------------------------+
//| Obtenir le nombre de bougies depuis le dernier spike                 |
//+------------------------------------------------------------------+
int SMC_PSR_GetBarsSinceSpike()
{
   return g_postSpikeRecovery.barsSinceSpike;
}

//+------------------------------------------------------------------+
//| Réinitialiser après expiration (ex: 10 minutes sans spike)          |
//+------------------------------------------------------------------+
void SMC_PSR_CheckExpiry(const int maxMinutes = 10)
{
   if(g_postSpikeRecovery.lastSpikeTime > 0)
   {
      if(TimeCurrent() - g_postSpikeRecovery.lastSpikeTime > maxMinutes * 60)
      {
         Print("[PSR] Expiration - reset après ", maxMinutes, " minutes");
         SMC_PSR_Init();
      }
   }
}

#endif // SMC_POST_SPIKE_RECOVERY_MQH
