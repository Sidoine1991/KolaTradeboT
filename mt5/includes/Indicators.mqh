//+------------------------------------------------------------------+
//| Indicators.mqh - Gestion des indicateurs pour Fx_robot           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property strict

//--- Inclusions
#include "D:\\Dev\\TradBOT\\mt5\\includes\\Common.mqh"

//+------------------------------------------------------------------+
//| Calcul du VPIN (Volume-Synchronized Probability of Informed Trading)
//+------------------------------------------------------------------+
double ComputeVPIN(int windowBars, ENUM_TIMEFRAMES tf, string symbol)
{
   if(windowBars <= 10) return 0.0;
   
   MqlRates rates[];
   int copied = CopyRates(symbol, tf, 1, windowBars, rates);
   if(copied <= 0) 
   {
      Print("Erreur dans CopyRates pour VPIN: ", GetLastError());
      return 0.0;
   }
   
   double buyVol = 0.0, sellVol = 0.0, totalVol = 0.0;
   
   for(int i = 0; i < copied; i++)
   {
      double volume = (double)rates[i].tick_volume;
      totalVol += volume;
      
      if(rates[i].close > rates[i].open)
         buyVol += volume;
      else if(rates[i].close < rates[i].open)
         sellVol += volume;
      else
      {
         buyVol += volume * 0.5;
         sellVol += volume * 0.5;
      }
   }
   
   if(totalVol <= 0.0) return 0.0;
   
   return MathAbs(buyVol - sellVol) / totalVol;
}

//+------------------------------------------------------------------+
//| Calcul de l'OBI (Order Book Imbalance)                           |
//+------------------------------------------------------------------+
double ComputeOBI(int lookbackBars, ENUM_TIMEFRAMES tf, string symbol)
{
   if(lookbackBars <= 10) return 0.0;
   
   MqlRates rates[];
   int copied = CopyRates(symbol, tf, 1, lookbackBars, rates);
   if(copied <= 0)
   {
      Print("Erreur dans CopyRates pour OBI: ", GetLastError());
      return 0.0;
   }
   
   double buyVol = 0.0, sellVol = 0.0;
   
   for(int i = 0; i < copied; i++)
   {
      double volume = (double)rates[i].tick_volume;
      
      if(rates[i].close > rates[i].open)
         buyVol += volume;
      else if(rates[i].close < rates[i].open)
         sellVol += volume;
      else
      {
         buyVol += volume * 0.5;
         sellVol += volume * 0.5;
      }
   }
   
   double total = buyVol + sellVol;
   if(total <= 0.0) return 0.0;
   
   return (buyVol - sellVol) / total;
}

//+------------------------------------------------------------------+
//| Calcul du CVD (Cumulative Volume Delta)                          |
//+------------------------------------------------------------------+
double ComputeCVD(int windowBars, ENUM_TIMEFRAMES tf, string symbol)
{
   if(windowBars <= 5) return 0.0;
   
   MqlRates rates[];
   int copied = CopyRates(symbol, tf, 1, windowBars, rates);
   if(copied <= 0)
   {
      Print("Erreur dans CopyRates pour CVD: ", GetLastError());
      return 0.0;
   }
   
   double cvd = 0.0;
   
   for(int i = 0; i < copied; i++)
   {
      double sign = 0.0;
      if(rates[i].close > rates[i].open)
         sign = 1.0;
      else if(rates[i].close < rates[i].open)
         sign = -1.0;
         
      cvd += sign * (double)rates[i].tick_volume;
   }
   
   return cvd;
}

//+------------------------------------------------------------------+
//| Vérifie si un symbole est un indice de volatilité                |
//+------------------------------------------------------------------+
bool IsVolatilityIndex(string symbol)
{
   ToLowerCase(symbol);
   return (StringFind(symbol, "volatility") >= 0 || 
           StringFind(symbol, "boom") >= 0 || 
           StringFind(symbol, "crash") >= 0 ||
           StringFind(symbol, "step") >= 0);
}

//+------------------------------------------------------------------+
//| Vérifie si un symbole est un indice Boom/Crash                   |
//+------------------------------------------------------------------+
bool IsBoomCrashIndex(string symbol)
{
   ToLowerCase(symbol);
   return (StringFind(symbol, "boom") >= 0 || StringFind(symbol, "crash") >= 0);
}

//+------------------------------------------------------------------+
//| Vérifie si un symbole est un indice Step                         |
//+------------------------------------------------------------------+
bool IsStepIndex(string symbol)
{
   ToLowerCase(symbol);
   return (StringFind(symbol, "step") >= 0);
}
