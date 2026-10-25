//+------------------------------------------------------------------+
//| SMC_AdvancedRiskManager.mqh — Gestion avancée du risque          |
//| Pattern Index Synthetics EA + SpikeRider EA                     |
//| Coupe-circuit perte journalière + break-even automatique        |
//+------------------------------------------------------------------+
#ifndef SMC_ADVANCED_RISK_MANAGER_MQH
#define SMC_ADVANCED_RISK_MANAGER_MQH

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

// ── État du gestionnaire de risque journalier ─────────────────────────────
struct SMC_DailyRiskState {
   double dayStartBalance;
   double dayStartEquity;
   double dailyLossLimit;      // Limite de perte journalière ($)
   double dailyProfitTarget;   // Objectif de profit journalier ($)
   double currentDailyPnL;     // PnL journalier actuel
   double currentFloatingPnL;  // PnL flottant actuel
   int tradesToday;            // Nombre de trades aujourd'hui
   int winningTrades;          // Trades gagnants
   int losingTrades;           // Trades perdants
   double maxDrawdownToday;    // Drawdown max aujourd'hui
   bool dailyLossHit;          // Limite de perte atteinte
   bool dailyTargetHit;        // Objectif de profit atteint
   bool tradingStopped;        // Trading arrêté pour la journée
   datetime lastTradeTime;     // Heure du dernier trade
   datetime dayStartTime;      // Heure de début de journée
};

SMC_DailyRiskState g_dailyRiskState;
SMC_GatedTrade g_riskTrade;

// ── État du break-even automatique ────────────────────────────────────────
struct SMC_BreakEvenState {
   bool enabled;
   double triggerATR;          // Déclencheur en ATR (ex: 0.5 ATR)
   double triggerPct;          // Déclencheur en % du SL (ex: 50%)
   double bufferATR;           // Buffer au-dessus du prix d'entrée (ex: 0.1 ATR)
   bool moveOnTPHit;          // Déplacer SL à BE sur TP partiel
   int partialTPPercent;      // % du TP pour déclencher BE (ex: 50%)
};

SMC_BreakEvenState g_beState;

// ── Configuration du gestionnaire de risque ───────────────────────────────
input double InpDailyLossLimitPct   = 5.0;   // Limite perte journalière (% du solde)
input double InpDailyTargetPct     = 5.0;   // Objectif profit journalier (% du solde)
input double InpMaxDrawdownPct     = 3.0;   // Drawdown max journalier (% du solde)
input int    InpMaxTradesPerDay    = 20;    // Nombre max de trades par jour
input bool   InpEnableDailyStop    = true;  // Activer arrêt journalier
input bool   InpEnableBreakEven    = true;  // Activer break-even automatique
input double InpBETriggerATR       = 0.5;   // Déclencheur BE (ATR)
input double InpBEBufferATR        = 0.1;   // Buffer BE (ATR)
input bool   InpBEMoveOnTP         = true;  // Déplacer BE sur TP partiel
input int    InpBEPartialTPPercent = 50;    // % TP pour déclencher BE

