//+------------------------------------------------------------------+
//|                                                  SpikeRiderEA.mq5 |
//|   EA spécialisé détection et capture de spikes Boom/Crash/PAIN/GAIN|
//|   Logique : Z-Score + ATR + RSI + Stair + Compteur inter-spike   |
//|   Sortie   : TP fixe ATR × mult + trailing stop dès activation   |
//|   Symboles : Boom 300/500/600/900/1000, Crash 300/500/600/900/1000|
//|              PAINx / GAINx (Weltrade synthetics)                  |
//|   v5.06 : panel2 coin bas-gauche (CORNER_LEFT_LOWER) — jamais     |
//|           chevauché avec panel1 quelle que soit la hauteur chart  |
//|   v5.05 : panel2 purge D2_* avant redessin — plus de chevauchement|
//|   v5.04 : multi-symbole Market Watch, panel2 décalé, fermeture   |
//|           immédiate sur spike en gain, notif pré-spike mobile     |
//|   v5.03 : bridge TradingView /spike-tv-state (OB, EMA, sniper 80%%) |
//|   v5.07 : mode synth Boom/Crash — détection corps bougie + bypass filtres |
//|           TV spike entry, seuils abaissés, SMC/TV désactivés par défaut   |
//|   v5.08 : intégration stratégies Deriv EA Pro — EMA crossover, S&R        |
//|           breakout, range trading, RSI divergence, pattern 1-2-3          |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "5.08"
#property strict

#include <Trade/Trade.mqh>
#include <SpikeRider_SMC.mqh>

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
input group "=== GESTION DU RISQUE ==="
input double InpFixedLot         = 0.0;   // 0 = lot MIN broker | >0 = lot fixe (>= min)
input double InpMaxDailyLossPct  = 5.0;   // Arrêt journalier si perte > X% solde

input group "=== DÉTECTION SPIKE ==="
input ENUM_TIMEFRAMES InpTF      = PERIOD_M1;  // Timeframe analyse
input int    InpLookback         = 20;          // Bougies historique pour Z-Score (réduit pour réactivité)
input double InpZScoreMin        = 1.2;         // Z-Score minimum (forex / général)
input double InpSynthZScoreMin   = 0.9;         // Z-Score min Boom/Crash (corps bougie)
input double InpMinMoveMult      = 1.35;        // Mouvement min = X × moyenne corps
input double InpSynthBodyAtrMult = 0.32;        // Corps live >= X×ATR = spike synthétique
input int    InpRSIPeriod        = 14;          // Période RSI
input double InpRSIBoomMax       = 55.0;        // RSI max Boom — élargi (spikes arrivent souvent de RSI neutre)
input double InpRSICrashMin      = 45.0;        // RSI min Crash — élargi
input bool   InpRequireRSI       = false;       // RSI désactivé — bloquait 80% des spikes valides
input int    InpStairBars        = 3;           // Escalier réduit à 3 bougies (plus sensible)
input double InpStairMinPct      = 0.0;         // Escalier désactivé comme filtre bloquant

input group "=== PRÉ-SPIKE (désactivé v5 — setup SMC obligatoire) ==="
input bool   InpPreSpikeEnabled  = false;       // OFF synth — entrée sur spike détecté uniquement
input bool   InpPreSpikeUseMarket= true;        // true = marché (recommandé Boom/Crash)
input int    InpSpikeFrequency   = 0;           // 0 = auto depuis nom symbole (ex. Boom 600 → 600)
input double InpImminenceThresh  = 15.0;        // Seuil imminence (pré-spike si activé)
input bool   InpRequirePriorFavorable = false;  // false = prior informatif seulement (ne bloque pas)
input double InpPendingOffsetATR = 0.2;         // Offset pending = X×ATR au-dessus ask (Boom)
input int    InpPendingMaxAgeSec = 60;          // Durée pending réduite (spike = rapide)
input double InpAtrCompressRatio = 0.80;        // Seuil compression élargi

input group "=== STAIR-ONLY ENTRY (sans spike Z) ==="
input bool   InpEnableStairOnlyEntry = false;   // Désactivé — trop de faux signaux sans Z
input double InpStairOnlyMinPct      = 0.67;    // Stair min si réactivé
input bool   InpStairOnlyNeedImminence = false; // Sans imminence si stair-only réactivé

input group "=== STRATÉGIES DERIV EA PRO ==="
input bool   InpEnableEMACross       = true;    // Entrée E : croisement EMA 5/20
input bool   InpEnableSRBreakout     = true;    // Entrée F : cassure S/R dynamique (50 bougies)
input bool   InpEnableRangeTrading   = false;   // Entrée G : range trading (buy bas / sell haut)
input bool   InpEnableRSIDivergence  = true;    // Entrée H : divergence RSI (retournement)
input bool   InpEnablePattern123     = true;    // Entrée I : pattern 1-2-3 (swing pivots)
input int    InpEMAEntryFast         = 5;       // EMA rapide pour croisement (défaut: 5)
input int    InpEMAEntrySlow         = 20;      // EMA lente pour croisement (défaut: 20)
input int    InpSRLookbackBars       = 50;      // Fenêtre S/R dynamique (bougies)
input double InpSRBreakoutATRMult    = 0.5;     // Seuil cassure = X×ATR au-dessus S/R
input double InpRangeZonePct         = 0.15;    // Zone extrême range = 15% de l'amplitude
input int    InpDivLookback          = 20;      // Fenêtre analyse divergence RSI (bougies)
input int    InpPattern123Lookback   = 30;      // Fenêtre pattern 1-2-3 (bougies)

input group "=== SMC SPIKE (BOS / CHOCH / OTE) ==="
input bool   InpRequireSMC       = false;       // OFF par défaut sur Boom/Crash (spike = signal)
input bool   InpRequireBOS       = false;       // BOS non requis sur synthétiques
input bool   InpRequireCHOCH     = false;       // CHOCH requis (sinon BOS OU CHOCH)
input bool   InpRequireOTE       = false;       // OTE non requis — spike direct
input int    InpSwingLookback    = 40;         // Lookback pivots swing / Fib
input bool   InpDrawSMCLevels    = true;        // Afficher Fib + OTE sur graphique

input group "=== GESTION DE POSITION ==="
input int    InpATRPeriod        = 14;          // Période ATR
input double InpSL_ATR           = 1.0;         // SL = 1×ATR
input double InpTP_ATR           = 2.0;         // TP = 2×ATR
input bool   InpUseChartStops    = true;        // true = TOUJOURS placer SL/TP broker
input bool   InpUseTrailing      = false;       // false = pas de modify SL (Invalid stops)
input double InpTrailActivation  = 0.5;         // Trailing activé dès 0.5×ATR de profit
input double InpTrailStep        = 0.5;         // Pas trailing >= distance broker
input int    InpCooldownSec      = 8;           // Cooldown court — spikes rapprochés

input group "=== SERVEUR AI ==="
input bool   InpUsePrior         = true;                         // Activer prior horaire
input string InpAIServerURL      = "http://127.0.0.1:8000";      // URL du serveur AI
input int    InpPriorTimeoutMs   = 2000;                         // Timeout requête HTTP (ms)
input bool   InpUseAngelOfSpike  = false;       // Désactivé — Angel=HOLD bloquait toutes les entrées
input bool   InpUseZonePrior     = false;       // Désactivé — ZonePrior=0 bloquait toutes les entrées
input bool   InpUseRealtimeCross = true;                         // Consulter /spike/realtime cross-chart
input bool   InpSendFeedback     = true;                         // Envoyer résultat trade /trades/feedback
input bool   InpSendStairDetect  = false;       // Désactivé — réduit les WebRequests
input bool   InpSendInfluence    = false;       // Désactivé — réduit les WebRequests

input group "=== FILTRES TENDANCE / CONFIRMATION ==="
input bool   InpRequireTrendAlign   = false;     // OFF Boom/Crash — spike = contre-tendance
input int    InpTrendBars           = 6;         // Bougies pour mesurer la poussée récente
input double InpTrendStrongATR      = 0.28;     // Corps cumulés >= X×ATR = tendance opposée
input int    InpConfirmBars         = 0;         // 0 = pas de confirmation bougies fermées
input bool   InpPreSpikeNeedConfirm = false;     // Pas de confirm sur pré-spike
input int    InpEMAFast             = 9;         // EMA rapide (structure)
input int    InpEMASlow             = 21;        // EMA lente (structure)
input bool   InpRequireM1PushAlign  = false;     // OFF — Boom spike en poussée baissière M1

input group "=== BRIDGE TRADINGVIEW (SpikeRider) ==="
input bool   InpUseTVBridge         = true;      // Poll /spike-tv-state (comme TradeManager/GOM)
input int    InpTVBridgePollSec     = 2;         // Intervalle poll TV (sec)
input int    InpTVBridgeMaxAgeSec   = 20;        // Données TV expirées → pas d'entrée sniper
input bool   InpRequireTVSniper     = false;     // true = entrées UNIQUEMENT si sniper TV >= seuil
input double InpSniperMinConfidence = 80.0;      // Confiance min sniper (%%) — spike imminent
input bool   InpBlockCounterTrendTV = false;     // OFF — M15 bearish normal sur Boom
input bool   InpBlockCorrectionZone = false;     // OFF — spike = correction par nature

input group "=== CONFIRMATION TRADINGVIEW (via ai_server) ==="
input bool   InpUseTVConfirm        = false;     // OFF — ne bloque pas les spikes synth
input int    InpTVConfirmIntervalSec= 45;        // Refresh max (évite spam WebRequest)
input int    InpTVConfirmMaxAgeSec  = 120;       // Biais TV trop vieux → refus entrée

input group "=== SORTIE RAPIDE (anti micro-pertes) ==="
input bool   InpUseQuickExit        = true;      // Sortie rapide activée
input int    InpMinHoldSec           = 5;         // Durée min avant toute sortie (réduit: spike dure 2-5s)
input double InpQuickExitMinProfitUSD= 0.05;    // Profit min $ avant sortie (abaissé pour capturer le spike)
input double InpQuickExitMinProfitBoom600= 0.10; // Profit min $ sur Boom 600 (abaissé)
input bool   InpExitOnSameSpikeBar  = false;     // false = ne pas fermer sur le spike d'entrée

input group "=== FILTRES ==="
input bool   InpCheckNewBar      = false;       // DÉSACTIVÉ — entrée immédiate sur spike live
input int    InpMaxSpreadPoints  = 500;         // Spread élargi (synthétiques ont spreads larges)

input group "=== FILTRE GLOBAL TF ==="
input bool   InpRequireGlobalDir    = false;  // OFF — TF global bloquait les BUY Boom
input int    InpGlobalMinConfidence = 70;     // Confiance TF global minimale (%)
input double InpGlobalMinCoherence  = 60.0;  // Cohérence signal minimale (%)
input double InpOTEBypassZScore     = 2.0;   // Z fort → bypass OTE (si SMC réactivé)

input group "=== SPIKE SCALP IMMÉDIAT ==="
input bool   InpUseImmediateScalp = true;   // Entrée immédiate sur spike Z (même DetectSpike)
input double InpScalpZScore       = 0.9;   // Aligné InpSynthZScoreMin
input int    InpScalpLookback     = 20;    // (legacy, DetectSpike utilise InpLookback)
input double InpScalpExitPips     = 5.0;   // Close après X pips profit

input group "=== AFFICHAGE ==="
input bool   InpShowDashboard    = true;
input int    InpDashPanelWidth   = 420;  // Largeur zone panel (px depuis bord droit, CORNER_RIGHT_UPPER)
input bool   InpDebug            = false;
input ulong  InpMagic            = 20260524;

//+------------------------------------------------------------------+
//| TYPES INTERNES                                                   |
//+------------------------------------------------------------------+
enum ESpikeType { SPIKE_NONE, SPIKE_BUY, SPIKE_SELL };

struct SpikeResult
{
   ESpikeType type;
   double     zScore;
   double     rsi;
   double     atr;
   double     stairScore;
};

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade      g_trade;
int         g_hATR            = INVALID_HANDLE;
int         g_hRSI            = INVALID_HANDLE;
int         g_hEMAFast        = INVALID_HANDLE;
int         g_hEMASlow        = INVALID_HANDLE;
datetime    g_lastBar         = 0;
datetime    g_lastTrade       = 0;
datetime    g_lastEntryFail   = 0;   // anti-spam après Invalid stops
datetime    g_lastEntryBarTime = 0;  // bougie d'entrée (évite sortie même spike)
bool        g_entrySlotLocked  = false; // 1 seule tentative d'ouverture / tick / symbole
double      g_dayStartBalance = 0.0;
datetime    g_dayTag          = 0;

// Compteur inter-spike
int         g_barsSinceLastSpike = 0;
datetime    g_lastSpikeBar       = 0;

// Ordre pending pré-spike
ulong       g_pendingTicket      = 0;
datetime    g_pendingPlacedAt    = 0;

// Contexte SMC (BOS / CHOCH / OTE)
SR_SMCSetup g_smc;
datetime    g_lastSMCBar         = 0;

// Prior horaire AWS RDS  (/spike/hour-prior)
double      g_priorCaptureRate   = 0.5;
double      g_priorAtrMult       = 2.5;
double      g_priorAtrThreshold  = 1.8;
bool        g_priorFavorable     = true;
int         g_priorSampleCount   = 0;
string      g_priorSource        = "init";
datetime    g_lastPriorFetch     = 0;
datetime    g_lastPriorAttempt   = 0;
int         g_lastPriorHour      = -1;

// Zone prior (/mt5/spike-zone-prior)
double      g_zonePrior          = 0.5;   // score combiné spike_rate + propice_score
double      g_zoneSpikeRate      = 0.0;
double      g_zonePropiceScore   = 0.0;
int         g_zoneSamples        = 0;
datetime    g_lastZoneFetch      = 0;
datetime    g_lastZoneAttempt    = 0;
int         g_lastZoneHour       = -1;

// Angel of Spike (/angelofspike/trend)
string      g_angelSignal        = "HOLD"; // "BUY" | "SELL" | "HOLD"
double      g_angelConfidence    = 0.0;
string      g_angelMarketState   = "";
datetime    g_lastAngelFetch     = 0;
datetime    g_lastAngelAttempt   = 0;

//+------------------------------------------------------------------+
//| SPIKE SCALP MODE v2.0                                            |
//+------------------------------------------------------------------+
struct SpikeScalpState {
   bool spikeDetected;
   int direction;
   double zscore;
   datetime detectedTime;
};

SpikeScalpState g_scalpState;
datetime g_lastScalpTrade = 0;
int         g_lastAngelHour      = -1;

// Realtime cross-chart (/spike/realtime)
bool        g_realtimeSpikeActive   = false;
string      g_realtimeSpikeDir      = "";
datetime    g_lastRealtimeFetch     = 0;

// TradingView bias (/mt5/tv-bias + /spike-tv-state)
string      g_tvDirection           = "NEUTRAL";
string      g_tvStructureM15        = "";
string      g_tvStructureH1         = "";
double      g_tvBiasScore           = 0.0;
datetime    g_lastTVFetch           = 0;
datetime    g_lastTVAttempt         = 0;

// Bridge SpikeRider — /spike-tv-state (OB, EMA, sniper)
bool        g_spikeTVOk             = false;
datetime    g_lastSpikeTVFetch      = 0;
datetime    g_lastSpikeTVAttempt    = 0;
double      g_tvImminencePct        = 0.0;
double      g_tvSniperConfidence    = 0.0;
bool        g_tvSniperReady         = false;
bool        g_tvCounterTrend        = false;
string      g_tvObBias              = "none";
string      g_tvEmaTrend            = "neutral";
string      g_tvSpikeDir            = "NEUTRAL";
bool        g_tvSpikeDetected       = false;
double      g_tvSpikeZ              = 0.0;
bool        g_tvEntryValid          = false;
// TF Global + cohérence (depuis /spike-tv-state — tf_global_dir/strength/coherence_pct)
string      g_tvGlobalDir           = "";     // "BULL" | "BEAR" | "NEUT"
int         g_tvGlobalStrength      = 0;      // 0-100 (confidence proxy)
double      g_tvCoherencePct        = 0.0;    // 0-100

// Stair detection — ID pour feedback ultérieur
string      g_lastStairEventId      = "";   // uuid retourné par /stair/detect
string      g_lastStairClientId     = "";   // client_event_id généré par l'EA

// Suivi positions pour feedback
struct TradeRecord
{
   ulong    ticket;
   ESpikeType spikeType;
   double   entryPrice;
   datetime openTime;
   double   imminenceAtEntry;
   double   zScoreAtEntry;
   double   rsiAtEntry;
   double   stairAtEntry;
   double   zonePriorAtEntry;
   double   angelConfAtEntry;
   string   stairEventId;
   string   stairClientId;
};
TradeRecord g_openTrades[10];
int         g_openTradesCount = 0;

// ══ MULTI-SYMBOLE — scan tous les Boom/Crash du Market Watch ════
struct SymbolCtx
{
   string      sym;
   bool        isBoom;
   int         hATR, hRSI, hEMAFast, hEMASlow;
   int         barsSince;
   datetime    lastBar;
   datetime    lastTrade;
   datetime    lastEntryFail;
   datetime    lastEntryBarTime;
   SR_SMCSetup smc;
};
SymbolCtx g_syms[20];
int       g_symCount = 0;

// Anti-spam notifications pré-spike
datetime  g_lastNotifTime = 0;
double    g_lastNotifImm  = 0.0;

//+------------------------------------------------------------------+
//| DÉTECTION & NORMALISATION SYMBOLES                               |
//+------------------------------------------------------------------+
bool IsBoom(const string s)
{
   return StringFind(s,"Boom",0)>=0 || StringFind(s,"boom",0)>=0 ||
          StringFind(s,"GAIN",0)>=0 || StringFind(s,"gain",0)>=0;
}
bool IsCrash(const string s)
{
   return StringFind(s,"Crash",0)>=0 || StringFind(s,"crash",0)>=0 ||
          StringFind(s,"PAIN",0)>=0  || StringFind(s,"pain",0)>=0;
}
bool IsSupportedSymbol(const string s) { return IsBoom(s) || IsCrash(s); }

// Normalise symbole MT5 pour URL queries vers AI server
// MT5: "Boom 500 Index" → URL: "Boom%20500%20Index" ou API: "Boom500Index"
string NormalizeSymbolForURL(const string mtSymbol)
{
   string normalized = mtSymbol;
   StringReplace(normalized, " ", "%20");  // URL encoding for spaces
   return normalized;
}

// Alternative: encode sans espaces pour canonicité API
string NormalizeSymbolForAPI(const string mtSymbol)
{
   string normalized = mtSymbol;
   StringReplace(normalized, " ", "");  // Remove spaces: "Boom 500 Index" → "Boom500Index"
   return normalized;
}

// Fréquence spike : 0 = déduire du nom (Boom 600 Index → 600), sinon input manuel
int GetEffectiveSpikeFrequency()
{
   if(InpSpikeFrequency > 0) return InpSpikeFrequency;
   const string nums[] = {"1000","900","600","500","300"};
   for(int i = 0; i < ArraySize(nums); i++)
      if(StringFind(_Symbol, nums[i]) >= 0)
         return (int)StringToInteger(nums[i]);
   return 600;
}

//+------------------------------------------------------------------+
//| LECTURE ATR / RSI                                                |
//+------------------------------------------------------------------+
double GetATR()
{
   if(g_hATR == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_hATR, 0, 0, 3, buf) < 3) return 0.0;
   return buf[1];
}
double GetRSI()
{
   if(g_hRSI == INVALID_HANDLE) return 50.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_hRSI, 0, 0, 3, buf) < 3) return 50.0;
   return buf[1];
}

// Somme des corps des N dernières bougies fermées (shift 1+)
double GetRecentBodySum(const int bars, const int shiftStart = 1)
{
   if(bars <= 0) return 0.0;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpTF, shiftStart, bars, r) < bars) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < bars; i++)
      sum += r[i].close - r[i].open;
   return sum;
}

// +1 poussée haussière, -1 baissière, 0 neutre
int GetMicroTrendPush(const int bars)
{
   double atr = GetATR();
   if(atr <= 0.0) return 0;
   double sum = GetRecentBodySum(bars, 1);
   if(sum >= atr * InpTrendStrongATR) return 1;
   if(sum <= -atr * InpTrendStrongATR) return -1;
   return 0;
}

bool IsSynthIndex()
{
   return IsBoom(_Symbol) || IsCrash(_Symbol);
}

// Spike Z confirmé sur Boom/Crash : toute bougie spike validée bypass les filtres forex/TV
bool IsSynthSpikeConfirmed(const SpikeResult &spike, const bool isPreSpike)
{
   if(!IsSynthIndex() || isPreSpike) return false;
   if(spike.type != SPIKE_NONE) return true;
   return (spike.zScore >= InpSynthZScoreMin);
}

bool IsSynthSpikeStrong(const SpikeResult &spike)
{
   if(!IsSynthIndex()) return false;
   return (spike.zScore >= InpOTEBypassZScore);
}

