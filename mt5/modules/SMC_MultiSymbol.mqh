//+------------------------------------------------------------------+
//| SMC_MultiSymbol.mqh — MASTER MULTI-SYMBOLES                       |
//|                                                                   |
//| Une seule instance EA scanne une liste de symboles (FxVol,        |
//| Gold/XAUUSD, Boom/Crash...) et trade sur chacun à partir des      |
//| verdicts GOM servis par le serveur (/gom-kola-dashboard).         |
//|                                                                   |
//| QUAND UseMultiSymbolMaster = true : les stratégies par-chart de   |
//| l'EA (SMCASC, SMCFX, SMCR, spike chain, Dow...) sont désactivées  |
//| (OnTick retourne tôt) — seule l'instance master trade.            |
//|                                                                   |
//| Dépendances (déjà incluses avant ce fichier) :                    |
//|   modules/SMC_GOM_Pipeline.mqh  → SMCGP_HttpGet / SMCGP_Json*    |
//|   modules/SMC_SymbolCategory.mqh → SMC_GetSymbolCategory          |
//|   SMC_Universal.mq5 (déclarations anticipées) → CM_IsEntryBlocked,|
//|     SMC_GV_IsBreakerActive, PB_SendWhatsAppViaAI                  |
//|   SMC_Universal.mq5 (inputs) → InpMagicNumber,                    |
//|     CapitalManagerExemptVolatility, UseDailyCapitalManager        |
//|   helpers définis avant ce include → IsBoomLikeSymbol,            |
//|     IsCrashLikeSymbol, SMC_IsSpikeStyleSymbol                     |
//+------------------------------------------------------------------+
#ifndef SMC_MULTISYMBOL_MQH
#define SMC_MULTISYMBOL_MQH

input group "=== MASTER MULTI-SYMBOLES (1 instance = N symboles) ==="
input bool   UseMultiSymbolMaster    = false;    // Master multi-symboles actif (désactive les stratégies par-chart)
input string MS_Symbols              = "FX Vol 20,SFX Vol 75,XAUUSD"; // Liste des symboles à trader (séparés par des virgules)
input int    MS_MaxSymbols           = 8;        // Nombre max de symboles scannés
input string MS_PollTF               = "M1";     // Timeframe de référence pour les verdicts serveur (M1/M5/M15)
input int    MS_PollIntervalSec      = 5;        // Poll GOM par symbole (secondes)
input int    MS_MaxVerdictAgeSec     = 30;       // Verdict périmé au-delà de N secondes (pas d'entrée)
input int    MS_MinVerdictNum        = 2;        // |verdict_num| minimum pour entrer
input double MS_MinCoherencePct      = 50.0;     // Cohérence GOM minimale (%) — 0 = pas de filtre
input double MS_RiskPct              = 0.5;      // Risque par trade (% equity)
input double MS_CapLossPerTradeUSD   = 3.0;      // Perte max par trade ($)
input int    MS_MaxPositionsTotal    = 4;        // Positions master max (total)
input int    MS_MaxPosPerSymbol      = 1;        // Positions master max par symbole
input int    MS_ReentryCooldownSec   = 60;       // Anti-spam entre deux entrées sur le même symbole
input int    MS_SlippagePoints       = 50;       // Slippage autorisé (points)
input bool   MS_EnableSpike          = true;     // Autoriser Boom/Crash/PainX/GainX
input bool   MS_EnableVolatility     = true;     // Autoriser FxVol / Volatility indexes
input bool   MS_EnableMetal          = true;     // Autoriser Gold/XAUUSD
input bool   MS_EnableFX             = false;    // Autoriser Forex
input bool   MS_EnableCrypto         = false;    // Autoriser Crypto
input bool   MS_UseVerdictSLTP       = true;     // Utiliser les SL/TP du serveur quand disponibles
input double MS_SL_ATRMult           = 2.0;      // SL (x ATR M1) si pas de SL serveur
input double MS_TP_ATRMult           = 4.0;      // TP (x ATR M1) si pas de TP serveur
input double MS_ATRTrailMult         = 2.0;      // Trail ATR : verrouiller après +N ATR (0 = off)
input double MS_VolKeepPct           = 70.0;     // FxVol : % du gain à protéger par le trailing
input double MS_MaxFloatLossUSD      = 8.0;      // Couper tout si perte flottante master dépasse $ (0 = off)
input bool   MS_AntiHedge            = true;     // Fermer le sens opposé plus ancien sur le même symbole
input bool   MS_CloseOnVerdictFlip   = true;     // Fermer si le verdict retourne contre la position (|vn|>=2)
input bool   MS_CloseOnWaitSustained = true;     // Fermer si WAIT persiste sur N polls consécutifs
input int    MS_WaitClosePollCount   = 3;        // Nb de polls WAIT avant fermeture
input string MS_OrderComment         = "MULTISYM"; // Tag des ordres master

