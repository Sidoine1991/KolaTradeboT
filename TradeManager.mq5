//+------------------------------------------------------------------+
//| TradeManager.mq5 v3 — Multi-symbole universel                   |
//| Trailing stop + re-entrée sur EMA la plus proche                 |
//| Attacher sur UN SEUL chart — gère tout le terminal               |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "3.18"
#property strict
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>

input group "=== TRAILING STOP ==="
input bool   UseTrailing            = true;   // Activer trailing stop
input double TrailActivateUSD       = 1.0;    // Activer dès que profit >= $1 USD (sécurise plus tôt)
input double TrailLockPct           = 0.30;   // Verrouiller 30% du profit max depuis pic (sécurité perte)

input group "=== SORTIE PROFIT STAGNÉ ==="
input bool   UseStagnationExit        = true;   // Couper si profit stagne puis recule (ex: $2 → pas $1)
input double StagnationTriggerUSD     = 2.0;    // Surveiller dès profit >= (USD)
input int    StagnationHoldSec        = 180;    // Temps min en zone profit (sec) — ex: 3 minutes
input double StagnationMaxGivebackUSD = 0.75;   // Recul max depuis le pic avant fermeture (ex: $2→$1.25)
input double StagnationLockMinUSD     = 1.25;   // Plancher absolu après armement (ne pas descendre à $1)
input double StagnationFlatBandUSD    = 0.35;   // Bande "stagne autour du pic" (USD)

input group "=== LIMITES GLOBALES ==="
input int    MaxGlobalPositions     = 5;      // Max positions simultanées tous symboles confondus
input bool   ReEntryIgnoreGlobal    = true;   // Re-entrée même symbole exempt de la limite globale

input group "=== RE-ENTRÉE SUR EMA ==="
input bool   UseReEntry             = true;   // Activer re-entrée automatique
input int    ReEntryMaxPerSymbol    = 3;      // Max re-entrées par position fermée
input int    ReEntryCooldownSec     = 30;     // Cooldown minimal entre tentatives (sec)
input int    EMA_Fast               = 8;      // EMA rapide M1 — 1ère cible
input int    EMA_Slow               = 21;     // EMA lente M1 — 2ème cible
input double EMATouch_Pct           = 0.5;   // Tolérance toucher EMA (% du spread)
input bool   RequireCorrectSide     = false;  // 🔧 DÉSACTIVÉ: Bloquer prix "mauvais côté EMA" (fix log)

input group "=== FILTRE RSI ==="
input int    RSI_Period             = 14;
input double RSI_SellMax            = 65.0;   // SELL bloqué si RSI > X
input double RSI_BuyMin             = 30.0;   // BUY bloqué si RSI < X

input group "=== FILTRE ==="
input int    MagicFilter            = 0;      // Magic number (0 = tous)
input int    CheckIntervalSec       = 5;      // Intervalle vérification (sec)

input group "=== AUTO SL/TP ==="
input bool   AutoAssignSLTP         = true;   // Auto-assigner SL/TP si manquants
input double MaxRiskUSD             = 3.0;    // Perte max absolue par position (USD) — fermeture marché
input double TargetProfitUSD        = 10.0;   // TP cible (USD)

input group "=== PROTECTION PROFIT (anti dégringolade) ==="
input bool   UseProfitGivebackExit  = true;   // Fermer au marché si gain → perte (sans attendre SL broker)
input double ProfitGivebackArmUSD   = 1.0;    // Actif dès qu'un pic profit >= (USD)
input double MaxGivebackFromPeakUSD = 3.0;    // Recul max depuis le pic (ex: pic $4 → coupe à $1)
input double MaxLossCapUSD          = 3.0;    // Plancher perte si déjà été en gain (ex: pas plus de -$3)
input int    MaxPositionsPerSymbol  = 2;      // Max positions gérées par symbole (évite 2 dup en perte)

input group "=== PROFIT GLOBAL ==="
input bool   UseGlobalProfitTarget  = true;   // Fermer tout si profit total >= cible
input double GlobalProfitTargetUSD  = 10.0;   // Cible profit global (USD) — somme positions MCP
input bool   GlobalProfitMCPOnly    = true;   // Ne compter que les positions magic MCP (bridge)

input group "=== SIGNAUX MCP TRADINGVIEW ==="
input bool   UseMCPSignals          = true;   // Exécuter signaux bridge/WhatsApp (pending-order)
input string AIServerURL            = "http://127.0.0.1:8000"; // URL AI server
input int    MCPPollIntervalSec     = 3;      // Intervalle poll /pending-order (GOM optimized: 3s)
input int    MCPMagicNumber         = 20260526; // Magic number ordres MCP
input double MCPEntryTolerancePct   = 0.05;  // Tolérance entrée limit (% du prix)
input bool   MCPExecuteAtMarket     = true;   // Exécuter au marché dès signal ready (recommandé)
input bool   MCPBypassConsolidation = true;   // Ne pas bloquer MCP sur filtre consolidation (GOM: TRUE)
input bool   MCPDuplicateOnce       = false;  // Dupliquer 1x la position après profit minimum (DÉSACTIVÉ — évite double position à l'ouverture)
input double MCPDuplicateMinProfit  = 2.0;    // Profit minimum (USD) avant duplication
input bool   DuplicateManualOrders  = true;   // Dupliquer aussi les ordres manuels (magic=0)
input bool   DuplicateRequireGoodPerfect = true; // GOOD ou PERFECT (vnum ±2/±3) pour dupliquer
input int    DuplicateMinGlobalStrength = 60; // Force TF global mini pour autoriser duplication
input double DuplicateMinQuality    = 60.0;   // Quality min % pour dupliquer
input double DuplicateMinCoherence  = 65.0;   // Coherence min % pour dupliquer
input int    DupProfitStableSec     = 120;    // Profit >= $2 maintenu sans rechute (sec)
input double DupMinSetupProb        = 0.45;   // Proba setup min (RDS) pour autoriser dup
input string InpPollSymbols         = "Boom 600 Index,Boom 1000 Index,Crash 600 Index,Crash 1000 Index,XAUUSD,Gold Basket";

input group "=== NOTIFICATIONS WHATSAPP ==="
input bool   UseWhatsApp            = true;   // Envoyer alertes WhatsApp
input int    WATimeoutMs            = 8000;   // Timeout requête WhatsApp (ms)

input group "=== ALIGNEMENT SIGNAL (TA + MCP) ==="
input bool   RequireSignalAlign     = false;  // 🔧 DÉSACTIVÉ: Trop de blocages (fix log)
input int    SignalCacheAgeSec      = 300;    // Durée validité cache biais (sec, 0=désactivé)
input double MinTAConfidence        = 0.55;   // Confiance TA minimum pour que le biais compte

input group "=== FILTRE CONSOLIDATION ==="
input bool   UseConsolidationFilter = false;  // GOM gère consolidation → désactiver ce filtre (GOM mode)
input int    ADX_Period             = 14;     // Période ADX
input double ADX_MinTrend           = 0;      // ADX < seuil → N/A (GOM mode: 0)
input double ConsolidationATRRatio  = 0.65;  // ATR < ATR_SMA * ratio → consolidation

input group "=== FILTRES CORRECTION (BUG FIX) ==="
input bool   UseEMAFilter           = false;  // 🔧 DÉSACTIVÉ: Bloquer prix "mauvais côté EMA" (fix log)
input double MinMLConfidence        = 50.0;   // 🔧 ABAISSÉ: 75% → 50% (fix: conf faible)
input int    MaxSignalFailCount     = 2;      // Rejeter ordre après N échecs

input group "=== GOM SCALP LOOP ==="
input bool   UseGOMScalp           = true;   // 🎯 PRINCIPAL: Coupe auto sur signal GOM opposé
input int    GOMPollIntervalSec    = 1;      // Poll /gom-verdict (1s = latence TV réduite)
input int    GOMSignalMaxAgeSec    = 45;     // Verdict GOM max âge (sec) pour trader
input bool   UseGOMAutoEntry       = true;   // Ouvrir trade si GOM GOOD/PERFECT (sans WhatsApp)
input int    GOMAutoEntryCooldownSec = 45;   // Cooldown entre 2 entrées GOM auto
input double GOMMinQuality         = 35.0;   // Quality min % pour entrée auto
input double GOMMinCoherence       = 40.0;   // Coherence min % pour entrée auto
input bool   GOMAllowStrongSimple  = true;   // Entrer si SELL/BUY fort (scores) même sans libellé GOOD
input double GOMStrongScoreGap     = 1.0;    // Écart min score_buy vs score_sell (ex: sell 5.9 buy 4.7)
input bool   GOMAllowSimpleDespiteKola = true; // Signal score fort: ignorer KOLA vide/opposé à l'entrée
input bool   GOMReEntryEnabled     = true;   // 🎯 Re-entrer quand GOM réaligne (+ follow indicators)
input int    GOMReEntryCooldownSec = 20;     // Cooldown réduit (GOM optimized: 20s)
input double GOMReEntryLot         = 0.01;   // Lot pour ré-entrée GOM
input int    GOMReEntryMaxCount    = 5;      // Max ré-entrées (GOM optimized: 5)
input bool   GOMUseGlobalTrendFilter = true; // Bloquer micro-corrections contre tendance TF Global
input int    GOMGlobalTrendMinStrength = 55; // Force mini (0-100) pour filtrer contre-tendance
input bool   GOMWaitPullbackToKola    = true; // Entrer seulement sur pullback OM (KOLA NEAR BUY/SELL)
input bool   RequireGlobalDirMatch    = true;  // ✅ Exiger que TF Global soit dans la même direction
input int    GlobalDirMinConfidence   = 70;    // Confiance TF global minimale (%) pour autoriser l'entrée
input double GlobalMinCoherencePct    = 60.0;  // Cohérence GOM minimale (%) pour autoriser l'entrée

input group "=== SETUP TV — ORDRE LIMITE ==="
input bool   UseTVSetupLimit          = true;   // Placer ordre limite depuis tableau SETUP TV
input int    TVSetupMagicNumber       = 20260527; // Magic dédié setup limit
input double TVSetupEntryTolPct       = 0.04;  // Tolérance « prix touche entry » (%)
input bool   TVSetupRequirePinBar     = false;  // Exiger PIN_BAR_BULL/BEAR dans Confirm
input bool   TVSetupBlockPlaceOnWait  = false; // false = placer la limite même si GOM WAIT (annule au touch+WAIT)
input bool   TVSetupCancelOnWaitTouch = true;  // Annuler si entry touchée + GOM WAIT
input int    TVSetupRearmCooldownSec  = 15;    // Délai après annulation avant nouveau même setup
input bool   TVSetupInferFromGOM      = true;  // Reconstruire setup si plots TV absents (KOLA+BB)
input bool   TVSetupMarketOnBreakout  = true;  // Marché si prix repasse au-dessus entry (reprise BUY)
input double TVSetupBreakoutTolPct    = 0.03;  // Tolérance breakout au-dessus entry (%)

input group "=== CHEMIN PREDICTIF + ANTI-CORRECTION ==="
input bool   ShowGOMPathCandles       = true;  // Dessiner bougies futures sur chart MT5
input int    GOMPathDrawBars          = 200;   // Nombre de bougies predites affichees
input int    GOMPathDrawRefreshSec    = 8;     // Rafraichissement affichage (sec)
input double GOMPathStepAtr           = 0.16;  // ⚠️ SYNC: Must match Pine GOM_KOLA_SIDO.pine path_step=0.16
input bool   GOMBlockCorrectionZone   = true;  // Ne pas trader pendant correction
input bool   GOMUseMicroTFCorrection  = true;  // M1/M5 contre H1 = correction
input int    GOMCorrectionPathLook    = 25;    // Barres pred_path analysees
input int    GOMCorrectionMinBars     = 7;     // Min bougies D/U opposees = correction
input double GOMMinSetupProb          = 0.40;  // Proba setup min (RDS) pour entrer

input group "=== GOM/KOLA DASHBOARD ==="
input bool   UseDashboard          = true;   // Afficher le dashboard GOM/KOLA sur le chart
input int    DashboardX            = 20;     // Distance depuis le coin (CORNER_RIGHT_UPPER)
input int    DashboardY            = 50;
input int    DashboardUpdateSec    = 5;      // Rafraîchissement dashboard (aligné TV)
input bool   DashboardLocalMTF     = true;   // Calcul MTF local si serveur sans MTF
input int    PanelWidth            = 380;
input int    RowHeight             = 28;
input int    FontSize              = 9;
input color  ColorHeaderBuy        = 0x1B5E20;
input color  ColorBuy              = 0x2E7D32;
input color  ColorNeutral          = 0x757575;
input color  ColorSell             = 0xC62828;
input color  ColorHeaderSell       = 0x8B0000;
input color  ColorBackground       = 0x1E1E1E;
input color  ColorText             = clrWhite;
input color  ColorBorder           = 0x424242;

CTrade        trade;
CPositionInfo posInfo;

bool     g_globalCloseDone = false;
datetime g_globalCloseTime = 0;

// GOM Scalp Loop
datetime g_lastGOMPoll       = 0;
int      g_lastGOMAutoVnum   = 0;
datetime g_lastGOMAutoEntry  = 0;
string   g_lastGOMVerdict    = "";
int      g_lastGOMRSI        = 50;
bool     g_gomRSIOversold    = false;
bool     g_gomRSIOverbought  = false;
int      g_lastGOMVerdictNum = 0;
string   g_lastKOLAState     = "";  // "NEAR BUY" | "NEAR SELL" | "NEUTRAL"
bool     g_isConsolidation   = false; // KOLA diverge du verdict
double   g_lastGOMQuality    = 0.0; // entry_quality %
double   g_lastGOMCoherence  = 0.0; // coherence_pct %
double   g_lastGOMScoreBuy   = 0.0;
double   g_lastGOMScoreSell  = 0.0;
string   g_lastGOMGlobalDir  = "";  // "BULL" | "BEAR" | "NEUT"
int      g_lastGOMGlobalStrength = 0; // 0-100

// Tableau SETUP TradingView (OB_BULL / OB_BEAR)
bool     g_setupValid       = false;
int      g_setupDir         = 0;      // 1=BUY limit, -1=SELL limit
double   g_setupEntry       = 0.0;
double   g_setupSL          = 0.0;
double   g_setupTP1         = 0.0;
double   g_setupTP2         = 0.0;
double   g_setupRR          = 0.0;
string   g_setupType        = "";
string   g_setupConfirm     = "";
string   g_setupKey         = "";     // détecte changement de proposition

// Ordre limite setup TV actif
ulong    g_tvSetupOrderTicket = 0;
datetime g_tvSetupPlacedAt    = 0;
bool     g_tvSetupEntryTouched = false;
datetime g_tvSetupCancelAt     = 0;
datetime g_tvSetupBreakoutDone = 0;
datetime g_tvSetupPlaceFailAt    = 0;

// Chemin predictif GOM (pred_path depuis /gom-verdict)
string   g_predPath           = "";
string   g_predPathDrawKey    = "";
int      g_predNet            = 0;
int      g_lastGOMStDir       = 0;
datetime g_lastGOMPathDraw    = 0;
double   g_lastKolaBuy        = 0.0;
double   g_lastKolaSell       = 0.0;
double   g_lastBBUp           = 0.0;
double   g_lastBBDn           = 0.0;
double   g_setupBuyProb       = 0.0;
double   g_setupSellProb      = 0.0;
double   g_setupValidProb     = 0.0;
double   g_predHitRate        = 0.0;

// ---------------------------------------------------------------------------
// WHITELIST PIPELINE — symboles validés par autonomous_pipeline.py
// Lire D:\Dev\TradBOT\data\pipeline_whitelist.json
// ---------------------------------------------------------------------------
string   g_whitelistSymbols[];
int      g_whitelistCount   = 0;
datetime g_whitelistLoadedAt = 0;
#define  WHITELIST_PATH "pipeline_whitelist.json"   // Common/Files via FILE_COMMON
#define  WHITELIST_MAX_AGE 86400   // 24h

void LoadPipelineWhitelist()
{
   // Recharger max 1x par minute
   if(g_whitelistLoadedAt > 0 && (int)(TimeCurrent() - g_whitelistLoadedAt) < 60)
      return;

   g_whitelistCount = 0;
   ArrayResize(g_whitelistSymbols, 0);

   int fh = FileOpen(WHITELIST_PATH, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(fh == INVALID_HANDLE)
   {
      // Essai chemin absolu via FileOpenW
      PrintOnce("[Whitelist] Fichier introuvable: " + WHITELIST_PATH, 300);
      return;
   }

   string content = "";
   while(!FileIsEnding(fh))
      content += FileReadString(fh);
   FileClose(fh);

   // Vérifier l'age via "generated_at" — format ISO
   // Parser les "symbol": "XXX" simplement
   int pos = 0;
   while(true)
   {
      int found = StringFind(content, "\"symbol\":", pos);
      if(found < 0) break;
      int q1 = StringFind(content, "\"", found + 9);
      if(q1 < 0) break;
      int q2 = StringFind(content, "\"", q1 + 1);
      if(q2 < 0) break;
      string sym = StringSubstr(content, q1 + 1, q2 - q1 - 1);
      if(StringLen(sym) >= 2 && StringLen(sym) <= 20)
      {
         ArrayResize(g_whitelistSymbols, g_whitelistCount + 1);
         g_whitelistSymbols[g_whitelistCount] = sym;
         g_whitelistCount++;
      }
      pos = q2 + 1;
   }

   g_whitelistLoadedAt = TimeCurrent();
   string syms = "";
   for(int i = 0; i < g_whitelistCount; i++)
      syms += (i > 0 ? "," : "") + g_whitelistSymbols[i];
   PrintOnce("[Whitelist] Chargée: " + (g_whitelistCount > 0 ? syms : "VIDE"), 300);
}

bool IsSymbolWhitelisted(const string sym)
{
   LoadPipelineWhitelist();
   if(g_whitelistCount == 0)
   {
      // Whitelist vide = pas de scan fait aujourd'hui → bloquer tout sauf symbole du chart
      return (sym == _Symbol);
   }
   for(int i = 0; i < g_whitelistCount; i++)
      if(g_whitelistSymbols[i] == sym) return true;
   return false;
}
// ---------------------------------------------------------------------------

struct DupProfitStable
{
   ulong    ticket;
   datetime armedAt;
};
DupProfitStable g_dupStable[];
int g_dupStableCount = 0;

struct GOMReEntryState
{
   bool     active;
   string   symbol;
   int      direction;    // 1=BUY -1=SELL
   double   entryPrice;
   double   stopLoss;
   double   takeProfit;
   double   lot;
   datetime closedAt;
   int      reEntryCount;
};
GOMReEntryState g_gomReEntry[];
int             g_gomReEntryCount = 0;

// --- Signaux MCP TradingView ---
struct MCPSignal
{
   bool     active;         // Signal en attente d'exécution
   bool     executed;       // Ordre passé, en surveillance
   bool     marketExec;     // execution_type market → pas attendre le prix entry
   bool     duplicated;     // 2ème jambe déjà ouverte
   string   symbol;
   int      direction;      // 1=BUY -1=SELL
   double   entryPrice;     // Niveau d'entrée précis
   double   stopLoss;
   double   takeProfit1;    // TP1
   double   lot;
   ulong    ticket;         // Ticket MT5 après exécution
   datetime receivedAt;
   bool     entryNotifSent; // Alerte "prix touche entrée" déjà envoyée
   bool     tp1NotifSent;
   bool     slNotifSent;
   string   orderId;        // UUID du pending order depuis AI server
   int      failCount;      // Nb tentatives echouees (abandon apres 3)
};

MCPSignal g_mcpSignals[];
int       g_mcpCount    = 0;
datetime  g_lastMCPPoll = 0;

// --- Cache biais TradingAgents / MCP (poll /session-bias) ---
struct SignalBias
{
   string   symbol;
   string   recommendation; // "BUY" | "SELL" | "NEUTRAL" | "HOLD"
   double   confidence;
   datetime fetchedAt;
   bool     valid;
};
SignalBias g_biasCache[];
int        g_biasCacheCount = 0;
datetime   g_lastBiasPoll   = 0;

struct SymbolState
{
   string   symbol;
   int      direction;       // 1=BUY, -1=SELL
   double   openPrice;       // Prix d'ouverture de la dernière position
   double   originalSL;      // SL de référence (recalculé à chaque re-entrée)
   double   originalTP;      // TP de référence
   double   originalLot;     // Lot original
   double   slDist;          // Distance SL initiale en prix (conservée)
   double   tpDist;          // Distance TP initiale en prix (conservée)
   double   peakProfit;      // Profit max atteint
   datetime closeTime;
   double   closePrice;
   int      reEntryCount;
   datetime lastReEntry;
   bool     waitingReEntry;
   bool     forceTrailing;   // SL/TP refusés par broker — trailing activé de force
   datetime lastReEntryFail; // Timestamp dernier échec re-entrée (anti-spam)
   datetime stagnationZoneSince;  // Début zone profit >= StagnationTriggerUSD
   datetime stagnationLastPeakTime; // Dernier nouveau pic de profit
   double   stagnationPeakUSD;    // Pic profit en zone stagnation
   bool     stagnationArmed;      // Armé après StagnationHoldSec en profit
   int      hRSI;
   int      hEMAFast;        // EMA rapide M1
   int      hEMASlow;        // EMA lente M1
   int      hADX;            // ADX M1 — filtre consolidation
   int      hATR;            // ATR M1 — filtre consolidation
};

SymbolState g_states[];
int         g_stateCount = 0;

// Tickets des positions manuelles déjà dupliquées (évite double-duplication)
ulong g_manualDupTickets[];
int   g_manualDupCount = 0;

// Pic de profit par ticket (duplicatas + trailing correct par position)
ulong  g_ticketPeakTickets[];
double g_ticketPeakUSD[];
int    g_ticketPeakCount = 0;

// --- Dashboard GOM/KOLA ---
struct GOMData {
   string symbol;
   string verdict;
   int verdict_num;
   double score_buy;
   double score_sell;
   double spike_pct;
   int rsi;
   int st_dir;
   double entry_quality;
   double coherence_pct;
   double kola_buy;
   double kola_sell;
   double current_price;
   bool valid;

   // TABLEAU 1: Multi-TF Direction + RSI
   string tf_m1_dir;
   int tf_m1_rsi;
   string tf_m5_dir;
   int tf_m5_rsi;
   string tf_m15_dir;
   int tf_m15_rsi;
   string tf_h1_dir;
   int tf_h1_rsi;
   string tf_h4_dir;
   int tf_h4_rsi;
   string tf_d1_dir;
   int tf_d1_rsi;
   string tf_w1_dir;
   int tf_w1_rsi;
   string tf_global_dir;
   int tf_global_strength;

   // TABLEAU 2: Extended Verdict Data
   double force_pts;
   string rsi_alert;
   string kola_state;

   // LIGNES: KOLA Levels
   double kola_line_1;
   double kola_line_2;

   // BOÎTES: Price Zones
   double zone_1_high;
   double zone_1_low;
   double zone_2_high;
   double zone_2_low;

   // Timestamp
   datetime capture_time;
   string   data_source;   // "TV" | "MT5"
};

datetime g_lastDashboardUpdate = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   EventSetTimer(CheckIntervalSec);
   ScanAllPositions();
   Print("[TradeManager v3.14] Actif | MCP market=", MCPExecuteAtMarket,
         " | giveback=", UseProfitGivebackExit, " maxLoss=$", MaxLossCapUSD,
         " | stagnation=", UseStagnationExit, " @$", StagnationTriggerUSD, "/", StagnationHoldSec, "s",
         " | dup=", MCPDuplicateOnce, " | profit global=$", GlobalProfitTargetUSD,
         " | EMA", EMA_Fast, "/", EMA_Slow, " | positions=", g_stateCount);
   if(UseDashboard) {
      Print("[Dashboard] Enabled - Update interval: " + IntegerToString(DashboardUpdateSec) + "s");
      RefreshDashboard();
   }
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(UseDashboard) RemoveAllDashboardObjects();
   CleanupGOMPathObjects();
   for(int i = 0; i < g_stateCount; i++)
   {
      if(g_states[i].hRSI     != INVALID_HANDLE) IndicatorRelease(g_states[i].hRSI);
      if(g_states[i].hEMAFast != INVALID_HANDLE) IndicatorRelease(g_states[i].hEMAFast);
      if(g_states[i].hEMASlow != INVALID_HANDLE) IndicatorRelease(g_states[i].hEMASlow);
      if(g_states[i].hADX     != INVALID_HANDLE) IndicatorRelease(g_states[i].hADX);
      if(g_states[i].hATR     != INVALID_HANDLE) IndicatorRelease(g_states[i].hATR);
   }
}

void OnTimer()
{
   ScanAllPositions();
   if(RequireSignalAlign)    PollSignalBias();
   if(UseGlobalProfitTarget) CheckGlobalProfit();
   if(UseProfitGivebackExit) ManageProfitGivebackExit();
   if(UseTrailing)           ManageAllTrailing();
   if(UseStagnationExit)     ManageProfitStagnationExit();
   if(UseReEntry)            CheckAllReEntries();
   if(UseMCPSignals)         PollMCPSignals();
   if(UseMCPSignals)         MonitorMCPPositions();
   if(MCPDuplicateOnce)      { UpdateDupProfitStableTracking(); MonitorManualDuplicates(); }
   if(UseGOMScalp)           PollGOMScalpVerdict();
   if(UseGOMScalp)           CheckGOMAutoEntry();
   if(UseGOMScalp)           CheckGOMReEntry();
   if(UseTVSetupLimit)       ManageTVSetupLimitOrder();
   if(ShowGOMPathCandles)    DrawGOMPathPredictedCandles();
                             DrawEntryLevels();
   if(UseDashboard)          RefreshDashboard();  // ⭐ NEW Dashboard with colored boxes
}

void OnTick()
{
   static datetime lastRun = 0;
   if(TimeCurrent() - lastRun < CheckIntervalSec) return;
   lastRun = TimeCurrent();
   ScanAllPositions();
   if(RequireSignalAlign)    PollSignalBias();
   if(UseGlobalProfitTarget) CheckGlobalProfit();
   if(UseProfitGivebackExit) ManageProfitGivebackExit();
   if(UseTrailing)           ManageAllTrailing();
   if(UseStagnationExit)     ManageProfitStagnationExit();
   if(UseReEntry)            CheckAllReEntries();
   if(UseMCPSignals)         PollMCPSignals();
   if(UseMCPSignals)         MonitorMCPPositions();
   if(MCPDuplicateOnce)      { UpdateDupProfitStableTracking(); MonitorManualDuplicates(); }
   if(UseGOMScalp)           PollGOMScalpVerdict();
   if(UseGOMScalp)           CheckGOMAutoEntry();
   if(UseGOMScalp)           CheckGOMReEntry();
   if(UseTVSetupLimit)       ManageTVSetupLimitOrder();
}

//+------------------------------------------------------------------+
//| SETUP TV — ordre limite + annulation entry touchée + GOM WAIT    |
//+------------------------------------------------------------------+
bool IsGOMVerdictWait()
{
   if(g_lastGOMVerdictNum == 0) return true;
   if(StringFind(g_lastGOMVerdict, "WAIT") >= 0) return true;
   return false;
}

//+------------------------------------------------------------------+
//| Chemin predictif — affichage MT5 + filtre zone correction        |
//+------------------------------------------------------------------+
int CalcGOMTFDirection(const ENUM_TIMEFRAMES tf)
{
   double c0 = iClose(_Symbol, tf, 0);
   double c3 = iClose(_Symbol, tf, 3);
   if(c0 <= 0 || c3 <= 0) return 0;
   double tol = c3 * 0.00008;
   if(c0 > c3 + tol) return 1;
   if(c0 < c3 - tol) return -1;
   return 0;
}