bool HasDirectionConfirmation(const ESpikeType dir)
{
   if(InpConfirmBars <= 0) return true;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpTF, 1, InpConfirmBars, r) < InpConfirmBars) return false;
   int ok = 0;
   for(int i = 0; i < InpConfirmBars; i++)
   {
      double body = r[i].close - r[i].open;
      if(dir == SPIKE_BUY  && body > 0.0) ok++;
      if(dir == SPIKE_SELL && body < 0.0) ok++;
   }
   return (ok >= InpConfirmBars);
}

bool IsStrongCounterTrend(const ESpikeType dir)
{
   if(!InpRequireTrendAlign) return false;
   int push = GetMicroTrendPush(InpTrendBars);
   if(dir == SPIKE_BUY  && push < 0) return true;
   if(dir == SPIKE_SELL && push > 0) return true;

   double ef[], es[];
   if(g_hEMAFast != INVALID_HANDLE && g_hEMASlow != INVALID_HANDLE &&
      CopyBuffer(g_hEMAFast, 0, 1, 1, ef) >= 1 && CopyBuffer(g_hEMASlow, 0, 1, 1, es) >= 1)
   {
      MqlRates c[];
      if(CopyRates(_Symbol, InpTF, 1, 1, c) >= 1)
      {
         if(dir == SPIKE_BUY  && ef[0] < es[0] && c[0].close < es[0] && push <= 0) return true;
         if(dir == SPIKE_SELL && ef[0] > es[0] && c[0].close > es[0] && push >= 0) return true;
      }
   }
   return false;
}

void UpdateSMCContext()
{
   double px = IsBoom(_Symbol) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   SR_BuildSMCSetup(_Symbol, InpTF, IsBoom(_Symbol), px, InpSwingLookback, g_smc);
}

bool IsSpikeCorrectionZone(const ESpikeType dir)
{
   if(!InpBlockCorrectionZone) return false;

   if(InpUseTVBridge && g_spikeTVOk && g_tvCounterTrend)
      return true;

   int push = GetMicroTrendPush(InpTrendBars);
   if(dir == SPIKE_BUY && push < 0) return true;
   if(dir == SPIKE_SELL && push > 0) return true;

   if(g_spikeTVOk && StringLen(g_tvGlobalDir) > 0 && g_tvGlobalStrength >= 50)
   {
      bool globalBull = (StringCompare(g_tvGlobalDir, "BULL") == 0);
      bool globalBear = (StringCompare(g_tvGlobalDir, "BEAR") == 0);
      if(dir == SPIKE_BUY && globalBear) return true;
      if(dir == SPIKE_SELL && globalBull) return true;
   }

   double c1 = iClose(_Symbol, PERIOD_M1, 0);
   double c3 = iClose(_Symbol, PERIOD_M1, 3);
   double cH1 = iClose(_Symbol, PERIOD_H1, 0);
   double cH3 = iClose(_Symbol, PERIOD_H1, 3);
   if(dir == SPIKE_BUY && c1 < c3 && cH1 > cH3) return true;
   if(dir == SPIKE_SELL && c1 > c3 && cH1 < cH3) return true;

   return false;
}

bool CanEnterInDirection(const ESpikeType dir, const bool isPreSpike,
                         const SpikeResult &spike, string &reason)
{
   reason = "";
   if(IsBoom(_Symbol)  && dir != SPIKE_BUY)  { reason = "Boom → BUY uniquement"; return false; }
   if(IsCrash(_Symbol) && dir != SPIKE_SELL) { reason = "Crash → SELL uniquement"; return false; }

   const bool synthSpike = IsSynthSpikeConfirmed(spike, isPreSpike);

   if(!synthSpike && IsSpikeCorrectionZone(dir))
   {
      reason = "zone correction — spike évité (M1 vs H1 / TV contre-tendance)";
      return false;
   }

   if(isPreSpike && !InpPreSpikeEnabled)
   {
      reason = "pré-spike désactivé";
      return false;
   }

   if(!synthSpike && IsStrongCounterTrend(dir))
   {
      reason = StringFormat("tendance opposée (%d bar, push=%d)", InpTrendBars, GetMicroTrendPush(InpTrendBars));
      return false;
   }

   if(!synthSpike && InpRequireM1PushAlign && IsBoom(_Symbol) && dir == SPIKE_BUY)
   {
      int push = GetMicroTrendPush(InpTrendBars);
      if(push < 0)
      {
         reason = StringFormat("M1 en poussée baissière (push=%d) — pas de BUY", push);
         return false;
      }
   }

   if(!synthSpike && InpRequireM1PushAlign && IsCrash(_Symbol) && dir == SPIKE_SELL)
   {
      int push = GetMicroTrendPush(InpTrendBars);
      if(push > 0)
      {
         reason = StringFormat("M1 en poussée haussière (push=%d) — pas de SELL", push);
         return false;
      }
   }

   // Bloquer si TV indique contre-tendance (données fraîches uniquement)
   bool tvSaysCounterTrend = InpUseTVBridge && g_spikeTVOk && g_tvCounterTrend;
   bool tvDataFresh = InpUseTVBridge && g_spikeTVOk &&
                      (TimeCurrent() - g_lastSpikeTVFetch <= 120);

   if(!synthSpike && InpBlockCounterTrendTV && tvDataFresh)
   {
      if(tvSaysCounterTrend)
      {
         reason = StringFormat("TV contre-tendance (CT=true | M15=%s H1=%s)",
                               g_tvStructureM15, g_tvStructureH1);
         return false;
      }
      if(dir == SPIKE_BUY && g_tvStructureM15 == "bearish")
      {
         reason = StringFormat("TV M15 bearish bloque BUY | OB=%s EMA=%s",
                               g_tvObBias, g_tvEmaTrend);
         return false;
      }
      if(dir == SPIKE_SELL && g_tvStructureM15 == "bullish")
      {
         reason = StringFormat("TV M15 bullish bloque SELL | OB=%s EMA=%s",
                               g_tvObBias, g_tvEmaTrend);
         return false;
      }
   }

   if(InpUseTVBridge && InpRequireTVSniper)
   {
      string snWhy;
      if(!TVSniperAllowsEntry(dir, snWhy))
      {
         reason = snWhy;
         return false;
      }
   }

   if(InpUseTVConfirm && !synthSpike)
   {
      string tvWhy;
      if(!TVChartConfirmsEntry(dir, tvWhy))
      {
         reason = tvWhy;
         return false;
      }
   }

   if(!isPreSpike && (spike.type == SPIKE_NONE || spike.type != dir))
   {
      reason = "spike non confirmé dans le sens";
      return false;
   }

   if(!synthSpike && InpPreSpikeNeedConfirm && !HasDirectionConfirmation(dir) &&
      spike.zScore < InpZScoreMin + 0.75)
   {
      reason = "bougies non alignées + Z faible";
      return false;
   }

   UpdateSMCContext();
   if(InpRequireSMC && !synthSpike)
   {
      bool requireBOS = InpRequireBOS;
      bool requireOTE = InpRequireOTE;
      if(!SR_SMCAllowsEntry(g_smc, IsBoom(_Symbol), requireBOS, InpRequireCHOCH,
                            requireOTE, !isPreSpike, spike.zScore, InpZScoreMin, reason))
         return false;
   }

   // Filtre TF global + cohérence — UNIQUEMENT si filtre activé ET données fraîches
   bool globalDataValid = InpRequireGlobalDir && g_spikeTVOk && tvDataFresh;

   if(globalDataValid && !synthSpike)
   {
      // 1. Cohérence minimale — bloquer si cohérence basse et détectée
      if(g_tvCoherencePct > 0 && g_tvCoherencePct < InpGlobalMinCoherence)
      {
         reason = StringFormat("Cohérence TF global %.0f%% < seuil %.0f%%",
                               g_tvCoherencePct, InpGlobalMinCoherence);
         return false;
      }

      // 2. Confiance TF global minimale
      if(g_tvGlobalStrength > 0 && g_tvGlobalStrength < InpGlobalMinConfidence)
      {
         reason = StringFormat("Confiance TF global %d%% < seuil %d%%",
                               g_tvGlobalStrength, InpGlobalMinConfidence);
         return false;
      }

      // 3. Direction TF global opposée au spike (NEUT/NEUTRAL = pas de contrainte)
      string gd = g_tvGlobalDir;
      StringToUpper(gd);
      bool isNeutral = (StringCompare(gd, "NEUT") == 0 ||
                       StringCompare(gd, "NEUTRAL") == 0);

      if(!isNeutral && g_tvGlobalStrength > 0)
      {
         bool globalBull = (StringCompare(gd, "BULL") == 0);
         bool globalBear = (StringCompare(gd, "BEAR") == 0);

         if(dir == SPIKE_BUY && !globalBull)
         {
            reason = StringFormat("TF global=%s force=%d%% (contre BUY)",
                                  gd, g_tvGlobalStrength);
            return false;
         }
         if(dir == SPIKE_SELL && !globalBear)
         {
            reason = StringFormat("TF global=%s force=%d%% (contre SELL)",
                                  gd, g_tvGlobalStrength);
            return false;
         }
      }
   }

   reason = StringFormat("✓ %s | Z=%.2f | stair=%.0f%% | %s | TV[%s CT=%s sniper=%s] | Global=%s(%d%%) Coh=%.0f%%",
                        (dir == SPIKE_BUY ? "BUY" : "SELL"),
                        spike.zScore, spike.stairScore * 100.0, g_smc.tag,
                        (g_spikeTVOk ? "OK" : "OFF"),
                        (g_tvCounterTrend ? "BLOQUE" : "ok"),
                        (g_tvSniperReady ? "ready" : "---"),
                        g_tvGlobalDir, g_tvGlobalStrength, g_tvCoherencePct);
   return true;
}
double GetATRMean()
{
   if(g_hATR == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   int n = InpLookback + 2;
   if(CopyBuffer(g_hATR, 0, 0, n, buf) < n) return 0.0;
   double sum = 0.0;
   for(int i = 1; i <= InpLookback; i++) sum += buf[i];
   return sum / InpLookback;
}

//+------------------------------------------------------------------+
//| UUID simple (timestamp + pseudo-random suffix)                   |
//+------------------------------------------------------------------+
string GenerateClientEventId()
{
   MathSrand((int)(TimeCurrent() * 1000 + MathRand()));
   return StringFormat("sr_%d_%04x%04x",
                       (int)TimeCurrent(), MathRand(), MathRand());
}

//+------------------------------------------------------------------+
//| JSON HELPERS                                                     |
//+------------------------------------------------------------------+
double JsonExtractDouble(const string &body, const string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(body, search);
   if(pos < 0) return -1.0;
   pos += StringLen(search);
   while(pos < StringLen(body) && StringGetCharacter(body, pos) == ' ') pos++;
   string sub = StringSubstr(body, pos, 24);
   int end = 0;
   while(end < StringLen(sub))
   {
      ushort c = StringGetCharacter(sub, end);
      if(c == ',' || c == '}' || c == ' ' || c == '\n' || c == '\r') break;
      end++;
   }
   return StringToDouble(StringSubstr(sub, 0, end));
}
bool JsonExtractBool(const string &body, const string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(body, search);
   if(pos < 0) return false;  // Défaut: false si clé absente (au lieu de true)
   pos += StringLen(search);
   while(pos < StringLen(body) && StringGetCharacter(body, pos) == ' ') pos++;
   ushort c = StringGetCharacter(body, pos);
   if(c == 't') return true;   // "true"
   if(c == 'f') return false;  // "false"
   return false;  // Défaut: false pour les valeurs invalides
}
string JsonExtractString(const string &body, const string key)
{
   string search = "\"" + key + "\":\"";
   int pos = StringFind(body, search);
   if(pos < 0) return "";
   pos += StringLen(search);
   int end = StringFind(body, "\"", pos);
   if(end < 0) return "";
   return StringSubstr(body, pos, end - pos);
}

//+------------------------------------------------------------------+
//| HTTP POST helper (fire-and-forget, pas de lecture réponse)       |
//+------------------------------------------------------------------+
bool HttpPost(const string url, const string jsonBody)
{
   char   postData[];
   char   result[];
   string headers = "Content-Type: application/json\r\n";
   string respH;
   StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody));
   ArrayResize(postData, StringLen(jsonBody));  // sans \0 final
   int code = WebRequest("POST", url, headers, InpPriorTimeoutMs, postData, result, respH);
   if(InpDebug)
      PrintFormat("[SpikeRider][HTTP] POST %s -> code=%d body=%s",
                  url, code, StringSubstr(jsonBody, 0, 120));
   return (code >= 200 && code < 300);
}

bool HttpGet(const string url, string &bodyOut)
{
   char   postData[];
   char   result[];
   string headers = "Content-Type: application/json\r\n";
   string respH;
   int code = WebRequest("GET", url, headers, InpPriorTimeoutMs, postData, result, respH);
   if(code != 200)
   {
      if(InpDebug) PrintFormat("[SpikeRider][HTTP] GET %s -> code=%d", url, code);
      return false;
   }
   bodyOut = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   return true;
}

//+------------------------------------------------------------------+
//| TradingView — /mt5/tv-bias (MCP Kola via ai_server)              |
//+------------------------------------------------------------------+
bool FetchTVChartBias(const bool forceRefresh = false)
{
   if(!InpUseTVConfirm) return true;
   if(!forceRefresh && g_lastTVFetch != 0 &&
      TimeCurrent() - g_lastTVFetch < InpTVConfirmIntervalSec)
      return (g_tvDirection != "" && g_tvDirection != "UNKNOWN");

   if(g_lastTVAttempt != 0 && TimeCurrent() - g_lastTVAttempt < 15)
      return (g_lastTVFetch != 0);
   g_lastTVAttempt = TimeCurrent();

   string sym_enc = NormalizeSymbolForURL(_Symbol);
   string url = InpAIServerURL + "/mt5/tv-bias?symbol=" + sym_enc;
   if(forceRefresh) url += "&refresh=true";

   string body;
   if(!HttpGet(url, body))
   {
      PrintFormat("[SpikeRider] ⚠️ TV bias indisponible (ai_server / CDP?)");
      return false;
   }

   bool ok = JsonExtractBool(body, "ok");
   string dir = JsonExtractString(body, "direction");
   if(StringLen(dir) > 0) g_tvDirection = dir;
   string m15 = JsonExtractString(body, "structure_m15");
   string h1  = JsonExtractString(body, "structure_h1");
   if(StringLen(m15) > 0) g_tvStructureM15 = m15;
   if(StringLen(h1) > 0)  g_tvStructureH1  = h1;
   g_tvBiasScore = JsonExtractDouble(body, "bias_score");
   g_lastTVFetch = TimeCurrent();

   if(ok)
      PrintFormat("[SpikeRider] TV: %s | M15=%s H1=%s score=%.0f",
                  g_tvDirection, g_tvStructureM15, g_tvStructureH1, g_tvBiasScore);
   return ok;
}

bool TVChartConfirmsEntry(const ESpikeType dir, string &reason)
{
   if(!InpUseTVConfirm) return true;

   if(g_lastTVFetch == 0 || TimeCurrent() - g_lastTVFetch > InpTVConfirmMaxAgeSec)
   {
      if(!FetchTVChartBias(true))
      {
         // Fail-open : si TV indisponible, ne pas bloquer — laisser passer
         reason = "TV indisponible — entrée autorisée sans confirmation TV";
         return true;
      }
   }

   string tv = g_tvDirection;
   StringToUpper(tv);

   if(dir == SPIKE_BUY)
   {
      if(tv == "SELL")
      {
         reason = "TV oppose: direction SELL (M15/H1 bearish)";
         return false;
      }
      if(g_tvStructureM15 == "bearish" || g_tvStructureH1 == "bearish")
      {
         reason = "TV downtrend M15=" + g_tvStructureM15 + " H1=" + g_tvStructureH1
                  + " - pas de BUY Boom";
         return false;
      }
      if(tv == "NEUTRAL" && g_tvBiasScore < 0.0)
      {
         reason = "TV neutre mais score biais négatif";
         return false;
      }
   }
   else if(dir == SPIKE_SELL)
   {
      if(tv == "BUY")
      {
         reason = "TV oppose: direction BUY";
         return false;
      }
      if(g_tvStructureM15 == "bullish" || g_tvStructureH1 == "bullish")
      {
         reason = "TV uptrend M15=" + g_tvStructureM15 + " H1=" + g_tvStructureH1
                  + " - pas de SELL Crash";
         return false;
      }
   }

   reason = "TV OK " + tv + " | M15=" + g_tvStructureM15 + " H1=" + g_tvStructureH1;
   return true;
}

//+------------------------------------------------------------------+
//| Bridge TradingView — /spike-tv-state (SpikeRider + TradeManager)  |
//+------------------------------------------------------------------+
bool PollSpikeTVState(const bool forceRefresh = false)
{
   if(!InpUseTVBridge) return true;

   if(!forceRefresh && g_lastSpikeTVFetch != 0 &&
      TimeCurrent() - g_lastSpikeTVFetch < InpTVBridgePollSec)
      return g_spikeTVOk;

   if(g_lastSpikeTVAttempt != 0 && TimeCurrent() - g_lastSpikeTVAttempt < 1)
      return g_spikeTVOk;
   g_lastSpikeTVAttempt = TimeCurrent();

   string sym_enc = NormalizeSymbolForURL(_Symbol);
   string url = InpAIServerURL + "/spike-tv-state?symbol=" + sym_enc;
   if(forceRefresh) url += "&refresh=true";

   string body;
   if(!HttpGet(url, body))
   {
      if(InpDebug) Print("[SpikeRider] ⚠️ /spike-tv-state indisponible");
      return false;
   }

   // Parser "ok" status — verdict GOM principal
   g_spikeTVOk = JsonExtractBool(body, "ok");
   if(!g_spikeTVOk && StringFind(body, "\"ok\":true") >= 0)
      g_spikeTVOk = true;

   // Direction principale (BUY/SELL/NEUTRAL)
   string dir = JsonExtractString(body, "direction");
   if(StringLen(dir) > 0) g_tvDirection = dir;
   else g_tvDirection = "NEUTRAL";

   // Structure M15 / H1 (bullish/bearish/neutral)
   string m15 = JsonExtractString(body, "structure_m15");
   string h1  = JsonExtractString(body, "structure_h1");
   if(StringLen(m15) > 0) g_tvStructureM15 = m15;
   else g_tvStructureM15 = "neutral";
   if(StringLen(h1) > 0)  g_tvStructureH1  = h1;
   else g_tvStructureH1 = "neutral";

   // Scores imminence et confiance
   g_tvBiasScore        = JsonExtractDouble(body, "bias_score");
   g_tvImminencePct     = JsonExtractDouble(body, "imminence_pct");
   if(g_tvImminencePct < 0) g_tvImminencePct = 0;
   if(g_tvImminencePct > 100) g_tvImminencePct = 100;

   g_tvSniperConfidence = JsonExtractDouble(body, "sniper_confidence");
   if(g_tvSniperConfidence < 0) g_tvSniperConfidence = 0;
   if(g_tvSniperConfidence > 100) g_tvSniperConfidence = 100;

   // Flags booléens — verdicts GOM cruciaux
   g_tvSniperReady      = JsonExtractBool(body, "sniper_ready");
   g_tvCounterTrend     = JsonExtractBool(body, "counter_trend");  // ← VERDICT GOM
   g_tvSpikeDetected    = JsonExtractBool(body, "spike_detected");
   g_tvEntryValid       = JsonExtractBool(body, "entry_valid");

   // Biases et tendances (OB = Order Block, EMA = trend)
   string ob = JsonExtractString(body, "ob_bias");
   if(StringLen(ob) > 0) g_tvObBias = ob;
   else g_tvObBias = "none";

   string emaTr = JsonExtractString(body, "ema_trend");
   if(StringLen(emaTr) > 0) g_tvEmaTrend = emaTr;
   else g_tvEmaTrend = "neutral";

   string spDir = JsonExtractString(body, "spike_direction");
   if(StringLen(spDir) > 0) g_tvSpikeDir = spDir;
   else g_tvSpikeDir = "NEUTRAL";

   // Z-score du spike TV
   double z = JsonExtractDouble(body, "spike_z");
   if(z >= 0) g_tvSpikeZ = z;
   else g_tvSpikeZ = 0;

   // TF Global + cohérence — filtres direction haut niveau
   string gDir = JsonExtractString(body, "tf_global_dir");
   if(StringLen(gDir) > 0) { g_tvGlobalDir = gDir; StringToUpper(g_tvGlobalDir); }
   else g_tvGlobalDir = "NEUT";

   double gStr = JsonExtractDouble(body, "tf_global_strength");
   if(gStr > 0) g_tvGlobalStrength = (int)gStr;
   else g_tvGlobalStrength = 0;

   double coh = JsonExtractDouble(body, "coherence_pct");
   if(coh > 0) g_tvCoherencePct = coh;
   else g_tvCoherencePct = 0;

   g_lastSpikeTVFetch = TimeCurrent();
   g_lastTVFetch      = TimeCurrent();

   if(InpDebug || forceRefresh)
      PrintFormat("[SpikeRider] GOM-Bridge %s | "
                  "verdict_CT=%s | sniper=%s %.0f%% | imm=%.0f%% | "
                  "spike=%s Z=%.2f | dir=%s | "
                  "struct=[M15=%s H1=%s] OB=%s EMA=%s | "
                  "global=%s[%d%%] coh=%.0f%%",
                  _Symbol,
                  (g_tvCounterTrend ? "BLOQUE" : "ok"),
                  (g_tvSniperReady ? "READY" : "wait"), g_tvSniperConfidence,
                  g_tvImminencePct,
                  (g_tvSpikeDetected ? g_tvSpikeDir : "---"), g_tvSpikeZ,
                  g_tvDirection,
                  g_tvStructureM15, g_tvStructureH1, g_tvObBias, g_tvEmaTrend,
                  g_tvGlobalDir, g_tvGlobalStrength, g_tvCoherencePct);

   return g_spikeTVOk;
}

