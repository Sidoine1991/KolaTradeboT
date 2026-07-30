//+------------------------------------------------------------------+
//| SMC_OTE_Zone.mqh — Zone OTE (Optimal Trade Entry, retracement    |
//| Fibonacci 61.8%-79%) sur le dernier swing M5.                    |
//| Remplace les stubs vides précédents (aucune logique n'existait). |
//| Entrée gardée par : GOM GOOD/PERFECT + blink confirmé + règle    |
//| absolue Boom/Crash/Painx/Gainx + plafonds terminal existants.    |
//+------------------------------------------------------------------+
#ifndef SMC_OTE_ZONE_MQH
#define SMC_OTE_ZONE_MQH

struct SMC_OTEState
{
   bool     zoneActive;
   int      dirSign;        // +1 bullish (retracement vers le bas dans une hausse), -1 bearish
   double   swingStart;     // début de l'impulsion (origine du fib)
   double   swingEnd;       // extrémité de l'impulsion (100%)
   double   zoneHi;         // borne haute de la zone OTE (61.8%)
   double   zoneLo;         // borne basse de la zone OTE (79%)
   datetime lastEntryTime;
   int      tradesToday;
   datetime dayStamp;
};
SMC_OTEState g_oteState = {false, 0, 0.0, 0.0, 0.0, 0.0, 0, 0, 0};

int g_oteATRHandle = INVALID_HANDLE;

//--- Limites simples (par jour) pour éviter le sur-trading OTE
input int    OTE_MaxTradesPerDay = 3;
input double OTE_SL_ATRMult      = 1.5;
input double OTE_TP_ATRMult      = 3.0;
input int    OTE_CooldownSec     = 30;

//+------------------------------------------------------------------+
bool OTE_IsActiveSymbol(const string symbol)
{
   // Zone OTE utilisable sur tout symbole où le GOM/Spike-state est actif
   return true;
}

void OTE_InitHandles()
{
   if(g_oteATRHandle == INVALID_HANDLE)
      g_oteATRHandle = iATR(_Symbol, PERIOD_M5, 14);
}

void OTE_ReleaseHandles()
{
   if(g_oteATRHandle != INVALID_HANDLE) { IndicatorRelease(g_oteATRHandle); g_oteATRHandle = INVALID_HANDLE; }
}

double OTE_GetATR()
{
   if(g_oteATRHandle == INVALID_HANDLE) OTE_InitHandles();
   double buf[];
   ArraySetAsSeries(buf, true);
   if(g_oteATRHandle == INVALID_HANDLE || CopyBuffer(g_oteATRHandle, 0, 0, 1, buf) < 1) return 0.0;
   return buf[0];
}

//+------------------------------------------------------------------+
//| Récupère le dernier swing (réutilise g_lastSwingHigh/Low déjà    |
//| maintenus par la détection SMC principale — évite de dupliquer   |
//| une détection de fractales redondante)                           |
//+------------------------------------------------------------------+
void OTE_FindSwings(double &high1, double &high2, datetime &ht1, datetime &ht2,
                    double &low1, double &low2, datetime &lt1, datetime &lt2)
{
   high1 = g_lastSwingHigh; high2 = 0; ht1 = TimeCurrent(); ht2 = 0;
   low1  = g_lastSwingLow;  low2  = 0; lt1 = TimeCurrent(); lt2 = 0;
}

//+------------------------------------------------------------------+
//| Détermine la structure / biais directionnel.                     |
//| RÈGLE ABSOLUE : Boom/Gainx => biais haussier seul autorisé,       |
//| Crash/Painx => biais baissier seul autorisé (jamais l'inverse).  |
//+------------------------------------------------------------------+
void OTE_AnalyzeStructure()
{
   bool isBoom  = IsBoomLikeSymbol(_Symbol);
   bool isCrash = IsCrashLikeSymbol(_Symbol);

   int structDir = 0;
   if(isBoom)       structDir = 1;
   else if(isCrash) structDir = -1;
   else
   {
      // Symboles non-spike : biais issu du verdict GOM (si disponible)
      if(g_smcGomConnected && MathAbs(g_smcGomVerdictNum) >= 2)
         structDir = (g_smcGomVerdictNum > 0) ? 1 : -1;
   }
   g_oteState.dirSign = structDir;
}

