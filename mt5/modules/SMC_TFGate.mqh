//+------------------------------------------------------------------+
//| SMC_TFGate.mqh — Multi-Timeframe Alignment Gate                  |
//| Top-down analysis: D1→H4→H1→M15→M5→M1                          |
//| Bloque les entrées quand les TFs supérieurs contredisent        |
//| Boost les entrées quand tous les TFs sont alignés               |
//+------------------------------------------------------------------+
#ifndef SMC_TFGATE_MQH
#define SMC_TFGATE_MQH

//--- Input (1 seul — le reste hardcodé) ---
input bool UseTFGate = true;  // Activer la gate d'alignement multi-TF

//--- Poids des TFs (top-down) — somme = 100 ---
#define TFW_D1     30   // Tendance principale — le plus important
#define TFW_H4     25   // Tendance secondaire
#define TFW_H1     20   // Tendance intraday
#define TFW_M15    10   // Momentum court
#define TFW_M5     10   // Timing entrée
#define TFW_M1      5   // Précision entrée

//--- Seuils de score ---
#define TFSCORE_BOOSTED    70   // Tous TFs alignés → entrée boostée
#define TFSCORE_ALLOWED    40   // Assez aligné → entrée normale
#define TFSCORE_REDUCED    10   // Mixte → entrée réduite, SL serré
// < TFSCORE_REDUCED → BLOQUÉ

//--- Règles dures ---
#define TFSCORE_HARD_BLOCK_D1    true   // Si D1 contredit → BLOCÉ
#define TFSCORE_HARD_BLOCK_H4H1  true   // Si H4+H1 contredisent → BLOCÉ

//--- État interne ---
struct TFGateState
{
   int    score;         // Score total (-100 à +100)
   string level;         // "BOOSTED", "ALLOWED", "REDUCED", "BLOCKED"
   string reason;        // Explication du blocage
   int    bullCount;     // Nombre de TFs BULL
   int    bearCount;     // Nombre de TFs BEAR
   int    alignedCount;  // Nombre de TFs alignés avec la direction
   bool   d1Contradicts; // D1 contredit la direction
   bool   h4Contradicts; // H4 contredit
   bool   h1Contradicts; // H1 contdit
};

TFGateState g_tfGateState;

