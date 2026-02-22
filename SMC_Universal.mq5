//+------------------------------------------------------------------+
//| SMC_Universal.mq5                                                 |
//| Robot Smart Money Concepts - UN SEUL ROBOT multi-actifs + IA      |
//| Boom/Crash | Volatility | Forex | Commodities | Metals           |
//| FVG | OB | BOS | LS | OTE | EQH/EQL | P/D | LO/NYO              |
//+------------------------------------------------------------------+
#property copyright "TradBOT SMC"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

//+------------------------------------------------------------------+
//| SMC - Structures et énumérations (intégré)                       |
//+------------------------------------------------------------------+
struct FVGData {
   double top;
   double bottom;
   int direction;
   datetime time;
   bool isInversion;
   int barIndex;
};
struct OrderBlockData {
   double high;
   double low;
   int direction;
   datetime time;
   int barIndex;
   string type;
};
struct SMC_Signal {
   string action;
   double confidence;
   string concept;
   string reasoning;
   double entryPrice;
   double stopLoss;
   double takeProfit;
};
enum ENUM_SYMBOL_CATEGORY {
   SYM_BOOM_CRASH,
   SYM_VOLATILITY,
   SYM_FOREX,
   SYM_COMMODITY,
   SYM_METAL,
   SYM_UNKNOWN
};
ENUM_SYMBOL_CATEGORY SMC_GetSymbolCategory(string symbol)
{
   string s = symbol;
   StringToUpper(s);
   if(StringFind(s, "BOOM") >= 0 || StringFind(s, "CRASH") >= 0) return SYM_BOOM_CRASH;
   if(StringFind(s, "VOLATILITY") >= 0 || StringFind(s, "RANGE BREAK") >= 0) return SYM_VOLATILITY;
   if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0) return SYM_METAL;
   if(StringFind(s, "XAG") >= 0 || StringFind(s, "SILVER") >= 0) return SYM_METAL;
   if(StringFind(s, "OIL") >= 0 || StringFind(s, "COPPER") >= 0) return SYM_COMMODITY;
   if(StringFind(s, "USD") >= 0 || StringFind(s, "EUR") >= 0 || StringFind(s, "GBP") >= 0 || StringFind(s, "JPY") >= 0) return SYM_FOREX;
   return SYM_UNKNOWN;
}
bool SMC_DetectFVG(string symbol, ENUM_TIMEFRAMES tf, int lookback, FVGData &fvgOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, lookback, rates) < lookback) return false;
   for(int i = 2; i < lookback - 1; i++)
   {
      if(rates[i-1].low > rates[i+1].high)
      {
         double gap = rates[i-1].low - rates[i+1].high;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(gap > point * 3) {
            fvgOut.top = rates[i-1].low; fvgOut.bottom = rates[i+1].high; fvgOut.direction = 1;
            fvgOut.time = rates[i].time; fvgOut.isInversion = false; fvgOut.barIndex = i;
            return true;
         }
      }
      if(rates[i-1].high < rates[i+1].low)
      {
         double gap = rates[i+1].low - rates[i-1].high;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(gap > point * 3) {
            fvgOut.top = rates[i+1].low; fvgOut.bottom = rates[i-1].high; fvgOut.direction = -1;
            fvgOut.time = rates[i].time; fvgOut.isInversion = false; fvgOut.barIndex = i;
            return true;
         }
      }
   }
   return false;
}
bool SMC_DetectBOS(string symbol, ENUM_TIMEFRAMES tf, int &directionOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 20, rates) < 20) return false;
   double prevSwingHigh = MathMax(rates[3].high, MathMax(rates[4].high, rates[5].high));
   double prevSwingLow = MathMin(rates[3].low, MathMin(rates[4].low, rates[5].low));
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minBreak = point * 5;
   if(rates[1].close > prevSwingHigh + minBreak) { directionOut = 1; return true; }
   if(rates[1].close < prevSwingLow - minBreak) { directionOut = -1; return true; }
   return false;
}
bool SMC_DetectLiquiditySweep(string symbol, ENUM_TIMEFRAMES tf, string &typeOut)
{
   int barsAgo;
   return SMC_DetectLiquiditySweepEx(symbol, tf, typeOut, barsAgo);
}
bool SMC_DetectLiquiditySweepEx(string symbol, ENUM_TIMEFRAMES tf, string &typeOut, int &barsAgoOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 15, rates) < 15) return false;
   barsAgoOut = 99;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minSweep = point * 5;
   for(int b = 1; b <= 5; b++)
   {
      if(b + 2 >= ArraySize(rates)) break;
      double prevHigh = rates[b+1].high;
      double prevLow = rates[b+1].low;
      double currHigh = rates[b].high;
      double currLow = rates[b].low;
      if(currHigh > prevHigh && (currHigh - prevHigh) > minSweep)
      {
         typeOut = "BSL";
         barsAgoOut = b;
         return true;
      }
      if(currLow < prevLow && (prevLow - currLow) > minSweep)
      {
         typeOut = "SSL";
         barsAgoOut = b;
         return true;
      }
   }
   return false;
}
bool SMC_DetectOrderBlock(string symbol, ENUM_TIMEFRAMES tf, OrderBlockData &obOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 50, rates) < 50) return false;
   for(int i = 3; i < 45; i++)
   {
      if(rates[i].close < rates[i].open && rates[i+1].close > rates[i+1].open)
      {
         double moveUp = rates[i+2].high - rates[i].low;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(moveUp > point * 20) {
            obOut.high = rates[i].high; obOut.low = rates[i].low; obOut.direction = 1;
            obOut.time = rates[i].time; obOut.barIndex = i; obOut.type = "OB";
            return true;
         }
      }
      if(rates[i].close > rates[i].open && rates[i+1].close < rates[i+1].open)
      {
         double moveDown = rates[i].high - rates[i+2].low;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(moveDown > point * 20) {
            obOut.high = rates[i].high; obOut.low = rates[i].low; obOut.direction = -1;
            obOut.time = rates[i].time; obOut.barIndex = i; obOut.type = "OB";
            return true;
         }
      }
   }
   return false;
}
bool SMC_IsLondonOpen(int hourStart, int hourEnd)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= hourStart && dt.hour <= hourEnd);
}
bool SMC_IsNewYorkOpen(int hourStart, int hourEnd)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= hourStart && dt.hour <= hourEnd);
}
bool SMC_IsKillZone(int loStart, int loEnd, int nyoStart, int nyoEnd)
{
   return SMC_IsLondonOpen(loStart, loEnd) || SMC_IsNewYorkOpen(nyoStart, nyoEnd);
}
double SMC_GetATRMultiplier(ENUM_SYMBOL_CATEGORY cat)
{
   switch(cat) {
      case SYM_BOOM_CRASH:  return 1.5;
      case SYM_VOLATILITY:  return 2.0;
      case SYM_FOREX:       return 2.0;
      case SYM_COMMODITY:   return 2.5;
      case SYM_METAL:       return 2.5;
      default:              return 2.0;
   }
}

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input group "=== GÉNÉRAL ==="
input bool   UseMinLotOnly     = true;   // Toujours lot minimum (le plus bas)
input int    MaxPositionsTerminal = 4;   // Nombre max de positions (tout le terminal MT5)
input bool   OnePositionPerSymbol = true; // Une seule position par symbole
input int    MagicNumber       = 202502; // Magic Number
input double MaxTotalLossDollars  = 10.0; // Perte totale max ($) - au-delà on ferme la position la plus perdante
input bool   UseSessions       = true;   // Trader seulement LO/NYO
input bool   ShowChartGraphics = true;   // FVG, OB, Fibo, EMA, Swing H/L sur le graphique
input bool   ShowPremiumDiscount = true; // Zones Premium (vente) / Discount (achat) / Équilibre
input bool   ShowSignalArrow     = true; // Flèche dynamique clignotante BUY/SELL
input bool   ShowPredictedSwing  = true; // SL/SH prédits (futurs) sur le canal
input bool   ShowEMASupportResistance = true; // EMA M1, M5, H1 en support/résistance

input group "=== SL/TP DYNAMIQUES (prudent / sécuriser gain) ==="
input double SL_ATRMult        = 2.5;    // Stop Loss (x ATR) - prudent
input double TP_ATRMult        = 2.5;    // Take Profit (x ATR) - gain sécurisé

input group "=== SMC CONCEPTS ==="
input bool   UseFVG            = true;   // Fair Value Gap
input bool   UseOrderBlocks    = true;   // Order Blocks
input bool   UseLiquiditySweep = true;   // Liquidity Sweep (LS)
input bool   RequireStructureAfterSweep = true; // Smart Money: entrée après confirmation (LS+BOS/FVG/OB)
input bool   NoEntryDuringSweep = true;  // Attendre 1+ barres après le sweep (jamais pendant panique)
input bool   StopBeyondNewStructure = true; // Stop au-delà nouvelle structure (pas niveau évident)
input bool   UseBOS            = true;   // Break Of Structure
input bool   UseOTE            = true;   // Optimal Trade Entry (Fib 0.62-0.79)
input bool   UseEqualHL        = true;   // Equal Highs/Lows (EQH/EQL)

