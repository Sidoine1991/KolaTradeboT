//+------------------------------------------------------------------+
//| SMC_AdvancedRangeDetection.mqh — Détection avancée de range    |
//| Pattern EA Gold Stuff fix + Index Synthetics EA                 |
//| Détection range avant entrée + WAIT forcé après 2 ranges plats   |
//+------------------------------------------------------------------+
#ifndef SMC_ADVANCED_RANGE_DETECTION_MQH
#define SMC_ADVANCED_RANGE_DETECTION_MQH

#include "SMC_SharedCore.mqh"

// ── État de détection de range ─────────────────────────────────────────────
struct SMC_RangeState {
   bool inRange;
   double rangeHigh;
   double rangeLow;
   double rangeMid;
   datetime rangeStart;
   int rangeBars;
   double slope;           // Pente du range (positive = haussier, négative = baissier)
   bool isFlatRange;       // Range à pente plate (slope proche de 0)
   int consecutiveFlatRanges; // Compteur de ranges plats consécutifs
   double rangeWidthATR;   // Largeur du range en ATR
   double breakoutStrength; // Force du breakout potentiel
};

SMC_RangeState g_rangeState;
datetime g_lastRangeCheck = 0;

// ── Configuration de détection de range ───────────────────────────────────
input int    InpRangeLookback        = 20;    // Nombre de bougies pour détecter range
input double InpRangeWidthATRMax    = 0.8;   // Largeur max range (en ATR)
input double InpRangeSlopeThreshold  = 0.05;  // Seuil de pente pour range "plat"
input int    InpFlatRangeWaitBars   = 2;     // Nombre de ranges plats avant WAIT forcé
input double InpBreakoutThreshold   = 1.5;   // Seuil ATR pour confirmer breakout
input int    InpRangeMinBars        = 10;    // Nombre minimum de bougies pour confirmer range

// ── Initialiser l'état de range ───────────────────────────────────────────
void SMC_Range_Init()
{
   g_rangeState.inRange = false;
   g_rangeState.rangeHigh = 0;
   g_rangeState.rangeLow = 0;
   g_rangeState.rangeMid = 0;
   g_rangeState.rangeStart = 0;
   g_rangeState.rangeBars = 0;
   g_rangeState.slope = 0;
   g_rangeState.isFlatRange = false;
   g_rangeState.consecutiveFlatRanges = 0;
   g_rangeState.rangeWidthATR = 0;
   g_rangeState.breakoutStrength = 0;
   g_lastRangeCheck = 0;
}

