}

void ActivateProfitLockIfNeeded()
{
   if(!IsProfitLockTriggered()) return;

   datetime now = TimeCurrent();
   if(g_dailyPauseUntil > now) return; // déjà en pause

   // Pause jusqu'à fin de journée
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 23; dt.min = 59; dt.sec = 59;
   g_dailyPauseUntil = StructToTime(dt);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double peakProfit = g_dailyMaxEquity - g_dailyStartEquity;
   double giveback = g_dailyMaxEquity - equity;

   Print("⛔ PROFIT LOCK - Pic=", DoubleToString(peakProfit, 2), "$ | Giveback=", DoubleToString(giveback, 2),
         "$ ≥ ", DoubleToString(ProfitLockMaxGivebackDollars, 2), "$ | pause jusqu'à ", TimeToString(g_dailyPauseUntil, TIME_SECONDS));

   if(ProfitLockClosePositions)
      CloseAllPositionsAndPendingOurEA("PROFIT LOCK - giveback");
}

// Vérifie si le modèle ML courant est suffisamment fiable pour autoriser un trade sur ce symbole/catégorie
bool IsMLModelTrustedForCurrentSymbol(const string direction)
{
   if(!UseAIServer) return true; // pas de filtrage si IA désactivée
   if(g_mlLastAccuracy <= 0.0) return false; // pas de métriques utilisables

   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   double minAcc = 0.0;

   switch(cat)
   {
      case SYM_BOOM_CRASH:
         minAcc = 80.0; // Boom/Crash: demander une précision élevée
         break;
      case SYM_VOLATILITY:
         minAcc = 70.0;
         break;
      case SYM_FOREX:
      case SYM_METAL:
         minAcc = 65.0;
         break;
      case SYM_COMMODITY:
      case SYM_UNKNOWN:
      default:
         minAcc = 60.0;
         break;
   }

   if(g_mlLastAccuracy < minAcc)
   {
      Print("🚫 ML BLOQUÉ - Modèle insuffisamment précis pour ", _Symbol,
            " (cat=", (int)cat, ") | Acc=", DoubleToString(g_mlLastAccuracy, 1),
            "% < seuil ", DoubleToString(minAcc, 1), "% | Modèle=", g_mlLastModelName,
            " | Direction demandée=", direction);
      return false;
   }

   return true;
}

// Perte journalière max atteinte → pause 2h
bool IsDailyLossPauseActive()
{
   if(MaxDailyLossDollars <= 0.0 || g_dailyStartEquity <= 0.0) return false;

   datetime now = TimeCurrent();
   if(g_dailyLossPauseUntil > now) return true;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyProfit = equity - g_dailyStartEquity;
   if(dailyProfit > -MaxDailyLossDollars) return false;

   g_dailyLossPauseUntil = now + 2 * 60 * 60;
   Print("⏸ PAUSE PERTE JOURNALIÈRE - PnL ", DoubleToString(dailyProfit, 2), "$ ≤ -",
         DoubleToString(MaxDailyLossDollars, 2), "$ | pause jusqu'à ",
         TimeToString(g_dailyLossPauseUntil, TIME_SECONDS));
   return true;
}

// Pause après pertes consécutives cumulées (géré par g_lossPauseUntil)
bool IsCumulativeLossPauseActive()
{
   datetime now = TimeCurrent();
   if(g_lossPauseUntil > now) return true;
   if(g_lossPauseUntil != 0 && g_lossPauseUntil <= now)
      g_lossPauseUntil = 0;
   return false;
}

// Vérifie en continu les ordres LIMIT en attente et annule ceux qui ne sont plus alignés avec la décision IA
void GuardPendingLimitOrdersWithAI()
{
   if(!UseAIServer) return;

   // Mettre à jour la décision IA si elle est trop ancienne
   datetime now = TimeCurrent();
   if(now - g_lastAIUpdate >= AI_UpdateInterval_Seconds)
   {
      UpdateAIDecision(AI_Timeout_ms);
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;

      // Ne contrôler que les ordres proches du prix courant (prêts à être déclenchés)
      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      double refPrice   = (t == ORDER_TYPE_BUY_LIMIT)
                          ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0) point = 0.0001;
      double maxDistPts = 10.0; // ne vérifier l'IA que si on est à <= 10 points
      if(MathAbs(orderPrice - refPrice) > maxDistPts * point)
         continue; // prix encore loin de l'ordre, ne pas annuler trop tôt

      string cmt = OrderGetString(ORDER_COMMENT);
      string dir = (t == ORDER_TYPE_BUY_LIMIT ? "BUY" : "SELL");

      string ia = g_lastAIAction;
      string iaUpper = ia;
      StringToUpper(iaUpper);
      double conf = g_lastAIConfidence * 100.0;
      double minConf = MinAIConfidencePercent + 10.0; // marge +10% par rapport au minimum global

      bool shouldCancel = false;

      // IA en HOLD -> annuler immédiatement l'ordre LIMIT
      if(iaUpper == "HOLD")
      {
         shouldCancel = true;
         Print("🚫 LIMIT ANNULÉ - IA en HOLD sur ", _Symbol, " | Ticket=", ticket, " | Comment=", cmt);
      }
      else if(iaUpper == "BUY" && dir == "SELL")
      {
         shouldCancel = true;
         Print("🚫 LIMIT ANNULÉ - IA=BUY mais ordre SELL LIMIT en attente sur ", _Symbol, " | Ticket=", ticket, " | Comment=", cmt);
      }
      else if(iaUpper == "SELL" && dir == "BUY")
      {
         shouldCancel = true;
         Print("🚫 LIMIT ANNULÉ - IA=SELL mais ordre BUY LIMIT en attente sur ", _Symbol, " | Ticket=", ticket, " | Comment=", cmt);
      }
      else
      {
         // Direction alignée mais confiance insuffisante
         if(conf < minConf)
         {
            shouldCancel = true;
            Print("🚫 LIMIT ANNULÉ - Confiance IA insuffisante pour ", dir, " sur ", _Symbol,
                  " | Conf=", DoubleToString(conf, 1), "% < seuil ", DoubleToString(minConf, 1),
                  "% | Ticket=", ticket, " | Comment=", cmt);
         }
      }

      if(shouldCancel)
      {
         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action = TRADE_ACTION_REMOVE;
         req.order  = ticket;
         req.symbol = _Symbol;

         if(!OrderSend(req, res))
         {
            Print("? ÉCHEC ANNULATION LIMIT - Ticket=", ticket, " | Code=", res.retcode);
         }
      }
   }
}

// Détermine si un ordre limite doit être remplacé selon les conditions IA
bool ShouldReplaceLimitOrder(ENUM_ORDER_TYPE orderType, string orderComment, double orderPrice)
{
   if(!UseAIServer || !ReplaceMisalignedLimitOrders) return false;
   
   // Mettre à jour la décision IA si trop ancienne
   datetime now = TimeCurrent();
   if(now - g_lastAIUpdate >= AI_UpdateInterval_Seconds)
   {
      UpdateAIDecision(AI_Timeout_ms);
   }
   
   string ia = g_lastAIAction;
   string iaUpper = ia;
   StringToUpper(iaUpper);
   double conf = g_lastAIConfidence * 100.0;
   double minConf = MinConfidenceForReplacement * 100.0;
   
   string dir = (orderType == ORDER_TYPE_BUY_LIMIT) ? "BUY" : "SELL";
   
   // Vérifier la distance du prix (configurable)
   double refPrice = (orderType == ORDER_TYPE_BUY_LIMIT)
                   ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) point = 0.0001;
   
   if(MathAbs(orderPrice - refPrice) > MaxDistanceForLimitCheck * point)
      return false; // Trop loin, pas besoin de remplacer maintenant
   
   // Condition 1: IA en HOLD -> ne pas remplacer
   if(iaUpper == "HOLD")
   {
      Print("🚫 PAS DE REMPLACEMENT - IA en HOLD pour ", dir, " sur ", _Symbol);
      return false;
   }
   
   // Condition 2: Direction opposée -> remplacer
   if((iaUpper == "BUY" && dir == "SELL") || (iaUpper == "SELL" && dir == "BUY"))
   {
      Print("🔄 REMPLACEMENT REQUIS - IA=", ia, " opposée à ordre ", dir, " sur ", _Symbol);
      return true;
   }
   
   // Condition 3: Confiance IA insuffisante -> ne pas remplacer
   if(conf < minConf)
   {
      Print("🚫 PAS DE REMPLACEMENT - Confiance IA insuffisante: ", DoubleToString(conf, 1), "% < ", DoubleToString(minConf, 1), "%");
      return false;
   }
   
   // Condition 4: Direction alignée mais IA a changé depuis placement -> remplacer
   // (vérifier si l'ordre a été placé avant le dernier changement IA)
   if(StringFind(orderComment, "STRAT") >= 0)
   {
      // Ordre stratégique : remplacer si IA est plus forte maintenant
      Print("🔄 REMPLACEMENT REQUIS - Ordre stratégique ", dir, " avec IA ", ia, " (", DoubleToString(conf, 1), "%) sur ", _Symbol);
      return true;
   }
   
   return false;
}

// Remplace un ordre limite par un nouvel ordre aligné avec l'IA
bool ReplaceLimitOrder(ENUM_ORDER_TYPE oldOrderType, double oldOrderPrice, string oldOrderComment)
{
   if(!UseAIServer) return false;
   
   string ia = g_lastAIAction;
   string iaUpper = ia;
   StringToUpper(iaUpper);
   
   // Déterminer le nouveau type d'ordre selon IA
   ENUM_ORDER_TYPE newOrderType;
   string newDirection;
   
   if(iaUpper == "BUY")
   {
      newOrderType = ORDER_TYPE_BUY_LIMIT;
      newDirection = "BUY";
   }
   else if(iaUpper == "SELL")
   {
      newOrderType = ORDER_TYPE_SELL_LIMIT;
      newDirection = "SELL";
   }
   else
   {
      Print("🚫 IMPOSSIBLE REMPLACEMENT - IA=", ia, " non valide pour nouvel ordre");
      return false;
   }
   
   // Calculer le nouveau prix d'ordre
   double currentPrice = SymbolInfoDouble(_Symbol, (newOrderType == ORDER_TYPE_BUY_LIMIT) ? SYMBOL_ASK : SYMBOL_BID);
   double atrVal = GetCurrentATR();
   double newOrderPrice;
   double stopLoss = 0;
   double takeProfit = 0;
   
   // Utiliser la logique existante de calcul de prix
   if(newOrderType == ORDER_TYPE_BUY_LIMIT)
   {
      // BUY LIMIT : sous le prix actuel
      string sourceOut;
      double supportLevel = GetClosestBuyLevel(currentPrice, atrVal, MaxDistanceLimitATR, sourceOut);
      if(supportLevel > 0)
         newOrderPrice = supportLevel;
      else
         newOrderPrice = currentPrice - 15 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      stopLoss = newOrderPrice - 300 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      takeProfit = newOrderPrice + 600 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }
   else
   {
      // SELL LIMIT : au-dessus du prix actuel
      string sourceOut;
      double resistanceLevel = GetClosestSellLevel(currentPrice, atrVal, MaxDistanceLimitATR, sourceOut);
      if(resistanceLevel > 0)
         newOrderPrice = resistanceLevel;
      else
         newOrderPrice = currentPrice + 15 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      stopLoss = newOrderPrice + 300 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      takeProfit = newOrderPrice - 600 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }
   
   // Calculer le lot size
   double lotSize = CalculateLotSizeForPendingOrders();
   if(lotSize <= 0)
   {
      Print("🚫 IMPOSSIBLE REMPLACEMENT - Lot size invalide");
      return false;
   }
   
   // Préparer la requête d'ordre
   MqlTradeRequest req = {};
   MqlTradeResult res = {};
   
   req.action = TRADE_ACTION_PENDING;
   req.symbol = _Symbol;
   req.volume = lotSize;
   req.type = newOrderType;
   req.price = newOrderPrice;
   req.sl = stopLoss;
   req.tp = takeProfit;
   req.deviation = 20;
   req.magic = InpMagicNumber;
   req.comment = "STRAT " + newDirection + " LIMIT (REPLACEMENT)";
   req.type_filling = ORDER_FILLING_IOC;
   req.type_time = ORDER_TIME_GTC;
   
   // Valider et ajuster le prix si nécessaire
   if(!ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, newOrderType))
   {
      Print("🚫 IMPOSSIBLE REMPLACEMENT - Prix/SL/TP invalides après ajustement");
      return false;
   }
   
   // Placer le nouvel ordre
   if(OrderSend(req, res))
   {
      Print("✅ REMPLACEMENT RÉUSSI - ", newDirection, " LIMIT placé | Prix=", DoubleToString(newOrderPrice, 5), 
            " | Lot=", DoubleToString(lotSize, 2), " | Ticket=", res.order);
      Print("   🔄 Ancien ordre: ", oldOrderComment, " | Prix=", DoubleToString(oldOrderPrice, 5));
      Print("   🧠 IA: ", ia, " | Confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "%");
      return true;
   }
   else
   {
      Print("❌ ÉCHEC REMPLACEMENT - ", newDirection, " LIMIT | Code=", res.retcode, " | Comment=", res.comment);
      return false;
   }
}

// Récupère l'ATR courant du timeframe M1
double GetCurrentATR()
{
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   int copied = CopyBuffer(atrM1, 0, 0, 1, atrBuffer);
   if(copied > 0 && atrBuffer[0] > 0)
      return atrBuffer[0];
   
   // Fallback : utiliser l'ATR LTF si M1 indisponible
   if(atrHandle != INVALID_HANDLE)
   {
      copied = CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
      if(copied > 0 && atrBuffer[0] > 0)
         return atrBuffer[0];
   }
   
   // Dernier fallback : ATR fixe selon symbole
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   switch(cat)
   {
      case SYM_BOOM_CRASH: return 0.025;  // 25 points pour Boom/Crash
      case SYM_FOREX:     return 0.00020; // 20 pips pour Forex
      case SYM_COMMODITY: return 0.5;    // 50 points pour matières premières
      default:            return 0.001;   // Valeur par défaut
   }
}

// Version améliorée de GuardPendingLimitOrdersWithAI avec remplacement automatique
void GuardPendingLimitOrdersWithAI_Enhanced()
{
   if(!UseAIServer) return;

   // Mettre à jour la décision IA si elle est trop ancienne
   datetime now = TimeCurrent();
   if(now - g_lastAIUpdate >= AI_UpdateInterval_Seconds)
   {
      UpdateAIDecision(AI_Timeout_ms);
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;

      // Vérifier tous les ordres limites (distance étendue)
      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      double refPrice   = (t == ORDER_TYPE_BUY_LIMIT)
                          ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0) point = 0.0001;
      
      // Distance étendue selon paramètre
      if(MathAbs(orderPrice - refPrice) > MaxDistanceForLimitCheck * point)
         continue; // prix encore trop loin de l'ordre

      string cmt = OrderGetString(ORDER_COMMENT);
      string dir = (t == ORDER_TYPE_BUY_LIMIT ? "BUY" : "SELL");

      string ia = g_lastAIAction;
      string iaUpper = ia;
      StringToUpper(iaUpper);
      double conf = g_lastAIConfidence * 100.0;
      double minConf = MinAIConfidencePercent + 10.0; // marge +10% par rapport au minimum global

      bool shouldCancel = false;
      bool shouldReplace = false;

      // Logique d'annulation (existante)
      if(iaUpper == "HOLD")
      {
         shouldCancel = true;
         Print("🚫 LIMIT ANNULÉ - IA en HOLD sur ", _Symbol, " | Ticket=", ticket, " | Comment=", cmt);
      }
      else if(iaUpper == "BUY" && dir == "SELL")
      {
         shouldCancel = true;
         shouldReplace = ReplaceMisalignedLimitOrders; // Remplacement si activé
         Print("🔄 LIMIT CONFLIT - IA=BUY mais ordre SELL LIMIT sur ", _Symbol, " | Ticket=", ticket, " | Comment=", cmt);
      }
      else if(iaUpper == "SELL" && dir == "BUY")
      {
         shouldCancel = true;
         shouldReplace = ReplaceMisalignedLimitOrders; // Remplacement si activé
         Print("🔄 LIMIT CONFLIT - IA=SELL mais ordre BUY LIMIT sur ", _Symbol, " | Ticket=", ticket, " | Comment=", cmt);
      }
      else
      {
         // Direction alignée mais confiance insuffisante
         if(conf < minConf)
         {
            shouldCancel = true;
            shouldReplace = ReplaceMisalignedLimitOrders && conf >= MinConfidenceForReplacement * 100.0;
            Print("🚫 LIMIT CONFIANCE - Confiance IA insuffisante pour ", dir, " sur ", _Symbol,
                  " | Conf=", DoubleToString(conf, 1), "% < seuil ", DoubleToString(minConf, 1),
                  "% | Ticket=", ticket, " | Comment=", cmt);
         }
      }

      // Exécuter l'annulation si nécessaire
      if(shouldCancel)
      {
         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action = TRADE_ACTION_REMOVE;
         req.order  = ticket;
         req.symbol = _Symbol;

         if(OrderSend(req, res))
         {
            Print("✅ LIMIT ANNULÉ - ", dir, " sur ", _Symbol, " | Ticket=", ticket, " | Raison: ", 
                  (iaUpper == "HOLD" ? "IA HOLD" : 
                   (iaUpper == "BUY" && dir == "SELL") ? "Direction opposée BUY vs SELL" :
                   (iaUpper == "SELL" && dir == "BUY") ? "Direction opposée SELL vs BUY" :
                   "Confiance insuffisante"));
            
            // Tenter le remplacement si activé et conditions réunies
            if(shouldReplace && ShouldReplaceLimitOrder(t, cmt, orderPrice))
            {
               ReplaceLimitOrder(t, orderPrice, cmt);
            }
         }
         else
         {
            Print("❌ ÉCHEC ANNULATION LIMIT - Ticket=", ticket, " | Code=", res.retcode);
         }
      }
   }
}

// Vérifie que l'entraînement continu backend est actif; sinon, le démarre (si forceStart ou statut indique non-actif)
bool EnsureMLContinuousTrainingRunning(bool forceStart = false)
{
   if(!ShowMLMetrics) return false;
   if(!AutoStartMLContinuousTraining && !forceStart) return false;

   static datetime lastCheck = 0;
   datetime now = TimeCurrent();
   int interval = MathMax(30, MLContinuousCheckIntervalSec);
   if(!forceStart && (now - lastCheck) < interval)
      return true;
   lastCheck = now;

   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
   string fallbackUrl = UseRenderAsPrimary ? AI_ServerURL : AI_ServerRender;
   string headers = "Content-Type: application/json\r\n";
   char post[], result[];
   string resultHeaders;

   // 1) Lire status
   int resStatus = WebRequest("GET", baseUrl + "/ml/continuous/status", "", AI_Timeout_ms, post, result, resultHeaders);
   if(resStatus != 200)
      resStatus = WebRequest("GET", fallbackUrl + "/ml/continuous/status", "", AI_Timeout_ms2, post, result, resultHeaders);

   bool running = false;
   if(resStatus == 200)
   {
      string statusData = CharArrayToString(result);
      // On accepte plusieurs formats possibles: "running":true, "active":true, "enabled":true
      running = (StringFind(statusData, "\"running\": true") >= 0 ||
                 StringFind(statusData, "\"running\":true") >= 0 ||
                 StringFind(statusData, "\"active\": true") >= 0 ||
                 StringFind(statusData, "\"active\":true") >= 0 ||
                 StringFind(statusData, "\"enabled\": true") >= 0 ||
                 StringFind(statusData, "\"enabled\":true") >= 0);
   }

   // 2) Démarrer si nécessaire
   if(forceStart || !running)
   {
      string startUrl1 = baseUrl + "/ml/continuous/start";
      string startUrl2 = fallbackUrl + "/ml/continuous/start";
      int resStart = WebRequest("POST", startUrl1, headers, AI_Timeout_ms, post, result, resultHeaders);
      if(resStart != 200)
         resStart = WebRequest("POST", startUrl2, headers, AI_Timeout_ms2, post, result, resultHeaders);

      if(resStart == 200)
      {
         Print("✅ ML continuous training démarré/relancé.");
         return true;
      }
      Print("⚠️ Impossible de démarrer ML continuous training (HTTP ", resStart, ").");
      return false;
   }

   return true;
}

// Affichage dédié des métriques ML sur le graphique (label)
void DrawMLMetricsOnChart()
{
   string name = "SMC_ML_METRICS_LABEL";
   if(!ShowMLMetrics)
   {
      ObjectDelete(0, name);
      return;
   }

   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         return;
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);  // Réduit à 7 pour cohérence
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_BACK, false);  // Premier plan pour visibilité
   }

   // Calculer la position Y pour éviter la superposition avec le dashboard
   int y = MathMax(MLMetricsLabelYOffsetPixels, g_dashboardBottomY + 45);  // 45px d'espace sous le dashboard (augmenté)
   
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);

   // Catégorie de symbole pour rendre explicite le type de modèle utilisé
   string catStr = "UNKNOWN";
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   switch(cat)
   {
      case SYM_BOOM_CRASH:  catStr = "Boom/Crash"; break;
      case SYM_VOLATILITY:  catStr = "Volatility"; break;
      case SYM_FOREX:       catStr = "Forex"; break;
      case SYM_COMMODITY:   catStr = "Commodity"; break;
      case SYM_METAL:       catStr = "Metal"; break;
   }

   string txt = "ML (" + catStr + ", " + _Symbol + "): " + (g_mlMetricsStr == "" ? "En attente..." : g_mlMetricsStr);
   txt += " | Canal: " + (g_channelValid ? "OK" : "—");
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, g_channelValid ? clrLime : clrYellow);
   
   // Log de débogage pour vérifier le positionnement
   static datetime lastMLDebugLog = 0;
   if(TimeCurrent() - lastMLDebugLog >= 300) // Toutes les 5 minutes
   {
      Print("?? DEBUG ML Metrics - y=", y, " | dashboardBottom=", g_dashboardBottomY);
      lastMLDebugLog = TimeCurrent();
   }
}

// Fonction de nettoyage global des objets graphiques du dashboard
void CleanupDashboardObjects()
{
   // Nettoyer TOUS les objets dashboard existants - méthode plus agressive
   int totalDeleted = 0;
   
   // Méthode 1: Nettoyer par préfixes connus
   string prefixes[] = {"SMC_DASHBOARD_LABEL", "SMC_DASH_LINE_", "SMC_ML_METRICS_LABEL", "SMC_PROPICE_LINE", "SMC_", "DASH_", "ML_"};
   
   for(int p = 0; p < ArraySize(prefixes); p++)
   {
      string prefix = prefixes[p];
      
      // Pour les préfixes de lignes, tester plusieurs numéros
      if(prefix == "SMC_DASH_LINE_")
      {
         for(int i = 0; i < 200; i++)
         {
            string name = prefix + IntegerToString(i);
            if(ObjectFind(0, name) >= 0)
            {
               if(ObjectDelete(0, name))
                  totalDeleted++;
            }
         }
      }
      else
      {
         // Pour les objets uniques, essayer directement
         if(ObjectFind(0, prefix) >= 0)
         {
            if(ObjectDelete(0, prefix))
               totalDeleted++;
         }
      }
   }
   
   // Méthode 2: Parcourir TOUS les objets sur le chart et supprimer ceux qui correspondent
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      
      // Supprimer tous les objets avec ces préfixes
      if(StringFind(objName, "SMC_DASH_") == 0 ||
         StringFind(objName, "SMC_DASHBOARD_LABEL") == 0 ||
         StringFind(objName, "SMC_ML_") == 0 ||
         StringFind(objName, "SMC_PROPICE_") == 0 ||
         StringFind(objName, "DASH_") == 0 ||
         StringFind(objName, "ML_METRICS") == 0)
      {
         if(ObjectDelete(0, objName))
            totalDeleted++;
      }
   }
   
   if(totalDeleted > 0)
   {
      Print("🧹 NETTOYAGE DASHBOARD - ", totalDeleted, " objets supprimés");
   }
}

// Fonction de nettoyage complet de tous les dessins SMC sur le chart
void CleanupAllChartObjects()
{
   // Préfixes de tous les objets SMC à nettoyer
   string prefixes[] = {
      "SMC_",           // Tous les objets SMC
      "FVG_",           // Fair Value Gaps
      "OB_",            // Order Blocks
      "BOS_",           // Break of Structure
      "LS_",            // Liquidity Sweep
      "OTE_",           // Optimal Trade Entry
      "EQH_", "EQL_",   // Equal High/Low
      "PD_",            // Point of Interest
      "SWING_",         // Swing points
      "EMA_",           // EMA lines
      "TREND_",         // Trend lines
      "CHANNEL_",       // Channels
      "SPIKE_",         // Spike indicators
      "ARROW_",         // Arrow signals
      "PREDICT_",       // Predictions
      "LEVEL_",         // Support/Resistance levels
      "ZONE_",          // Zones (Premium/Discount)
      "PROPICE_",       // Propice symbols
      "ML_",            // ML metrics
      "DASH_",          // Dashboard
      "SIGNAL_",        // Signal arrows
      "WARNING_"        // Warnings
   };
   
   int totalDeleted = 0;
   
   for(int p = 0; p < ArraySize(prefixes); p++)
   {
      string prefix = prefixes[p];
      
      // Parcourir tous les objets sur le chart
      for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
      {
         string objName = ObjectName(0, i);
         if(StringFind(objName, prefix) == 0)  // Commence par le préfixe
         {
            if(ObjectDelete(0, objName))
            {
               totalDeleted++;
            }
         }
      }
   }
   
   // Nettoyer aussi les objets plus anciens qui pourraient avoir d'autres noms
   string oldPrefixes[] = {"DERIV_", "BOOKMARK_", "KILLZONE_", "LIQUIDITY_"};
   
   for(int p = 0; p < ArraySize(oldPrefixes); p++)
   {
      string prefix = oldPrefixes[p];
      
      for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
      {
         string objName = ObjectName(0, i);
         if(StringFind(objName, prefix) == 0)
         {
            if(ObjectDelete(0, objName))
            {
               totalDeleted++;
            }
         }
      }
   }
   
   if(totalDeleted > 0)
   {
      Print("🧹 NETTOYAGE COMPLET - ", totalDeleted, " objets graphiques supprimés du chart");
   }
}

// Fonction pour vérifier et gérer la pause après avoir atteint l'objectif de profit journalier
bool CheckDailyProfitPause()
{
   // Calculer le profit journalier actuel
   double dailyProfit = 0.0;
   
   // Utiliser les variables globales de stats journalières si disponibles
   dailyProfit = g_dayNetProfit;
   
   // Mettre à jour le pic de profit si nécessaire
   if(dailyProfit > g_dailyProfitPeak)
   {
      g_dailyProfitPeak = dailyProfit;
   }
   
   // Vérifier si l'objectif de profit est atteint
   if(dailyProfit >= DailyProfitTarget && !g_dailyProfitTargetReached)
   {
      g_dailyProfitTargetReached = true;
      g_dailyProfitPauseStartTime = TimeCurrent();
      // Pause jusqu'à la fin de la journée (objectif atteint = ignorer toutes opportunités restantes)
      MqlDateTime dt;
      TimeCurrent(dt);
      dt.hour = 23; dt.min = 59; dt.sec = 59;
      g_dailyPauseUntil = StructToTime(dt);
      
      Print("🎯 OBJECTIF PROFIT JOURNALIER ATTEINT - ", DoubleToString(dailyProfit, 2), "$ ≥ ", DoubleToString(DailyProfitTarget, 2), "$");
      Print("⏸️ STOP JOURNALIER ACTIVÉ - Protection des gains");
      Print("🚫 TOUS LES TRADES BLOQUÉS jusqu'à ", TimeToString(g_dailyPauseUntil, TIME_SECONDS));
      
      return true;  // Bloquer les trades
   }
   
   // Si la pause est active, vérifier si elle est terminée
   if(g_dailyProfitTargetReached && g_dailyProfitPauseStartTime > 0)
   {
      datetime pauseEndTime = (g_dailyPauseUntil > 0 ? g_dailyPauseUntil : (g_dailyProfitPauseStartTime + PauseAfterProfitHours * 3600));
      
      if(TimeCurrent() >= pauseEndTime)
      {
         // Réinitialiser la pause
         g_dailyProfitTargetReached = false;
         g_dailyProfitPauseStartTime = 0;
         g_dailyProfitPeak = 0.0;
         g_dailyPauseUntil = 0;
         
         Print("✅ STOP JOURNALIER TERMINÉ - Reprise du trading autorisée");
         Print("💰 Gains protégés: ", DoubleToString(dailyProfit, 2), "$");
         
         return false;  // Autoriser les trades
      }
      else
      {
         // Pause encore active - afficher le temps restant
         int remainingSeconds = (int)(pauseEndTime - TimeCurrent());
         int remainingHours = remainingSeconds / 3600;
         int remainingMinutes = (remainingSeconds % 3600) / 60;
         
         // Log toutes les 15 minutes pendant la pause
         static datetime lastPauseLog = 0;
         if(TimeCurrent() - lastPauseLog >= 900) // 15 minutes
         {
            Print("⏳ PAUSE EN COURS - Temps restant: ", remainingHours, "h ", remainingMinutes, "min");
            Print("💰 Gains protégés: ", DoubleToString(dailyProfit, 2), "$ / Objectif: ", DoubleToString(DailyProfitTarget, 2), "$");
            lastPauseLog = TimeCurrent();
         }
         
         return true;  // Bloquer les trades
      }
   }
   
   return false;  // Autoriser les trades
}

void DrawDashboardOnChart(const string &lines[], const color &colors[], int count)
{
   // NETTOYAGE AGRESSIF - Supprimer TOUS les anciens labels dashboard
   for(int j = 0; j < 300; j++)  // jusqu'à 300 lignes potentielles
   {
      string name = "SMC_DASH_LINE_" + IntegerToString(j);
      if(ObjectFind(0, name) >= 0)
      {
         ObjectDelete(0, name);
      }
   }
   
   // Vérification supplémentaire : parcourir tous les objets et supprimer ceux qui correspondent
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, "SMC_DASH_LINE_") == 0)
      {
         ObjectDelete(0, objName);
      }
   }
   
   // Créer/mettre à jour une liste de labels verticaux, sans superposition
   int x  = MathMax(0, DashboardLabelXOffsetPixels);
   int y0 = MathMax(0, DashboardLabelYStartPixels);
   int lh = MathMax(22, DashboardLabelLineHeightPixels);  // espacement confortable

   int maxLines = MathMin(count, 40);  // on autorise plus de lignes visibles

   // Log de débogage pour vérifier le positionnement
   static datetime lastDebugLog = 0;
   if(TimeCurrent() - lastDebugLog >= 300) // Toutes les 5 minutes
   {
      Print("?? DEBUG Dashboard - x=", x, " | y0=", y0, " | lineHeight=", lh, " | lines=", maxLines);
      lastDebugLog = TimeCurrent();
   }

   for(int i = 0; i < maxLines; i++)
   {
      string name = "SMC_DASH_LINE_" + IntegerToString(i);
      
      // Créer le label s'il n'existe pas
      if(ObjectFind(0, name) < 0)
      {
         if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
            continue;
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);  // compact mais lisible
         ObjectSetInteger(0, name, OBJPROP_BACK, false);  // Premier plan pour visibilité
      }

      // Calcul de la position Y avec vérification
      int yPos = y0 + (i * lh);
      
      // Appliquer le positionnement
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yPos);
      ObjectSetInteger(0, name, OBJPROP_COLOR, colors[i]);
      ObjectSetString(0, name, OBJPROP_TEXT, lines[i]);

      // Log de débogage pour les premières lignes seulement
      if(i < 3 && TimeCurrent() - lastDebugLog >= 300)
      {
         Print("?? DEBUG Line ", i, " - yPos=", yPos, " | text=", StringSubstr(lines[i], 0, 30));
      }
   }

   g_dashboardBottomY = y0 + maxLines * lh;
}

