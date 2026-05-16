//+------------------------------------------------------------------+
//|                                    SMC_Liquidity_HedgeFund.mq5 |
//|                    Smart Money Concept - Hedge Fund Strategy    |
//|                      Trading comme les fonds d'investissement   |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>

//+------------------------------------------------------------------+
//| STRUCTURES DE DONNÉES SMC                                    |
//+------------------------------------------------------------------+

struct LiquidityZone {
    double price;
    datetime time;
    int touches;
    string type; // "SWING_HIGH", "SWING_LOW", "EQUAL_HIGH", "EQUAL_LOW", "TRENDLINE"
    double strength;
    bool isActive;
    string objectId;
    
    void Reset() {
        price = 0.0;
        time = 0;
        touches = 0;
        type = "";
        strength = 0.0;
        isActive = false;
        objectId = "";
    }
};

struct MarketStructure {
    double lastSwingHigh;
    double lastSwingLow;
    datetime lastSwingHighTime;
    datetime lastSwingLowTime;
    double currentEqualHigh;
    double currentEqualLow;
    int equalHighTouches;
    int equalLowTouches;
    bool bullishStructure;
    bool bearishStructure;
    
    void Reset() {
        lastSwingHigh = 0.0;
        lastSwingLow = 0.0;
        lastSwingHighTime = 0;
        lastSwingLowTime = 0;
        currentEqualHigh = 0.0;
        currentEqualLow = 0.0;
        equalHighTouches = 0;
        equalLowTouches = 0;
        bullishStructure = false;
        bearishStructure = false;
    }
};

//+------------------------------------------------------------------+
//| PARAMÈTRES D'ENTRÉE                                        |
//+------------------------------------------------------------------+

input group "=== PARAMÈTRES GÉNÉRAUX ==="
input bool   EnableTrading        = true;        // Activer/Désactiver le trading
input double InpLotSize         = 0.01;         // Taille de lot par défaut
input double RiskPercent        = 1.0;          // Risque en % du capital
input double RR_Ratio           = 3.0;          // Ratio Risk/Reward (1:3)
input int    MagicNumber        = 888888;        // Magic Number unique
input ENUM_TIMEFRAMES PrimaryTF     = PERIOD_M15;    // Timeframe principal d'analyse
input ENUM_TIMEFRAMES ConfirmationTF = PERIOD_H1;     // Timeframe de confirmation

input group "=== DÉTECTION DE LIQUIDITÉ ==="
input int    SwingLookback      = 5;             // Période pour détection swing
input double EqualTolerance    = 15.0;          // Tolérance pour equal highs/lows (points)
input int    MinEqualTouches    = 2;              // Touches minimum pour equal high/low
input double LiquidityStrength  = 0.7;           // Force minimale de la zone (0-1)
input int    MaxLiquidityZones = 10;             // Nombre max de zones à tracking
input bool   UseTrendlines      = true;          // Utiliser trendlines diagonales

input group "=== STRATÉGIE D'ENTRÉE ==="
input bool   WaitForSweep      = true;          // Attendre sweep de liquidité
input double SweepThreshold    = 5.0;           // Seuil de sweep (points)
input bool   ConfirmBreakOfStructure = true;     // Confirmer BOS après sweep
input int    EntryDelayBars    = 1;              // Délai en barres après sweep
input double MinMoveAfterSweep = 10.0;          // Mouvement minimum après sweep
input bool   UseVolumeConfirmation = true;       // Confirmation volume

input group "=== GESTION DES RISQUES ==="
input double MaxDailyLoss      = 50.0;          // Perte journalière maximale ($)
input int    MaxDailyTrades    = 20;             // Trades max par jour
input double MaxSpreadPoints   = 5.0;            // Spread maximum autorisé
input double StopLossBuffer    = 3.0;            // Buffer SL au-dessus/en dessous zone
input bool   UseTrailingStop    = true;          // Utiliser trailing stop
input double TrailingStopATR   = 1.5;           // Trailing stop en ATR

input group "=== AFFICHAGE ==="
input bool   ShowLiquidityZones = true;          // Afficher zones de liquidité
input bool   ShowSweeps         = true;          // Afficher sweeps détectés
input bool   ShowEntries         = true;          // Afficher points d'entrée
input bool   ShowDashboard       = true;          // Afficher tableau de bord
input color  LiquidityColor     = clrOrange;       // Couleur zones liquidité
input color  SweepColor         = clrRed;          // Couleur sweeps
input color  EntryColor         = clrLime;        // Couleur entrées

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                           |
//+------------------------------------------------------------------+

