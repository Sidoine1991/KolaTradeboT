//+------------------------------------------------------------------+
//| SMC_PurePriceAction.mqh                                          |
//| Architecture Pure Price Action (rapport Deep Research)           |
//| + GOM comme DERNIÈRE validation uniquement                       |
//|                                                                  |
//| Modules :                                                        |
//|  1. Analyse marché (structure, swings, BOS, CHoCH, tendance)     |
//|  2. Détection patterns (réutilise + étend SMC_PatternSignals)    |
//|  3. Filtrage contextuel (session, spread, volatilité)            |
//|  4. Gestion du risque (1% max, RR min, kill-switch journalier)   |
//|  5. Exécution + suivi position (BE, trailing, partial)           |
//|  6. Monitoring & sécurité                                        |
//|                                                                  |
//| Principe clé :                                                   |
//|  - Tout le signal vient du Price Action (structure + pattern)    |
//|  - GOM n’est consulté qu’à la toute fin :                        |
//|      • WAIT / déconnecté  → BLOQUE                               |
//|      • Direction opposée  → BLOQUE                               |
//|      • GOOD/PERFECT aligné + STABLE (anti-flicker) → AUTORISE    |
//|  → On ne trade jamais en condition défavorable.                  |
//|                                                                  |
//| AFFINAGE 2026-09-14 :                                            |
//|  - GOM doit rester GOOD/PERFECT dans la même direction N sec     |
//|  - Cohérence GOM mini configurable                               |
//|  - Confirmation corps M1 + anti-chase (prix trop étendu du niveau)|
//|  - Weltrade Vol inclus (pas d'exclusion) ; mêmes règles strictes |
//+------------------------------------------------------------------+
#ifndef SMC_PURE_PRICE_ACTION_MQH
#define SMC_PURE_PRICE_ACTION_MQH

//--- Inputs dédiés Pure PA (peuvent être surchargés dans l’EA principal)
input group "===== PURE PRICE ACTION ====="
input bool   UsePurePriceActionMode     = true;  // Confirmations PA + niveaux DOW/FVG/GOM_TF (GOM = validation finale)
input bool   PurePA_ExclusiveEntries    = false; // false = GOM pipeline + DOW line/EP + FVG DISP restent autorisés
input bool   PurePA_RequireGOMFinalGate = true;   // GOM = dernière validation obligatoire
input bool   PurePA_ConfirmGOMEntries   = false;  // false : ne pas bloquer GOM/DOW/FVG si le bias PA diverge
input bool   PurePA_AllowSimpleGOM      = false;  // false = exige GOOD/PERFECT (|vn|>=2)
input int    PurePA_GOMMinSustainSec    = 25;     // GOM GOOD/PERFECT doit tenir N sec (anti-flicker)
input double PurePA_MinCoherencePct     = 55.0;   // Cohérence GOM mini (%) — 0 = désactivé
input double PurePA_RiskPercent         = 1.0;    // Risque max par trade (% equity)
input double PurePA_MinRR               = 2.0;    // Ratio Reward/Risk minimum
input double PurePA_MaxDailyLossPct     = 3.0;    // Kill-switch : perte journalière max (%)
input double PurePA_MaxSpreadPercent    = 0.08;   // Spread max autorisé (% du prix)
input int    PurePA_MinBarsBetweenTrades= 3;      // Cooldown en barres M1
input bool   PurePA_UseMultiTF          = true;   // Alignement H4/D1 + H1 bias + M5/M1 exec
input bool   PurePA_RequireM15Level     = true;   // Confluence structurelle M15 obligatoire
input bool   PurePA_RequireKeyLevel     = true;   // Pattern doit être sur S/R ou swing
input bool   PurePA_RequireStructure    = true;   // Exiger structure H1 valide (bias)
input bool   PurePA_RequireM1Confirm    = true;   // Corps M1 aligné + pas de doji
input double PurePA_MinBodyATR          = 0.12;   // Corps M1 min (x ATR M5) si RequireM1Confirm
input double PurePA_MaxExtensionATR     = 0.45;   // Anti-chase : prix trop loin du niveau clé (x ATR)
input bool   PurePA_EnablePartialTP     = true;   // Clôture partielle à 1R
input double PurePA_PartialTP_R         = 1.0;    // Multiplicateur R pour partial
input bool   PurePA_EnableBreakEven     = true;   // Déplacer SL à BE après 1R
input bool   PurePA_EnableTrailing      = true;   // Trailing après 1.5R
input double PurePA_TrailStart_R        = 1.5;
input double PurePA_TrailStep_R         = 0.5;
input bool   PurePA_LogVerbose          = true;   // Logs détaillés
input bool   PurePA_DrawStructure       = true;   // Dessiner swings / BOS / CHoCH
input int    PurePA_DrawSwingLookback   = 40;     // Nombre de barres pour les swings affichés
input int    PurePA_DrawSwingStrength   = 2;      // Force du pivot (barres de chaque côté)
input color  PurePA_ColorSwingHigh      = clrDodgerBlue;   // Couleur Swing High
input color  PurePA_ColorSwingLow       = clrOrange;       // Couleur Swing Low
input color  PurePA_ColorBOS            = clrLime;         // Couleur BOS
input color  PurePA_ColorCHoCH          = clrMagenta;      // Couleur CHoCH
input color  PurePA_ColorBiasBull       = clrLime;         // Zone biais haussier
input color  PurePA_ColorBiasBear       = clrTomato;       // Zone biais baissier
input group "===== PURE PA — MTF / TOUCHE / IMPULSION ====="
input bool   PurePA_WaitM1Touch         = true;   // Armer le niveau M15/OTE, n'entrer que sur touche M1
input bool   PurePA_RequireM5Confirm    = true;   // Entrée M1 uniquement si M5 clôturée dans le sens
input bool   PurePA_RequireM15Confirm   = true;   // Entrée uniquement si M15 confirme la direction
input bool   PurePA_BlockCorrections    = true;   // Interdit d'entrer pendant une correction
input bool   PurePA_RequireImpulse      = true;   // Exige une impulsion franche (pas le chop)
input double PurePA_TouchATR            = 0.28;   // Tolérance touche du niveau armé (x ATR M5)
input int    PurePA_ImpulseMinBars      = 3;      // Bougies M1 consécutives dans le sens
input double PurePA_ScalpProtectUSD     = 1.0;    // Dès 1$ : SL à BE
input double PurePA_ScalpTrailUSD       = 2.0;    // Dès 2$ : trailing pour sécuriser
input group "===== PURE PA — SOURCES DE NIVEAUX + EXÉCUTION ====="
// FIX 2026-09-19 (Sidoine) : Pure PA réutilise les lignes DÉJÀ opérationnelles
// (DOW proj line / SMC_FVG_DISP / GOM_TF_TL M1/M5) au lieu de recalculer ses
// propres swings. Le verdict GOM reste la décision FINALE (PurePA_GOMFinalGate).
// Un SEUL ordre LIMIT est placé au niveau choisi.
input bool   PurePA_UseExistingLevels = true;  // zones DOW/FVG/GOM_TF_TL, entrée seulement après réaction PA
input bool   PurePA_SrcDOWProj        = true;  // source: ligne DOW projetée
input bool   PurePA_SrcGOMTF          = true;  // source: trendlines GOM_TF_TL (M1/M5)
input bool   PurePA_SrcFVG            = true;  // source: FVG display (SMC_DISP_FVG / SMC_DISP_FVG_TRAIL)
input bool   PurePA_SrcPreferDOW      = true;  // préférence: DOW d'abord, sinon GOM_TF_TL puis FVG
input bool   PurePA_UseLimitOrder     = false; // false = MARKET après réaction PA confirmée au niveau
input int    PurePA_LimitExpirySec    = 300;   // durée max des LIMIT Pure PA (minimum 60 s)
input double PurePA_LimitMaxDistATR   = 2.5;   // distance max prix→LIMIT (x ATR M5) — anti-chase ne s'applique qu'au MARKET
input int    PurePA_LevelReactionMaxBars = 3;  // fenêtre de confirmation après la touche M1
input int    PurePA_MaxTickAgeSec       = 10;  // refuser une cotation marché trop ancienne

bool SMC_IsPurePAExclusive()
{
   return (UsePurePriceActionMode && PurePA_ExclusiveEntries);
}

//--- État interne Pure PA
struct PurePA_Swing
{
   datetime time;
   double   price;
   bool     isHigh;      // true = swing high, false = swing low
   bool     broken;      // cassé par un BOS
};

struct PurePA_Structure
{
   int      bias;           // +1 haussier, -1 baissier, 0 neutre
   datetime lastBOSTime;
   int      lastBOSDir;     // +1 ou -1
   datetime lastCHoCHTime;
   int      lastCHoCHDir;
   double   lastSwingHigh;
   double   lastSwingLow;
   bool     valid;
};

struct PurePA_DailyState
{
   double   startEquity;
   double   realizedPnL;
   bool     killSwitch;
   datetime dayStart;
};

PurePA_Structure   g_ppaStruct;
PurePA_DailyState  g_ppaDaily;
datetime           g_ppaLastEntryBar = 0;
ulong              g_ppaManagedTickets[32];
int                g_ppaManagedCount = 0;

// POINT 1 : structure calculée une seule fois par bougie H1 fermée (pas à chaque tick)
datetime           g_ppaLastStructBarTime = 0;

// POINT 3 : dernière confluence M15 détectée, "projetée" sur le graphique M1 pour visualisation
double             g_ppaLastM15Level = 0.0;
int                g_ppaLastM15Dir   = 0;
datetime           g_ppaLastM15Time  = 0;

// Anti-flicker GOM : dernier verdict "tradable" tenu dans le temps
int                g_ppaGomStableVn   = 0;
datetime           g_ppaGomStableSince = 0;

// Niveau M15/OTE armé : le robot ATTEND la touche M1 avant d'envoyer.
double             g_ppaArmedEntry = 0.0;
double             g_ppaArmedSL    = 0.0;
double             g_ppaArmedTP    = 0.0;
int                g_ppaArmedDir   = 0;
datetime           g_ppaArmedSince = 0;
string             g_ppaArmedSrc   = "";
datetime           g_ppaTouchBarTime = 0;
double             g_ppaTouchBarHigh = 0.0;
double             g_ppaTouchBarLow = 0.0;
datetime           g_ppaLastTouchScanBar = 0;

//+------------------------------------------------------------------+
//| 1. ANALYSE DU MARCHÉ — Structure & Swings                        |
//+------------------------------------------------------------------+
int PurePA_FindSwings(const string symbol, const ENUM_TIMEFRAMES tf,
                      PurePA_Swing &swings[], const int lookback = 40,
                      const int strength = 2)
{
   ArrayResize(swings, 0);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, lookback + strength * 2 + 5, rates) < lookback)
      return 0;

   for(int i = strength; i < lookback - strength; i++)
   {
      bool isHigh = true, isLow = true;
      for(int k = 1; k <= strength; k++)
      {
         if(rates[i].high <= rates[i-k].high || rates[i].high <= rates[i+k].high)
            isHigh = false;
         if(rates[i].low  >= rates[i-k].low  || rates[i].low  >= rates[i+k].low)
            isLow = false;
      }
      if(isHigh)
      {
         int n = ArraySize(swings);
         ArrayResize(swings, n + 1);
         swings[n].time   = rates[i].time;
         swings[n].price  = rates[i].high;
         swings[n].isHigh = true;
         swings[n].broken = false;
      }
      else if(isLow)
      {
         int n = ArraySize(swings);
         ArrayResize(swings, n + 1);
         swings[n].time   = rates[i].time;
         swings[n].price  = rates[i].low;
         swings[n].isHigh = false;
         swings[n].broken = false;
      }
   }
   return ArraySize(swings);
}

