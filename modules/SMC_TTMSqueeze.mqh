//+------------------------------------------------------------------+
//| SMC_TTMSqueeze.mqh                                               |
//| TTM Squeeze (Bollinger inside Keltner) — détection de compression|
//| avant spike. Complémentaire des Spike Zones historiques.         |
//|                                                                   |
//| Visuel : points rouges/verts sous les bougies + histogramme      |
//| momentum (direction probable du break).                           |
//|                                                                   |
//| Intégration EA :                                                  |
//|   - SMC_TTM_Update() à chaque tick / nouvelle barre              |
//|   - SMC_TTM_IsSqueezing() / SMC_TTM_IsFiring() / MomentumDir()    |
//|   - Score ajouté au Confluence / Combo d'entrée                  |
//+------------------------------------------------------------------+
#property copyright "TradBOT SMC"
#property strict

#ifndef SMC_TTM_SQUEEZE_MQH
#define SMC_TTM_SQUEEZE_MQH

//--- Inputs (peuvent être surchargés par le main EA via #define avant include)
#ifndef TTM_BB_PERIOD
   #define TTM_BB_PERIOD          20
#endif
#ifndef TTM_BB_DEVIATION
   #define TTM_BB_DEVIATION        2.0
#endif
#ifndef TTM_KC_PERIOD
   #define TTM_KC_PERIOD          20
#endif
#ifndef TTM_KC_MULT
   #define TTM_KC_MULT            1.5
#endif
#ifndef TTM_MOM_PERIOD
   #define TTM_MOM_PERIOD         12
#endif
#ifndef TTM_SQUEEZE_LOOKBACK
   #define TTM_SQUEEZE_LOOKBACK   8      // barres de compression minimum pour valider
#endif
#ifndef TTM_DRAW_ON_CHART
   #define TTM_DRAW_ON_CHART      true
#endif
#ifndef TTM_HISTO_SCALE
   #define TTM_HISTO_SCALE        0.35   // échelle visuelle de l'histogramme (× ATR)
#endif

//--- État global du module
struct SMC_TTMState
{
   bool     ready;
   bool     isSqueezing;          // BB complètement à l'intérieur de KC
   bool     isFiring;             // sortie de squeeze (fire)
   int      squeezeBars;          // nombre de barres consécutives en squeeze
   int      momentumDir;          // +1 haussier, -1 baissier, 0 neutre
   double   momentumValue;        // valeur brute de l'histo momentum
   double   momentumStrength;     // 0..1 normalisé
   double   bbUpper, bbLower, bbMid;
   double   kcUpper, kcLower, kcMid;
   double   squeezeWidthPct;      // largeur relative (plus petit = compression plus forte)
   datetime lastBarTime;
   string   lastSignal;           // "SQUEEZE" / "FIRE_UP" / "FIRE_DOWN" / "NONE"
};

SMC_TTMState g_ttm;

//--- Handles (créés une seule fois)
int g_ttmBBHandle   = INVALID_HANDLE;
int g_ttmATRHandle  = INVALID_HANDLE;
int g_ttmMAHandle   = INVALID_HANDLE;   // pour Keltner mid

//+------------------------------------------------------------------+
//| Initialisation                                                   |
//+------------------------------------------------------------------+
bool SMC_TTM_Init(const string symbol = NULL, const ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   string sym = (symbol == NULL || symbol == "") ? _Symbol : symbol;

   g_ttmBBHandle  = iBands(sym, tf, TTM_BB_PERIOD, 0, TTM_BB_DEVIATION, PRICE_CLOSE);
   g_ttmATRHandle = iATR(sym, tf, TTM_KC_PERIOD);
   g_ttmMAHandle  = iMA(sym, tf, TTM_KC_PERIOD, 0, MODE_SMA, PRICE_CLOSE);

   if(g_ttmBBHandle == INVALID_HANDLE || g_ttmATRHandle == INVALID_HANDLE || g_ttmMAHandle == INVALID_HANDLE)
   {
      Print("❌ SMC_TTMSqueeze: échec création handles (", GetLastError(), ")");
      return false;
   }

   ZeroMemory(g_ttm);
   g_ttm.ready = true;
   g_ttm.lastSignal = "NONE";
   Print("✅ SMC_TTMSqueeze initialisé | BB(", TTM_BB_PERIOD, ",", TTM_BB_DEVIATION,
         ") KC(", TTM_KC_PERIOD, ",", TTM_KC_MULT, ") Mom(", TTM_MOM_PERIOD, ")");
   return true;
}

