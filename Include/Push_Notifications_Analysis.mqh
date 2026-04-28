//+------------------------------------------------------------------+
//| Push_Notifications_Analysis.mqh                                   |
//| Notifications push combinant actualités économiques + analyse    |
//+------------------------------------------------------------------+
#property copyright "TradBOT 2026"
#property link      "https://github.com/yourusername/tradbot"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| PARAMÈTRES                                                       |
//+------------------------------------------------------------------+

input group "=== NOTIFICATIONS PUSH ANALYSE ==="
input bool   EnablePushNotifications = true;      // Activer notifications push
input int    PushNotificationInterval = 600;      // Intervalle (secondes) - 600 = 10 min
input bool   PushIncludeEconomicNews = true;      // Inclure actualités économiques
input bool   PushIncludeTechnicalAnalysis = true; // Inclure analyse technique
input bool   PushIncludeSignals = true;           // Inclure signaux trading
input bool   PushOnlyHighImpactNews = false;      // Seulement news HIGH impact

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+

datetime g_lastPushNotification = 0;

//+------------------------------------------------------------------+
//| Structure pour données d'analyse                                 |
//+------------------------------------------------------------------+

struct TechnicalAnalysisData
{
   string symbol;
   double currentPrice;
   string trend;              // "BULLISH", "BEARISH", "SIDEWAYS"
   double trendStrength;      // 0-100
   double rsi;
   double atr;
   double emaFast;
   double emaSlow;
   string signal;             // "BUY", "SELL", "NEUTRAL"
   double supportLevel;
   double resistanceLevel;
};

//+------------------------------------------------------------------+
//| Récupérer actualités économiques depuis API                      |
//+------------------------------------------------------------------+
bool FetchEconomicNewsForPush(const string symbol, string &newsText)
{
   string url = "http://localhost:8000/economic/news/ticker?symbol=" + symbol;

   char post[], result[];
   string headers;
   int timeout = 5000;

   int res = WebRequest("GET", url, "", NULL, timeout, post, 0, result, headers);

   if(res != 200)
   {
      newsText = "⚠️ Actualités indisponibles";
      return false;
   }

   // Parser JSON simple pour extraire ticker_text
   string json = CharArrayToString(result);
   int startPos = StringFind(json, "\"ticker_text\":");

   if(startPos >= 0)
   {
      startPos = StringFind(json, "\"", startPos + 15);
      int endPos = StringFind(json, "\"", startPos + 1);

      if(startPos >= 0 && endPos > startPos)
      {
         newsText = StringSubstr(json, startPos + 1, endPos - startPos - 1);

         // Si seulement HIGH impact demandé, filtrer
         if(PushOnlyHighImpactNews && StringFind(newsText, "[HIGH]") < 0)
         {
            newsText = "📊 Pas d'événements HIGH impact actuellement";
         }

         // Tronquer si trop long (notifications limitées à ~256 caractères)
         if(StringLen(newsText) > 200)
            newsText = StringSubstr(newsText, 0, 197) + "...";

         return true;
      }
   }

   newsText = "📰 Actualités en cours de chargement";
   return false;
}

//+------------------------------------------------------------------+
//| Analyser situation technique du symbole                          |
//+------------------------------------------------------------------+
void AnalyzeTechnicalSituation(const string symbol, TechnicalAnalysisData &data)
{
   data.symbol = symbol;
   data.currentPrice = (SymbolInfoDouble(symbol, SYMBOL_BID) + SymbolInfoDouble(symbol, SYMBOL_ASK)) / 2.0;

   // Calculer indicateurs
   double ema9[], ema21[], rsi[], atr[];
   int ema9H = iMA(symbol, PERIOD_M15, 9, 0, MODE_EMA, PRICE_CLOSE);
   int ema21H = iMA(symbol, PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE);
   int rsiH = iRSI(symbol, PERIOD_M15, 14, PRICE_CLOSE);
   int atrH = iATR(symbol, PERIOD_M15, 14);

   ArraySetAsSeries(ema9, true);
   ArraySetAsSeries(ema21, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);

   if(CopyBuffer(ema9H, 0, 0, 3, ema9) > 0 &&
      CopyBuffer(ema21H, 0, 0, 3, ema21) > 0 &&
      CopyBuffer(rsiH, 0, 0, 3, rsi) > 0 &&
      CopyBuffer(atrH, 0, 0, 3, atr) > 0)
   {
      data.emaFast = ema9[0];
      data.emaSlow = ema21[0];
      data.rsi = rsi[0];
      data.atr = atr[0];

      // Déterminer tendance
      if(ema9[0] > ema21[0] && data.currentPrice > ema9[0])
      {
         data.trend = "BULLISH";
         double gap = (ema9[0] - ema21[0]) / ema21[0] * 10000;
         data.trendStrength = MathMin(100, gap * 5);
      }
      else if(ema9[0] < ema21[0] && data.currentPrice < ema9[0])
      {
         data.trend = "BEARISH";
         double gap = (ema21[0] - ema9[0]) / ema21[0] * 10000;
         data.trendStrength = MathMin(100, gap * 5);
      }
      else
      {
         data.trend = "SIDEWAYS";
         data.trendStrength = 30.0;
      }

      // Déterminer signal
      if(data.trend == "BULLISH" && rsi[0] > 50 && rsi[0] < 70)
         data.signal = "BUY";
      else if(data.trend == "BEARISH" && rsi[0] < 50 && rsi[0] > 30)
         data.signal = "SELL";
      else
         data.signal = "NEUTRAL";

      // Calculer supports/résistances simples
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(symbol, PERIOD_M15, 0, 50, rates) > 0)
      {
         // Trouver highest et lowest manuellement
         double highest = rates[0].high;
         double lowest = rates[0].low;

         for(int i = 0; i < 20 && i < ArraySize(rates); i++)
         {
            if(rates[i].high > highest) highest = rates[i].high;
            if(rates[i].low < lowest) lowest = rates[i].low;
         }

         data.resistanceLevel = highest;
         data.supportLevel = lowest;
      }
   }
   else
   {
      data.trend = "UNKNOWN";
      data.trendStrength = 0;
      data.signal = "NEUTRAL";
      data.rsi = 50;
   }
}

