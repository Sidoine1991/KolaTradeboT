//+------------------------------------------------------------------+
//| SMC_PreSpikeGuard.mqh — PainX/GainX : éviter -$2.5 avant spike   |
//| Détecte drift M1 (~10 bougies) → BLOQUE ou RETARDE 2 min         |
//+------------------------------------------------------------------+
#ifndef SMC_PRE_SPIKE_GUARD_MQH
#define SMC_PRE_SPIKE_GUARD_MQH

// Mode: 0=OFF  1=BLOQUE seulement  2=RETARDE  3=AUTO (retarde si risque moyen, bloque si élevé)
input group "=== PRE-SPIKE GUARD (PainX/GainX Weltrade) ==="
input bool   UsePreSpikeGuard           = true;
input int    PreSpikeGuardMode          = 3;     // 0=OFF 1=BLOQUE 2=RETARDE 3=AUTO
input double PreSpikeMaxDrawdownUSD     = 2.50;  // MAE estimée avant spike → annuler entrée
input int    PreSpikeDelaySec           = 45;    // Retard exécution après signal (sec) — réduit de 120s à 45s : 120s laissait passer la majorité des spikes réels
input int    PreSpikeLookbackM1Bars     = 10;    // Bougies M1 pour estimer drift pré-spike
input double PreSpikeMinImminencePct    = 55.0;  // Entrer immédiat seulement si imminence >= (assoupli de 62 à 55)
input double PreSpikeMinPreSpikePct     = 38.0;  // pre_spike_pct min (TV/serveur)
input double PreSpikeDelayMinImminence  = 42.0;  // Après retard: imminence min pour entrer (assoupli de 48 à 42)

struct SMC_PreSpikePending
{
   string   symbol;
   string   direction;
   string   tag;
   string   levelSource;
   int      dirSign;
   datetime signalTime;
   double   signalImminence;
   double   signalPreSpike;
   double   signalEstUSD;
   bool     active;
};

SMC_PreSpikePending g_preSpikePending;

//+------------------------------------------------------------------+
double SMC_PreSpikePriceMoveToUSD(const string symbol, const double priceMove, const double volume)
{
   if(priceMove <= 0 || volume <= 0) return 0.0;
   double tickVal = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0 || tickSz <= 0) return priceMove * volume * 100.0;
   return MathAbs(priceMove) / tickSz * tickVal * volume;
}

//+------------------------------------------------------------------+
double SMC_EstimatePreSpikeAdverseUSD(const string symbol, const int dirSign, const int lookbackBars)
{
   if(dirSign == 0) return 0.0;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(symbol, PERIOD_M1, 1, lookbackBars, r);
   if(n < 4) return 0.0;

   double cumulative = 0.0;
   int adverseBars = 0;
   double avgBody = 0.0;

   for(int i = 0; i < n - 1; i++)
   {
      avgBody += MathAbs(r[i].close - r[i].open);
      if(dirSign == 1 && r[i].close < r[i + 1].close)
      {
         cumulative += (r[i + 1].close - r[i].close);
         adverseBars++;
      }
      else if(dirSign == -1 && r[i].close > r[i + 1].close)
      {
         cumulative += (r[i].close - r[i + 1].close);
         adverseBars++;
      }
   }
   avgBody /= MathMax(1, n - 1);

   double windowMove = 0.0;
   if(dirSign == 1)
      windowMove = MathMax(0.0, r[n - 1].open - r[0].close);
   else
      windowMove = MathMax(0.0, r[0].close - r[n - 1].open);

   double adverseMove = MathMax(cumulative, windowMove);

   double atrVal = 0.0;
   int atrH = iATR(symbol, PERIOD_M1, 14);
   if(atrH != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrH, 0, 1, 1, atrBuf) >= 1)
         atrVal = atrBuf[0];
      IndicatorRelease(atrH);
   }

   // Drift lent (petites bougies) mais direction contraire → typique pré-spike PainX/GainX
   if(atrVal > 0 && avgBody < atrVal * 0.35 && adverseBars >= 5)
      adverseMove = MathMax(adverseMove, atrVal * 0.55);

   // Projection ~10 bougies si le drift continue au rythme actuel
   if(adverseBars >= 3)
   {
      double perBar = cumulative / adverseBars;
      double projected = perBar * PreSpikeLookbackM1Bars;
      adverseMove = MathMax(adverseMove, projected);
   }

   double lot = CalculateLotSize();
   if(lot <= 0) lot = 0.01;
   return SMC_PreSpikePriceMoveToUSD(symbol, adverseMove, lot);
}

