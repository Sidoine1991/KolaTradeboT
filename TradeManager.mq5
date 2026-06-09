//+------------------------------------------------------------------+
//| TradeManager.mq5 v3 — Multi-symbole universel                   |
//| Trailing stop + re-entrée sur EMA la plus proche                 |
//| Attacher sur UN SEUL chart — gère tout le terminal               |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "3.24"
#property strict
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>

input group "=== TRAILING STOP ==="
input bool   UseTrailing            = true;   // Activer trailing stop
// Trailing : actif dès $2 profit, ferme si recul > 30% du gain depuis le pic ($2 → plancher $1.40)
input double TrailActivateUSD       = 2.0;    // Activer trailing dès profit >= $2 (métaux/forex)
input double TrailLockPct           = 0.30;   // Verrouiller 70% du pic — ferme si recul > 30%

input group "=== SORTIE PROFIT STAGNÉ ==="
input bool   UseStagnationExit        = true;   // Couper si profit stagne puis recule
input double StagnationTriggerUSD     = 2.0;    // Surveiller dès profit >= $2
input int    StagnationHoldSec        = 120;    // Temps min en zone profit (sec) — 2 minutes
input double StagnationMaxGivebackUSD = 0.60;   // Recul max depuis le pic (30% de $2 = $0.60)
input double StagnationLockMinUSD     = 1.40;   // Plancher absolu après armement ($2 - $0.60)
input double StagnationFlatBandUSD    = 0.25;   // Bande stagnation (USD)

input group "=== LIMITES GLOBALES ==="
input int    MaxGlobalPositions     = 2;      // Max positions simultanées tous symboles confondus
input bool   ReEntryIgnoreGlobal    = true;   // Re-entrée même symbole exempt de la limite globale

input group "=== RE-ENTRÉE SUR EMA ==="
input bool   UseReEntry             = true;   // Activer re-entrée automatique
input int    ReEntryMaxPerSymbol    = 3;      // Max re-entrées par position fermée
input int    ReEntryCooldownSec     = 30;     // Cooldown minimal entre tentatives (sec)
input int    EMA_Fast               = 8;      // EMA rapide M1 — 1ère cible
input int    EMA_Slow               = 21;     // EMA lente M1 — 2ème cible
input double EMATouch_Pct           = 0.5;   // Tolérance toucher EMA (% du spread)
input bool   RequireCorrectSide     = false;  // Bloquer prix "mauvais côté EMA"

input group "=== FILTRE RSI ==="
input int    RSI_Period             = 14;
input double RSI_SellMax            = 65.0;   // SELL bloqué si RSI > X
input double RSI_BuyMin             = 30.0;   // BUY bloqué si RSI < X

input group "=== FILTRE ==="
input int    MagicFilter            = 0;      // Magic number (0 = tous)
input int    CheckIntervalSec       = 5;      // Intervalle vérification (sec)

input group "=== AUTO SL/TP ==="
input bool   AutoAssignSLTP         = true;   // Auto-assigner SL/TP si manquants
input double MaxRiskUSD             = 3.5;    // Perte max absolue métaux/forex (USD) — fermeture marché
input double TargetProfitUSD        = 10.0;   // TP cible (USD)

input group "=== PROTECTION PROFIT (anti dégringolade) ==="
input bool   UseProfitGivebackExit  = true;   // Fermer au marché si gain → perte
// Armé dès $2 profit — ferme si recul > 30% du pic ($2 → plancher $1.40)
input double ProfitGivebackArmUSD   = 2.0;    // Actif dès pic profit >= $2
input double MaxGivebackFromPeakUSD = 0.30;   // Recul max = 30% du pic (pic $2 → plancher $1.40)
input double MaxLossCapUSD          = 3.5;    // Perte absolue max si jamais été en gain (=MaxRiskUSD)
input int    MaxPositionsPerSymbol  = 2;      // Max positions gérées par symbole (évite 2 dup en perte)

input group "=== PROFIT GLOBAL ==="
input bool   UseGlobalProfitTarget  = true;   // Fermer tout si profit total >= cible
input double GlobalProfitTargetUSD  = 10.0;   // Cible profit global (USD) — somme positions MCP
input bool   GlobalProfitMCPOnly    = true;   // Ne compter que les positions magic MCP (bridge)

input group "=== CAPITAL MANAGER — GAME CHANGER ==="
input bool   UseCapitalManager      = true;   // Activer gestion intelligente du capital
input double CM_DailyTargetPct      = 5.0;    // Objectif profit journalier (% du capital) — 5% de $50 = $2.50
input double CM_DailyStopLossPct    = 6.0;    // Stop perte journalier (% du capital) — ex: 6% de $50 = $3
input int    CM_MaxTradesPerDay      = 3;      // Max trades par jour (0 = calculé automatiquement)
input double CM_MinCapitalToTrade    = 20.0;   // Ne pas trader si capital < ce montant ($)
input double CM_LotRiskPct          = 2.0;    // Risque par trade (% du capital) pour lot sizing adaptatif
input bool   CM_PersistStats        = true;   // Sauvegarder stats journalières en fichier (survit rechargement)

input group "=== MODE EXÉCUTION ==="
input bool   PipelineOnlyMode       = true;   // 🔒 MODE STRICT: Uniquement ordres pipeline (désactive TOUTES entrées auto)
input string PipelineWhitelistPath  = "pipeline_whitelist.json"; // Whitelist pipeline (Common/Files)

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
input string InpPollSymbols         =
   // Boom / Crash (tous les indices synthétiques Deriv)
   "Boom 300 Index,Boom 500 Index,Boom 600 Index,Boom 900 Index,Boom 1000 Index,"
   "Crash 300 Index,Crash 500 Index,Crash 600 Index,Crash 900 Index,Crash 1000 Index,"
   // Volatility Index Deriv
   "Volatility 10 Index,Volatility 25 Index,Volatility 50 Index,Volatility 75 Index,Volatility 100 Index,"
   "Volatility 10 (1s) Index,Volatility 25 (1s) Index,Volatility 50 (1s) Index,Volatility 75 (1s) Index,Volatility 100 (1s) Index,"
   // Métaux
   "XAUUSD,XAGUSD,Gold Basket,"
   // Forex majeurs
   "EURUSD,GBPUSD,USDJPY,USDCHF,AUDUSD,NZDUSD,USDCAD,EURGBP,EURJPY,GBPJPY,"
   // Indices boursiers
   "US30,US500,NAS100,USTEC,UK100,GER40,JPN225,"
   // Crypto
   "BTCUSD,ETHUSD,BNBUSD,SOLUSD,XRPUSD,ADAUSD";

input group "=== NOTIFICATIONS WHATSAPP ==="
input bool   UseWhatsApp            = true;   // Envoyer alertes WhatsApp
input int    WATimeoutMs            = 8000;   // Timeout requête WhatsApp (ms)

input group "=== ALIGNEMENT SIGNAL (TA + MCP) ==="
input bool   RequireSignalAlign     = false;  // 🔧 DÉSACTIVÉ: Trop de blocages (fix log)
input int    SignalCacheAgeSec      = 300;    // Durée validité cache biais (sec, 0=désactivé)
input double MinTAConfidence        = 0.55;   // Confiance TA minimum pour que le biais compte

input group "=== FILTRE CONSOLIDATION ==="
input bool   UseConsolidationFilter = true;   // Bloquer trades en range (ADX + ATR)
input int    ADX_Period             = 14;     // Période ADX
input double ADX_MinTrend           = 20.0;   // ADX < 20 = range → entrée bloquée
input double ConsolidationATRRatio  = 0.65;  // ATR < 65% de la moyenne = range serré

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
input double GlobalMinCoherencePct    = 45.0;  // Cohérence GOM minimale (%) — 45 évite de bloquer les PERFECT BUY/SELL
input bool   UseBBTrendFilter         = true;  // Bloquer entrée si BB contre-tendance (prix sous BB Mid + pente baissière → pas de BUY)
input int    BBTrendPeriod            = 20;    // Période Bollinger Band pour filtre tendance
input int    BBTrendSlopeBars         = 3;     // Barres pour mesurer la pente de la BB Middle

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
input bool   TVSetupSpikeMarket       = true;  // Entrée marché immédiate PRE-SPIKE Boom/Crash (TV)

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

input group "=== DERIV SYNTHETICS (Boom / Crash / Volatility) ==="
input bool   UseDerivEngine         = true;   // Activer moteur spike pour Boom/Crash
input bool   DRV_AutoPresets        = true;   // Ajuster seuils auto selon le variant (300/500/1000)
input double DRV_SpikeBodyMult      = 0.50;   // Corps min = N * ATR
input double DRV_SpikeWickMult      = 0.60;   // Mèche min = N * ATR
input int    DRV_BarsMin            = 8;      // Cycle attendu (barres) — Boom500=8, 1000=16
input double DRV_WindowStart        = 0.60;   // Début fenêtre anticipation (% cycle)
input double DRV_WindowEnd          = 0.85;   // Fin fenêtre anticipation
input int    DRV_PullbackBars       = 3;      // Barres max post-spike pour pullback entry
input bool   DRV_UseBOS            = true;   // ICT — Break of Structure
input bool   DRV_UseCHOCH          = true;   // ICT — Change of Character
input bool   DRV_UseLiqSweep       = true;   // ICT — Liquidity Sweep
input bool   DRV_UseOB             = true;   // ICT — Order Block
input bool   DRV_UseFVG            = true;   // ICT — Fair Value Gap
input bool   DRV_UseOTE            = true;   // ICT — Optimal Trade Entry (Fib 62-79%)
input int    DRV_MinICTScore        = 0;      // Score ICT minimum (0=OFF, 40=souple, 70=strict)
input int    DRV_ICTLookback        = 20;     // Barres pour détection ICT
input double DRV_SL_ATR             = 1.5;    // SL = N * ATR
input double DRV_TP_ATR             = 3.0;    // TP = N * ATR
input bool   DRV_UseQuickExit       = true;   // Fermer sur spike suivant
input double DRV_QuickExitMinPct    = 0.3;    // Profit min avant quick exit (% ATR)
input int    DRV_TimeStopMin        = 20;     // Fermer après N minutes
input bool   DRV_UseSmartBE         = true;   // Breakeven automatique
input double DRV_BETrigger          = 1.0;    // Déclencher BE à N*ATR profit
input bool   DRV_UseTrail           = true;   // Trailing stop
input double DRV_TrailATR           = 0.5;    // Distance trailing = N * ATR
input double DRV_TrailActivation    = 0.8;    // Activer trailing à N*ATR profit

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

// Daily Profit Target (CM_DailyTargetPct)
bool     g_dailyTargetHit    = false;  // true = objectif % atteint aujourd'hui → bloquer entrées
datetime g_dailyResetDate    = 0;      // date du dernier reset (comparaison jour calendaire)
double   g_dailyStartBalance = 0.0;    // balance au début de la journée
int      g_dailyTradeCount   = 0;      // 🆕 nombre de trades ouverts aujourd'hui
int      g_maxDailyTrades    = 7;      // 🆕 max 7 trades par jour (DISCIPLINE)
double   g_dailyProfitTarget = 20.0;   // 🆕 cible: 20$ de profit → STOP entrées

// GOM Scalp Loop
datetime g_lastGOMPoll       = 0;
int      g_lastGOMAutoVnum   = 0;
datetime g_lastGOMAutoEntry  = 0;
string   g_lastGOMVerdict    = "";
int      g_lastGOMRSI        = 50;
bool     g_gomRSIOversold    = false;
bool     g_gomRSIOverbought  = false;
int      g_lastGOMVerdictNum = 999;   // Init neutre (999=pas update encore). 0=WAIT, ±1=BUY/SELL, ±2=GOOD, ±3=PERFECT
string   g_lastKOLAState     = "";  // "NEAR BUY" | "NEAR SELL" | "NEUTRAL"
bool     g_isConsolidation   = false; // KOLA diverge du verdict
double   g_lastGOMQuality    = 0.0; // entry_quality %
double   g_lastGOMCoherence  = 0.0; // coherence_pct %
double   g_lastGOMScoreBuy   = 0.0;
double   g_lastGOMScoreSell  = 0.0;
string   g_lastGOMGlobalDir  = "";  // "BULL" | "BEAR" | "NEUT"
int      g_lastGOMGlobalStrength = 0; // 0-100

// GHOST OrderFlow — mis à jour depuis /gom-verdict (plots data_window)
double   g_ghostDelta   = 0.0;  // delta volume bougie courante (+ = buyers, - = sellers)
double   g_ghostCVD     = 0.0;  // CVD cumulatif session
double   g_ghostBuyPct  = 50.0; // sentiment BUY% pondéré volume (20 barres)
double   g_ghostCompass = 0.0;  // angle boussole momentum 0-360°

// Order Blocks confirmés depuis TradingView Pine
double   g_obBullTop    = 0.0;
double   g_obBullBot    = 0.0;
double   g_obBearTop    = 0.0;
double   g_obBearBot    = 0.0;

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
double   g_lastBBMid          = 0.0;  // SMA20 — zone de rebond en tendance
double   g_lastBBDn           = 0.0;
datetime g_lastBBCurveDraw    = 0;    // timestamp dernier dessin courbes BB
double   g_setupBuyProb       = 0.0;
double   g_setupSellProb      = 0.0;
double   g_setupValidProb     = 0.0;
double   g_predHitRate        = 0.0;
bool     g_spikeTradable      = false;
double   g_spikeImminence     = 0.0;

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

