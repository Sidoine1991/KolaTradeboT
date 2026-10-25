//+------------------------------------------------------------------+
//| SMC_PriceSensitivity.mqh                                           |
//| Module de sensibilité du prix pour décisions d'entrée            |
//| Intègre les indicateurs de sensibilité du prix actuel            |
//|                                                                   |
//| HOTFIX 2026-09-15 (v1.00):                                        |
//|  - Création du module                                             |
//|  - Calcul de momentum M1/M5                                      |
//|  - Détection de compression de volatilité                        |
//|  - Détection de volume spike                                      |
//|  - Filtrage des entrées sur prix plat                            |
//|  - Validation de sensibilité avant entrée                        |
//+------------------------------------------------------------------+
#ifndef SMC_PRICE_SENSITIVITY_MQH
#define SMC_PRICE_SENSITIVITY_MQH

#include <Indicators\Indicators.mqh>

//--- Paramètres de sensibilité (définis dans SMC_Universal.mq5)
// UsePriceSensitivityFilter defined in SMC_Universal.mq5
// MinM1MomentumThreshold defined in SMC_Universal.mq5
// MinM5MomentumThreshold defined in SMC_Universal.mq5
// VolatilityCompressionThreshold defined in SMC_Universal.mq5
// VolumeSpikeMultiplier defined in SMC_Universal.mq5
// FlatPriceMaxBars defined in SMC_Universal.mq5
// FlatPriceATRTolerance defined in SMC_Universal.mq5
// RequireVolumeConfirmation defined in SMC_Universal.mq5
// RequireCompressionForEntry defined in SMC_Universal.mq5

//--- État de sensibilité par symbole
struct PriceSensitivityState
{
   string   symbol;           // Symbole
   double   m1Momentum;        // Momentum M1 (change sur 1 bougie)
   double   m5Momentum;        // Momentum M5 (change sur 5 bougies)
   double   m15Momentum;      // Momentum M15 (change sur 15 bougies)
   double   volatilityCompression; // Compression de volatilité (0-1)
   double   volumeRatio;      // Ratio volume actuel / moyenne
   bool     volumeSpike;      // Volume spike détecté
   bool     bbSqueeze;        // Bollinger Band squeeze
   int      flatPriceBars;    // Nombre de bougies prix plat
   bool     isPriceFlat;      // Prix plat détecté
   double   priceAcceleration; // Accélération du prix
   datetime lastUpdate;      // Dernière mise à jour
};

PriceSensitivityState g_priceSensitivityStates[];
int g_priceSensitivityCount = 0;

//+------------------------------------------------------------------+
//| Trouver ou créer l'état de sensibilité pour un symbole           |
//+------------------------------------------------------------------+
int PriceSensitivity_GetStateIndex(const string symbol)
{
   for(int i = 0; i < g_priceSensitivityCount; i++)
   {
      if(g_priceSensitivityStates[i].symbol == symbol)
         return i;
   }
   
   // Créer nouvel état
   g_priceSensitivityCount++;
   ArrayResize(g_priceSensitivityStates, g_priceSensitivityCount);
   
   int idx = g_priceSensitivityCount - 1;
   g_priceSensitivityStates[idx].symbol = symbol;
   g_priceSensitivityStates[idx].m1Momentum = 0.0;
   g_priceSensitivityStates[idx].m5Momentum = 0.0;
   g_priceSensitivityStates[idx].m15Momentum = 0.0;
   g_priceSensitivityStates[idx].volatilityCompression = 0.0;
   g_priceSensitivityStates[idx].volumeRatio = 1.0;
   g_priceSensitivityStates[idx].volumeSpike = false;
   g_priceSensitivityStates[idx].bbSqueeze = false;
   g_priceSensitivityStates[idx].flatPriceBars = 0;
   g_priceSensitivityStates[idx].isPriceFlat = false;
   g_priceSensitivityStates[idx].priceAcceleration = 0.0;
   g_priceSensitivityStates[idx].lastUpdate = 0;
   
   return idx;
}

//+------------------------------------------------------------------+
//| Calculer le momentum sur N bougies                               |
//+------------------------------------------------------------------+
double CalculateMomentum(const string symbol, const ENUM_TIMEFRAMES tf, const int bars)
{
   double close[];
   ArraySetAsSeries(close, true);
   
   if(CopyClose(symbol, tf, 0, bars + 1, close) < bars + 1)
      return 0.0;
   
   double currentClose = close[0];
   double pastClose = close[bars];
   
   if(pastClose <= 0.0) return 0.0;
   
   return (currentClose - pastClose) / pastClose;
}