input group "=== TIMEFRAMES ==="
input ENUM_TIMEFRAMES HTF      = PERIOD_H4;  // Structure (HTF)
input ENUM_TIMEFRAMES LTF      = PERIOD_M15; // Entrée (LTF)

input group "=== FVG_Kill PRO (Smart Money) ==="
input bool   UseFVGKillMode    = true;   // Activer logique FVG_Kill (EMA HTF + LS)
input int    EMA50_Period      = 50;     // EMA 50 (HTF)
input int    EMA200_Period     = 200;    // EMA 200 (HTF)
input double ATR_Mult          = 1.8;    // Multiplicateur ATR (SL FVG_Kill)
input bool   UseTrailingStructure = true; // Trailing SL sur structure (LTF bar)
input bool   UseDashboard      = true;   // Tableau de bord FVG_Kill
input bool   BoomCrashMode     = true;   // Boom/Crash: BUY sur Boom, SELL sur Crash

input group "=== SESSIONS (heure serveur) ==="
input bool   TradeOutsideKillZone = true;  // Trader 24/7 (true = ignorer Kill Zone)
input int    LondonStart       = 8;      // London Open début
input int    LondonEnd         = 11;     // London Open fin
input int    NYOStart          = 13;     // New York Open début
input int    NYOEnd            = 16;     // New York Open fin

input group "=== NOTIFICATIONS ==="
input bool   UseNotifications  = true;   // Alert + notification push (signaux et trades)

input group "=== BOUGIES FUTURES ==="
input bool   ShowPredictionChannel = false; // Canal ML désactivé (bougies futures uniquement)
input int    PredictionChannelPastBars = 1000; // (interne)
input int    PredictionChannelBars = 5000;  // (interne)
input bool   ShowMLMetrics         = true;  // Afficher métriques ML (précision, entraînement continu)

input group "=== IA SERVEUR ==="
input bool   UseAIServer       = true;   // Utiliser IA pour confirmation
input bool   RequireAIConfirmation = false; // Exiger confirmation IA pour SMC (false = trader sans IA)
input bool   UseRenderAsPrimary = true;  // Utiliser Render en premier (backend uniquement = true)
input string AI_ServerURL      = "http://localhost:8000";  // URL serveur local
input string AI_ServerRender   = "https://kolatradebot.onrender.com";  // URL Render (backend)
input double MinAIConfidence   = 0.55;   // Confiance IA min pour exécuter
input int    AI_Timeout_ms     = 10000;  // Timeout WebRequest (ms) - Render cold start

input group "=== BOOM/CRASH ==="
input bool   BoomBuyOnly       = true;   // Boom: BUY uniquement
input bool   CrashSellOnly     = true;   // Crash: SELL uniquement
input bool   NoSLTP_BoomCrash  = false;  // Pas de SL/TP sur Boom/Crash (spike)
input double BoomCrashSpikeTP  = 0.01;   // Fermer dès petit gain (spike capté) si profit > ce seuil ($)
input double TargetProfitBoomCrashUSD = 2.0; // Gain à capter ($) - fermer si profit >= ce seuil (Spike_Close)
input double MaxLossDollars    = 6.0;    // Fermer toute position si perte atteint ($)
input double TakeProfitDollars = 2.0;    // Fermer si bénéfice atteint ($) - Volatility/Forex/Commodity

//+------------------------------------------------------------------+
//| GLOBALS                                                           |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo posInfo;
COrderInfo orderInfo;

int atrHandle;
int emaHandle = INVALID_HANDLE;
int ema50H = INVALID_HANDLE;
int ema200H = INVALID_HANDLE;
int fractalH = INVALID_HANDLE;
int emaM1H = INVALID_HANDLE;
int emaM5H = INVALID_HANDLE;
int emaH1H = INVALID_HANDLE;
string g_lastAIAction = "";
string g_lastAIAlignment = "";
string g_lastAICoherence = "";
static datetime g_arrowBlinkTime = 0;
static bool g_arrowVisible = true;
double g_lastAIConfidence = 0;
datetime g_lastAIUpdate = 0;
int g_aiUpdateInterval = 30;
bool g_aiConnected = false;
static double g_lastBoomCrashPrice = 0.0;
static datetime g_lastBoomCrashPriceTime = 0;
double g_lastSwingHigh = 0, g_lastSwingLow = 0;
datetime g_lastSwingHighTime = 0, g_lastSwingLowTime = 0;
static datetime g_lastChannelUpdate = 0;
static bool g_channelValid = false;
static double g_chUpperStart = 0, g_chUpperEnd = 0, g_chLowerStart = 0, g_chLowerEnd = 0;
static datetime g_chTimeStart = 0, g_chTimeEnd = 0;
static string g_mlMetricsStr = "—";
static datetime g_lastMLMetricsUpdate = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   atrHandle = iATR(_Symbol, LTF, 14);
   emaHandle = iMA(_Symbol, LTF, 9, 0, MODE_EMA, PRICE_CLOSE);
   ema50H = iMA(_Symbol, HTF, EMA50_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema200H = iMA(_Symbol, HTF, EMA200_Period, 0, MODE_EMA, PRICE_CLOSE);
   fractalH = iFractals(_Symbol, LTF);
   emaM1H = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
   emaM5H = iMA(_Symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE);
   emaH1H = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("❌ Erreur création ATR");
      return INIT_FAILED;
   }
   if(ema50H != INVALID_HANDLE) ChartIndicatorAdd(0, 0, ema50H);
   if(ema200H != INVALID_HANDLE) ChartIndicatorAdd(0, 0, ema200H);
   if(fractalH != INVALID_HANDLE) ChartIndicatorAdd(0, 0, fractalH);
   ChartSetInteger(0, CHART_SHIFT, 1);
   GlobalVariableSet("SMC_OPEN_LOCK_" + IntegerToString(MagicNumber), 0);
   Print("📊 SMC Universal + FVG_Kill PRO | 1 pos/symbole | Stratégie visible");
   Print("   Catégorie: ", EnumToString(SMC_GetSymbolCategory(_Symbol)));
   Print("   IA: ", UseAIServer ? AI_ServerURL : "Désactivé");
   return INIT_SUCCEEDED;
}

bool TryAcquireOpenLock()
{
   string lockName = "SMC_OPEN_LOCK_" + IntegerToString(MagicNumber);
   int waitMs = 0;
   while(GlobalVariableGet(lockName) != 0 && waitMs < 200) { Sleep(5); waitMs += 5; }
   if(GlobalVariableGet(lockName) != 0) return false;
   GlobalVariableSet(lockName, 1);
   if(CountPositionsOurEA() >= MaxPositionsTerminal) { GlobalVariableSet(lockName, 0); return false; }
   return true;
}
void ReleaseOpenLock() { GlobalVariableSet("SMC_OPEN_LOCK_" + IntegerToString(MagicNumber), 0); }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaHandle != INVALID_HANDLE) IndicatorRelease(emaHandle);
   if(ema50H != INVALID_HANDLE) IndicatorRelease(ema50H);
   if(ema200H != INVALID_HANDLE) IndicatorRelease(ema200H);
   if(fractalH != INVALID_HANDLE) IndicatorRelease(fractalH);
   if(emaM1H != INVALID_HANDLE) IndicatorRelease(emaM1H);
   if(emaM5H != INVALID_HANDLE) IndicatorRelease(emaM5H);
   if(emaH1H != INVALID_HANDLE) IndicatorRelease(emaH1H);
   ObjectsDeleteAll(0, "SMC_");
   Comment("");
}

//+------------------------------------------------------------------+
bool IsBullishHTF()
{
   if(ema50H == INVALID_HANDLE || ema200H == INVALID_HANDLE) return true;
   double f[], s[];
   ArraySetAsSeries(f, true); ArraySetAsSeries(s, true);
   if(CopyBuffer(ema50H, 0, 0, 1, f) < 1 || CopyBuffer(ema200H, 0, 0, 1, s) < 1) return true;
   return f[0] > s[0];
}
bool IsBearishHTF()
{
   if(ema50H == INVALID_HANDLE || ema200H == INVALID_HANDLE) return true;
   double f[], s[];
   ArraySetAsSeries(f, true); ArraySetAsSeries(s, true);
   if(CopyBuffer(ema50H, 0, 0, 1, f) < 1 || CopyBuffer(ema200H, 0, 0, 1, s) < 1) return true;
   return f[0] < s[0];
}
bool FVGKill_LiquiditySweepDetected()
{
   double prevHigh = iHigh(_Symbol, LTF, 2);
   double prevLow  = iLow(_Symbol, LTF, 2);
   double h1 = iHigh(_Symbol, LTF, 1);
   double l1 = iLow(_Symbol, LTF, 1);
   return (h1 > prevHigh || l1 < prevLow);
}
bool FVGKill_SweepConfirmed(int minBarsAgo = 2)
{
   string lsType;
   int barsAgo = 0;
   if(!SMC_DetectLiquiditySweepEx(_Symbol, LTF, lsType, barsAgo)) return false;
   return (barsAgo >= minBarsAgo);
}

