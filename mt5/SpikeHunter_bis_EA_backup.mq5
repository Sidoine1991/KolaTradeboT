//+------------------------------------------------------------------+
//|                                        SpikeHunter_Simple_EA.mq5 |
//|                        Copyright 2025, TradBOT Spike Hunter EA   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, TradBOT Spike Hunter EA"
#property link      "https://www.mql5.com"
#property version   "1.01"
#property description "Robot de trading automatique pour capturer les spikes Boom/Crash - Version Simplifiée"

//--- Paramètres d'entrée
input group "=== CONFIGURATION GÉNÉRALE ==="
input bool     InpEnableTrading = true;           // Activer le trading
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M1;   // Timeframe d'analyse
input int      InpMagicNumber = 123456;           // Magic Number

input group "=== CONFIGURATION BOOM/CRASH ==="
input bool     InpTradeBoom = true;               // Trader Boom Index
input bool     InpTradeCrash = true;              // Trader Crash Index
input int      InpMaxTrades = 3;                  // Nombre max de trades simultanés
input double   InpLotSize = 0.01;                 // Taille des lots
input int      InpStopLoss = 50;                  // Stop Loss en points
input int      InpTakeProfit = 150;               // Take Profit en points

input group "=== DÉTECTION DE SPIKE ==="
input double   InpSpikeThreshold = 0.5;           // Seuil de spike (%)
input int      InpMinSpikeInterval = 10;          // Intervalle minimum entre spikes (secondes)

input group "=== TRAILING STOP ==="
input bool     InpUseTrailing = true;             // Utiliser le trailing stop
input int      InpTrailingStart = 30;             // Distance de démarrage trailing (points)
input int      InpTrailingStep = 10;              // Pas du trailing stop (points)

input group "=== NOTIFICATIONS ==="
input bool     InpSendNotifications = true;       // Envoyer des notifications

//--- Variables globales
int ma_handle;
int rsi_handle;
double ma_buffer[];
double rsi_buffer[];

//--- Structures pour les trades
struct TradeInfo {
    ulong ticket;
    datetime open_time;
    double open_price;
    double lot_size;
    int direction; // 1 = BUY, -1 = SELL
    bool is_spike_trade;
    double spike_start_price;
};

TradeInfo active_trades[]; // dynamic array
int trade_count = 0;

//--- Variables de suivi
double last_boom_price = 0;
double last_crash_price = 0;
datetime last_spike_time = 0;
bool spike_detected = false;
int spike_direction = 0; // 1 = Boom spike, -1 = Crash spike

//--- Variables pour la prédiction de spikes
struct SpikePrediction {
    datetime predicted_time;
    int predicted_direction; // 1 = Boom, -1 = Crash
    double confidence;
    int duration_seconds;
    bool is_active;
    string reason;
};

SpikePrediction current_prediction;
datetime last_prediction_time = 0;
int total_predictions = 0;
int successful_predictions = 0;

//--- Historique des prix pour l'analyse prédictive
double price_history[50];
int history_index = 0;
datetime last_history_update = 0;

//--- Structures pour les supports et résistances
struct SupportResistance {
    double level;
    int strength; // 1-5 (nombre de touches)
    datetime last_touch;
    bool is_support; // true = support, false = résistance
    bool is_confirmed; // confirmé si strength >= 3
    string name;
};

SupportResistance support_levels[20];
SupportResistance resistance_levels[20];
int support_count = 0;
int resistance_count = 0;

//--- Structures pour les trendlines
struct TrendLine {
    double start_price;
    double end_price;
    datetime start_time;
    datetime end_time;
    double slope;
    bool is_uptrend; // true = haussier, false = baissier
    bool is_confirmed; // confirmé si plusieurs touches
    string name;
};

TrendLine trendlines[10];
int trendline_count = 0;

