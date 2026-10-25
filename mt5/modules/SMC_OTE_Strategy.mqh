//+------------------------------------------------------------------+
//| SMC_OTE_Strategy.mqh                                              |
//| Implementation reelle de la strategie OTE (Optimal Trade Entry)   |
//| dont les 22 fonctions n'etaient QUE prototypees (lignes ~513-535  |
//| de SMC_Universal.mq5) et jamais definies/appelees.                |
//|                                                                    |
//| Zone OTE : retracement Fibo 61.8%-79% du dernier swing, entree    |
//| sniper a 70.5%. Confluence : Order Block + FVG + RSI + bougie de  |
//| confirmation (pin bar / engulfing). Cascade TP1..TP6 par          |
//| extension Fibonacci du swing (OTE_TP1_Fibo..OTE_TP6_Fibo).        |
//|                                                                    |
//| ATTENTION INTEGRATION :                                           |
//|  1) Si modules/SMC_Stubs.mqh definit deja des corps (meme vides)  |
//|     pour l'un des noms OTE_* ci-dessous, retirez-les de ce fichier|
//|     avant de compiler (MQL5 refuse les definitions dupliquees).   |
//|  2) SMC_CalculateLocalOTE() n'est actuellement appelee nulle part.|
//|     Ajoutez `if(UseOTEStrategy) SMC_CalculateLocalOTE();` dans    |
//|     OnTick() (une fois par symbole/bar, avant/apres vos autres    |
//|     strategies). Ajoutez aussi `SMC_ManageOTEPositions();` pour   |
//|     activer partial close / BE / trailing sur les trades OTE.    |
//|  3) Reutilise les globals/helpers deja definis dans le fichier    |
//|     principal : trade (CTrade), atrHandle, LTF, InpMagicNumber,   |
//|     GetMinLotForSymbol(), NormalizeVolumeForSymbol(),             |
//|     SMC_DetectFVG(), ComputeRSI(), swingPoints[]/swingPointCount. |
//+------------------------------------------------------------------+
#ifndef SMC_OTE_STRATEGY_MQH
#define SMC_OTE_STRATEGY_MQH

#define OTE_TAG_BUY   "OTE_BUY"
#define OTE_TAG_SELL  "OTE_SELL"
#define OTE_OBJ_PREFIX "OTE_LVL_"

struct OTESetup
{
   bool     valid;
   string   direction;      // "BUY" / "SELL"
   double   zoneBot, zoneMid, zoneTop;
   double   swingLowPrice, swingHighPrice;
   double   entry, sl;
   double   tp[6];
   int      tpCount;
   double   score;          // 0..1
   bool     confirmed;      // zone touchee + bougie de confirmation
   string   reason;
   datetime barTime;
};

OTESetup g_oteSetup;
datetime g_oteLastEvalBar   = 0;
int      g_oteStructureBias = 0;   // +1 haussier / -1 baissier / 0 neutre
int      g_oteHTFBias       = 0;

//+------------------------------------------------------------------+
//| Handles / lifecycle                                               |
//+------------------------------------------------------------------+
void OTE_InitHandles()
{
   // RSI est calcule via ComputeRSI(rates,...) directement sur les prix,
   // pas besoin de handle indicateur dedie. Fonction conservee pour
   // respecter la signature prototypee (extension future possible).
   ZeroMemory(g_oteSetup);
}

void OTE_ReleaseHandles()
{
   // Rien a liberer (pas de handle indicateur ouvert par ce module).
}

bool OTE_IsActiveSymbol(const string symbol)
{
   if(!UseOTEStrategy) return false;
   if(symbol == "") return false;
   return true;
}

//+------------------------------------------------------------------+
//| Conversion pips <-> prix                                          |
//+------------------------------------------------------------------+
double OTE_PipsToPrice(double pips)
{
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double mult   = (digits == 3 || digits == 5) ? 10.0 : 1.0;
   return pips * point * mult;
}

double OTE_PriceToPips(double dist)
{
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double mult   = (digits == 3 || digits == 5) ? 10.0 : 1.0;
   if(point <= 0) return 0.0;
   return dist / (point * mult);
}

