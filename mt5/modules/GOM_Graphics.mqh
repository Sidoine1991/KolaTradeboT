//+------------------------------------------------------------------+
//| GOM_Graphics.mqh � Dessine Bollinger + Zones futures            |
//+------------------------------------------------------------------+
#ifndef GOM_GRAPHICS_MQH
#define GOM_GRAPHICS_MQH

//+------------------------------------------------------------------+
// Dessiner les bandes Bollinger depuis GOM
//+------------------------------------------------------------------+
void GOMG_DrawBollinger(double bb_up, double bb_mid, double bb_dn)
{
   if(bb_up <= 0 || bb_mid <= 0 || bb_dn <= 0) return;

   datetime now = TimeCurrent();
   datetime future = now + 3600; // 1 heure dans le futur

   // Bande sup�rieure (OBJ_TREND = droite)
   string bbUpName = "GOM_BB_UP";
   ObjectDelete(0, bbUpName);
   ObjectCreate(0, bbUpName, OBJ_TREND, 0, now, bb_up, future, bb_up);
   ObjectSetInteger(0, bbUpName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, bbUpName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bbUpName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, bbUpName, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, bbUpName, OBJPROP_BACK, false);

   // Bande du milieu (OBJ_TREND = droite)
   string bbMidName = "GOM_BB_MID";
   ObjectDelete(0, bbMidName);
   ObjectCreate(0, bbMidName, OBJ_TREND, 0, now, bb_mid, future, bb_mid);
   ObjectSetInteger(0, bbMidName, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, bbMidName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, bbMidName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, bbMidName, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, bbMidName, OBJPROP_BACK, false);

   // Bande inf�rieure (OBJ_TREND = droite)
   string bbDnName = "GOM_BB_DN";
   ObjectDelete(0, bbDnName);
   ObjectCreate(0, bbDnName, OBJ_TREND, 0, now, bb_dn, future, bb_dn);
   ObjectSetInteger(0, bbDnName, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, bbDnName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bbDnName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, bbDnName, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, bbDnName, OBJPROP_BACK, false);

   Print("[GOMG] Bollinger dessin�es: UP=", bb_up, " MID=", bb_mid, " DN=", bb_dn);
}

