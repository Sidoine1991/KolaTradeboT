//+------------------------------------------------------------------+
//| SMC_PredictiveEngine.mqh — Moteur prédictif MTF                 |
//| Remplace la détection réactive par des prédictions directionnelles|
//| Phase 1: Correction Predictor + Spike Series Predictor           |
//+------------------------------------------------------------------+
#ifndef SMC_PREDICTIVE_ENGINE_MQH
#define SMC_PREDICTIVE_ENGINE_MQH

// ── États prédictifs ─────────────────────────────────────────────
enum ENUM_PREDICTION_STATE
{
   PRED_NONE,        // Pas de prédiction active
   PRED_FORMING,     // Correction/spike en formation (début)
   PRED_LIKE,        // Formation probable (milieu, structure intacte)
   PRED_RIPE,        // Quasi terminé, prêt pour entrée
   PRED_FIRE,        // Signal d'entrée valide
   PRED_SERIES,      // Série de spikes active (ré-entrée possible)
   PRED_EXPIRED      // Prédiction expirée (trop vieux)
};

// ── État prédictif par symbole ────────────────────────────────────
struct SMC_PredictiveState
{
   ENUM_PREDICTION_STATE  corrState;          // État correction
   ENUM_PREDICTION_STATE  spikeState;         // État série spikes
   double                 exhaustionScore;    // 0-100, épuisement correction
   double                 trendAlignment;     // -100 à +100 (négatif = contre-tendance)
   double                 volatilityRatio;    // ATR M1 / ATR M15 (>1 = expansion)
   double                 momentumDivergence; // Divergence RSI/price
   double                 spikeProbability;   // 0-100, proba prochain spike
   double                 confidence;         // 0-100, confiance globale
   int                    barsToExpiry;       // Bars restants avant expiration
   int                    spikeSeriesCount;   // Nombre spikes dans série
   double                 spikeDeclineRatio;  // ATR courant / ATR précédent série
   datetime               lastUpdate;         // Dernière mise à jour
   string                 label;              // Label affichage
};

// État par symbole (max 8 symboles simultanés)
#define PRED_MAX_SYMBOLS 8
SMC_PredictiveState g_predState[];
string              g_predSymbols[];
int                 g_predCount = 0;

// ── Inputs ────────────────────────────────────────────────────────
input group "=== PREDICTIVE ENGINE ==="
input bool   UsePredictiveEngine      = true;   // Activer le moteur prédictif
input int    PredExhaustionLookback   = 20;     // Bougies M5 pour score exhaustion
input int    PredSpikeLookbackM1      = 15;     // Bougies M1 pour drift pré-spike
input double PredExhaustionThreshold  = 70.0;   // Seuil exhaustion -> RIPE
input double PredFireThreshold        = 85.0;   // Seuil -> FIRE (entrée)
input int    PredExpiryBars           = 50;     // Expiration prédiction (bars M5)
input double PredMinConfidence        = 55.0;   // Confiance minimale pour RIPE+
input bool   PredShowOverlay          = true;   // Afficher overlay prédictif
input bool   PredReplaceOldCorrGate   = true;   // Remplacer l'ancien gate correction

//+------------------------------------------------------------------+
//| Helpers                                                           |
//+------------------------------------------------------------------+
double SMC_PE_GetATR(const string symbol, ENUM_TIMEFRAMES tf, int period = 14)
{
   int h = iATR(symbol, tf, period);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   double val = 0.0;
   if(CopyBuffer(h, 0, 0, 1, buf) >= 1)
      val = buf[0];
   IndicatorRelease(h);
   return val;
}

