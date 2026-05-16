//+------------------------------------------------------------------+
//| SMC_SniperModules.mqh                                             |
//| Fusion intelligente: Liquidity Sniper + Sniper Radar + SMC_Universal
//| Voting System: chaque module vote, SMC arbitre                     |
//+------------------------------------------------------------------+
#ifndef SMC_SNIPER_MODULES_MQH
#define SMC_SNIPER_MODULES_MQH

//=== STRUCTURES VOTING SYSTEM ================================================

struct SniperVote
{
   bool   liquiditySweptDetected;    // Liquidity Sniper: sweep détecté?
   int    confluenceScore;           // Sniper Radar: score 1-5
   bool   radarBOSDetected;          // Sniper Radar: BOS/MSS détecté?
   double levelPrice;                // Prix du niveau détecté
   string levelType;                 // "SWEEP", "BOS", "CONFLUENCE", etc
   int    totalSignalStrength;       // Score final 0-10 (pour graphique)
};

//=== VARIABLES GLOBALES =======================================================

SniperVote     g_CurrentVote;
double         g_LiquidityLevels[];
int            g_LiquidityLevelCount = 0;
datetime       g_LastSniperUpdate = 0;

//=== MODULE 1: LIQUIDITY SNIPER - SWEEP DETECTOR ==========================
// Détecte: BSL/SSL (equal highs/lows) + SWEEPS (cassure+retour)
// Valeur: ★★★★★ (signal très distinct)

struct LiquidityLevel
{
   double price;
   int touches;
   bool isBSL;      // true=BSL (résistance), false=SSL (support)
   bool swept;      // Sweep confirmé
   int bar;
};

void LiquiditySniperModule_Update()
{
   if(!EnableLiquiditySniperModule)
      return;

   ArrayResize(g_LiquidityLevels, 0);
   g_LiquidityLevelCount = 0;

   double tolPips = LS_EqualPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Détecter swing highs (BSL) et swing lows (SSL)
   for(int i = 2; i <= LS_LookbackBars - 2; i++)
   {
      double hi = iHigh(_Symbol, _Period, i);
      double lo = iLow(_Symbol, _Period, i);

      // Swing high = BSL candidate
      if(hi > iHigh(_Symbol, _Period, i-1) &&
         hi > iHigh(_Symbol, _Period, i+1) &&
         hi > iHigh(_Symbol, _Period, i-2) &&
         hi > iHigh(_Symbol, _Period, i+2))
      {
         int touches = LS_CountTouches(hi, true, tolPips, i);
         if(touches >= LS_MinTouches)
         {
            bool swept = LS_IsSwept(hi, true);
            if(swept) // Seulement si sweep confirmé
            {
               ArrayResize(g_LiquidityLevels, g_LiquidityLevelCount + 1);
               g_LiquidityLevels[g_LiquidityLevelCount].price = hi;
               g_LiquidityLevels[g_LiquidityLevelCount].isBSL = true;
               g_LiquidityLevels[g_LiquidityLevelCount].swept = true;
               g_LiquidityLevelCount++;
            }
         }
      }

      // Swing low = SSL candidate
      if(lo < iLow(_Symbol, _Period, i-1) &&
         lo < iLow(_Symbol, _Period, i+1) &&
         lo < iLow(_Symbol, _Period, i-2) &&
         lo < iLow(_Symbol, _Period, i+2))
      {
         int touches = LS_CountTouches(lo, false, tolPips, i);
         if(touches >= LS_MinTouches)
         {
            bool swept = LS_IsSwept(lo, false);
            if(swept)
            {
               ArrayResize(g_LiquidityLevels, g_LiquidityLevelCount + 1);
               g_LiquidityLevels[g_LiquidityLevelCount].price = lo;
               g_LiquidityLevels[g_LiquidityLevelCount].isBSL = false;
               g_LiquidityLevels[g_LiquidityLevelCount].swept = true;
               g_LiquidityLevelCount++;
            }
         }
      }
   }
}

int LS_CountTouches(double level, bool isHigh, double tol, int startBar)
{
   int touches = 0;
   for(int i = startBar; i <= LS_LookbackBars; i++)
   {
      double price = isHigh ? iHigh(_Symbol, _Period, i) : iLow(_Symbol, _Period, i);
      if(MathAbs(price - level) <= tol) touches++;
   }
   return touches;
}

bool LS_IsSwept(double level, bool isBSL)
{
   double currentHigh = iHigh(_Symbol, _Period, 1);
   double currentLow = iLow(_Symbol, _Period, 1);

   if(isBSL) // Sweep baissier du BSL
      return (currentHigh > level && currentLow < level);
   else      // Sweep haussier du SSL
      return (currentLow < level && currentHigh > level);
}

//=== MODULE 2: SNIPER RADAR - CONFLUENCE FILTER ============================
// Détecte: BOS/MSS + Order Blocks + FVG + Confluence scoring
// Valeur: ★★★☆☆ (moyen, overlap avec GOM)

struct MarketStructure
{
   bool bullish;
   bool bearish;
   bool bosDetected;
   bool mssDetected;
   double bosLevel;
};

MarketStructure g_SR_MS_HTF, g_SR_MS_Current;

void SniperRadarModule_Update()
{
   if(!EnableSniperRadarModule)
      return;

   // Analyser structure HTF (bias)
   SR_AnalyzeStructure(SR_HTF, g_SR_MS_HTF);

   // Analyser structure timeframe courant (execution)
   SR_AnalyzeStructure(_Period, g_SR_MS_Current);
}