bool IsGOMCorrectionZone(const int tradeDir)
{
   if(!GOMBlockCorrectionZone || tradeDir == 0) return false;

   if(GOMUseMicroTFCorrection)
   {
      int m1 = CalcGOMTFDirection(PERIOD_M1);
      int m5 = CalcGOMTFDirection(PERIOD_M5);
      int h1 = CalcGOMTFDirection(PERIOD_H1);
      int h4 = CalcGOMTFDirection(PERIOD_H4);

      if(tradeDir == 1)
      {
         if((m1 == -1 || m5 == -1) && (h1 == 1 || h4 == 1))
         {
            PrintOnce("[GOM-Corr] Zone correction — M1/M5 baissiers vs H1/H4 haussiers", 25);
            return true;
         }
         if(g_lastGOMStDir < 0)
         {
            PrintOnce("[GOM-Corr] Zone correction — Supertrend baissier", 25);
            return true;
         }
      }
      if(tradeDir == -1)
      {
         if((m1 == 1 || m5 == 1) && (h1 == -1 || h4 == -1))
         {
            PrintOnce("[GOM-Corr] Zone correction — M1/M5 haussiers vs H1/H4 baissiers", 25);
            return true;
         }
         if(g_lastGOMStDir > 0)
         {
            PrintOnce("[GOM-Corr] Zone correction — Supertrend haussier", 25);
            return true;
         }
      }
   }

   int look = MathMin(GOMCorrectionPathLook, StringLen(g_predPath));
   if(look >= GOMCorrectionMinBars)
   {
      int u = 0, d = 0;
      for(int i = 0; i < look; i++)
      {
         ushort ch = StringGetCharacter(g_predPath, i);
         if(ch == 'U') u++;
         else if(ch == 'D') d++;
      }
      if(tradeDir == 1 && d >= GOMCorrectionMinBars && d > u)
      {
         PrintOnce(StringFormat("[GOM-Corr] Chemin predictif correction (%d D / %d U sur %d)",
               d, u, look), 25);
         return true;
      }
      if(tradeDir == -1 && u >= GOMCorrectionMinBars && u > d)
      {
         PrintOnce(StringFormat("[GOM-Corr] Chemin predictif correction (%d U / %d D sur %d)",
               u, d, look), 25);
         return true;
      }
   }

   return false;
}

void CleanupGOMPathObjects()
{
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string n = ObjectName(0, i, 0, -1);
      if(StringFind(n, "GOM_PRED_") == 0)
         ObjectDelete(0, n);
   }
}

//+------------------------------------------------------------------+
//| Symboles — forex pur vs synthétiques (Boom/Crash/XAU/Index)      |
//+------------------------------------------------------------------+
bool IsPureForexPair(const string sym)
{
   string u = sym;
   StringToUpper(u);
   if(StringFind(u, "BOOM") >= 0 || StringFind(u, "CRASH") >= 0) return false;
   if(StringFind(u, "INDEX") >= 0 || StringFind(u, "BASKET") >= 0) return false;
   if(StringFind(u, "XAU") >= 0 || StringFind(u, "GOLD") >= 0) return false;
   if(StringFind(u, "VOLATILITY") >= 0 || StringFind(u, "STEP") >= 0) return false;
   if(StringFind(u, "JUMP") >= 0 || StringFind(u, "PAIN") >= 0 || StringFind(u, "GAIN") >= 0) return false;
   return true;
}

bool IsBoomOrCrashSymbol(const string sym)
{
   string u = sym;
   StringToUpper(u);
   return (StringFind(u, "BOOM") >= 0 || StringFind(u, "CRASH") >= 0
           || StringFind(u, "PAIN") >= 0 || StringFind(u, "GAIN") >= 0);
}

bool ShouldDrawGOMPathForSymbol(const string sym)
{
   return !IsPureForexPair(sym);
}

bool IsGOMPathAlignedWithDir(const int dir)
{
   if(dir == 0 || StringLen(g_predPath) < 10) return true;
   int look = MathMin(30, StringLen(g_predPath));
   int u = 0, d = 0;
   for(int i = 0; i < look; i++)
   {
      ushort ch = StringGetCharacter(g_predPath, i);
      if(ch == 'U') u++;
      else if(ch == 'D') d++;
   }
   if(dir == 1) return (u >= d && g_predNet >= 0);
   if(dir == -1) return (d >= u && g_predNet <= 0);
   return true;
}

bool HasSetupProbForDir(const int dir)
{
   if(g_setupValidProb <= 0 && g_predHitRate <= 0) return true;
   double prob = (dir == 1) ? g_setupBuyProb : g_setupSellProb;
   if(prob <= 0) prob = g_setupValidProb;
   if(prob <= 0 && g_predHitRate > 0) prob = g_predHitRate;
   if(prob <= 0) return true;
   return prob >= GOMMinSetupProb;
}

int FindDupStableIdx(const ulong ticket)
{
   for(int i = 0; i < g_dupStableCount; i++)
      if(g_dupStable[i].ticket == ticket) return i;
   return -1;
}

void UpdateDupProfitStableTracking()
{
   for(int i = g_dupStableCount - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_dupStable[i].ticket))
      {
         for(int j = i; j < g_dupStableCount - 1; j++)
            g_dupStable[j] = g_dupStable[j + 1];
         g_dupStableCount--;
         ArrayResize(g_dupStable, g_dupStableCount);
      }
   }

   for(int pi = PositionsTotal() - 1; pi >= 0; pi--)
   {
      if(!posInfo.SelectByIndex(pi)) continue;
      if(!PositionIncludedInTrailing()) continue;
      ulong ticket = posInfo.Ticket();
      double profit = PositionNetProfit();
      int idx = FindDupStableIdx(ticket);

      if(profit < MCPDuplicateMinProfit)
      {
         if(idx >= 0)
         {
            for(int j = idx; j < g_dupStableCount - 1; j++)
               g_dupStable[j] = g_dupStable[j + 1];
            g_dupStableCount--;
            ArrayResize(g_dupStable, g_dupStableCount);
         }
         continue;
      }

      if(idx < 0)
      {
         ArrayResize(g_dupStable, g_dupStableCount + 1);
         g_dupStable[g_dupStableCount].ticket = ticket;
         g_dupStable[g_dupStableCount].armedAt = TimeCurrent();
         g_dupStableCount++;
      }
   }
}

bool HasDupProfitStable(const ulong ticket)
{
   int idx = FindDupStableIdx(ticket);
   if(idx < 0) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   if(PositionNetProfit() < MCPDuplicateMinProfit) return false;
   return ((int)(TimeCurrent() - g_dupStable[idx].armedAt) >= DupProfitStableSec);
}

void DrawGOMPathSRLevels(const datetime t0, const datetime tEnd)
{
   ObjectDelete(0, "GOM_PRED_SR_KB");
   ObjectDelete(0, "GOM_PRED_SR_KS");
   ObjectDelete(0, "GOM_PRED_SR_BBUP");
   ObjectDelete(0, "GOM_PRED_SR_BBDN");
   if(g_lastKolaBuy > 0)
   {
      ObjectCreate(0, "GOM_PRED_SR_KB", OBJ_TREND, 0, t0, g_lastKolaBuy, tEnd, g_lastKolaBuy);
      ObjectSetInteger(0, "GOM_PRED_SR_KB", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, "GOM_PRED_SR_KB", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "GOM_PRED_SR_KB", OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, "GOM_PRED_SR_KB", OBJPROP_BACK, true);
   }
   if(g_lastKolaSell > 0)
   {
      ObjectCreate(0, "GOM_PRED_SR_KS", OBJ_TREND, 0, t0, g_lastKolaSell, tEnd, g_lastKolaSell);
      ObjectSetInteger(0, "GOM_PRED_SR_KS", OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, "GOM_PRED_SR_KS", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "GOM_PRED_SR_KS", OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, "GOM_PRED_SR_KS", OBJPROP_BACK, true);
   }
   if(g_lastBBUp > 0)
   {
      ObjectCreate(0, "GOM_PRED_SR_BBUP", OBJ_TREND, 0, t0, g_lastBBUp, tEnd, g_lastBBUp);
      ObjectSetInteger(0, "GOM_PRED_SR_BBUP", OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, "GOM_PRED_SR_BBUP", OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, "GOM_PRED_SR_BBUP", OBJPROP_RAY_RIGHT, false);
   }
   if(g_lastBBDn > 0)
   {
      ObjectCreate(0, "GOM_PRED_SR_BBDN", OBJ_TREND, 0, t0, g_lastBBDn, tEnd, g_lastBBDn);
      ObjectSetInteger(0, "GOM_PRED_SR_BBDN", OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, "GOM_PRED_SR_BBDN", OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, "GOM_PRED_SR_BBDN", OBJPROP_RAY_RIGHT, false);
   }
}

//+------------------------------------------------------------------+
//| Helper : dessine une OBJ_HLINE avec texte                        |
//+------------------------------------------------------------------+
void DrawHLine(const string name, const double price, const color clr,
               const int width, const ENUM_LINE_STYLE style, const string lbl)
{
   ObjectDelete(0, name);
   if(price <= 0) return;
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      width);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      style);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ObjectSetString (0, name, OBJPROP_TEXT,       lbl);
}

//+------------------------------------------------------------------+
//| Dessine Entry OB / SL / TP + KOLA sur le chart MT5 courant      |
//+------------------------------------------------------------------+
void DrawEntryLevels()
{
   static datetime s_lastDraw = 0;
   if((int)(TimeCurrent() - s_lastDraw) < 3) return;
   s_lastDraw = TimeCurrent();

   // Niveaux KOLA — toujours affichés dès que GOM poll a des données
   DrawHLine("TM_KOLA_BUY",  g_lastKolaBuy,  clrDodgerBlue, 2, STYLE_DASH,
             StringFormat("KOLA BUY  %.5f", g_lastKolaBuy));
   DrawHLine("TM_KOLA_SELL", g_lastKolaSell, clrOrangeRed,  2, STYLE_DASH,
             StringFormat("KOLA SELL %.5f", g_lastKolaSell));

   if(g_setupValid && g_setupEntry > 0)
   {
      color cE = (g_setupDir == 1) ? clrDodgerBlue : clrOrangeRed;

      DrawHLine("TM_OB_ENTRY", g_setupEntry, cE,          3, STYLE_SOLID,
                StringFormat("ENTRY %s %.5f", g_setupType, g_setupEntry));
      DrawHLine("TM_OB_SL",    g_setupSL,    clrCrimson,  2, STYLE_DASH,
                StringFormat("SL %.5f", g_setupSL));
      DrawHLine("TM_OB_TP1",   g_setupTP1,   clrLimeGreen,2, STYLE_DASH,
                StringFormat("TP1 %.5f", g_setupTP1));
      DrawHLine("TM_OB_TP2",   g_setupTP2,   clrLimeGreen,1, STYLE_DOT,
                StringFormat("TP2 %.5f", g_setupTP2));

      // Zone OB entre Entry et SL
      ObjectDelete(0, "TM_OB_ZONE");
      if(g_setupSL > 0)
      {
         datetime t0  = iTime(_Symbol, PERIOD_CURRENT, 0);
         datetime tE  = t0 + PeriodSeconds(PERIOD_CURRENT) * 80;
         double   zH  = MathMax(g_setupEntry, g_setupSL);
         double   zL  = MathMin(g_setupEntry, g_setupSL);
         ObjectCreate(0, "TM_OB_ZONE", OBJ_RECTANGLE, 0, t0, zH, tE, zL);
         ObjectSetInteger(0, "TM_OB_ZONE", OBJPROP_COLOR, cE);
         ObjectSetInteger(0, "TM_OB_ZONE", OBJPROP_BACK,  true);
         ObjectSetInteger(0, "TM_OB_ZONE", OBJPROP_FILL,  true);
         ObjectSetInteger(0, "TM_OB_ZONE", OBJPROP_SELECTABLE, false);
      }

      // Label fixe coin haut-gauche
      ObjectDelete(0, "TM_OB_LABEL");
      ObjectCreate(0, "TM_OB_LABEL", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_CORNER,    CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_YDISTANCE, 30);
      ObjectSetString (0, "TM_OB_LABEL", OBJPROP_TEXT,
         StringFormat("%s  E:%.5f  SL:%.5f  TP1:%.5f  RR:%.1f",
            g_setupType, g_setupEntry, g_setupSL, g_setupTP1, g_setupRR));
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_COLOR,    clrWhite);
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_FONTSIZE, 10);
      ObjectSetString (0, "TM_OB_LABEL", OBJPROP_FONT,     "Arial Bold");
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_BACK,     false);
   }
   else
   {
      ObjectDelete(0, "TM_OB_ENTRY");
      ObjectDelete(0, "TM_OB_SL");
      ObjectDelete(0, "TM_OB_TP1");
      ObjectDelete(0, "TM_OB_TP2");
      ObjectDelete(0, "TM_OB_ZONE");
      ObjectDelete(0, "TM_OB_LABEL");
   }

   ChartRedraw(0);
}

void DrawGOMPathPredictedCandles()
{
   if(!ShowGOMPathCandles) return;
   if(!ShouldDrawGOMPathForSymbol(_Symbol))
   {
      CleanupGOMPathObjects();
      return;
   }

   string drawKey = g_predPath + "|" + IntegerToString(g_predNet);
   if(drawKey == g_predPathDrawKey
      && g_lastGOMPathDraw > 0
      && (int)(TimeCurrent() - g_lastGOMPathDraw) < GOMPathDrawRefreshSec)
      return;

   if(StringLen(g_predPath) < 5)
   {
      PrintOnce("[GOM-Path] pred_path absent — activer path_in_alert dans Pine + poller", 120);
      return;
   }

   CleanupGOMPathObjects();

   ENUM_TIMEFRAMES tf = PERIOD_M1;
   int nBars = MathMin(GOMPathDrawBars, StringLen(g_predPath));
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   int hAtr = iATR(_Symbol, tf, 14);
   if(hAtr == INVALID_HANDLE) return;
   if(CopyBuffer(hAtr, 0, 0, 1, atrBuf) < 1) { IndicatorRelease(hAtr); return; }
   double stepPx = atrBuf[0] * GOMPathStepAtr;
   IndicatorRelease(hAtr);
   if(stepPx <= 0) stepPx = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50;

   datetime t0 = iTime(_Symbol, tf, 0);
   int tfSec = PeriodSeconds(tf);
   if(t0 <= 0 || tfSec <= 0) return;

   double y = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(y <= 0) y = iClose(_Symbol, tf, 0);

   double minP = y, maxP = y;

   for(int i = 0; i < nBars; i++)
   {
      ushort ch = StringGetCharacter(g_predPath, i);
      int pdir = (ch == 'U') ? 1 : (ch == 'D') ? -1 : 0;
      double o = y;
      double c = y + pdir * stepPx;
      double h = MathMax(o, c) + stepPx * 0.12;
      double l = MathMin(o, c) - stepPx * 0.08;

      datetime tStart = t0 + (i * tfSec);
      datetime tEnd   = t0 + ((i + 1) * tfSec);
      datetime tMid   = tStart + tfSec / 2;

      color col = (c >= o) ? clrLimeGreen : clrCrimson;
      if(pdir == 0) col = clrOrange;

      string bodyName = "GOM_PRED_BODY_" + IntegerToString(i);
      ObjectCreate(0, bodyName, OBJ_RECTANGLE, 0, tStart, MathMax(o, c), tEnd, MathMin(o, c));
      ObjectSetInteger(0, bodyName, OBJPROP_COLOR, col);
      ObjectSetInteger(0, bodyName, OBJPROP_FILL, true);
      ObjectSetInteger(0, bodyName, OBJPROP_BACK, true);
      ObjectSetInteger(0, bodyName, OBJPROP_SELECTABLE, false);

      string wickName = "GOM_PRED_WICK_" + IntegerToString(i);
      ObjectCreate(0, wickName, OBJ_TREND, 0, tMid, l, tMid, h);
      ObjectSetInteger(0, wickName, OBJPROP_COLOR, col);
      ObjectSetInteger(0, wickName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, wickName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, wickName, OBJPROP_BACK, true);
      ObjectSetInteger(0, wickName, OBJPROP_SELECTABLE, false);

      minP = MathMin(minP, l);
      maxP = MathMax(maxP, h);
      y = c;
   }

   string zoneName = "GOM_PRED_ZONE";
   ObjectDelete(0, zoneName);
   ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, t0 + tfSec, minP, t0 + nBars * tfSec, maxP);
   ObjectSetInteger(0, zoneName, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, zoneName, OBJPROP_FILL, false);
   ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
   ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, false);

   string lbl = "GOM_PRED_LBL";
   ObjectDelete(0, lbl);
   ObjectCreate(0, lbl, OBJ_TEXT, 0, t0 + tfSec, maxP);
   ObjectSetString(0, lbl, OBJPROP_TEXT, StringFormat("GOM %d | net=%d | setup=%.0f%% hit=%.0f%%",
         nBars, g_predNet, g_setupValidProb * 100.0, g_predHitRate * 100.0));
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, lbl, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);

   DrawGOMPathSRLevels(t0 + tfSec, t0 + nBars * tfSec);

   g_predPathDrawKey = drawKey;
   g_lastGOMPathDraw = TimeCurrent();
   ChartRedraw(0);
}

string BuildTVSetupKey()
{
   if(!g_setupValid || g_setupDir == 0 || g_setupEntry <= 0) return "";
   return StringFormat("%s|%d|%.5f|%.5f|%.5f|%.5f",
         g_setupType, g_setupDir, g_setupEntry, g_setupSL, g_setupTP1, g_setupTP2);
}

void ValidateTVSetupLevels()
{
   g_setupValid = (g_setupDir != 0 && g_setupEntry > 0 && g_setupSL > 0 && g_setupTP1 > 0);
   if(!g_setupValid) return;
   if(g_setupDir == 1 && !(g_setupSL < g_setupEntry && g_setupTP1 > g_setupEntry))
      g_setupValid = false;
   if(g_setupDir == -1 && !(g_setupSL > g_setupEntry && g_setupTP1 < g_setupEntry))
      g_setupValid = false;
}

void InferTVSetupFromGOMBody(const string &body)
{
   if(!TVSetupInferFromGOM) return;

   double sb  = JsonGetDouble(body, "score_buy");
   double ss  = JsonGetDouble(body, "score_sell");
   double gap = JsonGetDouble(body, "verdict_gap");
   if(gap <= 0) gap = MathAbs(sb - ss);
   double kola_buy  = JsonGetDouble(body, "kola_buy");
   double kola_sell = JsonGetDouble(body, "kola_sell");
   double bb_up = JsonGetDouble(body, "bb_up");
   double bb_dn = JsonGetDouble(body, "bb_dn");
   double price = JsonGetDouble(body, "price");
   if(price <= 0) price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double atr_est = price * 0.0012;

   if(sb >= ss && gap >= 0.8 && kola_buy > 0)
   {
      g_setupDir   = 1;
      g_setupType  = "OB_BULL";
      // Entry = retest SOUS le prix (BuyLimit). Éviter entry >= price (→ Invalid price).
      double entryCand = kola_buy;
      if(bb_up > 0 && bb_up < price - price * 0.00005)
         entryCand = bb_up;
      else if(bb_dn > 0 && bb_dn < price)
         entryCand = MathMax(bb_dn, kola_buy);
      g_setupEntry = MathMin(entryCand, price - atr_est * 0.08);
      if(g_setupEntry <= 0 || g_setupEntry >= price)
         g_setupEntry = kola_buy;
      g_setupSL    = kola_buy - atr_est * 0.12;
      double risk  = g_setupEntry - g_setupSL;
      if(risk <= price * 0.00005) return;
      g_setupTP1 = g_setupEntry + risk;
      g_setupTP2 = g_setupEntry + risk * 1.5;
      g_setupRR  = 1.0;
   }
   else if(ss > sb && gap >= 0.8 && kola_sell > 0)
   {
      g_setupDir   = -1;
      g_setupType  = "OB_BEAR";
      double entryCandS = kola_sell;
      if(bb_dn > 0 && bb_dn > price + price * 0.00005)
         entryCandS = bb_dn;
      else if(bb_up > 0 && bb_up > price)
         entryCandS = MathMin(bb_up, kola_sell);
      g_setupEntry = MathMax(entryCandS, price + atr_est * 0.08);
      if(g_setupEntry <= 0 || g_setupEntry <= price)
         g_setupEntry = kola_sell;
      g_setupSL    = kola_sell + atr_est * 0.12;
      double risk  = g_setupSL - g_setupEntry;
      if(risk <= price * 0.00005) return;
      g_setupTP1 = g_setupEntry - risk;
      g_setupTP2 = g_setupEntry - risk * 1.5;
      g_setupRR  = 1.0;
   }
   ValidateTVSetupLevels();
   if(g_setupValid)
      PrintOnce(StringFormat("[TV-Setup] Setup inféré %s entry=%.2f SL=%.2f TP1=%.2f",
            g_setupType, g_setupEntry, g_setupSL, g_setupTP1), 30);
}

void ParseTVSetupFromGOMBody(const string &body)
{
   g_setupDir     = (int)JsonGetDouble(body, "setup_dir");
   g_setupEntry   = JsonGetDouble(body, "setup_entry");
   g_setupSL      = JsonGetDouble(body, "setup_sl");
   g_setupTP1     = JsonGetDouble(body, "setup_tp1");
   g_setupTP2     = JsonGetDouble(body, "setup_tp2");
   g_setupRR      = JsonGetDouble(body, "setup_rr");
   g_setupType    = JsonGetString(body, "setup_type");
   g_setupConfirm = JsonGetString(body, "setup_confirm");

   if(StringLen(g_setupConfirm) == 0)
   {
      int ccode = (int)JsonGetDouble(body, "setup_confirm_code");
      if(ccode == 1)       g_setupConfirm = "PIN_BAR_BULL";
      else if(ccode == -1) g_setupConfirm = "PIN_BAR_BEAR";
   }

   ValidateTVSetupLevels();

   if(!g_setupValid)
      InferTVSetupFromGOMBody(body);
   else if(g_setupDir != 0 && g_setupEntry > 0)
      PrintOnce(StringFormat("[TV-Setup] Setup TV %s @ %.2f (confirm=%s)",
            g_setupType, g_setupEntry, g_setupConfirm), 60);
}

// 1=BUY_LIMIT 2=BUY_STOP -1=SELL_LIMIT -2=SELL_STOP 0=entry trop proche du marché
int ClassifyTVSetupPendingType(const int dir, const double entry)
{
   string sym = _Symbol;
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0 || bid <= 0 || entry <= 0) return 0;
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   int stopsLvl = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (double)MathMax(stopsLvl + 5, 10) * pt;

   if(dir == 1)
   {
      if(entry < ask - minDist) return 1;
      if(entry > ask + minDist) return 2;
      return 0;
   }
   if(dir == -1)
   {
      if(entry > bid + minDist) return -1;
      if(entry < bid - minDist) return -2;
      return 0;
   }
   return 0;
}

bool FixTVSetupStopsForBroker(const int dir, double &entry, double &sl, double &tp)
{
   string sym = _Symbol;
   int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   int stopsLvl = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (double)MathMax(stopsLvl + 5, 10) * pt;
   double ref = (dir == 1) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   if(ref <= 0) ref = entry;

   if(sl > 0 && MathAbs(ref - sl) < minDist)
      sl = NormalizeDouble((dir == 1) ? ref - minDist : ref + minDist, dg);
   if(tp > 0 && MathAbs(tp - ref) < minDist)
      tp = NormalizeDouble((dir == 1) ? ref + minDist : ref - minDist, dg);

   bool slOk = (sl <= 0) || ((dir == 1) ? (sl < entry) : (sl > entry));
   bool tpOk = (tp <= 0) || ((dir == 1) ? (tp > entry) : (tp < entry));
   if(!slOk || !tpOk)
   {
      PrintOnce(StringFormat("[TV-Setup] SL/TP invalides entry=%.2f sl=%.2f tp=%.2f (minDist=%.2f)",
            entry, sl, tp, minDist), 30);
      return false;
   }
   return true;
}

bool FindTVSetupPendingTicket(ulong &ticketOut)
{
   ticketOut = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != (long)TVSetupMagicNumber) continue;
      ENUM_ORDER_TYPE ty = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ty == ORDER_TYPE_BUY_LIMIT || ty == ORDER_TYPE_SELL_LIMIT
         || ty == ORDER_TYPE_BUY_STOP || ty == ORDER_TYPE_SELL_STOP)
      {
         ticketOut = t;
         return true;
      }
   }
   return false;
}

bool CancelTVSetupLimitOrder(const string reason)
{
   ulong t = 0;
   if(g_tvSetupOrderTicket > 0)
      t = g_tvSetupOrderTicket;
   else if(!FindTVSetupPendingTicket(t))
   {
      g_tvSetupOrderTicket = 0;
      return false;
   }

   CTrade ct;
   ct.SetExpertMagicNumber(TVSetupMagicNumber);
   bool ok = ct.OrderDelete(t);
   Print(StringFormat("[TV-Setup] ❌ Annulation limite ticket=%llu — %s", t, reason));
   g_tvSetupOrderTicket = 0;
   g_tvSetupEntryTouched = false;
   return ok;
}

bool PriceTouchedTVSetupEntry(const int dir, const double entry)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0 || bid <= 0 || entry <= 0) return false;
   double tol = MathMax(entry * TVSetupEntryTolPct / 100.0, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5);
   // BUY LIMIT / SELL LIMIT : retest vers l'entry
   // BUY STOP / SELL STOP : franchissement de l'entry
   int pk = ClassifyTVSetupPendingType(dir, entry);
   if(dir == 1 && pk == 2)
      return (ask >= entry - tol);
   if(dir == -1 && pk == -2)
      return (bid <= entry + tol);
   if(dir == 1)
      return (bid <= entry + tol);
   if(dir == -1)
      return (ask >= entry - tol);
   return (MathAbs(bid - entry) <= tol || MathAbs(ask - entry) <= tol);
}

