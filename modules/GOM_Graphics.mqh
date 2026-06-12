//+------------------------------------------------------------------+
//| GOM_Graphics.mqh — Dessine Bollinger + Zones futures            |
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

   // Bande supérieure (OBJ_TREND = droite)
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

   // Bande inférieure (OBJ_TREND = droite)
   string bbDnName = "GOM_BB_DN";
   ObjectDelete(0, bbDnName);
   ObjectCreate(0, bbDnName, OBJ_TREND, 0, now, bb_dn, future, bb_dn);
   ObjectSetInteger(0, bbDnName, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, bbDnName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bbDnName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, bbDnName, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, bbDnName, OBJPROP_BACK, false);

   Print("[GOMG] Bollinger dessinées: UP=", bb_up, " MID=", bb_mid, " DN=", bb_dn);
}

//+------------------------------------------------------------------+
// Dessiner les zones de prédiction futures
//+------------------------------------------------------------------+
void GOMG_DrawFutureZone(double zone_high, double zone_low, string label = "GOM_FUTURE_ZONE")
{
   if(zone_high <= 0 || zone_low <= 0) return;
   if(zone_high <= zone_low) return;

   // Effacer l'ancienne zone
   ObjectDelete(0, label);

   // Créer une rectangle pour la zone future
   datetime now = TimeCurrent();
   datetime future = now + 3600; // 1 heure dans le futur

   ObjectCreate(0, label, OBJ_RECTANGLE, 0, now, zone_high, future, zone_low);
   ObjectSetInteger(0, label, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, label, OBJPROP_FILL, true);
   ObjectSetInteger(0, label, OBJPROP_BACK, false);

   Print("[GOMG] Zone future dessinée: HIGH=", zone_high, " LOW=", zone_low);
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
// Tracer les Bollinger Bands PRÉDITES (300 bougies) — Courbes continues
//+------------------------------------------------------------------+
void GOMG_DrawBollingerPrediction(double& pred_bb_mid[], double& pred_bb_up[], double& pred_bb_dn[])
{
   if(ArraySize(pred_bb_mid) < 2) return;

   datetime now = TimeCurrent();
   int n_points = ArraySize(pred_bb_mid);

   // Intervalle temporel entre points (30s par défaut pour M1 = 60 points/min)
   int time_step = 60; // 1 min per point

   // ── Tracer MID (bleu, solide, épais) ──
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

   // ── Tracer UP (rouge, pointillé) ──
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

   // ── Tracer DN (vert, pointillé) ──
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

   Print("[GOMG] Bollinger Predictions dessinées: " + IntegerToString(n_points) + " points");
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
   ObjectDelete(0, "GOM_FUTURE_ZONE");
   ObjectDelete(0, "GOM_PRED_MID*");  // Nettoyer les prédictions aussi
   ObjectDelete(0, "GOM_PRED_UP*");
   ObjectDelete(0, "GOM_PRED_DN*");
   Print("[GOMG] Tous les dessins GOM nettoyés");
}

#endif