// ── Initialiser le gestionnaire de risque journalier ─────────────────────
void SMC_Risk_Init()
{
   g_dailyRiskState.dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyRiskState.dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dailyRiskState.dailyLossLimit = g_dailyRiskState.dayStartBalance * InpDailyLossLimitPct / 100.0;
   g_dailyRiskState.dailyProfitTarget = g_dailyRiskState.dayStartBalance * InpDailyTargetPct / 100.0;
   g_dailyRiskState.currentDailyPnL = 0;
   g_dailyRiskState.currentFloatingPnL = 0;
   g_dailyRiskState.tradesToday = 0;
   g_dailyRiskState.winningTrades = 0;
   g_dailyRiskState.losingTrades = 0;
   g_dailyRiskState.maxDrawdownToday = 0;
   g_dailyRiskState.dailyLossHit = false;
   g_dailyRiskState.dailyTargetHit = false;
   g_dailyRiskState.tradingStopped = false;
   g_dailyRiskState.lastTradeTime = 0;
   g_dailyRiskState.dayStartTime = TimeCurrent();
   
   // Initialiser break-even
   g_beState.enabled = InpEnableBreakEven;
   g_beState.triggerATR = InpBETriggerATR;
   g_beState.triggerPct = 50.0; // 50% du SL par défaut
   g_beState.bufferATR = InpBEBufferATR;
   g_beState.moveOnTPHit = InpBEMoveOnTP;
   g_beState.partialTPPercent = InpBEPartialTPPercent;
   
   Print("🛡️ Risk Manager Initialized - Daily Loss Limit: $", DoubleToString(g_dailyRiskState.dailyLossLimit, 2),
         " | Daily Target: $", DoubleToString(g_dailyRiskState.dailyProfitTarget, 2));
}

// ── Réinitialiser pour une nouvelle journée ───────────────────────────────
void SMC_Risk_ResetDay()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   // Réinitialiser à minuit UTC
   if(dt.hour == 0 && dt.min == 0) {
      SMC_Risk_Init();
      Print("🔄 Risk Manager Reset - New Day");
   }
}

// ── Mettre à jour l'état du risque journalier ─────────────────────────────
void SMC_Risk_Update()
{
   // Réinitialiser si nouvelle journée
   SMC_Risk_ResetDay();
   
   // Calculer le PnL journalier
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   g_dailyRiskState.currentDailyPnL = currentBalance - g_dailyRiskState.dayStartBalance;
   g_dailyRiskState.currentFloatingPnL = currentEquity - currentBalance;
   
   // Calculer le drawdown
   double peakEquity = g_dailyRiskState.dayStartEquity;
   if(currentEquity > peakEquity) peakEquity = currentEquity;
   double drawdown = peakEquity - currentEquity;
   double drawdownPct = (peakEquity > 0) ? (drawdown / peakEquity) * 100.0 : 0;
   
   if(drawdown > g_dailyRiskState.maxDrawdownToday) {
      g_dailyRiskState.maxDrawdownToday = drawdown;
   }
   
   // Vérifier si la limite de perte est atteinte
   if(InpEnableDailyStop && !g_dailyRiskState.dailyLossHit) {
      if(g_dailyRiskState.currentDailyPnL <= -g_dailyRiskState.dailyLossLimit) {
         g_dailyRiskState.dailyLossHit = true;
         g_dailyRiskState.tradingStopped = true;
         Print("🛑 DAILY LOSS LIMIT HIT - Trading stopped for the day. Loss: $", 
               DoubleToString(g_dailyRiskState.currentDailyPnL, 2));
         
         // Fermer toutes les positions ouvertes
         SMC_Risk_CloseAllPositions("Daily loss limit hit");
      }
   }
   
   // Vérifier si l'objectif de profit est atteint
   if(InpEnableDailyStop && !g_dailyRiskState.dailyTargetHit) {
      if(g_dailyRiskState.currentDailyPnL >= g_dailyRiskState.dailyProfitTarget) {
         g_dailyRiskState.dailyTargetHit = true;
         Print("🎯 DAILY TARGET HIT - Profit: $", DoubleToString(g_dailyRiskState.currentDailyPnL, 2));
         // Optionnel: continuer à trader ou arrêter
      }
   }
   
   // Vérifier le drawdown max
   if(drawdownPct >= InpMaxDrawdownPct) {
      g_dailyRiskState.tradingStopped = true;
      Print("🛑 MAX DRAWDOWN HIT - Trading stopped. Drawdown: ", DoubleToString(drawdownPct, 2), "%");
      SMC_Risk_CloseAllPositions("Max drawdown hit");
   }
   
   // Vérifier le nombre max de trades
   if(g_dailyRiskState.tradesToday >= InpMaxTradesPerDay) {
      g_dailyRiskState.tradingStopped = true;
      Print("🛑 MAX TRADES PER DAY HIT - Trading stopped. Trades: ", g_dailyRiskState.tradesToday);
   }
}