//--- Variables pour la détection des niveaux
datetime last_level_detection = 0;
double last_high = 0;
double last_low = 0;
datetime last_high_time = 0;
datetime last_low_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Vérification des paramètres
    if(InpMaxTrades <= 0) {
        Print("ERREUR: Nombre maximum de trades doit être > 0");
        return INIT_PARAMETERS_INCORRECT;
    }

    if(InpLotSize <= 0) {
        Print("ERREUR: Taille des lots doit être > 0");
        return INIT_PARAMETERS_INCORRECT;
    }

    //--- Initialisation des indicateurs
    ma_handle = iMA(_Symbol, InpTimeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
    if(ma_handle == INVALID_HANDLE) {
        Print("ERREUR: Impossible de créer l'indicateur MA");
        return INIT_FAILED;
    }

    rsi_handle = iRSI(_Symbol, InpTimeframe, 14, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) {
        Print("ERREUR: Impossible de créer l'indicateur RSI");
        return INIT_FAILED;
    }

    //--- Initialisation des buffers
    ArraySetAsSeries(ma_buffer, true);
    ArraySetAsSeries(rsi_buffer, true);

    //--- Initialisation du tableau des trades
    ArrayResize(active_trades, InpMaxTrades);
    for(int i = 0; i < InpMaxTrades; i++) {
        active_trades[i].ticket = 0;
        active_trades[i].open_time = 0;
        active_trades[i].open_price = 0.0;
        active_trades[i].lot_size = 0.0;
        active_trades[i].direction = 0;
        active_trades[i].is_spike_trade = false;
        active_trades[i].spike_start_price = 0.0;
    }

    //--- Initialisation des variables de prédiction
    current_prediction.predicted_time = 0;
    current_prediction.predicted_direction = 0;
    current_prediction.confidence = 0.0;
    current_prediction.duration_seconds = 0;
    current_prediction.is_active = false;
    current_prediction.reason = "";
    last_prediction_time = 0;
    total_predictions = 0;
    successful_predictions = 0;

    //--- Initialisation de l'historique des prix
    ArrayInitialize(price_history, 0);
    history_index = 0;
    last_history_update = 0;

    //--- Activer le timer pour rafraîchir l'affichage
    EventSetTimer(1);

    //--- Initialisation des supports et résistances
    for(int i = 0; i < 20; i++) {
        support_levels[i].level = 0;
        support_levels[i].strength = 0;
        support_levels[i].last_touch = 0;
        support_levels[i].is_support = true;
        support_levels[i].is_confirmed = false;
        support_levels[i].name = "";
        
        resistance_levels[i].level = 0;
        resistance_levels[i].strength = 0;
        resistance_levels[i].last_touch = 0;
        resistance_levels[i].is_support = false;
        resistance_levels[i].is_confirmed = false;
        resistance_levels[i].name = "";
    }
    support_count = 0;
    resistance_count = 0;

    //--- Initialisation des trendlines
    for(int i = 0; i < 10; i++) {
        trendlines[i].start_price = 0;
        trendlines[i].end_price = 0;
        trendlines[i].start_time = 0;
        trendlines[i].end_time = 0;
        trendlines[i].slope = 0;
        trendlines[i].is_uptrend = false;
        trendlines[i].is_confirmed = false;
        trendlines[i].name = "";
    }
    trendline_count = 0;

    //--- Initialisation des variables de détection
    last_level_detection = 0;
    last_high = 0;
    last_low = 0;
    last_high_time = 0;
    last_low_time = 0;

    Print("SpikeHunter Simple EA initialisé avec succès");
    Print("Configuration: Boom=", InpTradeBoom, " Crash=", InpTradeCrash);
    Print("Max Trades: ", InpMaxTrades, " Lot Size: ", InpLotSize);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Arrêter le timer et nettoyer l'affichage/objets
    EventKillTimer();
    ObjectsDeleteAll(0, "SpikePrediction_");
    Comment("");

    //--- Libération des handles
    if(ma_handle != INVALID_HANDLE)
        IndicatorRelease(ma_handle);
    if(rsi_handle != INVALID_HANDLE)
        IndicatorRelease(rsi_handle);

    //--- Nettoyage des variables
    ArrayFree(active_trades);
    ArrayFree(ma_buffer);
    ArrayFree(rsi_buffer);

    Print("SpikeHunter Simple EA arrêté - Raison: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!InpEnableTrading) return;

    //--- Mise à jour des données
    if(!UpdateIndicators()) return;

    //--- Vérification des trades existants
    CheckActiveTrades();

    //--- Mise à jour de l'historique des prix
    UpdatePriceHistory();

    //--- Détection des supports et résistances
    DetectSupportResistance();

    //--- Détection des trendlines
    DetectTrendLines();

    //--- Prédiction de spikes (AVANT qu'ils arrivent)
    PredictSpike();

    //--- Détection de spike (pour validation des prédictions)
    DetectSpike();

    //--- Gestion des ordres
    if(spike_detected) {
        ProcessSpikeSignal();
        spike_detected = false;
    }

    //--- Trailing stop
    if(InpUseTrailing) {
        UpdateTrailingStops();
    }
}

//+------------------------------------------------------------------+
//| Mise à jour des indicateurs                                      |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
    //--- Copie des données des indicateurs
    if(CopyBuffer(ma_handle, 0, 0, 3, ma_buffer) < 0) return false;
    if(CopyBuffer(rsi_handle, 0, 0, 3, rsi_buffer) < 0) return false;

    return true;
}

