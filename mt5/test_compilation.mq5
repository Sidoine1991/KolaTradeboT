//+------------------------------------------------------------------+
//| Script de test pour vérifier la compilation des corrections      |
//+------------------------------------------------------------------+
#property script_show_inputs

// Structure pour stocker les handles d'indicateurs par symbole
struct SymbolIndicatorHandles
{
    int atr_handle;
    int ma20_handle;
    int ma50_handle;
    int short_atr_handle;
    int long_atr_handle;
    
    // Constructeur pour initialiser les handles
    SymbolIndicatorHandles()
    {
        atr_handle = INVALID_HANDLE;
        ma20_handle = INVALID_HANDLE;
        ma50_handle = INVALID_HANDLE;
        short_atr_handle = INVALID_HANDLE;
        long_atr_handle = INVALID_HANDLE;
    }
    
    // Méthode pour nettoyer tous les handles
    void ReleaseAll()
    {
        if(atr_handle != INVALID_HANDLE) { IndicatorRelease(atr_handle); atr_handle = INVALID_HANDLE; }
        if(ma20_handle != INVALID_HANDLE) { IndicatorRelease(ma20_handle); ma20_handle = INVALID_HANDLE; }
        if(ma50_handle != INVALID_HANDLE) { IndicatorRelease(ma50_handle); ma50_handle = INVALID_HANDLE; }
        if(short_atr_handle != INVALID_HANDLE) { IndicatorRelease(short_atr_handle); short_atr_handle = INVALID_HANDLE; }
        if(long_atr_handle != INVALID_HANDLE) { IndicatorRelease(long_atr_handle); long_atr_handle = INVALID_HANDLE; }
    }
};

// Tableau des handles par symbole
SymbolIndicatorHandles g_symbolHandles[];

//+------------------------------------------------------------------+
//| Obtient l'index des handles d'indicateurs pour un symbole spécifique |
//+------------------------------------------------------------------+
int GetSymbolHandleIndex(string symbol)
{
   // Rechercher le symbole dans le tableau
   for(int i = 0; i < ArraySize(g_symbolHandles); i++)
   {
      // Vérifier si les handles sont valides pour ce symbole
      if(g_symbolHandles[i].atr_handle != INVALID_HANDLE)
      {
         double testValue[];
         if(CopyBuffer(g_symbolHandles[i].atr_handle, 0, 0, 1, testValue) > 0)
         {
            // Handles valides, retourner l'index
            return i;
         }
      }
   }
   
   // Si non trouvé, créer un nouveau jeu de handles pour ce symbole
   int size = ArraySize(g_symbolHandles);
   ArrayResize(g_symbolHandles, size + 1);
   
   // Initialiser les handles pour le symbole
   g_symbolHandles[size].atr_handle = iATR(symbol, PERIOD_M1, 14);
   g_symbolHandles[size].ma20_handle = iMA(symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
   g_symbolHandles[size].ma50_handle = iMA(symbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_symbolHandles[size].short_atr_handle = iATR(symbol, PERIOD_M1, 5);
   g_symbolHandles[size].long_atr_handle = iATR(symbol, PERIOD_M1, 50);
   
   Print("Handles d'indicateurs créés pour ", symbol);
   return size;
}

//+------------------------------------------------------------------+
//| Test des fonctions corrigées                                      |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("Test de compilation des corrections");
   
   // Test de GetSymbolHandleIndex
   int index = GetSymbolHandleIndex(_Symbol);
   Print("Index obtenu: ", index);
   
   // Test d'accès aux handles
   if(index >= 0)
   {
      Print("ATR handle: ", g_symbolHandles[index].atr_handle);
      Print("MA20 handle: ", g_symbolHandles[index].ma20_handle);
      Print("MA50 handle: ", g_symbolHandles[index].ma50_handle);
   }
   
   Print("Test terminé avec succès");
}