// ── Vérifier si le trading est autorisé ───────────────────────────────────
bool SMC_Risk_AllowTrade()
{
   SMC_Risk_Update();
   
   if(g_dailyRiskState.tradingStopped) {
      Print("🚫 Trading stopped for the day");
      return false;
   }
   
   if(g_dailyRiskState.dailyLossHit) {
      Print("🚫 Daily loss limit already hit");
      return false;
   }
   
   return true;
}

// ── Enregistrer un trade ───────────────────────────────────────────────────
void SMC_Risk_RecordTrade(double profit)
{
   g_dailyRiskState.tradesToday++;
   g_dailyRiskState.lastTradeTime = TimeCurrent();
   
   if(profit > 0) {
      g_dailyRiskState.winningTrades++;
   } else {
      g_dailyRiskState.losingTrades++;
   }
   
   Print("📊 Trade recorded - Total: ", g_dailyRiskState.tradesToday,
         " | Wins: ", g_dailyRiskState.winningTrades,
         " | Losses: ", g_dailyRiskState.losingTrades);
}

// ── Fermer toutes les positions ───────────────────────────────────────────
void SMC_Risk_CloseAllPositions(const string reason)
{
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(pos.SelectByIndex(i)) {
         if(pos.Symbol() == _Symbol) {
            // AUDIT C7: l'ancien code OUVRAIT des ordres inverse (hedge) au
            // lieu de fermer. On ferme maintenant la position elle-même.
            if(pos.PositionType() == POSITION_TYPE_BUY || pos.PositionType() == POSITION_TYPE_SELL) {
               g_riskTrade.PositionClose(pos.Ticket());
            }
         }
      }
   }
}

// ── Gérer le break-even automatique pour une position ─────────────────────
void SMC_Risk_ManageBreakEven(const ulong ticket)
{
   if(!g_beState.enabled) return;
   
   CPositionInfo pos;
   if(!pos.SelectByTicket(ticket)) return;
   if(pos.Magic() != 0 && InpMagicNumber != 0 && pos.Magic() != InpMagicNumber)
      return;

   double openPrice = pos.PriceOpen();
   double currentSL = pos.StopLoss();
   double currentTP = pos.TakeProfit();
   string sym = pos.Symbol();
   int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   double profit = pos.Profit() + pos.Swap() + pos.Commission();

   // Breakeven dès +0.25$ — pas d'attente ATR (iATR handle cassait le BE).
   if(profit < 0.25) return;

   double buffer = MathMax(pt * 10.0, pt);
   double newSL;
   if(pos.PositionType() == POSITION_TYPE_BUY)
   {
      newSL = NormalizeDouble(openPrice + buffer, dg);
      if(currentSL > 0 && newSL <= currentSL) return;
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      if(newSL >= bid) return;
   }
   else
   {
      newSL = NormalizeDouble(openPrice - buffer, dg);
      if(currentSL > 0 && newSL >= currentSL) return;
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      if(newSL <= ask) return;
   }

   if(g_riskTrade.PositionModify(ticket, newSL, currentTP))
      Print("🔄 Break-even #", ticket, " ", sym, " P/L=$", DoubleToString(profit, 2),
            " SL→", DoubleToString(newSL, dg));
}

// ── Gérer le break-even pour toutes les positions ─────────────────────────
void SMC_Risk_ManageAllBreakEven()
{
   if(!g_beState.enabled) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      CPositionInfo pos;
      if(pos.SelectByIndex(i)) {
         SMC_Risk_ManageBreakEven(pos.Ticket());
      }
   }
}

