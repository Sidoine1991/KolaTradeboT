//+------------------------------------------------------------------+
//|               Correction Predictor for Boom/Crash               |
//|                 MQL5 Advanced Correction Detection              |
//+------------------------------------------------------------------+
#property strict

//--- Paramètres de configuration
input int    MA_Period = 20;              // Période de la moyenne mobile
input double CorrectionThreshold = 0.0;   // Seuil si tu veux % (0 = MA seulement)
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input int    HistoryBars = 500;           // Nombre de bougies pour l'analyse

//--- Variables globales pour les statistiques
double MA[];
int    total_trends = 0;
int    correction_count = 0;
int    duration_sum = 0;
double correction_probabilities[100];    // Historique des probabilités
int    correction_durations[100];         // Historique des durées
int    probability_index = 0;

//--- Variables pour Hidden Markov Model
int    hidden_states[500];
double transition_matrix[2][2];
double emission_means[2][3];             // [RSI, Distance_MA, Volatility]

//+------------------------------------------------------------------+
//| Fonction principale de détection des corrections                 |
//+------------------------------------------------------------------+
void DetectHistoricalCorrections()
{
   // Réinitialiser les compteurs
   total_trends = 0;
   correction_count = 0;
   duration_sum = 0;
   probability_index = 0;
   
   // Obtenir les données MA
   if(!CopyBuffer(iMA(NULL, Timeframe, MA_Period, 0, MODE_SMA, PRICE_CLOSE), 0, 0, HistoryBars, MA))
   {
      Print("❌ Erreur - Impossible d'obtenir les données MA");
      return;
   }
   
   // Obtenir les prix de clôture
   double Close[];
   ArraySetAsSeries(Close, true);
   if(CopyClose(NULL, Timeframe, 0, HistoryBars, Close) < HistoryBars)
   {
      Print("❌ Erreur - Impossible d'obtenir les prix de clôture");
      return;
   }
   
   bool in_correction = false;
   int start_index = -1;
   
   // Parcourir l'historique pour détecter les corrections
   for(int i = HistoryBars - 1; i >= 0; i--)
   {
      double price = Close[i];
      double ma_val = MA[i];
      
      // Détecter correction si prix < MA20
      bool is_correction = (price < ma_val);
      
      // Amélioration avec RSI pour éviter les faux signaux
      double rsi_val = iRSI(NULL, Timeframe, 14, PRICE_CLOSE, i);
      if(rsi_val > 70) is_correction = true;  // Surachat = forte probabilité de correction
      if(rsi_val < 30) is_correction = false; // Survente = tendance baissière normale
      
      if(is_correction)
      {
         if(!in_correction)
         {
            start_index = i;
            in_correction = true;
         }
      }
      else
      {
         if(in_correction)
         {
            int duration = start_index - i + 1;
            duration_sum += duration;
            correction_count++;
            
            // Enregistrer la durée pour l'analyse
            if(probability_index < 100)
            {
               correction_durations[probability_index] = duration;
               probability_index++;
            }
            
            in_correction = false;
         }
         total_trends++; // Compter les tendances complètes
      }
   }
   
   // Si correction en cours jusqu'à la dernière bougie
   if(in_correction)
   {
      int duration = start_index - 0 + 1;
      duration_sum += duration;
      correction_count++;
      total_trends++;
      
      if(probability_index < 100)
      {
         correction_durations[probability_index] = duration;
         probability_index++;
      }
   }
   
   Print("📊 ANALYSE HISTORIQUE DES CORRECTIONS - ", _Symbol);
   Print("   📍 Tendances analysées: ", total_trends);
   Print("   📍 Corrections détectées: ", correction_count);
}

//+------------------------------------------------------------------+
//| Calculer la probabilité de correction                            |
//+------------------------------------------------------------------+
double CalculateCorrectionProbability()
{
   if(total_trends == 0) return 0.0;
   
   double prob = (double)correction_count / total_trends * 100;
   return prob;
}

//+------------------------------------------------------------------+
//| Calculer la durée moyenne des corrections                        |
//+------------------------------------------------------------------+
double CalculateAverageCorrectionDuration()
{
   if(correction_count == 0) return 0.0;
   
   double avg_duration = (double)duration_sum / correction_count;
   return avg_duration;
}

//+------------------------------------------------------------------+
//| Probabilité conditionnelle avec indicateurs techniques            |
//+------------------------------------------------------------------+
double CalculateConditionalProbability()
{
   double rsi = iRSI(NULL, Timeframe, 14, PRICE_CLOSE, 0);
   double atr = iATR(NULL, Timeframe, 14, 0);
   double ma_val = MA[0];
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculer la distance à la MA en ATR
   double distance_to_ma = MathAbs(price - ma_val) / atr;
   
   // Calculer la volatilité (ATR normalisé)
   double volatility = atr / price * 100;
   
   // Modèle de probabilité conditionnelle
   double rsi_factor = (rsi > 70) ? 0.8 : (rsi < 30) ? 0.2 : 0.5;
   double distance_factor = (distance_to_ma > 2.0) ? 0.7 : (distance_to_ma > 1.0) ? 0.5 : 0.3;
   double volatility_factor = (volatility > 1.0) ? 0.6 : 0.4;
   
   // Formule pondérée
   double conditional_prob = 0.4 * rsi_factor + 0.3 * distance_factor + 0.3 * volatility_factor;
   
   return conditional_prob * 100; // En pourcentage
}

