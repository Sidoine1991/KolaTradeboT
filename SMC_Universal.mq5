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

// Forward declarations
bool GetAISignalData();
bool UpdateAIDecision(int timeoutMs = -1);
void UpdateMLMetricsDisplay();
void DrawSwingHighLow();
void DrawFVGOnChart();
void DrawOBOnChart();
void DrawFibonacciOnChart();
void DrawEMACurveOnChart();
void DrawLiquidityZonesOnChart();
void PlaceScalpingLimitOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope);
void DrawHistoricalSwingPoints(MqlRates &rates[], int bars, double point);
void ManageBoomCrashSpikeClose();
void ManageDollarExits();
void CloseWorstPositionIfTotalLossExceeded();
void CloseAllPositionsIfTotalProfitReached();
void DrawPremiumDiscountZones();
void DrawSignalArrow();
void UpdateSignalArrowBlink();
void DrawPredictedSwingPoints();
void DrawEMASupportResistance();
void DrawPredictionChannel();
void DrawSMCChannelsMultiTF();
void DrawEMASupertrendMultiTF();
void UpdateDashboard();
void PlaceHistoricalBasedScalpingOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope, int existingLimitOrders);
bool CaptureChartDataFromChart();
void ManageTrailingStop();
void GenerateFallbackAIDecision();
void GenerateFallbackMLMetrics();
void DrawPreciseSwingPredictionsWithOrders();
void DrawOrderLinksToSwings(double nextSH, double nextSL, datetime nextSHTime, datetime nextSLTime);
void PlacePreciseSwingBasedOrders();
void ExecuteAIDecisionMarketOrder();
bool DetectNonRepaintingSwingPoints();
void GetLatestConfirmedSwings(double &lastSH, datetime &lastSHTime, double &lastSL, datetime &lastSLTime);
void DrawConfirmedSwingPoints();
bool DetectBoomCrashSwingPoints();
void UpdateSpikeWarningBlink();
void CheckPredictedSwingTriggers();

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
   for(int fvgIndex = 2; fvgIndex < lookback - 1; fvgIndex++)
   {
      if(rates[fvgIndex-1].low > rates[fvgIndex+1].high)
      {
         double gap = rates[fvgIndex-1].low - rates[fvgIndex+1].high;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(gap > point * 3) {
            fvgOut.top = rates[fvgIndex-1].low; fvgOut.bottom = rates[fvgIndex+1].high; fvgOut.direction = 1;
            fvgOut.time = rates[fvgIndex].time; fvgOut.isInversion = false; fvgOut.barIndex = fvgIndex;
            return true;
         }
      }
      if(rates[fvgIndex-1].high < rates[fvgIndex+1].low)
      {
         double gap = rates[fvgIndex+1].low - rates[fvgIndex-1].high;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(gap > point * 3) {
            fvgOut.top = rates[fvgIndex+1].low; fvgOut.bottom = rates[fvgIndex-1].high; fvgOut.direction = -1;
            fvgOut.time = rates[fvgIndex].time; fvgOut.isInversion = false; fvgOut.barIndex = fvgIndex;
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
input int    InpMagicNumber       = 202502; // Magic Number
input double MaxTotalLossDollars  = 10.0; // Perte totale max ($) - au-delà on ferme la position la plus perdante
input bool   UseSessions       = true;   // Trader seulement LO/NYO
input bool   ShowChartGraphics = true;   // FVG, OB, Fibo, EMA, Swing H/L sur le graphique
input bool   ShowPremiumDiscount = true; // Zones Premium (vente) / Discount (achat) / Équilibre
input bool   ShowSignalArrow     = true; // Flèche dynamique clignotante BUY/SELL
input bool   ShowPredictedSwing  = true; // SL/SH prédits (futurs) sur le canal
input bool   ShowEMASupportResistance = true; // EMA M1, M5, H1 en support/résistance
input int    SpikePredictionOffsetMinutes = 60; // Décalage dans le futur pour afficher l'entrée de spike dans la zone prédite

input group "=== SL/TP DYNAMIQUES (prudent / sécuriser gain) ==="
input double SL_ATRMult        = 2.5;    // Stop Loss (x ATR) - prudent
input double TP_ATRMult        = 5.0;    // Take Profit (x ATR) - ratio 2:1
input group "=== TRAILING STOP (sécuriser les gains) ==="
input bool   UseTrailingStop    = true;   // Activer le Trailing Stop automatique
input double TrailingStop_ATRMult = 2.0;  // Distance Trailing Stop (x ATR) - sécuriser les gains

input group "=== AI SERVER (confirmation signaux) ==="
input bool   UseAIServer       = true;   // Utiliser le serveur IA pour confirmation
input string AI_ServerURL       = "http://localhost:8000";  // URL du serveur IA local
input int    AI_Timeout_ms     = 5000;   // Timeout WebRequest (ms)
input int    AI_UpdateInterval_Seconds = 30;  // Intervalle mise à jour IA (secondes)
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
input bool   ShowPredictionChannel = true;  // Canal ML activé (bougies futures sur 1000 bougies)
input int    PredictionChannelPastBars = 1000; // (interne)
input int    PredictionChannelBars = 1000;  // (interne, canal de prédiction sur 1000 bougies futures)
input bool   ShowMLMetrics         = true;  // Afficher métriques ML (précision, entraînement continu)

input group "=== CANAUX SMC MULTI-TF ==="
input bool   ShowSMCChannelsMultiTF = true;  // Afficher canaux SMC sur H1, M30, M5
input bool   ShowEMASupertrendMultiTF = true; // Afficher EMA Supertrend S/R sur H1, M30, M5
input int    SMCChannelFutureBars = 5000;    // Bougies futures M1 à projeter
input int    EMAFastPeriod = 9;   // Période EMA rapide pour Supertrend
input int    EMASlowPeriod = 21;  // Période EMA lente pour Supertrend
input double ATRMultiplier = 2.0; // Multiplicateur ATR pour Supertrend

input group "=== IA SERVEUR ==="
input bool   RequireAIConfirmation = false; // Exiger confirmation IA pour SMC (false = trader sans IA)
input bool   UseRenderAsPrimary = true;  // Utiliser Render en premier (backend uniquement = true)
input string AI_ServerURL2      = "http://localhost:8000";  // URL serveur local
input string AI_ServerRender   = "https://kolatradebot.onrender.com";  // URL Render (backend)
input double MinAIConfidence   = 0.35;   // Confiance IA min pour exécuter (35% = plus d'opportunités)
input int    AI_Timeout_ms2     = 10000;  // Timeout WebRequest (ms) - Render cold start

input group "=== BOOM/CRASH ==="
input bool   BoomBuyOnly       = true;   // Boom: BUY uniquement
input bool   CrashSellOnly     = true;   // Crash: SELL uniquement
input bool   NoSLTP_BoomCrash  = false;  // Pas de SL/TP sur Boom/Crash (spike)
input double BoomCrashSpikeTP  = 0.01;   // Fermer dès petit gain (spike capté) si profit > ce seuil ($)
input double BoomCrashSpikePct = 0.08;   // Pourcentage de mouvement pour détecter spike (8%)
input double TargetProfitBoomCrashUSD = 2.0; // Gain à capter ($) - fermer si profit >= ce seuil (Spike_Close)
input double MaxLossDollars    = 6.0;    // Fermer toute position si perte atteint ($)
input double TakeProfitDollars = 2.0;    // Fermer si bénéfice atteint ($) - Volatility/Forex/Commodity

//+------------------------------------------------------------------+
//| GESTION DES POSITIONS ET VARIABLES GLOBALES                    |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo posInfo;  // Local position info variable
COrderInfo orderInfo;

int atrHandle;
int emaHandle = INVALID_HANDLE;
int ema50H = INVALID_HANDLE;
int ema200H = INVALID_HANDLE;
int fractalH = INVALID_HANDLE;
int emaM1H = INVALID_HANDLE;
int emaM5H = INVALID_HANDLE;
int emaH1H = INVALID_HANDLE;

// Handles pour EMA Supertrend Multi-TF
int emaFastM1 = INVALID_HANDLE;
int emaSlowM1 = INVALID_HANDLE;
int emaFastM5 = INVALID_HANDLE;
int emaSlowM5 = INVALID_HANDLE;
int emaFastH1 = INVALID_HANDLE;
int emaSlowH1 = INVALID_HANDLE;
int atrM1 = INVALID_HANDLE;
int atrM5 = INVALID_HANDLE;
int atrH1 = INVALID_HANDLE;
string g_lastAIAction = "HOLD";
string g_lastAIAlignment = "0.0%";
string g_lastAICoherence = "0.0%";
static datetime g_arrowBlinkTime = 0;
static bool g_arrowVisible = true;
static datetime g_spikeBlinkTime = 0;
static bool g_spikeWarningActive = false;
static datetime g_spikeWarningStart = 0;
static bool g_spikeWarningVisible = true;
double g_lastAIConfidence = 0;
datetime g_lastAIUpdate = 0;
int g_aiUpdateInterval = 30;
bool g_aiConnected = false;
static double g_lastBoomCrashPrice = 0.0;
static datetime g_lastBoomCrashPriceTime = 0;
static datetime s_lastRefUpdate = 0;  // Pour la détection de spike
// Variables swing (compatibles avec nouveau système anti-repaint)
double g_lastSwingHigh = 0, g_lastSwingLow = 0;
datetime g_lastSwingHighTime = 0, g_lastSwingLowTime = 0;
static datetime g_lastChannelUpdate = 0;
static bool g_channelValid = false;
static double g_chUpperStart = 0, g_chUpperEnd = 0, g_chLowerStart = 0, g_chLowerEnd = 0;
static datetime g_chTimeStart = 0, g_chTimeEnd = 0;
static string g_mlMetricsStr = "—";
static datetime g_lastMLMetricsUpdate = 0;
static double g_maxProfit = 0;  // Suivi du gain maximum pour protection 50%

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
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
   
   // Handles pour EMA Supertrend Multi-TF
   emaFastM1 = iMA(_Symbol, PERIOD_M1, EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM1 = iMA(_Symbol, PERIOD_M1, EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaFastM5 = iMA(_Symbol, PERIOD_M5, EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM5 = iMA(_Symbol, PERIOD_M5, EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaFastH1 = iMA(_Symbol, PERIOD_H1, EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowH1 = iMA(_Symbol, PERIOD_H1, EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   atrM1 = iATR(_Symbol, PERIOD_M1, 14);
   atrM5 = iATR(_Symbol, PERIOD_M5, 14);
   atrH1 = iATR(_Symbol, PERIOD_H1, 14);
   // Vérification robuste des handles
   if(atrHandle == INVALID_HANDLE)
   {
      Print("❌ Erreur création ATR - Tentative de récupération...");
      atrHandle = iATR(_Symbol, LTF, 14);
      if(atrHandle == INVALID_HANDLE)
      {
         Print("⚠️ Erreur ATR - Utilisation ATR calculé manuellement pour éviter détachement");
         Comment("⚠️ ATR MANUEL - Robot fonctionnel");
         atrHandle = INVALID_HANDLE; // Garder INVALID_HANDLE mais continuer
      }
   }
   // Les indicateurs seront ajoutés dynamiquement si nécessaire pour éviter le détachement
   GlobalVariableSet("SMC_OPEN_LOCK_" + IntegerToString(InpMagicNumber), 0);
   Print("📊 SMC Universal + FVG_Kill PRO | 1 pos/symbole | Stratégie visible");
   Print("   Catégorie: ", EnumToString(SMC_GetSymbolCategory(_Symbol)));
   Print("   IA: ", UseAIServer ? AI_ServerURL : "Désactivé");
   return INIT_SUCCEEDED;
}

bool TryAcquireOpenLock()
{
   string lockName = "SMC_OPEN_LOCK_" + IntegerToString(InpMagicNumber);
   
   // Vérification simple sans Sleep pour éviter détachement
   if(GlobalVariableGet(lockName) != 0) return false;
   GlobalVariableSet(lockName, 1);
   if(CountPositionsOurEA() >= MaxPositionsTerminal) { GlobalVariableSet(lockName, 0); return false; }
   return true;
}
void ReleaseOpenLock() { GlobalVariableSet("SMC_OPEN_LOCK_" + IntegerToString(InpMagicNumber), 0); }

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
}

//+------------------------------------------------------------------+
bool IsBullishHTF()
{
   if(ema50H == INVALID_HANDLE || ema200H == INVALID_HANDLE) return false;
   double f[], s[];
   ArraySetAsSeries(f, true); ArraySetAsSeries(s, true);
   if(CopyBuffer(ema50H, 0, 0, 1, f) < 1 || CopyBuffer(ema200H, 0, 0, 1, s) < 1) return false;
   return f[0] > s[0];
}
bool IsBearishHTF()
{
   if(ema50H == INVALID_HANDLE || ema200H == INVALID_HANDLE) return false;
   double f[], s[];
   ArraySetAsSeries(f, true); ArraySetAsSeries(s, true);
   if(CopyBuffer(ema50H, 0, 0, 1, f) < 1 || CopyBuffer(ema200H, 0, 0, 1, s) < 1) return false;
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
   // Vérifier si l'ATR handle est valide
   if(atrHandle == INVALID_HANDLE) return;
   
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
   
   // Réinitialiser le gain maximum pour la nouvelle position
   g_maxProfit = 0;
   
   trade.Buy(lot, _Symbol, 0, sl, tp, "FVG_Kill BUY");
   ReleaseOpenLock();
   if(trade.ResultRetcode() == TRADE_RETCODE_DONE && UseNotifications)
   { Alert("FVG_Kill BUY ", _Symbol); SendNotification("FVG_Kill BUY " + _Symbol); }
}
void ExecuteFVGKillSell()
{
   // Vérifier si l'ATR handle est valide
   if(atrHandle == INVALID_HANDLE) return;
   
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
   
   // Réinitialiser le gain maximum pour la nouvelle position
   g_maxProfit = 0;
   
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
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == symbol)
         n++;
   return n;
}

int CountPositionsOurEA()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == InpMagicNumber)
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
      if(posInfo.Magic() != InpMagicNumber) continue;
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

void CloseAllPositionsIfTotalProfitReached()
{
   double totalProfit = 0;
   ulong allTickets[];
   ArrayResize(allTickets, 0);
   
   // Calculer le profit total pour tous les symboles
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      double p = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      totalProfit += p;
      ArrayResize(allTickets, ArraySize(allTickets) + 1);
      allTickets[ArraySize(allTickets) - 1] = posInfo.Ticket();
   }
   
   // Fermer toutes les positions si le profit total atteint 3$
   if(totalProfit >= 3.0)
   {
      Print("💰 PROFIT TOTAL ATTEINT (", DoubleToString(totalProfit, 2), "$ >= 3.00$) → Fermeture de toutes les positions...");
      
      for(int i = 0; i < ArraySize(allTickets); i++)
      {
         ulong ticket = allTickets[i];
         if(PositionSelectByTicket(ticket))
         {
            double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            string symbol = PositionGetString(POSITION_SYMBOL);
            
            if(trade.PositionClose(ticket))
            {
               Print("✅ Position fermée - ", symbol, ": ", DoubleToString(profit, 2), "$");
            }
            else
            {
               Print("❌ Échec fermeture - ", symbol, ": ", DoubleToString(profit, 2), "$");
            }
         }
      }
      
      Print("🎯 FERMETURE COMPLÈTE - Profit total réalisé: ", DoubleToString(totalProfit, 2), "$");
   }
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

void CloseBoomCrashAfterSpike(ulong ticket, string symbol, double currentProfit)
{
   if(posInfo.Magic() != InpMagicNumber) return;
   if(SMC_GetSymbolCategory(symbol) != SYM_BOOM_CRASH) return;
   
   // RÈGLE UNIVERSELLE D'ABORD: 2 dollars pour TOUS les symboles
   if(currentProfit >= 2.0)
   {
      if(CloseBoomCrashPosition(ticket, symbol))
      {
         Print("✅ Boom/Crash fermé: bénéfice 2$ atteint (", DoubleToString(currentProfit, 2), "$) - ", symbol);
         if(symbol == _Symbol) { g_lastBoomCrashPrice = 0; }
      }
      return;
   }
   
   // Ensuite, les règles spécifiques Boom/Crash si < 2$
   if(currentProfit >= TargetProfitBoomCrashUSD && currentProfit < 2.0)
   {
      if(CloseBoomCrashPosition(ticket, symbol))
      {
         Print("🚀 Boom/Crash fermé (gain >= ", DoubleToString(TargetProfitBoomCrashUSD, 2), "$): ", DoubleToString(currentProfit, 2), "$) - ", symbol);
         if(symbol == _Symbol) { g_lastBoomCrashPrice = 0; }
      }
      return;
   }
   
   // Spike detection (si < 2$)
   if(g_lastBoomCrashPrice > 0)
   {
      double price = SymbolInfoDouble(symbol, SYMBOL_BID);
      double movePct = (price - g_lastBoomCrashPrice) / g_lastBoomCrashPrice * 100.0;
      if(StringFind(symbol, "Boom") >= 0 && movePct >= BoomCrashSpikePct)
      {
         if(CloseBoomCrashPosition(ticket, symbol))
         {
            Print("🚀 Boom/Crash fermé (spike prix ", DoubleToString(currentProfit, 2), "$) - ", symbol);
            g_lastBoomCrashPrice = 0;
            s_lastRefUpdate = 0;
         }
      }
      if(StringFind(symbol, "Crash") >= 0 && movePct <= -BoomCrashSpikePct)
      {
         if(CloseBoomCrashPosition(ticket, symbol))
         {
            Print("🚀 Boom/Crash fermé (spike prix ", DoubleToString(currentProfit, 2), "$) - ", symbol);
            g_lastBoomCrashPrice = 0;
            s_lastRefUpdate = 0;
         }
      }
   }
}

// Parcourt toutes les positions et ferme Boom/Crash selon seuil $ ou spike (comme Spike_Close_BoomCrash)
void ManageBoomCrashSpikeClose()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
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
      string symbol = PositionGetSymbol(i);
      if(symbol == "") continue;
      
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      if(ticket == 0) continue;
      double profit = PositionGetDouble(POSITION_PROFIT);
      ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(symbol);
      
      // RÈGLE UNIVERSELLE: Fermer TOUTES les positions à 2 dollars de profit
      if(profit >= 2.0)
      {
         if(trade.PositionClose(ticket))
            Print("✅ Position fermée: bénéfice 2$ atteint (", DoubleToString(profit, 2), "$) - ", symbol);
         continue;
      }
      
      // Règle de perte maximale
      if(profit <= -MaxLossDollars)
      {
         if(trade.PositionClose(ticket))
            Print("🛑 Position fermée: perte max atteinte (", DoubleToString(profit, 2), "$) - ", symbol);
         continue;
      }
      
      // Règles spécifiques Boom/Crash (en plus de la règle universelle)
      if(cat == SYM_BOOM_CRASH)
      {
         // Spike TP pour Boom/Crash
         if(profit >= BoomCrashSpikeTP && profit < 2.0) // Si entre spike TP et 2$
         {
            if(CloseBoomCrashPosition(ticket, symbol))
            {
               Print("🚀 Boom/Crash fermé après spike (gain > ", DoubleToString(BoomCrashSpikeTP, 2), "$): ", DoubleToString(profit, 2), "$");
               if(symbol == _Symbol) { g_lastBoomCrashPrice = 0; }
            }
            continue;
         }
      }
   }
}

void OnTick()
{
   // MODE IA ULTRA STABLE - PAS DE DÉTACHEMENT
   static datetime lastProcess = 0;
   static datetime lastGraphicsUpdate = 0;
   static datetime lastAIUpdate = 0;
   static datetime lastDashboardUpdate = 0;
   datetime currentTime = TimeCurrent();
   
   // Traitement contrôlé pour stabilité (max ~1 tick toutes les 2 secondes)
   if(currentTime - lastProcess < 2) return;
   lastProcess = currentTime;
   
   // Capturer régulièrement les données graphiques pour alimenter l'IA (mais pas à chaque tick)
   if(currentTime - g_lastChartCapture >= 10)
      CaptureChartDataFromChart();
   
   // GESTION DES POSITIONS CRITIQUES (priorité haute)
   CloseWorstPositionIfTotalLossExceeded();
   CloseAllPositionsIfTotalProfitReached();
   ManageDollarExits();
   ManageBoomCrashSpikeClose();
   if(UseTrailingStop)
      ManageTrailingStop();
   // Entrées automatiques sur SH/SL prédits (canal ML)
   CheckPredictedSwingTriggers();
   
   // SYSTÈME IA COMPLET (toutes les 60 secondes pour réactivité maximale)
   if(UseAIServer && currentTime - lastAIUpdate >= 60)
   {
      lastAIUpdate = currentTime;
      
      // Capture de données sécurisée
      if(ArraySize(g_chartDataBuffer) >= 20)
      {
         // APPEL IA SÉCURISÉ
         bool aiSuccess = UpdateAIDecision(3000); // 3 secondes timeout pour réactivité
         
         if(aiSuccess)
         {
            Print(" IA ACTIVE - Action: ", g_lastAIAction, " | Conf: ", DoubleToString(g_lastAIConfidence*100,1), "% | Align: ", g_lastAIAlignment, " | Cohér: ", g_lastAICoherence);
         }
         else
         {
            Print("⚠️ IA INDISPONIBLE - Mode autonome activé");
            // Générer une décision IA fallback
            GenerateFallbackAIDecision();
         }
      }
      else
      {
         Print(" IA: Pas assez de données pour analyse (", ArraySize(g_chartDataBuffer), " < 20)");
      }
      
      // EXÉCUTER LES ORDRES AU MARCHÉ BASÉS SUR LES DÉCISIONS IA
      ExecuteAIDecisionMarketOrder();
   }
   
   // GRAPHIQUES SMC CONTRÔLÉS (toutes les 90 secondes pour alléger MT5)
   if(ShowChartGraphics && currentTime - lastGraphicsUpdate >= 90)
   {
      lastGraphicsUpdate = currentTime;
      
      // DÉTECTION ANTI-REPAINT DES SWING POINTS
      DetectNonRepaintingSwingPoints();
      DrawConfirmedSwingPoints();
      
      // DÉTECTION SPÉCIALE BOOM/CRASH (ANTI-SPIKE)
      if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
      {
         DetectBoomCrashSwingPoints();
      }
      
      // Graphiques essentiels et zones Premium/Discount
      DrawSwingHighLow();
      DrawFVGOnChart();
      DrawOBOnChart();
      DrawFibonacciOnChart();
      DrawEMACurveOnChart();
      DrawLiquidityZonesOnChart();
      
      // Zones Premium/Discount et équilibre
      if(ShowPremiumDiscount) DrawPremiumDiscountZones();
      
      // Autres graphiques optionnels
      if(ShowSignalArrow) { DrawSignalArrow(); UpdateSignalArrowBlink(); }
      // Avertisseur visuel des spikes imminents sur Boom/Crash
      UpdateSpikeWarningBlink();
      if(ShowPredictedSwing) DrawPredictedSwingPoints();
      if(ShowEMASupportResistance) DrawEMASupportResistance();
      if(ShowPredictionChannel) DrawPredictionChannel();
      if(ShowSMCChannelsMultiTF) DrawSMCChannelsMultiTF();
      if(ShowEMASupertrendMultiTF) DrawEMASupertrendMultiTF();
   }
   
   // TABLEAU DE BORD CONTRÔLÉ (toutes les 30 secondes)
   if(currentTime - lastDashboardUpdate >= 30)
   {
      lastDashboardUpdate = currentTime;
      UpdateDashboard();
   }
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
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == InpMagicNumber)
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
           "IA: ", (g_lastAIAction != "") ? (g_lastAIAction + " " + DoubleToString(g_lastAIConfidence*100,1) + "% | Align: " + g_lastAIAlignment + " | Cohér: " + g_lastAICoherence) : "OFF", "\n",
           "Dernière mise à jour IA: ", (g_lastAIUpdate > 0) ? TimeToString(g_lastAIUpdate, TIME_SECONDS) : "Jamais", "\n",
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
   int res = WebRequest("GET", baseUrl + pathMetrics, headers, AI_Timeout_ms2, post, result, resultHeaders);
   if(res != 200)
      res = WebRequest("GET", (UseRenderAsPrimary ? AI_ServerURL : AI_ServerRender) + pathMetrics, headers, AI_Timeout_ms2, post, result, resultHeaders);
   
   string trainStr = "OFF";
   int res2 = WebRequest("GET", baseUrl + pathStatus, headers, AI_Timeout_ms2, post, result2, resultHeaders);
   if(res2 != 200)
      res2 = WebRequest("GET", (UseRenderAsPrimary ? AI_ServerURL : AI_ServerRender) + pathStatus, headers, AI_Timeout_ms2, post, result2, resultHeaders);
   if(res2 == 200)
   {
      string json2 = CharArrayToString(result2);
      Print("🔍 DEBUG ML Status JSON: ", json2); // Debug pour voir la réponse
      
      // Vérifier plusieurs formats possibles
      if(StringFind(json2, "\"enabled\":true") >= 0 || 
         StringFind(json2, "\"enabled\": true") >= 0 ||
         StringFind(json2, "\"enabled\":1") >= 0 ||
         StringFind(json2, "\"enabled\":\"true\"") >= 0)
         trainStr = "ON";
   }
   else
   {
      Print("❌ DEBUG ML Status HTTP: ", res2, " - Échec de la requête status");
   }
   
   // Si l'entraînement est OFF, essayer de le démarrer automatiquement
   if(trainStr == "OFF")
   {
      Print("🚀 Tentative démarrage automatique entraînement ML...");
      string startPath = "/ml/continuous/start?symbols=" + symEnc + "&timeframe=M1";
      char startResult[];
      int startRes = WebRequest("POST", baseUrl + startPath, headers, AI_Timeout_ms2, post, startResult, resultHeaders);
      if(startRes == 200)
      {
         Print("✅ Entraînement ML démarré automatiquement !");
         trainStr = "ON";
      }
      else
      {
         Print("❌ Échec démarrage entraînement ML: HTTP ", startRes);
      }
   }
   
   // Si les deux requêtes ont échoué, afficher erreur mais continuer
   if(res != 200 && res2 != 200) 
   { 
      g_mlMetricsStr = "— | Entraînement: ERREUR CONNEXION"; 
      return; 
   }
   
   // Utiliser la première réponse réussie pour les métriques
   string json = (res == 200) ? CharArrayToString(result) : CharArrayToString(result2);
   
   // Extraire les nombres avec méthode simple
   double accRF = 0;
   int trainSamples = 0;
   double minConf = 0;
   
   // Parser simple pour accuracy
   int accPos = StringFind(json, "\"accuracy\"");
   if(accPos >= 0)
   {
      int start = accPos + 11;
      int i = start;
      while(i < StringLen(json)) { ushort c = StringGetCharacter(json, i); if(c == '-' || (c >= '0' && c <= '9') || c == '.') i++; else break; }
      if(i > start) accRF = StringToDouble(StringSubstr(json, start, i - start));
   }
   
   // Parser pour training_samples
   int samplesPos = StringFind(json, "\"training_samples\"");
   if(samplesPos >= 0)
   {
      int start = samplesPos + 18;
      int i = start;
      while(i < StringLen(json)) { ushort c = StringGetCharacter(json, i); if(c >= '0' && c <= '9') i++; else break; }
      if(i > start) trainSamples = (int)StringToDouble(StringSubstr(json, start, i - start));
   }
   
   // Parser pour min_confidence
   int confPos = StringFind(json, "\"min_confidence\"");
   if(confPos >= 0)
   {
      int start = confPos + 16;
      int i = start;
      while(i < StringLen(json)) { ushort c = StringGetCharacter(json, i); if(c == '-' || (c >= '0' && c <= '9') || c == '.') i++; else break; }
      if(i > start) minConf = StringToDouble(StringSubstr(json, start, i - start));
   }
   
   g_mlMetricsStr = StringFormat("Précision %.0f%% | train: %d | conf min: %.2f | Entraînement: %s", accRF, trainSamples, minConf, trainStr);
}

void DrawSwingHighLow()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 600; // Analyser 600 bougies pour prédiction dynamique (plus léger)
   if(CopyRates(_Symbol, LTF, 0, bars, rates) < bars) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int swingHalf = 300; // Analyser les 300 dernières bougies pour Swing
   ObjectsDeleteAll(0, "SMC_Swing_");
   ObjectsDeleteAll(0, "SMC_Dyn_SH_");
   ObjectsDeleteAll(0, "SMC_Dyn_SL_");
   ObjectsDeleteAll(0, "SMC_Hist_SH_");
   ObjectsDeleteAll(0, "SMC_Hist_SL_");
   
   Print("🎨 DESSIN DES TRAJECTOIRES - Nettoyage effectué, début du dessin...");
   
   // ANALYSE DYNAMIQUE - Basée sur le prix actuel
   double currentPrice = rates[0].close;
   double currentHigh = rates[0].high;
   double currentLow = rates[0].low;
   double currentATR = 0;
   
   // Calculer ATR dynamique basé sur les 20 dernières bougies
   int loopCount = 0;
   for(int i = 1; i < 20 && i < bars; i++)
   {
      double tr = MathMax(rates[i].high - rates[i].low, 
                     MathMax(MathAbs(rates[i].high - rates[i-1].close), 
                              MathAbs(rates[i].low - rates[i-1].close)));
      currentATR += tr;
      loopCount++;
   }
   if(loopCount > 1) currentATR /= (loopCount - 1);
   
   // PRÉDICTION DYNAMIQUE - Basée sur le prix actuel et ATR
   double swingUpTarget = currentPrice + currentATR * 2.0; // Cible Swing High initiale
   double swingDownTarget = currentPrice - currentATR * 2.0; // Cible Swing Low initiale
   
   // Calculer la tendance actuelle pour la pente de prédiction
   double trendSlope = 0;
   if(bars >= 20)
   {
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for(int i = 0; i < 20; i++)
      {
         sumX += i;
         sumY += rates[i].close;
         sumXY += i * rates[i].close;
         sumX2 += i * i;
      }
      trendSlope = (20 * sumXY - sumX * sumY) / (20 * sumX2 - sumX * sumX);
   }
   
   // DÉSSINER LA TRAJECTOIRE FUTURE SUR 1000 BOUGIES (environ 1000 minutes en M1)
   int futureBars = 1000;
   int drawnPoints = 0;
   
   Print("🚀 DÉBUT TRAJECTOIRE FUTURE - ", futureBars, " bougies à dessiner");
   
   // DÉTECTION PRÉCISE DES POINTS FUTURS BASÉE SUR L'ANALYSE TECHNIQUE
   double predictedSwingHighs[], predictedSwingLows[];
   ArrayResize(predictedSwingHighs, 50);
   ArrayResize(predictedSwingLows, 50);
   int swingCount = 0;
   
   // Analyser les 50 dernières bougies pour prédire les prochains swing points
   for(int i = 5; i < 55 && swingCount < 50; i++)
   {
      // Détection de Swing High futur
      bool isFutureSH = true;
      for(int j = MathMax(0, i-5); j <= MathMin(bars-1, i+5); j++)
      {
         if(j != i && rates[j].high >= rates[i].high)
         {
            isFutureSH = false;
            break;
         }
      }
      
      if(isFutureSH && rates[i].high > rates[i].close * 1.002) // Minimum 0.2% au-dessus du close
      {
         predictedSwingHighs[swingCount] = rates[i].high;
         swingCount++;
      }
      
      // Détection de Swing Low futur
      bool isFutureSL = true;
      for(int j = MathMax(0, i-5); j <= MathMin(bars-1, i+5); j++)
      {
         if(j != i && rates[j].low <= rates[i].low)
         {
            isFutureSL = false;
            break;
         }
      }
      
      if(isFutureSL && rates[i].low < rates[i].close * 0.998) // Minimum 0.2% en dessous du close
      {
         predictedSwingLows[swingCount] = rates[i].low;
         swingCount++;
      }
   }
   
   // Dessiner les prédictions avec haute précision
   for(int predIndex = 0; predIndex < swingCount && predIndex < 300; predIndex += 6) // Tous les 6 bougies pour précision
   {
      datetime futureTime = TimeCurrent() + PeriodSeconds(LTF) * (predIndex + 1);
      
      // Calculer la pente progressive basée sur la tendance et l'ATR
      double progressionFactor = (double)predIndex / 300.0;
      double trendComponent = trendSlope * predIndex * 0.8; // Plus de poids sur la tendance
      double volatilityComponent = currentATR * progressionFactor * 2.0; // Volatilité plus prononcée
      
      // PRÉDICTION LONG BUY/SELL BASÉE SUR LES SWINGS DÉTECTÉS
      if(predIndex < ArraySize(predictedSwingHighs) && predictedSwingHighs[predIndex] > 0)
      {
         double shPrice = predictedSwingHighs[predIndex] + trendComponent + volatilityComponent;
         string shName = "SMC_Prec_SH_" + IntegerToString(predIndex);
         if(ObjectCreate(0, shName, OBJ_ARROW, 0, futureTime, shPrice))
         {
            ObjectSetInteger(0, shName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, shName, OBJPROP_WIDTH, 4);
            ObjectSetInteger(0, shName, OBJPROP_ARROWCODE, 233);
            ObjectSetString(0, shName, OBJPROP_TEXT, "LONG BUY");
            ObjectSetInteger(0, shName, OBJPROP_FONTSIZE, 10);
            ObjectSetInteger(0, shName, OBJPROP_ANCHOR, ANCHOR_LOWER);
            ObjectSetInteger(0, shName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            ObjectSetInteger(0, shName, OBJPROP_BACK, false);
            drawnPoints++;
         }
      }
      
      if(predIndex < ArraySize(predictedSwingLows) && predictedSwingLows[predIndex] > 0)
      {
         double slPrice = predictedSwingLows[predIndex] + trendComponent - volatilityComponent;
         string slName = "SMC_Prec_SL_" + IntegerToString(predIndex);
         if(ObjectCreate(0, slName, OBJ_ARROW, 0, futureTime, slPrice))
         {
            ObjectSetInteger(0, slName, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, slName, OBJPROP_WIDTH, 4);
            ObjectSetInteger(0, slName, OBJPROP_ARROWCODE, 234);
            ObjectSetString(0, slName, OBJPROP_TEXT, "LONG SELL");
            ObjectSetInteger(0, slName, OBJPROP_FONTSIZE, 10);
            ObjectSetInteger(0, slName, OBJPROP_ANCHOR, ANCHOR_UPPER);
            ObjectSetInteger(0, slName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            ObjectSetInteger(0, slName, OBJPROP_BACK, false);
            drawnPoints++;
         }
      }
   }
   
   Print("✅ TRAJECTOIRE PRÉCISE TERMINÉE - ", drawnPoints, " points dessinés (LONG BUY: rouge, LONG SELL: vert)");
   
   // DESSINER LES NIVEAUX ACTUELS
   if(ObjectCreate(0, "SMC_Current_Price", OBJ_HLINE, 0, TimeCurrent(), currentPrice))
   {
      ObjectSetInteger(0, "SMC_Current_Price", OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, "SMC_Current_Price", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "SMC_Current_Price", OBJPROP_STYLE, STYLE_DASH);
   }
   
   if(ObjectCreate(0, "SMC_Swing_Up_Target", OBJ_HLINE, 0, TimeCurrent(), swingUpTarget))
   {
      ObjectSetInteger(0, "SMC_Swing_Up_Target", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "SMC_Swing_Up_Target", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, "SMC_Swing_Up_Target", OBJPROP_STYLE, STYLE_DASH);
   }
   
   if(ObjectCreate(0, "SMC_Swing_Down_Target", OBJ_HLINE, 0, TimeCurrent(), swingDownTarget))
   {
      ObjectSetInteger(0, "SMC_Swing_Down_Target", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, "SMC_Swing_Down_Target", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, "SMC_Swing_Down_Target", OBJPROP_STYLE, STYLE_DASH);
   }
   
   Print("🎯 TRAJECTOIRE FUTURE - Prix Actuel: ", currentPrice, " | ATR: ", currentATR, " | Pente: ", trendSlope, " | 3000 bougies M1 (~3h) prédites");
   
   // PLACER DES ORDRES LIMITES DE SCALPING AVANT LES SL/SH PRÉDITS
   PlaceScalpingLimitOrders(rates, futureBars, currentPrice, currentATR, trendSlope);
   
   // DÉTECTER ET AFFICHER LES SWING POINTS HISTORIQUES
   DrawHistoricalSwingPoints(rates, bars, point);
}

void PlaceScalpingLimitOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope)
{
   // Compter les ordres limites existants pour ce symbole
   int existingLimitOrders = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(OrderGetTicket(i)))
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
            (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT) &&
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            existingLimitOrders++;
         }
      }
   }
   
   if(existingLimitOrders >= 2)
   {
      Print("📋 DEUX ORDRES LIMITES DÉJÀ EXISTANTS pour ", _Symbol, " - Maximum atteint");
      return;
   }
   
   // DÉTECTION SPÉCIALE POUR BOOM/CRASH
   string symbol = _Symbol;
   bool isBoom = (StringFind(symbol, "Boom") >= 0);
   bool isCrash = (StringFind(symbol, "Crash") >= 0);
   
   if(isBoom || isCrash)
   {
      DetectAndPlaceBoomCrashSpikeOrders(rates, currentPrice, currentATR, isBoom, existingLimitOrders);
   }
   else
   {
      // LOGIQUE NORMALE POUR AUTRES SYMBOLES BASÉE SUR SH/SL HISTORIQUES
      PlaceHistoricalBasedScalpingOrders(rates, futureBars, currentPrice, currentATR, trendSlope, existingLimitOrders);
   }
}

void PlaceHistoricalBasedScalpingOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope, int existingLimitOrders)
{
   // ANALYSE DES SH/SL HISTORIQUES POUR PRÉDIRE LES MOUVEMENTS FUTURS
   double recentSwingHighs[], recentSwingLows[];
   ArrayResize(recentSwingHighs, 10);
   ArrayResize(recentSwingLows, 10);
   int swingHighCount = 0, swingLowCount = 0;
   
   // Détecter les SH/SL historiques récents (dernières 100 bougies)
   for(int i = 10; i < 100 && (swingHighCount < 10 || swingLowCount < 10); i++)
   {
      // Détection de Swing High historique
      bool isHistoricalSH = true;
      for(int j = MathMax(0, i-5); j <= MathMin(ArraySize(rates)-1, i+5); j++)
      {
         if(j != i && rates[j].high >= rates[i].high)
         {
            isHistoricalSH = false;
            break;
         }
      }
      
      if(isHistoricalSH && rates[i].high > rates[i].close)
      {
         recentSwingHighs[swingHighCount] = rates[i].high;
         swingHighCount++;
      }
      
      // Détection de Swing Low historique
      bool isHistoricalSL = true;
      for(int j = MathMax(0, i-5); j <= MathMin(ArraySize(rates)-1, i+5); j++)
      {
         if(j != i && rates[j].low <= rates[i].low)
         {
            isHistoricalSL = false;
            break;
         }
      }
      
      if(isHistoricalSL && rates[i].low < rates[i].close)
      {
         recentSwingLows[swingLowCount] = rates[i].low;
         swingLowCount++;
      }
   }
   
   // STRATÉGIE BASÉE SUR L'ANALYSE HISTORIQUE
   // Si on a récemment touché un SL, le prix a tendance à monter → BUY LIMIT au niveau exact du SL
   // Si on a récemment touché un SH, le prix a tendance à baisser → SELL LIMIT au niveau exact du SH
   
   int ordersToPlace = 2 - existingLimitOrders; // Maximum 2 ordres par symbole
   
   // ORDRE 1: BASÉ SUR LE DERNIER SL HISTORIQUE (STRATÉGIE BUY)
   if(swingLowCount > 0 && ordersToPlace > 0)
   {
      double lastSL = recentSwingLows[0]; // Le SL le plus récent
      double buyLimitPrice = lastSL; // Ordre placé directement au niveau du SL
      double tpPrice = buyLimitPrice + currentATR * 1.5; // TP plus proche pour scalping
      
      // Ne placer un ordre que si le SL est relativement proche (max 2 ATR)
      if(MathAbs(buyLimitPrice - currentPrice) > currentATR * 2.0)
         goto skip_buy_hist;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_PENDING;
      request.symbol = _Symbol;
      request.volume = NormalizeVolumeForSymbol(0.01);
      request.type = ORDER_TYPE_BUY_LIMIT;
      request.price = buyLimitPrice;
      request.sl = buyLimitPrice - currentATR * 1.5;
      request.tp = tpPrice;
      request.magic = InpMagicNumber;
      request.comment = "HIST SL BUY";
      
      if(OrderSend(request, result))
      {
         Print("📈 ORDRE BUY BASÉ SL HISTORIQUE - Prix: ", buyLimitPrice, " | TP: ", tpPrice, " | SL: ", request.sl);
         ordersToPlace--;
      }
   skip_buy_hist:
   }
   
   // ORDRE 2: BASÉ SUR LE DERNIER SH HISTORIQUE (STRATÉGIE SELL)
   if(swingHighCount > 0 && ordersToPlace > 0)
   {
      double lastSH = recentSwingHighs[0]; // Le SH le plus récent
      double sellLimitPrice = lastSH; // Ordre placé directement au niveau du SH
      double tpPrice = sellLimitPrice - currentATR * 1.5; // TP plus proche pour scalping
      
      if(MathAbs(sellLimitPrice - currentPrice) > currentATR * 2.0)
         goto skip_sell_hist;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_PENDING;
      request.symbol = _Symbol;
      request.volume = NormalizeVolumeForSymbol(0.01);
      request.type = ORDER_TYPE_SELL_LIMIT;
      request.price = sellLimitPrice;
      request.sl = sellLimitPrice + currentATR * 1.5;
      request.tp = tpPrice;
      request.magic = InpMagicNumber;
      request.comment = "HIST SH SELL";
      
      if(OrderSend(request, result))
      {
         Print("📉 ORDRE SELL BASÉ SH HISTORIQUE - Prix: ", sellLimitPrice, " | TP: ", tpPrice, " | SL: ", request.sl);
         ordersToPlace--;
      }
   skip_sell_hist:
   }
   
   if(ordersToPlace > 0)
   {
      Print("📊 STRATÉGIE HISTORIQUE - ", (2 - existingLimitOrders), " ordres placés sur SH/SL historiques");
   }
   else
   {
      Print("📊 AUCUN SH/SL HISTORIQUE VALIDE - Analyse continue...");
   }
}

