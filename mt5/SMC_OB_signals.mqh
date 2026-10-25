//+------------------------------------------------------------------+
//| SMC / Order Block lightweight signals (filtre ou déclencheur)    |
//| Intégration safe pour F_INX_robot4                               |
//+------------------------------------------------------------------+

#ifndef SMC_OB_PARAMS_DECLARED
// Paramètres SMC (inputs définis dans le robot principal)
extern bool   Use_SMC_OB_Filter;
extern bool   Use_SMC_OB_Entries;
extern ENUM_TIMEFRAMES SMC_HTF;
extern ENUM_TIMEFRAMES SMC_LTF;
extern double SMC_OB_ATR_Tolerance;
extern double SMC_OB_SL_ATR;
extern double SMC_OB_TP_ATR;
extern bool   SMC_DrawZones;
#endif

// ------------------------------------------------------------------
// Helpers temps (périodes en secondes)
int _SMC_PeriodSeconds(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:   return 60;
      case PERIOD_M5:   return 300;
      case PERIOD_M15:  return 900;
      case PERIOD_M30:  return 1800;
      case PERIOD_H1:   return 3600;
      case PERIOD_H4:   return 14400;
      case PERIOD_D1:   return 86400;
      default:          return 300;
   }
}

// Handles internes
int smc_atr_handle    = INVALID_HANDLE;
int smc_ma_fast_handle= INVALID_HANDLE;
int smc_ma_slow_handle= INVALID_HANDLE;

// Noms d'objets pour affichage
string SMC_SR_PREFIX = "SMC_OB_ZONE_";

// Initialisation des indicateurs SMC (appelée depuis OnInit)
bool SMC_Init()
{
   smc_atr_handle     = iATR(_Symbol, SMC_HTF, 14);
   smc_ma_fast_handle = iMA(_Symbol, SMC_LTF, 20, 0, MODE_SMA, PRICE_CLOSE);
   smc_ma_slow_handle = iMA(_Symbol, SMC_LTF, 50, 0, MODE_SMA, PRICE_CLOSE);
   
   if(smc_atr_handle == INVALID_HANDLE || smc_ma_fast_handle == INVALID_HANDLE || smc_ma_slow_handle == INVALID_HANDLE)
   {
      Print("SMC_INIT: échec création handles (ATR/MA)");
      return false;
   }
   return true;
}

// Libération des handles (appelée depuis OnDeinit)
void SMC_Deinit()
{
   if(smc_atr_handle != INVALID_HANDLE)     { IndicatorRelease(smc_atr_handle);     smc_atr_handle = INVALID_HANDLE; }
   if(smc_ma_fast_handle != INVALID_HANDLE) { IndicatorRelease(smc_ma_fast_handle); smc_ma_fast_handle = INVALID_HANDLE; }
   if(smc_ma_slow_handle != INVALID_HANDLE) { IndicatorRelease(smc_ma_slow_handle); smc_ma_slow_handle = INVALID_HANDLE; }
}

// Détection simple de niveaux S/R (pivots) sur un timeframe donné
int SMC_FindSRLevels(ENUM_TIMEFRAMES tf, double &levels[])
{
   int barsToCopy = 200;
   double highs[], lows[];
   ArrayResize(highs, barsToCopy);
   ArrayResize(lows, barsToCopy);
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   int copiedHigh = CopyHigh(_Symbol, tf, 0, barsToCopy, highs);
   int copiedLow  = CopyLow(_Symbol, tf, 0, barsToCopy, lows);
   if(copiedHigh <= 0 || copiedLow <= 0) return 0;

   int maxLevels = 10;
   ArrayResize(levels, 0);
   int count = 0;

   // Sommets locaux
   for(int i = 5; i < MathMin(copiedHigh - 5, barsToCopy - 5) && count < maxLevels/2; i++)
   {
      if(highs[i] > highs[i-1] && highs[i] > highs[i+1] && highs[i] > highs[i-2] && highs[i] > highs[i+2])
      {
         ArrayResize(levels, count+1);
         levels[count++] = highs[i];
      }
   }

   // Creux locaux
   for(int i = 5; i < MathMin(copiedLow - 5, barsToCopy - 5) && count < maxLevels; i++)
   {
      if(lows[i] < lows[i-1] && lows[i] < lows[i+1] && lows[i] < lows[i-2] && lows[i] < lows[i+2])
      {
         ArrayResize(levels, count+1);
         levels[count++] = lows[i];
      }
   }
   return count;
}

// Dessin facultatif de la zone de travail
void SMC_DrawZone(string name, double price, color clrLine)
{
   if(!SMC_DrawZones) return;
   string lineName = SMC_SR_PREFIX + name;
   ObjectDelete(0, lineName);
   if(ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, price))
   {
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrLine);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
   }
}

// Dessin rectangle persistant couvrant ~200 bougies passées + projection
void SMC_DrawZoneRect(string name, double centerPrice, double halfHeight, color clrRect)
{
   if(!SMC_DrawZones) return;
   string rectName = SMC_SR_PREFIX + "RECT_" + name;
   datetime tNow = TimeCurrent();
   int tfSec = _SMC_PeriodSeconds(SMC_LTF);
   datetime tStart = tNow - tfSec * 200;  // ~200 bougies en arrière
   datetime tEnd   = tNow + tfSec * 50;   // projection future

   double p1 = centerPrice + halfHeight;
   double p2 = centerPrice - halfHeight;

   if(ObjectFind(0, rectName) < 0)
      ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, tStart, p1, tEnd, p2);
   else
   {
      ObjectSetInteger(0, rectName, OBJPROP_TIME, 0, tStart);
      ObjectSetInteger(0, rectName, OBJPROP_TIME, 1, tEnd);
      ObjectSetDouble(0, rectName, OBJPROP_PRICE, 0, p1);
      ObjectSetDouble(0, rectName, OBJPROP_PRICE, 1, p2);
   }
   ObjectSetInteger(0, rectName, OBJPROP_COLOR, clrRect);
   ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
   ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, rectName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

