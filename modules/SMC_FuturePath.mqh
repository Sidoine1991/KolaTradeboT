//+------------------------------------------------------------------+
//| SMC_FuturePath.mqh � 200 bougies fant�mes (cognition forecast)   |
//+------------------------------------------------------------------+
#ifndef SMC_FUTURE_PATH_MQH
#define SMC_FUTURE_PATH_MQH

#ifndef ShowCognitionPath
#define ShowCognitionPath true
#endif

// etat cognition (defini dans SMC_GOM_Pipeline.mqh, inclus AVANT ce fichier)

void SMCFP_Clear()
{
   ObjectsDeleteAll(0, "COG_FC_");
   ObjectsDeleteAll(0, "COG_FAN_");
   ObjectsDeleteAll(0, "COG_SCEN_");
   ObjectsDeleteAll(0, "COG_LBL_");
   ObjectDelete(0, "COG_ARROW");
   ObjectDelete(0, "COG_SUMMARY");
}

void SMCFP_MarkStale(const int ageSec)
{
   if(ObjectFind(0, "COG_SUMMARY") < 0) return;
   ObjectSetString(0, "COG_SUMMARY", OBJPROP_TEXT,
                   "Projection precedente — actualisation en attente (" +
                   IntegerToString(ageSec) + "s)");
   ObjectSetInteger(0, "COG_SUMMARY", OBJPROP_COLOR, clrOrange);
   ChartRedraw(0);
}

// Couleur verte (haussier) ou rouge (baissier) dont la vivacit� refl�te strength � confidence
// Plage : 80 (signal faible) ? 255 (signal maximal)
color SMCFP_StrengthColor(const bool bullish, const double strength, const double confidence = 1.0)
{
   double combo = MathSqrt(MathMax(0.0, strength) * MathMax(0.0, confidence));
   int v = (int)MathRound(80.0 + combo * 175.0);
   if(v < 80)  v = 80;
   if(v > 255) v = 255;
   if(bullish)
      return (color)(v << 8);          // vert pur  RGB(0, v, 0)
   return (color)(v << 16);            // rouge pur RGB(v, 0, 0)
}

void SMCFP_DrawScenarioSegments(
   const string prefix, const double &values[], const int count,
   const int barSec, const datetime t0, const color lineColor)
{
   int available = (int)MathMin(count, ArraySize(values));
   if(available < 2) return;
   int step = 5;
   int previous = 0;
   int segment = 0;
   for(int current = step; current < available; current += step)
   {
      string name = prefix + IntegerToString(segment++);
      datetime t1 = t0 + (datetime)((previous + 1) * barSec);
      datetime t2 = t0 + (datetime)((current + 1) * barSec);
      if(ObjectCreate(0, name, OBJ_TREND, 0, t1, values[previous], t2, values[current]))
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      }
      previous = current;
   }
   if(previous < available - 1)
   {
      string name = prefix + IntegerToString(segment);
      datetime t1 = t0 + (datetime)((previous + 1) * barSec);
      datetime t2 = t0 + (datetime)(available * barSec);
      if(ObjectCreate(0, name, OBJ_TREND, 0, t1, values[previous], t2, values[available - 1]))
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      }
   }
}

