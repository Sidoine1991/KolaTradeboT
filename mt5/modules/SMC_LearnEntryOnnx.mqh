//+------------------------------------------------------------------+
//| SMC_LearnEntryOnnx.mqh  (v1.57)                                  |
//| Gate ONNX learn_entry : P(win) sur features shadow (28 dims).     |
//| Fail-open si modele absent / seuil >= 1.0 / warmup.               |
//| Ordre features = python/ml/train_learn_entry_onnx.py FEATURE_ORDER|
//+------------------------------------------------------------------+
#ifndef SMC_LEARN_ENTRY_ONNX_MQH
#define SMC_LEARN_ENTRY_ONNX_MQH

input group "=== APPRENTISSAGE : ONNX LEARN_ENTRY (v1.57) ==="
input string LE_OnnxModelFile   = "SMC_Learn\\learn_entry.onnx"; // Sous MQL5/Files/
input double LE_OnnxMinProb     = 0.62;  // P(win) min (defaut = seuil calibre holdout v1.57)
input bool   LE_OnnxFailOpen    = true;  // true = autoriser si modele non charge

long     g_leOnnxHandle   = INVALID_HANDLE;
bool     g_leOnnxReady    = false;
double   g_leOnnxThreshold = 0.55;
double   g_leLastProb     = -1.0;
datetime g_leLastInfer    = 0;
int      g_leBlocks       = 0;

double LE_Clip(const double v, const double lo, const double hi)
{
   if(!MathIsValidNumber(v)) return 0.0;
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
}

double LE_TfAlign(const string tfDir, const int dirSign)
{
   string s = tfDir;
   StringToUpper(s);
   double sign = 0.0;
   if(s == "BULL" || s == "BUY" || s == "UP" || s == "LONG") sign = 1.0;
   else if(s == "BEAR" || s == "SELL" || s == "DOWN" || s == "SHORT") sign = -1.0;
   return sign * (double)dirSign;
}

void LE_FamilyFlags(const string sym, double &fx, double &pain, double &gain)
{
   string u = sym;
   StringToUpper(u);
   StringReplace(u, " ", "");
   fx = 0.0; pain = 0.0; gain = 0.0;
   if(StringFind(u, "FXVOL") >= 0 || StringFind(u, "VOLATILITY") >= 0 || StringFind(u, "SFXVOL") >= 0)
      fx = 1.0;
   else if(StringFind(u, "PAIN") >= 0 || StringFind(u, "BOOM") >= 0)
      pain = 1.0;
   else if(StringFind(u, "GAIN") >= 0 || StringFind(u, "CRASH") >= 0)
      gain = 1.0;
}