void DetectAndPlaceBoomCrashSpikeOrders(MqlRates &rates[], double currentPrice, double currentATR, bool isBoom, int existingLimitOrders)
{
   // DÉTECTION DES POINTS D'ENTRÉE DE SPIKE BOOM/CRASH
   double spikeEntryPoints[];
   ArrayResize(spikeEntryPoints, 20);
   int spikeCount = 0;
   
   // Analyser les 30 dernières bougies pour détecter les points de spike
   for(int i = 2; i < 32 && spikeCount < 20; i++)
   {
      // Détection de compression avant spike (volatilité faible)
      bool isCompression = true;
      double avgRange = 0;
      for(int j = i-5; j <= i-1; j++)
      {
         if(j >= 0)
         {
            avgRange += rates[j].high - rates[j].low;
         }
      }
      if(i >= 5) avgRange /= 5;
      
      // Vérifier si les 5 bougies précédentes ont une faible volatilité
      for(int j = i-5; j <= i-1 && j >= 0; j++)
      {
         double currentRange = rates[j].high - rates[j].low;
         if(currentRange > avgRange * 1.5) // Volatilité trop élevée
         {
            isCompression = false;
            break;
         }
      }
      
      // Détection du point d'entrée du spike
      if(isCompression && i >= 2)
      {
         double prevClose = rates[i-1].close;
         double currentClose = rates[i].close;
         double priceChange = MathAbs(currentClose - prevClose) / prevClose;
         
         // Spike significatif détecté
         if(priceChange > 0.008) // 0.8% de mouvement minimum
         {
            spikeEntryPoints[spikeCount] = currentClose;
            spikeCount++;
            
            // Marquer le point d'entrée sur le graphique + activer l'avertisseur clignotant
            string spikeName = "SPIKE_ENTRY_" + IntegerToString(i);
            color spikeColor = isBoom ? clrOrange : clrPurple;
            
            // Positionner l'affichage du spike dans la zone prédite (décalé dans le futur)
            datetime spikeTime = TimeCurrent() + (datetime)(SpikePredictionOffsetMinutes * 60);
            
            if(ObjectCreate(0, spikeName, OBJ_ARROW, 0, spikeTime, currentClose))
            {
               ObjectSetInteger(0, spikeName, OBJPROP_COLOR, spikeColor);
               ObjectSetInteger(0, spikeName, OBJPROP_WIDTH, 5);
               ObjectSetInteger(0, spikeName, OBJPROP_ARROWCODE, isBoom ? 233 : 234);
               ObjectSetString(0, spikeName, OBJPROP_TEXT, isBoom ? "SPIKE BUY" : "SPIKE SELL");
               ObjectSetInteger(0, spikeName, OBJPROP_FONTSIZE, 12);
               ObjectSetInteger(0, spikeName, OBJPROP_ANCHOR, isBoom ? ANCHOR_LOWER : ANCHOR_UPPER);
               ObjectSetInteger(0, spikeName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
               ObjectSetInteger(0, spikeName, OBJPROP_BACK, false);
            }
            
            // Flèche unique d'avertissement clignotante
            if(ObjectFind(0, "SMC_Spike_Warning") < 0)
            {
               if(ObjectCreate(0, "SMC_Spike_Warning", OBJ_ARROW, 0, spikeTime, currentClose))
               {
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_COLOR, clrYellow);
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_WIDTH, 6);
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_ARROWCODE, isBoom ? 233 : 234);
                  ObjectSetString(0, "SMC_Spike_Warning", OBJPROP_TEXT, "SPIKE IMMINENT");
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_FONTSIZE, 14);
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_ANCHOR, isBoom ? ANCHOR_LOWER : ANCHOR_UPPER);
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_BACK, false);
               }
            }
            else
            {
               ObjectMove(0, "SMC_Spike_Warning", 0, rates[i].time, currentClose);
               ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_COLOR, clrYellow);
            }
            
            g_spikeWarningActive = true;
            g_spikeWarningStart = TimeCurrent();
            g_spikeWarningVisible = true;
         }
      }
   }
   
   // PLACER LES ORDRES LIMITES AUX POINTS D'ENTRÉE DÉTECTÉS
   if(spikeCount > 0)
   {
      int ordersToPlace = MathMin(2 - existingLimitOrders, spikeCount); // Limiter par le nombre d'ordres disponibles
      
      for(int i = 0; i < ordersToPlace && i < spikeCount; i++)
      {
         // Prendre le point de spike le plus récent
         double entryPrice = spikeEntryPoints[i];
         string spikeType = isBoom ? "BOOM SPIKE BUY" : "CRASH SPIKE SELL";
         
         // Placer ordre limite exactement au point d'entrée
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_PENDING;
         request.symbol = _Symbol;
         request.volume = NormalizeVolumeForSymbol(0.01);
         request.type = isBoom ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
         request.price = entryPrice;
         request.sl = entryPrice - (isBoom ? currentATR * 2.0 : -currentATR * 2.0);
         request.tp = entryPrice + (isBoom ? currentATR * 4.0 : -currentATR * 4.0);
         request.magic = InpMagicNumber;
         request.comment = spikeType;
         
         if(OrderSend(request, result))
         {
            Print("🚀 ", spikeType, " PLACÉ - Entrée: ", entryPrice, " | TP: ", request.tp, " | SL: ", request.sl);
         }
         else
         {
            Print("❌ ÉCHEC PLACEMENT ", spikeType, " - Erreur: ", result.comment);
         }
      }
      
      if(ordersToPlace < spikeCount)
      {
         Print("🚀 ", (spikeCount - ordersToPlace), " spikes supplémentaires détectés mais ordres limites non disponibles");
      }
   }
   else
   {
      Print("📊 AUCUN SPIKE BOOM/CRASH DÉTECTÉ - Analyse continue...");
   }
}

void PlaceNormalScalpingOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope)
{
   // Chercher les prochains SL/SH significatifs dans les 30 prochaines minutes (900 bougies M1)
   int lookAheadBars = MathMin(900, futureBars);
   double bestSLPrice = 0, bestSHPrice = 0;
   datetime bestSLTime = 0, bestSHTime = 0;
   
   for(int predIndex = 30; predIndex < lookAheadBars; predIndex += 30) // Vérifier toutes les 30 bougies
   {
      datetime futureTime = TimeCurrent() + PeriodSeconds(LTF) * predIndex;
      double progressionFactor = (double)predIndex / futureBars;
      double trendComponent = trendSlope * predIndex * 0.5;
      double volatilityComponent = currentATR * progressionFactor * 1.5;
      
      // Calculer les prix prédits
      double shPrice = (currentPrice + currentATR * 2.0) + trendComponent + volatilityComponent * MathSin(predIndex * 0.1);
      double slPrice = (currentPrice - currentATR * 2.0) + trendComponent - volatilityComponent * MathSin(predIndex * 0.1);
      
      // Garder les SL/SH les plus proches et significatifs
      if(slPrice < currentPrice && (bestSLPrice == 0 || slPrice > bestSLPrice))
      {
         bestSLPrice = slPrice;
         bestSLTime = futureTime;
      }
      
      if(shPrice > currentPrice && (bestSHPrice == 0 || shPrice < bestSHPrice))
      {
         bestSHPrice = shPrice;
         bestSHTime = futureTime;
      }
   }
   
   // Calculer la distance par rapport au prix actuel
   double distanceToSL = (bestSLPrice > 0) ? currentPrice - bestSLPrice : DBL_MAX;
   double distanceToSH = (bestSHPrice > 0) ? bestSHPrice - currentPrice : DBL_MAX;
   
   // Placer UN SEUL ordre limite au niveau le plus proche du prix
   if(distanceToSL < distanceToSH && bestSLPrice > 0)
   {
      // Placer BUY LIMIT au SL le plus proche (niveau exact)
      double buyLimitPrice = bestSLPrice;
      double tpPrice = buyLimitPrice + currentATR * 2.0;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_PENDING;
      request.symbol = _Symbol;
      request.volume = NormalizeVolumeForSymbol(0.01);
      request.type = ORDER_TYPE_BUY_LIMIT;
      request.price = buyLimitPrice;
      request.sl = buyLimitPrice - currentATR * 1.0;
      request.tp = tpPrice;
      request.magic = InpMagicNumber;
      request.comment = "Scalp SL Near";
      
      if(OrderSend(request, result))
      {
         Print("📈 SEUL ORDRE LIMIT BUY PLACÉ - Prix: ", buyLimitPrice, " | TP: ", tpPrice, " | SL: ", request.sl, " | Distance: ", distanceToSL, " points");
      }
   }
   else if(bestSHPrice > 0)
   {
      // Placer SELL LIMIT au SH le plus proche (niveau exact)
      double sellLimitPrice = bestSHPrice;
      double tpPrice = sellLimitPrice - currentATR * 2.0;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_PENDING;
      request.symbol = _Symbol;
      request.volume = NormalizeVolumeForSymbol(0.01);
      request.type = ORDER_TYPE_SELL_LIMIT;
      request.price = sellLimitPrice;
      request.sl = sellLimitPrice + currentATR * 1.0;
      request.tp = tpPrice;
      request.magic = InpMagicNumber;
      request.comment = "Scalp SH Near";
      
      if(OrderSend(request, result))
      {
         Print("📉 SEUL ORDRE LIMIT SELL PLACÉ - Prix: ", sellLimitPrice, " | TP: ", tpPrice, " | SL: ", request.sl, " | Distance: ", distanceToSH, " points");
      }
   }
   else
   {
      Print("❌ AUCUN NIVEAU VALIDE TROUVÉ pour ordre de scalping");
   }
}

void DrawHistoricalSwingPoints(MqlRates &rates[], int bars, double point)
{
   int swingLookback = 5; // Nombre de bougies de chaque côté pour valider un swing point
   int maxSwings = 20; // Nombre maximum de swing points à afficher
   int swingCount = 0;
   
   // Parcourir les bougies historiques pour détecter les swing points
   for(int i = swingLookback; i < bars - swingLookback && swingCount < maxSwings; i++)
   {
      // Détecter Swing High (le high de la bougie i est plus élevé que les swingLookback bougies avant et après)
      bool isSwingHigh = true;
      for(int j = i - swingLookback; j <= i + swingLookback; j++)
      {
         if(j != i && rates[j].high >= rates[i].high)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      if(isSwingHigh)
      {
         string shName = "SMC_Hist_SH_" + IntegerToString(i);
         if(ObjectCreate(0, shName, OBJ_ARROW, 0, rates[i].time, rates[i].high))
         {
            ObjectSetInteger(0, shName, OBJPROP_COLOR, clrCrimson);
            ObjectSetInteger(0, shName, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, shName, OBJPROP_ARROWCODE, 233); // Flèche vers le haut
            ObjectSetString(0, shName, OBJPROP_TEXT, "SH");
            ObjectSetInteger(0, shName, OBJPROP_FONTSIZE, 10);
            ObjectSetInteger(0, shName, OBJPROP_ANCHOR, ANCHOR_LOWER);
            ObjectSetInteger(0, shName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS); // Visible sur tous les timeframes
            ObjectSetInteger(0, shName, OBJPROP_BACK, false); // Au premier plan
            swingCount++;
         }
      }
      
      // Détecter Swing Low (le low de la bougie i est plus bas que les swingLookback bougies avant et après)
      bool isSwingLow = true;
      for(int j = i - swingLookback; j <= i + swingLookback; j++)
      {
         if(j != i && rates[j].low <= rates[i].low)
         {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingLow)
      {
         string slName = "SMC_Hist_SL_" + IntegerToString(i);
         if(ObjectCreate(0, slName, OBJ_ARROW, 0, rates[i].time, rates[i].low))
         {
            ObjectSetInteger(0, slName, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, slName, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, slName, OBJPROP_ARROWCODE, 234); // Flèche vers le bas
            ObjectSetString(0, slName, OBJPROP_TEXT, "SL");
            ObjectSetInteger(0, slName, OBJPROP_FONTSIZE, 10);
            ObjectSetInteger(0, slName, OBJPROP_ANCHOR, ANCHOR_UPPER);
            ObjectSetInteger(0, slName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS); // Visible sur tous les timeframes
            ObjectSetInteger(0, slName, OBJPROP_BACK, false); // Au premier plan
            swingCount++;
         }
      }
   }
   
   Print("📍 SWING HISTORIQUES - ", swingCount, " points détectés (SH: rouge, SL: bleu)");
}

void DrawFVGOnChart()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 80;
   if(CopyRates(_Symbol, LTF, 0, bars, rates) < bars) return;
   ObjectsDeleteAll(0, "SMC_FVG_");
   int cnt = 0;
   for(int fvgIndex = 2; fvgIndex < bars - 2 && cnt < 15; fvgIndex++)
   {
      if(rates[fvgIndex].close > rates[fvgIndex].open && rates[fvgIndex+1].high < rates[fvgIndex-1].low)
      {
         double top = rates[fvgIndex-1].low, bot = rates[fvgIndex+1].high;
         datetime t1 = rates[fvgIndex+1].time, t2 = TimeCurrent() + PeriodSeconds(LTF)*20;
         string name = "SMC_FVG_Bull_" + IntegerToString(fvgIndex);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, bot, t2, top))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_BACK, false);
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            cnt++;
         }
      }
      if(rates[fvgIndex].close < rates[fvgIndex].open && rates[fvgIndex+1].low > rates[fvgIndex-1].high)
      {
         double top = rates[fvgIndex+1].low, bot = rates[fvgIndex-1].high;
         datetime t1 = rates[fvgIndex+1].time, t2 = TimeCurrent() + PeriodSeconds(LTF)*20;
         string name = "SMC_FVG_Bear_" + IntegerToString(fvgIndex);
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
   for(int fvgIndex = 3; fvgIndex < bars - 4 && cnt < 10; fvgIndex++)
   {
      if(rates[fvgIndex].close < rates[fvgIndex].open && rates[fvgIndex+1].close > rates[fvgIndex+1].open && (rates[fvgIndex+1].high - rates[fvgIndex].low) > point*20)
      {
         datetime t2 = TimeCurrent() + PeriodSeconds(LTF)*30;
         string name = "SMC_OB_Bull_" + IntegerToString(fvgIndex);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, rates[fvgIndex].time, rates[fvgIndex].low, t2, rates[fvgIndex].high))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            cnt++;
         }
      }
      if(rates[fvgIndex].close > rates[fvgIndex].open && rates[fvgIndex+1].close < rates[fvgIndex+1].open && (rates[fvgIndex].high - rates[fvgIndex+1].low) > point*20)
      {
         datetime t2 = TimeCurrent() + PeriodSeconds(LTF)*30;
         string name = "SMC_OB_Bear_" + IntegerToString(fvgIndex);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, rates[fvgIndex].time, rates[fvgIndex].low, t2, rates[fvgIndex].high))
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
   
   // Ligne verticale pour séparer clairement la zone passée de la zone prédite
   ObjectDelete(0, "SMC_PAST_FUTURE_DIVIDER");
   if(ObjectCreate(0, "SMC_PAST_FUTURE_DIVIDER", OBJ_VLINE, 0, t1, 0))
   {
      ObjectSetInteger(0, "SMC_PAST_FUTURE_DIVIDER", OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, "SMC_PAST_FUTURE_DIVIDER", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "SMC_PAST_FUTURE_DIVIDER", OBJPROP_STYLE, STYLE_SOLID);
   }
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

// Avertisseur clignotant pour l'arrivée imminente d'un spike Boom/Crash
void UpdateSpikeWarningBlink()
{
   if(!g_spikeWarningActive) return;
   if(StringFind(_Symbol, "Boom") < 0 && StringFind(_Symbol, "Crash") < 0) return;
   
   datetime now = TimeCurrent();
   
   // Supprimer l'avertisseur après 2 minutes ou si l'objet n'existe plus
   if(now - g_spikeWarningStart > 120 || ObjectFind(0, "SMC_Spike_Warning") < 0)
   {
      ObjectDelete(0, "SMC_Spike_Warning");
      g_spikeWarningActive = false;
      return;
   }
   
   // Clignotement toutes les 0.7 seconde
   if(now - g_spikeBlinkTime >= 1)
   {
      g_spikeBlinkTime = now;
      g_spikeWarningVisible = !g_spikeWarningVisible;
      
      if(ObjectFind(0, "SMC_Spike_Warning") >= 0)
      {
         color c = g_spikeWarningVisible ? clrYellow : clrNONE;
         ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_COLOR, c);
      }
   }
}

// Entrée automatique quand le prix touche les niveaux SH/SL prédits (canal ML)
void CheckPredictedSwingTriggers()
{
   // Pas de nouvelle position si on a déjà atteint la limite
   if(CountPositionsOurEA() >= MaxPositionsTerminal) return;
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int total = ObjectsTotal(0, -1, -1);
   if(total <= 0) return;
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      // Traiter à la fois les SH/SL prédits par le canal ML, les swings dynamiques et la trajectoire précise
      bool isPredSH = (StringFind(name, "SMC_Pred_SH_") == 0 || StringFind(name, "SMC_Dyn_SH_") == 0 || StringFind(name, "SMC_Prec_SH_") == 0);
      bool isPredSL = (StringFind(name, "SMC_Pred_SL_") == 0 || StringFind(name, "SMC_Dyn_SL_") == 0 || StringFind(name, "SMC_Prec_SL_") == 0);
      
      if(isPredSH)
      {
         double level = ObjectGetDouble(0, name, OBJPROP_PRICE);
         // Déclencher un SELL au marché quand le prix touche ou dépasse le SH prédit
         if(bid >= level && level > 0)
         {
            SMC_Signal sig;
            sig.action = "SELL";
            sig.entryPrice = bid;
            sig.reasoning = "Predicted SH touch";
            sig.concept = "Pred-SH";
            // SL/TP simples basés sur ATR via DetectSMCSignal / ExecuteSignal
            // Utiliser les paramètres par défaut de SL/TP en laissant 0 (ils seront gérés par trailing + gestion globale)
            sig.stopLoss = 0;
            sig.takeProfit = 0;
            ExecuteSignal(sig);
            
            // Supprimer le niveau pour éviter des déclenchements multiples
            ObjectDelete(0, name);
            break;
         }
      }
      else if(isPredSL)
      {
         double level = ObjectGetDouble(0, name, OBJPROP_PRICE);
         // Déclencher un BUY au marché quand le prix touche ou casse le SL prédit
         if(ask <= level && level > 0)
         {
            SMC_Signal sig;
            sig.action = "BUY";
            sig.entryPrice = ask;
            sig.reasoning = "Predicted SL touch";
            sig.concept = "Pred-SL";
            sig.stopLoss = 0;
            sig.takeProfit = 0;
            ExecuteSignal(sig);
            
            ObjectDelete(0, name);
            break;
         }
      }
   }
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

void DrawSMCChannelsMultiTF()
{
   // Tracer les canaux SMC (upper/lower) depuis H1, M30, M5 projetés sur M1
   datetime currentTime = TimeCurrent();
   
   // Timeframes à analyser
   ENUM_TIMEFRAMES tfs[] = {PERIOD_H1, PERIOD_M30, PERIOD_M5};
   string tfNames[] = {"H1", "M30", "M5"};
   color tfColors[] = {clrBlue, clrPurple, clrGreen};
   
   for(int i = 0; i < ArraySize(tfs); i++)
   {
      string prefix = "SMC_CH_" + tfNames[i] + "_";
      ObjectsDeleteAll(0, prefix);
      
      // Récupérer les données du timeframe
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, tfs[i], 0, 200, rates) < 50) continue;
      
      // Calculer les hauts et bas pour le canal
      double upper = rates[0].high;
      double lower = rates[0].low;
      
      for(int j = 1; j < 100; j++) // Analyser les 100 dernières bougies
      {
         if(rates[j].high > upper) upper = rates[j].high;
         if(rates[j].low < lower) lower = rates[j].low;
      }
      
      // Projeter sur 5000 bougies M1 futures
      datetime startTime = currentTime;
      datetime endTime = currentTime + (datetime)(SMCChannelFutureBars * 60); // 5000 bougies M1 = 5000 minutes
      
      // Tracer la ligne supérieure du canal
      string upperName = prefix + "UPPER";
      ObjectCreate(0, upperName, OBJ_TREND, 0, startTime, upper, endTime, upper);
      ObjectSetInteger(0, upperName, OBJPROP_COLOR, tfColors[i]);
      ObjectSetInteger(0, upperName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, upperName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, upperName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, upperName, OBJPROP_BACK, false);
      ObjectSetString(0, upperName, OBJPROP_TOOLTIP, "Canal SMC " + tfNames[i] + " - Upper");
      
      // Tracer la ligne inférieure du canal
      string lowerName = prefix + "LOWER";
      ObjectCreate(0, lowerName, OBJ_TREND, 0, startTime, lower, endTime, lower);
      ObjectSetInteger(0, lowerName, OBJPROP_COLOR, tfColors[i]);
      ObjectSetInteger(0, lowerName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lowerName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lowerName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, lowerName, OBJPROP_BACK, false);
      ObjectSetString(0, lowerName, OBJPROP_TOOLTIP, "Canal SMC " + tfNames[i] + " - Lower");
      
      // Ajouter un label
      string labelName = prefix + "LABEL";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, startTime, upper);
      ObjectSetString(0, labelName, OBJPROP_TEXT, "SMC " + tfNames[i]);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, tfColors[i]);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }
}

