//+------------------------------------------------------------------+
//| SMC_VolumeProfile.mqh — Profil de volume / POC temps réel       |
//| FIX v1.46: histogramme VERTICAL bord droit + POC + Value Area   |
//| 70% + gate anti-correction (pas d'entrée DANS la zone d'oscil-  |
//| lation: BUY au-dessus de VAH, SELL sous VAL) + confirmation     |
//| structurelle optionnelle au POC.                                 |
//+------------------------------------------------------------------+
#ifndef SMC_VOLUME_PROFILE_MQH
#define SMC_VOLUME_PROFILE_MQH

input group "=== VOLUME PROFILE / POC (v1.46) ==="
input bool   UseVolumeProfile     = true;   // Activer profil de volume + POC
input int    VP_LookbackBars      = 180;    // Bougies M1 analysées (30 min d'historique à 180)
input int    VP_PriceBins         = 40;     // Nombre de tranches de prix (lignes de l'histogramme)
input double VP_ValueAreaPct      = 70.0;   // Value Area (% du volume cumulé)
input int    VP_RefreshSec        = 10;     // Rafraîchissement dessin (secondes)
input int    VP_MaxHistBars       = 25;     // Largeur max d'une barre d'histogramme (pixels)
input bool   VP_BlockInValueArea  = true;   // GATE: interdire entrée dans la Value Area
input bool   VP_RequirePOCConfirm = false;  // Confirmation obligatoire du côté du POC avant entrée
input double VP_BypassMinCoherence = 40.0; // v1.51: cohérence min du serveur pour bypasser la Value Area
input double VP_POCMarginPts      = 30;     // Marge autour du POC (points) pour la confirmation
input bool   VP_DrawHistogram     = true;   // Dessiner l'histogramme vertical à droite
input bool   VP_DrawValueArea     = true;   // Encadrer la Value Area (VAH/VAL)
input color  VP_ColorHist         = C'70,140,255'; // Couleur des barres hors VA (vives v1.49)
input color  VP_ColorVA           = C'60,225,90';  // Couleur des barres dans la VA (vives v1.49)
input color  VP_ColorPOC          = clrGold;       // Couleur POC
input int    VP_RightFreeBars     = 4;             // Bougies libres à droite entre prix et profil (v1.49)

// v1.56: bords de la Value Area (VAH/VAL) = support/resistance + money flow M1
input bool   UseVPFlowGate         = true;   // Entree seulement sur un bord VA (fade) ou cassure avec flux aligne
input double VPF_EdgeATR           = 0.6;    // Largeur de la zone de bord (x ATR M1)
input int    VPF_FlowBars          = 20;     // Barres M1 fermees pour le money flow (CMF)
input double VPF_MinFlowFade       = 0.0;    // Flux court (3 barres) min dans le sens du trade pour un fade de bord
input double VPF_MinFlowBreak      = 0.10;   // Flux (CMF) min dans le sens pour une cassure de VA
input double VPF_MaxChaseATR       = 2.5;    // Distance max au-dela du bord apres cassure (x ATR)
input bool   VPF_ApplySpikeSymbols = false;  // Appliquer aussi aux Boom/Crash/PainX/GainX

// — État calculé (par chart) —
double g_vpPocPrice = 0.0, g_vpVah = 0.0, g_vpVal = 0.0;
datetime g_vpLastCalc = 0;

const string VP_PFX = "SMC_VP_";