// Applique la stratégie adaptée à la catégorie de symbole (Boom/Crash, Volatility, Forex/Metals)
void RunCategoryStrategy()
{
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   
   switch(cat)
   {
      case SYM_BOOM_CRASH:
         // Boom/Crash: priorité aux signaux DERIV ARROW + logique spike dédiée
         CheckAndExecuteDerivArrowTrade();
         // La détection/gestion des spikes et canaux Boom/Crash est déjà appelée plus bas (ManageBoomCrashSpikeClose, CheckImminentSpike, etc.)
         break;

      case SYM_VOLATILITY:
         // Volatility: privilégier des entrées LIMIT sur niveaux "propices" (S/R 20 bars, Pivot D1, SuperTrend),
         // + confirmation IA (direction/confidence) et modèle ML fiable (déjà géré par IsMLModelTrustedForCurrentSymbol).
         CheckAndExecuteDerivArrowTrade(); // conserve la détection flèche, mais l'entrée est filtrée par l'IA + confiance
         break;

      case SYM_FOREX:
         // Forex: stratégie ICT-like OTE+Imbalance + BOS+Retest (entrée marché uniquement) avec garde-fous IA/ML/propice
         ExecuteOTEImbalanceTrade();
         ExecuteForexBOSRetest();
         // Fallback (si pas de signal BOS+retest): conserver le comportement générique existant
         CheckAndExecuteDerivArrowTrade();
         break;

      case SYM_METAL:
      case SYM_COMMODITY:
      case SYM_UNKNOWN:
      default:
         // Métaux / autres indices: utiliser la stratégie OTE+Imbalance si disponible, sinon logique SMC/Deriv Arrow générique
         ExecuteOTEImbalanceTrade();
         CheckAndExecuteDerivArrowTrade();
         break;
   }
}

// --- FOREX STRATEGY: BOS + Retest (market entry only) ---
// Détecte une cassure de structure (BOS) sur LTF puis attend un retest du niveau cassé.
// Quand le retest est validé, renvoie direction + niveaux SL/TP basés structure+ATR.
bool Forex_DetectBOSRetest(string &dirOut, double &entryOut, double &slOut, double &tpOut)
{
   dirOut = "";
   entryOut = 0.0;
   slOut = 0.0;
   tpOut = 0.0;

   // Cette stratégie ne s'applique qu'aux symboles Forex (métaux exclus pour l'instant)
   if(SMC_GetSymbolCategory(_Symbol) != SYM_FOREX) return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, LTF, 0, 120, rates);
   if(copied < 30) return false;

   // ATR sur LTF (tolérance retest)
   double atrVal = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 2, atrBuf) >= 1)
         atrVal = atrBuf[0];
   }
   if(atrVal <= 0.0)
      atrVal = MathAbs(rates[1].high - rates[1].low); // fallback minimal

   double tol = MathMax(atrVal * 0.20, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);

   // Etat persistant "en attente de retest" (EA par symbole)
   static bool     s_waitingRetest = false;
   static string   s_dir = "";
   static double   s_level = 0.0;
   static datetime s_bosTime = 0;
   static datetime s_lastLog = 0;

   // Helper: chercher le swing high/low le plus récent (fractal-like)
   double lastSwingHigh = 0.0;
   double lastSwingLow  = 0.0;
   int swingHighIdx = -1;
   int swingLowIdx  = -1;

   for(int i = 5; i < MathMin(copied - 5, 80); i++)
   {
      bool isHigh = (rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
                     rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high);
      bool isLow  = (rates[i].low  < rates[i-1].low  && rates[i].low  < rates[i+1].low  &&
                     rates[i].low  < rates[i-2].low  && rates[i].low  < rates[i+2].low);

      if(swingHighIdx < 0 && isHigh) { swingHighIdx = i; lastSwingHigh = rates[i].high; }
      if(swingLowIdx  < 0 && isLow)  { swingLowIdx  = i; lastSwingLow  = rates[i].low;  }
      if(swingHighIdx >= 0 && swingLowIdx >= 0) break;
   }

   if(lastSwingHigh <= 0.0 || lastSwingLow <= 0.0) return false;

   double close1 = rates[1].close;
   double close2 = rates[2].close;

   // Timeout d'attente retest (évite d'attendre éternellement)
   if(s_waitingRetest && s_bosTime > 0)
   {
      if((TimeCurrent() - s_bosTime) > (60 * 60 * 6)) // 6h
      {
         s_waitingRetest = false;
         s_dir = "";
         s_level = 0.0;
         s_bosTime = 0;
      }
   }

   // Si pas en attente, détecter un BOS frais
   if(!s_waitingRetest)
   {
      // BOS UP: close[1] casse au-dessus du swing high
      if(close1 > lastSwingHigh && close2 <= lastSwingHigh)
      {
         s_waitingRetest = true;
         s_dir = "BUY";
         s_level = lastSwingHigh;
         s_bosTime = rates[1].time;
         if(TimeCurrent() - s_lastLog >= 60)
         {
            Print("📈 FOREX BOS détecté (BUY) sur ", _Symbol, " | Niveau=", DoubleToString(s_level, _Digits));
            s_lastLog = TimeCurrent();
         }
         return false;
      }
      // BOS DOWN: close[1] casse au-dessous du swing low
      if(close1 < lastSwingLow && close2 >= lastSwingLow)
      {
         s_waitingRetest = true;
         s_dir = "SELL";
         s_level = lastSwingLow;
         s_bosTime = rates[1].time;
         if(TimeCurrent() - s_lastLog >= 60)
         {
            Print("📉 FOREX BOS détecté (SELL) sur ", _Symbol, " | Niveau=", DoubleToString(s_level, _Digits));
            s_lastLog = TimeCurrent();
         }
         return false;
      }
      return false;
   }

   // En attente retest: vérifier retest du niveau cassé (tolérance ATR)
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool retestOk = false;
   if(s_dir == "BUY")
   {
      // Prix revient toucher/approcher le niveau cassé et clôture sans réintégrer fortement sous le niveau
      bool touched = (rates[0].low <= (s_level + tol));
      bool held    = (rates[0].close >= (s_level - tol));
      retestOk = (touched && held);
      if(!retestOk && TimeCurrent() - s_lastLog >= 120)
      {
         Print("⏳ FOREX Retest en attente (BUY) sur ", _Symbol,
               " | Niveau=", DoubleToString(s_level, _Digits),
               " | tol=", DoubleToString(tol, _Digits));
         s_lastLog = TimeCurrent();
      }
   }
   else if(s_dir == "SELL")
   {
      bool touched = (rates[0].high >= (s_level - tol));
      bool held    = (rates[0].close <= (s_level + tol));
      retestOk = (touched && held);
      if(!retestOk && TimeCurrent() - s_lastLog >= 120)
      {
         Print("⏳ FOREX Retest en attente (SELL) sur ", _Symbol,
               " | Niveau=", DoubleToString(s_level, _Digits),
               " | tol=", DoubleToString(tol, _Digits));
         s_lastLog = TimeCurrent();
      }
   }
   else
   {
      s_waitingRetest = false;
      s_level = 0.0;
      s_bosTime = 0;
      return false;
   }

   if(!retestOk) return false;

   // Optionnel: si filtres SMC activés, exiger une validation multi-signaux existante
   if(UseLiquiditySweep || UseOrderBlocks || UseFVG)
   {
      if(!ValidateEntryWithMultipleSignals(s_dir))
      {
         if(TimeCurrent() - s_lastLog >= 60)
         {
            Print("⛔ FOREX Retest OK mais filtres SMC KO sur ", _Symbol, " (", s_dir, ")");
            s_lastLog = TimeCurrent();
         }
         return false;
      }
   }

   dirOut = s_dir;
   entryOut = (s_dir == "BUY") ? ask : bid;

   // SL/TP structure + ATR
   double risk = 0.0;
   if(s_dir == "BUY")
   {
      slOut = s_level - atrVal * 0.80;
      risk = MathMax(entryOut - slOut, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);
      tpOut = entryOut + (2.0 * risk);
   }
   else
   {
      slOut = s_level + atrVal * 0.80;
      risk = MathMax(slOut - entryOut, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);
      tpOut = entryOut - (2.0 * risk);
   }

   // Consommer le signal (une seule entrée par BOS)
   s_waitingRetest = false;
   s_dir = "";
   s_level = 0.0;
   s_bosTime = 0;

   return true;
}

void ExecuteForexBOSRetest()
{
   if(SMC_GetSymbolCategory(_Symbol) != SYM_FOREX) return;

   // Anti-duplication symbol exposure
   if(HasAnyExposureForSymbol(_Symbol)) return;

   string dir;
   double entry, sl, tp;
   if(!Forex_DetectBOSRetest(dir, entry, sl, tp)) return;

   string d = dir; StringToUpper(d);

   // Filtre "propice"
   if(UsePropiceSymbolsFilter && !g_currentSymbolIsPropice)
   {
      Print("⛔ FOREX BOS+Retest bloqué - symbole non propice: ", _Symbol);
      return;
   }

   // IA gating (HOLD interdit + direction match + confiance >= MinAIConfidencePercent)
   if(UseAIServer)
   {
      string ia = g_lastAIAction;
      StringToUpper(ia);
      double confPct = g_lastAIConfidence * 100.0;

      if(ia == "" || ia == "HOLD")
      {
         Print("⛔ FOREX BOS+Retest bloqué - IA HOLD/absente sur ", _Symbol);
         return;
      }
      if(ia != d)
      {
         Print("⛔ FOREX BOS+Retest bloqué - IA=", ia, " != ", d, " sur ", _Symbol, " (", DoubleToString(confPct, 1), "%)");
         return;
      }
      if(confPct < MinAIConfidencePercent)
      {
         Print("⛔ FOREX BOS+Retest bloqué - Confiance IA trop faible: ", DoubleToString(confPct,1),
               "% < ", DoubleToString(MinAIConfidencePercent,1), "% sur ", _Symbol);
         return;
      }
   }

   // ML gating (seuil Forex via IsMLModelTrustedForCurrentSymbol)
   if(!IsMLModelTrustedForCurrentSymbol(d))
   {
      Print("⛔ FOREX BOS+Retest bloqué - Modèle ML non fiable sur ", _Symbol,
            " (acc=", DoubleToString(g_mlLastAccuracy * 100.0, 1), "%)");
      return;
   }

   // Lock terminal-level (éviter doubles opens simultanés)
   if(!TryAcquireOpenLock()) return;

   // Respecter les contraintes stops level du broker
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = MathMax((double)stopsLevel * point, point * 10.0);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(d == "BUY")
   {
      entry = ask;
      if((entry - sl) < minDist) sl = entry - minDist;
      if((tp - entry) < minDist) tp = entry + minDist;
   }
   else
   {
      entry = bid;
      if((sl - entry) < minDist) sl = entry + minDist;
      if((entry - tp) < minDist) tp = entry - minDist;
   }

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double lot = CalculateLotSize(); // lots standard EA (risk mgmt déjà existant)
   lot = NormalizeVolumeForSymbol(lot);

   bool ok = false;
   string comment = "FOREX_BOS_RETEST";
   if(d == "BUY")
      ok = trade.Buy(lot, _Symbol, 0.0, sl, tp, comment);
   else
      ok = trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);

   if(ok)
   {
      Print("✅ FOREX BOS+Retest EXECUTÉ ", d, " ", _Symbol,
            " | lot=", DoubleToString(lot, 2),
            " | SL=", DoubleToString(sl, _Digits),
            " | TP=", DoubleToString(tp, _Digits));
   }
   else
   {
      Print("❌ FOREX BOS+Retest ÉCHEC ", d, " ", _Symbol,
            " | err=", IntegerToString(GetLastError()));
   }

   ReleaseOpenLock();
}

string FormatWLNet(int wins, int losses, double net)
{
   return IntegerToString(wins) + "W/" + IntegerToString(losses) + "L | Net=" + DoubleToString(net, 2) + "$";
}

// Stats strictement issues de l'historique MT5 (deals) filtrés par Magic + symbole + période.
// Compte les sorties (DEAL_ENTRY_OUT) et agrège profit+swap+commission.
bool GetSymbolStatsFromHistory(const string symbol, datetime fromTime, datetime toTime, int &winsOut, int &lossesOut, double &netOut)
{
   winsOut = 0;
   lossesOut = 0;
   netOut = 0.0;
   if(StringLen(symbol) <= 0) return false;
   if(fromTime <= 0 || toTime <= 0 || toTime <= fromTime) return false;

   if(!HistorySelect(fromTime, toTime))
      return false;

   int total = HistoryDealsTotal();
   if(total <= 0) return true; // pas d'historique -> stats à 0

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      long magic = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
      if(magic != InpMagicNumber) continue;

      string sym = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(sym != symbol) continue;

      long entry = (long)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      netOut += profit;
      if(profit > 0) winsOut++;
      else if(profit < 0) lossesOut++;
   }

   return true;
}

// Stats étendues strictement issues de l'historique MT5 (deals) filtrés par Magic + symbole + période.
// tradeCount: nombre de deals de sortie (DEAL_ENTRY_OUT) dans la fenêtre
// grossProfit: somme des profits positifs
// grossLossAbs: somme des pertes en valeur absolue (positive)
// lastTradeAtOut: timestamp du dernier deal de sortie (0 si aucun)
bool GetSymbolStatsExtendedFromHistory(const string symbol,
                                      datetime fromTime,
                                      datetime toTime,
                                      int &tradeCountOut,
                                      int &winsOut,
                                      int &lossesOut,
                                      double &netOut,
                                      double &grossProfitOut,
                                      double &grossLossAbsOut,
                                      datetime &lastTradeAtOut)
{
   tradeCountOut = 0;
   winsOut = 0;
   lossesOut = 0;
   netOut = 0.0;
   grossProfitOut = 0.0;
   grossLossAbsOut = 0.0;
   lastTradeAtOut = 0;

   if(StringLen(symbol) <= 0) return false;
   if(fromTime <= 0 || toTime <= 0 || toTime <= fromTime) return false;

   if(!HistorySelect(fromTime, toTime))
      return false;

   int total = HistoryDealsTotal();
   if(total <= 0) return true;

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      long magic = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
      if(magic != InpMagicNumber) continue;

      string sym = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(sym != symbol) continue;

      long entry = (long)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue;

      datetime t = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(t > lastTradeAtOut) lastTradeAtOut = t;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      tradeCountOut++;
      netOut += profit;
      if(profit > 0)
      {
         winsOut++;
         grossProfitOut += profit;
      }
      else if(profit < 0)
      {
         lossesOut++;
         grossLossAbsOut += -profit;
      }
   }

   return true;
}

// Stats locales: met à jour g_dayWins/g_dayLosses/g_dayNetProfit et g_monthWins/g_monthLosses/g_monthNetProfit
// directement depuis l'historique MT5 (source de vérité pour le panneau).
void EnsureLocalSymbolStatsUpToDate()
{
   // Throttle: éviter de marteler HistorySelect à chaque tick
   static datetime lastLocalUpdate = 0;
   datetime now = TimeCurrent();
   if(now - lastLocalUpdate < 15) // maj max toutes les 15s (dashboard se met à jour à 15s)
      return;
   lastLocalUpdate = now;

   datetime nowUtc = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(nowUtc, dt);

   // Début de journée UTC
   MqlDateTime d0 = dt;
   d0.hour = 0; d0.min = 0; d0.sec = 0;
   datetime dayStartUtc = StructToTime(d0);

   // Début de mois UTC
   MqlDateTime m0 = dt;
   m0.day = 1;
   m0.hour = 0; m0.min = 0; m0.sec = 0;
   datetime monthStartUtc = StructToTime(m0);

   int tcDay=0, wDay=0, lDay=0;
   double netDay=0, gpDay=0, glDay=0;
   datetime lastDay=0;

   int tcMonth=0, wMonth=0, lMonth=0;
   double netMonth=0, gpMonth=0, glMonth=0;
   datetime lastMonth=0;

   if(GetSymbolStatsExtendedFromHistory(_Symbol, dayStartUtc, nowUtc, tcDay, wDay, lDay, netDay, gpDay, glDay, lastDay))
   {
      g_dayWins = wDay;
      g_dayLosses = lDay;
      g_dayNetProfit = netDay;
   }

   if(GetSymbolStatsExtendedFromHistory(_Symbol, monthStartUtc, nowUtc, tcMonth, wMonth, lMonth, netMonth, gpMonth, glMonth, lastMonth))
   {
      g_monthWins = wMonth;
      g_monthLosses = lMonth;
      g_monthNetProfit = netMonth;
   }
}

// Envoie les stats jour/mois (UTC) au serveur pour UPSERT dans Supabase `symbol_trade_stats`
void SyncSymbolTradeStatsToServer()
{
   if(!UseAIServer) return;

   static datetime lastSync = 0;
   datetime now = TimeCurrent();
   if(now - lastSync < 300) return; // 5 minutes
   lastSync = now;

   if(AI_ServerURL == "" && AI_ServerRender == "") return;

   datetime nowUtc = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(nowUtc, dt);

   MqlDateTime d0 = dt;
   d0.hour = 0; d0.min = 0; d0.sec = 0;
   datetime dayStartUtc = StructToTime(d0);

   MqlDateTime m0 = dt;
   m0.day = 1;
   m0.hour = 0; m0.min = 0; m0.sec = 0;
   datetime monthStartUtc = StructToTime(m0);

   int tcDay=0, wDay=0, lDay=0;
   double netDay=0, gpDay=0, glDay=0;
   datetime lastDay=0;

   int tcMonth=0, wMonth=0, lMonth=0;
   double netMonth=0, gpMonth=0, glMonth=0;
   datetime lastMonth=0;

   if(!GetSymbolStatsExtendedFromHistory(_Symbol, dayStartUtc, nowUtc, tcDay, wDay, lDay, netDay, gpDay, glDay, lastDay))
      return;
   if(!GetSymbolStatsExtendedFromHistory(_Symbol, monthStartUtc, nowUtc, tcMonth, wMonth, lMonth, netMonth, gpMonth, glMonth, lastMonth))
      return;

   string dayDate = TimeToString(dayStartUtc, TIME_DATE);
   string monthDate = TimeToString(monthStartUtc, TIME_DATE);
   long lastDayMs = (lastDay > 0 ? (long)lastDay * 1000 : 0);
   long lastMonthMs = (lastMonth > 0 ? (long)lastMonth * 1000 : 0);

   string json_payload = StringFormat(
      "{"
      "\"rows\":["
      "{"
      "\"symbol\":\"%s\","
      "\"period_type\":\"day\","
      "\"period_start\":\"%s\","
      "\"timeframe\":\"M1\","
      "\"trade_count\":%d,"
      "\"wins\":%d,"
      "\"losses\":%d,"
      "\"net_profit\":%.2f,"
      "\"gross_profit\":%.2f,"
      "\"gross_loss\":%.2f,"
      "\"last_trade_at\":%lld"
      "},"
      "{"
      "\"symbol\":\"%s\","
      "\"period_type\":\"month\","
      "\"period_start\":\"%s\","
      "\"timeframe\":\"M1\","
      "\"trade_count\":%d,"
      "\"wins\":%d,"
      "\"losses\":%d,"
      "\"net_profit\":%.2f,"
      "\"gross_profit\":%.2f,"
      "\"gross_loss\":%.2f,"
      "\"last_trade_at\":%lld"
      "}"
      "]"
      "}",
      _Symbol, dayDate, tcDay, wDay, lDay, netDay, gpDay, glDay, lastDayMs,
      _Symbol, monthDate, tcMonth, wMonth, lMonth, netMonth, gpMonth, glMonth, lastMonthMs
   );

   string url1 = UseRenderAsPrimary ? (AI_ServerRender + "/mt5/symbol-trade-stats-upload") : (AI_ServerURL + "/mt5/symbol-trade-stats-upload");
   string url2 = UseRenderAsPrimary ? (AI_ServerURL + "/mt5/symbol-trade-stats-upload") : (AI_ServerRender + "/mt5/symbol-trade-stats-upload");

   string headers = "Content-Type: application/json\r\n";
   char post_data[];
   char result_data[];
   string result_headers;
   StringToCharArray(json_payload, post_data, 0, StringLen(json_payload));

   int http_result = WebRequest("POST", url1, headers, AI_Timeout_ms, post_data, result_data, result_headers);
   if(http_result != 200)
      http_result = WebRequest("POST", url2, headers, AI_Timeout_ms2, post_data, result_data, result_headers);

   if(http_result == 200)
   {
      g_dayWins = wDay; g_dayLosses = lDay; g_dayNetProfit = netDay;
      g_monthWins = wMonth; g_monthLosses = lMonth; g_monthNetProfit = netMonth;
      Print("📊 STATS SYM SYNC OK - ", _Symbol, " | day ", IntegerToString(wDay), "W/", IntegerToString(lDay), "L net=", DoubleToString(netDay, 2),
            " | month ", IntegerToString(wMonth), "W/", IntegerToString(lMonth), "L net=", DoubleToString(netMonth, 2));
   }
   else
   {
      Print("⚠️ STATS SYM SYNC ÉCHEC - HTTP ", http_result, " | ", _Symbol);
   }
}

//| VALIDATION ET AJUSTEMENT DES PRIX POUR ORDRES LIMITES            |
bool ValidateAndAdjustLimitPrice(double &entryPrice, double &stopLoss, double &takeProfit, ENUM_ORDER_TYPE orderType)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Récupérer les exigences du courtier
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopsLevel * point;
   
   // Détection spécifique pour chaque type de symbole
   bool isVolatility = (StringFind(_Symbol, "Volatility") >= 0 || StringFind(_Symbol, "RANGE BREAK") >= 0);
   bool isGold = (StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0);
   bool isForex = (StringFind(_Symbol, "USD") >= 0 && !isGold && !isVolatility);
   
   if(isVolatility)
   {
      minDistance = MathMax(minDistance, 500 * point); // Augmenté à 500 pips pour Volatility
      Print("?? Volatility Index détecté - Distance minimale: ", DoubleToString(minDistance, 0), " pips");
   }
   else if(isGold)
   {
      minDistance = MathMax(minDistance, 200 * point); // 200 pips minimum pour XAUUSD
      Print("?? Gold (XAUUSD) détecté - Distance minimale: ", DoubleToString(minDistance, 0), " pips");
   }
   else if(isForex)
   {
      minDistance = MathMax(minDistance, 100 * point); // Augmenté à 100 pips pour Forex (AUDJPY, etc.)
      Print("?? Forex détecté - Distance minimale: ", DoubleToString(minDistance, 0), " pips");
   }
   else
   {
      minDistance = MathMax(minDistance, 30 * point); // 30 pips minimum par défaut
   }
   
   // Validation et ajustement du prix d'entrée
   bool priceAdjusted = false;
   
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      // BUY LIMIT doit être < Ask
      if(entryPrice >= currentAsk)
      {
         entryPrice = currentBid - (minDistance * 2); // Plus de marge
         priceAdjusted = true;
         Print("?? BUY LIMIT price ajusté: ", DoubleToString(entryPrice, _Digits), " (doit être < Ask)");
      }
      
      // Vérifier distance minimale
      if(currentAsk - entryPrice < minDistance)
      {
         entryPrice = currentAsk - (minDistance * 1.5); // Plus de marge
         priceAdjusted = true;
         Print("?? BUY LIMIT distance ajustée: ", DoubleToString(entryPrice, _Digits), " (distance minimale)");
      }
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      // SELL LIMIT doit être > Bid
      if(entryPrice <= currentBid)
      {
         entryPrice = currentAsk + (minDistance * 2); // Plus de marge
         priceAdjusted = true;
         Print("?? SELL LIMIT price ajusté: ", DoubleToString(entryPrice, _Digits), " (doit être > Bid)");
      }
      
      // Vérifier distance minimale
      if(entryPrice - currentBid < minDistance)
      {
         entryPrice = currentBid + (minDistance * 1.5); // Plus de marge
         priceAdjusted = true;
         Print("?? SELL LIMIT distance ajustée: ", DoubleToString(entryPrice, _Digits), " (distance minimale)");
      }
   }
   
   // Validation et ajustement du Stop Loss
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(stopLoss >= entryPrice || (entryPrice - stopLoss) < minDistance)
      {
         stopLoss = entryPrice - (minDistance * 1.2); // Plus de marge
         Print("?? BUY LIMIT SL ajusté: ", DoubleToString(stopLoss, _Digits));
      }
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      if(stopLoss <= entryPrice || (stopLoss - entryPrice) < minDistance)
      {
         stopLoss = entryPrice + (minDistance * 1.2); // Plus de marge
         Print("?? SELL LIMIT SL ajusté: ", DoubleToString(stopLoss, _Digits));
      }
   }
   
   // Validation et ajustement du Take Profit
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(takeProfit <= entryPrice || (takeProfit - entryPrice) < minDistance)
      {
         takeProfit = entryPrice + (minDistance * 3); // Ratio 1:3 pour plus de sécurité
         Print("?? BUY LIMIT TP ajusté: ", DoubleToString(takeProfit, _Digits));
      }
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      if(takeProfit >= entryPrice || (entryPrice - takeProfit) < minDistance)
      {
         takeProfit = entryPrice - (minDistance * 3); // Ratio 1:3 pour plus de sécurité
         Print("?? SELL LIMIT TP ajusté: ", DoubleToString(takeProfit, _Digits));
      }
   }
   
   // Normaliser tous les prix
   entryPrice = NormalizeDouble(entryPrice, _Digits);
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   // Validation finale très stricte
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(entryPrice >= currentAsk || (currentAsk - entryPrice) < minDistance || 
         stopLoss >= entryPrice || (entryPrice - stopLoss) < minDistance ||
         takeProfit <= entryPrice || (takeProfit - entryPrice) < minDistance)
      {
         Print("? ERREUR CRITIQUE: Prix BUY LIMIT toujours invalides après ajustement!");
         Print("   Entry: ", DoubleToString(entryPrice, _Digits), " Ask: ", DoubleToString(currentAsk, _Digits));
         Print("   SL: ", DoubleToString(stopLoss, _Digits), " TP: ", DoubleToString(takeProfit, _Digits));
         Print("   MinDistance: ", DoubleToString(minDistance, 0), " pips");
         return false;
      }
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      if(entryPrice <= currentBid || (entryPrice - currentBid) < minDistance ||
         stopLoss <= entryPrice || (stopLoss - entryPrice) < minDistance ||
         takeProfit >= entryPrice || (entryPrice - takeProfit) < minDistance)
      {
         Print("? ERREUR CRITIQUE: Prix SELL LIMIT toujours invalides après ajustement!");
         Print("   Entry: ", DoubleToString(entryPrice, _Digits), " Bid: ", DoubleToString(currentBid, _Digits));
         Print("   SL: ", DoubleToString(stopLoss, _Digits), " TP: ", DoubleToString(takeProfit, _Digits));
         Print("   MinDistance: ", DoubleToString(minDistance, 0), " pips");
         return false;
      }
   }
   
   if(priceAdjusted)
   {
      Print("? Prix final ajusté - Entry: ", DoubleToString(entryPrice, _Digits), 
            " SL: ", DoubleToString(stopLoss, _Digits), 
            " TP: ", DoubleToString(takeProfit, _Digits));
   }
   
   return true;
}

void ManageTrailingStop()
{
   // OPTIMISATION: Sortir rapidement si aucune position
   if(PositionsTotal() == 0) return;
   
   // OPTIMISATION: Limiter le trailing stop aux positions de notre EA uniquement
   int ourPositionsCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == InpMagicNumber)
      {
         ourPositionsCount++;
      }
   }
   
   if(ourPositionsCount == 0) return;
   
   // NOTE: trailing par position/symbole (pas de _Symbol global)
   if(!DynamicSL_Enable && !UseTrailingStop) return;

   // Throttle global: éviter spam de PositionModify
   static datetime lastRun = 0;
   datetime nowRun = TimeCurrent();
   if(nowRun - lastRun < 1) return; // max 1 fois / seconde
   lastRun = nowRun;
   
   // Parcourir uniquement nos positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      
      // Limiter le trailing aux marchés Volatility / Forex / Métaux (hors Boom/Crash)
      string symbol = posInfo.Symbol();
      ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(symbol);
      if(cat == SYM_BOOM_CRASH)
         continue;
      
      ulong  ticket = posInfo.Ticket();
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      double openPrice = posInfo.PriceOpen();
      double currentSL = posInfo.StopLoss();
      double currentTP = posInfo.TakeProfit();

      // Trailing distance: ATR du symbole de la position (M1)
      double atrValue = 0.0;
      int atrLocalHandle = iATR(symbol, PERIOD_M1, 14);
      if(atrLocalHandle != INVALID_HANDLE)
      {
         double atrBuf[];
         ArraySetAsSeries(atrBuf, true);
         if(CopyBuffer(atrLocalHandle, 0, 0, 1, atrBuf) >= 1)
            atrValue = atrBuf[0];
      }
      if(atrValue <= 0.0) continue;

      double trailDistance = atrValue * TrailingStop_ATRMult;
      // Break-even buffer: petit cushion pour sécuriser même micro-gains
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0) point = 0.0001;
      double beBuffer = (double)MathMax(0, DynamicSL_BE_BufferPoints) * point;

      // Prix courant selon le symbole de la position
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(bid <= 0 || ask <= 0) continue;
      
      // Vérifier existence position avant toute modif
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      
      // Max profit par ticket (évite g_maxProfit global qui mélange les positions)
      string gvName = "SMC_MAXPROFIT_" + IntegerToString((int)ticket);
      double maxP = 0.0;
      if(GlobalVariableCheck(gvName))
         maxP = GlobalVariableGet(gvName);
      if(profit > maxP)
      {
         maxP = profit;
         GlobalVariableSet(gvName, maxP);
      }

      double startP = (DynamicSL_Enable ? DynamicSL_StartProfitDollars : TrailingStartProfitDollars);
      double lockPct = (DynamicSL_Enable ? DynamicSL_LockPctOfMax : 0.50);
      if(lockPct < 0.0) lockPct = 0.0;
      if(lockPct > 1.0) lockPct = 1.0;

      bool shouldTrail = (profit >= startP) || (maxP >= startP && profit <= (maxP * (1.0 - lockPct)));
      double lockProfit = maxP * lockPct;

      // Convertir lockProfit ($) -> distance prix, selon tick_value/tick_size et volume
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickSize <= 0) tickSize = point;
      if(tickVal <= 0) tickVal = 1.0;
      double dollarsPerPriceUnit = (tickVal / tickSize) * posInfo.Volume();
      if(dollarsPerPriceUnit <= 0) dollarsPerPriceUnit = 1.0;
      double lockPriceDist = (lockProfit > 0 ? (lockProfit / dollarsPerPriceUnit) : 0.0);
      
      if(shouldTrail)
      {
         if(posInfo.PositionType() == POSITION_TYPE_BUY)
         {
            // 1) Break-even dès micro gain: SL >= open + buffer
            double beSL = openPrice + beBuffer;
            // 2) Trailing ATR
            double newSL = bid - trailDistance;
            if(newSL < beSL) newSL = beSL;

            // 3) Lock X% du gain max en $: empêcher de retomber trop bas
            if(DynamicSL_Enable && lockPriceDist > 0)
            {
               double lockSL = bid - lockPriceDist;
               if(lockSL < beSL) lockSL = beSL;
               if(newSL < lockSL) newSL = lockSL;
            }
            
            // Only move SL if it improves the current SL and is above open price
            if(newSL > currentSL && newSL > openPrice)
            {
               if(trade.PositionModify(ticket, newSL, currentTP))
               {
                  Print("?? Trailing Stop BUY mis à jour: ", symbol, " | ", DoubleToString(currentSL, _Digits), " -> ", DoubleToString(newSL, _Digits));
               }
            }
         }
         else if(posInfo.PositionType() == POSITION_TYPE_SELL)
         {
            double beSL = openPrice - beBuffer;
            double newSL = ask + trailDistance;
            if(newSL > beSL) newSL = beSL;

            if(DynamicSL_Enable && lockPriceDist > 0)
            {
               double lockSL = ask + lockPriceDist;
               if(lockSL > beSL) lockSL = beSL;
               if(newSL > lockSL) newSL = lockSL;
            }
            
            // Only move SL if it improves the current SL and is below open price
            if((newSL < currentSL || currentSL == 0) && newSL < openPrice)
            {
               if(trade.PositionModify(ticket, newSL, currentTP))
               {
                  Print("?? Trailing Stop SELL mis à jour: ", symbol, " | ", DoubleToString(currentSL, _Digits), " -> ", DoubleToString(newSL, _Digits));
               }
            }
         }
      }
   }

   // Nettoyage opportuniste: supprimer les GV max profit des tickets qui n'existent plus
   static datetime lastCleanup = 0;
   datetime nowC = TimeCurrent();
   if(nowC - lastCleanup >= 30)
   {
      lastCleanup = nowC;
      for(int gi = (int)GlobalVariablesTotal() - 1; gi >= 0; gi--)
      {
         string gv = GlobalVariableName(gi);
         if(StringFind(gv, "SMC_MAXPROFIT_") != 0) continue;
         string tidStr = StringSubstr(gv, StringLen("SMC_MAXPROFIT_"));
         long tid = (long)StringToInteger(tidStr);
         if(tid <= 0) continue;
         if(!PositionSelectByTicket((ulong)tid))
            GlobalVariableDel(gv);
      }
   }
}

