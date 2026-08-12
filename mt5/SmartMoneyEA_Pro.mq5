//+------------------------------------------------------------------+
//|                    SmartMoneyEA_Pro.mq5                          |
//|          Expert Advisor - Smart Money Concepts (SMC)             |
//|  Stratégie: Multi-TF (4H→1H→15min) + SMC + Indicateurs          |
//|  Marchés: Forex, Métaux (XAU/XAG), Volatilité (Boom/Crash)      |
//|  Auteur: Généré pour Sidoine YEBADOKPO                           |
//|  Version: 1.0.0                                                  |
//+------------------------------------------------------------------+
#property copyright   "SmartMoneyEA Pro - SMC Strategy"
#property version     "1.00"
#property description "EA basée sur SMC: OB, FVG, S&D, BOS, Liquidity"
#property description "Analyse Multi-TF: 4H (Biais) → 1H (Setup) → 15min (Entrée)"

//--- Includes
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Indicators\Indicators.mqh>

//+------------------------------------------------------------------+
//|              PARAMÈTRES D'ENTRÉE (Inputs)                        |
//+------------------------------------------------------------------+

//--- ═══════════════════ GESTION DES RISQUES ═══════════════════════
input group "══════ GESTION DU RISQUE ══════"
input double   InpRiskPercent      = 1.0;       // Risque par trade (%)
input double   InpMaxLotSize       = 5.0;       // Lot maximum
input double   InpMinLotSize       = 0.01;      // Lot minimum
input int      InpMaxOpenTrades    = 3;         // Trades simultanés max
input double   InpDailyLossLimit   = 3.0;       // Perte journalière max (%)
input bool     InpUseTrailingStop  = true;      // Utiliser Trailing Stop
input double   InpTrailingStep     = 15.0;      // Pas du Trailing (points)

//--- ═══════════════════ TIMEFRAMES ═══════════════════════════════
input group "══════ MULTI-TIMEFRAME ══════"
input ENUM_TIMEFRAMES InpTF_Bias   = PERIOD_H4;  // TF Biais (4H)
input ENUM_TIMEFRAMES InpTF_Setup  = PERIOD_H1;  // TF Setup (1H)
input ENUM_TIMEFRAMES InpTF_Entry  = PERIOD_M15; // TF Entrée (15min)

//--- ═══════════════════ SMC - ORDER BLOCKS ═══════════════════════
input group "══════ ORDER BLOCKS (SMC) ══════"
input bool     InpUseOrderBlocks   = true;      // Activer Order Blocks
input int      InpOB_Lookback      = 20;        // Bougies de lookback OB
input int      InpOB_MinSize       = 10;        // Taille min OB (points)
input color    InpOB_BullColor     = clrDodgerBlue;  // Couleur OB Haussier
input color    InpOB_BearColor     = clrOrangeRed;   // Couleur OB Baissier
input int      InpOB_Transparency  = 80;        // Transparence OB (0-255)

//--- ═══════════════════ SMC - FAIR VALUE GAP ════════════════════
input group "══════ FAIR VALUE GAP (FVG) ══════"
input bool     InpUseFVG           = true;      // Activer Fair Value Gaps
input int      InpFVG_Lookback     = 30;        // Bougies lookback FVG
input int      InpFVG_MinSize      = 5;         // Taille min FVG (points)
input color    InpFVG_BullColor    = C'0,120,255'; // Couleur FVG Haussier
input color    InpFVG_BearColor    = C'255,80,0';  // Couleur FVG Baissier

//--- ═══════════════════ SMC - STRUCTURE ═════════════════════════
input group "══════ STRUCTURE DU MARCHÉ ══════"
input bool     InpUseBOS           = true;      // Break of Structure
input bool     InpUseCHoCH         = true;      // Change of Character
input int      InpStructLookback   = 50;        // Lookback Structure
input color    InpBOS_Color        = clrYellow; // Couleur BOS
input color    InpCHoCH_Color      = clrMagenta;// Couleur CHoCH

//--- ═══════════════════ SUPPLY & DEMAND ═════════════════════════
input group "══════ SUPPLY & DEMAND ══════"
input bool     InpUseSnD           = true;      // Activer Supply & Demand
input int      InpSnD_Lookback     = 100;       // Lookback S&D
input int      InpSnD_Strength     = 3;         // Force min zone (bougies)
input color    InpSupply_Color     = clrCrimson;    // Couleur Supply
input color    InpDemand_Color     = clrForestGreen; // Couleur Demand

//--- ═══════════════════ LIQUIDITY ═══════════════════════════════
input group "══════ LIQUIDITY POOLS ══════"
input bool     InpUseLiquidity     = true;      // Activer Liquidity
input int      InpLiq_Lookback     = 50;        // Lookback Liquidité
input color    InpLiq_Color        = clrGold;   // Couleur Liquidité

//--- ═══════════════════ INDICATEURS ═════════════════════════════
input group "══════ INDICATEURS ══════"
input bool     InpUseEMA9         = true;       // EMA 9 (Court terme)
input bool     InpUseEMA21        = true;       // EMA 21 (Entrée/Sortie)
input bool     InpUseEMA50        = true;       // EMA 50 (Stop Loss)
input bool     InpUseEMA200       = true;       // EMA 200 (Long terme)
input bool     InpUseMACD         = true;       // MACD (Signal)
input bool     InpUseRSI          = true;       // RSI (Overbought/Oversold)
input int      InpRSI_Period      = 14;         // Période RSI
input double   InpRSI_OB          = 70.0;       // RSI Overbought
input double   InpRSI_OS          = 30.0;       // RSI Oversold
input bool     InpUseBollinger    = true;       // Bollinger Bands
input int      InpBB_Period       = 20;         // Période Bollinger
input double   InpBB_Deviation    = 2.0;        // Déviation Bollinger

//--- ═══════════════════ PATTERNS ════════════════════════════════
input group "══════ PATTERNS (Triple Top/Bottom) ══════"
input bool     InpUseTripleTop    = true;       // Triple Top/Bottom
input int      InpPattern_LB      = 50;         // Lookback Pattern
input int      InpPattern_Tol     = 20;         // Tolérance Pattern (points)

//--- ═══════════════════ KILL ZONES ══════════════════════════════
input group "══════ KILL ZONES (Sessions) ══════"
input bool     InpUseKillZones    = true;       // Activer Kill Zones
input bool     InpLondonOpen      = true;       // London Open (07:00-09:00)
input bool     InpNYOpen          = true;       // NY Open (13:00-15:00)
input bool     InpLondonClose     = false;      // London Close (15:00-16:00)
input color    InpKZ_London_Color = C'255,215,0'; // Couleur Kill Zone London
input color    InpKZ_NY_Color     = C'0,191,255'; // Couleur Kill Zone NY

//--- ═══════════════════ BOOM/CRASH SPÉCIFIQUE ════════════════════
input group "══════ BOOM & CRASH (Synthetic) ══════"
input bool     InpBoomCrashMode   = false;      // Mode Boom/Crash activé
input int      InpSpike_ATR_Multi = 3;          // Multiplicateur ATR Spike
input int      InpSpike_Confirm   = 2;          // Bougies confirmation Spike
input bool     InpOnlyBuyBoom     = true;       // Boom: acheter seulement
input bool     InpOnlySellCrash   = true;       // Crash: vendre seulement

//--- ═══════════════════ AFFICHAGE ═══════════════════════════════
input group "══════ AFFICHAGE DASHBOARD ══════"
input bool     InpShowDashboard   = true;       // Afficher Dashboard
input bool     InpShowSignals     = true;       // Afficher signaux
input color    InpDash_BG         = C'15,15,30'; // Fond Dashboard
input color    InpDash_Text       = clrWhite;   // Texte Dashboard
input int      InpDash_X          = 10;         // Position X Dashboard
input int      InpDash_Y          = 30;         // Position Y Dashboard

//+------------------------------------------------------------------+
//|              VARIABLES GLOBALES                                   |
//+------------------------------------------------------------------+

//--- Objets de trading
CTrade         g_trade;
CPositionInfo  g_posInfo;
COrderInfo     g_ordInfo;

//--- Handles indicateurs
int h_ema9, h_ema21, h_ema50, h_ema200;
int h_macd, h_rsi, h_bb, h_atr;

//--- Compteurs et états
int    g_totalBars         = 0;
bool   g_isBullBias        = false;
bool   g_isBearBias        = false;
double g_dailyStartBalance = 0.0;
double g_dailyPnL          = 0.0;
datetime g_lastBarTime     = 0;

//--- Structures SMC
struct SOrderBlock {
   double   high;
   double   low;
   datetime time;
   bool     isBullish;
   bool     isActive;
   string   objName;
};

