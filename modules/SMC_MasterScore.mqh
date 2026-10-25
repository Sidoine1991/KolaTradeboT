//+------------------------------------------------------------------+
//| SMC_MasterScore.mqh — God Mode quality score                    |
//| Fusionne TOUS les filtres en un score unique 0-100.             |
//| Un trade n'est autorisé que si score > MasterScoreMinThreshold   |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Forward declarations from main EA                                |
//+------------------------------------------------------------------+
int    SMC_ComputePropiceScore();
double ComputeSetupScore(const string direction);

//+------------------------------------------------------------------+
//| Extern globals from main EA                                      |
//+------------------------------------------------------------------+
extern int    g_smcGomVerdictNum;
extern string g_smcGomVerdict;
extern double g_lastAIConfidence;
extern double g_lastEntryProbability;

//+------------------------------------------------------------------+
//| Extern globals from other modules                                |
//+------------------------------------------------------------------+
extern double g_regimeScore;

//+------------------------------------------------------------------+
//| Configuration                                                    |
//+------------------------------------------------------------------+
bool   ExtUseMasterScore       = true;     // Activer le master score
double ExtMasterScoreMin       = 85.0;     // Seuil minimum (0-100)
bool   ExtMasterScoreLog       = false;    // Log détaillé du score

//+------------------------------------------------------------------+
//| Score components structure                                       |
//+------------------------------------------------------------------+
struct SMC_MasterScoreComponents
{
   double regimeScore;      // 0-100 Régime de marché
   double sessionScore;     // 0-100 Qualité de session
   double mtfScore;         // 0-100 Alignment MTF
   double propiceScore;     // 0-100 Score propice existant
   double gomScore;         // 0-100 GOM verdict
   double aiScore;          // 0-100 Confiance IA
   double probabilityScore; // 0-100 Probability gate
   double setupScore;       // 0-100 Setup quality
   double total;            // 0-100 Score final pondéré
   bool   perfectBypass;    // PERFECT bypass activé ?
};
SMC_MasterScoreComponents g_masterScore;

//+------------------------------------------------------------------+
//| Weight configuration                                             |
//+------------------------------------------------------------------+
double g_masterWeights[8] = {
   0.20,  // regime     — 20%
   0.10,  // session    — 10%
   0.20,  // mtf        — 20%
   0.15,  // propice    — 15%
   0.10,  // gom        — 10%
   0.10,  // ai         — 10%
   0.10,  // probability— 10%
   0.05   // setup      — 5%
};

//+------------------------------------------------------------------+
//| Globals from main EA (declared in SMC_Universal.mq5 if needed)  |
//+------------------------------------------------------------------+
double g_masterPropiceScore = 50.0;