bool LE_BuildFeatures(const string symbol, const int dirSign, float &feat[])
{
   ArrayResize(feat, 28);
   for(int i = 0; i < 28; i++) feat[i] = 0.0f;

   if(dirSign == 0) return false;

   string sym = (StringLen(symbol) > 0) ? symbol : _Symbol;
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double price = (dirSign > 0) ? ask : bid;
   double atr = SMC_EffectiveSymbolATR(sym);
   double pt  = SymbolInfoDouble(sym, SYMBOL_POINT);

   double vn = (double)g_smcGomVerdictNum;
   double dsign = (dirSign > 0) ? 1.0 : -1.0;

   double poc_d = 0.0, vah_d = 0.0, val_d = 0.0, in_va = 0.0;
   if(g_vpLastCalc > 0 && atr > 0.0 && price > 0.0 && g_vpVah > g_vpVal)
   {
      poc_d = (price - g_vpPocPrice) / atr;
      vah_d = (price - g_vpVah) / atr;
      val_d = (price - g_vpVal) / atr;
      in_va = (price <= g_vpVah && price >= g_vpVal) ? 1.0 : 0.0;
   }

   double rsi = 50.0;
   double ema_gap = 0.0;
   if(g_ljRsi != INVALID_HANDLE)
   {
      double b[];
      if(CopyBuffer(g_ljRsi, 0, 0, 1, b) > 0) rsi = b[0];
   }
   if(g_ljEmaF != INVALID_HANDLE && g_ljEmaS != INVALID_HANDLE && atr > 0.0)
   {
      double bf[], bs[];
      if(CopyBuffer(g_ljEmaF, 0, 0, 1, bf) > 0 && CopyBuffer(g_ljEmaS, 0, 0, 1, bs) > 0)
         ema_gap = (bf[0] - bs[0]) / atr;
   }

   double spr = (pt > 0.0) ? (ask - bid) / pt : 0.0;
   MqlDateTime mt;
   TimeToStruct(TimeCurrent(), mt);

   double flow20 = 0.0, flow3 = 0.0;
   flow20 = VPF_MoneyFlow(sym, VPF_FlowBars, 1);
   flow3  = VPF_MoneyFlow(sym, 3, 1);

   double fx = 0.0, pain = 0.0, gain = 0.0;
   LE_FamilyFlags(sym, fx, pain, gain);

   // FEATURE_ORDER (28) — doit matcher train_learn_entry_onnx.py
   feat[0]  = (dirSign > 0) ? 1.0f : 0.0f;                          // dir_is_buy
   feat[1]  = (float)LE_Clip(MathAbs(vn), 0.0, 10.0);               // vn_abs
   feat[2]  = (float)LE_Clip(vn * dsign, -10.0, 10.0);              // vn_aligned
   feat[3]  = (float)LE_Clip(g_smcGomCoherence, 0.0, 100.0);        // coh
   feat[4]  = (float)LE_Clip(g_smcGomQuality, 0.0, 100.0);          // qual
   feat[5]  = (float)LE_TfAlign(g_smcTfM1Dir, dirSign);             // m1_align
   feat[6]  = (float)LE_TfAlign(g_smcTfM5Dir, dirSign);             // m5_align
   feat[7]  = (float)LE_TfAlign(g_smcTfM15Dir, dirSign);            // m15_align
   feat[8]  = (float)LE_Clip(g_smcGhostDelta, -100.0, 100.0);       // delta_w
   feat[9]  = (float)LE_Clip(g_smcGhostCVD, -300.0, 300.0);         // cvd_w
   feat[10] = (float)LE_Clip(poc_d, -10.0, 10.0);                   // poc_d
   feat[11] = (float)LE_Clip(vah_d, -10.0, 10.0);                   // vah_d
   feat[12] = (float)LE_Clip(val_d, -10.0, 10.0);                   // val_d
   feat[13] = (float)LE_Clip(in_va, 0.0, 1.0);                      // in_va
   feat[14] = (float)LE_Clip(flow20, -5.0, 5.0);                    // flow20
   feat[15] = (float)LE_Clip(flow3, -5.0, 5.0);                     // flow3
   feat[16] = (float)LE_Clip((price > 0.0) ? atr / price * 100.0 : 0.0, 0.0, 1.0); // atr_pct
   feat[17] = (float)LE_Clip(rsi, 0.0, 100.0);                      // rsi14
   feat[18] = (float)LE_Clip(ema_gap, -10.0, 10.0);                 // ema_gap
   feat[19] = (float)LE_Clip(spr, 0.0, 2000.0);                     // spread_w
   feat[20] = (float)LE_Clip((double)mt.hour, 0.0, 23.0);           // hour
   feat[21] = (float)LE_Clip((double)mt.day_of_week, 0.0, 6.0);     // dow
   feat[22] = (float)LE_Clip(ChainPred_GetImminence(), 0.0, 100.0); // imminence
   feat[23] = (float)LE_Clip(g_lastAIConfidence, 0.0, 1.0);         // ai_conf
   feat[24] = g_smcGomConnected ? 1.0f : 0.0f;                      // gom_conn
   feat[25] = (float)fx;                                            // fam_fxvol
   feat[26] = (float)pain;                                          // fam_pain
   feat[27] = (float)gain;                                          // fam_gain
   return true;
}

bool LE_LoadThresholdFromMeta()
{
   // Metadata JSON minimale : cherche "threshold": <float>
   string paths[2];
   paths[0] = "SMC_Learn\\learn_entry_metadata.json";
   paths[1] = "TradBOT\\SMC_Learn\\learn_entry_metadata.json";
   for(int p = 0; p < 2; p++)
   {
      int flags = FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ;
      if(p == 1) flags |= FILE_COMMON;
      int h = FileOpen(paths[p], flags);
      if(h == INVALID_HANDLE) continue;
      string content = "";
      while(!FileIsEnding(h))
         content += FileReadString(h);
      FileClose(h);
      int pos = StringFind(content, "\"threshold\"");
      if(pos < 0) continue;
      int colon = StringFind(content, ":", pos);
      if(colon < 0) continue;
      string rest = StringSubstr(content, colon + 1, 32);
      StringTrimLeft(rest);
      // Lire jusqu'a virgule / newline
      string num = "";
      for(int i = 0; i < StringLen(rest); i++)
      {
         ushort c = StringGetCharacter(rest, i);
         if((c >= '0' && c <= '9') || c == '.' || c == '-')
            num += ShortToString(c);
         else if(StringLen(num) > 0)
            break;
      }
      double thr = StringToDouble(num);
      if(thr > 0.0 && thr <= 1.01)
      {
         g_leOnnxThreshold = thr;
         Print("[LEARN-ONNX] threshold metadata=", DoubleToString(thr, 3),
               " | source=", paths[p]);
         return true;
      }
   }
   g_leOnnxThreshold = LE_OnnxMinProb;
   return false;
}