struct SFVG {
   double   high;
   double   low;
   datetime time;
   bool     isBullish;
   bool     isFilled;
   string   objName;
};

struct SSupplyDemand {
   double   high;
   double   low;
   datetime startTime;
   datetime endTime;
   bool     isSupply;
   bool     isActive;
   string   objName;
};

struct SLiquidityLevel {
   double   level;
   datetime time;
   bool     isBSL; // Buy Side Liquidity
   string   objName;
};

//--- Tableaux SMC
SOrderBlock    g_OB[];
SFVG           g_FVG[];
SSupplyDemand  g_SnD[];
SLiquidityLevel g_Liq[];

//--- Signal global
enum ENUM_SIGNAL {
   SIG_NONE  = 0,
   SIG_BUY   = 1,
   SIG_SELL  = -1
};

ENUM_SIGNAL g_currentSignal = SIG_NONE;
double      g_signalSL      = 0.0;
double      g_signalTP      = 0.0;
double      g_signalOB_High = 0.0;
double      g_signalOB_Low  = 0.0;

//+------------------------------------------------------------------+
//|              INITIALISATION                                       |
//+------------------------------------------------------------------+
int OnInit() {
   //--- Configuration du trading
   g_trade.SetExpertMagicNumber(202600);
   g_trade.SetDeviationInPoints(20);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   //--- Initialisation des indicateurs
   string sym = _Symbol;

   h_ema9   = iMA(sym, InpTF_Entry, 9,   0, MODE_EMA, PRICE_CLOSE);
   h_ema21  = iMA(sym, InpTF_Entry, 21,  0, MODE_EMA, PRICE_CLOSE);
   h_ema50  = iMA(sym, InpTF_Entry, 50,  0, MODE_EMA, PRICE_CLOSE);
   h_ema200 = iMA(sym, InpTF_Entry, 200, 0, MODE_EMA, PRICE_CLOSE);
   h_macd   = iMACD(sym, InpTF_Entry, 12, 26, 9, PRICE_CLOSE);
   h_rsi    = iRSI(sym, InpTF_Entry, InpRSI_Period, PRICE_CLOSE);
   h_bb     = iBands(sym, InpTF_Entry, InpBB_Period, 0, InpBB_Deviation, PRICE_CLOSE);
   h_atr    = iATR(sym, InpTF_Entry, 14);

   if(h_ema9 == INVALID_HANDLE || h_macd == INVALID_HANDLE ||
      h_rsi  == INVALID_HANDLE || h_atr  == INVALID_HANDLE) {
      Alert("SmartMoneyEA: Erreur initialisation indicateurs!");
      return INIT_FAILED;
   }

   //--- Balance de départ
   g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   //--- Nettoyer anciens objets
   CleanupAllObjects();

   //--- Initialiser les tableaux
   ArrayResize(g_OB,  0);
   ArrayResize(g_FVG, 0);
   ArrayResize(g_SnD, 0);
   ArrayResize(g_Liq, 0);

   //--- Afficher info
   Print("╔══════════════════════════════════════════╗");
   Print("║      SmartMoneyEA Pro - v1.0             ║");
   Print("║  Stratégie SMC Multi-TF Activée          ║");
   Print("╚══════════════════════════════════════════╝");
   Print("Symbole: ", _Symbol, " | Point: ", _Point, " | Digits: ", _Digits);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|              DÉSINITIALISATION                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   CleanupAllObjects();
   IndicatorRelease(h_ema9);
   IndicatorRelease(h_ema21);
   IndicatorRelease(h_ema50);
   IndicatorRelease(h_ema200);
   IndicatorRelease(h_macd);
   IndicatorRelease(h_rsi);
   IndicatorRelease(h_bb);
   IndicatorRelease(h_atr);
   Print("SmartMoneyEA: Désactivé. Raison: ", reason);
}

//+------------------------------------------------------------------+
//|              BOUCLE PRINCIPALE OnTick                            |
//+------------------------------------------------------------------+
void OnTick() {
   //--- Vérifier nouvelle bougie
   datetime currentBarTime = iTime(_Symbol, InpTF_Entry, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);

   if(isNewBar) {
      g_lastBarTime = currentBarTime;

      //=== ANALYSE MULTI-TIMEFRAME ===
      AnalyzeBias();           // 4H → Direction + S&D
      AnalyzeSetup();          // 1H → OB + FVG + Structure
      AnalyzeEntry();          // 15min → Reversal + Confirmation

      //=== DESSINS SUR GRAPHIQUE ===
      DrawOrderBlocks();
      DrawFairValueGaps();
      DrawSupplyDemand();
      DrawLiquidityLevels();
      DrawStructure();
      DrawKillZones();
      DrawEMAs();
      DrawTripleTopPattern();

      //=== GESTION DES TRADES ===
      ManageOpenPositions();

      //=== EXÉCUTION DES SIGNAUX ===
      if(CanOpenNewTrade()) {
         ExecuteSignal();
      }

      //=== DASHBOARD ===
      if(InpShowDashboard) DrawDashboard();
   }

   //--- Trailing stop en temps réel (chaque tick)
   if(InpUseTrailingStop) ManageTrailingStop();
}

