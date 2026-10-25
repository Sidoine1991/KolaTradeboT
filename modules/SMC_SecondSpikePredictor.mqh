//+------------------------------------------------------------------+
//| SMC_SecondSpikePredictor.mqh - Prédiction et gestion du second spike   |
//| Au lieu de fermer au premier spike, prédit et attend le second spike   |
//| Basé sur recherche: spikes clusterisent souvent en chaînes (2-3)       |
//+------------------------------------------------------------------+
#ifndef SMC_SECOND_SPIKE_PREDICTOR_MQH
#define SMC_SECOND_SPIKE_PREDICTOR_MQH

struct SMC_SecondSpikePrediction
{
   bool     firstSpikeCaptured;
   datetime firstSpikeTime;
   double   firstSpikeEntry;
   double   firstSpikeExit;
   double   firstSpikeProfit;
   int      firstSpikeDirection;  // +1 BUY, -1 SELL
   bool     waitingSecondSpike;
   double   secondSpikeProbability;  // 0-100
   int      barsSinceFirstSpike;
   double   maxProfitSinceFirstSpike;
   double   currentProfit;
   bool     secondSpikeDetected;
   datetime secondSpikeTime;
   int      maxWaitBars;  // nombre max de bougies à attendre
};

SMC_SecondSpikePrediction g_secondSpikePred = {false, 0, 0, 0, 0, 0, false, 0, 0, 0, 0, false, 0, 15};

//+------------------------------------------------------------------+
//| Initialiser le système de prédiction du second spike                   |
//+------------------------------------------------------------------+
void SMC_SSP_Init()
{
   ZeroMemory(g_secondSpikePred);
   g_secondSpikePred.maxWaitBars = 15;  // 15 bougies M1 max d'attente
}

//+------------------------------------------------------------------+
//| Enregistrer la capture d'un premier spike                            |
//+------------------------------------------------------------------+
void SMC_SSP_RegisterFirstSpike(const double entry, const double exit, const int direction)
{
   g_secondSpikePred.firstSpikeCaptured = true;
   g_secondSpikePred.firstSpikeTime = TimeCurrent();
   g_secondSpikePred.firstSpikeEntry = entry;
   g_secondSpikePred.firstSpikeExit = exit;
   g_secondSpikePred.firstSpikeProfit = (direction > 0) ? (exit - entry) : (entry - exit);
   g_secondSpikePred.firstSpikeDirection = direction;
   g_secondSpikePred.barsSinceFirstSpike = 0;
   g_secondSpikePred.maxProfitSinceFirstSpike = g_secondSpikePred.firstSpikeProfit;
   g_secondSpikePred.currentProfit = g_secondSpikePred.firstSpikeProfit;
   
   Print("[SSP] Premier spike capturé: ", direction > 0 ? "BUY" : "SELL", 
         " | profit=", DoubleToString(g_secondSpikePred.firstSpikeProfit, 2),
         " | attente second spike...");
}

//+------------------------------------------------------------------+
//| Calculer la probabilité d'un second spike                           |
//+------------------------------------------------------------------+
double SMC_SSP_CalcSecondSpikeProb(const string symbol)
{
   if(!g_secondSpikePred.firstSpikeCaptured) return 0.0;
   
   double prob = 0.0;
   
   // 1. Z-score ATR (si élevé = forte probabilité de continuation)
   double z = SMC_ComputeATRZScore(SpikeChainATRLookback);
   if(z > 2.5) prob += 30;
   else if(z > 2.0) prob += 20;
   else if(z > 1.5) prob += 10;
   
   // 2. Persistance directionnelle (si forte = probabilité élevée)
   int dirSign = g_secondSpikePred.firstSpikeDirection;
   double momentum = SMC_PE_GetCompositeScore(symbol, dirSign);
   if(momentum > 70) prob += 25;
   else if(momentum > 50) prob += 15;
   else if(momentum > 30) prob += 5;
   
   // 3. Temps écoulé (si court = probabilité élevée)
   if(g_secondSpikePred.barsSinceFirstSpike <= 3) prob += 20;
   else if(g_secondSpikePred.barsSinceFirstSpike <= 5) prob += 10;
   else if(g_secondSpikePred.barsSinceFirstSpike <= 8) prob += 5;
   
   // 4. Profit du premier spike (si modéré = probabilité élevée)
   double profitPct = MathAbs(g_secondSpikePred.firstSpikeProfit) / 
                      (g_secondSpikePred.firstSpikeEntry + 0.001) * 100;
   if(profitPct > 0.5 && profitPct < 2.0) prob += 15;  // profit modéré
   else if(profitPct >= 2.0 && profitPct < 5.0) prob += 10;  // profit moyen
   else if(profitPct >= 5.0) prob -= 10;  // profit élevé = moins probable
   
   // 5. État de la chaîne de spikes (si active = probabilité élevée)
   if(g_spikeChainState == SPIKE_STATE_CHAIN_ACTIVE) prob += 20;
   else if(g_spikeChainState == SPIKE_STATE_EXHAUSTION) prob += 10;
   
   // 6. Imminence de spike (si élevée = probabilité élevée)
   if(g_smcGomImminencePct > 60) prob += 15;
   else if(g_smcGomImminencePct > 40) prob += 8;
   
   return MathMax(0, MathMin(100, prob));
}