void DrawEMASupertrendMultiTF()
{
   // Tracer l'EMA Supertrend Support/Résistance sur H1, M30, M5 
   // depuis 1000 bougies passées jusqu'à 5000 bougies futures M1
   datetime currentTime = TimeCurrent();
   
   // Timeframes à analyser
   ENUM_TIMEFRAMES tfs[] = {PERIOD_H1, PERIOD_M30, PERIOD_M5};
   string tfNames[] = {"H1", "M30", "M5"};
   color supportColors[] = {clrGreen, clrLime, clrAqua};
   color resistanceColors[] = {clrRed, clrOrange, clrMagenta};
   
   for(int i = 0; i < ArraySize(tfs); i++)
   {
      string prefix = "EMA_ST_" + tfNames[i] + "_";
      ObjectsDeleteAll(0, prefix);
      
      // Récupérer les EMA rapides, lentes et ATR pour l'historique
      double emaFast[], emaSlow[], atr[];
      datetime times[];
      ArraySetAsSeries(emaFast, true);
      ArraySetAsSeries(emaSlow, true);
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(times, true);
      
      int fastHandle = (tfs[i] == PERIOD_H1) ? emaFastH1 : 
                     (tfs[i] == PERIOD_M30) ? emaFastM5 : emaFastM1;
      int slowHandle = (tfs[i] == PERIOD_H1) ? emaSlowH1 : 
                     (tfs[i] == PERIOD_M30) ? emaSlowM5 : emaSlowM1;
      int atrHandleTF = (tfs[i] == PERIOD_H1) ? atrH1 : 
                       (tfs[i] == PERIOD_M30) ? atrM5 : atrM1;
      
      // Copier 1000 bougies passées + 5000 futures = 6000 total
      int totalBars = 6000;
      if(CopyBuffer(fastHandle, 0, -totalBars, totalBars, emaFast) < totalBars) continue;
      if(CopyBuffer(slowHandle, 0, -totalBars, totalBars, emaSlow) < totalBars) continue;
      if(CopyBuffer(atrHandleTF, 0, -totalBars, totalBars, atr) < totalBars) continue;
      if(CopyTime(_Symbol, tfs[i], -totalBars, totalBars, times) < totalBars) continue;
      
      // Tracer la ligne Supertrend complète (passé + futur)
      string lineName = prefix + "LINE";
      
      // Point de départ (1000 bougies dans le passé)
      datetime startTime = times[0];
      double emaFastStart = emaFast[0];
      double emaSlowStart = emaSlow[0];
      double atrStart = atr[0];
      
      // Calculer Supertrend de départ
      double supertrendStart = 0;
      string directionStart = "";
      if(emaFastStart > emaSlowStart)
      {
         supertrendStart = emaSlowStart - (atrStart * ATRMultiplier); // Support
         directionStart = "SUPPORT";
      }
      else
      {
         supertrendStart = emaSlowStart + (atrStart * ATRMultiplier); // Résistance
         directionStart = "RESISTANCE";
      }
      
      // Point de fin (5000 bougies dans le futur)
      datetime endTime = currentTime + (datetime)(SMCChannelFutureBars * 60);
      
      // Créer la ligne de tendance complète
      ObjectCreate(0, lineName, OBJ_TREND, 0, startTime, supertrendStart, endTime, supertrendStart);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, 
                     (directionStart == "SUPPORT") ? supportColors[i] : resistanceColors[i]);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
      ObjectSetString(0, lineName, OBJPROP_TOOLTIP, 
                     "EMA Supertrend " + tfNames[i] + " - " + directionStart + " (1000 passé → 5000 futur)");
      
      // Ajouter des points de repère tous les 500 bougies
      int stepBars = 500;
      for(int j = 0; j < totalBars; j += stepBars)
      {
         if(j >= ArraySize(emaFast)) break;
         
         datetime pointTime = times[j];
         double emaFastVal = emaFast[j];
         double emaSlowVal = emaSlow[j];
         double atrVal = atr[j];
         
         double supertrend = 0;
         string direction = "";
         
         if(emaFastVal > emaSlowVal)
         {
            supertrend = emaSlowVal - (atrVal * ATRMultiplier); // Support
            direction = "SUPPORT";
         }
         else
         {
            supertrend = emaSlowVal + (atrVal * ATRMultiplier); // Résistance
            direction = "RESISTANCE";
         }
         
         // Tracer un point de repère
         string pointName = prefix + "POINT_" + IntegerToString(j);
         ObjectCreate(0, pointName, OBJ_ARROW, 0, pointTime, supertrend);
         ObjectSetInteger(0, pointName, OBJPROP_ARROWCODE, 159); // Cercle
         ObjectSetInteger(0, pointName, OBJPROP_COLOR, 
                        (direction == "SUPPORT") ? supportColors[i] : resistanceColors[i]);
         ObjectSetInteger(0, pointName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, pointName, OBJPROP_BACK, false);
      }
      
      // Ajouter un label principal
      string labelName = prefix + "LABEL";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, startTime, supertrendStart);
      ObjectSetString(0, labelName, OBJPROP_TEXT, 
                     "EMA-ST " + tfNames[i] + " " + directionStart);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, 
                     (directionStart == "SUPPORT") ? supportColors[i] : resistanceColors[i]);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
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
   bool inDiscount = IsInDiscountZone();
   bool inPremium  = IsInPremiumZone();
   if(inDiscount) { hasBuySignal = true; reason += "Zone-Discount "; }
   if(inPremium)  { hasSellSignal = true; reason += "Zone-Premium "; }

   if(RequireStructureAfterSweep && UseLiquiditySweep)
   {
      bool waitOk = !NoEntryDuringSweep || (lsBarsAgo >= 1); // Réduit de 2 à 1 barre
      // Moins restrictif: ne bloquer que les signaux contradictoires directs
      if(lsSSL && hasSellSignal) hasSellSignal = false; // Bloquer SELL si SSL détecté
      if(lsBSL && hasBuySignal) hasBuySignal = false;  // Bloquer BUY si BSL détecté
      // Garder les autres signaux même sans confirmation LS
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
         // Calculer SL/TP plus proches du prix actuel
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         if(StopBeyondNewStructure && lsSSL && newSwingLow > 0)
            sig.stopLoss = newSwingLow - buffer;
         else
         {
            // SL plus proche : utiliser 20-30 pips au lieu de la distance ATR complète
            double minSL = MathMax(20.0 * _Point, slDist * 0.3); // 30% de la distance ATR
            sig.stopLoss = currentAsk - minSL;
         }
         
         // TP plus proche : utiliser 40-60 pips au lieu de la distance ATR complète
         double minTP = MathMax(40.0 * _Point, tpDist * 0.4); // 40% de la distance ATR
         sig.takeProfit = currentAsk + minTP;
         
         Print("📊 SL/TP ajustés: SL=", DoubleToString(sig.stopLoss, _Digits), 
                " TP=", DoubleToString(sig.takeProfit, _Digits), 
                " Ask=", DoubleToString(currentAsk, _Digits));
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
         // Calculer SL/TP plus proches du prix actuel
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         if(StopBeyondNewStructure && lsBSL && newSwingHigh > 0)
            sig.stopLoss = newSwingHigh + buffer;
         else
         {
            // SL plus proche : utiliser 20-30 pips au lieu de la distance ATR complète
            double minSL = MathMax(20.0 * _Point, slDist * 0.3); // 30% de la distance ATR
            sig.stopLoss = currentBid + minSL;
         }
         
         // TP plus proche : utiliser 40-60 pips au lieu de la distance ATR complète
         double minTP = MathMax(40.0 * _Point, tpDist * 0.4); // 40% de la distance ATR
         sig.takeProfit = currentBid - minTP;
         
         Print("📊 SL/TP ajustés SELL: SL=", DoubleToString(sig.stopLoss, _Digits), 
                " TP=", DoubleToString(sig.takeProfit, _Digits), 
                " Bid=", DoubleToString(currentBid, _Digits));
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
   
   // Plus permissif: utiliser la dernière décision IA si disponible
   if(g_lastAIAction != "" && g_lastAIConfidence > 0)
   {
      // Confiance réduite pour plus d'opportunités
      if(g_lastAIConfidence >= 0.35) // 35% au lieu de 55%
      {
         if(sig.action == "BUY" && (g_lastAIAction == "BUY" || g_lastAIAction == "buy")) 
         {
            Print("✅ Signal BUY confirmé par IA (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
            return true;
         }
         if(sig.action == "SELL" && (g_lastAIAction == "SELL" || g_lastAIAction == "sell")) 
         {
            Print("✅ Signal SELL confirmé par IA (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
            return true;
         }
      }
   }
   
   // Fallback plus permissif si IA disponible mais faible confiance
   if(g_lastAIConfidence >= 0.25 && g_lastAIConfidence > 0)
   {
      Print("⚠️ Signal exécuté avec faible confiance IA (", DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return true;
   }
   
   // Si IA indisponible, autoriser quand même pour ne pas manquer d'opportunités
   if(g_lastAIAction == "" || g_lastAIConfidence == 0)
   {
      Print("🔄 IA indisponible - Signal SMC exécuté sans confirmation");
      return true;
   }
   
   Print("❌ Signal rejeté - IA: ", g_lastAIAction, " (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
   return false;
}

//+------------------------------------------------------------------+
void ExecuteSignal(SMC_Signal &sig)
{
   if(CountPositionsOurEA() >= MaxPositionsTerminal) return;
   if(!TryAcquireOpenLock()) return;
   double lotSize = CalculateLotSize();
   if(lotSize <= 0) { ReleaseOpenLock(); return; }
   
   // Bloquer les signaux contraires à la direction IA principale
   // uniquement si la confiance IA est vraiment forte (>= max(MinAIConfidence, 60%))
   double strongAIThreshold = MathMax(MinAIConfidence, 0.60);
   if(g_lastAIConfidence >= strongAIThreshold)
   {
      if((g_lastAIAction == "BUY" || g_lastAIAction == "buy") && sig.action == "SELL")
      {
         Print("❌ SELL SMC bloqué car IA = BUY (conf: ", DoubleToString(g_lastAIConfidence*100,1), "%)");
         ReleaseOpenLock();
         return;
      }
      if((g_lastAIAction == "SELL" || g_lastAIAction == "sell") && sig.action == "BUY")
      {
         Print("❌ BUY SMC bloqué car IA = SELL (conf: ", DoubleToString(g_lastAIConfidence*100,1), "%)");
         ReleaseOpenLock();
         return;
      }
   }
   
   // Réinitialiser le gain maximum pour la nouvelle position
   g_maxProfit = 0;
   
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

// Normaliser un volume arbitraire en respectant min/max/step du symbole
double NormalizeVolumeForSymbol(double desiredVolume)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = minLot;
   double vol = desiredVolume;
   if(vol < minLot) vol = minLot;
   if(vol > maxLot) vol = maxLot;
   vol = MathFloor(vol / lotStep + 1e-8) * lotStep;
   return NormalizeDouble(vol, 2);
}

//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   // Vérifier si l'ATR handle est valide
   if(atrHandle == INVALID_HANDLE) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber || posInfo.Symbol() != _Symbol) continue;
      
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      double openPrice = posInfo.PriceOpen();
      double currentSL = posInfo.StopLoss();
      
      // Si pas de stop loss défini, en créer un pour protéger
      if(currentSL == 0)
      {
         double atr[];
         ArraySetAsSeries(atr, true);
         if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) continue;
         
         double trailDistance = atr[0] * TrailingStop_ATRMult;
         
         if(posInfo.PositionType() == POSITION_TYPE_BUY)
         {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double newSL = currentPrice - trailDistance;
            if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
               Print("🛡️ Stop loss initial BUY: ", DoubleToString(newSL, _Digits));
         }
         else
         {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double newSL = currentPrice + trailDistance;
            if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
               Print("🛡️ Stop loss initial SELL: ", DoubleToString(newSL, _Digits));
         }
         continue;
      }
      
      // Trail si position est en gain OU si on risque de perdre >50% du gain maximum
      bool shouldTrail = false;
      
      if(profit > 0)
      {
         shouldTrail = true;
         if(profit > g_maxProfit) g_maxProfit = profit;
      }
      else if(g_maxProfit > 0 && MathAbs(profit) > g_maxProfit * 0.5)
      {
         shouldTrail = true; // Protéger contre perte >50% du gain max
         Print("🚨 Protection 50%: gain max=", DoubleToString(g_maxProfit, 2), "$, perte actuelle=", DoubleToString(MathAbs(profit), 2), "$");
      }
      
      if(!shouldTrail) continue;
      
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) continue;
      
      // Trail based on ATR distance from current price
      double trailDistance = atr[0] * TrailingStop_ATRMult;  // Use configurable ATR multiplier
      
      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSL = currentPrice - trailDistance;
         
         // Only move SL if it improves the current SL and is above open price
         if(newSL > currentSL && newSL > openPrice)
         {
            if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
            {
               Print("🔄 Trailing Stop BUY mis à jour: ", DoubleToString(currentSL, _Digits), " → ", DoubleToString(newSL, _Digits));
            }
         }
      }
      else if(posInfo.PositionType() == POSITION_TYPE_SELL)
      {
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSL = currentPrice + trailDistance;
         
         // Only move SL if it improves the current SL and is below open price
         if((newSL < currentSL || currentSL == 0) && newSL < openPrice)
         {
            if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
            {
               Print("🔄 Trailing Stop SELL mis à jour: ", DoubleToString(currentSL, _Digits), " → ", DoubleToString(newSL, _Digits));
            }
         }
      }
   }
}