double SMC_PE_GetRSI(const string symbol, ENUM_TIMEFRAMES tf, int period = 14)
{
   int h = iRSI(symbol, tf, period, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 50.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   double val = 50.0;
   if(CopyBuffer(h, 0, 0, 1, buf) >= 1)
      val = buf[0];
   IndicatorRelease(h);
   return val;
}

double SMC_PE_GetEMA(const string symbol, ENUM_TIMEFRAMES tf, int period, int shift = 0)
{
   int h = iMA(symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   double val = 0.0;
   if(CopyBuffer(h, 0, shift, 1, buf) >= 1)
      val = buf[0];
   IndicatorRelease(h);
   return val;
}

//+------------------------------------------------------------------+
//| Trouver ou créer l'index d'un symbole                             |
//+------------------------------------------------------------------+
int SMC_PE_FindIndex(const string symbol)
{
   for(int i = 0; i < g_predCount; i++)
   {
      if(g_predSymbols[i] == symbol)
         return i;
   }
   if(g_predCount >= PRED_MAX_SYMBOLS)
      return -1;
   int idx = g_predCount;
   g_predCount++;
   ArrayResize(g_predState, g_predCount);
   ArrayResize(g_predSymbols, g_predCount);
   g_predSymbols[idx] = symbol;
   ZeroMemory(g_predState[idx]);
   g_predState[idx].corrState = PRED_NONE;
   g_predState[idx].spikeState = PRED_NONE;
   return idx;
}

//+------------------------------------------------------------------+
//| Trend alignment MTF (H4/H1/M15/M5/M1 vs direction)              |
//| Retourne -100 à +100                                           |
//+------------------------------------------------------------------+
double SMC_PE_CalcTrendAlignment(const string symbol, const int dirSign)
{
   if(dirSign == 0) return 0.0;

   int aligned = 0;
   int total = 0;

   // H4 vs EMA50
   double h4Ema = SMC_PE_GetEMA(symbol, PERIOD_H4, 50);
   MqlRates h4r[];
   ArraySetAsSeries(h4r, true);
   if(h4Ema > 0 && CopyRates(symbol, PERIOD_H4, 0, 1, h4r) >= 1)
   {
      total++;
      if((h4r[0].close > h4Ema && dirSign == 1) ||
         (h4r[0].close < h4Ema && dirSign == -1))
         aligned++;
   }

   // H1 EMA21 slope
   double h1Ema0 = SMC_PE_GetEMA(symbol, PERIOD_H1, 21, 0);
   double h1Ema4 = SMC_PE_GetEMA(symbol, PERIOD_H1, 21, 4);
   if(h1Ema0 > 0 && h1Ema4 > 0)
   {
      total++;
      int h1Dir = (h1Ema0 > h1Ema4) ? 1 : -1;
      if(h1Dir == dirSign) aligned++;
   }

   // M15 RSI
   double m15Rsi = SMC_PE_GetRSI(symbol, PERIOD_M15);
   total++;
    if((m15Rsi > 55 && dirSign == 1) || (m15Rsi < 45 && dirSign == -1))
       aligned++;
    // contre-tendance = non aligné (rien à faire)

   // M5 EMA9 slope
   double m5Ema0 = SMC_PE_GetEMA(symbol, PERIOD_M5, 9, 0);
   double m5Ema4 = SMC_PE_GetEMA(symbol, PERIOD_M5, 9, 4);
   if(m5Ema0 > 0 && m5Ema4 > 0)
   {
      total++;
      int m5Dir = (m5Ema0 > m5Ema4) ? 1 : -1;
      if(m5Dir == dirSign) aligned++;
   }

   // M1 EMA9 slope
   double m1Ema0 = SMC_PE_GetEMA(symbol, PERIOD_M1, 9, 0);
   double m1Ema4 = SMC_PE_GetEMA(symbol, PERIOD_M1, 9, 4);
   if(m1Ema0 > 0 && m1Ema4 > 0)
   {
      total++;
      int m1Dir = (m1Ema0 > m1Ema4) ? 1 : -1;
      if(m1Dir == dirSign) aligned++;
   }

   if(total == 0) return 0.0;
   return ((double)aligned / total) * 100.0 * dirSign;
}

//+------------------------------------------------------------------+
//| Score d'épuisement correction (0-100)                           |
//| Plus haut = correction avancée, bientôt terminée                |
//+------------------------------------------------------------------+
double SMC_PE_CalcExhaustionScore(const string symbol, const int dirSign)
{
   if(dirSign == 0) return 0.0;

   double score = 0.0;

   // 1. RSI M1 en zone de rebond (30 pts max)
   double rsiM1 = SMC_PE_GetRSI(symbol, PERIOD_M1);
   if(dirSign == 1)
   {
      // BUY : RSI bas = correction profonde, RSI qui remonte = exhaustion
      if(rsiM1 < 35) score += 25.0;
      else if(rsiM1 < 45) score += 15.0;
      else if(rsiM1 > 55) score += 5.0;   // sortie de correction
   }
   else
   {
      // SELL : RSI haut = correction profonde
      if(rsiM1 > 65) score += 25.0;
      else if(rsiM1 > 55) score += 15.0;
      else if(rsiM1 < 45) score += 5.0;
   }

   // 2. RSI M5 tendance (20 pts max)
   double rsiM5 = SMC_PE_GetRSI(symbol, PERIOD_M5);
   if(dirSign == 1 && rsiM5 < 40) score += 20.0;
   else if(dirSign == -1 && rsiM5 > 60) score += 20.0;
   else if(dirSign == 1 && rsiM5 < 50) score += 10.0;
   else if(dirSign == -1 && rsiM5 > 50) score += 10.0;

   // 3. M1 vs M5 divergence (rebond M1 mais M5 encore contre = milieu correction) (25 pts)
   double m1Ema0 = SMC_PE_GetEMA(symbol, PERIOD_M1, 9, 0);
   double m1Ema4 = SMC_PE_GetEMA(symbol, PERIOD_M1, 9, 4);
   double m5Ema0 = SMC_PE_GetEMA(symbol, PERIOD_M5, 9, 0);
   double m5Ema4 = SMC_PE_GetEMA(symbol, PERIOD_M5, 9, 4);

   if(m1Ema0 > 0 && m1Ema4 > 0 && m5Ema0 > 0 && m5Ema4 > 0)
   {
      int m1Dir = (m1Ema0 > m1Ema4) ? 1 : -1;
      int m5Dir = (m5Ema0 > m5Ema4) ? 1 : -1;

      if(m1Dir == dirSign && m5Dir == -dirSign)
         score += 20.0;  // M1 commence à revenir = début exhaustion
      else if(m1Dir == dirSign && m5Dir == dirSign)
         score += 25.0;  // M1+M5 réalignés = fin correction
      else if(m1Dir == -dirSign && m5Dir == -dirSign)
         score += 5.0;   // encore pleine correction
   }

   // 4. ATR compression puis expansion (25 pts)
   double peAtrM1  = SMC_PE_GetATR(symbol, PERIOD_M1);
   double peAtrM5  = SMC_PE_GetATR(symbol, PERIOD_M5);
   double peAtrM15 = SMC_PE_GetATR(symbol, PERIOD_M15);
   if(peAtrM1 > 0 && peAtrM15 > 0)
   {
      double ratio = peAtrM1 / peAtrM15;
      if(ratio > 1.2) score += 20.0;       // expansion = résolution
      else if(ratio > 0.9) score += 12.0;  // normalisation
      else if(ratio < 0.5) score += 8.0;   // compression = consolidation
   }
   if(peAtrM1 > 0 && peAtrM5 > 0)
   {
      double m1m5 = peAtrM1 / peAtrM5;
      if(m1m5 > 1.3) score += 5.0;  // M1 explose = résolution
   }

   return MathMin(100.0, MathMax(0.0, score));
}

//+------------------------------------------------------------------+
//| Momentum divergence M1 (RSI vs price)                           |
//| Retourne -100 à +100                                           |
//+------------------------------------------------------------------+
double SMC_PE_CalcMomentumDivergence(const string symbol, const int dirSign)
{
   if(dirSign == 0) return 0.0;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(symbol, PERIOD_M1, 0, 10, r);
   if(n < 6) return 0.0;

   // Price direction sur 5 bougies
   double priceDelta = r[0].close - r[4].close;

   // RSI direction sur 5 bougies
   double rsi0 = SMC_PE_GetRSI(symbol, PERIOD_M1);
   // Approximation: comparer RSI actuel vs price
   // Si price monte mais RSI baisse = divergence bearish
   double div = 0.0;
   if(dirSign == 1)
   {
      // BUY: positif si momentum confirme la hausse
      if(priceDelta > 0 && rsi0 > 50) div = 30.0;
      else if(priceDelta > 0 && rsi0 < 45) div = -20.0;  // divergence bearish
      else if(priceDelta < 0 && rsi0 < 35) div = 15.0;   // oversold = opportunité
      else if(priceDelta < 0 && rsi0 > 55) div = -15.0;
   }
   else
   {
      if(priceDelta < 0 && rsi0 < 50) div = 30.0;
      else if(priceDelta < 0 && rsi0 > 55) div = -20.0;
      else if(priceDelta > 0 && rsi0 > 65) div = 15.0;
      else if(priceDelta > 0 && rsi0 < 45) div = -15.0;
   }

   return MathMin(100.0, MathMax(-100.0, div));
}

//+------------------------------------------------------------------+
//| Volatility ratio M1/M15 (>1 = expansion imminente)              |
//+------------------------------------------------------------------+
double SMC_PE_CalcVolatilityRatio(const string symbol)
{
   double peAtrM1  = SMC_PE_GetATR(symbol, PERIOD_M1);
   double peAtrM15 = SMC_PE_GetATR(symbol, PERIOD_M15);
   if(peAtrM15 <= 0) return 1.0;
   return peAtrM1 / peAtrM15;
}

//+------------------------------------------------------------------+
//| Spike probability (drift M1 typique pré-spike Boom/Crash)       |
//| Retourne 0-100                                                   |
//+------------------------------------------------------------------+
double SMC_PE_CalcSpikeProbability(const string symbol)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(symbol, PERIOD_M1, 1, PredSpikeLookbackM1, r);
   if(n < 5) return 0.0;

   double score = 0.0;

   // 1. Drift lent (petites bougies) = typique pré-spike (30 pts)
   double avgBody = 0.0;
   double peAtrM1 = SMC_PE_GetATR(symbol, PERIOD_M1);
   for(int i = 0; i < n; i++)
      avgBody += MathAbs(r[i].close - r[i].open);
   avgBody /= n;

   if(peAtrM1 > 0 && avgBody < peAtrM1 * 0.35)
      score += 30.0;  // drift lent détecté
   else if(peAtrM1 > 0 && avgBody < peAtrM1 * 0.50)
      score += 15.0;

   // 2. Conséquence de petites bougies (20 pts)
   int smallCount = 0;
   for(int i = 0; i < MathMin(8, n); i++)
   {
      if(peAtrM1 > 0 && MathAbs(r[i].close - r[i].open) < peAtrM1 * 0.30)
         smallCount++;
   }
   if(smallCount >= 6) score += 20.0;
   else if(smallCount >= 4) score += 10.0;

   // 3. Compression ATR (25 pts)
   double peAtrM5 = SMC_PE_GetATR(symbol, PERIOD_M5);
   if(peAtrM5 > 0 && peAtrM1 > 0)
   {
      double ratio = peAtrM1 / peAtrM5;
      if(ratio < 0.6) score += 25.0;      // forte compression
      else if(ratio < 0.8) score += 15.0; // compression modérée
   }

   // 4. Serveur data (25 pts)
   if(g_smcGomImminencePct > 70) score += 20.0;
   else if(g_smcGomImminencePct > 50) score += 12.0;
   if(g_smcPreSpikePct > 50) score += 5.0;

   return MathMin(100.0, MathMax(0.0, score));
}

//+------------------------------------------------------------------+
//| Évaluation principale — met à jour l'état prédictif             |
//+------------------------------------------------------------------+
void SMC_PE_Evaluate(const string symbol, const int dirSign)
{
   int idx = SMC_PE_FindIndex(symbol);
   if(idx < 0) return;

   

   g_predState[idx].lastUpdate = TimeCurrent();
   g_predState[idx].trendAlignment    = SMC_PE_CalcTrendAlignment(symbol, dirSign);
   g_predState[idx].exhaustionScore   = SMC_PE_CalcExhaustionScore(symbol, dirSign);
   g_predState[idx].volatilityRatio   = SMC_PE_CalcVolatilityRatio(symbol);
   g_predState[idx].momentumDivergence = SMC_PE_CalcMomentumDivergence(symbol, dirSign);
   g_predState[idx].spikeProbability  = SMC_PE_CalcSpikeProbability(symbol);

   // ── Déterminer l'état correction ──────────────────────────────
   // Le calcul est direction-agnostique : on évalue l'épuisement
   // de la correction CONTRE la direction visée.
   double exh = g_predState[idx].exhaustionScore;
   double align = MathAbs(g_predState[idx].trendAlignment);

   if(exh >= PredFireThreshold && align > 40)
   {
      g_predState[idx].corrState = PRED_FIRE;
      g_predState[idx].confidence = (exh + align) / 2.0;
   }
   else if(exh >= PredExhaustionThreshold && align > 30)
   {
      g_predState[idx].corrState = PRED_RIPE;
      g_predState[idx].confidence = (exh + align) / 2.0;
   }
   else if(exh >= 40.0 && align > 20)
   {
      g_predState[idx].corrState = PRED_LIKE;
      g_predState[idx].confidence = (exh + align) / 2.0;
   }
   else if(exh >= 15.0)
   {
      g_predState[idx].corrState = PRED_FORMING;
      g_predState[idx].confidence = exh;
   }
   else
   {
      // Pas de correction détectée ou trop tôt
      // Si M1 ET M5 contre = correction active mais épuisement inconnu
      double m1Ema0 = SMC_PE_GetEMA(symbol, PERIOD_M1, 9, 0);
      double m1Ema4 = SMC_PE_GetEMA(symbol, PERIOD_M1, 9, 4);
      double m5Ema0 = SMC_PE_GetEMA(symbol, PERIOD_M5, 9, 0);
      double m5Ema4 = SMC_PE_GetEMA(symbol, PERIOD_M5, 9, 4);

      bool m1Against = false;
      bool m5Against = false;
      if(m1Ema0 > 0 && m1Ema4 > 0)
      {
         int m1d = (m1Ema0 > m1Ema4) ? 1 : -1;
         m1Against = (m1d == -dirSign);
      }
      if(m5Ema0 > 0 && m5Ema4 > 0)
      {
         int m5d = (m5Ema0 > m5Ema4) ? 1 : -1;
         m5Against = (m5d == -dirSign);
      }

      if(m1Against || m5Against)
      {
         g_predState[idx].corrState = PRED_FORMING;
         g_predState[idx].confidence = 20.0;
      }
      else
      {
         g_predState[idx].corrState = PRED_NONE;
         g_predState[idx].confidence = 0.0;
      }
   }

   // Expiration
   g_predState[idx].barsToExpiry = PredExpiryBars;
   g_predState[idx].label = "";
   switch(g_predState[idx].corrState)
   {
      case PRED_NONE:     g_predState[idx].label = "---"; break;
      case PRED_FORMING:  g_predState[idx].label = "FORM"; break;
      case PRED_LIKE:     g_predState[idx].label = "LIKE"; break;
      case PRED_RIPE:     g_predState[idx].label = "RIPE"; break;
      case PRED_FIRE:     g_predState[idx].label = "FIRE"; break;
      case PRED_SERIES:   g_predState[idx].label = "SERIES"; break;
      case PRED_EXPIRED:  g_predState[idx].label = "EXPIRED"; break;
   }

   // ── Spike series ──────────────────────────────────────────────
   if(SMCGP_IsBoomCrashSym(symbol) && g_predState[idx].spikeProbability > 60)
   {
      g_predState[idx].spikeState = PRED_SERIES;
      g_predState[idx].spikeSeriesCount = 0;
      if(g_spikeSeries.seriesActive)
      {
         g_predState[idx].spikeSeriesCount = g_spikeSeries.spikeCount;
         g_predState[idx].spikeDeclineRatio = g_spikeSeries.spikeDeclineRatio;
      }
   }
   else
   {
      g_predState[idx].spikeState = PRED_NONE;
      g_predState[idx].spikeSeriesCount = 0;
      g_predState[idx].spikeDeclineRatio = 1.0;
   }
}

//+------------------------------------------------------------------+
//| API : la correction est-elle en état RIPE ou FIRE ?              |
//| Remplace SMC_IsCorrectionZoneForDirection() pour le gate        |
//+------------------------------------------------------------------+
bool SMC_PE_CorrectionAllowsEntry(const string symbol, const int dirSign)
{
   if(!UsePredictiveEngine) return false;
   if(!PredReplaceOldCorrGate) return false;

   int idx = SMC_PE_FindIndex(symbol);
   if(idx < 0) return false;

   

   // Si pas de correction active (PRED_NONE) = pas de blocage
   if(g_predState[idx].corrState == PRED_NONE)
      return true;

   // FIRE = entrée autorisée (correction résolue)
   if(g_predState[idx].corrState == PRED_FIRE)
      return true;

   // RIPE = entrée possible avec score suffisant
   if(g_predState[idx].corrState == PRED_RIPE && g_predState[idx].confidence >= PredMinConfidence)
      return true;

   // Sinon = bloquer
   return false;
}

//+------------------------------------------------------------------+
//| API : la spike series autorise-t-elle une ré-entrée ?            |
//+------------------------------------------------------------------+
bool SMC_PE_SpikeSeriesAllowsEntry(const string symbol)
{
   if(!UsePredictiveEngine) return false;

   int idx = SMC_PE_FindIndex(symbol);
   if(idx < 0) return false;

   

   // Si série active ET déclin (< 0.7 = spikes faiblissants)
   if(g_predState[idx].spikeState == PRED_SERIES && g_predState[idx].spikeDeclineRatio > 0 && g_predState[idx].spikeDeclineRatio < 0.70)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| API : score composite d'entrée prédictive (0-100)               |
//| Utilisé par SMC_EvaluateEntryGate en remplacement du old gate    |
//+------------------------------------------------------------------+
double SMC_PE_GetCompositeScore(const string symbol, const int dirSign)
{
   if(!UsePredictiveEngine) return 0.0;

   int idx = SMC_PE_FindIndex(symbol);
   if(idx < 0) return 0.0;

   

   double score = 0.0;

   // Exhaustion (35%)
   score += g_predState[idx].exhaustionScore * 0.35;

   // Trend alignment (30%)
   double absAlign = MathAbs(g_predState[idx].trendAlignment);
   score += absAlign * 0.30;

   // Momentum divergence (15%)
   double absDiv = MathAbs(g_predState[idx].momentumDivergence);
   score += absDiv * 0.15;

   // Volatility ratio bonus (10%)
   if(g_predState[idx].volatilityRatio > 1.2)
      score += 10.0;
   else if(g_predState[idx].volatilityRatio > 0.9)
      score += 5.0;

   // Spike probability (10%)
   score += g_predState[idx].spikeProbability * 0.10;

   return MathMin(100.0, MathMax(0.0, score));
}

//+------------------------------------------------------------------+
//| Overlay graphique — non-repainting (update in-place)            |
//+------------------------------------------------------------------+
string g_predOverlayPrefix = "SMC_PRED_";

void SMC_PE_DrawOverlay(const string symbol, const int dirSign)
{
   if(!PredShowOverlay) return;
   if(!UsePredictiveEngine) return;

   int idx = SMC_PE_FindIndex(symbol);
   if(idx < 0) return;

   
   int dg = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(bid <= 0) return;

   string prefix = g_predOverlayPrefix + symbol + "_";

   // ── Label état prédictif ──────────────────────────────────────
   string lblName = prefix + "STATE";
   if(ObjectFind(0, lblName) < 0)
   {
      ObjectCreate(0, lblName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, lblName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, lblName, OBJPROP_XDISTANCE, 15);
      ObjectSetInteger(0, lblName, OBJPROP_YDISTANCE, 180);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 11);
      ObjectSetString(0, lblName, OBJPROP_FONT, "Consolas");
   }

   color stateClr = clrDimGray;
   switch(g_predState[idx].corrState)
   {
      case PRED_NONE:    stateClr = clrDimGray; break;
      case PRED_FORMING: stateClr = clrOrange; break;
      case PRED_LIKE:    stateClr = clrYellow; break;
      case PRED_RIPE:    stateClr = clrLimeGreen; break;
      case PRED_FIRE:    stateClr = clrLime; break;
      case PRED_SERIES:  stateClr = clrAqua; break;
      case PRED_EXPIRED: stateClr = clrRed; break;
   }

   string txt = StringFormat("PRED %s | EXH %.0f | ALG %.0f | CONF %.0f",
                             g_predState[idx].label, g_predState[idx].exhaustionScore,
                             g_predState[idx].trendAlignment, g_predState[idx].confidence);
   ObjectSetString(0, lblName, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, stateClr);

   // ── Spike probability ─────────────────────────────────────────
   string spkName = prefix + "SPIKE";
   if(ObjectFind(0, spkName) < 0)
   {
      ObjectCreate(0, spkName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, spkName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, spkName, OBJPROP_XDISTANCE, 15);
      ObjectSetInteger(0, spkName, OBJPROP_YDISTANCE, 200);
      ObjectSetInteger(0, spkName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, spkName, OBJPROP_FONT, "Consolas");
   }

   string spkTxt = StringFormat("SPIKE %.0f%% | VOL x%.2f | MOM %.0f",
                                g_predState[idx].spikeProbability, g_predState[idx].volatilityRatio,
                                g_predState[idx].momentumDivergence);
   ObjectSetString(0, spkName, OBJPROP_TEXT, spkTxt);
   ObjectSetInteger(0, spkName, OBJPROP_COLOR,
                    g_predState[idx].spikeProbability > 60 ? clrAqua : clrDimGray);

   // ── Ligne d'état (zone colorée) ──────────────────────────────
   string zoneName = prefix + "ZONE";
   if(g_predState[idx].corrState != PRED_NONE)
   {
      if(ObjectFind(0, zoneName) < 0)
      {
         ObjectCreate(0, zoneName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, zoneName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, zoneName, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(0, zoneName, OBJPROP_YDISTANCE, 170);
         ObjectSetInteger(0, zoneName, OBJPROP_XSIZE, 300);
         ObjectSetInteger(0, zoneName, OBJPROP_YSIZE, 45);
         ObjectSetInteger(0, zoneName, OBJPROP_BGCOLOR, clrBlack);
         ObjectSetInteger(0, zoneName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, zoneName, OBJPROP_BORDER_COLOR, stateClr);
         ObjectSetInteger(0, zoneName, OBJPROP_BACK, false);
      }
      ObjectSetInteger(0, zoneName, OBJPROP_BORDER_COLOR, stateClr);
   }
   else
   {
      ObjectDelete(0, zoneName);
   }
}

//+------------------------------------------------------------------+
//| Supprimer l'overlay                                               |
//+------------------------------------------------------------------+
void SMC_PE_CleanupOverlay(const string symbol = "")
{
   string prefix = g_predOverlayPrefix;
   if(StringLen(symbol) > 0)
      prefix += symbol + "_";
   ObjectsDeleteAll(0, prefix);
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
void SMC_PE_Init()
{
   g_predCount = 0;
   ArrayResize(g_predState, 0);
   ArrayResize(g_predSymbols, 0);
   Print("[PRED-ENGINE] Actif=", UsePredictiveEngine ? "ON" : "OFF",
         " | exhaustionThresh=", DoubleToString(PredExhaustionThreshold, 0),
         " | fireThresh=", DoubleToString(PredFireThreshold, 0),
         " | replaceCorrGate=", PredReplaceOldCorrGate ? "ON" : "OFF",
         " | overlay=", PredShowOverlay ? "ON" : "OFF");
}

//+------------------------------------------------------------------+
//| Cleanup                                                           |
//+------------------------------------------------------------------+
void SMC_PE_Deinit()
{
   SMC_PE_CleanupOverlay();
}

//+------------------------------------------------------------------+
//| Test function (appelable depuis EA pour debug)                   |
//+------------------------------------------------------------------+
void SMC_PE_TestPredictiveEngine()
{
   Print("=== PREDICTIVE ENGINE TEST ===");
   SMC_PE_Evaluate(_Symbol, 1);
   int idx = SMC_PE_FindIndex(_Symbol);
   if(idx >= 0)
   {
      
      Print("  State: ", g_predState[idx].label);
      Print("  Exhaustion: ", DoubleToString(g_predState[idx].exhaustionScore, 1));
      Print("  Trend Align: ", DoubleToString(g_predState[idx].trendAlignment, 1));
      Print("  Vol Ratio: ", DoubleToString(g_predState[idx].volatilityRatio, 2));
      Print("  Momentum Div: ", DoubleToString(g_predState[idx].momentumDivergence, 1));
      Print("  Spike Prob: ", DoubleToString(g_predState[idx].spikeProbability, 1));
      Print("  Confidence: ", DoubleToString(g_predState[idx].confidence, 1));
      Print("  Composite: ", DoubleToString(SMC_PE_GetCompositeScore(_Symbol, 1), 1));
      Print("  Allows Entry: ", SMC_PE_CorrectionAllowsEntry(_Symbol, 1) ? "YES" : "NO");
   }
   Print("=== END TEST ===");
}

#endif // SMC_PREDICTIVE_ENGINE_MQH