// 🔒 MODE PIPELINE ONLY — Garde toutes entrées automatiques
bool CanAutoEntry(const string context, const string sym = "")
{
   if(!PipelineOnlyMode)
      return true;  // Mode normal — toutes entrées auto autorisées

   // Mode strict — UNIQUEMENT ordres pipeline
   string symCheck = (StringLen(sym) > 0) ? sym : _Symbol;

   if(!IsSymbolWhitelisted(symCheck))
   {
      PrintOnce(StringFormat("[%s] 🔒 BLOQUÉ: %s pas dans whitelist pipeline (PipelineOnlyMode=true)",
                context, symCheck), 120);
      return false;
   }

   // Whitelist OK mais entrée auto désactivée en mode strict
   PrintOnce(StringFormat("[%s] 🔒 BLOQUÉ: Entrée auto désactivée (PipelineOnlyMode=true) — attendre signal pipeline",
             context), 120);
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
   string   source;         // "pipeline" | "ob_reentry" | "" (GOM auto)
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
   datetime lastSLHitTime;   // Timestamp dernière fermeture par SL — bloque re-entrée 10min
   int      consecutiveLosses; // Nombre de SL consécutifs sur ce symbole
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

// 🆕 Statistiques trades pour dashboard
int      g_totalWins           = 0;      // Trades fermés en profit
int      g_totalLosses         = 0;      // Trades fermés en perte
double   g_totalProfitWins     = 0.0;    // Profit total des wins
double   g_totalLossPerfect    = 0.0;    // Perte totale des losses
double   g_lastTradeProfit     = 0.0;    // Profit du dernier trade fermé

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   EventSetTimer(CheckIntervalSec);
   ScanAllPositions();
   Print("[TradeManager v3.19] Actif | 🔒 PipelineOnly=", PipelineOnlyMode,
         " | MCP market=", MCPExecuteAtMarket,
         " | giveback=", UseProfitGivebackExit, " maxLoss=$", MaxLossCapUSD,
         " | stagnation=", UseStagnationExit, " @$", StagnationTriggerUSD, "/", StagnationHoldSec, "s",
         " | dup=", MCPDuplicateOnce, " | profit global=$", GlobalProfitTargetUSD,
         " | EMA", EMA_Fast, "/", EMA_Slow, " | positions=", g_stateCount);

   if(PipelineOnlyMode)
   {
      Print("┌─────────────────────────────────────────────────────────────┐");
      Print("│  🔒 MODE PIPELINE ONLY ACTIF                               │");
      Print("│  TOUTES les entrées automatiques sont DÉSACTIVÉES          │");
      Print("│  TradeManager = EXÉCUTEUR PASSIF uniquement                │");
      Print("│                                                             │");
      Print("│  Ordres acceptés UNIQUEMENT depuis:                        │");
      Print("│  → Pipeline autonome (autonomous_pipeline.py)              │");
      Print("│  → /pending-order API (signaux MCP validés)                │");
      Print("│                                                             │");
      Print("│  BLOQUÉ:                                                    │");
      Print("│  ❌ GOM AutoEntry / ReEntry                                │");
      Print("│  ❌ TradingView Setups automatiques                        │");
      Print("│  ❌ Re-entrées EMA                                         │");
      Print("│  ❌ Duplications manuelles                                 │");
      Print("│  ❌ Moteur Deriv (Boom/Crash spikes)                       │");
      Print("└─────────────────────────────────────────────────────────────┘");
   }
   else
   {
      Print("⚠️ MODE AUTO TRADING ACTIF — Toutes entrées auto autorisées");
   }
   if(UseDashboard) {
      Print("[Dashboard] Enabled - Update interval: " + IntegerToString(DashboardUpdateSec) + "s");
      RefreshDashboard();
   }

   // Handles indicateurs Deriv (uniquement sur symboles synthétiques)
   if(UseDerivEngine && (IsBoomOrCrashSymbol(_Symbol) || DRV_IsVolatility()))
   {
      g_drvHATR = iATR(_Symbol, PERIOD_M1, 14);
      g_drvHRSI = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
      g_drvBarsSinceSpike  = DRV_GetCycle() / 2;
      g_drvLastProcessedBar= 0;
      g_drvTradeTaken      = false;
      Print(StringFormat("[DRV] Moteur Deriv activé — %s | Cycle=%d | Fenêtre %.0f-%.0f%%",
            _Symbol, DRV_GetCycle(), DRV_WindowStart*100, DRV_WindowEnd*100));
   }

   // Forcer un poll + dessin immédiat au chargement — pas d'attente du premier tick
   if(UseGOMScalp)
   {
      g_lastGOMPoll = 0; // forcer le poll
      PollGOMScalpVerdict();
   }
   DrawEntryLevels();
   DrawBollingerCurves(true);  // dessin initial au chargement
   if(ShowGOMPathCandles) DrawGOMPathPredictedCandles();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| 🆕 Discipline Trading: Max 7/jour, Cible 20USD → STOP entrées     |
//+------------------------------------------------------------------+
bool CanEnterTrade(const string reason = "")
{
   // Vérifier cible de profit 20 USD atteinte
   double closedPnl = CalcDailyClosedProfit();
   if(closedPnl >= g_dailyProfitTarget)
   {
      Print(StringFormat("[DISCIPLINE] ❌ BLOQUE: Cible profit +$%.2f atteinte | raison: %s", closedPnl, reason));
      return false;
   }

   // Vérifier max 7 trades/jour
   if(g_dailyTradeCount >= g_maxDailyTrades)
   {
      Print(StringFormat("[DISCIPLINE] ❌ BLOQUE: %d/%d trades atteint | raison: %s", g_dailyTradeCount, g_maxDailyTrades, reason));
      return false;
   }

   return true;  // ✅ Autorisé
}

//+------------------------------------------------------------------+
//| Wrapper: Enregistrer nouvelle entrée + vérifier discipline        |
//+------------------------------------------------------------------+
void RegisterTradeEntry(const int direction, const string entryType = "")
{
   g_dailyTradeCount++;
   double closedPnl = CalcDailyClosedProfit();
   int remaining = g_maxDailyTrades - g_dailyTradeCount;
   string dirStr = (direction > 0) ? "BUY" : "SELL";
   Print(StringFormat("[DISCIPLINE] TRADE #%d/%d | direction=%s type=%s | PnL=$%.2f | Restantes: %d",
         g_dailyTradeCount, g_maxDailyTrades, dirStr, entryType, closedPnl, remaining));
}

//+------------------------------------------------------------------+
//| Afficher status discipline toutes les 30 min                      |
//+------------------------------------------------------------------+
void DisplayDisciplineStatus()
{
   static datetime lastDisplay = 0;
   if(TimeCurrent() - lastDisplay < 1800) return;  // 30 minutes
   lastDisplay = TimeCurrent();

   double closedPnl = CalcDailyClosedProfit();
   int remaining = g_maxDailyTrades - g_dailyTradeCount;
   bool targetReached = (closedPnl >= g_dailyProfitTarget);
   bool tradesMaxed = (g_dailyTradeCount >= g_maxDailyTrades);

   string tradesStatus = tradesMaxed ? "MAXED" : "OK";
   string targetStatus = targetReached ? "ATTEINT" : "...";
   string globalStatus = (tradesMaxed || targetReached) ? "DESACTIF" : "ACTIF";
   string reasonStatus = "";
   if(tradesMaxed && targetReached) reasonStatus = "MAX TRADES ET CIBLE";
   else if(tradesMaxed) reasonStatus = "MAX TRADES";
   else if(targetReached) reasonStatus = "CIBLE 20USD";
   else reasonStatus = "NORMAL";

   Print("[DISCIPLINE STATUS] Trades: " + IntegerToString(g_dailyTradeCount) + "/" + IntegerToString(g_maxDailyTrades) + " (" + tradesStatus + ")");
   Print("  Cible: $" + StringFormat("%.2f", closedPnl) + "/$" + StringFormat("%.2f", g_dailyProfitTarget) + " (" + targetStatus + ") | Restantes: " + IntegerToString(remaining));
   Print("  Status: TRADING " + globalStatus + " — " + reasonStatus);
}

//+------------------------------------------------------------------+
//| 🆕 Surveillance GOM + Fermeture auto si WAIT                      |
//+------------------------------------------------------------------+
void MonitorGOMWaitClosePositions()
{
   if(!IsGOMVerdictWait()) return;  // Rien à faire si GOM n'est pas WAIT

   // Parcourir toutes les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;

      string posSymbol = PositionGetString(POSITION_SYMBOL);
      if(posSymbol != _Symbol) continue;  // Ignorer autres symboles

      ulong ticket = PositionGetTicket(i);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double pnl = PositionGetDouble(POSITION_PROFIT);
      int dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;

      // Fermer la position avec message explicite
      CTrade tradeClose;
      if(tradeClose.PositionClose(ticket, 50))
      {
         Print(StringFormat("[GOM-WAIT-CLOSE] ✅ %s fermée | entry=%.5f pnl=%.2f | verdict=WAIT (vnum=%d)",
               _Symbol, entry, pnl, g_lastGOMVerdictNum));
      }
      else
      {
         Print(StringFormat("[GOM-WAIT-CLOSE] ❌ %s erreur fermeture | ticket=%d | %s",
               _Symbol, ticket, tradeClose.ResultRetcodeDescription()));
      }
   }
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_drvHATR!=INVALID_HANDLE) IndicatorRelease(g_drvHATR);
   if(g_drvHRSI!=INVALID_HANDLE) IndicatorRelease(g_drvHRSI);
   if(UseDashboard) RemoveAllDashboardObjects();
   // Ne pas supprimer les niveaux GOM/OB/chemin — ils restent visibles après rechargement
   // CleanupGOMPathObjects() — désactivé intentionnellement
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
   if(UseDerivEngine)        RunDerivEngine();
   if(IsBoomOrCrashSymbol(_Symbol)) MonitorSpikeAutoClose();
   if(UseCapitalManager)     CheckDailyProfitTarget();
   DisplayDisciplineStatus();  // 🆕 Afficher status discipline toutes les 30 min
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
   // Mise à jour flag barre confirmée pour MonitorSpikeAutoClose
   static datetime _lastBar = 0;
   datetime _curBar = iTime(_Symbol, PERIOD_M1, 0);
   barstate_isconfirmed_local = (_curBar != _lastBar);
   if(barstate_isconfirmed_local) _lastBar = _curBar;

   static datetime lastRun = 0;
   if(TimeCurrent() - lastRun < CheckIntervalSec) return;
   lastRun = TimeCurrent();
   ScanAllPositions();
   if(UseDerivEngine)        RunDerivEngine();
   if(UseCapitalManager)     CheckDailyProfitTarget();
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
   if(UseGOMScalp)           MonitorGOMWaitClosePositions();  // 🆕 Fermer si GOM passe à WAIT
   if(UseTVSetupLimit)       ManageTVSetupLimitOrder();
   DrawEntryLevels();
   DrawBollingerCurves();    // courbes BB — redessinées toutes les 60s ou sur rapport TA
}

