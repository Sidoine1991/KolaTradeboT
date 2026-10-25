//+------------------------------------------------------------------+
//| SMC_PatternGOMIntegration.mqh — Intégration Patterns → GOM      |
//| Pattern Infinity Trader EA (sentiment + price-action avant verdict) |
//| Les figures chartistes influencent le verdict GOM au lieu d'être  |
//| utilisées seulement comme filtre a posteriori                     |
//+------------------------------------------------------------------+
#ifndef SMC_PATTERN_GOM_INTEGRATION_MQH
#define SMC_PATTERN_GOM_INTEGRATION_MQH

#include "SMC_SharedCore.mqh"
#include "SMC_PatternSignals.mqh"

// ── État d'intégration Patterns → GOM ───────────────────────────────────
struct SMC_PatternGOMState {
   double patternBuyScore;      // Score composite patterns haussiers
   double patternSellScore;     // Score composite patterns baissiers
   double patternConfluence;    // Confluence patterns (0-100)
   int strongPatternCount;      // Nombre de patterns forts (weight >= 3)
   int patternDirection;        // Direction dominante des patterns (1=buy, -1=sell, 0=neutral)
   double gomAdjustment;        // Ajustement appliqué au verdict GOM
   bool patternConfirmedGOM;    // Les patterns ont confirmé le verdict GOM
   datetime lastPatternCheck;   // Dernière vérification des patterns
};

SMC_PatternGOMState g_patternGomState;

// ── Configuration de l'intégration ───────────────────────────────────────
input double InpPatternGOMWeight     = 0.3;   // Poids des patterns dans le verdict GOM (0-1)
input double InpPatternConfluenceMin = 60.0;  // Confluence minimale pour influencer GOM
input int    InpStrongPatternMin    = 2;     // Nombre minimum de patterns forts requis
input bool   InpPatternOverrideWeak  = true;  // Patterns forts peuvent override GOM faible
input double InpPatternBonusThreshold = 2.0;  // Seuil GOM pour bonus patterns
input bool   InpPatternRespectTrend  = true;  // Respecter la tendance avant override (anti-contre-trend)

// ── Initialiser l'état d'intégration ─────────────────────────────────────
void SMC_PGI_Init()
{
   g_patternGomState.patternBuyScore = 0;
   g_patternGomState.patternSellScore = 0;
   g_patternGomState.patternConfluence = 0;
   g_patternGomState.strongPatternCount = 0;
   g_patternGomState.patternDirection = 0;
   g_patternGomState.gomAdjustment = 0;
   g_patternGomState.patternConfirmedGOM = false;
   g_patternGomState.lastPatternCheck = 0;
}

// ── Calculer le score composite des patterns pour une direction ────────────
double SMC_PGI_CalculatePatternScore(const int dirSign)
{
   // Accéder aux scores de SMC_PatternSignals
   double dirWeight = SMCPS_DirWeight(dirSign);
   int dirStrong = SMCPS_DirStrong(dirSign);
   
   // Bonus pour patterns forts
   double strongBonus = (double)dirStrong * 0.5;
   
   // Bonus pour confluence élevée
   double totalWeight = g_smcps.bullWeight + g_smcps.bearWeight;
   double confluence = (totalWeight > 0) ? (dirWeight / totalWeight) * 100.0 : 0;
   double confluenceBonus = (confluence >= InpPatternConfluenceMin) ? 1.0 : 0;
   
   return dirWeight + strongBonus + confluenceBonus;
}

// ── Déterminer la direction dominante des patterns ───────────────────────
int SMC_PGI_GetPatternDirection()
{
   double buyScore = SMC_PGI_CalculatePatternScore(1);
   double sellScore = SMC_PGI_CalculatePatternScore(-1);
   
   g_patternGomState.patternBuyScore = buyScore;
   g_patternGomState.patternSellScore = sellScore;
   
   double scoreDiff = buyScore - sellScore;
   double threshold = 1.0; // Seuil de significativité
   
   if(scoreDiff > threshold) return 1;   // Dominance haussière
   if(scoreDiff < -threshold) return -1;  // Dominance baissière
   return 0; // Neutre
}