//+------------------------------------------------------------------+
//|         ANALYSE 4H - BIAIS DIRECTIONNEL                         |
//+------------------------------------------------------------------+
void AnalyzeBias() {
   int bars = iBars(_Symbol, InpTF_Bias);
   if(bars < InpStructLookback) return;

   double ema200_4h[];
   ArraySetAsSeries(ema200_4h, true);

   int h_ema200_4h = iMA(_Symbol, InpTF_Bias, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(h_ema200_4h == INVALID_HANDLE) return;

   if(CopyBuffer(h_ema200_4h, 0, 0, 3, ema200_4h) < 3) {
      IndicatorRelease(h_ema200_4h);
      return;
   }

   double close_4h = iClose(_Symbol, InpTF_Bias, 1);
   double high_4h  = iHigh(_Symbol, InpTF_Bias, 1);
   double low_4h   = iLow(_Symbol, InpTF_Bias, 1);

   //--- Déterminer le biais
   g_isBullBias = (close_4h > ema200_4h[1]);
   g_isBearBias = (close_4h < ema200_4h[1]);

   //--- Analyser Supply & Demand sur 4H
   if(InpUseSnD) DetectSupplyDemand(InpTF_Bias);

   IndicatorRelease(h_ema200_4h);
}

//+------------------------------------------------------------------+
//|         ANALYSE 1H - SETUP (OB, FVG, BOS, CHoCH)               |
//+------------------------------------------------------------------+
void AnalyzeSetup() {
   int bars = iBars(_Symbol, InpTF_Setup);
   if(bars < InpOB_Lookback + 5) return;

   //--- Détecter Order Blocks sur 1H
   if(InpUseOrderBlocks) DetectOrderBlocks(InpTF_Setup);

   //--- Détecter FVG sur 1H
   if(InpUseFVG) DetectFairValueGaps(InpTF_Setup);

   //--- Détecter Liquidité sur 1H
   if(InpUseLiquidity) DetectLiquidity(InpTF_Setup);

   //--- Détecter Structure (BOS/CHoCH)
   if(InpUseBOS || InpUseCHoCH) DetectStructure(InpTF_Setup);
}

//+------------------------------------------------------------------+
//|         ANALYSE 15min - ENTRÉE (Reversal + Confirmation)        |
//+------------------------------------------------------------------+
void AnalyzeEntry() {
   g_currentSignal = SIG_NONE;

   //--- Lire les indicateurs 15min
   double ema9[], ema21[], ema50[], ema200[];
   double macd_main[], macd_signal[];
   double rsi_val[];
   double bb_upper[], bb_lower[], bb_middle[];
   double atr_val[];

   ArraySetAsSeries(ema9, true);   ArraySetAsSeries(ema21, true);
   ArraySetAsSeries(ema50, true);  ArraySetAsSeries(ema200, true);
   ArraySetAsSeries(macd_main, true); ArraySetAsSeries(macd_signal, true);
   ArraySetAsSeries(rsi_val, true);
   ArraySetAsSeries(bb_upper, true); ArraySetAsSeries(bb_lower, true);
   ArraySetAsSeries(bb_middle, true);
   ArraySetAsSeries(atr_val, true);

   if(CopyBuffer(h_ema9,   0, 0, 3, ema9)      < 3) return;
   if(CopyBuffer(h_ema21,  0, 0, 3, ema21)     < 3) return;
   if(CopyBuffer(h_ema50,  0, 0, 3, ema50)     < 3) return;
   if(CopyBuffer(h_ema200, 0, 0, 3, ema200)    < 3) return;
   if(CopyBuffer(h_macd,   0, 0, 3, macd_main) < 3) return;
   if(CopyBuffer(h_macd,   1, 0, 3, macd_signal)< 3) return;
   if(CopyBuffer(h_rsi,    0, 0, 3, rsi_val)   < 3) return;
   if(CopyBuffer(h_bb,     1, 0, 3, bb_upper)  < 3) return;
   if(CopyBuffer(h_bb,     2, 0, 3, bb_lower)  < 3) return;
   if(CopyBuffer(h_bb,     0, 0, 3, bb_middle) < 3) return;
   if(CopyBuffer(h_atr,    0, 0, 3, atr_val)   < 3) return;

   double close1 = iClose(_Symbol, InpTF_Entry, 1);
   double open1  = iOpen(_Symbol,  InpTF_Entry, 1);
   double high1  = iHigh(_Symbol,  InpTF_Entry, 1);
   double low1   = iLow(_Symbol,   InpTF_Entry, 1);
   double close2 = iClose(_Symbol, InpTF_Entry, 2);

   //--- Mode Boom/Crash
   if(InpBoomCrashMode) {
      AnalyzeBoomCrash(atr_val[1], close1, high1, low1);
      return;
   }

   //--- Kill Zones - vérifier si on est dans une session active
   if(InpUseKillZones && !IsInKillZone()) return;

   //--- ════ SIGNAL ACHAT ════
   bool buySignal  = false;
   bool sellSignal = false;

   // 1. Biais haussier (4H)
   if(g_isBullBias) {
      // 2. EMA Alignment haussier (9 > 21 > 50)
      bool emaAlignBull = (ema9[1] > ema21[1] && ema21[1] > ema50[1]);
      // 3. MACD au-dessus du signal
      bool macdBull = (macd_main[1] > macd_signal[1]);
      // 4. RSI pas en surachat
      bool rsiBull  = (rsi_val[1] > 40.0 && rsi_val[1] < InpRSI_OB);
      // 5. Prix au-dessus EMA200
      bool aboveEMA200 = (close1 > ema200[1]);
      // 6. Close haussière (bullish candle)
      bool bullCandle = (close1 > open1);
      // 7. Proximité d'un Order Block haussier
      bool nearBullOB = IsNearBullishOB(close1, atr_val[1]);
      // 8. Prix dans une FVG haussière (pour confirmation)
      bool inBullFVG = IsInBullishFVG(low1, high1);

      if(aboveEMA200 && emaAlignBull && macdBull && rsiBull && bullCandle) {
         if(nearBullOB || inBullFVG) {
            buySignal = true;
         }
      }
   }

   //--- ════ SIGNAL VENTE ════
   if(g_isBearBias) {
      bool emaAlignBear = (ema9[1] < ema21[1] && ema21[1] < ema50[1]);
      bool macdBear     = (macd_main[1] < macd_signal[1]);
      bool rsiSell      = (rsi_val[1] < 60.0 && rsi_val[1] > InpRSI_OS);
      bool belowEMA200  = (close1 < ema200[1]);
      bool bearCandle   = (close1 < open1);
      bool nearBearOB   = IsNearBearishOB(close1, atr_val[1]);
      bool inBearFVG    = IsInBearishFVG(low1, high1);

      if(belowEMA200 && emaAlignBear && macdBear && rsiSell && bearCandle) {
         if(nearBearOB || inBearFVG) {
            sellSignal = true;
         }
      }
   }

   //--- Finaliser le signal
   if(buySignal) {
      g_currentSignal = SIG_BUY;
      CalculateSLTP_Buy(close1, atr_val[1]);
      if(InpShowSignals) DrawSignalArrow(true, iTime(_Symbol, InpTF_Entry, 1), low1);
   }
   else if(sellSignal) {
      g_currentSignal = SIG_SELL;
      CalculateSLTP_Sell(close1, atr_val[1]);
      if(InpShowSignals) DrawSignalArrow(false, iTime(_Symbol, InpTF_Entry, 1), high1);
   }
}

//+------------------------------------------------------------------+
//|         DÉTECTION DES ORDER BLOCKS                              |
//+------------------------------------------------------------------+
void DetectOrderBlocks(ENUM_TIMEFRAMES tf) {
   int n = InpOB_Lookback;
   int bars = iBars(_Symbol, tf);
   if(bars < n + 5) return;

   //--- Réinitialiser
   ArrayResize(g_OB, 0);
   int count = 0;

   for(int i = 1; i < n - 1; i++) {
      double open_i  = iOpen(_Symbol,  tf, i);
      double close_i = iClose(_Symbol, tf, i);
      double high_i  = iHigh(_Symbol,  tf, i);
      double low_i   = iLow(_Symbol,   tf, i);
      double close_prev = iClose(_Symbol, tf, i+1);

      //--- Order Block Haussier: dernière bougie baissière avant mouvement haussier fort
      double close_next1 = iClose(_Symbol, tf, i-1);
      double close_next2 = (i > 1) ? iClose(_Symbol, tf, i-2) : close_next1;

      bool isBearishCandle = (close_i < open_i);
      bool strongBullMove  = ((close_next1 - close_i) > InpOB_MinSize * _Point * 2);

      if(isBearishCandle && strongBullMove) {
         ArrayResize(g_OB, count+1);
         g_OB[count].high      = high_i;
         g_OB[count].low       = low_i;
         g_OB[count].time      = iTime(_Symbol, tf, i);
         g_OB[count].isBullish = true;
         g_OB[count].isActive  = true;
         g_OB[count].objName   = "OB_Bull_" + IntegerToString(i) + "_" + TimeToString(iTime(_Symbol,tf,i),TIME_DATE);
         count++;
         if(count >= 10) break; // Maximum 10 OB
      }

      //--- Order Block Baissier: dernière bougie haussière avant mouvement baissier fort
      bool isBullishCandle = (close_i > open_i);
      bool strongBearMove  = ((close_i - close_next1) > InpOB_MinSize * _Point * 2);

      if(isBullishCandle && strongBearMove) {
         ArrayResize(g_OB, count+1);
         g_OB[count].high      = high_i;
         g_OB[count].low       = low_i;
         g_OB[count].time      = iTime(_Symbol, tf, i);
         g_OB[count].isBullish = false;
         g_OB[count].isActive  = true;
         g_OB[count].objName   = "OB_Bear_" + IntegerToString(i) + "_" + TimeToString(iTime(_Symbol,tf,i),TIME_DATE);
         count++;
         if(count >= 10) break;
      }
   }
}

//+------------------------------------------------------------------+
//|         DÉTECTION DES FAIR VALUE GAPS                           |
//+------------------------------------------------------------------+
void DetectFairValueGaps(ENUM_TIMEFRAMES tf) {
   int n = InpFVG_Lookback;
   int bars = iBars(_Symbol, tf);
   if(bars < n + 3) return;

   ArrayResize(g_FVG, 0);
   int count = 0;

   for(int i = 1; i < n; i++) {
      double high_prev  = iHigh(_Symbol, tf, i+1);
      double low_prev   = iLow(_Symbol,  tf, i+1);
      double high_curr  = iHigh(_Symbol, tf, i);
      double low_curr   = iLow(_Symbol,  tf, i);
      double high_next  = iHigh(_Symbol, tf, i-1);
      double low_next   = iLow(_Symbol,  tf, i-1);

      double minSize = InpFVG_MinSize * _Point;

      //--- FVG Haussier: low[i-1] > high[i+1]  (gap entre bougie 1 et 3)
      if(low_next > high_prev && (low_next - high_prev) > minSize) {
         ArrayResize(g_FVG, count+1);
         g_FVG[count].high      = low_next;
         g_FVG[count].low       = high_prev;
         g_FVG[count].time      = iTime(_Symbol, tf, i);
         g_FVG[count].isBullish = true;
         g_FVG[count].isFilled  = false;
         g_FVG[count].objName   = "FVG_Bull_" + IntegerToString(i);
         count++;
         if(count >= 15) break;
      }

      //--- FVG Baissier: high[i-1] < low[i+1]
      if(high_next < low_prev && (low_prev - high_next) > minSize) {
         ArrayResize(g_FVG, count+1);
         g_FVG[count].high      = low_prev;
         g_FVG[count].low       = high_next;
         g_FVG[count].time      = iTime(_Symbol, tf, i);
         g_FVG[count].isBullish = false;
         g_FVG[count].isFilled  = false;
         g_FVG[count].objName   = "FVG_Bear_" + IntegerToString(i);
         count++;
         if(count >= 15) break;
      }
   }
}

//+------------------------------------------------------------------+
//|         DÉTECTION SUPPLY & DEMAND                               |
//+------------------------------------------------------------------+
void DetectSupplyDemand(ENUM_TIMEFRAMES tf) {
   int n = InpSnD_Lookback;
   int bars = iBars(_Symbol, tf);
   if(bars < n + 5) return;

   ArrayResize(g_SnD, 0);
   int count = 0;

   for(int i = InpSnD_Strength; i < n - InpSnD_Strength; i++) {
      double high_zone = iHigh(_Symbol, tf, i);
      double low_zone  = iLow(_Symbol,  tf, i);
      double close_i   = iClose(_Symbol, tf, i);
      double open_i    = iOpen(_Symbol,  tf, i);

      //--- Trouver les extremes sur la période de confirmation
      double maxHighBefore = 0, minLowBefore = 9999999;
      double maxHighAfter  = 0, minLowAfter  = 9999999;

      for(int j = 1; j <= InpSnD_Strength; j++) {
         double h_before = iHigh(_Symbol, tf, i+j);
         double l_before = iLow(_Symbol,  tf, i+j);
         double h_after  = iHigh(_Symbol, tf, i-j);
         double l_after  = iLow(_Symbol,  tf, i-j);

         if(h_before > maxHighBefore) maxHighBefore = h_before;
         if(l_before < minLowBefore)  minLowBefore  = l_before;
         if(h_after  > maxHighAfter)  maxHighAfter  = h_after;
         if(l_after  < minLowAfter)   minLowAfter   = l_after;
      }

      //--- Zone de Demande: Bas local avec fort mouvement haussier
      bool isDemand = (low_zone < minLowBefore) && (maxHighAfter > high_zone * 1.001);
      //--- Zone de Supply: Haut local avec fort mouvement baissier
      bool isSupply = (high_zone > maxHighBefore) && (minLowAfter < low_zone * 0.999);

      if(isDemand && count < 8) {
         ArrayResize(g_SnD, count+1);
         g_SnD[count].high      = high_zone;
         g_SnD[count].low       = low_zone;
         g_SnD[count].startTime = iTime(_Symbol, tf, i);
         g_SnD[count].endTime   = TimeCurrent() + PeriodSeconds(tf) * 20;
         g_SnD[count].isSupply  = false;
         g_SnD[count].isActive  = true;
         g_SnD[count].objName   = "SD_Demand_" + IntegerToString(i);
         count++;
      }
      else if(isSupply && count < 8) {
         ArrayResize(g_SnD, count+1);
         g_SnD[count].high      = high_zone;
         g_SnD[count].low       = low_zone;
         g_SnD[count].startTime = iTime(_Symbol, tf, i);
         g_SnD[count].endTime   = TimeCurrent() + PeriodSeconds(tf) * 20;
         g_SnD[count].isSupply  = true;
         g_SnD[count].isActive  = true;
         g_SnD[count].objName   = "SD_Supply_" + IntegerToString(i);
         count++;
      }
   }
}

//+------------------------------------------------------------------+
//|         DÉTECTION LIQUIDITÉ                                      |
//+------------------------------------------------------------------+
void DetectLiquidity(ENUM_TIMEFRAMES tf) {
   int n = InpLiq_Lookback;
   int bars = iBars(_Symbol, tf);
   if(bars < n + 3) return;

   ArrayResize(g_Liq, 0);
   int count = 0;

   //--- Chercher les equal highs/lows (Liquidity Pools)
   double tolerance = 5 * _Point;

   for(int i = 3; i < n - 3; i++) {
      double high_i = iHigh(_Symbol, tf, i);
      double low_i  = iLow(_Symbol,  tf, i);

      //--- Chercher equal highs (BSL - Buy Side Liquidity)
      for(int j = i+2; j < MathMin(i+15, n); j++) {
         double high_j = iHigh(_Symbol, tf, j);
         if(MathAbs(high_i - high_j) < tolerance) {
            ArrayResize(g_Liq, count+1);
            g_Liq[count].level  = (high_i + high_j) / 2.0;
            g_Liq[count].time   = iTime(_Symbol, tf, i);
            g_Liq[count].isBSL  = true;
            g_Liq[count].objName = "LIQ_BSL_" + IntegerToString(count);
            count++;
            if(count >= 10) return;
            break;
         }
      }

      //--- Chercher equal lows (SSL - Sell Side Liquidity)
      for(int j = i+2; j < MathMin(i+15, n); j++) {
         double low_j = iLow(_Symbol, tf, j);
         if(MathAbs(low_i - low_j) < tolerance) {
            ArrayResize(g_Liq, count+1);
            g_Liq[count].level  = (low_i + low_j) / 2.0;
            g_Liq[count].time   = iTime(_Symbol, tf, i);
            g_Liq[count].isBSL  = false;
            g_Liq[count].objName = "LIQ_SSL_" + IntegerToString(count);
            count++;
            if(count >= 10) return;
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//|         DÉTECTION STRUCTURE (BOS / CHoCH)                      |
//+------------------------------------------------------------------+
void DetectStructure(ENUM_TIMEFRAMES tf) {
   int n = InpStructLookback;
   if(iBars(_Symbol, tf) < n + 5) return;

   //--- Identifier HH, HL, LH, LL (structure de marché)
   double prevSwingHigh = 0, prevSwingLow = 9999999;
   double currSwingHigh = 0, currSwingLow = 9999999;
   datetime prevHighTime = 0, prevLowTime = 0;

   for(int i = 2; i < n-2; i++) {
      double h = iHigh(_Symbol, tf, i);
      double l = iLow(_Symbol,  tf, i);
      double h1 = iHigh(_Symbol, tf, i+1), h2 = iHigh(_Symbol, tf, i-1);
      double l1 = iLow(_Symbol,  tf, i+1), l2 = iLow(_Symbol,  tf, i-1);

      bool isSwingHigh = (h > h1 && h > h2);
      bool isSwingLow  = (l < l1 && l < l2);

      if(isSwingHigh) {
         if(prevSwingHigh > 0) {
            //--- BOS Haussier: HH brisé
            if(InpUseBOS && h > prevSwingHigh) {
               DrawStructureLine("BOS_Bull_" + IntegerToString(i),
                  iTime(_Symbol, tf, i), prevSwingHigh,
                  iTime(_Symbol, tf, 0), prevSwingHigh,
                  InpBOS_Color, "BOS ↑");
            }
            //--- CHoCH: LH (structure baissière commence)
            if(InpUseCHoCH && h < prevSwingHigh) {
               DrawStructureLine("CHoCH_Bear_" + IntegerToString(i),
                  iTime(_Symbol, tf, i), h,
                  iTime(_Symbol, tf, 0), h,
                  InpCHoCH_Color, "CHoCH ↓");
            }
         }
         prevSwingHigh = h;
         prevHighTime  = iTime(_Symbol, tf, i);
      }

      if(isSwingLow) {
         if(prevSwingLow < 9999999) {
            //--- BOS Baissier: LL brisé
            if(InpUseBOS && l < prevSwingLow) {
               DrawStructureLine("BOS_Bear_" + IntegerToString(i),
                  iTime(_Symbol, tf, i), prevSwingLow,
                  iTime(_Symbol, tf, 0), prevSwingLow,
                  InpBOS_Color, "BOS ↓");
            }
            //--- CHoCH: HL (structure haussière commence)
            if(InpUseCHoCH && l > prevSwingLow) {
               DrawStructureLine("CHoCH_Bull_" + IntegerToString(i),
                  iTime(_Symbol, tf, i), l,
                  iTime(_Symbol, tf, 0), l,
                  InpCHoCH_Color, "CHoCH ↑");
            }
         }
         prevSwingLow = l;
         prevLowTime  = iTime(_Symbol, tf, i);
      }
   }
}

//+------------------------------------------------------------------+
//|         ANALYSE BOOM / CRASH                                    |
//+------------------------------------------------------------------+
void AnalyzeBoomCrash(double atr, double close, double high, double low) {
   string sym = _Symbol;
   bool isBoom  = (StringFind(sym, "Boom")  >= 0 || StringFind(sym, "BOOM")  >= 0);
   bool isCrash = (StringFind(sym, "Crash") >= 0 || StringFind(sym, "CRASH") >= 0);

   //--- Détection spike par ATR Z-Score
   double spikeThreshold = atr * InpSpike_ATR_Multi;
   double candleRange    = high - low;

   bool isBullSpike = (candleRange > spikeThreshold) && (close > (low + candleRange * 0.7));
   bool isBearSpike = (candleRange > spikeThreshold) && (close < (high - candleRange * 0.7));

   //--- Sur Boom: acheter seulement (après spike baissier)
   if(isBoom && InpOnlyBuyBoom) {
      if(isBearSpike) {
         // Attendre confirmation (prix remonte)
         double close_confirm = iClose(_Symbol, InpTF_Entry, 1);
         double open_confirm  = iOpen(_Symbol,  InpTF_Entry, 1);
         if(close_confirm > open_confirm) { // Bougie haussière de confirmation
            g_currentSignal = SIG_BUY;
            g_signalSL = low - atr * 0.5;
            g_signalTP = close + atr * 3.0;
         }
      }
   }

   //--- Sur Crash: vendre seulement (après spike haussier)
   if(isCrash && InpOnlySellCrash) {
      if(isBullSpike) {
         double close_confirm = iClose(_Symbol, InpTF_Entry, 1);
         double open_confirm  = iOpen(_Symbol,  InpTF_Entry, 1);
         if(close_confirm < open_confirm) { // Bougie baissière de confirmation
            g_currentSignal = SIG_SELL;
            g_signalSL = high + atr * 0.5;
            g_signalTP = close - atr * 3.0;
         }
      }
   }
}

//+------------------------------------------------------------------+
//|         CALCUL SL/TP BUY                                        |
//+------------------------------------------------------------------+
void CalculateSLTP_Buy(double entryPrice, double atr) {
   //--- SL: sous l'OB le plus proche ou sous EMA50
   double ema50_val[];
   ArraySetAsSeries(ema50_val, true);
   CopyBuffer(h_ema50, 0, 0, 2, ema50_val);

   double slBase = ema50_val[1] - atr * 1.5;

   //--- Chercher le meilleur OB haussier pour SL
   double bestOBLow = 0;
   for(int i = 0; i < ArraySize(g_OB); i++) {
      if(g_OB[i].isBullish && g_OB[i].isActive) {
         if(g_OB[i].low < entryPrice && g_OB[i].low > bestOBLow) {
            bestOBLow = g_OB[i].low;
         }
      }
   }

   g_signalSL = (bestOBLow > 0) ? bestOBLow - atr * 0.3 : slBase;
   double riskPoints = entryPrice - g_signalSL;

   //--- TP: 2:1 ou vers prochaine zone de liquidité
   g_signalTP = entryPrice + riskPoints * 2.0;

   //--- Chercher prochaine zone BSL comme TP
   for(int i = 0; i < ArraySize(g_Liq); i++) {
      if(g_Liq[i].isBSL && g_Liq[i].level > entryPrice && g_Liq[i].level < g_signalTP * 1.5) {
         g_signalTP = g_Liq[i].level;
         break;
      }
   }
}

//+------------------------------------------------------------------+
//|         CALCUL SL/TP SELL                                       |
//+------------------------------------------------------------------+
void CalculateSLTP_Sell(double entryPrice, double atr) {
   double ema50_val[];
   ArraySetAsSeries(ema50_val, true);
   CopyBuffer(h_ema50, 0, 0, 2, ema50_val);

   double slBase = ema50_val[1] + atr * 1.5;

   double bestOBHigh = 9999999;
   for(int i = 0; i < ArraySize(g_OB); i++) {
      if(!g_OB[i].isBullish && g_OB[i].isActive) {
         if(g_OB[i].high > entryPrice && g_OB[i].high < bestOBHigh) {
            bestOBHigh = g_OB[i].high;
         }
      }
   }

   g_signalSL = (bestOBHigh < 9999999) ? bestOBHigh + atr * 0.3 : slBase;
   double riskPoints = g_signalSL - entryPrice;

   g_signalTP = entryPrice - riskPoints * 2.0;

   for(int i = 0; i < ArraySize(g_Liq); i++) {
      if(!g_Liq[i].isBSL && g_Liq[i].level < entryPrice && g_Liq[i].level > g_signalTP * 0.5) {
         g_signalTP = g_Liq[i].level;
         break;
      }
   }
}

//+------------------------------------------------------------------+
//|         CALCUL TAILLE DE LOT                                    |
//+------------------------------------------------------------------+
double CalculateLotSize(double slPoints) {
   if(slPoints <= 0) return InpMinLotSize;

   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk     = balance * InpRiskPercent / 100.0;
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickVal <= 0 || tickSize <= 0) return InpMinLotSize;

   double lotCalc = risk / (slPoints / tickSize * tickVal);

   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotCalc = MathFloor(lotCalc / lotStep) * lotStep;
   lotCalc = MathMax(InpMinLotSize, MathMin(InpMaxLotSize, lotCalc));

   return NormalizeDouble(lotCalc, 2);
}

//+------------------------------------------------------------------+
//|         VÉRIFICATIONS AVANT OUVERTURE                           |
//+------------------------------------------------------------------+
bool CanOpenNewTrade() {
   //--- Vérifier nombre max de trades
   int openCount = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(g_posInfo.SelectByIndex(i)) {
         if(g_posInfo.Symbol() == _Symbol && g_posInfo.Magic() == 202600)
            openCount++;
      }
   }
   if(openCount >= InpMaxOpenTrades) return false;

   //--- Vérifier limite de perte journalière
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyLoss = (g_dailyStartBalance - equity) / g_dailyStartBalance * 100.0;
   if(dailyLoss >= InpDailyLossLimit) {
      static bool warnPrinted = false;
      if(!warnPrinted) {
         Print("SmartMoneyEA: Limite perte journalière atteinte (", DoubleToString(dailyLoss,2), "%)");
         warnPrinted = true;
      }
      return false;
   }

   return (g_currentSignal != SIG_NONE);
}

//+------------------------------------------------------------------+
//|         EXÉCUTION DU SIGNAL                                     |
//+------------------------------------------------------------------+
void ExecuteSignal() {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slPoints = 0;
   double lot      = 0;
   string comment  = "SmartMoneyEA|SMC";

   if(g_currentSignal == SIG_BUY) {
      slPoints = (ask - g_signalSL) / _Point;
      if(slPoints < 10) return; // SL trop proche
      lot = CalculateLotSize(slPoints * _Point);
      if(lot <= 0) return;

      g_signalSL = NormalizeDouble(g_signalSL, _Digits);
      g_signalTP = NormalizeDouble(g_signalTP, _Digits);

      if(g_trade.Buy(lot, _Symbol, ask, g_signalSL, g_signalTP, comment)) {
         Print("✅ BUY ouvert | Lot:", lot, " SL:", g_signalSL, " TP:", g_signalTP);
         DrawTradeLevel("SL_Buy_" + IntegerToString(TimeCurrent()), g_signalSL, clrRed, "SL");
         DrawTradeLevel("TP_Buy_" + IntegerToString(TimeCurrent()), g_signalTP, clrLime, "TP");
      } else {
         Print("❌ Erreur BUY: ", g_trade.ResultRetcode(), " - ", g_trade.ResultRetcodeDescription());
      }
   }
   else if(g_currentSignal == SIG_SELL) {
      slPoints = (g_signalSL - bid) / _Point;
      if(slPoints < 10) return;
      lot = CalculateLotSize(slPoints * _Point);
      if(lot <= 0) return;

      g_signalSL = NormalizeDouble(g_signalSL, _Digits);
      g_signalTP = NormalizeDouble(g_signalTP, _Digits);

      if(g_trade.Sell(lot, _Symbol, bid, g_signalSL, g_signalTP, comment)) {
         Print("✅ SELL ouvert | Lot:", lot, " SL:", g_signalSL, " TP:", g_signalTP);
         DrawTradeLevel("SL_Sell_" + IntegerToString(TimeCurrent()), g_signalSL, clrRed, "SL");
         DrawTradeLevel("TP_Sell_" + IntegerToString(TimeCurrent()), g_signalTP, clrLime, "TP");
      } else {
         Print("❌ Erreur SELL: ", g_trade.ResultRetcode(), " - ", g_trade.ResultRetcodeDescription());
      }
   }

   g_currentSignal = SIG_NONE;
}

//+------------------------------------------------------------------+
//|         GESTION DES POSITIONS OUVERTES                         |
//+------------------------------------------------------------------+
void ManageOpenPositions() {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!g_posInfo.SelectByIndex(i)) continue;
      if(g_posInfo.Symbol() != _Symbol) continue;
      if(g_posInfo.Magic() != 202600) continue;

      double openPrice  = g_posInfo.PriceOpen();
      double currentSL  = g_posInfo.StopLoss();
      double currentTP  = g_posInfo.TakeProfit();
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      ulong  ticket     = g_posInfo.Ticket();

      //--- Break Even: déplacer SL au prix d'entrée si profit >= 1R
      double atr_val[];
      ArraySetAsSeries(atr_val, true);
      if(CopyBuffer(h_atr, 0, 0, 2, atr_val) >= 2) {
         double atr = atr_val[1];
         if(g_posInfo.PositionType() == POSITION_TYPE_BUY) {
            double profitPoints = currentBid - openPrice;
            if(profitPoints > atr * 1.5 && currentSL < openPrice) {
               g_trade.PositionModify(ticket, openPrice + _Point, currentTP);
            }
         }
         else if(g_posInfo.PositionType() == POSITION_TYPE_SELL) {
            double profitPoints = openPrice - currentAsk;
            if(profitPoints > atr * 1.5 && currentSL > openPrice) {
               g_trade.PositionModify(ticket, openPrice - _Point, currentTP);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//|         TRAILING STOP                                           |
//+------------------------------------------------------------------+
void ManageTrailingStop() {
   if(!InpUseTrailingStop) return;

   double atr_val[];
   ArraySetAsSeries(atr_val, true);
   if(CopyBuffer(h_atr, 0, 0, 2, atr_val) < 2) return;
   double atr = atr_val[1];
   double trailDist = MathMax(InpTrailingStep * _Point, atr * 1.0);

   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!g_posInfo.SelectByIndex(i)) continue;
      if(g_posInfo.Symbol() != _Symbol) continue;
      if(g_posInfo.Magic() != 202600) continue;

      ulong  ticket    = g_posInfo.Ticket();
      double openPrice = g_posInfo.PriceOpen();
      double currentSL = g_posInfo.StopLoss();
      double currentTP = g_posInfo.TakeProfit();
      double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(g_posInfo.PositionType() == POSITION_TYPE_BUY) {
         double newSL = NormalizeDouble(bid - trailDist, _Digits);
         if(newSL > currentSL + _Point && newSL > openPrice) {
            g_trade.PositionModify(ticket, newSL, currentTP);
         }
      }
      else if(g_posInfo.PositionType() == POSITION_TYPE_SELL) {
         double newSL = NormalizeDouble(ask + trailDist, _Digits);
         if(newSL < currentSL - _Point && newSL < openPrice) {
            g_trade.PositionModify(ticket, newSL, currentTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//|         VÉRIFICATIONS CONTEXTUELLES                             |
//+------------------------------------------------------------------+
bool IsNearBullishOB(double price, double atr) {
   double tolerance = atr * 0.5;
   for(int i = 0; i < ArraySize(g_OB); i++) {
      if(!g_OB[i].isBullish || !g_OB[i].isActive) continue;
      if(price >= g_OB[i].low - tolerance && price <= g_OB[i].high + tolerance)
         return true;
   }
   return false;
}

bool IsNearBearishOB(double price, double atr) {
   double tolerance = atr * 0.5;
   for(int i = 0; i < ArraySize(g_OB); i++) {
      if(g_OB[i].isBullish || !g_OB[i].isActive) continue;
      if(price >= g_OB[i].low - tolerance && price <= g_OB[i].high + tolerance)
         return true;
   }
   return false;
}

bool IsInBullishFVG(double low, double high) {
   for(int i = 0; i < ArraySize(g_FVG); i++) {
      if(!g_FVG[i].isBullish || g_FVG[i].isFilled) continue;
      if(low <= g_FVG[i].high && high >= g_FVG[i].low) return true;
   }
   return false;
}

bool IsInBearishFVG(double low, double high) {
   for(int i = 0; i < ArraySize(g_FVG); i++) {
      if(g_FVG[i].isBullish || g_FVG[i].isFilled) continue;
      if(low <= g_FVG[i].high && high >= g_FVG[i].low) return true;
   }
   return false;
}

bool IsInKillZone() {
   if(!InpUseKillZones) return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;

   if(InpLondonOpen && hour >= 7  && hour < 9)  return true;
   if(InpNYOpen     && hour >= 13 && hour < 15) return true;
   if(InpLondonClose && hour >= 15 && hour < 16) return true;

   return false;
}

//+------------------------------------------------------------------+
//|         TRIPLE TOP / BOTTOM PATTERN                             |
//+------------------------------------------------------------------+
void DrawTripleTopPattern() {
   if(!InpUseTripleTop) return;

   int n = InpPattern_LB;
   if(iBars(_Symbol, InpTF_Setup) < n) return;

   double tol = InpPattern_Tol * _Point;
   double tops[3] = {0, 0, 0};
   datetime topTimes[3];
   int topCount = 0;

   double bots[3] = {0, 0, 0};
   datetime botTimes[3];
   int botCount = 0;

   for(int i = 2; i < n-2 && (topCount < 3 || botCount < 3); i++) {
      double h = iHigh(_Symbol, InpTF_Setup, i);
      double l = iLow(_Symbol,  InpTF_Setup, i);
      bool isSwingHigh = h > iHigh(_Symbol, InpTF_Setup, i+1) &&
                         h > iHigh(_Symbol, InpTF_Setup, i-1) &&
                         h > iHigh(_Symbol, InpTF_Setup, i+2) &&
                         h > iHigh(_Symbol, InpTF_Setup, i-2);
      bool isSwingLow  = l < iLow(_Symbol,  InpTF_Setup, i+1) &&
                         l < iLow(_Symbol,  InpTF_Setup, i-1) &&
                         l < iLow(_Symbol,  InpTF_Setup, i+2) &&
                         l < iLow(_Symbol,  InpTF_Setup, i-2);

      if(isSwingHigh && topCount < 3) {
         if(topCount == 0 || MathAbs(h - tops[0]) < tol * 3) {
            tops[topCount]     = h;
            topTimes[topCount] = iTime(_Symbol, InpTF_Setup, i);
            topCount++;
         }
      }
      if(isSwingLow && botCount < 3) {
         if(botCount == 0 || MathAbs(l - bots[0]) < tol * 3) {
            bots[botCount]     = l;
            botTimes[botCount] = iTime(_Symbol, InpTF_Setup, i);
            botCount++;
         }
      }
   }

   //--- Dessiner Triple Top si trouvé
   if(topCount == 3 && MathAbs(tops[0]-tops[1]) < tol && MathAbs(tops[1]-tops[2]) < tol) {
      double avgTop = (tops[0] + tops[1] + tops[2]) / 3.0;
      for(int k = 0; k < 3; k++) {
         string nm = "TT_Peak_" + IntegerToString(k);
         ObjectCreate(0, nm, OBJ_ARROW_DOWN, 0, topTimes[k], tops[k] + 5*_Point);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, 234);
         ObjectSetInteger(0, nm, OBJPROP_WIDTH, 2);
      }
      //--- Ligne de résistance
      ObjectCreate(0, "TT_Line", OBJ_TREND, 0, topTimes[2], avgTop, topTimes[0], avgTop);
      ObjectSetInteger(0, "TT_Line", OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, "TT_Line", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "TT_Line", OBJPROP_WIDTH, 1);
   }

   //--- Dessiner Triple Bottom si trouvé
   if(botCount == 3 && MathAbs(bots[0]-bots[1]) < tol && MathAbs(bots[1]-bots[2]) < tol) {
      double avgBot = (bots[0] + bots[1] + bots[2]) / 3.0;
      for(int k = 0; k < 3; k++) {
         string nm = "TB_Trough_" + IntegerToString(k);
         ObjectCreate(0, nm, OBJ_ARROW_UP, 0, botTimes[k], bots[k] - 5*_Point);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, clrLimeGreen);
         ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, 233);
         ObjectSetInteger(0, nm, OBJPROP_WIDTH, 2);
      }
      ObjectCreate(0, "TB_Line", OBJ_TREND, 0, botTimes[2], avgBot, botTimes[0], avgBot);
      ObjectSetInteger(0, "TB_Line", OBJPROP_COLOR, clrLimeGreen);
      ObjectSetInteger(0, "TB_Line", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "TB_Line", OBJPROP_WIDTH, 1);
   }
}

//+------------------------------------------------------------------+
//|         ═══ FONCTIONS DE DESSIN SUR GRAPHIQUE ═══               |
//+------------------------------------------------------------------+

//--- Dessiner Order Blocks
void DrawOrderBlocks() {
   if(!InpUseOrderBlocks) return;

   // Supprimer anciens OB
   ObjectsDeleteAll(0, "OB_", 0, OBJ_RECTANGLE);

   datetime currentTime = TimeCurrent();
   datetime futureTime  = currentTime + PeriodSeconds(InpTF_Entry) * 30;

   for(int i = 0; i < ArraySize(g_OB); i++) {
      if(!g_OB[i].isActive) continue;

      color    boxColor = g_OB[i].isBullish ? InpOB_BullColor : InpOB_BearColor;
      string   nm       = g_OB[i].objName;

      if(ObjectCreate(0, nm, OBJ_RECTANGLE, 0,
                      g_OB[i].time, g_OB[i].high,
                      futureTime,   g_OB[i].low)) {
         ObjectSetInteger(0, nm, OBJPROP_COLOR,   boxColor);
         ObjectSetInteger(0, nm, OBJPROP_STYLE,   STYLE_SOLID);
         ObjectSetInteger(0, nm, OBJPROP_WIDTH,   1);
         ObjectSetInteger(0, nm, OBJPROP_BACK,    true);
         ObjectSetInteger(0, nm, OBJPROP_FILL,    true);
         // Simuler transparence via RGBA
         color fillColor = ColorWithAlpha(boxColor, InpOB_Transparency);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, fillColor);

         //--- Label
         string lbName = nm + "_LBL";
         string lbText = g_OB[i].isBullish ? "Bullish OB" : "Bearish OB";
         if(ObjectCreate(0, lbName, OBJ_TEXT, 0, g_OB[i].time, g_OB[i].high)) {
            ObjectSetString(0,  lbName, OBJPROP_TEXT, lbText);
            ObjectSetInteger(0, lbName, OBJPROP_COLOR, boxColor);
            ObjectSetInteger(0, lbName, OBJPROP_FONTSIZE, 7);
            ObjectSetString(0,  lbName, OBJPROP_FONT, "Arial Bold");
         }
      }
   }
}

//--- Dessiner Fair Value Gaps
void DrawFairValueGaps() {
   if(!InpUseFVG) return;

   ObjectsDeleteAll(0, "FVG_", 0, OBJ_RECTANGLE);

   datetime currentTime = TimeCurrent();
   datetime futureTime  = currentTime + PeriodSeconds(InpTF_Entry) * 20;

   for(int i = 0; i < ArraySize(g_FVG); i++) {
      if(g_FVG[i].isFilled) continue;

      color  fvgColor = g_FVG[i].isBullish ? InpFVG_BullColor : InpFVG_BearColor;
      string nm       = g_FVG[i].objName;

      if(ObjectCreate(0, nm, OBJ_RECTANGLE, 0,
                      g_FVG[i].time, g_FVG[i].high,
                      futureTime,    g_FVG[i].low)) {
         color fillCol = ColorWithAlpha(fvgColor, 40);
         ObjectSetInteger(0, nm, OBJPROP_COLOR,  fillCol);
         ObjectSetInteger(0, nm, OBJPROP_BACK,   true);
         ObjectSetInteger(0, nm, OBJPROP_FILL,   true);
         ObjectSetInteger(0, nm, OBJPROP_STYLE,  STYLE_DOT);

         string lbName = nm + "_LBL";
         if(ObjectCreate(0, lbName, OBJ_TEXT, 0, g_FVG[i].time, g_FVG[i].high)) {
            ObjectSetString(0,  lbName, OBJPROP_TEXT, "FVG");
            ObjectSetInteger(0, lbName, OBJPROP_COLOR, fvgColor);
            ObjectSetInteger(0, lbName, OBJPROP_FONTSIZE, 7);
         }
      }
   }
}

//--- Dessiner Supply & Demand
void DrawSupplyDemand() {
   if(!InpUseSnD) return;

   ObjectsDeleteAll(0, "SD_", 0, OBJ_RECTANGLE);

   for(int i = 0; i < ArraySize(g_SnD); i++) {
      if(!g_SnD[i].isActive) continue;

      color  zoneColor = g_SnD[i].isSupply ? InpSupply_Color : InpDemand_Color;
      string nm        = g_SnD[i].objName;

      if(ObjectCreate(0, nm, OBJ_RECTANGLE, 0,
                      g_SnD[i].startTime, g_SnD[i].high,
                      g_SnD[i].endTime,   g_SnD[i].low)) {
         color fillCol = ColorWithAlpha(zoneColor, 60);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, fillCol);
         ObjectSetInteger(0, nm, OBJPROP_BACK,  true);
         ObjectSetInteger(0, nm, OBJPROP_FILL,  true);
         ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, nm, OBJPROP_WIDTH, 2);

         string lbName = nm + "_LBL";
         if(ObjectCreate(0, lbName, OBJ_TEXT, 0, g_SnD[i].startTime, g_SnD[i].high)) {
            ObjectSetString(0,  lbName, OBJPROP_TEXT, g_SnD[i].isSupply ? "SUPPLY" : "DEMAND");
            ObjectSetInteger(0, lbName, OBJPROP_COLOR, zoneColor);
            ObjectSetInteger(0, lbName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0,  lbName, OBJPROP_FONT, "Arial Bold");
         }
      }
   }
}

//--- Dessiner Niveaux de Liquidité
void DrawLiquidityLevels() {
   if(!InpUseLiquidity) return;

   ObjectsDeleteAll(0, "LIQ_", 0, OBJ_TREND);

   datetime startTime = iTime(_Symbol, InpTF_Setup, InpLiq_Lookback);
   datetime endTime   = TimeCurrent() + PeriodSeconds(InpTF_Entry) * 20;

   for(int i = 0; i < ArraySize(g_Liq); i++) {
      string nm = g_Liq[i].objName;
      if(ObjectCreate(0, nm, OBJ_TREND, 0,
                      g_Liq[i].time, g_Liq[i].level,
                      endTime,        g_Liq[i].level)) {
         ObjectSetInteger(0, nm, OBJPROP_COLOR, InpLiq_Color);
         ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, true);

         string lbName = nm + "_LBL";
         if(ObjectCreate(0, lbName, OBJ_TEXT, 0, endTime - PeriodSeconds(InpTF_Entry)*5, g_Liq[i].level)) {
            string txt = g_Liq[i].isBSL ? "BSL" : "SSL";
            ObjectSetString(0,  lbName, OBJPROP_TEXT, txt);
            ObjectSetInteger(0, lbName, OBJPROP_COLOR, InpLiq_Color);
            ObjectSetInteger(0, lbName, OBJPROP_FONTSIZE, 7);
         }
      }
   }
}

//--- Dessiner Structure BOS/CHoCH
void DrawStructure() {
   // Structure lines drawn in DetectStructure
}

void DrawStructureLine(string name, datetime t1, double p1, datetime t2, double p2, color col, string lbl) {
   ObjectsDeleteAll(0, name, 0, OBJ_TREND);
   if(ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2)) {
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);

      string lbName = name + "_LBL";
      if(ObjectCreate(0, lbName, OBJ_TEXT, 0, t2, p2)) {
         ObjectSetString(0,  lbName, OBJPROP_TEXT, lbl);
         ObjectSetInteger(0, lbName, OBJPROP_COLOR, col);
         ObjectSetInteger(0, lbName, OBJPROP_FONTSIZE, 8);
         ObjectSetString(0,  lbName, OBJPROP_FONT, "Arial Bold");
      }
   }
}