//+------------------------------------------------------------------+
//| Mettre à jour l'état du second spike (à appeler chaque tick)           |
//+------------------------------------------------------------------+
void SMC_SSP_Update(const string symbol, const double currentPrice)
{
   if(!g_secondSpikePred.firstSpikeCaptured) return;
   
   g_secondSpikePred.barsSinceFirstSpike++;
   
   // Calculer le profit actuel
   if(g_secondSpikePred.firstSpikeDirection > 0)
      g_secondSpikePred.currentProfit = currentPrice - g_secondSpikePred.firstSpikeEntry;
   else
      g_secondSpikePred.currentProfit = g_secondSpikePred.firstSpikeEntry - currentPrice;
   
   // Mettre à jour le profit max
   if(g_secondSpikePred.currentProfit > g_secondSpikePred.maxProfitSinceFirstSpike)
      g_secondSpikePred.maxProfitSinceFirstSpike = g_secondSpikePred.currentProfit;
   
   // Calculer la probabilité de second spike
   g_secondSpikePred.secondSpikeProbability = SMC_SSP_CalcSecondSpikeProb(symbol);
   
   // Décider si on attend le second spike
   if(g_secondSpikePred.secondSpikeProbability >= 60 && 
      g_secondSpikePred.barsSinceFirstSpike <= g_secondSpikePred.maxWaitBars)
   {
      g_secondSpikePred.waitingSecondSpike = true;
   }
   else
   {
      g_secondSpikePred.waitingSecondSpike = false;
   }
}

//+------------------------------------------------------------------+
//| Vérifier si on doit attendre le second spike (bloquer fermeture)     |
//+------------------------------------------------------------------+
bool SMC_SSP_ShouldWaitSecondSpike()
{
   if(!g_secondSpikePred.firstSpikeCaptured) return false;
   
   // Conditions pour arrêter d'attendre
   if(g_secondSpikePred.barsSinceFirstSpike > g_secondSpikePred.maxWaitBars)
   {
      Print("[SSP] Timeout - arrêt attente après ", g_secondSpikePred.maxWaitBars, " bougies");
      return false;
   }
   
   // Si profit devient négatif (drawdown), arrêter d'attendre
   if(g_secondSpikePred.currentProfit < 0)
   {
      Print("[SSP] Drawdown détecté - arrêt attente | profit=", 
            DoubleToString(g_secondSpikePred.currentProfit, 2));
      return false;
   }
   
   // Si probabilité trop basse, arrêter d'attendre
   if(g_secondSpikePred.secondSpikeProbability < 50)
   {
      return false;
   }
   
   return g_secondSpikePred.waitingSecondSpike;
}

//+------------------------------------------------------------------+
//| Enregistrer la détection d'un second spike                          |
//+------------------------------------------------------------------+
void SMC_SSP_RegisterSecondSpike(const double price)
{
   g_secondSpikePred.secondSpikeDetected = true;
   g_secondSpikePred.secondSpikeTime = TimeCurrent();
   
   Print("[SSP] Second spike détecté @ ", DoubleToString(price, 2),
         " | bars depuis premier: ", g_secondSpikePred.barsSinceFirstSpike,
         " | profit total estimé: ", DoubleToString(g_secondSpikePred.currentProfit, 2));
}

//+------------------------------------------------------------------+
//| Réinitialiser après fermeture de position                           |
//+------------------------------------------------------------------+
void SMC_SSP_Reset()
{
   Print("[SSP] Reset après fermeture position");
   SMC_SSP_Init();
}

//+------------------------------------------------------------------+
//| Obtenir le profit actuel depuis le premier spike                       |
//+------------------------------------------------------------------+
double SMC_SSP_GetCurrentProfit()
{
   return g_secondSpikePred.currentProfit;
}

//+------------------------------------------------------------------+
//| Obtenir la probabilité de second spike                               |
//+------------------------------------------------------------------+
double SMC_SSP_GetSecondSpikeProb()
{
   return g_secondSpikePred.secondSpikeProbability;
}

//+------------------------------------------------------------------+
//| Obtenir le nombre de bougies depuis le premier spike                  |
//+------------------------------------------------------------------+
int SMC_SSP_GetBarsSinceFirstSpike()
{
   return g_secondSpikePred.barsSinceFirstSpike;
}

//+------------------------------------------------------------------+
//| Ajuster le TP pour le second spike (plus agressif)                     |
//+------------------------------------------------------------------+
double SMC_SSP_GetSecondSpikeTPMult()
{
   // Pour le second spike, on peut viser un TP plus agressif
   // car on capture déjà le profit du premier spike
   return 1.5;  // 1.5x le TP normal
}

//+------------------------------------------------------------------+
//| Afficher l'état du système (debug)                                    |
//+------------------------------------------------------------------+
void SMC_SSP_PrintState()
{
   Print("=== SECOND SPIKE PREDICTOR STATE ===");
   Print("First spike captured: ", g_secondSpikePred.firstSpikeCaptured ? "YES" : "NO");
   if(g_secondSpikePred.firstSpikeCaptured)
   {
      Print("Bars since first: ", g_secondSpikePred.barsSinceFirstSpike, "/", g_secondSpikePred.maxWaitBars);
      Print("Current profit: ", DoubleToString(g_secondSpikePred.currentProfit, 2));
      Print("Max profit: ", DoubleToString(g_secondSpikePred.maxProfitSinceFirstSpike, 2));
      Print("Second spike prob: ", DoubleToString(g_secondSpikePred.secondSpikeProbability, 1), "%");
      Print("Waiting second spike: ", g_secondSpikePred.waitingSecondSpike ? "YES" : "NO");
      Print("Second spike detected: ", g_secondSpikePred.secondSpikeDetected ? "YES" : "NO");
   }
   Print("=====================================");
}

#endif // SMC_SECOND_SPIKE_PREDICTOR_MQH
