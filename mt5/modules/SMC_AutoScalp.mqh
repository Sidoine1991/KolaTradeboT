//+------------------------------------------------------------------+
//| SMC_AutoScalp.mqh                                                 |
//| SETUP 1 - Scalping autonome synthétiques (Boom/Crash/PainX/GainX)|
//| Fusion: expérience 30 ans (suivre le biais du générateur de      |
//| spikes) + boucle (SL dur 3$, capital composé, Z-score, chaîne).   |
//| + SETUP 1B - Scalp Dow: GOM PERFECT + Cognition alignée → entrer|
//|   à chaque creux/sommet prédit (théorie de Dow).                  |
//| + SETUP 1C - Dow M5 + SR20 + Patterns: structure Dow M5          |
//|   confirme → prix au SR20 + pattern bougie → scalp.              |
//| Contrainte INVIOLABLE: perte max par trade = SMCASC_MaxLossUSD.   |
//+------------------------------------------------------------------+
#ifndef SMC_AUTO_SCALP_MQH
#define SMC_AUTO_SCALP_MQH

//--- Inputs SETUP 1 (Z-score)
input bool   SMCASC_Enable          = true;   // Activer le scalping autonome SETUP 1
input double SMCASC_MaxLossUSD      = 3.0;    // Perte max ABSOLUE par trade (SL dur)
input double SMCASC_ZScoreMin       = 2.0;    // Z-score ATR min pour état PRE-SPIKE
input double SMCASC_Tp1Mult          = 1.0;    // TP1 = 1R (scale out)
input double SMCASC_Tp2Mult          = 2.0;    // TP2 = 2R
input double SMCASC_TrailR          = 1.5;    // Trailing activé après +1.5R
input int    SMCASC_MaxTrades        = 1;      // Max positions ouvertes simultanées

//--- Inputs SETUP 1B (Dow Scalp v2 — Spike Chain + Fib Retrace)
input bool   SMCASC_DowScalpEnable  = true;   // Activer scalp Dow (spike chain + Fib)
input int    SMCASC_DowMinVerdict   = 1;      // |vn| min (1=tout verdict non-WAIT, 3=PERFECT only)
input double SMCASC_DowTolerancePct = 0.05;   // (ancien) Tolérance % pour path — non utilisé v2
input double SMCASC_DowSLMult        = 0.8;   // (ancien) SL = ATR x mult — non utilisé v2
input double SMCASC_DowTPMult        = 1.5;   // (ancien) TP = ATR x mult — non utilisé v2
input int    SMCASC_DowCooldownSec  = 5;      // Cooldown secondes entre 2 trades Dow (réduit pour réactivité)
input int    SMCASC_DowMaxTrades     = 3;     // Max trades Dow simultanés

//--- Inputs SETUP 1C (Dow M5 + SR20 + Patterns)
input bool   SMCASC_DowSR20Enable   = true;   // Activer SETUP 1C (Dow M5 + SR20 + Patterns)
input int    SMCASC_DowSR20MinVerdict = 2;    // |vn| min (2=GOOD+, 3=PERFECT only)
input double SMCASC_DowSR20SLMult    = 0.7;   // SL = ATR x mult (tight scalp)
input double SMCASC_DowSR20TPMult    = 1.2;   // TP = ATR x mult
input int    SMCASC_DowSR20Cooldown  = 20;    // Cooldown secondes entre 2 trades
input int    SMCASC_DowSR20MaxTrades = 2;     // Max trades 1C simultanés
input int    SMCASC_DowSR20M5Bars    = 30;    // Bougies M5 pour Dow structure
input double SMCASC_DowSR20MinScore  = 0.3;   // Score Dow M5 minimum (0..1)

//--- Inputs SETUP 1D (Vol Momentum + Fib Retrace — Weltrade Volatility Index)
input bool   SMCASC_VolMomEnable      = true;  // Activer scalp Vol momentum + Fib
input int    SMCASC_VolMomMinBars     = 2;     // Min bars consécutifs directionnels
input double SMCASC_VolMomAtrMult     = 1.5;   // Range > ATR x mult = bar momentum
input int    SMCASC_VolMomCooldownSec = 10;    // Cooldown secondes
input int    SMCASC_VolMomMaxTrades   = 2;     // Max trades simultanés
input double SMCASC_VolMomFibTol      = 0.20;  // Tolérance Fib (20% du range S/R20)
input double SMCASC_VolMomSLBuf       = 0.15;  // Buffer SL (15% du range S/R20)

//--- État interne
struct SMCASC_State
{
   bool     active;
   double   lastLot;
   datetime lastTradeTime;
};
SMCASC_State g_smcasc;

