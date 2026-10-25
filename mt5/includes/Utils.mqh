//+------------------------------------------------------------------+
//| Utils.mqh - Fonctions utilitaires pour Fx_robot                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property strict

//--- Inclusions
#include "D:\\Dev\\TradBOT\\mt5\\includes\\Common.mqh"

//+------------------------------------------------------------------+
//| Obtient le nombre de bougies disponibles pour un symbole         |
//+------------------------------------------------------------------+
int GetBarsCount(string symbol, ENUM_TIMEFRAMES timeframe)
{
   if(!SymbolSelect(symbol, true)) 
   {
      Print("Erreur: Impossible de sélectionner le symbole ", symbol);
      return 0;
   }
   
   datetime times[];
   if(CopyTime(symbol, timeframe, 0, 1, times) <= 0)
   {
      Print("Erreur dans CopyTime pour ", symbol, ": ", GetLastError());
      return 0;
   }
   
   return (int)SeriesInfoInteger(symbol, timeframe, SERIES_BARS_COUNT);
}

//+------------------------------------------------------------------+
//| Obtient la valeur actuelle de l'ATR                              |
//+------------------------------------------------------------------+
double GetCurrentATR(int atr_handle)
{
   if(atr_handle == INVALID_HANDLE)
   {
      Print("Erreur: Handle ATR invalide");
      return 0.0;
   }
   
   double atr_values[1];
   if(CopyBuffer(atr_handle, 0, 0, 1, atr_values) <= 0)
   {
      Print("Erreur lors de la copie du buffer ATR: ", GetLastError());
      return 0.0;
   }
   
   return atr_values[0];
}

//+------------------------------------------------------------------+
//| Calcule les niveaux de stop loss et take profit                  |
//+------------------------------------------------------------------+
void CalculateSLTP(string symbol, double entry, int direction, double atr, double &sl, double &tp)
{
   if(direction == 0 || atr <= 0) 
   {
      sl = 0;
      tp = 0;
      return;
   }
   
   if(!SymbolSelect(symbol, true)) 
   {
      Print("Erreur: Impossible de sélectionner le symbole ", symbol);
      sl = 0;
      tp = 0;
      return;
   }

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double stopLevel = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double minStopDistance = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

   // Calculer les niveaux SL et TP en fonction de l'ATR
   double atrSl = atr * InpATRMultiplier;
   double atrTp = atr * (InpATRMultiplier * 2);

   if(direction > 0) // Achat
   {
      sl = NormalizeDouble(entry - atrSl, digits);
      tp = NormalizeDouble(entry + atrTp, digits);
      
      // Vérifier les niveaux de stop minimum
      double minSl = entry - stopLevel;
      if(sl > minSl) sl = minSl;
      
      double minTpDistance = stopLevel * 2;
      if((tp - entry) < minTpDistance) 
         tp = entry + minTpDistance;
   }
   else // Vente
   {
      sl = NormalizeDouble(entry + atrSl, digits);
      tp = NormalizeDouble(entry - atrTp, digits);
      
      // Vérifier les niveaux de stop minimum
      double maxSl = entry + stopLevel;
      if(sl < maxSl) sl = maxSl;
      
      double minTpDistance = stopLevel * 2;
      if((entry - tp) < minTpDistance) 
         tp = entry - minTpDistance;
   }

   // Ajuster aux pas de prix autorisés
   sl = NormalizeDouble(MathFloor(sl / tickSize) * tickSize, digits);
   tp = NormalizeDouble(MathFloor(tp / tickSize) * tickSize, digits);
   
   // Vérifier que le stop n'est pas trop proche du prix d'entrée
   if(direction > 0 && (entry - sl) < minStopDistance)
      sl = entry - minStopDistance;
   else if(direction < 0 && (sl - entry) < minStopDistance)
      sl = entry + minStopDistance;
}

