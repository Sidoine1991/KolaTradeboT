//+------------------------------------------------------------------+
//| SMC_ChainPredictor.mqh — Moteur prédictif de chaînes de spikes   |
//|                                                                    |
//| 4 sous-modèles combinés en un score "chain_imminence" 0-100 :     |
//|   1) ISI Compression — ratio intervalle inter-spike récent/moyen  |
//|   2) Chain Length P(continue) — décroissance exponentielle         |
//|   3) Regime Classifier — compression ATR + volume + range          |
//|   4) Temporal Clustering — fréquence historique par heure UTC     |
//|                                                                    |
//| Score ≥ 70 → chaîne de 3-4 spikes imminente (entrée agressive)   |
//| Score 40-69 → possible chaîne (entrée conservative)               |
//| Score < 40 → spike isolé probable (pas de chaîne)                 |
//+------------------------------------------------------------------+
#ifndef SMC_CHAIN_PREDICTOR_MQH
#define SMC_CHAIN_PREDICTOR_MQH

//--- Ring buffer pour les timestamps de spikes ---
#define CHAIN_PRED_MAX_SPIKES 20

//--- Inputs du module ---
input group "=== CHAIN PREDICTOR ==="
input bool   UseChainPredictor        = true;   // Activer le moteur prédictif de chaînes
input int    ChainPredMaxSpikes       = 20;     // Nombre max de spikes à mémoriser (ring buffer)
input double ChainPredISICompressThresh = 0.60; // Ratio ISI < seuil → signal fort
input double ChainPredStrongThresh    = 70.0;   // Score ≥ → chaîne imminente (entrée agressive)
input double ChainPredWeakThresh      = 40.0;   // Score ≥ → possible chaîne (entrée conservative)
input bool   ChainPredShowOnChart     = true;   // Afficher le score sur le chart
input bool   ChainPredSoundAlert      = true;   // Bip sonore quand score ≥ seuil fort
input bool   ChainPredSoundWeak       = false;  // Bip sonore quand score ≥ seuil faible
input bool   ChainPredDrawZone        = true;   // Dessiner zone colorée sur chart (PRE_CHAIN)
input bool   ChainPredDrawArrows      = true;   // Flèches d'entrée potentielle
input string ChainPredPeakHours       = "2,3,4,13,14,15,16"; // Heures UTC avec forte fréquence de chaînes

//--- État interne du prédicteur ---
struct ChainPred_SpikeRecord
{
   datetime time;       // Timestamp du spike
   double   amplitude;  // Amplitude en ATR
   int      direction;  // +1 up, -1 down
};

struct ChainPred_State
{
   // Ring buffer de spikes
   ChainPred_SpikeRecord spikes[CHAIN_PRED_MAX_SPIKES];
   int                   spikeCount;         // Nombre total enregistré
   int                   spikeIdx;           // Index courant dans le ring

   // Métriques courantes
   double  isiCompression;     // Ratio ISI récent / historique [0..2]
   double  chainLengthScore;   // Score basé sur la longueur actuelle [0..100]
   double  regimeScore;        // Score régime compression [0..100]
   double  temporalScore;      // Score temporel [0..100]
   double  chainImminence;     // Score combiné final [0..100]

   // État chaîne active
   int     currentChainLen;    // Longueur de la chaîne en cours
   int     currentChainDir;    // Direction de la chaîne en cours
   datetime chainStartTime;    // Début de la chaîne en cours

   // Dernière évaluation
   datetime lastEvalTime;
   string   regime;            // "PRE_CHAIN", "UNCERTAIN", "NORMAL"

   // Alert tracking ( éviter les bips répétés )
   string   prevRegime;        // Régime précédent pour détecter les transitions
   datetime lastAlertTime;     // Dernière alerte sonore envoyée
   bool     zoneDrawn;         // Zone visuelle déjà dessinée
};

ChainPred_State g_chainPred;

//--- Heures de pointe parsées ---
int    g_chainPredPeakHours[];
int    g_chainPredPeakCount = 0;

//+------------------------------------------------------------------+
//| Initialisation du module                                          |
//+------------------------------------------------------------------+
void ChainPred_Init()
{
   ZeroMemory(g_chainPred);
   g_chainPred.currentChainDir = 0;

   // Parser les heures de pointe
   g_chainPredPeakCount = 0;
   string parts[];
   int n = StringSplit(ChainPredPeakHours, ',', parts);
   for(int i = 0; i < n; i++)
   {
      string s = parts[i];
      StringTrimLeft(s);
      StringTrimRight(s);
      int h = (int)StringToInteger(s);
      if(h >= 0 && h <= 23)
      {
         ArrayResize(g_chainPredPeakHours, g_chainPredPeakCount + 1);
         g_chainPredPeakHours[g_chainPredPeakCount] = h;
         g_chainPredPeakCount++;
      }
   }
   Print("[ChainPredictor] Initialisé — peak hours: ", ChainPredPeakHours,
         " | seuils: fort=", ChainPredStrongThresh, " faible=", ChainPredWeakThresh);
}