bool TVSniperAllowsEntry(const ESpikeType dir, string &reason)
{
   if(!InpRequireTVSniper) return true;

   // Récupérer les données TV fraîches si nécessaire
   if(g_lastSpikeTVFetch == 0 || TimeCurrent() - g_lastSpikeTVFetch > InpTVBridgeMaxAgeSec)
   {
      if(!PollSpikeTVState(true))
      {
         reason = "TV sniper: pas de données (ai_server indisponible)";
         return false;
      }
   }

   // Vérifier que les données ne sont pas trop vieilles (staleness check)
   if(TimeCurrent() - g_lastSpikeTVFetch > InpTVBridgeMaxAgeSec)
   {
      reason = StringFormat("TV sniper: données expirées (%.0fs > %.0fs)",
                            (double)(TimeCurrent() - g_lastSpikeTVFetch),
                            (double)InpTVBridgeMaxAgeSec);
      return false;
   }

   // Bloc 1: contre-tendance explicite du verdict GOM
   if(g_tvCounterTrend)
   {
      reason = StringFormat("TV VERDICT: contre-tendance détecté (EMA=%s OB=%s CT=true)",
                            g_tvEmaTrend, g_tvObBias);
      return false;
   }

   // Bloc 2: direction symbole vs EA (Boom=BUY, Crash=SELL)
   ESpikeType want = IsBoom(_Symbol) ? SPIKE_BUY : SPIKE_SELL;
   if(dir != want)
   {
      reason = "Symbole incompatible (Boom→BUY, Crash→SELL)";
      return false;
   }

   // Bloc 3: confiance sniper insuffisante
   if(!g_tvSniperReady || g_tvSniperConfidence < InpSniperMinConfidence)
   {
      reason = StringFormat("Sniper TV %.0f%% < seuil %.0f%% (imm=%.0f%% spike=%s ready=%s)",
                            g_tvSniperConfidence, InpSniperMinConfidence,
                            g_tvImminencePct, (g_tvSpikeDetected ? g_tvSpikeDir : "---"),
                            (g_tvSniperReady ? "oui" : "non"));
      return false;
   }

   // Bloc 4: direction spike TV vs symbole
   if(IsBoom(_Symbol) && StringCompare(g_tvSpikeDir, "SELL") == 0)
   {
      reason = "TV spike SELL incompatible avec Boom (BUY)";
      return false;
   }
   if(IsCrash(_Symbol) && StringCompare(g_tvSpikeDir, "BUY") == 0)
   {
      reason = "TV spike BUY incompatible avec Crash (SELL)";
      return false;
   }

   reason = StringFormat("SNIPER TV OK %.0f%% | imm=%.0f%% | Z=%.2f | OB=%s | CT=%s",
                         g_tvSniperConfidence, g_tvImminencePct, g_tvSpikeZ,
                         g_tvObBias, (g_tvCounterTrend ? "bloque" : "ok"));
   return true;
}

//+------------------------------------------------------------------+
//| 1. PRIOR HORAIRE : /spike/hour-prior                            |
//+------------------------------------------------------------------+
void FetchHourlyPrior()
{
   if(!InpUsePrior) return;
   MqlDateTime utc; TimeToStruct(TimeGMT(), utc);
   int hourNow = utc.hour;
   if(hourNow == g_lastPriorHour && g_lastPriorFetch != 0) return;
   if(g_lastPriorAttempt != 0 && TimeCurrent() - g_lastPriorAttempt < 60) return;
   g_lastPriorAttempt = TimeCurrent();

   string url = InpAIServerURL + "/spike/hour-prior?symbol=" + _Symbol;
   string headers = "Content-Type: application/json\r\n";
   char post[], result[]; string respH;
   int code = WebRequest("GET", url, headers, InpPriorTimeoutMs, post, result, respH);
   if(code != 200)
   {
      PrintFormat("[SpikeRider] ⚠️ hour-prior code=%d | %s", code, url);
      return;
   }
   string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   double cr = JsonExtractDouble(body, "capture_rate");
   double am = JsonExtractDouble(body, "avg_atr_mult");
   double at = JsonExtractDouble(body, "atr_threshold");
   double sc = JsonExtractDouble(body, "sample_count");
   bool   fav = JsonExtractBool(body,  "favorable");
   string src = JsonExtractString(body,"source");
   if(cr  > 0.0) g_priorCaptureRate  = cr;
   if(am  > 0.0) g_priorAtrMult      = am;
   if(at  > 0.0) g_priorAtrThreshold = at;
   if(sc >= 0.0) g_priorSampleCount  = (int)sc;
   g_priorFavorable = fav;
   g_priorSource    = (StringLen(src)>0) ? src : "unknown";
   g_lastPriorFetch = TimeCurrent();
   g_lastPriorHour  = hourNow;
   PrintFormat("[SpikeRider] Prior %02d:00UTC capture=%.0f%% avg_atr=%.2f thresh=%.2f n=%d fav=%s [%s]",
               hourNow, g_priorCaptureRate*100, g_priorAtrMult, g_priorAtrThreshold,
               g_priorSampleCount, (g_priorFavorable?"OUI":"NON"), g_priorSource);
}

//+------------------------------------------------------------------+
//| 2. ZONE PRIOR : /mt5/spike-zone-prior                           |
//+------------------------------------------------------------------+
void FetchZonePrior()
{
   if(!InpUseZonePrior) return;
   MqlDateTime utc; TimeToStruct(TimeGMT(), utc);
   int hourNow = utc.hour;
   if(hourNow == g_lastZoneHour && g_lastZoneFetch != 0) return;
   if(g_lastZoneAttempt != 0 && TimeCurrent() - g_lastZoneAttempt < 60) return;
   g_lastZoneAttempt = TimeCurrent();

   string url = InpAIServerURL + "/mt5/spike-zone-prior?symbol=" + _Symbol + "&timeframe=M1";
   string headers = "Content-Type: application/json\r\n";
   char post[], result[]; string respH;
   int code = WebRequest("GET", url, headers, InpPriorTimeoutMs, post, result, respH);
   if(code != 200)
   {
      if(InpDebug) PrintFormat("[SpikeRider] zone-prior code=%d", code);
      return;
   }
   string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   double prior = JsonExtractDouble(body, "prior");
   double sr    = JsonExtractDouble(body, "spike_rate");
   double ps    = JsonExtractDouble(body, "propice_score");
   double samp  = JsonExtractDouble(body, "samples");
   if(prior >= 0.0) g_zonePrior        = prior;
   if(sr    >= 0.0) g_zoneSpikeRate    = sr;
   if(ps    >= 0.0) g_zonePropiceScore = ps;
   if(samp  >= 0.0) g_zoneSamples      = (int)samp;
   g_lastZoneFetch = TimeCurrent();
   g_lastZoneHour  = hourNow;
   PrintFormat("[SpikeRider] ZonePrior %02d:00UTC prior=%.2f spike_rate=%.2f propice=%.2f n=%d",
               hourNow, g_zonePrior, g_zoneSpikeRate, g_zonePropiceScore, g_zoneSamples);
}

//+------------------------------------------------------------------+
//| 3. ANGEL OF SPIKE : /angelofspike/trend                         |
//+------------------------------------------------------------------+
void FetchAngelOfSpike()
{
   if(!InpUseAngelOfSpike) return;
   MqlDateTime utc; TimeToStruct(TimeGMT(), utc);
   int hourNow = utc.hour;
   // Refresh toutes les heures (même logique que prior)
   if(hourNow == g_lastAngelHour && g_lastAngelFetch != 0) return;
   if(g_lastAngelAttempt != 0 && TimeCurrent() - g_lastAngelAttempt < 60) return;
   g_lastAngelAttempt = TimeCurrent();

   string sym_enc = NormalizeSymbolForURL(_Symbol);
   string url = InpAIServerURL + "/angelofspike/trend?symbol=" + sym_enc + "&timeframe=M1";
   string headers = "Content-Type: application/json\r\n";
   char post[], result[]; string respH;
   int code = WebRequest("GET", url, headers, InpPriorTimeoutMs, post, result, respH);
   if(code != 200)
   {
      if(InpDebug) PrintFormat("[SpikeRider] angelofspike code=%d", code);
      return;
   }
   string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   string sig  = JsonExtractString(body, "signal");       // "BUY"|"SELL"|"HOLD"
   double conf = JsonExtractDouble(body, "confidence");
   string mst  = JsonExtractString(body, "market_state");
   if(StringLen(sig) > 0) g_angelSignal      = sig;
   if(conf >= 0.0)        g_angelConfidence  = conf;
   if(StringLen(mst)> 0)  g_angelMarketState = mst;
   g_lastAngelFetch = TimeCurrent();
   g_lastAngelHour  = hourNow;
   PrintFormat("[SpikeRider] Angel %02d:00UTC signal=%s conf=%.1f%% state=%s",
               hourNow, g_angelSignal, g_angelConfidence, g_angelMarketState);
}

//+------------------------------------------------------------------+
//| 4. REALTIME CROSS-CHART : /spike/realtime                       |
//+------------------------------------------------------------------+
void FetchRealtimeSpike()
{
   if(!InpUseRealtimeCross) return;
   // Toutes les 5 secondes max
   if(TimeCurrent() - g_lastRealtimeFetch < 5) return;
   g_lastRealtimeFetch = TimeCurrent();

   string sym_enc = NormalizeSymbolForURL(_Symbol);
   string url = InpAIServerURL + "/spike/realtime?symbol=" + sym_enc;
   string headers = "Content-Type: application/json\r\n";
   char post[], result[]; string respH;
   int code = WebRequest("GET", url, headers, InpPriorTimeoutMs, post, result, respH);
   if(code != 200) return;

   string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   bool   spk  = JsonExtractBool(body,   "spike");
   string dir  = JsonExtractString(body, "direction");
   g_realtimeSpikeActive = spk;
   if(StringLen(dir) > 0) g_realtimeSpikeDir = dir;
   if(InpDebug && spk)
      PrintFormat("[SpikeRider] Realtime cross-chart: SPIKE dir=%s", dir);
}

//+------------------------------------------------------------------+
//| 5. STAIR/DETECT : poster l'escalier détecté en DB               |
//+------------------------------------------------------------------+
void PostStairDetect(double stairScore, double imminence, double atr)
{
   if(!InpSendStairDetect) return;
   if(stairScore < InpStairMinPct) return;

   g_lastStairClientId = GenerateClientEventId();
   bool isBoom = IsBoom(_Symbol);
   string dir  = isBoom ? "buy" : "sell";

   string json = StringFormat(
      "{\"client_event_id\":\"%s\","
      "\"symbol\":\"%s\","
      "\"category\":\"boomcrash\","
      "\"direction\":\"%s\","
      "\"timeframe\":\"M1\","
      "\"pattern_kinds\":\"stair\","
      "\"source\":\"ea\","
      "\"features\":{"
        "\"stair_score\":%.4f,"
        "\"imminence\":%.2f,"
        "\"atr\":%.5f,"
        "\"bars_since_spike\":%d,"
        "\"spike_frequency\":%d,"
        "\"zone_prior\":%.4f,"
        "\"angel_signal\":\"%s\","
        "\"angel_conf\":%.2f"
      "}}",
      g_lastStairClientId, _Symbol, dir,
      stairScore, imminence, atr,
      g_barsSinceLastSpike, GetEffectiveSpikeFrequency(),
      g_zonePrior, g_angelSignal, g_angelConfidence
   );

   string url = InpAIServerURL + "/stair/detect";
   char postData[], result[]; string respH;
   StringToCharArray(json, postData, 0, StringLen(json));
   ArrayResize(postData, StringLen(json));
   string headers = "Content-Type: application/json\r\n";
   int code = WebRequest("POST", url, headers, InpPriorTimeoutMs, postData, result, respH);
   if(code >= 200 && code < 300)
   {
      // Extraire l'ID retourné par le serveur
      string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      string rid  = JsonExtractString(body, "id");
      if(StringLen(rid) > 0) g_lastStairEventId = rid;
      if(InpDebug) PrintFormat("[SpikeRider] stair/detect OK id=%s client=%s",
                                g_lastStairEventId, g_lastStairClientId);
   }
   else if(InpDebug)
      PrintFormat("[SpikeRider] stair/detect code=%d", code);
}

//+------------------------------------------------------------------+
//| 6. SPIKE-INFLUENCE-EVENT : snapshot zone d'imminence            |
//+------------------------------------------------------------------+
void PostSpikeInfluenceEvent(double imminence, double atr)
{
   if(!InpSendInfluence) return;

   MqlDateTime utc; TimeToStruct(TimeGMT(), utc);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double band = atr * 2.0;

   string json = StringFormat(
      "{\"symbol\":\"%s\","
      "\"timeframe\":\"M1\","
      "\"hour_utc\":%d,"
      "\"local_probability\":%.4f,"
      "\"combined_score\":%.4f,"
      "\"mass_level\":%d,"
      "\"prior_server\":%.4f,"
      "\"window_seconds\":%d,"
      "\"price_band_low\":%.5f,"
      "\"price_band_high\":%.5f,"
      "\"source\":\"spikerider\","
      "\"features\":{"
        "\"bars_since_spike\":%d,"
        "\"zone_prior\":%.4f,"
        "\"angel_signal\":\"%s\","
        "\"realtime_spike\":%s"
      "}}",
      _Symbol, utc.hour,
      imminence/100.0, (imminence/100.0 + g_zonePrior) / 2.0,
      (imminence >= 90.0 ? 3 : imminence >= 75.0 ? 2 : 1),
      g_zonePrior, InpPendingMaxAgeSec,
      ask - band, ask + band,
      g_barsSinceLastSpike, g_zonePrior,
      g_angelSignal, (g_realtimeSpikeActive ? "true" : "false")
   );

   HttpPost(InpAIServerURL + "/mt5/spike-influence-event", json);
}

//+------------------------------------------------------------------+
//| 7. FEEDBACK TRADE : /trades/feedback                            |
//+------------------------------------------------------------------+
void PostTradeFeedback(const TradeRecord &rec, double exitPrice, double profit)
{
   if(!InpSendFeedback) return;
   bool isWin  = (profit > 0.0);
   string side = (rec.spikeType == SPIKE_BUY) ? "buy" : "sell";

   string json = StringFormat(
      "{\"symbol\":\"%s\","
      "\"timeframe\":\"M1\","
      "\"side\":\"%s\","
      "\"profit\":%.4f,"
      "\"is_win\":%s,"
      "\"entry_price\":%.5f,"
      "\"exit_price\":%.5f,"
      "\"open_time\":%d,"
      "\"close_time\":%d,"
      "\"ai_confidence\":%.4f,"
      "\"stair_detection_id\":\"%s\","
      "\"stair_client_event_id\":\"%s\"}",
      _Symbol, side, profit,
      (isWin ? "true" : "false"),
      rec.entryPrice, exitPrice,
      (int)rec.openTime, (int)TimeCurrent(),
      rec.imminenceAtEntry / 100.0,
      rec.stairEventId, rec.stairClientId
   );

   bool ok = HttpPost(InpAIServerURL + "/trades/feedback", json);
   PrintFormat("[SpikeRider] Feedback %s %.2f$ %s | stair=%s",
               (isWin ? "WIN" : "LOSS"), profit, side,
               (ok ? "OK" : "ERR"));
}

//+------------------------------------------------------------------+
//| Enregistrement d'un trade ouvert                                 |
//+------------------------------------------------------------------+
void RegisterOpenTrade(ulong ticket, ESpikeType t, double entry,
                       datetime openTime, double imminence,
                       double zScore, double rsi, double stair)
{
   if(g_openTradesCount >= 10) return;
   int idx = g_openTradesCount++;
   g_openTrades[idx].ticket             = ticket;
   g_openTrades[idx].spikeType          = t;
   g_openTrades[idx].entryPrice         = entry;
   g_openTrades[idx].openTime           = openTime;
   g_openTrades[idx].imminenceAtEntry   = imminence;
   g_openTrades[idx].zScoreAtEntry      = zScore;
   g_openTrades[idx].rsiAtEntry         = rsi;
   g_openTrades[idx].stairAtEntry       = stair;
   g_openTrades[idx].zonePriorAtEntry   = g_zonePrior;
   g_openTrades[idx].angelConfAtEntry   = g_angelConfidence;
   g_openTrades[idx].stairEventId       = g_lastStairEventId;
   g_openTrades[idx].stairClientId      = g_lastStairClientId;
   g_lastEntryBarTime                    = iTime(_Symbol, InpTF, 0);
}

int FindOpenTradeIdx(ulong ticket)
{
   for(int i = 0; i < g_openTradesCount; i++)
      if(g_openTrades[i].ticket == ticket) return i;
   return -1;
}

void RemoveOpenTradeAt(int idx)
{
   if(idx < 0 || idx >= g_openTradesCount) return;
   for(int i = idx; i < g_openTradesCount - 1; i++)
      g_openTrades[i] = g_openTrades[i+1];
   g_openTradesCount--;
}

//+------------------------------------------------------------------+
//| CALCUL LOT — lot minimum broker (synthétiques : pas de % risque)  |
//+------------------------------------------------------------------+
int SR_VolumeDigits(const double step)
{
   if(step <= 0.0) return 2;
   if(step >= 1.0) return 0;
   return (int)MathMax(0, MathRound(-MathLog10(step)));
}

double CalcLot(double atr)
{
   const double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = minLot > 0.0 ? minLot : 0.01;

   // Règle absolue : lot le plus bas proposé par le broker sur ce symbole
   double lot = minLot;
   if(InpFixedLot > 0.0)
      lot = MathMax(minLot, MathMin(maxLot, InpFixedLot));

   lot = MathFloor(lot / step + 0.5) * step;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   return NormalizeDouble(lot, SR_VolumeDigits(step));
}

//+------------------------------------------------------------------+
//| Normalisation prix (tick size broker — évite Invalid price)       |
//+------------------------------------------------------------------+
double SR_NormalizeToTick(const double price, const bool roundUp)
{
   const int    dg   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) return NormalizeDouble(price, dg);
   double n = price / tick;
   n = roundUp ? MathCeil(n - 1e-12) : MathFloor(n + 1e-12);
   return NormalizeDouble(n * tick, dg);
}

bool SR_AdjustStopsForOrder(const ENUM_ORDER_TYPE otype, const double openPrice,
                            double &sl, double &tp, const double minDistExtra = 0.0)
{
   if(openPrice <= 0.0) return false;
   const double pt    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    stops = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const int    freeze= (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minD  = (double)MathMax(stops + freeze + 5, 10) * pt;
   if(minDistExtra > 0.0)
      minD = MathMax(minD, minDistExtra);

   const bool isBuy = (otype == ORDER_TYPE_BUY || otype == ORDER_TYPE_BUY_STOP ||
                       otype == ORDER_TYPE_BUY_LIMIT);
   if(sl > 0.0)
   {
      if(isBuy && openPrice - sl < minD)
         sl = SR_NormalizeToTick(openPrice - minD, false);
      if(!isBuy && sl - openPrice < minD)
         sl = SR_NormalizeToTick(openPrice + minD, true);
   }
   if(tp > 0.0)
   {
      if(isBuy && tp - openPrice < minD)
         tp = SR_NormalizeToTick(openPrice + minD, true);
      if(!isBuy && openPrice - tp < minD)
         tp = SR_NormalizeToTick(openPrice - minD, false);
   }
   if(isBuy && sl > 0.0 && sl >= openPrice) return false;
   if(!isBuy && sl > 0.0 && sl <= openPrice) return false;
   if(isBuy && tp > 0.0 && tp <= openPrice) return false;
   if(!isBuy && tp > 0.0 && tp >= openPrice) return false;
   return true;
}

// Réduit la distance SL/TP (pas les prix bruts × facteur — évite Invalid stops)
void SR_ScaleStopDistances(const ENUM_ORDER_TYPE otype, const double entry,
                           const double slOrig, const double tpOrig,
                           const double factor, double &sl, double &tp)
{
   const bool isBuy = (otype == ORDER_TYPE_BUY || otype == ORDER_TYPE_BUY_STOP ||
                       otype == ORDER_TYPE_BUY_LIMIT);
   sl = slOrig;
   tp = tpOrig;
   if(entry <= 0.0 || factor <= 0.0) return;
   if(isBuy)
   {
      if(slOrig > 0.0 && slOrig < entry)
         sl = SR_NormalizeToTick(entry - (entry - slOrig) * factor, false);
      if(tpOrig > 0.0 && tpOrig > entry)
         tp = SR_NormalizeToTick(entry + (tpOrig - entry) * factor, true);
   }
   else
   {
      if(slOrig > 0.0 && slOrig > entry)
         sl = SR_NormalizeToTick(entry + (slOrig - entry) * factor, true);
      if(tpOrig > 0.0 && tpOrig < entry)
         tp = SR_NormalizeToTick(entry - (entry - tpOrig) * factor, false);
   }
}

bool SR_OrderCheckMarket(const ENUM_ORDER_TYPE otype, const double lot,
                         const double sl, const double tp)
{
   MqlTradeRequest     req;
   MqlTradeCheckResult chk;
   ZeroMemory(req);
   ZeroMemory(chk);
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = _Symbol;
   req.volume    = lot;
   req.type      = otype;
   req.price     = (otype == ORDER_TYPE_BUY)
                   ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   req.sl        = sl;
   req.tp        = tp;
   req.deviation = 30;
   req.magic     = InpMagic;
   return OrderCheck(req, chk);
}

// Recalcule SL/TP au prix marché actuel + vérifie broker
bool SR_PrepareMarketStops(const ENUM_ORDER_TYPE otype, const double atr,
                           const double lot, double &sl, double &tp)
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double px  = (otype == ORDER_TYPE_BUY) ? ask : bid;
   if(px <= 0.0 || atr <= 0.0) return false;

   const double minExtra = atr * 0.35;
   if(otype == ORDER_TYPE_BUY)
   {
      sl = SR_NormalizeToTick(px - atr * InpSL_ATR, false);
      tp = SR_NormalizeToTick(px + atr * InpTP_ATR, true);
   }
   else
   {
      sl = SR_NormalizeToTick(px + atr * InpSL_ATR, true);
      tp = SR_NormalizeToTick(px - atr * InpTP_ATR, false);
   }
   if(!SR_AdjustStopsForOrder(otype, px, sl, tp, minExtra))
      return false;
   return SR_OrderCheckMarket(otype, lot, sl, tp);
}

