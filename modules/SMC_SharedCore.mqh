//+------------------------------------------------------------------+
//| SMC_SharedCore.mqh — Shared types, state, forward decls         |
//| Single-point definitions for cross-module dependencies           |
//+------------------------------------------------------------------+
#ifndef SMC_SHARED_CORE_MQH
#define SMC_SHARED_CORE_MQH

//+------------------------------------------------------------------+
//| TradingSignal enum (was in GOM_Graphics.mqh)                     |
//+------------------------------------------------------------------+
enum TradingSignal
{
   SIGNAL_NONE = 0,            // Aucun signal
   SIGNAL_BUY_ENTER = 1,        // Acheter maintenant
   SIGNAL_BUY_PREPARE = 2,       // Préparer à acheter
   SIGNAL_SELL_ENTER = 3,       // Vendre maintenant
   SIGNAL_SELL_PREPARE = 4,      // Préparer à vendre
   SIGNAL_EXIT_NOW = 5,         // Sortir maintenant - urgent
   SIGNAL_EXIT_SOON = 6,        // Préparer à sortir - bientôt
   SIGNAL_HOLD_LONG = 7,        // Conserver long (signal réellement faible, |v|=1)
   SIGNAL_HOLD_SHORT = 8,       // Conserver court (signal réellement faible, |v|=1)
   SIGNAL_BLOCKED_LONG = 9,     // Signal fort (GOOD/PERFECT) mais bloqué par un gate
   SIGNAL_BLOCKED_SHORT = 10    // Signal fort (GOOD/PERFECT) mais bloqué par un gate
};

//+------------------------------------------------------------------+
//| Committed signal state (no-repaint)                              |
//+------------------------------------------------------------------+
TradingSignal g_gomCommittedSignal  = SIGNAL_NONE;
int           g_gomCommittedDir     = 0;   // +1 buy, -1 sell
int           g_gomConfirmCount     = 0;   // compteur de confirmation dans la même direction
datetime      g_gomCommittedTime    = 0;
int           g_gomPendingDir       = 0;   // direction des confirmations non encore engagées
datetime      g_gomPendingTime      = 0;   // horodatage de la dernière confirmation valide

// Raison du dernier blocage BLOCKED_LONG/BLOCKED_SHORT
string g_gomBlockedReason = "";
int    g_gomUnifiedExecutionDir = 0;
string g_gomUnifiedExecutionReason = "";
bool   g_gomUnifiedEntryExecuted = false;

//+------------------------------------------------------------------+
//| Main-file globals (must precede GOM_Pipeline include)            |
//+------------------------------------------------------------------+
int atrHandle;
int emaHandle = INVALID_HANDLE;
int emaFastM1 = INVALID_HANDLE;
int emaSlowM1 = INVALID_HANDLE;
int emaFastM5 = INVALID_HANDLE;
int emaSlowM5 = INVALID_HANDLE;
int emaFastH1 = INVALID_HANDLE;
int emaSlowH1 = INVALID_HANDLE;
int atrM1 = INVALID_HANDLE;
int atrM5 = INVALID_HANDLE;
int atrH1 = INVALID_HANDLE;
int atrH4 = INVALID_HANDLE;
double g_lastSwingHigh = 0, g_lastSwingLow = 0;
datetime g_lastSwingHighTime = 0, g_lastSwingLowTime = 0;

double g_cachedBestBuyLevel  = 0.0;
double g_cachedBestSellLevel = 0.0;

#ifndef ENUM_SPIKE_CHAIN_STATE_DEFINED
#define ENUM_SPIKE_CHAIN_STATE_DEFINED
enum ENUM_SPIKE_CHAIN_STATE
{
   SPIKE_STATE_CALM = 0,
   SPIKE_STATE_PRE_SPIKE,
   SPIKE_STATE_CHAIN_ACTIVE,
   SPIKE_STATE_EXHAUSTION
};
#endif
ENUM_SPIKE_CHAIN_STATE g_spikeChainState = SPIKE_STATE_CALM;

//+------------------------------------------------------------------+
//| Swing detection struct + state (was in SMC_Universal.mq5)       |
//+------------------------------------------------------------------+
struct SwingPoint
{
   double price;
   datetime time;
   bool isHigh;
   int confirmedBar; // Barre où le swing est confirmé
};

