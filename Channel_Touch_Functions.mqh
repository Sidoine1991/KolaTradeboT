//+------------------------------------------------------------------+
//| CHANNEL TOUCH LIMIT ORDERS - NOUVELLES FONCTIONS                 |
//+------------------------------------------------------------------+

// Variables globales pour les ordres limit channel touch
datetime g_lastChannelTouchTime = 0;
bool g_channelTouchLimitPending = false;
string g_channelTouchSymbol = "";
double g_channelTouchLevel = 0.0;

// Variables IA partagées
string g_lastAIAction = "";
double g_lastAIConfidence = 0.0;

// Structure pour gérer les trades de double spike
struct DoubleSpikeTrade {
   string symbol;
   bool isActive;
   bool isBoom;
   datetime entryTime;
   datetime lastSpikeTime;
   double entryPrice;
   double channelLevel;
   int smallCandlesAfterLastSpike;
   ENUM_POSITION_TYPE positionType;
   ulong ticket;
   bool waitingForSecondSpike;
};

// Variables globales pour le double spike
DoubleSpikeTrade g_doubleSpikeTrades[];
int g_maxDoubleSpikeTrades = 2;

// Fonction pour détecter si le prix touche un canal SMC
bool IsPriceTouchingSMCChannel(string symbol, string &channelTouched, double &channelPrice)
{
   // Vérifier les objets de canal SMC sur le graphique
   // SMC_upper_chan pour les canaux supérieurs (résistance)
   // smc_lower_chan pour les canaux inférieurs (support)

   // Chercher SMC_upper_chan
   if(ObjectFind(0, "SMC_upper_chan") >= 0)
   {
      double upperChannel = ObjectGetDouble(0, "SMC_upper_chan", OBJPROP_PRICE);
      double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);

      // Vérifier si le prix touche le canal supérieur (avec une tolérance)
      double tolerance = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10; // 10 points de tolérance

      if(MathAbs(currentPrice - upperChannel) <= tolerance)
      {
         channelTouched = "SMC_upper_chan";
         channelPrice = upperChannel;
         return true;
      }
   }

   // Chercher smc_lower_chan
   if(ObjectFind(0, "smc_lower_chan") >= 0)
   {
      double lowerChannel = ObjectGetDouble(0, "smc_lower_chan", OBJPROP_PRICE);
      double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);

      // Vérifier si le prix touche le canal inférieur (avec une tolérance)
      double tolerance = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10; // 10 points de tolérance

      if(MathAbs(currentPrice - lowerChannel) <= tolerance)
      {
         channelTouched = "smc_lower_chan";
         channelPrice = lowerChannel;
         return true;
      }
   }

   return false;
}

// Fonction pour détecter un spike pendant le touché du canal
bool DetectSpikeDuringChannelTouch(string symbol, string channelTouched, double channelPrice, int &spikeDirection)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   if(CopyRates(symbol, PERIOD_M1, 0, 5, rates) < 5) return false;

   // Analyser les 3 dernières bougies pour détecter un spike
   double move1 = MathAbs(rates[1].close - rates[1].open);
   double move2 = MathAbs(rates[2].close - rates[2].open);
   double move3 = MathAbs(rates[3].close - rates[3].open);

   // Spike = mouvement significatif (au moins 2x la moyenne des mouvements précédents)
   double avgMove = (move1 + move2) / 2.0;
   double currentMove = move3;

   if(currentMove >= avgMove * 2.0 && currentMove >= SymbolInfoDouble(symbol, SYMBOL_POINT) * 50) // Au moins 50 points
   {
      // Déterminer la direction du spike
      if(channelTouched == "SMC_upper_chan")
      {
         // Pour canal supérieur (résistance), spike descendant attendu (Crash)
         if(rates[3].close < rates[3].open) // Bougie baissière
         {
            spikeDirection = -1; // SELL direction
            return true;
         }
      }
      else if(channelTouched == "smc_lower_chan")
      {
         // Pour canal inférieur (support), spike montant attendu (Boom)
         if(rates[3].close > rates[3].open) // Bougie haussière
         {
            spikeDirection = 1; // BUY direction
            return true;
         }
      }
   }

   return false;
}

