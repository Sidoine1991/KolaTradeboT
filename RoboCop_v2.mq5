//+------------------------------------------------------------------+
//|                                                  RoboCop_v2.mq5 |
//|                             Copyright 2025, Sidoine & Grok/xAI |
//|                                          https://x.ai/         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Sidoine & Grok/xAI"
#property link      "https://x.ai"
#property version   "2.00"
#property strict
#property description "RoboCop v2 - Robot de trading IA avec communication robuste et gestion d'objectif journalier."

//--- Inclure la bibliothèque pour le parsing JSON
#include <CJAVal.mqh> 

//===================================================================
//                PARAMÈTRES D'ENTRÉE
//===================================================================
input group "Configuration Serveur"
input bool   InpUseLocalServer  = true;                               // Utiliser le serveur local (http://localhost:8000)
input string InpRenderURL       = "https://kolatradebot.onrender.com";  // URL de votre serveur sur Render
input int    InpMaxRetries      = 3;                                  // Nombre de tentatives de reconnexion
input int    InpRetryDelay      = 5000;                               // Délai entre les tentatives (ms)

input group "Gestion des Trades"
input int    InpMagicNumber     = 198420;                             // Numéro magique unique
input double InpRiskPercent     = 1.0;                                // Pourcentage du capital à risquer (0 = lot fixe)
input double InpFixedLot        = 0.01;                               // Lot fixe si InpRiskPercent = 0
input int    InpSlippage        = 5;                                  // Slippage maximum en points

input group "Objectif de Gain Journalier"
input bool   InpUseDailyProfitTarget = true;                          // Activer l'objectif de profit journalier ?
input double InpDailyProfitTarget    = 50.0;                          // Objectif de profit journalier en devise du compte ($)

input group "Gestion des Positions"
input int    InpMaxOpenPos      = 2;                                  // Nombre maximum de positions ouvertes
input bool   InpUseTrailingStop = true;                               // Activer le Trailing Stop ?
input int    InpTrailingStartPts= 250;                                // Points de déclenchement du Trailing
input int    InpTrailingStepPts = 100;                                // Pas du Trailing Stop
input bool   InpUseBreakeven    = true;                               // Activer le Breakeven ?
input int    InpBreakevenTrigger= 180;                                // Points pour déclencher le Breakeven
input int    InpBreakevenOffset = 40;                                 // Marge de sécurité pour le Breakeven

input group "Filtres de Trading"
input bool   InpHourFilter      = false;                              // Activer le filtre horaire ?
input string InpAllowedHours    = "8-11,14-17";                       // Heures autorisées (fuseau horaire du broker)


//===================================================================
//                CONSTANTES ET VARIABLES GLOBALES
//===================================================================
#define API_DECISION "/decision"
#define API_FEEDBACK "/trades/feedback"

//--- Variables globales
string   g_server_url;
string   g_current_server_name = "Local";
datetime g_last_decision_time = 0;
string   g_last_api_response = "";
double   g_daily_profit = 0;
int      g_last_day_check = 0;
bool     g_daily_target_reached = false;

//===================================================================
//                SECTION 1 : INITIALISATION ET DÉINITIALISATION
//===================================================================
int OnInit()
{
   Print(" ");
   Print("+------------------------------------------------------------------+");
   Print("|                    ROBOCOP v2.0 - DÉMARRAGE                      |");
   Print("+------------------------------------------------------------------+");
   
   // Déterminer l'URL du serveur à utiliser
   g_server_url = InpUseLocalServer ? "http://localhost:8000" : InpRenderURL;
   
   PrintFormat("Serveur cible : %s", g_server_url);
   PrintFormat("Symbole : %s", _Symbol);
   PrintFormat("Numéro Magique : %d", InpMagicNumber);
   PrintFormat("Objectif de profit journalier : %s (%.2f %s)", 
               InpUseDailyProfitTarget ? "Activé" : "Désactivé", 
               InpDailyProfitTarget, AccountInfoString(ACCOUNT_CURRENCY));

   // Initialiser le compteur de profit journalier
   ResetDailyProfit();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   PrintFormat("RoboCop v2.0 arrêté. Raison : %d", reason);
   Comment("");
}