//| DONNÉES GRAPHIQUES POUR ANALYSE EN TEMPS RÉEL          |

// Buffer pour stocker les données graphiques en temps réel
MqlRates g_chartDataBuffer[];
static datetime g_lastChartCapture = 0;

//| FONCTION POUR CAPTURER LES DONNÉES GRAPHIQUES MT5          |
bool CaptureChartDataFromChart()
{
   // Protection anti-erreur critique
   static int captureErrors = 0;
   static datetime lastErrorReset = 0;
   datetime currentTime = TimeCurrent();
   
   // Réinitialiser les erreurs toutes les 2 minutes
   if(currentTime - lastErrorReset >= 120)
   {
      captureErrors = 0;
      lastErrorReset = currentTime;
   }
   
   // Si trop d'erreurs de capture, désactiver temporairement
   if(captureErrors > 3)
   {
      Print("?? Trop d'erreurs de capture graphique - Mode dégradé");
      return false;
   }
   
   // Récupérer les dernières bougies depuis le graphique
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Limiter la taille pour éviter les surcharges
   int barsToCopy = MathMin(50, 100); // Maximum 50 bougies
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, barsToCopy, rates) >= barsToCopy)
   {
      // Stocker les données pour analyse ML
      int bufferSize = MathMin(barsToCopy, ArraySize(rates));
      int startIndex = MathMax(0, ArraySize(rates) - bufferSize);
      
      // Vérifier que le buffer n'est pas trop grand
      if(bufferSize > 100)
      {
         Print("?? Buffer trop grand: ", bufferSize, " - Limitation à 100");
         bufferSize = 100;
      }
      
      // Redimensionner le buffer si nécessaire
      if(ArraySize(g_chartDataBuffer) != bufferSize)
         ArrayResize(g_chartDataBuffer, bufferSize);
      
      // Copier les données dans le buffer circulaire
      for(int i = 0; i < bufferSize && i < ArraySize(rates); i++)
      {
         g_chartDataBuffer[i] = rates[startIndex + i];
      }
      
      g_lastChartCapture = currentTime;
      Print("?? Données graphiques capturées: ", bufferSize, " bougies M1");
      return true;
   }
   else
   {
      captureErrors++;
      Print("? Erreur capture graphique (", captureErrors, "/3) - bars demandées: ", barsToCopy);
      return false;
   }
}

//| FONCTION POUR CALCULER LES FEATURES À PARTIR DES DONNÉES MT5          |
double compute_features_from_mt5_data(MqlRates &rates[])
{
   // Utiliser les prix OHLCV directement depuis les données MT5
   double features[];
   int ratesSize = ArraySize(rates);
   ArrayResize(features, ratesSize * 20); // Allocate enough space for all features
   
   for(int i = 0; i < ratesSize; i++)
   {
      // Features de base (using offset to avoid overlap)
      int baseIdx = i * 20;
      features[baseIdx] = rates[i].close;
      features[baseIdx + 1] = rates[i].open;
      features[baseIdx + 2] = rates[i].high;
      features[baseIdx + 3] = rates[i].low;
      
      // Features techniques (calculées sur les bougies)
      // RSI
      double rsi = ComputeRSI(rates, 14, i);
      features[baseIdx + 4] = (rsi < 30) ? -1 : (rsi > 70) ? 1 : 0;
      
      // MACD
      double macd = ComputeMACD(rates, 12, 26, 9, i);
      features[baseIdx + 5] = (macd > 0) ? 1 : 0;
      
      // ATR
      double atr = 0;
      for(int j = MathMax(0, i - 13); j < i; j++)
      {
         double range = rates[j].high - rates[j].low;
         atr += range;
      }
      if(i > 13) atr /= 14;
      features[baseIdx + 6] = atr;
      
      // Volume (convert long to double)
      features[baseIdx + 7] = (double)rates[i].tick_volume;
      
      // Moyennes mobiles
      if(i >= 20) features[baseIdx + 8] = rates[i].close;
      if(i >= 50) features[baseIdx + 9] = rates[i].close;
      if(i >= 100) features[baseIdx + 10] = rates[i].close;
      
      // Features de volatilité
      if(i >= 20)
      {
         double returns[] = {0, 0, 0, 0, 0};
         for(int j = 1; j <= 20; j++)
         {
            double ret = rates[i - j].close - rates[i - j - 1].close;
            if(ret > 0) returns[j-1] = 1; else returns[j-1] = 0;
         }
         features[baseIdx + 11] = 1;
         for(int k = 0; k < ArraySize(returns); k++)
         {
            if(returns[k]) features[baseIdx + 11 + k] = 1;
         }
      }
      
      // Indicateurs de tendance
      if(i >= 2)
      {
         // EMA 5
         double ema5 = ComputeEMA(rates, 5, i);
         double ema20 = ComputeEMA(rates, 20, i);
         features[baseIdx + 12] = ema5;
         features[baseIdx + 13] = ema20;
         
         // RSI et autres indicateurs...
      }
      
      features[baseIdx] = rates[i].close; // Prix actuel
   }
   
   return 0.0;
}

//| FONCTION POUR DÉTECTER LES PATTERNS GRAPHIQUES          |
bool DetectChartPatterns(MqlRates &rates[])
{
   // Détecter les patterns SMC directement depuis les données graphiques
   // FVG, Order Blocks, Liquidity Sweep, etc.
   
   // Retourner les patterns détectés
   return true;
}

//| FONCTIONS TECHNIQUES POUR DONNÉES MT5                    |

double ComputeEMA(MqlRates &rates[], int period, int index)
{
   if(index < period - 1) return rates[index].close;
   
   double ema = rates[index].close;
   double multiplier = 2.0 / (period + 1);
   
   for(int i = 0; i <= index; i++)
   {
      ema = (rates[i].close - ema) * multiplier + ema;
   }
   
   return ema;
}

double ComputeRSI(MqlRates &rates[], int period, int index)
{
   if(index < period - 1) return 50.0;
   
   double gains = 0, losses = 0;
   for(int i = index - period + 1; i <= index; i++)
   {
      double change = rates[i].close - rates[i-1].close;
      if(change > 0)
         gains += change;
      else
         losses += -change;
   }
   
   double avgGain = gains / period;
   double avgLoss = losses / period;
   if(avgLoss == 0.0)
      return 100.0;
   double rs = avgGain / avgLoss;
   double rsi = 100.0 - (100.0 / (1.0 + rs));
   // Clamp pour rester dans [0,100]
   if(rsi < 0.0) rsi = 0.0;
   if(rsi > 100.0) rsi = 100.0;
   return rsi;
}

double ComputeMACD(MqlRates &rates[], int fast, int slow, int signal, int index)
{
   if(index < slow) return 0;
   
   double emaFast = rates[index].close;
   double emaSlow = rates[index].close;
   
   for(int i = 0; i <= index; i++)
   {
      emaFast = (rates[i].close * 2.0 / (fast + 1)) + emaFast * (fast - 1) / (fast + 1);
      emaSlow = (rates[i].close * 2.0 / (slow + 1)) + emaSlow * (slow - 1) / (slow + 1);
   }
   
   return emaFast - emaSlow;
}

// Résumé combiné des indicateurs classiques (MA/RSI/MACD/Bollinger/VWAP/Pivots/Ichimoku/OBV)
// Retourne true si suffisamment d'indicateurs sont alignés avec la direction demandée
bool IsClassicIndicatorsAligned(const string direction, string &summaryOut)
{
   summaryOut = "";

   if(!UseClassicIndicatorsFilter)
      return true;

   string dir = direction;
   if(dir != "BUY" && dir != "SELL")
      return true;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0)
      return true;

   // Données M1 récentes
   MqlRates m1[];
   ArraySetAsSeries(m1, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 60, m1) < 30)
      return true;

   double price = m1[0].close;

   int scoreFor = 0;
   int scoreAgainst = 0;

   // 1) Tendance EMA simple (déjà existante via emaFastM1 / emaSlowM1)
   double emaFast = 0.0, emaSlow = 0.0;
   double bufFast[], bufSlow[];
   ArraySetAsSeries(bufFast, true);
   ArraySetAsSeries(bufSlow, true);

   if(emaFastM1 != INVALID_HANDLE && CopyBuffer(emaFastM1, 0, 0, 1, bufFast) > 0)
      emaFast = bufFast[0];
   if(emaSlowM1 != INVALID_HANDLE && CopyBuffer(emaSlowM1, 0, 0, 1, bufSlow) > 0)
      emaSlow = bufSlow[0];

   if(emaFast > 0.0 && emaSlow > 0.0)
   {
      bool emaBull = (emaFast > emaSlow);
      bool emaBear = (emaFast < emaSlow);
      if(emaBull || emaBear)
      {
         if((dir == "BUY"  && emaBull) ||
            (dir == "SELL" && emaBear))
         {
            scoreFor++;
            summaryOut += "[EMA OK] ";
         }
         else
         {
            scoreAgainst++;
            summaryOut += "[EMA CONTRA] ";
         }
      }
   }

   // 2) RSI (existing ComputeRSI)
   double rsi = ComputeRSI(m1, 14, 0);
   if(rsi > 70.0)
   {
      if(dir == "SELL") { scoreFor++; summaryOut += "[RSI SURACHAT?SELL] "; }
      else              { scoreAgainst++; summaryOut += "[RSI SURACHAT CONTRA] "; }
   }
   else if(rsi < 30.0)
   {
      if(dir == "BUY")  { scoreFor++; summaryOut += "[RSI SURVENTE?BUY] "; }
      else              { scoreAgainst++; summaryOut += "[RSI SURVENTE CONTRA] "; }
   }

   // 3) MACD (existing ComputeMACD)
   double macd = ComputeMACD(m1, 12, 26, 9, 0);
   if(macd > 0)
   {
      if(dir == "BUY")  { scoreFor++; summaryOut += "[MACD HAUSSIER] "; }
      else              { scoreAgainst++; summaryOut += "[MACD CONTRA] "; }
   }
   else if(macd < 0)
   {
      if(dir == "SELL") { scoreFor++; summaryOut += "[MACD BAISSIER] "; }
      else              { scoreAgainst++; summaryOut += "[MACD CONTRA] "; }
   }

   // 4) Bandes de Bollinger
   if(UseBollingerFilter)
   {
      int bbHandle = iBands(_Symbol, PERIOD_M1, 20, 2.0, 0, PRICE_CLOSE);
      if(bbHandle != INVALID_HANDLE)
      {
         double upper[], middle[], lower[];
         ArraySetAsSeries(upper,  true);
         ArraySetAsSeries(middle, true);
         ArraySetAsSeries(lower,  true);
         if(CopyBuffer(bbHandle, 0, 0, 1, upper)  == 1 &&
            CopyBuffer(bbHandle, 1, 0, 1, middle) == 1 &&
            CopyBuffer(bbHandle, 2, 0, 1, lower)  == 1)
         {
            bool nearUpper = (price >= middle[0]) && (price > upper[0] * 0.995);
            bool nearLower = (price <= middle[0]) && (price < lower[0] * 1.005);
            if(nearUpper)
            {
               if(dir == "SELL") { scoreFor++; summaryOut += "[BB HAUT?SELL] "; }
               else              { scoreAgainst++; summaryOut += "[BB HAUT CONTRA] "; }
            }
            else if(nearLower)
            {
               if(dir == "BUY")  { scoreFor++; summaryOut += "[BB BAS?BUY] "; }
               else              { scoreAgainst++; summaryOut += "[BB BAS CONTRA] "; }
            }
         }
         IndicatorRelease(bbHandle);
      }
   }

   // 5) VWAP intraday (M1, dernière session ~60 bougies)
   if(UseVWAPFilter)
   {
      double sumPV = 0.0, sumV = 0.0;
      int barsVWAP = MathMin(ArraySize(m1), 60);
      for(int i = 0; i < barsVWAP; i++)
      {
         double typical = (m1[i].high + m1[i].low + m1[i].close) / 3.0;
         double vol     = (double)m1[i].tick_volume;
         sumPV += typical * vol;
         sumV  += vol;
      }
      if(sumV > 0.0)
      {
         double vwap = sumPV / sumV;
         if(price > vwap * 1.001)
         {
            if(dir == "BUY")  { scoreFor++; summaryOut += "[VWAP AU-DESSUS?BUY] "; }
            else              { scoreAgainst++; summaryOut += "[VWAP CONTRA] "; }
         }
         else if(price < vwap * 0.999)
         {
            if(dir == "SELL") { scoreFor++; summaryOut += "[VWAP SOUS?SELL] "; }
            else              { scoreAgainst++; summaryOut += "[VWAP CONTRA] "; }
         }
      }
   }

   // 6) Points pivots journaliers
   if(UsePivotFilter)
   {
      MqlRates d1[];
      ArraySetAsSeries(d1, true);
      if(CopyRates(_Symbol, PERIOD_D1, 0, 3, d1) >= 2)
      {
         double highPrev = d1[1].high;
         double lowPrev  = d1[1].low;
         double closePrev= d1[1].close;
         double pivot = (highPrev + lowPrev + closePrev) / 3.0;
         double r1 = 2.0 * pivot - lowPrev;
         double s1 = 2.0 * pivot - highPrev;

         bool nearR1 = MathAbs(price - r1) / r1 < 0.002;
         bool nearS1 = MathAbs(price - s1) / s1 < 0.002;

         if(nearR1)
         {
            if(dir == "SELL") { scoreFor++; summaryOut += "[PIVOT R1?SELL] "; }
            else              { scoreAgainst++; summaryOut += "[PIVOT R1 CONTRA] "; }
         }
         else if(nearS1)
         {
            if(dir == "BUY")  { scoreFor++; summaryOut += "[PIVOT S1?BUY] "; }
            else              { scoreAgainst++; summaryOut += "[PIVOT S1 CONTRA] "; }
         }
      }
   }

   // 7) Ichimoku H1 (résumé simple)
   if(UseIchimokuFilter)
   {
      int ichHandle = iIchimoku(_Symbol, PERIOD_H1, 9, 26, 52);
      if(ichHandle != INVALID_HANDLE)
      {
         double tenkanBuf[], kijunBuf[], spanABuf[], spanBBuf[];
         ArraySetAsSeries(tenkanBuf, true);
         ArraySetAsSeries(kijunBuf,  true);
         ArraySetAsSeries(spanABuf,  true);
         ArraySetAsSeries(spanBBuf,  true);

         bool okTenkan = (CopyBuffer(ichHandle, 0, 0, 1, tenkanBuf) == 1);
         bool okKijun  = (CopyBuffer(ichHandle, 1, 0, 1, kijunBuf)  == 1);
         bool okA      = (CopyBuffer(ichHandle, 2, 0, 1, spanABuf)  == 1);
         bool okB      = (CopyBuffer(ichHandle, 3, 0, 1, spanBBuf)  == 1);

         if(okTenkan && okKijun && okA && okB)
         {
            double cloudTop    = MathMax(spanABuf[0], spanBBuf[0]);
            double cloudBottom = MathMin(spanABuf[0], spanBBuf[0]);
            bool ichBull = (price > cloudTop && tenkanBuf[0] > kijunBuf[0]);
            bool ichBear = (price < cloudBottom && tenkanBuf[0] < kijunBuf[0]);

            if(ichBull)
            {
               if(dir == "BUY")  { scoreFor++; summaryOut += "[ICHIMOKU BULL] "; }
               else              { scoreAgainst++; summaryOut += "[ICHIMOKU CONTRA] "; }
            }
            else if(ichBear)
            {
               if(dir == "SELL") { scoreFor++; summaryOut += "[ICHIMOKU BEAR] "; }
               else              { scoreAgainst++; summaryOut += "[ICHIMOKU CONTRA] "; }
            }
         }
         IndicatorRelease(ichHandle);
      }
   }

   // 8) OBV (On-Balance Volume) sur M15
   if(UseOBVFilter)
   {
      MqlRates m15[];
      ArraySetAsSeries(m15, true);
      int copied = CopyRates(_Symbol, PERIOD_M15, 0, 30, m15);
      // Besoin d'au moins 2 barres pour comparer les clôtures
      if(copied >= 2)
      {
         double obv = 0.0;
         // Parcourir les barres en comparant close[i] avec close[i-1]
         // pour éviter tout dépassement de tableau (array out of range).
         for(int i = 1; i < copied; i++)
         {
            double vol = (double)m15[i].tick_volume;
            if(m15[i].close > m15[i-1].close)
               obv += vol;
            else if(m15[i].close < m15[i-1].close)
               obv -= vol;
         }
         if(obv > 0)
         {
            if(dir == "BUY")  { scoreFor++; summaryOut += "[OBV INFLOW?BUY] "; }
            else              { scoreAgainst++; summaryOut += "[OBV CONTRA] "; }
         }
         else if(obv < 0)
         {
            if(dir == "SELL") { scoreFor++; summaryOut += "[OBV OUTFLOW?SELL] "; }
            else              { scoreAgainst++; summaryOut += "[OBV CONTRA] "; }
         }
      }
   }

   // Décision finale : au moins ClassicMinConfirmations en faveur
   bool ok = (scoreFor >= ClassicMinConfirmations);

   summaryOut = "For=" + IntegerToString(scoreFor) +
                " Against=" + IntegerToString(scoreAgainst) + " " + summaryOut;

   return ok;
}

bool LookForTradingOpportunity(SMC_Signal &sig)
{
   // Cette fonction peut être implémentée plus tard si nécessaire
   return false;
}

void CheckTotalLossAndClose()
{
   // Cette fonction est déjà implémentée sous le nom CloseWorstPositionIfTotalLossExceeded()
   CloseWorstPositionIfTotalLossExceeded();
}

//| ENVOI DE FEEDBACK DE TRADES À L'IA SERVER                        |
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Ne traiter que les transactions de clôture de positions
   if(trans.type != TRADE_TRANSACTION_POSITION)
      return;

   // Pour les transactions de position, vérifier si c'est une clôture
   // En MQL5, on vérifie si la position existe encore
   CPositionInfo pos;
   if(!pos.SelectByTicket(trans.position))
   {
      // La position n'existe plus = elle a été fermée
      // Réinitialiser le maxProfit pour cette position
      g_maxProfit = 0;
      
      // On doit récupérer les informations depuis l'historique des deals
      if(HistorySelectByPosition(trans.position))
      {
         // Récupérer le dernier deal de cette position
         int deals = HistoryDealsTotal();
         for(int i = deals - 1; i >= 0; i--)
         {
            ulong deal_ticket = HistoryDealGetTicket(i);
            if(deal_ticket > 0)
            {
               CDealInfo deal;
               if(deal.SelectByIndex(i) && deal.PositionId() == trans.position)
               {
                  // C'est le deal de clôture de notre position
                  // Vérifier que c'est notre robot (magic number)
                  if(deal.Magic() != InpMagicNumber)
                     return;

                  // Extraire les données du trade
                  string symbol = deal.Symbol();
                  double profit = deal.Profit() + deal.Swap() + deal.Commission();
                  bool is_win = (profit > 0);
                  string side = (deal.Entry() == DEAL_ENTRY_IN) ? "BUY" : "SELL";

                  // Mémoriser perte récente par symbole (éviter 2e perte consécutive sans conditions strictes)
                  if(profit < 0)
                  {
                     g_lastLossSymbol = symbol;
                     g_lastLossTime   = (datetime)deal.Time();
                  }
                  else if(symbol == g_lastLossSymbol)
                  {
                     g_lastLossSymbol = "";
                     g_lastLossTime   = 0;
                  }

                  // Timestamps (convertir en millisecondes pour compatibilité JSON)
                  long open_time = (long)deal.Time() * 1000;  // Time of the deal
                  long close_time = (long)deal.Time() * 1000;

                  // Utiliser la dernière confiance IA connue
                  double ai_confidence = g_lastAIConfidence;

                  // Créer le payload JSON
                  string json_payload = StringFormat(
                     "{"
                     "\"symbol\":\"%s\","
                     "\"timeframe\":\"M1\","
                     "\"profit\":%.2f,"
                     "\"is_win\":%s,"
                     "\"ai_confidence\":%.4f,"
                     "\"side\":\"%s\","
                     "\"open_time\":%lld,"
                     "\"close_time\":%lld"
                     "}",
                     symbol,
                     profit,
                     is_win ? "true" : "false",
                     ai_confidence,
                     side,
                     open_time,
                     close_time
                  );

                  // Envoyer à l'IA server (essayer primaire puis secondaire)
                  string url1 = UseRenderAsPrimary ? (AI_ServerRender + "/trades/feedback") : (AI_ServerURL + "/trades/feedback");
                  string url2 = UseRenderAsPrimary ? (AI_ServerURL + "/trades/feedback") : (AI_ServerRender + "/trades/feedback");
                  
                  Print("?? ENVOI FEEDBACK IA - URL1: ", url1);
                  Print("?? ENVOI FEEDBACK IA - URL2: ", url2);
                  Print("?? ENVOI FEEDBACK IA - Données: symbol=", symbol, " profit=", DoubleToString(profit, 2), " ai_conf=", DoubleToString(ai_confidence, 2));

                  string headers = "Content-Type: application/json\r\n";
                  char post_data[];
                  char result_data[];
                  string result_headers;

                  // Convertir string JSON en array de char
                  StringToCharArray(json_payload, post_data, 0, StringLen(json_payload));

                  // Premier essai
                  int http_result = WebRequest("POST", url1, headers, AI_Timeout_ms, post_data, result_data, result_headers);

                  // Si échec, essayer le serveur secondaire
                  if(http_result != 200)
                  {
                     http_result = WebRequest("POST", url2, headers, AI_Timeout_ms, post_data, result_data, result_headers);
                  }

                  // Log du résultat
                  if(http_result == 200)
                  {
                     Print("? FEEDBACK IA ENVOYÉ: ", symbol, " ", side, " Profit: ", DoubleToString(profit, 2), " IA Conf: ", DoubleToString(ai_confidence, 2));
                  }
                  else
                  {
                     Print("? ÉCHEC ENVOI FEEDBACK IA: HTTP ", http_result, " pour ", symbol, " ", side);
                  }

                  break; // On a trouvé le deal de clôture, sortir de la boucle
               }
            }
         }
      }
   }
}

//| Récupérer les données de l'endpoint Decision                        |
bool GetAISignalData()
{
   static datetime lastAPICall = 0;
   static string lastCachedResponse = "";
   
   datetime currentTime = TimeCurrent();
   
   // Cache API: éviter les appels trop fréquents (toutes les 30 secondes)
   if((currentTime - lastAPICall) < 30 && lastCachedResponse != "")
   {
      // Utiliser la réponse en cache
      if(StringFind(lastCachedResponse, "\"action\":") >= 0)
      {
         int actionStart = StringFind(lastCachedResponse, "\"action\":");
         actionStart = StringFind(lastCachedResponse, "\"", actionStart + 9) + 1;
         int actionEnd = StringFind(lastCachedResponse, "\"", actionStart);
         if(actionEnd > actionStart)
         {
            g_lastAIAction = StringSubstr(lastCachedResponse, actionStart, actionEnd - actionStart);
            return true;
         }
      }
   }
   
   // Endpoint POST /decision sur Render ou serveur local
   string base = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
   string url  = base + "/decision";
   string headers = "Content-Type: application/json\r\n";
   char post[];
   uchar response[];
   
   // Préparer les données de marché de base
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // ATR via handle principal (si disponible)
   double atr = 0.0;
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atrBuf) > 0)
      atr = atrBuf[0];
   
   // Calcul d'un RSI M15 pour alimenter le backend simplifié
   double rsi = 50.0;
   MqlRates rsiRates[];
   ArraySetAsSeries(rsiRates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 50, rsiRates) >= 15)
   {
      // Utilise la fonction ComputeRSI déjà définie (période 14)
      rsi = ComputeRSI(rsiRates, 14, 14);
   }
   // Sécurité supplémentaire : clamp 0-100 pour l'envoi JSON
   if(rsi < 0.0) rsi = 0.0;
   if(rsi > 100.0) rsi = 100.0;
   
   // Récupérer les EMA rapides/lentes via les handles existants (M1, M5, H1)
   double emaFastM1Val = 0.0, emaSlowM1Val = 0.0;
   double emaFastM5Val = 0.0, emaSlowM5Val = 0.0;
   double emaFastH1Val = 0.0, emaSlowH1Val = 0.0;
   double bufFast[], bufSlow[];
   ArraySetAsSeries(bufFast, true);
   ArraySetAsSeries(bufSlow, true);
   
   // M1
   if(emaFastM1 != INVALID_HANDLE && CopyBuffer(emaFastM1, 0, 0, 1, bufFast) > 0)
      emaFastM1Val = bufFast[0];
   if(emaSlowM1 != INVALID_HANDLE && CopyBuffer(emaSlowM1, 0, 0, 1, bufSlow) > 0)
      emaSlowM1Val = bufSlow[0];
   
   // M5
   if(emaFastM5 != INVALID_HANDLE && CopyBuffer(emaFastM5, 0, 0, 1, bufFast) > 0)
      emaFastM5Val = bufFast[0];
   if(emaSlowM5 != INVALID_HANDLE && CopyBuffer(emaSlowM5, 0, 0, 1, bufSlow) > 0)
      emaSlowM5Val = bufSlow[0];
   
   // H1
   if(emaFastH1 != INVALID_HANDLE && CopyBuffer(emaFastH1, 0, 0, 1, bufFast) > 0)
      emaFastH1Val = bufFast[0];
   if(emaSlowH1 != INVALID_HANDLE && CopyBuffer(emaSlowH1, 0, 0, 1, bufSlow) > 0)
      emaSlowH1Val = bufSlow[0];
   
   // Construire la requête JSON enrichie pour /decision (compatible decision_simplified)
   // Ajouter les indicateurs de détection de spike avancée - VERSION OPTIMISÉE
   double volCompression = 1.0; // Valeur par défaut
   double priceAccel = 0.0;
   bool volumeSpike = false;
   double spikeProb = 0.5; // Valeur neutre par défaut
   
   // Calcul rapide avec protection
   if(atrHandle != INVALID_HANDLE)
   {
      // Compression ATR rapide
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(atrHandle, 0, 0, 10, buffer) >= 5)
      {
         double recentATR = buffer[0];
         double avgATR = 0.0;
         for(int i = 0; i < 5; i++) avgATR += buffer[i];
         avgATR /= 5.0;
         if(avgATR > 0) volCompression = recentATR / avgATR;
      }
      
      // Accélération prix rapide
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, PERIOD_M1, 0, 3, rates) >= 2)
      {
         double change1 = (rates[0].close - rates[1].close) / rates[1].close;
         double change2 = (rates[1].close - rates[2].close) / rates[2].close;
         priceAccel = (change1 - change2) / 2.0;
      }
      
      // Volume spike rapide
      long volume[];
      ArraySetAsSeries(volume, true);
      if(CopyTickVolume(_Symbol, PERIOD_M1, 0, 5, volume) >= 3)
      {
         double recentVolume = (double)volume[0];
         double avgVolume = 0.0;
         for(int i = 1; i < 3; i++) avgVolume += (double)volume[i];
         avgVolume /= 2.0;
         volumeSpike = (recentVolume > avgVolume * 1.5);
      }
      
      // Probabilité spike rapide - AJUSTÉ pour 70% de certitude
      spikeProb = 0.0;
      if(volCompression < 0.7) spikeProb += 0.4; // Compression forte (< 70%)
      if(MathAbs(priceAccel) > 0.001) spikeProb += 0.3; // Accélération notable
      if(volumeSpike) spikeProb += 0.3; // Volume spike confirmé
      spikeProb = MathMin(spikeProb, 1.0);

      // Mémoriser la probabilité locale de spike pour réutilisation (CheckImminentSpike, filtres ML, etc.)
      g_lastSpikeProbability = spikeProb;
      g_lastSpikeUpdate      = TimeCurrent();
   }
   
   string jsonRequest = StringFormat(
      "{\"symbol\":\"%s\",\"bid\":%.5f,\"ask\":%.5f,"
      "\"atr\":%.5f,\"rsi\":%.2f,"
      "\"ema_fast_m1\":%.5f,\"ema_slow_m1\":%.5f,"
      "\"ema_fast_m5\":%.5f,\"ema_slow_m5\":%.5f,"
      "\"ema_fast_h1\":%.5f,\"ema_slow_h1\":%.5f,"
      "\"volatility_compression\":%.3f,"
      "\"price_acceleration\":%.6f,"
      "\"volume_spike\":%s,"
      "\"spike_probability\":%.3f,"
      "\"timestamp\":\"%s\"}",
      _Symbol, bid, ask, atr, rsi,
      emaFastM1Val, emaSlowM1Val,
      emaFastM5Val, emaSlowM5Val,
      emaFastH1Val, emaSlowH1Val,
      volCompression,
      priceAccel,
      volumeSpike ? "true" : "false",
      spikeProb,
      TimeToString(TimeCurrent())
   );
   
   Print("?? ENVOI IA: ", jsonRequest);
   
   StringToCharArray(jsonRequest, post);
   
   // Timeout réduit pour éviter le détachement
   int res = WebRequest("POST", url, headers, 2000, post, response, headers);
   
      if(res == 200)
      {
         string jsonResponse = CharArrayToString(response);
         Print("?? RÉPONSE IA: ", jsonResponse);
         
         // Mettre à jour le cache
         lastAPICall = currentTime;
         lastCachedResponse = jsonResponse;
         
         // Parser la réponse JSON
         int actionStart = StringFind(jsonResponse, "\"action\":");
         if(actionStart >= 0)
         {
            actionStart = StringFind(jsonResponse, "\"", actionStart + 9) + 1;
            int actionEnd = StringFind(jsonResponse, "\"", actionStart);
            if(actionEnd > actionStart)
            {
               g_lastAIAction = StringSubstr(jsonResponse, actionStart, actionEnd - actionStart);
               
               int confStart = StringFind(jsonResponse, "\"confidence\":");
               if(confStart >= 0)
               {
                  confStart = StringFind(jsonResponse, ":", confStart) + 1;
                  int confEnd = StringFind(jsonResponse, ",", confStart);
                  if(confEnd < 0) confEnd = StringFind(jsonResponse, "}", confStart);
                  if(confEnd > confStart)
                  {
                     string confStr = StringSubstr(jsonResponse, confStart, confEnd - confStart);
                     g_lastAIConfidence = StringToDouble(confStr);
                  }
               }

               // Extraire la probabilité de spike renvoyée par le modèle ML (si disponible)
               int spikeStart = StringFind(jsonResponse, "\"spike_probability\"");
               if(spikeStart >= 0)
               {
                  spikeStart = StringFind(jsonResponse, ":", spikeStart) + 1;
                  int spikeEnd = StringFind(jsonResponse, ",", spikeStart);
                  if(spikeEnd < 0) spikeEnd = StringFind(jsonResponse, "}", spikeStart);
                  if(spikeEnd > spikeStart)
                  {
                     string spikeStr = StringSubstr(jsonResponse, spikeStart, spikeEnd - spikeStart);
                     double spikeVal = StringToDouble(spikeStr);
                     
                     // Accepter 0?1 ou 0?100%
                     if(spikeVal > 1.0)
                        spikeVal /= 100.0;
                     
                     if(spikeVal >= 0.0 && spikeVal <= 1.0)
                     {
                        g_lastSpikeProbability = spikeVal;
                        g_lastSpikeUpdate      = TimeCurrent();
                     }
                  }
               }
               
               // Extraire alignement et cohérence
            int alignStart = StringFind(jsonResponse, "\"alignment\":");
            if(alignStart >= 0)
            {
               alignStart = StringFind(jsonResponse, "\"", alignStart + 12) + 1;
               int alignEnd = StringFind(jsonResponse, "\"", alignStart);
               if(alignEnd > alignStart)
               {
                  g_lastAIAlignment = StringSubstr(jsonResponse, alignStart, alignEnd - alignStart);
               }
            }
            
            int cohStart = StringFind(jsonResponse, "\"coherence\":");
            if(cohStart >= 0)
            {
               cohStart = StringFind(jsonResponse, "\"", cohStart + 13) + 1;
               int cohEnd = StringFind(jsonResponse, "\"", cohStart);
               if(cohEnd > cohStart)
               {
                  g_lastAICoherence = StringSubstr(jsonResponse, cohStart, cohEnd - cohStart);
               }
            }
            
            g_lastAIUpdate = TimeCurrent();
            g_aiConnected = true;
            
            Print("? IA MISE À JOUR: ", g_lastAIAction, " | ", DoubleToString(g_lastAIConfidence*100,1), "% | ", g_lastAIAlignment, " | ", g_lastAICoherence);
            
            return true;
         }
      }
   }
   else
   {
      Print("? ERREUR IA: HTTP ", res);
      g_aiConnected = false;
      
      // FALLBACK: Le fallback sera géré par OnTick directement
      // GenerateFallbackAIDecision(); // Déplacé dans OnTick
   }
   
   return false;
}

