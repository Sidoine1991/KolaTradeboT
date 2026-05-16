//+------------------------------------------------------------------+
//| SMC_DASHBOARD_PRO - PROFESSIONAL TRADING DASHBOARD             |
//| Focus: P&L + RISK | Style: Trading Pro (TradingView-like)       |
//+------------------------------------------------------------------+

#property copyright "TradBOT IA"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| CONFIGURATION                                                    |
//+------------------------------------------------------------------+

input bool   EnablePrDashboard       = true;              // Active le dashboard
input int    DashboardRefreshMs      = 1000;             // Refresh rate (ms)
input bool   ShowPortfolioStats      = true;             // Afficher stats portefeuille
input bool   ShowRiskMetrics         = true;             // Afficher métriques risque
input bool   ShowTradeHistory        = true;             // Afficher dernières trades
input bool   ShowSignalsTable        = true;             // Afficher tableau signaux
input int    MaxTradesHistoryDisplay = 10;               // Nombre de trades à afficher

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

datetime lastDashboardUpdate = 0;
string lastDashboardText = "";

struct PortfolioStats {
   double totalPnL;
   double dailyPnL;
   double monthlyPnL;
   double winRate;
   int totalTrades;
   int winningTrades;
   int losingTrades;
};

struct RiskMetrics {
   double maxDrawdown;
   double currentDD;
   double riskReward;
   double sharpe;
   double exposure;
};

//+------------------------------------------------------------------+
//| DASHBOARD PRINCIPAL                                             |
//+------------------------------------------------------------------+

void DrawProDashboard()
{
   if(!EnablePrDashboard) return;
   if(TimeCurrent() * 1000 - lastDashboardUpdate < DashboardRefreshMs) return;

   lastDashboardUpdate = TimeCurrent() * 1000;

   // Récupérer les stats
   PortfolioStats stats = GetPortfolioStats();
   RiskMetrics risk = GetRiskMetrics();

   // Construire le texte du dashboard
   string dash = "";

   // Header
   dash += "════════════════════════════════════════════════════════\n";
   dash += "  🤖 TRADBOT IA | PROFESSIONAL DASHBOARD\n";
   dash += "════════════════════════════════════════════════════════\n";
   dash += "  Time: " + TimeToString(TimeCurrent(), TIME_MINUTES|TIME_SECONDS) + "\n";
   dash += "════════════════════════════════════════════════════════\n\n";

   // SECTION 1: P&L PRINCIPAL
   dash += "┌─ 💰 PORTFOLIO P&L ─────────────────────────────────────┐\n";
   dash += "│\n";
   dash += "│  Total P&L:     " + FormatPnL(stats.totalPnL) + " " + FormatColor(stats.totalPnL) + "\n";
   dash += "│  Daily P&L:     " + FormatPnL(stats.dailyPnL) + " " + FormatColor(stats.dailyPnL) + "\n";
   dash += "│  Monthly P&L:   " + FormatPnL(stats.monthlyPnL) + " " + FormatColor(stats.monthlyPnL) + "\n";
   dash += "│  Win Rate:      " + DoubleToString(stats.winRate * 100, 1) + "% (" + IntegerToString(stats.winningTrades) + "/" + IntegerToString(stats.totalTrades) + ")\n";
   dash += "│\n";
   dash += "└────────────────────────────────────────────────────────┘\n\n";

   // SECTION 2: RISK METRICS
   if(ShowRiskMetrics)
   {
      dash += "┌─ ⚠️  RISK METRICS ──────────────────────────────────────┐\n";
      dash += "│\n";
      dash += "│  Max Drawdown:  " + DoubleToString(risk.maxDrawdown * 100, 2) + "% / " + DoubleToString(risk.currentDD * 100, 2) + "%\n";
      dash += "│  Exposure:      " + DoubleToString(risk.exposure * 100, 1) + "% of Balance\n";
      dash += "│  Risk/Reward:   1:" + DoubleToString(risk.riskReward, 2) + "\n";
      dash += "│  Sharpe Ratio:  " + DoubleToString(risk.sharpe, 2) + "\n";
      dash += "│\n";
      dash += "└────────────────────────────────────────────────────────┘\n\n";
   }

   // SECTION 3: POSITIONS ACTUELLES
   dash += "┌─ 📊 OPEN POSITIONS ────────────────────────────────────┐\n";
   dash += "│\n";

   int posCount = PositionsTotal();
   if(posCount > 0)
   {
      for(int i = 0; i < posCount; i++)
      {
         if(!PositionSelectByTicket(PositionGetTicket(i))) continue;

         string symbol = PositionGetString(POSITION_SYMBOL);
         double volume = PositionGetDouble(POSITION_VOLUME);
         double price = PositionGetDouble(POSITION_PRICE_OPEN);
         double pnl = PositionGetDouble(POSITION_PROFIT);
         int type = (int)PositionGetInteger(POSITION_TYPE);

         string dir = (type == POSITION_TYPE_BUY) ? "LONG" : "SHORT";

         dash += "│  " + symbol + " " + dir + " | Vol:" + DoubleToString(volume, 2) +
                " | Entry:" + DoubleToString(price, 5) + " | PnL:" + FormatPnL(pnl) + " " + FormatColor(pnl) + "\n";
      }
   }
   else
   {
      dash += "│  ❌ No open positions\n";
   }
   dash += "│\n";
   dash += "└────────────────────────────────────────────────────────┘\n\n";

   // SECTION 4: AI SIGNALS
   dash += "┌─ 🤖 AI SIGNALS ────────────────────────────────────────┐\n";
   dash += "│\n";
   dash += "│  Signal: [AI Signal Here]\n";
   dash += "│  Confidence: [Confidence %]\n";
   dash += "│\n";
   dash += "└────────────────────────────────────────────────────────┘\n";

   // Mettre à jour l'objet texte
   if(dash != lastDashboardText)
   {
      lastDashboardText = dash;
      UpdateDashboardObject(dash);
   }
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                |
//+------------------------------------------------------------------+

PortfolioStats GetPortfolioStats()
{
   PortfolioStats stats;
   stats.totalPnL = 0;
   stats.dailyPnL = 0;
   stats.monthlyPnL = 0;
   stats.totalTrades = 0;
   stats.winningTrades = 0;
   stats.losingTrades = 0;

   // Compter positions ouvertes
   int posCount = PositionsTotal();
   for(int i = 0; i < posCount; i++)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      stats.totalPnL += PositionGetDouble(POSITION_PROFIT);
   }

   // Compter deals fermés (historique)
   int dealCount = HistoryDealsTotal();
   datetime today = TimeCurrent() - (TimeCurrent() % 86400);
   datetime monthStart = TimeCurrent() - ((TimeCurrent() % 2592000));

   for(int i = 0; i < dealCount; i++)
   {
      if(!HistoryDealSelect(i)) continue;

      double profit = HistoryDealGetDouble(i, DEAL_PROFIT);
      datetime time = (datetime)HistoryDealGetInteger(i, DEAL_TIME);

      if(profit != 0)
      {
         stats.totalTrades++;
         if(profit > 0)
            stats.winningTrades++;
         else
            stats.losingTrades++;

         if(time >= today)
            stats.dailyPnL += profit;

         if(time >= monthStart)
            stats.monthlyPnL += profit;
      }
   }

   if(stats.totalTrades > 0)
      stats.winRate = (double)stats.winningTrades / stats.totalTrades;

   return stats;
}