void SMCFP_DrawGhostCandles(
   int barSec,
   const double &opens[], const double &highs[], const double &lows[], const double &closes[],
   const double &q10[], const double &q90[],
   const double &scenarioBull[], const double &scenarioBear[],
   const string direction, const double strength, const double confidence)
{
   if(!ShowCognitionPath) return;

   int n = ArraySize(closes);
   if(n < 2) return;
   int maxBars = 200;
   if(CognitionHorizonBars > 0)
      maxBars = (int)MathMin(maxBars, CognitionHorizonBars);
   if(n > maxBars) n = maxBars;

   SMCFP_Clear();

   bool bull = (direction == "BUY");
   bool bear = (direction == "SELL");
   color bodyClr = (!bull && !bear) ? clrSlateGray : SMCFP_StrengthColor(bull, strength, confidence);
   if(barSec <= 0)
      barSec = (g_cogBarSeconds > 0) ? g_cogBarSeconds : PeriodSeconds(PERIOD_CURRENT);
   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t0 <= 0) t0 = TimeCurrent();

   for(int i = 0; i < n; i++)
   {
      datetime t1 = t0 + (datetime)((i + 1) * barSec);
      datetime t2 = t0 + (datetime)((i + 1) * barSec + barSec * 0.75);

      double op = (ArraySize(opens) > i) ? opens[i] : closes[i];
      double hi = (ArraySize(highs) > i) ? highs[i] : closes[i];
      double lo = (ArraySize(lows) > i) ? lows[i] : closes[i];
      double cl = closes[i];

      string base = "COG_FC_" + IntegerToString(i);

      string wick = base + "_W";
      ObjectDelete(0, wick);
      ObjectCreate(0, wick, OBJ_TREND, 0, t1, hi, t1, lo);
      ObjectSetInteger(0, wick, OBJPROP_COLOR, bodyClr);
      ObjectSetInteger(0, wick, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, wick, OBJPROP_BACK, true);
      ObjectSetInteger(0, wick, OBJPROP_SELECTABLE, false);

      string body = base + "_B";
      ObjectDelete(0, body);
      ObjectCreate(0, body, OBJ_RECTANGLE, 0, t1, MathMax(op, cl), t2, MathMin(op, cl));
      ObjectSetInteger(0, body, OBJPROP_COLOR, bodyClr);
      ObjectSetInteger(0, body, OBJPROP_FILL, true);
      ObjectSetInteger(0, body, OBJPROP_BACK, true);
      ObjectSetInteger(0, body, OBJPROP_SELECTABLE, false);

      if(i % 10 == 0 && ArraySize(q10) > i && ArraySize(q90) > i)
      {
         string fan = "COG_FAN_" + IntegerToString(i);
         ObjectDelete(0, fan);
         ObjectCreate(0, fan, OBJ_TREND, 0, t1, q10[i], t1, q90[i]);
         ObjectSetInteger(0, fan, OBJPROP_COLOR, clrGray);
         ObjectSetInteger(0, fan, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, fan, OBJPROP_BACK, true);
         ObjectSetInteger(0, fan, OBJPROP_SELECTABLE, false);
      }
   }

   SMCFP_DrawScenarioSegments("COG_SCEN_BULL_", scenarioBull, n, barSec, t0, clrDeepSkyBlue);
   SMCFP_DrawScenarioSegments("COG_SCEN_BEAR_", scenarioBear, n, barSec, t0, clrOrange);
   static datetime s_lastRenderLog = 0;
   if(TimeCurrent() - s_lastRenderLog >= 60)
   {
      Print("[SMCFP] Projection affichee: ", n, "/", maxBars,
            " bougies, intervalle=", barSec, "s, direction=", direction);
      s_lastRenderLog = TimeCurrent();
   }

   // ?? Label direction + confiance sur 1�re bougie ??????????????????
   if(n > 0)
   {
      datetime tLbl = t0 + (datetime)(barSec);
      double   pLbl = (ArraySize(closes) > 0) ? closes[0] : 0;
      if(pLbl > 0)
      {
         string dirTxt   = bull ? "HAUSSE" : (bear ? "BAISSE" : "NEUTRE");
         string cogLabel = dirTxt
                         + "  conf=" + DoubleToString(confidence * 100, 0) + "%"
                         + "  force=" + DoubleToString(strength * 100, 0) + "%"
                         + "  align=" + DoubleToString(g_cogComponentAlignment * 100, 0) + "%";
         if(g_pathConcordancePct > 0.0)
            cogLabel += "  conc=" + DoubleToString(g_pathConcordancePct, 0) + "%";

         ObjectDelete(0, "COG_LBL_DIR");
         ObjectCreate(0, "COG_LBL_DIR", OBJ_TEXT, 0, tLbl, pLbl);
         ObjectSetString(0,  "COG_LBL_DIR", OBJPROP_TEXT, cogLabel);
         ObjectSetInteger(0, "COG_LBL_DIR", OBJPROP_COLOR, bodyClr);
         ObjectSetInteger(0, "COG_LBL_DIR", OBJPROP_FONTSIZE, 9);
         ObjectSetString(0,  "COG_LBL_DIR", OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, "COG_LBL_DIR", OBJPROP_ANCHOR, bull ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER);
         ObjectSetInteger(0, "COG_LBL_DIR", OBJPROP_SELECTABLE, false);
      }
   }

   // ?? Fl�che de synth�se sur derni�re bougie + label r�sum� ????????
   if(n > 1)
   {
      datetime tEnd = t0 + (datetime)(n * barSec);
      double   pEnd = (ArraySize(closes) >= n) ? closes[n - 1] : 0;
      if(pEnd > 0)
      {
         // Fl�che directionnelle
         ObjectDelete(0, "COG_ARROW");
         if(bull || bear)
         {
            ObjectCreate(0, "COG_ARROW", OBJ_ARROW, 0, tEnd, pEnd);
            ObjectSetInteger(0, "COG_ARROW", OBJPROP_ARROWCODE, bull ? 233 : 234);
            ObjectSetInteger(0, "COG_ARROW", OBJPROP_COLOR, bodyClr);
            ObjectSetInteger(0, "COG_ARROW", OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, "COG_ARROW", OBJPROP_SELECTABLE, false);
         }

         // R�sum� interpr�tatif
         string quality = (confidence >= 0.7 && strength >= 0.6) ? "FORT" :
                          (confidence >= 0.5 && strength >= 0.4) ? "MODERE" : "FAIBLE";
         string impl = (!bull && !bear)
            ? "Scenarios: bleu haussier, orange baissier; projection incertaine"
            : (bull
               ? "Scenario haussier, bleu=haussier/orange=baissier; confirmer au prix reel"
               : "Scenario baissier, bleu=haussier/orange=baissier; confirmer au prix reel");

         ObjectDelete(0, "COG_SUMMARY");
         ObjectCreate(0, "COG_SUMMARY", OBJ_TEXT, 0, tEnd, pEnd);
         ObjectSetString(0,  "COG_SUMMARY", OBJPROP_TEXT, "[" + quality + "] " + impl);
         ObjectSetInteger(0, "COG_SUMMARY", OBJPROP_COLOR, bodyClr);
         ObjectSetInteger(0, "COG_SUMMARY", OBJPROP_FONTSIZE, 8);
         ObjectSetString(0,  "COG_SUMMARY", OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, "COG_SUMMARY", OBJPROP_ANCHOR, bull ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER);
         ObjectSetInteger(0, "COG_SUMMARY", OBJPROP_SELECTABLE, false);
      }
   }

   ChartRedraw(0);
}

