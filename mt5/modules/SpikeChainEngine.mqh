//| SpikeChainEngine.mqh                                               |
//| Spike Chain Predictor - Moteur de prédiction de chaînes de spikes  |
//| Architecture: 5 états + scoring CHAIN_SCORE /100                 |
//| Intégration: SMC + Chain Engine + Price Action M1 + Risk Engine    |
//+------------------------------------------------------------------+
#property copyright "TradBOT SMC"
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| ENUMS - États du moteur de chaîne                                 |
//+------------------------------------------------------------------+
enum ENUM_CHAIN_STATE
{
   CHAIN_STATE_NORMAL = 0,        // Volatilité normale, pas de structure
   CHAIN_STATE_COMPRESSION = 1,   // Range qui se resserre, diminution amplitude
   CHAIN_STATE_PRE_SPIKE = 2,     // Pression anormale, momentum croissant
   CHAIN_STATE_SPIKE_CONFIRMED = 3, // Vraie impulsion (displacement + break structure)
   CHAIN_STATE_CHAIN = 4,         // Chaîne active (spike 1+ retracement + spike 2+)
   CHAIN_STATE_DECAY = 5          // Chaîne perd de la force
};

//+------------------------------------------------------------------+
//| STRUCT - État du moteur de chaîne                                 |
//+------------------------------------------------------------------+
struct ChainEngineState
{
   ENUM_CHAIN_STATE state;
   datetime stateStartTime;
   int barsInState;
   double chainScore;              // Score 0-100
   int chainDirection;             // +1 BUY, -1 SELL, 0 indéterminé
   int spikeCount;                 // Nombre de spikes dans la chaîne actuelle
   datetime lastSpikeTime;
   double lastSpikeAmplitude;
   double avgSpikeInterval;        // Interval moyen entre spikes (en secondes)
   double avgSpikeAmplitude;       // Amplitude moyenne des spikes
   double lastRetracementPct;      // Dernier retracement en %
   double chainStrength;           // 0-100, force de la chaîne
   bool isValid;
   
   ChainEngineState()
   {
      state = CHAIN_STATE_NORMAL;
      stateStartTime = 0;
      barsInState = 0;
      chainScore = 0;
      chainDirection = 0;
      spikeCount = 0;
      lastSpikeTime = 0;
      lastSpikeAmplitude = 0;
      avgSpikeInterval = 0;
      avgSpikeAmplitude = 0;
      lastRetracementPct = 0;
      chainStrength = 0;
      isValid = false;
   }
};

//+------------------------------------------------------------------+
//| STRUCT - Métriques de compression                                 |
//+------------------------------------------------------------------+
struct CompressionMetrics
{
   bool isCompressing;
   double rangeWidth;              // Largeur du range en points
   double rangeWidthATR;           // Largeur en ATR
   double amplitudeDecline;        // Déclin d'amplitude %
   int smallBarCount;              // Nombre de petites bougies
   double retracementDecline;      // Déclin du retracement %
   double proximityToLevel;       // Proximité niveau important 0-1
   double directionalPressure;    // Pression directionnelle -1 à 1
   double compressionScore;       // Score 0-100
   
   CompressionMetrics()
   {
      isCompressing = false;
      rangeWidth = 0;
      rangeWidthATR = 0;
      amplitudeDecline = 0;
      smallBarCount = 0;
      retracementDecline = 0;
      proximityToLevel = 0;
      directionalPressure = 0;
      compressionScore = 0;
   }
};

//+------------------------------------------------------------------+
//| STRUCT - Métriques de chaîne                                      |
//+------------------------------------------------------------------+
struct ChainMetrics
{
   double compressionScore;        // +15
   double momentumScore;            // +15
   double breakStructureScore;      // +15
   double displacementScore;       // +15
   double weakRetracementScore;     // +10
   double intervalConsistencyScore;// +10
   double directionPersistenceScore; // +10
   double volatilityScore;         // +5
   double fvgDisplacementScore;     // +5
   double totalScore;               // /100
   
