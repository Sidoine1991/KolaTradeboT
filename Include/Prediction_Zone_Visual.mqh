//+------------------------------------------------------------------+
//| Prediction_Zone_Visual.mqh                                        |
//| Affichage visuel de la zone de prédiction avec trajectoire       |
//| Bougies futures + segments + flèches                             |
//+------------------------------------------------------------------+
#property copyright "TradBOT 2026"
#property link      "https://github.com/yourusername/tradbot"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| STRUCTURES DE DONNÉES                                            |
//+------------------------------------------------------------------+

struct PredictedCandle
{
   datetime time;
   double   open;
   double   high;
   double   low;
   double   close;
   double   confidence;  // 0-100
   string   trend;       // "UP", "DOWN", "SIDEWAYS"
};

struct TrajectoryPoint
{
   datetime time;
   double   price;
   string   type;        // "SUPPORT", "RESISTANCE", "PIVOT", "TARGET"
   double   confidence;
};

//+------------------------------------------------------------------+
//| PARAMÈTRES D'AFFICHAGE                                          |
//+------------------------------------------------------------------+

input group "=== ZONE DE PRÉDICTION VISUELLE ==="
input bool   ShowPredictionZone = true;           // Afficher zone prédiction
input int    PredictionNumCandles = 5;            // Nombre bougies à prédire
input bool   ShowPredictedCandles = true;         // Dessiner bougies futures
input bool   ShowTrajectoryPath = true;           // Dessiner trajectoire
input bool   ShowTrajectoryArrows = true;         // Flèches direction
input color  PredictionZoneColor = clrDarkSlateGray; // Couleur zone
input int    PredictionZoneAlpha = 230;           // Transparence zone (0-255)
input color  PredictedCandleBullish = clrLimeGreen; // Couleur bougies haussières
input color  PredictedCandleBearish = clrCrimson;   // Couleur bougies baissières
input int    PredictedCandleAlpha = 180;          // Transparence bougies
input color  TrajectoryLineColor = clrYellow;     // Couleur trajectoire
input int    TrajectoryLineWidth = 2;             // Épaisseur ligne
input int    TrajectoryArrowSize = 2;             // Taille flèches
input bool   ShowConfidenceLabels = true;         // Afficher % confiance
input int    ConfidenceLabelSize = 7;             // Taille police confiance

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+

datetime g_lastPredictionUpdate = 0;
int g_predictionUpdateInterval = 60;  // Mise à jour toutes les 60 secondes

