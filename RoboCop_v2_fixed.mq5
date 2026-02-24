//+------------------------------------------------------------------+
//|                                                  RoboCop_v2_fixed.mq5 |
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
//                DÉCLARATIONS DES FONCTIONS
//===================================================================
int OnInit();
void OnDeinit(const int reason);
void OnTick();
void TestHealth();
void RequestDecisionFromAPI();
string BuildDecisionRequestJSON();
void ProcessApiResponse(string response_body);
void ExecuteTrade(string action, double lot_size, double sl, double tp);
int CountOpenPositions();
void ResetDailyProfit();
void CheckForNewDay();
void UpdateDailyProfit(double profit);
void CheckDailyTarget();
void ManageOpenPositions();
void ApplyTrailingStop(ulong ticket);
void ApplyBreakeven(ulong ticket);
bool IsTradingAllowed();
bool IsTradingHourAllowed();
double CalculateLotSize(double sl_price);
bool SendJsonPost(string endpoint, string json_body, string &response_str);
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);
void UpdateChartComment();
void TestForceTrade();

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

   // Tester la connexion avec le endpoint /health
   TestHealth();

   // Initialiser le compteur de profit journalier
   ResetDailyProfit();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Test de connexion avec endpoint /health                           |
//+------------------------------------------------------------------+
void TestHealth()
{
   Print("=== TEST DE CONNEXION AU SERVEUR ===");
   string resp;
   if(SendJsonPost("/health", "{}", resp))
   {
      Print("✅ Health OK : ", resp);
   }
   else
   {
      Print("❌ Health KO - Vérifiez la connexion et l'URL du serveur");
   }
   Print("=====================================");
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

   // Debug: afficher l'état actuel
   static datetime last_debug = 0;
   if(TimeCurrent() - last_debug >= 30) // Toutes les 30 secondes
   {
      int open_pos = CountOpenPositions();
      PrintFormat("DEBUG: Positions ouvertes=%d/%d, Temps depuis dernière décision=%d sec", 
                  open_pos, InpMaxOpenPos, (int)(TimeCurrent() - g_last_decision_time));
      last_debug = TimeCurrent();
   }

   // Conditions pour prendre une nouvelle décision
   // 1. Pas de position ouverte sur ce symbole
   // 2. Attendre au moins 60 secondes entre deux décisions
   int open_pos = CountOpenPositions();
   bool can_trade = open_pos < InpMaxOpenPos && TimeCurrent() - g_last_decision_time >= 60;
   
   PrintFormat("DEBUG: Condition de trading: %s (positions: %d/%d, temps: %d sec)", 
               can_trade ? "OK" : "NON", open_pos, InpMaxOpenPos, (int)(TimeCurrent() - g_last_decision_time));
   
   if(can_trade)
   {
      // Filtres de trading (horaire, etc.)
      if(!IsTradingAllowed())
      {
         Print("DEBUG: Filtre de trading bloquant");
         return;
      }
      
      Print("DEBUG: Lancement de la requête de décision...");
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
   
   if(SendJsonPost(API_DECISION, json_request, response_body))
   {
      g_last_api_response = response_body; // Stocker la réponse pour l'affichage
      ProcessApiResponse(response_body);
   }
   else
   {
      Print("Échec de la requête de décision");
   }
}

// Construit le JSON à envoyer au serveur
string BuildDecisionRequestJSON()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double rsi = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
   double ema_fast_m1 = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
   double ema_slow_m1 = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
   double ema_fast_h1 = iMA(_Symbol, PERIOD_H1, 9, 0, MODE_EMA, PRICE_CLOSE);
   double ema_slow_h1 = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
   
   // Créer le timestamp au format ISO 8601
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string timestamp = StringFormat("%04d-%02d-%02dT%02d:%02d:%02d", 
                                 dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
   
   string json = StringFormat("{"
                             "\"symbol\":\"%s\","
                             "\"bid\":%.5f,"
                             "\"ask\":%.5f,"
                             "\"rsi\":%.2f,"
                             "\"atr\":%.5f,"
                             "\"ema_fast_m1\":%.5f,"
                             "\"ema_slow_m1\":%.5f,"
                             "\"ema_fast_h1\":%.5f,"
                             "\"ema_slow_h1\":%.5f,"
                             "\"timestamp\":\"%s\""
                             "}",
                             _Symbol, bid, ask, rsi, atr, 
                             ema_fast_m1, ema_slow_m1, ema_fast_h1, ema_slow_h1, timestamp);
   
   return json;
}

// Traite la réponse JSON du serveur
void ProcessApiResponse(string response_body)
{
   // Debug: afficher la réponse brute
   Print("Réponse brute du serveur : ", response_body);
   
   // Parser manuellement le JSON (CJAVal est trop simplifié)
   string action = "hold";
   double confidence = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   
   // Extraire l'action
   int action_pos = StringFind(response_body, "\"action\":");
   if(action_pos >= 0)
   {
      int start = StringFind(response_body, "\"", action_pos + 9);
      int end = StringFind(response_body, "\"", start + 1);
      if(start >= 0 && end > start)
      {
         action = StringSubstr(response_body, start + 1, end - start - 1);
      }
   }
   
   // Extraire la confiance
   int conf_pos = StringFind(response_body, "\"confidence\":");
   if(conf_pos >= 0)
   {
      string conf_str = "";
      for(int i = conf_pos + 12; i < StringLen(response_body); i++)
      {
         string curr_char = StringSubstr(response_body, i, 1);
         if(curr_char == "," || curr_char == "}" || curr_char == " ") break;
         conf_str += curr_char;
      }
      confidence = StringToDouble(conf_str);
   }
   
   // Extraire le stop loss
   int sl_pos = StringFind(response_body, "\"stop_loss\":");
   if(sl_pos >= 0)
   {
      string sl_str = "";
      for(int i = sl_pos + 12; i < StringLen(response_body); i++)
      {
         string curr_char = StringSubstr(response_body, i, 1);
         if(curr_char == "," || curr_char == "}" || curr_char == " ") break;
         sl_str += curr_char;
      }
      sl = StringToDouble(sl_str);
   }
   
   // Extraire le take profit
   int tp_pos = StringFind(response_body, "\"take_profit\":");
   if(tp_pos >= 0)
   {
      string tp_str = "";
      for(int i = tp_pos + 14; i < StringLen(response_body); i++)
      {
         string curr_char = StringSubstr(response_body, i, 1);
         if(curr_char == "," || curr_char == "}" || curr_char == " ") break;
         tp_str += curr_char;
      }
      tp = StringToDouble(tp_str);
   }

   PrintFormat("Décision parsée : Action=%s, Confiance=%.2f, SL=%.5f, TP=%.5f", action, confidence, sl, tp);

   if(action != "hold" && confidence >= 0.65) // Seuil de confiance pour trader
   {
      double lot_size = CalculateLotSize(sl);
      ExecuteTrade(action, lot_size, sl, tp);
   }
   else
   {
      Print("Pas de trade : action = hold ou confiance < 65%");
   }
}

//===================================================================
//                SECTION 4 : GESTION DES TRADES
//===================================================================
void ExecuteTrade(string action, double lot_size, double sl, double tp)
{
   PrintFormat("DEBUG: Tentative d'exécution de trade - Action: %s, Lot: %.2f, SL: %.5f, TP: %.5f", 
               action, lot_size, sl, tp);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {0};
   
   ENUM_ORDER_TYPE order_type = (action == "buy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   PrintFormat("DEBUG: Prix d'entrée: %.5f, Type: %s", price, EnumToString(order_type));
   
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
   
   // Vérifications avant l'envoi
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("ERREUR: Trading non autorisé dans le terminal!");
      return;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      Print("ERREUR: Trading non autorisé pour ce compte!");
      return;
   }
   
   if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL)
   {
      Print("ERREUR: Trading non autorisé pour ce symbole!");
      return;
   }
   
   Print("DEBUG: Envoi de l'ordre...");
   if(!OrderSend(request, result))
   {
      PrintFormat("ERREUR OrderSend : %d - %s", result.retcode, result.comment);
   }
   else
   {
      PrintFormat("✅ Ordre exécuté avec succès. Ticket : %d", result.order);
   }
}