bool PlaceTVSetupLimitOrder()
{
   if(!g_setupValid || g_setupDir == 0) return false;
   if(IsGOMCorrectionZone(g_setupDir))
   {
      PrintOnce("[TV-Setup] Entree bloquee — zone de correction active", 30);
      return false;
   }
   if(g_tvSetupPlaceFailAt > 0 && (int)(TimeCurrent() - g_tvSetupPlaceFailAt) < 25)
      return false;
   if(TVSetupRearmCooldownSec > 0 && g_tvSetupCancelAt > 0
      && (int)(TimeCurrent() - g_tvSetupCancelAt) < TVSetupRearmCooldownSec)
      return false;
   if(TVSetupBlockPlaceOnWait && IsGOMVerdictWait())
   {
      Print("[TV-Setup] ⏸️ Pas de limite — GOM WAIT (TVSetupBlockPlaceOnWait=true)");
      return false;
   }
   if(TVSetupRequirePinBar)
   {
      if(g_setupDir == 1 && StringFind(g_setupConfirm, "PIN_BAR_BULL") < 0) return false;
      if(g_setupDir == -1 && StringFind(g_setupConfirm, "PIN_BAR_BEAR") < 0) return false;
   }

   if(UseGOMScalp)
   {
      int gomDir = 0, effVnum = 0;
      string actTag;
      if(ResolveGOMActionable(gomDir, effVnum, actTag))
      {
         if(gomDir != 0 && gomDir != g_setupDir)
         {
            PrintOnce(StringFormat("[TV-Setup] Setup %s ignoré — conflit GOM %s", g_setupType, actTag), 30);
            return false;
         }
      }
      else if(g_setupDir == 1 && g_lastGOMVerdictNum < 0)
      {
         PrintOnce("[TV-Setup] Setup BUY ignoré — verdict GOM baissier actif", 30);
         return false;
      }
      else if(g_setupDir == -1 && g_lastGOMVerdictNum > 0)
      {
         PrintOnce("[TV-Setup] Setup SELL ignoré — verdict GOM haussier actif", 30);
         return false;
      }
   }

   if(IsGlobalPositionLimitReached()) return false;
   if(HasMCPOpenPosition(_Symbol)) return false;

   ulong existing = 0;
   if(FindTVSetupPendingTicket(existing))
   {
      g_tvSetupOrderTicket = existing;
      return true;
   }

   double lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double entry = NormalizeDouble(g_setupEntry, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   double sl    = NormalizeDouble(g_setupSL, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   double tp    = NormalizeDouble(g_setupTP1, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

   int pendKind = ClassifyTVSetupPendingType(g_setupDir, entry);
   if(pendKind == 0)
   {
      PrintOnce(StringFormat("[TV-Setup] Entry %.2f trop proche du marché (ask=%.2f) — breakout ou attente",
            entry, SymbolInfoDouble(_Symbol, SYMBOL_ASK)), 20);
      return false;
   }

   if(!FixTVSetupStopsForBroker(g_setupDir, entry, sl, tp))
      return false;

   CTrade ct;
   ct.SetExpertMagicNumber(TVSetupMagicNumber);
   ct.SetDeviationInPoints(30);
   ct.SetTypeFilling(ORDER_FILLING_IOC);

   bool ok = false;
   string pendLabel = "";
   if(pendKind == 1)      { ok = ct.BuyLimit(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "TM_TV_SETUP");  pendLabel = "BUY_LIMIT"; }
   else if(pendKind == 2) { ok = ct.BuyStop(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "TM_TV_SETUP");   pendLabel = "BUY_STOP"; }
   else if(pendKind == -1){ ok = ct.SellLimit(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "TM_TV_SETUP"); pendLabel = "SELL_LIMIT"; }
   else if(pendKind == -2){ ok = ct.SellStop(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "TM_TV_SETUP");  pendLabel = "SELL_STOP"; }

   if(ok)
   {
      g_tvSetupOrderTicket = ct.ResultOrder();
      g_tvSetupPlacedAt = TimeCurrent();
      g_tvSetupEntryTouched = false;
      g_tvSetupPlaceFailAt = 0;
      Print(StringFormat("[TV-Setup] ✅ %s %s @ %.2f SL=%.2f TP1=%.2f (%s / %s)",
            pendLabel, _Symbol, entry, sl, tp, g_setupType, g_setupConfirm));
   }
   else
   {
      uint rc = ct.ResultRetcode();
      if(rc == TRADE_RETCODE_INVALID_PRICE || rc == TRADE_RETCODE_INVALID_STOPS)
         g_tvSetupPlaceFailAt = TimeCurrent();
      PrintOnce(StringFormat("[TV-Setup] ❌ Échec %s @ %.2f: %d %s (ask=%.2f bid=%.2f)",
            pendLabel, entry, (int)rc, ct.ResultRetcodeDescription(),
            SymbolInfoDouble(_Symbol, SYMBOL_ASK), SymbolInfoDouble(_Symbol, SYMBOL_BID)), 15);
   }

   return ok;
}

void ManageTVSetupLimitOrder()
{
   if(!UseTVSetupLimit) return;

   if(!g_setupValid || g_setupDir == 0)
   {
      if(g_tvSetupOrderTicket > 0 || FindTVSetupPendingTicket(g_tvSetupOrderTicket))
         CancelTVSetupLimitOrder("setup TV invalide ou retiré");
      g_setupKey = "";
      PrintOnce("[TV-Setup] Pas de setup actif — vérifier poller + GOM_KOLA_SIDO sur TV", 120);
      return;
   }

   string newKey = BuildTVSetupKey();
   if(newKey != "" && newKey != g_setupKey)
   {
      g_tvSetupPlaceFailAt = 0;
      if(g_tvSetupOrderTicket > 0 || FindTVSetupPendingTicket(g_tvSetupOrderTicket))
         CancelTVSetupLimitOrder("nouveau setup TV");
      g_setupKey = newKey;
      PlaceTVSetupLimitOrder();
      return;
   }

   ulong t = 0;
   if(!FindTVSetupPendingTicket(t))
   {
      g_tvSetupOrderTicket = 0;
      if(g_setupValid)
         PlaceTVSetupLimitOrder();
      TryTVSetupMarketBreakout();
      return;
   }
   g_tvSetupOrderTicket = t;

   if(PriceTouchedTVSetupEntry(g_setupDir, g_setupEntry))
      g_tvSetupEntryTouched = true;

   if(TVSetupCancelOnWaitTouch && g_tvSetupEntryTouched && IsGOMVerdictWait())
   {
      CancelTVSetupLimitOrder("entry touchée + GOM WAIT — attente nouveau setup");
      g_setupKey = "";
      g_tvSetupCancelAt = TimeCurrent();
      return;
   }

   TryTVSetupMarketBreakout();
}

// Reprise haussière : limite non exécutée, prix au-dessus de l'entry + GOM BUY
void TryTVSetupMarketBreakout()
{
   if(!TVSetupMarketOnBreakout || !g_setupValid || g_setupDir != 1) return;
   if(IsGOMCorrectionZone(1))
   {
      PrintOnce("[TV-Setup] Breakout BUY bloque — correction en cours", 30);
      return;
   }
   if(IsGOMVerdictWait()) return;
   if(g_lastGOMVerdictNum < 1 || g_lastGOMScoreBuy <= g_lastGOMScoreSell) return;
   if(GOMWaitPullbackToKola && StringCompare(g_lastKOLAState, "NEAR BUY") != 0) return;
   if(HasMCPOpenPosition(_Symbol) || IsGlobalPositionLimitReached()) return;

   ulong pending = 0;
   if(FindTVSetupPendingTicket(pending)) return;

   if((int)(TimeCurrent() - g_tvSetupBreakoutDone) < GOMAutoEntryCooldownSec) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0 || g_setupEntry <= 0) return;
   double tol = MathMax(g_setupEntry * TVSetupBreakoutTolPct / 100.0, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5);
   if(ask < g_setupEntry + tol) return;

   double lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double entry = ask;
   double sl = NormalizeDouble(g_setupSL, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   double tp = NormalizeDouble(g_setupTP1, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   if(!FixTVSetupStopsForBroker(1, entry, sl, tp)) return;

   CTrade ct;
   ct.SetExpertMagicNumber(TVSetupMagicNumber);
   ct.SetDeviationInPoints(50);
   ct.SetTypeFilling(ORDER_FILLING_IOC);
   if(!ct.Buy(lot, _Symbol, 0, sl, tp, "TM_TV_SETUP_BRK"))
   {
      PrintOnce(StringFormat("[TV-Setup] Breakout BUY échoué: %d", (int)ct.ResultRetcode()), 20);
      return;
   }

   g_tvSetupBreakoutDone = TimeCurrent();
   Print(StringFormat("[TV-Setup] 🚀 BREAKOUT BUY %s @ %.2f (entry setup=%.2f) SL=%.2f TP=%.2f | %s",
         _Symbol, entry, g_setupEntry, sl, tp, g_lastGOMVerdict));
}

//+------------------------------------------------------------------+
//| Profit net position (swap + commission inclus)                    |
//+------------------------------------------------------------------+
double PositionNetProfit()
{
   return posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
}

//+------------------------------------------------------------------+
//| Suivi pic profit par ticket (chaque jambe / duplicata)            |
//+------------------------------------------------------------------+
int FindTicketPeakIdx(const ulong ticket)
{
   for(int i = 0; i < g_ticketPeakCount; i++)
      if(g_ticketPeakTickets[i] == ticket) return i;
   return -1;
}

void SetTicketPeak(const ulong ticket, const double peakUSD)
{
   int i = FindTicketPeakIdx(ticket);
   if(i < 0)
   {
      i = g_ticketPeakCount;
      ArrayResize(g_ticketPeakTickets, i + 1);
      ArrayResize(g_ticketPeakUSD, i + 1);
      g_ticketPeakTickets[i] = ticket;
      g_ticketPeakCount++;
   }
   g_ticketPeakUSD[i] = peakUSD;
}

double GetTicketPeak(const ulong ticket)
{
   int i = FindTicketPeakIdx(ticket);
   return (i >= 0) ? g_ticketPeakUSD[i] : 0.0;
}

void PruneTicketPeaks()
{
   for(int i = g_ticketPeakCount - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(g_ticketPeakTickets[i])) continue;
      for(int j = i; j < g_ticketPeakCount - 1; j++)
      {
         g_ticketPeakTickets[j] = g_ticketPeakTickets[j + 1];
         g_ticketPeakUSD[j]      = g_ticketPeakUSD[j + 1];
      }
      g_ticketPeakCount--;
      ArrayResize(g_ticketPeakTickets, g_ticketPeakCount);
      ArrayResize(g_ticketPeakUSD, g_ticketPeakCount);
   }
}

// Limite globale configurable via input MaxGlobalPositions
bool IsGlobalPositionLimitReached()
{
   // Compter uniquement les positions gérées par cet EA (magic MCP)
   // Ignore les positions manuelles et autres EA pour ne pas fausser la limite
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic == MCPMagicNumber || magic == TVSetupMagicNumber || magic == 0)
         n++;
   }
   return n >= MaxGlobalPositions;
}

// Vérifie la limite globale en exemptant le même symbole (re-entrée tendance)
bool IsGlobalPositionLimitReachedForReEntry(const string sym)
{
   if(ReEntryIgnoreGlobal) return false;   // re-entrée toujours autorisée si option activée
   return IsGlobalPositionLimitReached();
}

int CountManagedPositions(const string sym)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != sym) continue;
      if(!PositionIncludedInTrailing()) continue;
      n++;
   }
   return n;
}

double SumManagedProfit(const string sym)
{
   double sum = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != sym) continue;
      if(!PositionIncludedInTrailing()) continue;
      sum += PositionNetProfit();
   }
   return sum;
}

// Règle unique de duplication :
//   - Jamais sur Boom/Crash
//   - Profit position >= $2 stable pendant DupProfitStableSec
//   - GOM GOOD/PERFECT + trajectoire alignée + proba setup RDS
//   - 1 seule duplication par symbole (2 positions max)
bool CanDuplicateOnSymbol(const string sym, string &why)
{
   why = "";
   if(IsBoomOrCrashSymbol(sym))
   {
      why = "duplication interdite sur Boom/Crash";
      return false;
   }
   if(CountManagedPositions(sym) >= 2)
   {
      why = StringFormat("déjà 2 positions sur %s — 1 duplication max", sym);
      return false;
   }
   return true;
}

bool CanDuplicateNowWithGOM(const string sym, const int dir, const ulong ticket, string &why)
{
   why = "";
   string baseWhy;
   if(!CanDuplicateOnSymbol(sym, baseWhy)) { why = baseWhy; return false; }

   if(!HasDupProfitStable(ticket))
   {
      why = StringFormat("profit $%.2f pas stable %ds (min %ds sans rechute)",
            PositionSelectByTicket(ticket) ? PositionNetProfit() : 0.0,
            DupProfitStableSec, DupProfitStableSec);
      return false;
   }

   if(g_isConsolidation)
   {
      why = "consolidation GOM/KOLA active";
      return false;
   }

   if(IsGOMCorrectionZone(dir))
   {
      why = "zone de correction active";
      return false;
   }

   if(DuplicateRequireGoodPerfect)
   {
      if(dir == 1 && (g_lastGOMVerdictNum != 2 && g_lastGOMVerdictNum != 3))
      {
         why = StringFormat("verdict=%s (exige GOOD/PERFECT BUY)", g_lastGOMVerdict);
         return false;
      }
      if(dir == -1 && (g_lastGOMVerdictNum != -2 && g_lastGOMVerdictNum != -3))
      {
         why = StringFormat("verdict=%s (exige GOOD/PERFECT SELL)", g_lastGOMVerdict);
         return false;
      }
   }

   if(!IsGOMPathAlignedWithDir(dir))
   {
      why = StringFormat("trajectoire non alignée (pred_net=%d)", g_predNet);
      return false;
   }

   double prob = (dir == 1) ? g_setupBuyProb : g_setupSellProb;
   if(prob <= 0) prob = g_setupValidProb;
   if(prob > 0 && prob < DupMinSetupProb)
   {
      why = StringFormat("proba setup %.0f%% < %.0f%%", prob * 100.0, DupMinSetupProb * 100.0);
      return false;
   }

   if(g_lastGOMGlobalStrength < DuplicateMinGlobalStrength)
   {
      why = StringFormat("force TF global insuffisante (%d < %d)", g_lastGOMGlobalStrength, DuplicateMinGlobalStrength);
      return false;
   }
   if(dir == 1  && StringCompare(g_lastGOMGlobalDir, "BULL") != 0) { why = StringFormat("TF global non haussier (%s)", g_lastGOMGlobalDir); return false; }
   if(dir == -1 && StringCompare(g_lastGOMGlobalDir, "BEAR") != 0) { why = StringFormat("TF global non baissier (%s)", g_lastGOMGlobalDir); return false; }

   if(g_lastGOMQuality < DuplicateMinQuality || g_lastGOMCoherence < DuplicateMinCoherence)
   {
      why = StringFormat("Quality/Coherence insuffisantes (Q=%.0f%% C=%.0f%%)", g_lastGOMQuality, g_lastGOMCoherence);
      return false;
   }

   if(GOMIsCounterTrendEntryBlocked(dir))
   {
      why = "bloqué par filtre contre-tendance";
      return false;
   }

   return true;
}

void EnsureStateForPosition()
{
   string sym = posInfo.Symbol();
   if(FindState(sym) >= 0) return;

   // Refuser de tracker un symbole non validé par le pipeline du jour
   if(!IsSymbolWhitelisted(sym))
   {
      PrintOnce(StringFormat("[TradeManager] 🚫 %s refusé — absent de la whitelist pipeline", sym), 120);
      return;
   }

   int idx = g_stateCount;
   ArrayResize(g_states, idx + 1);
   g_stateCount++;
   g_states[idx].symbol       = sym;
   g_states[idx].direction    = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
   g_states[idx].openPrice    = posInfo.PriceOpen();
   g_states[idx].originalSL   = posInfo.StopLoss();
   g_states[idx].originalTP   = posInfo.TakeProfit();
   g_states[idx].originalLot  = posInfo.Volume();
   g_states[idx].peakProfit   = 0.0;
   g_states[idx].forceTrailing = (posInfo.StopLoss() == 0);
   g_states[idx].slDist        = 0;
   g_states[idx].hRSI          = iRSI(sym, PERIOD_M1, RSI_Period, PRICE_CLOSE);
   g_states[idx].hEMAFast      = iMA(sym, PERIOD_M1, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_states[idx].hEMASlow      = iMA(sym, PERIOD_M1, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   g_states[idx].hADX          = iADX(sym, PERIOD_M1, ADX_Period);
   g_states[idx].hATR          = iATR(sym, PERIOD_M1, ADX_Period);
   ResetStagnationState(idx);
   Print(StringFormat("[TradeManager] 📌 TRACKING ajouté %s ticket=%llu (dup/autre magic)",
         sym, posInfo.Ticket()));
}

//+------------------------------------------------------------------+
//| Fermeture marché : ne pas laisser un gain redevenir grosse perte   |
//+------------------------------------------------------------------+
void ManageProfitGivebackExit()
{
   if(!UseProfitGivebackExit) return;
   PruneTicketPeaks();

   double maxLoss = MathMin(MaxRiskUSD, MaxLossCapUSD);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(!PositionIncludedInTrailing()) continue;

      ulong  ticket = posInfo.Ticket();
      string sym    = posInfo.Symbol();
      double profit = PositionNetProfit();

      double peak = GetTicketPeak(ticket);
      if(profit > peak) peak = profit;
      SetTicketPeak(ticket, peak);

      int idx = FindState(sym);
      if(idx >= 0 && profit > g_states[idx].peakProfit)
         g_states[idx].peakProfit = profit;

      if(profit <= -maxLoss)
      {
         Print(StringFormat("[TradeManager] 🛑 %s #%llu perte $%.2f (cap -$%.2f) — fermeture",
               sym, ticket, profit, maxLoss));
         trade.PositionClose(ticket);
         continue;
      }

      if(peak < ProfitGivebackArmUSD) continue;

      double floorPeak = peak - MaxGivebackFromPeakUSD;
      double floorAbs  = -maxLoss;
      double floorUSD  = MathMax(floorPeak, floorAbs);

      if(profit < floorUSD)
      {
         Print(StringFormat("[TradeManager] 💰 %s #%llu GIVEBACK | profit=$%.2f pic=$%.2f plancher=$%.2f",
               sym, ticket, profit, peak, floorUSD));
         trade.PositionClose(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Réinitialise le suivi stagnation profit (nouvelle position)       |
//+------------------------------------------------------------------+
void ResetStagnationState(int idx)
{
   if(idx < 0 || idx >= g_stateCount) return;
   g_states[idx].stagnationZoneSince    = 0;
   g_states[idx].stagnationLastPeakTime = 0;
   g_states[idx].stagnationPeakUSD       = 0.0;
   g_states[idx].stagnationArmed         = false;
}

//+------------------------------------------------------------------+
//| SORTIE PROFIT STAGNÉ — ne pas laisser $2 retomber vers $1         |
//| Après StagnationHoldSec en profit >= trigger, ferme si recul      |
//| puis attente re-entrée EMA / GOM (OB via signaux TV)              |
//+------------------------------------------------------------------+
void ManageProfitStagnationExit()
{
   if(!UseStagnationExit) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(!PositionIncludedInTrailing()) continue;

      string sym = posInfo.Symbol();
      int    idx = FindState(sym);
      if(idx < 0) continue;

      ulong  ticket    = posInfo.Ticket();
      double profitUSD = PositionNetProfit();
      datetime now     = TimeCurrent();

      double tPeak = GetTicketPeak(ticket);
      if(profitUSD > tPeak) SetTicketPeak(ticket, profitUSD);

      // Zone profit : démarrer / mettre à jour le pic
      if(profitUSD >= StagnationTriggerUSD)
      {
         if(g_states[idx].stagnationZoneSince == 0)
         {
            g_states[idx].stagnationZoneSince    = now;
            g_states[idx].stagnationLastPeakTime = now;
            g_states[idx].stagnationPeakUSD      = profitUSD;
            Print(StringFormat("[TradeManager] 📈 %s stagnation watch: profit $%.2f >= $%.2f — timer %ds",
                  sym, profitUSD, StagnationTriggerUSD, StagnationHoldSec));
         }
         else if(profitUSD > g_states[idx].stagnationPeakUSD + 0.02)
         {
            g_states[idx].stagnationPeakUSD      = profitUSD;
            g_states[idx].stagnationLastPeakTime = now;
         }
      }
      else if(!g_states[idx].stagnationArmed)
      {
         ResetStagnationState(idx);
         continue;
      }

      if(g_states[idx].stagnationZoneSince == 0) continue;

      int inZoneSec = (int)(now - g_states[idx].stagnationZoneSince);
      if(!g_states[idx].stagnationArmed && inZoneSec >= StagnationHoldSec)
      {
         g_states[idx].stagnationArmed = true;
         Print(StringFormat("[TradeManager] 🛡️ %s stagnation ARMÉ | pic=$%.2f | plancher=$%.2f (giveback max $%.2f)",
               sym, g_states[idx].stagnationPeakUSD,
               MathMax(StagnationLockMinUSD, g_states[idx].stagnationPeakUSD - StagnationMaxGivebackUSD),
               StagnationMaxGivebackUSD));
      }

      if(!g_states[idx].stagnationArmed) continue;

      double peak     = MathMax(g_states[idx].stagnationPeakUSD, GetTicketPeak(ticket));
      double floorUSD = MathMax(StagnationLockMinUSD, peak - StagnationMaxGivebackUSD);
      int    sincePeak = (int)(now - g_states[idx].stagnationLastPeakTime);

      bool stagnating = (sincePeak >= StagnationHoldSec) &&
                        (profitUSD >= StagnationTriggerUSD - StagnationFlatBandUSD) &&
                        (profitUSD <= peak + StagnationFlatBandUSD);

      bool givebackHit = (profitUSD < floorUSD);
      bool stallExit   = stagnating && (profitUSD < peak - StagnationMaxGivebackUSD * 0.5);

      if(!givebackHit && !stallExit) continue;

      double bid   = SymbolInfoDouble(sym, SYMBOL_BID);
      string why   = givebackHit ? "recul plancher" : "stagnation prolongée";

      Print(StringFormat("[TradeManager] 💰 %s SORTIE STAGNATION (%s) | profit=$%.2f pic=$%.2f plancher=$%.2f | %ds en zone",
            sym, why, profitUSD, peak, floorUSD, inZoneSec));

      g_states[idx].closeTime      = now;
      g_states[idx].closePrice     = bid;
      g_states[idx].waitingReEntry = true;
      g_states[idx].peakProfit     = 0.0;
      ResetStagnationState(idx);

      if(trade.PositionClose(ticket))
      {
         Print(StringFormat("[TradeManager] ✅ %s fermé — attente re-entrée EMA/GOM (OB TV)", sym));
         if(UseWhatsApp)
            SendWAEvent("STAGNATION_EXIT", sym, bid, profitUSD, "", 0, 0, 0, 0,
               StringFormat("Profit stagne ferme @ $%.2f (pic $%.2f) — re-entree EMA/GOM", profitUSD, peak));
      }
   }
}

//+------------------------------------------------------------------+
//| Scanne les positions ouvertes et initialise les états            |
//+------------------------------------------------------------------+
void ScanAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(MagicFilter > 0 && posInfo.Magic() != MagicFilter &&
         !(UseMCPSignals && posInfo.Magic() == (long)MCPMagicNumber))
         continue;

      string sym = posInfo.Symbol();
      if(FindState(sym) >= 0) continue;

      int idx = g_stateCount;
      ArrayResize(g_states, idx + 1);
      g_stateCount++;

      g_states[idx].symbol         = sym;
      g_states[idx].direction      = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
      g_states[idx].openPrice      = posInfo.PriceOpen();
      g_states[idx].originalSL     = posInfo.StopLoss();
      g_states[idx].originalTP     = posInfo.TakeProfit();
      g_states[idx].originalLot    = posInfo.Volume();
      g_states[idx].peakProfit     = 0.0;
      g_states[idx].reEntryCount   = 0;
      g_states[idx].lastReEntry    = 0;
      g_states[idx].waitingReEntry   = false;
      g_states[idx].forceTrailing    = false;
      g_states[idx].lastReEntryFail  = 0;
      g_states[idx].stagnationZoneSince    = 0;
      g_states[idx].stagnationLastPeakTime = 0;
      g_states[idx].stagnationPeakUSD       = 0.0;
      g_states[idx].stagnationArmed         = false;
      g_states[idx].closeTime        = 0;
      g_states[idx].closePrice       = 0.0;
      g_states[idx].hRSI             = iRSI(sym, PERIOD_M1, RSI_Period, PRICE_CLOSE);
      g_states[idx].hEMAFast         = iMA(sym, PERIOD_M1, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      g_states[idx].hEMASlow         = iMA(sym, PERIOD_M1, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
      g_states[idx].hADX             = iADX(sym, PERIOD_M1, ADX_Period);
      g_states[idx].hATR             = iATR(sym, PERIOD_M1, ADX_Period);

      // Calculer et mémoriser les distances SL/TP initiales
      double ep  = g_states[idx].openPrice;
      double sl0 = g_states[idx].originalSL;
      double tp0 = g_states[idx].originalTP;
      g_states[idx].slDist = (sl0 > 0 && ep > 0) ? MathAbs(ep - sl0) : 0;
      g_states[idx].tpDist = (tp0 > 0 && ep > 0) ? MathAbs(ep - tp0) : 0;

      // Auto-assigner SL/TP si manquants
      if(AutoAssignSLTP && (sl0 == 0 || tp0 == 0))
         AutoSetSLTP(idx);

      Print(StringFormat("[TradeManager] ✅ TRACKING %s | %s | EP=%.5f SL=%.5f TP=%.5f slDist=%.5f",
            sym, (g_states[idx].direction==1?"BUY":"SELL"),
            ep, g_states[idx].originalSL, g_states[idx].originalTP, g_states[idx].slDist));
   }
}

//+------------------------------------------------------------------+
//| Sync SL/TP vers AI server après modification position              |
//+------------------------------------------------------------------+
bool SyncSLTPToServer(ulong ticket, double newSL, double newTP, string source = "ea_auto")
{
   if(!UseMCPSignals) return true;

   string symbol = "";
   for(int i = 0; i < g_mcpCount; i++)
   {
      if(g_mcpSignals[i].ticket == ticket)
      {
         symbol = g_mcpSignals[i].symbol;
         break;
      }
   }

   if(StringLen(symbol) == 0)
   {
      Print("[TradeManager] ⚠️ SyncSLTPToServer: symbol not found for ticket ", ticket);
      return false;
   }

   // Endpoint: POST /pending-order/{symbol}/sync
   string url = AIServerURL + "/pending-order/" + symbol + "/sync";
   string headers = "Content-Type: application/json\r\n";

   // Construct JSON body matching OrderSyncBody schema
   string body = StringFormat(
      "{\"mt5_ticket\":%d,\"current_stop_loss\":%.5f,\"current_take_profit\":%.5f,\"update_source\":\"%s\"}",
      (int)ticket, newSL, newTP, source
   );

   char post[];
   char result[];
   string respH;
   StringToCharArray(body, post, 0, StringLen(body));
   ArrayResize(post, StringLen(body));

   int res = WebRequest("POST", url, headers, 10000, post, result, respH);
   if(res == 200)
   {
      Print("[TradeManager] ✅ SL/TP synced to server: symbol=", symbol, " ticket=", ticket, " SL=", DoubleToString(newSL, 5), " TP=", DoubleToString(newTP, 5), " source=", source);
      return true;
   }
   else
   {
      Print("[TradeManager] ❌ Failed to sync SL/TP: HTTP ", res, " symbol=", symbol, " ticket=", ticket);
      return false;
   }
}

//+------------------------------------------------------------------+
//| ReadGOMSignalFromServer — Fetch GOM KOLA verdict + niveaux       |
//+------------------------------------------------------------------+
struct GOMSignal
{
   string   verdict;      // "GOOD BUY", "GOOD SELL", "PERFECT BUY", "WAIT"
   double   score_buy;
   double   score_sell;
   double   fib_high;     // Entry level ou TP
   double   fib_low;      // SL level
   double   st_line;      // Supertrend baseline
   int      rsi;
   int      coherence;
   int      quality;
   bool     valid;
};

bool FetchGOMFromServer(string symbol, GOMSignal &sig)
{
   // GET http://127.0.0.1:8000/gom-verdict?symbol=XAUUSD
   string url = AIServerURL + "/gom-verdict?symbol=" + symbol;
   string headers = "Content-Type: application/json\r\n";
   char data[];
   char result[];

   int res = WebRequest("GET", url, headers, 5000, data, result, headers);
   if(res != 200) return false;

   // Parse JSON: "verdict", "score_buy", "score_sell", "fib_low", "fib_high", "st_line", "rsi", "coherence", "quality"
   string jsonStr = CharArrayToString(result);

   // Simple JSON parsing
   int pos = 0;

   // Extract verdict
   int pos_v = StringFind(jsonStr, "\"verdict\":");
   if(pos_v > 0)
   {
      pos_v = StringFind(jsonStr, "\"", pos_v + 10);
      int pos_v2 = StringFind(jsonStr, "\"", pos_v + 1);
      sig.verdict = StringSubstr(jsonStr, pos_v + 1, pos_v2 - pos_v - 1);
   }

   // Extract numeric fields (simplified)
   sig.score_buy = ExtractJSONDouble(jsonStr, "score_buy");
   sig.score_sell = ExtractJSONDouble(jsonStr, "score_sell");
   sig.fib_high = ExtractJSONDouble(jsonStr, "fib_high");
   sig.fib_low = ExtractJSONDouble(jsonStr, "fib_low");
   sig.st_line = ExtractJSONDouble(jsonStr, "st_line");
   sig.rsi = (int)ExtractJSONDouble(jsonStr, "rsi");
   sig.coherence = (int)ExtractJSONDouble(jsonStr, "coherence");
   sig.quality = (int)ExtractJSONDouble(jsonStr, "quality");

   sig.valid = (sig.coherence >= 60 && sig.quality >= 40);

   return sig.valid;
}

double ExtractJSONDouble(string json, string key)
{
   int pos = StringFind(json, "\"" + key + "\":");
   if(pos < 0) return 0;

   pos = StringFind(json, ":", pos) + 1;
   while(pos < StringLen(json) && (json[pos] == ' ' || json[pos] == '\t'))
      pos++;

   int pos_end = StringFind(json, ",", pos);
   if(pos_end < 0) pos_end = StringFind(json, "}", pos);

   string value_str = StringSubstr(json, pos, pos_end - pos);
   StringTrimLeft(value_str);
   StringTrimRight(value_str);

   return StringToDouble(value_str);
}

void AutoSetSLTP(int idx)
{
   string sym = g_states[idx].symbol;
   double tickVal = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double lot     = g_states[idx].originalLot;
   int    dg      = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   double slPts = (tickSz > 0 && tickVal > 0 && lot > 0) ? (MaxRiskUSD * tickSz / (lot * tickVal)) : 50;
   double tpPts = (tickSz > 0 && tickVal > 0 && lot > 0) ? (TargetProfitUSD * tickSz / (lot * tickVal)) : 100;

   double ep = g_states[idx].openPrice;
   double newSL = (g_states[idx].direction == 1) ? NormalizeDouble(ep - slPts, dg) : NormalizeDouble(ep + slPts, dg);
   double newTP = (g_states[idx].direction == 1) ? NormalizeDouble(ep + tpPts, dg) : NormalizeDouble(ep - tpPts, dg);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != sym) continue;
      if(MagicFilter > 0 && posInfo.Magic() != MagicFilter) continue;
      if(trade.PositionModify(posInfo.Ticket(), newSL, newTP))
      {
         g_states[idx].originalSL    = newSL;
         g_states[idx].originalTP    = newTP;
         g_states[idx].slDist        = slPts;
         g_states[idx].tpDist        = tpPts;
         g_states[idx].forceTrailing = false;
         Print(StringFormat("[TradeManager] ✅ AUTO SL/TP %s SL=%.5f TP=%.5f", sym, newSL, newTP));
         SyncSLTPToServer(posInfo.Ticket(), newSL, newTP, "ea_auto");
      }
      else
      {
         // Broker refuse SL/TP — activer trailing de force (perte max $MaxRiskUSD)
         g_states[idx].forceTrailing = true;
         g_states[idx].slDist        = slPts;
         g_states[idx].tpDist        = tpPts;
         Print(StringFormat("[TradeManager] ⚠️ %s SL/TP refusé (%d) — trailing forcé activé | maxLoss=$%.2f",
               sym, (int)trade.ResultRetcode(), MaxRiskUSD));
      }
      break;
   }
}

int FindState(string sym)
{
   for(int i = 0; i < g_stateCount; i++)
      if(g_states[i].symbol == sym) return i;
   return -1;
}

bool SymbolHasPosition(string sym)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != sym) continue;
      if(MagicFilter > 0 && posInfo.Magic() != MagicFilter) continue;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| TRAILING STOP                                                    |
//+------------------------------------------------------------------+
bool PositionIncludedInTrailing()
{
   long mg = posInfo.Magic();
   if(MagicFilter <= 0) return true;
   if(mg == (long)MagicFilter) return true;
   if(UseMCPSignals && mg == (long)MCPMagicNumber) return true;
   if(DuplicateManualOrders && mg == 0) return true;
   return false;
}

void ManageAllTrailing()
{
   PruneTicketPeaks();
   double maxLoss = MathMin(MaxRiskUSD, MaxLossCapUSD);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(!PositionIncludedInTrailing()) continue;

      string sym = posInfo.Symbol();
      int    idx = FindState(sym);
      if(idx < 0)
      {
         EnsureStateForPosition();
         idx = FindState(sym);
         if(idx < 0) continue;
      }

      ulong  ticket    = posInfo.Ticket();
      double ep        = posInfo.PriceOpen();
      int    dir       = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
      double curSL     = posInfo.StopLoss();
      double curProfit = PositionNetProfit();

      double ticketPeak = GetTicketPeak(ticket);
      if(curProfit > ticketPeak) SetTicketPeak(ticket, curProfit);
      if(curProfit > g_states[idx].peakProfit)
         g_states[idx].peakProfit = curProfit;

      // Garde-fou perte max — fermer si perte >= cap (fallback broker sans SL)
      if(curProfit <= -maxLoss)
      {
         Print(StringFormat("[TradeManager] 🛑 %s #%llu perte $%.2f >= -$%.2f — fermeture urgente",
               sym, ticket, curProfit, maxLoss));
         trade.PositionClose(ticket);
         continue;
      }

      bool doTrail = UseTrailing || g_states[idx].forceTrailing;
      if(!doTrail) continue;

      double sl0    = g_states[idx].originalSL;
      double slDist = (sl0 > 0 && ep > 0) ? MathAbs(ep - sl0) : g_states[idx].slDist;
      if(slDist <= 0) continue;
      if(ep == 0) continue;

      double bid       = SymbolInfoDouble(sym, SYMBOL_BID);
      double profitPts = (dir == 1) ? (bid - ep) : (ep - bid);

      // ⭐ ACTIVATION: USD OU pips (priorité USD pour rapidité)
      // Calculer profit en USD
      double tickVal     = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double tickSz      = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double lot         = posInfo.Volume();
      double profitPerPt = (tickSz > 0) ? (tickVal / tickSz) * lot : lot;
      double profitUSD   = (profitPerPt > 0) ? (profitPts * profitPerPt) : curProfit;

      // Activer dès que profit >= seuil OU si un pic a déjà dépassé l'armement giveback
      // (dans tous les cas, ManageProfitGivebackExit() protège aussi par fermeture marché)
      bool shouldActivate = (profitUSD >= TrailActivateUSD) ||
                            (ticketPeak >= ProfitGivebackArmUSD) ||
                            (g_states[idx].forceTrailing && profitPts >= slDist * 0.1);

      // 🔍 LOG: Activation check
      static datetime lastLog = 0;
      if(TimeCurrent() - lastLog > 5)  // Log tous les 5s max pour ne pas spammer
      {
         Print(StringFormat("[TradeManager] 🔍 %s Trailing: profitUSD=$%.2f (seuil=$%.2f) → %s | profitPts=%.5f peak=$%.2f",
               sym, profitUSD, TrailActivateUSD, (shouldActivate ? "✅ ACTIVER" : "⏳ Attendre"),
               profitPts, g_states[idx].peakProfit));
         lastLog = TimeCurrent();
      }

      if(!shouldActivate) continue;

      // Nouveau SL = verrouiller % du pic de profit
      if(profitPerPt <= 0) continue;  // déjà calculé plus haut

      double lockPct = g_states[idx].forceTrailing ? 0.5 : TrailLockPct;
      double peakUse = MathMax(g_states[idx].peakProfit, ticketPeak);
      double lockPts = (peakUse * lockPct) / profitPerPt;
      int    dg      = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      double newSL   = NormalizeDouble((dir == 1) ? ep + lockPts : ep - lockPts, dg);
      double minMove = SymbolInfoDouble(sym, SYMBOL_POINT) * 3;

      bool better = (dir == 1) ? (newSL > curSL + minMove)
                               : (curSL == 0 || newSL < curSL - minMove);
      if(!better) continue;

      if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
      {
         Print(StringFormat("[TradeManager] ✅ %s Trailing SL ACTIVÉ: %.5f→%.5f | profit=$%.2f peak=$%.2f | verrouille=%.1f%% du pic",
               sym, curSL, newSL, curProfit, g_states[idx].peakProfit, lockPct * 100));
         Print(StringFormat("[TradeManager] 🛡️ %s Perte maximale acceptée: %.5f (%.1f%% sous entry)",
               sym, (dir == 1 ? ep - newSL : newSL - ep), ((ep - newSL) / slDist * 100)));
         SyncSLTPToServer(posInfo.Ticket(), newSL, posInfo.TakeProfit(), "ea_trailing");
      }
   }
}