// BOS = cassure d’un swing dans le sens de la tendance
// CHoCH = cassure d’un swing opposé (changement de caractère)
// Niveaux BOS/CHoCH stockés pour le dessin
double   g_ppaBOSLevel     = 0.0;
datetime g_ppaBOSTime      = 0;
int      g_ppaBOSDir       = 0;
double   g_ppaCHoCHLevel   = 0.0;
datetime g_ppaCHoCHTime    = 0;
int      g_ppaCHoCHDir     = 0;
PurePA_Swing g_ppaLastSwings[64];
int      g_ppaLastSwingCount = 0;

void PurePA_UpdateStructure(const string symbol, const bool forceRecalc = false)
{
   // FIX 2026-09-18 : sur FX Vol / SFX Vol / Step, la structure doit suivre
   // le M15 (setups ICT/SMC), pas seulement la clôture H1 — sinon le robot
   // trade encore un biais haussier héritée pendant un dump déjà visible.
   bool isVol = (StringFind(symbol, "VOL") >= 0 || StringFind(symbol, "Vol") >= 0
                 || StringFind(symbol, "STEP") >= 0 || StringFind(symbol, "SFX") >= 0
                 || StringFind(symbol, "SFV") >= 0);
   ENUM_TIMEFRAMES structTf = isVol ? PERIOD_M15 : PERIOD_H1;
   datetime curStructBar = iTime(symbol, structTf, 0);
   if(!forceRecalc && g_ppaStruct.valid && curStructBar == g_ppaLastStructBarTime)
      return;
   g_ppaLastStructBarTime = curStructBar;

   g_ppaStruct.valid = false;
   PurePA_Swing swings[];
   int n = PurePA_FindSwings(symbol, structTf, swings,
                             PurePA_DrawSwingLookback, PurePA_DrawSwingStrength);
   if(n < 4) return;

   // Stocker pour le dessin
   g_ppaLastSwingCount = MathMin(n, 64);
   for(int i = 0; i < g_ppaLastSwingCount; i++)
      g_ppaLastSwings[i] = swings[i];

   // Derniers swings significatifs (les plus récents)
   double lastHigh = 0, lastLow = 0;
   datetime tHigh = 0, tLow = 0;
   for(int i = 0; i < n; i++)
   {
      if(swings[i].isHigh && (tHigh == 0 || swings[i].time > tHigh))
      { lastHigh = swings[i].price; tHigh = swings[i].time; }
      if(!swings[i].isHigh && (tLow == 0 || swings[i].time > tLow))
      { lastLow = swings[i].price; tLow = swings[i].time; }
   }
   g_ppaStruct.lastSwingHigh = lastHigh;
   g_ppaStruct.lastSwingLow  = lastLow;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(bid <= 0) return;

   // Biais structurel (HH+HL vs LL+LH)
   int bias = 0;
   int hh = 0, hl = 0, ll = 0, lh = 0;
   for(int i = 0; i < n - 1; i++)
   {
      if(swings[i].isHigh && swings[i+1].isHigh)
      {
         if(swings[i].price > swings[i+1].price) hh++;
         else lh++;
      }
      if(!swings[i].isHigh && !swings[i+1].isHigh)
      {
         if(swings[i].price < swings[i+1].price) ll++;
         else hl++;
      }
   }
   if(hh >= 2 && hl >= 1) bias = 1;
   else if(ll >= 2 && lh >= 1) bias = -1;

   // POINT 1 (fix) : BOS/CHoCH sur CLÔTURE H1 CONFIRMÉE, plus sur le bid live.
   // Avant : "bid > lastHigh" à chaque tick pouvait être déclenché par une simple mèche
   // qui dépasse le niveau puis retombe aussitôt — particulièrement risqué sur des
   // synthétiques (PainX/GainX) qui piquent violemment. On utilise désormais la dernière
   // bougie H1 réellement clôturée (index 1 ; l'index 0 est la bougie H1 en cours).
   MqlRates confirmedBar[];
   ArraySetAsSeries(confirmedBar, true);
   ENUM_TIMEFRAMES bosTf = PERIOD_H1;
   if(StringFind(symbol, "VOL") >= 0 || StringFind(symbol, "Vol") >= 0
      || StringFind(symbol, "STEP") >= 0 || StringFind(symbol, "SFX") >= 0
      || StringFind(symbol, "SFV") >= 0)
      bosTf = PERIOD_M15;
   if(CopyRates(symbol, bosTf, 1, 1, confirmedBar) < 1)
   {
      g_ppaStruct.bias  = bias;
      g_ppaStruct.valid = true;
      return;
   }
   double closedClose = confirmedBar[0].close;
   datetime closedTime = confirmedBar[0].time;

   static double s_prevHigh = 0, s_prevLow = 0;
   if(lastHigh > 0 && closedClose > lastHigh && lastHigh != s_prevHigh)
   {
      // Cassure haussière confirmée en clôture
      bool wasBear = (g_ppaStruct.bias < 0 || bias < 0);
      g_ppaBOSLevel   = lastHigh;
      g_ppaBOSTime    = closedTime;
      g_ppaBOSDir     = 1;
      g_ppaStruct.lastBOSTime = g_ppaBOSTime;
      g_ppaStruct.lastBOSDir  = 1;
      bias = 1;

      if(wasBear)
      {
         // CHoCH haussier (changement de caractère)
         g_ppaCHoCHLevel = lastHigh;
         g_ppaCHoCHTime  = closedTime;
         g_ppaCHoCHDir   = 1;
         g_ppaStruct.lastCHoCHTime = g_ppaCHoCHTime;
         g_ppaStruct.lastCHoCHDir  = 1;
      }
      s_prevHigh = lastHigh;
   }
   else if(lastLow > 0 && closedClose < lastLow && lastLow != s_prevLow)
   {
      bool wasBull = (g_ppaStruct.bias > 0 || bias > 0);
      g_ppaBOSLevel   = lastLow;
      g_ppaBOSTime    = closedTime;
      g_ppaBOSDir     = -1;
      g_ppaStruct.lastBOSTime = g_ppaBOSTime;
      g_ppaStruct.lastBOSDir  = -1;
      bias = -1;

      if(wasBull)
      {
         g_ppaCHoCHLevel = lastLow;
         g_ppaCHoCHTime  = closedTime;
         g_ppaCHoCHDir   = -1;
         g_ppaStruct.lastCHoCHTime = g_ppaCHoCHTime;
         g_ppaStruct.lastCHoCHDir  = -1;
      }
      s_prevLow = lastLow;
   }

   g_ppaStruct.bias  = bias;
   g_ppaStruct.valid = true;
}

//+------------------------------------------------------------------+
//| 2. NIVEAUX CLÉS (Support / Résistance récents)                   |
//+------------------------------------------------------------------+
bool PurePA_IsNearKeyLevel(const string symbol, const double price,
                           const double atr, double &levelOut)
{
   levelOut = 0.0;
   if(atr <= 0) return false;
   double tol = atr * 0.35;

   // Swings H1
   PurePA_Swing swings[];
   int n = PurePA_FindSwings(symbol, PERIOD_H1, swings, 30, 2);
   for(int i = 0; i < n; i++)
   {
      if(MathAbs(price - swings[i].price) <= tol)
      {
         levelOut = swings[i].price;
         return true;
      }
   }

   // Extrêmes 20 barres M5
   int lowest  = iLowest(symbol, PERIOD_M5, MODE_LOW,  20, 1);
   int highest = iHighest(symbol, PERIOD_M5, MODE_HIGH, 20, 1);
   if(lowest >= 0)
   {
      double lo = iLow(symbol, PERIOD_M5, lowest);
      if(MathAbs(price - lo) <= tol) { levelOut = lo; return true; }
   }
   if(highest >= 0)
   {
      double hi = iHigh(symbol, PERIOD_M5, highest);
      if(MathAbs(price - hi) <= tol) { levelOut = hi; return true; }
   }
   return false;
}

//+------------------------------------------------------------------+
//| 3. FILTRES CONTEXTUELS                                           |
//+------------------------------------------------------------------+
bool PurePA_SessionOK()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   // Éviter les heures très calmes (dimanche soir / lundi très tôt selon broker)
   // Autoriser principalement London + NY (7h-21h UTC approximatif)
   int hour = dt.hour;
   if(hour >= 0 && hour < 5) return false;   // nuit très calme
   return true;
}

bool PurePA_SpreadOK(const string symbol)
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(bid <= 0 || ask <= bid) return false;

   // FIX (2026-09-14) : comparaison en % du prix, plus en points bruts.
   // Bug identifié via log réel : 25 points calibrés pour du forex 5-digits
   // (EURUSD : 25 pts = 0.00025 = ~0.02% du prix) bloquaient systématiquement
   // BTCUSD/XAUUSD/indices, où le même nombre de points ne représente pas la
   // même réalité de marché (ex : spread de 24$ sur BTC à ~78000$ = 0.03% du
   // prix, un spread SERRÉ, mais valait 2400+ "points" avec point=0.01 →
   // rejeté à tort en boucle sur chaque tick).
   double spreadPct = (ask - bid) / bid * 100.0;
   return (spreadPct <= PurePA_MaxSpreadPercent);
}

bool PurePA_VolatilityOK(const string symbol)
{
   // ATR M5 ne doit pas être nul / aberrant
   int h = iATR(symbol, PERIOD_M5, 14);
   if(h == INVALID_HANDLE) return true;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h, 0, 0, 1, buf) < 1) { IndicatorRelease(h); return true; }
   IndicatorRelease(h);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(bid <= 0) return false;
   // ATR entre 0.02% et 5% du prix (filtre extrême)
   double atrPct = (buf[0] / bid) * 100.0;
   return (atrPct > 0.02 && atrPct < 5.0);
}

bool PurePA_PassesFilters(const string symbol)
{
   if(!PurePA_SessionOK()) {
      if(PurePA_LogVerbose) Print("[PurePA] Filtre session — hors heures favorables");
      return false;
   }
   if(!PurePA_SpreadOK(symbol)) {
      if(PurePA_LogVerbose)
      {
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double pct = (bid > 0) ? (ask - bid) / bid * 100.0 : 0.0;
         Print("[PurePA] Filtre spread trop large — ", DoubleToString(pct, 4),
               "% > ", DoubleToString(PurePA_MaxSpreadPercent, 4), "%");
      }
      return false;
   }
   if(!PurePA_VolatilityOK(symbol)) {
      if(PurePA_LogVerbose) Print("[PurePA] Filtre volatilité anormale");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| 4. GESTION DU RISQUE & KILL-SWITCH                               |
//+------------------------------------------------------------------+
void PurePA_UpdateDailyState()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));

   if(g_ppaDaily.dayStart != today)
   {
      g_ppaDaily.dayStart    = today;
      g_ppaDaily.startEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_ppaDaily.realizedPnL = 0.0;
      g_ppaDaily.killSwitch  = false;
      if(PurePA_LogVerbose)
         Print("[PurePA] Nouveau jour — equity de référence = ",
               DoubleToString(g_ppaDaily.startEquity, 2));
   }

   // PnL réalisé du jour (approximatif via positions fermées Magic)
   // On utilise aussi l’equity actuelle pour le kill-switch
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct = 0.0;
   if(g_ppaDaily.startEquity > 0)
      ddPct = ((g_ppaDaily.startEquity - equity) / g_ppaDaily.startEquity) * 100.0;

   if(ddPct >= PurePA_MaxDailyLossPct)
   {
      if(!g_ppaDaily.killSwitch)
      {
         g_ppaDaily.killSwitch = true;
         Print("🛑 [PurePA] KILL-SWITCH JOURNALIER activé — drawdown ",
               DoubleToString(ddPct, 2), "% ≥ ", PurePA_MaxDailyLossPct, "%");
      }
   }
}

