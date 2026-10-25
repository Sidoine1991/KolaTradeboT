//+------------------------------------------------------------------+
//|                                        SpikeHunter_Light_EA.mq5 |
//|                        Copyright 2025, TradBOT Spike Hunter EA   |
//|                                    Version Allégée et Optimisée   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, TradBOT Spike Hunter EA"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property description "Robot de trading automatique LÉGER pour capturer les spikes Boom/Crash"

//--- Paramètres d'entrée essentiels
input group "=== CONFIGURATION GÉNÉRALE ==="
input bool     InpEnableTrading = true;           // Activer le trading AUTONOME
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M1;   // Timeframe d'analyse
input int      InpMagicNumber = 123456;           // Magic Number
input double   InpUserCapital = 50.0;             // Capital utilisateur ($)

input group "=== OPTIMISATIONS MT5 ==="
input bool     InpOptimizeForMT5 = true;          // Activer optimisations MT5
input int      InpApiCallInterval = 10;           // Intervalle appels API (secondes)
input int      InpCacheDuration = 60;             // Durée cache (secondes)
input bool     InpUseBatchProcessing = true;      // Traitement en batch
input int      InpBatchSize = 2;                  // Taille des batches
input bool     InpReduceApiCalls = true;          // Réduire appels API
input bool     InpUseLazyLoading = true;         // Chargement paresseux

input group "=== TRADING OPTIMISÉ ==="
input int      InpMaxSymbolsToScan = 3;           // Max symboles à scanner (réduit)
input int      InpScanInterval = 30;              // Intervalle scan (30s)
input bool     InpUseSmartCaching = true;         // Cache intelligent
input int      InpMaxConcurrentTrades = 2;        // Max trades simultanés (réduit)
input bool     InpOptimizeMemoryUsage = true;     // Optimisation mémoire
input bool     InpThrottleCPUUsage = true;       // Réduction charge CPU

input group "=== PARAMÈTRES DE TRADING ==="
input string   InpSymbolsToTrade = "Crash 1000 Index, Boom 1000 Index"; // Symboles prioritaires
input double   InpBaseLotSize = 0.1;              // Taille de base des lots
input int      InpStopLoss = 8;                   // Stop Loss en points
input int      InpTakeProfit = 12;                // Take Profit en points
input double   InpRiskPercent = 2.0;               // Pourcentage de risque par trade (%)

input group "=== SURVEILLANCE OPTIMISÉE ==="
input int      InpHeavyTaskIntervalSec = 10;      // Intervalle tâches lourdes (10s)
input int      InpNetTrendCacheSec = 60;          // Cache API tendance (60s)
input int      InpUIUpdateIntervalSec = 5;        // Intervalle UI (5s)
input int      InpLogVerbosity = 0;               // Logs minimaux
input bool     InpLazyInitialization = true;     // Initialisation paresseuse
input int      InpStartupDelaySec = 5;            // Délai démarrage (5s)

input group "=== NOTIFICATIONS ==="
input bool     InpSendNotifications = true;       // Envoyer des notifications

//--- Variables globales optimisées
string g_symbols[];
int g_symbol_count = 0;
datetime g_last_api_call = 0;
datetime g_last_scan = 0;
datetime g_last_ui_update = 0;
datetime g_last_heavy_task = 0;
datetime g_startup_time = 0;

// Cache optimisé
struct TrendCache {
    string symbol;
    datetime timestamp;
    string trend_direction;
    int trend_strength;
    string confidence;
    string trading_signal;
    double spike_probability;
    int time_to_spike;
    double stop_loss;
    double take_profit;
    double lot_size;
    string reasoning;
};

TrendCache g_trend_cache[10]; // Cache limité à 10 entrées
int g_cache_size = 0;

// Variables de performance
int g_api_calls_reduced = 0;
int g_cache_hits = 0;
int g_cache_misses = 0;
int g_batch_operations = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 Initialisation SpikeHunter Light EA v2.00");
    
    // Délai de démarrage pour éviter la surcharge
    if(InpStartupDelaySec > 0) {
        Sleep(InpStartupDelaySec * 1000);
    }
    
    g_startup_time = TimeCurrent();
    
    // Initialisation paresseuse
    if(InpLazyInitialization) {
        Print("⚡ Mode initialisation paresseuse activé");
        return InitializeLazy();
    }
    
    return InitializeFull();
}