   ChainMetrics()
   {
      compressionScore = 0;
      momentumScore = 0;
      breakStructureScore = 0;
      displacementScore = 0;
      weakRetracementScore = 0;
      intervalConsistencyScore = 0;
      directionPersistenceScore = 0;
      volatilityScore = 0;
      fvgDisplacementScore = 0;
      totalScore = 0;
   }
};

//+------------------------------------------------------------------+
//| CLASS - Spike Chain Engine                                       |
//+------------------------------------------------------------------+
class CSpikeChainEngine
{
private:
   string m_symbol;
   int m_atrHandle;
   int m_emaHandle;
   ChainEngineState m_state;
   CompressionMetrics m_compression;
   ChainMetrics m_metrics;
   
   // Historique des spikes pour analyse
   struct SpikeRecord
   {
      datetime time;
      double amplitude;
      double amplitudeATR;
      int direction;  // +1 up, -1 down
      int barsSincePrev;
   };
   SpikeRecord m_spikeHistory[20];
   int m_spikeHistoryCount;
   
   // Paramètres configurables
   int m_compressionLookbackBars;
   double m_compressionThresholdATR;
   double m_smallBodyThresholdATR;
   int m_minSmallBarsForCompression;
   double m_maxChainRetracementPct;
   double m_chainScoreThreshold;
   double m_preSpikeScoreThreshold;
   
public:
   CSpikeChainEngine(const string symbol);
   ~CSpikeChainEngine();
   
   bool Init();
   void Deinit();
   void OnTick();
   
   ChainEngineState GetState() const { return m_state; }
   CompressionMetrics GetCompressionMetrics() const { return m_compression; }
   ChainMetrics GetChainMetrics() const { return m_metrics; }
   
   bool IsChainActive() const { return (m_state.state == CHAIN_STATE_CHAIN); }
   bool IsPreSpike() const { return (m_state.state == CHAIN_STATE_PRE_SPIKE); }
   bool IsCompression() const { return (m_state.state == CHAIN_STATE_COMPRESSION); }
   