CTrade trade;
MarketStructure marketStructure;
LiquidityZone liquidityZones[];
double dailyPL = 0.0;
int dailyTradeCount = 0;
datetime lastBarTime = 0;
datetime dailyResetTime = 0;
string dashboardPrefix = "SMC_DASH_";

//+------------------------------------------------------------------+
//| FONCTIONS DE CALCUL                                           |
//+------------------------------------------------------------------+

double CalculateOptimalLotSize(double stopLossPoints) {
    if(stopLossPoints <= 0) return InpLotSize;
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (RiskPercent / 100.0);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickValue <= 0 || pointValue <= 0) return InpLotSize;
    
    double lotSize = riskAmount / (stopLossPoints * tickValue / pointValue);
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    return NormalizeDouble(lotSize, 2);
}

double GetATR(int period, ENUM_TIMEFRAMES timeframe) {
    int handle = iATR(_Symbol, timeframe, period);
    if(handle == INVALID_HANDLE) return 0.0;
    
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(handle, 0, 0, 1, atr) > 0) {
        IndicatorRelease(handle);
        return atr[0];
    }
    
    IndicatorRelease(handle);
    return 0.0;
}

double GetVolume(int shift, ENUM_TIMEFRAMES timeframe) {
    long volume[];
    ArraySetAsSeries(volume, true);
    if(CopyTickVolume(_Symbol, timeframe, shift, 1, volume) > 0) {
        return (double)volume[0];
    }
    return 0.0;
}