//+------------------------------------------------------------------+
//| Calculer l'accélération du prix                                  |
//+------------------------------------------------------------------+
double CalculatePriceAcceleration(const string symbol, const ENUM_TIMEFRAMES tf)
{
   double m1 = CalculateMomentum(symbol, tf, 1);
   double m3 = CalculateMomentum(symbol, tf, 3);
   
   return m1 - m3;
}

//+------------------------------------------------------------------+
//| Calculer la compression de volatilité (Bollinger Bands)           |
//+------------------------------------------------------------------+
double CalculateVolatilityCompression(const string symbol, const ENUM_TIMEFRAMES tf, const int period = 20)
{
   double close[];
   double bbUpper[];
   double bbLower[];
   
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(bbUpper, true);
   ArraySetAsSeries(bbLower, true);
   
   if(CopyClose(symbol, tf, 0, period + 1, close) < period + 1)
      return 0.0;
   
   // Calcul simple de compression basé sur l'écart-type
   double sum = 0.0;
   double mean = 0.0;
   for(int i = 0; i < period; i++)
   {
      mean += close[i];
   }
   mean /= period;
   
   for(int i = 0; i < period; i++)
   {
      sum += MathPow(close[i] - mean, 2);
   }
   
   double stdDev = MathSqrt(sum / period);
   double avgPrice = mean;
   
   if(avgPrice <= 0.0) return 0.0;
   
   // Compression = 1 - (stdDev/avgPrice) normalisé
   double volatilityRatio = stdDev / avgPrice;
   double compression = 1.0 - MathMin(volatilityRatio * 100.0, 1.0);
   
   return compression;
}

//+------------------------------------------------------------------+
//| Calculer le ratio de volume                                      |
//+------------------------------------------------------------------+
double CalculateVolumeRatio(const string symbol, const ENUM_TIMEFRAMES tf, const int period = 20)
{
   long volume[];
   ArraySetAsSeries(volume, true);
   
   if(CopyTickVolume(symbol, tf, 0, period + 1, volume) < period + 1)
      return 1.0;
   
   double currentVolume = (double)volume[0];
   double avgVolume = 0.0;
   
   for(int i = 1; i <= period; i++)
   {
      avgVolume += (double)volume[i];
   }
   avgVolume /= period;
   
   if(avgVolume <= 0.0) return 1.0;
   
   return currentVolume / avgVolume;
}

//+------------------------------------------------------------------+
//| Détecter si le prix est plat (faible mouvement)                 |
//+------------------------------------------------------------------+
bool DetectFlatPrice(const string symbol, const ENUM_TIMEFRAMES tf, const int maxBars, const double atrTolerance)
{
   double close[];
   double atr[];
   
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(atr, true);
   
   if(CopyClose(symbol, tf, 0, maxBars + 1, close) < maxBars + 1)
      return false;
   
   // Calculer ATR
   int atrHandlePS = iATR(symbol, tf, 14);
   if(atrHandlePS == INVALID_HANDLE) return false;
   
   if(CopyBuffer(atrHandlePS, 0, 0, 1, atr) < 1)
   {
      IndicatorRelease(atrHandlePS);
      return false;
   }
   
   double currentATR = atr[0];
   IndicatorRelease(atrHandlePS);
   
   if(currentATR <= 0.0) return false;
   
   double tolerance = currentATR * atrTolerance;
   int flatBars = 0;
   
   for(int i = 0; i < maxBars; i++)
   {
      double change = MathAbs(close[i] - close[i + 1]);
      if(change < tolerance)
         flatBars++;
      else
         break;
   }
   
   return flatBars >= maxBars;
}