// Calcule POC + VAH/VAL sur les N dernières bougies M1.
void VP_CalcProfile()
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, PERIOD_M1, 0, VP_LookbackBars, r);
   if(n < 20) return;

   double lo = r[0].low, hi = r[0].high;
   for(int i = 1; i < n; i++)
   {
      if(r[i].low < lo)  lo = r[i].low;
      if(r[i].high > hi) hi = r[i].high;
   }
   if(hi <= lo) return;

   int bins = MathMax(10, VP_PriceBins);
   double step = (hi - lo) / bins;
   long vol[];
   ArrayResize(vol, bins);
   ArrayInitialize(vol, 0);

   for(int i = 0; i < n; i++)
   {
      long v = (long)r[i].tick_volume;
      // Répartition du volume de la bougie sur les tranches couvertes
      int bLo = (int)((r[i].low  - lo) / step);
      int bHi = (int)((r[i].high - lo) / step);
      if(bLo < 0) bLo = 0;
      if(bHi >= bins) bHi = bins - 1;
      if(bHi < bLo) bHi = bLo;
      int span = bHi - bLo + 1;
      for(int b = bLo; b <= bHi; b++)
         vol[b] += (long)(v / span);
   }

   // POC = tranche au volume max ; VA = expansion 70% depuis le POC
   int pocBin = 0;
   for(int b = 1; b < bins; b++) if(vol[b] > vol[pocBin]) pocBin = b;

   double targetVol = 0, totalVol = 0;
   for(int b = 0; b < bins; b++) totalVol += (double)vol[b];
   targetVol = totalVol * (VP_ValueAreaPct / 100.0);

   int vaLoBin = pocBin, vaHiBin = pocBin;
   double acc = (double)vol[pocBin];
   bool tookLo = true;
   while(acc < targetVol && (vaLoBin > 0 || vaHiBin < bins - 1))
   {
      double vLo = (vaLoBin > 0)        ? (double)vol[vaLoBin - 1] : -1;
      double vHi = (vaHiBin < bins - 1) ? (double)vol[vaHiBin + 1] : -1;
      if(vLo >= vHi && vaLoBin > 0)      { vaLoBin--; acc += vLo; }
      else if(vaHiBin < bins - 1)        { vaHiBin++; acc += vHi; }
      else break;
   }

   g_vpPocPrice = lo + (pocBin + 0.5) * step;
   g_vpVah      = lo + (vaHiBin + 1.0) * step;
   g_vpVal      = lo + vaLoBin * step;
   g_vpLastCalc = TimeCurrent();
}

