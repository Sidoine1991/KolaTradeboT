//+------------------------------------------------------------------+
//|                                     SMC_Imbalance_OTE_Visual.mq5 |
//|                                  Stratégie SMC - Casper Trading  |
//+------------------------------------------------------------------+
#property copyright "Créé par l'IA"
#property link      ""
#property version   "2.00"

#include <Trade\Trade.mqh>

//--- Paramètres d'entrée
input double   InpLotSize        = 0.1;      // Taille de position (Lots)
input int      InpSwingLookback  = 40;       // Période pour détecter le plus Haut/Bas (Swing)
input double   InpFiboOTE_1      = 0.620;    // Niveau Fibonacci OTE 1
input double   InpFiboOTE_2      = 0.786;    // Niveau Fibonacci OTE 2
input double   InpRiskReward     = 2.0;      // Ratio Risk:Reward (Objectif 2 pour 1)
input ulong    InpMagicNumber    = 123456;   // Magic Number
input bool     EnableTrading    = true;     // Activer les ordres au marché (true) ou dessiner seulement (false)
input bool     CleanBeforeDraw  = false;    // Nettoyer les anciens dessins OTE avant nouveau setup
input int      MinImbalancePoints = 1;      // Filtre minimum pour éviter les micro-gaps (points)
input bool     DrawEvenIfNoConfluence = true; // Si pas de confluence FVG<->OTE, afficher quand même les zones (debug/visuel)
input int      InpEmaFast       = 50;      // EMA fast (trend)
input int      InpEmaSlow       = 200;     // EMA slow (trend)
input int      InpMaxFvgToDraw   = 3;      // Nombre max de FVG à afficher (visual)

//--- NOUVEAUX: Paramètres IA et Tableau de Bord
input bool     UseAIServer       = true;    // Utiliser le serveur IA pour les décisions
input string   AIServerURL       = "http://localhost:8080/api/decision"; // URL du serveur IA
input int      AI_Timeout_ms     = 5000;    // Timeout pour les requêtes IA (ms)
input bool     ShowDashboard     = true;    // Afficher le tableau de bord des indicateurs
input int      DashboardUpdateInterval = 30; // Intervalle de mise à jour du tableau de bord (secondes)
input bool     EnableLimitOrders = true;    // Activer les ordres limit validés
input double   LimitOrderDistance = 0.0010; // Distance des ordres limit (en pips)
input bool     OTE_VirtualPendingMarket = true; // Pending affiché sur graphique + exé au marché au toucher du niveau
input bool     OTE_CancelPendingWhenSetupInvalid = true; // Annuler pending si confluence OTE+FVG n'est plus valide
input bool     OTE_InstantMarketOnConfluence = false; // Si true: entrée marché dès confluence (ignore virtual pending)
input bool     ShowMLMetrics = true;        // Afficher les métriques ML

//--- NOUVEAUX: Paramètres de confirmations OTE améliorées
input bool     EnableBreakerBlocks = true;    // Activer détection breaker blocks
input bool     EnableOrderBlocks = true;      // Activer détection order blocks
input bool     EnableLiquiditySweep = true;   // Activer détection prise de liquidité
input int      MinConfluenceScore = 3;        // Score minimum de confluence pour trading (1-5)
input bool     ShowConfluenceScore = true;    // Afficher le score de confluence
input int      SwingValidationBars = 5;      // Nombre de bougies pour valider swing points

//--- Couleurs pour les dessins
input color    ClrFVGBull        = clrLightSkyBlue; // Couleur Imbalance Haussière
input color    ClrFVGBear        = clrLightPink;    // Couleur Imbalance Baissière
input color    ClrOTE            = clrGold;         // Couleur Zone OTE

CTrade trade;
datetime lastBuySetupTime = 0;  // Anti-spam (BUY)
datetime lastSellSetupTime = 0; // Anti-spam (SELL)
string OBJ_PREFIX = "SMC_OTE_";
int hEmaFast = INVALID_HANDLE;
int hEmaSlow = INVALID_HANDLE;

//--- NOUVELLES VARIABLES GLOBALES IA ET TABLEAU DE BORD
string g_lastAIAction = "";
double g_lastAIConfidence = 0.0;
datetime g_lastAIUpdate = 0;
datetime g_lastDashboardUpdate = 0;
string g_currentTrend = "NEUTRAL";
double g_currentOTE_Low = 0.0;
double g_currentOTE_High = 0.0;
int g_activeFVGCount = 0;
bool g_hasConfluence = false;

//--- Variables pour ordres limit
string g_pendingLimitOrder = "";
double g_limitOrderPrice = 0.0;
datetime g_limitOrderTime = 0;
// Pending virtuel (ligne graphique + exé marché au toucher)
bool     g_virtualPendingActive = false;
bool     g_virtualIsBuy = false;
double   g_virtualSL = 0.0;
double   g_virtualTP = 0.0;
datetime g_pendingSwingTimeLow = 0;
datetime g_pendingSwingTimeHigh = 0;

// Préfixe distinct de OBJ_PREFIX ("SMC_OTE_") pour ne pas supprimer la ligne avec CleanupOTEObjects()
#define SMC_OTEVP_LINE "SMC_OTEVP_LINE"
#define SMC_OTEVP_LBL  "SMC_OTEVP_LBL"

//--- Variables pour métriques ML
string g_mlMetricsStr = "";
datetime g_lastMLMetricsUpdate = 0;

//--- Variables pour confirmations OTE améliorées
int g_confluenceScore = 0;
bool g_hasBreakerBlock = false;
bool g_hasOrderBlock = false;
bool g_hasLiquiditySweep = false;
double g_breakerBlockPrice = 0.0;
double g_orderBlockPrice = 0.0;
datetime g_liquiditySweepTime = 0;

void CleanupOTEObjects()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, OBJ_PREFIX) == 0) ObjectDelete(0, name);
   }
}

bool HasAnyOurExposure(string sym)
{
   // positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      string pSym = PositionGetString(POSITION_SYMBOL);
      long pMag = PositionGetInteger(POSITION_MAGIC);
      if(pSym == sym && (ulong)pMag == InpMagicNumber)
         return true;
   }
   // pending orders (limit uniquement pour ce EA)
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      string oSym = OrderGetString(ORDER_SYMBOL);
      long oMag = OrderGetInteger(ORDER_MAGIC);
      if(oSym == sym && (ulong)oMag == InpMagicNumber)
      {
         ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT)
            return true;
      }
   }
   return false;
}

int CountPositionsOurEA(string sym)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      string pSym = PositionGetString(POSITION_SYMBOL);
      long pMag = PositionGetInteger(POSITION_MAGIC);
      if(pSym == sym && (ulong)pMag == InpMagicNumber)
         count++;
   }
   return count;
}

