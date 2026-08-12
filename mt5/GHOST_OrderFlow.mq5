//+------------------------------------------------------------------+
//|                              GHOST_OrderFlow.mq5                |
//|   Order Flow Intelligence — Inspiré Bookmap / NinjaTrader       |
//|                                                                  |
//|   Modules :                                                      |
//|   1. Liquidity Heatmap  — zones de volume cumulé sur chart      |
//|   2. Delta Volume       — pression acheteur/vendeur par bougie  |
//|   3. CVD Cumulatif      — Cumulative Volume Delta session       |
//|   4. Momentum Compass   — boussole angulaire (style screenshot) |
//|   5. Sentiment Gauge    — BUY% vs SELL% pondéré par volume      |
//|                                                                  |
//|   Intégré TradBOT — préfixe objets : GHOST_OF_                  |
//|   Dashboard en CORNER_RIGHT_UPPER (TradeManager = LEFT_LOWER)   |
//+------------------------------------------------------------------+
#property copyright "TradBOT GHOST v1.0"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
input group "=== GHOST — Heatmap Liquidité ==="
input bool   InpShowHeatmap   = true;    // Afficher heatmap de liquidité
input int    InpLookback      = 100;     // Bougies analysées
input int    InpHeatZones     = 24;      // Tranches de prix

input group "=== GHOST — Delta / CVD ==="
input bool   InpShowDelta     = true;    // Afficher Delta + CVD
input int    InpDeltaBars     = 12;      // Barres mini-histogramme
input int    InpCVDPeriod     = 60;      // Bougies CVD cumulatif

input group "=== GHOST — Boussole Momentum ==="
input bool   InpShowCompass   = true;    // Afficher boussole

input group "=== GHOST — Sentiment ==="
input bool   InpShowSentiment = true;    // Afficher jauge sentiment
input int    InpSentPeriod    = 20;      // Bougies sentiment

input group "=== GHOST — Affichage ==="
input int    InpPanelX        = 12;      // Distance bord droit (px)
input int    InpPanelY        = 30;      // Distance bord bas (px)
input color  InpBullColor     = clrDodgerBlue;
input color  InpBearColor     = clrOrangeRed;
input color  InpNeutColor     = C'100,100,100';
input color  InpBgColor       = C'12,14,22';
input color  InpBorderColor   = C'40,45,65';
input color  InpHeaderColor   = C'25,28,42';

//+------------------------------------------------------------------+
//| CONSTANTES                                                       |
//+------------------------------------------------------------------+
#define GHOST_PFX  "GHOST_OF_"
#define PANEL_W    228
#define ROW_H      17
#define FONT       "Consolas"
#define FSZ        8
#define FSZ_SM     7
#define FSZ_LG     10

//+------------------------------------------------------------------+
//| HANDLES                                                          |
//+------------------------------------------------------------------+
int g_hEMA9  = INVALID_HANDLE;
int g_hEMA21 = INVALID_HANDLE;
int g_hRSI   = INVALID_HANDLE;
int g_hATR   = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| ÉTAT GLOBAL                                                      |
//+------------------------------------------------------------------+
datetime g_lastBar   = 0;
double   g_cvd       = 0.0;
datetime g_cvdDay    = 0;

//+------------------------------------------------------------------+
//| HELPERS GRAPHIQUES                                               |
//+------------------------------------------------------------------+
void RectLabel(const string n, int corner, int x, int y, int w, int h,
               color bg, color border = clrNONE, bool back = false)
{
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,      corner);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,        h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, (border == clrNONE) ? bg : border);
   ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE,  BORDER_FLAT);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, n, OBJPROP_BACK,         back);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,       true);
}

void Lbl(const string n, int corner, int x, int y, const string txt,
         color clr, int sz = FSZ, uint anchor = ANCHOR_LEFT_UPPER)
{
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    corner);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString (0, n, OBJPROP_TEXT,      txt);
   ObjectSetString (0, n, OBJPROP_FONT,      FONT);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,  sz);
   ObjectSetInteger(0, n, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, n, OBJPROP_ANCHOR,    anchor);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, n, OBJPROP_BACK,      false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,    true);
}