double GetAverageVolume(int period, ENUM_TIMEFRAMES timeframe) {
    long volume[];
    ArraySetAsSeries(volume, true);
    if(CopyTickVolume(_Symbol, timeframe, 0, period, volume) > 0) {
        double sum = 0.0;
        for(int i = 0; i < period; i++) {
            sum += (double)volume[i];
        }
        return sum / period;
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| DÉTECTION SWING HIGH/LOW                                      |
//+------------------------------------------------------------------+

bool IsSwingHigh(int index, ENUM_TIMEFRAMES timeframe) {
    double high = iHigh(_Symbol, timeframe, index);
    
    for(int i = 1; i <= SwingLookback; i++) {
        if(index + i >= Bars(_Symbol, timeframe)) break;
        if(iHigh(_Symbol, timeframe, index + i) >= high) return false;
    }
    
    for(int i = 1; i <= SwingLookback; i++) {
        if(index - i < 0) break;
        if(iHigh(_Symbol, timeframe, index - i) >= high) return false;
    }
    
    return true;
}

bool IsSwingLow(int index, ENUM_TIMEFRAMES timeframe) {
    double low = iLow(_Symbol, timeframe, index);
    
    for(int i = 1; i <= SwingLookback; i++) {
        if(index + i >= Bars(_Symbol, timeframe)) break;
        if(iLow(_Symbol, timeframe, index + i) <= low) return false;
    }
    
    for(int i = 1; i <= SwingLookback; i++) {
        if(index - i < 0) break;
        if(iLow(_Symbol, timeframe, index - i) <= low) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| DÉTECTION EQUAL HIGHS/LOWS                                   |
//+------------------------------------------------------------------+

bool IsEqualHigh(double price1, double price2) {
    return MathAbs(price1 - price2) <= EqualTolerance * _Point;
}

bool IsEqualLow(double price1, double price2) {
    return MathAbs(price1 - price2) <= EqualTolerance * _Point;
}

//+------------------------------------------------------------------+
//| BREAK OF STRUCTURE (BOS)                                      |
//+------------------------------------------------------------------+

bool IsBullishBOS() {
    if(marketStructure.lastSwingHigh == 0.0) return false;
    
    double currentClose = iClose(_Symbol, PrimaryTF, 0);
    return currentClose > marketStructure.lastSwingHigh;
}

bool IsBearishBOS() {
    if(marketStructure.lastSwingLow == 0.0) return false;
    
    double currentClose = iClose(_Symbol, PrimaryTF, 0);
    return currentClose < marketStructure.lastSwingLow;
}

//+------------------------------------------------------------------+
//| DÉTECTION DE SWEEP DE LIQUIDITÉ                             |
//+------------------------------------------------------------------+

bool IsLiquiditySweepAbove(double zonePrice) {
    double currentHigh = iHigh(_Symbol, PrimaryTF, 1);
    double previousHigh = iHigh(_Symbol, PrimaryTF, 2);
    
    return currentHigh > zonePrice && previousHigh <= zonePrice;
}

bool IsLiquiditySweepBelow(double zonePrice) {
    double currentLow = iLow(_Symbol, PrimaryTF, 1);
    double previousLow = iLow(_Symbol, PrimaryTF, 2);
    
    return currentLow < zonePrice && previousLow >= zonePrice;
}

//+------------------------------------------------------------------+
//| GESTION DES ZONES DE LIQUIDITÉ                             |
//+------------------------------------------------------------------+

void AddLiquidityZone(double price, datetime time, string type, double strength) {
    if(ArraySize(liquidityZones) >= MaxLiquidityZones) {
        // Supprimer la plus ancienne zone
        for(int i = ArraySize(liquidityZones) - 1; i > 0; i--) {
            liquidityZones[i] = liquidityZones[i-1];
        }
        ArrayResize(liquidityZones, ArraySize(liquidityZones) - 1);
    }
    
    int newSize = ArraySize(liquidityZones) + 1;
    ArrayResize(liquidityZones, newSize);
    
    LiquidityZone newZone;
    newZone.price = price;
    newZone.time = time;
    newZone.type = type;
    newZone.strength = strength;
    newZone.touches = 1;
    newZone.isActive = true;
    newZone.objectId = type + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
    
    liquidityZones[newSize - 1] = newZone;
    
    if(ShowLiquidityZones) {
        DrawLiquidityZone(newZone);
    }
}

void UpdateLiquidityZones() {
    for(int i = 0; i < ArraySize(liquidityZones); i++) {
        if(!liquidityZones[i].isActive) continue;
        
        // Vérifier si le prix touche la zone
        double currentHigh = iHigh(_Symbol, PrimaryTF, 0);
        double currentLow = iLow(_Symbol, PrimaryTF, 0);
        
        bool touched = false;
        if(liquidityZones[i].type == "SWING_HIGH" || liquidityZones[i].type == "EQUAL_HIGH") {
            touched = currentHigh >= liquidityZones[i].price && currentLow <= liquidityZones[i].price;
        } else if(liquidityZones[i].type == "SWING_LOW" || liquidityZones[i].type == "EQUAL_LOW") {
            touched = currentLow <= liquidityZones[i].price && currentHigh >= liquidityZones[i].price;
        }
        
        if(touched) {
            liquidityZones[i].touches++;
            
            // Mettre à jour equal highs/lows
            if(liquidityZones[i].type == "EQUAL_HIGH" || liquidityZones[i].type == "EQUAL_LOW") {
                UpdateEqualZone(liquidityZones[i]);
            }
        }
    }
}

void UpdateEqualZone(LiquidityZone &zone) {
    if(zone.type == "EQUAL_HIGH") {
        marketStructure.equalHighTouches++;
        if(marketStructure.equalHighTouches >= MinEqualTouches) {
            zone.strength = MathMin(1.0, zone.strength + 0.2);
        }
    } else if(zone.type == "EQUAL_LOW") {
        marketStructure.equalLowTouches++;
        if(marketStructure.equalLowTouches >= MinEqualTouches) {
            zone.strength = MathMin(1.0, zone.strength + 0.2);
        }
    }
}

//+------------------------------------------------------------------+
//| FONCTIONS DE DESSIN                                          |
//+------------------------------------------------------------------+

void DrawLiquidityZone(LiquidityZone &zone) {
    string objName = zone.objectId;
    
    if(ObjectFind(0, objName) >= 0) {
        ObjectDelete(0, objName);
    }
    
    ObjectCreate(0, objName, OBJ_HLINE, 0, 0, zone.price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, LiquidityColor);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    
    // Ajouter label
    string labelName = objName + "_LABEL";
    if(ObjectFind(0, labelName) >= 0) {
        ObjectDelete(0, labelName);
    }
    
    ObjectCreate(0, labelName, OBJ_TEXT, 0, zone.time, zone.price);
    ObjectSetString(0, labelName, OBJPROP_TEXT, zone.type + " (" + IntegerToString(zone.touches) + ")");
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, LiquidityColor);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void DrawSweep(string direction, double price, datetime time) {
    if(!ShowSweeps) return;
    
    string objName = "SWEEP_" + direction + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
    
    ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, SweepColor);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
    ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, direction == "BUY" ? 233 : 234);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void DrawEntry(string direction, double price, datetime time) {
    if(!ShowEntries) return;
    
    string objName = "ENTRY_" + direction + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
    
    ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, EntryColor);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 4);
    ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, direction == "BUY" ? 236 : 238);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| LOGIQUE D'ENTRÉE                                           |
//+------------------------------------------------------------------+

void CheckForLiquiditySweep() {
    double currentPrice = iClose(_Symbol, PrimaryTF, 0);
    double atr = GetATR(14, PrimaryTF);
    
    for(int i = 0; i < ArraySize(liquidityZones); i++) {
        if(!liquidityZones[i].isActive || liquidityZones[i].strength < LiquidityStrength) continue;
        
        bool sweepDetected = false;
        string direction = "";
        
        // Vérifier sweep au-dessus (pour entrée BUY)
        if((liquidityZones[i].type == "SWING_HIGH" || liquidityZones[i].type == "EQUAL_HIGH") && 
           IsLiquiditySweepBelow(liquidityZones[i].price)) {
            
            sweepDetected = true;
            direction = "BUY";
            
            // Confirmation BOS
            if(ConfirmBreakOfStructure && !IsBullishBOS()) continue;
            
        }
        // Vérifier sweep en dessous (pour entrée SELL)
        else if((liquidityZones[i].type == "SWING_LOW" || liquidityZones[i].type == "EQUAL_LOW") && 
                IsLiquiditySweepAbove(liquidityZones[i].price)) {
            
            sweepDetected = true;
            direction = "SELL";
            
            // Confirmation BOS
            if(ConfirmBreakOfStructure && !IsBearishBOS()) continue;
        }
        
        if(sweepDetected) {
            // Confirmation volume
            if(UseVolumeConfirmation) {
                double currentVolume = GetVolume(1, PrimaryTF);
                double avgVolume = GetAverageVolume(20, PrimaryTF);
                if(currentVolume < avgVolume * 1.2) continue;
            }
            
            // Vérifier mouvement après sweep
            if(direction == "BUY") {
                double lowAfterSweep = iLow(_Symbol, PrimaryTF, 0);
                if(lowAfterSweep > liquidityZones[i].price + MinMoveAfterSweep * _Point) {
                    ExecuteBuyTrade(liquidityZones[i].price);
                    DrawSweep(direction, liquidityZones[i].price, TimeCurrent());
                }
            } else if(direction == "SELL") {
                double highAfterSweep = iHigh(_Symbol, PrimaryTF, 0);
                if(highAfterSweep < liquidityZones[i].price - MinMoveAfterSweep * _Point) {
                    ExecuteSellTrade(liquidityZones[i].price);
                    DrawSweep(direction, liquidityZones[i].price, TimeCurrent());
                }
            }
        }
    }
}

void ExecuteBuyTrade(double sweepPrice) {
    if(!EnableTrading) return;
    if(!CheckTradingConditions()) return;
    
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double spread = (ask - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
    
    if(spread > MaxSpreadPoints) {
        Print("Spread trop élevé: ", spread, " points");
        return;
    }
    
    double stopLoss = sweepPrice - StopLossBuffer * _Point;
    double takeProfit = ask + ((ask - stopLoss) * RR_Ratio);
    double stopPoints = (ask - stopLoss) / _Point;
    
    double lotSize = CalculateOptimalLotSize(stopPoints);
    
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    
    bool result = trade.Buy(lotSize, _Symbol, ask, stopLoss, takeProfit, "SMC LIQUIDITY BUY");
    
    if(result) {
        DrawEntry("BUY", ask, TimeCurrent());
        dailyTradeCount++;
        Print("Trade BUY exécuté à ", ask, " | SL: ", stopLoss, " | TP: ", takeProfit, " | Lot: ", lotSize);
    } else {
        Print("Échec trade BUY: ", trade.ResultComment());
    }
}

void ExecuteSellTrade(double sweepPrice) {
    if(!EnableTrading) return;
    if(!CheckTradingConditions()) return;
    
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - bid) / _Point;
    
    if(spread > MaxSpreadPoints) {
        Print("Spread trop élevé: ", spread, " points");
        return;
    }
    
    double stopLoss = sweepPrice + StopLossBuffer * _Point;
    double takeProfit = bid - ((stopLoss - bid) * RR_Ratio);
    double stopPoints = (stopLoss - bid) / _Point;
    
    double lotSize = CalculateOptimalLotSize(stopPoints);
    
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    
    bool result = trade.Sell(lotSize, _Symbol, bid, stopLoss, takeProfit, "SMC LIQUIDITY SELL");
    
    if(result) {
        DrawEntry("SELL", bid, TimeCurrent());
        dailyTradeCount++;
        Print("Trade SELL exécuté à ", bid, " | SL: ", stopLoss, " | TP: ", takeProfit, " | Lot: ", lotSize);
    } else {
        Print("Échec trade SELL: ", trade.ResultComment());
    }
}

//+------------------------------------------------------------------+
//| GESTION DES RISQUES                                         |
//+------------------------------------------------------------------+

bool CheckTradingConditions() {
    // Vérifier perte journalière
    if(dailyPL < -MathAbs(MaxDailyLoss)) {
        Print("Perte journalière maximale atteinte");
        return false;
    }
    
    // Vérifier nombre de trades journaliers
    if(dailyTradeCount >= MaxDailyTrades) {
        Print("Nombre maximum de trades journaliers atteint");
        return false;
    }
    
    // Vérifier si position déjà ouverte
    if(PositionsTotal() > 0) {
        // Permettre seulement si pas de position sur ce symbole avec ce magic number
        for(int i = 0; i < PositionsTotal(); i++) {
            if(PositionSelectByTicket(PositionGetTicket(i))) {
                if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
                   PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
                    Print("Position déjà ouverte sur ce symbole");
                    return false;
                }
            }
        }
    }
    
    return true;
}

