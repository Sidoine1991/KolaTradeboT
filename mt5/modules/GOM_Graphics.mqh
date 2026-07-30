//+------------------------------------------------------------------+
//| GOM_Graphics.mqh � Dessine Bollinger + Zones futures + Signaux         |
//+------------------------------------------------------------------+
#ifndef GOM_GRAPHICS_MQH
#define GOM_GRAPHICS_MQH

#include "SMC_SymbolCategory.mqh"

#ifndef SMC_GOM_PIPELINE_MQH
extern string   g_cogDirection;
extern string   g_smcGomGlobalDir;
extern int      g_smcGomRsi;
extern double   g_smcCogClose[];
extern double   g_smcCogHigh[];
extern double   g_smcCogLow[];
extern double   g_smcPredPathMid[];
extern double   g_smcPredPathUp[];
extern double   g_smcPredPathDn[];
extern double   g_smcPredBbMid[];
extern double   g_smcPredBbUp[];
extern double   g_smcPredBbDn[];
#endif

extern bool     g_SH_available;
extern double   g_SH_hazardPct;
extern string   g_SH_regime;

//+------------------------------------------------------------------+
// Enum�ration des signaux de trading GOM                                     |
//+------------------------------------------------------------------+
enum TradingSignal
{
    SIGNAL_NONE = 0,            // Aucun signal
    SIGNAL_BUY_ENTER = 1,        // Acheter maintenant
    SIGNAL_BUY_PREPARE = 2,       // Pr�parer � acheter
    SIGNAL_SELL_ENTER = 3,       // Vendre maintenant
    SIGNAL_SELL_PREPARE = 4,      // Pr�parer � vendre
    SIGNAL_EXIT_NOW = 5,         // Sortir maintenant - urgent
    SIGNAL_EXIT_SOON = 6,        // Pr�parer � sortir - bient�t
    SIGNAL_HOLD_LONG = 7,        // Conserver long
    SIGNAL_HOLD_SHORT = 8        // Conserver court
};

