//+------------------------------------------------------------------+
//| SMC_PathTrailBonus.mqh — trailing adaptatif selon concordance path |
//| Si GOM GOOD/PERFECT + cognition + IA + prob path élevée : laisser |
//| courir le trade le long du path projeté. Si correction : resserrer.|
//+------------------------------------------------------------------+
#ifndef SMC_PATH_TRAIL_BONUS_MQH
#define SMC_PATH_TRAIL_BONUS_MQH

// Variables partagées : inputs SMC_Universal.mq5 + SMC_GOM_Pipeline.mqh + SMC_ProbabilityGate.mqh
double g_pathTrailLastMult = 1.0;

string SMCPT_EffectiveCogDir()
{
   if(StringLen(g_cogDirection5m) > 0 && g_cogDirection5m != "NEUTRAL")
      return g_cogDirection5m;
   if(StringLen(g_cogDirection15m) > 0 && g_cogDirection15m != "NEUTRAL")
      return g_cogDirection15m;
   return g_cogDirection;
}

int SMCPT_CountPathRunway(const int posDir, const int lookBars = 40)
{
   int runway = 0;
   if(StringLen(g_smcPredPath) >= 5)
   {
      int look = MathMin(lookBars, StringLen(g_smcPredPath));
      for(int i = 0; i < look; i++)
      {
         ushort ch = StringGetCharacter(g_smcPredPath, i);
         if(posDir > 0 && ch == 'U')
            runway++;
         else if(posDir < 0 && ch == 'D')
            runway++;
         else if(ch == 'U' || ch == 'D')
            break;
      }
      return runway;
   }

   int n = ArraySize(g_smcPredPathMid);
   if(n < 3) return 0;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int start = 0;
   double bestDiff = 1e30;
   for(int i = 0; i < n; i++)
   {
      double d = MathAbs(g_smcPredPathMid[i] - bid);
      if(d < bestDiff)
      {
         bestDiff = d;
         start = i;
      }
   }
   for(int j = start + 1; j < n; j++)
   {
      if(posDir > 0 && g_smcPredPathMid[j] >= g_smcPredPathMid[j - 1])
         runway++;
      else if(posDir < 0 && g_smcPredPathMid[j] <= g_smcPredPathMid[j - 1])
         runway++;
      else
         break;
   }
   return runway;
}

bool SMCPT_PathCorrectionRisk(const int posDir, const int lookBars = 25)
{
   if(posDir == 0) return true;
   if(StringLen(g_smcPredPath) >= 8)
   {
      int look = MathMin(lookBars, StringLen(g_smcPredPath));
      int u = 0, d = 0;
      for(int i = 0; i < look; i++)
      {
         ushort ch = StringGetCharacter(g_smcPredPath, i);
         if(ch == 'U') u++;
         else if(ch == 'D') d++;
      }
      if(posDir > 0 && d >= 6 && d > u) return true;
      if(posDir < 0 && u >= 6 && u > d) return true;
   }

   if(!g_smcCorrEntrySafe && g_smcCorrExhaustPct < 45.0)
   {
      if(g_smcCorrPhase == "correcting") return true;
      if(StringFind(g_smcCorrType, "pullback") >= 0) return true;
      if(StringFind(g_smcCorrType, "counter") >= 0) return true;
   }
   return false;
}

double SMCPT_EntryProbabilityPct(const int posDir)
{
   if(g_smcEntryProbabilityPct > 0.0)
      return g_smcEntryProbabilityPct;
   if(g_lastEntryProbability > 0.0)
      return g_lastEntryProbability;
   return SMC_ComputeEntryProbability(posDir);
}

