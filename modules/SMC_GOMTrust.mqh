//+------------------------------------------------------------------+
//| SMC_GOMTrust.mqh - Système de confiance GOM par symbole           |
//| FIX 2026-09-20 (Sidoine) : Suit la précision des verdicts GOM    |
//| par symbole et bloque les symboles avec un score de confiance faible|
//+------------------------------------------------------------------+
// Paramètres externes (définis dans SMC_Universal.mq5 comme input)

// État de confiance par symbole
struct GOMTrustState
{
   string symbol;
   int totalTrades;
   int winningTrades;
   int losingTrades;
   double trustScore;
   bool isBlocked;
   datetime lastTradeTime;
   string lastVerdict;
   double lastProfit;
   
   void Reset()
   {
      totalTrades = 0;
      winningTrades = 0;
      losingTrades = 0;
      trustScore = 0.5;  // Score neutre au démarrage
      isBlocked = false;
      lastTradeTime = 0;
      lastVerdict = "";
      lastProfit = 0.0;
   }
   
   void CalculateTrustScore()
   {
      if(totalTrades == 0)
      {
         trustScore = 0.5;  // Score neutre si pas de trades
         return;
      }
      
      // Calculer le score de confiance basé sur le ratio gain/perte
      double winRate = (double)winningTrades / (double)totalTrades;
      
      // Ajuster le score en fonction du nombre de trades
      double confidenceFactor = MathMin(1.0, (double)totalTrades / (double)MinTradesBeforeTrust);
      
      // Score final = winRate * confidenceFactor
      trustScore = winRate * confidenceFactor;
      
      // Si bloqué et score remonte au-dessus du seuil, débloquer
      if(isBlocked && trustScore >= MinTrustScore)
      {
         isBlocked = false;
         Print("🔄 GOM TRUST - Symbole ", symbol, " débloqué (score=", DoubleToString(trustScore, 2), ")");
      }
      // Si non bloqué et score descend en-dessous du seuil, bloquer
      else if(!isBlocked && trustScore < MinTrustScore && totalTrades >= MinTradesBeforeTrust && AutoBlockLowTrust)
      {
         isBlocked = true;
         Print("🛑 GOM TRUST - Symbole ", symbol, " bloqué (score=", DoubleToString(trustScore, 2), " < ", DoubleToString(MinTrustScore, 2), ")");
      }
   }
};

// Tableau de confiance par symbole (max 20 symboles)
static GOMTrustState g_gomTrustStates[20];
static int g_gomTrustCount = 0;

//+------------------------------------------------------------------+
//| Initialiser le système de confiance GOM                           |
//+------------------------------------------------------------------+
void SMC_GOMTrust_Init()
{
   g_gomTrustCount = 0;
   for(int i = 0; i < 20; i++)
      g_gomTrustStates[i].Reset();
   Print("🚀 GOM TRUST SYSTEM - Initialisé");
}

//+------------------------------------------------------------------+
//| Nettoyer le système de confiance GOM                              |
//+------------------------------------------------------------------+
void SMC_GOMTrust_Deinit()
{
   g_gomTrustCount = 0;
   for(int i = 0; i < 20; i++)
      g_gomTrustStates[i].Reset();
   Print("🚀 GOM TRUST SYSTEM - Nettoyé");
}

//+------------------------------------------------------------------+
//| Obtenir l'index d'un symbole dans le tableau de confiance          |
//+------------------------------------------------------------------+
int SMC_GOMTrust_GetIndex(const string symbol)
{
   for(int i = 0; i < g_gomTrustCount; i++)
   {
      if(g_gomTrustStates[i].symbol == symbol)
         return i;
   }
   
   // Symbole non trouvé, l'ajouter
   if(g_gomTrustCount < 20)
   {
      int idx = g_gomTrustCount++;
      g_gomTrustStates[idx].symbol = symbol;
      g_gomTrustStates[idx].Reset();
      return idx;
   }
   
   return -1;  // Tableau plein
}

//+------------------------------------------------------------------+
//| Enregistrer un trade avec son résultat                            |
//+------------------------------------------------------------------+
void SMC_GOMTrust_RegisterTrade(const string symbol, const string verdict, const double profit)
{
   if(!UseGOMTrustSystem) return;
   
   int idx = SMC_GOMTrust_GetIndex(symbol);
   if(idx < 0) return;
   
   g_gomTrustStates[idx].totalTrades++;
   g_gomTrustStates[idx].lastTradeTime = TimeCurrent();
   g_gomTrustStates[idx].lastVerdict = verdict;
   g_gomTrustStates[idx].lastProfit = profit;
   
   if(profit >= 0)
      g_gomTrustStates[idx].winningTrades++;
   else
      g_gomTrustStates[idx].losingTrades++;
   
   // Réinitialiser le score après un certain nombre de trades
   if(g_gomTrustStates[idx].totalTrades >= TrustResetTrades)
   {
      Print("🔄 GOM TRUST - Réinitialisation du score pour ", symbol, " (", TrustResetTrades, " trades)");
      g_gomTrustStates[idx].totalTrades = 0;
      g_gomTrustStates[idx].winningTrades = 0;
      g_gomTrustStates[idx].losingTrades = 0;
   }
   
   // Recalculer le score de confiance
   g_gomTrustStates[idx].CalculateTrustScore();
   
   Print("📊 GOM TRUST - ", symbol, " | Trades=", g_gomTrustStates[idx].totalTrades,
         " | Wins=", g_gomTrustStates[idx].winningTrades,
         " | Losses=", g_gomTrustStates[idx].losingTrades,
         " | Score=", DoubleToString(g_gomTrustStates[idx].trustScore, 2),
         " | Blocked=", g_gomTrustStates[idx].isBlocked ? "YES" : "NO");
}