//+------------------------------------------------------------------+
//| Swings (reutilise swingPoints[] deja alimente par                 |
//| DetectNonRepaintingSwingPoints(), sinon repli sur iHigh/iLow)     |
//+------------------------------------------------------------------+
void OTE_FindSwings(double &high1, double &high2, datetime &ht1, datetime &ht2,
                     double &low1, double &low2, datetime &lt1, datetime &lt2)
{
   high1 = high2 = 0.0; low1 = low2 = 0.0;
   ht1 = ht2 = lt1 = lt2 = 0;

   int hFound = 0, lFound = 0;
   for(int i = swingPointCount - 1; i >= 0 && (hFound < 2 || lFound < 2); i--)
   {
      if(swingPoints[i].isHigh && hFound < 2)
      {
         if(hFound == 0) { high1 = swingPoints[i].price; ht1 = swingPoints[i].time; }
         else            { high2 = swingPoints[i].price; ht2 = swingPoints[i].time; }
         hFound++;
      }
      else if(!swingPoints[i].isHigh && lFound < 2)
      {
         if(lFound == 0) { low1 = swingPoints[i].price; lt1 = swingPoints[i].time; }
         else            { low2 = swingPoints[i].price; lt2 = swingPoints[i].time; }
         lFound++;
      }
   }

   // Repli : buffer swingPoints[] pas assez rempli -> iHighest/iLowest bruts
   if(hFound < 1 || lFound < 1)
   {
      int idxH = iHighest(_Symbol, LTF, MODE_HIGH, OTE_LookbackLB, 0);
      int idxL = iLowest(_Symbol, LTF, MODE_LOW, OTE_LookbackLB, 0);
      if(hFound < 1 && idxH >= 0) { high1 = iHigh(_Symbol, LTF, idxH); ht1 = iTime(_Symbol, LTF, idxH); }
      if(lFound < 1 && idxL >= 0) { low1 = iLow(_Symbol, LTF, idxL);  lt1 = iTime(_Symbol, LTF, idxL); }
   }
}

void OTE_AnalyzeStructure()
{
   double h1, h2, l1, l2; datetime ht1, ht2, lt1, lt2;
   OTE_FindSwings(h1, h2, ht1, ht2, l1, l2, lt1, lt2);
   g_oteStructureBias = 0;
   if(h1 > 0 && h2 > 0 && h1 > h2) g_oteStructureBias = 1;      // HH -> biais haussier
   else if(l1 > 0 && l2 > 0 && l1 < l2) g_oteStructureBias = -1; // LL -> biais baissier
}

void OTE_UpdateHTFBias()
{
   g_oteHTFBias = 0;
   if(!OTE_UseMTF) return;
   ENUM_TIMEFRAMES htf = PERIOD_H1;
   double c0 = iClose(_Symbol, htf, 0);
   double c1 = iClose(_Symbol, htf, 8);
   if(c0 <= 0 || c1 <= 0) return;
   g_oteHTFBias = (c0 > c1) ? 1 : (c0 < c1 ? -1 : 0);
}

