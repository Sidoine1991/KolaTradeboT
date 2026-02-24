//+------------------------------------------------------------------+
//| OUTILS D'ANALYSE TECHNIQUE AVANCÉE - FONCTIONS SUPPLÉMENTAIRES      |
//+------------------------------------------------------------------+

#property strict

// Dessiner les EMA comme courbes fluides
void DrawEMACurves()
{
   if(!ShowDashboard) return;
   
   double emaFast[];
   ArraySetAsSeries(emaFast, true);
   if(CopyBuffer(emaFastHandle, 0, 0, 50, emaFast) > 0)
   {
      for(int i = 49; i >= 0; i--)
      {
         datetime time[];
         ArraySetAsSeries(time, true);
         if(CopyTime(_Symbol, PERIOD_M1, i, 1, time) > 0)
         {
            string curveName = "EMA_Fast_Curve_" + IntegerToString(i);
            ObjectCreate(0, curveName, OBJ_TREND, 0, time[i], emaFast[i]);
            ObjectSetInteger(0, curveName, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, curveName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, curveName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, curveName, OBJPROP_RAY_RIGHT, false);
         }
      }
   }
   
   double emaSlow[];
   ArraySetAsSeries(emaSlow, true);
   if(CopyBuffer(emaSlowHandle, 0, 0, 50, emaSlow) > 0)
   {
      for(int i = 49; i >= 0; i--)
      {
         datetime time[];
         ArraySetAsSeries(time, true);
         if(CopyTime(_Symbol, PERIOD_M1, i, 1, time) > 0)
         {
            string curveName = "EMA_Slow_Curve_" + IntegerToString(i);
            ObjectCreate(0, curveName, OBJ_TREND, 0, time[i], emaSlow[i]);
            ObjectSetInteger(0, curveName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, curveName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, curveName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, curveName, OBJPROP_RAY_RIGHT, false);
         }
      }
   }
}

// Dessiner les retracements de Fibonacci
void DrawFibonacciRetracements()
{
   if(!ShowDashboard) return;
   
   double high[], low[];
   datetime time[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   
   if(CopyHigh(_Symbol, PERIOD_M1, 0, 100, high) < 100 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 100, low) < 100 ||
      CopyTime(_Symbol, PERIOD_M1, 0, 100, time) < 100)
      return;
   
   double recentHigh = high[0], recentLow = low[0];
   int highIndex = 0, lowIndex = 0;
   
   for(int i = 1; i < 100; i++)
   {
      if(high[i] > recentHigh)
      {
         recentHigh = high[i];
         highIndex = i;
      }
      if(low[i] < recentLow)
      {
         recentLow = low[i];
         lowIndex = i;
      }
   }
   
   double fibLevels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
   color fibColors[] = {clrGray, clrYellow, clrOrange, clrRed, clrBlue, clrGreen, clrPurple, clrMagenta};
   
   for(int i = 0; i < 8; i++)
   {
      double fibLevel = recentLow + (recentHigh - recentLow) * fibLevels[i];
      string fibLineName = "FIB_" + DoubleToString(fibLevels[i] * 100, 0);
      ObjectCreate(0, fibLineName, OBJ_HLINE, 0, 0, fibLevel);
      ObjectSetInteger(0, fibLineName, OBJPROP_COLOR, fibColors[i]);
      ObjectSetInteger(0, fibLineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, fibLineName, OBJPROP_WIDTH, 1);
      ObjectSetString(0, fibLineName, OBJPROP_TEXT, DoubleToString(fibLevels[i] * 100, 1) + "%");
   }
}

