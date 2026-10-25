//+------------------------------------------------------------------+
//| SMC_ConfluenceRibbon.mqh                                         |
//| Ruban de confluence unique — score 0-100 qui regroupe            |
//| GOM + TF + Zone + Structure + TTM Squeeze + SR20/Impulse + DOW  |
//|                                                                   |
//| Visuel : bande colorée + label score                             |
//| Quand score ≥ 78 → COMBO VALIDÉ pour l'EA                        |
//|                                                                   |
//| NOTE: utilise les variables globales déjà déclarées dans         |
//| l'EA / GOM_Pipeline / PatternSignals (pas de extern).            |
//+------------------------------------------------------------------+
#property copyright "TradBOT SMC"
#property strict

#ifndef SMC_CONFLUENCE_RIBBON_MQH
#define SMC_CONFLUENCE_RIBBON_MQH

#include "SMC_TTMSqueeze.mqh"

// Seuils
#define RIBBON_COMBO_MIN          78
#define RIBBON_LIMIT_ONLY_MIN     65
#define RIBBON_DRAW               true

struct SMC_RibbonState
{
   int      score;           // 0-100
   bool     comboValidated;  // ≥ 78
   bool     limitOnly;       // 65-77
   string   topContributors; // ex: "GOM PERFECT + TTM FIRE + M5"
   string   detail;
   datetime lastUpdate;
};

SMC_RibbonState g_ribbon;

//+------------------------------------------------------------------+
//| Calcul du score de confluence                                    |
//| dirSign = +1 BUY, -1 SELL (direction envisagée)                  |
//| Utilise directement les globals de l'EA (déjà visibles).         |
//+------------------------------------------------------------------+
int SMC_Ribbon_ComputeScore(const int dirSign, string &detailOut)
{
   detailOut = "";
   if(dirSign == 0) return 0;

   int score = 0;
   string top = "";

   // 1) GOM (0 / 25 / 40 / 50)
   // g_smcGomConnected, g_smcGomVerdictNum, g_smcGomVerdict : SMC_GOM_Pipeline.mqh
   if(g_smcGomConnected)
   {
      int vn = g_smcGomVerdictNum;
      if(MathAbs(vn) >= 3 && ((vn > 0 && dirSign > 0) || (vn < 0 && dirSign < 0)))
      { score += 50; top += "GOM PERFECT "; }
      else if(MathAbs(vn) >= 2 && ((vn > 0 && dirSign > 0) || (vn < 0 && dirSign < 0)))
      { score += 40; top += "GOM GOOD "; }
      else if(MathAbs(vn) >= 1 && ((vn > 0 && dirSign > 0) || (vn < 0 && dirSign < 0)))
      { score += 25; top += "GOM SIMPLE "; }
      else if(vn == 0)
      { score += 0; top += "GOM WAIT "; }
      else
      { score -= 15; top += "GOM CONTRE "; }
   }

   // 2) Alignement TF courts M1+M5 (0-15)
   // g_smcTfM1Dir, g_smcTfM5Dir, g_smcTfH1Dir : SMC_GOM_Pipeline.mqh
   int tfPts = 0;
   string m1 = g_smcTfM1Dir; StringToUpper(m1);
   string m5 = g_smcTfM5Dir; StringToUpper(m5);
   string h1 = g_smcTfH1Dir; StringToUpper(h1);

   bool m1Ok = (dirSign > 0 && (m1 == "BULL" || m1 == "BUY" || m1 == "UP")) ||
               (dirSign < 0 && (m1 == "BEAR" || m1 == "SELL" || m1 == "DOWN"));
   bool m5Ok = (dirSign > 0 && (m5 == "BULL" || m5 == "BUY" || m5 == "UP")) ||
               (dirSign < 0 && (m5 == "BEAR" || m5 == "SELL" || m5 == "DOWN"));
   bool h1Ok = (dirSign > 0 && (h1 == "BULL" || h1 == "BUY" || h1 == "UP")) ||
               (dirSign < 0 && (h1 == "BEAR" || h1 == "SELL" || h1 == "DOWN"));
   bool h1Against = (dirSign > 0 && (h1 == "BEAR" || h1 == "SELL" || h1 == "DOWN")) ||
                    (dirSign < 0 && (h1 == "BULL" || h1 == "BUY" || h1 == "UP"));

   if(m1Ok && m5Ok) { tfPts += 12; top += "+M1/M5 "; }
   else if(m5Ok)    { tfPts += 7;  top += "+M5 "; }
   else if(m1Ok)    { tfPts += 4; }
   if(h1Ok)         { tfPts += 3;  top += "+H1 "; }
   if(h1Against)    { tfPts -= 6; }
   score += MathMax(0, tfPts);

   // 3) Zone Premium/Discount (0-12)
   // g_priceZone* : SMC_Universal.mq5
   if(dirSign > 0 && (g_priceInDiscount || g_priceZonePct <= 35.0))
   { score += 10; if(g_priceZonePct <= 18.0) score += 2; top += "+DISC "; }
   else if(dirSign < 0 && (g_priceInPremium || g_priceZonePct >= 65.0))
   { score += 10; if(g_priceZonePct >= 82.0) score += 2; top += "+PREM "; }
   else if(g_priceInEquilibrium || (g_priceZonePct > 40.0 && g_priceZonePct < 60.0))
   { score -= 8; top += "+MID "; }

   // 4) TTM Squeeze (0-20)
   int ttmPts = SMC_TTM_ConfluencePoints(dirSign);
   score += ttmPts;
   if(ttmPts >= 12) top += "+TTM ";
   else if(ttmPts >= 6) top += "+TTM~ ";

   // 5) Structure SR20 / Impulse / DISP (0-15)
   int structPts = 0;
   if(dirSign > 0 && (g_sr20BounceArmedBuy || g_impulseSupTouched)) { structPts += 7; top += "+SR20/IMP "; }
   if(dirSign < 0 && (g_sr20BounceArmedSell || g_impulseResTouched)) { structPts += 7; top += "+SR20/IMP "; }
   if(g_dispTrailValid && !g_dispTrailBroken) { structPts += 5; top += "+DISP "; }
   score += MathMin(15, structPts);

   // 6) Bonus si déjà très haut
   if(score >= 70) score += 3;

   score = MathMax(0, MathMin(100, score));
   detailOut = top;
   return score;
}

