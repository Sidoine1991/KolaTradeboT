//+------------------------------------------------------------------+
//| SMC_AdaptiveInstrument.mqh — Filtrage adaptatif par instrument  |
//| Pattern Index Synthetics EA / Scalper Deriv                      |
//| Paramètres GOM différenciés par catégorie de symbole             |
//+------------------------------------------------------------------+
#ifndef SMC_ADAPTIVE_INSTRUMENT_MQH
#define SMC_ADAPTIVE_INSTRUMENT_MQH

#include "SMC_SharedCore.mqh"

// ── Configuration adaptative par catégorie de symbole ─────────────────────
struct SMC_AdaptiveConfig {
   double gomThreshold;        // Seuil GOM pour entrée (|vn|)
   double volatilityMultiplier; // Multiplicateur ATR pour SL/TP
   double rangeTolerance;      // Tolérance range (%)
   int minBarsForEntry;        // Nombre minimum de bougies après signal
   double patternWeightBonus;  // Bonus poids patterns SMC
   bool allowGridTrading;     // Autoriser grid/martingale (déconseillé)
};

SMC_AdaptiveConfig g_adaptiveConfig[7]; // Indexé par ENUM_SYMBOL_CATEGORY

// ── Volatilité historique par symbole ────────────────────────────────────
struct SMC_VolatilityHistory {
   string symbol;
   double atr14;
   double atr50;
   double atr200;
   double bodyRatioAvg;
   double rangeRatioAvg;
   int sampleCount;
};

SMC_VolatilityHistory g_volHistory[64]; // Cache par symbole
int g_volHistoryCount = 0;

// ── Initialisation des configurations par défaut ─────────────────────────
void SMC_AI_Init()
{
   // BOOM/CRASH (spikes brusques)
   g_adaptiveConfig[SYM_BOOM_CRASH].gomThreshold = 1.5;
   g_adaptiveConfig[SYM_BOOM_CRASH].volatilityMultiplier = 1.5;
   g_adaptiveConfig[SYM_BOOM_CRASH].rangeTolerance = 0.15;
   g_adaptiveConfig[SYM_BOOM_CRASH].minBarsForEntry = 2;
   g_adaptiveConfig[SYM_BOOM_CRASH].patternWeightBonus = 1.2;
   g_adaptiveConfig[SYM_BOOM_CRASH].allowGridTrading = false;
   
   // VOLATILITY (mouvements continus)
   g_adaptiveConfig[SYM_VOLATILITY].gomThreshold = 2.0;
   g_adaptiveConfig[SYM_VOLATILITY].volatilityMultiplier = 2.0;
   g_adaptiveConfig[SYM_VOLATILITY].rangeTolerance = 0.25;
   g_adaptiveConfig[SYM_VOLATILITY].minBarsForEntry = 3;
   g_adaptiveConfig[SYM_VOLATILITY].patternWeightBonus = 1.3;
   g_adaptiveConfig[SYM_VOLATILITY].allowGridTrading = false;
   
   // FOREX (marché classique)
   g_adaptiveConfig[SYM_FOREX].gomThreshold = 2.0;
   g_adaptiveConfig[SYM_FOREX].volatilityMultiplier = 2.0;
   g_adaptiveConfig[SYM_FOREX].rangeTolerance = 0.20;
   g_adaptiveConfig[SYM_FOREX].minBarsForEntry = 4;
   g_adaptiveConfig[SYM_FOREX].patternWeightBonus = 1.5;
   g_adaptiveConfig[SYM_FOREX].allowGridTrading = false;
   
   // COMMODITY
   g_adaptiveConfig[SYM_COMMODITY].gomThreshold = 2.5;
   g_adaptiveConfig[SYM_COMMODITY].volatilityMultiplier = 2.5;
   g_adaptiveConfig[SYM_COMMODITY].rangeTolerance = 0.30;
   g_adaptiveConfig[SYM_COMMODITY].minBarsForEntry = 5;
   g_adaptiveConfig[SYM_COMMODITY].patternWeightBonus = 1.4;
   g_adaptiveConfig[SYM_COMMODITY].allowGridTrading = false;
   
   // METAL (Gold, Silver)
   g_adaptiveConfig[SYM_METAL].gomThreshold = 2.5;
   g_adaptiveConfig[SYM_METAL].volatilityMultiplier = 2.5;
   g_adaptiveConfig[SYM_METAL].rangeTolerance = 0.35;
   g_adaptiveConfig[SYM_METAL].minBarsForEntry = 5;
   g_adaptiveConfig[SYM_METAL].patternWeightBonus = 1.6;
   g_adaptiveConfig[SYM_METAL].allowGridTrading = false;
   
   // CRYPTO
   g_adaptiveConfig[SYM_CRYPTO].gomThreshold = 3.0;
   g_adaptiveConfig[SYM_CRYPTO].volatilityMultiplier = 3.0;
   g_adaptiveConfig[SYM_CRYPTO].rangeTolerance = 0.40;
   g_adaptiveConfig[SYM_CRYPTO].minBarsForEntry = 6;
   g_adaptiveConfig[SYM_CRYPTO].patternWeightBonus = 1.8;
   g_adaptiveConfig[SYM_CRYPTO].allowGridTrading = false;
   
   // UNKNOWN (conservateur par défaut)
   g_adaptiveConfig[SYM_UNKNOWN].gomThreshold = 2.0;
   g_adaptiveConfig[SYM_UNKNOWN].volatilityMultiplier = 2.0;
   g_adaptiveConfig[SYM_UNKNOWN].rangeTolerance = 0.20;
   g_adaptiveConfig[SYM_UNKNOWN].minBarsForEntry = 4;
   g_adaptiveConfig[SYM_UNKNOWN].patternWeightBonus = 1.0;
   g_adaptiveConfig[SYM_UNKNOWN].allowGridTrading = false;
}

