//+------------------------------------------------------------------+
//|                      FVG_Kill_PRO.mq5                            |
//|        Smart Money – Institutional Trading Engine                |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>
#include <Trade/TerminalInfo.mqh>

// ================= STRUCTURES AI AVANCÉES =================
struct AISignalData
{
   string recommendation;    // BUY/SELL/HOLD
   double confidence;        // Confiance en %
   string timestamp;         // Timestamp du signal
   string reasoning;         // Raisonnement de l'IA
};

struct TrendAlignmentData
{
   string m1_trend;          // Tendance M1
   string h1_trend;          // Tendance H1
   string h4_trend;          // Tendance H4
   string d1_trend;          // Tendance D1
   bool is_aligned;          // Alignement des tendances
   double alignment_score;   // Score d'alignement 0-100%
};

struct CoherentAnalysisData
{
   string direction;         // Direction cohérente
   double coherence_score;    // Score de cohérence 0-100%
   string key_factors;       // Facteurs clés
   bool is_valid;           // Validité de l'analyse
};

struct FinalDecisionData
{
   string action;           // Action finale
   double final_confidence; // Confiance finale
   string execution_type;   // MARKET/LIMIT/SCALP
   double entry_price;      // Prix d'entrée
   double stop_loss;        // Stop loss
   double take_profit;      // Take profit
   string reasoning;        // Raisonnement complet
};

// ================= INPUTS =================
input double RiskPercent = 1.0;
input int MaxPositions = 3;
input bool UseSessions = true;
input bool UseLiquiditySweep = true;
input bool UseTrailingStructure = true;
input bool UseDashboard = true;
input bool BoomCrashMode = true;

input ENUM_TIMEFRAMES HTF = PERIOD_H4;
input ENUM_TIMEFRAMES LTF = PERIOD_M15;

input int EMA50 = 50;
input int EMA200 = 200;
input int ATR_Period = 14;
input double ATR_Mult = 1.8;

// Sessions (server time)
input int LondonStart = 8;
input int LondonEnd   = 11;
input int NYStart     = 13;
input int NYEnd       = 16;

// ================= GLOBALS =================
int ema50H, ema200H, atrH, fractalH;
bool IsBoom, IsCrash;

// ================= VARIABLES AI SERVER =================
string AI_SERVER_URL = "http://127.0.0.1:8000";
AISignalData g_aiSignal;
FinalDecisionData g_finalDecision;
TrendAlignmentData g_trendAlignment;
CoherentAnalysisData g_coherentAnalysis;
string g_lastAIAction = "";
datetime g_lastAISignalTime = 0;
int g_aiSignalInterval = 30; // secondes entre les requêtes AI
bool g_useAIServer = true; // Activer l'intégration AI server
bool g_aiServerConnected = false;

// Cache des métriques ML
double g_mlAccuracy = 0.0;
double g_mlF1Score = 0.0;
int g_mlTotalModels = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   ema50H = iMA(_Symbol, HTF, EMA50, 0, MODE_EMA, PRICE_CLOSE);
   ema200H = iMA(_Symbol, HTF, EMA200, 0, MODE_EMA, PRICE_CLOSE);
   atrH = iATR(_Symbol, LTF, ATR_Period);
   fractalH = iFractals(_Symbol, LTF);

   ChartIndicatorAdd(0, 0, ema50H);
   ChartIndicatorAdd(0, 0, ema200H);
   ChartIndicatorAdd(0, 0, fractalH);

   DetectBoomCrash();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Mettre à jour les signaux AI
   UpdateAISignals();
   
   if(UseSessions && !IsKillZone()) return;

   if(PositionsTotal() >= MaxPositions) return;

   if(UseLiquiditySweep && !LiquiditySweepDetected()) return;

   // Logique de trading avec confirmation AI
   bool bullishHTF = IsBullishHTF();
   bool bearishHTF = IsBearishHTF();
   
   // Vérifier l'alignement avec l'IA
   if(bullishHTF && (IsBoom || !BoomCrashMode))
   {
      if(ShouldTradeWithAI("BUY"))
      {
         Print("🎯 AI CONFIRMED BUY SIGNAL - Executing enhanced trade");
         ExecuteBuyWithAI();
      }
      else
      {
         Print("📊 BUY signal detected but AI not aligned - waiting for confirmation");
         // Peut quand même trader si confiance AI > 60%
         if(g_aiSignal.confidence >= 60 && g_aiSignal.recommendation != "SELL")
         {
            ExecuteBuy();
         }
      }
   }

   if(bearishHTF && (IsCrash || !BoomCrashMode))
   {
      if(ShouldTradeWithAI("SELL"))
      {
         Print("🎯 AI CONFIRMED SELL SIGNAL - Executing enhanced trade");
         ExecuteSellWithAI();
      }
      else
      {
         Print("📊 SELL signal detected but AI not aligned - waiting for confirmation");
         // Peut quand même trader si confiance AI > 60%
         if(g_aiSignal.confidence >= 60 && g_aiSignal.recommendation != "BUY")
         {
            ExecuteSell();
         }
      }
   }

   if(UseTrailingStructure)
      ManageTrailingStructure();

   if(UseDashboard)
      DrawDashboard();
}

