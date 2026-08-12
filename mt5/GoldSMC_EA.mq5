//+------------------------------------------------------------------+
//| GoldSMC_EA.mq5                                                   |
//| EA Or — XAUUSD H1                                                |
//| Stratégie : OB+BOS + EMA multi-TF + filtre ATR range + spread    |
//| Version 5.0 — Détection régime marché W1 + TP Partiel            |
//| Architecture v5 :                                                 |
//|   - Régime auto W1 (EMA50/200) : BULL / BEAR / TRANSITION        |
//|   - BuyBiasOnly supprimé → remplacé par régime auto              |
//|   - TP partiel à RR=1.5 (50% lot) puis trailing vers RR=3.0      |
//|   - Tous les fixes v4 conservés intégralement                     |
//| Historique : v2 base + v3 fixes + v4 production + v5 régime      |
//+------------------------------------------------------------------+
#property copyright "TradBOT — GoldSMC v5"
#property version   "5.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| ENUM RÉGIME MARCHÉ                                                |
//+------------------------------------------------------------------+
enum EMarketRegime
{
   REGIME_BULL       = 0,   // Marché haussier
   REGIME_BEAR       = 1,   // Marché baissier
   REGIME_TRANSITION = 2    // Transition / indécis
};

//+------------------------------------------------------------------+
//| PARAMÈTRES D'ENTRÉE                                               |
//+------------------------------------------------------------------+

input group "=== RISQUE ==="
input double InpLotSize          = 0.01;   // Taille du lot (fixe si pas risk-based)
input bool   UseMinLotOnly       = true;   // Forcer lot minimum
input bool   UseRiskBasedLot     = false;  // Lot selon % risque / distance SL
input double RiskPercentPerTrade = 1.0;    // % equity risqué par trade
input double MaxRiskPerTradePct  = 3.0;    // Hard cap : skip si minLot risque > X% equity
input double SL_ATRMult          = 1.5;    // SL = X * ATR(14) — optimal OOS (1.8 dégradait BULL 2024-2025)
input double MaxDailyLossPct     = 5.0;    // Perte max journalière (% equity)
input double MaxDrawdownPct      = 30.0;   // Drawdown max depuis pic (%)
input bool   DisableBreakerInTester = true; // Backtest : CB désactivé

input group "=== REGIME MARCHE (W1) ==="
input bool   UseRegimeFilter      = true;   // Activer détection régime W1
input bool   UseMonthlyFilter     = true;   // Filtre EMA50 mensuel — réduit lot si baissier
input double RegimeBullThreshPct  = 0.5;    // EMA50 > EMA200 * (1+X%) = BULL
input double RegimeBearThreshPct  = 0.5;    // EMA50 < EMA200 * (1-X%) = BEAR
input bool   TradeInTransition    = true;   // Trader en régime TRANSITION
input double TransitionLotPct    = 0.3;    // Réduire lot à X% en TRANSITION — BULL conservative

input group "=== TP PARTIEL ==="
input bool   UsePartialTP         = true;   // Activer TP partiel (50% à TP1)
input double TP_RR_Partial        = 1.5;    // Fermer 50% à ce RR (TP1) — optimal OOS
input double TP_RR_Final          = 3.0;    // Fermer reste à ce RR (TP2)

input group "=== FILTRES ENTRÉE ==="
input int    ATR_Period          = 14;     // Période ATR
input double ATR_RangeFilterMult = 0.6;    // ATR < MA20 * X => range, skip — optimal
input int    ATR_MAPeriod        = 20;     // Période MA de l'ATR
input int    EMA_Fast            = 9;      // EMA rapide H1
input int    EMA_Slow            = 21;     // EMA lente H1
input int    EMA_HTF_Fast        = 50;     // EMA HTF H1
input int    EMA_HTF_Slow        = 200;    // EMA HTF H1 (tendance long terme)
input int    SwingLookback       = 5;      // Lookback pivots swing (barres) — optimal

input group "=== FILTRE SPREAD (XAUUSD) ==="
input bool   UseSpreadFilter     = true;   // Filtre spread actif
input int    MaxSpreadPoints     = 350;    // XAUUSD_i spread élevé

input group "=== SESSIONS (UTC) ==="
input bool   UseSessionFilter    = true;   // Filtre sessions — désactivé auto en BULL (trend 24h)
input bool   SessionFilterBullOff= true;   // OFF en régime BULL (XAUUSD trend toute la journée)
input int    Session1_Start      = 4;      // Londres open
input int    Session1_End        = 6;      // Avant overlap
input int    Session2_Start      = 12;     // New York open
input int    Session2_End        = 16;     // Clôture NY
input int    SessionWide_Start   = 4;      // Heures larges (TRANSITION) : début
input int    SessionWide_End     = 16;     // Heures larges (TRANSITION) : fin

input group "=== GESTION POSITION ==="
input int    CooldownMinutes     = 60;     // Cooldown entre entrées (min) — optimal
input int    MaxConsecLosses     = 4;      // Pause après N pertes consécutives
input int    PauseDurationMinutes= 60;     // Durée pause (min)
input double TrailingActivateMult= 0.5;    // Activer trailing après X*SL de profit
input double TrailingLockPct     = 0.3;    // Verrouiller X% du profit max

input group "=== OB DETECTION ==="
input int    OB_LookbackBars     = 8;      // Barres à scanner pour trouver l'OB — optimal
input double OB_RetestBuffer     = 0.3;    // Extension zone retest OB (x ATR)
input bool   StrictBOS           = false;  // BOS strict (close > SH) ou relaxé (high > SH)

input group "=== SESSION BIAS (TradingAgents) ==="
input bool   UseSessionBiasFilter = false;  // Filtre Session Bias (backtest=OFF)
input string AIServerURL         = "http://127.0.0.1:8000"; // URL serveur IA
input double SessionBiasMinConf   = 0.60;   // Confiance minimum requise (0.0-1.0)
input int    SessionBiasCacheSec  = 3600;   // Cache du biais (secondes)

input group "=== MAGIC / AFFICHAGE ==="
input int    MagicNumber         = 20260523;
input bool   ShowDashboard       = true;
input bool   DebugMode           = false;

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                                |
//+------------------------------------------------------------------+
CTrade        trade;
CPositionInfo posInfo;

int g_hATR   = INVALID_HANDLE;
int g_hEMAf  = INVALID_HANDLE;
int g_hEMAs  = INVALID_HANDLE;
int g_hEMAhf = INVALID_HANDLE;
int g_hEMAhs = INVALID_HANDLE;

// Handles pour régime W1
int g_hEMA_W1_50  = INVALID_HANDLE;
int g_hEMA_W1_200 = INVALID_HANDLE;

// Handle EMA50 mensuelle (filtre tendance longue)
int g_hEMA_MN_50  = INVALID_HANDLE;

