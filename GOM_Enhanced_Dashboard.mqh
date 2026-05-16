//+------------------------------------------------------------------+
//| GOM_Enhanced_Dashboard.mqh                                        |
//| Tableau de bord amélioré avec stats ML AWS RDS                   |
//+------------------------------------------------------------------+
#property copyright "TradBOT 2026"
#property strict

// Nettoyage automatique des dessins expirés (GOM/KOLA/SIDO + SMC/OTE graphe, hors labels UI)
void GOM_CleanExpiredDrawings()
{
   const int maxAgeSec = 14400; // 4h — aligné tendances GOM
   datetime nowTime = TimeCurrent();
   int total = ObjectsTotal(0, 0, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      long typ = (long)ObjectGetInteger(0, name, OBJPROP_TYPE);

      bool isGomFamily = (StringFind(name, "GOM_") == 0 ||
                          StringFind(name, "KOLA_") == 0 ||
                          StringFind(name, "SIDO_") == 0);
      if(isGomFamily)
      {
         datetime expiration = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
         if(expiration > 0 && expiration < nowTime)
         {
            ObjectDelete(0, name);
            continue;
         }

         if(typ == OBJ_TREND)
         {
            datetime objTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
            datetime objTime2 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
            datetime tmx = (objTime > objTime2) ? objTime : objTime2;
            if(nowTime - tmx > maxAgeSec)
               ObjectDelete(0, name);
         }
         continue;
      }

      bool isChartStale = (StringFind(name, "SMC_") == 0 || StringFind(name, "OTE_SETUP_") == 0);
      if(!isChartStale)
         continue;

      if(typ == OBJ_LABEL || typ == OBJ_RECTANGLE_LABEL)
         continue;

      if(typ == OBJ_HLINE)
         continue;

      if(typ == OBJ_TREND)
      {
         datetime t0 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
         datetime t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
         datetime tmx = (t0 > t1) ? t0 : t1;
         if(tmx > 0 && nowTime - tmx > maxAgeSec)
            ObjectDelete(0, name);
      }
      else if(typ == OBJ_TEXT || typ == OBJ_ARROW)
      {
         datetime t0 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
         if(t0 > 0 && nowTime - t0 > maxAgeSec)
            ObjectDelete(0, name);
      }
      else if(typ == OBJ_RECTANGLE || typ == OBJ_VLINE || typ == OBJ_FIBO)
      {
         datetime t0 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
         datetime t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
         datetime tmx = (t0 > t1) ? t0 : t1;
         if(tmx > 0 && nowTime - tmx > maxAgeSec)
            ObjectDelete(0, name);
      }
   }
}

// Libellé court du timeframe du graphique
string GOM_ChartPeriodTag(void)
{
   switch(_Period)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return "TF";
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

// Début de journée serveur (minuit broker) pour agréger l’historique « aujourd’hui »
datetime GOM_BrokerDayStart(datetime serverNow)
{
   MqlDateTime t;
   TimeToStruct(serverNow, t);
   t.hour = 0;
   t.min = 0;
   t.sec = 0;
   return StructToTime(t);
}

// Métriques compte / symbole directement depuis MT5 (hors GlobalVariables RDS)
struct LiveMT5DashMetrics
{
   double balance;
   double equity;
   double marginUsed;
   double marginFree;
   double floatingPL;
   int    positionsOnSymbol;
   double lotsOnSymbol;
   double floatingOnSymbol;
   int    closedDealsToday;
   int    winsToday;
   int    lossesToday;
   double realizedTodayUSD;
   int    positionsAccount;
   double lotsAccount;
   double marginLevelPct;
   long   leverage;
};

void GOM_ComputeLiveMT5DashMetrics(LiveMT5DashMetrics &m)
{
   m.balance = AccountInfoDouble(ACCOUNT_BALANCE);
   m.equity = AccountInfoDouble(ACCOUNT_EQUITY);
   m.marginUsed = AccountInfoDouble(ACCOUNT_MARGIN);
   m.marginFree = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   m.floatingPL = AccountInfoDouble(ACCOUNT_PROFIT);

   m.positionsOnSymbol = 0;
   m.lotsOnSymbol = 0.0;
   m.floatingOnSymbol = 0.0;
   m.positionsAccount = 0;
   m.lotsAccount = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double fp = PositionGetDouble(POSITION_PROFIT)
                  + PositionGetDouble(POSITION_SWAP)
                  + PositionGetDouble(POSITION_COMMISSION);

      m.positionsAccount++;
      m.lotsAccount += vol;

      if(sym == _Symbol)
      {
         m.positionsOnSymbol++;
         m.lotsOnSymbol += vol;
         m.floatingOnSymbol += fp;
      }
   }

   m.leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   m.marginLevelPct = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   m.closedDealsToday = 0;
   m.winsToday = 0;
   m.lossesToday = 0;
   m.realizedTodayUSD = 0.0;

   datetime day0 = GOM_BrokerDayStart(TimeCurrent());
   datetime now = TimeCurrent() + 60;
   if(!HistorySelect(day0, now))
      return;

   for(int j = HistoryDealsTotal() - 1; j >= 0; j--)
   {
      ulong deal = HistoryDealGetTicket(j);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;

      ENUM_DEAL_ENTRY ent = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(ent != DEAL_ENTRY_OUT && ent != DEAL_ENTRY_OUT_BY)
         continue;

      ENUM_DEAL_TYPE dtyp = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(dtyp != DEAL_TYPE_BUY && dtyp != DEAL_TYPE_SELL)
         continue;

      double net = HistoryDealGetDouble(deal, DEAL_PROFIT)
                  + HistoryDealGetDouble(deal, DEAL_SWAP)
                  + HistoryDealGetDouble(deal, DEAL_COMMISSION);

      m.closedDealsToday++;
      m.realizedTodayUSD += net;
      if(net > 1e-8)
         m.winsToday++;
      else if(net < -1e-8)
         m.lossesToday++;
   }
}