//--- Dessiner Kill Zones
void DrawKillZones() {
   if(!InpUseKillZones) return;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   datetime today_start = StringToTime(
      IntegerToString(dt.year) + "." +
      (dt.mon < 10 ? "0" : "") + IntegerToString(dt.mon) + "." +
      (dt.day < 10 ? "0" : "") + IntegerToString(dt.day));

   //--- London Open 07:00 - 09:00
   if(InpLondonOpen) {
      datetime t1 = today_start + 7*3600;
      datetime t2 = today_start + 9*3600;
      DrawKillZoneBox("KZ_London", t1, t2, InpKZ_London_Color, "London Open");
   }

   //--- NY Open 13:00 - 15:00
   if(InpNYOpen) {
      datetime t1 = today_start + 13*3600;
      datetime t2 = today_start + 15*3600;
      DrawKillZoneBox("KZ_NewYork", t1, t2, InpKZ_NY_Color, "NY Open");
   }
}

void DrawKillZoneBox(string name, datetime t1, datetime t2, color col, string lbl) {
   double chartHigh = ChartGetDouble(0, CHART_PRICE_MAX);
   double chartLow  = ChartGetDouble(0, CHART_PRICE_MIN);

   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, chartHigh, t2, chartLow);
      color fillCol = ColorWithAlpha(col, 20);
      ObjectSetInteger(0, name, OBJPROP_COLOR, fillCol);
      ObjectSetInteger(0, name, OBJPROP_BACK,  true);
      ObjectSetInteger(0, name, OBJPROP_FILL,  true);

      string lbName = name + "_LBL";
      if(ObjectCreate(0, lbName, OBJ_TEXT, 0, t1, chartHigh)) {
         ObjectSetString(0,  lbName, OBJPROP_TEXT, lbl);
         ObjectSetInteger(0, lbName, OBJPROP_COLOR, col);
         ObjectSetInteger(0, lbName, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0,  lbName, OBJPROP_FONT, "Arial Bold");
      }
   }
}

