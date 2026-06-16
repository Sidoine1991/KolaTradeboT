//+------------------------------------------------------------------+
//| SMC_FuturePath.mqh — 200 bougies fantômes (cognition forecast)   |
//+------------------------------------------------------------------+
#ifndef SMC_FUTURE_PATH_MQH
#define SMC_FUTURE_PATH_MQH

// inputs du .mq5 parent — visibles globalement, pas besoin de extern en MQL5

// État cognition (défini dans SMC_GOM_Pipeline.mqh)
extern double g_cogStrength;
extern double g_cogConfidence;
extern string g_cogDirection;
extern string g_cogRegime;
extern double g_smcPredPathMid[];
extern double g_smcPredPathUp[];
extern double g_smcPredPathDn[];
extern double g_smcCogOpen[];
extern double g_smcCogHigh[];
extern double g_smcCogLow[];
extern double g_smcCogClose[];
extern double g_smcCogQ10[];
extern double g_smcCogQ90[];

void SMCFP_Clear()
{
   ObjectsDeleteAll(0, "COG_FC_");
   ObjectsDeleteAll(0, "COG_FAN_");
   ObjectsDeleteAll(0, "COG_LBL_");
   ObjectDelete(0, "COG_ARROW");
   ObjectDelete(0, "COG_SUMMARY");
}

// Couleur verte (haussier) ou rouge (baissier) dont la vivacité reflète strength × confidence
// Plage : 80 (signal faible) → 255 (signal maximal)
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

void SMCFP_DrawGhostCandles(
   int barSec,
   const double &opens[], const double &highs[], const double &lows[], const double &closes[],
   const double &q10[], const double &q90[],
   const string direction, const double strength, const double confidence)
{
   if(!ShowCognitionPath) return;

   int n = ArraySize(closes);
   if(n < 2) return;
   if(CognitionHorizonBars > 0 && n > CognitionHorizonBars)
      n = CognitionHorizonBars;

   g_cogStrength = strength;
   g_cogConfidence = confidence;
   g_cogDirection = direction;

   SMCFP_Clear();

   bool bull = (direction == "BUY");
   color bodyClr = SMCFP_StrengthColor(bull, strength, confidence);
   if(barSec <= 0) barSec = PeriodSeconds(PERIOD_CURRENT);
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

   // ── Label direction + confiance sur 1ère bougie ──────────────────
   if(n > 0)
   {
      datetime tLbl = t0 + (datetime)(barSec);
      double   pLbl = (ArraySize(closes) > 0) ? closes[0] : 0;
      if(pLbl > 0)
      {
         string dirIcon  = bull ? "▲" : "▼";
         string dirTxt   = bull ? "HAUSSE" : "BAISSE";
         string cogLabel = dirIcon + " " + dirTxt
                         + "  conf=" + DoubleToString(confidence * 100, 0) + "%"
                         + "  force=" + DoubleToString(strength * 100, 0) + "%";

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

   // ── Flèche de synthèse sur dernière bougie + label résumé ────────
   if(n > 1)
   {
      datetime tEnd = t0 + (datetime)(n * barSec);
      double   pEnd = (ArraySize(closes) >= n) ? closes[n - 1] : 0;
      if(pEnd > 0)
      {
         // Flèche directionnelle
         ObjectDelete(0, "COG_ARROW");
         ObjectCreate(0, "COG_ARROW", OBJ_ARROW, 0, tEnd, pEnd);
         ObjectSetInteger(0, "COG_ARROW", OBJPROP_ARROWCODE, bull ? 233 : 234); // ↑ ou ↓
         ObjectSetInteger(0, "COG_ARROW", OBJPROP_COLOR, bodyClr);
         ObjectSetInteger(0, "COG_ARROW", OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, "COG_ARROW", OBJPROP_SELECTABLE, false);

         // Résumé interprétatif
         string quality = (confidence >= 0.7 && strength >= 0.6) ? "FORT" :
                          (confidence >= 0.5 && strength >= 0.4) ? "MODERE" : "FAIBLE";
         string impl = bull
            ? (quality == "FORT"   ? "Continuation haussiere probable — surveiller resistance"  :
               quality == "MODERE" ? "Biais haussier — confirmation recommandee"                :
                                     "Faible biais haussier — attendre signal clair")
            : (quality == "FORT"   ? "Continuation baissiere probable — surveiller support"     :
               quality == "MODERE" ? "Biais baissier — confirmation recommandee"                :
                                     "Faible biais baissier — attendre signal clair");

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

void SMCFP_DrawFromGlobals()
{
   int n = ArraySize(g_smcCogClose);
   if(n < 2)
   {
      // Fallback pred_path_* (closes seuls)
      n = ArraySize(g_smcPredPathMid);
      if(n < 2) return;
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

   SMCFP_DrawGhostCandles(
      PeriodSeconds(PERIOD_CURRENT),
      g_smcCogOpen, g_smcCogHigh, g_smcCogLow, g_smcCogClose,
      g_smcCogQ10, g_smcCogQ90,
      g_cogDirection, g_cogStrength, g_cogConfidence);
}

#endif