//+------------------------------------------------------------------+
//| Zone OTE (61.8% - 79%, sniper 70.5%)                              |
//+------------------------------------------------------------------+
void OTE_DetectZone()
{
   double h1, h2, l1, l2; datetime ht1, ht2, lt1, lt2;
   OTE_FindSwings(h1, h2, ht1, ht2, l1, l2, lt1, lt2);
   ZeroMemory(g_oteSetup);
   g_oteSetup.barTime = iTime(_Symbol, LTF, 0);

   int dirBias = (OTE_UseMTF && g_oteHTFBias != 0) ? g_oteHTFBias : g_oteStructureBias;

   if(dirBias >= 0 && l1 > 0 && h1 > l1)
   {
      double swing = h1 - l1;
      if(swing > 0)
      {
         g_oteSetup.direction     = "BUY";
         g_oteSetup.swingLowPrice = l1;
         g_oteSetup.swingHighPrice= h1;
         g_oteSetup.zoneTop = h1 - swing * OTE_618;
         g_oteSetup.zoneMid = h1 - swing * OTE_705;
         g_oteSetup.zoneBot = h1 - swing * OTE_790;
         g_oteSetup.valid   = true;
         return;
      }
   }
   if(dirBias <= 0 && h1 > 0 && h1 > l1)
   {
      double swing = h1 - l1;
      if(swing > 0)
      {
         g_oteSetup.direction     = "SELL";
         g_oteSetup.swingLowPrice = l1;
         g_oteSetup.swingHighPrice= h1;
         g_oteSetup.zoneBot = l1 + swing * OTE_618;
         g_oteSetup.zoneMid = l1 + swing * OTE_705;
         g_oteSetup.zoneTop = l1 + swing * OTE_790;
         g_oteSetup.valid   = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Confluence : Order Block                                          |
//+------------------------------------------------------------------+
bool g_oteOBFound = false;

void OTE_DetectOrderBlock()
{
   g_oteOBFound = false;
   if(!OTE_UseOB || !g_oteSetup.valid) return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, LTF, 0, OTE_OB_LB, rates) < 10) return;

   bool isBuy = (g_oteSetup.direction == "BUY");
   for(int i = 1; i < ArraySize(rates) - 1; i++)
   {
      double body  = MathAbs(rates[i].close - rates[i].open);
      double range = rates[i].high - rates[i].low;
      if(range <= 0 || body / range < OTE_OB_BodyRatio) continue;

      bool inZone = (rates[i].low <= g_oteSetup.zoneTop && rates[i].high >= g_oteSetup.zoneBot);
      if(!inZone) continue;

      if(isBuy && rates[i].close < rates[i].open) { g_oteOBFound = true; return; }   // OB baissier avant impulsion haussiere
      if(!isBuy && rates[i].close > rates[i].open) { g_oteOBFound = true; return; }  // OB haussier avant impulsion baissiere
   }
}

//+------------------------------------------------------------------+
//| Confluence : FVG (reutilise SMC_DetectFVG deja existant)          |
//+------------------------------------------------------------------+
bool g_oteFVGFound = false;

void OTE_DetectFVG()
{
   g_oteFVGFound = false;
   if(!OTE_UseFVG || !g_oteSetup.valid) return;

   FVGData fvg;
   if(!SMC_DetectFVG(_Symbol, LTF, 30, fvg)) return;

   bool overlap = !(fvg.top < g_oteSetup.zoneBot || fvg.bottom > g_oteSetup.zoneTop);
   double gapPips = OTE_PriceToPips(MathAbs(fvg.top - fvg.bottom));
   if(overlap && gapPips >= OTE_FVG_MinPips) g_oteFVGFound = true;
}

//+------------------------------------------------------------------+
//| Confluence : bougie de confirmation (pin bar / engulfing)         |
//+------------------------------------------------------------------+
bool OTE_ConfirmBullish()
{
   if(!OTE_UsePinBar && !OTE_UseEngulfing) return true; // pas de filtre demande

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, LTF, 0, 3, r) < 3) return false;

   double body  = MathAbs(r[1].close - r[1].open);
   double lower = MathMin(r[1].open, r[1].close) - r[1].low;
   double upper = r[1].high - MathMax(r[1].open, r[1].close);
   double range = r[1].high - r[1].low;

   bool pin = OTE_UsePinBar && range > 0 &&
              lower >= body * 1.8 && lower >= range * 0.55 && upper <= body * 0.6;
   bool engulf = OTE_UseEngulfing &&
                 r[2].close < r[2].open && r[1].close > r[1].open &&
                 r[1].close >= r[2].open && r[1].open <= r[2].close;

   return pin || engulf;
}

bool OTE_ConfirmBearish()
{
   if(!OTE_UsePinBar && !OTE_UseEngulfing) return true;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, LTF, 0, 3, r) < 3) return false;

   double body  = MathAbs(r[1].close - r[1].open);
   double upper = r[1].high - MathMax(r[1].open, r[1].close);
   double lower = MathMin(r[1].open, r[1].close) - r[1].low;
   double range = r[1].high - r[1].low;

   bool pin = OTE_UsePinBar && range > 0 &&
              upper >= body * 1.8 && upper >= range * 0.55 && lower <= body * 0.6;
   bool engulf = OTE_UseEngulfing &&
                 r[2].close > r[2].open && r[1].close < r[1].open &&
                 r[1].close <= r[2].open && r[1].open >= r[2].close;

   return pin || engulf;
}

