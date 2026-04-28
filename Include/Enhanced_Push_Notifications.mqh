//+------------------------------------------------------------------+
//| Enhanced_Push_Notifications.mqh                                   |
//| Notifications enrichies avec données économiques automatiques     |
//+------------------------------------------------------------------+
#property copyright "TradBOT 2026"
#property link      "https://github.com/yourusername/tradbot"
#property version   "1.10"
#property strict

//+------------------------------------------------------------------+
//| PARAMÈTRES                                                       |
//+------------------------------------------------------------------+

input group "=== NOTIFICATIONS ENRICHIES ==="
input bool   EnhancedNotificationsEnabled = true;    // Activer notifications enrichies
input bool   AutoAddEconomicData = true;             // Ajouter auto données économiques
input bool   OnlyHighImpactInNotifs = false;         // Seulement événements HIGH impact
input bool   AddMarketSentiment = true;              // Ajouter sentiment de marché
input int    EconomicDataCacheDuration = 300;        // Durée cache données éco (secondes)

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+

struct EconomicDataCache
{
   string tickerText;
   string sentiment;          // "RISK_ON", "RISK_OFF", "NEUTRAL"
   double impactScore;        // 0-100
   datetime lastUpdate;
   bool hasHighImpactEvent;
   string nextEventTime;
   string nextEventTitle;
};

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+

EconomicDataCache g_economicCache;
datetime g_lastEconomicFetch = 0;

//+------------------------------------------------------------------+
//| Récupérer données économiques depuis l'API                       |
//+------------------------------------------------------------------+
bool FetchEconomicData(const string symbol, EconomicDataCache &cache)
{
   // Vérifier cache
   datetime now = TimeCurrent();
   if(now - g_lastEconomicFetch < EconomicDataCacheDuration && cache.tickerText != "")
   {
      return true; // Utiliser cache
   }

   string url = "http://localhost:8000/economic/news/ticker?symbol=" + symbol;

   char post[], result[];
   string headers;
   int timeout = 5000;

   int res = WebRequest("GET", url, "", NULL, timeout, post, 0, result, headers);

   if(res != 200)
   {
      Print("⚠️ API économique indisponible (", res, ")");
      cache.tickerText = "📊 Données économiques temporairement indisponibles";
      cache.sentiment = "NEUTRAL";
      cache.impactScore = 0;
      cache.hasHighImpactEvent = false;
      return false;
   }

   // Parser JSON
   string json = CharArrayToString(result);

   // Extraire ticker_text
   int startPos = StringFind(json, "\"ticker_text\":");
   if(startPos >= 0)
   {
      startPos = StringFind(json, "\"", startPos + 15);
      int endPos = StringFind(json, "\"", startPos + 1);

      if(startPos >= 0 && endPos > startPos)
      {
         cache.tickerText = StringSubstr(json, startPos + 1, endPos - startPos - 1);

         // Détecter présence HIGH impact
         cache.hasHighImpactEvent = (StringFind(cache.tickerText, "[HIGH]") >= 0);

         // Extraire sentiment du marché (basé sur mots-clés)
         if(StringFind(cache.tickerText, "Fed") >= 0 || StringFind(cache.tickerText, "inflation") >= 0)
         {
            cache.sentiment = "RISK_OFF";
            cache.impactScore = 80;
         }
         else if(StringFind(cache.tickerText, "GDP") >= 0 || StringFind(cache.tickerText, "Emploi") >= 0)
         {
            cache.sentiment = "RISK_ON";
            cache.impactScore = 65;
         }
         else if(StringFind(cache.tickerText, "[HIGH]") >= 0)
         {
            cache.sentiment = "RISK_OFF";
            cache.impactScore = 75;
         }
         else
         {
            cache.sentiment = "NEUTRAL";
            cache.impactScore = 30;
         }

         cache.lastUpdate = now;
         g_lastEconomicFetch = now;

         return true;
      }
   }

   // Fallback
   cache.tickerText = "📰 Pas d'événements économiques majeurs actuellement";
   cache.sentiment = "NEUTRAL";
   cache.impactScore = 0;
   cache.hasHighImpactEvent = false;

   return false;
}

