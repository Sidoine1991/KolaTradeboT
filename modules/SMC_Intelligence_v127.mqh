//+------------------------------------------------------------------+
//| SMC_Intelligence_v127.mqh                                         |
//| v1.27 — OpportunityScore + RealChain + AntiCorr + SmartLoss       |
//+------------------------------------------------------------------+
#ifndef SMC_INTELLIGENCE_V127_MQH
#define SMC_INTELLIGENCE_V127_MQH

// Globals declared in main EA:
// g_realChain*, g_antiCorr*, g_lastOppScore*, g_symLoss*, g_smartLoss*

void SMC_SmartLossRegister(const double profit)
{
   if(!UseSmartLossCircuit) return;
   if(profit >= 0.0)
   {
      g_symLossCount = 0;
      g_smartLossNeedPerfect = false;
      return;
   }
   datetime now = TimeCurrent();
   int keep = 0;
   datetime window = (datetime)(SmartLossWindowMin * 60);
   for(int i = 0; i < g_symLossCount && i < 8; i++)
   {
      if(now - g_symLossTimes[i] <= window)
      {
         g_symLossTimes[keep] = g_symLossTimes[i];
         keep++;
      }
   }
   g_symLossCount = keep;
   if(g_symLossCount < 8)
   {
      g_symLossTimes[g_symLossCount] = now;
      g_symLossCount++;
   }
   if(g_symLossCount >= 2)
   {
      int pauseSec = MathMax(60, SmartLossPauseMin * 60);
      g_smartLossPauseUntil = now + pauseSec;
      if(SmartLossRequirePerfect)
         g_smartLossNeedPerfect = true;
      Print("🛑 SMART LOSS CB — ", g_symLossCount, " pertes en ", SmartLossWindowMin,
            " min sur ", _Symbol, " → pause ", SmartLossPauseMin, " min",
            (g_smartLossNeedPerfect ? " + exige PERFECT" : ""));
      g_symLossCount = 0;
   }
}

bool SMC_SmartLossAllowsEntry(const int dirSign, string &whyOut)
{
   whyOut = "";
   if(!UseSmartLossCircuit) return true;
   datetime now = TimeCurrent();
   if(g_smartLossPauseUntil > 0 && now < g_smartLossPauseUntil)
   {
      whyOut = StringFormat("smart loss pause jusqu'à %s", TimeToString(g_smartLossPauseUntil, TIME_SECONDS));
      return false;
   }
   if(g_smartLossNeedPerfect && MathAbs(g_smcGomVerdictNum) < 3)
   {
      whyOut = "après 2 pertes: PERFECT requis (vn>=3)";
      return false;
   }
   if(g_smartLossNeedPerfect && MathAbs(g_smcGomVerdictNum) >= 3)
      g_smartLossNeedPerfect = false;
   return true;
}