datetime g_lastEntryTime  = 0;
datetime g_pauseUntil     = 0;
int      g_consecLosses   = 0;
double   g_dailyLoss      = 0.0;
double   g_dailyStartEquity = 0.0;
datetime g_dailyLossDate  = 0;
double   g_totalLoss      = 0.0;
double   g_peakEquity     = 0.0;
bool     g_circuitBreakerTripped = false;
bool     g_dailyLimitFired      = false;  // log limite journaliere une seule fois
double   g_maxProfit      = 0.0;
double   g_openSL         = 0.0;
double   g_openEntry      = 0.0;     // v5 : prix d'entrée pour calcul TP partiel
int      g_totalTrades    = 0;
int      g_winTrades      = 0;

// OB zone fraîche — séparées Buy/Sell (fix v3 #4)
bool     g_obZoneWasOutsideBuy  = true;
bool     g_obZoneWasOutsideSell = true;

// TP Partiel state (v5)
bool     g_halfClosed     = false;   // Flag — moitié déjà fermée
double   g_slDistance      = 0.0;    // Distance SL en prix (pour calcul RR)

// Régime marché (v5)
EMarketRegime g_currentRegime = REGIME_BULL;
datetime      g_regimeUpdate  = 0;

// Session Bias filter state (TradingAgents)
int      g_sessionBias       = 0;      // 1=BUY, -1=SELL, 0=NEUTRAL
double   g_sessionBiasConf   = 0.0;
datetime g_sessionBiasUpdate = 0;

string   g_dashPrefix     = "GSMC5_";

//+------------------------------------------------------------------+
//| INIT                                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.SetAsyncMode(false);

   // Indicateurs H1
   g_hATR   = iATR(_Symbol, PERIOD_H1, ATR_Period);
   g_hEMAf  = iMA(_Symbol,  PERIOD_H1, EMA_Fast,     0, MODE_EMA, PRICE_CLOSE);
   g_hEMAs  = iMA(_Symbol,  PERIOD_H1, EMA_Slow,     0, MODE_EMA, PRICE_CLOSE);
   g_hEMAhf = iMA(_Symbol,  PERIOD_H1, EMA_HTF_Fast,  0, MODE_EMA, PRICE_CLOSE);
   g_hEMAhs = iMA(_Symbol,  PERIOD_H1, EMA_HTF_Slow,  0, MODE_EMA, PRICE_CLOSE);

   // Indicateurs W1 pour régime (v5)
   g_hEMA_W1_50  = iMA(_Symbol, PERIOD_W1, 50,  0, MODE_EMA, PRICE_CLOSE);
   g_hEMA_W1_200 = iMA(_Symbol, PERIOD_W1, 200, 0, MODE_EMA, PRICE_CLOSE);
   // EMA50 mensuelle pour filtre tendance longue (v5 fix)
   g_hEMA_MN_50  = iMA(_Symbol, PERIOD_MN1, 50, 0, MODE_EMA, PRICE_CLOSE);

   if(g_hATR   == INVALID_HANDLE || g_hEMAf  == INVALID_HANDLE ||
      g_hEMAs  == INVALID_HANDLE || g_hEMAhf == INVALID_HANDLE ||
      g_hEMAhs == INVALID_HANDLE)
   {
      Print("[GoldSMC v5] ERREUR : création indicateurs H1 impossible");
      return INIT_FAILED;
   }

   if(g_hEMA_W1_50 == INVALID_HANDLE || g_hEMA_W1_200 == INVALID_HANDLE)
   {
      Print("[GoldSMC v5] ERREUR : création indicateurs W1 impossible");
      return INIT_FAILED;
   }

   g_peakEquity       = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dailyStartEquity = g_peakEquity;
   g_dailyLossDate    = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   bool inTester = (bool)MQLInfoInteger(MQL_TESTER);
   Print("======== GoldSMC EA v5.00 ========");
   Print("SL=", SL_ATRMult, "xATR | TP1(RR)=", TP_RR_Partial,
         " | TP2(RR)=", TP_RR_Final,
         " | PartialTP=", (UsePartialTP ? "OUI" : "NON"));
   Print("RegimeFilter=", (UseRegimeFilter ? "OUI" : "NON"),
         " | Bull>", RegimeBullThreshPct, "% | Bear<", RegimeBearThreshPct, "%",
         " | Transition=", (TradeInTransition ? "OUI" : "NON"),
         " (lot ", DoubleToString(TransitionLotPct*100,0), "%)");
   Print("RiskLot=", (UseRiskBasedLot ? "OUI" : "NON"),
         " | Risk%=", RiskPercentPerTrade);
   Print("Tester=", (inTester ? "OUI" : "NON"),
         " | CB=", (inTester && DisableBreakerInTester ? "OFF(test)" : "ON"),
         " | MaxDD=", MaxDrawdownPct, "%",
         " | Equity=$", DoubleToString(g_peakEquity, 2));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(g_hATR);
   IndicatorRelease(g_hEMAf);
   IndicatorRelease(g_hEMAs);
   IndicatorRelease(g_hEMAhf);
   IndicatorRelease(g_hEMAhs);
   IndicatorRelease(g_hEMA_W1_50);
   IndicatorRelease(g_hEMA_W1_200);
   IndicatorRelease(g_hEMA_MN_50);
   ObjectsDeleteAll(0, g_dashPrefix);

   Print("[GoldSMC v5] Deinit | Trades=", g_totalTrades,
         " | Wins=", g_winTrades,
         " | WR=", (g_totalTrades > 0 ? DoubleToString(100.0*g_winTrades/g_totalTrades, 1) : "0"), "%",
         " | PerteTotale=$", DoubleToString(g_totalLoss, 2));
}

//+------------------------------------------------------------------+
//| DÉTECTION RÉGIME MARCHÉ (W1) — Coeur de v5                       |
//+------------------------------------------------------------------+
EMarketRegime DetectMarketRegime()
{
   if(!UseRegimeFilter) return REGIME_BULL;  // fallback v4 = haussier

   double ema50Buf[], ema200Buf[];
   ArraySetAsSeries(ema50Buf, true);
   ArraySetAsSeries(ema200Buf, true);

   // On lit 2 valeurs pour avoir la bougie fermée (index 1) et la courante
   if(CopyBuffer(g_hEMA_W1_50,  0, 0, 2, ema50Buf)  < 2) return g_currentRegime;
   if(CopyBuffer(g_hEMA_W1_200, 0, 0, 2, ema200Buf) < 2) return g_currentRegime;

   double emaW1_50  = ema50Buf[1];   // Dernière bougie W1 fermée
   double emaW1_200 = ema200Buf[1];

   if(emaW1_200 <= 0.0) return g_currentRegime;

   double bullThresh = emaW1_200 * (1.0 + RegimeBullThreshPct / 100.0);
   double bearThresh = emaW1_200 * (1.0 - RegimeBearThreshPct / 100.0);

   EMarketRegime newRegime;
   if(emaW1_50 > bullThresh)
      newRegime = REGIME_BULL;
   else if(emaW1_50 < bearThresh)
      newRegime = REGIME_BEAR;
   else
      newRegime = REGIME_TRANSITION;

   // Log changement de régime
   if(newRegime != g_currentRegime)
   {
      string regimeNames[] = {"BULL", "BEAR", "TRANSITION"};
      Print(StringFormat("[GoldSMC v5] REGIME CHANGE : %s -> %s | EMA50W1=%.2f EMA200W1=%.2f",
            regimeNames[(int)g_currentRegime], regimeNames[(int)newRegime],
            emaW1_50, emaW1_200));
   }

   return newRegime;
}