//+------------------------------------------------------------------+
//| État par symbole                                                  |
//+------------------------------------------------------------------+
struct MS_SymbolState
{
   string   symbol;
   string   gomKey;
   int      category;
   bool     enabled;
   int      verdictNum;
   string   verdict;
   double   coherencePct;
   double   scoreBuy;
   double   scoreSell;
   double   serverEntry;
   double   serverSL;
   double   serverTP;
   bool     spikeTradableKnown;
   bool     spikeTradable;
   bool     hasVerdict;
   datetime lastPoll;
   datetime lastEntryTime;
   int      waitPolls;
};

MS_SymbolState g_msStates[];
int            g_msStateCount = 0;
bool           g_msInitialized  = false;
bool           g_msGomConnected = false;
datetime       g_msLastSuccess  = 0;
datetime       g_msLastTrailRun = 0;
datetime       g_msLastFloatCut = 0;
datetime       g_msLastFlipLog  = 0;
datetime       g_msLastEntryLog = 0;

//+------------------------------------------------------------------+
//| Helpers                                                           |
//+------------------------------------------------------------------+
void MS_CloseSymbolSide(const string symbol, const int side);

bool MS_IsMasterPosition(const ulong ticket)
{
   if(PositionGetString(POSITION_COMMENT) == "")
      return false;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) return false;
   string cm = PositionGetString(POSITION_COMMENT);
   return (StringFind(cm, MS_OrderComment) >= 0);
}

int MS_FindState(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   for(int i = 0; i < g_msStateCount; i++)
   {
      string stSym = g_msStates[i].symbol;
      StringToUpper(stSym);
      if(stSym == s) return i;
   }
   return -1;
}

int MS_CountOpenPositions(const string symbol, const int side)
{
   // side: 0 = tous, 1 = BUY, -1 = SELL
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!MS_IsMasterPosition(ticket)) continue;
      if(StringLen(symbol) > 0 && PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if(side != 0)
      {
         bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
         if((side > 0 && !isBuy) || (side < 0 && isBuy)) continue;
      }
      count++;
   }
   return count;
}

double MS_TotalFloatPnl()
{
   double sum = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!MS_IsMasterPosition(ticket)) continue;
      sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return sum;
}

double MS_NormalizeLot(const string symbol, double lot)
{
   double vmin  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(vmin <= 0) vmin = 0.01;
   if(vstep <= 0) vstep = 0.01;
   lot = MathFloor(lot / vstep) * vstep;
   lot = MathMax(vmin, lot);
   lot = MathMin(vmax, lot);
   return lot;
}

double MS_GetATR(const string symbol, const ENUM_TIMEFRAMES tf = PERIOD_M1)
{
   int h = iATR(symbol, tf, 14);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   double val = 0.0;
   if(CopyBuffer(h, 0, 0, 1, buf) >= 1) val = buf[0];
   IndicatorRelease(h);
   return val;
}