void SMC_UpdateRealChainTracker()
{
   if(!UseRealChainFilter) return;
   if(!SMC_IsSpikeStyleSymbol(_Symbol) && !IsBoomLikeSymbol(_Symbol) && !IsCrashLikeSymbol(_Symbol))
      return;

   static datetime s_lastBar = 0;
   datetime barT = iTime(_Symbol, PERIOD_M1, 0);
   if(barT == s_lastBar) return;
   s_lastBar = barT;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M1, 1, 4, r) < 3) return;

   double atr = 0;
   if(atrHandle != INVALID_HANDLE)
   {
      double ab[];
      ArraySetAsSeries(ab, true);
      if(CopyBuffer(atrHandle, 0, 1, 2, ab) >= 2) atr = ab[0];
   }
   if(atr <= 0) atr = _Point * 50;

   double body0 = MathAbs(r[0].close - r[0].open);
   double range0 = r[0].high - r[0].low;
   int dir0 = (r[0].close > r[0].open) ? 1 : ((r[0].close < r[0].open) ? -1 : 0);
   bool strong0 = (body0 >= atr * SpikeChainBodyATRMult) || (range0 >= atr * SpikeChainBodyATRMult * 1.15);

   if(!strong0 || dir0 == 0)
   {
      if(g_realChainLastSpikeTime > 0 && (TimeCurrent() - g_realChainLastSpikeTime) > 180)
      {
         g_realChainSpikeCount = 0;
         g_realChainDir = 0;
         g_realChainExhausted = false;
         g_realChainIsSecondSpike = false;
      }
      return;
   }

   if(g_realChainDir != 0 && dir0 != g_realChainDir)
   {
      g_realChainSpikeCount = 1;
      g_realChainDir = dir0;
      g_realChainPrevSpikeATR = 0;
      g_realChainLastSpikeATR = atr;
      g_realChainLastSpikeRange = range0;
      g_realChainSpikeStart = (dir0 > 0) ? r[0].low : r[0].high;
      g_realChainLastSpikeTime = r[0].time;
      g_realChainExhausted = false;
      g_realChainIsSecondSpike = false;
      return;
   }

   g_realChainDir = dir0;
   g_realChainPrevSpikeATR = g_realChainLastSpikeATR;
   g_realChainLastSpikeATR = atr;
   double prevRange = g_realChainLastSpikeRange;
   g_realChainLastSpikeRange = range0;
   g_realChainSpikeStart = (dir0 > 0) ? r[0].low : r[0].high;
   g_realChainLastSpikeTime = r[0].time;
   g_realChainSpikeCount++;

   bool expanded = true;
   if(g_realChainPrevSpikeATR > 0)
      expanded = (g_realChainLastSpikeATR >= g_realChainPrevSpikeATR * RealChainATRExpandMin);

   if(RealChainBlockExhaustion && g_realChainSpikeCount >= 3 && prevRange > 0)
   {
      if(range0 < prevRange * 0.85 || (g_realChainPrevSpikeATR > 0 && atr < g_realChainPrevSpikeATR * 0.92))
      {
         g_realChainExhausted = true;
         Print("⚪ REAL CHAIN EXHAUSTION — 3e spike plus petit | ", _Symbol,
               " count=", g_realChainSpikeCount, " range=", DoubleToString(range0, 2));
      }
   }

   g_realChainIsSecondSpike = (g_realChainSpikeCount == RealChainMinSpikes && expanded);

   if(g_realChainSpikeCount == RealChainMinSpikes && expanded)
      Print("✅ REAL CHAIN START — ", RealChainMinSpikes, " spikes ", (dir0 > 0 ? "UP" : "DOWN"),
            " + ATR expand | ", _Symbol, " atr=", DoubleToString(atr, 4));
}

bool SMC_RealChainAllowsEntry(const int dirSign, string &whyOut)
{
   whyOut = "";
   if(!UseRealChainFilter) return true;
   if(!SMC_IsSpikeStyleSymbol(_Symbol) && !IsBoomLikeSymbol(_Symbol) && !IsCrashLikeSymbol(_Symbol))
      return true;

   if(g_realChainExhausted)
   {
      whyOut = "chaîne épuisée (3e spike plus petit)";
      return false;
   }
   if(g_realChainSpikeCount < RealChainMinSpikes)
   {
      whyOut = StringFormat("attente chaîne réelle (%d/%d spikes)", g_realChainSpikeCount, RealChainMinSpikes);
      if(MathAbs(g_smcGomVerdictNum) >= 3 &&
         (g_spikeChainState == SPIKE_STATE_PRE_SPIKE || g_spikeChainState == SPIKE_STATE_CHAIN_ACTIVE))
         return true;
      return false;
   }
   if(g_realChainDir != 0 && dirSign != 0 && g_realChainDir != dirSign)
   {
      whyOut = "direction chaîne réelle opposée";
      return false;
   }
   return true;
}