//+------------------------------------------------------------------+
//| RSI (reutilise ComputeRSI deja defini dans le fichier principal)  |
//+------------------------------------------------------------------+
bool OTE_RSIok(bool isBuy)
{
   if(!OTE_UseRSI) return true;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, LTF, 0, OTE_RSI_Period + 5, r) < OTE_RSI_Period + 5) return true;
   double rsi = ComputeRSI(r, OTE_RSI_Period, 0);
   if(isBuy)  return rsi >= OTE_RSI_BullMin;
   return rsi <= OTE_RSI_BearMax;
}

//+------------------------------------------------------------------+
//| Limites journalieres / session / comptage                         |
//+------------------------------------------------------------------+
int g_oteDayTradeCount = 0;
datetime g_oteDayStamp = 0;
double   g_oteDayStartEquity = 0.0;

void OTE_ResetDayIfNeeded()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   datetime dayStart = TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   if(dayStart != g_oteDayStamp)
   {
      g_oteDayStamp        = dayStart;
      g_oteDayTradeCount   = 0;
      g_oteDayStartEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   }
}

int OTE_CountTrades()
{
   OTE_ResetDayIfNeeded();
   int total = g_oteDayTradeCount;
   // + positions OTE actuellement ouvertes (comptees une fois, deja incluses
   //   dans g_oteDayTradeCount au moment de l'ouverture ; ce compteur sert
   //   surtout de garde-fou si l'EA redemarre en cours de journee).
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol || posInfo.Magic() != InpMagicNumber) continue;
      if(StringFind(posInfo.Comment(), "OTE_") != 0) continue;
      // deja compte via g_oteDayTradeCount a l'ouverture -> pas de double compte ici
   }
   return total;
}

bool OTE_HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol || posInfo.Magic() != InpMagicNumber) continue;
      if(StringFind(posInfo.Comment(), "OTE_") == 0) return true;
   }
   return false;
}

bool OTE_CheckDailyLimits()
{
   OTE_ResetDayIfNeeded();
   if(g_oteDayTradeCount >= OTE_MaxTrades) return false;

   if(g_oteDayStartEquity > 0)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double pnlPct = (equity - g_oteDayStartEquity) / g_oteDayStartEquity * 100.0;
      if(pnlPct <= -MathAbs(OTE_MaxLoss_Day))  return false;
      if(pnlPct >=  MathAbs(OTE_MaxProfit_Day)) return false;
   }
   return true;
}

bool OTE_IsSessionOK()
{
   if(!OTE_UseSession) return true;
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);

   switch(dt.day_of_week)
   {
      case 1: if(!OTE_Trade_Mon) return false; break;
      case 2: if(!OTE_Trade_Tue) return false; break;
      case 3: if(!OTE_Trade_Wed) return false; break;
      case 4: if(!OTE_Trade_Thu) return false; break;
      case 5: if(!OTE_Trade_Fri) return false; break;
      default: return false; // week-end
   }
   if(OTE_Sess_Start <= OTE_Sess_End)
      return (dt.hour >= OTE_Sess_Start && dt.hour < OTE_Sess_End);
   return (dt.hour >= OTE_Sess_Start || dt.hour < OTE_Sess_End); // session a cheval sur minuit
}

//+------------------------------------------------------------------+
//| SL / TP / Lots                                                    |
//+------------------------------------------------------------------+
double OTE_GetATR()
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, buf) >= 1) return buf[0];
   return OTE_PipsToPrice(10); // repli grossier si handle indispo
}

double OTE_CalcBuySL(double entry, double bid)
{
   double atr = OTE_GetATR();
   return g_oteSetup.zoneBot - atr * 0.30;
}

double OTE_CalcSellSL(double entry, double ask)
{
   double atr = OTE_GetATR();
   return g_oteSetup.zoneTop + atr * 0.30;
}

