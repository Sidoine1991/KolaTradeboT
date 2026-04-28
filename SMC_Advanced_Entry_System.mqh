//+------------------------------------------------------------------+
//| SMC_Advanced_Entry_System.mqh                                    |
//| Système d'entrée avancé basé sur Price Action + Patterns        |
//| Engulfing | Pin Bar | Inside Bar | Harami | Confluence          |
//| Morning Star | Evening Star | 3WS | 3BC | Hanging Man | Inverted Hammer
//| Doji | Marubozu | Kicking | Piercing Line | Dark Cloud Cover | Spinning Top
//| Three Inside Up/Down | Three Outside Up/Down
//+------------------------------------------------------------------+

#ifndef __SMC_ADVANCED_ENTRY_SYSTEM_MQH__
#define __SMC_ADVANCED_ENTRY_SYSTEM_MQH__

//+------------------------------------------------------------------+
//| DÉTECTION DE PATTERNS DE BOUGIES                               |
//+------------------------------------------------------------------+

// Paramètres d'activation des patterns (à définir dans le fichier principal ou utiliser ces valeurs par défaut)
extern bool AdvancedEntryUseEngulfing = true;
extern bool AdvancedEntryUsePinBar = true;
extern bool AdvancedEntryUseInsideBar = true;
extern bool AdvancedEntryUseHarami = true;
extern bool AdvancedEntryUseMorningStar = true;
extern bool AdvancedEntryUseEveningStar = true;
extern bool AdvancedEntryUseThreeWhiteSoldiers = true;
extern bool AdvancedEntryUseThreeBlackCrows = true;
extern bool AdvancedEntryUseHangingMan = true;
extern bool AdvancedEntryUseInvertedHammer = true;
extern bool AdvancedEntryUseDoji = true;
extern bool AdvancedEntryUseMarubozu = true;
extern bool AdvancedEntryUseKicking = true;
extern bool AdvancedEntryUsePiercingLine = true;
extern bool AdvancedEntryUseDarkCloudCover = true;
extern bool AdvancedEntryUseSpinningTop = true;
extern bool AdvancedEntryUseThreeInsideUp = true;
extern bool AdvancedEntryUseThreeInsideDown = true;
extern bool AdvancedEntryUseThreeOutsideUp = true;
extern bool AdvancedEntryUseThreeOutsideDown = true;

// Structure pour un pattern détecté
struct PatternDetection
{
   string patternType;     // "ENGULFING", "PIN_BAR", "INSIDE_BAR", "HARAMI"
   string direction;       // "BUY" ou "SELL"
   double strength;        // 0.0 à 1.0
   int barIndex;          // index de la bougie du pattern
   double patternEntry;   // prix d'entrée suggéré
   double patternSL;      // stop loss suggéré
   double patternTP;      // take profit suggéré
};

//+------------------------------------------------------------------+
//| DETECTION: ENGULFING BULLISH/BEARISH                           |
//+------------------------------------------------------------------+
bool DetectEngulfing(ENUM_TIMEFRAMES tf, int lookback, PatternDetection &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 2, rates);
   if(copied < 3) return false;

   // Engulfing: la bougie actuelle enveloppe complètement la bougie précédente
   double o0 = rates[0].open;   double c0 = rates[0].close;   double h0 = rates[0].high;   double l0 = rates[0].low;
   double o1 = rates[1].open;   double c1 = rates[1].close;   double h1 = rates[1].high;   double l1 = rates[1].low;

   // Bullish Engulfing: bougie 0 up (close > open) + enveloppe bougie 1 down (close < open)
   bool bullishEngulfing = (c0 > o0) && (c1 < o1) && (o0 < c1) && (c0 > o1);
   
   // Bearish Engulfing: bougie 0 down (close < open) + enveloppe bougie 1 up (close > open)
   bool bearishEngulfing = (c0 < o0) && (c1 > o1) && (o0 > c1) && (c0 < o1);

   if(bullishEngulfing)
   {
      patOut.patternType = "ENGULFING";
      patOut.direction = "BUY";
      patOut.strength = 0.8;  // Engulfing fort
      patOut.barIndex = 0;
      patOut.patternEntry = rates[0].close + (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0);
      patOut.patternSL = l0 - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 3.0);
      patOut.patternTP = rates[0].close + (MathAbs(c0 - o0) * 2.0);
      return true;
   }

   if(bearishEngulfing)
   {
      patOut.patternType = "ENGULFING";
      patOut.direction = "SELL";
      patOut.strength = 0.8;
      patOut.barIndex = 0;
      patOut.patternEntry = rates[0].close - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0);
      patOut.patternSL = h0 + (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 3.0);
      patOut.patternTP = rates[0].close - (MathAbs(c0 - o0) * 2.0);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: PIN BAR (Pin Bar / Rejection Wick)                  |