// Fonction pour vérifier le signal IA compatible
bool IsAISignalCompatibleForChannelTouch(string symbol, int spikeDirection)
{
   // Vérifier que l'IA n'est pas en HOLD
   if(g_lastAIAction == "HOLD")
   {
      Print("🚫 CHANNEL TOUCH - IA en HOLD - Pas de signal valide");
      return false;
   }

   // Vérifier la direction selon le type de symbole
   bool isBoom = (StringFind(symbol, "Boom") >= 0);
   bool isCrash = (StringFind(symbol, "Crash") >= 0);

   if(!isBoom && !isCrash) return false; // Pas un symbole Boom/Crash

   if(isBoom && spikeDirection != 1) // Boom doit avoir direction BUY
   {
      Print("🚫 CHANNEL TOUCH - Boom nécessite direction BUY, spike détecté: ", spikeDirection);
      return false;
   }

   if(isCrash && spikeDirection != -1) // Crash doit avoir direction SELL
   {
      Print("🚫 CHANNEL TOUCH - Crash nécessite direction SELL, spike détecté: ", spikeDirection);
      return false;
   }

   // Vérifier que le signal IA correspond à la direction
   if((g_lastAIAction == "BUY" && spikeDirection == 1) ||
      (g_lastAIAction == "SELL" && spikeDirection == -1))
   {
      Print("✅ CHANNEL TOUCH - Signal IA compatible: ", g_lastAIAction, " | Direction spike: ", spikeDirection > 0 ? "BUY" : "SELL");
      return true;
   }

   Print("🚫 CHANNEL TOUCH - Signal IA incompatible: ", g_lastAIAction, " vs direction attendue: ", spikeDirection > 0 ? "BUY" : "SELL");
   return false;
}

// Fonction pour calculer le niveau de la 4ème petite bougie
double Calculate4thSmallCandleLevel(string symbol, int spikeDirection)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   if(CopyRates(symbol, PERIOD_M1, 0, 10, rates) < 10) return 0.0;

   // Identifier les "petites bougies" (corps < moyenne)
   double totalBody = 0.0;
   int smallCandlesCount = 0;
   double smallCandleLevels[];

   ArrayResize(smallCandleLevels, 10);

   for(int i = 1; i < 10; i++) // Commencer de la bougie 1 (plus récente après actuelle)
   {
      double body = MathAbs(rates[i].close - rates[i].open);
      totalBody += body;
   }

   double avgBody = totalBody / 9.0;

   // Collecter les niveaux des petites bougies
   for(int i = 1; i < 10; i++)
   {
      double body = MathAbs(rates[i].close - rates[i].open);
      if(body <= avgBody * 0.7) // Petite bougie = corps <= 70% de la moyenne
      {
         if(spikeDirection == 1) // BUY - prendre le haut de la bougie
            smallCandleLevels[smallCandlesCount] = rates[i].high;
         else // SELL - prendre le bas de la bougie
            smallCandleLevels[smallCandlesCount] = rates[i].low;

         smallCandlesCount++;
         if(smallCandlesCount >= 4) break; // On a besoin de la 4ème
      }
   }

   if(smallCandlesCount >= 4)
   {
      double level = smallCandleLevels[3]; // Index 3 = 4ème petite bougie
      Print("📊 CHANNEL TOUCH - 4ème petite bougie calculée: ", DoubleToString(level, _Digits),
            " | Direction: ", spikeDirection > 0 ? "BUY" : "SELL");
      return level;
   }

   Print("🚫 CHANNEL TOUCH - Impossible de calculer la 4ème petite bougie (trouvées: ", smallCandlesCount, ")");
   return 0.0;
}