//+------------------------------------------------------------------+
// Param�tres pour les signaux centraux                                       |
//+------------------------------------------------------------------+
// Taille de la zone de signal central
#define GOM_CENTER_SIGNAL_SIZE_X 60  // Largeur X du signal central
#define GOM_CENTER_SIGNAL_SIZE_Y 40  // Hauteur Y du signal central
#define GOM_CENTER_ZOOM     1.5     // Taille du zoom pour les ic�nes centraux
#define GOM_SIGNAL_BLINK_DURATION 2
//--- No-repaint signal confirm
#define GOM_CONFIRM_COUNT      2     // polls consecutifs pour confirmer le signal
#define GOM_COMMIT_TIMEOUT_SEC 300   // timeout d'un signal commit\ (secondes)
#define GOM_EXIT_COOLDOWN_SEC  60    // cooldown EXIT avant re-entr\e
 // Dur�e de clignotement en secondes
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
// Dessiner les bandes Bollinger depuis GOM                                   |
//+------------------------------------------------------------------+
void GOMG_DrawBollinger(double bb_up, double bb_mid, double bb_dn)
{
    if(bb_up <= 0 || bb_mid <= 0 || bb_dn <= 0) return;

    datetime now = TimeCurrent();
    datetime future = now + 3600; // 1 heure dans le futur

    // Bande sup�rieure (OBJ_TREND = droite)
    string bbUpName = "GOM_BB_UP";
    ObjectDelete(0, bbUpName);
    ObjectCreate(0, bbUpName, OBJ_TREND, 0, now, bb_up, future, bb_up);
    ObjectSetInteger(0, bbUpName, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, bbUpName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, bbUpName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, bbUpName, OBJPROP_RAY_RIGHT, true);
    ObjectSetInteger(0, bbUpName, OBJPROP_BACK, false);

    // Bande du milieu (OBJ_TREND = droite)
    string bbMidName = "GOM_BB_MID";
    ObjectDelete(0, bbMidName);
    ObjectCreate(0, bbMidName, OBJ_TREND, 0, now, bb_mid, future, bb_mid);
    ObjectSetInteger(0, bbMidName, OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(0, bbMidName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, bbMidName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, bbMidName, OBJPROP_RAY_RIGHT, true);
    ObjectSetInteger(0, bbMidName, OBJPROP_BACK, false);

    // Bande inf�rieure (OBJ_TREND = droite)
    string bbDnName = "GOM_BB_DN";
    ObjectDelete(0, bbDnName);
    ObjectCreate(0, bbDnName, OBJ_TREND, 0, now, bb_dn, future, bb_dn);
    ObjectSetInteger(0, bbDnName, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, bbDnName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, bbDnName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, bbDnName, OBJPROP_RAY_RIGHT, true);
    ObjectSetInteger(0, bbDnName, OBJPROP_BACK, false);

    Print("[GOMG] Bollinger dessin�es: UP=", bb_up, " MID=", bb_mid, " DN=", bb_dn);
}

//+------------------------------------------------------------------+
// Calculer le signal de trading GOM � partir du verdict actuel                   |
//+------------------------------------------------------------------+
// ── No-repaint : état global du signal commité ──
TradingSignal g_gomCommittedSignal  = SIGNAL_NONE;
int           g_gomCommittedDir     = 0;   // +1 buy, -1 sell
int           g_gomConfirmCount     = 0;   // compteur de confirmation dans la même direction
datetime      g_gomCommittedTime    = 0;

TradingSignal GOM_CalcSignal(int verdictNum, int prevVerdictNum = 0,
                              double quality = 0, double coherence = 0)
{
    // ── WAIT ──
    if(verdictNum == 0)
    {
        // Si commité, garder jusqu'au timeout (no-repaint)
        if(g_gomCommittedSignal != SIGNAL_NONE)
        {
            if(TimeCurrent() - g_gomCommittedTime > GOM_COMMIT_TIMEOUT_SEC)
            {
                g_gomCommittedSignal = SIGNAL_NONE;
                g_gomCommittedDir = 0;
                g_gomConfirmCount = 0;
                return SIGNAL_NONE;
            }
            return g_gomCommittedSignal; // garder l'ancien signal
        }
        return SIGNAL_NONE;
    }

    int nowDir = (verdictNum > 0) ? 1 : -1;
    int nowMag = MathAbs(verdictNum);

    // ── REVERSAL: direction opposée au signal commité → EXIT NOW ──
    if(g_gomCommittedDir != 0 && g_gomCommittedDir != nowDir)
    {
        g_gomCommittedSignal = SIGNAL_EXIT_NOW;
        g_gomCommittedDir = 0;
        g_gomConfirmCount = 0;
        g_gomCommittedTime = TimeCurrent();
        return SIGNAL_EXIT_NOW;
    }

    // ── Pas de signal commité : accumuler des confirmations ──
    if(g_gomCommittedSignal == SIGNAL_NONE)
    {
        // PERFECT → commit immédiat
        if(nowMag >= 3)
        {
            g_gomCommittedSignal = (verdictNum > 0) ? SIGNAL_BUY_ENTER : SIGNAL_SELL_ENTER;
            g_gomCommittedDir = nowDir;
            g_gomConfirmCount = GOM_CONFIRM_COUNT;
            g_gomCommittedTime = TimeCurrent();
            return g_gomCommittedSignal;
        }

        // COMPTER les confirmations (GOOD + qualité cohérente)
        if(nowMag >= 2 && quality >= 60 && coherence >= 50)
        {
            g_gomConfirmCount++;
            if(g_gomConfirmCount >= GOM_CONFIRM_COUNT)
            {
                g_gomCommittedSignal = (verdictNum > 0) ? SIGNAL_BUY_ENTER : SIGNAL_SELL_ENTER;
                g_gomCommittedDir = nowDir;
                g_gomCommittedTime = TimeCurrent();
                return g_gomCommittedSignal;
            }
            // Pas encore assez de confirmations → PREPARE
            if(verdictNum > 0) return SIGNAL_BUY_PREPARE;
            return SIGNAL_SELL_PREPARE;
        }

        // |v|=1 → HOLD
        if(verdictNum > 0) return SIGNAL_HOLD_LONG;
        return SIGNAL_HOLD_SHORT;
    }

    // ── Signal déjà commité : NE PAS REPAINT ──
    if(g_gomCommittedDir == nowDir)
    {
        // Weakening: force épuisée (|v|≤1) → EXIT SOON
        if(nowMag <= 1)
        {
            g_gomCommittedSignal = SIGNAL_EXIT_SOON;
            g_gomCommittedDir = 0;
            g_gomConfirmCount = 0;
            g_gomCommittedTime = TimeCurrent();
            return SIGNAL_EXIT_SOON;
        }
        g_gomCommittedTime = TimeCurrent(); // reset timeout
        return g_gomCommittedSignal;        // inchangé (no-repaint)
    }

    // Fallback
    if(verdictNum > 0) return SIGNAL_HOLD_LONG;
    return SIGNAL_HOLD_SHORT;
}

//+------------------------------------------------------------------+
// Dessiner un signal central au centre du chart (OBJ_LABEL + CORNER) |
//+------------------------------------------------------------------+
void GOMG_DrawCentralSignal(TradingSignal signal, string verdict, double price)
{
    // Nettoyer tous les anciens signaux centraux
    ObjectsDeleteAll(0, "GOM_CENTER_");

    if(signal == SIGNAL_NONE)
        return;

    // -- Paramètres par type de signal --
    string label = "";
    color  sigColor = clrGray;
    int    fontSize = 14;
    bool   urgent = false;

    if(signal == SIGNAL_BUY_ENTER)     { label = "BUY";    sigColor = clrLime;       fontSize = 28; }
    else if(signal == SIGNAL_SELL_ENTER){ label = "SELL";   sigColor = clrRed;        fontSize = 28; }
    else if(signal == SIGNAL_BUY_PREPARE){ label = "BUY P"; sigColor = clrGold;       fontSize = 20; }
    else if(signal == SIGNAL_SELL_PREPARE){ label = "SELL P"; sigColor = clrOrange;   fontSize = 20; }
    else if(signal == SIGNAL_EXIT_NOW) { label = "EXIT NOW"; sigColor = 0xFF4500;     fontSize = 24; urgent = true; }
    else if(signal == SIGNAL_EXIT_SOON){ label = "EXIT";    sigColor = clrDarkOrange; fontSize = 18; urgent = true; }
    else if(signal == SIGNAL_HOLD_LONG){ label = "HOLD L";  sigColor = clrGray;       fontSize = 16; }
    else if(signal == SIGNAL_HOLD_SHORT){ label = "HOLD S"; sigColor = clrGray;       fontSize = 16; }

    // -- Position: centré sous le panel ChainCorr (380px, y=10→146) --
    int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    int sigW   = 280;
    int sigX   = MathMax(5, (chartW - sigW) / 2);
    int sigY   = 155;  // juste sous le panel ChainCorr (10 + 136 + 9)

    // -- Ligne 1 : Signal principal --
    string nameMain = "GOM_CENTER_MAIN";
    ObjectCreate(0, nameMain, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, nameMain, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, nameMain, OBJPROP_XDISTANCE, sigX + (sigW - 200) / 2);
    ObjectSetInteger(0, nameMain, OBJPROP_YDISTANCE, sigY);
    ObjectSetString(0, nameMain, OBJPROP_TEXT, label);
    ObjectSetInteger(0, nameMain, OBJPROP_COLOR, sigColor);
    ObjectSetInteger(0, nameMain, OBJPROP_FONTSIZE, fontSize);
    ObjectSetString(0, nameMain, OBJPROP_FONT, "Arial Black");
    ObjectSetInteger(0, nameMain, OBJPROP_SELECTABLE, false);

    // -- Ligne 2 : Sous-texte verdict --
    string nameSub = "GOM_CENTER_SUB";
    string subText = verdict;
    if(signal == SIGNAL_BUY_ENTER)        subText = verdict + " -> ENTER BUY";
    else if(signal == SIGNAL_SELL_ENTER)  subText = verdict + " -> ENTER SELL";
    else if(signal == SIGNAL_EXIT_NOW)    subText = "!! URGENT EXIT !!";
    else if(signal == SIGNAL_EXIT_SOON)   subText = "Prepare to exit";
    else if(signal == SIGNAL_BUY_PREPARE) subText = "Prepare to buy";
    else if(signal == SIGNAL_SELL_PREPARE) subText = "Prepare to sell";
    else if(signal == SIGNAL_HOLD_LONG)   subText = "Maintain long";
    else if(signal == SIGNAL_HOLD_SHORT)  subText = "Maintain short";

    ObjectCreate(0, nameSub, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, nameSub, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, nameSub, OBJPROP_XDISTANCE, sigX + (sigW - 180) / 2);
    ObjectSetInteger(0, nameSub, OBJPROP_YDISTANCE, sigY + fontSize + 4);
    ObjectSetString(0, nameSub, OBJPROP_TEXT, subText);
    ObjectSetInteger(0, nameSub, OBJPROP_COLOR, sigColor);
    ObjectSetInteger(0, nameSub, OBJPROP_FONTSIZE, 11);
    ObjectSetString(0, nameSub, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, nameSub, OBJPROP_SELECTABLE, false);

    // -- Fond semi-transparent pour TOUS les signaux (lisibilité garantie) --
    string nameBG = "GOM_CENTER_BG";
    ObjectCreate(0, nameBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, nameBG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, nameBG, OBJPROP_XDISTANCE, sigX);
    ObjectSetInteger(0, nameBG, OBJPROP_YDISTANCE, sigY - 6);
    ObjectSetInteger(0, nameBG, OBJPROP_XSIZE, sigW);
    ObjectSetInteger(0, nameBG, OBJPROP_YSIZE, fontSize + 32);
    ObjectSetInteger(0, nameBG, OBJPROP_BGCOLOR, 0xDD0A0A0A);
    ObjectSetInteger(0, nameBG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, nameBG, OBJPROP_BORDER_COLOR, urgent ? sigColor : 0xFF333333);
    ObjectSetInteger(0, nameBG, OBJPROP_COLOR, urgent ? sigColor : 0xFF333333);
    ObjectSetInteger(0, nameBG, OBJPROP_WIDTH, urgent ? 3 : 1);
    ObjectSetInteger(0, nameBG, OBJPROP_BACK, true);
    ObjectSetInteger(0, nameBG, OBJPROP_SELECTABLE, false);
    // Remettre le texte devant le fond
    ObjectSetInteger(0, nameMain, OBJPROP_BACK, false);
    ObjectSetInteger(0, nameSub, OBJPROP_BACK, false);

    Print(StringFormat("[GOMG] Signal central: %s | verdict=%s | price=%.5f | urgent=%s",
          label, verdict, price, urgent ? "YES" : "no"));

    // ── Push MT5 anti-spam: notifier uniquement au changement de signal ──
    static TradingSignal s_lastNotifSignal = SIGNAL_NONE;
    static string        s_lastNotifVerdict = "";
    if(signal != s_lastNotifSignal || verdict != s_lastNotifVerdict)
    {
        s_lastNotifSignal  = signal;
        s_lastNotifVerdict = verdict;
        string pushMsg = StringFormat("[GOM] %s | %s | %.5f", label, verdict, price);
        if(!SendNotification(pushMsg))
            Print("[GOM-PUSH] Echec — vérifier Options > Notifications MT5");
    }
}

//+------------------------------------------------------------------+
// Message de signal pour debug                                       |
//+------------------------------------------------------------------+
string GetSignalMessage(TradingSignal signal, string verdict)
{
    switch(signal)
    {
        case SIGNAL_BUY_ENTER:     return "BUY NOW - Entry Signal";
        case SIGNAL_BUY_PREPARE:   return "Prepare to buy";
        case SIGNAL_SELL_ENTER:    return "SELL NOW - Entry Signal";
        case SIGNAL_SELL_PREPARE:  return "Prepare to sell";
        case SIGNAL_EXIT_NOW:      return "EXIT NOW - Urgent!";
        case SIGNAL_EXIT_SOON:     return "Prepare to exit";
        case SIGNAL_HOLD_LONG:     return "Hold long position";
        case SIGNAL_HOLD_SHORT:    return "Hold short position";
        default:                   return "";
    }
}

//+------------------------------------------------------------------+
// Dessiner icône BUY (coin supérieur droit, backup)                  |
//+------------------------------------------------------------------+
void GOMG_DrawBuySignal(double price)
{
    string name = "GOM_CENTER_BUY";
    ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 60);
    ObjectSetString(0, name, OBJPROP_TEXT, "BUY");
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 18);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial Black");
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
// Dessiner icône SELL (coin supérieur droit, backup)                 |
//+------------------------------------------------------------------+
void GOMG_DrawSellSignal(double price)
{
    string name = "GOM_CENTER_SELL";
    ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 60);
    ObjectSetString(0, name, OBJPROP_TEXT, "SELL");
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 18);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial Black");
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
// Trajectoire GOM Prediction — 5 segments basés sur données réelles   |
// Synthése: cognition + GOM verdict + global direction + pred arrays  |
//+------------------------------------------------------------------+
void GOMG_DrawFutureZone(double zone_high, double zone_low, string label = "GOM_FUTURE_ZONE",
                         int gomDir = 0, double currentPrice = 0)
{
   if(zone_high <= 0 || zone_low <= 0) return;
   if(zone_high <= zone_low) return;

   // Nettoyer les anciens objets
   ObjectsDeleteAll(0, label);
   ObjectsDeleteAll(0, label + "_SEG");
   ObjectsDeleteAll(0, label + "_ARROW");
   ObjectsDeleteAll(0, label + "_LBL");
   ObjectsDeleteAll(0, label + "_INFO");
   ObjectsDeleteAll(0, label + "_SPIKE");
   ObjectsDeleteAll(0, label + "_HAZ");

   // === 0. DETECTER SYMBOLE SPIKE (Boom/Crash/PainX/GainX) ===
   bool isSpikeSymbol = (SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH);
   bool isBoom = isSpikeSymbol && (StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Gain") >= 0);
   bool isCrash = isSpikeSymbol && (StringFind(_Symbol, "Crash") >= 0 || StringFind(_Symbol, "Pain") >= 0);

   // === 1. SYNTHÈSE DIRECTION ===
   // Sources: g_cogDirection, g_smcGomVerdictNum, g_smcGomGlobalDir
   int score = 0;  // +N = BUY, -N = SELL
   int sources = 0;

   if(StringLen(g_cogDirection) > 0)
   {
      if(g_cogDirection == "BUY")  score += 1;
      if(g_cogDirection == "SELL") score -= 1;
      sources++;
   }
   if(gomDir != 0)
   {
      score += (gomDir > 0) ? 1 : -1;
      sources++;
   }
   if(StringLen(g_smcGomGlobalDir) > 0)
   {
      if(g_smcGomGlobalDir == "BULL") score += 1;
      if(g_smcGomGlobalDir == "BEAR") score -= 1;
      sources++;
   }
   if(g_smcGomRsi > 70)      { score -= 1; sources++; }
   else if(g_smcGomRsi < 30) { score += 1; sources++; }

   // === SPIKE HAZARD: ajouter le hazard comme source additionnelle ===
   bool spikeHazardActive = false;
   if(isSpikeSymbol && g_SH_available && g_SH_hazardPct > 50.0)
   {
      spikeHazardActive = true;
      // Le hazard elevé confirme la direction: spike vient de se produire
      // Sur Boom = le spike est haussier, sur Crash = le spike est baissier
      if(isBoom)  score += 2;  // Boom spike = prix monte
      if(isCrash) score -= 2;  // Crash spike = prix descend
      sources += 2;
   }

   bool bull = (score > 0);
   bool bear = (score < 0);
   bool valid = (sources >= 2 && score != 0);
   if(!valid)
   {
      // Pas assez de sources — dessiner zone neutre
      bull = false;
      bear = false;
   }

   color clr      = bull ? clrLime : (bear ? clrRed : clrDimGray);
   color clrLight = bull ? clrGreen : (bear ? clrOrangeRed : clrGray);
   color clrSpike = spikeHazardActive ? (isBoom ? clrGold : clrMagenta) : clr;

   // === 2. SÉLECTION DONNÉES PRÉDICTION ===
   // Priorité: cogClose > predPathMid > predBbMid (plusieurs sources = plus fiable)
   double predClose[];
   double predUp[];
   double predDn[];
   ArrayFree(predClose);
   ArrayFree(predUp);
   ArrayFree(predDn);

   int nPred = 0;
   if(ArraySize(g_smcCogClose) >= 2)
   {
      ArrayCopy(predClose, g_smcCogClose);
      if(ArraySize(g_smcCogHigh) >= 2) ArrayCopy(predUp, g_smcCogHigh);
      if(ArraySize(g_smcCogLow)  >= 2) ArrayCopy(predDn, g_smcCogLow);
      nPred = ArraySize(predClose);
   }
   else if(ArraySize(g_smcPredPathMid) >= 2)
   {
      ArrayCopy(predClose, g_smcPredPathMid);
      if(ArraySize(g_smcPredPathUp) >= 2) ArrayCopy(predUp, g_smcPredPathUp);
      if(ArraySize(g_smcPredPathDn) >= 2) ArrayCopy(predDn, g_smcPredPathDn);
      nPred = ArraySize(predClose);
   }
   else if(ArraySize(g_smcPredBbMid) >= 2)
   {
      ArrayCopy(predClose, g_smcPredBbMid);
      if(ArraySize(g_smcPredBbUp) >= 2) ArrayCopy(predUp, g_smcPredBbUp);
      if(ArraySize(g_smcPredBbDn) >= 2) ArrayCopy(predDn, g_smcPredBbDn);
      nPred = ArraySize(predClose);
   }

   // === 3. PRIX ACTUEL ===
   if(currentPrice <= 0) currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(currentPrice <= 0) currentPrice = (zone_high + zone_low) / 2.0;

   datetime now = TimeCurrent();
   int tfSec = PeriodSeconds(PERIOD_CURRENT);
   if(tfSec <= 0) tfSec = 60;

   // === 4. ÉCHANTILLONNER 5 SEGMENTS ===
   int maxSeg = 5;
   double segPrice[];
   double segUp[];
   double segDn[];
   ArrayResize(segPrice, maxSeg + 1);
   ArrayResize(segUp, maxSeg + 1);
   ArrayResize(segDn, maxSeg + 1);

   // Premier point = prix actuel
   segPrice[0] = currentPrice;
   segUp[0] = currentPrice;
   segDn[0] = currentPrice;

   if(nPred >= 2)
   {
      // Échantillonner uniformément dans les données de prédiction
      for(int s = 1; s <= maxSeg; s++)
      {
         int idx = (int)MathRound((double)s / maxSeg * (nPred - 1));
         if(idx >= nPred) idx = nPred - 1;
         if(idx < 0) idx = 0;
         segPrice[s] = predClose[idx];
         segUp[s] = (ArraySize(predUp) > idx) ? predUp[idx] : predClose[idx];
         segDn[s] = (ArraySize(predDn) > idx) ? predDn[idx] : predClose[idx];
      }
   }
   else
   {
      // Pas de données prédiction — interpolation linéaire vers zone
      double target = bull ? zone_high : (bear ? zone_low : (zone_high + zone_low) / 2.0);
      for(int s = 1; s <= maxSeg; s++)
      {
         double t = (double)s / maxSeg;
         segPrice[s] = currentPrice + (target - currentPrice) * t;
         segUp[s] = segPrice[s] + (zone_high - zone_low) * 0.02 * (1.0 - t);
         segDn[s] = segPrice[s] - (zone_high - zone_low) * 0.02 * (1.0 - t);
      }
   }

   // === 5. DESSINER LES 5 SEGMENTS ===
   // Si spike hazard actif, accélérer le timing (segments plus courts = plus réactif)
   int segDuration = spikeHazardActive ? (tfSec / 2) : (tfSec * 2);  // Hazard: 0.5 periodes, Normal: 2 periodes

   for(int s = 0; s < maxSeg; s++)
   {
      datetime t1 = now + (datetime)(s * segDuration);
      datetime t2 = now + (datetime)((s + 1) * segDuration);

      string segName = label + "_SEG" + IntegerToString(s);
      ObjectDelete(0, segName);
      ObjectCreate(0, segName, OBJ_TREND, 0, t1, segPrice[s], t2, segPrice[s + 1]);

      // Couleur: spike hazard = couleur spike, sinon normale
      color segClr = spikeHazardActive ? clrSpike : clr;
      ObjectSetInteger(0, segName, OBJPROP_COLOR, segClr);
      ObjectSetInteger(0, segName, OBJPROP_WIDTH, spikeHazardActive ? 4 : 3);
      ObjectSetInteger(0, segName, OBJPROP_STYLE, spikeHazardActive ? STYLE_SOLID : STYLE_SOLID);
      ObjectSetInteger(0, segName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, segName, OBJPROP_BACK, false);
      ObjectSetInteger(0, segName, OBJPROP_SELECTABLE, false);

      // Bande de confiance (UP/DN) en pointillé
      if(ArraySize(segUp) > s + 1 && segUp[s + 1] > 0)
      {
         string fanName = label + "_FAN" + IntegerToString(s);
         ObjectDelete(0, fanName);
         ObjectCreate(0, fanName, OBJ_TREND, 0, t2, segUp[s + 1], t2, segDn[s + 1]);
         ObjectSetInteger(0, fanName, OBJPROP_COLOR, clrLight);
         ObjectSetInteger(0, fanName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, fanName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, fanName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, fanName, OBJPROP_BACK, true);
         ObjectSetInteger(0, fanName, OBJPROP_SELECTABLE, false);
      }
   }

   // === 5b. LABEL SPIKE HAZARD (si actif) ===
   if(spikeHazardActive && isSpikeSymbol)
   {
      string spikeLbl = label + "_SPIKE";
      ObjectDelete(0, spikeLbl);
      datetime spikeTime = now + (datetime)(segDuration);
      double spikePrice = bull ? zone_high : zone_low;

      ObjectCreate(0, spikeLbl, OBJ_TEXT, 0, spikeTime, spikePrice);
      string spikeDir = isBoom ? "BOOM" : "CRASH";
      ObjectSetString(0, spikeLbl, OBJPROP_TEXT, "  >> " + spikeDir + " SPIKE <<" );
      ObjectSetString(0, spikeLbl, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, spikeLbl, OBJPROP_FONTSIZE, 11);
      ObjectSetInteger(0, spikeLbl, OBJPROP_COLOR, clrSpike);
      ObjectSetInteger(0, spikeLbl, OBJPROP_BACK, false);
      ObjectSetInteger(0, spikeLbl, OBJPROP_SELECTABLE, false);

      // Label hazard percentage
      string hazLbl = label + "_HAZ";
      ObjectDelete(0, hazLbl);
      ObjectCreate(0, hazLbl, OBJ_TEXT, 0, spikeTime, spikePrice);
      ObjectSetString(0, hazLbl, OBJPROP_TEXT, "  HAZ " + DoubleToString(g_SH_hazardPct, 1) + "% [" + g_SH_regime + "]");
      ObjectSetString(0, hazLbl, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, hazLbl, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, hazLbl, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, hazLbl, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, hazLbl, OBJPROP_BACK, false);
      ObjectSetInteger(0, hazLbl, OBJPROP_SELECTABLE, false);
   }

   // === 6. FLÈCHE FINALE ===
   datetime tEnd = now + (datetime)(maxSeg * segDuration);
   double pEnd = segPrice[maxSeg];
   int arrowCode = bull ? 233 : (bear ? 234 : 159);  // 233=haut, 234=bas, 159=point

   string arrowName = label + "_ARROW";
   ObjectDelete(0, arrowName);
   ObjectCreate(0, arrowName, OBJ_ARROW, 0, tEnd, pEnd);
   ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
   ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);

   // === 7. LABEL DIRECTION + LABEL INFO ===
   string dirTxt;
   if(isSpikeSymbol)
   {
      // Pour Boom/Crash: afficher BOOM/CRASH au lieu de BUY/SELL
      if(bull)      dirTxt = isBoom ? "BOOM" : "REVERSAL";
      else if(bear) dirTxt = isCrash ? "CRASH" : "REVERSAL";
      else          dirTxt = "WAIT";
      if(spikeHazardActive) dirTxt += " !";
   }
   else
   {
      dirTxt = bull ? "BUY" : (bear ? "SELL" : "WAIT");
   }
   string lblName = label + "_LBL";
   ObjectDelete(0, lblName);
   ObjectCreate(0, lblName, OBJ_TEXT, 0, tEnd, pEnd);
   ObjectSetString(0, lblName, OBJPROP_TEXT, "  " + dirTxt);
   ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lblName, OBJPROP_BACK, false);
   ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);

   // Label synthèse sources
   string infoTxt = "src=" + IntegerToString(sources)
                  + " score=" + IntegerToString(score)
                  + " gom=" + IntegerToString(gomDir);
   if(g_smcGomRsi > 0) infoTxt += " rsi=" + IntegerToString(g_smcGomRsi);
   if(nPred > 0)       infoTxt += " pred=" + IntegerToString(nPred);
   if(spikeHazardActive) infoTxt += " SH=" + DoubleToString(g_SH_hazardPct, 0) + "%";
   string infoName = label + "_INFO";
   ObjectDelete(0, infoName);
   ObjectCreate(0, infoName, OBJ_TEXT, 0, tEnd, pEnd);
   ObjectSetString(0, infoName, OBJPROP_TEXT, "  " + infoTxt);
   ObjectSetString(0, infoName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, infoName, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, infoName, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, infoName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, infoName, OBJPROP_BACK, false);
   ObjectSetInteger(0, infoName, OBJPROP_SELECTABLE, false);

   Print("[GOMG] Trajectoire ", dirTxt, " | sources=", sources, " score=", score,
         " | pred=", nPred, " pts | ", currentPrice, " → ", pEnd);
}