// ── Obtenir l'état du risque journalier ───────────────────────────────────
SMC_DailyRiskState SMC_Risk_GetState()
{
   SMC_Risk_Update();
   return g_dailyRiskState;
}

// ── Obtenir le PnL journalier ─────────────────────────────────────────────
double SMC_Risk_GetDailyPnL()
{
   SMC_Risk_Update();
   return g_dailyRiskState.currentDailyPnL;
}

// ── Obtenir le drawdown journalier ────────────────────────────────────────
double SMC_Risk_GetDailyDrawdown()
{
   SMC_Risk_Update();
   return g_dailyRiskState.maxDrawdownToday;
}

// ── Vérifier si la limite de perte est atteinte ───────────────────────────
bool SMC_Risk_IsDailyLossHit()
{
   SMC_Risk_Update();
   return g_dailyRiskState.dailyLossHit;
}

// ── Vérifier si l'objectif de profit est atteint ─────────────────────────
bool SMC_Risk_IsDailyTargetHit()
{
   SMC_Risk_Update();
   return g_dailyRiskState.dailyTargetHit;
}

// ── Afficher le dashboard de risque ───────────────────────────────────────
void SMC_Risk_ShowDashboard()
{
   SMC_Risk_Update();
   
   int y = 50;
   int s = 15;
   
   ObjectCreate(0, "RISK_DAILY_PNL", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "RISK_DAILY_PNL", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "RISK_DAILY_PNL", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "RISK_DAILY_PNL", OBJPROP_YDISTANCE, y);
   ObjectSetString(0, "RISK_DAILY_PNL", OBJPROP_TEXT, 
                    StringFormat("Daily PnL: $%+.2f", g_dailyRiskState.currentDailyPnL));
   ObjectSetInteger(0, "RISK_DAILY_PNL", OBJPROP_COLOR, 
                    (g_dailyRiskState.currentDailyPnL >= 0) ? clrLime : clrRed);
   y += s;
   
   ObjectCreate(0, "RISK_DAILY_LIMIT", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "RISK_DAILY_LIMIT", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "RISK_DAILY_LIMIT", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "RISK_DAILY_LIMIT", OBJPROP_YDISTANCE, y);
   ObjectSetString(0, "RISK_DAILY_LIMIT", OBJPROP_TEXT, 
                    StringFormat("Limit: -$%.2f / Target: +$%.2f", 
                                g_dailyRiskState.dailyLossLimit, 
                                g_dailyRiskState.dailyProfitTarget));
   y += s;
   
   ObjectCreate(0, "RISK_TRADES", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "RISK_TRADES", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "RISK_TRADES", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "RISK_TRADES", OBJPROP_YDISTANCE, y);
   ObjectSetString(0, "RISK_TRADES", OBJPROP_TEXT, 
                    StringFormat("Trades: %d (W:%d L:%d)", 
                                g_dailyRiskState.tradesToday,
                                g_dailyRiskState.winningTrades,
                                g_dailyRiskState.losingTrades));
   y += s;
   
   ObjectCreate(0, "RISK_DRAWDOWN", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "RISK_DRAWDOWN", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "RISK_DRAWDOWN", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "RISK_DRAWDOWN", OBJPROP_YDISTANCE, y);
   ObjectSetString(0, "RISK_DRAWDOWN", OBJPROP_TEXT, 
                    StringFormat("Max DD: $%.2f", g_dailyRiskState.maxDrawdownToday));
    ObjectSetInteger(0, "RISK_DRAWDOWN", OBJPROP_COLOR, 
                     (g_dailyRiskState.maxDrawdownToday < g_dailyRiskState.dailyLossLimit) ? clrLime : clrRed);
}

void SMC_Risk_Deinit()
{
   g_dailyRiskState.tradingStopped = false;
   g_beState.enabled = false;
}

void SMC_Risk_UpdateBreakEven()
{
   SMC_Risk_ManageAllBreakEven();
}

#endif