//+------------------------------------------------------------------+
//| DÉTECTION FERMETURE — marquer en attente re-entrée               |
//+------------------------------------------------------------------+
void CheckAllReEntries()
{
   for(int i = 0; i < g_stateCount; i++)
   {
      if(g_states[i].reEntryCount >= ReEntryMaxPerSymbol) continue;

      if(!g_states[i].waitingReEntry)
      {
         if(!SymbolHasPosition(g_states[i].symbol))
         {
            double closePrice = GetLastClosePrice(g_states[i].symbol);
            g_states[i].closeTime      = TimeCurrent();
            g_states[i].closePrice     = closePrice;
            g_states[i].waitingReEntry = true;
            g_states[i].peakProfit     = 0;
            Print(StringFormat("[TradeManager] 🔴 %s fermé @ %.5f — attente re-entrée sur EMA%d/EMA%d",
                  g_states[i].symbol, closePrice, EMA_Fast, EMA_Slow));
         }
      }
      else
         TryReEntryOnEMA(i);
   }
}

//+------------------------------------------------------------------+
//| RE-ENTRÉE SUR L'EMA LA PLUS PROCHE                               |
//+------------------------------------------------------------------+
void TryReEntryOnEMA(int idx)
{
   string sym = g_states[idx].symbol;
   int    dir = g_states[idx].direction;

   // Limite par symbole toujours vérifiée — limite globale exemptée pour re-entrée tendance
   if(IsGlobalPositionLimitReachedForReEntry(sym)) return;
   if(CountManagedPositions(sym) >= MaxPositionsPerSymbol)
   {
      PrintOnce(StringFormat("[TM-EMA] %s: max %d positions atteint — re-entrée EMA bloquée",
            sym, MaxPositionsPerSymbol), 60);
      return;
   }

   // Cooldown minimal
   if(g_states[idx].lastReEntry > 0 &&
      (int)(TimeCurrent() - g_states[idx].lastReEntry) < ReEntryCooldownSec)
      return;

   double bid    = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask    = SymbolInfoDouble(sym, SYMBOL_ASK);
   double spread = ask - bid;
   if(spread <= 0) spread = SymbolInfoDouble(sym, SYMBOL_POINT);

   // Lire EMA fast et EMA slow (bougie précédente fermée = index 1)
   double emaFast = 0.0, emaSlow = 0.0;
   double bufF[], bufS[];
   ArraySetAsSeries(bufF, true);
   ArraySetAsSeries(bufS, true);
   bool hasFast = (g_states[idx].hEMAFast != INVALID_HANDLE &&
                   CopyBuffer(g_states[idx].hEMAFast, 0, 1, 1, bufF) > 0);
   bool hasSlow = (g_states[idx].hEMASlow != INVALID_HANDLE &&
                   CopyBuffer(g_states[idx].hEMASlow, 0, 1, 1, bufS) > 0);
   if(hasFast) emaFast = bufF[0];
   if(hasSlow) emaSlow = bufS[0];

   if(!hasFast && !hasSlow)
   {
      PrintOnce("[TradeManager] " + sym + ": aucune EMA disponible", 120);
      return;
   }

   // Prix de référence selon direction
   double refPx = (dir == 1) ? bid : ask;

   // Choisir l'EMA la plus proche
   double distFast = hasFast ? MathAbs(refPx - emaFast) : 1e10;
   double distSlow = hasSlow ? MathAbs(refPx - emaSlow) : 1e10;
   double targetEMA;
   int    emaUsed;
   if(distFast <= distSlow) { targetEMA = emaFast; emaUsed = EMA_Fast; }
   else                     { targetEMA = emaSlow; emaUsed = EMA_Slow; }

   // Prix doit être du bon côté (direction confirmée par l'EMA)
   if(RequireCorrectSide)
   {
      bool correctSide = (dir == 1) ? (bid >= targetEMA - spread * 2)
                                    : (ask <= targetEMA + spread * 2);
      if(!correctSide)
      {
         PrintOnce(StringFormat("[TradeManager] %s: prix mauvais côté EMA%d=%.5f bid=%.5f",
               sym, emaUsed, targetEMA, bid), 120);
         return;
      }
   }

   // Vérifier le toucher de l'EMA
   double tolerance = spread * MathMax(EMATouch_Pct, 0.3);
   if(MathAbs(refPx - targetEMA) > tolerance)
   {
      PrintOnce(StringFormat("[TradeManager] %s attente EMA%d=%.5f | ref=%.5f dist=%.5f tol=%.5f",
            sym, emaUsed, targetEMA, refPx, MathAbs(refPx - targetEMA), tolerance), 60);
      return;
   }

   // Filtre RSI
   if(g_states[idx].hRSI != INVALID_HANDLE)
   {
      double rBuf[];
      ArraySetAsSeries(rBuf, true);
      if(CopyBuffer(g_states[idx].hRSI, 0, 1, 1, rBuf) >= 1)
      {
         double rsi = rBuf[0];
         if(dir ==  1 && rsi < RSI_BuyMin)
         {
            PrintOnce(StringFormat("[TradeManager] %s BUY bloqué RSI=%.1f < %.1f", sym, rsi, RSI_BuyMin), 120);
            return;
         }
         if(dir == -1 && rsi > RSI_SellMax)
         {
            PrintOnce(StringFormat("[TradeManager] %s SELL bloqué RSI=%.1f > %.1f", sym, rsi, RSI_SellMax), 120);
            return;
         }
      }
   }

   // Bloquer si M1/M5 vont contre H1/H4 (micro-correction)
   if(IsGOMCorrectionZone(dir))
   {
      PrintOnce(StringFormat("[TM-EMA] %s re-entrée bloquée — zone correction", sym), 60);
      return;
   }

   // EMA fast DOIT être du bon côté pour confirmer la direction
   if(hasFast)
   {
      bool fastSideOk = (dir == 1) ? (refPx > emaFast) : (refPx < emaFast);
      if(!fastSideOk)
      {
         PrintOnce(StringFormat("[TM-EMA] %s re-entrée bloquée — prix mauvais côté EMA%d=%.5f",
               sym, EMA_Fast, emaFast), 60);
         return;
      }
   }

   // Si les deux EMAs sont disponibles, la fast doit être alignée sur la slow aussi
   if(hasFast && hasSlow)
   {
      bool emaAligned = (dir == 1) ? (emaFast > emaSlow) : (emaFast < emaSlow);
      if(!emaAligned)
      {
         PrintOnce(StringFormat("[TM-EMA] %s re-entrée bloquée — EMA%d/EMA%d non alignées",
               sym, EMA_Fast, EMA_Slow), 60);
         return;
      }
   }

   // Bloquer si KOLA dit l'opposé de la direction (ex: BUY mais KOLA=NEAR SELL)
   if(dir == 1  && StringCompare(g_lastKOLAState, "NEAR SELL") == 0)
   {
      PrintOnce(StringFormat("[TM-EMA] %s re-entrée BUY bloquée — KOLA=%s (contradiction)",
            sym, g_lastKOLAState), 60);
      return;
   }
   if(dir == -1 && StringCompare(g_lastKOLAState, "NEAR BUY") == 0)
   {
      PrintOnce(StringFormat("[TM-EMA] %s re-entrée SELL bloquée — KOLA=%s (contradiction)",
            sym, g_lastKOLAState), 60);
      return;
   }

   // Exiger que le prix soit proche du niveau OB entry ou du niveau KOLA
   // — évite les re-entrées en plein milieu au lieu du niveau de structure
   if(GOMWaitPullbackToKola)
   {
      double kolaLevel = (dir == 1) ? g_lastKolaBuy : g_lastKolaSell;
      double obLevel   = (g_setupValid && g_setupDir == dir) ? g_setupEntry : 0.0;

      // Tolérance : 0.1% du prix
      double tol = refPx * 0.001;

      bool nearKola = (kolaLevel > 0) && (MathAbs(refPx - kolaLevel) <= tol);
      bool nearOB   = (obLevel   > 0) && (MathAbs(refPx - obLevel)   <= tol);

      if(kolaLevel > 0 || obLevel > 0)
      {
         if(!nearKola && !nearOB)
         {
            PrintOnce(StringFormat("[TM-EMA] %s re-entrée bloquée — prix %.5f loin OB=%.5f KOLA=%.5f (tol=%.5f)",
                  sym, refPx, obLevel, kolaLevel, tol), 60);
            return;
         }
      }
   }

   // Filtre consolidation — ne pas re-entrer si marché en range serré
   if(IsConsolidating(idx))
      return;

   // Filtre alignement signal TA/MCP — direction doit correspondre au biais
   if(!IsDirectionAligned(sym, dir))
      return;

   // Cooldown après un échec (évite spam "Invalid stops" en boucle)
   if(g_states[idx].lastReEntryFail > 0 &&
      (int)(TimeCurrent() - g_states[idx].lastReEntryFail) < ReEntryCooldownSec * 3)
      return;

   // SL/TP : distance min obligatoire imposée par le broker (STOPS_LEVEL)
   double tickVal   = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSz    = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double lot       = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   int    dg        = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double pt        = SymbolInfoDouble(sym, SYMBOL_POINT);
   int    stopsLvl  = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   int    freezeLvl = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);
   double minBroker = (double)MathMax(stopsLvl + freezeLvl + 5, 10) * pt;

   // Distance SL depuis MaxRiskUSD
   double slDist = (tickSz > 0 && tickVal > 0 && lot > 0)
                   ? MaxRiskUSD * tickSz / (lot * tickVal)
                   : 0;

   // Si le risque $5 donne une distance < minimum broker → élargir au minimum
   if(slDist < minBroker)
   {
      double slDistBroker = minBroker;
      double dollarAtMin  = (tickSz > 0 && tickVal > 0 && lot > 0)
                            ? slDistBroker * lot * tickVal / tickSz
                            : 0;
      Print(StringFormat("[TradeManager] ⚠️ %s minBroker=%.5f > slDist=%.5f ($%.2f) — trailing forcé | maxLoss=$%.2f",
            sym, minBroker, slDist, dollarAtMin, MaxRiskUSD));
      g_states[idx].forceTrailing   = true;
      g_states[idx].waitingReEntry  = false;
      g_states[idx].lastReEntryFail = TimeCurrent();
      // Ouvrir sans SL/TP — TradeManager gérera via trailing+garde-fou
      bool ok0 = (dir == 1) ? trade.Buy(lot, sym, 0, 0, 0, "TM_EMA_RE_TRAIL")
                             : trade.Sell(lot, sym, 0, 0, 0, "TM_EMA_RE_TRAIL");
      if(ok0)
      {
         double entryPx0 = (dir == 1) ? ask : bid;
         g_states[idx].reEntryCount++;
         g_states[idx].lastReEntry   = TimeCurrent();
         g_states[idx].openPrice     = entryPx0;
         g_states[idx].slDist        = slDistBroker;
         g_states[idx].tpDist        = slDistBroker * 2.0;
         g_states[idx].peakProfit    = 0;
         ResetStagnationState(idx);
         Print(StringFormat("[TradeManager] ✅ %s re-entrée SANS SL/TP (trailing forcé) #%d @ %.5f",
               sym, g_states[idx].reEntryCount, entryPx0));
      }
      else
         Print(StringFormat("[TradeManager] ❌ %s re-entrée sans SL/TP ÉCHOUÉE: %d",
               sym, (int)trade.ResultRetcode()));
      return;
   }

   double tpDist  = (tickSz > 0 && tickVal > 0 && lot > 0)
                    ? TargetProfitUSD * tickSz / (lot * tickVal)
                    : slDist * 2.0;
   tpDist = MathMax(tpDist, minBroker);

   double entryPx = (dir == 1) ? ask : bid;
   double newSL   = NormalizeDouble((dir == 1) ? entryPx - slDist : entryPx + slDist, dg);
   double newTP   = NormalizeDouble((dir == 1) ? entryPx + tpDist : entryPx - tpDist, dg);

   bool ok = (dir == 1) ? trade.Buy(lot, sym, 0, newSL, newTP, "TM_EMA_RE")
                        : trade.Sell(lot, sym, 0, newSL, newTP, "TM_EMA_RE");
   if(ok)
   {
      g_states[idx].reEntryCount++;
      g_states[idx].lastReEntry    = TimeCurrent();
      g_states[idx].lastReEntryFail= 0;
      g_states[idx].waitingReEntry = false;
      g_states[idx].openPrice      = entryPx;
      ResetStagnationState(idx);
      g_states[idx].originalSL     = newSL;
      g_states[idx].originalTP     = newTP;
      g_states[idx].slDist         = slDist;
      g_states[idx].tpDist         = tpDist;
      g_states[idx].peakProfit     = 0;
      g_states[idx].forceTrailing  = false;

      // Vérifier que le SL/TP est bien posé sur la position réelle
      Sleep(200);
      for(int pi = PositionsTotal()-1; pi >= 0; pi--)
      {
         if(!posInfo.SelectByIndex(pi)) continue;
         if(posInfo.Symbol() != sym) continue;
         if(MagicFilter > 0 && posInfo.Magic() != MagicFilter) continue;
         if(posInfo.StopLoss() == 0 || posInfo.TakeProfit() == 0)
         {
            if(trade.PositionModify(posInfo.Ticket(), newSL, newTP))
            {
               Print(StringFormat("[TradeManager] 🔧 %s SL/TP reposé après re-entrée SL=%.5f TP=%.5f", sym, newSL, newTP));
               SyncSLTPToServer(posInfo.Ticket(), newSL, newTP, "ea_reentry");
            }
            else
            {
               g_states[idx].forceTrailing = true;
               Print(StringFormat("[TradeManager] ⚠️ %s SL/TP toujours refusé — trailing forcé | maxLoss=$%.2f", sym, MaxRiskUSD));
            }
         }
         break;
      }

      string msg = StringFormat("EMA%d Re-entrée #%d %s %s @ %.5f | lot=%.2f SL=%.5f TP=%.5f",
            emaUsed, g_states[idx].reEntryCount,
            (dir==1?"BUY":"SELL"), sym, entryPx, lot, newSL, newTP);
      Print("[TradeManager] ✅ ", msg);
      SendNotification("✅ " + msg);
   }
   else
   {
      g_states[idx].lastReEntryFail = TimeCurrent();
      Print(StringFormat("[TradeManager] ❌ %s re-entrée EMA%d ÉCHOUÉE: %d %s",
            sym, emaUsed, (int)trade.ResultRetcode(), trade.ResultComment()));
   }
}

//+------------------------------------------------------------------+
//| PROFIT GLOBAL — ferme tout, re-entre sur EMA                     |
//+------------------------------------------------------------------+
bool PositionIncludedInGlobalProfit()
{
   if(GlobalProfitMCPOnly && UseMCPSignals)
      return (posInfo.Magic() == (long)MCPMagicNumber);
   if(MagicFilter > 0)
      return (posInfo.Magic() == (long)MagicFilter);
   return true;
}

void CheckGlobalProfit()
{
   if(!g_globalCloseDone)
   {
      double totalProfit = 0.0;
      int    nCounted    = 0;
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         if(!posInfo.SelectByIndex(i)) continue;
         if(!PositionIncludedInGlobalProfit()) continue;
         totalProfit += posInfo.Profit() + posInfo.Swap();
         nCounted++;
      }
      if(nCounted == 0 || totalProfit < GlobalProfitTargetUSD) return;

      Print(StringFormat("[TradeManager] 🎯 PROFIT GLOBAL $%.2f >= $%.2f (%d pos) — fermeture",
            totalProfit, GlobalProfitTargetUSD, nCounted));
      SendNotification(StringFormat("🎯 TradBOT: $%.2f atteint — fermeture globale (%d pos)", totalProfit, nCounted));
      SendWAEvent("GLOBAL_TP", _Symbol, 0, totalProfit, "", 0, 0, 0, 0,
                  StringFormat("Profit combine $%.2f >= $%.2f", totalProfit, GlobalProfitTargetUSD));

      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         if(!posInfo.SelectByIndex(i)) continue;
         if(!PositionIncludedInGlobalProfit()) continue;
         trade.PositionClose(posInfo.Ticket());
      }

      g_globalCloseDone = true;
      g_globalCloseTime = TimeCurrent();

      for(int i = 0; i < g_stateCount; i++)
      {
         g_states[i].waitingReEntry = true;
         g_states[i].reEntryCount   = 0;
         g_states[i].lastReEntry    = 0;
         g_states[i].peakProfit     = 0;
         g_states[i].forceTrailing  = false;
         g_states[i].closeTime      = TimeCurrent();
      }
      return;
   }

   // Re-entrée sur EMA après fermeture globale — même logique que CheckAllReEntries
   bool anyOpen = false;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(!PositionIncludedInGlobalProfit()) continue;
      anyOpen = true; break;
   }
   if(anyOpen) { g_globalCloseDone = false; return; }

   for(int i = 0; i < g_stateCount; i++)
   {
      if(!g_states[i].waitingReEntry) continue;
      TryReEntryOnEMA(i);
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| HELPERS JSON (extraction simple sans lib)                        |
//+------------------------------------------------------------------+
double JsonGetDouble(const string &body, const string key, double def = 0.0)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(body, search);
   if(pos < 0) return def;
   pos += StringLen(search);
   while(pos < StringLen(body) && StringGetCharacter(body, pos) == ' ') pos++;
   string sub = StringSubstr(body, pos, 32);
   for(int i = 0; i < StringLen(sub); i++)
   {
      ushort c = StringGetCharacter(sub, i);
      if(c == ',' || c == '}' || c == ' ' || c == '\n' || c == '\r') { sub = StringSubstr(sub,0,i); break; }
   }
   return StringToDouble(sub);
}

string JsonGetString(const string &body, const string key)
{
   string search = "\"" + key + "\":\"";
   int pos = StringFind(body, search);
   if(pos < 0) return "";
   pos += StringLen(search);
   int end = StringFind(body, "\"", pos);
   if(end < 0) return "";
   return StringSubstr(body, pos, end - pos);
}

bool JsonGetBool(const string &body, const string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(body, search);
   if(pos < 0) return false;
   pos += StringLen(search);
   while(pos < StringLen(body) && StringGetCharacter(body, pos) == ' ') pos++;
   return (StringGetCharacter(body, pos) == 't');
}

//+------------------------------------------------------------------+
//| WHATSAPP — envoi via ai_server /notify-whatsapp                  |
//+------------------------------------------------------------------+
void SendWAEvent(const string event, const string sym,
                 double price = 0, double profit = 0,
                 const string direction = "", double entry = 0,
                 double sl = 0, double tp1 = 0, double lot = 0,
                 const string customMsg = "")
{
   if(!UseWhatsApp) return;

   string url = AIServerURL + "/notify-whatsapp";
   string json = StringFormat(
      "{\"event\":\"%s\","
      "\"symbol\":\"%s\","
      "\"price\":%.5f,"
      "\"profit\":%.2f,"
      "\"direction\":\"%s\","
      "\"entry_price\":%.5f,"
      "\"sl\":%.5f,"
      "\"tp1\":%.5f,"
      "\"lot\":%.2f,"
      "\"message\":\"%s\"}",
      event, sym, price, profit, direction, entry, sl, tp1, lot, customMsg
   );

   char postData[], result[];
   string headers = "Content-Type: application/json\r\n";
   string respH;
   StringToCharArray(json, postData, 0, StringLen(json));
   ArrayResize(postData, StringLen(json));
   int code = WebRequest("POST", url, headers, WATimeoutMs, postData, result, respH);
   if(code != 200)
      Print(StringFormat("[TradeManager] ⚠️ WhatsApp notify %s code=%d", event, code));
}

