//+------------------------------------------------------------------+
//| SMC_SpikeRanker.mqh — Classement opportunités spike par symbole  |
//| Calcule Spike Probability Score + Dashboard + Notifications      |
//+------------------------------------------------------------------+
#ifndef TM_SPIKE_RANKER_MQH
#define TM_SPIKE_RANKER_MQH

#include "TMState.mqh"

// ═══════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════

// Poix pour le Score de Probabilité Spike (total = 100)
#define SPIKE_W_IMMINENCE    30.0   // Imminence % du serveur
#define SPIKE_W_PRE_SPIKE    20.0   // Compression pré-spike
#define SPIKE_W_FREQ         20.0   // Fréquence des spikes
#define SPIKE_W_GOM_QUALITY  15.0   // Qualité GOM
#define SPIKE_W_ATR_MOMENTUM 15.0   // Momentum ATR

// Seuils
#define SPIKE_MIN_SCORE_NOTIFY  70.0  // Score min pour notification
#define SPIKE_MIN_SCORE_TRADE   75.0  // Score min pour trader
#define SPIKE_IMMINENCE_HIGH    60.0  // Imminence "haute"
#define SPIKE_EST_MIN_URGENT    5.0   // Minutes estimées "urgent"

// ═══════════════════════════════════════════════════════════════════
// VARIABLES GLOBALES
// ═══════════════════════════════════════════════════════════════════

// Dernière notification envoyée par symbole (pour éviter le spam)
datetime g_spikeRankerLastNotifTime[];
string   g_spikeRankerLastNotifSymbol[];

// Dashboard
#define SPIKE_DASH_PREFIX "SPIKE_RANK_"
#define SPIKE_DASH_MAX_ROWS 8

// ═══════════════════════════════════════════════════════════════════
// CALCUL SPIKE PROBABILITY SCORE
// ═══════════════════════════════════════════════════════════════════

double SpikeRanker_CalcProbabilityScore(
   double imminencePct,
   double preSpikePct,
   int    barsSinceSpike,
   int    spikeFreqBars,
   double gomQuality,
   double gomCoherence,
   double atrM1,
   double atrM5)
{
   double score = 0;

   // 1. IMMINENCE (0-100) — Poids 30%
   // Plus c'est haut, plus le spike est proche
   double imminenceScore = MathMin(100.0, imminencePct);
   score += imminenceScore * (SPIKE_W_IMMINENCE / 100.0);

   // 2. PRE-SPIKE COMPRESSION (0-100) — Poids 20%
   // Plus c'est compressé, plus le "ressort" est tendu
   double preSpikeScore = MathMin(100.0, preSpikePct);
   score += preSpikeScore * (SPIKE_W_PRE_SPIKE / 100.0);

   // 3. FRÉQUENCE SPIKE (0-100) — Poids 20%
   // Basé sur: barsSinceSpike / spikeFreqBars
   // Si on est proche de la fréquence moyenne, score élevé
   double freqScore = 0;
   if(spikeFreqBars > 0 && barsSinceSpike >= 0)
   {
      double ratio = (double)barsSinceSpike / (double)spikeFreqBars;
      if(ratio >= 1.0)
         freqScore = 100.0; // On est en retard → spike probable
      else if(ratio >= 0.8)
         freqScore = 80.0 + (ratio - 0.8) * 100.0;
      else if(ratio >= 0.5)
         freqScore = 50.0 + (ratio - 0.5) * 100.0;
      else
         freqScore = ratio * 100.0;
   }
   score += freqScore * (SPIKE_W_FREQ / 100.0);

   // 4. GOM QUALITY × COHERENCE (0-100) — Poids 15%
   double gomScore = (gomQuality * 0.6 + gomCoherence * 0.4);
   gomScore = MathMin(100.0, gomScore);
   score += gomScore * (SPIKE_W_GOM_QUALITY / 100.0);

   // 5. ATR MOMENTUM (0-100) — Poids 15%
   // Si ATR M1 > ATR M5 → momentum en hausse
   double atrMomentumScore = 50.0;
   if(atrM1 > 0 && atrM5 > 0)
   {
      double ratio = atrM1 / atrM5;
      if(ratio > 1.5) atrMomentumScore = 95.0;
      else if(ratio > 1.2) atrMomentumScore = 80.0;
      else if(ratio > 1.0) atrMomentumScore = 65.0;
      else if(ratio > 0.8) atrMomentumScore = 40.0;
      else atrMomentumScore = 20.0;
   }
   score += atrMomentumScore * (SPIKE_W_ATR_MOMENTUM / 100.0);

   return MathMin(100.0, MathMax(0.0, score));
}

// ═══════════════════════════════════════════════════════════════════
// ESTIMATION TEMPS AVANT SPIKE
// ═══════════════════════════════════════════════════════════════════

