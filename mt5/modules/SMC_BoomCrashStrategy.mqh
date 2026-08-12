//+------------------------------------------------------------------+
//| SMC_BoomCrashStrategy.mqh - Stratégies unifiées Boom/Crash/PainX/GainX |
//| Intègre: Post-Spike Recovery, Tightening Range, Acceleration Pattern,|
//| RSI Divergence, Spike Zones - système de décision unifié              |
//+------------------------------------------------------------------+
#ifndef SMC_BOOM_CRASH_STRATEGY_MQH
#define SMC_BOOM_CRASH_STRATEGY_MQH

#include "SMC_PostSpikeRecovery.mqh"
#include "SMC_TighteningRange.mqh"
#include "SMC_AccelPattern.mqh"
#include "SMC_RSIDivergence.mqh"
#include "SMC_SpikeZones.mqh"
#include "SMC_SecondSpikePredictor.mqh"

enum ENUM_BC_STRATEGY
{
   BC_STRATEGY_NONE,
   BC_STRATEGY_TREND_FOLLOW,      // Trend following entre spikes
   BC_STRATEGY_POST_SPIKE_REC,     // Post-spike recovery
   BC_STRATEGY_RSI_DIV,           // RSI divergence
   BC_STRATEGY_ZONE_BASED,        // Zone-based trading
   BC_STRATEGY_COMPRESSION_AVOID  // Éviter compression pré-spike
};

struct SMC_BC_TradeSetup
{
   ENUM_BC_STRATEGY strategy;
   int      dirSign;              // +1 BUY, -1 SELL
   double   entryPrice;
   double   sl;
   double   tp1;
   double   tp2;
   double   tp3;
   double   confidence;           // 0-100
   double   positionSizeMult;     // multiplicateur taille position
   string   reason;
   bool     shouldBlock;          // true = bloquer l'entrée
};

SMC_BC_TradeSetup g_bcSetup;

//+------------------------------------------------------------------+
//| Initialiser le système de stratégies Boom/Crash                     |
//+------------------------------------------------------------------+
void SMC_BC_Init()
{
   SMC_PSR_Init();
   SMC_TR_Init();
   SMC_AP_Init();
   SMC_RD_Init();
   SMC_SZ_Init();
   SMC_SSP_Init();
   ZeroMemory(g_bcSetup);
}

//+------------------------------------------------------------------+
//| Mettre à jour les états internes (à appeler chaque tick)            |
//+------------------------------------------------------------------+
void SMC_BC_Update(const string symbol)
{
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // Mettre à jour le compteur de bougies post-spike
   SMC_PSR_UpdateBars();
   
   // Mettre à jour le prédicteur de second spike
   SMC_SSP_Update(symbol, currentPrice);
   
   // Vérifier expiration post-spike
   SMC_PSR_CheckExpiry(10);
   
   // Nettoyer les zones inactives
   SMC_SZ_CleanupInactiveZones();
   
   // Mettre à jour les patterns
   SMC_TR_IsTighteningRange(symbol);
   SMC_AP_IsAccelerationPattern(symbol);
}

