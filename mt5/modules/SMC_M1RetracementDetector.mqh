//+------------------------------------------------------------------+
//|                                    SMC_M1RetracementDetector.mqh |
//|                                                                    |
//| VRAI détecteur de retracement en M1                              |
//| ---------------------------------------------------------------- |
//| Différence avec SMC_UpdatePreciseZones() (bande statique de range |
//| glissant M15/M5/H1) :                                             |
//|   1) Identifie une vraie jambe d'impulsion : 2 fractals M1        |
//|      confirmés, alternés (SL->SH ou SH->SL), pas une fenêtre      |
//|      arbitraire de N bougies.                                     |
//|   2) Filtre le bruit M1 : jambe rejetée si trop petite            |
//|      (< InpM1RD_MinLegATR x ATR) ou trop vieille (> MaxLegBars).  |
//|   3) Calcule le % Fibonacci EN DIRECT sur CETTE jambe précise.    |
//|   4) Distingue explicitement "retracement en cours" (0-100%) de   |
//|      "jambe invalidée / renversement" (>100%).                    |
//|                                                                    |
//| Anti-repaint : un fractal n'est enregistré que lorsque             |
//| InpM1RD_ConfirmBars bougies M1 fermées supplémentaires existent    |
//| déjà après lui — le swing ne peut plus "reculer" une fois publié.  |
//|                                                                    |
//| Intégration :                                                      |
//|   OnInit()   -> M1RD_Init();                                       |
//|   OnDeinit() -> M1RD_Deinit();                                     |
//|   OnTick()   -> M1RD_Info r = SMC_M1RD_Detect();                   |
//|                                                                    |
//| Les seuils par défaut (1.5xATR, Fibo 61.8/78.6...) sont des points |
//| de départ raisonnables mais DOIVENT être validés par backtest sur  |
//| données M1 réelles avant mise en prod, comme le reste du système.  |
//+------------------------------------------------------------------+
#property strict

//--- Réglages
input int    InpM1RD_FractalWing   = 5;    // bougies de chaque côté pour valider un fractal
input int    InpM1RD_ConfirmBars   = 3;    // bougies fermées de plus avant de "confirmer" le fractal
input int    InpM1RD_LookbackBars  = 200;  // profondeur d'analyse M1 à chaque recalcul
input double InpM1RD_MinLegATR     = 1.5;  // taille mini de la jambe = X * ATR(M1,14)
input int    InpM1RD_MinLegBars    = 3;    // jambe trop courte = bruit, ignorée
input int    InpM1RD_MaxLegBars    = 120;  // jambe trop vieille (~2h en M1) = ignorée
input double InpM1RD_OTE_Lo        = 61.8; // borne basse zone OTE
input double InpM1RD_OTE_Hi        = 78.6; // borne haute zone OTE

enum ENUM_M1RD_ZONE
{
   M1RZ_NONE,         // prix fait un nouvel extreme -> pas (encore) de retracement
   M1RZ_SHALLOW,      // 23.6% - 38.2%
   M1RZ_NORMAL,       // 38.2% - 61.8%
   M1RZ_OTE,          // 61.8% - 78.6% (zone d'entree ICT)
   M1RZ_DEEP,         // 78.6% - 100%
   M1RZ_INVALIDATED   // > 100% -> jambe cassee, ce n'est plus un retracement
};

struct M1RD_Swing
{
   double   price;
   datetime time;
   bool     isHigh;
};

struct M1RD_Info
{
   bool           valid;          // jambe exploitable (taille + fraicheur OK)
   int            direction;      // +1 = impulsion haussiere (retrace vers le bas), -1 = baissiere
   double         legOrigin;      // depart de l'impulsion (SL si bull, SH si bear)
   double         legExtreme;     // extremite de l'impulsion (SH si bull, SL si bear)
   datetime       legOriginTime;
   datetime       legExtremeTime;
   double         pct;            // % de retracement courant (0=a l'extreme, 100=a l'origine)
   ENUM_M1RD_ZONE zone;
   double         atrValue;
   int            legBars;
};