//+------------------------------------------------------------------+
//| Mettre à jour l'état de sensibilité pour un symbole              |
//+------------------------------------------------------------------+
void PriceSensitivity_UpdateState(const string symbol)
{
   if(!UsePriceSensitivityFilter) return;
   
   int idx = PriceSensitivity_GetStateIndex(symbol);
   datetime now = TimeCurrent();
   
   // Limiter la fréquence de mise à jour (max 1 par seconde)
   if(now - g_priceSensitivityStates[idx].lastUpdate < 1)
      return;
   
   g_priceSensitivityStates[idx].lastUpdate = now;
   
   // Calculer les indicateurs
   g_priceSensitivityStates[idx].m1Momentum = CalculateMomentum(symbol, PERIOD_M1, 1);
   g_priceSensitivityStates[idx].m5Momentum = CalculateMomentum(symbol, PERIOD_M5, 1);
   g_priceSensitivityStates[idx].m15Momentum = CalculateMomentum(symbol, PERIOD_M15, 1);
   g_priceSensitivityStates[idx].priceAcceleration = CalculatePriceAcceleration(symbol, PERIOD_M1);
   
   g_priceSensitivityStates[idx].volatilityCompression = CalculateVolatilityCompression(symbol, PERIOD_M15);
   g_priceSensitivityStates[idx].volumeRatio = CalculateVolumeRatio(symbol, PERIOD_M1);
   g_priceSensitivityStates[idx].volumeSpike = (g_priceSensitivityStates[idx].volumeRatio >= VolumeSpikeMultiplier);
   
   // Détection squeeze (simplifiée)
   g_priceSensitivityStates[idx].bbSqueeze = (g_priceSensitivityStates[idx].volatilityCompression >= VolatilityCompressionThreshold);
   
   // Détection prix plat
   g_priceSensitivityStates[idx].isPriceFlat = DetectFlatPrice(symbol, PERIOD_M1, FlatPriceMaxBars, FlatPriceATRTolerance);
   if(g_priceSensitivityStates[idx].isPriceFlat)
      g_priceSensitivityStates[idx].flatPriceBars = FlatPriceMaxBars;
   else
      g_priceSensitivityStates[idx].flatPriceBars = 0;
}

