//+------------------------------------------------------------------+
//| Test compilation                                                |
//+------------------------------------------------------------------+
#property strict

// Inclure le fichier principal pour tester
#include "F_INX_scalper_double.mq5"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("Test compilation - Nouvelles fonctions intégrées:");
    Print("1. WaitForReversalConfirmation() - Attend confirmation retournement");
    Print("2. DetectNearbySupportResistance() - Détecte niveaux S/R");
    Print("3. TryEntryWithReversalConfirmation() - Entrée avec confirmation");
    Print("4. UseReversalConfirmation - Variable de configuration activée");
    
    // Tester la détection de niveaux
    double support = DetectNearbySupportResistance(ORDER_TYPE_BUY);
    double resistance = DetectNearbySupportResistance(ORDER_TYPE_SELL);
    
    Print("Support détecté: ", DoubleToString(support, 5));
    Print("Résistance détectée: ", DoubleToString(resistance, 5));
    
    Print("Test compilation terminé avec succès!");
}