// ── Obtenir la configuration adaptative pour un symbole ───────────────────
SMC_AdaptiveConfig SMC_AI_GetConfig(const string symbol)
{
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(symbol);
   return g_adaptiveConfig[cat];
}

// ── Calculer le seuil GOM adaptatif pour un symbole ───────────────────────
double SMC_AI_AdaptiveGOMThreshold(const string symbol)
{
   SMC_AdaptiveConfig cfg = SMC_AI_GetConfig(symbol);
   
   // Ajustement basé sur la volatilité historique
   SMC_VolatilityHistory vol = SMC_AI_GetVolatilityHistory(symbol);
   double volAdjustment = 1.0;
   
   if(vol.sampleCount > 10) {
      // Si volatilité > 2x moyenne, assouplir le seuil
      if(vol.atr14 > vol.atr50 * 2.0) {
         volAdjustment = 0.8; // Seuil plus bas en haute volatilité
      }
      // Si volatilité < 0.5x moyenne, resserrer le seuil
      else if(vol.atr14 < vol.atr50 * 0.5) {
         volAdjustment = 1.2; // Seuil plus haut en basse volatilité
      }
   }
   
   return cfg.gomThreshold * volAdjustment;
}

// ── Mettre à jour l'historique de volatilité pour un symbole ───────────────
void SMC_AI_UpdateVolatilityHistory(const string symbol)
{
   string sym = symbol;
   StringToUpper(sym);
   
   // Chercher ou créer l'entrée
   int idx = -1;
   for(int i = 0; i < g_volHistoryCount; i++) {
      if(StringFind(g_volHistory[i].symbol, sym) >= 0) {
         idx = i;
         break;
      }
   }
   
   if(idx == -1 && g_volHistoryCount < 64) {
      idx = g_volHistoryCount++;
   }
   
   if(idx == -1) return; // Cache plein
   
   // Calculer ATR sur différentes périodes
   double atr14 = iATR(symbol, PERIOD_CURRENT, 14);
   double atr50 = iATR(symbol, PERIOD_CURRENT, 50);
   double atr200 = iATR(symbol, PERIOD_CURRENT, 200);
   
   // Calculer ratios body/range moyens sur 20 bougies
   double bodySum = 0, rangeSum = 0;
   for(int i = 1; i <= 20; i++) {
      double body = MathAbs(iClose(symbol, PERIOD_CURRENT, i) - iOpen(symbol, PERIOD_CURRENT, i));
      double range = iHigh(symbol, PERIOD_CURRENT, i) - iLow(symbol, PERIOD_CURRENT, i);
      bodySum += body;
      rangeSum += range;
   }
   double bodyRatio = (rangeSum > 0) ? bodySum / rangeSum : 0.5;
   double rangeRatio = atr14 / atr50;
   
    g_volHistory[idx].symbol = sym;

    if(g_volHistory[idx].sampleCount > 0) {
      double alpha = 0.1; // Facteur de lissage
      g_volHistory[idx].atr14 = g_volHistory[idx].atr14 * (1 - alpha) + atr14 * alpha;
      g_volHistory[idx].atr50 = g_volHistory[idx].atr50 * (1 - alpha) + atr50 * alpha;
      g_volHistory[idx].atr200 = g_volHistory[idx].atr200 * (1 - alpha) + atr200 * alpha;
      g_volHistory[idx].bodyRatioAvg = g_volHistory[idx].bodyRatioAvg * (1 - alpha) + bodyRatio * alpha;
      g_volHistory[idx].rangeRatioAvg = g_volHistory[idx].rangeRatioAvg * (1 - alpha) + rangeRatio * alpha;
   } else {
      g_volHistory[idx].atr14 = atr14;
      g_volHistory[idx].atr50 = atr50;
      g_volHistory[idx].atr200 = atr200;
      g_volHistory[idx].bodyRatioAvg = bodyRatio;
      g_volHistory[idx].rangeRatioAvg = rangeRatio;
   }
   
   g_volHistory[idx].sampleCount++;
}

