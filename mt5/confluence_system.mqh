//+------------------------------------------------------------------+
//| Système de Score de Confluence (Recommandation Audit)            |
//| Remplace les stratégies multiples par un système unifié        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calcule le score de confluence pour un signal                  |
//| Score total = SMC (50) + Tendance MTF (20) + Volume (15) + R:R (10) + Patterns (5) |
//| Seuil minimum recommandé: 75 points                            |
//+------------------------------------------------------------------+
ConfluenceScore CalculateConfluenceScore(string symbol, ENUM_TIMEFRAMES tf, int direction, double entryPrice, double sl, double tp)
{
   ConfluenceScore score = {0};
   score.direction = direction;
   score.isValid = false;
   
   // 1. Score SMC (Order Block) - Base 50 points
   int smcDirection = 0;
   double smcQuality = CheckSMCStrategy(symbol, tf, smcDirection);
   if(smcQuality > 0 && smcDirection == direction)
   {
      score.smcScore = 50.0; // Base score pour OB de qualité
      score.reason += "SMC OB détecté; ";
   }
   else if(smcQuality > 0)
   {
      score.smcScore = 25.0; // Score réduit si direction différente
      score.reason += "SMC OB mais direction différente; ";
   }
   
   // 2. Score Tendance MTF alignée - Max 20 points
   if(CheckTrendAlignment(symbol, tf, direction))
   {
      score.trendScore = 20.0;
      score.reason += "Tendance MTF alignée; ";
   }
   else
   {
      // Vérifier alignement partiel
      int trendM5 = GetTrendFromEMAForSymbol(symbol, PERIOD_M5);
      int trendM15 = GetTrendFromEMAForSymbol(symbol, PERIOD_M15);
      if((trendM5 == direction && trendM5 != 0) || (trendM15 == direction && trendM15 != 0))
      {
         score.trendScore = 10.0; // Alignement partiel
         score.reason += "Tendance partiellement alignée; ";
      }
   }
   
   // 3. Score Volume en augmentation - Max 15 points
   if(CheckVolumeIncrease(symbol, tf))
   {
      score.volumeScore = 15.0;
      score.reason += "Volume en augmentation; ";
   }
   else
   {
      score.volumeScore = 5.0; // Volume normal
   }
   
   // 4. Score Ratio Risque/Récompense - Max 10 points
   if(sl > 0 && tp > 0 && entryPrice > 0)
   {
      double risk = MathAbs(entryPrice - sl);
      double reward = MathAbs(tp - entryPrice);
      if(risk > 0)
      {
         double rrRatio = reward / risk;
         if(rrRatio >= 2.5)
         {
            score.riskRewardScore = 10.0;
            score.reason += StringFormat("R:R excellent (%.2f); ", rrRatio);
         }
         else if(rrRatio >= 2.0)
         {
            score.riskRewardScore = 7.0;
            score.reason += StringFormat("R:R bon (%.2f); ", rrRatio);
         }
         else if(rrRatio >= 1.5)
         {
            score.riskRewardScore = 5.0;
            score.reason += StringFormat("R:R acceptable (%.2f); ", rrRatio);
         }
      }
   }
   
   // 5. Score Patterns additionnels - Max 5 points
   // Détection de patterns de chandelier, FVG, etc.
   int fvg = DetectFVG(tf);
   if(fvg != 0 && ((fvg > 0 && direction > 0) || (fvg < 0 && direction < 0)))
   {
      score.patternScore = 5.0;
      score.reason += "FVG détecté; ";
   }
   
   // Calcul du score total
   score.totalScore = score.smcScore + score.trendScore + score.volumeScore + 
                      score.riskRewardScore + score.patternScore;
   
   // Validation: Score minimum recommandé = 75
   score.isValid = (score.totalScore >= 75.0);
   
   if(!score.isValid)
   {
      score.reason += StringFormat("Score insuffisant (%.1f < 75)", score.totalScore);
   }
   
   return score;
}

