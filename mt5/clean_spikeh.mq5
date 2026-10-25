//+------------------------------------------------------------------+
//|                                              AngelPrime_v2.0.mq5 |
//|          EA de Spike à Ultra-Haute Confiance (version renforcée) |
//|           Intègre la détection Pré-Spike et le Multi-Symbole     |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "2.00"
#property strict

// --- Includes MT5 Standard ---
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//--- Paramètres d'Entrée (Structure optimisée) ---
input group "=== Angel Prime v2 - Configuration Principale ==="
input bool   InpEnableTrading         = true;     // Activer le trading
input int    InpMagicNumber           = 990299;   // Magic number unique
input double InpLotSize               = 0.20;     // Lot par défaut (Boom/Crash)
input int    InpMaxSimultaneousTrades = 2;        // Maximum 2 trades simultanés au total
input int    InpMinTradeIntervalSec   = 300;      // Intervalle min entre trades (5 minutes)

input group "=== Gestion des Risques Stricte (USD) ==="
input double InpMaxLossPerTradeUSD    = 1.5;      // Perte max par trade ($) - TRÈS IMPORTANT
input double InpTargetProfitUSD       = 3.0;      // Gain cible par trade ($)
input double InpMaxGlobalOpenLossUSD  = 4.0;      // Perte totale ouverte max ($) - Coupe-circuit
input int    InpMaxConsecutiveLosses  = 2;        // Stop après N pertes consécutives (par symbole)
input int    InpCooldownMinutes       = 10;       // Cooldown après série de pertes (minutes)

input group "=== Signal de Confluence (Mode Sniper) ==="
input int    InpATR_Period            = 14;       // Période ATR
input double InpSpikeATRMult          = 1.8;      // Range >= k*ATR -> spike potentiel
input double InpWickBodyMin           = 2.0;      // max(mèche)/corps >= k -> forte réjection
input bool   InpUseMTFTrendFilter     = true;     // Exiger un alignement de tendance MTF strict
input int    InpEMAFast               = 20;       // EMA rapide pour tendance (M1/M5)
input int    InpEMASlow               = 50;       // EMA lente pour tendance (M1/M5)
input double InpMinConfidenceEntry    = 90.0;     // Confiance minimale requise pour entrer (%) - AUGMENTÉ

input group "=== NOUVEAU - Détection Pré-Spike (Anticipation) ==="
input bool   InpEnablePreSpike        = true;     // Activer l'anticipation de spike
input int    InpBBPeriod              = 20;       // Période Bollinger Bands
input double InpBBDeviation           = 2.0;      // Déviation Bollinger Bands
input double InpATRBoostMin           = 1.5;      // ATR actuel >= k * moyenne ATR
input int    InpPreSpikeMinConfidence = 70;       // Confiance minimale pour un pré-signal (%)

input group "=== NOUVEAU - Scan Multi-Symboles ==="
input bool   InpEnableMultiSymbolScan = true;      // Activer le scan de plusieurs symboles
input string InpSymbolsToScan         = "Boom 1000 Index,Crash 1000 Index,Boom 500 Index,Crash 500 Index,Boom 300 Index,Crash 300 Index"; // Symboles à scanner
input int    InpScanIntervalSec       = 5;        // Intervalle de scan (secondes)

input group "=== NOUVEAU - Mode Petit Capital ==="
input bool   InpSmallBalanceMode      = true;     // Activer l'adaptation pour petit capital
input double InpSmallBalanceThreshold = 20.0;    // Seuil (USD) pour activer ce mode
input double InpSmallTP_USD           = 1.0;      // TP en $ par trade pour petit capital
input double InpSmallSL_USD           = 0.5;      // SL en $ par trade pour petit capital

input group "=== NOUVEAU - Trailing Stop Intelligent ==="
input bool   InpUseTrailingStop       = true;     // Activer le trailing stop
input double InpBreakevenAtRR         = 1.0;      // Passer au Breakeven à 1:1 R/R
input double InpTrailAfterRR          = 1.5;      // Démarrer le trailing à 1:1.5 R/R
input double InpTrailDistanceR        = 0.5;      // Distance du trailing (en multiple de risque R)