double SpikeRanker_EstMinutesToSpike(
   int    barsSinceSpike,
   int    spikeFreqBars,
   double imminencePct)
{
   if(spikeFreqBars <= 0) return 999;

   // Estimation basée sur la fréquence
   int remainingBars = spikeFreqBars - barsSinceSpike;
   if(remainingBars <= 0) return 0.5; // Très proche

   // Chaque bar M1 = 1 minute approximativement
   double estMinutes = (double)remainingBars;

   // Ajuster par l'imminence
   // Si imminence est haute, réduire le temps estimé
   if(imminencePct > 0)
   {
      double imminenceFactor = 1.0 - (imminencePct / 100.0) * 0.5;
      estMinutes *= imminenceFactor;
   }

   return MathMax(0.5, estMinutes);
}

// ═══════════════════════════════════════════════════════════════════
// CLASSEMENT DES OPPORTUNITÉS
// ═══════════════════════════════════════════════════════════════════

void SpikeRanker_UpdateScores()
{
   for(int i = 0; i < g_state.scanner.count; i++)
   {
       TMScannerOpportunity opp = g_state.scanner.opportunities[i];

       // Calculer le spike score
      opp.spikeScore = SpikeRanker_CalcProbabilityScore(
         opp.imminencePct,
         opp.preSpikePct,
         opp.barsSinceSpike,
         opp.spikeFreqBars,
         opp.gomScore,
         opp.sessionScore, // Utiliser session comme proxy cohérence
         0, 0); // ATR sera mis à jour séparément

      // Estimation temps
      opp.estMinutesToSpike = SpikeRanker_EstMinutesToSpike(
         opp.barsSinceSpike,
         opp.spikeFreqBars,
         opp.imminencePct);
   }

   // Trier par spikeScore (bubble sort)
   for(int i = 0; i < g_state.scanner.count - 1; i++)
   {
      for(int j = i + 1; j < g_state.scanner.count; j++)
      {
         if(g_state.scanner.opportunities[j].spikeScore >
            g_state.scanner.opportunities[i].spikeScore)
         {
            TMScannerOpportunity tmp = g_state.scanner.opportunities[i];
            g_state.scanner.opportunities[i] = g_state.scanner.opportunities[j];
            g_state.scanner.opportunities[j] = tmp;
         }
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
// OBTENIR LE MEILLEUR SYMBOLE
// ═══════════════════════════════════════════════════════════════════

bool SpikeRanker_GetBest(TMScannerOpportunity &out)
{
   if(g_state.scanner.count == 0) return false;
   out = g_state.scanner.opportunities[0];
   return (out.spikeScore >= SPIKE_MIN_SCORE_TRADE);
}

bool SpikeRanker_GetTopN(int n, TMScannerOpportunity &out[])
{
   int count = MathMin(n, g_state.scanner.count);
   ArrayResize(out, count);
   for(int i = 0; i < count; i++)
      out[i] = g_state.scanner.opportunities[i];
   return (count > 0);
}

// ═══════════════════════════════════════════════════════════════════
// NOTIFICATIONS INTELLIGENTES
// ═══════════════════════════════════════════════════════════════════

bool SpikeRanker_ShouldNotify(const string symbol, double spikeScore, double estMinutes)
{
   if(spikeScore < SPIKE_MIN_SCORE_NOTIFY) return false;
   if(estMinutes > 15) return false; // Trop loin

   // Vérifier si on a déjà notifié ce symbole récemment (cooldown 5 min)
   for(int i = 0; i < ArraySize(g_spikeRankerLastNotifSymbol); i++)
   {
      if(g_spikeRankerLastNotifSymbol[i] == symbol)
      {
         if(TimeCurrent() - g_spikeRankerLastNotifTime[i] < 300)
            return false; // Déjà notifié il y a < 5 min
         break;
      }
   }
   return true;
}

void SpikeRanker_RecordNotification(const string symbol)
{
   int size = ArraySize(g_spikeRankerLastNotifSymbol);
   ArrayResize(g_spikeRankerLastNotifSymbol, size + 1);
   ArrayResize(g_spikeRankerLastNotifTime, size + 1);
   g_spikeRankerLastNotifSymbol[size] = symbol;
   g_spikeRankerLastNotifTime[size] = TimeCurrent();
}

string SpikeRanker_BuildNotifMessage(const TMScannerOpportunity &opp)
{
   string dir = (opp.direction > 0) ? "BUY" : "SELL";
   string urgency = "";
   if(opp.estMinutesToSpike <= 3) urgency = " URGENT";
   else if(opp.estMinutesToSpike <= 7) urgency = " RAPIDE";

   return StringFormat(
      "SPIKE %s %s%s\n"
      "Score: %.0f/100 | Imminence: %.0f%%\n"
      "Est: ~%.0f min | Freq: %d bars",
      opp.symbol, dir, urgency,
      opp.spikeScore, opp.imminencePct,
      opp.estMinutesToSpike, opp.spikeFreqBars);
}

// ═══════════════════════════════════════════════════════════════════
// DASHBOARD VISUEL
// ═══════════════════════════════════════════════════════════════════

void SpikeRanker_DrawDashboard()
{
   int x = 10;
   int y = 30;
   int rowH = 18;
   color bgColor = clrBlack;

   // Titre
   ObjectCreate(0, SPIKE_DASH_PREFIX + "TITLE", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "TITLE", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "TITLE", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "TITLE", OBJPROP_YDISTANCE, y);
   ObjectSetString(0, SPIKE_DASH_PREFIX + "TITLE", OBJPROP_TEXT,
                   "SPIKE RANKER — Top Opportunities");
   ObjectSetString(0, SPIKE_DASH_PREFIX + "TITLE", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "TITLE", OBJPROP_FONTSIZE, 11);
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "TITLE", OBJPROP_COLOR, clrGold);
   y += rowH + 5;

   // En-tête
   string header = StringFormat("%-12s %-5s %-6s %-8s %-8s %-10s",
                               "Symbol", "Dir", "Score", "Immin", "EstMin", "Status");
   ObjectCreate(0, SPIKE_DASH_PREFIX + "HDR", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "HDR", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "HDR", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "HDR", OBJPROP_YDISTANCE, y);
   ObjectSetString(0, SPIKE_DASH_PREFIX + "HDR", OBJPROP_TEXT, header);
   ObjectSetString(0, SPIKE_DASH_PREFIX + "HDR", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "HDR", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "HDR", OBJPROP_COLOR, clrGray);
   y += rowH;

   // Lignes
   int maxRows = MathMin(SPIKE_DASH_MAX_ROWS, g_state.scanner.count);
   for(int i = 0; i < maxRows; i++)
   {
      TMScannerOpportunity opp = g_state.scanner.opportunities[i];
      string prefix = SPIKE_DASH_PREFIX + "ROW_" + IntegerToString(i);

      string dir = (opp.direction > 0) ? "BUY" : "SELL";
      string status = "";
      color rowColor = clrWhite;

      if(opp.spikeScore >= SPIKE_MIN_SCORE_TRADE)
      {
         if(opp.estMinutesToSpike <= 3)
         {
            status = "🔥 URGENT";
            rowColor = clrRed;
         }
         else if(opp.estMinutesToSpike <= 7)
         {
            status = "⚡ RAPIDE";
            rowColor = clrOrange;
         }
         else
         {
            status = "✓ PRêt";
            rowColor = clrLime;
         }
      }
      else if(opp.spikeScore >= SPIKE_MIN_SCORE_NOTIFY)
      {
         status = "~ Attente";
         rowColor = clrYellow;
      }
      else
      {
         status = "- Faible";
         rowColor = clrGray;
      }

      string line = StringFormat("%-12s %-5s %5.0f   %5.0f%%   %5.0f    %s",
                                opp.symbol, dir, opp.spikeScore,
                                opp.imminencePct, opp.estMinutesToSpike, status);

      ObjectCreate(0, prefix, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, prefix, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, prefix, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, prefix, OBJPROP_YDISTANCE, y + i * rowH);
      ObjectSetString(0, prefix, OBJPROP_TEXT, line);
      ObjectSetString(0, prefix, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, prefix, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, prefix, OBJPROP_COLOR, rowColor);
   }

   // Lignes vides si moins de résultats
   for(int i = maxRows; i < SPIKE_DASH_MAX_ROWS; i++)
   {
      string prefix = SPIKE_DASH_PREFIX + "ROW_" + IntegerToString(i);
      ObjectCreate(0, prefix, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, prefix, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, prefix, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, prefix, OBJPROP_YDISTANCE, y + i * rowH);
      ObjectSetString(0, prefix, OBJPROP_TEXT, "");
   }

   // Dernière mise à jour
   ObjectCreate(0, SPIKE_DASH_PREFIX + "TIME", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "TIME", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "TIME", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "TIME", OBJPROP_YDISTANCE, y + maxRows * rowH + 10);
   ObjectSetString(0, SPIKE_DASH_PREFIX + "TIME", OBJPROP_TEXT,
                   "Scan: " + TimeToString(TimeCurrent(), TIME_SECONDS));
   ObjectSetString(0, SPIKE_DASH_PREFIX + "TIME", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "TIME", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, SPIKE_DASH_PREFIX + "TIME", OBJPROP_COLOR, clrDarkGray);
}

void SpikeRanker_ClearDashboard()
{
   ObjectsDeleteAll(0, SPIKE_DASH_PREFIX);
}

// ═══════════════════════════════════════════════════════════════════
// LOG SPÉCIALISÉ
// ═══════════════════════════════════════════════════════════════════

void SpikeRanker_LogTopOpportunities()
{
   if(g_state.scanner.count == 0) return;

   Print("═══ SPIKE RANKER — Top Opportunités ═══");
   int maxShow = MathMin(5, g_state.scanner.count);
   for(int i = 0; i < maxShow; i++)
   {
      TMScannerOpportunity opp = g_state.scanner.opportunities[i];
      string dir = (opp.direction > 0) ? "BUY" : "SELL";
      Print(StringFormat("  #%d %s %s | Score=%.0f Immin=%.0f%% Est=%.0fmin",
                        i + 1, opp.symbol, dir,
                        opp.spikeScore, opp.imminencePct,
                        opp.estMinutesToSpike));
   }
   Print("═══════════════════════════════════════");
}

#endif // TM_SPIKE_RANKER_MQH