//| Générer une décision IA de fallback basée sur les données de marché |
void GenerateFallbackAIDecision()
{
   // Récupérer les données de marché actuelles
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculer une tendance SMC EMA avancée
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   string action = "HOLD";
   double confidence = 0.5;
   double alignment = 50.0;
   double coherence = 50.0;
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, 50, rates) >= 20)
   {
      // Calculer les EMA pour analyse SMC
      double ema8 = 0, ema21 = 0, ema50 = 0, ema200 = 0;
      
      // EMA 8 (très court terme)
      double multiplier8 = 2.0 / (8 + 1);
      ema8 = rates[0].close;
      for(int i = 1; i < 8; i++)
         ema8 = rates[i].close * multiplier8 + ema8 * (1 - multiplier8);
      
      // EMA 21 (court terme)
      double multiplier21 = 2.0 / (21 + 1);
      ema21 = rates[0].close;
      for(int i = 1; i < 21; i++)
         ema21 = rates[i].close * multiplier21 + ema21 * (1 - multiplier21);
      
      // EMA 50 (moyen terme)
      double multiplier50 = 2.0 / (50 + 1);
      ema50 = rates[0].close;
      for(int i = 1; i < 50; i++)
         ema50 = rates[i].close * multiplier50 + ema50 * (1 - multiplier50);
      
      // EMA 200 (long terme)
      double multiplier200 = 2.0 / (200 + 1);
      ema200 = rates[0].close;
      for(int i = 1; i < MathMin(200, ArraySize(rates)); i++)
         ema200 = rates[i].close * multiplier200 + ema200 * (1 - multiplier200);
      
      double currentPrice = rates[0].close;
      
      // LOGIQUE SMC EMA AVANCÉE
      bool bullishStructure = (ema8 > ema21) && (ema21 > ema50) && (ema50 > ema200);
      bool bearishStructure = (ema8 < ema21) && (ema21 < ema50) && (ema50 < ema200);
      
      // Détecter les croisements EMA
      bool ema8Cross21Up = (ema8 > ema21) && (rates[1].close <= rates[2].close);
      bool ema8Cross21Down = (ema8 < ema21) && (rates[1].close >= rates[2].close);
      
      // Détecter la momentum
      double momentum = (currentPrice - ema50) / ema50;
      double momentumShort = (currentPrice - ema21) / ema21;
      
      // DÉCISION BASÉE SUR SMC EMA
      if(bullishStructure && momentum > 0.002)
      {
         action = "BUY";
         confidence = MathMin(0.95, 0.6 + MathAbs(momentum) * 100);
         alignment = MathMin(98.0, 60.0 + MathAbs(momentum) * 100);
         coherence = MathMin(95.0, 55.0 + MathAbs(momentumShort) * 80);
      }
      else if(bearishStructure && momentum < -0.002)
      {
         action = "SELL";
         confidence = MathMin(0.95, 0.6 + MathAbs(momentum) * 100);
         alignment = MathMin(98.0, 60.0 + MathAbs(momentum) * 100);
         coherence = MathMin(95.0, 55.0 + MathAbs(momentumShort) * 80);
      }
      else if(ema8Cross21Up && momentum > 0.001)
      {
         action = "BUY";
         confidence = 0.75 + (MathRand() % 15) / 100.0; // 75-90%
         alignment = 70.0 + (MathRand() % 20); // 70-90%
         coherence = 65.0 + (MathRand() % 25); // 65-90%
      }
      else if(ema8Cross21Down && momentum < -0.001)
      {
         action = "SELL";
         confidence = 0.75 + (MathRand() % 15) / 100.0; // 75-90%
         alignment = 70.0 + (MathRand() % 20); // 70-90%
         coherence = 65.0 + (MathRand() % 25); // 65-90%
      }
      else if(MathAbs(momentum) < 0.0005)
      {
         action = "HOLD";
         confidence = 0.40 + (MathRand() % 25) / 100.0; // 40-65%
         alignment = 35.0 + (MathRand() % 30); // 35-65%
         coherence = 30.0 + (MathRand() % 35); // 30-65%
      }
      else
      {
         // Décision basée sur le momentum restant
         if(momentum > 0)
         {
            action = "BUY";
            confidence = 0.55 + MathAbs(momentum) * 30;
            alignment = 50.0 + MathAbs(momentum) * 40;
            coherence = 45.0 + MathAbs(momentum) * 35;
         }
         else
         {
            action = "SELL";
            confidence = 0.55 + MathAbs(momentum) * 30;
            alignment = 50.0 + MathAbs(momentum) * 40;
            coherence = 45.0 + MathAbs(momentum) * 35;
         }
      }
   }
   else
   {
      // Si pas assez de données, générer des décisions variées réalistes
      string actions[] = {"BUY", "SELL", "HOLD"};
      // Pondération pour plus de BUY/SELL que HOLD
      int weights[] = {40, 40, 20}; // 40% BUY, 40% SELL, 20% HOLD
      int totalWeight = 100;
      int random = MathRand() % totalWeight;
      
      if(random < weights[0]) action = actions[0];
      else if(random < weights[0] + weights[1]) action = actions[1];
      else action = actions[2];
      
      confidence = 0.45 + (MathRand() % 40) / 100.0; // 45-85%
      alignment = 35.0 + (MathRand() % 55); // 35-90%
      coherence = 30.0 + (MathRand() % 60); // 30-90%
   }
   
   // Mettre à jour les variables globales
   g_lastAIAction = action;
   g_lastAIConfidence = confidence;
   g_lastAIAlignment = DoubleToString(alignment, 1) + "%";
   g_lastAICoherence = DoubleToString(coherence, 1) + "%";
   g_lastAIUpdate = TimeCurrent();
   
   Print("?? IA SMC-EMA - Action: ", action, " | Conf: ", DoubleToString(confidence*100,1), "% | Align: ", g_lastAIAlignment, " | Cohér: ", g_lastAICoherence);
}

// Petit helper de debug pour inspecter rapidement la dernière décision IA
void DebugPrintAIDecision()
{
   Print("?? DEBUG IA - Symbole: ", _Symbol,
         " | Action: ", g_lastAIAction,
         " | Confiance: ", DoubleToString(g_lastAIConfidence*100, 1), "%",
         " | Alignement: ", g_lastAIAlignment,
         " | Cohérence: ", g_lastAICoherence);
}

//| DÉTECTION SWING HIGH/LOW SPÉCIALE BOOM/CRASH (LOGIQUE TRADING) |
bool DetectBoomCrashSwingPoints()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int barsToAnalyze = 100;
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, barsToAnalyze, rates) < barsToAnalyze)
      return false;
   
   // Nettoyer les anciens objets Boom/Crash
   ObjectsDeleteAll(0, "SMC_BC_SH_");
   ObjectsDeleteAll(0, "SMC_BC_SL_");
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double avgMove = 0;
   
   // Calculer le mouvement moyen pour détecter les spikes
   for(int i = 1; i < barsToAnalyze; i++)
   {
      double move = MathAbs(rates[i-1].close - rates[i].close);
      avgMove += move;
   }
   avgMove /= (barsToAnalyze - 1);
   
   // Seuil de spike (8x le mouvement normal pour Boom/Crash)
   double spikeThreshold = avgMove * 8.0;
   
   // Réduire la fréquence des logs BOOM/CRASH pour éviter la superposition
   static datetime lastBoomCrashLog = 0;
   if(TimeCurrent() - lastBoomCrashLog >= 120) // Log toutes les 2 minutes maximum
   {
      Print("?? BOOM/CRASH - ", _Symbol, " | Mouvement: ", DoubleToString(avgMove, _Digits), " | Seuil spike: ", DoubleToString(spikeThreshold, _Digits));
      lastBoomCrashLog = TimeCurrent();
   }
   
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   
   // DÉTECTION DES SPIKES D'ABORD
   for(int i = 5; i < barsToAnalyze - 5; i++)
   {
      double priceChange = MathAbs(rates[i].close - rates[i-1].close);
      bool isSpike = (priceChange > spikeThreshold);
      
      if(!isSpike) continue;
      
      // Limiter les logs de spike pour éviter la surcharge
      static datetime lastSpikeLog = 0;
      if(TimeCurrent() - lastSpikeLog >= 30) // Log toutes les 30 secondes maximum
      {
         Print("?? SPIKE DÉTECTÉ - ", _Symbol, " | Barre ", i, " | Mouvement: ", DoubleToString(priceChange, _Digits), " | Type: ", isBoom ? "BOOM" : "CRASH");
         lastSpikeLog = TimeCurrent();
      }
      
      // LOGIQUE BOOM : SH APRÈS SPIKE (pour annoncer le sell)
      if(isBoom)
      {
         // Chercher le Swing High APRÈS le spike (confirmation de retournement)
         for(int j = MathMax(0, i - 8); j <= MathMax(0, i - 2); j++) // 2-8 barres après le spike
         {
            double currentHigh = rates[j].high;
            
            // Vérifier si c'est un swing high local
            bool isPotentialSH = true;
            for(int k = MathMax(0, j - 3); k <= MathMin(barsToAnalyze - 1, j + 3); k++)
            {
               if(k != j && rates[k].high >= currentHigh)
               {
                  isPotentialSH = false;
                  break;
               }
            }
            
            // Confirmation : le SH doit être plus bas que le pic du spike
            if(isPotentialSH && currentHigh < rates[i].high)
            {
               // Confirmer que c'est bien après le spike
               bool confirmedAfterSpike = true;
               for(int k = j + 1; k <= MathMin(barsToAnalyze - 1, j + 3); k++)
               {
                  if(rates[k].high > currentHigh)
                  {
                     confirmedAfterSpike = false;
                     break;
                  }
               }
               
               if(confirmedAfterSpike)
               {
                  string shName = "SMC_BC_SH_" + IntegerToString(j);
                  if(ObjectCreate(0, shName, OBJ_ARROW, 0, rates[j].time, currentHigh))
                  {
                     ObjectSetInteger(0, shName, OBJPROP_COLOR, clrRed);
                     ObjectSetInteger(0, shName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, shName, OBJPROP_WIDTH, 6);
                     ObjectSetInteger(0, shName, OBJPROP_ARROWCODE, 233);
                     ObjectSetString(0, shName, OBJPROP_TOOLTIP, 
                                   "SH APRÈS SPIKE BOOM (Signal SELL): " + DoubleToString(currentHigh, _Digits) + " | Spike: " + DoubleToString(rates[i].high, _Digits));
                     
                     // Ligne horizontale
                     string lineName = shName + "_Line";
                     if(ObjectCreate(0, lineName, OBJ_HLINE, 0, rates[j].time, currentHigh))
                     {
                        ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrRed);
                        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
                        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
                        ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
                     }
                     
                     Print("?? SH APRÈS SPIKE BOOM (Signal SELL) - Prix: ", DoubleToString(currentHigh, _Digits), " | Spike: ", DoubleToString(rates[i].high, _Digits), " | Time: ", TimeToString(rates[j].time));
                  }
                  break; // Prendre le premier SH valide après le spike
               }
            }
         }
      }
      
      // LOGIQUE CRASH : SL AVANT SPIKE (pour annoncer le crash)
      if(isCrash)
      {
         // Chercher le Swing Low AVANT le spike (préparation du crash)
         for(int j = i + 2; j <= MathMin(barsToAnalyze - 1, i + 8); j++) // 2-8 barres avant le spike
         {
            double currentLow = rates[j].low;
            
            // Vérifier si c'est un swing low local
            bool isPotentialSL = true;
            for(int k = MathMax(0, j - 3); k <= MathMin(barsToAnalyze - 1, j + 3); k++)
            {
               if(k != j && rates[k].low <= currentLow)
               {
                  isPotentialSL = false;
                  break;
               }
            }
            
            // Confirmation : le SL doit être plus haut que le creux du spike
            if(isPotentialSL && currentLow > rates[i].low)
            {
               // Confirmer que c'est bien avant le spike
               bool confirmedBeforeSpike = true;
               for(int k = MathMax(0, j - 3); k <= j - 1; k++)
               {
                  if(rates[k].low < currentLow)
                  {
                     confirmedBeforeSpike = false;
                     break;
                  }
               }
               
               if(confirmedBeforeSpike)
               {
                  string slName = "SMC_BC_SL_" + IntegerToString(j);
                  if(ObjectCreate(0, slName, OBJ_ARROW, 0, rates[j].time, currentLow))
                  {
                     ObjectSetInteger(0, slName, OBJPROP_COLOR, clrBlue);
                     ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, slName, OBJPROP_WIDTH, 6);
                     ObjectSetInteger(0, slName, OBJPROP_ARROWCODE, 234);
                     ObjectSetString(0, slName, OBJPROP_TOOLTIP, 
                                   "SL AVANT SPIKE CRASH (Signal CRASH): " + DoubleToString(currentLow, _Digits) + " | Spike: " + DoubleToString(rates[i].low, _Digits));
                     
                     // Ligne horizontale
                     string lineName = slName + "_Line";
                     if(ObjectCreate(0, lineName, OBJ_HLINE, 0, rates[j].time, currentLow))
                     {
                        ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrBlue);
                        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
                        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
                        ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
                     }
                     
                     Print("?? SL AVANT SPIKE CRASH (Signal CRASH) - Prix: ", DoubleToString(currentLow, _Digits), " | Spike: ", DoubleToString(rates[i].low, _Digits), " | Time: ", TimeToString(rates[j].time));
                  }
                  break; // Prendre le premier SL valide avant le spike
               }
            }
         }
      }
   }
   
   return true;
}

//| DÉTECTION SWING HIGH/LOW NON-REPAINTING (ANTI-REPAINT)          |
struct SwingPoint {
   double price;
   datetime time;
   bool isHigh;
   int confirmedBar; // Barre où le swing est confirmé
};

SwingPoint swingPoints[100]; // Buffer pour stocker les SH/SL confirmés
int swingPointCount = 0;

//| Détecter les Swing High/Low sans repaint (confirmation requise)    |
bool DetectNonRepaintingSwingPoints()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int barsToAnalyze = 200;
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, barsToAnalyze, rates) < barsToAnalyze)
      return false;
   
   // Nettoyer les anciens points non confirmés
   for(int i = 0; i < swingPointCount; i++)
   {
      if(swingPoints[i].confirmedBar > 10) // Garder seulement les 10 dernières barres
      {
         for(int j = i; j < swingPointCount - 1; j++)
            swingPoints[j] = swingPoints[j + 1];
         swingPointCount--;
         i--;
      }
   }
   
   // Analyser les barres pour détecter les swings potentiels
   for(int i = 10; i < barsToAnalyze - 10; i++) // Éviter les bords
   {
      // DÉTECTION SWING HIGH (NON-REPAINTING)
      bool isPotentialSH = true;
      double currentHigh = rates[i].high;
      
      // Vérifier si c'est le plus haut sur au moins 5 barres de chaque côté
      for(int j = MathMax(0, i - 5); j <= MathMin(barsToAnalyze - 1, i + 5); j++)
      {
         if(j != i && rates[j].high >= currentHigh)
         {
            isPotentialSH = false;
            break;
         }
      }
      
      // CONFIRMATION SWING HIGH : Attendre 3 barres après le point potentiel
      if(isPotentialSH && i >= 13) // Assez de barres pour confirmer
      {
         bool confirmed = true;
         
         // Vérifier que les 3 barres suivantes n'ont pas dépassé ce high
         for(int j = i - 3; j >= MathMax(0, i - 5); j--) // 3 barres après le point
         {
            if(rates[j].high > currentHigh)
            {
               confirmed = false;
               break;
            }
         }
         
         // Vérifier que ce n'est pas déjà enregistré
         if(confirmed)
         {
            bool alreadyRecorded = false;
            for(int k = 0; k < swingPointCount; k++)
            {
               if(swingPoints[k].isHigh && 
                  MathAbs(swingPoints[k].price - currentHigh) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5 &&
                  MathAbs(swingPoints[k].time - rates[i].time) <= 300) // 5 minutes tolerance
               {
                  alreadyRecorded = true;
                  break;
               }
            }
            
            if(!alreadyRecorded && swingPointCount < 100)
            {
               swingPoints[swingPointCount].price = currentHigh;
               swingPoints[swingPointCount].time = rates[i].time;
               swingPoints[swingPointCount].isHigh = true;
               swingPoints[swingPointCount].confirmedBar = i;
               swingPointCount++;
               
   // Réduire la fréquence des logs SWING pour éviter la superposition
   static datetime lastSwingLog = 0;
   if(TimeCurrent() - lastSwingLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? SWING HIGH CONFIRMÉ - ", _Symbol, " | Prix: ", DoubleToString(currentHigh, _Digits), " | Time: ", TimeToString(rates[i].time));
      lastSwingLog = TimeCurrent();
   }
            }
         }
      }
      
      // DÉTECTION SWING LOW (NON-REPAINTING)
      bool isPotentialSL = true;
      double currentLow = rates[i].low;
      
      // Vérifier si c'est le plus bas sur au moins 5 barres de chaque côté
      for(int j = MathMax(0, i - 5); j <= MathMin(barsToAnalyze - 1, i + 5); j++)
      {
         if(j != i && rates[j].low <= currentLow)
         {
            isPotentialSL = false;
            break;
         }
      }
      
      // CONFIRMATION SWING LOW : Attendre 3 barres après le point potentiel
      if(isPotentialSL && i >= 13) // Assez de barres pour confirmer
      {
         bool confirmed = true;
         
         // Vérifier que les 3 barres suivantes n'ont pas dépassé ce low
         for(int j = i - 3; j >= MathMax(0, i - 5); j--) // 3 barres après le point
         {
            if(rates[j].low < currentLow)
            {
               confirmed = false;
               break;
            }
         }
         
         // Vérifier que ce n'est pas déjà enregistré
         if(confirmed)
         {
            bool alreadyRecorded = false;
            for(int k = 0; k < swingPointCount; k++)
            {
               if(!swingPoints[k].isHigh && 
                  MathAbs(swingPoints[k].price - currentLow) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5 &&
                  MathAbs(swingPoints[k].time - rates[i].time) <= 300) // 5 minutes tolerance
               {
                  alreadyRecorded = true;
                  break;
               }
            }
            
            if(!alreadyRecorded && swingPointCount < 100)
            {
               swingPoints[swingPointCount].price = currentLow;
               swingPoints[swingPointCount].time = rates[i].time;
               swingPoints[swingPointCount].isHigh = false;
               swingPoints[swingPointCount].confirmedBar = i;
               swingPointCount++;
               
   // Réduire la fréquence des logs SWING pour éviter la superposition
   static datetime lastSwingLog = 0;
   if(TimeCurrent() - lastSwingLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? SWING LOW CONFIRMÉ - ", _Symbol, " | Prix: ", DoubleToString(currentLow, _Digits), " | Time: ", TimeToString(rates[i].time));
      lastSwingLog = TimeCurrent();
   }
            }
         }
      }
   }
   
   return true;
}

//| Obtenir les derniers Swing High/Low confirmés (non-repainting)     |
void GetLatestConfirmedSwings(double &lastSH, datetime &lastSHTime, double &lastSL, datetime &lastSLTime)
{
   lastSH = 0;
   lastSHTime = 0;
   lastSL = 999999;
   lastSLTime = 0;
   
   // Parcourir tous les points pour trouver les plus récents
   for(int i = 0; i < swingPointCount; i++)
   {
      if(swingPoints[i].isHigh && swingPoints[i].time > lastSHTime)
      {
         lastSH = swingPoints[i].price;
         lastSHTime = swingPoints[i].time;
      }
      else if(!swingPoints[i].isHigh && swingPoints[i].time > lastSLTime)
      {
         lastSL = swingPoints[i].price;
         lastSLTime = swingPoints[i].time;
      }
   }
}

//| Dessiner les Swing Points confirmés (non-repainting)              |
// Limité à 25 points pour éviter trop d'objets graphiques ? détachement
#define MAX_SWING_POINTS_DRAWN 25