//+------------------------------------------------------------------+
//| Enregistre un spike détecté et recalcule les scores               |
//+------------------------------------------------------------------+
void ChainPred_RegisterSpike(datetime spikeTime, double amplitudeAtr, int direction)
{
   if(!UseChainPredictor) return;

   // Ajouter au ring buffer
   int idx = g_chainPred.spikeIdx % ChainPredMaxSpikes;
   g_chainPred.spikes[idx].time      = spikeTime;
   g_chainPred.spikes[idx].amplitude = amplitudeAtr;
   g_chainPred.spikes[idx].direction = direction;
   g_chainPred.spikeIdx++;
   if(g_chainPred.spikeCount < ChainPredMaxSpikes)
      g_chainPred.spikeCount++;

   // Mettre à jour la chaîne en cours
   if(g_chainPred.currentChainDir == direction)
   {
      g_chainPred.currentChainLen++;
   }
   else if(g_chainPred.currentChainDir == 0)
   {
      // Début de nouvelle chaîne
      g_chainPred.currentChainDir = direction;
      g_chainPred.currentChainLen = 1;
      g_chainPred.chainStartTime  = spikeTime;
   }
   else
   {
      // Changement de direction → reset chaîne
      g_chainPred.currentChainDir = direction;
      g_chainPred.currentChainLen = 1;
      g_chainPred.chainStartTime  = spikeTime;
   }

   // Recalculer tous les scores
   ChainPred_Evaluate();
}

//+------------------------------------------------------------------+
//| Évaluation complète des 4 sous-modèles                           |
//+------------------------------------------------------------------+
void ChainPred_Evaluate()
{
   if(!UseChainPredictor) return;

   g_chainPred.lastEvalTime = TimeCurrent();

   // 1) ISI Compression
   ChainPred_CalcISICompression();

   // 2) Chain Length Score
   ChainPred_CalcChainLengthScore();

   // 3) Regime Score
   ChainPred_CalcRegimeScore();

   // 4) Temporal Score
   ChainPred_CalcTemporalScore();

   // Score combiné (poids internes, non exposés en inputs pour économiser les slots)
   double lenPts    = g_chainPred.chainLengthScore / 100.0 * 25.0;   // max 25 pts
   double regimePts = g_chainPred.regimeScore / 100.0 * 70.0;         // max 70 pts (ATR 30 + Vol 20 + Body 20)
   double tempPts   = g_chainPred.temporalScore / 100.0 * 15.0;       // max 15 pts

   // Bonus ISI : si ISI compresse, ajoute jusqu'à 15 pts
   double isiBonus = 0.0;
   if(g_chainPred.isiCompression < ChainPredISICompressThresh)
      isiBonus = 15.0;
   else if(g_chainPred.isiCompression < 0.80)
      isiBonus = 8.0;

   g_chainPred.chainImminence = MathMin(100.0, lenPts + regimePts + tempPts + isiBonus);

   // Classifier le régime
   string prevRegime = g_chainPred.regime;
   if(g_chainPred.chainImminence >= ChainPredStrongThresh)
      g_chainPred.regime = "PRE_CHAIN";
   else if(g_chainPred.chainImminence >= ChainPredWeakThresh)
      g_chainPred.regime = "UNCERTAIN";
   else
      g_chainPred.regime = "NORMAL";

   // ═══ ALERTES: bip sonore + zone visuelle ═══
   bool regimeChanged = (g_chainPred.regime != prevRegime);

   // Bip sonore quand on ENTRE dans PRE_CHAIN (pas répété tant qu'on reste dedans)
   if(regimeChanged && g_chainPred.regime == "PRE_CHAIN" && ChainPredSoundAlert)
   {
      if(TimeCurrent() - g_chainPred.lastAlertTime > 60) // max 1 bip/min
      {
         PlaySound("alert.wav");
         Alert("[CHAIN PREDICTOR] ", _Symbol, " — CHAÎNE IMMINENTE! Score: ",
               DoubleToString(g_chainPred.chainImminence, 1), "/100 | Chain: ",
               g_chainPred.currentChainLen, " ", (g_chainPred.currentChainDir > 0 ? "UP" : "DN"));
         g_chainPred.lastAlertTime = TimeCurrent();
      }
   }

   // Bip sonore plus discret quand on ENTRE dans UNCERTAIN
   if(regimeChanged && g_chainPred.regime == "UNCERTAIN" && ChainPredSoundWeak)
   {
      if(TimeCurrent() - g_chainPred.lastAlertTime > 120) // max 1 bip/2min
      {
         PlaySound("tick.wav");
         g_chainPred.lastAlertTime = TimeCurrent();
      }
   }

   // Notification push quand PRE_CHAIN (comme avant)
   if(regimeChanged && g_chainPred.regime == "PRE_CHAIN")
   {
      string msg = "⚡ CHAIN IMMINENT | " + _Symbol + " | Score: " +
                   DoubleToString(g_chainPred.chainImminence, 1) +
                   " | Chain: " + IntegerToString(g_chainPred.currentChainLen) + " " +
                   (g_chainPred.currentChainDir > 0 ? "UP" : "DN");
      SendNotification(msg);
   }

   // Log détaillé
   Print("🔗 CHAIN PREDICTOR | Score=", DoubleToString(g_chainPred.chainImminence, 1),
         " | ISI=", DoubleToString(g_chainPred.isiCompression, 2),
         " | Len=", DoubleToString(g_chainPred.chainLengthScore, 1),
         " | Regime=", DoubleToString(g_chainPred.regimeScore, 1),
         " | Temp=", DoubleToString(g_chainPred.temporalScore, 1),
         " | Chain=", g_chainPred.currentChainLen, " ", (g_chainPred.currentChainDir > 0 ? "UP" : "DN"),
         " → ", g_chainPred.regime);
}

