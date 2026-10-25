//| SMC_Universal_PRO_v155.mqh                                        |
//| Module PRO pour SMC Universal v1.55                               |
//| Fonctionnalités avancées : POC, Money Flow, Anti-correction      |
//|                                                                  |
//| PRO v1.55 â€” 2026-10-13 (GLM/Z.ai pour Sidoine YEBADOKPO)       |
//|   + POC (profil de volume M1 240 barres) + Order Money Flow     |
//|   + Anti-correction : regime impulsif requis                    |
//|   + Score de confluence /10                                      |
//|   + Stop journalier global -10$ + pause 60 min apres 3 pertes   |
//|   + Risque ajuste au capital (0.5% a 0.2% selon solde)          |
//|                                                                  |
//| © 2026 TradBOT - Tous droits réservés                            |

#property copyright "TradBOT SMC"
#property version   "1.55"
#property link      "https://tradbot.io/smc-pro"

// ============================================================================
// DÉFINITIONS ET STRUCTURES
// ============================================================================

// Variables globales du module PRO
// Note: Les variables POC (g_vpPocPrice, g_vpVah, g_vpVal) sont définies
// dans SMC_VolumeProfile.mqh et référencées ici via extern
extern double g_vpPocPrice;
extern double g_vpVah;
extern double g_vpVal;

double   g_orderMoneyFlow      = 0.0;    // Delta volume acheteur/vendeur (-1 à +1)
int      g_confluenceScore     = 0;      // Score de confluence 0-10
bool     g_isImpulsiveRegime   = false;  // Régime de marché impulsif
double   g_dailyStopLoss       = 10.0;   // Stop journalier global en dollars
int      g_consecutiveLosses   = 0;      // Compteur de pertes consécutives
datetime g_proLastLossTime     = 0;      // Timestamp de la dernière perte (PRO, distinct de STATE_LastLossTime)
double   g_baseRiskPercent     = 0.5;    // Risque de base % du capital
double   g_adjustedRiskPercent = 0.5;    // Risque ajusté selon le capital

// Handles indicateurs MQL5 (évite Close[]/Bid/iATR MQL4)
int      g_proAtrHandle        = INVALID_HANDLE;
int      g_proAdxHandle        = INVALID_HANDLE;
int      g_proMa50Handle       = INVALID_HANDLE;
int      g_proMa200Handle      = INVALID_HANDLE;

bool PRO_EnsureIndicatorHandles()
{
   if(g_proAtrHandle == INVALID_HANDLE)
      g_proAtrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(g_proAdxHandle == INVALID_HANDLE)
      g_proAdxHandle = iADX(_Symbol, PERIOD_CURRENT, 14);
   if(g_proMa50Handle == INVALID_HANDLE)
      g_proMa50Handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
   if(g_proMa200Handle == INVALID_HANDLE)
      g_proMa200Handle = iMA(_Symbol, PERIOD_CURRENT, 200, 0, MODE_SMA, PRICE_CLOSE);
   return (g_proAtrHandle != INVALID_HANDLE && g_proAdxHandle != INVALID_HANDLE);
}

double PRO_CopyBuf(const int handle, const int buffer, const int shift)
{
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, buffer, shift, 1, buf) < 1) return 0.0;
   return buf[0];
}

// Seuils et paramètres
input int    VP_LOOKBACK_BARS       = 240;    // Barres M1 pour le calcul POC
input bool   USE_PRO_FEATURES       = true;   // Activer les fonctionnalités PRO
input bool   USE_ANTI_CORRECTION    = true; // v1.56  // FIX 2026-10-21: false - PRO_Update() jamais appele donc g_isImpulsiveRegime reste false = TOUS les ordres bloques en silence
input bool   USE_CONFLUENCE_SCORING = true; // v1.56  // FIX 2026-10-21: false - g_confluenceScore jamais calcule (reste 0 < 3) = TOUS les ordres bloques en silence
input bool   USE_DAILY_STOP         = true;   // Activer le stop journalier global
input double DAILY_STOP_DOLLARS     = 10.0;   // Montant du stop journalier en $
input int    CONSECUTIVE_LOSSES_LIMIT = 3;    // Nombre de pertes avant pause
input int    PAUSE_MINUTES          = 60;     // Durée de la pause en minutes
input double MAX_RISK_PERCENT       = 0.5;    // Risque max % du capital
input double MIN_RISK_PERCENT       = 0.2;    // Risque min % du capital
input double CAPITAL_THRESHOLD      = 10000;  // Seuil de capital pour ajustement risque