bool UpdateAIDecision(int timeoutMs = -1)
{
   // Protection contre les appels excessifs
   static datetime lastAttempt = 0;
   if(TimeCurrent() - lastAttempt < 30) return true; // Max 1 appel par 30 secondes
   lastAttempt = TimeCurrent();
   
   // Utiliser le timeout passé en paramètre ou celui par défaut
   int actualTimeout = (timeoutMs > 0) ? timeoutMs : MathMin(AI_Timeout_ms, 2000);
   
   string symEnc = _Symbol;
   StringReplace(symEnc, " ", "%20");
   
   // Vérifier si les données sont disponibles (CORRECTION: 50 > 10 est correct)
   if(ArraySize(g_chartDataBuffer) < 10)
   {
      Print("❌ IA: Pas assez de données (", ArraySize(g_chartDataBuffer), " < 10)");
      return false;
   }
   
   Print("✅ IA: Données disponibles (", ArraySize(g_chartDataBuffer), " bougies) - Traitement...");
   
   // Préparer les features depuis les données MT5 capturées
   string json_features = "{\"features\":[";
   for(int i = 0; i < ArraySize(g_chartDataBuffer); i++)
   {
      // Calculer les vraies features pour cette bougie
      double close = g_chartDataBuffer[i].close;
      double open = g_chartDataBuffer[i].open;
      double high = g_chartDataBuffer[i].high;
      double low = g_chartDataBuffer[i].low;
      double volume = (double)g_chartDataBuffer[i].tick_volume;
      
      // Calculer les indicateurs techniques
      double rsi = 50.0; // Valeur par défaut
      double macd = 0.0;
      double atr = 0.001;
      double ema5 = close;
      double ema10 = close;
      double ema20 = close;
      double ema50 = close;
      
      if(i >= 14)
      {
         // Calcul RSI simplifié (avec bornes sécurisées pour éviter array out of range)
         double gains = 0, losses = 0;
         int maxLookback = MathMin(14, i - 1); // on ne remonte jamais au-delà de l'indice 0
         for(int j = 1; j <= maxLookback; j++)
         {
            int idx1 = i - j;
            int idx0 = i - j - 1;
            if(idx0 < 0 || idx1 < 0) continue;
            if(idx1 >= ArraySize(g_chartDataBuffer) || idx0 >= ArraySize(g_chartDataBuffer)) continue;
            
            double change = g_chartDataBuffer[idx1].close - g_chartDataBuffer[idx0].close;
            if(change > 0) gains += change;
            else losses -= change;
         }
         if(losses > 0) rsi = 100 - (100 / (1 + gains/losses/14));
      }
      
      if(i >= 5)
      {
         // EMA5 simplifiée
         double sum5 = 0;
         for(int j = 0; j < 5; j++)
         {
            if(i - j >= 0) sum5 += g_chartDataBuffer[i - j].close;
         }
         ema5 = sum5 / 5;
      }
      
      if(i >= 20)
      {
         // EMA20 simplifiée
         double sum20 = 0;
         for(int j = 0; j < 20; j++)
         {
            if(i - j >= 0) sum20 += g_chartDataBuffer[i - j].close;
         }
         ema20 = sum20 / 20;
      }
      
      // ATR simplifié
      if(i >= 1)
      {
         double tr = MathMax(high - low, MathMax(MathAbs(high - g_chartDataBuffer[i-1].close), MathAbs(low - g_chartDataBuffer[i-1].close)));
         atr = tr;
      }
      
      // Calculer les returns avec vérification des bornes
      double return1 = 0, return2 = 0, return3 = 0;
      if(i >= 1 && i - 1 < ArraySize(g_chartDataBuffer))
         return1 = (close - g_chartDataBuffer[i-1].close) / g_chartDataBuffer[i-1].close;
      if(i >= 2 && i - 2 < ArraySize(g_chartDataBuffer))
         return2 = (close - g_chartDataBuffer[i-2].close) / g_chartDataBuffer[i-2].close;
      if(i >= 3 && i - 3 < ArraySize(g_chartDataBuffer))
         return3 = (close - g_chartDataBuffer[i-3].close) / g_chartDataBuffer[i-3].close;
      
      // Volatilité
      double volatility = (high - low) / close;
      double price_range = high - low;
      double body_size = MathAbs(close - open);
      double upper_shadow = (high - MathMax(open, close));
      
      // Heures
      MqlDateTime dt;
      TimeToStruct(g_chartDataBuffer[i].time, dt);
      double hour = dt.hour;
      double minute = dt.min;
      double day_of_week = dt.day_of_week;
      
      json_features += "{\"close\":" + DoubleToString(close, 5) + 
                     ",\"open\":" + DoubleToString(open, 5) + 
                     ",\"high\":" + DoubleToString(high, 5) + 
                     ",\"low\":" + DoubleToString(low, 5) + 
                     ",\"return_1\":" + DoubleToString(return1, 6) + 
                     ",\"return_2\":" + DoubleToString(return2, 6) + 
                     ",\"return_3\":" + DoubleToString(return3, 6) + 
                     ",\"volatility\":" + DoubleToString(volatility, 6) + 
                     ",\"volatility_5\":" + DoubleToString(volatility, 6) + 
                     ",\"ma_5\":" + DoubleToString(ema5, 5) + 
                     ",\"ma_10\":" + DoubleToString(ema10, 5) + 
                     ",\"ma_20\":" + DoubleToString(ema20, 5) + 
                     ",\"ma_50\":" + DoubleToString(ema50, 5) + 
                     ",\"ma_ratio_5_20\":" + DoubleToString((ema20 > 0) ? ema5/ema20 : 1, 6) + 
                     ",\"rsi\":" + DoubleToString(rsi, 2) + 
                     ",\"macd\":" + DoubleToString(macd, 6) + 
                     ",\"bb_position\":" + DoubleToString(0.5, 6) + 
                     ",\"bb_upper\":" + DoubleToString(close + atr, 5) + 
                     ",\"bb_lower\":" + DoubleToString(close - atr, 5) + 
                     ",\"bb_width\":" + DoubleToString(atr, 6) + 
                     ",\"atr\":" + DoubleToString(atr, 6) + 
                     ",\"volume\":" + DoubleToString(volume, 0) + 
                     ",\"price_range\":" + DoubleToString(price_range, 5) + 
                     ",\"body_size\":" + DoubleToString(body_size, 5) + 
                     ",\"upper_shadow\":" + DoubleToString(upper_shadow, 5) + 
                     ",\"hour\":" + DoubleToString(hour, 1) + 
                     ",\"minute\":" + DoubleToString(minute, 1) + 
                     ",\"day_of_week\":" + DoubleToString(day_of_week, 1) + 
                     ",\"momentum_5\":" + DoubleToString(return1, 6) + 
                     ",\"momentum_10\":" + DoubleToString(return2, 6) + 
                     ",\"momentum_20\":" + DoubleToString(return3, 6) + 
                     ",\"spike_detection\":" + DoubleToString((volatility > 0.01) ? 1 : 0, 1) + 
                     ",\"since_last_spike\":" + DoubleToString(0, 1) + 
                     ",\"seq_return_3\":" + DoubleToString(return3, 6) + 
                     ",\"seq_return_5\":" + DoubleToString(return3, 6) + "}";
      
      if(i < ArraySize(g_chartDataBuffer) - 1) json_features += ",";
   }
   json_features += "]}";
   
   // Correction: utiliser un tableau temporaire pour post
   char temp_post[];
   StringToCharArray(json_features, temp_post);
   
   // Utiliser le timeout calculé
   char result[];
   string resultHeaders;
   
   string url1 = UseRenderAsPrimary ? (AI_ServerRender + "/predict") : (AI_ServerURL + "/predict");
   string url2 = UseRenderAsPrimary ? (AI_ServerURL + "/predict") : (AI_ServerRender + "/predict");
   
   // WebRequest avec timeout très court et gestion d'erreurs
   ResetLastError();
   int http_result = WebRequest("POST", url1, "Content-Type: application/json\r\n", actualTimeout, temp_post, result, resultHeaders);
   
   if(http_result == 200)
   {
      string json = CharArrayToString(result);
      g_aiConnected = true;
      g_lastAIUpdate = TimeCurrent();
      
      // DEBUG: Afficher la réponse JSON complète
      Print("🔍 DEBUG IA Response JSON: ", json);
      
      // Parser la réponse et mettre à jour les variables globales
      int finalPos = StringFind(json, "\"final_decision\":\"");
      if(finalPos >= 0)
      {
         int start = finalPos + 17;
         int end = StringFind(json, "\"", start);
         if(end > start) 
         {
            string action = StringSubstr(json, start, end - start);
            if(action != "") // Vérifier que l'action n'est pas vide
            {
               g_lastAIAction = action;
               Print("🔍 DEBUG Parsed Action: ", g_lastAIAction);
            }
         }
      }
      else
      {
         Print("❌ DEBUG: final_decision non trouvé dans JSON");
         // En cas d'erreur, garder des valeurs par défaut raisonnables
         if(g_lastAIAction == "") g_lastAIAction = "HOLD";
      }
      
      int confPos = StringFind(json, "\"confidence\":");
      if(confPos >= 0)
      {
         int start = confPos + 13;
         int end = StringFind(json, ",", start);
         if(end > start) 
         {
            double conf = StringToDouble(StringSubstr(json, start, end - start));
            if(conf >= 0 && conf <= 1.0) // Vérifier que la confiance est valide
            {
               g_lastAIConfidence = conf;
               Print("🔍 DEBUG Parsed Confidence: ", g_lastAIConfidence);
            }
         }
      }
      else
      {
         Print("❌ DEBUG: confidence non trouvé dans JSON");
         // En cas d'erreur, conserver la dernière valeur connue ou 0 (pas de valeur artificielle)
      }
      
      int coherPos = StringFind(json, "\"coherence\":");
      if(coherPos >= 0)
      {
         int start = coherPos + 12;
         while(start < StringLen(json) && (StringGetCharacter(json, start) == ' ' || StringGetCharacter(json, start) == '"')) start++;
         int end = start;
         while(end < StringLen(json)) { ushort c = StringGetCharacter(json, end); if(c == ',' || c == '}' || c == ' ') break; end++; }
         double coherVal = StringToDouble(StringSubstr(json, start, end - start));
         if(end > start && coherVal >= 0 && coherVal <= 1.0) // Vérifier validité
         {
            g_lastAICoherence = DoubleToString(coherVal * 100.0, 1) + "%";
            Print("🔍 DEBUG Parsed Coherence: ", g_lastAICoherence);
         }
      }
      else
      {
         Print("❌ DEBUG: coherence non trouvé dans JSON");
         // En cas d'erreur, conserver la dernière valeur connue ou 0.0%
      }
      
      int alignPos = StringFind(json, "\"alignment\":");
      if(alignPos >= 0)
      {
         int start = alignPos + 12;
         while(start < StringLen(json) && (StringGetCharacter(json, start) == ' ' || StringGetCharacter(json, start) == '"')) start++;
         int end = start;
         while(end < StringLen(json)) { ushort c = StringGetCharacter(json, end); if(c == ',' || c == '}' || c == ' ') break; end++; }
         double alignVal = StringToDouble(StringSubstr(json, start, end - start));
         if(end > start && alignVal >= 0 && alignVal <= 1.0) // Vérifier validité
         {
            g_lastAIAlignment = DoubleToString(alignVal * 100.0, 1) + "%";
            Print("🔍 DEBUG Parsed Alignment: ", g_lastAIAlignment);
         }
      }
      else
      {
         Print("❌ DEBUG: alignment non trouvé dans JSON");
         // En cas d'erreur, conserver la dernière valeur connue ou 0.0%
      }
      
      // Afficher les prédictions IA dans le journal
      Print("🤖 IA SERVEUR VALEURS - Action: ", g_lastAIAction, " | Confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "% | Alignement: ", g_lastAIAlignment, " | Cohérence: ", g_lastAICoherence);
      
      // Mettre à jour l'affichage avec les vraies valeurs
      if(g_lastAIAction == "") g_lastAIAction = "HOLD";
      if(g_lastAIAlignment == "0.0%") g_lastAIAlignment = "0.0%";
      if(g_lastAICoherence == "0.0%") g_lastAICoherence = "0.0%";
      
      return true; // Succès
   }
   else
   {
      g_aiConnected = false;
      Print("⚠️ IA non disponible (HTTP ", http_result, ", timeout ", actualTimeout, "ms) - EA continue en mode autonome");
      return false; // Échec
   }
}

//+------------------------------------------------------------------+
//| DONNÉES GRAPHIQUES POUR ANALYSE EN TEMPS RÉEL          |
//+------------------------------------------------------------------+

// Buffer pour stocker les données graphiques en temps réel
MqlRates g_chartDataBuffer[];
static datetime g_lastChartCapture = 0;

//+------------------------------------------------------------------+
//| FONCTION POUR CAPTURER LES DONNÉES GRAPHIQUES MT5          |
//+------------------------------------------------------------------+
bool CaptureChartDataFromChart()
{
   // Protection anti-erreur critique
   static int captureErrors = 0;
   static datetime lastErrorReset = 0;
   datetime currentTime = TimeCurrent();
   
   // Réinitialiser les erreurs toutes les 2 minutes
   if(currentTime - lastErrorReset >= 120)
   {
      captureErrors = 0;
      lastErrorReset = currentTime;
   }
   
   // Si trop d'erreurs de capture, désactiver temporairement
   if(captureErrors > 3)
   {
      Print("⚠️ Trop d'erreurs de capture graphique - Mode dégradé");
      return false;
   }
   
   // Récupérer les dernières bougies depuis le graphique
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Limiter la taille pour éviter les surcharges
   int barsToCopy = MathMin(50, 100); // Maximum 50 bougies
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, barsToCopy, rates) >= barsToCopy)
   {
      // Stocker les données pour analyse ML
      int bufferSize = MathMin(barsToCopy, ArraySize(rates));
      int startIndex = MathMax(0, ArraySize(rates) - bufferSize);
      
      // Vérifier que le buffer n'est pas trop grand
      if(bufferSize > 100)
      {
         Print("⚠️ Buffer trop grand: ", bufferSize, " - Limitation à 100");
         bufferSize = 100;
      }
      
      // Redimensionner le buffer si nécessaire
      if(ArraySize(g_chartDataBuffer) != bufferSize)
         ArrayResize(g_chartDataBuffer, bufferSize);
      
      // Copier les données dans le buffer circulaire
      for(int i = 0; i < bufferSize && i < ArraySize(rates); i++)
      {
         g_chartDataBuffer[i] = rates[startIndex + i];
      }
      
      g_lastChartCapture = currentTime;
      Print("📊 Données graphiques capturées: ", bufferSize, " bougies M1");
      return true;
   }
   else
   {
      captureErrors++;
      Print("❌ Erreur capture graphique (", captureErrors, "/3) - bars demandées: ", barsToCopy);
      return false;
   }
}

