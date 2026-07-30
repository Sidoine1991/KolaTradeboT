//+------------------------------------------------------------------+
//| SMC_DowTrendline.mqh — Trendline Dow + Limit Orders              |
//| Détecte les lower highs (Crash/Painx) ou higher lows (Boom/Gainx)|
//| Trace la trendline de Dow, projette le prochain touch, place     |
//| un ordre LIMIT au niveau projeté.                                |
//+------------------------------------------------------------------+
#ifndef SMC_DOWTRENDLINE_MQH
#define SMC_DOWTRENDLINE_MQH

#include "SMC_SignalGates.mqh"
#include "SMC_GOM_Pipeline.mqh"

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
#define DOW_MODIFY_MIN_PTS      5     // Nb points min pour modifier un LIMIT existant (éviter micro-modifs)
#define DOW_MANAGE_COOLDOWN_SEC 120   // Minimum entre chaque gestion (modif/suppression) d'un LIMIT DOW

//--- Chase EMA : si LIMIT DOW jamais touché en haute vol → rebaser sur EMA fast ---
#define DOW_STALE_SEC           600   // Âge min avant suppression (10 min, était 5 min)
#define DOW_STALE_ATR           1.2   // Distance min prix↔LIMIT (x ATR) pour stale
#define DOW_EMA_FAST_PERIOD     8     // EMA fast M1
#define DOW_CHASE_OFFSET_ATR    0.15  // Offset LIMIT vs EMA (x ATR)
#define DOW_CHASE_REFRESH_SEC   15    // Intervalle min entre re-modifications chase
#define DOW_CHASE_MIN_MOVE_PTS  2     // Ignore modify si delta < N points

//--- Refresh après cassure ---
#define DOW_BREAK_REFRESH_CANDLES 10    // Bougies après cassure → refresh trendline
#define DOW_BREAK_CHECK_BARS      5     // Barres M1 à gauche/droite pour confirmer cassure
#define DOW_BREAK_ATR_MULT        1.5   // Mult. ATR pour tolérance cassure (wick vs vrai breakout)
#define DOW_BREAK_CONSEC_REQUIRED 2     // Consecutif de cassures requis pour confirmer

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
     datetime limitLastManaged;// Timestamp dernière gestion (modif/suppression)
     datetime lastChaseAt;     // Dernier modify chase
     datetime limitRemovedAt;  // Timestamp dernière suppression (anti place/delete)
     bool     chasingEma;      // true = LIMIT rebasé sur EMA fast
      ulong    limitTicket;     // Ticket LIMIT suivi
       // EP LIMIT (entrée retracement niveau EP)
       double   currentEpPrice;   // Prix EP courant (mid)
       datetime epLastTouchTime;  // Timestamp dernier touché EP
       double   epTouchPrice;     // Prix EP au moment du touché
        datetime epTouchBarTime;   // Temps d'ouverture de la bougie de touché
       ulong    epLimitTicket;    // Ticket EP LIMIT
        // Gestion cassure + refresh
        bool     broken;           // true = trendline cassée
        int      candlesSinceBreak;// Nb bougies depuis la cassure
        int      brokenBreakCount;  // Nb cassures consécutives confirmées
        datetime lastBreakTime;    // Timestamp de la cassure
        datetime lastRefreshTime;  // Dernier refresh trendline
        // DOW reentry tracking
        datetime lastDowEntryTime; // Timestamp dernière entrée DOW
        string   lastDowEntryDir;  // "BUY" ou "SELL"
        double   lastDowEntryPrice;// Prix entrée DOW
        bool     lastDowWasWin;    // true si dernier trade DOW gagnant
        int      dowReentryCount;  // Nb reentries sur cette trendline
};

DowTrendlineState g_dowState;

//--- Pattern Forecast State (from /ml/pattern-forecast) ---
#define PATTERN_FORECAST_CACHE_SEC  300   // Cache 5 min entre chaque appel serveur
#define PATTERN_FORECAST_SPIKE_BLOCK 0.7  // Spike prob > ce seuil → BLOCK trade
#define PATTERN_FORECAST_DIR_BLOCK   0.6  // Direction conflict + confidence > ce seuil → BLOCK

struct PatternForecastState
{
    bool     valid;              // Données valides reçues
    string   direction;          // "BUY", "SELL", "NEUTRAL"
    double   spikeProbability;   // 0.0 - 1.0
    int      spikeExpectedBar;   // Bar index où le spike est attendu (-1 = inconnu)
    double   spikeMagnitudeAtr;  // Magnitude du spike attendu (x ATR)
    double   confidence;         // 0.0 - 1.0
    double   confidencePct;      // 0-100
    double   patternQuality;     // 0.0 - 1.0
    datetime lastFetchTime;      // Timestamp dernier appel serveur
    string   symbol;             // Symbole pour lequel le forecast a été fait
    //--- Projected path (from "projected_path" JSON array)
    int      pathCount;          // Nombre de points dans le path projeté
    double   pathPrices[];       // Prix projetés
    double   pathHighs[];        // Highs projetés
    double   pathLows[];         // Lows projetés
};

PatternForecastState g_patternForecast;

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
//| Recupere la trendline DOW depuis le serveur AI                   |
//+------------------------------------------------------------------+
bool Dow_FetchTrendlineFromServer()
{
   if(!UseDowTrendline || !UseAIServer) return false;

   string sym = _Symbol;
   string symType = "";
   string symUpper = _Symbol;
   StringToUpper(symUpper);
   if(StringFind(symUpper, "BOOM") >= 0 || StringFind(symUpper, "GAINX") >= 0)
      symType = "bullish";
   else if(StringFind(symUpper, "CRASH") >= 0 || StringFind(symUpper, "PAINX") >= 0)
      symType = "bearish";

   string body = StringFormat(
      "{\"symbol\":\"%s\",\"symbol_type\":\"%s\"}",
      SMCGP_JsonEscape(sym), symType);

   string resp;
   if(!SMCGP_HttpPostWithResponse("/mt5/dow-trendline", body, resp, 5000))
      return false;
   if(!SMCGP_JsonBool(resp, "ok")) return false;
   if(!SMCGP_JsonBool(resp, "active")) return false;

   double atrArr[];
   ArraySetAsSeries(atrArr, true);
   int atrH = iATR(_Symbol, PERIOD_M1, 14);
   double atrVal = 0;
   if(atrH != INVALID_HANDLE && CopyBuffer(atrH, 0, 0, 1, atrArr) >= 1)
      atrVal = atrArr[0];
   if(atrVal <= 0) atrVal = 0.0001;

   bool isBearish = SMCGP_JsonBool(resp, "is_bearish");
   double p0 = SMCGP_JsonDouble(resp, "start_price");
   double p1 = SMCGP_JsonDouble(resp, "end_price");
   double slope = SMCGP_JsonDouble(resp, "slope");
   double projPrice = SMCGP_JsonDouble(resp, "projected_price");
   datetime t0 = (datetime)SMCGP_JsonDouble(resp, "start_time");
   datetime t1 = (datetime)SMCGP_JsonDouble(resp, "end_time");
   datetime projTime = (datetime)SMCGP_JsonDouble(resp, "projected_time");

   if(p0 <= 0 || p1 <= 0 || t0 <= 0 || t1 <= 0) return false;

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
   g_dowState.broken = Dow_IsTrendlineBroken(_Symbol, isBearish);

    Print("[DOW] Server trendline: ", (isBearish ? "SELL" : "BUY"),
         " p0=", p0, " p1=", p1, " slope=", slope,
         " proj=", projPrice, " broken=", g_dowState.broken);
    return true;
}