bool PurePA_RiskLimitReached()
{
   PurePA_UpdateDailyState();
   return g_ppaDaily.killSwitch;
}

int PurePA_VolumeDigits(const double volumeStep)
{
   for(int digits = 0; digits <= 8; digits++)
   {
      if(MathAbs(volumeStep - NormalizeDouble(volumeStep, digits)) < 1e-9)
         return digits;
   }
   return 8;
}

double PurePA_CalculateLot(const string symbol, const int dirSign,
                           const double entryPrice, const double stopLoss)
{
   if(dirSign == 0 || entryPrice <= 0.0 || stopLoss <= 0.0)
      return 0.0;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0 || PurePA_RiskPercent <= 0.0)
      return 0.0;
   double riskMoney = equity * (PurePA_RiskPercent / 100.0);

   double profitAtStop = 0.0;
   ENUM_ORDER_TYPE orderType = (dirSign > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(orderType, symbol, 1.0, entryPrice, stopLoss, profitAtStop) ||
      profitAtStop >= 0.0)
      return 0.0;

   double riskPerLot = MathAbs(profitAtStop);
   if(riskPerLot <= 0.0) return 0.0;
   double rawLot = riskMoney / riskPerLot;

   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(minLot <= 0.0 || maxLot < minLot || step <= 0.0)
      return 0.0;

   double lot = MathFloor(MathMin(rawLot, maxLot) / step + 1e-9) * step;
   int volumeDigits = PurePA_VolumeDigits(step);
   lot = NormalizeDouble(lot, volumeDigits);
   if(lot < minLot || lot <= 0.0)
      return 0.0;

   if(riskPerLot * lot > riskMoney + MathMax(0.01, riskMoney * 0.000001))
      return 0.0;
   return lot;
}

//+------------------------------------------------------------------+
//| 5. GATE GOM FINAL (dernière validation) — version stabilisée     |
//| Anti-flicker : un GOOD/PERFECT qui bascule WAIT en < N sec       |
//| (cas typique FX Vol / SFX Vol dans les logs du 2026-09-14) ne    |
//| doit PAS autoriser d'entrée.                                     |
//+------------------------------------------------------------------+
void PurePA_UpdateGomStability()
{
   int vn = g_smcGomConnected ? g_smcGomVerdictNum : 0;
   bool tradable = (vn != 0 && vn != -999);
   if(!PurePA_AllowSimpleGOM)
      tradable = tradable && SMCGP_IsGoodPerfect(vn);

   if(!tradable)
   {
      g_ppaGomStableVn = 0;
      g_ppaGomStableSince = 0;
      return;
   }

   // Même signe / même "qualité tradable" → on prolonge
   if(g_ppaGomStableVn != 0 &&
      ((g_ppaGomStableVn > 0 && vn > 0) || (g_ppaGomStableVn < 0 && vn < 0)))
   {
      // upgrade SIMPLE→GOOD ou GOOD→PERFECT : on garde le chrono
      g_ppaGomStableVn = vn;
      return;
   }

   // Nouveau verdict tradable (démarrage ou retournement)
   g_ppaGomStableVn = vn;
   g_ppaGomStableSince = TimeCurrent();
}

bool PurePA_GOMFinalGate(const int dirSign)
{
   if(!PurePA_RequireGOMFinalGate) return true;   // mode pure PA sans GOM

   PurePA_UpdateGomStability();

   if(!g_smcGomConnected)
   {
      if(PurePA_LogVerbose) Print("[PurePA] GOM déconnecté → BLOQUE");
      return false;
   }

   int vn = g_smcGomVerdictNum;
   if(vn == 0 || vn == -999)
   {
      if(PurePA_LogVerbose) Print("[PurePA] GOM = WAIT → BLOQUE (condition défavorable)");
      return false;
   }

   // Direction opposée
   if((dirSign > 0 && vn < 0) || (dirSign < 0 && vn > 0))
   {
      if(PurePA_LogVerbose)
         Print("[PurePA] GOM direction opposée (vn=", vn, ") → BLOQUE");
      return false;
   }

   // Exiger GOOD/PERFECT si demandé
   if(!PurePA_AllowSimpleGOM)
   {
      if(!SMCGP_IsGoodPerfect(vn))
      {
         if(PurePA_LogVerbose)
            Print("[PurePA] GOM = SIMPLE (vn=", vn, ") — GOOD/PERFECT requis → BLOQUE");
         return false;
      }
   }

   // Cohérence mini (si disponible côté pipeline)
   if(PurePA_MinCoherencePct > 0.0 && g_smcGomCoherence > 0.0 &&
      g_smcGomCoherence < PurePA_MinCoherencePct)
   {
      if(PurePA_LogVerbose)
         Print("[PurePA] Cohérence GOM ", DoubleToString(g_smcGomCoherence, 0),
               "% < min ", DoubleToString(PurePA_MinCoherencePct, 0), "% → BLOQUE");
      return false;
   }

   // Anti-flicker : verdict tradable doit tenir PurePA_GOMMinSustainSec
   if(PurePA_GOMMinSustainSec > 0)
   {
      if(g_ppaGomStableSince <= 0 ||
         (int)(TimeCurrent() - g_ppaGomStableSince) < PurePA_GOMMinSustainSec)
      {
         if(PurePA_LogVerbose)
            Print("[PurePA] GOM trop récent (",
                  (g_ppaGomStableSince > 0 ? (int)(TimeCurrent() - g_ppaGomStableSince) : 0),
                  "s < ", PurePA_GOMMinSustainSec, "s) → attendre stabilité");
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| POINT 2 : alignement H4/D1 via le TF Gate EXISTANT de l'EA       |
//| (g_smcTfH4Dir/g_smcTfD1Dir, déjà calculés ailleurs — on ne les   |
//| recalcule pas indépendamment dans PurePA pour éviter d'avoir     |
//| deux "cerveaux" qui peuvent se contredire sur le même symbole)   |
//+------------------------------------------------------------------+
int PurePA_DirFromTfString(const string tfDir)
{
   if(tfDir == "BULL") return 1;
   if(tfDir == "BEAR") return -1;
   return 0;
}

bool PurePA_HigherTFAligned(const int dir)
{
   if(!PurePA_UseMultiTF) return true;

   int d1  = PurePA_DirFromTfString(g_smcTfD1Dir);
   int h4  = PurePA_DirFromTfString(g_smcTfH4Dir);
   int h1  = PurePA_DirFromTfString(g_smcTfH1Dir);
   int m15 = PurePA_DirFromTfString(g_smcTfM15Dir);

   // D1/H4 définissent le contexte ; les TF intraday neutres sont tolérés,
   // mais une structure H1/M15 opposée invalide le setup.
   if(d1 != dir || h4 != dir) return false;
   if(h1 != 0 && h1 != dir) return false;
   if(m15 != 0 && m15 != dir) return false;
   return true;
}

bool PurePA_ConfirmsGOMDirection(const string symbol, const int dir)
{
   if(dir == 0) return false;
   PurePA_UpdateStructure(symbol);
   if(!g_ppaStruct.valid || g_ppaStruct.bias != dir || !PurePA_HigherTFAligned(dir))
   {
      static datetime s_ppaConfLog = 0;
      if(PurePA_LogVerbose && TimeCurrent() - s_ppaConfLog >= 20)
      {
         s_ppaConfLog = TimeCurrent();
         PrintFormat("PPA↔GOM: refus (%s) — bias PPA=%d valid=%d vs GOM dir=%d",
                     symbol, g_ppaStruct.bias, (int)g_ppaStruct.valid, dir);
      }
      return false;
   }
   return true;
}

bool PurePA_M1ImpulseOK(const string symbol, const int dir)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 8, r) < 6) return false;
   int consec = 0;
   for(int i = 1; i <= 5; i++)
   {
      bool bull = (r[i].close > r[i].open);
      bool bear = (r[i].close < r[i].open);
      if(dir > 0 && bull) consec++;
      else if(dir < 0 && bear) consec++;
      else break;
   }
   double move = r[1].close - r[4].close;
   if(dir > 0) return (consec >= PurePA_ImpulseMinBars && move > 0);
   return (consec >= PurePA_ImpulseMinBars && move < 0);
}

bool PurePA_PriceTouchesLevel(const string symbol, const int dir, const double level, const double atr)
{
   if(level <= 0.0 || atr <= 0.0) return false;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double px  = (dir > 0) ? ask : bid;
   double tol = atr * MathMax(0.08, PurePA_TouchATR);
   if(MathAbs(px - level) <= tol) return true;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 3, r) < 2) return false;
   // Touche par mèche M1 (bougie en cours ou précédente)
   for(int i = 0; i < 2; i++)
   {
      if(r[i].low <= level + tol && r[i].high >= level - tol)
         return true;
   }
   return false;
}