//+------------------------------------------------------------------+
//| Init : parse la liste de symboles configurée                      |
//+------------------------------------------------------------------+
void MS_Init()
{
   g_msStateCount = 0;
   ArrayResize(g_msStates, 0);

   string symbols[];
   int n = StringSplit(MS_Symbols, ',', symbols);
   if(n <= 0) return;

   int maxSym = (MS_MaxSymbols > 0 ? MS_MaxSymbols : 8);

   for(int i = 0; i < n && g_msStateCount < maxSym; i++)
   {
      string s = symbols[i];
      StringTrimLeft(s);
      StringTrimRight(s);
      if(StringLen(s) == 0) continue;
      if(SymbolInfoDouble(s, SYMBOL_POINT) <= 0) continue;
      SymbolSelect(s, true);

      MS_SymbolState st;
      st.symbol        = s;
      st.gomKey        = SMCGP_ResolveGOMSym(s);
      st.category      = (int)SMC_GetSymbolCategory(s);
      st.verdictNum    = 0;
      st.verdict       = "";
      st.coherencePct  = 0.0;
      st.scoreBuy      = 0.0;
      st.scoreSell     = 0.0;
      st.serverEntry   = 0.0;
      st.serverSL      = 0.0;
      st.serverTP      = 0.0;
      st.spikeTradableKnown = false;
      st.spikeTradable = false;
      st.hasVerdict    = false;
      st.lastPoll      = 0;
      st.lastEntryTime = 0;
      st.waitPolls     = 0;

      switch((ENUM_SYMBOL_CATEGORY)st.category)
      {
         case SYM_BOOM_CRASH: st.enabled = MS_EnableSpike;    break;
         case SYM_VOLATILITY: st.enabled = MS_EnableVolatility; break;
         case SYM_METAL:      st.enabled = MS_EnableMetal;    break;
         case SYM_FOREX:      st.enabled = MS_EnableFX;       break;
         case SYM_CRYPTO:     st.enabled = MS_EnableCrypto;   break;
         default:             st.enabled = false;             break;
      }

      int idx = g_msStateCount;
      ArrayResize(g_msStates, idx + 1);
      g_msStates[idx] = st;
      g_msStateCount++;

      Print("[MULTISYM] Symbole ajouté: ", s, " | cat=", st.category,
            " | gomKey=", st.gomKey, " | enabled=", st.enabled);
   }

   g_msInitialized = (g_msStateCount > 0);
   if(!g_msInitialized)
      Print("[MULTISYM] Aucun symbole valide — vérifier MS_Symbols (symboles présents dans le Market Watch).");
}

//+------------------------------------------------------------------+
//| Poll GOM pour un symbole                                          |
//+------------------------------------------------------------------+
void MS_PollOne(const int idx)
{
   if(idx < 0 || idx >= g_msStateCount) return;
   MS_SymbolState st = g_msStates[idx];
   st.lastPoll = TimeCurrent();

   string query = "/gom-kola-dashboard?symbol=" + SMCGP_EncodeSym(st.gomKey)
                + "&chart_tf=" + MS_PollTF + "&source=local";
   string body;
   int timeout = 8000;

   if(SMCGP_HttpGet(query, body, timeout)
      && (SMCGP_JsonBool(body, "ok") || StringFind(body, "\"ok\":true") >= 0))
   {
      st.verdictNum  = (int)SMCGP_JsonDouble(body, "verdict_num");
      st.verdict     = SMCGP_JsonString(body, "verdict");
      st.coherencePct= SMCGP_JsonDouble(body, "coherence_pct");
      st.scoreBuy    = SMCGP_JsonDouble(body, "score_buy");
      st.scoreSell   = SMCGP_JsonDouble(body, "score_sell");
      st.serverEntry = SMCGP_JsonDouble(body, "entry");
      st.serverSL    = SMCGP_JsonDouble(body, "sl");
      st.serverTP    = SMCGP_JsonDouble(body, "tp");
      st.hasVerdict  = true;

      double stv = SMCGP_JsonDouble(body, "spike_tradable", -1.0);
      st.spikeTradableKnown = (stv >= 0.0);
      st.spikeTradable = SMCGP_JsonBool(body, "spike_tradable");

      if(st.verdictNum == 0) st.waitPolls++;
      else st.waitPolls = 0;

      g_msLastSuccess  = TimeCurrent();
      g_smcGomConnected = true;  // alimente les composants globaux (LIMIT discipline, etc.)
      SMCGP_CacheVerdict(st.gomKey, st.verdictNum, st.verdict);
   }
   // En cas d'échec on ne touche pas au dernier verdict connu : la fraîcheur
   // est gérée par MS_MaxVerdictAgeSec via lastPoll.
   g_msStates[idx] = st;
}