//--- Dessiner EMAs sur graphique
void DrawEMAs() {
   // Les EMAs s'affichent via les handles iMA déjà créés
   // Pour les rendre visibles, on les active dans les paramètres du graphique
   // (Les indicateurs de fenêtre sont déjà attachés)
}

//--- Flèches de signal
void DrawSignalArrow(bool isBuy, datetime t, double price) {
   string name = "SIG_" + (isBuy ? "BUY_" : "SELL_") + IntegerToString(t);
   double arrowPrice = isBuy ? price - 10*_Point : price + 10*_Point;

   if(ObjectCreate(0, name, OBJ_ARROW, 0, t, arrowPrice)) {
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, isBuy ? 233 : 234);
      ObjectSetInteger(0, name, OBJPROP_COLOR,     isBuy ? clrLime : clrRed);
      ObjectSetInteger(0, name, OBJPROP_WIDTH,     3);
   }
}

//--- Niveaux SL/TP
void DrawTradeLevel(string name, double price, color col, string lbl) {
   datetime t1 = TimeCurrent();
   datetime t2 = TimeCurrent() + PeriodSeconds(InpTF_Entry) * 50;
   if(ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price)) {
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);

      string lbName = name + "_LBL";
      if(ObjectCreate(0, lbName, OBJ_TEXT, 0, t1, price)) {
         ObjectSetString(0,  lbName, OBJPROP_TEXT, lbl + " " + DoubleToString(price, _Digits));
         ObjectSetInteger(0, lbName, OBJPROP_COLOR, col);
         ObjectSetInteger(0, lbName, OBJPROP_FONTSIZE, 8);
      }
   }
}