//+------------------------------------------------------------------+
//| 1) ISI Compression — ratio intervalle inter-spike                |
//+------------------------------------------------------------------+
void ChainPred_CalcISICompression()
{
   g_chainPred.isiCompression = 1.0; // défaut = pas de compression
   if(g_chainPred.spikeCount < 3) return;

   // Calculer les 3 derniers intervalles
   double isis[];
   ArrayResize(isis, 0);

   int count = MathMin(g_chainPred.spikeCount, ChainPredMaxSpikes);
   for(int i = 1; i < count; i++)
   {
      int idx0 = (g_chainPred.spikeIdx - 1 - i) % ChainPredMaxSpikes;
      int idx1 = (g_chainPred.spikeIdx - 1 - (i-1)) % ChainPredMaxSpikes;
      if(idx0 < 0) idx0 += ChainPredMaxSpikes;
      if(idx1 < 0) idx1 += ChainPredMaxSpikes;

      datetime t0 = g_chainPred.spikes[idx0].time;
      datetime t1 = g_chainPred.spikes[idx1].time;
      if(t0 > 0 && t1 > 0 && t1 > t0)
      {
         int interval = (int)(t1 - t0); // en secondes
         int barsInterval = interval / 60; // approximatif M1
         if(barsInterval > 0 && barsInterval <= 30)
         {
            int sz = ArraySize(isis);
            ArrayResize(isis, sz + 1);
            isis[sz] = (double)barsInterval;
         }
      }
   }

   if(ArraySize(isis) < 2) return;

   // ISI récent = premier intervalle
   double recentISI = isis[0];

   // ISI moyen = moyenne des précédents
   double avgISI = 0.0;
   for(int i = 1; i < ArraySize(isis); i++)
      avgISI += isis[i];
   avgISI /= (ArraySize(isis) - 1);

   if(avgISI > 0)
      g_chainPred.isiCompression = recentISI / avgISI;
}

//+------------------------------------------------------------------+
//| 2) Chain Length Score — P(continue) based on exponential decay   |
//+------------------------------------------------------------------+
void ChainPred_CalcChainLengthScore()
{
   g_chainPred.chainLengthScore = 0.0;
   if(g_chainPred.currentChainLen <= 0) return;

   // P(chaîne continue) = exp(-N / avgLength)
   // À N=1: P≈0.67, N=2: P≈0.45, N=3: P≈0.30, N=4: P≈0.20
   // Mais on veut un SCORE qui AUGMENTE avec la longueur
   // (plus la chaîne est longue, plus c'est intéressant d'entrer)
   // → on utilise le score inverse: plus la chaîne a duré, plus le regime est confirmé

   // Score log: log(1 + len) / log(1 + maxLength) * 100
   double maxLen = 8.0;
   double score = MathLog(1.0 + g_chainPred.currentChainLen) / MathLog(1.0 + maxLen) * 100.0;

   // Bonus si ISI compresse (la chaîne s'accélère)
   if(g_chainPred.isiCompression < ChainPredISICompressThresh)
      score = MathMin(100.0, score * 1.3);
   else if(g_chainPred.isiCompression < 0.80)
      score = MathMin(100.0, score * 1.15);

   g_chainPred.chainLengthScore = MathMin(100.0, MathMax(0.0, score));
}