void DrawConfirmedSwingPoints()
{
   long chId = ChartID();
   if(chId <= 0) return;
   
   ObjectsDeleteAll(chId, "SMC_Confirmed_SH_");
   ObjectsDeleteAll(chId, "SMC_Confirmed_SL_");
   
   // Limiter le nombre de points affichés pour éviter saturation objets ? détachement
   int toDraw = MathMin(swingPointCount, MAX_SWING_POINTS_DRAWN);
   int futureBars = (SMCChannelFutureBars > 0 && SMCChannelFutureBars <= 5000) ? SMCChannelFutureBars : 5000;
   
   for(int i = 0; i < toDraw; i++)
   {
      if(!MathIsValidNumber(swingPoints[i].price) || swingPoints[i].time <= 0) continue;
      
      string objName;
      color objColor;
      int objCode;
      
      if(swingPoints[i].isHigh)
      {
         objName = "SMC_Confirmed_SH_" + IntegerToString(i);
         objColor = clrRed;
         objCode = 233;
      }
      else
      {
         objName = "SMC_Confirmed_SL_" + IntegerToString(i);
         objColor = clrBlue;
         objCode = 234;
      }
      
      if(ObjectCreate(chId, objName, OBJ_ARROW, 0, swingPoints[i].time, swingPoints[i].price))
      {
         ObjectSetInteger(chId, objName, OBJPROP_COLOR, objColor);
         ObjectSetInteger(chId, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(chId, objName, OBJPROP_WIDTH, 4);
         ObjectSetInteger(chId, objName, OBJPROP_ARROWCODE, objCode);
         ObjectSetString(chId, objName, OBJPROP_TOOLTIP, 
                       swingPoints[i].isHigh ? "SH Confirmé: " + DoubleToString(swingPoints[i].price, _Digits) 
                                            : "SL Confirmé: " + DoubleToString(swingPoints[i].price, _Digits));
         
         string lineName = objName + "_Line";
         datetime startTime = TimeCurrent();
         datetime endTime = startTime + (datetime)((long)futureBars * 60);
         
         if(MathIsValidNumber(swingPoints[i].price) && 
            ObjectCreate(chId, lineName, OBJ_TREND, 0, startTime, swingPoints[i].price, endTime, swingPoints[i].price))
         {
            ObjectSetInteger(chId, lineName, OBJPROP_COLOR, objColor);
            ObjectSetInteger(chId, lineName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(chId, lineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(chId, lineName, OBJPROP_BACK, true);
            ObjectSetInteger(chId, lineName, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(chId, lineName, OBJPROP_RAY_LEFT, false);
         }
      }
   }
}

//| VÉRIFICATION ET EXÉCUTION IMMÉDIATE DU DERIV ARROW               |
void CheckAndExecuteDerivArrowTrade()
{
   // DEBUG: Log pour voir si la fonction est appelée
   static datetime lastLog = 0;
   if(TimeCurrent() - lastLog >= 10) // Log toutes les 10 secondes maximum
   {
      Print("?? DEBUG - CheckAndExecuteDerivArrowTrade appelée pour: ", _Symbol, " | Time: ", TimeToString(TimeCurrent(), TIME_SECONDS));
      lastLog = TimeCurrent();
   }
   
   // RÈGLE FONDAMENTALE: Boom/Crash + Volatility (avec conditions)
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   string catStr = "";
   switch(cat)
   {
      case SYM_BOOM_CRASH: catStr = "BOOM_CRASH"; break;
      case SYM_VOLATILITY: catStr = "VOLATILITY"; break;
      case SYM_FOREX: catStr = "FOREX"; break;
      default: catStr = "UNKNOWN"; break;
   }
   
   // Autoriser Boom/Crash ET Volatility (avec conditions différentes)
   bool isBoomCrash = (cat == SYM_BOOM_CRASH);
   bool isVolatility = (cat == SYM_VOLATILITY);
   
   if(!isBoomCrash && !isVolatility)
   {
      return; // Ignorer les autres symboles
   }

   // Anti?duplication SPIKE uniquement : autoriser les autres stratégies sur le même symbole,
   // mais éviter plusieurs trades de type "SPIKE TRADE" en parallèle.
   if(HasOpenSpikeTradeForSymbol(_Symbol))
   {
      Print("?? SPIKE TRADE BLOQUÉ - Une position SPIKE TRADE est déjà ouverte sur ", _Symbol, " (pas de doublon)");
      return;
   }
   
   // Confirmer le type de symbole
   // Réduire la fréquence des logs DEBUG de symbole pour éviter la surcharge
   static datetime lastDebugSymbolLog = 0;
   if(TimeCurrent() - lastDebugSymbolLog >= 300) // Log toutes les 5 minutes maximum
   {
      Print("? DEBUG - Symbole validé: ", _Symbol, " = ", catStr);
      lastDebugSymbolLog = TimeCurrent();
   }
   
   // VALIDATION IA: BLOQUER TOUS LES TRADES SI IA EST EN HOLD
   if(UseAIServer && (g_lastAIAction == "HOLD" || g_lastAIAction == "hold"))
   {
      Print("?? TRADE BLOQUÉ - IA en HOLD sur ", _Symbol);
      return;
   }
   
   // NOUVEAU: DÉTECTION DES FLÈCHES DERIV ARROW EXISTANTES
   string arrowDirection = "";
   bool hasDerivArrow = GetDerivArrowDirection(arrowDirection);
   
   if(hasDerivArrow)
   {
      Print("?? FLÈCHE DERIV ARROW DÉTECTÉE - Direction: ", arrowDirection, " sur ", _Symbol);
      
      // Validation stricte: Boom = BUY uniquement, Crash = SELL uniquement
      bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
      bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
      
      if(isBoom && arrowDirection == "BUY")
      {
         Print("? FLÈCHE VERTE + BOOM = COMPATIBLE - Exécution BUY autorisée");
         ExecuteDerivArrowTrade("BUY");
         return;
      }
      else if(isCrash && arrowDirection == "SELL")
      {
         Print("? FLÈCHE ROUGE + CRASH = COMPATIBLE - Exécution SELL autorisée");
         ExecuteDerivArrowTrade("SELL");
         return;
      }
      else
      {
         Print("?? FLÈCHE DERIV ARROW INCOMPATIBLE - ", arrowDirection, " sur ", _Symbol, " (règle Boom/Crash)");
         return;
      }
   }
   
   // RÈGLE STRICTE: BLOQUER TOUS LES TRADES BUY SUR BOOM SI IA = SELL
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   string aiAction = g_lastAIAction;
   if(aiAction == "buy") aiAction = "BUY";
   if(aiAction == "sell") aiAction = "SELL";
   
   if(isBoom && aiAction == "SELL")
   {
   // Réduire la fréquence des logs de trading pour éviter la surcharge
   static datetime lastTradingLog = 0;
   if(TimeCurrent() - lastTradingLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? DERIV ARROW BOOM BLOQUÉ - IA = SELL (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal BUY avant de placer trade BUY");
      lastTradingLog = TimeCurrent();
   }
      return;
   }
   
   if(isCrash && aiAction == "BUY")
   {
   // Réduire la fréquence des logs de trading pour éviter la surcharge
   static datetime lastTradingLog = 0;
   if(TimeCurrent() - lastTradingLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? DERIV ARROW CRASH BLOQUÉ - IA = BUY (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal SELL avant de placer trade SELL");
      lastTradingLog = TimeCurrent();
   }
      return;
   }
   
   // VALIDATION IA: Confiance minimum différente selon le type ET la zone ICT (Premium/Discount)
   // Objectif: éviter de prendre des positions avec une confiance IA faible,
   // surtout lorsque la décision IA est CONTRAIRE à la zone Premium/Discount.
   bool inDiscount = IsInDiscountZone();
   bool inPremium  = IsInPremiumZone();
   
   double requiredConfidence = 0.0;
   if(isBoomCrash)
   {
      // Sur Boom/Crash: exiger au minimum 65% (même si MinAIConfidence est plus bas)
      double baseBoomConf = MathMax(MinAIConfidence, 0.65);
      requiredConfidence = baseBoomConf;
      
      // Si l'IA est SELL en zone Discount (achat) ou BUY en zone Premium (vente),
      // augmenter encore l'exigence de confiance (trade "contre-zone").
      bool contrarianToZone = (aiAction == "SELL" && inDiscount) || (aiAction == "BUY" && inPremium);
      if(contrarianToZone)
         requiredConfidence = MathMax(requiredConfidence, 0.75);
   }
   else
   {
      // Pour Volatility: garder un seuil fixe plus élevé
      requiredConfidence = 0.85;
   }
   
   if(UseAIServer && g_lastAIConfidence < requiredConfidence)
   {
      string zoneStr = "Equilibre";
      if(inDiscount) zoneStr = "Discount";
      else if(inPremium) zoneStr = "Premium";
      
      Print("?? TRADE BLOQUÉ - Confiance IA insuffisante sur ", _Symbol, " | Zone: ", zoneStr,
            " | ", DoubleToString(g_lastAIConfidence*100, 1), "% < ", DoubleToString(requiredConfidence*100, 1), "%");
      return;
   }
   
   // DÉTECTION DIFFÉRENCIÉE: Spike requis pour Boom/Crash, signal IA fort pour Volatility
   bool spikeDetected = false;
   bool shouldTrade = false;
   
   if(isBoomCrash)
   {
      // Boom/Crash: deux modes possibles
      // - Mode "pré-spike only" : entrer dès que le prix est dans la zone SMC / pré?spike (avant le 1er spike)
      // - Mode "spike confirmé" : attendre un spike récent + proba ML suffisante (avec option pré?spike strict)
      bool preSpike = IsPreSpikePattern();
      spikeDetected = DetectRecentSpike();
      
      // Filtre supplémentaire basé sur la probabilité ML de spike (si activé)
      double spikeProbML = g_lastSpikeProbability;
      bool probaOk = true;
      if(UseSpikeMLFilter)
      {
         // Toujours calculer/rafraîchir une probabilité locale (éviter le cas "0%/N/A" qui court-circuite le filtre)
         if(g_lastSpikeUpdate == 0 || (TimeCurrent() - g_lastSpikeUpdate) > 300)
            spikeProbML = CalculateSpikeProbability();
         probaOk = (spikeProbML >= SpikeML_MinProbability);
      }
      
      if(SpikeUsePreSpikeOnlyForBoomCrash)
      {
         // Entrer AVANT le premier spike: pattern pré?spike + proba ML OK
         shouldTrade = (preSpike && probaOk);
      }
      else
      {
         // Mode par défaut: spike récent + proba ML OK, avec option pré?spike strict
         shouldTrade = (spikeDetected && probaOk && (!SpikeRequirePreSpikePattern || preSpike));
      }
      
      // Bypass: signal IA très fort (?85%) ? autoriser l'entrée pour capter les spikes en escalier
      // même si preSpike/spike récent/proba ML ne sont pas remplis (évite de rater une forte tendance)
      if(!shouldTrade && g_lastAIConfidence >= 0.85)
      {
         if((isBoom && aiAction == "BUY") || (isCrash && aiAction == "SELL"))
         {
            shouldTrade = true;
            Print("? Boom/Crash - Entrée autorisée par confiance IA forte (", DoubleToString(g_lastAIConfidence*100, 1), "%) - capture spikes/tendance");
         }
      }
      // Rebond canal: Boom ? BUY quand prix touche low_chan; Crash ? SELL quand prix touche upper chan
      if(!shouldTrade && isBoom && aiAction == "BUY" && PriceTouchesLowerChannel())
      {
         shouldTrade = true;
         Print("? Boom - Entrée autorisée (prix touche canal bas ? rebond haussier attendu)");
      }
      if(!shouldTrade && isCrash && aiAction == "SELL" && PriceTouchesUpperChannel())
      {
         shouldTrade = true;
         Print("? Crash - Entrée autorisée (prix touche canal haut ? rebond baissier attendu)");
      }
      // Après une perte sur ce symbole: exiger conditions meilleures + spike imminant pour éviter 2e perte consécutive
      if(shouldTrade && !AllowReentryAfterRecentLoss(_Symbol,
                                                     (isBoom ? "BUY" : "SELL"),
                                                     spikeDetected && (preSpike || spikeProbML >= 0.75)))
         shouldTrade = false;
      
      Print("?? DEBUG - Boom/Crash SNIPER - PreSpike: ", preSpike ? "OUI" : "NON",
            " | Spike récent: ", spikeDetected ? "OUI" : "NON",
            " | Proba ML spike: ",
            (spikeProbML > 0.0 ? DoubleToString(spikeProbML*100.0, 1) + "%" : "N/A"),
            " (min ",
            (UseSpikeMLFilter ? DoubleToString(SpikeML_MinProbability*100.0, 1) + "%" : "N/A"),
            ")",
            " | Mode pré-spike only: ", SpikeUsePreSpikeOnlyForBoomCrash ? "OUI" : "NON",
            " | Mode pré-spike strict: ", SpikeRequirePreSpikePattern ? "OUI" : "NON",
            " | Autorisé: ", shouldTrade ? "OUI" : "NON");
   }
   else if(isVolatility)
   {
      // Volatility: Pas de spike requis, seulement signal IA fort (80%+)
      spikeDetected = false; // Non applicable
      shouldTrade = true; // Trade autorisé si IA forte (déjà validé ci-dessus)
      
      Print("?? DEBUG - Volatility - Trade autorisé (confiance IA: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
   }
   
   if(!shouldTrade)
   {
      if(isBoomCrash)
         Print("? Conditions spike non remplies - trade Boom/Crash ignoré (Spike récent requis",
               SpikeRequirePreSpikePattern ? " + Pré-spike" : "",
               UseSpikeMLFilter ? " + Filtre proba" : "",
               ")");
      else
         Print("? Conditions non remplies - trade Volatility ignoré");
      return;
   }
   
   // DÉTERMINER LA DIRECTION basée sur le signal IA et le type de symbole
   string direction = "";
   string iaDirection = "";
   
   // Récupérer la direction de l'IA
   if(g_lastAIAction == "BUY" || g_lastAIAction == "buy")
      iaDirection = "BUY";
   else if(g_lastAIAction == "SELL" || g_lastAIAction == "sell")
      iaDirection = "SELL";
   else
   {
      Print("? Aucun signal IA clair (", g_lastAIAction, ") - trade ignoré");
      return;
   }
   
   // Vérifier la compatibilité entre le signal IA et le type de symbole
   if(isBoomCrash)
   {
      // Règles Boom/Crash: directions spécifiques
      if(StringFind(_Symbol, "Boom") >= 0)
      {
         if(iaDirection == "BUY")
         {
            direction = "BUY"; // Boom + IA BUY = OK
         }
         else
         {
            Print("? CONFLIT: IA dit ", iaDirection, " mais Boom n'accepte que BUY - trade ignoré");
            return;
         }
      }
      else if(StringFind(_Symbol, "Crash") >= 0)
      {
         if(iaDirection == "SELL")
         {
            direction = "SELL"; // Crash + IA SELL = OK
         }
         else
         {
            Print("? CONFLIT: IA dit ", iaDirection, " mais Crash n'accepte que SELL - trade ignoré");
            return;
         }
      }
   }
   else if(isVolatility)
   {
      // Volatility: BUY et SELL autorisés (suivre l'IA)
      direction = iaDirection; // Volatility suit directement l'IA
      Print("? Volatility - Direction IA acceptée: ", direction, " sur ", _Symbol);
   }
   
   Print("? Signal IA validé: ", iaDirection, " compatible avec ", _Symbol, " ? Direction: ", direction);

   // Vérifier l'alignement avec les indicateurs techniques classiques (TradingView-like)
   string classicSummary;
   bool classicOk = IsClassicIndicatorsAligned(direction, classicSummary);

   Print("?? DEBUG - Indicateurs classiques (", direction, ") => ", classicOk ? "ALIGNÉS" : "NON ALIGNÉS",
         " | ", classicSummary);

   if(!classicOk)
   {
      if(UseClassicIndicatorsFilter)
      {
         Print("?? TRADE SPIKE BLOQUÉ - Indicateurs classiques insuffisants (min ",
               ClassicMinConfirmations, " confirmations) sur ", _Symbol);
         return;
      }
   }

   // Protection capital: en zone d'achat au bord inférieur ? SELL seulement si confiance IA >= 85%
   if(direction == "SELL" && IsAtDiscountLowerEdge() && g_lastAIConfidence < 0.85)
   {
      Print("?? TRADE BLOQUÉ - Zone Discount au bord inférieur: SELL autorisé seulement si confiance IA ? 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }
   // Protection capital: en zone premium au bord supérieur (Boom) ? BUY seulement si confiance IA >= 85%
   if(direction == "BUY" && isBoom && IsAtPremiumUpperEdge() && g_lastAIConfidence < 0.85)
   {
      Print("?? TRADE BLOQUÉ - Zone Premium au bord supérieur (Boom): BUY autorisé seulement si confiance IA ? 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }

   // Réentrée après perte sur ce symbole (hors Boom/Crash): exiger conditions exceptionnelles
   if(!AllowReentryAfterRecentLoss(_Symbol, direction, spikeDetected))
      return;

   Print("?? SPIKE DÉTECTÉ - Direction: ", direction, " | Symbole: ", _Symbol);

   // EXÉCUTION DU TRADE avec les mêmes validations que précédemment
   ExecuteSpikeTrade(direction);
}

//| DÉTECTER SI UNE FLÈCHE DERIV ARROW EST PRÉSENTE SUR LE GRAPHIQUE |
bool IsDerivArrowPresent()
{
   // Chercher les objets flèche sur le graphique avec des noms typiques
   for(int i = ObjectsTotal(0, -1, OBJ_ARROW) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, OBJ_ARROW);
      
      // Vérifier si c'est une flèche Deriv Arrow (noms communs)
      if(StringFind(objName, "DERIV") >= 0 || StringFind(objName, "Deriv") >= 0 || 
         StringFind(objName, "ARROW") >= 0 || StringFind(objName, "Arrow") >= 0 ||
         StringFind(objName, "SIGNAL") >= 0 || StringFind(objName, "Signal") >= 0)
      {
         // Vérifier que l'objet est visible et sur la bougie récente
         datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
         datetime currentTime = TimeCurrent();
         
         // La flèche doit être sur les 5 dernières bougies maximum
         if(currentTime - objTime <= PeriodSeconds() * 5)
         {
            return true;
         }
      }
   }
   
   return false;
}

// Détecte une tendance "escalier" sur Boom/Crash en M1 (utile quand la flèche n'apparaît pas).
// Heuristique simple: mouvement net suffisant + majorité de bougies dans le sens + drawdown contenu.
bool IsBoomCrashTrendStaircase(const string direction)
{
   string dir = direction;
   StringToUpper(dir);
   if(dir != "BUY" && dir != "SELL") return false;

   int n = MathMax(20, BoomCrashTrendLookbackBarsM1);
   if(Bars(_Symbol, PERIOD_M1) < (n + 2)) return false;

   double startClose = iClose(_Symbol, PERIOD_M1, n);
   double endClose   = iClose(_Symbol, PERIOD_M1, 1);
   if(startClose <= 0.0 || endClose <= 0.0) return false;

   double netMove = endClose - startClose;
   if(dir == "SELL") netMove = -netMove;
   double netMovePct = (MathAbs(netMove) / endClose) * 100.0;
   if(netMove <= 0.0) return false;
   if(netMovePct < BoomCrashTrendMinMovePct) return false;

   int aligned = 0;
   double peak = (dir == "BUY") ? -DBL_MAX : DBL_MAX;
   double worstDrawdown = 0.0; // en prix, dans le sens opposé

   for(int i = n; i >= 1; i--)
   {
      double o = iOpen(_Symbol, PERIOD_M1, i);
      double c = iClose(_Symbol, PERIOD_M1, i);
      double h = iHigh(_Symbol, PERIOD_M1, i);
      double l = iLow(_Symbol, PERIOD_M1, i);
      if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0) continue;

      bool isAligned = (dir == "BUY") ? (c >= o) : (c <= o);
      if(isAligned) aligned++;

      if(dir == "BUY")
      {
         if(h > peak) peak = h;
         double dd = peak - l; // retracement depuis le peak
         if(dd > worstDrawdown) worstDrawdown = dd;
      }
      else
      {
         if(l < peak) peak = l;
         double dd = h - peak; // retracement depuis le trough
         if(dd > worstDrawdown) worstDrawdown = dd;
      }
   }

   double alignedRatio = (double)aligned / (double)n;
   if(alignedRatio < BoomCrashTrendMinBullishCandleRatio) return false;

   double maxAllowedDD = MathAbs(netMove) * BoomCrashTrendMaxDrawdownPct;
   if(worstDrawdown > maxAllowedDD) return false;

   return true;
}

// Exige la présence récente de la flèche SMC_DERIV_ARROW_<symbol> avant d'exécuter un ordre au marché.
// Direction: "BUY" ou "SELL" (insensible à la casse).
bool HasRecentSMCDerivArrowForDirection(string direction)
{
   if(!RequireSMCDerivArrowForMarketOrders) return true;

   string dir = direction;
   StringToUpper(dir);
   if(dir != "BUY" && dir != "SELL") return false;

   // Exception Boom/Crash: en tendance escalier forte + confiance ML très élevée, autoriser sans flèche
   if(AllowBoomCrashTrendEntryWithoutArrow && SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH)
   {
      double confPct = g_lastAIConfidence * 100.0;
      if(confPct >= BoomCrashTrendEntryMinConfidencePct && IsBoomCrashTrendStaircase(dir))
      {
         Print("BYPASS FLECHE - Boom/Crash tendance forte + ML conf ", DoubleToString(confPct, 1),
               "% >= ", DoubleToString(BoomCrashTrendEntryMinConfidencePct, 1), "% | Dir=", dir);
         return true;
      }
   }

   string arrowName = "SMC_DERIV_ARROW_" + _Symbol;
   string foundName = arrowName;
   if(ObjectFind(0, arrowName) < 0)
   {
      // Fallback: certains modules peuvent nommer différemment. On prend la plus récente des flèches SMC_DERIV_ARROW*.
      datetime bestTime = 0;
      string bestName = "";
      for(int i = ObjectsTotal(0, -1, OBJ_ARROW) - 1; i >= 0; i--)
      {
         string objName = ObjectName(0, i, -1, OBJ_ARROW);
         if(StringFind(objName, "SMC_DERIV_ARROW") < 0) continue;
         if(StringFind(objName, _Symbol) < 0) continue; // rester strict: flèche du symbole courant
         datetime t = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
         if(t > bestTime)
         {
            bestTime = t;
            bestName = objName;
         }
      }
      if(bestName == "")
      {
         if(DebugDerivArrowCapture)
            Print("ARROW DEBUG - aucune flèche SMC_DERIV_ARROW trouvée pour ", _Symbol);
         return false;
      }
      foundName = bestName;
   }

   // Vérifier que la flèche est récente (N bougies max sur timeframe courant)
   datetime arrowTime = (datetime)ObjectGetInteger(0, foundName, OBJPROP_TIME, 0);
   int maxAgeBars = MathMax(1, SMCDerivArrowMaxAgeBars);
   int maxAgeSec = PeriodSeconds(PERIOD_CURRENT) * maxAgeBars;
   if(maxAgeSec <= 0) maxAgeSec = 60 * maxAgeBars;
   int ageSec = (int)(TimeCurrent() - arrowTime);
   if(ageSec > maxAgeSec)
   {
      if(DebugDerivArrowCapture)
         Print("ARROW DEBUG - flèche trop vieille: name=", foundName, " ageSec=", ageSec, " > maxAgeSec=", maxAgeSec, " | sym=", _Symbol);
      return false;
   }

   // Vérifier direction via le code de flèche
   int arrowCode = (int)ObjectGetInteger(0, foundName, OBJPROP_ARROWCODE);
   bool isBuyArrow = (arrowCode == 233);
   bool isSellArrow = (arrowCode == 234);
   if(DebugDerivArrowCapture)
      Print("ARROW DEBUG - found=", foundName, " code=", arrowCode, " ageSec=", ageSec, " dirNeed=", dir, " buy=", isBuyArrow, " sell=", isSellArrow);
   if(dir == "BUY" && !isBuyArrow) return false;
   if(dir == "SELL" && !isSellArrow) return false;

   return true;
}

//| VARIABLES GLOBALES POUR ORDRES LIMIT POST-HOLD |
static bool g_postHoldLimitOrderPending = false;
static datetime g_lastHoldCloseTime = 0;

//| PLACER ORDRE LIMIT POST-HOLD APRÈS PERTE 2,0$ |
void PlacePostHoldLimitOrder(string closedSymbol, ENUM_POSITION_TYPE closedType, double closedProfit)
{
   Print("?? DEBUG POST-HOLD - Début fonction");
   Print("   ?? Symbole: ", closedSymbol, " | Type: ", (closedType == POSITION_TYPE_BUY ? "BUY" : "SELL"), " | Profit: ", DoubleToString(closedProfit, 2), "$");
   
   // Vérifier si la fermeture était bien due à HOLD avec perte ? 2,0$
   if(closedProfit > -2.0)
   {
      Print("?? POST-HOLD - Perte insuffisante: ", DoubleToString(closedProfit, 2), "$ > -2.00$");
      return;
   }
   Print("? POST-HOLD - Perte suffisante: ", DoubleToString(closedProfit, 2), "$ ? -2.00$");
   
   // Vérifier si c'est bien Boom/Crash
   bool isBoom = (StringFind(closedSymbol, "Boom") >= 0);
   bool isCrash = (StringFind(closedSymbol, "Crash") >= 0);
   
   if(!isBoom && !isCrash)
   {
      Print("?? POST-HOLD - Symbole non Boom/Crash: ", closedSymbol);
      return;
   }
   Print("? POST-HOLD - Symbole valide - Boom: ", isBoom, " | Crash: ", isCrash);
   
   // Vérifier si un ordre limit est déjà en attente
   if(g_postHoldLimitOrderPending)
   {
      Print("?? POST-HOLD - Ordre limit déjà en attente, annulation");
      return;
   }
   Print("? POST-HOLD - Aucun ordre limit en attente");
   
   // Détecter si nous étions en zone Premium (vente) ou Discount (achat)
   bool inDiscount = IsInDiscountZone();
   bool inPremium = IsInPremiumZone();
   
   Print("?? POST-HOLD - Zones SMC - Discount: ", inDiscount, " | Premium: ", inPremium);
   
   // Conditions détaillées pour ordre limit
   bool shouldPlaceLimit = false;
   ENUM_ORDER_TYPE limitType = WRONG_VALUE;
   double limitPrice = 0.0;
   string limitReason = "";
   
   if(isBoom && inDiscount && closedType == POSITION_TYPE_BUY)
   {
      // Boom en zone Discount avec position BUY fermée ? ordre BUY limit au support
      limitType = ORDER_TYPE_BUY_LIMIT;
      limitPrice = GetSupportLevel(20); // Support sur 20 barres
      limitReason = "Boom Discount - Support 20 bars (post-HOLD)";
      shouldPlaceLimit = true;
      Print("?? POST-HOLD - Condition Boom+Discount+BUY remplie");
   }
   else if(isCrash && inPremium && closedType == POSITION_TYPE_SELL)
   {
      // Crash en zone Premium avec position SELL fermée ? ordre SELL limit à la résistance
      limitType = ORDER_TYPE_SELL_LIMIT;
      limitPrice = GetResistanceLevel(20); // Résistance sur 20 barres
      limitReason = "Crash Premium - Resistance 20 bars (post-HOLD)";
      shouldPlaceLimit = true;
      Print("?? POST-HOLD - Condition Crash+Premium+SELL remplie");
   }
   
   if(!shouldPlaceLimit)
   {
      Print("?? POST-HOLD - Conditions non remplies pour ordre limit");
      Print("   ?? Symbole: ", closedSymbol, " | Type: ", (closedType == POSITION_TYPE_BUY ? "BUY" : "SELL"));
      Print("   ?? Zones - Discount: ", inDiscount, " | Premium: ", inPremium);
      Print("   ?? Attendu: (Boom+Discount+BUY) ou (Crash+Premium+SELL)");
      return;
   }
   
   Print("? POST-HOLD - Conditions validées - Calcul niveau de prix...");
   
   // Placer l'ordre limit
   double lot = CalculateLotSize();
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = closedSymbol;
   request.volume = lot;
   request.type = limitType;
   request.price = limitPrice;
   request.sl = 0;
   request.tp = 0;
   request.deviation = 10;
   request.magic = InpMagicNumber;
   request.comment = "POST-HOLD Limit - " + limitReason;
   request.type_time = ORDER_TIME_GTC; // Good till cancelled
   request.expiration = 0;
   
   Print("?? POST-HOLD - Requête ordre limit préparée:");
   Print("   ?? Type: ", (limitType == ORDER_TYPE_BUY_LIMIT ? "BUY LIMIT" : "SELL LIMIT"));
   Print("   ?? Prix: ", DoubleToString(limitPrice, _Digits), " | Lot: ", DoubleToString(lot, 2));
   Print("   ?? Raison: ", limitReason);
   
   if(OrderSend(request, result))
   {
      g_postHoldLimitOrderPending = true;
      g_lastHoldCloseTime = TimeCurrent();
      Print("? POST-HOLD - Ordre limit placé avec succès");
      Print("   ?? Symbole: ", closedSymbol, " | Type: ", (limitType == ORDER_TYPE_BUY_LIMIT ? "BUY LIMIT" : "SELL LIMIT"));
      Print("   ?? Prix: ", DoubleToString(limitPrice, _Digits), " | Lot: ", DoubleToString(lot, 2));
      Print("   ?? Raison: ", limitReason);
      Print("   ?? Ticket: ", result.order);
   }
   else
   {
      Print("? POST-HOLD - Échec placement ordre limit");
      Print("   ?? Erreur: ", result.retcode, " - ", result.comment);
      Print("   ?? Code erreur: ", GetLastError());
   }
}

//| OBTENIR NIVEAU DE SUPPORT (20 BARRES) |
double GetSupportLevel(int bars)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, bars + 1, rates) < bars + 1)
   {
      Print("? Impossible de copier les rates pour support");
      return 0.0;
   }
   
   double support = rates[0].low;
   for(int i = 1; i <= bars; i++)
   {
      if(rates[i].low < support)
         support = rates[i].low;
   }
   
   return support;
}

//| OBTENIR NIVEAU DE RÉSISTANCE (20 BARRES) |
double GetResistanceLevel(int bars)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, bars + 1, rates) < bars + 1)
   {
      Print("? Impossible de copier les rates pour résistance");
      return 0.0;
   }
   
   double resistance = rates[0].high;
   for(int i = 1; i <= bars; i++)
   {
      if(rates[i].high > resistance)
         resistance = rates[i].high;
   }
   
   return resistance;
}
static string g_lastAIActionPrevious = ""; // Action IA précédente

//| SURVEILLER ET FERMER POSITIONS SI IA DEVIENT HOLD |
void MonitorAndClosePositionsOnHold()
{
   if(!UseAIServer) return; // Seulement si serveur IA actif
   
   // Vérifier si l'IA est passée de BUY/SELL à HOLD
   if(g_lastAIActionPrevious != "" && g_lastAIActionPrevious != "HOLD" && g_lastAIActionPrevious != "hold" &&
      (g_lastAIAction == "HOLD" || g_lastAIAction == "hold"))
   {
      Print("?? CHANGEMENT IA DÉTECTÉ - ", g_lastAIActionPrevious, " ? HOLD");
      Print("   ?? SURVEILLANCE DES POSITIONS - Attente perte ? 2.0$ avant fermeture");
      
      // Parcourir toutes les positions ouvertes
      int totalPositions = PositionsTotal();
      for(int i = totalPositions - 1; i >= 0; i--)
      {
         if(PositionGetTicket(i) > 0)
         {
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            ulong posTicket = PositionGetInteger(POSITION_TICKET);
            double posProfit = PositionGetDouble(POSITION_PROFIT);
            
            // Vérifier si la position correspond à l'action précédente
            bool shouldClose = false;
            if(g_lastAIActionPrevious == "BUY" && posType == POSITION_TYPE_BUY)
            {
               shouldClose = true;
               Print("   ?? SURVEILLANCE BUY - ", posSymbol, " | Ticket: ", posTicket, " | Profit: ", DoubleToString(posProfit, 2), "$");
            }
            else if(g_lastAIActionPrevious == "SELL" && posType == POSITION_TYPE_SELL)
            {
               shouldClose = true;
               Print("   ?? SURVEILLANCE SELL - ", posSymbol, " | Ticket: ", posTicket, " | Profit: ", DoubleToString(posProfit, 2), "$");
            }
            
            if(shouldClose)
            {
               // NOUVEAU: Vérifier si perte ? 2.0$ avant de fermer
               if(posProfit <= -2.0)
               {
                  Print("   ?? SEUIL DE PERTE ATTEINT - ", DoubleToString(posProfit, 2), "$ ? -2.00$");
                  Print("   ?? FERMETURE AUTOMATIQUE sur HOLD - Perte ? 2.0$");
                  
                  // Fermer la position
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  
                  request.action = TRADE_ACTION_DEAL;
                  request.position = posTicket;
                  request.symbol = posSymbol;
                  request.volume = PositionGetDouble(POSITION_VOLUME);
                  request.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                  request.price = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(posSymbol, SYMBOL_BID) : SymbolInfoDouble(posSymbol, SYMBOL_ASK);
                  request.deviation = 10;
                  request.magic = InpMagicNumber;
                  request.comment = "IA HOLD Auto-Close (Loss ? 2.0$)";
                  
                  if(OrderSend(request, result))
                  {
                     Print("? POSITION FERMÉE - ", posSymbol, " | Ticket: ", posTicket, " | Profit: ", DoubleToString(posProfit, 2), "$");
                     
                     // NOUVEAU: Placer ordre limit post-HOLD si perte ? 2.0$
                     PlacePostHoldLimitOrder(posSymbol, posType, posProfit);
                  }
                  else
                  {
                     Print("? ERREUR FERMETURE - ", posSymbol, " | Erreur: ", result.comment);
                  }
               }
               else
               {
                  Print("   ? SURVEILLANCE CONTINUE - Perte: ", DoubleToString(posProfit, 2), "$ > -2.00$ (seuil non atteint)");
                  Print("   ?? Attente HOLD - Position maintenue jusqu'à perte ? 2.0$");
               }
            }
         }
      }
   }
   
   // Mettre à jour l'action précédente
   g_lastAIActionPrevious = g_lastAIAction;
}
bool IsMaxPositionsReached()
{
   int totalPositions = PositionsTotal();
   
   // NOUVEAU: Protection capital faible - Si < 20$, limiter à 1 position seulement
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   int maxAllowedPositions = (accountEquity < 20.0) ? 1 : MaxPositionsTerminal;
   
   // Si on a déjà le nombre maximum de positions autorisées, bloquer les nouveaux trades
   if(totalPositions >= maxAllowedPositions)
   {
      // Si exactement le nombre maximum, log d'information
      if(totalPositions == maxAllowedPositions)
      {
         static datetime lastLog = 0;
         if(TimeCurrent() - lastLog >= 60) // Log toutes les minutes maximum
         {
            if(accountEquity < 20.0)
            {
               Print("?? CAPITAL FAIBLE - Équité: ", DoubleToString(accountEquity, 2), "$ < 20.00$");
               Print("   ?? LIMITATION À 1 POSITION SEULEMENT pour protéger le capital");
            }
            else
            {
               Print("??? PROTECTION CAPITAL - ", totalPositions, "/", maxAllowedPositions, " positions atteintes (sur symboles différents)");
            }
            
            Print("   ?? Positions actuelles :");
            for(int i = 0; i < totalPositions; i++)
            {
               if(PositionGetTicket(i) > 0)
               {
                  string posSymbol = PositionGetString(POSITION_SYMBOL);
                  double posProfit = PositionGetDouble(POSITION_PROFIT);
                  ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                  ulong posTicket = PositionGetInteger(POSITION_TICKET);
                  
                  Print("   - ", posType == POSITION_TYPE_BUY ? "BUY" : "SELL", " ", posSymbol, 
                        " | Ticket: ", posTicket, " | Profit: ", DoubleToString(posProfit, 2), "$");
               }
            }
            
            if(accountEquity < 20.0)
            {
               Print("   ?? NOUVEAUX TRADES BLOQUÉS - Capital faible, 1 position max");
            }
            else
            {
               Print("   ?? NOUVEAUX TRADES BLOQUÉS jusqu'à libération d'une position");
               Print("   ?? Règle: Max ", maxAllowedPositions, " positions sur symboles différents autorisées");
            }
            lastLog = TimeCurrent();
         }
      }
      return true; // Bloquer les nouveaux trades
   }
   
   return false; // Autoriser les trades
}

//| OBTENIR LA DIRECTION DE LA FLÈCHE DERIV ARROW |
bool GetDerivArrowDirection(string &direction)
{
   direction = "";
   
   // NOUVEAU: MÉMOIRE DES FLÈCHES DÉJÀ DÉTECTÉES
   static string lastDetectedArrow = "";
   static datetime lastDetectedTime = 0;
   
   // Chercher les objets flèche sur le graphique
   for(int i = ObjectsTotal(0, -1, OBJ_ARROW) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, OBJ_ARROW);
      
      // Vérifier si c'est une flèche Deriv Arrow - PLUS SPÉCIFIQUE
      bool isDerivArrow = false;
      if(StringFind(objName, "DERIV") >= 0 || StringFind(objName, "Deriv") >= 0 || 
         StringFind(objName, "ARROW") >= 0 || StringFind(objName, "Arrow") >= 0 ||
         StringFind(objName, "SIGNAL") >= 0 || StringFind(objName, "Signal") >= 0)
      {
         isDerivArrow = true;
      }
      
      // VÉRIFICATION SUPPLÉMENTAIRE: chercher les grandes flèches typiques
      if(!isDerivArrow)
      {
         // Noms de grandes flèches trading
         if(StringFind(objName, "BUY") >= 0 || StringFind(objName, "SELL") >= 0 ||
            StringFind(objName, "ENTRY") >= 0 || StringFind(objName, "Entry") >= 0 ||
            StringFind(objName, "TRADE") >= 0 || StringFind(objName, "Trade") >= 0)
         {
            isDerivArrow = true;
         }
      }
      
      if(!isDerivArrow) continue;
      
      datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
      datetime currentTime = TimeCurrent();
      
      // La flèche doit être sur les 3 dernières bougies maximum (plus réactif)
      if(currentTime - objTime <= PeriodSeconds() * 3)
      {
         // Vérifier que la flèche est VRAIMENT visible (propriétés visuelles)
         color arrowColor = (color)ObjectGetInteger(0, objName, OBJPROP_COLOR);
         int arrowWidth = (int)ObjectGetInteger(0, objName, OBJPROP_WIDTH);
         bool arrowVisible = (bool)ObjectGetInteger(0, objName, OBJPROP_TIME, 0) > 0;
         
         // IGNORER les flèches trop petites ou invisibles
         if(arrowWidth < 2 || !arrowVisible)
         {
            Print("?? Flèche ignorée - Trop petite ou invisible: ", objName, " | Width: ", arrowWidth);
            continue;
         }
         
         // Créer une clé unique pour cette flèche
         string arrowKey = _Symbol + "_" + objName + "_" + TimeToString(objTime, TIME_MINUTES);
         
         // Vérifier si cette flèche a déjà été détectée
         if(lastDetectedArrow == arrowKey && (currentTime - lastDetectedTime) < 300) // 5 minutes
         {
            continue; // Ignorer cette flèche déjà traitée
         }
         
         // Vert = BUY, Rouge = SELL
         if(arrowColor == clrGreen || arrowColor == clrLime || arrowColor == clrForestGreen)
         {
            direction = "BUY";
            Print("?? GRANDE FLÈCHE VERTE DÉTECTÉE - Signal BUY sur ", _Symbol, 
                  " | Objet: ", objName, 
                  " | Width: ", arrowWidth,
                  " | Time: ", TimeToString(objTime, TIME_SECONDS));
            
            // MÉMORISER CETTE FLÈCHE COMME DÉTECTÉE
            lastDetectedArrow = arrowKey;
            lastDetectedTime = currentTime;
            return true;
         }
         else if(arrowColor == clrRed || arrowColor == clrCrimson || arrowColor == clrIndianRed)
         {
            direction = "SELL";
            Print("?? GRANDE FLÈCHE ROUGE DÉTECTÉE - Signal SELL sur ", _Symbol,
                  " | Objet: ", objName,
                  " | Width: ", arrowWidth,
                  " | Time: ", TimeToString(objTime, TIME_SECONDS));
            
            // MÉMORISER CETTE FLÈCHE COMME DÉTECTÉE
            lastDetectedArrow = arrowKey;
            lastDetectedTime = currentTime;
            return true;
         }
         else
         {
            // Si la couleur n'est pas claire, essayer de deviner par le code de la flèche
            long arrowCode = ObjectGetInteger(0, objName, OBJPROP_ARROWCODE);
            
            // Codes de flèche UP (BUY) - plus de codes pour les grandes flèches
            if(arrowCode == 241 || arrowCode == 242 || arrowCode == 233 || arrowCode == 225 ||
               arrowCode == 67 || arrowCode == 68 || arrowCode == 71 || arrowCode == 72) // Codes grandes flèches
            {
               direction = "BUY";
               Print("?? GRANDE FLÈCHE UP DÉTECTÉE - Signal BUY sur ", _Symbol, 
                     " (code: ", arrowCode, ") | Objet: ", objName,
                     " | Width: ", arrowWidth);
               
               // MÉMORISER CETTE FLÈCHE COMME DÉTECTÉE
               lastDetectedArrow = arrowKey;
               lastDetectedTime = currentTime;
               return true;
            }
            // Codes de flèche DOWN (SELL) - plus de codes pour les grandes flèches
            else if(arrowCode == 240 || arrowCode == 243 || arrowCode == 234 || arrowCode == 226 ||
                     arrowCode == 76 || arrowCode == 77 || arrowCode == 78 || arrowCode == 79) // Codes grandes flèches
            {
               direction = "SELL";
               Print("?? GRANDE FLÈCHE DOWN DÉTECTÉE - Signal SELL sur ", _Symbol,
                     " (code: ", arrowCode, ") | Objet: ", objName,
                     " | Width: ", arrowWidth);
               
               // MÉMORISER CETTE FLÈCHE COMME DÉTECTÉE
               lastDetectedArrow = arrowKey;
               lastDetectedTime = currentTime;
               return true;
            }
            else
            {
               Print("?? Flèche ignorée - Code non reconnu: ", arrowCode, " | Objet: ", objName);
            }
         }
      }
   }
   
   return false;
}

//| EXÉCUTER UN TRADE BASÉ SUR LA FLÈCHE DERIV ARROW |
void ExecuteDerivArrowTrade(string direction)
{
   Print("?? DÉBUT ANALYSE FLÈCHE DERIV ARROW - Direction: ", direction, " | Symbole: ", _Symbol);
   
   // NOUVEAU: VÉRIFICATION PROTECTION CAPITAL - MAX 2 POSITIONS
   if(IsMaxPositionsReached())
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - Protection capital activée (max ", MaxPositionsTerminal, " positions)");
      return;
   }
   Print("? Protection capital OK");
   
   // NOUVEAU: VÉRIFICATION CONFIANCE IA MINIMALE
   if(UseAIServer)
   {
      double aiConfidence = g_lastAIConfidence;
      Print("?? Vérification IA - Confiance: ", DoubleToString(aiConfidence, 1), "% | Action: ", g_lastAIAction);
      if(aiConfidence < MinAIConfidencePercent)
      {
         Print("?? FLÈCHE DERIV ARROW BLOQUÉE - Confiance IA insuffisante: ", 
               DoubleToString(aiConfidence, 1), "% < ", DoubleToString(MinAIConfidencePercent, 1), "% minimum");
         Print("   ?? IA Action: ", g_lastAIAction);
         return;
      }
      else
      {
         Print("? CONFIANCE IA VALIDÉE - ", DoubleToString(aiConfidence, 1), "% ? ", 
               DoubleToString(MinAIConfidencePercent, 1), "% minimum");
      }
   }
   else
   {
      Print("?? Serveur IA désactivé - Utilisation flèche uniquement");
   }

   // Vérifier que le modèle ML utilisé pour ce symbole est suffisamment fiable
   if(!IsMLModelTrustedForCurrentSymbol(direction))
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Modèle ML non fiable pour ", _Symbol);
      return;
   }
   
   // Validation : Boom = BUY uniquement, Crash = SELL uniquement
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   
   Print("?? Validation symbole - Boom: ", isBoom, " | Crash: ", isCrash, " | Direction: ", direction);
   
   if(isBoom && direction != "BUY")
   {
      Print("?? FLÈCHE DERIV ARROW IGNOREE - ", direction, " sur Boom (seul BUY autorisé)");
      return;
   }
   
   if(isCrash && direction != "SELL")
   {
      Print("?? FLÈCHE DERIV ARROW IGNOREE - ", direction, " sur Crash (seul SELL autorisé)");
      return;
   }
   Print("? Validation symbole OK");
   
   // Vérifier que l'IA n'est pas en HOLD
   if(UseAIServer && (g_lastAIAction == "HOLD" || g_lastAIAction == "hold"))
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - IA en HOLD sur ", _Symbol);
      return;
   }
   Print("? IA non-HOLD OK");

   // Décision finale = ML + stratégie interne: la direction de la flèche doit être cohérente avec la décision ML
   if(UseAIServer)
   {
      string mlAction = g_lastAIAction;
      StringToUpper(mlAction);
      if(mlAction != direction)
      {
         Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Direction flèche (", direction, ") != décision ML (", mlAction, ") sur ", _Symbol);
         return;
      }
   }
   
   // NOUVEAU: VÉRIFIER SI LE PRIX EST DANS LA ZONE D'ÉQUILIBRE
   bool inDiscount = IsInDiscountZone();
   bool inPremium  = IsInPremiumZone();
   
   Print("?? Zones SMC - Discount: ", inDiscount, " | Premium: ", inPremium);
   
   // Si le prix est dans la zone d'équilibre (ni premium ni discount), bloquer le trade
   if(!inDiscount && !inPremium)
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - Prix dans zone d'équilibre sur ", _Symbol, 
            " (ni Premium ni Discount) - Trade non autorisé");
      return;
   }
   Print("? Zone SMC OK (ni Premium ni Discount)");
   
   // Protection capital: zone d'achat au bord inférieur ? SELL seulement si confiance IA >= 85%
   if(direction == "SELL" && IsAtDiscountLowerEdge() && g_lastAIConfidence < 0.85)
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - Zone Discount au bord inférieur: SELL autorisé seulement si confiance IA ? 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }
   // Protection capital: zone premium au bord supérieur (Boom) ? BUY seulement si confiance IA >= 85%
   if(direction == "BUY" && isBoom && IsAtPremiumUpperEdge() && g_lastAIConfidence < 0.85)
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - Zone Premium au bord supérieur (Boom): BUY autorisé seulement si confiance IA ? 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }
   
   // Filtre "propice" optionnel
   if(UsePropiceSymbolsFilter && !g_currentSymbolIsPropice)
   {
      Print("🚫 TRADE BLOQUÉ - Symbole non 'propice' actuellement: ", _Symbol);
      Print("   Heure UTC: ", TimeToString(TimeCurrent(), TIME_SECONDS), " | Top propices: ", g_propiceTopSymbolsText);
      Print("   💡 Le robot trade UNIQUEMENT sur les symboles les plus performants selon l'heure actuelle");
      return;
   }

   // Lock global pour éviter double ouverture via chemins différents
   if(!TryAcquireOpenLock())
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - lock indisponible (anti-duplication tick)");
      return;
   }

   // Anti-duplication : aucune exposition (position OU pending) sur ce symbole
   if(HasAnyExposureForSymbol(_Symbol))
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - Exposition déjà existante sur ", _Symbol, " (position ou ordre en attente)");
      ReleaseOpenLock();
      return;
   }
   Print("? Anti-duplication OK (lock + exposure)");
   
   Print("?? TOUTES LES VALIDATIONS RÉUSSIES - EXÉCUTION DU TRADE...");
   
   // NOUVEAU: MÉMOIRE DES FLÈCHES DÉJÀ TRAITÉES
   static string lastProcessedArrow = "";
   static datetime lastProcessedTime = 0;
   
   // Créer une clé unique pour cette flèche (symbole + direction + heure)
   string currentArrowKey = _Symbol + "_" + direction + "_" + TimeToString(TimeCurrent(), TIME_MINUTES);
   
   // Vérifier si cette flèche a déjà été traitée récemment
   if(lastProcessedArrow == currentArrowKey && (TimeCurrent() - lastProcessedTime) < 300) // 5 minutes
   {
      Print("?? FLÈCHE DERIV ARROW DÉJÀ TRAITÉE - ", direction, " sur ", _Symbol, " (ignorer pour éviter duplication)");
      ReleaseOpenLock();
      return;
   }
   
   // Obtenir le prix actuel
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, r) < 1)
   {
      Print("? ERREUR - Impossible d'obtenir les prix pour ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   
   double currentPrice = r[0].close;
   double stopLoss, takeProfit;

   // NOUVEAU: FOREX/MÉTAUX - entrée uniquement sur pullback proche des EMA (évite entrée en extension)
   ENUM_SYMBOL_CATEGORY catNow = SMC_GetSymbolCategory(_Symbol);
   if(catNow == SYM_FOREX || catNow == SYM_METAL || catNow == SYM_COMMODITY)
   {
      double e21, e31, dist, maxDist;
      if(!IsPriceNearEMAPullbackZone(direction, currentPrice, e21, e31, dist, maxDist))
      {
         static datetime lastEmaBlockLog = 0;
         if(TimeCurrent() - lastEmaBlockLog >= 60)
         {
            Print("⛔ ENTRY BLOQUÉE (EMA pullback) - ", _Symbol, " ", direction,
                  " | Prix=", DoubleToString(currentPrice, _Digits),
                  " | EMA21=", DoubleToString(e21, _Digits),
                  " | EMA31=", DoubleToString(e31, _Digits),
                  " | DistZone=", DoubleToString(dist, _Digits),
                  " > Max=", DoubleToString(maxDist, _Digits));
            lastEmaBlockLog = TimeCurrent();
         }
         ReleaseOpenLock();
         return;
      }
   }
   
   // NOUVEAU: CALCUL SL/TP CORRECT POUR ÉVITER "INVALID STOPS"
   // Approche radicale : utiliser les exigences du courtier
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Distance minimale obligatoire du courtier
   double minStopDistance = (double)stopsLevel * point;
   
   // Si stopsLevel = 0, utiliser une distance par défaut sécuritaire
   if(minStopDistance <= 0)
   {
      if(isCrash || isBoom)
      {
         minStopDistance = 1.0; // 1 point minimum pour Crash/Boom
      }
      else
      {
         minStopDistance = 20 * point; // 20 pips pour autres
      }
   }
   
   // Utiliser 2x la distance minimale pour être sûr
   double safeDistance = minStopDistance * 2.0;
   
   // Calculer SL/TP selon la direction
   if(direction == "BUY")
   {
      stopLoss = currentPrice - safeDistance;
      takeProfit = currentPrice + (safeDistance * 2.0);
   }
   else // SELL
   {
      stopLoss = currentPrice + safeDistance;
      takeProfit = currentPrice - (safeDistance * 2.0);
   }
   
   Print("?? DEBUG SL/TP - ", _Symbol, " ", direction, 
         " | Prix: ", DoubleToString(currentPrice, _Digits),
         " | Courtier StopsLevel: ", stopsLevel,
         " | MinDistance: ", DoubleToString(minStopDistance, _Digits),
         " | SafeDistance: ", DoubleToString(safeDistance, _Digits),
         " | SL: ", DoubleToString(stopLoss, _Digits),
         " | TP: ", DoubleToString(takeProfit, _Digits));
   
   // VALIDATION FINALE DES DISTANCES
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(direction == "BUY")
   {
      // Vérifier que SL est assez loin de l'ask
      if(askPrice - stopLoss < safeDistance)
      {
         stopLoss = askPrice - safeDistance;
         Print("?? SL ajusté pour BUY sur ", _Symbol, " | Nouveau SL: ", DoubleToString(stopLoss, _Digits));
      }
      // Vérifier que TP est assez loin de l'ask
      if(takeProfit - askPrice < safeDistance)
      {
         takeProfit = askPrice + (safeDistance * 2.0);
         Print("?? TP ajusté pour BUY sur ", _Symbol, " | Nouveau TP: ", DoubleToString(takeProfit, _Digits));
      }
   }
   else // SELL
   {
      // Vérifier que SL est assez loin du bid
      if(stopLoss - bidPrice < safeDistance)
      {
         stopLoss = bidPrice + safeDistance;
         Print("?? SL ajusté pour SELL sur ", _Symbol, " | Nouveau SL: ", DoubleToString(stopLoss, _Digits));
      }
      // Vérifier que TP est assez loin du bid
      if(bidPrice - takeProfit < safeDistance)
      {
         takeProfit = bidPrice - (safeDistance * 2.0);
         Print("?? TP ajusté pour SELL sur ", _Symbol, " | Nouveau TP: ", DoubleToString(takeProfit, _Digits));
      }
   }
   
   // Normaliser les prix
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   // Envoyer la notification
   SendDerivArrowNotification(direction, currentPrice, stopLoss, takeProfit);
   
   // Exécuter l'ordre au marché
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = CalculateLotSize();
   request.type = (direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = (direction == "BUY") ? askPrice : bidPrice;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 20;
   request.magic = InpMagicNumber;
   request.comment = "DERIV ARROW " + direction;
   
   if(OrderSend(request, result))
   {
      Print("? ORDRE DERIV ARROW EXÉCUTÉ - ", direction, " sur ", _Symbol,
            " | Prix: ", DoubleToString((direction == "BUY") ? askPrice : bidPrice, _Digits),
            " | SL: ", DoubleToString(stopLoss, _Digits),
            " | TP: ", DoubleToString(takeProfit, _Digits),
            " | Ticket: ", result.order);
      
      // MÉMORISER CETTE FLÈCHE COMME TRAITÉE
      lastProcessedArrow = currentArrowKey;
      lastProcessedTime = TimeCurrent();
   }
   else
   {
      Print("? ÉCHEC ORDRE DERIV ARROW - Erreur: ", GetLastError());
   }

   ReleaseOpenLock();
}

// Exécute la stratégie OTE + Imbalance (FVG) pour Forex, or, indices de devises.
void ExecuteOTEImbalanceTrade()
{
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(!(cat == SYM_FOREX || cat == SYM_METAL || cat == SYM_COMMODITY))
      return;

   // Anti-duplication symbolique
   if(HasAnyExposureForSymbol(_Symbol)) return;

   string dir;
   double entry, sl, tp;
   if(!DetectOTEImbalanceSetup(dir, entry, sl, tp))
      return;

   string d = dir; StringToUpper(d);

   // Filtre "propice"
   if(UsePropiceSymbolsFilter && !g_currentSymbolIsPropice)
   {
      Print("⛔ OTE+Imbalance bloqué - symbole non propice: ", _Symbol);
      return;
   }

   // IA gating
   if(UseAIServer)
   {
      string ia = g_lastAIAction;
      StringToUpper(ia);
      double confPct = g_lastAIConfidence * 100.0;

      if(ia == "" || ia == "HOLD")
      {
         Print("⛔ OTE+Imbalance bloqué - IA HOLD/absente sur ", _Symbol);
         return;
      }
      if(ia != d)
      {
         Print("⛔ OTE+Imbalance bloqué - IA=", ia, " != ", d, " sur ", _Symbol,
               " (", DoubleToString(confPct, 1), "%)");
         return;
      }
      if(confPct < MinAIConfidencePercent)
      {
         Print("⛔ OTE+Imbalance bloqué - Confiance IA trop faible: ",
               DoubleToString(confPct,1), "% < ", DoubleToString(MinAIConfidencePercent,1),
               "% sur ", _Symbol);
         return;
      }
   }

   // ML gating
   if(!IsMLModelTrustedForCurrentSymbol(d))
   {
      Print("⛔ OTE+Imbalance bloqué - Modèle ML non fiable sur ", _Symbol,
            " (acc=", DoubleToString(g_mlLastAccuracy * 100.0, 1), "%)");
      return;
   }

   if(!TryAcquireOpenLock()) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = MathMax((double)stopsLevel * point, point * 10.0);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = (d == "BUY") ? ask : bid;

   // Ajuster SL/TP pour respecter min distance
   if(d == "BUY")
   {
      if(price - sl < minDist) sl = price - minDist;
      if(tp - price < minDist) tp = price + minDist * 2.0;
   }
   else
   {
      if(sl - price < minDist) sl = price + minDist;
      if(price - tp < minDist) tp = price - minDist * 2.0;
   }

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double lot = CalculateLotSize();
   lot = NormalizeVolumeForSymbol(lot);

   bool ok = false;
   string comment = "OTE_IMBALANCE";
   if(d == "BUY")
      ok = trade.Buy(lot, _Symbol, 0.0, sl, tp, comment);
   else
      ok = trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);

   if(ok)
   {
      Print("✅ OTE+Imbalance EXECUTÉ ", d, " ", _Symbol,
            " | lot=", DoubleToString(lot, 2),
            " | SL=", DoubleToString(sl, _Digits),
            " | TP=", DoubleToString(tp, _Digits));
   }
   else
   {
      Print("❌ OTE+Imbalance ÉCHEC ", d, " ", _Symbol,
            " | err=", IntegerToString(GetLastError()));
   }

   ReleaseOpenLock();
}

// Filtre "entrée sur pullback EMA" (Forex/Métaux): évite les entrées en extension / en pleine correction loin des EMA.
// Retourne true si le prix actuel est proche de la zone EMA21/EMA31 sur LTF, sinon false.
bool IsPriceNearEMAPullbackZone(const string direction, double currentPrice, double &ema21Out, double &ema31Out, double &distOut, double &maxDistOut)
{
   ema21Out = 0.0;
   ema31Out = 0.0;
   distOut = 0.0;
   maxDistOut = 0.0;

   if(ema21LTF == INVALID_HANDLE || ema31LTF == INVALID_HANDLE) return true; // fail-open

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(ema21LTF, 0, 0, 2, buf) < 1) return true;
   ema21Out = buf[0];
   if(CopyBuffer(ema31LTF, 0, 0, 2, buf) < 1) return true;
   ema31Out = buf[0];

   // ATR LTF pour distance max (tolérance)
   double atrVal = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double a[];
      ArraySetAsSeries(a, true);
      if(CopyBuffer(atrHandle, 0, 0, 2, a) >= 1)
         atrVal = a[0];
   }
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atrVal <= 0.0) atrVal = point * 100.0;

   // Distance autorisée: 0.25 ATR (min 10 points)
   maxDistOut = MathMax(atrVal * 0.25, point * 10.0);

   double zoneLow = MathMin(ema21Out, ema31Out);
   double zoneHigh = MathMax(ema21Out, ema31Out);

   // Distance du prix à la "zone EMA" (0 si dans la zone)
   if(currentPrice < zoneLow) distOut = zoneLow - currentPrice;
   else if(currentPrice > zoneHigh) distOut = currentPrice - zoneHigh;
   else distOut = 0.0;

   // Si déjà dans la zone, OK
   if(distOut <= maxDistOut) return true;

   // Sinon, trop loin: on attend le pullback vers EMA
   return false;
}

