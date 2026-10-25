//+------------------------------------------------------------------+
//| SpikeHunter_Working.mq5                                          |
//| Version fonctionnelle sans dépendances complexes                 |
//| Version: 1.0 - Working Version                                   |
//+------------------------------------------------------------------+

#property copyright "SpikeHunter AI"
#property version   "1.00"
#property description "SpikeHunter - Version fonctionnelle simplifiée"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Paramètres d'entrée                                              |
//+------------------------------------------------------------------+

input group "=== CONFIGURATION GÉNÉRALE ==="
input bool     InpEnableTrading        = true;     // Activer le trading
input int      InpMagicNumber          = 123456;   // Magic number
input string   InpSymbols              = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD"; // Symboles à trader
input double   InpLotSize              = 0.01;     // Taille de lot
input double   InpStopLoss             = 50;       // Stop Loss en pips
input double   InpTakeProfit           = 100;      // Take Profit en pips

input group "=== DÉTECTION DE SPIKE ==="
input double   InpSpikeThreshold       = 0.1;      // Seuil de spike (%)
input int      InpATRPeriod            = 14;       // Période ATR
input double   InpATRMultiplier        = 2.0;      // Multiplicateur ATR
input int      InpLookbackBars         = 20;       // Barres de référence

input group "=== GESTION DES RISQUES ==="
input double   InpMaxRiskPercent       = 2.0;      // Risque maximum par trade (%)
input int      InpMaxTradesPerDay      = 5;        // Nombre max de trades par jour
input int      InpCooldownMinutes      = 30;       // Cooldown entre trades (minutes)

input group "=== NOTIFICATIONS ==="
input bool     InpSendNotifications    = true;     // Envoyer des notifications
input bool     InpPlaySounds           = true;     // Activer les alertes sonores

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+

CTrade trade;
int atr_handle;
double atr_buffer[];
datetime last_trade_time = 0;
int trades_today = 0;
datetime last_day = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 SPIKE HUNTER WORKING - Initialisation...");
    
    // Configuration du trade
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Création de l'indicateur ATR
    atr_handle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
    if(atr_handle == INVALID_HANDLE) {
        Print("ERREUR: ATR handle invalide");
        return INIT_FAILED;
    }
    
    // Configuration des arrays
    ArraySetAsSeries(atr_buffer, true);
    
    Print("✅ SPIKE HUNTER WORKING initialisé avec succès");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🛑 SPIKE HUNTER WORKING - Arrêt");
    IndicatorRelease(atr_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Vérifier si le trading est activé
    if(!InpEnableTrading) return;
    
    // Vérifier le cooldown
    if(TimeCurrent() - last_trade_time < InpCooldownMinutes * 60) return;
    
    // Vérifier le nombre de trades par jour
    datetime current_day = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    if(current_day != last_day) {
        trades_today = 0;
        last_day = current_day;
    }
    if(trades_today >= InpMaxTradesPerDay) return;
    
    // Obtenir les données ATR
    if(CopyBuffer(atr_handle, 0, 0, 3, atr_buffer) < 3) return;
    
    // Analyser les spikes
    if(DetectSpike()) {
        ExecuteTrade();
    }
}

//+------------------------------------------------------------------+
//| Détection de spike                                               |
//+------------------------------------------------------------------+
bool DetectSpike()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, InpLookbackBars, rates) < InpLookbackBars) return false;
    
    // Analyser la barre actuelle
    MqlRates current_bar = rates[0];
    MqlRates previous_bar = rates[1];
    
    // Calculer le range de la barre actuelle
    double current_range = current_bar.high - current_bar.low;
    double current_body = MathAbs(current_bar.close - current_bar.open);
    
    // Calculer la moyenne des ranges des barres précédentes
    double avg_range = 0;
    for(int i = 1; i < InpLookbackBars; i++) {
        avg_range += (rates[i].high - rates[i].low);
    }
    avg_range /= (InpLookbackBars - 1);
    
    // Vérifier si c'est un spike
    if(current_range > avg_range * (1 + InpSpikeThreshold/100)) {
        // Vérifier la direction du spike
        if(current_bar.close > current_bar.open) {
            // Spike haussier
            Print("📈 SPIKE HAUSSIER détecté - Range: ", current_range, " vs Moyenne: ", avg_range);
            return true;
        } else {
            // Spike baissier
            Print("📉 SPIKE BAISSIER détecté - Range: ", current_range, " vs Moyenne: ", avg_range);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Exécution du trade                                               |
//+------------------------------------------------------------------+
void ExecuteTrade()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr_value = atr_buffer[0];
    
    // Calculer la taille de lot basée sur le risque
    double lot_size = CalculateLotSize(atr_value);
    
    // Calculer SL et TP
    double sl_distance = InpStopLoss * point * 10;
    double tp_distance = InpTakeProfit * point * 10;
    
    // Déterminer la direction du trade
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) < 1) return;
    
    bool is_bullish = rates[0].close > rates[0].open;
    
    if(is_bullish) {
        // Trade d'achat
        double sl_price = ask - sl_distance;
        double tp_price = ask + tp_distance;
        
        if(trade.Buy(lot_size, _Symbol, ask, sl_price, tp_price, "SpikeHunter Buy")) {
            Print("✅ ACHAT exécuté - Lot: ", lot_size, " Prix: ", ask, " SL: ", sl_price, " TP: ", tp_price);
            last_trade_time = TimeCurrent();
            trades_today++;
            SendSpikeNotification("SpikeHunter: ACHAT exécuté sur " + _Symbol);
        }
    } else {
        // Trade de vente
        double sl_price = bid + sl_distance;
        double tp_price = bid - tp_distance;
        
        if(trade.Sell(lot_size, _Symbol, bid, sl_price, tp_price, "SpikeHunter Sell")) {
            Print("✅ VENTE exécutée - Lot: ", lot_size, " Prix: ", bid, " SL: ", sl_price, " TP: ", tp_price);
            last_trade_time = TimeCurrent();
            trades_today++;
            SendSpikeNotification("SpikeHunter: VENTE exécutée sur " + _Symbol);
        }
    }
}

//+------------------------------------------------------------------+
//| Calcul de la taille de lot                                       |
//+------------------------------------------------------------------+
double CalculateLotSize(double atr_value)
{
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * InpMaxRiskPercent / 100;
    
    double point_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double sl_distance = InpStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    
    double lot_size = risk_amount / (sl_distance * point_value);
    
    // Normaliser la taille de lot
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(lot_size, min_lot);
    lot_size = MathMin(lot_size, max_lot);
    lot_size = MathRound(lot_size / lot_step) * lot_step;
    
    return lot_size;
}

//+------------------------------------------------------------------+
//| Fonction de notification                                          |
//+------------------------------------------------------------------+
void SendSpikeNotification(string message)
{
    if(InpSendNotifications) {
        SendNotification(message);
    }
    if(InpPlaySounds) {
        PlaySound("alert.wav");
    }
}
