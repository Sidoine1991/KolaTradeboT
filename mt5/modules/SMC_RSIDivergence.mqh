//+------------------------------------------------------------------+
//| SMC_RSIDivergence.mqh - RSI Divergence Spike Anticipation           |
//| Stratégie ICT: divergence RSI = anticipation de spike               |
//| Basé sur recherche: divergence RSI = signal haute probabilité         |
//+------------------------------------------------------------------+
#ifndef SMC_RSI_DIVERGENCE_MQH
#define SMC_RSI_DIVERGENCE_MQH

struct SMC_RSIDivergenceState
{
   bool     hasBullishDivergence;  // prix plus bas, RSI plus haut
   bool     hasBearishDivergence;  // prix plus haut, RSI plus bas
   double   divergenceStrength;  // 0-100
   datetime lastDetection;
};

SMC_RSIDivergenceState g_rsiDivergence = {false, false, 0.0, 0};

//+------------------------------------------------------------------+
//| Initialiser l'état de divergence RSI                                |
//+------------------------------------------------------------------+
void SMC_RD_Init()
{
   ZeroMemory(g_rsiDivergence);
}

//+------------------------------------------------------------------+
//| Détecter la divergence RSI                                          |
//+------------------------------------------------------------------+
bool SMC_RD_HasRSIDivergence(const string symbol, const int dirSign)
{
   int h = iRSI(symbol, PERIOD_M1, 14, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return false;
   
   double rsiBuf[];
   ArraySetAsSeries(rsiBuf, true);
   if(CopyBuffer(h, 0, 0, 10, rsiBuf) < 10)
   {
      IndicatorRelease(h);
      return false;
   }
   
   MqlRates price[];
   ArraySetAsSeries(price, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 10, price) < 10)
   {
      IndicatorRelease(h);
      return false;
   }
   
   // Divergence haussière: prix fait plus bas, RSI fait plus haut
   bool bullishDiv = (price[0].close < price[4].close && rsiBuf[0] > rsiBuf[4]);
   // Divergence baissière: prix fait plus haut, RSI fait plus bas
   bool bearishDiv = (price[0].close > price[4].close && rsiBuf[0] < rsiBuf[4]);
   
   // Calculer la force de la divergence
   double priceChange = MathAbs(price[0].close - price[4].close);
   double rsiChange = MathAbs(rsiBuf[0] - rsiBuf[4]);
   double strength = (rsiChange / (priceChange + 0.001)) * 10;
   strength = MathMin(100, MathMax(0, strength));
   
   // Mettre à jour l'état
   g_rsiDivergence.hasBullishDivergence = bullishDiv;
   g_rsiDivergence.hasBearishDivergence = bearishDiv;
   g_rsiDivergence.divergenceStrength = strength;
   g_rsiDivergence.lastDetection = TimeCurrent();
   
   IndicatorRelease(h);
   
   // Retourner selon la direction demandée
   if(dirSign == 1 && bullishDiv)
   {
      static datetime s_log = 0;
      if(TimeCurrent() - s_log >= 30)
      {
         s_log = TimeCurrent();
         Print("[RD] Divergence haussière détectée: force=", DoubleToString(strength, 1));
      }
      return true;
   }
   if(dirSign == -1 && bearishDiv)
   {
      static datetime s_log = 0;
      if(TimeCurrent() - s_log >= 30)
      {
         s_log = TimeCurrent();
         Print("[RD] Divergence baissière détectée: force=", DoubleToString(strength, 1));
      }
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Obtenir la force de la divergence (0-100)                            |
//+------------------------------------------------------------------+
double SMC_RD_GetDivergenceStrength()
{
   return g_rsiDivergence.divergenceStrength;
}

//+------------------------------------------------------------------+
//| Obtenir le type de divergence actuelle                               |
//+------------------------------------------------------------------+
int SMC_RD_GetDivergenceType()
{
   if(g_rsiDivergence.hasBullishDivergence) return 1;  // haussière
   if(g_rsiDivergence.hasBearishDivergence) return -1; // baissière
   return 0;  // aucune
}

//+------------------------------------------------------------------+
//| Augmenter la confiance si divergence présente                         |
//+------------------------------------------------------------------+
double SMC_RD_GetConfidenceBonus()
{
   if(g_rsiDivergence.divergenceStrength < 30) return 0.0;
   
   // Bonus de confiance selon la force
   return g_rsiDivergence.divergenceStrength * 0.15;  // max 15% de bonus
}

//+------------------------------------------------------------------+
//| Permettre une taille de position plus grande avec divergence           |
//+------------------------------------------------------------------+
double SMC_RD_GetPositionSizeMultiplier()
{
   if(g_rsiDivergence.divergenceStrength < 50) return 1.0;
   
   // Augmenter la position si divergence forte
   if(g_rsiDivergence.divergenceStrength > 70) return 1.3;
   if(g_rsiDivergence.divergenceStrength > 50) return 1.15;
   
   return 1.0;
}

#endif // SMC_RSI_DIVERGENCE_MQH