//+------------------------------------------------------------------+
//|         DASHBOARD PRINCIPAL                                      |
//+------------------------------------------------------------------+
void DrawDashboard() {
   string prefix = "DASH_";

   //--- Données à afficher
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double profit  = AccountInfoDouble(ACCOUNT_PROFIT);
   int    spread  = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   double rsi_val[];
   ArraySetAsSeries(rsi_val, true);
   CopyBuffer(h_rsi, 0, 0, 2, rsi_val);
   double rsi = (ArraySize(rsi_val) > 0) ? rsi_val[1] : 0;

   double macd_main[], macd_sig[];
   ArraySetAsSeries(macd_main, true); ArraySetAsSeries(macd_sig, true);
   CopyBuffer(h_macd, 0, 0, 2, macd_main);
   CopyBuffer(h_macd, 1, 0, 2, macd_sig);
   string macdStatus = (ArraySize(macd_main)>0 && ArraySize(macd_sig)>0) ?
      (macd_main[1] > macd_sig[1] ? "↑ Haussier" : "↓ Baissier") : "---";

   int openTrades = 0;
   double totalProfit = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(g_posInfo.SelectByIndex(i) && g_posInfo.Symbol() == _Symbol && g_posInfo.Magic() == 202600) {
         openTrades++;
         totalProfit += g_posInfo.Profit();
      }
   }

   string biasText   = g_isBullBias ? "▲ HAUSSIER" : (g_isBearBias ? "▼ BAISSIER" : "◆ NEUTRE");
   color  biasColor  = g_isBullBias ? clrLime : (g_isBearBias ? clrRed : clrYellow);
   string sigText    = (g_currentSignal == SIG_BUY) ? "🟢 BUY" : (g_currentSignal == SIG_SELL) ? "🔴 SELL" : "⬛ NONE";
   color  sigColor   = (g_currentSignal == SIG_BUY) ? clrLime : (g_currentSignal == SIG_SELL) ? clrOrangeRed : clrGray;

   //--- Éléments du dashboard
   int x = InpDash_X, y = InpDash_Y;
   int lineH = 18;
   int w = 230;

   struct DashLine { string name; string text; color col; int fontSize; };
   DashLine lines[] = {
      {"T00", "┌─ SmartMoneyEA Pro ─────────┐",      clrCyan,       9},
      {"T01", "│ Symbole : " + _Symbol,               InpDash_Text,  9},
      {"T02", "│ Spread  : " + IntegerToString(spread) + " pts",  InpDash_Text, 9},
      {"T03", "├─ BIAIS 4H ─────────────────┤",      clrCyan,       9},
      {"T04", "│ Biais   : " + biasText,              biasColor,     9},
      {"T05", "├─ INDICATEURS 15min ─────────┤",      clrCyan,       9},
      {"T06", "│ RSI     : " + DoubleToString(rsi, 1), rsi>InpRSI_OB ? clrRed : rsi<InpRSI_OS ? clrLime : InpDash_Text, 9},
      {"T07", "│ MACD    : " + macdStatus,            clrDodgerBlue, 9},
      {"T08", "├─ SIGNAL ───────────────────┤",       clrCyan,       9},
      {"T09", "│ Signal  : " + sigText,               sigColor,      9},
      {"T10", "├─ POSITIONS ────────────────┤",       clrCyan,       9},
      {"T11", "│ Ouverts : " + IntegerToString(openTrades), InpDash_Text, 9},
      {"T12", "│ P&L pos : " + DoubleToString(totalProfit, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY), totalProfit >= 0 ? clrLime : clrRed, 9},
      {"T13", "├─ COMPTE ───────────────────┤",       clrCyan,       9},
      {"T14", "│ Balance : " + DoubleToString(balance, 2), InpDash_Text, 9},
      {"T15", "│ Equity  : " + DoubleToString(equity, 2),  equity >= balance ? clrLime : clrOrange, 9},
      {"T16", "├─ SMC ──────────────────────┤",       clrCyan,       9},
      {"T17", "│ OB act. : " + IntegerToString(ArraySize(g_OB)),  InpDash_Text, 9},
      {"T18", "│ FVG act.: " + IntegerToString(ArraySize(g_FVG)), InpDash_Text, 9},
      {"T19", "│ Liq.    : " + IntegerToString(ArraySize(g_Liq)), InpDash_Text, 9},
      {"T20", "│ S&D     : " + IntegerToString(ArraySize(g_SnD)), InpDash_Text, 9},
      {"T21", "└────────────────────────────┘",       clrCyan,       9}
   };

   int numLines = ArraySize(lines);
   for(int k = 0; k < numLines; k++) {
      string nm = prefix + lines[k].name;
      if(ObjectFind(0, nm) < 0)
         ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, nm, OBJPROP_XDISTANCE,  x);
      ObjectSetInteger(0, nm, OBJPROP_YDISTANCE,  y + k * lineH);
      ObjectSetInteger(0, nm, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
      ObjectSetString(0,  nm, OBJPROP_TEXT,       lines[k].text);
      ObjectSetInteger(0, nm, OBJPROP_COLOR,      lines[k].col);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE,   lines[k].fontSize);
      ObjectSetString(0,  nm, OBJPROP_FONT,       "Courier New");
      ObjectSetInteger(0, nm, OBJPROP_BACK,       false);
   }
}

