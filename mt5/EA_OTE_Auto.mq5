//+------------------------------------------------------------------+
//|                                                   EA_OTE_Auto.mq5|
//|                         TradBOT - OTE Strategy EA                |
//+------------------------------------------------------------------+
#property strict

input string  InpSymbol          = "";        // Vide = symbole du graphique
input ENUM_TIMEFRAMES InpTF      = PERIOD_CURRENT;
input double  InpMinLot          = 1.0;       // Lot minimum
input double  InpRiskPerTradePct = 1.0;       // Risque % par trade (utilisé ssi > min lot)
input int     InpOTEPivotWindow  = 5;         // Fenêtre pivots
input int     InpSLPips          = 20;        // Stop Loss pips
input int     InpTPPips          = 60;        // Take Profit pips
input int     InpMagic           = 26091;     // Magic Number
input int     InpSlippage        = 10;        // Slippage
input bool    InpOnlyOnePosition = true;      // Empêcher positions multiples sens opposé

int OnInit(){ return(INIT_SUCCEEDED); }
void OnDeinit(const int reason){}

void OnTick()
{
   string sym = (InpSymbol=="" ? _Symbol : InpSymbol);
   ENUM_TIMEFRAMES tf = (InpTF==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTF);

   // Données OHLC
   MqlRates rates[]; ArraySetAsSeries(rates,true);
   if(CopyRates(sym, tf, 0, 500, rates) <= 100) return;

   // Détection OTE sur la fenêtre récente
   int bars = ArraySize(rates);
   int w = MathMax(3, MathMin(11, InpOTEPivotWindow));
   int start = w, end = bars-1-w; if(end<start) return;
   int lastH=-1,lastL=-1;
   for(int i=end;i>=start;i--){ bool isH=true; for(int k=1;k<=w;k++){ if(rates[i].high<=rates[i-k].high || rates[i].high<=rates[i+k].high){ isH=false; break; } } if(isH){ lastH=i; break; } }
   for(int i=end;i>=start;i--){ bool isL=true; for(int k=1;k<=w;k++){ if(rates[i].low >=rates[i-k].low  || rates[i].low >=rates[i+k].low ){ isL=false; break; } } if(isL){ lastL=i; break; } }
   if(lastH<0 || lastL<0) return;

   double swingH=rates[lastH].high, swingL=rates[lastL].low; double rng=swingH-swingL; if(rng<=0) return;
   bool up = (lastH>lastL);
   double fib0 = up ? swingL : swingH;
   double fib1 = up ? swingH : swingL;
   double fib05 = fib0 + 0.5*rng;
   double fib078= fib0 + 0.78*rng;
   double bid=SymbolInfoDouble(sym, SYMBOL_BID); double ask=SymbolInfoDouble(sym, SYMBOL_ASK); double px=(bid+ask)*0.5;
   if(px<=0) return;

   // Zones
   bool buy_ok=false, sell_ok=false;
   if(up)
   {
      double pos=(px - fib0)/rng;
      buy_ok  = (pos>=0.0 && pos<=0.5);
      sell_ok = (pos>=0.78 && pos<=1.0);
   }
   else
   {
      double posD=(fib1 - px)/rng;
      sell_ok = (posD>=0.0 && posD<=0.5);
      buy_ok  = (posD>=0.78 && posD<=1.0);
   }

   // Gestion des positions
   int buys=0,sells=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong ticket=PositionGetTicket(i); if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==sym){ if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) buys++; else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL) sells++; }}
   if(InpOnlyOnePosition && ((buy_ok && buys>0) || (sell_ok && sells>0))) return;

   // Calcul lot (min 1)
   double lot = MathMax(InpMinLot, 1.0);
   // Optionnel: ajuster selon le risque et la taille du SL
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT); int digits=(int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double sl_points = InpSLPips * ( (StringFind(sym,"JPY")>=0 || StringFind(sym,"Index")>=0) ? 100 : 10000 );
   double tp_points = InpTPPips * ( (StringFind(sym,"JPY")>=0 || StringFind(sym,"Index")>=0) ? 100 : 10000 );

   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action = TRADE_ACTION_DEAL; req.symbol=sym; req.type_filling=ORDER_FILLING_IOC; req.deviation=InpSlippage; req.magic=InpMagic; req.volume=lot;

   if(buy_ok)
   {
      req.type=ORDER_TYPE_BUY; req.price=SymbolInfoDouble(sym, SYMBOL_ASK);
      req.sl = req.price - sl_points*pt; req.tp = req.price + tp_points*pt;
      OrderSend(req,res);
   }
   else if(sell_ok)
   {
      req.type=ORDER_TYPE_SELL; req.price=SymbolInfoDouble(sym, SYMBOL_BID);
      req.sl = req.price + sl_points*pt; req.tp = req.price - tp_points*pt;
      OrderSend(req,res);
   }
}