//+------------------------------------------------------------------+
//| Recupere le Pattern Forecast depuis le serveur AI                |
//| Appelle POST /ml/pattern-forecast — cache 5 min                  |
//+------------------------------------------------------------------+
bool Dow_FetchPatternForecast()
{
   if(!UseDowTrendline || !UseAIServer) return false;

   // Cache: ne pas re-appeler avant PATTERN_FORECAST_CACHE_SEC
   if(g_patternForecast.valid && g_patternForecast.symbol == _Symbol)
   {
      if(TimeCurrent() - g_patternForecast.lastFetchTime < PATTERN_FORECAST_CACHE_SEC)
         return true;
   }

   string sym = _Symbol;
   string body = StringFormat(
      "{\"symbol\":\"%s\",\"horizon\":500,\"top_k\":5,\"lookback\":5000}",
      SMCGP_JsonEscape(sym));

   string resp;
   if(!SMCGP_HttpPostWithResponse("/ml/pattern-forecast", body, resp, 8000))
   {
      // Serveur indisponible → conserver le dernier forecast valide
      return g_patternForecast.valid;
   }
   if(!SMCGP_JsonBool(resp, "ok"))
   {
      string err = SMCGP_JsonString(resp, "error");
      if(TimeCurrent() - g_patternForecast.lastFetchTime > PATTERN_FORECAST_CACHE_SEC * 2)
         Print("[DOW-PATTERN] Forecast nok: ", err);
      return g_patternForecast.valid;
   }

   g_patternForecast.valid = true;
   g_patternForecast.symbol = sym;
   g_patternForecast.lastFetchTime = TimeCurrent();
   g_patternForecast.direction = SMCGP_JsonString(resp, "consensus_direction");
   g_patternForecast.spikeProbability = SMCGP_JsonDouble(resp, "spike_probability", 0.0);
   g_patternForecast.spikeExpectedBar = (int)SMCGP_JsonDouble(resp, "spike_expected_bar", -1);
   g_patternForecast.spikeMagnitudeAtr = SMCGP_JsonDouble(resp, "spike_magnitude_atr", 0.0);
   g_patternForecast.confidence = SMCGP_JsonDouble(resp, "confidence", 0.0);
   g_patternForecast.confidencePct = SMCGP_JsonDouble(resp, "confidence_pct", 0.0);
   g_patternForecast.patternQuality = SMCGP_JsonDouble(resp, "pattern_quality", 0.0);

    Print("[DOW-PATTERN] Forecast: dir=", g_patternForecast.direction,
          " spike=", DoubleToString(g_patternForecast.spikeProbability * 100, 1), "%",
          " bar=", g_patternForecast.spikeExpectedBar,
          " conf=", DoubleToString(g_patternForecast.confidencePct, 1), "%",
          " qual=", DoubleToString(g_patternForecast.patternQuality * 100, 1), "%");

    //--- Parse projected_path array of objects [{"bar":N,"price":X,"high":Y,"low":Z},...]
    g_patternForecast.pathCount = 0;
    ArrayFree(g_patternForecast.pathPrices);
    ArrayFree(g_patternForecast.pathHighs);
    ArrayFree(g_patternForecast.pathLows);
    {
       int pos = StringFind(resp, "\"projected_path\"");
       if(pos >= 0)
       {
          int arrStart = StringFind(resp, "[", pos);
          int arrEnd   = StringFind(resp, "]", arrStart);
          if(arrStart >= 0 && arrEnd > arrStart)
          {
             string arrBody = StringSubstr(resp, arrStart + 1, arrEnd - arrStart - 1);
             int cur = 0;
             int len = StringLen(arrBody);
             while(cur < len)
             {
                int objStart = StringFind(arrBody, "{", cur);
                if(objStart < 0) break;
                int objEnd = StringFind(arrBody, "}", objStart);
                if(objEnd < 0) break;
                string obj = StringSubstr(arrBody, objStart + 1, objEnd - objStart - 1);

                // Extraire "price":X
                double price = 0, hi = 0, lo = 0;
                int pPos = StringFind(obj, "\"price\"");
                if(pPos >= 0)
                {
                   int colon = StringFind(obj, ":", pPos);
                   int comma = StringFind(obj, ",", colon);
                   if(comma < 0) comma = StringLen(obj);
                   price = StringToDouble(StringSubstr(obj, colon + 1, comma - colon - 1));
                }
                // Extraire "high":Y
                int hPos = StringFind(obj, "\"high\"");
                if(hPos >= 0)
                {
                   int colon = StringFind(obj, ":", hPos);
                   int comma = StringFind(obj, ",", colon);
                   if(comma < 0) comma = StringLen(obj);
                   hi = StringToDouble(StringSubstr(obj, colon + 1, comma - colon - 1));
                }
                // Extraire "low":Z
                int lPos = StringFind(obj, "\"low\"");
                if(lPos >= 0)
                {
                   int colon = StringFind(obj, ":", lPos);
                   int comma = StringFind(obj, ",", colon);
                   if(comma < 0) comma = StringLen(obj);
                   lo = StringToDouble(StringSubstr(obj, colon + 1, comma - colon - 1));
                }

                if(price > 0)
                {
                   ArrayResize(g_patternForecast.pathPrices, g_patternForecast.pathCount + 1);
                   ArrayResize(g_patternForecast.pathHighs,  g_patternForecast.pathCount + 1);
                   ArrayResize(g_patternForecast.pathLows,   g_patternForecast.pathCount + 1);
                   g_patternForecast.pathPrices[g_patternForecast.pathCount] = price;
                   g_patternForecast.pathHighs[g_patternForecast.pathCount]  = (hi > 0) ? hi : price;
                   g_patternForecast.pathLows[g_patternForecast.pathCount]   = (lo > 0) ? lo : price;
                   g_patternForecast.pathCount++;
                }

                cur = objEnd + 1;
             }
          }
       }
       if(g_patternForecast.pathCount > 0)
          Print("[DOW-PATTERN] Projected path parsed: ", g_patternForecast.pathCount, " points");
    }
   return true;
}

//+------------------------------------------------------------------+
//| Dessine le forecast pattern sur le graphique                     |
//| Coin supérieur droit — info compacte                              |
//+------------------------------------------------------------------+
void Dow_DrawPatternForecast()
{
   if(!g_patternForecast.valid) return;

   string prefix = "DOW_PAT_";

   // Couleur selon la direction
   color dirColor = clrGray;
   string dirText = "---";
   if(g_patternForecast.direction == "BUY")
   { dirColor = clrDodgerBlue; dirText = "▲ BUY"; }
   else if(g_patternForecast.direction == "SELL")
   { dirColor = clrCrimson; dirText = "▼ SELL"; }
   else
   { dirColor = clrGray; dirText = "● NEUTRAL"; }

   // Spike color
   color spikeColor = clrGray;
   if(g_patternForecast.spikeProbability >= PATTERN_FORECAST_SPIKE_BLOCK)
      spikeColor = clrRed;
   else if(g_patternForecast.spikeProbability >= 0.5)
      spikeColor = clrOrange;
   else
      spikeColor = clrLime;

   // Ligne 1: Direction + Confidence
   string line1 = "PAT: " + dirText + "  conf=" + DoubleToString(g_patternForecast.confidencePct, 0) + "%";
   ObjectCreate(0, prefix + "L1", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix + "L1", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefix + "L1", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, prefix + "L1", OBJPROP_YDISTANCE, 20);
   ObjectSetString(0, prefix + "L1", OBJPROP_TEXT, line1);
   ObjectSetString(0, prefix + "L1", OBJPROP_FONT, "Consolas Bold");
   ObjectSetInteger(0, prefix + "L1", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, prefix + "L1", OBJPROP_COLOR, dirColor);

   // Ligne 2: Spike prob + bar + magnitude
   string spikeStr = DoubleToString(g_patternForecast.spikeProbability * 100, 1) + "%";
   if(g_patternForecast.spikeExpectedBar >= 0)
      spikeStr += " ~" + IntegerToString(g_patternForecast.spikeExpectedBar) + " bars";
   if(g_patternForecast.spikeMagnitudeAtr > 0)
      spikeStr += " (" + DoubleToString(g_patternForecast.spikeMagnitudeAtr, 1) + "xATR)";
   string line2 = "SPIKE: " + spikeStr;
   ObjectCreate(0, prefix + "L2", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix + "L2", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefix + "L2", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, prefix + "L2", OBJPROP_YDISTANCE, 38);
   ObjectSetString(0, prefix + "L2", OBJPROP_TEXT, line2);
   ObjectSetString(0, prefix + "L2", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, prefix + "L2", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, prefix + "L2", OBJPROP_COLOR, spikeColor);

   // Ligne 3: Quality + block status
   bool blocked = Dow_PatternForecastBlocksTrade();
   string line3 = "QUAL: " + DoubleToString(g_patternForecast.patternQuality * 100, 0) + "%";
   if(blocked)
      line3 += "  ⛔ BLOCKED";
   string blockReason = "";
   if(g_patternForecast.spikeProbability >= PATTERN_FORECAST_SPIKE_BLOCK && g_patternForecast.spikeExpectedBar >= 0 && g_patternForecast.spikeExpectedBar < 30)
      blockReason = "spike imminent";
   else if(g_patternForecast.direction != "NEUTRAL")
   {
      string symUpper = _Symbol;
      StringToUpper(symUpper);
      bool isBearishSym = (StringFind(symUpper, "CRASH") >= 0 || StringFind(symUpper, "PAINX") >= 0);
      bool dirConflict = (isBearishSym && g_patternForecast.direction == "BUY") ||
                         (!isBearishSym && g_patternForecast.direction == "SELL");
      if(dirConflict && g_patternForecast.confidence >= PATTERN_FORECAST_DIR_BLOCK)
         blockReason = "dir conflict";
   }
   if(StringLen(blockReason) > 0)
      line3 += " (" + blockReason + ")";

   ObjectCreate(0, prefix + "L3", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix + "L3", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefix + "L3", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, prefix + "L3", OBJPROP_YDISTANCE, 54);
    ObjectSetString(0, prefix + "L3", OBJPROP_TEXT, line3);
    ObjectSetString(0, prefix + "L3", OBJPROP_FONT, "Consolas");
    ObjectSetInteger(0, prefix + "L3", OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, prefix + "L3", OBJPROP_COLOR, blocked ? clrRed : clrDarkGray);

    //--- Dessiner la trajectoire projetée sur le chart
    Dow_DrawPatternForecastPath();
}