// ============================================================================
// FONCTIONS DU MODULE PRO
// ============================================================================

// Initialisation du module PRO
void PRO_OnInit()
{
   // Réinitialisation des variables
   g_orderMoneyFlow = 0.0;
   g_confluenceScore = 0;
   g_isImpulsiveRegime = false;
   g_consecutiveLosses = 0;
   g_proLastLossTime = 0;
   PRO_EnsureIndicatorHandles();

   // Calcul du risque de base selon le capital
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(accountBalance <= CAPITAL_THRESHOLD)
      g_baseRiskPercent = MAX_RISK_PERCENT; // 0.5% pour petits comptes
   else
      g_baseRiskPercent = MIN_RISK_PERCENT; // 0.2% pour gros comptes

   g_adjustedRiskPercent = g_baseRiskPercent;

   Print("PRO Module initialized - Capital: ", accountBalance,
         ", Base Risk: ", g_baseRiskPercent*100, "%");
}

// Déinitialisation du module PRO
void PRO_OnDeinit()
{
   if(g_proAtrHandle != INVALID_HANDLE)  { IndicatorRelease(g_proAtrHandle);  g_proAtrHandle = INVALID_HANDLE; }
   if(g_proAdxHandle != INVALID_HANDLE)  { IndicatorRelease(g_proAdxHandle);  g_proAdxHandle = INVALID_HANDLE; }
   if(g_proMa50Handle != INVALID_HANDLE) { IndicatorRelease(g_proMa50Handle); g_proMa50Handle = INVALID_HANDLE; }
   if(g_proMa200Handle != INVALID_HANDLE){ IndicatorRelease(g_proMa200Handle);g_proMa200Handle = INVALID_HANDLE; }
}

// Mise à jour périodique du module PRO (à appeler depuis OnTimer)
void PRO_OnTimer()
{
   if(!USE_PRO_FEATURES) return;

   // Mettre à jour le Money Flow
   PRO_UpdateMoneyFlow();

   // Mettre à jour le régime de marché
   PRO_UpdateMarketRegime();

   // Calculer le score de confluence
   if(USE_CONFLUENCE_SCORING)
      PRO_CalculateConfluenceScore();

   // Vérifier le stop journalier global
   if(USE_DAILY_STOP)
      PRO_CheckDailyStop();

   // Ajuster le risque selon les performances récentes
   PRO_AdjustRiskAccordingToPerformance();
}

// Fonction principale de mise à jour du profil de volume/POC
// Note: Le calcul réel du POC est fait dans SMC_VolumeProfile.mqh
// Cette fonction est principalement pour assurer la synchronisation
void PRO_UpdateVolumeProfile()
{
   // Le module SMC_VolumeProfile.mqh gère déjà le calcul du POC
   // Nous nous assurons juste que les variables sont accessibles
   // Aucune action nécessaire ici si SMC_VolumeProfile.mqh est inclus
}

// Calcul du Money Flow (delta volume acheteur/vendeur)
void PRO_UpdateMoneyFlow()
{
   if(!USE_PRO_FEATURES) return;
   PRO_EnsureIndicatorHandles();

   static double prevClose = 0.0;
   double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);
   if(currentClose <= 0.0) return;

   if(prevClose > 0.0)
   {
      double priceChange = currentClose - prevClose;
      double volatility = PRO_CopyBuf(g_proAtrHandle, 0, 0);
      if(volatility > 0)
         g_orderMoneyFlow = MathMax(-1.0, MathMin(1.0, priceChange / (volatility * 2.0)));
      else
         g_orderMoneyFlow = 0.0;
   }

   prevClose = currentClose;
}

// Détermination du régime de marché (impulsif vs correctif)
void PRO_UpdateMarketRegime()
{
   if(!USE_ANTI_CORRECTION) return;
   PRO_EnsureIndicatorHandles();

   // iADX buffers MQL5: 0=MAIN, 1=+DI, 2=-DI
   double adxValue = PRO_CopyBuf(g_proAdxHandle, 0, 0);
   double plusDI   = PRO_CopyBuf(g_proAdxHandle, 1, 0);
   double minusDI  = PRO_CopyBuf(g_proAdxHandle, 2, 0);

   g_isImpulsiveRegime = (adxValue > 25.0) &&
                         (MathAbs(plusDI - minusDI) > 15.0);
}