// Distance minimale SL/TP par rapport au prix marché courant (modify position)
double SR_MinStopDistance()
{
   const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pt <= 0.0) return 0.0;
   const int stops  = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const int freeze = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minD = (double)MathMax(stops + freeze + 5, 10) * pt;
   double atr  = GetATR();
   if(atr > 0.0)
      minD = MathMax(minD, atr * 0.5);
   return minD;
}

bool SR_ClampStopsForModify(const long posType, const double marketPx, double &sl, double &tp)
{
   const double minD = SR_MinStopDistance();
   const double pt   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(minD <= 0.0 || marketPx <= 0.0) return true;

   if(posType == POSITION_TYPE_BUY)
   {
      if(sl > 0.0)
      {
         const double maxSl = marketPx - minD;
         if(sl > maxSl) sl = SR_NormalizeToTick(maxSl, false);
         if(pt > 0.0 && sl >= marketPx - pt * 0.5) return false;
      }
      if(tp > 0.0)
      {
         const double minTp = marketPx + minD;
         if(tp <= marketPx)
            tp = 0.0;
         else if(tp < minTp)
            tp = SR_NormalizeToTick(minTp, true);
      }
   }
   else
   {
      if(sl > 0.0)
      {
         const double minSl = marketPx + minD;
         if(sl < minSl) sl = SR_NormalizeToTick(minSl, true);
         if(pt > 0.0 && sl <= marketPx + pt * 0.5) return false;
      }
      if(tp > 0.0)
      {
         const double maxTp = marketPx - minD;
         if(tp >= marketPx)
            tp = 0.0;
         else if(tp > maxTp)
            tp = SR_NormalizeToTick(maxTp, false);
      }
   }
   return true;
}

// Vérifie SL/TP via OrderCheck avant PositionModify (évite Invalid stops en journal)
bool SR_SafePositionModify(const ulong ticket, double sl, double tp)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket)) return false;

   MqlTradeRequest     req;
   MqlTradeCheckResult chk;
   ZeroMemory(req);
   ZeroMemory(chk);
   req.action   = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol   = _Symbol;
   req.magic    = InpMagic;
   req.sl       = sl;
   req.tp       = tp;

   if(OrderCheck(req, chk))
      return g_trade.PositionModify(ticket, sl, tp);

   if(tp > 0.0)
   {
      req.tp = 0.0;
      if(OrderCheck(req, chk))
         return g_trade.PositionModify(ticket, sl, 0.0);
   }
   return false;
}

//+------------------------------------------------------------------+
//| SCORE STAIR                                                      |
//+------------------------------------------------------------------+
double CalcStairScore(bool isBoom)
{
   if(InpStairBars <= 0) return 1.0;
   MqlRates r[];
   int need = InpStairBars + 2;
   if(CopyRates(_Symbol, InpTF, 1, need, r) < need) return 0.5;
   int aligned = 0;
   for(int i = 0; i < InpStairBars; i++)
   {
      double body = r[i].close - r[i].open;
      // Boom: escalier haussier (bougies vertes). Crash: escalier baissier (bougies rouges).
      if(isBoom  && body > 0) aligned++;
      if(!isBoom && body < 0) aligned++;
   }
   return (double)aligned / InpStairBars;
}

//+------------------------------------------------------------------+
//| SCORE D'IMMINENCE (5 facteurs + zone prior + angel)             |
//+------------------------------------------------------------------+
double CalcImminenceScore(double atr, double rsi, double stair)
{
   bool isBoom   = IsBoom(_Symbol);
   bool hasPrior = (InpUsePrior && g_lastPriorFetch != 0);
   bool hasZone  = (InpUseZonePrior && g_lastZoneFetch != 0 && g_zoneSamples >= 3);
   double score  = 0.0;

   // 1. Compteur inter-spike : 25% (avec zone) / 30% (sans)
   double w1 = hasZone ? 25.0 : (hasPrior ? 30.0 : 35.0);
   int spikeFreq = GetEffectiveSpikeFrequency();
   if(spikeFreq > 0)
   {
      // Compteur utile dès ~25% de la fréquence (ex. 150 bar M1 sur Boom 600)
      double ratio    = (double)g_barsSinceLastSpike / (double)spikeFreq;
      double cntScore = (ratio >= 0.25) ? MathMin((ratio - 0.25) / 0.75, 1.0) : 0.0;
      score += cntScore * w1;
   }

   // 2. Compression ATR : 20%
   double atrMean = GetATRMean();
   if(atr > 0 && atrMean > 0)
   {
      double compRatio = atr / atrMean;
      if(compRatio <= InpAtrCompressRatio)
      {
         double compScore = MathMin((InpAtrCompressRatio - compRatio) / InpAtrCompressRatio, 1.0);
         score += compScore * 20.0;
      }
   }

   // 3. Stair score : 15%
   score += stair * 15.0;

   // 4. RSI extrême : 10%
   if(isBoom)
   {
      if(rsi <= 30.0)      score += 10.0;
      else if(rsi < 40.0)  score += (40.0 - rsi) / 10.0 * 10.0;
   }
   else
   {
      if(rsi >= 70.0)      score += 10.0;
      else if(rsi > 60.0)  score += (rsi - 60.0) / 10.0 * 10.0;
   }

   // 5. Prior RDS (capture_rate + avg_atr_mult) : 15%
   if(hasPrior && g_priorSampleCount >= 5)
   {
      double cr = g_priorCaptureRate;
      double ps = 0.0;
      if(cr >= 0.70)      ps = 1.0;
      else if(cr >= 0.30) ps = (cr - 0.30) / 0.40;
      if(g_priorAtrMult >= 3.0)       ps = MathMin(ps + 0.2, 1.0);
      else if(g_priorAtrMult >= 2.5)  ps = MathMin(ps + 0.1, 1.0);
      score += ps * 15.0;
   }

   // 6. Zone prior (/mt5/spike-zone-prior) : +10% bonus si disponible
   if(hasZone)
      score += g_zonePrior * 10.0;

   // 7. Angel of Spike (/angelofspike/trend) : +5% si aligné, -5% si opposé
   if(InpUseAngelOfSpike && g_lastAngelFetch != 0)
   {
      bool aligned = (isBoom  && g_angelSignal == "BUY") ||
                     (!isBoom && g_angelSignal == "SELL");
      bool opposed = (isBoom  && g_angelSignal == "SELL") ||
                     (!isBoom && g_angelSignal == "BUY");
      if(aligned) score += g_angelConfidence / 100.0 * 5.0;
      if(opposed) score -= g_angelConfidence / 100.0 * 5.0;
   }

   // 8. Realtime cross-chart : +5% si spike actif dans la bonne direction
   if(InpUseRealtimeCross && g_realtimeSpikeActive)
   {
      bool aligned = (isBoom  && (g_realtimeSpikeDir == "up"  || g_realtimeSpikeDir == "BUY")) ||
                     (!isBoom && (g_realtimeSpikeDir == "down"|| g_realtimeSpikeDir == "SELL"));
      if(aligned) score += 5.0;
   }

   // 9. Proximité zone spike historique RDS : +15% bonus si prix dans rayon 1×ATR
   //    d'un niveau où un spike s'est déjà produit (capturé avec profit)
   //    C'est le facteur clé : les spikes Boom/Crash reviennent souvent aux mêmes zones
   if(g_spikeCount > 0 && atr > 0)
   {
      double px      = isBoom ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double radius  = atr * 1.5;   // tolérance = 1.5× ATR autour du prix historique
      int    hits    = 0;
      int    hitsCap = 0;
      for(int k = 0; k < g_spikeCount; k++)
      {
         // On retrouve le prix MT5 au timestamp du spike historique
         MqlRates sr[];
         if(CopyRates(_Symbol, InpTF, g_spikeTs[k], 1, sr) < 1) continue;
         double spikePx = (g_spikeDirs[k] == "BUY") ? sr[0].low : sr[0].high;
         if(spikePx <= 0) continue;
         if(MathAbs(px - spikePx) <= radius)
         {
            hits++;
            if(g_spikeCaptured[k]) hitsCap++;
         }
      }
      if(hits > 0)
      {
         // Plus il y a eu de spikes capturés dans cette zone, plus le bonus est fort
         double zoneBonus = MathMin((double)hitsCap / MathMax(hits, 1), 1.0) * 15.0;
         zoneBonus = MathMax(zoneBonus, hits > 1 ? 5.0 : 2.0);  // bonus minimal si hits > 0
         score += zoneBonus;
         if(InpDebug) PrintFormat("[SpikeRider] Zone RDS: %d hits (%d cap) bonus=%.0f",
                                   hits, hitsCap, zoneBonus);
      }
   }

   return MathMax(0.0, MathMin(score, 100.0));
}

//+------------------------------------------------------------------+
//| GESTION ORDRE PENDING PRÉ-SPIKE                                 |
//+------------------------------------------------------------------+
bool HasPendingOrder()
{
   if(g_pendingTicket == 0) return false;
   if(OrderSelect(g_pendingTicket)) return true;
   g_pendingTicket = 0;
   return false;
}
void CancelPendingOrder(const string reason)
{
   if(g_pendingTicket == 0) return;
   if(OrderSelect(g_pendingTicket))
   {
      g_trade.OrderDelete(g_pendingTicket);
      if(InpDebug) PrintFormat("[SpikeRider] Pending annulé (%s) ticket=%llu", reason, g_pendingTicket);
   }
   g_pendingTicket   = 0;
   g_pendingPlacedAt = 0;
}
void ManagePendingAge()
{
   if(g_pendingTicket == 0 || InpPendingMaxAgeSec <= 0) return;
   if((int)(TimeCurrent() - g_pendingPlacedAt) >= InpPendingMaxAgeSec)
      CancelPendingOrder("expiré");
}
bool PlacePreSpikePending(double atr, double imminence)
{
   if(atr <= 0.0) return false;

   // Marché par défaut — évite Invalid price sur synthétiques (Boom/Crash)
   if(InpPreSpikeUseMarket)
   {
      SpikeResult pre;
      pre.type       = IsBoom(_Symbol) ? SPIKE_BUY : SPIKE_SELL;
      pre.zScore     = 0.0;
      pre.rsi        = GetRSI();
      pre.atr        = atr;
      pre.stairScore = CalcStairScore(IsBoom(_Symbol));
      CancelPendingOrder("pré-spike marché");
      return EnterSpikeTrade(pre, imminence, true);
   }

   bool isBoom  = IsBoom(_Symbol);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return false;

   const double pt     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    stops  = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const int    freeze = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const double minGap = (double)(stops + freeze + 3) * (pt > 0.0 ? pt : 0.01);
   const double offset = MathMax(atr * InpPendingOffsetATR, minGap);
   const double lot    = CalcLot(atr);

   double price, sl, tp;
   ENUM_ORDER_TYPE otype;
   if(isBoom)
   {
      otype = ORDER_TYPE_BUY_STOP;
      price = SR_NormalizeToTick(ask + offset, true);
      if(price <= ask)
         price = SR_NormalizeToTick(ask + minGap, true);
      if(price <= ask)
      {
         if(InpDebug) PrintFormat("[SpikeRider] BUY_STOP invalide ask=%.5f price=%.5f → marché", ask, price);
         SpikeResult pre; pre.type = SPIKE_BUY; pre.rsi = GetRSI(); pre.atr = atr;
         pre.stairScore = CalcStairScore(true); pre.zScore = 0.0;
         return EnterSpikeTrade(pre, imminence, true);
      }
      sl = SR_NormalizeToTick(price - atr * InpSL_ATR, false);
      tp = SR_NormalizeToTick(price + atr * InpTP_ATR, true);
   }
   else
   {
      otype = ORDER_TYPE_SELL_STOP;
      price = SR_NormalizeToTick(bid - offset, false);
      if(price >= bid)
         price = SR_NormalizeToTick(bid - minGap, false);
      if(price >= bid)
      {
         if(InpDebug) PrintFormat("[SpikeRider] SELL_STOP invalide bid=%.5f price=%.5f → marché", bid, price);
         SpikeResult pre; pre.type = SPIKE_SELL; pre.rsi = GetRSI(); pre.atr = atr;
         pre.stairScore = CalcStairScore(false); pre.zScore = 0.0;
         return EnterSpikeTrade(pre, imminence, true);
      }
      sl = SR_NormalizeToTick(price + atr * InpSL_ATR, true);
      tp = SR_NormalizeToTick(price - atr * InpTP_ATR, false);
   }

   const double minExtraPend = atr * 0.35;
   if(!SR_AdjustStopsForOrder(otype, price, sl, tp, minExtraPend))
   {
      SpikeResult pre;
      pre.type = isBoom ? SPIKE_BUY : SPIKE_SELL;
      pre.rsi = GetRSI(); pre.atr = atr; pre.stairScore = CalcStairScore(isBoom); pre.zScore = 0.0;
      return EnterSpikeTrade(pre, imminence, true);
   }

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(30);
   datetime expiry = TimeCurrent() + InpPendingMaxAgeSec;
   bool ok = g_trade.OrderOpen(_Symbol, otype, lot, 0, price, sl, tp,
                                ORDER_TIME_SPECIFIED, expiry,
                                "SpikeRider|PRE-SPIKE");
   if(ok)
   {
      g_pendingTicket   = g_trade.ResultOrder();
      g_pendingPlacedAt = TimeCurrent();
      PrintFormat("[SpikeRider] ⏳ Pending %s prix=%.5f ask=%.5f SL=%.5f TP=%.5f lot=%.2f",
                  (isBoom ? "BUY_STOP" : "SELL_STOP"), price, ask, sl, tp, lot);
      PostSpikeInfluenceEvent(imminence, atr);
   }
   else
   {
      PrintFormat("[SpikeRider] ❌ Pending %d %s | ask=%.5f bid=%.5f px=%.5f → fallback marché",
                  g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription(), ask, bid, price);
      SpikeResult pre;
      pre.type = isBoom ? SPIKE_BUY : SPIKE_SELL;
      pre.rsi = GetRSI(); pre.atr = atr; pre.stairScore = CalcStairScore(isBoom); pre.zScore = 0.0;
      ok = EnterSpikeTrade(pre, imminence, true);
   }
   return ok;
}

//+------------------------------------------------------------------+
//| DÉTECTION SPIKE CONFIRMÉ (bougie fermée)                        |
//+------------------------------------------------------------------+
SpikeResult DetectSpike()
{
   SpikeResult res;
   res.type       = SPIKE_NONE;
   res.zScore     = 0.0;
   res.rsi        = GetRSI();
   res.atr        = GetATR();
   res.stairScore = 0.0;

   int need = InpLookback + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpTF, 0, need, rates) < need) return res;

   bool isBoom  = IsBoom(_Symbol);
   bool isCrash = IsCrash(_Symbol);
   bool synth   = isBoom || isCrash;

   double mean = 0.0, sd = 0.0, z = 0.0;
   double moveClosed = 0.0, moveLive = 0.0, curMove = 0.0;
   bool useLive = false;

   if(synth)
   {
      // Boom/Crash : baseline sur CORPS de bougies (pas close-close)
      double bodies[];
      ArrayResize(bodies, InpLookback);
      for(int i = 0; i < InpLookback; i++)
      {
         bodies[i] = MathAbs(rates[i + 1].close - rates[i + 1].open);
         mean += bodies[i];
      }
      mean /= InpLookback;
      if(mean <= 0.0) mean = _Point * 10.0;

      double var = 0.0;
      for(int i = 0; i < InpLookback; i++)
         var += MathPow(bodies[i] - mean, 2);
      sd = MathSqrt(var / InpLookback);
      if(sd <= 0.0) sd = mean * 0.15;

      moveClosed = MathAbs(rates[1].close - rates[1].open);
      moveLive   = MathAbs(rates[0].close - rates[0].open);
      // Bougie en formation : extension haussière/baissière (capte le spike tôt)
      if(isBoom)
         moveLive = MathMax(moveLive, MathMax(rates[0].close - rates[0].open, rates[0].high - rates[0].open));
      if(isCrash)
         moveLive = MathMax(moveLive, MathMax(rates[0].open - rates[0].close, rates[0].open - rates[0].low));
      moveLive = MathAbs(moveLive);

      curMove  = MathMax(moveClosed, moveLive);
      useLive  = (moveLive >= moveClosed);
      z        = (curMove - mean) / sd;
   }
   else
   {
      double moves[];
      ArrayResize(moves, InpLookback);
      for(int i = 0; i < InpLookback; i++)
      {
         moves[i] = MathAbs(rates[i + 1].close - rates[i + 2].close);
         mean += moves[i];
      }
      mean /= InpLookback;
      if(mean <= 0.0) return res;

      double var = 0.0;
      for(int i = 0; i < InpLookback; i++) var += MathPow(moves[i] - mean, 2);
      sd = MathSqrt(var / InpLookback);
      if(sd <= 0.0) sd = mean * 0.1;

      moveClosed = MathAbs(rates[1].close - rates[1].open);
      moveLive   = MathAbs(rates[0].close - rates[0].open);
      curMove    = MathMax(moveClosed, moveLive);
      useLive    = (moveLive > moveClosed);
      z          = (curMove - mean) / sd;
   }

   res.zScore = z;

   double zThresh = synth ? InpSynthZScoreMin : InpZScoreMin;
   bool isSpike = (z >= zThresh) || (curMove >= mean * InpMinMoveMult);
   if(synth && res.atr > 0.0)
      isSpike = isSpike || (curMove >= res.atr * InpSynthBodyAtrMult);
   if(!isSpike) return res;

   bool up = useLive ? (rates[0].close > rates[0].open) : (rates[1].close > rates[1].open);
   if(synth && useLive && isBoom && rates[0].high > rates[0].open)
      up = true;
   if(synth && useLive && isCrash && rates[0].low < rates[0].open)
      up = false;

   if(isBoom  && !up) return res;
   if(isCrash && up)  return res;

   ESpikeType want = isBoom ? SPIKE_BUY : SPIKE_SELL;
   if(!synth && IsStrongCounterTrend(want))
   {
      if(InpDebug) Print("[SpikeRider] Spike Z OK mais tendance opposée — ignoré");
      return res;
   }

   if(InpRequireRSI)
   {
      if(isBoom  && res.rsi > InpRSIBoomMax)  return res;
      if(isCrash && res.rsi < InpRSICrashMin) return res;
   }

   if(InpUseAngelOfSpike && g_lastAngelFetch != 0 && g_angelConfidence >= 70.0)
   {
      bool opposed = (isBoom  && g_angelSignal == "SELL") ||
                     (!isBoom && g_angelSignal == "BUY");
      if(opposed)
      {
         if(InpDebug) PrintFormat("[SpikeRider] Spike bloqué par Angel (%s conf=%.0f%%)",
                                   g_angelSignal, g_angelConfidence);
         return res;
      }
   }

   double stair   = CalcStairScore(isBoom);
   res.stairScore = stair;
   if(InpStairMinPct > 0.0 && stair < InpStairMinPct) return res;

   res.type = up ? SPIKE_BUY : SPIKE_SELL;
   return res;
}

//+------------------------------------------------------------------+
//| POSITION OUVERTE                                                 |
//+------------------------------------------------------------------+

// Retourne le nombre de positions ouvertes par cet EA sur ce symbole
int CountOurPositions()
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)InpMagic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         count++;
   }
   return count;
}

string SymbolEntryLockKey()
{
   return StringFormat("SpikeRider_%u_%s", (uint)InpMagic, _Symbol);
}

