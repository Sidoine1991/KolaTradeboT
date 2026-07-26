//+------------------------------------------------------------------+
//| SMC_DowTrendline.mqh — Trendline Dow + Limit Orders              |
//| Détecte les lower highs (Crash/Painx) ou higher lows (Boom/Gainx)|
//| Trace la trendline de Dow, projette le prochain touch, place     |
//| un ordre LIMIT au niveau projeté.                                |
//+------------------------------------------------------------------+
#ifndef SMC_DOWTRENDLINE_MQH
#define SMC_DOWTRENDLINE_MQH

#include "SMC_SignalGates.mqh"

//--- Inputs (1 seul input — le reste hardcodé pour économiser les slots) ---
input bool UseDowTrendline = true;  // Activer trendline Dow + LIMIT orders

//--- Paramètres internes (hardcoded) ---
#define DOW_SWING_LOOKBACK      3     // Bougies avant/après pour valider un swing
#define DOW_MIN_SWINGS          2     // Nombre minimum de swings (2 sommets/creux suffisent)
#define DOW_MAX_SWINGS          6     // Nombre maximum de swings à analyser
#define DOW_SL_ATRMULT          2.0   // SL = ATR x ce multiplicateur
#define DOW_TP_ATRMULT          4.0   // TP = ATR x ce multiplicateur
#define DOW_PROJ_BARS_AHEAD     8     // Ancien — remplacé par touch projection
#define DOW_TOUCH_M1_AHEAD      4     // Placer LIMIT N bougies M1 AVANT le touché exact (sniper)
#define DOW_SNIPER_PRICE_OFFSET_ATR 0.18 // Écart prix vs intersection trendline (x ATR) — déclenche avant le touché
#define DOW_TOUCH_MAX_LOOKAHEAD 100   // Max bougies M1 à scruter pour trouver le touché
#define DOW_TL_EXTEND_BARS      1000  // Étendre la trendline visuelle N barres dans le futur
#define DOW_TRENDLINE_COLOR     clrGold
#define DOW_TRENDLINE_WIDTH     2
#define DOW_SWING_TOL_PCT       0.0005  // 0.05% tolérance pour swings quasi-égaux
#define DOW_PROJ_COLOR          clrOrangeRed
#define DOW_LIMIT_OFFSET_PTS    2     // Points d'offset pour le prix limite
#define DOW_ENTRY_MAX_ATR       2.0   // Entrée max = ATR x ce multiplicateur au-dessus/dessous du swing
#define DOW_MTF_SWING_LOOKBACK  5     // Bougies avant/après pour swings M5/H1
#define DOW_MTF_MIN_SWINGS      3     // Swings minimum pour valider un canal MTF

//--- Chase EMA : si LIMIT DOW jamais touché en haute vol → rebaser sur EMA fast ---
#define DOW_STALE_SEC           300   // Âge min avant suppression (5 min)
#define DOW_STALE_ATR           1.2   // Distance min prix↔LIMIT (x ATR) pour stale
#define DOW_EMA_FAST_PERIOD     8     // EMA fast M1
#define DOW_CHASE_OFFSET_ATR    0.15  // Offset LIMIT vs EMA (x ATR)
#define DOW_CHASE_REFRESH_SEC   15    // Intervalle min entre re-modifications chase
#define DOW_CHASE_MIN_MOVE_PTS  2     // Ignore modify si delta < N points

//--- Refresh après cassure ---
#define DOW_BREAK_REFRESH_CANDLES 10    // Bougies après cassure → refresh trendline
#define DOW_BREAK_CHECK_BARS      5     // Barres M1 à gauche/droite pour confirmer cassure

//--- Structure pour un point swing ---
struct DowSwingPoint
{
   datetime time;
   double   price;
   bool     isHigh;  // true = swing high, false = swing low
};

//--- État interne ---
struct DowTrendlineState
{
   bool     active;          // Trendline valide détectée
   bool     isBearish;       // true = bearish (lower highs), false = bullish (higher lows)
   datetime startTime;       // Temps du 1er point
   double   startPrice;      // Prix du 1er point
   datetime endTime;         // Temps du dernier point
   double   endPrice;        // Prix du dernier point
   double   slope;           // Pente (price per second)
   double   projectedPrice;  // Prix projeté au prochain touch
   datetime projectedTime;   // Temps projeté
   double   currentATR;      // ATR courant pour SL/TP
    // Chase EMA (LIMIT DOW non touché)
    datetime limitPlacedAt;   // Timestamp placement / dernier reset
    datetime lastChaseAt;     // Dernier modify chase
    datetime limitRemovedAt;  // Timestamp dernière suppression (anti place/delete)
    bool     chasingEma;      // true = LIMIT rebasé sur EMA fast
     ulong    limitTicket;     // Ticket LIMIT suivi
    // Gestion cassure + refresh
    bool     broken;           // true = trendline cassée
    int      candlesSinceBreak;// Nb bougies depuis la cassure
    datetime lastBreakTime;    // Timestamp de la cassure
    datetime lastRefreshTime;  // Dernier refresh trendline
};

DowTrendlineState g_dowState;

//+------------------------------------------------------------------+
//| Trie les swings du plus récent au plus ancien                    |
//+------------------------------------------------------------------+
void Dow_SortSwingsByTimeDesc(DowSwingPoint &swings[], int count)
{
   for(int i = 0; i < count - 1; i++)
      for(int j = i + 1; j < count; j++)
         if(swings[i].time < swings[j].time)
         {
            DowSwingPoint tmp = swings[i];
            swings[i] = swings[j];
            swings[j] = tmp;
         }
}