bool IsInDiscountZone()
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 100, high) < 100 || CopyLow(_Symbol, PERIOD_H1, 0, 100, low) < 100 || CopyClose(_Symbol, PERIOD_H1, 0, 100, close) < 100) return false;
   int n = ArraySize(close);
   if(n < 25) return false;
   double sma20[];
   ArrayResize(sma20, n);
   ArraySetAsSeries(sma20, true);
   for(int i = 0; i < n - 20; i++) { double s = 0; for(int j = 0; j < 20; j++) s += close[i + j]; sma20[i] = s / 20; }
   for(int i = n - 20; i < n; i++) sma20[i] = sma20[MathMax(0, n - 21)];
   double eq = sma20[0];
   double discLow = low[ArrayMinimum(low, 0, 20)];
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (bid >= discLow && bid <= eq && discLow < eq);
}
bool IsInPremiumZone()
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 100, high) < 100 || CopyLow(_Symbol, PERIOD_H1, 0, 100, low) < 100 || CopyClose(_Symbol, PERIOD_H1, 0, 100, close) < 100) return false;
   int n = ArraySize(close);
   if(n < 25) return false;
   double sma20[];
   ArrayResize(sma20, n);
   ArraySetAsSeries(sma20, true);
   for(int i = 0; i < n - 20; i++) { double s = 0; for(int j = 0; j < 20; j++) s += close[i + j]; sma20[i] = s / 20; }
   for(int i = n - 20; i < n; i++) sma20[i] = sma20[MathMax(0, n - 21)];
   double eq = sma20[0];
   double premHigh = high[ArrayMaximum(high, 0, 20)];
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask >= eq && ask <= premHigh && premHigh > eq);
}
void ExecuteFVGKillBuy()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) return;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, LTF, 0, 3, r) < 3) return;
   double sl = r[1].low - atr[0] * ATR_Mult;
   double tp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - sl) * 2.0;
   if(CountPositionsOurEA() >= MaxPositionsTerminal) return;
   if(!TryAcquireOpenLock()) return;
   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }
   trade.Buy(lot, _Symbol, 0, sl, tp, "FVG_Kill BUY");
   ReleaseOpenLock();
   if(trade.ResultRetcode() == TRADE_RETCODE_DONE && UseNotifications)
   { Alert("FVG_Kill BUY ", _Symbol); SendNotification("FVG_Kill BUY " + _Symbol); }
}
void ExecuteFVGKillSell()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) return;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, LTF, 0, 3, r) < 3) return;
   double sl = r[1].high + atr[0] * ATR_Mult;
   double tp = SymbolInfoDouble(_Symbol, SYMBOL_BID) - (sl - SymbolInfoDouble(_Symbol, SYMBOL_BID)) * 2.0;
   if(CountPositionsOurEA() >= MaxPositionsTerminal) return;
   if(!TryAcquireOpenLock()) return;
   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }
   trade.Sell(lot, _Symbol, 0, sl, tp, "FVG_Kill SELL");
   ReleaseOpenLock();
   if(trade.ResultRetcode() == TRADE_RETCODE_DONE && UseNotifications)
   { Alert("FVG_Kill SELL ", _Symbol); SendNotification("FVG_Kill SELL " + _Symbol); }
}

//+------------------------------------------------------------------+
int CountPositionsForSymbol(string symbol)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == MagicNumber && posInfo.Symbol() == symbol)
         n++;
   return n;
}

int CountPositionsOurEA()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == MagicNumber)
         n++;
   return n;
}

void CloseWorstPositionIfTotalLossExceeded()
{
   double totalProfit = 0;
   double worstProfit = 0;
   ulong worstTicket = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != MagicNumber) continue;
      double p = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      totalProfit += p;
      if(worstTicket == 0 || p < worstProfit)
      {
         worstProfit = p;
         worstTicket = posInfo.Ticket();
      }
   }
   if(totalProfit > -MaxTotalLossDollars) return;
   if(worstTicket != 0 && trade.PositionClose(worstTicket))
      Print("🛑 Perte totale (", DoubleToString(totalProfit, 2), "$) >= ", DoubleToString(MaxTotalLossDollars, 0), "$ → position la plus perdante fermée (", DoubleToString(worstProfit, 2), "$)");
}

// Fermeture par ordre inverse (comme Spike_Close_BoomCrash) pour compatibilité brokers
bool ClosePositionByDeal(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string symbol = PositionGetString(POSITION_SYMBOL);
   double volume = PositionGetDouble(POSITION_VOLUME);
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   request.action   = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol   = symbol;
   request.volume   = volume;
   request.type     = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price    = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID)
                                                   : SymbolInfoDouble(symbol, SYMBOL_ASK);
   request.deviation = 50;
   return OrderSend(request, result);
}

bool CloseBoomCrashPosition(ulong ticket, const string symbol)
{
   if(ClosePositionByDeal(ticket)) return true;
   if(trade.PositionClose(ticket)) return true;
   return false;
}

void CloseBoomCrashAfterSpike(ulong ticket, const string symbol, double currentProfit)
{
   if(!posInfo.SelectByTicket(ticket)) return;
   if(posInfo.Magic() != MagicNumber) return;
   if(SMC_GetSymbolCategory(symbol) != SYM_BOOM_CRASH) return;
   
   // 1) Seuil gain à capter: fermer si profit >= TargetProfitBoomCrashUSD
   if(currentProfit >= TargetProfitBoomCrashUSD)
   {
      if(CloseBoomCrashPosition(ticket, symbol))
      {
         Print("🚀 Boom/Crash fermé (gain >= ", DoubleToString(TargetProfitBoomCrashUSD, 2), "$): ", DoubleToString(currentProfit, 2), "$");
         if(symbol == _Symbol) { g_lastBoomCrashPrice = 0; }
      }
      return;
   }
   
   // 2) Fermer dès qu’en gain (spike capté) pour TOUS les symboles Boom/Crash
   if(currentProfit > BoomCrashSpikeTP)
   {
      if(CloseBoomCrashPosition(ticket, symbol))
      {
         Print("🚀 Boom/Crash fermé après spike (gain > ", DoubleToString(BoomCrashSpikeTP, 2), "$): ", DoubleToString(currentProfit, 2), "$");
         if(symbol == _Symbol) { g_lastBoomCrashPrice = 0; }
      }
      return;
   }
   
   // 3) Détection spike par mouvement de prix (uniquement symbole du graphique)
   if(symbol != _Symbol) return;
   
   double currentPrice = posInfo.PriceCurrent();
   datetime now = TimeCurrent();
   static datetime s_lastRefUpdate = 0;
   bool spikeDetected = false;
   if(g_lastBoomCrashPrice > 0 && (now - s_lastRefUpdate) >= 1)
   {
      double priceChange = MathAbs(currentPrice - g_lastBoomCrashPrice);
      double pct = (g_lastBoomCrashPrice > 0) ? (priceChange / g_lastBoomCrashPrice) * 100.0 : 0;
      if(pct >= 0.08) spikeDetected = true;
   }
   if((now - s_lastRefUpdate) >= 1)
   {
      g_lastBoomCrashPrice = currentPrice;
      g_lastBoomCrashPriceTime = now;
      s_lastRefUpdate = now;
   }
   if(spikeDetected)
   {
      if(CloseBoomCrashPosition(ticket, symbol))
      {
         Print("🚀 Boom/Crash fermé (spike prix ", DoubleToString(currentProfit, 2), "$)");
         g_lastBoomCrashPrice = 0;
         s_lastRefUpdate = 0;
      }
   }
}

// Parcourt toutes les positions et ferme Boom/Crash selon seuil $ ou spike (comme Spike_Close_BoomCrash)
void ManageBoomCrashSpikeClose()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != MagicNumber) continue;
      string symbol = posInfo.Symbol();
      if(SMC_GetSymbolCategory(symbol) != SYM_BOOM_CRASH)
         continue;
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      CloseBoomCrashAfterSpike(posInfo.Ticket(), symbol, profit);
   }
}

void ManageDollarExits()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol) continue;
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      ulong ticket = posInfo.Ticket();
      ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
      if(profit <= -MaxLossDollars)
      {
         if(trade.PositionClose(ticket))
            Print("🛑 Position fermée: perte max atteinte (", DoubleToString(profit, 2), "$)");
         continue;
      }
      if(cat == SYM_BOOM_CRASH)
         continue;
      if((cat == SYM_VOLATILITY || cat == SYM_FOREX || cat == SYM_COMMODITY || cat == SYM_METAL) && profit >= TakeProfitDollars)
      {
         if(trade.PositionClose(ticket))
            Print("✅ Position fermée: bénéfice atteint (", DoubleToString(profit, 2), "$)");
      }
   }
}