int g_smcascDowCount = 0;      // Nombre de trades Dow ouverts (1B)
int g_smcascDowSR20Count = 0;  // Nombre de trades 1C ouverts
int g_smcascVolMomCount = 0;   // Nombre de trades Vol momentum ouverts (1D)

//+------------------------------------------------------------------+
//| Calcule le lot pour que la perte sur SL ne dépasse JAMAIS maxLoss|
//| slDistancePoints = distance SL en points (symbole)               |
//+------------------------------------------------------------------+
double SMCASC_LotForMaxLoss(const string symbol, double slDistancePoints, double maxLoss)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = minLot;
   if(slDistancePoints <= 0) return minLot;

   double tickVal = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(tickVal <= 0 || tickSize <= 0 || point <= 0) return minLot;

   // Valeur en $ d'un point pour 1 lot
   double pointValuePerLot = (tickVal / tickSize) * point;
   if(pointValuePerLot <= 0) return minLot;

   // Lot = perte max / (distance_SL_points * valeur_point_par_lot)
   double lot = maxLoss / (slDistancePoints * pointValuePerLot);
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathRound(lot / lotStep) * lotStep;
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//|保留: pas besoin d'helper supplémentaire ici                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Tente un scalp SETUP 1 sur un symbole synthétique.               |
//| Conditions (fusion):                                             |
//|  - SMC_IsSpikeStyleSymbol (Boom/Crash/PainX/GainX)               |
//|  - Z-score ATR >= SMCASC_ZScoreMin (état pré-spike)             |
//|  - GOM GOOD/PERFECT dans le sens du spike (pas WAIT/SIMPLE)      |
//|  - Pas de position ouverte (max 1)                               |
//+------------------------------------------------------------------+
void SMCASC_TryScalpSynthetic(const string symbol, int dirSign)
{
   if(!SMCASC_Enable) return;
   if(!SMC_IsSpikeStyleSymbol(symbol)) return;
   if(g_smcasc.active) return;
   if(g_inRetrace) return; // bloqué par retracement

   // GOM: exiger GOOD/PERFECT dans le bon sens
   int vn = -999;
   if(g_smcGomConnected) vn = SMCGP_GetCachedVerdictNum(symbol);
   if(vn == -999 && symbol == _Symbol) vn = g_smcGomVerdictNum;
   if(vn == -999) return;                       // pas de verdict -> pas de trade
   if(vn == 0) return;                          // WAIT -> bloqué
   if(MathAbs(vn) < MinGOMVerdictNumAbs) return; // SIMPLE -> bloqué
   if(dirSign > 0 && vn < 0) return;            // contre-verdict
   if(dirSign < 0 && vn > 0) return;            // contre-verdict

   // Z-score pré-spike
   double z = SMC_ComputeATRZScore(SpikeChainATRLookback);
   if(z < SMCASC_ZScoreMin) return;

   // ATR pour dimensionner SL en points
   double atrPts = 0;
   if(atrHandle != INVALID_HANDLE)
   {
      double a[];
      ArraySetAsSeries(a, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, a) > 0) atrPts = a[0] / SymbolInfoDouble(symbol, SYMBOL_POINT);
   }
   if(atrPts <= 0) atrPts = 20; // fallback mini

   double slDistancePoints = atrPts * 1.0; // SL = 1 ATR (scalp tight)
   double lot = SMCASC_LotForMaxLoss(symbol, slDistancePoints, SMCASC_MaxLossUSD);
   if(lot <= 0) lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   lot = MathMin(lot, balance / 10.0);
   lot = MathMax(lot, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double entry = (dirSign > 0) ? ask : bid;
   double sl = (dirSign > 0) ? entry - atrPts * SymbolInfoDouble(symbol, SYMBOL_POINT)
                              : entry + atrPts * SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tp1 = (dirSign > 0) ? entry + atrPts * SMCASC_Tp1Mult * SymbolInfoDouble(symbol, SYMBOL_POINT)
                               : entry - atrPts * SMCASC_Tp1Mult * SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tp2 = (dirSign > 0) ? entry + atrPts * SMCASC_Tp2Mult * SymbolInfoDouble(symbol, SYMBOL_POINT)
                               : entry - atrPts * SMCASC_Tp2Mult * SymbolInfoDouble(symbol, SYMBOL_POINT);

   // Vérifier max positions ouvertes
   if(PositionsTotal() >= SMCASC_MaxTrades) return;

   MqlTradeRequest req = {};
   MqlTradeResult res = {};
   req.action = TRADE_ACTION_PENDING;
   req.symbol = symbol;
   req.volume = lot;
   req.type = (dirSign > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   req.price = entry;
   req.sl = sl;
   req.tp = tp2;
   req.magic = InpMagicNumber;
   req.deviation = 50;
   req.comment = "AUTOSCALP S1";

   if(!CanPlaceLimitOrder(symbol, req.type)) return;
   if(!ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, req.type)) return;

   if(SafeSafeOrderSend(req, res, req.comment) && res.retcode == TRADE_RETCODE_DONE)
   {
      g_smcasc.active = true;
      g_smcasc.lastLot = lot;
      g_smcasc.lastTradeTime = TimeCurrent();

       string dir = (dirSign > 0) ? "BUY" : "SELL";
       string gomLabel = "";
       if(MathAbs(vn) >= 3) gomLabel = (vn > 0) ? "PERFECT BUY" : "PERFECT SELL";
       else if(MathAbs(vn) >= 2) gomLabel = (vn > 0) ? "GOOD BUY" : "GOOD SELL";
       else gomLabel = "SIMPLE vn=" + IntegerToString(vn);
       string msg = "⚡ AUTOSCALP S1 [" + symbol + "]\n";
       msg += "ORDRE EXÉCUTÉ " + dir + "\n";
       msg += "GOM: " + gomLabel + " | Z=" + DoubleToString(z,2) + "\n";
       msg += "Entry: " + DoubleToString(entry, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "\n";
       msg += "SL(3$): " + DoubleToString(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "\n";
       msg += "TP1(" + DoubleToString(SMCASC_Tp1Mult,1) + "R): " + DoubleToString(tp1, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) +
              " | TP2(" + DoubleToString(SMCASC_Tp2Mult,1) + "R): " + DoubleToString(tp2, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "\n";
       msg += "Lot: " + DoubleToString(lot,2) + " (minLot=" + DoubleToString(SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN),2) + ")";
       if(UseNotifications) SendNotification(msg);
       if(UseWhatsAppAlerts)
       {
          double dow = 0; double conf = 1.0; int sc = 1;
          string extra = gomLabel + " Z=" + DoubleToString(z,2);
          SendSR20WhatsAppSignal("CHAIN_SIGNAL", symbol, dir, entry, sl, tp2, entry, 0, "", atrPts, conf, sc, extra);
       }
      Print("✅ AUTOSCALP S1 ", dir, " placé ", symbol, " @ ", DoubleToString(entry, _Digits),
            " | Lot: ", DoubleToString(lot,2), " | SL pts: ", DoubleToString(slDistancePoints,1),
            " | Perte max $: ", DoubleToString(SMCASC_MaxLossUSD,2));
   }
   else
   {
      Print("❌ AUTOSCALP S1 échec ", symbol, " rc=", res.retcode, " ", res.comment);
   }
}

//+------------------------------------------------------------------+
//| Libère le verrou actif quand la position est fermée/clôturée.   |
//+------------------------------------------------------------------+
void SMCASC_OnTickGuard()
{
   if(g_smcasc.active)
   {
      bool stillOpen = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong tk = PositionGetTicket(i);
         if(tk > 0 && PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber
            && StringFind(PositionGetString(POSITION_COMMENT), "AUTOSCALP S1") >= 0)
         { stillOpen = true; break; }
      }
      if(!stillOpen) g_smcasc.active = false;
   }
   // Compter les trades Dow ouverts (SETUP 1B)
   g_smcascDowCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk > 0 && PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber
         && StringFind(PositionGetString(POSITION_COMMENT), "DOW SCALP") >= 0)
         g_smcascDowCount++;
   }
   // Compter les trades Dow SR20 ouverts (SETUP 1C)
   g_smcascDowSR20Count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk > 0 && PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber
         && StringFind(PositionGetString(POSITION_COMMENT), "DOW SR20") >= 0)
         g_smcascDowSR20Count++;
   }
}