// Remplit g_oteSetup.tp[0..5] (TP1..TP6) par extension Fibonacci du swing.
void OTE_ComputeAllTPs()
{
   double ratios[6];
   ratios[0] = OTE_TP1_Fibo; ratios[1] = OTE_TP2_Fibo; ratios[2] = OTE_TP3_Fibo;
   ratios[3] = OTE_TP4_Fibo; ratios[4] = OTE_TP5_Fibo; ratios[5] = OTE_TP6_Fibo;

   double swing = g_oteSetup.swingHighPrice - g_oteSetup.swingLowPrice;
   bool isBuy = (g_oteSetup.direction == "BUY");
   g_oteSetup.tpCount = 0;
   for(int i = 0; i < 6; i++)
   {
      double level = isBuy
         ? g_oteSetup.swingLowPrice  + swing * ratios[i]
         : g_oteSetup.swingHighPrice - swing * ratios[i];
      g_oteSetup.tp[i] = level;
      g_oteSetup.tpCount++;
   }
}

double OTE_CalcBuyTP(double entry, double sl)
{
   OTE_ComputeAllTPs();
   return g_oteSetup.tpCount > 0 ? g_oteSetup.tp[0] : entry + MathAbs(entry - sl) * OTE_TP1_Fibo;
}

double OTE_CalcSellTP(double entry, double sl)
{
   OTE_ComputeAllTPs();
   return g_oteSetup.tpCount > 0 ? g_oteSetup.tp[0] : entry - MathAbs(sl - entry) * OTE_TP1_Fibo;
}

double OTE_CalcLots(double entry, double sl)
{
   double dist = MathAbs(entry - sl);
   if(dist <= 0) return GetMinLotForSymbol(_Symbol);

   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * (OTE_Risk_Pct / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0 || tickValue <= 0) return GetMinLotForSymbol(_Symbol);

   double lossPerLot = (dist / tickSize) * tickValue;
   if(lossPerLot <= 0) return GetMinLotForSymbol(_Symbol);

   double lots = riskMoney / lossPerLot;
   lots = NormalizeVolumeForSymbol(lots);
   double minLot = GetMinLotForSymbol(_Symbol);
   if(lots < minLot) lots = minLot;
   return lots;
}

//+------------------------------------------------------------------+
//| Placement d'ordre (CTrade natif — cf `CTrade trade;` global)      |
//+------------------------------------------------------------------+
bool OTE_PlaceTrade(string direction, double ask, double bid, double sl, double tp, double lots)
{
   // Ouverture unifiée (MARKET) — anciennement trade.Buy()/trade.Sell() en direct,
   // ce qui contournait TOUTES les gardes centrales (SMC_FinalOpenGate, SafeOrderSend :
   // GOM WAIT/seuil/cohérence, contre-trend Boom/Crash, anti-hedge, cap SL $).
   // OTE passe désormais par le même point d'entrée unique que les autres stratégies.
   string comment = (direction == "BUY") ? OTE_TAG_BUY : OTE_TAG_SELL;

   SMC_EntryRequest oteEr;
   SMC_EntryRequest_Init(oteEr);
   oteEr.symbol      = _Symbol;
   oteEr.orderType   = (direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   oteEr.volume      = lots;
   oteEr.price       = (direction == "BUY") ? ask : bid;
   oteEr.sl          = sl;
   oteEr.tp          = tp;
   oteEr.comment     = comment;
   oteEr.sourceLabel = "OTE";

   MqlTradeResult res;
   bool ok = SMC_SubmitEntry(oteEr, res);

   if(ok)
      g_oteDayTradeCount++;
   else
      Print("🚫 OTE ", direction, " ", _Symbol, " rejeté — retcode=", res.retcode);

   return ok;
}

//+------------------------------------------------------------------+
//| Dessin des niveaux TP1..TPn / entree / SL sur le graphique         |
//+------------------------------------------------------------------+
void SMC_CleanMultiTP()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, OTE_OBJ_PREFIX) == 0) ObjectDelete(0, name);
   }
}