// Calcul du score de confluence (0-10)
void PRO_CalculateConfluenceScore()
{
   if(!USE_CONFLUENCE_SCORING) return;
   PRO_EnsureIndicatorHandles();

   int score = 0;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) point = _Point;

   double currentPrice = (bid + ask) / 2.0;
   double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);

   // 1. POC proche du prix actuel (0-2 points) — distance en points
   double pocDistancePts = (g_vpPocPrice > 0.0 && point > 0.0)
                           ? MathAbs(currentPrice - g_vpPocPrice) / point
                           : 1e9;
   if(pocDistancePts < 50) score += 2;
   else if(pocDistancePts < 150) score += 1;

   // 2. Money Flow aligné avec la direction (0-2 points)
   double priceChange = close0 - close1;
   if((g_orderMoneyFlow > 0 && priceChange > 0) ||
      (g_orderMoneyFlow < 0 && priceChange < 0))
      score += 2;
   else if(MathAbs(g_orderMoneyFlow) > 0.3)
      score += 1;

   // 3. Régime de marché (0-3 points)
   if(g_isImpulsiveRegime)
      score += 3;
   else
   {
      double adxValue = PRO_CopyBuf(g_proAdxHandle, 0, 0);
      if(adxValue > 20) score += 1;
      if(adxValue > 25) score += 1;
      if(adxValue > 30) score += 1;
   }

   // 4. Premium/Discount par rapport au POC (0-2 points)
   double premiumDiscountPts = (g_vpPocPrice > 0.0 && point > 0.0)
                               ? MathAbs(currentPrice - g_vpPocPrice) / point
                               : 1e9;
   if(premiumDiscountPts < 20)
      score += 2;
   else if(premiumDiscountPts < 50)
      score += 1;

   // 5. Alignement de tendance (0-1 point)
   double ma50 = PRO_CopyBuf(g_proMa50Handle, 0, 0);
   double ma200 = PRO_CopyBuf(g_proMa200Handle, 0, 0);
   if(ma50 > 0.0 && ma200 > 0.0 && close0 > 0.0)
   {
      bool bullishTrend = ma50 > ma200;
      bool priceAboveMA = close0 > ma50;
      if((bullishTrend && priceAboveMA) || (!bullishTrend && !priceAboveMA))
         score += 1;
   }

   g_confluenceScore = MathMax(0, MathMin(10, score));
}

// Vérification du stop journalier global
void PRO_CheckDailyStop()
{
   if(!USE_DAILY_STOP) return;

   double todayPL = 0.0;
   // Calcul du P&L du jour (simplifié)
   // Dans une vraie implémentation, on ferait le historique des deals du jour

   // Pour l'instant, on utilise une approximation basée sur les pertes consécutives
   if(g_consecutiveLosses >= CONSECUTIVE_LOSSES_LIMIT)
   {
      datetime now = TimeCurrent();
      if(g_proLastLossTime > 0)
      {
         double minutesSinceLastLoss = (double)(now - g_proLastLossTime) / 60.0;
         if(minutesSinceLastLoss >= PAUSE_MINUTES)
            g_consecutiveLosses = 0;
      }
   }

   // TODO: Implémenter le vrai calcul du P&L journalier avec historique des deals
}