//+------------------------------------------------------------------+
//| Valide une série de lower highs (canal baissier Dow)             |
//+------------------------------------------------------------------+
bool Dow_ValidateLowerHighs(DowSwingPoint &highs[], int count, bool isCrashLike = false)
{
   if(count < DOW_MIN_SWINGS) return false;
   // Crash/PainX: tolérance élargie (0.2%) car spikes naturels cassent les lower highs strictes
   double tol = isCrashLike ? 0.002 : DOW_SWING_TOL_PCT;
   int check = MathMin(count, DOW_MAX_SWINGS);
   for(int i = 0; i < check - 1; i++)
   {
      if(highs[i].price > highs[i + 1].price * (1.0 + tol))
      {
         Print("[DOW] LowerHigh FAIL: swing[", i, "]=", DoubleToString(highs[i].price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
               " > swing[", i+1, "]=", DoubleToString(highs[i+1].price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
               " tol=", DoubleToString(tol*100, 2), "%");
         return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Valide une série de higher lows (canal haussier Dow)             |
//+------------------------------------------------------------------+
bool Dow_ValidateHigherLows(DowSwingPoint &lows[], int count, bool isBoomLike = false)
{
   if(count < DOW_MIN_SWINGS) return false;
   // Boom/GainX: tolérance élargie (0.2%) car spikes naturels cassent les higher lows strictes
   double tol = isBoomLike ? 0.002 : DOW_SWING_TOL_PCT;
   int check = MathMin(count, DOW_MAX_SWINGS);
   for(int i = 0; i < check - 1; i++)
   {
      if(lows[i].price < lows[i + 1].price * (1.0 - tol))
      {
         Print("[DOW] HigherLow FAIL: swing[", i, "]=", DoubleToString(lows[i].price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
               " < swing[", i+1, "]=", DoubleToString(lows[i+1].price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
               " tol=", DoubleToString(tol*100, 2), "%");
         return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Mode DOW-only : seuls les LIMIT sur trendline DOW sont autorisés  |
//+------------------------------------------------------------------+
bool Dow_IsDowOnlyLimitMode()
{
   if(!UseDowTrendline) return false;
   string symUpper = _Symbol;
   StringToUpper(symUpper);
   return (StringFind(symUpper, "BOOM") >= 0 || StringFind(symUpper, "CRASH") >= 0 ||
           StringFind(symUpper, "PAINX") >= 0 || StringFind(symUpper, "GAINX") >= 0);
}

//+------------------------------------------------------------------+
//| Supprime tous les ordres LIMIT non-DOW (évite le place/delete)    |
//+------------------------------------------------------------------+
void Dow_PurgeNonDowLimitOrders()
{
   if(!Dow_IsDowOnlyLimitMode()) return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, "DOW") >= 0) continue;

      if(LimitSafeOrderDelete(ticket, false, "DOW purge non-DOW " + cmt))
         Print("[DOW] LIMIT non-DOW supprimé: ", cmt, " ticket=", ticket);
   }
}

//+------------------------------------------------------------------+
//| Compte les ordres LIMIT DOW déjà placés sur le symbole           |
//+------------------------------------------------------------------+
int Dow_CountLimitOrders(const string symbol)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, "DOW") >= 0)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Scan les swing highs et lows sur les N dernières bougies M1     |
//+------------------------------------------------------------------+
bool Dow_ScanSwingPoints(const string symbol, DowSwingPoint &swings[], int &count)
{
   count = 0;
   MqlRates rates[];
   int barsNeeded = 200;  // 200 barres M1 (~3.3h) pour trouver assez de swings
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(symbol, PERIOD_M1, 0, barsNeeded, rates);
   if(copied < barsNeeded) return false;

   int maxSwings = DOW_MAX_SWINGS * 2; // On cherche les deux types
   ArrayResize(swings, maxSwings);

   for(int i = DOW_SWING_LOOKBACK; i < copied - DOW_SWING_LOOKBACK && count < maxSwings; i++)
   {
      // Swing High
      bool isHigh = true;
      for(int j = i - DOW_SWING_LOOKBACK; j <= i + DOW_SWING_LOOKBACK; j++)
      {
         if(j != i && rates[j].high >= rates[i].high)
         { isHigh = false; break; }
      }
      if(isHigh && count < maxSwings)
      {
         swings[count].time  = rates[i].time;
         swings[count].price = rates[i].high;
         swings[count].isHigh = true;
         count++;
      }

      // Swing Low
      bool isLow = true;
      for(int j = i - DOW_SWING_LOOKBACK; j <= i + DOW_SWING_LOOKBACK; j++)
      {
         if(j != i && rates[j].low <= rates[i].low)
         { isLow = false; break; }
      }
      if(isLow && count < maxSwings)
      {
         swings[count].time  = rates[i].time;
         swings[count].price = rates[i].low;
         swings[count].isHigh = false;
         count++;
      }
   }
   return (count >= 2);
}

//+------------------------------------------------------------------+
//| Identifie la tendance Dow: lower highs ou higher lows            |
//| Retourne true si une tendance est détectée                       |
//+------------------------------------------------------------------+
bool Dow_DetectTrend(const string symbol, bool &isBearishOut, DowSwingPoint &selected[], int &selectedCount)
{
   DowSwingPoint allSwings[];
   int totalCount = 0;
   if(!Dow_ScanSwingPoints(symbol, allSwings, totalCount)) return false;

   // Séparer high et low
   DowSwingPoint highs[], lows[];
   int highCount = 0, lowCount = 0;
   ArrayResize(highs, totalCount);
   ArrayResize(lows, totalCount);

   for(int i = 0; i < totalCount; i++)
   {
      if(allSwings[i].isHigh)
      { highs[highCount] = allSwings[i]; highCount++; }
      else
      { lows[lowCount] = allSwings[i]; lowCount++; }
   }

   ArrayResize(highs, highCount);
   ArrayResize(lows, lowCount);
   Dow_SortSwingsByTimeDesc(highs, highCount);
   Dow_SortSwingsByTimeDesc(lows, lowCount);

   // Boom/GainX = canal haussier (higher lows) | Crash/PainX = canal baissier (lower highs)
   bool preferBull = IsBoomLikeSymbol(symbol);
   bool preferBear = IsCrashLikeSymbol(symbol);

   bool bearishOk = Dow_ValidateLowerHighs(highs, highCount, preferBear);
   bool bullishOk = Dow_ValidateHigherLows(lows, lowCount, preferBull);

   Print("[DOW] DetectTrend ", symbol, " | swings=", totalCount, " highs=", highCount, " lows=", lowCount,
         " bearishOk=", bearishOk, " bullishOk=", bullishOk,
         " preferBull=", preferBull, " preferBear=", preferBear);

   if(preferBull && bullishOk)
   {
      isBearishOut = false;
      selectedCount = MathMin(lowCount, DOW_MAX_SWINGS);
      ArrayResize(selected, selectedCount);
      for(int i = 0; i < selectedCount; i++) selected[i] = lows[i];
      return true;
   }
   if(preferBear && bearishOk)
   {
      isBearishOut = true;
      selectedCount = MathMin(highCount, DOW_MAX_SWINGS);
      ArrayResize(selected, selectedCount);
      for(int i = 0; i < selectedCount; i++) selected[i] = highs[i];
      return true;
   }

   // MODIFIÉ: Sur Boom/GainX/Crash/PainX, ne PAS dessiner la direction opposée
   // Sur PainX/Crash: on ne veut que du bearish (lower highs)
   // Sur Boom/GainX: on ne veut que du bullish (higher lows)
   if(preferBull || preferBear)
   {
      Print("[DOW] Direction spécifique non trouvée pour ", symbol,
            " - Aucune trendline tracée");
      return false;
   }

   // Symbole non Boom/Crash/Painx/Gainx: prendre la structure Dow la plus nette
   if(bullishOk && !bearishOk)
   {
      isBearishOut = false;
      selectedCount = MathMin(lowCount, DOW_MAX_SWINGS);
      ArrayResize(selected, selectedCount);
      for(int i = 0; i < selectedCount; i++) selected[i] = lows[i];
      return true;
   }
   if(bearishOk && !bullishOk)
   {
      isBearishOut = true;
      selectedCount = MathMin(highCount, DOW_MAX_SWINGS);
      ArrayResize(selected, selectedCount);
      for(int i = 0; i < selectedCount; i++) selected[i] = highs[i];
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Ajuste la tendance pour ne garder QUE les swings concordants    |
//| (élimine les outliers qui cassent la trendline)                  |
//+------------------------------------------------------------------+
void Dow_FitTrendline(DowSwingPoint &points[], int count, bool isBearish,
                      datetime &t0, double &p0, datetime &t1, double &p1)
{
   if(count < 2) return;

   // Utiliser les 2 points les plus éloignés pour la pente maximale
   // Trier par temps croissant
   for(int i = 0; i < count - 1; i++)
      for(int j = i + 1; j < count; j++)
         if(points[i].time > points[j].time)
         { DowSwingPoint tmp = points[i]; points[i] = points[j]; points[j] = tmp; }

   // Régression linéaire simple sur price vs time
   double sumT = 0, sumP = 0, sumTP = 0, sumTT = 0;
   for(int i = 0; i < count; i++)
   {
      double t = (double)(points[i].time);
      double p = points[i].price;
      sumT  += t;
      sumP  += p;
      sumTP += t * p;
      sumTT += t * t;
   }
   double n = (double)count;
   double denom = n * sumTT - sumT * sumT;
   if(MathAbs(denom) < 1e-10) return;

   double slope = (n * sumTP - sumT * sumP) / denom;
   double intercept = (sumP - slope * sumT) / n;

   // Les deux extrémités
   t0 = points[0].time;
   p0 = slope * (double)t0 + intercept;
   t1 = points[count - 1].time;
   p1 = slope * (double)t1 + intercept;
}

//+------------------------------------------------------------------+
//| Draw la trendline Dow sur le chart                               |
//+------------------------------------------------------------------+
void Dow_DrawTrendline(datetime t0, double p0, datetime t1, double p1,
                       bool isBearish, datetime projTime, double projPrice)
{
   string prefix = "DOW_TL_";

    // Trendline principale (rayon droit infini + point d'extension à 1000 barres)
    string tlName = prefix + "line";
    double tlSlope = (t1 != t0) ? (p1 - p0) / (double)(t1 - t0) : 0;
    datetime extTime = projTime + PeriodSeconds(PERIOD_M1) * DOW_TL_EXTEND_BARS;
    double extPrice = p1 + tlSlope * (double)(extTime - t1);
    ObjectDelete(0, tlName);
    ObjectCreate(0, tlName, OBJ_TREND, 0, t0, p0, extTime, extPrice);
    ObjectSetInteger(0, tlName, OBJPROP_COLOR, DOW_TRENDLINE_COLOR);
    ObjectSetInteger(0, tlName, OBJPROP_WIDTH, DOW_TRENDLINE_WIDTH);
    ObjectSetInteger(0, tlName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, tlName, OBJPROP_RAY_RIGHT, true);
    ObjectSetInteger(0, tlName, OBJPROP_BACK, false);
   ObjectSetString(0, tlName, OBJPROP_TOOLTIP,
                   isBearish ? "DOW BEARISH (lower highs)" : "DOW BULLISH (higher lows)");

   // Point de projection (entrée LIMIT sur la trendline Dow)
   string projName = prefix + "proj";
   color projColor = DOW_PROJ_COLOR;
   ObjectDelete(0, projName);
   ObjectCreate(0, projName, OBJ_ARROW, 0, projTime, projPrice);
   ObjectSetInteger(0, projName, OBJPROP_COLOR, projColor);
   ObjectSetInteger(0, projName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, projName, OBJPROP_ARROWCODE, isBearish ? 234 : 233);
   ObjectSetString(0, projName, OBJPROP_TEXT, "DOW LIMIT");
   ObjectSetInteger(0, projName, OBJPROP_ANCHOR, isBearish ? ANCHOR_UPPER : ANCHOR_LOWER);

   // Ligne horizontale au niveau projeté
   string hlineName = prefix + "hline";
   color hlineColor = DOW_PROJ_COLOR;
   ObjectDelete(0, hlineName);
   ObjectCreate(0, hlineName, OBJ_HLINE, 0, 0, projPrice);
   ObjectSetInteger(0, hlineName, OBJPROP_COLOR, hlineColor);
   ObjectSetInteger(0, hlineName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetString(0, hlineName, OBJPROP_TOOLTIP, "DOW projected level");

   // Label avec prix projeté
   string labelName = prefix + "label";
   ObjectDelete(0, labelName);
   ObjectCreate(0, labelName, OBJ_TEXT, 0, projTime, projPrice);
   ObjectSetString(0, labelName, OBJPROP_TEXT,
                   (isBearish ? "SELL LIMIT @ " : "BUY LIMIT @ ") + DoubleToString(projPrice, _Digits));
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, DOW_PROJ_COLOR);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);

   // Bande latérale (indicateur visuel)
   string cpLine = prefix + "chainline";
   if(ObjectFind(0, cpLine) >= 0) ObjectDelete(0, cpLine);
}

//+------------------------------------------------------------------+
//| Supprime les objets trendline Dow du chart                       |
//+------------------------------------------------------------------+
void Dow_CleanupChart()
{
   string prefixes[] = {"DOW_TL_"};
   for(int p = 0; p < ArraySize(prefixes); p++)
   {
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, prefixes[p]) == 0)
            ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
//| Scanne les swings sur un TF donné (M5 ou H1)                    |
//+------------------------------------------------------------------+
bool Dow_ScanSwingsOnTF(const string symbol, ENUM_TIMEFRAMES tf, DowSwingPoint &swings[], int &count)
{
   count = 0;
   MqlRates rates[];
   int barsNeeded = DOW_MAX_SWINGS * (DOW_MTF_SWING_LOOKBACK * 2 + 1) + 20;
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(symbol, tf, 0, barsNeeded, rates);
   if(copied < barsNeeded) return false;

   int maxSwings = DOW_MAX_SWINGS * 2;
   ArrayResize(swings, maxSwings);

   for(int i = DOW_MTF_SWING_LOOKBACK; i < copied - DOW_MTF_SWING_LOOKBACK && count < maxSwings; i++)
   {
      // Swing High
      bool isHigh = true;
      for(int j = i - DOW_MTF_SWING_LOOKBACK; j <= i + DOW_MTF_SWING_LOOKBACK; j++)
      {
         if(j != i && rates[j].high >= rates[i].high)
         { isHigh = false; break; }
      }
      if(isHigh && count < maxSwings)
      {
         swings[count].time  = rates[i].time;
         swings[count].price = rates[i].high;
         swings[count].isHigh = true;
         count++;
      }

      // Swing Low
      bool isLow = true;
      for(int j = i - DOW_MTF_SWING_LOOKBACK; j <= i + DOW_MTF_SWING_LOOKBACK; j++)
      {
         if(j != i && rates[j].low <= rates[i].low)
         { isLow = false; break; }
      }
      if(isLow && count < maxSwings)
      {
         swings[count].time  = rates[i].time;
         swings[count].price = rates[i].low;
         swings[count].isHigh = false;
         count++;
      }
   }
   return (count >= 2);
}

//+------------------------------------------------------------------+
//| Vérifie qu'un canal trending existe sur M5 ou H1                |
//| Retourne true si un canal est confirmé (pas en correction)       |
//| isBearishOut = direction du canal détecté                        |
//+------------------------------------------------------------------+
bool Dow_IsChannelConfirmedOnMTF(const string symbol, bool &isBearishOut)
{
   // Scanner M5
   DowSwingPoint m5Swings[];
   int m5Count = 0;
   bool m5Ok = Dow_ScanSwingsOnTF(symbol, PERIOD_M5, m5Swings, m5Count);

   // Scanner H1
   DowSwingPoint h1Swings[];
   int h1Count = 0;
   bool h1Ok = Dow_ScanSwingsOnTF(symbol, PERIOD_H1, h1Swings, h1Count);

   if(!m5Ok && !h1Ok) return false;

   // Séparer high/low pour M5
   bool m5Bearish = false, m5Bullish = false;
   if(m5Ok)
   {
      DowSwingPoint m5Highs[], m5Lows[];
      int m5HC = 0, m5LC = 0;
      ArrayResize(m5Highs, m5Count);
      ArrayResize(m5Lows, m5Count);
      for(int i = 0; i < m5Count; i++)
      {
         if(m5Swings[i].isHigh) { m5Highs[m5HC] = m5Swings[i]; m5HC++; }
         else { m5Lows[m5LC] = m5Swings[i]; m5LC++; }
      }
      ArrayResize(m5Highs, m5HC);
      ArrayResize(m5Lows, m5LC);
      Dow_SortSwingsByTimeDesc(m5Highs, m5HC);
      Dow_SortSwingsByTimeDesc(m5Lows, m5LC);
      m5Bearish = Dow_ValidateLowerHighs(m5Highs, m5HC);
      m5Bullish = Dow_ValidateHigherLows(m5Lows, m5LC);
   }

   // Séparer high/low pour H1
   bool h1Bearish = false, h1Bullish = false;
   if(h1Ok)
   {
      DowSwingPoint h1Highs[], h1Lows[];
      int h1HC = 0, h1LC = 0;
      ArrayResize(h1Highs, h1Count);
      ArrayResize(h1Lows, h1Count);
      for(int i = 0; i < h1Count; i++)
      {
         if(h1Swings[i].isHigh) { h1Highs[h1HC] = h1Swings[i]; h1HC++; }
         else { h1Lows[h1LC] = h1Swings[i]; h1LC++; }
      }
      ArrayResize(h1Highs, h1HC);
      ArrayResize(h1Lows, h1LC);
      Dow_SortSwingsByTimeDesc(h1Highs, h1HC);
      Dow_SortSwingsByTimeDesc(h1Lows, h1LC);
      h1Bearish = Dow_ValidateLowerHighs(h1Highs, h1HC);
      h1Bullish = Dow_ValidateHigherLows(h1Lows, h1LC);
   }

   // Boom/GainX = préfère canal haussier | Crash/PainX = préfère canal baissier
   bool preferBull = IsBoomLikeSymbol(symbol);
   bool preferBear = IsCrashLikeSymbol(symbol);

   // Priorité: canal aligné avec la direction naturelle du symbole
   if(preferBull && (m5Bullish || h1Bullish))
   {
      isBearishOut = false;
      return true;
   }
   if(preferBear && (m5Bearish || h1Bearish))
   {
      isBearishOut = true;
      return true;
   }

   // MODIFIÉ: Sur Boom/GainX/Crash/PainX, ne PAS détecter la direction opposée
   if(preferBull || preferBear)
      return false;

   // Sinon: prendre le canal le plus net
   if(m5Bullish || h1Bullish)
   {
      isBearishOut = false;
      return true;
   }
   if(m5Bearish || h1Bearish)
   {
      isBearishOut = true;
      return true;
   }

   // Aucun canal trending → consolidation/correction
   return false;
}

//+------------------------------------------------------------------+
//| Valide et ajuste le prix d'entrée dans les bornes du canal      |
//| BUY LIMIT: entre swingLow et swingLow + ATR*max                  |
//| SELL LIMIT: entre swingHigh - ATR*max et swingHigh               |
//| Retourne le prix ajusté                                          |
//+------------------------------------------------------------------+
double Dow_ValidateEntryBounds(double projectedPrice, bool isBearish, double atr, const string symbol)
{
   if(atr <= 0) return projectedPrice;

   // Trouver le swing high/low récent sur M1
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 60, rates) < 30) return projectedPrice;

   double recentHigh = rates[0].high;
   double recentLow = rates[0].low;
   for(int i = 1; i < 30; i++)
   {
      if(rates[i].high > recentHigh) recentHigh = rates[i].high;
      if(rates[i].low < recentLow) recentLow = rates[i].low;
   }

   double maxDeviation = atr * DOW_ENTRY_MAX_ATR;

   if(!isBearish) // BUY LIMIT
   {
      // Le prix doit être au-dessus du swingLow et au maximum ATR*max au-dessus
      double lowerBound = recentLow;
      double upperBound = recentLow + maxDeviation;
      if(projectedPrice < lowerBound)
      {
         Print("[DOW] Entry ajustée (trop basse): ", DoubleToString(projectedPrice, _Digits),
               " → ", DoubleToString(lowerBound, _Digits));
         return lowerBound;
      }
      if(projectedPrice > upperBound)
      {
         Print("[DOW] Entry ajustée (trop haute): ", DoubleToString(projectedPrice, _Digits),
               " → ", DoubleToString(upperBound, _Digits));
         return upperBound;
      }
   }
   else // SELL LIMIT
   {
      // Le prix doit être en-dessous du swingHigh et au minimum ATR*max en-dessous
      double upperBound = recentHigh;
      double lowerBound = recentHigh - maxDeviation;
      if(projectedPrice > upperBound)
      {
         Print("[DOW] Entry ajustée (trop haute): ", DoubleToString(projectedPrice, _Digits),
               " → ", DoubleToString(upperBound, _Digits));
         return upperBound;
      }
      if(projectedPrice < lowerBound)
      {
         Print("[DOW] Entry ajustée (trop basse): ", DoubleToString(projectedPrice, _Digits),
               " → ", DoubleToString(lowerBound, _Digits));
         return lowerBound;
      }
   }

   return projectedPrice;
}

//+------------------------------------------------------------------+
//| Initialise le module                                             |
//+------------------------------------------------------------------+
void DowTrendline_Init()
{
   g_dowState.active = false;
   g_dowState.projectedPrice = 0;
   g_dowState.limitPlacedAt = 0;
   g_dowState.lastChaseAt = 0;
   g_dowState.chasingEma = false;
   g_dowState.limitTicket = 0;
   Print("📊 DOW Trendline module initialized (+ EMA chase si LIMIT stale)");
}

//+------------------------------------------------------------------+
//| Trouve le ticket LIMIT DOW existant (0 si aucun)                  |
//| Accepte "DOW" et "DOW-EMA" (chase)                                |
//+------------------------------------------------------------------+
ulong Dow_FindLimitTicket(const string symbol)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;
      if(StringFind(OrderGetString(ORDER_COMMENT), "DOW") >= 0)
         return ticket;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| EMA fast sur TF donné (0 si indisponible)                         |
//+------------------------------------------------------------------+
double Dow_GetEma(const string symbol, ENUM_TIMEFRAMES tf = PERIOD_M1)
{
   int h = iMA(symbol, tf, DOW_EMA_FAST_PERIOD, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 0;
   double buf[];
   ArraySetAsSeries(buf, true);
   double ema = 0;
   if(CopyBuffer(h, 0, 0, 1, buf) >= 1)
      ema = buf[0];
   IndicatorRelease(h);
   return ema;
}

//+------------------------------------------------------------------+
//| GOM autorise le chase : GOOD/PERFECT aligné avec direction DOW    |
//+------------------------------------------------------------------+
bool Dow_GomAllowsChase(const bool isBearish)
{
   // Si filtre GOM off → autoriser chase (discipline prix seule)
   if(!UseGOMVerdictFilter) return true;
   if(!g_smcGomConnected) return false;

   int vn = g_smcGomVerdictNum;
   if(MathAbs(vn) < 2) return false; // WAIT / SIMPLE → pas de chase

   if(isBearish && vn >= 2) return false; // DOW SELL mais GOM BUY
   if(!isBearish && vn <= -2) return false; // DOW BUY mais GOM SELL
   return true;
}

//+------------------------------------------------------------------+
//| GOM = WAIT (ou SIMPLE hors GP) → ne pas laisser un LIMIT zombie  |
//+------------------------------------------------------------------+
bool Dow_GomIsWaitOrBlocked()
{
   if(!UseGOMVerdictFilter) return false;
   if(!g_smcGomConnected) return false;
   return (MathAbs(g_smcGomVerdictNum) < 2);
}

//+------------------------------------------------------------------+
//| LIMIT stale : âgé + prix trop loin (spike n'est pas revenu)      |
//+------------------------------------------------------------------+
bool Dow_IsLimitStale(const ulong ticket, const double atrVal)
{
   if(ticket == 0 || atrVal <= 0) return false;
   if(!OrderSelect(ticket)) return false;

   datetime placed = g_dowState.limitPlacedAt;
   if(placed <= 0)
      placed = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
   if(placed <= 0) return false;

   int age = (int)(TimeCurrent() - placed);
   if(age < DOW_STALE_SEC) return false;

   double limitPx = OrderGetDouble(ORDER_PRICE_OPEN);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(limitPx <= 0 || bid <= 0 || ask <= 0) return false;

   ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   double dist = (t == ORDER_TYPE_BUY_LIMIT) ? (bid - limitPx) : (limitPx - ask);
   if(dist < atrVal * DOW_STALE_ATR) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Supprime un LIMIT DOW/DOW-EMA                                     |
//+------------------------------------------------------------------+
bool Dow_RemoveLimit(const ulong ticket, const string reason)
{
   if(ticket == 0) return false;
   if(!LimitSafeOrderDelete(ticket, false, "DOW " + reason))
      return false;
   g_dowState.limitTicket = 0;
   g_dowState.limitPlacedAt = 0;
   g_dowState.lastChaseAt = 0;
   g_dowState.limitRemovedAt = TimeCurrent();
   g_dowState.chasingEma = false;
   return true;
}

//+------------------------------------------------------------------+
//| Prix chase EMA fast (BUY sous EMA, SELL au-dessus)                |
//+------------------------------------------------------------------+
double Dow_ComputeEmaChasePrice(const bool isBearish, const double atrVal)
{
   double ema = Dow_GetEma(_Symbol);
   if(ema <= 0 || atrVal <= 0) return 0;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) point = _Point;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0) tickSize = point;
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = MathMax((double)stopsLevel * point, tickSize);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double offset = atrVal * DOW_CHASE_OFFSET_ATR;
   if(offset < minDist) offset = minDist;

   double price = 0;
   if(isBearish)
   {
      // SELL LIMIT au-dessus du marché, ancré EMA(+offset)
      price = ema + offset;
      double minSell = ask + minDist;
      if(price < minSell) price = minSell;
   }
   else
   {
      // BUY LIMIT sous le marché, ancré EMA(-offset)
      price = ema - offset;
      double maxBuy = bid - minDist;
      if(price > maxBuy) price = maxBuy;
   }

   return NormalizeDouble(price, dg);
}

//+------------------------------------------------------------------+
//| Met à jour le marqueur graphique chase (hline PROJ)               |
//+------------------------------------------------------------------+
void Dow_UpdateChaseVisual(const double chasePrice, const bool isBearish)
{
   string hlineName = "DOW_TL_hline";
   if(ObjectFind(0, hlineName) >= 0)
      ObjectSetDouble(0, hlineName, OBJPROP_PRICE, 0, chasePrice);

   string labelName = "DOW_TL_label";
   if(ObjectFind(0, labelName) >= 0)
   {
      ObjectSetString(0, labelName, OBJPROP_TEXT,
                      (isBearish ? "SELL EMA-CHASE @ " : "BUY EMA-CHASE @ ")
                      + DoubleToString(chasePrice, _Digits));
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrDodgerBlue);
   }
}

//+------------------------------------------------------------------+
//| Chase : modify LIMIT vers EMA fast (conserve ticket DOW)          |
//| Retourne true si modify OK                                        |
//+------------------------------------------------------------------+
bool Dow_ChaseLimitToEma(const ulong ticket, const bool isBearish, const double atrVal)
{
   if(ticket == 0 || atrVal <= 0) return false;
   if(!OrderSelect(ticket)) return false;

   // Throttle
   if(g_dowState.lastChaseAt > 0 &&
      (TimeCurrent() - g_dowState.lastChaseAt) < DOW_CHASE_REFRESH_SEC)
      return false;

   double newPrice = Dow_ComputeEmaChasePrice(isBearish, atrVal);
   if(newPrice <= 0) return false;

   double oldPrice = OrderGetDouble(ORDER_PRICE_OPEN);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) point = _Point;
   if(MathAbs(oldPrice - newPrice) < point * DOW_CHASE_MIN_MOVE_PTS)
   {
      g_dowState.lastChaseAt = TimeCurrent();
      return false;
   }

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double sl, tp;
   if(isBearish)
   {
      sl = NormalizeDouble(newPrice + atrVal * DOW_SL_ATRMULT, dg);
      tp = NormalizeDouble(newPrice - atrVal * DOW_TP_ATRMULT, dg);
   }
   else
   {
      sl = NormalizeDouble(newPrice - atrVal * DOW_SL_ATRMULT, dg);
      tp = NormalizeDouble(newPrice + atrVal * DOW_TP_ATRMULT, dg);
   }

   // Modify prix uniquement (commentaire inchangé — reste "DOW*" → survit au purge)
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_MODIFY;
   req.order  = ticket;
   req.price  = newPrice;
   req.sl     = sl;
   req.tp     = tp;

   if(OrderSend(req, res))
   {
      g_dowState.chasingEma = true;
      g_dowState.lastChaseAt = TimeCurrent();
      g_dowState.limitTicket = ticket;
      Dow_UpdateChaseVisual(newPrice, isBearish);
      Print("[DOW→EMA] LIMIT chase @ ", DoubleToString(newPrice, dg),
            " (ancien ", DoubleToString(oldPrice, dg), ") EMA",
            DOW_EMA_FAST_PERIOD, " | vn=", g_smcGomVerdictNum,
            " | ticket=", ticket);
      return true;
   }

   Print("[DOW→EMA] Modify failed: ", res.retcode, " - ", res.comment);
   return false;
}

//+------------------------------------------------------------------+
//| Prix LIMIT = ligne horizontale DOW PROJ sur le graphique          |
//+------------------------------------------------------------------+
double Dow_GetProjPriceFromChart()
{
   string hlineName = "DOW_TL_hline";
   if(ObjectFind(0, hlineName) < 0) return 0;
   return ObjectGetDouble(0, hlineName, OBJPROP_PRICE, 0);
}

//+------------------------------------------------------------------+
//| Vérifie si la trendline est cassée par le prix                    |
//+------------------------------------------------------------------+
bool Dow_IsTrendlineBroken(const string symbol, bool isBearish)
{
    if(!g_dowState.active) return false;
    if(g_dowState.endTime <= 0) return false;

    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int bars = DOW_BREAK_CHECK_BARS + 2;
    if(CopyRates(symbol, PERIOD_M1, 0, bars, rates) < bars) return false;

    for(int i = 0; i < bars - 1; i++)
    {
        // Prix projeté de la trendline à ce moment
        double tDelta = (double)(rates[i].time - g_dowState.endTime);
        double tlPrice = g_dowState.endPrice + g_dowState.slope * tDelta;

        if(isBearish)
        {
            // Trendline baissière (lower highs) → cassée si close > tlPrice
            if(rates[i].close > tlPrice)
                return true;
        }
        else
        {
            // Trendline haussière (higher lows) → cassée si close < tlPrice
            if(rates[i].close < tlPrice)
                return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Vérifie entrée sur OB + fast EMA M5/M1 aligné avec verdict       |
//+------------------------------------------------------------------+
bool Dow_IsEntryValidByOB_EMA(const string symbol, bool isBearish)
{
    // 1. Verdict GOM aligné avec la direction
    if(UseGOMVerdictFilter && g_smcGomConnected)
    {
        int vn = g_smcGomVerdictNum;
        if(vn == 0) return false;                    // WAIT
        if(isBearish && vn > 0) return false;         // SELL demandé mais GOM BUY
        if(!isBearish && vn < 0) return false;        // BUY demandé mais GOM SELL
        if(MathAbs(vn) < 2) return false;             // SIMPLE → pas assez confiant
    }

    // 2. Fast EMA M1 alignée
    double emaM1 = Dow_GetEma(symbol);
    if(emaM1 <= 0) return true; // pas d'EMA → on laisse passer

    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    if(isBearish && bid < emaM1) return false;  // SELL mais prix sous EMA → pas aligné
    if(!isBearish && ask > emaM1) return false;  // BUY mais prix au-dessus EMA → pas aligné

    // 3. OB sur M5 (OrderBlock dans la même direction)
    OrderBlockData ob;
    if(SMC_DetectOrderBlock(symbol, PERIOD_M5, ob))
    {
        if(isBearish && ob.direction == -1) return true;  // SELL + OB baissier ✅
        if(!isBearish && ob.direction == 1) return true;  // BUY + OB haussier ✅
        // OB direction opposée → bloquer
        return false;
    }

    // 4. Pas d'OB → entrée seulement si EMA M5 alignée
    double emaM5 = Dow_GetEma(symbol, PERIOD_M5);
    if(emaM5 <= 0) return true;
    if(isBearish && bid < emaM5) return false;
    if(!isBearish && ask > emaM5) return false;

    return true;
}

//+------------------------------------------------------------------+
//| Calcule le prochain point de touché prix ↔ trendline              |
//| Retourne (touchTime, touchPrice) et offset LIMITTime              |
//+------------------------------------------------------------------+
bool Dow_ComputeTouchProjection(bool isBearish,
                                datetime &touchTime, double &touchPrice,
                                datetime &limitTime,  double &limitPrice)
{
   if(!g_dowState.active) return false;
   if(g_dowState.endTime <= 0) return false;

   double slope = g_dowState.slope;
   datetime t1 = g_dowState.endTime;
   double p1 = g_dowState.endPrice;

   // Prix courant
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double current = isBearish ? ask : bid;

   // Momentum M1 (moyenne des 5 dernières variations de close)
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 10, rates) < 6) return false;
   double avgMove = 0;
   for(int i = 1; i <= 5; i++)
      avgMove += (rates[i-1].close - rates[i].close);
   avgMove /= 5.0;

   datetime now = TimeCurrent();
   datetime tfSec = PeriodSeconds(PERIOD_M1);

   // Parcourir les futures bougies M1 pour trouver l'intersection
   for(int b = 1; b <= DOW_TOUCH_MAX_LOOKAHEAD; b++)
   {
      datetime T = now + b * tfSec;
      double tlPrice = p1 + slope * (T - t1);
      double estPrice = current + avgMove * b;

      bool crossed = false;
      if(isBearish)
      {
         // Price monte vers TL descendante → intersection si estPrice >= tlPrice
         if(estPrice >= tlPrice) crossed = true;
      }
      else
      {
         // Price descend vers TL montante → intersection si estPrice <= tlPrice
         if(estPrice <= tlPrice) crossed = true;
      }

      if(crossed)
      {
         // Interpolation linéaire pour le point exact
         datetime T_prev = now + (b - 1) * tfSec;
         double tlPrev = p1 + slope * (T_prev - t1);
         double estPrev = current + avgMove * (b - 1);
         double dEst  = estPrice - estPrev;
         double dTL   = tlPrice - tlPrev;
         double tFrac = (tlPrev - estPrev) / (dEst - dTL); // 0..1 entre prev et now
         if(tFrac < 0.0) tFrac = 0.0;
         if(tFrac > 1.0) tFrac = 1.0;

         touchTime   = (datetime)(T_prev + (int)(tfSec * tFrac));
         touchPrice  = p1 + slope * (touchTime - t1);

         // LIMIT = N bougies M1 AVANT le touché sur la trendline
         datetime   limT = touchTime - DOW_TOUCH_M1_AHEAD * tfSec;
         if(limT < now) limT = now; // ne pas placer dans le passé
         limitTime  = limT;
         limitPrice = p1 + slope * (limitTime - t1);
         return true;
      }
   }

   // Fallback: projection fixe DOW_PROJ_BARS_AHEAD
   touchTime  = now + 8 * tfSec;
   touchPrice = p1 + slope * (touchTime - t1);
   limitTime  = touchTime - DOW_TOUCH_M1_AHEAD * tfSec;
   if(limitTime < now) limitTime = now;
   limitPrice = p1 + slope * (limitTime - t1);
   return true;
}

//+------------------------------------------------------------------+
//| Trendline DOW = prédicteur d'entrée                               |
//| Quand la tendance est claire (swings confirmés + MTF aligné)     |
//| → entrée MARKET immédiat dans la direction de la trendline       |
//| GOM ne fait que VETO : bloquer si verdict CONTRAIRE              |
//| GOM WAIT (vn=0) → la trendline décide seule                      |
//+------------------------------------------------------------------+
datetime g_dowLastPerfectMarketEntry = 0;
#define DOW_PERFECT_COOLDOWN_SEC 30  // cooldown entre entrées

//+------------------------------------------------------------------+
//| Logique de gating :                                               |
//|  - 2+ swings + GOM PERFECT aligné → ENTER (GOM confirme)         |
//|  - 3+ swings + GOM WAIT/DISCONNECTED → ENTER (trendline seul)    |
//|  - GOM contraire → VETO                                           |
//+------------------------------------------------------------------+
bool Dow_GomVetoesDirection(bool isBearish)
{
   if(!UseGOMVerdictFilter) return false;
   if(!g_smcGomConnected) return false;

   int vn = g_smcGomVerdictNum;
   if(vn == 0) return false;

   if(!isBearish && vn < 0) return true;
   if(isBearish && vn > 0) return true;

   return false;
}

void Dow_ExecutePredictiveMarketOrder(bool isBearish, double atrVal, int selectedCount)
{
   if(!UseDowTrendline) return;
   if(selectedCount < 2) return;  // minimum absolu : 2 swings

   // ── BLOQUAGE RETRACEMENT ──────────────────────────────────────
   // Si le prix est dans une zone de retracement (M1/M5/H1/H4), AUCUNE entrée
   if(g_inRetrace)
   {
      static datetime s_lastRetraceLog = 0;
      if(TimeCurrent() - s_lastRetraceLog >= 30)
      {
         s_lastRetraceLog = TimeCurrent();
         Print("[DOW→PREDICT] RETRACE ZONE | prix=", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
               " → entrée bloquée");
      }
      return;
   }

   // GOM veto
   if(Dow_GomVetoesDirection(isBearish))
   {
      static datetime s_lastVetoLog = 0;
      if(TimeCurrent() - s_lastVetoLog >= 30)
      {
         s_lastVetoLog = TimeCurrent();
         Print("[DOW→PREDICT] Veto GOM | DOW=", (isBearish ? "SELL" : "BUY"),
               " GOM vn=", g_smcGomVerdictNum, " → entrée bloquée");
      }
      return;
   }

    // ── BLOQUAGE GOM=WAIT / DÉCONNECTÉ ─────────────────────────
    // Quand le verdict est WAIT ou le GOM déconnecté, AUCUNE entrée autorisée
    if(!g_smcGomConnected || g_smcGomVerdictNum == 0)
    {
       static datetime s_lastWaitBlock = 0;
       if(TimeCurrent() - s_lastWaitBlock >= 30)
       {
          s_lastWaitBlock = TimeCurrent();
          Print("[DOW→PREDICT] GOM ",
                (!g_smcGomConnected ? "DÉCONNECTÉ" : "WAIT"),
                " | vn=", g_smcGomVerdictNum,
                " → entrée bloquée (aucun ordre autorisé)");
       }
       return;
    }

    // ── Exige GOOD/PERFECT (|vn|>=2) — pas de SIMPLE ───────────
    if(MathAbs(g_smcGomVerdictNum) < 2)
    {
       static datetime s_lastSimpleBlock = 0;
       if(TimeCurrent() - s_lastSimpleBlock >= 30)
       {
          s_lastSimpleBlock = TimeCurrent();
          Print("[DOW→PREDICT] GOM SIMPLE vn=", g_smcGomVerdictNum,
                " → entrée bloquée (exige GOOD/PERFECT)");
       }
       return;
    }

    // Gate de confirmation :
    //  - GOM GOOD/PERFECT aligné avec direction DOW
    //  - décision finale BUY/SELL clignotante confirmée
    bool gomAligned = false;
    {
       int vn = g_smcGomVerdictNum;
       gomAligned = (!isBearish && vn >= 2) || (isBearish && vn <= -2);
    }
    if(!gomAligned)
    {
       static datetime s_lastAlignLog = 0;
       if(TimeCurrent() - s_lastAlignLog >= 30)
       {
          s_lastAlignLog = TimeCurrent();
          Print("[DOW→PREDICT] GOM non aligné DOW=", (isBearish ? "SELL" : "BUY"),
                " vn=", g_smcGomVerdictNum);
       }
       return;
    }

   // Cooldown
   if(TimeCurrent() - g_dowLastPerfectMarketEntry < DOW_PERFECT_COOLDOWN_SEC) return;

   // ── BLINK GATE : décision finale BUY/SELL doit clignoter ~1.5s
   if(!IsSignalConfirmed()) return;
   int blinkDir = GetConfirmedSignalDir();
   if((!isBearish && blinkDir != 1) || (isBearish && blinkDir != -1))
      return;

    // Direction spike obligatoire (Boom/Gainx=BUY, Crash/Painx=SELL)
    string dirStr = isBearish ? "SELL" : "BUY";
    if(!IsDirectionAllowedForBoomCrash(_Symbol, dirStr))
    {
       Print("[DOW→PREDICT] 🚫 ", dirStr, " interdit sur ", _Symbol, " (règle spike)");
       return;
    }

    // Pas de position ouverte
    if(CountPositionsForSymbol(_Symbol) > 0) return;

    // Gate central marché (GOM + direction + caps)
    if(!CanPlaceMarketOrder(_Symbol, isBearish ? -1 : 1)) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(atrVal <= 0) return;

   // ── Entrée UNIQUEMENT au niveau de la trendline DOW (toucher) ──
   datetime nowTL = TimeCurrent();
   double tlPrice = g_dowState.endPrice + g_dowState.slope * (double)(nowTL - g_dowState.endTime);
   double nearTol = atrVal * 0.40;
   double refPx = isBearish ? bid : ask;
   if(MathAbs(refPx - tlPrice) > nearTol)
   {
      static datetime s_lastFarLog = 0;
      if(TimeCurrent() - s_lastFarLog >= 45)
      {
         s_lastFarLog = TimeCurrent();
         Print("[DOW→PREDICT] Prix loin de trendline | px=", DoubleToString(refPx, dg),
               " TL=", DoubleToString(tlPrice, dg), " tol=", DoubleToString(nearTol, dg),
               " → attendre touché");
      }
      return;
   }

   // Cross-Correlation gate
   if(UseCrossCorrelation && UseCrossCorrDOWgate && CrossCorr_IsSignalActive())
   {
      double xStrength = CrossCorr_GetSignalStrength();
      if(xStrength >= 0.7)
      {
         int xDir = CrossCorr_GetPredictedDirection();
         bool aligne = (isBearish && xDir == -1) || (!isBearish && xDir == +1);
         if(!aligne) return;
      }
   }

   double lot = CalculateLotSize();
   if(lot <= 0) return;

   if(!TryAcquireOpenLock()) return;

   bool ok = false;
   int vn = g_smcGomConnected ? g_smcGomVerdictNum : 0;

   if(!isBearish) // BUY
   {
      double sl = NormalizeDouble(ask - atrVal * DOW_SL_ATRMULT, dg);
      double tp = NormalizeDouble(ask + atrVal * DOW_TP_ATRMULT, dg);
      ok = trade.Buy(lot, _Symbol, ask, sl, tp, "DOW TL MARKET BUY");
      if(ok)
      {
         g_dowLastPerfectMarketEntry = TimeCurrent();
         ulong ticket = trade.ResultOrder();
         if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
         Print("🚀 DOW TL MARKET BUY | Entry=", DoubleToString(ask, dg),
               " TL=", DoubleToString(tlPrice, dg),
               " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg),
               " Lot=", DoubleToString(lot, 2), " | swings=", selectedCount,
               " vn=", vn, " (GOM+blink+touche TL)");
         if(UseNotifications)
            SendNotification("🚀 DOW TL BUY " + _Symbol + " vn=" + IntegerToString(vn));
      }
   }
   else // SELL
   {
      double sl = NormalizeDouble(bid + atrVal * DOW_SL_ATRMULT, dg);
      double tp = NormalizeDouble(bid - atrVal * DOW_TP_ATRMULT, dg);
      ok = trade.Sell(lot, _Symbol, bid, sl, tp, "DOW TL MARKET SELL");
      if(ok)
      {
         g_dowLastPerfectMarketEntry = TimeCurrent();
         ulong ticket = trade.ResultOrder();
         if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
         Print("🚀 DOW TL MARKET SELL | Entry=", DoubleToString(bid, dg),
               " TL=", DoubleToString(tlPrice, dg),
               " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg),
               " Lot=", DoubleToString(lot, 2), " | swings=", selectedCount,
               " vn=", vn, " (GOM+blink+touche TL)");
         if(UseNotifications)
            SendNotification("🚀 DOW TL SELL " + _Symbol + " vn=" + IntegerToString(vn));
      }
   }

   ReleaseOpenLock();
}

//+------------------------------------------------------------------+
//| Boucle principale — scan + LIMIT dynamique ou MARKET (PERFECT)   |
//| GOM PERFECT + direction alignée → MARKET immédiat (scalp)        |
//| Sinon → LIMIT au prochain touché trendline                       |
//+------------------------------------------------------------------+
void DowTrendline_OnTick()
{
   if(!UseDowTrendline) return;

   string symUpper = _Symbol;
   StringToUpper(symUpper);
   bool isSpike = (StringFind(symUpper, "BOOM") >= 0 || StringFind(symUpper, "CRASH") >= 0 ||
                   StringFind(symUpper, "PAINX") >= 0 || StringFind(symUpper, "GAINX") >= 0);
   if(!isSpike) return;

   DowSwingPoint selected[];
   int selectedCount = 0;
   bool isBearish = false;

   if(!Dow_DetectTrend(_Symbol, isBearish, selected, selectedCount))
   {
      if(g_dowState.active)
      {
         g_dowState.active = false;
         Dow_CleanupChart();
      }
      return;
   }

   datetime t0, t1;
   double p0, p1;
   Dow_FitTrendline(selected, selectedCount, isBearish, t0, p0, t1, p1);

   double atrArr[];
   ArraySetAsSeries(atrArr, true);
   int atrH = iATR(_Symbol, PERIOD_M1, 14);
   if(atrH == INVALID_HANDLE || CopyBuffer(atrH, 0, 0, 1, atrArr) < 1) return;
   double atrVal = atrArr[0];
   if(atrVal <= 0) return;

   // Projection de la trendline
   double slope = 0;
   if(t1 != t0) slope = (p1 - p0) / (double)(t1 - t0);
   datetime projTime = TimeCurrent() + PeriodSeconds(PERIOD_M1) * 8;
   double projPrice = p1 + slope * (double)(projTime - t1);

   g_dowState.active = true;
   g_dowState.isBearish = isBearish;
   g_dowState.startTime = t0;
   g_dowState.startPrice = p0;
   g_dowState.endTime = t1;
   g_dowState.endPrice = p1;
   g_dowState.slope = slope;
   g_dowState.projectedPrice = projPrice;
   g_dowState.projectedTime = projTime;
   g_dowState.currentATR = atrVal;

   // Dessin trendline + proj
   Dow_DrawTrendline(t0, p0, t1, p1, isBearish, projTime, projPrice);

   // Direction selon canal Dow
   if(isBearish)
   {
      if(!IsDirectionAllowedForBoomCrash(_Symbol, "SELL")) return;
   }
   else
   {
      if(!IsDirectionAllowedForBoomCrash(_Symbol, "BUY")) return;
   }

   // ── PRIORITÉ 1: Trendline prédit → MARKET immédiat ──────────
   // Trendline (2+ swings) + pas de veto GOM → entrée
   bool hasPosition = (CountPositionsForSymbol(_Symbol) > 0);
   if(!hasPosition)
   {
      Dow_ExecutePredictiveMarketOrder(isBearish, atrVal, selectedCount);
      // Si le MARKET a été placé (position ouverte) → on sort, trailing gère
      // Si GOM=WAIT a bloqué → on continue vers LIMIT
      if(CountPositionsForSymbol(_Symbol) > 0)
         return;
   }
   else
   {
      // Si position ouverte en mode PERFECT, ne rien faire (trailing gère)
      return;
   }

    // ── PRIORITÉ 2: LIMIT classique au touché trendline ──────────
    // Calculer le prix ACTUEL de la trendline (ce qui est affiché au graphique)
    int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickSize <= 0) tickSize = _Point;

    datetime now = TimeCurrent();
    double limitPrice = 0;
    datetime touchTime = 0, limitTime = 0;
    double touchPrice = 0;

    // Priorité: projection touché future avec avance sniper (N bougies + offset prix)
    if(Dow_ComputeTouchProjection(isBearish, touchTime, touchPrice, limitTime, limitPrice))
    {
       double sniperOff = atrVal * DOW_SNIPER_PRICE_OFFSET_ATR;
       if(isBearish)
          limitPrice = NormalizeDouble(limitPrice - sniperOff, dg); // SELL: en dessous de l'intersection
       else
          limitPrice = NormalizeDouble(limitPrice + sniperOff, dg); // BUY: au-dessus de l'intersection
    }
    else
    {
       // Fallback: prix actuel trendline + offset sniper
       double currentTrendlinePrice = g_dowState.endPrice + g_dowState.slope * (now - g_dowState.endTime);
       double sniperOff = atrVal * DOW_SNIPER_PRICE_OFFSET_ATR;
       if(isBearish)
          limitPrice = NormalizeDouble(currentTrendlinePrice - sniperOff, dg);
       else
          limitPrice = NormalizeDouble(currentTrendlinePrice + sniperOff, dg);
    }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return;

   // Cross-Correlation gate
   if(UseCrossCorrelation && UseCrossCorrDOWgate && CrossCorr_IsSignalActive())
   {
      double xStrength = CrossCorr_GetSignalStrength();
      if(xStrength >= 0.7)
      {
         int xDir = CrossCorr_GetPredictedDirection();
         bool aligne = (isBearish && xDir == -1) || (!isBearish && xDir == +1);
         if(!aligne)
         {
            Print("[DOW] ⛔ LIMIT bloqué par CrossCorr : signal ",
                  (xDir == 1 ? "BUY" : "SELL"), " oppose DOW ",
                  (isBearish ? "SELL" : "BUY"),
                  " (force ", DoubleToString(xStrength * 100, 0), "%)");
            return;
         }
      }
   }

   // ── Gérer le LIMIT existant ─────────────────────
   ulong existing = Dow_FindLimitTicket(_Symbol);

   if(existing > 0)
   {
      g_dowState.limitTicket = existing;
      if(g_dowState.limitPlacedAt <= 0 && OrderSelect(existing))
         g_dowState.limitPlacedAt = (datetime)OrderGetInteger(ORDER_TIME_SETUP);

      if(OrderSelect(existing))
      {
         ENUM_ORDER_TYPE curType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         ENUM_ORDER_TYPE wantType = isBearish ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_BUY_LIMIT;
         if(curType != wantType)
         {
            Dow_RemoveLimit(existing, "direction changée");
            return;
         }
      }

      // Vérifier GOM — si WAIT, ne pas supprimer le LIMIT existant
      // Le LIMIT doit continuer à suivre la trendline même sous WAIT
      if(Dow_GomIsWaitOrBlocked())
      {
         // Ne PAS supprimer le LIMIT existant — juste le laisser se mettre à jour
         // Le placement de NOUVEAUX LIMIT est bloqué plus bas (ligne 1422)
      }

      // Supprimer le LIMIT s'il est stale (âge >= 5 min + prix trop loin)
      if(Dow_IsLimitStale(existing, atrVal))
      {
         Dow_RemoveLimit(existing, "stale >5min unfilled");
         return;
      }

      // Mettre à jour le LIMIT pour suivre le prochain touché
      if(OrderSelect(existing))
      {
         double curOpen = OrderGetDouble(ORDER_PRICE_OPEN);
         double diff = MathAbs(limitPrice - curOpen);
         if(diff >= tickSize * 2) // changer que si significatif
         {
            MqlTradeRequest modReq = {};
            MqlTradeResult  modRes = {};
            modReq.action   = TRADE_ACTION_MODIFY;
            modReq.order    = existing;
            modReq.price    = limitPrice;
            modReq.sl       = OrderGetDouble(ORDER_SL);
            modReq.tp       = OrderGetDouble(ORDER_TP);
            modReq.type_time = ORDER_TIME_GTC;
            if(OrderSend(modReq, modRes))
                Print("[DOW] LIMIT modifié ", curOpen, " -> ", limitPrice, " (prix actuel trendline)");
            else
               Print("[DOW] Modify LIMIT échec: ", modRes.retcode);
         }
      }
      return; // LIMIT vivant, ne pas en créer un autre
   }

    // Reset si pas de LIMIT
    g_dowState.chasingEma = false;
    g_dowState.limitTicket = 0;

    // Anti place/delete : attendre 60s après une suppression avant de replacer
    if(g_dowState.limitRemovedAt > 0 && TimeCurrent() - g_dowState.limitRemovedAt < 60)
       return;

    // ── BLINK GATE : signal doit clignoter ~1.5s avant de placer un LIMIT
   if(!IsSignalConfirmed()) return;
   int blinkDirLim = GetConfirmedSignalDir();
   if((!isBearish && blinkDirLim != 1) || (isBearish && blinkDirLim != -1))
      return;

    // ── Placer un nouveau LIMIT si pas de position ouverte ──
    if(Dow_GomIsWaitOrBlocked()) return;

    // ── Terminal cap + per-symbol cap ──
    if(IsTerminalFull())
    {
       Print("🚫 DOW LIMIT BLOQUÉ — Terminal plein (", CountTerminalAllOrders(), "/", MaxPositionsTerminal, ")");
       return;
    }
    if(SymbolHasActiveOrder(_Symbol))
    {
       Print("🚫 DOW LIMIT BLOQUÉ — ", _Symbol, " a déjà un ordre actif");
       return;
    }
    if(CountOpenLimitOrdersTerminal() >= MaxLimitOrdersTerminal)
    {
       Print("🚫 DOW LIMIT BLOQUÉ — ", CountOpenLimitOrdersTerminal(), " LIMIT pending (max=", MaxLimitOrdersTerminal, ")");
       return;
    }

   // Validation : LIMIT doit être du bon côté du marché
   if(isBearish && limitPrice <= ask) return;
   if(!isBearish && limitPrice >= bid) return;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action   = TRADE_ACTION_PENDING;
   req.symbol   = _Symbol;
   req.volume   = NormalizeVolumeForSymbol(0.01);
   req.magic    = InpMagicNumber;
   req.price    = limitPrice;

   if(isBearish)
   {
      req.type  = ORDER_TYPE_SELL_LIMIT;
      req.sl    = NormalizeDouble(limitPrice + atrVal * DOW_SL_ATRMULT, dg);
      req.tp    = NormalizeDouble(limitPrice - atrVal * DOW_TP_ATRMULT, dg);
      req.comment = "DOW SELL LIMIT";
   }
   else
   {
      req.type  = ORDER_TYPE_BUY_LIMIT;
      req.sl    = NormalizeDouble(limitPrice - atrVal * DOW_SL_ATRMULT, dg);
      req.tp    = NormalizeDouble(limitPrice + atrVal * DOW_TP_ATRMULT, dg);
      req.comment = "DOW BUY LIMIT";
   }

   if(isBearish && req.price <= ask) return;
   if(!isBearish && req.price >= bid) return;

   if(!CanPlaceLimitOrder(_Symbol, req.type)) return;

   if(trade.OrderSend(req, res))
   {
      g_dowState.limitPlacedAt = TimeCurrent();
      g_dowState.lastChaseAt = 0;
      g_dowState.chasingEma = false;
      g_dowState.limitTicket = res.order;
      Print("📈 DOW ", (isBearish ? "SELL" : "BUY"), " LIMIT @ ", req.price,
            " (prix actuel trendline) | SL=", req.sl, " | TP=", req.tp);
   }
   else
      Print("❌ DOW LIMIT failed: ", res.retcode, " - ", res.comment);
}

//+------------------------------------------------------------------+
//| Nettoyage à la déconnexion                                      |
//+------------------------------------------------------------------+
void DowTrendline_Cleanup()
{
   Dow_CleanupChart();
   g_dowState.active = false;
   g_dowState.chasingEma = false;
   g_dowState.limitTicket = 0;
   g_dowState.limitPlacedAt = 0;
   g_dowState.lastChaseAt = 0;
   g_dowState.broken = false;
   g_dowState.candlesSinceBreak = 0;
   g_dowState.lastBreakTime = 0;
   g_dowState.lastRefreshTime = 0;
}

#endif // SMC_DOWTRENDLINE_MQH

// force recompile
