//+------------------------------------------------------------------+
//| SMC_SpikeModels.mqh                                              |
//| Spike Chain ONNX models for MQL5                                 |
//| Auto-generated from Python pipeline                              |
//| Supports: amplitude, interval, direction prediction              |
//| Include from SMC_Universal.mq5 after other includes              |
//+------------------------------------------------------------------+
#property strict



enum ENUM_SPIKE_PREDICTION
{
   SPIKE_PREDICT_AMPLITUDE,   // Next spike amplitude (ATR multiples)
   SPIKE_PREDICT_INTERVAL,    // Minutes until next spike
   SPIKE_PREDICT_DIRECTION,   // P(next spike is up) — only for Volatility
};

class CSpikeModelSet
{
private:
   long   m_ampHandle;
   long   m_intHandle;
   long   m_dirHandle;
   bool   m_ready;

   bool   LoadOnnx(const string filename, long &handle, const long &inpShape[], const int outDim0, const int outDim1 = -1)
   {
      handle = OnnxCreate(filename, ONNX_DEFAULT);
      if(handle == INVALID_HANDLE)
      {
         PrintFormat("[SpikeModels] Failed to load %s (err=%d)", filename, GetLastError());
         return false;
      }
      if(!OnnxSetInputShape(handle, 0, inpShape))
      {
         PrintFormat("[SpikeModels] Failed OnnxSetInputShape for %s (err=%d)", filename, GetLastError());
         return false;
      }
      long outShape[];
      if(outDim1 < 0)
      {
         ArrayResize(outShape, 1);
         outShape[0] = outDim0;
      }
      else
      {
         ArrayResize(outShape, 2);
         outShape[0] = outDim0;
         outShape[1] = outDim1;
      }
      if(!OnnxSetOutputShape(handle, 0, outShape))
      {
         PrintFormat("[SpikeModels] Failed OnnxSetOutputShape for %s (err=%d)", filename, GetLastError());
         return false;
      }
      return true;
   }

public:
   CSpikeModelSet() : m_ampHandle(INVALID_HANDLE), m_intHandle(INVALID_HANDLE),
                      m_dirHandle(INVALID_HANDLE), m_ready(false) {}

   bool Init(const string ampFile, const string intFile, const string dirFile)
   {
      const long inpShape[] = {1, 10};  // 10 features for regression models

      if(ampFile != "")
      {
         if(!LoadOnnx(ampFile, m_ampHandle, inpShape, 1, 1)) return false;
      }
      if(intFile != "")
      {
         if(!LoadOnnx(intFile, m_intHandle, inpShape, 1, 1)) return false;
      }
      if(dirFile != "")
      {
         const long dirShape[] = {1, 8};
         if(!LoadOnnx(dirFile, m_dirHandle, dirShape, 1, 2)) return false;
      }

      m_ready = (m_ampHandle != INVALID_HANDLE) || (m_intHandle != INVALID_HANDLE) || (m_dirHandle != INVALID_HANDLE);
      return m_ready;
   }

   void Deinit()
   {
      if(m_ampHandle != INVALID_HANDLE) OnnxRelease(m_ampHandle);
      if(m_intHandle != INVALID_HANDLE) OnnxRelease(m_intHandle);
      if(m_dirHandle != INVALID_HANDLE) OnnxRelease(m_dirHandle);
      m_ampHandle = INVALID_HANDLE;
      m_intHandle = INVALID_HANDLE;
      m_dirHandle = INVALID_HANDLE;
      m_ready = false;
   }

   bool IsReady() const { return m_ready; }

   //--- Predict next spike amplitude (in ATR multiples)
   //    Features: amplitude_atr, velocity_proxy, minutes_since_prev, hour, minute,
   //              close_zscore, spikes_last_60min, avg_amplitude_last_5, amplitude_ratio, chain_len
   double PredictAmplitude(const double &features[])
   {
      if(m_ampHandle == INVALID_HANDLE) return -1.0;
      float inp[10];
      for(int i = 0; i < 10; i++) inp[i] = (float)features[i];
      float output[1];
      if(!OnnxRun(m_ampHandle, ONNX_DEFAULT, inp, output))
      {
         Print("[SpikeModels] OnnxRun amplitude failed");
         return -1.0;
      }
      return (double)output[0];
   }