void ResetDailyCounters() {
    dailyPL = 0.0;
    dailyTradeCount = 0;
    dailyResetTime = TimeCurrent();
    Print("Compteurs journaliers réinitialisés");
}

void UpdateDailyPL() {
    datetime currentTime = TimeCurrent();
    
    // Réinitialiser à minuit
    MqlDateTime currentTimeStruct, resetTimeStruct;
    TimeToStruct(currentTime, currentTimeStruct);
    TimeToStruct(dailyResetTime, resetTimeStruct);
    
    if(currentTimeStruct.day != resetTimeStruct.day) {
        ResetDailyCounters();
        return;
    }
    
    // Calculer P&L du jour
    double todayPL = 0.0;
    for(int i = 0; i < HistoryDealsTotal(); i++) {
        if(HistorySelect(0, TimeCurrent())) {
            if(HistoryDealSelect(i)) {
                ulong dealTicket = HistoryDealGetTicket(i);
                if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == MagicNumber) {
                    datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                    MqlDateTime dealTimeStruct;
                    TimeToStruct(dealTime, dealTimeStruct);
                    if(dealTimeStruct.day == currentTimeStruct.day) {
                        todayPL += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                    }
                }
            }
        }
    }
    
    dailyPL = todayPL;
}

//+------------------------------------------------------------------+
//| ANALYSE PRINCIPALE                                          |
//+------------------------------------------------------------------+