//+------------------------------------------------------------------+
//| Vérifie la stratégie SMC (Order Block)                          |
//| Retourne la qualité de l'OB (0-100) et la direction             |
//+------------------------------------------------------------------+
double CheckSMCStrategy(string symbol, ENUM_TIMEFRAMES tf, int &direction)
{
   direction = 0;
   if(!InpEnableSMC || !InpUseSMCForTrading) return 0.0;
   
   // Détecter les Order Blocks
   OBZone allOBs[];
   int obCount = DetectOrderBlocksAdvanced(symbol, tf, InpMaxOBLookback, allOBs);
   
   if(obCount == 0) return 0.0;
   
   // Trouver l'OB le plus récent et de meilleure qualité
   double bestQuality = 0.0;
   int bestDirection = 0;
   
   for(int i = 0; i < obCount; i++)
   {
      // Vérifier si l'OB est récent (dans les 2 dernières bougies)
      MqlRates rates[];
      if(CopyRates(symbol, tf, 0, 10, rates) < 10) continue;
      ArraySetAsSeries(rates, true);
      
      datetime obTime = allOBs[i].time1;
      int obBarIndex = -1;
      for(int j = 0; j < 10; j++)
      {
         if(rates[j].time == obTime)
         {
            obBarIndex = j;
            break;
         }
      }
      
      if(obBarIndex < 1 || obBarIndex > 2) continue; // OB trop ancien
      
      double confidenceScore = 0;
      double quality = ValidateOrderBlockQuality(symbol, tf, allOBs[i], confidenceScore);
      
      if(quality > bestQuality)
      {
         bestQuality = quality;
         bestDirection = allOBs[i].bullish ? 1 : -1;
      }
   }
   
   direction = bestDirection;
   return bestQuality;
}

//+------------------------------------------------------------------+
//| Vérifie la stratégie de rejet de canal                          |
//| Retourne la force du signal (0-100) et la direction             |
//+------------------------------------------------------------------+
double CheckChannelRejectionStrategy(string symbol, ENUM_TIMEFRAMES tf, int &direction)
{
   direction = 0;
   if(!InpEnableChannelRejection || !InpUseChannelRejectionForTrading) return 0.0;
   
   // Cette stratégie est désactivée par défaut selon audit
   // Retourner 0 pour ne pas contribuer au score
   return 0.0;
}

//+------------------------------------------------------------------+
//| Vérifie la stratégie de proximité EMA                           |
//| Retourne la force du signal (0-100) et la direction             |
//+------------------------------------------------------------------+
double CheckEMAPximityStrategy(string symbol, ENUM_TIMEFRAMES tf, int &direction)
{
   direction = 0;
   if(!InpEnableEMAProximityEntries) return 0.0;
   
   // Cette stratégie est désactivée par défaut selon audit
   // Retourner 0 pour ne pas contribuer au score
   return 0.0;
}

//+------------------------------------------------------------------+
//| Vérifie l'alignement de la tendance multi-timeframe             |
//+------------------------------------------------------------------+
bool CheckTrendAlignment(string symbol, ENUM_TIMEFRAMES tf, int direction)
{
   if(!InpUseMultiTimeframeConf) return false;
   
   // Vérifier les timeframes de confirmation
   int trend1 = GetTrendFromEMAForSymbol(symbol, InpConfTimeframe1);
   int trend2 = GetTrendFromEMAForSymbol(symbol, InpConfTimeframe2);
   
   // Les deux timeframes doivent être alignés avec la direction
   return (trend1 == direction && trend2 == direction && direction != 0);
}

//+------------------------------------------------------------------+
//| Vérifie si le volume est en augmentation                        |
//+------------------------------------------------------------------+
bool CheckVolumeIncrease(string symbol, ENUM_TIMEFRAMES tf)
{
   long currentVolume = iVolume(symbol, tf, 0);
   long avgVolume = 0;
   
   // Calculer la moyenne des 20 dernières bougies
   for(int i = 1; i <= 20; i++)
   {
      avgVolume += iVolume(symbol, tf, i);
   }
   avgVolume /= 20;
   
   // Volume en augmentation si > 1.5x la moyenne
   return (avgVolume > 0 && currentVolume > avgVolume * 1.5);
}