//+------------------------------------------------------------------+
//| Formater données économiques pour notification                   |
//+------------------------------------------------------------------+
string FormatEconomicDataForNotification(const EconomicDataCache &cache, bool compact = true)
{
   if(!AutoAddEconomicData) return "";

   // Si seulement HIGH impact et pas d'événement HIGH, ne rien ajouter
   if(OnlyHighImpactInNotifs && !cache.hasHighImpactEvent)
      return "";

   string economicText = "\n\n"; // Séparer de l'analyse technique

   if(compact)
   {
      // Version compacte pour notifications courtes
      if(cache.hasHighImpactEvent)
      {
         economicText += "📢 HIGH IMPACT: ";

         // Extraire seulement l'événement HIGH
         int highPos = StringFind(cache.tickerText, "[HIGH]");
         if(highPos >= 0)
         {
            // Prendre 50 caractères autour de [HIGH]
            int startPos = MathMax(0, highPos - 20);
            int length = MathMin(70, StringLen(cache.tickerText) - startPos);
            economicText += StringSubstr(cache.tickerText, startPos, length);
         }
         else
         {
            economicText += StringSubstr(cache.tickerText, 0, 70);
         }
      }
      else
      {
         // Version courte du ticker
         if(StringLen(cache.tickerText) > 80)
            economicText += "📰 " + StringSubstr(cache.tickerText, 0, 77) + "...";
         else
            economicText += "📰 " + cache.tickerText;
      }
   }
   else
   {
      // Version complète
      economicText += "📊 CONTEXTE ÉCONOMIQUE:\n";
      economicText += cache.tickerText;

      if(AddMarketSentiment && cache.sentiment != "NEUTRAL")
      {
         economicText += "\n\n";
         if(cache.sentiment == "RISK_ON")
            economicText += "🟢 Sentiment: RISK ON (Appétit pour le risque)";
         else if(cache.sentiment == "RISK_OFF")
            economicText += "🔴 Sentiment: RISK OFF (Aversion au risque)";

         economicText += "\n💪 Impact: " + DoubleToString(cache.impactScore, 0) + "/100";
      }
   }

   return economicText;
}

//+------------------------------------------------------------------+
//| Fonction principale: SendNotification enrichie                   |
//+------------------------------------------------------------------+
bool SendEnhancedNotification(const string technicalMessage, const string symbol = "", bool forceCompact = true)
{
   if(!EnhancedNotificationsEnabled)
   {
      // Fallback vers notification standard
      return SendNotification(technicalMessage);
   }

   // Utiliser symbole courant si non spécifié
   string targetSymbol = (symbol == "") ? _Symbol : symbol;

   // Récupérer données économiques
   FetchEconomicData(targetSymbol, g_economicCache);

   // Formater message enrichi
   string enrichedMessage = technicalMessage;

   // Ajouter données économiques
   string economicPart = FormatEconomicDataForNotification(g_economicCache, forceCompact);
   if(economicPart != "")
   {
      enrichedMessage += economicPart;
   }

   // Limiter à 256 caractères max pour compatibilité MT5
   if(StringLen(enrichedMessage) > 256)
   {
      enrichedMessage = StringSubstr(enrichedMessage, 0, 253) + "...";
   }

   // Envoyer notification
   bool success = SendNotification(enrichedMessage);

   if(success)
   {
      Print("✅ Notification enrichie envoyée (", StringLen(enrichedMessage), " car.)");
   }
   else
   {
      Print("❌ Échec notification enrichie");
   }

   return success;
}

//+------------------------------------------------------------------+
//| Version avec analyse technique complète                         |
//+------------------------------------------------------------------+
bool SendFullAnalysisNotification(
   const string signal,        // "BUY", "SELL", "NEUTRAL"
   const string concept,        // "FVG", "OTE", "Break of Structure", etc.
   const double entryPrice,
   const double stopLoss,
   const double takeProfit,
   const double confidence = 0,
   const string symbol = ""
)
{
   string targetSymbol = (symbol == "") ? _Symbol : symbol;
   int digits = (int)SymbolInfoInteger(targetSymbol, SYMBOL_DIGITS);

   // Icône selon signal
   string icon = "⚪";
   if(signal == "BUY") icon = "🟢";
   else if(signal == "SELL") icon = "🔴";

   // Construire message technique
   string message = icon + " " + signal + " " + targetSymbol;

   if(concept != "")
      message += "\n📐 " + concept;

   message += "\n💰 Entry: " + DoubleToString(entryPrice, digits);
   message += "\n🛑 SL: " + DoubleToString(stopLoss, digits);
   message += "\n🎯 TP: " + DoubleToString(takeProfit, digits);

   if(confidence > 0)
      message += "\n📊 Conf: " + DoubleToString(confidence * 100, 1) + "%";

   // Calculer RR
   double risk = MathAbs(entryPrice - stopLoss);
   double reward = MathAbs(takeProfit - entryPrice);
   if(risk > 0)
   {
      double rr = reward / risk;
      message += "\n⚖️ RR: 1:" + DoubleToString(rr, 1);
   }

   // Envoyer avec enrichissement économique
   return SendEnhancedNotification(message, targetSymbol, true);
}