input group "=== Exécution & Visuels ==="
input double InpQuickGainThresholdUSD = 0.05;     // Seuil de gain rapide pour fermeture ($)
input int    InpStopsBufferPoints     = 10;       // Buffer (en points) pour éviter "invalid stops"
input bool   InpShowHUD               = true;     // Afficher le panneau d'information (HUD)
input bool   InpDebug                 = false;    // Activer les logs de diagnostic

// --- Variables Globales et Déclarations Anticipées ---
CTrade g_trade;
datetime g_lastOrderTs = 0;
datetime g_globalCooldownUntil = 0;
datetime g_lastHudUpdate = 0;
const int MAX_SYMBOLS = 64; // Augmenté pour le scan multi-symboles

// Tableaux pour le suivi par symbole
string   g_lossSymbols[MAX_SYMBOLS];
int      g_lossCounts[MAX_SYMBOLS];
string   g_cdSymbols[MAX_SYMBOLS];
datetime g_cdUntil[MAX_SYMBOLS];
string   g_symbols_to_scan[]; // Tableau dynamique pour les symboles à scanner
int      g_current_scan_index = 0;
datetime g_last_scan_time = 0;

// Déclarations anticipées des fonctions utilitaires
bool IsBoomCrashIndex(const string sym);
int EnforceBoomCrashDirection(const string symbol, int desiredDirection);
double GetPointValueUSD(const string symbol, double lot);
double SnapLotToSymbol(const string symbol, const double desired);
void ComputeSLTP_ByDollar(const string symbol, const int direction, const double lot, double &slPrice, double &tpPrice);
bool IsSymbolInCooldown(const string symbol);
void SetSymbolCooldown(const string symbol, const int seconds);
void IncrementConsecutiveLoss(const string symbol);
void ResetConsecutiveLoss(const string symbol);
void DrawText(const string id, const string text, const int x, const int y, const color col);

// --- Classe: CRiskManager (Gestion stricte des limites) ---
class CRiskManager
{
public:
    bool IsGlobalPositionLimitReached()
    {
        int openTradesGlobal = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            if(!PositionSelectByIndex(i)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            openTradesGlobal++;
            }
        }
        return (openTradesGlobal >= InpMaxSimultaneousTrades);
    }
    
    bool CanOpenTrade(const string symbol)
    {
        if(g_globalCooldownUntil > TimeCurrent()) return false;
        if(IsGlobalPositionLimitReached()) return false;
        if(IsSymbolInCooldown(symbol)) return false;
        
        int loss_idx = StringFindInArray(g_lossSymbols, symbol);
        if(loss_idx != -1 && g_lossCounts[loss_idx] >= InpMaxConsecutiveLosses) {
        return false;
    }

        if(TimeCurrent() - g_lastOrderTs < InpMinTradeIntervalSec) return false;

            return true;
    }
};

