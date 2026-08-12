//+------------------------------------------------------------------+
//| SMC_TighteningRange.mqh - Tightening Range Pattern Detection          |
//| Détection de compression avant spike pour éviter entrées risquées   |
//| Basé sur recherche: compression = stockage de volatilité           |
//+------------------------------------------------------------------+
#ifndef SMC_TIGHTENING_RANGE_MQH
#define SMC_TIGHTENING_RANGE_MQH

struct SMC_TighteningRangeState
{
   bool     isTightening;
   double   compressionRatio;  // ratio corps actuel / corps moyen
   int      decreasingBars;   // nombre de bougies avec corps décroissant
   double   avgBodySize;
   double   currentBodySize;
   datetime lastDetection;
};

SMC_TighteningRangeState g_tighteningRange = {false, 0.0, 0, 0.0, 0.0, 0};

//+------------------------------------------------------------------+
//| Initialiser l'état de compression                                   |
//+------------------------------------------------------------------+
void SMC_TR_Init()
{
   ZeroMemory(g_tighteningRange);
}

//+------------------------------------------------------------------+
//| Détecter si le marché est en phase de compression (tightening)      |
//+------------------------------------------------------------------+
bool SMC_TR_IsTighteningRange(const string symbol, const int lookbackBars = 8)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, lookbackBars, r) < lookbackBars) return false;
   
   double bodies[];
   for(int i = 0; i < lookbackBars; i++)
   {
      int sz = ArraySize(bodies);
      ArrayResize(bodies, sz + 1);
      bodies[sz] = MathAbs(r[i].close - r[i].open);
   }
   
   // Calculer la taille moyenne des corps
   double total = 0;
   for(int i = 0; i < lookbackBars; i++)
      total += bodies[i];
   double avgBody = total / lookbackBars;
   
   // Vérifier décroissance des corps
   int decreasingCount = 0;
   for(int i = 1; i < lookbackBars; i++)
   {
      if(bodies[i] < bodies[i-1]) decreasingCount++;
   }
   
   // Calculer le ratio de compression
   double currentBody = bodies[0];
   double compressionRatio = (avgBody > 0) ? currentBody / avgBody : 1.0;
   
   // Mettre à jour l'état
   g_tighteningRange.avgBodySize = avgBody;
   g_tighteningRange.currentBodySize = currentBody;
   g_tighteningRange.decreasingBars = decreasingCount;
   g_tighteningRange.compressionRatio = compressionRatio;
   g_tighteningRange.lastDetection = TimeCurrent();
   
   // Condition: > 70% des bougies ont des corps décroissants
   bool isTightening = (decreasingCount >= (lookbackBars * 0.7));
   
   g_tighteningRange.isTightening = isTightening;
   
   if(isTightening)
   {
      static datetime s_log = 0;
      if(TimeCurrent() - s_log >= 30)
      {
         s_log = TimeCurrent();
         Print("[TR] Compression détectée: ", decreasingCount, "/", lookbackBars, 
               " bougies décroissantes | ratio=", DoubleToString(compressionRatio, 3));
      }
   }
   
   return isTightening;
}

//+------------------------------------------------------------------+
//| Obtenir le niveau de risque de compression (0-100)                  |
//+------------------------------------------------------------------+
double SMC_TR_GetCompressionRiskLevel()
{
   if(!g_tighteningRange.isTightening) return 0.0;
   
   // Plus le ratio est bas, plus le risque est élevé
   double risk = (1.0 - g_tighteningRange.compressionRatio) * 100;
   return MathMax(0, MathMin(100, risk));
}

//+------------------------------------------------------------------+
//| Obtenir le nombre de bougies avec corps décroissants                  |
//+------------------------------------------------------------------+
int SMC_TR_GetDecreasingBarsCount()
{
   return g_tighteningRange.decreasingBars;
}

//+------------------------------------------------------------------+
//| Vérifier si l'entrée doit être bloquée due à compression            |
//+------------------------------------------------------------------+
bool SMC_TR_ShouldBlockEntry(const double riskThreshold = 60.0)
{
   if(!g_tighteningRange.isTightening) return false;
   
   double riskLevel = SMC_TR_GetCompressionRiskLevel();
   return (riskLevel >= riskThreshold);
}

//+------------------------------------------------------------------+
//| Réduire la taille de position selon le niveau de compression        |
//+------------------------------------------------------------------+
double SMC_TR_GetPositionSizeMultiplier()
{
   if(!g_tighteningRange.isTightening) return 1.0;
   
   double riskLevel = SMC_TR_GetCompressionRiskLevel();
   
   // Réduire progressivement selon le risque
   if(riskLevel > 80) return 0.25;  // 25% de la taille normale
   if(riskLevel > 60) return 0.50;  // 50% de la taille normale
   if(riskLevel > 40) return 0.75;  // 75% de la taille normale
   
   return 1.0;
}

#endif // SMC_TIGHTENING_RANGE_MQH