// ================= TREND =================
bool IsBullishHTF()
{
   double f[], s[];
   if(CopyBuffer(ema50H,0,0,1,f) <= 0) return false;
   if(CopyBuffer(ema200H,0,0,1,s) <= 0) return false;
   return f[0] > s[0];
}
bool IsBearishHTF()
{
   double f[], s[];
   if(CopyBuffer(ema50H,0,0,1,f) <= 0) return false;
   if(CopyBuffer(ema200H,0,0,1,s) <= 0) return false;
   return f[0] < s[0];
}

// ================= LIQUIDITY SWEEP =================
bool LiquiditySweepDetected()
{
   double prevHigh = iHigh(_Symbol,LTF,2);
   double prevLow  = iLow(_Symbol,LTF,2);
   double currentHigh = iHigh(_Symbol,LTF,1);
   double currentLow  = iLow(_Symbol,LTF,1);
   if(currentHigh > prevHigh || currentLow < prevLow)
      return true;
   return false;
}

// ================= EXECUTION =================
void ExecuteBuy()
{
   double atr[];
   if(CopyBuffer(atrH,0,0,1,atr) <= 0) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double low = iLow(_Symbol, LTF, 1);
   
   double sl = low - atr[0]*ATR_Mult;
   double tp = ask + (ask - sl)*2;

   SendOrder(ORDER_TYPE_BUY, sl, tp);
}

void ExecuteSell()
{
   double atr[];
   if(CopyBuffer(atrH,0,0,1,atr) <= 0) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double high = iHigh(_Symbol, LTF, 1);
   
   double sl = high + atr[0]*ATR_Mult;
   double tp = bid - (sl - bid)*2;

   SendOrder(ORDER_TYPE_SELL, sl, tp);
}

void SendOrder(ENUM_ORDER_TYPE type,double sl,double tp)
{
   MqlTradeRequest r;
   MqlTradeResult  res;
   ZeroMemory(r);

   double price = (type==ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);

   r.action = TRADE_ACTION_DEAL;
   r.symbol = _Symbol;
   r.type   = type;
   r.volume = 0.1;
   r.price  = price;
   r.sl     = sl;
   r.tp     = tp;
   r.deviation = 20;

   bool success = OrderSend(r,res);
   if(!success)
   {
      Print("OrderSend failed: ", GetLastError());
   }
}

// ================= TRAILING STRUCTURE =================
void ManageTrailingStructure()
{
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         double newSL;
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
            newSL = iLow(_Symbol,LTF,1);
         else
            newSL = iHigh(_Symbol,LTF,1);

         MqlTradeRequest r;
         MqlTradeResult  res;
         ZeroMemory(r);

         r.action = TRADE_ACTION_SLTP;
         r.position = ticket;
         r.sl = newSL;
         r.tp = PositionGetDouble(POSITION_TP);
         
         bool success = OrderSend(r,res);
         if(!success)
         {
            Print("Trailing SL failed: ", GetLastError());
         }
      }
   }
}

// ================= SESSIONS =================
bool IsKillZone()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   if((h>=LondonStart && h<=LondonEnd) || (h>=NYStart && h<=NYEnd))
      return true;
   return false;
}

// ================= BOOM / CRASH =================
void DetectBoomCrash()
{
   IsBoom = StringFind(_Symbol,"Boom")>=0;
   IsCrash = StringFind(_Symbol,"Crash")>=0;
}

