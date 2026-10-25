//+------------------------------------------------------------------+
//| SMC_OpportunityFilter.mqh - Filtre d'opportunité de marché        |
//| FIX 2026-09-20 (Sidoine) : Bloque les entrées pendant moments     |
//| défavorables, ne trade que pendant moments de forte opportunité    |
//+------------------------------------------------------------------+
// Paramètres externes (définis dans SMC_Universal.mq5 comme input)

// État du filtre
struct OpportunityFilterState
{
   int consecutiveLosses;
   datetime lastLossTime;
   bool inCooldown;
   datetime cooldownUntil;
   bool marketFavorable;
   double currentVolatility;
   double currentTrendStrength;
   string lastReason;
   
   void Reset()
   {
      consecutiveLosses = 0;
      lastLossTime = 0;
      inCooldown = false;
      cooldownUntil = 0;
      marketFavorable = false;
      currentVolatility = 0.0;
      currentTrendStrength = 0.0;
      lastReason = "";
   }
};

static OpportunityFilterState g_opfState;

//+------------------------------------------------------------------+
//| Initialiser le filtre d'opportunité                               |
//+------------------------------------------------------------------+
void SMC_OPF_Init()
{
   g_opfState.Reset();
   Print("🚀 OPPORTUNITY FILTER - Initialisé");
}

//+------------------------------------------------------------------+
//| Nettoyer le filtre d'opportunité                                  |
//+------------------------------------------------------------------+
void SMC_OPF_Deinit()
{
   g_opfState.Reset();
   Print("🚀 OPPORTUNITY FILTER - Nettoyé");
}

//+------------------------------------------------------------------+
//| Mettre à jour le filtre d'opportunité                             |
//+------------------------------------------------------------------+
void SMC_OPF_Update(const string symbol)
{
   if(!UseOpportunityFilter)
   {
      g_opfState.marketFavorable = true;
      g_opfState.lastReason = "Filtre désactivé";
      return;
   }
   
   // Vérifier le cooldown après pertes
   if(g_opfState.inCooldown)
   {
      if(TimeCurrent() < g_opfState.cooldownUntil)
      {
         g_opfState.marketFavorable = false;
         g_opfState.lastReason = "Cooldown après perte";
         return;
      }
      else
      {
         g_opfState.inCooldown = false;
         g_opfState.consecutiveLosses = 0;
         Print("🔄 OPPORTUNITY FILTER - Cooldown terminé, trading repris");
      }
   }
   
   // Vérifier les pertes consécutives
   if(g_opfState.consecutiveLosses >= MaxConsecutiveLosses)
   {
      g_opfState.inCooldown = true;
      g_opfState.cooldownUntil = TimeCurrent() + CooldownAfterLossMin * 60;
      g_opfState.marketFavorable = false;
      g_opfState.lastReason = StringFormat("Trop de pertes consécutives (%d)", g_opfState.consecutiveLosses);
      Print("⚠️ OPPORTUNITY FILTER - Cooldown activé après %d pertes consécutives", g_opfState.consecutiveLosses);
      return;
   }
   
   // Vérifier la session de trading
   if(UseSessionFilter && !SMC_OPF_IsFavorableSession())
   {
      g_opfState.marketFavorable = false;
      g_opfState.lastReason = "Session défavorable";
      return;
   }
   
   // Vérifier la volatilité
   if(!SMC_OPF_CheckVolatility(symbol))
   {
      g_opfState.marketFavorable = false;
      g_opfState.lastReason = StringFormat("Volatilité trop faible (%.2f < %.2f)", 
                                          g_opfState.currentVolatility, MinVolatilityATR);
      return;
   }
   
   // Vérifier la force de tendance
   if(!SMC_OPF_CheckTrendStrength(symbol))
   {
      g_opfState.marketFavorable = false;
      g_opfState.lastReason = StringFormat("Tendance trop faible (%.2f < %.2f)", 
                                          g_opfState.currentTrendStrength, MinTrendStrength);
      return;
   }
   
   // Vérifier le range du marché
   if(!SMC_OPF_CheckMarketRange(symbol))
   {
      g_opfState.marketFavorable = false;
      g_opfState.lastReason = "Range de marché insuffisant";
      return;
   }
   
   // Toutes les conditions sont favorables
   g_opfState.marketFavorable = true;
   g_opfState.lastReason = "Conditions favorables";
}

//+------------------------------------------------------------------+
//| Enregistrer une perte                                              |
//+------------------------------------------------------------------+
void SMC_OPF_RegisterLoss(const string symbol)
{
   if(!UseOpportunityFilter) return;
   
   g_opfState.consecutiveLosses++;
   g_opfState.lastLossTime = TimeCurrent();
   
   Print("⚠️ OPPORTUNITY FILTER - Perte enregistrée: %d pertes consécutives", 
         g_opfState.consecutiveLosses);
   
   // Si trop de pertes, activer le cooldown
   if(g_opfState.consecutiveLosses >= MaxConsecutiveLosses)
   {
      g_opfState.inCooldown = true;
      g_opfState.cooldownUntil = TimeCurrent() + CooldownAfterLossMin * 60;
      Print("🛑 OPPORTUNITY FILTER - Cooldown activé pour %d minutes", CooldownAfterLossMin);
   }
}