//--- Etat interne du module
M1RD_Swing g_m1rd_swings[300];
int        g_m1rd_swingCount  = 0;
int        g_m1rd_atrHandle   = INVALID_HANDLE;
datetime   g_m1rd_lastBarTime = 0;

//+------------------------------------------------------------------+
//| A appeler dans OnInit()                                          |
//+------------------------------------------------------------------+
bool M1RD_Init()
{
   g_m1rd_atrHandle   = iATR(_Symbol, PERIOD_M1, 14);
   g_m1rd_swingCount  = 0;
   g_m1rd_lastBarTime = 0;
   return (g_m1rd_atrHandle != INVALID_HANDLE);
}

//+------------------------------------------------------------------+
//| A appeler dans OnDeinit()                                        |
//+------------------------------------------------------------------+
void M1RD_Deinit()
{
   if(g_m1rd_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_m1rd_atrHandle);
      g_m1rd_atrHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Enregistre un swing confirme s'il n'est pas deja connu           |
//+------------------------------------------------------------------+
void M1RD_RegisterSwing(double price, datetime t, bool isHigh)
{
   for(int k = 0; k < g_m1rd_swingCount; k++)
      if(g_m1rd_swings[k].isHigh == isHigh && g_m1rd_swings[k].time == t)
         return; // deja enregistre

   if(g_m1rd_swingCount >= ArraySize(g_m1rd_swings))
   {
      // Buffer plein : on retire le plus ancien (decalage) plutot qu'un
      // ArrayResize couteux — le detecteur n'a besoin que des swings recents.
      for(int k = 1; k < g_m1rd_swingCount; k++)
         g_m1rd_swings[k - 1] = g_m1rd_swings[k];
      g_m1rd_swingCount--;
   }
   g_m1rd_swings[g_m1rd_swingCount].price  = price;
   g_m1rd_swings[g_m1rd_swingCount].time   = t;
   g_m1rd_swings[g_m1rd_swingCount].isHigh = isHigh;
   g_m1rd_swingCount++;
}

//+------------------------------------------------------------------+
//| Recalcule les fractals M1 confirmes. Auto-limite a 1 fois par    |
//| nouvelle bougie M1 fermee (inutile et couteux a chaque tick).    |
//+------------------------------------------------------------------+
void M1RD_UpdateSwings()
{
   datetime curBarTime = (datetime)SeriesInfoInteger(_Symbol, PERIOD_M1, SERIES_LASTBAR_DATE);
   if(curBarTime == g_m1rd_lastBarTime) return;
   g_m1rd_lastBarTime = curBarTime;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int need = InpM1RD_LookbackBars;
   if(CopyRates(_Symbol, PERIOD_M1, 0, need, r) < need) return;

   int wing    = InpM1RD_FractalWing;
   int confirm = InpM1RD_ConfirmBars;

   // Parcours du plus ancien vers le plus recent pour garder g_m1rd_swings
   // trie chronologiquement (le dernier element = swing le plus recent).
   for(int i = need - wing - 1; i >= MathMax(wing, confirm); i--)
   {
      bool isSH = true, isSL = true;
      for(int j = i - wing; j <= i + wing; j++)
      {
         if(j == i) continue;
         if(r[j].high >= r[i].high) isSH = false;
         if(r[j].low  <= r[i].low)  isSL = false;
         if(!isSH && !isSL) break;
      }
      if(isSH) M1RD_RegisterSwing(r[i].high, r[i].time, true);
      if(isSL) M1RD_RegisterSwing(r[i].low,  r[i].time, false);
   }
}

//+------------------------------------------------------------------+
//| Recupere la jambe d'impulsion la plus recente : les 2 derniers   |
//| swings confirmes, de type oppose, dans l'ordre chronologique.    |
//+------------------------------------------------------------------+
bool M1RD_GetLastLeg(double &origin, datetime &originTime,
                      double &extreme, datetime &extremeTime, int &direction)
{
   origin = extreme = 0; originTime = extremeTime = 0; direction = 0;
   if(g_m1rd_swingCount < 2) return false;

   int latest = g_m1rd_swingCount - 1;
   int prev   = -1;
   for(int k = latest - 1; k >= 0; k--)
   {
      if(g_m1rd_swings[k].isHigh != g_m1rd_swings[latest].isHigh)
      { prev = k; break; }
   }
   if(prev < 0) return false;

   originTime  = g_m1rd_swings[prev].time;
   origin      = g_m1rd_swings[prev].price;
   extremeTime = g_m1rd_swings[latest].time;
   extreme     = g_m1rd_swings[latest].price;
   direction   = g_m1rd_swings[latest].isHigh ? +1 : -1; // +1: origin=SL, extreme=SH (bull)
   return (extreme != origin);
}

//+------------------------------------------------------------------+
//| Detecteur principal — a appeler a chaque tick.                   |
//| Peu couteux : la seule partie lourde (M1RD_UpdateSwings) s'auto- |
//| limite a 1 execution par nouvelle bougie M1 fermee.               |
//+------------------------------------------------------------------+
M1RD_Info SMC_M1RD_Detect()
{
   M1RD_Info info;
   ZeroMemory(info);
   info.zone = M1RZ_NONE;

   M1RD_UpdateSwings();

   double origin, extreme; datetime originTime, extremeTime; int dir;
   if(!M1RD_GetLastLeg(origin, originTime, extreme, extremeTime, dir))
      return info;

   double legRange = MathAbs(extreme - origin);
   if(legRange <= 0) return info;

   int legBars = (int)MathRound((double)(extremeTime - originTime) / 60.0);
   if(legBars < InpM1RD_MinLegBars || legBars > InpM1RD_MaxLegBars)
      return info; // jambe trop courte (bruit) ou trop vieille (perimee)

   double atrVal = 0;
   if(g_m1rd_atrHandle != INVALID_HANDLE)
   {
      double buf[];
      if(CopyBuffer(g_m1rd_atrHandle, 0, 0, 1, buf) > 0) atrVal = buf[0];
   }
   if(atrVal <= 0 || legRange < InpM1RD_MinLegATR * atrVal)
      return info; // jambe pas assez significative vs volatilite M1 courante

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double px  = (bid > 0 && ask > 0) ? (bid + ask) * 0.5 : bid;
   if(px <= 0) return info;

   double pct = (dir > 0) ? (extreme - px) / legRange * 100.0
                          : (px - extreme) / legRange * 100.0;

   info.valid          = true;
   info.direction      = dir;
   info.legOrigin      = origin;
   info.legExtreme     = extreme;
   info.legOriginTime  = originTime;
   info.legExtremeTime = extremeTime;
   info.pct            = pct;
   info.atrValue       = atrVal;
   info.legBars        = legBars;

   if(pct < 0)                       info.zone = M1RZ_NONE;        // nouvel extreme, pas de retrace
   else if(pct > 100.0)              info.zone = M1RZ_INVALIDATED; // jambe cassee
   else if(pct < 23.6)               info.zone = M1RZ_NONE;
   else if(pct < 38.2)               info.zone = M1RZ_SHALLOW;
   else if(pct <= InpM1RD_OTE_Lo)    info.zone = M1RZ_NORMAL;
   else if(pct <= InpM1RD_OTE_Hi)    info.zone = M1RZ_OTE;
   else                              info.zone = M1RZ_DEEP;

   return info;
}

//+------------------------------------------------------------------+
//| Aide lisible pour logs / panneau graphique                       |
//+------------------------------------------------------------------+
string M1RD_ZoneToString(ENUM_M1RD_ZONE z)
{
   switch(z)
   {
      case M1RZ_NONE:        return "AUCUN";
      case M1RZ_SHALLOW:     return "LEGER (23.6-38.2%)";
      case M1RZ_NORMAL:      return "NORMAL (38.2-61.8%)";
      case M1RZ_OTE:         return "OTE (61.8-78.6%)";
      case M1RZ_DEEP:        return "PROFOND (78.6-100%)";
      case M1RZ_INVALIDATED: return "INVALIDE (>100%)";
      default:                return "?";
   }
}
//+------------------------------------------------------------------+
