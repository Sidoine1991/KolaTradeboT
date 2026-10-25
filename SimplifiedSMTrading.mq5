//+------------------------------------------------------------------+
//|                                            SimplifiedSMTrading.mq5 |
//|                                    Système SMC Simplifié pour EA |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.00"

//+------------------------------------------------------------------+
//| INCLURE LES FONCTIONS SMC                                    |
//+------------------------------------------------------------------+
input group "=== SMC SIMPLIFIÉ ==="
input bool     InpUseSMCTrading     = true;      // Activer trading SMC
input double   InpSRTolerance        = 0.001;     // Tolérance S/R (0.1%)
input int      InpMinSRTouches      = 2;         // Touches minimum pour confirmer
input double   InpMinStrength       = 0.6;       // Force minimum niveau
input double   InpMinRRRatio        = 2.0;      // Risk/Reward minimum (1:2)
input bool     InpDrawSMCLevels     = true;      // Afficher niveaux SMC

//+------------------------------------------------------------------+
//| STRUCTURES SMC                                                   |
//+------------------------------------------------------------------+
struct SMCLevel {
    double price;
    int type;        // 1=Support, -1=Resistance
    double strength;
    int touches;
    bool confirmed;
    datetime last_contact;
};

struct ImbalanceZone {
    double top;
    double bottom;
    int zone_type;   // 1=IB_BUY, -1=IB_SELL
    double strength;
    datetime formed_time;
    bool filled;
    bool confirmed;
};

struct OrderBlock {
    double high;
    double low;
    int ob_type;     // 1=OB_BUY, -1=OB_SELL
    datetime formed_time;
    double strength;
    bool invalidated;
    bool confirmed;
};

struct SMCSignal {
    string symbol;
    int action;      // 1=BUY, -1=SELL
    double entry_price;
    double sl_price;
    double tp_price;
    double confidence;
    string reason;
    double key_level;
    double risk_reward;
};

// Variables globales SMC
SMCLevel g_sr_levels[20];
int g_sr_count = 0;

ImbalanceZone g_ib_zones[15];
int g_ib_count = 0;

OrderBlock g_order_blocks[10];
int g_ob_count = 0;

//+------------------------------------------------------------------+
//| Détecter les niveaux Support/Résistance confirmés              |
//+------------------------------------------------------------------+
void DetectSupportResistance(string symbol, ENUM_TIMEFRAMES tf, int periods)
{
    g_sr_count = 0;
    
    MqlRates rates[];
    if(CopyRates(symbol, tf, 0, periods, rates) < periods) return;
    
    // Détecter les swing highs/lows
    double swing_highs[];
    double swing_lows[];
    
    int window = 5;
    for(int i = window; i < periods - window; i++) {
        // Swing High
        bool is_high = true;
        for(int j = 1; j <= window; j++) {
            if(rates[i].high < rates[i-j].high || rates[i].high < rates[i+j].high) {
                is_high = false;
                break;
            }
        }
        if(is_high) {
            ArrayResize(swing_highs, ArraySize(swing_highs)+1);
            swing_highs[ArraySize(swing_highs)-1] = rates[i].high;
        }
        
        // Swing Low
        bool is_low = true;
        for(int j = 1; j <= window; j++) {
            if(rates[i].low > rates[i-j].low || rates[i].low > rates[i+j].low) {
                is_low = false;
                break;
            }
        }
        if(is_low) {
            ArrayResize(swing_lows, ArraySize(swing_lows)+1);
            swing_lows[ArraySize(swing_lows)-1] = rates[i].low;
        }
    }
    
    // Fusionner les niveaux proches
    // Support
    for(int i = 0; i < ArraySize(swing_lows); i++) {
        double level = swing_lows[i];
        int touches = CountTouches(rates, level, 1, periods);
        double strength = MathMin(touches/3.0, 1.0);
        
        if(touches >= InpMinSRTouches && strength >= InpMinStrength) {
            g_sr_levels[g_sr_count].price = level;
            g_sr_levels[g_sr_count].type = 1;
            g_sr_levels[g_sr_count].strength = strength;
            g_sr_levels[g_sr_count].touches = touches;
            g_sr_levels[g_sr_count].confirmed = true;
            g_sr_levels[g_sr_count].last_contact = rates[periods-1].time;
            g_sr_count++;
            
            if(g_sr_count >= 20) break;
        }
    }
    
    // Resistance
    for(int i = 0; i < ArraySize(swing_highs); i++) {
        double level = swing_highs[i];
        int touches = CountTouches(rates, level, -1, periods);
        double strength = MathMin(touches/3.0, 1.0);
        
        if(touches >= InpMinSRTouches && strength >= InpMinStrength) {
            g_sr_levels[g_sr_count].price = level;
            g_sr_levels[g_sr_count].type = -1;
            g_sr_levels[g_sr_count].strength = strength;
            g_sr_levels[g_sr_count].touches = touches;
            g_sr_levels[g_sr_count].confirmed = true;
            g_sr_levels[g_sr_count].last_contact = rates[periods-1].time;
            g_sr_count++;
            
            if(g_sr_count >= 20) break;
        }
    }
}