void OnTick()
{
   bool inKillZone = TradeOutsideKillZone || !UseSessions || SMC_IsKillZone(LondonStart, LondonEnd, NYOStart, NYOEnd);
   bool underMaxPos = (CountPositionsOurEA() < MaxPositionsTerminal);
   bool canOpenThisSymbol = !OnePositionPerSymbol || (CountPositionsForSymbol(_Symbol) == 0);
   bool doTrading = inKillZone && underMaxPos && canOpenThisSymbol;

   if(UseAIServer && (TimeCurrent() - g_lastAIUpdate) >= g_aiUpdateInterval)
      UpdateAIDecision();

   CloseWorstPositionIfTotalLossExceeded();
   ManageTrailingStop();
   ManageDollarExits();
   ManageBoomCrashSpikeClose();

   if(doTrading)
   {
      bool isBoom = (SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH && StringFind(_Symbol, "Boom") >= 0);
      bool isCrash = (SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH && StringFind(_Symbol, "Crash") >= 0);
      bool lsOk = UseLiquiditySweep && FVGKill_LiquiditySweepDetected();
      if(NoEntryDuringSweep) lsOk = lsOk && FVGKill_SweepConfirmed();
      if(CountPositionsForSymbol(_Symbol) == 0 && CountPositionsOurEA() < MaxPositionsTerminal && UseFVGKillMode && lsOk)
      {
         if(IsBullishHTF() && (isBoom || !BoomCrashMode))
            ExecuteFVGKillBuy();
         else if(IsBearishHTF() && (isCrash || !BoomCrashMode))
            ExecuteFVGKillSell();
      }
      if(CountPositionsForSymbol(_Symbol) == 0 && CountPositionsOurEA() < MaxPositionsTerminal)
      {
         SMC_Signal signal;
         if(DetectSMCSignal(signal))
         {
            if(UseNotifications)
               Alert("SMC Universal | Signal ", signal.action, " ", _Symbol, " détecté - ", signal.concept);
            if(ConfirmWithAI(signal))
               ExecuteSignal(signal);
            else if(UseNotifications)
               Alert("SMC Universal | Signal ", signal.action, " ", _Symbol, " non exécuté (IA)");
         }
      }
   }

   if(ShowChartGraphics)
   {
      DrawSwingHighLow();
      DrawFVGOnChart();
      DrawOBOnChart();
      DrawFibonacciOnChart();
      DrawEMACurveOnChart();
      DrawLiquidityZonesOnChart();
      if(ShowPremiumDiscount) DrawPremiumDiscountZones();
      if(ShowSignalArrow) { DrawSignalArrow(); UpdateSignalArrowBlink(); }
      if(ShowPredictedSwing) DrawPredictedSwingPoints();
      if(ShowEMASupportResistance) DrawEMASupportResistance();
      if(ShowPredictionChannel)
         DrawPredictionChannel();
   }

   UpdateDashboard();
}

//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!UseDashboard) return;
   string catStr = "UNKNOWN";
   switch(SMC_GetSymbolCategory(_Symbol))
   {
      case SYM_BOOM_CRASH:  catStr = "Boom/Crash"; break;
      case SYM_VOLATILITY:  catStr = "Volatility"; break;
      case SYM_FOREX:       catStr = "Forex"; break;
      case SYM_COMMODITY:   catStr = "Commodity"; break;
      case SYM_METAL:       catStr = "Metal"; break;
   }
   int posCount = CountPositionsForSymbol(_Symbol);
   int totalPos = CountPositionsOurEA();
   double totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == MagicNumber)
         totalPL += posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
   string swingStr = "";
   if(g_lastSwingHigh > 0) swingStr += " SH=" + DoubleToString(g_lastSwingHigh, _Digits);
   if(g_lastSwingLow > 0)  swingStr += " SL=" + DoubleToString(g_lastSwingLow, _Digits);
   double atrVal = 0, emaVal = 0;
   double atrArr[], emaArr[];
   ArraySetAsSeries(atrArr, true); ArraySetAsSeries(emaArr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrArr) >= 1) atrVal = atrArr[0];
   if(emaHandle != INVALID_HANDLE && CopyBuffer(emaHandle, 0, 0, 1, emaArr) >= 1) emaVal = emaArr[0];
   string trendHTF = IsBullishHTF() ? "BULLISH" : "BEARISH";
   string lsStr = FVGKill_LiquiditySweepDetected() ? "YES" : "NO";
   if(ShowMLMetrics && (TimeCurrent() - g_lastMLMetricsUpdate) >= 60)
      UpdateMLMetricsDisplay();
   string killStr = SMC_IsKillZone(LondonStart, LondonEnd, NYOStart, NYOEnd) ? "ACTIVE" : "OFF";
   string bcStr = (StringFind(_Symbol, "Boom") >= 0) ? "BOOM" : (StringFind(_Symbol, "Crash") >= 0) ? "CRASH" : "FOREX";
   Comment("═══ SMC Universal + FVG_Kill PRO ═══\n",
           "Stratégie: SMC (FVG|OB|LS|BOS) + FVG_Kill (EMA HTF + LS)\n",
           "Trend HTF: ", trendHTF, " | Liquidity Sweep: ", lsStr, " | Kill Zone: ", killStr, "\n",
           "Boom/Crash: ", bcStr, " | Catégorie: ", catStr, "\n",
           "IA: ", g_aiConnected ? (g_lastAIAction + " " + DoubleToString(g_lastAIConfidence*100,1) + "% | Align: " + g_lastAIAlignment + " | Cohér: " + g_lastAICoherence) : "OFF", "\n",
           "Positions terminal: ", totalPos, "/", MaxPositionsTerminal, " | ", _Symbol, ": ", posCount, "/1\n",
           "Perte totale: ", DoubleToString(totalPL, 2), " $ (max ", DoubleToString(MaxTotalLossDollars, 0), "$)\n",
           "Swing: ", swingStr, "\n",
           "ATR: ", DoubleToString(atrVal, _Digits), " | EMA(9): ", DoubleToString(emaVal, _Digits),
           "\nCanal ML: ", (g_channelValid ? "OK" : "—"),
           "\nML (entraînement): ", g_mlMetricsStr);
}

void UpdateMLMetricsDisplay()
{
   g_lastMLMetricsUpdate = TimeCurrent();
   string symEnc = _Symbol;
   StringReplace(symEnc, " ", "%20");
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
   string pathMetrics = "/ml/metrics?symbol=" + symEnc + "&timeframe=M1";
   string pathStatus = "/ml/continuous/status";
   string headers = "";
   char post[], result[], result2[];
   string resultHeaders;
   int res = WebRequest("GET", baseUrl + pathMetrics, headers, AI_Timeout_ms, post, result, resultHeaders);
   if(res != 200)
      res = WebRequest("GET", (UseRenderAsPrimary ? AI_ServerURL : AI_ServerRender) + pathMetrics, headers, AI_Timeout_ms, post, result, resultHeaders);
   string trainStr = "OFF";
   int res2 = WebRequest("GET", baseUrl + pathStatus, headers, AI_Timeout_ms, post, result2, resultHeaders);
   if(res2 != 200)
      res2 = WebRequest("GET", (UseRenderAsPrimary ? AI_ServerURL : AI_ServerRender) + pathStatus, headers, AI_Timeout_ms, post, result2, resultHeaders);
   if(res2 == 200)
   {
      string json2 = CharArrayToString(result2);
      if(StringFind(json2, "\"enabled\":true") >= 0 || StringFind(json2, "\"enabled\": true") >= 0)
         trainStr = "ON";
   }
   if(res != 200) { g_mlMetricsStr = "— | Entraînement: " + trainStr; return; }
   string json = CharArrayToString(result);
   double accRF = ExtractJsonNumber(json, "accuracy");
   int posRF = StringFind(json, "\"random_forest\"");
   if(posRF >= 0)
   {
      int posAcc = StringFind(json, "\"accuracy\":", posRF);
      if(posAcc >= 0)
      {
         int start = posAcc + 11;
         int i = start;
         while(i < StringLen(json)) { ushort c = StringGetCharacter(json, i); if(c == '-' || (c >= '0' && c <= '9') || c == '.') i++; else break; }
         if(i > start) accRF = StringToDouble(StringSubstr(json, start, i - start));
      }
   }
   int trainSamples = (int)ExtractJsonNumber(json, "training_samples");
   double minConf = ExtractJsonNumber(json, "min_confidence");
   int posRec = StringFind(json, "\"recommendations\"");
   if(posRec >= 0) { int posMc = StringFind(json, "\"min_confidence\":", posRec); if(posMc >= 0) { int s = posMc + 17; int e = s; while(e < StringLen(json)) { ushort c = StringGetCharacter(json, e); if(c == '-' || (c >= '0' && c <= '9') || c == '.') e++; else break; } if(e > s) minConf = StringToDouble(StringSubstr(json, s, e - s)); } }
   g_mlMetricsStr = StringFormat("Précision %.0f%% | train: %d | conf min: %.2f | Entraînement: %s", accRF, trainSamples, minConf, trainStr);
}

