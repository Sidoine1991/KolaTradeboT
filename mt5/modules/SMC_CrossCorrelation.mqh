//+------------------------------------------------------------------+
//| SMC_CrossCorrelation.mqh — Corrélation croisée PainX ↔ GainX    |
//|                                                                    |
//| Détecte les spikes sur le symbole INVERSE et génère un signal     |
//| prédictif pour le symbole courant.                                |
//|                                                                    |
//| Logique: un spike sur PainX 1200 → signal BUY GainX 1200          |
//|          un spike sur GainX 1200 → signal SELL PainX 1200         |
//|                                                                    |
//| Fonctionne aussi pour Boom/Crash Deriv.                           |
//|                                                                    |
//| Les symboles sont groupés par "taille" (1200, 800, 600, etc.)     |
//| pour corréler uniquement les paires de même taille.               |
//+------------------------------------------------------------------+
#ifndef SMC_CROSS_CORRELATION_MQH
#define SMC_CROSS_CORRELATION_MQH

//--- Nombre max de symboles pairs à surveiller ---
#define CROSS_CORR_MAX_PAIRS 6

//--- Inputs ---
input group "=== CROSS CORRELATION ==="
input bool   UseCrossCorrelation     = true;   // Activer la corrélation croisée
input string CrossCorrPairs          = "PainX 1200:GainX 1200,PainX 800:GainX 800,PainX 600:GainX 600,Boom 1000:Crash 1000,Boom 500:Crash 500,Boom 300:Crash 300"; // Paires symbole:symbole inverse
input int    CrossCorrLookbackBars   = 15;      // Nombre de bougies M1 à scanner sur le symbole inverse
input int    CrossCorrDelayMaxBars   = 5;       // Délai max (bars M1) entre spike inverse et signal
input double CrossCorrBoostWeight    = 20.0;    // Points bonus au ChainImminence si spike inverse détecté
input bool   UseCrossCorrDOWgate     = true;    // DOW LIMIT seulement si CrossCorr ≥70% et direction alignée

//--- Structure d'une paire de symboles ---
struct CrossCorr_Pair
{
   string   symbolA;       // Premier symbole (ex: "PainX 1200")
   string   symbolB;       // Symbole inverse (ex: "GainX 1200")
   int      size;          // Taille (1200, 800, 600...)
   bool     isActive;      // Paire active (les 2 symboles existent)
};

//--- État de corrélation pour une paire ---
struct CrossCorr_State
{
   datetime lastSpikeOnInverse;  // Dernier spike détecté sur le symbole inverse
   double   lastSpikeAmplitude;  // Amplitude du dernier spike inverse (ATR)
   int      lastSpikeBarsAgo;    // Nombre de bougies depuis le spike inverse
   double   signalStrength;      // Force du signal [0..1]
   bool     signalActive;        // Signal actif (spike inverse récent)
   string   triggerSymbol;       // Symbole qui a déclenché le signal
   bool     spikeDirectionUp;    // true = spike haussier sur l'inverse, false = baissier
};

//--- Données globales ---
CrossCorr_Pair  g_crossCorrPairs[CROSS_CORR_MAX_PAIRS];
int             g_crossCorrPairCount = 0;
CrossCorr_State g_crossCorrState;