// Fonction pour placer l'ordre limit
bool PlaceChannelTouchLimitOrder(string symbol, double entryPrice, int spikeDirection)
{
   // Vérifier qu'il n'y a pas déjà un ordre limit en attente
   if(g_channelTouchLimitPending)
   {
      Print("🚫 CHANNEL TOUCH - Ordre limit déjà en attente sur ", g_channelTouchSymbol);
      return false;
   }

   // Calculer SL/TP
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double atr = GetATRValue(symbol, PERIOD_M1, 14, 0);

   if(atr <= 0) atr = point * 300; // Valeur par défaut

   double sl, tp;
   double lot = 0.01; // Lot fixe pour commencer

   if(spikeDirection == 1) // BUY
   {
      sl = entryPrice - atr * 1.5;
      tp = entryPrice + atr * 3.0;
   }
   else // SELL
   {
      sl = entryPrice + atr * 1.5;
      tp = entryPrice - atr * 3.0;
   }

   // Normaliser les prix
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   entryPrice = NormalizeDouble(entryPrice, digits);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   // Créer l'ordre limit
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_PENDING;
   request.symbol = symbol;
   request.volume = lot;
   request.price = entryPrice;
   request.sl = sl;
   request.tp = tp;
   request.type = (spikeDirection == 1) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   request.magic = 20251115; // Magic number
   request.comment = "CHANNEL TOUCH LIMIT - " + (spikeDirection > 0 ? "BUY" : "SELL");

   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE)
      {
         g_channelTouchLimitPending = true;
         g_channelTouchSymbol = symbol;
         g_channelTouchLevel = entryPrice;
         g_lastChannelTouchTime = TimeCurrent();

         Print("✅ CHANNEL TOUCH - Ordre limit placé avec succès");
         Print("   📊 Symbole: ", symbol);
         Print("   🎯 Prix: ", DoubleToString(entryPrice, digits));
         Print("   📈 Type: ", spikeDirection > 0 ? "BUY LIMIT" : "SELL LIMIT");
         Print("   🛡️ SL: ", DoubleToString(sl, digits));
         Print("   💰 TP: ", DoubleToString(tp, digits));
         Print("   📝 Commentaire: ", request.comment);

         return true;
      }
   }

   Print("❌ CHANNEL TOUCH - Échec placement ordre limit: ", result.retcode);
   return false;
}

// Fonction principale pour gérer les touchés de canal
void CheckSMCChannelTouchLimitOrders()
{
   // Vérifier seulement sur les symboles Boom/Crash
   if(StringFind(_Symbol, "Boom") < 0 && StringFind(_Symbol, "Crash") < 0) return;

   // Éviter les vérifications trop fréquentes (une fois par bougie M1)
   static datetime lastCheckTime = 0;
   datetime currentTime = iTime(_Symbol, PERIOD_M1, 0);
   if(currentTime == lastCheckTime) return;
   lastCheckTime = currentTime;

   // Vérifier si le prix touche un canal SMC
   string channelTouched = "";
   double channelPrice = 0.0;

   if(!IsPriceTouchingSMCChannel(_Symbol, channelTouched, channelPrice))
   {
      return; // Pas de touché de canal
   }

   Print("🎯 CHANNEL TOUCH DÉTECTÉ - ", channelTouched, " à ", DoubleToString(channelPrice, _Digits));

   // Vérifier si c'est accompagné d'un spike
   int spikeDirection = 0;
   if(!DetectSpikeDuringChannelTouch(_Symbol, channelTouched, channelPrice, spikeDirection))
   {
      Print("🚫 CHANNEL TOUCH - Pas de spike détecté pendant le touché");
      return;
   }

   Print("⚡ CHANNEL TOUCH - Spike détecté - Direction: ", spikeDirection > 0 ? "HAUSSIER" : "BAISSIER");

   // Vérifier la compatibilité du signal IA
   if(!IsAISignalCompatibleForChannelTouch(_Symbol, spikeDirection))
   {
      return; // Signal IA incompatible
   }

   // Calculer le niveau de la 4ème petite bougie
   double limitLevel = Calculate4thSmallCandleLevel(_Symbol, spikeDirection);
   if(limitLevel <= 0)
   {
      Print("🚫 CHANNEL TOUCH - Impossible de calculer le niveau de la 4ème bougie");
      return;
   }

   // Placer l'ordre limit
   if(PlaceChannelTouchLimitOrder(_Symbol, limitLevel, spikeDirection))
   {
      Print("🎉 CHANNEL TOUCH - Stratégie complète exécutée avec succès!");
   }
}