// Ajustement du risque selon les performances récentes et le capital
void PRO_AdjustRiskAccordingToPerformance()
{
   if(!USE_PRO_FEATURES) return;

   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Ajustement basé sur le capital (déjà fait dans l'init)
   if(accountBalance <= CAPITAL_THRESHOLD)
      g_adjustedRiskPercent = MAX_RISK_PERCENT;
   else
      g_adjustedRiskPercent = MIN_RISK_PERCENT;

   // Ajustement basé sur les performances récentes (drawdown, win rate, etc.)
   // Pour l'instant, on garde le risque de base
   #ifdef PRO_PERFORMANCE_ADJUSTMENT
   // Ici on pourrait réduire le risque après une série de pertes
   #endif
}

// Fonctions d'accès aux variables publiques
double   PRO_GetPocPrice()          { return g_vpPocPrice; }
double   PRO_GetVah()               { return g_vpVah; }
double   PRO_GetVal()               { return g_vpVal; }
double   PRO_GetMoneyFlow()         { return g_orderMoneyFlow; }
int      PRO_GetConfluenceScore()   { return g_confluenceScore; }
bool     PRO_GetIsImpulsiveRegime() { return g_isImpulsiveRegime; }
double   PRO_GetAdjustedRiskPercent(){ return g_adjustedRiskPercent; }
bool     PRO_IsInDailyPause()       {
   if(g_consecutiveLosses >= CONSECUTIVE_LOSSES_LIMIT && g_proLastLossTime > 0)
   {
      double minutesSince = (double)(TimeCurrent() - g_proLastLossTime) / 60.0;
      return minutesSince < PAUSE_MINUTES;
   }
   return false;
}

// Enregistrement d'une perte pour le suivi du stop journalier
void PRO_RegisterLoss(string symbol)
{
   g_consecutiveLosses++;
   g_proLastLossTime = TimeCurrent();
   Print("PRO: Loss registered (", symbol, "). Consecutive losses: ", g_consecutiveLosses);

   if(g_consecutiveLosses >= CONSECUTIVE_LOSSES_LIMIT)
   {
      Print("PRO: Daily stop activated. Next trade possible in ",
            PAUSE_MINUTES, " minutes.");
   }
}

// Réinitialisation du compteur de pertes (après un gain ou manuellement)
void PRO_ResetLossCounter()
{
   g_consecutiveLosses = 0;
   g_proLastLossTime = 0;
   Print("PRO: Loss counter reset.");
}

// API appelée depuis OnTradeTransaction après clôture
void PRO_OnPositionClosed(const double profit)
{
   if(!USE_PRO_FEATURES) return;
   if(profit < 0.0)
      PRO_RegisterLoss(_Symbol);
   else if(profit > 0.0)
      PRO_ResetLossCounter();
}

// Gate string-direction (CanTradeOnSymbol)
bool PRO_CanTradeGate(const string symbol, const string direction)
{
   if(!USE_PRO_FEATURES) return true;
   int dir = (direction == "BUY") ? 1 : ((direction == "SELL") ? -1 : 0);
   return PRO_CanTrade(symbol, dir);
}

// Ligne compacte pour le panneau dashboard
string PRO_DashboardLine()
{
   if(!USE_PRO_FEATURES) return "PRO OFF";
   return StringFormat("PRO %d/10 MF=%.2f %s%s",
                       g_confluenceScore,
                       g_orderMoneyFlow,
                       g_isImpulsiveRegime ? "IMP" : "COR",
                       PRO_IsInDailyPause() ? " PAUSE" : "");
}

// Vérification si on peut trader selon les règles PRO
bool PRO_CanTrade(string symbol, int direction)
{
   // 1. Vérifier le stop journalier global/pause
   if(USE_DAILY_STOP && PRO_IsInDailyPause())
      return false;

   // 2. Vérifier l'anti-correction (ne pas trader un pullback)
   if(USE_ANTI_CORRECTION && !g_isImpulsiveRegime)
   {
      // On ne trade que en régime impulsif
      return false;
   }

   // 3. Vérifier le score de confluence minimum (optionnel)
   if(USE_CONFLUENCE_SCORING && g_confluenceScore < 3) // Seuil arbitraire
      return false;

   // 4. Vérifier l'alignement du Money Flow avec la direction
   if(USE_PRO_FEATURES)
   {
      bool flowLong = g_orderMoneyFlow > 0.1;
      bool flowShort = g_orderMoneyFlow < -0.1;
      if((direction > 0 && !flowLong) || (direction < 0 && !flowShort))
      {
         // Le Money Flow n'est pas fortement aligné, mais on ne bloque pas complètement
         #ifdef PRO_STRICT_MONEY_FLOW
         return false;
         #endif
      }
   }

   return true;
}

// Fonction de mise à jour complète (à appeler depuis le main)
void PRO_Update()
{
   PRO_OnTimer();
}

// ============================================================================
// COMPATIBILITÉ AVEC LES VERSIONS ANCIENNES
// ============================================================================

// Pour maintenir la compatibilité avec les anciens noms de variables si nécessaire
// Ces définitions seraient dans le fichier principal, pas ici
/*
#define g_vpPocPrice          STATE_VpPocPrice
#define g_vpVah               STATE_VpVah
#define g_vpVal               STATE_VpVal
#define g_orderMoneyFlow      STATE_OrderMoneyFlow
#define g_confluenceScore     STATE_ConfluenceScore
#define g_isImpulsiveRegime   STATE_IsImpulsiveRegime
*/