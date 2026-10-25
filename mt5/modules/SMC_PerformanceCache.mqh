//+------------------------------------------------------------------+
//| SMC_PerformanceCache.mqh - Cache de données pour optimisation      |
//| FIX 2026-09-20 (Sidoine) : Réduit les appels CopyBuffer/CopyRates    |
//| en mettant en cache les valeurs fréquemment utilisées               |
//+------------------------------------------------------------------+
// Structure de cache pour un symbole
struct SymbolDataCache
{
   datetime lastUpdate;
   
   // ATR values
   double atrM1;
   double atrM5;
   double atrH1;
   double atrH4;
   
   // EMA values (M1)
   double emaFastM1;
   double emaSlowM1;
   
   // EMA values (M5)
   double emaFastM5;
   double emaSlowM5;
   
   // EMA values (H1)
   double emaFastH1;
   double emaSlowH1;
   
   // Volatility
   double volatilityM1;
   
   // Flags de validité
   bool atrM1Valid;
   bool atrM5Valid;
   bool atrH1Valid;
   bool atrH4Valid;
   bool emaFastM1Valid;
   bool emaSlowM1Valid;
   bool emaFastM5Valid;
   bool emaSlowM5Valid;
   bool emaFastH1Valid;
   bool emaSlowH1Valid;
   bool volatilityM1Valid;
   
   void Reset()
   {
      lastUpdate = 0;
      atrM1 = 0; atrM5 = 0; atrH1 = 0; atrH4 = 0;
      emaFastM1 = 0; emaSlowM1 = 0;
      emaFastM5 = 0; emaSlowM5 = 0;
      emaFastH1 = 0; emaSlowH1 = 0;
      volatilityM1 = 0;
      
      atrM1Valid = false; atrM5Valid = false; atrH1Valid = false; atrH4Valid = false;
      emaFastM1Valid = false; emaSlowM1Valid = false;
      emaFastM5Valid = false; emaSlowM5Valid = false;
      emaFastH1Valid = false; emaSlowH1Valid = false;
      volatilityM1Valid = false;
   }
};

// Cache global par symbole
static SymbolDataCache g_dataCache[10];  // Max 10 symboles
static string g_cachedSymbols[10];
static int g_cachedSymbolCount = 0;

//+------------------------------------------------------------------+
//| Initialiser le cache                                               |
//+------------------------------------------------------------------+
void SMC_PC_Init()
{
   for(int i = 0; i < 10; i++)
   {
      g_dataCache[i].Reset();
      g_cachedSymbols[i] = "";
   }
   g_cachedSymbolCount = 0;
   Print("🚀 PERFORMANCE CACHE - Initialisé");
}

//+------------------------------------------------------------------+
//| Nettoyer le cache                                                   |
//+------------------------------------------------------------------+
void SMC_PC_Deinit()
{
   for(int i = 0; i < 10; i++)
   {
      g_dataCache[i].Reset();
      g_cachedSymbols[i] = "";
   }
   g_cachedSymbolCount = 0;
   Print("🚀 PERFORMANCE CACHE - Nettoyé");
}

//+------------------------------------------------------------------+
//| Obtenir l'index du cache pour un symbole                          |
//+------------------------------------------------------------------+
int SMC_PC_GetCacheIndex(const string symbol)
{
   // Chercher si le symbole est déjà dans le cache
   for(int i = 0; i < g_cachedSymbolCount; i++)
   {
      if(g_cachedSymbols[i] == symbol)
         return i;
   }
   
   // Ajouter le symbole au cache si de la place
   if(g_cachedSymbolCount < 10)
   {
      int idx = g_cachedSymbolCount;
      g_cachedSymbols[idx] = symbol;
      g_cachedSymbolCount++;
      return idx;
   }
   
   // Cache plein - utiliser le premier (LRU simple)
   return 0;
}