//+------------------------------------------------------------------+
// Trajectoire GOM Prediction — 5 segments basés sur données réelles   |
// Synthése: cognition + GOM verdict + global direction + pred arrays  |
//+------------------------------------------------------------------+
void GOMG_DrawFutureZone(double zone_high, double zone_low, string label = "GOM_FUTURE_ZONE",
                         int gomDir = 0, double currentPrice = 0)
{
   if(zone_high <= 0 || zone_low <= 0) return;
   if(zone_high <= zone_low) return;

   // Nettoyer les anciens objets
   ObjectsDeleteAll(0, label);
   ObjectsDeleteAll(0, label + "_SEG");
   ObjectsDeleteAll(0, label + "_ARROW");
   ObjectsDeleteAll(0, label + "_LBL");
   ObjectsDeleteAll(0, label + "_INFO");

   // === 1. SYNTHÉSE DIRECTION ===
   // Sources: g_cogDirection, g_smcGomVerdictNum, g_smcGomGlobalDir
   int score = 0;  // +N = BUY, -N = SELL
   int sources = 0;

   if(StringLen(g_cogDirection) > 0)
   {
      if(g_cogDirection == "BUY")  score += 1;
      if(g_cogDirection == "SELL") score -= 1;
      sources++;
   }
   if(gomDir != 0)
   {
      score += (gomDir > 0) ? 1 : -1;
      sources++;
   }
   if(StringLen(g_smcGomGlobalDir) > 0)
   {
      if(g_smcGomGlobalDir == "BULL") score += 1;
      if(g_smcGomGlobalDir == "BEAR") score -= 1;
      sources++;
   }
   if(g_smcGomRsi > 70)      { score -= 1; sources++; }
   else if(g_smcGomRsi < 30) { score += 1; sources++; }

   bool bull = (score > 0);
   bool bear = (score < 0);
   bool valid = (sources >= 2 && score != 0);
   if(!valid)
   {
      // Pas assez de sources — dessiner zone neutre
      bull = false;
      bear = false;
   }

   color clr      = bull ? clrLime : (bear ? clrRed : clrDimGray);
   color clrLight = bull ? clrGreen : (bear ? clrOrangeRed : clrGray);

   // === 2. SÉLECTION DONNÉES PRÉDICTION ===
   // Priorité: cogClose > predPathMid > predBbMid (plusieurs sources = plus fiable)
   double predClose[];
   double predUp[];
   double predDn[];
   ArrayFree(predClose);
   ArrayFree(predUp);
   ArrayFree(predDn);

   int nPred = 0;
   if(ArraySize(g_smcCogClose) >= 2)
   {
      ArrayCopy(predClose, g_smcCogClose);
      if(ArraySize(g_smcCogHigh) >= 2) ArrayCopy(predUp, g_smcCogHigh);
      if(ArraySize(g_smcCogLow)  >= 2) ArrayCopy(predDn, g_smcCogLow);
      nPred = ArraySize(predClose);
   }
   else if(ArraySize(g_smcPredPathMid) >= 2)
   {
      ArrayCopy(predClose, g_smcPredPathMid);
      if(ArraySize(g_smcPredPathUp) >= 2) ArrayCopy(predUp, g_smcPredPathUp);
      if(ArraySize(g_smcPredPathDn) >= 2) ArrayCopy(predDn, g_smcPredPathDn);
      nPred = ArraySize(predClose);
   }
   else if(ArraySize(g_smcPredBbMid) >= 2)
   {
      ArrayCopy(predClose, g_smcPredBbMid);
      if(ArraySize(g_smcPredBbUp) >= 2) ArrayCopy(predUp, g_smcPredBbUp);
      if(ArraySize(g_smcPredBbDn) >= 2) ArrayCopy(predDn, g_smcPredBbDn);
      nPred = ArraySize(predClose);
   }

   // === 3. PRIX ACTUEL ===
   if(currentPrice <= 0) currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(currentPrice <= 0) currentPrice = (zone_high + zone_low) / 2.0;

   datetime now = TimeCurrent();
   int tfSec = PeriodSeconds(PERIOD_CURRENT);
   if(tfSec <= 0) tfSec = 60;

   // === 4. ÉCHANTILLONNER 5 SEGMENTS ===
   int maxSeg = 5;
   double segPrice[];
   double segUp[];
   double segDn[];
   ArrayResize(segPrice, maxSeg + 1);
   ArrayResize(segUp, maxSeg + 1);
   ArrayResize(segDn, maxSeg + 1);

   // Premier point = prix actuel
   segPrice[0] = currentPrice;
   segUp[0] = currentPrice;
   segDn[0] = currentPrice;

   if(nPred >= 2)
   {
      // Échantillonner uniformément dans les données de prédiction
      for(int s = 1; s <= maxSeg; s++)
      {
         int idx = (int)MathRound((double)s / maxSeg * (nPred - 1));
         if(idx >= nPred) idx = nPred - 1;
         if(idx < 0) idx = 0;
         segPrice[s] = predClose[idx];
         segUp[s] = (ArraySize(predUp) > idx) ? predUp[idx] : predClose[idx];
         segDn[s] = (ArraySize(predDn) > idx) ? predDn[idx] : predClose[idx];
      }
   }
   else
   {
      // Pas de données prédiction — interpolation linéaire vers zone
      double target = bull ? zone_high : (bear ? zone_low : (zone_high + zone_low) / 2.0);
      for(int s = 1; s <= maxSeg; s++)
      {
         double t = (double)s / maxSeg;
         segPrice[s] = currentPrice + (target - currentPrice) * t;
         segUp[s] = segPrice[s] + (zone_high - zone_low) * 0.02 * (1.0 - t);
         segDn[s] = segPrice[s] - (zone_high - zone_low) * 0.02 * (1.0 - t);
      }
   }

   // === 5. DESSINER LES 5 SEGMENTS ===
   int segDuration = tfSec * 2;  // 2 périodes par segment

   for(int s = 0; s < maxSeg; s++)
   {
      datetime t1 = now + (datetime)(s * segDuration);
      datetime t2 = now + (datetime)((s + 1) * segDuration);

      string segName = label + "_SEG" + IntegerToString(s);
      ObjectDelete(0, segName);
      ObjectCreate(0, segName, OBJ_TREND, 0, t1, segPrice[s], t2, segPrice[s + 1]);
      ObjectSetInteger(0, segName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, segName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, segName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, segName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, segName, OBJPROP_BACK, false);
      ObjectSetInteger(0, segName, OBJPROP_SELECTABLE, false);

      // Bande de confiance (UP/DN) en pointillé
      if(ArraySize(segUp) > s + 1 && segUp[s + 1] > 0)
      {
         string fanName = label + "_FAN" + IntegerToString(s);
         ObjectDelete(0, fanName);
         ObjectCreate(0, fanName, OBJ_TREND, 0, t2, segUp[s + 1], t2, segDn[s + 1]);
         ObjectSetInteger(0, fanName, OBJPROP_COLOR, clrLight);
         ObjectSetInteger(0, fanName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, fanName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, fanName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, fanName, OBJPROP_BACK, true);
         ObjectSetInteger(0, fanName, OBJPROP_SELECTABLE, false);
      }
   }

   // === 6. FLÈCHE FINALE ===
   datetime tEnd = now + (datetime)(maxSeg * segDuration);
   double pEnd = segPrice[maxSeg];
   int arrowCode = bull ? 233 : (bear ? 234 : 159);  // 233=haut, 234=bas, 159=point

   string arrowName = label + "_ARROW";
   ObjectDelete(0, arrowName);
   ObjectCreate(0, arrowName, OBJ_ARROW, 0, tEnd, pEnd);
   ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
   ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);

   // === 7. LABEL DIRECTION + LABEL INFO ===
   string dirTxt = bull ? "BUY" : (bear ? "SELL" : "WAIT");
   string lblName = label + "_LBL";
   ObjectDelete(0, lblName);
   ObjectCreate(0, lblName, OBJ_TEXT, 0, tEnd, pEnd);
   ObjectSetString(0, lblName, OBJPROP_TEXT, "  " + dirTxt);
   ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lblName, OBJPROP_BACK, false);
   ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);

   // Label synthèse sources
   string infoTxt = "src=" + IntegerToString(sources)
                  + " score=" + IntegerToString(score)
                  + " gom=" + IntegerToString(gomDir);
   if(g_smcGomRsi > 0) infoTxt += " rsi=" + IntegerToString(g_smcGomRsi);
   if(nPred > 0)       infoTxt += " pred=" + IntegerToString(nPred);
   string infoName = label + "_INFO";
   ObjectDelete(0, infoName);
   ObjectCreate(0, infoName, OBJ_TEXT, 0, tEnd, pEnd);
   ObjectSetString(0, infoName, OBJPROP_TEXT, "  " + infoTxt);
   ObjectSetString(0, infoName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, infoName, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, infoName, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, infoName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, infoName, OBJPROP_BACK, false);
   ObjectSetInteger(0, infoName, OBJPROP_SELECTABLE, false);

   Print("[GOMG] Trajectoire ", dirTxt, " | sources=", sources, " score=", score,
         " | pred=", nPred, " pts | ", currentPrice, " → ", pEnd);
}