// Fonction principale pour gérer la logique de double spike
void CheckAndExecuteDoubleSpikeTrades()
{
   // Vérifier les touchés de canal SMC
   CheckChannelTouchesForDoubleSpike();

   // Gérer les trades actifs de double spike
   ManageActiveDoubleSpikeTrades();
}

// Vérifier les touchés de canal et initier les trades de double spike
void CheckChannelTouchesForDoubleSpike()
{
   string symbols[] = {"Boom 500 Index", "Boom 1000 Index", "Crash 500 Index", "Crash 1000 Index"};

   for(int i = 0; i < ArraySize(symbols); i++) {
      string symbol = symbols[i];
      bool isBoom = (StringFind(symbol, "Boom") >= 0);
      bool isCrash = (StringFind(symbol, "Crash") >= 0);

      if(!isBoom && !isCrash) continue;

      // Vérifier si on peut initier un nouveau trade double spike
      if(CountActiveDoubleSpikeTrades() >= g_maxDoubleSpikeTrades) break;
      if(HasActiveDoubleSpikeTrade(symbol)) continue;

      // Analyser le touché de canal
      double channelLevel = GetChannelLevelForDoubleSpike(symbol, isBoom);
      if(channelLevel == 0.0) continue;

      // Vérifier si le prix touche le canal
      if(!IsPriceTouchingChannel(symbol, channelLevel, isBoom)) continue;

      // Attendre le premier spike et entrer immédiatement au marché
      if(DetectFirstSpikeAfterChannelTouch(symbol, isBoom, channelLevel)) {
         // Entrer immédiatement au marché pour capturer le second spike
         EnterDoubleSpikePosition(symbol, isBoom, channelLevel);
      }
   }
}

// Obtenir le niveau de canal SMC pour le double spike
double GetChannelLevelForDoubleSpike(string symbol, bool isBoom)
{
   string upperName = "SMC_CH_H1_UPPER";
   string lowerName = "SMC_CH_H1_LOWER";

   if(ObjectFind(0, upperName) < 0 || ObjectFind(0, lowerName) < 0) return 0.0;

   if(isBoom) {
      // Pour Boom, on surveille le canal inférieur (support)
      return ObjectGetDouble(0, lowerName, OBJPROP_PRICE);
   } else {
      // Pour Crash, on surveille le canal supérieur (résistance)
      return ObjectGetDouble(0, upperName, OBJPROP_PRICE);
   }
}

// Vérifier si le prix touche le canal
bool IsPriceTouchingChannel(string symbol, double channelLevel, bool isBoom)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

   if(isBoom) {
      // Pour Boom: vérifier si le prix touche ou dépasse légèrement le canal inférieur
      return (bid <= channelLevel + SymbolInfoDouble(symbol, SYMBOL_POINT) * 50);
   } else {
      // Pour Crash: vérifier si le prix touche ou dépasse légèrement le canal supérieur
      return (ask >= channelLevel - SymbolInfoDouble(symbol, SYMBOL_POINT) * 50);
   }
}