//+------------------------------------------------------------------+
//| Mettre à jour le cache pour un symbole                             |
//+------------------------------------------------------------------+
void SMC_PC_UpdateCache(const string symbol)
{
   int idx = SMC_PC_GetCacheIndex(symbol);

   // Mettre à jour seulement si nécessaire (max 1x par seconde)
   datetime currentTime = TimeCurrent();
   if(currentTime - g_dataCache[idx].lastUpdate < 1) return;
   
   // Récupérer ATR M1
   if(atrM1 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(atrM1, 0, 0, 1, buf) >= 1)
      {
         g_dataCache[idx].atrM1 = buf[0];
         g_dataCache[idx].atrM1Valid = true;
      }
   }
   
   // Récupérer ATR M5
   if(atrM5 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(atrM5, 0, 0, 1, buf) >= 1)
      {
         g_dataCache[idx].atrM5 = buf[0];
         g_dataCache[idx].atrM5Valid = true;
      }
   }
   
   // Récupérer ATR H1
   if(atrH1 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(atrH1, 0, 0, 1, buf) >= 1)
      {
         g_dataCache[idx].atrH1 = buf[0];
         g_dataCache[idx].atrH1Valid = true;
      }
   }
   
   // Récupérer ATR H4
   if(atrH4 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(atrH4, 0, 0, 1, buf) >= 1)
      {
         g_dataCache[idx].atrH4 = buf[0];
         g_dataCache[idx].atrH4Valid = true;
      }
   }
   
   // Récupérer EMA Fast M1
   if(emaFastM1 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(emaFastM1, 0, 0, 1, buf) >= 1)
      {
         g_dataCache[idx].emaFastM1 = buf[0];
         g_dataCache[idx].emaFastM1Valid = true;
      }
   }
   
   // Récupérer EMA Slow M1
   if(emaSlowM1 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(emaSlowM1, 0, 0, 1, buf) >= 1)
      {
         g_dataCache[idx].emaSlowM1 = buf[0];
         g_dataCache[idx].emaSlowM1Valid = true;
      }
   }
   
   // Récupérer EMA Fast M5
   if(emaFastM5 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(emaFastM5, 0, 0, 1, buf) >= 1)
      {
         g_dataCache[idx].emaFastM5 = buf[0];
         g_dataCache[idx].emaFastM5Valid = true;
      }
   }
   
   // Récupérer EMA Slow M5
   if(emaSlowM5 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(emaSlowM5, 0, 0, 1, buf) >= 1)
      {
         g_dataCache[idx].emaSlowM5 = buf[0];
         g_dataCache[idx].emaSlowM5Valid = true;
      }
   }
   
   // Récupérer EMA Fast H1
   if(emaFastH1 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(emaFastH1, 0, 0, 1, buf) >= 1)
      {
         g_dataCache[idx].emaFastH1 = buf[0];
         g_dataCache[idx].emaFastH1Valid = true;
      }
   }
   
   // Récupérer EMA Slow H1
   if(emaSlowH1 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(emaSlowH1, 0, 0, 1, buf) >= 1)
      {
         g_dataCache[idx].emaSlowH1 = buf[0];
         g_dataCache[idx].emaSlowH1Valid = true;
      }
   }
   
   // Calculer volatilité M1
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 20, rates) >= 20)
   {
      double sum = 0;
      for(int i = 0; i < 20; i++)
         sum += (rates[i].high - rates[i].low);
      g_dataCache[idx].volatilityM1 = sum / 20;
      g_dataCache[idx].volatilityM1Valid = true;
   }
   
   g_dataCache[idx].lastUpdate = currentTime;
}

//+------------------------------------------------------------------+
//| Obtenir ATR M1 depuis le cache                                     |
//+------------------------------------------------------------------+
double SMC_PC_GetATR_M1(const string symbol)
{
   int idx = SMC_PC_GetCacheIndex(symbol);
   
   
   if(!g_dataCache[idx].atrM1Valid)
      SMC_PC_UpdateCache(symbol);
   
   return g_dataCache[idx].atrM1;
}

//+------------------------------------------------------------------+
//| Obtenir ATR M5 depuis le cache                                     |
//+------------------------------------------------------------------+
double SMC_PC_GetATR_M5(const string symbol)
{
   int idx = SMC_PC_GetCacheIndex(symbol);
   
   
   if(!g_dataCache[idx].atrM5Valid)
      SMC_PC_UpdateCache(symbol);
   
   return g_dataCache[idx].atrM5;
}

//+------------------------------------------------------------------+
//| Obtenir ATR H1 depuis le cache                                     |
//+------------------------------------------------------------------+
double SMC_PC_GetATR_H1(const string symbol)
{
   int idx = SMC_PC_GetCacheIndex(symbol);
   
   
   if(!g_dataCache[idx].atrH1Valid)
      SMC_PC_UpdateCache(symbol);
   
   return g_dataCache[idx].atrH1;
}

//+------------------------------------------------------------------+
//| Obtenir EMA Fast M1 depuis le cache                                |
//+------------------------------------------------------------------+
double SMC_PC_GetEMA_Fast_M1(const string symbol)
{
   int idx = SMC_PC_GetCacheIndex(symbol);
   
   
   if(!g_dataCache[idx].emaFastM1Valid)
      SMC_PC_UpdateCache(symbol);
   
   return g_dataCache[idx].emaFastM1;
}

//+------------------------------------------------------------------+
//| Obtenir EMA Slow M1 depuis le cache                                |
//+------------------------------------------------------------------+
double SMC_PC_GetEMA_Slow_M1(const string symbol)
{
   int idx = SMC_PC_GetCacheIndex(symbol);
   
   
   if(!g_dataCache[idx].emaSlowM1Valid)
      SMC_PC_UpdateCache(symbol);
   
   return g_dataCache[idx].emaSlowM1;
}

//+------------------------------------------------------------------+
//| Obtenir EMA Fast M5 depuis le cache                                |
//+------------------------------------------------------------------+
double SMC_PC_GetEMA_Fast_M5(const string symbol)
{
   int idx = SMC_PC_GetCacheIndex(symbol);
   
   
   if(!g_dataCache[idx].emaFastM5Valid)
      SMC_PC_UpdateCache(symbol);
   
   return g_dataCache[idx].emaFastM5;
}

//+------------------------------------------------------------------+
//| Obtenir EMA Slow M5 depuis le cache                                |
//+------------------------------------------------------------------+
double SMC_PC_GetEMA_Slow_M5(const string symbol)
{
   int idx = SMC_PC_GetCacheIndex(symbol);
   
   
   if(!g_dataCache[idx].emaSlowM5Valid)
      SMC_PC_UpdateCache(symbol);
   
   return g_dataCache[idx].emaSlowM5;
}

//+------------------------------------------------------------------+
//| Obtenir volatilité M1 depuis le cache                              |
//+------------------------------------------------------------------+
double SMC_PC_GetVolatility_M1(const string symbol)
{
   int idx = SMC_PC_GetCacheIndex(symbol);
   
   
   if(!g_dataCache[idx].volatilityM1Valid)
      SMC_PC_UpdateCache(symbol);
   
   return g_dataCache[idx].volatilityM1;
}