void OTE_UpdateHTFBias()
{
   // Confirmation H1 : le verdict GOM doit être GOOD/PERFECT et aligné avec le biais structurel
   if(g_oteState.dirSign == 0) return;
   if(!g_smcGomConnected || MathAbs(g_smcGomVerdictNum) < 2)
   {
      g_oteState.zoneActive = false;
      return;
   }
   bool aligned = (g_oteState.dirSign > 0 && g_smcGomVerdictNum >= 2) ||
                  (g_oteState.dirSign < 0 && g_smcGomVerdictNum <= -2);
   if(!aligned) g_oteState.zoneActive = false;
}

//+------------------------------------------------------------------+
//| Calcule la zone OTE (61.8% - 79%) du dernier swing                |
//+------------------------------------------------------------------+
void OTE_DetectZone()
{
   if(g_oteState.dirSign == 0) { g_oteState.zoneActive = false; return; }
   if(g_lastSwingHigh <= 0 || g_lastSwingLow <= 0) { g_oteState.zoneActive = false; return; }
   if(g_lastSwingHigh <= g_lastSwingLow) { g_oteState.zoneActive = false; return; }

   double range = g_lastSwingHigh - g_lastSwingLow;
   if(range <= 0) { g_oteState.zoneActive = false; return; }

   if(g_oteState.dirSign > 0) // impulsion haussière → retracement depuis le haut
   {
      g_oteState.swingStart = g_lastSwingLow;
      g_oteState.swingEnd   = g_lastSwingHigh;
      g_oteState.zoneHi = g_lastSwingHigh - range * 0.618;
      g_oteState.zoneLo = g_lastSwingHigh - range * 0.79;
   }
   else // impulsion baissière → retracement depuis le bas
   {
      g_oteState.swingStart = g_lastSwingHigh;
      g_oteState.swingEnd   = g_lastSwingLow;
      g_oteState.zoneLo = g_lastSwingLow + range * 0.618;
      g_oteState.zoneHi = g_lastSwingLow + range * 0.79;
   }
   g_oteState.zoneActive = true;
}

void OTE_DetectOrderBlock() { /* Affinage optionnel — non nécessaire au fonctionnement de base */ }
void OTE_DetectFVG()        { /* Affinage optionnel — non nécessaire au fonctionnement de base */ }

//+------------------------------------------------------------------+
//| Confirmation d'entrée bullish/bearish : prix dans la zone OTE +  |
//| GOM GOOD/PERFECT + décision clignotante confirmée + règle spike  |
//+------------------------------------------------------------------+
bool OTE_ConfirmBullish()
{
   if(!g_oteState.zoneActive || g_oteState.dirSign != 1) return false;
   if(!IsDirectionAllowedForBoomCrash(_Symbol, "BUY")) return false;
   if(!IsSignalConfirmed() || GetConfirmedSignalDir() != 1) return false;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0) return false;
   return (ask <= g_oteState.zoneHi && ask >= g_oteState.zoneLo);
}

bool OTE_ConfirmBearish()
{
   if(!g_oteState.zoneActive || g_oteState.dirSign != -1) return false;
   if(!IsDirectionAllowedForBoomCrash(_Symbol, "SELL")) return false;
   if(!IsSignalConfirmed() || GetConfirmedSignalDir() != -1) return false;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0) return false;
   return (bid <= g_oteState.zoneHi && bid >= g_oteState.zoneLo);
}

//+------------------------------------------------------------------+
bool OTE_CheckDailyLimits()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   if(today != g_oteState.dayStamp)
   {
      g_oteState.dayStamp = today;
      g_oteState.tradesToday = 0;
   }
   return (g_oteState.tradesToday < MathMax(1, OTE_MaxTradesPerDay));
}

bool OTE_IsSessionOK() { return true; } // Pas de restriction de session spécifique pour l'instant

int OTE_CountTrades() { return g_oteState.tradesToday; }

double OTE_PipsToPrice(double pips) { return pips * _Point * 10.0; }
double OTE_PriceToPips(double dist) { return (_Point > 0) ? dist / (_Point * 10.0) : 0.0; }

