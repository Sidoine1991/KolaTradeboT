//+------------------------------------------------------------------+
//| SMC_ZigzagScalper.mqh — Scalping intelligent spikes en zigzag     |
//|                                                                    |
//| Mécanisme:                                                        |
//| 1) Détecte pattern zigzag (alternance spikes direction opposée)    |
//| 2) Prédit prochain spike via extrapolation ISI + momentum          |
//| 3) Entrée scalping rapide sur retracement inter-spike              |
//| 4) Gestion dynamique SL/TP adaptée à la volatilité zigzag          |
//|                                                                    |
//| Intégration avec ChainPredictor pour confirmation chaîne           |
//+------------------------------------------------------------------+
#ifndef SMC_ZIGZAG_SCALPER_MQH
#define SMC_ZIGZAG_SCALPER_MQH

#include "SMC_ChainPredictor.mqh"

//--- Inputs du module ---
input group "=== ZIGZAG SCALPER ==="
input bool   UseZigzagScalper      = true;   // Activer le scalping zigzag
input int    ZigzagMinSpikes       = 3;      // Min spikes pour détecter zigzag
input double ZigzagISICompressThresh = 0.55; // ISI < seuil = zigzag actif
input double ZigzagMomentumThresh = 1.2;    // Momentum minimum pour entrée
input double ZigzagRetracePct      = 0.38;   // Retracement Fib (38.2% typique)
input double ZigzagSlMultATR       = 0.8;    // SL = ATR x 0.8 (scalping serré)
input double ZigzagTp1MultATR      = 1.2;    // TP1 = ATR x 1.2
input double ZigzagTp2MultATR      = 2.0;    // TP2 = ATR x 2.0
input int    ZigzagMaxBarsWait     = 5;      // Max bougies M1 à attendre pour entrée
input bool   ZigzagUseChainConfirm = true;   // Exiger confirmation ChainPredictor

//--- État interne du scalper zigzag ---
struct ZigzagScalper_State
{
   // Historique des spikes pour pattern zigzag
   struct SpikePoint
   {
      datetime time;
      double   price;
      int      direction;  // +1 up, -1 down
      double   amplitude;  // en ATR
   };
   
   SpikePoint spikes[20];  // Ring buffer
   int        spikeCount;
   int        spikeIdx;
   
   // État zigzag actuel
   bool       isZigzagActive;
   int        zigzagDirection;  // Direction dominante du zigzag
   double     avgISI;           // Intervalle inter-spike moyen (secondes)
   double     lastISI;          // Dernier intervalle
   double     isiCompression;   // Ratio lastISI / avgISI
   
   // Métriques momentum
   double     momentumScore;
   double     retraceLevel;     // Niveau de retracement Fib pour entrée
   
   // Timing
   datetime   lastSpikeTime;
   int        barsSinceLastSpike;
   
   // Dernière évaluation
   datetime   lastEvalTime;
   string     status;  // "IDLE", "WAITING_ENTRY", "IN_TRADE", "ZIGZAG_END"
};

ZigzagScalper_State g_zigzag;

//+------------------------------------------------------------------+
//| Initialisation du module                                          |
//+------------------------------------------------------------------+
void ZigzagScalper_Init()
{
   ZeroMemory(g_zigzag);
   g_zigzag.isZigzagActive = false;
   g_zigzag.zigzagDirection = 0;
   g_zigzag.status = "IDLE";
   Print("[ZIGZAG SCALPER] Initialisé | minSpikes=", ZigzagMinSpikes,
         " | ISI_thresh=", ZigzagISICompressThresh);
}

//+------------------------------------------------------------------+
//| Enregistre un spike et met à jour l'état zigzag                  |
//+------------------------------------------------------------------+
void ZigzagScalper_RegisterSpike(datetime spikeTime, double price, 
                                 double amplitudeAtr, int direction)
{
   if(!UseZigzagScalper) return;
   
   // Ajouter au ring buffer
   int idx = g_zigzag.spikeIdx % 20;
   g_zigzag.spikes[idx].time = spikeTime;
   g_zigzag.spikes[idx].price = price;
   g_zigzag.spikes[idx].direction = direction;
   g_zigzag.spikes[idx].amplitude = amplitudeAtr;
   g_zigzag.spikeIdx++;
   if(g_zigzag.spikeCount < 20) g_zigzag.spikeCount++;
   
   // Calculer ISI
   if(g_zigzag.spikeCount >= 2)
   {
      int prevIdx = (g_zigzag.spikeIdx - 2) % 20;
      if(prevIdx < 0) prevIdx += 20;
      g_zigzag.lastISI = (double)(spikeTime - g_zigzag.spikes[prevIdx].time);
      
      // Moyenne ISI sur les 5 derniers
      double isiSum = 0.0;
      int isiCount = 0;
      for(int i = 1; i <= MathMin(5, g_zigzag.spikeCount - 1); i++)
      {
         int idx1 = (g_zigzag.spikeIdx - 1 - i) % 20;
         int idx2 = (g_zigzag.spikeIdx - 1 - (i-1)) % 20;
         if(idx1 < 0) idx1 += 20;
         if(idx2 < 0) idx2 += 20;
         if(g_zigzag.spikes[idx1].time > 0 && g_zigzag.spikes[idx2].time > 0)
         {
            isiSum += (double)(g_zigzag.spikes[idx2].time - g_zigzag.spikes[idx1].time);
            isiCount++;
         }
      }
      if(isiCount > 0)
      {
         g_zigzag.avgISI = isiSum / isiCount;
         g_zigzag.isiCompression = g_zigzag.lastISI / g_zigzag.avgISI;
      }
   }
   
   g_zigzag.lastSpikeTime = spikeTime;
   g_zigzag.barsSinceLastSpike = 0;
   
   // Détecter pattern zigzag
   ZigzagScalper_DetectPattern();
   
   // Calculer niveau de retracement pour prochaine entrée
   ZigzagScalper_CalcRetraceLevel();
   
   Print("[ZIGZAG] Spike #", g_zigzag.spikeCount, " | dir=", 
         (direction > 0 ? "UP" : "DN"), " | ISI=", DoubleToString(g_zigzag.lastISI, 0),
         "s | comp=", DoubleToString(g_zigzag.isiCompression, 2),
         " | status=", g_zigzag.status);
}

