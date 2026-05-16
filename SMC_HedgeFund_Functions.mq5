//+------------------------------------------------------------------+
//| SMC_HedgeFund_Functions.mq5                                   |
//| Fonctions SMC Hedge Fund pour intégration                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| FONCTIONS DE CALCUL                                           |
//+------------------------------------------------------------------+

double SMCCalculateOptimalLotSize(double stopLossPoints) {
    if(stopLossPoints <= 0) return InpLotSize;
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (MaxLossPerTradeDollars / 100.0);
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

double SMCGetATR(int period, ENUM_TIMEFRAMES timeframe) {
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

double SMCGetVolume(int shift, ENUM_TIMEFRAMES timeframe) {
    long volume[];
    ArraySetAsSeries(volume, true);
    if(CopyTickVolume(_Symbol, timeframe, shift, 1, volume) > 0) {
        return (double)volume[0];
    }
    return 0.0;
}

double SMCGetAverageVolume(int period, ENUM_TIMEFRAMES timeframe) {
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

bool SMCIsSwingHigh(int index, ENUM_TIMEFRAMES timeframe) {
    double high = iHigh(_Symbol, timeframe, index);
    
    for(int i = 1; i <= g_smcConfig.swingLookback; i++) {
        if(index + i >= Bars(_Symbol, timeframe)) break;
        if(iHigh(_Symbol, timeframe, index + i) >= high) return false;
    }
    
    for(int i = 1; i <= g_smcConfig.swingLookback; i++) {
        if(index - i < 0) break;
        if(iHigh(_Symbol, timeframe, index - i) >= high) return false;
    }
    
    return true;
}

bool SMCIsSwingLow(int index, ENUM_TIMEFRAMES timeframe) {
    double low = iLow(_Symbol, timeframe, index);
    
    for(int i = 1; i <= g_smcConfig.swingLookback; i++) {
        if(index + i >= Bars(_Symbol, timeframe)) break;
        if(iLow(_Symbol, timeframe, index + i) <= low) return false;
    }
    
    for(int i = 1; i <= g_smcConfig.swingLookback; i++) {
        if(index - i < 0) break;
        if(iLow(_Symbol, timeframe, index - i) <= low) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| DÉTECTION EQUAL HIGHS/LOWS                                   |
//+------------------------------------------------------------------+

bool SMCIsEqualHigh(double price1, double price2) {
    return MathAbs(price1 - price2) <= g_smcConfig.equalTolerance * _Point;
}

bool SMCIsEqualLow(double price1, double price2) {
    return MathAbs(price1 - price2) <= g_smcConfig.equalTolerance * _Point;
}

//+------------------------------------------------------------------+
//| BREAK OF STRUCTURE (BOS)                                      |
//+------------------------------------------------------------------+

bool SMCIsBullishBOS() {
    if(g_smcMarketStructure.lastSwingHigh == 0.0) return false;
    
    double currentClose = iClose(_Symbol, PERIOD_M15, 0);
    return currentClose > g_smcMarketStructure.lastSwingHigh;
}

bool SMCIsBearishBOS() {
    if(g_smcMarketStructure.lastSwingLow == 0.0) return false;
    
    double currentClose = iClose(_Symbol, PERIOD_M15, 0);
    return currentClose < g_smcMarketStructure.lastSwingLow;
}

//+------------------------------------------------------------------+
//| DÉTECTION DE SWEEP DE LIQUIDITÉ                             |
//+------------------------------------------------------------------+

bool SMCIsLiquiditySweepAbove(double zonePrice) {
    double currentHigh = iHigh(_Symbol, PERIOD_M15, 1);
    double previousHigh = iHigh(_Symbol, PERIOD_M15, 2);
    
    return currentHigh > zonePrice && previousHigh <= zonePrice;
}

bool SMCIsLiquiditySweepBelow(double zonePrice) {
    double currentLow = iLow(_Symbol, PERIOD_M15, 1);
    double previousLow = iLow(_Symbol, PERIOD_M15, 2);
    
    return currentLow < zonePrice && previousLow >= zonePrice;
}

//+------------------------------------------------------------------+
//| GESTION DES ZONES DE LIQUIDITÉ                             |
//+------------------------------------------------------------------+

void SMCAddLiquidityZone(double price, datetime time, string type, double strength) {
    if(ArraySize(g_smcLiquidityZones) >= g_smcConfig.maxLiquidityZones) {
        // Supprimer la plus ancienne zone
        for(int i = ArraySize(g_smcLiquidityZones) - 1; i > 0; i--) {
            g_smcLiquidityZones[i] = g_smcLiquidityZones[i-1];
        }
        ArrayResize(g_smcLiquidityZones, ArraySize(g_smcLiquidityZones) - 1);
    }
    
    int newSize = ArraySize(g_smcLiquidityZones) + 1;
    ArrayResize(g_smcLiquidityZones, newSize);
    
    LiquidityZone newZone;
    newZone.price = price;
    newZone.time = time;
    newZone.type = type;
    newZone.strength = strength;
    newZone.touches = 1;
    newZone.isActive = true;
    newZone.objectId = type + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
    
    g_smcLiquidityZones[newSize - 1] = newZone;
    
    if(g_smcConfig.showLiquidityZones) {
        SMCDrawLiquidityZone(newZone);
    }
}

void SMCUpdateLiquidityZones() {
    for(int i = 0; i < ArraySize(g_smcLiquidityZones); i++) {
        if(!g_smcLiquidityZones[i].isActive) continue;
        
        // Vérifier si le prix touche la zone
        double currentHigh = iHigh(_Symbol, PERIOD_M15, 0);
        double currentLow = iLow(_Symbol, PERIOD_M15, 0);
        
        bool touched = false;
        if(g_smcLiquidityZones[i].type == "SWING_HIGH" || g_smcLiquidityZones[i].type == "EQUAL_HIGH") {
            touched = currentHigh >= g_smcLiquidityZones[i].price && currentLow <= g_smcLiquidityZones[i].price;
        } else if(g_smcLiquidityZones[i].type == "SWING_LOW" || g_smcLiquidityZones[i].type == "EQUAL_LOW") {
            touched = currentLow <= g_smcLiquidityZones[i].price && currentHigh >= g_smcLiquidityZones[i].price;
        }
        
        if(touched) {
            g_smcLiquidityZones[i].touches++;
            
            // Mettre à jour equal highs/lows
            if(g_smcLiquidityZones[i].type == "EQUAL_HIGH" || g_smcLiquidityZones[i].type == "EQUAL_LOW") {
                SMCUpdateEqualZone(g_smcLiquidityZones[i]);
            }
        }
    }
}

void SMCUpdateEqualZone(LiquidityZone &zone) {
    if(zone.type == "EQUAL_HIGH") {
        g_smcMarketStructure.equalHighTouches++;
        if(g_smcMarketStructure.equalHighTouches >= g_smcConfig.minEqualTouches) {
            zone.strength = MathMin(1.0, zone.strength + 0.2);
        }
    } else if(zone.type == "EQUAL_LOW") {
        g_smcMarketStructure.equalLowTouches++;
        if(g_smcMarketStructure.equalLowTouches >= g_smcConfig.minEqualTouches) {
            zone.strength = MathMin(1.0, zone.strength + 0.2);
        }
    }
}

//+------------------------------------------------------------------+
//| FONCTIONS DE DESSIN                                          |
//+------------------------------------------------------------------+

void SMCDrawLiquidityZone(LiquidityZone &zone) {
    string objName = zone.objectId;
    
    if(ObjectFind(0, objName) >= 0) {
        ObjectDelete(0, objName);
    }
    
    ObjectCreate(0, objName, OBJ_HLINE, 0, 0, zone.price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, g_smcConfig.liquidityColor);
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
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, g_smcConfig.liquidityColor);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void SMCDrawSweep(string direction, double price, datetime time) {
    if(!g_smcConfig.showSweeps) return;
    
    string objName = "SMC_SWEEP_" + direction + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
    
    ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, g_smcConfig.sweepColor);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 4);
    ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, direction == "BUY" ? 233 : 234);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void SMCDrawEntry(string direction, double price, datetime time) {
    if(!g_smcConfig.showEntries) return;
    
    string objName = "SMC_ENTRY_" + direction + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
    
    ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, g_smcConfig.entryColor);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 4);
    ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, direction == "BUY" ? 236 : 238);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| LOGIQUE D'ENTRÉE                                           |
//+------------------------------------------------------------------+

void SMCCheckForLiquiditySweep() {
    double currentPrice = iClose(_Symbol, PERIOD_M15, 0);
    double atr = SMCGetATR(14, PERIOD_M15);
    
    for(int i = 0; i < ArraySize(g_smcLiquidityZones); i++) {
        if(!g_smcLiquidityZones[i].isActive || g_smcLiquidityZones[i].strength < g_smcConfig.liquidityStrength) continue;
        
        bool sweepDetected = false;
        string direction = "";
        
        // Vérifier sweep au-dessus (pour entrée BUY)
        if((g_smcLiquidityZones[i].type == "SWING_HIGH" || g_smcLiquidityZones[i].type == "EQUAL_HIGH") && 
           SMCIsLiquiditySweepBelow(g_smcLiquidityZones[i].price)) {
            
            sweepDetected = true;
            direction = "BUY";
            
            // Confirmation BOS
            if(g_smcConfig.confirmBreakOfStructure && !SMCIsBullishBOS()) continue;
            
        }
        // Vérifier sweep en dessous (pour entrée SELL)
        else if((g_smcLiquidityZones[i].type == "SWING_LOW" || g_smcLiquidityZones[i].type == "EQUAL_LOW") && 
                SMCIsLiquiditySweepAbove(g_smcLiquidityZones[i].price)) {
            
            sweepDetected = true;
            direction = "SELL";
            
            // Confirmation BOS
            if(g_smcConfig.confirmBreakOfStructure && !SMCIsBearishBOS()) continue;
        }
        
        if(sweepDetected) {
            // Confirmation volume
            if(g_smcConfig.useVolumeConfirmation) {
                double currentVolume = SMCGetVolume(1, PERIOD_M15);
                double avgVolume = SMCGetAverageVolume(20, PERIOD_M15);
                if(currentVolume < avgVolume * 1.2) continue;
            }
            
            // Vérifier mouvement après sweep
            if(direction == "BUY") {
                double lowAfterSweep = iLow(_Symbol, PERIOD_M15, 0);
                if(lowAfterSweep > g_smcLiquidityZones[i].price + g_smcConfig.minMoveAfterSweep * _Point) {
                    SMCDrawSweep(direction, g_smcLiquidityZones[i].price, TimeCurrent());
                    // Publier Global Variable pour SMC_Universal_Enhanced
                    GlobalVariableSet("SMC_SWEEP_" + _Symbol + "_DETECTED", 1.0);
                    GlobalVariableSet("SMC_SWEEP_" + _Symbol + "_DIRECTION", direction == "BUY" ? 1.0 : -1.0);
                    GlobalVariableSet("SMC_SWEEP_" + _Symbol + "_PRICE", g_smcLiquidityZones[i].price);
                }
            } else if(direction == "SELL") {
                double highAfterSweep = iHigh(_Symbol, PERIOD_M15, 0);
                if(highAfterSweep < g_smcLiquidityZones[i].price - g_smcConfig.minMoveAfterSweep * _Point) {
                    SMCDrawSweep(direction, g_smcLiquidityZones[i].price, TimeCurrent());
                    // Publier Global Variable pour SMC_Universal_Enhanced
                    GlobalVariableSet("SMC_SWEEP_" + _Symbol + "_DETECTED", 1.0);
                    GlobalVariableSet("SMC_SWEEP_" + _Symbol + "_DIRECTION", direction == "BUY" ? 1.0 : -1.0);
                    GlobalVariableSet("SMC_SWEEP_" + _Symbol + "_PRICE", g_smcLiquidityZones[i].price);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| GESTION DES RISQUES                                         |
//+------------------------------------------------------------------+

bool SMCCheckTradingConditions() {
    // Vérifier perte journalière
    if(g_smcDailyPL < -MathAbs(g_smcConfig.maxDailyLoss)) {
        Print("SMC: Perte journalière maximale atteinte");
        return false;
    }
    
    // Vérifier nombre de trades journaliers
    if(g_smcDailyTradeCount >= g_smcConfig.maxDailyTrades) {
        Print("SMC: Nombre maximum de trades journaliers atteint");
        return false;
    }
    
    // Vérifier spread
    double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
    if(spread > g_smcConfig.maxSpreadPoints) {
        Print("SMC: Spread trop élevé: ", spread, " points");
        return false;
    }
    
    return true;
}

void SMCResetDailyCounters() {
    g_smcDailyPL = 0.0;
    g_smcDailyTradeCount = 0;
    g_smcDailyResetTime = TimeCurrent();
    Print("SMC: Compteurs journaliers réinitialisés");
}

void SMCUpdateDailyPL() {
    datetime currentTime = TimeCurrent();
    
    // Réinitialiser à minuit
    MqlDateTime currentTimeStruct, resetTimeStruct;
    TimeToStruct(currentTime, currentTimeStruct);
    TimeToStruct(g_smcDailyResetTime, resetTimeStruct);
    
    if(currentTimeStruct.day != resetTimeStruct.day) {
        SMCResetDailyCounters();
        return;
    }
    
    // Calculer P&L du jour
    double todayPL = 0.0;
    for(int i = 0; i < HistoryDealsTotal(); i++) {
        if(HistorySelect(0, TimeCurrent())) {
            if(HistoryDealSelect(i)) {
                ulong dealTicket = HistoryDealGetTicket(i);
                if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagicNumber) {
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
    
    g_smcDailyPL = todayPL;
}

//+------------------------------------------------------------------+
//| ANALYSE PRINCIPALE                                          |
//+------------------------------------------------------------------+

void SMCAnalyzeMarketStructure() {
    int barsToAnalyze = 100;
    
    for(int i = barsToAnalyze; i >= 0; i--) {
        datetime barTime = iTime(_Symbol, PERIOD_M15, i);
        
        // Détecter swing highs
        if(SMCIsSwingHigh(i, PERIOD_M15)) {
            double swingHigh = iHigh(_Symbol, PERIOD_M15, i);
            
            if(swingHigh > g_smcMarketStructure.lastSwingHigh) {
                g_smcMarketStructure.lastSwingHigh = swingHigh;
                g_smcMarketStructure.lastSwingHighTime = barTime;
                
                SMCAddLiquidityZone(swingHigh, barTime, "SWING_HIGH", 0.8);
            }
            
            // Vérifier equal high
            if(g_smcMarketStructure.currentEqualHigh > 0 && SMCIsEqualHigh(swingHigh, g_smcMarketStructure.currentEqualHigh)) {
                g_smcMarketStructure.equalHighTouches++;
                if(g_smcMarketStructure.equalHighTouches >= g_smcConfig.minEqualTouches) {
                    SMCAddLiquidityZone(g_smcMarketStructure.currentEqualHigh, barTime, "EQUAL_HIGH", 0.9);
                }
            } else {
                g_smcMarketStructure.currentEqualHigh = swingHigh;
                g_smcMarketStructure.equalHighTouches = 1;
            }
        }
        
        // Détecter swing lows
        if(SMCIsSwingLow(i, PERIOD_M15)) {
            double swingLow = iLow(_Symbol, PERIOD_M15, i);
            
            if(swingLow < g_smcMarketStructure.lastSwingLow || g_smcMarketStructure.lastSwingLow == 0.0) {
                g_smcMarketStructure.lastSwingLow = swingLow;
                g_smcMarketStructure.lastSwingLowTime = barTime;
                
                SMCAddLiquidityZone(swingLow, barTime, "SWING_LOW", 0.8);
            }
            
            // Vérifier equal low
            if(g_smcMarketStructure.currentEqualLow > 0 && SMCIsEqualLow(swingLow, g_smcMarketStructure.currentEqualLow)) {
                g_smcMarketStructure.equalLowTouches++;
                if(g_smcMarketStructure.equalLowTouches >= g_smcConfig.minEqualTouches) {
                    SMCAddLiquidityZone(g_smcMarketStructure.currentEqualLow, barTime, "EQUAL_LOW", 0.9);
                }
            } else {
                g_smcMarketStructure.currentEqualLow = swingLow;
                g_smcMarketStructure.equalLowTouches = 1;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| TABLEAU DE BORD                                             |
//+------------------------------------------------------------------+

void SMCUpdateDashboard() {
    if(!g_smcConfig.showDashboard) return;
    
    string info = "=== SMC HEDGE FUND ===\n";
    info += "Zones: " + IntegerToString(ArraySize(g_smcLiquidityZones)) + "\n";
    info += "P&L: $" + DoubleToString(g_smcDailyPL, 2) + "\n";
    info += "Trades: " + IntegerToString(g_smcDailyTradeCount) + "\n";
    
    if(SMCIsBullishBOS()) info += "Structure: BULLISH BOS\n";
    else if(SMCIsBearishBOS()) info += "Structure: BEARISH BOS\n";
    else info += "Structure: NEUTRAL\n";
    
    Comment(info);
}

//+------------------------------------------------------------------+
//| NETTOYAGE DES OBJETS                                        |
//+------------------------------------------------------------------+

void SMCCleanChartObjects() {
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--) {
        string objName = ObjectName(0, i);
        if(StringFind(objName, "SMC_") >= 0) {
            ObjectDelete(0, objName);
        }
    }
}

//+------------------------------------------------------------------+
//| FONCTION PRINCIPALE SMC                                     |
//+------------------------------------------------------------------+

void SMCProcess() {
    if(!EnableSMCHedgeFund) return;
    
    datetime currentBar = iTime(_Symbol, PERIOD_M15, 0);
    
    // Exécuter seulement sur nouvelle barre
    if(currentBar == g_smcLastBarTime) return;
    g_smcLastBarTime = currentBar;
    
    // Mettre à jour les compteurs journaliers
    SMCUpdateDailyPL();
    
    // Analyser la structure du marché
    SMCAnalyzeMarketStructure();
    
    // Mettre à jour les zones de liquidité
    SMCUpdateLiquidityZones();
    
    // Vérifier les sweeps de liquidité
    if(g_smcConfig.waitForSweep) {
        SMCCheckForLiquiditySweep();
    }
    
    // Mettre à jour le tableau de bord
    SMCUpdateDashboard();
}
