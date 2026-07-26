//+------------------------------------------------------------------+
//| SMC_SpikeChainSignal.mqh — Signal de chaîne de spikes enrichi    |
//| Score Dow + classification chaîne lâche/serrée + notifications   |
//| Entry/SL/TP1-3 (~5 min) en push MT5 + WhatsApp.                  |
//| Ne modifie PAS la logique de trading (SR20/pattern/GOM intacte). |
//+------------------------------------------------------------------+
#ifndef SMC_SPIKE_CHAIN_SIGNAL_MQH
#define SMC_SPIKE_CHAIN_SIGNAL_MQH

// --- États partagés (définis une seule fois, guard ci-dessus) ---
struct SMCSCS_ChainState
{
   int    lastSpikeBar;        // Numéro de bougie (iBarShift) du dernier spike capté
   int    prevSpikeBar;        // Bougie du spike avant le dernier
   int    spikeCount;          // Nombre de spikes dans la chaîne courante
   double lastSpikeDir;        // +1 haussier, -1 baissier
   int    looseCount;          // Spikes classés "lâches" (intervalle > seuil)
   int    tightCount;          // Spikes classés "serrés"
   double dowScore;            // Score tendance Dow [-1..+1]
   double confidence;          // Confiance combinée [0..1]
};
SMCSCS_ChainState g_smcscs = {0,0,0,0,0,0,0,0};

// Seuils de classification (en bougies M1 entre 2 spikes)
input int   SMCSCS_TightMaxBars   = 4;     // <=4 bougies -> chaîne SERRÉE
input int   SMCSCS_LooseMaxBars   = 7;     // <=7 bougies -> chaîne LÂCHE, >7 -> hors chaîne
input double SMCSCS_DowWeight     = 0.45;  // Poids du score Dow dans la confiance
input double SMCSCS_Tp1Mult        = 1.0;   // TP1 = ATR x 1.0 (~courte durée)
input double SMCSCS_Tp2Mult        = 2.0;   // TP2 = ATR x 2.0
input double SMCSCS_Tp3Mult        = 3.5;   // TP3 = ATR x 3.5 (~5 min moyenne)
input double SMCSCS_SlMult        = 1.5;   // SL = ATR x 1.5

//+------------------------------------------------------------------+
//| Score de tendance Dow : sommets/creux selon direction symbole   |
//| Boom/GainX (haussier) : sommets de plus en plus HAUTS -> +1      |
//| Crash/PainX (baissier) : creux de plus en plus BAS   -> -1      |
//+------------------------------------------------------------------+
double SMCSCS_ComputeDowScore(const string symbol, int &swingCount)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 60, rates) < 60) return 0;

   // Boom/GainX -> haussier (on veut sommets montants). Crash/PainX -> baissier.
   bool bullish = !(IsCrashLikeSymbol(symbol));

   // Détecter les swings (pivot high/low sur 3 bougies)
   double swings[];
   int    swDir[];   // +1 high, -1 low
   for(int i = 3; i < 57; i++)
   {
      if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
         rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
      {
         int sz = ArraySize(swings); ArrayResize(swings, sz+1); swings[sz]=rates[i].high;
         ArrayResize(swDir, sz+1); swDir[sz]=1;
      }
      if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
         rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
      {
         int sz = ArraySize(swings); ArrayResize(swings, sz+1); swings[sz]=rates[i].low;
         ArrayResize(swDir, sz+1); swDir[sz]=-1;
      }
   }

   swingCount = ArraySize(swings);
   if(swingCount < 3) return 0;

   int aligned = 0, total = 0;
   for(int i = 1; i < swingCount; i++)
   {
      // On ne compare que les swings de même nature (high vs high, low vs low)
      if(swDir[i] != swDir[i-1]) continue;
      total++;
      if(swDir[i] == 1) // sommet
      {
         if(bullish && swings[i] > swings[i-1]) aligned++;
         if(!bullish && swings[i] < swings[i-1]) aligned++;
      }
      else // creux
      {
         if(bullish && swings[i] < swings[i-1]) aligned++;   // creux plus bas = sain en haussier
         if(!bullish && swings[i] > swings[i-1]) aligned++;  // creux plus haut = sain en baissier
      }
   }
   if(total == 0) return 0;
   return (double)aligned / (double)total * 2.0 - 1.0; // [-1..+1]
}