string RegimeToString(EMarketRegime regime)
{
   switch(regime)
   {
      case REGIME_BULL:       return "BULL";
      case REGIME_BEAR:       return "BEAR";
      case REGIME_TRANSITION: return "TRANSITION";
   }
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| TICK — exécuté sur chaque tick                                    |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsTradeAllowed()) return;

   ResetDailyLoss();

   // Mise à jour régime — toutes les 5 minutes pour ne pas surcharger
   if(TimeCurrent() - g_regimeUpdate > 300)
   {
      g_currentRegime = DetectMarketRegime();
      g_regimeUpdate  = TimeCurrent();
   }

   ManageOpenPosition();

   if(ShowDashboard) UpdateDashboard();

   // Vérifications préalables
   if(!CanEnterNewTrade()) return;
   if(!PassSpreadFilter()) return;
   if(!IsSessionAllowed()) return;

   // Lire les indicateurs
   double atr;
   bool   bullLTF, bullHTF;
   if(!GetIndicatorValues(atr, bullLTF, bullHTF))
   {
      if(DebugMode) PrintOnce("[GoldSMC v5] Indicateurs pas prêts", 1800);
      return;
   }

   // Filtre ATR range
   if(!PassATRFilter(atr))
   {
      if(DebugMode) PrintOnce("[GoldSMC v5] ATR range — skip", 1800);
      return;
   }

   CheckAndEnter(atr, bullLTF, bullHTF);
}

//+------------------------------------------------------------------+
//| REMISE À ZÉRO PERTE JOURNALIÈRE                                   |
//+------------------------------------------------------------------+
void ResetDailyLoss()
{
   double eq    = AccountInfoDouble(ACCOUNT_EQUITY);
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(g_dailyLossDate != today)
   {
      if(g_dailyLoss > 0)
         Print("[GoldSMC v5] Reset journalier | Perte hier=$", DoubleToString(g_dailyLoss, 2));
      g_dailyLoss        = 0.0;
      g_dailyStartEquity = eq;
      g_dailyLossDate    = today;
      g_dailyLimitFired  = false;  // reset flag au nouveau jour
   }
   if(eq > g_peakEquity) g_peakEquity = eq;
}

//+------------------------------------------------------------------+
//| Circuit breaker DD depuis le pic d'equity                         |
//+------------------------------------------------------------------+
bool IsCircuitBreakerBlocking(double equity)
{
   if(MQLInfoInteger(MQL_TESTER) && DisableBreakerInTester) return false;
   if(g_peakEquity <= 0.0) return false;

   double ddPct = (g_peakEquity - equity) / g_peakEquity * 100.0;

   if(ddPct >= MaxDrawdownPct)
   {
      if(!g_circuitBreakerTripped)
      {
         g_circuitBreakerTripped = true;
         Print("[GoldSMC v5] Circuit breaker ACTIF | DD ", DoubleToString(ddPct, 1),
               "% >= ", DoubleToString(MaxDrawdownPct, 1),
               "% — nouvelles entrées bloquées");
      }
      return true;
   }

   // Reprise si DD redescend sous MaxDD - 5%
   if(g_circuitBreakerTripped && ddPct < (MaxDrawdownPct - 5.0))
   {
      g_circuitBreakerTripped = false;
      Print("[GoldSMC v5] Circuit breaker levé | DD=", DoubleToString(ddPct, 1), "%");
   }
   return g_circuitBreakerTripped;
}

//+------------------------------------------------------------------+
//| PEUT-ON ENTRER ?                                                  |
//+------------------------------------------------------------------+
bool CanEnterNewTrade()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(IsCircuitBreakerBlocking(equity))
      return false;

   // Limite journalière en % du capital de début de journée
   if(g_dailyStartEquity > 0.0)
   {
      double dailyDdPct = (g_dailyStartEquity - equity) / g_dailyStartEquity * 100.0;
      if(dailyDdPct >= MaxDailyLossPct)
      {
         if(DebugMode && !g_dailyLimitFired)
         {
            g_dailyLimitFired = true;
            Print(StringFormat("[GoldSMC v5] Limite journaliere %.1f%% >= %.1f%% — stop du jour",
                  dailyDdPct, MaxDailyLossPct));
         }
         return false;
      }
   }

   if(g_pauseUntil > TimeCurrent())
   {
      if(DebugMode) PrintOnce("[GoldSMC v5] Pause " + IntegerToString((int)(g_pauseUntil-TimeCurrent())) + "s", 1800);
      return false;
   }
   if(g_lastEntryTime > 0)
   {
      int elapsed = (int)(TimeCurrent() - g_lastEntryTime);
      int needed  = CooldownMinutes * 60;
      if(elapsed < needed)
      {
         if(DebugMode) PrintOnce("[GoldSMC v5] Cooldown actif", 1800);
         return false;
      }
   }
   if(HasOpenPosition())
      return false;
   return true;
}

//+------------------------------------------------------------------+
//| FILTRE SPREAD                                                     |
//+------------------------------------------------------------------+
bool PassSpreadFilter()
{
   if(!UseSpreadFilter) return true;
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= MaxSpreadPoints) return true;
   if(DebugMode)
      PrintOnce(StringFormat("[GoldSMC v5] Spread %d > max %d — skip",
                (int)spread, MaxSpreadPoints), 1800);
   return false;
}

bool IsSessionAllowed()
{
   if(!UseSessionFilter) return true;

   // En régime BULL : XAUUSD trend 24h, SessionFilter contre-productif
   if(SessionFilterBullOff && g_currentRegime == REGIME_BULL) return true;

   MqlDateTime mt;
   TimeToStruct(TimeCurrent(), mt);
   int h = mt.hour;

   // En TRANSITION : heures larges 7-17h pour éviter de couper trop de signaux
   if(g_currentRegime == REGIME_TRANSITION)
      return (h >= SessionWide_Start && h < SessionWide_End);

   // En BEAR : sessions précises Londres + NY uniquement
   return (h >= Session1_Start && h < Session1_End) ||
          (h >= Session2_Start && h < Session2_End);
}