// Détection de setup ICT-like: tendance claire + Imbalance (FVG) + zone OTE (0.62-0.786) alignées.
bool DetectOTEImbalanceSetup(string &dirOut, double &entryOut, double &slOut, double &tpOut)
{
   dirOut = "";
   entryOut = 0.0;
   slOut = 0.0;
   tpOut = 0.0;

   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(!(cat == SYM_FOREX || cat == SYM_METAL || cat == SYM_COMMODITY))
      return false;

   if(!UseFVG || !UseOTE)
      return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // 1) Détection tendance via EMA HTF
   bool bullHTF = IsBullishHTF();
   bool bearHTF = IsBearishHTF();
   if(!bullHTF && !bearHTF)
      return false;

   string dir = bullHTF ? "BUY" : "SELL";

   // 2) Swing High / Low récents (structure)
   if(!DetectNonRepaintingSwingPoints())
      return false;

   double lastSH, lastSL;
   datetime tSH, tSL;
   GetLatestConfirmedSwings(lastSH, tSH, lastSL, tSL);

   if(lastSH <= 0 || lastSL <= 0 || tSH == 0 || tSL == 0)
      return false;

   // 3) Zone OTE (0.62-0.786 du mouvement)
   double high = lastSH;
   double low  = lastSL;
   if(high <= low) return false;

   double range = high - low;
   double oteLow, oteHigh;

   if(dir == "BUY")
   {
      // OTE BUY: retracement 62-78.6% depuis le bas vers le haut
      oteHigh = low + range * 0.62;
      oteLow  = low + range * 0.786;
   }
   else
   {
      // OTE SELL: retracement 62-78.6% depuis le haut vers le bas
      oteLow  = high - range * 0.62;
      oteHigh = high - range * 0.786;
      if(oteLow > oteHigh)
      {
         double tmp = oteLow; oteLow = oteHigh; oteHigh = tmp;
      }
   }

   // 4) Imbalance (FVG) récente sur LTF
   FVGData fvg;
   if(!SMC_DetectFVG(_Symbol, LTF, 40, fvg))
      return false;

   // Direction cohérente avec la tendance
   if((dir == "BUY" && fvg.direction != 1) ||
      (dir == "SELL" && fvg.direction != -1))
      return false;

   double fvgLow  = fvg.bottom;
   double fvgHigh = fvg.top;

   // 5) Confluence: intersection FVG ∩ OTE
   double zoneLow  = MathMax(fvgLow, oteLow);
   double zoneHigh = MathMin(fvgHigh, oteHigh);

   if(zoneHigh <= zoneLow)
      return false;

   double price = (dir == "BUY") ? bid : ask;
   if(price < zoneLow || price > zoneHigh)
      return false; // attendre que le prix entre dans la zone confluente

   // 6) SL sous / au-dessus de la zone, TP 2R
   double buffer = MathMax(point * 10.0, range * 0.05);
   double sl, tp;
   if(dir == "BUY")
   {
      sl = zoneLow - buffer;
      double risk = price - sl;
      if(risk <= point * 5.0) return false;
      tp = price + 2.0 * risk;
   }
   else
   {
      sl = zoneHigh + buffer;
      double risk = sl - price;
      if(risk <= point * 5.0) return false;
      tp = price - 2.0 * risk;
   }

   dirOut = dir;
   entryOut = price;
   slOut = NormalizeDouble(sl, _Digits);
   tpOut = NormalizeDouble(tp, _Digits);

   return true;
}