//+------------------------------------------------------------------+
//| SETUP 1B — Scalp Dow: entre à chaque creux/sommet prédit        |
//| Quand GOM PERFECT + Cognition alignée, suit la structure Dow.    |
//| BUY = creux (trough) prédit | SELL = sommet (peak) prédit       |
//+------------------------------------------------------------------+
void SMCASC_TryDowScalp(const string symbol, int dirSign)
{
   //═══════════════════════════════════════════════════════════════════════
   // SETUP 1B v2 — Spike Chain + Fib Retrace
   //
   // Logique (inspirée de l'observation PainX):
   //   1. Un 1er spike touche S/R 20 bars (résistance pour Crash, support pour Boom)
   //   2. Un 2ème spike suit (chaîne lâche: 5-6 bougies) → chain confirmée
   //   3. Entrée IMMÉDIATE au niveau Fib:
   //      - Crash/PainX: SELL @ Fib 100% = résistance 20 bars
   //      - Boom/GainX:  BUY @ Fib 0%   = support 20 bars
   //   4. SL au-delà de la zone, TP = niveau opposite S/R 20
   //
   // Plus besoin de: GOM PERFECT, Cognition, Dow score, prédiction path
   //═══════════════════════════════════════════════════════════════════════
   if(!SMCASC_DowScalpEnable) return;
   if(!SMC_IsSpikeStyleSymbol(symbol)) return;
   if(g_smcascDowCount >= SMCASC_DowMaxTrades) { Print("[DOW] blocked: max trades=", g_smcascDowCount); return; }

   // Cooldown
   static datetime s_lastDowTrade = 0;
   if(TimeCurrent() - s_lastDowTrade < SMCASC_DowCooldownSec) return;

   // ── 1. SPIKE CHAIN DETECTION ──
   // Au moins 2 spikes dans la chaîne + le dernier spike est dans notre direction
   if(g_smcscs.spikeCount < 2) return;
   if(g_smcscs.lastSpikeDir * dirSign <= 0) return; // spike doit être dans notre sens

   // Vérifier que les spikes sont récents (chain active: ≤ LooseMaxBars entre les 2 derniers)
   int interval = g_smcscs.lastSpikeBar - g_smcscs.prevSpikeBar;
   if(interval <= 0 || interval > SMCSCS_LooseMaxBars) return;

   // ── 2. GOM: juste pas WAIT (vn != 0) ──
   int vn = -999;
   if(g_smcGomConnected) vn = SMCGP_GetCachedVerdictNum(symbol);
   if(vn == -999 && symbol == _Symbol) vn = g_smcGomVerdictNum;
   if(vn == -999) return; // pas de verdict dispo
   if(vn == 0) return;    // WAIT = on attend

   // ── 3. COMPUTE S/R 20 BARS (Fibonacci levels) ──
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 1, 20, rates) < 20) return;
   double sup20 = rates[0].low;
   double res20 = rates[0].high;
   for(int i = 1; i < 20; i++)
   {
      if(rates[i].low < sup20) sup20 = rates[i].low;
      if(rates[i].high > res20) res20 = rates[i].high;
   }
   if(res20 <= sup20) return; // range invalide

   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double bid    = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask    = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double range  = res20 - sup20;

   // ── 4. FIB RETRACE ENTRY ZONE ──
   // Tolérance = 20% du range S/R20 (zone d'entrée élargie pour capter le mouvement rapide)
   double fibTolerance = range * 0.20;
   double currentPrice = (dirSign > 0) ? bid : ask;

   if(dirSign < 0) // SELL (Crash/PainX) → entrée @ Fib 100% = résistance
   {
      if(ask < res20 - fibTolerance) { Print("[DOW] blocked: ask=", DoubleToString(ask,digits),
         " trop loin de res20=", DoubleToString(res20,digits)); return; }
   }
   else // BUY (Boom/GainX) → entrée @ Fib 0% = support
   {
      if(bid > sup20 + fibTolerance) { Print("[DOW] blocked: bid=", DoubleToString(bid,digits),
         " trop loin de sup20=", DoubleToString(sup20,digits)); return; }
   }

   // ── 5. SL/TP basés sur S/R 20 ──
   double bufferPts = range * 0.15; // buffer = 15% du range au-delà de la zone
   double entry, sl, tp;

   if(dirSign < 0) // SELL
   {
      entry = ask;
      sl    = res20 + bufferPts;            // SL au-dessus de la résistance
      tp    = sup20;                         // TP = support (Fib 0%)
   }
   else // BUY
   {
      entry = bid;
      sl    = sup20 - bufferPts;            // SL en-dessous du support
      tp    = res20;                         // TP = résistance (Fib 100%)
   }

   // Lot = risque max $3
   double slDistancePts = MathAbs(entry - sl) / point;
   double lot = SMCASC_LotForMaxLoss(symbol, slDistancePts, SMCASC_MaxLossUSD);
   if(lot <= 0) lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   lot = MathMin(lot, balance / 10.0);
   lot = MathMax(lot, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));

   // ── 6. ORDRE LIMIT (SL/TP fixés par S/R20, pas de override) ──
   // On ne PASSE PAS par ValidateAndAdjustLimitPrice car il remplace nos SL/TP
   // basés sur S/R20 par des calculs M1 bars génériques. On fait juste la
   // validation broker minimale (prix < Ask pour BUY_LIMIT, etc.)
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_PENDING;
   req.symbol    = symbol;
   req.volume    = lot;
   req.type      = (dirSign > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   req.price     = NormalizeDouble(entry, digits);
   req.sl        = NormalizeDouble(sl, digits);
   req.tp        = NormalizeDouble(tp, digits);
   req.magic     = InpMagicNumber;
   req.deviation = 50;
   req.comment   = "DOW SCALP";

   if(!CanPlaceLimitOrder(symbol, req.type)) return;

   // Validation broker minimale (sans override SL/TP)
   double curAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double curBid = SymbolInfoDouble(symbol, SYMBOL_BID);
   long stopsLvl = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stopsLvl * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(dirSign > 0 && req.price >= curAsk) { Print("[DOW] prix ajusté: BUY_LIMIT doit être < Ask"); return; }
   if(dirSign < 0 && req.price <= curBid) { Print("[DOW] prix ajusté: SELL_LIMIT doit être > Bid"); return; }
   // Vérifier min distance SL/TP vs prix
   if(MathAbs(entry - sl) < minDist * SymbolInfoDouble(symbol, SYMBOL_POINT)) {
      sl = (dirSign > 0) ? entry - minDist * 1.2 * SymbolInfoDouble(symbol, SYMBOL_POINT)
                         : entry + minDist * 1.2 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      req.sl = NormalizeDouble(sl, digits);
   }
   if(MathAbs(entry - tp) < minDist * SymbolInfoDouble(symbol, SYMBOL_POINT)) {
      tp = (dirSign > 0) ? entry + minDist * 1.2 * SymbolInfoDouble(symbol, SYMBOL_POINT)
                         : entry - minDist * 1.2 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      req.tp = NormalizeDouble(tp, digits);
   }

   if(SafeSafeOrderSend(req, res, req.comment) && res.retcode == TRADE_RETCODE_DONE)
   {
      s_lastDowTrade = TimeCurrent();
      g_smcascDowCount++;

      string dir = (dirSign > 0) ? "BUY" : "SELL";
      string fibLevel = (dirSign < 0) ? "Fib100%=res20" : "Fib0%=sup20";
      string gomLabel = (MathAbs(vn) >= 3) ? "PERFECT" : "GOOD";
      string chainType = SMCSCS_ChainType();

      string msg = "🎯 DOW SCALP v2 [" + symbol + "]\n";
      msg += dir + " @ " + fibLevel + "\n";
      msg += "Chain: " + chainType + " (" + IntegerToString(g_smcscs.spikeCount) + " spikes, " + IntegerToString(interval) + " bars)\n";
      msg += "GOM: " + gomLabel + " vn=" + IntegerToString(vn) + "\n";
      msg += "S/R20: [" + DoubleToString(sup20, digits) + " - " + DoubleToString(res20, digits) + "]\n";
      msg += "Entry: " + DoubleToString(entry, digits) + "\n";
      msg += "SL: " + DoubleToString(sl, digits) + " | TP: " + DoubleToString(tp, digits) + "\n";
      msg += "Lot: " + DoubleToString(lot, 2) + " | Dow trades: " + IntegerToString(g_smcascDowCount);
      if(UseNotifications) SendNotification(msg);
      Print("🎯 DOW SCALP v2 ", dir, " ", symbol, " @ ", DoubleToString(entry, digits),
            " | SR20=[", DoubleToString(sup20,digits), "-", DoubleToString(res20,digits), "]",
            " | Chain=", chainType, " | GOM vn=", vn);
   }
   else
   {
      Print("❌ DOW SCALP échec ", symbol, " rc=", res.retcode, " ", res.comment);
   }
}

