//+------------------------------------------------------------------+
//|                                                    OptimUtils.mqh |
//|                                  Copyright 2024, Your Company Name |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

#include <Generic\HashMap.mqh>

// Niveau de débogage : 0=aucun, 1=erreurs, 2=avertissements, 3=debug
#ifndef DEBUG_LEVEL
   #define DEBUG_LEVEL 1
#endif

// Structure pour le cache des indicateurs
template<typename T>
struct IndicatorCache
{
   T            lastValue;
   datetime     lastUpdate;
   double       buffer[];
   
   void Update(const T &value) {
      lastValue = value;
      lastUpdate = TimeCurrent();
   }
};

// Gestion des logs optimisée
void DebugPrint(int level, const string message)
{
   #ifdef __MQL5_DEBUG__
   if(level <= DEBUG_LEVEL)
   {
      static string levelStr[] = {"", "[ERROR]", "[WARN] ", "[DEBUG]"};
      Print(TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), " ", 
            levelStr[level > 0 && level < 4 ? level : 0], " ", 
            message);
   }
   #endif
}

// Vérification des conditions de trading
bool IsTradingAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      DebugPrint(1, "Le trading n'est pas autorisé par le terminal");
      return false;
   }
   
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      DebugPrint(1, "Le trading automatique est désactivé");
      return false;
   }
   
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      DebugPrint(1, "Pas de connexion au serveur de trading");
      return false;
   }
   
   if(IsTradeContextBusy())
   {
      static int lastAlert = 0;
      if(TimeCurrent() - lastAlert > 60) // Alerte max toutes les 60 secondes
      {
         DebugPrint(2, "Contexte de trading occupé");
         lastAlert = TimeCurrent();
      }
      return false;
   }
   
   return true;
}

// Vérification des barres
bool IsNewBar(ENUM_TIMEFRAMES timeframe, datetime &lastBarTime)
{
   datetime currentBarTime = iTime(_Symbol, timeframe, 0);
   if(currentBarTime > lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

// Classe pour la gestion des performances
class CPerformanceTimer
{
private:
   ulong m_startTime;
   string m_name;
   
public:
   CPerformanceTimer(string name) : m_name(name) 
   { 
      m_startTime = GetMicrosecondCount(); 
   }
   
   ~CPerformanceTimer()
   {
      ulong duration = GetMicrosecondCount() - m_startTime;
      if(duration > 1000) // Afficher uniquement si > 1ms
         DebugPrint(3, StringFormat("Timer %s: %d µs", m_name, duration));
   }
};