//+------------------------------------------------------------------+
//| Dessine la trajectoire projetée (projected_path) sur le chart    |
//| Segments trend: prix central + bandes high/low transparentes     |
//+------------------------------------------------------------------+
void Dow_DrawPatternForecastPath()
{
   if(g_patternForecast.pathCount < 2) return;

   string pathPrefix = "DOW_PAT_PATH_";

   // Couleur selon direction
   color pathColor = clrGray;
   if(g_patternForecast.direction == "BUY")
      pathColor = clrDodgerBlue;
   else if(g_patternForecast.direction == "SELL")
      pathColor = clrCrimson;

   datetime t0 = iTime(_Symbol, PERIOD_M1, 0);
   int stepSec = PeriodSeconds(PERIOD_M1);

   //--- Downsampling: max 60 segments visuels (tous les N points)
   int n = g_patternForecast.pathCount;
   int skip = (n > 60) ? n / 60 : 1;

   //--- Segment principal (prix central)
   int segIdx = 0;
   for(int i = 0; i < n - 1; i += skip)
   {
      int next = (i + skip < n) ? i + skip : n - 1;
      string segName = pathPrefix + "seg_" + IntegerToString(segIdx);
      datetime t1 = t0 + (i + 1) * stepSec;
      datetime t2 = t0 + (next + 1) * stepSec;
      ObjectDelete(0, segName);
      ObjectCreate(0, segName, OBJ_TREND, 0, t1, g_patternForecast.pathPrices[i],
                   t2, g_patternForecast.pathPrices[next]);
      ObjectSetInteger(0, segName, OBJPROP_COLOR, pathColor);
      ObjectSetInteger(0, segName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, segName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, segName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, segName, OBJPROP_BACK, true);
      ObjectSetString(0, segName, OBJPROP_TOOLTIP,
                      "PAT projected: " + DoubleToString(g_patternForecast.pathPrices[next], _Digits));
      segIdx++;
   }

   //--- Bandes high/low (même downsampling)
   int bandIdx = 0;
   for(int i = 0; i < n - 1; i += skip)
   {
      int next = (i + skip < n) ? i + skip : n - 1;
      datetime t1 = t0 + (i + 1) * stepSec;
      datetime t2 = t0 + (next + 1) * stepSec;

      string hiName = pathPrefix + "hi_" + IntegerToString(bandIdx);
      ObjectDelete(0, hiName);
      ObjectCreate(0, hiName, OBJ_TREND, 0, t1, g_patternForecast.pathHighs[i],
                   t2, g_patternForecast.pathHighs[next]);
      ObjectSetInteger(0, hiName, OBJPROP_COLOR, clrDarkGray);
      ObjectSetInteger(0, hiName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, hiName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, hiName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, hiName, OBJPROP_BACK, true);

      string loName = pathPrefix + "lo_" + IntegerToString(bandIdx);
      ObjectDelete(0, loName);
      ObjectCreate(0, loName, OBJ_TREND, 0, t1, g_patternForecast.pathLows[i],
                   t2, g_patternForecast.pathLows[next]);
      ObjectSetInteger(0, loName, OBJPROP_COLOR, clrDarkGray);
      ObjectSetInteger(0, loName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, loName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, loName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, loName, OBJPROP_BACK, true);

      bandIdx++;
   }

   //--- Point final (flèche direction)
   string arrowName = pathPrefix + "arrow";
   datetime tArrow = t0 + (n + 1) * stepSec;
   double lastPrice = g_patternForecast.pathPrices[n - 1];
   ObjectDelete(0, arrowName);
   ObjectCreate(0, arrowName, OBJ_ARROW, 0, tArrow, lastPrice);
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR, pathColor);
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE,
                    g_patternForecast.direction == "BUY" ? 233 : 234);
   ObjectSetInteger(0, arrowName, OBJPROP_BACK, true);
   ObjectSetString(0, arrowName, OBJPROP_TOOLTIP,
                   "PAT projected end: " + DoubleToString(lastPrice, _Digits));

   //--- Label prix final
   string lblName = pathPrefix + "lbl";
   ObjectDelete(0, lblName);
   ObjectCreate(0, lblName, OBJ_TEXT, 0, tArrow, lastPrice);
   ObjectSetString(0, lblName, OBJPROP_TEXT,
                   DoubleToString(lastPrice, _Digits));
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, pathColor);
   ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, lblName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Supprime les objets graphiques du pattern forecast               |
//+------------------------------------------------------------------+
void Dow_CleanupPatternForecast()
{
   string prefix = "DOW_PAT_";
   ObjectDelete(0, prefix + "L1");
   ObjectDelete(0, prefix + "L2");
   ObjectDelete(0, prefix + "L3");
   //--- Path segments (max 60 after downsampling)
   string pathPrefix = "DOW_PAT_PATH_";
   for(int i = 0; i < 60; i++)
   {
      ObjectDelete(0, pathPrefix + "seg_" + IntegerToString(i));
      ObjectDelete(0, pathPrefix + "hi_" + IntegerToString(i));
      ObjectDelete(0, pathPrefix + "lo_" + IntegerToString(i));
   }
   ObjectDelete(0, pathPrefix + "arrow");
   ObjectDelete(0, pathPrefix + "lbl");
}