//+------------------------------------------------------------------+
// Dessiner le niveau Kola
//+------------------------------------------------------------------+
void GOMG_DrawKolaLevels(double kola_buy, double kola_sell)
{
   if(kola_buy > 0)
   {
      string kolaBuyName = "GOM_KOLA_BUY";
      ObjectDelete(0, kolaBuyName);
      ObjectCreate(0, kolaBuyName, OBJ_HLINE, 0, 0, kola_buy);
      ObjectSetInteger(0, kolaBuyName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, kolaBuyName, OBJPROP_WIDTH, 3);
   }

   if(kola_sell > 0)
   {
      string kolaSellName = "GOM_KOLA_SELL";
      ObjectDelete(0, kolaSellName);
      ObjectCreate(0, kolaSellName, OBJ_HLINE, 0, 0, kola_sell);
      ObjectSetInteger(0, kolaSellName, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, kolaSellName, OBJPROP_WIDTH, 3);
   }

   Print("[GOMG] Niveaux Kola: BUY=", kola_buy, " SELL=", kola_sell);
}

//+------------------------------------------------------------------+
// Tracer les Bollinger Bands PR�DITES (300 bougies) � Courbes continues
//+------------------------------------------------------------------+
void GOMG_DrawBollingerPrediction(double& pred_bb_mid[], double& pred_bb_up[], double& pred_bb_dn[])
{
   if(ArraySize(pred_bb_mid) < 2) return;

   datetime now = TimeCurrent();
   int n_points = ArraySize(pred_bb_mid);

   // Intervalle temporel entre points (30s par d�faut pour M1 = 60 points/min)
   int time_step = 60; // 1 min per point

   // ?? Tracer MID (bleu, solide, ?pais) ??
   for(int i = 0; i < n_points - 1; i++)
   {
      string line_name = "GOM_PRED_MID_" + IntegerToString(i);
      datetime t1 = now + (i * time_step);
      datetime t2 = now + ((i + 1) * time_step);

      ObjectDelete(0, line_name);
      ObjectCreate(0, line_name, OBJ_TREND, 0, t1, pred_bb_mid[i], t2, pred_bb_mid[i + 1]);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
   }

   // ?? Tracer UP (rouge, pointill�) ??
   for(int i = 0; i < n_points - 1; i++)
   {
      string line_name = "GOM_PRED_UP_" + IntegerToString(i);
      datetime t1 = now + (i * time_step);
      datetime t2 = now + ((i + 1) * time_step);

      ObjectDelete(0, line_name);
      ObjectCreate(0, line_name, OBJ_TREND, 0, t1, pred_bb_up[i], t2, pred_bb_up[i + 1]);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
   }

   // ?? Tracer DN (vert, pointill�) ??
   for(int i = 0; i < n_points - 1; i++)
   {
      string line_name = "GOM_PRED_DN_" + IntegerToString(i);
      datetime t1 = now + (i * time_step);
      datetime t2 = now + ((i + 1) * time_step);

      ObjectDelete(0, line_name);
      ObjectCreate(0, line_name, OBJ_TREND, 0, t1, pred_bb_dn[i], t2, pred_bb_dn[i + 1]);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
   }

   Print("[GOMG] Bollinger Predictions dessin�es: " + IntegerToString(n_points) + " points");
}