// ── Dessin: histogramme vertical sur le bord droit ──
void VP_DrawProfile()
{
   if(!UseVolumeProfile || !VP_DrawHistogram) return;
   if(g_vpLastCalc == 0) return;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(_Symbol, PERIOD_M1, 0, VP_LookbackBars, r);
   if(n < 20) return;

   double lo = r[0].low, hi = r[0].high;
   for(int i = 1; i < n; i++)
   {
      if(r[i].low < lo)  lo = r[i].low;
      if(r[i].high > hi) hi = r[i].high;
   }
   if(hi <= lo) return;
   int bins = MathMax(10, VP_PriceBins);
   double step = (hi - lo) / bins;

   for(int i = 0; i < 220; i++) { ObjectDelete(0, VP_PFX + "B" + (string)i); ObjectDelete(0, VP_PFX + "L" + (string)i); }

   // Largeur commune: barre max normalisée
   long vol[]; ArrayResize(vol, bins); ArrayInitialize(vol, 0);
   for(int i = 0; i < n; i++)
   {
      long v = (long)r[i].tick_volume;
      int bLo = (int)MathFloor((r[i].low  - lo) / step); if(bLo < 0) bLo = 0;
      int bHi = (int)MathFloor((r[i].high - lo) / step); if(bHi >= bins) bHi = bins - 1;
      int span = bHi - bLo + 1;
      for(int b = bLo; b <= bHi; b++) vol[b] += (long)(v / span);
   }
   long vMax = 0;
   for(int b = 0; b < bins; b++) if(vol[b] > vMax) vMax = vol[b];
   if(vMax <= 0) return;

   // FIX v1.48 (visible par défaut): l'histogramme couvre une fenêtre de
   // VP_WindowBars bougies TERMINALES de la zone VISIBLE (pas de temps futurs
   // qui demandent le décalage graphique, plus de rectangles àlargeur nulle).
   // FIX v1.49 (demande trader "ramène-le vers la gauche"): le profil se
   // termine VP_RightFreeBars bougies avant le prix courant, sur une fenêtre
   // de 12 bougies — nettement visible, sans masquer la bougie live.
   const int windowBars = 12;
   datetime tShift = PeriodSeconds(_Period) * MathMax(1, VP_RightFreeBars);
   datetime tRight = TimeCurrent() - tShift;
   datetime tLeft  = tRight - (datetime)PeriodSeconds(_Period) * windowBars;
   double spanSec  = (double)PeriodSeconds(_Period) * windowBars;
   if(spanSec <= 0) spanSec = 600;

   static datetime s_vpShownLog = 0;
   if(TimeCurrent() - s_vpShownLog >= 60)
   {
      s_vpShownLog = TimeCurrent();
      Print("🖼️ [VP] histogramme affiché ", _Symbol, " | POC=", DoubleToString(g_vpPocPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
            " VA=[", DoubleToString(g_vpVal, 5), " - ", DoubleToString(g_vpVah, 5), "]",
            " | fenêtre: ", TimeToString(tLeft, TIME_MINUTES), " -> ", TimeToString(tRight, TIME_MINUTES));
   }

   for(int b = 0; b < bins; b++)
   {
      if(vol[b] <= 0) continue;
      double wFrac = (double)vol[b] / (double)vMax;          // 0..1
      datetime t0 = tLeft;
      datetime t1 = tLeft + (datetime)(spanSec * wFrac);      // largeur la plus
      if(t1 <= t0) t1 = t0 + 1;
      double pLo = lo + b * step, pHi = lo + (b + 1) * step;
      string nm = VP_PFX + "B" + (string)b;
      if(ObjectFind(0, nm) < 0)
      {
         ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t0, pLo, t1, pHi);
         ObjectSetInteger(0, nm, OBJPROP_BACK, true);       // sous les bougies
         ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, nm, OBJPROP_FILL, true);
      }
      ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t0);
      ObjectSetInteger(0, nm, OBJPROP_TIME, 1, t1);
      ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, pLo);
      ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, pHi);

      bool inVA = (pLo >= g_vpVal && pHi <= g_vpVah);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, inVA ? VP_ColorVA : VP_ColorHist);
   }

   // POC: ligne dorée + label
   string pocName = VP_PFX + "POC";
   if(ObjectFind(0, pocName) < 0)
   {
      ObjectCreate(0, pocName, OBJ_TREND, 0, tLeft, g_vpPocPrice, tRight, g_vpPocPrice);
      ObjectSetInteger(0, pocName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, pocName, OBJPROP_RAY_RIGHT, false); // v1.48: fenêtre visible
      ObjectSetInteger(0, pocName, OBJPROP_WIDTH, 2);
   }
   ObjectSetInteger(0, pocName, OBJPROP_COLOR, VP_ColorPOC);
   ObjectMove(0, pocName, 0, tLeft, g_vpPocPrice);
   ObjectMove(0, pocName, 1, tRight, g_vpPocPrice);

   // Étiquette texte du POC au-dessus de la ligne (v1.49)
   string pocLbl = VP_PFX + "POC_LBL";
   int dg2 = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(ObjectFind(0, pocLbl) < 0)
   {
      ObjectCreate(0, pocLbl, OBJ_TEXT, 0, tLeft, g_vpPocPrice);
      ObjectSetInteger(0, pocLbl, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, pocLbl, OBJPROP_COLOR, VP_ColorPOC);
      ObjectSetInteger(0, pocLbl, OBJPROP_FONTSIZE, 9);
   }
   ObjectSetString(0, pocLbl, OBJPROP_TEXT, "POC " + DoubleToString(g_vpPocPrice, dg2));
   ObjectMove(0, pocLbl, 0, tLeft, g_vpPocPrice);

   if(VP_DrawValueArea)
   {
      string vaN = VP_PFX + "VAH", vaS = VP_PFX + "VAL";
      if(ObjectFind(0, vaN) < 0) { ObjectCreate(0, vaN, OBJ_TREND, 0, tLeft, g_vpVah, tRight, g_vpVah); ObjectSetInteger(0, vaN, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, vaN, OBJPROP_STYLE, STYLE_DOT); ObjectSetInteger(0, vaN, OBJPROP_RAY_RIGHT, false); }
      if(ObjectFind(0, vaS) < 0) { ObjectCreate(0, vaS, OBJ_TREND, 0, tLeft, g_vpVal, tRight, g_vpVal); ObjectSetInteger(0, vaS, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, vaS, OBJPROP_STYLE, STYLE_DOT); ObjectSetInteger(0, vaS, OBJPROP_RAY_RIGHT, false); }
      ObjectSetInteger(0, vaN, OBJPROP_COLOR, VP_ColorVA);
      ObjectSetInteger(0, vaS, OBJPROP_COLOR, VP_ColorVA);
      ObjectMove(0, vaN, 0, tLeft, g_vpVah); ObjectMove(0, vaN, 1, tRight, g_vpVah);
      ObjectMove(0, vaS, 0, tLeft, g_vpVal); ObjectMove(0, vaS, 1, tRight, g_vpVal);
   }
   ChartRedraw(0);
}