//+------------------------------------------------------------------+
//| Formater message de notification                                 |
//+------------------------------------------------------------------+
string FormatPushNotificationMessage(const TechnicalAnalysisData &data, const string newsText)
{
   string message = "";

   // Header avec symbole et signal
   string signalIcon = "⚪";
   if(data.signal == "BUY") signalIcon = "🟢";
   else if(data.signal == "SELL") signalIcon = "🔴";

   message += signalIcon + " " + data.symbol + " | " + data.signal + "\n";

   // Analyse technique
   if(PushIncludeTechnicalAnalysis)
   {
      string trendIcon = "➡️";
      if(data.trend == "BULLISH") trendIcon = "📈";
      else if(data.trend == "BEARISH") trendIcon = "📉";

      message += trendIcon + " " + data.trend;
      message += " (" + DoubleToString(data.trendStrength, 0) + "%)\n";

      message += "💰 " + DoubleToString(data.currentPrice, (int)SymbolInfoInteger(data.symbol, SYMBOL_DIGITS));
      message += " | RSI " + DoubleToString(data.rsi, 1) + "\n";

      // Support/Resistance
      int digits = (int)SymbolInfoInteger(data.symbol, SYMBOL_DIGITS);
      message += "📍 S:" + DoubleToString(data.supportLevel, digits);
      message += " R:" + DoubleToString(data.resistanceLevel, digits) + "\n";
   }

   // Actualités économiques
   if(PushIncludeEconomicNews && newsText != "")
   {
      message += "\n📰 " + newsText;
   }

   return message;
}

//+------------------------------------------------------------------+
//| Envoyer notification push                                         |
//+------------------------------------------------------------------+
void SendPushAnalysisNotification()
{
   if(!EnablePushNotifications) return;

   datetime now = TimeCurrent();

   // Vérifier intervalle
   if(now - g_lastPushNotification < PushNotificationInterval)
      return;

   g_lastPushNotification = now;

   Print("📲 Envoi notification push analyse...");

   // Récupérer données d'analyse technique
   TechnicalAnalysisData data;
   AnalyzeTechnicalSituation(_Symbol, data);

   // Récupérer actualités économiques
   string newsText = "";
   if(PushIncludeEconomicNews)
   {
      FetchEconomicNewsForPush(_Symbol, newsText);
   }

   // Formater message
   string message = FormatPushNotificationMessage(data, newsText);

   // Envoyer notification
   bool success = SendNotification(message);

   if(success)
   {
      Print("✅ Notification push envoyée: ", data.signal, " - ", data.trend);
   }
   else
   {
      Print("❌ Échec envoi notification push");
      Print("💡 Vérifiez: Outils > Options > Notifications > activé");
   }
}

//+------------------------------------------------------------------+
//| Initialiser système de notifications                             |
//+------------------------------------------------------------------+
void InitPushNotifications()
{
   g_lastPushNotification = 0;

   if(EnablePushNotifications)
   {
      Print("📲 Système de notifications push activé");
      Print("⏱️ Intervalle: ", PushNotificationInterval, " secondes (",
            PushNotificationInterval / 60, " minutes)");
      Print("💡 Assurez-vous d'avoir activé les notifications dans MT5:");
      Print("   Outils > Options > Notifications > cochez 'Activer les notifications Push'");
      Print("   Et configurez votre MetaQuotes ID");
   }
}

//+------------------------------------------------------------------+
//| Fonction d'envoi immédiat (pour tester)                         |
//+------------------------------------------------------------------+
void SendImmediatePushNotification()
{
   g_lastPushNotification = 0; // Reset pour forcer envoi
   SendPushAnalysisNotification();
}