//+------------------------------------------------------------------+
//| 3) Regime Classifier — ATR compression + volume + small bodies   |
//+------------------------------------------------------------------+
void ChainPred_CalcRegimeScore()
{
   double score = 0.0;

   // --- ATR M1/M5 compression ---
   double cpAtrM1  = ChainPred_GetATR(_Symbol, PERIOD_M1, 14);
   double cpAtrM5  = ChainPred_GetATR(_Symbol, PERIOD_M5, 14);
   if(cpAtrM5 > 0 && cpAtrM1 > 0)
   {
      double ratio = cpAtrM1 / cpAtrM5;
      if(ratio < 0.60)
         score += 30.0; // forte compression ATR
      else if(ratio < 0.80)
         score += 18.0; // compression modérée
   }

   // --- Volume ratio (ticks récents vs moyenne) ---
   long volTicks[];
   ArraySetAsSeries(volTicks, true);
   if(CopyTickVolume(_Symbol, PERIOD_M1, 0, 10, volTicks) >= 6)
   {
      double recentV = (double)volTicks[0];
      double avgV = 0.0;
      for(int i = 1; i <= 5; i++) avgV += (double)volTicks[i];
      avgV /= 5.0;
      if(avgV > 0)
      {
         double volRatio = recentV / avgV;
         if(volRatio >= 1.5)
            score += 20.0;
         else if(volRatio >= 1.05)
            score += 10.0;
      }
   }

   // --- Petites bougies (drift calme = pré-spike) ---
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, PERIOD_M1, 1, 8, r);
   if(n >= 6 && cpAtrM1 > 0)
   {
      int smallCount = 0;
      for(int i = 0; i < MathMin(8, n); i++)
      {
         double body = MathAbs(r[i].close - r[i].open);
         if(body < cpAtrM1 * 0.35)
            smallCount++;
      }
      if(smallCount >= 6)
         score += 20.0;
      else if(smallCount >= 4)
         score += 12.0;
   }

   g_chainPred.regimeScore = MathMin(100.0, MathMax(0.0, score));
}

//+------------------------------------------------------------------+
//| 4) Temporal Clustering — fréquence historique par heure UTC      |
//+------------------------------------------------------------------+
void ChainPred_CalcTemporalScore()
{
   g_chainPred.temporalScore = 0.0;
   if(g_chainPredPeakCount == 0) return;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int currentHour = tm.hour;

   // Vérifier si l'heure courante est dans les heures de pointe
   for(int i = 0; i < g_chainPredPeakCount; i++)
   {
      if(currentHour == g_chainPredPeakHours[i])
      {
         g_chainPred.temporalScore = 100.0;
         return;
      }
   }

   // Vérifier si on est à ±1 heure d'une heure de pointe
   for(int i = 0; i < g_chainPredPeakCount; i++)
   {
      int diff = MathAbs(currentHour - g_chainPredPeakHours[i]);
      if(diff > 12) diff = 24 - diff; // wrap around
      if(diff == 1)
      {
         g_chainPred.temporalScore = 50.0;
         return;
      }
   }

   g_chainPred.temporalScore = 0.0;
}

//+------------------------------------------------------------------+
//| API : le régime est-il "PRE_CHAIN" ?                              |
//+------------------------------------------------------------------+
bool ChainPred_IsPreChain()
{
   return UseChainPredictor && g_chainPred.regime == "PRE_CHAIN";
}

//+------------------------------------------------------------------+
//| API : le régime est-il au moins "UNCERTAIN" ?                     |
//+------------------------------------------------------------------+
bool ChainPred_IsUncertainOrBetter()
{
   return UseChainPredictor && (g_chainPred.regime == "PRE_CHAIN" || g_chainPred.regime == "UNCERTAIN");
}

//+------------------------------------------------------------------+
//| API : score d'imminence courant                                   |
//+------------------------------------------------------------------+
double ChainPred_GetImminence()
{
   return UseChainPredictor ? g_chainPred.chainImminence : 0.0;
}

