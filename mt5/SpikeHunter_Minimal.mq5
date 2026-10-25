//+------------------------------------------------------------------+
//|                                            SpikeHunter_Minimal.mq5 |
//|                        Copyright 2025, TradBOT Spike Hunter EA   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, TradBOT Spike Hunter EA"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Robot de trading minimal pour capturer les spikes"

//--- Paramètres d'entrée
input bool     InpEnableTrading = true;           // Activer le trading
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M1;   // Timeframe d'analyse
input int      InpMagicNumber = 123456;           // Magic Number
input double   InpSpikeThreshold = 0.1;           // Seuil de spike (%)
input bool     InpSendNotifications = true;       // Envoyer des notifications
input bool     InpPlaySounds = true;              // Activer les alertes sonores

//--- Variables globales
int ma_handle;
int rsi_handle;
double ma_buffer[];
double rsi_buffer[];

//--- Variables de suivi
datetime last_spike_time = 0;
bool spike_detected = false;
int spike_direction = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 SPIKE HUNTER MINIMAL - Initialisation...");
    
    // Vérification du symbole
    if(!SymbolSelect(_Symbol, true)) {
        Print("ERREUR: Symbole invalide: ", _Symbol);
        return INIT_FAILED;
    }
    
    // Création des indicateurs
    ma_handle = iMA(_Symbol, InpTimeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
    if(ma_handle == INVALID_HANDLE) {
        Print("ERREUR: MA handle invalide");
        return INIT_FAILED;
    }
    
    rsi_handle = iRSI(_Symbol, InpTimeframe, 14, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) {
        Print("ERREUR: RSI handle invalide");
        IndicatorRelease(ma_handle);
        return INIT_FAILED;
    }
    
    // Initialisation des buffers
    ArraySetAsSeries(ma_buffer, true);
    ArraySetAsSeries(rsi_buffer, true);
    
    // Initialisation des variables
    spike_detected = false;
    spike_direction = 0;
    last_spike_time = 0;
    
    Print("✅ SPIKE HUNTER MINIMAL INITIALISÉ AVEC SUCCÈS !");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(ma_handle != INVALID_HANDLE)
        IndicatorRelease(ma_handle);
    if(rsi_handle != INVALID_HANDLE)
        IndicatorRelease(rsi_handle);
    
    ArrayFree(ma_buffer);
    ArrayFree(rsi_buffer);
    
    Print("SpikeHunter Minimal arrêté - Raison: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!InpEnableTrading) return;
    
    // Log de debug simple
    static int tick_count = 0;
    tick_count++;
    if(tick_count % 100 == 1) {
        Print("🔄 OnTick #", tick_count, " - EA fonctionne");
    }
    
    // Vérifications de base
    if(!TerminalInfoInteger(TERMINAL_CONNECTED)) {
        Print("❌ Pas de connexion");
        return;
    }
    
    if(!SymbolSelect(_Symbol, true)) {
        Print("❌ Symbole invalide");
        return;
    }

    // Mise à jour des indicateurs
    if(!UpdateIndicators()) {
        Print("❌ Erreur indicateurs");
        return;
    }

    // Détection de spike
    DetectSpike();
    
    // Affichage des signaux
    if(spike_detected) {
        string direction_text = (spike_direction > 0) ? "BUY" : "SELL";
        Print("🎯 SIGNAL SPIKE: ", direction_text, " ", _Symbol);
        spike_detected = false;
    }
}

//+------------------------------------------------------------------+
//| Mise à jour des indicateurs                                      |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
    if(CopyBuffer(ma_handle, 0, 0, 3, ma_buffer) < 0) {
        Print("❌ Erreur copie buffer MA: ", GetLastError());
        return false;
    }
    if(CopyBuffer(rsi_handle, 0, 0, 3, rsi_buffer) < 0) {
        Print("❌ Erreur copie buffer RSI: ", GetLastError());
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Détection de spike                                               |
//+------------------------------------------------------------------+
void DetectSpike()
{
    static datetime last_check = 0;
    if(TimeCurrent() - last_check < 1) return;
    last_check = TimeCurrent();
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    static double last_price = 0;
    
    if(last_price > 0) {
        double price_change = (current_price - last_price) / last_price * 100;
        
        // Détection de spike
        if(MathAbs(price_change) >= InpSpikeThreshold) {
            if(TimeCurrent() - last_spike_time > 2) {
                spike_detected = true;
                spike_direction = (price_change > 0) ? 1 : -1;
                last_spike_time = TimeCurrent();
                
                string order_type = (spike_direction > 0) ? "BUY" : "SELL";
                Print("🚀 SPIKE DÉTECTÉ: ", _Symbol, " - ", order_type, " - Changement: ", DoubleToString(price_change, 4), "%");
                
                PlayAlert("SPIKE");
                
                if(InpSendNotifications) {
                    string notification = StringFormat("Signal: %s %s | Prix: %s | Changement: %.4f%%", 
                                                     order_type, _Symbol, DoubleToString(current_price, _Digits), price_change);
                    SendMyNotification(notification);
                }
            }
        }
    }
    
    last_price = current_price;
}

//+------------------------------------------------------------------+
//| Fonction de notification                                         |
//+------------------------------------------------------------------+
void SendMyNotification(string message)
{
    Print("📱 NOTIFICATION: ", message);
    bool result = ::SendNotification(message);
    if(result) {
        Print("✅ NOTIFICATION ENVOYÉE");
    } else {
        Print("❌ ÉCHEC NOTIFICATION - Erreur: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Fonction d'alerte sonore                                         |
//+------------------------------------------------------------------+
void PlayAlert(string alert_type)
{
    if(!InpPlaySounds) return;
    PlaySound("alert.wav");
    Print("🔊 Alerte sonore: ", alert_type);
}