//+------------------------------------------------------------------+
//| Symbole déjà dans la file MCP active/exécutée (+ timeout vieux signaux)
//+------------------------------------------------------------------+
bool MCPHasSignalForSymbol(const string sym)
{
   datetime now = TimeCurrent();
   for(int k = 0; k < g_mcpCount; k++)
   {
      if(g_mcpSignals[k].symbol != sym) continue;

      // Vérifier l'âge du signal (timeout: 5 minutes = 300 sec)
      int signalAge = (int)(now - g_mcpSignals[k].receivedAt);

      // Si signal EXÉCUTÉ mais très vieux (>10 min), il peut être remplacé
      if(g_mcpSignals[k].executed && signalAge > 600)
      {
         Print(StringFormat("[TradeManager] ⚠️ %s: Ancien signal exécuté (age=%d sec) → REMPLACEABLE", sym, signalAge));
         continue;  // Ne le compte pas comme "ayant signal"
      }

      // Si signal ACTIF (pas exécuté) mais vieux (>5 min), le supprimer et remplacer
      if(g_mcpSignals[k].active && !g_mcpSignals[k].executed && signalAge > 300)
      {
         Print(StringFormat("[TradeManager] 🔄 %s: Signal READY expiré après %d sec → REMPLACEMENT", sym, signalAge));
         g_mcpSignals[k].active = false;  // Marquer comme inactif pour permettre nouveau signal
         continue;
      }

      // Signal actif et jeune → compte comme "ayant signal"
      if(g_mcpSignals[k].active || g_mcpSignals[k].executed)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Enregistre + exécute un pending-order JSON pour un symbole       |
//+------------------------------------------------------------------+
void IngestPendingOrderForSymbol(const string sym, const string &body)
{
   bool isXau = (StringCompare(sym, "XAUUSD") == 0);

   if(!JsonGetBool(body, "ok"))
   {
      if(isXau) Print(StringFormat("[TradeManager] ❌ %s: JSON 'ok'=false — IGNORE", sym));
      return;
   }

      int orderPos = StringFind(body, "\"order\":{");
   if(orderPos < 0)
   {
      if(isXau) Print(StringFormat("[TradeManager] ❌ %s: no 'order' field — IGNORE", sym));
      return;
   }
      string orderBody = StringSubstr(body, orderPos);

   string action = JsonGetString(orderBody, "action");
   if(StringLen(action) == 0) action = JsonGetString(orderBody, "recommendation");
   StringToUpper(action);
   double entry = JsonGetDouble(orderBody, "entry_price");
   double sl    = JsonGetDouble(orderBody, "stop_loss");
   double tp    = JsonGetDouble(orderBody, "take_profit");
   double lot   = JsonGetDouble(orderBody, "lot");
      if(lot <= 0) lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

   string execType = JsonGetString(orderBody, "execution_type");
   StringToLower(execType);
   bool atMarket = MCPExecuteAtMarket || (execType == "market" || StringLen(execType) == 0);

   if(StringLen(action) == 0)
   {
      if(isXau) Print(StringFormat("[TradeManager] ❌ %s: no action — IGNORE", sym));
      return;
   }
   if(action != "BUY" && action != "SELL")
   {
      if(isXau) Print(StringFormat("[TradeManager] ❌ %s: action=%s (not BUY/SELL) — IGNORE", sym, action));
      return;
   }

   if(isXau) Print(StringFormat("[TradeManager] ✅ %s: Found %s order (entry=%.2f SL=%.2f TP=%.2f lot=%.2f)",
         sym, action, entry, sl, tp, lot));

   // ⭐ PRIORITÉ GOM: GOOD/PERFECT ou signal score fort (sell>>buy)
   if(UseGOMScalp && (TimeCurrent() - g_lastGOMPoll) < GOMSignalMaxAgeSec)
   {
      int    gomDir = 0, effVnum = 0;
      string actTag;
      if(!ResolveGOMActionable(gomDir, effVnum, actTag))
      {
         if(isXau) Print(StringFormat("[TradeManager] 🔴 %s: GOM %s (vnum=%d) — pas actionable → REJETÉ",
               sym, g_lastGOMVerdict, g_lastGOMVerdictNum));
         SendNotification(StringFormat("🔴 TradBOT: Ordre %s rejeté — GOM=%s (faible)", action, g_lastGOMVerdict));
         return;
      }

      int mcpDir = (action == "BUY") ? 1 : -1;
      if(gomDir != 0 && gomDir != mcpDir)
      {
         // Conflit MCP vs GOM : rejeter le signal MCP.
         // GOM auto-entry (CheckGOMAutoEntry) tourne toutes les 1s et placera
         // lui-même le trade dans le bon sens avec les vrais niveaux KOLA
         // dès que verdict_num reste GOOD/PERFECT — pas besoin d'inverser ici.
         Print(StringFormat("[TradeManager] 🚫 %s: CONFLIT GOM %s vs signal=%s — REJETÉ | GOM auto-entry prendra le relais",
               sym, actTag, action));
         return;
      }

      if(ShouldBlockGOMConsolidationForEntry(effVnum))
      {
         if(isXau) Print(StringFormat("[TradeManager] 🟡 %s: consolidation GOM=%s KOLA=%s → ATTENDRE",
               sym, g_lastGOMVerdict, g_lastKOLAState));
         SendNotification(StringFormat("🟡 TradBOT: %s consolidation GOM/KOLA", sym));
         return;
      }

      // 🧭 Anti micro-correction: tendance TF Global forte dans l'autre sens → attendre
      if(GOMIsCounterTrendEntryBlocked(mcpDir))
      {
         if(isXau) Print(StringFormat("[TradeManager] 🧭 %s: entrée %s bloquée (TF Global=%s force=%d) → ATTENDRE",
               sym, action, g_lastGOMGlobalDir, g_lastGOMGlobalStrength));
         return;
      }

      // 🎯 Pullback OM: n'entrer que quand KOLA indique un retest (NEAR BUY/SELL)
      if(GOMWaitPullbackToKola)
      {
         if(mcpDir == -1 && StringCompare(g_lastKOLAState, "NEAR SELL") != 0)
         {
            if(isXau) Print(StringFormat("[TradeManager] ⏳ %s: attente pullback OM (KOLA=%s) avant SELL",
                  sym, g_lastKOLAState));
            return;
         }
         if(mcpDir == 1 && StringCompare(g_lastKOLAState, "NEAR BUY") != 0)
         {
            if(isXau) Print(StringFormat("[TradeManager] ⏳ %s: attente pullback OM (KOLA=%s) avant BUY",
                  sym, g_lastKOLAState));
            return;
         }
      }

      if(isXau) Print(StringFormat("[TradeManager] ✅ %s: GOM OK — %s | KOLA=%s",
            sym, actTag, g_lastKOLAState));
   }
   else if(isXau && UseGOMScalp)
      Print(StringFormat("[TradeManager] ⏭️ %s: GOM check SKIPPED (verdict > %ds)", sym, GOMSignalMaxAgeSec));

   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(atMarket && entry <= 0)
      entry = (action == "BUY") ? ask : bid;
   if(entry <= 0) return;

   // 🔧 VALIDATION SL/TP + AUTO-CORRECTION (FIX: adjust invalid levels vs reject)
   int dig = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   int tradeStopsLevel = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double minSLDist = (double)tradeStopsLevel * SymbolInfoDouble(sym, SYMBOL_POINT);
   if(minSLDist <= 0) minSLDist = 10 * SymbolInfoDouble(sym, SYMBOL_POINT);  // Fallback: 10 pts

   if(sl > 0 && tp > 0)
   {
      bool slValid = false, tpValid = false;

      if(action == "BUY")
      {
         slValid = (sl < bid);  // SL doit être EN-DESSOUS du bid
         tpValid = (tp > ask);  // TP doit être AU-DESSUS du ask

         // Auto-correction si invalide
         if(!slValid)
         {
            double correctedSL = bid - minSLDist;
            Print(StringFormat("[TradeManager] 🔧 %s BUY: SL=%.5f invalid (>= bid %.5f) → auto-correct to %.5f",
                  sym, sl, bid, correctedSL));
            sl = correctedSL;
            slValid = true;
         }
         if(!tpValid)
         {
            double correctedTP = ask + minSLDist * 2;
            Print(StringFormat("[TradeManager] 🔧 %s BUY: TP=%.5f invalid (<= ask %.5f) → auto-correct to %.5f",
                  sym, tp, ask, correctedTP));
            tp = correctedTP;
            tpValid = true;
         }

         if(isXau) Print(StringFormat("[TradeManager] ✅ %s BUY validation: ask=%.5f bid=%.5f | SL=%.5f TP=%.5f (corrected if needed)",
               sym, ask, bid, sl, tp));
      }
      else if(action == "SELL")
      {
         slValid = (sl > ask);  // SL doit être AU-DESSUS du ask
         tpValid = (tp < bid);  // TP doit être EN-DESSOUS du bid

         // Auto-correction si invalide
         if(!slValid)
         {
            double correctedSL = ask + minSLDist;
            Print(StringFormat("[TradeManager] 🔧 %s SELL: SL=%.5f invalid (<= ask %.5f) → auto-correct to %.5f",
                  sym, sl, ask, correctedSL));
            sl = correctedSL;
            slValid = true;
         }
         if(!tpValid)
         {
            double correctedTP = bid - minSLDist * 2;
            Print(StringFormat("[TradeManager] 🔧 %s SELL: TP=%.5f invalid (>= bid %.5f) → auto-correct to %.5f",
                  sym, tp, bid, correctedTP));
            tp = correctedTP;
            tpValid = true;
         }

         if(isXau) Print(StringFormat("[TradeManager] ✅ %s SELL validation: ask=%.5f bid=%.5f | SL=%.5f TP=%.5f (corrected if needed)",
               sym, ask, bid, sl, tp));
      }
   }
   else if(isXau && (sl <= 0 || tp <= 0)) Print(StringFormat("[TradeManager] ⚠️ %s: SL/TP missing (SL=%.2f TP=%.2f) — skipping validation", sym, sl, tp));

   if(MCPHasSignalForSymbol(sym))
   {
      if(isXau) Print(StringFormat("[TradeManager] ⏭️ %s: Signal already queued — SKIP", sym));
      return;
   }

   // Bloquer si une position MCP est déjà ouverte (évite double ouverture quand GOM-Auto a déjà ouvert)
   if(HasMCPOpenPosition(sym))
   {
      if(isXau) Print(StringFormat("[TradeManager] ⏭️ %s: Position MCP déjà ouverte — signal MCP ignoré", sym));
      return;
   }

      int idx = g_mcpCount;
      ArrayResize(g_mcpSignals, idx + 1);
      g_mcpCount++;
   g_mcpSignals[idx].active         = true;
   g_mcpSignals[idx].executed       = false;
   g_mcpSignals[idx].marketExec      = atMarket;
   g_mcpSignals[idx].duplicated      = false;
      g_mcpSignals[idx].symbol          = sym;
      g_mcpSignals[idx].direction       = (action == "BUY") ? 1 : -1;
      g_mcpSignals[idx].entryPrice      = entry;
      g_mcpSignals[idx].stopLoss        = sl;
      g_mcpSignals[idx].takeProfit1     = tp;
      g_mcpSignals[idx].lot             = lot;
      g_mcpSignals[idx].ticket          = 0;
      g_mcpSignals[idx].receivedAt      = TimeCurrent();
      g_mcpSignals[idx].entryNotifSent  = false;
      g_mcpSignals[idx].tp1NotifSent    = false;
      g_mcpSignals[idx].slNotifSent     = false;
   g_mcpSignals[idx].orderId         = JsonGetString(orderBody, "order_id");
   g_mcpSignals[idx].failCount       = 0;  // 🔧 Compteur d'échecs (rejeté après MaxSignalFailCount)

   if(isXau) Print(StringFormat("[TradeManager] ✅ %s: Signal QUEUED (index %d) — now calling TryExecuteMCPSignal...", sym, idx));

   Print(StringFormat("[TradeManager] 📡 Pending ready: %s %s entry=%.5f SL=%.5f TP=%.5f lot=%.2f market=%s",
         action, sym, entry, sl, tp, lot, (atMarket ? "OUI" : "NON")));

      TryExecuteMCPSignal(idx);
   }

//+------------------------------------------------------------------+
//| POLL /pending-order — signaux bridge/WhatsApp (multi-symboles)   |
//+------------------------------------------------------------------+
void PollMCPSignals()
{
   if((int)(TimeCurrent() - g_lastMCPPoll) < MCPPollIntervalSec) return;
   g_lastMCPPoll = TimeCurrent();

   // 🔍 LOG: Poll loop started
   static int pollCount = 0;
   pollCount++;

   // Poll uniquement: symbole du graphique courant + InpPollSymbols explicite
   // NE PAS inclure g_states (positions ouvertes sur d'autres graphiques) — évite
   // d'exécuter des ordres sur des symboles non attachés à ce graphique
   string syms[];
   int nsyms = 0;
   string parts[];
   int np = StringSplit(InpPollSymbols, ',', parts);
   ArrayResize(syms, np + 4);

   // 1. Symbole du graphique courant en premier
   syms[nsyms++] = _Symbol;

   // 2. Symboles explicitement listés dans InpPollSymbols
   for(int p = 0; p < np; p++)
   {
      string s = parts[p];
      StringTrimLeft(s);
      StringTrimRight(s);
      if(StringLen(s) < 2) continue;
      bool dup = false;
      for(int j = 0; j < nsyms; j++)
         if(syms[j] == s) { dup = true; break; }
      if(!dup) syms[nsyms++] = s;
   }
   // Note: g_states (positions d'autres graphiques) délibérément exclus
   // Chaque EA gère uniquement son graphique + la liste explicite

   PrintOnce(StringFormat("[TradeManager] 🔄 PollMCPSignals ENABLED (interval=%ds) | Monitoring %d symbols", MCPPollIntervalSec, nsyms), 300);

   for(int si = 0; si < nsyms; si++)
   {
      string sym = syms[si];

      // 🔍 LOG: Polling symbol
      if(StringCompare(sym, "XAUUSD") == 0)
         Print(StringFormat("[TradeManager] 🔍 Poll #%d: %s → checking if already has signal...", pollCount, sym));

      if(MCPHasSignalForSymbol(sym))
      {
         if(StringCompare(sym, "XAUUSD") == 0)
            Print(StringFormat("[TradeManager] ⏭️ Poll #%d: %s — SKIP (signal already exists)", pollCount, sym));
         continue;
      }

      string symEnc = sym;
      StringReplace(symEnc, " ", "%20");
      string url = AIServerURL + "/pending-order?symbol=" + symEnc;
      char post[], result[];
      string headers = "Content-Type: application/json\r\n";
      string respH;

      // 🔍 LOG: HTTP request
      int code = WebRequest("GET", url, headers, WATimeoutMs, post, result, respH);
      if(StringCompare(sym, "XAUUSD") == 0)
         Print(StringFormat("[TradeManager] 📡 Poll #%d: %s → HTTP %d", pollCount, sym, code));

      if(code != 200)
      {
         if(StringCompare(sym, "XAUUSD") == 0 && code != 0)
            Print(StringFormat("[TradeManager] ❌ Poll #%d: %s → HTTP error %d", pollCount, sym, code));
         continue;
      }

      string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      if(StringCompare(sym, "XAUUSD") == 0)
         Print(StringFormat("[TradeManager] ✅ Poll #%d: %s → Response (len=%d chars)", pollCount, sym, StringLen(body)));

      IngestPendingOrderForSymbol(sym, body);
   }
}

//+------------------------------------------------------------------+
//| Ouvre la 2ème jambe (duplication)                                |
//+------------------------------------------------------------------+
bool DuplicateMCPPosition(int idx, CTrade &mcpTrade)
{
   if(!MCPDuplicateOnce || g_mcpSignals[idx].duplicated) return false;
   if(IsGlobalPositionLimitReached())
   {
      Print(StringFormat("[TradeManager] 🚫 DuplicateMCP %s: limite globale %d positions atteinte", g_mcpSignals[idx].symbol, MaxGlobalPositions));
      g_mcpSignals[idx].duplicated = true;
      return false;
   }

   string sym = g_mcpSignals[idx].symbol;
   int dir = g_mcpSignals[idx].direction;
   string dupWhy;
   if(!CanDuplicateNowWithGOM(sym, dir, g_mcpSignals[idx].ticket, dupWhy))
   {
      Print(StringFormat("[TradeManager] 🚫 Duplication MCP refusée %s: %s", sym, dupWhy));
      return false;
   }
   double lot = g_mcpSignals[idx].lot;
   double sl  = g_mcpSignals[idx].stopLoss;
   double tp  = g_mcpSignals[idx].takeProfit1;

   bool ok = (dir == 1) ? mcpTrade.Buy(lot, sym, 0, sl, tp, "TM_MCP_DUP")
                        : mcpTrade.Sell(lot, sym, 0, sl, tp, "TM_MCP_DUP");
   if(ok)
   {
      g_mcpSignals[idx].duplicated = true;
      Print(StringFormat("[TradeManager] 📋 Position dupliquée %s %s lot=%.2f",
            (dir==1?"BUY":"SELL"), sym, lot));
      SendWAEvent("DUPLICATE", sym, (dir==1)?SymbolInfoDouble(sym,SYMBOL_ASK):SymbolInfoDouble(sym,SYMBOL_BID),
                  0, (dir==1?"BUY":"SELL"), g_mcpSignals[idx].entryPrice, sl, tp, lot);
   }
   else
      Print(StringFormat("[TradeManager] ⚠️ Duplication échouée %s: %d", sym, (int)mcpTrade.ResultRetcode()));
   return ok;
}

//+------------------------------------------------------------------+
//| Filtre direction TF global + cohérence (condition ajoutée)       |
//| dir: 1=BUY -1=SELL                                               |
//| Retourne true si l'entrée est autorisée, false + raison sinon.   |
//+------------------------------------------------------------------+
bool CheckGlobalDirAndCoherence(int dir, string &reason)
{
   if(!RequireGlobalDirMatch) return true;

   // 1. Cohérence GOM minimale
   if(g_lastGOMCoherence < GlobalMinCoherencePct)
   {
      reason = StringFormat("Cohérence GOM insuffisante (%.0f%% < %.0f%%)",
                            g_lastGOMCoherence, GlobalMinCoherencePct);
      return false;
   }

   // 2. Confiance TF global minimale (force = confidence proxy)
   if(g_lastGOMGlobalStrength < GlobalDirMinConfidence)
   {
      reason = StringFormat("TF global confiance insuffisante (%d%% < %d%%)",
                            g_lastGOMGlobalStrength, GlobalDirMinConfidence);
      return false;
   }

   // 3. Direction TF global doit correspondre à la direction de l'ordre
   bool globalBull = (StringCompare(g_lastGOMGlobalDir, "BULL") == 0);
   bool globalBear = (StringCompare(g_lastGOMGlobalDir, "BEAR") == 0);
   if(dir == 1 && !globalBull)
   {
      reason = StringFormat("TF global=%s (force=%d%%) — BUY non autorisé",
                            g_lastGOMGlobalDir, g_lastGOMGlobalStrength);
      return false;
   }
   if(dir == -1 && !globalBear)
   {
      reason = StringFormat("TF global=%s (force=%d%%) — SELL non autorisé",
                            g_lastGOMGlobalDir, g_lastGOMGlobalStrength);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Exécute un signal MCP si le prix est dans la tolérance d'entrée  |
//+------------------------------------------------------------------+
void TryExecuteMCPSignal(int idx)
{
   string sym  = g_mcpSignals[idx].symbol;
   bool isXau = (StringCompare(sym, "XAUUSD") == 0);

   // Règle absolue : n'exécuter que si le symbole = graphique courant
   // Un EA attaché à XAUUSD ne doit jamais ouvrir un trade USDJPY
   if(sym != _Symbol)
   {
      Print(StringFormat("[TradeManager] 🚫 %s: ordre ignoré — EA attaché à %s uniquement", sym, _Symbol));
      g_mcpSignals[idx].active = false;
      return;
   }

   if(IsGlobalPositionLimitReached())
   {
      if(isXau) Print(StringFormat("[TradeManager] 🚫 %s: Signal annulé — limite globale %d positions atteinte", sym, MaxGlobalPositions));
      return;
   }

   if(!g_mcpSignals[idx].active || g_mcpSignals[idx].executed)
   {
      if(isXau && !g_mcpSignals[idx].active) Print(StringFormat("[TradeManager] ⏭️ %s: Not active — SKIP", sym));
      if(isXau && g_mcpSignals[idx].executed) Print(StringFormat("[TradeManager] ⏭️ %s: Already executed — SKIP", sym));
      return;
   }

   if(g_mcpSignals[idx].failCount >= (int)MaxSignalFailCount)
   {
      Print(StringFormat("[TradeManager] 🚫 Signal %s abandonne apres %d echecs (max=%d)",
            sym, g_mcpSignals[idx].failCount, (int)MaxSignalFailCount));
      g_mcpSignals[idx].active = false;
      return;
   }

   int    dir  = g_mcpSignals[idx].direction;
   double ep   = g_mcpSignals[idx].entryPrice;
   double ask  = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid  = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
   {
      if(isXau) Print(StringFormat("[TradeManager] ⚠️ %s: Invalid prices (ask=%.5f bid=%.5f) — SKIP", sym, ask, bid));
      return;
   }
   double refPx = (dir == 1) ? ask : bid;
   double tol  = MathMax(ep * MCPEntryTolerancePct / 100.0, SymbolInfoDouble(sym, SYMBOL_POINT) * 5);

   if(isXau) Print(StringFormat("[TradeManager] 🔍 %s TryExecute: dir=%d entry=%.5f refPx=%.5f tol=%.5f", sym, dir, ep, refPx, tol));

   // Alerte "niveau atteint" même si on n'exécute pas encore
   if(!g_mcpSignals[idx].entryNotifSent && MathAbs(refPx - ep) <= tol * 5)
   {
      g_mcpSignals[idx].entryNotifSent = true;
      SendWAEvent("ENTRY_HIT", sym, refPx, 0, (dir==1?"BUY":"SELL"), ep,
                  g_mcpSignals[idx].stopLoss, g_mcpSignals[idx].takeProfit1, g_mcpSignals[idx].lot);
   }

   bool execNow = g_mcpSignals[idx].marketExec || MCPExecuteAtMarket;
   double priceDistance = MathAbs(refPx - ep);
   if(isXau) Print(StringFormat("[TradeManager] 🔍 %s: execNow=%s distance=%.5f tol=%.5f", sym, (execNow?"YES":"NO"), priceDistance, tol));
   if(!execNow && priceDistance > tol)
   {
      if(isXau) Print(StringFormat("[TradeManager] ⏳ %s: Distance %.5f > tolerance %.5f — waiting for price", sym, priceDistance, tol));
      return;  // limit: attendre le prix
   }

   // Sanity check: SL/TP doivent etre du bon cote du prix d'entree
   double slChk = g_mcpSignals[idx].stopLoss;
   double tpChk = g_mcpSignals[idx].takeProfit1;
   if(slChk > 0 && tpChk > 0)
   {
      bool slOk = (dir == 1) ? (slChk < refPx) : (slChk > refPx);
      bool tpOk = (dir == 1) ? (tpChk > refPx) : (tpChk < refPx);
      if(!slOk || !tpOk)
      {
         Print(StringFormat("[TradeManager] INVALID SL/TP for %s %s: price=%.5f SL=%.5f TP=%.5f — signal supprime",
               (dir==1?"BUY":"SELL"), sym, refPx, slChk, tpChk));
         g_mcpSignals[idx].active = false;
         return;
      }
   }

   // Filtre consolidation (désactivable pour signaux bridge)
   int sIdx = FindState(sym);
   if(sIdx < 0)
   {
      ScanAllPositions();
      sIdx = FindState(sym);
   }
   if(!MCPBypassConsolidation && sIdx >= 0 && IsConsolidating(sIdx))
   {
      PrintOnce(StringFormat("[TradeManager] 🔶 Signal MCP %s bloqué — consolidation élevée", sym), 120);
      return;
   }

   // Filtre biais TA : le signal MCP est autorisé SAUF si un biais TA récent dit l'inverse
   // avec forte confiance (>= 0.70) — le signal MCP a priorité si confiance TA faible
   if(RequireSignalAlign)
   {
      double conf = 0.5;
      string bias = GetBiasForSymbol(sym, conf);
      if(conf >= 0.70 && (bias == "BUY" || bias == "SELL"))
      {
         bool aligned = (dir == 1 && bias == "BUY") || (dir == -1 && bias == "SELL");
         if(!aligned)
         {
            PrintOnce(StringFormat("[TradeManager] 🚫 Signal MCP %s %s bloqué — biais TA=%s (conf=%.0f%% >= 70%%)",
                  sym, (dir==1?"BUY":"SELL"), bias, conf * 100), 120);
            return;
         }
      }
   }

   // Filtre TF global + cohérence (condition additionnelle — ne remplace pas les règles précédentes)
   {
      string globalReason;
      if(!CheckGlobalDirAndCoherence(dir, globalReason))
      {
         PrintOnce(StringFormat("[TradeManager] 🚫 MCP %s %s bloqué — %s",
               sym, (dir==1?"BUY":"SELL"), globalReason), 60);
         return;
      }
   }

   // Vérifier STOPS_LEVEL broker
   double pt       = SymbolInfoDouble(sym, SYMBOL_POINT);
   int    stopsLvl = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist  = (double)(stopsLvl + 5) * pt;
   double sl = g_mcpSignals[idx].stopLoss;
   double tp = g_mcpSignals[idx].takeProfit1;
   int    dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   // Ajuster SL/TP au minimum broker si nécessaire
   if(sl > 0 && MathAbs(refPx - sl) < minDist)
      sl = NormalizeDouble((dir==1) ? refPx - minDist : refPx + minDist, dg);
   if(tp > 0 && MathAbs(tp - refPx) < minDist)
      tp = NormalizeDouble((dir==1) ? refPx + minDist : refPx - minDist, dg);

   // Vérifier après correction que SL/TP sont du bon côté du prix
   bool slValid = (sl <= 0) || ((dir == 1) ? (sl < refPx) : (sl > refPx));
   bool tpValid = (tp <= 0) || ((dir == 1) ? (tp > refPx) : (tp < refPx));
   if(!slValid || !tpValid)
   {
      Print(StringFormat("[TradeManager] ❌ INVALID SL/TP after adjustment for %s %s: price=%.5f SL=%.5f TP=%.5f",
            (dir==1?"BUY":"SELL"), sym, refPx, sl, tp));
      g_mcpSignals[idx].active = false;
      return;
   }

   CTrade mcpTrade;
   mcpTrade.SetExpertMagicNumber(MCPMagicNumber);
   mcpTrade.SetDeviationInPoints(30);
   mcpTrade.SetTypeFilling(ORDER_FILLING_IOC);

   double lot = g_mcpSignals[idx].lot;
   bool ok = (dir == 1) ? mcpTrade.Buy(lot, sym, 0, sl, tp, "TM_MCP_SIGNAL")
                        : mcpTrade.Sell(lot, sym, 0, sl, tp, "TM_MCP_SIGNAL");
   if(ok)
   {
      g_mcpSignals[idx].executed  = true;
      g_mcpSignals[idx].active    = false;
      g_mcpSignals[idx].ticket    = 0;
      Sleep(300);
      for(int pi = PositionsTotal() - 1; pi >= 0; pi--)
      {
         if(!posInfo.SelectByIndex(pi)) continue;
         if(posInfo.Symbol() != sym) continue;
         if(posInfo.Magic() != (long)MCPMagicNumber) continue;
         g_mcpSignals[idx].ticket = posInfo.Ticket();
         break;
      }

      ScanAllPositions();
      // Duplication différée — déclenchée par MonitorMCPPositions() quand profit >= MCPDuplicateMinProfit

      // Supprimer l'ordre pending du serveur
      string symEnc = sym;
      StringReplace(symEnc, " ", "%20");
      string delUrl = AIServerURL + "/pending-order?symbol=" + symEnc;
      char dp[], dr[]; string dh;
      WebRequest("DELETE", delUrl, "Content-Type: application/json\r\n", WATimeoutMs, dp, dr, dh);

      Print(StringFormat("[TradeManager] ✅ MCP AUTO %s %s @ %.5f SL=%.5f TP=%.5f lot=%.2f ticket=%llu dup=%s",
            (dir==1?"BUY":"SELL"), sym, refPx, sl, tp, lot, g_mcpSignals[idx].ticket,
            (g_mcpSignals[idx].duplicated ? "OUI" : "NON")));

      SendWAEvent("ORDER_EXECUTED", sym, refPx, 0, (dir==1?"BUY":"SELL"), ep, sl, tp, lot);
   }
   else
   {
      g_mcpSignals[idx].failCount++;
      Print(StringFormat("[TradeManager] MCP ORDER ECHOUE %s %s: %d %s (tentative %d/3)",
            (dir==1?"BUY":"SELL"), sym,
            (int)mcpTrade.ResultRetcode(), mcpTrade.ResultRetcodeDescription(),
            g_mcpSignals[idx].failCount));
   }
}

//+------------------------------------------------------------------+
//| Duplique les positions manuelles (magic=0) quand profit >= $2    |
//+------------------------------------------------------------------+
void MonitorManualDuplicates()
{
   if(!MCPDuplicateOnce || !DuplicateManualOrders) return;
   if(IsGlobalPositionLimitReached())
   {
      Print(StringFormat("[TradeManager] 🚫 MonitorManualDup: limite globale %d positions atteinte — annulé", MaxGlobalPositions));
      return;
   }

   for(int pi = PositionsTotal() - 1; pi >= 0; pi--)
   {
      if(!posInfo.SelectByIndex(pi)) continue;

      long magic = posInfo.Magic();
      // Cibler uniquement magic=0 (manuel) ou MagicFilter si défini
      if(magic != 0 && magic != (long)MagicFilter) continue;
      // Exclure les positions déjà générées par TM (magic MCP ou duplicats TM)
      if(magic == (long)MCPMagicNumber) continue;

      ulong ticket = posInfo.Ticket();
      double profit = posInfo.Profit();
      if(!HasDupProfitStable(ticket)) continue;

      // Vérifier si déjà dupliqué
      bool alreadyDup = false;
      for(int k = 0; k < g_manualDupCount; k++)
         if(g_manualDupTickets[k] == ticket) { alreadyDup = true; break; }
      if(alreadyDup) continue;

      string sym = posInfo.Symbol();
      // Ne dupliquer que le symbole du graphique courant
      if(sym != _Symbol) continue;
      if(IsBoomOrCrashSymbol(sym)) continue;

      int dir = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;

      // Bloquer si déjà au max de positions
      if(CountManagedPositions(sym) >= MaxPositionsPerSymbol)
      {
         Print(StringFormat("[TradeManager] 🚫 Dup manuelle refusée %s: déjà %d positions (max %d)",
               sym, CountManagedPositions(sym), MaxPositionsPerSymbol));
         // Marquer comme dupliqué pour stopper les tentatives répétées
         ArrayResize(g_manualDupTickets, g_manualDupCount + 1);
         g_manualDupTickets[g_manualDupCount++] = ticket;
         continue;
      }

      string dupWhy;
      if(!CanDuplicateNowWithGOM(sym, dir, ticket, dupWhy))
      {
         Print(StringFormat("[TradeManager] 🚫 Dup manuelle refusée %s: %s", sym, dupWhy));
         continue;
      }

      // Dupliquer
      double lot = posInfo.Volume();
      double sl  = posInfo.StopLoss();
      double tp  = posInfo.TakeProfit();

      CTrade dupTrade;
      dupTrade.SetExpertMagicNumber(MCPMagicNumber);
      dupTrade.SetDeviationInPoints(30);
      dupTrade.SetTypeFilling(ORDER_FILLING_IOC);

      bool ok = (dir == 1) ? dupTrade.Buy(lot, sym, 0, sl, tp, "TM_MANUAL_DUP")
                           : dupTrade.Sell(lot, sym, 0, sl, tp, "TM_MANUAL_DUP");
      if(ok)
      {
         ArrayResize(g_manualDupTickets, g_manualDupCount + 1);
         g_manualDupTickets[g_manualDupCount++] = ticket;
         Print(StringFormat("[TradeManager] 📋 Duplication manuelle %s %s lot=%.2f profit=$%.2f",
               (dir==1?"BUY":"SELL"), sym, lot, profit));
         SendWAEvent("DUPLICATE", sym,
                     (dir==1)?SymbolInfoDouble(sym,SYMBOL_ASK):SymbolInfoDouble(sym,SYMBOL_BID),
                     profit, (dir==1?"BUY":"SELL"), posInfo.PriceOpen(), sl, tp, lot);
      }
      else
         Print(StringFormat("[TradeManager] ⚠️ Dup manuelle échouée %s: %d", sym, (int)dupTrade.ResultRetcode()));
   }
}

//+------------------------------------------------------------------+
//| Poll /gom-verdict — FILTRE STRICT: GOOD/PERFECT uniquement       |
//| Dégradation verdict → fermer positions dupliquées ou toutes       |
//| Indicateurs exploités: scores, RSI, Coherence, Quality            |
//+------------------------------------------------------------------+
void PollGOMScalpVerdict()
{
   if(!UseGOMScalp) return;
   if((int)(TimeCurrent() - g_lastGOMPoll) < GOMPollIntervalSec) return;
   g_lastGOMPoll = TimeCurrent();

   // ── Fetch /gom-verdict (clé serveur = symbole TV, ex. XAUUSD) ──
   string sym = _Symbol;
   string fetchSym = ResolveGOMFetchSymbol(sym);
   string symEnc = EncodeSymbolForURL(fetchSym);
   string url = AIServerURL + "/gom-verdict?symbol=" + symEnc;
   char post[], result[];
   string headers = "Content-Type: application/json\r\n";
   string respH;
   int code = WebRequest("GET", url, headers, WATimeoutMs, post, result, respH);
   if(code != 200) return;

   string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   if(StringFind(body, "\"ok\":false") >= 0) return;

   // Parser indicateurs GOM complets
   string verdict       = JsonGetString(body, "verdict");
   int    rsi           = (int)JsonGetDouble(body, "rsi");
   double score_buy     = JsonGetDouble(body, "score_buy");
   double score_sell    = JsonGetDouble(body, "score_sell");
   double coherence     = JsonGetDouble(body, "coherence_pct");
   double quality       = JsonGetDouble(body, "entry_quality");
   bool   oversold      = StringFind(body, "\"rsi_oversold\":true")  >= 0;
   bool   overbought    = StringFind(body, "\"rsi_overbought\":true") >= 0;
   int    vnum          = (int)JsonGetDouble(body, "verdict_num");
   string tfGlobalDir   = JsonGetString(body, "tf_global_dir");
   int    tfStrength    = (int)JsonGetDouble(body, "tf_global_strength");

   string kolaState = JsonGetString(body, "kola_state");
   if(StringLen(kolaState) == 0)
   {
      if(StringFind(body, "NEAR BUY") >= 0)  kolaState = "NEAR BUY";
      else if(StringFind(body, "NEAR SELL") >= 0) kolaState = "NEAR SELL";
      else kolaState = "---";
   }

   // 🔴 FILTRE CRITIQUE: Accepter UNIQUEMENT GOOD/PERFECT
   //    vnum = -3 (PERFECT SELL), -2 (GOOD SELL), 0 (WAIT), +2 (GOOD BUY), +3 (PERFECT BUY)
   bool isGoodOrPerfect = (vnum == 2 || vnum == 3 || vnum == -2 || vnum == -3);
   bool isSimpleBuySell = (vnum == 1 || vnum == -1);  // "BUY"/"SELL" simples → ignorer
   bool isWait         = (vnum == 0);                  // "WAIT" → attendre

   // 🔴 DÉTECTION CONSOLIDATION: KOLA diverge du verdict
   //    GOOD/PERFECT BUY mais KOLA=NEAR SELL → consolidation
   //    GOOD/PERFECT SELL mais KOLA=NEAR BUY → consolidation
   bool isConsolidation = false;
   if(isGoodOrPerfect && vnum > 0 && StringCompare(kolaState, "NEAR SELL") == 0)
   {
      isConsolidation = true;  // Verdict BUY mais KOLA SELL → divergence
   }
   else if(isGoodOrPerfect && vnum < 0 && StringCompare(kolaState, "NEAR BUY") == 0)
   {
      isConsolidation = true;  // Verdict SELL mais KOLA BUY → divergence
   }

   g_lastGOMVerdict    = verdict;
   g_lastGOMRSI        = rsi;
   g_gomRSIOversold    = oversold;
   g_gomRSIOverbought  = overbought;
   g_lastGOMVerdictNum = vnum;
   g_lastKOLAState     = kolaState;
   g_isConsolidation   = isConsolidation;
   g_lastGOMQuality    = quality;
   g_lastGOMCoherence  = coherence;
   g_lastGOMScoreBuy   = score_buy;
   g_lastGOMScoreSell  = score_sell;
   if(StringLen(tfGlobalDir) > 0)
   {
      g_lastGOMGlobalDir = tfGlobalDir;
      StringToUpper(g_lastGOMGlobalDir);
   }
   if(tfStrength > 0) g_lastGOMGlobalStrength = tfStrength;

   g_predPath = JsonGetString(body, "pred_path");
   g_predNet  = (int)JsonGetDouble(body, "pred_net");
   g_lastGOMStDir = (int)JsonGetDouble(body, "st_dir");
   g_lastKolaBuy  = JsonGetDouble(body, "kola_buy");
   g_lastKolaSell = JsonGetDouble(body, "kola_sell");
   g_lastBBUp     = JsonGetDouble(body, "bb_up");
   g_lastBBDn     = JsonGetDouble(body, "bb_dn");
   g_setupBuyProb  = JsonGetDouble(body, "setup_buy_prob");
   g_setupSellProb = JsonGetDouble(body, "setup_sell_prob");
   g_setupValidProb = JsonGetDouble(body, "setup_valid_prob");
   g_predHitRate   = JsonGetDouble(body, "pred_direction_hit_rate");
   if(g_setupBuyProb > 1.0)  g_setupBuyProb  /= 100.0;
   if(g_setupSellProb > 1.0) g_setupSellProb /= 100.0;
   if(g_setupValidProb > 1.0) g_setupValidProb /= 100.0;
   if(g_predHitRate > 1.0) g_predHitRate /= 100.0;
   if(StringLen(g_predPath) == 0)
   {
      int pb = (int)JsonGetDouble(body, "pred_bull");
      int pbe = (int)JsonGetDouble(body, "pred_bear");
      if(pb + pbe > 0)
         PrintOnce(StringFormat("[GOM-Path] pred_path vide (bull=%d bear=%d) — redemarrer poller", pb, pbe), 90);
   }

   if(UseTVSetupLimit)
      ParseTVSetupFromGOMBody(body);

   if(ShowGOMPathCandles)
      DrawGOMPathPredictedCandles();

   // ── Scanner positions ouvertes ──────────────────────────────
   // 🟡 Si CONSOLIDATION: Fermer positions si pas de profit significatif (fausse entrée)
   if(isConsolidation)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!posInfo.SelectByIndex(i)) continue;
         string posSym = posInfo.Symbol();
         if(posSym != sym) continue;

         double profit = posInfo.Profit();
         ulong  ticket = posInfo.Ticket();
         int    dir    = posInfo.PositionType() == POSITION_TYPE_BUY ? 1 : -1;

         // Fermer si profit < $5 USD (fausse entrée en consolidation)
         if(profit < 5.0)
         {
            CTrade closeTrade;
            closeTrade.SetDeviationInPoints(50);
            if(closeTrade.PositionClose(ticket))
            {
               Print(StringFormat("[GOMScalp] 🟡 CONSOLIDATION DETECTED — Position %s fermée (profit=$%.2f < $5 seuil) — FAUSSE ENTRÉE",
                     (dir==1?"BUY":"SELL"), profit));
               SendWAEvent("CONSOLIDATION_CLOSE", posSym, posInfo.PriceCurrent(), profit,
                           (dir==1?"BUY":"SELL"), posInfo.PriceOpen(),
                           posInfo.StopLoss(), posInfo.TakeProfit(), posInfo.Volume());
            }
         }
         else
         {
            // Profit > $5: Laisser tranquille (gain suffisant)
            Print(StringFormat("[GOMScalp] 🟡 CONSOLIDATION — Position %s gardée (profit=$%.2f > $5) — trailing stop actif",
                  (dir==1?"BUY":"SELL"), profit));
         }
      }
      if(UseTVSetupLimit)
         ManageTVSetupLimitOrder();
      return;  // Sortir après gestion consolidation
   }

   if(UseTVSetupLimit)
      ManageTVSetupLimitOrder();

   int posCount = 0, dupCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      string posSym = posInfo.Symbol();
      if(posSym != sym) continue;

      int    dir    = posInfo.PositionType() == POSITION_TYPE_BUY ? 1 : -1;
      double profit = posInfo.Profit();
      ulong  ticket = posInfo.Ticket();
      string comment = posInfo.Comment();
      bool   isDuplicate = (StringFind(comment, "DUP") >= 0);

      if(isDuplicate) dupCount++;
      posCount++;

      bool   shouldClose = false;
      string closeReason = "";

      // 🎯 LOGIQUE DE DÉGRADATION: PERFECT → GOOD → WAIT/SIMPLE → fermer
      if(dir == -1) // Position SELL en cours
      {
         // Verdict dégradé de PERFECT/GOOD à WAIT/SIMPLE/BUY → fermer
         if(isWait && profit >= 0)
         {
            // WAIT: attendre avec patience, fermer si +profit sécurisation
            shouldClose = true;
            closeReason = "GOM=WAIT → calme attentif (verrouiller profit)";
         }
         else if(isSimpleBuySell && vnum > 0) // Verdict SELL dégradé en SIMPLE BUY
         {
            shouldClose = true;
            closeReason = "GOM=SIMPLE BUY (dégradation SELL) → mouvement épuisé";
         }
         else if(isGoodOrPerfect && vnum > 0) // GOOD/PERFECT BUY (opposé à SELL)
         {
            // ⭐ Logique clé: si 2 positions et vnum > 0
            if(isDuplicate)
            {
               shouldClose = true;  // Fermer SEULEMENT la position dupliquée
               closeReason = "GOM=GOOD/PERFECT BUY (opposé) → fermer DUPLICATE seulement";
            }
            else if(dupCount == 0)  // Pas de duplicate, fermer position unique
            {
               shouldClose = true;
               closeReason = "GOM=GOOD/PERFECT BUY (opposé) → fermer position unique";
            }
         }

         // Indicateurs additionnels: RSI, Quality, Coherence
         if(!shouldClose && score_sell > 0 && score_buy < score_sell - 1.5 && quality < 40)
         {
            // Qualité faible + SELL score dominé → risque, fermer si profit
            if(profit > 0)
            {
               shouldClose = true;
               closeReason = StringFormat("Quality faible (%.0f%%) + Coherence basse (%.0f%%) → sécurisation",
                     quality, coherence);
            }
         }
         else if(oversold && profit > 0 && !isGoodOrPerfect)
         {
            // RSI survente + pas de signal GOOD/PERFECT → rebond
            shouldClose = true;
            closeReason = StringFormat("RSI=%d SURVENTE (rebond imminent)", rsi);
         }
      }
      else if(dir == 1) // Position BUY en cours
      {
         // Verdict dégradé de PERFECT/GOOD à WAIT/SIMPLE/SELL → fermer
         if(isWait && profit >= 0)
         {
            shouldClose = true;
            closeReason = "GOM=WAIT → calme attentif (verrouiller profit)";
         }
         else if(isSimpleBuySell && vnum < 0) // Verdict BUY dégradé en SIMPLE SELL
         {
            shouldClose = true;
            closeReason = "GOM=SIMPLE SELL (dégradation BUY) → mouvement épuisé";
         }
         else if(isGoodOrPerfect && vnum < 0) // GOOD/PERFECT SELL (opposé à BUY)
         {
            // ⭐ Logique clé: si 2 positions et vnum < 0
            if(isDuplicate)
            {
               shouldClose = true;  // Fermer SEULEMENT la position dupliquée
               closeReason = "GOM=GOOD/PERFECT SELL (opposé) → fermer DUPLICATE seulement";
            }
            else if(dupCount == 0)  // Pas de duplicate, fermer position unique
            {
               shouldClose = true;
               closeReason = "GOM=GOOD/PERFECT SELL (opposé) → fermer position unique";
            }
         }

         // Indicateurs additionnels: RSI, Quality, Coherence
         if(!shouldClose && score_buy > 0 && score_sell < score_buy - 1.5 && quality < 40)
         {
            // Qualité faible + BUY score dominé → risque, fermer si profit
            if(profit > 0)
            {
               shouldClose = true;
               closeReason = StringFormat("Quality faible (%.0f%%) + Coherence basse (%.0f%%) → sécurisation",
                     quality, coherence);
            }
         }
         else if(overbought && profit > 0 && !isGoodOrPerfect)
         {
            // RSI surachat + pas de signal GOOD/PERFECT → retournement
            shouldClose = true;
            closeReason = StringFormat("RSI=%d SURACHAT (retournement imminent)", rsi);
         }
      }

      if(!shouldClose) continue;

      // Fermer la position
      CTrade closeTrade;
      closeTrade.SetDeviationInPoints(50);
      bool closed = closeTrade.PositionClose(ticket);

      if(closed)
      {
         Print(StringFormat("[GOMScalp] Position %s %s fermée (profit=%.2f$ RSI=%d Quality=%.0f%% Score: BUY=%.1f SELL=%.1f) Raison: %s",
               (dir==1?"BUY":"SELL"), posSym, profit, rsi, quality, score_buy, score_sell, closeReason));

         SendWAEvent("GOM_CLOSE", posSym, posInfo.PriceCurrent(), profit,
                     (dir==1?"BUY":"SELL"), posInfo.PriceOpen(),
                     posInfo.StopLoss(), posInfo.TakeProfit(), posInfo.Volume());

         // Enregistrer état pour ré-entrée (SEULEMENT si GOOD/PERFECT reste valide)
         if(GOMReEntryEnabled && isGoodOrPerfect)
         {
            int idx = g_gomReEntryCount;
            ArrayResize(g_gomReEntry, idx + 1);
            g_gomReEntryCount++;
            g_gomReEntry[idx].active       = true;
            g_gomReEntry[idx].symbol       = posSym;
            g_gomReEntry[idx].direction    = dir;
            g_gomReEntry[idx].entryPrice   = posInfo.PriceOpen();
            g_gomReEntry[idx].stopLoss     = posInfo.StopLoss();
            g_gomReEntry[idx].takeProfit   = posInfo.TakeProfit();
            g_gomReEntry[idx].lot          = GOMReEntryLot;
            g_gomReEntry[idx].closedAt     = TimeCurrent();
            g_gomReEntry[idx].reEntryCount = 0;
         }
      }
   }
}