void DrawSwingHighLow()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 50;
   if(CopyRates(_Symbol, LTF, 0, bars, rates) < bars) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int swingHalf = 2;
   ObjectsDeleteAll(0, "SMC_Swing_");
   for(int i = swingHalf; i < bars - swingHalf - 1; i++)
   {
      bool isSwingHigh = (rates[i].high >= rates[i-1].high && rates[i].high >= rates[i+1].high);
      bool isSwingLow  = (rates[i].low <= rates[i-1].low && rates[i].low <= rates[i+1].low);
      if(isSwingHigh)
      {
         g_lastSwingHigh = rates[i].high;
         g_lastSwingHighTime = rates[i].time;
         string name = "SMC_Swing_SH_" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_TEXT, 0, rates[i].time, rates[i].high + 5*point))
         {
            ObjectSetString(0, name, OBJPROP_TEXT, "SH");
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LOWER);
         }
      }
      if(isSwingLow)
      {
         g_lastSwingLow = rates[i].low;
         g_lastSwingLowTime = rates[i].time;
         string name = "SMC_Swing_SL_" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_TEXT, 0, rates[i].time, rates[i].low - 5*point))
         {
            ObjectSetString(0, name, OBJPROP_TEXT, "SL");
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
         }
      }
   }
}

void DrawFVGOnChart()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 80;
   if(CopyRates(_Symbol, LTF, 0, bars, rates) < bars) return;
   ObjectsDeleteAll(0, "SMC_FVG_");
   int cnt = 0;
   for(int i = 2; i < bars - 2 && cnt < 15; i++)
   {
      if(rates[i].close > rates[i].open && rates[i+1].high < rates[i-1].low)
      {
         double top = rates[i-1].low, bot = rates[i+1].high;
         datetime t1 = rates[i+1].time, t2 = TimeCurrent() + PeriodSeconds(LTF)*20;
         string name = "SMC_FVG_Bull_" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, bot, t2, top))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_BACK, false);
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            cnt++;
         }
      }
      if(rates[i].close < rates[i].open && rates[i+1].low > rates[i-1].high)
      {
         double top = rates[i+1].low, bot = rates[i-1].high;
         datetime t1 = rates[i+1].time, t2 = TimeCurrent() + PeriodSeconds(LTF)*20;
         string name = "SMC_FVG_Bear_" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, bot, t2, top))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_BACK, false);
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            cnt++;
         }
      }
   }
}

void DrawOBOnChart()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 80;
   if(CopyRates(_Symbol, LTF, 0, bars, rates) < bars) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   ObjectsDeleteAll(0, "SMC_OB_");
   int cnt = 0;
   for(int i = 3; i < bars - 4 && cnt < 10; i++)
   {
      if(rates[i].close < rates[i].open && rates[i+1].close > rates[i+1].open && (rates[i+1].high - rates[i].low) > point*20)
      {
         datetime t2 = TimeCurrent() + PeriodSeconds(LTF)*30;
         string name = "SMC_OB_Bull_" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, rates[i].time, rates[i].low, t2, rates[i].high))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            cnt++;
         }
      }
      if(rates[i].close > rates[i].open && rates[i+1].close < rates[i+1].open && (rates[i].high - rates[i+1].low) > point*20)
      {
         datetime t2 = TimeCurrent() + PeriodSeconds(LTF)*30;
         string name = "SMC_OB_Bear_" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, rates[i].time, rates[i].low, t2, rates[i].high))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrCrimson);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            cnt++;
         }
      }
   }
}

void DrawFibonacciOnChart()
{
   double high[], low[];
   datetime time[];
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(time, true);
   int n = 50;
   if(CopyHigh(_Symbol, LTF, 0, n, high) < n || CopyLow(_Symbol, LTF, 0, n, low) < n || CopyTime(_Symbol, LTF, 0, n, time) < n) return;
   int iHigh = ArrayMaximum(high, 0, n), iLow = ArrayMinimum(low, 0, n);
   if(iHigh < 0 || iLow < 0) return;
   double h = high[iHigh], l = low[iLow];
   ObjectsDeleteAll(0, "SMC_Fib_");
   double levels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
   color colors[] = {clrGray, clrDodgerBlue, clrAqua, clrYellow, clrOrange, clrOrangeRed, clrMagenta};
   for(int i = 0; i < 7; i++)
   {
      double price = l + (h - l) * levels[i];
      string name = "SMC_Fib_" + IntegerToString(i);
      if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR, colors[i]);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetString(0, name, OBJPROP_TOOLTIP, "Fib " + DoubleToString(levels[i]*100, 1) + "%");
      }
   }
}

void DrawEMACurveOnChart()
{
   if(emaHandle == INVALID_HANDLE) return;
   double ema[];
   ArraySetAsSeries(ema, true);
   int len = 20;
   if(CopyBuffer(emaHandle, 0, 0, len, ema) < len) return;
   datetime time[];
   ArraySetAsSeries(time, true);
   if(CopyTime(_Symbol, LTF, 0, len, time) < len) return;
   ObjectsDeleteAll(0, "SMC_EMA_");
   for(int i = 0; i < len - 1; i++)
   {
      string name = "SMC_EMA_" + IntegerToString(i);
      if(ObjectCreate(0, name, OBJ_TREND, 0, time[i], ema[i], time[i+1], ema[i+1]))
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      }
   }
}

void DrawLiquidityZonesOnChart()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 30;
   if(CopyRates(_Symbol, LTF, 0, bars, rates) < bars) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   ObjectsDeleteAll(0, "SMC_Liq_");
   int cnt = 0;
   for(int i = 5; i < bars - 5 && cnt < 8; i++)
   {
      double zHigh = rates[i].high, zLow = rates[i].low;
      for(int j = i; j < i + 10 && j < bars; j++)
      {
         if(rates[j].high > zHigh) zHigh = rates[j].high;
         if(rates[j].low < zLow) zLow = rates[j].low;
      }
      if(zHigh - zLow > point * 5)
      {
         string name = "SMC_Liq_" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, rates[i+5].time, zLow, rates[i].time, zHigh))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrPurple);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            cnt++;
         }
      }
   }
}

void DrawPremiumDiscountZones()
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);
   ENUM_TIMEFRAMES tf = PERIOD_H1;
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 100, high) < 100 || CopyLow(_Symbol, PERIOD_H1, 0, 100, low) < 100 || CopyClose(_Symbol, PERIOD_H1, 0, 100, close) < 100)
   {
      tf = LTF;
      int n = MathMin(100, Bars(_Symbol, tf));
      if(n < 30 || CopyHigh(_Symbol, tf, 0, n, high) < n || CopyLow(_Symbol, tf, 0, n, low) < n || CopyClose(_Symbol, tf, 0, n, close) < n) return;
   }
   int n = ArraySize(close);
   if(n < 25) return;
   double sma20[];
   ArrayResize(sma20, n);
   ArraySetAsSeries(sma20, true);
   for(int i = 0; i < n - 20; i++)
   {
      double sum = 0;
      for(int j = 0; j < 20; j++) sum += close[i + j];
      sma20[i] = sum / 20;
   }
   for(int i = n - 20; i < n; i++) sma20[i] = sma20[MathMax(0, n - 21)];
   double eq = sma20[0];
   datetime t0 = TimeCurrent() - 7200;
   datetime t1 = TimeCurrent();
   ObjectDelete(0, "SMC_ICT_PREMIUM_ZONE");
   ObjectDelete(0, "SMC_ICT_DISCOUNT_ZONE");
   ObjectDelete(0, "SMC_ICT_PREMIUM_LABEL");
   ObjectDelete(0, "SMC_ICT_DISCOUNT_LABEL");
   ObjectDelete(0, "SMC_ICT_EQUILIBRE");
   ObjectDelete(0, "SMC_ICT_EQUILIBRE_LABEL");
   double premHigh = high[ArrayMaximum(high, 0, 20)];
   double discLow = low[ArrayMinimum(low, 0, 20)];
   if(premHigh <= eq || discLow >= eq) return;
   ObjectCreate(0, "SMC_ICT_PREMIUM_ZONE", OBJ_RECTANGLE, 0, t0, eq, t1, premHigh);
   ObjectSetInteger(0, "SMC_ICT_PREMIUM_ZONE", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "SMC_ICT_PREMIUM_ZONE", OBJPROP_BACK, true);
   ObjectSetInteger(0, "SMC_ICT_PREMIUM_ZONE", OBJPROP_FILL, true);
   ObjectCreate(0, "SMC_ICT_PREMIUM_LABEL", OBJ_TEXT, 0, t0 + 600, (eq + premHigh) / 2);
   ObjectSetString(0, "SMC_ICT_PREMIUM_LABEL", OBJPROP_TEXT, "Premium (vente)");
   ObjectSetInteger(0, "SMC_ICT_PREMIUM_LABEL", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "SMC_ICT_PREMIUM_LABEL", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "SMC_ICT_PREMIUM_LABEL", OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectCreate(0, "SMC_ICT_DISCOUNT_ZONE", OBJ_RECTANGLE, 0, t0, discLow, t1, eq);
   ObjectSetInteger(0, "SMC_ICT_DISCOUNT_ZONE", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, "SMC_ICT_DISCOUNT_ZONE", OBJPROP_BACK, true);
   ObjectSetInteger(0, "SMC_ICT_DISCOUNT_ZONE", OBJPROP_FILL, true);
   ObjectCreate(0, "SMC_ICT_DISCOUNT_LABEL", OBJ_TEXT, 0, t0 + 1800, (discLow + eq) / 2);
   ObjectSetString(0, "SMC_ICT_DISCOUNT_LABEL", OBJPROP_TEXT, "Discount (achat)");
   ObjectSetInteger(0, "SMC_ICT_DISCOUNT_LABEL", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "SMC_ICT_DISCOUNT_LABEL", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "SMC_ICT_DISCOUNT_LABEL", OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectCreate(0, "SMC_ICT_EQUILIBRE", OBJ_HLINE, 0, 0, eq);
   ObjectSetInteger(0, "SMC_ICT_EQUILIBRE", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, "SMC_ICT_EQUILIBRE", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "SMC_ICT_EQUILIBRE", OBJPROP_WIDTH, 2);
   ObjectCreate(0, "SMC_ICT_EQUILIBRE_LABEL", OBJ_TEXT, 0, t0 + 3600, eq);
   ObjectSetString(0, "SMC_ICT_EQUILIBRE_LABEL", OBJPROP_TEXT, "ZONE D'ÉQUILIBRE");
   ObjectSetInteger(0, "SMC_ICT_EQUILIBRE_LABEL", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, "SMC_ICT_EQUILIBRE_LABEL", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "SMC_ICT_EQUILIBRE_LABEL", OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void DrawSignalArrow()
{
   if(g_lastAIAction != "buy" && g_lastAIAction != "BUY" && g_lastAIAction != "sell" && g_lastAIAction != "SELL") return;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, r) < 1) return;
   double arrowPrice = r[0].close;
   datetime arrowTime = r[0].time;
   bool isBuy = (g_lastAIAction == "buy" || g_lastAIAction == "BUY");
   string arrowName = "SMC_DERIV_ARROW_" + _Symbol;
   if(ObjectFind(0, arrowName) < 0)
      ObjectCreate(0, arrowName, OBJ_ARROW, 0, arrowTime, arrowPrice);
   ObjectSetInteger(0, arrowName, OBJPROP_TIME, 0, arrowTime);
   ObjectSetDouble(0, arrowName, OBJPROP_PRICE, 0, arrowPrice);
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR, isBuy ? clrLime : clrRed);
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, isBuy ? 233 : 234);
   ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
}