//+------------------------------------------------------------------+
//| Verifie si le pattern forecast doit bloquer le trade             |
//| Retourne true si le trade doit être bloqué (hard block)          |
//+------------------------------------------------------------------+
bool Dow_PatternForecastBlocksTrade()
{
    if(!g_patternForecast.valid) return false;

    // BYPASS GOM PERFECT: quand le verdict GOM est PERFECT (|vn| >= 3)
    // et que le symbole est Boom/Crash, on suit le GOM et on ne bloque pas.
    if(g_smcGomVerdictNum >= 3 || g_smcGomVerdictNum <= -3)
    {
       string symUpper = _Symbol;
       StringToUpper(symUpper);
       if(StringFind(symUpper, "BOOM") >= 0 || StringFind(symUpper, "CRASH") >= 0 ||
          StringFind(symUpper, "PAINX") >= 0 || StringFind(symUpper, "GAINX") >= 0)
       {
          return false;
       }
    }

    // Blocage 1: Spike imminent (prob > 0.7 et attendu dans < 30 barres)
   if(g_patternForecast.spikeProbability >= PATTERN_FORECAST_SPIKE_BLOCK)
   {
      if(g_patternForecast.spikeExpectedBar >= 0 && g_patternForecast.spikeExpectedBar < 30)
      {
         static datetime s_lastSpikeBlock = 0;
         if(TimeCurrent() - s_lastSpikeBlock >= 60)
         {
            Print("[DOW-PATTERN] ⛔ BLOCKED — spike imminent: ",
                  DoubleToString(g_patternForecast.spikeProbability * 100, 1), "%",
                  " at bar ", g_patternForecast.spikeExpectedBar);
            s_lastSpikeBlock = TimeCurrent();
         }
         return true;
      }
   }

   // Blocage 2: Direction conflict avec le symbole
   if(g_patternForecast.direction != "NEUTRAL" && g_patternForecast.confidence >= PATTERN_FORECAST_DIR_BLOCK)
   {
      string symUpper = _Symbol;
      StringToUpper(symUpper);
      bool isBearishSym = (StringFind(symUpper, "CRASH") >= 0 || StringFind(symUpper, "PAINX") >= 0);
      bool dirConflict = (isBearishSym && g_patternForecast.direction == "BUY") ||
                         (!isBearishSym && g_patternForecast.direction == "SELL");
      if(dirConflict)
      {
         static datetime s_lastDirBlock = 0;
         if(TimeCurrent() - s_lastDirBlock >= 60)
         {
            Print("[DOW-PATTERN] ⛔ BLOCKED — direction conflict: pattern=",
                  g_patternForecast.direction, " vs symbol=",
                  (isBearishSym ? "BEARISH" : "BULLISH"),
                  " conf=", DoubleToString(g_patternForecast.confidencePct, 1), "%");
            s_lastDirBlock = TimeCurrent();
         }
         return true;
      }
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
//| Vérifie si un reentry DOW est autorisé après TP1/perte           |
//+------------------------------------------------------------------+
bool SMC_DOWReentryAllowed(const string symbol, int dirSign, double &reentryPrice)
{
   reentryPrice = 0;
   if(!UseDowTrendline) return false;
   if(dirSign == 0) return false;
   
   // Vérifier si on a eu un entry DOW récemment
   if(g_dowState.lastDowEntryTime == 0) return false;
   
   // Cooldown 30s minimum entre entries
   if(TimeCurrent() - g_dowState.lastDowEntryTime < 30) return false;
   
   // Max 2 reentries par activation DOW
   if(g_dowState.dowReentryCount >= 2) return false;
   
   // Vérifier la direction
   if(dirSign > 0 && g_dowState.lastDowEntryDir != "BUY") return false;
   if(dirSign < 0 && g_dowState.lastDowEntryDir != "SELL") return false;
   
   // Vérifier si le prix est revenu sur la trendline (±10% ATR tolérance)
   double atrVal = g_dowState.currentATR;
   if(atrVal <= 0) return false;
   
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double trendPrice = g_dowState.projectedPrice;
   if(trendPrice <= 0) return false;
   
   double dist = MathAbs(currentPrice - trendPrice);
   if(dist > atrVal * 0.5) return false; // Trop loin de la trendline
   
   reentryPrice = trendPrice;
   return true;
}

//+------------------------------------------------------------------+
//| Vérifie si un reentry EMA 23/25/28 est autorisé                  |
//+------------------------------------------------------------------+
bool SMC_EMAReentryAllowed(const string symbol, int dirSign, double &reentryPrice)
{
   reentryPrice = 0;
   if(dirSign == 0) return false;
   
   // Récupérer les EMA 23, 25, 28 sur M1
   double ema23 = 0, ema25 = 0, ema28 = 0;
   int h23 = iMA(symbol, PERIOD_M1, 23, 0, MODE_EMA, PRICE_CLOSE);
   int h25 = iMA(symbol, PERIOD_M1, 25, 0, MODE_EMA, PRICE_CLOSE);
   int h28 = iMA(symbol, PERIOD_M1, 28, 0, MODE_EMA, PRICE_CLOSE);
   
   if(h23 != INVALID_HANDLE) { double buf[]; ArraySetAsSeries(buf, true); if(CopyBuffer(h23, 0, 0, 1, buf) >= 1) ema23 = buf[0]; IndicatorRelease(h23); }
   if(h25 != INVALID_HANDLE) { double buf[]; ArraySetAsSeries(buf, true); if(CopyBuffer(h25, 0, 0, 1, buf) >= 1) ema25 = buf[0]; IndicatorRelease(h25); }
   if(h28 != INVALID_HANDLE) { double buf[]; ArraySetAsSeries(buf, true); if(CopyBuffer(h28, 0, 0, 1, buf) >= 1) ema28 = buf[0]; IndicatorRelease(h28); }
   
   if(ema23 <= 0 && ema25 <= 0 && ema28 <= 0) return false;
   
   // Trouver l'EMA la plus proche du prix
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double closestEma = 0;
   double minDist = 999999;
   
   if(ema23 > 0 && MathAbs(currentPrice - ema23) < minDist) { minDist = MathAbs(currentPrice - ema23); closestEma = ema23; }
   if(ema25 > 0 && MathAbs(currentPrice - ema25) < minDist) { minDist = MathAbs(currentPrice - ema25); closestEma = ema25; }
   if(ema28 > 0 && MathAbs(currentPrice - ema28) < minDist) { minDist = MathAbs(currentPrice - ema28); closestEma = ema28; }
   
   if(closestEma <= 0) return false;
   
   // Vérifier la tolérance (±0.5 ATR)
   double atrVal = iATR(symbol, PERIOD_M1, 14);
   if(atrVal <= 0) return false;
   
   double dist = MathAbs(currentPrice - closestEma);
   if(dist > atrVal * 0.5) return false;
   
   // Vérifier l'alignement de tendance
   if(dirSign > 0 && currentPrice < closestEma) return false; // BUY mais prix sous EMA
   if(dirSign < 0 && currentPrice > closestEma) return false; // SELL mais prix au-dessus EMA
   
   reentryPrice = closestEma;
   return true;
}

//+------------------------------------------------------------------+
//| Initialise le module                                             |
//+------------------------------------------------------------------+
void DowTrendline_Init()
{
    g_dowState.active = false;
    g_dowState.projectedPrice = 0;
    g_dowState.limitPlacedAt = 0;
    g_dowState.limitLastManaged = 0;
    g_dowState.lastChaseAt = 0;
    g_dowState.chasingEma = false;
    g_dowState.limitTicket = 0;
    g_dowState.lastDowEntryTime = 0;
    g_dowState.lastDowEntryDir = "";
    g_dowState.lastDowEntryPrice = 0;
    g_dowState.lastDowWasWin = false;
    g_dowState.dowReentryCount = 0;
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
      string cm = OrderGetString(ORDER_COMMENT);
      if(StringFind(cm, "DOW") >= 0 && StringFind(cm, "DOW EP") < 0)
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

//--- Paramètres de tolérance pour les ordres LIMIT
#define DOW_LIMIT_MIN_LIFETIME_SEC   30   // Durée minimale avant pouvoir annuler
#define DOW_LIMIT_MAX_DIST_ATR       1.5  // Distance max ATR pour maintenir le LIMIT
#define DOW_LIMIT_STABILITY_BARS     3    // Nb de bougies avant de considérer stable

//+------------------------------------------------------------------+
//| Valide qu'un LIMIT DOW est bien placé avant envoi                  |
//+------------------------------------------------------------------+
bool Dow_ValidateLimitPlacement(const double limitPrice, const bool isBearish, const double atrVal)
{
   if(limitPrice <= 0 || atrVal <= 0) return false;
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return false;
   
   // 1) Prix actuel doit être à distance raisonnable du LIMIT
   double distToLimit = isBearish ? (limitPrice - ask) : (bid - limitPrice);
   if(distToLimit < 0) return false; // LIMIT du mauvais côté du marché
   
   // 2) Distance max 2 ATR (sinon trop loin, risque de ne jamais être rempli)
   if(distToLimit > atrVal * 2.0) return false;
   
   // 3) Vérifier que la trendline est toujours valide
   if(!g_dowState.active) return false;
   
   // 4) Vérifier cohérence GOM (au moins GOOD pour Boom/Crash, PERFECT pour autres)
   if(!g_smcGomConnected) return false;
   int vn = g_smcGomVerdictNum;
   if(MathAbs(vn) < 2) return false; // Trop faible pour placer un LIMIT
   
   // 5) Direction GOM alignée avec DOW
   if(isBearish && vn > 0) return false;
   if(!isBearish && vn < 0) return false;
   
   // 6) Vérifier que le spread est raisonnable (< 50% ATR)
   double spread = ask - bid;
   if(spread > atrVal * 0.5) return false;
   
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
    g_dowState.limitLastManaged = TimeCurrent();
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

if(SafeSafeOrderSend(req, res))
    {
       g_dowState.chasingEma = true;
       g_dowState.lastChaseAt = TimeCurrent();
       g_dowState.limitTicket = ticket;
       g_dowState.limitLastManaged = TimeCurrent();
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

    double atrVal = g_dowState.currentATR;
    if(atrVal <= 0) atrVal = SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID);
    if(atrVal <= 0) atrVal = _Point * 10;

    double tolerance = atrVal * DOW_BREAK_ATR_MULT;
    int breakCount = 0;

    for(int i = 0; i < bars - 1; i++)
    {
        double tDelta = (double)(rates[i].time - g_dowState.endTime);
        double tlPrice = g_dowState.endPrice + g_dowState.slope * tDelta;
        bool isBroken = false;

        if(isBearish)
        {
            // Trendline baissière → cassée si close dépasse tlPrice de plus de la tolérance ATR
            if(rates[i].close > tlPrice + tolerance)
                isBroken = true;
        }
        else
        {
            // Trendline haussière → cassée si close descend sous tlPrice de plus de la tolérance ATR
            if(rates[i].close < tlPrice - tolerance)
                isBroken = true;
        }

        if(isBroken)
           breakCount++;
    }

    // Il faut DOW_BREAK_CONSEC_REQUIRED cassures sur les DOW_BREAK_CHECK_BARS pour confirmer
    bool isBroken = (breakCount >= DOW_BREAK_CONSEC_REQUIRED);
    if(isBroken)
       g_dowState.brokenBreakCount++;
    else
       g_dowState.brokenBreakCount = 0;
    return isBroken;
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
#define DOW_TouchGraceSec 3          // fenêtre de grâce (sec) après un passage proche de la TL

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
   if(selectedCount < 2) return;

   // ── GOM PERFECT obligatoire (|vn|>=3, pas GOOD) ──
   int vn = g_smcGomConnected ? g_smcGomVerdictNum : 0;
   if(MathAbs(vn) < 3)
   {
      static datetime s_lastAlignLog = 0;
      if(TimeCurrent() - s_lastAlignLog >= 30)
      {
         s_lastAlignLog = TimeCurrent();
         Print("[DOW→MARKET] GOM non PERFECT vn=", vn, " (exige |vn|>=3) → skip MARKET");
      }
      return;
   }
   // ── Direction GOM alignée avec DOW ──
   bool gomAligned = (!isBearish && vn >= 3) || (isBearish && vn <= -3);
   if(!gomAligned)
   {
      static datetime s_lastAlignLog2 = 0;
      if(TimeCurrent() - s_lastAlignLog2 >= 30)
      {
         s_lastAlignLog2 = TimeCurrent();
         Print("[DOW→MARKET] GOM PERFECT mais direction ≠ DOW=", (isBearish ? "SELL" : "BUY"),
               " vn=", vn);
      }
      return;
   }

    // ── BLINK GATE : décision finale doit clignoter ~1.5s ──
    // PERFECT verdict (|vn|>=3) sur Boom/Crash : bypass blink gate pour capturer les spikes immédiatement
    bool isPerfectBypass = (MathAbs(vn) >= 3 && SMCGP_IsBoomCrashSym(_Symbol));
    if(!isPerfectBypass && !IsSignalConfirmed())
    {
       static datetime s_lastBlinkLog = 0;
       if(TimeCurrent() - s_lastBlinkLog >= 15) { Print("[DOW→MARKET] blink non confirmé sur ", _Symbol); s_lastBlinkLog = TimeCurrent(); }
       return;
    }
    if(isPerfectBypass)
    {
       // Skip blink check but still verify direction
       int perfectDir = (vn > 0) ? 1 : -1;
       if((!isBearish && perfectDir != 1) || (isBearish && perfectDir != -1))
          return;
    }
    else
    {
       int blinkDir = GetConfirmedSignalDir();
       if((!isBearish && blinkDir != 1) || (isBearish && blinkDir != -1))
          return;
    }

   // Direction spike obligatoire (Boom/Gainx=BUY, Crash/Painx=SELL)
   string dirStr = isBearish ? "SELL" : "BUY";
   if(!IsDirectionAllowedForBoomCrash(_Symbol, dirStr))
   {
      Print("[DOW→MARKET] ", dirStr, " interdit sur ", _Symbol);
      return;
   }

   // Pas de position ouverte
   if(CountPositionsForSymbol(_Symbol) > 0) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(atrVal <= 0) return;

   double lot = CalculateLotSize();
   if(lot <= 0) return;

   if(!TryAcquireOpenLock()) return;

   bool ok = false;
   double tlPrice = g_dowState.endPrice + g_dowState.slope * (double)(TimeCurrent() - g_dowState.endTime);

   if(g_smcGomVerdictNum == 0)
   {
      ReleaseOpenLock();
      return;
   }

    if(!isBearish)
    {
       // SL/TP capital-aware: SL tolère max 2$ de perte, TP proportionnel
       double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
       double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
       double pricePerDollar = (tickVal * lot) / tickSz;
       double slDist = (pricePerDollar > 0) ? (2.0 / pricePerDollar) : atrVal * 1.0;
       slDist = NormalizeDouble(MathMax(slDist, tickSz * 2), dg);

       double sl = NormalizeDouble(ask - slDist, dg);
       double tp = NormalizeDouble(ask + slDist * DOW_TP_ATRMULT, dg);

       // EP zone comme référence d'entrée (DOW_BULL EP)
       double epRef = (g_dowState.currentEpPrice > 0) ? g_dowState.currentEpPrice : ask;
       MqlTradeRequest req = {};
       MqlTradeResult  res = {};
       req.action    = TRADE_ACTION_DEAL;
       req.symbol    = _Symbol;
       req.volume    = lot;
       req.type      = ORDER_TYPE_BUY;
       req.price     = ask;
       req.sl        = sl;
       req.tp        = tp;
       req.magic     = InpMagicNumber;
       req.deviation = 30;
        req.comment   = "DOW EP BUY";
        ok = SafeSafeSafeOrderSend(req, res, "DOW MARKET BUY") && res.retcode == TRADE_RETCODE_DONE;
        if(ok)
        {
           g_dowLastPerfectMarketEntry = TimeCurrent();
           g_dowState.lastDowEntryTime = TimeCurrent();
           g_dowState.lastDowEntryDir = "BUY";
           g_dowState.lastDowEntryPrice = ask;
           ulong ticket = res.order;
           if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
            string tsBuy = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
            Print("🚀 DOW MARKET BUY | Entry=", DoubleToString(ask, dg),
                 " EP=", DoubleToString(epRef, dg),
                 " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg),
                 " Lot=", DoubleToString(lot, 2), " vn=", vn, " ", tsBuy);
           if(UseNotifications)
              SendNotification("🚀 DOW BUY MARKET " + _Symbol +
                               " @ " + DoubleToString(ask, dg) +
                               " EP=" + DoubleToString(epRef, dg) +
                               " SL=" + DoubleToString(sl, dg) +
                               " TP=" + DoubleToString(tp, dg) +
                               " vn=" + IntegerToString(vn) +
                               " " + tsBuy);
       }
    }
    else
    {
       double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
       double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
       double pricePerDollar = (tickVal * lot) / tickSz;
       double slDist = (pricePerDollar > 0) ? (2.0 / pricePerDollar) : atrVal * 1.0;
       slDist = NormalizeDouble(MathMax(slDist, tickSz * 2), dg);

       double sl = NormalizeDouble(bid + slDist, dg);
       double tp = NormalizeDouble(bid - slDist * DOW_TP_ATRMULT, dg);

       // EP zone comme référence d'entrée (DOW_BEAR EP)
       double epRef = (g_dowState.currentEpPrice > 0) ? g_dowState.currentEpPrice : bid;
       MqlTradeRequest req = {};
       MqlTradeResult  res = {};
       req.action    = TRADE_ACTION_DEAL;
       req.symbol    = _Symbol;
       req.volume    = lot;
       req.type      = ORDER_TYPE_SELL;
       req.price     = bid;
       req.sl        = sl;
       req.tp        = tp;
       req.magic     = InpMagicNumber;
       req.deviation = 30;
        req.comment   = "DOW EP SELL";
        ok = SafeSafeSafeOrderSend(req, res, "DOW MARKET SELL") && res.retcode == TRADE_RETCODE_DONE;
        if(ok)
        {
           g_dowLastPerfectMarketEntry = TimeCurrent();
           g_dowState.lastDowEntryTime = TimeCurrent();
           g_dowState.lastDowEntryDir = "SELL";
           g_dowState.lastDowEntryPrice = bid;
           ulong ticket = res.order;
           if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
            string tsSell = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
            Print("🚀 DOW MARKET SELL | Entry=", DoubleToString(bid, dg),
                 " EP=", DoubleToString(epRef, dg),
                 " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg),
                 " Lot=", DoubleToString(lot, 2), " vn=", vn, " ", tsSell);
           if(UseNotifications)
              SendNotification("🚀 DOW SELL MARKET " + _Symbol +
                               " @ " + DoubleToString(bid, dg) +
                               " EP=" + DoubleToString(epRef, dg) +
                               " SL=" + DoubleToString(sl, dg) +
                               " TP=" + DoubleToString(tp, dg) +
                               " vn=" + IntegerToString(vn) +
                               " " + tsSell);
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

   // ── Pattern Forecast (cache 5 min) ──
   Dow_FetchPatternForecast();

   DowSwingPoint selected[];
   int selectedCount = 0;
   bool isBearish = false;
   bool trendOk = false;

   // ── Server DOW trendline en priorité ──
   if(Dow_FetchTrendlineFromServer())
   {
      isBearish = g_dowState.isBearish;
      trendOk = true;
   }
   else if(Dow_DetectTrend(_Symbol, isBearish, selected, selectedCount))
   {
      trendOk = true;
   }

   if(!trendOk)
   {
      if(g_dowState.active)
      {
         g_dowState.active = false;
         Dow_CleanupChart();
      }
      // ── Même sans trendline DOW, tenter re-entry sur zones cached ──
      Dow_ZoneReentryLimit();
      return;
   }

   datetime t0, t1;
   double p0, p1;

   // Si serveur a fourni les donnees, on les utilise directement
   if(g_dowState.active && g_dowState.startTime > 0)
   {
      t0 = g_dowState.startTime;
      p0 = g_dowState.startPrice;
      t1 = g_dowState.endTime;
      p1 = g_dowState.endPrice;
   }
   else
   {
      Dow_FitTrendline(selected, selectedCount, isBearish, t0, p0, t1, p1);
   }

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
    g_dowState.broken = Dow_IsTrendlineBroken(_Symbol, isBearish);

    if(g_dowState.broken)
    {
       Print("[DOW] Trendline cassée détectée | Direction=", (isBearish ? "BEARISH" : "BULLISH"),
             " | Prix actuel: ", DoubleToString(isBearish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits));
       g_dowState.active = false;
       Dow_CleanupChart();
       return;
    }

   // Dessin trendline + proj
   Dow_DrawTrendline(t0, p0, t1, p1, isBearish, projTime, projPrice);

   // ── Pattern Forecast display ──
   Dow_DrawPatternForecast();

    // Direction selon canal Dow
    if(isBearish)
    {
       if(!IsDirectionAllowedForBoomCrash(_Symbol, "SELL"))
       {
          static datetime s_lastDirBlock = 0;
          if(TimeCurrent() - s_lastDirBlock >= 30) { Print("[DOW] DIRECTION BLOQUÉE — SELL interdit sur ", _Symbol); s_lastDirBlock = TimeCurrent(); }
          return;
       }
    }
    else
    {
       if(!IsDirectionAllowedForBoomCrash(_Symbol, "BUY"))
       {
          static datetime s_lastDirBlock = 0;
          if(TimeCurrent() - s_lastDirBlock >= 30) { Print("[DOW] DIRECTION BLOQUÉE — BUY interdit sur ", _Symbol); s_lastDirBlock = TimeCurrent(); }
          return;
       }
    }

     // ── DÉTECTION CONTRE-TENDANCE: fermer la position opposée ──
     // Si un ordre contre-tendance s'exécute (positions dans les deux sens),
     // fermer la position qui va à l'encontre de la tendance DOW détectée.
     {
        bool hasLong = false, hasShort = false;
        ulong longTicket = 0, shortTicket = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
           ulong tk = PositionGetTicket(i);
           if(tk == 0) continue;
           if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
           if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
           if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           { hasLong = true; longTicket = tk; }
           else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
           { hasShort = true; shortTicket = tk; }
        }
        if(hasLong && hasShort)
        {
           ulong toClose = isBearish ? longTicket : shortTicket;
           if(toClose > 0 && trade.PositionClose(toClose))
              Print("[DOW] Contre-tendance → position fermée #", toClose, " (",
                    (isBearish ? "BUY" : "SELL"), ") sur ", _Symbol);
        }
     }

      // ── NOTIFICATION: détection entrée par LIMIT (fill) ──
      // Une position DOW sans "MARKET" dans le commentaire = LIMIT qui vient de filler
      {
         int dgN = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
         static ulong s_lastNotifiedDOWPos = 0;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong tk = PositionGetTicket(i);
            if(tk == 0) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            string cmt = PositionGetString(POSITION_COMMENT);
            if(StringFind(cmt, "DOW") < 0) continue;
            if(StringFind(cmt, "MARKET") >= 0) continue;
            if(tk == s_lastNotifiedDOWPos) continue;
            s_lastNotifiedDOWPos = tk;
            string dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            string ts = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
            double ep = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
             Print("📌 DOW LIMIT FILLED ", dir, " Entry=", DoubleToString(ep, dgN),
                  " SL=", DoubleToString(sl, dgN), " TP=", DoubleToString(tp, dgN), " ", ts);
             if(UseNotifications)
                SendNotification("📌 DOW LIMIT FILLED " + _Symbol + " " + dir +
                                 " @ " + DoubleToString(ep, dgN) + " " + ts);
         }
      }

      // ── DEBUG: état de chaque gate ──
      {
         int vnDbg = g_smcGomConnected ? g_smcGomVerdictNum : 0;
         bool confirmed = IsSignalConfirmed();
         int hasPos = CountPositionsForSymbol(_Symbol);
         bool gomAlignedDbg = (!isBearish && vnDbg >= 3) || (isBearish && vnDbg <= -3);
         bool dirAllowed = IsDirectionAllowedForBoomCrash(_Symbol, isBearish ? "SELL" : "BUY");
         bool patBlock = Dow_PatternForecastBlocksTrade();
         static datetime s_lastDbg = 0;
         if(TimeCurrent() - s_lastDbg >= 10)
         {
            Print("[DOW DBG] ", _Symbol, " vn=", vnDbg,
                  " isBear=", isBearish, " gomAlign=", gomAlignedDbg,
                  " blink=", g_signalActiveAction, " confirmed=", confirmed,
                  " ai=", g_lastAIAction, " hasPos=", hasPos,
                  " dirOK=", dirAllowed, " selCnt=", selectedCount,
                  " patDir=", g_patternForecast.direction,
                  " patSpike=", DoubleToString(g_patternForecast.spikeProbability * 100, 0), "%",
                  " patBlock=", patBlock);
            s_lastDbg = TimeCurrent();
         }
      }

       // ── PRIORITÉ 0: REENTRY DOW + EMA avant MARKET classique ──────────
       bool hasPosition = (CountPositionsForSymbol(_Symbol) > 0);
       if(!hasPosition)
       {
          // REENTRY DOW
          double reentryPrice = 0;
          if(SMC_DOWReentryAllowed(_Symbol, (!isBearish ? 1 : -1), reentryPrice))
          {
             if(TryAcquireOpenLock())
             {
                double lot = CalculateLotSize();
                if(lot > 0)
                {
                    int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
                    double atrRe = 0;
                    int atrReH = iATR(_Symbol, PERIOD_M1, 14);
                    if(atrReH != INVALID_HANDLE)
                    {
                       double atrReBuf[];
                       ArraySetAsSeries(atrReBuf, true);
                       if(CopyBuffer(atrReH, 0, 0, 1, atrReBuf) >= 1) atrRe = atrReBuf[0];
                       IndicatorRelease(atrReH);
                    }
                    if(atrRe > 0)
                    {
                       bool okRe = false;
                       if(!isBearish)
                       {
                          double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                          double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                          double pricePerDollar = (tickVal * lot) / tickSz;
                          double slDist = (pricePerDollar > 0) ? MathMax(5.0 / pricePerDollar, atrRe * 3.0) : atrRe * 4.0;
                          slDist = NormalizeDouble(MathMax(slDist, tickSz * 5), dg);
                          double sl = NormalizeDouble(reentryPrice - slDist, dg);
                          double tp = NormalizeDouble(reentryPrice + slDist * 3.0, dg);
                          okRe = trade.Buy(lot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, tp, "DOW REENTRY BUY");
                       }
                       else
                       {
                          double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                          double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                          double pricePerDollar = (tickVal * lot) / tickSz;
                          double slDist = (pricePerDollar > 0) ? MathMax(5.0 / pricePerDollar, atrRe * 3.0) : atrRe * 4.0;
                          slDist = NormalizeDouble(MathMax(slDist, tickSz * 5), dg);
                          double sl = NormalizeDouble(reentryPrice + slDist, dg);
                          double tp = NormalizeDouble(reentryPrice - slDist * 3.0, dg);
                          okRe = trade.Sell(lot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, tp, "DOW REENTRY SELL");
                       }
                       if(okRe)
                       {
                          g_dowState.dowReentryCount++;
                          g_dowState.lastDowEntryTime = TimeCurrent();
                          g_dowState.lastDowEntryDir = (!isBearish ? "BUY" : "SELL");
                          g_dowState.lastDowEntryPrice = reentryPrice;
                          Print("✅ DOW REENTRY ", (!isBearish ? "BUY" : "SELL"), " @", DoubleToString(reentryPrice, dg));
                       }
                    }
                 }
                 ReleaseOpenLock();
                 if(CountPositionsForSymbol(_Symbol) > 0) return;
              }
           }
           
           // REENTRY EMA 23/25/28
           double emaReentryPrice = 0;
           if(SMC_EMAReentryAllowed(_Symbol, (!isBearish ? 1 : -1), emaReentryPrice))
           {
              if(TryAcquireOpenLock())
              {
                 double lot = CalculateLotSize();
                 if(lot > 0)
                 {
                    int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
                    double atrRe = 0;
                    int atrReH = iATR(_Symbol, PERIOD_M1, 14);
                    if(atrReH != INVALID_HANDLE)
                    {
                       double atrReBuf[];
                       ArraySetAsSeries(atrReBuf, true);
                       if(CopyBuffer(atrReH, 0, 0, 1, atrReBuf) >= 1) atrRe = atrReBuf[0];
                       IndicatorRelease(atrReH);
                    }
                    if(atrRe > 0)
                    {
                       bool okRe = false;
                       if(!isBearish)
                       {
                          double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                          double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                          double pricePerDollar = (tickVal * lot) / tickSz;
                          double slDist = (pricePerDollar > 0) ? MathMax(5.0 / pricePerDollar, atrRe * 3.0) : atrRe * 4.0;
                          slDist = NormalizeDouble(MathMax(slDist, tickSz * 5), dg);
                          double sl = NormalizeDouble(emaReentryPrice - slDist, dg);
                          double tp = NormalizeDouble(emaReentryPrice + slDist * 3.0, dg);
                          okRe = trade.Buy(lot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, tp, "EMA REENTRY BUY");
                       }
                       else
                       {
                          double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                          double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                          double pricePerDollar = (tickVal * lot) / tickSz;
                          double slDist = (pricePerDollar > 0) ? MathMax(5.0 / pricePerDollar, atrRe * 3.0) : atrRe * 4.0;
                          slDist = NormalizeDouble(MathMax(slDist, tickSz * 5), dg);
                          double sl = NormalizeDouble(emaReentryPrice + slDist, dg);
                          double tp = NormalizeDouble(emaReentryPrice - slDist * 3.0, dg);
                          okRe = trade.Sell(lot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, tp, "EMA REENTRY SELL");
                       }
                       if(okRe)
                       {
                          Print("✅ EMA REENTRY ", (!isBearish ? "BUY" : "SELL"), " @", DoubleToString(emaReentryPrice, dg));
                       }
                    }
                 }
                 ReleaseOpenLock();
                 if(CountPositionsForSymbol(_Symbol) > 0) return;
              }
           }
        }

        // ── PRIORITÉ 1: GOM PERFECT + blink → MARKET immédiat ──────────
       hasPosition = (CountPositionsForSymbol(_Symbol) > 0);
    if(!hasPosition)
    {
       // ⛔ Pattern Forecast hard block
       if(Dow_PatternForecastBlocksTrade())
          return;

       // Cap 2 MARKET DOW par symbole
       int dowMktCount = 0;
       for(int i = PositionsTotal() - 1; i >= 0; i--)
       {
          ulong tk = PositionGetTicket(i);
          if(tk == 0) continue;
          if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
          if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
          if(StringFind(PositionGetString(POSITION_COMMENT), "DOW MARKET") >= 0)
             dowMktCount++;
       }
       if(dowMktCount >= 2)
       {
          static datetime s_lastMktCap = 0;
          if(TimeCurrent() - s_lastMktCap >= 30) { Print("[DOW] MAX 2 MARKET atteint (", dowMktCount, ") sur ", _Symbol); s_lastMktCap = TimeCurrent(); }
          return;
       }

       Dow_ExecutePredictiveMarketOrder(isBearish, atrVal, selectedCount);
       if(CountPositionsForSymbol(_Symbol) > 0)
          return;
    }
    else
    {
       // Si position ouverte, ne rien faire (trailing gère)
       static datetime s_lastPosLog = 0;
       if(TimeCurrent() - s_lastPosLog >= 30) { Print("[DOW] POSITION EXISTANTE sur ", _Symbol, " → skip LIMIT (trailing gère)"); s_lastPosLog = TimeCurrent(); }
       return;
    }

      // ── PRIORITÉ 2: MARKET classique au prix actuel (remplace LIMIT trendline) ──
      // GOM PERFECT obligatoire aussi (|vn|>=3)
      if(CountPositionsForSymbol(_Symbol) > 0) return; // déjà une position → skip

      // ⛔ Pattern Forecast hard block
      if(Dow_PatternForecastBlocksTrade())
         return;

      int vnLim = g_smcGomConnected ? g_smcGomVerdictNum : 0;

       // Si GOM n'est plus PERFECT → vérifier la discipline LIMIT avant suppression
       if(MathAbs(vnLim) < 3)
       {
          // ── VÉRIFICATION DISCIPLINE LIMIT (via SMC_LimitDiscipline) ──
          if(g_dowState.limitTicket > 0)
          {
             // Utiliser LimitCancelAllowed pour respecter les paramètres de patience
             if(!LimitCancelAllowed(g_dowState.limitTicket, false, "GOM non PERFECT"))
             {
                static datetime s_discLog = 0;
                if(TimeCurrent() - s_discLog >= 15)
                {
                   s_discLog = TimeCurrent();
                   Print("[DOW] LIMIT conservée (discipline) malgré GOM=", vnLim,
                         " age=", LimitOrderAgeSec(g_dowState.limitTicket), "s");
                }
                // NE PAS supprimer - garder le LIMIT
             }
             else
             {
                Dow_RemoveLimit(g_dowState.limitTicket, "GOM non PERFECT vn=" + IntegerToString(vnLim) + " → LIMIT supprimé");
                Print("[DOW] LIMIT ANNUlé car GOM=", vnLim, " sur ", _Symbol);
                g_dowState.limitTicket = 0;
             }
          }
          
          // Pour EP LIMIT et ZONE LIMIT, même logique
          if(g_dowState.epLimitTicket > 0)
          {
             if(!LimitCancelAllowed(g_dowState.epLimitTicket, false, "GOM non PERFECT"))
             {
                // Garder EP LIMIT
             }
             else
             {
                Dow_RemoveLimit(g_dowState.epLimitTicket, "GOM non PERFECT → EP LIMIT supprimé");
                g_dowState.epLimitTicket = 0;
             }
          }
          
          if(g_smcZoneLimitTicket > 0)
          {
             if(!LimitCancelAllowed(g_smcZoneLimitTicket, false, "GOM non PERFECT"))
             {
                // Garder ZONE LIMIT
             }
             else
             {
                Dow_RemoveLimit(g_smcZoneLimitTicket, "GOM non PERFECT → ZONE LIMIT supprimé");
                g_smcZoneLimitTicket = 0;
             }
          }
          
          return;
       }

       // Direction GOM alignée avec DOW pour MARKET
       bool limGomAligned = (!isBearish && vnLim >= 3) || (isBearish && vnLim <= -3);
       if(!limGomAligned)
       {
          // ── VÉRIFICATION DISCIPLINE LIMIT avant suppression ──
          if(g_dowState.limitTicket > 0)
          {
             if(!LimitCancelAllowed(g_dowState.limitTicket, false, "GOM direction ≠ DOW"))
             {
                static datetime s_discLog2 = 0;
                if(TimeCurrent() - s_discLog2 >= 15)
                {
                   s_discLog2 = TimeCurrent();
                   Print("[DOW] LIMIT conservée (discipline) malgré direction ≠ DOW=", 
                         (isBearish ? "SELL" : "BUY"), " vn=", vnLim);
                }
             }
             else
             {
                Dow_RemoveLimit(g_dowState.limitTicket, "GOM PERFECT mais ≠ DOW → LIMIT supprimé");
                Print("[DOW] LIMIT ANNUlé: GOM PERFECT mais vn=", vnLim, " ≠ DOW=", (isBearish ? "SELL" : "BUY"));
                g_dowState.limitTicket = 0;
             }
          }
          
          if(g_dowState.epLimitTicket > 0)
          {
             if(!LimitCancelAllowed(g_dowState.epLimitTicket, false, "GOM direction ≠ DOW"))
             {
                // Garder EP LIMIT
             }
             else
             {
                Dow_RemoveLimit(g_dowState.epLimitTicket, "GOM PERFECT mais ≠ DOW → EP LIMIT supprimé");
                g_dowState.epLimitTicket = 0;
             }
          }
          
          return;
       }

      // Le prix LIMIT = le prix projeté affiché sur le graphique (DOW projected level)
      int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize <= 0) tickSize = _Point;

      datetime now = TimeCurrent();
      double limitPrice = g_dowState.projectedPrice;
      if(limitPrice <= 0)
      {
         limitPrice = g_dowState.endPrice + g_dowState.slope * (now - g_dowState.endTime + PeriodSeconds(PERIOD_M1) * 8);
      }
      limitPrice = NormalizeDouble(limitPrice, dg);

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    if(bid <= 0 || ask <= 0) return;

    // ── MARKET exécuté directement (ancienne chase LIMIT supprimée) ──

    // ── MARKET au lieu de LIMIT (trendline) ──
    MqlTradeRequest req = {};
    MqlTradeResult  res = {};
    req.action    = TRADE_ACTION_DEAL;
    req.symbol    = _Symbol;
    req.volume    = NormalizeVolumeForSymbol(0.01);
    req.magic     = InpMagicNumber;
    req.deviation = 30;

    if(isBearish)
    {
       req.type    = ORDER_TYPE_SELL;
       req.price   = bid;
       req.sl      = NormalizeDouble(bid + atrVal * DOW_SL_ATRMULT, dg);
       req.tp      = NormalizeDouble(bid - atrVal * DOW_TP_ATRMULT, dg);
       req.comment = "DOW SELL MARKET";
    }
    else
    {
       req.type    = ORDER_TYPE_BUY;
       req.price   = ask;
       req.sl      = NormalizeDouble(ask - atrVal * DOW_SL_ATRMULT, dg);
       req.tp      = NormalizeDouble(ask + atrVal * DOW_TP_ATRMULT, dg);
       req.comment = "DOW BUY MARKET";
    }

   if(SafeSafeSafeOrderSend(req, res, req.comment) && res.retcode == TRADE_RETCODE_DONE)
   {
       string tsLim = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
       Print("📈 DOW ", (isBearish ? "SELL" : "BUY"), " MARKET @ ", req.price,
             " | SL=", req.sl, " | TP=", req.tp, " ", tsLim);
       if(UseNotifications)
          SendNotification("🚀 DOW " + (isBearish ? "SELL" : "BUY") + " MARKET " + _Symbol +
                           " @ " + DoubleToString(req.price, dg) +
                           " SL=" + DoubleToString(req.sl, dg) +
                           " TP=" + DoubleToString(req.tp, dg) +
                           " " + tsLim);
    }
      else
         Print("❌ DOW MARKET failed: ", res.retcode, " - ", res.comment);

   // ── PRIORITÉ 3: EP MARKET (retracement au niveau DOW BULL/BEAR EP) ──
   // Exécute un MARKET au niveau mid quand le prix touche l'EP
   // et retrace 1 bougie. GOM PERFECT déjà checké ci-dessus (|vn|>=3).
   double epPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   g_dowState.currentEpPrice = epPrice;

   // Détection touché EP: Bull→prix descend jusqu'à EP, Bear→prix monte jusqu'à EP
   double low1 = iLow(_Symbol, PERIOD_M1, 0);
   double high1 = iHigh(_Symbol, PERIOD_M1, 0);
   bool epTouched = isBearish ? (high1 >= epPrice) : (low1 <= epPrice);
   if(epTouched)
   {
      g_dowState.epLastTouchTime = TimeCurrent();
      g_dowState.epTouchPrice = epPrice;
      g_dowState.epTouchBarTime = iTime(_Symbol, PERIOD_M1, 0);
   }

    // ── EP LIMIT management removed — now using MARKET ──

   // ── Placer nouveau EP MARKET ──
   if(g_dowState.epLimitTicket == 0)
   {
      // Attendre 1 bougie après le touché
      if(g_dowState.epLastTouchTime > 0 && iTime(_Symbol, PERIOD_M1, 0) > g_dowState.epTouchBarTime)
      {
         // ⛔ Pattern Forecast hard block
         if(Dow_PatternForecastBlocksTrade())
            return;

         MqlTradeRequest epReq = {};
         MqlTradeResult  epRes = {};
         epReq.action    = TRADE_ACTION_DEAL;
         epReq.symbol    = _Symbol;
         epReq.volume    = NormalizeVolumeForSymbol(0.01);
         epReq.magic     = InpMagicNumber;
         epReq.deviation = 30;

         if(isBearish)
         {
            epReq.type    = ORDER_TYPE_SELL;
            epReq.price   = bid;
            epReq.sl      = NormalizeDouble(bid + atrVal * DOW_SL_ATRMULT, dg);
            epReq.tp      = NormalizeDouble(bid - atrVal * DOW_TP_ATRMULT, dg);
            epReq.comment = "DOW EP SELL MARKET";
         }
         else
         {
            epReq.type    = ORDER_TYPE_BUY;
            epReq.price   = ask;
            epReq.sl      = NormalizeDouble(ask - atrVal * DOW_SL_ATRMULT, dg);
            epReq.tp      = NormalizeDouble(ask + atrVal * DOW_TP_ATRMULT, dg);
            epReq.comment = "DOW EP BUY MARKET";
         }

         if(SafeSafeSafeOrderSend(epReq, epRes, epReq.comment) && epRes.retcode == TRADE_RETCODE_DONE)
         {
             g_dowState.epLimitTicket = epRes.order;
              string tsEp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
              Print("📈 DOW EP ", (isBearish ? "SELL" : "BUY"), " MARKET @ ", epReq.price,
                    " (touché EP) | SL=", epReq.sl, " | TP=", epReq.tp, " ", tsEp);
              if(UseNotifications)
                 SendNotification("🚀 DOW EP " + (isBearish ? "SELL" : "BUY") + " MARKET " + _Symbol +
                                  " @ " + DoubleToString(epReq.price, dg) +
                                  " SL=" + DoubleToString(epReq.sl, dg) +
                                  " TP=" + DoubleToString(epReq.tp, dg) +
                                  " " + tsEp);
         }
         else
            Print("❌ DOW EP MARKET failed: ", epRes.retcode, " - ", epRes.comment);
      }
   }

   // ── PRIORITÉ 4: SMC Zone Re-entry MARKET sur zones cached ──
   // Quand GOM PERFECT + zone valide, exécute un MARKET immédiat
   Dow_ZoneReentryLimit();
}

//+------------------------------------------------------------------+
//| Nettoyage à la déconnexion                                      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| SMC Zone Re-entry MARKET — entrées sur les zones cached          |
//| PERFECT SELL: g_cachedBestSellLevel = résistance → SELL MARKET   |
//| PERFECT BUY:  g_cachedBestBuyLevel  = support   → BUY MARKET    |
//| Fonctionne indépendamment de DOW trendline (même si DOW inactif) |
//+------------------------------------------------------------------+
ulong g_smcZoneLimitTicket = 0;

void Dow_ZoneReentryLimit()
{
   if(!UseDowTrendline) return;

   if(!g_smcGomConnected) return;
   int vn = g_smcGomVerdictNum;
   if(MathAbs(vn) < 3) return;

   bool isBearish = (vn < 0);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0) tickSize = _Point;

   double atrVal = 0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) >= 1) atrVal = atrBuf[0];
   }
   if(atrVal <= 0) atrVal = g_dowState.currentATR;
   if(atrVal <= 0) return;

   // ── Niveau LIMIT selon la tendance ──
   double limitPrice = 0;
   string comment = "";

   if(isBearish && g_cachedBestSellLevel > 0)
   {
      limitPrice = g_cachedBestSellLevel - atrVal * 0.1;
      comment = "DOW ZONE SELL";
   }
   else if(!isBearish && g_cachedBestBuyLevel > 0)
   {
      limitPrice = g_cachedBestBuyLevel + atrVal * 0.1;
      comment = "DOW ZONE BUY";
   }

   if(limitPrice <= 0) return;

   // ⛔ Pattern Forecast hard block
   if(Dow_PatternForecastBlocksTrade())
      return;

   // ── MARKET au lieu de LIMIT ──
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = _Symbol;
   req.volume    = NormalizeVolumeForSymbol(0.01);
   req.magic     = InpMagicNumber;
   req.deviation = 30;

   if(isBearish)
   {
      req.type    = ORDER_TYPE_SELL;
      req.price   = bid;
      req.sl      = NormalizeDouble(bid + atrVal * DOW_SL_ATRMULT, dg);
      req.tp      = NormalizeDouble(bid - atrVal * DOW_TP_ATRMULT, dg);
      req.comment = comment;
   }
   else
   {
      req.type    = ORDER_TYPE_BUY;
      req.price   = ask;
      req.sl      = NormalizeDouble(ask - atrVal * DOW_SL_ATRMULT, dg);
      req.tp      = NormalizeDouble(ask + atrVal * DOW_TP_ATRMULT, dg);
      req.comment = comment;
   }

   if(SafeSafeSafeOrderSend(req, res, comment) && res.retcode == TRADE_RETCODE_DONE)
   {
      string ts = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      Print("📈 DOW ZONE ", (isBearish ? "SELL" : "BUY"), " MARKET @ ", req.price,
            " | SL=", req.sl, " | TP=", req.tp, " ", ts);
      if(UseNotifications)
         SendNotification("🚀 DOW ZONE " + (isBearish ? "SELL" : "BUY") + " MARKET " + _Symbol +
                          " @ " + DoubleToString(req.price, dg) +
                          " SL=" + DoubleToString(req.sl, dg) +
                          " TP=" + DoubleToString(req.tp, dg) +
                          " " + ts);
   }
   else
      Print("❌ ZONE MARKET failed: ", res.retcode, " - ", res.comment);
}