//+------------------------------------------------------------------+
//| FILTRE ATR RANGE                                                  |
//+------------------------------------------------------------------+
bool PassATRFilter(double atrCurrent)
{
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   int copied = CopyBuffer(g_hATR, 0, 1, ATR_MAPeriod, atrBuf);
   if(copied < ATR_MAPeriod) return true; // pas assez de données, on laisse passer

   double atrMa = 0.0;
   for(int i = 0; i < ATR_MAPeriod; i++) atrMa += atrBuf[i];
   atrMa /= ATR_MAPeriod;

   double seuil = atrMa * ATR_RangeFilterMult;
   if(atrCurrent < seuil)
   {
      if(DebugMode)
         PrintOnce(StringFormat("[GoldSMC v5] ATR range | ATR=%.2f < seuil=%.2f (MA=%.2f*%.1f)",
                   atrCurrent, seuil, atrMa, ATR_RangeFilterMult), 1800);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| LECTURE INDICATEURS                                               |
//+------------------------------------------------------------------+
bool GetIndicatorValues(double &atr, bool &bullLTF, bool &bullHTF)
{
   double atrBuf[], efBuf[], esBuf[], ehfBuf[], ehsBuf[];
   ArraySetAsSeries(atrBuf, true); ArraySetAsSeries(efBuf,  true);
   ArraySetAsSeries(esBuf,  true); ArraySetAsSeries(ehfBuf, true);
   ArraySetAsSeries(ehsBuf, true);

   if(CopyBuffer(g_hATR,   0, 0, 2, atrBuf)  < 2) return false;
   if(CopyBuffer(g_hEMAf,  0, 0, 2, efBuf)   < 2) return false;
   if(CopyBuffer(g_hEMAs,  0, 0, 2, esBuf)   < 2) return false;
   if(CopyBuffer(g_hEMAhf, 0, 0, 2, ehfBuf)  < 2) return false;
   if(CopyBuffer(g_hEMAhs, 0, 0, 2, ehsBuf)  < 2) return false;

   atr     = atrBuf[1];          // Barre fermée (index 1)
   bullLTF = efBuf[1]  > esBuf[1];
   bullHTF = ehfBuf[1] > ehsBuf[1];
   return (atr > 0.5);           // Sanity check : ATR > 0.5$ pour XAUUSD
}

//+------------------------------------------------------------------+
//| DÉTECTION STRUCTURE BULLISH : BOS + OB RETEST                    |
//|                                                                   |
//| Logique éprouvée v2 :                                             |
//|  1. Trouver swing low pivot (plus ancien)                         |
//|  2. Trouver swing high pivot ULTÉRIEUR au SL                      |
//|  3. BOS : close[1] OU high[1] > swing high => cassure             |
//|  4. OB : 1ère bougie bearish dans les OB_LookbackBars barres      |
//|     précédant la cassure                                          |
//|  5. Retest : ask dans [obLow - buffer, obHigh + buffer]           |
//+------------------------------------------------------------------+
bool DetectBullishSetup(double atr, double &entryPrice, double &slPrice, double &tpPrice)
{
   int needed = MathMax(SwingLookback * 2 + OB_LookbackBars + 10, 50);

   double hi[], lo[], cl[], op[];
   ArraySetAsSeries(hi, true); ArraySetAsSeries(lo, true);
   ArraySetAsSeries(cl, true); ArraySetAsSeries(op, true);

   if(CopyHigh (_Symbol, PERIOD_H1, 0, needed, hi) < needed) return false;
   if(CopyLow  (_Symbol, PERIOD_H1, 0, needed, lo) < needed) return false;
   if(CopyClose(_Symbol, PERIOD_H1, 0, needed, cl) < needed) return false;
   if(CopyOpen (_Symbol, PERIOD_H1, 0, needed, op) < needed) return false;

   int lb = SwingLookback;

   // -- 1. Recherche Swing Low (pivot bas)
   int   slBar   = -1;
   double slPrx  = 0.0;
   for(int i = lb + 2; i < needed - lb; i++)
   {
      bool pivot = true;
      for(int j = 1; j <= lb && pivot; j++)
         if(lo[i] >= lo[i-j] || lo[i] >= lo[i+j]) pivot = false;
      if(pivot) { slBar = i; slPrx = lo[i]; break; }
   }
   if(slBar < 0)
   {
      if(DebugMode) PrintOnce("[GoldSMC v5] BUY : aucun Swing Low trouvé", 1800);
      return false;
   }

   // -- 2. Recherche Swing High après le SL (indice < slBar)
   int   shBar  = -1;
   double shPrx = 0.0;
   for(int i = lb + 2; i < slBar - lb; i++)
   {
      bool pivot = true;
      for(int j = 1; j <= lb && pivot; j++)
         if(hi[i] <= hi[i-j] || hi[i] <= hi[i+j]) pivot = false;
      if(pivot) { shBar = i; shPrx = hi[i]; break; }
   }
   if(shBar < 0)
   {
      if(DebugMode) PrintOnce("[GoldSMC v5] BUY : aucun Swing High trouvé après SL", 1800);
      return false;
   }

   // -- 3. BOS : la barre [1] (dernière fermée) casse au-dessus du SH
   bool bos = StrictBOS ? (cl[1] > shPrx) : (hi[1] > shPrx);
   if(!bos)
   {
      if(DebugMode)
         PrintOnce(StringFormat("[GoldSMC v5] BUY : pas de BOS | hi[1]=%.2f SH=%.2f", hi[1], shPrx), 1800);
      return false;
   }

   // -- 4. Order Block : 1ère bougie BEARISH dans les X barres avant BOS
   int   obBar  = -1;
   double obHi  = 0.0, obLo = 0.0;
   int   searchStart = shBar + 1;
   int   searchEnd   = MathMin(shBar + OB_LookbackBars + 1, needed - 1);

   for(int i = searchStart; i < searchEnd; i++)
   {
      if(cl[i] < op[i])   // Bougie bearish = OB bullish
      {
         obBar = i; obHi = hi[i]; obLo = lo[i];
         break;
      }
   }

   // Fallback : si aucune bearish, prendre la dernière bougie avant le SH
   if(obBar < 0 && shBar + 1 < needed)
   {
      obBar = shBar + 1;
      obHi  = hi[obBar];
      obLo  = lo[obBar];
   }
   if(obBar < 0) return false;

   // -- 5. Retest : ask actuel dans la zone OB étendue
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double buf    = atr * OB_RetestBuffer;
   double zoneHi = obHi + buf;
   double zoneLo = MathMax(obLo - buf, slPrx); // ne pas descendre sous le SL structure

   bool inZone = (ask >= zoneLo && ask <= zoneHi);
   if(!inZone)
   {
      g_obZoneWasOutsideBuy = true;  // Fix v3 #4 : variable séparée Buy
      if(DebugMode)
         PrintOnce(StringFormat("[GoldSMC v5] BUY : ask=%.2f hors zone OB [%.2f-%.2f]",
                   ask, zoneLo, zoneHi), 1800);
      return false;
   }
   // Exiger touche fraîche (prix était hors zone avant)
   if(!g_obZoneWasOutsideBuy)
   {
      PrintOnce("[GoldSMC v5] BUY : prix déjà dans zone OB — attente touche fraîche", 1800);
      return false;
   }
   g_obZoneWasOutsideBuy = false;

   // -- 6. Calcul SL / TP
   double rawSL = ask - atr * SL_ATRMult;

   // SL ne peut pas être au-dessus du swing low de structure
   rawSL = MathMin(rawSL, slPrx - atr * 0.1);

   // SL ne peut pas être au-dessus de l'entrée
   if(rawSL >= ask)
   {
      if(DebugMode) Print("[GoldSMC v5] BUY : SL incohérent (SL >= ask), skip");
      return false;
   }

   double slDist = ask - rawSL;
   double tpRR   = UsePartialTP ? TP_RR_Final : TP_RR_Partial;
   double rawTP  = ask + slDist * tpRR;

   // Normaliser aux digits du symbole
   int    dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   entryPrice = NormalizeDouble(ask,    dg);
   slPrice    = NormalizeDouble(rawSL,  dg);
   tpPrice    = NormalizeDouble(rawTP,  dg);

   // Vérification min distance broker
   double minStop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if((entryPrice - slPrice) < minStop || (tpPrice - entryPrice) < minStop)
   {
      if(DebugMode) Print("[GoldSMC v5] BUY : distances SL/TP trop petites vs broker minimum");
      return false;
   }

   if(DebugMode)
      Print(StringFormat("[GoldSMC v5] BUY setup | SL=%.2f(bar%d) SH=%.2f(bar%d) OB[%.2f-%.2f] ask=%.2f",
            slPrx, slBar, shPrx, shBar, obLo, obHi, ask));
   return true;
}

//+------------------------------------------------------------------+
//| DÉTECTION STRUCTURE BEARISH : BOS + OB RETEST                    |
//+------------------------------------------------------------------+
bool DetectBearishSetup(double atr, double &entryPrice, double &slPrice, double &tpPrice)
{
   int needed = MathMax(SwingLookback * 2 + OB_LookbackBars + 10, 50);

   double hi[], lo[], cl[], op[];
   ArraySetAsSeries(hi, true); ArraySetAsSeries(lo, true);
   ArraySetAsSeries(cl, true); ArraySetAsSeries(op, true);

   if(CopyHigh (_Symbol, PERIOD_H1, 0, needed, hi) < needed) return false;
   if(CopyLow  (_Symbol, PERIOD_H1, 0, needed, lo) < needed) return false;
   if(CopyClose(_Symbol, PERIOD_H1, 0, needed, cl) < needed) return false;
   if(CopyOpen (_Symbol, PERIOD_H1, 0, needed, op) < needed) return false;

   int lb = SwingLookback;

   // Swing High pivot
   int shBar = -1; double shPrx = 0.0;
   for(int i = lb + 2; i < needed - lb; i++)
   {
      bool pivot = true;
      for(int j = 1; j <= lb && pivot; j++)
         if(hi[i] <= hi[i-j] || hi[i] <= hi[i+j]) pivot = false;
      if(pivot) { shBar = i; shPrx = hi[i]; break; }
   }
   if(shBar < 0) return false;

   // Swing Low après le SH
   int slBar = -1; double slPrx = 0.0;
   for(int i = lb + 2; i < shBar - lb; i++)
   {
      bool pivot = true;
      for(int j = 1; j <= lb && pivot; j++)
         if(lo[i] >= lo[i-j] || lo[i] >= lo[i+j]) pivot = false;
      if(pivot) { slBar = i; slPrx = lo[i]; break; }
   }
   if(slBar < 0) return false;

   // BOS bearish
   bool bos = StrictBOS ? (cl[1] < slPrx) : (lo[1] < slPrx);
   if(!bos) return false;

   // OB bearish : bougie bullish avant le SL structure
   int obBar = -1; double obHi = 0.0, obLo = 0.0;
   for(int i = slBar + 1; i < MathMin(slBar + OB_LookbackBars + 1, needed - 1); i++)
   {
      if(cl[i] > op[i]) { obBar = i; obHi = hi[i]; obLo = lo[i]; break; }
   }
   if(obBar < 0 && slBar + 1 < needed)
   { obBar = slBar + 1; obHi = hi[obBar]; obLo = lo[obBar]; }
   if(obBar < 0) return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double buf = atr * OB_RetestBuffer;

   bool inZoneSell = (bid >= obLo - buf && bid <= obHi + buf);
   if(!inZoneSell)
   {
      g_obZoneWasOutsideSell = true;  // Fix v3 #4 : variable séparée Sell
      return false;
   }
   if(!g_obZoneWasOutsideSell)
   {
      PrintOnce("[GoldSMC v5] SELL : prix déjà dans zone OB — attente touche fraîche", 1800);
      return false;
   }
   g_obZoneWasOutsideSell = false;

   double rawSL = bid + atr * SL_ATRMult;
   rawSL = MathMax(rawSL, shPrx + atr * 0.1);
   if(rawSL <= bid) return false;

   double slDist = rawSL - bid;
   double tpRR   = UsePartialTP ? TP_RR_Final : TP_RR_Partial;
   double rawTP  = bid - slDist * tpRR;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   entryPrice = NormalizeDouble(bid,   dg);
   slPrice    = NormalizeDouble(rawSL, dg);
   tpPrice    = NormalizeDouble(rawTP, dg);

   double minStop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if((slPrice - entryPrice) < minStop || (entryPrice - tpPrice) < minStop) return false;

   if(DebugMode)
      Print(StringFormat("[GoldSMC v5] SELL setup | SH=%.2f(bar%d) SL=%.2f(bar%d) OB[%.2f-%.2f] bid=%.2f",
            shPrx, shBar, slPrx, slBar, obLo, obHi, bid));
   return true;
}

//+------------------------------------------------------------------+
//| LOGIQUE PRINCIPALE D'ENTRÉE — Adaptée au régime v5               |
//+------------------------------------------------------------------+
void CheckAndEnter(double atr, bool bullLTF, bool bullHTF)
{
   bool canBuy  = false;
   bool canSell = false;

   // Logique v5 : direction selon régime marché W1
   switch(g_currentRegime)
   {
      case REGIME_BULL:
         // Comme v4 : BUY si HTF haussier (EMA50>EMA200 H1)
         canBuy  = bullHTF;
         canSell = false;
         break;

      case REGIME_BEAR:
         // SYMÉTRIQUE : SELL si HTF baissier
         canBuy  = false;
         canSell = !bullHTF;
         break;

      case REGIME_TRANSITION:
         if(TradeInTransition)
         {
            // Double confirmation exigée : LTF ET HTF alignés
            canBuy  = bullLTF && bullHTF;
            canSell = !bullLTF && !bullHTF;
         }
         else
         {
            canBuy  = false;
            canSell = false;
         }
         break;
   }

   // Filtre Session Bias (TradingAgents) — live uniquement
   if(UseSessionBiasFilter && !MQLInfoInteger(MQL_TESTER))
   {
      RefreshSessionBias();
      if(g_sessionBias == 1 && canSell)  canSell = false;
      if(g_sessionBias == -1 && canBuy)  canBuy  = false;
   }

   if(DebugMode)
   {
      static datetime s_lastLog = 0;
      if(TimeCurrent() - s_lastLog > 180)
      {
         s_lastLog = TimeCurrent();
         Print(StringFormat("[GoldSMC v5] Biais | Regime=%s canBuy=%s canSell=%s bullLTF=%s bullHTF=%s ATR=%.2f",
               RegimeToString(g_currentRegime),
               (canBuy?"Y":"N"), (canSell?"Y":"N"),
               (bullLTF?"Y":"N"), (bullHTF?"Y":"N"), atr));
      }
   }

   if(canBuy)
   {
      double ep, sl, tp;
      if(DetectBullishSetup(atr, ep, sl, tp))
         ExecuteEntry("BUY", ep, sl, tp, atr);
   }
   else if(canSell)
   {
      double ep, sl, tp;
      if(DetectBearishSetup(atr, ep, sl, tp))
         ExecuteEntry("SELL", ep, sl, tp, atr);
   }
}

//+------------------------------------------------------------------+
//| CALCUL LOT — Risk-based (fix v3 #1) + régime transition          |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0.0) stepLot = minLot;
   lot = MathFloor(lot / stepLot) * stepLot;
   return MathMax(minLot, MathMin(maxLot, lot));
}

double GetLot(double entryPrice, double slPrice)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(UseMinLotOnly) return minLot;

   double lot = InpLotSize;  // default

   double slDist = MathAbs(entryPrice - slPrice);
   if(UseRiskBasedLot && slDist > 0.0 && RiskPercentPerTrade > 0.0)
   {
      double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskMoney = equity * RiskPercentPerTrade / 100.0;
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickSize > 0.0 && tickValue > 0.0)
      {
         double slTicks    = slDist / tickSize;
         double lossPerLot = slTicks * tickValue;
         if(lossPerLot > 0.0)
            lot = riskMoney / lossPerLot;
      }
   }

   // v5 : Réduction du lot en régime TRANSITION
   if(g_currentRegime == REGIME_TRANSITION && TransitionLotPct > 0.0 && TransitionLotPct < 1.0)
   {
      lot *= TransitionLotPct;
      if(DebugMode)
         PrintOnce(StringFormat("[GoldSMC v5] Lot réduit à %.0f%% (TRANSITION)", TransitionLotPct*100), 1800);
   }

   // Fallback : lot fixe si risk-based n'a pas fonctionné
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / stepLot) * stepLot;
   return NormalizeLot(MathMax(lot, minLot));
}

