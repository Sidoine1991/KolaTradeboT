//+------------------------------------------------------------------+
//|                                                AngelOfSpike_Test.mq5  |
//|                    Test Simple pour Attachement au Graphique     |
//|                                                   Copyright 2025 |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🚀 Angel of Spike Test - Initialisation réussie !");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("⏹️ Angel of Spike Test - Arrêt");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Test simple - ne rien faire
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Test simple - ne rien faire
}