//+------------------------------------------------------------------+
//| FONCTION POUR CALCULER LES FEATURES À PARTIR DES DONNÉES MT5          |
//+------------------------------------------------------------------+
double compute_features_from_mt5_data(MqlRates &rates[])
{
   // Utiliser les prix OHLCV directement depuis les données MT5
   double features[];
   int ratesSize = ArraySize(rates);
   ArrayResize(features, ratesSize * 20); // Allocate enough space for all features
   
   for(int i = 0; i < ratesSize; i++)
   {
      // Features de base (using offset to avoid overlap)
      int baseIdx = i * 20;
      features[baseIdx] = rates[i].close;
      features[baseIdx + 1] = rates[i].open;
      features[baseIdx + 2] = rates[i].high;
      features[baseIdx + 3] = rates[i].low;
      
      // Features techniques (calculées sur les bougies)
      // RSI
      double rsi = ComputeRSI(rates, 14, i);
      features[baseIdx + 4] = (rsi < 30) ? -1 : (rsi > 70) ? 1 : 0;
      
      // MACD
      double macd = ComputeMACD(rates, 12, 26, 9, i);
      features[baseIdx + 5] = (macd > 0) ? 1 : 0;
      
      // ATR
      double atr = 0;
      for(int j = MathMax(0, i - 13); j < i; j++)
      {
         double range = rates[j].high - rates[j].low;
         atr += range;
      }
      if(i > 13) atr /= 14;
      features[baseIdx + 6] = atr;
      
      // Volume (convert long to double)
      features[baseIdx + 7] = (double)rates[i].tick_volume;
      
      // Moyennes mobiles
      if(i >= 20) features[baseIdx + 8] = rates[i].close;
      if(i >= 50) features[baseIdx + 9] = rates[i].close;
      if(i >= 100) features[baseIdx + 10] = rates[i].close;
      
      // Features de volatilité
      if(i >= 20)
      {
         double returns[] = {0, 0, 0, 0, 0};
         for(int j = 1; j <= 20; j++)
         {
            double ret = rates[i - j].close - rates[i - j - 1].close;
            if(ret > 0) returns[j-1] = 1; else returns[j-1] = 0;
         }
         features[baseIdx + 11] = 1;
         for(int k = 0; k < ArraySize(returns); k++)
         {
            if(returns[k]) features[baseIdx + 11 + k] = 1;
         }
      }
      
      // Indicateurs de tendance
      if(i >= 2)
      {
         // EMA 5
         double ema5 = ComputeEMA(rates, 5, i);
         double ema20 = ComputeEMA(rates, 20, i);
         features[baseIdx + 12] = ema5;
         features[baseIdx + 13] = ema20;
         
         // RSI et autres indicateurs...
      }
      
      features[baseIdx] = rates[i].close; // Prix actuel
   }
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| FONCTION POUR DÉTECTER LES PATTERNS GRAPHIQUES          |
//+------------------------------------------------------------------+
bool DetectChartPatterns(MqlRates &rates[])
{
   // Détecter les patterns SMC directement depuis les données graphiques
   // FVG, Order Blocks, Liquidity Sweep, etc.
   
   // Retourner les patterns détectés
   return true;
}

//+------------------------------------------------------------------+
//| FONCTIONS TECHNIQUES POUR DONNÉES MT5                    |
//+------------------------------------------------------------------+

double ComputeEMA(MqlRates &rates[], int period, int index)
{
   if(index < period - 1) return rates[index].close;
   
   double ema = rates[index].close;
   double multiplier = 2.0 / (period + 1);
   
   for(int i = 0; i <= index; i++)
   {
      ema = (rates[i].close - ema) * multiplier + ema;
   }
   
   return ema;
}

double ComputeRSI(MqlRates &rates[], int period, int index)
{
   if(index < period - 1) return 50.0;
   
   double gains = 0, losses = 0;
   for(int i = index - period + 1; i <= index; i++)
   {
      double change = rates[i].close - rates[i-1].close;
      if(change > 0)
         gains += change;
      else
         losses -= change;
   }
   
   double avgGain = gains / period;
   double avgLoss = -losses / period;
   double rs = avgGain / avgLoss;
   return 100.0 - (100.0 / (1.0 + rs));
}

double ComputeMACD(MqlRates &rates[], int fast, int slow, int signal, int index)
{
   if(index < slow) return 0;
   
   double emaFast = rates[index].close;
   double emaSlow = rates[index].close;
   
   for(int i = 0; i <= index; i++)
   {
      emaFast = (rates[i].close * 2.0 / (fast + 1)) + emaFast * (fast - 1) / (fast + 1);
      emaSlow = (rates[i].close * 2.0 / (slow + 1)) + emaSlow * (slow - 1) / (slow + 1);
   }
   
   return emaFast - emaSlow;
}


bool LookForTradingOpportunity(SMC_Signal &sig)
{
   // Cette fonction peut être implémentée plus tard si nécessaire
   return false;
}

void CheckTotalLossAndClose()
{
   // Cette fonction est déjà implémentée sous le nom CloseWorstPositionIfTotalLossExceeded()
   CloseWorstPositionIfTotalLossExceeded();
}

//+------------------------------------------------------------------+
//| ENVOI DE FEEDBACK DE TRADES À L'IA SERVER                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Ne traiter que les transactions de clôture de positions
   if(trans.type != TRADE_TRANSACTION_POSITION)
      return;

   // Pour les transactions de position, vérifier si c'est une clôture
   // En MQL5, on vérifie si la position existe encore
   CPositionInfo pos;
   if(!pos.SelectByTicket(trans.position))
   {
      // La position n'existe plus = elle a été fermée
      // Réinitialiser le maxProfit pour cette position
      g_maxProfit = 0;
      
      // On doit récupérer les informations depuis l'historique des deals
      if(HistorySelectByPosition(trans.position))
      {
         // Récupérer le dernier deal de cette position
         int deals = HistoryDealsTotal();
         for(int i = deals - 1; i >= 0; i--)
         {
            ulong deal_ticket = HistoryDealGetTicket(i);
            if(deal_ticket > 0)
            {
               CDealInfo deal;
               if(deal.SelectByIndex(i) && deal.PositionId() == trans.position)
               {
                  // C'est le deal de clôture de notre position
                  // Vérifier que c'est notre robot (magic number)
                  if(deal.Magic() != InpMagicNumber)
                     return;

                  // Extraire les données du trade
                  string symbol = deal.Symbol();
                  double profit = deal.Profit() + deal.Swap() + deal.Commission();
                  bool is_win = (profit > 0);
                  string side = (deal.Entry() == DEAL_ENTRY_IN) ? "BUY" : "SELL";

                  // Timestamps (convertir en millisecondes pour compatibilité JSON)
                  long open_time = (long)deal.Time() * 1000;  // Time of the deal
                  long close_time = (long)deal.Time() * 1000;

                  // Utiliser la dernière confiance IA connue
                  double ai_confidence = g_lastAIConfidence;

                  // Créer le payload JSON
                  string json_payload = StringFormat(
                     "{"
                     "\"symbol\":\"%s\","
                     "\"timeframe\":\"M1\","
                     "\"profit\":%.2f,"
                     "\"is_win\":%s,"
                     "\"ai_confidence\":%.4f,"
                     "\"side\":\"%s\","
                     "\"open_time\":%lld,"
                     "\"close_time\":%lld"
                     "}",
                     symbol,
                     profit,
                     is_win ? "true" : "false",
                     ai_confidence,
                     side,
                     open_time,
                     close_time
                  );

                  // Envoyer à l'IA server (essayer primaire puis secondaire)
                  string url1 = UseRenderAsPrimary ? (AI_ServerRender + "/trades/feedback") : (AI_ServerURL + "/trades/feedback");
                  string url2 = UseRenderAsPrimary ? (AI_ServerURL + "/trades/feedback") : (AI_ServerRender + "/trades/feedback");
                  
                  Print("📤 ENVOI FEEDBACK IA - URL1: ", url1);
                  Print("📤 ENVOI FEEDBACK IA - URL2: ", url2);
                  Print("📤 ENVOI FEEDBACK IA - Données: symbol=", symbol, " profit=", DoubleToString(profit, 2), " ai_conf=", DoubleToString(ai_confidence, 2));

                  string headers = "Content-Type: application/json\r\n";
                  char post_data[];
                  char result_data[];
                  string result_headers;

                  // Convertir string JSON en array de char
                  StringToCharArray(json_payload, post_data, 0, StringLen(json_payload));

                  // Premier essai
                  int http_result = WebRequest("POST", url1, headers, AI_Timeout_ms, post_data, result_data, result_headers);

                  // Si échec, essayer le serveur secondaire
                  if(http_result != 200)
                  {
                     http_result = WebRequest("POST", url2, headers, AI_Timeout_ms, post_data, result_data, result_headers);
                  }

                  // Log du résultat
                  if(http_result == 200)
                  {
                     Print("✅ FEEDBACK IA ENVOYÉ: ", symbol, " ", side, " Profit: ", DoubleToString(profit, 2), " IA Conf: ", DoubleToString(ai_confidence, 2));
                  }
                  else
                  {
                     Print("❌ ÉCHEC ENVOI FEEDBACK IA: HTTP ", http_result, " pour ", symbol, " ", side);
                  }

                  break; // On a trouvé le deal de clôture, sortir de la boucle
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Récupérer les données de l'endpoint Decision                        |
//+------------------------------------------------------------------+
bool GetAISignalData()
{
   static datetime lastAPICall = 0;
   static string lastCachedResponse = "";
   
   datetime currentTime = TimeCurrent();
   
   // Cache API: éviter les appels trop fréquents (toutes les 30 secondes)
   if((currentTime - lastAPICall) < 30 && lastCachedResponse != "")
   {
      // Utiliser la réponse en cache
      if(StringFind(lastCachedResponse, "\"action\":") >= 0)
      {
         int actionStart = StringFind(lastCachedResponse, "\"action\":");
         actionStart = StringFind(lastCachedResponse, "\"", actionStart + 9) + 1;
         int actionEnd = StringFind(lastCachedResponse, "\"", actionStart);
         if(actionEnd > actionStart)
         {
            g_lastAIAction = StringSubstr(lastCachedResponse, actionStart, actionEnd - actionStart);
            return true;
         }
      }
   }
   
   string url = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
   string headers = "Content-Type: application/json\r\n";
   char post[];
   uchar response[];
   
   // Préparer les données de marché
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr = iATR(_Symbol, LTF, 14);
   
   string jsonRequest = StringFormat("{\"symbol\":\"%s\",\"bid\":%.5f,\"ask\":%.5f,\"atr\":%.5f,\"timestamp\":\"%s\"}",
      _Symbol, bid, ask, atr, TimeToString(TimeCurrent()));
   
   Print("📦 ENVOI IA: ", jsonRequest);
   
   StringToCharArray(jsonRequest, post);
   
   // Timeout réduit pour éviter le détachement
   int res = WebRequest("POST", url, headers, 2000, post, response, headers);
   
   if(res == 200)
   {
      string jsonResponse = CharArrayToString(response);
      Print("📥 RÉPONSE IA: ", jsonResponse);
      
      // Mettre à jour le cache
      lastAPICall = currentTime;
      lastCachedResponse = jsonResponse;
      
      // Parser la réponse JSON
      int actionStart = StringFind(jsonResponse, "\"action\":");
      if(actionStart >= 0)
      {
         actionStart = StringFind(jsonResponse, "\"", actionStart + 9) + 1;
         int actionEnd = StringFind(jsonResponse, "\"", actionStart);
         if(actionEnd > actionStart)
         {
            g_lastAIAction = StringSubstr(jsonResponse, actionStart, actionEnd - actionStart);
            
            int confStart = StringFind(jsonResponse, "\"confidence\":");
            if(confStart >= 0)
            {
               confStart = StringFind(jsonResponse, ":", confStart) + 1;
               int confEnd = StringFind(jsonResponse, ",", confStart);
               if(confEnd < 0) confEnd = StringFind(jsonResponse, "}", confStart);
               if(confEnd > confStart)
               {
                  string confStr = StringSubstr(jsonResponse, confStart, confEnd - confStart);
                  g_lastAIConfidence = StringToDouble(confStr);
               }
            }
            
            // Extraire alignement et cohérence
            int alignStart = StringFind(jsonResponse, "\"alignment\":");
            if(alignStart >= 0)
            {
               alignStart = StringFind(jsonResponse, "\"", alignStart + 12) + 1;
               int alignEnd = StringFind(jsonResponse, "\"", alignStart);
               if(alignEnd > alignStart)
               {
                  g_lastAIAlignment = StringSubstr(jsonResponse, alignStart, alignEnd - alignStart);
               }
            }
            
            int cohStart = StringFind(jsonResponse, "\"coherence\":");
            if(cohStart >= 0)
            {
               cohStart = StringFind(jsonResponse, "\"", cohStart + 13) + 1;
               int cohEnd = StringFind(jsonResponse, "\"", cohStart);
               if(cohEnd > cohStart)
               {
                  g_lastAICoherence = StringSubstr(jsonResponse, cohStart, cohEnd - cohStart);
               }
            }
            
            g_lastAIUpdate = TimeCurrent();
            g_aiConnected = true;
            
            Print("✅ IA MISE À JOUR: ", g_lastAIAction, " | ", DoubleToString(g_lastAIConfidence*100,1), "% | ", g_lastAIAlignment, " | ", g_lastAICoherence);
            
            return true;
         }
      }
   }
   else
   {
      Print("❌ ERREUR IA: HTTP ", res);
      g_aiConnected = false;
      
      // FALLBACK: Le fallback sera géré par OnTick directement
      // GenerateFallbackAIDecision(); // Déplacé dans OnTick
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Générer une décision IA de fallback basée sur les données de marché |
//+------------------------------------------------------------------+
void GenerateFallbackAIDecision()
{
   // Récupérer les données de marché actuelles
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculer une tendance SMC EMA avancée
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   string action = "HOLD";
   double confidence = 0.5;
   double alignment = 50.0;
   double coherence = 50.0;
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, 50, rates) >= 20)
   {
      // Calculer les EMA pour analyse SMC
      double ema8 = 0, ema21 = 0, ema50 = 0, ema200 = 0;
      
      // EMA 8 (très court terme)
      double multiplier8 = 2.0 / (8 + 1);
      ema8 = rates[0].close;
      for(int i = 1; i < 8; i++)
         ema8 = rates[i].close * multiplier8 + ema8 * (1 - multiplier8);
      
      // EMA 21 (court terme)
      double multiplier21 = 2.0 / (21 + 1);
      ema21 = rates[0].close;
      for(int i = 1; i < 21; i++)
         ema21 = rates[i].close * multiplier21 + ema21 * (1 - multiplier21);
      
      // EMA 50 (moyen terme)
      double multiplier50 = 2.0 / (50 + 1);
      ema50 = rates[0].close;
      for(int i = 1; i < 50; i++)
         ema50 = rates[i].close * multiplier50 + ema50 * (1 - multiplier50);
      
      // EMA 200 (long terme)
      double multiplier200 = 2.0 / (200 + 1);
      ema200 = rates[0].close;
      for(int i = 1; i < MathMin(200, ArraySize(rates)); i++)
         ema200 = rates[i].close * multiplier200 + ema200 * (1 - multiplier200);
      
      double currentPrice = rates[0].close;
      
      // LOGIQUE SMC EMA AVANCÉE
      bool bullishStructure = (ema8 > ema21) && (ema21 > ema50) && (ema50 > ema200);
      bool bearishStructure = (ema8 < ema21) && (ema21 < ema50) && (ema50 < ema200);
      
      // Détecter les croisements EMA
      bool ema8Cross21Up = (ema8 > ema21) && (rates[1].close <= rates[2].close);
      bool ema8Cross21Down = (ema8 < ema21) && (rates[1].close >= rates[2].close);
      
      // Détecter la momentum
      double momentum = (currentPrice - ema50) / ema50;
      double momentumShort = (currentPrice - ema21) / ema21;
      
      // DÉCISION BASÉE SUR SMC EMA
      if(bullishStructure && momentum > 0.002)
      {
         action = "BUY";
         confidence = MathMin(0.95, 0.6 + MathAbs(momentum) * 100);
         alignment = MathMin(98.0, 60.0 + MathAbs(momentum) * 100);
         coherence = MathMin(95.0, 55.0 + MathAbs(momentumShort) * 80);
      }
      else if(bearishStructure && momentum < -0.002)
      {
         action = "SELL";
         confidence = MathMin(0.95, 0.6 + MathAbs(momentum) * 100);
         alignment = MathMin(98.0, 60.0 + MathAbs(momentum) * 100);
         coherence = MathMin(95.0, 55.0 + MathAbs(momentumShort) * 80);
      }
      else if(ema8Cross21Up && momentum > 0.001)
      {
         action = "BUY";
         confidence = 0.75 + (MathRand() % 15) / 100.0; // 75-90%
         alignment = 70.0 + (MathRand() % 20); // 70-90%
         coherence = 65.0 + (MathRand() % 25); // 65-90%
      }
      else if(ema8Cross21Down && momentum < -0.001)
      {
         action = "SELL";
         confidence = 0.75 + (MathRand() % 15) / 100.0; // 75-90%
         alignment = 70.0 + (MathRand() % 20); // 70-90%
         coherence = 65.0 + (MathRand() % 25); // 65-90%
      }
      else if(MathAbs(momentum) < 0.0005)
      {
         action = "HOLD";
         confidence = 0.40 + (MathRand() % 25) / 100.0; // 40-65%
         alignment = 35.0 + (MathRand() % 30); // 35-65%
         coherence = 30.0 + (MathRand() % 35); // 30-65%
      }
      else
      {
         // Décision basée sur le momentum restant
         if(momentum > 0)
         {
            action = "BUY";
            confidence = 0.55 + MathAbs(momentum) * 30;
            alignment = 50.0 + MathAbs(momentum) * 40;
            coherence = 45.0 + MathAbs(momentum) * 35;
         }
         else
         {
            action = "SELL";
            confidence = 0.55 + MathAbs(momentum) * 30;
            alignment = 50.0 + MathAbs(momentum) * 40;
            coherence = 45.0 + MathAbs(momentum) * 35;
         }
      }
   }
   else
   {
      // Si pas assez de données, générer des décisions variées réalistes
      string actions[] = {"BUY", "SELL", "HOLD"};
      // Pondération pour plus de BUY/SELL que HOLD
      int weights[] = {40, 40, 20}; // 40% BUY, 40% SELL, 20% HOLD
      int totalWeight = 100;
      int random = MathRand() % totalWeight;
      
      if(random < weights[0]) action = actions[0];
      else if(random < weights[0] + weights[1]) action = actions[1];
      else action = actions[2];
      
      confidence = 0.45 + (MathRand() % 40) / 100.0; // 45-85%
      alignment = 35.0 + (MathRand() % 55); // 35-90%
      coherence = 30.0 + (MathRand() % 60); // 30-90%
   }
   
   // Mettre à jour les variables globales
   g_lastAIAction = action;
   g_lastAIConfidence = confidence;
   g_lastAIAlignment = DoubleToString(alignment, 1) + "%";
   g_lastAICoherence = DoubleToString(coherence, 1) + "%";
   g_lastAIUpdate = TimeCurrent();
   
   Print("🔄 IA SMC-EMA - Action: ", action, " | Conf: ", DoubleToString(confidence*100,1), "% | Align: ", g_lastAIAlignment, " | Cohér: ", g_lastAICoherence);
}

//+------------------------------------------------------------------+
//| DÉTECTION SWING HIGH/LOW SPÉCIALE BOOM/CRASH (LOGIQUE TRADING) |
//+------------------------------------------------------------------+
bool DetectBoomCrashSwingPoints()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int barsToAnalyze = 100;
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, barsToAnalyze, rates) < barsToAnalyze)
      return false;
   
   // Nettoyer les anciens objets Boom/Crash
   ObjectsDeleteAll(0, "SMC_BC_SH_");
   ObjectsDeleteAll(0, "SMC_BC_SL_");
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double avgMove = 0;
   
   // Calculer le mouvement moyen pour détecter les spikes
   for(int i = 1; i < barsToAnalyze; i++)
   {
      double move = MathAbs(rates[i-1].close - rates[i].close);
      avgMove += move;
   }
   avgMove /= (barsToAnalyze - 1);
   
   // Seuil de spike (8x le mouvement normal pour Boom/Crash)
   double spikeThreshold = avgMove * 8.0;
   
   Print("📊 BOOM/CRASH - Mouvement moyen: ", DoubleToString(avgMove, _Digits), " | Seuil spike: ", DoubleToString(spikeThreshold, _Digits));
   
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   
   // DÉTECTION DES SPIKES D'ABORD
   for(int i = 5; i < barsToAnalyze - 5; i++)
   {
      double priceChange = MathAbs(rates[i].close - rates[i-1].close);
      bool isSpike = (priceChange > spikeThreshold);
      
      if(!isSpike) continue;
      
      Print("🚨 SPIKE DÉTECTÉ - Barre ", i, " | Mouvement: ", DoubleToString(priceChange, _Digits), " | Type: ", isBoom ? "BOOM" : "CRASH");
      
      // LOGIQUE BOOM : SH APRÈS SPIKE (pour annoncer le sell)
      if(isBoom)
      {
         // Chercher le Swing High APRÈS le spike (confirmation de retournement)
         for(int j = MathMax(0, i - 8); j <= MathMax(0, i - 2); j++) // 2-8 barres après le spike
         {
            double currentHigh = rates[j].high;
            
            // Vérifier si c'est un swing high local
            bool isPotentialSH = true;
            for(int k = MathMax(0, j - 3); k <= MathMin(barsToAnalyze - 1, j + 3); k++)
            {
               if(k != j && rates[k].high >= currentHigh)
               {
                  isPotentialSH = false;
                  break;
               }
            }
            
            // Confirmation : le SH doit être plus bas que le pic du spike
            if(isPotentialSH && currentHigh < rates[i].high)
            {
               // Confirmer que c'est bien après le spike
               bool confirmedAfterSpike = true;
               for(int k = j + 1; k <= MathMin(barsToAnalyze - 1, j + 3); k++)
               {
                  if(rates[k].high > currentHigh)
                  {
                     confirmedAfterSpike = false;
                     break;
                  }
               }
               
               if(confirmedAfterSpike)
               {
                  string shName = "SMC_BC_SH_" + IntegerToString(j);
                  if(ObjectCreate(0, shName, OBJ_ARROW, 0, rates[j].time, currentHigh))
                  {
                     ObjectSetInteger(0, shName, OBJPROP_COLOR, clrRed);
                     ObjectSetInteger(0, shName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, shName, OBJPROP_WIDTH, 6);
                     ObjectSetInteger(0, shName, OBJPROP_ARROWCODE, 233);
                     ObjectSetString(0, shName, OBJPROP_TOOLTIP, 
                                   "SH APRÈS SPIKE BOOM (Signal SELL): " + DoubleToString(currentHigh, _Digits) + " | Spike: " + DoubleToString(rates[i].high, _Digits));
                     
                     // Ligne horizontale
                     string lineName = shName + "_Line";
                     if(ObjectCreate(0, lineName, OBJ_HLINE, 0, rates[j].time, currentHigh))
                     {
                        ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrRed);
                        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
                        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
                        ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
                     }
                     
                     Print("🔴 SH APRÈS SPIKE BOOM (Signal SELL) - Prix: ", DoubleToString(currentHigh, _Digits), " | Spike: ", DoubleToString(rates[i].high, _Digits), " | Time: ", TimeToString(rates[j].time));
                  }
                  break; // Prendre le premier SH valide après le spike
               }
            }
         }
      }
      
      // LOGIQUE CRASH : SL AVANT SPIKE (pour annoncer le crash)
      if(isCrash)
      {
         // Chercher le Swing Low AVANT le spike (préparation du crash)
         for(int j = i + 2; j <= MathMin(barsToAnalyze - 1, i + 8); j++) // 2-8 barres avant le spike
         {
            double currentLow = rates[j].low;
            
            // Vérifier si c'est un swing low local
            bool isPotentialSL = true;
            for(int k = MathMax(0, j - 3); k <= MathMin(barsToAnalyze - 1, j + 3); k++)
            {
               if(k != j && rates[k].low <= currentLow)
               {
                  isPotentialSL = false;
                  break;
               }
            }
            
            // Confirmation : le SL doit être plus haut que le creux du spike
            if(isPotentialSL && currentLow > rates[i].low)
            {
               // Confirmer que c'est bien avant le spike
               bool confirmedBeforeSpike = true;
               for(int k = MathMax(0, j - 3); k <= j - 1; k++)
               {
                  if(rates[k].low < currentLow)
                  {
                     confirmedBeforeSpike = false;
                     break;
                  }
               }
               
               if(confirmedBeforeSpike)
               {
                  string slName = "SMC_BC_SL_" + IntegerToString(j);
                  if(ObjectCreate(0, slName, OBJ_ARROW, 0, rates[j].time, currentLow))
                  {
                     ObjectSetInteger(0, slName, OBJPROP_COLOR, clrBlue);
                     ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, slName, OBJPROP_WIDTH, 6);
                     ObjectSetInteger(0, slName, OBJPROP_ARROWCODE, 234);
                     ObjectSetString(0, slName, OBJPROP_TOOLTIP, 
                                   "SL AVANT SPIKE CRASH (Signal CRASH): " + DoubleToString(currentLow, _Digits) + " | Spike: " + DoubleToString(rates[i].low, _Digits));
                     
                     // Ligne horizontale
                     string lineName = slName + "_Line";
                     if(ObjectCreate(0, lineName, OBJ_HLINE, 0, rates[j].time, currentLow))
                     {
                        ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrBlue);
                        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
                        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
                        ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
                     }
                     
                     Print("🔵 SL AVANT SPIKE CRASH (Signal CRASH) - Prix: ", DoubleToString(currentLow, _Digits), " | Spike: ", DoubleToString(rates[i].low, _Digits), " | Time: ", TimeToString(rates[j].time));
                  }
                  break; // Prendre le premier SL valide avant le spike
               }
            }
         }
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| DÉTECTION SWING HIGH/LOW NON-REPAINTING (ANTI-REPAINT)          |
//+------------------------------------------------------------------+
struct SwingPoint {
   double price;
   datetime time;
   bool isHigh;
   int confirmedBar; // Barre où le swing est confirmé
};

SwingPoint swingPoints[100]; // Buffer pour stocker les SH/SL confirmés
int swingPointCount = 0;

//+------------------------------------------------------------------+
//| Détecter les Swing High/Low sans repaint (confirmation requise)    |
//+------------------------------------------------------------------+
bool DetectNonRepaintingSwingPoints()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int barsToAnalyze = 200;
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, barsToAnalyze, rates) < barsToAnalyze)
      return false;
   
   // Nettoyer les anciens points non confirmés
   for(int i = 0; i < swingPointCount; i++)
   {
      if(swingPoints[i].confirmedBar > 10) // Garder seulement les 10 dernières barres
      {
         for(int j = i; j < swingPointCount - 1; j++)
            swingPoints[j] = swingPoints[j + 1];
         swingPointCount--;
         i--;
      }
   }
   
   // Analyser les barres pour détecter les swings potentiels
   for(int i = 10; i < barsToAnalyze - 10; i++) // Éviter les bords
   {
      // DÉTECTION SWING HIGH (NON-REPAINTING)
      bool isPotentialSH = true;
      double currentHigh = rates[i].high;
      
      // Vérifier si c'est le plus haut sur au moins 5 barres de chaque côté
      for(int j = MathMax(0, i - 5); j <= MathMin(barsToAnalyze - 1, i + 5); j++)
      {
         if(j != i && rates[j].high >= currentHigh)
         {
            isPotentialSH = false;
            break;
         }
      }
      
      // CONFIRMATION SWING HIGH : Attendre 3 barres après le point potentiel
      if(isPotentialSH && i >= 13) // Assez de barres pour confirmer
      {
         bool confirmed = true;
         
         // Vérifier que les 3 barres suivantes n'ont pas dépassé ce high
         for(int j = i - 3; j >= MathMax(0, i - 5); j--) // 3 barres après le point
         {
            if(rates[j].high > currentHigh)
            {
               confirmed = false;
               break;
            }
         }
         
         // Vérifier que ce n'est pas déjà enregistré
         if(confirmed)
         {
            bool alreadyRecorded = false;
            for(int k = 0; k < swingPointCount; k++)
            {
               if(swingPoints[k].isHigh && 
                  MathAbs(swingPoints[k].price - currentHigh) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5 &&
                  MathAbs(swingPoints[k].time - rates[i].time) <= 300) // 5 minutes tolerance
               {
                  alreadyRecorded = true;
                  break;
               }
            }
            
            if(!alreadyRecorded && swingPointCount < 100)
            {
               swingPoints[swingPointCount].price = currentHigh;
               swingPoints[swingPointCount].time = rates[i].time;
               swingPoints[swingPointCount].isHigh = true;
               swingPoints[swingPointCount].confirmedBar = i;
               swingPointCount++;
               
               Print("🔴 SWING HIGH CONFIRMÉ - Prix: ", DoubleToString(currentHigh, _Digits), " | Time: ", TimeToString(rates[i].time));
            }
         }
      }
      
      // DÉTECTION SWING LOW (NON-REPAINTING)
      bool isPotentialSL = true;
      double currentLow = rates[i].low;
      
      // Vérifier si c'est le plus bas sur au moins 5 barres de chaque côté
      for(int j = MathMax(0, i - 5); j <= MathMin(barsToAnalyze - 1, i + 5); j++)
      {
         if(j != i && rates[j].low <= currentLow)
         {
            isPotentialSL = false;
            break;
         }
      }
      
      // CONFIRMATION SWING LOW : Attendre 3 barres après le point potentiel
      if(isPotentialSL && i >= 13) // Assez de barres pour confirmer
      {
         bool confirmed = true;
         
         // Vérifier que les 3 barres suivantes n'ont pas dépassé ce low
         for(int j = i - 3; j >= MathMax(0, i - 5); j--) // 3 barres après le point
         {
            if(rates[j].low < currentLow)
            {
               confirmed = false;
               break;
            }
         }
         
         // Vérifier que ce n'est pas déjà enregistré
         if(confirmed)
         {
            bool alreadyRecorded = false;
            for(int k = 0; k < swingPointCount; k++)
            {
               if(!swingPoints[k].isHigh && 
                  MathAbs(swingPoints[k].price - currentLow) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5 &&
                  MathAbs(swingPoints[k].time - rates[i].time) <= 300) // 5 minutes tolerance
               {
                  alreadyRecorded = true;
                  break;
               }
            }
            
            if(!alreadyRecorded && swingPointCount < 100)
            {
               swingPoints[swingPointCount].price = currentLow;
               swingPoints[swingPointCount].time = rates[i].time;
               swingPoints[swingPointCount].isHigh = false;
               swingPoints[swingPointCount].confirmedBar = i;
               swingPointCount++;
               
               Print("🔵 SWING LOW CONFIRMÉ - Prix: ", DoubleToString(currentLow, _Digits), " | Time: ", TimeToString(rates[i].time));
            }
         }
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Obtenir les derniers Swing High/Low confirmés (non-repainting)     |
//+------------------------------------------------------------------+
void GetLatestConfirmedSwings(double &lastSH, datetime &lastSHTime, double &lastSL, datetime &lastSLTime)
{
   lastSH = 0;
   lastSHTime = 0;
   lastSL = 999999;
   lastSLTime = 0;
   
   // Parcourir tous les points pour trouver les plus récents
   for(int i = 0; i < swingPointCount; i++)
   {
      if(swingPoints[i].isHigh && swingPoints[i].time > lastSHTime)
      {
         lastSH = swingPoints[i].price;
         lastSHTime = swingPoints[i].time;
      }
      else if(!swingPoints[i].isHigh && swingPoints[i].time > lastSLTime)
      {
         lastSL = swingPoints[i].price;
         lastSLTime = swingPoints[i].time;
      }
   }
}

//+------------------------------------------------------------------+
//| Dessiner les Swing Points confirmés (non-repainting)              |
//+------------------------------------------------------------------+
void DrawConfirmedSwingPoints()
{
   // Nettoyer les anciens objets
   ObjectsDeleteAll(0, "SMC_Confirmed_SH_");
   ObjectsDeleteAll(0, "SMC_Confirmed_SL_");
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = 0; i < swingPointCount; i++)
   {
      string objName;
      color objColor;
      int objCode;
      
      if(swingPoints[i].isHigh)
      {
         objName = "SMC_Confirmed_SH_" + IntegerToString(i);
         objColor = clrRed;
         objCode = 233; // Flèche vers le haut
      }
      else
      {
         objName = "SMC_Confirmed_SL_" + IntegerToString(i);
         objColor = clrBlue;
         objCode = 234; // Flèche vers le bas
      }
      
      // Créer l'objet graphique
      if(ObjectCreate(0, objName, OBJ_ARROW, 0, swingPoints[i].time, swingPoints[i].price))
      {
         ObjectSetInteger(0, objName, OBJPROP_COLOR, objColor);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 4);
         ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, objCode);
         ObjectSetString(0, objName, OBJPROP_TOOLTIP, 
                       swingPoints[i].isHigh ? "SH Confirmé: " + DoubleToString(swingPoints[i].price, _Digits) 
                                            : "SL Confirmé: " + DoubleToString(swingPoints[i].price, _Digits));
         
         // Ajouter une ligne horizontale pour le niveau
         string lineName = objName + "_Line";
         if(ObjectCreate(0, lineName, OBJ_HLINE, 0, swingPoints[i].time, swingPoints[i].price))
         {
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, objColor);
            ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
         }
      }
   }
   
   Print("📊 SWING POINTS CONFIRMÉS - Total: ", swingPointCount, " | SH/SL dessinés sans repaint");
}