void CleanPrefix(const string pfx)
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i);
      if(StringFind(nm, pfx) == 0) ObjectDelete(0, nm);
   }
}

void CleanupGhostObjects() { CleanPrefix(GHOST_PFX); }

//+------------------------------------------------------------------+
//| MODULE 1 — Delta Volume estimé (formule proxy Bookmap)          |
//+------------------------------------------------------------------+
double EstimateDelta(const MqlRates &c)
{
   double range = c.high - c.low;
   if(range < 1e-10) return 0.0;
   // Buyers aggressifs si close près du high, sellers si près du low
   return (double)c.tick_volume * (2.0 * (c.close - c.low) / range - 1.0);
}

//+------------------------------------------------------------------+
//| MODULE 2 — CVD cumulatif (reset à minuit broker)                |
//+------------------------------------------------------------------+
void UpdateCVD()
{
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != g_cvdDay) { g_cvd = 0.0; g_cvdDay = today; }

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int got = CopyRates(_Symbol, PERIOD_CURRENT, 1, InpCVDPeriod, r);
   if(got < 1) return;
   g_cvd = 0.0;
   for(int i = got - 1; i >= 0; i--) g_cvd += EstimateDelta(r[i]);
}

//+------------------------------------------------------------------+
//| MODULE 3 — Sentiment pondéré par volume                         |
//+------------------------------------------------------------------+
void CalcSentiment(double &buyPct, double &sellPct)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int got = CopyRates(_Symbol, PERIOD_CURRENT, 1, InpSentPeriod, r);
   if(got < 1) { buyPct = 50; sellPct = 50; return; }
   double bv = 0, sv = 0;
   for(int i = 0; i < got; i++)
   {
      if(r[i].close >= r[i].open) bv += (double)r[i].tick_volume;
      else                        sv += (double)r[i].tick_volume;
   }
   double tot = bv + sv;
   if(tot < 1e-10) { buyPct = 50; sellPct = 50; return; }
   buyPct  = bv / tot * 100.0;
   sellPct = 100.0 - buyPct;
}

//+------------------------------------------------------------------+
//| MODULE 4 — Angle de momentum (0°=E, 90°=N, -90°=S, 180°=W)     |
//+------------------------------------------------------------------+
double Atan2Custom(double y, double x)
{
   if(x == 0.0)
   {
      if(y > 0) return  M_PI / 2.0;
      if(y < 0) return -M_PI / 2.0;
      return 0.0;
   }
   double a = MathArctan(y / x);
   if(x < 0) a += (y >= 0) ? M_PI : -M_PI;
   return a;
}

double CalcMomentumAngle(int &octant)
{
   double ema9[], ema21[], rsi[], atr_buf[];
   ArraySetAsSeries(ema9, true); ArraySetAsSeries(ema21, true);
   ArraySetAsSeries(rsi,  true); ArraySetAsSeries(atr_buf, true);

   if(CopyBuffer(g_hEMA9,  0, 0, 5, ema9)     < 5) { octant = 0; return 0; }
   if(CopyBuffer(g_hEMA21, 0, 0, 2, ema21)    < 2) { octant = 0; return 0; }
   if(CopyBuffer(g_hRSI,   0, 1, 1, rsi)      < 1) { octant = 0; return 0; }
   if(CopyBuffer(g_hATR,   0, 1, 1, atr_buf)  < 1) { octant = 0; return 0; }
   double atr_val = atr_buf[0];
   if(atr_val < 1e-10) { octant = 0; return 0; }

   // X = déséquilibre EMA (position relative)
   double emaDiff = (ema9[0] - ema21[0]) / atr_val;
   // Y = pente EMA9 sur 4 barres (vitesse)
   double slope   = (ema9[0] - ema9[4]) / (4.0 * atr_val);

   double angle = Atan2Custom(slope, emaDiff) * 180.0 / M_PI;
   // Normaliser 0–360
   if(angle < 0) angle += 360.0;

   // Octant 0-7 : E NE N NW W SW S SE
   static const double centers[8] = {0, 45, 90, 135, 180, 225, 270, 315};
   double best = 360; octant = 0;
   for(int i = 0; i < 8; i++)
   {
      double diff = MathAbs(angle - centers[i]);
      if(diff > 180) diff = 360 - diff;
      if(diff < best) { best = diff; octant = i; }
   }
   return angle;
}

