//+------------------------------------------------------------------+
//| GOM_Enhanced_Dashboard.mqh                                        |
//| Tableau de bord amélioré avec stats ML AWS RDS                   |
//+------------------------------------------------------------------+
#property copyright "TradBOT 2026"
#property strict

// UI dashboard / scanner — ne jamais purger comme « dessin expiré »
bool GOM_IsProtectedUiObject(const string name)
{
   if(StringFind(name, "DASH_") == 0)
      return true;
   if(StringFind(name, "GOM_DASH_") == 0)
      return true;
   if(StringFind(name, "SCANNER_") == 0)
      return true;
   if(StringFind(name, "SMC_DASHBOARD") == 0)
      return true;
   if(StringFind(name, "SMC_ML_METRICS") == 0)
      return true;
   if(StringFind(name, "GOM_MLINFO") == 0)
      return true;
   if(StringFind(name, "SMC_GOM_IA") == 0)
      return true;
   return false;
}

bool GOM_IsDrawableTradeObject(const string name)
{
   if(GOM_IsProtectedUiObject(name))
      return false;
   if(StringFind(name, "GOM_") == 0)
      return true;
   if(StringFind(name, "KOLA_") == 0)
      return true;
   if(StringFind(name, "SIDO_") == 0)
      return true;
   if(StringFind(name, "SMC_") == 0)
      return true;
   if(StringFind(name, "OTE_SETUP_") == 0)
      return true;
   if(StringFind(name, "BOS_SETUP_") == 0)
      return true;
   if(StringFind(name, "CHOCH_SETUP_") == 0)
      return true;
   return false;
}

datetime GOM_ObjectNewestAnchorTime(const string name)
{
   datetime t0 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
   datetime t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
   return (t0 > t1) ? t0 : t1;
}

// Nettoyage automatique des dessins expirés (GOM/KOLA/SIDO + SMC/OTE, hors UI dashboard)
void GOM_CleanExpiredDrawings(const int maxAgeSec = 7200)
{
   datetime nowTime = TimeCurrent();
   int deleted = 0;

   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(!GOM_IsDrawableTradeObject(name))
         continue;

      long typ = (long)ObjectGetInteger(0, name, OBJPROP_TYPE);

      if(typ == OBJ_LABEL || typ == OBJ_RECTANGLE_LABEL)
         continue;

      if(typ == OBJ_HLINE)
         continue;

      datetime expiration = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
      if(expiration > 0 && expiration < nowTime)
      {
         if(ObjectDelete(0, name))
            deleted++;
         continue;
      }

      datetime tmx = GOM_ObjectNewestAnchorTime(name);
      if(tmx > 0 && nowTime - tmx > maxAgeSec)
      {
         if(ObjectDelete(0, name))
            deleted++;
      }
   }

   if(deleted > 0)
      ChartRedraw(0);
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
                  + PositionGetDouble(POSITION_COMMISSION_CURRENT);

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

datetime GOM_SanitizeEpochTimestamp(const double raw)
{
   if(raw <= 0.0)
      return 0;
   long sec = (long)raw;
   if(sec > 1000000000000L)
      sec /= 1000;
   datetime now = TimeCurrent();
   if(sec < (long)now - 3600)
      return 0;
   if(sec > (long)now + 86400 * 14)
      return 0;
   return (datetime)sec;
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
   bool utcWindowPause;       // Pause UTC hors fenêtres autorisées
   LiveMT5DashMetrics live;   // Toujours synchronisé MT5
};

// Récupérer le statut du robot
RobotStatus GOM_GetRobotStatus()
{
   RobotStatus status;

   status.isActive = (!GlobalVariableCheck("ROBOT_ACTIVE") || GlobalVariableGet("ROBOT_ACTIVE") > 0.5);
   status.pauseUntil = GOM_SanitizeEpochTimestamp(GlobalVariableGet("ROBOT_PAUSE_UNTIL"));
   status.isPaused = (GlobalVariableGet("ROBOT_PAUSED") > 0.5);
   if(status.isPaused && (status.pauseUntil == 0 || status.pauseUntil <= TimeCurrent()))
      status.isPaused = false;

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
   status.eaResumeAt = GOM_SanitizeEpochTimestamp(GlobalVariableGet("EA_DASH_RESUME_AT"));
   status.utcWindowPause = (GlobalVariableCheck("EA_DASH_UTC_PAUSE") &&
                            GlobalVariableGet("EA_DASH_UTC_PAUSE") > 0.5);

   if(!status.isPaused && status.eaResumeAt > TimeCurrent())
      status.isPaused = true;

   return status;
}

