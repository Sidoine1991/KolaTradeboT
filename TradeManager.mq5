//+------------------------------------------------------------------+
//| TradeManager.mq5 v3 — Multi-symbole universel                   |
//| Trailing stop + re-entrée sur EMA la plus proche                 |
//| Attacher sur UN SEUL chart — gère tout le terminal               |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "3.10"
#property strict
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>

input group "=== TRAILING STOP ==="
input bool   UseTrailing            = true;   // Activer trailing stop
input double TrailActivatePct       = 0.3;    // Activer après X% du SL initial en profit
input double TrailLockPct           = 0.25;   // Verrouiller X% du profit max depuis pic

input group "=== RE-ENTRÉE SUR EMA ==="
input bool   UseReEntry             = true;   // Activer re-entrée automatique
input int    ReEntryMaxPerSymbol    = 3;      // Max re-entrées par position fermée
input int    ReEntryCooldownSec     = 30;     // Cooldown minimal entre tentatives (sec)
input int    EMA_Fast               = 8;      // EMA rapide M1 — 1ère cible
input int    EMA_Slow               = 21;     // EMA lente M1 — 2ème cible
input double EMATouch_Pct           = 0.5;   // Tolérance toucher EMA (% du spread)
input bool   RequireCorrectSide     = true;   // Prix doit être du bon côté de l'EMA

input group "=== FILTRE RSI ==="
input int    RSI_Period             = 14;
input double RSI_SellMax            = 65.0;   // SELL bloqué si RSI > X
input double RSI_BuyMin             = 30.0;   // BUY bloqué si RSI < X

input group "=== FILTRE ==="
input int    MagicFilter            = 0;      // Magic number (0 = tous)
input int    CheckIntervalSec       = 5;      // Intervalle vérification (sec)

input group "=== AUTO SL/TP ==="
input bool   AutoAssignSLTP         = true;   // Auto-assigner SL/TP si manquants
input double MaxRiskUSD             = 5.0;    // SL max risque (USD)
input double TargetProfitUSD        = 10.0;   // TP cible (USD)

input group "=== PROFIT GLOBAL ==="
input bool   UseGlobalProfitTarget  = true;   // Fermer tout si profit total >= cible
input double GlobalProfitTargetUSD  = 10.0;   // Cible profit global (USD) — somme positions MCP
input bool   GlobalProfitMCPOnly    = true;   // Ne compter que les positions magic MCP (bridge)

input group "=== SIGNAUX MCP TRADINGVIEW ==="
input bool   UseMCPSignals          = true;   // Exécuter signaux bridge/WhatsApp (pending-order)
input string AIServerURL            = "http://127.0.0.1:8000"; // URL AI server
input int    MCPPollIntervalSec     = 10;     // Intervalle poll /pending-order (sec)
input int    MCPMagicNumber         = 20260526; // Magic number ordres MCP
input double MCPEntryTolerancePct   = 0.05;  // Tolérance entrée limit (% du prix)
input bool   MCPExecuteAtMarket     = true;   // Exécuter au marché dès signal ready (recommandé)
input bool   MCPBypassConsolidation = true;   // Ne pas bloquer MCP sur filtre consolidation
input bool   MCPDuplicateOnce       = true;   // Dupliquer 1x la position après profit minimum
input double MCPDuplicateMinProfit  = 2.0;    // Profit minimum (USD) avant duplication
input bool   DuplicateManualOrders  = true;   // Dupliquer aussi les ordres manuels (magic=0)
input string InpPollSymbols         = "Boom 600 Index,Boom 1000 Index,Crash 600 Index,Crash 1000 Index,XAUUSD";

input group "=== NOTIFICATIONS WHATSAPP ==="
input bool   UseWhatsApp            = true;   // Envoyer alertes WhatsApp
input int    WATimeoutMs            = 8000;   // Timeout requête WhatsApp (ms)

input group "=== ALIGNEMENT SIGNAL (TA + MCP) ==="
input bool   RequireSignalAlign     = true;   // Bloquer re-entrée si direction oppose biais TA/MCP
input int    SignalCacheAgeSec      = 300;    // Durée validité cache biais (sec, 0=désactivé)
input double MinTAConfidence        = 0.55;   // Confiance TA minimum pour que le biais compte