//+------------------------------------------------------------------+
//| Enregistre un spike capté et met à jour la chaîne               |
//+------------------------------------------------------------------+
void SMCSCS_RegisterSpike(const string symbol, const double spikeDir, int currentBar)
{
   int swingCount = 0;
   double dow = SMCSCS_ComputeDowScore(symbol, swingCount);
   g_smcscs.dowScore = dow;

   if(g_smcscs.lastSpikeBar > 0)
   {
      int interval = currentBar - g_smcscs.lastSpikeBar;
      g_smcscs.prevSpikeBar = g_smcscs.lastSpikeBar;
      if(interval <= SMCSCS_TightMaxBars)      g_smcscs.tightCount++;
      else if(interval <= SMCSCS_LooseMaxBars) g_smcscs.looseCount++;
   }
   g_smcscs.lastSpikeBar = currentBar;
   g_smcscs.spikeCount++;
   g_smcscs.lastSpikeDir = spikeDir;

   // Confiance = mélange Dow + régularité chaîne (Z-score calculé ailleurs)
   double chainReg = (g_smcscs.tightCount + g_smcscs.looseCount) > 0
                     ? (double)g_smcscs.tightCount / (g_smcscs.tightCount + g_smcscs.looseCount)
                     : 0.0;
   g_smcscs.confidence = MathMin(1.0, SMCSCS_DowWeight * ((dow+1)/2.0) + (1.0-SMCSCS_DowWeight) * chainReg);
}

//+------------------------------------------------------------------+
//| Type de chaîne courante                                          |
//+------------------------------------------------------------------+
string SMCSCS_ChainType()
{
   if(g_smcscs.tightCount > g_smcscs.looseCount) return "SERRÉE";
   if(g_smcscs.looseCount > 0)                    return "LÂCHE";
   return "MIXTE";
}

//+------------------------------------------------------------------+
//| Calcule Entry/SL/TP1-3 à partir de l'ATR et de la direction      |
//+------------------------------------------------------------------+
void SMCSCS_BuildLevels(const string symbol, const double spikeDir, double atr,
                        double &entry, double &sl, double &tp1, double &tp2, double &tp3)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   entry = (spikeDir > 0) ? ask : bid;
   double dg = (double)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   if(spikeDir > 0) // BUY
   {
      sl  = NormalizeDouble(entry - atr * SMCSCS_SlMult,  (int)dg);
      tp1 = NormalizeDouble(entry + atr * SMCSCS_Tp1Mult, (int)dg);
      tp2 = NormalizeDouble(entry + atr * SMCSCS_Tp2Mult, (int)dg);
      tp3 = NormalizeDouble(entry + atr * SMCSCS_Tp3Mult, (int)dg);
   }
   else             // SELL
   {
      sl  = NormalizeDouble(entry + atr * SMCSCS_SlMult,  (int)dg);
      tp1 = NormalizeDouble(entry - atr * SMCSCS_Tp1Mult, (int)dg);
      tp2 = NormalizeDouble(entry - atr * SMCSCS_Tp2Mult, (int)dg);
      tp3 = NormalizeDouble(entry - atr * SMCSCS_Tp3Mult, (int)dg);
   }
}

//+------------------------------------------------------------------+
//| Notifie le signal de chaîne (push MT5 + WhatsApp)                |
//+------------------------------------------------------------------+
void SMCSCS_NotifyChainSignal(const string symbol, const double spikeDir, double atr)
{
   if(atr <= 0) return;
   double entry, sl, tp1, tp2, tp3;
   SMCSCS_BuildLevels(symbol, spikeDir, atr, entry, sl, tp1, tp2, tp3);

   string dir = (spikeDir > 0) ? "BUY" : "SELL";
   string chainType = SMCSCS_ChainType();
   string dowTxt = (g_smcscs.dowScore >= 0) ? "HAUSSIER" : "BAISSIER";
   string coh = DoubleToString(g_smcscs.confidence * 100, 0) + "%";
   int dg = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   string msg = "⚡ CHAÎNE SPIKE [" + symbol + "]\n";
   msg += "Type: " + chainType + " | Dow: " + dowTxt + " (" + DoubleToString(g_smcscs.dowScore,2) + ")\n";
   msg += "Direction: " + dir + " | Confiance: " + coh + "\n";
   msg += "Entry: " + DoubleToString(entry, dg) + "\n";
   msg += "SL: " + DoubleToString(sl, dg) + "\n";
   msg += "TP1: " + DoubleToString(tp1, dg) +
          " | TP2: " + DoubleToString(tp2, dg) +
          " | TP3: " + DoubleToString(tp3, dg) + "\n";
   msg += "ATR: " + DoubleToString(atr, dg) +
          " | Spikes: " + IntegerToString(g_smcscs.spikeCount);

   // Push MT5 natif
   if(UseNotifications) SendNotification(msg);

   // WhatsApp (réutilise l'infra existante SendSR20WhatsAppSignal)
    if(UseWhatsAppAlerts)
    {
       double refPx = (spikeDir>0) ? SymbolInfoDouble(symbol,SYMBOL_ASK) : SymbolInfoDouble(symbol,SYMBOL_BID);
       double dow = g_smcscs.dowScore;
       double conf = g_smcscs.confidence;
       int sc = g_smcscs.spikeCount;
       string extra = "Dow=" + DoubleToString(dow,2) + " chain=" + chainType;
       SendSR20WhatsAppSignal("CHAIN_SIGNAL", symbol, dir, entry, sl, tp3, refPx,
                              0, "", atr, conf, sc, extra);
    }
}

#endif // SMC_SPIKE_CHAIN_SIGNAL_MQH