//+------------------------------------------------------------------+
//| DESSIN — Jauge Sentiment  (CORNER_RIGHT_UPPER, py = haut)       |
//+------------------------------------------------------------------+
int DrawSentimentSection(int px, int py)
{
   double buyPct, sellPct;
   CalcSentiment(buyPct, sellPct);

   int sectionH = ROW_H * 2 + 6;
   RectLabel(GHOST_PFX+"SENT_BG", CORNER_RIGHT_UPPER, px - 4, py, PANEL_W + 8, sectionH, C'16,18,28');
   Lbl(GHOST_PFX+"SENT_LBL", CORNER_RIGHT_UPPER, px, py + 2, "SENTIMENT", InpNeutColor, FSZ_SM);
   Lbl(GHOST_PFX+"SENT_N",   CORNER_RIGHT_UPPER, px + PANEL_W, py + 2, StringFormat("(%d bars)", InpSentPeriod), InpNeutColor, FSZ_SM, ANCHOR_RIGHT_UPPER);

   int barY  = py + ROW_H;
   int barH  = ROW_H - 2;
   int barW  = PANEL_W - 16;
   int buyW  = (int)(barW * buyPct / 100.0);
   int sellW = barW - buyW;

   RectLabel(GHOST_PFX+"SENT_BARBG", CORNER_RIGHT_UPPER, px + 8, barY, barW, barH, C'30,30,40');
   if(buyW  > 0) RectLabel(GHOST_PFX+"SENT_BARB", CORNER_RIGHT_UPPER, px + 8,          barY, buyW,  barH, InpBullColor);
   if(sellW > 0) RectLabel(GHOST_PFX+"SENT_BARS", CORNER_RIGHT_UPPER, px + 8 + buyW,   barY, sellW, barH, InpBearColor);

   color buyC  = (buyPct  > 60) ? InpBullColor : clrSilver;
   color sellC = (sellPct > 60) ? InpBearColor : clrSilver;
   Lbl(GHOST_PFX+"SENT_BPCT", CORNER_RIGHT_UPPER, px + 8,           barY + barH + 1, StringFormat("BUY %.0f%%",  buyPct),  buyC,  FSZ_SM);
   Lbl(GHOST_PFX+"SENT_SPCT", CORNER_RIGHT_UPPER, px + PANEL_W - 8, barY + barH + 1, StringFormat("SELL %.0f%%", sellPct), sellC, FSZ_SM, ANCHOR_RIGHT_UPPER);
   return sectionH;
}