// ── Mettre à jour la détection de range ───────────────────────────────────
void SMC_Range_Update(const string symbol, const ENUM_TIMEFRAMES tf)
{
   // Mettre à jour seulement toutes les 60 secondes max
   if(TimeCurrent() - g_lastRangeCheck < 60) return;
   g_lastRangeCheck = TimeCurrent();
   
   MqlRates rates[];
   int copied = CopyRates(symbol, tf, 0, InpRangeLookback, rates);
   if(copied < InpRangeMinBars) {
      g_rangeState.inRange = false;
      return;
   }
   
   ArraySetAsSeries(rates, true);
   
   // Calculer les highs/lows sur la période
   double highMax = rates[0].high;
   double lowMin = rates[0].low;
   double highSum = 0, lowSum = 0;
   
   for(int i = 0; i < copied; i++) {
      if(rates[i].high > highMax) highMax = rates[i].high;
      if(rates[i].low < lowMin) lowMin = rates[i].low;
      highSum += rates[i].high;
      lowSum += rates[i].low;
   }
   
   double highAvg = highSum / copied;
   double lowAvg = lowSum / copied;
   
   // Calculer ATR pour normaliser
   double atr = iATR(symbol, tf, 14);
   if(atr <= 0) return;
   
   double rangeWidth = highMax - lowMin;
   double rangeWidthATR = rangeWidth / atr;
   
   // Déterminer si c'est un range
   bool isRange = (rangeWidthATR <= InpRangeWidthATRMax);
   
   // Calculer la pente du range (régression linéaire simple)
   double slope = 0;
   if(isRange) {
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for(int i = 0; i < copied; i++) {
         double x = (double)i;
         double y = (rates[i].high + rates[i].low) / 2.0; // Point médian
         sumX += x;
         sumY += y;
         sumXY += x * y;
         sumX2 += x * x;
      }
      double n = (double)copied;
      slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
      
      // Normaliser la pente par ATR
      slope = slope / atr;
   }
   
   // Déterminer si le range est "plat"
   bool isFlat = (MathAbs(slope) <= InpRangeSlopeThreshold);
   
   // Mettre à jour l'état
   bool wasInRange = g_rangeState.inRange;
   bool wasFlat = g_rangeState.isFlatRange;
   
   g_rangeState.inRange = isRange;
   g_rangeState.rangeHigh = highMax;
   g_rangeState.rangeLow = lowMin;
   g_rangeState.rangeMid = (highMax + lowMin) / 2.0;
   g_rangeState.rangeBars = copied;
   g_rangeState.slope = slope;
   g_rangeState.isFlatRange = isFlat;
   g_rangeState.rangeWidthATR = rangeWidthATR;
   
   // Gérer le compteur de ranges plats consécutifs
   if(isRange && isFlat) {
      if(!wasInRange || !wasFlat) {
         // Nouveau range plat détecté
         g_rangeState.consecutiveFlatRanges++;
      }
   } else if(!isRange) {
      // Reset si on sort du range
      if(wasInRange) {
         // Vérifier si c'était un range plat
         if(wasFlat && g_rangeState.consecutiveFlatRanges >= InpFlatRangeWaitBars) {
            Print("🔄 Range plat terminé après ", g_rangeState.consecutiveFlatRanges, " occurrences sur ", symbol);
         }
      }
      g_rangeState.consecutiveFlatRanges = 0;
   }
   
   // Calculer la force de breakout potentielle
   if(isRange) {
      double currentPrice = (rates[0].high + rates[0].low) / 2.0;
      double distFromMid = MathAbs(currentPrice - g_rangeState.rangeMid);
      g_rangeState.breakoutStrength = distFromMid / atr;
   } else {
      g_rangeState.breakoutStrength = 0;
   }
}

// ── Vérifier si le prix est dans un range ───────────────────────────────────
bool SMC_Range_IsInRange()
{
   return g_rangeState.inRange;
}

// ── Vérifier si le range est plat (pente faible) ─────────────────────────
bool SMC_Range_IsFlatRange()
{
   return g_rangeState.isFlatRange;
}

// ── Vérifier si on doit forcer WAIT (après 2+ ranges plats) ───────────────
bool SMC_Range_ShouldForceWait()
{
   return (g_rangeState.consecutiveFlatRanges >= InpFlatRangeWaitBars);
}

// ── Obtenir le nombre de ranges plats consécutifs ─────────────────────────
int SMC_Range_GetConsecutiveFlatRanges()
{
   return g_rangeState.consecutiveFlatRanges;
}

// ── Vérifier si un breakout est imminent (prix proche des bornes) ──────────
bool SMC_Range_IsBreakoutImminent(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!g_rangeState.inRange) return false;
   
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double atr = iATR(symbol, tf, 14);
   if(atr <= 0) return false;
   
   double distToHigh = g_rangeState.rangeHigh - bid;
   double distToLow = bid - g_rangeState.rangeLow;
   double minDist = MathMin(distToHigh, distToLow);
   
   // Breakout imminent si proche d'une borne (< 0.3 ATR)
   return (minDist / atr < 0.3);
}

// ── Obtenir la direction probable de breakout ─────────────────────────────
int SMC_Range_GetBreakoutDirection(const string symbol)
{
   if(!g_rangeState.inRange) return 0;
   
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double distToHigh = g_rangeState.rangeHigh - bid;
   double distToLow = bid - g_rangeState.rangeLow;
   
   if(distToHigh < distToLow) return 1;  // Probable breakout haut
   if(distToLow < distToHigh) return -1; // Probable breakout bas
   return 0; // Indéterminé
}

// ── Obtenir la largeur du range en ATR ────────────────────────────────────
double SMC_Range_GetWidthATR()
{
   return g_rangeState.rangeWidthATR;
}