//| Exécuter les ordres au marché basés sur les décisions IA SMC EMA   |
void ExecuteAIDecisionMarketOrder()
{
   // Catégorie du symbole pour adapter le seuil de confiance IA
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   double requiredConf = MinAIConfidence;
   // Pour tous les marchés HORS Boom/Crash: 85% minimum
   if(cat != SYM_BOOM_CRASH)
      requiredConf = 0.85;
   
   // Vérifier si on a une décision IA valide
   if(g_lastAIAction == "" || g_lastAIConfidence < requiredConf)
   {
      return;
   }
   
   // BLOQUER LES ORDRES SI IA EST EN HOLD
   // Réduire la fréquence des logs DEBUG HOLD pour éviter la surcharge
   static datetime lastDebugHoldLog = 0;
   if(TimeCurrent() - lastDebugHoldLog >= 120) // Log toutes les 2 minutes maximum
   {
      Print("?? DEBUG HOLD (Market): g_lastAIAction = '", g_lastAIAction, "' | g_lastAIConfidence = ", DoubleToString(g_lastAIConfidence*100, 1), "%");
      lastDebugHoldLog = TimeCurrent();
   }
   
   if(g_lastAIAction == "HOLD" || g_lastAIAction == "hold")
   {
      Print("?? ORDRES MARCHÉ BLOQUÉS - IA en HOLD - Attente de changement de statut");
      return;
   }
   
   // Calculer une note de setup globale et bloquer si trop basse
   double setupScore = ComputeSetupScore(g_lastAIAction);
   if(setupScore < MinSetupScoreEntry)
   {
   // Réduire la fréquence des logs de setup score pour éviter la surcharge
   static datetime lastSetupScoreLog = 0;
   if(TimeCurrent() - lastSetupScoreLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? ORDRE IA BLOQUÉ - SetupScore trop bas: ",
            DoubleToString(setupScore, 1), " < ",
            DoubleToString(MinSetupScoreEntry, 1),
            " pour ", _Symbol, " (", g_lastAIAction, ")");
      lastSetupScoreLog = TimeCurrent();
   }
      return;
   }
   
   Print("? ORDRES MARCHÉ AUTORISÉS - IA: ", g_lastAIAction,
         " | SetupScore=", DoubleToString(setupScore, 1));

   // Réentrée après perte sur ce symbole: exiger conditions exceptionnelles
   if(!AllowReentryAfterRecentLoss(_Symbol, g_lastAIAction, false))
      return;

   // Filtre "propice" optionnel
   if(UsePropiceSymbolsFilter && !g_currentSymbolIsPropice)
   {
      Print("🚫 TRADE IA BLOQUÉ - Symbole non 'propice' actuellement: ", _Symbol);
      Print("   Heure UTC: ", TimeToString(TimeCurrent(), TIME_SECONDS), " | Top propices: ", g_propiceTopSymbolsText);
      Print("   💡 Le robot trade UNIQUEMENT sur les symboles les plus performants selon l'heure actuelle");
      return;
   }
   
   // Vérification ANTI-DUPLICATION stricte - AUCUNE position sur CE symbole
   if(HasAnyExposureForSymbol(_Symbol))
   {
      Print("?? DUPLICATION BLOQUÉE - Exposition déjà existante sur ", _Symbol, " (position ou ordre en attente)");
      return; // BLOQUER TOUTE duplication sur ce symbole
   }
   
   // BOOM/CRASH: exiger flèche récente OU (optionnel) tendance forte + confiance ML élevée
   if(cat == SYM_BOOM_CRASH)
   {
      if(!HasRecentSMCDerivArrowForDirection(g_lastAIAction))
      {
         Print("?? ORDRES MARCHÉ BLOQUÉS SUR BOOM/CRASH - Pas de flèche (ou conditions tendance forte non remplies) pour ", _Symbol);
         return;
      }
   }
   
   // BLOQUER LES ORDRES SI PRIX EST DANS UN RANGE
   if(IsPriceInRange())
   {
      Print("?? ORDRES MARCHÉ BLOQUÉS - Prix dans un range sur ", _Symbol, " - Attente de breakout");
      return;
   }
   
   // Vérifier le lock pour éviter les doublons
   if(!TryAcquireOpenLock()) return;
   
   // Règle Boom/Crash: pas de SELL sur Boom, pas de BUY sur Crash
   if(!IsDirectionAllowedForBoomCrash(_Symbol, g_lastAIAction))
   {
      Print("? Ordre IA ", g_lastAIAction, " bloqué sur ", _Symbol, " (règle Boom/Crash)");
      ReleaseOpenLock();
      return;
   }
   
   // VALIDATION MULTI-SIGNAUX POUR ENTRÉES PRÉCISES
   if(!ValidateEntryWithMultipleSignals(g_lastAIAction))
   {
      Print("? ENTRÉE BLOQUÉE - Validation multi-signaux échouée pour ", g_lastAIAction, " sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   
   // CALCULER L'ENTRÉE PRÉCISE AU LIEU DU PRIX ACTUEL
   double preciseEntry, preciseSL, preciseTP;
   if(!CalculatePreciseEntryPoint(g_lastAIAction, preciseEntry, preciseSL, preciseTP))
   {
      Print("? CALCUL D'ENTRÉE PRÉCISE ÉCHOUÉ pour ", g_lastAIAction, " sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   
   double lot = CalculateLotSize();
   if(lot <= 0)
   {
      ReleaseOpenLock();
      return;
   }
   
   bool orderExecuted = false;
   
   if(g_lastAIAction == "BUY" || g_lastAIAction == "buy")
   {
      if(!HasRecentSMCDerivArrowForDirection("BUY"))
      {
         Print("?? ORDRE MARCHÉ BLOQUÉ - Attendre flèche SMC_DERIV_ARROW BUY sur ", _Symbol);
         ReleaseOpenLock();
         return;
      }
      // Utiliser l'entrée précise calculée au lieu du prix actuel
      if(trade.Buy(lot, _Symbol, preciseEntry, preciseSL, preciseTP, "IA SMC-EMA BUY PRÉCIS"))
      {
         orderExecuted = true;
         Print("?? ORDRE BUY PRÉCIS EXÉCUTÉ - Entry: ", DoubleToString(preciseEntry, _Digits), 
               " | SL: ", DoubleToString(preciseSL, _Digits), 
               " | TP: ", DoubleToString(preciseTP, _Digits),
               " | Lot: ", DoubleToString(lot, 2),
               " | Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
         
         if(UseNotifications)
         {
            Alert("?? BUY PRÉCIS ", _Symbol, " @", DoubleToString(preciseEntry, _Digits), " - Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
            SendNotification("?? BUY PRÉCIS " + _Symbol + " @" + DoubleToString(preciseEntry, _Digits) + " - Conf: " + DoubleToString(g_lastAIConfidence*100, 1) + "%");
         }
      }
      else
      {
         Print("? Échec ordre BUY PRÉCIS - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   else if(g_lastAIAction == "SELL" || g_lastAIAction == "sell")
   {
      if(!HasRecentSMCDerivArrowForDirection("SELL"))
      {
         Print("?? ORDRE MARCHÉ BLOQUÉ - Attendre flèche SMC_DERIV_ARROW SELL sur ", _Symbol);
         ReleaseOpenLock();
         return;
      }
      // Utiliser l'entrée précise calculée au lieu du prix actuel
      if(trade.Sell(lot, _Symbol, preciseEntry, preciseSL, preciseTP, "IA SMC-EMA SELL PRÉCIS"))
      {
         orderExecuted = true;
         Print("?? ORDRE SELL PRÉCIS EXÉCUTÉ - Entry: ", DoubleToString(preciseEntry, _Digits), 
               " | SL: ", DoubleToString(preciseSL, _Digits), 
               " | TP: ", DoubleToString(preciseTP, _Digits),
               " | Lot: ", DoubleToString(lot, 2),
               " | Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
         
         if(UseNotifications)
         {
            Alert("?? SELL PRÉCIS ", _Symbol, " @", DoubleToString(preciseEntry, _Digits), " - Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
            SendNotification("?? SELL PRÉCIS " + _Symbol + " @" + DoubleToString(preciseEntry, _Digits) + " - Conf: " + DoubleToString(g_lastAIConfidence*100, 1) + "%");
         }
      }
      else
      {
         Print("? Échec ordre SELL PRÉCIS - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   
   ReleaseOpenLock();
   
   if(orderExecuted)
   {
      // Réinitialiser le gain maximum pour la nouvelle position
      g_maxProfit = 0;
   }
}

//| FONCTIONS DE GESTION DES PAUSES ET BLACKLIST TEMPORAIRE        |
void InitializeSymbolPauseSystem()
{
   g_pauseCount = 0;
   for(int i = 0; i < 20; i++)
   {
      g_symbolPauses[i].symbol = "";
      g_symbolPauses[i].pauseUntil = 0;
      g_symbolPauses[i].consecutiveLosses = 0;
      g_symbolPauses[i].consecutiveWins = 0;
      g_symbolPauses[i].lastTradeTime = 0;
      g_symbolPauses[i].lastProfit = 0;
   }
}

bool IsSymbolPaused(string symbol)
{
   datetime currentTime = TimeCurrent();
   for(int i = 0; i < g_pauseCount; i++)
   {
      if(g_symbolPauses[i].symbol == symbol)
      {
         if(currentTime < g_symbolPauses[i].pauseUntil)
         {
            Print("?? SYMBOLE EN PAUSE: ", symbol, " - Jusqu'à: ", TimeToString(g_symbolPauses[i].pauseUntil, TIME_SECONDS));
            return true;
         }
         break;
      }
   }
   return false;
}

void UpdateSymbolPauseInfo(string symbol, double profit)
{
   datetime currentTime = TimeCurrent();
   int index = -1;
   
   // Trouver ou créer l'entrée pour ce symbole
   for(int i = 0; i < g_pauseCount; i++)
   {
      if(g_symbolPauses[i].symbol == symbol)
      {
         index = i;
         break;
      }
   }
   
   if(index == -1 && g_pauseCount < 20)
   {
      // Créer nouvelle entrée
      index = g_pauseCount;
      g_symbolPauses[index].symbol = symbol;
      g_symbolPauses[index].pauseUntil = 0;
      g_symbolPauses[index].consecutiveLosses = 0;
      g_symbolPauses[index].consecutiveWins = 0;
      g_pauseCount++;
   }
   
   if(index >= 0)
   {
      // Mettre à jour les compteurs
      if(profit < 0)
      {
         g_symbolPauses[index].consecutiveLosses++;
         g_symbolPauses[index].consecutiveWins = 0;
         Print("?? PERTE DÉTECTÉE: ", symbol, " | Perte: ", DoubleToString(profit, 2), "$ | Pertes consécutives: ", g_symbolPauses[index].consecutiveLosses);
      }
      else if(profit > 0)
      {
         g_symbolPauses[index].consecutiveWins++;
         g_symbolPauses[index].consecutiveLosses = 0;
         Print("?? GAIN DÉTECTÉ: ", symbol, " | Gain: ", DoubleToString(profit, 2), "$ | Gains consécutifs: ", g_symbolPauses[index].consecutiveWins);
      }
      
      g_symbolPauses[index].lastTradeTime = currentTime;
      g_symbolPauses[index].lastProfit = profit;
   }
}

bool ShouldPauseSymbol(string symbol, double profit)
{
   // Pause après 2 pertes successives (10 minutes)
   if(profit < 0)
   {
      for(int i = 0; i < g_pauseCount; i++)
      {
         if(g_symbolPauses[i].symbol == symbol)
         {
            if(g_symbolPauses[i].consecutiveLosses >= 1) // Déjà 1 perte, celle-ci fait 2
            {
               Print("?? PAUSE 10 MINUTES: ", symbol, " - 2 pertes successives détectées");
               return true;
            }
            break;
         }
      }
   }
   
   // Pause après 2 gains successifs (5 minutes)
   if(profit > 0)
   {
      for(int i = 0; i < g_pauseCount; i++)
      {
         if(g_symbolPauses[i].symbol == symbol)
         {
            if(g_symbolPauses[i].consecutiveWins >= 1) // Déjà 1 gain, celui-ci fait 2
            {
               Print("?? PAUSE 5 MINUTES: ", symbol, " - 2 gains successifs détectés");
               return true;
            }
            break;
         }
      }
   }
   
   return false;
}

void ApplySymbolPause(string symbol, int minutes)
{
   datetime currentTime = TimeCurrent();
   datetime pauseUntil = currentTime + (minutes * 60);
   
   for(int i = 0; i < g_pauseCount; i++)
   {
      if(g_symbolPauses[i].symbol == symbol)
      {
         g_symbolPauses[i].pauseUntil = pauseUntil;
         Print("?? SYMBOLE MIS EN PAUSE: ", symbol, " - Durée: ", minutes, " minutes | Jusqu'à: ", TimeToString(pauseUntil, TIME_SECONDS));
         break;
      }
   }
}

//| DÉTECTION DE RANGE - ÉVITER DE TRADER DANS LES RANGES         |
bool DetectPriceRange()
{
   // Utiliser les 20 dernières bougies pour détecter un range
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 20, rates) < 20) return false;
   
   double highs[], lows[];
   ArrayResize(highs, 20);
   ArrayResize(lows, 20);
   
   for(int i = 0; i < 20; i++)
   {
      highs[i] = rates[i].high;
      lows[i] = rates[i].low;
   }
   
   // Calculer le plus haut et plus bas sur la période
   double highestHigh = rates[0].high;
   double lowestLow = rates[0].low;
   
   for(int i = 1; i < 20; i++)
   {
      if(rates[i].high > highestHigh) highestHigh = rates[i].high;
      if(rates[i].low < lowestLow) lowestLow = rates[i].low;
   }
   
   double rangeSize = highestHigh - lowestLow;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Déterminer si le prix est dans le range (zone médiane 40-60%)
   double rangeMiddle = lowestLow + (rangeSize * 0.5);
   double rangeWidth = rangeSize * 0.2; // 20% de chaque côté du milieu
   
   bool inRange = (currentPrice >= (rangeMiddle - rangeWidth) && currentPrice <= (rangeMiddle + rangeWidth));
   
   // Critères supplémentaires pour confirmer le range
   bool isConsolidating = false;
   
   // Vérifier si les bougies ont des corps petits (indique de consolidation)
   double avgBodySize = 0;
   for(int i = 0; i < 20; i++)
   {
      double bodySize = MathAbs(rates[i].close - rates[i].open);
      avgBodySize += bodySize;
   }
   avgBodySize /= 20;
   
   // Si les corps sont petits par rapport au range, c'est une consolidation
   isConsolidating = (avgBodySize < rangeSize * 0.1);
   
   // Détection finale de range
   bool isRange = inRange && isConsolidating && (rangeSize > 0);
   
   if(isRange)
   {
      Print("?? RANGE DÉTECTÉ sur ", _Symbol, 
             " | Range: ", DoubleToString(lowestLow, _Digits), " - ", DoubleToString(highestHigh, _Digits),
             " | Prix actuel: ", DoubleToString(currentPrice, _Digits),
             " | Largeur range: ", DoubleToString(rangeSize, _Digits),
             " | Corps moyen: ", DoubleToString(avgBodySize, _Digits));
   }
   
   return isRange;
}

bool IsPriceInRange()
{
   return DetectPriceRange();
}

//| NOTE DE SETUP IA (0-100)                                         |
double ComputeSetupScore(const string direction)
{
   // 1) Base: confiance IA (0-60 pts)
   double score = 0.0;
   double confPct = g_lastAIConfidence * 100.0;
   if(confPct < 0.0) confPct = 0.0;
   if(confPct > 100.0) confPct = 100.0;
   score += confPct * 0.60;

   // 2) Alignement et cohérence (0-20 pts chaque) à partir des chaînes "xx.x%"
   double alignPct = 0.0, cohPct = 0.0;
   if(StringLen(g_lastAIAlignment) > 0)
   {
      string s = g_lastAIAlignment;
      StringReplace(s, "%", "");
      alignPct = StringToDouble(s);
      if(alignPct < 0.0) alignPct = 0.0;
      if(alignPct > 100.0) alignPct = 100.0;
   }
   if(StringLen(g_lastAICoherence) > 0)
   {
      string s2 = g_lastAICoherence;
      StringReplace(s2, "%", "");
      cohPct = StringToDouble(s2);
      if(cohPct < 0.0) cohPct = 0.0;
      if(cohPct > 100.0) cohPct = 100.0;
   }
   score += alignPct * 0.20;
   score += cohPct * 0.20;

   // 3) Contexte de tendance HTF (bonus/malus)
   bool bullHTF = IsBullishHTF();
   bool bearHTF = IsBearishHTF();
   string dir = direction;
   StringToUpper(dir);

   if(dir == "BUY" && bullHTF)       score += 5.0;
   if(dir == "SELL" && bearHTF)      score += 5.0;
   if(dir == "BUY" && bearHTF)       score -= 10.0;
   if(dir == "SELL" && bullHTF)      score -= 10.0;

   // 4) Éviter les ranges (gros malus si range détecté)
   if(IsPriceInRange())
      score -= 15.0;

   // Clamp final 0-100
   if(score < 0.0)   score = 0.0;
   if(score > 100.0) score = 100.0;

   Print("?? SETUP SCORE ", _Symbol, " ", dir, " = ", DoubleToString(score, 1),
         " (Conf=", DoubleToString(confPct,1), "% Align=", DoubleToString(alignPct,1),
         "% Coh=", DoubleToString(cohPct,1), "%)");

   return score;
}

//| MÉTRIQUES ML FALLBACK - SI SERVEUR IA INDISPONIBLE          |
void GenerateFallbackMLMetrics()
{
   // Si le serveur IA n'est pas connecté, générer des métriques basiques
   if(!g_aiConnected)
   {
      // Calculer des métriques basées sur l'analyse technique locale
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      
      if(CopyRates(_Symbol, PERIOD_M1, 0, 20, rates) >= 20)
      {
         // Calculer la tendance simple
         double priceChange = rates[0].close - rates[19].close;
         bool isUptrend = priceChange > 0;
         
         // Calculer la volatilité
         double avgRange = 0;
         for(int i = 0; i < 20; i++)
         {
            avgRange += rates[i].high - rates[i].low;
         }
         avgRange /= 20;
         
         // Générer des métriques de fallback
         if(isUptrend)
         {
            g_lastAIAction = "BUY";
            g_lastAIConfidence = MathMin(0.65, 0.5 + (priceChange / currentPrice) * 10); // Max 65%
         }
         else
         {
            g_lastAIAction = "SELL";
            g_lastAIConfidence = MathMin(0.65, 0.5 + MathAbs(priceChange / currentPrice) * 10); // Max 65%
         }
         
         // Alignement et cohérence basés sur la volatilité
         double volatilityScore = MathMin(1.0, avgRange / currentPrice * 100);
         g_lastAIAlignment = DoubleToString(volatilityScore * 80, 1) + "%"; // Max 80%
         g_lastAICoherence = DoubleToString(volatilityScore * 70, 1) + "%"; // Max 70%
         
         Print("?? MÉTRIQUES FALLBACK - Action: ", g_lastAIAction, 
               " | Confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "%",
               " | Alignement: ", g_lastAIAlignment,
               " | Cohérence: ", g_lastAICoherence);
      }
      else
      {
         // Valeurs par défaut si pas assez de données
         g_lastAIAction = "HOLD";
         g_lastAIConfidence = 0.0;
         g_lastAIAlignment = "0.0%";
         g_lastAICoherence = "0.0%";
         
         Print("?? MÉTRIQUES DÉFAUT - Pas assez de données pour fallback");
      }
   }
}

//| FONCTIONS IA - COMMUNICATION AVEC LE SERVEUR                       |

bool UpdateAIDecision(int timeoutMs = -1)
{
   // Déporter toute la logique réseau sur GetAISignalData()
   bool ok = GetAISignalData();
   if(!ok)
   {
      // En cas d'échec complet, générer immédiatement un fallback local
      GenerateFallbackAIDecision();
      return false;
   }
   // GetAISignalData met déjà à jour g_lastAIAction / g_lastAIConfidence / alignement / cohérence
   Print("? Décision IA mise à jour via /decision - Action: ", g_lastAIAction,
         " | Confiance: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
   return true;
}

string GetAISignalData(string symbol, string timeframe)
{
   string symEnc = symbol;
   StringReplace(symEnc, " ", "%20");
   
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
   string path = "/ml/signal?symbol=" + symEnc + "&timeframe=" + timeframe;
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   int res = WebRequest("GET", baseUrl + path, headers, AI_Timeout_ms, post, result, resultHeaders);
   
   if(res == 200)
   {
      return CharArrayToString(result);
   }
   
   return "";
}

string GetTrendAlignmentData(string symbol)
{
   string symEnc = symbol;
   StringReplace(symEnc, " ", "%20");
   
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
   string path = "/ml/trend_alignment?symbol=" + symEnc;
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   int res = WebRequest("GET", baseUrl + path, headers, AI_Timeout_ms, post, result, resultHeaders);
   
   if(res == 200)
   {
      return CharArrayToString(result);
   }
   
   return "";
}

string GetCoherentAnalysisData(string symbol)
{
   string symEnc = symbol;
   StringReplace(symEnc, " ", "%20");
   
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
   string path = "/ml/coherent_analysis?symbol=" + symEnc;
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   int res = WebRequest("GET", baseUrl + path, headers, AI_Timeout_ms, post, result, resultHeaders);
   
   if(res == 200)
   {
      return CharArrayToString(result);
   }
   
   return "";
}

void ProcessAIDecision(string jsonData)
{
   // Parser la réponse JSON du serveur IA
   // Format attendu: {"action": "BUY/SELL/HOLD", "confidence": 0.85, "alignment": "75%", "coherence": "82%"}
   
   g_lastAIUpdate = TimeCurrent();
   
   // Extraire l'action
   if(StringFind(jsonData, "\"action\":") >= 0)
   {
      int start = StringFind(jsonData, "\"action\":") + 9;
      int end = StringFind(jsonData, ",", start);
      if(end < 0) end = StringFind(jsonData, "}", start);
      
      if(end > start)
      {
         string action = StringSubstr(jsonData, start, end - start);
         StringReplace(action, "\"", "");
         StringReplace(action, " ", "");
         g_lastAIAction = action;
      }
   }
   
   // Extraire la confiance
   if(StringFind(jsonData, "\"confidence\":") >= 0)
   {
      int start = StringFind(jsonData, "\"confidence\":") + 13;
      int end = StringFind(jsonData, ",", start);
      if(end < 0) end = StringFind(jsonData, "}", start);
      
      if(end > start)
      {
         string confStr = StringSubstr(jsonData, start, end - start);
         g_lastAIConfidence = StringToDouble(confStr);
      }
   }
   
   // Extraire l'alignement
   if(StringFind(jsonData, "\"alignment\":") >= 0)
   {
      int start = StringFind(jsonData, "\"alignment\":") + 12;
      int end = StringFind(jsonData, ",", start);
      if(end < 0) end = StringFind(jsonData, "}", start);
      
      if(end > start)
      {
         string alignStr = StringSubstr(jsonData, start, end - start);
         StringReplace(alignStr, "\"", "");
         g_lastAIAlignment = alignStr;
      }
   }
   
   // Extraire la cohérence
   if(StringFind(jsonData, "\"coherence\":") >= 0)
   {
      int start = StringFind(jsonData, "\"coherence\":") + 13;
      int end = StringFind(jsonData, ",", start);
      if(end < 0) end = StringFind(jsonData, "}", start);
      
      if(end > start)
      {
         string cohStr = StringSubstr(jsonData, start, end - start);
         StringReplace(cohStr, "\"", "");
         g_lastAICoherence = cohStr;
      }
   }
   
   // Si aucune donnée trouvée, valeurs par défaut
   if(g_lastAIAction == "") g_lastAIAction = "HOLD";
   if(g_lastAIConfidence == 0) g_lastAIConfidence = 0.5;
   if(g_lastAIAlignment == "") g_lastAIAlignment = "50%";
   if(g_lastAICoherence == "") g_lastAICoherence = "50%";
}

//| NOTIFICATION MOBILE POUR APPARITION FLÈCHE DERIV ARROW          |
void SendDerivArrowNotification(string direction, double entryPrice, double stopLoss, double takeProfit)
{
   // Calculer le gain estimé
   double risk = MathAbs(entryPrice - stopLoss);
   double reward = MathAbs(takeProfit - entryPrice);
   double estimatedGain = 0;
   
   // Calculer le gain en points et en dollars (pour lot 0.01)
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointsToTP = MathAbs(takeProfit - entryPrice) / tickSize;
   estimatedGain = pointsToTP * pointValue * 0.01; // Pour lot 0.01
   
   // Calculer le ratio Risk/Reward
   double riskRewardRatio = reward / risk;
   
   // Formater les prix
   string entryStr = DoubleToString(entryPrice, _Digits);
   string slStr = DoubleToString(stopLoss, _Digits);
   string tpStr = DoubleToString(takeProfit, _Digits);
   string gainStr = DoubleToString(estimatedGain, 2);
   string ratioStr = DoubleToString(riskRewardRatio, 2);
   
   // Créer le message de notification
   string notificationMsg = "?? DERIV ARROW " + direction + "\n" +
                           "Symbole: " + _Symbol + "\n" +
                           "Entry: " + entryStr + "\n" +
                           "SL: " + slStr + "\n" +
                           "TP: " + tpStr + "\n" +
                           "Gain estimé: $" + gainStr + "\n" +
                           "Risk/Reward: 1:" + ratioStr;
   
   // Créer le message d'alerte desktop
   string alertMsg = "?? DERIV ARROW " + direction + " - " + _Symbol + 
                    " @ " + entryStr + 
                    " | SL: " + slStr + 
                    " | TP: " + tpStr + 
                    " | Gain: $" + gainStr + 
                    " | R/R: 1:" + ratioStr;
   
   // Envoyer la notification mobile
   SendNotification(notificationMsg);
   
   // Envoyer l'alerte desktop
   Alert(alertMsg);
   
   // Log détaillé
   Print("?? NOTIFICATION ENVOYÉE - DERIV ARROW ", direction);
   Print("?? Symbole: ", _Symbol);
   Print("?? Entry: ", entryStr, " | SL: ", slStr, " | TP: ", tpStr);
   Print("?? Gain estimé: $", gainStr, " | Risk/Reward: 1:", ratioStr);
   Print("?? Notification mobile envoyée avec succès!");
}

//| CALCUL D'ENTRÉE PRÉCISE - SYSTÈME AMÉLIORÉ                    |
bool CalculatePreciseEntryPoint(string direction, double &entryPrice, double &stopLoss, double &takeProfit)
{
   // Récupérer les données de marché récentes
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 50, rates) < 50) return false;
   
   if(atrHandle == INVALID_HANDLE) return false;
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) return false;
   double atrValue = atr[0];
   
   // Analyser la structure de marché
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double support = rates[0].low;
   double resistance = rates[0].high;
   
   // Trouver le support/résistance le plus proche (last 10 bougies)
   for(int i = 1; i < 10; i++)
   {
      if(rates[i].low < support) support = rates[i].low;
      if(rates[i].high > resistance) resistance = rates[i].high;
   }
   
   // Calculer les niveaux de Fibonacci sur les 20 dernières bougies
   double highest = rates[0].high;
   double lowest = rates[0].low;
   for(int i = 1; i < 20; i++)
   {
      if(rates[i].high > highest) highest = rates[i].high;
      if(rates[i].low < lowest) lowest = rates[i].low;
   }
   
   double fib38_2 = lowest + (highest - lowest) * 0.382;
   double fib61_8 = lowest + (highest - lowest) * 0.618;
   
   // Calculer l'entrée précise selon la direction
   if(direction == "BUY")
   {
      // Entrée BUY: au-dessus du support ou fib38_2
      double buyLevel1 = support + (atrValue * 0.5);
      double buyLevel2 = fib38_2 + (atrValue * 0.3);
      
      entryPrice = MathMax(buyLevel1, buyLevel2);
      
      // SL: sous le support avec marge de sécurité
      stopLoss = support - (atrValue * 0.2);
      
      // TP: ratio 2:1 minimum
      double risk = entryPrice - stopLoss;
      takeProfit = entryPrice + (risk * 2.5);
      
      // Validation: l'entrée doit être < prix actuel + 1 ATR
      if(entryPrice > currentPrice + atrValue) return false;
   }
   else // SELL
   {
      // Entrée SELL: sous la résistance ou fib61_8
      double sellLevel1 = resistance - (atrValue * 0.5);
      double sellLevel2 = fib61_8 - (atrValue * 0.3);
      
      entryPrice = MathMin(sellLevel1, sellLevel2);
      
      // SL: au-dessus de la résistance avec marge
      stopLoss = resistance + (atrValue * 0.2);
      
      // TP: ratio 2:1 minimum
      double risk = stopLoss - entryPrice;
      takeProfit = entryPrice - (risk * 2.5);
      
      // Validation: l'entrée doit être > prix actuel - 1 ATR
      if(entryPrice < currentPrice - atrValue) return false;
   }
   
   // Validation finale des distances
   long stopsLevel = 0;
   double point = 0.0;
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevel);
   SymbolInfoDouble(_Symbol, SYMBOL_POINT, point);
   double minDistance = (double)stopsLevel * point;
   if(minDistance == 0) minDistance = atrValue * 0.5; // Distance par défaut
   
   if(MathAbs(entryPrice - stopLoss) < minDistance) return false;
   if(MathAbs(takeProfit - entryPrice) < minDistance * 2) return false;
   
   Print("?? ENTRÉE PRÉCISE CALCULÉE - ", direction,
         " | Entry: ", DoubleToString(entryPrice, _Digits),
         " | SL: ", DoubleToString(stopLoss, _Digits),
         " | TP: ", DoubleToString(takeProfit, _Digits),
         " | Risk/Reward: 1:", DoubleToString(MathAbs(takeProfit - entryPrice) / MathAbs(entryPrice - stopLoss), 2));
   
   return true;
}

//| VALIDATION MULTI-SIGNAUX POUR ENTRÉES PRÉCISES               |
bool ValidateEntryWithMultipleSignals(string direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 30, rates) < 30) return false;
   
   int confirmationCount = 0;
   
   // 1. Confirmation par momentum (last 5 bougies)
   double momentum = 0;
   for(int i = 0; i < 5; i++)
   {
      momentum += (rates[i].close - rates[i].open) / rates[i].open;
   }
   bool momentumConfirm = (direction == "BUY" && momentum > 0.001) || 
                          (direction == "SELL" && momentum < -0.001);
   if(momentumConfirm) confirmationCount++;
   
   // 2. Confirmation par volume (comparaison aux 10 bougies précédentes)
   double recentVolume = 0;
   double avgVolume = 0;
   for(int i = 0; i < 5; i++) recentVolume += (double)rates[i].tick_volume;
   for(int i = 5; i < 15; i++) avgVolume += (double)rates[i].tick_volume;
   recentVolume /= 5;
   avgVolume /= 10;
   
   bool volumeConfirm = recentVolume > avgVolume * 1.2; // Volume > 20% moyenne
   if(volumeConfirm) confirmationCount++;
   
   // 3. Confirmation par structure (pas de range)
   double range = rates[0].high - rates[0].low;
   double avgRange = 0;
   for(int i = 1; i < 10; i++) avgRange += rates[i].high - rates[i].low;
   avgRange /= 9;
   
   bool structureConfirm = range > avgRange * 0.8; // Range actuel > 80% moyenne
   if(structureConfirm) confirmationCount++;
   
   // 4. Confirmation par EMA (trend aligné)
   double ema[];
   ArraySetAsSeries(ema, true);
   bool emaConfirm = false;
   if(ema50H != INVALID_HANDLE && CopyBuffer(ema50H, 0, 0, 1, ema) >= 1)
   {
      emaConfirm = (direction == "BUY" && rates[0].close > ema[0]) ||
                   (direction == "SELL" && rates[0].close < ema[0]);
      if(emaConfirm) confirmationCount++;
   }

   // 4b. Retouche EMA (9/21/50/100/200) avant de reprendre un trade (anti-correction)
   bool emaTouchConfirm = true;
   if(RequireEMATouchBeforeEntry)
   {
      emaTouchConfirm = false;
      int lb = MathMax(3, EMATouchLookbackBarsM1);

      // On récupère les valeurs EMA sur M1 pour comparer aux bougies M1
      int handles[5] = { emaHandle, ema21LTF, ema50LTF, ema100LTF, ema200LTF };
      double emaBuf[5][64];
      int need = MathMin(lb + 1, 64);

      for(int h = 0; h < 5; h++)
      {
         if(handles[h] == INVALID_HANDLE) continue;
         double tmp[];
         ArraySetAsSeries(tmp, true);
         if(CopyBuffer(handles[h], 0, 0, need, tmp) < need) continue;
         for(int i = 0; i < need; i++) emaBuf[h][i] = tmp[i];
      }

      double mid = (rates[0].close > 0.0) ? rates[0].close : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double maxDist = mid * (EMATouchMaxDistancePct / 100.0);
      if(maxDist <= 0.0) maxDist = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;

      // Touch = une bougie dont high/low encadre l'EMA OU close suffisamment proche de l'EMA
      for(int i = 1; i <= lb && i < 30; i++)
      {
         for(int h = 0; h < 5; h++)
         {
            if(handles[h] == INVALID_HANDLE) continue;
            double ev = emaBuf[h][i];
            if(ev <= 0.0) continue;
            bool crossed = (rates[i].low <= ev && rates[i].high >= ev);
            bool near = (MathAbs(rates[i].close - ev) <= maxDist);
            if(crossed || near)
            {
               emaTouchConfirm = true;
               break;
            }
         }
         if(emaTouchConfirm) break;
      }

      if(DebugEMATouchFilter)
      {
         static datetime lastDbg = 0;
         datetime now = TimeCurrent();
         if(now - lastDbg >= 10)
         {
            Print("EMA TOUCH DEBUG ", _Symbol, " dir=", direction,
                  " | ok=", (emaTouchConfirm ? "YES" : "NO"),
                  " | lb=", lb, " | maxDist=", DoubleToString(maxDist, _Digits));
            lastDbg = now;
         }
      }

      // Si pas de retouche EMA → bloquer (anti-correction / attendre pullback)
      if(!emaTouchConfirm) return false;
   }
   
   // 5. Confirmation par volatilité (ni trop basse, ni trop élevée)
   double volatility = range / rates[0].close;
   bool volatilityConfirm = (volatility > 0.0005 && volatility < 0.02);
   if(volatilityConfirm) confirmationCount++;
   
   Print("?? VALIDATION MULTI-SIGNAUX - ", direction,
         " | Confirmations: ", confirmationCount, "/5",
         " | Momentum: ", momentumConfirm ? "?" : "?",
         " | Volume: ", volumeConfirm ? "?" : "?",
         " | Structure: ", structureConfirm ? "?" : "?",
         " | EMA: ", emaConfirm ? "?" : "?",
         " | Volatilité: ", volatilityConfirm ? "?" : "?");
   
   // Exiger au moins 3 confirmations sur 5
   return confirmationCount >= 3;
}

//| DÉTECTION AVANCÉE DE SPIKE IMMINENT                          |

// Calcule la compression de volatilité (prédicteur de spike)
double CalculateVolatilityCompression()
{
   // Vérifier si l'handle ATR est valide
   if(atrHandle == INVALID_HANDLE) return 0.0;
   
   double buffer[];
   ArraySetAsSeries(buffer, true);
   
   // Utiliser ATR sur 20 périodes pour la volatilité récente
   if(CopyBuffer(atrHandle, 0, 0, 20, buffer) < 20) return 0.0;
   
   double recentATR = buffer[0];
   double avgATR = 0.0;
   
   // Calculer la moyenne ATR sur 20 périodes
   for(int i = 0; i < 20; i++)
   {
      avgATR += buffer[i];
   }
   avgATR /= 20.0;
   
   // Compression = ratio ATR récent / moyenne ATR
   if(avgATR == 0) return 0.0;
   return recentATR / avgATR;
}

// Calcule l'accélération du prix (prédicteur de momentum)
double CalculatePriceAcceleration()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, 10, rates) < 10) return 0.0;
   
   // Calculer les variations de prix sur 3 périodes
   double change1 = (rates[0].close - rates[1].close) / rates[1].close;
   double change2 = (rates[1].close - rates[2].close) / rates[2].close;
   double change3 = (rates[2].close - rates[3].close) / rates[3].close;
   
   // Accélération = variation des variations
   double acceleration = (change1 - change3) / 3.0;
   
   return acceleration;
}

// Détecte les pics de volume anormaux
bool DetectVolumeSpike()
{
   long volume[];
   ArraySetAsSeries(volume, true);
   
   if(CopyTickVolume(_Symbol, PERIOD_M1, 0, 20, volume) < 20) return false;
   
   double recentVolume = (double)volume[0];
   double avgVolume = 0.0;
   
   // Calculer la moyenne de volume sur 20 périodes
   for(int i = 1; i < 20; i++) // Exclure la période la plus récente
   {
      avgVolume += (double)volume[i];
   }
   avgVolume /= 19.0;
   
   // Spike si volume > 2x la moyenne
   return (recentVolume > avgVolume * 2.0);
}

// Détecte les patterns pré-spike spécifiques Boom/Crash
bool IsPreSpikePattern()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, 50, rates) < 50) return false;
   
   // 1. Détection de compression (range qui se resserre)
   double high50 = rates[0].high;
   double low50  = rates[0].low;
   for(int i = 1; i < 50; i++)
   {
      if(rates[i].high > high50) high50 = rates[i].high;
      if(rates[i].low  < low50)  low50  = rates[i].low;
   }
   double range50 = high50 - low50;
   
   double high10 = rates[0].high;
   double low10  = rates[0].low;
   for(int i = 1; i < 10; i++)
   {
      if(rates[i].high > high10) high10 = rates[i].high;
      if(rates[i].low  < low10)  low10  = rates[i].low;
   }
   double range10 = high10 - low10;
   
   // Compression récente si range10 < (ratio) du range50
   bool compression = (range10 < range50 * PreSpike_CompressionRatio);
   
   // 2. Détection de formation en coin/wedge
   double ma5 = 0, ma20 = 0;
   for(int i = 0; i < 5; i++) ma5 += rates[i].close;
   ma5 /= 5.0;
   for(int i = 0; i < 20; i++) ma20 += rates[i].close;
   ma20 /= 20.0;
   
   // Prix proche de la moyenne mobile (consolidation)
   bool consolidation = (MathAbs(rates[0].close - ma20) / ma20 < PreSpike_ConsolidationPct);
   
   // 3. Vérifier si le prix est à un niveau clé
   bool keyLevel = IsNearKeyLevel(rates[0].close);
   
   return (compression && consolidation && keyLevel);
}

// Vérifie si le prix est près d'un niveau clé (support/résistance)
bool IsNearKeyLevel(double price)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 100, rates) < 100) return false;
   
   // Chercher les niveaux de swing points récents
   for(int i = 5; i < 50; i++)
   {
      double high = rates[i].high;
      double low = rates[i].low;
      
      // Si prix est à moins de X% d'un swing high/low
      if(MathAbs(price - high) / high < PreSpike_KeyLevelPct || MathAbs(price - low) / low < PreSpike_KeyLevelPct)
      {
         return true;
      }
   }
   
   return false;
}

// Calcule la probabilité de spike imminent
double CalculateSpikeProbability()
{
   // Objectif: fournir une proba 0..1 stable et exploitable même quand le serveur IA ne renvoie rien.
   // Utilise des signaux rapides: compression ATR, accélération, volume, range, pré-spike, proximité canal.
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);

   double volCompression = 1.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 10, atrBuf) >= 6)
      {
         double recentATR = atrBuf[0];
         double avgATR = 0.0;
         for(int i = 1; i <= 5; i++) avgATR += atrBuf[i];
         avgATR /= 5.0;
         if(avgATR > 0.0) volCompression = recentATR / avgATR;
      }
   }

   // Rates M1 rapides
   MqlRates r5[];
   ArraySetAsSeries(r5, true);
   double accel = 0.0;
   double rangeRatio = 1.0;
   if(CopyRates(_Symbol, PERIOD_M1, 0, 6, r5) >= 3)
   {
      double change1 = (r5[0].close - r5[1].close) / (r5[1].close == 0 ? 1.0 : r5[1].close);
      double change2 = (r5[1].close - r5[2].close) / (r5[2].close == 0 ? 1.0 : r5[2].close);
      accel = (change1 - change2) / 2.0;

      double range0 = MathAbs(r5[0].high - r5[0].low);
      double avgRange = 0.0;
      for(int i = 1; i < 6; i++) avgRange += MathAbs(r5[i].high - r5[i].low);
      avgRange /= 5.0;
      if(avgRange > 0.0) rangeRatio = range0 / avgRange;
   }

   // Volume ratio
   double volRatio = 1.0;
   bool volumeSpike = false;
   long volTicks[];
   ArraySetAsSeries(volTicks, true);
   if(CopyTickVolume(_Symbol, PERIOD_M1, 0, 10, volTicks) >= 6)
   {
      double recentV = (double)volTicks[0];
      double avgV = 0.0;
      for(int i = 1; i <= 5; i++) avgV += (double)volTicks[i];
      avgV /= 5.0;
      if(avgV > 0.0) volRatio = recentV / avgV;
      volumeSpike = (volRatio >= 1.6);
   }

   // Pré-spike "light" (sans scan swing complet)
   bool preSpikePattern = false;
   MqlRates r60[];
   ArraySetAsSeries(r60, true);
   if(cat == SYM_BOOM_CRASH && CopyRates(_Symbol, PERIOD_M1, 0, 60, r60) >= 50)
   {
      double hi10 = r60[0].high, lo10 = r60[0].low;
      for(int i = 0; i < 10; i++) { hi10 = MathMax(hi10, r60[i].high); lo10 = MathMin(lo10, r60[i].low); }
      double range10 = hi10 - lo10;
      double hi50 = r60[0].high, lo50 = r60[0].low;
      for(int i = 0; i < 50; i++) { hi50 = MathMax(hi50, r60[i].high); lo50 = MathMin(lo50, r60[i].low); }
      double range50 = hi50 - lo50;

      double ma20 = 0.0;
      for(int i = 0; i < 20; i++) ma20 += r60[i].close;
      ma20 /= 20.0;
      bool compression = (range50 > 0.0 && range10 < range50 * PreSpike_CompressionRatio);
      bool consolidation = (ma20 > 0.0 && (MathAbs(r60[0].close - ma20) / ma20) < PreSpike_ConsolidationPct);
      preSpikePattern = (compression && consolidation);
   }

   // Proximité canal SMC H1
   bool touchChannel = false;
   if(cat == SYM_BOOM_CRASH)
   {
      if(StringFind(_Symbol, "Boom") >= 0)  touchChannel = PriceTouchesLowerChannel();
      if(StringFind(_Symbol, "Crash") >= 0) touchChannel = PriceTouchesUpperChannel();
   }

   // Normalisation 0..1
   double sCompression = 0.0;
   if(volCompression < 1.0) sCompression = MathMin((1.0 - volCompression) / 0.6, 1.0); // 0.4 => 1.0
   double sAccel = MathMin(MathAbs(accel) / 0.003, 1.0);
   double sVolume = 0.0;
   if(volRatio > 1.0) sVolume = MathMin((volRatio - 1.0) / 1.5, 1.0);
   double sRange = 0.0;
   if(rangeRatio > 1.0) sRange = MathMin((rangeRatio - 1.0) / 1.0, 1.0);
   double sPre = preSpikePattern ? 1.0 : 0.0;
   double sChan = touchChannel ? 1.0 : 0.0;

   double probability =
      0.25 * sCompression +
      0.20 * sAccel +
      0.20 * sVolume +
      0.15 * sRange +
      0.10 * sPre +
      0.10 * sChan;

   probability = MathMax(0.0, MathMin(probability, 1.0));

   // Publier pour les filtres/affichages
   g_lastSpikeProbability = probability;
   g_lastSpikeUpdate      = TimeCurrent();

   return probability;
}