//+------------------------------------------------------------------+
//| Détecte si on est dans un pattern zigzag actif                    |
//+------------------------------------------------------------------+
void ZigzagScalper_DetectPattern()
{
   if(g_zigzag.spikeCount < ZigzagMinSpikes)
   {
      g_zigzag.isZigzagActive = false;
      g_zigzag.status = "IDLE";
      return;
   }
   
   // Analyser les derniers ZigzagMinSpikes spikes
   int alternations = 0;
   int directionChanges = 0;
   int lastDir = 0;
   
   for(int i = 1; i <= ZigzagMinSpikes; i++)
   {
      int idx = (g_zigzag.spikeIdx - i) % 20;
      if(idx < 0) idx += 20;
      int dir = g_zigzag.spikes[idx].direction;
      
      if(lastDir != 0 && dir != lastDir)
      {
         directionChanges++;
         alternations++;
      }
      lastDir = dir;
   }
   
   // Zigzag = alternance fréquente (≥ 2 changements sur minSpikes)
   bool isAlternating = (directionChanges >= 2);
   
   // Vérifier compression ISI (zigzag s'accélère)
   bool isiCompressed = (g_zigzag.isiCompression < ZigzagISICompressThresh);
   
   g_zigzag.isZigzagActive = (isAlternating && isiCompressed);
   
   if(g_zigzag.isZigzagActive)
   {
      g_zigzag.status = "WAITING_ENTRY";
      
      // Déterminer direction dominante (plus de spikes dans une direction)
      int upCount = 0, downCount = 0;
      for(int i = 1; i <= ZigzagMinSpikes; i++)
      {
         int idx = (g_zigzag.spikeIdx - i) % 20;
         if(idx < 0) idx += 20;
         if(g_zigzag.spikes[idx].direction > 0) upCount++;
         else downCount++;
      }
      g_zigzag.zigzagDirection = (upCount > downCount) ? 1 : -1;
      
      Print("[ZIGZAG] Pattern détecté | alternations=", directionChanges,
            " | ISI_comp=", DoubleToString(g_zigzag.isiCompression, 2),
            " | dir_dom=", (g_zigzag.zigzagDirection > 0 ? "UP" : "DN"));
   }
   else
   {
      g_zigzag.status = "IDLE";
   }
}

//+------------------------------------------------------------------+
//| Calcule le niveau de retracement Fib pour entrée                  |
//+------------------------------------------------------------------+
void ZigzagScalper_CalcRetraceLevel()
{
   if(g_zigzag.spikeCount < 2) return;
   
   // Utiliser les 2 derniers spikes pour calculer retracement
   int idx1 = (g_zigzag.spikeIdx - 2) % 20;
   int idx2 = (g_zigzag.spikeIdx - 1) % 20;
   if(idx1 < 0) idx1 += 20;
   if(idx2 < 0) idx2 += 20;
   
   double p1 = g_zigzag.spikes[idx1].price;
   double p2 = g_zigzag.spikes[idx2].price;
   int dir2 = g_zigzag.spikes[idx2].direction;
   
   // Retracement Fib 38.2% du mouvement p1->p2
   double move = p2 - p1;
   double retraceAmt = move * ZigzagRetracePct;
   
   // Niveau d'entrée = contre le mouvement (retracement)
   g_zigzag.retraceLevel = p2 - retraceAmt;
   
   // Si dernier spike était UP, on attend retracement DOWN (et inversement)
   // Le niveau est ajusté en conséquence
}