void SMC_UpdateAntiCorrection()
{
   if(!UseAntiCorrectionFilter) return;

   if(g_realChainLastSpikeRange > 0 && g_realChainSpikeStart > 0 && g_realChainDir != 0)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double extreme = (g_realChainDir < 0)
         ? (g_realChainSpikeStart - g_realChainLastSpikeRange)
         : (g_realChainSpikeStart + g_realChainLastSpikeRange);
      double moveFromExtreme = MathAbs(bid - extreme);
      double pctFromExtreme = (g_realChainLastSpikeRange > 0)
         ? (moveFromExtreme / g_realChainLastSpikeRange * 100.0) : 0.0;

      if(pctFromExtreme >= AntiCorrRetracePct)
      {
         g_antiCorrWaitUntil = TimeCurrent() + AntiCorrWaitSec;
         g_antiCorrReason = StringFormat("retrace %.0f%% du spike", pctFromExtreme);
      }
   }

   if(AntiCorrEngulfBlock)
   {
      int eng = SMC_DetectLocalEngulfingDir();
      int targetDir = (g_smcGomConnected && g_smcGomVerdictNum != 0)
         ? ((g_smcGomVerdictNum > 0) ? 1 : -1)
         : g_realChainDir;
      if(eng != 0 && targetDir != 0 && eng == -targetDir)
      {
         g_antiCorrWaitUntil = TimeCurrent() + AntiCorrWaitSec;
         g_antiCorrReason = "engulf M1 contre sens";
      }
   }

   if(AntiCorrTickDensityBlock && g_tickFreqAvg > 0 && g_tickFreqRatio > 0)
   {
      if(g_tickFreqRatio < AntiCorrTickDensityMin)
      {
         g_antiCorrWaitUntil = TimeCurrent() + MathMax(8, AntiCorrWaitSec / 2);
         g_antiCorrReason = StringFormat("tick density basse (%.2f)", g_tickFreqRatio);
      }
   }
}

bool SMC_AntiCorrectionAllowsEntry(string &whyOut)
{
   whyOut = "";
   if(!UseAntiCorrectionFilter) return true;
   if(g_antiCorrWaitUntil > 0 && TimeCurrent() < g_antiCorrWaitUntil)
   {
      whyOut = "anti-corr: " + g_antiCorrReason + " (WAIT forcé)";
      return false;
   }
   return true;
}

