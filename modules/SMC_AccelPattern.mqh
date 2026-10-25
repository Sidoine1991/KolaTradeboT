//+------------------------------------------------------------------+
//| SMC_AccelPattern.mqh - Acceleration Pattern Detection                 |
//| Détection d'accélération du creep avant spike                        |
//| Basé sur recherche: accélération 50-200 ticks avant spike           |
//+------------------------------------------------------------------+
#ifndef SMC_ACCEL_PATTERN_MQH
#define SMC_ACCEL_PATTERN_MQH

struct SMC_AccelPatternState
{
   bool     isAccelerating;
   double   speed1;  // vitesse période 1 (récent)
   double   speed2;  // vitesse période 2 (moyen)
   double   speed3;  // vitesse période 3 (ancien)
   double   accelRatio;  // ratio d'accélération
   datetime lastDetection;
};

SMC_AccelPatternState g_accelPattern = {false, 0.0, 0.0, 0.0, 0.0, 0};

//+------------------------------------------------------------------+
//| Initialiser l'état d'accélération                                    |
//+------------------------------------------------------------------+
void SMC_AP_Init()
{
   ZeroMemory(g_accelPattern);
}

//+------------------------------------------------------------------+
//| Détecter si le marché est en phase d'accélération                    |
//+------------------------------------------------------------------+
bool SMC_AP_IsAccelerationPattern(const string symbol)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 10, r) < 10) return false;
   
   // Calculer la vitesse sur 3 périodes de 3 bougies
   double speed1 = MathAbs(r[0].close - r[3].close) / 3.0;
   double speed2 = MathAbs(r[3].close - r[6].close) / 3.0;
   double speed3 = MathAbs(r[6].close - r[9].close) / 3.0;
   
   // Éviter division par zéro
   if(speed2 <= 0.001 || speed3 <= 0.001) return false;
   
   // Calculer le ratio d'accélération
   double accelRatio1 = speed1 / speed2;
   double accelRatio2 = speed2 / speed3;
   
   // Accélération significative: vitesse augmente de >30%
   bool isAccelerating = (accelRatio1 > 1.3 && accelRatio2 > 1.3);
   
   // Mettre à jour l'état
   g_accelPattern.speed1 = speed1;
   g_accelPattern.speed2 = speed2;
   g_accelPattern.speed3 = speed3;
   g_accelPattern.accelRatio = accelRatio1;
   g_accelPattern.lastDetection = TimeCurrent();
   g_accelPattern.isAccelerating = isAccelerating;
   
   if(isAccelerating)
   {
      static datetime s_log = 0;
      if(TimeCurrent() - s_log >= 30)
      {
         s_log = TimeCurrent();
         Print("[AP] Accélération détectée: v1=", DoubleToString(speed1, 4),
               " v2=", DoubleToString(speed2, 4), " v3=", DoubleToString(speed3, 4),
               " | ratio=", DoubleToString(accelRatio1, 2));
      }
   }
   
   return isAccelerating;
}

//+------------------------------------------------------------------+
//| Obtenir le niveau de risque d'accélération (0-100)                   |
//+------------------------------------------------------------------+
double SMC_AP_GetAccelerationRiskLevel()
{
   if(!g_accelPattern.isAccelerating) return 0.0;
   
   // Plus le ratio est élevé, plus le risque est élevé
   double risk = (g_accelPattern.accelRatio - 1.0) * 100;
   return MathMax(0, MathMin(100, risk));
}

//+------------------------------------------------------------------+
//| Vérifier si l'entrée doit être bloquée due à accélération             |
//+------------------------------------------------------------------+
bool SMC_AP_ShouldBlockEntry(const double riskThreshold = 50.0)
{
   if(!g_accelPattern.isAccelerating) return false;
   
   double riskLevel = SMC_AP_GetAccelerationRiskLevel();
   return (riskLevel >= riskThreshold);
}

//+------------------------------------------------------------------+
//| Réduire la taille de position selon le niveau d'accélération        |
//+------------------------------------------------------------------+
double SMC_AP_GetPositionSizeMultiplier()
{
   if(!g_accelPattern.isAccelerating) return 1.0;
   
   double riskLevel = SMC_AP_GetAccelerationRiskLevel();
   
   // Réduire progressivement selon le risque
   if(riskLevel > 80) return 0.25;
   if(riskLevel > 60) return 0.50;
   if(riskLevel > 40) return 0.75;
   
   return 1.0;
}

//+------------------------------------------------------------------+
//| Prendre les profits plus tôt en cas d'accélération                     |
//+------------------------------------------------------------------+
double SMC_AP_GetTakeProfitMultiplier()
{
   if(!g_accelPattern.isAccelerating) return 1.0;
   
   double riskLevel = SMC_AP_GetAccelerationRiskLevel();
   
   // Réduire les TP en cas d'accélération (prendre profits plus vite)
   if(riskLevel > 70) return 0.5;  // 50% du TP normal
   if(riskLevel > 50) return 0.7;  // 70% du TP normal
   
   return 1.0;
}

#endif // SMC_ACCEL_PATTERN_MQH