//===================================================================
//                SECTION 2 : LOGIQUE PRINCIPALE - OnTick()
//===================================================================
void OnTick()
{
   // Vérifier si un nouveau jour a commencé pour réinitialiser l'objectif
   CheckForNewDay();

   // Si l'objectif journalier est atteint, on arrête de trader
   if(g_daily_target_reached)
   {
      Comment(StringFormat("Objectif journalier de %.2f %s atteint.\nTrading en pause jusqu'à demain.",
                           InpDailyProfitTarget, AccountInfoString(ACCOUNT_CURRENCY)));
      return;
   }

   // Gérer les positions existantes (Trailing Stop, Breakeven)
   ManageOpenPositions();

   // Conditions pour prendre une nouvelle décision
   // 1. Pas de position ouverte sur ce symbole
   // 2. Attendre au moins 60 secondes entre deux décisions
   if(CountOpenPositions() < InpMaxOpenPos && TimeCurrent() - g_last_decision_time >= 60)
   {
      // Filtres de trading (horaire, etc.)
      if(!IsTradingAllowed())
      {
         return;
      }
      
      g_last_decision_time = TimeCurrent();
      RequestDecisionFromAPI();
   }
   
   // Mettre à jour l'affichage sur le graphique
   UpdateChartComment();
}

//===================================================================
//          SECTION 3 : COMMUNICATION AVEC LE SERVEUR IA
//===================================================================
void RequestDecisionFromAPI()
{
   string json_request = BuildDecisionRequestJSON();
   string response_body = "";
   
   if(SendWebRequest("POST", API_DECISION, json_request, response_body))
   {
      g_last_api_response = response_body; // Stocker la réponse pour l'affichage
      ProcessApiResponse(response_body);
   }
}

// Construit le JSON à envoyer au serveur
string BuildDecisionRequestJSON()
{
   // Utilisation de la bibliothèque CJAVal pour créer le JSON
   CJAVal json;
   json["symbol"].SetStr(_Symbol);
   json["bid"].SetDbl(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   json["ask"].SetDbl(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   json["rsi"].SetDbl(iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE));
   json["atr"].SetDbl(iATR(_Symbol, PERIOD_CURRENT, 14));
   
   // Indicateurs multi-timeframe
   json["ema_fast_m1"].SetDbl(iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE));
   json["ema_slow_m1"].SetDbl(iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE));
   json["ema_fast_h1"].SetDbl(iMA(_Symbol, PERIOD_H1, 9, 0, MODE_EMA, PRICE_CLOSE));
   json["ema_slow_h1"].SetDbl(iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE));

   return json.Serialize();
}

// Traite la réponse JSON du serveur
void ProcessApiResponse(string response_body)
{
   CJAVal json_response;
   if(!json_response.Deserialize(response_body))
   {
      Print("Erreur : Impossible de parser la réponse JSON du serveur.");
      return;
   }

   string action = json_response["action"].GetStr();
   double confidence = json_response["confidence"].GetDbl();
   double sl = json_response["stop_loss"].GetDbl();
   double tp = json_response["take_profit"].GetDbl();

   PrintFormat("Décision reçue : Action=%s, Confiance=%.2f, SL=%.5f, TP=%.5f", action, confidence, sl, tp);

   if(action != "hold" && confidence >= 0.65) // Seuil de confiance pour trader
   {
      double lot_size = CalculateLotSize(sl);
      ExecuteTrade(action, lot_size, sl, tp);
   }
}

//===================================================================
//                SECTION 4 : GESTION DES TRADES
//===================================================================
void ExecuteTrade(string action, double lot_size, double sl, double tp)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {0};
   
   ENUM_ORDER_TYPE order_type = (action == "buy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot_size;
   request.type = order_type;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = InpSlippage;
   request.magic = InpMagicNumber;
   request.comment = "RoboCop v2 AI";
   
   if(!OrderSend(request, result))
   {
      PrintFormat("Erreur OrderSend : %d - %s", result.retcode, result.comment);
   }
   else
   {
      PrintFormat("Ordre exécuté avec succès. Ticket : %d", result.order);
   }
}

