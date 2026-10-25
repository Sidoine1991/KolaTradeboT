//+------------------------------------------------------------------+
//| SMC_Diagnostic.mq5 - Script de diagnostic pour SMC Universal      |
//| Vérifie l'état des modules, paramètres et affichage graphique      |
//+------------------------------------------------------------------+
#property copyright "TradBOT SMC"
#property version   "1.0"
#property script_show_inputs

#include "modules/SMC_SymbolCategory.mqh"
#include "modules/SMC_GOM_Pipeline.mqh"
#include "modules/SMC_SniperGraphics.mqh"
#include "modules/SMC_ICT2022Model.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== DIAGNOSTIC SMC UNIVERSAL ===");
   Print("Symbole: ", _Symbol);
   Print("Timeframe: ", EnumToString(Period()));
   
   // 1. Vérifier la catégorie du symbole
   ENUM_SYMBOL_CATEGORY category = SMC_GetSymbolCategory(_Symbol);
   Print("Catégorie symbole: ", EnumToString(category));
   
   bool isSpike = (category == SYM_BOOM_CRASH);
   bool isVol = (category == SYM_VOLATILITY);
   bool isForex = (category == SYM_FOREX);
   
   Print("Est spike style: ", isSpike ? "OUI" : "NON");
   Print("Est volatility: ", isVol ? "OUI" : "NON");
   Print("Est forex: ", isForex ? "OUI" : "NON");
   
   // 2. Vérifier l'état GOM
   Print("\n=== ÉTAT GOM ===");
   Print("GOM connecté: ", g_smcGomConnected ? "OUI" : "NON");
   Print("GOM verdict: ", g_smcGomVerdict);
   Print("GOM verdict num: ", g_smcGomVerdictNum);
   Print("GOM qualité: ", DoubleToString(g_smcGomQuality, 1), "%");
   Print("GOM cohérence: ", DoubleToString(g_smcGomCoherence, 1), "%");
   Print("GOM harmonisé M1: ", g_smcGomHarmonizedM1 ? "OUI" : "NON");
   
   // 3. Vérifier les modules sniper
   Print("\n=== MODULES SNIPER ===");
   Print("FVGs détectés: ", CountActiveFVGs());
   Print("Order Blocks détectés: ", CountActiveOrderBlocks());
   Print("Sniper Entries actives: ", CountActiveSniperEntries());
   Print("Liquidity Sweeps: ", CountActiveSweeps());
   Print("ICT Entries: ", CountActiveICTEntries());
   
   // 4. Vérifier les indicateurs techniques
   Print("\n=== INDICATEURS TECHNIQUES ===");
   double atr = iATR(_Symbol, PERIOD_CURRENT, 14, 0);
   Print("ATR actuel: ", DoubleToString(atr, _Digits));
   
   double ema20 = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
   double ema50 = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   Print("Prix actuel: ", DoubleToString(price, _Digits));
   Print("EMA 20: ", DoubleToString(ema20, _Digits));
   Print("EMA 50: ", DoubleToString(ema50, _Digits));
   Print("Prix vs EMA20: ", price > ema20 ? "AU-DESSUS" : "EN-DESSOUS");
   
   // 5. Vérifier les positions ouvertes
   Print("\n=== POSITIONS OUVERTES ===");
   int totalPositions = PositionsTotal();
   Print("Total positions: ", totalPositions);
   
   for(int i = 0; i < totalPositions; i++)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            Print("Position ", i+1, ": ", PositionGetString(POSITION_TYPE), 
                  " | Prix: ", PositionGetDouble(POSITION_PRICE_OPEN),
                  " | Profit: ", DoubleToString(PositionGetDouble(POSITION_PROFIT), 2));
         }
      }
   }
   
   // 6. Vérifier les graphiques
   Print("\n=== GRAPHIQUE ===");
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   Print("Taille graphique: ", chartWidth, "x", chartHeight);
   
   int objCount = ObjectsTotal(0, 0, -1);
   Print("Objets graphiques: ", objCount);
   
   // Compter les objets sniper
   int fvgCount = 0, obCount = 0, entryCount = 0, ictCount = 0;
   for(int i = 0; i < objCount; i++)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "SG_FVG_") >= 0) fvgCount++;
      if(StringFind(name, "SG_OB_") >= 0) obCount++;
      if(StringFind(name, "SG_ENTRY_") >= 0) entryCount++;
      if(StringFind(name, "ICT_") >= 0) ictCount++;
   }
   
   Print("Objets FVG: ", fvgCount);
   Print("Objets Order Block: ", obCount);
   Print("Objets Sniper Entry: ", entryCount);
   Print("Objets ICT: ", ictCount);
   
   // 7. Recommandations
   Print("\n=== RECOMMANDATIONS ===");
   
   if(!g_smcGomConnected)
      Print("⚠️ GOM non connecté - Vérifier ai_server.py");
   
   if(g_smcGomVerdictNum == 0)
      Print("⚠️ Verdict GOM = WAIT - Aucun ordre ne sera exécuté");
   
   if(isVol && CountActiveFVGs() == 0)
      Print("ℹ️ FxVol mais pas de FVGs détectés - Normal pour ce type de symbole");
   
   if(isVol && CountActiveOrderBlocks() == 0)
      Print("ℹ️ FxVol mais pas d'Order Blocks détectés - Normal pour ce type de symbole");
   
   if(fvgCount == 0 && obCount == 0)
      Print("⚠️ Aucun objet graphique sniper - Vérifier si les modules sont initialisés");
   
   if(totalPositions == 0 && g_smcGomVerdictNum != 0)
      Print("ℹ️ Aucune position mais verdict GOM actif - Vérifier les paramètres de trading");
   
   Print("\n=== FIN DU DIAGNOSTIC ===");
}

//+------------------------------------------------------------------+
//| Fonctions auxiliaires pour le diagnostic                           |
//+------------------------------------------------------------------+
int CountActiveFVGs()
{
   int count = 0;
   for(int i = 0; i < g_maxFVGs; i++)
   {
      if(g_fvgs[i].isActive) count++;
   }
   return count;
}

int CountActiveOrderBlocks()
{
   int count = 0;
   for(int i = 0; i < g_maxOrderBlocks; i++)
   {
      if(g_orderBlocks[i].isActive) count++;
   }
   return count;
}

int CountActiveSniperEntries()
{
   int count = 0;
   for(int i = 0; i < g_maxSniperEntries; i++)
   {
      if(g_sniperEntries[i].isActive) count++;
   }
   return count;
}

int CountActiveSweeps()
{
   int count = 0;
   for(int i = 0; i < g_maxSweeps; i++)
   {
      if(g_liquiditySweeps[i].isValid) count++;
   }
   return count;
}

int CountActiveICTEntries()
{
   int count = 0;
   for(int i = 0; i < g_maxICTEntries; i++)
   {
      if(g_ictEntries[i].isActive) count++;
   }
   return count;
}