//+------------------------------------------------------------------+
// Dessiner le niveau Kola
//+------------------------------------------------------------------+
void GOMG_DrawKolaLevels(double kola_buy, double kola_sell)
{
   if(kola_buy > 0)
   {
      string kolaBuyName = "GOM_KOLA_BUY";
      ObjectDelete(0, kolaBuyName);
      ObjectCreate(0, kolaBuyName, OBJ_HLINE, 0, 0, kola_buy);
      ObjectSetInteger(0, kolaBuyName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, kolaBuyName, OBJPROP_WIDTH, 3);
   }

   if(kola_sell > 0)
   {
      string kolaSellName = "GOM_KOLA_SELL";
      ObjectDelete(0, kolaSellName);
      ObjectCreate(0, kolaSellName, OBJ_HLINE, 0, 0, kola_sell);
      ObjectSetInteger(0, kolaSellName, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, kolaSellName, OBJPROP_WIDTH, 3);
   }

   Print("[GOMG] Niveaux Kola: BUY=", kola_buy, " SELL=", kola_sell);
}

//+------------------------------------------------------------------+
// Tracer les Bollinger Bands PR�DITES (300 bougies) � Courbes continues
//+------------------------------------------------------------------+
void GOMG_DrawBollingerPrediction(double& pred_bb_mid[], double& pred_bb_up[], double& pred_bb_dn[])
{
   if(ArraySize(pred_bb_mid) < 2) return;

   datetime now = TimeCurrent();
   int n_points = ArraySize(pred_bb_mid);

   // Intervalle temporel entre points (30s par d�faut pour M1 = 60 points/min)
   int time_step = 60; // 1 min per point

   // ?? Tracer MID (bleu, solide, �pais) ??
   for(int i = 0; i < n_points - 1; i++)
   {
      string line_name = "GOM_PRED_MID_" + IntegerToString(i);
      datetime t1 = now + (i * time_step);
      datetime t2 = now + ((i + 1) * time_step);

      ObjectDelete(0, line_name);
      ObjectCreate(0, line_name, OBJ_TREND, 0, t1, pred_bb_mid[i], t2, pred_bb_mid[i + 1]);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
   }

   // ?? Tracer UP (rouge, pointill�) ??
   for(int i = 0; i < n_points - 1; i++)
   {
      string line_name = "GOM_PRED_UP_" + IntegerToString(i);
      datetime t1 = now + (i * time_step);
      datetime t2 = now + ((i + 1) * time_step);

      ObjectDelete(0, line_name);
      ObjectCreate(0, line_name, OBJ_TREND, 0, t1, pred_bb_up[i], t2, pred_bb_up[i + 1]);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
   }

   // ?? Tracer DN (vert, pointill�) ??
   for(int i = 0; i < n_points - 1; i++)
   {
      string line_name = "GOM_PRED_DN_" + IntegerToString(i);
      datetime t1 = now + (i * time_step);
      datetime t2 = now + ((i + 1) * time_step);

      ObjectDelete(0, line_name);
      ObjectCreate(0, line_name, OBJ_TREND, 0, t1, pred_bb_dn[i], t2, pred_bb_dn[i + 1]);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
   }

   Print("[GOMG] Bollinger Predictions dessin�es: " + IntegerToString(n_points) + " points");
}

//+------------------------------------------------------------------+
// Nettoyer tous les dessins GOM
//+------------------------------------------------------------------+
void GOMG_ClearAll()
{
   ObjectDelete(0, "GOM_BB_UP");
   ObjectDelete(0, "GOM_BB_MID");
   ObjectDelete(0, "GOM_BB_DN");
   ObjectDelete(0, "GOM_KOLA_BUY");
   ObjectDelete(0, "GOM_KOLA_SELL");
   ObjectsDeleteAll(0, "GOM_PRED_ZONE");
   ObjectsDeleteAll(0, "GOM_PRED_MID_");
   ObjectsDeleteAll(0, "GOM_PRED_UP_");
   ObjectsDeleteAll(0, "GOM_PRED_DN_");
   Print("[GOMG] Tous les dessins GOM nettoyés");
}

#endif
