//+------------------------------------------------------------------+
//| CALCUL DE LA VRAIE PROBABILITÉ DE SPIKE EN COURS                  |
//+------------------------------------------------------------------+

// Structure pour stocker les données d'un symbole
struct SymbolSpikeData {
   string symbol;
   double realDirection;      // Direction réelle des prix (-1 SELL, 1 BUY, 0 neutre)
   double currentVolatility;  // Volatilité actuelle (pas moyenne historique)
   double momentumStrength;   // Force du momentum actuel
   double continuationProb;   // Probabilité de continuation
   bool isAgainstTrend;       // Contre-tendance ou non
   double spikeProbability;   // Probabilité totale de spike
};

// Variables globales pour stocker les dernières opportunités
string g_lastBestSymbol = "";
double g_lastSpikeProbability = 0.0;
double g_lastRealDirection = 0.0;
double CalculateRealSpikeOpportunity(string symbol, SymbolSpikeData &data)
{
   data.symbol = symbol;
   data.spikeProbability = 0.0;

   // 1. ANALYSER LA DIRECTION RÉELLE DES PRIX EN M1/M5
   data.realDirection = AnalyzeRealPriceDirection(symbol);
   if(data.realDirection == 0) {
      Print("❌ ", symbol, " - Direction neutre, pas d'opportunité claire");
      return 0.0; // Direction neutre = pas d'opportunité
   }

   // 2. ÉVALUER LE VOLUME ET LA VOLATILITÉ ACTUELS
   data.currentVolatility = CalculateCurrentVolatility(symbol);
   if(data.currentVolatility < 0.0001) { // Seuil minimum
      Print("❌ ", symbol, " - Volatilité trop faible (", DoubleToString(data.currentVolatility, 6), ")");
      return 0.0;
   }

   // 3. CALCULER LA PROBABILITÉ DE CONTINUATION
   data.momentumStrength = CalculateMomentumStrength(symbol);
   data.continuationProb = CalculateContinuationProbability(symbol, data.realDirection);

   // 4. VÉRIFIER SI C'EST CONTRE-TENDANCE
   data.isAgainstTrend = IsAgainstCurrentTrend(symbol, data.realDirection);

   // Calcul de la probabilité totale
   data.spikeProbability = CalculateTotalSpikeProbability(data);

   Print("🎯 ", symbol, " - Analyse réelle terminée:");
   Print("   📈 Direction: ", data.realDirection > 0 ? "HAUSSIÈRE" : "BAISSIÈRE");
   Print("   💹 Volatilité actuelle: ", DoubleToString(data.currentVolatility, 6));
   Print("   ⚡ Force momentum: ", DoubleToString(data.momentumStrength, 2));
   Print("   🔄 Probabilité continuation: ", DoubleToString(data.continuationProb, 2), "%");
   Print("   🚫 Contre-tendance: ", data.isAgainstTrend ? "OUI" : "NON");
   Print("   🎲 Probabilité spike totale: ", DoubleToString(data.spikeProbability, 2), "%");

   return data.spikeProbability;
}

// 1. Analyse de la direction réelle des prix en M1/M5
double AnalyzeRealPriceDirection(string symbol)
{
   MqlRates ratesM1[], ratesM5[];

   // Récupérer les données M1 (5 dernières bougies)
   if(CopyRates(symbol, PERIOD_M1, 0, 5, ratesM1) < 5) return 0.0;

   // Récupérer les données M5 (3 dernières bougies)
   if(CopyRates(symbol, PERIOD_M5, 0, 3, ratesM5) < 3) return 0.0;

   ArraySetAsSeries(ratesM1, true);
   ArraySetAsSeries(ratesM5, true);

   // Calcul de la direction M1 (moyenne des 3 dernières bougies)
   double directionM1 = 0.0;
   for(int i = 1; i <= 3; i++) {
      double body = ratesM1[i].close - ratesM1[i].open;
      directionM1 += (body > 0) ? 1.0 : (body < 0) ? -1.0 : 0.0;
   }
   directionM1 /= 3.0;

   // Calcul de la direction M5 (moyenne des 2 dernières bougies)
   double directionM5 = 0.0;
   for(int i = 1; i <= 2; i++) {
      double body = ratesM5[i].close - ratesM5[i].open;
      directionM5 += (body > 0) ? 1.0 : (body < 0) ? -1.0 : 0.0;
   }
   directionM5 /= 2.0;

   // Direction globale pondérée (M1 60%, M5 40%)
   double globalDirection = (directionM1 * 0.6) + (directionM5 * 0.4);

   // Seuillage pour éviter les directions trop faibles
   if(MathAbs(globalDirection) < 0.3) return 0.0; // Trop neutre

   return (globalDirection > 0) ? 1.0 : -1.0;
}