void SMCFP_NormalizeOHLC(double &opens[], double &highs[], double &lows[], double &closes[])
{
   int n = MathMin(ArraySize(opens), MathMin(ArraySize(highs), MathMin(ArraySize(lows), ArraySize(closes))));
   if(n <= 0) return;
   for(int i = 0; i < n; i++)
   {
      if(i > 0) opens[i] = closes[i - 1];
      if(opens[i] <= 0) opens[i] = (i > 0 ? closes[i - 1] : closes[i]);
      if(closes[i] <= 0) closes[i] = opens[i];
      double bodyHigh = MathMax(opens[i], closes[i]);
      double bodyLow = MathMin(opens[i], closes[i]);
      if(highs[i] <= 0) highs[i] = bodyHigh;
      if(lows[i] <= 0) lows[i] = bodyLow;
      highs[i] = MathMax(highs[i], bodyHigh);
      lows[i] = MathMin(lows[i], bodyLow);
      if(highs[i] < lows[i])
      {
         highs[i] = bodyHigh;
         lows[i] = bodyLow;
      }
   }
}

void SMCFP_DrawFromGlobals()
{
   if(!g_smcCogPathPayloadFresh)
   {
      int ageSec = (g_smcCogPathLastPayloadTime > 0)
                   ? (int)(TimeCurrent() - g_smcCogPathLastPayloadTime) : -1;
      if(ageSec >= 0 && ageSec <= 90)
      {
         SMCFP_MarkStale(ageSec);
         return;
      }
      SMCFP_Clear();
      return;
   }
   g_smcCogPathPayloadFresh = false;

   int n = ArraySize(g_smcCogClose);
   if(n < 2)
   {
      // Fallback pred_path_* (closes seuls)
      n = ArraySize(g_smcPredPathMid);
      if(n < 2)
      {
         SMCFP_Clear();
         return;
      }
      ArrayResize(g_smcCogClose, n);
      ArrayResize(g_smcCogOpen, n);
      ArrayResize(g_smcCogHigh, n);
      ArrayResize(g_smcCogLow, n);
      ArrayResize(g_smcCogQ10, n);
      ArrayResize(g_smcCogQ90, n);
      for(int i = 0; i < n; i++)
      {
         g_smcCogClose[i] = g_smcPredPathMid[i];
         g_smcCogOpen[i] = (i > 0) ? g_smcPredPathMid[i - 1] : g_smcPredPathMid[i];
         g_smcCogHigh[i] = (ArraySize(g_smcPredPathUp) > i) ? g_smcPredPathUp[i] : g_smcPredPathMid[i];
         g_smcCogLow[i] = (ArraySize(g_smcPredPathDn) > i) ? g_smcPredPathDn[i] : g_smcPredPathMid[i];
         g_smcCogQ10[i] = g_smcCogLow[i];
         g_smcCogQ90[i] = g_smcCogHigh[i];
      }
   }

   SMCFP_NormalizeOHLC(g_smcCogOpen, g_smcCogHigh, g_smcCogLow, g_smcCogClose);

   SMCFP_DrawGhostCandles(
      g_cogBarSeconds,
      g_smcCogOpen, g_smcCogHigh, g_smcCogLow, g_smcCogClose,
      g_smcCogQ10, g_smcCogQ90,
      g_smcCogScenarioBull, g_smcCogScenarioBear,
      g_cogPathDirection, g_cogPathStrength, g_cogPathConfidence);
}

#endif