//+------------------------------------------------------------------+
//| Enregistrer un gain (réinitialiser les pertes consécutives)        |
//+------------------------------------------------------------------+
void SMC_OPF_RegisterWin(const string symbol)
{
   if(!UseOpportunityFilter) return;
   
   if(g_opfState.consecutiveLosses > 0)
   {
      Print("✅ OPPORTUNITY FILTER - Gain enregistré, pertes consécutives réinitialisées");
      g_opfState.consecutiveLosses = 0;
      g_opfState.inCooldown = false;
   }
}

//+------------------------------------------------------------------+
//| Vérifier si le marché est favorable pour le trading               |
//+------------------------------------------------------------------+
bool SMC_OPF_IsMarketFavorable(const string symbol)
{
   if(!UseOpportunityFilter) return true;
   
   SMC_OPF_Update(symbol);
   return g_opfState.marketFavorable;
}

//+------------------------------------------------------------------+
//| Obtenir la raison du rejet                                         |
//+------------------------------------------------------------------+
string SMC_OPF_GetRejectionReason()
{
   return g_opfState.lastReason;
}

//+------------------------------------------------------------------+
//| Vérifier si la session est favorable                              |
//+------------------------------------------------------------------+
bool SMC_OPF_IsFavorableSession()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   int hour = dt.hour;
   int dayOfWeek = dt.day_of_week;
   
   // Dimanche = 0, Samedi = 6 (éviter le week-end)
   if(dayOfWeek == 0 || dayOfWeek == 6)
      return false;
   
   // Session Asie: 00:00 - 06:00 GMT
   bool isAsian = (hour >= 0 && hour < 6);
   
   // Session Londres: 07:00 - 16:00 GMT
   bool isLondon = (hour >= 7 && hour < 16);
   
   // Session New York: 13:00 - 22:00 GMT
   bool isNewYork = (hour >= 13 && hour < 22);
   
   // Session overlap (Londres + NY): 13:00 - 16:00 GMT (meilleure volatilité)
   bool isOverlap = (hour >= 13 && hour < 16);
   
   // Priorité: overlap > Londres > NY > Asie
   if(isOverlap) return true;
   if(isLondon && TradeLondonSession) return true;
   if(isNewYork && TradeNewYorkSession) return true;
   if(isAsian && TradeAsianSession) return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier la volatilité                                             |
//+------------------------------------------------------------------+
bool SMC_OPF_CheckVolatility(const string symbol)
{
   // Utiliser le cache de performance si disponible
   double atr = 0.0;
   if(atrM1 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(atrM1, 0, 0, 1, buf) >= 1)
         atr = buf[0];
   }
   
   if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 50.0;
   
   // Calculer la volatilité relative (ATR / prix)
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   double volatility = atr / price;
   
   g_opfState.currentVolatility = volatility;
   
   // Vérifier si la volatilité est suffisante
   return volatility >= MinVolatilityATR * 0.001;  // ATR multiplié par 0.001 pour normaliser
}

//+------------------------------------------------------------------+
//| Vérifier la force de tendance                                      |
//+------------------------------------------------------------------+
bool SMC_OPF_CheckTrendStrength(const string symbol)
{
   // Calculer la force de tendance basée sur EMA
   double emaFast = 0.0, emaSlow = 0.0;
   
   if(emaFastM1 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(emaFastM1, 0, 0, 1, buf) >= 1)
         emaFast = buf[0];
   }
   
   if(emaSlowM1 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(emaSlowM1, 0, 0, 1, buf) >= 1)
         emaSlow = buf[0];
   }
   
   if(emaFast <= 0 || emaSlow <= 0) return true;  // Pas de données, autoriser par défaut
   
   // Calculer la force de tendance (écart relatif entre EMA)
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   double trendStrength = MathAbs(emaFast - emaSlow) / price;
   
   g_opfState.currentTrendStrength = trendStrength;
   
   // Vérifier si la tendance est suffisamment forte
   return trendStrength >= MinTrendStrength * 0.001;  // Normaliser
}

//+------------------------------------------------------------------+
//| Vérifier le range du marché                                        |
//+------------------------------------------------------------------+
bool SMC_OPF_CheckMarketRange(const string symbol)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(symbol, PERIOD_M1, 0, MinRangeBars + 5, rates) < MinRangeBars)
      return true;  // Pas assez de données, autoriser par défaut
   
   // Calculer le range moyen sur les dernières bougies
   double totalRange = 0.0;
   for(int i = 1; i <= MinRangeBars; i++)
   {
      totalRange += (rates[i].high - rates[i].low);
   }
   
   double avgRange = totalRange / MinRangeBars;
   double atr = 0.0;
   
   if(atrM1 != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(atrM1, 0, 0, 1, buf) >= 1)
         atr = buf[0];
   }
   
   if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 50.0;
   
   // Vérifier si le range est suffisant (au moins 50% de l'ATR)
   return avgRange >= atr * 0.5;
}

//+------------------------------------------------------------------+
//| Obtenir l'état actuel du filtre                                    |
//+------------------------------------------------------------------+
string SMC_OPF_GetState()
{
   string state = StringFormat(
      "OpportunityFilter: %s | ConsecutiveLosses=%d | Cooldown=%s | Favorable=%s | Reason=%s",
      UseOpportunityFilter ? "ON" : "OFF",
      g_opfState.consecutiveLosses,
      g_opfState.inCooldown ? "YES" : "NO",
      g_opfState.marketFavorable ? "YES" : "NO",
      g_opfState.lastReason
   );
   
   return state;
}