// Verrou global : plusieurs graphiques MT5 sur le même symbole partagent le même EA
bool AcquireSymbolEntryLock(const int holdSec = 8)
{
   string key = SymbolEntryLockKey();
   datetime now = TimeCurrent();
   if(GlobalVariableCheck(key))
   {
      datetime lockedAt = (datetime)GlobalVariableGet(key);
      if(now - lockedAt < holdSec)
         return false;
   }
   GlobalVariableSet(key, (double)now);
   return true;
}

void ReleaseSymbolEntryLock()
{
   string key = SymbolEntryLockKey();
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}

void SyncEntrySlotLock()
{
   bool hasPos      = (CountOurPositions() >= 1);
   // Garde le slot verrouillé pendant le cooldown après un trade — évite la duplication
   // entre l'envoi de l'ordre et la confirmation broker (race condition inter-ticks)
   bool recentTrade = (g_lastTrade != 0 && TimeCurrent() - g_lastTrade < (int)MathMax(InpCooldownSec, 3));
   g_entrySlotLocked = hasPos || recentTrade;
   if(!g_entrySlotLocked)
      ReleaseSymbolEntryLock();
}

bool HasPosition()        { return CountOurPositions() > 0; }

// 1 seule position par symbole (magic + _Symbol)
bool MaxPositionsReached()
{
   if(CountOurPositions() >= 1) return true;
   return g_entrySlotLocked;
}
ulong GetOpenTicket()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)InpMagic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return t;
   }
   return 0;
}
bool SpreadOK()
{
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (InpMaxSpreadPoints <= 0 || spread <= InpMaxSpreadPoints);
}

//+------------------------------------------------------------------+
//| LIMITE JOURNALIÈRE                                               |
//+------------------------------------------------------------------+
void ResetDayIfNeeded()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime today = StructToTime(dt);
   if(today != g_dayTag)
   {
      g_dayTag          = today;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
}
bool DailyLimitHit()
{
   if(InpMaxDailyLossPct <= 0.0) return false;
   double bal  = AccountInfoDouble(ACCOUNT_BALANCE);
   double loss = g_dayStartBalance - bal;
   return (loss >= g_dayStartBalance * InpMaxDailyLossPct / 100.0);
}

//+------------------------------------------------------------------+
//| ENTRÉE MARCHÉ (spike confirmé)                                   |
//+------------------------------------------------------------------+
bool EnterSpikeTrade(const SpikeResult &spike, double imminence, const bool isPreSpike = false)
{
   if(MaxPositionsReached())
   {
      if(InpDebug) Print("[SpikeRider] Entrée ignorée: position déjà ouverte sur ", _Symbol);
      return false;
   }
   if(g_entrySlotLocked)
   {
      if(InpDebug) Print("[SpikeRider] Entrée ignorée: slot déjà réservé ce tick");
      return false;
   }
   if(!AcquireSymbolEntryLock())
   {
      if(InpDebug) Print("[SpikeRider] Entrée ignorée: verrou global actif (autre instance/chart)");
      return false;
   }
   g_entrySlotLocked = true;

   string blockReason;
   if(!CanEnterInDirection(spike.type, isPreSpike, spike, blockReason))
   {
      if(InpDebug)
         PrintFormat("[SpikeRider] %s %s bloqué: %s",
                     (isPreSpike ? "Pré-spike" : "Spike"),
                     (spike.type == SPIKE_BUY ? "BUY" : "SELL"), blockReason);
      g_entrySlotLocked = (CountOurPositions() >= 1);
      if(!g_entrySlotLocked) ReleaseSymbolEntryLock();
      return false;
   }

   double atr = spike.atr;
   if(atr <= 0.0)
   {
      g_entrySlotLocked = (CountOurPositions() >= 1);
      if(!g_entrySlotLocked) ReleaseSymbolEntryLock();
      return false;
   }
   double lot   = CalcLot(atr);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price, sl = 0.0, tp = 0.0;
   ENUM_ORDER_TYPE otype = (spike.type == SPIKE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(spike.type == SPIKE_BUY) price = ask;
   else                        price = bid;

   double slUse = 0.0, tpUse = 0.0;
   if(spike.type == SPIKE_BUY)
   {
      sl = SR_NormalizeToTick(price - atr * InpSL_ATR, false);
      tp = SR_NormalizeToTick(price + atr * InpTP_ATR, true);
   }
   else
   {
      sl = SR_NormalizeToTick(price + atr * InpSL_ATR, true);
      tp = SR_NormalizeToTick(price - atr * InpTP_ATR, false);
   }
   slUse = sl;
   tpUse = tp;

   // Prix marché + OrderCheck (évite Invalid stops quand le prix bouge vite sur Boom)
   const double minExtra = atr * 0.35;
   bool stopsReady = false;
   for(int pass = 0; pass < 3 && !stopsReady; pass++)
   {
      price = (spike.type == SPIKE_BUY)
              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(pass == 0)
      {
         slUse = sl;
         tpUse = tp;
      }
      else
         SR_ScaleStopDistances(otype, price, sl, tp, (pass == 1 ? 0.85 : 0.70), slUse, tpUse);

      if(!SR_AdjustStopsForOrder(otype, price, slUse, tpUse, minExtra))
         continue;
      if(!SR_OrderCheckMarket(otype, lot, slUse, tpUse))
      {
         if(InpDebug)
            PrintFormat("[SpikeRider] OrderCheck refuse SL=%.5f TP=%.5f ask=%.5f (pass %d)",
                        slUse, tpUse, price, pass);
         continue;
      }
      stopsReady = true;
   }
   if(!stopsReady)
   {
      if(!SR_PrepareMarketStops(otype, atr, lot, slUse, tpUse))
      {
         g_lastEntryFail = TimeCurrent();
         if(InpDebug)
            PrintFormat("[SpikeRider] SL/TP impossibles ask=%.5f ATR=%.5f stops=%d",
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK), atr,
                        (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL));
         g_entrySlotLocked = (CountOurPositions() >= 1);
         if(!g_entrySlotLocked) ReleaseSymbolEntryLock();
         return false;
      }
   }

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(30);
   string cmt = StringFormat("SRv5|%s|Z=%.2f|BOS%s|CH%s|OTE%s",
                              (spike.type == SPIKE_BUY ? "BUY" : "SELL"),
                              spike.zScore,
                              (g_smc.bos ? "+" : "-"),
                              (g_smc.choch ? "+" : "-"),
                              (g_smc.inOTE ? "+" : "-"));
   bool ok = (spike.type == SPIKE_BUY)
             ? g_trade.Buy(lot,  _Symbol, 0, slUse, tpUse, cmt)
             : g_trade.Sell(lot, _Symbol, 0, slUse, tpUse, cmt);
   if(!ok)
   {
      g_lastEntryFail = TimeCurrent();
      PrintFormat("[SpikeRider] ❌ Ordre échoué SL=%.5f TP=%.5f ask=%.5f | %d - %s",
                  slUse, tpUse, SymbolInfoDouble(_Symbol, SYMBOL_ASK),
                  g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
      g_entrySlotLocked = (CountOurPositions() >= 1);
      if(!g_entrySlotLocked) ReleaseSymbolEntryLock();
      return false;
   }
   if(ok)
   {
      g_lastTrade          = TimeCurrent();
      g_barsSinceLastSpike = 0;
      g_lastSpikeBar       = iTime(_Symbol, InpTF, 0);
      ulong ticket         = g_trade.ResultOrder();
      RegisterOpenTrade(ticket, spike.type, price, TimeCurrent(),
                        imminence, spike.zScore, spike.rsi, spike.stairScore);
      PrintFormat("[SpikeRider] ✅ %s lot=%.2f SL=%.5f TP=%.5f Z=%.2f imminence=%.0f%%",
                  (spike.type==SPIKE_BUY?"BUY":"SELL"), lot, sl, tp,
                  spike.zScore, imminence);
   }
   else
      PrintFormat("[SpikeRider] ❌ %s échoué | %d - %s",
                  (spike.type==SPIKE_BUY?"BUY":"SELL"),
                  g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
   return ok;
}

//+------------------------------------------------------------------+
//| NOTIFICATION PRÉ-SPIKE — alerte AVANT le spike (imminence)      |
//+------------------------------------------------------------------+
void CheckAndNotifyPreSpike(double imminence)
{
   // Seuils : alerte progressive selon imminence
   bool alert70  = (imminence >= 70.0  && g_lastNotifImm < 70.0);
   bool alert50  = (imminence >= 50.0  && g_lastNotifImm < 50.0);
   bool alertNew = (alert70 || alert50);

   // Anti-spam : 1 notification par tranche, cooldown 30s min
   if(!alertNew) return;
   if(TimeCurrent() - g_lastNotifTime < 30) return;

   bool   boom   = IsBoom(_Symbol);
   int    freq   = GetEffectiveSpikeFrequency();
   double prog   = (freq > 0) ? MathMin((double)g_barsSinceLastSpike / freq * 100.0, 100.0) : 0.0;

   string lvl    = (imminence >= 70.0) ? "🔥 IMMINENT" : "⚡ ALERTE";
   string dir    = boom ? "BUY (hausse)" : "SELL (baisse)";
   string msg    = StringFormat("%s %s | %s | Imm=%.0f%% Barres=%d/%d (%.0f%%)",
                                lvl, _Symbol, dir, imminence,
                                g_barsSinceLastSpike, freq, prog);

   Alert(msg);
   SendNotification(msg);   // notification mobile MT5
   PrintFormat("[SpikeRider] 🔔 NOTIF: %s", msg);

   g_lastNotifTime = TimeCurrent();
   g_lastNotifImm  = imminence;
}

// Réinitialiser le seuil de notification après un spike
void ResetNotifState() { g_lastNotifImm = 0.0; }

//+------------------------------------------------------------------+
//| SORTIE RAPIDE — fermeture immédiate dès spike capté en gain      |
//| Priorité : spike en profit > hold minimum (scalping spike)       |
//+------------------------------------------------------------------+
void ManageQuickExit(const bool spikeActive = false)
{
   if(!InpUseQuickExit) return;

   double minProfit = InpQuickExitMinProfitUSD;
   if(StringFind(_Symbol, "600") >= 0)
      minProfit = MathMax(minProfit, InpQuickExitMinProfitBoom600);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)         continue;

      double profit = PositionGetDouble(POSITION_PROFIT)
                    + PositionGetDouble(POSITION_SWAP);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int holdSec = (int)(TimeCurrent() - openTime);

      datetime barNow = iTime(_Symbol, InpTF, 0);
      bool sameSpikeBar = (!InpExitOnSameSpikeBar && g_lastEntryBarTime > 0 &&
                           barNow <= g_lastEntryBarTime);

      // ── PRIORITÉ 1 : spike capté pendant position ouverte → fermer si gain ──
      // Pas de hold minimum ici : le spike EST la sortie cible du scalping
      if(spikeActive && !sameSpikeBar && profit > 0.0)
      {
         g_trade.PositionClose(ticket, 10);
         ResetNotifState();
         PrintFormat("[SpikeRider] ⚡ Sortie spike capturé (profit=$%.2f, hold=%ds) ticket=%llu",
                     profit, holdSec, ticket);
         continue;
      }

      // ── PRIORITÉ 1b : flèche clignotante ACTIVE (imminence >= seuil) + profit réalisé ──
      // La flèche sur la bougie courante = signal que le spike est en cours → sortir
      bool blinkActive = (g_barsSinceLastSpike > 0);  // barres écoulées = spike vraisemblable
      if(blinkActive && !sameSpikeBar && holdSec >= 2 && profit > 0.0)
      {
         double px = IsBoom(_Symbol) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double openPx = PositionGetDouble(POSITION_PRICE_OPEN);
         bool   inProfit = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                           ? (px > openPx) : (px < openPx);
         if(inProfit && profit >= InpQuickExitMinProfitUSD * 0.5)
         {
            g_trade.PositionClose(ticket, 10);
            ResetNotifState();
            PrintFormat("[SpikeRider] 🎯 Sortie flèche active (profit=$%.2f, hold=%ds) ticket=%llu",
                        profit, holdSec, ticket);
            continue;
         }
      }

      // ── PRIORITÉ 2 : sortie objectif profit après hold minimum ──
      if(holdSec < InpMinHoldSec) continue;

      if(profit >= minProfit)
      {
         g_trade.PositionClose(ticket, 10);
         ResetNotifState();
         PrintFormat("[SpikeRider] ✅ Sortie objectif | profit=$%.2f hold=%ds ticket=%llu",
                     profit, holdSec, ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| FERMETURE GLOBALE — tous Boom/Crash en gain sur spike capté      |
//| Appelée dès qu'un spike est détecté sur le chart courant.        |
//| Ferme toutes les positions Boom/Crash (tout magic, tout symbole) |
//| dès que profit + swap > 0, même infime.                          |
//+------------------------------------------------------------------+
void CloseAllBoomCrashOnSpike()
{
   if(!InpUseQuickExit) return;

   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      if(!IsBoom(sym) && !IsCrash(sym)) continue;   // Boom/Crash uniquement

      double profit = PositionGetDouble(POSITION_PROFIT)
                    + PositionGetDouble(POSITION_SWAP);
      if(profit <= 0.0) continue;                    // En gain même infime

      bool ok = g_trade.PositionClose(ticket, 10);
      if(ok)
      {
         closed++;
         PrintFormat("[SpikeRider] ⚡ CloseAll SPIKE → %s profit=$%.2f ticket=%llu",
                     sym, profit, ticket);
      }
   }
   if(closed > 0)
   {
      ResetNotifState();
      PrintFormat("[SpikeRider] ✅ %d position(s) fermée(s) sur spike global", closed);
   }
}

//+------------------------------------------------------------------+
//| TRAILING STOP                                                    |
//+------------------------------------------------------------------+
void ManageTrailing()
{
   if(!InpUseTrailing) return;

   ulong ticket = GetOpenTicket();
   if(ticket == 0) return;
   if(!PositionSelectByTicket(ticket)) return;
   double atr = GetATR();
   if(atr <= 0.0) return;
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   long   posType     = PositionGetInteger(POSITION_TYPE);
   double ask         = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid         = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double pt    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double minD  = SR_MinStopDistance();
   const double activation = atr * InpTrailActivation;
   const double trailDist  = MathMax(atr * InpTrailStep, minD);

   static datetime s_lastTrailFailLog = 0;

   if(posType == POSITION_TYPE_BUY)
   {
      if(bid - openPrice < activation) return;
      double newSL = SR_NormalizeToTick(bid - trailDist, false);
      if(currentSL > 0.0 && newSL <= currentSL + pt) return;
      double tpUse = currentTP;
      if(!SR_ClampStopsForModify(POSITION_TYPE_BUY, bid, newSL, tpUse)) return;
      if(currentSL > 0.0 && newSL <= currentSL + pt) return;
      if(!SR_SafePositionModify(ticket, newSL, tpUse))
      {
         if(InpDebug && TimeCurrent() - s_lastTrailFailLog >= 120)
         {
            s_lastTrailFailLog = TimeCurrent();
            PrintFormat("[SpikeRider] Trailing BUY ignoré | bid=%.4f sl=%.4f tp=%.4f minD=%.4f",
                        bid, newSL, tpUse, minD);
         }
      }
   }
   else if(posType == POSITION_TYPE_SELL)
   {
      if(openPrice - ask < activation) return;
      double newSL = SR_NormalizeToTick(ask + trailDist, true);
      if(currentSL > 0.0 && newSL >= currentSL - pt) return;
      double tpUse = currentTP;
      if(!SR_ClampStopsForModify(POSITION_TYPE_SELL, ask, newSL, tpUse)) return;
      if(currentSL > 0.0 && newSL >= currentSL - pt) return;
      if(!SR_SafePositionModify(ticket, newSL, tpUse))
      {
         if(InpDebug && TimeCurrent() - s_lastTrailFailLog >= 120)
         {
            s_lastTrailFailLog = TimeCurrent();
            PrintFormat("[SpikeRider] Trailing SELL ignoré | ask=%.4f sl=%.4f tp=%.4f minD=%.4f",
                        ask, newSL, tpUse, minD);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| HELPERS OBJETS GRAPHIQUES                                        |
//+------------------------------------------------------------------+
string ObjName(string suffix) { return "SR_" + _Symbol + "_" + suffix; }

void ObjDel(string suffix) { ObjectDelete(0, ObjName(suffix)); }

void ObjHLine(string suffix, double price, color clr, ENUM_LINE_STYLE style, int width=1)
{
   string n = ObjName(suffix);
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, n, OBJPROP_PRICE, price);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_STYLE, style);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, n, OBJPROP_BACK, true);
}

void ObjArrow(string suffix, datetime t, double price, int arrowCode, color clr, int anchor)
{
   string n = ObjName(suffix);
   ObjectDelete(0, n);
   ObjectCreate(0, n, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, n, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, n, OBJPROP_ANCHOR, anchor);
}

void ObjRect(string suffix, datetime t1, double p1, datetime t2, double p2, color clr, bool fill=true)
{
   string n = ObjName(suffix);
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, n, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, n, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, n, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, n, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FILL, fill);
   ObjectSetInteger(0, n, OBJPROP_BACK, true);
}

void ObjLabel(string suffix, string txt, int x, int y, color clr, int fontSize=9)
{
   // CORNER_RIGHT_UPPER : XDISTANCE = distance depuis bord DROIT de l'écran.
   // On convertit la marge gauche originale (x=8) en offset depuis la droite :
   // le panneau commence à InpDashPanelWidth px du bord droit, la marge interne est x.
   int xRight = MathMax(4, InpDashPanelWidth - x);
   string n = ObjName(suffix);
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, xRight);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_RIGHT_UPPER);  // coin droit — ne chevauche pas SMC (gauche)
   ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);   // texte s'étend vers la droite
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
}

// Panel 2 — coin BAS-GAUCHE, y compté depuis le bas
void ObjLabel2(string suffix, string txt, int x, int y, color clr, int fontSize=8)
{
   string n = ObjName(suffix);
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
}

// Supprime tous les objets SR_ de ce symbole + labels panel 2
void ClearAllSRObjects()
{
   // Objets Deriv EA Pro
   ObjDel("EF5"); ObjDel("EF20");
   ObjDel("DynRes"); ObjDel("DynSup");
   ObjDel("RngHi"); ObjDel("RngLo"); ObjDel("RngZoneHi"); ObjDel("RngZoneLo");
   ObjDel("DerivSignal"); ObjDel("D_DerivStrat");

   // Panel 2 (coin bas-gauche) — noms sans préfixe SR_
   ObjectDelete(0, ObjName("D2_Title"));
   ObjectDelete(0, ObjName("D2_Empty"));
   for(int si = 0; si < 20; si++)
      ObjectDelete(0, ObjName("D2_Sym" + IntegerToString(si)));

   int total = ObjectsTotal(0);
   string prefix = "SR_" + _Symbol + "_";
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i);
      if(StringFind(nm, prefix) == 0) ObjectDelete(0, nm);
   }
}

// Handles indicateurs stratégies Deriv EA Pro
int g_hEMAEntry5  = INVALID_HANDLE;
int g_hEMAEntry20 = INVALID_HANDLE;

// État dernier signal Deriv EA Pro (pour affichage dashboard)
string   g_derivLastStrat  = "---";
ESpikeType g_derivLastSig  = SPIKE_NONE;
datetime   g_derivLastBar  = 0;   // bougie sur laquelle le signal a été évalué

//+------------------------------------------------------------------+
//| STRATÉGIES DERIV EA PRO                                          |
//+------------------------------------------------------------------+

// Copie close[shift=1..n] fermées dans un tableau
bool GetClosedBodies(double &out[], int n, int shiftStart = 1)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpTF, shiftStart, n, r) < n) return false;
   ArrayResize(out, n);
   for(int i = 0; i < n; i++) out[i] = r[i].close;
   return true;
}

// E — EMA 5/20 crossover (adapté Deriv stratSpikeBoom / stratEMAScalp)
// BUY : EMA5 croise au-dessus EMA20 + Boom | SELL : inverse + Crash
ESpikeType StratEMACross()
{
   if(!InpEnableEMACross) return SPIKE_NONE;
   if(g_hEMAEntry5 == INVALID_HANDLE || g_hEMAEntry20 == INVALID_HANDLE) return SPIKE_NONE;

   double fast[], slow[];
   ArraySetAsSeries(fast, true); ArraySetAsSeries(slow, true);
   if(CopyBuffer(g_hEMAEntry5,  0, 0, 3, fast) < 3) return SPIKE_NONE;
   if(CopyBuffer(g_hEMAEntry20, 0, 0, 3, slow) < 3) return SPIKE_NONE;

   // croisement sur bougie fermée [1] vs bougie précédente [2]
   bool crossUp   = fast[2] < slow[2] && fast[1] > slow[1];
   bool crossDown = fast[2] > slow[2] && fast[1] < slow[1];

   if(crossUp   && IsBoom(_Symbol))  return SPIKE_BUY;
   if(crossDown && IsCrash(_Symbol)) return SPIKE_SELL;
   return SPIKE_NONE;
}

