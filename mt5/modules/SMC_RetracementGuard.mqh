//+------------------------------------------------------------------+
//| SMC_RetracementGuard.mqh                                          |
//| Détection multi-TF (M1/M5/H1/H4) du début/fin de retracement.    |
//| Fusion: 30 ans = support/résistance 20 bars + Théorie de Dow.    |
//| Bloque TOUT ordre si le prix est en zone de retracement.         |
//+------------------------------------------------------------------+
#ifndef SMC_RETRACEMENT_GUARD_MQH
#define SMC_RETRACEMENT_GUARD_MQH

input bool   SMCGR_Enable              = true;   // Activer le garde-fou retracement
input int    SMCGR_BarsLookback         = 20;     // Bougies pour calcul S/R
input double SMCGR_RetracePctMin        = 20.0;   // % mini tendance pour considérer retracement
input double SMCGR_ResumePctMin         = 15.0;   // % mini reprise sortie retracement
input int    SMCGR_SpikeRetraceMinBars  = 3;      // Bougies M1 contre le creep = retracement spike
input double SMCGR_SpikeRetraceMinATR   = 0.35;  // Mouvement net min (x ATR M1) pour valider retrace spike

// État interne : 1 zone par TF
enum SMCGR_TF { GR_M1, GR_M5, GR_H1, GR_H4, GR_TF_COUNT };

struct SMCGR_Zone
{
   bool   inRetrace;      // true = prix en phase de retracement
   bool   isBuyRetrace;   // true = retracement baissier dans tendance haussière
   double sup20;          // support 20 bars
   double res20;          // résistance 20 bars
   double zoneHigh;       // haut de la zone de blocage
   double zoneLow;        // bas de la zone de blocage
   double entryPrice;     // prix au début du retracement
   datetime startTime;    // timestamp début
};

SMCGR_Zone g_smcgrZones[GR_TF_COUNT];

//+------------------------------------------------------------------+
//| Récupère le support et résistance 20 bars sur une TF donnée.     |
//+------------------------------------------------------------------+
void SMCGR_GetSR20(const string symbol, SMCGR_TF tf, double &sup, double &res)
{
   ENUM_TIMEFRAMES mtf[] = {PERIOD_M1, PERIOD_M5, PERIOD_H1, PERIOD_H4};
   int idx = (int)tf;
   if(idx < 0 || idx >= 4) { sup = 0; res = 0; return; }

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, mtf[idx], 1, SMCGR_BarsLookback, r) < SMCGR_BarsLookback) { sup = 0; res = 0; return; }

   sup = r[0].low; res = r[0].high;
   for(int i = 1; i < SMCGR_BarsLookback; i++)
   {
      if(r[i].low < sup) sup = r[i].low;
      if(r[i].high > res) res = r[i].high;
   }
}

//+------------------------------------------------------------------+
//| Retracement post-spike Boom/Crash : drift M1 contre le creep.    |
//| Boom  = descente lente entre deux spikes haussiers.              |
//| Crash = remontée lente entre deux spikes baissiers.              |
//+------------------------------------------------------------------+
bool SMCGR_IsSpikePostRetrace(const string symbol)
{
   if(!SMCGR_Enable || !SMC_IsSpikeStyleSymbol(symbol)) return false;

   bool isBoom = IsBoomLikeSymbol(symbol);
   bool isCrash = IsCrashLikeSymbol(symbol);
   if(!isBoom && !isCrash) return false;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 10, r) < 6) return false;

   int lookback = MathMax(3, SMCGR_SpikeRetraceMinBars);
   int oppBars = 0;
   double bodySum = 0;
   for(int i = 0; i < lookback; i++)
   {
      bodySum += MathAbs(r[i].close - r[i].open);
      if(isBoom && r[i].close < r[i].open) oppBars++;
      if(isCrash && r[i].close > r[i].open) oppBars++;
   }
   double avgBody = bodySum / (double)lookback;
   if(avgBody <= 0) return false;

   double netMove = r[0].close - r[lookback - 1].close;
   double atrVal = avgBody * 2.5;
   int atrH = iATR(symbol, PERIOD_M1, 14);
   if(atrH != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrH, 0, 1, 1, atrBuf) >= 1 && atrBuf[0] > 0)
         atrVal = atrBuf[0];
      IndicatorRelease(atrH);
   }

   double minMove = atrVal * SMCGR_SpikeRetraceMinATR;
   if(isBoom)
      return (oppBars >= lookback - 1 && netMove < -minMove);
   return (oppBars >= lookback - 1 && netMove > minMove);
}