//+------------------------------------------------------------------+
//| Mise à jour de l'historique des prix                             |
//+------------------------------------------------------------------+
void UpdatePriceHistory()
{
    //--- Mettre à jour seulement toutes les secondes
    if(TimeCurrent() - last_history_update < 1) return;
    last_history_update = TimeCurrent();
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    price_history[history_index] = current_price;
    history_index = (history_index + 1) % 50;
}

//+------------------------------------------------------------------+
//| Prédiction de spikes (ALGORITHME PRÉDICTIF)                      |
//+------------------------------------------------------------------+
void PredictSpike()
{
    //--- Vérifier seulement toutes les 3 secondes pour éviter le spam
    static datetime last_prediction_check = 0;
    if(TimeCurrent() - last_prediction_check < 3) return;
    last_prediction_check = TimeCurrent();
    
    //--- Éviter les prédictions trop fréquentes
    if(TimeCurrent() - last_prediction_time < 30) return;
    
    //--- Analyser les patterns pour prédire les spikes
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    //--- Calculer les indicateurs prédictifs
    double volatility = CalculateVolatility();
    double momentum = CalculateMomentum();
    double trend_strength = CalculateTrendStrength();
    double pressure_build = CalculatePressureBuild();
    double divergence = CalculateDivergence();
    
    //--- Score de prédiction (0-100)
    double prediction_score = 0;
    int predicted_direction = 0;
    string reason = "";
    
    //--- Pattern 1: Accumulation de pression (le plus important)
    if(pressure_build > 0.7) {
        prediction_score += 40;
        predicted_direction = (momentum > 0) ? 1 : -1;
        reason += "Pression élevée ";
    }
    
    //--- Pattern 2: Volatilité croissante + momentum fort
    if(volatility > 0.0005 && MathAbs(momentum) > 0.0003) {
        prediction_score += 30;
        if(predicted_direction == 0) predicted_direction = (momentum > 0) ? 1 : -1;
        reason += "Volatilité+Momentum ";
    }
    
    //--- Pattern 3: Divergence (signal fort)
    if(MathAbs(divergence) > 0.6) {
        prediction_score += 25;
        if(predicted_direction == 0) predicted_direction = (divergence > 0) ? 1 : -1;
        reason += "Divergence ";
    }
    
    //--- Pattern 4: Force de tendance
    if(MathAbs(trend_strength) > 0.4) {
        prediction_score += 20;
        if(predicted_direction == 0) predicted_direction = (trend_strength > 0) ? 1 : -1;
        reason += "Tendance forte ";
    }
    
    //--- Si le score est suffisant pour prédire un spike (80% minimum)
    if(prediction_score >= 80 && predicted_direction != 0) {
        //--- Créer la prédiction - SPIKE DANS 30-90 SECONDES
        int prediction_delay = (int)(30 + (prediction_score - 60) * 1.5); // 30-90 secondes
        current_prediction.predicted_time = TimeCurrent() + prediction_delay;
        current_prediction.predicted_direction = predicted_direction;
        current_prediction.confidence = prediction_score / 100.0;
        current_prediction.duration_seconds = prediction_delay;
        current_prediction.is_active = true;
        current_prediction.reason = reason;
        last_prediction_time = TimeCurrent();
        total_predictions++;
        
        //--- Afficher la prédiction
        string direction_str = (predicted_direction > 0) ? "BOOM" : "CRASH";
        string emoji = (predicted_direction > 0) ? "🚀" : "💥";
        
        Print("🔮 PRÉDICTION SPIKE: ", emoji, " ", direction_str, " dans ", prediction_delay, "s - Score: ", DoubleToString(prediction_score, 1), " - Raison: ", reason);
        
        //--- Alerte sonore et notification
        Alert("⚠️ SPIKE PRÉDIT! " + direction_str + " dans " + IntegerToString(prediction_delay) + " secondes - Score: " + DoubleToString(prediction_score, 1) + "%");
        
        if(InpSendNotifications) {
            SendMyNotification("Spike prédit: " + direction_str + " dans " + IntegerToString(prediction_delay) + "s - Score: " + DoubleToString(prediction_score, 1) + "% - " + reason);
        }
        
        //--- Dessiner la flèche de prédiction
        DrawPredictionArrow();
    }
    
    //--- Vérifier si la prédiction s'est réalisée (et nettoyer après échéance)
    if(current_prediction.is_active && TimeCurrent() >= current_prediction.predicted_time) {
        //--- Vérifier si un spike s'est produit dans la direction prédite
        if(spike_detected && spike_direction == current_prediction.predicted_direction) {
            successful_predictions++;
            Print("✅ PRÉDICTION RÉUSSIE! Direction: ", (spike_direction > 0) ? "BOOM" : "CRASH");
        } else {
            Print("❌ PRÉDICTION ÉCHOUÉE - Aucun spike détecté dans la direction prédite");
        }
        
        //--- Désactiver la prédiction
        current_prediction.is_active = false;
        ObjectsDeleteAll(0, "SpikePrediction_");
    }
}