// Vérifie que même le lot minimum ne risque pas trop — hard cap sécurité
bool CheckRiskCap(double entryPrice, double slPrice)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double slDist  = MathAbs(entryPrice - slPrice);
   double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(tickSz <= 0 || tickVal <= 0 || equity <= 0) return true;
   double riskMinLot = (slDist / tickSz) * tickVal * minLot;
   double riskPct    = riskMinLot / equity * 100.0;
   if(riskPct > MaxRiskPerTradePct)
   {
      PrintOnce(StringFormat("[GoldSMC v5] Hard cap | minLot risk=%.1f%% > max %.1f%% — skip",
                riskPct, MaxRiskPerTradePct), 1800);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| EXÉCUTION D'UNE ENTRÉE                                            |
//+------------------------------------------------------------------+
bool ExecuteEntry(string dir, double ep, double sl, double tp, double atr)
{
   // Fix v5 : hard cap — skip si risque trop grand même au lot minimum
   if(!CheckRiskCap(ep, sl)) return false;

   // Fix v5 : filtre EMA mensuelle — si EMA50 MN en baisse, réduire lot de 50%
   bool monthlyBearish = false;
   if(UseMonthlyFilter && g_hEMA_MN_50 != INVALID_HANDLE)
   {
      double mn50cur[], mn50prev[];
      ArraySetAsSeries(mn50cur, true); ArraySetAsSeries(mn50prev, true);
      if(CopyBuffer(g_hEMA_MN_50, 0, 1, 2, mn50cur) >= 2)
         monthlyBearish = (mn50cur[0] < mn50cur[1]); // EMA50 mensuelle en baisse
   }

   double lot = GetLot(ep, sl);

   // Réduire lot de 50% si EMA mensuelle baissière et on est en BUY
   if(monthlyBearish && dir == "BUY")
   {
      lot *= 0.5;
      double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      lot = MathMax(MathFloor(lot / stepLot) * stepLot, minLot);
      PrintOnce("[GoldSMC v5] EMA50 mensuelle baissiere — lot BUY réduit 50%", 1800);
   }
   int    dg  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string comment = "GoldSMCv5_" + dir + "_" + RegimeToString(g_currentRegime);
   bool   ok   = false;

   // Fix v3 #2 : Vérification marge libre avant passage de l'ordre
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginReq  = 0.0;
   if(!OrderCalcMargin(dir == "BUY" ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                       _Symbol, lot, ep, marginReq))
      marginReq = lot * ep * 0.01; // estimation fallback 1%
   if(freeMargin < marginReq * 1.2) // 20% de marge de sécurité
   {
      Print(StringFormat("[GoldSMC v5] Marge insuffisante | Free=%.2f Req=%.2f lot=%.2f — skip",
            freeMargin, marginReq, lot));
      return false;
   }

   if(dir == "BUY")
      ok = SafeTradeBuy(lot, _Symbol, 0,
                     NormalizeDouble(sl, dg),
                     NormalizeDouble(tp, dg),
                     comment);
   else
      ok = SafeTradeSell(lot, _Symbol, 0,
                      NormalizeDouble(sl, dg),
                      NormalizeDouble(tp, dg),
                      comment);

   if(ok)
   {
      g_lastEntryTime = TimeCurrent();
      g_openSL        = sl;
      g_openEntry     = ep;
      g_slDistance     = MathAbs(ep - sl);
      g_maxProfit     = 0.0;
      g_halfClosed    = false;   // v5 : reset TP partiel flag
      g_totalTrades++;

      // Estimation profit potentiel
      double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      double slPts  = MathAbs(ep - sl);
      double tpPts  = MathAbs(tp - ep);
      double riskUSD  = slPts * lot * contractSize / MathPow(10, _Digits);
      double rewardUSD= tpPts * lot * contractSize / MathPow(10, _Digits);

      Print(StringFormat("[GoldSMC v5] %s OUVERT [%s] | EP=%.2f SL=%.2f TP=%.2f | "
                         "ATR=%.2f Lot=%.2f RR=%.1f | Risk=$%.2f Reward=$%.2f",
            dir, RegimeToString(g_currentRegime), ep, sl, tp, atr, lot, TP_RR_Final, riskUSD, rewardUSD));
      if(UsePartialTP)
         Print(StringFormat("[GoldSMC v5] TP Partiel actif | TP1(50%%)=RR%.1f TP2(50%%)=RR%.1f",
               TP_RR_Partial, TP_RR_Final));
   }
   else
   {
      int rc = (int)trade.ResultRetcode();
      Print(StringFormat("[GoldSMC v5] ÉCHEC %s | Code=%d %s | EP=%.2f SL=%.2f TP=%.2f",
            dir, rc, trade.ResultComment(), ep, sl, tp));
   }

   return ok;
}

//+------------------------------------------------------------------+
//| GESTION POSITION OUVERTE — Trailing + TP Partiel v5              |
//+------------------------------------------------------------------+
void ManageOpenPosition()
{
   if(!HasOpenPosition()) return;

   ulong ticket = GetOpenTicket();
   if(ticket == 0) return;
   if(!posInfo.SelectByTicket(ticket)) return;

   double curProfit = posInfo.Profit();
   if(curProfit > g_maxProfit) g_maxProfit = curProfit;

   double sl  = posInfo.StopLoss();
   double ep  = posInfo.PriceOpen();
   double curPrice = posInfo.PriceCurrent();
   bool   isBuy = (posInfo.PositionType() == POSITION_TYPE_BUY);
   int    dg  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // --- TP PARTIEL (v5) ---
   if(UsePartialTP && !g_halfClosed && g_slDistance > 0.0)
   {
      double tp1Distance = g_slDistance * TP_RR_Partial;
      bool   tp1Reached  = false;

      if(isBuy)
         tp1Reached = (curPrice >= ep + tp1Distance);
      else
         tp1Reached = (curPrice <= ep - tp1Distance);

      if(tp1Reached)
      {
         double currentLot = posInfo.Volume();
         double halfLot    = NormalizeLot(currentLot * 0.5);

         if(halfLot >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         {
            bool closed = trade.PositionClosePartial(ticket, halfLot);

            if(closed)
            {
               g_halfClosed = true;

               // Déplacer SL au Break Even (prix d'entrée)
               double newSL    = NormalizeDouble(ep, dg);
               double minStop2 = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
               bool   slValid  = isBuy ? (newSL < curPrice - minStop2)
                                       : (newSL > curPrice + minStop2);
               if(slValid)
               {
                  trade.PositionModify(ticket, newSL, posInfo.TakeProfit());
               }

               Print(StringFormat("[GoldSMC v5] TP1 PARTIEL | Fermé %.2f lots (50%%) à RR=%.1f | SL -> BE (%.2f)",
                     halfLot, TP_RR_Partial, ep));
            }
         }
         else
         {
            // Lot trop petit pour diviser : on marque comme fait, trailing prendra le relais
            g_halfClosed = true;
            if(DebugMode)
               Print("[GoldSMC v5] TP1 : lot trop petit pour split, trailing actif");
         }
      }
   }

   // --- TRAILING STOP ---
   if(TrailingActivateMult <= 0.0) return;

   double slDist = MathAbs(ep - g_openSL);
   if(slDist <= 0) return;

   // Activer seulement si profit > seuil (converti en USD)
   double lot2         = posInfo.Volume();
   double contractSize2 = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double profitPerPt2  = lot2 * contractSize2 / MathPow(10, _Digits);
   double slProfitUSD = slDist * profitPerPt2;
   double activateThresh = (profitPerPt2 > 0) ? slProfitUSD * TrailingActivateMult : 0;
   if(curProfit < activateThresh) return;

   // Calcul du nouveau SL en prix (trailing = verrouiller % du profit max)
   double lot          = posInfo.Volume();
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double profitPerPt  = lot * contractSize / MathPow(10, _Digits);
   if(profitPerPt <= 0) return;

   double lockProfit = g_maxProfit * TrailingLockPct;
   double lockPts    = (profitPerPt > 0) ? lockProfit / profitPerPt : 0;
   if(lockPts <= 0) return;

   double newSL;
   if(isBuy)
      newSL = ep + lockPts;
   else
      newSL = ep - lockPts;

   newSL = NormalizeDouble(newSL, dg);
   double minMove   = _Point * 10;
   double minStop3  = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   bool   tsValid   = isBuy ? (newSL < curPrice - minStop3)
                            : (newSL > curPrice + minStop3);

   bool shouldModify = tsValid && (isBuy ? (newSL > sl + minMove)
                                         : (newSL < sl - minMove));
   if(shouldModify)
   {
      if(trade.PositionModify(ticket, newSL, posInfo.TakeProfit()))
      {
         if(DebugMode)
            Print(StringFormat("[GoldSMC v5] Trailing SL %.2f -> %.2f (profit max=$%.2f)",
                  sl, newSL, g_maxProfit));
      }
   }
}

//+------------------------------------------------------------------+
//| CALLBACK TRADE — suivi P&L                                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &req,
                        const MqlTradeResult  &res)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong deal = trans.deal;
   if(!HistoryDealSelect(deal)) return;
   if(HistoryDealGetInteger(deal, DEAL_MAGIC)  != MagicNumber)    return;
   if(HistoryDealGetInteger(deal, DEAL_ENTRY)  != DEAL_ENTRY_OUT) return;

   double pnl = HistoryDealGetDouble(deal, DEAL_PROFIT)
              + HistoryDealGetDouble(deal, DEAL_SWAP)
              + HistoryDealGetDouble(deal, DEAL_COMMISSION);

   string res_str;
   if(pnl < 0.0)
   {
      double loss    = MathAbs(pnl);
      g_dailyLoss   += loss;
      g_totalLoss   += loss;
      g_consecLosses++;
      res_str = StringFormat("PERTE $%.2f | consec=%d", loss, g_consecLosses);

      if(g_consecLosses >= MaxConsecLosses)
      {
         g_pauseUntil   = TimeCurrent() + PauseDurationMinutes * 60;
         g_consecLosses = 0;
         Print(StringFormat("[GoldSMC v5] PAUSE %dmin après %d pertes consécutives",
               PauseDurationMinutes, MaxConsecLosses));
      }
   }
   else
   {
      g_consecLosses = 0;
      g_winTrades++;
      res_str = StringFormat("GAIN  $%.2f", pnl);
      // Fix v3 #5 : PAS de post-win gate
      g_obZoneWasOutsideBuy  = true;
      g_obZoneWasOutsideSell = true;
   }
   g_maxProfit  = 0.0;
   g_halfClosed = false;  // v5 : reset pour prochain trade

   Print(StringFormat("[GoldSMC v5] Trade fermé | %s | Total trades=%d WR=%.0f%%",
         res_str, g_totalTrades,
         (g_totalTrades > 0 ? 100.0*g_winTrades/g_totalTrades : 0)));
}