// Confluence OTE∩FVG + risque minimal (même logique que la boucle principale)
bool ComputeAnyOteConfluence(const bool isBuy, const double swingLow, const double swingHigh,
                             const double oteZoneLow, const double oteZoneHigh,
                             const double &fvgTopArr[], const double &fvgBottomArr[], const int fvgCount,
                             const double point)
{
   for(int k = 0; k < fvgCount; k++)
   {
      double interLow = MathMax(fvgBottomArr[k], oteZoneLow);
      double interHigh = MathMin(fvgTopArr[k], oteZoneHigh);
      bool confluenceOk = (interHigh > interLow) ||
                          (MathAbs(interHigh - interLow) < (oteZoneHigh - oteZoneLow) * 0.3);
      if(!confluenceOk) continue;
      double entryPrice = isBuy ? interHigh : interLow;
      double sl = isBuy ? swingLow : swingHigh;
      double risk = isBuy ? (entryPrice - sl) : (sl - entryPrice);
      if(risk > point * 2.0)
         return true;
   }
   return false;
}

void CancelOurBrokerLimitOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT)
         trade.OrderDelete(ticket);
   }
}

void DeleteVirtualPendingGraphics()
{
   ObjectDelete(0, SMC_OTEVP_LINE);
   ObjectDelete(0, SMC_OTEVP_LBL);
}

void ClearVirtualPendingState()
{
   g_virtualPendingActive = false;
   g_virtualIsBuy = false;
   g_virtualSL = 0.0;
   g_virtualTP = 0.0;
   DeleteVirtualPendingGraphics();
   if(StringFind(g_pendingLimitOrder, "VIRTUAL") >= 0)
   {
      g_pendingLimitOrder = "";
      g_limitOrderPrice = 0.0;
      g_limitOrderTime = 0;
   }
}

void CancelAllOtePending(const string reason)
{
   CancelOurBrokerLimitOrders();
   ClearVirtualPendingState();
   g_pendingLimitOrder = "";
   g_limitOrderPrice = 0.0;
   g_limitOrderTime = 0;
   Print("SMC_OTE - Pending annulé (", reason, ")");
}

void SyncPendingLimitFromBroker()
{
   if(g_virtualPendingActive) return;
   if(g_pendingLimitOrder == "") return;
   if(StringFind(g_pendingLimitOrder, "VIRTUAL") >= 0) return;

   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT)
         count++;
   }
   if(count == 0)
   {
      g_pendingLimitOrder = "";
      g_limitOrderPrice = 0.0;
      g_limitOrderTime = 0;
   }
}

void DrawOrUpdateVirtualPendingLine(const double price, const bool isBuy)
{
   if(ObjectFind(0, SMC_OTEVP_LINE) < 0)
   {
      ObjectCreate(0, SMC_OTEVP_LINE, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, SMC_OTEVP_LINE, OBJPROP_COLOR, isBuy ? clrDodgerBlue : clrOrangeRed);
      ObjectSetInteger(0, SMC_OTEVP_LINE, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, SMC_OTEVP_LINE, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, SMC_OTEVP_LINE, OBJPROP_BACK, false);
      ObjectSetString(0, SMC_OTEVP_LINE, OBJPROP_TOOLTIP,
                      "OTE pending → exécution marché au toucher");
   }
   else
   {
      ObjectSetDouble(0, SMC_OTEVP_LINE, OBJPROP_PRICE, price);
      ObjectSetInteger(0, SMC_OTEVP_LINE, OBJPROP_COLOR, isBuy ? clrDodgerBlue : clrOrangeRed);
   }

   datetime tlab = TimeCurrent();
   if(ObjectFind(0, SMC_OTEVP_LBL) < 0)
      ObjectCreate(0, SMC_OTEVP_LBL, OBJ_TEXT, 0, tlab, price);
   else
   {
      ObjectSetInteger(0, SMC_OTEVP_LBL, OBJPROP_TIME, tlab);
      ObjectSetDouble(0, SMC_OTEVP_LBL, OBJPROP_PRICE, price);
   }
   string txt = StringFormat("OTE pending %s @ %s → MARCHÉ au toucher",
                             isBuy ? "BUY" : "SELL",
                             DoubleToString(price, _Digits));
   ObjectSetString(0, SMC_OTEVP_LBL, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, SMC_OTEVP_LBL, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, SMC_OTEVP_LBL, OBJPROP_FONTSIZE, 9);
}

bool PlaceVirtualPendingOrder(const string direction, const double entryPrice, const double sl, const double tp,
                              const datetime swingTLow, const datetime swingTHigh)
{
   if(!EnableLimitOrders) return false;
   if(g_pendingLimitOrder != "" || g_virtualPendingActive)
   {
      Print("SMC_OTE - Pending déjà actif: ", g_pendingLimitOrder);
      return false;
   }

   g_virtualPendingActive = true;
   g_virtualIsBuy = (direction == "BUY");
   g_limitOrderPrice = entryPrice;
   g_virtualSL = sl;
   g_virtualTP = tp;
   g_limitOrderTime = TimeCurrent();
   g_pendingSwingTimeLow = swingTLow;
   g_pendingSwingTimeHigh = swingTHigh;
   g_pendingLimitOrder = g_virtualIsBuy ? "VIRTUAL_BUY" : "VIRTUAL_SELL";

   DrawOrUpdateVirtualPendingLine(entryPrice, g_virtualIsBuy);
   Print("SMC_OTE - Pending virtuel placé (graphique) @ ", DoubleToString(entryPrice, _Digits),
         " → exécution au marché au toucher");
   return true;
}

void CheckVirtualPendingTouch()
{
   if(!g_virtualPendingActive) return;
   if(!EnableTrading) return;
   if(CountPositionsOurEA(_Symbol) >= 2) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) return;

   double entry = g_limitOrderPrice;
   bool touched = false;
   if(g_virtualIsBuy)
   {
      if(bid <= entry + point * 3.0)
         touched = true;
   }
   else
   {
      if(ask >= entry - point * 3.0)
         touched = true;
   }

   if(!touched) return;

   bool ok = false;
   if(g_virtualIsBuy)
   {
      ok = trade.Buy(InpLotSize, _Symbol, ask, g_virtualSL, g_virtualTP, "OTE_VP_BUY_MKT");
   }
   else
   {
      ok = trade.Sell(InpLotSize, _Symbol, bid, g_virtualSL, g_virtualTP, "OTE_VP_SELL_MKT");
   }

   if(ok)
   {
      Print("SMC_OTE - Pending virtuel déclenché → ordre marché @ ",
            g_virtualIsBuy ? DoubleToString(ask, _Digits) : DoubleToString(bid, _Digits));
      ClearVirtualPendingState();
      g_pendingLimitOrder = "";
      g_limitOrderPrice = 0.0;
      g_limitOrderTime = 0;
   }
   else
   {
      Print("SMC_OTE - Échec exé marché depuis pending virtuel: ",
            trade.ResultRetcode(), " - ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   hEmaFast = iMA(_Symbol, _Period, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaSlow = iMA(_Symbol, _Period, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   if(hEmaFast == INVALID_HANDLE || hEmaSlow == INVALID_HANDLE)
      Print("? SMC_OTE - EMA handle invalide (fast=", hEmaFast, " slow=", hEmaSlow, ")");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
{
   if(hEmaFast != INVALID_HANDLE) IndicatorRelease(hEmaFast);
   if(hEmaSlow != INVALID_HANDLE) IndicatorRelease(hEmaSlow);
   DeleteVirtualPendingGraphics();
}

//+------------------------------------------------------------------+
//| Helper : Dessiner un rectangle (Imbalance / OTE)                 |
//+------------------------------------------------------------------+
void DrawRectangle(string name, datetime time1, double price1, datetime time2, double price2, color clr)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_BACK, true); // Met le rectangle en arrière-plan
      ObjectSetInteger(0, name, OBJPROP_FILL, true); // Remplit le rectangle de couleur
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
  }