//+------------------------------------------------------------------+
//| Détermination du sens selon la catégorie et le verdict            |
//+------------------------------------------------------------------+
int MS_DirectionFor(const MS_SymbolState &st)
{
   int vn = st.verdictNum;
   if(vn == 0 || vn == -999) return 0;

   if(st.category == SYM_BOOM_CRASH)
   {
      if(IsBoomLikeSymbol(st.symbol))
         return (vn >= MS_MinVerdictNum) ? 1 : 0;   // Boom/GainX : jamais SELL
      if(IsCrashLikeSymbol(st.symbol))
         return (vn <= -MS_MinVerdictNum) ? -1 : 0; // Crash/PainX : jamais BUY
      return (vn > 0) ? 1 : -1;
   }

   return (vn > 0) ? 1 : -1;
}

//+------------------------------------------------------------------+
//| Vérifications avant entrée                                        |
//+------------------------------------------------------------------+
bool MS_CanOpen(const int idx, const int dir, string &reason)
{
   MS_SymbolState st = g_msStates[idx];
   reason = "";

   if(!g_msGomConnected)               { reason = "GOM deconnecte"; return false; }
   if(!st.enabled)                     { reason = "categorie desactivee"; return false; }
   if(!st.hasVerdict)                  { reason = "pas de verdict"; return false; }
   if(TimeCurrent() - st.lastPoll > MS_MaxVerdictAgeSec)
                                       { reason = "verdict perime"; return false; }
   int vn = st.verdictNum;
   if(vn == 0 || vn == -999)           { reason = "verdict WAIT/inconnu"; return false; }
   if(MathAbs(vn) < MS_MinVerdictNum)  { reason = "verdict trop faible |vn|=" + IntegerToString(vn); return false; }
   if(st.coherencePct > 0 && st.coherencePct < MS_MinCoherencePct)
                                       { reason = "coherence faible (" + DoubleToString(st.coherencePct, 1) + "%)"; return false; }
   if(st.category == SYM_BOOM_CRASH && st.spikeTradableKnown && !st.spikeTradable)
                                       { reason = "spike_tradable=false"; return false; }

   if(MS_CountOpenPositions(st.symbol, dir) >= MS_MaxPosPerSymbol)
                                       { reason = "cap positions symbole"; return false; }

   // Anti-hedge : si un sens opposé est déjà ouvert, on le ferme puis on continue
   if(MS_CountOpenPositions(st.symbol, -dir) > 0)
   {
      if(!MS_AntiHedge)                { reason = "position opposee ouverte"; return false; }
      MS_CloseSymbolSide(st.symbol, -dir);
   }

   if(TimeCurrent() - st.lastEntryTime < MS_ReentryCooldownSec)
                                       { reason = "cooldown reentree"; return false; }

   // Capital manager journalier (sauf exemption Volatility)
   if(UseDailyCapitalManager && !(CapitalManagerExemptVolatility && st.category == SYM_VOLATILITY))
   {
      if(CM_IsEntryBlocked(reason)) return false;
   }

   // Circuit breaker multi-symboles (GlobalVariables partagées entre instances)
   if(SMC_GV_IsBreakerActive(st.symbol, reason)) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Calcul lot + SL/TP puis envoi de l'ordre                          |
//+------------------------------------------------------------------+
bool MS_OpenTrade(const int idx, const int dir)
{
   MS_SymbolState st = g_msStates[idx];
   string sym = st.symbol;

   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return false;
   double price = (dir > 0) ? ask : bid;

   double slDist = 0.0, tpDist = 0.0;

   if(MS_UseVerdictSLTP && st.serverEntry > 0 && st.serverSL > 0 && st.serverTP > 0)
   {
      slDist = MathAbs(st.serverEntry - st.serverSL);
      tpDist = MathAbs(st.serverTP - st.serverEntry);
   }
   if(slDist <= 0 || tpDist <= 0)
   {
      double atr = MS_GetATR(sym);
      if(atr <= 0) return false;               // pas de SL possible -> pas d'entrée (sécurité)
      slDist = atr * MS_SL_ATRMult;
      tpDist = atr * MS_TP_ATRMult;
   }

   double sl = (dir > 0) ? price - slDist : price + slDist;
   double tp = (dir > 0) ? price + tpDist : price - tpDist;

   // Respecter le niveau d'arrêt minimum du broker
   double stops = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(sym, SYMBOL_POINT);
   if(stops > 0)
   {
      if(MathAbs(price - sl) < stops) sl = (dir > 0) ? price - stops : price + stops;
      if(MathAbs(price - tp) < stops) tp = (dir > 0) ? price + stops : price - stops;
   }

   // Lot : risque % equity, plafonné en $ par trade
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0) balance = 1000.0;
   double riskUSD = balance * MS_RiskPct / 100.0;
   if(riskUSD <= 0) riskUSD = 1.0;
   if(MS_CapLossPerTradeUSD > 0) riskUSD = MathMin(riskUSD, MS_CapLossPerTradeUSD);

   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double tickVal  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double lossPerLot = (tickSize > 0) ? (slDist / tickSize) * tickVal : 0.0;

   double lot = (lossPerLot > 0) ? riskUSD / lossPerLot : SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   if(lossPerLot > 0 && MS_CapLossPerTradeUSD > 0)
      lot = MathMin(lot, MS_CapLossPerTradeUSD / lossPerLot);
   lot = MS_NormalizeLot(sym, lot);
   if(lot <= 0) return false;

   long fillMode = SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
   ENUM_ORDER_TYPE_FILLING filling = ((fillMode & 1) != 0) ? ORDER_FILLING_FOK
                                    : (((fillMode & 2) != 0) ? ORDER_FILLING_IOC : ORDER_FILLING_RETURN);

   string dirStr = (dir > 0) ? "BUY" : "SELL";

   bool ok = false;
   for(int attempt = 0; attempt < 3 && !ok; attempt++)
   {
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action        = TRADE_ACTION_DEAL;
      req.symbol        = sym;
      req.volume        = lot;
      req.type          = (dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      req.price         = price;
      req.sl            = sl;
      req.tp            = tp;
      req.deviation     = MS_SlippagePoints;
      req.type_filling  = filling;
      req.magic         = InpMagicNumber;
      req.comment       = MS_OrderComment;
      ok = OrderSend(req, res) && (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED);
      if(!ok && attempt < 2) Sleep(250);
   }

   if(ok)
   {
      st.lastEntryTime = TimeCurrent();
      if(TimeCurrent() - g_msLastEntryLog >= 10)
      {
         g_msLastEntryLog = TimeCurrent();
         Print("[MULTISYM] ENTREE ", dirStr, " ", sym,
               " | lot=", DoubleToString(lot, 2),
               " | verdict=", st.verdict, " (vn=", st.verdictNum, ")",
               " | SL=", DoubleToString(sl, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)),
               " | TP=", DoubleToString(tp, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)));
      }
      PB_SendWhatsAppViaAI("MULTISYM", sym, "Master: entrée " + dirStr,
                           dirStr, price, sl, tp, lot);
   }
   if(ok) g_msStates[idx].lastEntryTime = st.lastEntryTime;
   return ok;
}

