//+------------------------------------------------------------------+
//| PROFESSIONAL VERDICT FALLBACK SYSTEM                             |
//| Fallback validation when external signals fail                   |
//+------------------------------------------------------------------+

#ifndef GOM_FALLBACK_MQH
#define GOM_FALLBACK_MQH

struct ProfessionalSignalHistory
{
   datetime   timestamp;
   string     symbol;
   double     ourScore;
   string     ourVerdict;
   double     actualPnL;
   int        tradeId;
   bool       wasSuccessful;
};

class ProfessionalFallbackSystem
{
private:
   ProfessionalSignalHistory m_tradingHistory[100];
   int m_historyCount = 0;
   double m_historicalAccuracy = 0.0;
   bool m_useFallbackMode = false;
   
public:
   void Initialize()
   {
      Print("[FALLBACK] Professional fallback system initialized");
      m_useFallbackMode = false;
   }
   
   void RecordTradeOutcome(ProfessionalSignalHistory trade)
   {
      if(m_historyCount >= 100) ShiftHistory();
      m_tradingHistory[m_historyCount++] = trade;
      
      // Update accuracy metrics
      CalculateHistoricalAccuracy();
      
      // If fallback needed, adapt our threshold
      if(m_historicalAccuracy < 0.60)  // Below 60% accuracy
      {
         m_useFallbackMode = true;
         Print("[FALLBACK] Activating fallback mode - accuracy ", m_historicalAccuracy);
      }
   }
   
   double AdjustScoreBasedOnFallback(double ourScore, const string symbol, datetime whenSignalGiven)
   {
      if(!m_useFallbackMode) return ourScore;
      
      // Get similar historical signals
      double similarScoreAdjustment = GetSimilarSignalAdjustment(ourScore, symbol, whenSignalGiven);
      
      // Apply conservative penalty
      double adjustedScore = ourScore * similarScoreAdjustment;
      
      // With high similarity but failure, be more conservative
      if(similarScoreAdjustment < 0.80 && adjustedScore > 65.0)
      {
         adjustedScore = MathMin(adjustedScore, 75.0);  // Cap high scores
         Print("[FALLBACK] CONservative adjustment for signal history failure");
      }
      
      return adjustedScore;
   }
   
   double CalculateHistoricalAccuracy()
   {
      if(m_historyCount == 0) return 0.0;
      
      double successfulTrades = 0.0;
      for(int i = 0; i < m_historyCount; i++)
      {
         if(m_tradingHistory[i].wasSuccessful && m_tradingHistory[i].actualPnL > 20.0)
            successfulTrades++;
      }
      
      double accuracy = successfulTrades / (double)m_historyCount;
      m_historicalAccuracy = accuracy;
      
      if(accuracy < 0.50)
      {
         Print("[FALLBACK] CRITICAL: Historical accuracy below 50%:", accuracy);
         // More aggressive fallback protocol
         m_useFallbackMode = true;
      }
      
      return accuracy;
   }
   
   double GetSimilarSignalAdjustment(double ourScore, const string symbol, datetime signalTime)
   {
      // Look for similar historical signals
      double similarScoreSum = 0.0;
      int similarCount = 0;
      
      for(int i = 0; i < m_historyCount; i++)
      {
         if(m_tradingHistory[i].symbol == symbol)
         {
            double timeDiff = fabs((double)(signalTime - m_tradingHistory[i].timestamp)) / 86400.0; // days
            if(timeDiff <= 3.0) // Same time period (3 days)
            {
               double similarity = 1.0 - (MathMin(timeDiff, 3.0) / 3.0); // More recent = more similar
               double adjustedOutcome = MathMin(m_tradingHistory[i].actualPnL / 100.0, 1.0); // Normalize profit
               
               similarScoreSum += adjustedOutcome * similarity;
               similarCount++;
            }
         }
      }
      
      if(similarCount == 0) return 1.0; // No similar history, no adjustment
      
      double avgOutcome = similarScoreSum / (double)similarCount;
      
      // Map outcome to adjustment factor
      if(avgOutcome >= 0.6) return 0.85;   // Historically profitable = conservative
      else if(avgOutcome >= 0.4) return 0.90; // Moderately profitable = slightly conservative
      else if(avgOutcome >= 0.2) return 0.95; // Slightly profitable = minor conservative
      else if(avgOutcome >= 0.0) return 1.0;  // Break-even = normal
      else if(avgOutcome >= -0.2) return 1.05; // Minor losses = slight aggressive
      else return 1.15;                     // Major losses = aggressively conservative
   }
   
   void ShiftHistory()
   {
      for(int i = 0; i < 99; i++)
         m_tradingHistory[i] = m_tradingHistory[i+1];
      m_historyCount = 99;
   }
};

ProfessionalFallbackSystem g_fallbackSystem;

ProfessionalSignalHistory ConvertToHistoryFormat(ProfessionalSOMSignal &profSig, const string symbol, int tradeId, double pnl)
{
   ProfessionalSignalHistory hist;
   ZeroMemory(hist);
   
   hist.timestamp = TimeCurrent();
   hist.symbol = symbol;
   hist.ourScore = profSig.customScore;
   hist.ourVerdict = profSig.verdict;
   hist.actualPnL = pnl;
   hist.tradeId = tradeId;
   hist.wasSuccessful = (pnl > 20.0); // >$20 profit considered successful
   
   return hist;
}

void RecordProfessionalTradeOutcome(ProfessionalSOMSignal &profSig, const string symbol, int tradeId, double pnl)
{
   ProfessionalSignalHistory hist = ConvertToHistoryFormat(profSig, symbol, tradeId, pnl);
   g_fallbackSystem.RecordTradeOutcome(hist);
}

void ApplyFallbackScoreAdjustment(ProfessionalSOMSignal &profSig, const string symbol)
{
   if(!g_fallbackSystem.m_useFallbackMode) return;
   
   // Adjust based on historical performance
   double adjustment = g_fallbackSystem.AdjustScoreBasedOnFallback(profSig.customScore, symbol, TimeCurrent());
   
   profSig.customScore = adjustment;
   
   // Update risk based on historical performance
   if(adjustment < 60.0)  // Poor historical performance
      profSig.riskScore = MathMin(profSig.riskScore * 1.2, 0.30);
   
   Print("[FALLBACK] Applied score adjustment: ", profSig.customScore);
}

#endif // GOM_FALLBACK_MQH