//+------------------------------------------------------------------+
//| Générer un setup de trading selon les conditions actuelles            |
//+------------------------------------------------------------------+
SMC_BC_TradeSetup SMC_BC_GenerateSetup(const string symbol, const int requestedDir = 0)
{
   SMC_BC_TradeSetup setup;
   ZeroMemory(setup);
   setup.positionSizeMult = 1.0;
   setup.confidence = 0.0;
   setup.shouldBlock = false;
   
   bool isCrash = IsCrashLikeSymbol(symbol);
   int creepDir = isCrash ? 1 : -1;  // Crash=BUY, Boom=SELL
   
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // --- PRIORITÉ 1: Vérifier les filtres de RISQUE ---
   
   // Compression élevée = bloquer
   if(SMC_TR_ShouldBlockEntry(60))
   {
      setup.strategy = BC_STRATEGY_COMPRESSION_AVOID;
      setup.shouldBlock = true;
      setup.confidence = 0.0;
      setup.reason = "Compression élevée - blocage";
      setup.positionSizeMult = SMC_TR_GetPositionSizeMultiplier();
      Print("[BC] BLOCAGE - Compression: ", SMC_TR_GetCompressionRiskLevel(), "%");
      return setup;
   }
   
   // Accélération élevée = bloquer
   if(SMC_AP_ShouldBlockEntry(50))
   {
      setup.strategy = BC_STRATEGY_COMPRESSION_AVOID;
      setup.shouldBlock = true;
      setup.confidence = 0.0;
      setup.reason = "Accélération élevée - blocage";
      setup.positionSizeMult = SMC_AP_GetPositionSizeMultiplier();
      Print("[BC] BLOCAGE - Accélération: ", SMC_AP_GetAccelerationRiskLevel(), "%");
      return setup;
   }
   
   // Près d'une zone de spike à haute fréquence = réduire
   double zoneRisk = SMC_SZ_GetZoneRiskLevel(currentPrice);
   if(zoneRisk > 60)
   {
      setup.positionSizeMult *= SMC_SZ_GetPositionSizeMultiplier(currentPrice);
      Print("[BC] Réduction position - Zone spike: ", DoubleToString(zoneRisk, 1), "%");
   }
   
   // --- PRIORITÉ 2: Stratégies d'entrée ---
   
   // RSI Divergence = haute priorité
   int divDir = SMC_RD_GetDivergenceType();
   if(divDir != 0 && (requestedDir == 0 || requestedDir == divDir))
   {
      setup.strategy = BC_STRATEGY_RSI_DIV;
      setup.dirSign = divDir;
      setup.confidence = 75.0 + SMC_RD_GetConfidenceBonus();
      setup.reason = "RSI Divergence";
      setup.positionSizeMult *= SMC_RD_GetPositionSizeMultiplier();
      Print("[BC] SETUP RSI Divergence: ", divDir > 0 ? "BUY" : "SELL", " | conf=", 
            DoubleToString(setup.confidence, 1));
      return setup;
   }
   
   // Post-Spike Recovery = haute priorité
   if(SMC_PSR_AllowsEntry(symbol, creepDir))
   {
      setup.strategy = BC_STRATEGY_POST_SPIKE_REC;
      setup.dirSign = creepDir;
      setup.confidence = 85.0;
      setup.reason = "Post-Spike Recovery (force=" + DoubleToString(SMC_PSR_GetRecoveryStrength(), 1) + ")";
      Print("[BC] SETUP Post-Spike Recovery: ", creepDir > 0 ? "BUY" : "SELL", 
            " | force=", DoubleToString(SMC_PSR_GetRecoveryStrength(), 1));
      return setup;
   }
   
   // Trend Following = stratégie par défaut (si pas de risque)
   if(!SMC_TR_IsTighteningRange(symbol) && !SMC_AP_IsAccelerationPattern(symbol))
   {
      setup.strategy = BC_STRATEGY_TREND_FOLLOW;
      setup.dirSign = creepDir;
      setup.confidence = 65.0;
      setup.reason = "Trend Following (pas de compression/accélération)";
      Print("[BC] SETUP Trend Follow: ", creepDir > 0 ? "BUY" : "SELL");
      return setup;
   }
   
   // Sinon = pas de setup favorable
   setup.strategy = BC_STRATEGY_NONE;
   setup.confidence = 0.0;
   setup.reason = "Aucun setup favorable";
   
   return setup;
}

//+------------------------------------------------------------------+
//| Enregistrer un spike détecté dans le système                         |
//+------------------------------------------------------------------+
void SMC_BC_RegisterSpike(const double price, const int direction)
{
   SMC_PSR_RegisterSpike(price, direction);
   SMC_SZ_RegisterSpike(price, MathAbs(price - SymbolInfoDouble(_Symbol, SYMBOL_BID)));
   
   // Si c'est le premier spike capturé pour une position active
   if(SMC_SSP_ShouldWaitSecondSpike())
   {
      SMC_SSP_RegisterFirstSpike(price, price, direction);
   }
}