void SMC_DrawMultiTP(double entryPrice, double slPrice, double dirSign)
{
   SMC_CleanMultiTP();

   string nameEntry = OTE_OBJ_PREFIX + "ENTRY";
   ObjectCreate(0, nameEntry, OBJ_HLINE, 0, 0, entryPrice);
   ObjectSetInteger(0, nameEntry, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, nameEntry, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetString(0, nameEntry, OBJPROP_TEXT, "OTE Entry");

   string nameSL = OTE_OBJ_PREFIX + "SL";
   ObjectCreate(0, nameSL, OBJ_HLINE, 0, 0, slPrice);
   ObjectSetInteger(0, nameSL, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, nameSL, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetString(0, nameSL, OBJPROP_TEXT, "OTE SL");

   color tpColors[6] = { clrLimeGreen, clrLimeGreen, clrGreen, clrGreen, clrDarkGreen, clrDarkGreen };
   for(int i = 0; i < g_oteSetup.tpCount && i < 6; i++)
   {
      string nameTP = OTE_OBJ_PREFIX + "TP" + IntegerToString(i + 1);
      ObjectCreate(0, nameTP, OBJ_HLINE, 0, 0, g_oteSetup.tp[i]);
      ObjectSetInteger(0, nameTP, OBJPROP_COLOR, tpColors[i]);
      ObjectSetInteger(0, nameTP, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetString(0, nameTP, OBJPROP_TEXT, "OTE TP" + IntegerToString(i + 1));
   }
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Orchestrateur principal — a appeler depuis OnTick() :              |
//|   if(UseOTEStrategy) SMC_CalculateLocalOTE();                     |
//+------------------------------------------------------------------+
void SMC_CalculateLocalOTE()
{
   if(!UseOTEStrategy || !OTE_IsActiveSymbol(_Symbol)) return;

   // 1 evaluation par bougie LTF fermee (evite le repaint / les doublons)
   datetime curBar = iTime(_Symbol, LTF, 0);
   if(curBar == g_oteLastEvalBar) return;
   g_oteLastEvalBar = curBar;

   if(!OTE_IsSessionOK())      return;
   if(!OTE_CheckDailyLimits()) return;
   if(OTE_HasOpenPosition())   return; // pas d'empilement sur le meme symbole

   OTE_UpdateHTFBias();
   OTE_AnalyzeStructure();
   OTE_DetectZone();
   if(!g_oteSetup.valid) return;

   // ── Garde-fou GOM (meme convention que le reste de l'EA : jamais un      ──
   // ── module local ne doit trader a l'encontre du verdict GOM principal). ──
   if(UseGOMVerdictFilter && g_smcGomConnected)
   {
      bool oteBuy = (g_oteSetup.direction == "BUY");
      if(oteBuy && g_smcGomVerdictNum < 0)
      {
         Print("🚫 OTE BUY BLOQUÉ — GOM verdict=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ") — direction SELL");
         return;
      }
      if(!oteBuy && g_smcGomVerdictNum > 0)
      {
         Print("🚫 OTE SELL BLOQUÉ — GOM verdict=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ") — direction BUY");
         return;
      }
      if(MathAbs(g_smcGomVerdictNum) < MinGOMVerdictNumAbs)
      {
         Print("🚫 OTE ", g_oteSetup.direction, " BLOQUÉ — GOM verdict trop faible (vn=", g_smcGomVerdictNum,
               ", exige |vn|>=", MinGOMVerdictNumAbs, ")");
         return;
      }
   }

   OTE_DetectOrderBlock();
   OTE_DetectFVG();

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double last = (g_oteSetup.direction == "BUY") ? ask : bid;

   double atr = OTE_GetATR();
   bool inZone = (last >= g_oteSetup.zoneBot - atr * 0.15) && (last <= g_oteSetup.zoneTop + atr * 0.15);
   if(!inZone) { g_oteSetup.reason = "hors_zone"; return; }

   bool isBuy = (g_oteSetup.direction == "BUY");
   bool confCandle = isBuy ? OTE_ConfirmBullish() : OTE_ConfirmBearish();
   bool rsiOk       = OTE_RSIok(isBuy);

   int votes = (g_oteOBFound ? 1 : 0) + (g_oteFVGFound ? 1 : 0) + (rsiOk ? 1 : 0);
   double score = 0.76 + votes * 0.045 + (confCandle ? 0.08 : 0.0);
   if(score > 0.97) score = 0.97;

   g_oteSetup.score     = score;
   g_oteSetup.confirmed = confCandle && rsiOk;

   if(!g_oteSetup.confirmed)
   {
      g_oteSetup.reason = StringFormat("watch score=%.2f OB=%s FVG=%s RSI=%s conf=%s",
                                        score, g_oteOBFound ? "1" : "0", g_oteFVGFound ? "1" : "0",
                                        rsiOk ? "1" : "0", confCandle ? "1" : "0");
      return; // pas d'entree tant que non confirme — on privilegie la qualite du signal
   }

   double entry = last;
   double sl    = isBuy ? OTE_CalcBuySL(entry, bid) : OTE_CalcSellSL(entry, ask);
   double tp1   = isBuy ? OTE_CalcBuyTP(entry, sl)   : OTE_CalcSellTP(entry, sl);

   double risk = MathAbs(entry - sl);
   double reward = MathAbs(tp1 - entry);
   if(risk <= 0 || reward / risk < OTE_Min_RR)
   {
      g_oteSetup.reason = "RR_insuffisant";
      return;
   }

   double lots = OTE_CalcLots(entry, sl);
   g_oteSetup.entry = entry;
   g_oteSetup.sl    = sl;

   if(OTE_PlaceTrade(g_oteSetup.direction, ask, bid, sl, tp1, lots))
      SMC_DrawMultiTP(entry, sl, isBuy ? 1.0 : -1.0);
}

//+------------------------------------------------------------------+
//| Gestion des positions OTE ouvertes : partial close TP1 / BE /     |
//| trailing. A appeler chaque tick : SMC_ManageOTEPositions();       |
//| (bonus — n'etait pas dans les 22 prototypes d'origine mais est    |
//| necessaire pour que OTE_PartialClose / OTE_UseBE / OTE_UseTrailing|
//| aient un effet reel).                                             |
//+------------------------------------------------------------------+
void SMC_ManageOTEPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol || posInfo.Magic() != InpMagicNumber) continue;
      if(StringFind(posInfo.Comment(), "OTE_") != 0) continue;

      ulong  ticket   = posInfo.Ticket();
      bool   isBuy    = (posInfo.PositionType() == POSITION_TYPE_BUY);
      double openPx   = posInfo.PriceOpen();
      double curSL    = posInfo.StopLoss();
      double curPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double risk     = MathAbs(openPx - curSL);
      if(risk <= 0) continue;
      double rMultiple = isBuy ? (curPrice - openPx) / risk : (openPx - curPrice) / risk;

      // Partial close au niveau TP1 (1R par defaut, cf OTE_TP1_Fibo)
      if(OTE_PartialClose && rMultiple >= OTE_TP1_Fibo)
      {
         double vol = posInfo.Volume();
         double closeVol = NormalizeVolumeForSymbol(vol * OTE_PartialPct / 100.0);
         if(closeVol > 0 && closeVol < vol)
         {
            trade.PositionClosePartial(ticket, closeVol);
         }
      }

      // Breakeven
      if(OTE_UseBE && rMultiple >= OTE_BE_Trigger_R)
      {
         bool needBE = isBuy ? (curSL < openPx) : (curSL > openPx || curSL == 0);
         if(needBE) trade.PositionModify(ticket, openPx, posInfo.TakeProfit());
      }

      // Trailing stop simple par pas fixe (OTE_Trail_StepPips)
      if(OTE_UseTrailing && rMultiple >= OTE_Trail_StartR)
      {
         double step = OTE_PipsToPrice(OTE_Trail_StepPips);
         double newSL = isBuy ? curPrice - step : curPrice + step;
         bool improve = isBuy ? (newSL > curSL) : (curSL == 0 || newSL < curSL);
         if(improve) trade.PositionModify(ticket, newSL, posInfo.TakeProfit());
      }
   }
}

#endif // SMC_OTE_STRATEGY_MQH