// F — S&R Breakout dynamique (stratSRBreakout)
ESpikeType StratSRBreakout()
{
   if(!InpEnableSRBreakout) return SPIKE_NONE;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int need = InpSRLookbackBars + 2;
   if(CopyRates(_Symbol, InpTF, 1, need, r) < need) return SPIKE_NONE;

   double hi = r[0].high, lo = r[0].low;
   for(int i = 1; i < InpSRLookbackBars; i++)
   { hi = MathMax(hi, r[i].high); lo = MathMin(lo, r[i].low); }

   double atr = GetATR();
   double threshold = (atr > 0) ? atr * InpSRBreakoutATRMult : (hi - lo) * 0.02;
   double priceNow = iClose(_Symbol, InpTF, 1);
   double pricePrev = iClose(_Symbol, InpTF, 5);

   if(IsBoom(_Symbol) && priceNow > hi + threshold && pricePrev < hi)
      return SPIKE_BUY;
   if(IsCrash(_Symbol) && priceNow < lo - threshold && pricePrev > lo)
      return SPIKE_SELL;
   return SPIKE_NONE;
}

// G — Range Trading (stratRangeTrading)
ESpikeType StratRangeTrading()
{
   if(!InpEnableRangeTrading) return SPIKE_NONE;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpTF, 1, 60, r) < 60) return SPIKE_NONE;

   double rHigh = r[0].high, rLow = r[0].low;
   for(int i = 1; i < 60; i++)
   { rHigh = MathMax(rHigh, r[i].high); rLow = MathMin(rLow, r[i].low); }

   double amplitude = rHigh - rLow;
   if(amplitude <= 0) return SPIKE_NONE;
   double zone = amplitude * InpRangeZonePct;
   double price = iClose(_Symbol, InpTF, 1);

   if(IsCrash(_Symbol) && price >= rHigh - zone) return SPIKE_SELL;
   if(IsBoom(_Symbol)  && price <= rLow  + zone) return SPIKE_BUY;
   return SPIKE_NONE;
}

// H — RSI Divergence (stratRsiDivergence)
// Prix monte + RSI baisse → SELL (divergence baissière) | inverse → BUY
ESpikeType StratRSIDivergence()
{
   if(!InpEnableRSIDivergence) return SPIKE_NONE;
   if(g_hRSI == INVALID_HANDLE) return SPIKE_NONE;

   int half = InpDivLookback / 2;
   if(half < 5) return SPIKE_NONE;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpTF, 1, InpDivLookback * 2, r) < InpDivLookback * 2) return SPIKE_NONE;

   double rsiNow[1], rsiBuf[];
   ArraySetAsSeries(rsiNow, true); ArraySetAsSeries(rsiBuf, true);
   if(CopyBuffer(g_hRSI, 0, 1, 1, rsiNow) < 1) return SPIKE_NONE;
   if(CopyBuffer(g_hRSI, 0, InpDivLookback + 1, 1, rsiBuf) < 1) return SPIKE_NONE;

   double rsiCurr = rsiNow[0];
   double rsiPrev = rsiBuf[0];

   // Hauts et bas sur la fenêtre courante (1..half) vs précédente (half+1..half*2)
   double currHigh = r[0].high, prevHigh = r[half].high;
   double currLow  = r[0].low,  prevLow  = r[half].low;
   for(int i = 1; i < half; i++)
   { currHigh = MathMax(currHigh, r[i].high); currLow  = MathMin(currLow,  r[i].low); }
   for(int i = half; i < half * 2; i++)
   { prevHigh = MathMax(prevHigh, r[i].high); prevLow  = MathMin(prevLow,  r[i].low); }

   // Divergence baissière : prix monte mais RSI baisse (suracheté)
   if(IsCrash(_Symbol) && currHigh > prevHigh && rsiCurr < rsiPrev && rsiCurr > 60)
      return SPIKE_SELL;
   // Divergence haussière : prix baisse mais RSI monte (survendu)
   if(IsBoom(_Symbol) && currLow < prevLow && rsiCurr > rsiPrev && rsiCurr < 40)
      return SPIKE_BUY;
   return SPIKE_NONE;
}

// I — Pattern 1-2-3 (stratPattern123 adapté MQL5)
// Cherche 3 pivots locaux dans les InpPattern123Lookback dernières bougies fermées
ESpikeType StratPattern123()
{
   if(!InpEnablePattern123) return SPIKE_NONE;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int need = InpPattern123Lookback + 2;
   if(CopyRates(_Symbol, InpTF, 1, need, r) < need) return SPIKE_NONE;

   // Détecter 3 pivots alternants (haut/bas/haut ou bas/haut/bas) — fenêtre glissante
   int p1=-1, p2=-1, p3=-1;
   int n = MathMin(InpPattern123Lookback, ArraySize(r));

   for(int i = 2; i < n - 2; i++)
   {
      bool isHigh = (r[i].high > r[i+1].high && r[i].high > r[i+2].high &&
                     r[i].high > r[i-1].high && r[i].high > r[i-2].high);
      bool isLow  = (r[i].low  < r[i+1].low  && r[i].low  < r[i+2].low  &&
                     r[i].low  < r[i-1].low   && r[i].low  < r[i-2].low);

      if(isHigh && p1 < 0) { p1 = i; continue; }
      if(isLow  && p2 < 0 && p1 >= 0) { p2 = i; continue; }
      if(isHigh && p3 < 0 && p2 >= 0) { p3 = i; break; }
   }

   // Pattern 1-2-3 haussier (Boom) : p3 > p1 et p2 < p1
   if(IsBoom(_Symbol) && p1 >= 0 && p2 >= 0 && p3 >= 0)
   {
      if(r[p3].high > r[p1].high && r[p2].low < r[p1].low)
         return SPIKE_BUY;
   }

   // Reset pour pattern baissier (Crash)
   p1 = -1; p2 = -1; p3 = -1;
   for(int i = 2; i < n - 2; i++)
   {
      bool isLow  = (r[i].low  < r[i+1].low  && r[i].low  < r[i+2].low  &&
                     r[i].low  < r[i-1].low   && r[i].low  < r[i-2].low);
      bool isHigh = (r[i].high > r[i+1].high && r[i].high > r[i+2].high &&
                     r[i].high > r[i-1].high && r[i].high > r[i-2].high);

      if(isLow  && p1 < 0) { p1 = i; continue; }
      if(isHigh && p2 < 0 && p1 >= 0) { p2 = i; continue; }
      if(isLow  && p3 < 0 && p2 >= 0) { p3 = i; break; }
   }

   // Pattern 1-2-3 baissier (Crash) : p3 < p1 et p2 > p1
   if(IsCrash(_Symbol) && p1 >= 0 && p2 >= 0 && p3 >= 0)
   {
      if(r[p3].low < r[p1].low && r[p2].high > r[p1].high)
         return SPIKE_SELL;
   }

   return SPIKE_NONE;
}

// Données S/R historiques depuis RDS (chargées au démarrage + toutes les heures)
double   g_srLevels[];        // prix des niveaux S/R multi-TF
string   g_srLabels[];        // labels ("H1 R1", "D1 Pivot", etc.)
color    g_srColors[];        // couleur de chaque niveau
datetime g_lastSRFetch = 0;

// Données spikes historiques depuis RDS
datetime g_spikeTs[];         // timestamps des spikes passés
string   g_spikeDirs[];       // "BUY" ou "SELL"
bool     g_spikeCaptured[];   // profit capturé ou non
int      g_spikeCount = 0;
datetime g_lastSpikeLevelFetch = 0;

//+------------------------------------------------------------------+
//| CALCUL S/R MULTI-TF depuis bougies MT5                          |
//| H1 : Pivot PP, R1, R2, S1, S2                                   |
//| H4 : PP, R1, S1                                                 |
//| D1 : PP, R1, S1                                                 |
//+------------------------------------------------------------------+
void CalcSRLevels()
{
   // Ne recalculer qu'une fois par heure
   if(g_lastSRFetch != 0 && TimeCurrent() - g_lastSRFetch < 3600) return;
   g_lastSRFetch = TimeCurrent();

   // Supprimer les anciens niveaux
   int total = ObjectsTotal(0);
   string prefix = "SR_" + _Symbol + "_SR_";
   for(int i = total - 1; i >= 0; i--)
      if(StringFind(ObjectName(0, i), prefix) == 0) ObjectDelete(0, ObjectName(0, i));

   ArrayResize(g_srLevels,  0);
   ArrayResize(g_srLabels,  0);
   ArrayResize(g_srColors,  0);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // Calcule pivots pour un TF donné
   struct TFConfig { ENUM_TIMEFRAMES tf; string name; color clrR; color clrS; color clrP; };
   TFConfig tfs[3];
   tfs[0].tf=PERIOD_H1;  tfs[0].name="H1"; tfs[0].clrR=C'255,100,100'; tfs[0].clrS=C'100,200,100'; tfs[0].clrP=C'180,180,255';
   tfs[1].tf=PERIOD_H4;  tfs[1].name="H4"; tfs[1].clrR=C'220,60,60';   tfs[1].clrS=C'60,180,60';   tfs[1].clrP=C'140,140,220';
   tfs[2].tf=PERIOD_D1;  tfs[2].name="D1"; tfs[2].clrR=C'180,30,30';   tfs[2].clrS=C'30,150,30';   tfs[2].clrP=C'100,100,190';

   for(int t = 0; t < 3; t++)
   {
      MqlRates r[];
      ArraySetAsSeries(r, true);
      if(CopyRates(_Symbol, tfs[t].tf, 1, 2, r) < 2) continue;

      double H = r[1].high, L = r[1].low, C = r[1].close;
      double PP = (H + L + C) / 3.0;
      double R1 = 2*PP - L;
      double R2 = PP + (H - L);
      double S1 = 2*PP - H;
      double S2 = PP - (H - L);

      int    w  = (t == 0) ? 1 : (t == 1 ? 2 : 3);  // épaisseur selon TF
      ENUM_LINE_STYLE stPivot = STYLE_DASHDOT;
      ENUM_LINE_STYLE stRS    = STYLE_DOT;

      // PP
      string nPP = "SR_" + tfs[t].name + "_PP";
      ObjHLine(nPP, NormalizeDouble(PP, digits), tfs[t].clrP, stPivot, w);
      ObjectSetString(0, ObjName(nPP), OBJPROP_TEXT, tfs[t].name + " Pivot");

      // R1, R2 (uniquement H4/D1 pour R2)
      string nR1 = "SR_" + tfs[t].name + "_R1";
      ObjHLine(nR1, NormalizeDouble(R1, digits), tfs[t].clrR, stRS, w);
      ObjectSetString(0, ObjName(nR1), OBJPROP_TEXT, tfs[t].name + " R1");
      if(t >= 1)
      {
         string nR2 = "SR_" + tfs[t].name + "_R2";
         ObjHLine(nR2, NormalizeDouble(R2, digits), tfs[t].clrR, STYLE_DOT, w);
         ObjectSetString(0, ObjName(nR2), OBJPROP_TEXT, tfs[t].name + " R2");
      }

      // S1, S2
      string nS1 = "SR_" + tfs[t].name + "_S1";
      ObjHLine(nS1, NormalizeDouble(S1, digits), tfs[t].clrS, stRS, w);
      ObjectSetString(0, ObjName(nS1), OBJPROP_TEXT, tfs[t].name + " S1");
      if(t >= 1)
      {
         string nS2 = "SR_" + tfs[t].name + "_S2";
         ObjHLine(nS2, NormalizeDouble(S2, digits), tfs[t].clrS, STYLE_DOT, w);
         ObjectSetString(0, ObjName(nS2), OBJPROP_TEXT, tfs[t].name + " S2");
      }
   }
}

//+------------------------------------------------------------------+
//| FETCH SPIKES HISTORIQUES depuis RDS via /spike/levels           |
//+------------------------------------------------------------------+
void FetchSpikeLevels()
{
   if(!InpUsePrior) return;
   if(g_lastSpikeLevelFetch != 0 && TimeCurrent() - g_lastSpikeLevelFetch < 3600) return;

   string url = InpAIServerURL + "/spike/levels?symbol=" + _Symbol + "&limit=50";
   string headers = "Content-Type: application/json\r\n";
   char   post[], result[];
   string respHeaders;

   int code = WebRequest("GET", url, headers, InpPriorTimeoutMs * 3, post, result, respHeaders);
   if(code != 200) return;

   string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);

   // Parser le tableau "spikes" — chercher les champs ts, direction, captured
   // Format: {"spikes":[{"ts":"2026-05-18T18:26:31+00:00","direction":"SELL","captured":true,"atr_mult":1.8},...]}
   g_spikeCount = 0;
   ArrayResize(g_spikeTs,       50);
   ArrayResize(g_spikeDirs,     50);
   ArrayResize(g_spikeCaptured, 50);

   int pos = StringFind(body, "\"spikes\":[");
   if(pos < 0) return;
   pos += 10;

   while(g_spikeCount < 50)
   {
      int objStart = StringFind(body, "{", pos);
      int objEnd   = StringFind(body, "}", objStart);
      if(objStart < 0 || objEnd < 0) break;

      string obj   = StringSubstr(body, objStart, objEnd - objStart + 1);
      string ts    = JsonExtractString(obj, "ts");
      string dir   = JsonExtractString(obj, "direction");
      bool   cap   = JsonExtractBool(obj, "captured");

      if(StringLen(ts) >= 19)
      {
         // Convertir ISO "2026-05-18T18:26:31" en datetime MT5
         string dtPart = StringSubstr(ts, 0, 19);
         StringReplace(dtPart, "T", " ");
         datetime dt = StringToTime(dtPart);
         if(dt > 0)
         {
            g_spikeTs[g_spikeCount]       = dt;
            g_spikeDirs[g_spikeCount]     = dir;
            g_spikeCaptured[g_spikeCount] = cap;
            g_spikeCount++;
         }
      }
      pos = objEnd + 1;
      if(StringGetCharacter(body, pos) == ']') break;
   }

   g_lastSpikeLevelFetch = TimeCurrent();
   if(InpDebug) PrintFormat("[SpikeRider] %d niveaux spike chargés depuis RDS", g_spikeCount);
}

//+------------------------------------------------------------------+
//| DESSIN DES MARQUEURS SPIKES HISTORIQUES                          |
//+------------------------------------------------------------------+
void DrawSpikeHistoryMarkers()
{
   if(g_spikeCount <= 0) return;

   // Supprimer anciens marqueurs
   int total = ObjectsTotal(0);
   string prefix = "SR_" + _Symbol + "_SPK_";
   for(int i = total - 1; i >= 0; i--)
      if(StringFind(ObjectName(0, i), prefix) == 0) ObjectDelete(0, ObjectName(0, i));

   for(int i = 0; i < g_spikeCount; i++)
   {
      datetime ts  = g_spikeTs[i];
      string   dir = g_spikeDirs[i];
      bool     cap = g_spikeCaptured[i];

      // Retrouver le prix MT5 à ce timestamp
      MqlRates r[];
      if(CopyRates(_Symbol, InpTF, ts, 1, r) < 1) continue;
      double px = (dir == "BUY") ? r[0].low : r[0].high;

      // Couleur : vert = capturé, rouge = manqué
      color clr  = cap ? C'0,200,100' : C'200,60,60';
      int   code = (dir == "BUY") ? 233 : 234;
      int   anchor = (dir == "BUY") ? ANCHOR_TOP : ANCHOR_BOTTOM;
      double offset = (dir == "BUY") ? -r[0].low * 0.0005 : r[0].high * 0.0005;

      string suf = "SPK_" + IntegerToString(i);
      ObjArrow(suf, ts, px + offset, code, clr, anchor);
      // Réduire la taille pour ne pas encombrer
      ObjectSetInteger(0, ObjName(suf), OBJPROP_WIDTH, 1);
   }
}

