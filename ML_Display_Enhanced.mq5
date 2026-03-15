//| ML_Display_Enhanced.mq5                                          |
//| Affichage des vraies métriques ML sur le graphique MT5          |
//| Niveau d'entraînement, accuracy, features, calibration       |
//| Réponse ML en temps réel avec données Supabase              |
#property copyright "TradBOT ML Display"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

//--- Variables globales pour les métriques ML ---
string g_mlSymbol = "";
string g_mlTimeframe = "M1";
datetime g_lastMLUpdate = D'1970.01.01 00:00:00';
int g_mlUpdateInterval = 60; // 60 secondes entre les mises à jour

//--- Variables pour les métriques ---
string g_trainingLevel = "🔴 EN ATTENTE";
double g_accuracy = 0.0;
double g_f1Score = 0.0;
int g_samplesUsed = 0;
string g_modelType = "Unknown";
string g_lastTrainingTime = "";

//--- Top 5 Features ---
string g_featureNames[5];
double g_featureImportance[5];
int g_featureCount = 0;

//--- Calibration ---
double g_driftFactor = 0.0;
double g_winRate = 0.0;
int g_calibrationWins = 0;
int g_calibrationTotal = 0;

//--- Réponse ML ---
double g_mlConfidence = 0.0;
string g_mlPrediction = "HOLD";
string g_mlTimestamp = "";

//--- Configuration ---
input group "=== ML METRICS DISPLAY ==="
input bool   ShowMLMetricsPanel   = true;   // Afficher le panneau ML
input bool   ShowMLTrainingLevel  = true;   // Afficher le niveau d'entraînement
input bool   ShowMLAccuracy       = true;   // Afficher l'accuracy
input bool   ShowMLFeatures       = true;   // Afficher les features importantes
input bool   ShowMLCalibration    = true;   // Afficher la calibration
input bool   ShowMLResponse       = true;   // Afficher la réponse ML
input color  MLPanelBackColor      = clrBlack;  // Couleur de fond du panneau
input color  MLPanelTextColor      = clrWhite;  // Couleur du texte
input int   MLPanelFontSize       = 8;        // Taille de police
input int   MLPanelWidth         = 350;      // Largeur du panneau
input int   MLPanelHeight        = 250;      // Hauteur du panneau

//--- URLs de l'API ---
string g_mlMetricsURL = "http://localhost:8000/api/ml/metrics/";