//+------------------------------------------------------------------+
//| API : direction de la chaîne en cours                             |
//+------------------------------------------------------------------+
int ChainPred_GetChainDirection()
{
   return g_chainPred.currentChainDir;
}

//+------------------------------------------------------------------+
//| API : longueur de la chaîne en cours                              |
//+------------------------------------------------------------------+
int ChainPred_GetChainLength()
{
   return g_chainPred.currentChainLen;
}

//+------------------------------------------------------------------+
//| API : ratio ISI courant                                           |
//+------------------------------------------------------------------+
double ChainPred_GetISICompression()
{
   return g_chainPred.isiCompression;
}

//+------------------------------------------------------------------+
//| API : le score autorise-t-il une entrée agressive ?               |
//+------------------------------------------------------------------+
bool ChainPred_AllowsAggressiveEntry()
{
   return UseChainPredictor && g_chainPred.chainImminence >= ChainPredStrongThresh;
}

//+------------------------------------------------------------------+
//| API : le score autorise-t-il une entrée conservative ?            |
//+------------------------------------------------------------------+
bool ChainPred_AllowsConservativeEntry()
{
   return UseChainPredictor && g_chainPred.chainImminence >= ChainPredWeakThresh;
}

//+------------------------------------------------------------------+
//| API : reset de la chaîne (appeler quand la chaîne s'arrête)      |
//+------------------------------------------------------------------+
void ChainPred_ResetChain()
{
   g_chainPred.currentChainLen = 0;
   g_chainPred.currentChainDir = 0;
   g_chainPred.chainStartTime  = 0;
}

//+------------------------------------------------------------------+
//| Utilitaire local : ATR pour un symbole/TF donné                  |
//+------------------------------------------------------------------+
double ChainPred_GetATR(const string symbol, ENUM_TIMEFRAMES tf, int period)
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

//+------------------------------------------------------------------+
//| Largeur chart (fallback si resize MT5)                            |
//+------------------------------------------------------------------+
int ChainPred_GetChartWidth()
{
   static int s_lastGood = 1000;
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   if(w < 400) return s_lastGood;
   s_lastGood = w;
   return w;
}

//+------------------------------------------------------------------+
//| Fond semi-transparent pour le panneau                             |
//+------------------------------------------------------------------+
void ChainPred_DrawPanelBg(const string name, int x, int y, int w, int h, color bgClr)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Panneau Chain Predictor — haut centre (gauche du milieu)          |
//+------------------------------------------------------------------+
void ChainPred_DrawPanelTopCenter(int yTop = 10)
{
   if(!UseChainPredictor || !ChainPredShowOnChart) return;

   const int panelW = 200;
   const int panelH = 118;
   const int gap    = 14;
   int chartW = ChainPred_GetChartWidth();
   int x = chartW / 2 - panelW - gap / 2;

   ChainPred_DrawPanelBg("CHAIN_PRED_BG", x - 6, yTop - 4, panelW + 10, panelH, C'20,20,28');
   ChainPred_DrawPanel(x, yTop);
}