//+------------------------------------------------------------------+
//| Boucle d'évaluation des entrées                                   |
//+------------------------------------------------------------------+
void MS_EvaluateAndTrade()
{
   if(!g_msGomConnected) return;

   if(MS_CountOpenPositions("", 0) >= MS_MaxPositionsTotal) return;

   for(int i = 0; i < g_msStateCount; i++)
   {
      int dir = MS_DirectionFor(g_msStates[i]);
      if(dir == 0) continue;

      string reason = "";
      if(!MS_CanOpen(i, dir, reason)) continue;

      MS_OpenTrade(i, dir);
   }
}

//+------------------------------------------------------------------+
//| Fermeture d'une position master                                   |
//+------------------------------------------------------------------+
void MS_ClosePosition(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   string sym = PositionGetString(POSITION_SYMBOL);
   double vol = PositionGetDouble(POSITION_VOLUME);
   bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double price = isBuy ? SymbolInfoDouble(sym, SYMBOL_BID) : SymbolInfoDouble(sym, SYMBOL_ASK);

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_DEAL;
   req.position  = ticket;
   req.symbol    = sym;
   req.volume    = vol;
   req.type      = isBuy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.price     = price;
   req.deviation = MS_SlippagePoints;
   req.magic     = InpMagicNumber;
   req.comment   = "MS_CLOSE";
   if(OrderSend(req, res))
      Print("[MULTISYM] FERMETURE ", sym, " ticket=", ticket);
}