//+------------------------------------------------------------------+
//| SETUP TV — ordre limite + annulation entry touchée + GOM WAIT    |
//+------------------------------------------------------------------+
bool IsGOMVerdictWait()
{
   if(g_lastGOMVerdictNum == 999) return false;  // Pas encore update (startup) → pas WAIT
   if(g_lastGOMVerdictNum == 0) return true;     // 0 = WAIT verdict
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

bool IsBBCounterTrend(const int tradeDir)
{
   if(!UseBBTrendFilter || tradeDir == 0) return false;

   int hBB = iBands(_Symbol, PERIOD_CURRENT, BBTrendPeriod, 0, 2.0, PRICE_CLOSE);
   if(hBB == INVALID_HANDLE) return false;

   double bufMid[];
   ArraySetAsSeries(bufMid, true);
   if(CopyBuffer(hBB, 0, 0, BBTrendSlopeBars + 1, bufMid) < BBTrendSlopeBars + 1)
   {
      IndicatorRelease(hBB);
      return false;
   }
   IndicatorRelease(hBB);

   double price = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2.0;
   double bbMid = bufMid[0];
   double bbMidPrev = bufMid[BBTrendSlopeBars];
   bool slopeDown = (bbMid < bbMidPrev);
   bool slopeUp   = (bbMid > bbMidPrev);

   if(tradeDir == 1 && price < bbMid && slopeDown)
   {
      PrintOnce(StringFormat("[BB-Filter] BUY bloqué — prix (%.5f) sous BB Mid (%.5f) + pente baissière",
            price, bbMid), 30);
      return true;
   }
   if(tradeDir == -1 && price > bbMid && slopeUp)
   {
      PrintOnce(StringFormat("[BB-Filter] SELL bloqué — prix (%.5f) au-dessus BB Mid (%.5f) + pente haussière",
            price, bbMid), 30);
      return true;
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
   return true; // Dessiner le chemin prédictif sur TOUS les symboles
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
// Dessine une ligne horizontale bornée dans le temps (OBJ_TREND) avec label
void DrawTLine(const string name, const double price, const color clr,
               const int width, const ENUM_LINE_STYLE style, const string lbl,
               const int barsBack = 5, const int barsForward = 80)
{
   ObjectDelete(0, name);
   if(price <= 0) return;
   datetime t0  = iTime(_Symbol, PERIOD_CURRENT, barsBack);
   datetime tE  = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * barsForward;
   if(t0 <= 0) t0 = TimeCurrent() - PeriodSeconds(PERIOD_CURRENT) * barsBack;
   ObjectCreate(0, name, OBJ_TREND, 0, t0, price, tE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      width);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      style);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT,  false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ObjectSetString (0, name, OBJPROP_TEXT,       lbl);
}

//+------------------------------------------------------------------+
//| Trace les courbes BB (Sup/Mid/Inf) sur 200 barres hist + 200     |
//| barres projetées. Appelé à chaque nouveau rapport TradingAgents. |
//+------------------------------------------------------------------+
void DrawBollingerCurves(bool forceRedraw = false)
{
   // Redessiner si forcé (nouveau rapport TA) ou toutes les 60s
   if(!forceRedraw && (int)(TimeCurrent() - g_lastBBCurveDraw) < 60) return;
   g_lastBBCurveDraw = TimeCurrent();

   // Supprimer les anciens objets BB courbe + les lignes plates obsolètes
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, 0, -1);
      if(StringFind(nm, "TM_BB_CURVE_") == 0 || nm == "TM_BB_UP" || nm == "TM_BB_MID" || nm == "TM_BB_DN")
         ObjectDelete(0, nm);
   }

   ENUM_TIMEFRAMES period = PERIOD_CURRENT;
   int bbPer   = 20;
   int bars    = 200;  // barres historiques
   int proj    = 200;  // barres projetées
   int dg      = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // Handles BB pour le symbole courant
   int hBB = iBands(_Symbol, period, bbPer, 0, 2.0, PRICE_CLOSE);
   if(hBB == INVALID_HANDLE) return;

   double bufUp[], bufMid[], bufDn[];
   ArraySetAsSeries(bufUp,  true);
   ArraySetAsSeries(bufMid, true);
   ArraySetAsSeries(bufDn,  true);

   int copied = CopyBuffer(hBB, 1, 0, bars, bufUp);   // band supérieure
   CopyBuffer(hBB, 0, 0, bars, bufMid);                // milieu (SMA20)
   CopyBuffer(hBB, 2, 0, bars, bufDn);                 // band inférieure
   IndicatorRelease(hBB);

   if(copied < 2) return;

   int ptSec = PeriodSeconds(period);

   // ── Tracer 200 barres historiques ────────────────────────────────
   for(int i = copied - 1; i >= 1; i--)
   {
      datetime t1 = iTime(_Symbol, period, i);
      datetime t2 = iTime(_Symbol, period, i - 1);
      if(t1 <= 0 || t2 <= 0) continue;

      string sfx = IntegerToString(copied - 1 - i);

      // BB Sup — argent
      string nmU = "TM_BB_CURVE_U" + sfx;
      ObjectCreate(0, nmU, OBJ_TREND, 0, t1, bufUp[i], t2, bufUp[i-1]);
      ObjectSetInteger(0, nmU, OBJPROP_COLOR,     clrSilver);
      ObjectSetInteger(0, nmU, OBJPROP_WIDTH,     1);
      ObjectSetInteger(0, nmU, OBJPROP_STYLE,     STYLE_DOT);
      ObjectSetInteger(0, nmU, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nmU, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, nmU, OBJPROP_BACK,      true);

      // BB Mid — or (SMA20, ligne de rebond)
      string nmM = "TM_BB_CURVE_M" + sfx;
      ObjectCreate(0, nmM, OBJ_TREND, 0, t1, bufMid[i], t2, bufMid[i-1]);
      ObjectSetInteger(0, nmM, OBJPROP_COLOR,     clrGold);
      ObjectSetInteger(0, nmM, OBJPROP_WIDTH,     1);
      ObjectSetInteger(0, nmM, OBJPROP_STYLE,     STYLE_DOT);
      ObjectSetInteger(0, nmM, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nmM, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, nmM, OBJPROP_BACK,      true);

      // BB Inf — argent
      string nmD = "TM_BB_CURVE_D" + sfx;
      ObjectCreate(0, nmD, OBJ_TREND, 0, t1, bufDn[i], t2, bufDn[i-1]);
      ObjectSetInteger(0, nmD, OBJPROP_COLOR,     clrSilver);
      ObjectSetInteger(0, nmD, OBJPROP_WIDTH,     1);
      ObjectSetInteger(0, nmD, OBJPROP_STYLE,     STYLE_DOT);
      ObjectSetInteger(0, nmD, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nmD, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, nmD, OBJPROP_BACK,      true);
   }

   // ── Projection 200 barres futures (motif cyclique per-bar) ─────────
   // Extraction du motif : deltas réels des 40 dernières barres
   int patLen = MathMin(40, copied - 2);
   if(patLen < 2) return;

   double deltaU[], deltaM[], deltaD[];
   ArrayResize(deltaU, patLen);
   ArrayResize(deltaM, patLen);
   ArrayResize(deltaD, patLen);
   for(int k = 0; k < patLen; k++)
   {
      // buf[k] = barre la plus récente → buf[k+1] = barre précédente
      // delta positif = bande montait de k+1 vers k
      deltaU[k] = bufUp[k]  - bufUp[k+1];
      deltaM[k] = bufMid[k] - bufMid[k+1];
      deltaD[k] = bufDn[k]  - bufDn[k+1];
   }

   double prevU = bufUp[0], prevM = bufMid[0], prevD = bufDn[0];
   datetime prevT = iTime(_Symbol, period, 0);

   for(int p = 1; p <= proj; p++)
   {
      datetime t2p = prevT + (datetime)ptSec;
      int    patIdx = (p - 1) % patLen;
      double damp   = MathPow(0.97, p);   // 3% d'atténuation par barre
      double nextU  = prevU + deltaU[patIdx] * damp;
      double nextM  = prevM + deltaM[patIdx] * damp;
      double nextD  = prevD + deltaD[patIdx] * damp;

      string sfxP = "P" + IntegerToString(p);

      string nmUP = "TM_BB_CURVE_U" + sfxP;
      ObjectCreate(0, nmUP, OBJ_TREND, 0, prevT, prevU, t2p, nextU);
      ObjectSetInteger(0, nmUP, OBJPROP_COLOR,     C'100,100,100');  // gris foncé projection
      ObjectSetInteger(0, nmUP, OBJPROP_WIDTH,     1);
      ObjectSetInteger(0, nmUP, OBJPROP_STYLE,     STYLE_DOT);
      ObjectSetInteger(0, nmUP, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nmUP, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, nmUP, OBJPROP_BACK,      true);

      string nmMP = "TM_BB_CURVE_M" + sfxP;
      ObjectCreate(0, nmMP, OBJ_TREND, 0, prevT, prevM, t2p, nextM);
      ObjectSetInteger(0, nmMP, OBJPROP_COLOR,     C'180,140,0');    // or foncé projection
      ObjectSetInteger(0, nmMP, OBJPROP_WIDTH,     1);
      ObjectSetInteger(0, nmMP, OBJPROP_STYLE,     STYLE_DOT);
      ObjectSetInteger(0, nmMP, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nmMP, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, nmMP, OBJPROP_BACK,      true);

      string nmDP = "TM_BB_CURVE_D" + sfxP;
      ObjectCreate(0, nmDP, OBJ_TREND, 0, prevT, prevD, t2p, nextD);
      ObjectSetInteger(0, nmDP, OBJPROP_COLOR,     C'100,100,100');
      ObjectSetInteger(0, nmDP, OBJPROP_WIDTH,     1);
      ObjectSetInteger(0, nmDP, OBJPROP_STYLE,     STYLE_DOT);
      ObjectSetInteger(0, nmDP, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nmDP, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, nmDP, OBJPROP_BACK,      true);

      prevU = nextU; prevM = nextM; prevD = nextD; prevT = t2p;
   }

   // Label sur la dernière barre projetée
   ObjectCreate(0, "TM_BB_LBL_U", OBJ_TEXT, 0, prevT, prevU);
   ObjectSetString(0, "TM_BB_LBL_U", OBJPROP_TEXT, "BB Sup →");
   ObjectSetInteger(0, "TM_BB_LBL_U", OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(0, "TM_BB_LBL_U", OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, "TM_BB_LBL_U", OBJPROP_SELECTABLE, false);

   ObjectCreate(0, "TM_BB_LBL_M", OBJ_TEXT, 0, prevT, prevM);
   ObjectSetString(0, "TM_BB_LBL_M", OBJPROP_TEXT, "BB Mid →");
   ObjectSetInteger(0, "TM_BB_LBL_M", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, "TM_BB_LBL_M", OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, "TM_BB_LBL_M", OBJPROP_SELECTABLE, false);

   ObjectCreate(0, "TM_BB_LBL_D", OBJ_TEXT, 0, prevT, prevD);
   ObjectSetString(0, "TM_BB_LBL_D", OBJPROP_TEXT, "BB Inf →");
   ObjectSetInteger(0, "TM_BB_LBL_D", OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(0, "TM_BB_LBL_D", OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, "TM_BB_LBL_D", OBJPROP_SELECTABLE, false);

   ChartRedraw(0);
}

void DrawEntryLevels()
{
   static datetime s_lastDraw = 0;
   if((int)(TimeCurrent() - s_lastDraw) < 3) return;
   s_lastDraw = TimeCurrent();

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // ── Niveaux KOLA ──────────────────────────────────────────────────
   DrawTLine("TM_KOLA_BUY",  g_lastKolaBuy,  clrDodgerBlue, 2, STYLE_DASH,
             StringFormat("KOLA BUY %."+IntegerToString(dg)+"f", g_lastKolaBuy));
   DrawTLine("TM_KOLA_SELL", g_lastKolaSell, clrOrangeRed,  2, STYLE_DASH,
             StringFormat("KOLA SELL %."+IntegerToString(dg)+"f", g_lastKolaSell));

   // ── BB courbes — dessinées par DrawBollingerCurves() appelé séparément ──
   // (200 barres hist + 200 barres projetées, redessinées sur nouveau rapport TA)

   // ── Niveaux OB Setup ──────────────────────────────────────────────
   if(g_setupValid && g_setupEntry > 0)
   {
      color cE = (g_setupDir == 1) ? clrDodgerBlue : clrOrangeRed;

      DrawTLine("TM_OB_ENTRY", g_setupEntry, cE, 3, STYLE_SOLID,
                StringFormat("ENTRY %s %."+IntegerToString(dg)+"f", g_setupType, g_setupEntry));
      DrawTLine("TM_OB_SL",    g_setupSL,    clrCrimson,   2, STYLE_DASH,
                StringFormat("SL %."+IntegerToString(dg)+"f", g_setupSL));
      DrawTLine("TM_OB_TP1",   g_setupTP1,   clrLimeGreen, 2, STYLE_DASH,
                StringFormat("TP1 %."+IntegerToString(dg)+"f", g_setupTP1));
      DrawTLine("TM_OB_TP2",   g_setupTP2,   clrLimeGreen, 1, STYLE_DOT,
                StringFormat("TP2 %."+IntegerToString(dg)+"f", g_setupTP2));

      // Zone OB colorée (rectangle Entry → SL)
      ObjectDelete(0, "TM_OB_ZONE");
      if(g_setupSL > 0)
      {
         datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 10);
         datetime tE = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 60;
         double zH = MathMax(g_setupEntry, g_setupSL);
         double zL = MathMin(g_setupEntry, g_setupSL);
         ObjectCreate(0, "TM_OB_ZONE", OBJ_RECTANGLE, 0, t0, zH, tE, zL);
         ObjectSetInteger(0, "TM_OB_ZONE", OBJPROP_COLOR,      cE);
         ObjectSetInteger(0, "TM_OB_ZONE", OBJPROP_BACK,       true);
         ObjectSetInteger(0, "TM_OB_ZONE", OBJPROP_FILL,       true);
         ObjectSetInteger(0, "TM_OB_ZONE", OBJPROP_SELECTABLE, false);
      }

      // Label résumé coin haut-gauche
      ObjectDelete(0, "TM_OB_LABEL");
      ObjectCreate(0, "TM_OB_LABEL", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_CORNER,    CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_YDISTANCE, 30);
      ObjectSetString (0, "TM_OB_LABEL", OBJPROP_TEXT,
         StringFormat("%s  E:%."+IntegerToString(dg)+"f  SL:%."+IntegerToString(dg)
            +"f  TP1:%."+IntegerToString(dg)+"f  RR:%.1f",
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

   // Si pred_path absent → construire localement depuis pred_net et les TF GOM
   string usePath = g_predPath;
   if(StringLen(usePath) < 5)
   {
      // pred_net = différence bull-bear sur 200 barres
      // On construit un chemin simplifié depuis la direction globale et pred_net
      int netDir = 0;
      if(g_predNet > 20)       netDir =  1;  // tendance haussière
      else if(g_predNet < -20) netDir = -1;  // tendance baissière

      // Fallback : utiliser la direction GOM globale
      if(netDir == 0)
      {
         if(StringCompare(g_lastGOMGlobalDir, "BULL") == 0) netDir =  1;
         if(StringCompare(g_lastGOMGlobalDir, "BEAR") == 0) netDir = -1;
      }

      if(netDir != 0)
      {
         string ch = (netDir == 1) ? "U" : "D";
         int nGen = MathMin(GOMPathDrawBars, 60); // 60 barres max en mode local
         usePath = "";
         for(int k = 0; k < nGen; k++) usePath += ch;
         PrintOnce(StringFormat("[GOM-Path] pred_path local construit (%d barres %s depuis pred_net=%d global=%s)",
               nGen, ch, g_predNet, g_lastGOMGlobalDir), 60);
      }
      else
      {
         PrintOnce("[GOM-Path] pred_path absent et direction indéterminée — dessin ignoré", 120);
         return;
      }
   }

   CleanupGOMPathObjects();

   ENUM_TIMEFRAMES tf = PERIOD_CURRENT;
   int nBars = MathMin(GOMPathDrawBars, StringLen(usePath));
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
      ushort ch = StringGetCharacter(usePath, i);
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

   if(sb >= ss && gap >= 0.3 && kola_buy > 0)
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
   else if(ss > sb && gap >= 0.3 && kola_sell > 0)
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

   // 🔒 GARDE PIPELINE ONLY MODE
   if(!CanAutoEntry("TV-Setup-Limit", _Symbol)) return false;

   if(IsDailyTargetLocked())
   {
      PrintOnce("[CM] 🔒 TVSetup bloqué — objectif journalier atteint", 300);
      return false;
   }
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
      else
      {
         // vnum=0 (WAIT) : bloquer placement sauf si TVSetupBlockPlaceOnWait désactivé explicitement
         if(g_lastGOMVerdictNum == 0)
         {
            PrintOnce("[TV-Setup] Setup ignoré — GOM WAIT (vnum=0)", 30);
            return false;
         }
         if(g_setupDir == 1 && g_lastGOMVerdictNum < 0)
         {
            PrintOnce("[TV-Setup] Setup BUY ignoré — verdict GOM baissier actif", 30);
            return false;
         }
         if(g_setupDir == -1 && g_lastGOMVerdictNum > 0)
         {
            PrintOnce("[TV-Setup] Setup SELL ignoré — verdict GOM haussier actif", 30);
            return false;
         }
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

// Pre-spike Boom/Crash : entrée marché immédiate depuis signal TV
bool TryTVPreSpikeMarketEntry()
{
   if(!TVSetupSpikeMarket || !g_setupValid || g_setupDir == 0) return false;

   // 🔒 GARDE PIPELINE ONLY MODE
   if(!CanAutoEntry("TV-PreSpike", _Symbol)) return false;

   if(StringFind(g_setupType, "SPIKE_") < 0 && !g_spikeTradable) return false;
   if(!IsBoomOrCrashSymbol(_Symbol)) return false;
   if(IsDailyTargetLocked()) return false;
   if(HasMCPOpenPosition(_Symbol) || IsGlobalPositionLimitReached()) return false;
   if((int)(TimeCurrent() - g_tvSetupBreakoutDone) < GOMAutoEntryCooldownSec) return false;

   ulong pending = 0;
   if(FindTVSetupPendingTicket(pending)) return false;

   if(g_setupDir == 1 && g_lastGOMVerdictNum < 1) return false;
   if(g_setupDir == -1 && g_lastGOMVerdictNum > -1) return false;

   int pendKind = ClassifyTVSetupPendingType(g_setupDir, g_setupEntry);
   if(pendKind != 0 && g_setupEntry > 0) return false;

   double lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double entry = (g_setupDir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0) return false;
   double sl = NormalizeDouble(g_setupSL, dg);
   double tp = NormalizeDouble(g_setupTP1, dg);
   if(!FixTVSetupStopsForBroker(g_setupDir, entry, sl, tp)) return false;

   CTrade ct;
   ct.SetExpertMagicNumber(TVSetupMagicNumber);
   ct.SetDeviationInPoints(50);
   ct.SetTypeFilling(ORDER_FILLING_IOC);

   bool ok = (g_setupDir == 1)
      ? ct.Buy(lot, _Symbol, 0, sl, tp, "TM_TV_SPIKE")
      : ct.Sell(lot, _Symbol, 0, sl, tp, "TM_TV_SPIKE");

   if(!ok)
   {
      PrintOnce(StringFormat("[TV-Setup] Pre-spike %s échoué: %d",
            (g_setupDir == 1 ? "BUY" : "SELL"), (int)ct.ResultRetcode()), 20);
      return false;
   }

   g_tvSetupBreakoutDone = TimeCurrent();
   g_setupKey = BuildTVSetupKey();
   Print(StringFormat("[TV-Setup] ⚡ PRE-SPIKE %s %s @ %.2f SL=%.2f TP=%.2f | %s imm=%.0f%%",
         g_setupType, (g_setupDir == 1 ? "BUY" : "SELL"), entry, sl, tp,
         g_lastGOMVerdict, g_spikeImminence));
   return true;
}

void ManageTVSetupLimitOrder()
{
   if(!UseTVSetupLimit) return;

   bool isSpikeSetup = (StringFind(g_setupType, "SPIKE_") >= 0) || g_spikeTradable;

   if(!g_setupValid || g_setupDir == 0)
   {
      if(g_tvSetupOrderTicket > 0 || FindTVSetupPendingTicket(g_tvSetupOrderTicket))
         CancelTVSetupLimitOrder("setup TV invalide ou retiré");
      g_setupKey = "";
      PrintOnce("[TV-Setup] Pas de setup actif — vérifier poller + GOM_KOLA_SIDO sur TV", 120);
      return;
   }

   if(isSpikeSetup && TVSetupSpikeMarket)
   {
      TryTVPreSpikeMarketEntry();
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

   // 🔒 GARDE PIPELINE ONLY MODE
   if(!CanAutoEntry("TV-Breakout", _Symbol)) return;

   if(IsGOMCorrectionZone(1))
   {
      PrintOnce("[TV-Setup] Breakout BUY bloque — correction en cours", 30);
      return;
   }
   if(IsBBCounterTrend(1))
   {
      PrintOnce("[TV-Setup] Breakout BUY bloque — BB baissier", 30);
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

   // GOM=WAIT — bloquer toute duplication peu importe DuplicateRequireGoodPerfect
   if(IsGOMVerdictWait())
   {
      why = StringFormat("GOM=WAIT (vnum=%d) — duplication interdite", g_lastGOMVerdictNum);
      return false;
   }

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

      // ⏰ Grace period: skip stop-loss check for first 120 seconds after entry
      // Prevents immediate closure from spread/slippage on new positions
      long openTimeLong = PositionGetInteger(POSITION_TIME);
      long timeNowLong  = (long)TimeCurrent();
      int ageSeconds    = (int)(timeNowLong - openTimeLong);
      bool withinGrace  = (ageSeconds < 120);  // First 2 minutes

      if(!withinGrace && profit <= -maxLoss)
      {
         Print(StringFormat("[TradeManager] 🛑 %s #%llu perte $%.2f (cap -$%.2f) — fermeture",
               sym, ticket, profit, maxLoss));
         if(trade.PositionClose(ticket))
            Print(StringFormat("[ProfitGivebackExit] 💀 %s #%llu fermée perte STOP-LOSS $%.2f",
                  sym, ticket, profit));
         continue;
      }

      if(peak < ProfitGivebackArmUSD) continue;

      // Plancher = 50% du pic (MaxGivebackFromPeakUSD = 0.50 → 50%)
      // Ex : pic $2 → plancher $1 | pic $3 → plancher $1.5 | pic $5 → plancher $2.5
      double floorPeak = peak * (1.0 - MaxGivebackFromPeakUSD);
      // Jamais en négatif si on a déjà vu $1 de gain
      double floorAbs  = (peak >= 1.0) ? 0.0 : -maxLoss;
      double floorUSD  = MathMax(floorPeak, floorAbs);

      if(profit < floorUSD)
      {
         Print(StringFormat("[TradeManager] 💰 %s #%llu GIVEBACK | profit=$%.2f pic=$%.2f plancher=$%.2f (50%% du pic)",
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
      g_states[idx].lastSLHitTime    = 0;
      g_states[idx].consecutiveLosses = 0;
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
   double lot = g_states[idx].originalLot;
   int    dg  = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double ep  = g_states[idx].openPrice;
   int    dir = g_states[idx].direction;

   double newSL = 0.0, newTP = 0.0;
   ComputeAutoSLTPPrices(sym, dir, lot, ep, newSL, newTP);

   double slPts = MathAbs(ep - newSL);
   double tpPts = MathAbs(ep - newTP);

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
      // Boom/Crash : cap plus souple car gérés par spike — mais garde-fou à 2× MaxRisk
      double capLoss = IsBoomOrCrashSymbol(sym) ? maxLoss * 2.0 : maxLoss;
      if(curProfit <= -capLoss)
      {
         Print(StringFormat("[TradeManager] 🛑 %s #%llu perte $%.2f >= -$%.2f — fermeture urgente",
               sym, ticket, curProfit, capLoss));
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
      if(profitPerPt <= 0) continue;

      int    dg       = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      double pt       = SymbolInfoDouble(sym, SYMBOL_POINT);
      double peakUse  = MathMax(g_states[idx].peakProfit, ticketPeak);
      double minMove  = pt * 3;
      double newSL    = 0;
      string phase    = "";

      // ── BOOM/CRASH : trailing désactivé — fermeture uniquement sur spike ──
      // MonitorSpikeAutoClose() gère la sortie après spike détecté
      if(IsBoomOrCrashSymbol(sym))
      {
         // Garde-fou perte max uniquement — pas de trailing SL progressif
         // (le spike est la seule sortie rentable sur Boom/Crash)
         continue;
      }

      // ── MÉTAUX / FOREX : trailing actif dès $2, recul max 30% du pic ────
      // Phase 1 : pic $0→$2   → pas de trail, garde-fou perte max $3.50
      // Phase 2 : pic $2+     → actif, SL protège 70% du pic (recul max 30%)
      // Phase 3 : pic $4+     → trailing serré, recul max 20%

      // 30% du pic en distance prix
      double lockPts30   = (peakUse * TrailLockPct) / MathMax(profitPerPt, 0.0001);
      double lockSL30    = NormalizeDouble((dir == 1) ? ep + (peakUse * 0.70 / MathMax(profitPerPt, 0.0001))
                                                     : ep - (peakUse * 0.70 / MathMax(profitPerPt, 0.0001)), dg);

      if(peakUse >= 4.0 || (g_states[idx].forceTrailing && peakUse >= 2.0))
      {
         // Phase 3 — trailing serré : recul max 20% du pic depuis prix courant
         double allowedGivebackUSD = peakUse * 0.20;
         double allowedGivebackPts = allowedGivebackUSD / MathMax(profitPerPt, 0.0001);
         newSL = NormalizeDouble(
            (dir == 1) ? (bid - allowedGivebackPts) : (bid + allowedGivebackPts), dg);
         // Jamais sous le plancher 70% du pic
         if(dir == 1) newSL = MathMax(newSL, lockSL30);
         else         newSL = MathMin(newSL, lockSL30);
         phase = StringFormat("Phase3 serré | recul max $%.2f (20%%)", allowedGivebackUSD);
      }
      else if(peakUse >= TrailActivateUSD)
      {
         // Phase 2 — SL protège 70% du pic (recul max 30%)
         // Armé dès $2 : si prix recule de 30% du pic → fermeture
         newSL = lockSL30;
         phase = StringFormat("Phase2 BB | SL=$%.2f (70%% de pic $%.2f, recul max 30%%)", peakUse * 0.70, peakUse);
      }
      else
      {
         // Phase 1 — pas encore armé ($0→$2) : breakeven uniquement si déjà en gain
         double be = NormalizeDouble((dir == 1) ? ep + pt : ep - pt, dg);
         newSL = be;
         phase = StringFormat("Phase1 attente $%.2f (actuel $%.2f)", TrailActivateUSD, peakUse);
      }

      // Vérifier stops_level broker
      int stopsLvl = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
      double minDist = (double)(stopsLvl + 5) * pt;
      double ask2 = SymbolInfoDouble(sym, SYMBOL_ASK);
      // BUY : SL doit être sous BID (pas ask) — le broker valide par rapport au BID
      if(dir == 1 && (bid - newSL) < minDist)
      {
         newSL = NormalizeDouble(bid - minDist, dg);
         // Si newSL < entry → breakeven impossible, abandonner ce tick
         if(newSL <= ep) continue;
      }
      if(dir == -1 && (newSL - ask2) < minDist)
         newSL = NormalizeDouble(ask2 + minDist, dg);

      // N'appliquer que si le nouveau SL est meilleur que l'actuel
      bool better = (dir == 1) ? (newSL > curSL + minMove)
                               : (curSL == 0 || newSL < curSL - minMove);
      if(!better) continue;

      if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
      {
         Print(StringFormat("[TradeManager] 🛡️ %s %s | SL %.5f→%.5f | profit=$%.2f peak=$%.2f",
               sym, phase, curSL, newSL, curProfit, peakUse));
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

            // Détecter fermeture par SL : close_price proche du SL original
            double slRef  = g_states[i].originalSL;
            double pt     = SymbolInfoDouble(g_states[i].symbol, SYMBOL_POINT);
            bool   hitSL  = (slRef > 0 && MathAbs(closePrice - slRef) <= pt * 20);
            // Aussi : si peakProfit était <= 0 → trade n'a jamais été en profit = perte nette
            if(hitSL || g_states[i].peakProfit <= 0.10)
            {
               g_states[i].lastSLHitTime = TimeCurrent();
               g_states[i].consecutiveLosses++;
               Print(StringFormat("[TradeManager] ❌ %s PERTE (SL hit #%d) @ %.5f — cooldown re-entrée 10min",
                     g_states[i].symbol, g_states[i].consecutiveLosses, closePrice));
            }
            else
            {
               g_states[i].consecutiveLosses = 0; // reset si sorti en profit
               Print(StringFormat("[TradeManager] 🔴 %s fermé @ %.5f — attente re-entrée sur EMA%d/EMA%d",
                     g_states[i].symbol, closePrice, EMA_Fast, EMA_Slow));
            }
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

   // GOM=WAIT — bloquer toute re-entrée EMA/BB au marché
   if(UseGOMScalp && IsGOMVerdictWait())
   {
      PrintOnce(StringFormat("[TM-EMA] %s re-entrée bloquée — GOM=WAIT (vnum=%d)",
            sym, g_lastGOMVerdictNum), 60);
      return;
   }

   // 🔒 GARDE PIPELINE ONLY MODE — exception BB Mid en GOM PERFECT
   bool isGOMPerfectPre = (g_lastGOMVerdictNum == 3 || g_lastGOMVerdictNum == -3);
   bool bbDataReady     = (g_lastBBMid > 0 && g_lastBBUp > 0 && g_lastBBDn > 0);
   bool bbPerfectMatch  = bbDataReady && isGOMPerfectPre &&
                          ((g_lastGOMVerdictNum == 3 && dir == 1) || (g_lastGOMVerdictNum == -3 && dir == -1));
   if(!bbPerfectMatch)
   {
      if(!CanAutoEntry("EMA-ReEntry", sym)) return;
   }

   // 🎯 STRATÉGIE BB MID : uniquement si GOM PERFECT BUY ou PERFECT SELL
   // La BB Mid comme re-entry ne s'active qu'en condition de momentum parfait
   bool isGOMPerfect = (g_lastGOMVerdictNum == 3 || g_lastGOMVerdictNum == -3);
   bool isBBMidTouch = (g_lastBBMid > 0 && g_lastBBUp > 0 && g_lastBBDn > 0);
   bool useBBStrategy = false;
   if(isBBMidTouch && !isGOMPerfect)
   {
      // Touch BB Mid sans GOM PERFECT → bloquer si c'est la seule justification
      double distBBCheck = (dir == 1) ? MathAbs(SymbolInfoDouble(sym, SYMBOL_BID) - g_lastBBMid)
                                      : MathAbs(SymbolInfoDouble(sym, SYMBOL_ASK) - g_lastBBMid);
      double tolBBCheck  = (SymbolInfoDouble(sym, SYMBOL_ASK) - SymbolInfoDouble(sym, SYMBOL_BID)) * 3.0;
      if(distBBCheck < tolBBCheck)
      {
         PrintOnce(StringFormat("[TM-BB] %s re-entrée BB Mid bloquée — GOM=%s (exige PERFECT)",
               sym, g_lastGOMVerdict), 60);
         return;
      }
   }
   if(isBBMidTouch && isGOMPerfect)
   {
      // Valider direction GOM PERFECT vs signal
      bool perfectBuy  = (g_lastGOMVerdictNum == 3  && dir == 1);
      bool perfectSell = (g_lastGOMVerdictNum == -3 && dir == -1);
      if(!perfectBuy && !perfectSell)
      {
         PrintOnce(StringFormat("[TM-BB] %s BB Mid bloquée — GOM PERFECT %s opposé au signal %s",
               sym, g_lastGOMVerdict, (dir==1?"BUY":"SELL")), 60);
         return;
      }

      // Règle anti-correction : pente BB Mid nettement dans la direction du signal
      // Méthode : régression linéaire sur 10 barres — slope > seuil = trending
      // Seuil = 0.003% du prix par barre (élimine range et corrections faibles)
      int hBBSlope = iBands(sym, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
      bool bbAligned = false;
      if(hBBSlope != INVALID_HANDLE)
      {
         double bbMidSlope[];
         ArraySetAsSeries(bbMidSlope, true);
         int nSlope = 10;
         if(CopyBuffer(hBBSlope, 0, 0, nSlope, bbMidSlope) >= nSlope)
         {
            // Régression linéaire simple : slope = (sum(x*y) - n*mx*my) / (sum(x²) - n*mx²)
            // x = 0..n-1 (le plus récent = index 0, donc x croît vers le passé)
            // Pour que slope positif = montée récente, on inverse : x[i] = (n-1-i)
            double sumX=0, sumY=0, sumXX=0, sumXY=0;
            for(int ki=0; ki<nSlope; ki++)
            {
               double xi = (double)(nSlope - 1 - ki);  // 0=passé, n-1=récent
               double yi = bbMidSlope[ki];
               sumX  += xi;
               sumY  += yi;
               sumXX += xi * xi;
               sumXY += xi * yi;
            }
            double denom = (double)nSlope * sumXX - sumX * sumX;
            double slopePerBar = (denom != 0) ? ((double)nSlope * sumXY - sumX * sumY) / denom : 0;
            // Seuil : 0.003% du prix courant par barre
            double refPxSlope  = (dir == 1) ? SymbolInfoDouble(sym, SYMBOL_BID)
                                            : SymbolInfoDouble(sym, SYMBOL_ASK);
            double slopeMin    = refPxSlope * 0.00003;  // 0.003% / barre
            if(dir == 1)  bbAligned = (slopePerBar >  slopeMin);
            else          bbAligned = (slopePerBar < -slopeMin);
            PrintOnce(StringFormat("[TM-BB] %s pente BB Mid = %.6f/barre (seuil=%.6f) → %s",
                  sym, slopePerBar, slopeMin, bbAligned ? "TREND OK" : "RANGE/CONTRE-TENDANCE"), 30);
         }
         IndicatorRelease(hBBSlope);
      }

      // Si BB opposé, vérifier si le prix est dans l'OB haussier/baissier (pullback valide)
      bool inOBZone = false;
      if(!bbAligned)
      {
         double refPxOB = (dir == 1) ? SymbolInfoDouble(sym, SYMBOL_BID)
                                     : SymbolInfoDouble(sym, SYMBOL_ASK);
         if(dir == 1 && g_obBullTop > 0 && g_obBullBot > 0)
            inOBZone = (refPxOB >= g_obBullBot && refPxOB <= g_obBullTop);
         if(dir == -1 && g_obBearTop > 0 && g_obBearBot > 0)
            inOBZone = (refPxOB >= g_obBearBot && refPxOB <= g_obBearTop);
      }

      if(!bbAligned && !inOBZone)
      {
         PrintOnce(StringFormat("[TM-BB] %s entrée BLOQUÉE — BB %s (correction) et prix hors OB %s — attendre BB haussier ou pullback OB",
               sym, (dir==1?"baissier":"haussier"), (dir==1?"haussier":"baissier")), 60);
         return;
      }
      useBBStrategy = true;
   }

   // Limite par symbole toujours vérifiée — limite globale exemptée pour re-entrée tendance
   if(IsGlobalPositionLimitReachedForReEntry(sym)) return;
   if(CountManagedPositions(sym) >= MaxPositionsPerSymbol)
   {
      PrintOnce(StringFormat("[TM-EMA] %s: max %d positions atteint — re-entrée EMA bloquée",
            sym, MaxPositionsPerSymbol), 60);
      return;
   }

   // Cooldown minimal entre re-entrées
   if(g_states[idx].lastReEntry > 0 &&
      (int)(TimeCurrent() - g_states[idx].lastReEntry) < ReEntryCooldownSec)
      return;

   // Cooldown post-SL : 10 min après une perte, 20 min après 2 pertes consécutives
   if(g_states[idx].lastSLHitTime > 0)
   {
      int losses    = g_states[idx].consecutiveLosses;
      int cooldownSec = (losses >= 2) ? 1200 : 600; // 20min si 2+ pertes, 10min sinon
      int elapsed   = (int)(TimeCurrent() - g_states[idx].lastSLHitTime);
      if(elapsed < cooldownSec)
      {
         PrintOnce(StringFormat("[TM-EMA] %s re-entrée bloquée — %d perte(s) consécutive(s), attendre %ds (reste %ds)",
               sym, losses, cooldownSec, cooldownSec - elapsed), 60);
         return;
      }
   }

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

   // Choisir le niveau de rebond le plus proche : EMA fast, EMA slow, ou BB Mid (SMA20)
   double distFast  = hasFast          ? MathAbs(refPx - emaFast)       : 1e10;
   double distSlow  = hasSlow          ? MathAbs(refPx - emaSlow)        : 1e10;
   double distBBMid = (g_lastBBMid > 0) ? MathAbs(refPx - g_lastBBMid) : 1e10;
   double targetEMA;
   int    emaUsed;
   if(distBBMid <= distFast && distBBMid <= distSlow)
   {
      targetEMA = g_lastBBMid;
      emaUsed   = 20;  // SMA20 = BB Mid
   }
   else if(distFast <= distSlow) { targetEMA = emaFast; emaUsed = EMA_Fast; }
   else                          { targetEMA = emaSlow; emaUsed = EMA_Slow; }

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

   // Vérifier le toucher EMA/BB Mid
   double tolerance = spread * MathMax(EMATouch_Pct, 0.3);
   string levelName = (emaUsed == 20) ? "BB Mid" : StringFormat("EMA%d", emaUsed);
   if(MathAbs(refPx - targetEMA) > tolerance)
   {
      PrintOnce(StringFormat("[TradeManager] %s attente %s=%.5f | ref=%.5f dist=%.5f tol=%.5f",
            sym, levelName, targetEMA, refPx, MathAbs(refPx - targetEMA), tolerance), 60);
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

   double entryPx = (dir == 1) ? ask : bid;
   double newSL, newTP;
   double tpDist = slDist * 2.0;  // valeur par défaut, écrasée selon stratégie

   if(useBBStrategy && g_lastBBUp > 0 && g_lastBBDn > 0)
   {
      // Stratégie BB PERFECT : SL = BB Inf (BUY) / BB Sup (SELL), TP = BB Sup (BUY) / BB Inf (SELL)
      if(dir == 1)
      {
         newSL = NormalizeDouble(g_lastBBDn, dg);  // BB Inf comme SL
         newTP = NormalizeDouble(g_lastBBUp, dg);  // BB Sup comme TP
      }
      else
      {
         newSL = NormalizeDouble(g_lastBBUp, dg);  // BB Sup comme SL
         newTP = NormalizeDouble(g_lastBBDn, dg);  // BB Inf comme TP
      }
      // Vérifier validité minimale broker
      if(MathAbs(entryPx - newSL) < minBroker)
         newSL = NormalizeDouble((dir==1) ? entryPx - minBroker : entryPx + minBroker, dg);
      if(MathAbs(newTP - entryPx) < minBroker)
         newTP = NormalizeDouble((dir==1) ? entryPx + minBroker*2 : entryPx - minBroker*2, dg);
      Print(StringFormat("[TM-BB] %s %s BB Strategy — Entry=%.5f SL=%.5f(BBInf/Sup) TP=%.5f(BBSup/Inf)",
            sym, (dir==1?"BUY":"SELL"), entryPx, newSL, newTP));
   }
   else
   {
      tpDist = (tickSz > 0 && tickVal > 0 && lot > 0)
               ? TargetProfitUSD * tickSz / (lot * tickVal)
               : slDist * 2.0;
      tpDist = MathMax(tpDist, minBroker);
      newSL = NormalizeDouble((dir == 1) ? entryPx - slDist : entryPx + slDist, dg);
      newTP = NormalizeDouble((dir == 1) ? entryPx + tpDist : entryPx - tpDist, dg);
   }

   bool ok = (dir == 1) ? trade.Buy(lot, sym, 0, newSL, newTP, useBBStrategy ? "TM_BB_RE" : "TM_EMA_RE")
                        : trade.Sell(lot, sym, 0, newSL, newTP, useBBStrategy ? "TM_BB_RE" : "TM_EMA_RE");
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
//| Daily Profit Target — bloque toute entrée dès 5% gagné/jour     |
//+------------------------------------------------------------------+

// Retourne le profit net des deals clôturés aujourd'hui (depuis minuit heure broker)
double CalcDailyClosedProfit()
{
   double pnl = 0.0;
   datetime dayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE)); // minuit local broker
   HistorySelect(dayStart, TimeCurrent());
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_BALANCE) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT)
           + HistoryDealGetDouble(ticket, DEAL_SWAP)
           + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
   }
   return pnl;
}

// Profit flottant toutes positions ouvertes (tous magic)
double CalcFloatingProfit()
{
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      pnl += posInfo.Profit() + posInfo.Swap();
   }
   return pnl;
}

//+------------------------------------------------------------------+
//| DERIV ENGINE — Boom / Crash / Volatility                        |
//| Moteur spike ICT/SMC intégré depuis DerivEAPro v9               |
//+------------------------------------------------------------------+

// État persistant Deriv
int      g_drvBarsSinceSpike   = 0;
datetime g_drvLastSpikeBar     = 0;
datetime g_drvLastProcessedBar = 0;
double   g_drvSpikeExtLow      = 0;
double   g_drvSpikeExtHigh     = 0;
bool     g_drvTradeTaken       = false;
datetime g_drvLastTradeBar     = 0;
datetime g_drvOpenTime         = 0;
ulong    g_drvTicket           = 0;
bool     g_drvBETriggered      = false;
string   g_drvLastReason       = "—";
// ICT last result
int      g_drvICTScore         = 0;
string   g_drvICTGrade         = "C";

// Handles indicateurs Deriv (créés OnInit si symbole synthétique)
int g_drvHATR = INVALID_HANDLE;
int g_drvHRSI = INVALID_HANDLE;

// ── Helpers symbole ──────────────────────────────────────────────
bool DRV_IsBoom()  { return StringFind(_Symbol,"Boom")>=0||StringFind(_Symbol,"boom")>=0; }
bool DRV_IsCrash() { return StringFind(_Symbol,"Crash")>=0||StringFind(_Symbol,"crash")>=0; }
bool DRV_IsVolatility() { return StringFind(_Symbol,"Volatility")>=0||StringFind(_Symbol,"volatility")>=0||StringFind(_Symbol,"Vol ")>=0; }

int DRV_GetCycle()
{
   if(StringFind(_Symbol,"300")>=0)  return 5;
   if(StringFind(_Symbol,"500")>=0)  return 8;
   if(StringFind(_Symbol,"600")>=0)  return 10;
   if(StringFind(_Symbol,"900")>=0)  return 13;
   if(StringFind(_Symbol,"1000")>=0) return 16;
   return DRV_BarsMin;
}
double DRV_BodyMult() { return (DRV_AutoPresets && StringFind(_Symbol,"1000")>=0) ? 0.60 : DRV_SpikeBodyMult; }
double DRV_WickMult() { return (DRV_AutoPresets && StringFind(_Symbol,"1000")>=0) ? 0.70 : DRV_SpikeWickMult; }
double DRV_SL()       { return (DRV_AutoPresets && StringFind(_Symbol,"1000")>=0) ? 2.0  : DRV_SL_ATR; }
double DRV_TP()       { return (DRV_AutoPresets && StringFind(_Symbol,"1000")>=0) ? 3.5  : DRV_TP_ATR; }

double DRV_GetATR(int shift=1)
{
   if(g_drvHATR==INVALID_HANDLE) return 0;
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(g_drvHATR,0,shift,1,b)<1) return 0;
   return b[0];
}
double DRV_GetRSI(int shift=1)
{
   if(g_drvHRSI==INVALID_HANDLE) return 50;
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(g_drvHRSI,0,shift,1,b)<1) return 50;
   return b[0];
}

// ── Détection spike ──────────────────────────────────────────────
bool DRV_IsSpike(const MqlRates &c, double atr, bool forBoom)
{
   double body=MathAbs(c.close-c.open);
   double wickUp=c.high-MathMax(c.open,c.close);
   double wickDn=MathMin(c.open,c.close)-c.low;
   if(forBoom)
      return ((body>=atr*DRV_BodyMult()||wickUp>=atr*DRV_WickMult())&&c.close>c.open);
   else
      return ((body>=atr*DRV_BodyMult()||wickDn>=atr*DRV_WickMult())&&c.close<c.open);
}

void DRV_UpdateCycle()
{
   // 🔒 GARDE PIPELINE ONLY MODE
   if(!CanAutoEntry("Deriv-Engine", _Symbol)) return;

   double atr=DRV_GetATR(1); if(atr<=0) return;
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,PERIOD_M1,1,1,r)<1) return;
   bool forBoom = DRV_IsBoom();
   // Volatility : spike dans les deux sens
   bool spike = DRV_IsVolatility()
      ? DRV_IsSpike(r[0],atr,true)||DRV_IsSpike(r[0],atr,false)
      : DRV_IsSpike(r[0],atr,forBoom);
   if(spike)
   {
      g_drvLastSpikeBar   = r[0].time;
      g_drvSpikeExtLow    = r[0].low;
      g_drvSpikeExtHigh   = r[0].high;
      g_drvBarsSinceSpike = 0;
      g_drvTradeTaken     = false;
   }
   else
   {
      g_drvBarsSinceSpike++;
      int cyMax = DRV_GetCycle()*3;
      if(g_drvBarsSinceSpike > cyMax) g_drvBarsSinceSpike = DRV_GetCycle();
   }
}

// ── Score ICT simplifié ──────────────────────────────────────────
int DRV_CalcICT(bool forBuy)
{
   int score=0;
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n=DRV_ICTLookback+4;
   if(CopyRates(_Symbol,PERIOD_M1,0,n,r)<n) return 0;
   double atr=DRV_GetATR(1); if(atr<=0) return 0;
   double cur=r[1].close;

   // BOS
   if(DRV_UseBOS)
   {
      double hh=r[2].high, ll=r[2].low;
      for(int i=3;i<n-1;i++) { hh=MathMax(hh,r[i].high); ll=MathMin(ll,r[i].low); }
      if(forBuy && r[1].close>hh) score+=20;
      if(!forBuy && r[1].close<ll) score+=20;
   }
   // CHoCH
   if(DRV_UseCHOCH && n>=8)
   {
      if(forBuy) {
         bool down=(r[5].low>r[4].low)&&(r[4].low>r[3].low);
         double rHi=MathMax(MathMax(r[2].high,r[3].high),r[4].high);
         if(down&&r[1].close>rHi) score+=20;
      } else {
         bool up=(r[5].high<r[4].high)&&(r[4].high<r[3].high);
         double rLo=MathMin(MathMin(r[2].low,r[3].low),r[4].low);
         if(up&&r[1].close<rLo) score+=20;
      }
   }
   // Order Block
   if(DRV_UseOB)
   {
      for(int i=3;i<MathMin(11,n);i++)
      {
         if(forBuy && r[i].close<r[i].open)
         {
            double imp=0; for(int j=i-1;j>=2;j--) imp+=(r[j].close-r[j].open);
            if(imp>=atr*1.2 && cur>=r[i].close-atr*0.1 && cur<=r[i].open+atr*0.2) { score+=15; break; }
         }
         if(!forBuy && r[i].close>r[i].open)
         {
            double imp=0; for(int j=i-1;j>=2;j--) imp+=(r[j].open-r[j].close);
            if(imp>=atr*1.2 && cur<=r[i].close+atr*0.1 && cur>=r[i].open-atr*0.2) { score+=15; break; }
         }
      }
   }
   // FVG
   if(DRV_UseFVG && n>=6)
   {
      for(int i=1;i<=3&&i+2<n;i++)
      {
         if(forBuy && r[i].low>r[i+2].high && cur>=r[i+2].high && cur<=r[i].low) { score+=15; break; }
         if(!forBuy && r[i].high<r[i+2].low && cur<=r[i+2].low && cur>=r[i].high) { score+=15; break; }
      }
   }
   // OTE (Fib 62-79%)
   if(DRV_UseOTE)
   {
      double hi=r[1].high,lo=r[1].low;
      for(int i=2;i<n;i++){hi=MathMax(hi,r[i].high);lo=MathMin(lo,r[i].low);}
      double rng=hi-lo; if(rng>0)
      {
         if(forBuy) { double f62=hi-rng*0.62,f79=hi-rng*0.79; if(cur>=f79&&cur<=f62) score+=10; }
         else       { double f62=lo+rng*0.62,f79=lo+rng*0.79; if(cur>=f62&&cur<=f79) score+=10; }
      }
   }
   return MathMin(score, 100);
}

// ── Logique d'entrée ──────────────────────────────────────────────
bool DRV_EvaluateEntry(bool &isBuy, string &reason)
{
   isBuy  = DRV_IsBoom();
   reason = "";
   if(g_drvTradeTaken) { reason="1 trade/cycle déjà pris"; return false; }

   // GOM=WAIT → bloquer tout ordre marché (Boom/Crash inclus)
   if(UseGOMScalp && IsGOMVerdictWait())
   { reason=StringFormat("GOM=WAIT (vnum=%d) — aucun trade marché", g_lastGOMVerdictNum); return false; }

   double atr = DRV_GetATR(1); if(atr<=0) { reason="ATR invalide"; return false; }
   int cycle  = DRV_GetCycle();
   double pct = (cycle>0) ? MathMin((double)g_drvBarsSinceSpike/cycle, 1.2) : 0.5;

   // Volatility : direction par biais GOM
   if(DRV_IsVolatility())
   {
      if(g_lastGOMVerdictNum >= 2)      isBuy = true;
      else if(g_lastGOMVerdictNum <= -2) isBuy = false;
      else { reason=StringFormat("Volatility — GOM WAIT (vnum=%d)",g_lastGOMVerdictNum); return false; }
   }

   // Filtre BB — ne pas entrer si Bollinger contre-tendance (sauf Boom/Crash pur)
   if(!DRV_IsBoom() && !DRV_IsCrash() && IsBBCounterTrend(isBuy ? 1 : -1))
   { reason="BB contre-tendance — attendre pullback OB ou BB haussier"; return false; }

   // Filtre RSI
   double rsi=DRV_GetRSI(1);
   if(isBuy  && rsi>72) { reason=StringFormat("RSI=%.0f suracheté",rsi); return false; }
   if(!isBuy && rsi<28) { reason=StringFormat("RSI=%.0f survendu",rsi);  return false; }

   int ict = DRV_CalcICT(isBuy);
   g_drvICTScore = ict;
   g_drvICTGrade = ict>=85?"A+":ict>=70?"A":ict>=50?"B":"C";

   if(DRV_MinICTScore>0 && ict<DRV_MinICTScore)
   { reason=StringFormat("ICT=%d<%d",ict,DRV_MinICTScore); return false; }

   // Mode 1 : ANTICIPATION (fenêtre 60-85%)
   if(pct>=DRV_WindowStart && pct<DRV_WindowEnd)
   {
      reason=StringFormat("ANTICIPATION %.0f%% | ICT=%d(%s) | RSI=%.0f",pct*100,ict,g_drvICTGrade,rsi);
      return true;
   }
   // Mode 2 : PULLBACK post-spike
   if(g_drvLastSpikeBar>0 && g_drvBarsSinceSpike>=1 && g_drvBarsSinceSpike<=DRV_PullbackBars)
   {
      double refPx   = isBuy ? g_drvSpikeExtLow : g_drvSpikeExtHigh;
      double curPx   = isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double dist    = isBuy ? curPx-refPx : refPx-curPx;
      if(dist>=-atr*0.3 && dist<=atr*2.5 && (DRV_MinICTScore==0||ict>=DRV_MinICTScore))
      {
         reason=StringFormat("PULLBACK %d bars | ICT=%d(%s) | RSI=%.0f",g_drvBarsSinceSpike,ict,g_drvICTGrade,rsi);
         return true;
      }
   }
   reason=StringFormat("Attente %.0f%% cycle (%.0f-%.0f%% requis) | ICT=%d",pct*100,DRV_WindowStart*100,DRV_WindowEnd*100,ict);
   return false;
}

// ── Ouverture ordre Deriv ────────────────────────────────────────
void DRV_OpenTrade(bool isBuy)
{
   if(IsDailyTargetLocked()) return;
   if(IsGlobalPositionLimitReached()) return;
   double atr   = DRV_GetATR(1); if(atr<=0) return;
   double price  = isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(price<=0) return;
   double pt    = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   int    sl_lv = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minD  = MathMax((double)(sl_lv+100)*pt, atr*0.3);
   double slD   = MathMax(atr*DRV_SL(), minD);
   double tpD   = MathMax(atr*DRV_TP(), minD*1.5);
   int    dg    = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double sl    = isBuy ? NormalizeDouble(price-slD,dg) : NormalizeDouble(price+slD,dg);
   double tp    = isBuy ? NormalizeDouble(price+tpD,dg) : NormalizeDouble(price-tpD,dg);
   // 🔧 LOT MINIMUM BROKER UNIQUEMENT (pas de calcul risque pour éviter survolume)
   double lot   = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   // Désactivé: calcul automatique via CM_LotRiskPct
   // On utilise TOUJOURS le lot minimum du broker pour ce symbole

   CTrade drvTrade;
   drvTrade.SetExpertMagicNumber(MCPMagicNumber);
   drvTrade.SetDeviationInPoints(50);
   drvTrade.SetTypeFilling(ORDER_FILLING_IOC);
   string dirStr = isBuy ? "BUY" : "SELL";
   string cmt = StringFormat("TM_DRV|%s|ICT%d", dirStr, g_drvICTScore);
   bool ok = isBuy ? drvTrade.Buy(lot,_Symbol,0,sl,tp,cmt)
                   : drvTrade.Sell(lot,_Symbol,0,sl,tp,cmt);
   if(ok)
   {
      g_drvTicket       = drvTrade.ResultOrder();
      g_drvTradeTaken   = true;
      g_drvOpenTime     = TimeCurrent();
      g_drvBETriggered  = false;
      g_drvLastTradeBar = iTime(_Symbol,PERIOD_M1,0);
      Print(StringFormat("[DRV] %s | lot=%.2f | SL=%.5f TP=%.5f | ICT=%d(%s) | %s",
            isBuy?"BUY":"SELL", lot, sl, tp, g_drvICTScore, g_drvICTGrade, g_drvLastReason));
      SendWAEvent(isBuy?"GOM_AUTO_ENTRY":"GOM_AUTO_ENTRY", _Symbol, price, 0,
                  isBuy?"BUY":"SELL", price, sl, tp, lot);
   }
}

// ── Gestion position Deriv ───────────────────────────────────────
void DRV_ManagePosition()
{
   if(g_drvTicket==0) return;
   if(!PositionSelectByTicket(g_drvTicket)) { g_drvTicket=0; return; }

   double profit = PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   double openPx = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL  = PositionGetDouble(POSITION_SL);
   double curTP  = PositionGetDouble(POSITION_TP);
   long   ptype  = PositionGetInteger(POSITION_TYPE);
   double bid    = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask    = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double atr    = DRV_GetATR(1); if(atr<=0) return;
   double pt     = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   int    sl_lv  = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minD   = MathMax((double)(sl_lv+100)*pt, atr*0.3);
   int    dg     = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   CTrade drvT; drvT.SetDeviationInPoints(50);

   // Time stop
   if(DRV_TimeStopMin>0 && (int)(TimeCurrent()-g_drvOpenTime)>=DRV_TimeStopMin*60)
   { drvT.PositionClose(g_drvTicket,20); g_drvTicket=0; return; }

   // Quick exit sur spike suivant
   if(DRV_UseQuickExit && g_drvBarsSinceSpike==0 && profit>=atr*DRV_QuickExitMinPct)
   { drvT.PositionClose(g_drvTicket,20); g_drvTicket=0; return; }

   // Smart Breakeven
   if(DRV_UseSmartBE && !g_drvBETriggered)
   {
      double spread=ask-bid;
      if(ptype==POSITION_TYPE_BUY && bid-openPx>=atr*DRV_BETrigger)
      {
         double nsl=NormalizeDouble(openPx+spread*1.5,dg);
         if(bid-nsl>=minD && nsl>curSL) { drvT.PositionModify(g_drvTicket,nsl,curTP); g_drvBETriggered=true; }
      }
      else if(ptype==POSITION_TYPE_SELL && openPx-ask>=atr*DRV_BETrigger)
      {
         double nsl=NormalizeDouble(openPx-spread*1.5,dg);
         if(nsl-ask>=minD && (curSL==0||nsl<curSL)) { drvT.PositionModify(g_drvTicket,nsl,curTP); g_drvBETriggered=true; }
      }
   }
   // Trailing
   if(DRV_UseTrail)
   {
      double trD=MathMax(atr*DRV_TrailATR,minD);
      if(ptype==POSITION_TYPE_BUY && bid-openPx>=atr*DRV_TrailActivation)
      {
         double nsl=NormalizeDouble(bid-trD,dg);
         if(nsl>curSL&&bid-nsl>=minD) drvT.PositionModify(g_drvTicket,nsl,curTP);
      }
      else if(ptype==POSITION_TYPE_SELL && openPx-ask>=atr*DRV_TrailActivation)
      {
         double nsl=NormalizeDouble(ask+trD,dg);
         if((curSL==0||nsl<curSL)&&nsl-ask>=minD) drvT.PositionModify(g_drvTicket,nsl,curTP);
      }
   }
}

// ── Fermeture automatique après spike capté (Boom/Crash) ─────────
// Ferme toute position en gain dès qu'un spike est détecté sur la barre courante
// Applicable aux positions MCP pipeline ET moteur Deriv
void MonitorSpikeAutoClose()
{
   if(!spike_bc_en_local || !IsBoomOrCrashSymbol(_Symbol)) return;

   double atr = DRV_GetATR(1);
   if(atr <= 0) return;

   // Détecter spike en cours (même logique que DRV)
   double body = MathAbs(iClose(_Symbol,PERIOD_M1,0) - iOpen(_Symbol,PERIOD_M1,0));
   bool   isBoom  = StringFind(_Symbol,"Boom") >= 0 || StringFind(_Symbol,"BOOM") >= 0;
   bool   isCrash = StringFind(_Symbol,"Crash") >= 0 || StringFind(_Symbol,"CRASH") >= 0;
   bool   spikeUp   = isBoom  && body >= atr * 0.32 && iClose(_Symbol,PERIOD_M1,0) > iOpen(_Symbol,PERIOD_M1,0);
   bool   spikeDown = isCrash && body >= atr * 0.32 && iClose(_Symbol,PERIOD_M1,0) < iOpen(_Symbol,PERIOD_M1,0);
   bool   spikeNow  = barstate_isconfirmed_local ? (spikeUp || spikeDown) : false;

   if(!spikeNow) return;

   CTrade spkTrade;
   spkTrade.SetDeviationInPoints(50);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol) continue;
      // Seulement les positions en gain
      double profit = posInfo.Profit() + posInfo.Swap();
      if(profit <= 0) continue;
      // Direction alignée avec le spike
      bool isBuyPos  = posInfo.PositionType() == POSITION_TYPE_BUY;
      bool isSellPos = posInfo.PositionType() == POSITION_TYPE_SELL;
      if(isBoom  && !isBuyPos)  continue;  // Boom → seulement BUY en gain
      if(isCrash && !isSellPos) continue;  // Crash → seulement SELL en gain

      spkTrade.PositionClose(posInfo.Ticket(), 50);
      Print(StringFormat("[SpikeClose] ✅ Fermé %s ticket=%llu profit=$%.2f | spike détecté body=%.5f atr=%.5f",
            posInfo.Symbol(), posInfo.Ticket(), profit, body, atr));
      SendWAEvent("SPIKE_CLOSE", _Symbol, posInfo.PriceCurrent(), profit,
                  isBuyPos?"BUY":"SELL", posInfo.PriceOpen(), 0, 0, posInfo.Volume());
   }
}

// Flags locaux pour éviter la re-déclaration (already declared in global scope)
bool spike_bc_en_local    = true;   // Activer fermeture spike auto
bool barstate_isconfirmed_local = false;  // Mis à jour dans OnTick

// ── Point d'entrée principal Deriv ───────────────────────────────
void RunDerivEngine()
{
   if(!UseDerivEngine) return;
   if(!IsBoomOrCrashSymbol(_Symbol) && !DRV_IsVolatility()) return;

   // Nouvelle barre
   datetime curBar = iTime(_Symbol,PERIOD_M1,0);
   bool newBar     = (curBar != g_drvLastProcessedBar);
   if(newBar) { g_drvLastProcessedBar=curBar; DRV_UpdateCycle(); }

   // Gestion position existante
   if(g_drvTicket>0) { DRV_ManagePosition(); return; }
   // Vérifier aussi si position ouverte par ce magic sur ce symbole
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==(long)MCPMagicNumber &&
         PositionGetString(POSITION_SYMBOL)==_Symbol)
      { g_drvTicket=t; DRV_ManagePosition(); return; }
   }

   if(!newBar) return;            // Entrées uniquement sur nouvelle barre
   if(g_drvTradeTaken) return;
   if(IsDailyTargetLocked()) return;

   bool   isBuy;
   string reason;
   if(!DRV_EvaluateEntry(isBuy, reason)) { g_drvLastReason=reason; return; }
   g_drvLastReason=reason;
   DRV_OpenTrade(isBuy);
}

void CheckDailyProfitTarget()
{
   if(!UseCapitalManager) return;

   // Reset quotidien à minuit
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_dailyResetDate)
   {
      g_dailyResetDate    = today;
      g_dailyTargetHit    = false;
      g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_dailyTradeCount   = 0;  // 🆕 Reset compteur de trades
      PrintOnce(StringFormat("[DISCIPLINE] Nouveau jour — balance=$%.2f | Objectif: +%.0f%% ($%.2f) | Max %d trades | Cible: +$%.0f",
            g_dailyStartBalance, CM_DailyTargetPct,
            g_dailyStartBalance * CM_DailyTargetPct / 100.0, g_maxDailyTrades, g_dailyProfitTarget), 3600);
   }

   if(g_dailyTargetHit) return;

   double capital     = (g_dailyStartBalance > 0) ? g_dailyStartBalance : AccountInfoDouble(ACCOUNT_BALANCE);
   double targetUSD   = capital * CM_DailyTargetPct / 100.0;
   double closedPnl   = CalcDailyClosedProfit();
   double floatPnl    = CalcFloatingProfit();
   double totalDayPnl = closedPnl + floatPnl;

   // Déjà en dessous de la cible — pas d'action
   if(totalDayPnl < targetUSD) return;

   // Objectif atteint → fermer toutes les positions et bloquer
   g_dailyTargetHit = true;
   Print(StringFormat("[CM] 🎯 OBJECTIF JOURNALIER ATTEINT +%.1f%% ($%.2f / cible $%.2f) — arrêt trading",
         totalDayPnl / capital * 100.0, totalDayPnl, targetUSD));
   SendNotification(StringFormat("🎯 TradBOT: +%.1f%% atteint ($%.2f) — arrêt du jour",
         totalDayPnl / capital * 100.0, totalDayPnl));
   SendWAEvent("DAILY_TARGET", _Symbol, 0, totalDayPnl, "",
               0, 0, 0, 0,
               StringFormat("+%.1f%% (%.2f$) objectif %.0f%% atteint",
                     totalDayPnl / capital * 100.0, totalDayPnl, CM_DailyTargetPct));

   // Fermer toutes les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      trade.PositionClose(posInfo.Ticket());
   }

   // Annuler tous les ordres limites/stops en attente
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0) trade.OrderDelete(ticket);
   }
}

