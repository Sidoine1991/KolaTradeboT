//+------------------------------------------------------------------+
//| SMC_MissedSpikeReentry.mqh                                         |
//| Gestion de réentrée après spike manqué                            |
//| Quand une position touche SL sans atteindre le spike → prix en    |
//| correction → attendre prochain spike (4 bougies) → réentrée si   |
//| conditions favorables (M1+M5, Dow, etc.)                         |
//+------------------------------------------------------------------+
// ── État de suivi des spikes manqués ───────────────────────────────
struct MissedSpikeState
{
   datetime lastMissedSpikeTime;    // Heure du dernier spike manqué
   int      missedDirection;        // Direction du spike manqué (1=BUY, -1=SELL)
   int      barsSinceMissed;        // Bougies depuis le spike manqué
   bool     reentryArmed;           // Réentrée armée (après 4 bougies)
   string   symbol;                 // Symbole concerné
};

MissedSpikeState g_missedSpikeState;

// ── Paramètres ───────────────────────────────────────────────────────
input int    MissedSpikeWaitBars      = 4;      // Bougies d'attente après spike manqué
input double MissedSpikeReentryATRMult = 0.15;  // Distance max pour réentrée (x ATR)

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
void SMC_MSR_Init()
{
   ZeroMemory(g_missedSpikeState);
   g_missedSpikeState.missedDirection = 0;
   g_missedSpikeState.barsSinceMissed = 0;
   g_missedSpikeState.reentryArmed = false;
}

//+------------------------------------------------------------------+
//| Nettoyage                                                         |
//+------------------------------------------------------------------+
void SMC_MSR_Deinit()
{
   ZeroMemory(g_missedSpikeState);
}

//+------------------------------------------------------------------+
//| Mettre à jour l'état (appelé dans OnTick)                         |
//+------------------------------------------------------------------+
void SMC_MSR_Update(const string symbol)
{
   // Si pas de spike manqué en cours → rien à faire
   if(g_missedSpikeState.missedDirection == 0)
      return;

   // Compter les bougies depuis le spike manqué
   datetime barTime = iTime(symbol, PERIOD_M1, 0);
   if(barTime > g_missedSpikeState.lastMissedSpikeTime)
   {
      g_missedSpikeState.barsSinceMissed++;
      
      // Armer la réentrée après le nombre de bougies requis
      if(g_missedSpikeState.barsSinceMissed >= MissedSpikeWaitBars)
      {
         g_missedSpikeState.reentryArmed = true;
         Print("[MSR] Réentrée armée après ", g_missedSpikeState.barsSinceMissed, 
               " bougies | ", symbol, " | Direction: ", 
               (g_missedSpikeState.missedDirection > 0 ? "BUY" : "SELL"));
      }
   }
}

//+------------------------------------------------------------------+
//| Enregistrer un spike manqué (appelé quand SL touché sans spike)    |
//+------------------------------------------------------------------+
void SMC_MSR_RegisterMissedSpike(const string symbol, const int direction)
{
   g_missedSpikeState.lastMissedSpikeTime = TimeCurrent();
   g_missedSpikeState.missedDirection = direction;
   g_missedSpikeState.barsSinceMissed = 0;
   g_missedSpikeState.reentryArmed = false;
   g_missedSpikeState.symbol = symbol;
   
   Print("[MSR] Spike manqué enregistré | ", symbol, " | Direction: ",
         (direction > 0 ? "BUY" : "SELL"), " | Attente ", MissedSpikeWaitBars, " bougies");
}

//+------------------------------------------------------------------+
//| Vérifier si réentrée autorisée                                    |
//+------------------------------------------------------------------+
bool SMC_MSR_CanReentry(const string symbol, const int direction)
{
   // Pas de spike manqué en cours
   if(g_missedSpikeState.missedDirection == 0)
      return false;
   
   // Mauvais symbole
   if(g_missedSpikeState.symbol != symbol)
      return false;
   
   // Direction opposée
   if(g_missedSpikeState.missedDirection != direction)
      return false;
   
   // Réentrée pas encore armée
   if(!g_missedSpikeState.reentryArmed)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Réinitialiser après réentrée réussie                             |
//+------------------------------------------------------------------+
void SMC_MSR_ResetAfterReentry()
{
   Print("[MSR] Réentrée réussie → reset état");
   ZeroMemory(g_missedSpikeState);
   g_missedSpikeState.missedDirection = 0;
}

//+------------------------------------------------------------------+
//| Obtenir l'état pour diagnostic                                   |
//+------------------------------------------------------------------+
string SMC_MSR_GetState()
{
   if(g_missedSpikeState.missedDirection == 0)
      return "Aucun spike manqué";
   
   string dir = (g_missedSpikeState.missedDirection > 0) ? "BUY" : "SELL";
   string armed = g_missedSpikeState.reentryArmed ? "ARMÉ" : "EN ATTENTE";
   
   return StringFormat("Missed: %s | Bars: %d/%d | %s", 
                      dir, 
                      g_missedSpikeState.barsSinceMissed, 
                      MissedSpikeWaitBars,
                      armed);
}