//+------------------------------------------------------------------+
bool SMC_PreSpikeIsWeltradePainGain(const string symbol)
{
   return SMC_IsWeltradeBoomCrash(symbol);
}

//+------------------------------------------------------------------+
int SMC_PreSpikeAssessRisk(const string symbol, const int dirSign,
                           double &estUSDOut, string &reasonOut)
{
   estUSDOut = 0.0;
   reasonOut = "";

   if(!UsePreSpikeGuard || PreSpikeGuardMode == 0) return 0;
   if(!SMC_PreSpikeIsWeltradePainGain(symbol)) return 0;
   if(dirSign == 0) return 0;

   estUSDOut = SMC_EstimatePreSpikeAdverseUSD(symbol, dirSign, PreSpikeLookbackM1Bars);

   bool spikeFar = (g_smcGomImminencePct < PreSpikeMinImminencePct);
   bool preSpikeLow = (g_smcPreSpikePct > 0 && g_smcPreSpikePct < PreSpikeMinPreSpikePct);
   bool driftHigh = (estUSDOut >= PreSpikeMaxDrawdownUSD * 0.55);

   if(estUSDOut >= PreSpikeMaxDrawdownUSD && spikeFar)
   {
      reasonOut = StringFormat("MAE~$%.2f>=%.2f avant spike (imminence %.0f%%)",
                               estUSDOut, PreSpikeMaxDrawdownUSD, g_smcGomImminencePct);
      return 2; // HIGH → bloquer
   }

   if(preSpikeLow && driftHigh && g_smcGomImminencePct < PreSpikeMinImminencePct + 8.0)
   {
      reasonOut = StringFormat("pre_spike %.0f%% + drift M1 ~$%.2f", g_smcPreSpikePct, estUSDOut);
      return 2;
   }

   if(spikeFar || preSpikeLow || estUSDOut >= PreSpikeMaxDrawdownUSD * 0.40)
   {
      reasonOut = StringFormat("spike pas prêt (imm=%.0f%% pre=%.0f%% MAE~$%.2f)",
                               g_smcGomImminencePct, g_smcPreSpikePct, estUSDOut);
      return 1; // MEDIUM → retarder (mode AUTO/DELAY)
   }

   return 0; // OK immédiat
}

//+------------------------------------------------------------------+
bool SMC_PreSpikeGuardBlocksEntry(const string symbol, const int dirSign, string &reasonOut)
{
   reasonOut = "";
   double estUSD = 0.0;
   int risk = SMC_PreSpikeAssessRisk(symbol, dirSign, estUSD, reasonOut);

   if(risk == 0) return false;

   if(PreSpikeGuardMode == 1 || (PreSpikeGuardMode == 3 && risk >= 2))
      return true;

   return false;
}

//+------------------------------------------------------------------+
bool SMC_PreSpikeGuardQueueEntry(const string symbol, const int dirSign,
                                 const string direction, const string tag,
                                 const string levelSource, const string reason)
{
   if(g_preSpikePending.active && g_preSpikePending.symbol == symbol)
      return true;

   g_preSpikePending.symbol         = symbol;
   g_preSpikePending.direction      = direction;
   g_preSpikePending.tag            = tag;
   g_preSpikePending.levelSource    = levelSource;
   g_preSpikePending.dirSign        = dirSign;
   g_preSpikePending.signalTime     = TimeCurrent();
   g_preSpikePending.signalImminence = g_smcGomImminencePct;
   g_preSpikePending.signalPreSpike  = g_smcPreSpikePct;
   g_preSpikePending.signalEstUSD    = SMC_EstimatePreSpikeAdverseUSD(symbol, dirSign, PreSpikeLookbackM1Bars);
   g_preSpikePending.active          = true;

   Print("[PRE-SPIKE-DELAY] ", direction, " ", symbol, " retardé ", PreSpikeDelaySec,
         "s | ", reason, " | imm=", DoubleToString(g_smcGomImminencePct, 0),
         "% pre=", DoubleToString(g_smcPreSpikePct, 0), "%");
   return true;
}