//+------------------------------------------------------------------+
//| SESSION BIAS (TradingAgents) — live uniquement                   |
//+------------------------------------------------------------------+
string ExtractJsonString(const string json, const string key)
{
   string search = "\"" + key + "\":\"";
   int pos = StringFind(json, search);
   if(pos < 0) return "";
   pos += StringLen(search);
   int end = StringFind(json, "\"", pos);
   if(end < 0) return "";
   return StringSubstr(json, pos, end - pos);
}

double ExtractJsonDouble(const string json, const string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(json, search);
   if(pos < 0) return 0.0;
   pos += StringLen(search);
   int end = pos;
   while(end < StringLen(json))
   {
      ushort c = StringGetCharacter(json, end);
      if(c==',' || c=='}' || c=='\n') break;
      end++;
   }
   return StringToDouble(StringSubstr(json, pos, end - pos));
}

int GetSessionBias(string symbol)
{
   if(MQLInfoInteger(MQL_TESTER)) return 0;

   string url = AIServerURL + "/session-bias?symbol=" + symbol;
   string headers = "Content-Type: application/json\r\n";
   char   reqData[], resData[];
   string resp_headers;
   int    timeout_ms = 5000;

   int code = WebRequest("GET", url, headers, timeout_ms, reqData, resData, resp_headers);
   if(code != 200)
   {
      if(DebugMode)
         PrintOnce("[SessionBias] HTTP " + IntegerToString(code) + " — NEUTRAL", 1800);
      return 0;
   }

   string json = CharArrayToString(resData);
   if(StringFind(json, "\"valid\":false") >= 0) return 0;

   double confidence = ExtractJsonDouble(json, "confidence");
   g_sessionBiasConf = confidence;
   if(confidence < SessionBiasMinConf) return 0;

   string direction = ExtractJsonString(json, "direction");
   if(direction == "BUY")  return 1;
   if(direction == "SELL") return -1;
   return 0;
}