//+------------------------------------------------------------------+
//| Vérifier si un symbole est autorisé à trader                      |
//+------------------------------------------------------------------+
bool SMC_GOMTrust_IsSymbolAllowed(const string symbol)
{
   if(!UseGOMTrustSystem) return true;
   
   int idx = SMC_GOMTrust_GetIndex(symbol);
   if(idx < 0) return true;  // Tableau plein, autoriser par défaut
   
   // Si pas assez de trades, autoriser
   if(g_gomTrustStates[idx].totalTrades < MinTradesBeforeTrust)
      return true;
   
   // Vérifier si bloqué
   if(g_gomTrustStates[idx].isBlocked)
   {
      static datetime s_lastBlockLog = 0;
      if(TimeCurrent() - s_lastBlockLog >= 30)
      {
         Print("❌ GOM TRUST - Symbole ", symbol, " bloqué (score=",
               DoubleToString(g_gomTrustStates[idx].trustScore, 2), " < ",
               DoubleToString(MinTrustScore, 2), ")");
         s_lastBlockLog = TimeCurrent();
      }
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Obtenir le score de confiance d'un symbole                        |
//+------------------------------------------------------------------+
double SMC_GOMTrust_GetTrustScore(const string symbol)
{
   if(!UseGOMTrustSystem) return 1.0;
   
   int idx = SMC_GOMTrust_GetIndex(symbol);
   if(idx < 0) return 0.5;
   
   return g_gomTrustStates[idx].trustScore;
}

//+------------------------------------------------------------------+
//| Forcer le blocage d'un symbole                                    |
//+------------------------------------------------------------------+
void SMC_GOMTrust_BlockSymbol(const string symbol)
{
   if(!UseGOMTrustSystem) return;
   
   int idx = SMC_GOMTrust_GetIndex(symbol);
   if(idx < 0) return;
   
   g_gomTrustStates[idx].isBlocked = true;
   Print("🛑 GOM TRUST - Symbole ", symbol, " bloqué manuellement");
}

//+------------------------------------------------------------------+
//| Forcer le déblocage d'un symbole                                  |
//+------------------------------------------------------------------+
void SMC_GOMTrust_UnblockSymbol(const string symbol)
{
   if(!UseGOMTrustSystem) return;
   
   int idx = SMC_GOMTrust_GetIndex(symbol);
   if(idx < 0) return;
   
   g_gomTrustStates[idx].isBlocked = false;
   Print("🔄 GOM TRUST - Symbole ", symbol, " débloqué manuellement");
}

//+------------------------------------------------------------------+
//| Obtenir l'état du système de confiance                            |
//+------------------------------------------------------------------+
string SMC_GOMTrust_GetState()
{
   if(!UseGOMTrustSystem) return "GOM Trust System: OFF";
   
   string state = "GOM Trust System: ON\n";
   for(int i = 0; i < g_gomTrustCount; i++)
   {
      state += StringFormat("  %s | Trades=%d | Wins=%d | Losses=%d | Score=%.2f | Blocked=%s\n",
                           g_gomTrustStates[i].symbol,
                           g_gomTrustStates[i].totalTrades,
                           g_gomTrustStates[i].winningTrades,
                           g_gomTrustStates[i].losingTrades,
                           g_gomTrustStates[i].trustScore,
                           g_gomTrustStates[i].isBlocked ? "YES" : "NO");
   }
   
   return state;
}

//+------------------------------------------------------------------+
//| Obtenir les statistiques d'un symbole                             |
//+------------------------------------------------------------------+
string SMC_GOMTrust_GetSymbolStats(const string symbol)
{
   if(!UseGOMTrustSystem) return "GOM Trust System: OFF";
   
   int idx = SMC_GOMTrust_GetIndex(symbol);
   if(idx < 0) return "Symbole non trouvé";
   
   return StringFormat("GOM Trust - %s | Trades=%d | Wins=%d | Losses=%d | Score=%.2f | Blocked=%s",
                      g_gomTrustStates[idx].symbol,
                      g_gomTrustStates[idx].totalTrades,
                      g_gomTrustStates[idx].winningTrades,
                      g_gomTrustStates[idx].losingTrades,
                      g_gomTrustStates[idx].trustScore,
                      g_gomTrustStates[idx].isBlocked ? "YES" : "NO");
}