// ── Obtenir la pente du range ─────────────────────────────────────────────
double SMC_Range_GetSlope()
{
   return g_rangeState.slope;
}

// ── Dessiner les bornes du range sur le graphique ─────────────────────────
void SMC_Range_Draw(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!g_rangeState.inRange) return;
   
   datetime timeStart = iTime(symbol, tf, InpRangeLookback - 1);
   datetime timeEnd = iTime(symbol, tf, 0) + PeriodSeconds(tf) * 5;
   
   string nameHigh = "SMC_RANGE_HIGH_" + IntegerToString(TimeCurrent());
   string nameLow = "SMC_RANGE_LOW_" + IntegerToString(TimeCurrent());
   
   // Ligne haute
   ObjectCreate(0, nameHigh, OBJ_TREND, 0, timeStart, g_rangeState.rangeHigh, timeEnd, g_rangeState.rangeHigh);
   ObjectSetInteger(0, nameHigh, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, nameHigh, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nameHigh, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, nameHigh, OBJPROP_RAY_RIGHT, false);
   
   // Ligne basse
   ObjectCreate(0, nameLow, OBJ_TREND, 0, timeStart, g_rangeState.rangeLow, timeEnd, g_rangeState.rangeLow);
   ObjectSetInteger(0, nameLow, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, nameLow, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nameLow, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, nameLow, OBJPROP_RAY_RIGHT, false);
   
   // Label avec info
   string nameLabel = "SMC_RANGE_LABEL_" + IntegerToString(TimeCurrent());
   string labelText = StringFormat("Range: %.1f ATR | Slope: %.3f | Flat: %s | Count: %d",
                                    g_rangeState.rangeWidthATR,
                                    g_rangeState.slope,
                                    g_rangeState.isFlatRange ? "YES" : "NO",
                                    g_rangeState.consecutiveFlatRanges);
   
   ObjectCreate(0, nameLabel, OBJ_TEXT, 0, timeEnd, g_rangeState.rangeHigh);
   ObjectSetString(0, nameLabel, OBJPROP_TEXT, labelText);
   ObjectSetInteger(0, nameLabel, OBJPROP_COLOR, g_rangeState.isFlatRange ? clrRed : clrOrange);
   ObjectSetInteger(0, nameLabel, OBJPROP_FONTSIZE, 8);
}

// ── Nettoyer les objets de range ─────────────────────────────────────────
void SMC_Range_ClearObjects()
{
   ObjectsDeleteAll(0, "SMC_RANGE_HIGH_");
   ObjectsDeleteAll(0, "SMC_RANGE_LOW_");
   ObjectsDeleteAll(0, "SMC_RANGE_LABEL_");
}

// ── Logique de gate pour les entrées basée sur le range ───────────────────
bool SMC_Range_AllowEntry(const string symbol, const int gomNum)
{
   SMC_Range_Update(symbol, PERIOD_CURRENT);
   
   // Si pas en range, autoriser l'entrée
   if(!g_rangeState.inRange) return true;
   
   // Si en range mais verdict GOM PERFECT (|vn| >= 3), autoriser
   if(MathAbs(gomNum) >= 3) return true;
   
   // Si range plat et compteur atteint, bloquer l'entrée
   if(g_rangeState.isFlatRange && g_rangeState.consecutiveFlatRanges >= InpFlatRangeWaitBars) {
      Print("🚫 ENTRÉE BLOQUÉE - Range plat consécutif (", g_rangeState.consecutiveFlatRanges, ") sur ", symbol);
      return false;
   }
   
   // Si range mais breakout imminent, autoriser
   if(SMC_Range_IsBreakoutImminent(symbol, PERIOD_CURRENT)) {
      Print("⚠️ BREAKOUT IMMINENT - Autorisation d'entrée sur ", symbol);
      return true;
   }
   
   // Sinon, bloquer l'entrée en range
   Print("🚫 ENTRÉE BLOQUÉE - Prix dans range sur ", symbol);
    return false;
}

void SMC_Range_Deinit()
{
   g_rangeState.inRange = false;
   g_rangeState.rangeHigh = 0;
   g_rangeState.rangeLow = 0;
   g_rangeState.rangeMid = 0;
   g_lastRangeCheck = 0;
}

#endif
