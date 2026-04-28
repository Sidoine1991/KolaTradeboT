// Test de compilation pour vérifier les corrections de variables locales
// Fichier minimal pour tester la syntaxe

// Variables globales pour tester
CPositionInfo posInfo;
double atrM1 = 0.0;
double atrM5 = 0.0;

// Fonctions de test
double GetATR(ENUM_TIMEFRAMES period, int ma_period)
{
   return iATR(_Symbol, period, ma_period);
}

bool IsBoomCrashVolatilityAcceptable()
{
   double localAtrM1 = GetATR(PERIOD_M1, 14);
   double localAtrM5 = GetATR(PERIOD_M5, 14);
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atrM1Points = localAtrM1 / point;
   double atrM5Points = localAtrM5 / point;
   
   double maxBoomCrashVolatility = 5000.0;
   if(atrM5Points > maxBoomCrashVolatility)
   {
      return false;
   }
   
   double minBoomCrashVolatility = 50.0;
   if(atrM5Points < minBoomCrashVolatility)
   {
      return false;
   }
   
   return true;
}

void TestEarlyExit()
{
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   CPositionInfo localPosInfo;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!localPosInfo.SelectByIndex(i)) continue;
      
      string symbol = localPosInfo.Symbol();
      ulong ticket = localPosInfo.Ticket();
      double openPrice = localPosInfo.PriceOpen();
      double currentSL = localPosInfo.StopLoss();
      double currentTP = localPosInfo.TakeProfit();
      ENUM_POSITION_TYPE posType = localPosInfo.PositionType();
      datetime openTime = (datetime)localPosInfo.Time();
      
      // Logique de test
      if(posType == POSITION_TYPE_BUY)
      {
         // Test pour les positions BUY
      }
      else
      {
         // Test pour les positions SELL
      }
   }
}

int OnInit()
{
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   TestEarlyExit();
}

void OnDeinit()
{
}