//+------------------------------------------------------------------+
//| DESSIN — Boussole  (CORNER_RIGHT_UPPER, py = haut)              |
//+------------------------------------------------------------------+
int DrawCompassSection(int px, int py)
{
   int    octant;
   double angle = CalcMomentumAngle(octant);
   static const string lbls[8]   = {"E","NE","N","NW","W","SW","S","SE"};
   static const string arrows[8] = {"E>","NE","N^","NW","W<","SW","Sv","SE"};

   color dirClr = (octant == 2 || octant == 1 || octant == 7 || octant == 0) ? InpBullColor : InpBearColor;
   if(octant == 2) dirClr = InpBullColor;
   if(octant == 6) dirClr = InpBearColor;

   int sectionH = ROW_H * 5;
   RectLabel(GHOST_PFX+"CMP_BG", CORNER_RIGHT_UPPER, px - 4, py, PANEL_W + 8, sectionH, C'14,16,26');
   Lbl(GHOST_PFX+"CMP_LBL", CORNER_RIGHT_UPPER, px,           py + 2, "MOMENTUM COMPASS",     InpNeutColor, FSZ_SM);
   Lbl(GHOST_PFX+"CMP_ANG", CORNER_RIGHT_UPPER, px + PANEL_W, py + 2, StringFormat("%.0f deg", angle), dirClr, FSZ_SM, ANCHOR_RIGHT_UPPER);

   // Grille 3×3 : CORNER_RIGHT_UPPER, y descend
   // Row NW/N/NE  → py + ROW_H
   // Row W/./E    → py + ROW_H * 2
   // Row SW/S/SE  → py + ROW_H * 3
   int cellW  = 34;
   int gridLX = px + (PANEL_W - 3 * cellW) / 2 + 8;
   int rows[3];
   rows[0] = py + ROW_H;
   rows[1] = py + ROW_H * 2;
   rows[2] = py + ROW_H * 3;

   static const int oCol[8] = {2, 2, 1, 0, 0, 0, 1, 2};
   static const int oRow[8] = {1, 0, 0, 0, 1, 2, 2, 2};

   for(int d = 0; d < 8; d++)
   {
      bool   active = (d == octant);
      int    gx    = gridLX + oCol[d] * cellW;
      int    gy    = rows[oRow[d]];
      color  clr   = active ? dirClr : InpNeutColor;
      int    sz    = active ? FSZ_LG : FSZ_SM;
      string txt   = active ? arrows[d] : lbls[d];
      Lbl(GHOST_PFX+"CMP_D"+IntegerToString(d), CORNER_RIGHT_UPPER, gx, gy, txt, clr, sz);
   }
   Lbl(GHOST_PFX+"CMP_CTR", CORNER_RIGHT_UPPER, gridLX + cellW, rows[1], "*", InpNeutColor, FSZ_SM);
   return sectionH;
}

//+------------------------------------------------------------------+
//| DESSIN — Delta + CVD  (CORNER_RIGHT_UPPER, py = haut)           |
//+------------------------------------------------------------------+
int DrawDeltaSection(int px, int py)
{
   UpdateCVD();

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int got = CopyRates(_Symbol, PERIOD_CURRENT, 1, InpDeltaBars, r);

   int sectionH = ROW_H * 4 + 4;
   RectLabel(GHOST_PFX+"DLT_BG", CORNER_RIGHT_UPPER, px - 4, py, PANEL_W + 8, sectionH, C'16,18,28');
   Lbl(GHOST_PFX+"DLT_LBL", CORNER_RIGHT_UPPER, px, py + 2, "DELTA / CVD", InpNeutColor, FSZ_SM);

   // CVD + Delta courant sur la même ligne
   color cvdClr = (g_cvd >= 0) ? InpBullColor : InpBearColor;
   Lbl(GHOST_PFX+"DLT_CVD", CORNER_RIGHT_UPPER, px, py + ROW_H, StringFormat("CVD %s%.0f", (g_cvd >= 0 ? "+" : ""), g_cvd), cvdClr, FSZ);

   MqlRates cur[1];
   double curDelta = 0;
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, cur) == 1)
      curDelta = EstimateDelta(cur[0]);
   color curClr = (curDelta >= 0) ? InpBullColor : InpBearColor;
   Lbl(GHOST_PFX+"DLT_CUR", CORNER_RIGHT_UPPER, px + PANEL_W, py + ROW_H, StringFormat("D%s%.0f", (curDelta >= 0 ? "+" : ""), curDelta), curClr, FSZ, ANCHOR_RIGHT_UPPER);

   // Histogramme centré sur la zone restante
   if(got > 0)
   {
      double deltas[];
      ArrayResize(deltas, got);
      double maxAbs = 1.0;
      for(int i = 0; i < got; i++)
      {
         deltas[i] = EstimateDelta(r[i]);
         if(MathAbs(deltas[i]) > maxAbs) maxAbs = MathAbs(deltas[i]);
      }
      int histH = ROW_H * 2;
      int histY = py + ROW_H * 2;
      int histW = PANEL_W - 16;
      int bw    = MathMax(2, (histW - got) / got);
      RectLabel(GHOST_PFX+"DLT_HBKG", CORNER_RIGHT_UPPER, px + 8, histY,              histW, histH, C'10,12,20');
      RectLabel(GHOST_PFX+"DLT_ZERO", CORNER_RIGHT_UPPER, px + 8, histY + histH / 2,  histW, 1,     C'50,50,70');
      for(int i = 0; i < got; i++)
      {
         double d  = deltas[got - 1 - i];
         int    bh = (int)(MathAbs(d) / maxAbs * (histH / 2 - 1));
         if(bh < 1) bh = 1;
         color  c  = (d >= 0) ? InpBullColor : InpBearColor;
         int    bx = px + 8 + i * (bw + 1);
         int    by = (d >= 0) ? histY + histH / 2 - bh : histY + histH / 2;
         RectLabel(GHOST_PFX+"DLT_B"+IntegerToString(i), CORNER_RIGHT_UPPER, bx, by, bw, bh, c);
      }
   }
   return sectionH;
}