   int GetChainDirection() const { return m_state.chainDirection; }
   double GetChainScore() const { return m_state.chainScore; }
   
private:
   void UpdateState();
   void DetectCompression();
   void DetectPreSpike();
   void DetectSpike();
   void DetectChain();
   void DetectDecay();
   void CalculateChainScore();
   void RecordSpike(double amplitude, int direction);
   double CalculateATR(int period = 14);
   double CalculateEMA(int period = 20);
   double CalculateMomentum(int period = 10);
   bool DetectDisplacement(int &direction, double &amplitude);
   bool DetectBreakStructure(int direction);
   bool DetectLiquiditySweep(int direction);
   double CalculateRetracement(double from, double to, double current);
   bool DetectFVG(int direction);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSpikeChainEngine::CSpikeChainEngine(const string symbol)
{
   m_symbol = symbol;
   m_atrHandle = INVALID_HANDLE;
   m_emaHandle = INVALID_HANDLE;
   m_spikeHistoryCount = 0;
   
   // Paramètres par défaut
   m_compressionLookbackBars = 20;
   m_compressionThresholdATR = 0.5;  // Range < 0.5 ATR = compression
   m_smallBodyThresholdATR = 0.3;    // Corps < 0.3 ATR = petite bougie
   m_minSmallBarsForCompression = 8; // 8+ petites bougies = compression
   m_maxChainRetracementPct = 35.0;  // Retracement > 35% = fin de chaîne
   m_chainScoreThreshold = 75.0;     // Score >= 75 = chaîne probable
   m_preSpikeScoreThreshold = 60.0;  // Score >= 60 = pré-spike
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
bool CSpikeChainEngine::Init()
{
   m_atrHandle = iATR(m_symbol, PERIOD_M1, 14);
   if(m_atrHandle == INVALID_HANDLE)
   {
      Print("❌ SpikeChainEngine: Impossible de créer handle ATR pour ", m_symbol);
      return false;
   }
   
   m_emaHandle = iMA(m_symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
   if(m_emaHandle == INVALID_HANDLE)
   {
      Print("❌ SpikeChainEngine: Impossible de créer handle EMA pour ", m_symbol);
      return false;
   }
   
   m_state.state = CHAIN_STATE_NORMAL;
   m_state.stateStartTime = TimeCurrent();
   m_state.isValid = true;
   
   Print("✅ SpikeChainEngine initialisé pour ", m_symbol);
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialisation                                                  |
//+------------------------------------------------------------------+
void CSpikeChainEngine::Deinit()
{
   if(m_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_atrHandle);
      m_atrHandle = INVALID_HANDLE;
   }
   
   if(m_emaHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_emaHandle);
      m_emaHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Appel à chaque tick                                              |
//+------------------------------------------------------------------+
void CSpikeChainEngine::OnTick()
{
   UpdateState();
}

//+------------------------------------------------------------------+
//| Mise à jour de l'état                                             |
//+------------------------------------------------------------------+
void CSpikeChainEngine::UpdateState()
{
   m_state.barsInState++;
   
   switch(m_state.state)
   {
      case CHAIN_STATE_NORMAL:
         DetectCompression();
         break;
         
      case CHAIN_STATE_COMPRESSION:
         DetectPreSpike();
         // Si compression se relâche, retour NORMAL
         if(!m_compression.isCompressing)
         {
            m_state.state = CHAIN_STATE_NORMAL;
            m_state.stateStartTime = TimeCurrent();
            m_state.barsInState = 0;
         }
         break;
         
      case CHAIN_STATE_PRE_SPIKE:
         DetectSpike();
         // Si pression retombe, retour COMPRESSION ou NORMAL
         if(m_metrics.totalScore < m_preSpikeScoreThreshold)
         {
            m_state.state = (m_compression.isCompressing) ? CHAIN_STATE_COMPRESSION : CHAIN_STATE_NORMAL;
            m_state.stateStartTime = TimeCurrent();
            m_state.barsInState = 0;
         }
         break;
         
      case CHAIN_STATE_SPIKE_CONFIRMED:
         DetectChain();
         break;
         
      case CHAIN_STATE_CHAIN:
         DetectDecay();
         break;
         
      case CHAIN_STATE_DECAY:
         // Après délai, retour NORMAL
         if(m_state.barsInState > 10)
         {
            m_state.state = CHAIN_STATE_NORMAL;
            m_state.stateStartTime = TimeCurrent();
            m_state.barsInState = 0;
            m_state.spikeCount = 0;
            m_state.chainDirection = 0;
         }
         break;
   }
}

//+------------------------------------------------------------------+
//| Détection de compression                                          |
//+------------------------------------------------------------------+
void CSpikeChainEngine::DetectCompression()
{
   m_compression.isCompressing = false;
   m_compression.compressionScore = 0;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(m_symbol, PERIOD_M1, 0, m_compressionLookbackBars, rates) < m_compressionLookbackBars)
      return;
   
   double atr = CalculateATR();
   if(atr <= 0) return;
   
   // 1. Calculer la largeur du range
   double high = rates[0].high;
   double low = rates[0].low;
   for(int i = 1; i < m_compressionLookbackBars; i++)
   {
      if(rates[i].high > high) high = rates[i].high;
      if(rates[i].low < low) low = rates[i].low;
   }
   
   m_compression.rangeWidth = high - low;
   m_compression.rangeWidthATR = m_compression.rangeWidth / atr;
   
   // 2. Compter les petites bougies
   int smallBars = 0;
   double totalBody = 0;
   for(int i = 0; i < m_compressionLookbackBars; i++)
   {
      double body = MathAbs(rates[i].close - rates[i].open);
      totalBody += body;
      if(body < atr * m_smallBodyThresholdATR)
         smallBars++;
   }
   m_compression.smallBarCount = smallBars;
   
   // 3. Calculer le déclin d'amplitude
   double recentBody = 0;
   double olderBody = 0;
   for(int i = 0; i < 5; i++)
      recentBody += MathAbs(rates[i].close - rates[i].open);
   for(int i = 5; i < 15; i++)
      olderBody += MathAbs(rates[i].close - rates[i].open);
   
   if(olderBody > 0)
      m_compression.amplitudeDecline = 1.0 - (recentBody / olderBody);
   
   // 4. Calculer le déclin de retracement
   double recentRetracement = 0;
   double olderRetracement = 0;
   for(int i = 0; i < 5 && i < m_compressionLookbackBars - 1; i++)
   {
      double range = rates[i].high - rates[i].low;
      if(range > 0)
         recentRetracement += MathAbs(rates[i].close - rates[i].open) / range;
   }
   for(int i = 5; i < 15 && i < m_compressionLookbackBars - 1; i++)
   {
      double range = rates[i].high - rates[i].low;
      if(range > 0)
         olderRetracement += MathAbs(rates[i].close - rates[i].open) / range;
   }
   
   if(olderRetracement > 0)
      m_compression.retracementDecline = 1.0 - (recentRetracement / olderRetracement);
   
   // 5. Pression directionnelle (basé sur EMA)
   double ema = CalculateEMA();
   double currentPrice = rates[0].close;
   if(ema > 0)
   {
      m_compression.directionalPressure = (currentPrice - ema) / atr;
      if(m_compression.directionalPressure > 1) m_compression.directionalPressure = 1;
      if(m_compression.directionalPressure < -1) m_compression.directionalPressure = -1;
   }
   
   // Score de compression (0-100)
   double score = 0;
   if(m_compression.rangeWidthATR < m_compressionThresholdATR)
      score += 30;  // Range étroit
   if(smallBars >= m_minSmallBarsForCompression)
      score += 25;  // Petites bougies
   if(m_compression.amplitudeDecline > 0.2)
      score += 20;  // Amplitude en déclin
   if(m_compression.retracementDecline > 0.15)
      score += 15;  // Retracement en déclin
   if(MathAbs(m_compression.directionalPressure) > 0.3)
      score += 10;  // Pression directionnelle
   
   m_compression.compressionScore = score;
   m_compression.isCompressing = (score >= 60);
   
   if(m_compression.isCompressing && m_state.state == CHAIN_STATE_NORMAL)
   {
      m_state.state = CHAIN_STATE_COMPRESSION;
      m_state.stateStartTime = TimeCurrent();
      m_state.barsInState = 0;
      m_state.chainDirection = (m_compression.directionalPressure > 0) ? 1 : -1;
      
      Print("📊 COMPRESSION détectée | Score=", DoubleToString(score, 1),
            " | RangeATR=", DoubleToString(m_compression.rangeWidthATR, 2),
            " | SmallBars=", smallBars,
            " | Dir=", m_state.chainDirection);
   }
}

//+------------------------------------------------------------------+
//| Détection de pré-spike                                            |
//+------------------------------------------------------------------+
void CSpikeChainEngine::DetectPreSpike()
{
   CalculateChainScore();
   
   if(m_metrics.totalScore >= m_preSpikeScoreThreshold && m_state.state == CHAIN_STATE_COMPRESSION)
   {
      m_state.state = CHAIN_STATE_PRE_SPIKE;
      m_state.stateStartTime = TimeCurrent();
      m_state.barsInState = 0;
      
      Print("⚡ PRE-SPIKE détecté | Score=", DoubleToString(m_metrics.totalScore, 1),
            " | Dir=", m_state.chainDirection,
            " | Momentum=", DoubleToString(m_metrics.momentumScore, 1));
   }
}

//+------------------------------------------------------------------+
//| Détection de spike                                                |
//+------------------------------------------------------------------+
void CSpikeChainEngine::DetectSpike()
{
   int direction = 0;
   double amplitude = 0;
   
   if(DetectDisplacement(direction, amplitude))
   {
      m_state.state = CHAIN_STATE_SPIKE_CONFIRMED;
      m_state.stateStartTime = TimeCurrent();
      m_state.barsInState = 0;
      m_state.spikeCount = 1;
      m_state.lastSpikeTime = TimeCurrent();
      m_state.lastSpikeAmplitude = amplitude;
      
      if(direction != 0)
         m_state.chainDirection = direction;
      
      RecordSpike(amplitude, direction);
      
      Print("🎯 SPIKE CONFIRMÉ | Dir=", (direction > 0 ? "BUY" : "SELL"),
            " | Amp=", DoubleToString(amplitude, 2),
            " | Score=", DoubleToString(m_metrics.totalScore, 1));
   }
}

//+------------------------------------------------------------------+
//| Détection de chaîne                                               |
//+------------------------------------------------------------------+
void CSpikeChainEngine::DetectChain()
{
   // Vérifier si on a un retracement suivi d'un nouveau spike
   if(m_state.spikeCount >= 1)
   {
      int direction = 0;
      double amplitude = 0;
      
      if(DetectDisplacement(direction, amplitude))
      {
         // Vérifier que c'est dans la même direction
         if(direction == m_state.chainDirection)
         {
            m_state.spikeCount++;
            m_state.lastSpikeTime = TimeCurrent();
            m_state.lastSpikeAmplitude = amplitude;
            
            RecordSpike(amplitude, direction);
            
            // Calculer les métriques de chaîne
            if(m_spikeHistoryCount >= 2)
            {
               // Intervalle moyen
               double totalInterval = 0;
               for(int i = 1; i < m_spikeHistoryCount; i++)
               {
                  totalInterval += (double)(m_spikeHistory[i].time - m_spikeHistory[i-1].time);
               }
               m_state.avgSpikeInterval = totalInterval / (m_spikeHistoryCount - 1);
               
               // Amplitude moyenne
               double totalAmp = 0;
               for(int i = 0; i < m_spikeHistoryCount; i++)
                  totalAmp += m_spikeHistory[i].amplitude;
               m_state.avgSpikeAmplitude = totalAmp / m_spikeHistoryCount;
            }
            
            // Score de chaîne
            CalculateChainScore();
            
            if(m_metrics.totalScore >= m_chainScoreThreshold && m_state.spikeCount >= 2)
            {
               m_state.state = CHAIN_STATE_CHAIN;
               m_state.chainScore = m_metrics.totalScore;
               m_state.chainStrength = 100; // Force initiale max
               
               Print("🔗 CHAÎNE ACTIVE | Spikes=", m_state.spikeCount,
                     " | Score=", DoubleToString(m_metrics.totalScore, 1),
                     " | Dir=", (m_state.chainDirection > 0 ? "BUY" : "SELL"));
            }
            else
            {
               Print("📈 Spike supplémentaire | Spikes=", m_state.spikeCount,
                     " | Score=", DoubleToString(m_metrics.totalScore, 1));
            }
         }
      }
      
      // Vérifier le retracement
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double retracement = CalculateRetracement(0, m_state.lastSpikeAmplitude * m_state.chainDirection, currentPrice);
      m_state.lastRetracementPct = MathAbs(retracement);
      
      // Si retracement trop fort, chaîne invalide
      if(m_state.lastRetracementPct > m_maxChainRetracementPct)
      {
         m_state.state = CHAIN_STATE_DECAY;
         Print("📉 Chaîne invalide - Retracement ", DoubleToString(m_state.lastRetracementPct, 1), "%");
      }
   }
}

//+------------------------------------------------------------------+
//| Détection de déclin de chaîne                                    |
//+------------------------------------------------------------------+
void CSpikeChainEngine::DetectDecay()
{
   // Vérifier si l'amplitude décroît
   if(m_spikeHistoryCount >= 3)
   {
      double recentAmp = m_spikeHistory[m_spikeHistoryCount-1].amplitude;
      double midAmp = m_spikeHistory[m_spikeHistoryCount-2].amplitude;
      double oldAmp = m_spikeHistory[m_spikeHistoryCount-3].amplitude;
      
      // Si amplitude décroît sur 3 spikes
      if(recentAmp < midAmp && midAmp < oldAmp)
      {
         m_state.chainStrength -= 20;
         if(m_state.chainStrength < 0) m_state.chainStrength = 0;
         
         Print("📉 Force chaîne décroissante | Strength=", DoubleToString(m_state.chainStrength, 0));
         
         if(m_state.chainStrength < 30)
         {
            m_state.state = CHAIN_STATE_DECAY;
            Print("🛑 Chaîne épuisée");
         }
      }
   }
   
   // Vérifier si trop de temps depuis dernier spike
   if(m_state.avgSpikeInterval > 0)
   {
      double timeSinceLast = (double)(TimeCurrent() - m_state.lastSpikeTime);
      if(timeSinceLast > m_state.avgSpikeInterval * 2.5)
      {
         m_state.state = CHAIN_STATE_DECAY;
         Print("⏱️ Chaîne expirée - délai trop long");
      }
   }
}

//+------------------------------------------------------------------+
//| Calcul du score de chaîne                                         |
//+------------------------------------------------------------------+
void CSpikeChainEngine::CalculateChainScore()
{
   m_metrics.totalScore = 0;
   
   // 1. Compression préalable (+15)
   m_metrics.compressionScore = MathMin(15.0, m_compression.compressionScore * 0.15);
   m_metrics.totalScore += m_metrics.compressionScore;
   
   // 2. Momentum croissant (+15)
   double momentum = CalculateMomentum(10);
   if(momentum > 0)
      m_metrics.momentumScore = MathMin(15.0, momentum * 15.0);
   else
      m_metrics.momentumScore = 0;
   m_metrics.totalScore += m_metrics.momentumScore;
   
   // 3. Break structure (+15)
   int direction = m_state.chainDirection;
   if(direction != 0 && DetectBreakStructure(direction))
      m_metrics.breakStructureScore = 15.0;
   else
      m_metrics.breakStructureScore = 0;
   m_metrics.totalScore += m_metrics.breakStructureScore;
   
   // 4. Displacement (+15)
   double dispAmp = 0;
   int dispDir = 0;
   if(DetectDisplacement(dispDir, dispAmp))
      m_metrics.displacementScore = 15.0;
   else
      m_metrics.displacementScore = 0;
   m_metrics.totalScore += m_metrics.displacementScore;
   
   // 5. Retracement faible (+10)
   if(m_state.lastRetracementPct < 25.0)
      m_metrics.weakRetracementScore = 10.0;
   else if(m_state.lastRetracementPct < 35.0)
      m_metrics.weakRetracementScore = 5.0;
   else
      m_metrics.weakRetracementScore = 0;
   m_metrics.totalScore += m_metrics.weakRetracementScore;
   
   // 6. Intervalle cohérent (+10)
   if(m_spikeHistoryCount >= 2)
   {
      double intervals[19];
      double sum = 0, sumSq = 0;
      int count = 0;
      
      for(int i = 1; i < m_spikeHistoryCount; i++)
      {
         intervals[count] = (double)(m_spikeHistory[i].time - m_spikeHistory[i-1].time);
         sum += intervals[count];
         sumSq += intervals[count] * intervals[count];
         count++;
      }
      
      if(count > 0)
      {
         double mean = sum / count;
         double variance = (sumSq / count) - (mean * mean);
         double stdDev = MathSqrt(variance);
         double cv = (mean > 0) ? (stdDev / mean) : 1.0;
         
         // CV < 0.4 = intervalles cohérents
         if(cv < 0.4)
            m_metrics.intervalConsistencyScore = 10.0;
         else if(cv < 0.6)
            m_metrics.intervalConsistencyScore = 5.0;
         else
            m_metrics.intervalConsistencyScore = 0;
      }
   }
   m_metrics.totalScore += m_metrics.intervalConsistencyScore;
   
   // 7. Direction persistante (+10)
   if(m_spikeHistoryCount >= 3)
   {
      bool consistent = true;
      int dir = m_spikeHistory[0].direction;
      for(int i = 1; i < m_spikeHistoryCount; i++)
      {
         if(m_spikeHistory[i].direction != dir)
         {
            consistent = false;
            break;
         }
      }
      m_metrics.directionPersistenceScore = consistent ? 10.0 : 0;
   }
   m_metrics.totalScore += m_metrics.directionPersistenceScore;
   
   // 8. Volatilité compatible (+5)
   double atr = CalculateATR();
   double atrMean = 0;
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(m_atrHandle, 0, 0, 20, atrBuffer) >= 20)
   {
      for(int i = 0; i < 20; i++)
         atrMean += atrBuffer[i];
      atrMean /= 20.0;
      
      if(atrMean > 0)
      {
         double atrRatio = atr / atrMean;
         if(atrRatio >= 0.8 && atrRatio <= 1.5)
            m_metrics.volatilityScore = 5.0;
         else
            m_metrics.volatilityScore = 0;
      }
   }
   m_metrics.totalScore += m_metrics.volatilityScore;
   
   // 9. FVG/displacement (+5)
   if(direction != 0 && DetectFVG(direction))
      m_metrics.fvgDisplacementScore = 5.0;
   else
      m_metrics.fvgDisplacementScore = 0;
   m_metrics.totalScore += m_metrics.fvgDisplacementScore;
   
   m_state.chainScore = m_metrics.totalScore;
}

//+------------------------------------------------------------------+
//| Enregistrer un spike dans l'historique                            |
//+------------------------------------------------------------------+
void CSpikeChainEngine::RecordSpike(double amplitude, int direction)
{
   // Décaler l'historique
   if(m_spikeHistoryCount >= 20)
   {
      for(int i = 0; i < 19; i++)
         m_spikeHistory[i] = m_spikeHistory[i+1];
      m_spikeHistoryCount = 19;
   }
   
   m_spikeHistory[m_spikeHistoryCount].time = TimeCurrent();
   m_spikeHistory[m_spikeHistoryCount].amplitude = amplitude;
   m_spikeHistory[m_spikeHistoryCount].amplitudeATR = amplitude / CalculateATR();
   m_spikeHistory[m_spikeHistoryCount].direction = direction;
   
   if(m_spikeHistoryCount > 0)
   {
      int bars = 0;
      datetime prevTime = m_spikeHistory[m_spikeHistoryCount-1].time;
      datetime curTime = m_spikeHistory[m_spikeHistoryCount].time;
      bars = (int)((curTime - prevTime) / PeriodSeconds(PERIOD_M1));
      m_spikeHistory[m_spikeHistoryCount].barsSincePrev = bars;
   }
   
   m_spikeHistoryCount++;
}

//+------------------------------------------------------------------+
//| Calculer ATR                                                      |
//+------------------------------------------------------------------+
double CSpikeChainEngine::CalculateATR(int period)
{
   if(m_atrHandle == INVALID_HANDLE) return 0;
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   if(CopyBuffer(m_atrHandle, 0, 0, 1, atrBuffer) >= 1)
      return atrBuffer[0];
   
   return 0;
}

//+------------------------------------------------------------------+
//| Calculer EMA                                                     |
//+------------------------------------------------------------------+
double CSpikeChainEngine::CalculateEMA(int period)
{
   if(m_emaHandle == INVALID_HANDLE) return 0;
   
   double emaBuffer[];
   ArraySetAsSeries(emaBuffer, true);
   
   if(CopyBuffer(m_emaHandle, 0, 0, 1, emaBuffer) >= 1)
      return emaBuffer[0];
   
   return 0;
}

//+------------------------------------------------------------------+
//| Calculer momentum                                                 |
//+------------------------------------------------------------------+
double CSpikeChainEngine::CalculateMomentum(int period)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(m_symbol, PERIOD_M1, 0, period + 1, rates) < period + 1)
      return 0;
   