//+------------------------------------------------------------------+
bool SMC_PreSpikeGuardHandleEntry(const string symbol, const int dirSign,
                                  const string direction, const string tag,
                                  const string levelSource)
{
   if(!UsePreSpikeGuard || PreSpikeGuardMode == 0) return false;
   if(!SMC_PreSpikeIsWeltradePainGain(symbol)) return false;

   string reason = "";
   double estUSD = 0.0;
   int risk = SMC_PreSpikeAssessRisk(symbol, dirSign, estUSD, reason);

   if(risk == 0) return false;

   if(PreSpikeGuardMode == 1 || (PreSpikeGuardMode == 3 && risk >= 2))
   {
      static datetime s_blockLog = 0;
      if(TimeCurrent() - s_blockLog >= 20)
      {
         s_blockLog = TimeCurrent();
         Print("[PRE-SPIKE-BLOCK] ", direction, " ", symbol, " ANNULÉ — ", reason);
      }
      return true;
   }

   if(PreSpikeGuardMode == 2 || PreSpikeGuardMode == 3)
      return SMC_PreSpikeGuardQueueEntry(symbol, dirSign, direction, tag, levelSource, reason);

   return false;
}

//+------------------------------------------------------------------+
bool SMC_PreSpikeDelayedEntryReady(const string symbol, const int dirSign, string &reasonOut)
{
   reasonOut = "";

   if(g_smcGomImminencePct >= PreSpikeDelayMinImminence)
   {
      reasonOut = StringFormat("imminence %.0f%%", g_smcGomImminencePct);
      return true;
   }

   if(g_smcPreSpikePct >= PreSpikeMinPreSpikePct + 5.0)
   {
      reasonOut = StringFormat("pre_spike %.0f%%", g_smcPreSpikePct);
      return true;
   }

   double estNow = SMC_EstimatePreSpikeAdverseUSD(symbol, dirSign, MathMax(4, PreSpikeLookbackM1Bars / 2));
   if(estNow < PreSpikeMaxDrawdownUSD * 0.35)
   {
      reasonOut = StringFormat("drift réduit MAE~$%.2f", estNow);
      return true;
   }

   if(g_smcGomImminencePct >= g_preSpikePending.signalImminence + 12.0)
   {
      reasonOut = StringFormat("imminence +%.0f pts", g_smcGomImminencePct - g_preSpikePending.signalImminence);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
void SMC_PreSpikeGuardProcessDelayed()
{
   if(!UsePreSpikeGuard || PreSpikeGuardMode == 0 || PreSpikeGuardMode == 1) return;
   if(!g_preSpikePending.active) return;
   if(g_preSpikePending.symbol != _Symbol) return;

   int elapsed = (int)(TimeCurrent() - g_preSpikePending.signalTime);
   if(elapsed < PreSpikeDelaySec) return;

   string readyReason = "";
   if(!SMC_PreSpikeDelayedEntryReady(_Symbol, g_preSpikePending.dirSign, readyReason))
   {
      if(elapsed > PreSpikeDelaySec + 180)
      {
         Print("[PRE-SPIKE-DELAY] Expiré sans amélioration — ", g_preSpikePending.direction,
               " ", _Symbol, " annulé après ", elapsed, "s");
         g_preSpikePending.active = false;
      }
      return;
   }

   if(g_smcGomVerdictNum == 0)
   {
      g_preSpikePending.active = false;
      return;
   }

   int curDir = (g_smcGomVerdictNum > 0) ? 1 : ((g_smcGomVerdictNum < 0) ? -1 : 0);
   if(curDir != g_preSpikePending.dirSign)
   {
      Print("[PRE-SPIKE-DELAY] GOM a changé de direction — entrée annulée");
      g_preSpikePending.active = false;
      return;
   }

   string blockReason = "";
   if(SMC_PreSpikeGuardBlocksEntry(_Symbol, g_preSpikePending.dirSign, blockReason))
   {
      Print("[PRE-SPIKE-DELAY] Toujours bloqué après ", elapsed, "s — ", blockReason);
      g_preSpikePending.active = false;
      return;
   }

   Print("[PRE-SPIKE-DELAY] Exécution après ", elapsed, "s — ", readyReason,
         " | ", g_preSpikePending.direction, " ", _Symbol);

   bool ok = PlaceGOMMarketOrder(g_preSpikePending.direction,
                                 g_preSpikePending.tag + "_DELAY",
                                 g_preSpikePending.levelSource);
   g_preSpikePending.active = false;

   if(!ok)
      Print("[PRE-SPIKE-DELAY] Échec ordre différé ", g_preSpikePending.direction, " ", _Symbol);
}

#endif