// Nombre de lignes dans un libellé multi-lignes
int GOM_DashTextLineCount(const string text)
{
   int n = 1;
   for(int i = 0; i < StringLen(text); i++)
      if(StringGetCharacter(text, i) == '\n')
         n++;
   return n;
}

// Hauteur minimale de cellule selon le contenu (évite débordement)
int GOM_DashRowHeight(const int baseH, const string text, const int fontSize)
{
   int lines = GOM_DashTextLineCount(text);
   int linePx = MathMax(11, fontSize + 4);
   int need = lines * linePx + 10;
   return MathMax(baseH, need);
}

// Tronquer une ligne pour éviter le débordement horizontal
string GOM_DashTruncate(const string text, const int maxChars)
{
   if(maxChars < 8)
      return text;
   int len = StringLen(text);
   if(len <= maxChars)
      return text;
   return StringSubstr(text, 0, maxChars - 3) + "...";
}

int GOM_DashBarWidth(const int baseX, const int preferredW)
{
   int chartPixW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   if(chartPixW < 400)
      chartPixW = 1200;
   int avail = chartPixW - baseX - 14;
   int w = preferredW;
   if(w > avail)
      w = avail;
   if(w < 200)
      w = MathMax(200, avail);
   return w;
}

void GOM_DrawDashRow(string objName, int x, int &cy, int w, int rowH, int gap,
                     string text, color bgColor, color txtColor, int fontSize, bool anchorTop)
{
   int maxCh = MathMax(24, w / MathMax(6, fontSize + 1));
   GOM_DrawDashCell(objName, x, cy, w, rowH, GOM_DashTruncate(text, maxCh),
                    bgColor, txtColor, fontSize, anchorTop);
   cy += rowH + gap;
}