// Détecter le premier spike après le touché de canal
bool DetectFirstSpikeAfterChannelTouch(string symbol, bool isBoom, double channelLevel)
{
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, 0, 10, rates) < 10) return false;

   ArraySetAsSeries(rates, true);

   // Analyser les dernières bougies pour détecter un spike
   for(int i = 1; i <= 5; i++) {
      double body = MathAbs(rates[i].close - rates[i].open);
      double range = rates[i].high - rates[i].low;

      // Spike = corps significatif (au moins 60% de la range)
      if(body >= range * 0.6 && body >= SymbolInfoDouble(symbol, SYMBOL_POINT) * 100) {
         // Vérifier la direction du spike
         bool spikeUp = (rates[i].close > rates[i].open);
         bool spikeDown = (rates[i].close < rates[i].open);

         if((isBoom && spikeUp) || (!isBoom && spikeDown)) {
            Print("🚀 PREMIER SPIKE DÉTECTÉ sur ", symbol, " après touché canal - ENTRÉE MARCHÉ IMMÉDIATE !");
            return true;
         }
      }
   }

   return false;
}

// Fonction ATR helper
double GetATRValue(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift)
{
   int handle = iATR(symbol, timeframe, period);
   if(handle == INVALID_HANDLE) return 0.0;

   double value[1];
   if(CopyBuffer(handle, 0, shift, 1, value) <= 0)
   {
      IndicatorRelease(handle);
      return 0.0;
   }

   IndicatorRelease(handle);
   return value[0];
}

// Entrer immédiatement en position après le premier spike (pas d'attente petite bougie)
void EnterDoubleSpikePosition(string symbol, bool isBoom, double channelLevel)
{
   // Entrer immédiatement en position au prix actuel
   double entryPrice = isBoom ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
   ENUM_ORDER_TYPE orderType = isBoom ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   // Calculer SL/TP basé sur ATR pour capturer le mouvement de spike
   double atr = GetATRValue(symbol, PERIOD_M1, 14, 0);

   // SL plus serré pour les spikes (risque limité)
   double sl = entryPrice - (isBoom ? atr * 1.0 : -atr * 1.0);

   // TP plus large pour capturer le mouvement complet du double spike
   double tp = entryPrice + (isBoom ? atr * 4.0 : -atr * 4.0);

   // Placer l'ordre MARKET immédiatement
   MqlTradeRequest req = {};
   MqlTradeResult res = {};

   req.action = TRADE_ACTION_DEAL;
   req.symbol = symbol;
   req.volume = 0.01;
   req.type = orderType;
   req.price = entryPrice;
   req.sl = sl;
   req.tp = tp;
   req.magic = 123456; // Magic number spécial pour double spike
   req.comment = "DOUBLE_SPIKE_MARKET_ENTRY";

   if(OrderSend(req, res)) {
      // Enregistrer le trade double spike
      DoubleSpikeTrade newTrade;
      newTrade.symbol = symbol;
      newTrade.isActive = true;
      newTrade.isBoom = isBoom;
      newTrade.entryTime = TimeCurrent();
      newTrade.lastSpikeTime = TimeCurrent();
      newTrade.entryPrice = entryPrice;
      newTrade.channelLevel = channelLevel;
      newTrade.smallCandlesAfterLastSpike = 0;
      newTrade.positionType = isBoom ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      newTrade.ticket = res.order;
      newTrade.waitingForSecondSpike = true;

      // Ajouter au tableau
      int size = ArraySize(g_doubleSpikeTrades);
      ArrayResize(g_doubleSpikeTrades, size + 1);
      g_doubleSpikeTrades[size] = newTrade;

      Print("🚀 POSITION DOUBLE SPIKE MARCHÉ OUVERTE sur ", symbol);
      Print("   📍 Entrée: ", DoubleToString(entryPrice, _Digits));
      Print("   🎯 Canal: ", DoubleToString(channelLevel, _Digits));
      Print("   ⏳ Attente du SECOND SPIKE pour confirmer la tendance...");
   } else {
      Print("❌ ÉCHEC ENTRÉE DOUBLE SPIKE sur ", symbol, " - Erreur: ", res.retcode);
   }
}

