//+------------------------------------------------------------------+
//| Properties & Includes                                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Professional Trading EA"
#property link      "https://www.mql5.com"
#property version   "3.00"
#property description "Spike Hunter - Trading professionnel et securise"

//--- Includes
#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>

//--- Variables globales pour la gestion des cooldowns
static int g_consecutiveLosses = 0;
static int g_consecutiveWins = 0;
static datetime g_cooldownEndTime = 0;
static bool g_inCooldown = false;

//--- Variables globales pour le trading automatique
static datetime g_lastSignalTime = 0;
static int g_pendingOrdersCount = 0;
static double g_lastSignalPrice = 0;
static int g_lastSignalDirection = 0;
static bool g_autoTradingEnabled = true;
static datetime g_lastOrderTime = 0;

//+------------------------------------------------------------------+
//| Structures pour le calcul de performance                        |
//+------------------------------------------------------------------+

// Structure pour les données de performance journalières
struct DailyPerformanceData {
    datetime date;                    // Date du jour
    double equity;                    // Équité actuelle
    int winning_trades;               // Nombre de trades gagnants
    int losing_trades;                // Nombre de trades perdants
    double daily_profit;              // Profit total du jour
    double daily_loss;                // Perte totale du jour
    double net_profit;                // Profit net du jour
    double roe;                       // Return on Equity
    double win_rate;                  // Taux de réussite
    double profit_factor;             // Facteur de profit
    double performance_score;         // Score de performance (0-100)
};

// Structure pour le calculateur de performance
struct PerformanceCalculator {
    double initial_capital;           // Capital initial
    DailyPerformanceData daily_data[365]; // Historique des 365 derniers jours
    int data_count;                   // Nombre de données stockées
    double performance_history[365];  // Historique des scores
    datetime last_update;             // Dernière mise à jour
};

// Variables globales pour la performance
PerformanceCalculator g_performance_calc;

//+------------------------------------------------------------------+
//| Fonctions de calcul de performance                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialiser le calculateur de performance                       |
//+------------------------------------------------------------------+
void InitializePerformanceCalculator()
{
    // Utiliser le capital initial du compte MT5 connecté ou la valeur paramètre
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(account_balance > 0 && InpInitialCapital <= 0) {
        g_performance_calc.initial_capital = account_balance;
        Print("✅ Capital initial détecté depuis le compte MT5: $", DoubleToString(account_balance, 2));
    } else {
        g_performance_calc.initial_capital = InpInitialCapital;
        Print("✅ Capital initial configuré: $", DoubleToString(InpInitialCapital, 2));
    }
    
    g_performance_calc.data_count = 0;
    g_performance_calc.last_update = 0;
    
    // Obtenir les informations du compte MT5
    long account_number = AccountInfoInteger(ACCOUNT_LOGIN);
    string account_server = AccountInfoString(ACCOUNT_SERVER);
    string account_name = AccountInfoString(ACCOUNT_NAME);
    string account_currency = AccountInfoString(ACCOUNT_CURRENCY);
    
    // Initialiser les tableaux
    for(int i = 0; i < 365; i++) {
        g_performance_calc.daily_data[i].date = 0;
        g_performance_calc.daily_data[i].equity = 0;
        g_performance_calc.daily_data[i].winning_trades = 0;
        g_performance_calc.daily_data[i].losing_trades = 0;
        g_performance_calc.daily_data[i].daily_profit = 0;
        g_performance_calc.daily_data[i].daily_loss = 0;
        g_performance_calc.daily_data[i].net_profit = 0;
        g_performance_calc.daily_data[i].roe = 0;
        g_performance_calc.daily_data[i].win_rate = 0;
        g_performance_calc.daily_data[i].profit_factor = 0;
        g_performance_calc.daily_data[i].performance_score = 0;
        g_performance_calc.performance_history[i] = 0;
    }
    
    Print("✅ Calculateur de performance MT5 initialisé");
    Print("   Compte: #", IntegerToString(account_number), " (", account_server, ")");
    Print("   Nom: ", account_name);
    Print("   Devise: ", account_currency);
    Print("   Capital initial: $", DoubleToString(g_performance_calc.initial_capital, 2));
}

//+------------------------------------------------------------------+
//| Calculer le Return on Equity (ROE)                              |
//+------------------------------------------------------------------+
double CalculateROE(double equity)
{
    if(g_performance_calc.initial_capital <= 0) return 0.0;
    return (equity - g_performance_calc.initial_capital) / g_performance_calc.initial_capital;
}

//+------------------------------------------------------------------+
//| Calculer le taux de réussite (Win Rate)                         |
//+------------------------------------------------------------------+
double CalculateWinRate(int winning_trades, int losing_trades)
{
    int total_trades = winning_trades + losing_trades;
    if(total_trades == 0) return 0.0;
    return (double)winning_trades / (double)total_trades;
}

//+------------------------------------------------------------------+
//| Calculer le Profit Factor                                       |
//+------------------------------------------------------------------+
double CalculateProfitFactor(double daily_profit, double daily_loss)
{
    if(daily_loss == 0) {
        return (daily_profit > 0) ? daily_profit : 0.0;
    }
    return daily_profit / daily_loss;
}

//+------------------------------------------------------------------+
//| Calculer le score de performance synthétique amélioré           |
//+------------------------------------------------------------------+
double CalculatePerformanceScore(double roe, double win_rate, double profit_factor)
{
    // Normalisation du profit factor entre 0 et 1
    double pf_normalized = 0.0;
    if(profit_factor >= 0) {
        pf_normalized = profit_factor / (1.0 + profit_factor);
    }
    
    // Score de base : 30% ROE + 25% Win Rate + 25% Profit Factor normalisé
    double base_score = 100.0 * (0.3 * roe + 0.25 * win_rate + 0.25 * pf_normalized);
    
    return NormalizeDouble(base_score, 2);
}

//+------------------------------------------------------------------+
//| Calculer le score de performance avancé avec stabilité          |
//+------------------------------------------------------------------+
double CalculateAdvancedPerformanceScore(double roe, double win_rate, double profit_factor, 
                                        double current_equity, double current_balance, 
                                        double daily_profit, double daily_loss, 
                                        double &performance_history[], int history_count)
{
    // Score de base
    double base_score = CalculatePerformanceScore(roe, win_rate, profit_factor);
    
    // 1. Facteur de stabilité (20% du score total)
    double stability_score = CalculateStabilityScore(performance_history, history_count);
    
    // 2. Facteur de drawdown (15% du score total)
    double drawdown_score = CalculateDrawdownScore(current_equity, current_balance);
    
    // 3. Facteur de régularité des profits (10% du score total)
    double consistency_score = CalculateConsistencyScore(daily_profit, daily_loss);
    
    // Score final pondéré avec paramètres configurables
    double final_score = (InpBaseScoreWeight * base_score) + 
                        (InpStabilityWeight * stability_score) + 
                        (InpDrawdownWeight * drawdown_score) + 
                        (InpConsistencyWeight * consistency_score);
    
    return NormalizeDouble(final_score, 2);
}

//+------------------------------------------------------------------+
//| Calculer le score de stabilité basé sur l'historique            |
//+------------------------------------------------------------------+
double CalculateStabilityScore(double &performance_history[], int history_count)
{
    if(history_count < 7) return 50.0; // Score neutre si pas assez de données
    
    // Calculer la variance des 7 derniers scores
    double sum = 0.0;
    for(int i = history_count - 7; i < history_count; i++) {
        sum += performance_history[i];
    }
    double mean = sum / 7.0;
    
    double variance = 0.0;
    for(int i = history_count - 7; i < history_count; i++) {
        double diff = performance_history[i] - mean;
        variance += diff * diff;
    }
    variance /= 7.0;
    
    double std_dev = MathSqrt(variance);
    
    // Score de stabilité : plus la variance est faible, plus le score est élevé
    double stability = MathMax(0, 100 - (std_dev * InpStabilityPenalty)); // Pénalité configurable par écart-type
    
    return NormalizeDouble(stability, 2);
}

//+------------------------------------------------------------------+
//| Calculer le score de drawdown                                  |
//+------------------------------------------------------------------+
double CalculateDrawdownScore(double current_equity, double current_balance)
{
    if(current_balance <= 0) return 0.0;
    
    double drawdown_percent = ((current_balance - current_equity) / current_balance) * 100;
    
    // Score basé sur le drawdown : 0% = 100 points, seuil configurable
    double drawdown_score = MathMax(0, 100 - (drawdown_percent * (100.0 / InpMaxDrawdownThreshold)));
    
    return NormalizeDouble(drawdown_score, 2);
}

//+------------------------------------------------------------------+
//| Calculer le score de régularité des profits                    |
//+------------------------------------------------------------------+
double CalculateConsistencyScore(double daily_profit, double daily_loss)
{
    if(daily_profit <= 0 && daily_loss <= 0) return 50.0; // Score neutre si pas de trades
    
    // Ratio profit/loss pour la journée
    double daily_ratio = 0.0;
    if(daily_loss > 0) {
        daily_ratio = daily_profit / daily_loss;
    } else if(daily_profit > 0) {
        daily_ratio = 10.0; // Très bon si pas de pertes
    }
    
    // Score basé sur la régularité : ratio stable = bon score
    double consistency = MathMin(100, daily_ratio * 20); // 20 points par unité de ratio
    
    return NormalizeDouble(consistency, 2);
}

//+------------------------------------------------------------------+
//| Mettre à jour les données de performance journalières           |
//+------------------------------------------------------------------+
void UpdateDailyPerformance()
{
    if(!InpEnablePerformanceTracking) return;
    
    datetime current_time = TimeCurrent();
    datetime current_date = StringToTime(TimeToString(current_time, TIME_DATE));
    
    // Vérifier si on doit mettre à jour (toutes les X minutes)
    if(current_time - g_performance_calc.last_update < InpPerformanceUpdateMinutes * 60) {
        return;
    }
    
    // Obtenir les données réelles du compte MT5 connecté
    double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double current_margin = AccountInfoDouble(ACCOUNT_MARGIN);
    double current_free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double current_margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    
    // Obtenir les informations du compte
    string account_name = AccountInfoString(ACCOUNT_NAME);
    string account_server = AccountInfoString(ACCOUNT_SERVER);
    long account_number = AccountInfoInteger(ACCOUNT_LOGIN);
    string account_currency = AccountInfoString(ACCOUNT_CURRENCY);
    
    // Compter les trades du jour pour ce magic number spécifique
    int winning_trades = 0;
    int losing_trades = 0;
    double daily_profit = 0.0;
    double daily_loss = 0.0;
    int total_trades_today = 0;
    
    // Analyser l'historique des trades du jour
    if(HistorySelect(current_date, current_time)) {
        int total_deals = HistoryDealsTotal();
        for(int i = 0; i < total_deals; i++) {
            ulong deal_ticket = HistoryDealGetTicket(i);
            if(deal_ticket > 0) {
                long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
                if(deal_magic == InpMagicNumber) {
                    double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
                    double deal_commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
                    double deal_swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
                    double deal_fee = HistoryDealGetDouble(deal_ticket, DEAL_FEE);
                    
                    // Profit net = profit + commission + swap + fee
                    double net_profit = deal_profit + deal_commission + deal_swap + deal_fee;
                    
                    total_trades_today++;
                    
                    if(net_profit > 0) {
                        winning_trades++;
                        daily_profit += net_profit;
                    } else if(net_profit < 0) {
                        losing_trades++;
                        daily_loss += MathAbs(net_profit);
                    }
                }
            }
        }
    }
    
    // Obtenir les positions ouvertes actuelles
    int open_positions = 0;
    double unrealized_pnl = 0.0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetTicket(i) > 0) {
            long pos_magic = PositionGetInteger(POSITION_MAGIC);
            if(pos_magic == InpMagicNumber) {
                open_positions++;
                unrealized_pnl += PositionGetDouble(POSITION_PROFIT);
            }
        }
    }
    
    // Calculer les métriques de performance
    double net_profit = daily_profit - daily_loss;
    double roe = CalculateROE(current_equity);
    double win_rate = CalculateWinRate(winning_trades, losing_trades);
    double profit_factor = CalculateProfitFactor(daily_profit, daily_loss);
    
    // Utiliser le score de performance avancé ou basique selon la configuration
    double performance_score;
    if(InpUseAdvancedScoring) {
        performance_score = CalculateAdvancedPerformanceScore(roe, win_rate, profit_factor,
                                                            current_equity, current_balance,
                                                            daily_profit, daily_loss,
                                                            g_performance_calc.performance_history,
                                                            g_performance_calc.data_count);
    } else {
        performance_score = CalculatePerformanceScore(roe, win_rate, profit_factor);
    }
    
    // Calculer des métriques supplémentaires du compte MT5
    double margin_utilization = (current_margin > 0) ? (current_margin / current_equity) * 100 : 0;
    double drawdown = (current_balance > 0) ? ((current_balance - current_equity) / current_balance) * 100 : 0;
    double profit_per_trade = (total_trades_today > 0) ? net_profit / total_trades_today : 0;
    
    // Trouver l'index pour aujourd'hui ou créer une nouvelle entrée
    int today_index = -1;
    for(int i = 0; i < g_performance_calc.data_count; i++) {
        if(g_performance_calc.daily_data[i].date == current_date) {
            today_index = i;
            break;
        }
    }
    
    // Si pas trouvé, créer une nouvelle entrée
    if(today_index == -1) {
        if(g_performance_calc.data_count < 365) {
            today_index = g_performance_calc.data_count;
            g_performance_calc.data_count++;
        } else {
            // Décaler les données (FIFO)
            for(int i = 0; i < 364; i++) {
                g_performance_calc.daily_data[i] = g_performance_calc.daily_data[i + 1];
                g_performance_calc.performance_history[i] = g_performance_calc.performance_history[i + 1];
            }
            today_index = 364;
        }
    }
    
    // Mettre à jour les données avec les informations réelles du compte MT5
    g_performance_calc.daily_data[today_index].date = current_date;
    g_performance_calc.daily_data[today_index].equity = current_equity;
    g_performance_calc.daily_data[today_index].winning_trades = winning_trades;
    g_performance_calc.daily_data[today_index].losing_trades = losing_trades;
    g_performance_calc.daily_data[today_index].daily_profit = daily_profit;
    g_performance_calc.daily_data[today_index].daily_loss = daily_loss;
    g_performance_calc.daily_data[today_index].net_profit = net_profit;
    g_performance_calc.daily_data[today_index].roe = roe;
    g_performance_calc.daily_data[today_index].win_rate = win_rate;
    g_performance_calc.daily_data[today_index].profit_factor = profit_factor;
    g_performance_calc.daily_data[today_index].performance_score = performance_score;
    
    g_performance_calc.performance_history[today_index] = performance_score;
    g_performance_calc.last_update = current_time;
    
    // Calculer les scores détaillés pour l'affichage
    double stability_score = CalculateStabilityScore(g_performance_calc.performance_history, g_performance_calc.data_count);
    double drawdown_score = CalculateDrawdownScore(current_equity, current_balance);
    double consistency_score = CalculateConsistencyScore(daily_profit, daily_loss);
    
    // Afficher les informations de performance détaillées du compte MT5
    Print("📊 PERFORMANCE MT5 AVANCÉE - Compte: ", IntegerToString(account_number), " (", account_server, ")");
    Print("   💰 Équité: $", DoubleToString(current_equity, 2), 
          " | Balance: $", DoubleToString(current_balance, 2),
          " | Marge: $", DoubleToString(current_margin, 2));
    Print("   📈 Score Total: ", DoubleToString(performance_score, 2),
          " | ROE: ", DoubleToString(roe * 100, 2), "%",
          " | Win Rate: ", DoubleToString(win_rate * 100, 2), "%");
    Print("   🎯 Trades: ", IntegerToString(winning_trades), "W/", IntegerToString(losing_trades), "L",
          " | Profit: $", DoubleToString(net_profit, 2),
          " | PF: ", DoubleToString(profit_factor, 2));
    Print("   📊 Positions ouvertes: ", IntegerToString(open_positions),
          " | PnL non réalisé: $", DoubleToString(unrealized_pnl, 2));
    Print("   ⚠️  Drawdown: ", DoubleToString(drawdown, 2), "%",
          " | Utilisation marge: ", DoubleToString(margin_utilization, 2), "%");
    Print("   🔧 Scores détaillés - Stabilité: ", DoubleToString(stability_score, 1),
          " | Drawdown: ", DoubleToString(drawdown_score, 1),
          " | Régularité: ", DoubleToString(consistency_score, 1));
    
    // Exporter les données si activé
    if(InpExportPerformanceData) {
        ExportPerformanceData();
    }
}

//+------------------------------------------------------------------+
//| Obtenir le résumé de performance                                |
//+------------------------------------------------------------------+
string GetPerformanceSummary()
{
    if(g_performance_calc.data_count == 0) {
        return "Aucune donnée de performance disponible";
    }
    
    // Obtenir les informations actuelles du compte MT5
    double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double current_margin = AccountInfoDouble(ACCOUNT_MARGIN);
    long account_number = AccountInfoInteger(ACCOUNT_LOGIN);
    string account_server = AccountInfoString(ACCOUNT_SERVER);
    
    // Calculer les moyennes sur les 7 derniers jours
    int recent_days = MathMin(7, g_performance_calc.data_count);
    double avg_score = 0.0;
    double avg_roe = 0.0;
    double avg_win_rate = 0.0;
    double total_net_profit = 0.0;
    
    for(int i = g_performance_calc.data_count - recent_days; i < g_performance_calc.data_count; i++) {
        avg_score += g_performance_calc.daily_data[i].performance_score;
        avg_roe += g_performance_calc.daily_data[i].roe;
        avg_win_rate += g_performance_calc.daily_data[i].win_rate;
        total_net_profit += g_performance_calc.daily_data[i].net_profit;
    }
    
    avg_score /= recent_days;
    avg_roe /= recent_days;
    avg_win_rate /= recent_days;
    
    // Déterminer la tendance
    string trend = "Stable";
    if(g_performance_calc.data_count >= 14) {
        double recent_avg = 0.0;
        double older_avg = 0.0;
        
        for(int i = g_performance_calc.data_count - 7; i < g_performance_calc.data_count; i++) {
            recent_avg += g_performance_calc.daily_data[i].performance_score;
        }
        recent_avg /= 7.0;
        
        for(int i = g_performance_calc.data_count - 14; i < g_performance_calc.data_count - 7; i++) {
            older_avg += g_performance_calc.daily_data[i].performance_score;
        }
        older_avg /= 7.0;
        
        double diff = recent_avg - older_avg;
        if(diff > 2.0) trend = "[+] Amélioration";
        else if(diff < -2.0) trend = "[-] Dégradation";
        else trend = "[=] Stable";
    }
    
    // Calculer le drawdown actuel
    double current_drawdown = (current_balance > 0) ? ((current_balance - current_equity) / current_balance) * 100 : 0;
    
    // Calculer les scores avancés pour le résumé
    double stability_score = CalculateStabilityScore(g_performance_calc.performance_history, g_performance_calc.data_count);
    double drawdown_score = CalculateDrawdownScore(current_equity, current_balance);
    
    // Créer le résumé avec les informations du compte MT5 et les nouveaux facteurs
    string summary = StringFormat("MT5 #%d | Score: %.1f | ROE: %.2f%% | WR: %.1f%% | PnL: $%.2f | DD: %.1f%% | Stab: %.1f | %s",
                                 account_number, avg_score, avg_roe * 100, avg_win_rate * 100, 
                                 total_net_profit, current_drawdown, stability_score, trend);
    
    return summary;
}

//+------------------------------------------------------------------+
//| Exporter les données de performance                             |
//+------------------------------------------------------------------+
void ExportPerformanceData()
{
    if(g_performance_calc.data_count == 0) return;
    
    int file_handle = FileOpen(InpPerformanceFilePath, FILE_WRITE | FILE_CSV);
    if(file_handle == INVALID_HANDLE) {
        Print("❌ Erreur ouverture fichier performance: ", GetLastError());
        return;
    }
    
    // Obtenir les informations du compte MT5
    long account_number = AccountInfoInteger(ACCOUNT_LOGIN);
    string account_server = AccountInfoString(ACCOUNT_SERVER);
    string account_name = AccountInfoString(ACCOUNT_NAME);
    string account_currency = AccountInfoString(ACCOUNT_CURRENCY);
    
    // En-tête CSV avec informations du compte MT5
    FileWrite(file_handle, "AccountNumber,AccountServer,AccountName,Currency,Date,Equity,Balance,Margin,FreeMargin,MarginLevel,WinningTrades,LosingTrades,DailyProfit,DailyLoss,NetProfit,ROE,WinRate,ProfitFactor,PerformanceScore");
    
    // Données avec informations du compte MT5
    for(int i = 0; i < g_performance_calc.data_count; i++) {
        DailyPerformanceData data = g_performance_calc.daily_data[i];
        if(data.date > 0) {
            // Obtenir les données du compte pour cette date (approximation)
            double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
            double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
            double current_margin = AccountInfoDouble(ACCOUNT_MARGIN);
            double current_free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
            double current_margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
            
            string line = StringFormat("%d,%s,%s,%s,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%.2f,%.2f,%.2f,%.4f,%.4f,%.2f,%.2f",
                                     account_number,
                                     account_server,
                                     account_name,
                                     account_currency,
                                     TimeToString(data.date, TIME_DATE),
                                     data.equity,
                                     current_balance,
                                     current_margin,
                                     current_free_margin,
                                     current_margin_level,
                                     data.winning_trades,
                                     data.losing_trades,
                                     data.daily_profit,
                                     data.daily_loss,
                                     data.net_profit,
                                     data.roe,
                                     data.win_rate,
                                     data.profit_factor,
                                     data.performance_score);
            FileWrite(file_handle, line);
        }
    }
    
    FileClose(file_handle);
    Print("✅ Données de performance MT5 exportées: ", InpPerformanceFilePath);
    Print("   Compte: #", IntegerToString(account_number), " (", account_server, ")");
}

//+------------------------------------------------------------------+
//| Dessiner le panneau de performance                              |
//+------------------------------------------------------------------+
void DrawPerformancePanel()
{
    if(!InpShowPerformancePanel) return;
    
    string panel_name = "PerformancePanel";
    
    // Supprimer l'ancien panneau
    if(ObjectFind(0, panel_name) >= 0) {
        ObjectDelete(0, panel_name);
    }
    
    // Créer le panneau
    if(ObjectCreate(0, panel_name, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
        ObjectSetInteger(0, panel_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, panel_name, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, panel_name, OBJPROP_YDISTANCE, 30);
        ObjectSetInteger(0, panel_name, OBJPROP_XSIZE, 300);
        ObjectSetInteger(0, panel_name, OBJPROP_YSIZE, 150);
        ObjectSetInteger(0, panel_name, OBJPROP_BGCOLOR, clrDarkSlateGray);
        ObjectSetInteger(0, panel_name, OBJPROP_BORDER_COLOR, clrGold);
        ObjectSetInteger(0, panel_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, panel_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, panel_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, panel_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, panel_name, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, panel_name, OBJPROP_HIDDEN, true);
    }
    
    // Ajouter le texte de performance
    string performance_text = GetPerformanceSummary();
    string text_name = "PerformanceText";
    
    if(ObjectFind(0, text_name) >= 0) {
        ObjectDelete(0, text_name);
    }
    
    if(ObjectCreate(0, text_name, OBJ_LABEL, 0, 0, 0)) {
        ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, text_name, OBJPROP_XDISTANCE, 20);
        ObjectSetInteger(0, text_name, OBJPROP_YDISTANCE, 50);
        ObjectSetString(0, text_name, OBJPROP_TEXT, performance_text);
        ObjectSetString(0, text_name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 9);
        ObjectSetInteger(0, text_name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, text_name, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, true);
    }
}

//+------------------------------------------------------------------+
//| Structures pour Support/Resistance et Trendlines               |
//+------------------------------------------------------------------+

// Structure pour une zone de support/resistance
struct SRZone {
    double level;                    // Niveau de prix
    double strength;                 // Force de la zone (0-1)
    int touch_count;                 // Nombre de touches
    datetime first_touch;            // Premiere touche
    datetime last_touch;             // Derniere touche
    bool is_support;                 // True si support, false si résistance
    ENUM_TIMEFRAMES timeframe;       // Timeframe de la zone
    bool is_active;                  // Zone encore active
    double success_rate;             // Taux de succès des trades à ce niveau
    int total_trades;                // Nombre total de trades à ce niveau
    int winning_trades;              // Nombre de trades gagnants
    double avg_profit;               // Profit moyen
    double avg_loss;                 // Perte moyenne
    double profit_factor;            // Facteur de profit
    datetime created_time;           // Temps de création
};

// Structure pour une trendline
struct Trendline {
    double start_price;              // Prix de départ
    double end_price;                // Prix de fin
    datetime start_time;             // Temps de départ
    datetime end_time;               // Temps de fin
    double slope;                    // Pente de la trendline
    bool is_uptrend;                 // True si haussière, false si baissière
    int touch_count;                 // Nombre de touches
    double strength;                 // Force de la trendline (0-1)
    ENUM_TIMEFRAMES timeframe;       // Timeframe de la trendline
    bool is_active;                  // Trendline encore active
    datetime created_time;           // Temps de création
};


// Variables globales pour S/R et trendlines
SRZone g_sr_zones[50];               // Zones S/R détectées
int g_sr_zone_count = 0;             // Nombre de zones S/R
Trendline g_trendlines[30];          // Trendlines détectées
int g_trendline_count = 0;           // Nombre de trendlines
datetime g_last_sr_update = 0;      // Dernière mise à jour S/R
datetime g_last_trendline_update = 0; // Dernière mise à jour trendlines


// Variables pour stabilité de confiance
double g_confidence_history[10];     // Historique des confiances
int g_confidence_index = 0;          // Index actuel
datetime g_last_confidence_check = 0; // Dernière vérification
double g_min_stable_confidence = 0.95; // Confiance minimum stable (95%)

//--- Forward declarations for functions used before their definitions
double SnapToDerivBoomCrashLots(const double desired);
bool IsBoomCrashIndex(string symbol);
double SnapLotToSymbol(const string symbol, const double desired);
void   EnsureValidStops(const string symbol, const int direction, const double price, const double point, double &sl_price, double &tp_price);

// Global implementation so calls outside classes can resolve
double SnapToDerivBoomCrashLots(const double desired)
{
    double allowed[] = {0.20, 0.50, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0};
    double target = desired;
    if(target <= allowed[0]) return allowed[0];
    for(int i=1;i<ArraySize(allowed);i++)
    {
        if(target <= allowed[i])
        {
            double low = allowed[i-1];
            double high = allowed[i];
            return (MathAbs(target-low) <= MathAbs(high-target)) ? low : high;
        }
    }
    return allowed[ArraySize(allowed)-1];
}

// ICT helpers (simplifiés)
int DetectICTStructureScore(MqlRates &rates[])
{
    // BOS/COS simplifié: comparer sommets/creux récents
    double h2=rates[2].high, h3=rates[3].high, h4=rates[4].high;
    double l2=rates[2].low,  l3=rates[3].low,  l4=rates[4].low;
    int score=0;
    if(h2>h3 && h3>h4) score += 15; // lower-highs → biais vendeur
    if(l2<l3 && l3<l4) score += 15; // higher-lows → biais acheteur
    return score;
}

int DetectICTOTEScore(MqlRates &rates[])
{
    // OTE classique: zone 62%-79% d'un swing récent (bougies 5..1)
    double swingHigh = rates[5].high;
    double swingLow  = rates[5].low;
    for(int i=4;i>=1;i--){ if(rates[i].high>swingHigh) swingHigh=rates[i].high; if(rates[i].low<swingLow) swingLow=rates[i].low; }
    double range = swingHigh - swingLow; if(range<=0) return 0;
    double oteMin = swingLow + 0.62*range;
    double oteMax = swingLow + 0.79*range;
    double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    return (px>=oteMin && px<=oteMax)? 20 : 0;
}

void DrawOTEZone() { /* disabled */ }

void DrawBOSCOSLevels() { /* disabled */ }

// Spike Zone Detector (compression + confluences)
bool IsSpikeBar(const MqlRates &bar, const double atr)
{
    double range = bar.high - bar.low;
    double body  = MathAbs(bar.close - bar.open);
    double upper = bar.high - MathMax(bar.open, bar.close);
    double lower = MathMin(bar.open, bar.close) - bar.low;
    if(atr<=0) return false;
    if(range < InpSpikeATRMult * atr) return false;
    if(body<=0) return false;
    if(MathMax(upper,lower)/body < InpSpikeWickBodyMin) return false;
    return true;
}

bool DetectCompressionZone(MqlRates &rates[], double &zLow, double &zHigh)
{
    int n = ArraySize(rates); if(n < InpCompressionLookback*2+2) return false;
    double rRecent=0, rOld=0; int L=InpCompressionLookback;
    for(int i=1; i<=L; i++) rRecent += (rates[i].high - rates[i].low);
    for(int i=L+1; i<=2*L; i++) rOld += (rates[i].high - rates[i].low);
    if(rOld<=0) return false;
    bool compressed = (rRecent <= InpCompressionRatio * rOld);
    if(!compressed) return false;
    zLow = rates[L].low; zHigh = rates[L].high;
    for(int i=1;i<=L;i++){ if(rates[i].low<zLow) zLow=rates[i].low; if(rates[i].high>zHigh) zHigh=rates[i].high; }
    return true;
}

int ComputeSpikeZoneScore(MqlRates &rates[])
{
    int score=0;
    // ATR M1
    int atr=iATR(_Symbol, PERIOD_M1, 14); double a[2]; if(atr!=INVALID_HANDLE && CopyBuffer(atr,0,0,2,a)>=2) { if(a[0]>0) score += 10; IndicatorRelease(atr);} 
    // OTE confluence
    score += DetectICTOTEScore(rates);
    // BOS/COS confluence
    score += DetectICTStructureScore(rates);
    // Price action
    score += DetectICTPriceActionScore(rates);
    // Trend MTF
    score += DetectICTTrendScore();
    if(score>100) score=100; return score;
}

void DrawSpikeZoneIfAny()
{
    MqlRates r[]; if(CopyRates(_Symbol, PERIOD_M1, 0, MathMax(20, 2*InpCompressionLookback+5), r) < 2*InpCompressionLookback+5) return;
    double zl=0, zh=0; if(!DetectCompressionZone(r, zl, zh)) return;

    // Dessiner zone de compression comme zone potentielle de départ de spike
    datetime t0=TimeCurrent(); string name=StringFormat("SPKZ_%s_%d", _Symbol, (int)t0);
    if(ObjectFind(0,name)>=0) ObjectDelete(0,name);
    if(ObjectCreate(0,name, OBJ_RECTANGLE, 0, t0-60, zl, t0, zh))
    {
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_COLOR, (color)clrDeepSkyBlue);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    }

    // Score dynamique (OTE/BOS/COS désactivés visuellement, score conservé si besoin)
    int L = MathMax(2, InpCompressionLookback);
    double rRecent=0, rOld=0;
    for(int i=1; i<=L; i++) rRecent += (r[i].high - r[i].low);
    for(int i=L+1; i<=2*L; i++) rOld += (r[i].high - r[i].low);
    double compScore = 0.0;
    if(rRecent>0.0 && rOld>0.0)
    {
        double ratio = rOld / MathMax(1e-8, rRecent); // >1 si compression
        compScore = (ratio - 1.0) * 25.0;             // 1.0 -> 0; 3.0 -> ~50
        if(compScore < 0.0) compScore = 0.0;
        if(compScore > 50.0) compScore = 50.0;
    }
    int cScore = (int)MathRound(compScore);

    int oScore = DetectICTOTEScore(r);               // 0..20
    int bScore = DetectICTStructureScore(r);         // 0..30 → cap 20
    if(bScore > 20) bScore = 20;
    int tScore = DetectICTTrendScore();              // 0..15 → cap 10
    if(tScore > 10) tScore = 10;

    int total = cScore + oScore + bScore + tScore;
    if(total > 100) total = 100;

    // Afficher label détaillé
    string lbl=StringFormat("SPKZLBL_%s_%d", _Symbol, (int)t0);
    string text = StringFormat("SpikeZone %d (C:%d O:%d B:%d T:%d)", total, cScore, oScore, bScore, tScore);
    DrawLabel(lbl, text, 12, 78, clrLightSteelBlue);
}

int DetectICTPriceActionScore(MqlRates &rates[])
{
    // Rejet/mèche longue sur dernière bougie
    double body = MathAbs(rates[1].close - rates[1].open);
    double upper = rates[1].high - MathMax(rates[1].open, rates[1].close);
    double lower = MathMin(rates[1].open, rates[1].close) - rates[1].low;
    int s=0;
    if(body>0){ if(upper/body>2.0) s+=10; if(lower/body>2.0) s+=10; }
    return s;
}

int DetectICTTrendScore()
{
    // Alignement tendance H1 + M15 via EMA fast/slow
    int d1 = CSignalValidator::GetTrendDirection(PERIOD_H1);
    int d2 = CSignalValidator::GetTrendDirection(PERIOD_M15);
    if(d1==0 || d2==0) return 0;
    return (d1==d2)? 15 : 0;
}
// Header duplicated earlier; removed here to avoid duplicate properties/includes

//--- Input parameters (OPTIMISÉS - 15 paramètres maximum pour éviter les bugs MT5)
input group "=== CONFIGURATION GÉNÉRALE ==="
input bool     InpEnableTrading        = true;     // Activer le trading
input int      InpMagicNumber          = 123456;   // Magic number
input double   InpLotSize              = 0.1;      // Taille du lot par défaut (réduit pour sécurité)
input int      InpStopLoss             = 10;       // Stop Loss (points) - plus serré
input int      InpTakeProfit           = 20;       // Take Profit (points) - ratio 1:2

input group "=== GESTION DES RISQUES ==="
input double   InpMaxRiskPercent       = 0.5;      // Risque maximum par trade (%) - réduit pour sécurité
input double   InpMaxDailyLoss         = 5.0;      // Perte max journalière ($) - réduit
input int      InpMaxTrades            = 3;        // Nombre max de trades - augmenté
input int      InpCooldownMinutes      = 1;        // Cooldown entre trades (min) - réduit
input bool     InpStrictSinglePosition = false;    // Une seule position à la fois
input bool     InpEnableSpikeReentry   = true;     // Ré-entrée après spike
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_M15; // Timeframe pour tendance - plus réactif
input int      InpMaxGlobalSimultaneousTrades = 3; // Nombre max de trades simultanés global - augmenté

input group "=== TRADING INTELLIGENT (FAIBLE PERTE, MAX GAIN) ==="
input bool     InpUseSmartTrading       = true;     // Activer le trading intelligent
input double   InpMaxRiskPerTrade       = 0.3;      // Risque max par trade (0.3% du capital) - réduit
input double   InpMinRiskRewardRatio   = 2.5;      // Ratio risque/récompense minimum (1:2.5) - amélioré
input double   InpMinConfidenceThreshold = 85.0;    // Seuil de confiance minimum (85%) - plus accessible
input bool     InpSpikeOnlyMode         = true;     // N'entrer que si probabilité de spike élevée
input bool     InpValidateTradeWin      = true;     // Valider que le trade est gagnant en 1 min
input bool     InpVerifySpikeBeforeSignal = true;   // Vérifier le spike avant d'annoncer
input bool     InpEnableEarlyDetection  = true;     // Activer la détection précoce
input int      InpLookbackPeriod        = 15;       // Période de lookback pour détection - réduit
input double   InpConsolidationThreshold = 0.6;     // Seuil de consolidation (0.6 = 60%) - plus strict
input double   InpWickRatioThreshold    = 1.8;      // Seuil de ratio de mèche (1.8 = 180%) - plus strict
input bool     InpUseMultiTimeframe     = true;     // Utiliser la validation multi-timeframe - activé
input bool     InpUseSupportResistance  = true;     // Utiliser la validation support/résistance - activé
input int      InpMinConfidence         = 75;       // Confiance minimum pour validation - augmenté
input double   InpVolatilityThreshold   = 1.2;      // Seuil d'augmentation de volatilité (1.2 = 120%) - plus strict
input double   InpSRProximityPercent    = 0.3;      // Proximité S/R en pourcentage (0.3%) - plus strict
input bool     InpUseDynamicTP          = true;     // Take Profit dynamique basé sur volatilité
input bool     InpUseAdaptiveSL         = true;     // Stop Loss adaptatif
input bool     InpUsePartialClose       = true;     // Fermeture partielle des positions
input double   InpPartialClosePercent   = 60.0;     // Pourcentage de fermeture partielle - augmenté
input int      InpPartialCloseAtProfit  = 8;       // Fermeture partielle à X points de profit - augmenté
input bool     InpUseTrailingStopSmart  = true;    // Trailing stop intelligent
input int      InpTrailingStartPoints   = 6;       // Démarrage trailing stop (points) - augmenté
input int      InpTrailingStepPoints    = 3;       // Pas du trailing stop (points) - augmenté

input group "=== API CONNEXION ==="
input string   InpAPIUrl               = "http://127.0.0.1:8001"; // URL API Python
input int      InpAPITimeout           = 3000;     // Timeout API (ms)
input bool     InpUseAPIPredictions    = true;     // Utiliser prédictions API

input group "=== NOTIFICATIONS ==="
input bool     InpSendNotifications    = true;     // Envoyer notifications
input bool     InpPlaySounds           = false;    // Alertes sonores (désactivées)
input string   InpSoundFile            = "alert.wav"; // Fichier son pour alertes
input bool     InpNotifyRawSignals     = false;    // Notifier les pré-signaux (désactivé)
input bool     InpDrawPreSignalArrows  = false;    // Dessiner flèches pré-signal (désactivé)
input int      InpNotificationCooldownSec = 30;    // Cooldown notifications (sec)

input group "=== ICT STRATEGY (BOS, COS, OTE, FIB, PA) ==="
input bool     InpEnableICT            = true;     // Activer filtres ICT
input int      InpICTMinScore          = 40;       // Score ICT minimum (0-100)
input bool     InpICTUseBOSCOS         = true;     // Utiliser BOS/COS (Break/Change of Structure)
input bool     InpICTUseOTE            = true;     // Utiliser OTE (Optimal Trade Entry) 62-79%
input bool     InpICTUseFibonacci      = true;     // Utiliser confluence niveaux Fibonacci
input bool     InpICTUsePriceAction    = true;     // Rejets, mèches longues, FVG simple
input bool     InpICTUseTrendMTF       = true;     // Tendance MTF alignée
input bool     InpICTAnnouncePreSpike  = true;     // Annoncer le spike 1 minute avant (flèche unique)
input bool     InpAlwaysDrawSpikeZones = false;    // Dessiner zones (OTE/BOS/COS/Compression) en continu

input group "=== SPIKE ZONES (DETECTION) ==="
input double   InpSpikeATRMult         = 3.0;      // k1: Spike si range >= k1*ATR
input double   InpSpikeWickBodyMin     = 2.0;      // k2: max(wick)/corps >= k2
input double   InpCompressionRatio     = 0.7;      // Compression: range récent <= 0.7 * ancien
input int      InpCompressionLookback  = 5;        // Bougies pour compression
input int      InpSpikeZoneMinScore    = 60;       // Score minimum pour dessiner zone

input group "=== IA ANTICIPATIVE ==="
input bool     InpUseAIForAnticipation = true;     // Utiliser l'IA pour anticiper/filtrer
input int      InpAIMinTradeConfidence = 75;       // Confiance minimale IA pour agir (%)
input bool     InpAIAsHardFilter       = false;    // Exiger accord IA sur les signaux locaux
input bool     InpAIEnablePendingOrders = true;    // Placer des ordres LIMIT selon l'IA
input int      InpAIPendingExpirySec   = 120;      // Expiration des ordres LIMIT (sec)
input int      InpAIDecisionTTLMin     = 10;       // Validité d'une recommandation IA (minutes)
input bool     InpAPlusMode            = false;    // Mode A+ (filtrage strict)

input group "=== SIGNALS EXTERNES (API) ==="
input bool     InpUseExternalSignals   = true;     // Consommer des signaux via API externe
input string   InpExternalSignalsURL   = "http://localhost:8001/signals"; // Endpoint /signals
input string   InpTrendAnalysisURL     = "http://localhost:8001/trend"; // Endpoint /trend
input int      InpExtSigMinConfidence  = 70;       // Confiance minimale API (%)
input bool     InpExtSigAsHardFilter   = false;    // Exiger accord API sur signaux locaux
input int      InpExtSigTTLSeconds     = 5;        // Durée de vie du cache (s)
input bool     InpEnableMultiSymbolAPI = true;     // Scanner les graphiques ouverts et agir sur signaux API
input int      InpMaxChartsScan        = 10;       // Nombre max de graphiques à scanner par tick
input int      InpMultiSymbolCooldownSec = 2;      // Cooldown scan multi-symbol (secondes)
input bool     InpEnableAdditionalSymbols = true;   // Activer une liste de symboles additionnels
input string   InpAdditionalSymbols     = "Crash 1000 Index,Crash 500 Index"; // Liste CSV de symboles à trader

input group "=== RECOMMANDATIONS IA (GEMINI PROXY) ==="
input bool     InpEnableAIRecommendations = false;  // Activer recommandations IA (via proxy local)
input string   InpAIProxyURL           = "http://127.0.0.1:8099/recommend"; // URL du proxy AI
input int      InpAIUpdateSeconds      = 10;        // Fréquence mise à jour panneau IA (sec)

input group "=== RECOMMANDATIONS API SIMPLE ==="
input bool     InpUseApiRecommendations = true;     // Consommer /recommendations depuis simple_api
input string   InpRecommendationsURL    = "http://127.0.0.1:8001/recommendations"; // Endpoint /recommendations
input int      InpRecoPollSeconds       = 60;       // Fréquence de poll (sec)
input bool     InpShowApiPanel          = true;     // Afficher panneau d'analyses API sur le graphique
input int      InpApiPanelUpdateSeconds = 10;       // Fréquence mise à jour panneau API (sec)

input group "=== FERMETURE PANIER (BASKET) ==="
input bool     InpEnableBasketClose    = true;     // Fermer toutes les positions si profit total atteint
input double   InpBasketProfitCloseUSD = 50.0;     // Seuil de profit total ($) pour arrêter la journée
input bool     InpBasketIncludeAllPositions = false; // Inclure toutes les positions (tous magics)
input double   InpBasketLossCloseUSD   = 4.0;      // Seuil de perte totale ($) pour couper et arrêter la journée (2 trades x 2$)
input bool     InpReenterAfterBasketTP = false;    // Ré-entrer après clôture sur TP panier si tendance ok

input group "=== SYSTÈME SPIKE ULTRA-PRÉCIS ==="
input bool     InpUltraPreciseMode     = true;     // Mode ultra-précis : entrée SEULEMENT sur spike confirmé
input double   InpSpikeConfirmationThreshold = 0.15; // Seuil de confirmation spike (%) - Plus accessible
input double   InpMinSpikeStrength     = 1.8;      // Force minimum du spike (vs ATR) - Plus accessible
input bool     InpImmediateCloseAfterSpike = true; // Fermeture immédiate après capture
input double   InpQuickGainThreshold   = 1.0;      // Seuil de gain rapide pour fermeture ($) - augmenté
input double   InpUltraHighConfidence  = 90.0;     // Confiance minimum ultra-élevée (%) - Plus accessible
input double   InpStableConfidenceMin  = 85.0;     // Confiance minimum stable pour trading (%) - Plus accessible
input double   InpConfidenceStabilityMax = 3.0;    // Écart-type maximum pour stabilité (%) - Plus accessible
input bool     InpSingleTradeOnly      = false;    // Un seul trade à la fois
input int      InpMaxSimultaneousTrades = 3;       // Nombre maximum de trades simultanés - augmenté
input int      InpMinTradeIntervalSeconds = 60;   // Intervalle minimum entre trades (sec) - réduit
input double   InpMaxLossPerTradeUSD   = 2.0;      // Perte maximale par trade ($) - 2$ max
input int      InpCooldownAfterLosses  = 2;        // Nombre de pertes consécutives avant cooldown - réduit
input int      InpCooldownAfterWins    = 5;        // Nombre de gains consécutifs avant cooldown - réduit
input int      InpCooldownLossMinutes  = 3;        // Cooldown après pertes (minutes) - réduit
input int      InpCooldownWinMinutes   = 1;        // Cooldown après gains (minutes) - réduit
input double   InpMaxCapitalEngagedUSD = 30.0;     // Capital engagé maximum par jour ($) - augmenté

input group "=== SIGNALS BOOM/CRASH/VOLATILITY S/R ==="
input bool     InpEnableBoomCrashSignals = true;   // Activer signaux Boom/Crash/Volatility basés S/R
input double   InpSupportBoomThreshold = 60.0;     // Seuil support pour signal BUY (60%)
input double   InpResistanceCrashThreshold = 50.0; // Seuil résistance pour signal SELL (50%)
input double   InpSRProximityTolerance = 0.0003;   // Tolérance proximité S/R (en prix)
input bool     InpCloseImmediatelyAfterSpike = true; // Fermeture immédiate après spike
input bool     InpEnableVolatilitySignals = true;   // Activer signaux Volatility (bidirectionnel)
input double   InpVolatilitySpikeThreshold = 1.8;  // Seuil spike pour Volatility (1.8x ATR)
input double   InpVol10SpikeThreshold = 1.5;        // Seuil spike pour Volatility 10% (plus sensible)
input double   InpVol25SpikeThreshold = 1.6;        // Seuil spike pour Volatility 25%
input double   InpVol50SpikeThreshold = 1.8;        // Seuil spike pour Volatility 50%
input double   InpVol75SpikeThreshold = 2.0;        // Seuil spike pour Volatility 75%
input double   InpVol100SpikeThreshold = 2.2;        // Seuil spike pour Volatility 100% (plus strict)

input group "=== PRÉDICTION SPIKE IMMINENT ==="
input bool     InpEnableSpikePrediction = true;    // Activer prédiction de spike imminent
input double   InpVolumeCompressionThreshold = 0.5; // Seuil compression volume (50%)
input double   InpMAConvergenceThreshold = 0.001;   // Seuil convergence MA (0.1%)
input double   InpATRCompressionThreshold = 0.7;    // Seuil compression ATR (70%)
input double   InpPressureImbalanceThreshold = 2.0; // Seuil déséquilibre pression (2:1)
input int      InpPredictionConfidenceMin = 75;    // Confiance minimum prédiction (%)

input group "=== CALCUL DE PERFORMANCE ==="
input bool     InpEnablePerformanceTracking = true; // Activer le suivi de performance
input double   InpInitialCapital = 1000.0;          // Capital initial pour calcul ROE
input bool     InpShowPerformancePanel = true;      // Afficher panneau de performance
input int      InpPerformanceUpdateMinutes = 5;     // Fréquence mise à jour performance (min)
input bool     InpExportPerformanceData = true;     // Exporter données de performance
input string   InpPerformanceFilePath = "performance_data.csv"; // Chemin fichier export

input group "=== SCORE DE PERFORMANCE AVANCÉ ==="
input bool     InpUseAdvancedScoring = true;        // Utiliser le score de performance avancé
input double   InpStabilityWeight = 0.2;            // Poids du facteur stabilité (20%)
input double   InpDrawdownWeight = 0.15;            // Poids du facteur drawdown (15%)
input double   InpConsistencyWeight = 0.1;          // Poids du facteur régularité (10%)
input double   InpBaseScoreWeight = 0.5;            // Poids du score de base (50%)
input double   InpMaxDrawdownThreshold = 10.0;      // Seuil de drawdown maximum (10%)
input double   InpStabilityPenalty = 2.0;           // Pénalité par écart-type de stabilité


input group "=== SL/TP OPTIMAUX BASÉS SUR VOLATILITÉ ==="
input bool     InpUseOptimalSLTP       = true;     // Utiliser SL/TP optimaux basés sur ATR
input double   InpSL_ATR_Multiplier   = 0.8;      // Multiplicateur ATR pour SL (conservateur)
input double   InpTP_ATR_Multiplier   = 1.2;      // Multiplicateur ATR pour TP (optimiste)
input int      InpATR_Period          = 14;       // Période ATR pour calculs
input bool     InpAdaptiveSLTP        = true;     // SL/TP adaptatifs selon volatilité

input group "=== SUPPORT/RÉSISTANCE MULTI-TIMEFRAME ==="
input bool     InpEnableSRDetection    = true;     // Activer détection S/R multi-timeframe
input bool     InpPrioritizeSREntries = true;     // Privilégier entrées dans zones S/R
input double   InpSRZoneTolerance     = 0.0005;     // Tolérance zone S/R (en prix)
input int      InpSRMinTouches        = 2;        // Nombre minimum de touches pour valider S/R
input int      InpSRLookbackBars      = 100;      // Barres à analyser pour S/R
input bool     InpDrawSRZones         = true;     // Dessiner zones S/R sur graphique
input double   InpSRMinConfidence     = 70.0;     // Confiance minimum pour affichage (%)
input color    InpSRSupportColor      = clrLime;  // Couleur zones support
input color    InpSRResistanceColor   = clrRed;   // Couleur zones résistance

input group "=== TRENDLINES DÉTECTION ==="
input bool     InpEnableTrendlines    = true;     // Activer détection trendlines
input double   InpTrendlineTolerance  = 0.0003;   // Tolérance trendline (en prix)
input int      InpTrendlineMinPoints  = 3;        // Points minimum pour trendline
input bool     InpDrawTrendlines      = true;     // Dessiner trendlines sur graphique
input color    InpTrendlineUpColor    = clrBlue;  // Couleur trendline haussière
input color    InpTrendlineDownColor  = clrOrange; // Couleur trendline baissière

input group "=== OBJECTIFS MONÉTAIRES PAR TRADE ==="
input bool     InpEnforceDollarTargets = true;     // Forcer objectifs $ par trade
input double   InpMaxLossUSDPerTrade   = 2.0;      // Perte max $ par trade - augmenté
input double   InpTargetProfitUSD      = 5.0;      // Gain cible $ par trade - ratio 1:2.5

input group "=== OBJECTIF GLOBAL OUVERT ==="
input double   InpMaxGlobalOpenLossUSD = 6.0;      // Perte totale ouverte max ($) pour forcer clôture - augmenté
input int      InpGlobalCooldownMin    = 3;        // Cooldown global après perte (minutes) - réduit

input group "=== TENDANCE & RÉENTRÉE ==="
input int      InpEMAFast              = 15;        // EMA rapide - plus réactif
input int      InpEMASlow              = 35;        // EMA lente - plus réactif
input bool     InpEnforceM1Trend       = true;      // Interdire les entrées contre-tendance M1
input bool     InpRequireTrendAlign    = true;      // N'entrer que si aligné avec la tendance
input int      InpMinEdgeConfidence    = 80;        // Score minimum pour engager un trade (0-100) - augmenté
input int      InpMaxSpreadPoints      = 25;        // Spread max autorisé (points) - réduit
input int      InpReentryMinBars       = 1;         // Attendre au moins N petites bougies - réduit
input int      InpReentryMaxBars       = 3;         // Au plus N petites bougies - réduit
input double   InpSmallCandlePct       = 0.50;      // Bougie petite si range < 50% de la moyenne - plus strict
input double   InpPerTradeLossCloseUSD = 2.0;       // Fermer une position si perte ≥ $2.0 - augmenté
input int      InpReentryCooldownMin   = 2;         // Attendre N minutes avant reprise après perte - réduit
input int      InpConsecutiveLossCooldownMin = 2;   // Cooldown après 2 pertes consécutives (minutes) - réduit
input int      InpMaxConsecutiveLosses = 2;        // Nombre max de pertes consécutives avant cooldown - réduit
input double   InpPerTradeProfitCloseUSD = 3.0;     // Fermer une position si gain ≥ $3 - augmenté
input bool     InpEnableConservativeRangeMode = true; // Activer mode conservateur en range (H1/M30)
input ENUM_TIMEFRAMES InpRangeModeTF1  = PERIOD_H1; // TF 1 pour détection range
input ENUM_TIMEFRAMES InpRangeModeTF2  = PERIOD_M30; // TF 2 pour détection range
input double   InpConservativeProfitUSD = 1.0;      // TP par trade en mode conservateur ($)
input double   InpConservativeLossUSD   = 0.5;      // SL par trade en mode conservateur ($)
input bool     InpEnableStaircaseM1    = false;     // Détection pattern "escalier" en M1
input int      InpStaircaseLookback    = 8;         // Nombre de bougies à analyser en M1
input int      InpStaircaseMinSteps    = 4;         // Nombre minimum de petites bougies
input int      InpStaircaseMaxBurst    = 3;         // Nombre max d'ordres à ouvrir en rafale
input bool     InpPreferBoomCrash      = true;      // Privilégier Boom/Crash
input int      InpBoomCrashConfidenceBoost = 15;    // Diminuer l'exigence de score pour Boom/Crash
input int      InpNonBoomCrashPenalty  = 0;         // Pénalité pour non Boom/Crash (0 pour inclure Forex)
input double   InpBCQuickTPUSD         = 1.0;       // Boom/Crash: TP rapide si spike capturé ($)
input int      InpBCReentryDelayMin    = 1;         // Boom/Crash: délai avant ré-entrée (minutes)
// Trailing management - MODIFIÉ: Désactivé par défaut car interdiction de modifier
input bool     InpUseTrailing          = false;     // Activer trailing - MODIFIÉ
input double   InpBreakEvenAtR         = 0.7;       // Passer à BE à 0.7R
input double   InpTrailDistanceR       = 0.5;       // Distance de trailing = 0.5R

input group "=== PRÉ-SPIKE (BOOM/CRASH) ==="
input bool     InpEnablePreSpike       = true;      // Activer prédiction précoce
input int      InpBBPeriod             = 20;        // Période Bollinger
input double   InpBBDeviation          = 2.0;       // Déviation Bollinger
input int      InpATRShort             = 14;        // ATR court
input double   InpATRBoostMin          = 1.2;       // ATR actuel vs moyenne min
input double   InpWickRatioMin         = 1.8;       // Mèche/Corps min sur bougie précédente
input int      InpPreSpikeMinConfidence= 60;        // Confiance mini (%)
input bool     InpEnableEMATouchPreSpike = true;    // Anticiper proche touche EMA10 (M1)
input double   InpEMAApproachATRMult   = 1.2;       // Distance EMA10 <= k * ATR(M1)
input int      InpEMATouchLookaheadMin = 1;         // Horizon minutes pour approche EMA10
// --- Coupures automatiques (désactivées par défaut pour éviter les va-et-vient) ---
input bool     InpEnablePerTradeAutoClose = false;   // Fermer auto par trade (profit/perte) [OFF]
input bool     InpEnableSpikeAutoClose    = false;   // Fermer auto sur spike violent [OFF]

input group "=== ZONES S/R MULTI-TIMEFRAME ==="
input bool     InpDrawMTFZones          = true;      // Dessiner zones S/R D1..M5
input int      InpZonesLookbackBars     = 150;       // Nombre de barres à analyser par TF
input double   InpZoneBandPct           = 0.0010;    // Epaisseur relative de la zone (0.10%)
input int      InpZoneRedrawSec         = 30;        // Intervalle de rafraîchissement des zones (sec)
input double   InpEntryZoneProximityPct = 0.0008;    // Proximité requise à une zone (0.08%)
input bool     InpRequireZoneProximity  = false;     // Exiger proximité d'une zone pour valider le signal
input double   InpSpikeATRMultipleClose = 2.0;       // Fermer si range M1 > k*ATR(M1)
input bool     InpDrawFibonacci         = true;      // Tracer les retracements Fibonacci principaux
input color    InpTPZoneColor           = C'255,255,200'; // Jaune clair pour TP
input color    InpSLZoneColor           = C'255,200,200'; // Rouge clair pour SL
input bool     InpRequireFibEntry       = true;      // Exiger une entrée dans la zone fib 38.2-61.8
input ENUM_TIMEFRAMES InpFibEntryTF     = PERIOD_M5; // TF pour calcul d'entrée Fibonacci

input group "=== TRADING AUTOMATIQUE ==="
input bool     InpEnableAutoTrading      = true;      // Activer le trading automatique
input bool     InpUseDirectOrders        = true;      // Utiliser ordres directs (market)
input bool     InpUseLimitOrders         = true;      // Utiliser ordres limit
input double   InpLimitOrderDistance     = 0.0003;   // Distance ordres limit (en prix) - réduit
input int      InpMaxPendingOrders       = 5;        // Nombre max d'ordres en attente - augmenté
input int      InpOrderExpirationMin     = 15;       // Expiration ordres limit (minutes) - réduit
input bool     InpUseTrailingStop        = true;      // Utiliser trailing stop
input double   InpTrailingStopDistance   = 0.0002;   // Distance trailing stop - réduit
input double   InpTrailingStep           = 0.0001;   // Pas du trailing stop
input bool     InpUseBreakEven           = true;      // Passer en break-even
input double   InpBreakEvenTrigger       = 0.0001;   // Déclencheur break-even (en prix) - réduit
input int      InpMaxTradesPerHour       = 8;         // Nombre max de trades par heure - augmenté
input bool     InpUseSmartSizing         = true;      // Utiliser sizing intelligent
input double   InpRiskPerTrade           = 0.015;    // Risque par trade (% du capital) - réduit
input bool     InpUseTimeFilter          = false;     // Utiliser filtre temporel (désactivé pour trading 24h/24)
input int      InpStartHour              = 0;         // Heure de début trading - 24h/24
input int      InpEndHour                = 23;        // Heure de fin trading - 24h/24

input group "=== SL/TP DYNAMIQUES & SÉCURITÉ ==="
input bool     InpUseATRForSLTP        = true;     // Utiliser ATR pour dimensionner SL/TP\r
input int      InpATRPeriod            = 14;       // Période ATR\r
input double   InpSL_ATR_Mult          = 1.0;      // Multiplicateur ATR pour SL\r
input double   InpTP_ATR_Mult          = 1.6;      // Multiplicateur ATR pour TP\r
input double   InpMinRiskReward        = 1.5;      // R:R minimum (TP >= R * SL)\r
input int      InpStopsBufferPoints    = 2;        // Buffer points au-dessus du stops level\r
input double   InpBoomCrashStopsMultiplier = 1.5;   // Multiplicateur du stops level sur Boom/Crash\r
input int      InpSLTPRetryMs          = 500;       // Délai (ms) avant tentative de modification SL/TP\r
input int      InpMaxSLTPRetries       = 3;         // Nombre maximum de tentatives de modification SL/TP\r

input group "=== GOD MODE (A+ EXTRÊME) ==="
input bool     InpEnableGodMode        = false;     // Activer GOD Mode (filtres ultra stricts)\r
input int      InpGodMinScore          = 85;        // Score minimal pour autoriser l'entrée (0-100)
input int      InpGodTFsRequired       = 4;         // Nombre de TFs alignés requis (sur D1/H4/H1/M30/M15)
input int      InpGodATRLookback       = 60;        // Barres M1 pour estimer momentum ATR
input double   InpGodATRBoostMin       = 1.3;       // ATR actuel >= k * ATRmoy (momentum)
input bool     InpGodRequireSRNear     = true;      // Exiger proximité d'une zone S/R MTF cohérente
input int      InpMinEMASlopePoints    = 5;         // Pente EMA minimum (points)
input int      InpMinADX               = 20;        // ADX minimum pour tendance

input group "=== TREND FILTER ==="
input bool     InpUseTrendOnly         = true;      // Trader uniquement dans le sens de la tendance
input int      InpEMAPeriod            = 50;        // EMA pour direction et pente
input int      InpADXPeriod            = 14;        // ADX période
input int      InpMinEMASlopePips      = 3;         // Pente min EMA (pips) par 10 barres

input group "=== DASHBOARD ==="
input bool     InpShowDashboard        = true;      // Afficher panneau
input int      InpDashCorner           = 0;         // 0 TL, 1 TR, 2 BL, 3 BR
input int      InpDashX                = 10;        // Décalage X
input int      InpDashY                = 20;        // Décalage Y

input group "=== SNIPER MODE (ENTRÉES TRÈS PRÉCISES) ==="
input bool     InpSniperMode           = true;      // Activer entrées "sniper"
input double   InpSniperMaxLossUSD     = 0.5;       // Perte $ max visée par trade (cap SL)
input int      InpSniperEntryOffsetPts = 6;         // Offset LIMIT par rapport au prix (points)

//--- Classes modulaires
class CRiskManager {
private:
    double m_dailyLoss;
    double m_dailyStartBalance;
    int m_tradesToday;
    datetime m_lastTradeTime;
    
public:
    bool ExecuteTradeOnSymbol(const string symbol, const int direction)
    {
        if(direction==0) return false;
        
        // ENCOURAGER: Trades sur volatilités, step index et forex
        bool isVolatility = IsVolatilityIndex(symbol);
        bool isStepIndex = IsStepIndex(symbol);
        bool isForex = IsForexSymbol(symbol);
        
        if(isVolatility || isStepIndex || isForex) {
            Print("✅ SYMBOL FAVORI - ", symbol, " (", 
                  (isVolatility ? "Volatilité" : ""), 
                  (isStepIndex ? "Step Index" : ""), 
                  (isForex ? "Forex" : ""), ") - Trade encouragé");
        }
        
        // Vérifier le cooldown adaptatif après perte
        if(IsSymbolInCooldown(symbol)) {
            // Vérifier si on peut trader malgré le cooldown du symbole
            if(CanTradeDespiteCooldown()) {
                Print("🚀 COOLDOWN SYMBOLE BYPASS - Conditions favorables sur ", symbol);
            } else {
                Print("⏳ COOLDOWN ACTIF - Attente d'une opportunité confirmée sur ", symbol);
                return false;
            }
        }
        
        // Vérifier les pertes consécutives pour ce symbole
        if(IsSymbolInConsecutiveLossCooldown(symbol)) {
            Print("🚫 SYMBOLE ", symbol, " EN COOLDOWN après ", InpMaxConsecutiveLosses, " pertes consécutives");
            return false;
        }
        
        // Vérifier la limite globale de positions simultanées
        if(IsGlobalPositionLimitReached()) {
            return false;
        }
        
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double price = (direction>0)? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
        if(point<=0 || price<=0) return false;

        // SL basé sur InpStopLoss et stops
        int stops = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        int bufferPts = MathMax(0, InpStopsBufferPoints);
        if(IsBoomCrashIndex(symbol)) { stops = (int)MathCeil(stops*MathMax(1.0, InpBoomCrashStopsMultiplier)); bufferPts = (int)MathCeil(bufferPts*MathMax(1.0, InpBoomCrashStopsMultiplier)); }
        int minPts = MathMax(1, stops + bufferPts);
        double sl_points = MathMax((double)InpStopLoss, (double)minPts);
        double sl_price = (direction>0)? price - sl_points*point : price + sl_points*point;

        // TP dynamique
        double tp_points = CalculateDynamicTakeProfit(symbol, price, direction, sl_price);
        double tp_price = (direction>0)? price + tp_points*point : price - tp_points*point;
        double risk_reward_ratio = tp_points / sl_points;
        if(risk_reward_ratio < InpMinRiskRewardRatio)
        {
            tp_points = sl_points * InpMinRiskRewardRatio;
            tp_price = (direction>0)? price + tp_points*point : price - tp_points*point;
        }

        // Lot
        double lotRaw = (IsBoomCrashIndex(symbol))? 0.20 : CalculateSmartLotSize(symbol, price, sl_price);
        double lotSize = SnapLotToSymbol(symbol, lotRaw);
        if(lotSize<=0) return false;

        CTrade trade;
        trade.SetExpertMagicNumber(InpMagicNumber);
        trade.SetDeviationInPoints(10);
        trade.SetTypeFilling(ORDER_FILLING_FOK);

        EnsureValidStops(symbol, direction, price, point, sl_price, tp_price);
        bool result = (direction>0)? trade.Buy(lotSize, symbol, price, sl_price, tp_price, "SpikeHunter Smart")
                                   : trade.Sell(lotSize, symbol, price, sl_price, tp_price, "SpikeHunter Smart");
        if(!result)
        {
            // Nudge SL/TP puis volume +0.2
            double nudgePts = MathMax(1, InpStopsBufferPoints);
            double sl_adj = sl_price, tp_adj = tp_price;
            if(direction>0){ if(sl_price>0) sl_adj-=nudgePts*point; if(tp_price>0) tp_adj+=nudgePts*point; }
            else            { if(sl_price>0) sl_adj+=nudgePts*point; if(tp_price>0) tp_adj-=nudgePts*point; }
            result = (direction>0)? trade.Buy(lotSize, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart")
                                  : trade.Sell(lotSize, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            if(!result)
            {
                double lot_up = SnapLotToSymbol(symbol, lotSize + 0.20);
                result = (direction>0)? trade.Buy(lot_up, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart")
                                      : trade.Sell(lot_up, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            }
        }
        return result;
    }
    CRiskManager() {
        m_dailyLoss = 0;
        m_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_tradesToday = 0;
        m_lastTradeTime = 0;
    }
    
    bool CanOpenTrade() {
        // VÉRIFICATION ABSOLUE: Maximum 2 positions simultanées - JAMAIS PLUS
        int currentPositions = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                currentPositions++;
            }
        }
        
        if(currentPositions >= 2) {
            Print("🚫 CANOPEN TRADE BLOQUÉ - ", currentPositions, " positions ouvertes (MAXIMUM: 2)");
            Print("🛑 IMPOSSIBLE D'OUVRIR UNE NOUVELLE POSITION - Limite absolue dépassée");
            return false;
        }
        
        // Vérifier la limite de capital engagé journalier
        if(IsCapitalEngagedLimitReached()) {
            return false;
        }
        
        // Cooldown global
        if(g_globalCooldownUntil>0 && TimeCurrent() < g_globalCooldownUntil) return false;
        // Vérifier la perte journalière
        if(m_dailyLoss >= InpMaxDailyLoss) {
            Print("❌ Arrêt journalier atteint: $", DoubleToString(m_dailyLoss, 2));
            return false;
        }
        
        // Vérifier le nombre de trades
        if(m_tradesToday >= InpMaxTrades) {
            Print("❌ Limite de trades atteinte: ", m_tradesToday);
            return false;
        }
        
        // Vérifier le cooldown adaptatif
        if(m_lastTradeTime > 0) {
            int adaptiveCooldown = GetAdaptiveCooldownMinutes(InpCooldownMinutes);
            int cooldownSeconds = adaptiveCooldown * 60;
            
            if(TimeCurrent() - m_lastTradeTime < cooldownSeconds) {
                // Vérifier si on peut trader malgré le cooldown
                if(!CanTradeDespiteCooldown()) {
                    return false;
                } else {
                    Print("🚀 COOLDOWN BYPASS - Conditions favorables détectées");
                }
            }
        }
        
        // Mode strict: si une position (avec notre magic) est ouverte n'importe où, interdire toute nouvelle entrée
        if(InpStrictSinglePosition)
        {
            for(int i = 0; i < PositionsTotal(); i++) {
                ulong tk = PositionGetTicket(i);
                if(!PositionSelectByTicket(tk)) continue;
                if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                    return false;
            }
        }
        
        // Vérification du nombre maximum de trades simultanés
        int current_trades = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                current_trades++;
            }
        }
        
        if(InpSingleTradeOnly && current_trades >= 1) {
            Print("🚫 Un seul trade autorisé - Trade existant détecté");
            return false;
        }
        
        if(current_trades >= InpMaxSimultaneousTrades) {
            Print("🚫 LIMITE STRICTE - Maximum ", InpMaxSimultaneousTrades, " positions simultanées atteint: ", current_trades, "/", InpMaxSimultaneousTrades);
            Print("⏸️ AUCUNE NOUVELLE POSITION AUTORISÉE - Attendre fermeture d'une position existante");
            Print("📋 RÈGLE: Maximum 2 trades simultanés autorisés - Pas de duplication");
            return false;
        }
        
        // Vérifier l'intervalle minimum entre les trades
        static datetime last_trade_time = 0;
        if(last_trade_time > 0 && TimeCurrent() - last_trade_time < InpMinTradeIntervalSeconds) {
            Print("🚫 Intervalle minimum entre trades non respecté (", InpMinTradeIntervalSeconds, " sec)");
            return false;
        }
        
        // Vérifier les trades ouverts globalement (même magic) - LIMITE STRICTE
        int openTradesGlobal = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            openTradesGlobal++;
        }
        
        // LIMITE STRICTE : Maximum 2 positions simultanées GLOBALEMENT
        if(IsGlobalPositionLimitReached()) {
            return false;
        }
        
        return true;
    }
    
    void RecordTrade(double profit) {
        m_tradesToday++;
        m_lastTradeTime = TimeCurrent();
        m_dailyLoss += MathAbs(MathMin(profit, 0));
    }
    
    void ResetDaily() {
        m_dailyLoss = 0;
        m_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_tradesToday = 0;
        m_lastTradeTime = 0; // Reset last trade time as well
    }
};

class CSignalDetector {
private:
    int m_atrHandle;
    int m_maHandle;
    int m_bbHandle;
    
public:
    CSignalDetector() {
        m_atrHandle = iATR(_Symbol, PERIOD_M1, 14);
        m_maHandle = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE);
        m_bbHandle = iBands(_Symbol, PERIOD_M1, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
    }
    
    ~CSignalDetector() {
        if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
        if(m_maHandle != INVALID_HANDLE) IndicatorRelease(m_maHandle);
        if(m_bbHandle != INVALID_HANDLE) IndicatorRelease(m_bbHandle);
    }
    
    int DetectSignal() {
        if(!InpEnableEarlyDetection) return 0;
        
        // VÉRIFICATION PRÉALABLE DE TENDANCE M5 ET M1
        int trendM5 = CSignalValidator::GetTrendDirection(PERIOD_M5);
        int trendM1 = CSignalValidator::GetTrendDirection(PERIOD_M1);
        
        // Ne pas détecter de signal si tendances incertaines ou non alignées
        if(trendM5 == 0 || trendM1 == 0) {
            return 0; // Tendance incertaine
        }
        
        if(trendM5 != trendM1) {
            return 0; // Tendance non alignée
        }
        
        // Obtenir les données des bougies
        MqlRates rates[];
        if(CopyRates(_Symbol, PERIOD_M1, 0, InpLookbackPeriod, rates) < InpLookbackPeriod) {
            return 0;
        }
        
        // Filtre spread: ne pas trader si spread trop élevé
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int spreadPts = (int)MathRound((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID))/MathMax(pt,1e-12));
        if(spreadPts > InpMaxSpreadPoints) return 0;
        
        // Pré-spike Boom/Crash: compression + ATR boost + mèches
        if(InpEnablePreSpike && IsBoomCrashIndex(_Symbol))
        {
            int dir = 0; int conf = 0;
            if(DetectPreSpike(rates, dir, conf))
            {
                if(InpAPlusMode && !IsAPlusEnvironment(dir)) return 0;
                g_isEarlySignal = true;
                return dir;
            }
        }

        // Pré-signal EMA10: approche imminente de l'EMA10 en M1 (mouvements en ciseaux)
        if(InpEnableEMATouchPreSpike && IsBoomCrashIndex(_Symbol))
        {
            int dirEMA = 0; int confEMA = 0;
            if(DetectPreSpikeEMATouch(rates, dirEMA, confEMA))
            {
                // Dessiner une flèche creuse pour pré-signal
                DrawPreSignalArrow(dirEMA);
                // Auto-entrée optionnelle si filtres passent (respect Boom/Crash + M1/M5)
                int d = EnforceBoomCrashDirection(dirEMA);
                if(d!=0 && (!InpEnforceM1Trend || CSignalValidator::IsAlignedWithM1M5(d)))
                {
                    if(!InpAPlusMode || IsAPlusEnvironment(d))
                    {
                        g_isEarlySignal = true;
                        return d;
                    }
                }
            }
        }

        // 1. Détection de consolidation
        if(IsConsolidation(rates)) {
            Print("🎯 SIGNAL: Consolidation détectée");
            int d = AnalyzeDirection(rates);
            if(InpAPlusMode && d!=0 && !IsAPlusEnvironment(d)) d = 0;
            // Exécuter en M5/M1 selon tendance long-terme (éviter contre-tendance Boom/Crash)
            d = EnforceBoomCrashDirection(d);
            return d;
        }
        
        // 2. Détection de mèches longues
        if(HasLongWicks(rates)) {
            Print("🎯 SIGNAL: Mèches longues détectées");
            {
                int d = AnalyzeDirection(rates);
                if(InpAPlusMode && d!=0 && !IsAPlusEnvironment(d)) d = 0;
                return d;
            }
        }
        
        // 3. Détection de volatilité croissante
        if(IsVolatilityIncreasing(rates)) {
            Print("🎯 SIGNAL: Volatilité croissante");
            {
                int d = AnalyzeDirection(rates);
                if(InpAPlusMode && d!=0 && !IsAPlusEnvironment(d)) d = 0;
                return d;
            }
        }
        
        return 0;
    }
    
private:
    bool IsAPlusEnvironment(const int direction)
    {
        if(direction==0) return false;
        // 1) Trend alignment déjà géré si InpRequireTrendAlign, mais on revalide pour A+
        int trend = CSignalValidator::GetTrendDirection(InpTrendTF);
        if(trend!=direction) return false;
        // 2) ADX M15
        int adx = iADX(_Symbol, PERIOD_M15, 14);
        if(adx==INVALID_HANDLE) return false;
        double adxv[2]; bool ok = (CopyBuffer(adx, 0, 0, 2, adxv)>=1); IndicatorRelease(adx);
        if(!ok) return false;
        if(adxv[0] < MathMax(5, InpMinADX)) return false;
        // 3) EMA slope on H1 (fast EMA moving in direction by at least X points over last 5 bars)
        int emaF = iMA(_Symbol, PERIOD_H1, MathMax(2, InpEMAFast), 0, MODE_EMA, PRICE_CLOSE);
        if(emaF==INVALID_HANDLE) return false;
        double f[6]; ok = (CopyBuffer(emaF, 0, 0, 6, f)>=5); IndicatorRelease(emaF);
        if(!ok) return false;
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double slopePts = (f[0]-f[5]) / MathMax(point,1e-12);
        if(direction>0 && slopePts <  MathMax(1.0, InpMinEMASlopePoints)) return false;
        if(direction<0 && slopePts > -MathMax(1.0, InpMinEMASlopePoints)) return false;
        // 4) ATR boost (M1): momentum présent
        int atr = iATR(_Symbol, PERIOD_M1, MathMax(5, InpATRShort));
        if(atr!=INVALID_HANDLE)
        {
            double a[20]; int n = CopyBuffer(atr,0,0,20,a); IndicatorRelease(atr);
            if(n>=5){ double now=a[0]; double avg=0; for(int i=1;i<n;i++) avg+=a[i]; avg/=MathMax(1,n-1); if(!(now >= InpATRBoostMin * MathMax(1e-8, avg))) return false; }
        }
        // 5) Favorable distance to recent pivot in direction (avoid entering right into nearby opposite pivot)
        MqlRates r[]; if(CopyRates(_Symbol, PERIOD_M5, 0, 50, r)<20) return false;
        double lastHigh=r[1].high, lastLow=r[1].low;
        for(int i=2;i<=10;i++){ if(r[i].high>lastHigh) lastHigh=r[i].high; if(r[i].low<lastLow) lastLow=r[i].low; }
        double price = (direction>0)? SymbolInfoDouble(_Symbol, SYMBOL_ASK):SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double distOpp = (direction>0)? (lastHigh-price) : (price-lastLow);
        // must have at least 0.5 * ATR(M5) room
        int atr5 = iATR(_Symbol, PERIOD_M5, 14); if(atr5!=INVALID_HANDLE){ double aa[2]; if(CopyBuffer(atr5,0,0,2,aa)>=1){ if(distOpp < 0.5*aa[0]){ IndicatorRelease(atr5); return false; } } IndicatorRelease(atr5); }
        return true;
    }
    bool DetectPreSpike(MqlRates &rates[], int &outDir, int &outConf)
    {
        outDir = 0; outConf = 0;
        // Bollinger bandwidth (compression)
        if(m_bbHandle == INVALID_HANDLE) return false;
        double up[2], mid[2], lo[2];
        if(CopyBuffer(m_bbHandle,0,0,2,up)<2 || CopyBuffer(m_bbHandle,1,0,2,mid)<2 || CopyBuffer(m_bbHandle,2,0,2,lo)<2) return false;
        double bbw = (up[0]-lo[0]) / MathMax(1e-8, mid[0]);
        double bbwPrev = (up[1]-lo[1]) / MathMax(1e-8, mid[1]);
        bool compressed = (bbw < bbwPrev && bbw < 0.012);

        // ATR boost
        int atr = iATR(_Symbol, PERIOD_M1, InpATRShort);
        if(atr == INVALID_HANDLE) return false;
        double a[20]; int n=CopyBuffer(atr,0,0,ArraySize(a),a); IndicatorRelease(atr);
        if(n < 5) return false;
        double atrNow=a[0]; double atrAvg=0; for(int i=1;i<n;i++) atrAvg += a[i]; atrAvg/=MathMax(1,n-1);
        bool atrBoost = (atrNow >= InpATRBoostMin * MathMax(1e-8, atrAvg));

        // Wick/body of previous candle
        double body = MathAbs(rates[1].close - rates[1].open);
        double upper = rates[1].high - MathMax(rates[1].close, rates[1].open);
        double lower = MathMin(rates[1].close, rates[1].open) - rates[1].low;
        bool longUp = body>0 && (upper/body >= InpWickRatioMin);
        bool longDn = body>0 && (lower/body >= InpWickRatioMin);

        int dir = 0; if(longDn) dir=1; else if(longUp) dir=-1;
        int conf = 0; if(dir!=0){ conf += compressed?30:0; conf += atrBoost?30:0; conf += 40; }

        if(dir!=0 && conf >= InpPreSpikeMinConfidence) { outDir=dir; outConf=conf; return true; }
        return false;
    }

    // Anticipation touche EMA10: si prix actuel est à <= k*ATR de l'EMA10
    bool DetectPreSpikeEMATouch(MqlRates &rates[], int &outDir, int &outConf)
    {
        outDir = 0; outConf = 0;
        // Handles EMA10 et ATR(M1)
        int ema10 = iMA(_Symbol, PERIOD_M1, 10, 0, MODE_EMA, PRICE_CLOSE);
        if(ema10==INVALID_HANDLE) return false;
        int atr = iATR(_Symbol, PERIOD_M1, MathMax(5, InpATRShort));
        if(atr==INVALID_HANDLE) { IndicatorRelease(ema10); return false; }
        double e[2]; double a[2];
        bool okE = (CopyBuffer(ema10,0,0,2,e)>=1); bool okA = (CopyBuffer(atr,0,0,2,a)>=1);
        IndicatorRelease(ema10); IndicatorRelease(atr);
        if(!okE || !okA) return false;
        double ema = e[0]; double atrNow = a[0];

        // Prix de référence et direction Boom/Crash
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        bool isBoom = (StringFind(_Symbol, "Boom")>=0);
        bool isCrash= (StringFind(_Symbol, "Crash")>=0);

        // Distance actuelle à EMA10
        double distBuy  = MathAbs(ask - ema);
        double distSell = MathAbs(bid - ema); // Fixed: ensure positive distance
        double maxDist  = InpEMAApproachATRMult * MathMax(1e-8, atrNow);

        // Si Boom: chercher BUY quand prix approche EMA10 depuis au-dessus (pullback)
        if(isBoom && distBuy <= maxDist)
        {
            outDir = 1; outConf = 60; // base
            // Bonus de confiance si escalier actif
            if(IsStaircasePatternM1()) outConf += 20;
            return true;
        }
        // Si Crash: chercher SELL quand prix approche EMA10 depuis en-dessous
        if(isCrash && distSell <= maxDist)
        {
            outDir = -1; outConf = 60;
            if(IsStaircasePatternM1()) outConf += 20;
            return true;
        }
        return false;
    }
    bool IsConsolidation(MqlRates &rates[]) {
        double recentRange = 0;
        double oldRange = 0;
        
        // Analyser les bougies 2-6 (récentes)
        for(int i = 2; i <= 6; i++) {
            recentRange += (rates[i].high - rates[i].low);
        }
        
        // Analyser les bougies 7-12 (anciennes)
        for(int i = 7; i <= 12; i++) {
            oldRange += (rates[i].high - rates[i].low);
        }
        
        return (recentRange < oldRange * InpConsolidationThreshold);
    }
    
    bool HasLongWicks(MqlRates &rates[]) {
        int longWicks = 0;
        
        for(int i = 2; i <= 8; i++) {
            double bodySize = MathAbs(rates[i].close - rates[i].open);
            double upperWick = rates[i].high - MathMax(rates[i].open, rates[i].close);
            double lowerWick = MathMin(rates[i].open, rates[i].close) - rates[i].low;
            
            if(bodySize > 0) {
                double wickRatio = MathMax(upperWick, lowerWick) / bodySize;
                if(wickRatio > InpWickRatioThreshold) {
                    longWicks++;
                }
            }
        }
        
        return (longWicks >= 2);
    }
    
    bool IsVolatilityIncreasing(MqlRates &rates[]) {
        double recentVolatility = 0;
        double oldVolatility = 0;
        
        // Volatilité récente (bougies 2-6)
        for(int i = 2; i <= 6; i++) {
            recentVolatility += (rates[i].high - rates[i].low);
        }
        
        // Volatilité ancienne (bougies 7-12)
        for(int i = 7; i <= 12; i++) {
            oldVolatility += (rates[i].high - rates[i].low);
        }
        
        return (recentVolatility > oldVolatility * InpVolatilityThreshold);
    }
    
    int AnalyzeDirection(MqlRates &rates[]) {
        // Analyser la tendance récente
        double recentClose = rates[1].close;
        double oldClose = rates[5].close;
        int dir = 0;
        if(recentClose > oldClose) dir = 1; else if(recentClose < oldClose) dir = -1;
        
        // Exiger l'alignement de tendance si demandé
        if(InpRequireTrendAlign)
        {
            int trend = CSignalValidator::GetTrendDirection(InpTrendTF);
            if(trend != dir) return 0;
        }
        
        // Score de confiance simple (0-100): volatilité et cohérence
        int score = 0;
        score += IsConsolidation(rates) ? 30 : 0;
        score += HasLongWicks(rates) ? 30 : 0;
        score += IsVolatilityIncreasing(rates) ? 40 : 0;
        // Booster la préférence Boom/Crash
        if(InpPreferBoomCrash && IsBoomCrashIndex(_Symbol)) score += InpBoomCrashConfidenceBoost;
        if(InpPreferBoomCrash && !IsBoomCrashIndex(_Symbol)) score -= InpNonBoomCrashPenalty;
        if(score < InpMinEdgeConfidence) return 0;
        
        // VÉRIFICATION FINALE: Le signal doit être dans le sens de la tendance M5 et M1
        if(dir != 0) {
            int trendM5 = CSignalValidator::GetTrendDirection(PERIOD_M5);
            int trendM1 = CSignalValidator::GetTrendDirection(PERIOD_M1);
            
            if((dir > 0 && (trendM5 <= 0 || trendM1 <= 0)) || 
               (dir < 0 && (trendM5 >= 0 || trendM1 >= 0))) {
                Print("🚫 SIGNAL DÉTECTÉ MAIS CONTRE TENDANCE - Ignoré (Signal: ", dir, " vs M5: ", trendM5, " M1: ", trendM1, ")");
                return 0;
            }
        }
        
        return dir; // 1 ou -1
    }
    
    //+------------------------------------------------------------------+
    //| Obtenir la confiance du signal                                  |
    //+------------------------------------------------------------------+
public:
    double GetSignalConfidence() {
        if(!InpEnableEarlyDetection) return 0.0;
        
        // Obtenir les données des bougies
        MqlRates rates[];
        if(CopyRates(_Symbol, PERIOD_M1, 0, InpLookbackPeriod, rates) < InpLookbackPeriod) {
            return 0.0;
        }
        
        double confidence = 0.0;
        
        // Filtre spread: ne pas trader si spread trop élevé
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int spreadPts = (int)MathRound((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID))/MathMax(pt,1e-12));
        if(spreadPts > InpMaxSpreadPoints) return 0.0;
        
        // Pré-spike Boom/Crash: compression + ATR boost + mèches
        if(InpEnablePreSpike && IsBoomCrashIndex(_Symbol)) {
            int dir = 0; int conf = 0;
            if(DetectPreSpike(rates, dir, conf)) {
                confidence += conf;
            }
        }
        
        // Pré-signal EMA10: approche imminente de l'EMA10 en M1
        if(InpEnableEMATouchPreSpike && IsBoomCrashIndex(_Symbol)) {
            int dirEMA = 0; int confEMA = 0;
            if(DetectPreSpikeEMATouch(rates, dirEMA, confEMA)) {
                confidence += confEMA;
            }
        }
        
        // Pattern escalier M1
        if(IsStaircasePatternM1()) {
            confidence += 30;
        }
        
        // Score de confiance basé sur les conditions techniques (base)
        int score = 20; // Score de base
        confidence += score;

        // Ajout score ICT (BOS/COS, OTE/Fibonacci, PA, Trend MTF)
        if(InpEnableICT)
        {
            int ictScore = 0;
            if(InpICTUseBOSCOS)       ictScore += DetectICTStructureScore(rates);
            if(InpICTUseOTE && InpICTUseFibonacci) ictScore += DetectICTOTEScore(rates);
            if(InpICTUsePriceAction)  ictScore += DetectICTPriceActionScore(rates);
            if(InpICTUseTrendMTF)     ictScore += DetectICTTrendScore();
            if(ictScore > 60) ictScore = 60; // Cap ICT
            confidence += ictScore;
        }
        
        // Booster la préférence Boom/Crash
        if(InpPreferBoomCrash && IsBoomCrashIndex(_Symbol)) confidence += InpBoomCrashConfidenceBoost;
        if(InpPreferBoomCrash && !IsBoomCrashIndex(_Symbol)) confidence -= InpNonBoomCrashPenalty;
        
        // Limiter la confiance entre 0 et 100
        if(confidence < 0) confidence = 0;
        if(confidence > 100) confidence = 100;
        
        return confidence;
    }
};

class CSignalValidator {
public:
    static bool ValidateSignal(int direction) {
        if(!InpUseMultiTimeframe && !InpUseSupportResistance) {
            return true;
        }
        
        int confidence = 0;
        
        // Validation multi-timeframe
        if(InpUseMultiTimeframe) {
            confidence += ValidateMultiTimeframe(direction);
        }
        
        // Validation Support/Résistance
        if(InpUseSupportResistance) {
            confidence += ValidateSupportResistance();
        }
        
        if(confidence < InpMinConfidence) return false;
        // Exiger proximité zone S/R si demandé
        if(InpRequireZoneProximity && InpDrawMTFZones)
        {
            double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(!IsNearAnyMTFZone(px, direction)) return false;
        }
        return true;
    }
    
    // Interdire contre-tendance M1 et M5 pour Boom/Crash
    static bool IsAlignedWithM1M5(int direction)
    {
        if(direction==0) return false;
        bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
        bool isCrash= (StringFind(_Symbol, "Crash")>= 0);

        // M1 Check
        int emaF1 = iMA(_Symbol, PERIOD_M1, MathMax(2, InpEMAFast), 0, MODE_EMA, PRICE_CLOSE);
        int emaS1 = iMA(_Symbol, PERIOD_M1, MathMax(3, InpEMASlow), 0, MODE_EMA, PRICE_CLOSE);
        if(emaF1 == INVALID_HANDLE || emaS1 == INVALID_HANDLE) { if(emaF1!=INVALID_HANDLE) IndicatorRelease(emaF1); if(emaS1!=INVALID_HANDLE) IndicatorRelease(emaS1); return false; }
        double f1[2], s1[2]; bool ok1 = (CopyBuffer(emaF1,0,0,2,f1)>=2 && CopyBuffer(emaS1,0,0,2,s1)>=2); IndicatorRelease(emaF1); IndicatorRelease(emaS1);
        if(!ok1) return false;
        int dir1 = (f1[0]>s1[0])?1:((f1[0]<s1[0])?-1:0);

        // M5 Check
        int emaF5 = iMA(_Symbol, PERIOD_M5, MathMax(2, InpEMAFast), 0, MODE_EMA, PRICE_CLOSE);
        int emaS5 = iMA(_Symbol, PERIOD_M5, MathMax(3, InpEMASlow), 0, MODE_EMA, PRICE_CLOSE);
        if(emaF5 == INVALID_HANDLE || emaS5 == INVALID_HANDLE) { if(emaF5!=INVALID_HANDLE) IndicatorRelease(emaF5); if(emaS5!=INVALID_HANDLE) IndicatorRelease(emaS5); return false; }
        double f5[2], s5[2]; bool ok5 = (CopyBuffer(emaF5,0,0,2,f5)>=2 && CopyBuffer(emaS5,0,0,2,s5)>=2); IndicatorRelease(emaF5); IndicatorRelease(emaS5);
        if(!ok5) return false;
        int dir5 = (f5[0]>s5[0])?1:((f5[0]<s5[0])?-1:0);

        // General Trend Alignment Check
        if(dir1 != direction || dir5 != direction) return false;

        // Boom/Crash specific checks
        if(isBoom)
        {
            if(direction < 0) return false; // No SELL on Boom
            // If M1 or M5 trend is against the desired BUY direction
            if(dir1 < 0 || dir5 < 0) return false;
        }
        else if(isCrash)
        {
            if(direction > 0) return false; // No BUY on Crash
            // If M1 or M5 trend is against the desired SELL direction
            if(dir1 > 0 || dir5 > 0) return false;
        }

        return true;
    }
private:
    static int ValidateMultiTimeframe(int direction) {
        int alignedTimeframes = 0;
        // D1, H4, H1, M30, M15
        ENUM_TIMEFRAMES timeframes[] = {PERIOD_D1, PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15};
        
        for(int i = 0; i < ArraySize(timeframes); i++) {
            if(IsTimeframeAligned(timeframes[i], direction)) {
                alignedTimeframes++;
            }
        }
        
        return (alignedTimeframes * 20); // 5 TFs -> 100% max
    }
    
    static bool IsTimeframeAligned(ENUM_TIMEFRAMES timeframe, int direction) {
        // EMA-based trend alignment
        int emaFast = iMA(_Symbol, timeframe, MathMax(2, InpEMAFast), 0, MODE_EMA, PRICE_CLOSE);
        int emaSlow = iMA(_Symbol, timeframe, MathMax(3, InpEMASlow), 0, MODE_EMA, PRICE_CLOSE);
        if(emaFast == INVALID_HANDLE || emaSlow == INVALID_HANDLE) { if(emaFast!=INVALID_HANDLE) IndicatorRelease(emaFast); if(emaSlow!=INVALID_HANDLE) IndicatorRelease(emaSlow); return false; }
        double f[2], s[2];
        bool ok = (CopyBuffer(emaFast, 0, 0, 2, f) >= 2 && CopyBuffer(emaSlow, 0, 0, 2, s) >= 2);
        IndicatorRelease(emaFast);
        IndicatorRelease(emaSlow);
        if(!ok) return false;
        int tfDir = (f[0] > s[0]) ? 1 : (f[0] < s[0] ? -1 : 0);
        return (tfDir == direction);
    }
    
    static int ValidateSupportResistance() {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double proximityThreshold = InpSRProximityPercent / 100.0;
        
        // Analyser les niveaux récents
        MqlRates rates[];
        if(CopyRates(_Symbol, PERIOD_M1, 0, 50, rates) < 50) return 0;
        
        int nearLevels = 0;
        for(int i = 10; i < 50; i++) {
            double high = rates[i].high;
            double low = rates[i].low;
            
            if(MathAbs(currentPrice - high) / currentPrice <= proximityThreshold ||
               MathAbs(currentPrice - low) / currentPrice <= proximityThreshold) {
                nearLevels++;
            }
        }
        
        return (nearLevels >= 2) ? 50 : 0; // 50% si près de S/R
    }
    
    // Déterminer la direction de tendance via EMA croisée
public:
    static int GetTrendDirection(ENUM_TIMEFRAMES tf)
    {
        int emaFast = iMA(_Symbol, tf, MathMax(2, InpEMAFast), 0, MODE_EMA, PRICE_CLOSE);
        int emaSlow = iMA(_Symbol, tf, MathMax(3, InpEMASlow), 0, MODE_EMA, PRICE_CLOSE);
        if(emaFast == INVALID_HANDLE || emaSlow == INVALID_HANDLE) return 0;
        double f[2], s[2];
        bool ok = (CopyBuffer(emaFast, 0, 0, 2, f) >= 2 && CopyBuffer(emaSlow, 0, 0, 2, s) >= 2);
        IndicatorRelease(emaFast);
        IndicatorRelease(emaSlow);
        if(!ok) return 0;
        if(f[0] > s[0]) return 1;     // tendance haussière
        if(f[0] < s[0]) return -1;    // tendance baissière
        return 0;
    }

    // GOD Mode composite score (0-100). Uses strict confluence of factors.
    static int ComputeGodScore(const int direction)
    {
        if(direction==0) return 0;
        int score = 0;

        // 1) Multi-timeframe alignment: require N TFs aligned
        ENUM_TIMEFRAMES tfs[] = {PERIOD_D1, PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15};
        int aligned = 0;
        for(int i=0;i<ArraySize(tfs);i++)
            if(IsTimeframeAligned(tfs[i], direction)) aligned++;
        if(aligned >= MathMax(1, InpGodTFsRequired))
            score += MathMin(40, 10*aligned); // up to 50 but cap at 40 for balance

        // 2) A+ environment (ADX, EMA slope, ATR momentum, pivots room)
        // Reuse private helper by proxy: check using public gate ValidateSignal prerequisites
        // Here we partially re-run core checks inline to avoid private method access
        int trend = GetTrendDirection(InpTrendTF);
        if(trend==direction) score += 10;
        // ADX M15
        int adx = iADX(_Symbol, PERIOD_M15, 14);
        if(adx!=INVALID_HANDLE){ double a[2]; if(CopyBuffer(adx,0,0,2,a)>=1){ if(a[0] >= MathMax(5, InpMinADX)) score += 10; } IndicatorRelease(adx); }
        // EMA slope H1 in direction
        int emaF = iMA(_Symbol, PERIOD_H1, MathMax(2, InpEMAFast), 0, MODE_EMA, PRICE_CLOSE);
        if(emaF!=INVALID_HANDLE){ double f[6]; if(CopyBuffer(emaF,0,0,6,f)>=5){ double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT); double slope=(f[0]-f[5])/MathMax(pt,1e-12); if((direction>0 && slope>=InpMinEMASlopePoints) || (direction<0 && slope<=-InpMinEMASlopePoints)) score += 10; } IndicatorRelease(emaF);}
        
        // 3) Momentum via ATR(M1): now >= k * average over lookback
        int look = MathMax(10, InpGodATRLookback);
        int atrH = iATR(_Symbol, PERIOD_M1, MathMax(5, InpATRShort));
        if(atrH!=INVALID_HANDLE){ double arr[180]; int n=CopyBuffer(atrH,0,0,MathMin(look+1,ArraySize(arr)),arr); IndicatorRelease(atrH); if(n>=look){ double now=arr[0]; double avg=0; for(int i=1;i<look;i++) avg+=arr[i]; avg/=MathMax(1,look-1); if(now >= InpGodATRBoostMin * MathMax(1e-8, avg)) score += 10; } }

        // 4) SR proximity coherence
        if(InpDrawMTFZones && InpGodRequireSRNear)
        {
            double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(IsNearAnyMTFZone(px, direction)) score += 10;
        }

        // 5) Spread gate: rewards tight spread
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int spreadPts = (int)MathRound((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID))/MathMax(pt,1e-12));
        if(spreadPts <= MathMax(3, InpMaxSpreadPoints/3)) score += 10;

        // Cap 0..100
        if(score<0) score=0; if(score>100) score=100; return score;
    }
};

class CTradeExecutor {
private:
    CTrade m_trade;
    
    bool PlacePendingLimit(const int direction, const double entryPrice, double slPrice, double tpPrice)
    {
        // Validate inputs
        if(direction==0 || entryPrice<=0.0) return false;
        ENUM_ORDER_TYPE type = (direction>0)? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
        double lotSize = CalculateValidLotSize(); if(lotSize<=0) return false;
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

        // Ensure SL/TP are on the correct side and respect minimum distance from ENTRY (not market price)
        if(slPrice>0 || tpPrice>0)
        {
            double tmpSL = slPrice; double tmpTP = tpPrice;
            EnsureValidStops(_Symbol, direction, entryPrice, pt, tmpSL, tmpTP);
            slPrice = tmpSL; tpPrice = tmpTP;
        }

        // Expiration
        datetime expiry = TimeCurrent() + MathMax(30, InpAIPendingExpirySec);

        // Submit pending order request directly
        {
            MqlTradeRequest rq; MqlTradeResult rs; 
            rq.action = TRADE_ACTION_PENDING;
            rq.symbol = _Symbol;
            rq.type = type;
            rq.price = NormalizeDouble(entryPrice, digits);
            rq.sl = (slPrice>0.0)? NormalizeDouble(slPrice, digits) : 0.0;
            rq.tp = (tpPrice>0.0)? NormalizeDouble(tpPrice, digits) : 0.0;
            rq.volume = lotSize;
            rq.type_filling = ORDER_FILLING_RETURN;
            rq.type_time = ORDER_TIME_SPECIFIED;
            rq.expiration = expiry;
            rq.deviation = 10;
            rq.magic = InpMagicNumber;
            rq.comment = "AI_LIMIT";
            if(!OrderSend(rq, rs))
            {
                Print("❌ Echec LIMIT IA: ", GetLastError(), " / ", rs.comment);
                return false;
            }
            Print("✅ LIMIT IA placé: ", (direction>0?"BUY_LIMIT":"SELL_LIMIT"), " @ ", DoubleToString(rq.price,digits),
                  " SL=", (rq.sl>0? DoubleToString(rq.sl,digits):"0"), " TP=", (rq.tp>0?DoubleToString(rq.tp,digits):"0"));
            return true;
        }
    }
    void DrawOrderLine(const string name, const double price, const color c)
    {
        datetime t0, t1; GetChartTimeWindow(t0, t1);
        if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
        if(ObjectCreate(0, name, OBJ_TREND, 0, t0, price, t1, price))
        {
            ObjectSetInteger(0, name, OBJPROP_COLOR, c);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
        }
    }
    
public:
    CTradeExecutor() {
        m_trade.SetExpertMagicNumber(InpMagicNumber);
        m_trade.SetDeviationInPoints(10);
        m_trade.SetTypeFilling(ORDER_FILLING_FOK);
    }
    
    // Compute trend direction on given TF: >0 uptrend, <0 downtrend, 0 neutral
    static int GetTrendDirection(const ENUM_TIMEFRAMES tf)
    {
        int emaP = MathMax(5, InpEMAPeriod);
        int handle = iMA(_Symbol, tf, emaP, 0, MODE_EMA, PRICE_CLOSE);
        if(handle==INVALID_HANDLE) return 0;
        double buf[12]; int n = CopyBuffer(handle, 0, 0, ArraySize(buf), buf); IndicatorRelease(handle);
        if(n < 11) return 0;
        double emaNow = buf[0]; double emaPrev10 = buf[10];
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double slopePts = (emaNow - emaPrev10) / MathMax(pt,1e-12);
        if(MathAbs(slopePts) < MathMax(1, InpMinEMASlopePips*10)) return 0;
        int adxH = iADX(_Symbol, tf, MathMax(5, InpADXPeriod));
        if(adxH!=INVALID_HANDLE)
        {
            double adx[2]; if(CopyBuffer(adxH,2,0,2,adx)>=1) { if(adx[0] < InpMinADX) return 0; }
            IndicatorRelease(adxH);
        }
        return (slopePts>0)? 1 : -1;
    }
    
    bool ExecuteTrade(int direction) {
        if(direction == 0) return false;
        
        // VÉRIFICATION ABSOLUE: Maximum 2 positions simultanées - JAMAIS PLUS
        int currentPositions = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                currentPositions++;
            }
        }
        
        if(currentPositions >= 2) {
            Print("🚫 EXECUTE TRADE BLOQUÉ - ", currentPositions, " positions déjà ouvertes (MAXIMUM: 2)");
            Print("🛑 IMPOSSIBLE D'OUVRIR UNE NOUVELLE POSITION - Limite dépassée");
            return false;
        }
        
        if(currentPositions == 1) {
            Print("⚠️ EXECUTE TRADE - 1 position déjà ouverte, maximum 1 de plus");
        }
        
        // ENCOURAGER: Trades sur volatilités, step index et forex
        bool isVolatility = IsVolatilityIndex(_Symbol);
        bool isStepIndex = IsStepIndex(_Symbol);
        bool isForex = IsForexSymbol(_Symbol);
        
        if(isVolatility || isStepIndex || isForex) {
            Print("✅ SYMBOL FAVORI - ", _Symbol, " (", 
                  (isVolatility ? "Volatilité" : ""), 
                  (isStepIndex ? "Step Index" : ""), 
                  (isForex ? "Forex" : ""), ") - Trade encouragé");
        }
        
        // Vérifier le cooldown après perte avant d'ouvrir une nouvelle position
        if(IsSymbolInCooldown(_Symbol)) {
            Print("⏳ COOLDOWN ACTIF - Attente d'une opportunité confirmée sur ", _Symbol);
            return false;
        }
        
        // Vérifier les pertes consécutives pour ce symbole
        if(IsSymbolInConsecutiveLossCooldown(_Symbol)) {
            Print("🚫 SYMBOLE ", _Symbol, " EN COOLDOWN après ", InpMaxConsecutiveLosses, " pertes consécutives");
            return false;
        }
        
        // Vérifier la limite globale de positions simultanées
        if(IsGlobalPositionLimitReached()) {
            return false;
        }
        
        double price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                                          SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // Calculer le Stop Loss adaptatif
        double sl_points = CalculateAdaptiveStopLoss(_Symbol, price, direction);
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double sl_price = (direction > 0) ? price - (sl_points * point) : price + (sl_points * point);
        // Sniper: limiter la distance SL par risque $ si activé
        if(InpSniperMode && InpSniperMaxLossUSD>0.0)
        {
            double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
            double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
            double dollarPerPointPerLot = 0.0;
            if(tickSize>0.0 && point>0.0) dollarPerPointPerLot = tickValue * (point / tickSize);
            double lotPreview = CalculateValidLotSize(); if(lotPreview<=0) lotPreview = 0.20;
            if(dollarPerPointPerLot>0.0)
            {
                double maxPts = (InpSniperMaxLossUSD / MathMax(1e-8, dollarPerPointPerLot)) / MathMax(1e-8, lotPreview);
                double maxPtsClamped = MathMax(1.0, MathMin(sl_points, maxPts));
                sl_points = maxPtsClamped;
                sl_price = (direction>0)? price - sl_points*point : price + sl_points*point;
            }
        }
        
        // Calculer la taille de lot intelligente
        // Fixer le lot à 0.20 pour Boom/Crash, sinon utiliser la logique existante
        double lotSize = CalculateValidLotSize();
        double lotRaw = lotSize;
        if(IsBoomCrashIndex(_Symbol)) lotRaw = 0.20; else if(InpUseSmartTrading) lotRaw = CalculateSmartLotSize(_Symbol, price, sl_price);
        lotSize = SnapLotToSymbol(_Symbol, lotRaw);
        
        if(lotSize <= 0) {
            Print("❌ Lot size invalide: ", lotSize);
            return false;
        }
        
        // Calculer le Take Profit dynamique
        double tp_points = CalculateDynamicTakeProfit(_Symbol, price, direction, sl_price);
        double tp_price = (direction > 0) ? price + (tp_points * point) : price - (tp_points * point);
        
        // Vérifier le ratio risque/récompense
        double risk_reward_ratio = tp_points / sl_points;
        if(risk_reward_ratio < InpMinRiskRewardRatio) {
            Print("⚠️ Ratio risque/récompense insuffisant: ", DoubleToString(risk_reward_ratio, 2), " < ", DoubleToString(InpMinRiskRewardRatio, 2));
            // Ajuster le TP pour respecter le ratio minimum
            tp_points = sl_points * InpMinRiskRewardRatio;
            tp_price = (direction > 0) ? price + (tp_points * point) : price - (tp_points * point);
        }
        
        EnsureValidStops(_Symbol, direction, price, point, sl_price, tp_price);
        bool result = (direction>0)? m_trade.Buy(lotSize, _Symbol, price, sl_price, tp_price, "SpikeHunter Smart")
                                   : m_trade.Sell(lotSize, _Symbol, price, sl_price, tp_price, "SpikeHunter Smart");

        // Si échec, tenter ajustements anti "request failed"
        if(!result)
        {
            int err = (int)m_trade.ResultRetcode();
            Print("⚠️ Échec envoi ordre (retcode=", err, ") → tentative d'ajustement.");
            // 1) Nudge SL/TP légèrement et réessayer
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double nudgePts = MathMax(1, InpStopsBufferPoints);
            double sl_adj = sl_price;
            double tp_adj = tp_price;
            if(direction > 0) { if(sl_price>0) sl_adj = sl_price - nudgePts*point; if(tp_price>0) tp_adj = tp_price + nudgePts*point; }
            else              { if(sl_price>0) sl_adj = sl_price + nudgePts*point; if(tp_price>0) tp_adj = tp_price - nudgePts*point; }
            if(direction > 0) result = m_trade.Buy(lotSize, _Symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            else              result = m_trade.Sell(lotSize, _Symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            // 2) Si toujours KO, augmenter le volume de 0.2 et réessayer
            if(!result)
            {
                double lot_up = SnapLotToSymbol(_Symbol, lotSize + 0.20);
                if(direction > 0) result = m_trade.Buy(lot_up, _Symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
                else              result = m_trade.Sell(lot_up, _Symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            }
            // 3) Derniers recours: enlever TP puis SL
            if(!result)
            {
                double tp_try = 0.0;
                if(direction > 0) result = m_trade.Buy(lotSize, _Symbol, price, sl_adj, tp_try, "SpikeHunter Smart");
                else              result = m_trade.Sell(lotSize, _Symbol, price, sl_adj, tp_try, "SpikeHunter Smart");
            }
            if(!result)
            {
                double sl_try = 0.0; double tp_try2 = 0.0;
                if(direction > 0) result = m_trade.Buy(lotSize, _Symbol, price, sl_try, tp_try2, "SpikeHunter Smart");
                else              result = m_trade.Sell(lotSize, _Symbol, price, sl_try, tp_try2, "SpikeHunter Smart");
            }
        }
        
        if(result) {
            // Ajouter au système de trading intelligent
            if(InpUseSmartTrading) {
                ulong ticket = m_trade.ResultOrder();
                AddSmartTrade(ticket, price, lotSize, direction, sl_price, tp_price);
            }
            
            Print("🧠 TRADE INTELLIGENT EXÉCUTÉ: ", (direction > 0 ? "BUY" : "SELL"),
                  " | Lot: ", DoubleToString(lotSize, 2),
                  " | SL: ", DoubleToString(sl_points, 1), " pts",
                  " | TP: ", DoubleToString(tp_points, 1), " pts",
                  " | Ratio R/R: ", DoubleToString(risk_reward_ratio, 2));
            
            // Dessiner lignes SL/TP si disponibles
            if(tp_price>0) DrawOrderLine(StringFormat("TP_%s_%d", _Symbol, (int)TimeCurrent()), tp_price, clrGreen);
            if(sl_price>0) DrawOrderLine(StringFormat("SL_%s_%d", _Symbol, (int)TimeCurrent()), sl_price, clrTomato);

            if(InpSendNotifications) {
                string side = (direction > 0 ? "BUY" : "SELL");
                string msg = StringFormat("SpikeHunter Smart: Trade %s exécuté", side);
                NotifyOnce(msg);
            }
            
            if(InpPlaySounds) {
                PlaySound(InpSoundFile);
            }
        } else {
            // Gestion des erreurs de trade (par exemple, stops invalides)
            // Comme on n'a pas le droit de modifier, on se contente de loguer l'erreur.
            Print("❌ ÉCHEC TRADE: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment());
        }
        
        return result;
    }
    
    bool ExecuteTradeOnSymbol(const string symbol, const int direction)
    {
        if(direction==0) return false;
        
        // ENCOURAGER: Trades sur volatilités, step index et forex
        bool isVolatility = IsVolatilityIndex(symbol);
        bool isStepIndex = IsStepIndex(symbol);
        bool isForex = IsForexSymbol(symbol);
        
        if(isVolatility || isStepIndex || isForex) {
            Print("✅ SYMBOL FAVORI - ", symbol, " (", 
                  (isVolatility ? "Volatilité" : ""), 
                  (isStepIndex ? "Step Index" : ""), 
                  (isForex ? "Forex" : ""), ") - Trade encouragé");
        }
        
        // Vérifier le cooldown adaptatif après perte
        if(IsSymbolInCooldown(symbol)) {
            // Vérifier si on peut trader malgré le cooldown du symbole
            if(CanTradeDespiteCooldown()) {
                Print("🚀 COOLDOWN SYMBOLE BYPASS - Conditions favorables sur ", symbol);
            } else {
                Print("⏳ COOLDOWN ACTIF - Attente d'une opportunité confirmée sur ", symbol);
                return false;
            }
        }
        
        // Vérifier les pertes consécutives pour ce symbole
        if(IsSymbolInConsecutiveLossCooldown(symbol)) {
            Print("🚫 SYMBOLE ", symbol, " EN COOLDOWN après ", InpMaxConsecutiveLosses, " pertes consécutives");
            return false;
        }
        
        // Vérifier la limite globale de positions simultanées
        if(IsGlobalPositionLimitReached()) {
            return false;
        }
        
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double price = (direction>0)? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
        if(point<=0 || price<=0) return false;

        int stops = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        int bufferPts = MathMax(0, InpStopsBufferPoints);
        if(IsBoomCrashIndex(symbol)) { stops = (int)MathCeil(stops*MathMax(1.0, InpBoomCrashStopsMultiplier)); bufferPts = (int)MathCeil(bufferPts*MathMax(1.0, InpBoomCrashStopsMultiplier)); }
        int minPts = MathMax(1, stops + bufferPts);
        double sl_points = MathMax((double)InpStopLoss, (double)minPts);
        double sl_price = (direction>0)? price - sl_points*point : price + sl_points*point;

        double tp_points = CalculateDynamicTakeProfit(symbol, price, direction, sl_price);
        double tp_price = (direction>0)? price + tp_points*point : price - tp_points*point;
        double risk_reward_ratio = tp_points / sl_points;
        if(risk_reward_ratio < InpMinRiskRewardRatio)
        {
            tp_points = sl_points * InpMinRiskRewardRatio;
            tp_price = (direction>0)? price + tp_points*point : price - tp_points*point;
        }

        double lotSize = (IsBoomCrashIndex(symbol))? 0.20 : CalculateSmartLotSize(symbol, price, sl_price);
        if(lotSize<=0) return false;

        bool result = (direction>0)? m_trade.Buy(lotSize, symbol, price, sl_price, tp_price, "SpikeHunter Smart")
                                   : m_trade.Sell(lotSize, symbol, price, sl_price, tp_price, "SpikeHunter Smart");
        if(!result)
        {
            double nudgePts = MathMax(1, InpStopsBufferPoints);
            double sl_adj = sl_price, tp_adj = tp_price;
            if(direction>0){ if(sl_price>0) sl_adj-=nudgePts*point; if(tp_price>0) tp_adj+=nudgePts*point; }
            else            { if(sl_price>0) sl_adj+=nudgePts*point; if(tp_price>0) tp_adj-=nudgePts*point; }
            result = (direction>0)? m_trade.Buy(lotSize, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart")
                                  : m_trade.Sell(lotSize, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            if(!result)
            {
                double lot_up = lotSize + 0.20; if(IsBoomCrashIndex(symbol)) lot_up = SnapToDerivBoomCrashLots(lot_up);
                result = (direction>0)? m_trade.Buy(lot_up, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart")
                                      : m_trade.Sell(lot_up, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            }
        }
        return result;
    }
    
public:
    bool ExecutePendingFromAI(const int direction, const double entryPrice, const double slPrice, const double tpPrice)
    {
        if(!InpAIEnablePendingOrders) return false;
        return PlacePendingLimit(direction, entryPrice, slPrice, tpPrice);
    }
    
private:
    void ComputeDynamicSLTP(const int direction, const double entryPrice, double &outSL, double &outTP)
    {
        // Important: Conformément à la règle "pas autorisé à modifier une position en cours",
        // nous calculons SL/TP une seule fois à l'ouverture et ils ne seront jamais modifiés.
        // Le code qui suit est une adaptation pour calculer un SL/TP initial SANS modification ultérieure.

        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        int stops = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
        int bufferPts = MathMax(0, InpStopsBufferPoints);
        if(IsBoomCrashIndex(_Symbol)) {
            // multiplier les stops et buffer pour éviter invalid stops sur Boom/Crash
            stops = (int)MathCeil(stops * MathMax(1.0, InpBoomCrashStopsMultiplier));
            bufferPts = (int)MathCeil(bufferPts * MathMax(1.0, InpBoomCrashStopsMultiplier));
        }
        int minPts = MathMax(1, stops + bufferPts);
        
        // Base SL/TP from inputs
        double baseSLptsInput = MathMax((double)InpStopLoss, (double)minPts);
        double baseTPptsInput = MathMax((double)InpTakeProfit, (double)minPts*2);

        // ATR-based distances for initial SL/TP
        double atrDistPoints = 0.0;
        if(InpUseATRForSLTP)
        {
            int atr = iATR(_Symbol, PERIOD_M1, MathMax(5, InpATRPeriod));
            if(atr != INVALID_HANDLE)
            {
                double a[2];
                if(CopyBuffer(atr, 0, 0, 2, a) >= 1)
                {
                    double atrValue = a[0];
                    if(atrValue > 0)
                {
                    // Convert ATR (in price) to points
                        double atrPoints = atrValue / MathMax(point, 1e-12);
                    atrDistPoints = MathMax(atrPoints, minPts);
                    }
                }
                IndicatorRelease(atr);
            }
        }
        
        // Determine final initial SL/TP points
        double finalSLpts = baseSLptsInput;
        double finalTPpts = baseTPptsInput;

        if(InpUseATRForSLTP && atrDistPoints > 0)
        {
            finalSLpts = atrDistPoints * MathMax(0.5, InpSL_ATR_Mult);
            finalTPpts = atrDistPoints * MathMax(1.0, InpTP_ATR_Mult);
        }

        // For Boom/Crash: cap SL to 10 previous candles' extreme and force TP = 3x SL if possible
        if(IsBoomCrashIndex(_Symbol))
        {
            MqlRates rr[];
            if(CopyRates(_Symbol, PERIOD_M1, 0, 12, rr) >= 11)
            {
                double low10 = rr[1].low;
                double high10 = rr[1].high;
                for(int i=2;i<=10;i++){ if(rr[i].low < low10) low10 = rr[i].low; if(rr[i].high > high10) high10 = rr[i].high; }
                double distPts10 = 0.0;
                if(direction > 0) // BUY on Boom
                    distPts10 = (entryPrice - low10) / MathMax(point,1e-12);
                else // SELL on Crash
                    distPts10 = (high10 - entryPrice) / MathMax(point,1e-12);
                distPts10 = MathMax((double)minPts, distPts10);
                finalSLpts = MathMax((double)minPts, MathMin(finalSLpts, distPts10));
            }
            // Force TP = 3x SL for Boom/Crash, IF initial calculation allows
            finalTPpts = 3.0 * finalSLpts;
        }

        // Monetary guards per symbol:
        // - Boom/Crash: cap SL to $2 max loss; TP in dollars not enforced here (spike close will handle exits)
        // - Others: cap SL to $1 max loss; enforce TP >= $5 profit
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double lotForMoney = CalculateValidLotSize();
    if(IsBoomCrashIndex(_Symbol)) lotForMoney = 0.20;
        double dollarPerPointPerLot = 0.0;
        if(tickSize>0.0 && point>0.0) dollarPerPointPerLot = tickValue * (point / tickSize);
        if(dollarPerPointPerLot>0.0 && lotForMoney>0.0)
        {
            bool isBC = IsBoomCrashIndex(_Symbol);
            double lossUSD  = isBC ? 2.0 : 1.0;
            double profitUSD= isBC ? 0.0 : 5.0;

            double maxSLPtsByMoney = MathFloor(MathAbs(lossUSD) / (dollarPerPointPerLot * lotForMoney));
            if(maxSLPtsByMoney > 0.0)
                finalSLpts = MathMin(finalSLpts, maxSLPtsByMoney);

            if(profitUSD > 0.0)
            {
                double minTPPtsByMoney = MathCeil(MathAbs(profitUSD) / (dollarPerPointPerLot * lotForMoney));
                if(minTPPtsByMoney > 0.0)
                    finalTPpts = MathMax(finalTPpts, minTPPtsByMoney);
            }
        }

        // Enforce minimum Risk:Reward (TP >= R * SL)
        double rrMin = MathMax(1.0, InpMinRiskReward);
        if(finalTPpts < rrMin * finalSLpts)
            finalTPpts = rrMin * finalSLpts;
        
        // Prices
        if(direction > 0) // BUY
        {
            outSL = NormalizeDouble(entryPrice - finalSLpts * point, digits);
            outTP = NormalizeDouble(entryPrice + finalTPpts * point, digits);
        }
        else // SELL
        {
            outSL = NormalizeDouble(entryPrice + finalSLpts * point, digits);
            outTP = NormalizeDouble(entryPrice - finalTPpts * point, digits);
        }
        
        // Final validation: ensure distances >= minPts and SL/TP coherent
        double minDist = minPts * point;
        if(direction > 0)
        {
            if((entryPrice - outSL) < minDist) outSL = NormalizeDouble(entryPrice - minDist, digits);
            if((outTP - entryPrice) < minDist) outTP = NormalizeDouble(entryPrice + minDist, digits);
        }
        else
        {
            if((outSL - entryPrice) < minDist) outSL = NormalizeDouble(entryPrice + minDist, digits);
            if((entryPrice - outTP) < minDist) outTP = NormalizeDouble(entryPrice - minDist, digits);
        }
        
        // Safeguard: if distances are still too tight (rounding), zero them to avoid invalid stops
        if(MathAbs(entryPrice - outSL) < minDist - 1e-8 || MathAbs(outTP - entryPrice) < minDist - 1e-8)
        {
            outSL = 0.0; outTP = 0.0;
        }
    }
    
    // Aligne un lot sur l'échelle Deriv Boom/Crash autorisée
    double SnapToDerivBoomCrashLots(const double desired)
    {
        // Liste discrète utilisée par Deriv pour Boom/Crash
        double allowed[] = {0.20, 0.50, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0};
        double target = desired;
        if(target <= allowed[0]) return allowed[0];
        for(int i=1;i<ArraySize(allowed);i++)
        {
            if(target <= allowed[i])
            {
                // choisir la valeur la plus proche
                double low = allowed[i-1];
                double high = allowed[i];
                return (MathAbs(target-low) <= MathAbs(high-target)) ? low : high;
            }
        }
        return allowed[ArraySize(allowed)-1];
    }

    double CalculateValidLotSize() {
        // Obtenir les paramètres de lot du symbole
        double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        
    // Par défaut, utiliser l'input
    double lotSize = InpLotSize;

        // Si Boom/Crash, aligner explicitement sur l'échelle Deriv
        if(IsBoomCrashIndex(_Symbol))
            lotSize = SnapToDerivBoomCrashLots(0.20);
        
        // Normaliser selon le step
        if(lotStep > 0.0)
            lotSize = MathFloor(lotSize / lotStep) * lotStep;
        
        // Bornes broker
        if(lotSize < minLot) lotSize = minLot;
        if(lotSize > maxLot) lotSize = maxLot;
        
        // Vérification finale
        if(lotSize < minLot || lotSize > maxLot) {
            Print("❌ Lot size invalide après normalisation: ", lotSize,
                  " MinBroker:", minLot, " MaxBroker:", maxLot, " Step:", lotStep);
            return 0;
        }
        
        return NormalizeDouble(lotSize, 2);
    }
};

//--- Variables globales
CRiskManager* g_riskManager = NULL;
CSignalDetector* g_signalDetector = NULL;
CSignalValidator* g_signalValidator = NULL;
CTradeExecutor* g_tradeExecutor = NULL;

// Global cooldown timer after global loss close
static datetime g_globalCooldownUntil = 0;

//--- Variables pour le trading intelligent
struct SmartTradeInfo {
    ulong ticket;
    double entry_price;
    double lot_size;
    int direction;
    double original_sl;
    double original_tp;
    double current_sl;
    double current_tp;
    bool partial_closed;
    double partial_close_price;
    datetime open_time;
    double max_profit;
    double max_loss;
    bool trailing_active;
    double confidence_score;  // Score de confiance du signal
    bool validated_win;       // Trade validé comme gagnant
    datetime validation_time; // Temps de validation
};
SmartTradeInfo smart_trades[10];
int smart_trade_count = 0;

//--- Variables pour la validation des signaux
struct SignalValidation {
    int direction;
    double confidence;
    datetime signal_time;
    double entry_price;
    bool spike_verified;
    bool trade_validated;
};
SignalValidation pending_signals[5];
int pending_signal_count = 0;

//--- Variables de gestion
datetime g_lastDay = -1;
bool g_isEarlySignal = false; // true si le signal courant provient d'un pré-spike / EMA-touch

// --- Cache IA pour anticipation
static int      g_aiLastDir = 0;          // 1 BUY, -1 SELL, 0 neutre
static int      g_aiLastConf = 0;         // 0..100
static datetime g_aiLastUpdate = 0;       // timestamp dernier refresh
static int      g_aiTtlSeconds = 15;      // validité du cache
static double   g_aiLastEntry = 0.0;      // prix d'entrée absolu si fourni
static double   g_aiLastSL    = 0.0;      // SL absolu si fourni
static double   g_aiLastTP    = 0.0;      // TP absolu si fourni
static string   g_aiLastNote  = "";       // Explication IA (NOTE=...)

// --- Cache signaux externes API
static int      g_extLastDir = 0;         // 1 BUY, -1 SELL, 0 neutre
static int      g_extLastConf = 0;        // 0..100
static datetime g_extLastUpdate = 0;      // timestamp

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🤖 SPIKE HUNTER PROFESSIONNEL - Version 3.0 Corrigée");
    Print("   ✅ Architecture modulaire et sécurisée");
    Print("   ✅ Gestion des risques professionnelle");
    Print("   ✅ Validation des signaux rigoureuse");
    Print("   ✅ Performance optimisée");
    Print("   ✅ Système de calcul de performance intégré");
    
    // Initialiser les gestionnaires
    g_riskManager = new CRiskManager();
    g_signalDetector = new CSignalDetector();
    g_tradeExecutor = new CTradeExecutor();
    
    // Initialiser le calculateur de performance
    if(InpEnablePerformanceTracking) {
        InitializePerformanceCalculator();
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🤖 SPIKE HUNTER - Arrêt du trading");
    
    // Exporter les données de performance finales
    if(InpEnablePerformanceTracking && InpExportPerformanceData) {
        ExportPerformanceData();
    }
    
    // Nettoyer les objets graphiques de performance
    if(InpShowPerformancePanel) {
        ObjectDelete(0, "PerformancePanel");
        ObjectDelete(0, "PerformanceText");
    }
    
    // Nettoyer les ressources
    if(g_riskManager != NULL) {
        delete g_riskManager;
        g_riskManager = NULL;
    }
    if(g_signalDetector != NULL) {
        delete g_signalDetector;
        g_signalDetector = NULL;
    }
    if(g_tradeExecutor != NULL) {
        delete g_tradeExecutor;
        g_tradeExecutor = NULL;
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//| Calculer la taille de lot intelligente basée sur le risque       |
//+------------------------------------------------------------------+
double CalculateSmartLotSize(string symbol, double entry_price, double stop_loss_price)
{
    if(!InpUseSmartTrading) return InpLotSize;
    
    // Utiliser le capital engagé restant au lieu du solde total
    double currentCapitalEngagedUSD = CalculateCapitalEngaged();
    double remainingCapitalUSD = InpMaxCapitalEngagedUSD - currentCapitalEngagedUSD;
    
    // Si on a déjà atteint la limite de capital engagé, retourner 0
    if(remainingCapitalUSD <= 0) {
        Print("🚫 CAPITAL ENGAGÉ LIMITE ATTEINTE - Aucun nouveau trade possible");
        return 0.0;
    }
    
    // Utiliser le capital restant comme base de calcul
    double risk_amount = MathMin(remainingCapitalUSD * 0.5, 5.0); // Maximum 5$ par trade ou 50% du capital restant
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(point <= 0 || tick_value <= 0 || tick_size <= 0) return InpLotSize;
    
    // Calculer la distance du stop loss en points
    double sl_distance_points = MathAbs(entry_price - stop_loss_price) / point;
    
    // Calculer la valeur du risque par point
    double risk_per_point = tick_value * (point / tick_size);
    
    // Calculer la taille de lot basée sur le risque
    double calculated_lot = risk_amount / (sl_distance_points * risk_per_point);
    
    // Appliquer les limites
    double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    calculated_lot = MathMax(calculated_lot, min_lot);
    calculated_lot = MathMin(calculated_lot, max_lot);
    
    // Arrondir au step
    if(lot_step > 0) {
        calculated_lot = MathRound(calculated_lot / lot_step) * lot_step;
    }
    
    Print("🧠 LOT INTELLIGENT: Risque: $", DoubleToString(risk_amount, 2), 
          " | Distance SL: ", DoubleToString(sl_distance_points, 1), " pts | Lot: ", DoubleToString(calculated_lot, 2));
    
    return calculated_lot;
}

//+------------------------------------------------------------------+
//| Calculer le Take Profit dynamique basé sur la volatilité        |
//+------------------------------------------------------------------+
double CalculateDynamicTakeProfit(string symbol, double entry_price, int direction, double stop_loss_price)
{
    if(!InpUseDynamicTP) return InpTakeProfit;
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double sl_distance_points = MathAbs(entry_price - stop_loss_price) / point;
    
    // Calculer l'ATR pour la volatilité
    int atr_handle = iATR(symbol, PERIOD_M1, 14);
    if(atr_handle == INVALID_HANDLE) return InpTakeProfit;
    
    double atr_values[1];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_values) < 1) {
        IndicatorRelease(atr_handle);
        return InpTakeProfit;
    }
    
    double atr_points = atr_values[0] / point;
    IndicatorRelease(atr_handle);
    
    // Calculer le TP dynamique basé sur le ratio risque/récompense et la volatilité
    double base_tp_points = sl_distance_points * InpMinRiskRewardRatio;
    double volatility_multiplier = MathMin(2.0, MathMax(0.5, atr_points / 10.0));
    
    double dynamic_tp_points = base_tp_points * volatility_multiplier;
    
    // Limiter le TP maximum
    dynamic_tp_points = MathMin(dynamic_tp_points, InpTakeProfit * 3.0);
    
    Print("🎯 TP DYNAMIQUE: SL: ", DoubleToString(sl_distance_points, 1), 
          " pts | ATR: ", DoubleToString(atr_points, 1), " pts | TP: ", DoubleToString(dynamic_tp_points, 1), " pts");
    
    return dynamic_tp_points;
}

//+------------------------------------------------------------------+
//| Calculer le Stop Loss adaptatif                                 |
//+------------------------------------------------------------------+
double CalculateAdaptiveStopLoss(string symbol, double entry_price, int direction)
{
    if(!InpUseAdaptiveSL) return InpStopLoss;
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Calculer l'ATR pour la volatilité
    int atr_handle = iATR(symbol, PERIOD_M1, 14);
    if(atr_handle == INVALID_HANDLE) return InpStopLoss;
    
    double atr_values[1];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_values) < 1) {
        IndicatorRelease(atr_handle);
        return InpStopLoss;
    }
    
    double atr_points = atr_values[0] / point;
    IndicatorRelease(atr_handle);
    
    // Calculer le SL adaptatif basé sur l'ATR
    double adaptive_sl_points = MathMax(InpStopLoss * 0.5, atr_points * 1.5);
    adaptive_sl_points = MathMin(adaptive_sl_points, InpStopLoss * 2.0);
    
    Print("🛡️ SL ADAPTATIF: ATR: ", DoubleToString(atr_points, 1), 
          " pts | SL: ", DoubleToString(adaptive_sl_points, 1), " pts");
    
    return adaptive_sl_points;
}

//+------------------------------------------------------------------+
//| Gérer les trades intelligents                                    |
//+------------------------------------------------------------------+
void ManageSmartTrades()
{
    if(!InpUseSmartTrading) return;
    
    for(int i = 0; i < smart_trade_count; i++) {
        if(smart_trades[i].ticket == 0) continue;
        
        if(!PositionSelectByTicket(smart_trades[i].ticket)) {
            // Position fermée, nettoyer
            smart_trades[i].ticket = 0;
            continue;
        }
        
        double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
        double current_profit = PositionGetDouble(POSITION_PROFIT);
        double current_volume = PositionGetDouble(POSITION_VOLUME);
        
        // Vérifier la fermeture automatique après spike (seulement si en gain)
        if(InpImmediateCloseAfterSpike && DetectSpikeForClose() && current_profit > 0.0) {
            string symbol = PositionGetString(POSITION_SYMBOL);
            int type = (int)PositionGetInteger(POSITION_TYPE);
            
            Print("🚨 SPIKE DÉTECTÉ + GAIN - Fermeture immédiate du trade ", smart_trades[i].ticket, 
                  " sur ", symbol, " - Profit: $", DoubleToString(current_profit, 2));
            
            // Fermer la position manuellement
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_DEAL;
            request.position = smart_trades[i].ticket;
            request.symbol = symbol;
            request.volume = current_volume;
            request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.magic = InpMagicNumber;
            request.comment = "SpikeCloseGain";
            
            if(OrderSend(request, result)) {
                Print("✅ Trade fermé automatiquement après spike + gain - Profit final: $", DoubleToString(current_profit, 2));
                smart_trades[i].ticket = 0;
                continue;
            } else {
                Print("❌ Échec fermeture automatique après spike: ", GetLastError());
            }
        }
        
        // Fermeture immédiate si profit > seuil configuré (capture rapide des gains)
        // Pour les indices Boom/Crash/Volatility, fermer selon le niveau de volatilité
        double quick_threshold = InpQuickGainThreshold;
        string symbol = PositionGetString(POSITION_SYMBOL);
        if(StringFind(symbol, "Crash") >= 0 || StringFind(symbol, "Boom") >= 0) {
            quick_threshold = 0.01; // Fermer dès 1 centime de profit pour les indices Boom/Crash
        } else if(IsVolatilityIndex(symbol)) {
            int vol_level = GetVolatilityLevel(symbol);
            // Adapter le seuil selon le niveau de volatilité
            switch(vol_level) {
                case 10:  quick_threshold = 0.05; break;  // Plus rapide pour Vol 10%
                case 25:  quick_threshold = 0.1; break;
                case 50:  quick_threshold = 0.2; break;
                case 75:  quick_threshold = 0.3; break;
                case 100: quick_threshold = 0.4; break;  // Plus patient pour Vol 100%
                default:  quick_threshold = 0.2; break;
            }
        }
        
        if(current_profit > quick_threshold) {
            int type = (int)PositionGetInteger(POSITION_TYPE);
            
            Print("💰 GAIN RAPIDE - Fermeture immédiate du trade ", smart_trades[i].ticket, 
                  " sur ", symbol, " - Profit: $", DoubleToString(current_profit, 2));
            
            // Fermer la position manuellement
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_DEAL;
            request.position = smart_trades[i].ticket;
            request.symbol = symbol;
            request.volume = current_volume;
            request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.magic = InpMagicNumber;
            request.comment = "QuickGain";
            
            if(OrderSend(request, result)) {
                Print("✅ Trade fermé pour gain rapide - Profit final: $", DoubleToString(current_profit, 2));
                smart_trades[i].ticket = 0;
                continue;
            } else {
                Print("❌ Échec fermeture pour gain rapide: ", GetLastError());
            }
        }
        
        // Mettre à jour le profit maximum
        if(current_profit > smart_trades[i].max_profit) {
            smart_trades[i].max_profit = current_profit;
        }
        
        // Mettre à jour la perte maximum
        if(current_profit < smart_trades[i].max_loss) {
            smart_trades[i].max_loss = current_profit;
        }
        
        // Fermeture partielle si profit atteint
        if(InpUsePartialClose && !smart_trades[i].partial_closed) {
            double profit_points = MathAbs(current_price - smart_trades[i].entry_price) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            if(profit_points >= InpPartialCloseAtProfit) {
                ClosePartialPosition(smart_trades[i].ticket, InpPartialClosePercent);
                smart_trades[i].partial_closed = true;
                smart_trades[i].partial_close_price = current_price;
                Print("💰 FERMETURE PARTIELLE: ", DoubleToString(InpPartialClosePercent, 0), "% à ", DoubleToString(profit_points, 1), " pts de profit");
            }
        }
        
        // Trailing stop intelligent
        if(InpUseTrailingStopSmart) {
            ManageTrailingStopSmart(i);
        }
        
        // Sortie immédiate sur premier profit positif (capture du spike)
        if(current_profit > 0.0)
        {
            MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
            rq.action = TRADE_ACTION_DEAL;
            rq.symbol = _Symbol;
            rq.position = smart_trades[i].ticket;
            rq.volume = current_volume;
            rq.type = (smart_trades[i].direction>0)? ORDER_TYPE_SELL : ORDER_TYPE_BUY; // close by opposite
            rq.price = SymbolInfoDouble(_Symbol, (smart_trades[i].direction>0)? SYMBOL_BID:SYMBOL_ASK);
            rq.deviation = 20;
            rq.magic = InpMagicNumber;
            rq.comment = "SpikeCaptureClose";
            if(OrderSend(rq, rs))
            {
                Print("✅ Fermeture immédiate en gain: ", DoubleToString(current_profit,2), " USD");
                // Nettoyer cette structure
                smart_trades[i].ticket = 0;
                continue;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Gérer le trailing stop intelligent                              |
//+------------------------------------------------------------------+
void ManageTrailingStopSmart(int trade_index)
{
    double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
    double current_sl = PositionGetDouble(POSITION_SL);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    // Calculer le profit en points
    double profit_points = MathAbs(current_price - smart_trades[trade_index].entry_price) / point;
    
    // Activer le trailing stop si profit suffisant
    if(profit_points >= InpTrailingStartPoints && !smart_trades[trade_index].trailing_active) {
        smart_trades[trade_index].trailing_active = true;
        Print("🎯 TRAILING STOP ACTIVÉ: ", DoubleToString(profit_points, 1), " pts de profit");
    }
    
    if(smart_trades[trade_index].trailing_active) {
        double new_sl = 0;
        
        if(smart_trades[trade_index].direction > 0) { // BUY
            new_sl = current_price - (InpTrailingStepPoints * point);
            if(new_sl > current_sl) {
                ModifyPositionSL(smart_trades[trade_index].ticket, new_sl);
                smart_trades[trade_index].current_sl = new_sl;
            }
        } else { // SELL
            new_sl = current_price + (InpTrailingStepPoints * point);
            if(current_sl == 0 || new_sl < current_sl) {
                ModifyPositionSL(smart_trades[trade_index].ticket, new_sl);
                smart_trades[trade_index].current_sl = new_sl;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Fermer partiellement une position                              |
//+------------------------------------------------------------------+
void ClosePartialPosition(ulong ticket, double percent)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    double current_volume = PositionGetDouble(POSITION_VOLUME);
    double close_volume = current_volume * (percent / 100.0);
    
    // Arrondir au step de volume
    double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(volume_step > 0) {
        close_volume = MathRound(close_volume / volume_step) * volume_step;
    }
    
    if(close_volume <= 0) return;
    
    MqlTradeRequest request;
    MqlTradeResult result;
    // ZeroMemory(request);
    // ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = _Symbol;
    request.volume = close_volume;
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    request.deviation = 10;
    request.magic = InpMagicNumber;
    request.comment = "PartialClose";
    
    if(OrderSend(request, result)) {
        Print("✅ FERMETURE PARTIELLE: ", DoubleToString(close_volume, 2), " lots fermés");
    }
}

//+------------------------------------------------------------------+
//| Modifier le Stop Loss d'une position                            |
//+------------------------------------------------------------------+
void ModifyPositionSL(ulong ticket, double new_sl)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    // ZeroMemory(request);
    // ZeroMemory(result);
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.sl = new_sl;
    request.tp = PositionGetDouble(POSITION_TP);
    
    if(OrderSend(request, result)) {
        Print("🔄 SL MODIFIÉ: ", DoubleToString(new_sl, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Ajouter un trade intelligent                                    |
//+------------------------------------------------------------------+
void AddSmartTrade(ulong ticket, double entry_price, double lot_size, int direction, double sl_price, double tp_price, double confidence = 0.0)
{
    if(smart_trade_count >= 10) return;
    
    smart_trades[smart_trade_count].ticket = ticket;
    smart_trades[smart_trade_count].entry_price = entry_price;
    smart_trades[smart_trade_count].lot_size = lot_size;
    smart_trades[smart_trade_count].direction = direction;
    smart_trades[smart_trade_count].original_sl = sl_price;
    smart_trades[smart_trade_count].original_tp = tp_price;
    smart_trades[smart_trade_count].current_sl = sl_price;
    smart_trades[smart_trade_count].current_tp = tp_price;
    smart_trades[smart_trade_count].partial_closed = false;
    smart_trades[smart_trade_count].partial_close_price = 0;
    smart_trades[smart_trade_count].open_time = TimeCurrent();
    smart_trades[smart_trade_count].max_profit = 0;
    smart_trades[smart_trade_count].max_loss = 0;
    smart_trades[smart_trade_count].trailing_active = false;
    smart_trades[smart_trade_count].confidence_score = confidence;
    smart_trades[smart_trade_count].validated_win = false;
    smart_trades[smart_trade_count].validation_time = 0;
    
    smart_trade_count++;
    
    Print("🧠 TRADE INTELLIGENT AJOUTÉ: Ticket ", ticket, " | Lot: ", DoubleToString(lot_size, 2), 
          " | SL: ", DoubleToString(sl_price, _Digits), " | TP: ", DoubleToString(tp_price, _Digits),
          " | Confiance: ", DoubleToString(confidence, 1), "%");
}

//+------------------------------------------------------------------+
//| Vérifier la confiance du signal                                 |
//+------------------------------------------------------------------+
bool IsSignalConfidenceValid(double confidence)
{
    return (confidence >= InpMinConfidenceThreshold);
}

//+------------------------------------------------------------------+
//| Ajouter un signal en attente de validation                      |
//+------------------------------------------------------------------+
void AddPendingSignal(int direction, double confidence, double entry_price)
{
    if(pending_signal_count >= 5) return;
    
    pending_signals[pending_signal_count].direction = direction;
    pending_signals[pending_signal_count].confidence = confidence;
    pending_signals[pending_signal_count].signal_time = TimeCurrent();
    pending_signals[pending_signal_count].entry_price = entry_price;
    pending_signals[pending_signal_count].spike_verified = false;
    pending_signals[pending_signal_count].trade_validated = false;
    
    pending_signal_count++;
    
    Print("⏳ SIGNAL EN ATTENTE: Direction ", (direction > 0 ? "BUY" : "SELL"), 
          " | Confiance: ", DoubleToString(confidence, 1), "% | Prix: ", DoubleToString(entry_price, _Digits));
}

//+------------------------------------------------------------------+
//| Vérifier si un spike est arrivé                                 |
//+------------------------------------------------------------------+
bool VerifySpikeArrival(int direction, double entry_price)
{
    if(!InpVerifySpikeBeforeSignal) return true;
    
    double current_price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    // Vérifier si le prix a bougé significativement dans la direction attendue
    double price_movement = MathAbs(current_price - entry_price) / point;
    double min_spike_points = 5.0; // Minimum 5 points de mouvement
    
    // Pour les indices Boom/Crash, être plus sensible
    if(IsBoomCrashIndex(_Symbol)) {
        min_spike_points = 2.0; // Plus sensible pour Boom/Crash
    }
    
    if(direction > 0) {
        // Pour BUY, vérifier que le prix a monté
        bool spike_detected = (current_price > entry_price && price_movement >= min_spike_points);
        if(spike_detected && IsBoomCrashIndex(_Symbol)) {
            Print("🚀 SPIKE BOOM DÉTECTÉ - Prix: ", DoubleToString(current_price, 5), 
                  " vs Entrée: ", DoubleToString(entry_price, 5), 
                  " (+", DoubleToString(price_movement, 1), " points)");
        }
        return spike_detected;
    } else {
        // Pour SELL, vérifier que le prix a baissé
        bool spike_detected = (current_price < entry_price && price_movement >= min_spike_points);
        if(spike_detected && IsBoomCrashIndex(_Symbol)) {
            Print("📉 SPIKE CRASH DÉTECTÉ - Prix: ", DoubleToString(current_price, 5), 
                  " vs Entrée: ", DoubleToString(entry_price, 5), 
                  " (-", DoubleToString(price_movement, 1), " points)");
        }
        return spike_detected;
    }
}

//+------------------------------------------------------------------+
//| Valider qu'un trade est gagnant en 1 minute                    |
//+------------------------------------------------------------------+
bool ValidateTradeWin(ulong ticket, int direction, double entry_price)
{
    if(!InpValidateTradeWin) return true;
    
    if(!PositionSelectByTicket(ticket)) return false;
    
    double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
    double current_profit = PositionGetDouble(POSITION_PROFIT);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    // Vérifier si le trade est en profit après 1 minute
    if(current_profit > 0) {
        double profit_points = MathAbs(current_price - entry_price) / point;
        double min_profit_points = 3.0; // Minimum 3 points de profit
        
        if(profit_points >= min_profit_points) {
            Print("✅ TRADE VALIDÉ GAGNANT: Ticket ", ticket, " | Profit: ", DoubleToString(current_profit, 2), 
                  " | Points: ", DoubleToString(profit_points, 1));
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Gérer les signaux en attente de validation                      |
//+------------------------------------------------------------------+
void ManagePendingSignals()
{
    for(int i = pending_signal_count - 1; i >= 0; i--) {
        // Vérifier si le signal a expiré (plus de 2 minutes)
        if(TimeCurrent() - pending_signals[i].signal_time > 120) {
            Print("⏰ SIGNAL EXPIRÉ: Direction ", (pending_signals[i].direction > 0 ? "BUY" : "SELL"));
            // Supprimer le signal expiré
            for(int j = i; j < pending_signal_count - 1; j++) {
                pending_signals[j] = pending_signals[j + 1];
            }
            pending_signal_count--;
            continue;
        }
        
        // Vérifier si le spike est arrivé
        if(!pending_signals[i].spike_verified) {
            if(VerifySpikeArrival(pending_signals[i].direction, pending_signals[i].entry_price)) {
                pending_signals[i].spike_verified = true;
                Print("🎯 SPIKE VÉRIFIÉ: Direction ", (pending_signals[i].direction > 0 ? "BUY" : "SELL"));
            }
        }
        
        // Si le spike est vérifié, on peut exécuter le trade
        if(pending_signals[i].spike_verified && !pending_signals[i].trade_validated) {
            if(g_riskManager.CanOpenTrade()) {
                // Exécuter le trade avec la confiance
                if(g_tradeExecutor.ExecuteTrade(pending_signals[i].direction)) {
                    pending_signals[i].trade_validated = true;
                    Print("🚀 TRADE EXÉCUTÉ APRÈS VALIDATION: Direction ", (pending_signals[i].direction > 0 ? "BUY" : "SELL"), 
                          " | Confiance: ", DoubleToString(pending_signals[i].confidence, 1), "%");
                    
                    // Ajouter le trade aux trades intelligents avec la confiance
                    ulong ticket = 0;
                    for(int j = PositionsTotal() - 1; j >= 0; j--) {
                        ulong pos_ticket = PositionGetTicket(j);
                        if(PositionSelectByTicket(pos_ticket)) {
                            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                                ticket = pos_ticket;
                                break;
                            }
                        }
                    }
                    
                    if(ticket > 0) {
                        double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
                        double lot_size = PositionGetDouble(POSITION_VOLUME);
                        double sl_price = PositionGetDouble(POSITION_SL);
                        double tp_price = PositionGetDouble(POSITION_TP);
                        AddSmartTrade(ticket, entry_price, lot_size, pending_signals[i].direction, sl_price, tp_price, pending_signals[i].confidence);
                        // Dessiner une seule flèche validée et notifier (post-validation uniquement)
                        DrawSignalArrow(pending_signals[i].direction);
                        if(InpSendNotifications) {
                            string sidev = (pending_signals[i].direction>0?"BUY":"SELL");
                            NotifyOnce(StringFormat("✅ Signal validé %s (≥ %.0f%%) sur %s", sidev, InpMinConfidenceThreshold, _Symbol));
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
// Timers globaux pour ré-entrées
static datetime g_basketReentryArmedAt = 0;
static datetime g_bcReentryArmedTime   = 0;

void OnTick()
{
    if(!InpEnableTrading) return;
    
    // Mettre à jour les données de performance
    if(InpEnablePerformanceTracking) {
        UpdateDailyPerformance();
        
        // Dessiner le panneau de performance
        if(InpShowPerformancePanel) {
            DrawPerformancePanel();
        }
    }
    
    // Gérer les trades intelligents (fermeture partielle, trailing stop, etc.)
    ManageSmartTrades();
    
    // === AMÉLIORATIONS DE TRADING ===
    
    // 1. Trailing stop intelligent basé sur ATR
    ManageIntelligentTrailingStop();
    
    // 2. Fermeture partielle intelligente
    ManageIntelligentPartialClose();
    
    // Gérer les signaux en attente de validation
    ManagePendingSignals();
    
    // Mettre à jour les zones S/R et trendlines
    if(TimeCurrent() - g_last_sr_update >= 60) { // Mise à jour toutes les minutes
        UpdateSRZones();
    }
    
    // Mise à jour dynamique des patterns en temps réel
    UpdateDynamicPatterns();
    
    // Mise à jour des données API (tous les endpoints)
    UpdateAPIData();
    
    // Mise à jour des résultats journaliers (toujours affiché)
    UpdateDailyResults();
    
    // FORCER LA MISE À JOUR DES ZONES S/R (pour test)
    static datetime last_force_update = 0;
    if(TimeCurrent() - last_force_update >= 300) { // Toutes les 5 minutes
        Print("🔄 FORÇAGE MISE À JOUR ZONES S/R");
        UpdateSRZones();
        last_force_update = TimeCurrent();
    }
    
    
    // PRÉDICTION DE SPIKE IMMINENT
    static datetime last_prediction = 0;
    if(TimeCurrent() - last_prediction >= 10) { // Vérification toutes les 10 secondes
        double confidence = 0;
        int direction = 0;
        
        if(PredictImminentSpike(confidence, direction)) {
            Print("🔮 SPIKE IMMINENT DÉTECTÉ - Confiance: ", DoubleToString(confidence, 1), "%",
                  " Direction: ", (direction > 0 ? "BUY" : "SELL"));
            
            // Préparer l'entrée anticipée
            PrepareAnticipatedEntry(direction, confidence);
        }
        
        last_prediction = TimeCurrent();
    }
    
    // SYSTÈME ULTRA-PRÉCIS : Vérifier les spikes pour entrée
    if(InpUltraPreciseMode && DetectSpikeForEntry()) {
        // Vérifier la stabilité de la confiance avant de trader
        if(IsConfidenceStable()) {
            ExecuteUltraPreciseTrade();
        } else {
            Print("⚠️ Confiance instable - Trade bloqué");
        }
    }
    
    // === SYSTÈME DE TRADING AUTOMATIQUE PRINCIPAL ===
    // Exécuter le trading automatique (système principal)
    ExecuteAutoTrading();
    
    // Vérifier que les objets sont initialisés
    if(g_riskManager == NULL || g_signalDetector == NULL || g_tradeExecutor == NULL) {
        Print("❌ Objets non initialisés");
        return;
    }
    
    // Reset journalier
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);
    if(g_lastDay != currentTime.day) {
        g_lastDay = currentTime.day;
        g_riskManager.ResetDaily();
        Print("📅 Nouveau jour - Reset des compteurs");
    }

    // Rafraîchir / dessiner des zones S/R MTF
    if(InpDrawMTFZones) RefreshMTFZones();

    // Rafraîchir panneau IA
    static datetime lastAI = 0;
    if(InpEnableAIRecommendations && TimeCurrent() - lastAI >= MathMax(3, InpAIUpdateSeconds))
    {
        lastAI = TimeCurrent();
        RefreshAIPanel();
    }
    // Rafraîchir panneau d'analyses API simples (trend)
    static datetime lastApiPanel = 0;
    if(InpShowApiPanel && TimeCurrent() - lastApiPanel >= MathMax(3, InpApiPanelUpdateSeconds))
    {
        lastApiPanel = TimeCurrent();
        // Interroger l'endpoint /recommendations et afficher pour le symbole courant
        string headers = "Accept: application/json";
        string respHeaders = ""; char resp[]; ResetLastError();
        uchar payload[]; ArrayResize(payload,0);
        string trendUrl = InpTrendAnalysisURL + "?symbol=" + _Symbol + "&timeframe=M1";
        int code = WebRequest("GET", trendUrl, headers, 4000, payload, resp, respHeaders);
        if(code==200)
        {
            string body = CharArrayToString(resp, 0, -1, CP_UTF8);
            // Extraire la direction/force/confiance de la tendance
            int pDir = StringFind(body, "\"direction\"");
            int pStr = StringFind(body, "\"strength\"");
            int pConf= StringFind(body, "\"confidence\"");
            string sdir="NEUTRE"; int sstr=0; int sconf=0;
            if(pDir>=0){ int cd=StringFind(body,":",pDir); if(cd>=0){ string seg=StringSubstr(body,cd+1,16); if(StringFind(seg,"BUY")>=0) sdir="BUY"; else if(StringFind(seg,"SELL")>=0) sdir="SELL"; }}
            if(pStr>=0){ int cs=StringFind(body,":",pStr); if(cs>=0){ string seg=StringSubstr(body,cs+1,6); sstr=(int)StringToInteger(seg);} }
            if(pConf>=0){ int cc=StringFind(body,":",pConf); if(cc>=0){ string seg=StringSubstr(body,cc+1,6); sconf=(int)StringToInteger(seg);} }
            // Afficher aussi l'analyse de tendance via helper
            int trendDir=0, trendStr=0; bool hasTrend = GetTrendAnalysis(_Symbol, trendDir, trendStr);
                string trendInfo = hasTrend ? StringFormat(" | Trend: %d (%.0f%%)", trendDir, (double)trendStr) : "";
                
                string panel = StringFormat("API %s | entry %s | SL %s | TP %s | conf %s%s",
                                            _Symbol, se, ssl, stp, sconf, trendInfo);
                DrawLabel("API_PANEL", panel, 8, 38, clrAqua);

                // Dessiner des lignes horizontales ENTRY/SL/TP si valides
                double entryP = StringToDouble(se);
                double slP    = StringToDouble(ssl);
                double tpP    = StringToDouble(stp);
                int digits    = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
                string le = StringFormat("API_RECO_ENTRY_%s", _Symbol);
                string ls = StringFormat("API_RECO_SL_%s", _Symbol);
                string lt = StringFormat("API_RECO_TP_%s", _Symbol);
                // ENTRY
                if(entryP > 0)
                {
                    if(ObjectFind(0, le) >= 0) ObjectDelete(0, le);
                    if(ObjectCreate(0, le, OBJ_HLINE, 0, 0, NormalizeDouble(entryP, digits)))
                    {
                        ObjectSetInteger(0, le, OBJPROP_COLOR, clrAqua);
                        ObjectSetInteger(0, le, OBJPROP_STYLE, STYLE_DOT);
                        ObjectSetString(0, le, OBJPROP_TEXT, "API ENTRY");
                    }
                }
                // SL
                if(slP > 0)
                {
                    if(ObjectFind(0, ls) >= 0) ObjectDelete(0, ls);
                    if(ObjectCreate(0, ls, OBJ_HLINE, 0, 0, NormalizeDouble(slP, digits)))
                    {
                        ObjectSetInteger(0, ls, OBJPROP_COLOR, clrTomato);
                        ObjectSetInteger(0, ls, OBJPROP_STYLE, STYLE_SOLID);
                        ObjectSetString(0, ls, OBJPROP_TEXT, "API SL");
                    }
                }
                // TP
                if(tpP > 0)
                {
                    if(ObjectFind(0, lt) >= 0) ObjectDelete(0, lt);
                    if(ObjectCreate(0, lt, OBJ_HLINE, 0, 0, NormalizeDouble(tpP, digits)))
                    {
                        ObjectSetInteger(0, lt, OBJPROP_COLOR, clrLime);
                        ObjectSetInteger(0, lt, OBJPROP_STYLE, STYLE_SOLID);
                        ObjectSetString(0, lt, OBJPROP_TEXT, "API TP");
                    }
                }
            }
            else
            {
                // Fallback: essayer d'afficher la première reco globale si le symbole exact n'est pas trouvé
                int pe = StringFind(body, "\"entry\"");
                int ps = StringFind(body, "\"sl\"");
                int pt = StringFind(body, "\"tp\"");
                int pc = StringFind(body, "\"confidence\"");
                if(pe>0 && ps>0 && pt>0)
                {
                    int ce=StringFind(body,":",pe); int cs=StringFind(body,":",ps); int ct=StringFind(body,":",pt);
                    string se=StringSubstr(body,ce+1,16); string ssl=StringSubstr(body,cs+1,16); string stp=StringSubstr(body,ct+1,16);
                    string sconf=""; if(pc>0){ int cc=StringFind(body,":",pc); sconf=StringSubstr(body,cc+1,6); }
                    DrawLabel("API_PANEL", StringFormat("API (fallback) | entry %s | SL %s | TP %s | conf %s", se, ssl, stp, sconf), 8, 38, clrAqua);
                }
                else
                {
                    // Afficher un extrait brut pour diagnostic rapide
                    string preview = StringSubstr(body, 0, 120);
                    DrawLabel("API_PANEL", StringFormat("API: aucune reco pour %s", _Symbol), 8, 38, clrSilver);
                    DrawLabel("API_PANEL_RAW", StringFormat("RAW: %s", preview), 8, 52, clrSilver);
                }
            }
        }
        else
        {
            DrawLabel("API_PANEL", StringFormat("API: indisponible (HTTP %d / err %d)", code, GetLastError()), 8, 38, clrSilver);
        }
    }
    
    // Dessiner en continu les zones de spike si demandé
    static datetime lastZones = 0;
    if(InpEnableICT && InpAlwaysDrawSpikeZones)
    {
        if(TimeCurrent() - lastZones >= 5)
        {
            lastZones = TimeCurrent();
            // Purge BOS/COS/OTE objects periodically
            int total = ObjectsTotal(0, -1, -1);
            for(int oi = total-1; oi >= 0; oi--)
            {
                string on = ObjectName(0, oi);
                if(StringFind(on, "BOS_") == 0 || StringFind(on, "COS_") == 0 || StringFind(on, "OTE_") == 0)
                    ObjectDelete(0, on);
            }
        }
    }
    
    // Fermeture panier si profit total atteint
    static bool g_dailyHalted = false;
    if(InpEnableBasketClose)
    {
        static datetime lastBasketCheck = 0;
        if(TimeCurrent() - lastBasketCheck >= 1) // Check every second
        {
            double totalProfit = 0.0;
            double totalLoss = 0.0;
            int positionsCount = 0;

            for(int i = PositionsTotal()-1; i >= 0; i--)
            {
                ulong tk = PositionGetTicket(i);
                if(!PositionSelectByTicket(tk)) continue;

                // Check if position belongs to this EA
                    if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

                positionsCount++;
                double profit = PositionGetDouble(POSITION_PROFIT);
                totalProfit += profit;
                if(profit < 0) totalLoss += profit;
            }

            // Check against basket profit target
            if(totalProfit >= InpBasketProfitCloseUSD)
            {
                Print("💰 TP panier atteint (", DoubleToString(totalProfit,2), " >= ", DoubleToString(InpBasketProfitCloseUSD,2), ") -> Fermeture TOTALE de toutes les positions avec magic ", InpMagicNumber);
                // Close all positions with the magic number
                CloseAllPositions(InpMagicNumber);
                // Stop the day (disable re-entry for the day)
                g_dailyHalted = true;
            }
            // Check against basket loss limit
            else if((-totalLoss) >= InpBasketLossCloseUSD) // totalLoss is negative, so -totalLoss is positive loss
            {
                Print("🛑 Perte panier atteinte (", DoubleToString(-totalLoss,2), " >= ", DoubleToString(InpBasketLossCloseUSD,2), ") -> Fermeture TOTALE de toutes les positions avec magic ", InpMagicNumber);
                CloseAllPositions(InpMagicNumber);
                g_dailyHalted = true;
            }
            lastBasketCheck = TimeCurrent();
        }
    }
    if(g_dailyHalted) return;
    // Execute basket re-entry if armed and conditions met
    if(!InpStrictSinglePosition && g_basketReentryArmedAt > 0 && TimeCurrent() - g_basketReentryArmedAt >= 60)
    {
        int trendDir = CSignalValidator::GetTrendDirection(InpTrendTF);
        trendDir = EnforceBoomCrashDirection(trendDir);
        if(trendDir != 0 && g_riskManager.CanOpenTrade())
        {
            if(g_tradeExecutor.ExecuteTrade(trendDir))
                g_basketReentryArmedAt = 0; // Reset after successful re-entry
        }
    }

    // Scanner les graphiques ouverts et symboles additionnels pour signaux API confirmés et ouvrir si conditions ok
    if(InpEnableMultiSymbolAPI && InpUseExternalSignals)
    {
        static datetime lastScan = 0;
        if(TimeCurrent() - lastScan >= MathMax(1, InpMultiSymbolCooldownSec))
        {
            lastScan = TimeCurrent();
            int scanned = 0;
            long chart = ChartFirst();
            while(chart != -1 && scanned < InpMaxChartsScan)
            {
                string sym = ChartSymbol(chart);
            if(StringLen(sym) > 0 && !IsSymbolInCooldown(sym))
                {
                    // Éviter doublons/positions existantes sur ce symbole (même magic)
                    bool hasPos=false;
                    for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(!PositionSelectByTicket(tk)) continue; if(PositionGetString(POSITION_SYMBOL)==sym && (int)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber){ hasPos=true; break; } }
                    if(!hasPos && g_riskManager!=NULL && g_riskManager.CanOpenTrade())
                    {
                        int dir=0, conf=0; bool ok = GetExternalSignal(sym, dir, conf);
                        if(ok && conf >= InpExtSigMinConfidence && dir!=0)
                        {
                            // Confirmation minimale: respecter Boom/Crash si activé
                            if(IsBoomCrashIndex(sym)) dir = EnforceBoomCrashDirection(dir);
                            if(dir!=0)
                            {
                                bool traded = g_tradeExecutor.ExecuteTradeOnSymbol(sym, dir);
                                if(traded) { scanned++; }
                            }
                        }
                    }
                }
                chart = ChartNext(chart);
            }

            // Parcourir les symboles additionnels configurés
            if(InpEnableAdditionalSymbols && scanned < InpMaxChartsScan)
            {
                string list = InpAdditionalSymbols;
                int start = 0;
                while(scanned < InpMaxChartsScan && start < StringLen(list))
                {
                    int comma = StringFind(list, ",", start);
                    string symb;
                    if(comma < 0) { symb = StringSubstr(list, start); start = StringLen(list); }
                    else { symb = StringSubstr(list, start, comma - start); start = comma + 1; }
                    // Trim spaces
                    while(StringLen(symb)>0 && StringGetCharacter(symb,0)==' ') symb = StringSubstr(symb,1);
                    while(StringLen(symb)>0 && StringGetCharacter(symb, StringLen(symb)-1)==' ') symb = StringSubstr(symb,0,StringLen(symb)-1);
                    if(StringLen(symb)==0) continue;
                    if(IsSymbolInCooldown(symb)) continue;
                    // Sauter si position déjà ouverte sur ce symbole
                    bool hasPos2=false;
                    for(int i2=PositionsTotal()-1;i2>=0;i2--){ ulong tk2=PositionGetTicket(i2); if(!PositionSelectByTicket(tk2)) continue; if(PositionGetString(POSITION_SYMBOL)==symb && (int)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber){ hasPos2=true; break; } }
                    if(hasPos2) continue;
                    if(g_riskManager!=NULL && g_riskManager.CanOpenTrade())
                    {
                        int d2=0,c2=0; bool ok2 = GetExternalSignal(symb, d2, c2);
                        if(ok2 && c2 >= InpExtSigMinConfidence && d2!=0)
                        {
                            if(IsBoomCrashIndex(symb)) d2 = EnforceBoomCrashDirection(d2);
                            if(d2!=0)
                            {
                                bool traded2 = g_tradeExecutor.ExecuteTradeOnSymbol(symb, d2);
                                if(traded2) { scanned++; }
                            }
                        }
                    }
                }
            }

        // API calls are now handled by UpdateAPIData() function for all endpoints
        }
    }

    // Re-entry Boom/Crash after X small candles (if enabled)
    if(!InpStrictSinglePosition && InpEnableSpikeReentry && IsBoomCrashIndex(_Symbol))
    {
        static datetime lastEntryTime = 0; // Track last entry time on this symbol
        // Check if we can attempt re-entry based on cooldown and no open positions for this symbol
        bool positionOpenForSymbol = false;
        for(int i = PositionsTotal()-1; i >= 0; i--) {
            ulong t = PositionGetTicket(i);
            if(!PositionSelectByTicket(t)) continue;
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && (int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                positionOpenForSymbol = true;
                break;
            }
        }
        
        // If no position is open for this symbol and we are within the cooldown after a loss
        if(!positionOpenForSymbol)
        {
            // Vérifier que le cooldown après perte est respecté
            if(IsSymbolInCooldown(_Symbol)) {
                Print("⏳ SYMBOLE EN COOLDOWN après perte - Attente d'une opportunité confirmée sur ", _Symbol);
                return;
            }
            
            // Check for the small candle pattern and execute if conditions met
            MqlRates r[10];
            if(CopyRates(_Symbol, PERIOD_M1, 0, 10, r) >= 6)
            {
                double avgCandleRange = 0;
                for(int i = 1; i <= 5; i++) avgCandleRange += (r[i].high - r[i].low);
                avgCandleRange /= 5.0;

                int smallCandleCount = 0;
                for(int i = 1; i <= 5; i++) {
                    if((r[i].high - r[i].low) < avgCandleRange * InpSmallCandlePct) {
                        smallCandleCount++;
                    }
                }

                // If pattern detected and risk manager allows
                if(smallCandleCount >= InpReentryMinBars && smallCandleCount <= InpReentryMaxBars)
                {
                    int signal = EnforceBoomCrashDirection(CSignalValidator::GetTrendDirection(InpTrendTF));
                    if(signal != 0 && g_riskManager.CanOpenTrade())
                    {
                        if(g_tradeExecutor.ExecuteTrade(signal))
                        {
                            // Reset re-entry logic for this symbol after successful trade
                            lastEntryTime = TimeCurrent(); // update last entry time
                        }
                    }
                }
            }
        }
    }

    // Close positions per symbol if per-trade thresholds reached, then cooldown before re-entry
    // Always enforce user-specified symbol rules (Boom/Crash vs others)
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;

            if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

            string psym = PositionGetString(POSITION_SYMBOL);
            double p = PositionGetDouble(POSITION_PROFIT);
        int ptype = (int)PositionGetInteger(POSITION_TYPE);
        double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);

        // Determine if conservative mode is active
        bool useConservative = false;
        if(InpEnableConservativeRangeMode)
        {
            int d1 = CSignalValidator::GetTrendDirection(InpRangeModeTF1);
            int d2 = CSignalValidator::GetTrendDirection(InpRangeModeTF2);
            // Conservative mode is active if trends are non-aligned or neutral
            if(d1==0 || d2==0 || d1!=d2) useConservative = true;
        }

        // Define loss and profit targets based on symbol rules
        bool isBCsym = IsBoomCrashIndex(psym);
        double lossThresh = InpMaxLossUSDPerTrade; // universel: quitter à -$ fixé
        double profitThresh = isBCsym ? 1e9 : 5.0; // Boom/Crash: close on spike instead of fixed profit

        // Check if trade should be closed for loss or profit
        bool closeForLoss = (p <= -lossThresh);
        bool closeForProfit = (p >= profitThresh);

        // For Boom/Crash: close immediately after spike appearance relative to entry and direction
        if(isBCsym)
        {
            int dir = (ptype==POSITION_TYPE_BUY)? 1 : -1;
            if(VerifySpikeArrival(dir, entry_price))
            {
                closeForProfit = true; // treat spike detection as exit signal
            }
        }

            if(closeForLoss || closeForProfit)
            {
            // Close this specific position
                double vol = PositionGetDouble(POSITION_VOLUME);
                MqlTradeRequest rq; MqlTradeResult rs; // ZeroMemory(rq); // ZeroMemory(rs);
                rq.action = TRADE_ACTION_DEAL; rq.position = tk; rq.symbol = psym; rq.volume = vol;
                rq.type = (ptype==POSITION_TYPE_BUY)? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                rq.magic = InpMagicNumber; rq.comment = "PerTradeAutoClose";

                if(OrderSend(rq, rs))
                {
            if(closeForLoss)
                {
                    Print("🛑 Perte par trade atteinte (", DoubleToString(-p,2), ") sur ", psym, " -> fermeture et cooldown.");
                    // Arm re-entry cooldown if a loss occurred
                    SetSymbolCooldown(psym, InpReentryCooldownMin * 60); // Cooldown for this symbol
                // Count consecutive loss for symbol and potentially trigger cooldown after consecutive losses
                IncrementConsecutiveLoss(psym);
                int lidx = FindLossIndex(psym);
                if(lidx>=0 && g_lossCounts[lidx] >= InpMaxConsecutiveLosses)
                {
                    Print("🚫 ", InpMaxConsecutiveLosses, " PERTES CONSÉCUTIVES sur ", psym, " → COOLDOWN ", InpConsecutiveLossCooldownMin, " minutes");
                    Print("⏸️ SYMBOLE ", psym, " TEMPORAIREMENT DÉSACTIVÉ - Retour dans ", InpConsecutiveLossCooldownMin, " minutes");
                    SetSymbolCooldown(psym, InpConsecutiveLossCooldownMin * 60);
                    
                    // Reset le compteur après avoir activé le cooldown
                    g_lossCounts[lidx] = 0;
                }
                else if(lidx>=0) {
                    Print("⚠️ PERTE #", g_lossCounts[lidx], " sur ", psym, " - ", (InpMaxConsecutiveLosses - g_lossCounts[lidx]), " perte(s) avant cooldown");
                }
                }
                else // closeForProfit
                {
                    Print("✅ Gain par trade atteint (", DoubleToString(p,2), ") sur ", psym, " -> sécurisation.");
                    // If Boom/Crash and re-entry enabled, arm it after a quick TP
                    if(IsBoomCrashIndex(psym) && InpEnableSpikeReentry)
                        g_bcReentryArmedTime = TimeCurrent(); // Arm the general re-entry timer
                // Reset consecutive loss counters on profit
                ResetConsecutiveLoss(psym);
                }
            }
            else
            {
                Print("❌ Échec fermeture per-trade (", psym, "): ", GetLastError(), " - ", rs.comment);
            }
        }
    }

    // Global cooldown check: if any trade was closed due to loss, enforce global cooldown
    // A simple way to implement this is to check if any position was closed for loss in the last loop
    // and then prevent further trades. For simplicity, we rely on individual symbol cooldowns and the general risk manager cooldown.
    // If you need a global cooldown *after* any loss, you'd need a separate timer.

    // Mettre à jour les compteurs de pertes/gains consécutifs
    UpdateConsecutiveCounters();
    
    // Vérifier si on est en cooldown
    if(IsInCooldown()) {
        Print("⏳ COOLDOWN ACTIF - Attente de ", (g_cooldownEndTime - TimeCurrent()) / 60, " minutes");
        return;
    }
    
    // Vérifier si le capital engagé dépasse la limite journalière
    if(IsCapitalEngagedLimitReached()) {
        return;
    }
    
    // Vérifier les signaux de spike imminent avec confiance 100%
    CheckAndExecuteSpikeSignals();
    
    // Vérifier si on peut trader (basé sur les règles du Risk Manager)
    if(!g_riskManager.CanOpenTrade()) return;
    
    // VÉRIFICATION ABSOLUE: Maximum 2 trades simultanés - JAMAIS PLUS
    int currentPositions = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong tk = PositionGetTicket(i);
        if(!PositionSelectByTicket(tk)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            currentPositions++;
        }
    }
    
    // BLOQUER IMMÉDIATEMENT si 2 positions ou plus
    if(currentPositions >= 2) {
        Print("🚫 BLOCAGE ABSOLU - ", currentPositions, " positions ouvertes (MAXIMUM: 2)");
        Print("⏸️ AUCUNE NOUVELLE POSITION AUTORISÉE - Attendre fermeture d'une position existante");
        Print("📊 DÉTAIL POSITIONS:");
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(PositionSelectByTicket(tk)) {
                if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                    string sym = PositionGetString(POSITION_SYMBOL);
                    double profit = PositionGetDouble(POSITION_PROFIT);
                    Print("   - ", sym, " (Ticket: ", tk, ") - Profit: $", DoubleToString(profit, 2));
                }
            }
        }
        Print("🛑 ARRÊT COMPLET DU TRADING - Limite de 2 positions dépassée");
        return;
    }
    
    // VÉRIFICATION SUPPLÉMENTAIRE: Si on a déjà 1 position, être très prudent
    if(currentPositions == 1) {
        Print("⚠️ ATTENTION - 1 position déjà ouverte, maximum 1 de plus autorisé");
    }

    // Per-symbol aggregate open-loss guard: if total open loss per symbol <= -$2 (or InpMaxLossUSDPerTrade),
    // close all positions for that symbol and arm a cooldown to prevent immediate re-entry.
    // This enforces "ne depasse pas deux dollar de perte par symbole" across concurrent positions.
    {
        string symbols[128];
        double lossBySymbol[128];
        int symCount = 0;
        for(int i=PositionsTotal()-1;i>=0;i--)
        {
            ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
            string s = PositionGetString(POSITION_SYMBOL);
            double pnl = PositionGetDouble(POSITION_PROFIT);
            int idx=-1; for(int k=0;k<symCount;k++){ if(symbols[k]==s){ idx=k; break; } }
            if(idx<0 && symCount<128){ idx=symCount; symbols[symCount]=s; lossBySymbol[symCount]=0.0; symCount++; }
            if(idx>=0) lossBySymbol[idx] += pnl;
        }
        double perSymbolCap = MathMax(0.01, InpMaxLossUSDPerTrade); // default 2.0
        for(int k=0;k<symCount;k++)
        {
            if(lossBySymbol[k] <= -perSymbolCap)
            {
                Print("🛑 Perte agrégée par symbole atteinte (", symbols[k], ") = ", DoubleToString(lossBySymbol[k],2), " ≤ -$", DoubleToString(perSymbolCap,2), " → fermeture de sécurité");
                ClosePositionsForSymbol(symbols[k], InpMagicNumber);
                // Arm per-symbol cooldown to avoid immediate re-entry
                SetSymbolCooldown(symbols[k], InpReentryCooldownMin * 60);
            }
        }
    }

    // Global open-loss guard: if total open loss <= -InpMaxGlobalOpenLossUSD, close all our positions and arm global cooldown
    if(InpMaxGlobalOpenLossUSD > 0.0)
    {
        double totalOpenPnl = 0.0;
        for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue; if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue; totalOpenPnl += PositionGetDouble(POSITION_PROFIT); }
        if(totalOpenPnl <= -MathAbs(InpMaxGlobalOpenLossUSD))
        {
            Print("🛑 Seuil global de perte atteint (", DoubleToString(totalOpenPnl,2), ") → fermeture de sécurité");
            for(int i=PositionsTotal()-1;i>=0;i--){ 
                ulong t=PositionGetTicket(i); 
                if(!PositionSelectByTicket(t)) continue; 
                if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue; 
                double vol=PositionGetDouble(POSITION_VOLUME); 
                MqlTradeRequest rq; MqlTradeResult rs; 
                rq.action=TRADE_ACTION_DEAL; 
                rq.position=t; 
                rq.symbol=PositionGetString(POSITION_SYMBOL); 
                rq.volume=vol; 
                rq.type=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)? ORDER_TYPE_SELL: ORDER_TYPE_BUY; 
                rq.magic=InpMagicNumber; 
                rq.comment="GlobalStop"; 
                if(!OrderSend(rq, rs)) {
                    Print("❌ Échec fermeture globale: ", GetLastError());
                }
            }
            g_globalCooldownUntil = TimeCurrent() + InpGlobalCooldownMin*60;
            return;
        }
    }
    
    // Détecter les signaux
    int signal = g_signalDetector.DetectSignal();
    
    // VÉRIFICATION STRICTE DE TENDANCE: Ne jamais trader contre la tendance M5 et M1
    if(signal != 0) {
        int trendM5 = CSignalValidator::GetTrendDirection(PERIOD_M5);
        int trendM1 = CSignalValidator::GetTrendDirection(PERIOD_M1);
        
        // Bloquer si tendance M5 incertaine ou opposée
        if(trendM5 == 0) {
            Print("🚫 SIGNAL BLOQUÉ - Tendance M5 incertaine");
            signal = 0;
        } else if(signal * trendM5 < 0) {
            Print("🚫 SIGNAL BLOQUÉ - Contre tendance M5 (Signal: ", signal, " vs Tendance: ", trendM5, ")");
            signal = 0;
        }
        
        // Bloquer si tendance M1 incertaine ou opposée
        if(signal != 0 && trendM1 == 0) {
            Print("🚫 SIGNAL BLOQUÉ - Tendance M1 incertaine");
            signal = 0;
        } else if(signal != 0 && signal * trendM1 < 0) {
            Print("🚫 SIGNAL BLOQUÉ - Contre tendance M1 (Signal: ", signal, " vs Tendance: ", trendM1, ")");
            signal = 0;
        }
        
        // Vérifier l'alignement M5 et M1
        if(signal != 0 && trendM5 != trendM1) {
            Print("🚫 SIGNAL BLOQUÉ - Tendance M5 et M1 non alignées (M5: ", trendM5, " vs M1: ", trendM1, ")");
            signal = 0;
        }
        
        // Confirmation finale: signal doit être dans le sens des deux tendances
        if(signal != 0) {
            Print("✅ SIGNAL VALIDÉ - Aligné avec tendance M5 (", trendM5, ") et M1 (", trendM1, ")");
        }
    }
    
    // Filtre de tendance supplémentaire si activé
    if(InpUseTrendOnly && signal != 0)
    {
        int trend = CTradeExecutor::GetTrendDirection(InpTrendTF);
        if(trend==0) signal = 0; // pas de trade si tendance incertaine
        else if(signal*trend < 0) signal = 0; // bloquer contre-tendance
    }
    
    // Calculer la confiance du signal
    double signal_confidence = g_signalDetector.GetSignalConfidence();
    
    // Vérifier le seuil de confiance minimum
    if(signal != 0 && !IsSignalConfidenceValid(signal_confidence)) {
        Print("❌ Signal rejeté: Confiance insuffisante (", DoubleToString(signal_confidence, 1), "% < ", DoubleToString(InpMinConfidenceThreshold, 1), "%)");
        signal = 0; // Annuler le signal
    }
    // SpikeOnly: exiger un pré-signal spike et confiance ≥ 90%
    if(InpSpikeOnlyMode)
    {
        if(!(g_isEarlySignal && signal_confidence >= MathMax(90.0, InpMinConfidenceThreshold)))
        {
            // Dessiner une pré-flèche pour visualiser le near-miss si besoin
            if(signal!=0) DrawPreSignalArrow(signal);
            signal = 0;
        }
    }
    
    if(signal != 0) {
        Print("✅ Signal détecté: Direction ", (signal > 0 ? "BUY" : "SELL"), " | Confiance: ", DoubleToString(signal_confidence, 1), "%");
    }

    // 0) Analyse de tendance API: validation préalable
    int apiTrend=0, apiStrength=0; bool hasTrend = GetTrendAnalysis(_Symbol, apiTrend, apiStrength);
    if(hasTrend && InpExtSigAsHardFilter)
    {
        // Si l'API indique une tendance forte, l'utiliser comme filtre
        if(apiStrength >= 80 && signal != 0 && signal != apiTrend)
        {
            Print("❌ Signal rejeté: Contre-tendance API (API:", apiTrend, " vs Local:", signal, ")");
            signal = 0;
        }
    }

    // 1) Signaux externes API: possibilité d'anticiper ou filtrer
    if(InpUseExternalSignals)
    {
        int exDir=0, exConf=0; bool hasExt = GetExternalSignal(_Symbol, exDir, exConf);
        if(hasExt && exConf >= InpExtSigMinConfidence)
        {
            if(signal==0) signal = exDir; // anticipation si local vide
            else if(InpExtSigAsHardFilter && ((exDir>0 && signal<0) || (exDir<0 && signal>0))) signal = 0; // exiger accord
        }
        else if(InpExtSigAsHardFilter)
        {
            signal = 0; // hard filter actif sans accord
        }
    }

    // Option IA: anticipation / filtre / ordres LIMIT avec prix absolus
    if(InpUseAIForAnticipation)
    {
        int aiDir=0, aiConf=0; bool hasAI = GetAIDecision(_Symbol, aiDir, aiConf);
        if(hasAI && aiConf >= InpAIMinTradeConfidence)
        {
            // 1) Anticiper si aucun signal local
            if(signal==0)
                signal = aiDir;
            // 2) Filtrer si demandé: exiger accord IA
            else if(InpAIAsHardFilter && (aiDir==0 || (aiDir>0 && signal<0) || (aiDir<0 && signal>0)))
                signal = 0;
            
            // 3) Tentative de placement d'un ordre LIMIT basé sur prix absolus si fournis par l'IA
            if(InpAIEnablePendingOrders)
            {
                // Re-demander la string brute via RefreshAIPanel? Non, on parse dans GetAIDecision. Simplification: re-appeler GetAIDecision et reparser le dernier body n'est pas stocké.
                // Ici on s'en remet à la logique: si la reco contient ENTRY/SL/TP, la fonction dédiée d'exécution sera appelée via une API spécifique.
                // Pour garder le flux simple, on n'essaie pas si signal local déjà pris par marché ouvert. Les LIMIT sont utiles quand pas d'entrée immédiate.
            }
        }
        else if(InpAIAsHardFilter)
        {
            // Si hard filter et pas d'accord IA, bloquer
            signal = 0;
        }
    }
    // Notification pré-signal (désactivée par défaut)
    if(InpNotifyRawSignals && InpSendNotifications && signal!=0)
    {
        string side0 = (signal>0?"BUY":"SELL");
        NotifyOnce(StringFormat("📡 Pré-signal détecté: %s %s", _Symbol, side0));
    }
    // Enforcer la règle Boom/Crash: BUY uniquement sur Boom*, SELL uniquement sur Crash*
    signal = EnforceBoomCrashDirection(signal);
    if(signal == 0) return;

    // GOD Mode gate: require a high composite score before continuing
    if(InpEnableGodMode)
    {
        int gscore = CSignalValidator::ComputeGodScore(signal);
        if(gscore < MathMax(50, InpGodMinScore))
        {
            // Optionally draw a pre-signal arrow to visualize near-miss
            DrawPreSignalArrow(signal);
            return;
        }
    }
    
    // Si la validation est activée, ajouter le signal en attente au lieu d'exécuter directement
    if(InpValidateTradeWin || InpVerifySpikeBeforeSignal || InpSpikeOnlyMode) {
        double entry_price = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        // Annonce pré-spike (flèche unique) si ICT actif et score suffisant
        if(InpEnableICT && InpICTAnnouncePreSpike && signal_confidence >= MathMax(90.0, InpMinConfidenceThreshold)) {
            DrawPreSignalArrow(signal); // flèche unique (contrôle ON/OFF par input)
            DrawSpikeZoneIfAny(); // dessine la zone de spike candidate
            if(InpSendNotifications && InpNotifyRawSignals) {
                string sideAnn = (signal>0?"BUY":"SELL");
                NotifyOnce(StringFormat("📣 Pré-spike attendu dans ~1 min: %s %s", _Symbol, sideAnn));
            }
        }
        // Suppressed ICT drawings (BOS/COS/OTE)
        AddPendingSignal(signal, signal_confidence, entry_price);
        return;
    }

    // Bloquer contre-tendance M1+M5 et règles Boom/Crash demandées
    if(InpEnforceM1Trend && !CSignalValidator::IsAlignedWithM1M5(signal))
    {
        Print("❌ Signal rejeté: Contre-tendance M1/M5 détectée.");
        return;
    }
    
    // Valider le signal
    if(!g_isEarlySignal)
    {
    if(!CSignalValidator::ValidateSignal(signal)) {
            Print("❌ Signal rejeté par validation (Confiance=", CSignalValidator::ComputeGodScore(signal), ")");
        return;
        }
    }

    // Optionnel: exiger une entrée dans la zone de retracement Fibonacci 38.2-61.8
    if(InpRequireFibEntry)
    {
        if(!IsPriceInFibEntryZone(InpFibEntryTF, signal))
        {
            // Dessine une flèche pré-signal pour visualiser le refus
            DrawPreSignalArrow(signal);
            return;
        }
    }

    // Mode strict: garantir une seule position globale; si early signal, tenter une seule entrée puis reset le flag
    if(InpStrictSinglePosition)
    {
        // If any position with our magic exists, do nothing
        for(int i=0;i<PositionsTotal();i++){ ulong tk=PositionGetTicket(i); if(!PositionSelectByTicket(tk)) continue; if((int)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber) { g_isEarlySignal=false; return; } }
    }

    // If early signal or regular signal, try a single trade (risk manager still checks strict constraints)
    if(g_tradeExecutor.ExecuteTrade(signal)) {
        g_riskManager.RecordTrade(0);
// Dessin du marqueur de trade exécuté
        DrawSignalArrow(signal);
        // Afficher dashboard si actif
        if(InpShowDashboard) UpdateDashboard();
        if(InpSendNotifications)
        {
            string side = (signal>0?"BUY":"SELL");
            NotifyOnce(StringFormat("✅ Trade %s exécuté sur %s", side, _Symbol));
        }
    }
    else if(InpAIEnablePendingOrders && g_aiLastDir!=0 && g_aiLastEntry>0.0)
    {
        // If market entry failed or not executed, but AI provided absolute prices, place pending order
        double slp = g_aiLastSL; double tpp = g_aiLastTP;
        // Minimal sanity: ensure SL/TP on correct side if provided
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        // Enforce $2 max loss by adjusting SL distance if needed (per current lot calculation)
        double lot = g_tradeExecutor==NULL? InpLotSize : 0.0;
        if(lot<=0.0) lot = InpLotSize; // fallback
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        double dollarPerPointPerLot = (tickSize>0.0 && pt>0.0)? (tickValue * (pt / tickSize)) : 0.0;
        if(dollarPerPointPerLot>0.0 && lot>0.0)
        {
            double maxPts = MathFloor(MathAbs(2.0) / (dollarPerPointPerLot * lot));
            if(maxPts>0)
            {
                if(g_aiLastDir>0)
                {
                    if(slp>0.0)
                    {
                        double currentPts = (g_aiLastEntry - slp) / MathMax(pt,1e-12);
                        if(currentPts > maxPts) slp = NormalizeDouble(g_aiLastEntry - maxPts*pt, digits);
                    }
                }
                else
                {
                    if(slp>0.0)
                    {
                        double currentPts = (slp - g_aiLastEntry) / MathMax(pt,1e-12);
                        if(currentPts > maxPts) slp = NormalizeDouble(g_aiLastEntry + maxPts*pt, digits);
                    }
                }
            }
        }
        if(g_aiLastDir>0)
        {
            if(slp>0 && slp>=g_aiLastEntry) slp = NormalizeDouble(g_aiLastEntry - 5*pt, digits);
            if(tpp<=0.0)
            {
                // If TP missing, set TP = entry + 1.5x (entry - SL)
                if(slp>0.0) tpp = NormalizeDouble(g_aiLastEntry + 1.5*(g_aiLastEntry - slp), digits);
            }
            if(tpp>0 && tpp<=g_aiLastEntry) tpp = NormalizeDouble(g_aiLastEntry + 5*pt, digits);
        }
        else
        {
            if(slp>0 && slp<=g_aiLastEntry) slp = NormalizeDouble(g_aiLastEntry + 5*pt, digits);
            if(tpp<=0.0)
            {
                if(slp>0.0) tpp = NormalizeDouble(g_aiLastEntry - 1.5*(slp - g_aiLastEntry), digits);
            }
            if(tpp>0 && tpp>=g_aiLastEntry) tpp = NormalizeDouble(g_aiLastEntry - 5*pt, digits);
        }
        bool placed = g_tradeExecutor.ExecutePendingFromAI(g_aiLastDir, g_aiLastEntry, slp, tpp);
        if(placed && InpSendNotifications)
        {
            string s2 = (g_aiLastDir>0?"BUY_LIMIT":"SELL_LIMIT");
            string explain = (StringLen(g_aiLastNote)>0)? (" | IA: "+g_aiLastNote) : "";
            NotifyOnce(StringFormat("🕒 Ordre %s placé @ %s (SL=%s, TP=%s)%s", s2, DoubleToString(g_aiLastEntry,digits), (slp>0?DoubleToString(slp,digits):"0"), (tpp>0?DoubleToString(tpp,digits):"0"), explain));
        }
    }
    g_isEarlySignal = false;
}

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+

void DrawLabel(const string name, const string text, const int x, const int y, const color col)
{
    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
    if(ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_COLOR, col);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
    }
}

void RefreshAIPanel()
{
    // Construire un petit contexte compact
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double pt  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int spreadPts = (int)MathRound((ask-bid)/MathMax(pt,1e-12));

    // Construire JSON minimal (MQL5 n'a pas de JSON natif, on envoie un texte simplifié)
    string payload = StringFormat("{\"symbol\":\"%s\",\"timeframe\":\"M1\",\"context\":{\"bid\":%s,\"ask\":%s,\"spread\":%d}}",
                                  _Symbol, DoubleToString(bid,_Digits), DoubleToString(ask,_Digits), spreadPts);

    uchar post[]; int n = StringToCharArray(payload, post, 0, StringLen(payload), CP_UTF8);
    if(n>0) ArrayResize(post, n); // ensure exact payload size
    string headers = "Content-Type: application/json\r\nAccept: application/json";
    string respHeaders = ""; char resp[]; ResetLastError();
    int code = WebRequest("POST", InpAIProxyURL, headers, 7000, post, resp, respHeaders);
    if(code==200)
    {
        string body = CharArrayToString(resp, 0, -1, CP_UTF8);
        string txt = StringSubstr(body, 0, 200);
        DrawLabel("AI_PANEL", StringFormat("AI: %s", txt), 8, 22, clrGold);
    }
    else
    {
        DrawLabel("AI_PANEL", StringFormat("AI: indisponible (HTTP %d / err %d)", (int)code, GetLastError()), 8, 22, clrSilver);
    }
}

// Récupère l'analyse de tendance depuis l'API (/trend)
// JSON attendu: { "trend": 1, "strength": 85, "timeframe": "M1", "symbol": "Boom 1000 Index" }
bool GetTrendAnalysis(const string symbol, int &outTrend, int &outStrength)
{
    outTrend = 0; outStrength = 0;
    if(!InpUseExternalSignals) return false;
    
    string headers = "Accept: application/json";
    string respHeaders = ""; char resp[]; ResetLastError();
    uchar emptyPayload[]; ArrayResize(emptyPayload, 0);
    int code = WebRequest("GET", InpTrendAnalysisURL, headers, 5000, emptyPayload, resp, respHeaders);
    if(code!=200) return false;

    string body = CharArrayToString(resp, 0, -1, CP_UTF8);
    // Recherche de l'entrée correspondant au symbole (insensible à la casse)
    string needle = StringFormat("\"symbol\":\"%s\"", symbol);
    int p = StringFind(body, needle);
    if(p < 0)
    {
        string bodyU = body; string symU = symbol;
        for(int iuc=0;iuc<StringLen(bodyU);iuc++){ ushort ch=(ushort)StringGetCharacter(bodyU,iuc); if(ch>='a'&&ch<='z') StringSetCharacter(bodyU,iuc,(ushort)(ch-'a'+'A')); }
        for(int juc=0;juc<StringLen(symU);juc++){ ushort ch2=(ushort)StringGetCharacter(symU,juc); if(ch2>='a'&&ch2<='z') StringSetCharacter(symU,juc,(ushort)(ch2-'a'+'A')); }
        string needleU = StringFormat("\"SYMBOL\":\"%s\"", symU);
        p = StringFind(bodyU, needleU);
    }
    if(p<0) return false;

    // Parse trend et strength
    int pTrend = StringFind(body, "\"trend\"", p);
    int pStrength = StringFind(body, "\"strength\"", p);
    if(pTrend>=0 && pStrength>=0)
    {
        int c1 = StringFind(body, ":", pTrend);
        int c2 = StringFind(body, ":", pStrength);
        if(c1>=0 && c2>=0)
        {
            string sTrend = StringSubstr(body, c1+1, 6);
            string sStrength = StringSubstr(body, c2+1, 6);
            outTrend = (int)StringToInteger(sTrend);
            outStrength = (int)StringToInteger(sStrength);
            return (outTrend != 0);
        }
    }
    return false;
}

// Récupère un signal externe pour le symbole courant depuis l'API (/signals)
// JSON attendu (extrait pertinent):
//   { "signals": [ {"symbol":"Boom 1000 Index","direction":1,"confidence":85,"ts":1699999999}, ... ] }
bool GetExternalSignal(const string symbol, int &outDir, int &outConf)
{
    outDir = 0; outConf = 0;
    if(!InpUseExternalSignals) return false;
    // Cache (uniquement pour le symbole courant)
    if(symbol == _Symbol && TimeCurrent() - g_extLastUpdate <= MathMax(1, InpExtSigTTLSeconds) && g_extLastDir!=0)
    {
        outDir = g_extLastDir; outConf = g_extLastConf; return true;
    }

    string headers = "Accept: application/json";
    string respHeaders = ""; char resp[]; ResetLastError();
    // MQL5 requires an array for the payload even for GET. Use empty payload.
    uchar emptyPayload[]; ArrayResize(emptyPayload, 0);
    int code = (int)WebRequest("GET", InpExternalSignalsURL, headers, 5000, emptyPayload, resp, respHeaders);
    if(code!=200) return false;

            string body = CharArrayToString(resp, 0, -1, CP_UTF8);
            // Recherche de l'entrée correspondant au symbole (relâchée: insensible à la casse)
            string needle = StringFormat("\"symbol\":\"%s\"", symbol);
            int p = StringFind(body, needle);
            if(p < 0)
            {
                // Insensible à la casse
                string bodyU = body; string symU = symbol;
                for(int iuc=0;iuc<StringLen(bodyU);iuc++){ ushort ch=(ushort)StringGetCharacter(bodyU,iuc); if(ch>='a'&&ch<='z') StringSetCharacter(bodyU,iuc,(ushort)(ch-'a'+'A')); }
                for(int juc=0;juc<StringLen(symU);juc++){ ushort ch2=(ushort)StringGetCharacter(symU,juc); if(ch2>='a'&&ch2<='z') StringSetCharacter(symU,juc,(ushort)(ch2-'a'+'A')); }
                string needleU = StringFormat("\"SYMBOL\":\"%s\"", symU);
                p = StringFind(bodyU, needleU);
            }
    if(p<0) return false;

    // direction
    int pDirKey = StringFind(body, "\"direction\"", p);
    int pConfKey= StringFind(body, "\"confidence\"", p);
    if(pDirKey<0 || pConfKey<0) return false;
    int c1 = StringFind(body, ":", pDirKey);
    int c2 = StringFind(body, ":", pConfKey);
    if(c1<0 || c2<0) return false;
    string sDir = StringSubstr(body, c1+1, 6);
    string sConf= StringSubstr(body, c2+1, 6);
    int dir = (int)StringToInteger(sDir);
    int conf= (int)StringToInteger(sConf);
    if(dir==0) return false;

    g_extLastDir = dir; g_extLastConf = MathMax(0, MathMin(100, conf)); g_extLastUpdate = TimeCurrent();
    outDir = g_extLastDir; outConf = g_extLastConf; return true;
}

// Récupère une décision IA (direction, confiance). Utilise le cache pour limiter les requêtes.
bool GetAIDecision(const string symbol, int &outDir, int &outConf)
{
    outDir = 0; outConf = 0;
    if(!InpUseAIForAnticipation) return false;
    // Si cache valide (et <= TTL paramétré), renvoyer
    int ttlSecs = MathMax(60, InpAIDecisionTTLMin*60);
    if(TimeCurrent() - g_aiLastUpdate <= ttlSecs && g_aiLastDir!=0)
    {
        outDir = g_aiLastDir; outConf = g_aiLastConf; return true;
    }

    // Construire contexte minimal
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double pt  = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int spreadPts = (int)MathRound((ask-bid)/MathMax(pt,1e-12));

    string payload = StringFormat("{\"symbol\":\"%s\",\"timeframe\":\"M1\",\"context\":{\"bid\":%s,\"ask\":%s,\"spread\":%d}}",
                                  symbol, DoubleToString(bid,_Digits), DoubleToString(ask,_Digits), spreadPts);
    uchar post[]; int n = StringToCharArray(payload, post, 0, StringLen(payload), CP_UTF8); if(n>0) ArrayResize(post,n);
    string headers = "Content-Type: application/json\r\nAccept: application/json";
    string respHeaders = ""; char resp[]; ResetLastError();
    int code = WebRequest("POST", InpAIProxyURL, headers, 7000, post, resp, respHeaders);
    if(code!=200)
    {
        return false;
    }

    string body = CharArrayToString(resp, 0, -1, CP_UTF8);
    // Parsing flexible: 1) direction/conf numériques, 2) recommendation BUY/SELL/WAIT; with optional absolute prices: ENTRY=, SL=, TP=
    int dir = 0, conf = 0;
    int pDir = StringFind(body, "\"direction\"");
    int pConf= StringFind(body, "\"confidence\"");
    if(pDir>=0)
    {
        int c = StringFind(body, ":", pDir); if(c>=0){ string s = StringSubstr(body, c+1, 6); dir = (int)StringToInteger(s); }
    }
    if(pConf>=0)
    {
        int c = StringFind(body, ":", pConf); if(c>=0){ string s = StringSubstr(body, c+1, 6); conf = (int)StringToInteger(s); }
    }
    // Alternative schema: {"recommendation":"BUY|SELL|WAIT ...","confidence":<num|null>}
    double outEntry=0.0, outSLp=0.0, outTPp=0.0; // optional absolute prices from IA
    if(dir==0)
    {
        int pRec = StringFind(body, "\"recommendation\"");
        if(pRec>=0)
        {
            int c = StringFind(body, ":", pRec);
            if(c>=0)
            {
                // Extract a short slice and uppercase for matching
                string rec = StringSubstr(body, c+1, 128);
                // Convert to uppercase manually since StringToUpper doesn't exist in MQL5
                for(int i = 0; i < StringLen(rec); i++) {
                    ushort ch = StringGetCharacter(rec, i);
                    if(ch >= 'a' && ch <= 'z') {
                        ch = ch - 'a' + 'A';
                        StringSetCharacter(rec, i, ch);
                    }
                }
                // If API mentions 429/quota, treat as neutral (no signal)
                if(StringFind(rec, "429")>=0) { return false; }
                if(StringFind(rec, "BUY")>=0) dir = 1; else if(StringFind(rec, "SELL")>=0) dir = -1; else dir = 0;
                // Try to parse ENTRY, SL, TP as absolute prices in the same slice
                // Expected like: ENTRY=1234.56; SL=1220.00; TP=1250.00; NOTE=...
                int pe = StringFind(rec, "ENTRY="); if(pe>=0){ string seg=StringSubstr(rec, pe+6, 20); outEntry = StringToDouble(seg); }
                int ps = StringFind(rec, "SL=");    if(ps>=0){ string seg=StringSubstr(rec, ps+3, 20); outSLp  = StringToDouble(seg); }
                int pt = StringFind(rec, "TP=");    if(pt>=0){ string seg=StringSubstr(rec, pt+3, 20); outTPp  = StringToDouble(seg); }
                int pn = StringFind(rec, "NOTE=");  if(pn>=0){ g_aiLastNote = StringSubstr(rec, pn+5, 80); }
            }
        }
        // Try to parse confidence if present and numeric; null -> leave at 0
        if(pConf>=0)
        {
            int c2 = StringFind(body, ":", pConf);
            if(c2>=0)
            {
                string sc = StringSubstr(body, c2+1, 6);
                // If starts with 'n' (null), ignore; else parse integer
                if(StringLen(sc)>0 && StringGetCharacter(sc,0)!='n') conf = (int)StringToInteger(sc);
            }
        }
    }
    if(dir==0) return false;

    g_aiLastDir = dir; g_aiLastConf = MathMax(0, MathMin(100, conf)); g_aiLastUpdate = TimeCurrent();
    // Store last absolute prices if parsed (>0)
    if(outEntry>0.0) g_aiLastEntry = outEntry;
    if(outSLp>0.0)   g_aiLastSL    = outSLp;
    if(outTPp>0.0)   g_aiLastTP    = outTPp;
    outDir = g_aiLastDir; outConf = g_aiLastConf; return true;
}

// Closes all open positions for a given magic number.
void CloseAllPositions(int magic)
{
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(!PositionSelectByTicket(tk)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

        string psym = PositionGetString(POSITION_SYMBOL);
        int ptype = (int)PositionGetInteger(POSITION_TYPE);
        double vol = PositionGetDouble(POSITION_VOLUME);

        MqlTradeRequest rq; MqlTradeResult rs; // ZeroMemory(rq); // ZeroMemory(rs);
        rq.action = TRADE_ACTION_DEAL;
        rq.position = tk;
        rq.symbol = psym;
        rq.volume = vol;
        rq.type = (ptype == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        rq.magic = magic;
        rq.comment = "BasketClose";

        if(!OrderSend(rq, rs))
        {
            Print("❌ Échec fermeture panier (", psym, "): ", GetLastError(), " - ", rs.comment);
        }
        else
        {
            Print("✅ Fermeture position ", psym, " (", (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL"), ", ", DoubleToString(vol, 2), ")");
        }
    }
}

// Closes all open positions for a specific symbol and magic number.
void ClosePositionsForSymbol(const string symbol, int magic)
{
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(!PositionSelectByTicket(tk)) continue;

        if((int)PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != symbol) continue;

        int ptype = (int)PositionGetInteger(POSITION_TYPE);
        double vol = PositionGetDouble(POSITION_VOLUME);

        MqlTradeRequest rq; MqlTradeResult rs; // ZeroMemory(rq); // ZeroMemory(rs);
        rq.action = TRADE_ACTION_DEAL;
        rq.position = tk;
        rq.symbol = symbol;
        rq.volume = vol;
        rq.type = (ptype == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        rq.magic = magic;
        rq.comment = "SymbolSpikeClose";

        if(!OrderSend(rq, rs))
        {
            Print("❌ Échec fermeture symbole (", symbol, "): ", GetLastError(), " - ", rs.comment);
        }
    }
}

// Simple per-symbol cooldown storage using fixed arrays
string  g_cdSymbols[128];
datetime g_cdUntil[128];

// Track consecutive losses per symbol and globally
string  g_lossSymbols[128];
int     g_lossCounts[128];
int     g_consecutiveLossesGlobal = 0;

int FindCooldownIndex(const string symbol)
{
    for(int i=0;i<ArraySize(g_cdSymbols);i++)
        if(g_cdSymbols[i] == symbol)
            return i;
    return -1;
}

void SetSymbolCooldown(const string symbol, const int seconds)
{
    datetime until = TimeCurrent() + (int)seconds;
    int idx = FindCooldownIndex(symbol);
    if(idx < 0)
    {
        for(int i=0;i<ArraySize(g_cdSymbols);i++)
        {
            if(g_cdSymbols[i] == "") { g_cdSymbols[i] = symbol; g_cdUntil[i] = until; break; }
        }
    }
    else
    {
        g_cdUntil[idx] = until;
    }
    Print("⏳ Cooldown armé sur ", symbol, " jusqu'à ", (long)until);
}

bool IsSymbolInCooldown(const string symbol)
{
    int idx = FindCooldownIndex(symbol);
    if(idx < 0) return false;
    return (TimeCurrent() < g_cdUntil[idx]);
}

int FindLossIndex(const string symbol)
{
    for(int i=0;i<ArraySize(g_lossSymbols);i++)
        if(g_lossSymbols[i] == symbol)
            return i;
    return -1;
}

void IncrementConsecutiveLoss(const string symbol)
{
    int idx = FindLossIndex(symbol);
    if(idx < 0)
    {
        // Ajouter un nouveau symbole avec 1 perte
        for(int i=0;i<ArraySize(g_lossSymbols);i++)
        {
            if(g_lossSymbols[i] == "") { 
                g_lossSymbols[i] = symbol; 
                g_lossCounts[i] = 1; 
                Print("📊 NOUVEAU COMPTEUR PERTES pour ", symbol, " - Perte #1");
                break; 
            }
        }
    }
    else
    {
        // Incrémenter le compteur existant
        g_lossCounts[idx]++;
        Print("📊 COMPTEUR PERTES ", symbol, " - Perte #", g_lossCounts[idx]);
    }
    g_consecutiveLossesGlobal++;
}

void ResetConsecutiveLoss(const string symbol)
{
    int idx = FindLossIndex(symbol);
    if(idx >= 0) {
        if(g_lossCounts[idx] > 0) {
            Print("✅ COMPTEUR PERTES RÉINITIALISÉ pour ", symbol, " (gain réalisé)");
        }
        g_lossCounts[idx] = 0;
    }
    g_consecutiveLossesGlobal = 0;
}

// Vérifier si la limite globale de positions simultanées est atteinte
bool IsGlobalPositionLimitReached()
{
    int openTradesGlobal = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong tk = PositionGetTicket(i);
        if(!PositionSelectByTicket(tk)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        openTradesGlobal++;
    }
    
    if(openTradesGlobal >= InpMaxSimultaneousTrades) {
        Print("🚫 LIMITE STRICTE ATTEINTE - ", openTradesGlobal, " positions ouvertes (MAXIMUM: ", InpMaxSimultaneousTrades, ")");
        Print("⏸️ AUCUNE NOUVELLE POSITION AUTORISÉE - Attendre fermeture d'une position existante");
        Print("📊 Positions actuelles:");
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            string sym = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            Print("   - ", sym, " (Ticket: ", tk, ") - Profit: $", DoubleToString(profit, 2));
        }
        return true;
    }
    return false;
}

// Vérifier si un symbole est en cooldown après pertes consécutives
bool IsSymbolInConsecutiveLossCooldown(const string symbol)
{
    int loss_idx = FindLossIndex(symbol);
    if(loss_idx >= 0 && g_lossCounts[loss_idx] >= InpMaxConsecutiveLosses) {
        return true;
    }
    return false;
}

// Check if the current symbol is a Boom, Crash, or Volatility index.
bool IsBoomCrashIndex(string symbol)
{
    return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0 || 
            StringFind(symbol, "Volatility") >= 0 || StringFind(symbol, "Vol") >= 0 ||
            StringFind(symbol, "VIX") >= 0);
}

// Check if the current symbol is specifically a Volatility index (Deriv format)
bool IsVolatilityIndex(string symbol)
{
    // Reconnaître les indices Deriv Volatility avec pourcentages
    return (StringFind(symbol, "Volatility 10") >= 0 || StringFind(symbol, "Volatility 25") >= 0 ||
            StringFind(symbol, "Volatility 50") >= 0 || StringFind(symbol, "Volatility 75") >= 0 ||
            StringFind(symbol, "Volatility 100") >= 0 || StringFind(symbol, "Vol 10") >= 0 ||
            StringFind(symbol, "Vol 25") >= 0 || StringFind(symbol, "Vol 50") >= 0 ||
            StringFind(symbol, "Vol 75") >= 0 || StringFind(symbol, "Vol 100") >= 0 ||
            StringFind(symbol, "VIX") >= 0);
}

// Check if the current symbol is a Step Index
bool IsStepIndex(string symbol)
{
    return (StringFind(symbol, "Step") >= 0 || StringFind(symbol, "STEP") >= 0);
}

// Check if the current symbol is a Forex pair
bool IsForexSymbol(string symbol)
{
    // Reconnaître les paires Forex majeures et mineures
    string major_pairs[] = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD", "NZDUSD"};
    string minor_pairs[] = {"EURGBP", "EURJPY", "EURCHF", "EURAUD", "EURCAD", "EURNZD", 
                           "GBPJPY", "GBPCHF", "GBPAUD", "GBPCAD", "GBPNZD",
                           "AUDJPY", "AUDCHF", "AUDCAD", "AUDNZD",
                           "CADJPY", "CADCHF", "CADNZD",
                           "CHFJPY", "CHFNZD",
                           "NZDJPY", "NZDCHF", "NZDCAD"};
    
    // Vérifier les paires majeures
    for(int i = 0; i < ArraySize(major_pairs); i++) {
        if(StringFind(symbol, major_pairs[i]) >= 0) return true;
    }
    
    // Vérifier les paires mineures
    for(int i = 0; i < ArraySize(minor_pairs); i++) {
        if(StringFind(symbol, minor_pairs[i]) >= 0) return true;
    }
    
    // Vérifier les paires exotiques (contiennent 3 lettres de devise)
    if(StringLen(symbol) == 6) {
        string base = StringSubstr(symbol, 0, 3);
        string quote = StringSubstr(symbol, 3, 3);
        string currencies[] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD", "CAD", "NZD", "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "TRY", "ZAR", "MXN", "BRL", "RUB", "CNY", "HKD", "SGD", "THB", "INR", "KRW"};
        
        bool base_found = false, quote_found = false;
        for(int i = 0; i < ArraySize(currencies); i++) {
            if(base == currencies[i]) base_found = true;
            if(quote == currencies[i]) quote_found = true;
        }
        if(base_found && quote_found) return true;
    }
    
    return false;
}

// Obtenir le niveau de volatilité d'un indice Deriv
int GetVolatilityLevel(string symbol)
{
    if(StringFind(symbol, "Volatility 10") >= 0 || StringFind(symbol, "Vol 10") >= 0) return 10;
    if(StringFind(symbol, "Volatility 25") >= 0 || StringFind(symbol, "Vol 25") >= 0) return 25;
    if(StringFind(symbol, "Volatility 50") >= 0 || StringFind(symbol, "Vol 50") >= 0) return 50;
    if(StringFind(symbol, "Volatility 75") >= 0 || StringFind(symbol, "Vol 75") >= 0) return 75;
    if(StringFind(symbol, "Volatility 100") >= 0 || StringFind(symbol, "Vol 100") >= 0) return 100;
    if(StringFind(symbol, "VIX") >= 0) return 50; // VIX considéré comme niveau moyen
    return 0; // Pas un indice de volatilité
}

// Trader spikes uniquement: BUY sur Boom*, SELL sur Crash*, Volatility bidirectionnel
int EnforceBoomCrashDirection(int desiredDirection)
{
    if(!IsBoomCrashIndex(_Symbol)) return desiredDirection; // No restriction on non-Boom/Crash symbols
    
    bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
    bool isCrash= (StringFind(_Symbol, "Crash")>= 0);
    bool isVolatility = IsVolatilityIndex(_Symbol);

    if(desiredDirection == 0) return 0; // No signal to enforce

    // For Volatility indices: Allow both BUY and SELL (bidirectionnel)
    if(isVolatility)
    {
        return desiredDirection; // Allow both directions for volatility
    }
    
    // For Boom: Only allow BUY signals (direction > 0)
    if(isBoom)
    {
        if(desiredDirection < 0) return 0; // Deny SELL signal
        return 1; // Allow BUY signal
    }
    // For Crash: Only allow SELL signals (direction < 0)
    else if(isCrash)
    {
        if(desiredDirection > 0) return 0; // Deny BUY signal
        return -1; // Allow SELL signal
    }

    return desiredDirection; // Should not reach here if IsBoomCrashIndex is true
}

// Snap a raw lot to symbol's min/step/max and Deriv Boom/Crash grid when applicable
double SnapLotToSymbol(const string symbol, const double desired)
{
    double volMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double volStep= SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double volMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot = desired;
    if(IsBoomCrashIndex(symbol)) lot = SnapToDerivBoomCrashLots(lot);
    if(volStep>0.0) lot = MathFloor((lot - volMin)/volStep + 0.5)*volStep + volMin;
    if(lot < volMin) lot = volMin;
    if(volMax>0.0 && lot > volMax) lot = volMax;
    return NormalizeDouble(lot, 2);
}

// Validate SL/TP against stops level and freeze levels
void EnsureValidStops(const string symbol, const int direction, const double price, const double point, double &sl_price, double &tp_price)
{
    int stops = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    int freeze= (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    int minPts = MathMax(1, stops + MathMax(0, InpStopsBufferPoints));
    double minDist = minPts * point;
    if(direction>0)
    {
        if(sl_price>0 && price - sl_price < minDist) sl_price = price - minDist;
        if(tp_price>0 && tp_price - price < minDist) tp_price = price + minDist;
    }
    else
    {
        if(sl_price>0 && sl_price - price < minDist) sl_price = price + minDist;
        if(tp_price>0 && price - tp_price < minDist) tp_price = price - minDist;
    }
}

// Simple detection of the "staircase" pattern in M1: a sequence of small, directionally consistent candles.
bool IsStaircasePatternM1()
{
    if(!InpEnableStaircaseM1) return false;

    MqlRates r[];
    int lookback = MathMax(InpStaircaseLookback, 8); // Ensure enough candles are available
    if(CopyRates(_Symbol, PERIOD_M1, 0, lookback, r) < lookback) return false;

    // Calculate average range of the last few candles (excluding the most recent one)
    double avgCandleRange = 0;
    for(int i = 1; i <= 5; i++) // Use the last 5 candles for average
    {
        if(i >= lookback) break; // Prevent index out of bounds if lookback is small
        avgCandleRange += (r[i].high - r[i].low);
    }
    avgCandleRange /= MathMax(1.0, 5.0); // Avoid division by zero

    int smallCandleCount = 0;
    int consistentDirectionCount = 0;
    int currentDirection = 0; // 1 for bullish, -1 for bearish

    // Analyze candles from most recent backwards, excluding the very last one if it's a large spike or pattern not fitting
    for(int i = 1; i < lookback; i++) // Start from index 1 (previous bar)
    {
        double candleRange = r[i].high - r[i].low;

        // Count small candles
        if(candleRange < avgCandleRange * InpSmallCandlePct)
        {
            smallCandleCount++;
        }

        // Determine candle direction
        int candleDir = 0;
        if(r[i].close > r[i].open) candleDir = 1;
        else if(r[i].close < r[i].open) candleDir = -1;

        // Track consecutive candles in the same direction
        if(currentDirection == 0 && candleDir != 0) // First directional candle
        {
            currentDirection = candleDir;
            consistentDirectionCount++;
        }
        else if(candleDir == currentDirection) // Same direction as previous
        {
            consistentDirectionCount++;
        }
        else // Direction changed or candle is flat
        {
            // Reset or update direction if a new trend is established by a small candle
            if(candleDir != 0 && candleRange < avgCandleRange * InpSmallCandlePct)
            {
                currentDirection = candleDir;
                consistentDirectionCount = 1; // Reset count for the new direction
            }
            else
            {
                currentDirection = 0; // Reset if direction is broken or candle is flat
                consistentDirectionCount = 0;
            }
        }
    }

    // Check if pattern criteria are met
    return (smallCandleCount >= InpStaircaseMinSteps && consistentDirectionCount >= InpStaircaseMinSteps / 2);
}

// Draws a signal arrow (filled) at the current price.
static datetime g_lastArrowBarTime = 0;
static long     g_lastArrowBarIndex = -1;
static datetime g_lastNotificationTime = 0;
bool CanNotify()
{
    if(!InpSendNotifications) return false;
    int cd = MathMax(0, InpNotificationCooldownSec);
    if(cd==0) return true;
    return (TimeCurrent() - g_lastNotificationTime >= cd);
}
void NotifyOnce(const string message)
{
    if(!InpSendNotifications) return;
    if(CanNotify())
    {
        SendNotification(message);
        g_lastNotificationTime = TimeCurrent();
    }
}
void DrawSignalArrow(const int direction)
{
    // Enforce one arrow per bar
    datetime bt = iTime(_Symbol, PERIOD_CURRENT, 0);
    long bidx = iBarShift(_Symbol, PERIOD_CURRENT, bt);
    if(g_lastArrowBarIndex == bidx && g_lastArrowBarTime == bt) return;
    g_lastArrowBarIndex = bidx; g_lastArrowBarTime = bt;

    string name = StringFormat("Sig_%s_%d", _Symbol, (int)TimeCurrent());
    double price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    datetime t = TimeCurrent();
    ENUM_OBJECT objType = (direction > 0) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;

    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

    if(ObjectCreate(0, name, objType, 0, t, price))
    {
        color c = (direction > 0) ? clrLime : clrRed;
        ObjectSetInteger(0, name, OBJPROP_COLOR, c);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        // OBJ_ARROW_BUY/SELL affichent une grande flèche par défaut
        // Ajouter un label proche avec recommandation / confiance si disponible
        string lbl = StringFormat("SIGLBL_%s_%d", _Symbol, (int)TimeCurrent());
        string side = (direction>0?"BUY":"SELL");
        double conf = 0.0; // best effort: afficher valeur si disponible via dernière pending
        if(pending_signal_count>0) conf = pending_signals[pending_signal_count-1].confidence;
        string txt = StringFormat("%s | Conf: %.0f%%", side, conf);
        DrawLabel(lbl, txt, 12, 48, c);
    }
}

// Draws a pre-signal arrow (hollow/lighter color) for early indication.
void DrawPreSignalArrow(const int direction)
{
    if(!InpDrawPreSignalArrows) return; // disabled by default
    string name = StringFormat("PreSig_%s_%d", _Symbol, (int)TimeCurrent());
    double price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    datetime t = TimeCurrent();
    ENUM_OBJECT objType = (direction > 0) ? OBJ_ARROW_UP : OBJ_ARROW_DOWN;

    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

    if(ObjectCreate(0, name, objType, 0, t, price))
    {
        // Use lighter colors to differentiate pre-signals
        color c = (direction > 0) ? clrAqua : clrPink;
        ObjectSetInteger(0, name, OBJPROP_COLOR, c);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2); // Better visibility
        ObjectSetString(0, name, OBJPROP_TEXT, (direction > 0) ? "PreBUY" : "PreSELL");
        // Afficher un label d'annonce
        string lbl = StringFormat("PRESIGLBL_%s_%d", _Symbol, (int)TimeCurrent());
        string side = (direction>0?"BUY":"SELL");
        DrawLabel(lbl, StringFormat("Pré-signal %s (≈1m)", side), 12, 82, c);
    }
}

// Simple dashboard panel
void UpdateDashboard()
{
    if(!InpShowDashboard) return;
    string name = "DASH_PANEL";
    string txt = "SpikeHunter Dashboard\n";
    txt += StringFormat("Symbol: %s\n", _Symbol);
    txt += StringFormat("Open positions: %d/%d\n", PositionsTotal(), InpMaxSimultaneousTrades);
    
    // Afficher le statut de la limite globale
    if(IsGlobalPositionLimitReached()) {
        txt += "🚫 LIMITE GLOBALE ATTEINTE\n";
    } else {
        txt += StringFormat("✅ Limite OK (%d/%d)\n", PositionsTotal(), InpMaxSimultaneousTrades);
    }
    txt += StringFormat("Cooldown: %s\n", IsSymbolInCooldown(_Symbol)? "ON" : "OFF");
    
    // Afficher le statut des pertes consécutives
    int loss_idx = FindLossIndex(_Symbol);
    if(loss_idx >= 0 && g_lossCounts[loss_idx] > 0) {
        txt += StringFormat("Pertes consécutives: %d/%d\n", g_lossCounts[loss_idx], InpMaxConsecutiveLosses);
        if(g_lossCounts[loss_idx] >= InpMaxConsecutiveLosses) {
            txt += StringFormat("🚫 SYMBOLE EN COOLDOWN après %d pertes\n", InpMaxConsecutiveLosses);
        }
    } else {
        txt += "Pertes consécutives: 0\n";
    }
    txt += StringFormat("TrendTF(%d): %d\n", (int)InpTrendTF, (int)CTradeExecutor::GetTrendDirection(InpTrendTF));
    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, InpDashCorner);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpDashX);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpDashY);
    ObjectSetString(0, name, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
    
    // Afficher les résultats journaliers
    UpdateDailyResults();
}

//+------------------------------------------------------------------+
//| Afficher les résultats journaliers du robot                      |
//+------------------------------------------------------------------+
void UpdateDailyResults()
{
    string name = "DAILY_RESULTS_PANEL";
    
    // Vérifier si c'est un nouveau jour (réinitialisation automatique)
    static datetime lastUpdateDay = 0;
    datetime currentDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    if(lastUpdateDay != currentDay) {
        Print("🔄 NOUVEAU JOUR DÉTECTÉ - Réinitialisation des statistiques journalières");
        lastUpdateDay = currentDay;
    }
    
    // Calculer les statistiques journalières
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double dailyProfit = CalculateDailyProfit();
    double dailyLoss = CalculateDailyLoss();
    double dailyNet = dailyProfit + dailyLoss; // dailyLoss est négatif
    int dailyTrades = CalculateDailyTrades();
    
    // Debug: Afficher les valeurs calculées
    static datetime lastDebug = 0;
    if(TimeCurrent() - lastDebug >= 10) { // Debug toutes les 10 secondes pour voir les mises à jour
        double capitalEngaged = CalculateCapitalEngaged();
        Print("DEBUG RESULTATS: Balance=", currentBalance, " Equite=", currentEquity, 
              " Profit=", dailyProfit, " Perte=", dailyLoss, " Net=", dailyNet, 
              " Gagnants=", CalculateWinningTrades(), " Perdants=", CalculateLosingTrades(),
              " Capital engagé=", capitalEngaged);
        lastDebug = TimeCurrent();
    }
    
    
    // Afficher les informations avec symbologie et couleurs pures
    string infoText = StringFormat("Capital: $%.2f | Equite: $%.2f | Profit: $%.2f | Perte: $%.2f | Net: $%.2f | Trades: %d | Positions: %d", 
                                   currentBalance, currentEquity, dailyProfit, dailyLoss, dailyNet, dailyTrades, PositionsTotal());
    
    // Créer plusieurs labels avec couleurs différentes - Position en bas à droite (soulevés)
    CreateInfoLabel(name + "_CAPITAL", StringFormat("Capital: $%.2f", currentBalance), 200, 165, clrBlack);
    CreateInfoLabel(name + "_EQUITY", StringFormat("Equite: $%.2f", currentEquity), 200, 150, clrBlack);
    
    // Profit en bleu (positif)
    if(dailyProfit > 0) {
        CreateInfoLabel(name + "_PROFIT", StringFormat("Profit: +$%.2f", dailyProfit), 200, 135, clrBlue);
    } else {
        CreateInfoLabel(name + "_PROFIT", StringFormat("Profit: $%.2f", dailyProfit), 200, 135, clrBlack);
    }
    
    // Perte en rouge (négatif)
    if(dailyLoss < 0) {
        CreateInfoLabel(name + "_LOSS", StringFormat("Perte: $%.2f", dailyLoss), 200, 120, clrRed);
    } else {
        CreateInfoLabel(name + "_LOSS", StringFormat("Perte: $%.2f", dailyLoss), 200, 120, clrBlack);
    }
    
    // Bénéfice net avec couleur selon le résultat
    color netColor = (dailyNet > 0) ? clrBlue : (dailyNet < 0) ? clrRed : clrBlack;
    CreateInfoLabel(name + "_NET", StringFormat("Net: $%.2f", dailyNet), 200, 105, netColor);
    
    // Calculer le nombre de trades gagnants et perdants
    int winningTrades = CalculateWinningTrades();
    int losingTrades = CalculateLosingTrades();
    
    // Trades gagnants en bleu, perdants en rouge
    CreateInfoLabel(name + "_WINNING", StringFormat("Gagnants: %d", winningTrades), 200, 90, clrBlue);
    CreateInfoLabel(name + "_LOSING", StringFormat("Perdants: %d", losingTrades), 200, 75, clrRed);
    
    // Score de performance sur 100 (en dessous des trades perdants)
    double performanceScore = CalculatePerformanceScore(currentBalance, dailyProfit, dailyLoss, winningTrades, losingTrades);
    color scoreColor = (performanceScore >= 80) ? clrBlue : (performanceScore >= 60) ? clrYellow : (performanceScore >= 40) ? clrOrange : clrRed;
    CreateInfoLabel(name + "_PERFORMANCE_SCORE", StringFormat("Score: %.1f/100", performanceScore), 200, 60, scoreColor);
    
    // Tendance du score (amélioration/dégradation)
    string scoreTrend = CalculateScoreTrend();
    color trendColor = (StringFind(scoreTrend, "AMÉLIORATION") >= 0) ? clrBlue : 
                      (StringFind(scoreTrend, "DÉGRADATION") >= 0) ? clrRed : clrYellow;
    CreateInfoLabel(name + "_SCORE_TREND", scoreTrend, 200, 45, trendColor);
}

//+------------------------------------------------------------------+
//| Créer un label d'information avec couleur                       |
//+------------------------------------------------------------------+
void CreateInfoLabel(const string labelName, const string text, const int x, const int y, const color clr)
{
    // Supprimer l'ancien label s'il existe
    if(ObjectFind(0, labelName) >= 0) {
        ObjectDelete(0, labelName);
    }
    
    // Créer le nouveau label
    if(ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0)) {
        ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, y);
        ObjectSetString(0, labelName, OBJPROP_TEXT, text);
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
        ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
        ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
        ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
    }
}

//+------------------------------------------------------------------+
//| Calculer le profit journalier                                   |
//+------------------------------------------------------------------+
double CalculateDailyProfit()
{
    double totalProfit = 0.0;
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    datetime todayEnd = todayStart + 86400; // +24 heures
    
    // Forcer la sélection de l'historique pour la journée
    if(!HistorySelect(todayStart, todayEnd)) {
        // Si l'historique n'est pas disponible, essayer une période plus large
        HistorySelect(todayStart - 3600, todayEnd + 3600);
    }
    
    // Parcourir l'historique des trades d'aujourd'hui
    int totalDeals = HistoryDealsTotal();
    for(int i = 0; i < totalDeals; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > 0) {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber) {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                if(profit > 0) {
                    totalProfit += profit;
                }
            }
        }
    }
    
    // Ajouter les profits des positions ouvertes (non encore fermées)
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                double profit = PositionGetDouble(POSITION_PROFIT);
                if(profit > 0) {
                    totalProfit += profit;
                }
            }
        }
    }
    
    return totalProfit;
}

//+------------------------------------------------------------------+
//| Calculer la perte journalière                                   |
//+------------------------------------------------------------------+
double CalculateDailyLoss()
{
    double totalLoss = 0.0;
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    datetime todayEnd = todayStart + 86400; // +24 heures
    
    // Forcer la sélection de l'historique pour la journée
    if(!HistorySelect(todayStart, todayEnd)) {
        // Si l'historique n'est pas disponible, essayer une période plus large
        HistorySelect(todayStart - 3600, todayEnd + 3600);
    }
    
    // Parcourir l'historique des trades d'aujourd'hui
    int totalDeals = HistoryDealsTotal();
    for(int i = 0; i < totalDeals; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > 0) {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber) {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                if(profit < 0) {
                    totalLoss += profit; // profit est négatif, donc totalLoss sera négatif
                }
            }
        }
    }
    
    // Ajouter les pertes des positions ouvertes (non encore fermées)
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                double profit = PositionGetDouble(POSITION_PROFIT);
                if(profit < 0) {
                    totalLoss += profit;
                }
            }
        }
    }
    
    return totalLoss;
}

//+------------------------------------------------------------------+
//| Calculer le nombre de trades journaliers                        |
//+------------------------------------------------------------------+
int CalculateDailyTrades()
{
    int tradeCount = 0;
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    datetime todayEnd = todayStart + 86400; // +24 heures
    
    // Parcourir l'historique des trades d'aujourd'hui
    if(HistorySelect(todayStart, todayEnd)) {
        int totalDeals = HistoryDealsTotal();
        for(int i = 0; i < totalDeals; i++) {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket > 0) {
                if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber) {
                    ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
                    if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) {
                        tradeCount++;
                    }
                }
            }
        }
    }
    
    return tradeCount;
}

//+------------------------------------------------------------------+
//| Calculer le nombre de trades gagnants                           |
//+------------------------------------------------------------------+
int CalculateWinningTrades()
{
    int winningCount = 0;
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    datetime todayEnd = todayStart + 86400; // +24 heures
    
    // Forcer la sélection de l'historique pour la journée
    if(!HistorySelect(todayStart, todayEnd)) {
        // Si l'historique n'est pas disponible, essayer une période plus large
        HistorySelect(todayStart - 3600, todayEnd + 3600);
    }
    
    // Parcourir l'historique des trades d'aujourd'hui
    int totalDeals = HistoryDealsTotal();
    for(int i = 0; i < totalDeals; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > 0) {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber) {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                if(profit > 0) {
                    winningCount++;
                }
            }
        }
    }
    
    return winningCount;
}

//+------------------------------------------------------------------+
//| Calculer le nombre de trades perdants                            |
//+------------------------------------------------------------------+
int CalculateLosingTrades()
{
    int losingCount = 0;
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    datetime todayEnd = todayStart + 86400; // +24 heures
    
    // Forcer la sélection de l'historique pour la journée
    if(!HistorySelect(todayStart, todayEnd)) {
        // Si l'historique n'est pas disponible, essayer une période plus large
        HistorySelect(todayStart - 3600, todayEnd + 3600);
    }
    
    // Parcourir l'historique des trades d'aujourd'hui
    int totalDeals = HistoryDealsTotal();
    for(int i = 0; i < totalDeals; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > 0) {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber) {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                if(profit < 0) {
                    losingCount++;
                }
            }
        }
    }
    
    return losingCount;
}

//+------------------------------------------------------------------+
//| Calculer le capital engagé journalier en pourcentage du capital principal |
//+------------------------------------------------------------------+
double CalculateCapitalEngaged()
{
    double totalCapitalEngaged = 0.0;
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    datetime todayEnd = todayStart + 86400; // +24 heures
    
    // Forcer la sélection de l'historique pour la journée
    if(!HistorySelect(todayStart, todayEnd)) {
        HistorySelect(todayStart - 3600, todayEnd + 3600);
    }
    
    // Parcourir l'historique des trades d'aujourd'hui pour calculer le capital engagé
    int totalDeals = HistoryDealsTotal();
    for(int i = 0; i < totalDeals; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > 0) {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber) {
                double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
                double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
                string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
                
                // Calculer la valeur du capital engagé pour ce trade
                double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
                double capital = volume * contractSize * price;
                totalCapitalEngaged += capital;
            }
        }
    }
    
    // Ajouter le capital des positions ouvertes (non encore fermées)
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                double volume = PositionGetDouble(POSITION_VOLUME);
                double price = PositionGetDouble(POSITION_PRICE_OPEN);
                string symbol = PositionGetString(POSITION_SYMBOL);
                
                double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
                double capital = volume * contractSize * price;
                totalCapitalEngaged += capital;
            }
        }
    }
    
    // Retourner le montant en dollars
    return totalCapitalEngaged;
}

//+------------------------------------------------------------------+
//| Calculer le score de performance sur 100                        |
//+------------------------------------------------------------------+
double CalculatePerformanceScore(double capital, double profit, double loss, int winningTrades, int losingTrades)
{
    // Variables de base
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double netProfit = profit + loss; // loss est négatif
    int totalTrades = winningTrades + losingTrades;
    
    // 1. Return on Equity (ROE) - 40% du score
    double roe = 0.0;
    if(capital > 0) {
        roe = (equity - capital) / capital;
    }
    
    // 2. Win Rate (WR) - 30% du score
    double winRate = 0.0;
    if(totalTrades > 0) {
        winRate = (double)winningTrades / totalTrades;
    }
    
    // 3. Profit Factor (PF) - 30% du score
    double profitFactor = 0.0;
    if(loss < 0) {
        profitFactor = profit / MathAbs(loss);
    } else if(profit > 0) {
        profitFactor = profit; // Si pas de perte, PF = profit
    }
    
    // Normalisation du Profit Factor entre 0 et 1
    double normalizedPF = profitFactor / (1.0 + profitFactor);
    
    // Calcul du score principal (formule sophistiquée)
    double mainScore = 100.0 * (0.4 * roe + 0.3 * winRate + 0.3 * normalizedPF);
    
    // 4. Bonus pour performance exceptionnelle
    double bonus = 0.0;
    if(roe > 0.05 && winRate > 0.6 && totalTrades >= 5) {
        bonus += 10; // Bonus pour excellente performance
    }
    if(roe > 0.1 && winRate > 0.7 && totalTrades >= 10) {
        bonus += 15; // Bonus pour performance exceptionnelle
    }
    
    // 5. Pénalités pour performance dégradée
    double penalty = 0.0;
    if(roe < -0.05) {
        penalty += 20; // Pénalité pour perte significative
    }
    if(winRate < 0.3 && totalTrades >= 5) {
        penalty += 15; // Pénalité pour taux de réussite très faible
    }
    if(profitFactor < 0.5 && totalTrades >= 3) {
        penalty += 10; // Pénalité pour mauvais profit factor
    }
    
    // 6. Score de régularité (bonus/penalty)
    double consistencyScore = 0.0;
    if(totalTrades >= 3) {
        // Mesure de la régularité basée sur l'écart entre gains et pertes
        double tradeBalance = MathAbs(winningTrades - losingTrades);
        double consistency = 1.0 - (tradeBalance / (double)totalTrades);
        consistencyScore = consistency * 5; // 0-5 points pour la régularité
    }
    
    // 7. Score final
    double finalScore = mainScore + bonus - penalty + consistencyScore;
    
    // Limiter le score entre 0 et 100
    finalScore = MathMax(0, MathMin(finalScore, 100));
    
    // Debug: Afficher les composants du score
    static datetime lastDebug = 0;
    if(TimeCurrent() - lastDebug >= 30) { // Debug toutes les 30 secondes
        Print("📊 SCORE DEBUG - ROE: ", DoubleToString(roe*100, 2), "% | WR: ", DoubleToString(winRate*100, 1), 
              "% | PF: ", DoubleToString(profitFactor, 2), " | Bonus: ", DoubleToString(bonus, 1), 
              " | Penalty: ", DoubleToString(penalty, 1), " | Final: ", DoubleToString(finalScore, 1));
        lastDebug = TimeCurrent();
    }
    
    return finalScore;
}

//+------------------------------------------------------------------+
//| Calculer la tendance du score (amélioration/dégradation)        |
//+------------------------------------------------------------------+
string CalculateScoreTrend()
{
    static double scores[7]; // Historique des 7 derniers scores
    static int scoreIndex = 0;
    static bool initialized = false;
    
    // Obtenir le score actuel
    double currentScore = CalculatePerformanceScore(
        AccountInfoDouble(ACCOUNT_BALANCE),
        CalculateDailyProfit(),
        CalculateDailyLoss(),
        CalculateWinningTrades(),
        CalculateLosingTrades()
    );
    
    // Stocker le score actuel
    scores[scoreIndex] = currentScore;
    scoreIndex = (scoreIndex + 1) % 7;
    
    if(!initialized) {
        initialized = true;
        return "Calcul...";
    }
    
    // Calculer la moyenne des 7 derniers scores
    double sum = 0.0;
    for(int i = 0; i < 7; i++) {
        sum += scores[i];
    }
    double averageScore = sum / 7.0;
    
    // Déterminer la tendance
    if(currentScore > averageScore + 5) {
        return "📈 AMÉLIORATION";
    } else if(currentScore < averageScore - 5) {
        return "📉 DÉGRADATION";
    } else {
        return "➡️ STABLE";
    }
}

//+------------------------------------------------------------------+
//| Vérifier et exécuter les signaux de spike imminent              |
//+------------------------------------------------------------------+
void CheckAndExecuteSpikeSignals()
{
    // Vérifier les signaux de volatilité avec confiance 100%
    if(IsVolatilityIndex(_Symbol)) {
        int signal = DetectVolatilitySpikeSignal();
        if(signal != 0) {
            Print("🚨 SPIKE IMMINENT DÉTECTÉ - ", (signal > 0 ? "BUY" : "SELL"), " Volatility (Confiance: 100%)");
            ExecuteSpikeTrade(signal);
        }
    }
    
    // Vérifier les signaux Boom/Crash avec confiance 100%
    if(IsBoomCrashIndex(_Symbol)) {
        int signal = DetectBoomCrashSpikeSignal();
        if(signal != 0) {
            Print("🚨 SPIKE IMMINENT DÉTECTÉ - ", (signal > 0 ? "BUY" : "SELL"), " Boom/Crash (Confiance: 100%)");
            ExecuteSpikeTrade(signal);
        }
    }
}

//+------------------------------------------------------------------+
//| Détecter les signaux de spike pour les indices de volatilité    |
//+------------------------------------------------------------------+
int DetectVolatilitySpikeSignal()
{
    // Obtenir les données M1 pour détection rapide
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 10, rates) < 10) return 0;
    
    // === FILTRES AVANCÉS DE DÉTECTION ===
    
    // 1. Vérifier la volatilité récente
    double recentVolatility = CalculateRecentVolatility(rates, 5);
    double historicalVolatility = CalculateRecentVolatility(rates, 10);
    
    if(recentVolatility < historicalVolatility * 1.2) {
        return 0; // Volatilité insuffisante
    }
    
    // 2. Vérifier la compression pré-spike
    bool isCompressed = CheckPreSpikeCompression(rates, 5);
    if(!isCompressed) {
        return 0; // Pas de compression détectée
    }
    
    // 3. Vérifier les conditions de spike imminent
    double currentPrice = rates[9].close;
    double prevPrice = rates[8].close;
    double priceChange = MathAbs(currentPrice - prevPrice) / prevPrice * 100;
    
    // 4. Vérifier la direction du mouvement
    bool isBullish = (currentPrice > prevPrice);
    bool isBearish = (currentPrice < prevPrice);
    
    // 5. Vérifier la force du mouvement
    double movementStrength = CalculateMovementStrength(rates, 5);
    if(movementStrength < 2.0) {
        return 0; // Mouvement trop faible
    }
    
    // 6. Vérifier la confluence avec les niveaux techniques
    bool hasTechnicalConfluence = CheckTechnicalConfluence(currentPrice, rates);
    if(!hasTechnicalConfluence) {
        return 0; // Pas de confluence technique
    }
    
    // === DÉCISION FINALE AVEC FILTRES AVANCÉS ===
    if(priceChange >= 0.5 && isBullish && movementStrength >= 2.0) {
        // Validation finale avec filtres avancés
        if(IsAdvancedSignalValid(1) && ApplyAdvancedFilters(1)) {
            return 1; // Signal BUY validé
        }
    } else if(priceChange >= 0.5 && isBearish && movementStrength >= 2.0) {
        // Validation finale avec filtres avancés
        if(IsAdvancedSignalValid(-1) && ApplyAdvancedFilters(-1)) {
            return -1; // Signal SELL validé
        }
    }
    
    return 0; // Pas de signal
}

//+------------------------------------------------------------------+
//| Détecter les signaux de spike pour Boom/Crash                   |
//+------------------------------------------------------------------+
int DetectBoomCrashSpikeSignal()
{
    // Obtenir les données M1 pour détection rapide
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5) return 0;
    
    // Vérifier les conditions de spike imminent
    double currentPrice = rates[4].close;
    double prevPrice = rates[3].close;
    double priceChange = MathAbs(currentPrice - prevPrice) / prevPrice * 100;
    
    // Condition 1: Changement de prix significatif (>0.3% pour Boom/Crash)
    if(priceChange < 0.3) return 0;
    
    // Condition 2: Volume élevé
    long volume = rates[4].tick_volume;
    long avgVolume = (rates[0].tick_volume + rates[1].tick_volume + rates[2].tick_volume + rates[3].tick_volume) / 4;
    if(volume < avgVolume * 1.3) return 0;
    
    // Condition 3: Momentum directionnel
    int direction = 0;
    if(currentPrice > prevPrice && rates[4].high > rates[3].high) {
        direction = 1; // BUY
    } else if(currentPrice < prevPrice && rates[4].low < rates[3].low) {
        direction = -1; // SELL
    }
    
    return direction;
}

//+------------------------------------------------------------------+
//| Exécuter un trade de spike avec SL et TP optimisés              |
//+------------------------------------------------------------------+
void ExecuteSpikeTrade(int direction)
{
    if(direction == 0) return;
    
    // Vérifier les limites
    if(IsCapitalEngagedLimitReached()) return;
    
    int currentPositions = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong tk = PositionGetTicket(i);
        if(!PositionSelectByTicket(tk)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            currentPositions++;
        }
    }
    
    if(currentPositions >= 2) {
        Print("🚫 SPIKE TRADE BLOQUÉ - Limite de 2 positions atteinte");
        return;
    }
    
    // === GESTION DES RISQUES AMÉLIORÉE ===
    
    // 1. Validation multi-timeframe
    if(!ValidateEntryWithMultiTimeframe(direction)) {
        Print("🚫 SPIKE TRADE BLOQUÉ - Validation multi-timeframe échouée");
        return;
    }
    
    // 2. Calculer la taille de lot optimisée avec gestion des risques dynamique
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskPercent = InpMaxRiskPercent; // Utiliser le paramètre de risque
    
    // Ajuster le risque selon la performance récente
    double performanceAdjustment = GetPerformanceBasedRiskAdjustment();
    riskPercent *= performanceAdjustment;
    
    // Calculer SL et TP d'abord pour déterminer la taille de lot
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double price = (direction > 0) ? ask : bid;
    
    double slDistance = CalculateSpikeStopLoss(direction, price, point);
    double tpDistance = CalculateSpikeTakeProfit(direction, price, point);
    
    // Calculer la taille de lot optimale basée sur le risque
    double lotSize = CalculateOptimalLotSize(accountBalance, riskPercent, slDistance / point);
    
    if(lotSize <= 0) {
        Print("🚫 SPIKE TRADE BLOQUÉ - Taille de lot invalide");
        return;
    }
    
    double slPrice = (direction > 0) ? price - slDistance : price + slDistance;
    double tpPrice = (direction > 0) ? price + tpDistance : price - tpDistance;
    
    // Exécuter le trade
    CTrade trade;
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    bool result = (direction > 0) ? 
        trade.Buy(lotSize, _Symbol, price, slPrice, tpPrice, "Spike Imminent") :
        trade.Sell(lotSize, _Symbol, price, slPrice, tpPrice, "Spike Imminent");
    
    if(result) {
        Print("🚨 SPIKE TRADE EXÉCUTÉ - Direction: ", (direction > 0 ? "BUY" : "SELL"), 
              " | Lot: ", DoubleToString(lotSize, 2),
              " | SL: ", DoubleToString(slPrice, 5),
              " | TP: ", DoubleToString(tpPrice, 5));
    } else {
        Print("❌ ÉCHEC SPIKE TRADE - Erreur: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculer la taille de lot pour les trades de spike              |
//+------------------------------------------------------------------+
double CalculateSpikeLotSize()
{
    // Taille de lot plus agressive pour les spikes
    double baseLot = 0.1;
    
    // Ajuster selon le capital restant
    double currentCapitalEngaged = CalculateCapitalEngaged();
    double remainingCapital = InpMaxCapitalEngagedUSD - currentCapitalEngaged;
    
    if(remainingCapital < 5.0) {
        baseLot = 0.05; // Lot réduit si peu de capital restant
    } else if(remainingCapital > 15.0) {
        baseLot = 0.2; // Lot plus agressif si beaucoup de capital restant
    }
    
    // Ajuster selon le symbole
    if(IsBoomCrashIndex(_Symbol)) {
        baseLot = MathMin(baseLot, 0.5); // Limiter pour Boom/Crash
    }
    
    return SnapLotToSymbol(_Symbol, baseLot);
}

//+------------------------------------------------------------------+
//| Calculer le Stop Loss pour les trades de spike                  |
//+------------------------------------------------------------------+
double CalculateSpikeStopLoss(int direction, double price, double point)
{
    // SL plus serré pour les spikes (risque contrôlé)
    double slPoints = 20; // 20 points de SL
    
    // Ajuster selon le symbole
    if(IsVolatilityIndex(_Symbol)) {
        slPoints = 15; // SL plus serré pour volatilité
    } else if(IsBoomCrashIndex(_Symbol)) {
        slPoints = 25; // SL un peu plus large pour Boom/Crash
    }
    
    return slPoints * point;
}

//+------------------------------------------------------------------+
//| Calculer le Take Profit pour les trades de spike                |
//+------------------------------------------------------------------+
double CalculateSpikeTakeProfit(int direction, double price, double point)
{
    // TP optimisé pour capturer les spikes
    double tpPoints = 50; // 50 points de TP (ratio 1:2.5)
    
    // Ajuster selon le symbole
    if(IsVolatilityIndex(_Symbol)) {
        tpPoints = 40; // TP plus serré pour volatilité
    } else if(IsBoomCrashIndex(_Symbol)) {
        tpPoints = 60; // TP plus large pour Boom/Crash
    }
    
    return tpPoints * point;
}

//+------------------------------------------------------------------+
//| Vérifier si le capital engagé dépasse la limite journalière     |
//+------------------------------------------------------------------+
bool IsCapitalEngagedLimitReached()
{
    double currentCapitalEngagedUSD = CalculateCapitalEngaged();
    
    if(currentCapitalEngagedUSD >= InpMaxCapitalEngagedUSD) {
        Print("🚫 LIMITE CAPITAL ENGAGÉ ATTEINTE - $", DoubleToString(currentCapitalEngagedUSD, 2), 
              " / $", DoubleToString(InpMaxCapitalEngagedUSD, 2), " maximum");
        Print("⏸️ AUCUN NOUVEAU TRADE AUTORISÉ - Capital engagé journalier dépassé");
        return true;
    }
    
    // Avertissement si on approche de la limite
    if(currentCapitalEngagedUSD >= (InpMaxCapitalEngagedUSD * 0.8)) {
        Print("⚠️ ATTENTION - Capital engagé élevé: $", DoubleToString(currentCapitalEngagedUSD, 2), 
              " / $", DoubleToString(InpMaxCapitalEngagedUSD, 2), " (", 
              DoubleToString((currentCapitalEngagedUSD/InpMaxCapitalEngagedUSD)*100, 1), "%)");
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculer la taille de lot optimale basée sur le capital restant |
//+------------------------------------------------------------------+
double CalculateOptimalLotSize(const string symbol, const double maxCapitalPerTradeUSD = 5.0)
{
    double currentCapitalEngagedUSD = CalculateCapitalEngaged();
    double remainingCapitalUSD = InpMaxCapitalEngagedUSD - currentCapitalEngagedUSD;
    
    // Si on a déjà atteint la limite, retourner 0
    if(remainingCapitalUSD <= 0) {
        return 0.0;
    }
    
    // Limiter le capital par trade (en dollars)
    double capitalToUse = MathMin(remainingCapitalUSD, maxCapitalPerTradeUSD);
    
    // Obtenir les informations du symbole
    double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // Calculer la taille de lot basée sur le capital disponible
    double calculatedLot = capitalToUse / (contractSize * price);
    
    // Ajuster selon les contraintes du symbole
    calculatedLot = MathMax(calculatedLot, minLot);
    calculatedLot = MathMin(calculatedLot, maxLot);
    
    // Arrondir selon le step
    calculatedLot = MathRound(calculatedLot / lotStep) * lotStep;
    
    // Vérifier que le capital nécessaire ne dépasse pas le capital restant
    double requiredCapital = calculatedLot * contractSize * price;
    if(requiredCapital > capitalToUse) {
        // Réduire la taille de lot
        calculatedLot = capitalToUse / (contractSize * price);
        calculatedLot = MathMax(calculatedLot, minLot);
        calculatedLot = MathRound(calculatedLot / lotStep) * lotStep;
    }
    
    return calculatedLot;
}

//+------------------------------------------------------------------+
//| Vérifier si on est en cooldown                                  |
//+------------------------------------------------------------------+
bool IsInCooldown()
{
    if(!g_inCooldown) return false;
    
    if(TimeCurrent() >= g_cooldownEndTime) {
        g_inCooldown = false;
        g_cooldownEndTime = 0;
        Print("✅ COOLDOWN TERMINÉ - Retour au trading");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Démarrer un cooldown après pertes consécutives                  |
//+------------------------------------------------------------------+
void StartCooldownAfterLosses()
{
    g_inCooldown = true;
    g_cooldownEndTime = TimeCurrent() + (InpCooldownLossMinutes * 60);
    g_consecutiveLosses = 0; // Reset counter
    Print("🚫 COOLDOWN ACTIVÉ - ", InpCooldownLossMinutes, " minutes après ", InpCooldownAfterLosses, " pertes consécutives");
}

//+------------------------------------------------------------------+
//| Démarrer un cooldown après gains consécutifs                    |
//+------------------------------------------------------------------+
void StartCooldownAfterWins()
{
    g_inCooldown = true;
    g_cooldownEndTime = TimeCurrent() + (InpCooldownWinMinutes * 60);
    g_consecutiveWins = 0; // Reset counter
    Print("🚫 COOLDOWN ACTIVÉ - ", InpCooldownWinMinutes, " minutes après ", InpCooldownAfterWins, " gains consécutifs");
}

//+------------------------------------------------------------------+
//| Mettre à jour les compteurs de pertes/gains consécutifs         |
//+------------------------------------------------------------------+
void UpdateConsecutiveCounters()
{
    // Vérifier les trades fermés récemment
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    datetime todayEnd = todayStart + 86400;
    
    if(HistorySelect(todayStart, todayEnd)) {
        int totalDeals = HistoryDealsTotal();
        for(int i = totalDeals - 1; i >= 0; i--) { // Parcourir du plus récent au plus ancien
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket > 0) {
                if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber) {
                    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                    if(profit > 0) {
                        g_consecutiveWins++;
                        g_consecutiveLosses = 0; // Reset pertes
                        
                        if(g_consecutiveWins >= InpCooldownAfterWins) {
                            StartCooldownAfterWins();
                        }
                        break; // Sortir après le premier trade trouvé
                    } else if(profit < 0) {
                        g_consecutiveLosses++;
                        g_consecutiveWins = 0; // Reset gains
                        
                        if(g_consecutiveLosses >= InpCooldownAfterLosses) {
                            StartCooldownAfterLosses();
                        }
                        break; // Sortir après le premier trade trouvé
                    }
                }
            }
        }
    }
}

// --- Multi-Timeframe Support/Resistance Zones ---
struct Zone { double low; double high; string tf; bool isSupport; datetime created; };
static Zone g_zones[60]; // Array to store zone data
static int g_zoneCount = 0;
static datetime g_lastZoneDraw = 0; // Timer for redrawing zones

// Checks if the given price is near any of the drawn MTF zones, respecting the direction.
bool IsNearAnyMTFZone(const double price, const int direction)
{
    double prox = InpEntryZoneProximityPct; // Proximity threshold from inputs
    for(int i = 0; i < g_zoneCount; i++)
    {
        double zoneCenter = 0.5 * (g_zones[i].low + g_zones[i].high);
        double zoneHeight = g_zones[i].high - g_zones[i].low;
        
        // Calculate distance as a percentage of the zone's value
        double distPct = MathAbs(price - zoneCenter) / MathMax(1e-8, zoneCenter);
        
        // Check if price is within proximity threshold
        if(distPct <= prox)
        {
            // Directional check:
            // For BUY signals (direction > 0), we need to be near a Support zone.
            // For SELL signals (direction < 0), we need to be near a Resistance zone.
            if(direction > 0 && g_zones[i].isSupport) return true;
            if(direction < 0 && !g_zones[i].isSupport) return true;
        }
    }
    return false; // Price is not near any relevant zone
}

// Draws a rectangle object on the chart.
void DrawRect(const string name, const double y1, const double y2, const color col, const int transp)
{
    // Delete existing object if it exists
    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
    
    // Define time window for the rectangle (e.g., from last lookback bar to current time)
    datetime t0 = iTime(_Symbol, PERIOD_M1, InpZonesLookbackBars - 1);
    datetime t1 = TimeCurrent();
    
    // Create the rectangle object
    if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t0, y1, t1, y2))
    {
        // Apply transparency by embedding alpha into the color
        uchar a = (uchar)MathRound(MathMin(90.0, MathMax(30.0, (double)transp)));
        color cARGB = (color)ColorToARGB(col, a);
        ObjectSetInteger(0, name, OBJPROP_COLOR, cARGB);
        ObjectSetInteger(0, name, OBJPROP_BACK, true); // Draw behind other objects
        ObjectSetInteger(0, name, OBJPROP_FILL, true); // Fill the rectangle
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    }
}

// Refreshes and redraws the multi-timeframe Support/Resistance zones.
void RefreshMTFZones()
{
    // Check if enough time has passed since the last redraw
    if(TimeCurrent() - g_lastZoneDraw < InpZoneRedrawSec) return;
    
    // Update the last redraw time
    g_lastZoneDraw = TimeCurrent();
    
    // Clear previously drawn zones
    for(int k = ObjectsTotal(0) - 1; k >= 0; k--)
    {
        string objName = ObjectName(0, k);
        // Check if the object name starts with our prefix "MTFZ_"
        if(StringFind(objName, "MTFZ_") == 0) ObjectDelete(0, objName);
    }
    
    // Reset the zone counter
    g_zoneCount = 0;
    
    // Define timeframes and corresponding tags for naming zones
    ENUM_TIMEFRAMES tfs[] = {PERIOD_D1, PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15, PERIOD_M5};
    string tags[] = {"D1", "H4", "H1", "M30", "M15", "M5"};
    
    // Iterate through each timeframe to identify zones
    for(int ti = 0; ti < ArraySize(tfs); ti++)
    {
        int lb = MathMax(50, InpZonesLookbackBars); // Ensure a minimum lookback
        MqlRates r[];
        // Copy rates for the current timeframe
        if(CopyRates(_Symbol, tfs[ti], 0, lb, r) < lb) continue; // Skip if not enough data
        
        // Draw trendlines for this TF
        DrawTrendlinesTF(tfs[ti], tags[ti]);
        
        // Find the highest high and lowest low within the lookback period (excluding the current/most recent bar)
        double highestHigh = r[1].high;
        double lowestLow = r[1].low;
        for(int i = 2; i < MathMin(lb, 200); i++) // Limit analysis to first 200 bars for performance
        {
            if(r[i].high > highestHigh) highestHigh = r[i].high;
            if(r[i].low < lowestLow) lowestLow = r[i].low;
        }
        
        // Calculate the band thickness based on percentage
        double band = InpZoneBandPct * 0.5; // Use half the percentage for each side of the zone
        
        // Draw Support Zone (based on lowest low)
        if(g_zoneCount < 60) // Ensure we don't exceed array bounds
        {
            double supportLow = lowestLow * (1.0 - band);
            double supportHigh = lowestLow * (1.0 + band);
            string zoneName = StringFormat("MTFZ_%s_SUP", tags[ti]);
            DrawRect(zoneName, supportLow, supportHigh, clrGreen, 75); // Green for support, 75% transparency
            // Store zone data
            g_zones[g_zoneCount].low = supportLow;
            g_zones[g_zoneCount].high = supportHigh;
            g_zones[g_zoneCount].tf = tags[ti];
            g_zones[g_zoneCount].isSupport = true;
            g_zones[g_zoneCount].created = TimeCurrent();
            g_zoneCount++;
        }
        
        // Draw Resistance Zone (based on highest high)
        if(g_zoneCount < 60)
        {
            double resistanceLow = highestHigh * (1.0 - band);
            double resistanceHigh = highestHigh * (1.0 + band);
            string zoneName = StringFormat("MTFZ_%s_RES", tags[ti]);
            DrawRect(zoneName, resistanceLow, resistanceHigh, clrRed, 75); // Red for resistance, 75% transparency
            // Store zone data
            g_zones[g_zoneCount].low = resistanceLow;
            g_zones[g_zoneCount].high = resistanceHigh;
            g_zones[g_zoneCount].tf = tags[ti];
            g_zones[g_zoneCount].isSupport = false;
            g_zones[g_zoneCount].created = TimeCurrent();
            g_zoneCount++;
        }
        
        // Also draw Fibonacci on higher-vol TFs for clarity (H1 and M5 as examples)
        if(tfs[ti]==PERIOD_H1 || tfs[ti]==PERIOD_M5)
            DrawFiboForMoveTF(tfs[ti], tags[ti]);
    }
}

// Helper: get approximate chart time window [t0, t1]
void GetChartTimeWindow(datetime &t0, datetime &t1)
{
    t1 = TimeCurrent();
    // Use the longest of lookback or a fixed bars count for safety
    int lb = MathMax(300, InpZonesLookbackBars);
    t0 = iTime(_Symbol, PERIOD_M1, lb-1);
}

string MakeObj(const string prefix)
{
    return StringFormat("%s_%s_%d", prefix, _Symbol, (int)TimeCurrent());
}

// Draw trendlines by connecting recent swing highs and lows for a TF
void DrawTrendlinesTF(const ENUM_TIMEFRAMES tf, const string tag)
{
    if(!InpDrawTrendlines) return;
    int bars = MathMax(200, InpZonesLookbackBars);
    MqlRates r[]; if(CopyRates(_Symbol, tf, 0, bars, r) < 100) return;
    // Find last two swing highs and lows
    int sh1=-1, sh2=-1, sl1=-1, sl2=-1;
    for(int i=3; i<MathMin(bars-3, 400); i++)
    {
        bool highSwing = (r[i].high > r[i-1].high && r[i].high > r[i+1].high && r[i].high > r[i-2].high && r[i].high > r[i+2].high);
        bool lowSwing  = (r[i].low  < r[i-1].low  && r[i].low  < r[i+1].low  && r[i].low  < r[i-2].low  && r[i].low  < r[i+2].low);
        if(highSwing){ sh2=sh1; sh1=i; }
        if(lowSwing){  sl2=sl1; sl1=i; }
        if(sh1>=0 && sh2>=0 && sl1>=0 && sl2>=0) break;
    }
    datetime t0, t1; GetChartTimeWindow(t0, t1);
    if(sh1>=0 && sh2>=0)
    {
        string n = StringFormat("TL_%s_H_%s", tag, _Symbol);
        if(ObjectFind(0, n)>=0) ObjectDelete(0, n);
        ObjectCreate(0, n, OBJ_TREND, 0, r[sh2].time, r[sh2].high, r[sh1].time, r[sh1].high);
        ObjectSetInteger(0, n, OBJPROP_COLOR, clrOrange);
        ObjectSetInteger(0, n, OBJPROP_WIDTH, 2);
    }
    if(sl1>=0 && sl2>=0)
    {
        string n = StringFormat("TL_%s_L_%s", tag, _Symbol);
        if(ObjectFind(0, n)>=0) ObjectDelete(0, n);
        ObjectCreate(0, n, OBJ_TREND, 0, r[sl2].time, r[sl2].low, r[sl1].time, r[sl1].low);
        ObjectSetInteger(0, n, OBJPROP_COLOR, clrDodgerBlue);
        ObjectSetInteger(0, n, OBJPROP_WIDTH, 2);
    }
}

// Detect a recent high-volatility move on M5 and draw Fibonacci retracements
void DrawFiboForMoveTF(const ENUM_TIMEFRAMES tf, const string tag)
{
    if(!InpDrawFibonacci) return;
    int bars = 200;
    MqlRates r[]; if(CopyRates(_Symbol, tf, 0, bars, r) < 60) return;
    // Identify the strongest move over last 50 bars by range
    int bestStart=20, bestEnd=1; double bestRange=0.0;
    for(int i=1;i<=50;i++)
    {
        int s = i+20; if(s>=bars) break; // window of 20 bars behind i
        double hi=r[i].high, lo=r[i].low;
        for(int k=i;k<=s;k++){ if(r[k].high>hi) hi=r[k].high; if(r[k].low<lo) lo=r[k].low; }
        double range = hi-lo;
        if(range>bestRange){ bestRange=range; bestStart=s; bestEnd=i; }
    }
    if(bestRange<=0) return;
    double hi=r[bestEnd].high, lo=r[bestEnd].low;
    for(int k=bestEnd;k<=bestStart;k++){ if(r[k].high>hi) hi=r[k].high; if(r[k].low<lo) lo=r[k].low; }
    bool upMove = (r[bestEnd].close < r[bestStart].close);
    double moveHigh = upMove? hi : hi;
    double moveLow  = upMove? lo : lo;
    // Fibo levels
    double f0 = moveHigh; double f100 = moveLow;
    if(!upMove){ f0=moveLow; f100=moveHigh; }
    double f236 = f0 + 0.236*(f100 - f0);
    double f382 = f0 + 0.382*(f100 - f0);
    double f500 = f0 + 0.500*(f100 - f0);
    double f618 = f0 + 0.618*(f100 - f0);
    double f786 = f0 + 0.786*(f100 - f0);
    datetime t0, t1; GetChartTimeWindow(t0, t1);
    // Draw fib lines
    struct FiboLine { string nm; double y; color c; };
    FiboLine lines[6] = {
        { StringFormat("FB_%s_0",tag), f0, clrSilver },
        { StringFormat("FB_%s_23",tag), f236, clrSilver },
        { StringFormat("FB_%s_38",tag), f382, clrSilver },
        { StringFormat("FB_%s_50",tag), f500, clrSilver },
        { StringFormat("FB_%s_61",tag), f618, clrSilver },
        { StringFormat("FB_%s_78",tag), f786, clrSilver }
    };
    for(int i=0;i<6;i++)
    {
        if(ObjectFind(0, lines[i].nm)>=0) ObjectDelete(0, lines[i].nm);
        ObjectCreate(0, lines[i].nm, OBJ_TREND, 0, t0, lines[i].y, t1, lines[i].y);
        ObjectSetInteger(0, lines[i].nm, OBJPROP_COLOR, lines[i].c);
        ObjectSetInteger(0, lines[i].nm, OBJPROP_STYLE, STYLE_DOT);
    }
    // TP zone (light yellow) between 38.2 and 61.8
    double tpLow = MathMin(f382, f618), tpHigh = MathMax(f382, f618);
    string tpN = StringFormat("FB_%s_TP", tag);
    DrawRect(tpN, tpLow, tpHigh, InpTPZoneColor, 60);
    // SL zone (light red) near 78.6..100 of the move
    double slLow = MathMin(f786, f100), slHigh = MathMax(f786, f100);
    string slN = StringFormat("FB_%s_SL", tag);
    DrawRect(slN, slLow, slHigh, InpSLZoneColor, 60);
}

bool IsPriceInFibEntryZone(const ENUM_TIMEFRAMES tf, const int direction)
{
    if(!InpDrawFibonacci) return true; // if drawing disabled, don't block
    int bars = 200; MqlRates r[]; if(CopyRates(_Symbol, tf, 0, bars, r) < 60) return true;
    // same detection as DrawFiboForMoveTF
    int bestStart=20, bestEnd=1; double bestRange=0.0;
    for(int i=1;i<=50;i++)
    {
        int s = i+20; if(s>=bars) break;
        double hi=r[i].high, lo=r[i].low;
        for(int k=i;k<=s;k++){ if(r[k].high>hi) hi=r[k].high; if(r[k].low<lo) lo=r[k].low; }
        double range = hi-lo; if(range>bestRange){ bestRange=range; bestStart=s; bestEnd=i; }
    }
    if(bestRange<=0) return true;
    double hi=r[bestEnd].high, lo=r[bestEnd].low; for(int k=bestEnd;k<=bestStart;k++){ if(r[k].high>hi) hi=r[k].high; if(r[k].low<lo) lo=r[k].low; }
    bool upMove = (r[bestEnd].close < r[bestStart].close);
    double f0 = upMove? hi : lo; double f100 = upMove? lo : hi;
    double f382 = f0 + 0.382*(f100 - f0); double f618 = f0 + 0.618*(f100 - f0);
    double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double lowZ = MathMin(f382, f618), highZ = MathMax(f382, f618);
    // Entry logic: if direction>0 (BUY), prefer price in the retracement zone of an up move.
    // If the detected move direction mismatches the trade direction, allow (return true) to avoid blocking too much.
    if(direction>0 && !upMove) return true;
    if(direction<0 && upMove) return true;
    return (px >= lowZ && px <= highZ);
}

//+------------------------------------------------------------------+
//| Détection de spike pour fermeture automatique                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Détection ultra-précise de spike pour entrée                    |
//+------------------------------------------------------------------+
bool DetectSpikeForEntry()
{
    if(!InpUltraPreciseMode) return false;
    
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 30, rates) < 30) return false;
    
    // Obtenir ATR pour validation
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period);
    if(atr_handle == INVALID_HANDLE) return false;
    
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    if(CopyBuffer(atr_handle, 0, 0, 3, atr_buffer) < 3) {
        IndicatorRelease(atr_handle);
        return false;
    }
    
    double current_atr = atr_buffer[0];
    IndicatorRelease(atr_handle);
    
    // Analyser la barre actuelle
    MqlRates current_bar = rates[0];
    double current_range = current_bar.high - current_bar.low;
    double current_body = MathAbs(current_bar.close - current_bar.open);
    
    // Calculer la moyenne des ranges des 20 barres précédentes
    double avg_range = 0.0;
    for(int i = 1; i < 21; i++) {
        avg_range += (rates[i].high - rates[i].low);
    }
    avg_range /= 20.0;
    
                // CRITÈRES ULTRA-STRICTS POUR ENTRÉE (MILIMÉTRÉ)
                // 1. Range actuel > moyenne + seuil de confirmation (plus strict)
                double range_threshold = avg_range * (1.0 + InpSpikeConfirmationThreshold/100.0);
                if(current_range <= range_threshold) {
                    Print("❌ Range insuffisant: ", DoubleToString(current_range, 5), " vs ", DoubleToString(range_threshold, 5));
                    return false;
                }
                
                // 2. Range actuel > ATR * multiplicateur minimum (plus strict)
                if(current_range <= current_atr * InpMinSpikeStrength) {
                    Print("❌ Force spike insuffisante: ", DoubleToString(current_range, 5), " vs ", DoubleToString(current_atr * InpMinSpikeStrength, 5));
                    return false;
                }
                
                // 3. Corps significatif (plus strict - 60% minimum)
                if(current_body <= current_range * 0.6) {
                    Print("❌ Corps insuffisant: ", DoubleToString(current_body, 5), " vs ", DoubleToString(current_range * 0.6, 5));
                    return false;
                }
                
                // 4. Vérification supplémentaire: momentum fort
                double momentum = MathAbs(rates[0].close - rates[1].close);
                double avg_momentum = 0;
                for(int i = 1; i < 6; i++) {
                    avg_momentum += MathAbs(rates[i].close - rates[i+1].close);
                }
                avg_momentum /= 5.0;
                
                if(momentum <= avg_momentum * 1.5) {
                    Print("❌ Momentum insuffisant: ", DoubleToString(momentum, 5), " vs ", DoubleToString(avg_momentum * 1.5, 5));
                    return false;
                }
    
    // 4. Direction claire du spike
    bool bullish_spike = current_bar.close > current_bar.open;
    bool bearish_spike = current_bar.close < current_bar.open;
    if(!bullish_spike && !bearish_spike) return false;
    
    // 5. Validation de la tendance (EMA rapide vs lente)
    int ema_fast = iMA(_Symbol, PERIOD_CURRENT, 10, 0, MODE_EMA, PRICE_CLOSE);
    int ema_slow = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_fast == INVALID_HANDLE || ema_slow == INVALID_HANDLE) return false;
    
    double ema_fast_buffer[], ema_slow_buffer[];
    ArraySetAsSeries(ema_fast_buffer, true);
    ArraySetAsSeries(ema_slow_buffer, true);
    
    if(CopyBuffer(ema_fast, 0, 0, 2, ema_fast_buffer) < 2 || 
       CopyBuffer(ema_slow, 0, 0, 2, ema_slow_buffer) < 2) {
        IndicatorRelease(ema_fast);
        IndicatorRelease(ema_slow);
        return false;
    }
    
    // Vérifier l'alignement de la tendance
    bool trend_bullish = ema_fast_buffer[0] > ema_slow_buffer[0];
    bool trend_bearish = ema_fast_buffer[0] < ema_slow_buffer[0];
    
    // Spike doit être dans le sens de la tendance
    if(bullish_spike && !trend_bullish) return false;
    if(bearish_spike && !trend_bearish) return false;
    
    IndicatorRelease(ema_fast);
    IndicatorRelease(ema_slow);
    
    // VÉRIFICATION DES SIGNALS BOOM/CRASH BASÉS S/R (CRITÈRES RENFORCÉS + TENDANCE)
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double zone_level = 0, zone_strength = 0;
    
    // Déterminer la tendance générale
    int general_trend = DetermineGeneralTrend();
    
    if(InpEnableBoomCrashSignals) {
        // Vérifier signal BOOM (BUY) près d'un support - CRITÈRES RENFORCÉS + TENDANCE
        if(bullish_spike && IsNearSupportZone(current_price, zone_level, zone_strength)) {
            if(zone_strength * 100 >= InpSupportBoomThreshold + 20) { // +20% de marge
                // Vérifier que c'est cohérent avec la tendance générale
                if(general_trend >= 0) { // Tendance haussière ou neutre
                    // Vérification supplémentaire de stabilité
                    if(IsConfidenceStable()) {
                        Print("🚀 SIGNAL BOOM CONFIRMÉ - BUY près du support - Range: ", DoubleToString(current_range, 5), 
                              " vs Moyenne: ", DoubleToString(avg_range, 5), 
                              " vs ATR: ", DoubleToString(current_atr, 5),
                              " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)",
                              " Support: ", DoubleToString(zone_level, 5), " Force: ", DoubleToString(zone_strength*100, 1), "%");
                        return true;
                    } else {
                        Print("⚠️ SIGNAL BOOM DÉTECTÉ MAIS CONFIANCE INSTABLE - Trade bloqué");
                        return false;
                    }
                } else {
                    Print("⚠️ SIGNAL BOOM DÉTECTÉ MAIS CONTRE TENDANCE GÉNÉRALE - Trade bloqué");
                    return false;
                }
            }
        }
        
        // Vérifier signal CRASH (SELL) près d'une résistance - CRITÈRES RENFORCÉS + TENDANCE
        if(!bullish_spike && IsNearResistanceZone(current_price, zone_level, zone_strength)) {
            if(zone_strength * 100 >= InpResistanceCrashThreshold + 20) { // +20% de marge
                // Vérifier que c'est cohérent avec la tendance générale
                if(general_trend <= 0) { // Tendance baissière ou neutre
                    // Vérification supplémentaire de stabilité
                    if(IsConfidenceStable()) {
                        Print("💥 SIGNAL CRASH CONFIRMÉ - SELL près de la résistance - Range: ", DoubleToString(current_range, 5), 
                              " vs Moyenne: ", DoubleToString(avg_range, 5), 
                              " vs ATR: ", DoubleToString(current_atr, 5),
                              " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)",
                              " Résistance: ", DoubleToString(zone_level, 5), " Force: ", DoubleToString(zone_strength*100, 1), "%");
                        return true;
                    } else {
                        Print("⚠️ SIGNAL CRASH DÉTECTÉ MAIS CONFIANCE INSTABLE - Trade bloqué");
                        return false;
                    }
                } else {
                    Print("⚠️ SIGNAL CRASH DÉTECTÉ MAIS CONTRE TENDANCE GÉNÉRALE - Trade bloqué");
                    return false;
                }
            }
        }
        
        Print("⚠️ SPIKE DÉTECTÉ MAIS CONDITIONS BOOM/CRASH NON REMPLIES - Attente d'une meilleure opportunité");
        return false;
    }
    
    // VÉRIFICATION DES ZONES S/R - PRIORITÉ MAXIMALE (mode classique) - CRITÈRES RENFORCÉS + TENDANCE
    if(InpPrioritizeSREntries) {
        bool near_sr = IsNearSRZone(current_price, bullish_spike, zone_level, zone_strength);
        if(near_sr) {
            // Vérifier que c'est cohérent avec la tendance générale
            bool trend_ok = false;
            if(bullish_spike && general_trend >= 0) trend_ok = true;      // BUY si tendance haussière/neutre
            if(!bullish_spike && general_trend <= 0) trend_ok = true;     // SELL si tendance baissière/neutre
            
            if(trend_ok) {
                // Vérification supplémentaire de stabilité pour zones S/R
                if(IsConfidenceStable()) {
                    Print("🎯 SPIKE CONFIRMÉ DANS ZONE S/R - Range: ", DoubleToString(current_range, 5), 
                          " vs Moyenne: ", DoubleToString(avg_range, 5), 
                          " vs ATR: ", DoubleToString(current_atr, 5),
                          " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)",
                          " Direction: ", (bullish_spike ? "HAUSSIER" : "BAISSIER"),
                          " Zone: ", DoubleToString(zone_level, 5), " Force: ", DoubleToString(zone_strength*100, 1), "%");
                    return true;
                } else {
                    Print("⚠️ SPIKE DANS ZONE S/R MAIS CONFIANCE INSTABLE - Trade bloqué");
                    return false;
                }
            } else {
                Print("⚠️ SPIKE DANS ZONE S/R MAIS CONTRE TENDANCE GÉNÉRALE - Trade bloqué");
                return false;
            }
        } else {
            Print("⚠️ SPIKE DÉTECTÉ MAIS HORS ZONE S/R - Attente d'une meilleure opportunité");
            return false;
        }
    }
    
    Print("🎯 SPIKE CONFIRMÉ POUR ENTRÉE - Range: ", DoubleToString(current_range, 5), 
          " vs Moyenne: ", DoubleToString(avg_range, 5), 
          " vs ATR: ", DoubleToString(current_atr, 5),
          " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)",
          " Direction: ", (bullish_spike ? "HAUSSIER" : "BAISSIER"));
    
    return true;
}

//+------------------------------------------------------------------+
//| Détection de spike pour fermeture immédiate                     |
//+------------------------------------------------------------------+
bool DetectSpikeForClose()
{
    if(!InpCloseImmediatelyAfterSpike) return false;
    
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 10, rates) < 10) return false;
    
    // Analyser la barre actuelle
    MqlRates current_bar = rates[0];
    double current_range = current_bar.high - current_bar.low;
    double current_body = MathAbs(current_bar.close - current_bar.open);
    
    // Calculer la moyenne des ranges des 5 barres précédentes
    double avg_range = 0.0;
    for(int i = 1; i < 6; i++) {
        avg_range += (rates[i].high - rates[i].low);
    }
    avg_range /= 5.0;
    
    // DEBUG: Afficher les valeurs pour diagnostic avec info volatilité
    static datetime last_debug_time = 0;
    if(TimeCurrent() - last_debug_time >= 10) { // Debug toutes les 10 secondes
        string vol_info = "";
        if(IsVolatilityIndex(_Symbol)) {
            int vol_level = GetVolatilityLevel(_Symbol);
            vol_info = " [VOL " + IntegerToString(vol_level) + "%]";
        }
        
        Print("🔍 DEBUG SPIKE", vol_info, " - Range actuel: ", DoubleToString(current_range, 5), 
              " Moyenne: ", DoubleToString(avg_range, 5),
              " Ratio: ", DoubleToString(current_range/avg_range, 3),
              " Corps: ", DoubleToString(current_body, 5),
              " Corps%: ", DoubleToString(current_body/current_range*100, 1), "%");
        last_debug_time = TimeCurrent();
    }
    
    // Vérification spéciale pour les indices (Crash 300, Boom 300, Volatility, etc.)
    string symbol_name = _Symbol;
    if(StringFind(symbol_name, "Crash") >= 0 || StringFind(symbol_name, "Boom") >= 0 || 
       StringFind(symbol_name, "Volatility") >= 0 || StringFind(symbol_name, "Vol") >= 0 ||
       StringFind(symbol_name, "VIX") >= 0) {
        
        // Pour les indices de volatilité, utiliser une détection adaptée au niveau
        if(IsVolatilityIndex(symbol_name)) {
            int vol_level = GetVolatilityLevel(symbol_name);
            double spike_threshold = InpVolatilitySpikeThreshold; // Valeur par défaut
            
            // Adapter le seuil selon le niveau de volatilité
            switch(vol_level) {
                case 10:  spike_threshold = InpVol10SpikeThreshold; break;  // Plus sensible
                case 25:  spike_threshold = InpVol25SpikeThreshold; break;
                case 50:  spike_threshold = InpVol50SpikeThreshold; break;
                case 75:  spike_threshold = InpVol75SpikeThreshold; break;
                case 100: spike_threshold = InpVol100SpikeThreshold; break; // Plus strict
                default:  spike_threshold = InpVolatilitySpikeThreshold; break;
            }
            
            // Spike détecté selon le niveau de volatilité
            if(current_range > avg_range * spike_threshold && current_body > current_range * 0.25) {
                Print("🚨 SPIKE VOLATILITY ", vol_level, "% DÉTECTÉ - Range: ", DoubleToString(current_range, 5), 
                      " vs Moyenne: ", DoubleToString(avg_range, 5), 
                      " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)");
                return true;
            }
            
            // Alternative: fermeture si profit > seuil adapté ET mouvement significatif
            double profit_threshold = 0.3; // Valeur par défaut
            switch(vol_level) {
                case 10:  profit_threshold = 0.1; break;  // Plus rapide pour Vol 10%
                case 25:  profit_threshold = 0.2; break;
                case 50:  profit_threshold = 0.3; break;
                case 75:  profit_threshold = 0.4; break;
                case 100: profit_threshold = 0.5; break;  // Plus patient pour Vol 100%
            }
            
            for(int i = 0; i < PositionsTotal(); i++) {
                ulong ticket = PositionGetTicket(i);
                if(!PositionSelectByTicket(ticket)) continue;
                if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                    double profit = PositionGetDouble(POSITION_PROFIT);
                    if(profit > profit_threshold && current_range > avg_range * 1.3) {
                        Print("💰 SPIKE VOLATILITY ", vol_level, "% + GAIN - Fermeture: $", DoubleToString(profit, 2), 
                              " Range: +", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%");
                        return true;
                    }
                }
            }
        }
        // Pour les indices Boom/Crash, utiliser la logique existante
        else {
            // Spike détecté si range actuel > 1.5x la moyenne ET corps > 20% du range
            if(current_range > avg_range * 1.5 && current_body > current_range * 0.2) {
                Print("🚨 SPIKE BOOM/CRASH DÉTECTÉ - Range: ", DoubleToString(current_range, 5), 
                      " vs Moyenne: ", DoubleToString(avg_range, 5), 
                      " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)");
                return true;
            }
            
            // Alternative: fermeture si profit > 0$ ET mouvement significatif (peu importe le montant)
            for(int i = 0; i < PositionsTotal(); i++) {
                ulong ticket = PositionGetTicket(i);
                if(!PositionSelectByTicket(ticket)) continue;
                if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                    double profit = PositionGetDouble(POSITION_PROFIT);
                    if(profit > 0.0 && current_range > avg_range * 1.2) {
                        Print("💰 SPIKE BOOM/CRASH + GAIN POSITIF - Fermeture immédiate: $", DoubleToString(profit, 2), 
                              " Range: +", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%");
                        return true;
                    }
                }
            }
            
            // Détection ultra-agressive pour Boom/Crash : fermeture dès le premier centime
            for(int i = 0; i < PositionsTotal(); i++) {
                ulong ticket = PositionGetTicket(i);
                if(!PositionSelectByTicket(ticket)) continue;
                if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                    double profit = PositionGetDouble(POSITION_PROFIT);
                    if(profit > 0.01) { // Dès le premier centime
                        Print("⚡ SPIKE BOOM/CRASH ULTRA-RAPIDE - Fermeture dès le gain: $", DoubleToString(profit, 2));
                        return true;
                    }
                }
            }
        }
    }
    
    // Fermeture immédiate si profit > 0$ (capture rapide dès le gain)
    // Pour les indices Boom/Crash/Volatility, fermer dès le premier centime
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            double profit = PositionGetDouble(POSITION_PROFIT);
            string pos_symbol = PositionGetString(POSITION_SYMBOL);
            
            // Pour les indices Boom/Crash, fermer dès le premier centime de profit
            if(StringFind(pos_symbol, "Crash") >= 0 || StringFind(pos_symbol, "Boom") >= 0) {
                if(profit > 0.01) {
                    Print("💰 SPIKE INDEX - Fermeture immédiate dès le gain: $", DoubleToString(profit, 2));
                    return true;
                }
            }
            // Pour les indices Volatility, fermer selon le niveau de volatilité
            else if(IsVolatilityIndex(pos_symbol)) {
                int vol_level = GetVolatilityLevel(pos_symbol);
                double vol_threshold = 0.2; // Valeur par défaut
                switch(vol_level) {
                    case 10:  vol_threshold = 0.05; break;  // Plus rapide pour Vol 10%
                    case 25:  vol_threshold = 0.1; break;
                    case 50:  vol_threshold = 0.2; break;
                    case 75:  vol_threshold = 0.3; break;
                    case 100: vol_threshold = 0.4; break;  // Plus patient pour Vol 100%
                }
                if(profit > vol_threshold) {
                    Print("💰 SPIKE VOLATILITY ", vol_level, "% - Fermeture immédiate dès le gain: $", DoubleToString(profit, 2));
                    return true;
                }
            } else {
                // Pour les autres symboles, garder le seuil normal
                if(profit > 0.0) {
                    Print("💰 PROFIT DÉTECTÉ - Fermeture immédiate: $", DoubleToString(profit, 2));
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calcul des SL/TP optimaux basés sur ATR et volatilité           |
//+------------------------------------------------------------------+
void CalculateOptimalSLTP(double &sl_price, double &tp_price, int direction, double entry_price)
{
    if(!InpUseOptimalSLTP) return;
    
    // Obtenir ATR actuel
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period);
    if(atr_handle == INVALID_HANDLE) return;
    
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    if(CopyBuffer(atr_handle, 0, 0, 3, atr_buffer) < 3) {
        IndicatorRelease(atr_handle);
        return;
    }
    
    double current_atr = atr_buffer[0];
    IndicatorRelease(atr_handle);
    
    // Calculer la taille de lot pour respecter la perte maximale de 2$
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double lot_size = InpLotSize; // Utiliser le lot par défaut pour le calcul
    
    // Calculer la distance SL basée sur la perte maximale de 2$
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    
    double max_loss_usd = InpMaxLossPerTradeUSD;
    double sl_distance = 0;
    
    if(tick_size > 0 && tick_value > 0 && lot_size > 0) {
        // Calculer la distance SL pour respecter la perte maximale
        double ticks_for_max_loss = max_loss_usd / (lot_size * tick_value);
        sl_distance = ticks_for_max_loss * tick_size;
        
        // Limiter la distance SL à 2x l'ATR maximum
        double max_atr_distance = current_atr * 2.0;
        if(sl_distance > max_atr_distance) {
            sl_distance = max_atr_distance;
            Print("⚠️ SL limité par ATR - Distance: ", DoubleToString(sl_distance, 5));
        }
    } else {
        // Fallback: utiliser ATR
        sl_distance = current_atr * InpSL_ATR_Multiplier;
    }
    
    // TP plus conservateur (1.5:1 ratio)
    double tp_distance = sl_distance * 1.5;
    
    // Calculer les prix SL/TP
    if(direction == POSITION_TYPE_BUY) {
        sl_price = entry_price - sl_distance;
        tp_price = entry_price + tp_distance;
    } else {
        sl_price = entry_price + sl_distance;
        tp_price = entry_price - tp_distance;
    }
    
    // Normaliser selon les ticks du symbole
    if(tick_size > 0) {
        sl_price = MathRound(sl_price / tick_size) * tick_size;
        tp_price = MathRound(tp_price / tick_size) * tick_size;
    }
    
    Print("📊 SL/TP ULTRA-CONSERVATEUR - Perte max: $", DoubleToString(max_loss_usd, 2),
              " SL Distance: ", DoubleToString(sl_distance, 5),
              " TP Distance: ", DoubleToString(tp_distance, 5),
              " SL: ", DoubleToString(sl_price, 5), " TP: ", DoubleToString(tp_price, 5));
}

//+------------------------------------------------------------------+
//| Détection des zones Support/Résistance multi-timeframe         |
//+------------------------------------------------------------------+
void UpdateSRZones()
{
    if(!InpEnableSRDetection) {
        Print("⚠️ Détection S/R désactivée");
        return;
    }
    
    Print("🔄 MISE À JOUR ZONES S/R - Début analyse");
    Print("📊 Paramètres S/R - Tolérance: ", InpSRZoneTolerance, " Min touches: ", InpSRMinTouches, " Confiance min: ", InpSRMinConfidence, "%");
    
    // Réinitialiser le compteur pour forcer la détection
    g_sr_zone_count = 0;
    
    // Timeframes à analyser (H4, H1, M30, M15, M5)
    ENUM_TIMEFRAMES timeframes[] = {PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15, PERIOD_M5};
    
    for(int tf = 0; tf < 5; tf++) {
        Print("📊 Analyse timeframe: ", EnumToString(timeframes[tf]));
        DetectSRZonesForTimeframe(timeframes[tf]);
    }
    
    Print("📈 Total zones détectées: ", g_sr_zone_count);
    
    // Dessiner les zones sur le graphique
    if(InpDrawSRZones) {
        Print("🎨 Dessin des zones S/R...");
        DrawSRZones();
    } else {
        Print("⚠️ Dessin S/R désactivé");
    }
    
    g_last_sr_update = TimeCurrent();
    Print("✅ MISE À JOUR ZONES S/R TERMINÉE");
}

//+------------------------------------------------------------------+
//| Détection S/R pour un timeframe spécifique                      |
//+------------------------------------------------------------------+
void DetectSRZonesForTimeframe(ENUM_TIMEFRAMES timeframe)
{
    MqlRates rates[];
    if(CopyRates(_Symbol, timeframe, 0, InpSRLookbackBars, rates) < InpSRLookbackBars) {
        Print("❌ Échec copie des données pour timeframe: ", EnumToString(timeframe));
        return;
    }
    
    Print("🔍 ANALYSE S/R - Timeframe: ", EnumToString(timeframe), " Barres: ", ArraySize(rates));
    
    int pivots_found = 0;
    
    // Trouver les pivots (hauts et bas) avec critères plus souples
    for(int i = 3; i < InpSRLookbackBars - 3; i++) {
        // Pivot haut (résistance potentielle) - critères plus souples
        bool is_pivot_high = true;
        for(int j = 1; j <= 2; j++) {
            if(rates[i].high <= rates[i-j].high || rates[i].high <= rates[i+j].high) {
                is_pivot_high = false;
                break;
            }
        }
        
        if(is_pivot_high) {
            AddSRZone(rates[i].high, false, rates[i].time, timeframe);
            pivots_found++;
            Print("📈 PIVOT HAUT DÉTECTÉ - Prix: ", DoubleToString(rates[i].high, 5), 
                  " Time: ", TimeToString(rates[i].time), " TF: ", EnumToString(timeframe));
        }
        
        // Pivot bas (support potentiel) - critères plus souples
        bool is_pivot_low = true;
        for(int j = 1; j <= 2; j++) {
            if(rates[i].low >= rates[i-j].low || rates[i].low >= rates[i+j].low) {
                is_pivot_low = false;
                break;
            }
        }
        
        if(is_pivot_low) {
            AddSRZone(rates[i].low, true, rates[i].time, timeframe);
            pivots_found++;
            Print("📉 PIVOT BAS DÉTECTÉ - Prix: ", DoubleToString(rates[i].low, 5), 
                  " Time: ", TimeToString(rates[i].time), " TF: ", EnumToString(timeframe));
        }
    }
    
    Print("✅ PIVOTS DÉTECTÉS - Timeframe: ", EnumToString(timeframe), " Nombre: ", pivots_found);
}

//+------------------------------------------------------------------+
//| Ajouter une zone S/R                                           |
//+------------------------------------------------------------------+
void AddSRZone(double level, bool is_support, datetime touch_time, ENUM_TIMEFRAMES timeframe)
{
    // Vérifier si une zone similaire existe déjà
    for(int i = 0; i < g_sr_zone_count; i++) {
        if(MathAbs(g_sr_zones[i].level - level) <= InpSRZoneTolerance &&
           g_sr_zones[i].is_support == is_support &&
           g_sr_zones[i].timeframe == timeframe) {
            
                        // Mettre à jour la zone existante
                        g_sr_zones[i].touch_count++;
                        g_sr_zones[i].last_touch = touch_time;
                        // Force atteint 100% après 3 touches (au lieu de 5)
                        g_sr_zones[i].strength = MathMin(1.0, g_sr_zones[i].touch_count / 3.0);
                        return;
        }
    }
    
    // Ajouter une nouvelle zone si on a de la place
    if(g_sr_zone_count < 50) {
        g_sr_zones[g_sr_zone_count].level = level;
        g_sr_zones[g_sr_zone_count].is_support = is_support;
        g_sr_zones[g_sr_zone_count].touch_count = 1;
        g_sr_zones[g_sr_zone_count].first_touch = touch_time;
        g_sr_zones[g_sr_zone_count].last_touch = touch_time;
        g_sr_zones[g_sr_zone_count].timeframe = timeframe;
                    g_sr_zones[g_sr_zone_count].is_active = true;
                    g_sr_zones[g_sr_zone_count].strength = 0.33; // 33% après 1 touche, 66% après 2, 100% après 3
        g_sr_zones[g_sr_zone_count].created_time = TimeCurrent();
        g_sr_zones[g_sr_zone_count].success_rate = 0.0;
        g_sr_zones[g_sr_zone_count].total_trades = 0;
        g_sr_zones[g_sr_zone_count].winning_trades = 0;
        g_sr_zones[g_sr_zone_count].avg_profit = 0.0;
        g_sr_zones[g_sr_zone_count].avg_loss = 0.0;
        g_sr_zones[g_sr_zone_count].profit_factor = 0.0;
        
        g_sr_zone_count++;
        
        Print("📍 NOUVELLE ZONE S/R - ", (is_support ? "SUPPORT" : "RÉSISTANCE"), 
              " Niveau: ", DoubleToString(level, 5), 
              " TF: ", EnumToString(timeframe));
    }
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est proche d'une zone S/R                  |
//+------------------------------------------------------------------+
bool IsNearSRZone(double price, bool is_support, double &zone_level, double &zone_strength)
{
    if(!InpPrioritizeSREntries) return false;
    
    for(int i = 0; i < g_sr_zone_count; i++) {
        if(!g_sr_zones[i].is_active) continue;
        if(g_sr_zones[i].is_support != is_support) continue;
        if(g_sr_zones[i].touch_count < InpSRMinTouches) continue;
        
        double distance = MathAbs(g_sr_zones[i].level - price);
        if(distance <= InpSRZoneTolerance) {
            zone_level = g_sr_zones[i].level;
            zone_strength = g_sr_zones[i].strength;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est proche d'une zone de support           |
//+------------------------------------------------------------------+
bool IsNearSupportZone(double price, double &zone_level, double &zone_strength)
{
    if(!InpEnableBoomCrashSignals) return false;
    
    // Pour les indices de volatilité, utiliser une logique différente
    if(IsVolatilityIndex(_Symbol)) {
        // Pour Volatility, considérer les zones de support/résistance plus flexibles
        for(int i = 0; i < g_sr_zone_count; i++) {
            if(!g_sr_zones[i].is_active) continue;
            if(!g_sr_zones[i].is_support) continue;
            if(g_sr_zones[i].touch_count < MathMax(1, InpSRMinTouches-1)) continue; // Plus flexible pour Volatility
            
            double distance = MathAbs(g_sr_zones[i].level - price);
            if(distance <= InpSRProximityTolerance * 1.5) { // Tolérance plus large pour Volatility
                zone_level = g_sr_zones[i].level;
                zone_strength = g_sr_zones[i].strength;
                return true;
            }
        }
    } else {
        // Logique normale pour Boom/Crash
        for(int i = 0; i < g_sr_zone_count; i++) {
            if(!g_sr_zones[i].is_active) continue;
            if(!g_sr_zones[i].is_support) continue; // Seulement les supports
            if(g_sr_zones[i].touch_count < InpSRMinTouches) continue;
            
            double distance = MathAbs(g_sr_zones[i].level - price);
            if(distance <= InpSRProximityTolerance) {
                zone_level = g_sr_zones[i].level;
                zone_strength = g_sr_zones[i].strength;
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est proche d'une zone de résistance        |
//+------------------------------------------------------------------+
bool IsNearResistanceZone(double price, double &zone_level, double &zone_strength)
{
    if(!InpEnableBoomCrashSignals) return false;
    
    // Pour les indices de volatilité, utiliser une logique différente
    if(IsVolatilityIndex(_Symbol)) {
        // Pour Volatility, considérer les zones de support/résistance plus flexibles
        for(int i = 0; i < g_sr_zone_count; i++) {
            if(!g_sr_zones[i].is_active) continue;
            if(g_sr_zones[i].is_support) continue;
            if(g_sr_zones[i].touch_count < MathMax(1, InpSRMinTouches-1)) continue; // Plus flexible pour Volatility
            
            double distance = MathAbs(g_sr_zones[i].level - price);
            if(distance <= InpSRProximityTolerance * 1.5) { // Tolérance plus large pour Volatility
                zone_level = g_sr_zones[i].level;
                zone_strength = g_sr_zones[i].strength;
                return true;
            }
        }
    } else {
        // Logique normale pour Boom/Crash
        for(int i = 0; i < g_sr_zone_count; i++) {
            if(!g_sr_zones[i].is_active) continue;
            if(g_sr_zones[i].is_support) continue; // Seulement les résistances
            if(g_sr_zones[i].touch_count < InpSRMinTouches) continue;
            
            double distance = MathAbs(g_sr_zones[i].level - price);
            if(distance <= InpSRProximityTolerance) {
                zone_level = g_sr_zones[i].level;
                zone_strength = g_sr_zones[i].strength;
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Prédiction de spike imminent                                   |
//+------------------------------------------------------------------+
bool PredictImminentSpike(double &confidence, int &direction)
{
    if(!InpEnableSpikePrediction) return false;
    
    confidence = 0.0;
    direction = 0;
    
    // 1. Compression volumétrique
    double volume_score = DetectVolumeCompression();
    if(volume_score) confidence += 20.0;
    
    // 2. Convergence des moyennes
    double ma_score = DetectMAConvergence();
    if(ma_score) confidence += 25.0;
    
    // 3. Compression de volatilité
    double atr_score = DetectATRCompression();
    if(atr_score) confidence += 20.0;
    
    // 4. Déséquilibre de pression
    double pressure_score = DetectPressureImbalance();
    if(pressure_score) confidence += 15.0;
    
    // 5. Momentum caché
    double momentum_score = DetectHiddenMomentum();
    if(momentum_score) confidence += 20.0;
    
    // Déterminer la direction probable
    if(DetectBullishPressure()) direction = 1;  // BUY
    else if(DetectBearishPressure()) direction = -1;  // SELL
    
    bool prediction = (confidence >= InpPredictionConfidenceMin);
    
    if(prediction) {
        Print("🔮 SPIKE IMMINENT PRÉDIT - Confiance: ", DoubleToString(confidence, 1), "%",
              " Direction: ", (direction > 0 ? "BUY" : "SELL"));
    }
    
    return prediction;
}

//+------------------------------------------------------------------+
//| Détection de compression volumétrique                          |
//+------------------------------------------------------------------+
bool DetectVolumeCompression()
{
    double current_volume = (double)iVolume(_Symbol, PERIOD_M1, 0);
    double avg_volume = 0;
    
    for(int i = 1; i <= 20; i++) {
        avg_volume += (double)iVolume(_Symbol, PERIOD_M1, i);
    }
    avg_volume /= 20.0;
    
    bool compressed = (current_volume < avg_volume * InpVolumeCompressionThreshold);
    
    if(compressed) {
        Print("📊 COMPRESSION VOLUME - Actuel: ", DoubleToString(current_volume, 0),
              " vs Moyenne: ", DoubleToString(avg_volume, 0));
    }
    
    return compressed;
}

//+------------------------------------------------------------------+
//| Détection de convergence des moyennes                          |
//+------------------------------------------------------------------+
bool DetectMAConvergence()
{
    int ema_fast = iMA(_Symbol, PERIOD_M1, 5, 0, MODE_EMA, PRICE_CLOSE);
    int ema_slow = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
    
    if(ema_fast == INVALID_HANDLE || ema_slow == INVALID_HANDLE) return false;
    
    double fast_buffer[], slow_buffer[];
    ArraySetAsSeries(fast_buffer, true);
    ArraySetAsSeries(slow_buffer, true);
    
    if(CopyBuffer(ema_fast, 0, 0, 3, fast_buffer) < 3 ||
       CopyBuffer(ema_slow, 0, 0, 3, slow_buffer) < 3) {
        IndicatorRelease(ema_fast);
        IndicatorRelease(ema_slow);
        return false;
    }
    
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double gap = MathAbs(fast_buffer[0] - slow_buffer[0]) / price;
    
    IndicatorRelease(ema_fast);
    IndicatorRelease(ema_slow);
    
    bool converged = (gap < InpMAConvergenceThreshold);
    
    if(converged) {
        Print("📈 CONVERGENCE MA - Gap: ", DoubleToString(gap * 100, 3), "%");
    }
    
    return converged;
}

//+------------------------------------------------------------------+
//| Détection de compression ATR                                  |
//+------------------------------------------------------------------+
bool DetectATRCompression()
{
    int atr_handle = iATR(_Symbol, PERIOD_M1, 14);
    if(atr_handle == INVALID_HANDLE) return false;
    
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    if(CopyBuffer(atr_handle, 0, 0, 10, atr_buffer) < 10) {
        IndicatorRelease(atr_handle);
        return false;
    }
    
    double current_atr = atr_buffer[0];
    double avg_atr = 0;
    for(int i = 1; i < 10; i++) {
        avg_atr += atr_buffer[i];
    }
    avg_atr /= 9.0;
    
    IndicatorRelease(atr_handle);
    
    bool compressed = (current_atr < avg_atr * InpATRCompressionThreshold);
    
    if(compressed) {
        Print("⚡ COMPRESSION ATR - Actuel: ", DoubleToString(current_atr, 5),
              " vs Moyenne: ", DoubleToString(avg_atr, 5));
    }
    
    return compressed;
}

//+------------------------------------------------------------------+
//| Détection de déséquilibre de pression                          |
//+------------------------------------------------------------------+
bool DetectPressureImbalance()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 10, rates) < 10) return false;
    
    double buy_pressure = 0, sell_pressure = 0;
    
    for(int i = 0; i < 10; i++) {
        double body = MathAbs(rates[i].close - rates[i].open);
        double upper_wick = rates[i].high - MathMax(rates[i].open, rates[i].close);
        double lower_wick = MathMin(rates[i].open, rates[i].close) - rates[i].low;
        
        if(rates[i].close > rates[i].open) {
            buy_pressure += body + lower_wick;
        } else {
            sell_pressure += body + upper_wick;
        }
    }
    
    double ratio = 0;
    if(sell_pressure > 0) ratio = buy_pressure / sell_pressure;
    else if(buy_pressure > 0) ratio = sell_pressure / buy_pressure;
    
    bool imbalanced = (ratio > InpPressureImbalanceThreshold);
    
    if(imbalanced) {
        Print("💪 DÉSÉQUILIBRE PRESSION - Ratio: ", DoubleToString(ratio, 2));
    }
    
    return imbalanced;
}

//+------------------------------------------------------------------+
//| Détection de momentum caché                                    |
//+------------------------------------------------------------------+
bool DetectHiddenMomentum()
{
    int rsi_handle = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
    int macd_handle = iMACD(_Symbol, PERIOD_M1, 12, 26, 9, PRICE_CLOSE);
    
    if(rsi_handle == INVALID_HANDLE || macd_handle == INVALID_HANDLE) return false;
    
    double rsi_buffer[], macd_main[], macd_signal[];
    ArraySetAsSeries(rsi_buffer, true);
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    
    if(CopyBuffer(rsi_handle, 0, 0, 3, rsi_buffer) < 3 ||
       CopyBuffer(macd_handle, 0, 0, 3, macd_main) < 3 ||
       CopyBuffer(macd_handle, 1, 0, 3, macd_signal) < 3) {
        IndicatorRelease(rsi_handle);
        IndicatorRelease(macd_handle);
        return false;
    }
    
    bool rsi_neutral = (rsi_buffer[0] > 40 && rsi_buffer[0] < 60);
    bool macd_preparing = (macd_main[0] > macd_signal[0] && macd_main[1] <= macd_signal[1]);
    
    IndicatorRelease(rsi_handle);
    IndicatorRelease(macd_handle);
    
    bool hidden_momentum = (rsi_neutral && macd_preparing);
    
    if(hidden_momentum) {
        Print("🎯 MOMENTUM CACHÉ - RSI: ", DoubleToString(rsi_buffer[0], 1));
    }
    
    return hidden_momentum;
}

//+------------------------------------------------------------------+
//| Détection de pression haussière                               |
//+------------------------------------------------------------------+
bool DetectBullishPressure()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5) return false;
    
    int bullish_count = 0;
    for(int i = 0; i < 5; i++) {
        if(rates[i].close > rates[i].open) bullish_count++;
    }
    
    return (bullish_count >= 3); // 3/5 bougies haussières
}

//+------------------------------------------------------------------+
//| Détection de pression baissière                                |
//+------------------------------------------------------------------+
bool DetectBearishPressure()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5) return false;
    
    int bearish_count = 0;
    for(int i = 0; i < 5; i++) {
        if(rates[i].close < rates[i].open) bearish_count++;
    }
    
    return (bearish_count >= 3); // 3/5 bougies baissières
}

//+------------------------------------------------------------------+
//| Préparer l'entrée anticipée                                     |
//+------------------------------------------------------------------+
void PrepareAnticipatedEntry(int direction, double confidence)
{
    if(!g_riskManager.CanOpenTrade()) {
        Print("🚫 Entrée anticipée bloquée par gestion des risques");
        return;
    }
    
    // Calculer la taille de lot basée sur la confiance
    double base_lot = InpLotSize;
    double confidence_multiplier = confidence / 100.0;
    double lot_size = base_lot * confidence_multiplier;
    
    // Normaliser la taille de lot
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(lot_size, min_lot);
    lot_size = MathMin(lot_size, max_lot);
    lot_size = MathRound(lot_size / lot_step) * lot_step;
    
    Print("🎯 ENTRÉE ANTICIPÉE PRÉPARÉE - Direction: ", (direction > 0 ? "BUY" : "SELL"),
          " Lot: ", DoubleToString(lot_size, 2),
          " Confiance: ", DoubleToString(confidence, 1), "%");
    
    // Stocker les paramètres pour exécution immédiate au prochain tick
    // (Cette fonction prépare mais n'exécute pas encore)
}

//+------------------------------------------------------------------+
//| Dessiner les zones S/R sur le graphique                        |
//+------------------------------------------------------------------+
void DrawSRZones()
{
    if(!InpDrawSRZones) return;
    
    Print("🎨 DESSIN DES ZONES S/R - Nombre de zones: ", g_sr_zone_count);
    
    // Supprimer les anciens objets S/R
    for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
        string obj_name = ObjectName(0, i, 0, -1);
        if(StringFind(obj_name, "SR_") == 0) {
            ObjectDelete(0, obj_name);
        }
    }
    
    // DEBUG: Afficher toutes les zones détectées
    Print("🔍 DEBUG - Zones détectées:");
    for(int i = 0; i < g_sr_zone_count; i++) {
        if(g_sr_zones[i].is_active) {
            Print("  Zone ", i, ": ", (g_sr_zones[i].is_support ? "SUPPORT" : "RÉSISTANCE"),
                  " Niveau: ", DoubleToString(g_sr_zones[i].level, 5),
                  " Touches: ", g_sr_zones[i].touch_count,
                  " Force: ", DoubleToString(g_sr_zones[i].strength * 100, 1), "%");
        }
    }
    
    // Dessiner les zones avec le seuil configuré
    int drawn_count = 0;
    double confidence_threshold = InpSRMinConfidence / 100.0;
    Print("🎯 Seuil de confiance requis: ", DoubleToString(confidence_threshold * 100, 1), "%");
    
    for(int i = 0; i < g_sr_zone_count; i++) {
        if(!g_sr_zones[i].is_active) {
            Print("  Zone ", i, " inactive - ignorée");
            continue;
        }
        if(g_sr_zones[i].touch_count < InpSRMinTouches) {
            Print("  Zone ", i, " touches insuffisantes (", g_sr_zones[i].touch_count, " < ", InpSRMinTouches, ") - ignorée");
            continue;
        }
        
        // TEMPORAIRE: Seuil très bas pour debug
        if(g_sr_zones[i].strength < 0.1) { // 10% minimum pour debug
            Print("  Zone ", i, " confiance insuffisante (", DoubleToString(g_sr_zones[i].strength * 100, 1), "% < 10%) - ignorée");
            continue;
        }
        
        string obj_name = StringFormat("SR_%d_%s", i, (g_sr_zones[i].is_support ? "SUPPORT" : "RESISTANCE"));
        color zone_color = g_sr_zones[i].is_support ? InpSRSupportColor : InpSRResistanceColor;
        
        // Créer une ligne horizontale
        if(ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, g_sr_zones[i].level)) {
            ObjectSetInteger(0, obj_name, OBJPROP_COLOR, zone_color);
            ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
            ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, true);
            ObjectSetInteger(0, obj_name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, false);
            
            drawn_count++;
            Print("✅ ZONE S/R DESSINÉE - ", (g_sr_zones[i].is_support ? "SUPPORT" : "RÉSISTANCE"), 
                  " Niveau: ", DoubleToString(g_sr_zones[i].level, 5), 
                  " Touches: ", g_sr_zones[i].touch_count,
                  " Force: ", DoubleToString(g_sr_zones[i].strength * 100, 1), "%");
        } else {
            Print("❌ Échec création objet S/R: ", GetLastError());
        }
    }
    
    Print("✅ ZONES S/R DESSINÉES: ", drawn_count, " zones (seuil: ", DoubleToString(InpSRMinConfidence, 0), "%)");
}





//+------------------------------------------------------------------+
//| Mise à jour dynamique des patterns en temps réel               |
//+------------------------------------------------------------------+
void UpdateDynamicPatterns()
{
    // Obtenir le prix actuel
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    datetime current_time = TimeCurrent();
    
    // Vérifier si un spike est déjà apparu - si oui, supprimer la flèche
    if(DetectSpikeForClose()) {
        RemoveDynamicArrow();
        return;
    }
    
    // Analyser le pattern actuel
    int pattern_direction = AnalyzeCurrentPattern();
    double pattern_confidence = CalculatePatternConfidence();
    
    // Afficher seulement les flèches dynamiques avec confiance élevée pour annoncer un spike imminent
    if(pattern_direction != 0 && pattern_confidence > 0.9) {
        CreateDynamicArrow(current_time, current_price, pattern_direction, pattern_confidence);
    }
}

//+------------------------------------------------------------------+
//| Analyser le pattern actuel                                      |
//+------------------------------------------------------------------+
int AnalyzeCurrentPattern()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M5, 0, 20, rates) < 20) return 0;
    
    // VÉRIFICATION STRICTE DE TENDANCE M5 ET M1
    int trendM5 = CSignalValidator::GetTrendDirection(PERIOD_M5);
    int trendM1 = CSignalValidator::GetTrendDirection(PERIOD_M1);
    
    // Ne pas analyser si tendances incertaines ou non alignées
    if(trendM5 == 0 || trendM1 == 0) {
        Print("⚠️ Pattern ignoré - Tendance M5 ou M1 incertaine");
        return 0;
    }
    
    if(trendM5 != trendM1) {
        Print("⚠️ Pattern ignoré - Tendance M5 et M1 non alignées");
        return 0;
    }
    
    // DÉTERMINER LA TENDANCE GÉNÉRALE (H1, H4)
    int general_trend = DetermineGeneralTrend();
    
    // Pattern 1: Tendance haussière récente
    if(rates[0].close > rates[2].close && rates[0].close > rates[4].close) {
        // Vérifier que c'est cohérent avec la tendance M5/M1 ET générale
        if(trendM5 > 0 && trendM1 > 0 && general_trend >= 0) {
            return 1; // Haussier
        } else {
            Print("⚠️ Pattern haussier détecté mais contre tendance M5/M1 ou générale - Ignoré");
            return 0;
        }
    }
    
    // Pattern 2: Tendance baissière récente
    if(rates[0].close < rates[2].close && rates[0].close < rates[4].close) {
        // Vérifier que c'est cohérent avec la tendance M5/M1 ET générale
        if(trendM5 < 0 && trendM1 < 0 && general_trend <= 0) {
            return -1; // Baissier
        } else {
            Print("⚠️ Pattern baissier détecté mais contre tendance M5/M1 ou générale - Ignoré");
            return 0;
        }
    }
    
    // Pattern 3: Doji actuel
    double body_size = MathAbs(rates[0].close - rates[0].open);
    double total_range = rates[0].high - rates[0].low;
    if(total_range > 0 && body_size / total_range < 0.1) {
        // Direction basée sur la tendance générale, pas locale
        if(general_trend > 0) return 1; // Tendance haussière générale
        if(general_trend < 0) return -1; // Tendance baissière générale
        return 0; // Tendance neutre
    }
    
    // Pattern 4: Hammer actuel
    double body = MathAbs(rates[0].close - rates[0].open);
    double lower_shadow = MathMin(rates[0].close, rates[0].open) - rates[0].low;
    double upper_shadow = rates[0].high - MathMax(rates[0].close, rates[0].open);
    
    if(total_range > 0 && lower_shadow > body * 2 && upper_shadow < body) {
        // Hammer seulement si tendance générale haussière ou neutre
        if(general_trend >= 0) {
            return 1; // Hammer haussier
        } else {
            Print("⚠️ Hammer détecté mais contre tendance générale - Ignoré");
            return 0;
        }
    }
    
    // Pattern 5: Shooting Star actuel
    if(total_range > 0 && upper_shadow > body * 2 && lower_shadow < body) {
        // Shooting Star seulement si tendance générale baissière ou neutre
        if(general_trend <= 0) {
            return -1; // Shooting Star baissier
        } else {
            Print("⚠️ Shooting Star détecté mais contre tendance générale - Ignoré");
            return 0;
        }
    }
    
    return 0; // Aucun pattern clair ou cohérent
}

//+------------------------------------------------------------------+
//| Déterminer la tendance générale (H1, H4)                        |
//+------------------------------------------------------------------+
int DetermineGeneralTrend()
{
    // Analyser H4 (tendance principale)
    MqlRates h4_rates[];
    if(CopyRates(_Symbol, PERIOD_H4, 0, 10, h4_rates) < 10) return 0;
    
    // Analyser H1 (tendance secondaire)
    MqlRates h1_rates[];
    if(CopyRates(_Symbol, PERIOD_H1, 0, 10, h1_rates) < 10) return 0;
    
    // Calculer tendance H4 (EMA 20 vs EMA 50)
    double h4_ema20 = CalculateEMAForTrend(h4_rates, 0, 20);
    double h4_ema50 = CalculateEMAForTrend(h4_rates, 0, 50);
    
    // Calculer tendance H1 (EMA 20 vs EMA 50)
    double h1_ema20 = CalculateEMAForTrend(h1_rates, 0, 20);
    double h1_ema50 = CalculateEMAForTrend(h1_rates, 0, 50);
    
    // Score de tendance (H4 a plus de poids)
    int h4_trend = 0;
    int h1_trend = 0;
    
    if(h4_ema20 > h4_ema50) h4_trend = 1;      // H4 haussier
    else if(h4_ema20 < h4_ema50) h4_trend = -1; // H4 baissier
    
    if(h1_ema20 > h1_ema50) h1_trend = 1;      // H1 haussier
    else if(h1_ema20 < h1_ema50) h1_trend = -1; // H1 baissier
    
    // Calculer le score final (H4 a 70% de poids, H1 a 30%)
    double trend_score = (h4_trend * 0.7) + (h1_trend * 0.3);
    
    // Vérifier la cohérence des prix
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    bool price_above_h4_ema = current_price > h4_ema20;
    bool price_above_h1_ema = current_price > h1_ema20;
    
    // Ajuster le score selon la position du prix
    if(price_above_h4_ema && h4_trend > 0) trend_score += 0.2;
    if(price_above_h1_ema && h1_trend > 0) trend_score += 0.1;
    if(!price_above_h4_ema && h4_trend < 0) trend_score -= 0.2;
    if(!price_above_h1_ema && h1_trend < 0) trend_score -= 0.1;
    
    // Déterminer la tendance finale
    int final_trend = 0;
    if(trend_score > 0.3) final_trend = 1;      // Tendance haussière
    else if(trend_score < -0.3) final_trend = -1; // Tendance baissière
    // Sinon final_trend = 0 (neutre)
    
    Print("📊 TENDANCE GÉNÉRALE - H4: ", (h4_trend > 0 ? "HAUSSIER" : (h4_trend < 0 ? "BAISSIER" : "NEUTRE")),
          " H1: ", (h1_trend > 0 ? "HAUSSIER" : (h1_trend < 0 ? "BAISSIER" : "NEUTRE")),
          " Score: ", DoubleToString(trend_score, 2),
          " Final: ", (final_trend > 0 ? "HAUSSIER" : (final_trend < 0 ? "BAISSIER" : "NEUTRE")));
    
    return final_trend;
}

//+------------------------------------------------------------------+
//| Calculer EMA pour un tableau de rates (version 2)              |
//+------------------------------------------------------------------+
double CalculateEMAForTrend(MqlRates &rates[], int index, int period)
{
    if(index < period - 1) return 0;
    
    double sum = 0;
    for(int i = 0; i < period; i++) {
        sum += rates[index - i].close;
    }
    
    return sum / period;
}

//+------------------------------------------------------------------+
//| Calculer la confiance du pattern actuel                         |
//+------------------------------------------------------------------+
double CalculatePatternConfidence()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M5, 0, 10, rates) < 10) return 0.0;
    
    double confidence = 0.0;
    
    // Confiance basée sur la force du mouvement (plus généreux)
    double price_change = MathAbs(rates[0].close - rates[4].close);
    double avg_range = 0;
    for(int i = 0; i < 5; i++) {
        avg_range += (rates[i].high - rates[i].low);
    }
    avg_range /= 5.0;
    
    if(avg_range > 0) {
        confidence += MathMin(0.5, price_change / avg_range * 2.0); // Plus généreux
    }
    
    // Confiance basée sur la cohérence de la tendance (plus généreux)
    int bullish_bars = 0;
    for(int i = 0; i < 5; i++) {
        if(rates[i].close > rates[i].open) bullish_bars++;
    }
    
    if(bullish_bars >= 4) confidence += 0.4; // Tendance haussière forte
    else if(bullish_bars <= 1) confidence += 0.4; // Tendance baissière forte
    else if(bullish_bars == 3) confidence += 0.2; // Tendance modérée
    
    // Confiance basée sur le volume (plus généreux)
    double volume_ratio = 1.0;
    if(rates[0].tick_volume > 0) {
        double avg_volume = 0;
        for(int i = 1; i < 5; i++) {
            avg_volume += (double)rates[i].tick_volume;
        }
        avg_volume /= 4.0;
        if(avg_volume > 0) {
            volume_ratio = rates[0].tick_volume / avg_volume;
        }
    }
    
    if(volume_ratio > 1.2) confidence += 0.3; // Volume élevé (seuil plus bas)
    else if(volume_ratio > 0.8) confidence += 0.1; // Volume normal
    
    // Bonus pour patterns spécifiques
    double body_size = MathAbs(rates[0].close - rates[0].open);
    double total_range = rates[0].high - rates[0].low;
    
    // Doji (indécision forte)
    if(total_range > 0 && body_size / total_range < 0.05) {
        confidence += 0.2;
    }
    
    // Hammer/Shooting Star
    if(total_range > 0) {
        double lower_shadow = MathMin(rates[0].close, rates[0].open) - rates[0].low;
        double upper_shadow = rates[0].high - MathMax(rates[0].close, rates[0].open);
        
        if(lower_shadow > body_size * 2 && upper_shadow < body_size) {
            confidence += 0.3; // Hammer
        }
        if(upper_shadow > body_size * 2 && lower_shadow < body_size) {
            confidence += 0.3; // Shooting Star
        }
    }
    
    return MathMin(1.0, confidence);
}

//+------------------------------------------------------------------+
//| Vérifier la stabilité de la confiance                          |
//+------------------------------------------------------------------+
bool IsConfidenceStable()
{
    // Vérifier toutes les 5 secondes seulement
    if(TimeCurrent() - g_last_confidence_check < 5) {
        return false; // Attendre
    }
    
    // Calculer la confiance actuelle
    double current_confidence = CalculatePatternConfidence();
    
    // Ajouter à l'historique
    g_confidence_history[g_confidence_index] = current_confidence;
    g_confidence_index = (g_confidence_index + 1) % 10;
    
    g_last_confidence_check = TimeCurrent();
    
    // Vérifier si on a assez d'historique
    int valid_entries = 0;
    for(int i = 0; i < 10; i++) {
        if(g_confidence_history[i] > 0) valid_entries++;
    }
    
    if(valid_entries < 5) {
        Print("📊 Pas assez d'historique de confiance (", valid_entries, "/5)");
        return false;
    }
    
    // Calculer la moyenne et la variance
    double sum = 0;
    for(int i = 0; i < 10; i++) {
        if(g_confidence_history[i] > 0) {
            sum += g_confidence_history[i];
        }
    }
    double average = sum / valid_entries;
    
    // Calculer la variance
    double variance = 0;
    for(int i = 0; i < 10; i++) {
        if(g_confidence_history[i] > 0) {
            double diff = g_confidence_history[i] - average;
            variance += diff * diff;
        }
    }
    variance /= valid_entries;
    double std_deviation = MathSqrt(variance);
    
    // Critères de stabilité (utiliser les paramètres d'entrée)
    double min_confidence = InpStableConfidenceMin / 100.0;
    double max_deviation = InpConfidenceStabilityMax / 100.0;
    bool is_stable = (average >= min_confidence) && (std_deviation <= max_deviation);
    
    Print("📊 STABILITÉ CONFIANCE - Moyenne: ", DoubleToString(average * 100, 1), 
          "% Écart-type: ", DoubleToString(std_deviation * 100, 1), 
          "% Stable: ", (is_stable ? "OUI" : "NON"));
    
    return is_stable;
}

//+------------------------------------------------------------------+
//| Créer une flèche dynamique                                      |
//+------------------------------------------------------------------+
void CreateDynamicArrow(datetime time, double price, int direction, double confidence)
{
    string arrow_name = "DYNAMIC_PATTERN_ARROW";
    color arrow_color = direction > 0 ? clrBlue : clrRed; // Bleu haussier, Rouge baissier
    int arrow_code = direction > 0 ? 233 : 234; // Flèches haut/bas
    
    // Supprimer l'ancienne flèche
    ObjectDelete(0, arrow_name);
    
    // Créer la nouvelle flèche
    if(ObjectCreate(0, arrow_name, OBJ_ARROW, 0, time, price)) {
        ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, arrow_color);
        ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 5); // Plus épaisse
        ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, arrow_code);
        ObjectSetInteger(0, arrow_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, arrow_name, OBJPROP_SELECTABLE, true);
        
        Print("🎯 FLÈCHE DYNAMIQUE - Direction: ", (direction > 0 ? "HAUSSIER" : "BAISSIER"),
              " Confiance: ", DoubleToString(confidence * 100, 1), "%",
              " Prix: ", DoubleToString(price, 5));
        
        // Notification sonore pour annoncer le spike imminent
        if(InpPlaySounds) {
            PlaySound(InpSoundFile);
        }
        
        // Notification push si activée
        if(InpSendNotifications) {
            string side = (direction > 0 ? "BUY" : "SELL");
            NotifyOnce(StringFormat("🚨 SPIKE IMMINENT - %s %s (Confiance: %.0f%%)", side, _Symbol, confidence * 100));
        }
    }
}

//+------------------------------------------------------------------+
//| Supprimer la flèche dynamique                                   |
//+------------------------------------------------------------------+
void RemoveDynamicArrow()
{
    string arrow_name = "DYNAMIC_PATTERN_ARROW";
    if(ObjectFind(0, arrow_name) >= 0) {
        ObjectDelete(0, arrow_name);
        Print("🗑️ FLÈCHE DYNAMIQUE SUPPRIMÉE - Spike détecté");
    }
}






//+------------------------------------------------------------------+
//| Mise à jour des données API (tous les endpoints)                |
//+------------------------------------------------------------------+
void UpdateAPIData()
{
    static datetime last_trend_update = 0;
    static datetime last_signals_update = 0;
    static datetime last_recommendations_update = 0;
    
    datetime current_time = TimeCurrent();
    
    // 1. Mise à jour de l'analyse de tendance (toutes les 30 secondes)
    if(current_time - last_trend_update >= 30) {
        UpdateTrendAnalysis();
        last_trend_update = current_time;
    }
    
    // 2. Mise à jour des signaux externes (toutes les 15 secondes)
    if(current_time - last_signals_update >= 15) {
        UpdateExternalSignals();
        last_signals_update = current_time;
    }
    
    // 3. Mise à jour des recommandations (toutes les 60 secondes)
    if(current_time - last_recommendations_update >= 60) {
        UpdateRecommendations();
        last_recommendations_update = current_time;
    }
}

//+------------------------------------------------------------------+
//| Mise à jour de l'analyse de tendance                            |
//+------------------------------------------------------------------+
void UpdateTrendAnalysis()
{
    if(!InpUseExternalSignals) return;
    
    string headers = "Accept: application/json";
    string respHeaders = "";
    char resp[];
    uchar emptyPayload[];
    ArrayResize(emptyPayload, 0);
    
    int code = (int)WebRequest("GET", InpTrendAnalysisURL, headers, 3000, emptyPayload, resp, respHeaders);
    
    if(code == 200) {
        string body = CharArrayToString(resp, 0, -1, CP_UTF8);
        Print("📈 TREND ANALYSIS - ", StringSubstr(body, 0, 100));
        
        // Parser la réponse JSON pour extraire les données de tendance
        ParseTrendResponse(body);
    } else {
        Print("❌ Échec analyse de tendance: HTTP ", code);
    }
}

//+------------------------------------------------------------------+
//| Mise à jour des signaux externes                                |
//+------------------------------------------------------------------+
void UpdateExternalSignals()
{
    if(!InpUseExternalSignals) return;
    
    string headers = "Accept: application/json";
    string respHeaders = "";
    char resp[];
    uchar emptyPayload[];
    ArrayResize(emptyPayload, 0);
    
    int code = (int)WebRequest("GET", InpExternalSignalsURL, headers, 3000, emptyPayload, resp, respHeaders);
    
    if(code == 200) {
        string body = CharArrayToString(resp, 0, -1, CP_UTF8);
        Print("📡 SIGNALS EXTERNES - ", StringSubstr(body, 0, 100));
        
        // Parser la réponse JSON pour extraire les signaux
        ParseSignalsResponse(body);
    } else {
        Print("❌ Échec signaux externes: HTTP ", code);
    }
}

//+------------------------------------------------------------------+
//| Mise à jour des recommandations                                 |
//+------------------------------------------------------------------+
void UpdateRecommendations()
{
    if(!InpUseApiRecommendations) return;
    
    string headers = "Accept: application/json";
    string respHeaders = "";
    char resp[];
    uchar emptyPayload[];
    ArrayResize(emptyPayload, 0);
    
    // Remplacer /recommendations par /trend
    string trendUrl = InpTrendAnalysisURL + "?symbol=" + _Symbol + "&timeframe=M1";
    int code = (int)WebRequest("GET", trendUrl, headers, 3000, emptyPayload, resp, respHeaders);
    
    if(code == 200) {
        string body = CharArrayToString(resp, 0, -1, CP_UTF8);
        Print("📈 TREND - ", StringSubstr(body, 0, 100));
        
        // Parser la tendance pour mise à jour
        ParseTrendResponse(body);
    } else {
        Print("❌ Échec trend: HTTP ", code);
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse de tendance                                   |
//+------------------------------------------------------------------+
void ParseTrendResponse(string json_response)
{
    // Rechercher les données de tendance dans le JSON
    if(StringFind(json_response, "\"trend\"") >= 0) {
        Print("✅ Données de tendance reçues et analysées");
        // Ici on peut extraire et stocker les données de tendance
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse des signaux                                   |
//+------------------------------------------------------------------+
void ParseSignalsResponse(string json_response)
{
    // Rechercher les signaux dans le JSON
    if(StringFind(json_response, "\"signals\"") >= 0) {
        Print("✅ Signaux externes reçus et analysés");
        // Ici on peut extraire et traiter les signaux
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse des recommandations                           |
//+------------------------------------------------------------------+
void ParseRecommendationsResponse(string json_response)
{
    // Rechercher les recommandations dans le JSON
    if(StringFind(json_response, "\"recommendations\"") >= 0) {
        Print("✅ Recommandations reçues et analysées");
        // Ici on peut extraire et traiter les recommandations
    }
}

//+------------------------------------------------------------------+
//| Exécution de trade ultra-précis sur spike confirmé              |
//+------------------------------------------------------------------+
void ExecuteUltraPreciseTrade()
{
    // Vérifier les conditions de base
    if(!g_riskManager.CanOpenTrade()) {
        Print("🚫 Trade bloqué par gestion des risques");
        return;
    }
    
    // Obtenir les données de marché
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    // Déterminer la direction du spike
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) < 1) return;
    
    bool is_bullish_spike = rates[0].close > rates[0].open;
    int direction = is_bullish_spike ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    
    // Calculer la taille de lot optimale
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * InpMaxRiskPercent / 100.0;
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    // Estimation de la distance SL pour calculer le lot
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period);
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    double current_atr = 0;
    if(atr_handle != INVALID_HANDLE && CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) >= 1) {
        current_atr = atr_buffer[0];
        IndicatorRelease(atr_handle);
    }
    
    double estimated_sl_distance = current_atr * InpSL_ATR_Multiplier;
    double lot_size = 0;
    
    if(estimated_sl_distance > 0 && tick_value > 0) {
        lot_size = risk_amount / (estimated_sl_distance / tick_size * tick_value);
    } else {
        lot_size = InpLotSize; // Utiliser le lot par défaut
    }
    
    // Normaliser la taille de lot
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(lot_size, min_lot);
    lot_size = MathMin(lot_size, max_lot);
    lot_size = MathRound(lot_size / lot_step) * lot_step;
    
    if(lot_size <= 0) {
        Print("❌ Taille de lot invalide: ", lot_size);
        return;
    }
    
    // Calculer SL/TP optimaux
    double sl_price = 0, tp_price = 0;
    double entry_price = is_bullish_spike ? ask : bid;
    CalculateOptimalSLTP(sl_price, tp_price, direction, entry_price);
    
    // Validation finale des prix
    if(sl_price <= 0 || tp_price <= 0) {
        Print("❌ SL/TP invalides - SL: ", sl_price, " TP: ", tp_price);
        return;
    }
    
    // Exécuter le trade
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lot_size;
    request.type = is_bullish_spike ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = entry_price;
    request.sl = sl_price;
    request.tp = tp_price;
    request.magic = InpMagicNumber;
    request.comment = "UltraPreciseSpike";
    request.deviation = 10;
    
    if(OrderSend(request, result)) {
        Print("🎯 TRADE ULTRA-PRÉCIS EXÉCUTÉ - Direction: ", (is_bullish_spike ? "BUY" : "SELL"),
              " Lot: ", DoubleToString(lot_size, 2),
              " Prix: ", DoubleToString(entry_price, 5),
              " SL: ", DoubleToString(sl_price, 5),
              " TP: ", DoubleToString(tp_price, 5));
        
        // Ajouter à la liste des trades intelligents
        AddSmartTrade(result.order, entry_price, lot_size, direction, sl_price, tp_price, 95.0);
        
        // Mettre à jour le timestamp du dernier trade
        static datetime last_trade_time = 0;
        last_trade_time = TimeCurrent();
        
        // Envoyer notification
        if(InpSendNotifications) {
            SendNotification("SpikeHunter Ultra-Precis: " + (is_bullish_spike ? "BUY" : "SELL") + " sur " + _Symbol);
        }
    } else {
        Print("ERREUR - Echec execution trade ultra-precis: ", GetLastError(), " - ", result.comment);
    }
}

//+------------------------------------------------------------------+
//| Calculer la volatilité récente                                   |
//+------------------------------------------------------------------+
double CalculateRecentVolatility(MqlRates &rates[], int periods)
{
    if(ArraySize(rates) < periods) return 0.0;
    
    double sum = 0.0;
    for(int i = 0; i < periods; i++) {
        double range = rates[i].high - rates[i].low;
        sum += range;
    }
    
    return sum / periods;
}

//+------------------------------------------------------------------+
//| Vérifier la compression pré-spike                                |
//+------------------------------------------------------------------+
bool CheckPreSpikeCompression(MqlRates &rates[], int periods)
{
    if(ArraySize(rates) < periods * 2) return false;
    
    // Calculer la volatilité récente vs historique
    double recentVol = CalculateRecentVolatility(rates, periods);
    double historicalVol = CalculateRecentVolatility(rates, periods * 2);
    
    // Compression si volatilité récente < 70% de l'historique
    return (recentVol < historicalVol * 0.7);
}

//+------------------------------------------------------------------+
//| Calculer la force du mouvement                                   |
//+------------------------------------------------------------------+
double CalculateMovementStrength(MqlRates &rates[], int periods)
{
    if(ArraySize(rates) < periods) return 0.0;
    
    double totalMovement = 0.0;
    double totalRange = 0.0;
    
    for(int i = 0; i < periods; i++) {
        double movement = MathAbs(rates[i].close - rates[i].open);
        double range = rates[i].high - rates[i].low;
        
        totalMovement += movement;
        totalRange += range;
    }
    
    if(totalRange == 0.0) return 0.0;
    return totalMovement / totalRange;
}

//+------------------------------------------------------------------+
//| Vérifier la confluence technique                                 |
//+------------------------------------------------------------------+
bool CheckTechnicalConfluence(double price, MqlRates &rates[])
{
    if(ArraySize(rates) < 10) return false;
    
    // 1. Vérifier la proximité avec les niveaux de support/résistance
    double support = rates[9].low;
    double resistance = rates[9].high;
    
    for(int i = 8; i >= 0; i--) {
        support = MathMin(support, rates[i].low);
        resistance = MathMax(resistance, rates[i].high);
    }
    
    // 2. Vérifier si le prix est proche d'un niveau clé
    double supportDistance = MathAbs(price - support) / price * 100;
    double resistanceDistance = MathAbs(price - resistance) / price * 100;
    
    // 3. Vérifier la tendance récente
    bool uptrend = (rates[9].close > rates[5].close);
    bool downtrend = (rates[9].close < rates[5].close);
    
    // Confluence si proche d'un niveau ET tendance cohérente
    return ((supportDistance < 0.5 || resistanceDistance < 0.5) && (uptrend || downtrend));
}

//+------------------------------------------------------------------+
//| Améliorer la gestion des risques avec position sizing dynamique  |
//+------------------------------------------------------------------+
double CalculateOptimalLotSize(double accountBalance, double riskPercent, double stopLossPoints)
{
    if(stopLossPoints <= 0) return InpLotSize;
    
    // Calculer la valeur du point
    double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    if(pointValue <= 0) return InpLotSize;
    
    // Calculer le montant à risquer
    double riskAmount = accountBalance * (riskPercent / 100.0);
    
    // Calculer la taille de lot optimale
    double optimalLotSize = riskAmount / (stopLossPoints * pointValue);
    
    // Normaliser selon les limites du symbole
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    optimalLotSize = MathMax(minLot, MathMin(maxLot, optimalLotSize));
    optimalLotSize = MathRound(optimalLotSize / lotStep) * lotStep;
    
    return optimalLotSize;
}

//+------------------------------------------------------------------+
//| Optimiser les points d'entrée avec analyse multi-timeframe       |
//+------------------------------------------------------------------+
bool ValidateEntryWithMultiTimeframe(int direction)
{
    // Vérifier la tendance sur plusieurs timeframes
    bool h1Trend = CheckTrendDirection(PERIOD_H1, direction);
    bool h4Trend = CheckTrendDirection(PERIOD_H4, direction);
    bool d1Trend = CheckTrendDirection(PERIOD_D1, direction);
    
    // Entrée valide si au moins 2 timeframes sont alignés
    int alignedTimeframes = 0;
    if(h1Trend) alignedTimeframes++;
    if(h4Trend) alignedTimeframes++;
    if(d1Trend) alignedTimeframes++;
    
    return (alignedTimeframes >= 2);
}

//+------------------------------------------------------------------+
//| Vérifier la direction de tendance sur un timeframe donné         |
//+------------------------------------------------------------------+
bool CheckTrendDirection(ENUM_TIMEFRAMES timeframe, int direction)
{
    MqlRates rates[];
    if(CopyRates(_Symbol, timeframe, 0, 20, rates) < 20) return false;
    
    // Calculer la moyenne mobile simple
    double sma20 = 0.0;
    for(int i = 0; i < 20; i++) {
        sma20 += rates[i].close;
    }
    sma20 /= 20.0;
    
    double currentPrice = rates[19].close;
    
    if(direction > 0) {
        return (currentPrice > sma20); // Tendance haussière pour BUY
    } else {
        return (currentPrice < sma20); // Tendance baissière pour SELL
    }
}

//+------------------------------------------------------------------+
//| Ajuster le risque basé sur la performance récente                |
//+------------------------------------------------------------------+
double GetPerformanceBasedRiskAdjustment()
{
    // Obtenir les métriques de performance récentes
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double dailyProfit = CalculateDailyProfit();
    double dailyLoss = CalculateDailyLoss();
    int winningTrades = CalculateWinningTrades();
    int losingTrades = CalculateLosingTrades();
    
    // Calculer le score de performance
    double performanceScore = CalculatePerformanceScore(
        currentBalance, dailyProfit, dailyLoss, winningTrades, losingTrades
    );
    
    // Ajuster le risque selon la performance
    if(performanceScore >= 80) {
        return 1.2; // Augmenter le risque de 20% si excellente performance
    } else if(performanceScore >= 60) {
        return 1.0; // Risque normal
    } else if(performanceScore >= 40) {
        return 0.8; // Réduire le risque de 20% si performance moyenne
    } else {
        return 0.5; // Réduire drastiquement le risque si mauvaise performance
    }
}

//+------------------------------------------------------------------+
//| Améliorer la détection de signaux avec filtres avancés           |
//+------------------------------------------------------------------+
bool IsAdvancedSignalValid(int direction)
{
    // 1. Vérifier la volatilité du marché
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 20, rates) < 20) return false;
    
    double currentVolatility = CalculateRecentVolatility(rates, 5);
    double historicalVolatility = CalculateRecentVolatility(rates, 20);
    
    if(currentVolatility < historicalVolatility * 0.8) {
        return false; // Marché trop calme
    }
    
    // 2. Vérifier la compression pré-spike
    if(!CheckPreSpikeCompression(rates, 5)) {
        return false; // Pas de compression détectée
    }
    
    // 3. Vérifier la confluence technique
    double currentPrice = rates[19].close;
    if(!CheckTechnicalConfluence(currentPrice, rates)) {
        return false; // Pas de confluence technique
    }
    
    // 4. Vérifier la force du mouvement
    double movementStrength = CalculateMovementStrength(rates, 5);
    if(movementStrength < 1.5) {
        return false; // Mouvement trop faible
    }
    
    // 5. Vérifier l'alignement multi-timeframe
    if(!ValidateEntryWithMultiTimeframe(direction)) {
        return false; // Pas d'alignement multi-timeframe
    }
    
    return true; // Tous les filtres passés
}

//+------------------------------------------------------------------+
//| Système de trailing stop intelligent                            |
//+------------------------------------------------------------------+
void ManageIntelligentTrailingStop()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        
        if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                            SymbolInfoDouble(symbol, SYMBOL_BID) : 
                            SymbolInfoDouble(symbol, SYMBOL_ASK);
        double profit = PositionGetDouble(POSITION_PROFIT);
        double sl = PositionGetDouble(POSITION_SL);
        
        // Calculer le profit en points
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double profitPoints = 0;
        
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            profitPoints = (currentPrice - openPrice) / point;
        } else {
            profitPoints = (openPrice - currentPrice) / point;
        }
        
        // Trailing stop intelligent basé sur la volatilité
        if(profitPoints >= InpTrailingStartPoints) {
            double atr = GetATRValue(symbol, PERIOD_M1, 14);
            double trailingDistance = atr * 2.0; // 2x ATR pour le trailing
            
            double newSL = 0;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                newSL = currentPrice - trailingDistance;
                if(newSL > sl || sl == 0) {
                    ModifyPositionSLAdvanced(ticket, newSL);
                }
            } else {
                newSL = currentPrice + trailingDistance;
                if(newSL < sl || sl == 0) {
                    ModifyPositionSLAdvanced(ticket, newSL);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Obtenir la valeur ATR                                           |
//+------------------------------------------------------------------+
double GetATRValue(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
    int handle = iATR(symbol, timeframe, period);
    if(handle == INVALID_HANDLE) return 0.0;
    
    double atr[];
    if(CopyBuffer(handle, 0, 0, 1, atr) < 1) return 0.0;
    
    return atr[0];
}

//+------------------------------------------------------------------+
//| Modifier le Stop Loss d'une position (version améliorée)        |
//+------------------------------------------------------------------+
bool ModifyPositionSLAdvanced(ulong ticket, double newSL)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = PositionGetString(POSITION_SYMBOL);
    request.sl = newSL;
    request.tp = PositionGetDouble(POSITION_TP);
    
    if(OrderSend(request, result)) {
        Print("✅ Trailing Stop mis à jour - Ticket: ", ticket, " Nouveau SL: ", DoubleToString(newSL, 5));
        return true;
    } else {
        Print("❌ Erreur modification SL - Ticket: ", ticket, " Erreur: ", GetLastError());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Système de fermeture partielle intelligent                      |
//+------------------------------------------------------------------+
void ManageIntelligentPartialClose()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        
        if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                            SymbolInfoDouble(symbol, SYMBOL_BID) : 
                            SymbolInfoDouble(symbol, SYMBOL_ASK);
        double profit = PositionGetDouble(POSITION_PROFIT);
        double volume = PositionGetDouble(POSITION_VOLUME);
        
        // Calculer le profit en points
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double profitPoints = 0;
        
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            profitPoints = (currentPrice - openPrice) / point;
        } else {
            profitPoints = (openPrice - currentPrice) / point;
        }
        
        // Fermeture partielle si profit suffisant
        if(profitPoints >= InpPartialCloseAtProfit && volume > 0.01) {
            double closeVolume = volume * (InpPartialClosePercent / 100.0);
            closeVolume = MathMax(0.01, MathMin(closeVolume, volume - 0.01)); // Garder au moins 0.01
            
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = symbol;
            request.volume = closeVolume;
            request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                          ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = currentPrice;
            request.magic = InpMagicNumber;
            request.comment = "Partial Close";
            
            if(OrderSend(request, result)) {
                Print("💰 Fermeture partielle - Ticket: ", ticket, " Volume: ", DoubleToString(closeVolume, 2), 
                      " Profit: $", DoubleToString(profit, 2));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Système de filtres avancés pour réduire les faux signaux        |
//+------------------------------------------------------------------+
bool ApplyAdvancedFilters(int direction)
{
    // 1. Filtre de volatilité du marché
    if(!IsMarketVolatilityOptimal()) {
        return false; // Volatilité insuffisante
    }
    
    // 2. Filtre de tendance multi-timeframe
    if(!IsMultiTimeframeAligned(direction)) {
        return false; // Tendance non alignée
    }
    
    // 3. Filtre de support/résistance
    if(!IsNearKeyLevel()) {
        return false; // Pas proche d'un niveau clé
    }
    
    // 4. Filtre de momentum
    if(!HasStrongMomentum(direction)) {
        return false; // Momentum insuffisant
    }
    
    // 5. Filtre de volume
    if(!HasVolumeConfirmation()) {
        return false; // Volume insuffisant
    }
    
    // 6. Filtre de session de trading
    if(!IsOptimalTradingSession()) {
        return false; // Session non optimale
    }
    
    return true; // Tous les filtres passés
}

//+------------------------------------------------------------------+
//| Vérifier si la volatilité du marché est optimale                |
//+------------------------------------------------------------------+
bool IsMarketVolatilityOptimal()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 20, rates) < 20) return false;
    
    // Calculer la volatilité actuelle vs historique
    double currentVol = CalculateRecentVolatility(rates, 5);
    double historicalVol = CalculateRecentVolatility(rates, 20);
    
    // Volatilité optimale si entre 80% et 200% de la moyenne historique
    return (currentVol >= historicalVol * 0.8 && currentVol <= historicalVol * 2.0);
}

//+------------------------------------------------------------------+
//| Vérifier l'alignement multi-timeframe                            |
//+------------------------------------------------------------------+
bool IsMultiTimeframeAligned(int direction)
{
    // Vérifier H1, H4, D1
    bool h1Aligned = CheckTrendDirection(PERIOD_H1, direction);
    bool h4Aligned = CheckTrendDirection(PERIOD_H4, direction);
    bool d1Aligned = CheckTrendDirection(PERIOD_D1, direction);
    
    // Au moins 2 timeframes doivent être alignés
    int alignedCount = 0;
    if(h1Aligned) alignedCount++;
    if(h4Aligned) alignedCount++;
    if(d1Aligned) alignedCount++;
    
    return (alignedCount >= 2);
}

//+------------------------------------------------------------------+
//| Vérifier si proche d'un niveau clé                               |
//+------------------------------------------------------------------+
bool IsNearKeyLevel()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 50, rates) < 50) return false;
    
    double currentPrice = rates[49].close;
    
    // Trouver les niveaux de support/résistance
    double support = rates[49].low;
    double resistance = rates[49].high;
    
    for(int i = 48; i >= 0; i--) {
        support = MathMin(support, rates[i].low);
        resistance = MathMax(resistance, rates[i].high);
    }
    
    // Vérifier la proximité (dans les 0.5%)
    double supportDistance = MathAbs(currentPrice - support) / currentPrice * 100;
    double resistanceDistance = MathAbs(currentPrice - resistance) / currentPrice * 100;
    
    return (supportDistance < 0.5 || resistanceDistance < 0.5);
}

//+------------------------------------------------------------------+
//| Vérifier le momentum                                             |
//+------------------------------------------------------------------+
bool HasStrongMomentum(int direction)
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 10, rates) < 10) return false;
    
    // Calculer le momentum sur 5 périodes
    double momentum = 0;
    for(int i = 9; i >= 5; i--) {
        momentum += (rates[i].close - rates[i-1].close);
    }
    
    if(direction > 0) {
        return (momentum > 0); // Momentum haussier pour BUY
    } else {
        return (momentum < 0); // Momentum baissier pour SELL
    }
}

//+------------------------------------------------------------------+
//| Vérifier la confirmation de volume                               |
//+------------------------------------------------------------------+
bool HasVolumeConfirmation()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 10, rates) < 10) return false;
    
    // Volume actuel vs moyenne
    long currentVolume = rates[9].tick_volume;
    long avgVolume = 0;
    for(int i = 0; i < 9; i++) {
        avgVolume += rates[i].tick_volume;
    }
    avgVolume /= 9;
    
    // Volume doit être au moins 1.5x la moyenne
    return (currentVolume >= avgVolume * 1.5);
}

//+------------------------------------------------------------------+
//| Vérifier si c'est une session de trading optimale               |
//+------------------------------------------------------------------+
bool IsOptimalTradingSession()
{
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    
    // Sessions optimales (heures UTC)
    bool londonSession = (time.hour >= 7 && time.hour < 16);  // London
    bool nySession = (time.hour >= 13 && time.hour < 22);     // New York
    bool overlap = (time.hour >= 13 && time.hour < 16);      // Overlap
    
    return (londonSession || nySession || overlap);
}

//+------------------------------------------------------------------+
//| Optimiser la logique de cooldown pour plus d'activité            |
//+------------------------------------------------------------------+
bool ShouldReduceCooldown()
{
    // Réduire le cooldown si les conditions sont favorables
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Si le compte est en profit, réduire les cooldowns
    if(currentEquity > currentBalance) {
        return true;
    }
    
    // Si peu de trades récents, permettre plus d'activité
    int recentTrades = 0;
    for(int i = 0; i < HistoryDealsTotal(); i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > 0) {
            datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            if(TimeCurrent() - dealTime < 3600) { // Dernière heure
                recentTrades++;
            }
        }
    }
    
    return (recentTrades < 3); // Moins de 3 trades dans la dernière heure
}

//+------------------------------------------------------------------+
//| Cooldown adaptatif basé sur les conditions de marché            |
//+------------------------------------------------------------------+
int GetAdaptiveCooldownMinutes(int baseCooldown)
{
    if(!ShouldReduceCooldown()) {
        return baseCooldown; // Cooldown normal
    }
    
    // Réduire le cooldown de 50% si conditions favorables
    int adaptiveCooldown = MathMax(1, baseCooldown / 2);
    
    Print("🚀 COOLDOWN ADAPTATIF - Réduit de ", baseCooldown, " à ", adaptiveCooldown, " minutes");
    return adaptiveCooldown;
}

//+------------------------------------------------------------------+
//| Vérifier si on peut trader malgré un cooldown léger              |
//+------------------------------------------------------------------+
bool CanTradeDespiteCooldown()
{
    // Permettre le trading si :
    // 1. Conditions de marché très favorables
    // 2. Performance récente excellente
    // 3. Volatilité élevée (opportunités)
    
    // Vérifier la volatilité
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 10, rates) < 10) return false;
    
    double currentVolatility = CalculateRecentVolatility(rates, 5);
    double historicalVolatility = CalculateRecentVolatility(rates, 10);
    
    // Volatilité élevée = opportunités
    bool highVolatility = (currentVolatility > historicalVolatility * 1.5);
    
    // Vérifier la performance récente
    double performanceScore = CalculatePerformanceScore(
        AccountInfoDouble(ACCOUNT_BALANCE),
        CalculateDailyProfit(),
        CalculateDailyLoss(),
        CalculateWinningTrades(),
        CalculateLosingTrades()
    );
    
    bool goodPerformance = (performanceScore > 60);
    
    // Vérifier les conditions de marché
    bool optimalSession = IsOptimalTradingSession();
    
    return (highVolatility && goodPerformance && optimalSession);
}

//+------------------------------------------------------------------+
//| Fonctions de trading automatique                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Vérifier si le trading automatique est autorisé                 |
//+------------------------------------------------------------------+
bool IsAutoTradingAllowed()
{
    if(!InpEnableAutoTrading) return false;
    
    // Vérifier les limites de trading
    if(!CheckTradingLimits()) return false;
    
    // Vérifier le filtre temporel
    if(InpUseTimeFilter && !IsWithinTradingHours()) return false;
    
    // Vérifier les conditions de marché
    if(!IsMarketConditionsOptimal()) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Vérifier les limites de trading                                 |
//+------------------------------------------------------------------+
bool CheckTradingLimits()
{
    // Vérifier le nombre de trades par heure
    int tradesThisHour = CountTradesInLastHour();
    if(tradesThisHour >= InpMaxTradesPerHour) {
        Print("⚠️ Limite de trades par heure atteinte: ", tradesThisHour, "/", InpMaxTradesPerHour);
        return false;
    }
    
    // Vérifier le nombre d'ordres en attente
    int pendingOrders = CountPendingOrders();
    if(pendingOrders >= InpMaxPendingOrders) {
        Print("⚠️ Limite d'ordres en attente atteinte: ", pendingOrders, "/", InpMaxPendingOrders);
        return false;
    }
    
    // Vérifier le cooldown
    if(g_inCooldown && TimeCurrent() < g_cooldownEndTime) {
        Print("⚠️ Cooldown actif jusqu'à: ", TimeToString(g_cooldownEndTime));
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Vérifier si on est dans les heures de trading                   |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    
    return (time.hour >= InpStartHour && time.hour < InpEndHour);
}

//+------------------------------------------------------------------+
//| Vérifier les conditions de marché optimales                     |
//+------------------------------------------------------------------+
bool IsMarketConditionsOptimal()
{
    // Vérifier le spread
    double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(spread > InpMaxSpreadPoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT)) {
        Print("⚠️ Spread trop élevé: ", DoubleToString(spread, 5));
        return false;
    }
    
    // Vérifier la volatilité
    if(!IsMarketVolatilityOptimal()) {
        Print("⚠️ Volatilité non optimale");
        return false;
    }
    
    // Vérifier la session de trading
    if(!IsOptimalTradingSession()) {
        Print("⚠️ Session de trading non optimale");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Compter les trades de la dernière heure                         |
//+------------------------------------------------------------------+
int CountTradesInLastHour()
{
    int count = 0;
    datetime oneHourAgo = TimeCurrent() - 3600;
    
    if(HistorySelect(oneHourAgo, TimeCurrent())) {
        int totalDeals = HistoryDealsTotal();
        for(int i = 0; i < totalDeals; i++) {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket > 0) {
                if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber) {
                    ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
                    if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) {
                        count++;
                    }
                }
            }
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Compter les ordres en attente                                   |
//+------------------------------------------------------------------+
int CountPendingOrders()
{
    int count = 0;
    for(int i = 0; i < OrdersTotal(); i++) {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0) {
            if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber) {
                ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT ||
                   orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP) {
                    count++;
                }
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Exécuter un ordre direct sur un symbole spécifique              |
//+------------------------------------------------------------------+
bool ExecuteDirectOrderMultiSymbol(string symbol, int direction, double lotSize, double stopLoss, double takeProfit)
{
    if(!InpUseDirectOrders) return false;
    
    CTrade trade;
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(50); // Déviation élevée pour éviter les rejets
    trade.SetTypeFilling(ORDER_FILLING_IOC); // Immediate or Cancel
    
    // Normaliser les prix pour le symbole spécifique
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    stopLoss = NormalizeDouble(stopLoss, digits);
    takeProfit = NormalizeDouble(takeProfit, digits);
    
    // Vérifier les niveaux de stop minimum
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double minStopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    double currentPrice = (direction > 0) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Ajuster SL si trop proche
    if(stopLoss > 0 && MathAbs(currentPrice - stopLoss) < minStopLevel) {
        stopLoss = (direction > 0) ? currentPrice - minStopLevel : currentPrice + minStopLevel;
        stopLoss = NormalizeDouble(stopLoss, digits);
    }
    
    // Ajuster TP si trop proche
    if(takeProfit > 0 && MathAbs(currentPrice - takeProfit) < minStopLevel) {
        takeProfit = (direction > 0) ? currentPrice + minStopLevel : currentPrice - minStopLevel;
        takeProfit = NormalizeDouble(takeProfit, digits);
    }
    
    // Vérifier que les SL/TP sont valides
    if(stopLoss > 0 && takeProfit > 0) {
        if(direction > 0 && (stopLoss >= currentPrice || takeProfit <= currentPrice)) {
            Print("❌ SL/TP invalides pour BUY - SL: ", DoubleToString(stopLoss, 5), " TP: ", DoubleToString(takeProfit, 5), " Prix: ", DoubleToString(currentPrice, 5));
            return false;
        }
        if(direction < 0 && (stopLoss <= currentPrice || takeProfit >= currentPrice)) {
            Print("❌ SL/TP invalides pour SELL - SL: ", DoubleToString(stopLoss, 5), " TP: ", DoubleToString(takeProfit, 5), " Prix: ", DoubleToString(currentPrice, 5));
            return false;
        }
    }
    
    bool result = false;
    string comment = "Multi " + (direction > 0 ? "BUY" : "SELL") + " " + symbol;
    
    if(direction > 0) {
        result = trade.Buy(lotSize, symbol, 0, stopLoss, takeProfit, comment);
    } else {
        result = trade.Sell(lotSize, symbol, 0, stopLoss, takeProfit, comment);
    }
    
    if(result) {
        Print("✅ Trade exécuté sur ", symbol, " - ", (direction > 0 ? "BUY" : "SELL"), 
              " Lot: ", DoubleToString(lotSize, 2),
              " SL: ", DoubleToString(stopLoss, 5), 
              " TP: ", DoubleToString(takeProfit, 5));
        return true;
    } else {
        Print("❌ Échec trade sur ", symbol, " - Code: ", trade.ResultRetcode());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Exécuter un ordre direct (market) - Version originale           |
//+------------------------------------------------------------------+
bool ExecuteDirectOrder(int direction, double lotSize, double stopLoss, double takeProfit)
{
    return ExecuteDirectOrderMultiSymbol(_Symbol, direction, lotSize, stopLoss, takeProfit);
}

//+------------------------------------------------------------------+
//| Exécuter un ordre limit                                         |
//+------------------------------------------------------------------+
bool ExecuteLimitOrder(int direction, double lotSize, double price, double stopLoss, double takeProfit)
{
    if(!InpUseLimitOrders) return false;
    
    // Vérifier le nombre de positions ouvertes (max 2)
    int openPositions = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            openPositions++;
        }
    }
    
    if(openPositions >= 2) {
        Print("⚠️ Limite de 2 positions atteinte - Trade bloqué");
        return false;
    }
    
    CTrade trade;
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(20);
    
    // Normaliser les prix
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    price = NormalizeDouble(price, digits);
    stopLoss = NormalizeDouble(stopLoss, digits);
    takeProfit = NormalizeDouble(takeProfit, digits);
    
    // Vérifier les niveaux de prix
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    if(stopLoss > 0 && MathAbs(price - stopLoss) < minStopLevel) {
        stopLoss = (direction > 0) ? price - minStopLevel : price + minStopLevel;
        stopLoss = NormalizeDouble(stopLoss, digits);
    }
    if(takeProfit > 0 && MathAbs(price - takeProfit) < minStopLevel) {
        takeProfit = (direction > 0) ? price + minStopLevel : price - minStopLevel;
        takeProfit = NormalizeDouble(takeProfit, digits);
    }
    
    bool result = false;
    string comment = "Auto Limit " + (direction > 0 ? "BUY" : "SELL");
    datetime expiration = TimeCurrent() + 3600; // Expiration dans 1 heure
    
    if(direction > 0) {
        result = trade.BuyLimit(lotSize, price, _Symbol, stopLoss, takeProfit, ORDER_TIME_SPECIFIED, expiration, comment);
    } else {
        result = trade.SellLimit(lotSize, price, _Symbol, stopLoss, takeProfit, ORDER_TIME_SPECIFIED, expiration, comment);
    }
    
    if(result) {
        Print("✅ Ordre limit placé - Direction: ", (direction > 0 ? "BUY" : "SELL"), 
              " Prix: ", DoubleToString(price, 5), " Volume: ", DoubleToString(lotSize, 2),
              " SL: ", DoubleToString(stopLoss, 5), " TP: ", DoubleToString(takeProfit, 5));
        g_pendingOrdersCount++;
        g_lastOrderTime = TimeCurrent();
        return true;
    } else {
        Print("❌ Échec ordre limit - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Calculer la taille de lot intelligente                          |
//+------------------------------------------------------------------+
double CalculateSmartLotSize(double stopLossDistance)
{
    if(!InpUseSmartSizing) return InpLotSize;
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * InpRiskPerTrade;
    
    // Calculer la taille de lot basée sur le risque
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickValue > 0 && tickSize > 0 && stopLossDistance > 0) {
        double stopLossInTicks = stopLossDistance / tickSize;
        double lotSize = riskAmount / (stopLossInTicks * tickValue);
        
        // Normaliser la taille de lot
        double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        
        lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
        lotSize = MathRound(lotSize / lotStep) * lotStep;
        
        return lotSize;
    }
    
    return InpLotSize;
}

//+------------------------------------------------------------------+
//| Gérer le trailing stop                                          |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    if(!InpUseTrailingStop) return;
    
    CTrade trade; // Déclaration du CTrade au niveau de la fonction
    
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                                    SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                    SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentSL = PositionGetDouble(POSITION_SL);
                double profit = PositionGetDouble(POSITION_PROFIT);
                
                // Vérifier si on doit passer en break-even
                if(InpUseBreakEven && profit > 0 && currentSL < openPrice) {
                    double triggerDistance = InpBreakEvenTrigger;
                    if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && 
                        currentPrice >= openPrice + triggerDistance) ||
                       (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && 
                        currentPrice <= openPrice - triggerDistance)) {
                        
                        trade.PositionModify(ticket, openPrice, PositionGetDouble(POSITION_TP));
                        Print("✅ Position passée en break-even - Ticket: ", ticket);
                    }
                }
                
                // Gérer le trailing stop
                double newSL = 0;
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                    newSL = currentPrice - InpTrailingStopDistance;
                    if(newSL > currentSL + InpTrailingStep) {
                        trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
                        Print("✅ Trailing stop mis à jour - Ticket: ", ticket, " Nouveau SL: ", DoubleToString(newSL, 5));
                    }
                } else {
                    newSL = currentPrice + InpTrailingStopDistance;
                    if(newSL < currentSL - InpTrailingStep) {
                        trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
                        Print("✅ Trailing stop mis à jour - Ticket: ", ticket, " Nouveau SL: ", DoubleToString(newSL, 5));
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Détection de signal ULTRA SIMPLE pour un symbole spécifique     |
//+------------------------------------------------------------------+
int DetectUltraSimpleSignal(string symbol)
{
    // Obtenir les données de marché pour le symbole spécifique
    MqlRates rates[];
    if(CopyRates(symbol, PERIOD_CURRENT, 0, 3, rates) < 3) return 0;
    
    // Analyser seulement les 2 dernières bougies
    double currentClose = rates[0].close;
    double currentOpen = rates[0].open;
    double prevClose = rates[1].close;
    double prevOpen = rates[1].open;
    
    // Calculer la tendance simple
    bool currentBullish = currentClose > currentOpen;
    bool prevBullish = prevClose > prevOpen;
    
    // Signal d'achat : 2 bougies haussières consécutives
    if(currentBullish && prevBullish) {
        return 1; // BUY
    }
    
    // Signal de vente : 2 bougies baissières consécutives
    if(!currentBullish && !prevBullish) {
        return -1; // SELL
    }
    
    return 0; // Pas de signal
}

//+------------------------------------------------------------------+
//| Obtenir la distance SL adaptée au symbole                       |
//+------------------------------------------------------------------+
double GetSLDistance(string symbol)
{
    if(StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "CRASH") >= 0) {
        return 0.5; // 0.5 points pour Boom/Crash
    } else if(StringFind(symbol, "VOLATILITY") >= 0) {
        return 0.1; // 0.1 points pour Volatility
    }
    return 0.0010; // 10 pips par défaut
}

//+------------------------------------------------------------------+
//| Obtenir la distance TP adaptée au symbole                       |
//+------------------------------------------------------------------+
double GetTPDistance(string symbol)
{
    if(StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "CRASH") >= 0) {
        return 1.0; // 1.0 points pour Boom/Crash
    } else if(StringFind(symbol, "VOLATILITY") >= 0) {
        return 0.2; // 0.2 points pour Volatility
    }
    return 0.0020; // 20 pips par défaut
}

//+------------------------------------------------------------------+
//| Obtenir la taille de lot adaptée au symbole                     |
//+------------------------------------------------------------------+
double GetLotSizeForSymbol(string symbol)
{
    if(StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "CRASH") >= 0) {
        return 0.1; // Lot plus petit pour Boom/Crash
    } else if(StringFind(symbol, "VOLATILITY") >= 0) {
        return 0.05; // Lot encore plus petit pour Volatility
    }
    return InpLotSize; // Lot normal pour les autres symboles
}


//+------------------------------------------------------------------+
//| Obtenir le seuil de profit adapté au symbole                    |
//+------------------------------------------------------------------+
double GetProfitThreshold(string symbol)
{
    if(StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "CRASH") >= 0) {
        return 0.5; // 0.5 unités pour Boom/Crash
    } else if(StringFind(symbol, "VOLATILITY") >= 0) {
        return 0.2; // 0.2 unités pour Volatility
    }
    return 2.0; // 2 unités par défaut
}

//+------------------------------------------------------------------+
//| Gérer le trailing stop sur tous les symboles                    |
//+------------------------------------------------------------------+
void ManageTrailingStopMultiSymbol()
{
    if(!InpUseTrailingStop) return;
    
    CTrade trade;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                string symbol = PositionGetString(POSITION_SYMBOL);
                double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                                    SymbolInfoDouble(symbol, SYMBOL_BID) : 
                                    SymbolInfoDouble(symbol, SYMBOL_ASK);
                
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentSL = PositionGetDouble(POSITION_SL);
                double profit = PositionGetDouble(POSITION_PROFIT);
                
                // Vérifier si on doit passer en break-even
                if(InpUseBreakEven && profit > 0 && currentSL < openPrice) {
                    double triggerDistance = GetBreakEvenTrigger(symbol);
                    if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && 
                        currentPrice >= openPrice + triggerDistance) ||
                       (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && 
                        currentPrice <= openPrice - triggerDistance)) {
                        
                        trade.PositionModify(ticket, openPrice, PositionGetDouble(POSITION_TP));
                        Print("✅ Position passée en break-even sur ", symbol, " - Ticket: ", ticket);
                    }
                }
                
                // Gérer le trailing stop
                double newSL = 0;
                double trailingDistance = GetTrailingDistance(symbol);
                double trailingStep = GetTrailingStep(symbol);
                
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                    newSL = currentPrice - trailingDistance;
                    if(newSL > currentSL + trailingStep) {
                        trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
                        Print("✅ Trailing stop mis à jour sur ", symbol, " - Ticket: ", ticket, " Nouveau SL: ", DoubleToString(newSL, 5));
                    }
                } else {
                    newSL = currentPrice + trailingDistance;
                    if(newSL < currentSL - trailingStep) {
                        trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
                        Print("✅ Trailing stop mis à jour sur ", symbol, " - Ticket: ", ticket, " Nouveau SL: ", DoubleToString(newSL, 5));
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Obtenir le déclencheur break-even adapté au symbole             |
//+------------------------------------------------------------------+
double GetBreakEvenTrigger(string symbol)
{
    if(StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "CRASH") >= 0) {
        return 0.1; // 0.1 points pour Boom/Crash
    } else if(StringFind(symbol, "VOLATILITY") >= 0) {
        return 0.05; // 0.05 points pour Volatility
    }
    return InpBreakEvenTrigger; // Valeur par défaut
}

//+------------------------------------------------------------------+
//| Obtenir la distance trailing adaptée au symbole                 |
//+------------------------------------------------------------------+
double GetTrailingDistance(string symbol)
{
    if(StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "CRASH") >= 0) {
        return 0.2; // 0.2 points pour Boom/Crash
    } else if(StringFind(symbol, "VOLATILITY") >= 0) {
        return 0.05; // 0.05 points pour Volatility
    }
    return InpTrailingStopDistance; // Valeur par défaut
}

//+------------------------------------------------------------------+
//| Obtenir le pas trailing adapté au symbole                       |
//+------------------------------------------------------------------+
double GetTrailingStep(string symbol)
{
    if(StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "CRASH") >= 0) {
        return 0.1; // 0.1 points pour Boom/Crash
    } else if(StringFind(symbol, "VOLATILITY") >= 0) {
        return 0.02; // 0.02 points pour Volatility
    }
    return InpTrailingStep; // Valeur par défaut
}

//+------------------------------------------------------------------+
//| Nettoyer les ordres expirés                                     |
//+------------------------------------------------------------------+
void CleanExpiredOrders()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0) {
            if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber) {
                datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
                if(expiration > 0 && TimeCurrent() > expiration) {
                    CTrade trade;
                    if(trade.OrderDelete(ticket)) {
                        Print("✅ Ordre expiré supprimé - Ticket: ", ticket);
                        g_pendingOrdersCount--;
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Variables globales pour la gestion des pertes                    |
//+------------------------------------------------------------------+
struct LossTracker {
    double totalLossPerSymbol[10]; // Max 10 symboles
    string symbols[10];
    int symbolCount;
};

LossTracker g_lossTracker = {{0}, {""}, 0};

//+------------------------------------------------------------------+
//| Fonction principale de trading automatique OPTIMISÉE             |
//+------------------------------------------------------------------+
void ExecuteAutoTrading()
{
    // Vérifications de base
    if(!InpEnableAutoTrading) return;
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return;
    
    // Nettoyer les ordres expirés
    CleanExpiredOrders();
    
    // Gérer le trailing stop sur tous les symboles
    ManageTrailingStopMultiSymbol();
    
    // Fermer automatiquement les positions après gain sur tous les symboles
    AutoCloseProfitablePositionsMultiSymbol();
    
    // Détecter et fermer après les spikes
    ClosePositionsAfterSpikes();
    
    // Gérer les pertes et fermer si nécessaire
    ManageLossLimits();
    
    // Pause après pertes consécutives supprimée - Trading libre
    
    // Cooldown supprimé pour permettre plus d'activité de trading
    
    // Trader sur TOUS les symboles disponibles (dynamique) - UN SEUL ORDRE À LA FOIS
    string symbols[] = {"BOOM500", "CRASH500", "VOLATILITY75", "VOLATILITY100", "VOLATILITY50", "BOOM1000", "CRASH1000"};
    
    // Variable pour s'assurer qu'un seul ordre est exécuté
    bool orderExecuted = false;
    
    for(int s = 0; s < ArraySize(symbols) && !orderExecuted; s++) {
        string symbol = symbols[s];
        
        // Vérifier si le symbole est disponible
        if(!SymbolSelect(symbol, true)) continue;
        
        // Vérifier les pertes pour ce symbole (max 3.5$)
        if(GetSymbolLoss(symbol) >= 3.5) {
            Print("⚠️ Limite de perte atteinte pour ", symbol, " - Perte: $", DoubleToString(GetSymbolLoss(symbol), 2));
            continue;
        }
        
        // Vérifier le nombre de positions pour ce symbole (max 2)
        int symbolPositions = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                if(PositionGetString(POSITION_SYMBOL) == symbol) {
                    symbolPositions++;
                }
            }
        }
        
        if(symbolPositions >= 2) continue; // Limite atteinte pour ce symbole
        
        // Détection de signal OPTIMISÉE avec DYNAMIC PATTERN ARROW
        int direction = DetectAdvancedSignalWithPattern(symbol);
        if(direction == 0) continue;
        
        double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
        
        // SL/TP OPTIMISÉS avec ratio risque/récompense amélioré
        double slDistance = GetOptimalSLDistance(symbol);
        double tpDistance = GetOptimalTPDistance(symbol);
        
        double stopLoss = 0, takeProfit = 0;
        if(direction > 0) {
            stopLoss = currentPrice - slDistance;
            takeProfit = currentPrice + tpDistance;
        } else {
            stopLoss = currentPrice + slDistance;
            takeProfit = currentPrice - tpDistance;
        }
        
        // Taille de lot OPTIMISÉE
        double lotSize = GetOptimalLotSize(symbol);
        
        // Exécuter UN SEUL ordre avec gestion d'erreurs améliorée
        if(InpUseDirectOrders) {
            Print("🚀 SIGNAL DÉTECTÉ - ", symbol, " Direction: ", (direction > 0 ? "BUY" : "SELL"), 
                  " Prix: ", DoubleToString(currentPrice, 5), 
                  " SL: ", DoubleToString(stopLoss, 5), 
                  " TP: ", DoubleToString(takeProfit, 5),
                  " Lot: ", DoubleToString(lotSize, 2));
            
            bool result = ExecuteDirectOrderMultiSymbol(symbol, direction, lotSize, stopLoss, takeProfit);
            if(result) {
                orderExecuted = true; // Marquer qu'un ordre a été exécuté
                Print("✅ Trade exécuté sur ", symbol, " - Direction: ", (direction > 0 ? "BUY" : "SELL"), 
                      " Prix: ", DoubleToString(currentPrice, 5),
                      " SL: ", DoubleToString(stopLoss, 5), 
                      " TP: ", DoubleToString(takeProfit, 5));
                Print("🛡️ UN SEUL ORDRE EXÉCUTÉ - Arrêt du scan pour éviter les risques");
            } else {
                Print("❌ Échec exécution sur ", symbol, " - Direction: ", (direction > 0 ? "BUY" : "SELL"));
            }
        }
    }
    
    // Message si aucun ordre n'a été exécuté
    if(!orderExecuted) {
        static int noSignalCount = 0;
        noSignalCount++;
        if(noSignalCount % 10 == 0) { // Afficher tous les 10 ticks
            Print("🔍 Scan terminé - Aucun signal valide trouvé sur tous les symboles");
        }
    }
}

//+------------------------------------------------------------------+
//| Gérer les limites de perte par symbole                          |
//+------------------------------------------------------------------+
void ManageLossLimits()
{
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            string symbol = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            // Si la perte dépasse 3.5$ pour ce symbole, fermer la position
            if(profit <= -3.5) {
                CTrade trade;
                if(trade.PositionClose(PositionGetTicket(i))) {
                    Print("🚨 Position fermée - Limite de perte atteinte sur ", symbol, 
                          " - Perte: $", DoubleToString(profit, 2));
                    
                    // Mettre à jour le tracker de pertes
                    UpdateLossTracker(symbol, profit);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Obtenir la perte totale pour un symbole                         |
//+------------------------------------------------------------------+
double GetSymbolLoss(string symbol)
{
    double totalLoss = 0.0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            if(PositionGetString(POSITION_SYMBOL) == symbol) {
                double profit = PositionGetDouble(POSITION_PROFIT);
                if(profit < 0) {
                    totalLoss += MathAbs(profit);
                }
            }
        }
    }
    return totalLoss;
}

//+------------------------------------------------------------------+
//| Mettre à jour le tracker de pertes                              |
//+------------------------------------------------------------------+
void UpdateLossTracker(string symbol, double loss)
{
    if(loss < 0) {
        // Trouver ou ajouter le symbole dans le tracker
        int symbolIndex = -1;
        for(int i = 0; i < g_lossTracker.symbolCount; i++) {
            if(g_lossTracker.symbols[i] == symbol) {
                symbolIndex = i;
                break;
            }
        }
        
        if(symbolIndex == -1 && g_lossTracker.symbolCount < 10) {
            symbolIndex = g_lossTracker.symbolCount;
            g_lossTracker.symbols[symbolIndex] = symbol;
            g_lossTracker.symbolCount++;
        }
        
        if(symbolIndex >= 0) {
            g_lossTracker.totalLossPerSymbol[symbolIndex] += MathAbs(loss);
        }
        
        Print("📊 Perte enregistrée sur ", symbol, ": $", DoubleToString(MathAbs(loss), 2), 
              " - Total: $", DoubleToString(g_lossTracker.totalLossPerSymbol[symbolIndex], 2));
    }
}

//+------------------------------------------------------------------+
//| Détection de signal avancée avec DYNAMIC PATTERN ARROW          |
//+------------------------------------------------------------------+
int DetectAdvancedSignalWithPattern(string symbol)
{
    // Obtenir les données de marché
    MqlRates rates[];
    if(CopyRates(symbol, PERIOD_CURRENT, 0, 5, rates) < 5) return 0;
    
    // Analyser les patterns de bougies
    int signal = 0;
    
    // 1. Pattern de continuation (2 bougies consécutives dans la même direction)
    bool bullishContinuation = (rates[0].close > rates[0].open) && (rates[1].close > rates[1].open);
    bool bearishContinuation = (rates[0].close < rates[0].open) && (rates[1].close < rates[1].open);
    
    // 2. Pattern de retournement (Hammer/Shooting Star)
    bool hammer = IsHammerPattern(rates[0]);
    bool shootingStar = IsShootingStarPattern(rates[0]);
    
    // 3. Pattern Engulfing
    bool bullishEngulfing = IsBullishEngulfing(rates[0], rates[1]);
    bool bearishEngulfing = IsBearishEngulfing(rates[0], rates[1]);
    
    // 4. Pattern Doji (retournement)
    bool doji = IsDojiPattern(rates[0]);
    
    // 5. Analyse de volume et momentum
    double momentum = rates[0].close - rates[2].close;
    double volatility = CalculateVolatility(symbol, rates);
    
    // Calculer le score de confiance
    double confidence = 0.0;
    
    if(bullishContinuation && momentum > 0) {
        confidence += 0.3;
        signal = 1; // BUY
    }
    if(bearishContinuation && momentum < 0) {
        confidence += 0.3;
        signal = -1; // SELL
    }
    
    if(hammer && momentum > 0) {
        confidence += 0.4;
        signal = 1; // BUY
    }
    if(shootingStar && momentum < 0) {
        confidence += 0.4;
        signal = -1; // SELL
    }
    
    if(bullishEngulfing) {
        confidence += 0.5;
        signal = 1; // BUY
    }
    if(bearishEngulfing) {
        confidence += 0.5;
        signal = -1; // SELL
    }
    
    if(doji) {
        confidence += 0.2;
        // Signal de retournement basé sur la tendance précédente
        if(rates[1].close > rates[1].open) {
            signal = -1; // SELL (retournement baissier)
        } else {
            signal = 1; // BUY (retournement haussier)
        }
    }
    
    // Ajuster selon la volatilité
    if(volatility > 0.5) {
        confidence *= 1.2; // Augmenter la confiance en période de forte volatilité
    }
    
    // Seuil de confiance minimum
    if(confidence < 0.6) {
        return 0; // Signal trop faible
    }
    
    Print("🎯 DYNAMIC PATTERN ARROW - ", symbol, " Signal: ", (signal > 0 ? "BUY" : "SELL"), 
          " Confiance: ", DoubleToString(confidence * 100, 1), "%");
    
    return signal;
}

//+------------------------------------------------------------------+
//| Détecter le pattern Hammer                                      |
//+------------------------------------------------------------------+
bool IsHammerPattern(MqlRates &candle)
{
    double body = MathAbs(candle.close - candle.open);
    double lowerShadow = MathMin(candle.open, candle.close) - candle.low;
    double upperShadow = candle.high - MathMax(candle.open, candle.close);
    
    return (lowerShadow > body * 2) && (upperShadow < body * 0.5);
}

//+------------------------------------------------------------------+
//| Détecter le pattern Shooting Star                               |
//+------------------------------------------------------------------+
bool IsShootingStarPattern(MqlRates &candle)
{
    double body = MathAbs(candle.close - candle.open);
    double lowerShadow = MathMin(candle.open, candle.close) - candle.low;
    double upperShadow = candle.high - MathMax(candle.open, candle.close);
    
    return (upperShadow > body * 2) && (lowerShadow < body * 0.5);
}

//+------------------------------------------------------------------+
//| Détecter le pattern Bullish Engulfing                           |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(MqlRates &current, MqlRates &previous)
{
    return (previous.close < previous.open) && // Bougie précédente baissière
           (current.close > current.open) &&   // Bougie actuelle haussière
           (current.open < previous.close) &&  // Ouverture sous la clôture précédente
           (current.close > previous.open);   // Clôture au-dessus de l'ouverture précédente
}

//+------------------------------------------------------------------+
//| Détecter le pattern Bearish Engulfing                           |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(MqlRates &current, MqlRates &previous)
{
    return (previous.close > previous.open) && // Bougie précédente haussière
           (current.close < current.open) &&   // Bougie actuelle baissière
           (current.open > previous.close) &&  // Ouverture au-dessus de la clôture précédente
           (current.close < previous.open);    // Clôture sous l'ouverture précédente
}

//+------------------------------------------------------------------+
//| Détecter le pattern Doji                                        |
//+------------------------------------------------------------------+
bool IsDojiPattern(MqlRates &candle)
{
    double body = MathAbs(candle.close - candle.open);
    double range = candle.high - candle.low;
    
    return (body < range * 0.1); // Corps très petit par rapport à la range
}

//+------------------------------------------------------------------+
//| Calculer la volatilité                                          |
//+------------------------------------------------------------------+
double CalculateVolatility(string symbol, MqlRates &rates[])
{
    double sum = 0.0;
    for(int i = 0; i < 5; i++) {
        sum += (rates[i].high - rates[i].low) / rates[i].close;
    }
    return sum / 5.0;
}

//+------------------------------------------------------------------+
//| Obtenir la distance SL optimale                                 |
//+------------------------------------------------------------------+
double GetOptimalSLDistance(string symbol)
{
    if(StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "CRASH") >= 0) {
        return 0.15; // 0.15 points pour Boom/Crash (plus serré)
    } else if(StringFind(symbol, "VOLATILITY") >= 0) {
        return 0.03; // 0.03 points pour Volatility (plus serré)
    }
    return 0.1; // Valeur par défaut
}

//+------------------------------------------------------------------+
//| Obtenir la distance TP optimale                                 |
//+------------------------------------------------------------------+
double GetOptimalTPDistance(string symbol)
{
    if(StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "CRASH") >= 0) {
        return 0.30; // 0.30 points pour Boom/Crash (ratio 1:2)
    } else if(StringFind(symbol, "VOLATILITY") >= 0) {
        return 0.06; // 0.06 points pour Volatility (ratio 1:2)
    }
    return 0.2; // Valeur par défaut
}

//+------------------------------------------------------------------+
//| Obtenir la taille de lot optimale                               |
//+------------------------------------------------------------------+
double GetOptimalLotSize(string symbol)
{
    double baseLot = InpLotSize;
    
    // Ajuster selon le symbole
    if(StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "CRASH") >= 0) {
        return baseLot * 1.2; // Légèrement plus gros pour Boom/Crash
    } else if(StringFind(symbol, "VOLATILITY") >= 0) {
        return baseLot * 0.8; // Plus petit pour Volatility
    }
    
    return baseLot;
}

//+------------------------------------------------------------------+
//| Détecter les spikes et clôturer les positions                   |
//+------------------------------------------------------------------+
void ClosePositionsAfterSpikes()
{
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            string symbol = PositionGetString(POSITION_SYMBOL);
            ulong ticket = PositionGetTicket(i);
            
            // Détecter les spikes sur ce symbole
            if(DetectSpikeOnSymbol(symbol)) {
                CTrade trade;
                if(trade.PositionClose(ticket)) {
                    Print("⚡ Position fermée après SPIKE détecté sur ", symbol, " - Ticket: ", ticket);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Détecter un spike sur un symbole                                |
//+------------------------------------------------------------------+
bool DetectSpikeOnSymbol(string symbol)
{
    MqlRates rates[];
    if(CopyRates(symbol, PERIOD_CURRENT, 0, 3, rates) < 3) return false;
    
    // Calculer la volatilité récente
    double currentVolatility = (rates[0].high - rates[0].low) / rates[0].close;
    double avgVolatility = 0.0;
    
    for(int i = 1; i < 3; i++) {
        avgVolatility += (rates[i].high - rates[i].low) / rates[i].close;
    }
    avgVolatility /= 2.0;
    
    // Détecter un spike si la volatilité actuelle est 2x supérieure à la moyenne
    bool isSpike = currentVolatility > (avgVolatility * 2.0);
    
    if(isSpike) {
        Print("⚡ SPIKE DÉTECTÉ sur ", symbol, " - Volatilité: ", DoubleToString(currentVolatility * 100, 2), 
              "% vs Moyenne: ", DoubleToString(avgVolatility * 100, 2), "%");
    }
    
    return isSpike;
}

//+------------------------------------------------------------------+
//| Améliorer la fonction AutoCloseProfitablePositionsMultiSymbol   |
//+------------------------------------------------------------------+
void AutoCloseProfitablePositionsMultiSymbol()
{
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            string symbol = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            double profitThreshold = GetProfitThreshold(symbol);
            
            // Fermer si profit atteint OU si spike détecté
            if(profit >= profitThreshold || DetectSpikeOnSymbol(symbol)) {
                CTrade trade;
                if(trade.PositionClose(PositionGetTicket(i))) {
                    string reason = (profit >= profitThreshold) ? "Profit atteint" : "Spike détecté";
                    Print("✅ Position fermée - ", reason, " sur ", symbol, 
                          " - Profit: $", DoubleToString(profit, 2));
                }
            }
        }
    }
}