void RefreshSessionBias()
{
   if(!UseSessionBiasFilter) return;
   if(g_sessionBiasUpdate > 0 &&
      (int)(TimeCurrent() - g_sessionBiasUpdate) < SessionBiasCacheSec)
      return;
   g_sessionBias       = GetSessionBias(_Symbol);
   g_sessionBiasUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| HELPERS                                                           |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
   if(MQLInfoInteger(MQL_TESTER))
      return (bool)MQLInfoInteger(MQL_TRADE_ALLOWED);
   return (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)
       && (bool)MQLInfoInteger(MQL_TRADE_ALLOWED);
}

bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(posInfo.SelectByIndex(i))
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == MagicNumber)
            return true;
   return false;
}

ulong GetOpenTicket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(posInfo.SelectByIndex(i))
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == MagicNumber)
            return posInfo.Ticket();
   return 0;
}

// Log throttlé par message : chaque message a son propre timer (8 slots LRU)
void PrintOnce(string msg, int intervalSec)
{
   const int SLOTS = 8;
   static string   s_msgs[8];
   static datetime s_times[8];
   static int      s_next = 0;

   datetime now = TimeCurrent();
   for(int i = 0; i < SLOTS; i++)
   {
      if(s_msgs[i] == msg)
      {
         if(now - s_times[i] < intervalSec) return;
         s_times[i] = now;
         Print(msg);
         return;
      }
   }
   // Nouveau message : écrire dans le slot suivant (LRU circulaire)
   s_msgs[s_next]  = msg;
   s_times[s_next] = now;
   s_next = (s_next + 1) % SLOTS;
   Print(msg);
}