// Mémoire des spikes par symbole (pour le scan multi-symboles)
#define CROSS_CORR_MAX_SYMBOLS 12
struct CrossCorr_SpikeMem
{
   string   symbol;
   datetime lastSpikeTime;
   double   lastSpikeAmpATR;
   int      lastSpikeDir;
};
CrossCorr_SpikeMem g_crossCorrSpikeMem[CROSS_CORR_MAX_SYMBOLS];
int                g_crossCorrSpikeMemCount = 0;

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
void CrossCorr_Init()
{
   ZeroMemory(g_crossCorrState);
   g_crossCorrPairCount = 0;

   // Parser les paires
   string pairs[];
   int n = StringSplit(CrossCorrPairs, ',', pairs);
   for(int i = 0; i < n && g_crossCorrPairCount < CROSS_CORR_MAX_PAIRS; i++)
   {
      string p = pairs[i];
      StringTrimLeft(p);
      StringTrimRight(p);

      string parts[];
      int np = StringSplit(p, ':', parts);
      if(np != 2) continue;

      string symA = parts[0];
      string symB = parts[1];
      StringTrimLeft(symA); StringTrimRight(symA);
      StringTrimLeft(symB); StringTrimRight(symB);

      // Extraire la taille du nom (ex: "PainX 1200" → 1200)
      int spacePos = StringFind(symA, " ");
      int size = 0;
      if(spacePos >= 0)
         size = (int)StringToInteger(StringSubstr(symA, spacePos + 1));

      g_crossCorrPairs[g_crossCorrPairCount].symbolA  = symA;
      g_crossCorrPairs[g_crossCorrPairCount].symbolB  = symB;
      g_crossCorrPairs[g_crossCorrPairCount].size     = size;
      g_crossCorrPairs[g_crossCorrPairCount].isActive = true;
      g_crossCorrPairCount++;

      Print("[CrossCorr] Paire enregistrée: ", symA, " ↔ ", symB, " (size=", size, ")");
   }

   Print("[CrossCorr] ", g_crossCorrPairCount, " paires actives");
}