//+------------------------------------------------------------------+
// Tracer la zone de RETRACEMENT (barr�e semi-transparente)
//+------------------------------------------------------------------+
void GOMG_DrawRetracementZone(const string symbol, double zone_low, double zone_high, string label = "GOM_RETRACEMENT_ZONE")
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   datetime now = TimeCurrent();
   datetime future = now + PeriodSeconds(PERIOD_CURRENT) * 20;

   if(!ObjectCreate(0, label, OBJ_RECTANGLE, 0, now, zone_low, future, zone_high))
   {
      Print("[GOMG] ERREUR: ObjectCreate RECTANGLE ", label, " a échoué");
      return;
   }

   ObjectSetInteger(0, label, OBJPROP_COLOR, ColorToARGB(clrWhite, 30));
   ObjectSetInteger(0, label, OBJPROP_FILL, true);
   ObjectSetInteger(0, label, OBJPROP_BACK, true);
   ObjectSetInteger(0, label, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, label, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, label, OBJPROP_SELECTABLE, false);

   Print("[GOMG] Zone Retracement dessinée: ", symbol,
         " [", DoubleToString(zone_low, digits), " - ", DoubleToString(zone_high, digits), "]");
}

//+------------------------------------------------------------------+
// Nettoyer tous les dessins GOM
//+------------------------------------------------------------------+
void GOMG_ClearAll()
{
   ObjectDelete(0, "GOM_BB_UP");
   ObjectDelete(0, "GOM_BB_MID");
   ObjectDelete(0, "GOM_BB_DN");
   ObjectDelete(0, "GOM_KOLA_BUY");
   ObjectDelete(0, "GOM_KOLA_SELL");
   ObjectsDeleteAll(0, "GOM_PRED_ZONE");
   ObjectsDeleteAll(0, "GOM_PRED_MID_");
   ObjectsDeleteAll(0, "GOM_PRED_UP_");
   ObjectsDeleteAll(0, "GOM_PRED_DN_");
   Print("[GOMG] Tous les dessins GOM nettoyés");
}

#endif