// Compte les positions ouvertes par ce robot sur le symbole actuel
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         count++;
      }
   }
   return count;
}

//===================================================================
//       SECTION 5 : OBJECTIF JOURNALIER & GESTION DU TEMPS
//===================================================================
// Réinitialise le profit journalier et l'état de l'objectif
void ResetDailyProfit()
{
   g_daily_profit = 0;
   g_last_day_check = (int)TimeCurrent() / 86400;
   g_daily_target_reached = false;
   
   // Calculer le profit de la journée en cours au démarrage
   HistorySelect(TimeCurrent() - 86400, TimeCurrent());
   for(int i=0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         // S'assurer que le deal a été fermé aujourd'hui
         if(HistoryDealGetInteger(ticket, DEAL_TIME) / 86400 == g_last_day_check)
         {
            g_daily_profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         }
      }
   }
   PrintFormat("Profit initial pour aujourd'hui : %.2f %s", g_daily_profit, AccountInfoString(ACCOUNT_CURRENCY));
   CheckDailyTarget();
}

// Vérifie si un nouveau jour a commencé
void CheckForNewDay()
{
   int current_day = (int)TimeCurrent() / 86400;
   if(current_day != g_last_day_check)
   {
      Print("Nouveau jour détecté. Réinitialisation de l'objectif de profit journalier.");
      ResetDailyProfit();
   }
}

// Met à jour le profit journalier et vérifie si l'objectif est atteint
void UpdateDailyProfit(double profit)
{
   if(!InpUseDailyProfitTarget) return;

   g_daily_profit += profit;
   CheckDailyTarget();
}

void CheckDailyTarget()
{
    if(InpUseDailyProfitTarget && g_daily_profit >= InpDailyProfitTarget)
   {
      g_daily_target_reached = true;
      PrintFormat("OBJECTIF ATTEINT ! Profit journalier de %.2f %s. Le trading est mis en pause.", g_daily_profit, AccountInfoString(ACCOUNT_CURRENCY));
   }
}

//===================================================================
//                SECTION 6 : GESTION DES POSITIONS ACTIVES
//===================================================================
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         if(InpUseTrailingStop) ApplyTrailingStop(ticket);
         if(InpUseBreakeven) ApplyBreakeven(ticket);
      }
   }
}

void ApplyTrailingStop(ulong ticket)
{
   // ... (implémentation du trailing stop)
}

void ApplyBreakeven(ulong ticket)
{
    // ... (implémentation du breakeven)
}

//===================================================================
//          SECTION 7 : FILTRES, CALCULS ET UTILITAIRES
//===================================================================
bool IsTradingAllowed()
{
   if(InpHourFilter && !IsTradingHourAllowed())
   {
      Comment("Trading en pause : En dehors des heures autorisées.");
      return false;
   }
   return true;
}

bool IsTradingHourAllowed()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int current_hour = dt.hour;
   
   string hours_array[];
   StringSplit(InpAllowedHours, ',', hours_array);
   
   for(int i = 0; i < ArraySize(hours_array); i++)
   {
      string range[];
      StringSplit(hours_array[i], '-', range);
      if(ArraySize(range) == 2)
      {
         int start_hour = (int)StringToInteger(range[0]);
         int end_hour = (int)StringToInteger(range[1]);
         if(current_hour >= start_hour && current_hour < end_hour)
         {
            return true;
         }
      }
   }
   return false;
}

double CalculateLotSize(double sl_price)
{
   if(InpRiskPercent <= 0 || sl_price == 0)
   {
      return InpFixedLot;
   }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = balance * InpRiskPercent / 100.0;
   
   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double risk_per_lot = MathAbs(entry_price - sl_price) * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);

   if(risk_per_lot <= 0) return InpFixedLot;
   
   double lots = risk_amount / risk_per_lot;
   
   // Normaliser le lot selon les règles du broker
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lots = MathRound(lots / step_lot) * step_lot;
   
   if(lots < min_lot) lots = min_lot;
   if(lots > max_lot) lots = max_lot;
   
   return NormalizeDouble(lots, 2);
}