//+------------------------------------------------------------------+
//|         UTILITAIRES                                              |
//+------------------------------------------------------------------+

color ColorWithAlpha(color col, uchar alpha) {
   // Retourner la couleur avec transparence simulée (mélange avec fond sombre)
   uchar r = (uchar)((col >> 16) & 0xFF);
   uchar g_c = (uchar)((col >> 8)  & 0xFF);
   uchar b = (uchar)(col & 0xFF);
   // Mélanger avec noir selon alpha (0=transparent, 255=opaque)
   uchar nr = (uchar)(r * alpha / 255);
   uchar ng = (uchar)(g_c * alpha / 255);
   uchar nb = (uchar)(b * alpha / 255);
   return (color)((nr << 16) | (ng << 8) | nb);
}

void CleanupAllObjects() {
   string prefixes[] = {"OB_", "FVG_", "SD_", "LIQ_", "BOS_", "CHoCH_",
                        "SIG_", "DASH_", "KZ_", "TT_", "TB_", "SL_", "TP_"};
   for(int p = 0; p < ArraySize(prefixes); p++) {
      ObjectsDeleteAll(0, prefixes[p]);
   }
}

//+------------------------------------------------------------------+
//|         ÉVÉNEMENTS GRAPHIQUE                                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam) {
   // Permettre interaction utilisateur si nécessaire
}

//+------------------------------------------------------------------+
//|         OnTradeTransaction                                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                         const MqlTradeRequest& request,
                         const MqlTradeResult& result) {
   //--- Log des transactions importantes
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL) {
         Print("SmartMoneyEA Transaction: ", EnumToString(trans.deal_type),
               " | Vol: ", trans.volume, " | Prix: ", trans.price);
      }
   }
}

//+------------------------------------------------------------------+
//|         FIN DE L'EA                                             |
//+------------------------------------------------------------------+