void SMC_TTM_Deinit()
{
   if(g_ttmBBHandle  != INVALID_HANDLE) IndicatorRelease(g_ttmBBHandle);
   if(g_ttmATRHandle != INVALID_HANDLE) IndicatorRelease(g_ttmATRHandle);
   if(g_ttmMAHandle  != INVALID_HANDLE) IndicatorRelease(g_ttmMAHandle);
   g_ttmBBHandle = g_ttmATRHandle = g_ttmMAHandle = INVALID_HANDLE;

   // Nettoyage objets graphiques
   ObjectsDeleteAll(0, "TTM_");
   g_ttm.ready = false;
}

//+------------------------------------------------------------------+
//| Calcul principal (appeler à chaque tick ou nouvelle barre)       |
//+------------------------------------------------------------------+
bool SMC_TTM_Update(const string symbol = NULL, const ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   if(!g_ttm.ready) return false;

   string sym = (symbol == NULL || symbol == "") ? _Symbol : symbol;

   // Nouveaux buffers
   double bbUpper[], bbLower[], bbMid[];
   double atr[], ma[];
   ArraySetAsSeries(bbUpper, true); ArraySetAsSeries(bbLower, true); ArraySetAsSeries(bbMid, true);
   ArraySetAsSeries(atr, true); ArraySetAsSeries(ma, true);

   // On a besoin de TTM_MOM_PERIOD + quelques barres pour le momentum + lookback
   int need = MathMax(TTM_BB_PERIOD, TTM_KC_PERIOD) + TTM_MOM_PERIOD + 5;
   if(CopyBuffer(g_ttmBBHandle, 1, 0, need, bbUpper) < need) return false; // upper
   if(CopyBuffer(g_ttmBBHandle, 2, 0, need, bbLower) < need) return false; // lower
   if(CopyBuffer(g_ttmBBHandle, 0, 0, need, bbMid)   < need) return false; // middle
   if(CopyBuffer(g_ttmATRHandle, 0, 0, need, atr)    < need) return false;
   if(CopyBuffer(g_ttmMAHandle,  0, 0, need, ma)     < need) return false;

   // Keltner
   double kcMid   = ma[0];
   double kcUpper = kcMid + TTM_KC_MULT * atr[0];
   double kcLower = kcMid - TTM_KC_MULT * atr[0];

   g_ttm.bbUpper = bbUpper[0];
   g_ttm.bbLower = bbLower[0];
   g_ttm.bbMid   = bbMid[0];
   g_ttm.kcUpper = kcUpper;
   g_ttm.kcLower = kcLower;
   g_ttm.kcMid   = kcMid;

   // Squeeze = BB entièrement à l'intérieur de KC
   bool squeezeNow = (bbUpper[0] < kcUpper && bbLower[0] > kcLower);

   // Compteur de barres de squeeze
   if(squeezeNow)
   {
      if(g_ttm.isSqueezing) g_ttm.squeezeBars++;
      else                  g_ttm.squeezeBars = 1;
   }
   else
   {
      g_ttm.squeezeBars = 0;
   }

   // Largeur relative de la compression (plus petit = plus fort)
   double kcWidth = kcUpper - kcLower;
   double bbWidth = bbUpper[0] - bbLower[0];
   g_ttm.squeezeWidthPct = (kcWidth > 0.0) ? (bbWidth / kcWidth) * 100.0 : 100.0;

   // Momentum (linreg-like simplifié = close - SMA(close, momPeriod) ou delta)
   // Version classique TTM : momentum = close - moyenne des (high+low)/2 sur momPeriod
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, tf, 0, TTM_MOM_PERIOD + 3, rates) < TTM_MOM_PERIOD + 1)
      return false;

   double sumHL = 0.0;
   for(int i = 0; i < TTM_MOM_PERIOD; i++)
      sumHL += (rates[i].high + rates[i].low) * 0.5;
   double midAvg = sumHL / (double)TTM_MOM_PERIOD;
   double mom = rates[0].close - midAvg;

   g_ttm.momentumValue = mom;

   // Force normalisée (par ATR)
   double atr0 = atr[0];
   if(atr0 <= 0.0) atr0 = _Point * 10;
   g_ttm.momentumStrength = MathMin(1.0, MathAbs(mom) / (atr0 * 1.2));

   // Direction
   if(mom > atr0 * 0.08)       g_ttm.momentumDir = 1;
   else if(mom < -atr0 * 0.08) g_ttm.momentumDir = -1;
   else                        g_ttm.momentumDir = 0;

   // Détection FIRE (sortie de squeeze)
   bool wasSqueezing = g_ttm.isSqueezing;
   g_ttm.isSqueezing = squeezeNow && (g_ttm.squeezeBars >= 1);

   // Fire = était en squeeze (au moins TTM_SQUEEZE_LOOKBACK barres) et sort maintenant
   g_ttm.isFiring = false;
   if(wasSqueezing && !squeezeNow && g_ttm.squeezeBars >= TTM_SQUEEZE_LOOKBACK)
   {
      g_ttm.isFiring = true;
      g_ttm.lastSignal = (g_ttm.momentumDir > 0) ? "FIRE_UP" : (g_ttm.momentumDir < 0 ? "FIRE_DOWN" : "FIRE");
   }
   else if(g_ttm.isSqueezing)
   {
      g_ttm.lastSignal = "SQUEEZE";
   }
   else if(!g_ttm.isFiring)
   {
      g_ttm.lastSignal = "NONE";
   }

   // Dessin graphique
   if(TTM_DRAW_ON_CHART)
      SMC_TTM_Draw(sym, tf, atr0);

   return true;
}