void AnalyzeMarketStructure() {
    int barsToAnalyze = 100;
    
    for(int i = barsToAnalyze; i >= 0; i--) {
        datetime barTime = iTime(_Symbol, PrimaryTF, i);
        
        // Détecter swing highs
        if(IsSwingHigh(i, PrimaryTF)) {
            double swingHigh = iHigh(_Symbol, PrimaryTF, i);
            
            if(swingHigh > marketStructure.lastSwingHigh) {
                marketStructure.lastSwingHigh = swingHigh;
                marketStructure.lastSwingHighTime = barTime;
                
                AddLiquidityZone(swingHigh, barTime, "SWING_HIGH", 0.8);
            }
            
            // Vérifier equal high
            if(marketStructure.currentEqualHigh > 0 && IsEqualHigh(swingHigh, marketStructure.currentEqualHigh)) {
                marketStructure.equalHighTouches++;
                if(marketStructure.equalHighTouches >= MinEqualTouches) {
                    AddLiquidityZone(marketStructure.currentEqualHigh, barTime, "EQUAL_HIGH", 0.9);
                }
            } else {
                marketStructure.currentEqualHigh = swingHigh;
                marketStructure.equalHighTouches = 1;
            }
        }
        
        // Détecter swing lows
        if(IsSwingLow(i, PrimaryTF)) {
            double swingLow = iLow(_Symbol, PrimaryTF, i);
            
            if(swingLow < marketStructure.lastSwingLow || marketStructure.lastSwingLow == 0.0) {
                marketStructure.lastSwingLow = swingLow;
                marketStructure.lastSwingLowTime = barTime;
                
                AddLiquidityZone(swingLow, barTime, "SWING_LOW", 0.8);
            }
            
            // Vérifier equal low
            if(marketStructure.currentEqualLow > 0 && IsEqualLow(swingLow, marketStructure.currentEqualLow)) {
                marketStructure.equalLowTouches++;
                if(marketStructure.equalLowTouches >= MinEqualTouches) {
                    AddLiquidityZone(marketStructure.currentEqualLow, barTime, "EQUAL_LOW", 0.9);
                }
            } else {
                marketStructure.currentEqualLow = swingLow;
                marketStructure.equalLowTouches = 1;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| TABLEAU DE BORD                                             |
//+------------------------------------------------------------------+

void UpdateDashboard() {
    if(!ShowDashboard) return;
    
    string info = "=== SMC HEDGE FUND STRATEGY ===\n";
    info += "Symbole: " + _Symbol + "\n";
    info += "Timeframe: " + EnumToString(PrimaryTF) + "\n";
    info += "P&L Journalier: $" + DoubleToString(dailyPL, 2) + "\n";
    info += "Trades Journaliers: " + IntegerToString(dailyTradeCount) + "\n";
    info += "Zones de Liquidité: " + IntegerToString(ArraySize(liquidityZones)) + "\n";
    info += "Dernier Swing High: " + DoubleToString(marketStructure.lastSwingHigh, _Digits) + "\n";
    info += "Dernier Swing Low: " + DoubleToString(marketStructure.lastSwingLow, _Digits) + "\n";
    
    if(IsBullishBOS()) info += "Structure: BULLISH BOS\n";
    else if(IsBearishBOS()) info += "Structure: BEARISH BOS\n";
    else info += "Structure: NEUTRAL\n";
    
    Comment(info);
}

//+------------------------------------------------------------------+
//| NETTOYAGE DES OBJETS                                        |
//+------------------------------------------------------------------+

void CleanChartObjects() {
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--) {
        string objName = ObjectName(0, i);
        if(StringFind(objName, "SWEEP_") >= 0 || 
           StringFind(objName, "ENTRY_") >= 0 ||
           StringFind(objName, "SWING_") >= 0 ||
           StringFind(objName, "EQUAL_") >= 0) {
            ObjectDelete(0, objName);
        }
    }
}

//+------------------------------------------------------------------+
//| FONCTIONS PRINCIPALES                                        |
//+------------------------------------------------------------------+

int OnInit() {
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_IOC);
    
    ArrayResize(liquidityZones, 0);
    marketStructure.Reset();
    
    ResetDailyCounters();
    CleanChartObjects();
    
    Print("=== SMC Hedge Fund Strategy Initialisé ===");
    Print("Symbole: ", _Symbol);
    Print("Timeframe: ", EnumToString(PrimaryTF));
    Print("Magic Number: ", MagicNumber);
    
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    CleanChartObjects();
    Comment("");
    
    Print("=== SMC Hedge Fund Strategy Arrêté ===");
    Print("Raison: ", reason);
}

void OnTick() {
    if(!EnableTrading) return;
    
    datetime currentBar = iTime(_Symbol, PrimaryTF, 0);
    
    // Exécuter seulement sur nouvelle barre
    if(currentBar == lastBarTime) return;
    lastBarTime = currentBar;
    
    // Mettre à jour les compteurs journaliers
    UpdateDailyPL();
    
    // Analyser la structure du marché
    AnalyzeMarketStructure();
    
    // Mettre à jour les zones de liquidité
    UpdateLiquidityZones();
    
    // Vérifier les sweeps de liquidité
    if(WaitForSweep) {
        CheckForLiquiditySweep();
    }
    
    // Mettre à jour le tableau de bord
    UpdateDashboard();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    // Gérer les événements de graphique si nécessaire
    if(id == CHARTEVENT_CUSTOM) {
        // Événements personnalisés
    }
}
