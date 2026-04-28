//+------------------------------------------------------------------+
//| Economic_News_Ticker.mqh                                          |
//| Affichage défilant des actualités économiques en bas du graphique|
//+------------------------------------------------------------------+
#property copyright "TradBOT 2026"
#property link      "https://github.com/yourusername/tradbot"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| PARAMÈTRES D'AFFICHAGE                                          |
//+------------------------------------------------------------------+

input group "=== TICKER ACTUALITÉS ÉCONOMIQUES ==="
input bool   ShowEconomicTicker = true;           // Afficher ticker actualités
input int    TickerUpdateInterval = 120;          // Mise à jour toutes les N secondes
input color  TickerTextColor = clrYellow;         // Couleur texte
input color  TickerBackgroundColor = clrDarkSlateGray; // Couleur fond
input int    TickerFontSize = 8;                  // Taille police
input int    TickerScrollSpeed = 2;               // Vitesse défilement (pixels/tick)
input int    TickerYPosition = 30;                // Distance depuis le bas (pixels)
input int    TickerHeight = 25;                   // Hauteur du ticker
input bool   TickerShowIcons = true;              // Afficher emojis/icônes

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+

datetime g_lastTickerUpdate = 0;
string g_currentTickerText = "";
int g_tickerScrollOffset = 0;
int g_tickerTextPixelWidth = 0;

//+------------------------------------------------------------------+
//| Récupérer ticker depuis l'API                                    |
//+------------------------------------------------------------------+
bool FetchTickerFromAPI(const string symbol, string &tickerText)
{
   string url = "http://localhost:8000/economic/news/ticker";
   url += "?symbol=" + symbol;

   // Faire requête HTTP
   char post[], result[];
   string headers;
   int timeout = 5000;

   int res = WebRequest(
      "GET",
      url,
      "",
      NULL,
      timeout,
      post,
      0,
      result,
      headers
   );

   if(res != 200)
   {
      Print("❌ Erreur API ticker économique: HTTP ", res);

      // Ticker de secours
      tickerText = StringFormat("📊 Trading %s | 💹 Market open | 🌐 Real-time analysis", symbol);
      return false;
   }

   // Parser JSON pour extraire ticker_text
   string json = CharArrayToString(result);

   // Recherche simple du champ "ticker_text"
   int startPos = StringFind(json, "\"ticker_text\":");
   if(startPos >= 0)
   {
      startPos = StringFind(json, "\"", startPos + 15);
      int endPos = StringFind(json, "\"", startPos + 1);

      if(startPos >= 0 && endPos > startPos)
      {
         tickerText = StringSubstr(json, startPos + 1, endPos - startPos - 1);

         // Décoder les échappements JSON basiques
         StringReplace(tickerText, "\\n", " ");
         StringReplace(tickerText, "\\\"", "\"");

         return true;
      }
   }

   // Fallback
   tickerText = StringFormat("📊 Trading %s | 💹 Market analysis | 🌐 Economic data loading...", symbol);
   return false;
}

//+------------------------------------------------------------------+
//| Calculer largeur approximative du texte en pixels               |
//+------------------------------------------------------------------+
int CalculateTextWidth(const string text, const int fontSize)
{
   // Approximation: 1 caractère = fontSize * 0.6 pixels (pour Arial)
   int charCount = StringLen(text);
   return (int)(charCount * fontSize * 0.6);
}

//+------------------------------------------------------------------+
//| Dessiner le fond du ticker                                       |
//+------------------------------------------------------------------+
void DrawTickerBackground()
{
   string bgName = "ECON_TICKER_BG";
   ObjectDelete(0, bgName);

   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);

   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, 0);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, TickerYPosition);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, chartWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, TickerHeight);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, TickerBackgroundColor);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, TickerBackgroundColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Dessiner le texte défilant                                       |
//+------------------------------------------------------------------+
void DrawScrollingText(const string text, const int scrollOffset)
{
   string labelName = "ECON_TICKER_TEXT";
   ObjectDelete(0, labelName);

   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);

   // Position X avec défilement (commence hors écran à droite)
   int xPos = chartWidth - scrollOffset;

   ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, xPos);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, TickerYPosition + 5);
   ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, TickerTextColor);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, TickerFontSize);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
   ObjectSetString(0, labelName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Animer le défilement du ticker                                  |
//+------------------------------------------------------------------+
void AnimateTickerScroll()
{
   if(g_currentTickerText == "") return;

   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);

   // Incrémenter offset
   g_tickerScrollOffset += TickerScrollSpeed;

   // Reset quand le texte sort complètement à gauche
   if(g_tickerScrollOffset > chartWidth + g_tickerTextPixelWidth)
   {
      g_tickerScrollOffset = 0;
   }

   // Redessiner
   DrawScrollingText(g_currentTickerText, g_tickerScrollOffset);
}

//+------------------------------------------------------------------+
//| Fonction principale: Afficher et mettre à jour le ticker        |
//+------------------------------------------------------------------+
void DisplayEconomicNewsTicker()
{
   if(!ShowEconomicTicker) return;

   datetime now = TimeCurrent();

   // Mise à jour du texte toutes les N secondes
   if(now - g_lastTickerUpdate >= TickerUpdateInterval)
   {
      g_lastTickerUpdate = now;

      Print("📰 Mise à jour ticker économique...");

      string newTickerText;
      if(FetchTickerFromAPI(_Symbol, newTickerText))
      {
         g_currentTickerText = newTickerText;
         g_tickerTextPixelWidth = CalculateTextWidth(g_currentTickerText, TickerFontSize);
         g_tickerScrollOffset = 0; // Reset scroll

         Print("✅ Ticker économique: ", StringSubstr(g_currentTickerText, 0, 100), "...");
      }
      else
      {
         // Utiliser ticker de secours
         g_currentTickerText = newTickerText;
         g_tickerTextPixelWidth = CalculateTextWidth(g_currentTickerText, TickerFontSize);
      }

      // Redessiner fond
      DrawTickerBackground();
   }

   // Animer le défilement à chaque appel (OnTick)
   AnimateTickerScroll();
}

//+------------------------------------------------------------------+
//| Nettoyer le ticker                                               |
//+------------------------------------------------------------------+
void CleanupEconomicTicker()
{
   ObjectDelete(0, "ECON_TICKER_BG");
   ObjectDelete(0, "ECON_TICKER_TEXT");

   Print("🧹 Ticker économique nettoyé");
}

//+------------------------------------------------------------------+
//| Initialiser le ticker                                            |
//+------------------------------------------------------------------+
void InitEconomicTicker()
{
   g_lastTickerUpdate = 0;
   g_currentTickerText = "";
   g_tickerScrollOffset = 0;

   // Première récupération immédiate
   string initialText;
   FetchTickerFromAPI(_Symbol, initialText);
   g_currentTickerText = initialText;
   g_tickerTextPixelWidth = CalculateTextWidth(g_currentTickerText, TickerFontSize);

   DrawTickerBackground();

   Print("✅ Ticker économique initialisé pour ", _Symbol);
}