//+------------------------------------------------------------------+
//| Convertit la direction string en signe (-1, 0, +1)              |
//+------------------------------------------------------------------+
int TFGate_DirToSign(const string dir)
{
   if(dir == "BULL" || dir == "BUY")  return 1;
   if(dir == "BEAR" || dir == "SELL") return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Évalue l'alignement TF pour une direction donnée                |
//| dirSign: +1 = BUY, -1 = SELL                                    |
//| Retourne le score (-100 à +100) et remplit le state             |
//+------------------------------------------------------------------+
int TFGate_Score(const int dirSign)
{
   if(dirSign == 0) return 0;

   g_tfGateState.score = 0;
   g_tfGateState.bullCount = 0;
   g_tfGateState.bearCount = 0;
   g_tfGateState.alignedCount = 0;
   g_tfGateState.d1Contradicts = false;
   g_tfGateState.h4Contradicts = false;
   g_tfGateState.h1Contradicts = false;
   g_tfGateState.reason = "";

   // Tableau des TFs et leurs poids
   string tfDirs[6];
   int    tfWeights[6];

   tfDirs[0] = g_smcTfD1Dir;  tfWeights[0] = TFW_D1;
   tfDirs[1] = g_smcTfH4Dir;  tfWeights[1] = TFW_H4;
   tfDirs[2] = g_smcTfH1Dir;  tfWeights[2] = TFW_H1;
   tfDirs[3] = g_smcTfM15Dir; tfWeights[3] = TFW_M15;
   tfDirs[4] = g_smcTfM5Dir;  tfWeights[4] = TFW_M5;
   tfDirs[5] = g_smcTfM1Dir;  tfWeights[5] = TFW_M1;

   int totalScore = 0;

   for(int i = 0; i < 6; i++)
   {
      int tfSign = TFGate_DirToSign(tfDirs[i]);
      if(tfSign == 1) g_tfGateState.bullCount++;
      if(tfSign == -1) g_tfGateState.bearCount++;

      if(tfSign == dirSign)
      {
         // Aligné → ajouter le poids complet
         totalScore += tfWeights[i];
         g_tfGateState.alignedCount++;
      }
      else if(tfSign == -dirSign)
      {
         // Contredit → soustraire le poids
         totalScore -= tfWeights[i];

         // Marquer les contradictions critiques
         if(i == 0) g_tfGateState.d1Contradicts = true;
         if(i == 1) g_tfGateState.h4Contradicts = true;
         if(i == 2) g_tfGateState.h1Contradicts = true;
      }
      // Neutre (tfSign == 0) → 0 point
   }

   g_tfGateState.score = totalScore;

   // --- Appliquer les règles dures ---
   string blockReason = "";

   if(TFSCORE_HARD_BLOCK_D1 && g_tfGateState.d1Contradicts)
      blockReason = "D1 contredit la direction";

   if(TFSCORE_HARD_BLOCK_H4H1 && g_tfGateState.h4Contradicts && g_tfGateState.h1Contradicts)
      blockReason = "H4+H1 contredisent la direction";

   // --- Classifier le niveau ---
   if(StringLen(blockReason) > 0)
   {
      g_tfGateState.level = "BLOCKED";
      g_tfGateState.reason = blockReason;
   }
   else if(totalScore >= TFSCORE_BOOSTED)
   {
      g_tfGateState.level = "BOOSTED";
      g_tfGateState.reason = StringFormat("%d/6 TFs alignés (score %d)", g_tfGateState.alignedCount, totalScore);
   }
   else if(totalScore >= TFSCORE_ALLOWED)
   {
      g_tfGateState.level = "ALLOWED";
      g_tfGateState.reason = StringFormat("%d/6 TFs alignés (score %d)", g_tfGateState.alignedCount, totalScore);
   }
   else if(totalScore >= TFSCORE_REDUCED)
   {
      g_tfGateState.level = "REDUCED";
      g_tfGateState.reason = StringFormat("TFs mixtes (score %d)", totalScore);
   }
   else
   {
      g_tfGateState.level = "BLOCKED";
      g_tfGateState.reason = StringFormat("TFs trop opposés (score %d)", totalScore);
   }

   return totalScore;
}

//+------------------------------------------------------------------+
//| Gate principale : autorise, réduit ou bloque une entrée         |
//| Retourne true si l'entrée est autorisée                         |
//| isReduced: true = SL serré, lot réduit                          |
//+------------------------------------------------------------------+
bool TFGate_AllowEntry(const int dirSign, bool &isReduced)
{
   isReduced = false;
   if(!UseTFGate) return true;
   if(dirSign == 0) return false;

   TFGate_Score(dirSign);

   if(g_tfGateState.level == "BLOCKED")
   {
      Print("🚫 TF GATE BLOCKED | dir=", (dirSign > 0 ? "BUY" : "SELL"),
            " | score=", g_tfGateState.score,
            " | D1=", g_smcTfD1Dir, " H4=", g_smcTfH4Dir,
            " H1=", g_smcTfH1Dir, " M15=", g_smcTfM15Dir,
            " M5=", g_smcTfM5Dir, " M1=", g_smcTfM1Dir,
            " | reason: ", g_tfGateState.reason);
      return false;
   }

   if(g_tfGateState.level == "REDUCED")
   {
      isReduced = true;
      Print("⚠️ TF GATE REDUCED | dir=", (dirSign > 0 ? "BUY" : "SELL"),
            " | score=", g_tfGateState.score,
            " | aligned=", g_tfGateState.alignedCount, "/6",
            " | reason: ", g_tfGateState.reason);
   }

   if(g_tfGateState.level == "BOOSTED")
   {
      Print("✅ TF GATE BOOSTED | dir=", (dirSign > 0 ? "BUY" : "SELL"),
            " | score=", g_tfGateState.score,
            " | aligned=", g_tfGateState.alignedCount, "/6");
   }

   return true;
}

//+------------------------------------------------------------------+
//| Retourne le multiplicateur de SL basé sur le niveau TF         |
//| REDUCED → SL serré (0.7x), ALLOWED → normal (1.0x),            |
//| BOOSTED → SL plus large (1.2x, plus de marge)                   |
//+------------------------------------------------------------------+
double TFGate_GetSLMultiplier()
{
   if(!UseTFGate) return 1.0;
   if(g_tfGateState.level == "REDUCED")  return 0.7;  // SL serré
   if(g_tfGateState.level == "BOOSTED")  return 1.2;  // Plus de marge
   return 1.0;  // ALLOWED
}

//+------------------------------------------------------------------+
//| Retourne le multiplicateur de lot basé sur le niveau TF        |
//| REDUCED → lot réduit (0.5x), ALLOWED → normal (1.0x),          |
//| BOOSTED → lot augmenté (1.2x)                                   |
//+------------------------------------------------------------------+
double TFGate_GetLotMultiplier()
{
   if(!UseTFGate) return 1.0;
   if(g_tfGateState.level == "REDUCED")  return 0.5;  // Lot réduit
   if(g_tfGateState.level == "BOOSTED")  return 1.2;  // Lot augmenté
   return 1.0;  // ALLOWED
}

//+------------------------------------------------------------------+
//| Affiche le résumé du TF Gate sur le chart                       |
//+------------------------------------------------------------------+
void TFGate_DrawPanel(int x, int y)
{
   if(!UseTFGate) return;

   string prefix = "TFG_";
   // Supprimer l'ancien fond rectangulaire s'il existe encore
   if(ObjectFind(0, prefix + "bg") >= 0) ObjectDelete(0, prefix + "bg");

   // Titre
   ObjectCreate(0, prefix + "title", OBJ_TEXT, 0, 0, 0);
   ObjectSetInteger(0, prefix + "title", OBJPROP_XDISTANCE, x + 5);
   ObjectSetInteger(0, prefix + "title", OBJPROP_YDISTANCE, y + 5);
   ObjectSetString(0, prefix + "title", OBJPROP_TEXT, "TF ALIGNEMENT GATE");
   ObjectSetString(0, prefix + "title", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, prefix + "title", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, prefix + "title", OBJPROP_COLOR, clrWhite);

   // Directions TF
   string tfLine = StringFormat("D1:%s H4:%s H1:%s", g_smcTfD1Dir, g_smcTfH4Dir, g_smcTfH1Dir);
   ObjectCreate(0, prefix + "tf1", OBJ_TEXT, 0, 0, 0);
   ObjectSetInteger(0, prefix + "tf1", OBJPROP_XDISTANCE, x + 5);
   ObjectSetInteger(0, prefix + "tf1", OBJPROP_YDISTANCE, y + 22);
   ObjectSetString(0, prefix + "tf1", OBJPROP_TEXT, tfLine);
   ObjectSetInteger(0, prefix + "tf1", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, prefix + "tf1", OBJPROP_COLOR, clrSilver);

   string tfLine2 = StringFormat("M15:%s M5:%s M1:%s", g_smcTfM15Dir, g_smcTfM5Dir, g_smcTfM1Dir);
   ObjectCreate(0, prefix + "tf2", OBJ_TEXT, 0, 0, 0);
   ObjectSetInteger(0, prefix + "tf2", OBJPROP_XDISTANCE, x + 5);
   ObjectSetInteger(0, prefix + "tf2", OBJPROP_YDISTANCE, y + 35);
   ObjectSetString(0, prefix + "tf2", OBJPROP_TEXT, tfLine2);
   ObjectSetInteger(0, prefix + "tf2", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, prefix + "tf2", OBJPROP_COLOR, clrSilver);

   // Score + Level
   color levelClr = clrGray;
   if(g_tfGateState.level == "BOOSTED")  levelClr = clrLime;
   if(g_tfGateState.level == "ALLOWED")  levelClr = clrGold;
   if(g_tfGateState.level == "REDUCED")  levelClr = clrOrange;
   if(g_tfGateState.level == "BLOCKED")  levelClr = clrRed;

   string scoreLine = StringFormat("Score: %d | %s", g_tfGateState.score, g_tfGateState.level);
   ObjectCreate(0, prefix + "score", OBJ_TEXT, 0, 0, 0);
   ObjectSetInteger(0, prefix + "score", OBJPROP_XDISTANCE, x + 5);
   ObjectSetInteger(0, prefix + "score", OBJPROP_YDISTANCE, y + 52);
   ObjectSetString(0, prefix + "score", OBJPROP_TEXT, scoreLine);
   ObjectSetInteger(0, prefix + "score", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, prefix + "score", OBJPROP_COLOR, levelClr);

   // Aligned count
   string alignLine = StringFormat("Alignés: %d/6 | Bull: %d Bear: %d",
                                   g_tfGateState.alignedCount,
                                   g_tfGateState.bullCount,
                                   g_tfGateState.bearCount);
   ObjectCreate(0, prefix + "align", OBJ_TEXT, 0, 0, 0);
   ObjectSetInteger(0, prefix + "align", OBJPROP_XDISTANCE, x + 5);
   ObjectSetInteger(0, prefix + "align", OBJPROP_YDISTANCE, y + 68);
   ObjectSetString(0, prefix + "align", OBJPROP_TEXT, alignLine);
   ObjectSetInteger(0, prefix + "align", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, prefix + "align", OBJPROP_COLOR, clrSilver);

   // Reason
   if(StringLen(g_tfGateState.reason) > 0)
   {
      ObjectCreate(0, prefix + "reason", OBJ_TEXT, 0, 0, 0);
      ObjectSetInteger(0, prefix + "reason", OBJPROP_XDISTANCE, x + 5);
      ObjectSetInteger(0, prefix + "reason", OBJPROP_YDISTANCE, y + 85);
      ObjectSetString(0, prefix + "reason", OBJPROP_TEXT, g_tfGateState.reason);
      ObjectSetInteger(0, prefix + "reason", OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, prefix + "reason", OBJPROP_COLOR, clrGray);
   }
}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
void TFGate_Init()
{
   g_tfGateState.score = 0;
   g_tfGateState.level = "N/A";
   g_tfGateState.reason = "Not initialized";
   g_tfGateState.alignedCount = 0;
   g_tfGateState.bullCount = 0;
   g_tfGateState.bearCount = 0;
   Print("📊 TF Gate module initialized");
}

//+------------------------------------------------------------------+
//| Nettoyage chart                                                  |
//+------------------------------------------------------------------+
void TFGate_Cleanup()
{
   string prefix = "TFG_";
   string names[] = {"bg", "title", "tf1", "tf2", "score", "align", "reason"};
   for(int i = 0; i < ArraySize(names); i++)
      ObjectDelete(0, prefix + names[i]);
}

#endif // SMC_TFGATE_MQH