void UpdateSignalArrowBlink()
{
   if(g_lastAIAction != "buy" && g_lastAIAction != "BUY" && g_lastAIAction != "sell" && g_lastAIAction != "SELL")
   {
      ObjectDelete(0, "SMC_DERIV_ARROW_" + _Symbol);
      return;
   }
   string arrowName = "SMC_DERIV_ARROW_" + _Symbol;
   if(ObjectFind(0, arrowName) < 0) return;
   datetime now = TimeCurrent();
   if(now - g_arrowBlinkTime >= 500)
   {
      g_arrowBlinkTime = now;
      g_arrowVisible = !g_arrowVisible;
   }
   ObjectSetInteger(0, arrowName, OBJPROP_TIMEFRAMES, g_arrowVisible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
}

void DrawPredictedSwingPoints()
{
   if(!g_channelValid) return;
   ObjectsDeleteAll(0, "SMC_Pred_SH_");
   ObjectsDeleteAll(0, "SMC_Pred_SL_");
   datetime tNow = iTime(_Symbol, PERIOD_M1, 0);
   if(tNow <= 0) tNow = TimeCurrent();
   int periodSec = 60;
   double slopeUpper = (PredictionChannelBars > 0) ? (g_chUpperEnd - g_chUpperStart) / (double)PredictionChannelBars : 0;
   double slopeLower = (PredictionChannelBars > 0) ? (g_chLowerEnd - g_chLowerStart) / (double)PredictionChannelBars : 0;
   int step = MathMax(1, PredictionChannelBars / 10);
   for(int k = 1; k <= 10; k++)
   {
      int barsAhead = k * step;
      datetime t = tNow + (datetime)(barsAhead * periodSec);
      double minsFromStart = (g_chTimeStart > 0) ? (double)(t - g_chTimeStart) / (double)periodSec : (double)barsAhead;
      double upPrice = g_chUpperStart + slopeUpper * minsFromStart;
      double loPrice = g_chLowerStart + slopeLower * minsFromStart;
      string nameSH = "SMC_Pred_SH_" + IntegerToString(k);
      string nameSL = "SMC_Pred_SL_" + IntegerToString(k);
      if(ObjectCreate(0, nameSH, OBJ_ARROW, 0, t, upPrice))
      {
         ObjectSetInteger(0, nameSH, OBJPROP_ARROWCODE, 159);
         ObjectSetInteger(0, nameSH, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, nameSH, OBJPROP_WIDTH, 2);
      }
      if(ObjectCreate(0, nameSL, OBJ_ARROW, 0, t, loPrice))
      {
         ObjectSetInteger(0, nameSL, OBJPROP_ARROWCODE, 159);
         ObjectSetInteger(0, nameSL, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, nameSL, OBJPROP_WIDTH, 2);
      }
   }
}

void DrawEMASupportResistance()
{
   if(emaM1H == INVALID_HANDLE || emaM5H == INVALID_HANDLE || emaH1H == INVALID_HANDLE) return;
   double emaM1[], emaM5[], emaH1[];
   ArraySetAsSeries(emaM1, true); ArraySetAsSeries(emaM5, true); ArraySetAsSeries(emaH1, true);
   if(CopyBuffer(emaM1H, 0, 0, 1, emaM1) < 1 || CopyBuffer(emaM5H, 0, 0, 1, emaM5) < 1 || CopyBuffer(emaH1H, 0, 0, 1, emaH1) < 1) return;
   ObjectDelete(0, "SMC_EMA_M1");
   ObjectDelete(0, "SMC_EMA_M5");
   ObjectDelete(0, "SMC_EMA_H1");
   ObjectCreate(0, "SMC_EMA_M1", OBJ_HLINE, 0, 0, emaM1[0]);
   ObjectSetInteger(0, "SMC_EMA_M1", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, "SMC_EMA_M1", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "SMC_EMA_M1", OBJPROP_WIDTH, 1);
   ObjectSetString(0, "SMC_EMA_M1", OBJPROP_TOOLTIP, "EMA M1 (support/resistance)");
   ObjectCreate(0, "SMC_EMA_M5", OBJ_HLINE, 0, 0, emaM5[0]);
   ObjectSetInteger(0, "SMC_EMA_M5", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, "SMC_EMA_M5", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "SMC_EMA_M5", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "SMC_EMA_M5", OBJPROP_TOOLTIP, "EMA M5 (support/resistance)");
   ObjectCreate(0, "SMC_EMA_H1", OBJ_HLINE, 0, 0, emaH1[0]);
   ObjectSetInteger(0, "SMC_EMA_H1", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "SMC_EMA_H1", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "SMC_EMA_H1", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "SMC_EMA_H1", OBJPROP_TOOLTIP, "EMA H1 (support/resistance)");
}

void DrawPredictionChannel()
{
   int throttleSec = g_channelValid ? 60 : 15;
   if(TimeCurrent() - g_lastChannelUpdate < throttleSec)
   {
      if(g_channelValid)
         DrawPredictionChannelLines();
      else if(ShowChartGraphics)
         DrawPredictionChannelLabel("Canal ML: chargement...");
      return;
   }
   g_lastChannelUpdate = TimeCurrent();
   g_channelValid = false;
   string symEnc = _Symbol;
   StringReplace(symEnc, " ", "%20");
   string pathCh = "/prediction-channel?symbol=" + symEnc + "&timeframe=M1&future_bars=" + IntegerToString(PredictionChannelBars);
   string url1 = UseRenderAsPrimary ? (AI_ServerRender + pathCh) : (AI_ServerURL + pathCh);
   string url2 = UseRenderAsPrimary ? (AI_ServerURL + pathCh) : (AI_ServerRender + pathCh);
   string headers = "";
   char post[];
   char result[];
   string resultHeaders;
   int res = WebRequest("GET", url1, headers, AI_Timeout_ms, post, result, resultHeaders);
   if(res != 200)
      res = WebRequest("GET", url2, headers, AI_Timeout_ms, post, result, resultHeaders);
   if(res == 200)
   {
      string json = CharArrayToString(result);
      if(StringFind(json, "\"ok\":true") >= 0 || StringFind(json, "\"ok\": true") >= 0)
      {
         long timeStartSec = (long)ExtractJsonNumber(json, "time_start");
         int periodSec = (int)ExtractJsonNumber(json, "period_seconds");
         if(periodSec <= 0) periodSec = 60;
         g_chUpperStart = ExtractJsonNumber(json, "upper_start");
         g_chUpperEnd   = ExtractJsonNumber(json, "upper_end");
         g_chLowerStart = ExtractJsonNumber(json, "lower_start");
         g_chLowerEnd   = ExtractJsonNumber(json, "lower_end");
         g_chTimeStart = (datetime)timeStartSec;
         g_chTimeEnd   = (datetime)(timeStartSec + (long)PredictionChannelBars * (long)periodSec);
         g_channelValid = (g_chUpperStart != 0 || g_chLowerStart != 0);
      }
   }
   if(!g_channelValid)
      BuildFallbackPredictionChannel();
   if(g_channelValid)
      DrawPredictionChannelLines();
}

void BuildFallbackPredictionChannel()
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int need = MathMin(1000, Bars(_Symbol, PERIOD_M1));
   if(need < 50) need = 50;
   if(CopyRates(_Symbol, PERIOD_M1, 0, need, r) < need) return;
   double sumX = 0, sumYH = 0, sumYL = 0, sumXX = 0, sumXYH = 0, sumXYL = 0;
   for(int i = 0; i < need; i++)
   {
      double x = (double)i;
      sumX += x; sumXX += x * x;
      sumYH += r[i].high; sumYL += r[i].low;
      sumXYH += x * r[i].high; sumXYL += x * r[i].low;
   }
   double n = (double)need;
   double denom = n * sumXX - sumX * sumX;
   if(MathAbs(denom) < 1e-10) denom = 1;
   double slopeH = (n * sumXYH - sumX * sumYH) / denom;
   double slopeL = (n * sumXYL - sumX * sumYL) / denom;
   double bH = (sumYH - slopeH * sumX) / n;
   double bL = (sumYL - slopeL * sumX) / n;
   double marginU = 0, marginL = 0;
   for(int i = 0; i < need; i++)
   {
      double regH = bH + slopeH * (double)i;
      double regL = bL + slopeL * (double)i;
      if(r[i].high > regH) marginU = MathMax(marginU, r[i].high - regH);
      if(r[i].low < regL)  marginL = MathMax(marginL, regL - r[i].low);
   }
   g_chTimeStart = r[0].time;
   g_chUpperStart = bH + marginU;
   g_chLowerStart = bL - marginL;
   g_chUpperEnd   = bH + marginU + slopeH * (double)PredictionChannelBars;
   g_chLowerEnd   = bL - marginL + slopeL * (double)PredictionChannelBars;
   g_channelValid = true;
}

