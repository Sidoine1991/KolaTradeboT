//+------------------------------------------------------------------+
//| SMC_ML_Predictor.mqh — ML Correction Predictor Integration       |
//| Intègre le modèle ONNX pour prédire les régimes de marché         |
//| et affiner les décisions d'entrée en temps réel                  |
//+------------------------------------------------------------------+

// Déclarations globales pour le modèle ONNX
int g_mlModelHandle = INVALID_HANDLE;
double g_mlPrediction = 0;
double g_mlConfidence = 0;
datetime g_mlLastUpdate = 0;
int g_mlFeatureCount = 0;

// Fonctions d'initialisation et prédiction
void SMC_ML_Init()
{
   // Chemin vers le modèle ONNX (MQL5/Files, copié par deploy_models.py)
   // FIX v1.57: chemin relatif corrigé -> le modèle réel est dans MQL5/Files/
   string modelPath = "spike_chain_model.onnx";

   // Libérer l'ancien modèle si existant
   if(g_mlModelHandle != INVALID_HANDLE)
      OnnxDestroy(g_mlModelHandle);

   // Charger le modèle ONNX
   if(!OnnxCreate(g_mlModelHandle, modelPath))
   {
      Print("⚠️ SMC_ML: Impossible de charger le modèle ONNX - utilisation fallback");
      return;
   }

   // Charger les métadonnées pour interpréter les prédictions
   string metaPath = "..\\..\\SMC_Learn\\model_metadata.json";
   int fileHandle = FileOpen(metaPath, FILE_READ|FILE_TXT, 0);
   if(fileHandle > INVALID_HANDLE)
   {
      string metaContent = "";
      FileRead(fileHandle, metaContent);
      // Parser JSON simple (version MQL5 limitée)
      // Extraire l'ordre des features et le mapping
      FileClose(fileHandle);
   }

   Print("✅ SMC_ML: Modèle chargé avec succès - prédictions activées");
}

// Prédiction ML en temps réel (appelée depuis OnTimer toutes les 5 secondes)
void SMC_ML_Predict()
{
   if(g_mlModelHandle == INVALID_HANDLE) return;

   // Construire les features actuelles
   double features[20];
   int featureCount = SMC_ML_BuildFeatures(features);

   // Exécuter la prédiction ONNX
   double prediction = 0;
   if(OnnxRun(g_mlModelHandle, 1, 1, features, &prediction))
   {
      g_mlPrediction = prediction; // 0=down, 1=up
      g_mlConfidence = prediction * (1 - prediction); // confiance en forme de courbe
      g_mlLastUpdate = TimeCurrent();
   }

   // Mettre à jour le dashboard visuel
   SMC_ML_UpdateDashboard();
}

// Construire les features pour le modèle ML
int SMC_ML_BuildFeatures(double &features[])
{
   // Réinitialiser le tableau
   for(int i = 0; i < 20; i++) features[i] = 0;

   // 1. Direction du spike courant (à partir de g_smcGomVerdictNum)
   // 0 = indécis, 1 = BUY, -1 = SELL
   int currentDir = (g_smcGomVerdictNum > 0) ? 1 : ((g_smcGomVerdictNum < 0) ? -1 : 0);
   features[0] = (currentDir == 1) ? 1.0 : 0.0;  // dir_is_up

   // 2. Amplitude en pips (distance SL/TP)
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDist = g_smcEntrySLDist;
   double tpDist = g_smcEntryTPDist;
   if(slDist > 0 && tpDist > 0)
   {
      features[1] = MathAbs(tpDist - slDist) / point;  // amplitude_pips
      features[2] = slDist * (SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));  // amplitude_atr
   }

   // 3. Vélocité proxy (changement prix/temps)
   static datetime lastPriceTime = 0;
   static double lastPrice = 0;
   if(TimeCurrent() - lastPriceTime > 60)
   {
      lastPriceTime = TimeCurrent();
      lastPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   if(lastPrice > 0)
   {
      double currPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      features[3] = MathAbs(currPrice - lastPrice) / point;  // velocity_proxy
   }

   // 4. Temps depuis dernier spike (utiliser g_smcLastSpikeTime)
   if(g_smcLastSpikeTime > 0)
      features[4] = (TimeCurrent() - g_smcLastSpikeTime) / 60.0;  // minutes_since_prev_spike

   // 5. Heure/minute (saisonnalité intra-journalière)
   datetime now = TimeCurrent();
   features[5] = (now % 86400) / 3600.0;  // heure dans la journée (0-24)
   features[6] = ((now % 86400) / 60) % 60;  // minute dans l'heure

   // 6. Prior Markov (calculé côté MQL5 - simplifié ici)
   // Utiliser le dernier verdict GOM comme proxy
   features[7] = (MathAbs(g_smcGomVerdictNum) >= 2) ? 0.8 : 0.2;  // markov_prior_up

   g_mlFeatureCount = 8;
   return g_mlFeatureCount;
}

// Mettre à jour le dashboard visuel ML
void SMC_ML_UpdateDashboard()
{
   // HTML pour le dashboard (à intégrer dans le dessin existant)
   string html = "<div id='ml-dashboard' style='position:absolute; top:10px; right:10px; "
               "background:rgba(0,0,0,0.85); color:white; padding:10px; border-radius:5px; "
               "font-family:monospace; font-size:11px; max-width:220px;'>"
               "<h3>🔮 ML Correction Predictor</h3>"
               "<table style='width:100%; border-collapse:collapse;'>"
               "<tr><td>Prédiction :</td><td><b>" + (g_mlPrediction > 0.5 ? "BUY↑" : "SELL↓") + "</b></td></tr>"
               "<tr><td>Confiance :</td><td>" + DoubleToString(g_mlConfidence * 100, 1) + "%</td></tr>"
               "<tr><td>Dernière MAJ :</td><td>" + (g_mlLastUpdate > 0 ? DoubleToString((TimeCurrent() - g_mlLastUpdate)/60, 1) + "min" : "-") + "</td></tr>"
               "<tr><td>Signal :</td><td>" + (MathAbs(g_mlPrediction - 0.5) > 0.4 ? "ACTIF" : "INACTIF") + "</td></tr>"
               "<tr><td>RR ajusté :</td><td>" + DoubleToString(g_mlRRAdjusted * 10, 1) + "</td></tr>"
               "</table>"
               "</div>";

   // Ajouter au dessin (à appeler depuis votre fonction de dessin existante)
   // DrawTextHTML(html);
}

// Ajuster le RR en fonction de la prédiction ML
void SMC_ML_AdjustRisk(double &minRR, double &maxLossUSD)
{
   if(g_mlConfidence < 0.3) return;  // Pas assez confiant

   // Si ML prédit continuation haussière et on est en position short
   if(g_mlPrediction > 0.7 && !isBuySide)
   {
      // Réduire le RR minimum requis (plus agressif)
      minRR *= 0.8;
      maxLossUSD *= 1.2;
   }
   // Si ML prédit continuation baissière et on est en position long
   else if(g_mlPrediction < 0.3 && isBuySide)
   {
      minRR *= 0.8;
      maxLossUSD *= 1.2;
   }
   // Si ML détecte une correction (contre-trend)
   else if(MathAbs(g_mlPrediction - 0.5) > 0.2)
   {
      // Ajuster le RR selon la confiance
      minRR = MathMax(3.0, minRR * (1.0 + g_mlConfidence));
   }
}

// Fonction helper pour vérifier si le ML est actif
bool SMC_ML_IsActive()
{
   return g_mlModelHandle != INVALID_HANDLE;
}
