//+------------------------------------------------------------------+
//| SpikeChainPredictor.mqh                                          |
//| Module d'inference pour le Spike Chain State Detector            |
//| A inclure dans SMC_Universal EA                                  |
//|                                                                    |
//| Prerequis :                                                      |
//|   1) Copier spike_chain_model.onnx dans MQL5/Files/ (ou           |
//|      MQL5/Files/<subfolder>/) du terminal                        |
//|   2) Recopier ici la matrice simple_transition du fichier         |
//|      markov_<symbol>.json genere par le module 2 Python           |
//|   3) L'ordre des features ci-dessous DOIT correspondre EXACTEMENT |
//|      a feature_order dans model_metadata.json                    |
//+------------------------------------------------------------------+
#property strict

// --- Ordre des features (voir model_metadata.json) -----------------
// 0: dir_is_up
// 1: amplitude_pips
// 2: amplitude_atr
// 3: velocity_proxy
// 4: minutes_since_prev_spike
// 5: hour
// 6: minute
// 7: markov_prior_up

struct SpikeChainInput
{
   bool   dirIsUp;
   double amplitudePips;
   double amplitudeAtr;
   double velocityProxy;
   double minutesSincePrevSpike;
   int    hour;
   int    minute;
};

class CSpikeChainPredictor
{
private:
   long   m_onnxHandle;
   bool   m_ready;

   // Matrice de Markov "simple" recopiee depuis markov_<symbol>.json
   // (a mettre a jour a chaque re-entrainement)
   double m_markovUpGivenUp;    // simple_transition["up"]["up"]
   double m_markovUpGivenDown;  // simple_transition["down"]["up"]

public:
   CSpikeChainPredictor() : m_onnxHandle(INVALID_HANDLE), m_ready(false) {}

   //--- Charge le modele ONNX. A appeler dans OnInit().
   bool Init(const string onnxFileName,
             const double markovUpGivenUp,
             const double markovUpGivenDown)
   {
      m_markovUpGivenUp   = markovUpGivenUp;
      m_markovUpGivenDown = markovUpGivenDown;

      // ONNX_DEFAULT : shape figee a l'entrainement (batch=1 recommande pour l'inference live)
      m_onnxHandle = OnnxCreate(onnxFileName, ONNX_DEFAULT);
      if(m_onnxHandle == INVALID_HANDLE)
        {
         PrintFormat("[SpikeChain] Echec chargement ONNX '%s' - err=%d", onnxFileName, GetLastError());
         m_ready = false;
         return false;
        }

      // Definir explicitement les shapes d'entree/sortie (batch=1, 8 features)
      const long input_shape[] = {1, 8};
      if(!OnnxSetInputShape(m_onnxHandle, 0, input_shape))
        {
         PrintFormat("[SpikeChain] Echec OnnxSetInputShape - err=%d", GetLastError());
         return false;
        }

      m_ready = true;
      Print("[SpikeChain] Modele ONNX charge avec succes.");
      return true;
   }

   void Deinit()
   {
      if(m_onnxHandle != INVALID_HANDLE)
         OnnxRelease(m_onnxHandle);
   }

   //--- Prior Markov simple, utilise aussi comme feature d'entree du modele
   double MarkovPriorUp(const bool currentIsUp)
   {
      return currentIsUp ? m_markovUpGivenUp : m_markovUpGivenDown;
   }

   //--- Calcule P(prochain spike = haussier) via le modele corrige.
   //    Retourne -1.0 en cas d'erreur.
   double PredictNextSpikeUpProbability(const SpikeChainInput &in)
   {
      if(!m_ready)
         return -1.0;

      double markovPrior = MarkovPriorUp(in.dirIsUp);

      float inputData[8];
      inputData[0] = in.dirIsUp ? 1.0f : 0.0f;
      inputData[1] = (float)in.amplitudePips;
      inputData[2] = (float)in.amplitudeAtr;
      inputData[3] = (float)in.velocityProxy;
      inputData[4] = (float)in.minutesSincePrevSpike;
      inputData[5] = (float)in.hour;
      inputData[6] = (float)in.minute;
      inputData[7] = (float)markovPrior;

      float outputProba[2]; // [P(down), P(up)] selon l'ordre des classes LightGBM (0=down, 1=up)

      if(!OnnxRun(m_onnxHandle, ONNX_DEFAULT, inputData, outputProba))
        {
         PrintFormat("[SpikeChain] Echec OnnxRun - err=%d", GetLastError());
         return -1.0;
        }

      return (double)outputProba[1]; // proba "up"
   }
};

//+------------------------------------------------------------------+
//| Exemple d'utilisation dans SMC_Universal.mq5                     |
//+------------------------------------------------------------------+
/*
CSpikeChainPredictor g_spikeChainBoom;

int OnInit()
{
   // Valeurs a recopier depuis markov_boom1000.json -> simple_transition
   g_spikeChainBoom.Init("spike_chain_model_boom1000.onnx",
                          0.80,   // simple_transition.up.up
                          0.80);  // simple_transition.down.up
   ...
}

void OnTick()
{
   // ... detection du dernier spike (reutiliser la logique existante du
   // Spike Chain State Detector pour amplitude/velocity/minutes_since_prev) ...

   SpikeChainInput sci;
   sci.dirIsUp               = lastSpikeWasUp;
   sci.amplitudePips          = lastSpikeAmplitudePips;
   sci.amplitudeAtr           = lastSpikeAmplitudeAtr;
   sci.velocityProxy          = lastSpikeVelocityProxy;
   sci.minutesSincePrevSpike  = minutesSinceLastSpike;
   sci.hour                   = TimeHour(TimeCurrent());
   sci.minute                 = TimeMinute(TimeCurrent());

   double probaUp = g_spikeChainBoom.PredictNextSpikeUpProbability(sci);

   if(probaUp >= 0.75)
   {
      // Filtre favorable a un signal BUY (coherent avec le sens Boom)
      // -> combiner avec GOM AI pipeline / Sniper Scalper Mode existant
   }
   else if(probaUp <= 0.35)
   {
      // Probabilite elevee de contre-spike -> prudence / reduire taille
   }
}

void OnDeinit(const int reason)
{
   g_spikeChainBoom.Deinit();
}
*/