//+------------------------------------------------------------------+
//| Initialisation paresseuse                                        |
//+------------------------------------------------------------------+
int InitializeLazy()
{
    Print("📦 Initialisation paresseuse en cours...");
    
    // Initialiser seulement les éléments essentiels
    if(!InitializeSymbols()) {
        Print("❌ Erreur initialisation symboles");
        return INIT_FAILED;
    }
    
    // Initialiser le cache
    InitializeCache();
    
    Print("✅ Initialisation paresseuse terminée");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Initialisation complète                                          |
//+------------------------------------------------------------------+
int InitializeFull()
{
    Print("🔧 Initialisation complète en cours...");
    
    // Initialiser les symboles
    if(!InitializeSymbols()) {
        Print("❌ Erreur initialisation symboles");
        return INIT_FAILED;
    }
    
    // Initialiser le cache
    InitializeCache();
    
    // Initialiser les optimisations MT5
    if(InpOptimizeForMT5) {
        InitializeMT5Optimizations();
    }
    
    Print("✅ Initialisation complète terminée");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Initialiser les symboles                                         |
//+------------------------------------------------------------------+
bool InitializeSymbols()
{
    // Parser les symboles depuis la chaîne d'entrée
    string symbols_str = InpSymbolsToTrade;
    string sep = ",";
    ushort u_sep = StringGetCharacter(sep, 0);
    
    g_symbol_count = StringSplit(symbols_str, u_sep, g_symbols);
    
    // Limiter le nombre de symboles selon l'optimisation
    if(InpOptimizeForMT5 && g_symbol_count > InpMaxSymbolsToScan) {
        g_symbol_count = InpMaxSymbolsToScan;
        Print("⚡ Symboles limités à ", g_symbol_count, " pour optimisation MT5");
    }
    
    Print("📊 Symboles configurés: ", g_symbol_count);
    for(int i = 0; i < g_symbol_count; i++) {
        Print("   ", i+1, ". ", g_symbols[i]);
    }
    
    return g_symbol_count > 0;
}

//+------------------------------------------------------------------+
//| Initialiser le cache                                             |
//+------------------------------------------------------------------+
void InitializeCache()
{
    g_cache_size = 0;
    for(int i = 0; i < 10; i++) {
        g_trend_cache[i].symbol = "";
        g_trend_cache[i].timestamp = 0;
    }
    Print("📦 Cache initialisé");
}

//+------------------------------------------------------------------+
//| Initialiser les optimisations MT5                               |
//+------------------------------------------------------------------+
void InitializeMT5Optimizations()
{
    Print("⚡ Optimisations MT5 activées:");
    Print("   - Cache: ", InpCacheDuration, "s");
    Print("   - Intervalle API: ", InpApiCallInterval, "s");
    Print("   - Taille batch: ", InpBatchSize);
    Print("   - Réduction appels API: ", InpReduceApiCalls ? "Activée" : "Désactivée");
    Print("   - Optimisation mémoire: ", InpOptimizeMemoryUsage ? "Activée" : "Désactivée");
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🛑 Arrêt SpikeHunter Light EA");
    Print("📈 Statistiques finales:");
    Print("   - Appels API réduits: ", g_api_calls_reduced);
    Print("   - Cache hits: ", g_cache_hits);
    Print("   - Cache misses: ", g_cache_misses);
    Print("   - Opérations batch: ", g_batch_operations);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Optimisation CPU - pause adaptative
    if(InpThrottleCPUUsage) {
        Sleep(50); // 50ms de pause
    }
    
    // Vérifier si on peut faire des tâches lourdes
    if(!CanPerformHeavyTask()) {
        return;
    }
    
    // Traitement principal optimisé
    ProcessOptimizedTrading();
}

//+------------------------------------------------------------------+
//| Vérifier si on peut faire des tâches lourdes                    |
//+------------------------------------------------------------------+
bool CanPerformHeavyTask()
{
    datetime current_time = TimeCurrent();
    
    // Vérifier l'intervalle des tâches lourdes
    if(current_time - g_last_heavy_task < InpHeavyTaskIntervalSec) {
        return false;
    }
    
    g_last_heavy_task = current_time;
    return true;
}

//+------------------------------------------------------------------+
//| Traitement principal optimisé                                    |
//+------------------------------------------------------------------+
void ProcessOptimizedTrading()
{
    // Vérifier l'intervalle de scan
    if(TimeCurrent() - g_last_scan < InpScanInterval) {
        return;
    }
    
    g_last_scan = TimeCurrent();
    
    // Traitement en batch si activé
    if(InpUseBatchProcessing) {
        ProcessBatchTrading();
    } else {
        ProcessIndividualTrading();
    }
    
    // Nettoyer le cache si nécessaire
    if(InpOptimizeMemoryUsage) {
        CleanupCache();
    }
}

//+------------------------------------------------------------------+
//| Traitement en batch                                              |
//+------------------------------------------------------------------+
void ProcessBatchTrading()
{
    Print("📦 Traitement en batch de ", g_symbol_count, " symboles");
    
    for(int i = 0; i < g_symbol_count; i += InpBatchSize) {
        // Traiter un batch
        int batch_end = MathMin(i + InpBatchSize, g_symbol_count);
        
        for(int j = i; j < batch_end; j++) {
            ProcessSymbol(g_symbols[j]);
        }
        
        // Pause entre les batches
        if(batch_end < g_symbol_count) {
            Sleep(100); // 100ms de pause
        }
    }
    
    g_batch_operations++;
}

//+------------------------------------------------------------------+
//| Traitement individuel                                           |
//+------------------------------------------------------------------+
void ProcessIndividualTrading()
{
    for(int i = 0; i < g_symbol_count; i++) {
        ProcessSymbol(g_symbols[i]);
    }
}

//+------------------------------------------------------------------+
//| Traiter un symbole                                               |
//+------------------------------------------------------------------+
void ProcessSymbol(string symbol)
{
    // Vérifier le cache d'abord
    TrendCache cached_data;
    if(GetFromCache(symbol, cached_data)) {
        g_cache_hits++;
        ProcessTradingSignal(symbol, cached_data);
        return;
    }
    
    // Appel API optimisé
    if(CanMakeApiCall()) {
        TrendCache api_data = GetTrendDataFromAPI(symbol);
        if(api_data.symbol != "") {
            StoreInCache(api_data);
            g_cache_misses++;
            ProcessTradingSignal(symbol, api_data);
        }
    } else {
        g_api_calls_reduced++;
        // Utiliser des données par défaut
        ProcessTradingSignal(symbol, GetDefaultTrendData(symbol));
    }
}

//+------------------------------------------------------------------+
//| Vérifier si on peut faire un appel API                          |
//+------------------------------------------------------------------+
bool CanMakeApiCall()
{
    if(!InpReduceApiCalls) {
        return true;
    }
    
    datetime current_time = TimeCurrent();
    return (current_time - g_last_api_call) >= InpApiCallInterval;
}

//+------------------------------------------------------------------+
//| Obtenir les données de tendance depuis l'API                    |
//+------------------------------------------------------------------+
TrendCache GetTrendDataFromAPI(string symbol)
{
    TrendCache result;
    result.symbol = "";
    
    // Simuler l'appel API (remplacer par un vrai appel HTTP)
    string url = "http://localhost:8001/trend?symbol=" + symbol + "&timeframe=M1";
    
    // Pour l'instant, simuler des données
    result.symbol = symbol;
    result.timestamp = TimeCurrent();
    result.trend_direction = "BUY";
    result.trend_strength = 75;
    result.confidence = "high";
    result.trading_signal = "TRADE";
    result.spike_probability = 0.8;
    result.time_to_spike = 180;
    result.stop_loss = 0;
    result.take_profit = 0;
    result.lot_size = InpBaseLotSize;
    result.reasoning = "Analyse optimisée";
    
    g_last_api_call = TimeCurrent();
    
    return result;
}

//+------------------------------------------------------------------+
//| Obtenir les données par défaut                                   |
//+------------------------------------------------------------------+
TrendCache GetDefaultTrendData(string symbol)
{
    TrendCache result;
    result.symbol = symbol;
    result.timestamp = TimeCurrent();
    result.trend_direction = "HOLD";
    result.trend_strength = 50;
    result.confidence = "medium";
    result.trading_signal = "MONITOR";
    result.spike_probability = 0.5;
    result.time_to_spike = 300;
    result.stop_loss = 0;
    result.take_profit = 0;
    result.lot_size = InpBaseLotSize;
    result.reasoning = "Mode optimisé - données par défaut";
    
    return result;
}

//+------------------------------------------------------------------+
//| Obtenir depuis le cache                                         |
//+------------------------------------------------------------------+
bool GetFromCache(string symbol, TrendCache &data)
{
    for(int i = 0; i < g_cache_size; i++) {
        if(g_trend_cache[i].symbol == symbol) {
            // Vérifier si le cache est encore valide
            if(TimeCurrent() - g_trend_cache[i].timestamp < InpCacheDuration) {
                data = g_trend_cache[i];
                return true;
            } else {
                // Cache expiré, le supprimer
                RemoveFromCache(i);
                return false;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Stocker dans le cache                                           |
//+------------------------------------------------------------------+
void StoreInCache(TrendCache data)
{
    // Chercher une place libre ou remplacer la plus ancienne
    int index = -1;
    
    for(int i = 0; i < g_cache_size; i++) {
        if(g_trend_cache[i].symbol == data.symbol) {
            index = i;
            break;
        }
    }
    
    if(index == -1) {
        if(g_cache_size < 10) {
            index = g_cache_size++;
        } else {
            // Remplacer la plus ancienne
            index = FindOldestCacheEntry();
        }
    }
    
    g_trend_cache[index] = data;
}

//+------------------------------------------------------------------+
//| Trouver l'entrée de cache la plus ancienne                      |
//+------------------------------------------------------------------+
int FindOldestCacheEntry()
{
    int oldest_index = 0;
    datetime oldest_time = g_trend_cache[0].timestamp;
    
    for(int i = 1; i < g_cache_size; i++) {
        if(g_trend_cache[i].timestamp < oldest_time) {
            oldest_time = g_trend_cache[i].timestamp;
            oldest_index = i;
        }
    }
    
    return oldest_index;
}

//+------------------------------------------------------------------+
//| Supprimer du cache                                               |
//+------------------------------------------------------------------+
void RemoveFromCache(int index)
{
    if(index < 0 || index >= g_cache_size) {
        return;
    }
    
    // Décaler les éléments
    for(int i = index; i < g_cache_size - 1; i++) {
        g_trend_cache[i] = g_trend_cache[i + 1];
    }
    
    g_cache_size--;
}

//+------------------------------------------------------------------+
//| Nettoyer le cache                                                |
//+------------------------------------------------------------------+
void CleanupCache()
{
    datetime current_time = TimeCurrent();
    int removed_count = 0;
    
    for(int i = g_cache_size - 1; i >= 0; i--) {
        if(current_time - g_trend_cache[i].timestamp > InpCacheDuration * 2) {
            RemoveFromCache(i);
            removed_count++;
        }
    }
    
    if(removed_count > 0) {
        Print("🧹 Cache nettoyé: ", removed_count, " entrées supprimées");
    }
}

//+------------------------------------------------------------------+
//| Traiter le signal de trading                                     |
//+------------------------------------------------------------------+
void ProcessTradingSignal(string symbol, TrendCache data)
{
    if(data.trading_signal == "TRADE") {
        // Logique de trading simplifiée
        if(ShouldOpenTrade(symbol, data)) {
            OpenTrade(symbol, data);
        }
    }
    
    // Gérer les trades existants
    ManageExistingTrades(symbol);
}

//+------------------------------------------------------------------+
//| Vérifier si on doit ouvrir un trade                             |
//+------------------------------------------------------------------+
bool ShouldOpenTrade(string symbol, TrendCache data)
{
    // Vérifier le nombre maximum de trades
    if(CountOpenTrades() >= InpMaxConcurrentTrades) {
        return false;
    }
    
    // Vérifier la probabilité de spike
    if(data.spike_probability < 0.7) {
        return false;
    }
    
    // Vérifier la confiance
    if(data.confidence != "high") {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Ouvrir un trade                                                  |
//+------------------------------------------------------------------+
void OpenTrade(string symbol, TrendCache data)
{
    // Logique simplifiée d'ouverture de trade
    Print("📈 Ouverture trade ", symbol, " - Direction: ", data.trend_direction);
    
    // Ici, vous ajouteriez la logique d'ouverture de trade réelle
    // MqlTradeRequest request;
    // MqlTradeResult result;
    // ... logique d'ouverture ...
}

//+------------------------------------------------------------------+
//| Gérer les trades existants                                      |
//+------------------------------------------------------------------+
void ManageExistingTrades(string symbol)
{
    // Logique simplifiée de gestion des trades
    // Ici, vous ajouteriez la logique de trailing stop, etc.
}

//+------------------------------------------------------------------+
//| Compter les trades ouverts                                       |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetTicket(i) > 0) {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Expert timer function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Mise à jour de l'UI si nécessaire
    if(TimeCurrent() - g_last_ui_update >= InpUIUpdateIntervalSec) {
        UpdateUI();
        g_last_ui_update = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour l'interface utilisateur                            |
//+------------------------------------------------------------------+
void UpdateUI()
{
    // Mise à jour simplifiée de l'UI
    if(InpLogVerbosity > 0) {
        Print("📊 UI mise à jour - Trades ouverts: ", CountOpenTrades());
    }
}

//+------------------------------------------------------------------+