//+------------------------------------------------------------------+
//| Mise à jour + dessin                                             |
//+------------------------------------------------------------------+
void SMC_Ribbon_Update(const int dirSignHint = 0)
{
   int dir = dirSignHint;
   if(dir == 0 && g_smcGomConnected && g_smcGomVerdictNum != 0)
      dir = (g_smcGomVerdictNum > 0) ? 1 : -1;

   string detail = "";
   int sc = SMC_Ribbon_ComputeScore(dir, detail);

   g_ribbon.score          = sc;
   g_ribbon.comboValidated = (sc >= RIBBON_COMBO_MIN);
   g_ribbon.limitOnly      = (sc >= RIBBON_LIMIT_ONLY_MIN && sc < RIBBON_COMBO_MIN);
   g_ribbon.topContributors = detail;
   g_ribbon.detail         = StringFormat("Score %d | %s", sc, detail);
   g_ribbon.lastUpdate     = TimeCurrent();

   if(RIBBON_DRAW)
      SMC_Ribbon_Draw();
}

void SMC_Ribbon_Draw()
{
   string name = "SMC_RIBBON_" + _Symbol;
   ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return;

   color c = clrGray;
   string prefix = "RIBBON ";
   if(g_ribbon.comboValidated)
   {
      c = clrLime;
      prefix = "★ COMBO ";
   }
   else if(g_ribbon.limitOnly)
   {
      c = clrGold;
      prefix = "LIMIT ";
   }
   else if(g_ribbon.score >= 40)
      c = clrOrange;
   else
      c = clrTomato;

   string txt = prefix + IntegerToString(g_ribbon.score) + "  " + g_ribbon.topContributors;

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 12);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 22);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 11);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

// API simple pour les gates d'entrée
bool SMC_Ribbon_ComboOK(const int dirSign, string &whyOut)
{
   SMC_Ribbon_Update(dirSign);
   if(g_ribbon.comboValidated)
   {
      whyOut = "COMBO " + IntegerToString(g_ribbon.score) + " — " + g_ribbon.topContributors;
      return true;
   }
   whyOut = "Score " + IntegerToString(g_ribbon.score) + " < " + IntegerToString(RIBBON_COMBO_MIN) +
            " | " + g_ribbon.topContributors;
   return false;
}

bool SMC_Ribbon_LimitAllowed(const int dirSign)
{
   SMC_Ribbon_Update(dirSign);
   return (g_ribbon.score >= RIBBON_LIMIT_ONLY_MIN);
}

#endif // SMC_CONFLUENCE_RIBBON_MQH