// ── Calculer la confluence des patterns ───────────────────────────────────
double SMC_PGI_CalculateConfluence()
{
   double totalWeight = g_smcps.bullWeight + g_smcps.bearWeight;
   if(totalWeight <= 0) return 0;
   
   double maxWeight = MathMax(g_smcps.bullWeight, g_smcps.bearWeight);
   double confluence = (maxWeight / totalWeight) * 100.0;
   
   g_patternGomState.patternConfluence = confluence;
   return confluence;
}

// ── Déterminer la tendance actuelle (EMA-based) ─────────────────────────────
int SMC_PGI_GetTrendDirection(const string symbol, const ENUM_TIMEFRAMES tf)
{
   int pgiEmaHandle = iMA(symbol, tf, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(pgiEmaHandle == INVALID_HANDLE) return 0;

   double emaBuffer[];
   ArraySetAsSeries(emaBuffer, true);
   if(CopyBuffer(pgiEmaHandle, 0, 0, 3, emaBuffer) < 3) {
      IndicatorRelease(pgiEmaHandle);
      return 0;
   }

   double priceBuffer[];
   ArraySetAsSeries(priceBuffer, true);
   if(CopyClose(symbol, tf, 0, 3, priceBuffer) < 3) {
      IndicatorRelease(pgiEmaHandle);
      return 0;
   }

   // Trend = prix au-dessus de l'EMA et EMA croissante
   bool priceAboveEMA = (priceBuffer[0] > emaBuffer[0]);
   bool emaRising = (emaBuffer[0] > emaBuffer[1] && emaBuffer[1] > emaBuffer[2]);
   bool emaFalling = (emaBuffer[0] < emaBuffer[1] && emaBuffer[1] < emaBuffer[2]);

   IndicatorRelease(pgiEmaHandle);

   if(priceAboveEMA && emaRising) return 1;   // Uptrend
   if(!priceAboveEMA && emaFalling) return -1; // Downtrend
   return 0; // Range/indécis
}

// ── Mettre à jour l'état d'intégration ─────────────────────────────────────
void SMC_PGI_Update(const string symbol, const ENUM_TIMEFRAMES tf)
{
   // Mettre à jour seulement toutes les 30 secondes
   if(TimeCurrent() - g_patternGomState.lastPatternCheck < 30) return;
   g_patternGomState.lastPatternCheck = TimeCurrent();

   // Calculer la direction des patterns
   g_patternGomState.patternDirection = SMC_PGI_GetPatternDirection();

   // Calculer la confluence
   SMC_PGI_CalculateConfluence();

   // Compter les patterns forts
   g_patternGomState.strongPatternCount = g_smcps.bullStrong + g_smcps.bearStrong;
}

// ── Ajuster le verdict GOM en fonction des patterns ─────────────────────
int SMC_PGI_AdjustGOMVerdict(const int originalGOMNum, const string symbol, const ENUM_TIMEFRAMES tf)
{
   SMC_PGI_Update(symbol, tf);
   
   int adjustedGOM = originalGOMNum;
   double adjustment = 0;
   
   // Si pas assez de patterns ou confluence faible, pas d'ajustement
   if(g_patternGomState.strongPatternCount < InpStrongPatternMin ||
      g_patternGomState.patternConfluence < InpPatternConfluenceMin) {
      g_patternGomState.gomAdjustment = 0;
      g_patternGomState.patternConfirmedGOM = false;
      return adjustedGOM;
   }
   
   // Calculer l'ajustement basé sur la direction des patterns
   double patternInfluence = InpPatternGOMWeight;
   
   if(g_patternGomState.patternDirection > 0) {
      // Patterns haussiers → augmenter BUY GOM
      adjustment = patternInfluence * 1.0;
      if(adjustedGOM >= 0) {
         adjustedGOM += (int)(adjustment * 10); // Amplifier si même direction
      } else {
         adjustedGOM += (int)(adjustment * 5);  // Réduire si direction opposée
      }
   } else if(g_patternGomState.patternDirection < 0) {
      // Patterns baissiers → augmenter SELL GOM
      adjustment = patternInfluence * -1.0;
      if(adjustedGOM <= 0) {
         adjustedGOM += (int)(adjustment * 10); // Amplifier si même direction
      } else {
         adjustedGOM += (int)(adjustment * 5);  // Réduire si direction opposée
      }
   }
   
   // Override si patterns forts et GOM faible
   // SÉCURITÉ: vérifier la tendance avant override (anti-contre-trend)
   if(InpPatternOverrideWeak && MathAbs(originalGOMNum) < InpPatternBonusThreshold) {
      if(g_patternGomState.strongPatternCount >= InpStrongPatternMin) {
         int trendDir = 0;
         if(InpPatternRespectTrend) {
            trendDir = SMC_PGI_GetTrendDirection(symbol, tf);
         }

         // Override BUY: seulement si pas en downtrend fort
         if(g_patternGomState.patternDirection > 0 && originalGOMNum < 2) {
            if(InpPatternRespectTrend && trendDir < 0) {
               Print("🚫 Pattern Override BLOCKÉ - BUY patterns en downtrend (EMA 50) | ", symbol);
               // Pas d'override, garder le GOM original (probablement SELL ou WAIT)
            } else {
               adjustedGOM = 2; // Forcer BUY GOOD
               Print("🔄 Pattern Override - Weak GOM overridden by strong BUY patterns");
            }
         }
         // Override SELL: seulement si pas en uptrend fort
         else if(g_patternGomState.patternDirection < 0 && originalGOMNum > -2) {
            if(InpPatternRespectTrend && trendDir > 0) {
               Print("🚫 Pattern Override BLOCKÉ - SELL patterns en uptrend (EMA 50) | ", symbol);
               // Pas d'override, garder le GOM original
            } else {
               adjustedGOM = -2; // Forcer SELL GOOD
               Print("🔄 Pattern Override - Weak GOM overridden by strong SELL patterns");
            }
         }
      }
   }
   
   // Bonus pour confluence très élevée
   if(g_patternGomState.patternConfluence >= 80.0) {
      if(adjustedGOM > 0) adjustedGOM = MathMin(adjustedGOM + 1, 3);
      if(adjustedGOM < 0) adjustedGOM = MathMax(adjustedGOM - 1, -3);
   }
   
   g_patternGomState.gomAdjustment = adjustment;
   
   // Vérifier si les patterns confirment le GOM
   bool sameDirection = ((originalGOMNum > 0 && g_patternGomState.patternDirection > 0) ||
                        (originalGOMNum < 0 && g_patternGomState.patternDirection < 0));
   g_patternGomState.patternConfirmedGOM = sameDirection;
   
   if(sameDirection && MathAbs(adjustment) > 0) {
      Print("✅ Patterns confirm GOM - Original: ", originalGOMNum, 
            " | Adjusted: ", adjustedGOM,
            " | Pattern Direction: ", g_patternGomState.patternDirection,
            " | Confluence: ", DoubleToString(g_patternGomState.patternConfluence, 1), "%");
   }
   
   return adjustedGOM;
}

// ── Vérifier si les patterns confirment le verdict GOM ───────────────────
bool SMC_PGI_PatternsConfirmGOM(const int gomNum)
{
   return g_patternGomState.patternConfirmedGOM;
}

// ── Obtenir le score de confluence des patterns ───────────────────────────
double SMC_PGI_GetPatternConfluence()
{
   return g_patternGomState.patternConfluence;
}

// ── Obtenir la direction des patterns (valeur stockée) ─────────────────────
int SMC_PGI_GetStoredPatternDirection()
{
   return g_patternGomState.patternDirection;
}

// ── Obtenir le nombre de patterns forts ───────────────────────────────────
int SMC_PGI_GetStrongPatternCount()
{
   return g_patternGomState.strongPatternCount;
}

// ── Obtenir l'ajustement appliqué au GOM ─────────────────────────────────
double SMC_PGI_GetGOMAdjustment()
{
   return g_patternGomState.gomAdjustment;
}

// ── Afficher le dashboard d'intégration Patterns-GOM ─────────────────────
void SMC_PGI_ShowDashboard()
{
   int y = 150;
   int s = 15;
   
   // Direction des patterns
   string dirText = "NEUTRAL";
    color dirColor = clrGray;
   if(g_patternGomState.patternDirection > 0) {
      dirText = "BUY";
      dirColor = clrLime;
   } else if(g_patternGomState.patternDirection < 0) {
      dirText = "SELL";
      dirColor = clrRed;
   }
   
   ObjectCreate(0, "PGI_PATTERN_DIR", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "PGI_PATTERN_DIR", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "PGI_PATTERN_DIR", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "PGI_PATTERN_DIR", OBJPROP_YDISTANCE, y);
   ObjectSetString(0, "PGI_PATTERN_DIR", OBJPROP_TEXT, 
                    StringFormat("Pattern Dir: %s", dirText));
   ObjectSetInteger(0, "PGI_PATTERN_DIR", OBJPROP_COLOR, dirColor);
   y += s;
   
   // Confluence
   ObjectCreate(0, "PGI_CONFLUENCE", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "PGI_CONFLUENCE", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "PGI_CONFLUENCE", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "PGI_CONFLUENCE", OBJPROP_YDISTANCE, y);
   ObjectSetString(0, "PGI_CONFLUENCE", OBJPROP_TEXT, 
                    StringFormat("Confluence: %.1f%%", g_patternGomState.patternConfluence));
   ObjectSetInteger(0, "PGI_CONFLUENCE", OBJPROP_COLOR, 
                    (g_patternGomState.patternConfluence >= InpPatternConfluenceMin) ? clrLime : clrOrange);
   y += s;
   
   // Patterns forts
   ObjectCreate(0, "PGI_STRONG_COUNT", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "PGI_STRONG_COUNT", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "PGI_STRONG_COUNT", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "PGI_STRONG_COUNT", OBJPROP_YDISTANCE, y);
   ObjectSetString(0, "PGI_STRONG_COUNT", OBJPROP_TEXT, 
                    StringFormat("Strong Patterns: %d", g_patternGomState.strongPatternCount));
   ObjectSetInteger(0, "PGI_STRONG_COUNT", OBJPROP_COLOR, 
                    (g_patternGomState.strongPatternCount >= InpStrongPatternMin) ? clrLime : clrOrange);
   y += s;
   
   // Ajustement GOM
   ObjectCreate(0, "PGI_GOM_ADJ", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "PGI_GOM_ADJ", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "PGI_GOM_ADJ", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "PGI_GOM_ADJ", OBJPROP_YDISTANCE, y);
   ObjectSetString(0, "PGI_GOM_ADJ", OBJPROP_TEXT, 
                    StringFormat("GOM Adjustment: %+.2f", g_patternGomState.gomAdjustment));
   ObjectSetInteger(0, "PGI_GOM_ADJ", OBJPROP_COLOR, 
                    (g_patternGomState.gomAdjustment != 0) ? clrLime : clrGray);
   y += s;
   
   // Confirmation
   ObjectCreate(0, "PGI_CONFIRMED", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "PGI_CONFIRMED", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "PGI_CONFIRMED", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "PGI_CONFIRMED", OBJPROP_YDISTANCE, y);
   ObjectSetString(0, "PGI_CONFIRMED", OBJPROP_TEXT, 
                    StringFormat("Confirmed: %s", g_patternGomState.patternConfirmedGOM ? "YES" : "NO"));
   ObjectSetInteger(0, "PGI_CONFIRMED", OBJPROP_COLOR, 
                    g_patternGomState.patternConfirmedGOM ? clrLime : clrGray);
}

// ── Nettoyer les objets du dashboard ───────────────────────────────────────
void SMC_PGI_ClearDashboard()
{
   ObjectsDeleteAll(0, "PGI_PATTERN_DIR");
   ObjectsDeleteAll(0, "PGI_CONFLUENCE");
   ObjectsDeleteAll(0, "PGI_STRONG_COUNT");
   ObjectsDeleteAll(0, "PGI_GOM_ADJ");
    ObjectsDeleteAll(0, "PGI_CONFIRMED");
}

void SMC_PGI_Deinit()
{
   SMC_PGI_ClearDashboard();
}

#endif