double ExtractJsonNumber(string json, string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(json, search);
   if(pos < 0) return 0;
   int start = pos + StringLen(search);
   while(start < StringLen(json) && (StringGetCharacter(json, start) == ' ' || StringGetCharacter(json, start) == '\t'))
      start++;
   int i = start;
   while(i < StringLen(json))
   {
      ushort c = StringGetCharacter(json, i);
      if(c == '-' || (c >= '0' && c <= '9') || c == '.')
         i++;
      else
         break;
   }
   if(i <= start) return 0;
   return StringToDouble(StringSubstr(json, start, i - start));
}

void DrawPredictionChannelLines()
{
   ObjectsDeleteAll(0, "SMC_Chan_");
   datetime tNow = iTime(_Symbol, PERIOD_M1, 0);
   if(tNow <= 0) tNow = TimeCurrent();
   int periodSec = 60;
   int pastBars = MathMax(1, PredictionChannelPastBars);
   double slopeUpper = (PredictionChannelBars > 0) ? (g_chUpperEnd - g_chUpperStart) / (double)PredictionChannelBars : 0;
   double slopeLower = (PredictionChannelBars > 0) ? (g_chLowerEnd - g_chLowerStart) / (double)PredictionChannelBars : 0;
   double minsFromStart = (g_chTimeStart > 0) ? (double)(tNow - g_chTimeStart) / (double)periodSec : 0;
   double u0 = g_chUpperStart + slopeUpper * minsFromStart;
   double l0 = g_chLowerStart + slopeLower * minsFromStart;
   datetime tStart = tNow - (datetime)(pastBars * periodSec);
   datetime tEnd = tNow + (datetime)(PredictionChannelBars * periodSec);
   double uStart = u0 - slopeUpper * (double)pastBars;
   double lStart = l0 - slopeLower * (double)pastBars;
   double uEnd = u0 + slopeUpper * (double)PredictionChannelBars;
   double lEnd = l0 + slopeLower * (double)PredictionChannelBars;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int barsFit = (int)MathMin((long)pastBars, Bars(_Symbol, PERIOD_M1));
   if(CopyRates(_Symbol, PERIOD_M1, 0, barsFit, r) >= barsFit)
   {
      double marginU = 0, marginL = 0;
      for(int i = 0; i < barsFit; i++)
      {
         double uAt = u0 - slopeUpper * (double)i;
         double lAt = l0 - slopeLower * (double)i;
         if(r[i].high > uAt) marginU = MathMax(marginU, r[i].high - uAt);
         if(r[i].low < lAt)  marginL = MathMax(marginL, lAt - r[i].low);
      }
      uStart += marginU; lStart -= marginL;
      uEnd += marginU;   lEnd -= marginL;
   }

   color clrChan = (color)C'220,220,220';
   // Pas de surface remplie : uniquement 2 lignes qui enveloppent les bougies et suivent leur mouvement
   if(ObjectCreate(0, "SMC_Chan_Upper", OBJ_TREND, 0, tStart, uStart, tEnd, uEnd))
   {
      ObjectSetInteger(0, "SMC_Chan_Upper", OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, "SMC_Chan_Upper", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "SMC_Chan_Upper", OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, "SMC_Chan_Upper", OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, "SMC_Chan_Upper", OBJPROP_BACK, false);
   }
   if(ObjectCreate(0, "SMC_Chan_Lower", OBJ_TREND, 0, tStart, lStart, tEnd, lEnd))
   {
      ObjectSetInteger(0, "SMC_Chan_Lower", OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, "SMC_Chan_Lower", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "SMC_Chan_Lower", OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, "SMC_Chan_Lower", OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, "SMC_Chan_Lower", OBJPROP_BACK, false);
   }
   string lbl = "Canal ML " + IntegerToString(pastBars) + "→" + IntegerToString(PredictionChannelBars) + " bars";
   if(ObjectFind(0, "SMC_Chan_Label") < 0)
      ObjectCreate(0, "SMC_Chan_Label", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_YDISTANCE, 50);
   ObjectSetString(0, "SMC_Chan_Label", OBJPROP_TEXT, lbl);
   ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_FONTSIZE, 9);
}

void DrawPredictionChannelLabel(string text)
{
   if(ObjectFind(0, "SMC_Chan_Status") < 0)
      ObjectCreate(0, "SMC_Chan_Status", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_YDISTANCE, 50);
   ObjectSetString(0, "SMC_Chan_Status", OBJPROP_TEXT, text);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_FONTSIZE, 9);
}