//+------------------------------------------------------------------+
//| Compter les touches d'un niveau                                 |
//+------------------------------------------------------------------+
int CountTouches(MqlRates &rates[], double level, int type, int periods)
{
    int touches = 0;
    
    for(int i = 0; i < periods; i++) {
        if(type == 1) {  // Support
            if(MathAbs(rates[i].low - level) / level <= InpSRTolerance) {
                touches++;
            }
        } else {  // Resistance
            if(MathAbs(rates[i].high - level) / level <= InpSRTolerance) {
                touches++;
            }
        }
    }
    
    return touches;
}

//+------------------------------------------------------------------+
//| Détecter les zones d'imbalance (FVG)                           |
//+------------------------------------------------------------------+
void DetectImbalanceZones(string symbol, ENUM_TIMEFRAMES tf, int periods)
{
    g_ib_count = 0;
    
    MqlRates rates[];
    if(CopyRates(symbol, tf, 0, periods, rates) < periods) return;
    
    double min_fvg_size = SymbolInfoDouble(symbol, SYMBOL_BID) * 0.0005;
    
    for(int i = 2; i < periods; i++) {
        // FVG haussier (IB Buy)
        if(rates[i-2].low < rates[i].low) {
            double gap_bottom = rates[i-2].high;
            double gap_top = rates[i].low;
            
            if(gap_top > gap_bottom && gap_top - gap_bottom >= min_fvg_size) {
                g_ib_zones[g_ib_count].top = gap_top;
                g_ib_zones[g_ib_count].bottom = gap_bottom;
                g_ib_zones[g_ib_count].zone_type = 1;
                g_ib_zones[g_ib_count].strength = 1.0;
                g_ib_zones[g_ib_count].formed_time = rates[i].time;
                g_ib_zones[g_ib_count].filled = false;
                g_ib_zones[g_ib_count].confirmed = true;
                g_ib_count++;
                
                if(g_ib_count >= 15) break;
            }
        }
        
        // FVG baissier (IB Sell)
        if(rates[i-2].high > rates[i].high) {
            double gap_top = rates[i-2].low;
            double gap_bottom = rates[i].high;
            
            if(gap_bottom < gap_top && gap_top - gap_bottom >= min_fvg_size) {
                g_ib_zones[g_ib_count].top = gap_top;
                g_ib_zones[g_ib_count].bottom = gap_bottom;
                g_ib_zones[g_ib_count].zone_type = -1;
                g_ib_zones[g_ib_count].strength = 1.0;
                g_ib_zones[g_ib_count].formed_time = rates[i].time;
                g_ib_zones[g_ib_count].filled = false;
                g_ib_zones[g_ib_count].confirmed = true;
                g_ib_count++;
                
                if(g_ib_count >= 15) break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Détecter les Order Blocks                                        |
//+------------------------------------------------------------------+
void DetectOrderBlocks(string symbol, ENUM_TIMEFRAMES tf, int periods)
{
    g_ob_count = 0;
    
    MqlRates rates[];
    if(CopyRates(symbol, tf, 0, periods, rates) < periods) return;
    
    int min_bodies = 3;
    
    for(int i = min_bodies; i < periods - 1; i++) {
        // OB Buy: série baissière suivie de haussière
        bool bearish_streak = true;
        for(int j = 0; j < min_bodies; j++) {
            if(rates[i-j].close >= rates[i-j].open) {
                bearish_streak = false;
                break;
            }
        }
        
        if(bearish_streak && rates[i+1].close > rates[i+1].open) {
            double high = rates[i].high;
            double low = rates[i].low;
            
            for(int j = i-min_bodies+1; j <= i; j++) {
                if(rates[j].high > high) high = rates[j].high;
                if(rates[j].low < low) low = rates[j].low;
            }
            
            g_order_blocks[g_ob_count].high = high;
            g_order_blocks[g_ob_count].low = low;
            g_order_blocks[g_ob_count].ob_type = 1;
            g_order_blocks[g_ob_count].formed_time = rates[i].time;
            g_order_blocks[g_ob_count].strength = 1.0;
            g_order_blocks[g_ob_count].invalidated = false;
            g_order_blocks[g_ob_count].confirmed = true;
            g_ob_count++;
            
            if(g_ob_count >= 10) break;
        }
        
        // OB Sell: série haussière suivie de baissière
        bool bullish_streak = true;
        for(int j = 0; j < min_bodies; j++) {
            if(rates[i-j].close <= rates[i-j].open) {
                bullish_streak = false;
                break;
            }
        }
        
        if(bullish_streak && rates[i+1].close < rates[i+1].open) {
            double high = rates[i].high;
            double low = rates[i].low;
            
            for(int j = i-min_bodies+1; j <= i; j++) {
                if(rates[j].high > high) high = rates[j].high;
                if(rates[j].low < low) low = rates[j].low;
            }
            
            g_order_blocks[g_ob_count].high = high;
            g_order_blocks[g_ob_count].low = low;
            g_order_blocks[g_ob_count].ob_type = -1;
            g_order_blocks[g_ob_count].formed_time = rates[i].time;
            g_order_blocks[g_ob_count].strength = 1.0;
            g_order_blocks[g_ob_count].invalidated = false;
            g_order_blocks[g_ob_count].confirmed = true;
            g_ob_count++;
            
            if(g_ob_count >= 10) break;
        }
    }
}

//+------------------------------------------------------------------+
//| Calculer SL et TP intelligemment                                |
//+------------------------------------------------------------------+
bool CalculateSMCSLTP(string symbol, double entry_price, int action, 
                      double key_level, double &sl, double &tp)
{
    double atr = CalculateATRSimple(symbol, 14);
    double sl_mult = 2.0;
    double tp_mult = 4.0;
    
    if(action == 1) {  // BUY
        if(key_level > 0 && key_level < entry_price) {
            sl = key_level * 0.9995;
        } else {
            sl = entry_price - (atr * sl_mult);
        }
        tp = entry_price + (atr * tp_mult);
    } else {  // SELL
        if(key_level > 0 && key_level > entry_price) {
            sl = key_level * 1.0005;
        } else {
            sl = entry_price + (atr * sl_mult);
        }
        tp = entry_price - (atr * tp_mult);
    }
    
    // Vérifier ratio R:R
    double risk = MathAbs(entry_price - sl);
    double reward = MathAbs(tp - entry_price);
    
    if(risk > 0) {
        double rr = reward / risk;
        if(rr < InpMinRRRatio) {
            if(action == 1) {
                tp = entry_price + (risk * InpMinRRRatio);
            } else {
                tp = entry_price - (risk * InpMinRRRatio);
            }
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculer ATR simple                                             |
//+------------------------------------------------------------------+
double CalculateATRSimple(string symbol, int period)
{
    int atr_handle = iATR(symbol, PERIOD_M1, period);
    if(atr_handle == INVALID_HANDLE) return 0.0;
    
    double atr[];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr) < 1) {
        IndicatorRelease(atr_handle);
        return 0.0;
    }
    
    IndicatorRelease(atr_handle);
    return atr[0];
}

//+------------------------------------------------------------------+
//| Générer les signaux SMC                                         |
//+------------------------------------------------------------------+
SMCSignal GenerateSMCSignals(string symbol)
{
    SMCSignal signal;
    signal.confidence = 0.0;
    
    DetectSupportResistance(symbol, PERIOD_M1, 200);
    DetectImbalanceZones(symbol, PERIOD_M1, 50);
    DetectOrderBlocks(symbol, PERIOD_M1, 100);
    
    double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    // Analyser S/R
    for(int i = 0; i < g_sr_count; i++) {
        SMCLevel level = g_sr_levels[i];
        double distance = MathAbs(current_price - level.price) / current_price;
        
        if(distance <= 0.002) {  // Prix proche (0.2%)
            if(level.type == 1 && current_price > level.price) {  // Support et prix au-dessus
                double sl, tp;
                if(CalculateSMCSLTP(symbol, ask, 1, level.price, sl, tp)) {
                    double rr = MathAbs(tp - ask) / MathAbs(ask - sl);
                    
                    signal.symbol = symbol;
                    signal.action = 1;  // BUY
                    signal.entry_price = ask;
                    signal.sl_price = sl;
                    signal.tp_price = tp;
                    signal.confidence = level.strength * 0.8;
                    signal.reason = StringFormat("Support %dt", level.touches);
                    signal.key_level = level.price;
                    signal.risk_reward = rr;
                    
                    if(signal.confidence >= 0.65 && signal.risk_reward >= InpMinRRRatio) {
                        return signal;
                    }
                }
            } else if(level.type == -1 && current_price < level.price) {  // Resistance et prix en-dessous
                double sl, tp;
                if(CalculateSMCSLTP(symbol, ask, -1, level.price, sl, tp)) {
                    double rr = MathAbs(ask - tp) / MathAbs(sl - ask);
                    
                    signal.symbol = symbol;
                    signal.action = -1;  // SELL
                    signal.entry_price = ask;
                    signal.sl_price = sl;
                    signal.tp_price = tp;
                    signal.confidence = level.strength * 0.8;
                    signal.reason = StringFormat("Resistance %dt", level.touches);
                    signal.key_level = level.price;
                    signal.risk_reward = rr;
                    
                    if(signal.confidence >= 0.65 && signal.risk_reward >= InpMinRRRatio) {
                        return signal;
                    }
                }
            }
        }
    }
    
    // Analyser IB Buy
    for(int i = 0; i < g_ib_count; i++) {
        ImbalanceZone ib = g_ib_zones[i];
        
        if(ib.zone_type == 1 && !ib.filled) {  // IB Buy
            if(current_price >= ib.bottom && current_price <= ib.top) {
                double sl, tp;
                if(CalculateSMCSLTP(symbol, ask, 1, ib.bottom, sl, tp)) {
                    double rr = MathAbs(tp - ask) / MathAbs(ask - sl);
                    
                    signal.symbol = symbol;
                    signal.action = 1;
                    signal.entry_price = ask;
                    signal.sl_price = sl;
                    signal.tp_price = tp;
                    signal.confidence = ib.strength;
                    signal.reason = "Zone IB Buy";
                    signal.key_level = ib.bottom;
                    signal.risk_reward = rr;
                    
                    if(signal.risk_reward >= InpMinRRRatio) {
                        return signal;
                    }
                }
            }
        } else if(ib.zone_type == -1 && !ib.filled) {  // IB Sell
            if(current_price >= ib.bottom && current_price <= ib.top) {
                double sl, tp;
                if(CalculateSMCSLTP(symbol, ask, -1, ib.top, sl, tp)) {
                    double rr = MathAbs(ask - tp) / MathAbs(sl - ask);
                    
                    signal.symbol = symbol;
                    signal.action = -1;
                    signal.entry_price = ask;
                    signal.sl_price = sl;
                    signal.tp_price = tp;
                    signal.confidence = ib.strength;
                    signal.reason = "Zone IB Sell";
                    signal.key_level = ib.top;
                    signal.risk_reward = rr;
                    
                    if(signal.risk_reward >= InpMinRRRatio) {
                        return signal;
                    }
                }
            }
        }
    }
    
    // Analyser OB Buy
    for(int i = 0; i < g_ob_count; i++) {
        OrderBlock ob = g_order_blocks[i];
        
        if(ob.ob_type == 1 && !ob.invalidated) {  // OB Buy
            if(current_price <= ob.high) {
                double sl, tp;
                if(CalculateSMCSLTP(symbol, ask, 1, ob.low, sl, tp)) {
                    double rr = MathAbs(tp - ask) / MathAbs(ask - sl);
                    
                    signal.symbol = symbol;
                    signal.action = 1;
                    signal.entry_price = ask;
                    signal.sl_price = sl;
                    signal.tp_price = tp;
                    signal.confidence = ob.strength;
                    signal.reason = "Order Block Buy";
                    signal.key_level = ob.low;
                    signal.risk_reward = rr;
                    
                    if(signal.risk_reward >= InpMinRRRatio) {
                        return signal;
                    }
                }
            }
        } else if(ob.ob_type == -1 && !ob.invalidated) {  // OB Sell
            if(current_price >= ob.low) {
                double sl, tp;
                if(CalculateSMCSLTP(symbol, ask, -1, ob.high, sl, tp)) {
                    double rr = MathAbs(ask - tp) / MathAbs(sl - ask);
                    
                    signal.symbol = symbol;
                    signal.action = -1;
                    signal.entry_price = ask;
                    signal.sl_price = sl;
                    signal.tp_price = tp;
                    signal.confidence = ob.strength;
                    signal.reason = "Order Block Sell";
                    signal.key_level = ob.high;
                    signal.risk_reward = rr;
                    
                    if(signal.risk_reward >= InpMinRRRatio) {
                        return signal;
                    }
                }
            }
        }
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("✅ Système SMC Simplifié initialisé");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("⏹️ Système SMC arrêté - Raison: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!InpUseSMCTrading) return;
    
    // Générer les signaux SMC pour le symbole actuel
    SMCSignal signal = GenerateSMCSignals(_Symbol);
    
    if(signal.confidence >= 0.65 && signal.risk_reward >= InpMinRRRatio) {
        // Vérifier qu'il n'y a pas déjà une position
        if(PositionSelect(_Symbol)) {
            return; // Position déjà ouverte
        }
        
        // Exécuter le trade
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_DEAL;
        request.symbol = signal.symbol;
        request.volume = 0.01;
        request.type = (signal.action == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        request.price = (signal.action == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        request.sl = signal.sl_price;
        request.tp = signal.tp_price;
        request.deviation = 20;
        request.magic = 888001;
        request.comment = signal.reason;
        request.type_filling = ORDER_FILLING_IOC;
        
        if(OrderSend(request, result)) {
            Print("✅ Trade exécuté: ", signal.action == 1 ? "BUY" : "SELL", " ", signal.symbol, 
                  " - Confiance: ", DoubleToString(signal.confidence, 2), 
                  " - R:R: 1:", DoubleToString(signal.risk_reward, 2));
        } else {
            Print("❌ Échec trade: ", GetLastError());
        }
    }
}
//+------------------------------------------------------------------+