// 2. Calcul de la volatilité actuelle (pas historique)
double CalculateCurrentVolatility(string symbol)
{
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, 0, 10, rates) < 10) return 0.0;

   ArraySetAsSeries(rates, true);

   // Calcul de l'écart-type des 10 dernières bougies (volatilité actuelle)
   double mean = 0.0;
   for(int i = 0; i < 10; i++) {
      mean += MathAbs(rates[i].close - rates[i].open);
   }
   mean /= 10.0;

   double variance = 0.0;
   for(int i = 0; i < 10; i++) {
      double diff = MathAbs(rates[i].close - rates[i].open) - mean;
      variance += diff * diff;
   }
   variance /= 10.0;

   double volatility = MathSqrt(variance);

   // Normaliser par le prix actuel pour avoir un pourcentage
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_LAST);
   if(currentPrice > 0) {
      volatility = (volatility / currentPrice) * 100.0; // En pourcentage
   }

   return volatility;
}

// 3. Calcul de la force du momentum actuel
double CalculateMomentumStrength(string symbol)
{
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, 0, 5, rates) < 5) return 0.0;

   ArraySetAsSeries(rates, true);

   // Calcul de l'accélération des prix (différences successives)
   double momentum = 0.0;
   for(int i = 1; i < 4; i++) {
      double currentBody = MathAbs(rates[i].close - rates[i].open);
      double prevBody = MathAbs(rates[i+1].close - rates[i+1].open);
      momentum += (currentBody > prevBody) ? 1.0 : -1.0;
   }

   // Normaliser entre 0 et 100
   momentum = ((momentum + 4.0) / 8.0) * 100.0;

   return momentum;
}

// 4. Calcul de la probabilité de continuation
double CalculateContinuationProbability(string symbol, double direction)
{
   // Analyse des EMA pour voir si le mouvement est soutenu
   double ema9 = GetEMAValue(symbol, PERIOD_M1, 9, 0);
   double ema21 = GetEMAValue(symbol, PERIOD_M1, 21, 0);

   if(ema9 == 0 || ema21 == 0) return 50.0; // Valeur neutre

   double emaSlope = (ema9 > ema21) ? 1.0 : -1.0;

   // Si la direction des prix correspond à la pente des EMA, probabilité élevée
   if((direction > 0 && emaSlope > 0) || (direction < 0 && emaSlope < 0)) {
      return 80.0; // Forte probabilité de continuation
   } else {
      return 30.0; // Faible probabilité (contre-tendance EMA)
   }
}

// 5. Vérification si c'est contre-tendance
bool IsAgainstCurrentTrend(string symbol, double direction)
{
   // Vérifier la tendance générale sur H1
   double ema9_H1 = GetEMAValue(symbol, PERIOD_H1, 9, 0);
   double ema21_H1 = GetEMAValue(symbol, PERIOD_H1, 21, 0);

   if(ema9_H1 == 0 || ema21_H1 == 0) return false;

   double trendDirection = (ema9_H1 > ema21_H1) ? 1.0 : -1.0;

   // Si la direction actuelle va contre la tendance H1, c'est contre-tendance
   return ((direction > 0 && trendDirection < 0) || (direction < 0 && trendDirection > 0));
}

// 6. Calcul de la probabilité totale de spike
double CalculateTotalSpikeProbability(SymbolSpikeData &data)
{
   double probability = 0.0;

   // Facteur 1: Direction claire (requis)
   if(data.realDirection == 0) return 0.0;
   probability += 20.0; // Base pour direction claire

   // Facteur 2: Volatilité actuelle (plus c'est élevé, mieux c'est)
   probability += MathMin(data.currentVolatility * 10.0, 30.0);

   // Facteur 3: Force du momentum
   probability += data.momentumStrength * 0.3;

   // Facteur 4: Probabilité de continuation
   probability += data.continuationProb * 0.4;

   // Pénalité pour contre-tendance
   if(data.isAgainstTrend) {
      probability *= 0.5; // Réduction de 50%
   }

   // Limitation entre 0 et 100
   probability = MathMax(0.0, MathMin(100.0, probability));

   return probability;
}