//+------------------------------------------------------------------+
bool HasMCPOpenPosition(const string sym)
{
   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      if(!posInfo.SelectByIndex(p)) continue;
      if(posInfo.Symbol() != sym) continue;
      if(posInfo.Magic() == (long)MCPMagicNumber) return true;
   }
   return false;
}

void ComputeAutoSLTPPrices(const string sym, const int dir, const double lot,
                           const double entryPx, double &outSL, double &outTP)
{
   double tickVal = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double useLot  = (lot > 0) ? lot : SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   int    dg      = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double slDist = (tickSz > 0 && tickVal > 0 && useLot > 0)
                   ? (MaxRiskUSD * tickSz / (useLot * tickVal))
                   : 50.0 * SymbolInfoDouble(sym, SYMBOL_POINT);
   double tpDist = (tickSz > 0 && tickVal > 0 && useLot > 0)
                   ? (TargetProfitUSD * tickSz / (useLot * tickVal))
                   : 100.0 * SymbolInfoDouble(sym, SYMBOL_POINT);
   if(dir == 1)
   {
      outSL = NormalizeDouble(entryPx - slDist, dg);
      outTP = NormalizeDouble(entryPx + tpDist, dg);
   }
   else
   {
      outSL = NormalizeDouble(entryPx + slDist, dg);
      outTP = NormalizeDouble(entryPx - tpDist, dg);
   }
}

//+------------------------------------------------------------------+
//| GOOD/PERFECT ou SELL/BUY fort (écart scores) — entrée autorisée   |
//+------------------------------------------------------------------+
void SyncGOMGlobalsFromData(const GOMData &gom)
{
   if(!gom.valid) return;
   g_lastGOMVerdict    = gom.verdict;
   g_lastGOMVerdictNum = gom.verdict_num;
   g_lastGOMScoreBuy   = gom.score_buy;
   g_lastGOMScoreSell  = gom.score_sell;
   g_lastGOMQuality    = gom.entry_quality;
   g_lastGOMCoherence  = gom.coherence_pct;
   g_lastGOMRSI        = gom.rsi;
   g_lastKOLAState     = gom.kola_state;
   g_isConsolidation   = false;
   if(gom.verdict_num > 0 && StringFind(gom.kola_state, "NEAR SELL") >= 0)
      g_isConsolidation = true;
   if(gom.verdict_num < 0 && StringFind(gom.kola_state, "NEAR BUY") >= 0)
      g_isConsolidation = true;
   g_lastGOMPoll = TimeCurrent();
}