// Wrapper pour WebRequest avec tentatives
bool SendWebRequest(string method, string endpoint, string data, string &response)
{
   string url = g_server_url + endpoint;
   string headers = "Content-Type: application/json\r\n";
   char response_data[];
   string result = "";
   
   // Essayer d'abord le serveur local, puis Render en fallback
   string servers[] = {g_server_url, InpRenderURL};
   string server_names[] = {"Local", "Render"};
   
   for(int s = 0; s < ArraySize(servers); s++)
   {
      url = servers[s] + endpoint;
      PrintFormat("Tentative de connexion au serveur %s : %s", server_names[s], url);
      
      for(int i = 0; i < InpMaxRetries; i++)
      {
         ResetLastError();
         int code = WebRequest(method, url, headers, 5000, data, response_data, headers, "application/json");
         
         if(code == 200)
         {
            response = CharArrayToString(response_data);
            PrintFormat(" Connexion réussie au serveur %s", server_names[s]);
            
            // Si on utilise le serveur de fallback, mettre à jour l'URL globale
            if(s > 0)
            {
               g_server_url = servers[s];
               g_current_server_name = server_names[s];
               PrintFormat("🔄 Basculement automatique vers le serveur %s", server_names[s]);
            }
            return true;
         }
         else
         {
            PrintFormat("Erreur WebRequest %s (tentative %d/%d) : Code %d", server_names[s], i + 1, InpMaxRetries, code);
            if(i < InpMaxRetries - 1) Sleep(InpRetryDelay);
         }
      }
      
      // Si le serveur actuel a échoué, essayer le suivant
      if(s < ArraySize(servers) - 1)
      {
         PrintFormat(" Échec du serveur %s, basculement vers %s...", server_names[s], server_names[s + 1]);
      }
   }
   
   Print(" Erreur critique : Échec de tous les serveurs.");
   return false;
}

//===================================================================
//       SECTION 8 : FEEDBACK LOOP - OnTradeTransaction
//===================================================================
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
    // On ne s'intéresse qu'aux trades qui sont fermés
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

    long deal_entry_type = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
    // DEAL_ENTRY_OUT signifie que c'est une transaction de clôture
    if(deal_entry_type != DEAL_ENTRY_OUT) return;

    // Vérifier si le deal a été fait par ce robot
    if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagicNumber) return;

    double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
    
    // Mettre à jour l'objectif de profit journalier
    UpdateDailyProfit(profit);
    
    // Construire le JSON pour le feedback
    CJAVal feedback_json;
    feedback_json["symbol"].SetStr(_Symbol);
    feedback_json["profit"].SetDbl(profit);
    feedback_json["is_win"].SetBool(profit > 0);
    
    string feedback_str = feedback_json.Serialize();
    string response_body;

    // Envoyer le feedback au serveur (sans se soucier de la réponse)
    SendWebRequest("POST", API_FEEDBACK, feedback_str, response_body);
    PrintFormat("Feedback envoyé au serveur : Profit = %.2f", profit);
}

//===================================================================
//                SECTION 9 : AFFICHAGE GRAPHIQUE
//===================================================================
void UpdateChartComment()
{
   string comment = StringFormat("=== ROBOCOP v2.0 ===\n");
   comment += StringFormat("Serveur : %s\n", g_current_server_name);
   comment += StringFormat("Serveur URL : %s\n", g_server_url);
   comment += StringFormat("Objectif Journalier : %.2f / %.2f %s\n", g_daily_profit, InpDailyProfitTarget, AccountInfoString(ACCOUNT_CURRENCY));
   comment += StringFormat("Positions Ouvertes : %d / %d\n", CountOpenPositions(), InpMaxOpenPos);
   comment += "Dernière Réponse API :\n";
   comment += StringSubstr(g_last_api_response, 0, 100); // Affiche les 100 premiers caractères

   Comment(comment);
}