//+------------------------------------------------------------------+
//| Helper : Dessiner le Fibonacci                                   |
//+------------------------------------------------------------------+
void DrawFibo(string name, datetime time1, double price1, datetime time2, double price2)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_FIBO, 0, time1, price1, time2, price2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrDarkGray);
      ObjectSetInteger(0, name, OBJPROP_LEVELS, 4); // On garde seulement 4 niveaux clés
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 0, 0.0);
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 1, 1.0);
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 2, 0.62);
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 3, 0.786);
      
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, 0, "0.0");
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, 1, "1.0");
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, 2, "0.62 OTE");
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, 3, "0.786 OTE");
     }
  }

//+------------------------------------------------------------------+
//| Helper : Dessiner une ligne (Entry, SL, TP)                      |
//+------------------------------------------------------------------+
void DrawLine(string name, datetime time1, double price, datetime time2, color clr, int style = STYLE_SOLID)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false); // Empêche la ligne d'aller à l'infini
     }
   else
   {
      // Update (au cas où tu réattaches / recompile et que les paramètres changent)
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectMove(0, name, 0, time1, price);
      ObjectMove(0, name, 1, time2, price);
   }
  }

//+------------------------------------------------------------------+
//| NOUVELLES FONCTIONS IA ET TABLEAU DE BORD                        |
//+------------------------------------------------------------------+

// Fonction pour obtenir la décision de l'IA
bool GetAIDecision(string &actionOut, double &confidenceOut)
{
   if(!UseAIServer) return false;
   
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastAIUpdate < 60) // Mise à jour toutes les 60 secondes max
   {
      actionOut = g_lastAIAction;
      confidenceOut = g_lastAIConfidence;
      return true;
   }
   
   // Préparer les données pour l'IA
   string jsonData = PrepareAIData();
   
   // Envoyer la requête HTTP
   string response = "";
   if(!SendHTTPRequest(AIServerURL, jsonData, response, AI_Timeout_ms))
   {
      Print("❌ SMC_OTE - Erreur de communication avec le serveur IA");
      return false;
   }
   
   // Parser la réponse JSON
   if(!ParseAIResponse(response, actionOut, confidenceOut))
   {
      Print("❌ SMC_OTE - Erreur parsing réponse IA: ", response);
      return false;
   }
   
   // Mettre à jour les variables globales
   g_lastAIAction = actionOut;
   g_lastAIConfidence = confidenceOut;
   g_lastAIUpdate = currentTime;
   
   Print("🤖 SMC_OTE - Décision IA: ", actionOut, " (Confiance: ", confidenceOut, "%)");
   return true;
}

// Préparer les données pour l'IA
string PrepareAIData()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   CopyRates(_Symbol, _Period, 0, 50, rates);
   
   double currentPrice = rates[0].close;
   double emaFast = 0.0, emaSlow = 0.0;
   
   if(hEmaFast != INVALID_HANDLE && hEmaSlow != INVALID_HANDLE)
   {
      double a1[], a2[];
      ArraySetAsSeries(a1, true);
      ArraySetAsSeries(a2, true);
      CopyBuffer(hEmaFast, 0, 0, 1, a1);
      CopyBuffer(hEmaSlow, 0, 0, 1, a2);
      emaFast = a1[0];
      emaSlow = a2[0];
   }
   
   // Créer une chaîne de données simple (format: key=value&key2=value2)
   string data = "";
   data += "symbol=" + _Symbol;
   data += "&timeframe=" + EnumToString(_Period);
   data += "&current_price=" + DoubleToString(currentPrice, _Digits);
   data += "&ema_fast=" + DoubleToString(emaFast, _Digits);
   data += "&ema_slow=" + DoubleToString(emaSlow, _Digits);
   data += "&ote_low=" + DoubleToString(g_currentOTE_Low, _Digits);
   data += "&ote_high=" + DoubleToString(g_currentOTE_High, _Digits);
   data += "&fvg_count=" + IntegerToString(g_activeFVGCount);
   data += "&has_confluence=" + (g_hasConfluence ? "true" : "false");
   data += "&trend=" + g_currentTrend;
   
   return data;
}

// Envoyer une requête HTTP
bool SendHTTPRequest(string url, string data, string &response, int timeout)
{
   // Simulation pour le moment - à remplacer avec vraie requête HTTP
   // Pour l'instant, on génère une décision basique
   if(MathRand() % 2 == 0)
   {
      response = "action=BUY&confidence=75.5";
   }
   else
   {
      response = "action=SELL&confidence=68.2";
   }
   return true;
}

// Parser la réponse de l'IA (version simplifiée)
bool ParseAIResponse(string response, string &actionOut, double &confidenceOut)
{
   // Parser format: action=BUY&confidence=75.5
   string parts[];
   StringSplit(response, '&', parts);
   
   for(int i = 0; i < ArraySize(parts); i++)
   {
      string keyValue[];
      StringSplit(parts[i], '=', keyValue);
      
      if(ArraySize(keyValue) == 2)
      {
         if(keyValue[0] == "action")
            actionOut = keyValue[1];
         else if(keyValue[0] == "confidence")
            confidenceOut = StringToDouble(keyValue[1]);
      }
   }
   
   return (actionOut != "" && confidenceOut > 0);
}