//+------------------------------------------------------------------+
bool DetectPinBar(ENUM_TIMEFRAMES tf, int lookback, PatternDetection &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 2, rates);
   if(copied < 2) return false;

   double o0 = rates[0].open;   double c0 = rates[0].close;   double h0 = rates[0].high;   double l0 = rates[0].low;
   double body0 = MathAbs(c0 - o0);
   double range0 = h0 - l0;

   // Pin Bar = queue longue + corps court + clôture au-dessus (bullish) ou en-dessous (bearish) de la mi-range
   double minBodyRatio = 0.3;  // Corps < 30% de la range
   double minWickRatio = 2.0;  // Queue > 2x le corps

   if(body0 <= 0.0) return false;

   double wickUpper = h0 - MathMax(o0, c0);
   double wickLower = MathMin(o0, c0) - l0;

   // Bullish Pin Bar: queue haute longue + corps petit + clôture en haut
   if(wickUpper > wickLower && wickUpper > (body0 * minWickRatio) && (body0 / range0) < minBodyRatio && c0 > o0)
   {
      patOut.patternType = "PIN_BAR";
      patOut.direction = "BUY";
      patOut.strength = 0.75;
      patOut.barIndex = 0;
      patOut.patternEntry = rates[0].close;
      patOut.patternSL = l0 - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0);
      patOut.patternTP = rates[0].close + (wickUpper * 1.5);
      return true;
   }

   // Bearish Pin Bar: queue basse longue + corps petit + clôture en bas
   if(wickLower > wickUpper && wickLower > (body0 * minWickRatio) && (body0 / range0) < minBodyRatio && c0 < o0)
   {
      patOut.patternType = "PIN_BAR";
      patOut.direction = "SELL";
      patOut.strength = 0.75;
      patOut.barIndex = 0;
      patOut.patternEntry = rates[0].close;
      patOut.patternSL = h0 + (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0);
      patOut.patternTP = rates[0].close - (wickLower * 1.5);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: INSIDE BAR (bougie contenue dans la précédente)     |
//+------------------------------------------------------------------+
bool DetectInsideBar(ENUM_TIMEFRAMES tf, int lookback, PatternDetection &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 2, rates);
   if(copied < 2) return false;

   double h0 = rates[0].high;   double l0 = rates[0].low;
   double h1 = rates[1].high;   double l1 = rates[1].low;
   double o0 = rates[0].open;   double c0 = rates[0].close;

   // Inside Bar: High < High précédent ET Low > Low précédent
   bool isInside = (h0 < h1) && (l0 > l1);

   if(isInside)
   {
      // Direction: dépend de la clôture relative au midpoint
      double midpoint = (h1 + l1) / 2.0;
      
      if(c0 > midpoint)
      {
         // Bullish inside bar
         patOut.patternType = "INSIDE_BAR";
         patOut.direction = "BUY";
         patOut.strength = 0.65;
         patOut.barIndex = 0;
         patOut.patternEntry = h1 + (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0);  // Casse au-dessus
         patOut.patternSL = l0 - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0);
         patOut.patternTP = h1 + ((h1 - l1) * 1.5);
         return true;
      }
      else if(c0 < midpoint)
      {
         // Bearish inside bar
         patOut.patternType = "INSIDE_BAR";
         patOut.direction = "SELL";
         patOut.strength = 0.65;
         patOut.barIndex = 0;
         patOut.patternEntry = l1 - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0);  // Casse en-dessous
         patOut.patternSL = h0 + (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0);
         patOut.patternTP = l1 - ((h1 - l1) * 1.5);
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: HARAMI (petite bougie + grande bougie)               |
//+------------------------------------------------------------------+
bool DetectHarami(ENUM_TIMEFRAMES tf, int lookback, PatternDetection &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 2, rates);
   if(copied < 2) return false;

   double o0 = rates[0].open;   double c0 = rates[0].close;   double h0 = rates[0].high;   double l0 = rates[0].low;
   double o1 = rates[1].open;   double c1 = rates[1].close;   double h1 = rates[1].high;   double l1 = rates[1].low;

   double body0 = MathAbs(c0 - o0);
   double body1 = MathAbs(c1 - o1);

   // Harami: bougie 0 petite (corps small) + corps contenu dans bougie 1
   bool isHarami = (body0 < body1 * 0.5) && (h0 < h1) && (l0 > l1);

   if(isHarami)
   {
      // Bullish Harami: bougie 1 bearish + bougie 0 bullish
      if((c1 < o1) && (c0 > o0))
      {
         patOut.patternType = "HARAMI";
         patOut.direction = "BUY";
         patOut.strength = 0.70;
         patOut.barIndex = 0;
         patOut.patternEntry = rates[0].close;
         patOut.patternSL = l0 - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0);
         patOut.patternTP = rates[0].close + (body1 * 0.8);
         return true;
      }

      // Bearish Harami: bougie 1 bullish + bougie 0 bearish
      if((c1 > o1) && (c0 < o0))
      {
         patOut.patternType = "HARAMI";
         patOut.direction = "SELL";
         patOut.strength = 0.70;
         patOut.barIndex = 0;
         patOut.patternEntry = rates[0].close;
         patOut.patternSL = h0 + (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0);
         patOut.patternTP = rates[0].close - (body1 * 0.8);
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| NOUVEAUX PATTERNS CANDLESTICK                                  |
//+------------------------------------------------------------------+

// Structure pour stocker un pattern détecté (version tableau)
struct CandlestickPattern
{
   string patternType;   // ex: "MORNING_STAR"
   string direction;     // "BUY" ou "SELL"
   double strength;      // 0.0 à 1.0
   int    barIndex;      // index de la bougie (0 = actuelle)
};

//+------------------------------------------------------------------+
//| DETECTION: MORNING STAR (étoile du matin - retournement haussier)|
//+------------------------------------------------------------------+
bool DetectMorningStar(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 3, rates);
   if(copied < 3) return false;

   double o0 = rates[0].open, c0 = rates[0].close, h0 = rates[0].high, l0 = rates[0].low;
   double o1 = rates[1].open, c1 = rates[1].close, h1 = rates[1].high, l1 = rates[1].low;
   double o2 = rates[2].open, c2 = rates[2].close, h2 = rates[2].high, l2 = rates[2].low;

   double body0 = MathAbs(c0 - o0);
   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);
   double range2 = h2 - l2;

   // Bougie 2 bearish (grande)
   bool bigBearish = (c2 < o2) && (body2 > range2 * 0.5);
   // Bougie 1 petite (étoile) - gap down
   bool smallStar = (body1 < body2 * 0.3) && (h1 < o2) && (l1 > c0);
   // Bougie 0 bullish (grande) qui clôture au moins à 50% dans le corps de bougie 2
   bool bigBullish = (c0 > o0) && (c0 > o2 - (o2 - c2) * 0.5);

   if(bigBearish && smallStar && bigBullish)
   {
      patOut.patternType = "MORNING_STAR";
      patOut.direction = "BUY";
      patOut.strength = 0.85;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: EVENING STAR (étoile du soir - retournement baissier)|
//+------------------------------------------------------------------+
bool DetectEveningStar(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 3, rates);
   if(copied < 3) return false;

   double o0 = rates[0].open, c0 = rates[0].close, h0 = rates[0].high, l0 = rates[0].low;
   double o1 = rates[1].open, c1 = rates[1].close, h1 = rates[1].high, l1 = rates[1].low;
   double o2 = rates[2].open, c2 = rates[2].close, h2 = rates[2].high, l2 = rates[2].low;

   double body0 = MathAbs(c0 - o0);
   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);
   double range2 = h2 - l2;

   // Bougie 2 bullish (grande)
   bool bigBullish = (c2 > o2) && (body2 > range2 * 0.5);
   // Bougie 1 petite (étoile) - gap up
   bool smallStar = (body1 < body2 * 0.3) && (l1 > o2) && (h1 < c0);
   // Bougie 0 bearish (grande) qui clôture au moins à 50% dans le corps de bougie 2
   bool bigBearish = (c0 < o0) && (c0 < o2 + (c2 - o2) * 0.5);

   if(bigBullish && smallStar && bigBearish)
   {
      patOut.patternType = "EVENING_STAR";
      patOut.direction = "SELL";
      patOut.strength = 0.85;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: THREE WHITE SOLDIERS (3 soldats blancs)             |
//+------------------------------------------------------------------+
bool DetectThreeWhiteSoldiers(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 3, rates);
   if(copied < 3) return false;

   // 3 bougies bullish consécutives avec clôtures croissantes
   bool b0 = (rates[0].close > rates[0].open);
   bool b1 = (rates[1].close > rates[1].open);
   bool b2 = (rates[2].close > rates[2].open);

   bool ascending = (rates[0].close > rates[1].close) && (rates[1].close > rates[2].close);
   // Chaque bougie s'ouvre dans le corps de la précédente
   bool openInBody0 = (rates[0].open > rates[1].open) && (rates[0].open < rates[1].close);
   bool openInBody1 = (rates[1].open > rates[2].open) && (rates[1].open < rates[2].close);

   if(b0 && b1 && b2 && ascending && openInBody0 && openInBody1)
   {
      patOut.patternType = "THREE_WHITE_SOLDIERS";
      patOut.direction = "BUY";
      patOut.strength = 0.80;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: THREE BLACK CROWS (3 corbeaux noirs)                |
//+------------------------------------------------------------------+
bool DetectThreeBlackCrows(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 3, rates);
   if(copied < 3) return false;

   // 3 bougies bearish consécutives avec clôtures décroissantes
   bool b0 = (rates[0].close < rates[0].open);
   bool b1 = (rates[1].close < rates[1].open);
   bool b2 = (rates[2].close < rates[2].open);

   bool descending = (rates[0].close < rates[1].close) && (rates[1].close < rates[2].close);
   bool openInBody0 = (rates[0].open < rates[1].open) && (rates[0].open > rates[1].close);
   bool openInBody1 = (rates[1].open < rates[2].open) && (rates[1].open > rates[2].close);

   if(b0 && b1 && b2 && descending && openInBody0 && openInBody1)
   {
      patOut.patternType = "THREE_BLACK_CROWS";
      patOut.direction = "SELL";
      patOut.strength = 0.80;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: HANGING MAN (homme pendu - retournement baissier)   |
//+------------------------------------------------------------------+
bool DetectHangingMan(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 2, rates);
   if(copied < 2) return false;

   double o0 = rates[0].open, c0 = rates[0].close, h0 = rates[0].high, l0 = rates[0].low;
   double body = MathAbs(c0 - o0);
   double range = h0 - l0;
   double lowerWick = MathMin(o0, c0) - l0;
   double upperWick = h0 - MathMax(o0, c0);

   // Doit être en uptrend (précédente bougie bullish ou prix haut)
   bool priorUptrend = (rates[1].close > rates[1].open);

   // Corps petit en haut, longue mèche inférieure, pas de mèche supérieure
   bool smallBody = (body < range * 0.3);
   bool longLowerWick = (lowerWick > body * 2.0);
   bool noUpperWick = (upperWick < body * 0.1);

   if(priorUptrend && smallBody && longLowerWick && noUpperWick && c0 > o0)
   {
      patOut.patternType = "HANGING_MAN";
      patOut.direction = "SELL";
      patOut.strength = 0.75;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: INVERTED HAMMER (marteau inversé - retournement haussier)|
//+------------------------------------------------------------------+
bool DetectInvertedHammer(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 2, rates);
   if(copied < 2) return false;

   double o0 = rates[0].open, c0 = rates[0].close, h0 = rates[0].high, l0 = rates[0].low;
   double body = MathAbs(c0 - o0);
   double range = h0 - l0;
   double upperWick = h0 - MathMax(o0, c0);
   double lowerWick = MathMin(o0, c0) - l0;

   // Doit être en downtrend
   bool priorDowntrend = (rates[1].close < rates[1].open);

   // Corps petit en bas, longue mèche supérieure, pas de mèche inférieure
   bool smallBody = (body < range * 0.3);
   bool longUpperWick = (upperWick > body * 2.0);
   bool noLowerWick = (lowerWick < body * 0.1);

   if(priorDowntrend && smallBody && longUpperWick && noLowerWick && c0 > o0)
   {
      patOut.patternType = "INVERTED_HAMMER";
      patOut.direction = "BUY";
      patOut.strength = 0.75;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: DOJI (indécision - corps très petit)                  |
//+------------------------------------------------------------------+
bool DetectDoji(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 1, rates);
   if(copied < 1) return false;

   double o0 = rates[0].open, c0 = rates[0].close, h0 = rates[0].high, l0 = rates[0].low;
   double body = MathAbs(c0 - o0);
   double range = h0 - l0;

   // Doji: corps < 10% du range
   bool isDoji = (body < range * 0.1);

   if(isDoji)
   {
      patOut.patternType = "DOJI";
      patOut.direction = "HOLD";
      patOut.strength = 0.50;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: MARUBOZU (momentum fort - pas de mèches)              |
//+------------------------------------------------------------------+
bool DetectMarubozu(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 1, rates);
   if(copied < 1) return false;

   double o0 = rates[0].open, c0 = rates[0].close, h0 = rates[0].high, l0 = rates[0].low;
   double body = MathAbs(c0 - o0);
   double range = h0 - l0;
   double upperWick = h0 - MathMax(o0, c0);
   double lowerWick = MathMin(o0, c0) - l0;

   // Marubozu: corps > 85% du range, mèches < 5%
   bool isMarubozu = (body > range * 0.85) && (upperWick < range * 0.05) && (lowerWick < range * 0.05);

   if(isMarubozu)
   {
      patOut.patternType = "MARUBOZU";
      patOut.direction = (c0 > o0) ? "BUY" : "SELL";
      patOut.strength = 0.90;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: KICKING (gap fort - spike imminent)                   |
//+------------------------------------------------------------------+
bool DetectKicking(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 2, rates);
   if(copied < 2) return false;

   double o0 = rates[0].open, c0 = rates[0].close, h0 = rates[0].high, l0 = rates[0].low;
   double o1 = rates[1].open, c1 = rates[1].close, h1 = rates[1].high, l1 = rates[1].low;

   double body0 = MathAbs(c0 - o0);
   double body1 = MathAbs(c1 - o1);
   double range1 = h1 - l1;

   // Kicking: gap entre les bougies + corps dans la même direction
   bool bullishKicking = (o0 > h1) && (c0 > o0) && (body0 > range1 * 0.5);
   bool bearishKicking = (o0 < l1) && (c0 < o0) && (body0 > range1 * 0.5);

   if(bullishKicking)
   {
      patOut.patternType = "KICKING";
      patOut.direction = "BUY";
      patOut.strength = 0.95;
      patOut.barIndex = 0;
      return true;
   }
   if(bearishKicking)
   {
      patOut.patternType = "KICKING";
      patOut.direction = "SELL";
      patOut.strength = 0.95;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: PIERCING LINE (retournement haussier)                 |
//+------------------------------------------------------------------+
bool DetectPiercingLine(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 2, rates);
   if(copied < 2) return false;

   double o0 = rates[0].open, c0 = rates[0].close, h0 = rates[0].high, l0 = rates[0].low;
   double o1 = rates[1].open, c1 = rates[1].close, h1 = rates[1].high, l1 = rates[1].low;

   double body0 = MathAbs(c0 - o0);
   double body1 = MathAbs(c1 - o1);
   double range1 = h1 - l1;

   // Bougie 1 bearish (grande)
   bool bigBearish = (c1 < o1) && (body1 > range1 * 0.5);
   // Bougie 0 bullish qui ouvre sous le minimum de bougie 1 et clôture > 50% du corps de bougie 1
   bool piercing = (c0 > o0) && (o0 < l1) && (c0 > o1 - (o1 - c1) * 0.5);

   if(bigBearish && piercing)
   {
      patOut.patternType = "PIERCING_LINE";
      patOut.direction = "BUY";
      patOut.strength = 0.75;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: DARK CLOUD COVER (retournement baissier)              |
//+------------------------------------------------------------------+
bool DetectDarkCloudCover(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 2, rates);
   if(copied < 2) return false;

   double o0 = rates[0].open, c0 = rates[0].close, h0 = rates[0].high, l0 = rates[0].low;
   double o1 = rates[1].open, c1 = rates[1].close, h1 = rates[1].high, l1 = rates[1].low;

   double body0 = MathAbs(c0 - o0);
   double body1 = MathAbs(c1 - o1);
   double range1 = h1 - l1;

   // Bougie 1 bullish (grande)
   bool bigBullish = (c1 > o1) && (body1 > range1 * 0.5);
   // Bougie 0 bearish qui ouvre au-dessus du maximum de bougie 1 et clôture < 50% du corps de bougie 1
   bool darkCloud = (c0 < o0) && (o0 > h1) && (c0 < o1 + (c1 - o1) * 0.5);

   if(bigBullish && darkCloud)
   {
      patOut.patternType = "DARK_CLOUD_COVER";
      patOut.direction = "SELL";
      patOut.strength = 0.75;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: SPINNING TOP (compression - corps petit, mèches longues)|
//+------------------------------------------------------------------+
bool DetectSpinningTop(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 1, rates);
   if(copied < 1) return false;

   double o0 = rates[0].open, c0 = rates[0].close, h0 = rates[0].high, l0 = rates[0].low;
   double body = MathAbs(c0 - o0);
   double range = h0 - l0;
   double upperWick = h0 - MathMax(o0, c0);
   double lowerWick = MathMin(o0, c0) - l0;

   // Spinning Top: corps < 30% du range, mèches > corps
   bool isSpinningTop = (body < range * 0.3) && (upperWick > body) && (lowerWick > body);

   if(isSpinningTop)
   {
      patOut.patternType = "SPINNING_TOP";
      patOut.direction = "HOLD";
      patOut.strength = 0.40;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: THREE INSIDE UP (confirmation Harami haussier)        |
//+------------------------------------------------------------------+
bool DetectThreeInsideUp(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 3, rates);
   if(copied < 3) return false;

   double o0 = rates[0].open, c0 = rates[0].close;
   double o1 = rates[1].open, c1 = rates[1].close, h1 = rates[1].high, l1 = rates[1].low;
   double o2 = rates[2].open, c2 = rates[2].close, h2 = rates[2].high, l2 = rates[2].low;

   double body0 = MathAbs(c0 - o0);
   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);

   // Bougie 2 bearish (grande)
   bool bigBearish = (c2 < o2) && (body2 > (h2 - l2) * 0.5);
   // Bougie 1 Harami (petite corps contenu dans bougie 2)
   bool harami = (body1 < body2 * 0.5) && (h1 < h2) && (l1 > l2);
   // Bougie 0 bullish qui clôture au-dessus du maximum de bougie 1
   bool confirmBullish = (c0 > o0) && (c0 > h1);

   if(bigBearish && harami && confirmBullish)
   {
      patOut.patternType = "THREE_INSIDE_UP";
      patOut.direction = "BUY";
      patOut.strength = 0.80;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: THREE INSIDE DOWN (confirmation Harami baissier)       |
//+------------------------------------------------------------------+
bool DetectThreeInsideDown(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 3, rates);
   if(copied < 3) return false;

   double o0 = rates[0].open, c0 = rates[0].close;
   double o1 = rates[1].open, c1 = rates[1].close, h1 = rates[1].high, l1 = rates[1].low;
   double o2 = rates[2].open, c2 = rates[2].close, h2 = rates[2].high, l2 = rates[2].low;

   double body0 = MathAbs(c0 - o0);
   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);

   // Bougie 2 bullish (grande)
   bool bigBullish = (c2 > o2) && (body2 > (h2 - l2) * 0.5);
   // Bougie 1 Harami (petite corps contenu dans bougie 2)
   bool harami = (body1 < body2 * 0.5) && (h1 < h2) && (l1 > l2);
   // Bougie 0 bearish qui clôture sous le minimum de bougie 1
   bool confirmBearish = (c0 < o0) && (c0 < l1);

   if(bigBullish && harami && confirmBearish)
   {
      patOut.patternType = "THREE_INSIDE_DOWN";
      patOut.direction = "SELL";
      patOut.strength = 0.80;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: THREE OUTSIDE UP (confirmation Engulfing haussier)     |
//+------------------------------------------------------------------+
bool DetectThreeOutsideUp(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 3, rates);
   if(copied < 3) return false;

   double o0 = rates[0].open, c0 = rates[0].close;
   double o1 = rates[1].open, c1 = rates[1].close, h1 = rates[1].high, l1 = rates[1].low;
   double o2 = rates[2].open, c2 = rates[2].close, h2 = rates[2].high, l2 = rates[2].low;

   double body0 = MathAbs(c0 - o0);
   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);

   // Bougie 2 bearish
   bool bearish2 = (c2 < o2);
   // Bougie 1 Bullish Engulfing (englobe bougie 2)
   bool bullishEngulfing = (c1 > o1) && (h1 > h2) && (l1 < l2) && (body1 > body2);
   // Bougie 0 bullish qui clôture au-dessus du maximum de bougie 1
   bool confirmBullish = (c0 > o0) && (c0 > h1);

   if(bearish2 && bullishEngulfing && confirmBullish)
   {
      patOut.patternType = "THREE_OUTSIDE_UP";
      patOut.direction = "BUY";
      patOut.strength = 0.85;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION: THREE OUTSIDE DOWN (confirmation Engulfing baissier)   |
//+------------------------------------------------------------------+
bool DetectThreeOutsideDown(ENUM_TIMEFRAMES tf, int lookback, CandlestickPattern &patOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, lookback + 3, rates);
   if(copied < 3) return false;

   double o0 = rates[0].open, c0 = rates[0].close;
   double o1 = rates[1].open, c1 = rates[1].close, h1 = rates[1].high, l1 = rates[1].low;
   double o2 = rates[2].open, c2 = rates[2].close, h2 = rates[2].high, l2 = rates[2].low;

   double body0 = MathAbs(c0 - o0);
   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);

   // Bougie 2 bullish
   bool bullish2 = (c2 > o2);
   // Bougie 1 Bearish Engulfing (englobe bougie 2)
   bool bearishEngulfing = (c1 < o1) && (h1 > h2) && (l1 < l2) && (body1 > body2);
   // Bougie 0 bearish qui clôture sous le minimum de bougie 1
   bool confirmBearish = (c0 < o0) && (c0 < l1);

   if(bullish2 && bearishEngulfing && confirmBearish)
   {
      patOut.patternType = "THREE_OUTSIDE_DOWN";
      patOut.direction = "SELL";
      patOut.strength = 0.85;
      patOut.barIndex = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DETECTION UNIFIÉE: TOUS LES PATTERNS CANDLESTICK               |
//+------------------------------------------------------------------+

struct CandlestickPatternSet
{
   CandlestickPattern patterns[30];
   int patternCount;
   string dominantDirection;
   double dominantConfidence;
};

void DetectAllCandlestickPatterns(ENUM_TIMEFRAMES tf, int lookback, CandlestickPatternSet &setOut)
{
   setOut.patternCount = 0;
   setOut.dominantDirection = "HOLD";
   setOut.dominantConfidence = 0.0;

   CandlestickPattern pat;

   // Patterns existants (adaptés à CandlestickPattern)
   PatternDetection legacyPat;
   if(AdvancedEntryUseEngulfing && DetectEngulfing(tf, lookback, legacyPat))
   {
      pat.patternType = legacyPat.patternType;
      pat.direction = legacyPat.direction;
      pat.strength = legacyPat.strength;
      pat.barIndex = legacyPat.barIndex;
      setOut.patterns[setOut.patternCount++] = pat;
   }
   if(AdvancedEntryUsePinBar && DetectPinBar(tf, lookback, legacyPat))
   {
      pat.patternType = legacyPat.patternType;
      pat.direction = legacyPat.direction;
      pat.strength = legacyPat.strength;
      pat.barIndex = legacyPat.barIndex;
      setOut.patterns[setOut.patternCount++] = pat;
   }
   if(AdvancedEntryUseInsideBar && DetectInsideBar(tf, lookback, legacyPat))
   {
      pat.patternType = legacyPat.patternType;
      pat.direction = legacyPat.direction;
      pat.strength = legacyPat.strength;
      pat.barIndex = legacyPat.barIndex;
      setOut.patterns[setOut.patternCount++] = pat;
   }
   if(AdvancedEntryUseHarami && DetectHarami(tf, lookback, legacyPat))
   {
      pat.patternType = legacyPat.patternType;
      pat.direction = legacyPat.direction;
      pat.strength = legacyPat.strength;
      pat.barIndex = legacyPat.barIndex;
      setOut.patterns[setOut.patternCount++] = pat;
   }

   // Nouveaux patterns
   if(AdvancedEntryUseMorningStar && DetectMorningStar(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseEveningStar && DetectEveningStar(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseThreeWhiteSoldiers && DetectThreeWhiteSoldiers(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseThreeBlackCrows && DetectThreeBlackCrows(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseHangingMan && DetectHangingMan(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseInvertedHammer && DetectInvertedHammer(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;

   // Nouveaux patterns supplémentaires
   if(AdvancedEntryUseDoji && DetectDoji(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseMarubozu && DetectMarubozu(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseKicking && DetectKicking(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUsePiercingLine && DetectPiercingLine(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseDarkCloudCover && DetectDarkCloudCover(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseSpinningTop && DetectSpinningTop(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseThreeInsideUp && DetectThreeInsideUp(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseThreeInsideDown && DetectThreeInsideDown(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseThreeOutsideUp && DetectThreeOutsideUp(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
   if(AdvancedEntryUseThreeOutsideDown && DetectThreeOutsideDown(tf, lookback, pat))
      setOut.patterns[setOut.patternCount++] = pat;
}

//+------------------------------------------------------------------+
//| PRÉDICTION DE DIRECTION À PARTIR DES PATTERNS                  |
//+------------------------------------------------------------------+

struct CandlestickPrediction
{
   string direction;        // "BUY", "SELL", "HOLD"
   double confidence;       // 0.0 à 100.0
   string dominantPattern;  // Nom du pattern dominant
   int    patternCount;     // Nombre de patterns détectés
   datetime predictionTime; // Timestamp
};

// Variable globale pour la dernière prédiction (utilisée par SMC_Universal.mq5)
CandlestickPrediction g_lastCandlestickPrediction;

void PredictPriceDirectionFromPatterns(ENUM_TIMEFRAMES tf, int lookback, CandlestickPrediction &predOut)
{
   CandlestickPatternSet set;
   DetectAllCandlestickPatterns(tf, lookback, set);

   predOut.direction = "HOLD";
   predOut.confidence = 0.0;
   predOut.dominantPattern = "NONE";
   predOut.patternCount = set.patternCount;
   predOut.predictionTime = TimeCurrent();

   if(set.patternCount == 0)
      return;

   double buyScore = 0.0;
   double sellScore = 0.0;
   string dominantPat = "";
   double maxStrength = 0.0;

   for(int i = 0; i < set.patternCount; i++)
   {
      double w = set.patterns[i].strength;
      if(set.patterns[i].direction == "BUY")
      {
         buyScore += w;
         if(w > maxStrength)
         {
            maxStrength = w;
            dominantPat = set.patterns[i].patternType;
         }
      }
      else if(set.patterns[i].direction == "SELL")
      {
         sellScore += w;
         if(w > maxStrength)
         {
            maxStrength = w;
            dominantPat = set.patterns[i].patternType;
         }
      }
   }

   // Déterminer la direction dominante
   if(buyScore > sellScore && buyScore >= 0.5)
   {
      predOut.direction = "BUY";
      predOut.confidence = MathMin(100.0, buyScore * 100.0);
      predOut.dominantPattern = dominantPat;
   }
   else if(sellScore > buyScore && sellScore >= 0.5)
   {
      predOut.direction = "SELL";
      predOut.confidence = MathMin(100.0, sellScore * 100.0);
      predOut.dominantPattern = dominantPat;
   }
   else if(buyScore >= 0.3 || sellScore >= 0.3)
   {
      // Direction faible mais présente
      predOut.direction = (buyScore > sellScore) ? "BUY" : "SELL";
      predOut.confidence = MathMin(100.0, MathMax(buyScore, sellScore) * 80.0);
      predOut.dominantPattern = dominantPat;
   }

   // Stocker dans la variable globale
   g_lastCandlestickPrediction = predOut;
}

//+------------------------------------------------------------------+
//| CONFLUENCE ANALYSIS - Multi-Element Support Score              |
//+------------------------------------------------------------------+

struct ConfluenceAnalysis
{
   double supportResistanceScore;    // 0-1: force des niveaux S/R
   double fvgObScore;                 // 0-1: présence d'imbalances
   double liquidityScore;             // 0-1: niveaux de swing confirmés
   double multiTimeframeScore;        // 0-1: confluence M1+M5+H1
   double totalConfluenceScore;       // 0-1: score global
};

//+------------------------------------------------------------------+
//| Analyser la confluence pour une direction                      |
//+------------------------------------------------------------------+
bool AnalyzeConfluence(const string direction, ConfluenceAnalysis &confOut)
{
   confOut.supportResistanceScore = 0.0;
   confOut.fvgObScore = 0.0;
   confOut.liquidityScore = 0.0;
   confOut.multiTimeframeScore = 0.0;
   confOut.totalConfluenceScore = 0.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = ask - bid;

   // 1. Support/Resistance Analysis (M5)
   confOut.supportResistanceScore = AnalyzeSupportResistanceScore(direction);

   // 2. FVG/OB Analysis (Fair Value Gap / Order Block)
   confOut.fvgObScore = AnalyzeFVGAndOBScore(direction);

   // 3. Liquidity Zones (Swing Points)
   confOut.liquidityScore = AnalyzeLiquidityZonesScore(direction);

   // 4. Multi-Timeframe Confluence
   confOut.multiTimeframeScore = AnalyzeMultiTimeframeScore(direction);

   // Score total = moyenne pondérée
   confOut.totalConfluenceScore = (confOut.supportResistanceScore * 0.35 +
                                   confOut.fvgObScore * 0.25 +
                                   confOut.liquidityScore * 0.20 +
                                   confOut.multiTimeframeScore * 0.20);

   return true;
}

//+------------------------------------------------------------------+
//| Support/Resistance Score                                        |
//+------------------------------------------------------------------+
double AnalyzeSupportResistanceScore(const string direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, 50, rates);
   if(copied < 20) return 0.0;

   double currentPrice = rates[0].close;
   double score = 0.0;

   if(direction == "BUY")
   {
      // Chercher un support solide en-dessous du prix actuel
      double support = GetSupportLevel(rates, 20);
      if(support > 0.0)
      {
         double distance = currentPrice - support;
         double atr = GetATRForTimeframe(_Symbol, PERIOD_M5, 0);
         
         // Support proche (< 1.5 ATR) = meilleur score
         if(distance < atr * 1.5)
            score = 0.9;  // Support fort et proche
         else if(distance < atr * 3.0)
            score = 0.6;  // Support modéré
         else
            score = 0.3;  // Support éloigné
      }
   }
   else if(direction == "SELL")
   {
      // Chercher une résistance solide au-dessus du prix actuel
      double resistance = GetResistanceLevel(rates, 20);
      if(resistance > 0.0)
      {
         double distance = resistance - currentPrice;
         double atr = GetATRForTimeframe(_Symbol, PERIOD_M5, 0);
         
         if(distance < atr * 1.5)
            score = 0.9;  // Résistance forte et proche
         else if(distance < atr * 3.0)
            score = 0.6;  // Résistance modérée
         else
            score = 0.3;  // Résistance éloignée
      }
   }

   return score;
}

//+------------------------------------------------------------------+
//| FVG/OB Score (Fair Value Gap / Order Block)                    |
//+------------------------------------------------------------------+
double AnalyzeFVGAndOBScore(const string direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M1, 0, 30, rates);
   if(copied < 5) return 0.0;

   // Chercher les imbalances (Fair Value Gaps)
   // Imbalance UP: High[i] < Low[i+2]
   // Imbalance DOWN: Low[i] > High[i+2]

   double score = 0.0;
   double currentPrice = rates[0].close;

   for(int i = 1; i < MathMin(15, copied - 2); i++)
   {
      // Imbalance UP (liquidity vacuum)
      if(rates[i].high < rates[i-1].low && currentPrice > rates[i].high && currentPrice < rates[i-1].low)
      {
         if(direction == "BUY")
            score = MathMax(score, 0.7);  // FVG acheté
      }

      // Imbalance DOWN (liquidity vacuum)
      if(rates[i].low > rates[i-1].high && currentPrice < rates[i].low && currentPrice > rates[i-1].high)
      {
         if(direction == "SELL")
            score = MathMax(score, 0.7);  // FVG vendu
      }
   }

   return score;
}

//+------------------------------------------------------------------+
//| Liquidity Zones Score (Swing Points)                           |
//+------------------------------------------------------------------+
double AnalyzeLiquidityZonesScore(const string direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, 40, rates);
   if(copied < 15) return 0.0;

   double currentPrice = rates[0].close;
   double score = 0.0;

   if(direction == "BUY")
   {
      for(int i = 10; i < 30; i++)
      {
         if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
         {
            double distance = currentPrice - rates[i].low;
            if(distance > 0 && distance < (GetATRForTimeframe(_Symbol, PERIOD_M5, 0) * 2.0))
               score = MathMax(score, 0.75);
         }
      }
   }
   else if(direction == "SELL")
   {
      for(int i = 10; i < 30; i++)
      {
         if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
         {
            double distance = rates[i].high - currentPrice;
            if(distance > 0 && distance < (GetATRForTimeframe(_Symbol, PERIOD_M5, 0) * 2.0))
               score = MathMax(score, 0.75);
         }
      }
   }

   return score;
}

double AnalyzeMultiTimeframeScore(const string direction)
{
   double scoreM1 = GetTrendScore(PERIOD_M1, direction);
   double scoreM5 = GetTrendScore(PERIOD_M5, direction);
   double scoreH1 = GetTrendScore(PERIOD_H1, direction);

   int alignedCount = 0;
   if(scoreM1 >= 0.6) alignedCount++;
   if(scoreM5 >= 0.6) alignedCount++;
   if(scoreH1 >= 0.6) alignedCount++;

   if(alignedCount == 3) return 0.9;
   else if(alignedCount == 2) return 0.7;
   else if(alignedCount == 1) return 0.4;
   else return 0.2;
}

double GetSupportLevel(MqlRates &rates[], int bars)
{
   double support = 0.0;
   for(int i = 1; i < bars; i++)
   {
      if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
         support = MathMax(support, rates[i].low);
   }
   return support;
}

double GetResistanceLevel(MqlRates &rates[], int bars)
{
   double resistance = 0.0;
   for(int i = 1; i < bars; i++)
   {
      if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
         resistance = MathMax(resistance, rates[i].high);
   }
   return resistance;
}

double GetATRForTimeframe(const string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, shift, 15, rates) < 14) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < 14; i++) sum += (rates[i].high - rates[i].low);
   return sum / 14.0;
}

double GetTrendScore(ENUM_TIMEFRAMES tf, const string direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, tf, 0, 20, rates) < 10) return 0.5;
   double close = rates[0].close;
   double ema13 = CalculateEMA(_Symbol, tf, 13, 0);
   double ema21 = CalculateEMA(_Symbol, tf, 21, 0);
   if(direction == "BUY")
   {
      if(close > ema13 && ema13 > ema21) return 0.85;
      else if(close > ema13 || ema13 > ema21) return 0.65;
      else return 0.35;
   }
   else if(direction == "SELL")
   {
      if(close < ema13 && ema13 < ema21) return 0.85;
      else if(close < ema13 || ema13 < ema21) return 0.65;
      else return 0.35;
   }
   return 0.5;
}

double CalculateEMA(const string symbol, ENUM_TIMEFRAMES tf, int period, int shift)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, shift, period + 1, rates) < period) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < period; i++) sum += rates[i].close;
   return sum / period;
}

struct SetupScore
{
   double patternScore;
   double confluenceScore;
   double totalScore;
   bool isValid;
};

bool CalculateCompleteSetupScore(const string direction, SetupScore &scoreOut)
{
   scoreOut.patternScore = 0.0;
   scoreOut.confluenceScore = 0.0;
   scoreOut.totalScore = 0.0;
   scoreOut.isValid = false;
   PatternDetection pattern;
   bool foundPattern = false;

   if(AdvancedEntryUseEngulfing && DetectEngulfing(PERIOD_M1, 50, pattern))
      foundPattern = true;
   else if(AdvancedEntryUsePinBar && DetectPinBar(PERIOD_M1, 50, pattern))
      foundPattern = true;
   else if(AdvancedEntryUseInsideBar && DetectInsideBar(PERIOD_M1, 50, pattern))
      foundPattern = true;
   else if(AdvancedEntryUseHarami && DetectHarami(PERIOD_M1, 50, pattern))
      foundPattern = true;

   if(!foundPattern) return false;
   if(pattern.direction != direction) return false;

   scoreOut.patternScore = pattern.strength * 100.0;

   if(AdvancedEntryRequireMultiTimeframeConfluence)
   {
      ConfluenceAnalysis confluence;
      AnalyzeConfluence(direction, confluence);
      scoreOut.confluenceScore = confluence.totalConfluenceScore * 100.0;
   }
   else scoreOut.confluenceScore = 50.0;

   scoreOut.totalScore = (scoreOut.patternScore * 0.60) + (scoreOut.confluenceScore * 0.40);
   scoreOut.isValid = (scoreOut.totalScore >= AdvancedEntryMinimumScorePercent);
   return true;
}

//+------------------------------------------------------------------+
//| Niveaux d'entrée pour Advanced PA (marché courant)              |
//+------------------------------------------------------------------+
bool DetermineAdvancedEntryLevels(const string direction,
                                 double &entryOut, double &slOut, double &tpOut, string &reasonOut)
{
   entryOut = 0.0;
   slOut = 0.0;
   tpOut = 0.0;
   reasonOut = "";

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 3, r) < 1)
      return false;
   double currentClose = r[0].close;
   if(currentClose <= 0.0) return false;

   double atr = GetATRForTimeframe(_Symbol, PERIOD_M1, 0);
   if(atr <= 0.0) atr = MathMax(MathAbs(r[0].high - r[0].low), SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20.0);
   if(atr <= 0.0) return false;

   double slDistance = atr * AdvancedEntryStopLossMultiplier;
   double tpDistance = atr * AdvancedEntryTakeProfitMultiplier;

   if(direction == "BUY")
   {
      entryOut = currentClose;
      slOut = currentClose - slDistance;
      tpOut = currentClose + tpDistance;
      reasonOut = "ADV_PA_BUY";
   }
   else if(direction == "SELL")
   {
      entryOut = currentClose;
      slOut = currentClose + slDistance;
      tpOut = currentClose - tpDistance;
      reasonOut = "ADV_PA_SELL";
   }
   else
      return false;

   return true;
}

#endif // __SMC_ADVANCED_ENTRY_SYSTEM_MQH__