void MS_CloseSymbolSide(const string symbol, const int side)
{
   // Fermer la position la plus ancienne du sens donné sur ce symbole
   ulong oldest = 0;
   datetime oldestTime = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!MS_IsMasterPosition(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      if((side > 0 && !isBuy) || (side < 0 && isBuy)) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || t < oldestTime) { oldest = ticket; oldestTime = t; }
   }
   if(oldest != 0)
   {
      Print("[MULTISYM] Anti-hedge: fermeture de la position opposee sur ", symbol);
      MS_ClosePosition(oldest);
   }
}

//+------------------------------------------------------------------+
//| Gestion des sorties (verdict flip, WAIT, trailing, cap pertes)    |
//+------------------------------------------------------------------+
void MS_ManageExits()
{
   // ── Verdict flip / WAIT soutenu ──
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!MS_IsMasterPosition(ticket)) continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      int stIdx = MS_FindState(sym);
      if(stIdx < 0) continue;
      MS_SymbolState st = g_msStates[stIdx];
      if(!st.hasVerdict) continue;

      int vn = st.verdictNum;

      if(MS_CloseOnVerdictFlip && vn != 0 && vn != -999)
      {
         bool flipped = (isBuy && vn <= -MS_MinVerdictNum) || (!isBuy && vn >= MS_MinVerdictNum);
         if(flipped)
         {
            if(TimeCurrent() - g_msLastFlipLog >= 10)
            {
               g_msLastFlipLog = TimeCurrent();
               Print("[MULTISYM] Verdict retourne contre la position: ", sym,
                     " ", (isBuy ? "BUY" : "SELL"), " -> vn=", vn);
            }
            MS_ClosePosition(ticket);
            continue;
         }
      }

      if(MS_CloseOnWaitSustained && vn == 0 && st.waitPolls >= MS_WaitClosePollCount)
      {
         MS_ClosePosition(ticket);
         continue;
      }
   }

   // ── Anti-hedge : BUY+SELL simultanés sur le même symbole ──
   if(MS_AntiHedge)
   {
      for(int i = 0; i < g_msStateCount; i++)
      {
         int buys  = MS_CountOpenPositions(g_msStates[i].symbol, 1);
         int sells = MS_CountOpenPositions(g_msStates[i].symbol, -1);
         if(buys > 0 && sells > 0)
            MS_CloseSymbolSide(g_msStates[i].symbol, sells >= buys ? -1 : 1);
      }
   }

   // ── Cap perte flottante totale ──
   if(MS_MaxFloatLossUSD > 0)
   {
      double pnl = MS_TotalFloatPnl();
      if(pnl < -MS_MaxFloatLossUSD && TimeCurrent() - g_msLastFloatCut >= 10)
      {
         g_msLastFloatCut = TimeCurrent();
         Print("[MULTISYM] Perte flottante master ", DoubleToString(pnl, 2),
               "$ < -", DoubleToString(MS_MaxFloatLossUSD, 2),
               "$ → fermeture de toutes les positions master");
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(!MS_IsMasterPosition(ticket)) continue;
            MS_ClosePosition(ticket);
         }
      }
   }

   // ── Trailing (throttlé) ──
   if(TimeCurrent() - g_msLastTrailRun < 5) return;
   g_msLastTrailRun = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!MS_IsMasterPosition(ticket)) continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      double price = isBuy ? SymbolInfoDouble(sym, SYMBOL_BID) : SymbolInfoDouble(sym, SYMBOL_ASK);
      double atr = MS_GetATR(sym);

      int stIdx = MS_FindState(sym);
      int cat = (stIdx >= 0) ? g_msStates[stIdx].category : (int)SMC_GetSymbolCategory(sym);

      double newSL = 0.0;

      // Trail ATR classique
      if(MS_ATRTrailMult > 0 && atr > 0)
      {
         double trigger = atr * MS_ATRTrailMult;
         if(isBuy && price - open >= trigger)
         {
            double cand = price - atr;
            newSL = (curSL > 0) ? MathMax(curSL, cand) : cand;
         }
         else if(!isBuy && open - price >= trigger)
         {
            double cand = price + atr;
            newSL = (curSL > 0) ? MathMin(curSL, cand) : cand;
         }
      }

      // Trail FxVol : protéger MS_VolKeepPct % du gain
      if(cat == SYM_VOLATILITY && MS_VolKeepPct > 0 && atr > 0)
      {
         double keep = MS_VolKeepPct / 100.0;
         if(isBuy && price > open)
         {
            double cand = open + (price - open) * keep - atr * 0.3;
            newSL = MathMax(newSL, cand);
         }
         else if(!isBuy && price < open)
         {
            double cand = open - (open - price) * keep + atr * 0.3;
            newSL = (newSL > 0) ? MathMin(newSL, cand) : cand;
         }
      }

      if(newSL > 0 && newSL != curSL)
      {
         double stops = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(sym, SYMBOL_POINT);
         if(isBuy && newSL > price - stops) newSL = price - stops;
         if(!isBuy && newSL < price + stops) newSL = price + stops;

         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action   = TRADE_ACTION_SLTP;
         req.position = ticket;
         req.symbol   = sym;
         req.sl       = newSL;
         req.tp       = curTP;
         req.magic    = InpMagicNumber;
         if(OrderSend(req, res))
            Print("[MULTISYM] Trailing ", sym, " SL -> ", DoubleToString(newSL, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)));
      }
   }
}