//+------------------------------------------------------------------+
//| Affichage chart : panneau score chain imminence                   |
//+------------------------------------------------------------------+
void ChainPred_DrawPanel(int xCorner, int yCorner)
{
   if(!UseChainPredictor || !ChainPredShowOnChart) return;

   string prefix = "CHAIN_PRED_";
   // Supprimer l'ancien fond rectangulaire s'il existe encore
   string oldBg = prefix + "BG";
   if(ObjectFind(0, oldBg) >= 0) ObjectDelete(0, oldBg);
   // Supprimer l'ancienne barre de progression rectangulaire
   string oldBar = prefix + "BAR";
   if(ObjectFind(0, oldBar) >= 0) ObjectDelete(0, oldBar);

   // Titre
   ChainPred_DrawLabel(prefix + "TITLE", xCorner + 5, yCorner + 5,
                       "CHAIN PREDICTOR", clrWhite, 9);

   bool noData = (g_chainPred.spikeCount == 0 && g_chainPred.chainImminence == 0);

   // Score principal
   color scoreColor = clrGray;
   if(g_chainPred.chainImminence >= ChainPredStrongThresh)
      scoreColor = clrLime;
   else if(g_chainPred.chainImminence >= ChainPredWeakThresh)
      scoreColor = clrGold;

   string scoreText = noData ? "Score: --- awaiting spikes ---" :
                      "Score: " + DoubleToString(g_chainPred.chainImminence, 1) + " / 100";
   ChainPred_DrawLabel(prefix + "SCORE", xCorner + 5, yCorner + 22,
                       scoreText, scoreColor, 11);

   // Régime
   ChainPred_DrawLabel(prefix + "REGIME", xCorner + 5, yCorner + 40,
                       "Regime: " + g_chainPred.regime, scoreColor, 9);

   // ISI
   string isiText = noData ? "ISI: ---" :
                    "ISI: " + DoubleToString(g_chainPred.isiCompression, 2) +
                    (g_chainPred.isiCompression < ChainPredISICompressThresh ? " COMPRESSED" : "");
   ChainPred_DrawLabel(prefix + "ISI", xCorner + 5, yCorner + 55,
                       isiText,
                       noData ? clrGray :
                       g_chainPred.isiCompression < ChainPredISICompressThresh ? clrLime : clrGray, 9);

   // Chaîne en cours
   string chainDir = (g_chainPred.currentChainDir > 0) ? "UP" :
                     (g_chainPred.currentChainDir < 0) ? "DN" : "---";
   string chainText = noData ? "Chain: ---" :
                      "Chain: " + IntegerToString(g_chainPred.currentChainLen) + " " + chainDir;
   ChainPred_DrawLabel(prefix + "CHAIN", xCorner + 5, yCorner + 70,
                       chainText, noData ? clrGray : g_chainPred.currentChainLen > 0 ? clrOrange : clrGray, 9);

   // Barre de progression textuelle
   if(!noData && g_chainPred.chainImminence > 0)
   {
      int barChars = (int)(g_chainPred.chainImminence / 100.0 * 20);
      string barStr = "";
      for(int b = 0; b < 20; b++) barStr += (b < barChars) ? "■" : "□";
      ChainPred_DrawLabel(prefix + "BARLABEL", xCorner + 5, yCorner + 85,
                          barStr, scoreColor, 7);
   }

    // ═══ ZONE VISUELLE sur chart quand PRE_CHAIN ═══
    if(ChainPredDrawZone)
    {
       ChainPred_DrawSpikeZone(xCorner, yCorner);
    }

    // ═══ FLÈCHES d'entrée potentielle ═══
    if(ChainPredDrawArrows)
    {
       ChainPred_DrawEntryArrows();
    }
}

//+------------------------------------------------------------------+
//| Utilitaire : dessiner un label sur le chart                       |
//+------------------------------------------------------------------+
void ChainPred_DrawLabel(const string name, int x, int y, const string text,
                         color clr, int fontSize)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
}

//+------------------------------------------------------------------+
//| Dessiner zone colorée sur chart quand score ≥ seuil fort          |
//+------------------------------------------------------------------+
void ChainPred_DrawSpikeZone(int xCorner, int yCorner)
{
   string prefix = "CHAIN_PRED_";
   // Supprimer l'ancien rectangle de zone s'il existe
   string zoneRect = prefix + "ZONE";
   if(ObjectFind(0, zoneRect) >= 0) ObjectDelete(0, zoneRect);

   string zoneLabel = prefix + "ZONELBL";
   if(g_chainPred.chainImminence >= ChainPredStrongThresh)
   {
      ChainPred_DrawLabel(zoneLabel, xCorner + 5, yCorner + 100,
                          "⚡ SPIKE ZONE ACTIVE — Entrez maintenant!",
                          clrLime, 8);
   }
   else if(g_chainPred.chainImminence >= ChainPredWeakThresh)
   {
      ChainPred_DrawLabel(zoneLabel, xCorner + 5, yCorner + 100,
                          "? Zone possible — Surveillez",
                          clrGold, 8);
   }
   else
   {
      if(ObjectFind(0, zoneLabel) >= 0)
         ObjectDelete(0, zoneLabel);
   }
}