//+------------------------------------------------------------------+
//| Fonction pour extraire une valeur JSON                           |
//+------------------------------------------------------------------+
string ExtractJsonValue(string json, string key)
{
   string searchKey = "\"" + key + "\":";
   int pos = StringFind(json, searchKey);
   if(pos < 0) return "";
   
   pos += StringLen(searchKey);
   if(StringGetCharacter(json, pos) == '"') pos++;
   if(StringGetCharacter(json, pos) == '[') pos++;
   
   int start = pos;
   int end = start;
   int bracketCount = 0;
   
   for(int i = start; i < StringLen(json); i++)
   {
      char c = StringGetCharacter(json, i);
      if(c == '[' || c == '{') bracketCount++;
      if(c == ']' || c == '}')
      {
         bracketCount--;
         if(bracketCount == 0)
         {
            end = i;
            break;
         }
      }
      if(c == ',' && bracketCount == 0)
      {
         end = i;
         break;
      }
   }
   
   if(end <= start) return "";
   
   string result = StringSubstr(json, start, end - start + 1);
   StringTrim(result);
   
   // Nettoyer les guillemets
   if(StringGetCharacter(result, 0) == '"' && StringGetCharacter(result, StringLen(result) - 1) == '"')
   {
      result = StringSubstr(result, 1, StringLen(result) - 2);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Mettre à jour les métriques ML depuis l'API                   |
//+------------------------------------------------------------------+
bool UpdateMLMetricsFromAPI()
{
   if(!ShowMLMetricsPanel) return false;
   
   // Limiter la fréquence des appels API
   if(TimeCurrent() - g_lastMLUpdate < g_mlUpdateInterval) return false;
   
   g_lastMLUpdate = TimeCurrent();
   
   // Préparer l'URL
   string symbol = g_mlSymbol;
   StringReplace(symbol, " ", "%20");
   string url = g_mlMetricsURL + symbol + "?timeframe=" + g_mlTimeframe;
   
   // Préparer la requête
   string headers = "";
   string data = "";
   char result[];
   string resultHeaders;
   
   // Appel WebRequest
   int timeout = 10000; // 10 secondes
   int res = WebRequest("GET", url, headers, timeout, data, result, resultHeaders);
   
   if(res == 200)
   {
      string jsonResponse = CharArrayToString(result);
      
      // Parser la réponse JSON
      ParseMLMetricsResponse(jsonResponse);
      
      Print("✅ Métriques ML mises à jour pour ", g_mlSymbol);
      return true;
   }
   else
   {
      Print("❌ Erreur API ML Metrics: ", res, " pour ", g_mlSymbol);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Parser la réponse JSON des métriques ML                      |
//+------------------------------------------------------------------+
void ParseMLMetricsResponse(string json)
{
   // Extraire les métriques d'entraînement
   string trainingJson = ExtractJsonValue(json, "last_training");
   if(StringLen(trainingJson) > 0)
   {
      g_trainingLevel = ExtractJsonValue(trainingJson, "training_level");
      g_accuracy = StringToDouble(ExtractJsonValue(trainingJson, "accuracy"));
      g_f1Score = StringToDouble(ExtractJsonValue(trainingJson, "f1_score"));
      g_samplesUsed = StringToInteger(ExtractJsonValue(trainingJson, "samples_used"));
      g_modelType = ExtractJsonValue(trainingJson, "model_type");
      g_lastTrainingTime = ExtractJsonValue(trainingJson, "created_at");
   }
   
   // Extraire les features importantes
   string featuresJson = ExtractJsonValue(json, "top_features");
   if(StringLen(featuresJson) > 0)
   {
      // Parser le tableau de features (simplifié)
      g_featureCount = 0;
      int start = StringFind(featuresJson, "[");
      int end = StringFind(featuresJson, "]", start);
      
      if(start >= 0 && end > start)
      {
         string featuresArray = StringSubstr(featuresJson, start + 1, end - start - 1);
         
         // Parser chaque feature (simplifié)
         string items[];
         StringSplit(featuresArray, "},", items);
         
         for(int i = 0; i < MathMin(5, ArraySize(items)) && i < ArraySize(g_featureNames); i++)
         {
            string item = items[i];
            if(StringLen(item) > 0)
            {
               if(StringGetCharacter(item, StringLen(item) - 1) != '}')
                  item += "}";
               
               g_featureNames[i] = ExtractJsonValue(item, "name");
               g_featureImportance[i] = StringToDouble(ExtractJsonValue(item, "importance"));
               g_featureCount++;
            }
         }
      }
   }
   
   // Extraire la calibration
   string calibrationJson = ExtractJsonValue(json, "calibration");
   if(StringLen(calibrationJson) > 0)
   {
      g_driftFactor = StringToDouble(ExtractJsonValue(calibrationJson, "drift_factor"));
      g_winRate = StringToDouble(ExtractJsonValue(calibrationJson, "win_rate"));
      g_calibrationWins = StringToInteger(ExtractJsonValue(calibrationJson, "wins"));
      g_calibrationTotal = StringToInteger(ExtractJsonValue(calibrationJson, "total"));
   }
   
   // Extraire la réponse ML
   string responseJson = ExtractJsonValue(json, "ml_response");
   if(StringLen(responseJson) > 0)
   {
      g_mlConfidence = StringToDouble(ExtractJsonValue(responseJson, "confidence"));
      g_mlPrediction = ExtractJsonValue(responseJson, "prediction");
      g_mlTimestamp = ExtractJsonValue(responseJson, "timestamp");
   }
}

//+------------------------------------------------------------------+
//| Dessiner le panneau des métriques ML                           |
//+------------------------------------------------------------------+
void DrawMLMetricsPanel()
{
   if(!ShowMLMetricsPanel) return;
   
   string panelName = "ML_Metrics_Panel_" + g_mlSymbol;
   
   // Supprimer l'ancien panneau
   ObjectDelete(0, panelName);
   
   // Créer le panneau principal
   if(ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      // Positionner le panneau en haut à droite
      ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 100);
      ObjectSetInteger(0, panelName, OBJPROP_XSIZE, MLPanelWidth);
      ObjectSetInteger(0, panelName, OBJPROP_YSIZE, MLPanelHeight);
      ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, MLPanelBackColor);
      ObjectSetInteger(0, panelName, OBJPROP_BORDER_COLOR, clrGray);
      ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, panelName, OBJPROP_BACK_COLOR, CLR_NONE);
   }
   
   // Titre du panneau
   string titleName = panelName + "_Title";
   if(ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetString(0, titleName, OBJPROP_TEXT, "🤖 MÉTRIQUES ML - " + g_mlSymbol);
      ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, 25);
      ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, 105);
      ObjectSetInteger(0, titleName, OBJPROP_COLOR, clrLime);
      ObjectSetString(0, titleName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, MLPanelFontSize + 1);
      ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   }
   
   int yPos = 130;
   int lineHeight = 18;
   
   //--- Niveau d'entraînement ---
   if(ShowMLTrainingLevel)
   {
      string trainingLabel = panelName + "_Training";
      if(ObjectCreate(0, trainingLabel, OBJ_LABEL, 0, 0, 0))
      {
         ObjectSetString(0, trainingLabel, OBJPROP_TEXT, "🎯 NIVEAU: " + g_trainingLevel);
         ObjectSetInteger(0, trainingLabel, OBJPROP_XDISTANCE, 25);
         ObjectSetInteger(0, trainingLabel, OBJPROP_YDISTANCE, yPos);
         ObjectSetInteger(0, trainingLabel, OBJPROP_COLOR, MLPanelTextColor);
         ObjectSetString(0, trainingLabel, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, trainingLabel, OBJPROP_FONTSIZE, MLPanelFontSize);
         ObjectSetInteger(0, trainingLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      }
      yPos += lineHeight;
   }
   
   //--- Accuracy et F1 Score ---
   if(ShowMLAccuracy)
   {
      string accuracyLabel = panelName + "_Accuracy";
      if(ObjectCreate(0, accuracyLabel, OBJ_LABEL, 0, 0, 0))
      {
         ObjectSetString(0, accuracyLabel, OBJPROP_TEXT, 
            "📊 Précision: " + DoubleToString(g_accuracy * 100, 1) + "%" +
            " | F1: " + DoubleToString(g_f1Score * 100, 1) + "%");
         ObjectSetInteger(0, accuracyLabel, OBJPROP_XDISTANCE, 25);
         ObjectSetInteger(0, accuracyLabel, OBJPROP_YDISTANCE, yPos);
         ObjectSetInteger(0, accuracyLabel, OBJPROP_COLOR, 
            g_accuracy >= 0.8 ? clrLime : g_accuracy >= 0.6 ? clrYellow : clrRed);
         ObjectSetString(0, accuracyLabel, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, accuracyLabel, OBJPROP_FONTSIZE, MLPanelFontSize);
         ObjectSetInteger(0, accuracyLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      }
      yPos += lineHeight;
      
      string samplesLabel = panelName + "_Samples";
      if(ObjectCreate(0, samplesLabel, OBJ_LABEL, 0, 0, 0))
      {
         ObjectSetString(0, samplesLabel, OBJPROP_TEXT, 
            "📚 Samples: " + IntegerToString(g_samplesUsed) + 
            " | Modèle: " + g_modelType);
         ObjectSetInteger(0, samplesLabel, OBJPROP_XDISTANCE, 25);
         ObjectSetInteger(0, samplesLabel, OBJPROP_YDISTANCE, yPos);
         ObjectSetInteger(0, samplesLabel, OBJPROP_COLOR, MLPanelTextColor);
         ObjectSetString(0, samplesLabel, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, samplesLabel, OBJPROP_FONTSIZE, MLPanelFontSize);
         ObjectSetInteger(0, samplesLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      }
      yPos += lineHeight;
   }
   
   //--- Top 5 Features ---
   if(ShowMLFeatures && g_featureCount > 0)
   {
      string featuresTitle = panelName + "_FeaturesTitle";
      if(ObjectCreate(0, featuresTitle, OBJ_LABEL, 0, 0, 0))
      {
         ObjectSetString(0, featuresTitle, OBJPROP_TEXT, "🔥 TOP FEATURES:");
         ObjectSetInteger(0, featuresTitle, OBJPROP_XDISTANCE, 25);
         ObjectSetInteger(0, featuresTitle, OBJPROP_YDISTANCE, yPos);
         ObjectSetInteger(0, featuresTitle, OBJPROP_COLOR, clrOrange);
         ObjectSetString(0, featuresTitle, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, featuresTitle, OBJPROP_FONTSIZE, MLPanelFontSize);
         ObjectSetInteger(0, featuresTitle, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      }
      yPos += lineHeight;
      
      for(int i = 0; i < MathMin(g_featureCount, 5); i++)
      {
         string featureLabel = panelName + "_Feature" + IntegerToString(i);
         if(ObjectCreate(0, featureLabel, OBJ_LABEL, 0, 0, 0))
         {
            string featureText = StringSubstr(g_featureNames[i], 0, 15) + ": " + 
               DoubleToString(g_featureImportance[i] * 100, 1) + "%";
            
            ObjectSetString(0, featureLabel, OBJPROP_TEXT, featureText);
            ObjectSetInteger(0, featureLabel, OBJPROP_XDISTANCE, 30);
            ObjectSetInteger(0, featureLabel, OBJPROP_YDISTANCE, yPos);
            ObjectSetInteger(0, featureLabel, OBJPROP_COLOR, MLPanelTextColor);
            ObjectSetString(0, featureLabel, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, featureLabel, OBJPROP_FONTSIZE, MLPanelFontSize - 1);
            ObjectSetInteger(0, featureLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         }
         yPos += (lineHeight - 2);
      }
      yPos += 5; // Espacement après les features
   }
   
   //--- Calibration ---
   if(ShowMLCalibration)
   {
      string calibrationTitle = panelName + "_CalibrationTitle";
      if(ObjectCreate(0, calibrationTitle, OBJ_LABEL, 0, 0, 0))
      {
         ObjectSetString(0, calibrationTitle, OBJPROP_TEXT, "⚖️ CALIBRATION:");
         ObjectSetInteger(0, calibrationTitle, OBJPROP_XDISTANCE, 25);
         ObjectSetInteger(0, calibrationTitle, OBJPROP_YDISTANCE, yPos);
         ObjectSetInteger(0, calibrationTitle, OBJPROP_COLOR, clrAqua);
         ObjectSetString(0, calibrationTitle, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, calibrationTitle, OBJPROP_FONTSIZE, MLPanelFontSize);
         ObjectSetInteger(0, calibrationTitle, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      }
      yPos += lineHeight;
      
      string driftLabel = panelName + "_Drift";
      if(ObjectCreate(0, driftLabel, OBJ_LABEL, 0, 0, 0))
      {
         ObjectSetString(0, driftLabel, OBJPROP_TEXT, 
            "Drift: " + DoubleToString(g_driftFactor, 3) + 
            " | Win Rate: " + DoubleToString(g_winRate, 1) + "%");
         ObjectSetInteger(0, driftLabel, OBJPROP_XDISTANCE, 25);
         ObjectSetInteger(0, driftLabel, OBJPROP_YDISTANCE, yPos);
         ObjectSetInteger(0, driftLabel, OBJPROP_COLOR, 
            g_driftFactor < 0.1 ? clrLime : g_driftFactor < 0.3 ? clrYellow : clrRed);
         ObjectSetString(0, driftLabel, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, driftLabel, OBJPROP_FONTSIZE, MLPanelFontSize);
         ObjectSetInteger(0, driftLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      }
      yPos += lineHeight;
      
      string winsLabel = panelName + "_Wins";
      if(ObjectCreate(0, winsLabel, OBJ_LABEL, 0, 0, 0))
      {
         ObjectSetString(0, winsLabel, OBJPROP_TEXT, 
            "Trades: " + IntegerToString(g_calibrationWins) + "/" + IntegerToString(g_calibrationTotal));
         ObjectSetInteger(0, winsLabel, OBJPROP_XDISTANCE, 25);
         ObjectSetInteger(0, winsLabel, OBJPROP_YDISTANCE, yPos);
         ObjectSetInteger(0, winsLabel, OBJPROP_COLOR, MLPanelTextColor);
         ObjectSetString(0, winsLabel, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, winsLabel, OBJPROP_FONTSIZE, MLPanelFontSize);
         ObjectSetInteger(0, winsLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      }
      yPos += lineHeight;
   }
   
   //--- Réponse ML ---
   if(ShowMLResponse)
   {
      string responseTitle = panelName + "_ResponseTitle";
      if(ObjectCreate(0, responseTitle, OBJ_LABEL, 0, 0, 0))
      {
         ObjectSetString(0, responseTitle, OBJPROP_TEXT, "🧠 RÉPONSE ML:");
         ObjectSetInteger(0, responseTitle, OBJPROP_XDISTANCE, 25);
         ObjectSetInteger(0, responseTitle, OBJPROP_YDISTANCE, yPos);
         ObjectSetInteger(0, responseTitle, OBJPROP_COLOR, clrPurple);
         ObjectSetString(0, responseTitle, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, responseTitle, OBJPROP_FONTSIZE, MLPanelFontSize);
         ObjectSetInteger(0, responseTitle, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      }
      yPos += lineHeight;
      
      string predictionLabel = panelName + "_Prediction";
      if(ObjectCreate(0, predictionLabel, OBJ_LABEL, 0, 0, 0))
      {
         string predText = "Signal: " + g_mlPrediction + " | Conf: " + DoubleToString(g_mlConfidence * 100, 1) + "%";
         
         ObjectSetString(0, predictionLabel, OBJPROP_TEXT, predText);
         ObjectSetInteger(0, predictionLabel, OBJPROP_XDISTANCE, 25);
         ObjectSetInteger(0, predictionLabel, OBJPROP_YDISTANCE, yPos);
         ObjectSetInteger(0, predictionLabel, OBJPROP_COLOR, 
            g_mlPrediction == "BUY" ? clrLime : 
            g_mlPrediction == "SELL" ? clrRed : clrYellow);
         ObjectSetString(0, predictionLabel, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, predictionLabel, OBJPROP_FONTSIZE, MLPanelFontSize + 1);
         ObjectSetInteger(0, predictionLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      }
      yPos += lineHeight;
      
      string timestampLabel = panelName + "_Timestamp";
      if(ObjectCreate(0, timestampLabel, OBJ_LABEL, 0, 0, 0))
      {
         string timeStr = StringSubstr(g_mlTimestamp, 11, 8); // HH:MM:SS
         ObjectSetString(0, timestampLabel, OBJPROP_TEXT, "Dernière: " + timeStr);
         ObjectSetInteger(0, timestampLabel, OBJPROP_XDISTANCE, 25);
         ObjectSetInteger(0, timestampLabel, OBJPROP_YDISTANCE, yPos);
         ObjectSetInteger(0, timestampLabel, OBJPROP_COLOR, MLPanelTextColor);
         ObjectSetString(0, timestampLabel, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, timestampLabel, OBJPROP_FONTSIZE, MLPanelFontSize - 1);
         ObjectSetInteger(0, timestampLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      }
   }
}

//+------------------------------------------------------------------+
//| Nettoyer tous les objets ML                                 |
//+------------------------------------------------------------------+
void CleanupMLObjects()
{
   string prefix = "ML_Metrics_Panel_" + g_mlSymbol;
   
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, prefix) == 0)
      {
         ObjectDelete(0, objName);
      }
   }
}

//+------------------------------------------------------------------+
//| Initialisation                                               |
//+------------------------------------------------------------------+
int OnInit()
{
   g_mlSymbol = _Symbol;
   
   // Initialiser les arrays
   ArrayInitialize(g_featureNames, "");
   ArrayInitialize(g_featureImportance, 0.0);
   
   // Première mise à jour
   UpdateMLMetricsFromAPI();
   
   Print("🤖 ML Display Enhanced initialisé pour ", _Symbol);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialisation                                             |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   CleanupMLObjects();
   Print("🤖 ML Display Enhanced déinitialisé");
}

//+------------------------------------------------------------------+
//| Tick principal                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Mettre à jour les métriques périodiquement
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate >= g_mlUpdateInterval)
   {
      UpdateMLMetricsFromAPI();
      lastUpdate = TimeCurrent();
   }
   
   // Redessiner le panneau
   DrawMLMetricsPanel();
}