//+------------------------------------------------------------------+
//| MODULE Heatmap — calcule et dessine sur le chart                 |
//+------------------------------------------------------------------+
void DrawLiquidityHeatmap()
{
   CleanPrefix(GHOST_PFX+"LIQ_");

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int got = CopyRates(_Symbol, PERIOD_CURRENT, 1, InpLookback, r);
   if(got < 10) return;

   double hi = r[0].high, lo = r[0].low;
   for(int i = 1; i < got; i++)
   {
      if(r[i].high > hi) hi = r[i].high;
      if(r[i].low  < lo) lo = r[i].low;
   }
   if(hi <= lo) return;

   double zH  = (hi - lo) / InpHeatZones;
   double scores[];
   ArrayResize(scores, InpHeatZones);
   ArrayInitialize(scores, 0);

   // Accumulation volume pondéré par overlap avec chaque zone
   for(int i = 0; i < got; i++)
   {
      double barRng = r[i].high - r[i].low;
      if(barRng < 1e-10) continue;
      double vol = (double)r[i].tick_volume;
      for(int z = 0; z < InpHeatZones; z++)
      {
         double zLo  = lo + z * zH;
         double zHi  = zLo + zH;
         double over = MathMin(r[i].high, zHi) - MathMax(r[i].low, zLo);
         if(over > 0) scores[z] += vol * (over / barRng);
      }
   }

   double maxScore = 1.0;
   for(int z = 0; z < InpHeatZones; z++)
      if(scores[z] > maxScore) maxScore = scores[z];

   datetime t0 = r[got - 1].time;
   datetime t1 = r[0].time + (datetime)PeriodSeconds(PERIOD_CURRENT) * 5;

   for(int z = 0; z < InpHeatZones; z++)
   {
      double pct = scores[z] / maxScore;
      if(pct < 0.12) continue; // filtre bruit (<12%)

      double zLo = lo + z * zH;
      double zHi = zLo + zH;

      // Palette Bookmap : bleu sombre → cyan → orange/rouge
      color clr;
      if     (pct < 0.30) clr = C'0,35,90';    // bleu profond
      else if(pct < 0.50) clr = C'0,80,160';   // bleu moyen
      else if(pct < 0.70) clr = C'0,160,190';  // cyan (liquidité significative)
      else if(pct < 0.88) clr = C'0,200,130';  // vert (zone chaude)
      else                clr = C'210,90,10';   // orange/rouge (liquidité max)

      string nm = GHOST_PFX+"LIQ_"+IntegerToString(z);
      if(ObjectFind(0, nm) < 0)
         ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t0, zHi, t1, zLo);
      ObjectSetInteger(0, nm, OBJPROP_TIME,  0, t0);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, zHi);
      ObjectSetInteger(0, nm, OBJPROP_TIME,  1, t1);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 1, zLo);
      ObjectSetInteger(0, nm, OBJPROP_COLOR,      clr);
      ObjectSetInteger(0, nm, OBJPROP_STYLE,      STYLE_SOLID);
      ObjectSetInteger(0, nm, OBJPROP_FILL,        true);
      ObjectSetInteger(0, nm, OBJPROP_BACK,        true);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE,  false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN,      true);
   }
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   g_hEMA9  = iMA   (_Symbol, PERIOD_CURRENT, 9,  0, MODE_EMA, PRICE_CLOSE);
   g_hEMA21 = iMA   (_Symbol, PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI   = iRSI  (_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   g_hATR   = iATR  (_Symbol, PERIOD_CURRENT, 14);

   if(g_hEMA9  == INVALID_HANDLE || g_hEMA21 == INVALID_HANDLE ||
      g_hRSI   == INVALID_HANDLE || g_hATR   == INVALID_HANDLE)
   {
      Alert("[GHOST] Erreur handles — vérifier symbole/TF");
      return INIT_FAILED;
   }

   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, false);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   CleanupGhostObjects();
   IndicatorRelease(g_hEMA9);
   IndicatorRelease(g_hEMA21);
   IndicatorRelease(g_hRSI);
   IndicatorRelease(g_hATR);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int       rates_total,
                const int       prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
   // Throttle : redessin seulement sur nouvelle bougie ou premier appel
   datetime curBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBar == g_lastBar && prev_calculated > 0) return rates_total;
   bool isNewBar = (curBar != g_lastBar);
   g_lastBar = curBar;

   int px = InpPanelX;
   int py = InpPanelY;

   // CORNER_RIGHT_UPPER : y=0 en haut, sections empilées vers le bas
   int sentH = InpShowSentiment ? ROW_H * 2 + 6 : 0;
   int cmpH  = InpShowCompass   ? ROW_H * 5     : 0;
   int dltH  = InpShowDelta     ? ROW_H * 4 + 4 : 0;
   int hdrH  = ROW_H + 4;
   int totalH = hdrH + dltH + cmpH + sentH;

   // Fond global
   RectLabel(GHOST_PFX+"BG", CORNER_RIGHT_UPPER, px - 4, py - 4, PANEL_W + 8, totalH + 8, InpBgColor, InpBorderColor);

   // Header en haut
   RectLabel(GHOST_PFX+"HDR",     CORNER_RIGHT_UPPER, px - 4, py - 4, PANEL_W + 8, hdrH, InpHeaderColor);
   Lbl(GHOST_PFX+"HDR_TXT", CORNER_RIGHT_UPPER, px, py, "GHOST  OrderFlow", clrGold, FSZ, ANCHOR_LEFT_UPPER);

   // Sections empilées vers le bas depuis le header
   int curY = py + hdrH;

   if(InpShowDelta)
   {
      DrawDeltaSection(px, curY);
      curY += dltH;
   }
   if(InpShowCompass)
   {
      RectLabel(GHOST_PFX+"SEP1", CORNER_RIGHT_UPPER, px - 4, curY, PANEL_W + 8, 1, InpBorderColor);
      DrawCompassSection(px, curY + 1);
      curY += cmpH + 1;
   }
   if(InpShowSentiment)
   {
      RectLabel(GHOST_PFX+"SEP2", CORNER_RIGHT_UPPER, px - 4, curY, PANEL_W + 8, 1, InpBorderColor);
      DrawSentimentSection(px, curY + 1);
   }

   // Heatmap (seulement sur nouvelle bougie — calcul lourd)
   if(InpShowHeatmap && isNewBar)
      DrawLiquidityHeatmap();

   ChartRedraw(0);
   return rates_total;
}