// Retourne true si le robot doit refuser toute nouvelle entrée (objectif jour déjà atteint)
bool IsDailyTargetLocked()
{
   if(!UseCapitalManager) return false;
   // Re-vérifier le reset si minuit passé
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_dailyResetDate) return false;
   return g_dailyTargetHit;
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

      // Signal exécuté : bloquer re-poll seulement 2 min (anti double-exécution)
      // Après 2 min → libérer pour permettre un nouveau signal pipeline
      if(g_mcpSignals[k].executed && signalAge > 120)
      {
         g_mcpSignals[k].active = false;
         if(StringCompare(sym, "XAUUSD") == 0)
            Print(StringFormat("[TradeManager] ⚠️ %s: Signal exécuté expiré (%ds) → libéré pour nouveau signal", sym, signalAge));
         continue;
      }

      // Signal ACTIF (pas exécuté) mais vieux (>5 min) → expiration
      if(g_mcpSignals[k].active && !g_mcpSignals[k].executed && signalAge > 300)
      {
         Print(StringFormat("[TradeManager] 🔄 %s: Signal READY expiré après %d sec → REMPLACEMENT", sym, signalAge));
         g_mcpSignals[k].active = false;
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
   // 🔧 FORCER LOT MINIMUM BROKER (ignorer lot serveur pour éviter survolume)
   double lot   = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

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

   // 🚫 RÈGLE CRITIQUE: SELL interdit sur Boom, BUY interdit sur Crash
   if(StringFind(sym, "Boom") >= 0 && action == "SELL")
   {
      Print(StringFormat("[TradeManager] 🚫 %s: SELL INTERDIT sur Boom — signal REJETÉ", sym));
      SendNotification(StringFormat("🚫 TradBOT: SELL bloqué sur %s (Boom=BUY only)", sym));
      return;
   }
   if(StringFind(sym, "Crash") >= 0 && action == "BUY")
   {
      Print(StringFormat("[TradeManager] 🚫 %s: BUY INTERDIT sur Crash — signal REJETÉ", sym));
      SendNotification(StringFormat("🚫 TradBOT: BUY bloqué sur %s (Crash=SELL only)", sym));
      return;
   }

   // Sanity check : entry_price doit être dans ±20% du prix courant
   // Protège contre les ordres corrompus ou les vieux caches MQL5
   if(entry > 0)
   {
      double curPx = (action=="BUY") ? SymbolInfoDouble(sym,SYMBOL_ASK) : SymbolInfoDouble(sym,SYMBOL_BID);
      if(curPx > 0 && (MathAbs(entry - curPx) / curPx) > 0.20)
      {
         Print(StringFormat("[TradeManager] ⚠️ %s: entry=%.5f aberrant (prix=%.5f écart=%.1f%%) — REJETÉ",
               sym, entry, curPx, MathAbs(entry-curPx)/curPx*100));
         return;
      }
   }

   Print(StringFormat("[TradeManager] ✅ %s: Found %s order (entry=%.2f SL=%.2f TP=%.2f lot=%.2f)",
         sym, action, entry, sl, tp, lot));

   // Auto-calculer SL/TP si absents — utiliser niveaux GOM (KOLA/setup) ou ATR
   if(sl <= 0 || tp <= 0)
   {
      int    dir2  = (action == "BUY") ? 1 : -1;
      double ref   = (entry > 0) ? entry : ((dir2==1) ? SymbolInfoDouble(sym,SYMBOL_ASK) : SymbolInfoDouble(sym,SYMBOL_BID));
      double slC = sl, tpC = tp;
      ComputeAutoSLTPPrices(sym, dir2, lot, ref, slC, tpC);
      if(sl <= 0 && slC > 0) sl = slC;
      if(tp <= 0 && tpC > 0) tp = tpC;
      if(isXau) Print(StringFormat("[TradeManager] 🔧 %s: SL/TP auto-calculés SL=%.5f TP=%.5f", sym, sl, tp));
   }

   // ⭐ PRIORITÉ GOM: GOOD/PERFECT ou signal score fort (sell>>buy)
   // Pipeline bypass : skip tous les filtres GOM pour source=pipeline
   string orderSource = JsonGetString(orderBody, "source");
   bool isPipelineOrder = (StringCompare(orderSource, "pipeline") == 0);
   if(isPipelineOrder)
   {
      Print(StringFormat("[TradeManager] ✅ %s: source=pipeline — GOM filters BYPASSED", sym));
      // Nouveau rapport TradingAgents reçu → redessiner BB courbes immédiatement
      DrawBollingerCurves(true);
   }

   // Pour Boom/Crash : GOM du chart courant non pertinent → skip tous les filtres GOM
   bool isBoomCrashForGOM = IsBoomOrCrashSymbol(sym);
   // Pour les ordres gom_tv_sync : utiliser le verdict inclus dans le JSON serveur
   // (évite conflit avec g_lastGOMVerdict local stale quand poller est arrêté)
   string serverVerdict = JsonGetString(orderBody, "gom_verdict");
   StringToUpper(serverVerdict);
   bool serverVerdictAligned = false;
   if(StringLen(serverVerdict) > 0)
   {
      bool srvBuy  = (StringFind(serverVerdict, "BUY")  >= 0);
      bool srvSell = (StringFind(serverVerdict, "SELL") >= 0);
      serverVerdictAligned = (action == "BUY" && srvBuy) || (action == "SELL" && srvSell);
   }

   if(!isPipelineOrder && UseGOMScalp && (TimeCurrent() - g_lastGOMPoll) < GOMSignalMaxAgeSec && !isBoomCrashForGOM
      && !serverVerdictAligned)  // Si verdict serveur aligné → skip check GOM local stale
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
         Print(StringFormat("[TradeManager] 🚫 %s: CONFLIT GOM local %s vs signal=%s — REJETÉ (server=%s)",
               sym, actTag, action, serverVerdict));
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
      // NOTE: ce guard ne s'applique qu'aux ordres GOM auto — pas aux ordres pipeline
      // (les ordres pipeline ont isPipelineOrder=true → tout ce bloc est déjà skippé)
      if(GOMWaitPullbackToKola)
      {
         if(mcpDir == -1 && StringCompare(g_lastKOLAState, "NEAR SELL") != 0)
         {
            if(isXau) Print(StringFormat("[TradeManager] ⏳ %s: attente pullback OM (KOLA=%s) avant SELL",
                  sym, g_lastKOLAState));
            // Ne pas détruire l'ordre — re-évaluer au prochain poll (60s)
            return;
         }
         if(mcpDir == 1 && StringCompare(g_lastKOLAState, "NEAR BUY") != 0)
         {
            if(isXau) Print(StringFormat("[TradeManager] ⏳ %s: attente pullback OM (KOLA=%s) avant BUY",
                  sym, g_lastKOLAState));
            // Ne pas détruire l'ordre — re-évaluer au prochain poll (60s)
            return;
         }
      }

      if(isXau) Print(StringFormat("[TradeManager] ✅ %s: GOM OK — %s | KOLA=%s",
            sym, actTag, g_lastKOLAState));
   }
   else if(isXau && UseGOMScalp)
      Print(StringFormat("[TradeManager] ⏭️ %s: GOM check SKIPPED (verdict > %ds)", sym, GOMSignalMaxAgeSec));

   // S'assurer que le symbole est subscrit dans Market Watch
   if(!SymbolSelect(sym, true))
      Print(StringFormat("[TradeManager] ⚠️ SymbolSelect(%s) échoué — symbole non disponible sur ce broker", sym));

   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(atMarket && entry <= 0)
      entry = (action == "BUY") ? ask : bid;
   if(entry <= 0)
   {
      Print(StringFormat("[TradeManager] ❌ %s: prix introuvable (ask=%.5f bid=%.5f) — symbole absent du broker?", sym, ask, bid));
      return;
   }

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
   g_mcpSignals[idx].source          = JsonGetString(orderBody, "source");
   g_mcpSignals[idx].failCount       = 0;

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
   if(IsDailyTargetLocked())
   {
      PrintOnce("[CM] 🔒 MCP Signals bloqués — objectif journalier atteint", 300);
      return;
   }

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
   // Dimensionner: chart + InpPollSymbols + whitelist pipeline + marge
   ArrayResize(syms, np + g_whitelistCount + 8);

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
   // 3. Symboles de la whitelist pipeline (publiée par pipeline_with_approval.py)
   for(int wi = 0; wi < g_whitelistCount; wi++)
   {
      string ws = g_whitelistSymbols[wi];
      bool dup = false;
      for(int j = 0; j < nsyms; j++)
         if(syms[j] == ws) { dup = true; break; }
      if(!dup && nsyms < ArraySize(syms))
         syms[nsyms++] = ws;
   }

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
   // 🔧 FORCER LOT MINIMUM BROKER pour duplication
   double lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
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

   // 1. Cohérence GOM minimale — skip si poller arrêté (coherence=0 = données absentes)
   if(g_lastGOMCoherence > 0 && g_lastGOMCoherence < GlobalMinCoherencePct)
   {
      reason = StringFormat("Cohérence GOM insuffisante (%.0f%% < %.0f%%)",
                            g_lastGOMCoherence, GlobalMinCoherencePct);
      return false;
   }

   // 2. Confiance TF global minimale — skip si poller arrêté (strength=0 = données absentes)
   if(g_lastGOMGlobalStrength > 0 && g_lastGOMGlobalStrength < GlobalDirMinConfidence
      && g_lastGOMGlobalStrength < 10000)  // anti-overflow
   {
      reason = StringFormat("TF global confiance insuffisante (%d%% < %d%%)",
                            g_lastGOMGlobalStrength, GlobalDirMinConfidence);
      return false;
   }

   // 3. Direction TF global doit correspondre à la direction de l'ordre
   // Si direction inconnue (poller pas démarré ou données absentes) → laisser passer
   bool globalBull = (StringCompare(g_lastGOMGlobalDir, "BULL") == 0);
   bool globalBear = (StringCompare(g_lastGOMGlobalDir, "BEAR") == 0);
   bool globalKnown = (StringLen(g_lastGOMGlobalDir) > 0 &&
                       g_lastGOMGlobalStrength > 0 &&
                       g_lastGOMGlobalStrength < 10000);  // sanity anti-overflow
   if(globalKnown)
   {
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

   // Pipeline source préliminaire — sera confirmé après re-fetch plus bas
   bool isPipelineEarly = (StringCompare(g_mcpSignals[idx].source, "pipeline") == 0);

   // 🚫 BLOQUER si GOM=WAIT — aucun entry quel que soit la source
   if(UseGOMScalp && IsGOMVerdictWait())
   {
      PrintOnce(StringFormat("[MCP-Execute] %s bloqué — GOM=WAIT (vnum=%d) — pas d'entry", sym, g_lastGOMVerdictNum), 60);
      return;
   }

   // 🚫 ANTI-CORRECTION: Bloquer BUY en BEAR ou SELL en BULL — évite trader les corrections
   if(UseGOMScalp && g_lastGOMVerdictNum != 0)  // vnum != 0 = direction établie
   {
      int dir = g_mcpSignals[idx].direction;  // 1=BUY, -1=SELL
      bool isBull = (g_lastGOMVerdictNum > 0);  // vnum > 0 = tendance BULL
      bool isBear = (g_lastGOMVerdictNum < 0);  // vnum < 0 = tendance BEAR

      if((dir == 1 && isBear) || (dir == -1 && isBull))
      {
         string dir_txt = (dir == 1) ? "BUY" : "SELL";
         string bias_txt = isBear ? "BEAR" : "BULL";
         PrintOnce(StringFormat("[MCP-Execute] 🚫 %s %s bloqué — OB %s actif, marché en correction (vnum=%d)",
                                sym, dir_txt, bias_txt, g_lastGOMVerdictNum), 60);
         g_mcpSignals[idx].failCount++;
         return;
      }
   }

   // Limite globale : bypassée pour les ordres pipeline (signal validé humainement)
   if(!isPipelineEarly && IsGlobalPositionLimitReached())
   {
      if(isXau) Print(StringFormat("[TradeManager] 🚫 %s: Signal annulé — limite globale %d positions atteinte", sym, MaxGlobalPositions));
      return;
   }

   // 🆕 Vérifier discipline: max 7/jour + cible 20USD (même pour pipeline)
   if(!CanEnterTrade("MCP-Signal"))
   {
      if(isXau) Print(StringFormat("[TradeManager] 🚫 %s: Signal annulé — limite discipline atteinte", sym));
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

   // Souscrire le symbole dans Market Watch si nécessaire
   if(!SymbolInfoInteger(sym, SYMBOL_SELECT))
      SymbolSelect(sym, true);

   double ask  = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid  = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
   {
      Print(StringFormat("[TradeManager] ⚠️ %s: ask=%.5f bid=%.5f — symbole non dispo sur ce broker ou marché fermé", sym, ask, bid));
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
   string execStr = execNow ? "YES" : "NO";
   if(isXau) Print(StringFormat("[TradeManager] execNow=%s distance=%.5f tol=%.5f", execStr, priceDistance, tol));
   if(!execNow && priceDistance > tol)
   {
      if(isXau) Print(StringFormat("[TradeManager] ⏳ %s: Distance %.5f > tolerance %.5f — waiting for price", sym, priceDistance, tol));
      return;  // limit: attendre le prix
   }

   // Sanity check: SL/TP doivent etre du bon cote du prix d'entree
   // Pour pipeline : corriger automatiquement plutôt que tuer le signal
   double slChk = g_mcpSignals[idx].stopLoss;
   double tpChk = g_mcpSignals[idx].takeProfit1;
   if(slChk > 0 && tpChk > 0)
   {
      bool slOk = (dir == 1) ? (slChk < refPx) : (slChk > refPx);
      bool tpOk = (dir == 1) ? (tpChk > refPx) : (tpChk < refPx);
      if(!slOk || !tpOk)
      {
         if(isPipelineEarly)
         {
            // Pipeline : auto-correction SL/TP invalides (swap si inversés)
            double atrFix = slChk > 0 ? MathAbs(refPx - slChk) : MathAbs(tpChk - refPx) * 0.5;
            if(atrFix <= 0) atrFix = refPx * 0.001;
            int dgFix = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
            slChk = NormalizeDouble((dir == 1) ? refPx - atrFix : refPx + atrFix, dgFix);
            tpChk = NormalizeDouble((dir == 1) ? refPx + atrFix * 1.5 : refPx - atrFix * 1.5, dgFix);
            g_mcpSignals[idx].stopLoss    = slChk;
            g_mcpSignals[idx].takeProfit1 = tpChk;
            Print(StringFormat("[TradeManager] 🔧 Pipeline %s %s SL/TP corrigés auto: price=%.5f SL=%.5f TP=%.5f",
                  (dir==1?"BUY":"SELL"), sym, refPx, slChk, tpChk));
         }
         else
         {
            Print(StringFormat("[TradeManager] INVALID SL/TP for %s %s: price=%.5f SL=%.5f TP=%.5f — signal supprime",
                  (dir==1?"BUY":"SELL"), sym, refPx, slChk, tpChk));
            g_mcpSignals[idx].active = false;
            return;
         }
      }
   }

   // ── Re-fetch source depuis serveur pour capter un upgrade gom_tv_sync → pipeline ──
   // Le pipeline peut poster son ordre APRÈS que le poll a queué un signal gom_tv_sync.
   // On re-lit le source HTTP juste avant d'appliquer les guards.
   if(StringCompare(g_mcpSignals[idx].source, "pipeline") != 0)
   {
      string reUrl = StringFormat("http://127.0.0.1:8000/pending-order?symbol=%s&peek=true", sym);
      char reReq[], reResp[];
      string reHdr;
      int reSz = ArraySize(reResp);
      if(WebRequest("GET", reUrl, "Content-Type: application/json\r\n", 5000, reReq, reResp, reHdr) > 0)
      {
         string reBody = CharArrayToString(reResp);
         int reObjPos  = StringFind(reBody, "\"order\":{");
         if(reObjPos >= 0)
         {
            string reOrderBody = StringSubstr(reBody, reObjPos);
            string freshSource = JsonGetString(reOrderBody, "source");
            if(StringLen(freshSource) > 0 && freshSource != g_mcpSignals[idx].source)
            {
               Print(StringFormat("[TradeManager] 🔄 %s: source mis à jour %s → %s",
                     sym, g_mcpSignals[idx].source, freshSource));
               g_mcpSignals[idx].source = freshSource;
            }
         }
      }
   }

   // ── Pipeline bypass : ordres pipeline exécutent SANS aucun guard ──
   bool isPipelineSource = (StringCompare(g_mcpSignals[idx].source, "pipeline") == 0);
   if(isPipelineSource)
      Print(StringFormat("[TradeManager] ✅ %s: source=pipeline — BYPASS all guards", sym));

   // GOM=WAIT — bloquer ordres marché MCP (sauf pipeline validé humainement)
   if(!isPipelineSource && IsGOMVerdictWait())
   {
      PrintOnce(StringFormat("[TradeManager] 🚫 MCP %s %s bloqué — GOM=WAIT (vnum=%d)",
            sym, (dir==1?"BUY":"SELL"), g_lastGOMVerdictNum), 60);
      return;
   }

   // Filtre consolidation (désactivable pour signaux bridge)
   int sIdx = FindState(sym);
   if(sIdx < 0)
   {
      ScanAllPositions();
      sIdx = FindState(sym);
   }
   if(!isPipelineSource && !MCPBypassConsolidation && sIdx >= 0 && IsConsolidating(sIdx))
   {
      PrintOnce(StringFormat("[TradeManager] 🔶 Signal MCP %s bloqué — consolidation élevée", sym), 120);
      return;
   }

   // Filtre biais TA (skip pour pipeline)
   if(!isPipelineSource && RequireSignalAlign)
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

   // Filtre TF global + cohérence (skip pour pipeline et Boom/Crash)
   if(!isPipelineSource && !IsBoomOrCrashSymbol(sym))
   {
      string globalReason;
      if(!CheckGlobalDirAndCoherence(dir, globalReason))
      {
         PrintOnce(StringFormat("[TradeManager] 🚫 MCP %s %s bloqué — %s",
               sym, (dir==1?"BUY":"SELL"), globalReason), 60);
         return;
      }
   }

   // ── GUARD BB — bloquer si BB contre-tendance (skip pipeline) ──
   if(!isPipelineSource && IsBBCounterTrend(dir))
   {
      PrintOnce(StringFormat("[TradeManager] 🚫 MCP %s %s bloqué — BB contre-tendance (attendre pullback OB ou BB haussier)",
            sym, (dir==1?"BUY":"SELL")), 60);
      return;
   }

   // ── GUARD OB (skip pour pipeline et Boom/Crash) ──
   if(!isPipelineSource && !IsBoomOrCrashSymbol(sym) && !IsPriceAtOBEntry(dir)) return;

   // ── GUARD OB route (skip pour pipeline et Boom/Crash) ──
   string obBlockReason = "";
   if(!isPipelineSource && !IsBoomOrCrashSymbol(sym) && IsOBBlockingPath(dir, obBlockReason)) return;

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
      RegisterTradeEntry(dir, "MCP-Signal");  // 🆕 Incrémenter compteur discipline
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

   // 🔒 GARDE PIPELINE ONLY MODE (duplication = entrée auto)
   if(!CanAutoEntry("Manual-Duplicate")) return;

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

      // Dupliquer — 🔧 LOT MINIMUM BROKER
      double lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
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
   if(StringFind(body, "\"ok\":false") >= 0)
   {
      // Serveur signale données stales ou absentes → forcer WAIT pour éviter verdict stale
      string staleVerdict = JsonGetString(body, "verdict");
      if(StringLen(staleVerdict) == 0 || StringCompare(staleVerdict, "WAIT") == 0
         || StringFind(body, "stale") >= 0 || StringFind(body, "Aucun") >= 0)
      {
         g_lastGOMVerdictNum = 0;
         g_lastGOMVerdict    = "WAIT";
         PrintOnce("[GOM-Poll] ok:false reçu → verdict forcé WAIT (données stales/absentes)", 60);
      }
      return;
   }

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
   g_lastBBMid    = JsonGetDouble(body, "bb_mid");
   g_lastBBDn     = JsonGetDouble(body, "bb_dn");
   g_setupBuyProb  = JsonGetDouble(body, "setup_buy_prob");
   g_setupSellProb = JsonGetDouble(body, "setup_sell_prob");
   g_setupValidProb = JsonGetDouble(body, "setup_valid_prob");
   g_predHitRate   = JsonGetDouble(body, "pred_direction_hit_rate");
   if(g_setupBuyProb > 1.0)  g_setupBuyProb  /= 100.0;
   if(g_setupSellProb > 1.0) g_setupSellProb /= 100.0;

   // GHOST OrderFlow — lire si disponibles dans le payload
   double gDelta   = JsonGetDouble(body, "ghost_delta",   -99999);
   double gCVD     = JsonGetDouble(body, "ghost_cvd",     -99999);
   double gBuyPct  = JsonGetDouble(body, "ghost_buypct",  -1);
   double gCompass = JsonGetDouble(body, "ghost_compass", -1);
   if(gDelta   > -99999) g_ghostDelta   = gDelta;
   if(gCVD     > -99999) g_ghostCVD     = gCVD;
   if(gBuyPct  >= 0)     g_ghostBuyPct  = gBuyPct;
   if(gCompass >= 0)     g_ghostCompass = gCompass;

   // Order Blocks confirmés depuis Pine
   double obBT = JsonGetDouble(body, "ob_bull_top", 0);
   double obBB = JsonGetDouble(body, "ob_bull_bot", 0);
   double obRT = JsonGetDouble(body, "ob_bear_top", 0);
   double obRB = JsonGetDouble(body, "ob_bear_bot", 0);
   if(obBT > 0) g_obBullTop = obBT;
   if(obBB > 0) g_obBullBot = obBB;
   if(obRT > 0) g_obBearTop = obRT;
   if(obRB > 0) g_obBearBot = obRB;

   if(g_setupValidProb > 1.0) g_setupValidProb /= 100.0;
   if(g_predHitRate > 1.0) g_predHitRate /= 100.0;

   g_spikeTradable  = JsonGetDouble(body, "spike_tradable") >= 1.0;
   g_spikeImminence = JsonGetDouble(body, "imminence_pct");

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

         // ⏰ Grace period: skip consolidation close for first 120 seconds
         long openTimeLong = PositionGetInteger(POSITION_TIME);
         long timeNowLong  = (long)TimeCurrent();
         int ageSeconds    = (int)(timeNowLong - openTimeLong);
         bool withinGrace  = (ageSeconds < 120);

         // Fermer si profit < $5 USD (fausse entrée en consolidation) — MAIS PAS dans les 2 premières minutes
         if(!withinGrace && profit < 5.0)
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
   int    dg  = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double pt  = SymbolInfoDouble(sym, SYMBOL_POINT);

   // ── Lire ATR M5 (14 périodes) pour calibrer SL/TP sur la volatilité réelle ──
   double atrVal = 0.0;
   int hAtr = iATR(sym, PERIOD_M5, 14);
   if(hAtr != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(hAtr, 0, 1, 1, atrBuf) >= 1) atrVal = atrBuf[0];
      IndicatorRelease(hAtr);
   }
   // Fallback si ATR indisponible : 0.3% du prix
   if(atrVal <= 0) atrVal = entryPx * 0.003;

   // ── Priorité 1 : niveaux GOM (OB setup ou KOLA) ──
   // SL = au-delà du niveau structure (OB SL du setup, ou KOLA opposé + buffer)
   double slDist = 0.0;
   double tpDist = 0.0;

   if(g_setupValid && g_setupSL > 0 && g_setupDir == dir)
   {
      // Utiliser le SL du setup OB GOM — il est déjà positionné sur la structure
      slDist = MathAbs(entryPx - g_setupSL);
      // TP1 du setup si disponible, sinon R/R 1:2
      if(g_setupTP1 > 0)
         tpDist = MathAbs(entryPx - g_setupTP1);
      else
         tpDist = slDist * 2.0;
   }
   else
   {
      // ── Priorité 2 : niveaux KOLA comme cible ──
      double kolaOpposite = (dir == 1) ? g_lastKolaSell : g_lastKolaBuy;
      // Sanity : KOLA valide = dans ±30% du prix courant et non nul
      bool kolaValid = (kolaOpposite > 0 &&
                        MathAbs(entryPx - kolaOpposite) > atrVal * 0.5 &&
                        MathAbs(entryPx - kolaOpposite) / entryPx < 0.30);
      if(kolaValid)
         tpDist = MathAbs(entryPx - kolaOpposite);
      else
         tpDist = atrVal * 3.0;  // TP = 3× ATR minimum

      // SL = 0.8× ATR — serré pour petit compte
      slDist = atrVal * 0.8;
   }

   // ── Sécurités minimales (petit compte : SL serré) ──
   double minSL = atrVal * 0.5;   // SL jamais inférieur à 0.5× ATR
   double minTP = atrVal * 1.0;   // TP jamais inférieur à 1× ATR
   slDist = MathMax(slDist, minSL);
   tpDist = MathMax(tpDist, minTP);
   // R/R minimum 1:1.5
   if(tpDist < slDist * 1.5) tpDist = slDist * 1.5;

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
   if(v == 0) return false;  // GOM=WAIT — aucun trade marché autorisé

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
//| Vérifie qu'aucun OB opposé ne bloque le chemin vers le TP        |
//| BUY  : OB BEAR entre prix actuel et TP = BLOQUER                 |
//| SELL : OB BULL entre prix actuel et TP = BLOQUER                 |
//+------------------------------------------------------------------+
bool IsOBBlockingPath(const int dir, const string reason_out)
{
   // Si pas de setup GOM valide ou pas de TP, on ne peut pas vérifier
   if(!g_setupValid || g_setupTP1 <= 0) return false;

   double price = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp    = g_setupTP1;

   // OB BEAR = zone de résistance au-dessus du prix actuel (g_lastBBUp / g_lastKolaSell)
   // OB BULL = zone de support en-dessous du prix actuel (g_lastBBDn / g_lastKolaBuy)

   if(dir == 1) // BUY — chercher OB BEAR entre price et tp
   {
      // Résistance KOLA SELL dans le chemin
      if(g_lastKolaSell > price && g_lastKolaSell < tp)
      {
         PrintOnce(StringFormat("[OB-Guard] %s BUY BLOQUÉ — KOLA SELL %.5f dans chemin (price=%.5f tp=%.5f)",
               _Symbol, g_lastKolaSell, price, tp), 30);
         return true;
      }
      // Résistance BB UP dans le chemin
      if(g_lastBBUp > price && g_lastBBUp < tp)
      {
         PrintOnce(StringFormat("[OB-Guard] %s BUY BLOQUÉ — BB résistance %.5f dans chemin (price=%.5f tp=%.5f)",
               _Symbol, g_lastBBUp, price, tp), 30);
         return true;
      }
   }
   else // SELL — chercher OB BULL entre tp et price
   {
      // Support KOLA BUY dans le chemin
      if(g_lastKolaBuy < price && g_lastKolaBuy > tp)
      {
         PrintOnce(StringFormat("[OB-Guard] %s SELL BLOQUÉ — KOLA BUY %.5f dans chemin (price=%.5f tp=%.5f)",
               _Symbol, g_lastKolaBuy, price, tp), 30);
         return true;
      }
      // Support BB DN dans le chemin
      if(g_lastBBDn < price && g_lastBBDn > tp)
      {
         PrintOnce(StringFormat("[OB-Guard] %s SELL BLOQUÉ — BB support %.5f dans chemin (price=%.5f tp=%.5f)",
               _Symbol, g_lastBBDn, price, tp), 30);
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie que le prix est sur l'OB entry OU sur le niveau KOLA    |
//| KOLA BUY/SELL = anticipation valide avant même l'OB pullback    |
//+------------------------------------------------------------------+
bool IsPriceAtOBEntry(const int dir)
{
   double price = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Calcul tolérance ATR M5
   double atrTol = 0.0;
   int hAtr = iATR(_Symbol, PERIOD_M5, 14);
   if(hAtr != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(hAtr, 0, 1, 1, atrBuf) >= 1) atrTol = atrBuf[0] * 0.3;
      IndicatorRelease(hAtr);
   }
   double tol = MathMax(atrTol, price * 0.0005);

   // ── PRIORITÉ 1 : Prix touche le niveau KOLA (anticipation) ──────────
   // KOLA BUY → entrée BUY dès que le prix touche ce niveau
   // KOLA SELL → entrée SELL dès que le prix touche ce niveau
   double kolaLevel = (dir == 1) ? g_lastKolaBuy : g_lastKolaSell;
   if(kolaLevel > 0 && MathAbs(price - kolaLevel) <= tol)
   {
      PrintOnce(StringFormat("[KOLA-Entry] %s %s | prix %.5f touche KOLA %.5f ✅ — entrée anticipée",
            _Symbol, (dir==1?"BUY":"SELL"), price, kolaLevel), 15);
      return true;
   }

   // ── PRIORITÉ 2 : Prix touche l'OB entry du setup GOM ────────────────
   if(g_setupValid && g_setupEntry > 0)
   {
      if(MathAbs(price - g_setupEntry) <= tol)
      {
         PrintOnce(StringFormat("[OB-Entry] %s %s | prix %.5f sur OB entry %.5f ✅",
               _Symbol, (dir==1?"BUY":"SELL"), price, g_setupEntry), 15);
         return true;
      }
      // Prix entre KOLA et OB entry — attendre l'un des deux niveaux
      PrintOnce(StringFormat("[OB-Guard] %s attente KOLA %.5f ou OB %.5f | prix %.5f",
            _Symbol, kolaLevel, g_setupEntry, price), 15);
      return false;
   }

   // Pas de setup OB — autoriser si KOLA est proche (priorité 1 a déjà été vérifiée)
   if(kolaLevel > 0)
   {
      PrintOnce(StringFormat("[OB-Guard] %s attente KOLA %.5f | prix %.5f (dist=%.5f tol=%.5f)",
            _Symbol, kolaLevel, price, MathAbs(price - kolaLevel), tol), 15);
      return false;
   }

   // Ni OB ni KOLA disponibles — laisser passer (GOM seul suffit)
   return true;
}

//+------------------------------------------------------------------+
//| Entrée auto depuis verdict GOM (GOOD/PERFECT) — secours EA       |
//+------------------------------------------------------------------+
void CheckGOMAutoEntry()
{
   if(!UseGOMScalp || !UseGOMAutoEntry) return;

   // 🔒 GARDE PIPELINE ONLY MODE
   if(!CanAutoEntry("GOM-AutoEntry", _Symbol)) return;

   if(IsDailyTargetLocked())
   {
      PrintOnce("[CM] 🔒 GOM AutoEntry bloqué — objectif journalier atteint", 300);
      return;
   }
   if(!CanEnterTrade("GOM-AutoEntry"))
   {
      return;  // 🆕 Vérifier discipline: max 7/jour + cible 20USD
   }
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

   if(IsBBCounterTrend(dir))
   {
      PrintOnce(StringFormat("[GOM-Auto] %s bloque — BB contre-tendance (attendre pullback OB ou BB haussier)",
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

   // ── GUARD OB : attendre que le prix soit à l'OB entry ──
   if(!IsPriceAtOBEntry(dir)) return;

   // ── GUARD OB : bloquer si un OB opposé barre la route vers le TP ──
   string obReason = "";
   if(IsOBBlockingPath(dir, obReason)) return;

   // ── GHOST OrderFlow : vetos si CVD, sentiment ET compass contradisent la direction ──
   if(g_ghostCVD != 0.0 || g_ghostBuyPct != 50.0 || g_ghostCompass > 0)
   {
      bool ghostOk = true;
      int cmpOct = (int)((g_ghostCompass + 22.5) / 45.0) % 8;
      bool compassBullish = (cmpOct == 0 || cmpOct == 1 || cmpOct == 2 || cmpOct == 7);
      bool compassBearish = (cmpOct == 4 || cmpOct == 5 || cmpOct == 6 || cmpOct == 3);

      if(dir == 1 && g_ghostCVD < 0 && g_ghostBuyPct < 40.0)
      {
         PrintOnce(StringFormat("[GHOST] BUY bloqué — CVD=%.0f baissier + sentiment=%.0f%% faible",
               g_ghostCVD, g_ghostBuyPct), 30);
         ghostOk = false;
      }
      if(dir == -1 && g_ghostCVD > 0 && g_ghostBuyPct > 60.0)
      {
         PrintOnce(StringFormat("[GHOST] SELL bloqué — CVD=%.0f haussier + sentiment=%.0f%% fort",
               g_ghostCVD, g_ghostBuyPct), 30);
         ghostOk = false;
      }
      // Compass veto : momentum opposé à la direction demandée
      if(dir == 1 && compassBearish && g_ghostBuyPct < 50.0)
      {
         PrintOnce(StringFormat("[GHOST] BUY bloqué — Compass bearish (%s %.0f°) + sentiment=%.0f%%",
               (cmpOct==3?"NW":cmpOct==4?"W":cmpOct==5?"SW":"S"), g_ghostCompass, g_ghostBuyPct), 30);
         ghostOk = false;
      }
      if(dir == -1 && compassBullish && g_ghostBuyPct > 50.0)
      {
         PrintOnce(StringFormat("[GHOST] SELL bloqué — Compass bullish (%s %.0f°) + sentiment=%.0f%%",
               (cmpOct==0?"E":cmpOct==1?"NE":cmpOct==2?"N":"SE"), g_ghostCompass, g_ghostBuyPct), 30);
         ghostOk = false;
      }
      if(!ghostOk) return;
   }

   // 🔧 FORCER LOT MINIMUM BROKER (ignorer GOMReEntryLot input)
   double lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
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
   RegisterTradeEntry(dir, "GOM-AutoEntry");  // 🆕 Incrémenter compteur discipline
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

   // 🔒 GARDE PIPELINE ONLY MODE
   if(!CanAutoEntry("GOM-ReEntry")) return;

   if(IsDailyTargetLocked())
   {
      PrintOnce("[CM] 🔒 GOM ReEntry bloqué — objectif journalier atteint", 300);
      return;
   }
   if(!CanEnterTrade("GOM-ReEntry"))
   {
      return;  // 🆕 Vérifier discipline: max 7/jour + cible 20USD
   }
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

      // Cooldown post-SL via g_states
      int sIdx2 = FindState(posSym);
      if(sIdx2 >= 0 && g_states[sIdx2].lastSLHitTime > 0)
      {
         int losses2    = g_states[sIdx2].consecutiveLosses;
         int cooldown2  = (losses2 >= 2) ? 1200 : 600;
         int elapsed2   = (int)(TimeCurrent() - g_states[sIdx2].lastSLHitTime);
         if(elapsed2 < cooldown2)
         {
            PrintOnce(StringFormat("[GOM-ReEntry] %s bloqué — %d perte(s) SL, reste %ds",
                  posSym, losses2, cooldown2 - elapsed2), 60);
            continue;
         }
      }

      bool gomGood = (vnum == 2 || vnum == 3 || vnum == -2 || vnum == -3);
      bool aligned = gomGood && ((dir == -1 && vnum <= -2) || (dir == 1 && vnum >= 2));
      if(!aligned) continue;

      // Bloquer re-entrée en zone de correction (micro-TF contre tendance)
      if(IsGOMCorrectionZone(dir))
      {
         PrintOnce(StringFormat("[GOM-ReEntry] %s re-entrée bloquée — zone correction", posSym), 60);
         continue;
      }

      if(IsBBCounterTrend(dir))
      {
         PrintOnce(StringFormat("[GOM-ReEntry] %s re-entrée bloquée — BB contre-tendance", posSym), 60);
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

      // Ouvrir re-entrée — 🔧 LOT MINIMUM BROKER
      CTrade reTrade;
      reTrade.SetExpertMagicNumber(MCPMagicNumber);
      reTrade.SetDeviationInPoints(30);
      reTrade.SetTypeFilling(ORDER_FILLING_IOC);

      double lot = SymbolInfoDouble(posSym, SYMBOL_VOLUME_MIN);
      double sl  = g_gomReEntry[i].stopLoss;
      double tp  = g_gomReEntry[i].takeProfit;
      bool ok = (dir == 1) ? reTrade.Buy(lot, posSym, 0, sl, tp, "TM_GOM_REENTRY")
                           : reTrade.Sell(lot, posSym, 0, sl, tp, "TM_GOM_REENTRY");
      if(ok)
      {
         g_gomReEntry[i].reEntryCount++;
         g_gomReEntry[i].closedAt = TimeCurrent();
         RegisterTradeEntry(dir, "GOM-ReEntry");  // 🆕 Incrémenter compteur discipline
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

//+------------------------------------------------------------------+
//| COMPASS VISUEL — Dessin boussole moneyflow dans le dashboard     |
//+------------------------------------------------------------------+
void DrawCompassVisual(int cx, int cy, int radius)
{
   string pfx = "TM_DASH_CMP_";
   int compassOct = (int)((g_ghostCompass + 22.5) / 45.0) % 8;
   bool isBull = (compassOct == 0 || compassOct == 1 || compassOct == 2 || compassOct == 7);
   color activeClr = isBull ? ColorBuy : ColorSell;

   // Fond cercle (rectangle arrondi simulé)
   string bgName = pfx + "BG";
   if(ObjectFind(0, bgName) < 0)
   {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   }
   int boxSize = radius * 2 + 12;
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, cx - radius - 6);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, cy + radius + 6);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, boxSize);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, boxSize);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, 0x1A1A2E);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, ColorBorder);

   // Labels cardinaux (N/S/E/W + diagonales)
   static const string dirs[8] = {"E","NE","N","NW","W","SW","S","SE"};
   // Positions relatives sur cercle (cos/sin * radius, Y inversé car LOWER)
   static const double cosA[8] = { 1.0,  0.707, 0.0, -0.707, -1.0, -0.707,  0.0,  0.707};
   static const double sinA[8] = { 0.0,  0.707, 1.0,  0.707,  0.0, -0.707, -1.0, -0.707};

   for(int d = 0; d < 8; d++)
   {
      string lName = pfx + "D" + IntegerToString(d);
      if(ObjectFind(0, lName) < 0)
      {
         ObjectCreate(0, lName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, lName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetString(0, lName, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, lName, OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetInteger(0, lName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lName, OBJPROP_BACK, false);
      }
      int lx = cx + (int)(cosA[d] * (radius - 4));
      int ly = cy - (int)(sinA[d] * (radius - 4));
      bool active = (d == compassOct);
      ObjectSetInteger(0, lName, OBJPROP_XDISTANCE, lx);
      ObjectSetInteger(0, lName, OBJPROP_YDISTANCE, ly);
      ObjectSetString(0, lName, OBJPROP_TEXT, dirs[d]);
      ObjectSetInteger(0, lName, OBJPROP_FONTSIZE, active ? 10 : 7);
      ObjectSetInteger(0, lName, OBJPROP_COLOR, active ? activeClr : 0x606060);
   }

   // Aiguille : point central + extrémité (label Unicode ●→►)
   string centerName = pfx + "CTR";
   if(ObjectFind(0, centerName) < 0)
   {
      ObjectCreate(0, centerName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, centerName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetString(0, centerName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, centerName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, centerName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetInteger(0, centerName, OBJPROP_XDISTANCE, cx);
   ObjectSetInteger(0, centerName, OBJPROP_YDISTANCE, cy);
   ObjectSetString(0, centerName, OBJPROP_TEXT, "+");
   ObjectSetInteger(0, centerName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, centerName, OBJPROP_COLOR, 0xB0B0B0);

   // Pointe de l'aiguille (à 70% du rayon dans la direction)
   string needleName = pfx + "NDL";
   if(ObjectFind(0, needleName) < 0)
   {
      ObjectCreate(0, needleName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, needleName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetString(0, needleName, OBJPROP_FONT, "Wingdings");
      ObjectSetInteger(0, needleName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, needleName, OBJPROP_SELECTABLE, false);
   }
   double rad = g_ghostCompass * M_PI / 180.0;
   int nx = cx + (int)(MathCos(rad) * radius * 0.65);
   int ny = cy - (int)(MathSin(rad) * radius * 0.65);
   ObjectSetInteger(0, needleName, OBJPROP_XDISTANCE, nx);
   ObjectSetInteger(0, needleName, OBJPROP_YDISTANCE, ny);
   ObjectSetString(0, needleName, OBJPROP_TEXT, CharToString(108));
   ObjectSetInteger(0, needleName, OBJPROP_FONTSIZE, 14);
   ObjectSetInteger(0, needleName, OBJPROP_COLOR, activeClr);

   // Titre au-dessus : "MONEYFLOW COMPASS"
   string hdrName = pfx + "HDR";
   if(ObjectFind(0, hdrName) < 0)
   {
      ObjectCreate(0, hdrName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, hdrName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetString(0, hdrName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, hdrName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, hdrName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetInteger(0, hdrName, OBJPROP_XDISTANCE, cx);
   ObjectSetInteger(0, hdrName, OBJPROP_YDISTANCE, cy - radius - 14);
   ObjectSetString(0, hdrName, OBJPROP_TEXT, "MONEYFLOW COMPASS");
   ObjectSetInteger(0, hdrName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, hdrName, OBJPROP_COLOR, 0xB0B0B0);

   // Valeur angle + direction
   string titleName = pfx + "TTL";
   if(ObjectFind(0, titleName) < 0)
   {
      ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetString(0, titleName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, titleName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, titleName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, cx);
   ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, cy + radius + 14);
   string valTxt = dirs[compassOct] + " " + DoubleToString(g_ghostCompass, 0) + "\xB0";
   ObjectSetString(0, titleName, OBJPROP_TEXT, valTxt);
   ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, titleName, OBJPROP_COLOR, activeClr);

   // Label explicatif : "FLUX ACHETEUR" / "FLUX VENDEUR" / "NEUTRE"
   string explName = pfx + "EXPL";
   if(ObjectFind(0, explName) < 0)
   {
      ObjectCreate(0, explName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, explName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetString(0, explName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, explName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, explName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetInteger(0, explName, OBJPROP_XDISTANCE, cx);
   ObjectSetInteger(0, explName, OBJPROP_YDISTANCE, cy + radius + 28);
   bool isBear = (compassOct == 3 || compassOct == 4 || compassOct == 5 || compassOct == 6);
   string explTxt = isBull ? "FLUX ACHETEUR" : isBear ? "FLUX VENDEUR" : "NEUTRE";
   ObjectSetString(0, explName, OBJPROP_TEXT, explTxt);
   ObjectSetInteger(0, explName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, explName, OBJPROP_COLOR, isBull ? ColorBuy : isBear ? ColorSell : ColorNeutral);
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

void DisplayDisciplineDashboard()
{
   if(!UseDashboard) return;

   double closedPnl = CalcDailyClosedProfit();
   int remaining = g_maxDailyTrades - g_dailyTradeCount;
   bool targetReached = (closedPnl >= g_dailyProfitTarget);
   bool tradesMaxed = (g_dailyTradeCount >= g_maxDailyTrades);

   string status = "";
   if(tradesMaxed && targetReached) status = "MAX & CIBLE";
   else if(tradesMaxed) status = "MAX TRADES";
   else if(targetReached) status = "CIBLE +20";
   else status = "OK";

   // 🆕 Ligne 1: Compteur trade + Profit cible
   string line1 = "[DISCIPLINE] " + IntegerToString(g_dailyTradeCount) + "/" + IntegerToString(g_maxDailyTrades) + " | $" + StringFormat("%.2f", closedPnl) + "/$" + StringFormat("%.2f", g_dailyProfitTarget) + " | " + status;

   // 🆕 Ligne 2: Wins/Losses + Profit/Perte détaillés
   double netProfit = g_totalProfitWins - g_totalLossPerfect;
   string winRatio = (g_totalWins + g_totalLosses > 0) ?
      StringFormat("%.0f%%", 100.0 * g_totalWins / (g_totalWins + g_totalLosses)) : "N/A";
   string line2 = "📊 Win: " + IntegerToString(g_totalWins) + " | Loss: " + IntegerToString(g_totalLosses) + " | " + winRatio + " | Gagné: +$" + StringFormat("%.2f", g_totalProfitWins) + " | Perdu: -$" + StringFormat("%.2f", g_totalLossPerfect);

   // Utiliser ObjectCreate pour placer le texte à une position fixe (bas du chart)
   string objName1 = "DISC_DASHBOARD_1";
   string objName2 = "DISC_DASHBOARD_2";

   // Supprimer les anciens objets s'ils existent
   if(ObjectFind(0, objName1) >= 0) ObjectDelete(0, objName1);
   if(ObjectFind(0, objName2) >= 0) ObjectDelete(0, objName2);

   // Ligne 1: Discipline counter
   ObjectCreate(0, objName1, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, objName1, OBJPROP_TEXT, line1);
   ObjectSetInteger(0, objName1, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, objName1, OBJPROP_YDISTANCE, 100);
   ObjectSetInteger(0, objName1, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName1, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, objName1, OBJPROP_FONT, "Courier New");
   ObjectSetInteger(0, objName1, OBJPROP_COLOR, 32768);  // Vert
   ObjectSetInteger(0, objName1, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName1, OBJPROP_SELECTABLE, false);

   // Ligne 2: Win/Loss stats
   ObjectCreate(0, objName2, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, objName2, OBJPROP_TEXT, line2);
   ObjectSetInteger(0, objName2, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, objName2, OBJPROP_YDISTANCE, 120);  // 20px below line1
   ObjectSetInteger(0, objName2, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName2, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, objName2, OBJPROP_FONT, "Courier New");
   ObjectSetInteger(0, objName2, OBJPROP_COLOR, g_totalProfitWins > g_totalLossPerfect ? 32768 : 16711680);  // Green if profit, Red if loss
   ObjectSetInteger(0, objName2, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName2, OBJPROP_SELECTABLE, false);
}

void UpdateWinLossStats()
{
   // 🆕 Scan l'historique fermé du jour et met à jour win/loss counters
   g_totalWins = 0;
   g_totalLosses = 0;
   g_totalProfitWins = 0.0;
   g_totalLossPerfect = 0.0;

   CDealInfo dealInfo;  // Instance pour lire les deals
   datetime midnightToday = iTime(_Symbol, PERIOD_D1, 0);  // Minuit UTC d'aujourd'hui

   // Scanner deal history pour les positions fermées du jour
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(!dealInfo.Select(ticket)) continue;

      // Filtrer: only deals from today, only closing deals
      if(dealInfo.Time() < midnightToday) break;  // Pas du jour
      if(dealInfo.Entry() != DEAL_ENTRY_OUT && dealInfo.Entry() != DEAL_ENTRY_OUT_BY) continue;

      // Sommer le profit/perte de ce deal
      double dealProfit = dealInfo.Profit() + dealInfo.Commission() + dealInfo.Swap();

      if(dealProfit >= 0)
      {
         g_totalWins++;
         g_totalProfitWins += dealProfit;
      }
      else
      {
         g_totalLosses++;
         g_totalLossPerfect += MathAbs(dealProfit);
      }
   }
}

void RefreshDashboard()
{
   if(!UseDashboard) return;
   UpdateWinLossStats();  // Mettre à jour les stats avant affichage
   if(TimeCurrent() - g_lastDashboardUpdate < DashboardUpdateSec) return;
   g_lastDashboardUpdate = TimeCurrent();

   GOMData gom = FetchGOMDataForChart();
   if(gom.valid)
   {
      SyncGOMGlobalsFromData(gom);
      DisplayCompleteGOMDashboard(gom);
   }

   DisplayDisciplineDashboard();  // 🆕 Afficher compteur discipline EN DERNIER (par-dessus les tables)
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

   // ── Ligne SETUP (3ème ligne — au-dessus des 2 premières) ─────────────
   // Affiche le tableau SETUP TradingView : type, entry, SL, TP1, TP2, RR, confirm
   int y2 = marginBot + (cellH + gap) * 2;   // ligne au-dessus de y0
   xCur   = marginLR;

   // Col 0 — Type setup + direction
   color cSetup = (g_setupDir == 1) ? ColorBuy : (g_setupDir == -1) ? ColorSell : ColorNeutral;
   string setupLabel = (g_setupValid && g_setupEntry > 0)
      ? g_setupType + (g_setupDir == 1 ? " ▲" : " ▼")
      : "NO SETUP";
   DrawDashCell("S0_TYPE", xCur, y2, cellW, cellH, setupLabel, cSetup, cTxt);

   // Col 1 — Entry OB
   xCur += cellW + gap;
   string entryTxt = (g_setupEntry > 0) ? "E " + DoubleToString(g_setupEntry, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) : "---";
   DrawDashCell("S1_ENTRY", xCur, y2, cellW, cellH, entryTxt, cSetup, cTxt);

   // Col 2 — SL
   xCur += cellW + gap;
   string slTxt = (g_setupSL > 0) ? "SL " + DoubleToString(g_setupSL, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) : "---";
   DrawDashCell("S2_SL", xCur, y2, cellW, cellH, slTxt, ColorSell, cTxt);

   // Col 3 — TP1
   xCur += cellW + gap;
   string tp1Txt = (g_setupTP1 > 0) ? "TP1 " + DoubleToString(g_setupTP1, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) : "---";
   DrawDashCell("S3_TP1", xCur, y2, cellW, cellH, tp1Txt, ColorBuy, cTxt);

   // Col 4 — TP2
   xCur += cellW + gap;
   string tp2Txt = (g_setupTP2 > 0) ? "TP2 " + DoubleToString(g_setupTP2, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) : "---";
   DrawDashCell("S4_TP2", xCur, y2, cellW, cellH, tp2Txt, ColorBuy, cTxt);

   // Col 5 — R/R
   xCur += cellW + gap;
   string rrTxt = (g_setupRR > 0) ? "R/R " + DoubleToString(g_setupRR, 1) : "R/R ---";
   color cRR = (g_setupRR >= 1.5) ? ColorBuy : (g_setupRR > 0) ? ColorNeutral : cBg;
   DrawDashCell("S5_RR", xCur, y2, cellW, cellH, rrTxt, cRR, cTxt);

   // Col 6 — Confirm pattern
   xCur += cellW + gap;
   string confTxt = (StringLen(g_setupConfirm) > 0) ? g_setupConfirm : "CONFIRM ---";
   DrawDashCell("S6_CONF", xCur, y2, cellW, cellH, confTxt, cBg, cTxt);

   // Col 7 — OB entry guard (prix proche de l'entry ?)
   xCur += cellW + gap;
   double curPx = (g_setupDir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tol   = (curPx > 0) ? curPx * 0.0015 : 0;
   bool nearEntry = (g_setupEntry > 0 && tol > 0 && MathAbs(curPx - g_setupEntry) <= tol);
   string guardTxt = (g_setupEntry > 0) ? (nearEntry ? "AT OB ✓" : "WAIT OB") : "---";
   color  cGuard   = nearEntry ? ColorBuy : ColorNeutral;
   DrawDashCell("S7_GUARD", xCur, y2, cellW, cellH, guardTxt, cGuard, cTxt);

   // Col 8 — OB path guard (chemin libre vers TP ?)
   xCur += cellW + gap;
   bool pathBlocked = IsOBBlockingPath(g_setupDir, "");
   string pathTxt = (g_setupValid) ? (pathBlocked ? "OB BLOCK ✗" : "PATH OK ✓") : "---";
   color  cPath    = (!g_setupValid) ? cBg : pathBlocked ? ColorSell : ColorBuy;
   DrawDashCell("S8_PATH", xCur, y2, cellW, cellH, pathTxt, cPath, cTxt);

   // ── Ligne GHOST (4ème ligne) ──────────────────────────────────────────
   int y3 = marginBot + (cellH + gap) * 3;
   xCur   = marginLR;

   // CVD session
   color cCVD = (g_ghostCVD >= 0) ? ColorBuy : ColorSell;
   DrawDashCell("G0_CVD", xCur, y3, cellW, cellH,
                "CVD " + (g_ghostCVD >= 0 ? "+" : "") + DoubleToString(g_ghostCVD, 0), cCVD, cTxt);

   // Delta bougie courante
   xCur += cellW + gap;
   color cDelta = (g_ghostDelta >= 0) ? ColorBuy : ColorSell;
   DrawDashCell("G1_DLT", xCur, y3, cellW, cellH,
                "D " + (g_ghostDelta >= 0 ? "+" : "") + DoubleToString(g_ghostDelta, 0), cDelta, cTxt);

   // Sentiment BUY%
   xCur += cellW + gap;
   color cSent = (g_ghostBuyPct > 60) ? ColorBuy : (g_ghostBuyPct < 40) ? ColorSell : ColorNeutral;
   DrawDashCell("G2_SNT", xCur, y3, cellW, cellH,
                "BUY " + DoubleToString(g_ghostBuyPct, 0) + "%", cSent, cTxt);

   // Compass angle → direction label
   xCur += cellW + gap;
   int compassOct = (int)((g_ghostCompass + 22.5) / 45.0) % 8;
   static const string compassLbls[8] = {"E>","NE","N^","NW","W<","SW","Sv","SE"};
   bool compassBull = (compassOct == 0 || compassOct == 1 || compassOct == 2 || compassOct == 7);
   color cCmp = compassBull ? ColorBuy : ColorSell;
   string cmpTxt = compassLbls[compassOct] + " " + DoubleToString(g_ghostCompass, 0) + "d";
   DrawDashCell("G3_CMP", xCur, y3, cellW, cellH, cmpTxt, cCmp, cTxt);

   // Confluence GHOST : les 4 signaux pointent dans la même direction ?
   xCur += cellW + gap;
   int ghostBull = 0, ghostBear = 0;
   if(g_ghostCVD    > 0) ghostBull++; else if(g_ghostCVD < 0) ghostBear++;
   if(g_ghostDelta  > 0) ghostBull++; else if(g_ghostDelta < 0) ghostBear++;
   if(g_ghostBuyPct > 55) ghostBull++; else if(g_ghostBuyPct < 45) ghostBear++;
   if(compassBull) ghostBull++; else ghostBear++;
   string ghostCnf = IntegerToString(ghostBull) + "B/" + IntegerToString(ghostBear) + "S";
   color cGhostCnf = (ghostBull >= 3) ? ColorBuy : (ghostBear >= 3) ? ColorSell : ColorNeutral;
   DrawDashCell("G4_CNF", xCur, y3, cellW * 2, cellH, "GHOST " + ghostCnf, cGhostCnf, cTxt);

   // ── Compass visuel (milieu-droit du dashboard) ──
   int compassRadius = (cellH * 2) + 4;
   int compassCX = (chartW * 3) / 4;
   int compassCY = y3 - cellH / 2;
   DrawCompassVisual(compassCX, compassCY, compassRadius);

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