input group "=== FILTRE CONSOLIDATION ==="
input bool   UseConsolidationFilter = true;   // Bloquer en zone de consolidation élevée
input int    ADX_Period             = 14;     // Période ADX
input double ADX_MinTrend           = 20.0;  // ADX < seuil → consolidation (bloquer)
input double ConsolidationATRRatio  = 0.65;  // ATR < ATR_SMA * ratio → consolidation

input group "=== GOM SCALP LOOP ==="
input bool   UseGOMScalp           = true;   // Coupe auto sur signal GOM opposé
input int    GOMPollIntervalSec    = 5;      // Intervalle poll /gom-verdict (sec)
input bool   GOMReEntryEnabled     = true;   // Re-entrer quand GOM réaligne
input int    GOMReEntryCooldownSec = 30;     // Cooldown entre fermeture et ré-entrée
input double GOMReEntryLot         = 0.01;   // Lot pour ré-entrée GOM
input int    GOMReEntryMaxCount    = 3;      // Max ré-entrées par signal

CTrade        trade;
CPositionInfo posInfo;

bool     g_globalCloseDone = false;
datetime g_globalCloseTime = 0;

// GOM Scalp Loop
datetime g_lastGOMPoll       = 0;
string   g_lastGOMVerdict    = "";
int      g_lastGOMRSI        = 50;
bool     g_gomRSIOversold    = false;
bool     g_gomRSIOverbought  = false;
int      g_lastGOMVerdictNum = 0;

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

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   EventSetTimer(CheckIntervalSec);
   ScanAllPositions();
   Print("[TradeManager v3.1] Actif | MCP market=", MCPExecuteAtMarket,
         " | dup=", MCPDuplicateOnce, " | profit global=$", GlobalProfitTargetUSD,
         " | EMA", EMA_Fast, "/", EMA_Slow, " | positions=", g_stateCount);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
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
   if(UseTrailing)           ManageAllTrailing();
   if(UseReEntry)            CheckAllReEntries();
   if(UseMCPSignals)         PollMCPSignals();
   if(UseMCPSignals)         MonitorMCPPositions();
   if(MCPDuplicateOnce)      MonitorManualDuplicates();
   if(UseGOMScalp)           PollGOMScalpVerdict();
   if(UseGOMScalp)           CheckGOMReEntry();
}

void OnTick()
{
   static datetime lastRun = 0;
   if(TimeCurrent() - lastRun < CheckIntervalSec) return;
   lastRun = TimeCurrent();
   ScanAllPositions();
   if(RequireSignalAlign)    PollSignalBias();
   if(UseGlobalProfitTarget) CheckGlobalProfit();
   if(UseTrailing)           ManageAllTrailing();
   if(UseReEntry)            CheckAllReEntries();
   if(UseMCPSignals)         PollMCPSignals();
   if(UseMCPSignals)         MonitorMCPPositions();
   if(MCPDuplicateOnce)      MonitorManualDuplicates();
   if(UseGOMScalp)           PollGOMScalpVerdict();
   if(UseGOMScalp)           CheckGOMReEntry();
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

   string orderId = "";
   for(int i = 0; i < g_mcpCount; i++)
   {
      if(g_mcpSignals[i].ticket == ticket)
      {
         orderId = g_mcpSignals[i].orderId;
         break;
      }
   }

   if(StringLen(orderId) == 0)
   {
      Print("[TradeManager] ⚠️ SyncSLTPToServer: order_id not found for ticket ", ticket);
      return false;
   }

   string url = AIServerURL + "/pending-order/" + orderId + "/sync";
   string headers = "Content-Type: application/json\r\n";

   // Construire JSON body
   string body = StringFormat(
      "{\"mt5_ticket\":%d,\"current_stop_loss\":%.2f,\"current_take_profit\":%.2f,\"update_source\":\"%s\"}",
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
      Print("[TradeManager] ✅ Synced SL/TP to server: orderId=", orderId, " SL=", DoubleToString(newSL, 5), " TP=", DoubleToString(newTP, 5));
      return true;
   }
   else
   {
      Print("[TradeManager] ❌ Failed to sync SL/TP: HTTP ", res, " orderId=", orderId);
      return false;
   }
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
   if(MagicFilter > 0 && posInfo.Magic() == (long)MagicFilter) return true;
   if(UseMCPSignals && posInfo.Magic() == (long)MCPMagicNumber) return true;
   if(MagicFilter <= 0) return true;
   return false;
}