// ── Obtenir l'historique de volatilité pour un symbole ──────────────────────
SMC_VolatilityHistory SMC_AI_GetVolatilityHistory(const string symbol)
{
   SMC_VolatilityHistory empty;
   ZeroMemory(empty);
   string sym = symbol;
   StringToUpper(sym);
   
   for(int i = 0; i < g_volHistoryCount; i++) {
      if(StringFind(g_volHistory[i].symbol, sym) >= 0) {
         return g_volHistory[i];
      }
   }
   
   return empty;
}

// ── Vérifier si le GOM est valide avec seuil adaptatif ────────────────────
bool SMC_AI_GOMValidatesAdaptive(const string symbol, const int gomNum)
{
   double adaptiveThreshold = SMC_AI_AdaptiveGOMThreshold(symbol);
   return (MathAbs(gomNum) >= adaptiveThreshold);
}

// ── Calculer le multiplicateur de volatilité pour SL/TP ─────────────────────
double SMC_AI_VolatilityMultiplier(const string symbol)
{
   SMC_AdaptiveConfig cfg = SMC_AI_GetConfig(symbol);
   SMC_VolatilityHistory vol = SMC_AI_GetVolatilityHistory(symbol);
   
   double multiplier = cfg.volatilityMultiplier;
   
   // Ajustement dynamique basé sur la volatilité actuelle vs historique
   if(vol.sampleCount > 10) {
      double volRatio = vol.atr14 / vol.atr50;
      if(volRatio > 1.5) multiplier *= 1.3; // Volatilité élevée
      else if(volRatio < 0.7) multiplier *= 0.8; // Volatilité faible
   }
   
   return multiplier;
}

// ── Vérifier si le nombre minimum de bougies est respecté ─────────────────
bool SMC_AI_MinBarsForEntry(const string symbol, const int barsSinceSignal)
{
   SMC_AdaptiveConfig cfg = SMC_AI_GetConfig(symbol);
   return (barsSinceSignal >= cfg.minBarsForEntry);
}

// ── Obtenir le bonus de poids pour les patterns SMC ────────────────────────
double SMC_AI_PatternWeightBonus(const string symbol)
{
   SMC_AdaptiveConfig cfg = SMC_AI_GetConfig(symbol);
   return cfg.patternWeightBonus;
}

// ── Vérifier si le trading par grid est autorisé (TOUJOURS FALSE pour sécurité) ───
bool SMC_AI_AllowGridTrading(const string symbol)
{
   SMC_AdaptiveConfig cfg = SMC_AI_GetConfig(symbol);
   return cfg.allowGridTrading; // Toujours false par défaut
}

void SMC_AI_Deinit()
{
   g_volHistoryCount = 0;
   for(int i = 0; i < 64; i++)
   {
      g_volHistory[i].symbol = "";
      g_volHistory[i].atr14 = 0;
      g_volHistory[i].sampleCount = 0;
   }
}

#endif