//+------------------------------------------------------------------+
//| Vérifier si on doit attendre le second spike (bloquer fermeture)     |
//+------------------------------------------------------------------+
bool SMC_BC_ShouldWaitSecondSpike()
{
   return SMC_SSP_ShouldWaitSecondSpike();
}

//+------------------------------------------------------------------+
//| Enregistrer la détection d'un second spike                          |
//+------------------------------------------------------------------+
void SMC_BC_RegisterSecondSpike(const double price)
{
   SMC_SSP_RegisterSecondSpike(price);
}

//+------------------------------------------------------------------+
//| Réinitialiser le système de second spike après fermeture               |
//+------------------------------------------------------------------+
void SMC_BC_ResetSecondSpike()
{
   SMC_SSP_Reset();
}

//+------------------------------------------------------------------+
//| Obtenir le multiplicateur de TP pour second spike                      |
//+------------------------------------------------------------------+
double SMC_BC_GetSecondSpikeTPMult()
{
   if(SMC_SSP_ShouldWaitSecondSpike())
      return SMC_SSP_GetSecondSpikeTPMult();
   return 1.0;
}

//+------------------------------------------------------------------+
//| Obtenir le multiplicateur de taille de position combiné                |
//+------------------------------------------------------------------+
double SMC_BC_GetCombinedPositionSizeMult(const string symbol)
{
   double mult = 1.0;
   
   // Compression
   mult *= SMC_TR_GetPositionSizeMultiplier();
   
   // Accélération
   mult *= SMC_AP_GetPositionSizeMultiplier();
   
   // Zones de spike
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   mult *= SMC_SZ_GetPositionSizeMultiplier(price);
   
   // RSI Divergence (bonus positif)
   mult *= SMC_RD_GetPositionSizeMultiplier();
   
   return MathMax(0.25, MathMin(1.5, mult));  // Limiter entre 25% et 150%
}

//+------------------------------------------------------------------+
//| Obtenir le multiplicateur de TP combiné                              |
//+------------------------------------------------------------------+
double SMC_BC_GetCombinedTPMult()
{
   double mult = 1.0;
   
   // Réduire TP en cas d'accélération
   mult *= SMC_AP_GetTakeProfitMultiplier();
   
   // Si on attend le second spike, utiliser un TP plus agressif
   mult *= SMC_BC_GetSecondSpikeTPMult();
   
   return MathMax(0.5, MathMin(1.5, mult));
}

//+------------------------------------------------------------------+
//| Afficher l'état du système de stratégies (debug)                      |
//+------------------------------------------------------------------+
void SMC_BC_PrintState(const string symbol)
{
   Print("=== BC STRATEGY STATE ===");
   Print("Post-Spike: bars=", SMC_PSR_GetBarsSinceSpike(), 
         " confirmed=", SMC_PSR_AllowsEntry(symbol, 0) ? "YES" : "NO");
   Print("Tightening: ", g_tighteningRange.isTightening ? "YES" : "NO",
         " risk=", DoubleToString(SMC_TR_GetCompressionRiskLevel(), 1), "%");
   Print("Acceleration: ", g_accelPattern.isAccelerating ? "YES" : "NO",
         " risk=", DoubleToString(SMC_AP_GetAccelerationRiskLevel(), 1), "%");
   Print("RSI Div: type=", SMC_RD_GetDivergenceType(),
         " strength=", DoubleToString(SMC_RD_GetDivergenceStrength(), 1));
   Print("Zones: count=", g_spikeZoneCount);
   Print("========================");
}

#endif // SMC_BOOM_CRASH_STRATEGY_MQH