//+------------------------------------------------------------------+
//| Fonction de test pour forcer un trade (debug)                    |
//+------------------------------------------------------------------+
void TestForceTrade()
{
   Print("=== TEST FORCAGE TRADE ===");
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = current_price - 100 * _Point;
   double tp = current_price + 200 * _Point;
   
   ExecuteTrade("buy", 0.01, sl, tp);
   Print("========================");
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

//+------------------------------------------------------------------+
//| Envoi POST JSON robuste vers Render                              |
//+------------------------------------------------------------------+
bool SendJsonPost(string endpoint, string json_body, string &response_str)
{
   string servers[] = {g_server_url, InpRenderURL};
   string server_names[] = {g_current_server_name, "Render"};
   
   for(int s = 0; s < ArraySize(servers); s++)
   {
      string full_url = servers[s] + endpoint;
      char post_data[], result_data[];
      string result_headers = "";

      // Conversion correcte en tableau d'octets
      StringToCharArray(json_body, post_data, 0, StringLen(json_body));

      Print("Envoi vers : ", full_url);
      Print("Body JSON : ", json_body);

      int http_code = WebRequest("POST",
                                full_url,
                                "Content-Type: application/json\r\n"
                                "Accept: application/json\r\n"
                                "Connection: close\r\n",
                                NULL,
                                15000,               // timeout 15s
                                post_data,
                                ArraySize(post_data)-1,
                                result_data,
                                result_headers);

      if(http_code == 200)
      {
         response_str = CharArrayToString(result_data, 0, WHOLE_ARRAY, CP_UTF8);
         Print("✅ Connexion réussie au serveur ", server_names[s]);
         Print("Réponse HTTP : ", http_code);
         Print("Body réponse : ", response_str);
         
         // Si on utilise le serveur de fallback, mettre à jour l'URL globale
         if(s > 0)
         {
            g_server_url = servers[s];
            g_current_server_name = server_names[s];
            PrintFormat("🔄 Basculement automatique vers le serveur %s", server_names[s]);
         }
         return true;
      }
      else if(http_code == 422)
      {
         response_str = CharArrayToString(result_data, 0, WHOLE_ARRAY, CP_UTF8);
         Print("Erreur 422 → Problème de validation Pydantic côté serveur");
         Print("Body réponse : ", response_str);
         Print("Vérifiez que le JSON envoyé correspond exactement au modèle DecisionRequest");
         return false; // 422 est une erreur de format, pas de connexion
      }
      else
      {
         PrintFormat("❌ Échec HTTP %d avec serveur %s - Erreur Win32 : %d", http_code, server_names[s], GetLastError());
         
         // Si le serveur actuel a échoué et il y a un fallback, essayer le suivant
         if(s < ArraySize(servers) - 1)
         {
            PrintFormat("🔄 Basculement vers le serveur %s...", server_names[s + 1]);
            continue;
         }
         else
         {
            Print("❌ Échec de tous les serveurs");
            return false;
         }
      }
   }
   
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
    
    // Construire le JSON pour le feedback avec timestamp
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    string timestamp = StringFormat("%04d-%02d-%02dT%02d:%02d:%02d", 
                                 dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
    
    string feedback_json = StringFormat("{"
                                    "\"symbol\":\"%s\","
                                    "\"profit\":%.2f,"
                                    "\"is_win\":%s,"
                                    "\"timestamp\":\"%s\""
                                    "}",
                                    _Symbol, profit, profit > 0 ? "true" : "false", timestamp);
    
    string response_body;

    // Envoyer le feedback au serveur (sans se soucier de la réponse)
    SendJsonPost(API_FEEDBACK, feedback_json, response_body);
    PrintFormat("Feedback envoyé au serveur : Profit = %.2f", profit);
}

//===================================================================
//                SECTION 9 : AFFICHAGE GRAPHIQUE
//===================================================================
void UpdateChartComment()
{
   string comment = "=== ROBOCOP v2.0 ===\n";
   comment += StringFormat("Serveur : %s\n", g_current_server_name);
   comment += StringFormat("Serveur URL : %s\n", g_server_url);
   comment += StringFormat("Objectif Journalier : %.2f / %.2f %s\n", g_daily_profit, InpDailyProfitTarget, AccountInfoString(ACCOUNT_CURRENCY));
   comment += StringFormat("Positions Ouvertes : %d / %d\n", CountOpenPositions(), InpMaxOpenPos);
   comment += "Dernière Réponse API :\n";
   comment += StringSubstr(g_last_api_response, 0, 100); // Affiche les 100 premiers caractères

   Comment(comment);
}