bool ResolveGOMActionable(int &dir, int &effVnum, string &tag)
{
   dir = 0;
   effVnum = g_lastGOMVerdictNum;
   tag = "";

   int v = g_lastGOMVerdictNum;
   if(v == 2 || v == 3) { dir = 1; tag = g_lastGOMVerdict; return true; }
   if(v == -2 || v == -3) { dir = -1; tag = g_lastGOMVerdict; return true; }

   if(!GOMAllowStrongSimple) return false;

   double gap = g_lastGOMScoreSell - g_lastGOMScoreBuy;
   if(gap >= GOMStrongScoreGap && g_lastGOMScoreSell > g_lastGOMScoreBuy)
   {
      dir = -1;
      effVnum = -2;
      tag = StringFormat("STRONG SELL (sell=%.1f buy=%.1f)", g_lastGOMScoreSell, g_lastGOMScoreBuy);
      return true;
   }
   gap = g_lastGOMScoreBuy - g_lastGOMScoreSell;
   if(gap >= GOMStrongScoreGap && g_lastGOMScoreBuy > g_lastGOMScoreSell)
   {
      dir = 1;
      effVnum = 2;
      tag = StringFormat("STRONG BUY (buy=%.1f sell=%.1f)", g_lastGOMScoreBuy, g_lastGOMScoreSell);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Filtre tendance globale GOM (anti micro-correction)              |
//+------------------------------------------------------------------+
bool GOMIsCounterTrendEntryBlocked(const int dir)
{
   if(!GOMUseGlobalTrendFilter) return false;
   if(g_lastGOMGlobalStrength < GOMGlobalTrendMinStrength) return false;
   if(StringCompare(g_lastGOMGlobalDir, "BEAR") == 0 && dir == 1)  return true;
   if(StringCompare(g_lastGOMGlobalDir, "BULL") == 0 && dir == -1) return true;
   return false;
}

bool ShouldBlockGOMConsolidationForEntry(const int effVnum)
{
   if(!g_isConsolidation) return false;
   if(!GOMAllowSimpleDespiteKola) return true;
   double gap = MathAbs(g_lastGOMScoreSell - g_lastGOMScoreBuy);
   if(gap < GOMStrongScoreGap) return true;
   if(effVnum <= -2 && g_lastGOMScoreSell > g_lastGOMScoreBuy) return false;
   if(effVnum >= 2 && g_lastGOMScoreBuy > g_lastGOMScoreSell) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Entrée auto depuis verdict GOM (GOOD/PERFECT) — secours EA       |
//+------------------------------------------------------------------+
void CheckGOMAutoEntry()
{
   if(!UseGOMScalp || !UseGOMAutoEntry) return;
   if(IsGlobalPositionLimitReached())
   {
      Print(StringFormat("[GOM-Auto] %s entrée bloquée — limite globale %d positions atteinte", _Symbol, MaxGlobalPositions));
      return;
   }

   string sym = _Symbol;
   if((int)(TimeCurrent() - g_lastGOMPoll) > GOMSignalMaxAgeSec) return;
   if(MCPHasSignalForSymbol(sym)) return;
   if(HasMCPOpenPosition(sym)) return;

   // Bloquer si le nombre max de positions sur ce symbole est déjà atteint
   if(CountManagedPositions(sym) >= MaxPositionsPerSymbol)
   {
      PrintOnce(StringFormat("[GOM-Auto] %s: max positions atteint (%d) — entrée bloquée",
            sym, MaxPositionsPerSymbol), 60);
      return;
   }

   int    dir = 0, effVnum = 0;
   string actTag;
   if(!ResolveGOMActionable(dir, effVnum, actTag)) return;

   if(IsGOMCorrectionZone(dir))
   {
      PrintOnce(StringFormat("[GOM-Auto] %s bloque — zone correction (attendre fin pullback)",
            sym), 35);
      return;
   }

   if(!IsGOMPathAlignedWithDir(dir))
   {
      PrintOnce(StringFormat("[GOM-Auto] %s bloque — trajectoire opposee (pred_net=%d)",
            sym, g_predNet), 35);
      return;
   }

   if(!HasSetupProbForDir(dir))
   {
      PrintOnce(StringFormat("[GOM-Auto] %s bloque — proba setup insuffisante (buy=%.0f%% sell=%.0f%% hit=%.0f%%)",
            sym, g_setupBuyProb * 100.0, g_setupSellProb * 100.0, g_predHitRate * 100.0), 45);
      return;
   }

   if(GOMIsCounterTrendEntryBlocked(dir))
   {
      Print(StringFormat("[GOM-Auto] %s entrée bloquée (micro-correction) — TF Global=%s force=%d",
            sym, g_lastGOMGlobalDir, g_lastGOMGlobalStrength));
      return;
   }

   if(ShouldBlockGOMConsolidationForEntry(effVnum))
   {
      Print(StringFormat("[GOM-Auto] %s entrée bloquée — consolidation GOM=%s KOLA=%s",
            sym, g_lastGOMVerdict, g_lastKOLAState));
      return;
   }

   if(GOMWaitPullbackToKola)
   {
      if(dir == -1 && StringCompare(g_lastKOLAState, "NEAR SELL") != 0) return;
      if(dir == 1  && StringCompare(g_lastKOLAState, "NEAR BUY")  != 0) return;
   }

   double minQ = GOMMinQuality;
   double minC = GOMMinCoherence;
   if(GOMAllowStrongSimple && effVnum >= 2 && StringCompare(g_lastKOLAState, "NEAR BUY") == 0 && dir == 1)
      minQ = MathMin(minQ, 12.0);
   if(GOMAllowStrongSimple && effVnum <= -2 && StringCompare(g_lastKOLAState, "NEAR SELL") == 0 && dir == -1)
      minQ = MathMin(minQ, 12.0);

   if(g_lastGOMQuality < minQ)
   {
      PrintOnce(StringFormat("[GOM-Auto] %s bloqué — Quality %.0f%% < %.0f%% (GOM=%s)",
            sym, g_lastGOMQuality, minQ, g_lastGOMVerdict), 45);
      return;
   }
   if(g_lastGOMCoherence < minC)
   {
      PrintOnce(StringFormat("[GOM-Auto] %s bloqué — Cohérence %.0f%% < %.0f%%",
            sym, g_lastGOMCoherence, minC), 45);
      return;
   }

   bool bypassGlobal = false;
   if(GOMAllowStrongSimple && dir == 1 && effVnum >= 2 && StringCompare(g_lastKOLAState, "NEAR BUY") == 0)
      bypassGlobal = true;
   if(GOMAllowStrongSimple && dir == -1 && effVnum <= -2 && StringCompare(g_lastKOLAState, "NEAR SELL") == 0)
      bypassGlobal = true;

   if(!bypassGlobal)
   {
      string globalReason;
      if(!CheckGlobalDirAndCoherence(dir, globalReason))
      {
         PrintOnce(StringFormat("[GOM-Auto] %s %s bloqué — %s",
               sym, (dir==1?"BUY":"SELL"), globalReason), 60);
         return;
      }
   }

   bool vnumChanged = (effVnum != g_lastGOMAutoVnum);
   if(!vnumChanged && (int)(TimeCurrent() - g_lastGOMAutoEntry) < GOMAutoEntryCooldownSec)
      return;
   if(dir == 1 && g_gomRSIOverbought) return;
   if(dir == -1 && g_gomRSIOversold) return;
   if(RequireSignalAlign && !IsDirectionAligned(sym, dir)) return;

   double lot = GOMReEntryLot;
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0 || bid <= 0) return;

   double entry = (dir == 1) ? ask : bid;
   double sl = 0, tp = 0;
   if(AutoAssignSLTP)
      ComputeAutoSLTPPrices(sym, dir, lot, entry, sl, tp);

   CTrade gomTrade;
   gomTrade.SetExpertMagicNumber(MCPMagicNumber);
   gomTrade.SetDeviationInPoints(50);
   gomTrade.SetTypeFilling(ORDER_FILLING_IOC);

   bool ok = (dir == 1) ? gomTrade.Buy(lot, sym, 0, sl, tp, "TM_GOM_AUTO")
                        : gomTrade.Sell(lot, sym, 0, sl, tp, "TM_GOM_AUTO");
   if(!ok)
   {
      Print(StringFormat("[GOM-Auto] Echec entree %s %s retcode=%d",
            (dir==1?"BUY":"SELL"), sym, (int)gomTrade.ResultRetcode()));
      return;
   }

   g_lastGOMAutoEntry = TimeCurrent();
   g_lastGOMAutoVnum  = effVnum;
   Print(StringFormat("[GOM-Auto] ENTREE %s %s | %s vnum=%d Q=%.0f%% C=%.0f%% lot=%.2f",
         (dir==1?"BUY":"SELL"), sym, actTag, effVnum,
         g_lastGOMQuality, g_lastGOMCoherence, lot));
   SendWAEvent("GOM_AUTO_ENTRY", sym, entry, 0, (dir==1?"BUY":"SELL"), entry, sl, tp, lot);
}

//+------------------------------------------------------------------+
//| Re-entrée GOM après correction                                   |
//+------------------------------------------------------------------+
void CheckGOMReEntry()
{
   if(!UseGOMScalp || !GOMReEntryEnabled) return;
   if(IsGlobalPositionLimitReachedForReEntry(_Symbol))
   {
      Print(StringFormat("[GOM-ReEntry] %s re-entrée annulée — limite globale %d positions atteinte", _Symbol, MaxGlobalPositions));
      return;
   }

   for(int i = g_gomReEntryCount - 1; i >= 0; i--)
   {
      if(!g_gomReEntry[i].active) continue;
      if(g_gomReEntry[i].reEntryCount >= GOMReEntryMaxCount)
      {
         g_gomReEntry[i].active = false;
         continue;
      }
      if((int)(TimeCurrent() - g_gomReEntry[i].closedAt) < GOMReEntryCooldownSec) continue;

      string posSym = g_gomReEntry[i].symbol;
      int    dir    = g_gomReEntry[i].direction;
      int    vnum   = g_lastGOMVerdictNum;

      bool gomGood = (vnum == 2 || vnum == 3 || vnum == -2 || vnum == -3);
      bool aligned = gomGood && ((dir == -1 && vnum <= -2) || (dir == 1 && vnum >= 2));
      if(!aligned) continue;

      // Bloquer re-entrée en zone de correction (micro-TF contre tendance)
      if(IsGOMCorrectionZone(dir))
      {
         PrintOnce(StringFormat("[GOM-ReEntry] %s re-entrée bloquée — zone correction", posSym), 60);
         continue;
      }

      // Vérifier qu'aucune position ouverte sur ce symbole dans cette direction
      bool alreadyOpen = false;
      for(int p = PositionsTotal() - 1; p >= 0; p--)
      {
         if(!posInfo.SelectByIndex(p)) continue;
         if(posInfo.Symbol() != posSym) continue;
         int pdir = posInfo.PositionType() == POSITION_TYPE_BUY ? 1 : -1;
         if(pdir == dir) { alreadyOpen = true; break; }
      }
      if(alreadyOpen) { g_gomReEntry[i].active = false; continue; }

      // Bloquer si limite de positions par symbole atteinte
      if(CountManagedPositions(posSym) >= MaxPositionsPerSymbol)
      {
         PrintOnce(StringFormat("[GOM-ReEntry] %s: max %d positions atteint — re-entrée bloquée",
               posSym, MaxPositionsPerSymbol), 60);
         continue;
      }

      // Ouvrir re-entrée
      CTrade reTrade;
      reTrade.SetExpertMagicNumber(MCPMagicNumber);
      reTrade.SetDeviationInPoints(30);
      reTrade.SetTypeFilling(ORDER_FILLING_IOC);

      double lot = g_gomReEntry[i].lot;
      double sl  = g_gomReEntry[i].stopLoss;
      double tp  = g_gomReEntry[i].takeProfit;
      bool ok = (dir == 1) ? reTrade.Buy(lot, posSym, 0, sl, tp, "TM_GOM_REENTRY")
                           : reTrade.Sell(lot, posSym, 0, sl, tp, "TM_GOM_REENTRY");
      if(ok)
      {
         g_gomReEntry[i].reEntryCount++;
         g_gomReEntry[i].closedAt = TimeCurrent();
         Print(StringFormat("[GOMScalp] Re-entree #%d %s %s GOM=%s",
               g_gomReEntry[i].reEntryCount, (dir==1?"BUY":"SELL"), posSym, g_lastGOMVerdict));
         SendWAEvent("GOM_REENTRY", posSym,
                     (dir==1)?SymbolInfoDouble(posSym,SYMBOL_ASK):SymbolInfoDouble(posSym,SYMBOL_BID),
                     0, (dir==1?"BUY":"SELL"), g_gomReEntry[i].entryPrice, sl, tp, lot);
      }
   }
}

//+------------------------------------------------------------------+
//| Surveille les positions MCP exécutées — alerte TP1 / SL          |
//+------------------------------------------------------------------+
void MonitorMCPPositions()
{
   for(int i = 0; i < g_mcpCount; i++)
   {
      if(!g_mcpSignals[i].executed)
      {
         // Signal actif mais pas encore exécuté → essayer d'exécuter
         if(g_mcpSignals[i].active) TryExecuteMCPSignal(i);
         continue;
      }

      string sym  = g_mcpSignals[i].symbol;
      double tp1  = g_mcpSignals[i].takeProfit1;
      double sl   = g_mcpSignals[i].stopLoss;
      int    dir  = g_mcpSignals[i].direction;
      double bid  = SymbolInfoDouble(sym, SYMBOL_BID);
      double ask  = SymbolInfoDouble(sym, SYMBOL_ASK);
      double refPx = (dir == 1) ? bid : ask;

      // Chercher la position par ticket
      double profit = 0;
      bool posOpen = false;
      if(g_mcpSignals[i].ticket > 0 && PositionSelectByTicket(g_mcpSignals[i].ticket))
      {
         posOpen = true;
         profit  = PositionGetDouble(POSITION_PROFIT);
      }

      // 🔴 DUPLICATION — FILTRES STRICTS (1 seule duplication, profit >= seuil, pas si déjà 2 positions)
      if(MCPDuplicateOnce && !g_mcpSignals[i].duplicated && posOpen
         && HasDupProfitStable(g_mcpSignals[i].ticket))
      {
         // Vérification stricte : 1 seule position autorisée avant duplication
         if(CountManagedPositions(sym) >= MaxPositionsPerSymbol)
         {
            Print(StringFormat("[TradeManager] 🚫 %s: Duplication BLOQUÉE — déjà %d positions (max %d)",
                  sym, CountManagedPositions(sym), MaxPositionsPerSymbol));
            g_mcpSignals[i].duplicated = true; // Marquer pour ne plus tenter
         }
         else
         {
            string dupWhy;
            if(!CanDuplicateNowWithGOM(sym, dir, g_mcpSignals[i].ticket, dupWhy))
            {
               Print(StringFormat("[TradeManager] 🟡 %s: Duplication BLOQUÉE — %s", sym, dupWhy));
            }
            else
            {
               CTrade dupTrade;
               dupTrade.SetExpertMagicNumber(MCPMagicNumber);
               dupTrade.SetDeviationInPoints(30);
               dupTrade.SetTypeFilling(ORDER_FILLING_IOC);
               DuplicateMCPPosition(i, dupTrade);
            }
         }
      }

      // TP1 atteint (prix ou position fermée en profit)
      if(!g_mcpSignals[i].tp1NotifSent)
      {
         bool tp1Hit = (tp1 > 0) &&
                       ((dir==1 && refPx >= tp1) || (dir==-1 && refPx <= tp1));
         bool closedInProfit = (!posOpen && g_mcpSignals[i].ticket > 0 && profit >= 0);
         if(tp1Hit || closedInProfit)
         {
            g_mcpSignals[i].tp1NotifSent = true;
            SendWAEvent("TP1_HIT", sym, refPx, profit, (dir==1?"BUY":"SELL"),
                        g_mcpSignals[i].entryPrice, sl, tp1, g_mcpSignals[i].lot);
         }
      }

      // SL atteint
      if(!g_mcpSignals[i].slNotifSent)
      {
         bool slHit = (sl > 0) &&
                      ((dir==1 && refPx <= sl) || (dir==-1 && refPx >= sl));
         bool closedInLoss = (!posOpen && g_mcpSignals[i].ticket > 0 && profit < 0);
         if(slHit || closedInLoss)
         {
            g_mcpSignals[i].slNotifSent = true;
            SendWAEvent("SL_HIT", sym, refPx, profit, (dir==1?"BUY":"SELL"),
                        g_mcpSignals[i].entryPrice, sl, tp1, g_mcpSignals[i].lot);
         }
      }

      // Nettoyer si plus aucune position MCP ouverte sur ce symbole
      bool mcpOpen = false;
      for(int pi = PositionsTotal() - 1; pi >= 0; pi--)
      {
         if(!posInfo.SelectByIndex(pi)) continue;
         if(posInfo.Symbol() != sym) continue;
         if(posInfo.Magic() == (long)MCPMagicNumber) { mcpOpen = true; break; }
      }
      if(g_mcpSignals[i].executed && !mcpOpen)
      {
         for(int j = i; j < g_mcpCount - 1; j++) g_mcpSignals[j] = g_mcpSignals[j+1];
         g_mcpCount--;
         ArrayResize(g_mcpSignals, g_mcpCount);
         i--;
      }
   }
}

//+------------------------------------------------------------------+
//| POLL /session-bias — cache du biais TradingAgents + MCP          |
//+------------------------------------------------------------------+
void PollSignalBias()
{
   if(SignalCacheAgeSec <= 0) return;
   if((int)(TimeCurrent() - g_lastBiasPoll) < SignalCacheAgeSec / 2) return;
   g_lastBiasPoll = TimeCurrent();

   // Construire liste unique de symboles à surveiller
   string syms[];
   int nsyms = 0;
   ArrayResize(syms, g_stateCount + 1);
   for(int i = 0; i < g_stateCount; i++) syms[nsyms++] = g_states[i].symbol;
   bool found = false;
   for(int i = 0; i < nsyms; i++) if(syms[i] == _Symbol) { found = true; break; }
   if(!found) syms[nsyms++] = _Symbol;

   for(int si = 0; si < nsyms; si++)
   {
      string sym    = syms[si];
      string symEnc = sym;
      StringReplace(symEnc, " ", "%20");
      string url = AIServerURL + "/session-bias?symbol=" + symEnc;
      char post[], result[];
      string headers = "Content-Type: application/json\r\n";
      string respH;
      int code = WebRequest("GET", url, headers, WATimeoutMs, post, result, respH);
      if(code != 200) continue;

      string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      // Extraire le sous-objet "data" si présent
      int dataPos = StringFind(body, "\"data\":{");
      string src  = dataPos >= 0 ? StringSubstr(body, dataPos) : body;

      string rec  = JsonGetString(src, "recommendation");
      if(StringLen(rec) == 0) rec = JsonGetString(src, "bias");
      if(StringLen(rec) == 0) rec = JsonGetString(body, "recommendation");
      double conf = JsonGetDouble(src, "confidence", -1);
      if(conf < 0) conf = JsonGetDouble(body, "confidence", 0.5);

      StringToUpper(rec);
      if(rec != "BUY" && rec != "SELL" && rec != "NEUTRAL" && rec != "HOLD")
         rec = "NEUTRAL";

      // Mettre à jour ou créer entrée cache
      int cidx = -1;
      for(int k = 0; k < g_biasCacheCount; k++)
         if(g_biasCache[k].symbol == sym) { cidx = k; break; }
      if(cidx < 0)
      {
         cidx = g_biasCacheCount;
         ArrayResize(g_biasCache, cidx + 1);
         g_biasCacheCount++;
      }
      g_biasCache[cidx].symbol         = sym;
      g_biasCache[cidx].recommendation = rec;
      g_biasCache[cidx].confidence     = conf;
      g_biasCache[cidx].fetchedAt      = TimeCurrent();
      g_biasCache[cidx].valid          = true;
      Print(StringFormat("[TradeManager] 📊 Biais %s: %s conf=%.0f%%", sym, rec, conf * 100));
   }
}

//+------------------------------------------------------------------+
//| Retourne le biais TA/MCP pour un symbole (depuis cache)          |
//+------------------------------------------------------------------+
string GetBiasForSymbol(const string sym, double &conf)
{
   conf = 0.5;
   if(SignalCacheAgeSec <= 0) return "NEUTRAL";
   for(int k = 0; k < g_biasCacheCount; k++)
   {
      if(g_biasCache[k].symbol != sym || !g_biasCache[k].valid) continue;
      if(SignalCacheAgeSec > 0 &&
         (int)(TimeCurrent() - g_biasCache[k].fetchedAt) > SignalCacheAgeSec)
      {
         g_biasCache[k].valid = false;
         return "NEUTRAL";  // cache expiré → neutre (ne bloque pas)
      }
      conf = g_biasCache[k].confidence;
      return g_biasCache[k].recommendation;
   }
   return "NEUTRAL";  // pas encore chargé → ne bloque pas
}

//+------------------------------------------------------------------+
//| Vérifie si le marché est en consolidation (ADX faible + ATR bas) |
//+------------------------------------------------------------------+
bool IsConsolidating(int stateIdx)
{
   if(!UseConsolidationFilter) return false;

   int hAdx = g_states[stateIdx].hADX;
   int hAtr = g_states[stateIdx].hATR;

   // Lire ADX (buffer 0 = ADX principal)
   if(hAdx != INVALID_HANDLE)
   {
      double adxBuf[];
      ArraySetAsSeries(adxBuf, true);
      if(CopyBuffer(hAdx, 0, 1, 1, adxBuf) >= 1)
      {
         if(adxBuf[0] < ADX_MinTrend)
         {
            PrintOnce(StringFormat("[TradeManager] 🔶 %s CONSOLIDATION ADX=%.1f < %.1f — trade bloqué",
                  g_states[stateIdx].symbol, adxBuf[0], ADX_MinTrend), 60);
            return true;
         }
      }
   }

   // Lire ATR actuel vs ATR moyen (20 bougies)
   if(hAtr != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(hAtr, 0, 1, 20, atrBuf) >= 20)
      {
         double atrNow = atrBuf[0];
         double atrSum = 0;
         for(int k = 0; k < 20; k++) atrSum += atrBuf[k];
         double atrAvg = atrSum / 20.0;
         if(atrAvg > 0 && atrNow < atrAvg * ConsolidationATRRatio)
         {
            PrintOnce(StringFormat("[TradeManager] 🔶 %s CONSOLIDATION ATR=%.5f < %.0f%% avg=%.5f — trade bloqué",
                  g_states[stateIdx].symbol, atrNow, ConsolidationATRRatio * 100, atrAvg), 60);
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie l'alignement direction vs biais TA/MCP                   |
//+------------------------------------------------------------------+
bool IsDirectionAligned(const string sym, int dir)
{
   if(!RequireSignalAlign) return true;
   double conf = 0.5;
   string bias = GetBiasForSymbol(sym, conf);

   // Biais neutre ou confiance insuffisante → laisser passer
   if(bias == "NEUTRAL" || bias == "HOLD") return true;
   if(conf < MinTAConfidence) return true;

   bool aligned = (dir == 1 && bias == "BUY") || (dir == -1 && bias == "SELL");
   if(!aligned)
      PrintOnce(StringFormat("[TradeManager] 🚫 %s %s BLOQUÉ — biais TA=%s (conf=%.0f%%)",
            sym, (dir==1?"BUY":"SELL"), bias, conf * 100), 60);
   return aligned;
}

//+------------------------------------------------------------------+
double GetLastClosePrice(string sym)
{
   HistorySelect(TimeCurrent() - 7200, TimeCurrent());
   for(int i = HistoryDealsTotal()-1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != sym) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      return HistoryDealGetDouble(ticket, DEAL_PRICE);
   }
   return 0.0;
}

void PrintOnce(string msg, int intervalSec)
{
   static string  s_lastMsg = "";
   static datetime s_lastTs = 0;
   if(msg == s_lastMsg && (int)(TimeCurrent() - s_lastTs) < intervalSec) return;
   s_lastMsg = msg; s_lastTs = TimeCurrent();
   Print(msg);
}

//+------------------------------------------------------------------+
//| GOM KOLA DASHBOARD — Affichage tableau en temps réel             |
//+------------------------------------------------------------------+
static datetime g_lastDashboardFetch = 0;
static string g_lastGOMTableauJSON = "";

// DEPRECATED: Use RefreshDashboard() instead
void UpdateGOMDashboard_DISABLED()
{
   // Poll toutes les 10s pour ne pas surcharger
   if((int)(TimeCurrent() - g_lastDashboardFetch) < 10) return;
   g_lastDashboardFetch = TimeCurrent();

   // GET /gom-tableau depuis AI server
   string url = AIServerURL + "/gom-tableau?symbol=" + _Symbol;
   string headers = "Content-Type: application/json\r\n";
   char data[];
   char result[];

   int res = WebRequest("GET", url, headers, 5000, data, result, headers);
   if(res != 200) return;

   string json = CharArrayToString(result);
   if(StringLen(json) == 0) return;

   // Éviter les rafraîchissements redondants
   if(json == g_lastGOMTableauJSON) return;
   g_lastGOMTableauJSON = json;

   // Parser et afficher
   DisplayGOMDashboard(json);
}

// Ancien panneau JSON — désactivé, remplacé par DisplayCompleteGOMDashboard
void DisplayGOMDashboard(const string &json) { }

//+------------------------------------------------------------------+
//| DASHBOARD DRAWING HELPERS                                        |
//+------------------------------------------------------------------+
// Dessine une cellule du panneau bas-centre.
// x/y sont des offsets DEPUIS le coin CORNER_LEFT_LOWER (y compte vers le haut).
// cellW : largeur de la cellule.
void DrawDashCell(string name, int x, int y, int cellW, int cellH,
                  string text, color bgColor, color txtColor)
{
   string bgName  = "TM_DASH_" + name + "_BG";
   string txtName = "TM_DASH_" + name + "_TXT";

   if(ObjectFind(0, bgName) < 0)
   {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER,     CORNER_LEFT_LOWER);
      ObjectSetInteger(0, bgName, OBJPROP_BACK,       false);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE,     cellW);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE,     cellH);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR,   bgColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE,  BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, ColorBorder);

   if(ObjectFind(0, txtName) < 0)
   {
      ObjectCreate(0, txtName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, txtName, OBJPROP_CORNER,     CORNER_LEFT_LOWER);
      ObjectSetString(0,  txtName, OBJPROP_FONT,       "Consolas");
      ObjectSetInteger(0, txtName, OBJPROP_BACK,       false);
      ObjectSetInteger(0, txtName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, txtName, OBJPROP_ANCHOR,     ANCHOR_LEFT_UPPER);
   }
   ObjectSetString(0,  txtName, OBJPROP_TEXT,      text);
   ObjectSetInteger(0, txtName, OBJPROP_XDISTANCE, x + 4);
   ObjectSetInteger(0, txtName, OBJPROP_YDISTANCE, y - 4);   // légèrement au-dessus du bord bas de la cellule
   ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE,  FontSize);
   ObjectSetInteger(0, txtName, OBJPROP_COLOR,     txtColor);
}

// Compatibilité — ancien DrawDashRow maintenu mais ne dessine plus rien
// (tous les appels obsolètes passent ici sans effet)
void DrawDashRow(string name, int x, int y, string text, color bgColor) { }

void RemoveAllDashboardObjects()
{
   // Purge TOUS les objets des anciens panneaux (GOM_*, XAUUSD_*, TM_DASH_*)
   string prefixes[] = {"GOM_", "TM_DASH_", "TM_BOT_"};
   int objCount = ObjectsTotal(0);
   for(int i = objCount - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i);
      for(int p = 0; p < ArraySize(prefixes); p++)
         if(StringFind(nm, prefixes[p]) == 0) { ObjectDelete(0, nm); break; }
      // Anciens objets avec préfixe symbole (_HDR, _VERDICT, _SCORES, _IND, _KOLA, _STATUS)
      string suffixes[] = {"_HDR_BG","_HDR_TXT","_VERDICT_BG","_VERDICT_TXT",
                           "_SCORES_BG","_SCORES_TXT","_IND_BG","_IND_TXT",
                           "_KOLA_BG","_KOLA_TXT","_STATUS_BG","_STATUS_TXT"};
      for(int s = 0; s < ArraySize(suffixes); s++)
         if(StringFind(nm, suffixes[s]) >= 0) { ObjectDelete(0, nm); break; }
   }
}

void RefreshDashboard()
{
   if(!UseDashboard) return;
   if(TimeCurrent() - g_lastDashboardUpdate < DashboardUpdateSec) return;
   g_lastDashboardUpdate = TimeCurrent();

   GOMData gom = FetchGOMDataForChart();
   if(gom.valid)
   {
      SyncGOMGlobalsFromData(gom);
      DisplayCompleteGOMDashboard(gom);
   }
}

//+------------------------------------------------------------------+
//| URL encode symbole (espaces Boom/Crash Index)                    |
//+------------------------------------------------------------------+
string EncodeSymbolForURL(const string sym)
{
   string enc = sym;
   StringReplace(enc, " ", "%20");
   return enc;
}

// Symbole serveur GOM (XAUEUR → XAUUSD, espaces encodés)
string ResolveGOMFetchSymbol(const string sym)
{
   if(sym == "XAUEUR" || sym == "GOLD") return "XAUUSD";
   return sym;
}

bool TryFetchGOMFromServer(const string sym, GOMData &gom)
{
   string symEnc = EncodeSymbolForURL(sym);
   string json = "";

   if(HttpGetJson("/gom-tableau-complete?symbol=" + symEnc, json) &&
      StringFind(json, "\"ok\":true") >= 0)
   {
      ParseGOMFromJson(json, gom);
      if(gom.valid) { gom.data_source = "TV"; return true; }
   }

   json = "";
   if(HttpGetJson("/gom-verdict?symbol=" + symEnc, json) &&
      StringFind(json, "\"ok\":true") >= 0)
   {
      ParseGOMFromJson(json, gom);
      if(gom.valid) { gom.data_source = "TV"; return true; }
   }
   return false;
}

//+------------------------------------------------------------------+
//| HTTP GET JSON depuis AI server                                   |
//+------------------------------------------------------------------+
bool HttpGetJson(const string path, string &jsonOut)
{
   string headers = "Content-Type: application/json\r\n";
   char data[];
   char result[];
   string respH;
   int code = WebRequest("GET", AIServerURL + path, headers, WATimeoutMs, data, result, respH);
   if(code != 200) return false;
   jsonOut = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   return (StringLen(jsonOut) > 0);
}

//+------------------------------------------------------------------+
//| Direction MTF — même logique que Pine get_dir()                  |
//+------------------------------------------------------------------+
string DirTxtFromCode(int d)
{
   if(d == 1)  return "BULL";
   if(d == -1) return "BEAR";
   return "NEUT";
}