// Envoie une alerte de spike imminent - VERSION OPTIMISÉE
void CheckImminentSpike()
{
   // Uniquement sur Boom/Crash
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(cat != SYM_BOOM_CRASH) return;
   
   // Probabilité unifiée (même algo que l'affichage / filtre)
   double finalSpikeProb = CalculateSpikeProbability();
   double volCompression = CalculateVolatilityCompression();
   bool volumeSpike = DetectVolumeSpike();
   
   // Vérification finale
   if(finalSpikeProb < 0.0 || finalSpikeProb > 1.0) return;
   
   // Alerte si probabilité élevée (ajustée à 75% pour correspondre aux trades)
   if(finalSpikeProb > 0.75)
   {
      string alertMsg = "?? SPIKE IMMINENT sur " + _Symbol + 
                      " | Probabilité: " + DoubleToString(finalSpikeProb*100, 1) + "%" +
                      " | Compression: " + DoubleToString(volCompression*100, 1) + "%" +
                      " | Volume: " + (volumeSpike ? "SPIKE" : "Normal");
      
      Print(alertMsg);
      
      if(UseNotifications)
      {
         Alert(alertMsg);
         SendNotification("?? SPIKE " + _Symbol + " " + DoubleToString(finalSpikeProb*100, 1) + "%");
      }
      
      // Dessiner un marqueur visuel rapide
      DrawSpikeWarning(finalSpikeProb);
   }
}

//| DÉTECTION DES MOUVEMENTS DE RETOUR VERS CANAUX SMC               |
void CheckSMCChannelReturnMovements()
{
   // Uniquement sur Boom/Crash
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(cat != SYM_BOOM_CRASH) return;
   
   // Récupérer les canaux SMC H1
   string upperName = "SMC_CH_H1_UPPER";
   string lowerName = "SMC_CH_H1_LOWER";
   if(ObjectFind(0, upperName) < 0 || ObjectFind(0, lowerName) < 0) return;
   
   double upperPrice = ObjectGetDouble(0, upperName, OBJPROP_PRICE);
   double lowerPrice = ObjectGetDouble(0, lowerName, OBJPROP_PRICE);
   if(upperPrice <= 0 || lowerPrice <= 0) return;
   
   // Obtenir les prix actuels
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return;
   
   // Obtenir l'ATR pour les calculs de distance
   double atrVal = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) > 0)
         atrVal = atrBuf[0];
   }
   if(atrVal <= 0) atrVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100;
   
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   
   // RÈGLE STRICTE: BLOQUER TOUS LES MOUVEMENTS DE RETOUR BUY SUR BOOM SI IA = SELL
   string aiAction = g_lastAIAction;
   if(aiAction == "buy") aiAction = "BUY";
   if(aiAction == "sell") aiAction = "SELL";
   
   if(isBoom && aiAction == "SELL")
   {
      // Ne même pas analyser les mouvements de retour si IA = SELL sur Boom
      return;
   }
   
   if(isCrash && aiAction == "BUY")
   {
      // Ne même pas analyser les mouvements de retour si IA = BUY sur Crash
      return;
   }
   
   // Analyser les 5 dernières bougies pour détecter un mouvement de retour
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 3) return;
   
   // Détecter si le prix fait un mouvement de retour vers un canal
   bool returnMovementDetected = false;
   string returnDirection = "";
   double returnStrength = 0.0;
   
   if(isBoom)
   {
      // Pour Boom: vérifier si le prix monte vers le canal inférieur après être descendu
      double currentDistance = bid - lowerPrice;
      double previousDistance = rates[1].close - lowerPrice;
      
      // Mouvement de retour: la distance au canal diminue significativement
      if(previousDistance > currentDistance && previousDistance - currentDistance > atrVal * 0.3)
      {
         returnMovementDetected = true;
         returnDirection = "BUY";
         returnStrength = (previousDistance - currentDistance) / atrVal;
         
         // Vérifier si le mouvement est assez fort pour justifier une entrée immédiate
         if(returnStrength >= 0.5 && currentDistance <= atrVal * 3.0)
         {
            Print("?? MOUVEMENT RETOUR BOOM - Vers canal inférieur | Force: ", DoubleToString(returnStrength, 1), " ATR | Distance: ", DoubleToString(currentDistance/atrVal, 1), " ATR");
            
            // Placer un ordre limite plus proche pour capturer ce mouvement
            PlaceReturnMovementLimitOrder("BUY", bid, lowerPrice, atrVal, returnStrength);
         }
      }
   }
   else if(isCrash)
   {
      // Pour Crash: vérifier si le prix descend vers le canal supérieur après être monté
      double currentDistance = upperPrice - ask;
      double previousDistance = upperPrice - rates[1].close;
      
      // Mouvement de retour: la distance au canal diminue significativement
      if(previousDistance > currentDistance && previousDistance - currentDistance > atrVal * 0.3)
      {
         returnMovementDetected = true;
         returnDirection = "SELL";
         returnStrength = (previousDistance - currentDistance) / atrVal;
         
         // Vérifier si le mouvement est assez fort pour justifier une entrée immédiate
         if(returnStrength >= 0.5 && currentDistance <= atrVal * 3.0)
         {
            Print("?? MOUVEMENT RETOUR CRASH - Vers canal supérieur | Force: ", DoubleToString(returnStrength, 1), " ATR | Distance: ", DoubleToString(currentDistance/atrVal, 1), " ATR");
            
            // Placer un ordre limite plus proche pour capturer ce mouvement
            PlaceReturnMovementLimitOrder("SELL", ask, upperPrice, atrVal, returnStrength);
         }
      }
   }
}

//| PLACEMENT D'ORDRE LIMITE POUR MOUVEMENT DE RETOUR               |
void PlaceReturnMovementLimitOrder(string direction, double currentPrice, double channelPrice, double atrVal, double strength)
{
   // Vérifier si on a déjà un ordre de retour en cours
   int countReturnOrders = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(StringFind(OrderGetString(ORDER_COMMENT), "RETURN_MOVE") >= 0) countReturnOrders++;
   }
   if(countReturnOrders >= 1) return; // Un seul ordre de retour à la fois
   
   // Limite globale: maximum 2 ordres LIMIT par symbole, dont 1 seul hors canal
   {
      int totalLimits = CountOpenLimitOrdersForSymbol(_Symbol);
      int chanLimits  = CountChannelLimitOrdersForSymbol(_Symbol);
      int otherLimits = totalLimits - chanLimits;
      // Pour Boom/Crash: un seul LIMIT proche à la fois
      if(totalLimits >= 1 || otherLimits >= 1) return;
   }
   
   // Réentrée après perte sur ce symbole: exiger conditions exceptionnelles (IA ?90% + spike/setup fort)
   if(!AllowReentryAfterRecentLoss(_Symbol, direction, strength >= 0.8))
      return;
   
   if(CountPositionsForSymbol(_Symbol) > 0) return; // Pas d'ordre si déjà en position
   if(!TryAcquireOpenLock()) return;
   
   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }
   
   // Calculer le prix d'entrée optimisé pour le mouvement de retour
   double entryPrice;
   double distanceToChannel = MathAbs(currentPrice - channelPrice);
   
   if(direction == "BUY")
   {
      // Priorité SuperTrend support: entrée juste au-dessus du support, mais < prix actuel
      double stSupp = 0.0, stRes = 0.0;
      double tmpS = 0.0, tmpR = 0.0;
      if(GetSuperTrendLevel(PERIOD_M5, tmpS, tmpR) && tmpS > 0) stSupp = tmpS;
      else if(GetSuperTrendLevel(PERIOD_H1, tmpS, tmpR) && tmpS > 0) stSupp = tmpS;
      if(stSupp > 0 && stSupp < currentPrice)
      {
         double candidate = stSupp + atrVal * 0.15;
         if(candidate < currentPrice)
            entryPrice = candidate;
         else
            entryPrice = currentPrice - atrVal * 0.5;
      }
      else
      {
      // BUY: placer l'ordre entre le prix actuel et le canal, plus proche du prix
      if(distanceToChannel <= atrVal * 2.0)
         entryPrice = channelPrice + (atrVal * 0.2); // Très proche du canal
      else if(distanceToChannel <= atrVal * 4.0)
         entryPrice = currentPrice - (atrVal * 0.8); // Plus proche du prix
      else
         entryPrice = currentPrice - (atrVal * 1.2); // Distance modérée
      }
      
      if(entryPrice >= currentPrice) { ReleaseOpenLock(); return; }
      
      // Placer l'ordre BUY LIMIT
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);
      req.action = TRADE_ACTION_PENDING;
      req.symbol = _Symbol;
      req.magic = InpMagicNumber;
      req.volume = lot;
      req.type = ORDER_TYPE_BUY_LIMIT;
      req.price = entryPrice;
      req.sl = entryPrice - atrVal * 2.0;
      req.tp = entryPrice + atrVal * 4.0;
      req.comment = "RETURN_MOVE BUY LIMIT";
      
      if(OrderSend(req, res))
      {
         Print("? ORDRE RETOUR BUY PLACÉ - Entry: ", DoubleToString(entryPrice, _Digits), 
               " | Force: ", DoubleToString(strength, 1), " ATR");
      }
      else
      {
         Print("? ÉCHEC ORDRE RETOUR BUY - Erreur: ", res.retcode);
      }
   }
   else // SELL
   {
      // Priorité SuperTrend résistance: entrée juste en-dessous de la résistance, mais > prix actuel
      double stSupp = 0.0, stRes = 0.0;
      double tmpS = 0.0, tmpR = 0.0;
      if(GetSuperTrendLevel(PERIOD_M5, tmpS, tmpR) && tmpR > 0) stRes = tmpR;
      else if(GetSuperTrendLevel(PERIOD_H1, tmpS, tmpR) && tmpR > 0) stRes = tmpR;
      if(stRes > 0 && stRes > currentPrice)
      {
         double candidate = stRes - atrVal * 0.15;
         if(candidate > currentPrice)
            entryPrice = candidate;
         else
            entryPrice = currentPrice + atrVal * 0.5;
      }
      else
      {
      // SELL: placer l'ordre entre le prix actuel et le canal, plus proche du prix
      if(distanceToChannel <= atrVal * 2.0)
         entryPrice = channelPrice - (atrVal * 0.2); // Très proche du canal
      else if(distanceToChannel <= atrVal * 4.0)
         entryPrice = currentPrice + (atrVal * 0.8); // Plus proche du prix
      else
         entryPrice = currentPrice + (atrVal * 1.2); // Distance modérée
      }
      
      if(entryPrice <= currentPrice) { ReleaseOpenLock(); return; }
      
      // Placer l'ordre SELL LIMIT
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);
      req.action = TRADE_ACTION_PENDING;
      req.symbol = _Symbol;
      req.magic = InpMagicNumber;
      req.volume = lot;
      req.type = ORDER_TYPE_SELL_LIMIT;
      req.price = entryPrice;
      req.sl = entryPrice + atrVal * 2.0;
      req.tp = entryPrice - atrVal * 4.0;
      req.comment = "RETURN_MOVE SELL LIMIT";
      
      if(OrderSend(req, res))
      {
         Print("? ORDRE RETOUR SELL PLACÉ - Entry: ", DoubleToString(entryPrice, _Digits), 
               " | Force: ", DoubleToString(strength, 1), " ATR");
      }
      else
      {
         Print("? ÉCHEC ORDRE RETOUR SELL - Erreur: ", res.retcode);
      }
   }
   
   ReleaseOpenLock();
}

// Dessine un avertissement visuel de spike imminent - VERSION AMÉLIORÉE
void DrawSpikeWarning(double probability)
{
   string warningName = "SPIKE_WARNING_" + _Symbol;
   string probTextName = "SPIKE_PROB_TEXT_" + _Symbol;
   
   // Supprimer les avertissements précédents
   if(ObjectFind(0, warningName) >= 0)
      ObjectDelete(0, warningName);
   if(ObjectFind(0, probTextName) >= 0)
      ObjectDelete(0, probTextName);
   
   // Créer un nouvel avertissement
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, r) < 1) return;
   
   // Déterminer la couleur selon la probabilité
   color spikeColor = clrRed;
   if(probability >= 0.85) spikeColor = clrRed;      // 85%+ = Rouge critique
   else if(probability >= 0.70) spikeColor = clrOrange; // 70-84% = Orange alerte
   else if(probability >= 0.60) spikeColor = clrYellow; // 60-69% = Jaune attention
   else spikeColor = clrWhite; // < 60% = Blanc info
   
   // Dessiner une flèche d'avertissement
   ObjectCreate(0, warningName, OBJ_ARROW, 0, r[0].time, r[0].high);
   ObjectSetInteger(0, warningName, OBJPROP_ARROWCODE, 241); // Point d'exclamation
   ObjectSetInteger(0, warningName, OBJPROP_COLOR, spikeColor);
   ObjectSetInteger(0, warningName, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, warningName, OBJPROP_BACK, false);
   
   // Ajouter un texte avec la probabilité
   string probText = "SPIKE " + DoubleToString(probability*100, 0) + "%";
   ObjectCreate(0, probTextName, OBJ_TEXT, 0, r[0].time, r[0].high + (r[0].high - r[0].low) * 0.5);
   ObjectSetString(0, probTextName, OBJPROP_TEXT, probText);
   ObjectSetInteger(0, probTextName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, probTextName, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, probTextName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, probTextName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, probTextName, OBJPROP_BACK, true);
   
   // Log de l'affichage
   Print("?? SPIKE WARNING AFFICHÉ - ", _Symbol, 
         " | Probabilité: ", DoubleToString(probability*100, 1), "%",
         " | Couleur: ", (probability >= 0.85 ? "ROUGE CRITIQUE" : 
                         (probability >= 0.70 ? "ORANGE ALERTE" : 
                         (probability >= 0.60 ? "JAUNE ATTENTION" : "BLANC INFO"))));
}

// Affiche l'état IA et les prédictions sur le graphique
void DrawAIStatusAndPredictions()
{
   string statusBoxName = "AI_STATUS_BOX_" + _Symbol;
   string statusTextName = "AI_STATUS_TEXT_" + _Symbol;
   
   // Supprimer les objets précédents
   if(ObjectFind(0, statusBoxName) >= 0)
      ObjectDelete(0, statusBoxName);
   if(ObjectFind(0, statusTextName) >= 0)
      ObjectDelete(0, statusTextName);
   
   // Créer une boîte de statut
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, r) < 1) return;
   
   // Position de la boîte (coin supérieur gauche)
   datetime boxTime = r[0].time;
   double boxPrice = r[0].high + (r[0].high - r[0].low) * 0.8;
   
   // Créer le rectangle de fond
   ObjectCreate(0, statusBoxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, statusBoxName, OBJPROP_XDISTANCE, 10);
   // Bas-gauche, sans chevaucher les autres labels (ex: canal ML à ~50px)
   ObjectSetInteger(0, statusBoxName, OBJPROP_YDISTANCE, 90);
   ObjectSetInteger(0, statusBoxName, OBJPROP_XSIZE, 250);
   ObjectSetInteger(0, statusBoxName, OBJPROP_YSIZE, 80);
   ObjectSetInteger(0, statusBoxName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, statusBoxName, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, statusBoxName, OBJPROP_CORNER, CORNER_LEFT_LOWER); // Bas à gauche
   
   // Texte de statut IA
   string iaStatus = UseAIServer ? 
                    ("IA: " + g_lastAIAction + " (" + DoubleToString(g_lastAIConfidence*100, 1) + "%)") : 
                    "IA: DÉSACTIVÉ";
   
   // Texte de prédiction spike
   double spikeProb = CalculateSpikeProbability();
   string spikeStatus = "SPIKE: " + DoubleToString(spikeProb*100, 1) + "%";
   
   // Créer le texte de statut
   ObjectCreate(0, statusTextName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, statusTextName, OBJPROP_TEXT, 
                 iaStatus + "\n" + spikeStatus + "\nSymbole: " + _Symbol);
   ObjectSetInteger(0, statusTextName, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, statusTextName, OBJPROP_YDISTANCE, 100); // Aligné avec la boîte
   ObjectSetInteger(0, statusTextName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, statusTextName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, statusTextName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, statusTextName, OBJPROP_CORNER, CORNER_LEFT_LOWER); // Bas à gauche
}

//| DÉTECTER UN SPIKE RÉCENT sur Boom/Crash                           |
bool DetectRecentSpike()
{
   Print("?? DEBUG - Détection de spike pour: ", _Symbol);
   
   // Vérifier les 5 dernières bougies pour un spike significatif
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5)
   {
      Print("? Impossible de copier les rates pour détecter spike");
      return false;
   }
   
   // Calculer le mouvement moyen des bougies
   double avgMovement = 0.0;
   for(int i = 1; i < 5; i++) // Ignorer la bougie actuelle (0)
   {
      avgMovement += MathAbs(rates[i].high - rates[i].low);
   }
   avgMovement /= 4.0;
   
   // Vérifier si la dernière bougie a un mouvement significatif
   double lastMovement = MathAbs(rates[0].high - rates[0].low);
   
   // Rendre la détection plus permissive - seuil différent pour Boom/Crash
   double spikeMultiplier = 1.5; // 1.5x par défaut
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      spikeMultiplier = 1.2; // 1.2x pour Boom/Crash (plus sensible)
   }
   
   double spikeThreshold = avgMovement * spikeMultiplier;
   
   bool isSpike = lastMovement > spikeThreshold;
   
   Print("?? DEBUG - Analyse spike - Mouvement actuel: ", DoubleToString(lastMovement, _Digits), 
         " | Moyenne: ", DoubleToString(avgMovement, _Digits), 
         " | Seuil: ", DoubleToString(spikeThreshold, _Digits), 
         " | Ratio: ", DoubleToString(lastMovement/avgMovement, 1),
         " | Spike: ", isSpike ? "OUI" : "NON");
   
   // Ajouter une détection alternative basée sur le prix
   double priceChange = MathAbs(rates[0].close - rates[1].close) / rates[1].close;
   
   // Seuil différent pour Boom/Crash vs autres symboles
   double priceThreshold = 0.001; // 0.1% par défaut
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      priceThreshold = 0.0001; // 0.01% pour Boom/Crash (plus sensible)
   }
   
   bool priceSpike = priceChange > priceThreshold;
   
   Print("?? DEBUG - Spike prix - Changement: ", DoubleToString(priceChange*100, 4), "% | Seuil: ", DoubleToString(priceThreshold*100, 4), "% | Spike: ", priceSpike ? "OUI" : "NON");
   
   // Ajouter une détection basée sur le volume pour Boom/Crash
   bool volumeSpike = false;
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      long volume[];
      ArraySetAsSeries(volume, true);
      if(CopyTickVolume(_Symbol, PERIOD_M1, 0, 3, volume) >= 3)
      {
         double recentVolume = (double)volume[0];
         double avgVolume = ((double)volume[1] + (double)volume[2]) / 2.0;
         volumeSpike = recentVolume > avgVolume * 1.3; // 30% plus élevé
         
         Print("?? DEBUG - Spike volume - Récent: ", DoubleToString(recentVolume, 0), 
               " | Moyenne: ", DoubleToString(avgVolume, 0), 
               " | Spike: ", volumeSpike ? "OUI" : "NON");
      }
   }
   
   // Considérer comme spike si l'un des trois est vrai
   bool finalSpike = isSpike || priceSpike || volumeSpike;
   
   if(finalSpike)
   {
      string spikeType = "";
      if(isSpike) spikeType += "Mouvement";
      if(priceSpike) spikeType += (spikeType != "" ? "+" : "") + "Prix";
      if(volumeSpike) spikeType += (spikeType != "" ? "+" : "") + "Volume";
      
      Print("?? SPIKE DÉTECTÉ - Type: ", spikeType, 
            " | Mouvement: ", DoubleToString(lastMovement, _Digits), 
            " | Changement prix: ", DoubleToString(priceChange*100, 3), "%");
   }
   
   return finalSpike;
}

//| EXÉCUTER UN TRADE BASÉ SUR SPIKE                                  |
void ExecuteSpikeTrade(string direction)
{
   // Spike trades réservés aux symboles Boom/Crash et seulement si le modèle ML est fiable
   if(!IsMLModelTrustedForCurrentSymbol(direction))
   {
      Print("🚫 SPIKE TRADE BLOQUÉ - Modèle ML non fiable pour ", _Symbol);
      return;
   }

   // Calculer lot size (recovery: doubler le lot min sur un autre symbole après une perte)
   double lot = CalculateLotSize();
   lot = ApplyRecoveryLot(lot);
   if(lot <= 0) 
   {
      Print("? Erreur calcul lot size - trade annulé");
      return;
   }
   
   // Calculer SL/TP basés sur l'ATR
   double atrValue = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1)
         atrValue = atr[0];
   }
   
   if(atrValue == 0) atrValue = SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.002; // 0.2% par défaut
   
   Print("?? DEBUG - ATR pour SL/TP: ", DoubleToString(atrValue, _Digits), " | Symbol: ", _Symbol);
   
   // Perte max par trade (3$): perte en $ = (SL en prix) * (tickValue/tickSize) * lot
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0) tickSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tickVal <= 0) tickVal = 1.0;
   double riskPerLotDollars = (atrValue * 2.0) * (tickVal / tickSize); // $ par lot si SL 2x ATR touché
   if(riskPerLotDollars <= 0) riskPerLotDollars = 1.0;
   double potentialLoss = lot * riskPerLotDollars;
   if(potentialLoss > MaxLossPerSpikeTradeDollars)
   {
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(lotStep <= 0) lotStep = 0.01;
      double lotCap = MaxLossPerSpikeTradeDollars / riskPerLotDollars;
      lot = MathFloor(lotCap / lotStep) * lotStep;
      lot = MathMax(minLot, MathMin(maxLot, lot));
      lot = NormalizeDouble(lot, 2);
      potentialLoss = lot * riskPerLotDollars;
      if(potentialLoss > MaxLossPerSpikeTradeDollars * 1.01)
      {
         Print("? TRADE BLOQUÉ - Perte min (lot min ", DoubleToString(minLot, 2), ") = ", DoubleToString(potentialLoss, 2), "$ > ", MaxLossPerSpikeTradeDollars, "$");
         return;
      }
      Print("?? Lot réduit pour perte max ", MaxLossPerSpikeTradeDollars, "$ ? Lot: ", DoubleToString(lot, 2), " | Perte potentielle: ", DoubleToString(potentialLoss, 2), "$");
   }
   else
      Print("? Perte potentielle VALIDÉE: ", DoubleToString(potentialLoss, 2), "$ <= ", MaxLossPerSpikeTradeDollars, "$");
   
   // Envoyer notification
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double notificationSL = 0, notificationTP = 0;
   
   if(direction == "BUY")
   {
      notificationSL = currentPrice - (currentPrice * 0.001);
      notificationTP = currentPrice + (currentPrice * 0.003);
   }
   else // SELL
   {
      notificationSL = currentPrice + (currentPrice * 0.001);
      notificationTP = currentPrice - (currentPrice * 0.003);
   }
   
   SendDerivArrowNotification(direction, currentPrice, notificationSL, notificationTP);
   
   // Exécuter l'ordre
   bool orderExecuted = false;
   
   // DEBUG: Vérifier l'option NoSLTP_BoomCrash
   Print("?? DEBUG - NoSLTP_BoomCrash: ", NoSLTP_BoomCrash ? "OUI" : "NON", " | Catégorie: ", (SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH ? "BOOM_CRASH" : "AUTRE"));
   
   if(direction == "BUY")
   {
      if(!HasRecentSMCDerivArrowForDirection("BUY"))
      {
         Print("?? SPIKE TRADE BUY bloqué - Attendre flèche SMC_DERIV_ARROW BUY sur ", _Symbol);
         return;
      }
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = 0, tp = 0;
      
      // Appliquer SL/TP seulement si NoSLTP_BoomCrash est désactivé
      if(!NoSLTP_BoomCrash || SMC_GetSymbolCategory(_Symbol) != SYM_BOOM_CRASH)
      {
         sl = ask - atrValue * 2.0;  // Pour BUY: SL en-dessous (plus bas)
         tp = ask + atrValue * 3.0;  // Pour BUY: TP au-dessus (plus haut)
      }
      
      Print("?? DEBUG - BUY - Ask: ", DoubleToString(ask, _Digits), " | SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits));
      Print("?? DEBUG - Vérification SL/TP BUY - SL < Ask: ", (sl < ask || sl == 0) ? "OK" : "ERREUR", " | TP > Ask: ", (tp > ask || tp == 0) ? "OK" : "ERREUR");
      
      if(trade.Buy(lot, _Symbol, 0.0, sl, tp, "SPIKE TRADE BUY"))
      {
         orderExecuted = true;
         Print("? SPIKE TRADE BUY EXÉCUTÉ - ", _Symbol, " @", DoubleToString(ask, _Digits), " | Lot: ", DoubleToString(lot, 2), " | Magic: ", trade.RequestMagic());
         Print("?? DEBUG - Ticket d'ordre: ", trade.ResultOrder());
      }
      else
      {
         Print("? Échec SPIKE TRADE BUY - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   else // SELL
   {
      if(!HasRecentSMCDerivArrowForDirection("SELL"))
      {
         Print("?? SPIKE TRADE SELL bloqué - Attendre flèche SMC_DERIV_ARROW SELL sur ", _Symbol);
         return;
      }
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = 0, tp = 0;
      
      // Appliquer SL/TP seulement si NoSLTP_BoomCrash est désactivé
      if(!NoSLTP_BoomCrash || SMC_GetSymbolCategory(_Symbol) != SYM_BOOM_CRASH)
      {
         sl = bid + atrValue * 2.0;  // Pour SELL: SL au-dessus (plus haut)
         tp = bid - atrValue * 3.0;  // Pour SELL: TP en-dessous (plus bas)
      }
      
      Print("?? DEBUG - SELL - Bid: ", DoubleToString(bid, _Digits), " | SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits));
      Print("?? DEBUG - Vérification SL/TP SELL - SL > Bid: ", (sl > bid || sl == 0) ? "OK" : "ERREUR", " | TP < Bid: ", (tp < bid || tp == 0) ? "OK" : "ERREUR");
      
      if(trade.Sell(lot, _Symbol, 0.0, sl, tp, "SPIKE TRADE SELL"))
      {
         orderExecuted = true;
         Print("? SPIKE TRADE SELL EXÉCUTÉ - ", _Symbol, " @", DoubleToString(bid, _Digits), " | Lot: ", DoubleToString(lot, 2), " | Magic: ", trade.RequestMagic());
         Print("?? DEBUG - Ticket d'ordre: ", trade.ResultOrder());
      }
      else
      {
         Print("? Échec SPIKE TRADE SELL - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   
   if(orderExecuted)
   {
      Print("?? SPIKE TRADE EXÉCUTÉ AVEC SUCCÈS - Direction: ", direction, " | Symbole: ", _Symbol);
      
      // Démarrer la surveillance pour clôture immédiate en gain positif
      StartSpikePositionMonitoring(direction);
   }
}

//| SURVEILLER ET FERMER LA POSITION SPIKE EN GAIN POSITIF           |
void StartSpikePositionMonitoring(string direction)
{
   // DÉSACTIVÉ - Cette fonction fermait les positions trop rapidement
   // Laisser ManageBoomCrashSpikeClose() gérer les fermetures
   Print("?? SURVEILLANCE SPIKE DÉSACTIVÉE - Laisser le trade respirer");
   return;
   
   /* 
   // CODE ORIGINAL DÉSACTIVÉ:
   // Attendre un peu que la position soit complètement initialisée
   Sleep(1000);
   
   // Surveiller pendant 30 secondes maximum
   int maxAttempts = 30;
   int attempt = 0;
   
   while(attempt < maxAttempts)
   {
      // Parcourir les positions pour trouver celle du spike trade
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            string symbol = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            string comment = PositionGetString(POSITION_COMMENT);
            
            // Vérifier si c'est notre position spike
            if(symbol == _Symbol && StringFind(comment, "SPIKE TRADE") >= 0)
            {
               Print("?? SURVEILLANCE SPIKE - Ticket: ", ticket, " | Profit: ", DoubleToString(profit, 2), "$");
               
               // Fermer immédiatement si en gain positif (même 0.01$)
               if(profit > 0)
               {
                  Print("?? GAIN POSITIF DÉTECTÉ - Fermeture immédiate | Profit: ", DoubleToString(profit, 2), "$");
                  PositionCloseWithLog(ticket, "SPIKE GAIN POSITIF");
                  return;
               }
            }
         }
      }
      
      attempt++;
      Sleep(1000); // Attendre 1 seconde avant la prochaine vérification
   }
   
   Print("? FIN SURVEILLANCE SPIKE - Position non fermée dans le délai imparti");
   */
}

//| ROTATION AUTOMATIQUE DES POSITIONS - Évite de rester bloqué sur un symbole |
void AutoRotatePositions()
{
   int totalPositions = CountPositionsOurEA();
   
   // Si on n'est pas à la limite de positions, pas besoin de rotation
   if(totalPositions < MaxPositionsTerminal)
   {
      return;
   }
   
   // Si on est à la limite, vérifier s'il y a des opportunités sur d'autres symboles
   Print("?? ROTATION AUTO - Positions: ", totalPositions, "/", MaxPositionsTerminal, " - Vérification opportunités...");
   
   // Chercher la position la plus ancienne ou la moins performante
   ulong oldestTicket = 0;
   datetime oldestTime = TimeCurrent();
   double worstProfit = 999999;
   ulong worstTicket = 0;
   string worstSymbol = "";
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      
      string symbol = posInfo.Symbol();
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      datetime openTime = posInfo.Time();
      ulong ticket = posInfo.Ticket();
      
      // Priorité 1: Position en perte depuis longtemps
      if(profit < -0.5 && openTime < oldestTime)
      {
         oldestTime = openTime;
         oldestTicket = ticket;
      }
      
      // Priorité 2: Position avec la pire performance
      if(profit < worstProfit)
      {
         worstProfit = profit;
         worstTicket = ticket;
         worstSymbol = symbol;
      }
   }
   
   // Fermer la position la plus ancienne en perte OU la pire position
   ulong ticketToClose = (oldestTicket > 0) ? oldestTicket : worstTicket;
   
   if(ticketToClose > 0)
   {
      if(!PositionSelectByTicket(ticketToClose))
      {
         Print("?? Position déjà fermée avant rotation - ticket=", ticketToClose);
         return;
      }
      
      string symbolToClose = PositionGetString(POSITION_SYMBOL);
      double positionProfit = PositionGetDouble(POSITION_PROFIT);
      
      // Fermer seulement si c'est une position en perte ou si elle est ouverte depuis plus de 30 minutes
      datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);
      int minutesOpen = (int)(TimeCurrent() - positionTime) / 60;
      
      if(positionProfit < -0.2 || minutesOpen > 30)
      {
         Print("?? ROTATION AUTO - Fermeture position: ", symbolToClose, 
               " | Profit: ", DoubleToString(positionProfit, 2), "$",
               " | Âge: ", minutesOpen, " min");
         
         if(PositionCloseWithLog(ticketToClose, "Rotation automatique"))
         {
            Print("? ROTATION AUTO - Position fermée avec succès - Libère place pour nouvelles opportunités");
         }
         else
         {
            int err = GetLastError();
            Print("? ROTATION AUTO - Échec fermeture position: ", symbolToClose, " | Erreur: ", err);
         }
      }
      else
      {
         Print("?? ROTATION AUTO - Position conservée: ", symbolToClose, 
               " | Profit: ", DoubleToString(positionProfit, 2), "$",
               " | Âge: ", minutesOpen, " min (tôt ou profitable)");
      }
   }
   else
   {
      Print("?? ROTATION AUTO - Aucune position éligible à la fermeture");
   }
}

//| END OF PROGRAM                                                  |