//+------------------------------------------------------------------+
//| Vérifier si l'entrée est autorisée selon la sensibilité           |
//+------------------------------------------------------------------+
bool PriceSensitivity_AllowEntry(const string symbol, const int direction)
{
   if(!UsePriceSensitivityFilter) return true;
   
   PriceSensitivity_UpdateState(symbol);
   int idx = PriceSensitivity_GetStateIndex(symbol);
   PriceSensitivityState state = g_priceSensitivityStates[idx];
   
   // 1) Flux M1 1b+3b ne doit PAS être contre la direction (GOM figé).
   //    On n'exige plus un momentum déjà dans le sens : ça faisait chaser le spike.
   double currentMomentum = state.m1Momentum;
   double m3 = CalculateMomentum(symbol, PERIOD_M1, 3);
   if(direction > 0 && currentMomentum < 0.0 && m3 < 0.0)
   {
      Print("🚫 SENSITIVITY: M1 1b+3b dump vs BUY | symbol=", symbol,
            " | m1=", DoubleToString(currentMomentum, 6),
            " | m3=", DoubleToString(m3, 6));
      return false;
   }
   if(direction < 0 && currentMomentum > 0.0 && m3 > 0.0)
   {
      Print("🚫 SENSITIVITY: M1 1b+3b rally vs SELL | symbol=", symbol,
            " | m1=", DoubleToString(currentMomentum, 6),
            " | m3=", DoubleToString(m3, 6));
      return false;
   }
   
   // 2) Vérifier prix plat
   if(state.isPriceFlat)
   {
      Print("🚫 SENSITIVITY: Prix plat détecté | symbol=", symbol,
            " | flatBars=", state.flatPriceBars);
      return false;
   }
   
   // 3) Vérifier volume spike (si requis)
   if(RequireVolumeConfirmation && !state.volumeSpike)
   {
      // Pour les synthétiques, volume spike est moins critique
      bool isSynthetic = (StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "CRASH") >= 0 ||
                         StringFind(symbol, "PAINX") >= 0 || StringFind(symbol, "GAINX") >= 0 ||
                         StringFind(symbol, "VOL") >= 0);
      
      if(!isSynthetic)
      {
         Print("🚫 SENSITIVITY: Volume spike requis mais absent | symbol=", symbol,
               " | volumeRatio=", DoubleToString(state.volumeRatio, 2));
         return false;
      }
   }
   
   // 4) Vérifier compression (si requis)
   if(RequireCompressionForEntry && !state.bbSqueeze)
   {
      // La compression est souhaitable mais pas obligatoire pour tous les cas
      // On peut être plus permissif si le momentum est fort
      double strongMomentum = MinM1MomentumThreshold * 2.0;
      if(MathAbs(currentMomentum) < strongMomentum)
      {
         Print("⚠️ SENSITIVITY: Compression absente mais momentum faible | symbol=", symbol,
               " | compression=", DoubleToString(state.volatilityCompression, 3),
               " | momentum=", DoubleToString(currentMomentum, 6));
         // On ne bloque pas, mais on peut avertir
      }
   }
   
   // 5) Vérifier accélération (doit être dans le sens de la direction)
   if(direction > 0 && state.priceAcceleration < -MinM1MomentumThreshold * 0.5)
   {
      Print("🚫 SENSITIVITY: Accélération négative pour BUY | symbol=", symbol,
            " | acceleration=", DoubleToString(state.priceAcceleration, 6));
      return false;
   }
   
   if(direction < 0 && state.priceAcceleration > MinM1MomentumThreshold * 0.5)
   {
      Print("🚫 SENSITIVITY: Accélération positive pour SELL | symbol=", symbol,
            " | acceleration=", DoubleToString(state.priceAcceleration, 6));
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Obtenir le score de sensibilité (0-100)                           |
//+------------------------------------------------------------------+
double PriceSensitivity_GetScore(const string symbol, const int direction)
{
   if(!UsePriceSensitivityFilter) return 50.0;
   
   int idx = PriceSensitivity_GetStateIndex(symbol);
   PriceSensitivityState state = g_priceSensitivityStates[idx];
   
   double score = 50.0; // Score neutre de base
   
   // Momentum (30 points)
   double momentumScore = 0.0;
   if(direction > 0)
      momentumScore = MathMin(state.m1Momentum / MinM1MomentumThreshold, 1.0) * 30.0;
   else
      momentumScore = MathMin(-state.m1Momentum / MinM1MomentumThreshold, 1.0) * 30.0;
   score += momentumScore;
   
   // Compression (15 points)
   if(state.bbSqueeze)
      score += 15.0;
   else
      score += state.volatilityCompression * 15.0;
   
   // Volume spike (15 points)
   if(state.volumeSpike)
      score += 15.0;
   else
      score += MathMin((state.volumeRatio - 1.0) / (VolumeSpikeMultiplier - 1.0), 1.0) * 15.0;
   
   // Prix plat (pénalité -20 points)
   if(state.isPriceFlat)
      score -= 20.0;
   
   // Accélération (20 points)
   double accelScore = 0.0;
   if(direction > 0)
      accelScore = MathMin(state.priceAcceleration / MinM1MomentumThreshold, 1.0) * 20.0;
   else
      accelScore = MathMin(-state.priceAcceleration / MinM1MomentumThreshold, 1.0) * 20.0;
   score += accelScore;
   
   return MathMax(0.0, MathMin(100.0, score));
}

//+------------------------------------------------------------------+
//| Logger l'état de sensibilité (pour debug)                        |
//+------------------------------------------------------------------+
void PriceSensitivity_LogState(const string symbol)
{
   int idx = PriceSensitivity_GetStateIndex(symbol);
   PriceSensitivityState state = g_priceSensitivityStates[idx];
   
   Print("📊 SENSITIVITY STATE | symbol=", symbol,
         " | M1 momentum=", DoubleToString(state.m1Momentum, 6),
         " | M5 momentum=", DoubleToString(state.m5Momentum, 6),
         " | M15 momentum=", DoubleToString(state.m15Momentum, 6),
         " | acceleration=", DoubleToString(state.priceAcceleration, 6),
         " | compression=", DoubleToString(state.volatilityCompression, 3),
         " | volumeRatio=", DoubleToString(state.volumeRatio, 2),
         " | volumeSpike=", state.volumeSpike ? "YES" : "NO",
         " | bbSqueeze=", state.bbSqueeze ? "YES" : "NO",
         " | isPriceFlat=", state.isPriceFlat ? "YES" : "NO",
         " | flatBars=", state.flatPriceBars);
}

//+------------------------------------------------------------------+
//| Nettoyer les états obsolètes                                      |
//+------------------------------------------------------------------+
void PriceSensitivity_Cleanup()
{
   datetime now = TimeCurrent();
   for(int i = g_priceSensitivityCount - 1; i >= 0; i--)
   {
      // Supprimer les états non mis à jour depuis 5 minutes
      if(now - g_priceSensitivityStates[i].lastUpdate > 300)
      {
         for(int j = i; j < g_priceSensitivityCount - 1; j++)
            g_priceSensitivityStates[j] = g_priceSensitivityStates[j + 1];
         g_priceSensitivityCount--;
         ArrayResize(g_priceSensitivityStates, g_priceSensitivityCount);
      }
   }
}

#endif // SMC_PRICE_SENSITIVITY_MQH