//+------------------------------------------------------------------+
//| Prédire la durée actuelle de correction                          |
//+------------------------------------------------------------------+
int PredictCurrentCorrectionDuration()
{
   double rsi = iRSI(NULL, Timeframe, 14, PRICE_CLOSE, 0);
   double atr = iATR(NULL, Timeframe, 14, 0);
   double ma_val = MA[0];
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Si pas en correction, retourner 0
   if(price >= ma_val && rsi <= 70) return 0;
   
   // Prédire basé sur les indicateurs actuels
   double avg_duration = CalculateAverageCorrectionDuration();
   
   // Ajuster selon les conditions actuelles
   double adjustment = 1.0;
   if(rsi > 80) adjustment *= 1.5;      // Surachat extrême = correction plus longue
   if(rsi < 40) adjustment *= 0.7;      // Survente modérée = correction plus courte
   if(atr > avg_duration * 0.1) adjustment *= 1.2; // Haute volatilité = correction plus longue
   
   int predicted_duration = (int)(avg_duration * adjustment);
   return predicted_duration;
}

//+------------------------------------------------------------------+
//| Hidden Markov Model simplifié pour détection d'états             |
//+------------------------------------------------------------------+
void DetectHiddenStates()
{
   double rsi[], atr[], price[];
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(price, true);
   
   // Obtenir les données pour HMM
   if(CopyBuffer(iRSI(NULL, Timeframe, 14, PRICE_CLOSE), 0, 0, HistoryBars, rsi) < HistoryBars) return;
   if(CopyBuffer(iATR(NULL, Timeframe, 14), 0, 0, HistoryBars, atr) < HistoryBars) return;
   if(CopyClose(NULL, Timeframe, 0, HistoryBars, price) < HistoryBars) return;
   
   // Détection d'états simplifiée
   for(int i = 0; i < HistoryBars; i++)
   {
      // État 0 = tendance normale, État 1 = correction
      bool in_correction = (price[i] < MA[i] && rsi[i] > 70);
      hidden_states[i] = in_correction ? 1 : 0;
   }
}

//+------------------------------------------------------------------+
//| Calculer la matrice de transition                                 |
//+------------------------------------------------------------------+
void CalculateTransitionMatrix()
{
   // Réinitialiser la matrice
   for(int i = 0; i < 2; i++)
      for(int j = 0; j < 2; j++)
         transition_matrix[i][j] = 0;
   
   // Compter les transitions
   int transitions[2][2] = {{0, 0}, {0, 0}};
   
   for(int i = 1; i < HistoryBars; i++)
   {
      int from_state = hidden_states[i-1];
      int to_state = hidden_states[i];
      transitions[from_state][to_state]++;
   }
   
   // Normaliser pour obtenir les probabilités
   for(int i = 0; i < 2; i++)
   {
      int total = transitions[i][0] + transitions[i][1];
      if(total > 0)
      {
         transition_matrix[i][0] = (double)transitions[i][0] / total;
         transition_matrix[i][1] = (double)transitions[i][1] / total;
      }
   }
}

//+------------------------------------------------------------------+
//| Fonction principale d'analyse et de prédiction                    |
//+------------------------------------------------------------------+
void AnalyzeAndPredict()
{
   // 1. Détecter les corrections historiques
   DetectHistoricalCorrections();
   
   // 2. Calculer les statistiques
   double historical_prob = CalculateCorrectionProbability();
   double avg_duration = CalculateAverageCorrectionDuration();
   double conditional_prob = CalculateConditionalProbability();
   int predicted_duration = PredictCurrentCorrectionDuration();
   
   // 3. Détecter les états cachés (HMM)
   DetectHiddenStates();
   CalculateTransitionMatrix();
   
   // 4. Afficher les résultats
   Print("🎯 PRÉDICTION DE CORRECTION - ", _Symbol);
   Print("   📊 Probabilité historique: ", DoubleToString(historical_prob, 2), "%");
   Print("   📊 Durée moyenne: ", DoubleToString(avg_duration, 2), " bougies");
   Print("   📊 Probabilité conditionnelle: ", DoubleToString(conditional_prob, 2), "%");
   Print("   📊 Durée prédite actuelle: ", predicted_duration, " bougies");
   
   // 5. Afficher la matrice de transition
   Print("   🔄 Matrice de transition:");
   Print("      Normal → Normal: ", DoubleToString(transition_matrix[0][0]*100, 1), "%");
   Print("      Normal → Correction: ", DoubleToString(transition_matrix[0][1]*100, 1), "%");
   Print("      Correction → Normal: ", DoubleToString(transition_matrix[1][0]*100, 1), "%");
   Print("      Correction → Correction: ", DoubleToString(transition_matrix[1][1]*100, 1), "%");
}

//+------------------------------------------------------------------+
//| Vérifier si on est dans une zone de correction                    |
//+------------------------------------------------------------------+
bool IsInCorrectionZone()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ma_val = MA[0];
   double rsi = iRSI(NULL, Timeframe, 14, PRICE_CLOSE, 0);
   
   return (price < ma_val && rsi > 70);
}

//+------------------------------------------------------------------+
//| Obtenir le score de correction (0-100)                           |
//+------------------------------------------------------------------+
double GetCorrectionScore()
{
   double historical_prob = CalculateCorrectionProbability();
   double conditional_prob = CalculateConditionalProbability();
   
   // Pondération: 40% historique, 60% conditionnel
   double score = 0.4 * historical_prob + 0.6 * conditional_prob;
   
   return MathMin(100.0, MathMax(0.0, score));
}

//+------------------------------------------------------------------+
//| Obtenir la durée recommandée d'attente                           |
//+------------------------------------------------------------------+
int GetRecommendedWaitTime()
{
   double avg_duration = CalculateAverageCorrectionDuration();
   double conditional_prob = CalculateConditionalProbability();
   
   // Si forte probabilité de correction, attendre plus longtemps
   double multiplier = 1.0 + (conditional_prob / 100.0) * 0.5;
   
   return (int)(avg_duration * multiplier);
}