//+------------------------------------------------------------------+
//| Dessiner flèches d'entrée potentielle sur les candles récentes   |
//+------------------------------------------------------------------+
void ChainPred_DrawEntryArrows()
{
   string prefix = "CHAIN_PRED_ARROW_";

   // Supprimer anciennes flèches
   ObjectsDeleteAll(0, prefix);

   // Si pas en PRE_CHAIN, pas de flèches
   if(g_chainPred.chainImminence < ChainPredWeakThresh) return;

   // Obtenir les dernières candles
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5) return;

   // Dessiner flèche sur la dernière bougie fermée (index 1)
   int arrowCode = (g_chainPred.currentChainDir > 0) ? 233 : 234; // UP ou DOWN arrow
   color arrowClr = (g_chainPred.chainImminence >= ChainPredStrongThresh) ? clrLime : clrGold;

   string arrowName = prefix + "ENTRY";
   if(ObjectFind(0, arrowName) < 0)
   {
      ObjectCreate(0, arrowName, OBJ_ARROW, 0, rates[1].time, 0);
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowClr);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
   }

   // Positionner la flèche
   if(g_chainPred.currentChainDir > 0)
      ObjectSetDouble(0, arrowName, OBJPROP_PRICE, rates[1].low - (rates[1].high - rates[1].low) * 0.2);
   else
      ObjectSetDouble(0, arrowName, OBJPROP_PRICE, rates[1].high + (rates[1].high - rates[1].low) * 0.2);

   // Texte "CHAIN" à côté de la flèche
   string lblName = prefix + "LBL";
   if(ObjectFind(0, lblName) < 0)
   {
      ObjectCreate(0, lblName, OBJ_TEXT, 0, rates[1].time, 0);
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, arrowClr);
      ObjectSetString(0, lblName, OBJPROP_FONT, "Consolas Bold");
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
   }
   ObjectSetString(0, lblName, OBJPROP_TEXT,
                   "CHAIN[" + IntegerToString(g_chainPred.currentChainLen) + "]");
   if(g_chainPred.currentChainDir > 0)
      ObjectSetDouble(0, lblName, OBJPROP_PRICE, rates[1].low - (rates[1].high - rates[1].low) * 0.4);
   else
      ObjectSetDouble(0, lblName, OBJPROP_PRICE, rates[1].high + (rates[1].high - rates[1].low) * 0.4);
}