double SMC_OpportunityScore(const int dirSign, string &detailsOut)
{
   detailsOut = "";
   if(dirSign == 0) { detailsOut = "dir=0"; return 0; }

   double score = 0;
   string parts = "";

   // 1) Force spike (0-20)
   double spikePts = 0;
   if(g_lastSpikeAmplitudeAtr > 0)
   {
      if(g_lastSpikeAmplitudeAtr >= 2.5) spikePts = 20;
      else if(g_lastSpikeAmplitudeAtr >= 1.8) spikePts = 16;
      else if(g_lastSpikeAmplitudeAtr >= 1.2) spikePts = 12;
      else if(g_lastSpikeAmplitudeAtr >= 0.8) spikePts = 8;
      else spikePts = 4;
   }
   else if(g_realChainLastSpikeRange > 0 && atrHandle != INVALID_HANDLE)
   {
      double atr = 0;
      double ab[]; ArraySetAsSeries(ab, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, ab) >= 1) atr = ab[0];
      if(atr > 0)
      {
         double ratio = g_realChainLastSpikeRange / atr;
         if(ratio >= 2.5) spikePts = 18;
         else if(ratio >= 1.5) spikePts = 14;
         else if(ratio >= 1.0) spikePts = 10;
         else spikePts = 5;
      }
   }
   if(g_lastSpikeVelocityProxy > 0)
      spikePts = MathMin(20.0, spikePts + (g_lastSpikeVelocityProxy > 1.5 ? 3.0 : 1.0));
   score += spikePts;
   parts += StringFormat("Spike=%.0f ", spikePts);

   // 2) TF M1+M5+H1 (0-20)
   double tfPts = 0;
   bool m1ok = (dirSign > 0) ? SMC_ScalpTfDirIsBull(g_smcTfM1Dir) : SMC_ScalpTfDirIsBear(g_smcTfM1Dir);
   bool m5ok = (dirSign > 0) ? SMC_ScalpTfDirIsBull(g_smcTfM5Dir) : SMC_ScalpTfDirIsBear(g_smcTfM5Dir);
   bool h1ok = (dirSign > 0) ? SMC_ScalpTfDirIsBull(g_smcTfH1Dir) : SMC_ScalpTfDirIsBear(g_smcTfH1Dir);
   if(m1ok) tfPts += 7;
   if(m5ok) tfPts += 7;
   if(h1ok) tfPts += 6;
   if(!m1ok && !m5ok) tfPts = MathMax(0.0, tfPts - 8.0);
   score += tfPts;
   parts += StringFormat("TF=%.0f ", tfPts);

   // 3) Zone (0-15)
   double zonePts = 0;
   if(dirSign < 0)
   {
      if(g_priceZonePct >= 85.0 || g_priceZoneLabel == "PREMIUM_EXTREME") zonePts = 15;
      else if(g_priceInPremium && g_priceZonePct >= 65.0) zonePts = 12;
      else if(g_priceInPremium) zonePts = 7;
      else if(g_priceZonePct > 38.0 && g_priceZonePct < 62.0) zonePts = 0;
      else zonePts = 3;
   }
   else
   {
      if(g_priceZonePct <= 15.0 || g_priceZoneLabel == "DISCOUNT_EXTREME") zonePts = 15;
      else if(g_priceInDiscount && g_priceZonePct <= 35.0) zonePts = 12;
      else if(g_priceInDiscount) zonePts = 7;
      else if(g_priceZonePct > 38.0 && g_priceZonePct < 62.0) zonePts = 0;
      else zonePts = 3;
   }
   if(IsCrashLikeSymbol(_Symbol) && dirSign < 0 && g_priceInDiscount)
      zonePts = MathMax(zonePts, 11.0);
   if(IsBoomLikeSymbol(_Symbol) && dirSign > 0 && g_priceInPremium)
      zonePts = MathMax(zonePts, 11.0);
   score += zonePts;
   parts += StringFormat("Zone=%.0f ", zonePts);

   // 4) DISP trail (0-10)
   double dispPts = 0;
   if(UseDispFVGTrail)
   {
      if(g_dispTrailValid && !g_dispTrailBroken && !g_dispInCorrection)
      {
         if((dirSign > 0 && g_dispTrailDir > 0) || (dirSign < 0 && g_dispTrailDir < 0))
            dispPts = 10;
         else
            dispPts = 2;
      }
      else if(g_dispTrailBroken || g_dispInCorrection)
         dispPts = 0;
      else
         dispPts = 4;
   }
   else
      dispPts = 5;
   score += dispPts;
   parts += StringFormat("DISP=%.0f ", dispPts);

   // 5) Chain (0-15)
   double chainPts = 0;
   if(g_spikeChainState == SPIKE_STATE_CHAIN_ACTIVE && g_spikeChainDirection == dirSign)
      chainPts = 12;
   else if(g_spikeChainState == SPIKE_STATE_PRE_SPIKE)
      chainPts = 7;
   else if(g_spikeChainState == SPIKE_STATE_EXHAUSTION)
      chainPts = 0;
   else
      chainPts = 3;
   if(UseRealChainFilter)
   {
      if(g_realChainExhausted) chainPts = 0;
      else if(g_realChainIsSecondSpike && PreferSecondSpikeEntry)
         chainPts = MathMin(15.0, chainPts + 5.0);
      else if(g_realChainSpikeCount >= RealChainMinSpikes && g_realChainDir == dirSign)
         chainPts = MathMin(15.0, chainPts + 3.0);
   }
   score += chainPts;
   parts += StringFormat("Chain=%.0f ", chainPts);

   // 6) GOM (0-15)
   double gomPts = 0;
   if(g_smcGomConnected)
   {
      int vn = g_smcGomVerdictNum;
      bool aligned = (dirSign > 0 && vn > 0) || (dirSign < 0 && vn < 0);
      if(!aligned || vn == 0)
         gomPts = 0;
      else
      {
         if(MathAbs(vn) >= 3) gomPts = 10;
         else if(MathAbs(vn) >= 2) gomPts = 8;
         else gomPts = 4;
         if(g_smcGomCoherence >= 80.0) gomPts += 5;
         else if(g_smcGomCoherence >= 65.0) gomPts += 3;
         else if(g_smcGomCoherence >= 50.0) gomPts += 1;
         else gomPts = MathMax(0.0, gomPts - 3.0);
      }
   }
   else
      gomPts = 2;
   score += gomPts;
   parts += StringFormat("GOM=%.0f ", gomPts);

   // 7) No correction (0-5)
   double corrPts = 5;
   if(g_dispInCorrection) corrPts = 0;
   if(g_antiCorrWaitUntil > TimeCurrent()) corrPts = 0;
   if(dirSign > 0 && SMC_ScalpTfDirIsBear(g_smcTfM1Dir) && g_priceZonePct > 40.0 && g_priceZonePct < 60.0)
      corrPts = MathMin(corrPts, 1.0);
   if(dirSign < 0 && SMC_ScalpTfDirIsBull(g_smcTfM1Dir) && g_priceZonePct > 40.0 && g_priceZonePct < 60.0)
      corrPts = MathMin(corrPts, 1.0);
   score += corrPts;
   parts += StringFormat("NoCorr=%.0f", corrPts);

   score = MathMax(0.0, MathMin(100.0, score));
   detailsOut = parts;
   g_lastOppScore = score;
   g_lastOppScoreDetails = parts;
   return score;
}