bool PurePA_GetArmedLevel(const string symbol, const int dir, const double atr, double &levelOut, string &srcOut)
{
   levelOut = 0.0;
   srcOut = "";
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

   // 0) Niveau calculé serveur (D1→M1 + OTE/OB) si le sens correspond
   if(g_smcPaEntry > 0.0)
   {
      bool dirOk = (dir > 0 && (g_smcPaDir == "BUY" || g_smcPaDir == "BULL")) ||
                   (dir < 0 && (g_smcPaDir == "SELL" || g_smcPaDir == "BEAR"));
      if(dirOk || g_smcPaDir == "" || g_smcPaDir == "NEUT")
      {
         levelOut = g_smcPaEntry;
         srcOut = (g_smcPaSrc != "" ? g_smcPaSrc : "SERVER_PA");
         return true;
      }
   }

   // 1) Zone OTE 61.8–78.6 si le serveur l'a calculée dans le bon sens
   if(g_smcOteTop > 0.0 && g_smcOteBot > 0.0 &&
      (g_smcOteDir == 0 || (dir > 0 && g_smcOteDir > 0) || (dir < 0 && g_smcOteDir < 0)))
   {
      double lo = MathMin(g_smcOteTop, g_smcOteBot);
      double hi = MathMax(g_smcOteTop, g_smcOteBot);
      if(hi > lo)
      {
         levelOut = (lo + hi) * 0.5;
         srcOut = "OTE";
         // Si le prix est déjà dans la zone, c'est le niveau courant
         if(bid >= lo && bid <= hi)
            levelOut = bid;
         return true;
      }
   }

   // 2) Swing M15 (demande pour BUY, offre pour SELL) — le plus proche sous/sur le prix
   PurePA_Swing sw[];
   int n = PurePA_FindSwings(symbol, PERIOD_M15, sw, 40, 2);
   double best = 0.0;
   double bestDist = 0.0;
   for(int i = 0; i < n; i++)
   {
      if(dir > 0 && sw[i].isHigh) continue;
      if(dir < 0 && !sw[i].isHigh) continue;
      if(dir > 0 && sw[i].price > bid) continue; // demande sous le marché
      if(dir < 0 && sw[i].price < bid) continue; // offre au-dessus
      double dist = MathAbs(bid - sw[i].price);
      if(best <= 0.0 || dist < bestDist)
      {
         best = sw[i].price;
         bestDist = dist;
      }
   }
   if(best > 0.0)
   {
      levelOut = best;
      srcOut = "M15_SWING";
      g_ppaLastM15Level = best;
      g_ppaLastM15Dir = dir;
      g_ppaLastM15Time = TimeCurrent();
      return true;
   }

   // 3) Order block GOM
   if(dir > 0 && g_smcObBullBot > 0.0 && g_smcObBullTop > 0.0)
   {
      levelOut = (g_smcObBullBot + g_smcObBullTop) * 0.5;
      srcOut = "OB_BULL";
      return true;
   }
   if(dir < 0 && g_smcObBearBot > 0.0 && g_smcObBearTop > 0.0)
   {
      levelOut = (g_smcObBearBot + g_smcObBearTop) * 0.5;
      srcOut = "OB_BEAR";
      return true;
   }

   // 4) Retest BOS/CHoCH
   if(dir > 0 && g_ppaBOSDir > 0 && g_ppaBOSLevel > 0.0)
   {
      levelOut = g_ppaBOSLevel;
      srcOut = "BOS";
      return true;
   }
   if(dir < 0 && g_ppaBOSDir < 0 && g_ppaBOSLevel > 0.0)
   {
      levelOut = g_ppaBOSLevel;
      srcOut = "BOS";
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| POINT 3 : confluence structurelle M15 — DÉTECTION M15, projetée  |
//| ("rendue visible") sur M1. On ne relance PAS un algo de détection|
//| de figures directement sur M1 (bruit trop élevé → faux signaux); |
//| M15 sert de TF structurelle fiable, M1 ne sert qu'au timing.     |
//+------------------------------------------------------------------+
bool PurePA_M15LevelConfluence(const string symbol, const int dir, const double price,
                               const double atr, double &m15LevelOut)
{
   m15LevelOut = 0.0;
   if(atr <= 0) return false;
   double tol = atr * 0.5; // tolérance plus large qu'H1 : M15 = zone de confluence, pas point exact

   PurePA_Swing sw[];
   int n = PurePA_FindSwings(symbol, PERIOD_M15, sw, 40, 2);
   for(int i = 0; i < n; i++)
   {
      // BUY → on cherche un swing low M15 (zone de demande) ; SELL → swing high M15 (offre)
      if(dir > 0 && sw[i].isHigh) continue;
      if(dir < 0 && !sw[i].isHigh) continue;

      if(MathAbs(price - sw[i].price) <= tol)
      {
         m15LevelOut = sw[i].price;
         // Mémorisé pour être dessiné/projeté sur le graphique M1 (PurePA_DrawM15Level)
         g_ppaLastM15Level = sw[i].price;
         g_ppaLastM15Dir   = dir;
         g_ppaLastM15Time  = TimeCurrent();
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| 6. SIGNAL D’ENTRÉE PURE PA                                       |
//+------------------------------------------------------------------+
struct PurePA_Signal
{
   bool     valid;
   int      dirSign;       // +1 BUY / -1 SELL
   string   patternName;
   double   entryPrice;
   double   stopLoss;
   double   takeProfit;
   double   keyLevel;
   double   m15Level;    // POINT 3 : niveau de confluence M15 utilisé pour le timing M1
   string   reason;
};

//+------------------------------------------------------------------+
//| 6b. SOURCES DE NIVEAUX EXISTANTS (DOW proj / FVG / GOM_TF_TL)    |
//|      + verdict GOM comme décision finale + UN ordre LIMIT         |
//+------------------------------------------------------------------+
enum PurePA_LevelSource
{
   PPASRC_NONE  = 0,
   PPASRC_DOW   = 1,
   PPASRC_GOMTF = 2,
   PPASRC_FVG   = 3
};

// Nombre d'ordres LIMIT "PURE_PA" en attente sur ce symbole
int PurePA_CountPendingLimits(const string symbol)
{
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if(StringFind(OrderGetString(ORDER_COMMENT), "PURE_PA") < 0) continue;
      n++;
   }
   return n;
}

// Plus haut niveau valide pour la direction demandée, parmi les 3 sources.
// L'ordre est un retracement : BUY → niveau SOUS le marché, SELL → niveau AU-DESSUS.
bool PurePA_GetLevelForDirection(const string symbol, const int dir,
                                 const double atr, double &levelOut, string &srcOut)
{
   levelOut = 0.0;
   srcOut = "";
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double lvl = 0.0;
   string tag = "";
   double candidateLevels[3];
   string candidateSources[3];
   int candidateCount = 0;

   int seq[3];
   if(PurePA_SrcPreferDOW)
      { seq[0] = PPASRC_DOW;   seq[1] = PPASRC_GOMTF; seq[2] = PPASRC_FVG; }
   else
      { seq[0] = PPASRC_GOMTF; seq[1] = PPASRC_FVG;   seq[2] = PPASRC_DOW; }

   for(int s = 0; s < 3; s++)
   {
      int src = seq[s];
      lvl = 0.0; tag = "";

      if(src == PPASRC_DOW)
      {
         if(!PurePA_SrcDOWProj) continue;
         string epToken = (dir > 0) ? "DOW_BULL_EP" : "DOW_BEAR_EP";
         double epLvl = 0.0;
         if(SMC_FindReactionObjectLevel(symbol, epToken, epLvl) && epLvl > 0.0)
         {
            lvl = epLvl;
            tag = epToken;
         }
         else
         {
            bool bearish = false;
            double dowLvl = 0.0;
            if(!SMC_FindDOWProjectedLevel(dowLvl, bearish)) continue;
            if((dir > 0 && bearish) || (dir < 0 && !bearish)) continue;
            lvl = dowLvl;
            tag = "DOW_PROJ";
         }
      }
      else if(src == PPASRC_GOMTF)
      {
         if(!PurePA_SrcGOMTF) continue;
         double m1 = 0.0, m5 = 0.0;
         SMC_FindReactionObjectLevel(symbol, "GOM_TF_TL_M1", m1);
         SMC_FindReactionObjectLevel(symbol, "GOM_TF_TL_M5", m5);
         if(m1 <= 0.0 && m5 <= 0.0)
         {
            SMC_FindReactionObjectLevel(symbol, "TF_TL_M1", m1);
            SMC_FindReactionObjectLevel(symbol, "TF_TL_M5", m5);
         }
         if(m1 <= 0.0 && m5 <= 0.0) continue;
         double refPx = (dir > 0) ? ask : bid;
         double d1 = (m1 > 0.0) ? MathAbs(refPx - m1) : 1e+200;
         double d5 = (m5 > 0.0) ? MathAbs(refPx - m5) : 1e+200;
         if(d1 <= d5) { lvl = m1; tag = "GOM_TF_TL_M1"; }
         else         { lvl = m5; tag = "GOM_TF_TL_M5"; }
      }
      else // PPASRC_FVG
      {
         if(!PurePA_SrcFVG) continue;
         double trail = 0.0, fvg = 0.0;
         string trailTok = (dir > 0) ? "SMC_DISP_FVG_TRAIL_Bull" : "SMC_DISP_FVG_TRAIL_Bear";
         string boxTok   = (dir > 0) ? "SMC_DISP_FVG_Bull" : "SMC_DISP_FVG_Bear";
         string aliasTok = (dir > 0) ? "SMC_FVG_DISP_Bull" : "SMC_FVG_DISP_Bear";
         SMC_FindReactionObjectLevel(symbol, trailTok, trail);
         if(trail <= 0.0)
            SMC_FindReactionObjectLevel(symbol, boxTok, fvg);
         if(fvg <= 0.0)
            SMC_FindReactionObjectLevel(symbol, aliasTok, fvg);
         if(trail > 0.0)     { lvl = trail; tag = "SMC_FVG_DISP"; }
         else if(fvg > 0.0)  { lvl = fvg;   tag = "SMC_FVG_DISP"; }
         else continue;
      }

      if(lvl <= 0.0) continue;

      // Côté du retracement : BUY LIMIT → niveau au-dessous du marché,
      // SELL LIMIT → niveau au-dessus. Sinon refuser cette source.
      if(dir > 0 && lvl > ask) continue;
      if(dir < 0 && lvl < bid) continue;

      double refPx = (dir > 0) ? ask : bid;
      double distance = MathAbs(refPx - lvl);
      if(PurePA_LimitMaxDistATR > 0.0 &&
         distance > atr * PurePA_LimitMaxDistATR)
         continue;
      candidateLevels[candidateCount] = lvl;
      candidateSources[candidateCount] = tag;
      candidateCount++;
   }
   if(candidateCount <= 0)
      return false;

   int bestIndex = -1;
   int bestConfluence = 0;
   double bestDistance = 1e+100;
   double refPx = (dir > 0) ? ask : bid;
   for(int i = 0; i < candidateCount; i++)
   {
      int confluence = 1;
      for(int j = 0; j < candidateCount; j++)
      {
         if(i != j && MathAbs(candidateLevels[i] - candidateLevels[j]) <= atr * 0.20)
            confluence++;
      }

      double distance = MathAbs(refPx - candidateLevels[i]);
      if(confluence > bestConfluence ||
         (confluence == bestConfluence && distance < bestDistance))
      {
         bestIndex = i;
         bestConfluence = confluence;
         bestDistance = distance;
      }
   }
   if(bestIndex < 0 || candidateLevels[bestIndex] <= 0.0)
      return false;

   levelOut = candidateLevels[bestIndex];
   srcOut = candidateSources[bestIndex];
   if(bestConfluence > 1)
      srcOut += StringFormat("+CONFLUENCE%d", bestConfluence);
   return true;
}

bool PurePA_HasClosedTFConfirmation(const string symbol, const ENUM_TIMEFRAMES tf,
                                   const int dir)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 3, rates) < 3)
      return false;

   if(dir > 0)
      return (rates[1].close > rates[1].open &&
              rates[1].close > rates[2].close);
   if(dir < 0)
      return (rates[1].close < rates[1].open &&
              rates[1].close < rates[2].close);
   return false;
}

void PurePA_ResetLevelReaction()
{
   g_ppaTouchBarTime = 0;
   g_ppaTouchBarHigh = 0.0;
   g_ppaTouchBarLow = 0.0;
   g_ppaLastTouchScanBar = 0;
}

bool PurePA_ConfirmLevelReaction(const string symbol, const int dir,
                                 const double level, const double atr,
                                 MqlRates &confirmationBar)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 4, rates) < 4)
      return false;

   MqlRates touchBar = rates[1];
   confirmationBar = touchBar;
   int barSeconds = PeriodSeconds(PERIOD_M1);
   if(barSeconds <= 0 || TimeCurrent() - touchBar.time > barSeconds * 2)
      return false;

   double tolerance = atr * MathMax(0.08, PurePA_TouchATR);
   bool intersectsLevelZone =
      (touchBar.low <= level + tolerance && touchBar.high >= level - tolerance);
   if(touchBar.time != g_ppaLastTouchScanBar)
   {
      g_ppaLastTouchScanBar = touchBar.time;
      if(intersectsLevelZone)
      {
         g_ppaTouchBarTime = touchBar.time;
         g_ppaTouchBarHigh = touchBar.high;
         g_ppaTouchBarLow = touchBar.low;
      }
   }

   if(g_ppaTouchBarTime <= 0)
      return false;

   int barsAfterTouch = (int)((touchBar.time - g_ppaTouchBarTime) / barSeconds);
   if(barsAfterTouch < 0 || barsAfterTouch > MathMax(1, PurePA_LevelReactionMaxBars))
   {
      PurePA_ResetLevelReaction();
      return false;
   }

   double invalidationBuffer = atr * 0.05;
   if((dir > 0 && touchBar.close < level - invalidationBuffer) ||
      (dir < 0 && touchBar.close > level + invalidationBuffer))
   {
      PurePA_ResetLevelReaction();
      return false;
   }

   double body = MathAbs(touchBar.close - touchBar.open);
   double minimumBody = (PurePA_RequireM1Confirm || PurePA_RequireImpulse)
      ? atr * PurePA_MinBodyATR : atr * 0.05;
   bool directionalClose = (dir > 0)
      ? (touchBar.close > touchBar.open && touchBar.close > level)
      : (touchBar.close < touchBar.open && touchBar.close < level);

   bool confirmed = (g_ppaTouchBarTime == touchBar.time &&
                     directionalClose && body >= minimumBody);
   if(!confirmed && g_ppaTouchBarTime < touchBar.time)
   {
      bool followThrough = (dir > 0)
         ? (touchBar.close > g_ppaTouchBarHigh && touchBar.close > touchBar.open)
         : (touchBar.close < g_ppaTouchBarLow && touchBar.close < touchBar.open);
      confirmed = (followThrough && body >= minimumBody);
   }
   if(confirmed)
      confirmationBar = touchBar;
   return confirmed;
}