bool LE_OnnxInit()
{
   if(g_leOnnxHandle != INVALID_HANDLE)
   {
      OnnxRelease(g_leOnnxHandle);
      g_leOnnxHandle = INVALID_HANDLE;
   }
   g_leOnnxReady = false;
   g_leOnnxThreshold = LE_OnnxMinProb;

   g_leOnnxHandle = OnnxCreate(LE_OnnxModelFile, ONNX_DEFAULT);
   if(g_leOnnxHandle == INVALID_HANDLE)
   {
      // Fallback Common Files
      string alt = "TradBOT\\SMC_Learn\\learn_entry.onnx";
      // OnnxCreate ne lit pas FILE_COMMON — copier n'est pas possible ici.
      Print("[LEARN-ONNX] modele introuvable: ", LE_OnnxModelFile,
            " err=", GetLastError(),
            " | fail-open=", (LE_OnnxFailOpen ? "oui" : "non"),
            " | alt attendu aussi dans MQL5/Files/SMC_Learn/");
      return false;
   }

   const long input_shape[] = {1, 28};
   if(!OnnxSetInputShape(g_leOnnxHandle, 0, input_shape))
   {
      Print("[LEARN-ONNX] OnnxSetInputShape echoue err=", GetLastError());
      OnnxRelease(g_leOnnxHandle);
      g_leOnnxHandle = INVALID_HANDLE;
      return false;
   }

   LE_LoadThresholdFromMeta();
   // Seuil 1.01 = fail-open volontaire (pas de bucket profitable a l'entrainement)
   g_leOnnxReady = true;
   Print("[LEARN-ONNX] pret | file=", LE_OnnxModelFile,
         " | thr=", DoubleToString(g_leOnnxThreshold, 3),
         " | blocks=", g_leBlocks);
   return true;
}

void LE_OnnxDeinit()
{
   if(g_leOnnxHandle != INVALID_HANDLE)
   {
      OnnxRelease(g_leOnnxHandle);
      g_leOnnxHandle = INVALID_HANDLE;
   }
   g_leOnnxReady = false;
}

double LE_OnnxPredictPWin(const string symbol, const int dirSign)
{
   if(!g_leOnnxReady || g_leOnnxHandle == INVALID_HANDLE)
      return -1.0;

   float feat[];
   if(!LE_BuildFeatures(symbol, dirSign, feat))
      return -1.0;

   // Modele sklearn-onnx: souvent 1 input + label + proba (3 tenseurs)
   float outLabel[1];
   float outProba[2];
   const long out_shape_label[] = {1};
   const long out_shape_proba[] = {1, 2};
   OnnxSetOutputShape(g_leOnnxHandle, 0, out_shape_label);
   OnnxSetOutputShape(g_leOnnxHandle, 1, out_shape_proba);
   bool ran = OnnxRun(g_leOnnxHandle, ONNX_DEFAULT, feat, outLabel, outProba);
   if(!ran)
   {
      // Fallback: modeles a 1 seule sortie proba
      ResetLastError();
      ran = OnnxRun(g_leOnnxHandle, ONNX_DEFAULT, feat, outProba);
   }
   if(!ran)
   {
      static datetime s_err = 0;
      if(TimeCurrent() - s_err >= 60)
      {
         s_err = TimeCurrent();
         Print("[LEARN-ONNX] OnnxRun echoue err=", GetLastError());
      }
      return -1.0;
   }
   g_leLastProb = (outProba[1] > 0.0f) ? (double)outProba[1] : (double)outProba[0]; // P(win)
   g_leLastInfer = TimeCurrent();
   return g_leLastProb;
}

// Porte d'entree : fail-open si modele absent / seuil >= 1.0 / prediction invalide.
bool LE_OnnxAllowsEntry(const string symbol, const int dirSign)
{
   if(dirSign == 0)
      return true;

   if(!g_leOnnxReady || g_leOnnxHandle == INVALID_HANDLE)
      return LE_OnnxFailOpen;

   // threshold >= 1.0 => aucun trade ne passe le filtre => fail-open explicite
   if(g_leOnnxThreshold >= 1.0)
      return true;

   double pWin = LE_OnnxPredictPWin(symbol, dirSign);
   if(pWin < 0.0)
      return LE_OnnxFailOpen;

   if(pWin < g_leOnnxThreshold)
   {
      g_leBlocks++;
      static datetime s_log = 0;
      if(TimeCurrent() - s_log >= 30)
      {
         s_log = TimeCurrent();
         Print("[LEARN-ONNX] BLOQUÉ ", symbol, " ", (dirSign > 0 ? "BUY" : "SELL"),
               " | P(win)=", DoubleToString(pWin, 3),
               " < thr=", DoubleToString(g_leOnnxThreshold, 3),
               " | blocks=", g_leBlocks);
      }
      return false;
   }
   return true;
}

string LE_OnnxDashboardHint()
{
   if(!g_leOnnxReady)
      return "ONNX:off";
   if(g_leOnnxThreshold >= 1.0)
      return "ONNX:open";
   return StringFormat("ONNX:%.2f/%d", g_leLastProb, g_leBlocks);
}

#endif // SMC_LEARN_ENTRY_ONNX_MQH
