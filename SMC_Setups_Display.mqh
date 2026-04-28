//| MATÉRIALISATION DES SETUPS SMC SUR GRAPHIQUE                   |
//| Dessine les setups OTE, BOS, CHOCH détectés                    |

// Dessiner un setup OTE (Optimal Trade Entry)
void DrawOTESetup(double entryPrice, double stopLoss, double takeProfit, string direction)
{
   // Supprimer les anciens objets OTE
   ObjectsDeleteAll(0, "OTE_SETUP_");
   
   datetime currentTime = TimeCurrent();
   datetime futureTime = currentTime + PeriodSeconds(PERIOD_M1) * 20;
   
   // Zone d'entrée OTE
   string entryZone = "OTE_SETUP_ENTRY_ZONE";
   ObjectCreate(0, entryZone, OBJ_RECTANGLE, 0, currentTime, entryPrice - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2, 
                futureTime, entryPrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2);
   ObjectSetInteger(0, entryZone, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, entryZone, OBJPROP_BGCOLOR, C'220,220,255');
   ObjectSetInteger(0, entryZone, OBJPROP_FILL, true);
   ObjectSetInteger(0, entryZone, OBJPROP_BACK, true);
   ObjectSetInteger(0, entryZone, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, entryZone, OBJPROP_WIDTH, 1);
   
   // Ligne d'entrée
   string entryLine = "OTE_SETUP_ENTRY_LINE";
   ObjectCreate(0, entryLine, OBJ_HLINE, 0, currentTime, entryPrice);
   ObjectSetInteger(0, entryLine, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, entryLine, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, entryLine, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, entryLine, OBJPROP_BACK, false);
   
   // Ligne SL
   string slLine = "OTE_SETUP_SL_LINE";
   ObjectCreate(0, slLine, OBJ_HLINE, 0, currentTime, stopLoss);
   ObjectSetInteger(0, slLine, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, slLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, slLine, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, slLine, OBJPROP_BACK, false);
   
   // Ligne TP
   string tpLine = "OTE_SETUP_TP_LINE";
   ObjectCreate(0, tpLine, OBJ_HLINE, 0, currentTime, takeProfit);
   ObjectSetInteger(0, tpLine, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, tpLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, tpLine, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, tpLine, OBJPROP_BACK, false);
   
   // Labels
   string entryLabel = "OTE_SETUP_ENTRY_LABEL";
   ObjectCreate(0, entryLabel, OBJ_TEXT, 0, currentTime + PeriodSeconds(PERIOD_M1) * 2, entryPrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5);
   ObjectSetString(0, entryLabel, OBJPROP_TEXT, "OTE Entry " + direction + " @" + DoubleToString(entryPrice, _Digits));
   ObjectSetInteger(0, entryLabel, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, entryLabel, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, entryLabel, OBJPROP_BACK, false);
   
   string slLabel = "OTE_SETUP_SL_LABEL";
   ObjectCreate(0, slLabel, OBJ_TEXT, 0, currentTime + PeriodSeconds(PERIOD_M1) * 2, stopLoss - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 3);
   ObjectSetString(0, slLabel, OBJPROP_TEXT, "SL @" + DoubleToString(stopLoss, _Digits));
   ObjectSetInteger(0, slLabel, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, slLabel, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, slLabel, OBJPROP_BACK, false);
   
   string tpLabel = "OTE_SETUP_TP_LABEL";
   ObjectCreate(0, tpLabel, OBJ_TEXT, 0, currentTime + PeriodSeconds(PERIOD_M1) * 2, takeProfit + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 3);
   ObjectSetString(0, tpLabel, OBJPROP_TEXT, "TP @" + DoubleToString(takeProfit, _Digits));
   ObjectSetInteger(0, tpLabel, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, tpLabel, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, tpLabel, OBJPROP_BACK, false);
   
   // Titre du setup
   string title = "OTE_SETUP_TITLE";
   ObjectCreate(0, title, OBJ_TEXT, 0, currentTime, takeProfit + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
   ObjectSetString(0, title, OBJPROP_TEXT, "⚡ OTE SETUP - " + direction + " ⚡");
   ObjectSetInteger(0, title, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, title, OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, title, OBJPROP_BACK, false);
   
   Print("🎯 SETUP OTE MATÉRIALISÉ - ", direction, " ", _Symbol);
   Print("   📍 Entry: ", DoubleToString(entryPrice, _Digits));
   Print("   🛡️ SL: ", DoubleToString(stopLoss, _Digits));
   Print("   🎯 TP: ", DoubleToString(takeProfit, _Digits));
}

// Dessiner un setup BOS (Break of Structure)
void DrawBOSSetup(double breakPrice, string direction, datetime breakTime)
{
   // Supprimer les anciens objets BOS
   ObjectsDeleteAll(0, "BOS_SETUP_");
   
   datetime futureTime = breakTime + PeriodSeconds(PERIOD_M1) * 30;
   
   // Ligne de breakout BOS
   string bosLine = "BOS_SETUP_BREAK_LINE";
   ObjectCreate(0, bosLine, OBJ_TREND, 0, breakTime, breakPrice, futureTime, breakPrice);
   ObjectSetInteger(0, bosLine, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, bosLine, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, bosLine, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, bosLine, OBJPROP_BACK, false);
   
   // Flèche de direction
   string arrow = "BOS_SETUP_ARROW";
   ObjectCreate(0, arrow, OBJ_ARROW, 0, breakTime + PeriodSeconds(PERIOD_M1) * 5, 
                direction == "BUY" ? breakPrice - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10 : 
                                   breakPrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
   ObjectSetInteger(0, arrow, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, arrow, OBJPROP_ARROWCODE, direction == "BUY" ? 233 : 234);
   ObjectSetInteger(0, arrow, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, arrow, OBJPROP_BACK, false);
   
   // Label BOS
   string bosLabel = "BOS_SETUP_LABEL";
   ObjectCreate(0, bosLabel, OBJ_TEXT, 0, breakTime + PeriodSeconds(PERIOD_M1) * 2, 
                direction == "BUY" ? breakPrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5 : 
                                   breakPrice - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5);
   ObjectSetString(0, bosLabel, OBJPROP_TEXT, "🔥 BOS " + direction + " 🔥");
   ObjectSetInteger(0, bosLabel, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, bosLabel, OBJPROP_FONTSIZE, 11);
   ObjectSetInteger(0, bosLabel, OBJPROP_BACK, false);
   
   Print("🔥 SETUP BOS MATÉRIALISÉ - ", direction, " @ ", DoubleToString(breakPrice, _Digits), " ", _Symbol);
}

// Dessiner un setup CHOCH (Change of Character)
void DrawCHOCHSetup(double changePrice, string direction, datetime changeTime)
{
   // Supprimer les anciens objets CHOCH
   ObjectsDeleteAll(0, "CHOCH_SETUP_");
   
   datetime futureTime = changeTime + PeriodSeconds(PERIOD_M1) * 25;
   
   // Zone de changement CHOCH
   string chochZone = "CHOCH_SETUP_ZONE";
   ObjectCreate(0, chochZone, OBJ_RECTANGLE, 0, changeTime, 
                changePrice - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 3,
                futureTime, changePrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 3);
   ObjectSetInteger(0, chochZone, OBJPROP_COLOR, clrPurple);
   ObjectSetInteger(0, chochZone, OBJPROP_BGCOLOR, C'200,150,255');
   ObjectSetInteger(0, chochZone, OBJPROP_FILL, true);
   ObjectSetInteger(0, chochZone, OBJPROP_BACK, true);
   ObjectSetInteger(0, chochZone, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, chochZone, OBJPROP_WIDTH, 2);
   
   // Ligne de changement
   string changeLine = "CHOCH_SETUP_CHANGE_LINE";
   ObjectCreate(0, changeLine, OBJ_HLINE, 0, changeTime, changePrice);
   ObjectSetInteger(0, changeLine, OBJPROP_COLOR, clrPurple);
   ObjectSetInteger(0, changeLine, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, changeLine, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, changeLine, OBJPROP_BACK, false);
   
   // Marqueur de changement
   string marker = "CHOCH_SETUP_MARKER";
   ObjectCreate(0, marker, OBJ_ARROW, 0, changeTime, changePrice);
   ObjectSetInteger(0, marker, OBJPROP_COLOR, clrPurple);
   ObjectSetInteger(0, marker, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(0, marker, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, marker, OBJPROP_BACK, false);
   
   // Label CHOCH
   string chochLabel = "CHOCH_SETUP_LABEL";
   ObjectCreate(0, chochLabel, OBJ_TEXT, 0, changeTime + PeriodSeconds(PERIOD_M1) * 3, 
                changePrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 8);
   ObjectSetString(0, chochLabel, OBJPROP_TEXT, "🔄 CHOCH " + direction + " 🔄");
   ObjectSetInteger(0, chochLabel, OBJPROP_COLOR, clrPurple);
   ObjectSetInteger(0, chochLabel, OBJPROP_FONTSIZE, 11);
   ObjectSetInteger(0, chochLabel, OBJPROP_BACK, false);
   
   Print("🔄 SETUP CHOCH MATÉRIALISÉ - ", direction, " @ ", DoubleToString(changePrice, _Digits), " ", _Symbol);
}

// Nettoyer tous les setups SMC
void ClearAllSMCSetups()
{
   ObjectsDeleteAll(0, "OTE_SETUP_");
   ObjectsDeleteAll(0, "BOS_SETUP_");
   ObjectsDeleteAll(0, "CHOCH_SETUP_");
   Print("🧹 TOUS LES SETUPS SMC NETTOYÉS - ", _Symbol);
}