void ManageAllTrailing()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(!PositionIncludedInTrailing()) continue;

      string sym = posInfo.Symbol();
      int    idx = FindState(sym);
      if(idx < 0) continue;

      double ep        = g_states[idx].openPrice;
      int    dir       = g_states[idx].direction;
      double curSL     = posInfo.StopLoss();
      double curProfit = posInfo.Profit();

      if(curProfit > g_states[idx].peakProfit)
         g_states[idx].peakProfit = curProfit;

      // Garde-fou perte max — fermer si perte >= MaxRiskUSD (fallback broker sans SL)
      if(curProfit <= -MaxRiskUSD)
      {
         Print(StringFormat("[TradeManager] 🛑 %s perte $%.2f >= -$%.2f — fermeture urgente",
               sym, curProfit, MaxRiskUSD));
         trade.PositionClose(posInfo.Ticket());
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

      // forceTrailing : activer dès le moindre profit positif (seuil 10% du slDist)
      double activateThreshold = g_states[idx].forceTrailing ? (slDist * 0.1) : (slDist * TrailActivatePct);
      if(profitPts < activateThreshold) continue;

      // Nouveau SL = verrouiller % du pic de profit
      double tickVal     = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double tickSz      = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double lot         = posInfo.Volume();
      double profitPerPt = (tickSz > 0) ? (tickVal / tickSz) * lot : lot;
      if(profitPerPt <= 0) continue;

      double lockPct = g_states[idx].forceTrailing ? 0.5 : TrailLockPct;
      double lockPts = (g_states[idx].peakProfit * lockPct) / profitPerPt;
      int    dg      = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      double newSL   = NormalizeDouble((dir == 1) ? ep + lockPts : ep - lockPts, dg);
      double minMove = SymbolInfoDouble(sym, SYMBOL_POINT) * 3;

      bool better = (dir == 1) ? (newSL > curSL + minMove)
                               : (curSL == 0 || newSL < curSL - minMove);
      if(!better) continue;

      if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
      {
         Print(StringFormat("[TradeManager] 📈 %s Trailing SL %.5f→%.5f (profit=$%.2f peak=$%.2f%s)",
               sym, curSL, newSL, curProfit, g_states[idx].peakProfit,
               g_states[idx].forceTrailing ? " FORCÉ" : ""));
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
               Print(StringFormat("[TradeManager] 🔧 %s SL/TP reposé après re-entrée SL=%.5f TP=%.5f", sym, newSL, newTP));
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
//| Symbole déjà dans la file MCP active/exécutée                    |
//+------------------------------------------------------------------+
bool MCPHasSignalForSymbol(const string sym)
{
   for(int k = 0; k < g_mcpCount; k++)
      if(g_mcpSignals[k].symbol == sym && (g_mcpSignals[k].active || g_mcpSignals[k].executed))
         return true;
   return false;
}

//+------------------------------------------------------------------+
//| Enregistre + exécute un pending-order JSON pour un symbole       |
//+------------------------------------------------------------------+
void IngestPendingOrderForSymbol(const string sym, const string &body)
{
   if(!JsonGetBool(body, "ok")) return;

   int orderPos = StringFind(body, "\"order\":{");
   if(orderPos < 0) return;
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

   if(StringLen(action) == 0) return;
   if(action != "BUY" && action != "SELL") return;

   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(atMarket && entry <= 0)
      entry = (action == "BUY") ? ask : bid;
   if(entry <= 0) return;

   if(MCPHasSignalForSymbol(sym)) return;

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
   g_mcpSignals[idx].failCount       = 0;

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

   string syms[];
   int nsyms = 0;
   string parts[];
   int np = StringSplit(InpPollSymbols, ',', parts);
   ArrayResize(syms, MathMax(np, g_stateCount) + 4);
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
   for(int i = 0; i < g_stateCount; i++)
   {
      bool dup = false;
      for(int j = 0; j < nsyms; j++)
         if(syms[j] == g_states[i].symbol) { dup = true; break; }
      if(!dup) syms[nsyms++] = g_states[i].symbol;
   }
   bool hasChart = false;
   for(int j = 0; j < nsyms; j++)
      if(syms[j] == _Symbol) { hasChart = true; break; }
   if(!hasChart) syms[nsyms++] = _Symbol;

   for(int si = 0; si < nsyms; si++)
   {
      string sym = syms[si];
      if(MCPHasSignalForSymbol(sym)) continue;

      string symEnc = sym;
      StringReplace(symEnc, " ", "%20");
      string url = AIServerURL + "/pending-order?symbol=" + symEnc;
      char post[], result[];
      string headers = "Content-Type: application/json\r\n";
      string respH;
      int code = WebRequest("GET", url, headers, WATimeoutMs, post, result, respH);
      if(code != 200) continue;

      string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      IngestPendingOrderForSymbol(sym, body);
   }
}

//+------------------------------------------------------------------+
//| Ouvre la 2ème jambe (duplication)                                |
//+------------------------------------------------------------------+
bool DuplicateMCPPosition(int idx, CTrade &mcpTrade)
{
   if(!MCPDuplicateOnce || g_mcpSignals[idx].duplicated) return false;

   string sym = g_mcpSignals[idx].symbol;
   int    dir = g_mcpSignals[idx].direction;
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
//| Exécute un signal MCP si le prix est dans la tolérance d'entrée  |
//+------------------------------------------------------------------+
void TryExecuteMCPSignal(int idx)
{
   if(!g_mcpSignals[idx].active || g_mcpSignals[idx].executed) return;
   if(g_mcpSignals[idx].failCount >= 3)
   {
      Print(StringFormat("[TradeManager] Signal %s abandonne apres %d echecs",
            g_mcpSignals[idx].symbol, g_mcpSignals[idx].failCount));
      g_mcpSignals[idx].active = false;
      return;
   }

   string sym  = g_mcpSignals[idx].symbol;
   int    dir  = g_mcpSignals[idx].direction;
   double ep   = g_mcpSignals[idx].entryPrice;
   double ask  = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid  = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return;
   double refPx = (dir == 1) ? ask : bid;
   double tol  = MathMax(ep * MCPEntryTolerancePct / 100.0, SymbolInfoDouble(sym, SYMBOL_POINT) * 5);

   // Alerte "niveau atteint" même si on n'exécute pas encore
   if(!g_mcpSignals[idx].entryNotifSent && MathAbs(refPx - ep) <= tol * 5)
   {
      g_mcpSignals[idx].entryNotifSent = true;
      SendWAEvent("ENTRY_HIT", sym, refPx, 0, (dir==1?"BUY":"SELL"), ep,
                  g_mcpSignals[idx].stopLoss, g_mcpSignals[idx].takeProfit1, g_mcpSignals[idx].lot);
   }

   bool execNow = g_mcpSignals[idx].marketExec || MCPExecuteAtMarket;
   if(!execNow && MathAbs(refPx - ep) > tol) return;  // limit: attendre le prix

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
      if(profit < MCPDuplicateMinProfit) continue;

      // Vérifier si déjà dupliqué
      bool alreadyDup = false;
      for(int k = 0; k < g_manualDupCount; k++)
         if(g_manualDupTickets[k] == ticket) { alreadyDup = true; break; }
      if(alreadyDup) continue;

      // Dupliquer
      string sym = posInfo.Symbol();
      int    dir = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
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
//| Poll /gom-verdict et coupe positions si signal opposé            |
//+------------------------------------------------------------------+
void PollGOMScalpVerdict()
{
   if(!UseGOMScalp) return;
   if((int)(TimeCurrent() - g_lastGOMPoll) < GOMPollIntervalSec) return;
   g_lastGOMPoll = TimeCurrent();

   // ── Fetch /gom-verdict ──────────────────────────────────────
   string sym = _Symbol;
   string symEnc = sym;
   StringReplace(symEnc, " ", "%20");
   string url = AIServerURL + "/gom-verdict?symbol=" + symEnc;
   char post[], result[];
   string headers = "Content-Type: application/json\r\n";
   string respH;
   int code = WebRequest("GET", url, headers, WATimeoutMs, post, result, respH);
   if(code != 200) return;

   string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   if(StringFind(body, "\"ok\":false") >= 0) return;

   // Parser verdict
   string verdict    = JsonGetString(body, "verdict");
   int    rsi        = (int)JsonGetDouble(body, "rsi");
   bool   oversold   = StringFind(body, "\"rsi_oversold\":true")  >= 0;
   bool   overbought = StringFind(body, "\"rsi_overbought\":true") >= 0;
   int    vnum       = (int)JsonGetDouble(body, "verdict_num");

   g_lastGOMVerdict    = verdict;
   g_lastGOMRSI        = rsi;
   g_gomRSIOversold    = oversold;
   g_gomRSIOverbought  = overbought;
   g_lastGOMVerdictNum = vnum;

   // ── Scanner positions ouvertes ──────────────────────────────
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      string posSym = posInfo.Symbol();
      if(posSym != sym) continue;

      int    dir    = posInfo.PositionType() == POSITION_TYPE_BUY ? 1 : -1;
      double profit = posInfo.Profit();
      ulong  ticket = posInfo.Ticket();

      bool   shouldClose = false;
      string closeReason = "";

      if(dir == -1) // Position SELL
      {
         // Couper si GOM dit BUY ou WAIT + profit ou RSI survente extrême + profit
         if(vnum > 0)
         {
            shouldClose = true;
            closeReason = StringFormat("GOM=%s -> microcorrection BUY", verdict);
         }
         else if(StringCompare(verdict, "WAIT") == 0 && profit > 0)
         {
            shouldClose = true;
            closeReason = "GOM=WAIT + profit -> securisation";
         }
         else if(oversold && profit > 0)
         {
            shouldClose = true;
            closeReason = StringFormat("RSI=%d SURVENTE + profit -> rebond imminent", rsi);
         }
      }
      else if(dir == 1) // Position BUY
      {
         // Couper si GOM dit SELL ou WAIT + profit ou RSI surachat + profit
         if(vnum < 0)
         {
            shouldClose = true;
            closeReason = StringFormat("GOM=%s -> correction SELL", verdict);
         }
         else if(StringCompare(verdict, "WAIT") == 0 && profit > 0)
         {
            shouldClose = true;
            closeReason = "GOM=WAIT + profit -> securisation";
         }
         else if(overbought && profit > 0)
         {
            shouldClose = true;
            closeReason = StringFormat("RSI=%d SURACHAT + profit -> retournement imminent", rsi);
         }
      }

      if(!shouldClose) continue;

      // Fermer la position
      CTrade closeTrade;
      closeTrade.SetDeviationInPoints(50);
      bool closed = closeTrade.PositionClose(ticket);

      if(closed)
      {
         Print(StringFormat("[GOMScalp] Position %s %s fermee (profit=%.2f$) Raison: %s",
               (dir==1?"BUY":"SELL"), posSym, profit, closeReason));

         SendWAEvent("GOM_CLOSE", posSym, posInfo.PriceCurrent(), profit,
                     (dir==1?"BUY":"SELL"), posInfo.PriceOpen(),
                     posInfo.StopLoss(), posInfo.TakeProfit(), posInfo.Volume());

         // Enregistrer état pour ré-entrée
         if(GOMReEntryEnabled)
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
//| Re-entrée GOM après correction                                   |
//+------------------------------------------------------------------+
void CheckGOMReEntry()
{
   if(!UseGOMScalp || !GOMReEntryEnabled) return;

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

      // Re-entrer seulement si GOM réaligne avec la direction originale
      bool aligned = (dir == -1 && vnum <= -1) || (dir == 1 && vnum >= 1);
      if(!aligned) continue;

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

      // Duplication différée — dès que profit >= MCPDuplicateMinProfit
      if(MCPDuplicateOnce && !g_mcpSignals[i].duplicated && posOpen
         && profit >= MCPDuplicateMinProfit)
      {
         CTrade dupTrade;
         dupTrade.SetExpertMagicNumber(MCPMagicNumber);
         dupTrade.SetDeviationInPoints(30);
         dupTrade.SetTypeFilling(ORDER_FILLING_IOC);
         DuplicateMCPPosition(i, dupTrade);
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