// ── TICK du module (calcul + dessin throtté) ──
void VP_OnTimerTick()
{
   if(!UseVolumeProfile) return;
   static datetime s_lastCalc = 0, s_lastDraw = 0;
   datetime now = TimeCurrent();
   if(now - s_lastCalc >= MathMax(5, VP_RefreshSec)) { s_lastCalc = now; VP_CalcProfile(); }
   if(now - s_lastDraw >= MathMax(5, VP_RefreshSec)) { s_lastDraw = now; VP_DrawProfile(); }
}

// ── GATE de confirmation finale (appelé par SMC_FinalOpenGate ou CPA) ──
// Money flow (Chaikin) sur barres M1 FERMEES : -1 (vendeurs) .. +1 (acheteurs)
double VPF_MoneyFlow(const string sym, const int bars, const int startShift)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(sym, PERIOD_M1, startShift, MathMax(2, bars), r);
   if(n < 2) return 0.0;
   double num = 0.0, den = 0.0;
   for(int i = 0; i < n; i++)
   {
      double v = (double)r[i].tick_volume;
      if(v <= 0.0) continue;
      double rng = r[i].high - r[i].low;
      double mfm = (rng > 0.0) ? (((r[i].close - r[i].low) - (r[i].high - r[i].close)) / rng) : 0.0;
      num += mfm * v;
      den += v;
   }
   return (den > 0.0) ? (num / den) : 0.0;
}

