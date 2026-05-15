//+------------------------------------------------------------------+
//| GOM_Enhanced_Dashboard.mqh                                        |
//| Tableau de bord amélioré avec stats ML AWS RDS                   |
//+------------------------------------------------------------------+
#property copyright "TradBOT 2026"
#property strict

// Nettoyage automatique des dessins expirés
void GOM_CleanExpiredDrawings()
{
   datetime nowTime = TimeCurrent();
   int total = ObjectsTotal(0, 0, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);

      // Nettoyer les objets GOM anciens
      if(StringFind(name, "GOM_") == 0 ||
         StringFind(name, "DASH_") == 0 ||
         StringFind(name, "KOLA_") == 0 ||
         StringFind(name, "SIDO_") == 0)
      {
         // Vérifier si l'objet a une expiration
         datetime expiration = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
         if(expiration > 0 && expiration < nowTime)
         {
            ObjectDelete(0, name);
            continue;
         }

         // Supprimer les lignes de tendance très anciennes (> 4h)
         if(ObjectGetInteger(0, name, OBJPROP_TYPE) == OBJ_TREND)
         {
            datetime objTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
            if(nowTime - objTime > 14400) // 4 heures
            {
               ObjectDelete(0, name);
            }
         }
      }
   }
}

// Structure pour les stats ML depuis AWS RDS
struct MLStats
{
   int totalPredictions;      // Nombre total de prédictions
   int accuratePredictions;   // Prédictions correctes
   double accuracyPercent;    // Précision en %
   int tradesTotal;           // Nombre de trades
   int tradesWin;             // Trades gagnants
   double winRate;            // Taux de réussite
   double avgProfitUSD;       // Profit moyen
   datetime lastTraining;     // Dernier entraînement
   datetime lastPrediction;   // Dernière prédiction
   int modelsLoaded;          // Nombre de modèles chargés
};

// Récupérer les stats ML via GlobalVariables (alimentées par ai_server via feedback)
MLStats GOM_GetMLStats()
{
   MLStats stats;

   // Stats prédictions
   stats.totalPredictions = (int)GlobalVariableGet("ML_TOTAL_PREDICTIONS");
   stats.accuratePredictions = (int)GlobalVariableGet("ML_ACCURATE_PREDICTIONS");
   stats.accuracyPercent = (stats.totalPredictions > 0) ?
      (stats.accuratePredictions * 100.0 / stats.totalPredictions) : 0.0;

   // Stats trades
   stats.tradesTotal = (int)GlobalVariableGet("ML_TRADES_TOTAL");
   stats.tradesWin = (int)GlobalVariableGet("ML_TRADES_WIN");
   stats.winRate = (stats.tradesTotal > 0) ?
      (stats.tradesWin * 100.0 / stats.tradesTotal) : 0.0;
   stats.avgProfitUSD = GlobalVariableGet("ML_AVG_PROFIT_USD");

   // Timestamps
   stats.lastTraining = (datetime)GlobalVariableGet("ML_LAST_TRAINING");
   stats.lastPrediction = (datetime)GlobalVariableGet("ML_LAST_PREDICTION");
   stats.modelsLoaded = (int)GlobalVariableGet("ML_MODELS_LOADED");

   return stats;
}

// État du robot
struct RobotStatus
{
   bool isActive;             // Robot actif
   bool isPaused;             // En pause après profit
   datetime pauseUntil;       // Reprise à cette heure
   string pauseReason;        // Raison de la pause
   int positionsOpen;         // Positions ouvertes
   double dailyProfitUSD;     // Profit journalier
   double targetReachedPct;   // % de l'objectif atteint
};

// Récupérer le statut du robot
RobotStatus GOM_GetRobotStatus()
{
   RobotStatus status;

   status.isActive = GlobalVariableGet("ROBOT_ACTIVE") > 0.5;
   status.isPaused = GlobalVariableGet("ROBOT_PAUSED") > 0.5;
   status.pauseUntil = (datetime)GlobalVariableGet("ROBOT_PAUSE_UNTIL");

   // Raison de la pause
   if(status.isPaused)
   {
      double reason = GlobalVariableGet("ROBOT_PAUSE_REASON");
      if(reason == 1.0) status.pauseReason = "TARGET HIT";
      else if(reason == 2.0) status.pauseReason = "MAX DD";
      else if(reason == 3.0) status.pauseReason = "RISK LIMIT";
      else status.pauseReason = "MANUAL";
   }
   else
   {
      status.pauseReason = "";
   }

   // Positions ouvertes
   status.positionsOpen = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
         status.positionsOpen++;
   }

   // Profit journalier
   status.dailyProfitUSD = GlobalVariableGet("ROBOT_DAILY_PROFIT");
   status.targetReachedPct = GlobalVariableGet("ROBOT_TARGET_PCT");

   return status;
}