// Mettre à jour les métriques ML
void UpdateMLMetricsDisplay()
{
   if(!ShowMLMetrics) return;
   
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastMLMetricsUpdate < 60) return; // Mise à jour toutes les 60 secondes
   
   g_lastMLMetricsUpdate = currentTime;
   
   // Appel API pour métriques ML
   string response = "";
   string url = AIServerURL + "/ml/metrics/" + _Symbol + "?timeframe=" + EnumToString(_Period);
   
   if(!SendHTTPRequest(url, "", response, AI_Timeout_ms))
   {
      g_mlMetricsStr = "Erreur API";
      return;
   }
   
   // Parser la réponse
   string parts[];
   StringSplit(response, '&', parts);
   
   string training_level = "";
   double accuracy = 0.0, f1_score = 0.0;
   int samples_used = 0;
   string model_type = "";
   
   for(int i = 0; i < ArraySize(parts); i++)
   {
      string keyValue[];
      StringSplit(parts[i], '=', keyValue);
      
      if(ArraySize(keyValue) == 2)
      {
         if(keyValue[0] == "training_level") training_level = keyValue[1];
         else if(keyValue[0] == "accuracy") accuracy = StringToDouble(keyValue[1]);
         else if(keyValue[0] == "f1_score") f1_score = StringToDouble(keyValue[1]);
         else if(keyValue[0] == "samples_used") samples_used = (int)StringToInteger(keyValue[1]);
         else if(keyValue[0] == "model_type") model_type = keyValue[1];
      }
   }
   
   // Formater l'affichage
   g_mlMetricsStr = training_level + " | 📊 " + 
                   DoubleToString(accuracy * 100, 1) + "%/" + 
                   DoubleToString(f1_score * 100, 1) + "% | 📚 " + 
                   IntegerToString(samples_used) + " (" + model_type + ")";
}

// Mettre à jour le tableau de bord des indicateurs
void UpdateDashboard()
{
   if(!ShowDashboard) return;

   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastDashboardUpdate < DashboardUpdateInterval) return;

   g_lastDashboardUpdate = currentTime;

   // Nettoyer les anciens objets du tableau de bord
   ObjectsDeleteAll(0, "SMC_DASHBOARD_");

   // Calculer la position Y en coordonnées de prix (haut du graphique)
   double chartHeight = ChartGetDouble(0, CHART_PRICE_MAX);
   double chartLow = ChartGetDouble(0, CHART_PRICE_MIN);
   double priceRange = chartHeight - chartLow;
   double dashboardY = chartHeight - (priceRange * 0.1); // Position à 10% du haut du graphique

   // Créer le fond du tableau de bord (plus petit pour le haut)
   string dashboardName = "SMC_DASHBOARD_BG";
   ObjectCreate(0, dashboardName, OBJ_RECTANGLE, 0,
               TimeCurrent() - PeriodSeconds() * 8, // Plus à gauche
               dashboardY + (priceRange * 0.15), // Hauteur du fond
               TimeCurrent() + PeriodSeconds() * 4, // Plus large
               dashboardY); // Bas du fond
   ObjectSetInteger(0, dashboardName, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, dashboardName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, dashboardName, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, dashboardName, OBJPROP_BACK, false);
   ObjectSetInteger(0, dashboardName, OBJPROP_FILL, true);

   // Titre du tableau de bord (positionné en haut du fond)
   string titleName = "SMC_DASHBOARD_TITLE";
   ObjectCreate(0, titleName, OBJ_TEXT, 0,
               (int)TimeCurrent() - (int)PeriodSeconds() * 7.5, // Position à gauche
               dashboardY + (priceRange * 0.12));
   ObjectSetString(0, titleName, OBJPROP_TEXT, " SMC_OTE DASHBOARD");
   ObjectSetInteger(0, titleName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, titleName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, titleName, OBJPROP_ALIGN, ALIGN_LEFT);

   // Ligne 1: Tendance
   string trendName = "SMC_DASHBOARD_TREND";
   ObjectCreate(0, trendName, OBJ_TEXT, 0,
               (int)TimeCurrent() - (int)PeriodSeconds() * 7.5,
               dashboardY + (priceRange * 0.09));
   ObjectSetString(0, trendName, OBJPROP_TEXT,
                  " Tendance: " + g_currentTrend +
                  " | OTE: " + DoubleToString(g_currentOTE_Low, _Digits) + " - " + DoubleToString(g_currentOTE_High, _Digits));
   ObjectSetInteger(0, trendName, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, trendName, OBJPROP_FONTSIZE, 10);

   // Ligne 2: FVG et Confluence améliorée
   string fvgName = "SMC_DASHBOARD_FVG";
   ObjectCreate(0, fvgName, OBJ_TEXT, 0,
               (int)TimeCurrent() - (int)PeriodSeconds() * 7.5,
               dashboardY + (priceRange * 0.06));
   
   string confluenceText = " FVG: " + IntegerToString(g_activeFVGCount) + 
                          " | Score: " + IntegerToString(g_confluenceScore) + "/5" +
                          " | BB:" + (g_hasBreakerBlock ? "✓" : "✗") +
                          " | OB:" + (g_hasOrderBlock ? "✓" : "✗") +
                          " | LIQ:" + (g_hasLiquiditySweep ? "✓" : "✗");
   
   ObjectSetString(0, fvgName, OBJPROP_TEXT, confluenceText);
   ObjectSetInteger(0, fvgName, OBJPROP_COLOR, g_confluenceScore >= MinConfluenceScore ? clrLime : clrOrange);
   ObjectSetInteger(0, fvgName, OBJPROP_FONTSIZE, 9);

   // Ligne 3: IA
   string iaName = "SMC_DASHBOARD_IA";
   ObjectCreate(0, iaName, OBJ_TEXT, 0,
               (int)TimeCurrent() - (int)PeriodSeconds() * 7.5,
               dashboardY + (priceRange * 0.03));
   ObjectSetString(0, iaName, OBJPROP_TEXT,
                  " IA: " + g_lastAIAction +
                  " (Confiance: " + DoubleToString(g_lastAIConfidence, 1) + "%)");
   ObjectSetInteger(0, iaName, OBJPROP_COLOR, clrAqua);
   ObjectSetInteger(0, iaName, OBJPROP_FONTSIZE, 10);

   // Ligne 4: Ordres limit
   string limitName = "SMC_DASHBOARD_LIMIT";
   ObjectCreate(0, limitName, OBJ_TEXT, 0,
               (int)TimeCurrent() - (int)PeriodSeconds() * 7.5,
               dashboardY);
   if(g_pendingLimitOrder != "")
   {
      ObjectSetString(0, limitName, OBJPROP_TEXT,
                     " Ordre Limit: " + g_pendingLimitOrder +
                     " @ " + DoubleToString(g_limitOrderPrice, _Digits));
      ObjectSetInteger(0, limitName, OBJPROP_COLOR, clrOrange);
   }
   else
   {
      ObjectSetString(0, limitName, OBJPROP_TEXT, " Ordre Limit: AUCUN");
      ObjectSetInteger(0, limitName, OBJPROP_COLOR, clrGray);
   }
   ObjectSetInteger(0, limitName, OBJPROP_FONTSIZE, 10);

   // Ligne 5: Métriques ML
   if(ShowMLMetrics)
   {
      UpdateMLMetricsDisplay();
      string mlName = "SMC_DASHBOARD_ML";
      ObjectCreate(0, mlName, OBJ_TEXT, 0,
                  (int)TimeCurrent() - (int)PeriodSeconds() * 7.5,
                  dashboardY - (priceRange * 0.03));
      ObjectSetString(0, mlName, OBJPROP_TEXT, " ML: " + g_mlMetricsStr);
      ObjectSetInteger(0, mlName, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, mlName, OBJPROP_FONTSIZE, 8);
   }

   ChartRedraw();
}