//+------------------------------------------------------------------+
//| Trouver la paire correspondant au symbole courant                 |
//+------------------------------------------------------------------+
bool CrossCorr_FindPair(const string symbol, string &outPartner, string &outTriggerSym)
{
   outPartner = "";
   outTriggerSym = "";

   for(int i = 0; i < g_crossCorrPairCount; i++)
   {
      if(!g_crossCorrPairs[i].isActive) continue;

      if(symbol == g_crossCorrPairs[i].symbolA)
      {
         outPartner   = g_crossCorrPairs[i].symbolB;
         outTriggerSym = g_crossCorrPairs[i].symbolB;
         return true;
      }
      if(symbol == g_crossCorrPairs[i].symbolB)
      {
         outPartner   = g_crossCorrPairs[i].symbolA;
         outTriggerSym = g_crossCorrPairs[i].symbolA;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Scanner le symbole inverse pour des spikes récents                |
//| À appeler à chaque tick ou à chaque nouvelle bougie M1           |
//+------------------------------------------------------------------+
void CrossCorr_ScanPartner(const string currentSymbol)
{
   if(!UseCrossCorrelation) return;

   string partner = "";
   string triggerSym = "";
   if(!CrossCorr_FindPair(currentSymbol, partner, triggerSym))
   {
      g_crossCorrState.signalActive = false;
      return;
   }

   // Scanner les bougies récentes du partenaire
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int n = CopyRates(partner, PERIOD_M1, 1, CrossCorrLookbackBars, rates);
   if(n < 3)
   {
      g_crossCorrState.signalActive = false;
      return;
   }

   // ATR du partenaire pour normaliser l'amplitude
   double atrVal = CrossCorr_GetATR(partner, PERIOD_M1, 14);

    // Trouver le spike le plus récent sur le partenaire
    datetime now = TimeCurrent();
    bool foundSpike = false;
    double bestAmp = 0.0;
    int bestBarsAgo = 0;
    bool bestDirectionUp = true;

    for(int i = 0; i < MathMin(n, CrossCorrLookbackBars); i++)
    {
       double body = rates[i].close - rates[i].open;
       double bodyAbs = MathAbs(body);
       double range = rates[i].high - rates[i].low;

       // Un spike = corps ou range > min ATR
       if(atrVal > 0)
       {
          double ampATR = (bodyAbs > 0) ? bodyAbs / atrVal : range / atrVal;
          if(ampATR >= 1.5)
          {
             // Vérifier le délai
             int barsAgo = i + 1; // i=0 = dernière bougie clôturée = 1 bar ago
             if(barsAgo <= CrossCorrDelayMaxBars)
             {
                // Prendre le plus récent
                if(!foundSpike || barsAgo < bestBarsAgo)
                {
                   foundSpike     = true;
                   bestAmp        = ampATR;
                   bestBarsAgo    = barsAgo;
                   bestDirectionUp = (body > 0);
                }
             }
          }
       }
    }

    // Mettre à jour l'état
    if(foundSpike)
    {
       g_crossCorrState.lastSpikeOnInverse = now - bestBarsAgo * 60;
       g_crossCorrState.lastSpikeAmplitude = bestAmp;
       g_crossCorrState.lastSpikeBarsAgo   = bestBarsAgo;
       g_crossCorrState.triggerSymbol      = triggerSym;
       g_crossCorrState.spikeDirectionUp   = bestDirectionUp;

      // Force du signal : inversement proportionnelle au délai
      // Plus le spike est récent → signal plus fort
      double delayFactor = 1.0 - ((double)bestBarsAgo / (double)CrossCorrDelayMaxBars);
      // Boost si amplitude forte
      double ampFactor = MathMin(1.0, bestAmp / 3.0);
      g_crossCorrState.signalStrength = MathMin(1.0, delayFactor * 0.6 + ampFactor * 0.4);
      g_crossCorrState.signalActive   = (g_crossCorrState.signalStrength >= 0.5);

      if(g_crossCorrState.signalActive)
      {
         string dirLabel = bestDirectionUp ? "UP" : "DOWN";
         Print("🔀 CROSS-CORR SIGNAL | ", triggerSym, " spike ", dirLabel, " (",
               DoubleToString(bestAmp, 2), " ATR, il y a ", bestBarsAgo, " bars) → signal sur ",
               currentSymbol, " | Force: ", DoubleToString(g_crossCorrState.signalStrength, 2));
      }

      // Notification
      if(g_crossCorrState.signalActive)
      {
         string dirLabel = bestDirectionUp ? "UP" : "DOWN";
         string msg = "🔀 SPIKE INVERSE | " + triggerSym + " " + dirLabel +
                      " | Amp: " + DoubleToString(bestAmp, 1) + " ATR" +
                      " | il y a " + IntegerToString(bestBarsAgo) + " bars" +
                      " → Signal " + currentSymbol;
         SendNotification(msg);
      }
   }
   else
   {
      g_crossCorrState.signalActive = false;
      g_crossCorrState.signalStrength = 0.0;
   }
}

//+------------------------------------------------------------------+
//| API : y a-t-il un signal croisé actif ?                           |
//+------------------------------------------------------------------+
bool CrossCorr_IsSignalActive()
{
   return UseCrossCorrelation && g_crossCorrState.signalActive;
}

//+------------------------------------------------------------------+
//| API : force du signal croisé [0..1]                               |
//+------------------------------------------------------------------+
double CrossCorr_GetSignalStrength()
{
   return UseCrossCorrelation ? g_crossCorrState.signalStrength : 0.0;
}

//+------------------------------------------------------------------+
//| API : le signal est-il "fort" ?                                   |
//+------------------------------------------------------------------+
bool CrossCorr_IsStrongSignal()
{
   return UseCrossCorrelation && g_crossCorrState.signalStrength >= 0.8;
}

//+------------------------------------------------------------------+
//| API : bonus à ajouter au ChainImminence                           |
//+------------------------------------------------------------------+
double CrossCorr_GetImminenceBoost()
{
   if(!UseCrossCorrelation || !g_crossCorrState.signalActive) return 0.0;
   return g_crossCorrState.signalStrength * CrossCorrBoostWeight;
}

//+------------------------------------------------------------------+
//| API : symbole trigger (celui qui a fait le spike)                 |
//+------------------------------------------------------------------+
string CrossCorr_GetTriggerSymbol()
{
   return g_crossCorrState.triggerSymbol;
}

//+------------------------------------------------------------------+
//| API : delay depuis le spike inverse (bars)                        |
//+------------------------------------------------------------------+
int CrossCorr_GetDelayBars()
{
   return g_crossCorrState.lastSpikeBarsAgo;
}

//+------------------------------------------------------------------+
//| API : direction du spike sur l'inverse (true=UP, false=DOWN)      |
//+------------------------------------------------------------------+
bool CrossCorr_GetSpikeDirectionUp()
{
   return g_crossCorrState.spikeDirectionUp;
}

//+------------------------------------------------------------------+
//| API : direction prédite pour le symbole courant (+1=BUY, -1=SELL) |
//| Les paires sont inverses : spike UP sur inverse → SELL current   |
//|                              spike DOWN sur inverse → BUY current |
//+------------------------------------------------------------------+
int CrossCorr_GetPredictedDirection()
{
   if(!UseCrossCorrelation || !g_crossCorrState.signalActive) return 0;
   return g_crossCorrState.spikeDirectionUp ? -1 : +1;
}

//+------------------------------------------------------------------+
//| Enregistrer un spike du symbole courant (pour mise à jour mémoire)|
//+------------------------------------------------------------------+
void CrossCorr_RegisterSpike(const string symbol, datetime spikeTime, double ampATR, int dir)
{
   if(!UseCrossCorrelation) return;

   // Chercher ou créer l'entrée mémoire
   int idx = -1;
   for(int i = 0; i < g_crossCorrSpikeMemCount; i++)
   {
      if(g_crossCorrSpikeMem[i].symbol == symbol)
      {
         idx = i;
         break;
      }
   }
   if(idx < 0 && g_crossCorrSpikeMemCount < CROSS_CORR_MAX_SYMBOLS)
   {
      idx = g_crossCorrSpikeMemCount;
      g_crossCorrSpikeMemCount++;
   }
   if(idx >= 0)
   {
      g_crossCorrSpikeMem[idx].symbol       = symbol;
      g_crossCorrSpikeMem[idx].lastSpikeTime  = spikeTime;
      g_crossCorrSpikeMem[idx].lastSpikeAmpATR = ampATR;
      g_crossCorrSpikeMem[idx].lastSpikeDir    = dir;
   }
}

//+------------------------------------------------------------------+
//| Largeur chart (fallback si resize MT5)                            |
//+------------------------------------------------------------------+
int CrossCorr_GetChartWidth()
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
void CrossCorr_DrawPanelBg(const string name, int x, int y, int w, int h, color bgClr)
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
//| Panneau Cross Correlation — haut centre (droite du milieu)      |
//+------------------------------------------------------------------+
void CrossCorr_DrawPanelTopCenter(int yTop = 10)
{
   if(!UseCrossCorrelation) return;

   const int panelW = 200;
   const int panelH = 58;
   const int gap    = 14;
   int chartW = CrossCorr_GetChartWidth();
   int x = chartW / 2 + gap / 2;

   CrossCorr_DrawPanelBg("CROSS_CORR_BG", x - 6, yTop - 4, panelW + 10, panelH, C'20,20,28');
   CrossCorr_DrawPanel(x, yTop);
}

//+------------------------------------------------------------------+
//| Affichage chart                                                   |
//+------------------------------------------------------------------+
void CrossCorr_DrawPanel(int xCorner, int yCorner)
{
   if(!UseCrossCorrelation) return;

   string prefix = "CROSS_CORR_";
   // Supprimer l'ancien fond rectangulaire s'il existe encore
   string oldBg = prefix + "BG";
   if(ObjectFind(0, oldBg) >= 0) ObjectDelete(0, oldBg);

   // Titre
   CrossCorr_DrawLabel(prefix + "TITLE", xCorner + 5, yCorner + 5,
                       "CROSS CORRELATION", clrWhite, 9);

   // Signal status
   string statusText;
   color  statusClr;
   if(g_crossCorrState.signalActive)
   {
      statusText = "SIGNAL ACTIVE from " + g_crossCorrState.triggerSymbol;
      statusClr = g_crossCorrState.signalStrength >= 0.8 ? clrLime : clrGold;
   }
   else
   {
      statusText = "No signal";
      statusClr = clrGray;
   }
   CrossCorr_DrawLabel(prefix + "STATUS", xCorner + 5, yCorner + 22,
                       statusText, statusClr, 9);

   // Force
   string forceText = "Force: " + DoubleToString(g_crossCorrState.signalStrength * 100, 0) + "%";
   CrossCorr_DrawLabel(prefix + "FORCE", xCorner + 5, yCorner + 38,
                       forceText, statusClr, 9);
}

//+------------------------------------------------------------------+
//| Utilitaire local : ATR                                            |
//+------------------------------------------------------------------+
double CrossCorr_GetATR(const string symbol, ENUM_TIMEFRAMES tf, int period)
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
//| Utilitaire : dessiner un label                                    |
//+------------------------------------------------------------------+
void CrossCorr_DrawLabel(const string name, int x, int y, const string text,
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
//| Nettoyage                                                        |
//+------------------------------------------------------------------+
void CrossCorr_Cleanup()
{
   ObjectsDeleteAll(0, "CROSS_CORR_");
}

#endif // SMC_CROSS_CORRELATION_MQH