int CalcGOMDirTF(const string sym, ENUM_TIMEFRAMES tf, int &outRsi)
{
   outRsi = 50;
   int h9  = iMA(sym, tf, 9,  0, MODE_EMA, PRICE_CLOSE);
   int h21 = iMA(sym, tf, 21, 0, MODE_EMA, PRICE_CLOSE);
   int h50 = iMA(sym, tf, 50, 0, MODE_EMA, PRICE_CLOSE);
   int hR  = iRSI(sym, tf, RSI_Period, PRICE_CLOSE);
   int hA  = iATR(sym, tf, 10);
   if(h9 == INVALID_HANDLE || h21 == INVALID_HANDLE || h50 == INVALID_HANDLE ||
      hR == INVALID_HANDLE || hA == INVALID_HANDLE)
      return 0;

   double ef[], es[], eh[], c[], rsi[], atr[], hi[], lo[];
   ArraySetAsSeries(ef, true);
   ArraySetAsSeries(es, true);
   ArraySetAsSeries(eh, true);
   ArraySetAsSeries(c, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(hi, true);
   ArraySetAsSeries(lo, true);

   if(CopyBuffer(h9, 0, 1, 1, ef) < 1)  { IndicatorRelease(h9);  IndicatorRelease(h21); IndicatorRelease(h50); IndicatorRelease(hR); IndicatorRelease(hA); return 0; }
   if(CopyBuffer(h21, 0, 1, 1, es) < 1) { IndicatorRelease(h9);  IndicatorRelease(h21); IndicatorRelease(h50); IndicatorRelease(hR); IndicatorRelease(hA); return 0; }
   if(CopyBuffer(h50, 0, 1, 1, eh) < 1) { IndicatorRelease(h9);  IndicatorRelease(h21); IndicatorRelease(h50); IndicatorRelease(hR); IndicatorRelease(hA); return 0; }
   if(CopyBuffer(hR, 0, 1, 1, rsi) < 1)  { IndicatorRelease(h9);  IndicatorRelease(h21); IndicatorRelease(h50); IndicatorRelease(hR); IndicatorRelease(hA); return 0; }
   if(CopyBuffer(hA, 0, 1, 1, atr) < 1)  { IndicatorRelease(h9);  IndicatorRelease(h21); IndicatorRelease(h50); IndicatorRelease(hR); IndicatorRelease(hA); return 0; }
   if(CopyClose(sym, tf, 1, 1, c) < 1)   { IndicatorRelease(h9);  IndicatorRelease(h21); IndicatorRelease(h50); IndicatorRelease(hR); IndicatorRelease(hA); return 0; }
   if(CopyHigh(sym, tf, 1, 1, hi) < 1)   { IndicatorRelease(h9);  IndicatorRelease(h21); IndicatorRelease(h50); IndicatorRelease(hR); IndicatorRelease(hA); return 0; }
   if(CopyLow(sym, tf, 1, 1, lo) < 1)    { IndicatorRelease(h9);  IndicatorRelease(h21); IndicatorRelease(h50); IndicatorRelease(hR); IndicatorRelease(hA); return 0; }

   IndicatorRelease(h9);
   IndicatorRelease(h21);
   IndicatorRelease(h50);
   IndicatorRelease(hR);
   IndicatorRelease(hA);

   outRsi = (int)MathRound(rsi[0]);
   double hl2 = (hi[0] + lo[0]) / 2.0;
   bool stBull = (c[0] > hl2 + 3.0 * atr[0]);
   int bull = (ef[0] > es[0] ? 1 : 0) + (c[0] > eh[0] ? 1 : 0) + (rsi[0] > 52.0 ? 1 : 0) + (stBull ? 1 : 0);
   int bear = (ef[0] < es[0] ? 1 : 0) + (c[0] < eh[0] ? 1 : 0) + (rsi[0] < 48.0 ? 1 : 0) + (!stBull ? 1 : 0);
   if(bull >= 3) return 1;
   if(bear >= 3) return -1;
   return 0;
}

void ReleaseGOMVerdictHandles(const int hRsi, const int hE9, const int hE21, const int hE50,
                               const int hBb, const int hMacd, const int hAtr)
{
   if(hRsi  != INVALID_HANDLE) IndicatorRelease(hRsi);
   if(hE9   != INVALID_HANDLE) IndicatorRelease(hE9);
   if(hE21  != INVALID_HANDLE) IndicatorRelease(hE21);
   if(hE50  != INVALID_HANDLE) IndicatorRelease(hE50);
   if(hBb   != INVALID_HANDLE) IndicatorRelease(hBb);
   if(hMacd != INVALID_HANDLE) IndicatorRelease(hMacd);
   if(hAtr  != INVALID_HANDLE) IndicatorRelease(hAtr);
}

// Verdict GOM sur M1 — logique proche de GOM_KOLA_SIDO.pine (fallback sans TV)
void ComputeGOMVerdictLocal(GOMData &gom, const string sym)
{
   ENUM_TIMEFRAMES tf = PERIOD_M1;
   gom.symbol = sym;
   gom.data_source = "MT5";
   gom.current_price = SymbolInfoDouble(sym, SYMBOL_BID);

   int hRsi  = iRSI(sym, tf, 14, PRICE_CLOSE);
   int hE9   = iMA(sym, tf, 9,  0, MODE_EMA, PRICE_CLOSE);
   int hE21  = iMA(sym, tf, 21, 0, MODE_EMA, PRICE_CLOSE);
   int hE50  = iMA(sym, tf, 50, 0, MODE_EMA, PRICE_CLOSE);
   int hBb   = iBands(sym, tf, 20, 0, 2.0, PRICE_CLOSE);
   int hMacd = iMACD(sym, tf, 12, 26, 9, PRICE_CLOSE);
   int hAtr  = iATR(sym, tf, 10);
   if(hRsi == INVALID_HANDLE || hBb == INVALID_HANDLE || hMacd == INVALID_HANDLE)
   {
      ReleaseGOMVerdictHandles(hRsi, hE9, hE21, hE50, hBb, hMacd, hAtr);
      return;
   }

   double rsi[], e9[], e21[], e50[], bbMid[], bbUp[], bbDn[], macdMain[], macdSig[], atr[];
   double c[], hi[], lo[];
   ArraySetAsSeries(rsi, true); ArraySetAsSeries(e9, true); ArraySetAsSeries(e21, true);
   ArraySetAsSeries(e50, true); ArraySetAsSeries(bbMid, true); ArraySetAsSeries(bbUp, true);
   ArraySetAsSeries(bbDn, true); ArraySetAsSeries(macdMain, true); ArraySetAsSeries(macdSig, true);
   ArraySetAsSeries(atr, true); ArraySetAsSeries(c, true); ArraySetAsSeries(hi, true); ArraySetAsSeries(lo, true);

   bool dataOk =
      CopyBuffer(hRsi, 0, 1, 1, rsi) >= 1 &&
      CopyBuffer(hE9, 0, 1, 1, e9) >= 1 &&
      CopyBuffer(hE21, 0, 1, 1, e21) >= 1 &&
      CopyBuffer(hE50, 0, 1, 1, e50) >= 1 &&
      CopyBuffer(hBb, 0, 1, 1, bbMid) >= 1 &&
      CopyBuffer(hBb, 1, 1, 1, bbUp) >= 1 &&
      CopyBuffer(hBb, 2, 1, 1, bbDn) >= 1 &&
      CopyBuffer(hMacd, 0, 1, 1, macdMain) >= 1 &&
      CopyBuffer(hMacd, 1, 1, 1, macdSig) >= 1 &&
      CopyBuffer(hAtr, 0, 1, 1, atr) >= 1 &&
      CopyClose(sym, tf, 1, 1, c) >= 1 &&
      CopyHigh(sym, tf, 1, 1, hi) >= 1 &&
      CopyLow(sym, tf, 1, 1, lo) >= 1;

   if(!dataOk)
   {
      ReleaseGOMVerdictHandles(hRsi, hE9, hE21, hE50, hBb, hMacd, hAtr);
      return;
   }

   gom.rsi = (int)MathRound(rsi[0]);
   double hl2 = (hi[0] + lo[0]) / 2.0;
   bool stBull = (c[0] > hl2 + 3.0 * atr[0]);
   gom.st_dir = stBull ? 1 : -1;

   double scoreBuy = 0.0, scoreSell = 0.0;
   scoreBuy  += gom.st_dir == 1 ? 1.5 : 0.0;
   scoreSell += gom.st_dir == -1 ? 1.5 : 0.0;
   double vwapProxy = (hi[0] + lo[0] + c[0]) / 3.0;
   scoreBuy  += c[0] > vwapProxy ? 1.0 : 0.0;
   scoreSell += c[0] < vwapProxy ? 1.0 : 0.0;
   scoreBuy  += c[0] > bbMid[0] ? 0.5 : 0.0;
   scoreSell += c[0] < bbMid[0] ? 0.5 : 0.0;
   if(rsi[0] > 50.0 && rsi[0] < 70.0) scoreBuy += 1.0;
   else if(rsi[0] <= 35.0) scoreBuy += 0.5;
   if(rsi[0] < 50.0 && rsi[0] > 30.0) scoreSell += 1.0;
   else if(rsi[0] >= 65.0) scoreSell += 0.5;
   scoreBuy  += macdMain[0] > macdSig[0] ? 0.8 : 0.0;
   scoreSell += macdMain[0] < macdSig[0] ? 0.8 : 0.0;
   int emaAbove = (c[0] > e9[0] ? 1 : 0) + (c[0] > e21[0] ? 1 : 0) + (c[0] > e50[0] ? 1 : 0);
   scoreBuy  += emaAbove * 0.15;
   scoreSell += (3 - emaAbove) * 0.15;

   gom.score_buy = scoreBuy;
   gom.score_sell = scoreSell;
   gom.force_pts = MathAbs(scoreBuy - scoreSell);
   bool coherenceOk = true;
   gom.coherence_pct = 50.0;

   bool perfectSell = scoreSell > scoreBuy && gom.force_pts >= 4.0 && coherenceOk;
   bool goodSell    = scoreSell > scoreBuy && gom.force_pts >= 1.0 && !perfectSell && coherenceOk;
   bool sell        = scoreSell > scoreBuy && gom.force_pts >= 0.6 && !goodSell && !perfectSell && coherenceOk;
   bool perfectBuy  = scoreBuy > scoreSell && gom.force_pts >= 4.0 && coherenceOk;
   bool goodBuy     = scoreBuy > scoreSell && gom.force_pts >= 2.5 && !perfectBuy && coherenceOk;
   bool buy         = scoreBuy > scoreSell && gom.force_pts >= 1.2 && !goodBuy && !perfectBuy && coherenceOk;

   if(perfectSell)      { gom.verdict_num = -3; gom.verdict = "PERFECT SELL"; }
   else if(goodSell)    { gom.verdict_num = -2; gom.verdict = "GOOD SELL"; }
   else if(sell)        { gom.verdict_num = -1; gom.verdict = "SELL"; }
   else if(perfectBuy)   { gom.verdict_num = 3;  gom.verdict = "PERFECT BUY"; }
   else if(goodBuy)     { gom.verdict_num = 2;  gom.verdict = "GOOD BUY"; }
   else if(buy)         { gom.verdict_num = 1;  gom.verdict = "BUY"; }
   else                 { gom.verdict_num = 0;  gom.verdict = "WAIT"; }

   gom.entry_quality = MathMin(100.0, gom.force_pts * 12.0);
   gom.spike_pct = 0.0;
   gom.kola_buy = 0.0;
   gom.kola_sell = 0.0;
   gom.kola_state = "---";
   gom.valid = true;

   ReleaseGOMVerdictHandles(hRsi, hE9, hE21, hE50, hBb, hMacd, hAtr);
}

void FillGOMMTFLocal(GOMData &gom, const string sym)
{
   if(!DashboardLocalMTF) return;
   if(StringLen(gom.tf_m1_dir) > 0) return;

   int d = 0, r = 50;
   int tb = 0, ts = 0;

   d = CalcGOMDirTF(sym, PERIOD_M1, r);  gom.tf_m1_dir = DirTxtFromCode(d);  gom.tf_m1_rsi = r;  if(d==1) tb++; else if(d==-1) ts++;
   d = CalcGOMDirTF(sym, PERIOD_M5, r);  gom.tf_m5_dir = DirTxtFromCode(d);  gom.tf_m5_rsi = r;  if(d==1) tb++; else if(d==-1) ts++;
   d = CalcGOMDirTF(sym, PERIOD_M15, r); gom.tf_m15_dir = DirTxtFromCode(d); gom.tf_m15_rsi = r; if(d==1) tb++; else if(d==-1) ts++;
   d = CalcGOMDirTF(sym, PERIOD_H1, r);  gom.tf_h1_dir = DirTxtFromCode(d);  gom.tf_h1_rsi = r;  if(d==1) tb++; else if(d==-1) ts++;
   d = CalcGOMDirTF(sym, PERIOD_H4, r);  gom.tf_h4_dir = DirTxtFromCode(d);  gom.tf_h4_rsi = r;  if(d==1) tb++; else if(d==-1) ts++;
   d = CalcGOMDirTF(sym, PERIOD_D1, r);  gom.tf_d1_dir = DirTxtFromCode(d);  gom.tf_d1_rsi = r;  if(d==1) tb++; else if(d==-1) ts++;
   d = CalcGOMDirTF(sym, PERIOD_W1, r);  gom.tf_w1_dir = DirTxtFromCode(d);  gom.tf_w1_rsi = r;  if(d==1) tb++; else if(d==-1) ts++;

   int gd = (tb >= 5) ? 1 : (ts >= 5) ? -1 : (tb > ts) ? 1 : (ts > tb) ? -1 : 0;
   gom.tf_global_dir = DirTxtFromCode(gd);
   gom.tf_global_strength = MathMax(tb, ts);
}

//+------------------------------------------------------------------+
//| Parse JSON GOM (verdict + MTF) depuis réponse serveur            |
//+------------------------------------------------------------------+
void ParseGOMFromJson(const string &json, GOMData &gom)
{
   gom.symbol = _Symbol;
   gom.verdict = GetJSONString(json, "verdict");
   gom.verdict_num = (int)GetJSONDouble(json, "verdict_num");
   gom.score_buy = GetJSONDouble(json, "score_buy");
   gom.score_sell = GetJSONDouble(json, "score_sell");
   gom.spike_pct = GetJSONDouble(json, "spike_pct");
   gom.rsi = (int)GetJSONDouble(json, "rsi");
   gom.st_dir = (int)GetJSONDouble(json, "st_dir");
   gom.entry_quality = GetJSONDouble(json, "entry_quality");
   gom.coherence_pct = GetJSONDouble(json, "coherence_pct");
   gom.kola_buy = GetJSONDouble(json, "kola_buy");
   gom.kola_sell = GetJSONDouble(json, "kola_sell");
   gom.current_price = GetJSONDouble(json, "price");
   gom.force_pts = GetJSONDouble(json, "force_pts");
   if(gom.force_pts <= 0.0)
      gom.force_pts = GetJSONDouble(json, "verdict_gap");
   gom.rsi_alert = GetJSONString(json, "rsi_alert");
   gom.kola_state = GetJSONString(json, "kola_state");

   gom.tf_m1_dir = GetJSONString(json, "tf_m1_dir");
   gom.tf_m1_rsi = (int)GetJSONDouble(json, "tf_m1_rsi");
   gom.tf_m5_dir = GetJSONString(json, "tf_m5_dir");
   gom.tf_m5_rsi = (int)GetJSONDouble(json, "tf_m5_rsi");
   gom.tf_m15_dir = GetJSONString(json, "tf_m15_dir");
   gom.tf_m15_rsi = (int)GetJSONDouble(json, "tf_m15_rsi");
   gom.tf_h1_dir = GetJSONString(json, "tf_h1_dir");
   gom.tf_h1_rsi = (int)GetJSONDouble(json, "tf_h1_rsi");
   gom.tf_h4_dir = GetJSONString(json, "tf_h4_dir");
   gom.tf_h4_rsi = (int)GetJSONDouble(json, "tf_h4_rsi");
   gom.tf_d1_dir = GetJSONString(json, "tf_d1_dir");
   gom.tf_d1_rsi = (int)GetJSONDouble(json, "tf_d1_rsi");
   gom.tf_w1_dir = GetJSONString(json, "tf_w1_dir");
   gom.tf_w1_rsi = (int)GetJSONDouble(json, "tf_w1_rsi");
   gom.tf_global_dir = GetJSONString(json, "tf_global_dir");
   gom.tf_global_strength = (int)GetJSONDouble(json, "tf_global_strength");

   gom.kola_line_1 = GetJSONDouble(json, "kola_line_1");
   gom.kola_line_2 = GetJSONDouble(json, "kola_line_2");
   gom.zone_1_high = GetJSONDouble(json, "zone_1_high");
   gom.zone_1_low = GetJSONDouble(json, "zone_1_low");
   gom.zone_2_high = GetJSONDouble(json, "zone_2_high");
   gom.zone_2_low = GetJSONDouble(json, "zone_2_low");

   if(gom.current_price <= 0.0)
      gom.current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(StringLen(gom.kola_state) == 0)
   {
      if(StringFind(json, "NEAR BUY") >= 0)  gom.kola_state = "NEAR BUY";
      else if(StringFind(json, "NEAR SELL") >= 0) gom.kola_state = "NEAR SELL";
      else gom.kola_state = "---";
   }
   // Rejeter un WAIT pur sans scores — c'est le cas "serveur vide/poller arrêté"
   bool hasRealData = (gom.verdict_num != 0 || gom.score_buy > 0 || gom.score_sell > 0);
   gom.valid = (StringLen(gom.verdict) > 0 && hasRealData);
}

//+------------------------------------------------------------------+
//| Données GOM pour dashboard — source TradingView via AI server  |
//+------------------------------------------------------------------+
GOMData FetchGOMDataForChart()
{
   GOMData gom;
   gom.valid = false;
   gom.data_source = "";
   gom.capture_time = TimeCurrent();

   string fetchSym = ResolveGOMFetchSymbol(_Symbol);
   if(!TryFetchGOMFromServer(fetchSym, gom) && fetchSym != _Symbol)
      TryFetchGOMFromServer(_Symbol, gom);

   if(!gom.valid)
   {
      ComputeGOMVerdictLocal(gom, _Symbol);
      if(gom.valid)
         PrintOnce("[Dashboard] Pas de donnees TV sur serveur — affichage calcul MT5 (lancer gom_verdict_poller.py)", 120);
   }

   if(gom.valid)
      FillGOMMTFLocal(gom, _Symbol);

   return gom;
}

//+------------------------------------------------------------------+
//| GET COLOR FOR VERDICT NUMBER                                     |
//+------------------------------------------------------------------+
color GetVerdictColor(int verdictNum)
{
   if(verdictNum >= 2) return ColorHeaderBuy;      // PERFECT BUY
   if(verdictNum == 1) return ColorBuy;            // BUY
   if(verdictNum == 0) return ColorNeutral;        // WAIT
   if(verdictNum == -1) return ColorSell;          // SELL
   if(verdictNum <= -2) return ColorHeaderSell;    // PERFECT SELL
   return ColorNeutral;
}

//+------------------------------------------------------------------+
//| DISPLAY COMPLETE GOM DASHBOARD WITH ALL TABLEAU DATA             |
//+------------------------------------------------------------------+
void DisplayCompleteGOMDashboard(const GOMData &gom)
{
   if(!UseDashboard) return;

   // ── Dimensions ──────────────────────────────────────────────────────
   int chartW  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   if(chartW < 400) chartW = 1200;

   const int ROWS      = 2;       // 2 lignes de cellules
   const int COLS      = 9;       // 9 colonnes : VERDICT | M1|M5|M15|H1|H4|D1|GLOBAL|KOLA
   const int cellH     = RowHeight + 4;
   const int gap       = 2;
   const int marginLR  = 10;
   const int marginBot = DashboardY;

   int totalW  = chartW - 2 * marginLR;
   int cellW   = (totalW - (COLS - 1) * gap) / COLS;
   if(cellW < 60) cellW = 60;

   // Y depuis le bas : ligne 0 = la plus haute (heure + kola), ligne 1 = la plus basse (scores)
   int y0 = marginBot + cellH + gap;   // ligne haute (y compte depuis bas)
   int y1 = marginBot;                 // ligne basse

   // ── Couleurs verdictales ─────────────────────────────────────────────
   color cVerdict = GetVerdictColor(gom.verdict_num);
   color cBg      = ColorBackground;
   color cTxt     = ColorText;
   color cBorder  = ColorBorder;

   // Helper : couleur par direction TF
   // BUY/BULL → vert, SELL/BEAR → rouge, neutre → gris
   #define TF_COLOR(d) (StringFind(d,"BUY")>=0||StringFind(d,"BULL")>=0 ? ColorBuy : \
                        StringFind(d,"SELL")>=0||StringFind(d,"BEAR")>=0 ? ColorSell : ColorNeutral)

   string stTxt = (gom.st_dir > 0) ? "▲ST" : "▼ST";
   string src   = (gom.data_source == "TV") ? "TV" : "MT5";
   string ts    = TimeToString(TimeCurrent(), TIME_MINUTES);

   // ── Ligne haute — colonne 0 : VERDICT principal ──────────────────────
   int xCur = marginLR;
   string verdLabel = gom.verdict + (gom.verdict_num >= 2 ? " ★" : gom.verdict_num <= -2 ? " ★" : "");
   DrawDashCell("V0_HDR", xCur, y0, cellW, cellH,
                gom.symbol + " GOM", cVerdict, cTxt);

   // ── Ligne haute — colonnes 1-7 : TF ──────────────────────────────────
   struct TFSlot { string label; string dir; int rsi; };
   TFSlot tfs[7];
   tfs[0].label="M1";  tfs[0].dir=gom.tf_m1_dir;  tfs[0].rsi=gom.tf_m1_rsi;
   tfs[1].label="M5";  tfs[1].dir=gom.tf_m5_dir;  tfs[1].rsi=gom.tf_m5_rsi;
   tfs[2].label="M15"; tfs[2].dir=gom.tf_m15_dir; tfs[2].rsi=gom.tf_m15_rsi;
   tfs[3].label="H1";  tfs[3].dir=gom.tf_h1_dir;  tfs[3].rsi=gom.tf_h1_rsi;
   tfs[4].label="H4";  tfs[4].dir=gom.tf_h4_dir;  tfs[4].rsi=gom.tf_h4_rsi;
   tfs[5].label="D1";  tfs[5].dir=gom.tf_d1_dir;  tfs[5].rsi=gom.tf_d1_rsi;
   tfs[6].label="GLOB"; tfs[6].dir=gom.tf_global_dir; tfs[6].rsi=gom.tf_global_strength;

   for(int i = 0; i < 7; i++)
   {
      xCur += cellW + gap;
      color cTF = TF_COLOR(tfs[i].dir);
      string tfTxt = tfs[i].label + ":" + tfs[i].dir +
                     "\nRSI " + IntegerToString(tfs[i].rsi);
      DrawDashCell("V0_TF" + IntegerToString(i), xCur, y0, cellW, cellH,
                   tfs[i].label + " " + tfs[i].dir, cTF, cTxt);
   }

   // ── Ligne haute — colonne 8 : KOLA state ─────────────────────────────
   xCur += cellW + gap;
   color cKola = (StringFind(gom.kola_state,"BUY")>=0) ? ColorBuy :
                 (StringFind(gom.kola_state,"SELL")>=0) ? ColorSell : ColorNeutral;
   DrawDashCell("V0_KOLA", xCur, y0, cellW, cellH,
                "KOLA " + gom.kola_state, cKola, cTxt);

   // ── Ligne basse — colonne 0 : VERDICT + score ────────────────────────
   xCur = marginLR;
   string scoreTxt = verdLabel +
                     "  B:" + DoubleToString(gom.score_buy,1) +
                     " S:" + DoubleToString(gom.score_sell,1);
   DrawDashCell("V1_SCORE", xCur, y1, cellW, cellH, scoreTxt, cVerdict, cTxt);

   // ── Ligne basse — col 1 : RSI + Supertrend ──────────────────────────
   xCur += cellW + gap;
   color cRSI = (gom.rsi < 35) ? ColorBuy : (gom.rsi > 65) ? ColorSell : cBg;
   DrawDashCell("V1_RSI", xCur, y1, cellW, cellH,
                "RSI " + IntegerToString(gom.rsi) + " " + stTxt, cRSI, cTxt);

   // ── Ligne basse — col 2 : Quality + Coherence ────────────────────────
   xCur += cellW + gap;
   color cQ = (gom.entry_quality >= 60) ? ColorBuy :
              (gom.entry_quality >= 35) ? ColorNeutral : ColorSell;
   DrawDashCell("V1_QUAL", xCur, y1, cellW, cellH,
                "Q:" + DoubleToString(gom.entry_quality,0) + "% C:" +
                DoubleToString(gom.coherence_pct,0) + "%", cQ, cTxt);

   // ── Ligne basse — col 3 : Prix + Spike ───────────────────────────────
   xCur += cellW + gap;
   DrawDashCell("V1_PRICE", xCur, y1, cellW, cellH,
                DoubleToString(gom.current_price,2) +
                " Spk:" + DoubleToString(gom.spike_pct,0) + "%", cBg, cTxt);

   // ── Ligne basse — col 4 : KOLA BUY ───────────────────────────────────
   xCur += cellW + gap;
   DrawDashCell("V1_KB", xCur, y1, cellW, cellH,
                "KBuy " + DoubleToString(gom.kola_buy,2), ColorBuy, cTxt);

   // ── Ligne basse — col 5 : KOLA SELL ──────────────────────────────────
   xCur += cellW + gap;
   DrawDashCell("V1_KS", xCur, y1, cellW, cellH,
                "KSell " + DoubleToString(gom.kola_sell,2), ColorSell, cTxt);

   // ── Ligne basse — col 6 : MCP polling ───────────────────────────────
   xCur += cellW + gap;
   DrawDashCell("V1_MCP", xCur, y1, cellW, cellH,
                "MCP " + (UseMCPSignals ? "ON" : "OFF"), cBg, cTxt);

   // ── Ligne basse — col 7 : Filtre global (nouveau) ────────────────────
   xCur += cellW + gap;
   color cGlob = (g_lastGOMGlobalStrength >= GlobalDirMinConfidence) ? ColorBuy : ColorSell;
   DrawDashCell("V1_GLOB", xCur, y1, cellW, cellH,
                g_lastGOMGlobalDir + " " + IntegerToString(g_lastGOMGlobalStrength) + "%",
                cGlob, cTxt);

   // ── Ligne basse — col 8 : Source + heure ─────────────────────────────
   xCur += cellW + gap;
   DrawDashCell("V1_SRC", xCur, y1, cellW, cellH,
                src + " " + ts, cBg, cTxt);

   #undef TF_COLOR

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| JSON VALUE EXTRACTION HELPERS                                    |
//+------------------------------------------------------------------+
double GetJSONDouble(const string &json, const string &key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(json, search);
   if(pos < 0)
      return 0.0;

   pos += StringLen(search);

   // Skip spaces and quotes
   while(pos < StringLen(json) && StringGetCharacter(json, pos) == ' ')
      pos++;

   int end = pos;
   // Find end of value (comma, brace, bracket, or quote)
   while(end < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, end);
      if(ch == ',' || ch == '}' || ch == ']') break;
      end++;
   }

   // Remove trailing spaces
   while(end > pos && StringGetCharacter(json, end - 1) == ' ')
      end--;

   if(end <= pos)
      return 0.0;

   string valStr = StringSubstr(json, pos, end - pos);
   return StringToDouble(valStr);
}

string GetJSONString(const string &json, const string &key)
{
   string search = "\"" + key + "\":\"";
   int pos = StringFind(json, search);
   if(pos < 0) return "";

   pos += StringLen(search);
   int end = StringFind(json, "\"", pos);
   if(end < 0) return "";

   return StringSubstr(json, pos, end - pos);
}

//+------------------------------------------------------------------+
//| SYNC GOM DATA TO AI SERVER — PUSH complete GOM state             |
//+------------------------------------------------------------------+
bool SyncGOMDataToServer(const string &symbol,
                         double verdict_num, double score_buy, double score_sell,
                         double spike_pct, int rsi, double st_dir,
                         double entry_quality, double coherence_pct,
                         double kola_buy, double kola_sell, double current_price)
{
   string url = AIServerURL + "/gom-verdict";
   string headers = "Content-Type: application/json\r\n";

   // Build JSON body with ALL GOM fields
   string body = StringFormat(
      "{\"symbol\":\"%s\",\"verdict_num\":%.1f,\"score_buy\":%.2f,\"score_sell\":%.2f,"
      "\"spike_pct\":%.2f,\"rsi\":%d,\"st_dir\":%.1f,\"entry_quality\":%.2f,"
      "\"coherence_pct\":%.2f,\"kola_buy\":%.5f,\"kola_sell\":%.5f,\"price\":%.2f,\"timestamp\":%lld}",
      symbol, verdict_num, score_buy, score_sell, spike_pct, rsi, st_dir,
      entry_quality, coherence_pct, kola_buy, kola_sell, current_price, TimeCurrent()
   );

   char post[], result[];
   StringToCharArray(body, post, 0, StringLen(body));

   int res = WebRequest("POST", url, headers, 10000, post, result, headers);
   if(res == 200) {
      Print("[GOM-Sync] ✅ GOM data synced to server: " + symbol);
      return true;
   } else {
      Print("[GOM-Sync] ⚠️ GOM sync failed: HTTP " + IntegerToString(res));
      return false;
   }
}

//+------------------------------------------------------------------+
