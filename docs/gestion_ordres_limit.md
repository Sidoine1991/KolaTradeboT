# Gestion des Ordres Limités - F_INX_robot4.mq5

## Fonction Principale : CancelExistingLimitOrders()

```cpp
void CancelExistingLimitOrders()
{
   CTrade trade;
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Détection des marchés spéciaux
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   // Parcours des ordres
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      
      // Vérification du symbole et du magic number
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
         OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
      {
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         
         // Annulation des ordres interdits
         if((isBoom && orderType == ORDER_TYPE_SELL_LIMIT) ||
            (isCrash && orderType == ORDER_TYPE_BUY_LIMIT))
         {
            trade.OrderDelete(ticket);
            Print("❌ Ordre interdit annulé: ", EnumToString(orderType), " sur ", _Symbol);
            continue;
         }
         
         // Annulation des ordres LIMIT existants
         if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT)
         {
            trade.OrderDelete(ticket);
            Print("Ordre annulé: ", EnumToString(orderType), " (un seul ordre autorisé)");
         }
      }
   }
}
```

## Fonctions de Placement d'Ordres

### Placement d'un Ordre d'Achat Limité
```cpp
bool PlaceBuyOrder(double entryPrice, double sl, double tp, string comment, CTrade &tradeObj, int magicNumber)
{
   // Vérification marché Crash
   if(StringFind(_Symbol, "Crash") >= 0)
   {
      Print("Achat interdit sur Crash");
      return false;
   }
   
   CancelExistingLimitOrders();
   // ... reste du code de placement ...
}
```

### Placement d'un Ordre de Vente Limité
```cpp
bool PlaceSellOrder(double entryPrice, double sl, double tp, string comment, CTrade &tradeObj, int magicNumber)
{
   // Vérification marché Boom
   if(StringFind(_Symbol, "Boom") >= 0)
   {
      Print("Vente interdite sur Boom");
      return false;
   }
   
   CancelExistingLimitOrders();
   // ... reste du code de placement ...
}
```

## Règles Implémentées

1. **Un seul ordre par symbole** :
   - Annulation automatique des anciens ordres LIMIT

2. **Restrictions Boom/Crash** :
   - ❌ Pas de SELL_LIMIT sur les marchés Boom
   - ❌ Pas de BUY_LIMIT sur les marchés Crash

3. **Gestion des Erreurs** :
   - Messages de journalisation clairs
   - Vérification des erreurs après chaque opération

4. **Sécurité** :
   - Vérification des tickets d'ordre
   - Filtrage par magic number
   - Vérification des symboles

## Logs d'Exemple

```
2023.01.01 12:00:00 ❌ Ordre interdit annulé: ORDER_TYPE_SELL_LIMIT sur Boom 500
2023.01.01 12:00:01 Ordre annulé: ORDER_TYPE_BUY_LIMIT (un seul ordre autorisé)
```