// État du robot
struct RobotStatus
{
   bool isActive;             // Robot actif (GV optionnelle ML/sync)
   bool isPaused;             // En pause après profit
   datetime pauseUntil;       // Reprise à cette heure
   string pauseReason;        // Raison de la pause
   int positionsOpen;         // Positions ouvertes sur _Symbol
   double dailyProfitUSD;     // Profit journalier (GV ou complément ML)
   double targetReachedPct;   // % de l'objectif atteint
   bool eaTradingEnabled;     // EnableTrading (EA) — poussé par SMC_Universal
   datetime eaResumeAt;       // Fin de pause « interne » EA (serveur), 0 = aucune
   LiveMT5DashMetrics live;   // Toujours synchronisé MT5
};

// Récupérer le statut du robot
RobotStatus GOM_GetRobotStatus()
{
   RobotStatus status;

   status.isActive = (!GlobalVariableCheck("ROBOT_ACTIVE") || GlobalVariableGet("ROBOT_ACTIVE") > 0.5);
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

   GOM_ComputeLiveMT5DashMetrics(status.live);

   status.positionsOpen = status.live.positionsOnSymbol;

   // Profit « jour » affiché : réalisé (historique) + flottant symbole ; sinon fallback GV ML
   double liveDay = status.live.realizedTodayUSD + status.live.floatingOnSymbol;
   double gvDay = GlobalVariableGet("ROBOT_DAILY_PROFIT");
   status.dailyProfitUSD = liveDay;
   if(status.live.closedDealsToday == 0 && MathAbs(status.live.floatingOnSymbol) < 1e-8 &&
      GlobalVariableCheck("ROBOT_DAILY_PROFIT"))
      status.dailyProfitUSD = gvDay;

   status.targetReachedPct = GlobalVariableGet("ROBOT_TARGET_PCT");

   status.eaTradingEnabled = (!GlobalVariableCheck("EA_DASH_ENABLE_TRADING") ||
                              GlobalVariableGet("EA_DASH_ENABLE_TRADING") > 0.5);
   status.eaResumeAt = (datetime)GlobalVariableGet("EA_DASH_RESUME_AT");

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
   LiveMT5DashMetrics lv = robot.live;

   int baseX = posX;
   int cy = posY;
   int cellW = cellWidth;
   int cellH = cellHeight;
   int gap = 2;
   int fontSize = fontSizeCustom;

   color txtWhite = clrWhite;
   color bgDark = 0x1E1E1E;
   color bgGreen = 0x2E7D32;
   color bgRed = 0xC62828;
   color bgOrange = 0xEF6C00;
   color bgBlue = 0x1565C0;
   color bgPurple = 0x4527A0;

   int spanW = cellW * 3 + gap * 2;
   string accCur = AccountInfoString(ACCOUNT_CURRENCY);
   int spreadPts = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   // Ligne 0 — bandeau identité graphique + spread + devise + levier
   int hdrH = cellH + 22;
   string hdrTxt = _Symbol + "  " + GOM_ChartPeriodTag()
                   + "\n" + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS)
                   + "  spr " + IntegerToString(spreadPts)
                   + "\n" + accCur + "  |  lev 1:" + IntegerToString((int)lv.leverage);
   GOM_DrawDashCell("DASH_HDR", baseX, cy, spanW, hdrH, hdrTxt, bgPurple, txtWhite, fontSize - 1, anchorTop);
   cy += hdrH + gap;

   // Ligne 1 — état + positions sur ce symbole + equity / balance / flottant total
   bool termAuto = (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) != 0);
   string statusTxt = "🤖 ACTIVE";
   color statusBg = bgGreen;

   if(robot.isPaused)
   {
      statusTxt = "⏸️ PAUSE";
      statusBg = bgOrange;
   }
   else if(!termAuto)
   {
      statusTxt = "🔒 AUTO OFF";
      statusBg = bgDark;
   }
   else if(!robot.eaTradingEnabled)
   {
      statusTxt = "⏸️ STOPPED";
      statusBg = bgDark;
   }

   int r1h = cellH + 8;
   GOM_DrawDashCell("DASH_STATUS", baseX, cy, cellW, r1h, statusTxt, statusBg, txtWhite, fontSize, anchorTop);

   string posTxt = "📊 Ce symbole\nPOS " + IntegerToString(robot.positionsOpen)
                   + "\n" + DoubleToString(lv.lotsOnSymbol, 2) + " lot";
   GOM_DrawDashCell("DASH_POS", baseX + (cellW + gap), cy, cellW, r1h, posTxt, bgBlue, txtWhite, fontSize - 1, anchorTop);

   string profitTxt = "💰 Equity\n" + DoubleToString(lv.equity, 2)
                      + "\nBal " + DoubleToString(lv.balance, 2)
                      + "\nFl Σ " + DoubleToString(lv.floatingPL, 2);
   color profitBg = (lv.floatingPL >= 0.0) ? bgGreen : bgRed;
   GOM_DrawDashCell("DASH_PROFIT", baseX + 2 * (cellW + gap), cy, cellW, r1h, profitTxt, profitBg, txtWhite, fontSize - 1, anchorTop);
   cy += r1h + gap;

   // Ligne 2 — exposition totale compte + marges + P&L réalisé jour (symbole) + flottant symbole
   int r2h = cellH + 14;
   string mlvlStr = "—";
   if(lv.marginUsed > 1e-8 && lv.marginLevelPct > 1e-8 && lv.marginLevelPct < 999999.0)
      mlvlStr = DoubleToString(lv.marginLevelPct, 1) + "%";

   string acct1 = "🌐 Compte\nPOS " + IntegerToString(lv.positionsAccount)
                  + "\nLots Σ " + DoubleToString(lv.lotsAccount, 2);
   GOM_DrawDashCell("DASH_ACCT1", baseX, cy, cellW, r2h, acct1, bgBlue, txtWhite, fontSize - 1, anchorTop);

   string acct2 = "⚓ Marge\nU " + DoubleToString(lv.marginUsed, 2)
                  + "\nLibre " + DoubleToString(lv.marginFree, 2);
   GOM_DrawDashCell("DASH_ACCT2", baseX + (cellW + gap), cy, cellW, r2h, acct2, bgOrange, txtWhite, fontSize - 1, anchorTop);

   string acct3 = "📐 Mg lvl\n" + mlvlStr
                  + "\nRéal jr\n" + DoubleToString(lv.realizedTodayUSD, 2)
                  + "\nFl sym\n" + DoubleToString(lv.floatingOnSymbol, 2);
   GOM_DrawDashCell("DASH_ACCT3", baseX + 2 * (cellW + gap), cy, cellW, r2h, acct3, bgDark, txtWhite, fontSize - 1, anchorTop);
   cy += r2h + gap;

   // === PAUSE ML (GV) ===
   if(robot.isPaused)
   {
      string pauseTxt = robot.pauseReason;
      GOM_DrawDashCell("DASH_PAUSE_REASON", baseX, cy,
                       cellW, cellH, pauseTxt, bgOrange, txtWhite, fontSize - 1, anchorTop);

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

      GOM_DrawDashCell("DASH_PAUSE_TIME", baseX + (cellW + gap), cy,
                       cellW * 2 + gap, cellH, timeTxt, bgOrange, txtWhite, fontSize, anchorTop);

      cy += cellH + gap;
   }
   else
   {
      // Supprimer les objets de pause
      ObjectDelete(0, "DASH_PAUSE_REASON_BG");
      ObjectDelete(0, "DASH_PAUSE_REASON_TXT");
      ObjectDelete(0, "DASH_PAUSE_TIME_BG");
      ObjectDelete(0, "DASH_PAUSE_TIME_TXT");
   }

   // === REPRISE / PAUSE CÔTÉ EA (vide EnableTrading, pauses jour, symbole, pertes…) ===
   {
      datetime nowTc = TimeCurrent();
      bool showEaResumeRow = false;
      string eaResumeTxt = "";
      color eaResumeBg = bgOrange;

      if(!robot.eaTradingEnabled)
      {
         showEaResumeRow = true;
         eaResumeTxt = "Trading OFF\n(Activez EnableTrading)";
         eaResumeBg = bgDark;
      }
      else if(robot.eaResumeAt > nowTc)
      {
         showEaResumeRow = true;
         int rem = (int)(robot.eaResumeAt - nowTc);
         int h = rem / 3600;
         int m = (rem % 3600) / 60;
         int s = rem % 60;
         int tzOff = (int)(TimeLocal() - TimeCurrent());
         datetime resumeLocal = (datetime)((long)robot.eaResumeAt + (long)tzOff);
         eaResumeTxt = "Reprise dans " + IntegerToString(h) + "h " + IntegerToString(m) + "m " + IntegerToString(s) + "s\n"
                       + "À " + TimeToString(resumeLocal, TIME_DATE | TIME_MINUTES | TIME_SECONDS) + " (heure locale)";
      }

      if(showEaResumeRow)
      {
         int resumeH = cellH + 12;
         GOM_DrawDashCell("DASH_EA_RESUME", baseX, cy,
                          cellW * 3 + gap * 2, resumeH, eaResumeTxt, eaResumeBg, txtWhite, fontSize - 1, anchorTop);
         cy += resumeH + gap;
      }
      else
      {
         ObjectDelete(0, "DASH_EA_RESUME_BG");
         ObjectDelete(0, "DASH_EA_RESUME_TXT");
      }
   }

   // === ML cloud + stats jour (EA vs MT5) ===
   int rMl = cellH + 12;

   string accTxt = "☁ ML préc.\n";
   color accBg = bgDark;
   if(ml.totalPredictions > 0)
   {
      accTxt += DoubleToString(ml.accuracyPercent, 1) + "%\n☁ WR "
                + DoubleToString(ml.winRate, 1) + "%";
      accBg = (ml.accuracyPercent >= 65) ? bgGreen :
              (ml.accuracyPercent >= 55) ? bgOrange : bgRed;
   }
   else
      accTxt += "— (RDS)";

   GOM_DrawDashCell("DASH_ML_ACC", baseX, cy, cellW, rMl, accTxt, accBg, txtWhite, fontSize - 1, anchorTop);

   int wl = lv.winsToday + lv.lossesToday;
   double dayWr = (wl > 0) ? (100.0 * (double)lv.winsToday / (double)wl) : 0.0;
   string daySrc = "MT5";
   int dispW = lv.winsToday;
   int dispL = lv.lossesToday;

   if(GlobalVariableCheck("EA_DASH_TRADES_DAY"))
   {
      daySrc = "EA";
      dispW = (int)GlobalVariableGet("EA_DASH_WINS_DAY");
      dispL = (int)GlobalVariableGet("EA_DASH_LOSSES_DAY");
      wl = dispW + dispL;
      dayWr = (wl > 0) ? (100.0 * (double)dispW / (double)wl) : 0.0;
   }

   string wrTxt = "📅 " + daySrc + " jour\nW" + IntegerToString(dispW)
                  + " L" + IntegerToString(dispL);
   if(wl > 0)
      wrTxt += "\n" + DoubleToString(dayWr, 0) + "%";
   color wrBg = (wl == 0) ? bgDark :
                (dayWr >= 55.0) ? bgGreen :
                (dayWr >= 45.0) ? bgOrange : bgRed;
   GOM_DrawDashCell("DASH_ML_WR", baseX + (cellW + gap), cy, cellW, rMl, wrTxt, wrBg, txtWhite, fontSize - 1, anchorTop);

   string cloudTxt = "☁ Cloud hist.\nTr " + IntegerToString(ml.tradesTotal)
                     + " | G " + IntegerToString(ml.tradesWin)
                     + "\nØ " + DoubleToString(ml.avgProfitUSD, 2) + " " + accCur
                     + "\nMod x" + IntegerToString(ml.modelsLoaded);
   color cloudBg = (ml.tradesTotal > 0) ? bgBlue : bgDark;
   GOM_DrawDashCell("DASH_ML_MODELS", baseX + 2 * (cellW + gap), cy, cellW, rMl, cloudTxt, cloudBg, txtWhite, fontSize - 1, anchorTop);
   cy += rMl + gap;

   // === Dernière synchro ML + détail clôtures + P&L combiné ===
   int rBot = cellH + 12;

   string trainTxt = "—";
   if(ml.lastTraining > 0)
      trainTxt = TimeToString(ml.lastTraining, TIME_DATE | TIME_MINUTES);

   string predTxt = "🔮 Age pred.\n";
   color predBg = bgDark;
   if(ml.lastPrediction <= 0)
      predTxt += "—";
   else
   {
      int predAge = (int)(TimeCurrent() - ml.lastPrediction);
      if(predAge < 60)
         predTxt += IntegerToString(predAge) + "s";
      else if(predAge < 3600)
         predTxt += IntegerToString(predAge / 60) + "m";
      else if(predAge < 86400 * 365)
         predTxt += IntegerToString(predAge / 3600) + "h";
      else
         predTxt += "—";

      predBg = (predAge < 120) ? bgGreen :
               (predAge < 600) ? bgOrange : bgRed;
   }
   predTxt += "\nTrain\n" + trainTxt;

   GOM_DrawDashCell("DASH_ML_PRED", baseX, cy, cellW, rBot, predTxt, predBg, txtWhite, fontSize - 1, anchorTop);

   string totalPredTxt = "📊 Broker jr\nClôtures " + IntegerToString(lv.closedDealsToday)
                         + "\nPrédit. " + IntegerToString(ml.totalPredictions)
                         + "\nCible % " + DoubleToString(robot.targetReachedPct, 0);
   GOM_DrawDashCell("DASH_ML_TOTAL", baseX + (cellW + gap), cy, cellW, rBot, totalPredTxt, bgDark, txtWhite, fontSize - 1, anchorTop);

   string srvMode = "?";
   long tmAcc = AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(tmAcc == ACCOUNT_TRADE_MODE_DEMO) srvMode = "Démo";
   else if(tmAcc == ACCOUNT_TRADE_MODE_REAL) srvMode = "Réel";
   else if(tmAcc == ACCOUNT_TRADE_MODE_CONTEST) srvMode = "Contest";

   string tradesTxt = "Σ P&L jr\n" + DoubleToString(robot.dailyProfitUSD, 2) + " " + accCur
                      + "\nFl sym " + DoubleToString(lv.floatingOnSymbol, 2)
                      + "\n" + srvMode;
   color tradesBg = (robot.dailyProfitUSD >= 0.0) ? bgGreen : bgRed;
   GOM_DrawDashCell("DASH_ML_TRADES", baseX + 2 * (cellW + gap), cy, cellW, rBot, tradesTxt, tradesBg, txtWhite, fontSize - 1, anchorTop);
   // Forcer le rafraîchissement
   ChartRedraw(0);
}

// Nettoyer tout le tableau de bord
void GOM_CleanEnhancedDashboard()
{
   string prefixes[] = {"DASH_HDR",
                        "DASH_STATUS", "DASH_POS", "DASH_PROFIT",
                        "DASH_ACCT1", "DASH_ACCT2", "DASH_ACCT3",
                        "DASH_PAUSE_REASON", "DASH_PAUSE_TIME", "DASH_EA_RESUME",
                        "DASH_ML_ACC", "DASH_ML_WR", "DASH_ML_MODELS",
                        "DASH_ML_PRED", "DASH_ML_TOTAL", "DASH_ML_TRADES"};

   for(int i = 0; i < ArraySize(prefixes); i++)
   {
      ObjectDelete(0, prefixes[i] + "_BG");
      ObjectDelete(0, prefixes[i] + "_TXT");
   }
}
