//+------------------------------------------------------------------+
//| SMC_ProbabilityGate.mqh — entrées uniquement si probabilité élevée |
//+------------------------------------------------------------------+
#ifndef SMC_PROBABILITY_GATE_MQH
#define SMC_PROBABILITY_GATE_MQH

extern double g_smcGomCoherence;
extern int    g_smcGomVerdictNum;
extern bool   g_smcGomConnected;
extern string g_smcGomGlobalDir;
extern int    g_smcGomGlobalStr;
extern double g_cogStrength;
extern double g_cogConfidence;
extern string g_cogDirection;
extern int    g_smcBcHourUtc;
extern double g_smcBcConfidence;
extern bool   g_smcBcTradeable;

double g_lastEntryProbability = 0.0;

bool SMCGP_IsBoomCrashSym(const string sym);

double SMC_ComputeEntryProbability(const int dirSign)
{
   double score = 0.0;

   // GOM cohérence (30 %)
   if(g_smcGomCoherence > 0)
      score += MathMin(100.0, g_smcGomCoherence) * 0.30;

   // Force verdict GOM (25 %)
   int vnAbs = MathAbs(g_smcGomVerdictNum);
   if(vnAbs >= 3)
      score += 25.0;
   else if(vnAbs >= 2)
      score += 18.0;
   else if(vnAbs >= 1)
      score += 8.0;

   // Cognition alignée (25 %)
   double cogPart = g_cogStrength * g_cogConfidence * 100.0 * 0.25;
   score += cogPart;
   if(dirSign > 0 && g_cogDirection == "BUY")
      score += 3.0;
   else if(dirSign < 0 && g_cogDirection == "SELL")
      score += 3.0;
   else if(g_cogDirection != "NEUTRAL" && dirSign != 0)
   {
      if((dirSign > 0 && g_cogDirection == "SELL") || (dirSign < 0 && g_cogDirection == "BUY"))
         score -= 12.0;
   }

   // BC heure UTC (15 %)
   if(SMCGP_IsBoomCrashSym(_Symbol) && g_smcBcHourUtc >= 0)
      score += (g_smcBcTradeable ? g_smcBcConfidence : 0.0) * 0.15;
   else
      score += 10.0;

   // Tendance globale (5 %)
   if(dirSign > 0 && g_smcGomGlobalDir == "BULL")
      score += 5.0;
   else if(dirSign < 0 && g_smcGomGlobalDir == "BEAR")
      score += 5.0;
   else if(dirSign != 0 && StringLen(g_smcGomGlobalDir) > 0
           && g_smcGomGlobalStr >= 2
           && ((dirSign > 0 && g_smcGomGlobalDir == "BEAR")
               || (dirSign < 0 && g_smcGomGlobalDir == "BULL")))
      score -= 8.0;

   if(score < 0) score = 0;
   if(score > 100) score = 100;
   g_lastEntryProbability = score;
   return score;
}

bool SMC_HighProbabilityAllowsEntry(const int dirSign = 0)
{
   if(!UseHighProbabilityFilter)
      return true;

   if(!g_smcGomConnected)
   {
      static datetime s_log = 0;
      if(TimeCurrent() - s_log >= 120)
      {
         s_log = TimeCurrent();
         Print("[PROB-GATE] BLOQUE — GOM non connecté");
      }
      return false;
   }

   if(g_smcGomVerdictNum == 0)
      return false;

   if(MathAbs(g_smcGomVerdictNum) < MinGOMVerdictNumAbs)
   {
      static datetime s_vnLog = 0;
      if(TimeCurrent() - s_vnLog >= 60)
      {
         s_vnLog = TimeCurrent();
         Print("[PROB-GATE] BLOQUE — verdict vn=", g_smcGomVerdictNum,
               " (min |vn|=", MinGOMVerdictNumAbs, " GOOD/PERFECT requis)");
      }
      return false;
   }

   if(dirSign > 0 && g_smcGomVerdictNum < MinGOMVerdictNumAbs)
      return false;
   if(dirSign < 0 && g_smcGomVerdictNum > -MinGOMVerdictNumAbs)
      return false;

   if(SMCGP_IsBoomCrashSym(_Symbol) && g_smcBcHourUtc >= 0)
   {
      if(!g_smcBcTradeable || g_smcBcConfidence < HighProbBcMinConfidence)
      {
         static datetime s_bcLog = 0;
         if(TimeCurrent() - s_bcLog >= 60)
         {
            s_bcLog = TimeCurrent();
            Print("[PROB-GATE] BLOQUE BC — conf=", DoubleToString(g_smcBcConfidence, 1),
                  "% min ", DoubleToString(HighProbBcMinConfidence, 0), "%");
         }
         return false;
      }
   }

   if(g_cogStrength < CognitionMinStrength || g_cogConfidence < CognitionMinConfidence)
   {
      static datetime s_cogLog = 0;
      if(TimeCurrent() - s_cogLog >= 60)
      {
         s_cogLog = TimeCurrent();
         Print("[PROB-GATE] BLOQUE cognition — str=", DoubleToString(g_cogStrength, 2),
               " conf=", DoubleToString(g_cogConfidence, 2));
      }
      return false;
   }

   if(dirSign != 0 && g_cogDirection != "NEUTRAL")
   {
      if(dirSign > 0 && g_cogDirection == "SELL") return false;
      if(dirSign < 0 && g_cogDirection == "BUY") return false;
   }

   double prob = SMC_ComputeEntryProbability(dirSign);
   if(prob < MinEntryProbabilityPct)
   {
      static datetime s_probLog = 0;
      if(TimeCurrent() - s_probLog >= 60)
      {
         s_probLog = TimeCurrent();
         Print("[PROB-GATE] BLOQUE — prob=", DoubleToString(prob, 1),
               "% < min ", DoubleToString(MinEntryProbabilityPct, 1),
               "% | vn=", g_smcGomVerdictNum,
               " coh=", DoubleToString(g_smcGomCoherence, 1), "%");
      }
      return false;
   }

   return true;
}

#endif