RiskMetrics GetRiskMetrics()
{
   RiskMetrics risk;
   risk.maxDrawdown = 0;
   risk.currentDD = 0;
   risk.riskReward = 1.0;
   risk.sharpe = 0;
   risk.exposure = 0;

   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(accountBalance > 0)
      risk.currentDD = (1 - accountEquity / accountBalance);

   // Calculer l'exposition totale
   int posCount = PositionsTotal();
   for(int i = 0; i < posCount; i++)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      double posValue = PositionGetDouble(POSITION_VOLUME) * PositionGetDouble(POSITION_PRICE_OPEN);
      risk.exposure += posValue;
   }

   if(accountBalance > 0)
      risk.exposure /= accountBalance;

   return risk;
}

string FormatPnL(double value)
{
   string sign = (value >= 0) ? "+" : "";
   return sign + DoubleToString(value, 2) + "$";
}

string FormatColor(double value)
{
   return (value >= 0) ? "🟢" : "🔴";
}

void UpdateDashboardObject(string text)
{
   if(ObjectFind(0, "PRO_DASHBOARD") == -1)
   {
      ObjectCreate(0, "PRO_DASHBOARD", OBJ_LABEL, 0, 0, 0);
   }

   ObjectSetInteger(0, "PRO_DASHBOARD", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "PRO_DASHBOARD", OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, "PRO_DASHBOARD", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "PRO_DASHBOARD", OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, "PRO_DASHBOARD", OBJPROP_FONT, "Courier New");
   ObjectSetInteger(0, "PRO_DASHBOARD", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "PRO_DASHBOARD", OBJPROP_BACK, false);
   ObjectSetString(0, "PRO_DASHBOARD", OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| EVENT HANDLERS                                                   |
//+------------------------------------------------------------------+

void OnTick()
{
   DrawProDashboard();
}

int OnInit()
{
   Print("✅ SMC Professional Dashboard initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectDelete(0, "PRO_DASHBOARD");
}