   //--- Predict minutes until next spike
   double PredictInterval(const double &features[])
   {
      if(m_intHandle == INVALID_HANDLE) return -1.0;
      float inp[10];
      for(int i = 0; i < 10; i++) inp[i] = (float)features[i];
      float output[1];
      if(!OnnxRun(m_intHandle, ONNX_DEFAULT, inp, output))
      {
         Print("[SpikeModels] OnnxRun interval failed");
         return -1.0;
      }
      return (double)output[0];
   }

   //--- Predict P(next spike is up) — only valid for Volatility symbols
   double PredictDirectionUp(const double &features[])
   {
      if(m_dirHandle == INVALID_HANDLE) return -1.0;
      float inp[8];
      for(int i = 0; i < 8; i++) inp[i] = (float)features[i];
      float output[2];
      if(!OnnxRun(m_dirHandle, ONNX_DEFAULT, inp, output))
      {
         Print("[SpikeModels] OnnxRun direction failed");
         return -1.0;
      }
      return (double)output[1];  // index 1 = P(up)
   }
};

//+------------------------------------------------------------------+
//| Global instance                                                   |
//+------------------------------------------------------------------+
CSpikeModelSet g_spikeModels;

//+------------------------------------------------------------------+
//| Initialize spike models for current symbol                        |
//+------------------------------------------------------------------+
bool SpikeModels_Init(const string symbol)
{
   string safe = symbol;
   StringReplace(safe, " ", "_");

   string basePath = "Models\\" + safe;
   string ampFile  = basePath + "\\spike_amplitude.onnx";
   string intFile  = basePath + "\\spike_interval.onnx";
   string dirFile  = "";

   // Only Volatility symbols have direction models
   bool isVol = (StringFind(symbol, "FX Vol") != -1) || (StringFind(symbol, "SFX Vol") != -1);
   if(isVol)
      dirFile = basePath + "\\spike_chain_model.onnx";

   return g_spikeModels.Init(ampFile, intFile, dirFile);
}

//+------------------------------------------------------------------+
//| Deinitialize spike models                                         |
//+------------------------------------------------------------------+
void SpikeModels_Deinit()
{
   g_spikeModels.Deinit();
}

//+------------------------------------------------------------------+
//| Build feature vector for regression models (10 features)          |
//+------------------------------------------------------------------+
void SpikeModels_BuildFeatures(
   const double amplitudeAtr,
   const double velocityProxy,
   const double minutesSincePrevSpike,
   const int    hour,
   const int    minute,
   const double closeZscore,
   const int    spikesLast60min,
   const double avgAmplitudeLast5,
   const double amplitudeRatio,
   const int    chainLen,
   double &features[]
)
{
   features[0] = amplitudeAtr;
   features[1] = velocityProxy;
   features[2] = minutesSincePrevSpike;
   features[3] = (double)hour;
   features[4] = (double)minute;
   features[5] = closeZscore;
   features[6] = (double)spikesLast60min;
   features[7] = avgAmplitudeLast5;
   features[8] = amplitudeRatio;
   features[9] = (double)chainLen;
}

//+------------------------------------------------------------------+
//| Build feature vector for direction model (8 features)             |
//+------------------------------------------------------------------+
void SpikeModels_BuildDirFeatures(
   const bool   dirIsUp,
   const double amplitudePips,
   const double amplitudeAtr,
   const double velocityProxy,
   const double minutesSincePrevSpike,
   const int    hour,
   const int    minute,
   const double markovPriorUp,
   double &features[]
)
{
   features[0] = dirIsUp ? 1.0 : 0.0;
   features[1] = amplitudePips;
   features[2] = amplitudeAtr;
   features[3] = velocityProxy;
   features[4] = minutesSincePrevSpike;
   features[5] = (double)hour;
   features[6] = (double)minute;
   features[7] = markovPriorUp;
}