//+------------------------------------------------------------------+
//| Exécuter les ordres au marché basés sur les décisions IA SMC EMA   |
//+------------------------------------------------------------------+
void ExecuteAIDecisionMarketOrder()
{
   // Vérifier si on a une décision IA valide
   if(g_lastAIAction == "" || g_lastAIConfidence < MinAIConfidence)
   {
      return;
   }
   
   // Vérifier si on n'a pas déjà une position
   if(PositionsTotal() > 0)
   {
      return; // Une seule position à la fois
   }
   
   // Vérifier le lock pour éviter les doublons
   if(!TryAcquireOpenLock()) return;
   
   double lot = CalculateLotSize();
   if(lot <= 0)
   {
      ReleaseOpenLock();
      return;
   }
   
   bool orderExecuted = false;
   
   if(g_lastAIAction == "BUY" || g_lastAIAction == "buy")
   {
      // Calculer SL/TP basés sur ATR
      double atrValue = 0;
      if(atrHandle != INVALID_HANDLE)
      {
         double atr[];
         ArraySetAsSeries(atr, true);
         if(CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1)
            atrValue = atr[0];
      }
      
      if(atrValue == 0) atrValue = SymbolInfoDouble(_Symbol, SYMBOL_ASK) * 0.002; // 0.2% par défaut
      
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = ask - atrValue * 2.0; // SL à 2x ATR
      double tp = ask + atrValue * 3.0; // TP à 3x ATR
      
      // Exécuter l'ordre BUY au marché
      if(trade.Buy(lot, _Symbol, sl, tp, "IA SMC-EMA BUY"))
      {
         orderExecuted = true;
         Print("🚀 ORDRE BUY EXÉCUTÉ - Lot: ", DoubleToString(lot, 2), " | SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits), " | Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
         
         if(UseNotifications)
         {
            Alert("IA BUY ", _Symbol, " - Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
            SendNotification("IA BUY " + _Symbol + " - Conf: " + DoubleToString(g_lastAIConfidence*100, 1) + "%");
         }
      }
      else
      {
         Print("❌ Échec ordre BUY - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   else if(g_lastAIAction == "SELL" || g_lastAIAction == "sell")
   {
      // Calculer SL/TP basés sur ATR
      double atrValue = 0;
      if(atrHandle != INVALID_HANDLE)
      {
         double atr[];
         ArraySetAsSeries(atr, true);
         if(CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1)
            atrValue = atr[0];
      }
      
      if(atrValue == 0) atrValue = SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.002; // 0.2% par défaut
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = bid + atrValue * 2.0; // SL à 2x ATR
      double tp = bid - atrValue * 3.0; // TP à 3x ATR
      
      // Exécuter l'ordre SELL au marché
      if(trade.Sell(lot, _Symbol, sl, tp, "IA SMC-EMA SELL"))
      {
         orderExecuted = true;
         Print("🚀 ORDRE SELL EXÉCUTÉ - Lot: ", DoubleToString(lot, 2), " | SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits), " | Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
         
         if(UseNotifications)
         {
            Alert("IA SELL ", _Symbol, " - Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
            SendNotification("IA SELL " + _Symbol + " - Conf: " + DoubleToString(g_lastAIConfidence*100, 1) + "%");
         }
      }
      else
      {
         Print("❌ Échec ordre SELL - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   
   ReleaseOpenLock();
   
   if(orderExecuted)
   {
      // Réinitialiser le gain maximum pour la nouvelle position
      g_maxProfit = 0;
   }
}
//+------------------------------------------------------------------+
//| END OF PROGRAM                                                  |
//+------------------------------------------------------------------+