// --- Classe: CSignalDetector (Cerveau de détection de confluence) ---
class CSignalDetector
{
private:
    int GetTrendDirection(const string symbol, ENUM_TIMEFRAMES tf)
    {
        int emaF = iMA(symbol, tf, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
        int emaS = iMA(symbol, tf, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
        if(emaF == INVALID_HANDLE || emaS == INVALID_HANDLE) return 0;
        double f[2], s[2];
        bool ok = (CopyBuffer(emaF, 0, 0, 2, f) >= 2 && CopyBuffer(emaS, 0, 0, 2, s) >= 2);
        IndicatorRelease(emaF); IndicatorRelease(emaS);
        if(!ok) return 0;
        if(f[0] > s[0]) return POSITION_TYPE_BUY;
        if(f[0] < s[0]) return POSITION_TYPE_SELL;
        return 0;
    }

    double DetectSpikeConfluence(const string symbol, int &outDir)
    {
        outDir = 0;
        MqlRates r[3];
        if(CopyRates(symbol, PERIOD_M1, 0, 3, r) < 3) return 0.0;

        int hAtr = iATR(symbol, PERIOD_M1, InpATR_Period);
        double abuf[1];
        double atr = 0.0;
        if(hAtr != INVALID_HANDLE && CopyBuffer(hAtr, 0, 1, 1, abuf) >= 1) {
            atr = abuf[0];
            IndicatorRelease(hAtr);
        }
        if(atr <= 0.0) return 0.0;

        double range = r[1].high - r[1].low;
        double body = MathAbs(r[1].close - r[1].open);
        double upper = r[1].high - MathMax(r[1].open, r[1].close);
        double lower = MathMin(r[1].open, r[1].close) - r[1].low;

        if(range < InpSpikeATRMult * atr) return 0.0;
        if(body <= 0.0 || MathMax(upper, lower) / body < InpWickBodyMin) return 0.0;

        double baseConf = 40.0;
        baseConf += MathMin(30.0, (range / (InpSpikeATRMult * atr) - 1.0) * 30.0);
        baseConf += MathMin(30.0, (MathMax(upper, lower) / (InpWickBodyMin * body) - 1.0) * 30.0);
        outDir = (r[1].close > r[1].open) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        return baseConf;
    }
    
    // NOUVEAU: Logique de pré-détection de Spike
    double DetectPreSpike(const string symbol, int &outDir)
    {
        outDir = 0;
        if (!IsBoomCrashIndex(symbol)) return 0.0;

        // 1. Compression des Bollinger Bands
        int bb_handle = iBands(symbol, PERIOD_M1, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
        if(bb_handle == INVALID_HANDLE) return 0.0;
        double up[2], mid[2], lo[2];
        bool bb_ok = CopyBuffer(bb_handle, 0, 0, 2, up) >= 2 && CopyBuffer(bb_handle, 1, 0, 2, mid) >= 2 && CopyBuffer(bb_handle, 2, 0, 2, lo) >= 2;
        IndicatorRelease(bb_handle);
        if(!bb_ok || mid[0] <= 0) return 0.0;
        double bbw_now = (up[0] - lo[0]) / mid[0];
        if (bbw_now > 0.012) return 0.0; // Seuil de compression

        // 2. Augmentation de la volatilité (ATR)
        int atr_handle = iATR(symbol, PERIOD_M1, InpATR_Period);
        if(atr_handle == INVALID_HANDLE) return 0.0;
        double atr_buf[20];
        int copied = CopyBuffer(atr_handle, 0, 0, 20, atr_buf);
        IndicatorRelease(atr_handle);
        if(copied < 20) return 0.0;
        double atr_now = atr_buf[0];
        double atr_avg = 0;
        for(int i = 1; i < 20; i++) atr_avg += atr_buf[i];
        atr_avg /= 19.0;
        if(atr_now < InpATRBoostMin * atr_avg) return 0.0;

        // 3. Direction suggérée par la dernière bougie
        MqlRates r[2];
        if(CopyRates(symbol, PERIOD_M1, 0, 2, r) < 2) return 0.0;
        if (r[1].close > r[1].open) outDir = POSITION_TYPE_BUY;
        else outDir = POSITION_TYPE_SELL;

        double confidence = 20.0 + (bbw_now < 0.01 ? 25.0 : 10.0) + (atr_now / atr_avg - InpATRBoostMin) * 20.0;
        return MathMin(100.0, confidence);
    }
    
public:
    double Analyze(const string symbol, int &outDir)
    {
        outDir = 0;
        
        // Priorité 1: Détection de spike avancée
        double confidence = DetectSpikeConfluence(symbol, outDir);
        
        // Priorité 2: Si pas de spike, chercher un pré-signal
        if(confidence < 50.0 && InpEnablePreSpike) {
            int pre_dir = 0;
            double pre_conf = DetectPreSpike(symbol, pre_dir);
            if (pre_conf >= InpPreSpikeMinConfidence) {
                outDir = pre_dir;
                confidence = pre_conf; // Remplacer la confiance par celle du pré-signal
            }
        }
        
        if (confidence == 0.0) return 0.0;
        
        // Filtres de Tendance et ICT (restent les mêmes)
        int trend_dir_h1 = GetTrendDirection(symbol, PERIOD_H1);
        if (trend_dir_h1 != outDir) return 0.0; // Rejet si pas aligné avec H1
        confidence += 20.0;
        
        int trend_dir_m5 = GetTrendDirection(symbol, PERIOD_M5);
        if (trend_dir_m5 == outDir) confidence += 15.0; else return 0.0;

        // Vérification finale des règles Boom/Crash
        outDir = EnforceBoomCrashDirection(symbol, outDir);
        if(outDir == 0) return 0.0;
        
        return MathMin(100.0, confidence);
    }
};

// --- Classe: CTradeExecutor (Exécution et gestion des sorties) ---
class CTradeExecutor
{
public:
    bool ExecuteTrade(const string symbol, const int direction, const double confidence)
    {
        double price = (direction == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
        if(price <= 0.0) return false;
        
        double lotSize = SnapLotToSymbol(symbol, InpLotSize);
        if(lotSize <= 0.0) return false;
        
        double sl = 0, tp = 0;
        ComputeSLTP_ByDollar(symbol, direction, lotSize, sl, tp);
        if (sl <= 0 || tp <= 0) return false;

        g_trade.SetExpertMagicNumber(InpMagicNumber);
        g_trade.SetDeviationInPoints(InpStopsBufferPoints);
        
        bool ok = (direction == POSITION_TYPE_BUY) 
            ? g_trade.Buy(lotSize, symbol, price, sl, tp, StringFormat("AngelPrime BUY C:%.0f", confidence)) 
            : g_trade.Sell(lotSize, symbol, price, sl, tp, StringFormat("AngelPrime SELL C:%.0f", confidence));

        if (ok) {
            g_lastOrderTs = TimeCurrent();
            if(InpDebug) Print(StringFormat("TRADE EXECUTED: %s %s %.2f lots @ %.5f, SL=%.5f, TP=%.5f (Conf: %.0f)",
                                            symbol, (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), lotSize, price, sl, tp, confidence));
        } else {
             if(InpDebug) Print(StringFormat("TRADE FAILED: %s (Retcode: %d)", symbol, g_trade.ResultRetcode()));
        }
        return ok;
    }

    void ManageExits()
    {
        // Coupe-circuit global
        double totalOpenPnl = 0.0;
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            if(!PositionSelectByIndex(i)) continue;
                            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                totalOpenPnl += PositionGetDouble(POSITION_PROFIT);
            }
        }
        if (totalOpenPnl <= -MathAbs(InpMaxGlobalOpenLossUSD)) {
            if(InpDebug) Print("HARD STOP: Limite de perte globale atteinte. Clôture de toutes les positions.");
            CloseAllPositions(InpMagicNumber);
            g_globalCooldownUntil = TimeCurrent() + InpCooldownMinutes * 60;
        return;
    }
    
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(!PositionSelectByIndex(i)) continue;
                    if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

            ulong ticket = PositionGetTicket(i);
            string symbol = PositionGetString(POSITION_SYMBOL);
                double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            int direction = (int)PositionGetInteger(POSITION_TYPE);
            
            // NOUVEAU: Gestion du Trailing Stop intelligent
            if(InpUseTrailingStop) ManageTrailingStop(ticket, symbol, direction);
            
            // Gestion des sorties
            if (profit >= InpQuickGainThresholdUSD) {
                if (ClosePosition(ticket)) {
                    ResetConsecutiveLoss(symbol);
                    if(InpDebug) Print(StringFormat("POSITION CLOSED (Quick Gain): %s, Profit: $%.2f", symbol, profit));
                }
            }
        }
    }

private:
    bool ClosePosition(ulong ticket)
    {
        g_trade.SetExpertMagicNumber(InpMagicNumber);
        return g_trade.PositionClose(ticket);
    }
    
void CloseAllPositions(int magic)
{
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            if(!PositionSelectByIndex(i)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
            ClosePosition(PositionGetTicket(i));
        }
    }
    
    // NOUVEAU: Logique de Trailing Stop
    void ManageTrailingStop(ulong ticket, const string symbol, int direction)
    {
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_price = (direction == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
        double sl_price = PositionGetDouble(POSITION_SL);
        double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);

        double initial_risk_pts = MathAbs(open_price - sl_price) / pt;
        if(initial_risk_pts <= 0) return;

        double current_profit_pts = MathAbs(current_price - open_price) / pt;
        double r_multiple = current_profit_pts / initial_risk_pts;

        double new_sl = 0;

        // 1. Déplacer au Breakeven
        if (r_multiple >= InpBreakevenAtRR) {
            new_sl = open_price + (direction == POSITION_TYPE_BUY ? pt : -pt); // Léger profit
        }

        // 2. Activer le Trailing
        if (r_multiple >= InpTrailAfterRR) {
            double trail_dist_pts = initial_risk_pts * InpTrailDistanceR;
    if(direction == POSITION_TYPE_BUY) {
                new_sl = current_price - trail_dist_pts * pt;
    } else {
                new_sl = current_price + trail_dist_pts * pt;
            }
        }

        // Appliquer le nouveau SL s'il est meilleur
        if (new_sl > 0) {
            if ((direction == POSITION_TYPE_BUY && new_sl > sl_price) || 
                (direction == POSITION_TYPE_SELL && (sl_price == 0 || new_sl < sl_price))) {
                
                g_trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
            }
        }
    }
};

// --- Objets Globaux ---
CRiskManager   g_riskManager;
CSignalDetector g_signalDetector;
CTradeExecutor g_tradeExecutor;

// --- Implémentation des Fonctions Utilitaires ---
void InitializeSymbols()
{
    StringSplit(InpSymbolsToScan, ',', g_symbols_to_scan);
    for(int i = 0; i < ArraySize(g_symbols_to_scan); i++) {
        StringTrimLeft(g_symbols_to_scan[i]);
        StringTrimRight(g_symbols_to_scan[i]);
        SymbolSelect(g_symbols_to_scan[i], true); // S'assurer que le symbole est visible
    }
}

// ... (Les autres fonctions utilitaires comme SnapLotToSymbol, ComputeSLTP_ByDollar, etc. restent les mêmes)

void ComputeSLTP_ByDollar(const string symbol, const int direction, const double lot, double &slPrice, double &tpPrice)
{
    slPrice = 0.0; tpPrice = 0.0;
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    if(pt <= 0 || digits == 0) return;
    double entryPrice = (direction == POSITION_TYPE_BUY) ? ask : bid;

    // Utiliser les paramètres du mode petit capital si activé
    double maxLoss = InpMaxLossPerTradeUSD;
    double targetProfit = InpTargetProfitUSD;
    if (InpSmallBalanceMode && AccountInfoDouble(ACCOUNT_BALANCE) <= InpSmallBalanceThreshold) {
        maxLoss = InpSmallSL_USD;
        targetProfit = InpSmallTP_USD;
    }
    
    double usdPerPoint = GetPointValueUSD(symbol, lot);
    if (usdPerPoint <= 0.0) return;

    double maxLossPts = MathFloor(MathAbs(maxLoss) / usdPerPoint);
    double targetPts  = MathFloor(MathAbs(targetProfit) / usdPerPoint);
    if (maxLossPts <= InpStopsBufferPoints) return;
    
    if (direction == POSITION_TYPE_BUY) {
        slPrice = NormalizeDouble(entryPrice - maxLossPts * pt, digits);
        tpPrice = NormalizeDouble(entryPrice + targetPts * pt, digits);
        } else {
        slPrice = NormalizeDouble(entryPrice + maxLossPts * pt, digits);
        tpPrice = NormalizeDouble(entryPrice - targetPts * pt, digits);
    }
}

// ... (Le reste des fonctions utilitaires)
//+------------------------------------------------------------------+
//| Initialisation et Point d'Entrée Principal                       |
//+------------------------------------------------------------------+
int OnInit()
{
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetDeviationInPoints(InpStopsBufferPoints);
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    if (InpEnableMultiSymbolScan) {
        InitializeSymbols();
    }
    
    Print("Angel Prime v2.0 Initialized. Mode Sniper Renforcé.");
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    for(int i = 0; i < 6; i++) ObjectDelete(0, StringFormat("ANGEL_HUD_%d", i));
    Print("Angel Prime v2.0 Deinitialized.");
}

void OnTick()
{
    if(!InpEnableTrading) return;

    g_tradeExecutor.ManageExits();
    
    if (TimeCurrent() - g_lastHudUpdate >= 1) {
        DrawAngelHUD();
        g_lastHudUpdate = TimeCurrent();
    }
    
    if (g_globalCooldownUntil > TimeCurrent()) return;

    // Logique de scan multi-symboles
    if (InpEnableMultiSymbolScan) {
        if (TimeCurrent() - g_last_scan_time < InpScanIntervalSec) return;
        g_last_scan_time = TimeCurrent();
        
        string symbol_to_check = g_symbols_to_scan[g_current_scan_index];
        g_current_scan_index = (g_current_scan_index + 1) % ArraySize(g_symbols_to_scan);
        
        if (g_riskManager.CanOpenTrade(symbol_to_check)) {
            int direction = 0;
            double confidence = g_signalDetector.Analyze(symbol_to_check, direction);
            if (confidence >= InpMinConfidenceEntry && direction != 0) {
                g_tradeExecutor.ExecuteTrade(symbol_to_check, direction, confidence);
            }
        }
    } else { // Mode mono-symbole (graphique actuel)
        string symbol = _Symbol;
        if (g_riskManager.CanOpenTrade(symbol)) {
            int direction = 0;
            double confidence = g_signalDetector.Analyze(symbol, direction);
            if (confidence >= InpMinConfidenceEntry && direction != 0) {
                g_tradeExecutor.ExecuteTrade(symbol, direction, confidence);
            }
        }
    }
}

// Les fonctions utilitaires (DrawText, Cooldown, etc.) sont à copier depuis la version précédente.
// Je les omets ici pour la concision mais elles sont nécessaires.

// --- Helper Functions (à copier/coller depuis la v1.0) ---

int StringFindInArray(const string &arr[], const string value) {
    for(int i = 0; i < ArraySize(arr); i++) if(arr[i] == value) return i;
    return -1;
}

// --- Les autres fonctions utilitaires de la v1.0 doivent être présentes ici ---

void DrawAngelHUD()
{
    if(!InpShowHUD) return;
    
    for(int i = 0; i < 10; i++) ObjectsDeleteAll(0, StringFormat("ANGEL_HUD_%d", i), -1, -1);

    int y = 20;
    int dy = 14;
    color accent = clrDeepSkyBlue;
    
    string status = g_riskManager.IsGlobalPositionLimitReached() ? "❌ LIMIT REACHED" : "✅ OK";
    DrawText("ANGEL_HUD_0", "AngelPrime Status: " + status, 10, y, accent); y+=dy;
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    DrawText("ANGEL_HUD_1", StringFormat("Balance: %.2f USD", balance), 10, y, clrWhite); y+=dy;
    
    int openTrades = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelectByIndex(i) && (int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) openTrades++;
    }
    DrawText("ANGEL_HUD_2", StringFormat("Open Positions: %d / %d", openTrades, InpMaxSimultaneousTrades), 10, y, clrWhite); y+=dy;
    