//+------------------------------------------------------------------+
//| Récupérer prédictions depuis l'API                              |
//+------------------------------------------------------------------+
bool FetchPredictionFromAPI(
   const string symbol,
   const string timeframe,
   const int numCandles,
   PredictedCandle &candles[],
   TrajectoryPoint &trajectory[]
)
{
   // Construire requête
   double currentPrice = (SymbolInfoDouble(symbol, SYMBOL_BID) + SymbolInfoDouble(symbol, SYMBOL_ASK)) / 2.0;
   double emaFast = iMA(symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   double emaSlow = iMA(symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   double rsi = iRSI(symbol, PERIOD_M5, 14, PRICE_CLOSE);
   double atr = iATR(symbol, PERIOD_M5, 14);

   string url = "http://localhost:8000/prediction/candles/future";
   url += "?symbol=" + symbol;
   url += "&timeframe=" + timeframe;
   url += "&num_candles=" + IntegerToString(numCandles);
   url += "&price=" + DoubleToString(currentPrice, 5);
   url += "&ema_fast=" + DoubleToString(emaFast, 5);
   url += "&ema_slow=" + DoubleToString(emaSlow, 5);
   url += "&rsi=" + DoubleToString(rsi, 2);
   url += "&atr=" + DoubleToString(atr, 5);

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
      Print("❌ Erreur API prédiction: HTTP ", res);
      return false;
   }

   // Parser JSON
   string json = CharArrayToString(result);

   // TODO: Parser JSON complet
   // Pour l'instant, générer prédictions de démo
   GenerateDemoPredictions(symbol, numCandles, currentPrice, candles, trajectory);

   return true;
}

//+------------------------------------------------------------------+
//| Générer prédictions de démo (pour test)                         |
//+------------------------------------------------------------------+
void GenerateDemoPredictions(
   const string symbol,
   const int numCandles,
   const double currentPrice,
   PredictedCandle &candles[],
   TrajectoryPoint &trajectory[]
)
{
   ArrayResize(candles, numCandles);
   ArrayResize(trajectory, numCandles + 1);

   datetime currentTime = TimeCurrent();
   int tfSeconds = PeriodSeconds(PERIOD_CURRENT);

   double lastClose = currentPrice;
   double avgMove = SymbolInfoDouble(symbol, SYMBOL_POINT) * 50; // 50 points par bougie

   // Tendance aléatoire pour démo
   string trendDir = (MathRand() % 2 == 0) ? "UP" : "DOWN";

   // Point de départ
   trajectory[0].time = currentTime;
   trajectory[0].price = currentPrice;
   trajectory[0].type = "PIVOT";
   trajectory[0].confidence = 100.0;

   for(int i = 0; i < numCandles; i++)
   {
      datetime candleTime = currentTime + tfSeconds * (i + 1);

      double open = lastClose;
      double change = avgMove * (1 + (MathRand() % 50 - 25) / 100.0);

      double close, high, low;

      if(trendDir == "UP")
      {
         close = open + change;
         high = close + change * 0.3;
         low = open - change * 0.1;
      }
      else
      {
         close = open - change;
         low = close - change * 0.3;
         high = open + change * 0.1;
      }

      // Confiance décroissante
      double confidence = 85.0 * MathPow(0.85, i);

      candles[i].time = candleTime;
      candles[i].open = open;
      candles[i].high = high;
      candles[i].low = low;
      candles[i].close = close;
      candles[i].confidence = confidence;
      candles[i].trend = trendDir;

      // Point trajectoire
      trajectory[i + 1].time = candleTime;
      trajectory[i + 1].price = close;
      trajectory[i + 1].type = (i == numCandles - 1) ? "TARGET" : "PIVOT";
      trajectory[i + 1].confidence = confidence;

      lastClose = close;

      // Changer direction aléatoirement
      if(MathRand() % 100 < 20) // 20% chance
         trendDir = (trendDir == "UP") ? "DOWN" : "UP";
   }
}

//+------------------------------------------------------------------+
//| Dessiner une bougie prédite                                      |
//+------------------------------------------------------------------+
void DrawPredictedCandle(
   const PredictedCandle &candle,
   const int index
)
{
   string prefix = "PRED_CANDLE_" + IntegerToString(index) + "_";

   // Couleur selon direction
   color candleColor = (candle.close >= candle.open) ? PredictedCandleBullish : PredictedCandleBearish;

   // Transparence selon confiance
   int alpha = (int)(PredictedCandleAlpha * (candle.confidence / 100.0));

   // Corps de la bougie (rectangle)
   string bodyName = prefix + "BODY";
   ObjectDelete(0, bodyName);
   ObjectCreate(0, bodyName, OBJ_RECTANGLE, 0,
                candle.time - PeriodSeconds(PERIOD_CURRENT) / 2,
                candle.open,
                candle.time + PeriodSeconds(PERIOD_CURRENT) / 2,
                candle.close);
   ObjectSetInteger(0, bodyName, OBJPROP_COLOR, candleColor);
   ObjectSetInteger(0, bodyName, OBJPROP_FILL, true);
   ObjectSetInteger(0, bodyName, OBJPROP_BACK, true);
   ObjectSetInteger(0, bodyName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, bodyName, OBJPROP_SELECTABLE, false);

   // Mèches (lignes verticales)
   string wickName = prefix + "WICK";
   ObjectDelete(0, wickName);
   ObjectCreate(0, wickName, OBJ_TREND, 0, candle.time, candle.low, candle.time, candle.high);
   ObjectSetInteger(0, wickName, OBJPROP_COLOR, candleColor);
   ObjectSetInteger(0, wickName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, wickName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, wickName, OBJPROP_BACK, true);
   ObjectSetInteger(0, wickName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, wickName, OBJPROP_SELECTABLE, false);

   // Label confiance (optionnel)
   if(ShowConfidenceLabels)
   {
      string labelName = prefix + "CONFIDENCE";
      ObjectDelete(0, labelName);
      ObjectCreate(0, labelName, OBJ_TEXT, 0, candle.time, candle.high + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
      ObjectSetString(0, labelName, OBJPROP_TEXT, DoubleToString(candle.confidence, 0) + "%");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, ConfidenceLabelSize);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Dessiner la zone de prédiction (rectangle transparent)          |
//+------------------------------------------------------------------+
void DrawPredictionZone(
   const datetime startTime,
   const datetime endTime,
   const double minPrice,
   const double maxPrice
)
{
   string zoneName = "PREDICTION_ZONE";
   ObjectDelete(0, zoneName);

   ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, startTime, minPrice, endTime, maxPrice);
   ObjectSetInteger(0, zoneName, OBJPROP_COLOR, PredictionZoneColor);
   ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
   ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
   ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, false);

   // Label
   string labelName = "PREDICTION_ZONE_LABEL";
   ObjectDelete(0, labelName);
   ObjectCreate(0, labelName, OBJ_TEXT, 0, startTime, maxPrice);
   ObjectSetString(0, labelName, OBJPROP_TEXT, "⚡ ZONE PRÉDICTION ML");
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Dessiner la trajectoire avec segments et flèches                |
//+------------------------------------------------------------------+
void DrawTrajectoryPath(const TrajectoryPoint &points[])
{
   int numPoints = ArraySize(points);
   if(numPoints < 2) return;

   // Supprimer anciennes trajectoires
   for(int i = ObjectsTotal(0, 0, OBJ_TREND) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_TREND);
      if(StringFind(name, "TRAJECTORY_") == 0)
         ObjectDelete(0, name);
   }

   // Dessiner segments
   for(int i = 0; i < numPoints - 1; i++)
   {
      string segmentName = "TRAJECTORY_SEG_" + IntegerToString(i);

      ObjectCreate(0, segmentName, OBJ_TREND, 0,
                   points[i].time, points[i].price,
                   points[i + 1].time, points[i + 1].price);

      ObjectSetInteger(0, segmentName, OBJPROP_COLOR, TrajectoryLineColor);
      ObjectSetInteger(0, segmentName, OBJPROP_WIDTH, TrajectoryLineWidth);
      ObjectSetInteger(0, segmentName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, segmentName, OBJPROP_BACK, false);
      ObjectSetInteger(0, segmentName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, segmentName, OBJPROP_SELECTABLE, false);

      // Flèche à la fin du segment (optionnel)
      if(ShowTrajectoryArrows && i < numPoints - 2)
      {
         string arrowName = "TRAJECTORY_ARROW_" + IntegerToString(i);

         // Déterminer direction de la flèche
         int arrowCode = (points[i + 1].price > points[i].price) ? 233 : 234; // ▲ ou ▼

         ObjectCreate(0, arrowName, OBJ_ARROW, 0, points[i + 1].time, points[i + 1].price);
         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, TrajectoryLineColor);
         ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, TrajectoryArrowSize);
         ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
         ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
         ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
      }

      // Label pour points clés
      if(points[i + 1].type == "TARGET" || points[i + 1].type == "PIVOT")
      {
         string pointLabel = "TRAJECTORY_POINT_" + IntegerToString(i);
         ObjectCreate(0, pointLabel, OBJ_TEXT, 0, points[i + 1].time, points[i + 1].price);

         string labelText = "";
         if(points[i + 1].type == "TARGET")
            labelText = "🎯 " + DoubleToString(points[i + 1].price, _Digits);
         else if(points[i + 1].type == "PIVOT")
            labelText = "🔄";

         ObjectSetString(0, pointLabel, OBJPROP_TEXT, labelText);
         ObjectSetInteger(0, pointLabel, OBJPROP_COLOR, clrYellow);
         ObjectSetInteger(0, pointLabel, OBJPROP_FONTSIZE, 8);
         ObjectSetString(0, pointLabel, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, pointLabel, OBJPROP_SELECTABLE, false);
      }
   }
}