void DowTrendline_Cleanup()
{
    Dow_CleanupChart();
    Dow_CleanupPatternForecast();
    g_dowState.active = false;
    g_dowState.chasingEma = false;
    g_dowState.limitTicket = 0;
    g_dowState.limitPlacedAt = 0;
    g_dowState.limitLastManaged = 0;
    g_dowState.lastChaseAt = 0;
    g_dowState.broken = false;
    g_dowState.candlesSinceBreak = 0;
    g_dowState.brokenBreakCount = 0;
    g_dowState.lastBreakTime = 0;
    g_dowState.lastRefreshTime = 0;
    g_dowState.currentEpPrice = 0;
    g_dowState.epLastTouchTime = 0;
    g_dowState.epTouchPrice = 0;
    g_dowState.epTouchBarTime = 0;
    g_dowState.epLimitTicket = 0;
    g_dowState.lastDowEntryTime = 0;
    g_dowState.lastDowEntryDir = "";
    g_dowState.lastDowEntryPrice = 0;
    g_dowState.lastDowWasWin = false;
    g_dowState.dowReentryCount = 0;
    g_smcZoneLimitTicket = 0;
    g_patternForecast.valid = false;
    g_patternForecast.lastFetchTime = 0;
}

#endif // SMC_DOWTRENDLINE_MQH

// force recompile