// Dessiner une cellule de tableau de bord moderne
void GOM_DrawDashCell(string objName, int x, int y, int w, int h,
                      string text, color bgColor, color txtColor, int fontSize, bool anchorTop = false)
{
   // Choisir le coin d'ancrage
   ENUM_BASE_CORNER corner = anchorTop ? CORNER_LEFT_UPPER : CORNER_LEFT_LOWER;

   // Background rectangle
   if(ObjectFind(0, objName + "_BG") < 0)
      ObjectCreate(0, objName + "_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, objName + "_BG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName + "_BG", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName + "_BG", OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName + "_BG", OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName + "_BG", OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, objName + "_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName + "_BG", OBJPROP_CORNER, corner);
   ObjectSetInteger(0, objName + "_BG", OBJPROP_BACK, false);
   ObjectSetInteger(0, objName + "_BG", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName + "_BG", OBJPROP_HIDDEN, true);

   // Text label
   if(ObjectFind(0, objName + "_TXT") < 0)
      ObjectCreate(0, objName + "_TXT", OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, objName + "_TXT", OBJPROP_XDISTANCE, x + w/2);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_YDISTANCE, y + h/2);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_COLOR, txtColor);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, objName + "_TXT", OBJPROP_FONT, "Arial");
   ObjectSetString(0, objName + "_TXT", OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_CORNER, corner);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_HIDDEN, true);
}