bool SMC_OpportunityAllowsMarket(const int dirSign, string &whyOut)
{
   whyOut = "";
   if(!UseOpportunityScore) return true;

   string acWhy = "";
   if(!SMC_AntiCorrectionAllowsEntry(acWhy))
   {
      whyOut = acWhy;
      return false;
   }

   string slWhy = "";
   if(!SMC_SmartLossAllowsEntry(dirSign, slWhy))
   {
      whyOut = slWhy;
      return false;
   }

   string rcWhy = "";
   if(!SMC_RealChainAllowsEntry(dirSign, rcWhy))
   {
      whyOut = rcWhy;
      return false;
   }

   if(BlockMarketInRetraceMid && SMC_PriceIsInBlockedRetraceZone())
   {
      whyOut = "retrace mid 38-62% — pas de market";
      return false;
   }

   if(MarketOnlyInZoneAlign)
   {
      string zWhy = "";
      if(!SMC_ZoneAllowsDirection(dirSign, zWhy))
      {
         if(MathAbs(g_smcGomVerdictNum) < 3)
         {
            whyOut = "zone non alignée: " + zWhy;
            return false;
         }
      }
   }

   string det = "";
   double sc = SMC_OpportunityScore(dirSign, det);
   if(sc < OpportunityScoreMinMarket)
   {
      whyOut = StringFormat("score %.1f < %.1f [%s]", sc, OpportunityScoreMinMarket, det);
      if(OppScoreLogDetails)
      {
         static datetime s_log = 0;
         if(TimeCurrent() - s_log >= 12)
         {
            s_log = TimeCurrent();
            Print("📊 OPP SCORE ", _Symbol, " dir=", dirSign, " = ", DoubleToString(sc, 1),
                  " < ", DoubleToString(OpportunityScoreMinMarket, 0), " | ", det);
         }
      }
      return false;
   }

   if(OppScoreLogDetails)
   {
      static datetime s_ok = 0;
      if(TimeCurrent() - s_ok >= 15)
      {
         s_ok = TimeCurrent();
         Print("✅ OPP SCORE OK ", _Symbol, " = ", DoubleToString(sc, 1), " | ", det);
      }
   }
   return true;
}

bool SMC_OpportunityAllowsLimit(const int dirSign, string &whyOut)
{
   whyOut = "";
   if(!UseOpportunityScore) return true;
   string acWhy = "";
   if(!SMC_AntiCorrectionAllowsEntry(acWhy))
   {
      whyOut = acWhy;
      return false;
   }
   string det = "";
   double sc = SMC_OpportunityScore(dirSign, det);
   if(sc < OpportunityScoreMinLimit)
   {
      whyOut = StringFormat("score LIMIT %.1f < %.1f", sc, OpportunityScoreMinLimit);
      return false;
   }
   return true;
}

void SMC_UpdateIntelligenceModule()
{
   SMC_UpdateRealChainTracker();
   SMC_UpdateAntiCorrection();
}

#endif // SMC_INTELLIGENCE_V127_MQH