//+------------------------------------------------------------------+
//| Supprime les espaces en début et fin de chaîne                   |
//+------------------------------------------------------------------+
string StringTrim(string str)
{
   string result = "";
   int len = StringLen(str);
   int start = 0, end = len - 1;
   
   // Trouver le premier caractère non blanc
   while(start < len && (StringGetCharacter(str, start) == ' ' || 
                         StringGetCharacter(str, start) == '\t' || 
                         StringGetCharacter(str, start) == '\n' || 
                         StringGetCharacter(str, start) == '\r'))
   {
      start++;
   }
   
   // Si la chaîne est vide ou ne contient que des espaces
   if(start >= len) return "";
   
   // Trouver le dernier caractère non blanc
   while(end >= 0 && (StringGetCharacter(str, end) == ' ' || 
                      StringGetCharacter(str, end) == '\t' || 
                      StringGetCharacter(str, end) == '\n' || 
                      StringGetCharacter(str, end) == '\r'))
   {
      end--;
   }
   
   // Extraire la sous-chaîne sans les espaces
   if(end >= start)
   {
      result = StringSubstr(str, start, end - start + 1);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Convertit une chaîne en minuscules (version personnalisée)       |
//+------------------------------------------------------------------+
void ToLowerCase(string &str)
{
   string result = "";
   int len = StringLen(str);
   
   for(int i = 0; i < len; i++)
   {
      ushort ch = StringGetCharacter(str, i);
      if(ch >= 'A' && ch <= 'Z')
         ch += 32; // Convertir en minuscule
      result += ShortToString(ch);
   }
   
   str = result;
}

//+------------------------------------------------------------------+
//| Vérifie si une chaîne contient une sous-chaîne (insensible à la casse)
//+------------------------------------------------------------------+
bool StringContains(string str, string substr)
{
   StringToLower(str);
   StringToLower(substr);
   
   return (StringFind(str, substr) >= 0);
}

//+------------------------------------------------------------------+
//| Formate un message de journal avec un horodatage                 |
//+------------------------------------------------------------------+
string FormatLogMessage(string message)
{
   return StringFormat("[%s] %s", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), message);
}

//+------------------------------------------------------------------+
//| Journalise un message avec un niveau de sévérité                 |
//+------------------------------------------------------------------+
void LogMessage(string message, int level = 0)
{
   string prefix = "";
   
   switch(level)
   {
      case 0:  prefix = "INFO"; break;
      case 1:  prefix = "WARNING"; break;
      case 2:  prefix = "ERROR"; break;
      case 3:  prefix = "DEBUG"; break;
      default: prefix = "UNKNOWN";
   }
   
   string logMessage = StringFormat("[%s] %s: %s", 
                                   TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), 
                                   prefix, 
                                   message);
   
   Print(logMessage);
   
   // Écrire dans un fichier de log si nécessaire
   // int file_handle = FileOpen("FxRobot_" + TimeToString(TimeCurrent(), TIME_DATE) + ".log", 
   //                           FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   // if(file_handle != INVALID_HANDLE)
   // {
   //    FileSeek(file_handle, 0, SEEK_END);
   //    FileWriteString(file_handle, logMessage + "\n");
   //    FileClose(file_handle);
   // }
}

//+------------------------------------------------------------------+
//| Vérifie si le marché est ouvert pour un symbole donné            |
//+------------------------------------------------------------------+
bool IsMarketOpen(string symbol)
{
   if(!SymbolSelect(symbol, true))
   {
      Print("Erreur: Impossible de sélectionner le symbole ", symbol);
      return false;
   }
   
   // Vérifier si le trading est autorisé pour ce symbole
   long tradeMode;
   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE, tradeMode))
   {
      Print("Erreur: Impossible de récupérer le mode de trading pour ", symbol);
      return false;
   }
   
   return (tradeMode == SYMBOL_TRADE_MODE_FULL);
}

//+------------------------------------------------------------------+
//| Obtient le spread actuel en points                               |
//+------------------------------------------------------------------+
double GetCurrentSpread(string symbol)
{
   if(!SymbolSelect(symbol, true))
   {
      Print("Erreur: Impossible de sélectionner le symbole ", symbol);
      return 0.0;
   }
   
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(ask <= 0 || bid <= 0 || point <= 0)
   {
      Print("Erreur: Données de prix invalides pour ", symbol);
      return 0.0;
   }
   
   return (ask - bid) / point;
}

//+------------------------------------------------------------------+
//| Calcule le nombre de lots en fonction du risque                  |
//+------------------------------------------------------------------+
double CalculateLotSizeByRisk(string symbol, double riskPercent, double stopLossPoints)
{
   if(stopLossPoints <= 0) 
   {
      Print("Erreur: Stop loss doit être supérieur à 0");
      return 0.0;
   }
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (riskPercent / 100.0);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(tickValue <= 0 || tickSize <= 0 || point <= 0)
   {
      Print("Erreur: Données de symbole invalides pour ", symbol);
      return 0.0;
   }
   
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   // Calculer la taille de position en fonction du risque
   double lotSize = riskAmount / (stopLossPoints * tickValue * point / tickSize);
   
   // Arrondir au pas de lot le plus proche
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Vérifier les limites min/max
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Vérifie si une position est gagnante ou perdante                 |
//+------------------------------------------------------------------+
bool IsWinningPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
   {
      Print("Erreur: Impossible de sélectionner la position ", ticket);
      return false;
   }
   
   return (PositionGetDouble(POSITION_PROFIT) > 0);
}

//+------------------------------------------------------------------+
//| Calcule le drawdown actuel du compte                             |
//+------------------------------------------------------------------+
double CalculateDrawdownPercent()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance <= 0) return 0.0;
   
   return ((balance - equity) / balance) * 100.0;
}

//+------------------------------------------------------------------+
//| Vérifie si le drawdown maximal autorisé est atteint              |
//+------------------------------------------------------------------+
bool IsMaxDrawdownReached(double maxDrawdownPercent)
{
   if(maxDrawdownPercent <= 0) return false;
   
   double currentDrawdown = CalculateDrawdownPercent();
   return (currentDrawdown >= maxDrawdownPercent);
}