   double current = rates[0].close;
   double previous = rates[period].close;
   
   if(previous == 0) return 0;
   
   double momentum = (current - previous) / previous;
   
   // Normaliser entre 0 et 1
   if(momentum > 0.01) momentum = 1.0;
   else if(momentum < -0.01) momentum = 0;
   else momentum = (momentum + 0.01) / 0.02;
   
   return MathMax(0.0, MathMin(1.0, momentum));
}

//+------------------------------------------------------------------+
//| Détecter displacement                                             |
//+------------------------------------------------------------------+
bool CSpikeChainEngine::DetectDisplacement(int &direction, double &amplitude)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(m_symbol, PERIOD_M1, 0, 3, rates) < 3)
      return false;
   
   double atr = CalculateATR();
   if(atr <= 0) return false;
   
   double body0 = MathAbs(rates[0].close - rates[0].open);
   double body1 = MathAbs(rates[1].close - rates[1].open);
   double body2 = MathAbs(rates[2].close - rates[2].open);
   
   // Displacement = corps > 1.5 ATR et > corps précédent
   double threshold = atr * 1.5;
   
   if(body0 > threshold && body0 > body1 * 1.3)
   {
      direction = (rates[0].close > rates[0].open) ? 1 : -1;
      amplitude = body0;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Détecter break structure                                          |
//+------------------------------------------------------------------+
bool CSpikeChainEngine::DetectBreakStructure(int direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(m_symbol, PERIOD_M1, 0, 20, rates) < 20)
      return false;
   
   // Chercher un swing high/low récent
   double swingHigh = rates[0].high;
   double swingLow = rates[0].low;
   int swingHighIdx = 0, swingLowIdx = 0;
   
   for(int i = 1; i < 15; i++)
   {
      if(rates[i].high > swingHigh)
      {
         swingHigh = rates[i].high;
         swingHighIdx = i;
      }
      if(rates[i].low < swingLow)
      {
         swingLow = rates[i].low;
         swingLowIdx = i;
      }
   }
   
   // Vérifier break
   if(direction > 0) // BUY - break high
   {
      return (rates[0].close > swingHigh && swingHighIdx > 5);
   }
   else // SELL - break low
   {
      return (rates[0].close < swingLow && swingLowIdx > 5);
   }
}