//+------------------------------------------------------------------+
//| Fonction principale: Afficher la zone de prédiction             |
//+------------------------------------------------------------------+
void DisplayPredictionZone()
{
   if(!ShowPredictionZone) return;

   // Throttle: mise à jour toutes les 60 secondes
   datetime now = TimeCurrent();
   if(now - g_lastPredictionUpdate < g_predictionUpdateInterval)
      return;

   g_lastPredictionUpdate = now;

   Print("🔮 Mise à jour zone prédiction...");

   // Récupérer prédictions depuis API
   PredictedCandle candles[];
   TrajectoryPoint trajectory[];

   if(!FetchPredictionFromAPI(_Symbol, "M5", PredictionNumCandles, candles, trajectory))
   {
      Print("❌ Échec récupération prédictions");
      return;
   }

   // Trouver limites de la zone
   double minPrice = candles[0].low;
   double maxPrice = candles[0].high;
   datetime startTime = candles[0].time;
   datetime endTime = candles[ArraySize(candles) - 1].time;

   for(int i = 0; i < ArraySize(candles); i++)
   {
      if(candles[i].low < minPrice) minPrice = candles[i].low;
      if(candles[i].high > maxPrice) maxPrice = candles[i].high;
   }

   // Dessiner zone de prédiction
   DrawPredictionZone(startTime, endTime, minPrice, maxPrice);

   // Dessiner bougies prédites
   if(ShowPredictedCandles)
   {
      for(int i = 0; i < ArraySize(candles); i++)
      {
         DrawPredictedCandle(candles[i], i);
      }
   }

   // Dessiner trajectoire
   if(ShowTrajectoryPath)
   {
      DrawTrajectoryPath(trajectory);
   }

   Print("✅ Zone prédiction affichée: ", ArraySize(candles), " bougies futures");

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Nettoyer tous les objets de prédiction                          |
//+------------------------------------------------------------------+
void CleanupPredictionZone()
{
   // Supprimer tous les objets commençant par PRED_ ou TRAJECTORY_
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "PRED_") == 0 ||
         StringFind(name, "TRAJECTORY_") == 0 ||
         StringFind(name, "PREDICTION_ZONE") == 0)
      {
         ObjectDelete(0, name);
      }
   }
}