//+------------------------------------------------------------------+
//| DESSIN GRAPHIQUE — Indicateurs visuels stratégie                 |
//+------------------------------------------------------------------+
void DrawChartIndicators(const SpikeResult &spike, double imminence)
{
   if(!InpShowDashboard) return;

   bool   isBoom  = IsBoom(_Symbol);
   double atr     = spike.atr;
   double atrMean = GetATRMean();
   double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price   = isBoom ? ask : bid;
   int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // ── 1. S/R MULTI-TF (H1 / H4 / D1 pivots) ─────────────────────
   CalcSRLevels();

   // ── 2. MARQUEURS SPIKES HISTORIQUES RDS ────────────────────────
   FetchSpikeLevels();
   DrawSpikeHistoryMarkers();

   // ── 3. FIB / OTE / BOS (SMC) ───────────────────────────────────
   UpdateSMCContext();
   if(InpDrawSMCLevels && g_smc.valid)
   {
      ObjHLine("FIB50",  NormalizeDouble(g_smc.fib50,  digits), clrGold,       STYLE_DASH, 1);
      ObjHLine("FIB618", NormalizeDouble(g_smc.fib618, digits), clrOrange,    STYLE_SOLID, 2);
      ObjHLine("FIB786", NormalizeDouble(g_smc.fib786, digits), clrOrangeRed, STYLE_SOLID, 2);
      ObjHLine("OTEL",   NormalizeDouble(g_smc.oteLow,  digits), clrDodgerBlue, STYLE_DOT, 1);
      ObjHLine("OTEH",   NormalizeDouble(g_smc.oteHigh, digits), clrDodgerBlue, STYLE_DOT, 1);
      if(g_smc.breakLevel > 0.0)
         ObjHLine("BOS", NormalizeDouble(g_smc.breakLevel, digits),
                  g_smc.bos ? clrLime : clrGray, STYLE_SOLID, 2);
      ObjRect("OTEZONE", iTime(_Symbol, InpTF, 8), g_smc.oteLow,
              iTime(_Symbol, InpTF, 0) + PeriodSeconds(InpTF) * 3, g_smc.oteHigh,
              C'30,60,120', true);
   }
   else
   {
      ObjDel("FIB50"); ObjDel("FIB618"); ObjDel("FIB786");
      ObjDel("OTEL"); ObjDel("OTEH"); ObjDel("BOS"); ObjDel("OTEZONE");
   }

   // ── 4. SL / TP projetés (si chart stops) ───────────────────────
   if(InpUseChartStops && atr > 0)
   {
      double slDist = atr * InpSL_ATR;
      double tpDist = atr * InpTP_ATR;
      if(isBoom)
      {
         ObjHLine("SL", NormalizeDouble(price - slDist, digits), clrTomato,    STYLE_DOT, 2);
         ObjHLine("TP", NormalizeDouble(price + tpDist, digits), clrLimeGreen, STYLE_DOT, 2);
      }
      else
      {
         ObjHLine("SL", NormalizeDouble(price + slDist, digits), clrTomato,    STYLE_DOT, 2);
         ObjHLine("TP", NormalizeDouble(price - tpDist, digits), clrLimeGreen, STYLE_DOT, 2);
      }
   }
   else { ObjDel("SL"); ObjDel("TP"); }

   // ── 4. ZONE ATR COMPRESSION ────────────────────────────────────
   bool compressed = (atr > 0 && atrMean > 0 && atr < atrMean * InpAtrCompressRatio);
   if(compressed)
   {
      MqlRates r[];
      ArraySetAsSeries(r, true);
      int nb = MathMin(InpLookback, 20);
      if(CopyRates(_Symbol, InpTF, 0, nb + 1, r) >= nb)
      {
         datetime t1 = r[nb].time;
         datetime t2 = r[0].time + PeriodSeconds(InpTF);
         double lo = r[0].low, hi = r[0].high;
         for(int i = 1; i < nb; i++) { lo = MathMin(lo, r[i].low); hi = MathMax(hi, r[i].high); }
         ObjRect("CompressZone", t1, lo, t2, hi, C'40,40,60', true);
      }
   }
   else ObjDel("CompressZone");

   // ── 5. BOUGIES ESCALIER ─────────────────────────────────────────
   {
      MqlRates r[];
      ArraySetAsSeries(r, true);
      if(CopyRates(_Symbol, InpTF, 1, InpStairBars + 2, r) >= InpStairBars + 1)
      {
         for(int i = 0; i < InpStairBars; i++)
         {
            double body = r[i].close - r[i].open;
            bool aligned = isBoom ? (body > 0) : (body < 0);
            string suf = "Stair" + IntegerToString(i);
            if(aligned)
            {
               color clr = isBoom ? C'60,100,180' : C'180,100,30';
               ObjRect(suf, r[i].time, r[i].low, r[i].time + PeriodSeconds(InpTF), r[i].high, clr, false);
            }
            else ObjDel(suf);
         }
      }
   }

   // ── 6. FLÈCHE CLIGNOTANTE : pré-spike (alerte) + spike confirmé + trade ouvert ──
   {
      MqlRates r[];
      ArraySetAsSeries(r, true);
      bool hasBars = (CopyRates(_Symbol, InpTF, 0, 3, r) >= 3);
      bool boomSide  = IsBoom(_Symbol);
      bool hasPosition = HasPosition();

      // Clignote si : imminence suffisante OU spike détecté OU trade ouvert
      bool shouldBlink = hasBars && (imminence >= 40.0 || spike.type != SPIKE_NONE || hasPosition);

      if(shouldBlink)
      {
         color  c1 = boomSide ? clrDeepSkyBlue : clrOrange;
         color  c2 = boomSide ? clrDodgerBlue  : clrGold;
         // Couleur plus vive pendant spike confirmé ou trade ouvert
         if(spike.type != SPIKE_NONE || hasPosition)
         {
            c1 = boomSide ? clrAqua   : clrOrangeRed;
            c2 = boomSide ? clrYellow : clrRed;
         }
         // Clignotement : alterner chaque seconde (modulo 2)
         color  blinkClr = ((TimeCurrent() % 2) == 0) ? c1 : c2;
         int    code     = boomSide ? 233 : 234;
         int    anchor   = boomSide ? ANCHOR_TOP : ANCHOR_BOTTOM;
         // Flèche sur la bougie courante (spike/trade) ou bougie future (pré-spike)
         datetime arrowTime;
         double   arrowPx;
         int      arrowWidth;
         // Flèche sur bougie COURANTE dès que l'imminence atteint le seuil d'action
         // (pré-spike OU spike confirmé OU position ouverte)
         bool actionNow = (spike.type != SPIKE_NONE || hasPosition ||
                           imminence >= InpImminenceThresh);
         if(actionNow)
         {
            arrowTime  = r[0].time;
            arrowPx    = boomSide
                         ? r[0].low  - atr * 0.6
                         : r[0].high + atr * 0.6;
            arrowWidth = (imminence >= 70.0 || spike.type != SPIKE_NONE || hasPosition) ? 5 : 3;
         }
         else
         {
            // Imminence basse (40-seuil) : alerte précoce sur bougie future, pas d'action
            arrowTime  = r[0].time + PeriodSeconds(InpTF);
            arrowPx    = boomSide
                         ? r[0].low  - atr * (0.3 + imminence / 200.0)
                         : r[0].high + atr * (0.3 + imminence / 200.0);
            arrowWidth = (int)(2 + imminence / 33.0);
         }
         ObjArrow("SpikeArrow", arrowTime, arrowPx, code, blinkClr, anchor);
         ObjectSetInteger(0, ObjName("SpikeArrow"), OBJPROP_WIDTH, arrowWidth);
         ObjDel("PreSpikeArrow");  // une seule flèche unifiée
      }
      else
      {
         ObjDel("SpikeArrow");     // imminence trop basse — pas d'alerte
         ObjDel("PreSpikeArrow");
      }
   }

   // ── 7. BANDE ATR MOYENNE ────────────────────────────────────────
   if(atrMean > 0 && price > 0)
   {
      ObjHLine("ATRHi", NormalizeDouble(price + atrMean, digits), C'70,70,110', STYLE_DASHDOT, 1);
      ObjHLine("ATRLo", NormalizeDouble(price - atrMean, digits), C'70,70,110', STYLE_DASHDOT, 1);
      ObjectSetString(0, ObjName("ATRHi"), OBJPROP_TEXT, "ATR+");
      ObjectSetString(0, ObjName("ATRLo"), OBJPROP_TEXT, "ATR-");
   }

   // ── 9. STRATÉGIES DERIV EA PRO — lignes visuelles ───────────────
   // EMA Entry 5 / EMA Entry 20
   if(InpEnableEMACross && g_hEMAEntry5 != INVALID_HANDLE && g_hEMAEntry20 != INVALID_HANDLE)
   {
      double eF[], eS[];
      ArraySetAsSeries(eF, true); ArraySetAsSeries(eS, true);
      if(CopyBuffer(g_hEMAEntry5,  0, 0, 2, eF) >= 2 && CopyBuffer(g_hEMAEntry20, 0, 0, 2, eS) >= 2)
      {
         ObjHLine("EF5",  NormalizeDouble(eF[0], digits), C'0,229,160',  STYLE_SOLID, 1);
         ObjHLine("EF20", NormalizeDouble(eS[0], digits), C'0,102,255',  STYLE_SOLID, 1);
         ObjectSetString(0, ObjName("EF5"),  OBJPROP_TEXT, "EMA5");
         ObjectSetString(0, ObjName("EF20"), OBJPROP_TEXT, "EMA20");
      }
   }
   else { ObjDel("EF5"); ObjDel("EF20"); }

   // S&R dynamique (50 bougies fermées)
   if(InpEnableSRBreakout)
   {
      MqlRates rSR[];
      ArraySetAsSeries(rSR, true);
      int srN = InpSRLookbackBars;
      if(CopyRates(_Symbol, InpTF, 1, srN, rSR) >= srN)
      {
         double srHi = rSR[0].high, srLo = rSR[0].low;
         for(int i = 1; i < srN; i++)
         { srHi = MathMax(srHi, rSR[i].high); srLo = MathMin(srLo, rSR[i].low); }
         ObjHLine("DynRes", NormalizeDouble(srHi, digits), C'255,170,0', STYLE_DASH, 2);
         ObjHLine("DynSup", NormalizeDouble(srLo, digits), C'255,170,0', STYLE_DASH, 2);
         ObjectSetString(0, ObjName("DynRes"), OBJPROP_TEXT, StringFormat("Résistance(%d)", srN));
         ObjectSetString(0, ObjName("DynSup"), OBJPROP_TEXT, StringFormat("Support(%d)", srN));
      }
   }
   else { ObjDel("DynRes"); ObjDel("DynSup"); }

   // Zone Range (haut/bas des 60 bougies)
   if(InpEnableRangeTrading)
   {
      MqlRates rRng[];
      ArraySetAsSeries(rRng, true);
      if(CopyRates(_Symbol, InpTF, 1, 60, rRng) >= 60)
      {
         double rHi = rRng[0].high, rLo = rRng[0].low;
         for(int i = 1; i < 60; i++)
         { rHi = MathMax(rHi, rRng[i].high); rLo = MathMin(rLo, rRng[i].low); }
         double amp  = rHi - rLo;
         double zone = amp * InpRangeZonePct;
         bool   isCrash_ = IsCrash(_Symbol);
         color  zClrH = isCrash_ ? C'255,68,68' : C'100,100,100';
         color  zClrL = isBoom   ? C'0,201,122' : C'100,100,100';
         ObjHLine("RngHi",    NormalizeDouble(rHi,         digits), C'168,85,247', STYLE_DOT, 1);
         ObjHLine("RngLo",    NormalizeDouble(rLo,         digits), C'168,85,247', STYLE_DOT, 1);
         ObjHLine("RngZoneHi",NormalizeDouble(rHi - zone,  digits), zClrH, STYLE_DOT, 1);
         ObjHLine("RngZoneLo",NormalizeDouble(rLo + zone,  digits), zClrL, STYLE_DOT, 1);
         ObjectSetString(0, ObjName("RngHi"),    OBJPROP_TEXT, "Range Hi");
         ObjectSetString(0, ObjName("RngLo"),    OBJPROP_TEXT, "Range Lo");
         ObjectSetString(0, ObjName("RngZoneHi"),OBJPROP_TEXT, "Zone SELL");
         ObjectSetString(0, ObjName("RngZoneLo"),OBJPROP_TEXT, "Zone BUY");
      }
   }
   else { ObjDel("RngHi"); ObjDel("RngLo"); ObjDel("RngZoneHi"); ObjDel("RngZoneLo"); }

   // Flèche signal Deriv EA Pro sur la dernière bougie fermée
   {
      ObjDel("DerivSignal");
      if(g_derivLastSig != SPIKE_NONE && g_derivLastBar > 0)
      {
         MqlRates rD[];
         ArraySetAsSeries(rD, true);
         if(CopyRates(_Symbol, InpTF, g_derivLastBar, 1, rD) >= 1)
         {
            bool buyDir = (g_derivLastSig == SPIKE_BUY);
            double px = buyDir ? rD[0].low - atr * 0.4 : rD[0].high + atr * 0.4;
            int code = buyDir ? 233 : 234;
            int anchor = buyDir ? ANCHOR_TOP : ANCHOR_BOTTOM;
            color clr = buyDir ? C'0,229,160' : C'255,107,53';
            ObjArrow("DerivSignal", g_derivLastBar, px, code, clr, anchor);
            ObjectSetInteger(0, ObjName("DerivSignal"), OBJPROP_WIDTH, 2);
         }
      }
   }

   // ── 8. PANEL DASHBOARD (coins haut-gauche, labels empilés) ──────
   // Supprimer les labels conditionnels à chaque cycle pour éviter le chevauchement
   ObjDel("D_Prior");
   ObjDel("D_TVBridge");
   ObjDel("D_TVStruct");

   int yBase = 20;   // point de départ Y
   int yStep = 16;   // espacement entre lignes

   // Titre
   ObjLabel("D_Title",  "-- SpikeRider v5 SMC -- " + _Symbol + " --", 8, yBase, clrWhite, 9);
   yBase += yStep + 4;

   // Compte
   double bal  = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq   = AccountInfoDouble(ACCOUNT_EQUITY);
   int    nPos = CountOurPositions();
   double dayLoss = (g_dayStartBalance > 0) ? (g_dayStartBalance - bal) / g_dayStartBalance * 100.0 : 0.0;
   color  balClr  = (dayLoss > 3.0) ? clrTomato : clrSilver;
   ObjLabel("D_Acct", StringFormat("Bal $%.2f | Eq $%.2f | Pos:%d | DayLoss:%.1f%%",
            bal, eq, nPos, dayLoss), 8, yBase, balClr, 9);
   yBase += yStep;

   // Signaux détection
   color zClr = (MathAbs(spike.zScore) >= g_priorAtrThreshold) ? clrYellow : clrDimGray;
   ObjLabel("D_Detect", StringFormat("Z=%.2f  RSI=%.0f  ATR=%.1f  Stair=%.0f%%  Compress=%s",
            spike.zScore, spike.rsi, atr, spike.stairScore * 100,
            compressed ? "OUI" : "non"), 8, yBase, zClr, 9);
   yBase += yStep;

   // Jauge imminence
   color gaugeClr;
   if(imminence >= 85.0)      gaugeClr = clrOrangeRed;
   else if(imminence >= 70.0) gaugeClr = clrOrange;
   else if(imminence >= 40.0) gaugeClr = clrGold;
   else                       gaugeClr = clrDodgerBlue;
   string bar = "";
   int filled = (int)(imminence / 10.0);
   for(int i = 0; i < 10; i++) bar += (i < filled ? "|" : ".");
   ObjLabel("D_Gauge", StringFormat("Imminence [%s] %.0f%%", bar, imminence), 8, yBase, gaugeClr, 10);
   yBase += yStep;

   // Compteur inter-spike
   int effFreq = GetEffectiveSpikeFrequency();
   double progress = (effFreq > 0)
                     ? MathMin((double)g_barsSinceLastSpike / (double)effFreq * 100.0, 100.0)
                     : 0.0;
   color  cntClr = (progress >= 80.0) ? clrYellow : clrDimGray;
   ObjLabel("D_Counter", StringFormat("Barres: %d/%d (%.0f%%) | Spread: %d",
            g_barsSinceLastSpike, effFreq, progress,
            (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)), 8, yBase, cntClr, 9);
   yBase += yStep;

   // Prior horaire RDS
   if(InpUsePrior && g_lastPriorFetch != 0)
   {
      color  priorClr = g_priorFavorable ? clrLimeGreen : clrTomato;
      ObjLabel("D_Prior", StringFormat("Prior %02d:00 | Cap=%.0f%% ATR=%.2f N=%d | %s [%s]",
               g_lastPriorHour, g_priorCaptureRate * 100, g_priorAtrMult, g_priorSampleCount,
               (g_priorFavorable ? "FAVORABLE" : "DEFAVOR"), g_priorSource), 8, yBase, priorClr, 9);
      yBase += yStep;
   }

   // Angel + Zone + Realtime
   color angelClr = (g_angelSignal == "HOLD") ? clrDimGray :
                    ((IsBoom(_Symbol) && g_angelSignal == "BUY") ||
                     (IsCrash(_Symbol) && g_angelSignal == "SELL")) ? clrLimeGreen : clrTomato;
   ObjLabel("D_Angel", StringFormat("Angel=%s(%.0f%%) | Zone=%.2f | RT=%s",
            g_angelSignal, g_angelConfidence, g_zonePrior,
            g_realtimeSpikeActive ? "SPIKE!" : "---"), 8, yBase, angelClr, 9);
   yBase += yStep;

   // TradingView bridge (sniper / OB / EMA)
   if(InpUseTVBridge)
   {
      color tvClr = g_tvSniperReady ? clrLimeGreen :
                    (g_tvCounterTrend ? clrTomato : clrGold);
      int ageTv = (g_lastSpikeTVFetch > 0) ? (int)(TimeCurrent() - g_lastSpikeTVFetch) : -1;
      ObjLabel("D_TVBridge",
               StringFormat("TV %s | Sniper %s %.0f%% | imm=%.0f%% | Z=%.2f | OB=%s EMA=%s | %ds",
                            g_tvDirection,
                            (g_tvSniperReady ? "READY" : "---"),
                            g_tvSniperConfidence, g_tvImminencePct, g_tvSpikeZ,
                            g_tvObBias, g_tvEmaTrend, ageTv),
               8, yBase, tvClr, 9);
      yBase += yStep;
      ObjLabel("D_TVStruct",
               StringFormat("M15=%s H1=%s | spike=%s | CT=%s",
                            g_tvStructureM15, g_tvStructureH1,
                            (g_tvSpikeDetected ? g_tvSpikeDir : "non"),
                            (g_tvCounterTrend ? "BLOQUE" : "ok")),
               8, yBase, tvClr, 8);
      yBase += yStep;
   }

   // SL/TP en cours
   if(atr > 0)
   {
      double slDist = atr * InpSL_ATR;
      double tpDist = atr * InpTP_ATR;
      ObjLabel("D_SLTP", StringFormat("SL=%.1f pts | TP=%.1f pts | RR=%.1f",
               slDist / SymbolInfoDouble(_Symbol, SYMBOL_POINT),
               tpDist / SymbolInfoDouble(_Symbol, SYMBOL_POINT),
               InpTP_ATR / InpSL_ATR), 8, yBase, clrSilver, 9);
      yBase += yStep;
   }

   // Stratégies Deriv EA Pro — signal actif
   ObjDel("D_DerivStrat");
   {
      color derivClr = (g_derivLastSig == SPIKE_BUY)  ? clrLimeGreen :
                       (g_derivLastSig == SPIKE_SELL) ? clrOrangeRed : clrDimGray;
      string derivTxt = StringFormat("DerivStrat: %s %s | EMA=%s SR=%s Rng=%s Div=%s P123=%s",
                                     g_derivLastStrat,
                                     (g_derivLastSig == SPIKE_BUY ? "▲" : g_derivLastSig == SPIKE_SELL ? "▼" : "—"),
                                     (InpEnableEMACross      ? "ON" : "off"),
                                     (InpEnableSRBreakout    ? "ON" : "off"),
                                     (InpEnableRangeTrading  ? "ON" : "off"),
                                     (InpEnableRSIDivergence ? "ON" : "off"),
                                     (InpEnablePattern123    ? "ON" : "off"));
      ObjLabel("D_DerivStrat", derivTxt, 8, yBase, derivClr, 9);
      yBase += yStep;
   }

   // Légende spikes historiques
   ObjLabel("D_HistLeg", StringFormat("Hist. RDS: %d spikes | vert=capturé  rouge=manqué", g_spikeCount),
            8, yBase, C'140,140,140', 8);
   yBase += yStep;

   // Légende S/R
   ObjLabel("D_SRLeg",
            "S/R: H1(fin) H4(med) D1(epais)  PP=tiret-pt  R=rouge  S=vert",
            8, yBase, C'120,120,120', 8);
   yBase += yStep + 4;

   // ── PANEL 2 : MULTI-SYMBOLE — coin BAS-GAUCHE ──────────────────
   // Purger tous les anciens labels D2_* avant redessin
   ObjDel("D2_Title");
   ObjDel("D2_Empty");
   for(int si = 0; si < 20; si++)
      ObjDel("D2_Sym" + IntegerToString(si));

   // y2 croît depuis le bas : ligne 0 = toute en bas, ligne 1 = au-dessus, etc.
   // On commence par compter combien de lignes on va dessiner pour placer le titre en premier
   int nLines   = (g_symCount > 0) ? g_symCount : 1;
   int y2Step   = 14;
   int y2Bottom = 8;   // marge basse

   // Titre (ligne la plus haute du bloc = index le plus grand)
   int y2Title = y2Bottom + (nLines + 1) * y2Step;
   ObjLabel2("D2_Title", "--- Multi-Symboles Actifs ---", 8, y2Title, C'160,160,200', 8);

   if(g_symCount == 0)
   {
      ObjLabel2("D2_Empty", "Aucun symbole Boom/Crash dans Market Watch",
                8, y2Bottom + y2Step, clrDimGray, 8);
   }
   else
   {
      // Premier symbole = ligne tout en bas (y2Bottom + y2Step)
      // Dernier symbole = juste sous le titre
      for(int si = 0; si < g_symCount; si++)
      {
         string nm   = g_syms[si].sym;
         bool   boom = g_syms[si].isBoom;
         int    bars = g_syms[si].barsSince;
         int    freq = 600;
         const string nums[] = {"1000","900","600","500","300"};
         for(int ni = 0; ni < 5; ni++)
            if(StringFind(nm, nums[ni]) >= 0) { freq = (int)StringToInteger(nums[ni]); break; }
         double pct  = (freq > 0) ? MathMin((double)bars / (double)freq * 100.0, 100.0) : 0.0;
         color  sClr = (pct >= 80.0) ? clrYellow : (pct >= 50.0 ? clrGold : clrDimGray);
         string symLbl = StringFormat("%-22s %s  %3d/%d (%.0f%%)",
                                      nm, boom ? "BUY " : "SELL", bars, freq, pct);
         // si=0 → y le plus bas, si=nLines-1 → y le plus haut (juste sous titre)
         int yPos = y2Bottom + (si + 1) * y2Step;
         ObjLabel2("D2_Sym" + IntegerToString(si), symLbl, 8, yPos, sClr, 8);
      }
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| DASHBOARD (conservé pour compat — ne fait plus rien)            |
//+------------------------------------------------------------------+
void UpdateDashboard(const SpikeResult &spike, double imminence)
{
   // Tout est maintenant dans DrawChartIndicators (labels positionnés)
   if(!InpShowDashboard) return;
   bool isBoom  = IsBoom(_Symbol);
   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq    = AccountInfoDouble(ACCOUNT_EQUITY);
   int    nPos  = CountOurPositions();
   string pos   = StringFormat("%d/1%s", nPos, HasPendingOrder() ? "+PENDING" : "");
   double dayLoss = (g_dayStartBalance > 0)
                    ? (g_dayStartBalance - bal) / g_dayStartBalance * 100.0 : 0.0;

   string bar = "";
   int filled = (int)(imminence / 10.0);
   for(int i=0; i<10; i++) bar += (i < filled ? "|" : ".");

   UpdateSMCContext();
   string l1 = StringFormat("[SpikeRider v5] %s | Bal=$%.2f | %s | push=%d",
                              (isBoom?"BOOM":"CRASH"), bal, g_smc.tag, GetMicroTrendPush(3));
   string l2 = StringFormat("Z=%.2f  RSI=%.1f  ATR=%.5f  Stair=%.2f",
                              spike.zScore, spike.rsi, spike.atr, spike.stairScore);
   string l3 = StringFormat("Imminence [%s] %.0f%%  | Barres depuis spike: %d/%d",
                              bar, imminence, g_barsSinceLastSpike, GetEffectiveSpikeFrequency());
   string l4 = StringFormat("Spread=%d | DayLoss=%.2f%% | Angel=%s(%.0f%%) Zone=%.2f RT=%s",
                              (int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD), dayLoss,
                              g_angelSignal, g_angelConfidence, g_zonePrior,
                              (g_realtimeSpikeActive?"SPIKE!":"---"));
   string l5 = "";
   if(InpUsePrior && g_lastPriorFetch != 0)
      l5 = StringFormat("Prior %02d:00UTC cap=%.0f%% atr=%.2f thr=%.2f n=%d [%s] %s",
                         g_lastPriorHour, g_priorCaptureRate*100, g_priorAtrMult,
                         g_priorAtrThreshold, g_priorSampleCount,
                         (g_priorFavorable?"FAV":"DEF"), g_priorSource);
   // Commentaire supprimé — affichage via labels OBJ_LABEL dans DrawChartIndicators
}

//+------------------------------------------------------------------+
//| OnTradeTransaction : feedback immédiat à la fermeture           |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &,
                        const MqlTradeResult &)
{
   // On s'intéresse uniquement aux deals de fermeture de position
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != (long)InpMagic) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) return;

   ulong posTicket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int idx = FindOpenTradeIdx(posTicket);

   double profit    = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                    + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                    + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   double exitPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);

   // Si le pending a été rempli -> enregistrer le trade dans notre tableau
   if(g_pendingTicket != 0 && idx < 0)
   {
      // Le pending a été rempli, rechercher par position
      if(HistoryDealGetInteger(trans.deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
      {
         // Ouverture via pending — on le note mais on n'envoie pas de feedback ici
         g_pendingTicket = 0;
         g_pendingPlacedAt = 0;
         return;
      }
   }

   if(idx < 0)
   {
      if(InpDebug) PrintFormat("[SpikeRider] OnTradeTransaction: deal %llu non suivi", trans.deal);
      return;
   }

   TradeRecord rec = g_openTrades[idx];
   RemoveOpenTradeAt(idx);

   if(CountOurPositions() == 0)
   {
      // Forcer le cooldown après fermeture — empêche réentrée dans le même tick
      g_lastTrade       = TimeCurrent();
      g_entrySlotLocked = true;   // restera vrai jusqu'à expiry cooldown dans SyncEntrySlotLock
      ReleaseSymbolEntryLock();
   }

   // Spike confirmé → réinitialiser compteur + notif
   g_barsSinceLastSpike = 0;
   g_lastSpikeBar       = TimeCurrent();
   ResetNotifState();

   // Reset aussi dans le contexte multi-symbole si le symbole correspond
   for(int si = 0; si < g_symCount; si++)
      if(g_syms[si].sym == _Symbol) g_syms[si].barsSince = 0;

   PostTradeFeedback(rec, exitPrice, profit);
}

//+------------------------------------------------------------------+
//| SCAN MARKET WATCH — charger tous les Boom/Crash disponibles     |
//+------------------------------------------------------------------+
void ScanMarketWatchSymbols()
{
   g_symCount = 0;
   int total = SymbolsTotal(true);  // true = Market Watch uniquement
   for(int i = 0; i < total && g_symCount < 20; i++)
   {
      string s = SymbolName(i, true);
      if(!IsSupportedSymbol(s)) continue;

      // Vérifier que le symbole n'est pas déjà ajouté
      bool dup = false;
      for(int k = 0; k < g_symCount; k++) if(g_syms[k].sym == s) { dup = true; break; }
      if(dup) continue;

      g_syms[g_symCount].sym        = s;
      g_syms[g_symCount].isBoom     = IsBoom(s);
      g_syms[g_symCount].barsSince  = 0;
      g_syms[g_symCount].lastBar    = 0;
      g_syms[g_symCount].lastTrade  = 0;
      g_syms[g_symCount].lastEntryFail  = 0;
      g_syms[g_symCount].lastEntryBarTime = 0;
      g_syms[g_symCount].hATR       = iATR(s, InpTF, InpATRPeriod);
      g_syms[g_symCount].hRSI       = iRSI(s, InpTF, InpRSIPeriod, PRICE_CLOSE);
      g_syms[g_symCount].hEMAFast   = iMA(s, InpTF, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
      g_syms[g_symCount].hEMASlow   = iMA(s, InpTF, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
      g_symCount++;
   }
   PrintFormat("[SpikeRider] %d symboles Boom/Crash détectés dans Market Watch", g_symCount);
}

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!IsSupportedSymbol(_Symbol))
      Print("[SpikeRider] ⚠️ Symbole chart non supporté (normal si multi-symb): ", _Symbol);

   g_hATR = iATR(_Symbol, InpTF, InpATRPeriod);
   g_hRSI = iRSI(_Symbol, InpTF, InpRSIPeriod, PRICE_CLOSE);
   g_hEMAFast = iMA(_Symbol, InpTF, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMASlow = iMA(_Symbol, InpTF, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hATR == INVALID_HANDLE || g_hRSI == INVALID_HANDLE ||
      g_hEMAFast == INVALID_HANDLE || g_hEMASlow == INVALID_HANDLE)
   {
      Print("[SpikeRider] ❌ Erreur création indicateurs chart principal");
      return INIT_FAILED;
   }

   // Handles stratégies Deriv EA Pro
   g_hEMAEntry5  = iMA(_Symbol, InpTF, InpEMAEntryFast, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMAEntry20 = iMA(_Symbol, InpTF, InpEMAEntrySlow, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hEMAEntry5 == INVALID_HANDLE || g_hEMAEntry20 == INVALID_HANDLE)
   {
      Print("[SpikeRider] ❌ Erreur création indicateurs Deriv EA Pro");
      return INIT_FAILED;
   }

   // Scanner tous les Boom/Crash du Market Watch
   ScanMarketWatchSymbols();

   g_trade.SetExpertMagicNumber(InpMagic);
   g_dayStartBalance    = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dayTag             = 0;
   g_barsSinceLastSpike = 0;
   g_lastSpikeBar       = 0;
   g_pendingTicket      = 0;
   g_openTradesCount    = 0;
   g_lastPriorFetch     = 0; g_lastPriorAttempt   = 0; g_lastPriorHour   = -1;
   g_lastZoneFetch      = 0; g_lastZoneAttempt    = 0; g_lastZoneHour    = -1;
   g_lastAngelFetch     = 0; g_lastAngelAttempt   = 0; g_lastAngelHour   = -1;
   g_lastRealtimeFetch  = 0;
   g_lastStairEventId   = ""; g_lastStairClientId = "";

   // Initialiser variables S/R et historique
   g_lastSRFetch          = 0;
   g_lastSpikeLevelFetch  = 0;
   g_spikeCount           = 0;
   ArrayResize(g_spikeTs,       0);
   ArrayResize(g_spikeDirs,     0);
   ArrayResize(g_spikeCaptured, 0);

   // Fetches initiaux
   FetchHourlyPrior();
   FetchZonePrior();
   FetchAngelOfSpike();
   FetchSpikeLevels();

   UpdateSMCContext();
   if(InpUseTVBridge)
      PollSpikeTVState(true);
   else if(InpUseTVConfirm)
      FetchTVChartBias(true);

   if(InpUseTVBridge)
      EventSetTimer(MathMax(1, InpTVBridgePollSec));

   PrintFormat("[SpikeRider] ✅ Init v5.08 | %s | %s | SMC=%s | GOM-Bridge=%s | "
               "Block-CT=%s Sniper=%s GlobalDir=%s | Magic=%llu | "
               "DerivStrats: EMA=%s SR=%s Range=%s RSIDiv=%s Pat123=%s",
               _Symbol, (IsBoom(_Symbol) ? "BUY only" : "SELL only"),
               (InpRequireSMC ? "ON" : "OFF"),
               (InpUseTVBridge ? "ON (GOM verdict active)" : "OFF"),
               (InpBlockCounterTrendTV ? "ON" : "OFF"),
               (InpRequireTVSniper ? "ON" : "OFF"),
               (InpRequireGlobalDir ? "ON" : "OFF"),
               InpMagic,
               (InpEnableEMACross      ? "ON" : "off"),
               (InpEnableSRBreakout    ? "ON" : "off"),
               (InpEnableRangeTrading  ? "ON" : "off"),
               (InpEnableRSIDivergence ? "ON" : "off"),
               (InpEnablePattern123    ? "ON" : "off"));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_hATR != INVALID_HANDLE)       { IndicatorRelease(g_hATR);       g_hATR = INVALID_HANDLE; }
   if(g_hRSI != INVALID_HANDLE)       { IndicatorRelease(g_hRSI);       g_hRSI = INVALID_HANDLE; }
   if(g_hEMAFast != INVALID_HANDLE)   { IndicatorRelease(g_hEMAFast);   g_hEMAFast = INVALID_HANDLE; }
   if(g_hEMASlow != INVALID_HANDLE)   { IndicatorRelease(g_hEMASlow);   g_hEMASlow = INVALID_HANDLE; }
   if(g_hEMAEntry5 != INVALID_HANDLE) { IndicatorRelease(g_hEMAEntry5); g_hEMAEntry5 = INVALID_HANDLE; }
   if(g_hEMAEntry20!= INVALID_HANDLE) { IndicatorRelease(g_hEMAEntry20);g_hEMAEntry20= INVALID_HANDLE; }

   // Libérer les handles multi-symboles
   for(int si = 0; si < g_symCount; si++)
   {
      if(g_syms[si].hATR    != INVALID_HANDLE) IndicatorRelease(g_syms[si].hATR);
      if(g_syms[si].hRSI    != INVALID_HANDLE) IndicatorRelease(g_syms[si].hRSI);
      if(g_syms[si].hEMAFast!= INVALID_HANDLE) IndicatorRelease(g_syms[si].hEMAFast);
      if(g_syms[si].hEMASlow!= INVALID_HANDLE) IndicatorRelease(g_syms[si].hEMASlow);
   }
   g_symCount = 0;

   CancelPendingOrder("deinit");
   ClearAllSRObjects();
   Comment("");
   Print("[SpikeRider] Arrêté sur ", _Symbol);
}

//+------------------------------------------------------------------+
//| TIMER — poll TradingView bridge                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(InpUseTVBridge)
      PollSpikeTVState(false);
}

//+------------------------------------------------------------------+
//| SPIKE SCALP: Z-Score Detection & Immediate Close                 |
//+------------------------------------------------------------------+
bool DetectSpikeScalp(int &direction, double &zscore)
{
   if(!InpUseImmediateScalp) return false;

   SpikeResult spike = DetectSpike();
   zscore = spike.zScore;
   double thresh = IsSynthIndex() ? MathMin(InpScalpZScore, InpSynthZScoreMin) : InpScalpZScore;
   if(spike.type == SPIKE_NONE || zscore < thresh)
      return false;

   if(spike.type == SPIKE_BUY)  { direction = 1;  return true; }
   if(spike.type == SPIKE_SELL) { direction = -1; return true; }
   return false;
}

// Spike détecté côté ai_server / TradingView (/spike-tv-state)
bool TryBuildTVSpike(SpikeResult &out)
{
   out.type       = SPIKE_NONE;
   out.zScore     = 0.0;
   out.rsi        = GetRSI();
   out.atr        = GetATR();
   out.stairScore = CalcStairScore(IsBoom(_Symbol));

   if(!InpUseTVBridge || !g_spikeTVOk || !g_tvSpikeDetected) return false;
   if(g_tvSpikeZ < InpSynthZScoreMin) return false;

   string dir = g_tvSpikeDir;
   StringToUpper(dir);

   if(IsBoom(_Symbol))
   {
      if(StringFind(dir, "BUY") < 0 && StringFind(dir, "UP") < 0 && StringFind(dir, "LONG") < 0)
         return false;
      out.type = SPIKE_BUY;
   }
   else if(IsCrash(_Symbol))
   {
      if(StringFind(dir, "SELL") < 0 && StringFind(dir, "DOWN") < 0 && StringFind(dir, "SHORT") < 0)
         return false;
      out.type = SPIKE_SELL;
   }
   else return false;

   out.zScore = g_tvSpikeZ;
   return true;
}

// Retourne true si une entrée a été tentée/ouverte (évite doublon avec Entrée A)
bool ExecuteSpikeScalpOnce()
{
   if(TimeCurrent() - g_lastScalpTrade < InpCooldownSec) return false;

   int direction = 0;
   double zscore = 0;

   if(!DetectSpikeScalp(direction, zscore))
   {
      g_scalpState.spikeDetected = false;
      return false;
   }

   g_scalpState.spikeDetected = true;
   g_scalpState.direction = direction;
   g_scalpState.zscore = zscore;
   g_scalpState.detectedTime = TimeCurrent();

   SpikeResult spike;
   spike.type       = (direction > 0) ? SPIKE_BUY : SPIKE_SELL;
   spike.zScore     = zscore;
   spike.rsi        = GetRSI();
   spike.atr        = GetATR();
   spike.stairScore = CalcStairScore(IsBoom(_Symbol));

   if(EnterSpikeTrade(spike, 0.0, false))
   {
      g_lastScalpTrade = TimeCurrent();
      Print("[SpikeRider] 🔥 SPIKE SCALP: ", (direction > 0 ? "BUY ↑" : "SELL ↓"),
            " Z=", DoubleToString(zscore, 2));
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| TICK                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsSupportedSymbol(_Symbol)) return;

   SyncEntrySlotLock();

   if(InpUseTVBridge && g_lastSpikeTVFetch == 0)
      PollSpikeTVState(true);

   ResetDayIfNeeded();
   SpikeResult spikeLive = DetectSpike();
   bool spikeNow = (spikeLive.type != SPIKE_NONE);
   if(spikeNow) CloseAllBoomCrashOnSpike();  // fermer tous Boom/Crash en gain sur spike
   ManageQuickExit(spikeNow);   // hold min + profit min avant sortie
   ManageTrailing();
   ManagePendingAge();

   // Refresh fetches si l'heure UTC a changé
   MqlDateTime utc; TimeToStruct(TimeGMT(), utc);
   if(InpUsePrior        && utc.hour != g_lastPriorHour) FetchHourlyPrior();
   if(InpUseZonePrior    && utc.hour != g_lastZoneHour)  FetchZonePrior();
   if(InpUseAngelOfSpike && utc.hour != g_lastAngelHour) FetchAngelOfSpike();

   // Realtime cross-chart : toutes les 5 secondes
   FetchRealtimeSpike();

   // Incrémenter compteur inter-spike sur nouvelle bougie
   // Note: on compte dès le départ (g_lastSpikeBar == 0) pour avoir un score utile immédiatement
   datetime barTime = iTime(_Symbol, InpTF, 0);
   bool newBar = (barTime != g_lastBar);
   if(newBar)
   {
      g_lastBar = barTime;
      g_barsSinceLastSpike++;  // compte toujours — sera reset à 0 après chaque spike
   }

   // Réutiliser spike déjà calculé en début de tick
   SpikeResult spike = spikeLive;
   double stairNow   = CalcStairScore(IsBoom(_Symbol));
   double imminence  = CalcImminenceScore(spike.atr, spike.rsi, stairNow);

   // ── NOTIFICATION PRÉ-SPIKE : alerter AVANT le spike ─────────────
   // Déclenché dès que l'imminence dépasse 50% ou 70%, avant toute entrée
   if(!HasPosition())
      CheckAndNotifyPreSpike(imminence);
   else
      ResetNotifState();   // position ouverte : réarmer pour le prochain cycle

   // ── SCAN MULTI-SYMBOLE : mettre à jour barsSince pour le panel 2 ─
   for(int si = 0; si < g_symCount; si++)
   {
      datetime bTime = iTime(g_syms[si].sym, InpTF, 0);
      if(bTime != 0 && bTime != g_syms[si].lastBar)
      {
         g_syms[si].lastBar = bTime;
         g_syms[si].barsSince++;
      }
   }

   UpdateDashboard(spike, imminence);
   DrawChartIndicators(spike, imminence);

   if(DailyLimitHit()) return;
   if(!SpreadOK())     return;

   bool canTryEntry = (!MaxPositionsReached() &&
                       TimeCurrent() - g_lastTrade >= InpCooldownSec &&
                       TimeCurrent() - g_lastEntryFail >= InpCooldownSec);
   bool entryDone = false;

   // Scalp immédiat (optionnel) — après verrou, jamais en parallèle des entrées A/B/C
   if(canTryEntry && InpUseImmediateScalp)
      entryDone = ExecuteSpikeScalpOnce();

   // ── Entrée A : spike Z + structure SMC (BOS/CHOCH/OTE) ───────────
   if(canTryEntry && spike.type != SPIKE_NONE)
   {
      if(InpUseTVBridge)
         PollSpikeTVState(false);
      else if(InpUseTVConfirm)
         FetchTVChartBias(false);

      CancelPendingOrder("setup spike");
      string why;
      if(CanEnterInDirection(spike.type, false, spike, why))
      {
         PrintFormat("[SpikeRider] 🚀 SETUP SPIKE %s | Z=%.2f | %s | imm=%.0f",
                     (spike.type == SPIKE_BUY ? "BUY" : "SELL"),
                     spike.zScore, why, imminence);
         entryDone = EnterSpikeTrade(spike, imminence, false);
      }
      else if(InpDebug)
         PrintFormat("[SpikeRider] Spike Z=%.2f bloqué: %s", spike.zScore, why);
   }

   // ── Entrée D : spike bridge TV (ai_server) ───────────────────────
   SpikeResult tvSpike;
   if(canTryEntry && !entryDone && TryBuildTVSpike(tvSpike))
   {
      string whyTv;
      if(CanEnterInDirection(tvSpike.type, false, tvSpike, whyTv))
      {
         PrintFormat("[SpikeRider] 📡 TV SPIKE %s | Z=%.2f | %s",
                     (tvSpike.type == SPIKE_BUY ? "BUY" : "SELL"),
                     tvSpike.zScore, whyTv);
         entryDone = EnterSpikeTrade(tvSpike, imminence, false);
      }
      else if(InpDebug)
         PrintFormat("[SpikeRider] TV spike Z=%.2f bloqué: %s", tvSpike.zScore, whyTv);
   }

   // ── Entrées E/F/G/H/I : stratégies Deriv EA Pro (1 éval par bougie fermée) ──
   if(canTryEntry && !entryDone && newBar)
   {
      ESpikeType derivSig = SPIKE_NONE;
      string derivStratName = "";

      // E — EMA crossover (croisement sur bougie fermée [1])
      if(derivSig == SPIKE_NONE) { derivSig = StratEMACross();      if(derivSig != SPIKE_NONE) derivStratName = "EMA-Cross"; }
      // F — S&R Breakout
      if(derivSig == SPIKE_NONE) { derivSig = StratSRBreakout();    if(derivSig != SPIKE_NONE) derivStratName = "SR-Breakout"; }
      // G — Range Trading
      if(derivSig == SPIKE_NONE) { derivSig = StratRangeTrading();  if(derivSig != SPIKE_NONE) derivStratName = "Range"; }
      // H — RSI Divergence
      if(derivSig == SPIKE_NONE) { derivSig = StratRSIDivergence(); if(derivSig != SPIKE_NONE) derivStratName = "RSI-Div"; }
      // I — Pattern 1-2-3
      if(derivSig == SPIKE_NONE) { derivSig = StratPattern123();    if(derivSig != SPIKE_NONE) derivStratName = "Pat123"; }

      // Mémoriser pour le dashboard (bougie courante, même si pas d'entrée)
      g_derivLastStrat = (derivSig != SPIKE_NONE) ? derivStratName : "---";
      g_derivLastSig   = derivSig;
      g_derivLastBar   = barTime;

      if(derivSig != SPIKE_NONE)
      {
         SpikeResult derivSpike;
         derivSpike.type       = derivSig;
         derivSpike.zScore     = spike.zScore;
         derivSpike.rsi        = spike.rsi;
         derivSpike.atr        = spike.atr > 0 ? spike.atr : GetATR();
         derivSpike.stairScore = stairNow;

         string whyDeriv;
         if(CanEnterInDirection(derivSpike.type, false, derivSpike, whyDeriv))
         {
            PrintFormat("[SpikeRider] 📐 %s %s | %s",
                        derivStratName,
                        (derivSpike.type == SPIKE_BUY ? "BUY" : "SELL"),
                        whyDeriv);
            entryDone = EnterSpikeTrade(derivSpike, imminence, false);
         }
         else if(InpDebug)
            PrintFormat("[SpikeRider] %s bloqué: %s", derivStratName, whyDeriv);
      }
   }

   // ── Entrée B : pré-spike/imminence (option 1) — priorité TV si sniper actif ─
   bool tvPreOk = (!InpUseTVBridge || !InpRequireTVSniper ||
                   (g_tvSniperReady && g_tvImminencePct >= InpImminenceThresh));
   if(canTryEntry && !entryDone && InpPreSpikeEnabled && tvPreOk &&
      (imminence >= InpImminenceThresh ||
       (InpUseTVBridge && g_tvImminencePct >= InpImminenceThresh)))
   {
      SpikeResult pre;
      pre.type       = IsBoom(_Symbol) ? SPIKE_BUY : SPIKE_SELL;
      pre.zScore     = spike.zScore;
      pre.rsi        = spike.rsi;
      pre.atr        = spike.atr;
      pre.stairScore = stairNow;

      string whyPre;
      if(CanEnterInDirection(pre.type, true, pre, whyPre))
      {
         PrintFormat("[SpikeRider] ⚡ PRE-SPIKE %s | imm=%.0f | %s",
                     (pre.type == SPIKE_BUY ? "BUY" : "SELL"), imminence, whyPre);
         entryDone = EnterSpikeTrade(pre, imminence, true);
      }
      else if(InpDebug)
         PrintFormat("[SpikeRider] Pre-spike bloqué: %s", whyPre);
   }

   // ── Entrée C : stair-only sans spike Z (option 2) ─────────────────
   if(canTryEntry && !entryDone && InpEnableStairOnlyEntry && spike.type == SPIKE_NONE)
   {
      if(stairNow >= InpStairOnlyMinPct &&
         (!InpStairOnlyNeedImminence || imminence >= InpImminenceThresh))
      {
         SpikeResult st;
         st.type       = IsBoom(_Symbol) ? SPIKE_BUY : SPIKE_SELL;
         st.zScore     = spike.zScore;
         st.rsi        = spike.rsi;
         st.atr        = spike.atr;
         st.stairScore = stairNow;

         string whySt;
         if(CanEnterInDirection(st.type, true, st, whySt))
         {
            PrintFormat("[SpikeRider] 🪜 STAIR-ONLY %s | stair=%.0f%% imm=%.0f | %s",
                        (st.type == SPIKE_BUY ? "BUY" : "SELL"), stairNow * 100.0, imminence, whySt);
            entryDone = EnterSpikeTrade(st, imminence, true);
         }
         else if(InpDebug)
            PrintFormat("[SpikeRider] Stair-only bloqué: %s", whySt);
      }
   }
}