void PurePA_LogLevelWait(const string symbol, const string reason)
{
   if(!PurePA_LogVerbose)
      return;

   static datetime lastLogTime = 0;
   static string lastReason = "";
   datetime now = TimeCurrent();
   if(reason == lastReason && now - lastLogTime < 20)
      return;
   if(now - lastLogTime < 3)
      return;

   lastLogTime = now;
   lastReason = reason;
   Print("[PurePA] ", symbol, " — ", reason);
}

// Bâtit un signal à partir des niveaux existants, dans la direction du
// verdict GOM (GOOD/PERFECT). Le gate GOM final revalide ensuite dans
// PurePA_ExecuteEntry.
bool PurePA_BuildSignalFromLevels(const string symbol, PurePA_Signal &sig)
{
   // GOM = décision principale : on ne construit que dans le sens GOOD/PERFECT.
   if(!g_smcGomConnected)
   {
      PurePA_LogLevelWait(symbol, "GOM déconnecté");
      return false;
   }
   int gvn = g_smcGomVerdictNum;
   if(MathAbs(gvn) < 2)
   {
      PurePA_LogLevelWait(symbol, "GOM SIMPLE/WAIT : GOOD ou PERFECT requis");
      return false;
   }
   int dir = (gvn > 0) ? 1 : -1;
   if(!PurePA_HigherTFAligned(dir))
   {
      PurePA_LogLevelWait(symbol, "D1/H4 ou structure H1/M15 non alignés");
      return false;
   }

   double atr = 0.0;
   int hAtr = iATR(symbol, PERIOD_M5, 14);
   if(hAtr != INVALID_HANDLE)
   {
      double ab[];
      ArraySetAsSeries(ab, true);
      if(CopyBuffer(hAtr, 0, 0, 1, ab) >= 1) atr = ab[0];
      IndicatorRelease(hAtr);
   }
   if(atr <= 0.0)
   {
      PurePA_LogLevelWait(symbol, "ATR M5 indisponible");
      return false;
   }

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick) || tick.time <= 0 ||
      TimeCurrent() - tick.time > MathMax(1, PurePA_MaxTickAgeSec) ||
      tick.bid <= 0.0 || tick.ask <= tick.bid)
   {
      PurePA_LogLevelWait(symbol, "cotations absentes, invalides ou trop anciennes");
      return false;
   }

   double level = 0.0;
   string src = "";
   if(!PurePA_GetLevelForDirection(symbol, dir, atr, level, src))
   {
      PurePA_LogLevelWait(symbol, "aucun niveau DOW/GOM/FVG valide et proche");
      return false;
   }

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   bool sameSetup = (g_ppaArmedDir == dir && g_ppaArmedSrc == src &&
                     MathAbs(g_ppaArmedEntry - level) <= MathMax(point, atr * 0.02));
   if(!sameSetup)
   {
      PurePA_ResetLevelReaction();
      g_ppaArmedSince = TimeCurrent();
   }
   else if(g_ppaArmedSince > 0 && TimeCurrent() - g_ppaArmedSince > 600)
   {
      PurePA_ResetLevelReaction();
      g_ppaArmedSince = TimeCurrent();
      g_ppaLastTouchScanBar = iTime(symbol, PERIOD_M1, 1);
      return false;
   }
   g_ppaArmedEntry = level;
   g_ppaArmedDir = dir;
   g_ppaArmedSrc = src;

   MqlRates reaction;
   if(!PurePA_ConfirmLevelReaction(symbol, dir, level, atr, reaction))
   {
      PurePA_LogLevelWait(symbol, "niveau armé : attente touche puis clôture M1 de réaction");
      return false;
   }

   if(PurePA_RequireM5Confirm &&
      !PurePA_HasClosedTFConfirmation(symbol, PERIOD_M5, dir))
   {
      PurePA_LogLevelWait(symbol, "réaction M1 confirmée : attente clôture M5 directionnelle");
      return false;
   }
   if(PurePA_RequireM15Confirm &&
      !SMC_HasM15Confirmation(symbol, dir))
   {
      PurePA_LogLevelWait(symbol, "réaction M1 confirmée : attente confirmation M15");
      return false;
   }
   if(PurePA_BlockCorrections && SMC_IsCorrectionZoneForDirection(symbol, dir))
   {
      PurePA_LogLevelWait(symbol, "entrée bloquée : correction en cours");
      return false;
   }

   double refPx = (dir > 0) ? tick.ask : tick.bid;
   double distAtr = MathAbs(refPx - level) / atr;
   double maxDistance = PurePA_UseLimitOrder
      ? PurePA_LimitMaxDistATR : PurePA_MaxExtensionATR;
   if(maxDistance > 0.0 && distAtr > maxDistance)
   {
      PurePA_LogLevelWait(symbol, "entrée bloquée : prix trop étendu depuis le niveau");
      return false;
   }

   double buffer = atr * 0.15;
   double sl = 0.0;
   if(dir > 0)
      sl = MathMin(reaction.low, g_ppaTouchBarLow) - buffer;
   else
      sl = MathMax(reaction.high, g_ppaTouchBarHigh) + buffer;

   double entryPrice = PurePA_UseLimitOrder ? level : refPx;
   double risk = (dir > 0) ? entryPrice - sl : sl - entryPrice;
   if(risk <= 0.0 || PurePA_MinRR <= 0.0)
      return false;
   double tp = (dir > 0)
      ? entryPrice + risk * PurePA_MinRR
      : entryPrice - risk * PurePA_MinRR;

   // Respect des stops level broker
   long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stopsLevel * point;
   if(minDist <= 0) minDist = 5 * point;
   if(MathAbs(entryPrice - sl) < minDist)
      return false;

   int dg = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   sig.valid       = true;
   sig.dirSign     = dir;
   sig.patternName = src;
   sig.entryPrice  = NormalizeDouble(entryPrice, dg);
   sig.stopLoss    = NormalizeDouble(sl, dg);
   sig.takeProfit  = NormalizeDouble(tp, dg);
   sig.keyLevel    = level;
   sig.m15Level    = level;
   sig.reason      = StringFormat("PA %s %s=%s reaction=M1 close-confirm | GOM vn=%d | %s",
                                  (dir > 0 ? "BUY" : "SELL"), src,
                                  DoubleToString(level, dg), gvn,
                                  (PurePA_UseLimitOrder ? "LIMIT" : "MARKET"));
   return true;
}

