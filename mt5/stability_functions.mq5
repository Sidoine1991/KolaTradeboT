//+------------------------------------------------------------------+
//|                                         stability_functions.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00"
#property strict

// Inclure les fichiers nécessaires
#include <Trade/TerminalInfo.mqh>
#include <Trade/Trade.mqh>

// Déclaration des variables globales (définies dans le fichier principal)
extern datetime g_lastHeartbeat;
extern int g_reconnectAttempts;
extern const int MAX_RECONNECT_ATTEMPTS;
extern bool g_isStable;

// Déclaration des fonctions appelées (définies dans le fichier principal)
void InitializeIndicators();
void CleanupDashboardLabels();
void UpdateAdvancedDashboard();

// Déclarations des fonctions globales utilisées
datetime TimeCurrent();
void Sleep(int ms);
void Print(string message);
void ExpertRemove();
int TerminalInfoInteger(int property_id);

//+------------------------------------------------------------------+
//| Vérifier la stabilité du robot                                   |
//+------------------------------------------------------------------+
void CheckRobotStability()
{
   datetime currentTime = TimeCurrent();
   
   // Heartbeat toutes les 30 secondes
   if(currentTime - g_lastHeartbeat > 30)
   {
      g_lastHeartbeat = currentTime;
      
      // Vérifier si le robot est toujours attaché
      if(TerminalInfoInteger(TERMINAL_CONNECTED))
      {
         Print("💓 HEARTBEAT: Robot stable - ", TimeToString(currentTime));
         g_reconnectAttempts = 0;
         g_isStable = true;
      }
      else
      {
         Print("⚠️ CONNEXION PERDUE: Tentative de reconnexion...");
         g_isStable = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Système de récupération automatique                              |
//+------------------------------------------------------------------+
void AutoRecoverySystem()
{
   if(!g_isStable && g_reconnectAttempts < MAX_RECONNECT_ATTEMPTS)
   {
      g_reconnectAttempts++;
      
      Print("🔄 TENTATIVE DE RÉCUPÉRATION #", g_reconnectAttempts, "/", MAX_RECONNECT_ATTEMPTS);
      
      // Pause de 5 secondes entre tentatives
      Sleep(5000);
      
      // Réinitialiser les indicateurs
      InitializeIndicators();
      
      // Nettoyer et redessiner le dashboard
      CleanupDashboardLabels();
      UpdateAdvancedDashboard();
      
      // Vérifier si la récupération a réussi
      if(TerminalInfoInteger(TERMINAL_CONNECTED))
      {
         Print("✅ RÉCUPÉRATION RÉUSSIE: Robot reconnecté !");
         g_isStable = true;
         g_reconnectAttempts = 0;
      }
   }
   else if(g_reconnectAttempts >= MAX_RECONNECT_ATTEMPTS)
   {
      Print("❌ ÉCHEC DE RÉCUPÉRATION: Arrêt du robot pour éviter les dommages");
      ExpertRemove(); // Détacher proprement
   }
}
//+------------------------------------------------------------------+