//+------------------------------------------------------------------+
//| DASHBOARD v5 — avec régime marché                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq    = AccountInfoDouble(ACCOUNT_EQUITY);
   string inPos = HasOpenPosition() ? "EN POSITION" : "EN ATTENTE";

   double atr; bool blTF, bhTF;
   bool   atrReady = GetIndicatorValues(atr, blTF, bhTF);
   bool   atrOk    = atrReady ? PassATRFilter(atr) : false;
   bool   sesOk    = IsSessionAllowed();
   string wr       = (g_totalTrades > 0) ?
                     DoubleToString(100.0*g_winTrades/g_totalTrades, 1) + "%" : "N/A";

   double ddPct      = (g_peakEquity > 0.0) ? (g_peakEquity - eq) / g_peakEquity * 100.0 : 0.0;
   double dailyDdPct = (g_dailyStartEquity > 0.0) ? (g_dailyStartEquity - eq) / g_dailyStartEquity * 100.0 : 0.0;
   long spreadPts    = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool spreadOk     = PassSpreadFilter();

   string cbStr = (MQLInfoInteger(MQL_TESTER) && DisableBreakerInTester) ? "OFF(test)" :
                  (g_circuitBreakerTripped ? "ACTIF" : "OK");

   // Régime string
   string regStr = RegimeToString(g_currentRegime);
   string tpStr  = g_halfClosed ? "TP1 FAIT (BE)" : (UsePartialTP ? "TP1 en attente" : "OFF");

   string lns[13];
   lns[0]  = "-- GoldSMC EA v5 — XAUUSD H1 --";
   lns[1]  = StringFormat("Balance: $%.2f   Equity: $%.2f", bal, eq);
   lns[2]  = "Statut : " + inPos;
   lns[3]  = StringFormat("Regime W1 : %s", regStr);
   lns[4]  = StringFormat("DD jour: %.1f%% / %.1f%%", dailyDdPct, MaxDailyLossPct);
   lns[5]  = StringFormat("DD total: %.1f%% / %.1f%% | CB:%s", ddPct, MaxDrawdownPct, cbStr);
   lns[6]  = StringFormat("Trades: %d  |  WR: %s", g_totalTrades, wr);
   lns[7]  = StringFormat("Session: %s  |  ATR: %s  |  Spread: %d %s",
            (sesOk?"OK":"NON"), (atrOk?"OK":"NON"), (int)spreadPts, (spreadOk?"OK":"NON"));
   lns[8]  = StringFormat("Pertes consec: %d/%d | Pause: %s",
            g_consecLosses, MaxConsecLosses,
            (g_pauseUntil > TimeCurrent() ?
             IntegerToString((int)((g_pauseUntil - TimeCurrent()) / 60)) + "min" : "NON"));
   lns[9]  = StringFormat("TP Partiel: %s | TP1=RR%.1f TP2=RR%.1f",
            tpStr, TP_RR_Partial, TP_RR_Final);
   lns[10] = StringFormat("Risk: %.1f%% | Lot: risk-based=%s | Trans:%.0f%%",
            RiskPercentPerTrade, (UseRiskBasedLot?"OUI":"NON"), TransitionLotPct*100);
   lns[11] = StringFormat("ATR: %.2f  |  LTF:%s  HTF:%s",
            (atrReady?atr:0.0), (blTF?"BULL":"BEAR"), (bhTF?"BULL":"BEAR"));
   lns[12] = StringFormat("SL=%.1fxATR | Swing=%d | OB=%d bars",
            SL_ATRMult, SwingLookback, OB_LookbackBars);

   for(int i = 0; i < 13; i++)
   {
      string nm = g_dashPrefix + IntegerToString(i);
      if(ObjectFind(0, nm) < 0)
      {
         ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, nm, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
         ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, 12);
         ObjectSetInteger(0, nm, OBJPROP_FONTSIZE,  9);
         ObjectSetInteger(0, nm, OBJPROP_BACK,      false);
      }
      ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, 16 + i * 17);
      ObjectSetString (0, nm, OBJPROP_TEXT,      lns[i]);

      // Couleur par ligne
      color c = clrSilver;
      if(i == 0) c = clrGold;
      else if(i == 2 && HasOpenPosition()) c = clrLimeGreen;
      else if(i == 3)
      {
         // Régime en couleur : vert=BULL, rouge=BEAR, orange=TRANSITION
         if(g_currentRegime == REGIME_BULL) c = clrLimeGreen;
         else if(g_currentRegime == REGIME_BEAR) c = clrOrangeRed;
         else c = clrOrange;
      }
      else if(i == 4 && dailyDdPct >= MaxDailyLossPct) c = clrOrangeRed;
      else if(i == 5 && ddPct >= MaxDrawdownPct) c = clrRed;
      else if(i == 7 && !spreadOk) c = clrOrangeRed;
      else if(i == 9 && g_halfClosed) c = clrLimeGreen;

      ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   }
   ChartRedraw(0);
}
//+------------------------------------------------------------------+