//+------------------------------------------------------------------+
//| Notification de trade exécuté                                    |
//+------------------------------------------------------------------+
bool SendTradeExecutedNotification(
   const string action,        // "OPENED", "CLOSED", "MODIFIED"
   const string type,          // "BUY", "SELL"
   const double price,
   const double volume,
   const double profitLoss = 0,
   const string reason = "",
   const string symbol = ""
)
{
   string targetSymbol = (symbol == "") ? _Symbol : symbol;
   int digits = (int)SymbolInfoInteger(targetSymbol, SYMBOL_DIGITS);

   string icon = "⚪";
   if(action == "OPENED")
   {
      icon = (type == "BUY") ? "🟢" : "🔴";
   }
   else if(action == "CLOSED")
   {
      icon = (profitLoss >= 0) ? "✅" : "❌";
   }
   else if(action == "MODIFIED")
   {
      icon = "🔧";
   }

   string message = icon + " " + action + " " + type + " " + targetSymbol;
   message += "\n💰 " + DoubleToString(price, digits);
   message += " | Lot: " + DoubleToString(volume, 2);

   if(action == "CLOSED" && profitLoss != 0)
   {
      message += "\n💵 P/L: " + DoubleToString(profitLoss, 2) + "$";
   }

   if(reason != "")
   {
      message += "\n📝 " + reason;
   }

   // Version compacte pour trades
   return SendEnhancedNotification(message, targetSymbol, true);
}

//+------------------------------------------------------------------+
//| Obtenir résumé économique actuel (pour debug/logs)              |
//+------------------------------------------------------------------+
string GetCurrentEconomicSummary(const string symbol = "")
{
   string targetSymbol = (symbol == "") ? _Symbol : symbol;
   FetchEconomicData(targetSymbol, g_economicCache);

   string summary = "=== RÉSUMÉ ÉCONOMIQUE ===\n";
   summary += "Symbole: " + targetSymbol + "\n";
   summary += "Sentiment: " + g_economicCache.sentiment + "\n";
   summary += "Impact: " + DoubleToString(g_economicCache.impactScore, 0) + "/100\n";
   summary += "HIGH Impact Event: " + (g_economicCache.hasHighImpactEvent ? "OUI" : "NON") + "\n";
   summary += "Dernière MAJ: " + TimeToString(g_economicCache.lastUpdate) + "\n";
   summary += "\nTicker:\n" + g_economicCache.tickerText + "\n";

   return summary;
}

//+------------------------------------------------------------------+
//| Initialisation du module                                        |
//+------------------------------------------------------------------+
void InitEnhancedNotifications()
{
   if(!EnhancedNotificationsEnabled)
   {
      Print("ℹ️ Notifications enrichies désactivées");
      return;
   }

   Print("✅ Module notifications enrichies initialisé");
   Print("   📊 Ajout auto données économiques: ", AutoAddEconomicData ? "OUI" : "NON");
   Print("   📢 Seulement HIGH impact: ", OnlyHighImpactInNotifs ? "OUI" : "NON");
   Print("   💭 Sentiment de marché: ", AddMarketSentiment ? "OUI" : "NON");
   Print("   ⏱️ Cache: ", EconomicDataCacheDuration, " secondes");

   // Initialiser cache
   g_economicCache.tickerText = "";
   g_economicCache.sentiment = "NEUTRAL";
   g_economicCache.impactScore = 0;
   g_economicCache.lastUpdate = 0;
   g_economicCache.hasHighImpactEvent = false;
   g_lastEconomicFetch = 0;

   // Premier fetch pour remplir le cache
   FetchEconomicData(_Symbol, g_economicCache);

   Print("📰 Cache économique initial: ",
         g_economicCache.hasHighImpactEvent ? "HIGH IMPACT détecté" : "Normal");
}

//+------------------------------------------------------------------+
//| Test unitaire (optionnel)                                        |
//+------------------------------------------------------------------+
void TestEnhancedNotifications()
{
   Print("\n=== TEST NOTIFICATIONS ENRICHIES ===");

   // Test 1: Notification simple
   SendEnhancedNotification("🔔 Test notification simple", _Symbol, true);

   Sleep(1000);

   // Test 2: Notification analyse complète
   SendFullAnalysisNotification("BUY", "OTE Entry", 1.2345, 1.2300, 1.2400, 0.85, _Symbol);

   Sleep(1000);

   // Test 3: Notification trade exécuté
   SendTradeExecutedNotification("OPENED", "BUY", 1.2345, 0.1, 0, "FVG Bullish", _Symbol);

   Sleep(1000);

   // Test 4: Afficher résumé économique
   Print(GetCurrentEconomicSummary(_Symbol));

   Print("=== FIN TESTS ===\n");
}