//+------------------------------------------------------------------+
//| Dashboard texte (Comment)                                         |
//+------------------------------------------------------------------+
void MS_DrawDashboard()
{
   string lines = "";
   lines += "═══ MASTER MULTI-SYMBOLES ═══\n";
   lines += StringFormat("Connexion GOM: %s | Positions: %d/%d\n",
                         (g_msGomConnected ? "OK" : "PAS OK"),
                         MS_CountOpenPositions("", 0), MS_MaxPositionsTotal);
   for(int i = 0; i < g_msStateCount; i++)
   {
      MS_SymbolState st = g_msStates[i];
      int buys  = MS_CountOpenPositions(st.symbol, 1);
      int sells = MS_CountOpenPositions(st.symbol, -1);
      string v = (st.hasVerdict && TimeCurrent() - st.lastPoll <= MS_MaxVerdictAgeSec)
               ? StringFormat("%s (vn=%d)", st.verdict, st.verdictNum) : "pas de verdict";
      lines += StringFormat("%s [%s] %s | pos: %d/%d | coh: %.0f%%\n",
                            st.symbol,
                            (st.enabled ? "ON" : "OFF"),
                            v, buys + sells, MS_MaxPosPerSymbol,
                            st.coherencePct);
   }
   Comment(lines);
}

//+------------------------------------------------------------------+
//| Point d'entrée appelé par OnTick quand le master est actif        |
//+------------------------------------------------------------------+
void MS_OnTick()
{
   if(!g_msInitialized)
   {
      MS_Init();
      if(!g_msInitialized) return;
   }

   // Poll par symbole, throttle indépendant
   for(int i = 0; i < g_msStateCount; i++)
   {
      if(TimeCurrent() - g_msStates[i].lastPoll >= MS_PollIntervalSec)
         MS_PollOne(i);
   }

   g_msGomConnected = (TimeCurrent() - g_msLastSuccess <= MS_MaxVerdictAgeSec);

   MS_ManageExits();       // sorties d'abord (réduit le risque avant nouvelles entrées)
   MS_EvaluateAndTrade();
   MS_DrawDashboard();
}

#endif // SMC_MULTISYMBOL_MQH