//+------------------------------------------------------------------+
bool DetectSMCSignal(SMC_Signal &sig)
{
   sig.action = "HOLD";
   sig.confidence = 0;
   sig.reasoning = "";
   sig.entryPrice = 0;
   sig.stopLoss = 0;
   sig.takeProfit = 0;
   
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 3, atr) < 3) return false;
   double atrMult = SMC_GetATRMultiplier(cat);
   
   bool hasBuySignal = false;
   bool hasSellSignal = false;
   string reason = "";
   
   bool lsSSL = false, lsBSL = false;
   int lsBarsAgo = 99;
   if(UseLiquiditySweep)
   {
      string lsType;
      int barsAgo = 0;
      if(SMC_DetectLiquiditySweepEx(_Symbol, LTF, lsType, barsAgo))
      {
         lsBarsAgo = barsAgo;
         if(lsType == "SSL") lsSSL = true;
         else if(lsType == "BSL") lsBSL = true;
      }
      if(!RequireStructureAfterSweep)
      {
         if(lsSSL) { hasBuySignal = true; reason += "LS-SSL "; }
         else if(lsBSL) { hasSellSignal = true; reason += "LS-BSL "; }
      }
   }
   
   if(UseFVG)
   {
      FVGData fvg;
      if(SMC_DetectFVG(_Symbol, LTF, 30, fvg))
      {
         if(fvg.direction == 1 && bid >= fvg.bottom && bid <= fvg.top) { hasBuySignal = true; reason += "FVG-Bull "; }
         else if(fvg.direction == -1 && ask <= fvg.top && ask >= fvg.bottom) { hasSellSignal = true; reason += "FVG-Bear "; }
      }
   }
   
   if(UseOrderBlocks)
   {
      OrderBlockData ob;
      if(SMC_DetectOrderBlock(_Symbol, LTF, ob))
      {
         if(ob.direction == 1 && bid >= ob.low && bid <= ob.high) { hasBuySignal = true; reason += "OB-Bull "; }
         else if(ob.direction == -1 && ask <= ob.high && ask >= ob.low) { hasSellSignal = true; reason += "OB-Bear "; }
      }
   }
   
   if(UseBOS)
   {
      int bosDir;
      if(SMC_DetectBOS(_Symbol, LTF, bosDir))
      {
         if(bosDir == 1) { hasBuySignal = true; reason += "BOS-Up "; }
         else if(bosDir == -1) { hasSellSignal = true; reason += "BOS-Down "; }
      }
   }
   if(IsInDiscountZone()) { hasBuySignal = true; reason += "Zone-Discount "; }
   if(IsInPremiumZone()) { hasSellSignal = true; reason += "Zone-Premium "; }

   if(RequireStructureAfterSweep && UseLiquiditySweep)
   {
      bool waitOk = !NoEntryDuringSweep || (lsBarsAgo >= 2);
      if(hasBuySignal && lsBSL) hasBuySignal = false;
      else if(hasBuySignal && lsSSL && !waitOk) hasBuySignal = false;
      else if(hasBuySignal && !lsSSL && !lsBSL) { }
      if(hasSellSignal && lsSSL) hasSellSignal = false;
      else if(hasSellSignal && lsBSL && !waitOk) hasSellSignal = false;
      else if(hasSellSignal && !lsSSL && !lsBSL) { }
      if(hasBuySignal && lsSSL && waitOk) reason += "[LS+Conf] ";
      if(hasSellSignal && lsBSL && waitOk) reason += "[LS+Conf] ";
   }
   if((g_lastAIAction == "BUY" || g_lastAIAction == "buy") && g_lastAIConfidence >= MinAIConfidence) { hasBuySignal = true; reason += "IA-BUY "; }
   if((g_lastAIAction == "SELL" || g_lastAIAction == "sell") && g_lastAIConfidence >= MinAIConfidence) { hasSellSignal = true; reason += "IA-SELL "; }

   bool isBoom = (cat == SYM_BOOM_CRASH && StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (cat == SYM_BOOM_CRASH && StringFind(_Symbol, "Crash") >= 0);
   if(isBoom && BoomBuyOnly) hasSellSignal = false;
   if(isCrash && CrashSellOnly) hasBuySignal = false;
   
   double slDist = atr[0] * SL_ATRMult;
   double tpDist = atr[0] * TP_ATRMult;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   bool haveRates = (CopyRates(_Symbol, LTF, 0, 10, r) >= 10);
   double newSwingLow = 0, newSwingHigh = 0;
   if(haveRates && StopBeyondNewStructure)
   {
      newSwingLow = r[1].low;
      newSwingHigh = r[1].high;
      for(int i = 2; i < 8; i++) { if(r[i].low < newSwingLow) newSwingLow = r[i].low; if(r[i].high > newSwingHigh) newSwingHigh = r[i].high; }
   }
   double buffer = atr[0] * 0.5;
   if(hasBuySignal && !hasSellSignal)
   {
      sig.action = "BUY";
      sig.confidence = 0.65;
      sig.concept = reason;
      sig.reasoning = "SMC: " + reason;
      sig.entryPrice = ask;
      if(!NoSLTP_BoomCrash)
      {
         if(StopBeyondNewStructure && lsSSL && newSwingLow > 0)
            sig.stopLoss = newSwingLow - buffer;
         else
            sig.stopLoss = ask - slDist;
         sig.takeProfit = ask + tpDist;
      }
      return true;
   }
   else if(hasSellSignal && !hasBuySignal)
   {
      sig.action = "SELL";
      sig.confidence = 0.65;
      sig.concept = reason;
      sig.reasoning = "SMC: " + reason;
      sig.entryPrice = bid;
      if(!NoSLTP_BoomCrash)
      {
         if(StopBeyondNewStructure && lsBSL && newSwingHigh > 0)
            sig.stopLoss = newSwingHigh + buffer;
         else
            sig.stopLoss = bid + slDist;
         sig.takeProfit = bid - tpDist;
      }
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool ConfirmWithAI(SMC_Signal &sig)
{
   if(!RequireAIConfirmation) return true;
   if(!UseAIServer) return true;
   if(g_lastAIConfidence >= MinAIConfidence)
   {
      if(sig.action == "BUY" && (g_lastAIAction == "BUY" || g_lastAIAction == "buy")) return true;
      if(sig.action == "SELL" && (g_lastAIAction == "SELL" || g_lastAIAction == "sell")) return true;
   }
   return (g_lastAIConfidence >= 0.40 && g_lastAIAction != "HOLD");
}

//+------------------------------------------------------------------+
void ExecuteSignal(SMC_Signal &sig)
{
   if(CountPositionsOurEA() >= MaxPositionsTerminal) return;
   if(!TryAcquireOpenLock()) return;
   double lotSize = CalculateLotSize();
   if(lotSize <= 0) { ReleaseOpenLock(); return; }
   
   if(sig.action == "BUY")
   {
      if(NoSLTP_BoomCrash && SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH)
         trade.Buy(lotSize, _Symbol, 0, 0, 0, "SMC " + sig.concept);
      else
         trade.Buy(lotSize, _Symbol, 0, sig.stopLoss, sig.takeProfit, "SMC " + sig.concept);
      if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
      {
         Print("✅ SMC BUY @ ", sig.entryPrice, " - ", sig.concept);
         if(UseNotifications) { Alert("SMC BUY ", _Symbol, " ", sig.concept); SendNotification("SMC BUY " + _Symbol + " " + sig.concept); }
      }
   }
   else if(sig.action == "SELL")
   {
      if(NoSLTP_BoomCrash && SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH)
         trade.Sell(lotSize, _Symbol, 0, 0, 0, "SMC " + sig.concept);
      else
         trade.Sell(lotSize, _Symbol, 0, sig.stopLoss, sig.takeProfit, "SMC " + sig.concept);
      if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
      {
         Print("✅ SMC SELL @ ", sig.entryPrice, " - ", sig.concept);
         if(UseNotifications) { Alert("SMC SELL ", _Symbol, " ", sig.concept); SendNotification("SMC SELL " + _Symbol + " " + sig.concept); }
      }
   }
   ReleaseOpenLock();
}

//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(UseMinLotOnly)
      return NormalizeDouble(MathMax(minLot, lotStep), 2);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * 0.01;
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tickVal <= 0 || tickSize <= 0) return minLot;
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) return minLot;
   double slPoints = (atr[0] / point) * SL_ATRMult;
   double pipVal = (tickVal / tickSize) * point;
   if(pipVal <= 0) return minLot;
   double lotSize = riskAmount / (slPoints * pipVal);
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol) continue;
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      double openPrice = posInfo.PriceOpen();
      double currentSL = posInfo.StopLoss();
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, LTF, 0, 3, rates) < 3) continue;
      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double newSL = rates[1].low;
         if(profit > 0 && newSL > openPrice && (currentSL < newSL || currentSL == 0))
            trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
      }
      else
      {
         double newSL = rates[1].high;
         if(profit > 0 && newSL < openPrice && (currentSL > newSL || currentSL == 0))
            trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
      }
   }
}

//+------------------------------------------------------------------+
void UpdateAIDecision()
{
   string symEnc = _Symbol;
   StringReplace(symEnc, " ", "%20");
   string path = "/trend?symbol=" + symEnc + "&timeframe=M1";
   string headers = "";
   char post[];
   char result[];
   string resultHeaders;
   string url1 = UseRenderAsPrimary ? (AI_ServerRender + path) : (AI_ServerURL + path);
   string url2 = UseRenderAsPrimary ? (AI_ServerURL + path) : (AI_ServerRender + path);
   int res = WebRequest("GET", url1, headers, AI_Timeout_ms, post, result, resultHeaders);
   if(res != 200)
      res = WebRequest("GET", url2, headers, AI_Timeout_ms, post, result, resultHeaders);
   if(res == 200)
   {
      string json = CharArrayToString(result);
      g_aiConnected = true;
      g_lastAIUpdate = TimeCurrent();
      g_lastAIAlignment = "—";
      g_lastAICoherence = "—";
      int finalPos = StringFind(json, "\"final_decision\":\"");
      if(finalPos >= 0)
      {
         int start = finalPos + 17;
         int end = StringFind(json, "\"", start);
         if(end > start) g_lastAIAction = StringSubstr(json, start, end - start);
      }
      if(g_lastAIAction == "")
      {
         int decisionPos = StringFind(json, "\"decision\":\"");
         if(decisionPos >= 0)
         {
            int start = decisionPos + 11;
            int end = StringFind(json, "\"", start);
            if(end > start) g_lastAIAction = StringSubstr(json, start, end - start);
         }
      }
      int confPos = StringFind(json, "\"confidence\":");
      if(confPos >= 0)
      {
         int start = confPos + 13;
         int end = StringFind(json, ",", start);
         if(end < 0) end = StringFind(json, "}", start);
         if(end > start) g_lastAIConfidence = StringToDouble(StringSubstr(json, start, end - start));
      }
      int alignPos = StringFind(json, "\"alignment\":\"");
      if(alignPos >= 0)
      {
         int start = alignPos + 13;
         int end = StringFind(json, "\"", start);
         if(end > start) g_lastAIAlignment = StringSubstr(json, start, end - start);
      }
      int coherPos = StringFind(json, "\"coherence\":");
      if(coherPos >= 0)
      {
         int start = coherPos + 12;
         int end = StringFind(json, ",", start);
         if(end < 0) end = StringFind(json, "}", start);
         if(end > start)
            g_lastAICoherence = DoubleToString(StringToDouble(StringSubstr(json, start, end - start)) * 100.0, 1) + "%";
      }
   }
   else
      g_aiConnected = false;
}