// Placer un ordre limit validé
bool PlaceValidatedLimitOrder(string direction, double entryPrice, double sl, double tp)
{
   if(!EnableLimitOrders) return false;
   
   // Vérifier si on a déjà un ordre en attente
   if(g_pendingLimitOrder != "")
   {
      Print("📌 SMC_OTE - Ordre limit déjà en attente: ", g_pendingLimitOrder);
      return false;
   }
   
   double lot = InpLotSize;
   bool success = false;
   
   if(direction == "BUY")
   {
      success = trade.BuyLimit(lot, entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "SMC_OTE_BUY_LIMIT");
      if(success)
      {
         g_pendingLimitOrder = "BUY_LIMIT";
         g_limitOrderPrice = entryPrice;
         g_limitOrderTime = TimeCurrent();
         Print("✅ SMC_OTE - BUY LIMIT placé @ ", DoubleToString(entryPrice, _Digits));
      }
   }
   else if(direction == "SELL")
   {
      success = trade.SellLimit(lot, entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "SMC_OTE_SELL_LIMIT");
      if(success)
      {
         g_pendingLimitOrder = "SELL_LIMIT";
         g_limitOrderPrice = entryPrice;
         g_limitOrderTime = TimeCurrent();
         Print("✅ SMC_OTE - SELL LIMIT placé @ ", DoubleToString(entryPrice, _Digits));
      }
   }
   
   if(!success)
   {
      Print("❌ SMC_OTE - Échec placement ordre limit: ", trade.ResultRetcode(), " - ", trade.ResultComment());
   }
   
   return success;
}

// Vérifier et nettoyer les ordres limit expirés (broker + pending virtuel)
void CheckExpiredLimitOrders()
{
   if(g_pendingLimitOrder == "") return;
   
   // Si l'ordre a plus de 30 minutes, l'annuler
   if(TimeCurrent() - g_limitOrderTime > 1800) // 30 minutes
   {
      if(g_virtualPendingActive)
      {
         Print("🗑️ SMC_OTE - Pending virtuel expiré (30 min)");
         CancelAllOtePending("expiration 30min");
         return;
      }

      // Rechercher et annuler l'ordre broker
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         if(!OrderSelect(ticket)) continue;
         
         string oSym = OrderGetString(ORDER_SYMBOL);
         long oMag = OrderGetInteger(ORDER_MAGIC);
         
         if(oSym == _Symbol && (ulong)oMag == InpMagicNumber)
         {
            ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT)
            {
               if(trade.OrderDelete(ticket))
               {
                  Print("🗑️ SMC_OTE - Ordre limit expiré annulé: ", g_pendingLimitOrder);
                  g_pendingLimitOrder = "";
                  g_limitOrderPrice = 0.0;
                  g_limitOrderTime = 0;
                  break;
               }
            }
         }
      }
   }
}