// Tableau de bord compact et informatif (V3 avec paramètres)
void GOM_DrawEnhancedDashboardV3(int posX = 10, int posY = 30, bool anchorTop = true, int cellWidth = 100, int cellHeight = 25, int fontSizeCustom = 8)
{
   // Nettoyer les dessins expirés d'abord
   static datetime lastClean = 0;
   if(TimeCurrent() - lastClean > 300) // Toutes les 5 minutes
   {
      GOM_CleanExpiredDrawings();
      lastClean = TimeCurrent();
   }

   MLStats ml = GOM_GetMLStats();
   RobotStatus robot = GOM_GetRobotStatus();

   // Configuration layout (paramètres personnalisables)
   int baseX = posX;
   int baseY = posY;
   int cellW = cellWidth;
   int cellH = cellHeight;
   int gap = 2;
   int fontSize = fontSizeCustom;

   color txtWhite = clrWhite;
   color bgDark = 0x1E1E1E;    // Gris très foncé
   color bgGreen = 0x2E7D32;   // Vert mat
   color bgRed = 0xC62828;     // Rouge mat
   color bgOrange = 0xEF6C00;  // Orange
   color bgBlue = 0x1565C0;    // Bleu mat

   int row = 0;

   // === LIGNE 1: STATUT ROBOT ===
   string statusTxt = robot.isActive ? "🤖 ACTIVE" : "⏸️ STOPPED";
   color statusBg = robot.isActive ? bgGreen : bgDark;

   if(robot.isPaused)
   {
      statusTxt = "⏸️ PAUSE";
      statusBg = bgOrange;
   }

   GOM_DrawDashCell("DASH_STATUS", baseX, baseY + row * (cellH + gap),
                    cellW, cellH, statusTxt, statusBg, txtWhite, fontSize, anchorTop);

   // Positions ouvertes
   string posTxt = "📊 POS:" + IntegerToString(robot.positionsOpen);
   GOM_DrawDashCell("DASH_POS", baseX + (cellW + gap), baseY + row * (cellH + gap),
                    cellW, cellH, posTxt, bgBlue, txtWhite, fontSize, anchorTop);

   // Profit journalier
   string profitTxt = "💵 " + DoubleToString(robot.dailyProfitUSD, 2) + "$";
   color profitBg = (robot.dailyProfitUSD >= 0) ? bgGreen : bgRed;
   GOM_DrawDashCell("DASH_PROFIT", baseX + 2 * (cellW + gap), baseY + row * (cellH + gap),
                    cellW, cellH, profitTxt, profitBg, txtWhite, fontSize, anchorTop);

   row++;

   // === LIGNE 2: PAUSE INFO (si en pause) ===
   if(robot.isPaused)
   {
      string pauseTxt = robot.pauseReason;
      GOM_DrawDashCell("DASH_PAUSE_REASON", baseX, baseY + row * (cellH + gap),
                       cellW, cellH, pauseTxt, bgOrange, txtWhite, fontSize - 1, anchorTop);

      // Temps restant
      int remaining = (int)(robot.pauseUntil - TimeCurrent());
      string timeTxt = "⏱️ ";
      if(remaining > 0)
      {
         int hours = remaining / 3600;
         int mins = (remaining % 3600) / 60;
         timeTxt += IntegerToString(hours) + "h" + IntegerToString(mins) + "m";
      }
      else
      {
         timeTxt += "SOON";
      }

      GOM_DrawDashCell("DASH_PAUSE_TIME", baseX + (cellW + gap), baseY + row * (cellH + gap),
                       cellW * 2 + gap, cellH, timeTxt, bgOrange, txtWhite, fontSize, anchorTop);

      row++;
   }
   else
   {
      // Supprimer les objets de pause
      ObjectDelete(0, "DASH_PAUSE_REASON_BG");
      ObjectDelete(0, "DASH_PAUSE_REASON_TXT");
      ObjectDelete(0, "DASH_PAUSE_TIME_BG");
      ObjectDelete(0, "DASH_PAUSE_TIME_TXT");
   }

   // === LIGNE 3: ML STATS ===
   // Précision ML
   string accTxt = "🎯 " + DoubleToString(ml.accuracyPercent, 1) + "%";
   color accBg = (ml.accuracyPercent >= 65) ? bgGreen :
                 (ml.accuracyPercent >= 55) ? bgOrange : bgRed;
   GOM_DrawDashCell("DASH_ML_ACC", baseX, baseY + row * (cellH + gap),
                    cellW, cellH, accTxt, accBg, txtWhite, fontSize, anchorTop);

   // Win rate
   string wrTxt = "📈 " + DoubleToString(ml.winRate, 1) + "%";
   color wrBg = (ml.winRate >= 60) ? bgGreen :
                (ml.winRate >= 50) ? bgOrange : bgRed;
   GOM_DrawDashCell("DASH_ML_WR", baseX + (cellW + gap), baseY + row * (cellH + gap),
                    cellW, cellH, wrTxt, wrBg, txtWhite, fontSize, anchorTop);

   // Modèles chargés
   string modelsTxt = "🧠 x" + IntegerToString(ml.modelsLoaded);
   GOM_DrawDashCell("DASH_ML_MODELS", baseX + 2 * (cellW + gap), baseY + row * (cellH + gap),
                    cellW, cellH, modelsTxt, bgBlue, txtWhite, fontSize, anchorTop);

   row++;

   // === LIGNE 4: ML ACTIVITY ===
   // Dernière prédiction
   int predAge = (int)(TimeCurrent() - ml.lastPrediction);
   string predTxt = "🔮 ";
   if(predAge < 60) predTxt += IntegerToString(predAge) + "s";
   else if(predAge < 3600) predTxt += IntegerToString(predAge / 60) + "m";
   else predTxt += IntegerToString(predAge / 3600) + "h";

   color predBg = (predAge < 120) ? bgGreen :
                  (predAge < 600) ? bgOrange : bgRed;
   GOM_DrawDashCell("DASH_ML_PRED", baseX, baseY + row * (cellH + gap),
                    cellW, cellH, predTxt, predBg, txtWhite, fontSize, anchorTop);

   // Total prédictions
   string totalPredTxt = "📊 " + IntegerToString(ml.totalPredictions);
   GOM_DrawDashCell("DASH_ML_TOTAL", baseX + (cellW + gap), baseY + row * (cellH + gap),
                    cellW, cellH, totalPredTxt, bgDark, txtWhite, fontSize, anchorTop);

   // Trades total
   string tradesTxt = "💼 " + IntegerToString(ml.tradesTotal);
   GOM_DrawDashCell("DASH_ML_TRADES", baseX + 2 * (cellW + gap), baseY + row * (cellH + gap),
                    cellW, cellH, tradesTxt, bgDark, txtWhite, fontSize, anchorTop);

   // Forcer le rafraîchissement
   ChartRedraw(0);
}

// Nettoyer tout le tableau de bord
void GOM_CleanEnhancedDashboard()
{
   string prefixes[] = {"DASH_STATUS", "DASH_POS", "DASH_PROFIT",
                        "DASH_PAUSE_REASON", "DASH_PAUSE_TIME",
                        "DASH_ML_ACC", "DASH_ML_WR", "DASH_ML_MODELS",
                        "DASH_ML_PRED", "DASH_ML_TOTAL", "DASH_ML_TRADES"};

   for(int i = 0; i < ArraySize(prefixes); i++)
   {
      ObjectDelete(0, prefixes[i] + "_BG");
      ObjectDelete(0, prefixes[i] + "_TXT");
   }
}