//+------------------------------------------------------------------+
//| Détection de spike (pour validation des prédictions)             |
//+------------------------------------------------------------------+
void DetectSpike()
{
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double price_change = 0;
    static datetime last_check_time = 0;
    
    //--- Vérifier seulement toutes les secondes pour éviter le spam
    if(TimeCurrent() - last_check_time < 1) return;
    last_check_time = TimeCurrent();

    //--- Calcul du changement de prix
    if(StringFind(_Symbol, "Boom") >= 0) {
        if(last_boom_price > 0) {
            price_change = (current_price - last_boom_price) / last_boom_price * 100;
        }
        last_boom_price = current_price;
    }
    else if(StringFind(_Symbol, "Crash") >= 0) {
        if(last_crash_price > 0) {
            price_change = (last_crash_price - current_price) / last_crash_price * 100;
        }
        last_crash_price = current_price;
    }
    else {
        //--- Pour les autres symboles, utiliser la logique générale
        static double last_price = 0;
        if(last_price > 0) {
            price_change = (current_price - last_price) / last_price * 100;
        }
        last_price = current_price;
    }

    //--- Détection de spike basée sur le changement de prix
    if(MathAbs(price_change) >= InpSpikeThreshold) {
        //--- Éviter les spikes multiples dans un court laps de temps
        if(TimeCurrent() - last_spike_time > InpMinSpikeInterval) {
            spike_detected = true;
            spike_direction = (price_change > 0) ? 1 : -1;
            last_spike_time = TimeCurrent();

            string spike_type = (spike_direction > 0) ? "BOOM" : "CRASH";
            Print("🚀 SPIKE CONFIRMÉ: ", _Symbol, " ", spike_type, " - Changement: ", DoubleToString(price_change, 2), "%");

            //--- Envoi de notification
            if(InpSendNotifications) {
                SendMyNotification("Spike confirmé: " + spike_type + " sur " + _Symbol + " - " + DoubleToString(price_change, 2) + "%");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Traitement du signal de spike                                    |
//+------------------------------------------------------------------+
void ProcessSpikeSignal()
{
    //--- Vérification du nombre de trades actifs
    if(trade_count >= InpMaxTrades) {
        Print("Nombre maximum de trades atteint: ", trade_count);
        return;
    }

    //--- Détermination de la direction du trade
    int trade_direction = 0;
    bool should_trade = false;

    if(StringFind(_Symbol, "Boom") >= 0 && InpTradeBoom) {
        if(spike_direction == 1) { // Spike haussier
            trade_direction = 1; // BUY
            should_trade = true;
        }
    }
    else if(StringFind(_Symbol, "Crash") >= 0 && InpTradeCrash) {
        if(spike_direction == -1) { // Spike baissier
            trade_direction = -1; // SELL
            should_trade = true;
        }
    }

    if(!should_trade) return;

    //--- Ouverture du trade
    OpenTrade(trade_direction);
}

//+------------------------------------------------------------------+
//| Ouverture d'un trade                                             |
//+------------------------------------------------------------------+
void OpenTrade(int direction)
{
    MqlTradeRequest request;
    MqlTradeResult  result;
    ZeroMemory(request);
    ZeroMemory(result);

    //--- Configuration de la requête
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = InpLotSize;
    request.type = (direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.magic = InpMagicNumber;
    request.deviation = 10;
    request.type_filling = ORDER_FILLING_FOK;
    request.comment = "SpikeHunter_" + IntegerToString((int)GetTickCount());

    //--- Prix d'ouverture
    if(direction > 0) {
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    } else {
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    }

    //--- Stop Loss et Take Profit
    if(InpStopLoss > 0) {
        double sl_points = InpStopLoss * _Point;
        request.sl = (direction > 0) ? request.price - sl_points : request.price + sl_points;
    }

    if(InpTakeProfit > 0) {
        double tp_points = InpTakeProfit * _Point;
        request.tp = (direction > 0) ? request.price + tp_points : request.price - tp_points;
    }

    //--- Envoi de l'ordre
    if(OrderSend(request, result)) {
        if(result.retcode == TRADE_RETCODE_DONE) {
            //--- Ajout du trade à la liste
            AddActiveTrade(result.order, direction, request.price, request.volume);

            string direction_str = (direction > 0) ? "BUY" : "SELL";
            Print("TRADE OUVERT: ", direction_str, " ", _Symbol, " Prix: ", DoubleToString(request.price,_Digits), " Lot: ", request.volume);

            //--- Notification
            if(InpSendNotifications) {
                SendMyNotification("Trade ouvert: " + direction_str + " " + _Symbol + " @ " + DoubleToString(request.price, _Digits));
            }
        } else {
            Print("ERREUR ouverture trade: ", result.retcode, " - ", result.comment);
        }
    } else {
        Print("OrderSend() a échoué (bool false)");
    }
}

//+------------------------------------------------------------------+
//| Ajout d'un trade actif                                           |
//+------------------------------------------------------------------+
void AddActiveTrade(ulong ticket, int direction, double price, double volume)
{
    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket == 0) {
            active_trades[i].ticket = ticket;
            active_trades[i].open_time = TimeCurrent();
            active_trades[i].open_price = price;
            active_trades[i].lot_size = volume;
            active_trades[i].direction = direction;
            active_trades[i].is_spike_trade = true;
            active_trades[i].spike_start_price = price;
            trade_count++;
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Vérification des trades actifs                                   |
//+------------------------------------------------------------------+
void CheckActiveTrades()
{
    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket == 0) continue;

        //--- Vérification si le trade existe encore
        if(!PositionSelectByTicket(active_trades[i].ticket)) {
            //--- Trade fermé
            Print("TRADE FERMÉ: ", active_trades[i].ticket);
            if(InpSendNotifications) {
                string direction_str = (active_trades[i].direction > 0) ? "BUY" : "SELL";
                SendMyNotification("Trade fermé: " + direction_str + " " + _Symbol + " Ticket: " + IntegerToString((int)active_trades[i].ticket));
            }

            //--- Suppression du trade
            active_trades[i].ticket = 0;
            trade_count--;
        }
    }
}

//+------------------------------------------------------------------+
//| Mise à jour des trailing stops                                   |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket == 0) continue;

        if(!PositionSelectByTicket(active_trades[i].ticket)) continue;

        double current_price = (active_trades[i].direction > 0) ?
                              SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                              SymbolInfoDouble(_Symbol, SYMBOL_ASK);

        double current_sl = PositionGetDouble(POSITION_SL);
        double open_price = active_trades[i].open_price;

        //--- Calcul de la distance de profit
        double profit_distance = 0;
        if(active_trades[i].direction > 0) {
            profit_distance = current_price - open_price;
        } else {
            profit_distance = open_price - current_price;
        }

        //--- Vérification si le trailing doit commencer
        if(profit_distance >= InpTrailingStart * _Point) {
            double new_sl = 0;
            if(active_trades[i].direction > 0) {
                new_sl = current_price - InpTrailingStep * _Point;
            } else {
                new_sl = current_price + InpTrailingStep * _Point;
            }

            //--- Vérification si le nouveau SL est meilleur
            if((active_trades[i].direction > 0 && new_sl > current_sl) ||
               (active_trades[i].direction < 0 && (current_sl == 0 || new_sl < current_sl))) {

                //--- Modification du SL
                MqlTradeRequest request;
                MqlTradeResult  result;
                ZeroMemory(request);
                ZeroMemory(result);

                request.action = TRADE_ACTION_SLTP;
                request.position = active_trades[i].ticket;
                request.sl = new_sl;
                request.tp = PositionGetDouble(POSITION_TP);

                if(OrderSend(request, result)) {
                    Print("Trailing Stop mis à jour: ", active_trades[i].ticket, " Nouveau SL: ", DoubleToString(new_sl,_Digits));
                } else {
                    Print("OrderSend TRADE_ACTION_SLTP failed");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Fonction de notification                                         |
//+------------------------------------------------------------------+
void SendMyNotification(string message)
{
    //--- Utiliser la notification intégrée
    ::SendNotification(message);

    //--- Log dans le journal
    Print("NOTIFICATION: ", message);
}

//+------------------------------------------------------------------+
//| Fonction de calcul du profit total                               |
//+------------------------------------------------------------------+
double GetTotalProfit()
{
    double total_profit = 0;
    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket == 0) continue;

        if(PositionSelectByTicket(active_trades[i].ticket)) {
            total_profit += PositionGetDouble(POSITION_PROFIT);
        }
    }
    return total_profit;
}

//+------------------------------------------------------------------+
//| Calcul de la volatilité                                           |
//+------------------------------------------------------------------+
double CalculateVolatility()
{
    double volatility = 0;
    int count = 0;
    
    for(int i = 1; i < 20; i++) {
        int idx = (history_index - i + 50) % 50;
        int prev_idx = (history_index - i - 1 + 50) % 50;
        if(price_history[idx] > 0 && price_history[prev_idx] > 0) {
            double change = MathAbs((price_history[idx] - price_history[prev_idx]) / price_history[prev_idx]);
            volatility += change;
            count++;
        }
    }
    
    return (count > 0) ? volatility / count : 0;
}

//+------------------------------------------------------------------+
//| Calcul du momentum                                                |
//+------------------------------------------------------------------+
double CalculateMomentum()
{
    double momentum = 0;
    int count = 0;
    
    for(int i = 1; i < 15; i++) {
        int idx = (history_index - i + 50) % 50;
        int prev_idx = (history_index - i - 1 + 50) % 50;
        if(price_history[idx] > 0 && price_history[prev_idx] > 0) {
            double change = (price_history[idx] - price_history[prev_idx]) / price_history[prev_idx];
            momentum += change * i; // Momentum pondéré
            count++;
        }
    }
    
    return (count > 0) ? momentum / count : 0;
}

//+------------------------------------------------------------------+
//| Calcul de la force de tendance                                    |
//+------------------------------------------------------------------+
double CalculateTrendStrength()
{
    double trend = 0;
    int count = 0;
    
    for(int i = 1; i < 10; i++) {
        int idx = (history_index - i + 50) % 50;
        int prev_idx = (history_index - i - 1 + 50) % 50;
        if(price_history[idx] > 0 && price_history[prev_idx] > 0) {
            double change = (price_history[idx] - price_history[prev_idx]) / price_history[prev_idx];
            trend += change;
            count++;
        }
    }
    
    return (count > 0) ? trend / count : 0;
}

//+------------------------------------------------------------------+
//| Calcul de l'accumulation de pression                              |
//+------------------------------------------------------------------+
double CalculatePressureBuild()
{
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double pressure = 0;
    int count = 0;
    
    //--- Analyser les 30 dernières valeurs
    for(int i = 1; i < 30; i++) {
        int idx = (history_index - i + 50) % 50;
        if(price_history[idx] > 0) {
            double distance = MathAbs(current_price - price_history[idx]) / current_price;
            pressure += distance;
            count++;
        }
    }
    
    //--- Plus la pression est élevée, plus le spike est probable
    return (count > 0) ? pressure / count : 0;
}

//+------------------------------------------------------------------+
//| Calcul de la divergence                                           |
//+------------------------------------------------------------------+
double CalculateDivergence()
{
    double price_trend = 0;
    double momentum_trend = 0;
    int count = 0;
    
    //--- Calculer la tendance des prix
    for(int i = 1; i < 10; i++) {
        int idx = (history_index - i + 50) % 50;
        int prev_idx = (history_index - i - 1 + 50) % 50;
        if(price_history[idx] > 0 && price_history[prev_idx] > 0) {
            price_trend += (price_history[idx] - price_history[prev_idx]) / price_history[prev_idx];
            count++;
        }
    }
    
    //--- Calculer la tendance du momentum
    double momentum = CalculateMomentum();
    
    //--- Divergence = différence entre tendance prix et momentum
    double divergence = price_trend - momentum;
    
    return (count > 0) ? divergence : 0;
}

//+------------------------------------------------------------------+
//| Dessiner la flèche de prédiction                                  |
//+------------------------------------------------------------------+
void DrawPredictionArrow()
{
    if(!current_prediction.is_active) return;
    
    //--- Supprimer les anciennes flèches
    ObjectsDeleteAll(0, "SpikePrediction_");
    
    string arrow_name = "SpikePrediction_" + IntegerToString(TimeCurrent());
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    datetime current_time = TimeCurrent();
    
    //--- Couleur de la flèche
    color arrow_color = (current_prediction.predicted_direction > 0) ? clrBlue : clrRed;
    
    //--- Position de la flèche
    double arrow_price = current_price;
    if(current_prediction.predicted_direction > 0) {
        arrow_price = current_price + 20 * _Point;
    } else {
        arrow_price = current_price - 20 * _Point;
    }
    
    //--- Créer l'objet flèche
    if(ObjectCreate(0, arrow_name, OBJ_ARROW, 0, current_time, arrow_price)) {
        ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, (current_prediction.predicted_direction > 0) ? 233 : 234);
        ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, arrow_color);
        ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, arrow_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, arrow_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, arrow_name, OBJPROP_HIDDEN, true);
        
        Print("🎯 FLÈCHE PRÉDICTION PLACÉE: ", (current_prediction.predicted_direction > 0) ? "BLEUE" : "ROUGE");
    }
}

//+------------------------------------------------------------------+
//| Fonction d'affichage des informations (OnTimer)                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    //--- Affichage des informations sur le graphique
    int current_trades = 0;
    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket > 0) current_trades++;
    }
    
    string info = "SpikeHunter Simple EA | Trades: " + IntegerToString(current_trades) +
                 " | Profit: " + DoubleToString(GetTotalProfit(), 2) +
                 " | Prédictions: " + IntegerToString(total_predictions) +
                 " (" + IntegerToString(successful_predictions) + " OK)";
    
    if(current_prediction.is_active) {
        int time_left = (int)(current_prediction.predicted_time - TimeCurrent());
        if(time_left < 0) time_left = 0;
        string direction_str = (current_prediction.predicted_direction > 0) ? "BOOM" : "CRASH";
        info += " | 🔮 Prédiction: " + direction_str + " dans " + IntegerToString(time_left) + "s";
    }

    Comment(info);
}


//--- Fonctions vides pour compatibilité dans cette version simplifiée
void DetectSupportResistance() {}
void DetectTrendLines() {}