//+------------------------------------------------------------------+
//| SETUP 1C — Dow M5 + SR20 + Patterns M1                          |
//| Détecte la structure Dow sur M5 (higher lows / lower highs)      |
//| Quand M5 confirme → scalp M1: prix touche SR20 + GOM GOOD/PERFECT|
//| + pattern bougie confirme → entrée au support/résistance.        |
//+------------------------------------------------------------------+

//--- Calcul du Dow score sur M5 (structure de tendance)
//    Retourne [-1..+1]: +1 = haussier parfait, -1 = baissier parfait
//    swingCount = nombre de swings détectés
double SMCASC_ComputeDowScoreM5(const string symbol, int &swingCount)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = SMCASC_DowSR20M5Bars;
   if(CopyRates(symbol, PERIOD_M5, 0, bars + 5, rates) < bars) return 0;

   bool bullish = !(IsCrashLikeSymbol(symbol));

   // Détecter les swings M5 (pivot 3 bougies)
   double swings[];
   int    swDir[];
   for(int i = 3; i < bars - 2; i++)
   {
      if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
         rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
      {
         int sz = ArraySize(swings); ArrayResize(swings, sz+1); swings[sz]=rates[i].high;
         ArrayResize(swDir, sz+1); swDir[sz]=1;
      }
      if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
         rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
      {
         int sz = ArraySize(swings); ArrayResize(swings, sz+1); swings[sz]=rates[i].low;
         ArrayResize(swDir, sz+1); swDir[sz]=-1;
      }
   }

   swingCount = ArraySize(swings);
   if(swingCount < 3) return 0;

   int aligned = 0, total = 0;
   for(int i = 1; i < swingCount; i++)
   {
      if(swDir[i] != swDir[i-1]) continue;
      total++;
      if(swDir[i] == 1) // sommet
      {
         if(bullish && swings[i] > swings[i-1]) aligned++;  // higher high = haussier
         if(!bullish && swings[i] < swings[i-1]) aligned++; // lower high = baissier
      }
      else // creux
      {
         if(bullish && swings[i] < swings[i-1]) aligned++;  // higher low = haussier
         if(!bullish && swings[i] > swings[i-1]) aligned++; // lower low = baissier
      }
   }
   if(total == 0) return 0;
   return (double)aligned / (double)total * 2.0 - 1.0; // [-1..+1]
}