// Gérer les trades actifs de double spike
void ManageActiveDoubleSpikeTrades()
{
   for(int i = ArraySize(g_doubleSpikeTrades) - 1; i >= 0; i--) {
      DoubleSpikeTrade trade = g_doubleSpikeTrades[i];

      if(!trade.isActive) continue;

      // Vérifier si position toujours ouverte
      if(!IsPositionStillOpen(trade.ticket)) {
         // Position fermée, retirer du tableau
         RemoveDoubleSpikeTrade(i);
         continue;
      }

      // Analyser les bougies après le dernier spike
      int smallCandlesCount = CountSmallCandlesAfterSpike(trade.symbol, trade.lastSpikeTime);

      if(trade.waitingForSecondSpike) {
         // Vérifier si un second spike arrive
         if(DetectSecondSpike(trade.symbol, trade.isBoom, trade.channelLevel)) {
            // Second spike détecté - garder la position
            trade.lastSpikeTime = TimeCurrent();
            trade.smallCandlesAfterLastSpike = 0;
            trade.waitingForSecondSpike = false;
            g_doubleSpikeTrades[i] = trade;

            Print("🎯 SECOND SPIKE DÉTECTÉ sur ", trade.symbol, " - Position maintenue");
         } else if(smallCandlesCount >= 5) {
            // Pas de second spike après 5 petites bougies - sortir
            CloseDoubleSpikePosition(trade, i);
         } else {
            trade.smallCandlesAfterLastSpike = smallCandlesCount;
            g_doubleSpikeTrades[i] = trade;
         }
      } else {
         // Position déjà en profit avec second spike - surveiller
         if(ShouldExitAtSupportResistance(trade)) {
            CloseDoubleSpikePosition(trade, i);
         }
      }
   }
}

// Compter les petites bougies après le dernier spike
int CountSmallCandlesAfterSpike(string symbol, datetime spikeTime)
{
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, spikeTime, 10, rates) < 10) return 0;

   ArraySetAsSeries(rates, true);

   int smallCount = 0;
   double avgBody = 0.0;

   // Calculer la moyenne des corps
   for(int i = 0; i < 10; i++) {
      avgBody += MathAbs(rates[i].close - rates[i].open);
   }
   avgBody /= 10.0;

   // Compter les petites bougies
   for(int i = 0; i < 10; i++) {
      if(rates[i].time > spikeTime) {
         double body = MathAbs(rates[i].close - rates[i].open);
         if(body < avgBody * 0.7) { // Petite bougie < 70% moyenne
            smallCount++;
         }
      }
   }

   return smallCount;
}

// Détecter le second spike
bool DetectSecondSpike(string symbol, bool isBoom, double channelLevel)
{
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, 0, 5, rates) < 5) return false;

   ArraySetAsSeries(rates, true);

   // Chercher un spike dans la même direction que le premier
   for(int i = 1; i <= 3; i++) {
      double body = MathAbs(rates[i].close - rates[i].open);
      double range = rates[i].high - rates[i].low;

      if(body >= range * 0.6 && body >= SymbolInfoDouble(symbol, SYMBOL_POINT) * 80) {
         bool spikeUp = (rates[i].close > rates[i].open);
         bool spikeDown = (rates[i].close < rates[i].open);

         if((isBoom && spikeUp) || (!isBoom && spikeDown)) {
            return true;
         }
      }
   }

   return false;
}

// Vérifier si on doit sortir à un niveau de support/résistance proche
bool ShouldExitAtSupportResistance(DoubleSpikeTrade &trade)
{
   double currentPrice = SymbolInfoDouble(trade.symbol, trade.isBoom ? SYMBOL_BID : SYMBOL_ASK);

   // Pour Boom: chercher une résistance proche au-dessus
   // Pour Crash: chercher un support proche en-dessous

   double exitLevel = FindNearSupportResistance(trade.symbol, trade.isBoom);

   if(exitLevel == 0.0) return false;

   if(trade.isBoom) {
      // Boom: sortir quand prix atteint résistance proche
      return (currentPrice >= exitLevel);
   } else {
      // Crash: sortir quand prix atteint support proche
      return (currentPrice <= exitLevel);
   }
}