bool PurePA_BuildSignal(const string symbol, PurePA_Signal &sig)
{
   sig.valid = false;
   sig.dirSign = 0;
   sig.patternName = "";
   sig.entryPrice = 0;
   sig.stopLoss = 0;
   sig.takeProfit = 0;
   sig.keyLevel = 0;
   sig.m15Level = 0;
   sig.reason = "";

   // 1. Filtres contextuels
   if(!PurePA_PassesFilters(symbol)) return false;

   // FIX 2026-09-19 (Sidoine) : mode "niveaux existants" —
   // DOW proj line / SMC_FVG_DISP / GOM_TF_TL M1/M5 + verdict GOM final.
   if(PurePA_UseExistingLevels)
      return PurePA_BuildSignalFromLevels(symbol, sig);

   // 2. Structure multi-TF
   PurePA_UpdateStructure(symbol);
   if(PurePA_RequireStructure && !g_ppaStruct.valid)
   {
      if(PurePA_LogVerbose) Print("[PurePA] Structure non valide");
      return false;
   }

   // 3. Patterns M15/M5/M1 (chandeliers + SMC) — optionnels si OTE/BOS/OB
   if(UsePatternEntrySignals)
      SMCPS_EnsureScanned(symbol);

   int dirCandidates[2] = {1, -1};
   for(int d = 0; d < 2; d++)
   {
      int dir = dirCandidates[d];

      // Alignement structure H1 (propre à PurePA)
      if(PurePA_UseMultiTF && g_ppaStruct.valid && g_ppaStruct.bias != 0)
      {
         if(dir != g_ppaStruct.bias) continue;   // contre-tendance H1 refusée
      }

      // Pile Daily → M15
      if(!PurePA_HigherTFAligned(dir)) continue;

      // Breakout confirmation (si activé dans le module patterns)
      if(UsePatternEntrySignals && PatternRequireBreakout && !SMCPS_BreakoutConfirmed(symbol, dir))
         continue;

      // Niveau clé
      double atr = 0.0;
      int hAtr = iATR(symbol, PERIOD_M5, 14);
      if(hAtr != INVALID_HANDLE)
      {
         double ab[];
         ArraySetAsSeries(ab, true);
         if(CopyBuffer(hAtr, 0, 0, 1, ab) >= 1) atr = ab[0];
         IndicatorRelease(hAtr);
      }
      if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 50.0;

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double px  = (dir > 0) ? ask : bid;

      // Setup SMC / price action : pattern OU OTE OU BOS/OB
      bool hasPattern = SMCPS_HasPatternForDirection(dir);
      if(!hasPattern)
      {
         if(PatternRequireM1orM5 && !SMCPS_HasShortTFPattern(dir))
         {
            bool oteOk = (g_smcOteTop > 0.0 && g_smcOteBot > 0.0 &&
                          (g_smcOteDir == 0 || (dir > 0 && g_smcOteDir > 0) || (dir < 0 && g_smcOteDir < 0)));
            bool bosOk = (g_ppaBOSDir == dir);
            if(!oteOk && !bosOk) continue;
         }
      }

      double armedLvl = 0.0;
      string armedSrc = "";
      if(!PurePA_GetArmedLevel(symbol, dir, atr, armedLvl, armedSrc))
      {
         double keyLvlTmp = 0.0;
         if(!PurePA_IsNearKeyLevel(symbol, px, atr, keyLvlTmp))
            continue;
         armedLvl = keyLvlTmp;
         armedSrc = "KEY";
      }

      g_ppaArmedEntry = armedLvl;
      g_ppaArmedDir   = dir;
      g_ppaArmedSrc   = armedSrc;
      if(g_ppaArmedSince <= 0) g_ppaArmedSince = TimeCurrent();

      // Attendre que M1 TOUCHE le niveau (OTE / swing M15 / OB) — ne pas chasser
      if(PurePA_WaitM1Touch && !PurePA_PriceTouchesLevel(symbol, dir, armedLvl, atr))
      {
         static datetime s_waitTouch = 0;
         if(PurePA_LogVerbose && TimeCurrent() - s_waitTouch >= 20)
         {
            s_waitTouch = TimeCurrent();
            Print("[PurePA] WAIT TOUCH M1 ", (dir > 0 ? "BUY" : "SELL"),
                  " | src=", armedSrc, " lvl=", DoubleToString(armedLvl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                  " px=", DoubleToString(px, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
         }
         continue;
      }

      // Confirmation timeframe supérieur : M1 → M5 (et M15 si on exécute depuis M5)
      if(PurePA_RequireM5Confirm && !SMC_HasM5Confirmation(symbol, dir))
      {
         static datetime s_waitM5 = 0;
         if(PurePA_LogVerbose && TimeCurrent() - s_waitM5 >= 20)
         {
            s_waitM5 = TimeCurrent();
            Print("[PurePA] WAIT M5 CONFIRM ", (dir > 0 ? "BUY" : "SELL"), " | ", symbol);
         }
         continue;
      }
      if(PurePA_RequireM15Confirm && !SMC_HasM15Confirmation(symbol, dir))
         continue;

      // Pas d'entrée en correction — seulement impulsion franche
      if(PurePA_BlockCorrections && SMC_IsCorrectionZoneForDirection(symbol, dir))
      {
         if(PurePA_LogVerbose)
            Print("[PurePA] BLOQUE correction ", symbol, " ", (dir > 0 ? "BUY" : "SELL"));
         continue;
      }
      if(PurePA_RequireImpulse)
      {
         bool impulse = HasStrongImpulse(symbol) || PurePA_M1ImpulseOK(symbol, dir);
         if(!impulse)
         {
            if(PurePA_LogVerbose)
               Print("[PurePA] WAIT impulsion franche ", symbol);
            continue;
         }
      }

      double keyLvl = 0.0;
      PurePA_IsNearKeyLevel(symbol, px, atr, keyLvl);
      double m15Lvl = armedLvl;

      // Anti-chase après la touche : si on est trop loin, le mouvement est déjà parti
      if(PurePA_MaxExtensionATR > 0.0 && armedLvl > 0.0)
      {
         if(MathAbs(px - armedLvl) > atr * PurePA_MaxExtensionATR)
            continue;
      }

      MqlRates r[];
      ArraySetAsSeries(r, true);
      if(CopyRates(symbol, PERIOD_M1, 0, 5, r) < 3) continue;

      if(PurePA_RequireM1Confirm)
      {
         double body = MathAbs(r[1].close - r[1].open);
         if(body < atr * PurePA_MinBodyATR) continue;
         if(dir > 0 && r[1].close <= r[1].open) continue;
         if(dir < 0 && r[1].close >= r[1].open) continue;
      }

      double sl = 0, tp = 0;
      if(dir > 0)
      {
         double patternLow = MathMin(r[1].low, r[2].low);
         sl = patternLow - atr * 0.15;
         double risk = px - sl;
         if(risk <= 0) continue;
         tp = px + risk * PurePA_MinRR;
      }
      else
      {
         double patternHigh = MathMax(r[1].high, r[2].high);
         sl = patternHigh + atr * 0.15;
         double risk = sl - px;
         if(risk <= 0) continue;
         tp = px - risk * PurePA_MinRR;
      }

      long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double minDist = stopsLevel * point;
      if(minDist <= 0) minDist = 5 * point;
      if(MathAbs(px - sl) < minDist) continue;

      g_ppaArmedSL = sl;
      g_ppaArmedTP = tp;

      sig.valid       = true;
      sig.dirSign     = dir;
      sig.patternName = (SMCPS_BestPatternTag(dir) != "" ? SMCPS_BestPatternTag(dir) : armedSrc);
      sig.entryPrice  = px;
      sig.stopLoss    = NormalizeDouble(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
      sig.takeProfit  = NormalizeDouble(tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
      sig.keyLevel    = keyLvl;
      sig.m15Level    = m15Lvl;
      sig.reason      = StringFormat("PA %s | %s | bias=%d | D1=%s H4=%s H1=%s M15=%s M5=%s | touch=%.5f | RR>=%.1f",
                                    sig.patternName, armedSrc, g_ppaStruct.bias,
                                    g_smcTfD1Dir, g_smcTfH4Dir, g_smcTfH1Dir, g_smcTfM15Dir, g_smcTfM5Dir,
                                    armedLvl, PurePA_MinRR);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| 7. EXÉCUTION                                                     |
//+------------------------------------------------------------------+
bool PurePA_ExecuteEntry(const string symbol, const PurePA_Signal &sig)
{
   if(!sig.valid || sig.dirSign == 0) return false;

   // Cooldown
   datetime curBar = iTime(symbol, PERIOD_M1, 0);
   if(g_ppaLastEntryBar > 0 && curBar == g_ppaLastEntryBar) return false;
   if(g_ppaLastEntryBar > 0)
   {
      int barsSince = Bars(symbol, PERIOD_M1, g_ppaLastEntryBar, curBar);
      if(barsSince < PurePA_MinBarsBetweenTrades) return false;
   }

   // Déjà en position ?
   if(CountPositionsForSymbol(symbol) > 0) return false;

   // En mode LIMIT : UN SEUL ordre en attente Pure PA à la fois
   if(PurePA_CountPendingLimits(symbol) > 0)
      return false;

   // Gate anti-hedge / max positions (fonctions existantes de l’EA)
   string direction = (sig.dirSign > 0) ? "BUY" : "SELL";
   if(!CanTradeOnSymbol(symbol, direction))
   {
      if(PurePA_LogVerbose)
         Print("[PurePA] CanTradeOnSymbol bloqué — ", direction);
      return false;
   }

   // ★★★ DERNIÈRE VALIDATION GOM ★★★
   if(!PurePA_GOMFinalGate(sig.dirSign))
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick) || tick.time <= 0 ||
      TimeCurrent() - tick.time > MathMax(1, PurePA_MaxTickAgeSec) ||
      tick.bid <= 0.0 || tick.ask <= tick.bid)
      return false;

   double entryPrice = PurePA_UseLimitOrder
      ? sig.entryPrice
      : ((sig.dirSign > 0) ? tick.ask : tick.bid);
   if(!PurePA_UseLimitOrder)
   {
      if((sig.dirSign > 0 && entryPrice <= sig.stopLoss) ||
         (sig.dirSign < 0 && entryPrice >= sig.stopLoss))
      {
         Print("[PurePA] Entrée annulée — le prix a invalidé le stop avant l'envoi");
         return false;
      }

      double currentAtr = 0.0;
      int purePaAtrHandle = iATR(symbol, PERIOD_M5, 14);
      if(purePaAtrHandle != INVALID_HANDLE)
      {
         double atrBuffer[];
         ArraySetAsSeries(atrBuffer, true);
         if(CopyBuffer(purePaAtrHandle, 0, 0, 1, atrBuffer) >= 1)
            currentAtr = atrBuffer[0];
         IndicatorRelease(purePaAtrHandle);
      }
      if(currentAtr <= 0.0 ||
         (PurePA_MaxExtensionATR > 0.0 &&
          MathAbs(entryPrice - sig.keyLevel) > currentAtr * PurePA_MaxExtensionATR))
      {
         Print("[PurePA] Entrée annulée — prix trop étendu depuis la confirmation");
         return false;
      }

      if(MathAbs(entryPrice - sig.stopLoss) <= 0.0)
         return false;
   }

   // Lot
   double lot = PurePA_CalculateLot(symbol, sig.dirSign, entryPrice, sig.stopLoss);
   if(lot <= 0)
   {
      Print("[PurePA] Ordre refusé — lot minimum ou valeur tick dépasserait le risque ",
            DoubleToString(PurePA_RiskPercent, 2), "%");
      return false;
   }

   // Envoi via le pipeline sécurisé existant
   // FIX v1.22: lever g_purePAEntryInFlight AVANT SMC_SubmitEntry
   SMC_EntryRequest er;
   SMC_EntryRequest_Init(er);
   er.symbol      = symbol;
   er.orderType   = (sig.dirSign > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(PurePA_UseLimitOrder)
   {
      er.orderType    = (sig.dirSign > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
      er.maxPendingPerSymbol = 1;              // UN seul ordre limit Pure PA par symbole
      er.expirationSec = (int)MathMax(60, PurePA_LimitExpirySec);
   }
   er.volume      = lot;
   er.price       = entryPrice;
   er.sl          = sig.stopLoss;
   er.tp          = sig.takeProfit;
   if(!PurePA_UseLimitOrder)
   {
      double risk = MathAbs(entryPrice - sig.stopLoss);
      er.tp = (sig.dirSign > 0)
         ? entryPrice + risk * PurePA_MinRR
         : entryPrice - risk * PurePA_MinRR;
   }
   er.deviation   = 30;
   er.comment     = "PURE_PA " + sig.patternName;
   er.sourceLabel = "PURE_PA";

   MqlTradeResult res;
   g_purePAEntryInFlight = true;
   bool submitted = SMC_SubmitEntry(er, res);
   g_purePAEntryInFlight = false;
   if(!submitted)
   {
      Print("[PurePA] Échec ordre — retcode=", res.retcode, " ", res.comment);
      return false;
   }

   g_ppaLastEntryBar = curBar;
   ulong ticket = res.order;
   if(ticket > 0 && g_ppaManagedCount < 32)
   {
      g_ppaManagedTickets[g_ppaManagedCount++] = ticket;
      SMC_ApplyPostEntrySLBuffer(symbol, ticket, 1.0);
   }

   Print("✅ [PurePA] ", direction, " ", symbol,
         " | ", sig.reason,
         " | Lot=", DoubleToString(lot, 2),
         " | SL=", DoubleToString(er.sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
         " | TP=", DoubleToString(er.tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
         " | M15lvl=", DoubleToString(sig.m15Level, _Digits),
         " | H4=", g_smcTfH4Dir, " D1=", g_smcTfD1Dir,
         " | GOM vn=", g_smcGomVerdictNum);

   if(UseNotifications)
   {
      string msg = StringFormat("PURE PA %s %s | %s | GOM %s",
                                direction, symbol, sig.patternName, g_smcGomVerdict);
      SendNotification(msg);
   }
   return true;
}

//+------------------------------------------------------------------+
//| 8. GESTION DES POSITIONS OUVERTES (BE / Trailing / Partial)      |
//+------------------------------------------------------------------+
void PurePA_ManageOpenPositions(const string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != symbol) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      if(StringFind(posInfo.Comment(), "PURE_PA") < 0) continue;

      ulong  ticket = posInfo.Ticket();
      double open   = posInfo.PriceOpen();
      double sl     = posInfo.StopLoss();
      double tp     = posInfo.TakeProfit();
      double profit = posInfo.Profit() + posInfo.Swap();
      bool   isBuy  = (posInfo.PositionType() == POSITION_TYPE_BUY);

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double px  = isBuy ? bid : ask;

      double risk = MathAbs(open - sl);
      if(risk <= 0) continue;

      double rMultiple = isBuy ? (px - open) / risk : (open - px) / risk;

      // Scalp FX Vol : dès 1$ on met BE, dès 2$ on trail pour ne pas rendre la correction
      if(profit >= PurePA_ScalpProtectUSD && PurePA_EnableBreakEven)
      {
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         double bePrice = isBuy ? (open + point * 2) : (open - point * 2);
         bool needMove = (isBuy && sl < bePrice - point) ||
                         (!isBuy && (sl == 0 || sl > bePrice + point));
         if(needMove && trade.PositionModify(ticket, bePrice, tp))
            Print("[PurePA] Scalp BE @", DoubleToString(profit, 2), "$ ticket=", ticket);
      }
      if(profit >= PurePA_ScalpTrailUSD && PurePA_EnableTrailing)
      {
         double lockFrac = 0.55;
         double slTrail = isBuy ? (open + (px - open) * lockFrac)
                                : (open - (open - px) * lockFrac);
         bool better = (isBuy && slTrail > sl + 0.0) || (!isBuy && (sl == 0 || slTrail < sl));
         if(better && trade.PositionModify(ticket, slTrail, tp))
            Print("[PurePA] Scalp TRAIL @", DoubleToString(profit, 2), "$ SL=", DoubleToString(slTrail, _Digits));
      }

      // Break-even
      if(PurePA_EnableBreakEven && rMultiple >= 1.0)
      {
         double bePrice = open;
         // petit buffer pour couvrir le spread
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(isBuy) bePrice += point * 2;
         else      bePrice -= point * 2;

         bool needMove = (isBuy && (sl < bePrice - point)) ||
                         (!isBuy && (sl > bePrice + point || sl == 0));
         if(needMove)
         {
            if(trade.PositionModify(ticket, bePrice, tp))
               Print("[PurePA] BE activé ticket=", ticket, " @ ", DoubleToString(bePrice, _Digits));
         }
      }

      // Trailing
      if(PurePA_EnableTrailing && rMultiple >= PurePA_TrailStart_R)
      {
         double trailDist = risk * PurePA_TrailStep_R;
         double newSL = isBuy ? (px - trailDist) : (px + trailDist);
         bool improve = (isBuy && newSL > sl + SymbolInfoDouble(symbol, SYMBOL_POINT)) ||
                        (!isBuy && (sl == 0 || newSL < sl - SymbolInfoDouble(symbol, SYMBOL_POINT)));
         if(improve)
         {
            if(trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), tp))
               Print("[PurePA] Trailing ticket=", ticket, " → SL=", DoubleToString(newSL, _Digits));
         }
      }

      // Partial TP à 1R
      if(PurePA_EnablePartialTP && rMultiple >= PurePA_PartialTP_R)
      {
         string partialKey = "PPA_PARTIAL_" +
            IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
            IntegerToString((long)ticket);
         if(GlobalVariableCheck(partialKey))
            continue;

         double vol = posInfo.Volume();
         double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
         double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
         if(step <= 0.0) step = minLot;
         if(vol >= minLot * 2.0 && step > 0.0)
         {
            int volumeDigits = PurePA_VolumeDigits(step);
            double closeVol = MathFloor((vol * 0.5) / step + 1e-9) * step;
            closeVol = NormalizeDouble(closeVol, volumeDigits);
            double remainingVol = NormalizeDouble(vol - closeVol, volumeDigits);
            if(closeVol >= minLot && remainingVol >= minLot)
            {
               if(trade.PositionClosePartial(ticket, closeVol))
               {
                  GlobalVariableSet(partialKey, 1.0);
                  Print("[PurePA] Partial TP 50% ticket=", ticket,
                        " @ R=", DoubleToString(rMultiple, 2));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 9. DESSIN STRUCTURE — Swings / BOS / CHoCH                       |
//+------------------------------------------------------------------+
void PurePA_ClearStructureDrawings()
{
   ObjectsDeleteAll(0, "PPA_SW_");
   ObjectsDeleteAll(0, "PPA_BOS_");
   ObjectsDeleteAll(0, "PPA_CHOCH_");
   ObjectsDeleteAll(0, "PPA_BIAS_");
   ObjectsDeleteAll(0, "PPA_LVL_");
   ObjectDelete(0, "PPA_M15_LVL");
   ObjectDelete(0, "PPA_M15_LBL");
}

void PurePA_DrawSwings(const string symbol)
{
   if(!PurePA_DrawStructure) return;
   if(g_ppaLastSwingCount <= 0) return;

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   datetime now = TimeCurrent();
   int drawn = 0;
   const int maxDraw = 24;

   for(int i = 0; i < g_ppaLastSwingCount && drawn < maxDraw; i++)
   {
      double px = g_ppaLastSwings[i].price;
      datetime t  = g_ppaLastSwings[i].time;
      if(px <= 0 || t <= 0) continue;

      bool isHigh = g_ppaLastSwings[i].isHigh;
      color clr   = isHigh ? PurePA_ColorSwingHigh : PurePA_ColorSwingLow;
      int  code   = isHigh ? 217 : 218;   // flèche bas / haut (Wingdings)

      // Point + label
      string name = "PPA_SW_" + IntegerToString(drawn);
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_ARROW, 0, t, px);
      else
      {
         ObjectSetInteger(0, name, OBJPROP_TIME, t);
         ObjectSetDouble(0, name, OBJPROP_PRICE, px);
      }
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, name, OBJPROP_TOOLTIP,
         (isHigh ? "Swing High " : "Swing Low ") + DoubleToString(px, digits));

      // Ligne horizontale courte (rayon limité)
      string line = "PPA_SW_L_" + IntegerToString(drawn);
      datetime t2 = t + PeriodSeconds(PERIOD_H1) * 8;
      if(ObjectFind(0, line) < 0)
         ObjectCreate(0, line, OBJ_TREND, 0, t, px, t2, px);
      else
      {
         ObjectSetInteger(0, line, OBJPROP_TIME, 0, t);
         ObjectSetDouble(0, line, OBJPROP_PRICE, 0, px);
         ObjectSetInteger(0, line, OBJPROP_TIME, 1, t2);
         ObjectSetDouble(0, line, OBJPROP_PRICE, 1, px);
      }
      ObjectSetInteger(0, line, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, line, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, line, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, line, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, line, OBJPROP_BACK, true);

      // Texte SH / SL
      string txt = "PPA_SW_T_" + IntegerToString(drawn);
      if(ObjectFind(0, txt) < 0)
         ObjectCreate(0, txt, OBJ_TEXT, 0, t, px);
      else
      {
         ObjectSetInteger(0, txt, OBJPROP_TIME, t);
         ObjectSetDouble(0, txt, OBJPROP_PRICE, px);
      }
      ObjectSetString(0, txt, OBJPROP_TEXT, isHigh ? "SH" : "SL");
      ObjectSetInteger(0, txt, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, txt, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, txt, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, txt, OBJPROP_ANCHOR, isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
      ObjectSetInteger(0, txt, OBJPROP_SELECTABLE, false);

      drawn++;
   }
}

void PurePA_DrawBOS_CHoCH(const string symbol)
{
   if(!PurePA_DrawStructure) return;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   datetime now = TimeCurrent();
   datetime future = now + PeriodSeconds(PERIOD_H1) * 12;

   //--- BOS
   if(g_ppaBOSLevel > 0 && g_ppaBOSTime > 0)
   {
      color clr = PurePA_ColorBOS;
      string line = "PPA_BOS_LINE";
      if(ObjectFind(0, line) < 0)
         ObjectCreate(0, line, OBJ_TREND, 0, g_ppaBOSTime, g_ppaBOSLevel, future, g_ppaBOSLevel);
      else
      {
         ObjectSetInteger(0, line, OBJPROP_TIME, 0, g_ppaBOSTime);
         ObjectSetDouble(0, line, OBJPROP_PRICE, 0, g_ppaBOSLevel);
         ObjectSetInteger(0, line, OBJPROP_TIME, 1, future);
         ObjectSetDouble(0, line, OBJPROP_PRICE, 1, g_ppaBOSLevel);
      }
      ObjectSetInteger(0, line, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, line, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, line, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, line, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, line, OBJPROP_TOOLTIP,
         "BOS " + (g_ppaBOSDir > 0 ? "↑" : "↓") + " " + DoubleToString(g_ppaBOSLevel, digits));

      string lbl = "PPA_BOS_LBL";
      if(ObjectFind(0, lbl) < 0)
         ObjectCreate(0, lbl, OBJ_TEXT, 0, g_ppaBOSTime, g_ppaBOSLevel);
      ObjectSetInteger(0, lbl, OBJPROP_TIME, g_ppaBOSTime);
      ObjectSetDouble(0, lbl, OBJPROP_PRICE, g_ppaBOSLevel);
      ObjectSetString(0, lbl, OBJPROP_TEXT,
         "BOS " + (g_ppaBOSDir > 0 ? "▲" : "▼") + " " + DoubleToString(g_ppaBOSLevel, digits));
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, lbl, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, g_ppaBOSDir > 0 ? ANCHOR_LOWER : ANCHOR_UPPER);
      ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);

      // Flèche directionnelle
      string arw = "PPA_BOS_ARW";
      double atr = 0;
      int h = iATR(symbol, PERIOD_H1, 14);
      if(h != INVALID_HANDLE)
      {
         double ab[]; ArraySetAsSeries(ab, true);
         if(CopyBuffer(h, 0, 0, 1, ab) >= 1) atr = ab[0];
         IndicatorRelease(h);
      }
      if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 50;
      double y = g_ppaBOSLevel + (g_ppaBOSDir > 0 ? atr * 0.3 : -atr * 0.3);
      if(ObjectFind(0, arw) < 0)
         ObjectCreate(0, arw, OBJ_ARROW, 0, g_ppaBOSTime, y);
      ObjectSetInteger(0, arw, OBJPROP_TIME, g_ppaBOSTime);
      ObjectSetDouble(0, arw, OBJPROP_PRICE, y);
      ObjectSetInteger(0, arw, OBJPROP_ARROWCODE, g_ppaBOSDir > 0 ? 233 : 234);
      ObjectSetInteger(0, arw, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, arw, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, arw, OBJPROP_SELECTABLE, false);
   }

   //--- CHoCH
   if(g_ppaCHoCHLevel > 0 && g_ppaCHoCHTime > 0)
   {
      color clr = PurePA_ColorCHoCH;
      string line = "PPA_CHOCH_LINE";
      if(ObjectFind(0, line) < 0)
         ObjectCreate(0, line, OBJ_TREND, 0, g_ppaCHoCHTime, g_ppaCHoCHLevel, future, g_ppaCHoCHLevel);
      else
      {
         ObjectSetInteger(0, line, OBJPROP_TIME, 0, g_ppaCHoCHTime);
         ObjectSetDouble(0, line, OBJPROP_PRICE, 0, g_ppaCHoCHLevel);
         ObjectSetInteger(0, line, OBJPROP_TIME, 1, future);
         ObjectSetDouble(0, line, OBJPROP_PRICE, 1, g_ppaCHoCHLevel);
      }
      ObjectSetInteger(0, line, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, line, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, line, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, line, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, line, OBJPROP_TOOLTIP,
         "CHoCH " + (g_ppaCHoCHDir > 0 ? "↑" : "↓") + " " + DoubleToString(g_ppaCHoCHLevel, digits));

      string lbl = "PPA_CHOCH_LBL";
      if(ObjectFind(0, lbl) < 0)
         ObjectCreate(0, lbl, OBJ_TEXT, 0, g_ppaCHoCHTime, g_ppaCHoCHLevel);
      ObjectSetInteger(0, lbl, OBJPROP_TIME, g_ppaCHoCHTime);
      ObjectSetDouble(0, lbl, OBJPROP_PRICE, g_ppaCHoCHLevel);
      ObjectSetString(0, lbl, OBJPROP_TEXT,
         "CHoCH " + (g_ppaCHoCHDir > 0 ? "▲" : "▼") + " " + DoubleToString(g_ppaCHoCHLevel, digits));
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, lbl, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, g_ppaCHoCHDir > 0 ? ANCHOR_LOWER : ANCHOR_UPPER);
      ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);
   }

   //--- Niveaux de référence (dernier SH / SL)
   if(g_ppaStruct.lastSwingHigh > 0)
   {
      string name = "PPA_LVL_SH";
      datetime t0 = now - PeriodSeconds(PERIOD_H1) * 20;
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_TREND, 0, t0, g_ppaStruct.lastSwingHigh, future, g_ppaStruct.lastSwingHigh);
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t0);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, g_ppaStruct.lastSwingHigh);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, future);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, g_ppaStruct.lastSwingHigh);
      ObjectSetInteger(0, name, OBJPROP_COLOR, PurePA_ColorSwingHigh);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   if(g_ppaStruct.lastSwingLow > 0)
   {
      string name = "PPA_LVL_SL";
      datetime t0 = now - PeriodSeconds(PERIOD_H1) * 20;
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_TREND, 0, t0, g_ppaStruct.lastSwingLow, future, g_ppaStruct.lastSwingLow);
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t0);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, g_ppaStruct.lastSwingLow);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, future);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, g_ppaStruct.lastSwingLow);
      ObjectSetInteger(0, name, OBJPROP_COLOR, PurePA_ColorSwingLow);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
}