//+------------------------------------------------------------------+
//| SETUP 1C — Scalp: Dow M5 confirme → entrée au SR20 + Patterns   |
//+------------------------------------------------------------------+
void SMCASC_TryDowSR20Scalp(const string symbol, int dirSign)
{
   if(!SMCASC_DowSR20Enable) return;
   if(!SMC_IsSpikeStyleSymbol(symbol)) return;
   if(g_smcascDowSR20Count >= SMCASC_DowSR20MaxTrades) return;

   // Cooldown
   static datetime s_lastDowSR20Trade = 0;
   if(TimeCurrent() - s_lastDowSR20Trade < SMCASC_DowSR20Cooldown) return;

   //--- 1) GOM verdict GOOD/PERFECT dans la bonne direction
   int vn = -999;
   if(g_smcGomConnected) vn = SMCGP_GetCachedVerdictNum(symbol);
   if(vn == -999 && symbol == _Symbol) vn = g_smcGomVerdictNum;
   if(vn == 0) return;
   if(MathAbs(vn) < SMCASC_DowSR20MinVerdict) { Print("[DOW-SR20] blocked: |vn|=", MathAbs(vn), " < min=", SMCASC_DowSR20MinVerdict); return; }
   if(dirSign > 0 && vn < 0) { Print("[DOW-SR20] blocked: vn=", vn, " ≠ BUY dir"); return; }
   if(dirSign < 0 && vn > 0) { Print("[DOW-SR20] blocked: vn=", vn, " ≠ SELL dir"); return; }

   //--- 2) Dow M5 structure confirme la direction
   int swingCount = 0;
   double dowM5 = SMCASC_ComputeDowScoreM5(symbol, swingCount);
   if(swingCount < 3) { Print("[DOW-SR20] blocked: swings=", swingCount, " < 3"); return; }
   if(dirSign > 0 && dowM5 < SMCASC_DowSR20MinScore) { Print("[DOW-SR20] blocked: BUY dowM5=", DoubleToString(dowM5,3), " < min=", DoubleToString(SMCASC_DowSR20MinScore,3)); return; }
   if(dirSign < 0 && dowM5 > -SMCASC_DowSR20MinScore) { Print("[DOW-SR20] blocked: SELL dowM5=", DoubleToString(dowM5,3), " > max=", DoubleToString(-SMCASC_DowSR20MinScore,3)); return; }

   //--- 3) SR20 disponible et prix proche
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double price = (bid + ask) / 2.0;

   double sr20Level = 0;
   if(dirSign > 0) sr20Level = g_impulseSupport20;   // BUY au support
   else            sr20Level = g_impulseResistance20; // SELL à la résistance
   if(sr20Level <= 0) { Print("[DOW-SR20] blocked: SR20 level=0"); return; }

   // Le prix doit être proche du SR20 (dans 1 ATR)
   double atrVal = 0;
   if(atrHandle != INVALID_HANDLE)
   {
      double a[];
      ArraySetAsSeries(a, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, a) > 0) atrVal = a[0];
   }
   if(atrVal <= 0) atrVal = SymbolInfoDouble(symbol, SYMBOL_POINT) * 30;

   double distSR20 = MathAbs(price - sr20Level);
   if(distSR20 > atrVal * 1.0) { Print("[DOW-SR20] blocked: distSR20=", DoubleToString(distSR20,digits), " > ATR=", DoubleToString(atrVal,digits)); return; } // trop loin du SR20

   //--- 4) Pattern bougie confirme la direction
   if(!SMCPS_PatternGateOK(symbol, dirSign, false)) { Print("[DOW-SR20] blocked: no pattern ", (dirSign>0?"BUY":"SELL")); return; }

   //--- 5) Tous les gates passés → ENTRER
   double slDistancePoints = atrVal * SMCASC_DowSR20SLMult;
   double tpDistancePoints = atrVal * SMCASC_DowSR20TPMult;

   double lot = SMCASC_LotForMaxLoss(symbol, slDistancePoints, SMCASC_MaxLossUSD);
   if(lot <= 0) lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   lot = MathMin(lot, balance / 10.0);
   lot = MathMax(lot, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));

   double entry = (dirSign > 0) ? ask : bid;
   double sl = (dirSign > 0) ? entry - slDistancePoints * point
                              : entry + slDistancePoints * point;
   double tp = (dirSign > 0) ? entry + tpDistancePoints * point
                              : entry - tpDistancePoints * point;

   MqlTradeRequest req = {};
   MqlTradeResult res = {};
   req.action = TRADE_ACTION_DEAL;
   req.symbol = symbol;
   req.volume = lot;
   req.type = (dirSign > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.magic = InpMagicNumber;
   req.deviation = 50;
   req.comment = "DOW SR20";

   if(SafeSafeOrderSend(req, res, req.comment) && res.retcode == TRADE_RETCODE_DONE)
   {
      s_lastDowSR20Trade = TimeCurrent();
      g_smcascDowSR20Count++;

      string dir = (dirSign > 0) ? "BUY" : "SELL";
      string gomLabel = (MathAbs(vn) >= 3) ? "PERFECT" : "GOOD";
      string msg = "⚡ DOW SR20 [" + symbol + "]\n";
      msg += dir + " @ SR20 " + DoubleToString(sr20Level, digits) + "\n";
      msg += "GOM: " + gomLabel + " vn=" + IntegerToString(vn) + "\n";
      msg += "Dow M5: " + DoubleToString(dowM5, 2) + " (swings=" + IntegerToString(swingCount) + ")\n";
      msg += "Entry: " + DoubleToString(entry, digits) + "\n";
      msg += "SL: " + DoubleToString(sl, digits) + " | TP: " + DoubleToString(tp, digits) + "\n";
      msg += "Lot: " + DoubleToString(lot, 2) + " | 1C trades: " + IntegerToString(g_smcascDowSR20Count);
      if(UseNotifications) SendNotification(msg);
      Print("⚡ DOW SR20 ", dir, " ", symbol, " @ ", DoubleToString(entry, digits),
            " | SR20=", DoubleToString(sr20Level, digits),
            " | DowM5=", DoubleToString(dowM5, 2),
            " | GOM vn=", vn, " | pattern=", g_smcps.summary);
   }
   else
   {
       Print("❌ DOW SR20 échec ", symbol, " rc=", res.retcode, " ", res.comment);
    }
}