// Trouver un niveau de support/résistance proche
double FindNearSupportResistance(string symbol, bool isBoom)
{
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, 0, 50, rates) < 50) return 0.0;

   ArraySetAsSeries(rates, true);

   double currentPrice = SymbolInfoDouble(symbol, isBoom ? SYMBOL_BID : SYMBOL_ASK);
   double nearestLevel = 0.0;
   double minDistance = DBL_MAX;

   // Chercher les niveaux récents de swing high/low
   for(int i = 5; i < 30; i++) {
      double high = rates[i].high;
      double low = rates[i].low;

      if(isBoom) {
         // Pour Boom: chercher résistance (swing high) proche au-dessus
         double distance = high - currentPrice;
         if(distance > 0 && distance < minDistance && distance < SymbolInfoDouble(symbol, SYMBOL_POINT) * 500) {
            minDistance = distance;
            nearestLevel = high;
         }
      } else {
         // Pour Crash: chercher support (swing low) proche en-dessous
         double distance = currentPrice - low;
         if(distance > 0 && distance < minDistance && distance < SymbolInfoDouble(symbol, SYMBOL_POINT) * 500) {
            minDistance = distance;
            nearestLevel = low;
         }
      }
   }

   return nearestLevel;
}

// Fermer une position double spike
void CloseDoubleSpikePosition(DoubleSpikeTrade &trade, int index)
{
   // Fermer la position avec MqlTradeRequest
   MqlTradeRequest req = {};
   MqlTradeResult res = {};

   req.action = TRADE_ACTION_DEAL;
   req.position = trade.ticket;
   req.symbol = trade.symbol;
   req.volume = PositionGetDouble(POSITION_VOLUME);
   req.type = (trade.positionType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.price = (req.type == ORDER_TYPE_SELL) ?
               SymbolInfoDouble(trade.symbol, SYMBOL_BID) :
               SymbolInfoDouble(trade.symbol, SYMBOL_ASK);
   req.deviation = 10;

   if(OrderSend(req, res)) {
      Print("🔄 POSITION DOUBLE SPIKE FERMÉE sur ", trade.symbol);
      Print("   💰 Durée: ", TimeCurrent() - trade.entryTime, " secondes");
      Print("   📍 Raison: ", trade.waitingForSecondSpike ? "Pas de second spike après 5 petites bougies" : "Niveau S/R atteint");
   } else {
      Print("❌ ERREUR FERMETURE DOUBLE SPIKE sur ", trade.symbol, " - Code: ", res.retcode);
   }

   // Retirer du tableau
   RemoveDoubleSpikeTrade(index);
}

// Fonctions utilitaires
int CountActiveDoubleSpikeTrades()
{
   int count = 0;
   for(int i = 0; i < ArraySize(g_doubleSpikeTrades); i++) {
      if(g_doubleSpikeTrades[i].isActive) count++;
   }
   return count;
}

bool HasActiveDoubleSpikeTrade(string symbol)
{
   for(int i = 0; i < ArraySize(g_doubleSpikeTrades); i++) {
      if(g_doubleSpikeTrades[i].isActive && g_doubleSpikeTrades[i].symbol == symbol) {
         return true;
      }
   }
   return false;
}

bool IsPositionStillOpen(ulong ticket)
{
   return PositionSelectByTicket(ticket);
}

void RemoveDoubleSpikeTrade(int index)
{
   for(int i = index; i < ArraySize(g_doubleSpikeTrades) - 1; i++) {
      g_doubleSpikeTrades[i] = g_doubleSpikeTrades[i + 1];
   }
   ArrayResize(g_doubleSpikeTrades, ArraySize(g_doubleSpikeTrades) - 1);
}