SwingPoint swingPoints[100]; // Buffer pour stocker les SH/SL confirmés
int swingPointCount = 0;

//+------------------------------------------------------------------+
//| Pattern signal types + state (was in SMC_PatternSignals.mqh)     |
//+------------------------------------------------------------------+
#define SMCPS_MAX_PATTERNS 48

enum SMC_PATTERN_ID
{
   PAT_NONE = 0,
   PAT_BULL_ENGULFING,
   PAT_BEAR_ENGULFING,
   PAT_MORNING_STAR,
   PAT_EVENING_STAR,
   PAT_THREE_SOLDIERS,
   PAT_THREE_CROWS,
   PAT_TWEEZER_BOTTOM,
   PAT_TWEEZER_TOP,
   PAT_OB_RETEST,
   PAT_DEMAND_FLIP,
   PAT_SUPPLY_FLIP,
   PAT_BREAKER_DEMAND,
   PAT_BREAKER_SUPPLY,
   PAT_FVG_DEMAND,
   PAT_FVG_SUPPLY,
   PAT_DOUBLE_BOTTOM,
   PAT_DOUBLE_TOP,
   PAT_TRENDLINE_RETEST,
   PAT_FIB50_OB,
   PAT_ZONE_REJECTION,
   PAT_HAMMER,
   PAT_SHOOTING_STAR,
   PAT_BULL_HARAMI,
   PAT_BEAR_HARAMI,
   PAT_PIERCING_LINE,
   PAT_DARK_CLOUD_COVER,
   PAT_LIQ_SWEEP
};

struct SMCPS_Hit
{
   int              id;
   int              dirSign;
   ENUM_TIMEFRAMES  tf;
   datetime         barTime;
   double           entryLevel;
   string           name;
   int              weight;
   bool             inZone;
};

struct SMCPS_State
{
   SMCPS_Hit hits[SMCPS_MAX_PATTERNS];
   int       hitCount;
   int       bullScore;
   int       bearScore;
   double    bullWeight;
   double    bearWeight;
   int       bullStrong;
   int       bearStrong;
   string    bestName;
   int       bestDir;
   ENUM_TIMEFRAMES bestTf;
   datetime  lastScan;
   string    summary;
};

SMCPS_State g_smcps = { {}, 0, 0, 0, 0.0, 0.0, 0, 0, "", 0, PERIOD_CURRENT, 0, "" };

//+------------------------------------------------------------------+
//| Forward declarations for functions defined in main/other modules |
//+------------------------------------------------------------------+
double NormalizeSLForBroker(const string symbol, double newSL, double currentSL);
double GetMinLotForSymbol(const string symbol);
double NormalizeVolumeForSymbol(double desiredVolume);
bool   IsDirectionAllowedForBoomCrash(const string symbol, const string action);
TradingSignal GOM_CalcSignal(int verdictNum, int prevVerdictNum = 0,
                              double quality = 0, double coherence = 0);
void   GOMG_DrawCentralSignal(TradingSignal signal, string verdict, double price);
string SMCPS_TfShort(const ENUM_TIMEFRAMES tf);
double CalculateLotSize(const string symbol = "", double entryPrice = 0, double sl = 0);
double SMC_ComputeEntryProbability(const int dirSign);
double SCH1_GetATRAt(int handle, int shift);
bool   ValidateAndAdjustLimitPrice(double &entryPrice, double &stopLoss, double &takeProfit, ENUM_ORDER_TYPE orderType);
double ComputeRSI(MqlRates &rates[], int period, int index);
int    SMC_CurrentGOMQuality(const string symbol, const string direction);
bool   SMC_LowCapitalAllowsSymbol(const string symbol);
bool   SMC_SpreadAllowsEntry(const string symbol);
void   SendSR20WhatsAppSignal(const string &event, const string &symbol, const string &direction,
                              double entry, double sl, double tp, double price,
                              double sr20Level, const string &sr20Type, double atr,
                              double spikeProb, int greenBars, const string &exitReason);

string SMC_SymKey(const string s)
{
   string u = s;
   StringToUpper(u);
   StringReplace(u, " ", "");
   return u;
}

bool SMC_SameSymbol(const string a, const string b)
{
   return (SMC_SymKey(a) == SMC_SymKey(b));
}

#endif // SMC_SHARED_CORE_MQH