// Mise à jour autonome des zones (support / résistance) pour affichage
bool SMC_UpdateZones()
{
   if(!SMC_DrawZones) return false;

   double atrBuf[];
   if(smc_atr_handle == INVALID_HANDLE || CopyBuffer(smc_atr_handle, 0, 0, 1, atrBuf) <= 0)
      return false;
   double usedAtr = atrBuf[0];
   if(usedAtr <= 0) return false;

   double levels[];
   int lvlCount = SMC_FindSRLevels(SMC_HTF, levels);
   if(lvlCount == 0) return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid + ask) / 2.0;

   double nearestSupport = 0.0, nearestResistance = 0.0;
   double bestDistSupport = DBL_MAX, bestDistRes = DBL_MAX;
   for(int i=0; i<lvlCount; i++)
   {
      double lvl = levels[i];
      if(lvl <= mid)
      {
         double d = mid - lvl;
         if(d < bestDistSupport) { bestDistSupport = d; nearestSupport = lvl; }
      }
      else
      {
         double d = lvl - mid;
         if(d < bestDistRes) { bestDistRes = d; nearestResistance = lvl; }
      }
   }

   double bufferH = MathMax(usedAtr * SMC_OB_ATR_Tolerance, _Point * 20);
   if(nearestSupport > 0.0 && bestDistSupport < usedAtr * 3.0)
      SMC_DrawZoneRect("BUY", nearestSupport, bufferH, clrLime);
   if(nearestResistance > 0.0 && bestDistRes < usedAtr * 3.0)
      SMC_DrawZoneRect("SELL", nearestResistance, bufferH, clrRed);

   return true;
}

// Génère un signal SMC : renvoie true si un setup est présent
bool SMC_GenerateSignal(bool &isBuy, double &entry, double &sl, double &tp, string &reason, double &usedAtr)
{
   isBuy = false; entry = 0; sl = 0; tp = 0; reason = ""; usedAtr = 0.0;
   
   // Récupérer ATR HTF
   double atrBuf[];
   if(smc_atr_handle == INVALID_HANDLE || CopyBuffer(smc_atr_handle, 0, 0, 1, atrBuf) <= 0)
      return false;
   usedAtr = atrBuf[0];
   if(usedAtr <= 0) return false;

   // Récupérer MA LTF pour la tendance
   double maFast[], maSlow[];
   if(CopyBuffer(smc_ma_fast_handle, 0, 0, 1, maFast) <= 0) return false;
   if(CopyBuffer(smc_ma_slow_handle, 0, 0, 1, maSlow) <= 0) return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid + ask) / 2.0;

   bool upTrend   = (maFast[0] > maSlow[0]);
   bool downTrend = (maFast[0] < maSlow[0]);

   // Support / résistance HTF
   double levels[];
   int lvlCount = SMC_FindSRLevels(SMC_HTF, levels);
   if(lvlCount == 0) return false;

   double nearestSupport = 0.0, nearestResistance = 0.0;
   double bestDistSupport = DBL_MAX, bestDistRes = DBL_MAX;
   for(int i=0; i<lvlCount; i++)
   {
      double lvl = levels[i];
      if(lvl <= mid)
      {
         double d = mid - lvl;
         if(d < bestDistSupport) { bestDistSupport = d; nearestSupport = lvl; }
      }
      else
      {
         double d = lvl - mid;
         if(d < bestDistRes) { bestDistRes = d; nearestResistance = lvl; }
      }
   }

   double tol = usedAtr * SMC_OB_ATR_Tolerance;
   bool buySetup  = upTrend   && nearestSupport   > 0 && bestDistSupport   <= tol;
   bool sellSetup = downTrend && nearestResistance> 0 && bestDistRes      <= tol;

   if(buySetup && (!sellSetup || bestDistSupport <= bestDistRes))
   {
      isBuy = true;
      entry = ask;
      sl    = nearestSupport - SMC_OB_SL_ATR * usedAtr;
      tp    = entry + SMC_OB_TP_ATR * usedAtr;
      reason= StringFormat("SMC OB: support M15/M1 %.5f proche (%.1f%% ATR) + trend up", nearestSupport, bestDistSupport/usedAtr*100.0);
      SMC_DrawZone("BUY", nearestSupport, clrLime);
      return true;
   }
   if(sellSetup)
   {
      isBuy = false;
      entry = bid;
      sl    = nearestResistance + SMC_OB_SL_ATR * usedAtr;
      tp    = entry - SMC_OB_TP_ATR * usedAtr;
      reason= StringFormat("SMC OB: résistance M15/M1 %.5f proche (%.1f%% ATR) + trend down", nearestResistance, bestDistRes/usedAtr*100.0);
      SMC_DrawZone("SELL", nearestResistance, clrRed);
      return true;
   }
   return false;
}