// Decision de localisation : les bords VAH/VAL sont les seuls points d'entree valides.
//  - FADE : SELL au VAH / BUY au VAL, avec bougie M1 de rejet + flux court dans le sens
//  - CASSURE : SELL sous VAL / BUY au-dessus VAH, flux CMF aligne, sans courir apres (anti-chase)
//  - Milieu de VA / autour du POC (aimant) : refuse
// level/src = niveau d'entree structurel utilise pour le SL.
bool SMC_VPF_Allows(const string symbol, const int dirSign, const double price, const double atr,
                    string &why, double &level, string &src)
{
   why = ""; level = 0.0; src = "";
   if(!UseVPFlowGate || !UseVolumeProfile) return true;
   if(symbol != _Symbol) return true;
   if(g_vpLastCalc == 0 || g_vpPocPrice <= 0.0 || g_vpVah <= g_vpVal) return true;
   if(TimeCurrent() - g_vpLastCalc > 180) return true;
   if(!VPF_ApplySpikeSymbols && SMC_IsSpikeStyleSymbol(symbol)) return true;
   if(atr <= 0.0 || price <= 0.0 || dirSign == 0) return true;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 3, r) < 3) return true;

   int    dg    = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double tol   = atr * MathMax(0.1, VPF_EdgeATR);
   double flowL = VPF_MoneyFlow(symbol, VPF_FlowBars, 1);
   double flowS = VPF_MoneyFlow(symbol, 3, 1);
   bool candleOk = (dirSign > 0) ? (r[1].close > r[1].open) : (r[1].close < r[1].open);
   string ctx = " | POC=" + DoubleToString(g_vpPocPrice, dg) +
                " VA=[" + DoubleToString(g_vpVal, dg) + " - " + DoubleToString(g_vpVah, dg) + "]" +
                " px=" + DoubleToString(price, dg) +
                " flow20=" + DoubleToString(flowL, 2) + " flow3=" + DoubleToString(flowS, 2);

   if(dirSign < 0)
   {
      if(price < g_vpVal)
      {
         if(price < g_vpVal - atr * VPF_MaxChaseATR) { why = "SELL tardif: trop loin sous VAL" + ctx; return false; }
         if(-flowL < VPF_MinFlowBreak)               { why = "SELL sous VAL sans flux vendeur" + ctx; return false; }
         level = g_vpVal; src = "VP_VAL_BREAK";
         return true;
      }
      bool touched = (MathMax(r[0].high, r[1].high) >= g_vpVah - tol) && (price <= g_vpVah + tol);
      if(touched && candleOk && (-flowS >= VPF_MinFlowFade)) { level = g_vpVah; src = "VP_VAH_FADE"; return true; }
      if(touched) { why = "SELL au VAH: rejet M1 ou flux vendeur non confirme" + ctx; return false; }
      why = "SELL hors bord VAH (milieu de VA / trop haut)" + ctx;
      return false;
   }

   if(price > g_vpVah)
   {
      if(price > g_vpVah + atr * VPF_MaxChaseATR) { why = "BUY tardif: trop loin au-dessus VAH" + ctx; return false; }
      if(flowL < VPF_MinFlowBreak)                { why = "BUY au-dessus VAH sans flux acheteur" + ctx; return false; }
      level = g_vpVah; src = "VP_VAH_BREAK";
      return true;
   }
   bool touchedL = (MathMin(r[0].low, r[1].low) <= g_vpVal + tol) && (price >= g_vpVal - tol);
   if(touchedL && candleOk && (flowS >= VPF_MinFlowFade)) { level = g_vpVal; src = "VP_VAL_FADE"; return true; }
   if(touchedL) { why = "BUY au VAL: rejet M1 ou flux acheteur non confirme" + ctx; return false; }
   why = "BUY hors bord VAL (milieu de VA / trop bas)" + ctx;
   return false;
}

// GATE appelee par SMC_FinalOpenGate (tous les chemins d'ouverture)
bool SMC_VP_EntryGateOK(const string symbol, const int dirSign)
{
   if(!UseVolumeProfile || !VP_BlockInValueArea) return true;
   if(symbol != _Symbol) return true;
   // v1.47: GOOD/PERFECT traverse la Value Area. Le flux/chase VPF ne doit
   // plus bloquer un PERFECT SELL deja sous VAL (ex. FX Vol dump).
   // v1.56: PERFECT peut traverser VA; GOOD soumis aux bords POC
   if(MathAbs(g_smcGomVerdictNum) >= 3 || MathAbs(g_smcGomVerdictNumServer) >= 3)
      return true;
   double px  = SymbolInfoDouble(symbol, (dirSign > 0) ? SYMBOL_ASK : SYMBOL_BID);
   double atr = SMC_EffectiveSymbolATR(symbol);
   string why = "", src = "";
   double lvl = 0.0;
   bool ok = SMC_VPF_Allows(symbol, dirSign, px, atr, why, lvl, src);
   if(!ok)
   {
      static datetime s_vpfLog = 0;
      if(TimeCurrent() - s_vpfLog >= 30)
      {
         s_vpfLog = TimeCurrent();
         Print("VP-GATE refuse ", symbol, " ", (dirSign > 0 ? "BUY" : "SELL"), " : ", why);
      }
   }
   return ok;
}

void VP_Cleanup()
{
   for(int i = 0; i < 220; i++) { ObjectDelete(0, VP_PFX + "B" + (string)i); ObjectDelete(0, VP_PFX + "L" + (string)i); }
   ObjectDelete(0, VP_PFX + "POC");
   ObjectDelete(0, VP_PFX + "POC_LBL");
   ObjectDelete(0, VP_PFX + "VAH");
   ObjectDelete(0, VP_PFX + "VAL");
}

// v1.47: GOOD/PERFECT traverse la Value Area.
#endif // SMC_VOLUME_PROFILE_MQH