//+------------------------------------------------------------------+
//| Dessin graphique (points + histogramme léger)                    |
//+------------------------------------------------------------------+
void SMC_TTM_Draw(const string sym, const ENUM_TIMEFRAMES tf, const double atr0)
{
   // On dessine uniquement sur les 40 dernières barres pour rester léger
   const int maxBars = 40;
   string prefix = "TTM_" + sym + "_";

   // Nettoyage ancien
   ObjectsDeleteAll(0, prefix);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, tf, 0, maxBars + 2, rates) < maxBars) return;

   double bbU[], bbL[], atr[], ma[];
   ArraySetAsSeries(bbU, true); ArraySetAsSeries(bbL, true);
   ArraySetAsSeries(atr, true); ArraySetAsSeries(ma, true);

   if(CopyBuffer(g_ttmBBHandle, 1, 0, maxBars, bbU) < maxBars) return;
   if(CopyBuffer(g_ttmBBHandle, 2, 0, maxBars, bbL) < maxBars) return;
   if(CopyBuffer(g_ttmATRHandle, 0, 0, maxBars, atr) < maxBars) return;
   if(CopyBuffer(g_ttmMAHandle,  0, 0, maxBars, ma)  < maxBars) return;

   for(int i = 0; i < maxBars; i++)
   {
      double kcU = ma[i] + TTM_KC_MULT * atr[i];
      double kcL = ma[i] - TTM_KC_MULT * atr[i];
      bool sq = (bbU[i] < kcU && bbL[i] > kcL);

      // Point sous la bougie
      string dotName = prefix + "DOT_" + IntegerToString(i);
      double y = rates[i].low - atr[i] * 0.35;
      color  clr = sq ? clrRed : clrLime;

      if(ObjectCreate(0, dotName, OBJ_ARROW, 0, rates[i].time, y))
      {
         ObjectSetInteger(0, dotName, OBJPROP_ARROWCODE, 159); // petit point
         ObjectSetInteger(0, dotName, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, dotName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, dotName, OBJPROP_BACK, false);
         ObjectSetInteger(0, dotName, OBJPROP_SELECTABLE, false);
      }
   }

   // Histogramme momentum (barres verticales légères sous le prix)
   // On utilise des OBJ_TREND courts pour simuler un histo
   double momScale = atr0 * TTM_HISTO_SCALE;
   for(int i = 0; i < MathMin(25, maxBars); i++)
   {
      double sumHL = 0.0;
      int cnt = 0;
      for(int k = i; k < i + TTM_MOM_PERIOD && k < maxBars; k++)
      {
         sumHL += (rates[k].high + rates[k].low) * 0.5;
         cnt++;
      }
      if(cnt < 3) continue;
      double midAvg = sumHL / (double)cnt;
      double mom = rates[i].close - midAvg;

      string histName = prefix + "HIST_" + IntegerToString(i);
      double base = rates[i].low - atr[i] * 0.55;
      double tip  = base + MathMax(-momScale, MathMin(momScale, mom * 0.8));

      color hClr = (mom >= 0) ? clrDodgerBlue : clrOrangeRed;
      if(ObjectCreate(0, histName, OBJ_TREND, 0, rates[i].time, base, rates[i].time, tip))
      {
         ObjectSetInteger(0, histName, OBJPROP_COLOR, hClr);
         ObjectSetInteger(0, histName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, histName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, histName, OBJPROP_BACK, false);
         ObjectSetInteger(0, histName, OBJPROP_SELECTABLE, false);
      }
   }

   // Label statut en bas à gauche (juste au-dessus de la zone GOM si possible)
   string lbl = prefix + "STATUS";
   ObjectDelete(0, lbl);
   if(ObjectCreate(0, lbl, OBJ_LABEL, 0, 0, 0))
   {
      string txt = "TTM ";
      color  c   = clrSilver;
      if(g_ttm.isSqueezing)
      {
         txt += "SQUEEZE ×" + IntegerToString(g_ttm.squeezeBars) +
                " (" + DoubleToString(g_ttm.squeezeWidthPct, 0) + "%)";
         c = clrRed;
      }
      else if(g_ttm.isFiring)
      {
         txt += g_ttm.lastSignal + "  Mom=" + (g_ttm.momentumDir > 0 ? "UP" : "DOWN");
         c = (g_ttm.momentumDir > 0) ? clrLime : clrOrangeRed;
      }
      else
      {
         txt += "IDLE  Mom=" + DoubleToString(g_ttm.momentumValue, _Digits);
         c = clrGray;
      }

      ObjectSetInteger(0, lbl, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, lbl, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, lbl, OBJPROP_YDISTANCE, 28);
      ObjectSetString(0, lbl, OBJPROP_TEXT, txt);
      ObjectSetString(0, lbl, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, c);
      ObjectSetInteger(0, lbl, OBJPROP_BACK, false);
   }
}