// Fonction helper pour récupérer les valeurs EMA
double GetEMAValue(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift)
{
   int handle = iMA(symbol, timeframe, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return 0.0;

   double value[1];
   if(CopyBuffer(handle, 0, shift, 1, value) <= 0) {
      IndicatorRelease(handle);
      return 0.0;
   }

   IndicatorRelease(handle);
   return value[0];
}

// Fonction pour trouver les meilleures opportunités de spike (jusqu'à 2 symboles)
string FindBestSpikeOpportunities(string &symbols[], SymbolSpikeData &bestData[], int maxOpportunities = 2)
{
   SymbolSpikeData tempData[];
   ArrayResize(tempData, ArraySize(symbols));

   // Calculer les probabilités pour tous les symboles
   for(int i = 0; i < ArraySize(symbols); i++) {
      CalculateRealSpikeOpportunity(symbols[i], tempData[i]);
   }

   // Trier par probabilité décroissante
   for(int i = 0; i < ArraySize(symbols) - 1; i++) {
      for(int j = i + 1; j < ArraySize(symbols); j++) {
         if(tempData[j].spikeProbability > tempData[i].spikeProbability) {
            SymbolSpikeData temp = tempData[i];
            tempData[i] = tempData[j];
            tempData[j] = temp;
         }
      }
   }

   // Prendre les meilleures opportunités (max 2)
   int opportunitiesCount = MathMin(maxOpportunities, ArraySize(symbols));
   ArrayResize(bestData, opportunitiesCount);

   Print("🏆 MEILLEURES OPPORTUNITÉS DE SPIKE TROUVÉES:");
   Print("============================================");

   for(int i = 0; i < opportunitiesCount; i++) {
      bestData[i] = tempData[i];
      double score = MathMin(100.0, tempData[i].spikeProbability);

      Print("   #" + IntegerToString(i+1) + " - " + tempData[i].symbol);
      Print("   🎲 Score: " + DoubleToString(score, 1) + "/100 points");
      Print("   📈 Direction: " + (tempData[i].realDirection > 0 ? "ACHAT" : "VENTE"));
      Print("   💹 Volatilité: " + DoubleToString(tempData[i].currentVolatility, 2) + "%");
      Print("   ⚡ Momentum: " + DoubleToString(tempData[i].momentumStrength, 1));
      Print("   🔄 Continuation: " + DoubleToString(tempData[i].continuationProb, 1) + "%");
      Print("   🚫 Contre-tendance: " + (tempData[i].isAgainstTrend ? "OUI" : "NON"));
      Print("   --------------------------------------------");
   }

   // Retourner le symbole principal (le meilleur)
   if(opportunitiesCount > 0) {
      return bestData[0].symbol;
   }

   return "";
}

//+------------------------------------------------------------------+
//| FONCTION PRINCIPALE: Vérification des vraies opportunités de spike |
//+------------------------------------------------------------------+
void CheckRealTradingOpportunities()
{
   // Symboles Boom/Crash à analyser
   string symbols[] = {"Boom 500 Index", "Boom 1000 Index", "Crash 500 Index", "Crash 1000 Index"};

   // Obtenir les meilleures opportunités (max 2)
   SymbolSpikeData bestOpportunities[];
   string bestSymbol = FindBestSpikeOpportunities(symbols, bestOpportunities, 2);

   if(bestSymbol != "")
   {
      Print("🎯 OPPORTUNITÉ SPIKE PRINCIPALE: ", bestSymbol, " (Score: ",
            DoubleToString(MathMin(100.0, bestOpportunities[0].spikeProbability), 1), "/100)");
   }

   // Stocker les données pour utilisation par d'autres fonctions
   if(ArraySize(bestOpportunities) > 0) {
      g_lastBestSymbol = bestOpportunities[0].symbol;
      g_lastSpikeProbability = bestOpportunities[0].spikeProbability;
      g_lastRealDirection = bestOpportunities[0].realDirection;
   }
}