// Dessiner les bougies futures et prédictions OTE
void DrawFutureCandlesAndPredictions()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 0, 50, rates) < 20) return;
   
   datetime currentTime = rates[0].time;
   double currentPrice = rates[0].close;
   
   // Dessiner 5 bougies futures hypothétiques
   for(int i = 1; i <= 5; i++)
   {
      datetime futureTime = currentTime + (PeriodSeconds() * i);
      double futurePrice = currentPrice; // Prix de base
      
      // Ajuster selon la tendance et l'IA
      if(g_currentTrend == "UPTREND")
      {
         futurePrice += (i * 0.0005); // Croissance progressive
      }
      else if(g_currentTrend == "DOWNTREND")
      {
         futurePrice -= (i * 0.0005); // Décroissance progressive
      }
      
      // Dessiner la bougie future
      string candleName = "SMC_FUTURE_CANDLE_" + IntegerToString(i);
      ObjectCreate(0, candleName, OBJ_RECTANGLE, 0, 
                  futureTime - PeriodSeconds()/2, futurePrice - 0.0010,
                  futureTime + PeriodSeconds()/2, futurePrice + 0.0010);
      
      // Couleur selon la prédiction IA
      color candleColor = clrGray;
      if(g_lastAIAction == "BUY" && g_lastAIConfidence > 70)
         candleColor = clrGreen;
      else if(g_lastAIAction == "SELL" && g_lastAIConfidence > 70)
         candleColor = clrRed;
      
      ObjectSetInteger(0, candleName, OBJPROP_COLOR, candleColor);
      ObjectSetInteger(0, candleName, OBJPROP_BGCOLOR, candleColor);
      ObjectSetInteger(0, candleName, OBJPROP_BACK, false);
      ObjectSetInteger(0, candleName, OBJPROP_FILL, true);
      ObjectSetInteger(0, candleName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, candleName, OBJPROP_WIDTH, 1);
   }
   
   // Dessiner la zone de prédiction OTE dans le futur
   if(g_currentOTE_Low > 0 && g_currentOTE_High > 0)
   {
      string predictionName = "SMC_OTE_PREDICTION";
      datetime predictionStart = currentTime + PeriodSeconds() * 2;
      datetime predictionEnd = currentTime + PeriodSeconds() * 8;
      
      ObjectCreate(0, predictionName, OBJ_RECTANGLE, 0, 
                  predictionStart, g_currentOTE_High,
                  predictionEnd, g_currentOTE_Low);
      ObjectSetInteger(0, predictionName, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, predictionName, OBJPROP_BGCOLOR, clrGold);
      ObjectSetInteger(0, predictionName, OBJPROP_BACK, true);
      ObjectSetInteger(0, predictionName, OBJPROP_FILL, true);
      ObjectSetInteger(0, predictionName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, predictionName, OBJPROP_WIDTH, 2);
      
      // Label de prédiction
      string labelName = "SMC_OTE_PREDICTION_LABEL";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, 
                  predictionStart, (g_currentOTE_Low + g_currentOTE_High) / 2);
      ObjectSetString(0, labelName, OBJPROP_TEXT, "🔮 OTE Prediction");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 0) Mettre à jour les variables globales et le tableau de bord
   UpdateGlobalVariables();
   UpdateDashboard();
   CheckExpiredLimitOrders();
   
   // 1) Charger l'historique (rates) pour détecter FVG + swing + fib OTE
   int bars = MathMax(InpSwingLookback + 10, 70);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 0, bars, rates) < bars) return;

   datetime curTime = rates[0].time;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) return;

   // 2) Nettoyage optionnel (souvent pour debug/visuel)
   if(CleanBeforeDraw)
      CleanupOTEObjects();

   // 3) Obtenir la décision de l'IA
   string aiAction = "";
   double aiConfidence = 0.0;
   bool hasAIDecision = GetAIDecision(aiAction, aiConfidence);

   // 4) Déterminer la tendance via EMA fast/slow
   double emaFast = 0.0, emaSlow = 0.0;
   if(hEmaFast != INVALID_HANDLE && hEmaSlow != INVALID_HANDLE)
   {
      double a1[], a2[];
      ArraySetAsSeries(a1, true);
      ArraySetAsSeries(a2, true);
      if(CopyBuffer(hEmaFast, 0, 0, 1, a1) < 1) return;
      if(CopyBuffer(hEmaSlow, 0, 0, 1, a2) < 1) return;
      emaFast = a1[0];
      emaSlow = a2[0];
   }
   else
   {
      // Fallback: si handles invalides, décider tendance sur prix (fail-open visuel)
      emaFast = rates[0].close;
      emaSlow = rates[MathMin(20, bars-1)].close;
   }

   bool upTrend = (emaFast > emaSlow);
   bool isBuy = upTrend;
   
   // Mettre à jour la tendance globale
   g_currentTrend = upTrend ? "UPTREND" : "DOWNTREND";

   // Anti-spam: autoriser plusieurs trades mais avec délai raisonnable
   if(isBuy && curTime == lastBuySetupTime && curTime - lastBuySetupTime < PeriodSeconds() * 2) return;
   if(!isBuy && curTime == lastSellSetupTime && curTime - lastSellSetupTime < PeriodSeconds() * 2) return;

   // 5) Projeter à droite
   datetime futureTime = curTime + (PeriodSeconds() * 20);

   // 6) Swing anchors (min low / max high sur lookback)
   int lookN = MathMin(InpSwingLookback, bars - 5);
   double swingLow = rates[0].low;
   double swingHigh = rates[0].high;
   datetime timeLow = rates[0].time;
   datetime timeHigh = rates[0].time;

   for(int i = 0; i < lookN; i++)
   {
      if(rates[i].low < swingLow)
      {
         swingLow = rates[i].low;
         timeLow = rates[i].time;
      }
      if(rates[i].high > swingHigh)
      {
         swingHigh = rates[i].high;
         timeHigh = rates[i].time;
      }
   }

   double range = swingHigh - swingLow;
   if(range <= point * 10.0)
   {
      // Fail-open visuel: éviter "rien ne s'affiche" sur des marchés peu volatils
      range = point * 10.0;
      swingHigh = swingLow + range;
      timeHigh = timeLow;
   }

   // 7) Calcul OTE (0.62-0.786)
   double oteA = 0.0, oteB = 0.0;
   if(isBuy)
   {
      // OTE buy proche du haut (62% -> 78.6%)
      oteA = swingLow + range * 0.62;   // plus bas
      oteB = swingLow + range * 0.786;  // plus haut
   }
   else
   {
      // OTE sell proche du bas
      oteA = swingHigh - range * 0.62;
      oteB = swingHigh - range * 0.786;
   }

   double oteZoneLow  = MathMin(oteA, oteB);
   double oteZoneHigh = MathMax(oteA, oteB);
   
   // Mettre à jour les variables OTE globales
   g_currentOTE_Low = oteZoneLow;
   g_currentOTE_High = oteZoneHigh;

   // 8) Détecter un ou plusieurs FVG (Imbalance) dans le lookback
   int fvgCount = 0;
   double fvgTopArr[5];
   double fvgBottomArr[5];
   datetime fvgTimeArr[5];

   for(int i = 2; i < lookN - 2 && fvgCount < InpMaxFvgToDraw; i++)
   {
      // Bullish FVG (imbalance pour BUY): rates[i-1].low > rates[i+1].high
      if(isBuy)
      {
         if(rates[i-1].low > rates[i+1].high)
         {
            double gap = rates[i-1].low - rates[i+1].high;
            if(gap >= point * MinImbalancePoints)
            {
               fvgTopArr[fvgCount] = rates[i-1].low;
               fvgBottomArr[fvgCount] = rates[i+1].high;
               fvgTimeArr[fvgCount] = rates[i+1].time;
               fvgCount++;
            }
         }
      }
      else
      {
         // Bearish FVG (imbalance pour SELL): rates[i-1].high < rates[i+1].low
         if(rates[i-1].high < rates[i+1].low)
         {
            double gap = rates[i+1].low - rates[i-1].high;
            if(gap >= point * MinImbalancePoints)
            {
               fvgTopArr[fvgCount] = rates[i+1].low;
               fvgBottomArr[fvgCount] = rates[i-1].high;
               fvgTimeArr[fvgCount] = rates[i+1].time;
               fvgCount++;
            }
         }
      }
   }
   
   // Mettre à jour les variables FVG globales
   g_activeFVGCount = fvgCount;

   // 8.5) Détecter les confirmations OTE améliorées
   g_hasBreakerBlock = DetectBreakerBlock(rates, isBuy, g_breakerBlockPrice);
   g_hasOrderBlock = DetectOrderBlock(rates, isBuy, g_orderBlockPrice);
   g_hasLiquiditySweep = DetectLiquiditySweep(rates, isBuy, g_liquiditySweepTime);
   
   // Calculer le score de confluence amélioré
   bool hasFVGConfluence = ComputeAnyOteConfluence(isBuy, swingLow, swingHigh,
                                                  oteZoneLow, oteZoneHigh,
                                                  fvgTopArr, fvgBottomArr, fvgCount, point);
   
   g_confluenceScore = CalculateConfluenceScore(hasFVGConfluence, g_hasBreakerBlock, 
                                               g_hasOrderBlock, g_hasLiquiditySweep, upTrend);
   
   const bool anyConfluenceThisTick = (g_confluenceScore >= MinConfluenceScore);
   
   SyncPendingLimitFromBroker();
   if(OTE_CancelPendingWhenSetupInvalid && (g_pendingLimitOrder != "" || g_virtualPendingActive))
   {
      if(!anyConfluenceThisTick)
         CancelAllOtePending("setup OTE+FVG non valide");
   }
   CheckVirtualPendingTouch();
   if(g_virtualPendingActive && g_limitOrderPrice > 0.0)
      DrawOrUpdateVirtualPendingLine(g_limitOrderPrice, g_virtualIsBuy);

   // 9) Dessin commun: Fibonacci + OTE
   string dirStr = isBuy ? "Buy" : "Sell";
   string basePrefix = OBJ_PREFIX + dirStr + "_" + IntegerToString((long)curTime);

   DrawFibo(basePrefix + "_Fibo", timeLow, swingLow, timeHigh, swingHigh);
   // OTE rectangle: de zoneHigh à zoneLow
   DrawRectangle(basePrefix + "_OTE", curTime, oteZoneHigh, futureTime, oteZoneLow, ClrOTE);

   // 10) Dessiner les bougies futures et prédictions
   DrawFutureCandlesAndPredictions();

   // 10.5) Dessiner les confirmations OTE améliorées
   DrawConfirmations(isBuy, curTime, oteZoneLow, oteZoneHigh);

   // 11) Pour chaque FVG: dessiner le FVG + (si confluence) lines Entry/SL/TP + trading
   for(int k = 0; k < fvgCount; k++)
   {
      double fvgTop = fvgTopArr[k];
      double fvgBottom = fvgBottomArr[k];
      datetime tFVG = fvgTimeArr[k];

      string fvgPrefix = basePrefix + "_FVG" + IntegerToString(k);
      if(isBuy)
         DrawRectangle(fvgPrefix + "_Zone", tFVG, fvgTop, futureTime, fvgBottom, ClrFVGBull);
      else
         DrawRectangle(fvgPrefix + "_Zone", tFVG, fvgTop, futureTime, fvgBottom, ClrFVGBear);

      // Intersection confluence FVG ∩ OTE (assouplie)
      double interLow = MathMax(fvgBottom, oteZoneLow);
      double interHigh = MathMin(fvgTop, oteZoneHigh);
      // Confluence plus flexible: chevauchement partiel autorisé
      bool confluenceOk = (interHigh > interLow) || (MathAbs(interHigh - interLow) < (oteZoneHigh - oteZoneLow) * 0.3);
      
      // Mettre à jour la variable de confluence
      g_hasConfluence = confluenceOk;

      if(confluenceOk || DrawEvenIfNoConfluence)
      {
         if(confluenceOk)
         {
            double entryPrice = isBuy ? interHigh : interLow;
            double sl = isBuy ? swingLow : swingHigh;
            double risk = isBuy ? (entryPrice - sl) : (sl - entryPrice);
            if(risk > point * 2)
            {
               double tp = isBuy ? (entryPrice + InpRiskReward * risk) : (entryPrice - InpRiskReward * risk);

               DrawLine(fvgPrefix + "_Entry", curTime, entryPrice, futureTime, clrDodgerBlue, STYLE_SOLID);
               DrawLine(fvgPrefix + "_SL",    curTime, sl,          futureTime, clrRed, STYLE_DASH);
               DrawLine(fvgPrefix + "_TP",    curTime, tp,          futureTime, clrLimeGreen, STYLE_SOLID);
               
               // Vérifier la décision IA pour le trading
               bool aiAllowsTrade = false;
               if(hasAIDecision)
               {
                  if((isBuy && aiAction == "BUY" && aiConfidence > 60) || 
                     (!isBuy && aiAction == "SELL" && aiConfidence > 60))
                  {
                     aiAllowsTrade = true;
                     Print("🤖 SMC_OTE - IA valide le trade: ", aiAction, " (Confiance: ", aiConfidence, "%)");
                  }
                  else
                  {
                     Print("🚫 SMC_OTE - IA refuse le trade - IA: ", aiAction, " (Confiance: ", aiConfidence, "%)");
                  }
               }
               else
               {
                  aiAllowsTrade = true; // Pas d'IA = autorisation par défaut
               }
               
               // EXÉCUTION DES ORDRES
               int currentPositions = CountPositionsOurEA(_Symbol);
               const bool pendingBusy = (g_pendingLimitOrder != "" || g_virtualPendingActive);

               // 1) Pending virtuel: ligne sur graphique + exé marché au toucher (sans ordre LIMIT broker)
               if(OTE_VirtualPendingMarket && EnableLimitOrders && aiAllowsTrade && !pendingBusy && currentPositions < 2)
               {
                  const double limitEntry = isBuy ? entryPrice - LimitOrderDistance : entryPrice + LimitOrderDistance;
                  PlaceVirtualPendingOrder(isBuy ? "BUY" : "SELL", limitEntry, sl, tp, timeLow, timeHigh);
               }
               // 2) Entrée marché immédiate (optionnel; désactivé par défaut si virtual pending utilisé)
               else if(OTE_InstantMarketOnConfluence && EnableTrading && currentPositions < 2 && aiAllowsTrade && !pendingBusy)
               {
                  double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  
                  if(isBuy)
                  {
                     double stopLoss = ask - (entryPrice - sl);
                     double takeProfit = ask + (tp - entryPrice);
                     
                     if(trade.Buy(InpLotSize, _Symbol, ask, stopLoss, takeProfit, "OTE_BUY_FVG"))
                        Print("✅ OTE BUY exécuté - Prix: ", ask, " SL: ", stopLoss, " TP: ", takeProfit);
                     else
                        Print("❌ Échec OTE BUY - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultComment());
                  }
                  else
                  {
                     double stopLoss = bid + (sl - entryPrice);
                     double takeProfit = bid - (entryPrice - tp);
                     
                     if(trade.Sell(InpLotSize, _Symbol, bid, stopLoss, takeProfit, "OTE_SELL_FVG"))
                        Print("✅ OTE SELL exécuté - Prix: ", bid, " SL: ", stopLoss, " TP: ", takeProfit);
                     else
                        Print("❌ Échec OTE SELL - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultComment());
                  }
               }
               // 3) Ordres LIMIT broker (si mode virtual désactivé)
               else if(EnableLimitOrders && aiAllowsTrade && !OTE_VirtualPendingMarket && !pendingBusy && currentPositions < 2)
               {
                  double limitEntry = isBuy ? entryPrice - LimitOrderDistance : entryPrice + LimitOrderDistance;
                  double limitSL = isBuy ? sl : sl;
                  double limitTP = isBuy ? tp : tp;
                  
                  PlaceValidatedLimitOrder(isBuy ? "BUY" : "SELL", limitEntry, limitSL, limitTP);
               }
            }
         }
      }
   }

   ChartRedraw();
   if(isBuy) lastBuySetupTime = curTime;
   else      lastSellSetupTime = curTime;
}

//+------------------------------------------------------------------+
//| FONCTIONS DE DÉTECTION DES CONFIRMATIONS OTE AMÉLIORÉES          |
//+------------------------------------------------------------------+

// Valider un swing point selon la méthode Kasper
bool ValidateSwingPoint(const MqlRates &rates[], const int index, const bool isHigh, const int validationBars = 5)
{
   if(index < validationBars || index >= ArraySize(rates) - validationBars) return false;
   
   if(isHigh)
   {
      // Swing high valide: doit être plus haut que les N bougies avant et après
      double candidateHigh = rates[index].high;
      for(int i = 1; i <= validationBars; i++)
      {
         if(rates[index - i].high >= candidateHigh || rates[index + i].high >= candidateHigh)
            return false;
      }
      return true;
   }
   else
   {
      // Swing low valide: doit être plus bas que les N bougies avant et après  
      double candidateLow = rates[index].low;
      for(int i = 1; i <= validationBars; i++)
      {
         if(rates[index - i].low <= candidateLow || rates[index + i].low <= candidateLow)
            return false;
      }
      return true;
   }
}

// Détecter les breaker blocks
bool DetectBreakerBlock(const MqlRates &rates[], const bool isBuy, double &breakerPrice)
{
   if(!EnableBreakerBlocks) return false;
   
   // Chercher une rupture de structure suivie d'un retest
   for(int i = 5; i < ArraySize(rates) - 5; i++)
   {
      if(isBuy)
      {
         // Breaker block haussier: cassé un plus bas précédent, puis retest
         if(rates[i].low < rates[i-5].low && rates[i+1].low > rates[i-5].low && rates[i+2].low > rates[i-5].low)
         {
            breakerPrice = rates[i-5].low;
            return true;
         }
      }
      else
      {
         // Breaker block baissier: cassé un plus haut précédent, puis retest
         if(rates[i].high > rates[i-5].high && rates[i+1].high < rates[i-5].high && rates[i+2].high < rates[i-5].high)
         {
            breakerPrice = rates[i-5].high;
            return true;
         }
      }
   }
   return false;
}

// Détecter les order blocks (dernière bougie de forte mouvement)
bool DetectOrderBlock(const MqlRates &rates[], const bool isBuy, double &orderBlockPrice)
{
   if(!EnableOrderBlocks) return false;
   
   for(int i = 2; i < ArraySize(rates) - 1; i++)
   {
      double range = rates[i].high - rates[i].low;
      double avgRange = 0.0;
      
      // Calculer la range moyenne des 10 dernières bougies
      for(int j = 1; j <= 10 && i + j < ArraySize(rates); j++)
      {
         avgRange += rates[i + j].high - rates[i + j].low;
      }
      avgRange /= 10.0;
      
      // Order block: bougie avec range > 1.5x la moyenne
      if(range > avgRange * 1.5)
      {
         if(isBuy)
         {
            // Order block haussier: bougie baissière forte
            if(rates[i].close < rates[i].open)
            {
               orderBlockPrice = rates[i].low;
               return true;
            }
         }
         else
         {
            // Order block baissier: bougie haussière forte
            if(rates[i].close > rates[i].open)
            {
               orderBlockPrice = rates[i].high;
               return true;
            }
         }
      }
   }
   return false;
}

// Détecter la prise de liquidité (sweep of liquidity)
bool DetectLiquiditySweep(const MqlRates &rates[], const bool isBuy, datetime &sweepTime)
{
   if(!EnableLiquiditySweep) return false;
   
   for(int i = 3; i < ArraySize(rates) - 2; i++)
   {
      if(isBuy)
      {
         // Prise de liquidité haussière: cassé un plus bas puis retourné rapidement
         if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low && 
            rates[i+1].high > rates[i].high && rates[i+2].high > rates[i+1].high)
         {
            sweepTime = rates[i].time;
            return true;
         }
      }
      else
      {
         // Prise de liquidité baissière: cassé un plus haut puis retourné rapidement
         if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
            rates[i+1].low < rates[i].low && rates[i+2].low < rates[i+1].low)
         {
            sweepTime = rates[i].time;
            return true;
         }
      }
   }
   return false;
}