//+------------------------------------------------------------------+
//| Détecter liquidity sweep                                          |
//+------------------------------------------------------------------+
bool CSpikeChainEngine::DetectLiquiditySweep(int direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(m_symbol, PERIOD_M1, 0, 10, rates) < 10)
      return false;
   
   double atr = CalculateATR();
   if(atr <= 0) return false;
   
   if(direction > 0) // BUY - sweep lows
   {
      // Chercher equal lows
      double lows[10];
      for(int i = 0; i < 10; i++)
         lows[i] = rates[i].low;
      
      // Vérifier si wick a touché un low précédent
      for(int i = 1; i < 8; i++)
      {
         if(MathAbs(rates[0].low - lows[i]) < atr * 0.1)
         {
            // Sweep détecté si close au-dessus
            if(rates[0].close > lows[i])
               return true;
         }
      }
   }
   else // SELL - sweep highs
   {
      double highs[10];
      for(int i = 0; i < 10; i++)
         highs[i] = rates[i].high;
      
      for(int i = 1; i < 8; i++)
      {
         if(MathAbs(rates[0].high - highs[i]) < atr * 0.1)
         {
            if(rates[0].close < highs[i])
               return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculer retracement                                              |
//+------------------------------------------------------------------+
double CSpikeChainEngine::CalculateRetracement(double from, double to, double current)
{
   double totalMove = MathAbs(to - from);
   if(totalMove == 0) return 0;
   
   double retrace = MathAbs(current - to);
   return (retrace / totalMove) * 100.0;
}

//+------------------------------------------------------------------+
//| Détecter FVG                                                      |
//+------------------------------------------------------------------+
bool CSpikeChainEngine::DetectFVG(int direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(m_symbol, PERIOD_M1, 0, 3, rates) < 3)
      return false;
   
   // FVG bullish: gap entre bar[1].high et bar[2].low
   if(direction > 0)
   {
      if(rates[2].low > rates[1].high)
         return true;
   }
   // FVG bearish: gap entre bar[1].low et bar[2].high
   else
   {
      if(rates[2].high < rates[1].low)
         return true;
   }
   
   return false;
}