// Dessiner une cellule de tableau de bord (texte aligné en haut à gauche)
void GOM_DrawDashCell(string objName, int x, int y, int w, int h,
                      string text, color bgColor, color txtColor, int fontSize, bool anchorTop = false)
{
   ENUM_BASE_CORNER corner = anchorTop ? CORNER_LEFT_UPPER : CORNER_LEFT_LOWER;
   int pad = 5;
   int lines = GOM_DashTextLineCount(text);
   int fs = fontSize;
   if(lines >= 4) fs = MathMax(6, fontSize - 2);
   else if(lines >= 3) fs = MathMax(7, fontSize - 1);

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
   ObjectSetInteger(0, objName + "_BG", OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, objName + "_BG", OBJPROP_ZORDER, 2000);
   ObjectSetInteger(0, objName + "_BG", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

   if(ObjectFind(0, objName + "_TXT") < 0)
      ObjectCreate(0, objName + "_TXT", OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, objName + "_TXT", OBJPROP_COLOR, txtColor);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_FONTSIZE, fs);
   ObjectSetString(0, objName + "_TXT", OBJPROP_FONT, "Arial");
   ObjectSetString(0, objName + "_TXT", OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_CORNER, corner);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_XDISTANCE, x + pad);
   if(anchorTop)
      ObjectSetInteger(0, objName + "_TXT", OBJPROP_YDISTANCE, y + pad);
   else
      ObjectSetInteger(0, objName + "_TXT", OBJPROP_YDISTANCE, y + h - pad);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_BACK, false);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_ZORDER, 2001);
   ObjectSetInteger(0, objName + "_TXT", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

// Tableau de bord vertical — une ligne par bandeau (évite chevauchement)
void GOM_DrawEnhancedDashboardV3(int posX = 10, int posY = 30, bool anchorTop = true, int cellWidth = 100, int cellHeight = 25, int fontSizeCustom = 8)
{
   GOM_CleanEnhancedDashboard();

   MLStats ml = GOM_GetMLStats();
   RobotStatus robot = GOM_GetRobotStatus();
   LiveMT5DashMetrics lv = robot.live;

   int baseX = posX;
   int cy = posY;
   int gap = 2;
   int fontSize = MathMax(6, MathMin(10, fontSizeCustom));
   int rowH = MathMax(18, fontSize + 11);
   int barW = GOM_DashBarWidth(baseX, MathMax(260, cellWidth * 2));

   color txtWhite = clrWhite;
   color bgDark = 0x1E1E1E;
   color bgGreen = 0x2E7D32;
   color bgRed = 0xC62828;
   color bgOrange = 0xEF6C00;
   color bgBlue = 0x1565C0;
   color bgPurple = 0x4527A0;

   string accCur = AccountInfoString(ACCOUNT_CURRENCY);
   int spreadPts = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   string hdrLine = _Symbol + " " + GOM_ChartPeriodTag() + " | "
                    + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES)
                    + " | spr " + IntegerToString(spreadPts)
                    + " | " + accCur + " 1:" + IntegerToString((int)lv.leverage);
   GOM_DrawDashRow("DASH_HDR", baseX, cy, barW, rowH, gap, hdrLine, bgPurple, txtWhite, fontSize, anchorTop);

   bool termAuto = (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) != 0);
   string statusWord = "ACTIF";
   color statusBg = bgGreen;
   if(robot.utcWindowPause)
   {
      statusWord = "PAUSE UTC";
      statusBg = bgOrange;
   }
   else if(robot.isPaused)
   {
      statusWord = "PAUSE";
      statusBg = bgOrange;
   }
   else if(!termAuto)
   {
      statusWord = "AUTO OFF";
      statusBg = bgDark;
   }
   else if(!robot.eaTradingEnabled)
   {
      statusWord = "STOP";
      statusBg = bgDark;
   }

   string rowStat = statusWord + " | POS " + IntegerToString(robot.positionsOpen)
                    + " " + DoubleToString(lv.lotsOnSymbol, 2) + " lot"
                    + " | Eq " + DoubleToString(lv.equity, 2)
                    + " Bal " + DoubleToString(lv.balance, 2)
                    + " Fl " + DoubleToString(lv.floatingPL, 2);
   GOM_DrawDashRow("DASH_STATUS", baseX, cy, barW, rowH, gap, rowStat, statusBg, txtWhite, fontSize, anchorTop);

   string mlvlStr = "-";
   if(lv.marginUsed > 1e-8 && lv.marginLevelPct > 1e-8 && lv.marginLevelPct < 999999.0)
      mlvlStr = DoubleToString(lv.marginLevelPct, 1) + "%";

   string rowAcct = "Compte POS " + IntegerToString(lv.positionsAccount)
                    + " Lots " + DoubleToString(lv.lotsAccount, 2)
                    + " | Marge U " + DoubleToString(lv.marginUsed, 2)
                    + " Lib " + DoubleToString(lv.marginFree, 2)
                    + " | Mg " + mlvlStr
                    + " Real " + DoubleToString(lv.realizedTodayUSD, 2)
                    + " FlSym " + DoubleToString(lv.floatingOnSymbol, 2);
   GOM_DrawDashRow("DASH_ACCT", baseX, cy, barW, rowH, gap, rowAcct, bgBlue, txtWhite, fontSize, anchorTop);

   if(robot.utcWindowPause)
   {
      MqlDateTime gmt;
      TimeToStruct(TimeGMT(), gmt);
      string utcLine = "UTC ferme (h" + IntegerToString(gmt.hour) + " UTC) | voir TradeWindow*";
      GOM_DrawDashRow("DASH_UTC", baseX, cy, barW, rowH, gap, utcLine, bgOrange, txtWhite, fontSize, anchorTop);
   }

   if(robot.isPaused)
   {
      int remaining = (int)(robot.pauseUntil - TimeCurrent());
      string pauseLine = "Pause: " + robot.pauseReason;
      if(remaining > 0)
      {
         int hours = remaining / 3600;
         int mins = (remaining % 3600) / 60;
         pauseLine += " | fin dans " + IntegerToString(hours) + "h" + IntegerToString(mins) + "m";
      }
      else
         pauseLine += " | bientot";
      GOM_DrawDashRow("DASH_PAUSE", baseX, cy, barW, rowH, gap, pauseLine, bgOrange, txtWhite, fontSize, anchorTop);
   }

   datetime nowTc = TimeCurrent();
   if(!robot.eaTradingEnabled)
   {
      GOM_DrawDashRow("DASH_EA_RESUME", baseX, cy, barW, rowH, gap,
                      "Trading OFF | activer EnableTrading", bgDark, txtWhite, fontSize, anchorTop);
   }
   else if(robot.eaResumeAt > nowTc)
   {
      int rem = (int)(robot.eaResumeAt - nowTc);
      int h = rem / 3600;
      int m = (rem % 3600) / 60;
      int s = rem % 60;
      int tzOff = (int)(TimeLocal() - TimeCurrent());
      datetime resumeLocal = (datetime)((long)robot.eaResumeAt + (long)tzOff);
      string resumeLine = "Reprise " + IntegerToString(h) + "h" + IntegerToString(m) + "m" + IntegerToString(s) + "s"
                          + " | " + TimeToString(resumeLocal, TIME_DATE | TIME_MINUTES);
      GOM_DrawDashRow("DASH_EA_RESUME", baseX, cy, barW, rowH, gap, resumeLine, bgOrange, txtWhite, fontSize, anchorTop);
   }

   string mlPrec = "ML prec. -";
   if(ml.totalPredictions > 0)
      mlPrec = "ML prec. " + DoubleToString(ml.accuracyPercent, 1) + "% WR "
               + DoubleToString(ml.winRate, 1) + "%";

   int dispW = lv.winsToday;
   int dispL = lv.lossesToday;
   string daySrc = "MT5";
   if(GlobalVariableCheck("EA_DASH_TRADES_DAY"))
   {
      daySrc = "EA";
      dispW = (int)GlobalVariableGet("EA_DASH_WINS_DAY");
      dispL = (int)GlobalVariableGet("EA_DASH_LOSSES_DAY");
   }
   int wl = dispW + dispL;
   string dayLine = daySrc + " jour W" + IntegerToString(dispW) + " L" + IntegerToString(dispL);
   if(wl > 0)
      dayLine += " (" + DoubleToString(100.0 * dispW / wl, 0) + "%)";

   string cloudLine = "Cloud Tr " + IntegerToString(ml.tradesTotal)
                      + " G " + IntegerToString(ml.tradesWin)
                      + " | Mod x" + IntegerToString(ml.modelsLoaded);
   string rowMl = mlPrec + " | " + dayLine + " | " + cloudLine;
   color dayBg = bgDark;
   if(wl > 0)
   {
      double dayWr = 100.0 * dispW / wl;
      dayBg = (dayWr >= 55.0) ? bgGreen : ((dayWr >= 45.0) ? bgOrange : bgRed);
   }
   GOM_DrawDashRow("DASH_ML", baseX, cy, barW, rowH, gap, rowMl, dayBg, txtWhite, fontSize, anchorTop);

   string predAgeTxt = "-";
   color predBg = bgDark;
   if(ml.lastPrediction > 0)
   {
      int predAge = (int)(TimeCurrent() - ml.lastPrediction);
      if(predAge < 60)
         predAgeTxt = IntegerToString(predAge) + "s";
      else if(predAge < 3600)
         predAgeTxt = IntegerToString(predAge / 60) + "m";
      else if(predAge < 86400 * 365)
         predAgeTxt = IntegerToString(predAge / 3600) + "h";
      predBg = (predAge < 120) ? bgGreen : ((predAge < 600) ? bgOrange : bgRed);
   }
   string trainTxt = "-";
   if(ml.lastTraining > 0)
      trainTxt = TimeToString(ml.lastTraining, TIME_DATE | TIME_MINUTES);

   string rowPred = "Pred " + predAgeTxt + " | Train " + trainTxt
                    + " | Clot " + IntegerToString(lv.closedDealsToday)
                    + " | PredTot " + IntegerToString(ml.totalPredictions)
                    + " | Cible " + DoubleToString(robot.targetReachedPct, 0) + "%";
   GOM_DrawDashRow("DASH_PRED", baseX, cy, barW, rowH, gap, rowPred, predBg, txtWhite, fontSize, anchorTop);

   string srvMode = "?";
   long tmAcc = AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(tmAcc == ACCOUNT_TRADE_MODE_DEMO) srvMode = "Demo";
   else if(tmAcc == ACCOUNT_TRADE_MODE_REAL) srvMode = "Reel";
   else if(tmAcc == ACCOUNT_TRADE_MODE_CONTEST) srvMode = "Contest";

   color pnlBg = (robot.dailyProfitUSD >= 0.0) ? bgGreen : bgRed;
   string rowPnl = "P&L jr " + DoubleToString(robot.dailyProfitUSD, 2) + " " + accCur
                   + " | Fl sym " + DoubleToString(lv.floatingOnSymbol, 2)
                   + " | " + srvMode;
   GOM_DrawDashRow("DASH_PNL", baseX, cy, barW, rowH, gap, rowPnl, pnlBg, txtWhite, fontSize, anchorTop);

   ChartRedraw(0);
}

void GOM_DrawEnhancedDashboard(void)
{
   GOM_DrawEnhancedDashboardV3();
}

// Nettoyer tout le tableau de bord (y compris anciennes cellules grille)
void GOM_CleanEnhancedDashboard()
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "DASH_") == 0)
         ObjectDelete(0, name);
   }
}