bool SMCPT_BonusConditionsMet(const int posDir, string &reasonOut)
{
   reasonOut = "";
   if(!UsePathTrailBonus || posDir == 0) return false;
   if(!g_smcGomConnected) { reasonOut = "GOM off"; return false; }
   if(g_pathConcordancePct < PathTrailMinConcordancePct)
   {
      reasonOut = "conc low";
      return false;
   }
   if(MathAbs(g_smcGomVerdictNum) < 2)
   {
      reasonOut = "vn<2";
      return false;
   }
   if(posDir > 0 && g_smcGomVerdictNum < 2) { reasonOut = "gom sell"; return false; }
   if(posDir < 0 && g_smcGomVerdictNum > -2) { reasonOut = "gom buy"; return false; }

   string cog = SMCPT_EffectiveCogDir();
   if(posDir > 0 && cog == "SELL") { reasonOut = "cog opp"; return false; }
   if(posDir < 0 && cog == "BUY") { reasonOut = "cog opp"; return false; }
   if(g_cogConfidence > 0.0 && g_cogConfidence < 0.45) { reasonOut = "cog weak"; return false; }

   string ia = g_smcIAStatusAction;
   StringToUpper(ia);
   if(posDir > 0 && ia == "SELL") { reasonOut = "ia opp"; return false; }
   if(posDir < 0 && ia == "BUY") { reasonOut = "ia opp"; return false; }
   if(ia != "HOLD" && g_iaStatusConfidence > 0.0
      && g_iaStatusConfidence < PathTrailMinIAConfidencePct)
   {
      reasonOut = "ia weak";
      return false;
   }

   double prob = SMCPT_EntryProbabilityPct(posDir);
   if(prob < PathTrailMinEntryProbPct)
   {
      reasonOut = "prob low";
      return false;
   }

   int runway = SMCPT_CountPathRunway(posDir);
   if(runway < PathTrailMinRunwayBars)
   {
      reasonOut = "runway short";
      return false;
   }

   reasonOut = StringFormat("conc=%.0f%% prob=%.0f%% rw=%d",
                            g_pathConcordancePct, prob, runway);
   return true;
}

bool SMCPT_EvaluateBonus(const int posDir, double &trailMult, double &keepPct, double &givebackFrac)
{
   trailMult = 1.0;
   keepPct = GainProtectKeepPct;
   givebackFrac = 0.50;
   g_pathTrailBonusActive = false;
   g_pathTrailLastMult = 1.0;

   if(!UsePathTrailBonus || posDir == 0) return false;

   string why = "";
   bool corrRisk = SMCPT_PathCorrectionRisk(posDir);
   bool met = SMCPT_BonusConditionsMet(posDir, why);

   if(corrRisk)
   {
      trailMult = MathMax(0.35, PathTrailCorrTightenMult);
      keepPct = MathMin(95.0, GainProtectKeepPct + 18.0);
      givebackFrac = 0.25;
      g_pathTrailLastMult = trailMult;
      if(met)
      {
         static datetime s_corrLog = 0;
         if(TimeCurrent() - s_corrLog >= 45)
         {
            s_corrLog = TimeCurrent();
            Print("[PATH-TRAIL] Correction détectée — trailing resserré | ", why,
                  " | corr=", g_smcCorrPhase, " ", DoubleToString(g_smcCorrExhaustPct, 0), "%");
         }
      }
      return false;
   }

   if(!met) return false;

   double concBoost = (g_pathConcordancePct - PathTrailMinConcordancePct) / 35.0;
   if(concBoost < 0.0) concBoost = 0.0;
   if(concBoost > 1.0) concBoost = 1.0;
   int runway = SMCPT_CountPathRunway(posDir);
   double runwayBoost = MathMin(0.35, runway / 40.0);

   trailMult = 1.0 + (PathTrailLoosenATRMax - 1.0) * concBoost + runwayBoost;
   if(trailMult > PathTrailLoosenATRMax + 0.35)
      trailMult = PathTrailLoosenATRMax + 0.35;

   keepPct = MathMax(45.0, PathTrailGainKeepBonusPct);
   givebackFrac = MathMax(0.20, PathTrailGivebackFrac);
   g_pathTrailBonusActive = true;
   g_pathTrailLastMult = trailMult;

   static datetime s_bonusLog = 0;
   if(TimeCurrent() - s_bonusLog >= 60)
   {
      s_bonusLog = TimeCurrent();
      Print("[PATH-TRAIL] Bonus actif — trailing élargi x", DoubleToString(trailMult, 2),
            " | ", why, " | keep=", DoubleToString(keepPct, 0), "%");
   }
   return true;
}

double SMCPT_AdjustTrailDistance(const double baseDistance, const int posDir)
{
   double mult = 1.0, keep = GainProtectKeepPct, giveback = 0.5;
   SMCPT_EvaluateBonus(posDir, mult, keep, giveback);
   return baseDistance * mult;
}

double SMCPT_EffectiveKeepPct(const int posDir)
{
   double mult = 1.0, keep = GainProtectKeepPct, giveback = 0.5;
   SMCPT_EvaluateBonus(posDir, mult, keep, giveback);
   return keep;
}

double SMCPT_EffectiveGivebackFrac(const int posDir)
{
   double mult = 1.0, keep = GainProtectKeepPct, giveback = 0.5;
   SMCPT_EvaluateBonus(posDir, mult, keep, giveback);
   return giveback;
}

#endif