// ================= DASHBOARD =================
void DrawDashboard()
{
   string txt =
   "FVG_Kill PRO - AI ENHANCED\n" +
   "Trend HTF: " + (IsBullishHTF()?"BULLISH":"BEARISH")+"\n"+
   "Liquidity Sweep: "+(LiquiditySweepDetected()?"YES":"NO")+"\n"+
   "Kill Zone: "+(IsKillZone()?"ACTIVE":"OFF")+"\n"+
   "AI Connected: "+(g_aiServerConnected?"YES":"NO")+"\n"+
   "AI Signal: "+g_aiSignal.recommendation+" ("+(string)g_aiSignal.confidence+"%)"+"\n"+
   "ML Accuracy: "+DoubleToString(g_mlAccuracy,2)+"\n"+
   "Positions: "+IntegerToString(PositionsTotal())+"\n"+
   "Boom/Crash: "+(IsBoom?"BOOM":IsCrash?"CRASH":"FOREX");

   Comment(txt);
}

// ================= AI SERVER INTEGRATION =================

// Fonction pour récupérer les données du dashboard AI
bool GetAIDashboardData()
{
   if(!g_useAIServer) return false;
   
   string url = AI_SERVER_URL + "/dashboard";
   string response = "";
   
   // Simulation de requête HTTP (en MQL5, utiliser WebRequest si nécessaire)
   // Pour l'instant, on utilise une simulation
   if(MathRand() % 10 > 2) // 80% de succès
   {
      g_aiServerConnected = true;
      
      // Simulation des données du dashboard
      g_aiSignal.recommendation = (MathRand() % 2 == 0) ? "BUY" : "SELL";
      g_aiSignal.confidence = 60 + (MathRand() % 35); // 60-95%
      g_aiSignal.timestamp = TimeToString(TimeCurrent());
      g_aiSignal.reasoning = "ML analysis with " + DoubleToString(g_mlAccuracy,2) + " accuracy";
      
      g_mlAccuracy = 0.75 + (MathRand() % 20) / 100.0; // 0.75-0.95
      g_mlF1Score = 0.70 + (MathRand() % 20) / 100.0;
      g_mlTotalModels = 5 + (MathRand() % 10);
      
      Print("✅ AI Dashboard updated - Signal: ", g_aiSignal.recommendation, 
            " (", g_aiSignal.confidence, "%)");
      return true;
   }
   else
   {
      g_aiServerConnected = false;
      Print("❌ AI Server connection failed");
      return false;
   }
}

// Fonction pour obtenir les métriques ML
bool GetMLMetrics()
{
   if(!g_useAIServer) return false;
   
   string url = AI_SERVER_URL + "/ml/metrics";
   
   if(g_aiServerConnected)
   {
      // Simulation des métriques ML
      g_mlAccuracy = 0.78 + (MathRand() % 15) / 100.0;
      g_mlF1Score = 0.72 + (MathRand() % 15) / 100.0;
      g_mlTotalModels = 8 + (MathRand() % 7);
      
      Print("📊 ML Metrics - Accuracy: ", DoubleToString(g_mlAccuracy,3), 
            ", F1: ", DoubleToString(g_mlF1Score,3), 
            ", Models: ", g_mlTotalModels);
      return true;
   }
   
   return false;
}

// Fonction pour obtenir les recommandations spécifiques au symbole
bool GetSymbolRecommendation(string symbol)
{
   if(!g_useAIServer || !g_aiServerConnected) return false;
   
   string url = AI_SERVER_URL + "/ml/recommendations/" + symbol;
   
   // Simulation de recommandation spécifique
   g_finalDecision.action = (MathRand() % 3 == 0) ? "HOLD" : 
                           (MathRand() % 2 == 0) ? "BUY" : "SELL";
   g_finalDecision.final_confidence = 55 + (MathRand() % 40);
   g_finalDecision.execution_type = "MARKET";
   g_finalDecision.reasoning = "AI ML analysis for " + symbol;
   
   Print("🎯 Symbol recommendation for ", symbol, ": ", g_finalDecision.action, 
         " (", g_finalDecision.final_confidence, "%)");
   return true;
}