//+------------------------------------------------------------------+
//| API publique pour l'EA                                           |
//+------------------------------------------------------------------+
bool   SMC_TTM_IsSqueezing()       { return g_ttm.ready && g_ttm.isSqueezing; }
bool   SMC_TTM_IsFiring()          { return g_ttm.ready && g_ttm.isFiring; }
int    SMC_TTM_MomentumDir()       { return g_ttm.ready ? g_ttm.momentumDir : 0; }
double SMC_TTM_MomentumStrength()  { return g_ttm.ready ? g_ttm.momentumStrength : 0.0; }
int    SMC_TTM_SqueezeBars()       { return g_ttm.ready ? g_ttm.squeezeBars : 0; }
double SMC_TTM_SqueezeWidthPct()   { return g_ttm.ready ? g_ttm.squeezeWidthPct : 100.0; }
string SMC_TTM_LastSignal()        { return g_ttm.ready ? g_ttm.lastSignal : "NONE"; }

// Score 0–20 points pour le Confluence Ribbon / Master Score
// - Compression longue et étroite = points élevés
// - Fire avec momentum fort = points encore plus élevés
int SMC_TTM_ConfluencePoints(const int dirSign)
{
   if(!g_ttm.ready) return 0;

   int pts = 0;

   // Squeeze actif (préparation)
   if(g_ttm.isSqueezing)
   {
      pts += 6;
      if(g_ttm.squeezeBars >= TTM_SQUEEZE_LOOKBACK) pts += 4;
      if(g_ttm.squeezeWidthPct < 70.0) pts += 3;   // compression forte
      if(g_ttm.squeezeWidthPct < 55.0) pts += 2;   // très forte
   }

   // Fire (sortie) + direction alignée
   if(g_ttm.isFiring)
   {
      pts += 8;
      if(dirSign != 0 && g_ttm.momentumDir == dirSign)
         pts += 7;
      else if(dirSign != 0 && g_ttm.momentumDir == -dirSign)
         pts -= 5; // pénalité si momentum contraire
      if(g_ttm.momentumStrength >= 0.55) pts += 3;
   }
   // Momentum seul (pas encore fire) — bonus léger
   else if(dirSign != 0 && g_ttm.momentumDir == dirSign && g_ttm.momentumStrength >= 0.45)
   {
      pts += 3;
   }

   return MathMax(0, MathMin(20, pts));
}

// Gate booléen simple pour les entrées spike / volatility
bool SMC_TTM_AllowsEntry(const int dirSign, string &whyOut)
{
   whyOut = "";
   if(!g_ttm.ready)
   {
      whyOut = "TTM non initialisé";
      return true; // ne bloque pas si module absent
   }

   // En squeeze long → on préfère attendre le fire (sauf PERFECT GOM)
   if(g_ttm.isSqueezing && g_ttm.squeezeBars >= TTM_SQUEEZE_LOOKBACK + 2)
   {
      // On autorise quand même si momentum déjà très fort dans la bonne direction
      if(dirSign != 0 && g_ttm.momentumDir == dirSign && g_ttm.momentumStrength >= 0.70)
      {
         whyOut = "TTM SQUEEZE + mom fort aligné → OK anticipé";
         return true;
      }
      whyOut = "TTM SQUEEZE actif (" + IntegerToString(g_ttm.squeezeBars) +
               " bars) — attendre FIRE";
      return false;
   }

   // Fire avec momentum contraire → refus
   if(g_ttm.isFiring && dirSign != 0 && g_ttm.momentumDir != 0 && g_ttm.momentumDir != dirSign)
   {
      whyOut = "TTM FIRE momentum contraire (" +
               (g_ttm.momentumDir > 0 ? "UP" : "DOWN") + ")";
      return false;
   }

   // Fire aligné → excellent
   if(g_ttm.isFiring && (dirSign == 0 || g_ttm.momentumDir == dirSign))
   {
      whyOut = "TTM FIRE " + g_ttm.lastSignal + " aligné";
      return true;
   }

   whyOut = "TTM neutre";
   return true; // par défaut on ne bloque pas
}

#endif // SMC_TTM_SQUEEZE_MQH