//+------------------------------------------------------------------+
//| Vérifie si le prix est dans une zone de retracement active.      |
//| Retourne true si BLOQUÉ (prix en retracement).                   |
//+------------------------------------------------------------------+
bool SMCGR_IsInRetracement(const string symbol)
{
   if(!SMCGR_Enable) return false;
   if(SMCGR_IsSpikePostRetrace(symbol)) return true;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double price = (bid + ask) / 2.0;

   for(int i = 0; i < GR_TF_COUNT; i++)
   {
      if(g_smcgrZones[i].inRetrace)
      {
         if(price >= g_smcgrZones[i].zoneLow && price <= g_smcgrZones[i].zoneHigh)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Met à jour la détection de retracement pour tous les TF.         |
//| Appeler à chaque tick (ou chaque nouvelle bougie).               |
//+------------------------------------------------------------------+
void SMCGR_Update(const string symbol)
{
   if(!SMCGR_Enable) return;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double mid = (bid + ask) / 2.0;

   // Déterminer la tendance HTF via GOM (le verdict décide du sens)
   // PRIORITÉ: verdict global actuel sur le cache
   int vn = -999;
   // D'abord vérifier le verdict global actuel
   if(g_smcGomConnected && g_smcGomVerdictNum != 0)
   {
      // Si le verdict global n'est pas WAIT, utiliser le cache pour le symbole spécifique
      vn = SMCGP_GetCachedVerdictNum(symbol);
      if(vn == -999) vn = g_smcGomVerdictNum;
   }
   else if(g_smcGomConnected)
   {
      // Verdict global est WAIT (vn=0) - bloquer immédiatement
      vn = 0;
   }
   bool isSpikeSym = SMC_IsSpikeStyleSymbol(symbol);
   bool isBullTrend = (vn > 0);

   // Verdict WAIT : sur Boom/Crash, la tendance naturelle du symbole prime
   if(vn == 0)
   {
      if(IsBoomLikeSymbol(symbol)) isBullTrend = true;
      else if(IsCrashLikeSymbol(symbol)) isBullTrend = false;
      else return;
   }

    ENUM_TIMEFRAMES mtf[] = {PERIOD_M1, PERIOD_M5, PERIOD_H1, PERIOD_H4};
    for(int i = 0; i < GR_TF_COUNT; i++)
    {
       // M1 classique trop bruité sur spike : détection dédiée via SMCGR_IsSpikePostRetrace
       if(isSpikeSym && i == GR_M1) continue;
       double sup20, res20;
       SMCGR_GetSR20(symbol, (SMCGR_TF)i, sup20, res20);
       g_smcgrZones[i].sup20 = sup20;
       g_smcgrZones[i].res20 = res20;

       if(!g_smcgrZones[i].inRetrace)
       {
          // --- DÉTECTION DÉBUT DE RETRACEMENT ---
          // Tendance haussière : le prix baisse vers le support (retracement haussier)
          // Tendance baissière : le prix monte vers la résistance (retracement baissier)
           bool startRetrace = false;
           bool isBoomLikeSym = IsBoomLikeSymbol(symbol); // GAINX/BOOM: un gain = hausse
           bool isCrashLikeSym = IsCrashLikeSymbol(symbol); // CRASH/PAINX: un gain = baisse
           if(isBullTrend)
           {
              // Retracement haussier : le prix descend (loss de momentum vers le support)
              // POUR GAINX/BOOM: quand le prix baisse durant une hauste/gain, c'est
              // un retracement BAISSIÉ (le gain est haussier, la baisse est baissière)
              if(g_smcgrZones[i].res20 - g_smcgrZones[i].sup20 > 0)
              {
                 double dropPct = (g_smcgrZones[i].res20 - mid) / (g_smcgrZones[i].res20 - g_smcgrZones[i].sup20) * 100.0;
                 if(dropPct >= SMCGR_RetracePctMin && mid < g_smcgrZones[i].res20)
                 {
                    startRetrace = true;
                    // GAINX/BOOM: baisse durant une hausse = baissier (éviter le trade)
                    g_smcgrZones[i].isBuyRetrace = isBoomLikeSym ? false : true;
                 }
              }
           }
           else // bear trend
           {
              // Retracement baissier : le prix monte (gain de momentum vers la résistance)
              // POUR CRASH/PAINX: quand le prix monte durant une baisse, c'est
              // un retracement HAUSSIER (le gain est baissier, la hausse est haussière)
              if(g_smcgrZones[i].res20 - g_smcgrZones[i].sup20 > 0)
              {
                 double risePct = (mid - g_smcgrZones[i].sup20) / (g_smcgrZones[i].res20 - g_smcgrZones[i].sup20) * 100.0;
                 if(risePct >= SMCGR_RetracePctMin && mid > g_smcgrZones[i].sup20)
                 {
                    startRetrace = true;
                    // CRASH/PAINX: hausse durant une baisse = haussier (éviter le trade)
                    g_smcgrZones[i].isBuyRetrace = isCrashLikeSym ? true : false;
                 }
              }
           }

          if(startRetrace)
          {
             g_smcgrZones[i].inRetrace = true;
             g_smcgrZones[i].entryPrice = mid;
             g_smcgrZones[i].startTime = TimeCurrent();
             g_smcgrZones[i].zoneLow = MathMin(g_smcgrZones[i].sup20, mid);
             g_smcgrZones[i].zoneHigh = MathMax(g_smcgrZones[i].res20, mid);
             // Notification début retracement
             // Le label reflète le sens réel du mouvement (isBuyRetrace),
             // pas seulement la tendance (isBullTrend). Sur GAINX, une baisse
              // pendant une hausse est un retracement baissier à éviter.
             string dirLabel = g_smcgrZones[i].isBuyRetrace ? "HAUSSIER" : "BAISSIER";
             string tfLabel = (i==0?"M1":(i==1?"M5":(i==2?"H1":"H4")));
             string msg = "⏳ RETRACEMENT " + dirLabel + " [" + symbol + "]\n";
             msg += "TF: " + tfLabel + " | Entrée: " + DoubleToString(mid, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "\n";
             msg += "Zone: [" + DoubleToString(g_smcgrZones[i].zoneLow, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) +
                    " - " + DoubleToString(g_smcgrZones[i].zoneHigh, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "]\n";
             msg += "Support: " + DoubleToString(sup20, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) +
                    " | Résistance: " + DoubleToString(res20, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
             if(UseNotifications) SendNotification(msg);
             Print("⏳ SMCRG > RETRACEMENT ", dirLabel, " sur ", symbol, " TF=", tfLabel);
          }
       }
       else // g_smcgrZones[i].inRetrace == true
       {
          // --- DÉTECTION FIN DE RETRACEMENT ---
          bool endRetrace = false;
          if(g_smcgrZones[i].isBuyRetrace)
          {
             // Retracement haussier : le prix doit rebondir sur le support et remonter
             if(mid >= g_smcgrZones[i].entryPrice + (g_smcgrZones[i].entryPrice - g_smcgrZones[i].sup20) * 0.5)
                endRetrace = true;
             // Aussi si le prix casse le support par le bas -> échec de retracement (on sort aussi)
             if(mid < g_smcgrZones[i].sup20 * 0.98)
                endRetrace = true;
          }
          else
          {
             // Retracement baissier : le prix doit toucher la résistance et redescendre
             if(mid <= g_smcgrZones[i].entryPrice - (g_smcgrZones[i].res20 - g_smcgrZones[i].entryPrice) * 0.5)
                endRetrace = true;
             // Aussi si le prix casse la résistance par le haut -> échec
             if(mid > g_smcgrZones[i].res20 * 1.02)
                endRetrace = true;
          }

          if(endRetrace)
          {
             g_smcgrZones[i].inRetrace = false;
             string dirLabel = g_smcgrZones[i].isBuyRetrace ? "HAUSSIER" : "BAISSIER";
             string tfLabel = (i==0?"M1":(i==1?"M5":(i==2?"H1":"H4")));
             string msg = "✅ FIN RETRACEMENT " + dirLabel + " [" + symbol + "]\n";
             msg += "TF: " + tfLabel + " | Sortie @ " + DoubleToString(mid, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
             if(UseNotifications) SendNotification(msg);
             Print("✅ SMCRG > FIN RETRACEMENT ", dirLabel, " sur ", symbol, " TF=", tfLabel);
          }
       }
    }
}

//+------------------------------------------------------------------+
//| Dessine les zones de retracement actives sur le graphique.        |
//| Rectangle semi-transparent: vert si haussier, rouge si baissier.  |
//| La zone disparaît quand le prix sort du retracement.             |
//+------------------------------------------------------------------+
void SMCGR_DrawRetracementZones(const string symbol)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   string tfLabel[GR_TF_COUNT] = {"M1", "M5", "H1", "H4"};

   for(int i = 0; i < GR_TF_COUNT; i++)
   {
      string rectName = "SMCGR_ZONE_" + tfLabel[i];
      string textName = "SMCGR_TEXT_" + tfLabel[i];

      ObjectDelete(0, rectName);
      ObjectDelete(0, textName);

      if(!g_smcgrZones[i].inRetrace) continue;

      datetime now = TimeCurrent();
      datetime future = now + PeriodSeconds(PERIOD_M1) * 10;

      color lineColor = g_smcgrZones[i].isBuyRetrace ? clrLime : clrRed;
      uint   fillColor = g_smcgrZones[i].isBuyRetrace
                         ? ColorToARGB(clrLime, 35)
                         : ColorToARGB(clrRed, 35);

      if(ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, now, g_smcgrZones[i].zoneLow, future, g_smcgrZones[i].zoneHigh))
      {
         ObjectSetInteger(0, rectName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
         ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
         ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, rectName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);

         string dirTxt = g_smcgrZones[i].isBuyRetrace ? "▲" : "▼";
         ObjectCreate(0, textName, OBJ_TEXT, 0, now, g_smcgrZones[i].zoneHigh);
         ObjectSetString(0, textName, OBJPROP_TEXT,
                        " " + dirTxt + " RETRACE " + tfLabel[i] +
                        " [" + DoubleToString(g_smcgrZones[i].zoneLow, digits) +
                        " - " + DoubleToString(g_smcgrZones[i].zoneHigh, digits) + "]");
         ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 7);
         ObjectSetInteger(0, textName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, textName, OBJPROP_BACK, false);
         ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
      }
   }
}

//+------------------------------------------------------------------+
//| Nettoie toutes les zones de retracement du graphique.             |
//+------------------------------------------------------------------+
void SMCGR_CleanZones()
{
   ObjectsDeleteAll(0, "SMCGR_ZONE_");
   ObjectsDeleteAll(0, "SMCGR_TEXT_");
}

//+------------------------------------------------------------------+
//| Ferme TOUTES les positions du symbole si en zone de retracement.  |
//| Couvre EA + trades manuels (magic = 0 ou InpMagicNumber).        |
//| Appeler à chaque tick depuis OnTick.                              |
//+------------------------------------------------------------------+
datetime g_smcgrLastCloseTime = 0;
#define SMCGR_CLOSE_COOLDOWN_SEC 5
#define SMCGR_MIN_POS_AGE_SEC   60  // Ne pas fermer les positions de moins de 60s

void SMCGR_ClosePositionsInRetrace(const string symbol, long magicNumber)
{
   if(!SMCGR_Enable) return;

   bool inClassicRetrace = false;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double price = (bid + ask) / 2.0;
   for(int z = 0; z < GR_TF_COUNT; z++)
   {
      if(g_smcgrZones[z].inRetrace &&
         price >= g_smcgrZones[z].zoneLow && price <= g_smcgrZones[z].zoneHigh)
      {
         inClassicRetrace = true;
         break;
      }
   }
   bool inSpikeRetrace = SMCGR_IsSpikePostRetrace(symbol);
   if(!inClassicRetrace && !inSpikeRetrace) return;

   // Cooldown anti-spam
   if(TimeCurrent() - g_smcgrLastCloseTime < SMCGR_CLOSE_COOLDOWN_SEC) return;

   // ── 1) Fermer les positions ouvertes (EA + manuelles) ─────────
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;

       // Accepter magic=0 (manuel) ou notre magic (EA)
       long posMagic = PositionGetInteger(POSITION_MAGIC);
       if(posMagic != 0 && posMagic != magicNumber) continue;

       double volume = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap   = PositionGetDouble(POSITION_SWAP);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Retracement spike : fermer uniquement les positions exposées au drift
      if(inSpikeRetrace)
      {
         if(IsBoomLikeSymbol(symbol) && posType != POSITION_TYPE_BUY) continue;
         if(IsCrashLikeSymbol(symbol) && posType != POSITION_TYPE_SELL) continue;
      }

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action    = TRADE_ACTION_DEAL;
      req.symbol    = symbol;
      req.volume    = volume;
      req.deviation = 50;
      req.magic     = magicNumber;
      req.comment   = "SMCGR_RETRACE_CLOSE";

      if(posType == POSITION_TYPE_BUY)
      {
         req.type  = ORDER_TYPE_SELL;
         req.price = SymbolInfoDouble(symbol, SYMBOL_BID);
      }
      else
      {
         req.type  = ORDER_TYPE_BUY;
         req.price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      }

      if(!SafeOrderSend(req, res))
      {
         Print("[SMCGR] Erreur fermeture ticket #", ticket, " err=", GetLastError());
      }
      else
      {
         string src = (posMagic == 0) ? "MANUEL" : "EA";
         Print("[SMCGR] FERME en RETRACE | #", ticket, " ", src,
               " P/L=", DoubleToString(profit + swap, 2),
               " | zone retracement active");
          g_smcgrLastCloseTime = TimeCurrent();
      }
   }

   // ── 2) Annuler les ordres LIMIT en attente ────────────────
   for(int j = OrdersTotal() - 1; j >= 0; j--)
   {
      ulong ticket = OrderGetTicket(j);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      long oMagic = OrderGetInteger(ORDER_MAGIC);
      if(oMagic != 0 && oMagic != magicNumber) continue;

      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(inSpikeRetrace)
      {
         if(IsBoomLikeSymbol(symbol) && ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_BUY_STOP) continue;
         if(IsCrashLikeSymbol(symbol) && ot != ORDER_TYPE_SELL_LIMIT && ot != ORDER_TYPE_SELL_STOP) continue;
      }

      MqlTradeRequest rm = {};
      MqlTradeResult  rr = {};
      rm.action   = TRADE_ACTION_REMOVE;
      rm.order    = ticket;
      rm.symbol   = symbol;

      if(SafeOrderSend(rm, rr))
         Print("[SMCGR] LIMIT ANNULE en RETRACE | #", ticket,
               inSpikeRetrace ? " (spike drift)" : "");
   }
}

#endif // SMC_RETRACEMENT_GUARD_MQH