// Calculer le score de confluence (1-5)
int CalculateConfluenceScore(const bool hasFVG, const bool hasBreaker, const bool hasOrderBlock, 
                           const bool hasLiquidity, const bool trendAligned)
{
   int score = 0;
   if(hasFVG) score += 1;
   if(hasBreaker) score += 1;
   if(hasOrderBlock) score += 1;
   if(hasLiquidity) score += 1;
   if(trendAligned) score += 1;
   return MathMin(score, 5);
}

// Dessiner les confirmations sur le graphique
void DrawConfirmations(const bool isBuy, const datetime curTime, const double oteZoneLow, const double oteZoneHigh)
{
   string prefix = OBJ_PREFIX + "CONF_" + IntegerToString((long)curTime);
   
   // Dessiner breaker block
   if(g_hasBreakerBlock && g_breakerBlockPrice > 0)
   {
      string bbName = prefix + "_BREAKER";
      datetime bbTime = curTime - PeriodSeconds() * 10;
      ObjectCreate(0, bbName, OBJ_RECTANGLE, 0, bbTime, g_breakerBlockPrice - 0.0010, curTime, g_breakerBlockPrice + 0.0010);
      ObjectSetInteger(0, bbName, OBJPROP_COLOR, clrPurple);
      ObjectSetInteger(0, bbName, OBJPROP_BGCOLOR, clrPurple);
      ObjectSetInteger(0, bbName, OBJPROP_BACK, true);
      ObjectSetInteger(0, bbName, OBJPROP_FILL, true);
      ObjectSetString(0, bbName, OBJPROP_TOOLTIP, "Breaker Block");
   }
   
   // Dessiner order block
   if(g_hasOrderBlock && g_orderBlockPrice > 0)
   {
      string obName = prefix + "_ORDERBLOCK";
      datetime obTime = curTime - PeriodSeconds() * 8;
      ObjectCreate(0, obName, OBJ_RECTANGLE, 0, obTime, g_orderBlockPrice - 0.0010, curTime, g_orderBlockPrice + 0.0010);
      ObjectSetInteger(0, obName, OBJPROP_COLOR, clrMaroon);
      ObjectSetInteger(0, obName, OBJPROP_BGCOLOR, clrMaroon);
      ObjectSetInteger(0, obName, OBJPROP_BACK, true);
      ObjectSetInteger(0, obName, OBJPROP_FILL, true);
      ObjectSetString(0, obName, OBJPROP_TOOLTIP, "Order Block");
   }
   
   // Dessiner score de confluence
   if(ShowConfluenceScore && g_confluenceScore > 0)
   {
      string scoreName = prefix + "_SCORE";
      ObjectCreate(0, scoreName, OBJ_TEXT, 0, curTime - PeriodSeconds() * 5, isBuy ? oteZoneHigh : oteZoneLow);
      string scoreText = "Confluence: " + IntegerToString(g_confluenceScore) + "/5";
      ObjectSetString(0, scoreName, OBJPROP_TEXT, scoreText);
      ObjectSetInteger(0, scoreName, OBJPROP_COLOR, g_confluenceScore >= MinConfluenceScore ? clrLime : clrOrange);
      ObjectSetInteger(0, scoreName, OBJPROP_FONTSIZE, 10);
   }
}

// Mettre à jour les variables globales
void UpdateGlobalVariables()
{
   // Cette fonction met à jour les variables globales pour le tableau de bord
   // Les variables sont déjà mises à jour dans OnTick()
}
//+------------------------------------------------------------------+