void SR_AnalyzeStructure(ENUM_TIMEFRAMES tf, MarketStructure &ms)
{
   // Détecter swing points
   double lastHigh = 0, prevHigh = 0;
   double lastLow = DBL_MAX, prevLow = DBL_MAX;

   for(int i = 1; i <= SR_SwingLookback; i++)
   {
      double hi = iHigh(_Symbol, tf, i);
      double lo = iLow(_Symbol, tf, i);

      if(hi > lastHigh) { prevHigh = lastHigh; lastHigh = hi; }
      if(lo < lastLow) { prevLow = lastLow; lastLow = lo; }
   }

   // Déterminer structure
   ms.bullish = (lastHigh > prevHigh && lastLow > prevLow);
   ms.bearish = (lastHigh < prevHigh && lastLow < prevLow);

   // Détecter BOS
   double currentClose = iClose(_Symbol, tf, 1);
   ms.bosDetected = false;

   if(ms.bullish && currentClose > lastHigh)
   {
      ms.bosDetected = true;
      ms.bosLevel = lastHigh;
   }
   if(ms.bearish && currentClose < lastLow)
   {
      ms.bosDetected = true;
      ms.bosLevel = lastLow;
   }
}

//=== MODULE 3: VOTING SYSTEM - DECISION MAKER ==============================
// Fusionne les 3 modules et décide si trade = GO

void SniperModules_ComputeVote()
{
   g_CurrentVote.liquiditySweptDetected = false;
   g_CurrentVote.confluenceScore = 0;
   g_CurrentVote.radarBOSDetected = false;
   g_CurrentVote.totalSignalStrength = 0;

   if(!EnableLiquiditySniperModule && !EnableSniperRadarModule)
      return;

   // VOTE 1: Liquidity Sniper (Sweep Detection)
   if(EnableLiquiditySniperModule && g_LiquidityLevelCount > 0)
   {
      g_CurrentVote.liquiditySweptDetected = true;
      g_CurrentVote.levelType = g_LiquidityLevels[0].isBSL ? "SWEEP_BSL" : "SWEEP_SSL";
      g_CurrentVote.levelPrice = g_LiquidityLevels[0].price;
      g_CurrentVote.totalSignalStrength += 3; // Sweep = 3 points
   }

   // VOTE 2: Sniper Radar (Confluence)
   if(EnableSniperRadarModule)
   {
      int score = 0;

      // BOS = +2 points
      if(g_SR_MS_Current.bosDetected) score += 2;

      // Structure bias HTF alignée = +1 point
      if(g_SR_MS_HTF.bullish && g_SR_MS_Current.bullish) score += 1;
      if(g_SR_MS_HTF.bearish && g_SR_MS_Current.bearish) score += 1;

      // MSS (anti-biais) = +1 point
      if(g_SR_MS_Current.mssDetected) score += 1;

      // Max 5 points
      g_CurrentVote.confluenceScore = MathMin(5, score);
      g_CurrentVote.radarBOSDetected = g_SR_MS_Current.bosDetected;

      g_CurrentVote.totalSignalStrength += g_CurrentVote.confluenceScore;
   }

   // VOTE 3: FINAL DECISION (orchestre SMC)
   // Score 0-10, règles:
   // 0-2:  SKIP (signal faible)
   // 3-5:  ATTENDRE GOM + IA (signal moyen)
   // 6-8:  TRADING OK (signal bon)
   // 9-10: TRADING FORT (signal excellent)
}

bool SniperModules_ShouldTrade(string direction)
{
   if(g_CurrentVote.totalSignalStrength < 3)
   {
      if(DebugSniperModules)
         Print("🚫 SNIPER: Signal faible (", g_CurrentVote.totalSignalStrength, "/10) - SKIP");
      return false;
   }

   // Vérifier conflit de direction
   if(g_CurrentVote.radarBOSDetected)
   {
      // BOS est haussier = préfère BUY
      bool bosHaussier = (g_SR_MS_Current.bullish);

      if(direction == "BUY" && !bosHaussier)
      {
         if(DebugSniperModules)
            Print("⚠️ SNIPER: Conflit direction (BUY vs BOS bearish)");
         return false;
      }
      if(direction == "SELL" && bosHaussier)
      {
         if(DebugSniperModules)
            Print("⚠️ SNIPER: Conflit direction (SELL vs BOS bullish)");
         return false;
      }
   }

   if(DebugSniperModules)
      Print("✅ SNIPER VOTE: ", g_CurrentVote.totalSignalStrength, "/10 | Type:",
            g_CurrentVote.levelType, " @ ", g_CurrentVote.levelPrice);

   return true;
}

//=== GRAPHIQUES SNIPER ======================================================

void SniperModules_DrawGraphics()
{
   if(!ShowSniperGraphics)
      return;

   // Effacer anciens graphiques
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "SNIPER_") == 0)
         ObjectDelete(0, name);
   }

   // Dessiner niveaux Liquidity Sniper (sweeps)
   if(EnableLiquiditySniperModule && g_LiquidityLevelCount > 0)
   {
      for(int i = 0; i < g_LiquidityLevelCount; i++)
      {
         string objName = StringFormat("SNIPER_LS_SWEEP_%d", i);
         color col = g_LiquidityLevels[i].isBSL ? clrRed : clrBlue;

         ObjectCreate(0, objName, OBJ_HLINE, 0, 0, g_LiquidityLevels[i].price);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASHDOT);
      }
   }

   // Dessiner confluence score (texte)
   if(EnableSniperRadarModule && g_CurrentVote.confluenceScore > 0)
   {
      string scoreText = StringFormat("CONFLUENCE: %d/5", g_CurrentVote.confluenceScore);
      string objName = "SNIPER_CONFLUENCE_TEXT";

      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetString(0, objName, OBJPROP_TEXT, scoreText);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 50);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 100);
   }

   ChartRedraw(0);
}

#endif