// Dessiner les Liquidity Squid (zones de liquidité)
void DrawLiquiditySquid()
{
   if(!ShowDashboard) return;
   
   double volume[];
   ArraySetAsSeries(volume, true);
   if(CopyTickVolume(_Symbol, PERIOD_M1, 0, 50, volume) < 50)
      return;
   
   double avgVolume = 0;
   for(int i = 0; i < 50; i++)
   {
      avgVolume += volume[i];
   }
   avgVolume /= 50;
   
   for(int i = 0; i < 50; i++)
   {
      if(volume[i] > avgVolume * 1.5)
      {
         double high[], low[], close[];
         ArraySetAsSeries(high, true);
         ArraySetAsSeries(low, true);
         ArraySetAsSeries(close, true);
         
         if(CopyHigh(_Symbol, PERIOD_M1, i, 1, high) > 0 &&
            CopyLow(_Symbol, PERIOD_M1, i, 1, low) > 0 &&
            CopyClose(_Symbol, PERIOD_M1, i, 1, close) > 0)
         {
            string squidName = "LIQUIDITY_SQUID_" + IntegerToString(i);
            double squidHigh = MathMax(high[0], close[0]);
            double squidLow = MathMin(low[0], close[0]);
            
            ObjectCreate(0, squidName, OBJ_RECTANGLE, 0, 
                        TimeCurrent() - PeriodSeconds(PERIOD_M1) * i, squidLow,
                        TimeCurrent() - PeriodSeconds(PERIOD_M1) * (i-1), squidHigh);
            ObjectSetInteger(0, squidName, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(0, squidName, OBJPROP_BACK_COLOR, clrYellow);
            ObjectSetInteger(0, squidName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, squidName, OBJPROP_WIDTH, 1);
         }
      }
   }
}

// Dessiner les FVG (Fair Value Gaps)
void DrawFVG()
{
   if(!ShowDashboard) return;
   
   double high[], low[], close[];
   datetime time[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);
   
   if(CopyHigh(_Symbol, PERIOD_M1, 0, 20, high) < 20 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 20, low) < 20 ||
      CopyClose(_Symbol, PERIOD_M1, 0, 20, close) < 20 ||
      CopyTime(_Symbol, PERIOD_M1, 0, 20, time) < 20)
      return;
   
   for(int i = 1; i < 19; i++)
   {
      double prevClose = close[i];
      double currHigh = high[i-1];
      double currLow = low[i-1];
      
      if(currHigh > prevClose)
      {
         double fvgSize = currHigh - prevClose;
         if(fvgSize > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5)
         {
            string fvgName = "FVG_BULL_" + IntegerToString(i);
            ObjectCreate(0, fvgName, OBJ_RECTANGLE, 0,
                        time[i-1], prevClose,
                        time[i], currHigh);
            ObjectSetInteger(0, fvgName, OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, fvgName, OBJPROP_BACK_COLOR, clrGreen);
            ObjectSetInteger(0, fvgName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, fvgName, OBJPROP_WIDTH, 2);
         }
      }
      
      if(currLow < prevClose)
      {
         double fvgSize = prevClose - currLow;
         if(fvgSize > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5)
         {
            string fvgName = "FVG_BEAR_" + IntegerToString(i);
            ObjectCreate(0, fvgName, OBJ_RECTANGLE, 0,
                        time[i-1], currLow,
                        time[i], prevClose);
            ObjectSetInteger(0, fvgName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, fvgName, OBJPROP_BACK_COLOR, clrRed);
            ObjectSetInteger(0, fvgName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, fvgName, OBJPROP_WIDTH, 2);
         }
      }
   }
}

// Dessiner les Order Blocks sur H1, M30, M5
void DrawOrderBlocks()
{
   if(!ShowDashboard) return;
   
   ENUM_TIMEFRAMES timeframes[] = {PERIOD_H1, PERIOD_M30, PERIOD_M5};
   color blockColors[] = {clrBlue, clrPurple, clrOrange};
   
   for(int tf = 0; tf < 3; tf++)
   {
      double high[], low[], close[];
      datetime time[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(time, true);
      
      if(CopyHigh(_Symbol, timeframes[tf], 0, 50, high) < 50 ||
         CopyLow(_Symbol, timeframes[tf], 0, 50, low) < 50 ||
         CopyClose(_Symbol, timeframes[tf], 0, 50, close) < 50 ||
         CopyTime(_Symbol, timeframes[tf], 0, 50, time) < 50)
         continue;
      
      for(int i = 2; i < 48; i++)
      {
         double range1 = MathAbs(high[i] - low[i]);
         double range2 = MathAbs(high[i-1] - low[i-1]);
         double range3 = MathAbs(high[i-2] - low[i-2]);
         
         if(range1 > range2 * 1.5 && range1 > range3 * 1.5)
         {
            string blockName = "ORDER_BLOCK_" + IntegerToString(timeframes[tf]) + "_" + IntegerToString(i);
            
            ObjectCreate(0, blockName, OBJ_RECTANGLE, 0,
                        time[i], MathMin(low[i], close[i]),
                        time[i-1], MathMax(high[i], close[i-1]));
            ObjectSetInteger(0, blockName, OBJPROP_COLOR, blockColors[tf]);
            ObjectSetInteger(0, blockName, OBJPROP_BACK_COLOR, blockColors[tf]);
            ObjectSetInteger(0, blockName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, blockName, OBJPROP_WIDTH, 2);
            
            string arrowName = "BLOCK_ARROW_" + IntegerToString(timeframes[tf]) + "_" + IntegerToString(i);
            if(close[i] > close[i-1])
            {
               ObjectCreate(0, arrowName, OBJ_ARROW_UP, 0, time[i], MathMax(high[i], close[i]));
               ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrLime);
            }
            else
            {
               ObjectCreate(0, arrowName, OBJ_ARROW_DOWN, 0, time[i], MathMin(low[i], close[i]));
               ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
            }
            ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
         }
      }
   }
}

//+------------------------------------------------------------------+