//+------------------------------------------------------------------+
//| Évalue si une entrée scalping est opportune                       |
//+------------------------------------------------------------------+
bool ZigzagScalper_ShouldEnter(int &direction, double &entry, 
                               double &sl, double &tp1, double &tp2)
{
   if(!UseZigzagScalper) return false;
   if(!g_zigzag.isZigzagActive) return false;
   if(g_zigzag.status != "WAITING_ENTRY") return false;
   
   // Vérifier confirmation ChainPredictor si requis
   if(ZigzagUseChainConfirm && !ChainPred_IsPreChain() && !ChainPred_IsUncertainOrBetter())
   {
      return false;
   }
   
   // Vérifier timing (pas trop de bougies depuis dernier spike)
   if(g_zigzag.barsSinceLastSpike > ZigzagMaxBarsWait)
   {
      g_zigzag.status = "ZIGZAG_END";
      return false;
   }
   
   // Obtenir prix courant
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr = ZigzagScalper_GetATR();
   if(atr <= 0) return false;
   
   // Calculer momentum
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 3) return false;
   
   double body0 = MathAbs(rates[0].close - rates[0].open);
   double body1 = MathAbs(rates[1].close - rates[1].open);
   double avgBody = (body0 + body1) / 2.0;
   g_zigzag.momentumScore = body0 / MathMax(avgBody, atr * 0.1);
   
   if(g_zigzag.momentumScore < ZigzagMomentumThresh)
   {
      return false;  // Momentum insuffisant
   }
   
   // Direction = opposée au dernier spike (zigzag)
   int lastIdx = (g_zigzag.spikeIdx - 1) % 20;
   if(lastIdx < 0) lastIdx += 20;
   int lastDir = g_zigzag.spikes[lastIdx].direction;
   direction = -lastDir;  // Contre le dernier spike
   
   // Entry = prix courant (market) ou proche niveau retracement
   entry = (direction > 0) ? ask : bid;
   
   // SL/TP basés sur ATR
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(direction > 0)  // BUY
   {
      sl  = NormalizeDouble(entry - atr * ZigzagSlMultATR, dg);
      tp1 = NormalizeDouble(entry + atr * ZigzagTp1MultATR, dg);
      tp2 = NormalizeDouble(entry + atr * ZigzagTp2MultATR, dg);
   }
   else  // SELL
   {
      sl  = NormalizeDouble(entry + atr * ZigzagSlMultATR, dg);
      tp1 = NormalizeDouble(entry - atr * ZigzagTp1MultATR, dg);
      tp2 = NormalizeDouble(entry - atr * ZigzagTp2MultATR, dg);
   }
   
   g_zigzag.status = "IN_TRADE";
   
   Print("[ZIGZAG] ENTRÉE SCALP | dir=", (direction > 0 ? "BUY" : "SELL"),
         " | entry=", DoubleToString(entry, dg),
         " | SL=", DoubleToString(sl, dg),
         " | TP1=", DoubleToString(tp1, dg),
         " | momentum=", DoubleToString(g_zigzag.momentumScore, 2));
   
   return true;
}

//+------------------------------------------------------------------+
//| Met à jour le compteur de bougies depuis dernier spike            |
//+------------------------------------------------------------------+
void ZigzagScalper_OnNewBar()
{
   if(!UseZigzagScalper) return;
   if(g_zigzag.lastSpikeTime > 0)
   {
      g_zigzag.barsSinceLastSpike++;
      
      // Reset si trop de temps sans spike
      if(g_zigzag.barsSinceLastSpike > ZigzagMaxBarsWait * 2)
      {
         g_zigzag.isZigzagActive = false;
         g_zigzag.status = "ZIGZAG_END";
         Print("[ZIGZAG] Timeout - pattern terminé");
      }
   }
}

//+------------------------------------------------------------------+
//| Signale la fin d'un trade (pour réinitialiser l'état)             |
//+------------------------------------------------------------------+
void ZigzagScalper_OnTradeExit()
{
   if(!UseZigzagScalper) return;
   g_zigzag.status = "WAITING_ENTRY";
}

//+------------------------------------------------------------------+
//| Utilitaire: ATR courant                                           |
//+------------------------------------------------------------------+
double ZigzagScalper_GetATR()
{
   int h = iATR(_Symbol, PERIOD_M1, 14);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   double val = 0.0;
   if(CopyBuffer(h, 0, 0, 1, buf) >= 1)
      val = buf[0];
   IndicatorRelease(h);
   return val;
}

//+------------------------------------------------------------------+
//| API: le zigzag est-il actif ?                                     |
//+------------------------------------------------------------------+
bool ZigzagScalper_IsActive()
{
   return UseZigzagScalper && g_zigzag.isZigzagActive;
}

//+------------------------------------------------------------------+
//| API: score de momentum courant                                    |
//+------------------------------------------------------------------+
double ZigzagScalper_GetMomentum()
{
   return g_zigzag.momentumScore;
}

//+------------------------------------------------------------------+
//| API: ratio ISI courant                                            |
//+------------------------------------------------------------------+
double ZigzagScalper_GetISICompression()
{
   return g_zigzag.isiCompression;
}

#endif // SMC_ZIGZAG_SCALPER_MQH