//+------------------------------------------------------------------+
//| Panneau fusionné Chain Predictor + Cross Correlation              |
//| Un seul panneau centré en haut du chart                           |
//+------------------------------------------------------------------+
void ChainCorr_DrawMergedPanel(const string sch1Extra = "")
{
   if(!UseChainPredictor && !UseCrossCorrelation) return;
   if(!ChainPredShowOnChart && !UseCrossCorrelation) return;

   string prefix = "CC_MRG_";
   ObjectsDeleteAll(0, prefix);
   ObjectDelete(0, "CHAIN_PRED_BG");
   ObjectDelete(0, "CROSS_CORR_BG");

   int chartW = ChainPred_GetChartWidth();
   int panelW = 380;
   int panelH = 136;
   int x0 = (chartW - panelW) / 2;
   int y0 = 10;

   if(x0 < 5) x0 = 5;

   // ── FOND ──
   string bgName = prefix + "BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x0);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y0);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelW);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelH);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'20,20,28');
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);

   // ── CHAIN PREDICTOR (gauche) ──
   int lx = x0 + 8;
   int ly = y0 + 6;

   bool noData = (g_chainPred.spikeCount == 0 && g_chainPred.chainImminence == 0);

   color titleClr = UseChainPredictor ? clrMediumPurple : clrGray;
   ChainPred_DrawLabel(prefix + "CTITLE", lx, ly, "CHAIN PREDICTOR", titleClr, 9);

   color scoreColor = clrGray;
   if(g_chainPred.chainImminence >= ChainPredStrongThresh)
      scoreColor = clrLime;
   else if(g_chainPred.chainImminence >= ChainPredWeakThresh)
      scoreColor = clrGold;

   string scoreText = noData ? "Score: ---" :
                      "Score: " + DoubleToString(g_chainPred.chainImminence, 0) + "/100";
   ChainPred_DrawLabel(prefix + "CSCORE", lx, ly + 18, scoreText, scoreColor, 11);

   string regimeText = noData ? "Regime: ---" : "Regime: " + g_chainPred.regime;
   ChainPred_DrawLabel(prefix + "CREG", lx, ly + 36, regimeText, scoreColor, 8);

   string isiText = noData ? "ISI: ---" :
                    "ISI: " + DoubleToString(g_chainPred.isiCompression, 2) +
                    (g_chainPred.isiCompression < ChainPredISICompressThresh ? " COMP" : "");
   color isiClr = noData ? clrGray :
                  g_chainPred.isiCompression < ChainPredISICompressThresh ? clrLime : clrGray;
   ChainPred_DrawLabel(prefix + "CISI", lx, ly + 50, isiText, isiClr, 8);

   string chainDir = (g_chainPred.currentChainDir > 0) ? "UP" :
                     (g_chainPred.currentChainDir < 0) ? "DN" : "---";
   string chainText = noData ? "Chain: ---" :
                      "Chain: " + IntegerToString(g_chainPred.currentChainLen) + " " + chainDir;
   color chainClr = noData ? clrGray :
                    g_chainPred.currentChainLen > 0 ? clrOrange : clrGray;
   ChainPred_DrawLabel(prefix + "CCHAIN", lx, ly + 64, chainText, chainClr, 8);

   if(!noData && g_chainPred.chainImminence > 0)
   {
      int barChars = (int)(g_chainPred.chainImminence / 100.0 * 16);
      string barStr = "";
      for(int b = 0; b < 16; b++) barStr += (b < barChars) ? "#" : "-";
      ChainPred_DrawLabel(prefix + "CBAR", lx, ly + 78, barStr, scoreColor, 7);
   }

   // ── SEPARATEUR ──
   int sepX = x0 + panelW / 2;
   string sepName = prefix + "SEP";
   ObjectCreate(0, sepName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, sepName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, sepName, OBJPROP_XDISTANCE, sepX);
   ObjectSetInteger(0, sepName, OBJPROP_YDISTANCE, y0 + 8);
   ObjectSetInteger(0, sepName, OBJPROP_XSIZE, 1);
   ObjectSetInteger(0, sepName, OBJPROP_YSIZE, panelH - 16);
   ObjectSetInteger(0, sepName, OBJPROP_BGCOLOR, clrDimGray);
   ObjectSetInteger(0, sepName, OBJPROP_BACK, false);
   ObjectSetInteger(0, sepName, OBJPROP_SELECTABLE, false);

   // ── CROSS CORRELATION (droite) ──
   int rx = sepX + 10;

   color rxTitleClr = UseCrossCorrelation ? clrDeepSkyBlue : clrGray;
   ChainPred_DrawLabel(prefix + "XTITLE", rx, ly, "CROSS CORRELATION", rxTitleClr, 9);

   string statusText;
   color  statusClr;
   if(UseCrossCorrelation && CrossCorr_IsSignalActive())
   {
      statusText = "SIGNAL from " + CrossCorr_GetTriggerSymbol();
      statusClr = CrossCorr_IsStrongSignal() ? clrLime : clrGold;
   }
   else
   {
      statusText = "No signal";
      statusClr = clrGray;
   }
   ChainPred_DrawLabel(prefix + "XSTATUS", rx, ly + 18, statusText, statusClr, 9);

   double force = UseCrossCorrelation ? CrossCorr_GetSignalStrength() * 100.0 : 0.0;
   string forceText = "Force: " + DoubleToString(force, 0) + "%";
   ChainPred_DrawLabel(prefix + "XFORCE", rx, ly + 36, forceText, statusClr, 9);

   int delay = UseCrossCorrelation ? CrossCorr_GetDelayBars() : 0;
   string delayText = "Delay: " + IntegerToString(delay) + " bars";
   ChainPred_DrawLabel(prefix + "XDELAY", rx, ly + 50, delayText,
                       delay <= 2 ? clrLime : delay <= 4 ? clrGold : clrGray, 8);

    double boost = UseCrossCorrelation ? CrossCorr_GetImminenceBoost() : 0.0;
    string boostText = "Boost: +" + DoubleToString(boost, 1);
    ChainPred_DrawLabel(prefix + "XBOOST", rx, ly + 64, boostText,
                        boost > 0 ? clrLime : clrGray, 8);

    // Direction prédite pour le symbole courant
    string dirText = "Dir: --";
    color  dirClr = clrGray;
    if(UseCrossCorrelation && CrossCorr_IsSignalActive())
    {
       int xDir = CrossCorr_GetPredictedDirection();
       if(xDir == 1) { dirText = "Dir: BUY \x2191"; dirClr = clrLime; }
       else if(xDir == -1) { dirText = "Dir: SELL \x2193"; dirClr = clrRed; }
    }
    ChainPred_DrawLabel(prefix + "XDIR", rx, ly + 78, dirText, dirClr, 9);

    // ── SCH1 (Spike Chain H1/M5) — pleine largeur en bas ──
   if(StringLen(sch1Extra) > 0)
   {
      string sch1Label = "SCH1: " + sch1Extra;
      ChainPred_DrawLabel(prefix + "SCH1", lx, y0 + panelH - 16, sch1Label, clrDarkOrchid, 8);
   }
}

//+------------------------------------------------------------------+
//| Nettoyage des objets chart                                        |
//+------------------------------------------------------------------+
void ChainPred_Cleanup()
{
   string prefix = "CHAIN_PRED_";
   ObjectsDeleteAll(0, prefix);
   ObjectsDeleteAll(0, "CC_MRG_");
}

#endif // SMC_CHAIN_PREDICTOR_MQH