// POINT 3 : projette le dernier niveau M15 détecté comme zone visible sur le graphique
// (l'utilisateur suit le M1 en pratique — la figure/le niveau reste détecté en M15)
void PurePA_DrawM15Level(const string symbol)
{
   if(!PurePA_DrawStructure) return;
   if(g_ppaLastM15Level <= 0 || g_ppaLastM15Time <= 0) return;
   // Zone périmée (>4h) : ne plus l'afficher
   if(TimeCurrent() - g_ppaLastM15Time > 4 * 3600)
   {
      ObjectDelete(0, "PPA_M15_LVL");
      ObjectDelete(0, "PPA_M15_LBL");
      return;
   }

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   datetime now = TimeCurrent();
   datetime future = now + PeriodSeconds(PERIOD_M1) * 60;
   color clr = (g_ppaLastM15Dir > 0) ? PurePA_ColorSwingLow : PurePA_ColorSwingHigh;

   string line = "PPA_M15_LVL";
   if(ObjectFind(0, line) < 0)
      ObjectCreate(0, line, OBJ_TREND, 0, g_ppaLastM15Time, g_ppaLastM15Level, future, g_ppaLastM15Level);
   ObjectSetInteger(0, line, OBJPROP_TIME, 0, g_ppaLastM15Time);
   ObjectSetDouble(0, line, OBJPROP_PRICE, 0, g_ppaLastM15Level);
   ObjectSetInteger(0, line, OBJPROP_TIME, 1, future);
   ObjectSetDouble(0, line, OBJPROP_PRICE, 1, g_ppaLastM15Level);
   ObjectSetInteger(0, line, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, line, OBJPROP_STYLE, STYLE_DASHDOT);
   ObjectSetInteger(0, line, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, line, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, line, OBJPROP_SELECTABLE, false);
   ObjectSetString(0, line, OBJPROP_TOOLTIP,
      "M15 " + (g_ppaLastM15Dir > 0 ? "demande" : "offre") + " " + DoubleToString(g_ppaLastM15Level, digits));

   string lbl = "PPA_M15_LBL";
   if(ObjectFind(0, lbl) < 0)
      ObjectCreate(0, lbl, OBJ_TEXT, 0, g_ppaLastM15Time, g_ppaLastM15Level);
   ObjectSetInteger(0, lbl, OBJPROP_TIME, g_ppaLastM15Time);
   ObjectSetDouble(0, lbl, OBJPROP_PRICE, g_ppaLastM15Level);
   ObjectSetString(0, lbl, OBJPROP_TEXT, "M15");
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, lbl, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);
}