//+------------------------------------------------------------------+
//| SETUP 1D — Vol Momentum + Fib Retrace                            |
//| Weltrade Volatility Index (FX Vol, SFx Vol, SFV Vol)             |
//| Détecte une chaîne de bars momentum (range > ATR x mult)         |
//| → entrée MARKET au niveau Fib (S/R 20 bars).                     |
//| SL = buffer beyond zone, TP = opposite S/R20.                     |
//+------------------------------------------------------------------+
void SMCASC_TryVolMomentumScalp(const string symbol)
{
   if(!SMCASC_VolMomEnable) return;
   if(SMC_GetSymbolCategory(symbol) != SYM_VOLATILITY) return;
   if(!SMC_IsWeltradeVolSymbol(symbol)) return;
   if(g_smcascVolMomCount >= SMCASC_VolMomMaxTrades) return;

   // Cooldown
   static datetime s_lastVolMomTrade = 0;
   if(TimeCurrent() - s_lastVolMomTrade < SMCASC_VolMomCooldownSec) return;

   // ── 1. ATR M1 ──
   double atrVal = 0;
   if(atrHandle != INVALID_HANDLE)
   {
      double a[];
      ArraySetAsSeries(a, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, a) > 0) atrVal = a[0];
   }
   if(atrVal <= 0) return;

   // ── 2. MOMENTUM BAR CHAIN DETECTION ──
   // Scanne les 20 dernières bougies M1, compte les bars consécutives
   // dont le range (high-low) > ATR x VolMomAtrMult, depuis la plus récente.
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 20, rates) < 20) return;

   int momCount = 0;
   double momDir = 0;
   double momentumThreshold = atrVal * SMCASC_VolMomAtrMult;

   for(int i = 0; i < 18; i++) // i=0 = bougie la plus récente
   {
      double barRange = rates[i].high - rates[i].low;
      if(barRange < momentumThreshold) break; // chaîne brisée

      momCount++;
      // Direction = close > open → haussier
      double barDir = (rates[i].close >= rates[i].open) ? 1.0 : -1.0;
      if(momDir == 0) momDir = barDir; // première bar = direction de la chaîne
      else if(barDir != momDir) break;  // flip de direction = chaîne brisée
   }

   if(momCount < SMCASC_VolMomMinBars) return;

   // Direction = direction de la chaîne momentum
   int dirSign = (int)momDir;

   // ── 3. GOM: juste pas WAIT (vn != 0) ──
   int vn = -999;
   if(g_smcGomConnected) vn = SMCGP_GetCachedVerdictNum(symbol);
   if(vn == -999 && symbol == _Symbol) vn = g_smcGomVerdictNum;
   if(vn == -999) return;
   if(vn == 0) return;

   // ── 4. S/R 20 BARS (Fibonacci levels) ──
   double sup20 = rates[0].low;
   double res20 = rates[0].high;
   for(int i = 1; i < 20; i++)
   {
      if(rates[i].low < sup20) sup20 = rates[i].low;
      if(rates[i].high > res20) res20 = rates[i].high;
   }
   if(res20 <= sup20) return;

   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double bid    = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask    = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double range  = res20 - sup20;

   // ── 5. FIB RETRACE ENTRY ZONE ──
   double fibTolerance = range * SMCASC_VolMomFibTol;

   if(dirSign < 0) // SELL → prix proche résistance (Fib 100%)
   {
      if(ask < res20 - fibTolerance) { Print("[VOL-MOM] blocked: ask=", DoubleToString(ask,digits),
         " trop loin de res20=", DoubleToString(res20,digits)); return; }
   }
   else // BUY → prix proche support (Fib 0%)
   {
      if(bid > sup20 + fibTolerance) { Print("[VOL-MOM] blocked: bid=", DoubleToString(bid,digits),
         " trop loin de sup20=", DoubleToString(sup20,digits)); return; }
   }

   // ── 6. SL/TP basés sur S/R 20 ──
   double bufferPts = range * SMCASC_VolMomSLBuf;
   double entry, sl, tp;

   if(dirSign < 0) // SELL
   {
      entry = ask;
      sl    = res20 + bufferPts;
      tp    = sup20;
   }
   else // BUY
   {
      entry = bid;
      sl    = sup20 - bufferPts;
      tp    = res20;
   }

   // ── 7. LOT FIXE (Weltrade) ──
   double lot = SMC_WeltradeFxVolLot();
   if(lot <= 0) lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   lot = MathMax(lot, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));
   lot = MathMin(lot, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX));

   // ── 8. ORDER MARKET (Weltrade bloque LIMIT pour Vol) ──
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = symbol;
   req.volume    = lot;
   req.type      = (dirSign > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price     = (dirSign > 0) ? ask : bid;
   req.sl        = NormalizeDouble(sl, digits);
   req.tp        = NormalizeDouble(tp, digits);
   req.magic     = InpMagicNumber;
   req.deviation = 50;
   req.comment   = "VOL MOM";

   if(SafeSafeOrderSend(req, res, req.comment) && res.retcode == TRADE_RETCODE_DONE)
   {
      s_lastVolMomTrade = TimeCurrent();
      g_smcascVolMomCount++;

      string dir = (dirSign > 0) ? "BUY" : "SELL";
      string gomLabel = (MathAbs(vn) >= 3) ? "PERFECT" : "GOOD";

      string msg = "⚡ VOL MOM [" + symbol + "]\n";
      msg += dir + " @ " + DoubleToString(entry, digits) + "\n";
      msg += "Chain: " + IntegerToString(momCount) + " bars momentum (ATR x " +
             DoubleToString(SMCASC_VolMomAtrMult, 1) + ")\n";
      msg += "GOM: " + gomLabel + " vn=" + IntegerToString(vn) + "\n";
      msg += "S/R20: [" + DoubleToString(sup20, digits) + " - " + DoubleToString(res20, digits) + "]\n";
      msg += "SL: " + DoubleToString(sl, digits) + " | TP: " + DoubleToString(tp, digits) + "\n";
      msg += "Lot: " + DoubleToString(lot, 2) + " | Vol trades: " + IntegerToString(g_smcascVolMomCount);
      if(UseNotifications) SendNotification(msg);
      Print("⚡ VOL MOM ", dir, " ", symbol, " @ ", DoubleToString(entry, digits),
            " | SR20=[", DoubleToString(sup20,digits), "-", DoubleToString(res20,digits), "]",
            " | Chain=", momCount, " bars | GOM vn=", vn);
   }
   else
   {
      Print("❌ VOL MOM échec ", symbol, " rc=", res.retcode, " ", res.comment);
   }
}

#endif // SMC_AUTO_SCALP_MQH