double OTE_CalcBuySL(double entry, double bid)
{
   double atr = OTE_GetATR();
   return NormalizeDouble(entry - atr * OTE_SL_ATRMult, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}
double OTE_CalcSellSL(double entry, double ask)
{
   double atr = OTE_GetATR();
   return NormalizeDouble(entry + atr * OTE_SL_ATRMult, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}
double OTE_CalcBuyTP(double entry, double sl)
{
   double atr = OTE_GetATR();
   return NormalizeDouble(entry + atr * OTE_TP_ATRMult, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}
double OTE_CalcSellTP(double entry, double sl)
{
   double atr = OTE_GetATR();
   return NormalizeDouble(entry - atr * OTE_TP_ATRMult, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}
double OTE_CalcLots(double entry, double sl) { return CalculateLotSize(); }

//+------------------------------------------------------------------+
//| Envoi effectif de l'ordre marché OTE (mêmes gardes que les       |
//| autres méthodes : direction absolue + plafond terminal)          |
//+------------------------------------------------------------------+
bool OTE_PlaceTrade(string direction, double ask, double bid, double sl, double tp, double lots)
{
   if(lots <= 0) return false;
   int dirSign = (direction == "BUY") ? 1 : -1;
   if(!IsDirectionAllowedForBoomCrash(_Symbol, direction)) return false;
   if(!CanPlaceMarketOrder(_Symbol, dirSign)) return false;
   if(CountPositionsForSymbol(_Symbol) > 0) return false;
   if(!TryAcquireOpenLock()) return false;

   bool ok = false;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(direction == "BUY")
      ok = trade.Buy(lots, _Symbol, ask, NormalizeDouble(sl, dg), NormalizeDouble(tp, dg), "OTE ZONE BUY");
   else
      ok = trade.Sell(lots, _Symbol, bid, NormalizeDouble(sl, dg), NormalizeDouble(tp, dg), "OTE ZONE SELL");

   if(ok)
   {
      RegisterOrderPlaced();
      g_oteState.tradesToday++;
      g_oteState.lastEntryTime = TimeCurrent();
      ulong ticket = trade.ResultOrder();
      if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
      Print("🚀 OTE ZONE ", direction, " | zone[", DoubleToString(g_oteState.zoneLo, dg),
            "-", DoubleToString(g_oteState.zoneHi, dg), "] | SL=", DoubleToString(sl, dg),
            " TP=", DoubleToString(tp, dg), " Lot=", DoubleToString(lots, 2));
   }
   ReleaseOpenLock();
   return ok;
}

//+------------------------------------------------------------------+
//| Point d'entrée principal appelé depuis OnTick                    |
//+------------------------------------------------------------------+
bool OTE_PlaceOTETrade(const int dirSign)
{
   if(dirSign == 0) return false;
   if(!OTE_CheckDailyLimits()) return false;
   if(!OTE_IsSessionOK()) return false;
   if(TimeCurrent() - g_oteState.lastEntryTime < OTE_CooldownSec) return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0 || bid <= 0) return false;

   string direction = (dirSign > 0) ? "BUY" : "SELL";
   double lots = OTE_CalcLots(0, 0);
   double sl, tp;
   if(dirSign > 0)
   {
      sl = OTE_CalcBuySL(ask, bid);
      tp = OTE_CalcBuyTP(ask, sl);
   }
   else
   {
      sl = OTE_CalcSellSL(bid, ask);
      tp = OTE_CalcSellTP(bid, sl);
   }
   return OTE_PlaceTrade(direction, ask, bid, sl, tp, lots);
}

//+------------------------------------------------------------------+
void OTE_ManageTrades()
{
   // Nettoyage léger : rien de spécifique à gérer au-delà de la gestion
   // générique des positions déjà assurée par le reste de l'EA (trailing, SL, TP).
}

void OTE_DailyReset()
{
   g_oteState.tradesToday = 0;
}

bool OTE_IsNewBar()
{
   static datetime s_last = 0;
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   if(t <= 0 || t == s_last) return false;
   s_last = t;
   return true;
}

void OTE_OnNewBar()
{
   if(!OTE_IsNewBar()) return;
   // La structure/zone est recalculée à chaque nouvelle bougie M5
}

//+------------------------------------------------------------------+
//| Dessine la zone OTE sur le graphique (rectangle) — la "promeut"  |
//| visuellement comme demandé                                       |
//+------------------------------------------------------------------+
void OTE_DrawZone()
{
   string name = "OTE_ZONE_RECT";
   if(!g_oteState.zoneActive)
   {
      ObjectDelete(0, name);
      return;
   }
   datetime t0 = iTime(_Symbol, PERIOD_M5, 10);
   datetime t1 = TimeCurrent() + PeriodSeconds(PERIOD_M5) * 5;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t0, g_oteState.zoneHi, t1, g_oteState.zoneLo);
   else
   {
      ObjectMove(0, name, 0, t0, g_oteState.zoneHi);
      ObjectMove(0, name, 1, t1, g_oteState.zoneLo);
   }
   color clr = (g_oteState.dirSign > 0) ? clrDodgerBlue : clrOrange;
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

#endif // SMC_OTE_ZONE_MQH