    string cdStatus = IsSymbolInCooldown(_Symbol) ? "ACTIVE" : "NONE";
    DrawText("ANGEL_HUD_3", "Symbol Cooldown: " + cdStatus, 10, y, (cdStatus == "ACTIVE" ? clrRed : clrLime)); y+=dy;
    
    int loss_idx = StringFindInArray(g_lossSymbols, _Symbol);
    int consLoss = (loss_idx >= 0) ? g_lossCounts[loss_idx] : 0;
    DrawText("ANGEL_HUD_4", StringFormat("Cons. Losses: %d / %d", consLoss, InpMaxConsecutiveLosses), 10, y, (consLoss > 0 ? clrOrange : clrLime)); y+=dy;
    
    double totalOpenPnl = 0.0;
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelectByIndex(i) && (int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) totalOpenPnl += PositionGetDouble(POSITION_PROFIT);
    }
    string globalLoss = StringFormat("Global PnL: $%.2f (Cap: -$%.2f)", totalOpenPnl, InpMaxGlobalOpenLossUSD);
    DrawText("ANGEL_HUD_5", globalLoss, 10, y, (totalOpenPnl <= -InpMaxGlobalOpenLossUSD/2 ? clrRed : clrWhite)); y+=dy;
}

// --- Le reste des fonctions utilitaires de la v1.0 est à ajouter ici ---
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal_type == DEAL_ENTRY_OUT)
    {
        if(trans.magic == InpMagicNumber)
        {
            CHistoryDealInfo deal;
            if(deal.Select(trans.deal))
            {
                double profit = deal.Profit();
                if (profit < 0) {
                    IncrementConsecutiveLoss(deal.Symbol());
    } else {
                    ResetConsecutiveLoss(deal.Symbol());
                }
            }
        }
    }
}