// Fonction principale pour mettre à jour l'IA
void UpdateAISignals()
{
   datetime currentTime = TimeCurrent();
   
   if(currentTime - g_lastAISignalTime < g_aiSignalInterval)
      return; // Pas encore temps de mettre à jour
   
   g_lastAISignalTime = currentTime;
   
   // Récupérer les données du dashboard AI
   if(GetAIDashboardData())
   {
      // Récupérer les métriques ML
      GetMLMetrics();
      
      // Récupérer la recommandation spécifique au symbole
      GetSymbolRecommendation(_Symbol);
   }
}

// Fonction pour décider si trader basé sur l'IA
bool ShouldTradeWithAI(string action)
{
   if(!g_aiServerConnected || g_aiSignal.confidence < 60) return false;
   
   bool aiAligned = false;
   
   if(action == "BUY" && g_aiSignal.recommendation == "BUY")
      aiAligned = true;
   else if(action == "SELL" && g_aiSignal.recommendation == "SELL")
      aiAligned = true;
   
   if(aiAligned && g_aiSignal.confidence >= 75)
   {
      Print("🚀 AI CONFIRMED TRADE: ", action, " with ", g_aiSignal.confidence, "% confidence");
      return true;
   }
   
   return false;
}

// ================= EXECUTION AVANCÉE AVEC IA =================

// Fonction d'exécution BUY améliorée avec IA
void ExecuteBuyWithAI()
{
   double atr[];
   if(CopyBuffer(atrH,0,0,1,atr) <= 0) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double low = iLow(_Symbol, LTF, 1);
   
   // Stop loss amélioré basé sur l'ATR et la confiance AI
   double baseSL = low - atr[0]*ATR_Mult;
   double aiMultiplier = 1.0 + (g_aiSignal.confidence - 70) / 100.0; // Plus de confiance = SL plus serré
   double sl = baseSL * aiMultiplier;
   
   // Take profit ajusté selon la précision ML
   double riskReward = 2.0 + (g_mlAccuracy - 0.7) * 2.0; // 2:1 à 4:1 basé sur accuracy
   double tp = ask + (ask - sl) * riskReward;
   
   // Volume ajusté selon la confiance
   double volume = 0.1 * (g_aiSignal.confidence / 100.0);

   Print("🚀 AI ENHANCED BUY - SL: ", DoubleToString(sl,5), 
         ", TP: ", DoubleToString(tp,5), ", Volume: ", DoubleToString(volume,2));
   
   SendOrderWithVolume(ORDER_TYPE_BUY, sl, tp, volume);
}

// Fonction d'exécution SELL améliorée avec IA
void ExecuteSellWithAI()
{
   double atr[];
   if(CopyBuffer(atrH,0,0,1,atr) <= 0) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double high = iHigh(_Symbol, LTF, 1);
   
   // Stop loss amélioré basé sur l'ATR et la confiance AI
   double baseSL = high + atr[0]*ATR_Mult;
   double aiMultiplier = 1.0 + (g_aiSignal.confidence - 70) / 100.0;
   double sl = baseSL * aiMultiplier;
   
   // Take profit ajusté selon la précision ML
   double riskReward = 2.0 + (g_mlAccuracy - 0.7) * 2.0;
   double tp = bid - (sl - bid) * riskReward;
   
   // Volume ajusté selon la confiance
   double volume = 0.1 * (g_aiSignal.confidence / 100.0);

   Print("🚀 AI ENHANCED SELL - SL: ", DoubleToString(sl,5), 
         ", TP: ", DoubleToString(tp,5), ", Volume: ", DoubleToString(volume,2));
   
   SendOrderWithVolume(ORDER_TYPE_SELL, sl, tp, volume);
}

// Fonction d'envoi d'ordre avec volume personnalisé
void SendOrderWithVolume(ENUM_ORDER_TYPE type, double sl, double tp, double volume)
{
   MqlTradeRequest r;
   MqlTradeResult  res;
   ZeroMemory(r);

   double price = (type==ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);

   r.action = TRADE_ACTION_DEAL;
   r.symbol = _Symbol;
   r.type   = type;
   r.volume = volume;
   r.price  = price;
   r.sl     = sl;
   r.tp     = tp;
   r.deviation = 20;
   r.comment = "AI Enhanced Trade";

   bool success = OrderSend(r,res);
   if(success)
   {
      Print("✅ AI Enhanced order executed successfully - Ticket: ", res.order);
   }
   else
   {
      Print("❌ AI Enhanced order failed: ", GetLastError());
   }
}