void PurePA_DrawBiasPanel(const string symbol)
{
   if(!PurePA_DrawStructure) return;

   string panel = "PPA_BIAS_PANEL";
   if(ObjectFind(0, panel) < 0)
      ObjectCreate(0, panel, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, panel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, panel, OBJPROP_YDISTANCE, 160);
   ObjectSetInteger(0, panel, OBJPROP_SELECTABLE, false);

   color clr = clrGold;
   string biasTxt = "FLAT";
   if(g_ppaStruct.bias > 0) { biasTxt = "BULLISH ▲"; clr = PurePA_ColorBiasBull; }
   else if(g_ppaStruct.bias < 0) { biasTxt = "BEARISH ▼"; clr = PurePA_ColorBiasBear; }

   string bosTxt = (g_ppaBOSDir != 0) ?
      StringFormat("BOS %s @ %s", (g_ppaBOSDir > 0 ? "↑" : "↓"),
                   DoubleToString(g_ppaBOSLevel, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS))) : "BOS —";
   string chochTxt = (g_ppaCHoCHDir != 0) ?
      StringFormat("CHoCH %s @ %s", (g_ppaCHoCHDir > 0 ? "↑" : "↓"),
                   DoubleToString(g_ppaCHoCHLevel, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS))) : "CHoCH —";

   string text = StringFormat("STRUCTURE  %s\n%s\n%s\nSwings: %d",
                              biasTxt, bosTxt, chochTxt, g_ppaLastSwingCount);

   ObjectSetString(0, panel, OBJPROP_TEXT, text);
   ObjectSetInteger(0, panel, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, panel, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, panel, OBJPROP_FONT, "Consolas");
}

void PurePA_UpdateDrawings(const string symbol)
{
   if(!PurePA_DrawStructure)
   {
      PurePA_ClearStructureDrawings();
      return;
   }

   // Mise à jour structure (si pas déjà faite ce tick)
   PurePA_UpdateStructure(symbol);

   PurePA_DrawSwings(symbol);
   PurePA_DrawBOS_CHoCH(symbol);
   PurePA_DrawM15Level(symbol);
   PurePA_DrawBiasPanel(symbol);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| 10. POINT D’ENTRÉE PRINCIPAL (à appeler depuis OnTick)           |
//+------------------------------------------------------------------+
void PurePA_OnTick(const string symbol)
{
   if(!UsePurePriceActionMode) return;

   // Mise à jour anti-flicker GOM à chaque tick (chrono de stabilité)
   if(PurePA_RequireGOMFinalGate)
      PurePA_UpdateGomStability();

   // Dessin structure (toujours, même si kill-switch)
   PurePA_UpdateDrawings(symbol);

   // Kill-switch journalier
   if(PurePA_RiskLimitReached())
   {
      // On continue à gérer les positions existantes, mais plus de nouvelles entrées
      PurePA_ManageOpenPositions(symbol);
      return;
   }

   // Gestion des positions ouvertes
   PurePA_ManageOpenPositions(symbol);

   // Si déjà en position → pas de nouvelle entrée
   if(CountPositionsForSymbol(symbol) > 0) return;

   // Construction du signal pure PA
   PurePA_Signal sig;
   if(!PurePA_BuildSignal(symbol, sig)) return;

   // Exécution (avec GOM final gate à l’intérieur)
   PurePA_ExecuteEntry(symbol, sig);
}

//+------------------------------------------------------------------+
//| 10. DIAGNOSTIC (dashboard / logs)                                |
//+------------------------------------------------------------------+
string PurePA_GetStatusText()
{
   string s = "PurePA: ";
   if(!UsePurePriceActionMode) return s + "OFF";
   if(g_ppaDaily.killSwitch)   return s + "KILL-SWITCH";

   s += (g_ppaStruct.valid ?
         StringFormat("bias=%s ", (g_ppaStruct.bias > 0 ? "BULL" : (g_ppaStruct.bias < 0 ? "BEAR" : "FLAT"))) :
         "struct? ");

   if(g_ppaBOSDir != 0)
      s += StringFormat("BOS%s ", (g_ppaBOSDir > 0 ? "↑" : "↓"));
   if(g_ppaCHoCHDir != 0)
      s += StringFormat("CHoCH%s ", (g_ppaCHoCHDir > 0 ? "↑" : "↓"));

   if(g_smcGomConnected)
      s += StringFormat("GOM=%s(vn=%d) ", g_smcGomVerdict, g_smcGomVerdictNum);
   else
      s += "GOM=OFF ";

   s += StringFormat("D1=%s H4=%s H1=%s M15=%s M5=%s ",
                     g_smcTfD1Dir, g_smcTfH4Dir, g_smcTfH1Dir, g_smcTfM15Dir, g_smcTfM5Dir);
   if(g_ppaArmedEntry > 0.0)
      s += StringFormat("ARM:%s@%.5f ", g_ppaArmedSrc, g_ppaArmedEntry);
   if(g_ppaLastM15Level > 0 && TimeCurrent() - g_ppaLastM15Time <= 4 * 3600)
      s += StringFormat("M15lvl=%.5f ", g_ppaLastM15Level);

   s += StringFormat("SW=%d PAT=%d", g_ppaLastSwingCount, g_smcps.hitCount);
   return s;
}

void PurePA_LogDiagnostics(const string symbol)
{
   static datetime s_last = 0;
   if(TimeCurrent() - s_last < 30) return;
   s_last = TimeCurrent();

   PurePA_UpdateStructure(symbol);
   Print("[PurePA-DIAG] ", PurePA_GetStatusText(),
         " | filters=", (PurePA_PassesFilters(symbol) ? "OK" : "FAIL"),
         " | dailyDD=", DoubleToString(
            (g_ppaDaily.startEquity > 0 ?
             (g_ppaDaily.startEquity - AccountInfoDouble(ACCOUNT_EQUITY)) / g_ppaDaily.startEquity * 100.0 : 0), 2), "%");
}

#endif // SMC_PURE_PRICE_ACTION_MQH