//+------------------------------------------------------------------+
//| Calculate individual component scores                            |
//+------------------------------------------------------------------+
void SMC_CalcMasterScore(const string symbol, const int dirSign)
{
   ZeroMemory(g_masterScore);

   // 1. Regime score (from MarketIntelligence)
   if(ExtUseRegimeFilter)
   {
      g_masterScore.regimeScore = g_regimeScore;
   }
   else
   {
      g_masterScore.regimeScore = 100.0;
   }

   // 2. Session quality
   if(ExtUseSessionQuality)
   {
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);
      g_masterScore.sessionScore = SMC_GetSessionQuality(symbol, dt.hour);
   }
   else
   {
      g_masterScore.sessionScore = 100.0;
   }

   // 3. MTF alignment
   double h4s, h1s, m15s;
   SMC_GetMTFAlignment(symbol, dirSign, h4s, h1s, m15s);
   g_masterScore.mtfScore = (h4s + h1s + m15s) / 3.0;

   // 4. Propice score (from existing system)
   int propRaw = SMC_ComputePropiceScore();
   g_masterPropiceScore = (double)propRaw;
   g_masterScore.propiceScore = (double)propRaw;

   // 5. GOM verdict score
   int gomVn = g_smcGomVerdictNum;
   string gomVs = g_smcGomVerdict;
   if(gomVs == "PERFECT")          g_masterScore.gomScore = 100.0;
   else if(gomVn > 0 || gomVn < 0) g_masterScore.gomScore = 80.0;
   else                            g_masterScore.gomScore = 0.0;

   // 6. AI confidence
   g_masterScore.aiScore = g_lastAIConfidence * 100.0;  // 0.0-1.0 -> 0-100

   // 7. Probability gate
   g_masterScore.probabilityScore = g_lastEntryProbability;

   // 8. Setup score (calculated fresh)
   string action = (dirSign == 1) ? "BUY" : "SELL";
   g_masterScore.setupScore = ComputeSetupScore(action);

   // --- Calcul pondéré ---
   double weightedSum = 0;
   double weightTotal = 0;

   double comps[8] = {
      g_masterScore.regimeScore,
      g_masterScore.sessionScore,
      g_masterScore.mtfScore,
      g_masterScore.propiceScore,
      g_masterScore.gomScore,
      g_masterScore.aiScore,
      g_masterScore.probabilityScore,
      g_masterScore.setupScore
   };

   for(int i = 0; i < 8; i++)
   {
      if(comps[i] >= 0) // valid component
      {
         weightedSum += comps[i] * g_masterWeights[i];
         weightTotal += g_masterWeights[i];
      }
   }

   if(weightTotal > 0)
      g_masterScore.total = weightedSum / weightTotal;
   else
      g_masterScore.total = 100.0;

   // --- Perfect GOM bypass: si PERFECT, on peut bypasser le seuil ---
   if(g_smcGomVerdict == "PERFECT")
   {
      g_masterScore.perfectBypass = true;
      // PERFECT bypass: le seuil est réduit de 20 points
      // (car PERFECT est un signal très fort)
   }
   else
   {
      g_masterScore.perfectBypass = false;
   }
}

//+------------------------------------------------------------------+
//| Check if master score allows trade                               |
//+------------------------------------------------------------------+
bool SMC_MasterScoreAllowsTrade(const string symbol, const int dirSign)
{
   if(!ExtUseMasterScore) return true;

   SMC_CalcMasterScore(symbol, dirSign);

   double effectiveMin = ExtMasterScoreMin;

   // PERFECT bypass: abaisser le seuil
   if(g_masterScore.perfectBypass)
   {
      effectiveMin -= 20.0;
      if(ExtMasterScoreLog)
         Print("[MASTER] PERFECT bypass actif — seuil abaissé de ", effectiveMin + 20, " ? ", effectiveMin);
   }

   bool allowed = (g_masterScore.total >= effectiveMin);

   if(!allowed)
   {
      Print(StringFormat("[MASTER] BLOQUÉ — Score total %.1f < seuil %.1f | R=%.0f S=%.0f MTF=%.0f P=%.0f G=%.0f AI=%.0f Prob=%.0f Set=%.0f",
            g_masterScore.total, effectiveMin,
            g_masterScore.regimeScore,
            g_masterScore.sessionScore,
            g_masterScore.mtfScore,
            g_masterScore.propiceScore,
            g_masterScore.gomScore,
            g_masterScore.aiScore,
            g_masterScore.probabilityScore,
            g_masterScore.setupScore));
   }
   else
   {
      if(ExtMasterScoreLog || g_masterScore.total >= 95)
      {
         Print(StringFormat("[MASTER] ? Score %.1f ? | %s | R=%.0f S=%.0f MTF=%.0f P=%.0f G=%.0f AI=%.0f",
               g_masterScore.total, (g_masterScore.perfectBypass ? "PERFECT" : ""),
               g_masterScore.regimeScore,
               g_masterScore.sessionScore,
               g_masterScore.mtfScore,
               g_masterScore.propiceScore,
               g_masterScore.gomScore,
               g_masterScore.aiScore));
      }
   }

   return allowed;
}

//+------------------------------------------------------------------+
//| Get master score for dashboard                                   |
//+------------------------------------------------------------------+
double SMC_GetMasterScore()
{
   return g_masterScore.total;
}

//+------------------------------------------------------------------+
//| Init module                                                      |
//+------------------------------------------------------------------+
void SMC_InitMasterScore()
{
   ZeroMemory(g_masterScore);
   g_masterScore.total = 100.0;
   Print("[SMC-MasterScore] Module initialisé | Seuil=", ExtMasterScoreMin, "% | ", ExtUseMasterScore ? "ACTIF" : "INACTIF");
}
//+------------------------------------------------------------------+
